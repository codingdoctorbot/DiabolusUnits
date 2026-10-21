-- API Compatibility Module for WoW Forever (16001) & Modern Engine
-- Provides wrapper functions for deprecated/structured APIs and secret-safe helpers

local _, ns = ...

local Compat = {}
ns.Compat = Compat

local Secrets = ns.Secrets
local type = type
local pcall = pcall
local select = select
local math_floor = math.floor

-- REPUTATION API COMPATIBILITY

-- Wrapper for GetWatchedFactionInfo
-- Returns: name, standing, min, max, value, factionID
function Compat.GetWatchedFactionInfo()
	if GetWatchedFactionInfo then
		return GetWatchedFactionInfo()
	end
	if C_Reputation and C_Reputation.GetWatchedFactionData then
		local data = C_Reputation.GetWatchedFactionData()
		if data then
			return data.name,
				data.reaction,
				data.currentReactionThreshold,
				data.nextReactionThreshold,
				data.currentStanding,
				data.factionID
		end
	end
	return nil
end

function Compat.GetFactionInfo(index)
	if GetFactionInfo then
		return GetFactionInfo(index)
	end
	if C_Reputation and C_Reputation.GetFactionDataByIndex then
		local data = C_Reputation.GetFactionDataByIndex(index)
		if data then
			return data.name,
				data.description,
				data.reaction,
				data.currentReactionThreshold,
				data.nextReactionThreshold,
				data.currentStanding,
				data.atWarWith,
				data.canToggleAtWar,
				data.isHeader,
				data.isCollapsed,
				data.hasRep,
				data.isWatched,
				data.isChild,
				data.factionID,
				data.hasBonusRepGain,
				data.canSetInactive
		end
	end
	return nil
end

-- ADDON MANAGEMENT API COMPATIBILITY

function Compat.GetNumAddOns()
	if GetNumAddOns then
		return GetNumAddOns()
	end
	if C_AddOns and C_AddOns.GetNumAddOns then
		return C_AddOns.GetNumAddOns()
	end
	return 0
end

function Compat.LoadAddOn(addonName)
	if LoadAddOn then
		return LoadAddOn(addonName)
	end
	if C_AddOns and C_AddOns.LoadAddOn then
		return C_AddOns.LoadAddOn(addonName)
	end
	return false
end

function Compat.IsAddOnLoaded(addonName)
	if IsAddOnLoaded then
		return IsAddOnLoaded(addonName)
	end
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(addonName)
	end
	return false
end

function Compat.GetAddOnMetadata(addonName, field)
	if GetAddOnMetadata then
		return GetAddOnMetadata(addonName, field)
	end
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(addonName, field)
	end
	return nil
end

function Compat.GetAddOnInfo(index)
	if GetAddOnInfo then
		return GetAddOnInfo(index)
	end
	if C_AddOns and C_AddOns.GetAddOnInfo then
		return C_AddOns.GetAddOnInfo(index)
	end
	return nil, nil, nil, nil, nil, nil, nil, nil
end

function Compat.GetAddOnMemoryUsage(index)
	if GetAddOnMemoryUsage then
		return GetAddOnMemoryUsage(index)
	end
	return 0
end

-- The level cap. WoW Forever has no MAX_PLAYER_LEVEL global (only the
-- Vanilla reputation frame sets it, to 0): ask the game instead.
function Compat.MaxPlayerLevel()
	for _, name in ipairs({ "GetMaxPlayerLevel", "GetMaxLevelForPlayerExpansion" }) do
		local fn = rawget(_G, name)
		if type(fn) == "function" then
			local ok, level = pcall(fn)
			if ok and type(level) == "number" and not (Secrets and Secrets.IsSecret(level)) and level > 0 then
				return level
			end
		end
	end
	local global = rawget(_G, "MAX_PLAYER_LEVEL")
	if type(global) == "number" and global > 0 then
		return global
	end
	return 60
end

-- SPELL API COMPATIBILITY

