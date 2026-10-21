-- Permanent settings rows bound to one spec for the session.
-- Rows expose rowHeight, searchText, RefreshValue, and SetRowEnabled to Content.
-- Button rows own navigation focus; other rows expose their inner control.
-- Framework ported from PulseHaptics UI/Panel.

local ADDON_NAME, ns = ...

local Panel = ns.UI.Panel
local Theme = Panel.Theme

local Rows = {}
Panel.Rows = Rows

-- Shared row scaffolding

-- Place the controller cursor beside the row instead of over its control.
local function setCursorAnchor(row, control)
	if type(SmartNavigation_SetCustomCursorAnchorPointForFrame) ~= "function" then
		return
	end
	if type(CreateAnchor) ~= "function" then
		return
	end
	local ok, anchor = pcall(CreateAnchor, "RIGHT", row, "LEFT", 30)
	if ok and anchor then
		pcall(SmartNavigation_SetCustomCursorAnchorPointForFrame, control, anchor)
	end
end

-- Shared label, hover, and tooltip area. Label hit geometry originated in
-- Blizzard SettingsListElementTemplate; control positions use Theme offsets.
local function createBaseRow(parent, spec, frameType)
	local row = CreateFrame(frameType or "Frame", nil, parent)
	row:SetHeight(Theme.ROW_HEIGHT)
	row.rowHeight = Theme.ROW_HEIGHT
	row.spec = spec

	local indent = spec.child and Theme.INDENT or 0

	row.Text = row:CreateFontString(nil, "OVERLAY", spec.child and Theme.FONT_CHILD or Theme.FONT_NORMAL)
	row.Text:SetJustifyH("LEFT")
	row.Text:SetWordWrap(true)
	row.Text:SetJustifyV("MIDDLE")
	row.Text:SetPoint("LEFT", row, "LEFT", indent + Theme.TEXT_LEFT, 0)

	row.Text:SetText(spec.label or "")
	if row.Text.SetTextColor then
		row.Text:SetTextColor(Theme.COLOR_TEXT_PRIMARY.r, Theme.COLOR_TEXT_PRIMARY.g, Theme.COLOR_TEXT_PRIMARY.b)
	end

	row.MeasureHeight = function()
		local available = math.max(80, row:GetWidth() / 2 + Theme.TEXT_RIGHT - indent - Theme.TEXT_LEFT)
		row.Text:SetWidth(available)
		row.rowHeight = math.max(Theme.ROW_HEIGHT, row.Text:GetStringHeight() + 12)
		row:SetHeight(row.rowHeight)
		return row.rowHeight
	end
	row.HoverBackground = Theme.CreateHoverBackground(row)

	local pip = row:CreateTexture(nil, "OVERLAY")
	pip:SetSize(2, 16)
	pip:SetPoint("LEFT", row, "LEFT", 2, 0)
	pip:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.9)
	pip:Hide()
	row.HoverPip = pip

	row.ShowRowTooltip = function()
		row.HoverBackground:Show()
		if row.HoverPip then
			row.HoverPip:Show()
		end
		Theme.ShowTooltip(row, spec.label, spec.tooltip)
	end
	row.HideRowTooltip = function()
		row.HoverBackground:Hide()
		if row.HoverPip then
			row.HoverPip:Hide()
		end
		Theme.HideTooltip()
	end

	if frameType == "Button" then
		-- The row IS the navigation target, so hover and tooltip belong on it directly; a
		-- second hit-area frame would only fight it for OnLeave.
		row:SetScript("OnEnter", row.ShowRowTooltip)
		row:SetScript("OnLeave", row.HideRowTooltip)
	else
		local hit = CreateFrame("Frame", nil, row)
		hit:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		hit:SetPoint("BOTTOMRIGHT", row, "BOTTOM", Theme.CONTROL_LEFT - 8, 0)
		hit:EnableMouse(true)
		hit:SetScript("OnEnter", row.ShowRowTooltip)
		hit:SetScript("OnLeave", row.HideRowTooltip)
		-- Blizzard_SettingControls.lua:355: this frame has mouse scripts, so
		-- SmartNavigation_CanFocusFrame would treat it as a button. It is a label.
		Theme.MarkIgnored(hit)
		row.Hit = hit
	end

	row.searchText = string.lower((spec.label or "") .. " " .. (spec.tooltip or ""))

	return row
end

