--[[
# Element: Castbar
Handles the visibility and updating of spell castbars.
Based upon oUF_Castbar by starlon.
## Widget
Castbar - A `StatusBar` to represent spell cast/channel progress.
## Sub-Widgets
.Text     - A `FontString` to represent spell name.
.Icon     - A `Texture` to represent spell icon.
.Time     - A `FontString` to represent spell duration.
.Shield   - A `Texture` to represent if it's possible to interrupt or spell steal.
.SafeZone - A `Texture` to represent latency.
## Notes
A default texture will be applied to the StatusBar and Texture widgets if they don't have a texture or a color set.
## Options
.timeToHold - indicates for how many seconds the castbar should be visible after a _FAILED or _INTERRUPTED
              event. Defaults to 0 (number)
## Examples
    -- Position and size
    local Castbar = CreateFrame('StatusBar', nil, self)
    Castbar:SetSize(20, 20)
    Castbar:SetPoint('TOP')
    Castbar:SetPoint('LEFT')
    Castbar:SetPoint('RIGHT')
    -- Add a background
    local Background = Castbar:CreateTexture(nil, 'BACKGROUND')
    Background:SetAllPoints(Castbar)
    Background:SetTexture(1, 1, 1, .5)
    -- Add a spark
    local Spark = Castbar:CreateTexture(nil, 'OVERLAY')
    Spark:SetSize(20, 20)
    Spark:SetBlendMode('ADD')
    -- Add a timer
    local Time = Castbar:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    Time:SetPoint('RIGHT', Castbar)
    -- Add spell text
    local Text = Castbar:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    Text:SetPoint('LEFT', Castbar)
    -- Add spell icon
    local Icon = Castbar:CreateTexture(nil, 'OVERLAY')
    Icon:SetSize(20, 20)
    Icon:SetPoint('TOPLEFT', Castbar, 'TOPLEFT')
    -- Add Shield
    local Shield = Castbar:CreateTexture(nil, 'OVERLAY')
    Shield:SetSize(20, 20)
    Shield:SetPoint('CENTER', Castbar)
    -- Add safezone
    local SafeZone = Castbar:CreateTexture(nil, 'OVERLAY')
    -- Register it with oUF
    Castbar.bg = Background
    Castbar.Spark = Spark
    Castbar.Time = Time
    Castbar.Text = Text
    Castbar.Icon = Icon
    Castbar.Shield = Shield
    Castbar.SafeZone = SafeZone
    self.Castbar = Castbar
--]]
local _, ns = ...
local oUF = ns.oUF
local Secrets = ns.Secrets
local Compat = ns.Compat

local GetNetStats = GetNetStats
local GetTime = GetTime
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitCastingDuration = UnitCastingDuration
local UnitChannelDuration = UnitChannelDuration

local function safeSpellName(spellID)
	local id = Secrets.Number(spellID)
	if id and Compat then
		return (Compat.GetSpellInfo(id))
	end
	return nil
end

local function updateSafeZone(self)
	local safeZone = self.SafeZone
	local width = self:GetWidth()
	local _, _, _, ms = GetNetStats()

	if not self.max or self.max <= 0 then
		safeZone:Hide()
		return
	end

	local safeZoneRatio = (ms / 1e3) / self.max
	if(safeZoneRatio > 1) then
		safeZoneRatio = 1
	end

	safeZone:SetWidth(width * safeZoneRatio)
	safeZone:Show()
end

local function updateShield(shield, notInterruptible)
	if not shield then return end
	if Secrets.IsSecret(notInterruptible) then
		shield:Show()
		if shield.SetAlphaFromBoolean then
			shield:SetAlphaFromBoolean(notInterruptible, 1, 0)
		end
	elseif notInterruptible then
		if shield.SetAlpha then shield:SetAlpha(1) end
		shield:Show()
	else
		if shield.SetAlpha then shield:SetAlpha(1) end
		shield:Hide()
	end
end

