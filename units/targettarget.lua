local _, ns = ...

local oUF = ns.oUF or oUF

local cfg = ns.cfg

local func = ns.func

local unit = ns.unit

-- UNIT SPECIFIC FUNCTIONS

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
end

--actionbar background
local createArtwork = function(self)
	local t = self:CreateTexture(nil, "BORDER", nil, -8)
	t:SetAllPoints(self)
	t:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\targettarget")
end

--create health frames
local createHealthFrame = function(self)
	local cfg = self.cfg.health

	--health
	local h = CreateFrame("StatusBar", nil, self)
	h:SetPoint("TOP", 0, -29)
	h:SetPoint("LEFT", 30.5, 0)
	h:SetPoint("RIGHT", -30.5, 0)
	h:SetPoint("BOTTOM", 0, 25.7)
	h:SetFrameStrata("BACKGROUND")

	h:SetStatusBarTexture(cfg.texture)
	h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -6)
	h.bg:SetTexture(cfg.texture)
	h.bg:SetAllPoints(h)

	h.glow = h:CreateTexture(nil, "OVERLAY", nil, -5)
	h.glow:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\targettarget_hpglow")
	h.glow:SetPoint("TOP", 0, -33)
	h.glow:SetPoint("LEFT", -27.5, 0)
	h.glow:SetPoint("RIGHT", 27.5, 0)
	h.glow:SetPoint("BOTTOM", 0, 27)
	h.glow:SetVertexColor(0, 0, 0, 1)

	h.highlight = h:CreateTexture(nil, "OVERLAY", nil, -4)
	h.highlight:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\targettarget_highlight")
	h.highlight:SetAllPoints(h.glow)

	self.Health = h
	self.Health.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut
end

--create power frames
local createPowerFrame = function(self)
	local cfg = self.cfg.power

	--power
	local h = CreateFrame("StatusBar", nil, self.Health)
	h:SetPoint("TOP", 0, -12)
	h:SetPoint("LEFT", 4, 0)
	h:SetPoint("RIGHT", -4, 0)
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

func.updateTargetTargetText = function(self)
	if not self or not self.hpval then
		return
	end
	local hFmt = (self.cfg and self.cfg.healthFormat) or "deficit"

	self:Untag(self.hpval)
	self.hpval:SetText("")

	if hFmt == "deficit" then
		self:Tag(self.hpval, "[diablo:misshp]")
		self.hpval:Show()
	elseif hFmt == "percent" then
		self:Tag(self.hpval, "[perphp]")
		self.hpval:Show()
	elseif hFmt == "value" then
		self:Tag(self.hpval, "[diablo:hpval]")
		self.hpval:Show()
	elseif hFmt == "current" then
		self:Tag(self.hpval, "[curshp]")
		self.hpval:Show()
	elseif hFmt == "both" then
		self:Tag(self.hpval, "[cmaxshp]")
		self.hpval:Show()
	elseif hFmt == "none" then
		self.hpval:Hide()
	end

	if self.hpval.UpdateTag then
		self.hpval:UpdateTag()
	end
	if self.Name and self.Name.UpdateTag then
		self.Name:UpdateTag()
	end
end

func.refreshTargetTargetFrame = function()
	local self = unit.targettarget or rawget(_G, "Roth_UITargetTargetFrame")
	if not self then
		return
	end
	func.updateTargetTargetText(self)
end

--create health power strings
local createHealthPowerStrings = function(self)
	local name = func.createFontString(self, cfg.font, 14, "THINOUTLINE")
	name:SetPoint("BOTTOM", self, "TOP", 0, -13)
	name:SetPoint("LEFT", self.Health, 0, 0)
	name:SetPoint("RIGHT", self.Health, 0, 0)
	self.Name = name

	-- The fill sits beneath the stone frame; keep its text above the artwork.
 local hpval = func.createFontString(self, cfg.font, 11, "THINOUTLINE")
 hpval:SetPoint("RIGHT", self.Health, "RIGHT", -2, 0)
	self.hpval = hpval

	self:Tag(name, "[diablo:name]")
	func.updateTargetTargetText(self)
end

-- TARGETTARGET STYLE FUNC

local function createStyle(self)
	--apply config to self
	self.cfg = cfg.units.targettarget
	self.cfg.style = "targettarget"

	--init
	initUnitParameters(self)

	--create the art
	createArtwork(self)

	--createhealthPower
	createHealthFrame(self)
	createPowerFrame(self)

	--health power strings
	createHealthPowerStrings(self)

	--health power update
	self.Health.PostUpdate = func.updateHealth
	self.Power.PostUpdate = func.updatePower

	--auras
	if self.cfg.auras.show then
		func.createDebuffs(self)
	end

	--debuffglow
	func.createDebuffGlow(self)

	--icons
	self.RaidTargetIndicator = func.createIcon(self, "BACKGROUND", 20, self.Name, "BOTTOM", "TOP", 0, 0, -1)
	self.RaidTargetIndicator:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\raidicons")

	--add self to unit container (maybe access to that unit is needed in another style)
	unit.targettarget = self
end

-- SPAWN TARGETTARGET UNIT

if cfg.units.targettarget.show then
	oUF:RegisterStyle("diablo:targettarget", createStyle)
	oUF:SetActiveStyle("diablo:targettarget")
	unit.WatchTargetChanges(oUF:Spawn("targettarget", "Roth_UITargetTargetFrame"), "target")
end
