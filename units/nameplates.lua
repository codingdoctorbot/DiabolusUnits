---------------------------------------------
--  Roth_UI - Diablo nameplates
---------------------------------------------
-- Roth's own plates over WoW Forever's nameplates: zork's iron bar art
-- (targettarget, as the raid bars) with the health inside, the name and
-- level above, a head for elites / rares / bosses under it, the threat
-- colour on the iron, a gold glow on your target, a cast bar with the
-- orange interrupt-ready burn (core/castbars.lua), and the debuffs you put
-- on the unit.
--
-- How it fits the game (Blizzard_NamePlates, Forever's "Camelot" build):
--  * The game creates one base frame per plate (NAME_PLATE_CREATED) and
--    hands it a unit token on NAME_PLATE_UNIT_ADDED. A Roth plate is a child
--    of that base, so it follows it, and the game keeps placing, scaling,
--    fading and clicking the base itself; nothing of ours takes the mouse.
--  * Blizzard's own plate (base.UnitFrame, taken from a pool on every add)
--    is hidden, and kept hidden by a hook on its Show, Plater's way
--    (Plater.lua OnRetailNamePlateShow). Should it ever be protected, its
--    alpha goes to 0 instead (alpha is not restricted).
--  * Forbidden plates (friendly units inside instances) come with their own
--    events and frames that add-ons may not touch; Roth leaves them be.
--  * Soft targeting (what the gamepad will hit or talk to): the game draws
--    its icon on Blizzard's plate (NamePlateDriverMixin
--    UpdateSoftTargetIconInternal), which is hidden here, so a Roth plate
--    draws it itself with the same call (SetUnitCursorTexture, the
--    SoftTargetIcon* / SoftTargetNameplateSize settings) and adds a red glow
--    on the soft enemy.
--
-- Hidden values: health, max health, threat and cast info can be secret in
-- combat. Health goes to the status bar as it comes; the cast bar is driven
-- by the game's own duration object (UnitCastingDuration /
-- UnitChannelDuration -> StatusBar:SetTimerDuration, as Plater's Forever
-- build and Roth's oUF cast bar do); "cannot be interrupted" only sets
-- alphas (SetAlphaFromBoolean) and colours (C_CurveUtil); debuff timers use
-- C_UnitAuras.GetAuraDuration -> Cooldown:SetCooldownFromDurationObject and
-- stack counts GetAuraApplicationDisplayCount. A threat status that cannot
-- be read leaves the colour as it was. Nothing secret is compared in Lua.

local _, ns = ...

local cfg = ns.cfg
local func = ns.func
local Secrets = ns.Secrets

local NP = {}
ns.NamePlates = NP

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"
local W, H = 128, 64 -- the targettarget art
local HEALTH = { left = 24.5, right = -24.5, top = -21.9, bottom = 28.7 }
local MAX_DEBUFFS = 5

local function Opt(key, default)
	local n = cfg.nameplates
	if n and n[key] ~= nil then
		return n[key]
	end
	return default
end

NP.plates = {} -- unit token -> Roth plate
local hiddenBlizzard = setmetatable({}, { __mode = "k" }) -- Blizzard UnitFrame -> keep hidden?

---------------------------------------------
-- BUILD
---------------------------------------------

local function Text(parent, size, layer)
	local fs = func.createFontString(parent, cfg.font, size, "THINOUTLINE")
	if layer then
		fs:SetDrawLayer(layer)
	end
	return fs
end

