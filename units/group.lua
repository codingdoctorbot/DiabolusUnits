---------------------------------------------
--  Roth_UI - group frames (shared)
---------------------------------------------
-- Building blocks for the party and raid layouts (DESIGN.md §5): zork's
-- targettarget bar art with spiked iron endcaps, made secret-safe for WoW
-- Forever. Health, auras, range and threat may be secret in combat, so
-- nothing here compares or does arithmetic on them: values go to C setters
-- and curves, and the server-side aura filters pick what is shown.

local _, ns = ...

local cfg = ns.cfg
local func = ns.func
local Secrets = ns.Secrets

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"

local Group = {}
ns.Group = Group

-- Aura filters understood by WoW Forever (Blizzard_FrameXMLUtil/AuraUtil.lua
-- AuraUtil.AuraFilters). The server decides, so no aura data is inspected.
Group.FILTER_DEBUFFS = "HARMFUL|RAID_IN_COMBAT" -- debuffs flagged for raid frames
Group.FILTER_MY_BUFFS = "HELPFUL|PLAYER|RAID_IN_COMBAT" -- your own HoTs and shields
Group.FILTER_DISPELLABLE = "HARMFUL|RAID" -- debuffs you can dispel

-- Geometry per layout, taken from the original art placement:
-- party = units/targettarget.lua (150x64, health + power),
-- raid  = zork's oUF_Diablo raid.lua (128x64, health only),
-- tile  = the raid as square Diablo tiles (raid_back / raid_border art,
--         health filling upwards like a small orb), for 40-player raids;
--         cfg.units.raid.layout = "tiles" (the default) or "bars".
Group.LAYOUT = {
	party = {
		width = 150,
		height = 64,
		health = { top = -29, left = 30.5, right = -30.5, bottom = 25.7 },
		power = true,
		nameSize = 14,
		nameOffset = -13,
	},
	raid = {
		width = 128,
		height = 64,
		health = { top = -21.9, left = 24.5, right = -24.5, bottom = 28.7 },
		power = false,
		nameSize = 12,
		nameOffset = -14,
	},
	tile = {
		width = 52,
		height = 52,
		tile = true,
		health = { top = -5, left = 5, right = -5, bottom = 5 },
		power = false,
		nameSize = 10,
	},
}

-- The raid's tile art: raid_border's visible ring is 166 of its 256 px, so
-- every raid_* texture is drawn at size * 256 / 166 to put the ring on the edge.
local TILE_ART = 256 / 166

-- The geometry a frame of this kind uses.
function Group.Layout(kind)
	if kind == "raid" and (cfg.units.raid.layout or "tiles") == "tiles" then
		return Group.LAYOUT.tile
	end
	return Group.LAYOUT[kind]
end

local function TileTexture(parent, frame, layer, sublevel, file)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(MEDIA .. file)
	t:SetPoint("CENTER", frame, "CENTER", 0, 0)
	t:SetSize(frame.groupLayout.width * TILE_ART, frame.groupLayout.height * TILE_ART)
	return t
end

---------------------------------------------
-- ART
---------------------------------------------

local function CreateArt(self)
	if self.groupLayout.tile then
		-- stone back under the health, iron ring over it (on a frame above the bar)
		TileTexture(self, self, "BACKGROUND", -8, "raid_back")
		local over = CreateFrame("Frame", nil, self)
		over:SetAllPoints(self)
		self.RothTileOverlay = over
		self.Art = TileTexture(over, self, "ARTWORK", 0, "raid_border")
		return
	end
	local t = self:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetAllPoints(self)
	t:SetTexture(MEDIA .. "targettarget")
	self.Art = t

	if self.cfg.special and self.cfg.special.chains then
		for _, x in ipairs({ -32, 32 }) do
			local c = self:CreateTexture(nil, "BACKGROUND", nil, -7)
			c:SetTexture(MEDIA .. "chain2")
			c:SetSize(32, 32)
			c:SetPoint("CENTER", x, 28)
			c:SetAlpha(0.9)
		end
	end
end

