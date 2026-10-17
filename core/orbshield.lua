---------------------------------------------
--  Roth_UI - shield on the health orb
---------------------------------------------
-- Your absorb shields as a pale gold crescent up the right rim of the health
-- orb (media/orb_absorb_glow, Roth's own art): the bigger the shields
-- against your maximum health, the higher it climbs; no shield, no
-- crescent.
--
-- Your health and absorbs are secret on WoW Forever, so nothing is compared
-- in Lua: the crescent is the fill of a vertical StatusBar on the scale
-- 0 .. max health, and both values go to it as they come
-- (ForeverUnitFrames' Absorb.lua does the same on its bars).

local _, ns = ...

local cfg = ns.cfg

local OrbShield = {}
ns.OrbShield = OrbShield

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"

function OrbShield.Update(orb)
	local bar = orb.RothShield
	if not bar then
		return
	end
	local max = UnitHealthMax("player")
	local amount = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("player")
	-- presence by type(): a secret cannot be tested by truth
	if type(max) == "nil" then
		max = 1
	end
	if type(amount) == "nil" then
		amount = 0
	end
	bar:SetMinMaxValues(0, max)
	bar:SetValue(amount)
end

function OrbShield.Attach(orb)
	if orb.RothShield or cfg.orbShield == false then
		return
	end
	local bar = CreateFrame("StatusBar", nil, orb)
	bar:SetAllPoints(orb)
	bar:SetFrameLevel(orb:GetFrameLevel() + 7)
	bar:SetOrientation("VERTICAL")
	bar:SetStatusBarTexture(MEDIA .. "orb_absorb_glow")
	bar:SetStatusBarColor(1, 0.9, 0.6, 0.95)
	bar:GetStatusBarTexture():SetBlendMode("ADD")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	orb.RothShield = bar

	local events = CreateFrame("Frame", nil, orb)
	events:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
	events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:SetScript("OnEvent", function()
		OrbShield.Update(orb)
	end)
	OrbShield.Update(orb)
	return bar
end