local function CreateCastBar(plate)
	local cb = CreateFrame("StatusBar", nil, plate)
	cb:SetSize(W * 0.66, 7)
	cb:SetPoint("TOP", plate.Health, "BOTTOM", 0, -12)
	cb:SetStatusBarTexture(MEDIA .. "statusbar3")
	cb:SetStatusBarColor(1, 0.7, 0)
	cb:SetMinMaxValues(0, 1)
	cb:Hide()

	local bg = cb:CreateTexture(nil, "BACKGROUND", nil, -6)
	bg:SetTexture(MEDIA .. "statusbar3")
	bg:SetAllPoints(cb)
	bg:SetVertexColor(0.1, 0.08, 0.05, 0.8)

	-- the iron frame around it: castbar.tga's fill window is the middle 192 x 10 of 220 x 28
	local frame = cb:CreateTexture(nil, "OVERLAY", nil, 1)
	frame:SetTexture(MEDIA .. "castbar")
	frame:SetPoint("TOPLEFT", cb, "TOPLEFT", -cb:GetWidth() * 14 / 192, 9 * 7 / 10)
	frame:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", cb:GetWidth() * 14 / 192, -9 * 7 / 10)

	local icon = cb:CreateTexture(nil, "ARTWORK")
	icon:SetSize(14, 14)
	icon:SetPoint("RIGHT", cb, "LEFT", -10, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	cb.Icon = icon

	-- shown (by alpha) while the cast cannot be interrupted
	local shield = cb:CreateTexture(nil, "OVERLAY", nil, 2)
	shield:SetTexture(MEDIA .. "shield")
	shield:SetSize(22, 22)
	shield:SetPoint("CENTER", icon, "CENTER", 0, 0)
	shield:SetAlpha(0)
	cb.Shield = shield

	local text = Text(cb, 9)
	text:SetPoint("TOP", cb, "BOTTOM", 0, -3)
	text:SetTextColor(1, 0.9, 0.7)
	cb.Text = text

	-- the interrupt-ready burn reads bar.__owner.unit
	cb.__owner = plate
	if ns.CastBars and ns.CastBars.AddInterruptReady then
		ns.CastBars.AddInterruptReady(cb, { top = 9, side = 14, bottom = 8 })
	end
	plate.CastBar = cb
end

local function CreateDebuffs(plate)
	local row = CreateFrame("Frame", nil, plate)
	row:SetSize(1, 18)
	row:SetPoint("BOTTOM", plate.Name, "TOP", 0, 3)
	row.icons = {}
	for i = 1, MAX_DEBUFFS do
		local b = CreateFrame("Frame", nil, row)
		b:SetSize(18, 18)
		local icon = b:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", 2, -2)
		icon:SetPoint("BOTTOMRIGHT", -2, 2)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.icon = icon
		local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
		cd:SetAllPoints(icon)
		cd:SetDrawEdge(false)
		cd:SetHideCountdownNumbers(true)
		b.cooldown = cd
		local over = CreateFrame("Frame", nil, b)
		over:SetAllPoints(b)
		over:SetFrameLevel(cd:GetFrameLevel() + 1)
		local border = over:CreateTexture(nil, "OVERLAY")
		border:SetTexture(MEDIA .. "icon_border")
		border:SetPoint("TOPLEFT", -2, 2)
		border:SetPoint("BOTTOMRIGHT", 2, -2)
		local count = Text(over, 9)
		count:SetPoint("BOTTOMRIGHT", 2, -1)
		b.count = count
		b:Hide()
		row.icons[i] = b
	end
	plate.Debuffs = row
end

-- Game plate -> Roth plate, kept here: a field written onto the game's
-- pooled plate frame is read back by nothing of Blizzard's, but it is still
-- add-on data on a Blizzard frame.
local plateOf = setmetatable({}, { __mode = "k" })

function NP.PlateFor(base)
	return plateOf[base]
end

-- One Roth plate for one of the game's nameplate base frames.
function NP.Create(base)
	if plateOf[base] then
		return plateOf[base]
	end
	local plate = CreateFrame("Frame", nil, base)
	plate:SetSize(W, H)
	plate:SetPoint("CENTER", base, "CENTER", 0, 0)
	plate:SetScale(Opt("scale", 1))
	plate:EnableMouse(false)
	plate:Hide()
	plate.base = base

	local art = plate:CreateTexture(nil, "BACKGROUND", nil, -8)
	art:SetTexture(MEDIA .. "targettarget")
	art:SetAllPoints(plate)
	plate.Art = art

	-- your target: a gold glow around the iron (as the group frames)
	local glow = plate:CreateTexture(nil, "BACKGROUND", nil, -7)
	glow:SetTexture(MEDIA .. "targettarget_debuffglow")
	glow:SetAllPoints(plate)
	glow:SetVertexColor(1, 0.82, 0.3, 1)
	glow:Hide()
	plate.TargetGlow = glow

	-- the gamepad's soft enemy: a red glow (your hard target keeps the gold one)
	local soft = plate:CreateTexture(nil, "BACKGROUND", nil, -7)
	soft:SetTexture(MEDIA .. "targettarget_debuffglow")
	soft:SetAllPoints(plate)
	soft:SetVertexColor(1, 0.15, 0.05, 0.8)
	soft:Hide()
	plate.SoftGlow = soft

	local h = CreateFrame("StatusBar", nil, plate)
	h:SetPoint("TOP", 0, HEALTH.top)
	h:SetPoint("LEFT", HEALTH.left, 0)
	h:SetPoint("RIGHT", HEALTH.right, 0)
	h:SetPoint("BOTTOM", 0, HEALTH.bottom)
	h:SetStatusBarTexture(MEDIA .. "statusbar3")
	h.bg = h:CreateTexture(nil, "BACKGROUND", nil, -6)
	h.bg:SetTexture(MEDIA .. "statusbar3")
	h.bg:SetAllPoints(h)
	local shade = h:CreateTexture(nil, "OVERLAY", nil, -5)
	shade:SetTexture(MEDIA .. "targettarget_hpglow")
	shade:SetAllPoints(plate)
	shade:SetVertexColor(0, 0, 0, 0.7)
	local shine = h:CreateTexture(nil, "OVERLAY", nil, -4)
	shine:SetTexture(MEDIA .. "targettarget_highlight")
	shine:SetAllPoints(plate)
	plate.Health = h

	local pct = Text(h, 9)
	pct:SetPoint("RIGHT", h, "RIGHT", -2, 0)
	plate.HealthText = pct

	local name = Text(plate, 11)
	name:SetPoint("BOTTOM", plate, "TOP", 0, -16)
	name:SetWidth(W + 30)
	name:SetWordWrap(false)
	plate.Name = name

	-- elite / rare / boss: a Diablo head under the bar
	local head = plate:CreateTexture(nil, "ARTWORK")
	head:SetSize(36, 18)
	head:SetPoint("TOP", h, "BOTTOM", 0, 3)
	head:Hide()
	plate.Head = head

	if Opt("castbar", true) then
		CreateCastBar(plate)
	end
	if Opt("debuffs", true) then
		CreateDebuffs(plate)
	end

	-- the soft-target icon (interact cog, attack sword...), above everything
	local softIcon = plate:CreateTexture(nil, "OVERLAY", nil, 3)
	softIcon:SetSize(24, 24)
	softIcon:SetPoint("BOTTOM", plate.Debuffs or plate.Name, "TOP", 0, 2)
	softIcon:Hide()
	plate.SoftIcon = softIcon

	plateOf[base] = plate
	return plate
end

---------------------------------------------
-- UPDATE
---------------------------------------------

function NP.UpdateHealth(plate)
	local unit = plate.unit
	local h = plate.Health
	-- secret in combat: straight to the bar
	h:SetMinMaxValues(0, UnitHealthMax(unit))
	h:SetValue(UnitHealth(unit))
	if Opt("healthText", true) then
		local v = Secrets.RoundPercent(Secrets.UnitHealthPercent100(unit))
		if type(v) == "nil" then
			plate.HealthText:SetText("")
		else
			plate.HealthText:SetText(Secrets.Wrap(v, "", "%"))
		end
	end
end

-- Health colour by who it is: none of these calls return secrets on Forever.
function NP.UpdateColor(plate)
	local unit = plate.unit
	local r, g, b
	if Secrets.Bool(UnitIsTapDenied, unit) then
		r, g, b = 0.6, 0.6, 0.6
	elseif Secrets.Bool(UnitIsPlayer, unit) and Secrets.Bool(UnitIsFriend, "player", unit) then
		r, g, b = Secrets.UnitClassColor(unit)
	end
	if not r then
		local sr, sg, sb = UnitSelectionColor(unit)
		r, g, b = Secrets.Number(sr), Secrets.Number(sg), Secrets.Number(sb)
	end
	if not (r and g and b) then
		r, g, b = 0.8, 0.1, 0
	end
	plate.Health:SetStatusBarColor(r, g, b)
	plate.Health.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.9)
