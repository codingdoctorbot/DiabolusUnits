-- Settings geometry, fonts, colours, and shared widget helpers.
-- Framework ported from PulseHaptics UI/Panel (same author).
-- Rows stay bound to one setting; pages use a plain ScrollFrame.

local ADDON_NAME, ns = ...

ns.UI = ns.UI or {}
ns.UI.Panel = ns.UI.Panel or {}
local Panel = ns.UI.Panel

local Theme = {}
Panel.Theme = Theme

-- Window

Theme.PANEL_WIDTH = 1000
Theme.PANEL_HEIGHT = 660

-- Sidebar size and placement.
Theme.SIDEBAR_WIDTH = 172
Theme.SIDEBAR_INSET_X = 14
Theme.SIDEBAR_INSET_Y = -62
Theme.SIDEBAR_BOTTOM = 48

Theme.CONTAINER_GAP = 24 -- between sidebar right edge and the content container
Theme.CONTAINER_RIGHT = -22

-- Header above the scrolling content.
Theme.HEADER_HEIGHT = 42
Theme.HEADER_TITLE_X = 8
Theme.HEADER_TITLE_Y = -8
Theme.HEADER_TITLE_FONT = "GameFontHighlightHuge"

-- Content padding and scroll-region offsets.
Theme.LIST_VERTICAL_PAD = 8
Theme.LIST_PAD_LEFT = 8
Theme.LIST_PAD_RIGHT = 0
Theme.LIST_SPACING = 1
Theme.LIST_TOP_X = 0
Theme.LIST_TOP_Y = -2
Theme.LIST_BOTTOM_X = -14
Theme.LIST_BOTTOM_Y = -2

-- Rows
-- Row and section-header heights.
Theme.ROW_HEIGHT = 34
Theme.HEADER_ROW_H = 34

-- Label and control offsets within each settings row.
Theme.INDENT = 15
Theme.TEXT_LEFT = 12
Theme.TEXT_RIGHT = 18
Theme.CONTROL_LEFT = 38

-- Initial font objects; themed faces are assigned below.
Theme.FONT_NORMAL = "GameFontNormal"
Theme.FONT_CHILD = "GameFontNormalSmall"

-- Control sizes.
Theme.CHECKBOX_SIZE_X = 18
Theme.CHECKBOX_SIZE_Y = 18
Theme.SLIDER_WIDTH = 245
Theme.SLIDER_OFFSET_Y = 0
Theme.DROPDOWN_LEFT = 38 -- dropdown rows sit further right than sliders
Theme.DROPDOWN_WIDTH = 224
Theme.BUTTON_WIDTH = 220
Theme.BUTTON_LEFT = 38

-- Cue-row control offsets.
Theme.CUE_CHECK_LEFT = 4
Theme.CUE_LABEL_LEFT = 38
Theme.CUE_LABEL_WIDTH = 190
Theme.CUE_SLIDER_LEFT = 232
Theme.CUE_SLIDER_WIDTH = 150
Theme.CUE_DROPDOWN_LEFT = 392
Theme.CUE_DROPDOWN_WIDTH = 150
Theme.CUE_PLAY_LEFT = 550
Theme.CUE_PLAY_WIDTH = 28

-- Category geometry.
Theme.CATEGORY_HEIGHT = 30
Theme.CATEGORY_LABEL_X = 34
Theme.CATEGORY_INDENT = 0

-- Colors & Palette
-- Diablo: tarnished gold on soot, blood red for warnings, parchment text
Theme.COLOR_ACCENT = { r = 0.76, g = 0.59, b = 0.37 }
Theme.COLOR_ACCENT_DIM = { r = 0.45, g = 0.30, b = 0.13 }
Theme.COLOR_BG = { r = 0.060, g = 0.055, b = 0.050 }
Theme.COLOR_SURFACE = { r = 0.108, g = 0.098, b = 0.086 }
Theme.COLOR_BORDER = { r = 0.25, g = 0.225, b = 0.195 }
Theme.COLOR_BLOOD = { r = 0.62, g = 0.08, b = 0.05 }

Theme.COLOR_TEXT_PRIMARY = { r = 0.88, g = 0.855, b = 0.81 }
Theme.COLOR_TEXT_MUTED = { r = 0.61, g = 0.58, b = 0.53 }
Theme.COLOR_TEXT_ACCENT = Theme.COLOR_ACCENT
Theme.COLOR_LIVE = { r = 0.40, g = 0.80, b = 0.30 }

