--[[ Element: LFD Role Icon

 Toggles visibility of the LFD role icon based upon the units current dungeon
 role.

 Widget

 LFDRole - A Texture containing the LFD role icons at specific locations. Look
           at the default LFD role icon texture for an example of this.
           Alternatively you can look at the return values of
           GetTexCoordsForRoleSmallCircle(role).

 Notes

 The default LFD role texture will be applied if the UI widget is a texture and
 doesn't have a texture or color defined.

 Examples

   -- Position and size
   local LFDRole = self:CreateTexture(nil, "OVERLAY")
   LFDRole:SetSize(16, 16)
   LFDRole:SetPoint("LEFT", self)
   
   -- Register it with oUF
   self.LFDRole = LFDRole

 Hooks

 Override(self) - Used to completely override the internal update function.
                  Removing the table key entry will make the element fall-back
                  to its internal function again.
]]

local parent, ns = ...
local oUF = ns.oUF
local Secrets = ns.Secrets

local roleTexCoords = {
	TANK = { 0, 19/64, 22/64, 41/64 },
	HEALER = { 20/64, 39/64, 1/64, 20/64 },
	DAMAGER = { 20/64, 39/64, 22/64, 41/64 },
}

local Update = function(self, event)
	local lfdrole = self.LFDRole
	if(lfdrole.PreUpdate) then
		lfdrole:PreUpdate()
	end

	local role = Secrets.String(UnitGroupRolesAssigned(self.unit))
	if(role == 'TANK' or role == 'HEALER' or role == 'DAMAGER') then
		if GetTexCoordsForRoleSmallCircle then
			lfdrole:SetTexCoord(GetTexCoordsForRoleSmallCircle(role))
		else
			local coords = roleTexCoords[role]
			lfdrole:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		end
		lfdrole:Show()
	else
		lfdrole:Hide()
	end

	if(lfdrole.PostUpdate) then
		return lfdrole:PostUpdate(role)
	end
end

local Path = function(self, ...)
	return (self.LFDRole.Override or Update) (self, ...)
end

local ForceUpdate = function(element)
	return Path(element.__owner, 'ForceUpdate')
end

local Enable = function(self)
	local lfdrole = self.LFDRole
	if(lfdrole) then
		lfdrole.__owner = self
		lfdrole.ForceUpdate = ForceUpdate

		if(self.unit == "player") then
			self:RegisterEvent("PLAYER_ROLES_ASSIGNED", Path, true)
		else
			self:RegisterEvent("GROUP_ROSTER_UPDATE", Path, true)
		end

		if(lfdrole:IsObjectType"Texture" and not lfdrole:GetTexture()) then
			lfdrole:SetTexture[[Interface\LFGFrame\UI-LFG-ICON-PORTRAITROLES]]
		end

		return true
	end
end

local Disable = function(self)
	local lfdrole = self.LFDRole
	if(lfdrole) then
		lfdrole:Hide()
		self:UnregisterEvent("PLAYER_ROLES_ASSIGNED", Path)
		self:UnregisterEvent("GROUP_ROSTER_UPDATE", Path)
	end
end

oUF:AddElement('LFDRole', Path, Enable, Disable)