end

-- Threat on the iron: the threat colour once you are on the threat list;
-- a hidden (secret) status leaves it as it was.
function NP.UpdateThreat(plate)
	if not Opt("threat", true) then
		return
	end
	local status = UnitThreatSituation("player", plate.unit)
	if Secrets.IsSecret(status) then
		return
	end
	if type(status) == "number" and status >= 1 then
		local r, g, b = GetThreatStatusColor(status)
		plate.Art:SetVertexColor(r, g, b)
	else
		plate.Art:SetVertexColor(1, 1, 1)
	end
end

local HEADS = {
	boss = "d3_head_skull",
	rare = "d3_head_garg",
	elite = "d3_head_elite",
}

function NP.UpdateInfo(plate)
	local unit = plate.unit
	local level = Secrets.Number(UnitLevel(unit))
	local name = UnitName(unit)
	if level and level > 0 then
		local difficulty = GetCreatureDifficultyColor or GetQuestDifficultyColor
		local c = difficulty and difficulty(level)
		local hex = "ffd100"
		if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
			hex = ("%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
		end
		plate.Name:SetText(Secrets.Wrap(name, ("|cff%s%d|r "):format(hex, level), ""))
	elseif level == -1 then
		plate.Name:SetText(Secrets.Wrap(name, "|cffff2020??|r ", ""))
	else
		plate.Name:SetText(name or "")
	end
	local class = Secrets.String(UnitClassification(unit))
	local kind
	if class == "worldboss" or level == -1 then
		kind = "boss"
	elseif class == "rare" or class == "rareelite" then
		kind = "rare"
	elseif class == "elite" then
		kind = "elite"
	end
	if kind and Opt("heads", true) then
		plate.Head:SetTexture(MEDIA .. HEADS[kind])
		plate.Head:Show()
	else
		plate.Head:Hide()
	end
	NP.UpdateColor(plate)
end

function NP.UpdateTarget(plate)
	local isTarget = Secrets.UnitIsUnit(plate.unit, "target")
	plate.TargetGlow:SetShown(isTarget)
	plate:SetScale(Opt("scale", 1) * (isTarget and Opt("targetScale", 1.15) or 1))
	plate.Name:SetTextColor(isTarget and 1 or 0.9, isTarget and 0.82 or 0.85, isTarget and 0.4 or 0.75)
end

local function CVarBool(name)
	if C_CVar and C_CVar.GetCVarBool then
		return C_CVar.GetCVarBool(name) and true or false
	end
	return GetCVar and GetCVar(name) == "1"
end

-- The game's soft-target choice, shown the way Blizzard's plate shows it.
function NP.UpdateSoftTarget(plate)
	local unit = plate.unit
	local enemy = Secrets.UnitIsUnit(unit, "softenemy")
	plate.SoftGlow:SetShown(enemy and not Secrets.UnitIsUnit(unit, "target"))
	local size = tonumber(GetCVar and GetCVar("SoftTargetNameplateSize") or "") or 24
	local which
	if enemy and CVarBool("SoftTargetIconEnemy") then
		which = true
	elseif CVarBool("SoftTargetIconFriend") and Secrets.UnitIsUnit(unit, "softfriend") then
		which = true
	elseif CVarBool("SoftTargetIconInteract") and Secrets.UnitIsUnit(unit, "softinteract") then
		which = true
	end
	local shown = false
	if which and size > 0 and SetUnitCursorTexture then
		local ok, has = pcall(SetUnitCursorTexture, plate.SoftIcon, unit, nil, nil, true)
		shown = ok and has and true or false
	end
	plate.SoftIcon:SetSize(size, size)
	plate.SoftIcon:SetShown(shown)
end

---------------------------------------------
-- CAST BAR
---------------------------------------------

local function CastColor(cb, notInterruptible)
	-- gold, or grey when it cannot be interrupted, without testing the (maybe secret) flag
	local curve = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
	if curve and type(notInterruptible) ~= "nil" then
		local ok, r, g, b = pcall(function()
			return curve(notInterruptible, 0.6, 1), curve(notInterruptible, 0.6, 0.7), curve(notInterruptible, 0.6, 0)
		end)
		if ok then
			cb:SetStatusBarColor(r, g, b)
			return
		end
	end
	cb:SetStatusBarColor(1, 0.7, 0)
end

function NP.StopCast(plate)
	local cb = plate.CastBar
	if not cb then
		return
	end
	cb.casting = nil
	cb:Hide()
	if cb.PostCastStop then
		cb.PostCastStop(cb)
	end
end

-- channel: true for a channelled spell. Returns whether a cast is shown.
function NP.StartCast(plate, channel)
	local cb = plate.CastBar
	if not cb then
		return false
	end
	local unit = plate.unit
	local name, texture, notInterruptible, _
	if channel then
		name, _, texture, _, _, _, notInterruptible = UnitChannelInfo(unit)
	else
		name, _, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
	end
	if type(name) == "nil" then
		NP.StopCast(plate)
		return false
	end
	local duration
	if channel then
		duration = UnitChannelDuration and UnitChannelDuration(unit)
	else
		duration = UnitCastingDuration and UnitCastingDuration(unit)
	end
	local interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
	local direction = Enum.StatusBarTimerDirection
	direction = channel and (direction and direction.RemainingTime or 1) or (direction and direction.ElapsedTime or 0)
	local ok = type(duration) ~= "nil" and cb.SetTimerDuration and pcall(cb.SetTimerDuration, cb, duration, interpolation, direction)
	if not ok then
		NP.StopCast(plate)
		return false
	end
	cb.casting = true
	cb.Text:SetText(name)
	cb.Icon:SetTexture(texture)
	if type(notInterruptible) ~= "nil" then
		cb.Shield:SetAlphaFromBoolean(notInterruptible, 1, 0)
	else
		cb.Shield:SetAlpha(0)
	end
	CastColor(cb, notInterruptible)
	cb:Show()
	if channel and cb.PostChannelStart then
		cb.PostChannelStart(cb)
	elseif cb.PostCastStart then
		cb.PostCastStart(cb)
	end
	return true
end

-- A plate that appears mid-cast picks the cast up.
function NP.UpdateCast(plate)
	if not NP.StartCast(plate, false) then
		NP.StartCast(plate, true)
	end
end

---------------------------------------------
-- DEBUFFS (yours)
---------------------------------------------

function NP.UpdateDebuffs(plate)
	local row = plate.Debuffs
	if not row then
		return
	end
	local unit = plate.unit
	local auras = {}
	if C_UnitAuras and C_UnitAuras.GetUnitAuras then
		local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HARMFUL|PLAYER", Opt("maxDebuffs", 4))
		if ok and type(list) == "table" then
			auras = list
		end
	end
	local shown = 0
	for i, b in ipairs(row.icons) do
		local aura = auras[i]
		local id = aura and aura.auraInstanceID
		if id and not Secrets.IsSecret(id) then
			b.icon:SetTexture(aura.icon)
			local durOk, dur = pcall(C_UnitAuras.GetAuraDuration, unit, id)
			if durOk and dur and b.cooldown.SetCooldownFromDurationObject then
				b.cooldown:SetCooldownFromDurationObject(dur)
				if dur.IsZero then
					-- permanent auras: no sweep (the answer may be secret)
					b.cooldown:SetAlphaFromBoolean(dur:IsZero(), 0, 1)
				end
			else
				b.cooldown:Clear()
			end
			local countOk, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, id, 2)
			b.count:SetText(countOk and count or "")
			b:ClearAllPoints()
			b:SetPoint("LEFT", row, "LEFT", shown * 20, 0)
			b:Show()
			shown = shown + 1
		else
			b:Hide()
		end
	end
	row:SetWidth(math.max(1, shown * 20 - 2))