-- Attaches the tooltip to a control as well as to the label, so hovering the slider or the
-- dropdown says the same thing as hovering its name.
local function attachControlTooltip(row, control, spec)
	if not control or not control.HookScript then
		return
	end
	control:HookScript("OnEnter", function()
		if row.HoverBackground then
			row.HoverBackground:Show()
		end
		if row.HoverPip then
			row.HoverPip:Show()
		end
		Theme.ShowTooltip(control, spec.label, spec.tooltip)
	end)
	control:HookScript("OnLeave", function()
		if row.HoverBackground then
			row.HoverBackground:Hide()
		end
		if row.HoverPip then
			row.HoverPip:Hide()
		end
		Theme.HideTooltip()
	end)
end

-- Section header

-- Non-focusable section heading with themed text and divider.
function Rows.CreateHeader(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(Theme.HEADER_ROW_H)
	row.rowHeight = Theme.HEADER_ROW_H
	row.spec = spec
	row.isHeader = true

	row.Title = row:CreateFontString(nil, "OVERLAY", Theme.SECTION_FONT)
	row.Title:SetJustifyH("LEFT")
	row.Title:SetJustifyV("TOP")
	row.Title:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -12)
	row.Title:SetText(spec.label or "")

	local rule = row:CreateTexture(nil, "ARTWORK")
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -4)
	rule:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	rule:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.25)

	row.searchText = string.lower(spec.label or "")
	Theme.MarkIgnored(row)

	row.RefreshValue = function() end
	row.SetRowEnabled = function() end

	return row
end

-- Free-text block (the Guide page)

