--get the addon namespace
local addon, ns = ...

--get oUF namespace (just in case needed)
local oUF = ns.oUF or oUF
local Secrets = ns.Secrets

--get the config
local cfg = ns.cfg
--get the database
local db = ns.db

--get the functions
local func = ns.func

--get the unit container
local unit = ns.unit

--get the bars container
local bars = ns.bars

local floor, abs, sin, pi = floor, math.abs, math.sin, math.pi
local tinsert = tinsert

---------------------------------------------
-- UNIT SPECIFIC FUNCTIONS
---------------------------------------------

--init parameters
local initUnitParameters = function(self)
	self:SetFrameStrata("LOW")
	self:SetFrameLevel(1)
	self:SetSize(self.cfg.size, self.cfg.size)
	self:SetScale(self.cfg.scale)
	self:SetPoint(self.cfg.pos.a1, self.cfg.pos.af, self.cfg.pos.a2, self.cfg.pos.x, self.cfg.pos.y)
	self:RegisterForClicks("AnyDown")
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
	func.applyDragFunctionality(self, "orb")
end

--actionbar background (compact zork bar1/bar2/bar3 slot grid in Standard Mode)
local createActionBarBackground = function(self)
	local cfg = self.cfg.art.actionbarbackground
	local f = CreateFrame("Frame", "Roth_UIActionBarBackground", UIParent)
	f:SetFrameStrata("LOW")
	f:SetFrameLevel(0)
	f:SetSize(cfg.width or 512, cfg.height or 256)
	f:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
	f:SetScale(cfg.scale or 1)
	f.defaultPosition = {
		a1 = cfg.pos.a1 or "BOTTOM",
		af = cfg.pos.af or "UIParent",
		a2 = cfg.pos.a2 or "BOTTOM",
		x = cfg.pos.x or 0,
		y = cfg.pos.y or 0,
	}

	f:EnableMouse(false)
	func.applyDragFunctionality(f)

	if f.dragframe then
		f.dragframe:ClearAllPoints()
		f.dragframe:SetSize(220, 22)
		f.dragframe:SetPoint("BOTTOM", f, "BOTTOM", 0, 110)
		if f.dragframe.texture then
			f.dragframe.texture:SetColorTexture(0, 0.8, 0.2)
			f.dragframe.texture:SetAlpha(0.4)
		end
		local label = f.dragframe:CreateFontString(nil, "OVERLAY")
		label:SetFont(ns.cfg.font or "Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
		label:SetPoint("CENTER", 0, 0)
		label:SetText("Action Bar Stone Grid (Drag)")
		label:SetTextColor(1, 1, 1, 0.9)
	end

	local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetAllPoints(f)
	f.texture = t

	-- The action buttons are anchored to this frame, so in combat it is
	-- protected by anchoring: Show/Hide here is refused ("Roth_UIActionBarBackground:Show()
	-- blocked"). Defer the whole update to PLAYER_REGEN_ENABLED instead.
	local pendingTexture = false
	local setupBarTexture = function()
		if InCombatLockdown() then
			pendingTexture = true
			return
		end
		pendingTexture = false
		local isPad = (ns.StandardMode and ns.StandardMode.IsGamepad and ns.StandardMode:IsGamepad())
			or (
				C_InputInterfaceStyle
				and C_InputInterfaceStyle.GetCurrentStyle
				and Enum.InputDeviceInterfaceType
				and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
			)
		if not cfg.show or isPad then
			f:Hide()
			if t then
				t:SetTexture(nil)
			end
			if ns.bars and ns.bars.UpdateStatusBarLayout then
				ns.bars.UpdateStatusBarLayout()
			end
			return
		end
		f:Show()

		local leftShown = MultiBarBottomLeft and MultiBarBottomLeft:IsShown()
		local rightShown = MultiBarBottomRight and MultiBarBottomRight:IsShown()
		if leftShown and rightShown then
			t:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\bar3")
		elseif leftShown or rightShown then
			t:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\bar2")
		else
			t:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\bar1")
		end

		if ns.bars and ns.bars.UpdateStatusBarLayout then
			ns.bars.UpdateStatusBarLayout()
		end
	end

	local function applySize()
		if InCombatLockdown() then
			return
		end
		local w, h = cfg.width or 512, cfg.height or 256
		if math.abs(f:GetWidth() - w) > 0.5 or math.abs(f:GetHeight() - h) > 0.5 then
			f:SetSize(w, h)
		end
		setupBarTexture()
	end
	ns.PlayerArtApplySize = applySize

	setupBarTexture()
	ns.PlayerArt = { frame = f, texture = t, refresh = setupBarTexture }
	if MultiBarBottomRight then
		MultiBarBottomRight:HookScript("OnShow", setupBarTexture)
		MultiBarBottomRight:HookScript("OnHide", setupBarTexture)
	end
	if MultiBarBottomLeft then
		MultiBarBottomLeft:HookScript("OnShow", setupBarTexture)
		MultiBarBottomLeft:HookScript("OnHide", setupBarTexture)
	end

	f:RegisterEvent("PLAYER_LOGIN")
	f:RegisterEvent("PLAYER_LEVEL_UP")
	f:RegisterEvent("UNIT_ENTERED_VEHICLE")
	f:RegisterEvent("UNIT_EXITED_VEHICLE")
	f:RegisterEvent("UNIT_INVENTORY_CHANGED")
	f:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function(_, event, evUnit)
		if event == "PLAYER_REGEN_ENABLED" then
			if pendingTexture then
				setupBarTexture()
			end
			return
		end
		if evUnit and Secrets.IsSecret(evUnit) then
			return
		end
		if evUnit and evUnit ~= "player" and event ~= "INPUT_DEVICE_INTERFACE_TRANSITION" then
			return
		end
		if event == "PLAYER_LOGIN" then
			applySize()
			if ns.bars and ns.bars.UpdateStatusBarLayout then
				ns.bars.UpdateStatusBarLayout()
			end
			if ns.Belt and ns.Belt.Place then
				ns.Belt.Place()
			end
			return
		end
		setupBarTexture()
	end)
end
--create the angel
local createAngelFrame = function(self)
	if not self.cfg.art.angel.show then
		return
	end
	local f = CreateFrame("Frame", "Roth_UIAngelFrame", UIParent)
	f:SetSize(320, 160)
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(0)
	f:SetPoint(
		self.cfg.art.angel.pos.a1,
		self.cfg.art.angel.pos.af,
		self.cfg.art.angel.pos.a2,
		self.cfg.art.angel.pos.x,
		self.cfg.art.angel.pos.y
	)
	f:SetScale(self.cfg.art.angel.scale)
	func.applyDragFunctionality(f)
	local t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	t:SetAllPoints(f)
	t:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\d3_angel2")
end

--create the demon
local createDemonFrame = function(self)
	if not self.cfg.art.demon.show then
		return
	end
	local f = CreateFrame("Frame", "Roth_UIDemonFrame", UIParent)
	f:SetSize(320, 160)
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(0)
	f:SetPoint(
		self.cfg.art.demon.pos.a1,
		self.cfg.art.demon.pos.af,
		self.cfg.art.demon.pos.a2,
		self.cfg.art.demon.pos.x,
		self.cfg.art.demon.pos.y
	)
	f:SetScale(self.cfg.art.demon.scale)
	func.applyDragFunctionality(f)
	local t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	t:SetAllPoints(f)
	t:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\d3_demon2")
end

--create the bottomline
local createBottomLine = function(self)
	local cfg = self.cfg.art.bottomline
	if not cfg.show then
		return
	end
	local f = CreateFrame("Frame", "Roth_UIBottomLine", UIParent)
	-- Keep on LOW strata level 1 so XP/Rep bars (LOW level 5) sit visibly inside the stone trough
	f:SetFrameStrata("LOW")
	f:SetFrameLevel(1)
	f:SetSize(670, 112)
	f:SetPoint(cfg.pos.a1, cfg.pos.af, cfg.pos.a2, cfg.pos.x, cfg.pos.y)
	f:SetScale(cfg.scale)
	func.applyDragFunctionality(f, "bottomline")
	local t = f:CreateTexture(nil, "BACKGROUND", nil, 3)
	t:SetAllPoints(f)
	t:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\d3_bottom")
end

--post update orb func (used to display lowHp on percentage)
local updateValue = function(bar, unit, cur, max)
	local curNum, maxNum = Secrets.Number(cur), Secrets.Number(max)
	local isDead = Secrets.Bool(UnitIsDeadOrGhost, unit)
	local per
	if curNum and maxNum then
		per = (maxNum > 0) and floor(curNum / maxNum * 100) or 0
	end
	local orb = bar:GetParent()
	local self = orb:GetParent()
	if orb.type == "HEALTH" then
		if isDead then
			orb.lowHP:SetAlpha(1)
			orb.lowHP:Show()
			orb.skull:Show()
		elseif per ~= nil then
			orb.skull:Hide()
			if per <= 25 then
				orb.lowHP:SetAlpha(1)
				orb.lowHP:Show()
			else
				orb.lowHP:Hide()
			end
		else
			orb.skull:Hide()
			local curve = Secrets.LowHealthCurve()
			if curve and UnitHealthPercent then
				local ok, alpha = pcall(UnitHealthPercent, unit, true, curve)
				if ok and alpha ~= nil then
					orb.lowHP:SetAlpha(alpha)
					orb.lowHP:Show()
				else
					orb.lowHP:Hide()
				end
			else
				orb.lowHP:Hide()
			end
		end
	end
	if db.char[orb.type].value.hideOnEmpty and (isDead or (curNum and curNum < 1)) then
		orb.values:Hide()
	elseif db.char[orb.type].value.hideOnFull and (curNum and maxNum and curNum == maxNum) then
		orb.values:Hide()
	elseif not orb.values:IsShown() then
		orb.values:Show()
	end
	if orb.type == "HEALTH" then
		orb.values.top:SetText(oUF.Tags.Methods["diablo:HealthOrbTop"](self.unit or "player"))
		orb.values.bottom:SetText(oUF.Tags.Methods["diablo:HealthOrbBottom"](self.unit or "player"))
	elseif orb.type == "POWER" then
		orb.values.top:SetText(oUF.Tags.Methods["diablo:PowerOrbTop"](self.unit or "player"))
		orb.values.bottom:SetText(oUF.Tags.Methods["diablo:PowerOrbBottom"](self.unit or "player"))
	end
	if isDead then
		bar:SetValue(0)
	end
	if ns.panel and ns.panel.IsShown and ns.panel:IsShown() then
		if ns.panel.eventHelper and ns.panel.eventHelper.SetOrbsToMax then
			ns.panel.eventHelper:SetOrbsToMax()
		end
	end
end

--update spark func
local updateStatusBarColor = function(bar, r, g, b)
	local orb = bar:GetParent()
	orb.spark:SetVertexColor(r, g, b)
	if orb.galaxies then
		for i, galaxy in pairs(orb.galaxies) do
			galaxy:SetVertexColor(r, g, b)
		end
	end
	if orb.bubbles then
		for i, bubble in pairs(orb.bubbles) do
			bubble:SetVertexColor(r, g, b)
		end
	end
end

--update orb func
local updateOrb = function(bar, value)
	local orb = bar:GetParent()
	local valNum = Secrets.Number(value)
	local _, rawMax = bar:GetMinMaxValues()
	local maxNum = Secrets.Number(rawMax)
	if not valNum or not maxNum then
		orb.scrollFrame:SetHeight(orb.size)
		orb.scrollFrame:SetVerticalScroll(0)
		orb.scrollFrame:SetPoint("TOP", 0, 0)
		if orb.spark then
			orb.spark:Hide()
		end
		return
	end
	local per = 1
	local h = orb.size * per
	if maxNum > 0 then
		per = valNum / maxNum * 100
	end
	if valNum < 1 then
		per = 1
	end
	local offset = orb.size - per * orb.size / 100
	orb.scrollFrame:SetHeight(h)
	orb.scrollFrame:SetVerticalScroll(offset)
	orb.scrollFrame:SetPoint("TOP", 0, -offset)
	--adjust the orb spark in width/height matching the current scrollframe state
	if not orb.spark then
		return
	end
	local multiplier = floor(sin(per / 100 * pi) * 1000) / 1000
	if multiplier <= 0.25 then
		orb.spark:Hide()
	else
		orb.spark:SetWidth(256 * orb.size / 256 * multiplier)
		orb.spark:SetHeight(32 * orb.size / 256 * multiplier)
		orb.spark:SetPoint("TOP", orb.scrollFrame, 0, 16 * orb.size / 256 * multiplier)
		orb.spark:Show()
	end
end

--create galaxy func
local createGalaxy = function(frame, type, x, y, size, duration, texture, sublevel, degree)
	local t = frame:CreateTexture(nil, "OVERLAY", nil, sublevel)
	t:SetSize(size, size)
	t:SetPoint("CENTER", x, y)
	t:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\" .. texture)
	t:SetBlendMode("ADD")
	t.ag = t:CreateAnimationGroup()
	t.ag.anim = t.ag:CreateAnimation("Rotation")
	t.ag.anim:SetDegrees(degree)
	t.ag.anim:SetDuration(duration)
	t.ag:Play()
	t.ag:SetLooping("REPEAT")
	return t
end

--create orb func
local createOrb = function(self, type)
	--get the orb config
	local orbcfg = db.char[type]
	local name
	if type == "HEALTH" then
		name = "Roth_UIHealthOrb"
	else
		name = "Roth_UIPowerOrb"
	end
	--create the orb baseframe
	local orb = CreateFrame("Frame", name, self)
	--orb data
	orb.self = self
	orb.type = type
	orb.size = self.cfg.size
	orb:SetSize(orb.size, orb.size)
	--position the orb
	if orb.type == "POWER" then
		--reset the power to be on the opposite side of the health orb
		orb:SetPoint(self.cfg.pos.a1, self.cfg.pos.af, self.cfg.pos.a2, self.cfg.pos.x * -1, self.cfg.pos.y)
		--make the power orb dragable
		func.applyDragFunctionality(orb, "orb")
	else
		--position the health orb ontop of the self object
		orb:SetPoint("CENTER")
	end

	if orb.type == "HEALTH" then
		--debuff glow
		local glow = orb:CreateTexture("$parentGlow", "BACKGROUND", nil, -7)
		glow:SetPoint("CENTER", 0, 0)
		glow:SetSize(self.cfg.size + 5, self.cfg.size + 5)
		glow:SetBlendMode("BLEND")
		glow:SetVertexColor(0, 1, 1, 0) -- set alpha to 0 to hide the texture
		glow:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\orb_debuff_glow")
		orb.glow = glow
		self.DebuffHighlight = orb.glow
		self.DebuffHighlightAlpha = 1
		self.DebuffHighlightFilter = false
	end

	--background
	local bg = orb:CreateTexture("$parentBG", "BACKGROUND", nil, -6)
	bg:SetAllPoints()
	bg:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\orb_back2")
	orb.bg = bg

	--filling statusbar
	local fill = CreateFrame("StatusBar", "$parentFill", orb)
	fill:SetAllPoints()
	fill:SetMinMaxValues(0, 100)
	fill:SetStatusBarTexture(orbcfg.filling.texture)
	fill:SetStatusBarColor(orbcfg.filling.color.r, orbcfg.filling.color.g, orbcfg.filling.color.b)
	fill:SetOrientation("VERTICAL")
	fill:SetScript("OnValueChanged", updateOrb)
	orb.fill = fill

	--scroll frame
	local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", orb)
	scrollFrame:SetPoint("BOTTOM")
	scrollFrame:SetSize(orb:GetSize())

	--scroll child
	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(orb:GetSize())
	scrollFrame:SetScrollChild(scrollChild)

	--orb model
	local model = CreateFrame("PlayerModel", nil, scrollChild)
	model:SetSize(orb:GetSize())
	model:SetPoint("TOP")
	model:SetAlpha(orbcfg.model.alpha or 1)
	orb.scrollFrame = scrollFrame

	--update model func
	function model:Update()
		local cfg = db.char[self.type].model
		self:SetCamDistanceScale(cfg.camDistanceScale)
		self:SetPosition(0, cfg.pos_x, cfg.pos_y)
		self:SetRotation(cfg.rotation)
		self:SetPortraitZoom(cfg.portraitZoom)
		self:ClearModel()
		--self:SetModel("interface\\buttons\\talktomequestionmark.m2") --in case setdisplayinfo fails
		self:SetDisplayInfo(cfg.displayInfo)
		-- The model presets are display IDs from later expansions; WoW Forever's
		-- game files may not have them. A second later, note whether anything
		-- loaded (/roth pad lists it) instead of leaving an empty layer unexplained.
		if cfg.enable and C_Timer and self.GetModelFileID then
			local model, id = self, cfg.displayInfo
			C_Timer.After(1, function()
				local ok, file = pcall(model.GetModelFileID, model)
				ns.OrbModels = ns.OrbModels or {}
				-- (no type() here: createOrb's "type" argument shadows it)
				ns.OrbModels[model.type] = { displayInfo = id, loaded = (ok and file and file ~= 0) and true or false }
			end)
		end
	end
	model.type = orb.type
	model:SetScript("OnEvent", function(self)
		self:Update()
	end)
	model:RegisterEvent("PLAYER_ENTERING_WORLD")
	model:SetScript("OnShow", function(self)
		self:Update()
	end)
	model:Update()
	orb.model = model

	--galaxies
	orb.galaxies = {}
	tinsert(orb.galaxies, createGalaxy(scrollChild, orb.type, 0, 0, orb.size - 0, 120, "galaxy2", -8, 360))
	tinsert(orb.galaxies, createGalaxy(scrollChild, orb.type, 0, -2, orb.size - 20, 90, "galaxy", -7, 360))
	tinsert(orb.galaxies, createGalaxy(scrollChild, orb.type, 0, -4, orb.size - 5, 60, "galaxy4", -6, 360))
	-- a slow fourth spiral, turning the other way (the spare galaxy3 art)
	tinsert(orb.galaxies, createGalaxy(scrollChild, orb.type, 0, -3, orb.size - 10, 150, "galaxy3", -6, -360))
	for i, galaxy in pairs(orb.galaxies) do
		galaxy:SetVertexColor(orbcfg.filling.color.r, orbcfg.filling.color.g, orbcfg.filling.color.b)
	end

	--bubbles
	orb.bubbles = {}
	tinsert(
		orb.bubbles,
		createGalaxy(scrollChild, orb.type, 0, 0, orb.size - 12, 10, "orb_rotation_bubbles1", -8, -360)
	)
	tinsert(orb.bubbles, createGalaxy(scrollChild, orb.type, 0, 0, orb.size - 0, 20, "orb_rotation_bubbles2", -7, 360))
	tinsert(orb.bubbles, createGalaxy(scrollChild, orb.type, 0, 0, orb.size - 12, 15, "orb_rotation_bubbles1", -6, 360))
	tinsert(orb.bubbles, createGalaxy(scrollChild, orb.type, 0, 0, orb.size - 0, 20, "orb_rotation_bubbles2", -7, -360))
	tinsert(orb.bubbles, createGalaxy(scrollChild, orb.type, 0, 0, orb.size - 6, 25, "orb_rotation_bubbles3", -6, 360))
	for i, bubble in pairs(orb.bubbles) do
		bubble:SetVertexColor(orbcfg.filling.color.r, orbcfg.filling.color.g, orbcfg.filling.color.b)
	end

	--overlay frame
	local overlay = CreateFrame("Frame", "$parentOverlay", scrollFrame)
	--overlay:SetFrameLevel(model:GetFrameLevel()+1)
	overlay:SetAllPoints(orb)
	orb.overlay = orb

	--spark frame
	local spark = overlay:CreateTexture(nil, "BACKGROUND", nil, -3)
	spark:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\orb_spark")
	--the spark should fit the filling color otherwise it will stand out too much
	spark:SetVertexColor(orbcfg.filling.color.r, orbcfg.filling.color.g, orbcfg.filling.color.b)
	spark:SetWidth(256 * orb.size / 256)
	spark:SetHeight(32 * orb.size / 256)
	spark:SetPoint("TOP", scrollFrame, 0, -16 * orb.size / 256)
	--texture will be blended by blendmode, http://wowprogramming.com/docs/widgets/Texture/SetBlendMode
	spark:SetAlpha(orbcfg.spark.alpha or 1)
	spark:SetBlendMode("ADD")
	spark:Hide()
	orb.spark = spark

	--inner shadow: darkens the rim so the liquid reads as inside the glass
	if cfg.orbInnerShadow ~= false then
		local shade = overlay:CreateTexture(nil, "BACKGROUND", nil, -4)
		shade:SetAllPoints(orb)
		shade:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\orb_innershadow")
		shade:SetVertexColor(0, 0, 0, 0.6)
		orb.innerShadow = shade
	end

	--skull+lowhp
	if orb.type == "HEALTH" then
		local skull = overlay:CreateTexture(nil, "BACKGROUND", nil, 1)
		skull:SetPoint("CENTER", 0, 0)
		skull:SetSize(self.cfg.size - 40, self.cfg.size - 40)
		skull:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\d2_skull")
		skull:SetBlendMode("ADD")
		skull:SetAlpha(0.6)
		skull:Hide()
		orb.skull = skull

		local lowHP = overlay:CreateTexture(nil, "BACKGROUND", nil, 2)
		lowHP:SetPoint("CENTER", 0, 0)
		lowHP:SetSize(self.cfg.size - 15, self.cfg.size - 15)
		lowHP:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\orb_lowhp_glow")
		lowHP:SetBlendMode("ADD")
		lowHP:SetVertexColor(1, 0, 0, 1)
		lowHP:Hide()
		orb.lowHP = lowHP
	end

	--highlight
	local highlight = overlay:CreateTexture("$parentHighlight", "BACKGROUND", nil, 3)
	highlight:SetAllPoints()
	highlight:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\orb_gloss")
	highlight:SetAlpha(orbcfg.highlight.alpha or 1)
	orb.highlight = highlight

	--orb values
	local values = CreateFrame("Frame", "$parentValues", overlay)
	values:SetAllPoints(orb)
	--top value
	values.top = func.createFontString(values, cfg.font, 28, "THINOUTLINE")
	values.top:SetPoint("CENTER", 0, 10)
	values.top:SetTextColor(orbcfg.value.top.color.r, orbcfg.value.top.color.g, orbcfg.value.top.color.b)
	--bottom value
	values.bottom = func.createFontString(values, cfg.font, 16, "THINOUTLINE")
	values.bottom:SetPoint("CENTER", 0, -10)
	values.bottom:SetTextColor(orbcfg.value.top.color.r, orbcfg.value.top.color.g, orbcfg.value.top.color.b)
	orb.values = values

	--register the tags
	if orb.type == "HEALTH" then
		self:Tag(orb.values.top, "[diablo:HealthOrbTop]")
		self:Tag(orb.values.bottom, "[diablo:HealthOrbBottom]")
	else
		self:Tag(orb.values.top, "[diablo:PowerOrbTop]")
		self:Tag(orb.values.bottom, "[diablo:PowerOrbBottom]")
	end

	if orb.type == "POWER" then
		self.Power = orb.fill
		ns.PowerOrb = orb --save the orb in the namespace
		hooksecurefunc(self.Power, "SetStatusBarColor", updateStatusBarColor)
		self.Power.frequentUpdates = self.cfg.power.frequentUpdates or false
		self.Power.Smooth = false -- Disabled: smooth animation breaks orb scroll frame sync
		self.Power.colorPower = orbcfg.filling.colorAuto or false
		self.Power.PostUpdate = updateValue
		ns.FiveSecond.Attach(orb)
		ns.PowerCost.Attach(orb, orbcfg.filling.texture)
	else
		self.Health = orb.fill
		ns.HealthOrb = orb --save the orb in the namespace
		hooksecurefunc(self.Health, "SetStatusBarColor", updateStatusBarColor)
		self.Health.frequentUpdates = self.cfg.health.frequentUpdates or false
		self.Health.Smooth = false -- Disabled: smooth animation breaks orb scroll frame sync
		self.Health.colorClass = orbcfg.filling.colorAuto or false
		self.Health.colorHealth = orbcfg.filling.colorAuto or false --when player switches into a vehicle it will recolor the orb
		--we need to display the lowhp on a certain threshold without smoothing, so we use the postUpdate for that
		self.Health.PostUpdate = updateValue
		ns.OrbShield.Attach(orb)
	end
	--print(addon..": orb created "..orb.type)
end

local OnClick = function(butt)
	DestroyTotem(butt.slot)
end

local Totems = function(self)
	if not self.cfg.TotemBar.show then
		return
	end

	local TotemDrag = CreateFrame("Frame", "Roth_TotemFrame", self)
	TotemDrag:SetSize(140, 40)
	TotemDrag:SetPoint("TOP", 0, 15)
	TotemDrag:SetPoint("LEFT")
	TotemDrag:SetPoint("RIGHT")

	func.applyDragFunctionality(TotemDrag, "totem")

	local Totems = {}
	for index = 1, MAX_TOTEMS do
		-- Position and size of the totem indicator
		local Totem = CreateFrame("Button", nil, TotemDrag)
		Totem:SetSize(25, 25)
		Totem:SetPoint("TOPLEFT", TotemDrag, "TOPLEFT", index * Totem:GetWidth(), 0)
		Totem.slot = index

		local Icon = Totem:CreateTexture(nil, "OVERLAY")
		Icon:SetAllPoints()

		local Cooldown = CreateFrame("Cooldown", nil, Totem, "CooldownFrameTemplate")
		Cooldown:SetAllPoints()

		Totem.Icon = Icon
		Totem.Cooldown = Cooldown

		Totems[index] = Totem
	end

	-- Register with oUF
	self.Totems = Totems
end

local DruidMana = function(self)
	local class = select(2, UnitClass("player"))
	if class ~= "DRUID" then
		return
	end
	--Create DruidMana frame
	local DM = CreateFrame("StatusBar", "Roth_DruidMana", Roth_UIPowerOrb)
	DM:SetSize(140, 20)
	DM:SetPoint("TOP", 0, 15)
	DM:SetPoint("LEFT")
	DM:SetPoint("RIGHT")
	DM:SetFrameStrata("LOW")

	func.applyDragFunctionality(DM)

	--Add Artwork
	local b = CreateFrame("Frame", nil, Roth_DruidMana)
	b:SetSize(20, 20)
	b:SetPoint("TOP")
	b:SetPoint("LEFT")
	b:SetPoint("RIGHT")
	b:SetFrameStrata("LOW")

	local br = b:CreateTexture(nil, "OVERLAY", nil)
	br:SetPoint("TOP", 0, 8)
	br:SetPoint("LEFT", -50, 0)
	br:SetPoint("RIGHT", 50, 0)
	br:SetPoint("BOTTOM", 0, -8)
	br:SetTexture("Interface\\AddOns\\DiabolusUnits\\media\\d3_altpower_border")

	b:RegisterEvent("PLAYER_ENTERING_WORLD")
	b:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	b:SetScript("OnEvent", function(...)
		local self, event, unit = ...
		if unit and unit ~= "player" then
			return
		end
		local playerclass = select(2, UnitClass("player"))
		if playerclass == "DRUID" and (GetShapeshiftForm() == 1 or GetShapeshiftForm() == 3) then
			b:Show()
		else
			b:Hide()
		end
	end)

	--Register with oUF
	self.DruidMana = DM
	self.DruidMana.colorPower = DM
	self.DruidMana.bg = nil
end

---------------------------------------------
-- PLAYER STYLE FUNC
---------------------------------------------

local createStyle = function(self)
	--apply config to self
	self.cfg = cfg.units.player
	self.cfg.style = "player"

	--init
	initUnitParameters(self)

	--experience bar
	bars.createExpBar(self)

	--reputation bar
	bars.createRepBar(self)

	--create the actionbarbackground
	createActionBarBackground(self)

	--create the health orb
	createOrb(self, "HEALTH")
	--create the power orb
	createOrb(self, "POWER")

	if bars and bars.UpdateStatusBarLayout then
		bars.UpdateStatusBarLayout()
	end
	if ns.Belt and ns.Belt.Place then
		ns.Belt.Place()
	end

	--druidmana
	DruidMana(self)

	--totems
	Totems(self)

	--create art textures do this now for correct frame stacking
	createAngelFrame(self)
	createDemonFrame(self)

	--bottomline
	createBottomLine(self)

	--icons
	if self.cfg.icons.resting.show then
		local pos = self.cfg.icons.resting.pos
		self.Resting = func.createIcon(self, "OVERLAY", 32, self, pos.a1, pos.a2, pos.x, pos.y, -1)
	end
	if self.cfg.icons.pvp.show then
		local pos = self.cfg.icons.pvp.pos
		self.PvP = func.createIcon(self, "OVERLAY", 44, self, pos.a1, pos.a2, pos.x, pos.y, -1)
	end
	if self.cfg.icons.combat.show then
		local pos = self.cfg.icons.combat.pos
		self.Combat = func.createIcon(self, "OVERLAY", 32, self, pos.a1, pos.a2, pos.x, pos.y, -1)
	end

	--castbar
	if self.cfg.castbar.show then
		--load castingbar
		func.createCastbar(self)
		ns.CastBars.AddChannelTicks(self.Castbar)
	elseif self.cfg.castbar.hideDefault then
		if CastingBarFrame then
			CastingBarFrame:UnregisterAllEvents()
			ns.Blizz.Conceal(CastingBarFrame)
		end
	end

	--combobar
	if (cfg.playerclass == "ROGUE" or cfg.playerclass == "DRUID") and self.cfg.combobar.show then
		bars.createComboBar(self)
	end

	--create portrait
	if self.cfg.portrait.show then
		func.createStandAlonePortrait(self)
	end

	--make alternative power bar movable
	if self.cfg.altpower.show then
		func.createAltPowerBar(self, "oUF_AltPowerPlayer")
	end

	--add self to unit container (maybe access to that unit is needed in another style)
	unit.player = self
end

---------------------------------------------
-- SPAWN PLAYER UNIT
---------------------------------------------
if cfg.units.player.show then
	oUF:RegisterStyle("diablo:player", createStyle)
	oUF:SetActiveStyle("diablo:player")
	oUF:Spawn("player", "Roth_UIPlayerFrame")
end