end

---------------------------------------------
-- ATTACH / DETACH
---------------------------------------------

-- Other nameplate add-ons draw their own: Roth steps aside for them.
NP.OTHERS = { "Plater", "Kui_Nameplates", "TidyPlates_ThreatPlates", "TidyPlates", "NeatPlates", "EKplates", "nPlates" }
function NP.Yielding()
	if NP.yieldTo == nil then
		local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
		NP.yieldTo = false
		for _, name in ipairs(NP.OTHERS) do
			if loaded and loaded(name) then
				NP.yieldTo = name
				break
			end
		end
	end
	return NP.yieldTo
end

-- Is this plate one Roth draws? Enemies always; friendly ones by option.
function NP.Wanted(unit)
	if not Opt("enabled", true) or NP.Yielding() then
		return false
	end
	if Opt("friendly", true) then
		return true
	end
	return not Secrets.Bool(UnitIsFriend, "player", unit)
end

-- Blizzard's plate is faded, never hidden: Hide() from add-on code runs the
-- CompactUnitFrame's OnHide in our context, and the pooled frame then
-- carried tainted fields into NamePlateDriverFrame:OnNamePlateAdded and its
-- health updates (blocked actions and "secret value" errors, 2026-10-16).
-- Faded, it keeps running untainted and can be handed back at any time.
--
-- Nothing is hooked on the frame itself: an earlier hooksecurefunc(uf,
-- "Show") left Forever's pooled plate frames with a nil Show, so Blizzard's
-- CompactUnitFrame_UpdateVisible failed with "attempt to call a nil value"
-- on every plate it re-used. Blizzard's global functions that show the
-- frame or set its alpha are post-hooked instead; the hooks only SetAlpha.
local function Refade(frame)
	if frame and hiddenBlizzard[frame] then
		frame:SetAlpha(0)
	end
