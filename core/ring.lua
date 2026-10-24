---------------------------------------------
--  DiabolusForever - radial ring menu
---------------------------------------------
-- Combat-safe secure radial menu engine for controller play.
-- Slices hold consumables (potions, healthstone, mana gems, bandages, food, drink),
-- class utility spells, quest items, or player spells.
--
-- RestrictedExecution binds A (use), B (close), D-pad (step) and sticks (aim)
-- only while the ring is open. Zero controller keys are intercepted while closed.

local addon, ns = ...

local cfg = ns.cfg
local Glyphs = ns.Glyphs
local MEDIA = "Interface\\AddOns\\DiabolusForever\\media\\"

local Ring = {}
ns.Ring = Ring

local MAX_SLICES = 12
local RADIUS = 140

Ring.kinds = {}
Ring.openers = {}

Ring.KINDS = {
	consume = { title = "Consumables", icon = "Interface\\Icons\\INV_Potion_51", head = MEDIA .. "d3_head_garg", macro = "DF Consume" },
	utility = { title = "Utility", icon = "Interface\\Icons\\INV_Misc_Rune_01", head = MEDIA .. "d3_head_new", macro = "DF Utility" },
	quest = { title = "Quest Items", icon = "Interface\\Icons\\INV_Misc_Book_08", head = MEDIA .. "d3_head_skull", macro = "DF Quest" },
	spells = { title = "Spells", icon = "Interface\\Icons\\INV_Misc_Book_11", head = MEDIA .. "d3_head_diablo", macro = "DF Spells" },
}

-- Safe out-of-combat queue helper
local pendingOut = {}
local regenFrame = CreateFrame("Frame")
regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
regenFrame:SetScript("OnEvent", function()
	for k, fn in pairs(pendingOut) do
		pendingOut[k] = nil
		pcall(fn)
	end
end)

function Ring:RunOutOfCombat(key, fn)
	if not InCombatLockdown() then
		fn()
	else
		pendingOut[key] = fn
	end
end

---------------------------------------------
-- RESTRICTED SNIPPETS (owner = the ring)
---------------------------------------------

local OPEN_SNIPPET = [[
	local kind = ...
	if not kind then
		return
	end
	if self:IsShown() then
		local current = self:GetAttribute("r-kind")
		self:Hide()
		if current == kind then
			return
		end
	end
	local count = self:GetAttribute("r-" .. kind .. "-count") or 0
	self:SetAttribute("r-kind", kind)
	self:SetAttribute("r-count", count)
	self:SetAttribute("r-sel", nil)
	self:SetAttribute("r-pointed", nil)
	if count < 1 then
		self:CallMethod("OnRingEmpty", kind)
		return
	end
	self:Show()
]]

local OPEN_BODY = [[
	owner:RunAttribute("r-open", self:GetAttribute("r-kind"))
	return false
]]

