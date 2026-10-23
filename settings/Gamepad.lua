-- Settings controller navigation, ported from PulseHaptics UI/Panel/Gamepad.lua.
-- Focus moves through categories, subpage tabs, and rows; Left/B backs up one level.
-- Bumpers change categories, triggers scroll, PAD3/PAD4 change subpages.
-- The visible window receives button input; closing it releases capture state.

local _, ns = ...

local Panel = ns.UI.Panel
local Theme = Panel.Theme

local Gamepad = {}
Panel.Gamepad = Gamepad

local panel -- the settings window
local nativeInputActive = false
local focusBox -- visual focus reticle
local mode = "SIDEBAR" -- "SIDEBAR", "TABS" or "CONTENT"
local currentSidebarIndex = 1
local currentContentIndex = 1
local focusedRow = nil

function Gamepad.IsEnabled()
	if ns.StandardMode then
		return ns.StandardMode:IsGamepad()
	end
	local input = _G.InputUtil
	return input and input.IsGamepadUIEnabled and input.IsGamepadUIEnabled() or false
end

-- Visual Focus Reticle

local function getFocusBox(parent)
	if focusBox then
		return focusBox
	end

	local fb = CreateFrame("Frame", nil, parent)
	fb:SetFrameStrata("DIALOG")
	fb:SetFrameLevel((parent:GetFrameLevel() or 10) + 15)

	-- Thin controller-focus outline, distinct from the selected bronze tab.
	local bTop = fb:CreateTexture(nil, "OVERLAY")
	bTop:SetPoint("TOPLEFT", fb, "TOPLEFT", 0, 0)
	bTop:SetPoint("TOPRIGHT", fb, "TOPRIGHT", 0, 0)
	bTop:SetHeight(1)
	bTop:SetColorTexture(Theme.COLOR_FOCUS.r, Theme.COLOR_FOCUS.g, Theme.COLOR_FOCUS.b, 1.0)
	fb.bTop = bTop

	local bBottom = fb:CreateTexture(nil, "OVERLAY")
	bBottom:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 0, 0)
	bBottom:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", 0, 0)
	bBottom:SetHeight(1)
	bBottom:SetColorTexture(Theme.COLOR_FOCUS.r, Theme.COLOR_FOCUS.g, Theme.COLOR_FOCUS.b, 1.0)
	fb.bBottom = bBottom

	local bLeft = fb:CreateTexture(nil, "OVERLAY")
	bLeft:SetPoint("TOPLEFT", fb, "TOPLEFT", 0, 0)
	bLeft:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 0, 0)
	bLeft:SetWidth(1)
	bLeft:SetColorTexture(Theme.COLOR_FOCUS.r, Theme.COLOR_FOCUS.g, Theme.COLOR_FOCUS.b, 1.0)
	fb.bLeft = bLeft

	local bRight = fb:CreateTexture(nil, "OVERLAY")
	bRight:SetPoint("TOPRIGHT", fb, "TOPRIGHT", 0, 0)
	bRight:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", 0, 0)
	bRight:SetWidth(1)
	bRight:SetColorTexture(Theme.COLOR_FOCUS.r, Theme.COLOR_FOCUS.g, Theme.COLOR_FOCUS.b, 1.0)
	fb.bRight = bRight

	-- Small focus marker on the left edge.
	local accent = fb:CreateTexture(nil, "OVERLAY")
	accent:SetPoint("TOPLEFT", fb, "TOPLEFT", 0, 0)
	accent:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 0, 0)
	accent:SetWidth(2)
	accent:SetColorTexture(Theme.COLOR_FOCUS.r, Theme.COLOR_FOCUS.g, Theme.COLOR_FOCUS.b, 1.0)
	fb.accent = accent

	-- Faint fill inside the focus outline.
	local inner = fb:CreateTexture(nil, "BACKGROUND")
	inner:SetPoint("TOPLEFT", fb, "TOPLEFT", 2, -2)
	inner:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", -2, 2)
	inner:SetColorTexture(Theme.COLOR_FOCUS.r, Theme.COLOR_FOCUS.g, Theme.COLOR_FOCUS.b, 0.05)
	fb.inner = inner

	fb:Hide()
	focusBox = fb
	return fb
end