end
for _, name in ipairs({ "CompactUnitFrame_UpdateVisible", "CompactUnitFrame_UpdateCenterStatusIcon", "CompactUnitFrame_UpdateAll" }) do
	if type(_G[name]) == "function" then
		hooksecurefunc(name, Refade)
	end
end

function NP.HideBlizzard(uf)
	uf:SetAlpha(0)
end

function NP.Attach(unit)
	local base = C_NamePlate.GetNamePlateForUnit(unit)
	if not base then
		return nil
	end
	local uf = base.UnitFrame
	if not NP.Wanted(unit) then
		-- Blizzard's plate for this one: make sure it is back
		if uf then
			hiddenBlizzard[uf] = nil
			uf:SetAlpha(1)
		end
		if plateOf[base] then
			plateOf[base]:Hide()
		end
		return nil
	end
	local plate = NP.Create(base)
	plate.unit = unit
	NP.plates[unit] = plate
	if uf then
		hiddenBlizzard[uf] = true
		NP.HideBlizzard(uf)
	end
	NP.UpdateInfo(plate)
	NP.UpdateHealth(plate)
	NP.UpdateThreat(plate)
	NP.UpdateTarget(plate)
	NP.UpdateSoftTarget(plate)
	NP.UpdateDebuffs(plate)
	NP.UpdateCast(plate)
	plate:Show()
	return plate
