-- Mana-spend spark for the five-second regeneration rule.
-- Pass cast spell IDs directly to GetSpellPowerCost, as ForeverUnitFrames does.
-- Only readable mana costs start the spark; secret UnitPower values are never inspected.

local _, ns = ...

local cfg = ns.cfg
local Secrets = ns.Secrets

local FiveSecond = {}
ns.FiveSecond = FiveSecond

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"
local RULE = 5
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

local function Plain(v)
	if Secrets.IsSecret(v) then
		return nil
	end
	return v
end

-- Does this spell cost mana? nil when it cannot be told.
function FiveSecond.CostsMana(spellID)
	local get = C_Spell and C_Spell.GetSpellPowerCost
	if type(spellID) == "nil" or not get then
		return nil
	end
	local ok, costs = pcall(get, spellID)
	if not ok or type(costs) ~= "table" then
		return nil
	end
	for _, c in ipairs(costs) do
		local kind, cost = Plain(c.type), c.cost
		-- a secret amount still means the spell has a mana cost
		if kind == MANA and (Secrets.IsSecret(cost) or (type(cost) == "number" and cost > 0)) then
			return true
		end
	end
	return false
end

local function UsesMana()
	return Plain(UnitPowerType("player")) == MANA
end

function FiveSecond.Attach(orb)
	if orb.RothFiveSecond or (cfg.fiveSecondRule == false) then
		return
	end
	local cd = CreateFrame("Cooldown", nil, orb, "CooldownFrameTemplate")
	cd:SetAllPoints(orb)
	cd:SetFrameLevel(orb:GetFrameLevel() + 8)
	cd:SetDrawSwipe(false)
	cd:SetDrawBling(false)
	cd:SetDrawEdge(true)
	cd:SetUseCircularEdge(true)
	cd:SetEdgeTexture(MEDIA .. "orb_spark")
	cd:SetEdgeColor(0.6, 0.8, 1, 0.9)
	cd:SetHideCountdownNumbers(true)
	cd:SetReverse(true)
	orb.RothFiveSecond = cd

	local events = CreateFrame("Frame", nil, orb)
	events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	events:SetScript("OnEvent", function(_, _, _, _, spellID)
		if UsesMana() and FiveSecond.CostsMana(spellID) then
			cd:SetCooldown(GetTime(), RULE)
		end
	end)
	return cd
end
