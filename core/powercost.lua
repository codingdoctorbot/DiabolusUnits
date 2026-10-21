-- Preview a cast's power cost with a cropped slice of the orb fill.
-- Requires readable power, maximum, and cost; hides for secret values and instant spells.
-- Reference: ForeverUnitFrames Elements/PowerCost.lua.

local _, ns = ...

local cfg = ns.cfg
local Secrets = ns.Secrets

local PowerCost = {}
ns.PowerCost = PowerCost

local ENDS = {
	UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_SUCCEEDED = true,
}

-- The plain cost of spellID in the player's current power type, or nil.
function PowerCost.Cost(spellID)
	local get = C_Spell and C_Spell.GetSpellPowerCost
	if type(spellID) == "nil" or not get then
		return nil
	end
	local ok, costs = pcall(get, spellID)
	if not ok or type(costs) ~= "table" then
		return nil
	end
	local powerType = Secrets.Number(UnitPowerType("player"))
	for _, info in ipairs(costs) do
		if Secrets.Number(info.type) == powerType and powerType ~= nil then
			local cost = Secrets.Number(info.cost)
			return (cost and cost > 0) and cost or nil
		end
	end
	return nil
end

-- Where the band goes, as fractions of the orb's height from the top:
-- top, bottom; nil when it cannot be shown.
function PowerCost.Band(value, max, cost)
	value, max, cost = Secrets.Number(value), Secrets.Number(max), Secrets.Number(cost)
	if not (value and max and cost) or max <= 0 or value <= 0 then
		return nil
	end
	local top = 1 - math.min(value, max) / max
	local bottom = math.min(1, top + cost / max)
	return top, bottom
end

local function Draw(orb)
	local pc = orb.RothCost
	local fill = orb.fill
	local top, bottom
	if pc.cost then
		local _, max = fill:GetMinMaxValues()
		top, bottom = PowerCost.Band(fill:GetValue(), max, pc.cost)
	end
	if not top then
		pc.band:Hide()
		return
	end
	local size = orb.size
	pc.band:ClearAllPoints()
	pc.band:SetPoint("TOPLEFT", orb, "TOPLEFT", 0, -top * size)
	pc.band:SetPoint("TOPRIGHT", orb, "TOPRIGHT", 0, -top * size)
	pc.band:SetHeight(math.max(1, (bottom - top) * size))
	pc.band:SetTexCoord(0, 1, top, bottom)
	pc.band:Show()
end
PowerCost.Draw = Draw

function PowerCost.Attach(orb, texture)
	if orb.RothCost or cfg.powerCost == false then
		return
	end
	local layer = CreateFrame("Frame", nil, orb)
	layer:SetAllPoints(orb)
	layer:SetFrameLevel(orb:GetFrameLevel() + 6)
	local band = layer:CreateTexture(nil, "OVERLAY", nil, 1)
	band:SetTexture(texture)
	band:SetBlendMode("ADD")
	band:SetVertexColor(1, 1, 1, 0.45)
	band:Hide()
	local pulse = band:CreateAnimationGroup()
	local a = pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.4)
	a:SetDuration(0.6)
	pulse:SetLooping("BOUNCE")
	pulse:Play()
	orb.RothCost = { band = band }

	orb.fill:HookScript("OnValueChanged", function()
		if orb.RothCost.cost then
			Draw(orb)
		end
	end)

	local events = CreateFrame("Frame", nil, orb)
	events:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
	for event in pairs(ENDS) do
		events:RegisterUnitEvent(event, "player")
	end
	events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	events:SetScript("OnEvent", function(_, event, _, _, spellID)
		if event == "UNIT_SPELLCAST_START" then
			orb.RothCost.cost = PowerCost.Cost(spellID)
		else
			orb.RothCost.cost = nil
		end
		Draw(orb)
	end)
end
