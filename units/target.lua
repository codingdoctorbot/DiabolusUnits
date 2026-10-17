--get the addon namespace
local _, ns = ...

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
	self.Crest = crest
	t.PostUpdate = function(icon, kind)
		if kind then
			icon.kind = kind
		end
		local k = kind or icon.kind
		local showCrest = (self.cfg.showDragonCrest ~= false)
		crest:SetShown(showCrest and (k == "boss" or k == "rare" or k == "rareelite" or k == "elite"))
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
	if not glow or self.cfg.threatGlow == false then
		if glow then
			glow:Hide()
		end
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

local AURA_LAYOUTS = {
	right = {
		buffs = { a1 = "BOTTOMLEFT", a2 = "TOPRIGHT", x = 0, y = -15, init = "BOTTOMLEFT", gx = "RIGHT", gy = "UP" },
		debuffs = { a1 = "TOPLEFT", a2 = "BOTTOMRIGHT", x = 0, y = 15, init = "TOPLEFT", gx = "RIGHT", gy = "DOWN" },
	},
	above = {
		buffs = { a1 = "BOTTOMLEFT", a2 = "TOPLEFT", x = 0, y = 35, init = "BOTTOMLEFT", gx = "RIGHT", gy = "UP" },
		debuffs = { a1 = "BOTTOMLEFT", a2 = "TOPLEFT", x = 0, y = 62, init = "BOTTOMLEFT", gx = "RIGHT", gy = "UP" },
	},
	below = {
		buffs = { a1 = "TOPLEFT", a2 = "BOTTOMLEFT", x = 0, y = -42, init = "TOPLEFT", gx = "RIGHT", gy = "DOWN" },
		debuffs = { a1 = "TOPLEFT", a2 = "BOTTOMLEFT", x = 0, y = -15, init = "TOPLEFT", gx = "RIGHT", gy = "DOWN" },
	},
	left = {
		buffs = { a1 = "BOTTOMRIGHT", a2 = "TOPLEFT", x = 0, y = -15, init = "BOTTOMRIGHT", gx = "LEFT", gy = "UP" },
		debuffs = { a1 = "TOPRIGHT", a2 = "BOTTOMLEFT", x = 0, y = 15, init = "TOPRIGHT", gx = "LEFT", gy = "DOWN" },
	},
}

func.updateTargetAuras = function(self)
	if InCombatLockdown() then
		self.needAuraUpdate = true
		return
	end
	if not self or not self.cfg or not self.cfg.auras then
		return
	end
	local placement = self.cfg.auras.placement or "right"
	local layout = AURA_LAYOUTS[placement] or AURA_LAYOUTS.right

	local bCfg = layout.buffs
	local dCfg = layout.debuffs

	local bf = self.BuffFrame or self.Buffs
	if bf then
		bf:ClearAllPoints()
		bf:SetPoint(bCfg.a1, self, bCfg.a2, bCfg.x, bCfg.y)
		bf.initialAnchor = bCfg.init
		bf["growth-x"] = bCfg.gx
		bf["growth-y"] = bCfg.gy
		if bf.ForceUpdate then
			bf:ForceUpdate()
		end
	end

	local df = self.DebuffFrame or self.Debuffs
	if df then
		df:ClearAllPoints()
		df:SetPoint(dCfg.a1, self, dCfg.a2, dCfg.x, dCfg.y)
		df.initialAnchor = dCfg.init
		df["growth-x"] = dCfg.gx
		df["growth-y"] = dCfg.gy
		if df.ForceUpdate then
			df:ForceUpdate()
		end
	end

	local anchorUtil = rawget(_G, "AnchorUtil")
	if anchorUtil and anchorUtil.FlowDirection then
		local FLOW = anchorUtil.FlowDirection
		if self.RothNativeBuffs then
			local c = self.RothNativeBuffs
			c:ClearAllPoints()
			c:SetPoint(bCfg.init, bf or self, bCfg.init)
			c:SetFlowLayoutAnchorPoint(bCfg.init)
			local h = bCfg.gx == "LEFT" and FLOW.Left or FLOW.Right
			local v = bCfg.gy == "UP" and FLOW.Up or FLOW.Down
			c:SetFlowLayoutGrowthDirection(h, v)
			if c.UpdateAllAuras then
				pcall(c.UpdateAllAuras, c)
			end
		end
		if self.RothNativeDebuffs then
			local c = self.RothNativeDebuffs
			c:ClearAllPoints()
			c:SetPoint(dCfg.init, df or self, dCfg.init)
			c:SetFlowLayoutAnchorPoint(dCfg.init)
			local h = dCfg.gx == "LEFT" and FLOW.Left or FLOW.Right
			local v = dCfg.gy == "UP" and FLOW.Up or FLOW.Down
			c:SetFlowLayoutGrowthDirection(h, v)
			if c.UpdateAllAuras then
				pcall(c.UpdateAllAuras, c)
			end
		end
	end
end