-- The game's own GetSpellInfo, if it has one (WoW Forever does not). Captured
-- at load: Roth used to install Compat.GetSpellInfo as the global and then
-- call the global from inside it, which recursed until the script timed out.
local nativeGetSpellInfo = rawget(_G, "GetSpellInfo")

function Compat.GetSpellInfo(spellIdentifier)
	if not spellIdentifier or (Secrets and Secrets.IsSecret(spellIdentifier)) then
		return nil
	end
	if nativeGetSpellInfo then
		return nativeGetSpellInfo(spellIdentifier)
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, spellIdentifier)
		if ok and info then
			return info.name,
				nil,
				info.iconID,
				info.castTime,
				info.minRange,
				info.maxRange,
				info.spellID,
				info.originalIconID
		end
	end
	return nil
end

-- AURA API COMPATIBILITY (C_UnitAuras)

local function NormalizeFilter(filter)
	if not filter or filter == "" then
		return "HELPFUL"
	end
	if not filter:find("HELPFUL") and not filter:find("HARMFUL") then
		return "HELPFUL|" .. filter
	end
	return filter
end

local function UnpackAuraDataSafe(aura)
	if type(aura) ~= "table" or (Secrets and Secrets.IsSecret(aura)) then
		return nil
	end
	if not (Secrets and Secrets.Present(aura.name)) and aura.name == nil then
		return nil
	end
	local plainName = Secrets and Secrets.String(aura.name)
	if plainName and plainName == "" then
		return nil
	end
	local name = aura.name
	local icon = aura.icon
	local count = (Secrets and Secrets.Number(aura.applications))
	if count == nil then
		count = aura.applications
	end
	local dispelName = aura.dispelName
	local duration = (Secrets and Secrets.Number(aura.duration))
	if duration == nil then
		duration = aura.duration
	end
	local expirationTime = (Secrets and Secrets.Number(aura.expirationTime))
	if expirationTime == nil then
		expirationTime = aura.expirationTime
	end
	local sourceUnit = aura.sourceUnit
	local isStealable = (Secrets and Secrets.Boolean(aura.isStealable, false))
	if isStealable == nil then
		isStealable = aura.isStealable
	end
	local spellId = (Secrets and Secrets.Number(aura.spellId))
	if spellId == nil then
		spellId = aura.spellId
	end
	local isBossAura = (Secrets and Secrets.Boolean(aura.isBossAura, false))
	if isBossAura == nil then
		isBossAura = aura.isBossAura
	end
	local canApplyAura = (Secrets and Secrets.Boolean(aura.canApplyAura, false))
	if canApplyAura == nil then
		canApplyAura = aura.canApplyAura
	end
	local isFromPlayerOrPlayerPet = (Secrets and Secrets.Boolean(aura.isFromPlayerOrPlayerPet, false))
	if isFromPlayerOrPlayerPet == nil then
		isFromPlayerOrPlayerPet = aura.isFromPlayerOrPlayerPet
	end
	local auraInstanceID = (Secrets and Secrets.Number(aura.auraInstanceID))
	if auraInstanceID == nil then
		auraInstanceID = aura.auraInstanceID
	end

	return name,
		icon,
		count,
		dispelName,
		duration,
		expirationTime,
		sourceUnit,
		isStealable,
		nil, -- shouldConsolidate / nameplateShowPersonal
		spellId,
		canApplyAura,
		isBossAura,
		isFromPlayerOrPlayerPet,
		nil, -- nameplateShowAll
		nil, -- timeMod
		auraInstanceID
end

function Compat.GetAuraDataByIndex(unit, index, filter)
	if not unit or not index or index < 1 or (Secrets and Secrets.IsSecret(unit)) then
		return nil
	end
	filter = NormalizeFilter(filter)
	if C_UnitAuras then
		if C_UnitAuras.GetAuraDataByIndex then
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
			if
				ok
				and type(aura) == "table"
				and not (Secrets and Secrets.IsSecret(aura))
				and (Secrets and Secrets.Present(aura.name) or aura.name ~= nil)
			then
				return aura
			end
		end
		if C_UnitAuras.GetUnitAuras then
			local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
			if ok and type(list) == "table" and not (Secrets and Secrets.IsSecret(list)) then
				local aura = list[index]
				if
					aura
					and type(aura) == "table"
					and not (Secrets and Secrets.IsSecret(aura))
					and (Secrets and Secrets.Present(aura.name) or aura.name ~= nil)
				then
					return aura
				end
			end
		end
	end
	return nil
