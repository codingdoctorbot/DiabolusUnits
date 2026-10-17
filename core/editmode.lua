-----------------------------------------
-- DiabolusUnits - Edit Layout (Mouse)
-----------------------------------------
-- Integrated Edit Mode for all DiabolusUnits frames:
--   * Each unit frame, orb, statue, bar, and swing timer shows a green
--     outline box and drags directly with LeftButton.
--   * Clicking ANY element opens its dedicated settings popup dialog
--     (Roth_UISettingsDialog) right beside it.
--   * Dialog features:
--       - Element name header with [X] close button (movable by title).
--       - Visible / Enabled checkbox to turn elements on / off live.
--       - Size (scale) slider with [-] [+] nudge buttons (50% to 200%).
--       - Horizontal (X) & Vertical (Y) offset sliders with [-] [+] buttons.
--       - Context-specific Spacing / Size slider:
--           * Orbs: orb spacing / gap (moves orbs apart / together).
--           * Angel / Demon: horizontal spacing and offset from orbs.
--           * Bottom Bar: vertical Y spacing / position.
--           * XP / Rep Bar: vertical Y spacing / position.
--           * Stone Bar: width / scale.
--           * Target / ToT / Focus: Aura Icon Size (12px to 40px).
--       - [ Reset to Default ] button to revert scale, spacing & position.
--   * Top toolbar (DoneBar) provides frame cycling (< / >), element dropdown,
--     global UI Size slider, [ Reset UI ], and [ Done ].
--   * Mouse Wheel over any frame changes its size live (+/- 5%).
--   * Shift + Mouse Wheel over any frame adjusts spacing / aura size live.
--   * All scales, spacings, positions, and disabled states persist in Roth_UI_DB.
--   * Combat ends editing immediately (unit frames are protected).

local _, ns = ...

local EditMode = {}
ns.EditMode = EditMode

EditMode.active = false

local GROUPS = { "units", "bars", "art", "orbs" }

local EDITABLE_FRAMES = {
	{ id = "Roth_UIPlayerFrame", name = "Health Orb", type = "orb", orbType = "health" },
	{ id = "Roth_UIPowerOrb", name = "Power Orb", type = "orb", orbType = "power" },
	{ id = "Roth_UIAngelFrame", name = "Angel Statue", type = "angel" },
	{ id = "Roth_UIDemonFrame", name = "Demon Statue", type = "demon" },
	{ id = "Roth_UIBottomLine", name = "Bottom Stone Line", type = "bottomline" },
	{ id = "Roth_UIActionBarBackground", name = "Background Bar (Stone Bar)", type = "stonebar" },
	{ id = "Roth_UIExpBar", name = "Experience Bar", type = "xpbar" },
	{ id = "Roth_UIRepBar", name = "Reputation Bar", type = "repbar" },
	{ id = "Roth_UITargetFrame", name = "Target Frame", type = "unit", aura = "target" },
	{ id = "Roth_UITargetTargetFrame", name = "Target of Target", type = "unit", aura = "targettarget" },
	{ id = "Roth_UIFocusFrame", name = "Focus Frame", type = "unit", aura = "focus" },
	{ id = "Roth_UIFocusTargetFrame", name = "Focus Target", type = "unit" },
	{ id = "Roth_UIPetFrame", name = "Pet Frame", type = "unit" },
	{ id = "Roth_UIPetTargetFrame", name = "Pet Target", type = "unit" },
	{ id = "Roth_UIPartyDragFrame", name = "Party Frames", type = "unit", headerScale = "partyScale" },
	{ id = "Roth_UIRaidDragFrame", name = "Raid Frames", type = "unit", headerScale = "raidScale" },
	{ id = "Roth_UIBossFrame1", name = "Boss Frames", type = "unit" },
	{ id = "Roth_UIPlayerFrameCastBarDragFrame", name = "Player Cast Bar", type = "castbar" },
	{ id = "Roth_UITargetFrameCastBarDragFrame", name = "Target Cast Bar", type = "castbar" },
	{ id = "Roth_UIFocusFrameCastBarDragFrame", name = "Focus Cast Bar", type = "castbar" },
	{ id = "Roth_UISwingTimer", name = "Swing Timer", type = "swing" },
	{ id = "Roth_UIPlayerPortrait", name = "Player Portrait", type = "art" },
	{ id = "Roth_UITargetPortrait", name = "Target Portrait", type = "art" },
}

local selectedIdx = 1

EditMode.FRAMES = EDITABLE_FRAMES

function EditMode:EntryFor(id)
	for _, entry in ipairs(EDITABLE_FRAMES) do
		if entry.id == id then
			return entry
		end
	end
end

local HEADER_DEFAULT = { partyScale = 1.1, raidScale = 0.8 }

local function Say(msg)
	print("|c00FF3300DiabolusUnits:|r " .. msg)
end

-- Database helpers
function ns.LayoutProfile()
	local adb = ns.configDB
	if adb and adb.profile then
		return adb.profile
	end
	local raw = rawget(_G, "Roth_UI_DB")
	if type(raw) == "table" then
		raw.profile = raw.profile or {}
		return raw.profile
	end
	return nil
end

local function GetDB()
	return ns.LayoutProfile()
end

-- Apply party / raid header scales directly
function EditMode:ApplyHeaderScales()
	if InCombatLockdown() then
		return
	end
	local db = GetDB()
	local global = self:GetGlobalScale()
	local partyScale = (db and db.frameScales and db.frameScales["Roth_UIPartyDragFrame"])
		or (ns.cfg and ns.cfg.units and ns.cfg.units.party and ns.cfg.units.party.scale)
		or HEADER_DEFAULT.partyScale
	local raidScale = (db and db.frameScales and db.frameScales["Roth_UIRaidDragFrame"])
		or (ns.cfg and ns.cfg.units and ns.cfg.units.raid and ns.cfg.units.raid.scale)
		or HEADER_DEFAULT.raidScale

	if ns.partyHeader and ns.partyHeader.SetScale then
		ns.partyHeader:SetScale(partyScale * global)
	end
	for _, header in ipairs(ns.raidHeaders or {}) do
		if header.SetScale then
			header:SetScale(raidScale * global)
		end
	end
end

-- Live Scale (Size)
function EditMode:GetGlobalScale()
	local db = GetDB()
	local s = db and db.globalScale
	if type(s) == "number" and s >= 0.50 and s <= 2.00 then
		return math.floor(s * 100 + 0.5) / 100
	end
	return 1.0
end

function EditMode:ApplyGlobalScale(scale)
	scale = scale or self:GetGlobalScale()
	local db = GetDB()
	for _, entry in ipairs(EDITABLE_FRAMES) do
		local f = rawget(_G, entry.id)
		if f and f.SetScale and not InCombatLockdown() and not entry.headerScale then
			local indScale = (db and db.frameScales and db.frameScales[entry.id]) or 1.0
			f:SetScale(indScale * scale)
		end
	end
	self:ApplyHeaderScales()
end

function EditMode:SetGlobalScale(scale)
	if InCombatLockdown() then
		return
	end
	scale = math.max(0.50, math.min(1.50, math.floor(scale * 100 + 0.5) / 100))
	local db = GetDB()
	if db then
		db.globalScale = scale
	end
	self:ApplyGlobalScale(scale)
	if self.UpdateTopBar then
		self:UpdateTopBar()
	end
end

function EditMode:NudgeGlobalScale(delta)
	local cur = self:GetGlobalScale()
	self:SetGlobalScale(cur + delta)
