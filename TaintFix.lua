--[[
    Roth UI Taint Mitigation

    Records refused actions and keeps the gamepad "add-on blocked" popup from
    looping (below).

    An earlier version closed every dropdown and menu at combat start by
    calling CloseDropDownMenus / CloseMenus from here. That wrote the
    UIDROPDOWNMENU_* globals and the menu manager's state from add-on code at
    every pull, so Blizzard code reading them ran tainted in combat; removed
    2026-10-16. Roth's own dropdowns now use the Menu system (core/panel.lua).

    NOTE: Do NOT hook UIDropDownMenu_Initialize or write to dropdown frames
    from addon code — even rawset taints the frame in WoW's taint system,
    which propagates through SecureTemplates to FocusUnit/TargetUnit.
]]

local addonName, ns = ...

---------------------------------------------
-- BLOCKED ACTIONS: log, and keep the gamepad popup loop from starting
---------------------------------------------
-- On WoW Forever the client fires ADDON_ACTION_FORBIDDEN inside the tainted
-- call that was refused, so Blizzard's handler shows the "has been blocked"
-- popup from tainted code and every field it writes on the popup is tainted
-- (taint.log 2026-10-16 19:42: "reading field gamepadShown"). In the gamepad
-- UI, dismissing that popup (or anything that hides it) runs
-- FrameControlsManager -> InputBindingManager:RemoveSet ->
-- GamepadMainActionBarFrame:UpdateInteractIcons ->
-- SetPreferredGamepadInteractTarget tainted, which is refused again, which
-- shows the popup again: 2048 refusals in one second, then the client's 20 s
-- freeze (ERROR #109). Seen when looting, 2026-10-16 22:29.
--
-- An earlier "circuit breaker" here called StaticPopup_Hide from this file
-- after three popups. That hide is itself add-on code hiding a gamepad
-- window, so it fed the loop instead of breaking it; it is gone.
--
-- What is left:
--   * every ADDON_ACTION_FORBIDDEN / ADDON_ACTION_BLOCKED is recorded (chat
--     line, /roth taint, Roth_UI_DB_GLOB.blockedLog) so nothing is hidden;
--   * while the gamepad UI is on (cfg.pad.forbiddenGuard, default on) the
--     game's own popup frame is unsubscribed from ADDON_ACTION_FORBIDDEN, so
--     no tainted popup can start the loop. It is subscribed again when the
--     gamepad UI goes off, or when the guard is turned off.
-- The refused call itself stays refused either way; the guard only removes
-- the popup that turns one refusal into a frozen client.

local Blocked = { count = 0, recent = {} }
ns.TaintFix = Blocked

local MAX_RECENT = 20
local CHAT_GAP = 15 -- seconds a burst of refusals shares one chat line

local watcher = CreateFrame("Frame")
local burstOpen, burstMore = false, 0

local function Record(event, addon, func)
	addon, func = tostring(addon), tostring(func)
	Blocked.count = Blocked.count + 1
	local entry = { time = date("%H:%M:%S"), event = event, addon = addon, func = func }
	table.insert(Blocked.recent, 1, entry)
	if #Blocked.recent > MAX_RECENT then
		Blocked.recent[#Blocked.recent] = nil
	end
	if type(Roth_UI_DB_GLOB) == "table" then
		local log = Roth_UI_DB_GLOB.blockedLog or {}
		Roth_UI_DB_GLOB.blockedLog = log
		table.insert(log, 1, ("%s %s %s %s"):format(date("%m-%d %H:%M:%S"), event, addon, func))
		for i = #log, 50 + 1, -1 do
			log[i] = nil
		end
	end
	-- One chat line per burst: a tainted refresh refuses a dozen calls at
	-- once (the crossbar's sub-bars, 2026-10-16 22:57); the rest are counted
	-- into one follow-up line and all are kept for /roth taint.
	if burstOpen then
		burstMore = burstMore + 1
		return
	end
	burstOpen, burstMore = true, 0
	print(
		("|c00FF3300Roth_UI:|r the game refused %s (%s, %s). /roth taint lists every refusal."):format(
			func,
			addon,
			event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked"
		)
	)
	C_Timer.After(CHAT_GAP, function()
		if burstMore > 0 then
			print(("|c00FF3300Roth_UI:|r ...and %d more refused in the next %d s."):format(burstMore, CHAT_GAP))
		end
		burstOpen = false
	end)
end

watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
watcher:SetScript("OnEvent", function(_, event, addon, func)
	pcall(Record, event, addon, func)
end)

-- Frames other than ours that listen for the popup's event (Blizzard's
-- GameEvent router, and any error-catcher add-on).
local detached = {}

local function GuardWanted()
	local cfg = ns.cfg
	local on = not (cfg and cfg.pad and cfg.pad.forbiddenGuard == false)
	return on and ns.Pad and ns.Pad:IsActive()
end

function Blocked.ApplyGuard()
	local want = GuardWanted()
	if want and not Blocked.guarding then
		local list = rawget(_G, "GetFramesRegisteredForEvent")
		if not list then
			return
		end
		for _, frame in ipairs({ list("ADDON_ACTION_FORBIDDEN") }) do
			if frame ~= watcher and pcall(frame.UnregisterEvent, frame, "ADDON_ACTION_FORBIDDEN") then
				detached[#detached + 1] = frame
			end
		end
		Blocked.guarding = true
	elseif not want and Blocked.guarding then
		for i = #detached, 1, -1 do
			pcall(detached[i].RegisterEvent, detached[i], "ADDON_ACTION_FORBIDDEN")
			detached[i] = nil
		end
		Blocked.guarding = false
	end
end

if ns.Pad and ns.Pad.RegisterCallback then
	ns.Pad:RegisterCallback(Blocked.ApplyGuard)
end