end

local nativeUnitAura, nativeUnitBuff, nativeUnitDebuff =
	rawget(_G, "UnitAura"), rawget(_G, "UnitBuff"), rawget(_G, "UnitDebuff")

function Compat.UnitAura(unit, index, filter)
	if nativeUnitAura then
		return nativeUnitAura(unit, index, filter)
	end
	local aura = Compat.GetAuraDataByIndex(unit, index, filter)
	if aura then
		return UnpackAuraDataSafe(aura)
	end
	return nil
end

function Compat.UnitBuff(unit, index, filter)
	if nativeUnitBuff then
		return nativeUnitBuff(unit, index, filter)
	end
	if not filter or filter == "" then
		return Compat.UnitAura(unit, index, "HELPFUL")
	elseif not filter:find("HELPFUL") then
		return Compat.UnitAura(unit, index, "HELPFUL|" .. filter)
	end
	return Compat.UnitAura(unit, index, filter)
end

function Compat.UnitDebuff(unit, index, filter)
	if nativeUnitDebuff then
		return nativeUnitDebuff(unit, index, filter)
	end
	if not filter or filter == "" then
		return Compat.UnitAura(unit, index, "HARMFUL")
	elseif not filter:find("HARMFUL") then
		return Compat.UnitAura(unit, index, "HARMFUL|" .. filter)
	end
	return Compat.UnitAura(unit, index, filter)
end