-- The one row that is not a control. Height depends on the wrapped text, so Content.lua
-- calls MeasureHeight once the real width is known rather than fixing it here.
function Rows.CreateText(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	row.spec = spec
	row.isText = true
	row.rowHeight = 1

	row.Body = row:CreateFontString(nil, "OVERLAY", spec.font or Theme.FONT_CHILD)
	row.Body:SetJustifyH("LEFT")
	row.Body:SetSpacing(2)
	-- One corner only, width set explicitly in MeasureHeight. A FontString deriving its
	-- width from two anchors has not necessarily resolved it by the time GetStringHeight is
	-- asked, which is how a wrapped paragraph comes out one line tall on the first pass.
	row.Body:SetPoint("TOPLEFT", row, "TOPLEFT", Theme.TEXT_LEFT, 0)

	-- `body` may be a function, for a paragraph that reports state rather than stating a
	-- fact — the profiles page's "which rule is in force" line is the reason this exists.
	local function currentBody()
		if type(spec.body) == "function" then
			return spec.body() or ""
		end
		return spec.body or ""
	end
	row.Body:SetText(currentBody())

	-- currentBody(), not spec.body: a live paragraph is a function and concatenating one
	-- errors. Search matches the text as it read when the page was built, which is all a
	-- search index can honestly promise about a string that changes.
	row.searchText = string.lower((spec.label or "") .. " " .. currentBody())
	Theme.MarkIgnored(row)

	row.MeasureHeight = function()
		local available = (row:GetWidth() or 0) - Theme.TEXT_LEFT - 20
		if available > 1 then
			row.Body:SetWidth(available)
		end
		local height = row.Body:GetStringHeight()
		if not height or height < 1 then
			height = 1
		end
		row.rowHeight = height + (spec.gap or 4)
		row:SetHeight(row.rowHeight)
		return row.rowHeight
	end

	row.RefreshValue = function()
		if type(spec.body) ~= "function" then
			return
		end
		local text = currentBody()
		-- No relayout needed: every caller of RefreshRows follows it with LayoutRows,
		-- which re-measures text rows itself. Setting the string is enough.
		if text ~= row.Body:GetText() then
			row.Body:SetText(text)
		end
	end
	row.SetRowEnabled = function() end

	return row
end

-- Checkbox

-- Custom checkbox surface with separate checked and disabled states.
function Rows.CreateCheckbox(parent, spec)
	local row = createBaseRow(parent, spec, "Frame")

	local statusBadge
	if spec.isMaster then
		local cardBg = row:CreateTexture(nil, "BACKGROUND", nil, -1)
		cardBg:SetPoint("TOPLEFT", row, "TOPLEFT", 6, 1)
		cardBg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, -1)
		cardBg:SetColorTexture(Theme.COLOR_SURFACE.r, Theme.COLOR_SURFACE.g, Theme.COLOR_SURFACE.b, 0.75)

		local cardAccent = row:CreateTexture(nil, "BORDER")
		cardAccent:SetPoint("TOPLEFT", cardBg, "TOPLEFT", 0, 0)
		cardAccent:SetPoint("BOTTOMLEFT", cardBg, "BOTTOMLEFT", 0, 0)
		cardAccent:SetWidth(2)
		cardAccent:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.8)

		statusBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	end

	local box = CreateFrame("CheckButton", nil, row)
	box:SetSize(Theme.CHECKBOX_SIZE_X, Theme.CHECKBOX_SIZE_Y)
	box:SetPoint("LEFT", row, "CENTER", Theme.CONTROL_LEFT, 0)
	box:SetMotionScriptsWhileDisabled(true)
	Theme.CreateSurface(box, Theme.COLOR_BG)
	local check = box:CreateTexture(nil, "ARTWORK")
	check:SetPoint("TOPLEFT", 4, -4)
	check:SetPoint("BOTTOMRIGHT", -4, 4)
	check:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1)
	box:SetCheckedTexture(check)
	local disabledCheck = box:CreateTexture(nil, "ARTWORK")
	disabledCheck:SetPoint("TOPLEFT", 4, -4)
	disabledCheck:SetPoint("BOTTOMRIGHT", -4, 4)
	disabledCheck:SetColorTexture(0.38, 0.40, 0.43, 1)
	box:SetDisabledCheckedTexture(disabledCheck)

	if statusBadge then
		statusBadge:SetPoint("LEFT", box, "RIGHT", 10, 0)
	end

	local function updateStatus()
		local val = spec.get() and true or false
		box:SetChecked(val)
		if statusBadge then
			-- A page switch shows how much of its page is on ("12 of 35 on") rather than a
			-- bare ACTIVE/MUTED; everything else keeps the original badge.
			local text = spec.badge and spec.badge(val)
			statusBadge:SetText(text or (val and "|cffdb9e47[ON]|r" or "|cff94806a[OFF]|r"))
		end
	end

	box:SetScript("OnClick", function(self)
		local value = self:GetChecked() and true or false
		Theme.PlayCheckSound(value)
		spec.set(value)
		-- The store may refuse or clamp; show whatever it actually holds now.
		updateStatus()
	end)

	box:SetScript("OnEnter", function()
		row.HoverBackground:Show()
		if row.HoverPip then
			row.HoverPip:Show()
		end
		Theme.ShowTooltip(box, spec.label, spec.tooltip)
	end)
	box:SetScript("OnLeave", function()
		row.HoverBackground:Hide()
		if row.HoverPip then
			row.HoverPip:Hide()
		end
		Theme.HideTooltip()
	end)

	-- Clicking the label toggles the box, exactly as Blizzard's rows do
	-- (Blizzard_SettingControls.lua:596-600).
	row.Hit:SetScript("OnMouseUp", function()
		if box:IsEnabled() then
			box:Click()
		end
	end)

	setCursorAnchor(row, box)
	if type(SmartNavigation_AddIgnoreInputNavigationOverride) == "function" and SMART_NAV_INPUT_DIRECTION then
		pcall(SmartNavigation_AddIgnoreInputNavigationOverride, box, SMART_NAV_INPUT_DIRECTION.RIGHT)
	end

	row.Control = box
	row.RefreshValue = updateStatus
	row.SetRowEnabled = function(_, enabled)
		box:SetEnabled(enabled)
		Theme.DisplayEnabled(row, enabled)
	end

	row:RefreshValue()
	return row
end

-- Slider

-- Match displayed precision to the slider step; avoid floating-point text artifacts.
local function makeFormatter(step)
	local decimals, scale = 0, step or 0
	while scale > 0 and scale < 1 and decimals < 4 do
		scale = scale * 10
		decimals = decimals + 1
	end
	local pattern = "%." .. decimals .. "f"
	return function(value)
		return string.format(pattern, value or 0)
	end
end