end

function EditMode:GetScale(frame)
	if not frame then
		return 1.0
	end
	local name = frame.GetName and frame:GetName()
	local db = GetDB()
	if name and db and db.frameScales and db.frameScales[name] then
		return db.frameScales[name]
	end
	local entry = name and self:EntryFor(name)
	if entry and entry.headerScale then
		return HEADER_DEFAULT[entry.headerScale] or 1.0
	end
	return 1.0
end

function EditMode:SetScale(frame, scale)
	if InCombatLockdown() or not frame or not frame.SetScale then
		return
	end
	scale = math.max(0.50, math.min(2.00, math.floor(scale * 100 + 0.5) / 100))
	local name = frame.GetName and frame:GetName()
	if name then
		local db = GetDB()
		if db then
			db.frameScales = db.frameScales or {}
			db.frameScales[name] = scale
		end
	end

	local entry = name and self:EntryFor(name)
	if entry and entry.headerScale then
		if entry.headerScale == "partyScale" and ns.cfg and ns.cfg.units and ns.cfg.units.party then
			ns.cfg.units.party.scale = scale
		elseif entry.headerScale == "raidScale" and ns.cfg and ns.cfg.units and ns.cfg.units.raid then
			ns.cfg.units.raid.scale = scale
		end
		self:ApplyHeaderScales()
		if EditMode.UpdateDialog then
			EditMode:UpdateDialog()
		end
		return
	end

	local globalScale = self:GetGlobalScale()
	frame:SetScale(scale * globalScale)

	-- If scaling BossFrame1, scale BossFrame2..5 to match
	if name == "Roth_UIBossFrame1" then
		for i = 2, (rawget(_G, "MAX_BOSS_FRAMES") or 5) do
			local bf = rawget(_G, "Roth_UIBossFrame" .. i)
			if bf and bf.SetScale then
				bf:SetScale(scale * globalScale)
			end
		end
	end

	if EditMode.UpdateDialog then
		EditMode:UpdateDialog()
	end
end

function EditMode:NudgeScale(frame, delta)
	local cur = self:GetScale(frame)
	self:SetScale(frame, cur + delta)
end

-- Live Position Saving
function EditMode:SaveFramePosition(frame)
	if not frame or not frame.GetName then
		return
	end
	local name = frame:GetName()
	local db = GetDB()
	if not db then
		return
	end
	db.framePositions = db.framePositions or {}
	local pt, relTo, relPt, x, y = frame:GetPoint(1)
	if pt then
		local relName = (relTo and relTo.GetName and relTo:GetName()) or "UIParent"
		db.framePositions[name] = {
			point = pt,
			relativeTo = relName,
			relativePoint = relPt or pt,
			x = math.floor((x or 0) + 0.5),
			y = math.floor((y or 0) + 0.5),
		}
	end
end

-- Live Frame Position (X / Y Offset)
function EditMode:GetFramePosition(frame)
	if not frame or not frame.GetPoint then
		return 0, 0, "BOTTOM", UIParent, "BOTTOM"
	end
	local pt, relTo, relPt, x, y = frame:GetPoint(1)
	return math.floor((x or 0) + 0.5),
		math.floor((y or 0) + 0.5),
		pt or "BOTTOM",
		relTo or UIParent,
		relPt or (pt or "BOTTOM")
end

function EditMode:SetFrameOffset(frame, newX, newY)
	if InCombatLockdown() or not frame or not frame.SetPoint then
		return
	end
	local curX, curY, pt, relTo, relPt = self:GetFramePosition(frame)
	local targetX = newX ~= nil and math.floor(newX + 0.5) or curX
	local targetY = newY ~= nil and math.floor(newY + 0.5) or curY
	frame:ClearAllPoints()
	frame:SetPoint(pt, relTo, relPt, targetX, targetY)
	self:SaveFramePosition(frame)
end

function EditMode:NudgeFrameOffset(frame, deltaX, deltaY)
	local curX, curY = self:GetFramePosition(frame)
	self:SetFrameOffset(frame, curX + (deltaX or 0), curY + (deltaY or 0))
	if self.UpdateDialog then
		self:UpdateDialog()
	end
end

-- Live Visibility (Enable / Disable)
function EditMode:IsElementEnabled(entry)
	if not entry then
		return true
	end
	local db = GetDB()
	if db and db.disabledElements and db.disabledElements[entry.id] ~= nil then
		return not db.disabledElements[entry.id]
	end
	if entry.type == "stonebar" and ns.cfg and ns.cfg.units and ns.cfg.units.player and ns.cfg.units.player.art then
		return ns.cfg.units.player.art.actionbarbackground.show and true or false
	end
	local f = rawget(_G, entry.id)
	if f and f.IsShown then
		return f:IsShown()
	end
	return true
end

function EditMode:SetElementEnabled(entry, enabled)
	if InCombatLockdown() or not entry then
		return
	end
	local f = rawget(_G, entry.id)
	if f then
		f:SetShown(enabled)
		if f.dragframe then
			if EditMode.active then
				f.dragframe:SetShown(enabled)
			else
				f.dragframe:Hide()
			end
		end
	end

	-- Update underlying config
	if entry.type == "angel" and ns.cfg and ns.cfg.units and ns.cfg.units.player and ns.cfg.units.player.art then
		ns.cfg.units.player.art.angel.show = enabled
	elseif entry.type == "demon" and ns.cfg and ns.cfg.units and ns.cfg.units.player and ns.cfg.units.player.art then
		ns.cfg.units.player.art.demon.show = enabled
	elseif
		entry.type == "bottomline"
		and ns.cfg
		and ns.cfg.units
		and ns.cfg.units.player
		and ns.cfg.units.player.art
	then
		ns.cfg.units.player.art.bottomline.show = enabled
	elseif entry.type == "xpbar" and ns.cfg and ns.cfg.units and ns.cfg.units.player then
		ns.cfg.units.player.expbar.show = enabled
	elseif entry.type == "repbar" and ns.cfg and ns.cfg.units and ns.cfg.units.player then
		ns.cfg.units.player.repbar.show = enabled
	elseif entry.type == "stonebar" and ns.cfg and ns.cfg.units and ns.cfg.units.player and ns.cfg.units.player.art then
		ns.cfg.units.player.art.actionbarbackground.show = enabled
		local bg = rawget(_G, "Roth_UIActionBarBackground")
		if bg then
			bg:SetShown(enabled)
			if bg.texture then
				bg.texture:SetShown(enabled)
			end
			if ns.PlayerArt and ns.PlayerArt.refresh then
				ns.PlayerArt.refresh()
			end
		end
	elseif entry.type == "swing" and ns.cfg and ns.cfg.swingTimer then
		ns.cfg.swingTimer.enabled = enabled
	end

	local db = GetDB()
	if db then
		db.disabledElements = db.disabledElements or {}
		db.disabledElements[entry.id] = not enabled
	end

	if EditMode.UpdateDialog then
		EditMode:UpdateDialog()
	end
end