-- No global fallbacks: a global function written by Roth taints whatever
-- Blizzard code calls it, and Roth's own code uses ns.Compat directly.
-- (oUF's master looter element finds C_PartyInfo.GetLootMethod itself.)

-- SECRET-SAFE ACTION BUTTON UPDATER

function Compat.UpdateActionButton(button, buttonIndex, lastCooldownState, lastCurrentAction)
	if not button then
		return
	end
	local action = button:GetAttribute("action") or button.action
	if not action or not HasAction(action) then
		if button.icon then
			button.icon:Hide()
		end
		return
	end

	local texture = GetActionTexture(action)
	if ns.DiabloIcons and ns.DiabloIcons:IsEnabled() then
		local diabloTex = ns.DiabloIcons:GetCustomIcon(action)
		if diabloTex then
			texture = diabloTex
		end
	end
	if button.icon and Secrets.Present(texture) then
		button.icon:SetTexture(texture)
		button.icon:Show()

		local isUsable, notEnoughMana = IsUsableAction(action)
		local inRange = IsActionInRange(action)
		local usableBool = Secrets.Boolean(isUsable, true)
		local oomBool = Secrets.Boolean(notEnoughMana, false)
		local rangeBool = (type(inRange) ~= "nil" and not Secrets.IsSecret(inRange)) and inRange or nil
		if rangeBool == false then
			button.icon:SetVertexColor(1.0, 0.1, 0.1)
		elseif oomBool then
			button.icon:SetVertexColor(0.1, 0.3, 1.0)
		elseif usableBool then
			button.icon:SetVertexColor(1.0, 1.0, 1.0)
		else
			button.icon:SetVertexColor(0.4, 0.4, 0.4)
		end
	end

	local start, duration, isActive
	if C_ActionBar and type(C_ActionBar.GetActionCooldown) == "function" then
		local ok, info = pcall(C_ActionBar.GetActionCooldown, action)
		if ok and type(info) == "table" and not Secrets.IsSecret(info) then
			start, duration = info.startTime, info.duration
			isActive = Secrets.Boolean(info.isActive, nil)
		end
	elseif GetActionCooldown then
		local a, b = GetActionCooldown(action)
		if type(a) == "table" and not Secrets.IsSecret(a) then
			start, duration = a.startTime, a.duration
			isActive = Secrets.Boolean(a.isActive, nil)
		else
			start, duration = a, b
		end
	end

	local startNum = Secrets.Number(start)
	local durNum = Secrets.Number(duration)

	if buttonIndex and lastCurrentAction then
		local isCurrent = Secrets.Boolean(IsCurrentAction and IsCurrentAction(action), false)
		if isCurrent and not lastCurrentAction[buttonIndex] then
			-- Blizzard's action buttons carry Flash as a texture, not a method
			if type(button.Flash) == "function" then
				button:Flash()
			end
		end
		lastCurrentAction[buttonIndex] = isCurrent
	end

	if buttonIndex and lastCooldownState and lastCooldownState[buttonIndex] ~= nil then
		local newCooldownStart = 0
		if startNum and durNum then
			if startNum > 0 and durNum > 0.5 then
				newCooldownStart = startNum
			end
		elseif isActive then
			newCooldownStart = 1
		end
		if newCooldownStart > 0 and lastCooldownState[buttonIndex] == 0 then
			-- Blizzard's action buttons carry Flash as a texture, not a method
			if type(button.Flash) == "function" then
				button:Flash()
			end
		end
		lastCooldownState[buttonIndex] = newCooldownStart
	end

	if button.cooldownText then
		if startNum and durNum and durNum > 1.5 and startNum > 0 then
			local remaining = (startNum + durNum) - GetTime()
			if remaining > 0 then
				if remaining > 60 then
					button.cooldownText:SetText(math_floor(remaining / 60) .. "m")
				else
					button.cooldownText:SetText(math_floor(remaining))
				end
				button.cooldownText:Show()
			else
				button.cooldownText:SetText("")
				button.cooldownText:Hide()
			end
		else
			button.cooldownText:SetText("")
			button.cooldownText:Hide()
		end
	end

	if button.cooldown then
		if
			C_ActionBar
			and type(C_ActionBar.GetActionCooldownDuration) == "function"
			and type(button.cooldown.SetCooldownFromDurationObject) == "function"
		then
			local shouldShow = (isActive ~= nil) and isActive or (startNum and durNum and startNum > 0 and durNum > 0)
			local ok, durObj = pcall(C_ActionBar.GetActionCooldownDuration, action)
			if shouldShow and ok and durObj then
				button.cooldown:SetCooldownFromDurationObject(durObj)
			else
				button.cooldown:Clear()
			end
		elseif startNum and durNum then
			if durNum > 0 and startNum > 0 then
				button.cooldown:SetCooldown(startNum, durNum)
			else
				button.cooldown:Clear()
			end
		elseif Secrets.Present(start) and Secrets.Present(duration) then
			pcall(button.cooldown.SetCooldown, button.cooldown, start, duration)
		else
			button.cooldown:Clear()
		end
	end

	if button.cooldownOverlay then
		button.cooldownOverlay:Hide()
	end

	if button.Count then
		if C_ActionBar and type(C_ActionBar.GetActionDisplayCount) == "function" then
			local ok, disp = pcall(C_ActionBar.GetActionDisplayCount, action)
			if ok and Secrets.Present(disp) then
				button.Count:SetText(disp)
			else
				button.Count:SetText("")
			end
		elseif GetActionCount then
			local count = GetActionCount(action)
			local countNum = Secrets.Number(count)
			if countNum then
				button.Count:SetText(countNum > 1 and countNum or "")
			elseif Secrets.Present(count) then
				button.Count:SetText(count)
			else
				button.Count:SetText("")
			end
		end
	end
end

-- UTILITY FUNCTIONS

function Compat.SafeCall(func, ...)
	if type(func) == "function" then
		return func(...)
	end
	return nil
end

function Compat.SafeGet(obj, ...)
	if not obj then
		return nil
	end
	local result = obj
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		if result[key] == nil then
			return nil
		end
		result = result[key]
	end
	return result
end

return Compat
