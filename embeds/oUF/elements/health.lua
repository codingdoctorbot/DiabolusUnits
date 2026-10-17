--[[ Element: Health Bar

 Handles updating of `self.Health` based on the units health.

 Widget

 Health - A StatusBar used to represent current unit health.

 Sub-Widgets

 .bg - A Texture which functions as a background. It will inherit the color of
       the main StatusBar.

 Notes

 The default StatusBar texture will be applied if the UI widget doesn't have a
 status bar texture or color defined.

 Options

 The following options are listed by priority. The first check that returns
 true decides the color of the bar.

 .colorTapping      - Use `self.colors.tapping` to color the bar if the unit
                      isn't tapped by the player.
 .colorDisconnected - Use `self.colors.disconnected` to color the bar if the
                      unit is offline.
 .colorClass        - Use `self.colors.class[class]` to color the bar based on
                      unit class. `class` is defined by the second return of
                      [UnitClass](http://wowprogramming.com/docs/api/UnitClass).
 .colorClassNPC     - Use `self.colors.class[class]` to color the bar if the
                      unit is a NPC.
 .colorClassPet     - Use `self.colors.class[class]` to color the bar if the
                      unit is player controlled, but not a player.
 .colorReaction     - Use `self.colors.reaction[reaction]` to color the bar
                      based on the player's reaction towards the unit.
                      `reaction` is defined by the return value of
                      [UnitReaction](http://wowprogramming.com/docs/api/UnitReaction).
 .colorSmooth       - Use `self.colors.smooth` to color the bar with a smooth
                      gradient based on the player's current health percentage.
 .colorHealth       - Use `self.colors.health` to color the bar. This flag is
                      used to reset the bar color back to default if none of the
                      above conditions are met.

 Sub-Widgets Options

 .multiplier - Defines a multiplier, which is used to tint the background based
               on the main widgets R, G and B values. Defaults to 1 if not
               present.

 Examples

   -- Position and size
   local Health = CreateFrame("StatusBar", nil, self)
   Health:SetHeight(20)
   Health:SetPoint('TOP')
   Health:SetPoint('LEFT')
   Health:SetPoint('RIGHT')

   -- Add a background
   local Background = Health:CreateTexture(nil, 'BACKGROUND')
   Background:SetAllPoints(Health)
   Background:SetTexture(1, 1, 1, .5)

   -- Options
   Health.frequentUpdates = true
   Health.colorTapping = true
   Health.colorDisconnected = true
   Health.colorClass = true
   Health.colorReaction = true
   Health.colorHealth = true

   -- Make the background darker.
   Background.multiplier = .5

   -- Register it with oUF
   self.Health = Health
   self.Health.bg = Background

 Hooks

 Override(self) - Used to completely override the internal update function.
                  Removing the table key entry will make the element fall-back
                  to its internal function again.
]]
local parent, ns = ...
local oUF = ns.oUF
if not oUF or not oUF.colors then return end

local Secrets = ns.Secrets

oUF.colors.health = {49/255, 207/255, 37/255}

local Update = function(self, event, unit)
	local arenaPrep = event == 'ArenaPreparation'
	if(self.unit ~= unit and not arenaPrep) then return end
	local health = self.Health

	if(health.PreUpdate) then health:PreUpdate(unit) end

	local min, max
	if(arenaPrep) then
		min, max = 1, 1
	else
		min, max = UnitHealth(unit), UnitHealthMax(unit)
	end

	local connected = Secrets and Secrets.Boolean(UnitIsConnected(unit), true) or (UnitIsConnected(unit) and true or false)
	local disconnected = not connected
	health:SetMinMaxValues(0, max)

	if(disconnected) then
		health:SetValue(max)
	else
		health:SetValue(min)
	end

	health.disconnected = disconnected

	local isPlayer = Secrets and Secrets.Boolean(UnitIsPlayer(unit), false)
	local isPlayerControlled = Secrets and Secrets.Boolean(UnitPlayerControlled(unit), false)
	local isTapDenied = UnitIsTapDenied and (Secrets and Secrets.Boolean(UnitIsTapDenied(unit), false))
	local reaction = Secrets and Secrets.Number(UnitReaction(unit, 'player'))

	local r, g, b, t
	if(health.colorClass and arenaPrep and GetSpecializationInfoByID and GetArenaOpponentSpec) then
		local _, _, _, _, _, _, class = GetSpecializationInfoByID(GetArenaOpponentSpec(self.id))
		t = self.colors.class[class]
	elseif(health.colorTapping and not isPlayerControlled and isTapDenied) then
		t = self.colors.tapped
	elseif(health.colorDisconnected and disconnected) then
		t = self.colors.disconnected
	elseif(health.colorClass and isPlayer) or
		(health.colorClassNPC and not isPlayer) or
		(health.colorClassPet and isPlayerControlled and not isPlayer) then
		local _, class = UnitClass(unit)
		if Secrets and Secrets.IsSecret(class) then
			r, g, b = Secrets.UnitClassColor(unit)
		elseif class then
			t = self.colors.class[class]
		end
	elseif(health.colorReaction and reaction) then
		t = self.colors.reaction[reaction]
	elseif(health.colorSmooth) then
		local minNum = Secrets and Secrets.Number(min)
		local maxNum = Secrets and Secrets.Number(max)
		if minNum and maxNum then
			r, g, b = self.ColorGradient(minNum, maxNum, unpack(health.smoothGradient or self.colors.smooth))
		else
			t = self.colors.health
		end
	elseif(health.colorHealth) then
		t = self.colors.health
	end

	if(t) then
		r, g, b = t[1], t[2], t[3]
	end

	if(b) then
		health:SetStatusBarColor(r, g, b)

		local bg = health.bg
		if(bg) then local mu = bg.multiplier or 1
			bg:SetVertexColor(r * mu, g * mu, b * mu)
		end
	end

	if(health.PostUpdate) then
		return health:PostUpdate(unit, min, max)
	end
end

local Path = function(self, ...)
	return (self.Health.Override or Update) (self, ...)
end

local ForceUpdate = function(element)
	return Path(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local Enable = function(self, unit)
	local health = self.Health
	if(health) then
		health.__owner = self
		health.ForceUpdate = ForceUpdate

		if(health.frequentUpdates) then
			health._pollTimer = 0
			health._pollInterval = type(health.frequentUpdates) == 'number' and health.frequentUpdates or 0.1
			health:SetScript('OnUpdate', function(bar, elapsed)
				bar._pollTimer = bar._pollTimer + elapsed
				if(bar._pollTimer >= bar._pollInterval) then
					bar._pollTimer = 0
					Path(bar.__owner, 'OnUpdate', bar.__owner.unit)
				end
			end)
		end

		self:RegisterEvent('UNIT_HEALTH', Path)
		self:RegisterEvent("UNIT_MAXHEALTH", Path)
		self:RegisterEvent('UNIT_CONNECTION', Path)

		-- For tapping.
		self:RegisterEvent('UNIT_FACTION', Path)

		if(health:IsObjectType'StatusBar' and not health:GetStatusBarTexture()) then
			health:SetStatusBarTexture[[Interface\TargetingFrame\UI-StatusBar]]
		end

		return true
	end
end

local Disable = function(self)
	local health = self.Health
	if(health) then
		health:Hide()
		health:SetScript('OnUpdate', nil)
		self:UnregisterEvent('UNIT_HEALTH', Path)
		self:UnregisterEvent('UNIT_MAXHEALTH', Path)
		self:UnregisterEvent('UNIT_CONNECTION', Path)
		self:UnregisterEvent('UNIT_FACTION', Path)
	end
end

if oUF and oUF.AddElement then
	oUF:AddElement('Health', Path, Enable, Disable)
end
