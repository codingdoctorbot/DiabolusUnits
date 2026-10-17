--[[
-- Credits: Vika, Cladhaire, Tekkub
]]

local parent, ns = ...
local oUF = ns.oUF

local _PATTERN = '%[..-%]+'

local issecretvalue = _G.issecretvalue
local Secrets = ns.Secrets

local _ENV = {
	Hex = function(r, g, b)
		if type(r) == "table" then
			if r.r then r, g, b = r.r, r.g, r.b else r, g, b = unpack(r) end
		end
		if not r or (issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b))) then
			return "|cffffffff"
		end
		return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
	end,
	ColorGradient = oUF.ColorGradient,
	_SECRETS = Secrets,
}
local _PROXY = setmetatable(_ENV, {__index = _G})

local tagStrings = {
	["creature"] = [[function(u)
		local cf = _SECRETS and _SECRETS.String(UnitCreatureFamily(u)) or nil
		if cf then return cf end
		return _SECRETS and _SECRETS.String(UnitCreatureType(u)) or nil
	end]],

	["dead"] = [[function(u)
		if(_SECRETS and _SECRETS.Boolean(UnitIsDead(u))) then
			return 'Dead'
		elseif(_SECRETS and _SECRETS.Boolean(UnitIsGhost(u))) then
			return 'Ghost'
		end
	end]],

	["difficulty"] = [[function(u)
		if _SECRETS and _SECRETS.Boolean(UnitCanAttack("player", u)) then
			local l = _SECRETS.Number(UnitLevel(u))
			return Hex(GetQuestDifficultyColor((l and l > 0) and l or 99))
		end
	end]],

	["leader"] = [[function(u)
		if(_SECRETS and _SECRETS.Boolean(UnitIsGroupLeader(u))) then
			return 'L'
		end
	end]],

	["leaderlong"]  = [[function(u)
		if(_SECRETS and _SECRETS.Boolean(UnitIsGroupLeader(u))) then
			return 'Leader'
		end
	end]],

	["level"] = [[function(u)
		local l = _SECRETS and _SECRETS.Number(UnitLevel(u)) or nil
		if(UnitIsWildBattlePet and (_SECRETS.Boolean(UnitIsWildBattlePet(u)) or _SECRETS.Boolean(UnitIsBattlePetCompanion(u)))) then
			l = _SECRETS.Number(UnitBattlePetLevel(u))
		end

		if(l and l > 0) then
			return l
		else
			return '??'
		end
	end]],

	["missinghp"] = [[function(u)
		if _SECRETS then
			if type(UnitHealthMissing) == "function" then
				return _SECRETS.FormatMissing(UnitHealthMissing(u))
			end
			local cur, max = _SECRETS.Number(UnitHealth(u)), _SECRETS.Number(UnitHealthMax(u))
			if cur and max and max > cur then
				return max - cur
			end
		end
	end]],

	["missingpp"] = [[function(u)
		if _SECRETS then
			local cur, max = _SECRETS.Number(UnitPower(u)), _SECRETS.Number(UnitPowerMax(u))
			if cur and max and max > cur then
				return max - cur
			end
		end
	end]],

	["name"] = [[function(u, r)
		return UnitName(r or u)
	end]],

	["offline"] = [[function(u)
		if(not (_SECRETS and _SECRETS.Boolean(UnitIsConnected(u), true))) then
			return 'Offline'
		end
	end]],

	["perhp"] = [[function(u)
		if _SECRETS then
			return _SECRETS.RoundPercent(_SECRETS.UnitHealthPercent100(u))
		end
		return 0
	end]],

	["perpp"] = [[function(u)
		if _SECRETS then
			return _SECRETS.RoundPercent(_SECRETS.UnitPowerPercent100(u))
		end
		return 0
	end]],

	["plus"] = [[function(u)
		local c = _SECRETS and _SECRETS.String(UnitClassification(u))
		if(c == 'elite' or c == 'rareelite') then
			return '+'
		end
	end]],

	["pvp"] = [[function(u)
		if(_SECRETS and _SECRETS.Boolean(UnitIsPVP(u))) then
			return 'PvP'
		end
	end]],

	["raidcolor"] = [[function(u)
		if _SECRETS then
			local r, g, b = _SECRETS.UnitClassColor(u)
			if r and g and b then
				return Hex(r, g, b)
			end
		end
		local _, x = UnitClass(u)
		if(_SECRETS and _SECRETS.String(x)) then
			return Hex(_COLORS.class[x])
		end
	end]],

	["rare"] = [[function(u)
		local c = _SECRETS and _SECRETS.String(UnitClassification(u))
		if(c == 'rare' or c == 'rareelite') then
			return 'Rare'
		end
	end]],

	["resting"] = [[function(u)
		if(u == 'player' and _SECRETS and _SECRETS.Boolean(IsResting())) then
			return 'zzz'
		end
	end]],

	["sex"] = [[function(u)
		local s = _SECRETS and _SECRETS.Number(UnitSex(u))
		if(s == 2) then
			return 'Male'
		elseif(s == 3) then
			return 'Female'
		end
	end]],

	["smartclass"] = [[function(u)
		if(_SECRETS and _SECRETS.Boolean(UnitIsPlayer(u))) then
			return _TAGS['class'](u)
		end

		return _TAGS['creature'](u)
	end]],

	["status"] = [[function(u)
		if(_SECRETS and _SECRETS.Boolean(UnitIsDead(u))) then
			return 'Dead'
		elseif(_SECRETS and _SECRETS.Boolean(UnitIsGhost(u))) then
			return 'Ghost'
		elseif(not (_SECRETS and _SECRETS.Boolean(UnitIsConnected(u), true))) then
			return 'Offline'
		else
			return _TAGS['resting'](u)
		end
	end]],

	["threat"] = [[function(u)
		local s = _SECRETS and _SECRETS.Number(UnitThreatSituation(u))
		if(s == 1) then
			return '++'
		elseif(s == 2) then
			return '--'
		elseif(s == 3) then
			return 'Aggro'
		end
	end]],

	["threatcolor"] = [[function(u)
		local s = _SECRETS and _SECRETS.Number(UnitThreatSituation(u)) or 0
		return Hex(GetThreatStatusColor(s))
	end]],

	["cpoints"] = [[function(u)
		local cp
		if(_SECRETS and _SECRETS.Boolean(UnitHasVehicleUI('player'))) then
			cp = _SECRETS.Number(GetComboPoints('vehicle', 'target'))
		else
			cp = _SECRETS and _SECRETS.Number(GetComboPoints('player', 'target'))
		end

		if(cp and cp > 0) then
			return cp
		end
	end]],

	['smartlevel'] = [[function(u)
		local c = _SECRETS and _SECRETS.String(UnitClassification(u))
		if(c == 'worldboss') then
			return 'Boss'
		else
			local plus = _TAGS['plus'](u)
			local level = _TAGS['level'](u)
			if(plus) then
				return level .. plus
			else
				return level
			end
		end
	end]],

	["classification"] = [[function(u)
		local c = _SECRETS and _SECRETS.String(UnitClassification(u))
		if(c == 'rare') then
			return 'Rare'
		elseif(c == 'rareelite') then
			return 'Rare Elite'
		elseif(c == 'elite') then
			return 'Elite'
		elseif(c == 'worldboss') then
			return 'Boss'
		elseif(c == 'minus') then
			return 'Affix'
		end
	end]],

	["shortclassification"] = [[function(u)
		local c = _SECRETS and _SECRETS.String(UnitClassification(u))
		if(c == 'rare') then
			return 'R'
		elseif(c == 'rareelite') then
			return 'R+'
		elseif(c == 'elite') then
			return '+'
		elseif(c == 'worldboss') then
			return 'B'
		elseif(c == 'minus') then
			return '-'
		end
	end]],

	["group"] = [[function(unit)
		local name, server = UnitName(unit)
		if(server and server ~= "") then
			name = string.format("%s-%s", name, server)
		end

		for i=1, GetNumGroupMembers() do
			local raidName, _, group = GetRaidRosterInfo(i)
			if( raidName == name ) then
				return group
			end
		end
	end]],

	["deficit:name"] = [[function(u)
		local missinghp = _TAGS['missinghp'](u)
		if(missinghp) then
			return '-' .. missinghp
		else
			return _TAGS['name'](u)
		end
	end]],

	['curmana'] = [[function(unit)
		local manaType = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
		return UnitPower(unit, manaType)
	end]],

	['maxmana'] = [[function(unit)
		local manaType = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
		return UnitPowerMax(unit, manaType)
	end]],

	['soulshards'] = [[function()
		if not (Enum and Enum.PowerType and Enum.PowerType.SoulShards) then return end
		local num = UnitPower('player', Enum.PowerType.SoulShards)
		if(num > 0) then
			return num
		end
	end]],

	['holypower'] = [[function()
		if not (GetSpecialization and SPEC_PALADIN_RETRIBUTION) then return end
		if(GetSpecialization() == SPEC_PALADIN_RETRIBUTION) then
			if not (Enum and Enum.PowerType and Enum.PowerType.HolyPower) then return end
			local num = UnitPower('player', Enum.PowerType.HolyPower)
			if(num > 0) then
				return num
			end
		end
	end]],

	['chi'] = [[function()
		if not (GetSpecialization and SPEC_MONK_WINDWALKER) then return end
		if(GetSpecialization() == SPEC_MONK_WINDWALKER) then
			if not (Enum and Enum.PowerType and Enum.PowerType.Chi) then return end
			local num = UnitPower('player', Enum.PowerType.Chi)
			if(num > 0) then
				return num
			end
		end
	end]],

	['arcanecharges'] = [[function()
		if not (GetSpecialization and SPEC_MAGE_ARCANE) then return end
		if(GetSpecialization() == SPEC_MAGE_ARCANE) then
			if not (Enum and Enum.PowerType and Enum.PowerType.ArcaneCharges) then return end
			local num = UnitPower('player', Enum.PowerType.ArcaneCharges)
			if(num > 0) then
				return num
			end
		end
	end]],

	['affix'] = [[function(u)
		local c = UnitClassification(u)
		if(c == 'minus') then
			return 'Affix'
		end
	end]],

	['arenaspec'] = [[function(u)
		if not (GetArenaOpponentSpec and GetSpecializationInfoByID) then return end
		local id = u:match'arena(%d)$'
		if(id) then
			local specID = GetArenaOpponentSpec(tonumber(id))
			if(specID and specID > 0) then
				local _, specName = GetSpecializationInfoByID(specID)
				return specName
			end
		end
	end]],
}