-- Glows sit around the whole frame (targettarget_debuffglow is cut for it).
local function CreateGlow(self, sublevel, r, g, b)
	local t
	if self.groupLayout.tile then
		t = TileTexture(self, self, "BACKGROUND", sublevel, "raid_debuffglow")
	else
		t = self:CreateTexture(nil, "BACKGROUND", nil, sublevel)
		t:SetTexture(MEDIA .. "targettarget_debuffglow")
		t:SetAllPoints(self)
	end
	t:SetBlendMode("BLEND")
	t:SetVertexColor(r, g, b, 1)
	t:Hide()
	return t
end

---------------------------------------------
-- HEALTH / POWER
---------------------------------------------

local function UpdateHealth(bar, unit, min, max)
	func.updateHealth(bar, unit, min, max)
	-- Low health without a Lua test: the step curve gives 1 at <= 25 %, else 0.
	local curve = Secrets.LowHealthCurve()
	if curve and UnitHealthPercent and not Secrets.Bool(UnitIsDeadOrGhost, unit) then
		local ok, alpha = pcall(UnitHealthPercent, unit, true, curve)
		if ok and alpha then -- truthiness only: alpha may be secret
			bar.lowhp:SetAlpha(alpha)
			bar.lowhp:Show()
			return
		end
	end
	bar.lowhp:Hide()
end

local function CreateHealth(self, layout)
	local inset = layout.health
	local h = CreateFrame("StatusBar", nil, self)
	h:SetPoint("TOP", 0, inset.top)
	h:SetPoint("LEFT", inset.left, 0)
	h:SetPoint("RIGHT", inset.right, 0)
	h:SetPoint("BOTTOM", 0, inset.bottom)
	h:SetStatusBarTexture(self.cfg.health.texture)

	h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -6)
	h.bg:SetTexture(self.cfg.health.texture)
	h.bg:SetAllPoints(h)

	if layout.tile then
		-- fills upwards, like a small orb; the low-health glow is raid_hpglow
		h:SetOrientation("VERTICAL")
		h:SetRotatesTexture(true)
		h.bg:SetRotation(math.pi / 2)
		h.highlight = h:CreateTexture(nil, "OVERLAY", nil, -4)
		h.highlight:SetTexture(MEDIA .. "statusbar_highlight")
		h.highlight:SetAllPoints(h)
		h.highlight:SetAlpha(0.35)
		h.lowhp = TileTexture(self.RothTileOverlay, self, "OVERLAY", 1, "raid_hpglow")
		h.lowhp:SetVertexColor(1, 0, 0, 1)
		h.lowhp:SetBlendMode("ADD")
		h.lowhp:Hide()
		h.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut
		h.PostUpdate = UpdateHealth
		self.Health = h
		self.RothTileOverlay:SetFrameLevel(h:GetFrameLevel() + 3)
		return
	end

	h.glow = h:CreateTexture(nil, "OVERLAY", nil, -5)
	h.glow:SetTexture(MEDIA .. "targettarget_hpglow")
	h.glow:SetAllPoints(self)
	h.glow:SetVertexColor(0, 0, 0, 0.7)

	h.highlight = h:CreateTexture(nil, "OVERLAY", nil, -4)
	h.highlight:SetTexture(MEDIA .. "targettarget_highlight")
	h.highlight:SetAllPoints(self)

	-- red inner glow at low health (alpha driven by the curve)
	h.lowhp = h:CreateTexture(nil, "OVERLAY", nil, -3)
	h.lowhp:SetTexture(MEDIA .. "targettarget_hpglow")
	h.lowhp:SetAllPoints(self)
	h.lowhp:SetVertexColor(1, 0, 0, 1)
	h.lowhp:SetBlendMode("ADD")
	h.lowhp:Hide()

	h.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut
	h.PostUpdate = UpdateHealth
	self.Health = h
end