local SHOW_BODY = [[
	local mods = newtable("", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-")
	local pick = self:GetFrameRef("r-pick")
	for _, mod in ipairs(mods) do
		self:SetBindingClick(true, mod .. "PAD1", "DiabolusForeverRingUse", "LeftButton")
		self:SetBindingClick(true, mod .. "PAD2", "DiabolusForeverRingClose", "LeftButton")
		for _, key in ipairs(newtable("PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT")) do
			self:SetBindingClick(true, mod .. key, "DiabolusForeverRingStep", key)
		end
		for _, key in ipairs(newtable("PADLSTICKUP", "PADLSTICKDOWN", "PADLSTICKLEFT", "PADLSTICKRIGHT",
				"PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT")) do
			self:SetBindingClick(true, mod .. key, "DiabolusForeverRingPick", key)
			if pick then
				pick:SetAttribute("held-" .. key, 0)
			end
		end
	end
	self:CallMethod("OnRingShown")
]]

local HIDE_BODY = [[
	self:ClearBindings()
	self:CallMethod("OnRingHidden")
]]

local FIRE_SNIPPET = [[
	local kind = owner:GetAttribute("r-kind")
	local entryType = owner:GetAttribute("r-" .. kind .. "-t-" .. sel)
	local entryValue = owner:GetAttribute("r-" .. kind .. "-v-" .. sel)
	if entryType == "item" then
		self:SetAttribute("item", entryValue)
	elseif entryType == "spell" then
		self:SetAttribute("spell", entryValue)
	elseif entryType == "macro" then
		self:SetAttribute("macrotext", entryValue)
	else
		entryType = nil
	end
	self:SetAttribute("type", entryType)
	if attr == "typerelease" then
		self:SetAttribute("typerelease", entryType)
	end
	owner:CallMethod("OnRingFired", sel)
	owner:Hide()
]]

local USE_BODY = [[
	self:SetAttribute("type", nil)
	local sel = owner:GetAttribute("r-sel")
	if not sel then
		owner:Hide()
		return false
	end
	local attr = "type"
]] .. FIRE_SNIPPET

local CLOSE_BODY = [[
	owner:Hide()
	return false
]]

local STEP_BODY = [[
	local count = owner:GetAttribute("r-count") or 0
	if count < 1 then
		return false
	end
	local current = owner:GetAttribute("r-sel")
	local forward = button == "PADDRIGHT" or button == "PADDDOWN"
	if not current then
		if forward then
			current = 1
		else
			current = count
		end
	elseif forward then
		current = current % count + 1
	else
		current = (current - 2) % count + 1
	end
	owner:SetAttribute("r-sel", current)
	owner:SetAttribute("r-pointed", nil)
	owner:CallMethod("OnRingSelect", current)
	return false
]]

local PICK_BODY = [[
	self:SetAttribute("type", nil)
	self:SetAttribute("typerelease", nil)
	if not owner:IsShown() then
		return false
	end
	local side = strsub(button, 1, 9)
	local stickIndex = 1
	if side == "PADRSTICK" then
		stickIndex = 2
	end
	self:SetAttribute("held-" .. button, down and 1 or 0)
	if down then
		for _, dir in ipairs(newtable("UP", "DOWN", "LEFT", "RIGHT")) do
			if side .. dir ~= button then
				self:SetAttribute("held-" .. side .. dir, 0)
			end
		end
	end
	local count = owner:GetAttribute("r-count") or 0
	local pad = GetGamePadState and GetGamePadState()
	local sticks = pad and pad.sticks
	local stick = sticks and sticks[stickIndex]
	local lengthSq = 0
	if stick and stick.x and stick.y then
		lengthSq = stick.x * stick.x + stick.y * stick.y
	end
	local needed = 0.5
	if down then
		needed = 0.12
	end
	local best, bestDot
	if lengthSq > needed then
		for index = 1, count do
			local dot = stick.x * (owner:GetAttribute("r-dx-" .. count .. "-" .. index) or 0)
				+ stick.y * (owner:GetAttribute("r-dy-" .. count .. "-" .. index) or 0)
			if not bestDot or dot > bestDot then
				best, bestDot = index, dot
			end
		end
	elseif down then
		local kx, ky = 0, 0
		if self:GetAttribute("held-" .. side .. "UP") == 1 then
			ky = ky + 1
		end
		if self:GetAttribute("held-" .. side .. "DOWN") == 1 then
			ky = ky - 1
		end
		if self:GetAttribute("held-" .. side .. "RIGHT") == 1 then
			kx = kx + 1
		end
		if self:GetAttribute("held-" .. side .. "LEFT") == 1 then
			kx = kx - 1
		end
		if kx ~= 0 or ky ~= 0 then
			for index = 1, count do
				local dot = kx * (owner:GetAttribute("r-dx-" .. count .. "-" .. index) or 0)
					+ ky * (owner:GetAttribute("r-dy-" .. count .. "-" .. index) or 0)
				if not bestDot or dot > bestDot then
					best, bestDot = index, dot
				end
			end
		end
	end
	if best then
		if owner:GetAttribute("r-sel") ~= best then
			owner:SetAttribute("r-sel", best)
			owner:CallMethod("OnRingSelect", best)
		end
		owner:SetAttribute("r-pointed", stickIndex)
	end
	if down then
		return false
	end
	if owner:GetAttribute("r-release") ~= 1 or owner:GetAttribute("r-pointed") ~= stickIndex then
		return false
	end
	for _, dir in ipairs(newtable("UP", "DOWN", "LEFT", "RIGHT")) do
		if self:GetAttribute("held-" .. side .. dir) == 1 and lengthSq > 0.55 then
			return false
		end
	end
	local sel = owner:GetAttribute("r-sel")
	if not sel then
		return false
	end
	local attr = "typerelease"
]] .. FIRE_SNIPPET

---------------------------------------------
-- SECURE FRAMES
---------------------------------------------

local function SecureButton(name, ...)
	local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	b:SetSize(1, 1)
	b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
	b:RegisterForClicks(...)
	return b
end

local function CreateSecure()
	local ring = CreateFrame("Frame", "DiabolusForeverRing", UIParent, "SecureHandlerBaseTemplate")
	ring:SetSize(1, 1)
	ring:SetPoint("CENTER")
	ring:Hide()
	ring:SetAttribute("r-open", OPEN_SNIPPET)
	Ring.ring = ring

	-- Unit vectors for every ring size: slice 1 at 12 o'clock, clockwise.
	for count = 1, MAX_SLICES do
		for index = 1, count do
			local angle = (index - 1) * (2 * math.pi / count)
			ring:SetAttribute("r-dx-" .. count .. "-" .. index, math.sin(angle))
			ring:SetAttribute("r-dy-" .. count .. "-" .. index, math.cos(angle))
		end
	end

	local use = SecureButton("DiabolusForeverRingUse", "AnyDown")
	use:SetAttribute("useOnKeyDown", true)
	SecureHandlerWrapScript(use, "OnClick", ring, USE_BODY)

	local close = SecureButton("DiabolusForeverRingClose", "AnyDown")
	SecureHandlerWrapScript(close, "OnClick", ring, CLOSE_BODY)

	local step = SecureButton("DiabolusForeverRingStep", "AnyDown")
	SecureHandlerWrapScript(step, "OnClick", ring, STEP_BODY)

	local pick = SecureButton("DiabolusForeverRingPick", "AnyDown", "AnyUp")
	pick:SetAttribute("pressAndHoldAction", true)
	SecureHandlerWrapScript(pick, "OnClick", ring, PICK_BODY)
	SecureHandlerSetFrameRef(ring, "r-pick", pick)

	SecureHandlerWrapScript(ring, "OnShow", ring, SHOW_BODY)
	SecureHandlerWrapScript(ring, "OnHide", ring, HIDE_BODY)

	ring.OnRingShown = function()
		Ring:OnShown()
	end
	ring.OnRingHidden = function()
		Ring:OnHidden()
	end
	ring.OnRingSelect = function(_, index)
		Ring:OnSelect(index)
	end
	ring.OnRingFired = function()
		PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE or 851)
	end
	ring.OnRingEmpty = function(_, kind)
		local def = Ring.kinds[kind]
		print(("|c00FF3300DiabolusForever:|r %s ring is empty%s."):format(Ring.KINDS[kind].title, def and def.emptyHint and (": " .. def.emptyHint) or ""))
	end

	for kind in pairs(Ring.KINDS) do
		local opener = SecureButton("DiabolusForeverRingOpen_" .. kind, "AnyDown")
		opener:SetAttribute("r-kind", kind)
		SecureHandlerWrapScript(opener, "OnClick", ring, OPEN_BODY)
		Ring.openers[kind] = opener
	end
