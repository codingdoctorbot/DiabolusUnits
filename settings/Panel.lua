-- DiabolusUnits — settings/Panel.lua
--
-- The settings window: one place for every DiabolusUnits setting (orbs, layout, belt,
-- fonts, profiles). The edit layout (moving and sizing frames) stays separate and is opened
-- from here. Assembled from Theme, Popup, Rows, Sidebar, Gamepad, Content and Spec, which
-- are ported from PulseHaptics UI/Panel.
--
-- Built lazily the first time it is opened. Taint rules, all carried over from PulseHaptics:
--   * Shown with a plain Show() plus UISpecialFrames for Escape, never ShowUIPanel: the panel
--     manager hands the frame to FrameControlsManager, whose protected binding call is
--     refused from an addon's stack (ADDON_ACTION_FORBIDDEN, and in gamepad mode the 20 s
--     freeze loop).
--   * No Blizzard Menu or StaticPopup inside it (settings/Popup.lua says why).
--   * Closes when combat starts; nothing in it is needed in a fight.
-- The entry in Esc > Options > AddOns is a canvas page with one button. It does not close
-- Blizzard's settings window (HideUIPanel from addon code is the same forbidden route); ours
-- opens above it at DIALOG strata.

local ADDON_NAME, ns = ...

local Panel = ns.UI.Panel
local Theme = Panel.Theme
local Content = Panel.Content
local Sidebar = Panel.Sidebar
local Gamepad = Panel.Gamepad
local Spec = Panel.Spec

local FRAME_NAME = "DiabolusUnitsSettingsFrame"
local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"

local frame
local dirty, dirtyScheduled = false, false

-- ── Refresh ───────────────────────────────────────────────────────────────────

local function processDirty()
	dirtyScheduled = false
	if not dirty then
		return
	end
	dirty = false
	if frame and frame:IsShown() then
		frame.Content:RefreshRows()
		frame.Content:LayoutRows()
	end
end

-- Called after every write; at most one refresh pass per frame, only while shown.
function Panel.MarkDirty()
	dirty = true
	if dirtyScheduled or not frame or not frame:IsShown() then
		return
	end
	dirtyScheduled = true
	C_Timer.After(0, processDirty)
end
Panel.Refresh = Panel.MarkDirty

-- Folded sections (session only)
local folded = {}
function Panel.IsSectionCollapsed(key)
	return folded[key] and true or false
end
function Panel.SetSectionCollapsed(key, collapsed)
	folded[key] = collapsed or nil
	Panel.MarkDirty()
end

-- ── Orb preview ───────────────────────────────────────────────────────────────
-- While the window is open both orbs show full, so liquid, effects and numbers can be
-- judged on an empty mana or rage bar (the old orb panel did the same).

local preview = CreateFrame("Frame")
local function fillOrbs()
	local helper = ns.panel and ns.panel.eventHelper
	if helper and helper.SetOrbsToMax then
		helper:SetOrbsToMax()
	end
end
preview:SetScript("OnEvent", fillOrbs)

local function startPreview()
	preview:RegisterUnitEvent("UNIT_HEALTH", "player")
	preview:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	preview:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	fillOrbs()
end

local function stopPreview()
	preview:UnregisterAllEvents()
	local helper = ns.panel and ns.panel.eventHelper
	if helper and helper.SetOrbsToDefault then
		helper:SetOrbsToDefault()
	end
end

-- ── Window ────────────────────────────────────────────────────────────────────

local function addonVersion()
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local ok, version = pcall(get, ADDON_NAME, "Version")
	return (ok and version and version ~= "") and ("v" .. version) or ""
end

local function createWindow()
	for _, template in ipairs({ "SettingsFrameTemplate", "ButtonFrameTemplate" }) do
		local ok, result = pcall(CreateFrame, "Frame", FRAME_NAME, UIParent, template)
		if ok and result then
			return result
		end
	end
	return CreateFrame("Frame", FRAME_NAME, UIParent)
end

