-- DiabolusUnits — settings/Theme.lua
--
-- Geometry, fonts, colours and shared helpers for the DiabolusUnits settings window.
--
-- The window framework (Theme, Popup, Rows, Sidebar, Gamepad, Content) is ported from
-- PulseHaptics' UI/Panel (same author). Its two stability rules carry over unchanged:
--
--   1. No pooling. A row is built once for its page, the first time the page is opened,
--      and lives for the session, so no gamepad navigation reference can go stale.
--   2. A plain ScrollFrame, not a ScrollBox: SmartNavigation scrolls it with a flat
--      SetVerticalScroll (Blizzard_GamepadSmartNavigation/SmartNavigation.lua:879).
--
-- Geometry numbers are Blizzard's settings panel's; the colours are Diablo's.

local ADDON_NAME, ns = ...

ns.UI = ns.UI or {}
ns.UI.Panel = ns.UI.Panel or {}
local Panel = ns.UI.Panel

local Theme = {}
Panel.Theme = Theme

-- ── Window ────────────────────────────────────────────────────────────────────
-- Blizzard_SettingsPanel.xml:4-8.
Theme.PANEL_WIDTH = 920
Theme.PANEL_HEIGHT = 724

-- Blizzard_SettingsPanel.xml:60-66. The sidebar's own size plus where it sits.
Theme.SIDEBAR_WIDTH = 199
Theme.SIDEBAR_INSET_X = 18
Theme.SIDEBAR_INSET_Y = -76
Theme.SIDEBAR_BOTTOM = 46

-- Blizzard_SettingsPanel.xml:67-77.
Theme.CONTAINER_GAP = 16 -- between sidebar right edge and the content container
Theme.CONTAINER_RIGHT = -22

-- Blizzard_SettingsList.xml:6-25. The page header band above the scrolling list.
Theme.HEADER_HEIGHT = 50
Theme.HEADER_TITLE_X = 7
Theme.HEADER_TITLE_Y = -22
Theme.HEADER_TITLE_FONT = "GameFontHighlightHuge"

-- Blizzard_SettingsList.lua:53-82. verticalPad/padLeft/padRight/spacing for the list, and
-- where the scroll region sits relative to the header.
Theme.LIST_VERTICAL_PAD = 10
Theme.LIST_PAD_LEFT = 25
Theme.LIST_PAD_RIGHT = 0
Theme.LIST_SPACING = 9
Theme.LIST_TOP_X = -15
Theme.LIST_TOP_Y = -2
Theme.LIST_BOTTOM_X = -20
Theme.LIST_BOTTOM_Y = -2

-- ── Rows ──────────────────────────────────────────────────────────────────────
-- Blizzard_SettingControls.xml:104-131 (26px rows) and :13 (45px section header).
Theme.ROW_HEIGHT = 26
Theme.HEADER_ROW_H = 45

-- Blizzard_SettingControls.lua:1 — indentSize, and :338-341 for where the label sits.
-- Text runs from (indent + 37) on the left to 85px short of the row's centre; the control
-- itself starts 80px short of that same centre.
Theme.INDENT = 15
Theme.TEXT_LEFT = 37
Theme.TEXT_RIGHT = -85
Theme.CONTROL_LEFT = -80

-- Blizzard_SettingControls.lua:338 — a parented (child) row drops to the small font.
Theme.FONT_NORMAL = "GameFontNormal"
Theme.FONT_CHILD = "GameFontNormalSmall"

-- Blizzard_SettingControls.xml:82-90 / :693 / :802 / :922.
Theme.CHECKBOX_SIZE_X = 30
Theme.CHECKBOX_SIZE_Y = 29
Theme.SLIDER_WIDTH = 250
Theme.SLIDER_OFFSET_Y = 3
Theme.DROPDOWN_LEFT = -48 -- dropdown rows sit further right than sliders
Theme.DROPDOWN_WIDTH = 220
Theme.BUTTON_WIDTH = 200
Theme.BUTTON_LEFT = -40

-- One-line cue row (Phase 2). Left-anchored offsets inside a ~605 px row at the stock
-- 920 px window. [verify in game at 1280x800 and UI scale 0.64-1.0]
Theme.CUE_CHECK_LEFT = 4
Theme.CUE_LABEL_LEFT = 38
Theme.CUE_LABEL_WIDTH = 190
Theme.CUE_SLIDER_LEFT = 232
Theme.CUE_SLIDER_WIDTH = 150
Theme.CUE_DROPDOWN_LEFT = 392
Theme.CUE_DROPDOWN_WIDTH = 150
Theme.CUE_PLAY_LEFT = 550
Theme.CUE_PLAY_WIDTH = 28

-- Blizzard_CategoryList.xml:47-49 and :63-68.
Theme.CATEGORY_HEIGHT = 20
Theme.CATEGORY_LABEL_X = 36
Theme.CATEGORY_INDENT = 12

-- ── Colors & Palette ──────────────────────────────────────────────────────────
-- Diablo: tarnished gold on soot, blood red for warnings, parchment text
Theme.COLOR_ACCENT = { r = 0.86, g = 0.62, b = 0.28 }
Theme.COLOR_ACCENT_DIM = { r = 0.45, g = 0.30, b = 0.13 }
Theme.COLOR_BG = { r = 0.040, g = 0.030, b = 0.025 }
Theme.COLOR_SURFACE = { r = 0.085, g = 0.062, b = 0.048 }
Theme.COLOR_BORDER = { r = 0.36, g = 0.26, b = 0.16 }
Theme.COLOR_BLOOD = { r = 0.62, g = 0.08, b = 0.05 }

Theme.COLOR_TEXT_PRIMARY = { r = 0.93, g = 0.87, b = 0.74 }
Theme.COLOR_TEXT_MUTED = { r = 0.58, g = 0.50, b = 0.40 }
Theme.COLOR_TEXT_ACCENT = Theme.COLOR_ACCENT
Theme.COLOR_LIVE = { r = 0.40, g = 0.80, b = 0.30 }

-- Page titles in the Diablo face (stays on the stock font object if the file will not load)
Theme.DIABLO_FONT = "Interface\\AddOns\\DiabolusUnits\\media\\Diablo Std Regular.otf"
do
	local font = CreateFont("DiabolusSettingsTitleFont")
	font:CopyFontObject(GameFontHighlightHuge)
	if font:SetFont(Theme.DIABLO_FONT, 20, "") then
		font:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
		Theme.HEADER_TITLE_FONT = "DiabolusSettingsTitleFont"
	end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Faint gold wash under the cursor.
function Theme.CreateHoverBackground(frame, inset)
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.08)
	texture:SetPoint("TOPLEFT", frame, "TOPLEFT", inset or -10, 0)
	texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 0)
	texture:Hide()
	return texture
end

-- One tooltip for the whole panel, styled like Blizzard's SettingsTooltip: control name as
-- title, description wrapped underneath. Deliberately NOT SettingsTooltip itself — that
-- frame belongs to the panel being replaced, and borrowing it would put the dependency
-- back.
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
		local bg = button:CreateTexture(nil, "BACKGROUND")
		bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		bg:SetColorTexture(Theme.COLOR_SURFACE.r, Theme.COLOR_SURFACE.g, Theme.COLOR_SURFACE.b, 0.95)
		button.DiabolusBg = bg

		local border = button:CreateTexture(nil, "BORDER")
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