-- Live Spacing (Context-specific)
function EditMode:GetSpacingInfo(entry)
	if not entry then
		return nil
	end

	if entry.aura and ns.AuraSize then
		return {
			label = "Aura Icon Size:",
			unit = "px",
			min = 12,
			max = 40,
			step = 1,
			value = ns.AuraSize.Get(entry.aura),
			apply = function(v)
				ns.AuraSize.Set(entry.aura, v)
			end,
		}
	end

	if entry.type == "orb" then
		local p = ns.cfg and ns.cfg.units and ns.cfg.units.player
		local val = p and p.pos and math.abs(p.pos.x) or 325
		local hOrb = rawget(_G, "Roth_UIPlayerFrame")
		if hOrb and hOrb.GetPoint then
			local _, _, _, x = hOrb:GetPoint(1)
			if x then
				val = math.floor(math.abs(x) + 0.5)
			end
		end
		return {
			label = "Orb Spacing:",
			unit = "px",
			min = 120,
			max = 550,
			step = 5,
			value = val,
			apply = function(v)
				local h = rawget(_G, "Roth_UIPlayerFrame")
				local pOrb = rawget(_G, "Roth_UIPowerOrb")
				if h and pOrb and not InCombatLockdown() then
					local _, _, _, _, y = h:GetPoint(1)
					y = y or (p and p.pos and p.pos.y) or 10
					h:ClearAllPoints()
					h:SetPoint("BOTTOM", UIParent, "BOTTOM", -v, y)
					pOrb:ClearAllPoints()
					pOrb:SetPoint("BOTTOM", UIParent, "BOTTOM", v, y)
					self:SaveFramePosition(h)
					self:SaveFramePosition(pOrb)
					local db = GetDB()
					if db then
						db.orbSpacing = v
					end
				end
			end,
		}
	elseif entry.type == "angel" then
		local p = ns.cfg
			and ns.cfg.units
			and ns.cfg.units.player
			and ns.cfg.units.player.art
			and ns.cfg.units.player.art.angel
		local val = p and p.pos and p.pos.x or 330
		return {
			label = "Angel Spacing (X):",
			unit = "px",
			min = 120,
			max = 500,
			step = 5,
			value = val,
			apply = function(v)
				local f = rawget(_G, "Roth_UIAngelFrame")
				if f and not InCombatLockdown() then
					if ns.cfg.units.player.art.angel.pos then
						ns.cfg.units.player.art.angel.pos.x = v
					end
					local _, _, _, _, y = f:GetPoint(1)
					f:ClearAllPoints()
					f:SetPoint("BOTTOM", UIParent, "BOTTOM", v, y or 6)
					self:SaveFramePosition(f)
					local db = GetDB()
					if db then
						db.angelX = v
					end
				end
			end,
		}
	elseif entry.type == "demon" then
		local p = ns.cfg
			and ns.cfg.units
			and ns.cfg.units.player
			and ns.cfg.units.player.art
			and ns.cfg.units.player.art.demon
		local val = p and p.pos and p.pos.x or -335
		return {
			label = "Demon Spacing (X):",
			unit = "px",
			min = -500,
			max = -120,
			step = 5,
			value = val,
			apply = function(v)
				local f = rawget(_G, "Roth_UIDemonFrame")
				if f and not InCombatLockdown() then
					if ns.cfg.units.player.art.demon.pos then
						ns.cfg.units.player.art.demon.pos.x = v
					end
					local _, _, _, _, y = f:GetPoint(1)
					f:ClearAllPoints()
					f:SetPoint("BOTTOM", UIParent, "BOTTOM", v, y or 6)
					self:SaveFramePosition(f)
					local db = GetDB()
					if db then
						db.demonX = v
					end
				end
			end,
		}
	elseif entry.type == "bottomline" then
		local p = ns.cfg
			and ns.cfg.units
			and ns.cfg.units.player
			and ns.cfg.units.player.art
			and ns.cfg.units.player.art.bottomline
		local val = p and p.pos and p.pos.y or 2
		return {
			label = "Vertical Spacing (Y):",
			unit = "px",
			min = -40,
			max = 40,
			step = 1,
			value = val,
			apply = function(v)
				local f = rawget(_G, "Roth_UIBottomLine")
				if f and not InCombatLockdown() then
					if ns.cfg.units.player.art.bottomline.pos then
						ns.cfg.units.player.art.bottomline.pos.y = v
					end
					local _, _, _, x = f:GetPoint(1)
					f:ClearAllPoints()
					f:SetPoint("BOTTOM", UIParent, "BOTTOM", x or 0, v)
					self:SaveFramePosition(f)
					local db = GetDB()
					if db then
						db.bottomLineY = v
					end
				end
			end,
		}
	elseif entry.type == "xpbar" or entry.type == "repbar" then
		local f = rawget(_G, entry.id)
		local val = (entry.type == "xpbar") and 14 or 6
		if f and f.GetPoint then
			local _, _, _, _, y = f:GetPoint(1)
			val = math.floor((y or val) + 0.5)
		end
		return {
			label = "Vertical Spacing (Y):",
			unit = "px",
			min = -20,
			max = 120,
			step = 1,
			value = val,
			apply = function(v)
				if f and not InCombatLockdown() then
					local pt, relTo, relPt, x = f:GetPoint(1)
					f:ClearAllPoints()
					f:SetPoint(pt or "BOTTOM", relTo or UIParent, relPt or "BOTTOM", x or 0, v)
					EditMode:SaveFramePosition(f)
				end
			end,
		}
	elseif entry.type == "stonebar" then
		local bg = rawget(_G, "Roth_UIActionBarBackground")
		local val = bg and math.floor(bg:GetWidth() + 0.5) or 788
		return {
			label = "Bar Width:",
			unit = "px",
			min = 394,
			max = 1576,
			step = 10,
			value = val,
			apply = function(v)
				if bg and not InCombatLockdown() then
					local h = math.floor(v * 220 / 788 + 0.5)
					bg:SetSize(v, h)
					local db = GetDB()
					if db then
						db.barWidth = v
						db.barHeight = h
					end
				end
			end,
		}
	end

	return nil
end

function EditMode:NudgeSpacing(delta)
	local entry = EDITABLE_FRAMES[selectedIdx]
	local info = self:GetSpacingInfo(entry)
	if info and info.apply then
		local newVal = info.value + delta * info.step
		newVal = math.max(info.min, math.min(info.max, newVal))
		info.apply(newVal)
		if self.UpdateDialog then
			self:UpdateDialog()
		end
	end
end

-- Selection glow
local selectionGlow
local function ShowSelectionGlow(target)
	if not selectionGlow then
		selectionGlow = CreateFrame("Frame", "Roth_UIEditSelectionGlow", UIParent, "BackdropTemplate")
		selectionGlow:SetFrameStrata("HIGH")
		selectionGlow:SetFrameLevel(100)
		selectionGlow:SetBackdrop({
			edgeFile = "Interface\\Buttons\\UI-Common-MouseHilight",
			edgeSize = 14,
		})
		selectionGlow:SetBackdropBorderColor(1, 0.85, 0.2, 0.9)
	end
	if target and target.IsShown and target:IsShown() then
		selectionGlow:SetParent(target)
		selectionGlow:ClearAllPoints()
		selectionGlow:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
		selectionGlow:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
		selectionGlow:Show()
	else
		selectionGlow:Hide()
	end
end

