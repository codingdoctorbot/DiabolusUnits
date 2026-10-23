-- Lazy settings window, ported from PulseHaptics UI/Panel.
-- Use plain Show()/Hide() with UISpecialFrames; the panel manager can invoke protected
-- gamepad binding calls. Use our local popups and close the window on combat start.
-- The Blizzard AddOns canvas opens this window above the existing settings panel.

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

-- Refresh

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

-- Orb preview
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

-- Window

local function addonVersion()
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local ok, version = pcall(get, ADDON_NAME, "Version")
	return (ok and version and version ~= "") and ("v" .. version) or ""
end

local function createWindow()
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

	Theme.CreateSurface(f, Theme.COLOR_BG)
	local top = f:CreateTexture(nil, "BACKGROUND", nil, -5)
	top:SetPoint("TOPLEFT", 1, -1)
	top:SetPoint("TOPRIGHT", -1, -1)
	top:SetHeight(46)
	top:SetColorTexture(0.085, 0.076, 0.065, 1)
	local side = f:CreateTexture(nil, "BACKGROUND", nil, -5)
	side:SetPoint("TOPLEFT", 1, -47)
	side:SetPoint("BOTTOMLEFT", 1, 40)
	side:SetWidth(Theme.SIDEBAR_WIDTH + 25)
	side:SetColorTexture(0.072, 0.065, 0.057, 1)
	local titleText = f:CreateFontString(nil, "OVERLAY", Theme.FONT_NORMAL)
	titleText:SetPoint("TOPLEFT", f, "TOPLEFT", 38, -17)
	titleText:SetText("DIABOLUS UNITS")
	titleText:SetTextColor(Theme.COLOR_TEXT_PRIMARY.r, Theme.COLOR_TEXT_PRIMARY.g, Theme.COLOR_TEXT_PRIMARY.b)
	local titleIcon = Theme.CreateIcon(f, "brand", 16)
	titleIcon:SetIconColor(Theme.COLOR_ACCENT)
	titleIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -15)
	local close = CreateFrame("Button", nil, f)
	close:SetSize(28, 26)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -10)
	Theme.StylePlainButton(close, "x")
	close:SetScript("OnClick", Panel.Close)
	f.ClosePanelButton = close

	-- Window transparency toggle (Ghost Mode) for live visual feedback
	local opacityBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	opacityBtn:SetSize(104, 24)
	opacityBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -126, 12)
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
			label = ("Opacity: %d%%"):format(math.floor(alpha * 100))
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
	closeButton:SetSize(96, 24)
	closeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
	closeButton:SetText(CLOSE or "Close")
	Theme.StyleActionButton(closeButton, false)
	closeButton:SetScript("OnClick", Panel.Close)

	local status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 18)
	status:SetJustifyH("LEFT")
	status:SetText(("DiabolusUnits %s  /diabolus"):format(addonVersion()))
	status:SetFontObject(Theme.FONT_CHILD)

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
	local ok, search = pcall(CreateFrame, "EditBox", nil, f)
	if ok and search then
		search:SetSize(230, 24)
		search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -54, -11)
		search:SetAutoFocus(false)
		search:SetMaxBytes(64)
		search:SetFontObject(Theme.FONT_NORMAL)
		search:SetTextInsets(10, 8, 0, 0)
		Theme.CreateSurface(search, Theme.COLOR_BG)
		search.Instructions = search:CreateFontString(nil, "OVERLAY", Theme.FONT_CHILD)
		search.Instructions:SetPoint("LEFT", search, "LEFT", 10, 0)
		search:SetScript("OnEscapePressed", function(self)
			self:SetText("")
			self:ClearFocus()
		end)
		if search.Instructions then
			search.Instructions:SetText("Search this page")
		end
		search:HookScript("OnTextChanged", function(self)
			self.Instructions:SetShown(self:GetText() == "")
			f.Content:SetFilter(self:GetText())
		end)
		search:HookScript("OnEditFocusLost", function(self)
			if self:GetText() == "" then
				f.Content:SetFilter(nil)
			end
		end)
		f.SearchBox = search
	end

	local hints = f:CreateFontString(nil, "OVERLAY", Theme.FONT_CHILD)
	hints:SetPoint("BOTTOM", f, "BOTTOM", 40, 18)
	hints:SetText("D-pad Move  A Select  B Back  X/Y Tabs  LB/RB Pages  LT/RT Scroll")
	f.ControllerHints = hints
	f:SetScript("OnShow", function()
		local w, h = UIParent:GetWidth(), UIParent:GetHeight()
		f:SetScale(math.min(1, (w - 24) / Theme.PANEL_WIDTH, (h - 24) / Theme.PANEL_HEIGHT))
		hints:SetShown(Gamepad.IsEnabled())
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

-- Open / close

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

-- Esc > Options > AddOns entry

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
