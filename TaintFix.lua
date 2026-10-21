-- Log blocked actions and optionally suppress the recursive gamepad error popup.
-- The popup guard requires the ns.Pad activation callback; logging works independently.
-- Do not initialize legacy dropdowns or mutate Blizzard menu state from addon code.

local addonName, ns = ...

-- BLOCKED ACTIONS: log, and keep the gamepad popup loop from starting
-- A forbidden-action popup can recursively trigger protected gamepad binding failures.
-- Record refusals; when ns.Pad requests the guard, detach other listeners temporarily.
-- Restore listeners when the guard turns off. The original action remains refused.

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
	-- Summarize each burst in chat; retain individual entries for diagnostics.
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