local function UNIT_SPELLCAST_START(self, event, unit)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	local name, text, texture, startTime, endTime, _, castID, notInterruptible, spellID = UnitCastingInfo(unit)
	if(not Secrets.Present(name)) then
		return element:Hide()
	end

	element.casting = true
	element.channeling = nil
	element.holdTime = 0
	element.delay = 0
	element.castID = not Secrets.IsSecret(castID) and castID or nil
	element.notInterruptible = Secrets.Boolean(notInterruptible, false)

	if(Secrets.IsSecret(startTime) or Secrets.IsSecret(endTime)) then
		element._secretCast = true
		element.duration = 0
		element.max = 1
		local durObj = UnitCastingDuration and UnitCastingDuration(unit) or nil
		element._durationObj = durObj
		if(durObj and element.SetTimerDuration) then
			local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
			local dir = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0
			element:SetTimerDuration(durObj, interp, dir)
		else
			element:SetMinMaxValues(startTime, endTime)
			element:SetValue(GetTime() * 1000)
		end
		if(element.SafeZone) then element.SafeZone:Hide() end
	else
		element._secretCast = nil
		element._durationObj = nil
		endTime = endTime / 1e3
		startTime = startTime / 1e3
		local max = endTime - startTime

		element.duration = GetTime() - startTime
		element.max = max

		element:SetMinMaxValues(0, max)
		element:SetValue(0)

		local sf = element.SafeZone
		if(sf) then
			sf:ClearAllPoints()
			sf:SetPoint(element:GetReverseFill() and 'LEFT' or 'RIGHT')
			sf:SetPoint('TOP')
			sf:SetPoint('BOTTOM')
			updateSafeZone(element)
		end
	end

	if(element.Text) then element.Text:SetText(Secrets.Present(text) and text or name) end
	if(element.Icon) then element.Icon:SetTexture(texture) end
	if(element.Time) then element.Time:SetText() end

	updateShield(element.Shield, notInterruptible)

	--[[ Callback: Castbar:PostCastStart(unit, name, castID, spellID)
	Called after the element has been updated upon a spell cast start.
	* self    - the Castbar widget
	* unit    - unit for which the update has been triggered (string)
	* name    - name of the spell being cast (string)
	* castID  - unique identifier of the current spell cast (string)
	* spellID - spell identifier of the spell being cast (number)
	--]]
	if(element.PostCastStart) then
		element:PostCastStart(unit, name, element.castID, Secrets.Number(spellID))
	end
	element:Show()
end

local function UNIT_SPELLCAST_FAILED(self, event, unit, castID, spellID)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	if(not element._secretCast and not Secrets.IsSecret(castID) and element.castID and element.castID ~= castID) then
		return
	end

	local text = element.Text
	if(text) then
		text:SetText(FAILED)
	end

	element.casting = nil
	element._secretCast = nil
	element._durationObj = nil
	element.notInterruptible = nil
	element.holdTime = element.timeToHold or 0

	--[[ Callback: Castbar:PostCastFailed(unit, name, castID, spellID)
	Called after the element has been updated upon a failed spell cast.
	* self    - the Castbar widget
	* unit    - unit for which the update has been triggered (string)
	* name    - name of the failed spell (string)
	* castID  - unique identifier of the failed spell cast (string)
	* spellID - spell identifier of the failed spell (number)
	--]]
	if(element.PostCastFailed) then
		return element:PostCastFailed(unit, safeSpellName(spellID), element.castID, Secrets.Number(spellID))
	end
end

local function UNIT_SPELLCAST_INTERRUPTED(self, event, unit, castID, spellID)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	if(not element._secretCast and not Secrets.IsSecret(castID) and element.castID and element.castID ~= castID) then
		return
	end

	local text = element.Text
	if(text) then
		text:SetText(INTERRUPTED)
	end

	element.casting = nil
	element.channeling = nil
	element._secretCast = nil
	element._durationObj = nil
	element.holdTime = element.timeToHold or 0

	--[[ Callback: Castbar:PostCastInterrupted(unit, name, castID, spellID)
	Called after the element has been updated upon an interrupted spell cast.
	* self    - the Castbar widget
	* unit    - unit for which the update has been triggered (string)
	* name    - name of the interrupted spell (string)
	* castID  - unique identifier of the interrupted spell cast (string)
	* spellID - spell identifier of the interrupted spell (number)
	--]]
	if(element.PostCastInterrupted) then
		return element:PostCastInterrupted(unit, safeSpellName(spellID), element.castID, Secrets.Number(spellID))
	end