-- Reset element to defaults
function EditMode:ResetSelected()
	if InCombatLockdown() then
		Say("frames cannot be reset in combat.")
		return
	end
	local entry = EDITABLE_FRAMES[selectedIdx]
	if not entry then
		return
	end
	local f = rawget(_G, entry.id)
	if f then
		self:SetScale(f, entry.headerScale and HEADER_DEFAULT[entry.headerScale] or 1.0)
		self:SetElementEnabled(entry, entry.type ~= "stonebar")

		local db = GetDB()
		if db and db.framePositions then
			db.framePositions[entry.id] = nil
		end

		if f.defaultPosition then
			f:ClearAllPoints()
			local pos = f.defaultPosition
			local relTo = (type(pos.af) == "string" and rawget(_G, pos.af)) or pos.af or UIParent
			if pos.af and pos.a2 then
				f:SetPoint(pos.a1 or "CENTER", relTo, pos.a2, pos.x or 0, pos.y or 0)
			elseif pos.af then
				f:SetPoint(pos.a1 or "CENTER", relTo, pos.x or 0, pos.y or 0)
			else
				f:SetPoint(pos.a1 or "CENTER", pos.x or 0, pos.y or 0)
			end
		end

		if entry.type == "stonebar" then
			f:SetSize(788, 220)
		elseif entry.type == "xpbar" or entry.type == "repbar" then
			if ns.bars and ns.bars.UpdateStatusBarLayout then
				ns.bars.UpdateStatusBarLayout()
			end
		end
	end
	Say(entry.name .. " reset to default.")
	if self.UpdateDialog then
		self:UpdateDialog()
	end
end

-- Reset ALL elements to default layout
function EditMode:ResetAllToDefault()
	if InCombatLockdown() then
		Say("frames cannot be reset in combat.")
		return
	end

	-- 1. Standard Roth_UIReset
	local resetFunc = rawget(_G, "Roth_UIReset")
	if resetFunc then
		resetFunc("all")
	end

	-- 2. Clear saved DB override keys first so layout functions read clean state
	local db = GetDB()
	if db then
		db.framePositions = nil
		db.frameScales = nil
		db.globalScale = 1.0
		db.disabledElements = nil
		db.angelX = nil
		db.demonX = nil
		db.bottomLineY = nil
		db.xpbarY = nil
		db.repbarY = nil
		db.orbSpacing = nil
		db.barWidth = nil
		db.barHeight = nil
	end

	-- 3. Reset scales, positions, and enabled state for all editable frames
	for _, entry in ipairs(EDITABLE_FRAMES) do
		local f = rawget(_G, entry.id)
		if f then
			self:SetScale(f, entry.headerScale and HEADER_DEFAULT[entry.headerScale] or 1.0)
			if f.defaultPosition then
				f:ClearAllPoints()
				local pos = f.defaultPosition
				local relTo = (type(pos.af) == "string" and rawget(_G, pos.af)) or pos.af or UIParent
				f:SetPoint(pos.a1 or "CENTER", relTo, pos.a2 or pos.a1 or "CENTER", pos.x or 0, pos.y or 0)
			end
		end
		if entry.type == "stonebar" then
			self:SetElementEnabled(entry, false)
		else
			self:SetElementEnabled(entry, true)
		end
	end

	-- 4. Reset stone bar size
	local bg = rawget(_G, "Roth_UIActionBarBackground")
	if bg then
		bg:SetSize(788, 220)
	end

	-- 5. Reset Orbs, Statues, and Bottom Line
	local p = ns.cfg and ns.cfg.units and ns.cfg.units.player
	if p and p.art then
		if p.art.angel and p.art.angel.pos then
			p.art.angel.pos.x = 330
			p.art.angel.pos.y = 6
		end
		if p.art.demon and p.art.demon.pos then
			p.art.demon.pos.x = -335
			p.art.demon.pos.y = 6
		end
		if p.art.bottomline and p.art.bottomline.pos then
			p.art.bottomline.pos.y = 2
		end
		if p.art.actionbarbackground then
			p.art.actionbarbackground.show = false
		end
	end
	local angel = rawget(_G, "Roth_UIAngelFrame")
	if angel then
		angel:ClearAllPoints()
		angel:SetPoint("BOTTOM", UIParent, "BOTTOM", 330, 6)
	end
	local demon = rawget(_G, "Roth_UIDemonFrame")
	if demon then
		demon:ClearAllPoints()
		demon:SetPoint("BOTTOM", UIParent, "BOTTOM", -335, 6)
	end
	local bLine = rawget(_G, "Roth_UIBottomLine")
	if bLine then
		bLine:ClearAllPoints()
		bLine:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 2)
	end
	local hOrb = rawget(_G, "Roth_UIPlayerFrame")
	if hOrb then
		hOrb:ClearAllPoints()
		hOrb:SetPoint("BOTTOM", UIParent, "BOTTOM", -325, 10)
	end
	local pOrb = rawget(_G, "Roth_UIPowerOrb")
	if pOrb then
		pOrb:ClearAllPoints()
		pOrb:SetPoint("BOTTOM", UIParent, "BOTTOM", 325, 10)
	end

	-- 6. Reset Exp & Rep bars to between orbs
	if ns.bars and ns.bars.UpdateStatusBarLayout then
		ns.bars.UpdateStatusBarLayout()
	end

	-- 7. Re-apply global scale and pixel-perfect scale
	self:ApplyGlobalScale(1.0)
	if ns.func and ns.func.ApplyPixelPerfectScale then
		ns.func.ApplyPixelPerfectScale()
	end
	if ns.PlayerArt and ns.PlayerArt.refresh then
		ns.PlayerArt.refresh()
	end

	Say("All UI elements reset to default layout.")
	if self.UpdateDialog then
		self:UpdateDialog()
	end
	if self.UpdateTopBar then
		self:UpdateTopBar()
	end
end

------------------------------------------------------------------------
-- THE PER-FRAME SETTINGS DIALOG (like normal Edit Mode)
------------------------------------------------------------------------
local function SetSliderLabel(slider, childKey, text)
	if not slider then
		return
	end
	local child = rawget(slider, childKey)
	if not child and slider.GetName then
		child = rawget(_G, slider:GetName() .. childKey)
	end
	if type(child) == "table" and child.SetText then
		child:SetText(text)
	end
end