local function CreatePower(self)
	local p = CreateFrame("StatusBar", nil, self.Health)
	p:SetPoint("TOP", 0, -12)
	p:SetPoint("LEFT", 4, 0)
	p:SetPoint("RIGHT", -4, 0)
	p:SetPoint("BOTTOM", 0, -10)
	p:SetStatusBarTexture(self.cfg.power.texture)

	p.bg = p:CreateTexture(nil, "BACKGROUND", nil, -6)
	p.bg:SetTexture(self.cfg.power.texture)
	p.bg:SetAllPoints(p)

	p.glow = p:CreateTexture(nil, "OVERLAY", nil, -5)
	p.glow:SetTexture(MEDIA .. "targettarget_ppglow")
	p.glow:SetAllPoints(self)
	p.glow:SetVertexColor(0, 0, 0, 1)

	p.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut
	p.PostUpdate = func.updatePower
	self.Power = p
end

function Group.GetTagForFormat(format)
	if format == "deficit" then
		return "[diablo:misshp]"
	elseif format == "percent" then
		return "[perphp]"
	elseif format == "value" then
		return "[diablo:hpval]"
	elseif format == "current" then
		return "[curshp]"
	elseif format == "both" then
		return "[cmaxshp]"
	elseif format == "none" then
		return ""
	end
	return "[diablo:misshp]"
end

function Group.RefreshHealthTags(kind)
	local fmt = cfg.units[kind] and cfg.units[kind].healthFormat
	local tag = Group.GetTagForFormat(fmt)
	for _, frame in ipairs(Group.members or {}) do
		if (not kind or frame.groupKind == kind) and frame.HealthValue then
			frame:Untag(frame.HealthValue)
			if tag ~= "" then
				frame:Tag(frame.HealthValue, tag)
				frame.HealthValue:Show()
				if frame.HealthValue.UpdateTag then
					frame.HealthValue:UpdateTag()
				end
			else
				frame.HealthValue:SetText("")
				frame.HealthValue:Hide()
			end
		end
	end
end

function Group.RefreshRangeAlpha(kind)
	local alpha = cfg.units[kind] and cfg.units[kind].alpha and cfg.units[kind].alpha.notinrange
	if not alpha then
		return
	end
	for _, frame in ipairs(Group.members or {}) do
		if (not kind or frame.groupKind == kind) and frame.Range then
			frame.Range.outsideAlpha = alpha
		end
	end
end

function Group.RefreshScale(kind)
	local scale = cfg.units[kind] and cfg.units[kind].scale
	if not scale or InCombatLockdown() then
		return
	end
	if kind == "party" and ns.partyHeader then
		ns.partyHeader:SetScale(scale)
	elseif kind == "raid" and ns.raidHeaders then
		for _, h in ipairs(ns.raidHeaders) do
			h:SetScale(scale)
		end
	end
end

local function CreateTexts(self, layout)
	local tag = Group.GetTagForFormat(self.cfg.healthFormat or "deficit")
	if layout.tile then
		-- inside the tile, over the bar: the name clipped to the tile, missing health below it
		local over = self.RothTileOverlay
		local name = func.createFontString(over, cfg.font, layout.nameSize, "THINOUTLINE")
		name:SetPoint("CENTER", self, "CENTER", 0, 6)
		name:SetWidth(layout.width - 8)
		name:SetWordWrap(false)
		self:Tag(name, "[diablo:name]")
		self.Name = name
		local hpval = func.createFontString(over, cfg.font, 9, "THINOUTLINE")
		hpval:SetPoint("CENTER", self, "CENTER", 0, -5)
		if tag ~= "" then
			self:Tag(hpval, tag)
		end
		self.HealthValue = hpval
		return
	end
	local name = func.createFontString(self, cfg.font, layout.nameSize, "THINOUTLINE")
	name:SetPoint("BOTTOM", self, "TOP", 0, layout.nameOffset)
	name:SetPoint("LEFT", self.Health, -10, 0)
	name:SetPoint("RIGHT", self.Health, 10, 0)
	self:Tag(name, "[diablo:name]")
	self.Name = name

	local hpval = func.createFontString(self.Health, cfg.font, 11, "THINOUTLINE")
	hpval:SetPoint("RIGHT", -2, 0)
	if tag ~= "" then
		self:Tag(hpval, tag)
	end
	self.HealthValue = hpval
