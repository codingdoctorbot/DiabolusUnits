-- Local dropdowns and dialogs, ported from PulseHaptics UI/Panel/Popup.lua.
-- Avoid Blizzard Menu/StaticPopup activation here: their protected gamepad binding
-- calls have caused blocked-action popup loops on Forever. Use our own popup frames.

local ADDON_NAME, ns = ...

local Panel = ns.UI.Panel
local Theme = Panel.Theme

local Popup = {}
Panel.Popup = Popup

local ENTRY_HEIGHT = 26
local LIST_PADDING = 8
local ENTRY_INSET = 5 -- entries stop short of the border on both sides
local TEXT_INSET = 12
local LIST_MAX_ROWS = 12 -- a whole number of rows, so nothing is ever half-cut
local LIST_MIN_WIDTH = 140
local LIST_MAX_WIDTH = 340
local DIALOG_WIDTH = 400

-- Above the settings window, which is DIALOG — and that in turn is above Blizzard's own
-- settings window at HIGH, since the splash page can open ours while theirs is still up.
local OVERLAY_STRATA = "FULLSCREEN_DIALOG"

-- Opaque themed surface for popup lists and dialogs.
local function backdropFrame(parent, name)
	local frame = CreateFrame("Frame", name, parent)
	Theme.CreateSurface(frame, Theme.COLOR_BG)
	return frame
end

-- Dropdown list

local list -- the popup itself
local listCatcher -- full-screen click-away catcher behind it
local entries = {} -- reused entry buttons, index-keyed
local listState = {}

local function closeList()
	if listCatcher then
		listCatcher:Hide()
	end
	listState.onSelect = nil
	listState.owner = nil
	listState.previewScale = nil
end

function Popup.CloseList()
	closeList()
end

function Popup.IsListOpen()
	return listCatcher ~= nil and listCatcher:IsShown()
end

local function ensureList()
	if list then
		return
	end

	-- Parent the list to the full-screen catcher so outside clicks close it.
	listCatcher = CreateFrame("Button", nil, UIParent)
	listCatcher:SetAllPoints(UIParent)
	listCatcher:SetFrameStrata(OVERLAY_STRATA)
	listCatcher:Hide()
	listCatcher:SetScript("OnClick", closeList)
	Theme.MarkIgnored(listCatcher)

	list = backdropFrame(listCatcher, nil)
	list:SetFrameLevel(listCatcher:GetFrameLevel() + 10)
	list:EnableMouse(true)

	local scroll = CreateFrame("ScrollFrame", nil, list)
	scroll:SetPoint("TOPLEFT", list, "TOPLEFT", ENTRY_INSET, -LIST_PADDING)
	scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -ENTRY_INSET, LIST_PADDING)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange() or 0
		local value = self:GetVerticalScroll() - (delta * ENTRY_HEIGHT * 2)
		if value < 0 then
			value = 0
		elseif value > range then
			value = range
		end
		self:SetVerticalScroll(value)
	end)
	list.Scroll = scroll

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	list.Child = child

	-- The same plain-ScrollFrame plumbing Content.lua uses, unprotected for the same
	-- reason. Without it a list longer than the cap just stopped, with no sign of more.
	local okBar, bar = pcall(CreateFrame, "EventFrame", nil, list, "MinimalScrollBar")
	if okBar and bar then
		bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", -2, 0)
		bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -2, 0)
		if ScrollUtil and type(ScrollUtil.InitScrollFrameWithScrollBar) == "function" then
			pcall(ScrollUtil.InitScrollFrameWithScrollBar, scroll, bar)
		end
		Theme.MarkIgnored(bar)
		list.ScrollBar = bar
	end
end

local headers = {}
local dividers = {}

local function acquireHeader(index)
	local header = headers[index]
	if header then
		return header
	end

	header = CreateFrame("Frame", nil, list.Child)
	header:SetHeight(ENTRY_HEIGHT)

	header.Text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	header.Text:SetJustifyH("LEFT")
	header.Text:SetWordWrap(false)
	header.Text:SetPoint("LEFT", header, "LEFT", 8, 0)
	header.Text:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	header.Text:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)

	header.Line = header:CreateTexture(nil, "ARTWORK")
	header.Line:SetHeight(1)
	header.Line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 4, 0)
	header.Line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -4, 0)
	header.Line:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.40)

	Theme.MarkIgnored(header)
	headers[index] = header
	return header
end

