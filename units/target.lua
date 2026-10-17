--get the addon namespace
local addon, ns = ...

--get oUF namespace (just in case needed)
local oUF = ns.oUF or oUF
local Secrets = ns.Secrets

--get the config
local cfg = ns.cfg

--get the functions
local func = ns.func

--get the unit container
local unit = ns.unit

---------------------------------------------
-- UNIT SPECIFIC FUNCTIONS
---------------------------------------------

--init parameters
local initUnitParameters = function(self)
	self:SetFrameStrata("LOW")
	self:SetFrameLevel(1)
	self:SetSize(self.cfg.width, self.cfg.height)
	self:SetScale(self.cfg.scale)
	self:SetPoint(self.cfg.pos.a1, self.cfg.pos.af, self.cfg.pos.a2, self.cfg.pos.x, self.cfg.pos.y)
	self:RegisterForClicks("AnyDown")
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
	func.applyDragFunctionality(self)
	self:SetHitRectInsets(10, 10, 10, 10)
	-- DO NOT modify ZoneTextFrame/SubZoneTextFrame strata from addon code
	-- as it taints default Blizzard notification frames.
end

--Target Frame
local createArtwork = function(self)
	local t = self:CreateTexture(nil, "BORDER", nil, -8)
	t:SetPoint("TOP", 0, 25)
	t:SetPoint("LEFT", -62, 0)
	t:SetPoint("RIGHT", 60, 0)
	t:SetPoint("BOTTOM", 0, -15)

	self.RareIcon = t

	-- a horned crest over boss frames (oUF RareIcon PostUpdate, embeds/oUF/elements/rare.lua)
	local crest = self:CreateTexture(nil, "BORDER", nil, -6)
	crest:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\d3_head_elite")
	crest:SetSize(128, 64)
	crest:SetPoint("BOTTOM", t, "TOP", 0, -40)
	crest:Hide()
	t.PostUpdate = function(icon, kind)
		crest:SetShown(kind == "boss")
	end

	-- threat: the frame glows in the threat colour while the target is on you
	if self.cfg.threatGlow ~= false then
		local glow = self:CreateTexture(nil, "BACKGROUND", nil, -8)
		glow:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\target_threatglow")
		-- The glow's outline fills its whole 512 x 128 canvas, the frame art only
		-- x 58..454 / y 37..106 of its own: fit the outline just around the art
		-- (art box 422 x 104 here; glow canvas x 50..462, y 10..132 of the art's).
		glow:SetPoint("TOPLEFT", t, "TOPLEFT", 41, -8)
		glow:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -41, -3)
		glow:SetBlendMode("ADD")
		glow:Hide()
		self.ThreatGlow = glow
	end
end

-- UnitThreatSituation can be secret in combat: Secrets.Number makes that
-- nil, and the glow simply stays as it was until a readable update.
local updateThreatGlow = function(self)
	local glow = self.ThreatGlow
	if not glow then
		return
	end
	if not Secrets.UnitExists(self.unit or "target") then
		glow:Hide()
		return
	end
	local status = Secrets.Number(UnitThreatSituation("player", self.unit or "target"))
	if status == nil then
		return
	end
	if status >= 2 then
		local r, g, b = GetThreatStatusColor(status)
		glow:SetVertexColor(r, g, b, 1)
		glow:Show()
	else
		glow:Hide()
	end
end

--make a sound when target gets selected
local playTargetSound = function(self, event)
	if event == "PLAYER_TARGET_CHANGED" then
		if Secrets.UnitExists(self.unit) then
			if Secrets.Bool(UnitIsEnemy, self.unit, "player") then
				PlaySound(873)
			elseif Secrets.Bool(UnitIsFriend, "player", self.unit) then
				PlaySound(867)
			else
				PlaySound(871)
			end
		else
			PlaySound(684)
		end
	end
end