local tags = setmetatable(
	{
		curhp = UnitHealth,
		curpp = UnitPower,
		maxhp = UnitHealthMax,
		maxpp = UnitPowerMax,
		class = UnitClass,
		faction = UnitFactionGroup,
		race = UnitRace,
	},

	{
		__index = function(self, key)
			local tagFunc = tagStrings[key]
			if(tagFunc) then
				local func, err = loadstring('return ' .. tagFunc)
				if(func) then
					func = func()

					-- Want to trigger __newindex, so no rawset.
					self[key] = func
					tagStrings[key] = nil

					return func
				else
					error(err, 3)
				end
			end
		end,
		__newindex = function(self, key, val)
			if(type(val) == 'string') then
				tagStrings[key] = val
			elseif(type(val) == 'function') then
				-- So we don't clash with any custom envs.
				if(getfenv(val) == _G) then
					setfenv(val, _PROXY)
				end

				rawset(self, key, val)
			end
		end,
	}
)

_ENV._TAGS = tags

local tagEvents = {
	["curhp"]               = "UNIT_HEALTH",
	["dead"]                = "UNIT_HEALTH",
	["leader"]              = "PARTY_LEADER_CHANGED",
	["leaderlong"]          = "PARTY_LEADER_CHANGED",
	["level"]               = "UNIT_LEVEL PLAYER_LEVEL_UP",
	["maxhp"]               = "UNIT_MAXHEALTH",
	["missinghp"]           = "UNIT_HEALTH UNIT_MAXHEALTH",
	["name"]                = "UNIT_NAME_UPDATE",
	["perhp"]               = "UNIT_HEALTH UNIT_MAXHEALTH",
	["pvp"]                 = "UNIT_FACTION",
	["resting"]             = "PLAYER_UPDATE_RESTING",
	["smartlevel"]          = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED",
	["threat"]              = "UNIT_THREAT_SITUATION_UPDATE",
	["threatcolor"]         = "UNIT_THREAT_SITUATION_UPDATE",
	['cpoints']             = 'UNIT_POWER_UPDATE_FREQUENT PLAYER_TARGET_CHANGED',
	['affix']				= 'UNIT_CLASSIFICATION_CHANGED',
	['plus']				= 'UNIT_CLASSIFICATION_CHANGED',
	['rare']                = 'UNIT_CLASSIFICATION_CHANGED',
	['classification']      = 'UNIT_CLASSIFICATION_CHANGED',
	['shortclassification'] = 'UNIT_CLASSIFICATION_CHANGED',
	["group"]               = "GROUP_ROSTER_UPDATE",
	["curpp"]               = 'UNIT_POWER_UPDATE',
	["maxpp"]               = 'UNIT_MAXPOWER',
	["missingpp"]           = 'UNIT_MAXPOWER UNIT_POWER_UPDATE',
	["perpp"]               = 'UNIT_MAXPOWER UNIT_POWER_UPDATE',
	["offline"]             = "UNIT_HEALTH UNIT_CONNECTION",
	["status"]              = "UNIT_HEALTH PLAYER_UPDATE_RESTING UNIT_CONNECTION",
	['curmana']             = 'UNIT_POWER_UPDATE UNIT_MAXPOWER',
	['maxmana']             = 'UNIT_POWER_UPDATE UNIT_MAXPOWER',
	['soulshards']          = 'UNIT_POWER_UPDATE',
	['holypower']           = 'UNIT_POWER_UPDATE SPELLS_CHANGED',
	['chi']                 = 'UNIT_POWER_UPDATE SPELLS_CHANGED',
	['arcanecharges']       = 'UNIT_POWER_UPDATE SPELLS_CHANGED',
	['arenaspec']           = 'ARENA_PREP_OPPONENT_SPECIALIZATIONS',
}