local function acquireDivider(index)
	local div = dividers[index]
	if div then
		return div
	end

	div = list.Child:CreateTexture(nil, "BACKGROUND")
	div:SetWidth(1)
	div:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.20)
	dividers[index] = div
	return div
end

-- Entry buttons are reused across opens — safe here in a way row frames are not: nothing
-- outside this file holds one, they are marked out of gamepad navigation, and their click
-- closure is replaced on every open rather than left pointing at the last menu.
local function acquireEntry(index)
	local entry = entries[index]
	if entry then
		return entry
	end

	entry = CreateFrame("Button", nil, list.Child)
	entry:SetHeight(ENTRY_HEIGHT)

	-- A filled bar behind the selected row with subtle cyan accent tint
	entry.Selected = entry:CreateTexture(nil, "ARTWORK")
	entry.Selected:SetAllPoints(entry)
	entry.Selected:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.20)
	entry.Selected:Hide()

	entry.Highlight = entry:CreateTexture(nil, "HIGHLIGHT")
	entry.Highlight:SetAllPoints(entry)
	entry.Highlight:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.10)

	entry.Text = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	entry.Text:SetJustifyH("LEFT")
	entry.Text:SetWordWrap(false)
	entry.Text:SetPoint("LEFT", entry, "LEFT", TEXT_INSET, 0)
	entry.Text:SetPoint("RIGHT", entry, "RIGHT", -8, 0)

	entry:SetScript("OnEnter", function(self)
		if self.tooltip then
			Theme.ShowTooltip(self, self.label, self.tooltip)
		end
	end)
	entry:SetScript("OnLeave", Theme.HideTooltip)
	entry:SetScript("OnClick", function(self)
		local handler = listState.onSelect
		closeList()
		if handler then
			handler(self.value)
		end
	end)

	Theme.MarkIgnored(entry)
	entries[index] = entry
	return entry
end

local function positionList(owner, width, height, numCols)
	list:ClearAllPoints()
	local ownerBottom = (owner.GetBottom and owner:GetBottom()) or 0
	local ownerTop = (owner.GetTop and owner:GetTop()) or 0
	local ownerLeft = (owner.GetLeft and owner:GetLeft()) or 0
	local ownerRight = (owner.GetRight and owner:GetRight()) or 0
	local uiHeight = (UIParent.GetHeight and UIParent:GetHeight()) or 768
	local uiWidth = (UIParent.GetWidth and UIParent:GetWidth()) or 1024

	local openUpwards = (ownerBottom - height < 30) and (uiHeight - ownerTop > ownerBottom)

	if numCols > 1 then
		local anchorV = openUpwards and "BOTTOM" or "TOP"
		local targetV = openUpwards and "TOP" or "BOTTOM"
		local yOffset = openUpwards and 4 or -4

		local expectedLeft = ownerRight - width
		if expectedLeft >= 10 then
			list:SetPoint(anchorV .. "RIGHT", owner, targetV .. "RIGHT", 0, yOffset)
		else
			list:SetPoint(anchorV .. "LEFT", owner, targetV .. "LEFT", 0, yOffset)
		end
	else
		local anchorV = openUpwards and "BOTTOM" or "TOP"
		local targetV = openUpwards and "TOP" or "BOTTOM"
		local yOffset = openUpwards and 4 or -4

		local expectedRight = ownerLeft + width
		if expectedRight <= (uiWidth - 10) then
			list:SetPoint(anchorV .. "LEFT", owner, targetV .. "LEFT", 0, yOffset)
		else
			list:SetPoint(anchorV .. "RIGHT", owner, targetV .. "RIGHT", 0, yOffset)
		end
	end
end