end

local function UNIT_SPELLCAST_INTERRUPTIBLE(self, event, unit)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	local shield = element.Shield
	if(shield) then
		if shield.SetAlpha then shield:SetAlpha(1) end
		shield:Hide()
	end

	element.notInterruptible = nil

	--[[ Callback: Castbar:PostCastInterruptible(unit)
	Called after the element has been updated when a spell cast has become interruptible.
	* self - the Castbar widget
	* unit - unit for which the update has been triggered (string)
	--]]
	if(element.PostCastInterruptible) then
		return element:PostCastInterruptible(unit)
	end
end

local function UNIT_SPELLCAST_NOT_INTERRUPTIBLE(self, event, unit)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	local shield = element.Shield
	if(shield) then
		if shield.SetAlpha then shield:SetAlpha(1) end
		shield:Show()
	end

	element.notInterruptible = true

	--[[ Callback: Castbar:PostCastNotInterruptible(unit)
	Called after the element has been updated when a spell cast has become non-interruptible.
	* self - the Castbar widget
	* unit - unit for which the update has been triggered (string)
	--]]
	if(element.PostCastNotInterruptible) then
		return element:PostCastNotInterruptible(unit)
	end
end

local function UNIT_SPELLCAST_DELAYED(self, event, unit, _, spellID)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	local name, _, _, startTime, endTime, _, castID = UnitCastingInfo(unit)
	if(not Secrets.Present(startTime) or not element:IsShown()) then return end

	if(Secrets.IsSecret(startTime) or Secrets.IsSecret(endTime)) then
		element._secretCast = true
		local durObj = UnitCastingDuration and UnitCastingDuration(unit) or nil
		element._durationObj = durObj
		if(durObj and element.SetTimerDuration) then
			local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
			local dir = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0
			element:SetTimerDuration(durObj, interp, dir)
		else
			element:SetMinMaxValues(startTime, endTime)
			element:SetValue(GetTime() * 1000)
		end
	else
		local duration = GetTime() - (startTime / 1000)
		if(duration < 0) then duration = 0 end

		element.delay = element.delay + element.duration - duration
		element.duration = duration

		element:SetValue(duration)
	end

	--[[ Callback: Castbar:PostCastDelayed(unit, name, castID, spellID)
	Called after the element has been updated when a spell cast has been delayed.
	* self    - the Castbar widget
	* unit    - unit that the update has been triggered (string)
	* name    - name of the delayed spell (string)
	* castID  - unique identifier of the delayed spell cast (string)
	* spellID - spell identifier of the delayed spell (number)
	--]]
	if(element.PostCastDelayed) then
		return element:PostCastDelayed(unit, name, not Secrets.IsSecret(castID) and castID or nil, Secrets.Number(spellID))
	end
end

local function UNIT_SPELLCAST_STOP(self, event, unit, castID, spellID)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	if(not element._secretCast and not Secrets.IsSecret(castID) and element.castID and element.castID ~= castID) then
		return
	end

	element.casting = nil
	element._secretCast = nil
	element._durationObj = nil
	element.notInterruptible = nil

	--[[ Callback: Castbar:PostCastStop(unit, name, castID, spellID)
	Called after the element has been updated when a spell cast has finished.
	* self    - the Castbar widget
	* unit    - unit for which the update has been triggered (string)
	* name    - name of the spell (string)
	* castID  - unique identifier of the finished spell cast (string)
	* spellID - spell identifier of the spell (number)
	--]]
	if(element.PostCastStop) then
		return element:PostCastStop(unit, safeSpellName(spellID), element.castID, Secrets.Number(spellID))
	end
end