local unitlessEvents = {
	PLAYER_LEVEL_UP = true,
	PLAYER_UPDATE_RESTING = true,
	PLAYER_TARGET_CHANGED = true,

	PARTY_LEADER_CHANGED = true,

	GROUP_ROSTER_UPDATE = true,

	ARENA_PREP_OPPONENT_SPECIALIZATIONS = true,
}

local function SafeTagVal(v)
	if type(v) == "nil" then
		return ""
	end
	if issecretvalue and issecretvalue(v) then
		return v
	end
	if v == false then
		return ""
	end
	return v
end

local events = {}
local frame = CreateFrame"Frame"
frame:SetScript('OnEvent', function(self, event, unit)
	local strings = events[event]
	if(strings) then
		local unitSecret = issecretvalue and issecretvalue(unit)
		for k, fontstring in next, strings do
			if(fontstring:IsVisible() and (unitlessEvents[event] or unitSecret or fontstring.parent.unit == unit)) then
				fontstring:UpdateTag()
			end
		end
	end
end)

local OnUpdates = {}
local eventlessUnits = {}

local createOnUpdate = function(timer)
	local OnUpdate = OnUpdates[timer]

	if(not OnUpdate) then
		local total = timer
		local frame = CreateFrame'Frame'
		local strings = eventlessUnits[timer]

		frame:SetScript('OnUpdate', function(self, elapsed)
			if(total >= timer) then
				for k, fs in next, strings do
					local u = fs.parent.unit
					local exists = Secrets and Secrets.UnitExists(u) or (u and UnitExists(u))
					if(fs.parent:IsShown() and exists) then
						fs:UpdateTag()
					end
				end

				total = 0
			end

			total = total + elapsed
		end)

		OnUpdates[timer] = frame
	end
