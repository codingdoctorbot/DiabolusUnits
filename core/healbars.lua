---------------------------------------------
--  Roth_UI - incoming heals, absorbs, heal absorbs
---------------------------------------------
-- ForeverUnitFrames' method (Elements/HealPrediction.lua, Absorb.lua): on
-- WoW Forever these values are secret (UnitGetIncomingHeals is
-- SecretReturns), so nothing is added, compared or clamped in Lua. Status
-- bars as wide as the health bar and on its scale (0 .. max health) hang
-- from the end of the health fill; the client scales them, and a clipping
-- frame over the health bar cuts them at full health.
--
--   mine        your own incoming heals, bright emerald
--   all         everyone's incoming heals, darker green (what shows past
--               "mine" is other healers')
--   absorb      shields, gold stripes after the incoming heals
--   healAbsorb  necrotic-style "absorb healing" effects, dark red, drawn
--               back over the end of the health
--
-- HealBars.Attach(frame, healthBar) for any oUF frame; a vertical health bar
-- (the raid tiles) gets bars that stack upwards from the top of its fill. It updates on its own
-- events; the frame's health PostUpdate calls HealBars.Update so a new unit
-- (target change, header reassignment) is picked up on oUF's full update.

local _, ns = ...

local cfg = ns.cfg

local HealBars = {}
ns.HealBars = HealBars

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Opt(key, default)
	local h = cfg.healbars
	if h and h[key] ~= nil then
		return h[key]
	end
	return default
end

-- Presence is asked with type(): a secret cannot be tested by truth.
local function Show(bar, amount, maximum)
	if type(amount) == "nil" then
		amount = 0
	end
	if type(maximum) == "nil" then
		maximum = 1
	end
	bar:SetMinMaxValues(0, maximum)
	bar:SetValue(amount)
end

local function Bar(parent, level, r, g, b, a)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetFrameLevel(level)
	bar:SetStatusBarTexture(WHITE)
	bar:SetStatusBarColor(r, g, b, a)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

function HealBars.Update(frame)
	local hb = frame.RothHealBars
	local unit = frame.unit
	if not (hb and unit) then
		return
	end
	local maximum = UnitHealthMax(unit)
	if Opt("heals", true) then
		Show(hb.all, UnitGetIncomingHeals and UnitGetIncomingHeals(unit), maximum)
		Show(hb.mine, UnitGetIncomingHeals and UnitGetIncomingHeals(unit, "player"), maximum)
	end
	if Opt("absorbs", true) then
		Show(hb.absorb, UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit), maximum)
		Show(hb.healAbsorb, UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs(unit), maximum)
	end
end

local function OnEvent(frame, _, unit)
	if unit == frame.unit or (issecretvalue and issecretvalue(unit)) then
		HealBars.Update(frame)
	end
end

-- frame: an oUF frame; health: its health StatusBar.
function HealBars.Attach(frame, health)
	if frame.RothHealBars then
		return frame.RothHealBars
	end
	local fill = health:GetStatusBarTexture()
	local base = health:GetFrameLevel()

	-- everything is cut at the end of the health bar
	local clip = CreateFrame("Frame", nil, health)
	clip:SetClipsChildren(true)
	clip:SetAllPoints(health)
	clip:SetFrameLevel(base + 1)

	local vertical = health.GetOrientation and health:GetOrientation() == "VERTICAL"
	-- where each bar starts: after the end of the one before it
	local function After(bar, prev)
		if vertical then
			bar:SetOrientation("VERTICAL")
			bar:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, 0)
			bar:SetPoint("BOTTOMRIGHT", prev, "TOPRIGHT", 0, 0)
		else
			bar:SetPoint("TOPLEFT", prev, "TOPRIGHT", 0, 0)
			bar:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 0, 0)
		end
	end

	local hb = { clip = clip }
	hb.all = Bar(clip, base + 1, 0.05, 0.55, 0.2, 0.55)
	hb.mine = Bar(clip, base + 2, 0.15, 0.95, 0.35, 0.7)
	for _, bar in ipairs({ hb.all, hb.mine }) do
		After(bar, fill)
	end

	-- shields after all incoming heals: gold, with Roth's stripe overlay
	hb.absorb = Bar(clip, base + 3, 1, 0.82, 0.35, 0.35)
	local after = hb.all:GetStatusBarTexture()
	After(hb.absorb, after)
	local stripes = hb.absorb:CreateTexture(nil, "OVERLAY")
	stripes:SetTexture(MEDIA .. "absorb_statusbar_overlay", "REPEAT", "REPEAT")
	stripes:SetHorizTile(true)
	stripes:SetVertTile(true)
	stripes:SetVertexColor(1, 0.85, 0.4, 0.9)
	stripes:SetAllPoints(hb.absorb:GetStatusBarTexture())

	-- heal absorbs: from the end of the health back over it (reverse fill)
	hb.healAbsorb = Bar(clip, base + 4, 0.35, 0, 0.05, 0.75)
	hb.healAbsorb:SetReverseFill(true)
	if vertical then
		hb.healAbsorb:SetOrientation("VERTICAL")
		hb.healAbsorb:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
		hb.healAbsorb:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
	else
		hb.healAbsorb:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
		hb.healAbsorb:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
	end

	-- The bars are as long as the health bar. Header children have no size
	-- yet when they are built, so follow the bar's size (layout values,
	-- never secret).
	local function Fit(w, h)
		local length = vertical and h or w
		if type(length) == "number" and length > 0 then
			for _, bar in ipairs({ hb.all, hb.mine, hb.absorb, hb.healAbsorb }) do
				if vertical then
					bar:SetHeight(length)
				else
					bar:SetWidth(length)
				end
			end
		end
	end
	health:HookScript("OnSizeChanged", function(_, w, h)
		Fit(w, h)
	end)
	Fit(health:GetWidth(), health:GetHeight())

	frame.RothHealBars = hb
	for _, event in ipairs({ "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_MAXHEALTH" }) do
		frame:RegisterEvent(event, OnEvent)
	end
	if not Opt("heals", true) then
		hb.all:Hide()
		hb.mine:Hide()
	end
	if not Opt("absorbs", true) then
		hb.absorb:Hide()
		hb.healAbsorb:Hide()
	end
	return hb
end