local function UNIT_SPELLCAST_CHANNEL_START(self, event, unit, _, spellID)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	local name, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
	if(not Secrets.Present(name)) then
		return
	end

	element.channeling = true
	element.casting = nil
	element.castID = nil
	element.delay = 0
	element.holdTime = 0
	element.notInterruptible = Secrets.Boolean(notInterruptible, false)

	if(Secrets.IsSecret(startTime) or Secrets.IsSecret(endTime)) then
		element._secretCast = true
		element.duration = 0
		element.max = 1
		local durObj = UnitChannelDuration and UnitChannelDuration(unit) or nil
		element._durationObj = durObj
		if(durObj and element.SetTimerDuration) then
			local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
			local dir = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
			element:SetTimerDuration(durObj, interp, dir)
		else
			element:SetMinMaxValues(startTime, endTime)
			element:SetValue(GetTime() * 1000)
		end
		if(element.SafeZone) then element.SafeZone:Hide() end
	else
		element._secretCast = nil
		element._durationObj = nil
		endTime = endTime / 1e3
		startTime = startTime / 1e3
		local max = (endTime - startTime)
		local duration = endTime - GetTime()

		element.duration = duration
		element.max = max

		element:SetMinMaxValues(0, max)
		element:SetValue(duration)

		local sf = element.SafeZone
		if(sf) then
			sf:ClearAllPoints()
			sf:SetPoint(element:GetReverseFill() and 'RIGHT' or 'LEFT')
			sf:SetPoint('TOP')
			sf:SetPoint('BOTTOM')
			updateSafeZone(element)
		end
	end

	if(element.Text) then element.Text:SetText(name) end
	if(element.Icon) then element.Icon:SetTexture(texture) end
	if(element.Time) then element.Time:SetText() end

	updateShield(element.Shield, notInterruptible)

	--[[ Callback: Castbar:PostChannelStart(unit, name, spellID)
	Called after the element has been updated upon a spell channel start.
	* self    - the Castbar widget
	* unit    - unit for which the update has been triggered (string)
	* name    - name of the channeled spell (string)
	* spellID - spell identifier of the channeled spell (number)
	--]]
	if(element.PostChannelStart) then
		element:PostChannelStart(unit, name, Secrets.Number(spellID))
	end
	element:Show()
end

local function UNIT_SPELLCAST_CHANNEL_UPDATE(self, event, unit, _, spellID)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	local name, _, _, startTime, endTime = UnitChannelInfo(unit)
	if(not Secrets.Present(name) or not element:IsShown()) then
		return
	end

	if(Secrets.IsSecret(startTime) or Secrets.IsSecret(endTime)) then
		element._secretCast = true
		local durObj = UnitChannelDuration and UnitChannelDuration(unit) or nil
		element._durationObj = durObj
		if(durObj and element.SetTimerDuration) then
			local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
			local dir = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
			element:SetTimerDuration(durObj, interp, dir)
		else
			element:SetMinMaxValues(startTime, endTime)
			element:SetValue(GetTime() * 1000)
		end
	else
		local duration = (endTime / 1000) - GetTime()

		element.delay = element.delay + element.duration - duration
		element.duration = duration
		element.max = (endTime - startTime) / 1000

		element:SetMinMaxValues(0, element.max)
		element:SetValue(duration)
	end

	--[[ Callback: Castbar:PostChannelUpdate(unit, name, spellID)
	Called after the element has been updated after a channeled spell has been delayed or interrupted.
	* self    - the Castbar widget
	* unit    - unit for which the update has been triggered (string)
	* name    - name of the channeled spell (string)
	* spellID - spell identifier of the channeled spell (number)
	--]]
	if(element.PostChannelUpdate) then
		return element:PostChannelUpdate(unit, name, Secrets.Number(spellID))
	end
end

local function UNIT_SPELLCAST_CHANNEL_STOP(self, event, unit, _, spellID)
	if(self.unit ~= unit and self.realUnit ~= unit) then return end

	local element = self.Castbar
	if(element:IsShown()) then
		element.channeling = nil
		element._secretCast = nil
		element._durationObj = nil
		element.notInterruptible = nil

		--[[ Callback: Castbar:PostChannelUpdate(unit, name, spellID)
		Called after the element has been updated after a channeled spell has been completed.
		* self    - the Castbar widget
		* unit    - unit for which the update has been triggered (string)
		* name    - name of the channeled spell (string)
		* spellID - spell identifier of the channeled spell (number)
		--]]
		if(element.PostChannelStop) then
			return element:PostChannelStop(unit, safeSpellName(spellID), Secrets.Number(spellID))
		end
	end
end