-- A neutral typeface for controls; HUD font preferences remain independent.
Theme.FONT_PATH = "Interface\\AddOns\\DiabolusUnits\\media\\Expressway.ttf"
Theme.COLOR_FOCUS = { r = 0.56, g = 0.72, b = 0.86 }
local function font(name, size, color)
	local f = CreateFont(name)
	f:CopyFontObject(GameFontHighlight)
	f:SetFont(Theme.FONT_PATH, size, "")
	f:SetTextColor(color.r, color.g, color.b)
	return name
end
Theme.FONT_NORMAL = font("DiabolusSettingsText", 13, Theme.COLOR_TEXT_PRIMARY)
Theme.FONT_CHILD = font("DiabolusSettingsSmall", 12, Theme.COLOR_TEXT_MUTED)
Theme.HEADER_TITLE_FONT = font("DiabolusSettingsTitle", 18, Theme.COLOR_TEXT_PRIMARY)
Theme.SECTION_FONT = font("DiabolusSettingsSection", 13, Theme.COLOR_ACCENT)

-- A one-unit border behind the widget contents; physical size follows UI scale.
function Theme.CreateSurface(frame, background, borderColor)
	local c = borderColor or Theme.COLOR_BORDER
	local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
	edge:SetAllPoints(frame)
	edge:SetColorTexture(c.r, c.g, c.b, 1)
	c = background or Theme.COLOR_SURFACE
	local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
	fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	fill:SetColorTexture(c.r, c.g, c.b, 1)
	return fill, edge
end

-- Helpers

-- Faint gold wash under the cursor.
function Theme.CreateHoverBackground(frame, inset)
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.08)
	texture:SetPoint("TOPLEFT", frame, "TOPLEFT", inset or -10, 0)
	texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 0)
	texture:Hide()
	return texture
end

-- Use one addon-owned tooltip for control labels and descriptions.
local tooltip

local function getTooltip()
	if tooltip then
		return tooltip
	end
	-- SharedTooltipTemplate is Blizzard_SharedXML and always present; the fallback only
	-- degrades a missing template to no tooltip rather than to a broken panel.
	local ok, frame = pcall(CreateFrame, "GameTooltip", "DiabolusSettingsTooltip", UIParent, "SharedTooltipTemplate")
	if ok and frame then
		tooltip = frame
	else
		tooltip = GameTooltip
	end
	return tooltip
end

function Theme.ShowTooltip(owner, title, body)
	if not title and not body then
		return
	end
	local tip = getTooltip()
	if not tip then
		return
	end
	tip:SetOwner(owner, "ANCHOR_RIGHT", -10, 0)
	if title and title ~= "" then
		tip:SetText(title, 1, 1, 1, 1, true)
		if body and body ~= "" then
			tip:AddLine(" ")
			tip:AddLine(body, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
		end
	else
		tip:SetText(body, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
	end
	tip:Show()
end

function Theme.HideTooltip()
	local tip = getTooltip()
	if tip then
		tip:Hide()
	end
end

-- Every SmartNavigation call in this tree goes through these two. The globals come from
-- Blizzard_GamepadSmartNavigation, loaded only where gamepad UI exists, so a bare call
-- would error without it. Guarded once here rather than at forty call sites.
function Theme.MarkIgnored(frame)
	if frame and type(SmartNavigation_MarkFrameIgnored) == "function" then
		pcall(SmartNavigation_MarkFrameIgnored, frame)
	end
end

function Theme.MarkFocusable(frame)
	if frame and type(SmartNavigation_MarkFrameFocusable) == "function" then
		pcall(SmartNavigation_MarkFrameFocusable, frame)
	end
end

function Theme.ClearIgnored(frame)
	if frame and type(SmartNavigation_ClearIgnoreStatus) == "function" then
		pcall(SmartNavigation_ClearIgnoreStatus, frame)
	end
end

function Theme.PlayCheckSound(on)
	if not SOUNDKIT then
		return
	end
	local kit = on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
	if kit then
		PlaySound(kit)
	end
end

-- Flat soot button with a bronze (or gold, for the main action) border
function Theme.StyleActionButton(button, isAccent)
	if not button then
		return
	end
	if button.Left then
		button.Left:SetAlpha(0)
	end
	if button.Middle then
		button.Middle:SetAlpha(0)
	end
	if button.Right then
		button.Right:SetAlpha(0)
	end
	local normal = button:GetNormalTexture()
	if normal then
		normal:SetAlpha(0)
	end
	local pushed = button:GetPushedTexture()
	if pushed then
		pushed:SetAlpha(0)
	end
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetAlpha(0)
	end

	if not button.DiabolusBg then
		local bg = button:CreateTexture(nil, "BACKGROUND", nil, -6)
		bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		bg:SetColorTexture(Theme.COLOR_SURFACE.r, Theme.COLOR_SURFACE.g, Theme.COLOR_SURFACE.b, 0.95)
		button.DiabolusBg = bg

		local border = button:CreateTexture(nil, "BACKGROUND", nil, -7)
		border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
		border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
		if isAccent then
			border:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.7)
		else
			border:SetColorTexture(Theme.COLOR_BORDER.r, Theme.COLOR_BORDER.g, Theme.COLOR_BORDER.b, 0.8)
		end
		button.DiabolusBorder = border

		local hl = button:CreateTexture(nil, "HIGHLIGHT")
		hl:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		hl:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		hl:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.18)
		button:SetHighlightTexture(hl)
	end

	local fs = button:GetFontString()
	if fs then
		fs:SetFontObject(Theme.FONT_NORMAL)
		fs:SetTextColor(Theme.COLOR_TEXT_PRIMARY.r, Theme.COLOR_TEXT_PRIMARY.g, Theme.COLOR_TEXT_PRIMARY.b)
	end