local settingsDialog
local function CreateSettingsDialog()
	if settingsDialog then
		return settingsDialog
	end

	local d = CreateFrame("Frame", "Roth_UISettingsDialog", UIParent, "BackdropTemplate")
	d:SetSize(340, 205)
	d:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
	d:SetFrameStrata("DIALOG")
	d:SetClampedToScreen(true)
	d:SetMovable(true)
	d:EnableMouse(true)
	d:RegisterForDrag("LeftButton")
	d:SetScript("OnDragStart", d.StartMoving)
	d:SetScript("OnDragStop", function(s)
		s:StopMovingOrSizing()
		s.userMoved = true
	end)

	d:SetBackdrop({
		bgFile = "Interface\\AddOns\\DiabolusUnits\\media\\Tooltip_Background",
		edgeFile = "Interface\\AddOns\\DiabolusUnits\\media\\Tooltip_Border",
		edgeSize = 14,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	d:SetBackdropColor(0.2, 0.2, 0.2, 0.95)

	-- Header / Title
	local title = d:CreateFontString(nil, "OVERLAY")
	title:SetFont(ns.cfg.headerFont or ns.cfg.font, 14, "THINOUTLINE")
	title:SetPoint("TOPLEFT", 14, -10)
	title:SetTextColor(1, 0.82, 0.4)
	d.title = title

	local close = CreateFrame("Button", nil, d, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function()
		d:Hide()
		ShowSelectionGlow(nil)
	end)

	-- Row 1: Visibility Checkbox (Enable / Disable)
	local enableCheck = CreateFrame("CheckButton", "Roth_UIEditEnableCheck", d, "UICheckButtonTemplate")
	enableCheck:SetPoint("TOPLEFT", 12, -32)
	enableCheck:SetSize(24, 24)
	local checkText = enableCheck:CreateFontString(nil, "OVERLAY")
	checkText:SetFont(ns.cfg.font, 12, "THINOUTLINE")
	checkText:SetPoint("LEFT", enableCheck, "RIGHT", 4, 0)
	checkText:SetTextColor(1, 1, 1)
	checkText:SetText("Visible / Enabled")
	enableCheck:SetScript("OnClick", function(s)
		local entry = EDITABLE_FRAMES[selectedIdx]
		if entry then
			EditMode:SetElementEnabled(entry, s:GetChecked())
		end
	end)
	d.enableCheck = enableCheck

	-- Row 2: Size (Scale) Slider
	local sizeText = d:CreateFontString(nil, "OVERLAY")
	sizeText:SetFont(ns.cfg.font, 11, "THINOUTLINE")
	sizeText:SetPoint("TOPLEFT", 14, -58)
	sizeText:SetTextColor(1, 0.82, 0)
	d.sizeText = sizeText

	local sizeMinus = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	sizeMinus:SetSize(20, 20)
	sizeMinus:SetPoint("TOPLEFT", 14, -74)
	sizeMinus:SetText("-")
	sizeMinus:SetScript("OnClick", function()
		local entry = EDITABLE_FRAMES[selectedIdx]
		local f = entry and rawget(_G, entry.id)
		if f then
			EditMode:NudgeScale(f, -0.05)
		end
	end)

	local sizeSlider = CreateFrame("Slider", "Roth_UISizeSlider", d, "OptionsSliderTemplate")
	sizeSlider:SetPoint("LEFT", sizeMinus, "RIGHT", 6, 0)
	sizeSlider:SetWidth(180)
	sizeSlider:SetHeight(16)
	sizeSlider:SetMinMaxValues(0.50, 2.00)
	sizeSlider:SetValueStep(0.05)
	SetSliderLabel(sizeSlider, "Low", "50%")
	SetSliderLabel(sizeSlider, "High", "200%")
	SetSliderLabel(sizeSlider, "Text", "")
	sizeSlider:SetScript("OnValueChanged", function(s, value)
		if s.settingValue then
			return
		end
		local entry = EDITABLE_FRAMES[selectedIdx]
		local f = entry and rawget(_G, entry.id)
		if f then
			EditMode:SetScale(f, value)
		end
	end)
	d.sizeSlider = sizeSlider

	local sizePlus = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	sizePlus:SetSize(20, 20)
	sizePlus:SetPoint("LEFT", sizeSlider, "RIGHT", 6, 0)
	sizePlus:SetText("+")
	sizePlus:SetScript("OnClick", function()
		local entry = EDITABLE_FRAMES[selectedIdx]
		local f = entry and rawget(_G, entry.id)
		if f then
			EditMode:NudgeScale(f, 0.05)
		end
	end)

	-- Row 3: Horizontal (X) Offset Slider
	local xText = d:CreateFontString(nil, "OVERLAY")
	xText:SetFont(ns.cfg.font, 11, "THINOUTLINE")
	xText:SetPoint("TOPLEFT", 14, -100)
	xText:SetTextColor(1, 0.82, 0)
	d.xText = xText

	local xMinus = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	xMinus:SetSize(20, 20)
	xMinus:SetPoint("TOPLEFT", 14, -116)
	xMinus:SetText("-")
	xMinus:SetScript("OnClick", function()
		local entry = EDITABLE_FRAMES[selectedIdx]
		local f = entry and rawget(_G, entry.id)
		if f then
			EditMode:NudgeFrameOffset(f, -5, 0)
		end
	end)

	local xSlider = CreateFrame("Slider", "Roth_UIXSlider", d, "OptionsSliderTemplate")
	xSlider:SetPoint("LEFT", xMinus, "RIGHT", 6, 0)
	xSlider:SetWidth(180)
	xSlider:SetHeight(16)
	xSlider:SetMinMaxValues(-1000, 1000)
	xSlider:SetValueStep(1)
	SetSliderLabel(xSlider, "Low", "-1000")
	SetSliderLabel(xSlider, "High", "+1000")
	SetSliderLabel(xSlider, "Text", "")
	xSlider:SetScript("OnValueChanged", function(s, value)
		if s.settingValue then
			return
		end
		local entry = EDITABLE_FRAMES[selectedIdx]
		local f = entry and rawget(_G, entry.id)
		if f then
			EditMode:SetFrameOffset(f, value, nil)
			if d.xText then
				d.xText:SetText(string.format("Horizontal (X): %d px", math.floor(value + 0.5)))
			end
		end
	end)
	d.xSlider = xSlider

	local xPlus = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	xPlus:SetSize(20, 20)
	xPlus:SetPoint("LEFT", xSlider, "RIGHT", 6, 0)
	xPlus:SetText("+")
	xPlus:SetScript("OnClick", function()
		local entry = EDITABLE_FRAMES[selectedIdx]
		local f = entry and rawget(_G, entry.id)
		if f then
			EditMode:NudgeFrameOffset(f, 5, 0)
		end
	end)

	-- Row 4: Vertical (Y) Offset Slider
	local yText = d:CreateFontString(nil, "OVERLAY")
	yText:SetFont(ns.cfg.font, 11, "THINOUTLINE")
	yText:SetPoint("TOPLEFT", 14, -142)
	yText:SetTextColor(1, 0.82, 0)
	d.yText = yText

	local yMinus = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	yMinus:SetSize(20, 20)
	yMinus:SetPoint("TOPLEFT", 14, -158)
	yMinus:SetText("-")
	yMinus:SetScript("OnClick", function()
		local entry = EDITABLE_FRAMES[selectedIdx]
		local f = entry and rawget(_G, entry.id)
		if f then
			EditMode:NudgeFrameOffset(f, 0, -5)
		end
	end)

	local ySlider = CreateFrame("Slider", "Roth_UIYSlider", d, "OptionsSliderTemplate")
	ySlider:SetPoint("LEFT", yMinus, "RIGHT", 6, 0)
	ySlider:SetWidth(180)
	ySlider:SetHeight(16)
	ySlider:SetMinMaxValues(-600, 800)
	ySlider:SetValueStep(1)
	SetSliderLabel(ySlider, "Low", "-600")
	SetSliderLabel(ySlider, "High", "+800")
	SetSliderLabel(ySlider, "Text", "")
	ySlider:SetScript("OnValueChanged", function(s, value)
		if s.settingValue then
			return
		end
		local entry = EDITABLE_FRAMES[selectedIdx]
		local f = entry and rawget(_G, entry.id)
		if f then
			EditMode:SetFrameOffset(f, nil, value)
			if d.yText then
				d.yText:SetText(string.format("Vertical (Y): %d px", math.floor(value + 0.5)))
			end
		end
	end)
	d.ySlider = ySlider

	local yPlus = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	yPlus:SetSize(20, 20)
	yPlus:SetPoint("LEFT", ySlider, "RIGHT", 6, 0)
	yPlus:SetText("+")
	yPlus:SetScript("OnClick", function()
		local entry = EDITABLE_FRAMES[selectedIdx]
		local f = entry and rawget(_G, entry.id)
		if f then
			EditMode:NudgeFrameOffset(f, 0, 5)
		end
	end)

	-- Row 5: Spacing Slider (context-specific)
	local spaceText = d:CreateFontString(nil, "OVERLAY")
	spaceText:SetFont(ns.cfg.font, 11, "THINOUTLINE")
	spaceText:SetPoint("TOPLEFT", 14, -184)
	spaceText:SetTextColor(1, 0.82, 0)
	d.spaceText = spaceText

	local spaceMinus = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	spaceMinus:SetSize(20, 20)
	spaceMinus:SetPoint("TOPLEFT", 14, -200)
	spaceMinus:SetText("-")
	spaceMinus:SetScript("OnClick", function()
		EditMode:NudgeSpacing(-1)
	end)
	d.spaceMinus = spaceMinus

	local spaceSlider = CreateFrame("Slider", "Roth_UISpaceSlider", d, "OptionsSliderTemplate")
	spaceSlider:SetPoint("LEFT", spaceMinus, "RIGHT", 6, 0)
	spaceSlider:SetWidth(180)
	spaceSlider:SetHeight(16)
	SetSliderLabel(spaceSlider, "Text", "")
	spaceSlider:SetScript("OnValueChanged", function(s, value)
		if s.settingValue then
			return
		end
		local entry = EDITABLE_FRAMES[selectedIdx]
		local info = EditMode:GetSpacingInfo(entry)
		if info and info.apply then
			info.apply(value)
			if d.spaceText then
				d.spaceText:SetText(string.format("%s %d%s", info.label, math.floor(value + 0.5), info.unit))
			end
		end
	end)
	d.spaceSlider = spaceSlider

	local spacePlus = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	spacePlus:SetSize(20, 20)
	spacePlus:SetPoint("LEFT", spaceSlider, "RIGHT", 6, 0)
	spacePlus:SetText("+")
	spacePlus:SetScript("OnClick", function()
		EditMode:NudgeSpacing(1)
	end)
	d.spacePlus = spacePlus

	-- Bottom Row: Reset to Default
	local resetBtn = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	resetBtn:SetSize(130, 22)
	resetBtn:SetPoint("BOTTOMLEFT", 14, 12)
	resetBtn:SetText("Reset to Default")
	resetBtn:SetScript("OnClick", function()
		EditMode:ResetSelected()
	end)

	local doneSubBtn = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
	doneSubBtn:SetSize(80, 22)
	doneSubBtn:SetPoint("BOTTOMRIGHT", -14, 12)
	doneSubBtn:SetText("Done")
	doneSubBtn:SetScript("OnClick", function()
		EditMode:SetActive(false)
	end)

	d:Hide()
	settingsDialog = d
	return d
end

function EditMode:UpdateDialog()
	if not settingsDialog or not settingsDialog:IsShown() then
		return
	end
	local entry = EDITABLE_FRAMES[selectedIdx]
	if not entry then
		return
	end
	local f = rawget(_G, entry.id)

	settingsDialog.title:SetText(entry.name)

	-- Update enabled check
	local isEnabled = self:IsElementEnabled(entry)
	settingsDialog.enableCheck:SetChecked(isEnabled)

	-- Update size slider
	local scale = self:GetScale(f)
	settingsDialog.sizeText:SetText(string.format("Size (Scale): %d%%", math.floor(scale * 100 + 0.5)))
	settingsDialog.sizeSlider.settingValue = true
	settingsDialog.sizeSlider:SetValue(scale)
	settingsDialog.sizeSlider.settingValue = nil

	-- Update X and Y position sliders
	local curX, curY = self:GetFramePosition(f)
	settingsDialog.xText:SetText(string.format("Horizontal (X): %d px", curX))
	settingsDialog.xSlider.settingValue = true
	settingsDialog.xSlider:SetValue(curX)
	settingsDialog.xSlider.settingValue = nil

	settingsDialog.yText:SetText(string.format("Vertical (Y): %d px", curY))
	settingsDialog.ySlider.settingValue = true
	settingsDialog.ySlider:SetValue(curY)
	settingsDialog.ySlider.settingValue = nil

	-- Update spacing slider
	local spaceInfo = self:GetSpacingInfo(entry)
	if spaceInfo then
		settingsDialog.spaceText:Show()
		settingsDialog.spaceMinus:Show()
		settingsDialog.spaceSlider:Show()
		settingsDialog.spacePlus:Show()

		settingsDialog.spaceText:SetText(
			string.format("%s %d%s", spaceInfo.label, math.floor(spaceInfo.value + 0.5), spaceInfo.unit)
		)
		settingsDialog.spaceSlider:SetMinMaxValues(spaceInfo.min, spaceInfo.max)
		settingsDialog.spaceSlider:SetValueStep(spaceInfo.step)
		SetSliderLabel(settingsDialog.spaceSlider, "Low", tostring(spaceInfo.min))
		SetSliderLabel(settingsDialog.spaceSlider, "High", tostring(spaceInfo.max))

		settingsDialog.spaceSlider.settingValue = true
		settingsDialog.spaceSlider:SetValue(spaceInfo.value)
		settingsDialog.spaceSlider.settingValue = nil
		settingsDialog:SetHeight(280)
	else
		settingsDialog.spaceText:Hide()
		settingsDialog.spaceMinus:Hide()
		settingsDialog.spaceSlider:Hide()
		settingsDialog.spacePlus:Hide()
		settingsDialog:SetHeight(235)
	end
end

-- Open dialog for clicked frame
function EditMode:OpenFrameConfig(frame)
	local targetId = type(frame) == "string" and frame or (frame and frame.GetName and frame:GetName())
	if not targetId then
		return
	end

	for i, entry in ipairs(EDITABLE_FRAMES) do
		if entry.id == targetId then
			selectedIdx = i
			break
		end
	end

	local entry = EDITABLE_FRAMES[selectedIdx]
	local f = rawget(_G, entry.id)
	local d = CreateSettingsDialog()

	-- Position dialog near frame if not moved by user
	if not d.userMoved and f then
		d:ClearAllPoints()
		local bottom = f:GetBottom() or 0
		if bottom < UIParent:GetHeight() / 2 then
			d:SetPoint("BOTTOM", f, "TOP", 0, 20)
		else
			d:SetPoint("TOP", f, "BOTTOM", 0, -20)
		end
	end

	d:Show()
	if f then
		ShowSelectionGlow(f.dragframe or f)
	end
	self:UpdateDialog()

	if self.UpdateTopBar then
		self:UpdateTopBar()
	end
end

function EditMode:SelectFrame(frameOrName)
	self:OpenFrameConfig(frameOrName)
end

local doneBar

------------------------------------------------------------------------
-- THE DROPDOWN LIST (shows all options)
------------------------------------------------------------------------
local dropdownFrame
local function CreateDropdownFrame()
	if dropdownFrame then
		return dropdownFrame
	end

	local d = CreateFrame("Frame", "Roth_UIEditDropdown", UIParent, "BackdropTemplate")
	d:SetSize(235, 275)
	d:SetFrameStrata("TOOLTIP")
	d:SetClampedToScreen(true)
	d:EnableMouse(true)
	d:SetBackdrop({
		bgFile = "Interface\\AddOns\\DiabolusUnits\\media\\Tooltip_Background",
		edgeFile = "Interface\\AddOns\\DiabolusUnits\\media\\Tooltip_Border",
		edgeSize = 12,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	})
	d:SetBackdropColor(0.12, 0.12, 0.12, 0.98)

	local sf = CreateFrame("ScrollFrame", "Roth_UIEditDropdownScroll", d, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 6, -6)
	sf:SetPoint("BOTTOMRIGHT", -26, 6)

	local content = CreateFrame("Frame", nil, sf)
	content:SetSize(200, #EDITABLE_FRAMES * 23)
	sf:SetScrollChild(content)

	d.buttons = {}
	for i, entry in ipairs(EDITABLE_FRAMES) do
		local btn = CreateFrame("Button", nil, content)
		btn:SetSize(200, 22)
		btn:SetPoint("TOPLEFT", 0, -((i - 1) * 23))

		local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 0.82, 0.2, 0.25)

		local txt = btn:CreateFontString(nil, "OVERLAY")
		txt:SetFont(ns.cfg.font or "Fonts\\FRIZQT__.TTF", 11, "THINOUTLINE")
		txt:SetPoint("LEFT", 6, 0)
		txt:SetPoint("RIGHT", -6, 0)
		txt:SetJustifyH("LEFT")
		txt:SetText(entry.name)
		btn.txt = txt

		btn:SetScript("OnClick", function()
			selectedIdx = i
			EditMode:OpenFrameConfig(entry.id)
			d:Hide()
		end)

		d.buttons[i] = btn
	end

	d:SetScript("OnShow", function()
		for i, entry in ipairs(EDITABLE_FRAMES) do
			local btn = d.buttons[i]
			if btn and btn.txt then
				local isSel = (i == selectedIdx)
				local isEnabled = EditMode:IsElementEnabled(entry)
				if isSel then
					btn.txt:SetTextColor(1, 0.85, 0.2)
					btn.txt:SetText("> " .. entry.name)
				elseif not isEnabled then
					btn.txt:SetTextColor(0.55, 0.55, 0.55)
					btn.txt:SetText(entry.name .. " (Off)")
				else
					btn.txt:SetTextColor(1, 1, 1)
					btn.txt:SetText(entry.name)
				end
			end
		end
	end)

	d:Hide()
	dropdownFrame = d
	return d
end

function EditMode:ToggleDropdown()
	local d = CreateDropdownFrame()
	if d:IsShown() then
		d:Hide()
	else
		if doneBar and doneBar.dropdownBtn then
			d:ClearAllPoints()
			d:SetPoint("TOPLEFT", doneBar.dropdownBtn, "BOTTOMLEFT", 0, -2)
			d:Show()
		end
	end
end

------------------------------------------------------------------------
-- THE TOP TOOLBAR (DoneBar)
------------------------------------------------------------------------
local function DoneBar()
	if doneBar then
		return doneBar
	end

	doneBar = CreateFrame("Frame", "Roth_UIEditLayoutBar", UIParent, "BackdropTemplate")
	doneBar:SetSize(730, 48)
	doneBar:SetPoint("TOP", UIParent, "TOP", 0, -90)
	doneBar:SetFrameStrata("DIALOG")
	doneBar:SetClampedToScreen(true)
	doneBar:SetMovable(true)
	doneBar:EnableMouse(true)
	doneBar:RegisterForDrag("LeftButton")
	doneBar:SetScript("OnDragStart", doneBar.StartMoving)
	doneBar:SetScript("OnDragStop", doneBar.StopMovingOrSizing)

	doneBar:SetBackdrop({
		bgFile = "Interface\\AddOns\\DiabolusUnits\\media\\Tooltip_Background",
		edgeFile = "Interface\\AddOns\\DiabolusUnits\\media\\Tooltip_Border",
		edgeSize = 12,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	doneBar:SetBackdropColor(0.5, 0.45, 0.45, 0.95)

	local title = doneBar:CreateFontString(nil, "OVERLAY")
	title:SetFont(ns.cfg.headerFont or ns.cfg.font, 14, "THINOUTLINE")
	title:SetPoint("LEFT", 12, 0)
	title:SetTextColor(1, 0.82, 0.4)
	title:SetText("Edit layout")

	local prevBtn = CreateFrame("Button", nil, doneBar, "UIPanelButtonTemplate")
	prevBtn:SetSize(22, 22)
	prevBtn:SetPoint("LEFT", title, "RIGHT", 10, 0)
	prevBtn:SetText("<")
	prevBtn:SetScript("OnClick", function()
		selectedIdx = selectedIdx - 1
		if selectedIdx < 1 then
			selectedIdx = #EDITABLE_FRAMES
		end
		EditMode:OpenFrameConfig(EDITABLE_FRAMES[selectedIdx].id)
	end)

	local dropdownBtn = CreateFrame("Button", "Roth_UIEditDropdownButton", doneBar, "UIPanelButtonTemplate")
	dropdownBtn:SetSize(175, 24)
	dropdownBtn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
	dropdownBtn:SetText("Select Element  v")
	dropdownBtn:SetScript("OnClick", function()
		EditMode:ToggleDropdown()
	end)

	local nextBtn = CreateFrame("Button", nil, doneBar, "UIPanelButtonTemplate")
	nextBtn:SetSize(22, 22)
	nextBtn:SetPoint("LEFT", dropdownBtn, "RIGHT", 4, 0)
	nextBtn:SetText(">")
	nextBtn:SetScript("OnClick", function()
		selectedIdx = selectedIdx + 1
		if selectedIdx > #EDITABLE_FRAMES then
			selectedIdx = 1
		end
		EditMode:OpenFrameConfig(EDITABLE_FRAMES[selectedIdx].id)
	end)

	local scaleLabel = doneBar:CreateFontString(nil, "OVERLAY")
	scaleLabel:SetFont(ns.cfg.font, 11, "THINOUTLINE")
	scaleLabel:SetPoint("LEFT", nextBtn, "RIGHT", 10, 0)
	scaleLabel:SetTextColor(1, 0.82, 0)
	scaleLabel:SetText("UI Size:")

	local scaleMinus = CreateFrame("Button", nil, doneBar, "UIPanelButtonTemplate")
	scaleMinus:SetSize(20, 20)
	scaleMinus:SetPoint("LEFT", scaleLabel, "RIGHT", 6, 0)
	scaleMinus:SetText("-")
	scaleMinus:SetScript("OnClick", function()
		EditMode:NudgeGlobalScale(-0.05)
	end)

	local scaleSlider = CreateFrame("Slider", "Roth_UIGlobalScaleSlider", doneBar, "OptionsSliderTemplate")
	scaleSlider:SetPoint("LEFT", scaleMinus, "RIGHT", 4, 0)
	scaleSlider:SetWidth(95)
	scaleSlider:SetHeight(16)
	scaleSlider:SetMinMaxValues(0.50, 1.50)
	scaleSlider:SetValueStep(0.01)
	SetSliderLabel(scaleSlider, "Text", "")
	SetSliderLabel(scaleSlider, "Low", "50%")
	SetSliderLabel(scaleSlider, "High", "150%")
	scaleSlider:SetScript("OnValueChanged", function(s, value)
		if s.settingValue then
			return
		end
		EditMode:SetGlobalScale(value)
	end)

	local scalePlus = CreateFrame("Button", nil, doneBar, "UIPanelButtonTemplate")
	scalePlus:SetSize(20, 20)
	scalePlus:SetPoint("LEFT", scaleSlider, "RIGHT", 4, 0)
	scalePlus:SetText("+")
	scalePlus:SetScript("OnClick", function()
		EditMode:NudgeGlobalScale(0.05)
	end)

	local scaleVal = doneBar:CreateFontString(nil, "OVERLAY")
	scaleVal:SetFont(ns.cfg.font, 11, "THINOUTLINE")
	scaleVal:SetPoint("LEFT", scalePlus, "RIGHT", 5, 0)
	scaleVal:SetTextColor(1, 1, 1)
	scaleVal:SetText("100%")

	local resetBtn = CreateFrame("Button", nil, doneBar, "UIPanelButtonTemplate")
	resetBtn:SetSize(75, 24)
	resetBtn:SetPoint("LEFT", scaleVal, "RIGHT", 8, 0)
	resetBtn:SetText("Reset UI")
	resetBtn:SetScript("OnClick", function()
		EditMode:ResetAllToDefault()
	end)

	local done = CreateFrame("Button", nil, doneBar, "UIPanelButtonTemplate")
	done:SetSize(65, 24)
	done:SetPoint("RIGHT", -10, 0)
	done:SetText("Done")
	done:SetScript("OnClick", function()
		EditMode:SetActive(false)
	end)

	doneBar.dropdownBtn = dropdownBtn
	doneBar.scaleSlider = scaleSlider
	doneBar.scaleVal = scaleVal

	function EditMode:UpdateTopBar()
		if not doneBar or not doneBar:IsShown() then
			return
		end
		local entry = EDITABLE_FRAMES[selectedIdx]
		if entry and doneBar.dropdownBtn then
			doneBar.dropdownBtn:SetText(entry.name .. "  v")
		end
		local gs = EditMode:GetGlobalScale()
		if doneBar.scaleSlider then
			doneBar.scaleSlider.settingValue = true
			doneBar.scaleSlider:SetValue(gs)
			doneBar.scaleSlider.settingValue = nil
		end
		if doneBar.scaleVal then
			doneBar.scaleVal:SetText(string.format("%d%%", math.floor(gs * 100 + 0.5)))
		end
	end

	doneBar:Hide()
	return doneBar
end

function EditMode:SetActive(on, quiet, fromBlizzard)
	on = on and true or false
	if on == self.active then
		if not on then
			if doneBar then
				doneBar:Hide()
			end
			if settingsDialog then
				settingsDialog:Hide()
			end
			if dropdownFrame then
				dropdownFrame:Hide()
			end
			ShowSelectionGlow(nil)
		end
		return
	end
	if on and InCombatLockdown() then
		Say("the layout can be edited out of combat.")
		return
	end
	self.active = on
	for _, group in ipairs(GROUPS) do
		if on and Roth_UIUnlock then
			Roth_UIUnlock(group, true)
		elseif not on and Roth_UILock then
			Roth_UILock(group, true)
		end
	end
	if ns.SwingTimer and ns.SwingTimer.SetEditing then
		ns.SwingTimer.SetEditing(on)
	end

	-- Also ensure every frame in EDITABLE_FRAMES with a dragframe is unlocked/locked
	for _, entry in ipairs(EDITABLE_FRAMES) do
		local f = rawget(_G, entry.id)
		if f and f.dragframe then
			if on then
				if self:IsElementEnabled(entry) then
					f.dragframe:Show()
					f.dragframe:EnableMouse(true)
					f.dragframe:RegisterForDrag("LeftButton")
				end
			else
				f.dragframe:Hide()
				f.dragframe:EnableMouse(false)
				f.dragframe:RegisterForDrag()
			end
		end
	end

	if on then
		DoneBar():Show()
		self:UpdateTopBar()
		self:OpenFrameConfig(EDITABLE_FRAMES[selectedIdx].id)
	else
		if doneBar then
			doneBar:Hide()
		end
		if settingsDialog then
			settingsDialog:Hide()
		end
		if dropdownFrame then
			dropdownFrame:Hide()
		end
		ShowSelectionGlow(nil)
	end

	if not quiet then
		if on then
			Say("edit layout: click any frame to open its settings (size, spacing, enable/disable), or drag to move.")
		else
			Say("layout saved.")
		end
	end
end

function EditMode:Toggle()
	self:SetActive(not self.active)
end

-- Restore saved scales, positions, and disabled states at login
local function RestoreSavedLayout()
	local db = GetDB()
	if not db then
		return
	end

	-- Apply pixel-perfect scale if enabled
	if ns.func and ns.func.ApplyPixelPerfectScale then
		ns.func.ApplyPixelPerfectScale()
	end

	-- Restore global scale & individual scales
	local gs = EditMode:GetGlobalScale()
	EditMode:ApplyGlobalScale(gs)

	if db.frameScales and not InCombatLockdown() then
		for name, scale in pairs(db.frameScales) do
			local f = rawget(_G, name)
			local entry = EditMode:EntryFor(name)
			if entry and entry.headerScale then
				f = nil -- sized through ApplyHeaderScales
			end
			if f and f.SetScale and type(scale) == "number" and scale >= 0.5 and scale <= 2.0 then
				f:SetScale(scale * gs)
			end
		end
	end

	-- Restore stone bar size
	if db.barWidth and db.barHeight and not InCombatLockdown() then
		local bg = rawget(_G, "Roth_UIActionBarBackground")
		if bg then
			bg:SetSize(db.barWidth, db.barHeight)
		end
	end

	-- Restore frame positions
	if db.framePositions and not InCombatLockdown() then
		for name, pos in pairs(db.framePositions) do
			local f = rawget(_G, name)
			if f and f.ClearAllPoints and f.SetPoint and pos and pos.point then
				local relTo = (pos.relativeTo and rawget(_G, pos.relativeTo)) or UIParent
				f:ClearAllPoints()
				f:SetPoint(pos.point, relTo, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
			end
		end
	end

	-- Restore disabled / hidden states
	if db.disabledElements and not InCombatLockdown() then
		for frameId, disabled in pairs(db.disabledElements) do
			if disabled then
				local f = rawget(_G, frameId)
				if f and f.Hide then
					f:Hide()
				end
			end
		end
	end

	-- Restore individual element positions
	if
		db.angelX
		and ns.cfg
		and ns.cfg.units
		and ns.cfg.units.player
		and ns.cfg.units.player.art
		and ns.cfg.units.player.art.angel
	then
		ns.cfg.units.player.art.angel.pos.x = db.angelX
	end
	if
		db.demonX
		and ns.cfg
		and ns.cfg.units
		and ns.cfg.units.player
		and ns.cfg.units.player.art
		and ns.cfg.units.player.art.demon
	then
		ns.cfg.units.player.art.demon.pos.x = db.demonX
	end
	if
		db.bottomLineY
		and ns.cfg
		and ns.cfg.units
		and ns.cfg.units.player
		and ns.cfg.units.player.art
		and ns.cfg.units.player.art.bottomline
	then
		ns.cfg.units.player.art.bottomline.pos.y = db.bottomLineY
	end
end

-- Blizzard's Edit Mode callback
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("EditMode.Enter", function()
		EditMode:SetActive(true, true, true)
	end, EditMode)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		EditMode:SetActive(false, true)
	end, EditMode)
end

local function WatchEditModeWindow()
	local manager = rawget(_G, "EditModeManagerFrame")
	if manager and manager.HookScript and not EditMode.watching then
		EditMode.watching = true
		manager:HookScript("OnHide", function()
			EditMode:SetActive(false, true)
		end)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		WatchEditModeWindow()
		RestoreSavedLayout()
		return
	end
	if EditMode.active then
		EditMode:SetActive(false, true)
		Say("edit layout closed for combat; what you moved is kept.")
	end
end)
