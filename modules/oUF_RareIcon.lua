--[[
oUF Element: .RareIcon (DiabolusUnits)

The target frame's art by classification: target (normal), target_elite
(dragon crest) and target_boss (gothic horns, also for rares). On WoW
Forever the classification and level can be secret; ns.Secrets turns those
into nil, so they read as a plain frame instead of erroring on the
comparison. Every other value (normal, trivial, minus) puts the plain art
back, so it never sticks from the previous target.

Widget

RareIcon - a Texture; the element sets its texture.

Callbacks

RareIcon:PreUpdate()
RareIcon:PostUpdate(kind) - kind: "normal", "elite", "rare" or "boss"
RareIcon.Override(self, event, unit)
--]]

local _, ns = ...
local oUF = ns.oUF
local Secrets = ns.Secrets

local MEDIA = "Interface\\AddOns\\DiabolusForever\\media\\"

local function Update(self, event, unit)
	if unit ~= self.__unit then
		return
	end

	local element = self.RareIcon
	if element.PreUpdate then
		element:PreUpdate()
	end

	local class = Secrets.String(UnitClassification(unit))
	local level = Secrets.Number(UnitLevel(unit))
	local kind = "normal"
	if class == "worldboss" or level == -1 then
		kind = "boss"
	elseif class == "rare" or class == "rareelite" then
		kind = "rare"
	elseif class == "elite" then
		kind = "elite"
	end
	if kind == "boss" or kind == "rare" then
		element:SetTexture(MEDIA .. "target_boss")
	elseif kind == "elite" then
		element:SetTexture(MEDIA .. "target_elite")
	else
		element:SetTexture(MEDIA .. "target")
	end
	element.kind = kind

	if element.PostUpdate then
		return element:PostUpdate(kind)
	end
end

local function Path(self, ...)
	return (self.RareIcon.Override or Update)(self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, "ForceUpdate", element.__owner.__unit)
end

local function Enable(self)
	local element = self.RareIcon
	if element then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", Path)

		return true
	end
end

local function Disable(self)
	local element = self.RareIcon
	if element then
		element:Hide()
		self:UnregisterEvent("UNIT_CLASSIFICATION_CHANGED", Path)
	end
end

oUF:AddElement("RareIcon", Path, Enable, Disable)