end

local OnShow = function(self)
	for _, fs in next, self.__tags do
		fs:UpdateTag()
	end
end

local getTagName = function(tag)
	local s = (tag:match('>+()') or 2)
	local e = tag:match('.*()<+')
	e = (e and e - 1) or -2

	return tag:sub(s, e), s, e
end

local RegisterEvent = function(fontstr, event)
	if(not events[event]) then events[event] = {} end

	frame:RegisterEvent(event)
	table.insert(events[event], fontstr)
end

local RegisterEvents = function(fontstr, tagstr)
	for tag in tagstr:gmatch(_PATTERN) do
		tag = getTagName(tag)
		local tagevents = tagEvents[tag]
		if(tagevents) then
			for event in tagevents:gmatch'%S+' do
				RegisterEvent(fontstr, event)
			end
		end
	end
end

local UnregisterEvents = function(fontstr)
	for event, data in pairs(events) do
		for k, tagfsstr in pairs(data) do
			if(tagfsstr == fontstr) then
				if(#data == 1) then
					frame:UnregisterEvent(event)
				end

				table.remove(data, k)
			end
		end
	end
end

local tagPool = {}
local funcPool = {}
local tmp = {}

local Tag = function(self, fs, tagstr)
	if(not fs or not tagstr) then return end

	if(not self.__tags) then
		self.__tags = {}
		table.insert(self.__elements, OnShow)
	else
		-- Since people ignore everything that's good practice - unregister the tag
		-- if it already exists.
		for _, tag in pairs(self.__tags) do
			if(fs == tag) then
				-- We don't need to remove it from the __tags table as Untag handles
				-- that for us.
				self:Untag(fs)
			end
		end
	end

	fs.parent = self

	local func = tagPool[tagstr]
	if(not func) then
		local format, numTags = tagstr:gsub('%%', '%%%%'):gsub(_PATTERN, '%%s')
		local args = {}

		for bracket in tagstr:gmatch(_PATTERN) do
			local tagFunc = funcPool[bracket] or tags[bracket:sub(2, -2)]
			if(not tagFunc) then
				local tagName, s, e = getTagName(bracket)

				local tag = tags[tagName]
				if(tag) then
					s = s - 2
					e = e + 2

					if(s ~= 0 and e ~= 0) then
						local pre = bracket:sub(2, s)
						local ap = bracket:sub(e, -2)

						tagFunc = function(u,r)
							local str = tag(u,r)
							if type(str) == "nil" then return "" end
							if issecretvalue and issecretvalue(str) then return str end
							if(str and str ~= "") then
								return pre..str..ap
							end
						end
					elseif(s ~= 0) then
						local pre = bracket:sub(2, s)

						tagFunc = function(u,r)
							local str = tag(u,r)
							if type(str) == "nil" then return "" end
							if issecretvalue and issecretvalue(str) then return str end
							if(str and str ~= "") then
								return pre..str
							end
						end
					elseif(e ~= 0) then
						local ap = bracket:sub(e, -2)

						tagFunc = function(u,r)
							local str = tag(u,r)
							if type(str) == "nil" then return "" end
							if issecretvalue and issecretvalue(str) then return str end
							if(str and str ~= "") then
								return str..ap
							end
						end
					end

					funcPool[bracket] = tagFunc
				end
			end

			if(tagFunc) then
				table.insert(args, tagFunc)
			else
				return error(('Attempted to use invalid tag %s.'):format(bracket), 3)
			end
		end

		if(numTags == 1) then
			func = function(self)
				local parent = self.parent
				local realUnit
				if(self.overrideUnit) then
					realUnit = parent.realUnit
				end

				_ENV._COLORS = parent.colors
				return self:SetFormattedText(
					format,
					SafeTagVal(args[1](parent.unit, realUnit))
				)
			end
		elseif(numTags == 2) then
			func = function(self)
				local parent = self.parent
				local unit = parent.unit
				local realUnit
				if(self.overrideUnit) then
					realUnit = parent.realUnit
				end

				_ENV._COLORS = parent.colors
				return self:SetFormattedText(
					format,
					SafeTagVal(args[1](unit, realUnit)),
					SafeTagVal(args[2](unit, realUnit))
				)
			end
		elseif(numTags == 3) then
			func = function(self)
				local parent = self.parent
				local unit = parent.unit
				local realUnit
				if(self.overrideUnit) then
					realUnit = parent.realUnit
				end

				_ENV._COLORS = parent.colors
				return self:SetFormattedText(
					format,
					SafeTagVal(args[1](unit, realUnit)),
					SafeTagVal(args[2](unit, realUnit)),
					SafeTagVal(args[3](unit, realUnit))
				)
			end
		else
			func = function(self)
				local parent = self.parent
				local unit = parent.unit
				local realUnit
				if(self.overrideUnit) then
					realUnit = parent.realUnit
				end

				_ENV._COLORS = parent.colors
				for i, func in next, args do
					tmp[i] = SafeTagVal(func(unit, realUnit))
				end

				-- We do 1, numTags because tmp can hold several unneeded variables.
				return self:SetFormattedText(format, unpack(tmp, 1, numTags))
			end
		end

		tagPool[tagstr] = func
	end
	fs.UpdateTag = func

	local unit = self.unit
	if(self.__eventless or fs.frequentUpdates) then
		local timer
		if(type(fs.frequentUpdates) == 'number') then
			timer = fs.frequentUpdates
		else
			timer = .5
		end

		if(not eventlessUnits[timer]) then eventlessUnits[timer] = {} end
		table.insert(eventlessUnits[timer], fs)

		createOnUpdate(timer)
	else
		RegisterEvents(fs, tagstr)
	end

	table.insert(self.__tags, fs)
end

local Untag = function(self, fs)
	if(not fs) then return end

	UnregisterEvents(fs)
	for _, timers in next, eventlessUnits do
		for k, fontstr in next, timers do
			if(fs == fontstr) then
				table.remove(timers, k)
			end
		end
	end

	for k, fontstr in next, self.__tags do
		if(fontstr == fs) then
			table.remove(self.__tags, k)
		end
	end

	fs.UpdateTag = nil
end

if oUF then
	oUF.Tags = {
		Methods = tags,
		Events = tagEvents,
		SharedEvents = unitlessEvents,
	}
	if oUF.RegisterMetaFunction then
		oUF:RegisterMetaFunction('Tag', Tag)
		oUF:RegisterMetaFunction('Untag', Untag)
	end
end
