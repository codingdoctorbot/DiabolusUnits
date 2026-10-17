--[[ Element: Power Bar

 Handles updating of `self.Power` based upon the units power.

 Widget

 Power - A StatusBar used to represent mana.

 Sub-Widgets

 .bg - A Texture which functions as a background. It will inherit the color of
       the main StatusBar.

 Notes

 The default StatusBar texture will be applied if the UI widget doesn't have a
 status bar texture or color defined.

 Options

 .displayAltPower   - Use this to let the widget display alternate power if the
                      unit has one. If no alternate power the display will fall
                      back to primary power.

 The following options are listed by priority. The first check that returns
 true decides the color of the bar.

 .colorTapping      - Use `self.colors.tapping` to color the bar if the unit
                      isn't tapped by the player.
 .colorDisconnected - Use `self.colors.disconnected` to color the bar if the
                      unit is offline.
 .altPowerColor     - A table containing the RGB values to use for a fixed
                      color if the alt power bar is being displayed instead
 .colorPower        - Use `self.colors.power[token]` to color the bar based on
                      the unit's power type. This method will fall-back to
                      `:GetAlternativeColor()` if it can't find a color matching
                      the token. If this function isn't defined, then it will
                      attempt to color based upon the alternative power colors
                      returned by [UnitPowerType](http://wowprogramming.com/docs/api/UnitPowerType).
                      Finally, if these aren't defined, then it will attempt to
                      color the bar based upon `self.colors.power[type]`.
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

 Sub-Widget Options

 .multiplier - Defines a multiplier, which is used to tint the background based
               on the main widgets R, G and B values. Defaults to 1 if not
               present.

 Examples

   -- Position and size
   local Power = CreateFrame("StatusBar", nil, self)
   Power:SetHeight(20)
   Power:SetPoint('BOTTOM')
   Power:SetPoint('LEFT')
   Power:SetPoint('RIGHT')

   -- Add a background
   local Background = Power:CreateTexture(nil, 'BACKGROUND')
   Background:SetAllPoints(Power)
   Background:SetTexture(1, 1, 1, .5)

   -- Options
   Power.frequentUpdates = true
   Power.colorTapping = true
   Power.colorDisconnected = true
   Power.colorPower = true
   Power.colorClass = true
   Power.colorReaction = true

   -- Make the background darker.
   Background.multiplier = .5

   -- Register it with oUF
   self.Power = Power
   self.Power.bg = Background

 Hooks

 Override(self) - Used to completely override the internal update function.
                  Removing the table key entry will make the element fall-back
                  to its internal function again.
]]

local parent, ns = ...
local oUF = ns.oUF
if not oUF or not oUF.colors then return end

-- WoW Forever's PowerBarColor entries carry extra fields (atlas names,
-- prediction colours, nested bar styles), so read r / g / b where they are
-- numbers and only descend into sub-tables that are colours themselves.
oUF.colors.power = {}
for power, color in next, PowerBarColor do
	if type(power) == "string" and type(color) == "table" then
		if type(color.r) == "number" then
			oUF.colors.power[power] = {color.r, color.g, color.b}
		else
			local sub = {}
			for index, c in next, color do
				if type(c) == "table" and type(c.r) == "number" then
					sub[index] = {c.r, c.g, c.b}
				end
			end
			if next(sub) then
				oUF.colors.power[power] = sub
			end
		end
	end
end

-- sourced from FrameXML/Constants.lua
oUF.colors.power[0] = oUF.colors.power.MANA
oUF.colors.power[1] = oUF.colors.power.RAGE
oUF.colors.power[2] = oUF.colors.power.FOCUS
oUF.colors.power[3] = oUF.colors.power.ENERGY
oUF.colors.power[4] = oUF.colors.power.COMBO_POINTS
oUF.colors.power[5] = oUF.colors.power.RUNES
oUF.colors.power[6] = oUF.colors.power.RUNIC_POWER
oUF.colors.power[7] = oUF.colors.power.SOUL_SHARDS
oUF.colors.power[8] = oUF.colors.power.LUNAR_POWER
oUF.colors.power[9] = oUF.colors.power.HOLY_POWER
oUF.colors.power[11] = oUF.colors.power.MAELSTROM
oUF.colors.power[12] = oUF.colors.power.CHI
oUF.colors.power[13] = oUF.colors.power.INSANITY
oUF.colors.power[16] = oUF.colors.power.ARCANE_CHARGES
oUF.colors.power[17] = oUF.colors.power.FURY
oUF.colors.power[18] = oUF.colors.power.PAIN

local Secrets = ns.Secrets
local ALTERNATE_POWER_INDEX = (Enum and Enum.PowerType and Enum.PowerType.Alternate) or 10

local GetDisplayPower = function(unit)
	if not UnitAlternatePowerInfo then return end
	local _, min, _, _, _, _, showOnRaid = UnitAlternatePowerInfo(unit)
	if Secrets and Secrets.Boolean(showOnRaid) then
		return ALTERNATE_POWER_INDEX, Secrets.Number(min)
	end
end