end

function NP.Detach(unit)
	local plate = NP.plates[unit]
	NP.plates[unit] = nil
	if plate then
		NP.StopCast(plate)
		plate:Hide()
		plate.unit = nil
		local uf = plate.base and plate.base.UnitFrame
		if uf then
			hiddenBlizzard[uf] = nil
		end
	end
end

---------------------------------------------
-- EVENTS
---------------------------------------------

local CAST_START = { UNIT_SPELLCAST_START = false, UNIT_SPELLCAST_DELAYED = false, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true }
local CAST_STOP = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true }
local CAST_FLAG = { UNIT_SPELLCAST_INTERRUPTIBLE = true, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true }

function NP.UpdateAllSoft()
	for _, plate in pairs(NP.plates) do
		NP.UpdateSoftTarget(plate)
	end
end

local handlers = {
	NAME_PLATE_CREATED = function(base)
		NP.Create(base)
	end,
	NAME_PLATE_UNIT_ADDED = function(unit)
		NP.Attach(unit)
	end,
	NAME_PLATE_UNIT_REMOVED = function(unit)
		NP.Detach(unit)
	end,
	PLAYER_TARGET_CHANGED = function()
		for _, plate in pairs(NP.plates) do
			NP.UpdateTarget(plate)
			NP.UpdateSoftTarget(plate)
		end
	end,
	PLAYER_SOFT_ENEMY_CHANGED = function()
		NP.UpdateAllSoft()
	end,
	PLAYER_SOFT_FRIEND_CHANGED = function()
		NP.UpdateAllSoft()
	end,
	PLAYER_SOFT_INTERACT_CHANGED = function()
		NP.UpdateAllSoft()
	end,
	UNIT_THREAT_SITUATION_UPDATE = function()
		for _, plate in pairs(NP.plates) do
			NP.UpdateThreat(plate)
		end
	end,
}

