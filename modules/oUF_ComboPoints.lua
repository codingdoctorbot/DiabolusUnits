local parent, ns = ...
local oUF = ns.oUF or oUF

local class = (ns.Secrets and ns.Secrets.String(select(2, UnitClass("player")))) or select(2, UnitClass("player"))
local comboPowerType = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4

local Update = function(self, event, unit, powerType)
	local bar = self.ComboBar
	if not bar or not self.ComboPoints then
		return
	end
	local max = 5
	if UnitPowerMax then
		local maxPower = ns.Secrets and ns.Secrets.Number(UnitPowerMax("player", comboPowerType))
			or UnitPowerMax("player", comboPowerType)
		if maxPower and maxPower > 0 then
			max = maxPower
		end
	end
	local w = 64 * (max + 2)
	bar:SetWidth(w)

	local num = UnitPower("player", comboPowerType)
	local numNum = ns.Secrets and ns.Secrets.Number(num) or (type(num) == "number" and num or nil)

	for i = 1, #self.ComboPoints do
		local orb = self.ComboPoints[i]
		if orb then
			if i > max then
				if orb:IsShown() then
					orb:Hide()
				end
			else
				if not orb:IsShown() then
					orb:Show()
				end
			end
		end
	end

	if numNum ~= nil then
		local full = (max > 0) and (numNum / max) or 0
		for i = 1, max do
			local orb = self.ComboPoints[i]
			if orb then
				if i <= numNum then
					if full >= 1 then
						orb.fill:SetVertexColor(1, 0, 0)
						orb.glow:SetVertexColor(1, 0, 0)
					else
						orb.fill:SetVertexColor(bar.color.r, bar.color.g, bar.color.b)
						orb.glow:SetVertexColor(bar.color.r, bar.color.g, bar.color.b)
					end
					orb.fill:Show()
					orb.glow:Show()
					orb.highlight:Show()
				else
					orb.fill:Hide()
					orb.glow:Hide()
					orb.highlight:Hide()
				end
			end
		end
	else
		for i = 1, max do
			local orb = self.ComboPoints[i]
			if orb then
				orb.fill:SetVertexColor(bar.color.r, bar.color.g, bar.color.b)
				orb.glow:SetVertexColor(bar.color.r, bar.color.g, bar.color.b)
				orb.fill:Show()
				orb.glow:Show()
				orb.highlight:Show()
				local curve = ns.Secrets and ns.Secrets.ComboOrbCurve and ns.Secrets.ComboOrbCurve(i, max)
				local active = (curve and type(UnitPowerPercent) == "function")
						and UnitPowerPercent("player", comboPowerType, false, curve)
					or nil
				if active ~= nil and orb.fill.SetAlphaFromBoolean then
					orb.fill:SetAlphaFromBoolean(active, 1, 0)
					orb.glow:SetAlphaFromBoolean(active, 1, 0)
					orb.highlight:SetAlphaFromBoolean(active, 1, 0)
				else
					orb.fill:Hide()
					orb.glow:Hide()
					orb.highlight:Hide()
				end
			end
		end
	end
end

-- Cat Form is not a fixed form index (a druid without Aquatic Form has it at
-- 2, not 3); Cat Form is the form that turns a druid's power into energy.
local ENERGY = (Enum and Enum.PowerType and Enum.PowerType.Energy) or 3
local function IsCatForm()
	local powerType = ns.Secrets.Number(UnitPowerType("player"))
	return powerType == ENERGY
end

local Visibility = function(self, event, unit)
	local element = self.ComboPoints
	local bar = self.ComboBar
	if class == "ROGUE" or (class == "DRUID" and IsCatForm()) then
		bar:Show()
		element.ForceUpdate(element)
	else
		bar:Hide()
	end
end

local Path = function(self, ...)
	return (self.ComboPoints.Override or Update)(self, ...)
end

local ForceUpdate = function(element)
	return Path(element.__owner, "ForceUpdate", element.__owner.unit, "COMBO_POINTS")
end

local function Enable(self, unit)
	local element = self.ComboPoints
	if element and unit == "player" then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		self:RegisterEvent("UNIT_POWER_FREQUENT", Path)
		self:RegisterEvent("UNIT_DISPLAYPOWER", Path)
		self:RegisterEvent("UNIT_DISPLAYPOWER", Visibility)
		self:RegisterEvent("SPELLS_CHANGED", Visibility, true)
		self:RegisterEvent("UNIT_ENTERED_VEHICLE", Visibility)
		self:RegisterEvent("UNIT_EXITED_VEHICLE", Visibility)
		self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", Visibility)

		local helper = CreateFrame("Frame") --this is needed...adding player_login to the visivility events does not do anything
		helper:RegisterEvent("PLAYER_ENTERING_WORLD")
		helper:SetScript("OnEvent", function()
			Visibility(self)
		end)
		--    helper:SetScript("OnEvent", function() Update(self) end)

		return true
	end
end

local function Disable(self)
	local element = self.ComboPoints
	if element then
		self:UnregisterEvent("UNIT_POWER_FREQUENT", Path)
		self:UnregisterEvent("UNIT_DISPLAYPOWER", Path)
		self:UnregisterEvent("SPELLS_CHANGED", Visibility)
		self:UnregisterEvent("UNIT_ENTERED_VEHICLE", Visibility)
		self:UnregisterEvent("UNIT_EXITED_VEHICLE", Visibility)
		self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM", Visibility)
		self:UnregisterEvent("UNIT_DISPLAYPOWER", Visibility)
	end
end

oUF:AddElement("ComboPoints", Path, Enable, Disable)