--create health frames
local createHealthFrame = function(self)
	local cfg = self.cfg.health

	--health
	local h = CreateFrame("StatusBar", nil, self)
	h:SetPoint("TOP", 0, -21.9)
	h:SetPoint("LEFT", 24.5, 0)
	h:SetPoint("RIGHT", -24.5, 0)
	h:SetPoint("BOTTOM", 0, 29.7)
	h:SetFrameStrata("BACKGROUND")

	h:SetStatusBarTexture(cfg.texture)
	h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -6)
	h.bg:SetTexture(cfg.texture)
	h.bg:SetAllPoints(h)

	h.glow = h:CreateTexture(nil, "OVERLAY", nil, -5)
	h.glow:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\target_hpglow")
	h.glow:SetVertexColor(0, 0, 0, 1)

	h.highlight = h:CreateTexture(nil, "OVERLAY", nil, -4)
	h.highlight:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\target_highlight")
	h.highlight:SetAllPoints(h)

	self.Health = h
	self.Health.Smooth = true
	self.Health.frequentUpdates = self.cfg.health.frequentUpdates or false
end

--create power frames
local createPowerFrame = function(self)
	local cfg = self.cfg.power

	--power
	local h = CreateFrame("StatusBar", nil, self.Health)
	h:SetPoint("TOP", 0, -20)
	h:SetPoint("LEFT", 11, 0)
	h:SetPoint("RIGHT", -12, 0)
	h:SetPoint("BOTTOM", 0, -14)

	h:SetStatusBarTexture(cfg.texture)

	h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -6)
	h.bg:SetTexture(cfg.texture)
	h.bg:SetAllPoints(h)

	h.glow = h:CreateTexture(nil, "OVERLAY", nil, -5)
	h.glow:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\target_ppglow")
	h.glow:SetAllPoints(self)
	h.glow:SetVertexColor(0, 0, 0, 1)

	self.Power = h
	self.Power.Smooth = true
	self.Power.frequentUpdates = self.cfg.power.frequentUpdates or false
end

--create health power strings
local createHealthPowerStrings = function(self)
	local name = func.createFontString(self, cfg.headerFont or cfg.font, self.cfg.misc.NameFontSize, "THINOUTLINE")
	name:SetPoint("BOTTOM", self, "TOP", 0, 0)
	name:SetPoint("LEFT", self.Health, 0, 0)
	name:SetPoint("RIGHT", self.Health, 0, 0)
	self.Name = name

	local hpval = func.createFontString(self.Health, cfg.font, self.cfg.health.fontSize, "THINOUTLINE")
	hpval:SetPoint(self.cfg.health.point, self.cfg.health.x, self.cfg.health.y)

	local perphp = func.createFontString(self.Health, cfg.font, self.cfg.healper.fontSize, "THINOUTLINE")
	perphp:SetPoint(self.cfg.healper.point, self.cfg.healper.x, self.cfg.healper.y)

	local perpp = func.createFontString(self.Power, cfg.font, self.cfg.powper.fontSize, "THINOUTLINE")
	perpp:SetPoint(self.cfg.powper.point, self.cfg.powper.x, self.cfg.powper.y)

	local ppval = func.createFontString(self.Health, cfg.font, self.cfg.power.fontSize, "THINOUTLINE")
	ppval:SetPoint(self.cfg.power.point, self.cfg.power.x, self.cfg.power.y)

	local classtext = func.createFontString(self, cfg.font, self.cfg.misc.classFontSize, "THINOUTLINE")
	classtext:SetPoint("BOTTOM", self, "TOP", 0, -15)

	self:Tag(name, "[diablo:name]")
	self:Tag(hpval, self.cfg.health.tag or "")
	self:Tag(perphp, self.cfg.healper.tag or "")
	self:Tag(perpp, self.cfg.powper.tag or "")
	self:Tag(ppval, self.cfg.power.tag or "")
	self:Tag(classtext, "[diablo:classtext]")
end

