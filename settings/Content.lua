-- Lazy settings pages with permanent rows inside a plain ScrollFrame.
-- Page changes hide/show cached rows; search and section folding update their layout.
-- Geometry comes from Theme. Framework ported from PulseHaptics UI/Panel.

local _, ns = ...

local Panel = ns.UI.Panel
local Theme = Panel.Theme
local Rows = Panel.Rows

local Content = {}
Panel.Content = Content

local ContentMixin = {}

-- Construction

function Content.Create(parent)
	local frame = CreateFrame("Frame", nil, parent)
	Mixin(frame, ContentMixin)
	frame:SetAllPoints(parent)

	-- Header band: title on the left, divider underneath. Blizzard_SettingsList.xml:6-25.
	local header = CreateFrame("Frame", nil, frame)
	header:SetHeight(Theme.HEADER_HEIGHT)
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

	header.Title = header:CreateFontString(nil, "ARTWORK", Theme.HEADER_TITLE_FONT)
	header.Title:SetJustifyH("LEFT")
	header.Title:SetPoint("TOPLEFT", header, "TOPLEFT", Theme.HEADER_TITLE_X, Theme.HEADER_TITLE_Y)

	local divider = header:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(Theme.COLOR_BORDER.r, Theme.COLOR_BORDER.g, Theme.COLOR_BORDER.b, 1)
	divider:SetSize(1, 1)
	divider:SetPoint("LEFT", header, "LEFT", 8, 0)
	divider:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	divider:SetPoint("TOP", header, "TOP", 0, -Theme.HEADER_HEIGHT)
	header.Divider = divider

	header.Scope = header:CreateFontString(nil, "ARTWORK", Theme.FONT_CHILD)
	header.Scope:SetPoint("TOPRIGHT", header, "TOPRIGHT", -8, -12)
	frame.Header = header

	-- Subtab bar: for pages that declare `tabs`
	local tabBar = CreateFrame("Frame", nil, frame)
	tabBar:SetHeight(28)
	tabBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", Theme.HEADER_TITLE_X, 2)
	tabBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -Theme.HEADER_TITLE_X, 2)
	tabBar:Hide()
	frame.TabBar = tabBar
	local tabHint = frame:CreateFontString(nil, "ARTWORK", Theme.FONT_CHILD)
	tabHint:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -5)
	tabHint:Hide()
	frame.TabHint = tabHint
	frame.tabButtons = {}

	-- Scroll region.
	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", Theme.LIST_TOP_X, Theme.LIST_TOP_Y)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", Theme.LIST_BOTTOM_X, Theme.LIST_BOTTOM_Y)
	-- InitScrollFrameWithScrollBar installs an OnMouseWheel handler but does not enable
	-- the wheel; ScrollFrameTemplate normally does that in XML and this frame has no
	-- template.
	scroll:EnableMouseWheel(true)
	frame.Scroll = scroll

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	frame.Child = child

	-- Attach a MinimalScrollBar to the plain ScrollFrame when supported.
	local ok, bar = pcall(CreateFrame, "EventFrame", nil, frame, "MinimalScrollBar")
	if ok and bar then
		bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 0, -4)
		bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -1, 7)
		if ScrollUtil and type(ScrollUtil.InitScrollFrameWithScrollBar) == "function" then
			pcall(ScrollUtil.InitScrollFrameWithScrollBar, scroll, bar)
		end
		-- Hide the scrollbar when the page fits.
		if bar.SetHideIfUnscrollable then
			bar:SetHideIfUnscrollable(true)
		end
		frame.ScrollBar = bar
		Theme.MarkIgnored(bar)
	else
		-- No MinimalScrollBar: the mouse wheel still has to work.
		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local range = self:GetVerticalScrollRange() or 0
			local value = self:GetVerticalScroll() - (delta * 40)
			if value < 0 then
				value = 0
			elseif value > range then
				value = range
			end
			self:SetVerticalScroll(value)
		end)
	end

	scroll:SetScript("OnSizeChanged", function()
		frame:LayoutRows()
	end)

	frame.pages = {}
	frame.filter = nil

	return frame
