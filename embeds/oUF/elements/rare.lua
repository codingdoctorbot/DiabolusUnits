
local parent, ns = ...
local oUF = ns.oUF

-- Roth: the target frame's art by classification (target / target_elite /
-- target_boss). On WoW Forever the classification and level can be secret;
-- ns.Secrets turns those into nil, so they read as a plain frame instead of
-- erroring on the comparison. Every other value (normal, trivial, minus)
-- puts the plain art back, so it never sticks from the previous target.
local Update = function(self, event, unit)
	if(unit ~= self.unit) then return end

	local qicon = self.RareIcon
	if(qicon.PreUpdate) then
		qicon:PreUpdate()
	end

	local Secrets = ns.Secrets
	local class = Secrets and Secrets.String(UnitClassification(unit)) or nil
	local level = Secrets and Secrets.Number(UnitLevel(unit)) or nil
	local kind = "normal"
	if class == "worldboss" or level == -1 then
		kind = "boss"
	elseif class == "rare" or class == "rareelite" then
		kind = "rare"
	elseif class == "elite" then
		kind = "elite"
	end
	if kind == "boss" or kind == "rare" then
		qicon:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\target_boss")
	elseif kind == "elite" then
		qicon:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\target_elite")
	else
		qicon:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\target")
	end
	qicon.kind = kind

	if(qicon.PostUpdate) then
		return qicon:PostUpdate(kind)
	end
end

local Path = function(self, ...)
	return (self.RareIcon.Override or Update) (self, ...)
end

local ForceUpdate = function(element)
	return Path(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local Enable = function(self)
	local qicon = self.RareIcon
	if(qicon) then
		qicon.__owner = self
		qicon.ForceUpdate = ForceUpdate

		self:RegisterEvent('UNIT_CLASSIFICATION_CHANGED', Path)

		return true
	end
end

local Disable = function(self)
	if(self.RareIcon) then
		self.RareIcon:Hide()
		self:UnregisterEvent('UNIT_CLASSIFICATION_CHANGED', Path)
	end
end

oUF:AddElement('RareIcon', Path, Enable, Disable)