-- options: array of { value, label, tooltip, category? }.
-- Automatically expands into a zero-scroll 3-Column Categorized Palette when options
-- contain categories or exceed 8 items.
function Popup.OpenList(owner, options, selectedValue, onSelect, previewScale)
	ensureList()

	if listState.owner == owner and listCatcher:IsShown() then
		closeList()
		return
	end

	listState.owner = owner
	listState.onSelect = onSelect
	listState.previewScale = previewScale
	listState.selectedValue = selectedValue
	listState.focus = nil

	local hasCategories = false
	for _, opt in ipairs(options) do
		if opt.category then
			hasCategories = true
			break
		end
	end

	local numCols = 1
	if hasCategories then
		numCols = 3
	elseif #options > 16 then
		numCols = 3
	elseif #options > 8 then
		numCols = 2
	end

	if numCols == 1 then
		local shown = 0
		local widest = 0

		for index, option in ipairs(options) do
			local entry = acquireEntry(index)
			entry.value = option.value
			entry.label = option.label
			entry.tooltip = option.tooltip
			local selected = (option.value == selectedValue)
			entry.Selected:SetShown(selected)
			if selected then
				entry.Text:SetText("|cffdb9e47> |r" .. (option.label or tostring(option.value)))
				entry.Text:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
			else
				entry.Text:SetText("   " .. (option.label or tostring(option.value)))
				local c = Theme.COLOR_TEXT_PRIMARY
				entry.Text:SetTextColor(c.r, c.g, c.b)
			end

			local textWidth = entry.Text:GetStringWidth() or 0
			if textWidth > widest then
				widest = textWidth
			end

			entry:ClearAllPoints()
			entry:SetPoint("TOPLEFT", list.Child, "TOPLEFT", 0, -(index - 1) * ENTRY_HEIGHT)
			entry:SetPoint("RIGHT", list.Child, "RIGHT", 0, 0)
			entry:SetHeight(ENTRY_HEIGHT)
			entry:Show()
			shown = index
		end

		for index = shown + 1, #entries do
			entries[index]:Hide()
		end
		for i = 1, #headers do
			headers[i]:Hide()
		end
		for i = 1, #dividers do
			dividers[i]:Hide()
		end

		local width = math.max(owner:GetWidth() or 0, LIST_MIN_WIDTH, widest + TEXT_INSET + 20)
		if width > LIST_MAX_WIDTH then
			width = LIST_MAX_WIDTH
		end

		local visibleRows = math.min(shown, LIST_MAX_ROWS)
		local contentHeight = shown * ENTRY_HEIGHT
		local viewHeight = visibleRows * ENTRY_HEIGHT

		list.Child:SetSize(width - (ENTRY_INSET * 2), math.max(contentHeight, 1))
		local totalHeight = viewHeight + (LIST_PADDING * 2)
		list:SetSize(width, totalHeight)
		list.Scroll:SetVerticalScroll(0)

		positionList(owner, width, totalHeight, 1)

		if list.ScrollBar then
			list.ScrollBar:SetShown(contentHeight > viewHeight)
		end
	else
		local columns = {}
		for i = 1, numCols do
			columns[i] = { title = nil, items = {} }
		end

		if hasCategories then
			local catColMap = {}
			local nextCol = 1
			for _, opt in ipairs(options) do
				local cat = opt.category or "Other"
				if not catColMap[cat] then
					if nextCol <= numCols then
						catColMap[cat] = nextCol
						columns[nextCol].title = cat
						nextCol = nextCol + 1
					else
						catColMap[cat] = numCols
					end
				end
				local colIdx = catColMap[cat]
				local col = columns[colIdx]
				col.items[#col.items + 1] = opt
			end
		else
			local perCol = math.ceil(#options / numCols)
			for i, opt in ipairs(options) do
				local colIdx = math.min(math.floor((i - 1) / perCol) + 1, numCols)
				local col = columns[colIdx]
				col.items[#col.items + 1] = opt
			end
		end

		local maxColRows = 0
		for c = 1, numCols do
			local count = #columns[c].items
			if count > maxColRows then
				maxColRows = count
			end
		end

		local colWidth = 168
		local headerHeight = hasCategories and ENTRY_HEIGHT or 0
		local colContentHeight = headerHeight + (maxColRows * ENTRY_HEIGHT)
		local entryIndex = 0

		for c = 1, numCols do
			local col = columns[c]
			local colX = (c - 1) * colWidth

			if hasCategories and col.title then
				local header = acquireHeader(c)
				header:ClearAllPoints()
				header:SetPoint("TOPLEFT", list.Child, "TOPLEFT", colX + 4, 0)
				header:SetWidth(colWidth - 8)
				header.Text:SetText("|cffdb9e47" .. string.upper(col.title) .. "|r")
				header:Show()
			elseif headers[c] then
				headers[c]:Hide()
			end

			local currentY = -headerHeight
			for _, option in ipairs(col.items) do
				entryIndex = entryIndex + 1
				local entry = acquireEntry(entryIndex)
				entry.value = option.value
				entry.label = option.label
				entry.tooltip = option.tooltip
				local selected = (option.value == selectedValue)
				entry.Selected:SetShown(selected)
				if selected then
					entry.Text:SetText("|cffdb9e47> |r" .. (option.label or tostring(option.value)))
					entry.Text:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
				else
					entry.Text:SetText("   " .. (option.label or tostring(option.value)))
					local tc = Theme.COLOR_TEXT_PRIMARY
					entry.Text:SetTextColor(tc.r, tc.g, tc.b)
				end

				entry:ClearAllPoints()
				entry:SetPoint("TOPLEFT", list.Child, "TOPLEFT", colX, currentY)
				entry:SetSize(colWidth, ENTRY_HEIGHT)
				entry:Show()
				currentY = currentY - ENTRY_HEIGHT
			end

			if c < numCols then
				local div = acquireDivider(c)
				div:ClearAllPoints()
				div:SetPoint("TOPLEFT", list.Child, "TOPLEFT", c * colWidth, 0)
				div:SetPoint("BOTTOMLEFT", list.Child, "TOPLEFT", c * colWidth, -colContentHeight)
				div:Show()
			elseif dividers[c] then
				dividers[c]:Hide()
			end
		end

		for index = entryIndex + 1, #entries do
			entries[index]:Hide()
		end
		for c = numCols + 1, #headers do
			headers[c]:Hide()
		end
		for c = numCols, #dividers do
			dividers[c]:Hide()
		end

		local totalWidth = (numCols * colWidth) + (ENTRY_INSET * 2)
		local totalHeight = colContentHeight + (LIST_PADDING * 2)

		list.Child:SetSize(numCols * colWidth, math.max(colContentHeight, 1))
		list:SetSize(totalWidth, totalHeight)
		list.Scroll:SetVerticalScroll(0)

		positionList(owner, totalWidth, totalHeight, numCols)

		if list.ScrollBar then
			list.ScrollBar:Hide()
		end
	end

	listCatcher:Show()
	list:Show()
end

-- Dialogs

local dialog

local function closeDialog()
	if dialog then
		dialog:Hide()
	end
end

function Popup.CloseDialog()
	closeDialog()
end

local function ensureDialog()
	if dialog then
		return
	end

	dialog = backdropFrame(UIParent, "DiabolusSettingsDialog")
	dialog:SetFrameStrata(OVERLAY_STRATA)
	dialog:SetFrameLevel(200)
	dialog:SetWidth(DIALOG_WIDTH)
	dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	dialog:EnableMouse(true)
	dialog:Hide()
	Theme.MarkIgnored(dialog)

	dialog.Message = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	dialog.Message:SetJustifyH("CENTER")
	dialog.Message:SetSpacing(3)
	dialog.Message:SetWidth(DIALOG_WIDTH - 40)
	dialog.Message:SetPoint("TOP", dialog, "TOP", 0, -18)

	local edit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
	edit:SetSize(DIALOG_WIDTH - 80, 20)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(24)
	edit:SetPoint("TOP", dialog.Message, "BOTTOM", 0, -14)
	dialog.Edit = edit

	local accept = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	accept:SetSize(110, 22)
	dialog.Accept = accept

	local cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	cancel:SetSize(110, 22)
	cancel:SetText(CANCEL or "Cancel")
	cancel:SetScript("OnClick", closeDialog)
	Theme.StyleActionButton(accept, false)
	Theme.StyleActionButton(cancel, false)
	dialog.Cancel = cancel

	local function accepted()
		local handler = dialog.onAccept
		local value = dialog.Edit:IsShown() and dialog.Edit:GetText() or nil
		closeDialog()
		if handler then
			handler(value)
		end
	end
	dialog.accepted = accepted

	accept:SetScript("OnClick", accepted)
	edit:SetScript("OnEnterPressed", accepted)
	edit:SetScript("OnEscapePressed", closeDialog)

	-- Escape closes it when no edit box catches the key. Propagation stays on except for
	-- the one key actually handled, so the dialog never eats anything else.
	-- Skip restricted SetPropagateKeyboardInput in combat lockdown to prevent blocked action errors (CR-023).
	dialog:EnableKeyboard(true)
	if dialog.SetPropagateKeyboardInput then
		dialog:SetScript("OnKeyDown", function(self, key)
			if InCombatLockdown and InCombatLockdown() then
				if key == "ESCAPE" then
					closeDialog()
				end
				return
			end
			if key == "ESCAPE" then
				self:SetPropagateKeyboardInput(false)
				closeDialog()
			else
				self:SetPropagateKeyboardInput(true)
			end
		end)
	end

	dialog:RegisterEvent("PLAYER_REGEN_DISABLED")
	dialog:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_REGEN_DISABLED" then
			closeDialog()
		end
	end)

	dialog:SetScript("OnHide", function(self)
		self.onAccept = nil
		self.Edit:ClearFocus()
	end)
end

local function layoutDialog(withEdit)
	local height = 18 + dialog.Message:GetStringHeight() + 14
	if withEdit then
		dialog.Edit:Show()
		height = height + 20 + 14
		dialog.Accept:SetPoint("TOPRIGHT", dialog, "TOP", -6, -height)
		dialog.Cancel:SetPoint("TOPLEFT", dialog, "TOP", 6, -height)
	else
		dialog.Edit:Hide()
		dialog.Accept:SetPoint("TOPRIGHT", dialog, "TOP", -6, -height)
		dialog.Cancel:SetPoint("TOPLEFT", dialog, "TOP", 6, -height)
	end
	dialog:SetHeight(height + 22 + 18)
end

local function refuseInCombat()
	if InCombatLockdown and InCombatLockdown() then
		local errorsFrame = _G.UIErrorsFrame
		local msg = _G.ERR_NOT_IN_COMBAT or "You cannot do that while in combat."
		if errorsFrame and errorsFrame.AddMessage then
			errorsFrame:AddMessage(msg, 1, 0.1, 0.1)
		else
			print("DiabolusUnits: not available in combat. Try again after combat.")
		end
		return true
	end
	return false
end

-- A yes/no confirmation. `acceptText` names the action rather than saying "Okay": a button
-- that says what it does is the difference between reading the dialog and not.
function Popup.Confirm(text, acceptText, onAccept)
	if refuseInCombat() then
		return
	end
	ensureDialog()
	dialog.Message:SetText(text)
	dialog.Accept:SetText(acceptText or OKAY or "Okay")
	dialog.Accept:ClearAllPoints()
	dialog.Cancel:ClearAllPoints()
	dialog.onAccept = onAccept
	layoutDialog(false)
	dialog:Show()
end

-- A confirmation that also wants a line of text.
function Popup.Prompt(text, defaultValue, acceptText, onAccept)
	if refuseInCombat() then
		return
	end
	ensureDialog()
	dialog.Message:SetText(text)
	dialog.Accept:SetText(acceptText or ACCEPT or "Accept")
	dialog.Accept:ClearAllPoints()
	dialog.Cancel:ClearAllPoints()
	dialog.onAccept = onAccept
	layoutDialog(true)
	dialog.Edit:SetText(defaultValue or "")
	dialog:Show()
	dialog.Edit:SetFocus()
	dialog.Edit:HighlightText()
end

-- Test inspection helper
function Popup._DebugEntry(index)
	return entries[index]
end

-- Both overlays belong to the panel and should not outlive it on screen.
function Popup.CloseAll()
	closeList()
	closeDialog()
end

-- Local lists/dialogs participate in the panel's existing controller dispatcher.
function Popup.HandleGamepad(key)
	if dialog and dialog:IsShown() then
		if key == "PAD2" or key == "PADBACK" then
			closeDialog()
		elseif key == "PAD1" then
			dialog.accepted()
		end
		return true
	end
	if not Popup.IsListOpen() then
		return false
	end
	if key == "PAD2" or key == "PADBACK" then
		closeList()
		return true
	end
	local visible = {}
	for _, entry in ipairs(entries) do
		if entry:IsShown() then
			visible[#visible + 1] = entry
		end
	end
	if #visible == 0 then
		return true
	end
	local index = listState.focus
	if not index then
		index = 1
		for i, entry in ipairs(visible) do
			if entry.value == listState.selectedValue then
				index = i
				break
			end
		end
	end
	if key == "PADDUP" or key == "PADDLEFT" then
		index = math.max(1, index - 1)
	elseif key == "PADDDOWN" or key == "PADDRIGHT" then
		index = math.min(#visible, index + 1)
	elseif key == "PAD1" then
		visible[index]:Click()
		return true
	end
	listState.focus = index
	for i, entry in ipairs(visible) do
		entry.Selected:SetShown(i == index)
	end
	local entry, scroll = visible[index], list.Scroll
	local top, bottom = entry:GetTop(), entry:GetBottom()
	if top and bottom and scroll:GetTop() and scroll:GetBottom() then
		local offset = scroll:GetVerticalScroll()
		if top > scroll:GetTop() then
			scroll:SetVerticalScroll(math.max(0, offset - top + scroll:GetTop()))
		elseif bottom < scroll:GetBottom() then
			scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(), offset + scroll:GetBottom() - bottom))
		end
	end
	return true
end