local function highlightWidget(widget, insetX, insetY)
	if not widget or not widget:IsShown() then
		if focusBox then
			focusBox:Hide()
		end
		return
	end

	local fb = getFocusBox(panel)
	fb:ClearAllPoints()
	fb:SetPoint("TOPLEFT", widget, "TOPLEFT", -(insetX or 2), insetY or 2)
	fb:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", insetX or 2, -(insetY or 2))
	fb:Show()
end

-- Content Row Navigation

local function getVisibleRows()
	local rows = {}
	if not panel or not panel.Content or not panel.Content.page then
		return rows
	end
	local pageRows = panel.Content:GetActiveRows()
	if not pageRows then
		return rows
	end

	for _, row in ipairs(pageRows) do
		if row:IsShown() and not row.isHeader and not row.isText and row.lastEnabled ~= false then
			rows[#rows + 1] = row
		end
	end
	return rows
end

local function ensureRowVisible(row)
	if not row or not panel or not panel.Content or not panel.Content.Scroll then
		return
	end

	local scroll = panel.Content.Scroll
	local scrollChild = panel.Content.Child
	if not scrollChild then
		return
	end

	local rowTop = row:GetTop()
	local rowBottom = row:GetBottom()
	local scrollTop = scroll:GetTop()
	local scrollBottom = scroll:GetBottom()

	if not rowTop or not rowBottom or not scrollTop or not scrollBottom then
		return
	end

	local curScroll = scroll:GetVerticalScroll() or 0
	local maxScroll = scroll:GetVerticalScrollRange() or 0

	if rowTop > scrollTop then
		-- Row is above visible view: scroll up
		local diff = rowTop - scrollTop + 10
		local target = math.max(0, curScroll - diff)
		scroll:SetVerticalScroll(target)
	elseif rowBottom < scrollBottom then
		-- Row is below visible view: scroll down
		local diff = scrollBottom - rowBottom + 10
		local target = math.min(maxScroll, curScroll + diff)
		scroll:SetVerticalScroll(target)
	end
end

local function setContentFocus(index)
	local rows = getVisibleRows()
	if #rows == 0 then
		focusedRow = nil
		if focusBox then
			focusBox:Hide()
		end
		return
	end

	if index < 1 then
		index = 1
	elseif index > #rows then
		index = #rows
	end

	currentContentIndex = index

	if focusedRow and focusedRow.HideRowTooltip then
		focusedRow:HideRowTooltip()
	end

	local row = rows[index]
	focusedRow = row

	if row then
		if row.ShowRowTooltip then
			row:ShowRowTooltip()
		end
		highlightWidget(row, 2, 2)
		ensureRowVisible(row)
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		end
	end
end

-- Subpage navigation
local function getTabs()
	local content = panel and panel.Content
	return content and content.page and content.page.tabs
end
local function activeTabIndex()
	local tabs = getTabs() or {}
	for i, tab in ipairs(tabs) do
		if tab == panel.Content.activeTab then
			return i
		end
	end
	return 1
end
local function hasTabs()
	local tabs = getTabs()
	return tabs and #tabs > 0
end
local function highlightTab()
	local button = panel.Content.tabButtons[activeTabIndex()]
	if button then
		highlightWidget(button, 2, 2)
	end
end
local function setTabFocus(index)
	local tabs = getTabs()
	if not tabs or #tabs == 0 then
		return
	end
	if focusedRow and focusedRow.HideRowTooltip then
		focusedRow:HideRowTooltip()
	end
	focusedRow = nil
	mode = "TABS"
	index = (index - 1) % #tabs + 1
	panel.Content:SetTab(tabs[index])
	highlightTab()
	if Gamepad.UpdateHints then
		Gamepad.UpdateHints()
	end
end
local function enterContent()
	if hasTabs() then
		setTabFocus(activeTabIndex())
	else
		mode = "CONTENT"
		setContentFocus(1)
	end
end

-- Sidebar Navigation

local function getSidebarButtons()
	if not panel or not panel.Sidebar or not panel.Sidebar.buttons then
		return {}
	end
	local btns = {}
	for _, b in ipairs(panel.Sidebar.buttons) do
		if b:IsShown() then
			btns[#btns + 1] = b
		end
	end
	return btns
end

local function selectSidebarIndex(index, enterContent)
	local buttons = getSidebarButtons()
	if #buttons == 0 then
		return
	end

	if index < 1 then
		index = #buttons
	elseif index > #buttons then
		index = 1
	end

	currentSidebarIndex = index
	local btn = buttons[index]

	if btn and btn.page then
		panel.Sidebar:Select(btn.page)
		if enterContent then
			enterContent()
		else
			mode = "SIDEBAR"
			if focusedRow and focusedRow.HideRowTooltip then
				focusedRow:HideRowTooltip()
				focusedRow = nil
			end
			highlightWidget(btn, 0, 0)
		end
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
	end
end

-- Input Dispatcher

local function scrollContent(delta)
	if not panel or not panel.Content or not panel.Content.Scroll then
		return
	end
	local scroll = panel.Content.Scroll
	local cur = scroll:GetVerticalScroll() or 0
	local maxRange = scroll:GetVerticalScrollRange() or 0
	local target = math.max(0, math.min(maxRange, cur + delta))
	scroll:SetVerticalScroll(target)
end

local function handleInput(key)
	if InCombatLockdown and InCombatLockdown() then
		Panel.Close()
		return
	end

	if Panel.Popup.HandleGamepad and Panel.Popup.HandleGamepad(key) then
		return
	end
	if key == "PAD3" or key == "PAD4" then
		if hasTabs() then
			local keepContent = mode == "CONTENT"
			setTabFocus(activeTabIndex() + (key == "PAD3" and -1 or 1))
			if keepContent then
				mode = "CONTENT"
				setContentFocus(1)
			end
		end
		return
	end
	-- Global Bumpers: Tab categories forward/backward
	if key == "PADLSHOULDER" then
		selectSidebarIndex(currentSidebarIndex - 1, mode == "CONTENT")
		return
	elseif key == "PADRSHOULDER" then
		selectSidebarIndex(currentSidebarIndex + 1, mode == "CONTENT")
		return
	end

	-- Global Triggers: Scroll content
	if key == "PADLTRIGGER" then
		scrollContent(-120)
		return
	elseif key == "PADRTRIGGER" then
		scrollContent(120)
		return
	end

	-- Select / View closes the window from anywhere
	if key == "PADBACK" then
		Panel.Close()
		return
	end

	if mode == "SIDEBAR" then
		if key == "PADDUP" then
			selectSidebarIndex(currentSidebarIndex - 1, false)
		elseif key == "PADDDOWN" then
			selectSidebarIndex(currentSidebarIndex + 1, false)
		elseif key == "PADDRIGHT" or key == "PAD1" then
			-- Unit frames enter the subpage strip before the settings below it.
			enterContent()
		elseif key == "PAD2" or key == "PADFORWARD" then
			Panel.Close()
		end
	elseif mode == "TABS" then
		if key == "PADDLEFT" then
			setTabFocus(activeTabIndex() - 1)
		elseif key == "PADDRIGHT" then
			setTabFocus(activeTabIndex() + 1)
		elseif key == "PAD1" or key == "PADDDOWN" then
			mode = "CONTENT"
			setContentFocus(1)
		elseif key == "PAD2" or key == "PADDUP" then
			selectSidebarIndex(currentSidebarIndex, false)
		elseif key == "PADFORWARD" then
			Panel.Close()
		end
	elseif mode == "CONTENT" then
		local rows = getVisibleRows()
		local row = rows[currentContentIndex]

		if key == "PADDUP" then
			if currentContentIndex == 1 and hasTabs() then
				setTabFocus(activeTabIndex())
			else
				setContentFocus(currentContentIndex - 1)
			end
		elseif key == "PADDDOWN" then
			setContentFocus(currentContentIndex + 1)
		elseif key == "PADDLEFT" then
			-- Step a slider down; otherwise return to tabs or categories.
			if row and row.Control and row.Control.OnStepperClicked then
				row.Control:OnStepperClicked(false)
			elseif row and row.Control and (row.Control.DecrementButton or row.Control.Decrement) then
				if row.Control.DecrementButton then
					row.Control.DecrementButton:Click()
				else
					row.Control:Decrement()
				end
			else
				if hasTabs() then
					setTabFocus(activeTabIndex())
				else
					selectSidebarIndex(currentSidebarIndex, false)
				end
			end
		elseif key == "PADDRIGHT" then
			-- If on a slider or dropdown, step up
			if row and row.Control and row.Control.OnStepperClicked then
				row.Control:OnStepperClicked(true)
			elseif row and row.Control and (row.Control.IncrementButton or row.Control.Increment) then
				if row.Control.IncrementButton then
					row.Control.IncrementButton:Click()
				else
					row.Control:Increment()
				end
			end
		elseif key == "PAD1" then
			-- A button: Activate the control
			if row then
				if row.Dropdown then
					row.Dropdown:Click()
				elseif row.Control and row.Control:IsObjectType("CheckButton") then
					row.Control:Click()
				elseif row.Button and row.Button:IsObjectType("Button") then
					row.Button:Click()
				elseif row.Control and row.Control:IsObjectType("Button") then
					row.Control:Click()
				end
			end
		elseif key == "PAD2" then
			if hasTabs() then
				setTabFocus(activeTabIndex())
			else
				selectSidebarIndex(currentSidebarIndex, false)
			end
		elseif key == "PADFORWARD" then
			Panel.Close()
		end
	end
end

-- Bindings & Lifecycle

-- Input comes directly from the visible window. Capturing PAD keys with hidden
-- click targets prevented the native handler from receiving input on this client.
local function releaseCaptureKeys(owner)
	if ClearOverrideBindings then
		pcall(ClearOverrideBindings, owner)
	end
end

function Gamepad.OnShow()
	if not panel or not panel:IsShown() then
		return
	end

	mode = "SIDEBAR"
	Gamepad.SyncPage(panel.Sidebar.selectedPage)
	currentContentIndex = 1
	focusedRow = nil

	-- Hook native gamepad button events on the frame
	if panel.EnableGamePadButton then
		pcall(panel.EnableGamePadButton, panel, true)
	end

	releaseCaptureKeys(panel)
	nativeInputActive = Gamepad.IsEnabled()
	panel:SetScript("OnGamePadButtonDown", function(_, key)
		nativeInputActive = true
		handleInput(key)
		Gamepad.UpdateHints()
	end)
	if nativeInputActive then
		selectSidebarIndex(currentSidebarIndex, false)
	elseif focusBox then
		focusBox:Hide()
	end
	Gamepad.UpdateHints()
end

function Gamepad.OnHide()
	nativeInputActive = false
	if focusBox then
		focusBox:Hide()
	end
	if focusedRow and focusedRow.HideRowTooltip then
		focusedRow:HideRowTooltip()
		focusedRow = nil
	end
	if panel then
		releaseCaptureKeys(panel)
	end
end

function Gamepad.RefreshNavigation()
	if mode == "CONTENT" then
		setContentFocus(currentContentIndex)
	elseif mode == "TABS" and hasTabs() then
		highlightTab()
	end
	Gamepad.UpdateHints()
end

function Gamepad.Setup() end

-- Rows call these when SmartNavigation itself selects them; this window drives its own
-- focus (handleInput above), so there is nothing extra to do.
function Gamepad.OnSliderSelected() end
function Gamepad.OnSliderDeselected() end
function Gamepad.OnDropdownSelected() end
function Gamepad.OnDropdownDeselected() end

function Gamepad.Init(owner)
	panel = owner
end

function Gamepad.OnPointer()
	if focusBox then
		focusBox:Hide()
	end
end
function Gamepad.SyncPage(page)
	-- Mouse category selection must also leave the old tab/content focus context.
	if focusedRow and focusedRow.HideRowTooltip then
		focusedRow:HideRowTooltip()
	end
	focusedRow = nil
	mode = "SIDEBAR"
	for index, button in ipairs(getSidebarButtons()) do
		if button.page == page then
			currentSidebarIndex = index
			break
		end
	end
end

function Gamepad.UpdateHints()
	if not panel then
		return
	end
	local enabled = Gamepad.IsEnabled() or nativeInputActive
	if panel.ControllerHints then
		panel.ControllerHints:SetShown(enabled)
		if mode == "TABS" and hasTabs() then
			panel.ControllerHints:SetText("Left/Right Subpage   A Edit   B Categories   X/Y Subpages")
		elseif mode == "CONTENT" and hasTabs() then
			panel.ControllerHints:SetText("D-pad Edit   A Select   B Subpages   X/Y Subpages   LT/RT Scroll")
		else
			panel.ControllerHints:SetText("D-pad Move   A Open   B Back   LB/RB Categories   LT/RT Scroll")
		end
	end
	local content = panel.Content
	if content and content.TabHint then
		content.TabHint:SetShown(enabled and hasTabs() and true or false)
		if mode == "TABS" then
			content.TabHint:SetText("Left / Right: subpage     A / Down: edit settings     B / Up: categories")
		else
			content.TabHint:SetText("X / Y (Square / Triangle): subpage     Up from the first setting returns to tabs")
		end
	end
end