local Update = function(self, event, unit)
	local arenaPrep = event == 'ArenaPreparation'
	if(self.unit ~= unit and not arenaPrep) then return end
	local power = self.Power

	if(power.PreUpdate) then power:PreUpdate(unit) end

	local displayType, min
	if power.displayAltPower then
		displayType, min = GetDisplayPower(unit)
	end

	local cur, max
	if(arenaPrep) then
		cur, max = 1, 1
	else
		cur, max = UnitPower(unit, displayType), UnitPowerMax(unit, displayType)
	end

	local connected = Secrets and Secrets.Boolean(UnitIsConnected(unit), true) or (UnitIsConnected(unit) and true or false)
	local disconnected = not connected
	power:SetMinMaxValues(min or 0, max)

	if(disconnected) then
		power:SetValue(max)
	else
		power:SetValue(cur)
	end

	power.disconnected = disconnected

	local isPlayer = Secrets and Secrets.Boolean(UnitIsPlayer(unit), false)
	local isPlayerControlled = Secrets and Secrets.Boolean(UnitPlayerControlled(unit), false)
	local isTapDenied = UnitIsTapDenied and (Secrets and Secrets.Boolean(UnitIsTapDenied(unit), false))
	local reaction = Secrets and Secrets.Number(UnitReaction(unit, 'player'))

	local r, g, b, t
	if(power.colorClass and arenaPrep and GetSpecializationInfoByID and GetArenaOpponentSpec) then
		local _, _, _, _, _, _, class = GetSpecializationInfoByID(GetArenaOpponentSpec(self.id))
		t = self.colors.class[class]
	elseif(power.colorTapping and not isPlayerControlled and isTapDenied) then
		t = self.colors.tapped
	elseif(power.colorDisconnected and disconnected) then
		t = self.colors.disconnected
	elseif(displayType == ALTERNATE_POWER_INDEX and power.altPowerColor) then
		t = power.altPowerColor
	elseif(power.colorPower) then
		local ptype, ptoken, altR, altG, altB = UnitPowerType(unit)
		local plainToken = Secrets and Secrets.String(ptoken) or (not (Secrets and Secrets.IsSecret(ptoken)) and ptoken)
		local plainType = Secrets and Secrets.Number(ptype) or (not (Secrets and Secrets.IsSecret(ptype)) and ptype)

		if plainToken then
			t = self.colors.power[plainToken]
		end
		if(not t) then
			if(power.GetAlternativeColor) then
				r, g, b = power:GetAlternativeColor(unit, plainType, plainToken, altR, altG, altB)
			elseif(Secrets and Secrets.Number(altR)) then
				r, g, b = altR, altG, altB
			elseif plainType then
				t = self.colors.power[plainType]
			else
				t = self.colors.power.MANA
			end
		end
	elseif(power.colorClass and isPlayer) or
		(power.colorClassNPC and not isPlayer) or
		(power.colorClassPet and isPlayerControlled and not isPlayer) then
		local _, class = UnitClass(unit)
		if Secrets and Secrets.IsSecret(class) then
			r, g, b = Secrets.UnitClassColor(unit)
		elseif class then
			t = self.colors.class[class]
		end
	elseif(power.colorReaction and reaction) then
		t = self.colors.reaction[reaction]
	elseif(power.colorSmooth) then
		local curNum = Secrets and Secrets.Number(cur)
		local maxNum = Secrets and Secrets.Number(max)
		if curNum and maxNum then
			local adjust = 0 - (min or 0)
			r, g, b = self.ColorGradient(curNum + adjust, maxNum + adjust, unpack(power.smoothGradient or self.colors.smooth))
		end
	end

	if(t) then
		r, g, b = t[1], t[2], t[3]
	end

	if(b) then
		power:SetStatusBarColor(r, g, b)

		local bg = power.bg
		if(bg) then
			local mu = bg.multiplier or 1
			bg:SetVertexColor(r * mu, g * mu, b * mu)
		end
	end

	if(power.PostUpdate) then
		return power:PostUpdate(unit, cur, max, min)
	end
end

local Path = function(self, ...)
	return (self.Power.Override or Update) (self, ...)
end

local ForceUpdate = function(element)
	return Path(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local Enable = function(self, unit)
	local power = self.Power
	if(power) then
		power.__owner = self
		power.ForceUpdate = ForceUpdate

		if(power.frequentUpdates) then
			power._pollTimer = 0
			power._pollInterval = type(power.frequentUpdates) == 'number' and power.frequentUpdates or 0.1
			power:SetScript('OnUpdate', function(bar, elapsed)
				bar._pollTimer = bar._pollTimer + elapsed
				if(bar._pollTimer >= bar._pollInterval) then
					bar._pollTimer = 0
					Path(bar.__owner, 'OnUpdate', bar.__owner.unit)
				end
			end)
		end

		self:RegisterEvent('UNIT_POWER_UPDATE', Path)
		self:RegisterEvent('UNIT_POWER_BAR_SHOW', Path)
		self:RegisterEvent('UNIT_POWER_BAR_HIDE', Path)
		self:RegisterEvent('UNIT_DISPLAYPOWER', Path)
		self:RegisterEvent('UNIT_CONNECTION', Path)
		self:RegisterEvent('UNIT_MAXPOWER', Path)

		-- For tapping.
		self:RegisterEvent('UNIT_FACTION', Path)

		if(power:IsObjectType'StatusBar' and not power:GetStatusBarTexture()) then
			power:SetStatusBarTexture[[Interface\TargetingFrame\UI-StatusBar]]
		end

		return true
	end
end

local Disable = function(self)
	local power = self.Power
	if(power) then
		power:SetScript('OnUpdate', nil)
		self:UnregisterEvent('UNIT_POWER_UPDATE', Path)
		self:UnregisterEvent('UNIT_POWER_BAR_SHOW', Path)
		self:UnregisterEvent('UNIT_POWER_BAR_HIDE', Path)
		self:UnregisterEvent('UNIT_DISPLAYPOWER', Path)
		self:UnregisterEvent('UNIT_CONNECTION', Path)
		self:UnregisterEvent('UNIT_MAXPOWER', Path)
		self:UnregisterEvent('UNIT_FACTION', Path)
	end
end

if oUF and oUF.AddElement then
	oUF:AddElement('Power', Path, Enable, Disable)
end