end

---------------------------------------------
-- AURAS
---------------------------------------------

-- Spell IDs the rows never show; the client checks them (candidate filters),
-- so the blacklist holds in combat too.
local blacklist = {}
local function BuildBlacklist(list)
	for _, id in ipairs(list or {}) do
		blacklist[id] = true
	end
end

-- An oUF Auras element (client aura container, core/nativeauras.lua) filling
-- a holder that sits where Roth's row always was.
local function CreateAuraFrame(self, key, filter, size, num, pos, growthX)
	local spacing = 3
	local holder = CreateFrame("Frame", nil, self)
	holder:SetSize((size + spacing) * num, size)
	holder:SetPoint(pos.a1 or "CENTER", self, pos.a2 or pos.a1 or "CENTER", pos.x or 0, pos.y or 0)
	return ns.NativeAuras.Create(self, key, holder, {
		filter = filter,
		size = size,
		spacing = spacing,
		num = num,
		initialAnchor = (growthX == "LEFT") and "TOPRIGHT" or "TOPLEFT",
		growthX = growthX or "RIGHT",
		growthY = "DOWN",
		showType = key == "Debuffs",
		excludeSpellIDs = blacklist,
	})
end

local function CreateAuras(self)
	local acfg = self.cfg.auras
	if not (acfg and acfg.show) then
		return
	end
	BuildBlacklist(acfg.blacklist)
	if self.groupLayout.tile then
		-- two debuffs along the bottom, your own HoTs / shields in the top right
		local t = self.cfg.tiles or {}
		CreateAuraFrame(
			self,
			"Debuffs",
			Group.FILTER_DEBUFFS,
			t.debuffSize or 14,
			t.debuffs or 2,
			{ a1 = "BOTTOM", a2 = "BOTTOM", x = 0, y = 4 }
		)
		CreateAuraFrame(
			self,
			"Buffs",
			Group.FILTER_MY_BUFFS,
			t.buffSize or 10,
			t.buffs or 3,
			{ a1 = "TOPRIGHT", a2 = "TOPRIGHT", x = -4, y = -4 },
			"LEFT"
		)
		local level = self.RothTileOverlay:GetFrameLevel() + 1
		self.Debuffs:SetFrameLevel(level)
		self.Buffs:SetFrameLevel(level)
		return
	end
	local size = acfg.size or 16
	local num = acfg.num or acfg.number or 5
	local debuffPos = acfg.debuffPos or { a1 = "TOP", a2 = "BOTTOM", x = 0, y = 18 }
	CreateAuraFrame(self, "Debuffs", Group.FILTER_DEBUFFS, size, num, debuffPos)
	if acfg.showBuffs ~= false then
		local buffPos = acfg.buffPos or { a1 = "BOTTOMLEFT", a2 = "TOPRIGHT", x = -18, y = -10 }
		CreateAuraFrame(self, "Buffs", Group.FILTER_MY_BUFFS, size, num, buffPos)
	end
end

---------------------------------------------
-- STATE: dispel glow, target glow, dead skull, threat
---------------------------------------------

local function UpdateDispel(self, unit)
	local glow = self.DispelGlow
	local aura = C_UnitAuras
		and C_UnitAuras.GetAuraDataByIndex
		and C_UnitAuras.GetAuraDataByIndex(unit, 1, Group.FILTER_DISPELLABLE)
	if not aura then
		glow:Hide()
		return
	end
	local colored = false
	if C_UnitAuras.GetAuraDispelTypeColor then
		local ok, color = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, aura.auraInstanceID, Secrets.DispelCurve())
		if ok and color then
			glow:SetVertexColor(color:GetRGB())
			colored = true
		end
	end
	if not colored then
		glow:SetVertexColor(0.6, 0, 1)
	end
	glow:Show()
end