local function onUpdate(self, elapsed)
	if(self._secretCast and (self.casting or self.channeling)) then
		local unit = self.__owner.unit
		local activeName = self.casting and UnitCastingInfo(unit) or (self.channeling and UnitChannelInfo(unit))
		if(not Secrets.Present(activeName)) then
			local wasCasting = self.casting
			self.casting = nil
			self.channeling = nil
			self._secretCast = nil
			self._durationObj = nil
			self:Hide()
			if(wasCasting and self.PostCastStop) then
				self:PostCastStop(unit)
			elseif(not wasCasting and self.PostChannelStop) then
				self:PostChannelStop(unit)
			end
			return
		end

		if(self.Time) then
			if(self._durationObj and self._durationObj.GetRemainingDuration) then
				self.Time:SetFormattedText('%.1f', self._durationObj:GetRemainingDuration())
			else
				self.Time:SetText('')
			end
		end

		if(not (self._durationObj and self.SetTimerDuration)) then
			self:SetValue(GetTime() * 1000)
		end

		if(self.Spark) then
			self.Spark:Hide()
		end
		return
	end

	if(self.casting) then
		local duration = self.duration + elapsed
		if(duration >= self.max) then
			self.casting = nil
			self:Hide()

			if(self.PostCastStop) then self:PostCastStop(self.__owner.unit) end
			return
		end

		if(self.Time) then
			if(self.delay ~= 0) then
				if(self.CustomDelayText) then
					self:CustomDelayText(duration)
				else
					self.Time:SetFormattedText('%.1f|cffff0000-%.1f|r', duration, self.delay)
				end
			else
				if(self.CustomTimeText) then
					self:CustomTimeText(duration)
				else
					self.Time:SetFormattedText('%.1f', duration)
				end
			end
		end

		self.duration = duration
		self:SetValue(duration)

		if(self.Spark) then
			self.Spark:Show()
			local horiz = self.horizontal
			local size = self[horiz and 'GetWidth' or 'GetHeight'](self)

			local offset = (duration / self.max) * size
			if(self:GetReverseFill()) then
				offset = size - offset
			end

			self.Spark:SetPoint('CENTER', self, horiz and 'LEFT' or 'BOTTOM', horiz and offset or 0, horiz and 0 or offset)
		end
	elseif(self.channeling) then
		local duration = self.duration - elapsed

		if(duration <= 0) then
			self.channeling = nil
			self:Hide()

			if(self.PostChannelStop) then self:PostChannelStop(self.__owner.unit) end
			return
		end

		if(self.Time) then
			if(self.delay ~= 0) then
				if(self.CustomDelayText) then
					self:CustomDelayText(duration)
				else
					self.Time:SetFormattedText('%.1f|cffff0000-%.1f|r', duration, self.delay)
				end
			else
				if(self.CustomTimeText) then
					self:CustomTimeText(duration)
				else
					self.Time:SetFormattedText('%.1f', duration)
				end
			end
		end

		self.duration = duration
		self:SetValue(duration)
		if(self.Spark) then
			self.Spark:Show()
			local horiz = self.horizontal
			local size = self[horiz and 'GetWidth' or 'GetHeight'](self)

			local offset = (duration / self.max) * size
			if(self:GetReverseFill()) then
				offset = size - offset
			end

			self.Spark:SetPoint('CENTER', self, horiz and 'LEFT' or 'BOTTOM', horiz and offset or 0, horiz and 0 or offset)
		end
	elseif(self.holdTime > 0) then
		self.holdTime = self.holdTime - elapsed
	else
		self.casting = nil
		self.castID = nil
		self.channeling = nil
		self._secretCast = nil
		self._durationObj = nil

		self:Hide()
	end
end

local function Update(self, ...)
	UNIT_SPELLCAST_START(self, ...)
	return UNIT_SPELLCAST_CHANNEL_START(self, ...)
end