function Rows.CreateSlider(parent, spec)
	local row = createBaseRow(parent, spec, "Button")

	local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
	slider:SetWidth(Theme.SLIDER_WIDTH)
	slider:SetPoint("LEFT", row, "CENTER", Theme.CONTROL_LEFT, Theme.SLIDER_OFFSET_Y)

	local step = spec.step or 0.05
	local range = (spec.max or 1) - (spec.min or 0)
	local steps = (step > 0) and (range / step) or 100
	if steps < 1 then
		steps = 1
	end

	local formatters = {}
	if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
		formatters[MinimalSliderWithSteppersMixin.Label.Right] = spec.format or makeFormatter(step)
	end

	-- Fall back to the range minimum until the settings store has a numeric value.
	local function currentValue()
		local value = spec.get()
		if type(value) ~= "number" then
			return spec.min or 0
		end
		return value
	end

	slider:Init(currentValue(), spec.min or 0, spec.max or 1, steps, formatters)
	Theme.StyleSlider(slider)

	-- Prevent database refreshes from feeding back into the slider mid-drag.
	local applying = false
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if applying then
			return
		end
		applying = true
		spec.set(value)
		applying = false
	end, row)

	attachControlTooltip(row, slider.Slider, spec)

	-- Blizzard_SettingControls.lua:728-731: the inner widget is skipped and the ROW is the
	-- navigation target, so D-pad bindings act on a whole row.
	Theme.MarkIgnored(slider)
	Theme.MarkFocusable(row)
	setCursorAnchor(row, row)

	row.Control = slider
	row.RefreshValue = function()
		if applying then
			return
		end
		local value = currentValue()
		local current = slider.Slider and slider.Slider:GetValue()
		-- Only write when it actually differs, so a refresh never nudges a slider the
		-- player is holding.
		if current == nil or math.abs(current - value) > (step * 0.001) then
			applying = true
			slider:SetValue(value)
			applying = false
		end
	end
	row.SetRowEnabled = function(_, enabled)
		slider:SetEnabled(enabled)
		Theme.DisplayEnabled(row, enabled)
	end

	return row
end

-- Dropdown

-- SettingsDropdownWithButtonsTemplate is the dropdown-plus-stepper-arrows combination
-- Blizzard's own rows use; the arrows are what left and right map onto for gamepad. Falls
-- back to the bare dropdown if the template is absent, so the page still renders.
local function createDropdownControl(row)
	local control = CreateFrame("Frame", nil, row)
	control:SetSize(Theme.DROPDOWN_WIDTH + 56, 26)
	control:SetPoint("LEFT", row, "CENTER", Theme.CONTROL_LEFT, 0)
	local back = CreateFrame("Button", nil, control)
	back:SetSize(24, 26)
	back:SetPoint("LEFT")
	Theme.StylePlainButton(back, "<")
	local dropdown = CreateFrame("Button", nil, control)
	dropdown:SetSize(Theme.DROPDOWN_WIDTH, 26)
	dropdown:SetPoint("LEFT", back, "RIGHT", 4, 0)
	dropdown.Text = Theme.StylePlainButton(dropdown)
	local nextButton = CreateFrame("Button", nil, control)
	nextButton:SetSize(24, 26)
	nextButton:SetPoint("LEFT", dropdown, "RIGHT", 4, 0)
	Theme.StylePlainButton(nextButton, ">")
	control.Dropdown, control.DecrementButton, control.IncrementButton = dropdown, back, nextButton
	function control:SetSteppersEnabled(left, right)
		back:SetEnabled(left)
		nextButton:SetEnabled(right)
	end
	function control:SetSteppersShown(show)
		back:SetShown(show)
		nextButton:SetShown(show)
	end
	function control:SetEnabled(enabled)
		dropdown:SetEnabled(enabled)
		back:SetEnabled(enabled)
		nextButton:SetEnabled(enabled)
	end
	return control, dropdown
end