local function UpdateTarget(self, unit)
	if Secrets.UnitIsUnit(unit, "target") then
		self.TargetGlow:Show()
	else
		self.TargetGlow:Hide()
	end
end

local function UpdateDead(self, unit)
	if Secrets.Bool(UnitIsDeadOrGhost, unit) then
		self.Skull:Show()
		self.HealthValue:SetAlpha(0)
	else
		self.Skull:Hide()
		self.HealthValue:SetAlpha(1)
	end
end

local function UpdateThreat(self, unit)
	local threat = Secrets.Number(UnitThreatSituation(unit))
	if threat and threat >= 2 then
		local r, g, b = GetThreatStatusColor(threat)
		self.Art:SetVertexColor(r, g, b)
	else
		self.Art:SetVertexColor(1, 1, 1)
	end
end

-- Other modules (pad/grouptarget.lua) add fn(frame) here; they run after
-- every full update, which is also when a header gives the frame a new unit.
Group.refreshHooks = {}

local function RefreshState(self)
	local unit = self.__unit
	if not unit then
		return
	end
	UpdateDispel(self, unit)
	UpdateTarget(self, unit)
	UpdateDead(self, unit)
	UpdateThreat(self, unit)
	ns.Status.Update(self)
	ns.PrivateAuras.Update(self)
	ns.BuffCoverage.Update(self)
	for _, hook in ipairs(Group.refreshHooks) do
		hook(self)
	end
end
Group.RefreshState = RefreshState

local function OnAura(self, _, unit)
	if unit == self.__unit then
		UpdateDispel(self, unit)
	end
end

local function OnHealth(self, _, unit)
	if unit == self.__unit then
		UpdateDead(self, unit)
	end
end

local function OnThreat(self, _, unit)
	if unit == self.__unit then
		UpdateThreat(self, unit)
	end
end

local function OnTargetChanged(self)
	if self.__unit then
		UpdateTarget(self, self.__unit)
	end
end

local function CreateState(self)
	self.DispelGlow = CreateGlow(self, -6, 0.6, 0, 1)
	self.TargetGlow = CreateGlow(self, -7, 1, 0.82, 0.3)

	-- The pad layer's raid selection: red, pulsing (pad/grouptarget.lua shows it).
	local sel = CreateGlow(self, -5, 1, 0.1, 0.05)
	sel:SetBlendMode("ADD")
	local pulse = sel:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local a = pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.35)
	a:SetDuration(0.45)
	sel:SetScript("OnShow", function()
		pulse:Play()
	end)
	sel:SetScript("OnHide", function()
		pulse:Stop()
	end)
	self.PadSelect = sel

	local skull = (self.RothTileOverlay or self.Health):CreateTexture(nil, "OVERLAY", nil, 2)
	skull:SetTexture(MEDIA .. "d3_head_skull")
	if self.groupLayout.tile then
		skull:SetSize(36, 18)
	else
		skull:SetSize(48, 24)
	end
	skull:SetPoint("CENTER", self.Health, "CENTER", 0, 0)
	skull:Hide()
	self.Skull = skull

	self:RegisterEvent("UNIT_AURA", OnAura)
	self:RegisterEvent("UNIT_HEALTH", OnHealth)
	self:RegisterEvent("UNIT_CONNECTION", OnHealth)
	self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", OnThreat)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", OnTargetChanged, true)
	self.PostUpdate = RefreshState
end

---------------------------------------------
-- ICONS
---------------------------------------------

-- oUF's role / leader indicators set Blizzard atlases: keep Roth's art.
local function UpdateRole(self)
	local icon = self.GroupRoleIndicator
	local role = Secrets.String(UnitGroupRolesAssigned(self.__unit))
	if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
		icon:SetTexCoord(GetTexCoordsForRoleSmallCircle(role))
		icon:Show()
	else
		icon:Hide()
	end
end

local function CrownLeader(icon)
	icon:SetTexture(MEDIA .. "crown")
	icon:SetTexCoord(0, 1, 0, 1)
end

