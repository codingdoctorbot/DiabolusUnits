local _, ns = ...

local oUF = ns.oUF or oUF

local cfg = ns.cfg

local func = ns.func

local unit = ns.unit

-- UNIT SPECIFIC FUNCTIONS

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
	t:SetTexture("Interface\\AddOns\\DiabolusForever\\media\\targettarget")
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
	h.glow:SetTexture("Interface\\AddOns\\DiabolusForever\\media\\targettarget_hpglow")
	h.glow:SetPoint("TOP", 0, 17)
	h.glow:SetPoint("LEFT", -24, 0)
	h.glow:SetPoint("RIGHT", 24, 0)
	h.glow:SetPoint("BOTTOM", 0, -20)
	h.glow:SetVertexColor(0, 0, 0, 1)

	h.highlight = h:CreateTexture(nil, "OVERLAY", nil, -4)
	h.highlight:SetTexture("Interface\\AddOns\\DiabolusForever\\media\\targettarget_highlight")
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
	h.glow:SetTexture("Interface\\AddOns\\DiabolusForever\\media\\targettarget_ppglow")
	h.glow:SetAllPoints(self)
	h.glow:SetVertexColor(0, 0, 0, 1)

	self.Power = h
	self.Power.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut
end

func.updatePetText = function(self)
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

func.refreshPetFrame = function()
	local self = unit.pet or rawget(_G, "Roth_UIPetFrame")
	if not self then
		return
	end
	func.updatePetText(self)
	if self.Castbar then
		self.Castbar:SetShown(self.cfg.castbar and self.cfg.castbar.show ~= false)
	end
	if self.PetHappiness then
		self.PetHappiness:SetShown(self.cfg.happiness and self.cfg.happiness.show ~= false)
	end
	if self.Portrait then
		self.Portrait:SetShown(self.cfg.portrait and self.cfg.portrait.show ~= false)
	end
end

--create health power strings
local createHealthPowerStrings = function(self)
	local name = func.createFontString(self, cfg.font, self.cfg.nameSize or 14, "THINOUTLINE")
	name:SetPoint("BOTTOM", self, "TOP", 0, -13)
	name:SetPoint("LEFT", self.Health, 0, 0)
	name:SetPoint("RIGHT", self.Health, 0, 0)
	self.Name = name

	local hpval = func.createFontString(self.Health, cfg.font, 11, "THINOUTLINE")
	hpval:SetPoint("RIGHT", -2, 0)
	self.hpval = hpval

	self:Tag(name, "[diablo:name]")
	func.updatePetText(self)
end

-- Pet Happiness
local createPetHappiness = function(self)
	local cfg = self.cfg.happiness

	local f = CreateFrame("Frame", nil, self)
	f:SetSize(16 * cfg.scale, 16 * cfg.scale)
	if self.portraitSide and self.Portrait then
		-- a badge on the portrait's lower right corner
		f:SetPoint("CENTER", self.Portrait, "BOTTOMRIGHT", -2, 2)
		f:SetFrameLevel(self:GetFrameLevel() + 5)
	else
		f:SetPoint(cfg.pos.a1, self.Name, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
	end
	self.PetHappiness = f
end

-- PET STYLE FUNC

local function createStyle(self)
	--apply config to self
	self.cfg = cfg.units.pet
	self.cfg.style = "pet"

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

	--create portrait
	if self.cfg.portrait.show then
		func.createPortrait(self)
		local size = self.cfg.portrait.size or self.cfg.width
		self:SetHitRectInsets(0, 0, -(size - 28), 0)
		-- Keep the compact portrait on the health-bar frame, with its name directly above.
		local holder = self.PortraitHolder
		if holder and self.cfg.portrait.side then
			-- portrait beside the frame on the left, vertically centred on the bars; the art has
			-- an empty margin of ~1/5 of its width, so its visible edge meets the bars' stone
			holder:ClearAllPoints()
			-- measured in game (13.51.09): visible edge meets the bars' stone cap, centre on the
			-- name + bars block (the portrait is about as tall as that block)
			holder:SetPoint("RIGHT", self, "LEFT", self.cfg.portrait.sideX or 60, self.cfg.portrait.sideY or 16)
			self:SetHitRectInsets(-(size * 0.6), 0, 0, 0)
			self.portraitSide = true
			-- createPortrait lifted the name above a top portrait; back over the health bar
			self.Name:ClearAllPoints()
			self.Name:SetPoint("BOTTOM", self, "TOP", 0, self.cfg.nameY or -13)
			self.Name:SetPoint("LEFT", self.Health, 0, 0)
			self.Name:SetPoint("RIGHT", self.Health, 0, 0)
		elseif holder and size < self.cfg.width then
			local k = holder:GetScale()
			holder:ClearAllPoints()
			holder:SetPoint("BOTTOM", self, "TOP", 0, (-35 * k + (self.cfg.portrait.lift or -14)) / k)
			self.Name:ClearAllPoints()
			self.Name:SetPoint("BOTTOM", self.Portrait, "TOP", 0, 6)
		end
	end

	--castbar
	if self.cfg.castbar.show then
		func.createCastbar(self)
	elseif self.cfg.castbar.hideDefault then
		if PetCastingBarFrame then
			PetCastingBarFrame:UnregisterAllEvents()
			ns.Blizz.Conceal(PetCastingBarFrame)
		end
	end

	--auras
	if self.cfg.auras.show then
		-- the shared spot hangs below the frame, which is on the orb glass when the pet frame
		-- sits above an orb: put them beside the portrait instead, growing right
		local pos
		if self.portraitSide then
			-- above the name, growing right and up (free space over the frame)
			pos = { a1 = "BOTTOMLEFT", rel = self.Health, a2 = "TOPLEFT", x = 0, y = 16 }
			pos.initialAnchor = "BOTTOMLEFT"
			pos.growthY = "UP"
		elseif self.Portrait then
			pos = { a1 = "TOPLEFT", rel = self.Portrait, a2 = "TOPRIGHT", x = 8, y = 0 }
		end
		func.createDebuffs(self, pos)
		if self.cfg.auras.showBuffs then
			func.createBuffs(self)
		end
	end

	--debuffglow
	func.createDebuffGlow(self)

	--make alternative power bar movable (vehicle)
	if self.cfg.altpower.show then
		func.createAltPowerBar(self, "oUF_AltPowerPet")
	end

	--threat
	self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", func.checkThreat)

	--icons
	self.RaidTargetIndicator = func.createIcon(self, "BACKGROUND", 18, self.Name, "BOTTOM", "TOP", 0, 0, -1)

	--happiness
	createPetHappiness(self)

	--add self to unit container (maybe access to that unit is needed in another style)
	unit.pet = self
end

-- SPAWN PET UNIT

if cfg.units.pet.show then
	oUF:RegisterStyle("diablo:pet", createStyle)
	oUF:SetActiveStyle("diablo:pet")
	oUF:Spawn("pet", "Roth_UIPetFrame")
end