local function ForceUpdate(element)
	return Update(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local function Enable(self, unit)
	local element = self.Castbar
	if(element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		if(not (unit and unit:match'%wtarget$')) then
			self:RegisterEvent('UNIT_SPELLCAST_START', UNIT_SPELLCAST_START)
			self:RegisterEvent('UNIT_SPELLCAST_FAILED', UNIT_SPELLCAST_FAILED)
			self:RegisterEvent('UNIT_SPELLCAST_STOP', UNIT_SPELLCAST_STOP)
			self:RegisterEvent('UNIT_SPELLCAST_INTERRUPTED', UNIT_SPELLCAST_INTERRUPTED)
			self:RegisterEvent('UNIT_SPELLCAST_INTERRUPTIBLE', UNIT_SPELLCAST_INTERRUPTIBLE)
			self:RegisterEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', UNIT_SPELLCAST_NOT_INTERRUPTIBLE)
			self:RegisterEvent('UNIT_SPELLCAST_DELAYED', UNIT_SPELLCAST_DELAYED)
			self:RegisterEvent('UNIT_SPELLCAST_CHANNEL_START', UNIT_SPELLCAST_CHANNEL_START)
			self:RegisterEvent('UNIT_SPELLCAST_CHANNEL_UPDATE', UNIT_SPELLCAST_CHANNEL_UPDATE)
			self:RegisterEvent('UNIT_SPELLCAST_CHANNEL_STOP', UNIT_SPELLCAST_CHANNEL_STOP)
		end

		element.horizontal = element:GetOrientation() == 'HORIZONTAL'
		element.holdTime = 0
		element:SetScript('OnUpdate', element.OnUpdate or onUpdate)

		if(self.unit == 'player') then
			local playerCastBar = _G.PlayerCastingBarFrame or _G.CastingBarFrame
			if playerCastBar then
				playerCastBar:UnregisterAllEvents()
				-- Edit Mode system (Hide override): core/blizzsafe.lua
				ns.Blizz.Conceal(playerCastBar)
			end

			if PetCastingBarFrame then
				PetCastingBarFrame:UnregisterAllEvents()
				ns.Blizz.Conceal(PetCastingBarFrame)
			end
		end

		if(element:IsObjectType('StatusBar') and not element:GetStatusBarTexture()) then
			element:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
		end

		local spark = element.Spark
		if(spark and spark:IsObjectType('Texture') and not spark:GetTexture()) then
			spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
		end

		local shield = element.Shield
		if(shield and shield:IsObjectType('Texture') and not shield:GetTexture()) then
			shield:SetTexture([[Interface\CastingBar\UI-CastingBar-Small-Shield]])
		end

		local safeZone = element.SafeZone
		if(safeZone and safeZone:IsObjectType('Texture') and not safeZone:GetTexture()) then
			safeZone:SetColorTexture(1, 0, 0)
		end

		element:Hide()

		return true
	end
end

local function Disable(self)
	local element = self.Castbar
	if(element) then
		element:Hide()

		self:UnregisterEvent('UNIT_SPELLCAST_START', UNIT_SPELLCAST_START)
		self:UnregisterEvent('UNIT_SPELLCAST_FAILED', UNIT_SPELLCAST_FAILED)
		self:UnregisterEvent('UNIT_SPELLCAST_STOP', UNIT_SPELLCAST_STOP)
		self:UnregisterEvent('UNIT_SPELLCAST_INTERRUPTED', UNIT_SPELLCAST_INTERRUPTED)
		self:UnregisterEvent('UNIT_SPELLCAST_INTERRUPTIBLE', UNIT_SPELLCAST_INTERRUPTIBLE)
		self:UnregisterEvent('UNIT_SPELLCAST_NOT_INTERRUPTIBLE', UNIT_SPELLCAST_NOT_INTERRUPTIBLE)
		self:UnregisterEvent('UNIT_SPELLCAST_DELAYED', UNIT_SPELLCAST_DELAYED)
		self:UnregisterEvent('UNIT_SPELLCAST_CHANNEL_START', UNIT_SPELLCAST_CHANNEL_START)
		self:UnregisterEvent('UNIT_SPELLCAST_CHANNEL_UPDATE', UNIT_SPELLCAST_CHANNEL_UPDATE)
		self:UnregisterEvent('UNIT_SPELLCAST_CHANNEL_STOP', UNIT_SPELLCAST_CHANNEL_STOP)

		element:SetScript('OnUpdate', nil)
	end
end

if oUF and oUF.AddElement then
	oUF:AddElement('Castbar', Update, Enable, Disable)
end