function Rows.CreateDropdown(parent, spec)
	local row = createBaseRow(parent, spec, "Button")

	local control, dropdown = createDropdownControl(row)
	if not dropdown then
		-- No dropdown widget on this client: degrade to a label rather than taking the
		-- whole page down.
		row.RefreshValue = function() end
		row.SetRowEnabled = function(_, enabled)
			Theme.DisplayEnabled(row, enabled)
		end
		return row
	end

	-- Do not call SetupMenu: use Popup.OpenList to avoid protected gamepad Menu activation.

	local function options()
		local ok, result = pcall(spec.options)
		if ok and type(result) == "table" then
			return result
		end
		return {}
	end

	local function labelFor(value)
		if value == nil and spec.placeholder then
			return spec.placeholder
		end
		for _, option in ipairs(options()) do
			if option.value == value then
				return option.label
			end
		end
		return CUSTOM or "Custom"
	end

	local function setText(text)
		if dropdown.Text then
			dropdown.Text:SetText(text)
		elseif dropdown.SetText then
			dropdown:SetText(text)
		end
	end

	-- Step by one without opening anything. The template's stepper buttons normally drive
	-- the menu's own selection; with no menu they run off the options array directly.
	local function step(delta)
		local list = options()
		local current = spec.get()
		for index, option in ipairs(list) do
			if option.value == current then
				local target = list[index + delta]
				if target then
					spec.set(target.value)
				end
				return
			end
		end
		if list[1] then
			spec.set(list[1].value)
		end
	end

	local function updateSteppers()
		if not control.SetSteppersEnabled then
			return
		end
		local list = options()
		local current = spec.get()
		local index
		for i, option in ipairs(list) do
			if option.value == current then
				index = i
				break
			end
		end
		control:SetSteppersEnabled(index ~= nil and index > 1, index ~= nil and index < #list)
	end

	dropdown:SetScript("OnClick", function()
		if not dropdown:IsEnabled() then
			return
		end
		local previewScale = nil
		if spec.previewScale then
			if type(spec.previewScale) == "function" then
				previewScale = spec.previewScale()
			else
				previewScale = spec.previewScale
			end
		end
		Panel.Popup.OpenList(dropdown, options(), spec.get(), function(value)
			spec.set(value)
		end, previewScale)
	end)

	if control.IncrementButton then
		control.IncrementButton:SetScript("OnClick", function()
			step(1)
			if SOUNDKIT then
				Theme.PlayCheckSound(true)
			end
		end)
	end
	if control.DecrementButton then
		control.DecrementButton:SetScript("OnClick", function()
			step(-1)
			if SOUNDKIT then
				Theme.PlayCheckSound(true)
			end
		end)
	end
	if control.SetSteppersShown then
		control:SetSteppersShown(true)
	end

	attachControlTooltip(row, dropdown, spec)

	Theme.MarkIgnored(control)
	Theme.MarkFocusable(row)
	setCursorAnchor(row, row)

	row.Control = control
	row.Dropdown = dropdown

	row.RefreshValue = function()
		if spec.labelFunc then
			row.Text:SetText(spec.labelFunc())
		end
		setText(labelFor(spec.get()))
		updateSteppers()
	end
	row.SetRowEnabled = function(_, enabled)
		if control.SetEnabled then
			control:SetEnabled(enabled)
		elseif dropdown.SetEnabled then
			dropdown:SetEnabled(enabled)
		end
		Theme.DisplayEnabled(row, enabled)
	end

	row:RefreshValue()
	return row
end

-- Button

-- Action button beside a settings label.
function Rows.CreateButton(parent, spec)
	local row = createBaseRow(parent, spec, "Frame")

	local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	button:SetSize(Theme.BUTTON_WIDTH, 26)
	button:SetPoint("LEFT", row, "CENTER", Theme.BUTTON_LEFT, 0)
	button:SetText(spec.buttonText or "")
	Theme.StyleActionButton(button, true)
	button:SetScript("OnClick", function()
		spec.onClick()
	end)

	attachControlTooltip(row, button, spec)

	setCursorAnchor(row, button)
	if type(SmartNavigation_AddIgnoreInputNavigationOverride) == "function" and SMART_NAV_INPUT_DIRECTION then
		pcall(SmartNavigation_AddIgnoreInputNavigationOverride, button, SMART_NAV_INPUT_DIRECTION.RIGHT)
	end

	row.Control = button
	row.RefreshValue = function()
		if spec.buttonTextFunc then
			button:SetText(spec.buttonTextFunc())
		end
		-- Same idea as a live `body`: a row whose NAME reports state, e.g. a rule row
		-- that reads "This character — Raiding" and has to follow the rule it names.
		if spec.labelFunc then
			row.Text:SetText(spec.labelFunc())
		end
	end
	row.SetRowEnabled = function(_, enabled)
		button:SetEnabled(enabled)
		Theme.DisplayEnabled(row, enabled)
	end

	return row
end

-- Collapsible section header

-- Collapsible header; excluded from native SmartNavigation discovery.
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"

function Rows.CreateSectionHeader(parent, spec)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(Theme.HEADER_ROW_H)
	row.rowHeight = Theme.HEADER_ROW_H
	row.spec = spec
	row.isHeader = true
	row.isSectionHeader = true
	row.sectionKey = spec.sectionKey

	row.Toggle = row:CreateTexture(nil, "ARTWORK")
	row.Toggle:SetSize(14, 14)
	row.Toggle:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -18)

	row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	row.Title:SetJustifyH("LEFT")
	row.Title:SetPoint("LEFT", row.Toggle, "RIGHT", 6, 0)
	row.Title:SetText(spec.label or "")

	row.Badge = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.Badge:SetPoint("LEFT", row.Title, "RIGHT", 10, 0)

	local rule = row:CreateTexture(nil, "ARTWORK")
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", row.Toggle, "BOTTOMLEFT", 0, -6)
	rule:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	rule:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 0.25)

	row:SetScript("OnClick", function()
		spec.onToggle()
	end)

	row.searchText = string.lower(spec.label or "")
	Theme.MarkIgnored(row)

	row.RefreshValue = function()
		row.Toggle:SetTexture(spec.isCollapsed() and PLUS or MINUS)
		row.Badge:SetText(spec.badge and spec.badge() or "")
	end
	row.SetRowEnabled = function() end

	row:RefreshValue()
	return row