end

-- Unit Frame Highlight

local highlightFrame = nil
local highlightTimer = nil
local function flashUnitFrame(targetFrame)
	if not targetFrame or not targetFrame:IsShown() then
		return
	end
	if not highlightFrame then
		highlightFrame = CreateFrame("Frame", nil, UIParent)
		highlightFrame:SetFrameStrata("DIALOG")
		local border = highlightFrame:CreateTexture(nil, "OVERLAY")
		border:SetAllPoints()
		border:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.8)
		highlightFrame.Border = border
	end
	if highlightTimer then
		highlightTimer:Cancel()
		highlightTimer = nil
	end
	highlightFrame:ClearAllPoints()
	highlightFrame:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", -3, 3)
	highlightFrame:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", 3, -3)
	highlightFrame:SetAlpha(0.9)
	highlightFrame:Show()

	local steps = 8
	local step = 0
	highlightTimer = C_Timer.NewTicker(0.08, function()
		step = step + 1
		local alpha = 0.9 * (1 - (step / steps))
		if highlightFrame and highlightFrame.SetAlpha then
			highlightFrame:SetAlpha(math.max(0, alpha))
		end
		if step >= steps then
			if highlightFrame then
				highlightFrame:Hide()
			end
			highlightTimer = nil
		end
	end, steps)
end

-- Page & Tab building

-- Builds one page's rows, once. `page.build` (UI/Panel/Spec.lua) returns a flat array of
-- row specs in render order, headers included.
function ContentMixin:EnsurePage(page)
	if page.rows then
		return page.rows
	end

	local rows = {}
	local skipped = 0
	local specs = page.build and page.build() or {}
	for _, spec in ipairs(specs) do
		local row = Rows.Create(self.Child, spec)
		if row then
			row:Hide()
			rows[#rows + 1] = row
		else
			skipped = skipped + 1
		end
	end
	page.rows = rows
	page.skippedRows = skipped
	return rows
end

function ContentMixin:EnsureTab(tab)
	if tab.rows then
		return tab.rows
	end

	local rows = {}
	local skipped = 0
	local specs = tab.build and tab.build() or {}
	for _, spec in ipairs(specs) do
		local row = Rows.Create(self.Child, spec)
		if row then
			row:Hide()
			rows[#rows + 1] = row
		else
			skipped = skipped + 1
		end
	end
	tab.rows = rows
	tab.skippedRows = skipped
	return rows
end

function ContentMixin:UpdateTabButtons()
	local page = self.page
	if not (page and page.tabs and #page.tabs > 0) then
		self.TabBar:Hide()
		return
	end

	self.TabBar:Show()
	local prevBtn = nil

	for i, tab in ipairs(page.tabs) do
		local btn = self.tabButtons[i]
		if not btn then
			btn = CreateFrame("Button", nil, self.TabBar)
			btn:SetHeight(24)

			local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -6)
			bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
			bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
			bg:SetColorTexture(Theme.COLOR_SURFACE.r, Theme.COLOR_SURFACE.g, Theme.COLOR_SURFACE.b, 0.95)
			btn.Bg = bg

			local border = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
			border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
			border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
			border:SetColorTexture(Theme.COLOR_BORDER.r, Theme.COLOR_BORDER.g, Theme.COLOR_BORDER.b, 0.8)
			btn.Border = border

			local line = btn:CreateTexture(nil, "OVERLAY")
			line:SetHeight(2)
			line:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
			line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
			line:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1)
			btn.ActiveLine = line

			local text = btn:CreateFontString(nil, "ARTWORK", Theme.FONT_NORMAL)
			text:SetPoint("CENTER", btn, "CENTER", 0, 1)
			btn.Text = text

			local hl = btn:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints(btn)
			hl:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.15)
			btn:SetHighlightTexture(hl)

			local content = self
			btn:SetScript("OnClick", function()
				if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
					PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
				elseif SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
					PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
				end
				content:SetTab(btn.tab)
			end)

			btn:SetScript("OnEnter", function()
				if not btn.selected then
					btn.Text:SetTextColor(
						Theme.COLOR_TEXT_PRIMARY.r,
						Theme.COLOR_TEXT_PRIMARY.g,
						Theme.COLOR_TEXT_PRIMARY.b
					)
					btn.Border:SetColorTexture(
						Theme.COLOR_ACCENT_DIM.r,
						Theme.COLOR_ACCENT_DIM.g,
						Theme.COLOR_ACCENT_DIM.b,
						0.8
					)
				end
			end)

			btn:SetScript("OnLeave", function()
				if not btn.selected then
					btn.Text:SetTextColor(Theme.COLOR_TEXT_MUTED.r, Theme.COLOR_TEXT_MUTED.g, Theme.COLOR_TEXT_MUTED.b)
					btn.Border:SetColorTexture(Theme.COLOR_BORDER.r, Theme.COLOR_BORDER.g, Theme.COLOR_BORDER.b, 0.8)
				end
			end)

			self.tabButtons[i] = btn
		end

		btn.tab = tab
		btn.Text:SetText(tab.label or "")
		local strWidth = btn.Text:GetStringWidth() or 60
		local btnWidth = math.max(74, math.floor(strWidth + 24))
		btn:SetSize(btnWidth, 24)

		btn:ClearAllPoints()
		if prevBtn then
			btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
		else
			btn:SetPoint("LEFT", self.TabBar, "LEFT", 0, 0)
		end
		btn:Show()
		prevBtn = btn
	end

	for j = #page.tabs + 1, #self.tabButtons do
		self.tabButtons[j]:Hide()
	end

	self:UpdateTabButtonStates()
