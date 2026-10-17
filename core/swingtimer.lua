---------------------------------------------
--  Roth_UI - swing timer
---------------------------------------------
-- A Diablo bar for melee swings and Auto Shot, built from Roth's spare
-- segmented-bar art: combo_bar_left / right buckles, a combo_back2 slab and
-- the skull-studded combo_fill, which flashes combo_glow on every hit.
--
-- WoW Forever announces each swing itself: PLAYER_SWING (swingDuration,
-- swingType), the event its own Blizzard_SwingTimer resets its bars on
-- (SwingTimerDocumentation.lua). The duration is a plain number there
-- (Blizzard's bar does arithmetic on it); a secret one is skipped rather
-- than tested. The bar fills toward the next swing and fades out a moment
-- after the last one. Main hand and Auto Shot / wand / throw; the off hand
-- is left out (one bar, and the main hand sets the rhythm).
--
-- An energy or mana tick bar was the other use considered for this art:
-- UnitPower goes secret in combat on Forever, so ticks cannot be told apart
-- from Lua there, and it was dropped.

local _, ns = ...

local cfg = ns.cfg
local Secrets = ns.Secrets

local Swing = {}
ns.SwingTimer = Swing

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"
local WIDTH, HEIGHT, CAP = 200, 26, 38
local LINGER = 2 -- seconds the bar stays after the last swing

local function Opt(key, default)
	local s = cfg.swingTimer
	if s and s[key] ~= nil then
		return s[key]
	end
	return default
end

local function SwingType(name, literal)
	local value = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType[name]
	return type(value) == "number" and value or literal
end
local MAIN, RANGED = SwingType("MainHand", 0), SwingType("Ranged", 2)

local COLOR = {
	[MAIN] = { 1, 0.5, 0.12 },
	[RANGED] = { 0.55, 0.9, 0.3 },
}

---------------------------------------------
-- THE BAR
---------------------------------------------

local holder = CreateFrame("Frame", "Roth_UISwingTimer", UIParent)
holder:SetSize(WIDTH, HEIGHT)
holder:SetFrameStrata("MEDIUM")
holder:SetAlpha(0)
holder:SetScale(Opt("scale", 1))
holder:SetMovable(true) -- the HUD mover places it (user-placed, saved by the client)
Swing.holder = holder

local slab = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
slab:SetTexture(MEDIA .. "combo_back2")
slab:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, HEIGHT * 0.3)
slab:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, -HEIGHT * 0.3)

-- combo_fill's studded band is its middle 24 of 64 rows
local bar = CreateFrame("StatusBar", nil, holder)
bar:SetPoint("LEFT", holder, "LEFT", 4, 0)
bar:SetPoint("RIGHT", holder, "RIGHT", -4, 0)
bar:SetHeight(HEIGHT * 0.6)
bar:SetStatusBarTexture(MEDIA .. "combo_fill")
bar:GetStatusBarTexture():SetTexCoord(0, 1, 20 / 64, 44 / 64)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
Swing.bar = bar

local over = CreateFrame("Frame", nil, holder)
over:SetAllPoints(holder)
over:SetFrameLevel(bar:GetFrameLevel() + 2)
for _, side in ipairs({ "LEFT", "RIGHT" }) do
	local cap = over:CreateTexture(nil, "ARTWORK")
	cap:SetTexture(MEDIA .. (side == "LEFT" and "combo_bar_left" or "combo_bar_right"))
	cap:SetSize(CAP, CAP)
	if side == "LEFT" then
		cap:SetPoint("RIGHT", holder, "LEFT", 8, 0)
	else
		cap:SetPoint("LEFT", holder, "RIGHT", -8, 0)
	end
end

-- the hit flash: combo_glow (its rounded outline fills 56 x 26 of 64 x 64)
local glow = over:CreateTexture(nil, "OVERLAY")
glow:SetTexture(MEDIA .. "combo_glow")
glow:SetPoint("TOPLEFT", holder, "TOPLEFT", -6, HEIGHT * 0.8)
glow:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 6, -HEIGHT * 0.8)
glow:SetBlendMode("ADD")
glow:SetAlpha(0)
local flash = glow:CreateAnimationGroup()
local a = flash:CreateAnimation("Alpha")
a:SetFromAlpha(1)
a:SetToAlpha(0)
a:SetDuration(0.35)
Swing.glow = glow

local timeText = ns.func.createFontString(over, cfg.font, 11, "THINOUTLINE")
timeText:SetPoint("RIGHT", holder, "RIGHT", -6, 0)
timeText:SetTextColor(1, 0.9, 0.7)
Swing.timeText = timeText

---------------------------------------------
-- TIMING
---------------------------------------------

local state = { start = nil, duration = nil }
Swing.state = state

function Swing.OnSwing(duration, swingType)
	if not Opt("enabled", true) then
		return
	end
	if Secrets.IsSecret(swingType) or Secrets.IsSecret(duration) then
		return
	end
	if swingType ~= MAIN and not (swingType == RANGED and Opt("ranged", true)) then
		return
	end
	if type(duration) ~= "number" or duration <= 0 then
		return
	end
	state.start, state.duration = GetTime(), duration
	local c = COLOR[swingType]
	bar:SetStatusBarColor(c[1], c[2], c[3])
	glow:SetVertexColor(c[1], c[2], c[3])
	flash:Stop()
	flash:Play()
	holder:SetAlpha(1)
	holder:Show()
end

-- Fill toward the next swing; fade out after the last one.
function Swing.Tick(now)
	local start, duration = state.start, state.duration
	if not (start and duration) then
		return
	end
	if Swing.editing then
		return
	end
	local elapsed = now - start
	if elapsed < duration then
		bar:SetValue(elapsed / duration)
		timeText:SetFormattedText("%.1f", duration - elapsed)
		holder:SetAlpha(1)
		return
	end
	bar:SetValue(1)
	timeText:SetText("")
	local late = elapsed - duration
	if late >= LINGER then
		state.start, state.duration = nil, nil
		holder:SetAlpha(0)
	else
		holder:SetAlpha(1 - late / LINGER)
	end
end

holder:SetScript("OnUpdate", function()
	Swing.Tick(GetTime())
end)

-- Edit layout (core/editmode.lua): shown and draggable; the client saves the
-- place (user-placed).
do
	local box = holder:CreateTexture(nil, "OVERLAY", nil, 7)
	box:SetAllPoints(holder)
	box:SetColorTexture(0, 1, 0, 0.2)
	box:Hide()
	holder:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	holder:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(true)
	end)
	function Swing.SetEditing(on)
		Swing.editing = on
		box:SetShown(on)
		holder:EnableMouse(on)
		if on then
			holder:RegisterForDrag("LeftButton")
		else
			holder:RegisterForDrag()
		end
		if on then
			bar:SetValue(0.6)
			holder:SetAlpha(1)
		elseif not state.start then
			holder:SetAlpha(0)
		end
	end
end

-- Above the player's cast bar (it moves with the pad layout); the mover can
-- move it from there.
function Swing.Place()
	if holder:IsUserPlaced() then
		return
	end
	holder:ClearAllPoints()
	local castbar = rawget(_G, "Roth_UIPlayerFrameCastBarDragFrame")
	if castbar then
		holder:SetPoint("BOTTOM", castbar, "TOP", 0, Opt("gap", 10))
	else
		holder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 260)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_SWING")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_SWING" then
		Swing.OnSwing(...)
	else
		Swing.Place()
	end
end)