local function buildWindow()
	local f = createWindow()
	f:SetSize(Theme.PANEL_WIDTH, Theme.PANEL_HEIGHT)
	f:SetPoint("CENTER")
	-- DIALOG: above Blizzard's own settings window (HIGH), which may be open underneath
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()

	local titleText = f.NineSlice and f.NineSlice.Text
	if not titleText then
		titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		titleText:SetPoint("TOP", f, "TOP", 0, -5)
	end
	titleText:SetText("DIABOLUS UNITS")
	titleText:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)

	local titleIcon = f:CreateTexture(nil, "OVERLAY")
	titleIcon:SetSize(18, 18)
	titleIcon:SetTexture(MEDIA .. "d2_skull")
	titleIcon:SetPoint("RIGHT", titleText, "LEFT", -6, 0)

	-- SettingsFrameTemplate's Bg has an absolute frameLevel 0 and renders below other
	-- windows in the strata; an opaque fill of our own keeps the window solid.
	if f.Bg and f.Bg.SetFrameLevel then
		f.Bg:SetFrameLevel(f:GetFrameLevel())
	end
	local fill = f:CreateTexture(nil, "BACKGROUND")
	fill:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -20)
	fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
	fill:SetColorTexture(Theme.COLOR_BG.r, Theme.COLOR_BG.g, Theme.COLOR_BG.b, 1)

	-- Faint stone bar art behind the content
	local watermark = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	watermark:SetTexture(MEDIA .. "d3_bottom")
	watermark:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 4)
	watermark:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
	watermark:SetHeight(160)
	watermark:SetAlpha(0.12)

	local inner = f:CreateTexture(nil, "OVERLAY", nil, 2)
	if pcall(inner.SetAtlas, inner, "Options_InnerFrame", true) then
		inner:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -64)
	else
		inner:Hide()
	end

	if not f.ClosePanelButton then
		local ok, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
		if ok and close then
			f.ClosePanelButton = close
		end
	end
	if f.ClosePanelButton then
		f.ClosePanelButton:SetScript("OnClick", Panel.Close)
	end

	-- Window transparency toggle (Ghost Mode) for live visual feedback
	local opacityBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	opacityBtn:SetSize(110, 20)
	if f.ClosePanelButton then
		opacityBtn:SetPoint("RIGHT", f.ClosePanelButton, "LEFT", -4, 0)
	else
		opacityBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -4)
	end
	opacityBtn:SetText("Opacity: 100%")
	Theme.StyleActionButton(opacityBtn, false)
	local opacityLevels = { 1.0, 0.60, 0.35 }
	local currentOpacityIdx = 1
	opacityBtn:SetScript("OnClick", function()
		currentOpacityIdx = (currentOpacityIdx % #opacityLevels) + 1
		local alpha = opacityLevels[currentOpacityIdx]
		f:SetAlpha(alpha)
		local label = ("Opacity: %d%%"):format(math.floor(alpha * 100))
		if alpha < 1.0 then
			label = ("|cffdfaa46👁 %d%% Ghost|r"):format(math.floor(alpha * 100))
		end
		opacityBtn:SetText(label)
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
	end)
	opacityBtn:SetScript("OnEnter", function()
		Theme.ShowTooltip(
			opacityBtn,
			"Window Opacity (Ghost Mode)",
			"Cycles window transparency (100% -> 60% -> 35%) so you can see your unit frames and HUD directly behind the settings panel while adjusting options."
		)
	end)
	opacityBtn:SetScript("OnLeave", function()
		Theme.HideTooltip()
	end)
	f.OpacityButton = opacityBtn

	local closeButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	closeButton:SetSize(96, 22)
	closeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
	closeButton:SetText(CLOSE or "Close")
	Theme.StyleActionButton(closeButton, false)
	closeButton:SetScript("OnClick", Panel.Close)

	local status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 18)
	status:SetJustifyH("LEFT")
	status:SetText(("|cff94806aDiabolusUnits %s   •   /diabolus|r"):format(addonVersion()))

	local sidebar = Sidebar.Create(f, function(page)
		if f.SearchBox and f.SearchBox:GetText() ~= "" then
			f.SearchBox:SetText("")
		end
		f.Content:SetPage(page)
	end)
	sidebar:SetWidth(Theme.SIDEBAR_WIDTH)
	sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", Theme.SIDEBAR_INSET_X, Theme.SIDEBAR_INSET_Y)
	sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", Theme.SIDEBAR_INSET_X, Theme.SIDEBAR_BOTTOM)
	f.Sidebar = sidebar

	local container = CreateFrame("Frame", nil, f)
	container:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", Theme.CONTAINER_GAP, 0)
	container:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", Theme.CONTAINER_GAP, 1)
	container:SetPoint("RIGHT", f, "RIGHT", Theme.CONTAINER_RIGHT, 0)
	f.Container = container
	f.Content = Content.Create(container)

	-- Search within the page in view
	local ok, search = pcall(CreateFrame, "EditBox", nil, f, "SearchBoxTemplate")
	if ok and search then
		search:SetSize(260, 22)
		search:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 4, 20)
		search:SetAutoFocus(false)
		search:SetMaxBytes(64)
		if search.Instructions then
			search.Instructions:SetText("Search this page")
		end
		search:HookScript("OnTextChanged", function(self)
			f.Content:SetFilter(self:GetText())
		end)
		search:HookScript("OnEditFocusLost", function(self)
			if self:GetText() == "" then
				f.Content:SetFilter(nil)
			end
		end)
		f.SearchBox = search
	end

	f:SetScript("OnShow", function()
		f.Content:RefreshRows()
		f.Content:LayoutRows()
		Gamepad.OnShow()
		startPreview()
	end)
	f:SetScript("OnHide", function()
		Theme.HideTooltip()
		-- the list and dialogs are parented to UIParent so they can sit above the window
		Panel.Popup.CloseAll()
		Gamepad.OnHide()
		stopPreview()
	end)

	return f