end

-- Greying out. Blizzard's SettingsListElementMixin:DisplayEnabled
-- (Blizzard_SettingControls.lua:282-292) does these same three things, including taking the
-- row out of gamepad navigation: a disabled row should be unreachable, not merely dimmed.
function Theme.DisplayEnabled(row, enabled)
	local color = enabled and Theme.COLOR_TEXT_PRIMARY or Theme.COLOR_TEXT_MUTED
	if row.Text then
		row.Text:SetTextColor(color.r, color.g, color.b)
	end
	if row.DesaturateHierarchy then
		row:DesaturateHierarchy(enabled and 0 or 1)
	end
	if enabled then
		Theme.ClearIgnored(row)
	else
		Theme.MarkIgnored(row)
	end
end

function Theme.StylePlainButton(button, label)
	local text = button:GetFontString()
	if not text then
		text = button:CreateFontString(nil, "OVERLAY", Theme.FONT_NORMAL)
		text:SetPoint("LEFT", button, "LEFT", 8, 0)
		text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
		button:SetFontString(text)
	end
	if label then
		button:SetText(label)
	end
	Theme.StyleActionButton(button, false)
	button:HookScript("OnEnable", function()
		text:SetTextColor(Theme.COLOR_TEXT_PRIMARY.r, Theme.COLOR_TEXT_PRIMARY.g, Theme.COLOR_TEXT_PRIMARY.b)
	end)
	button:HookScript("OnDisable", function()
		text:SetTextColor(0.38, 0.40, 0.43)
	end)
	return text
end

function Theme.StyleSlider(control)
	control:SetHeight(22)
	local slider = control.Slider
	for _, key in ipairs({ "Left", "Right", "Middle" }) do
		if slider[key] then
			slider[key]:SetAlpha(0)
		end
	end
	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT", slider, "LEFT", 0, 0)
	track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
	track:SetHeight(3)
	track:SetColorTexture(Theme.COLOR_BORDER.r, Theme.COLOR_BORDER.g, Theme.COLOR_BORDER.b, 1)
	if slider.Thumb then
		slider.Thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
		slider.Thumb:SetVertexColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
		slider.Thumb:SetSize(5, 14)
	end
	for _, item in ipairs({ { control.Back, "<" }, { control.Forward, ">" } }) do
		local button = item[1]
		if button then
			for _, region in ipairs({ button:GetRegions() }) do
				if region:IsObjectType("Texture") then
					region:SetAlpha(0)
				end
			end
			button:SetSize(18, 22)
			Theme.StylePlainButton(button, item[2])
		end
	end
	if control.RightText then
		control.RightText:SetFontObject(Theme.FONT_NORMAL)
		control.RightText:SetTextColor(
			Theme.COLOR_TEXT_PRIMARY.r,
			Theme.COLOR_TEXT_PRIMARY.g,
			Theme.COLOR_TEXT_PRIMARY.b
		)
	end
end

