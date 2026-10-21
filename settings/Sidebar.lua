-- Settings categories with custom icons, hover colours, and selection markers.
-- The fixed list needs no scrolling. Framework ported from PulseHaptics UI/Panel/Sidebar.lua.

local ADDON_NAME, ns = ...

local Panel = ns.UI.Panel
local Theme = Panel.Theme

local Sidebar = {}
Panel.Sidebar = Sidebar

local SidebarMixin = {}

local function updateButtonState(button)
	local selected = button.selected
	button.Texture:SetShown(selected or button.over)
	button.Texture:SetColorTexture(
		selected and 0.155 or 0.115,
		selected and 0.135 or 0.105,
		selected and 0.11 or 0.09,
		1
	)
	button.Indicator:SetShown(selected)
	local c = selected and Theme.COLOR_TEXT_PRIMARY or Theme.COLOR_TEXT_MUTED
	button.Label:SetTextColor(c.r, c.g, c.b)
	if button.Icon then
		if button.Icon.SetIconColor then
			button.Icon:SetIconColor(
				selected and Theme.COLOR_ACCENT or (button.over and Theme.COLOR_TEXT_PRIMARY or Theme.COLOR_TEXT_MUTED)
			)
		else
			button.Icon:SetDesaturated(true)
			button.Icon:SetAlpha(selected and 0.85 or 0.5)
		end
	end
end

function Sidebar.Create(parent, onSelect)
	local frame = CreateFrame("Frame", nil, parent)
	Mixin(frame, SidebarMixin)
	frame.buttons = {}
	frame.onSelect = onSelect
	return frame
end

function SidebarMixin:CreateButtons(pages)
	local previous = nil
	for _, page in ipairs(pages) do
		local button = CreateFrame("Button", nil, self)
		button:SetHeight(Theme.CATEGORY_HEIGHT)
		button:SetPoint("LEFT", self, "LEFT", 0, 0)
		button:SetPoint("RIGHT", self, "RIGHT", 0, 0)
		if previous then
			button:SetPoint("TOP", previous, "BOTTOM", 0, 0)
		else
			button:SetPoint("TOP", self, "TOP", 0, 0)
		end

		button.Texture = button:CreateTexture(nil, "BACKGROUND")
		button.Texture:SetAllPoints(button)
		button.Texture:Hide()

		-- Left-edge active indicator pill
		button.Indicator = button:CreateTexture(nil, "OVERLAY")
		button.Indicator:SetWidth(2)
		button.Indicator:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -2)
		button.Indicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 2)
		button.Indicator:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1)
		button.Indicator:Hide()

		-- Category icon
		local iconTexture = page.icon
		local iconX = (Theme.CATEGORY_LABEL_X - 18) + (page.indent or 0) * Theme.CATEGORY_INDENT
		if iconTexture then
			local icon = Theme.CreateIcon(button, iconTexture, 16)
			if not icon then
				icon = button:CreateTexture(nil, "ARTWORK")
				icon:SetSize(16, 16)
				icon:SetTexture(iconTexture)
				icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			icon:SetPoint("LEFT", button, "LEFT", iconX - 2, 0)
			button.Icon = icon
		end

		button.Label = button:CreateFontString(nil, "ARTWORK", Theme.FONT_NORMAL)
		button.Label:SetJustifyH("LEFT")
		button.Label:SetPoint(
			"TOPLEFT",
			button,
			"TOPLEFT",
			Theme.CATEGORY_LABEL_X + (page.indent or 0) * Theme.CATEGORY_INDENT,
			1
		)
		button.Label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
		button.Label:SetText(page.label)

		button.page = page
		button.isChild = (page.indent or 0) > 0

		button:SetScript("OnEnter", function(btn)
			btn.over = true
			updateButtonState(btn)
		end)
		button:SetScript("OnLeave", function(btn)
			btn.over = false
			updateButtonState(btn)
		end)
		button:SetScript("OnClick", function(btn)
			if Panel.Gamepad.OnPointer then
				Panel.Gamepad.OnPointer()
			end
			if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
			end
			btn:GetParent():Select(btn.page)
		end)

		updateButtonState(button)

		self.buttons[#self.buttons + 1] = button
		previous = button
	end
end

-- Filter existing category buttons and close gaps; nil shows every page.
function SidebarMixin:ApplyFilter(keep)
	local previous = nil
	for _, button in ipairs(self.buttons) do
		local visible = (keep == nil) or keep(button.page)
		button:SetShown(visible)
		if visible then
			button:ClearAllPoints()
			button:SetPoint("LEFT", self, "LEFT", 0, 0)
			button:SetPoint("RIGHT", self, "RIGHT", 0, 0)
			if previous then
				button:SetPoint("TOP", previous, "BOTTOM", 0, 0)
			else
				button:SetPoint("TOP", self, "TOP", 0, 0)
			end
			previous = button
		end
	end
end

function SidebarMixin:Select(page)
	for _, button in ipairs(self.buttons) do
		button.selected = (button.page == page)
		updateButtonState(button)
	end
	self.selectedPage = page
	if Panel.Gamepad.SyncPage then
		Panel.Gamepad.SyncPage(page)
	end
	if self.onSelect then
		self.onSelect(page)
	end
end

function SidebarMixin:GetSelectedButton()
	for _, button in ipairs(self.buttons) do
		if button.selected then
			return button
		end
	end
	return self.buttons[1]
end

function SidebarMixin:GetFirstButton()
	return self.buttons[1]
end