end

function ContentMixin:UpdateTabButtonStates()
	for _, btn in ipairs(self.tabButtons) do
		if btn:IsShown() then
			local isSelected = (btn.tab == self.activeTab)
			btn.selected = isSelected
			if isSelected then
				btn.Text:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
				btn.Text:SetFontObject(Theme.FONT_NORMAL)
				btn.Border:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.95)
				btn.Bg:SetColorTexture(
					Theme.COLOR_SURFACE.r + 0.04,
					Theme.COLOR_SURFACE.g + 0.03,
					Theme.COLOR_SURFACE.b + 0.02,
					1
				)
				btn.ActiveLine:Show()
			else
				btn.Text:SetTextColor(Theme.COLOR_TEXT_MUTED.r, Theme.COLOR_TEXT_MUTED.g, Theme.COLOR_TEXT_MUTED.b)
				btn.Text:SetFontObject(Theme.FONT_NORMAL)
				btn.Border:SetColorTexture(Theme.COLOR_BORDER.r, Theme.COLOR_BORDER.g, Theme.COLOR_BORDER.b, 0.8)
				btn.Bg:SetColorTexture(Theme.COLOR_SURFACE.r, Theme.COLOR_SURFACE.g, Theme.COLOR_SURFACE.b, 0.85)
				btn.ActiveLine:Hide()
			end
		end
	end
end

function ContentMixin:SetTab(tab)
	if not tab or (self.activeTab == tab and tab.rows) then
		return
	end

	if self.activeTab and self.activeTab.rows then
		for _, row in ipairs(self.activeTab.rows) do
			row:Hide()
		end
	end

	self.activeTab = tab
	if self.page then
		self.page.activeTabId = tab.id
	end

	self:EnsureTab(tab)
	self:RefreshRows()

	self.Scroll:SetVerticalScroll(0)
	self:LayoutRows()

	self:UpdateTabButtonStates()
	Panel.Gamepad.RefreshNavigation()

	-- Highlight corresponding frame in game if available
	if tab.frameName then
		local f = rawget(_G, tab.frameName)
		if f then
			flashUnitFrame(f)
		end
	end