--check for interruptable spellcast
local checkShield = function(self, unit)
	if self.notInterruptible and Secrets.Bool(UnitCanAttack, "player", unit) then
		--show shield
		self:SetStatusBarColor(
			self.cfg.color.shieldbar.r,
			self.cfg.color.shieldbar.g,
			self.cfg.color.shieldbar.b,
			self.cfg.color.shieldbar.a
		)
		self.bg:SetVertexColor(
			self.cfg.color.shieldbg.r,
			self.cfg.color.shieldbg.g,
			self.cfg.color.shieldbg.b,
			self.cfg.color.shieldbg.a
		)
		self.Spark:SetVertexColor(0.8, 0.8, 0.8, 1)
		self.background:SetDesaturated(1)
	else
		--no shield
		self:SetStatusBarColor(self.cfg.color.bar.r, self.cfg.color.bar.g, self.cfg.color.bar.b, self.cfg.color.bar.a)
		self.bg:SetVertexColor(self.cfg.color.bg.r, self.cfg.color.bg.g, self.cfg.color.bg.b, self.cfg.color.bg.a)
		self.Spark:SetVertexColor(0.8, 0.6, 0, 1)
		self.background:SetDesaturated(nil)
	end
end

--check for interruptable spellcast
local checkCast = function(bar, unit, name, rank, castid)
	checkShield(bar, unit)
end

--check for interruptable spellcast
local checkChannel = function(bar, unit, name, rank)
	checkShield(bar, unit)
end

--create buffs
local createBuffs = function(self)
	local f = CreateFrame("Frame", nil, self)
	f.size = self.cfg.auras.size
	f.num = 40
	f:SetHeight((f.size + 5) * 4)
	f:SetWidth((f.size + 5) * 10)
	f:SetPoint(
		self.cfg.auras.buffs.pos.a1,
		self,
		self.cfg.auras.buffs.pos.a2,
		self.cfg.auras.buffs.pos.x,
		self.cfg.auras.buffs.pos.y
	)
	f.initialAnchor = self.cfg.auras.buffs.initialAnchor
	f["growth-x"] = self.cfg.auras.buffs.growthx
	f["growth-y"] = self.cfg.auras.buffs.growthy
	f.spacing = 5
	f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerBuffs
	f.showStealableBuffs = self.cfg.auras.showStealableBuffs
	f.filter = "HELPFUL"
	self.Buffs = f
end

--create debuff func
local createDebuffs = function(self)
	local f = CreateFrame("Frame", nil, self)
	f.size = self.cfg.auras.size
	f.num = 40
	f:SetHeight((f.size + 5) * 4)
	f:SetWidth((f.size + 5) * 10)
	f:SetPoint(
		self.cfg.auras.debuffs.pos.a1,
		self,
		self.cfg.auras.debuffs.pos.a2,
		self.cfg.auras.debuffs.pos.x,
		self.cfg.auras.debuffs.pos.y
	)
	f.initialAnchor = self.cfg.auras.debuffs.initialAnchor
	f["growth-x"] = self.cfg.auras.debuffs.growthx
	f["growth-y"] = self.cfg.auras.debuffs.growthy
	f.spacing = 5
	f.showDebuffType = self.cfg.auras.showDebuffType
	f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerDebuffs
	f.filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY"
	self.Debuffs = f
end

---------------------------------------------
-- UNIT SPECIFIC TAG
---------------------------------------------

