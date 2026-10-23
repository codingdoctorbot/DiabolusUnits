-- Minimap launcher: left-click settings, right-click edit layout, drag to reposition.
-- Account-wide state: Roth_UI_DB_GLOB.minimap = { hide, minimapPos }.
-- Save the angle on drop, suppress minimap input propagation, and ignore SmartNavigation.
-- Ported from PulseHaptics UI/Minimap.lua; also exposes a launcher when LDB is available.

local ADDON_NAME, ns = ...

ns.UI = ns.UI or {}
local MinimapButton = {}
ns.UI.Minimap = MinimapButton

local ICON = "Interface\\AddOns\\DiabolusUnits\\media\\d2_skull"
local DEFAULT_ANGLE = 200

local buttonFrame
local isDragging = false

local function config()
	if type(Roth_UI_DB_GLOB) ~= "table" then
		return { hide = false, minimapPos = DEFAULT_ANGLE }
	end
	local cfg = Roth_UI_DB_GLOB.minimap
	if type(cfg) ~= "table" then
		cfg = { hide = false, minimapPos = DEFAULT_ANGLE }
		Roth_UI_DB_GLOB.minimap = cfg
	end
	return cfg
end
MinimapButton.Config = config

local function radius()
	local width = Minimap and Minimap:GetWidth() or 140
	if not width or width <= 0 then
		width = 140
	end
	return width / 2 + 6
end

local function place(angle)
	if not buttonFrame then
		return
	end
	local rad = math.rad(angle or DEFAULT_ANGLE)
	buttonFrame:ClearAllPoints()
	buttonFrame:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius(), math.sin(rad) * radius())
end

local function fillTooltip(tip)
	tip:AddLine("DiabolusUnits", 0.86, 0.62, 0.28)
	tip:AddLine(" ")
	tip:AddLine("|cffdb9e47Left-click:|r settings", 0.93, 0.87, 0.74)
	tip:AddLine("|cffdb9e47Right-click:|r edit layout", 0.93, 0.87, 0.74)
	tip:AddLine("|cff94806aDrag:|r move this button", 0.58, 0.50, 0.40)
end

local function openSettings()
	if ns.UI.Panel and ns.UI.Panel.Toggle then
		ns.UI.Panel.Toggle()
	end
end

local function toggleEditLayout()
	if InCombatLockdown() then
		return
	end
	if ns.EditMode and ns.EditMode.Toggle then
		ns.EditMode:Toggle()
	end
end

local function create()
	if buttonFrame or not Minimap then
		return buttonFrame
	end

	local btn = CreateFrame("Button", "DiabolusUnitsMinimapButton", Minimap)
	btn:SetSize(32, 32)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel((Minimap:GetFrameLevel() or 8) + 5)
	btn:RegisterForClicks("AnyUp")
	btn:RegisterForDrag("LeftButton")
	if btn.SetPropagateMouseClicks then
		btn:SetPropagateMouseClicks(false)
	end
	if btn.SetPropagateMouseMotion then
		btn:SetPropagateMouseMotion(false)
	end
	if ns.UI.Panel and ns.UI.Panel.Theme then
		ns.UI.Panel.Theme.MarkIgnored(btn)
	end

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(22, 22)
	bg:SetPoint("CENTER")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetVertexColor(0, 0, 0, 0.9)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(22, 22)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetTexture(ICON)
	btn.Icon = icon

	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetSize(24, 24)
	hl:SetPoint("CENTER")
	hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	hl:SetBlendMode("ADD")

	btn:SetScript("OnEnter", function(self)
		if isDragging then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:ClearLines()
		fillTooltip(GameTooltip)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	btn:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			toggleEditLayout()
		else
			openSettings()
		end
	end)

	local angle
	btn:SetScript("OnDragStart", function(self)
		isDragging = true
		GameTooltip:Hide()
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			if not mx then
				return
			end
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale() or 1
			angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
			place(angle)
		end)
	end)
	btn:SetScript("OnDragStop", function(self)
		isDragging = false
		self:SetScript("OnUpdate", nil)
		if angle then
			config().minimapPos = angle
		end
	end)

	Minimap:HookScript("OnShow", function()
		MinimapButton:Refresh()
	end)
	Minimap:HookScript("OnHide", function()
		if buttonFrame then
			buttonFrame:Hide()
		end
	end)

	buttonFrame = btn
	return btn
end

local function initLDB()
	local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
	if not ldb or ldb:GetDataObjectByName("DiabolusUnits") then
		return
	end
	ldb:NewDataObject("DiabolusUnits", {
		type = "launcher",
		text = "DiabolusUnits",
		icon = ICON,
		OnClick = function(_, button)
			if button == "RightButton" then
				toggleEditLayout()
			else
				openSettings()
			end
		end,
		OnTooltipShow = function(tip)
			if tip and tip.AddLine then
				fillTooltip(tip)
			end
		end,
	})
end

function MinimapButton:Refresh()
	local btn = create()
	if not btn then
		return
	end
	local cfg = config()
	if cfg.hide or not Minimap:IsShown() then
		btn:Hide()
	else
		btn:Show()
		place(cfg.minimapPos)
	end
end

function MinimapButton:SetShown(shown)
	config().hide = not shown
	self:Refresh()
end

function MinimapButton:IsShownSetting()
	return not config().hide
end

-- Saved variables are in by PLAYER_LOGIN; the minimap has its final size by PLAYER_ENTERING_WORLD
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		initLDB()
	else
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
	MinimapButton:Refresh()
end)