-- Small, uniform symbols drawn with the client's Line API. No item/spell thumbnails,
-- texture packs or per-frame drawing. Coordinates share a 16-unit canvas.
local iconPaths = {
	brand = {
		{ 4, 3, 4, 5, 2, 7, 2, 11, 5, 14, 11, 14, 14, 11, 14, 7, 12, 5, 12, 3, 4, 3 },
		{ 5, 9, 6, 9 },
		{ 10, 9, 11, 9 },
		{ 7, 6, 8, 7, 9, 6 },
		{ 6, 3, 6, 1, 10, 1, 10, 3 },
		{ 8, 1, 8, 3 },
	},
	overview = {
		{ 2, 9, 2, 14, 7, 14, 7, 9, 2, 9 },
		{ 10, 9, 10, 14, 14, 14, 14, 9, 10, 9 },
		{ 2, 2, 2, 6, 7, 6, 7, 2, 2, 2 },
		{ 10, 2, 10, 6, 14, 6, 14, 2, 10, 2 },
	},
	layout = {
		{ 1, 3, 1, 12, 15, 12, 15, 3, 1, 3 },
		{ 3, 9, 5, 9 },
		{ 7, 9, 9, 9 },
		{ 11, 9, 13, 9 },
		{ 3, 6, 5, 6 },
		{ 7, 6, 9, 6 },
		{ 11, 6, 13, 6 },
		{ 5, 3, 5, 1, 11, 1, 11, 3 },
	},
	gamepad = {
		{ 2, 3, 1, 5, 2, 11, 4, 13, 12, 13, 14, 11, 15, 5, 14, 3, 11, 6, 5, 6, 2, 3 },
		{ 4, 8, 4, 11 },
		{ 2.5, 9.5, 5.5, 9.5 },
		{ 10, 10, 11, 10 },
		{ 12, 8, 13, 8 },
	},
	unitframes = { { 1, 2, 1, 14, 15, 14, 15, 2, 1, 2 }, { 6, 2, 6, 14 }, { 9, 10, 13, 10 }, { 9, 6, 13, 6 } },
 castbars = { { 1, 5, 1, 11, 15, 11, 15, 5, 1, 5 }, { 3, 7, 9, 7 }, { 3, 9, 9, 9 }, { 11, 4, 11, 12 } },
 tooltips = { { 2, 4, 2, 14, 14, 14, 14, 4, 8, 4, 5, 1, 5, 4, 2, 4 }, { 5, 11, 11, 11 }, { 5, 8, 10, 8 } },
	nameplates = { { 1, 9, 1, 13, 15, 13, 15, 9, 1, 9 }, { 3, 3, 3, 6, 13, 6, 13, 3, 3, 3 } },
	health = { { 5, 8, 11, 8 }, { 8, 5, 8, 11 } },
	power = { { 9, 13, 5, 7, 9, 7, 7, 3 } },
	belt = {
		{ 2, 12, 4, 12, 4, 10, 5, 9, 5, 3, 1, 3, 1, 9, 2, 10, 2, 12 },
		{ 7, 12, 9, 12, 9, 10, 10, 9, 10, 3, 6, 3, 6, 9, 7, 10, 7, 12 },
		{ 12, 12, 14, 12, 14, 10, 15, 9, 15, 3, 11, 3, 11, 9, 12, 10, 12, 12 },
	},
	fonts = { { 2, 3, 7, 14, 12, 3 }, { 4, 7, 10, 7 }, { 11, 12, 15, 12 }, { 13, 12, 13, 3 }, { 11, 3, 15, 3 } },
	profiles = { { 5, 1, 5, 11, 10, 11, 14, 7, 14, 1, 5, 1 }, { 10, 11, 10, 7, 14, 7 }, { 2, 5, 2, 15, 10, 15 } },
	help = { { 5, 10, 5, 11, 7, 12, 9, 12, 11, 10, 10, 8, 8, 7, 8, 6 }, { 8, 3, 8, 3.5 } },
}
function Theme.CreateIcon(parent, key, size)
	local paths = iconPaths[key]
	if not paths then
		return
	end
	local icon = CreateFrame("Frame", nil, parent)
	icon:SetSize(size or 16, size or 16)
	icon.lines = {}
	local scale = (size or 16) / 16
	local function segment(x1, y1, x2, y2)
		local line = icon:CreateLine(nil, "ARTWORK")
		line:SetThickness(1.2 * scale)
		line:SetStartPoint("BOTTOMLEFT", icon, x1 * scale, y1 * scale)
		line:SetEndPoint("BOTTOMLEFT", icon, x2 * scale, y2 * scale)
		icon.lines[#icon.lines + 1] = line
	end
	for _, path in ipairs(paths) do
		for i = 1, #path - 2, 2 do
			segment(path[i], path[i + 1], path[i + 2], path[i + 3])
		end
	end
	if key == "health" or key == "power" or key == "help" then
		for i = 0, 15 do
			local a, b = i * math.pi / 8, (i + 1) * math.pi / 8
			segment(8 + math.cos(a) * 6.5, 8 + math.sin(a) * 6.5, 8 + math.cos(b) * 6.5, 8 + math.sin(b) * 6.5)
		end
	end
	function icon:SetIconColor(c)
		for _, line in ipairs(self.lines) do
			line:SetColorTexture(c.r, c.g, c.b, 1)
		end
	end
	icon:SetIconColor(Theme.COLOR_TEXT_MUTED)
	Theme.MarkIgnored(icon)
	return icon
end