end

function ContentMixin:GetActiveRows()
	if self.page and self.page.tabs and #self.page.tabs > 0 and self.activeTab then
		return self.activeTab.rows or {}
	elseif self.page then
		return self.page.rows or {}
	end
	return {}
end

-- Showing a page

function ContentMixin:SetPage(page)
	if self.page == page then
		return
	end

	if self.page then
		if self.page.tabs and self.activeTab and self.activeTab.rows then
			for _, row in ipairs(self.activeTab.rows) do
				row:Hide()
			end
		elseif self.page.rows then
			for _, row in ipairs(self.page.rows) do
				row:Hide()
			end
		end
	end

	self.page = page
	self.activeTab = nil
	self.Header.Title:SetText(page and page.label or "")

	if page and page.tabs and #page.tabs > 0 then
		self.Header.Divider:ClearAllPoints()
		self.Header.Divider:SetPoint("TOP", self.TabBar, "BOTTOM", 0, -2)
		self.Scroll:ClearAllPoints()
		self.Scroll:SetPoint("TOPLEFT", self.TabBar, "BOTTOMLEFT", Theme.LIST_TOP_X, -27)
		self.Scroll:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", Theme.LIST_BOTTOM_X, Theme.LIST_BOTTOM_Y)

		self:UpdateTabButtons()

		local targetTab = page.tabs[1]
		if page.activeTabId then
			for _, t in ipairs(page.tabs) do
				if t.id == page.activeTabId then
					targetTab = t
					break
				end
			end
		end
		self:SetTab(targetTab)
	else
		self.TabBar:Hide()
		self.TabHint:Hide()
		self.Header.Divider:ClearAllPoints()
		self.Header.Divider:SetPoint("TOP", self.Header, "TOP", 0, -Theme.HEADER_HEIGHT)
		self.Scroll:ClearAllPoints()
		self.Scroll:SetPoint("TOPLEFT", self.Header, "BOTTOMLEFT", Theme.LIST_TOP_X, Theme.LIST_TOP_Y)
		self.Scroll:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", Theme.LIST_BOTTOM_X, Theme.LIST_BOTTOM_Y)

		if page then
			self:EnsurePage(page)
			self:RefreshRows()
		end

		self.Scroll:SetVerticalScroll(0)
		self:LayoutRows()
		Panel.Gamepad.RefreshNavigation()
	end
end

-- Filtering

-- Search only the active page; unopened pages remain unbuilt.
function ContentMixin:SetFilter(text)
	text = text and string.lower(strtrim(text)) or ""
	if text == "" then
		text = nil
	end
	if self.filter == text then
		return
	end
	self.filter = text
	self:LayoutRows()
	Panel.Gamepad.RefreshNavigation()
end

-- Combine visibleWhen, search, and section folding. Search reveals matches in folded
-- sections, while visibleWhen remains authoritative.
local function sectionFolded(key)
	return key ~= nil and Panel.IsSectionCollapsed ~= nil and Panel.IsSectionCollapsed(key)
end

local function rowVisible(row, filter)
	local spec = row.spec
	if spec and spec.visibleWhen and not spec.visibleWhen() then
		return false
	end
	if not filter then
		return not (spec and spec.sectionKey and not row.isSectionHeader and sectionFolded(spec.sectionKey))
	end
	if row.isHeader then
		return false
	end -- decided by its section, below
	return row.searchText and string.find(row.searchText, filter, 1, true) ~= nil
end

-- Layout