end

-- Colour swatch

-- Colour swatch: open the client colour picker with plain Show(), avoiding ShowUIPanel.
-- spec.get() returns r, g, b; spec.set(r, g, b) receives the selection.
function Rows.CreateColor(parent, spec)
	local row = createBaseRow(parent, spec, "Frame")

	local swatch = CreateFrame("Button", nil, row)
	swatch:SetSize(48, 20)
	swatch:SetPoint("LEFT", row, "CENTER", Theme.CONTROL_LEFT + 4, 0)
	local border = swatch:CreateTexture(nil, "BACKGROUND")
	border:SetAllPoints()
	border:SetColorTexture(Theme.COLOR_BORDER.r, Theme.COLOR_BORDER.g, Theme.COLOR_BORDER.b, 1)
	local fill = swatch:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 2, -2)
	fill:SetPoint("BOTTOMRIGHT", -2, 2)
	local hl = swatch:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.15)

	local function refresh()
		local r, g, b = spec.get()
		fill:SetColorTexture(r or 1, g or 1, b or 1, 1)
	end

	swatch:SetScript("OnClick", function()
		if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then
			return
		end
		local r, g, b = spec.get()
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r or 1,
			g = g or 1,
			b = b or 1,
			swatchFunc = function()
				local nr, ng, nb = ColorPickerFrame:GetColorRGB()
				spec.set(nr, ng, nb)
				refresh()
			end,
			cancelFunc = function(previous)
				if previous then
					spec.set(previous.r, previous.g, previous.b)
					refresh()
				end
			end,
		})
	end)

	attachControlTooltip(row, swatch, spec)
	setCursorAnchor(row, swatch)
	if type(SmartNavigation_AddIgnoreInputNavigationOverride) == "function" and SMART_NAV_INPUT_DIRECTION then
		pcall(SmartNavigation_AddIgnoreInputNavigationOverride, swatch, SMART_NAV_INPUT_DIRECTION.RIGHT)
	end

	row.Control = swatch
	row.RefreshValue = refresh
	row.SetRowEnabled = function(_, enabled)
		swatch:SetEnabled(enabled)
		fill:SetDesaturated(not enabled)
		Theme.DisplayEnabled(row, enabled)
	end

	refresh()
	return row
end

-- Dispatch

local builders = {
	header = Rows.CreateHeader,
	text = Rows.CreateText,
	checkbox = Rows.CreateCheckbox,
	slider = Rows.CreateSlider,
	dropdown = Rows.CreateDropdown,
	button = Rows.CreateButton,
	section = Rows.CreateSectionHeader,
	color = Rows.CreateColor,
}

-- Every write from a row marks the panel dirty, so rows that depend on it (enabledWhen,
-- visibleWhen, live text) follow on the next frame.
local function wrapSet(spec)
	local set = spec.set
	if type(set) ~= "function" then
		return
	end
	spec.set = function(...)
		set(...)
		if Panel.MarkDirty then
			Panel.MarkDirty()
		end
	end
end

function Rows.Create(parent, spec)
	local builder = builders[spec.kind]
	if not builder then
		return nil
	end

	wrapSet(spec)
	-- A single malformed spec should cost its own row, not the page it is on.
	local ok, row = pcall(builder, parent, spec)
	if not ok then
		print(("DiabolusUnits: could not build settings row %q (%s)"):format(tostring(spec.label), tostring(row)))
		return nil
	end
	return row
end