oUF.Tags.Methods["diablo:classtext"] = function(unit)
	local string, tmpstring, sp = "", "", " "
	local uLevel = Secrets.Number(UnitLevel(unit))
	if uLevel == 0 then
		string = "Haxx, unit undefined"
	elseif uLevel and uLevel > 0 then
		string = tostring(uLevel)
	else
		string = "??"
	end
	string = string .. sp
	local unitrace = Secrets.String(UnitRace(unit))
	local creatureType = Secrets.String(UnitCreatureType(unit))
	local isPlayer = Secrets.Bool(UnitIsPlayer, unit)
	if unitrace and isPlayer then
		string = string .. unitrace .. sp
	end
	if creatureType and not isPlayer then
		string = string .. creatureType .. sp
	end
	local unit_classification = Secrets.String(UnitClassification(unit))
	if unit_classification == "worldboss" or (uLevel and uLevel == -1) then
		tmpstring = "Boss"
	elseif unit_classification == "rare" or unit_classification == "rareelite" then
		tmpstring = "Rare"
		if unit_classification == "rareelite" then
			tmpstring = tmpstring .. " Elite"
		end
	elseif unit_classification == "elite" then
		tmpstring = "Elite"
	end
	if tmpstring ~= "" then
		tmpstring = tmpstring .. sp
	end
	string = string .. tmpstring
	tmpstring = ""
	local localizedClass = Secrets.String(UnitClass(unit))

	if localizedClass and isPlayer then
		string = string .. localizedClass .. sp
	end
	return string
end

---------------------------------------------
-- TARGET STYLE FUNC
---------------------------------------------

local function createStyle(self)
	--apply config to self
	self.cfg = cfg.units.target
	self.cfg.style = "target"

	--init
	initUnitParameters(self)

	--create the art
	createArtwork(self)

	--createhealthPower
	createHealthFrame(self)
	createPowerFrame(self)
	func.healPrediction(self)

	--sound
	self:RegisterEvent("PLAYER_TARGET_CHANGED", playTargetSound)
	self.Health:SetScript("OnShow", function(s)
		playTargetSound(self, "PLAYER_TARGET_CHANGED")
	end)

	--health power strings
	createHealthPowerStrings(self)

	--health power update
	self.Health.PostUpdate = func.updateHealth
	self.Power.PostUpdate = func.updatePower

	--auras
	if self.cfg.auras.show then
		createBuffs(self)
		createDebuffs(self)
		self.Buffs.PostCreateIcon = func.createAuraIcon
		self.Debuffs.PostCreateIcon = func.createAuraIcon
		if self.cfg.auras.desaturateDebuffs then
			self.Debuffs.PostUpdateIcon = func.postUpdateDebuff
		end
		-- the client draws them where it can, so they stay in combat (core/nativeauras.lua)
		ns.NativeAuras.Replace(self, "Buffs", "target")
		ns.NativeAuras.Replace(self, "Debuffs", "target")
	end

	--castbar
	if self.cfg.castbar.show then
		func.createCastbar(self)
		self.Castbar.cfg = self.cfg.castbar
		self.Castbar.PostCastStart = checkCast
		self.Castbar.PostChannelStart = checkChannel
		ns.CastBars.AddInterruptReady(self.Castbar)
	end

	--debuffglow
	func.createDebuffGlow(self)

	--threat glow updates (a plain frame: the threat events name the player, not the target)
	if self.ThreatGlow then
		local tf = CreateFrame("Frame")
		for _, e in ipairs({
			"UNIT_THREAT_SITUATION_UPDATE",
			"UNIT_THREAT_LIST_UPDATE",
			"PLAYER_TARGET_CHANGED",
			"PLAYER_REGEN_ENABLED",
		}) do
			tf:RegisterEvent(e)
		end
		tf:SetScript("OnEvent", function()
			updateThreatGlow(self)
		end)
	end

	--icons
	self.RaidIcon = func.createIcon(self, "BACKGROUND", 24, self.Name, "BOTTOM", "TOP", 0, 0, -1)
	self.RaidIcon:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\raidicons")

	--create portrait
	if self.cfg.portrait.show then
		func.createStandAlonePortrait(self)
	end

	--add self to unit container (maybe access to that unit is needed in another style)
	unit.target = self
end

---------------------------------------------
-- SPAWN TARGET UNIT
---------------------------------------------

if cfg.units.target.show then
	oUF:RegisterStyle("diablo:target", createStyle)
	oUF:SetActiveStyle("diablo:target")
	oUF:Spawn("target", "Roth_UITargetFrame")
end
