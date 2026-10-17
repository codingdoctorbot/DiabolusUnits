local __, ns = ...
local oUF = ns.oUF or oUF
local Secrets = ns.Secrets
assert(oUF, "oUF Reputation was unable to locate oUF install")

-- Resolve the watched-faction lookup once. Use the compat shim if it's
-- available so we transparently route through C_Reputation.GetWatchedFactionData
-- on clients where the legacy global is gone; otherwise fall back to the
-- legacy global. Re-resolve lazily inside each call to handle late-load order
-- (compat may not be ready when this file is parsed).
local function GetWatched()
	local fn = (ns and ns.Compat and ns.Compat.GetWatchedFactionInfo) or GetWatchedFactionInfo
	if not fn then
		return nil
	end
	return fn()
end

for tag, func in pairs({
	["currep"] = function()
		local _, _, min, _, value = GetWatched()
		local valNum = Secrets and Secrets.Number(value) or (type(value) == "number" and value or nil)
		local minNum = Secrets and Secrets.Number(min) or (type(min) == "number" and min or nil)
		if not valNum or not minNum then
			return 0
		end
		return valNum - minNum
	end,
	["maxrep"] = function()
		local _, _, min, max = GetWatched()
		local maxNum = Secrets and Secrets.Number(max) or (type(max) == "number" and max or nil)
		local minNum = Secrets and Secrets.Number(min) or (type(min) == "number" and min or nil)
		if not minNum or not maxNum then
			return 0
		end
		return maxNum - minNum
	end,
	["perrep"] = function()
		local _, _, min, max, value = GetWatched()
		local valNum = Secrets and Secrets.Number(value) or (type(value) == "number" and value or nil)
		local minNum = Secrets and Secrets.Number(min) or (type(min) == "number" and min or nil)
		local maxNum = Secrets and Secrets.Number(max) or (type(max) == "number" and max or nil)
		if not valNum or not minNum or not maxNum or (maxNum - minNum) <= 0 then
			return 0
		end
		return math.floor((valNum - minNum) / (maxNum - minNum) * 100 + 0.5)
	end,
	["standing"] = function()
		local _, standing = GetWatched()
		local stdNum = Secrets and Secrets.Number(standing) or (type(standing) == "number" and standing or nil)
		if not stdNum then
			return ""
		end
		if type(GetText) == "function" then
			return GetText("FACTION_STANDING_LABEL" .. stdNum, UnitSex("player"))
		end
		return _G["FACTION_STANDING_LABEL" .. stdNum] or tostring(stdNum)
	end,
	["reputation"] = function()
		return GetWatched()
	end,
}) do
	oUF.Tags.Methods[tag] = func
	oUF.Tags.Events[tag] = "UPDATE_FACTION"
end

oUF.Tags.SharedEvents.UPDATE_FACTION = true

local function Update(self, event, unit)
	local reputation = self.Reputation
	if not reputation then
		return
	end

	local name, standing, min, max, value = GetWatched()
	if (not name) or not min or not max or not value then
		return reputation:Hide()
	end
	reputation:Show()

	local valNum = Secrets and Secrets.Number(value) or (type(value) == "number" and value or nil)
	local minNum = Secrets and Secrets.Number(min) or (type(min) == "number" and min or nil)
	local maxNum = Secrets and Secrets.Number(max) or (type(max) == "number" and max or nil)
	local stdNum = Secrets and Secrets.Number(standing) or (type(standing) == "number" and standing or nil)

	if valNum and minNum and maxNum then
		local span = maxNum - minNum
		reputation:SetMinMaxValues(0, span > 0 and span or 1)
		reputation:SetValue(valNum - minNum)
	else
		reputation:SetMinMaxValues(0, 1)
		reputation:SetValue(1)
	end

	if reputation.colorStanding and stdNum then
		-- Guard FACTION_BAR_COLORS lookup — `standing` may be 0 (Hated -1?) or
		-- nil on partial data, in which case the table returns nil and indexing
		-- color.r would error.
		local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[stdNum]
		if color then
			reputation:SetStatusBarColor(color.r, color.g, color.b)
		end
	end

	if reputation.PostUpdate then
		return reputation:PostUpdate(unit, name, standing, min, max, value)
	end
end

local function Path(self, ...)
	return (self.Reputation.Override or Update)(self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, "ForceUpdate", element.__owner.__unit)
end

local function Enable(self, unit)
	local reputation = self.Reputation
	if reputation then
		reputation.__owner = self
		reputation.ForceUpdate = ForceUpdate

		--self:RegisterEvent('UPDATE_FACTION', Path)

		if not reputation:GetStatusBarTexture() then
			reputation:SetStatusBarTexture([=[Interface\TargetingFrame\UI-StatusBar]=])
		end

		return true
	end
end

local function Disable(self)
	if self.Reputation then
		self:UnregisterEvent("UPDATE_FACTION", Path)
	end
end

oUF:AddElement("Reputation", Path, Enable, Disable)