function ContentMixin:LayoutRows()
	local scope = ""
	if self.page then
		if self.page.id == "layout" then
			scope = "Keyboard defaults"
		elseif self.page.id == "gamepad" then
			scope = "Gamepad defaults"
		elseif self.page.id == "unitframes" then
			scope = ns.StandardMode and ns.StandardMode:IsGamepad() and "Sizes: gamepad layout"
				or "Sizes: keyboard layout"
		end
	end
	self.Header.Scope:SetText(scope)
	local rows = self:GetActiveRows()
	if not self.page or #rows == 0 then
		return
	end

	local width = self.Scroll:GetWidth()
	if not width or width <= 0 then
		return
	end
	self.Child:SetWidth(width)

	local filter = self.filter

	-- First pass: visibility. A section header shows only if something under it survived
	-- the filter, so a filtered page never shows a heading over nothing.
	local shown = {}
	local lastHeaderIndex = nil
	local headerHasContent = false
	for index, row in ipairs(rows) do
		if row.isHeader then
			if lastHeaderIndex and not headerHasContent then
				shown[lastHeaderIndex] = false
			end
			lastHeaderIndex = index
			-- A folded section keeps its heading (it is how you unfold it) unless a search
			-- is running, when headings follow their visible rows as before.
			headerHasContent = (row.isSectionHeader and not filter and sectionFolded(row.sectionKey)) or false
			shown[index] = true
		else
			local visible = rowVisible(row, filter)
			shown[index] = visible
			if visible then
				headerHasContent = true
			end
		end
	end
	if lastHeaderIndex and not headerHasContent then
		shown[lastHeaderIndex] = false
	end

	-- Second pass: place what is left.
	local y = Theme.LIST_VERTICAL_PAD
	local first = true
	for index, row in ipairs(rows) do
		if shown[index] then
			if not first then
				y = y + Theme.LIST_SPACING
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", self.Child, "TOPLEFT", Theme.LIST_PAD_LEFT, -y)
			if row.MeasureHeight then
				-- Width from SetWidth rather than from a second anchor, so the wrapped
				-- text has a resolved width to be measured against in this same pass.
				row:SetWidth(width - Theme.LIST_PAD_LEFT)
				row:MeasureHeight()
			else
				row:SetPoint("RIGHT", self.Child, "RIGHT", Theme.LIST_PAD_RIGHT, 0)
			end
			row:Show()
			y = y + (row.rowHeight or Theme.ROW_HEIGHT)
			first = false
		else
			row:Hide()
		end
	end

	local childHeight = math.max(y + Theme.LIST_VERTICAL_PAD, 1)
	self.Child:SetHeight(childHeight)

	-- Folding a section above the viewport shortens the child under the current scroll
	-- offset. Clamp from the heights just set rather than GetVerticalScrollRange, which
	-- only catches up after the scroll frame's next layout pass.
	local viewHeight = self.Scroll:GetHeight() or 0
	local maxScroll = math.max(0, childHeight - viewHeight)
	if (self.Scroll:GetVerticalScroll() or 0) > maxScroll then
		self.Scroll:SetVerticalScroll(maxScroll)
	end
end

-- Refresh

-- Re-reads every row on the page in view and re-evaluates its dependency. Driven by a dirty
-- flag rather than per change, so a profile switch — which notifies every cue and every
-- tunable listener at once — costs one pass, not several hundred.
function ContentMixin:RefreshRows()
	local rows = self:GetActiveRows()
	if not self.page or #rows == 0 then
		return
	end

	local navigationChanged = false
	for _, row in ipairs(rows) do
		if row.RefreshValue then
			row:RefreshValue()
		end

		local spec = row.spec
		if spec and spec.enabledWhen and row.SetRowEnabled then
			local enabled = spec.enabledWhen() and true or false
			if row.lastEnabled ~= enabled then
				row.lastEnabled = enabled
				row:SetRowEnabled(enabled)
				navigationChanged = true
			end
		end
	end

	if navigationChanged then
		-- A greyed row is marked ignored by SmartNavigation, so the set of things the
		-- stick can reach just changed and has to be rebuilt.
		Panel.Gamepad.RefreshNavigation()
	end
end
