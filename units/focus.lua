--get the addon namespace
local _, ns = ...

--get oUF namespace (just in case needed)
local oUF = ns.oUF or oUF

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
	self:SetFrameStrata("BACKGROUND")
	self:SetFrameLevel(1)
	self:SetSize(self.cfg.width, self.cfg.height)
	self:SetScale(self.cfg.scale)
	self:SetPoint(self.cfg.pos.a1, self.cfg.pos.af, self.cfg.pos.a2, self.cfg.pos.x, self.cfg.pos.y)
	self:RegisterForClicks("AnyDown")
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
	func.applyDragFunctionality(self)
end

--actionbar background
local createArtwork = function(self)
	local t = self:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetAllPoints(self)
	t:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\targettarget")
end

--create health frames
local createHealthFrame = function(self)
	local cfg = self.cfg.health

	--health
	local h = CreateFrame("StatusBar", nil, self)
	h:SetPoint("TOP", 0, -27.9)
	h:SetPoint("LEFT", 24.5, 0)
	h:SetPoint("RIGHT", -24.5, 0)
	h:SetPoint("BOTTOM", 0, 28.7)
	h:SetFrameStrata("LOW")

	h:SetStatusBarTexture(cfg.texture)
	h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -6)
	h.bg:SetTexture(cfg.texture)
	h.bg:SetAllPoints(h)

	h.glow = h:CreateTexture(nil, "OVERLAY", nil, -5)
	h.glow:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\targettarget_hpglow")
	h.glow:SetPoint("TOP", 0, 17)
	h.glow:SetPoint("LEFT", -24, 0)
	h.glow:SetPoint("RIGHT", 24, 0)
	h.glow:SetPoint("BOTTOM", 0, -20)
	h.glow:SetVertexColor(0, 0, 0, 1)

	h.highlight = h:CreateTexture(nil, "OVERLAY", nil, -4)
	h.highlight:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\targettarget_highlight")
	h.highlight:SetAllPoints(self)

	self.Health = h
	self.Health.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut
end

--create power frames
local createPowerFrame = function(self)
	local cfg = self.cfg.power

	--power
	local h = CreateFrame("StatusBar", nil, self.Health)
	h:SetPoint("TOP", 0, -13)
	h:SetPoint("LEFT", 5, 0)
	h:SetPoint("RIGHT", -5, 0)
	h:SetPoint("BOTTOM", 0, -10)

	h:SetStatusBarTexture(cfg.texture)

	h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -6)
	h.bg:SetTexture(cfg.texture)
	h.bg:SetAllPoints(h)

	h.glow = h:CreateTexture(nil, "OVERLAY", nil, -5)
	h.glow:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\targettarget_ppglow")
	h.glow:SetAllPoints(self)
	h.glow:SetVertexColor(0, 0, 0, 1)

	self.Power = h
	self.Power.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut
end

func.updateFocusText = function(self)
	if not self or not self.hpval then
		return
	end
	local hFmt = (self.cfg and self.cfg.healthFormat) or "both"
	local pFmt = (self.cfg and self.cfg.powerFormat) or "value"

	self:Untag(self.hpval)
	self.hpval:SetText("")
	if self.hpvalBelow then
		self:Untag(self.hpvalBelow)
		self.hpvalBelow:SetText("")
	end
	if self.ppval then
		self:Untag(self.ppval)
		self.ppval:SetText("")
	end

	if hFmt == "both" then
		self:Tag(self.hpval, "[perphp]")
		self.hpval:Show()
		if self.hpvalBelow then
			self:Tag(self.hpvalBelow, "[diablo:hpval]")
			self.hpvalBelow:Show()
		end
	elseif hFmt == "percent" then
		self:Tag(self.hpval, "[perphp]")
		self.hpval:Show()
		if self.hpvalBelow then
			self.hpvalBelow:Hide()
		end
	elseif hFmt == "deficit" then
		self:Tag(self.hpval, "[diablo:misshp]")
		self.hpval:Show()
		if self.hpvalBelow then
			self.hpvalBelow:Hide()
		end
	elseif hFmt == "current" then
		self:Tag(self.hpval, "[curshp]")
		self.hpval:Show()
		if self.hpvalBelow then
			self.hpvalBelow:Hide()
		end
	elseif hFmt == "value" then
		self:Tag(self.hpval, "[diablo:hpval]")
		self.hpval:Show()
		if self.hpvalBelow then
			self.hpvalBelow:Hide()
		end
	elseif hFmt == "none" then
		self.hpval:Hide()
		if self.hpvalBelow then
			self.hpvalBelow:Hide()
		end
	end

	if self.ppval then
		if pFmt == "value" then
			self:Tag(self.ppval, "[diablo:ppval]")
			self.ppval:Show()
		elseif pFmt == "percent" then
			self:Tag(self.ppval, "[perpp]%")
			self.ppval:Show()
		elseif pFmt == "none" then
			self.ppval:Hide()
		end
	end

	if self.hpval.UpdateTag then
		self.hpval:UpdateTag()
	end
	if self.hpvalBelow and self.hpvalBelow.UpdateTag then
		self.hpvalBelow:UpdateTag()
	end
	if self.ppval and self.ppval.UpdateTag then
		self.ppval:UpdateTag()
	end
	if self.Name and self.Name.UpdateTag then
		self.Name:UpdateTag()
	end