local function CreateIcons(self)
	self.RaidTargetIndicator = func.createIcon(self.Health, "OVERLAY", 14, self.Health, "BOTTOM", "TOP", 0, -6, 3)
	self.RaidTargetIndicator:SetTexture(MEDIA .. "raidicons")
	self.ReadyCheckIndicator = func.createIcon(self.Health, "OVERLAY", 24, self.Health, "CENTER", "CENTER", 0, 0, 4)
	if self.groupLayout.tile then
		-- tiles touch: the role sits inside, bottom left
		self.GroupRoleIndicator =
			func.createIcon(self.RothTileOverlay, "OVERLAY", 10, self.Health, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, 3)
	else
		self.GroupRoleIndicator = func.createIcon(self.Health, "OVERLAY", 12, self.Health, "TOP", "BOTTOM", 0, -2, 3)
	end
	self.GroupRoleIndicator:SetTexture(MEDIA .. "lfd_role")
	self.GroupRoleIndicator:SetDesaturated(true)
	self.GroupRoleIndicator.Override = UpdateRole
	self.LeaderIndicator = func.createIcon(self.Health, "OVERLAY", 14, self.Health, "BOTTOMLEFT", "TOPLEFT", -6, -2, 3)
	CrownLeader(self.LeaderIndicator) -- Roth's crown for the group leader
	self.LeaderIndicator.PostUpdate = CrownLeader
	-- summon / resurrection / phase / away, and the client-drawn private auras
	local tile = self.groupLayout.tile
	ns.Status.Attach(self, self.Health, tile and 16 or 20)
	ns.PrivateAuras.Attach(self, self.Health, tile and 12 or 14)
	ns.BuffCoverage.Attach(self, self.Health)
end

---------------------------------------------
-- STYLE
---------------------------------------------

-- Builds one member frame. kind is "party" or "raid".
function Group.Style(self, kind)
	local layout = Group.Layout(kind)
	self.groupLayout = layout
	self.cfg = cfg.units[kind]
	self.cfg.style = kind
	self.groupKind = kind

	self:RegisterForClicks("AnyDown")
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
	-- Above Blizzard's ghosted compact frames, so the mouse reaches ours.
	self:SetFrameStrata("MEDIUM")
	if layout.tile then
		self:SetHitRectInsets(0, 0, 0, 0)
	else
		self:SetHitRectInsets(
			layout.health.left - 6,
			-layout.health.right - 6,
			-layout.health.top - 14,
			layout.health.bottom - 8
		)
	end

	CreateArt(self)
	CreateHealth(self, layout)
	func.healPrediction(self)
	if layout.power then
		CreatePower(self)
	end
	CreateTexts(self, layout)
	CreateAuras(self)
	CreateState(self)
	CreateIcons(self)

	self.Range = {
		insideAlpha = 1,
		outsideAlpha = (self.cfg.alpha and self.cfg.alpha.notinrange) or 0.5,
	}

	Group.members = Group.members or {}
	Group.members[#Group.members + 1] = self
end

-- initialConfigFunction for SpawnHeader: size each member in secure code.
function Group.InitialConfig(kind, scale)
	local layout = Group.Layout(kind)
	return ([[
		self:SetWidth(%d)
		self:SetHeight(%d)
		self:SetScale(%f)
	]]):format(layout.width, layout.height, scale or 1)
end

-- Iterates the member frames that currently show a unit.
function Group.EachMember(kind)
	local list, i = Group.members or {}, 0
	return function()
		while true do
			i = i + 1
			local frame = list[i]
			if not frame then
				return nil
			end
			if (not kind or frame.groupKind == kind) and frame.__unit and frame:IsVisible() then
				return frame
			end
		end
	end
end

-- Drag frame + /roth unlock entry for a header anchor.
function Group.CreateAnchor(name, pos)
	local anchor = CreateFrame("Frame", name, UIParent)
	anchor:SetSize(50, 50)
	anchor:SetPoint(pos.a1, pos.af, pos.a2, pos.x, pos.y)
	func.applyDragFunctionality(anchor)
	table.insert(Roth_UI_Units, name)
	return anchor
end
