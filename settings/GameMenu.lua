-- Diabolus settings shortcut above Forever's native Game Menu.
-- The banner is ours, parented to UIParent. Never alter GameMenuFrame.buttons,
-- native navigation tables, or the panel's working native controller input.
local _, ns = ...
local Panel = ns.UI.Panel
local Theme = Panel.Theme
local Menu = {}
Panel.GameMenu = Menu

local BUTTON_NAME, PAD_KEY = "DiabolusGameMenuButton", "PAD4"
local HEIGHT, BUTTON_HEIGHTS = 44, 3
local banner, hookedMenu
local bound, cleanupPending, opening = false, false, false

local function inCombat()
	return InCombatLockdown()
end

local function menuShown()
	return _G.GameMenuFrame and _G.GameMenuFrame:IsShown()
end

local function refreshPrompt()
	if not banner then
		return
	end
	if not bound then
		banner.Subtitle:SetText("Click to open settings")
		return
	end
	local manager = _G.InputDeviceIconSetManager
	local style = manager and manager.GetActiveInputDeviceIconSet and manager:GetActiveInputDeviceIconSet()
	if style == "Letters" then
		banner.Subtitle:SetText("|A:gamepad-xbox1-buttony-normal:16:16|a Y: open settings")
	elseif style == "Reverse" then
		banner.Subtitle:SetText("|A:gamepad-switch-128x-face-x-normal:16:16|a X: open settings")
	else
		banner.Subtitle:SetText("|A:gamepad-ps-buttontriangle-normal:16:16|a Triangle: open settings")
	end
end

local function clearBinding()
	if not banner or not bound then
		return
	end
	if inCombat() then
		cleanupPending = true
		return
	end
	ClearOverrideBindings(banner)
	bound, cleanupPending = false, false
	refreshPrompt()
end

local function bindShortcut()
	if not banner or not menuShown() or inCombat() or Panel.IsShown() then
		return
	end
	local action = "CLICK " .. BUTTON_NAME .. ":LeftButton"
	if bound and GetBindingAction and GetBindingAction(PAD_KEY, true) == action then
		return
	end
	ClearOverrideBindings(banner)
	-- One visible button, one menu-only shortcut. Does not capture settings-panel input.
	SetOverrideBindingClick(banner, true, PAD_KEY, BUTTON_NAME, "LeftButton")
	bound = true
	refreshPrompt()
end

local function layoutBanner()
	local menu = _G.GameMenuFrame
	if not menu or not banner then
		return
	end
	local k = menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local height = 24
	for _, button in ipairs(menu.buttons or {}) do
		if button.GetHeight and button:GetHeight() > 0 then
			height = button:GetHeight() * button:GetEffectiveScale() / UIParent:GetEffectiveScale()
			break
		end
	end
	local gap = height * BUTTON_HEIGHTS
	local top = menu:GetTop()
	if top then
		local available = UIParent:GetHeight() - top * k - HEIGHT - 12
		gap = math.max(8, math.min(gap, available))
	end
	local width = math.max(220, menu:GetWidth() * k)
	banner:SetSize(width, HEIGHT)
	banner.Title:SetWidth(width - 56)
	banner.Subtitle:SetWidth(width - 56)
	banner:SetFrameLevel(menu:GetFrameLevel() + 5)
	banner:ClearAllPoints()
	banner:SetPoint("BOTTOM", menu, "TOP", 0, gap)
end

local function activate()
	if opening or inCombat() or not menuShown() then
		return
	end
	opening = true
	clearBinding()
	-- Let the native menu finish handling this press before dismissing it.
	C_Timer.After(0, function()
		opening = false
		if inCombat() or not menuShown() then
			return
		end
		-- Frame:Hide() alone leaves Forever's controller focus/catcher bindings active.
		HideUIPanel(_G.GameMenuFrame)
		if _G.GameMenuFrame:IsShown() then
			return
		end
		Panel.Open()
	end)
end

local function createBanner()
	if banner then
		return
	end
	local b = CreateFrame("Button", BUTTON_NAME, UIParent)
	b:SetSize(240, HEIGHT)
	b:SetFrameStrata("DIALOG")
	b:SetClampedToScreen(true)
	b:EnableMouse(true)
	b:RegisterForClicks("AnyUp")
	b:Hide()
	local fill = Theme.CreateSurface(b, Theme.COLOR_BG)
	local mark = b:CreateTexture(nil, "ARTWORK")
	mark:SetPoint("TOPLEFT", 0, 0)
	mark:SetPoint("BOTTOMLEFT", 0, 0)
	mark:SetWidth(2)
	mark:SetColorTexture(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b, 1)
	local icon = Theme.CreateIcon(b, "brand", 20)
	icon:SetPoint("LEFT", b, "LEFT", 12, 0)
	icon:SetIconColor(Theme.COLOR_ACCENT)
	local title = b:CreateFontString(nil, "OVERLAY", Theme.FONT_NORMAL)
	title:SetPoint("TOPLEFT", b, "TOPLEFT", 44, -7)
	title:SetJustifyH("LEFT")
	title:SetText("DiabolusUnits")
	title:SetTextColor(Theme.COLOR_TEXT_PRIMARY.r, Theme.COLOR_TEXT_PRIMARY.g, Theme.COLOR_TEXT_PRIMARY.b)
	local subtitle = b:CreateFontString(nil, "OVERLAY", Theme.FONT_CHILD)
	subtitle:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 44, 7)
	subtitle:SetJustifyH("LEFT")
	b.Title, b.Subtitle = title, subtitle
	b:SetScript("OnClick", activate)
	b:SetScript("OnEnter", function()
		fill:SetColorTexture(0.14, 0.12, 0.095, 1)
	end)
	b:SetScript("OnLeave", function()
		local c = Theme.COLOR_BG
		fill:SetColorTexture(c.r, c.g, c.b, 1)
	end)
	Theme.MarkIgnored(b)
	banner = b
	refreshPrompt()
end

local function onMenuShow()
	C_Timer.After(0, function()
		if not menuShown() or inCombat() then
			return
		end
		layoutBanner()
		banner:Show()
		bindShortcut()
	end)
end

local function onMenuHide()
	if banner then
		banner:Hide()
	end
	clearBinding()
end

local function hookMenu()
	local menu = _G.GameMenuFrame
	if not menu or hookedMenu == menu then
		return
	end
	createBanner()
	hookedMenu = menu
	menu:HookScript("OnShow", onMenuShow)
	menu:HookScript("OnHide", onMenuHide)
	if menu:IsShown() then
		onMenuShow()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		onMenuHide()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if cleanupPending then
			clearBinding()
		end
		if menuShown() then
			onMenuShow()
		end
	else
		hookMenu()
		refreshPrompt()
	end
end)
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("Gamepad.RefreshFrameFocus", function()
		if menuShown() then
			C_Timer.After(0, bindShortcut)
		end
	end, Menu)
end
local manager = _G.InputDeviceIconSetManager
if manager and manager.RegisterActiveInputDeviceIconSetUpdatedCallback then
	manager:RegisterActiveInputDeviceIconSetUpdatedCallback(refreshPrompt, Menu)
end
hookMenu()