local unitHandlers = {
	UNIT_HEALTH = NP.UpdateHealth,
	UNIT_MAXHEALTH = NP.UpdateHealth,
	UNIT_THREAT_LIST_UPDATE = NP.UpdateThreat,
	UNIT_AURA = NP.UpdateDebuffs,
	UNIT_NAME_UPDATE = NP.UpdateInfo,
	UNIT_LEVEL = NP.UpdateInfo,
	UNIT_FACTION = NP.UpdateInfo,
	UNIT_CLASSIFICATION_CHANGED = NP.UpdateInfo,
}

function NP.OnEvent(event, ...)
	local handler = handlers[event]
	if handler then
		handler(...)
		return
	end
	local unit = ...
	if type(unit) ~= "string" or Secrets.IsSecret(unit) then
		return
	end
	local plate = NP.plates[unit]
	if not plate then
		return
	end
	if unitHandlers[event] then
		unitHandlers[event](plate)
	elseif CAST_START[event] ~= nil then
		NP.StartCast(plate, CAST_START[event])
	elseif CAST_STOP[event] then
		NP.StopCast(plate)
	elseif CAST_FLAG[event] and plate.CastBar and plate.CastBar.casting then
		NP.UpdateCast(plate)
	end
end

-- Re-applies to the plates on screen (the setting changed).
function NP.Refresh()
	for unit in pairs(NP.plates) do
		NP.Detach(unit)
	end
	for _, base in ipairs((C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()) or {}) do
		local unit = base.GetUnit and base:GetUnit()
		if type(unit) == "string" then
			NP.Attach(unit)
		end
	end
end

-- Events are always registered: the on / off setting is read per plate, so
-- it can change in the game (the saved choice loads after this file).
if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
	local events = CreateFrame("Frame")
	for event in pairs(handlers) do
		events:RegisterEvent(event)
	end
	for event in pairs(unitHandlers) do
		events:RegisterEvent(event)
	end
	for _, list in ipairs({ CAST_START, CAST_STOP, CAST_FLAG }) do
		for event in pairs(list) do
			events:RegisterEvent(event)
		end
	end
	events:SetScript("OnEvent", function(_, event, ...)
		NP.OnEvent(event, ...)
	end)
	NP.events = events

	if ns.Pad and ns.Pad.RegisterOptionCallback then
		local last = Opt("enabled", true)
		ns.Pad:RegisterOptionCallback(function()
			local now = Opt("enabled", true)
			if now ~= last then
				last = now
				NP.Refresh()
			end
		end)
	end
	if ns.Pad and ns.Pad.AddReportLine then
		ns.Pad:AddReportLine(function()
			local n = 0
			for _ in pairs(NP.plates) do
				n = n + 1
			end
			local other = NP.Yielding()
			return ("nameplates: %s, %d on screen"):format(other and ("off (" .. other .. " draws them)") or (Opt("enabled", true) and "Roth" or "Blizzard"), n)
		end)
	end
end