func.updateTargetText = function(self)
	if not self or not self.hpval then
		return
	end
	local hFmt = (self.cfg and self.cfg.healthFormat) or "both"
	local pFmt = (self.cfg and self.cfg.powerFormat) or "both"

	-- Health formatting
	self:Untag(self.hpval)
	self:Untag(self.perphp)
	self.hpval:SetText("")
	self.perphp:SetText("")

	if hFmt == "both" then
		self:Tag(self.hpval, "[diablo:hpval]")
		self:Tag(self.perphp, "[perphp]")
		self.hpval:Show()
		self.perphp:Show()
	elseif hFmt == "value" then
		self:Tag(self.hpval, "[diablo:hpval]")
		self.hpval:Show()
		self.perphp:Hide()
	elseif hFmt == "percent" then
		self:Tag(self.perphp, "[perphp]")
		self.hpval:Hide()
		self.perphp:Show()
	elseif hFmt == "deficit" then
		self:Tag(self.hpval, "[diablo:misshp]")
		self.hpval:Show()
		self.perphp:Hide()
	elseif hFmt == "current" then
		self:Tag(self.hpval, "[curshp]")
		self.hpval:Show()
		self.perphp:Hide()
	elseif hFmt == "none" then
		self.hpval:Hide()
		self.perphp:Hide()
	end

	-- Power formatting
	self:Untag(self.ppval)
	self:Untag(self.perpp)
	self.ppval:SetText("")
	self.perpp:SetText("")

	if pFmt == "both" then
		self:Tag(self.ppval, "[diablo:ppval]")
		self:Tag(self.perpp, "[perpp]%")
		self.ppval:Show()
		self.perpp:Show()
	elseif pFmt == "value" then
		self:Tag(self.ppval, "[diablo:ppval]")
		self.ppval:Show()
		self.perpp:Hide()
	elseif pFmt == "percent" then
		self:Tag(self.perpp, "[perpp]%")
		self.ppval:Hide()
		self.perpp:Show()
	elseif pFmt == "none" then
		self.ppval:Hide()
		self.perpp:Hide()
	end

	if self.hpval.UpdateTag then
		self.hpval:UpdateTag()
	end
	if self.perphp.UpdateTag then
		self.perphp:UpdateTag()
	end
	if self.ppval.UpdateTag then
		self.ppval:UpdateTag()
	end
	if self.perpp.UpdateTag then
		self.perpp:UpdateTag()
	end
	if self.Name and self.Name.UpdateTag then
		self.Name:UpdateTag()
	end
	if self.classtext and self.classtext.UpdateTag then
		self.classtext:UpdateTag()
	end
end

func.refreshTargetFrame = function()
	local self = unit.target or rawget(_G, "Roth_UITargetFrame")
	if not self then
		return
	end
	func.updateTargetText(self)
	func.updateTargetAuras(self)
	if updateThreatGlow then
		updateThreatGlow(self)
	end
	if self.RareIcon and self.RareIcon.PostUpdate then
		self.RareIcon.PostUpdate(self.RareIcon, self.RareIcon.kind)
	end
	if self.Castbar then
		self.Castbar:SetShown(self.cfg.castbar.show ~= false)
	end
	local portrait = rawget(_G, "Roth_UITargetPortrait")
	if portrait then
		portrait:SetShown(self.cfg.portrait.show == true)
	end
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
	self.hpval = hpval

	local perphp = func.createFontString(self.Health, cfg.font, self.cfg.healper.fontSize, "THINOUTLINE")
	perphp:SetPoint(self.cfg.healper.point, self.cfg.healper.x, self.cfg.healper.y)
	self.perphp = perphp

	local perpp = func.createFontString(self.Power, cfg.font, self.cfg.powper.fontSize, "THINOUTLINE")
	perpp:SetPoint(self.cfg.powper.point, self.cfg.powper.x, self.cfg.powper.y)
	self.perpp = perpp

	local ppval = func.createFontString(self.Health, cfg.font, self.cfg.power.fontSize, "THINOUTLINE")
	ppval:SetPoint(self.cfg.power.point, self.cfg.power.x, self.cfg.power.y)
	self.ppval = ppval

	local classtext = func.createFontString(self, cfg.font, self.cfg.misc.classFontSize, "THINOUTLINE")
	classtext:SetPoint("BOTTOM", self, "TOP", 0, -15)
	self.classtext = classtext

	self:Tag(name, "[diablo:name]")
	self:Tag(classtext, "[diablo:classtext]")

	func.updateTargetText(self)
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
	self.BuffFrame = f
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
	self.DebuffFrame = f
end

---------------------------------------------
-- UNIT SPECIFIC TAG
---------------------------------------------

oUF.Tags.Methods["diablo:classtext"] = function(unit)
	local string, tmpstring, sp = "", "", " "
	local details = (unit == "target") and cfg and cfg.units and cfg.units.target and cfg.units.target.details
	local showLevel = not details or details.showLevel ~= false
	local showCreatureType = not details or details.showCreatureType ~= false
	local showClassification = not details or details.showClassification ~= false
	local showClass = not details or details.showClass ~= false

	if showLevel then
		local uLevel = Secrets.Number(UnitLevel(unit))
		if uLevel == 0 then
			string = "Haxx, unit undefined"
		elseif uLevel and uLevel > 0 then
			string = tostring(uLevel)
		else
			string = "??"
		end
		string = string .. sp
	end

	local unitrace = Secrets.String(UnitRace(unit))
	local creatureType = Secrets.String(UnitCreatureType(unit))
	local isPlayer = Secrets.Bool(UnitIsPlayer, unit)
	if showCreatureType then
		if unitrace and isPlayer then
			string = string .. unitrace .. sp
		end
		if creatureType and not isPlayer then
			string = string .. creatureType .. sp
		end
	end

	if showClassification then
		local uLevel = Secrets.Number(UnitLevel(unit))
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
	end

	local localizedClass = Secrets.String(UnitClass(unit))
	if showClass and localizedClass and isPlayer then
		string = string .. localizedClass .. sp
	end
	return string
end
oUF.Tags.Events["diablo:classtext"] = "UNIT_LEVEL UNIT_CLASSIFICATION_CHANGED PLAYER_TARGET_CHANGED"

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
		func.updateTargetAuras(self)
		self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
			if self.needAuraUpdate then
				self.needAuraUpdate = nil
				func.updateTargetAuras(self)
			end
		end)
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
