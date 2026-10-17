local __, ns = ...
local oUF = ns.oUF or oUF
local Secrets = ns.Secrets
assert(oUF, "oUF Experience was unable to locate oUF install")

for tag, func in pairs({
	["curxp"] = function(unit)
		return UnitXP(unit)
	end,
	["maxxp"] = function(unit)
		return UnitXPMax(unit)
	end,
	["perxp"] = function(unit)
		local cur = Secrets and Secrets.Number(UnitXP(unit)) or UnitXP(unit)
		local max = Secrets and Secrets.Number(UnitXPMax(unit)) or UnitXPMax(unit)
		if cur and max and max > 0 then
			return math.floor(cur / max * 100 + 0.5)
		end
		return 0
	end,
	["currested"] = function()
		return GetXPExhaustion()
	end,
	["perrested"] = function(unit)
		local rested = Secrets and Secrets.Number(GetXPExhaustion()) or GetXPExhaustion()
		local max = Secrets and Secrets.Number(UnitXPMax(unit)) or UnitXPMax(unit)
		if rested and max and max > 0 and rested > 0 then
			return math.floor(rested / max * 100 + 0.5)
		end
		return 0
	end,
}) do
	oUF.Tags.Methods[tag] = func
	oUF.Tags.Events[tag] = "PLAYER_XP_UPDATE PLAYER_LEVEL_UP UPDATE_EXHAUSTION"
end

local function Update(self, event, unit)
	if self.unit ~= unit then
		return
	end

	local experience = self.Experience
	if experience.PreUpdate then
		experience:PreUpdate(unit)
	end
	experience:Show()

	local min, max = UnitXP(unit), UnitXPMax(unit)
	local minNum = Secrets and Secrets.Number(min) or (type(min) == "number" and min or nil)
	local maxNum = Secrets and Secrets.Number(max) or (type(max) == "number" and max or nil)

	experience:SetMinMaxValues(0, max or 1)
	experience:SetValue(min or 0)

	if experience.Rested then
		local exhaustion = GetXPExhaustion()
		local exhNum = Secrets and Secrets.Number(exhaustion) or (type(exhaustion) == "number" and exhaustion or nil)
		experience.Rested:SetMinMaxValues(0, max or 1)
		if minNum and maxNum and exhNum then
			experience.Rested:SetValue(math.min(minNum + exhNum, maxNum))
		elseif Secrets and Secrets.Present(exhaustion) and Secrets.Present(min) then
			experience.Rested:SetValue(min)
		else
			experience.Rested:SetValue(0)
		end
	end

	if experience.PostUpdate then
		return experience:PostUpdate(unit, min, max)
	end
end

local function Path(self, ...)
	return (self.Experience.Override or Update)(self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, "ForceUpdate", element.__owner.unit)
end

local function Enable(self, unit)
	local experience = self.Experience
	if experience then
		experience.__owner = self
		experience.ForceUpdate = ForceUpdate

		self:RegisterEvent("PLAYER_XP_UPDATE", Path)
		self:RegisterEvent("PLAYER_LEVEL_UP", Path)

		local rested = experience.Rested
		if rested then
			self:RegisterEvent("UPDATE_EXHAUSTION", Path)
			rested:SetFrameLevel(experience:GetFrameLevel() - 1)

			if not rested:GetStatusBarTexture() then
				rested:SetStatusBarTexture([=[Interface\TargetingFrame\UI-StatusBar]=])
			end
		end

		if not experience:GetStatusBarTexture() then
			experience:SetStatusBarTexture([=[Interface\TargetingFrame\UI-StatusBar]=])
		end

		return true
	end
end

local function Disable(self)
	local experience = self.Experience
	if experience then
		self:UnregisterEvent("PLAYER_XP_UPDATE", Path)
		self:UnregisterEvent("PLAYER_LEVEL_UP", Path)

		if experience.Rested then
			self:UnregisterEvent("UPDATE_EXHAUSTION", Path)
		end
	end
end

oUF:AddElement("Experience", Path, Enable, Disable)