end

---------------------------------------------
-- CONTENT DEFINITION
---------------------------------------------

function Ring:Define(kind, entries, emptyHint)
	local def = self.kinds[kind] or {}
	def.entries = entries or {}
	def.emptyHint = emptyHint
	self.kinds[kind] = def
	self:RunOutOfCombat("ring-" .. kind, function()
		Ring:Push(kind)
	end)
end

function Ring:Push(kind)
	local def, ring = self.kinds[kind], self.ring
	if not (def and ring) then
		return
	end
	local count = math.min(#def.entries, MAX_SLICES)
	ring:SetAttribute("r-" .. kind .. "-count", count)
	self.helpers = self.helpers or {}
	for index = 1, MAX_SLICES do
		local entry = index <= count and def.entries[index] or nil
		local secureKind, secureValue = entry and entry.kind, entry and entry.value
		if secureKind == "click" then
			local name = "DiabolusForeverRingHelper_" .. kind .. "_" .. index
			local helper = self.helpers[name]
			if not helper then
				helper = CreateFrame("Button", name, UIParent)
				helper:SetSize(1, 1)
				helper:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
				helper:RegisterForClicks("AnyDown", "AnyUp")
				helper:SetScript("OnClick", function(frame)
					if type(frame.entryFunc) == "function" then
						frame.entryFunc()
					end
				end)
				self.helpers[name] = helper
			end
			helper.entryFunc = entry.func
			secureKind, secureValue = "macro", "/click " .. name
		end
		ring:SetAttribute("r-" .. kind .. "-t-" .. index, secureKind)
		ring:SetAttribute("r-" .. kind .. "-v-" .. index, secureValue)
	end
	ring:SetAttribute("r-release", 0)
end

---------------------------------------------
-- VISUAL (insecure overlay)
---------------------------------------------

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function RoundIcon(parent, size, layer)
	local icon = parent:CreateTexture(nil, layer or "ARTWORK")
	icon:SetSize(size, size)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if parent.CreateMaskTexture then
		local mask = parent:CreateMaskTexture()
		mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(icon)
		icon:AddMaskTexture(mask)
	end
	return icon
end

local function CreateSlice(parent)
	local s = CreateFrame("Frame", nil, parent)
	s:SetSize(48, 48)

	local bg = s:CreateTexture(nil, "BACKGROUND")
	Glyphs.Round(bg, MEDIA .. "combo_orb_bg", 50)
	bg:SetPoint("CENTER")

	s.icon = RoundIcon(s, 42)
	s.icon:SetPoint("CENTER")

	local ring = s:CreateTexture(nil, "OVERLAY", nil, 1)
	Glyphs.Round(ring, MEDIA .. "combo_orb_border", 48)
	ring:SetPoint("CENTER")
	ring:SetVertexColor(0.75, 0.62, 0.45)

	local gloss = s:CreateTexture(nil, "OVERLAY", nil, 2)
	Glyphs.Round(gloss, MEDIA .. "combo_orb_highlight", 28)
	gloss:SetPoint("CENTER")
	gloss:SetAlpha(0.3)

	s.glow = s:CreateTexture(nil, "BACKGROUND", nil, -1)
	Glyphs.Round(s.glow, MEDIA .. "combo_orb_glow", 72)
	s.glow:SetPoint("CENTER")
	s.glow:SetVertexColor(1, 0.5, 0.1)
	s.glow:SetBlendMode("ADD")
	s.glow:Hide()

	s.count = ns.func.createFontString(s, cfg.font, 13, "THINOUTLINE")
	s.count:SetPoint("BOTTOMRIGHT", 4, -2)

	s.label = ns.func.createFontString(s, cfg.font, 11, "THINOUTLINE")
	s.label:SetPoint("TOP", s, "BOTTOM", 0, -6)
	s.label:SetTextColor(0.85, 0.75, 0.55)
	return s
end

local function CreateLegendItem(parent, key, text)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(1, 22)
	local badge = Glyphs:CreateBadge(f, 20, key)
	badge.dimAlpha = 1
	badge:SetLit(false)
	badge.glyph:SetDesaturated(false)
	badge:SetPoint("LEFT", 0, 0)
	local label = ns.func.createFontString(f, cfg.font, 13, "THINOUTLINE")
	label:SetPoint("LEFT", badge, "RIGHT", 8, 0)
	label:SetText(text)
	label:SetTextColor(0.9, 0.82, 0.6)
	f:SetWidth(20 + 8 + (label:GetStringWidth() or 40) + 18)
	f.label = label
	return f
end

local function CreateVisual()
	local v = CreateFrame("Frame", "DiabolusForeverRingVisual", UIParent)
	v:SetSize(RADIUS * 2 + 120, RADIUS * 2 + 120)
	v:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	v:SetFrameStrata("FULLSCREEN_DIALOG")
	v:Hide()
	Ring.visual = v

	local base = v:CreateTexture(nil, "BACKGROUND", nil, -3)
	Glyphs.Round(base, MEDIA .. "combo_orb_bg", RADIUS * 2 + 92)
	base:SetPoint("CENTER")
	base:SetVertexColor(0.75, 0.7, 0.68, 0.95)

	local disc = v:CreateTexture(nil, "BACKGROUND", nil, -2)
	Glyphs.Round(disc, MEDIA .. "orb_back2", RADIUS * 2 + 92)
	disc:SetPoint("CENTER")

	local rim = v:CreateTexture(nil, "BACKGROUND", nil, -1)
	Glyphs.Round(rim, MEDIA .. "combo_orb_border", RADIUS * 2 + 100)
	rim:SetPoint("CENTER")
	rim:SetVertexColor(0.7, 0.58, 0.42)

	v.head = v:CreateTexture(nil, "ARTWORK", nil, 3)
	v.head:SetSize(192, 96)
	v.head:SetPoint("CENTER", v, "CENTER", 0, RADIUS + 52)

	v.hub = RoundIcon(v, 64)
	v.hub:SetPoint("CENTER")
	local hubBg = v:CreateTexture(nil, "BORDER")
	Glyphs.Round(hubBg, MEDIA .. "combo_orb_bg", 74)
	hubBg:SetPoint("CENTER")
	local hubRing = v:CreateTexture(nil, "OVERLAY", nil, 1)
	Glyphs.Round(hubRing, MEDIA .. "combo_orb_border", 72)
	hubRing:SetPoint("CENTER")
	hubRing:SetVertexColor(0.8, 0.66, 0.46)
	local hubGloss = v:CreateTexture(nil, "OVERLAY", nil, 2)
	Glyphs.Round(hubGloss, MEDIA .. "orb_gloss", 62)
	hubGloss:SetPoint("CENTER")
	hubGloss:SetAlpha(0.6)

	v.pointer = v:CreateTexture(nil, "OVERLAY", nil, 3)
	Glyphs.Round(v.pointer, MEDIA .. "combo_orb_glow", 22)
	v.pointer:SetVertexColor(1, 0.4, 0.05)
	v.pointer:SetBlendMode("ADD")
	v.pointer:Hide()

	local plate = v:CreateTexture(nil, "ARTWORK")
	plate:SetTexture(MEDIA .. "UIButton_300x51_Normal")
	plate:SetSize(320, 80)
	plate:SetPoint("TOP", v, "BOTTOM", 0, 34)
	v.title = ns.func.createFontString(v, cfg.font, 20, "THINOUTLINE")
	v.title:SetPoint("CENTER", plate, "CENTER", 0, 1)
	v.title:SetTextColor(1, 0.82, 0.4)
	v.name = ns.func.createFontString(v, cfg.font, 15, "THINOUTLINE")
	v.name:SetPoint("TOP", plate, "BOTTOM", 0, 10)

	local legend = CreateFrame("Frame", nil, v)
	legend:SetSize(1, 22)
	legend:SetPoint("TOP", v.name, "BOTTOM", 0, -8)
	local items = {
		CreateLegendItem(legend, "PADRSTICK", "Aim"),
		CreateLegendItem(legend, "PAD1", "Use"),
		CreateLegendItem(legend, "PADDLEFT", "Step"),
		CreateLegendItem(legend, "PAD2", "Close"),
	}
	local width = 0
	for _, item in ipairs(items) do
		width = width + item:GetWidth()
	end
	local x = -width / 2
	for _, item in ipairs(items) do
		item:SetPoint("LEFT", legend, "CENTER", x, 0)
		x = x + item:GetWidth()
	end
	v.legendItems = items

	v.slices = {}
	for index = 1, MAX_SLICES do
		v.slices[index] = CreateSlice(v)
		v.slices[index]:Hide()
	end

	v:SetScript("OnUpdate", function()
		local state = GetGamePadState and GetGamePadState()
		local sticks = state and state.sticks
		local x, y = 0, 0
		for i = 2, 1, -1 do
			local s = sticks and sticks[i]
			if s and s.x and s.y and (s.x * s.x + s.y * s.y) > 0.1 then
				x, y = s.x, s.y
				break
			end
		end
		if x ~= 0 or y ~= 0 then
			local angle = math.atan2(x, y)
			v.pointer:ClearAllPoints()
			v.pointer:SetPoint("CENTER", v, "CENTER", math.sin(angle) * 62, math.cos(angle) * 62)
			v.pointer:Show()
		else
			v.pointer:Hide()
		end
	end)
end

local function ItemCount(entry)
	if not entry.itemID then
		return ""
	end
	local count = C_Item and C_Item.GetItemCount and ns.Secrets and ns.Secrets.Number(C_Item.GetItemCount(entry.itemID))
	if count and count > 1 then
		return tostring(count)
	end
	return ""
end

function Ring:Layout(kind)
	local v, def, info = self.visual, self.kinds[kind], self.KINDS[kind]
	if not (v and def and info) then
		return
	end
	v.title:SetText(info.title)
	v.name:SetText("")
	v.hub:SetTexture(info.icon)
	v.head:SetTexture(info.head)
	local count = math.min(#def.entries, MAX_SLICES)
	for index = 1, MAX_SLICES do
		local slice, entry = v.slices[index], def.entries[index]
		if entry and index <= count then
			local angle = (index - 1) * (2 * math.pi / count)
			slice.entry = entry
			slice:ClearAllPoints()
			slice:SetPoint("CENTER", v, "CENTER", math.sin(angle) * RADIUS, math.cos(angle) * RADIUS)
			slice.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			slice.label:SetText(entry.short or "")
			slice.count:SetText(ItemCount(entry))
			slice.glow:Hide()
			slice:SetScale(1)
			slice:Show()
		else
			slice.entry = nil
			slice:Hide()
		end
	end
end

---------------------------------------------
-- OPEN / CLOSE FEEDBACK
---------------------------------------------

local saved = {}
local function SetTemp(name, value)
	if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
	local current = C_CVar.GetCVar(name)
	if current == value then
		return
	end
	if saved[name] == nil then
		saved[name] = current
	end
	pcall(C_CVar.SetCVar, name, value)
end

local function RestoreTemp()
	if not (C_CVar and C_CVar.SetCVar) then return end
	for name, value in pairs(saved) do
		local ok = pcall(C_CVar.SetCVar, name, value)
		if ok then
			saved[name] = nil
		end
	end
end

function Ring:OnShown()
	self:Layout(self.ring:GetAttribute("r-kind"))
	self.visual:Show()
	SetTemp("GamePadStickAxisButtons", "1")
	SetTemp("GamePadCameraYawSpeed", "0")
	SetTemp("GamePadCameraPitchSpeed", "0")
	PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 850)
end

function Ring:OnHidden()
	self.visual:Hide()
	RestoreTemp()
	PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE or 851)