end

function Panel.EnsureBuilt()
	if frame then
		return frame
	end
	local ok, result = pcall(buildWindow)
	if not ok then
		print("|cffdb9e47DiabolusUnits:|r could not build the settings window (" .. tostring(result) .. ")")
		return nil
	end
	frame = result
	local pages = Spec.BuildPages()
	frame.pageList = pages
	frame.Sidebar:CreateButtons(pages)
	Gamepad.Init(frame)
	tinsert(UISpecialFrames, FRAME_NAME)
	frame.Sidebar:Select(pages[1])
	return frame
end

-- ── Open / close ──────────────────────────────────────────────────────────────

function Panel.GoToPage(pageID)
	if not frame or not frame.pageList or not pageID then
		return false
	end
	for _, page in ipairs(frame.pageList) do
		if page.id == pageID then
			frame.Sidebar:Select(page)
			return true
		end
	end
	return false
end

function Panel.Open(pageID)
	if InCombatLockdown() then
		print("|cffdb9e47DiabolusUnits:|r settings open after combat.")
		return
	end
	local f = Panel.EnsureBuilt()
	if not f then
		return
	end
	Panel.GoToPage(pageID)
	f:Show()
	f:Raise()
end

function Panel.Close()
	if frame then
		frame:Hide()
	end
end

function Panel.Toggle(pageID)
	if frame and frame:IsShown() then
		Panel.Close()
	else
		Panel.Open(pageID)
	end
end

function Panel.IsShown()
	return frame ~= nil and frame:IsShown()
end

local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:SetScript("OnEvent", Panel.Close)

-- ── Esc > Options > AddOns entry ──────────────────────────────────────────────

local function registerAddOnsEntry()
	if type(Settings) ~= "table" or type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
		return
	end
	local canvas = CreateFrame("Frame")
	canvas:Hide()

	local bg = canvas:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(Theme.COLOR_BG.r, Theme.COLOR_BG.g, Theme.COLOR_BG.b, 0.9)

	local skull = canvas:CreateTexture(nil, "ARTWORK")
	skull:SetSize(96, 96)
	skull:SetPoint("TOP", canvas, "TOP", 0, -60)
	skull:SetTexture(MEDIA .. "d2_skull")

	local title = canvas:CreateFontString(nil, "ARTWORK", Theme.HEADER_TITLE_FONT)
	title:SetPoint("TOP", skull, "BOTTOM", 0, -12)
	title:SetText("DiabolusUnits")

	local body = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	body:SetPoint("TOP", title, "BOTTOM", 0, -12)
	body:SetWidth(420)
	body:SetText("All settings are in the DiabolusUnits window.\nMinimap button, or type /diabolus.")
	body:SetTextColor(Theme.COLOR_TEXT_PRIMARY.r, Theme.COLOR_TEXT_PRIMARY.g, Theme.COLOR_TEXT_PRIMARY.b)

	local open = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	open:SetSize(220, 28)
	open:SetPoint("TOP", body, "BOTTOM", 0, -20)
	open:SetText("Open DiabolusUnits settings")
	Theme.StyleActionButton(open, true)
	open:SetScript("OnClick", function()
		Panel.Open()
	end)

	local category = Settings.RegisterCanvasLayoutCategory(canvas, "DiabolusUnits")
	Settings.RegisterAddOnCategory(category)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	registerAddOnsEntry()
end)