end

func.refreshFocusFrame = function()
	local self = unit.focus or rawget(_G, "Roth_UIFocusFrame")
	if not self then
		return
	end
	func.updateFocusText(self)
	if self.Castbar then
		self.Castbar:SetShown(self.cfg.castbar and self.cfg.castbar.show ~= false)
	end
	if self.Portrait then
		self.Portrait:SetShown(self.cfg.portrait and self.cfg.portrait.show ~= false)
	end
end

--create health power strings
local createHealthPowerStrings = function(self)
	local name = func.createFontString(self, cfg.font, 14, "THINOUTLINE")
	name:SetPoint("BOTTOM", self, "TOP", 0, -13)
	name:SetPoint("LEFT", self.Health, 0, 0)
	name:SetPoint("RIGHT", self.Health, 0, 0)
	self.Name = name

	local hpval = func.createFontString(self.Health, cfg.font, 11, "THINOUTLINE")
	hpval:SetPoint("RIGHT", -2, 0)
	self.hpval = hpval

	-- Health value text below the frame
	local hpvalBelow = func.createFontString(self, cfg.font, 15, "THINOUTLINE")
	hpvalBelow:SetPoint("TOP", self, "BOTTOM", 0, 7)
	self.hpvalBelow = hpvalBelow

	-- Power/Mana value text below the health value
	local ppval = func.createFontString(self, cfg.font, 15, "THINOUTLINE")
	ppval:SetPoint("TOP", hpvalBelow, "BOTTOM", 0, -2)
	self.ppval = ppval

	self:Tag(name, "[diablo:name]")
	func.updateFocusText(self)
end

---------------------------------------------
-- FOCUS STYLE FUNC
---------------------------------------------

local function createStyle(self)
	--apply config to self
	self.cfg = cfg.units.focus
	self.cfg.style = "focus"

	--init
	initUnitParameters(self)

	--create the art
	createArtwork(self)

	--createhealthPower
	createHealthFrame(self)
	createPowerFrame(self)
	func.healPrediction(self)

	--health power strings
	createHealthPowerStrings(self)

	--health power update
	self.Health.PostUpdate = func.updateHealth
	self.Power.PostUpdate = func.updatePower

	--create portrait
	if self.cfg.portrait.show then
		func.createPortrait(self)
		self:SetHitRectInsets(0, 0, -100, 0)
	end

	--castbar
	if self.cfg.castbar.show then
		func.createCastbar(self)
		ns.CastBars.AddInterruptReady(self.Castbar)
	end

	--auras
	if self.cfg.auras.show then
		-- the client draws them, so they stay in combat (core/nativeauras.lua)
		func.createDebuffs(self)
		if self.cfg.auras.showBuffs then
			func.createBuffs(self)
		end
	end

	--aurawatch
	if self.cfg.aurawatch.show then
		func.createAuraWatch(self)
	end

	--debuffglow
	func.createDebuffGlow(self)

	--threat
	self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", func.checkThreat)

	--icons
	self.RaidTargetIndicator = func.createIcon(self, "BACKGROUND", 18, self.Name, "BOTTOM", "TOP", 0, 0, -1)

	--add self to unit container (maybe access to that unit is needed in another style)
	unit.focus = self
end

---------------------------------------------
-- SPAWN FOCUS UNIT
---------------------------------------------

if cfg.units.focus.show then
	oUF:RegisterStyle("diablo:focus", createStyle)
	oUF:SetActiveStyle("diablo:focus")
	oUF:Spawn("focus", "Roth_UIFocusFrame")
end