end

function Ring:OnSelect(index)
	local v = self.visual
	for i, slice in ipairs(v.slices) do
		local on = i == index
		slice.glow:SetShown(on)
		slice:SetScale(on and 1.15 or 1)
	end
	local slice = v.slices[index]
	if slice and slice.entry then
		v.name:SetText(slice.entry.name or "")
		v.hub:SetTexture(slice.entry.icon)
	end
	PlaySound(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115)
end

function Ring:MacroText(kind)
	return "/click DiabolusForeverRingOpen_" .. kind .. " LeftButton 1"
end

function Ring:CreateMacros()
	if InCombatLockdown() then
		print("|c00FF3300DiabolusForever:|r macros can only be made out of combat.")
		return
	end
	local made = {}
	for _, kind in ipairs({ "consume", "utility", "quest", "spells" }) do
		local info = self.KINDS[kind]
		if info then
			local body = self:MacroText(kind)
			local index = GetMacroIndexByName(info.macro)
			local ok = true
			if index and index > 0 then
				EditMacro(index, info.macro, nil, body)
			else
				ok = pcall(CreateMacro, info.macro, info.icon:match("([^\\]+)$") or "INV_Misc_QuestionMark", body, nil)
			end
			if ok then
				made[#made + 1] = "|cffffd100" .. info.macro .. "|r"
			end
		end
	end
	print(("|c00FF3300DiabolusForever:|r controller ring macros %s are ready."):format(table.concat(made, ", ")))
end

function Ring:OpenFromInsecure(kind)
	if not self.KINDS[kind] or not self.ring then
		return
	end
	if InCombatLockdown() then
		print("|c00FF3300DiabolusForever:|r in combat, open rings with their macro or key binding.")
		return
	end
	self:Push(kind)
	self.ring:SetAttribute("r-pending", kind)
	self.ring:Execute([[ self:RunAttribute("r-open", self:GetAttribute("r-pending")) ]])
end

CreateSecure()
CreateVisual()

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
	if not Ring.ring:IsShown() then
		RestoreTemp()
	end
end)
