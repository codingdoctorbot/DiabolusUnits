---------------------------------------------
--  DiabolusUnits - Seamless Gamepad <-> Standard Mode
---------------------------------------------
-- Automatically adapts the Diablo HUD between:
--   1. Gamepad Mode (WoW Forever's native Crossbar):
--      - Orbs wide (±325), Statues at (-355 / +350), Bottom Stone Ledge (670px),
--        Potion Belt beside Health Orb, Crossbar unobstructed.
--   2. Standard (Keyboard/Mouse) Mode:
--      - Orbs hug the compact 12-slot stone bar (±265, Statues at -295 / +290),
--        zork's bar1/bar2/bar3 crossed-sword slot grid (512x256) shown at bottom,
--        Blizzard's ActionButton1..12 & MultiBars scaled/aligned out of combat
--        directly into the 12 stone slots via ns.Blizz (C base methods, zero taint),
--        and Game Menu (Micro Menu) + Bag buttons docked on sculpted outer wings.

local _, ns = ...

local cfg = ns.cfg
local Blizz = ns.Blizz
local func = ns.func

local StandardMode = {}
ns.StandardMode = StandardMode

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"

local pendingApply = false
local microDock = nil
local bagDock = nil

local MICRO_LIST = {
	"CharacterMicroButton",
	"SpellbookMicroButton",
	"TalentMicroButton",
	"AchievementMicroButton",
	"QuestLogMicroButton",
	"SocialsMicroButton",
	"GuildMicroButton",
	"PVPMicroButton",
	"LFGMicroButton",
	"CollectionsMicroButton",
	"EJMicroButton",
	"StoreMicroButton",
	"MainMenuMicroButton",
	"HelpMicroButton",
}

local BAG_LIST = {
	"MainMenuBarBackpackButton",
	"CharacterBag0Slot",
	"CharacterBag1Slot",
	"CharacterBag2Slot",
	"CharacterBag3Slot",
	"KeyRingButton",
}

-- True when WoW Forever's native Gamepad UI / Crossbar is active
function StandardMode:IsGamepad()
	if C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and Enum and Enum.InputDeviceInterfaceType then
		local style = C_InputInterfaceStyle.GetCurrentStyle()
		if style ~= nil then
			return style == Enum.InputDeviceInterfaceType.Gamepad
		end
	end
	if GamepadMainActionBarFrame and GamepadMainActionBarFrame.IsShown and GamepadMainActionBarFrame:IsShown() then
		return true
	end
	return false
end

local function IsUserMoved(frameName)
	local prof = ns.LayoutProfile and ns.LayoutProfile()
	return prof and prof.framePositions and prof.framePositions[frameName] ~= nil
end

-- Safely hide Blizzard's decorative actionbar art & duplicate status bars
local function HideBlizzardBarArt()
	local artTextures = {
		"MainMenuBarLeftEndCap",
		"MainMenuBarRightEndCap",
		"MainMenuBarTexture0",
		"MainMenuBarTexture1",
		"MainMenuBarTexture2",
		"MainMenuBarTexture3",
		"MainMenuBarTextureExtender",
		"MainMenuBarArtFrameBackground",
		"SlidingActionBarTexture0",
		"SlidingActionBarTexture1",
		"StanceBarLeft",
		"StanceBarMiddle",
		"StanceBarRight",
		"MainMenuMaxLevelBar0",
		"MainMenuMaxLevelBar1",
		"MainMenuMaxLevelBar2",
		"MainMenuMaxLevelBar3",
		"MainMenuXPBarTexture0",
		"MainMenuXPBarTexture1",
		"MainMenuXPBarTexture2",
		"MainMenuXPBarTexture3",
		"MainMenuXPBarTextureLeftCap",
		"MainMenuXPBarTextureRightCap",
		"MainMenuXPBarTextureMid",
		"ReputationWatchBarTexture0",
		"ReputationWatchBarTexture1",
		"ReputationWatchBarTexture2",
		"ReputationWatchBarTexture3",
	}
	for _, name in ipairs(artTextures) do
		local tex = _G[name]
		if tex and tex.SetAlpha then
			tex:SetAlpha(0)
			if tex.Hide then
				pcall(tex.Hide, tex)
			end
		end
	end

	local pageFrames = {
		"ActionBarUpButton",
		"ActionBarDownButton",
		"MainMenuBarPageNumber",
		"MainMenuBarPerformanceBar",
		"MainMenuBarPerformanceBarFrame",
		"MainMenuBarPerformanceBarFrameButton",
		"MainMenuBarMaxLevelBar",
		"MainMenuExpBar",
		"ReputationWatchBar",
	}
	for _, name in ipairs(pageFrames) do
		local f = _G[name]
		if f then
			f:SetAlpha(0)
			if f.EnableMouse then
				pcall(f.EnableMouse, f, false)
			end
		end
	end

	if Blizz and Blizz.Conceal then
		Blizz.Conceal(_G.StatusTrackingBarManager)
		Blizz.Conceal(_G.MainStatusTrackingBarContainer)
		Blizz.Conceal(_G.SecondaryStatusTrackingBarContainer)
	end
end

-- Fit a 12-button Blizzard action bar row into zork's bar1/bar2/bar3 512x256 stone slot grid:
-- In the 512x256 texture, the 12 slots span x = 67..443 (376px wide, 31.5px center-to-center),
-- with row 1 center at y = 36.5, row 2 center at y = 67.5, row 3 center at y = 105 from bottom.
local function FitActionBarRow(prefix, rowBottomY, barFrame)
	if not barFrame then
		return
	end
	local firstBtn = _G[prefix .. "1"]
	if not firstBtn then
		return
	end
	local rawW = firstBtn:GetWidth() or 36
	if rawW <= 0 then
		rawW = 36
	end
	-- Target button visual size = 27px inside each 30px stone slot, pitch = 31.45px
	local btnScale = 27 / rawW

	for i = 1, 12 do
		local btn = _G[prefix .. i]
		if btn then
			Blizz.SetScale(btn, btnScale)
			Blizz.ClearAllPoints(btn)
			if i == 1 then
				-- Anchor button 1 precisely at left slot center (-173.0 in barFrame units)
				Blizz.SetPoint(btn, "CENTER", barFrame, "BOTTOM", -173.0 / btnScale, (rowBottomY + 13.5) / btnScale)
			else
				local prev = _G[prefix .. (i - 1)]
				Blizz.SetPoint(btn, "LEFT", prev, "RIGHT", (31.45 - 27) / btnScale, 0)
			end
			-- Trim default quickslot oversized border so icon sits cleanly inside the stone slot
			local nt = btn.GetNormalTexture and btn:GetNormalTexture()
			if nt then
				nt:SetAlpha(0.35)
			end
		end
	end
end

-- Create a Diablo stone-trimmed dock with mouseover fade for Micro Menu or Bags
local function CreateDock(name, labelText, defaultX, defaultY, width, height)
	local dock = CreateFrame("Frame", name, UIParent)
	dock:SetSize(width, height)
	dock:SetFrameStrata("LOW")
	dock:SetFrameLevel(8)
	dock:SetPoint("BOTTOM", UIParent, "BOTTOM", defaultX, defaultY)
	dock.defaultPosition = { a1 = "BOTTOM", af = "UIParent", a2 = "BOTTOM", x = defaultX, y = defaultY }

	-- Subtle Diablo stone shelf backdrop
	local bg = dock:CreateTexture(nil, "BACKGROUND", nil, 1)
	bg:SetPoint("TOPLEFT", dock, "TOPLEFT", -6, 4)
	bg:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 6, -4)
	bg:SetTexture(MEDIA .. "Tooltip_Background")
	bg:SetVertexColor(0.12, 0.10, 0.08, 0.85)
	dock.bg = bg

	local topLine = dock:CreateTexture(nil, "BORDER", nil, 2)
	topLine:SetPoint("TOPLEFT", bg, "TOPLEFT", 2, 0)
	topLine:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -2, 0)
	topLine:SetHeight(1)
	topLine:SetColorTexture(0.42, 0.33, 0.21, 0.8)

	local botLine = dock:CreateTexture(nil, "BORDER", nil, 2)
	botLine:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 2, 0)
	botLine:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -2, 0)
	botLine:SetHeight(1)
	botLine:SetColorTexture(0.22, 0.17, 0.11, 0.9)

	if func and func.applyDragFunctionality then
		func.applyDragFunctionality(dock)
		if dock.dragframe then
			local lbl = dock.dragframe:CreateFontString(nil, "OVERLAY")
			lbl:SetFont(cfg.font or "Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
			lbl:SetPoint("CENTER", 0, 0)
			lbl:SetText(labelText)
		end
	end

	return dock
end

local function WireDockHover(dock, buttons)
	local idleAlpha = (cfg.standardMode and cfg.standardMode.dockFadeAlpha) or 0.45
	dock:SetAlpha(idleAlpha)

	local function onEnter()
		dock:SetAlpha(1)
	end
	local function onLeave()
		if not dock:IsMouseOver() then
			dock:SetAlpha(idleAlpha)
		end
	end

	dock:HookScript("OnEnter", onEnter)
	dock:HookScript("OnLeave", onLeave)
	for _, btn in ipairs(buttons) do
		if btn and not btn._diabolusHoverHooked then
			btn._diabolusHoverHooked = true
			btn:HookScript("OnEnter", onEnter)
			btn:HookScript("OnLeave", onLeave)
		end
	end
end

local function SetupMicroDock(isPad)
	local sm = cfg.standardMode
	if not (sm and sm.integrateMicroMenu) then
		return
	end
	if not microDock then
		-- Docked on the left outer wing (outside the Demon statue)
		microDock = CreateDock("Roth_UIMicroDock", "Micro Menu", -495, 8, 230, 30)
	end
	if isPad then
		microDock:Hide()
		return
	end
	microDock:Show()

	local activeBtns = {}
	for _, name in ipairs(MICRO_LIST) do
		local btn = _G[name]
		if btn and btn:IsShown() then
			activeBtns[#activeBtns + 1] = btn
		end
	end
	if #activeBtns == 0 then
		return
	end

	local scale = 0.72
	local gap = -2
	local totalW = 0
	for i, btn in ipairs(activeBtns) do
		Blizz.SetScale(btn, scale)
		Blizz.ClearAllPoints(btn)
		local bw = (btn:GetWidth() or 28) * scale
		if i == 1 then
			Blizz.SetPoint(btn, "LEFT", microDock, "LEFT", 2 / scale, 0)
		else
			Blizz.SetPoint(btn, "LEFT", activeBtns[i - 1], "RIGHT", gap / scale, 0)
		end
		totalW = totalW + bw + (i > 1 and gap or 0)
	end
	microDock:SetWidth(math.max(160, totalW + 8))
	WireDockHover(microDock, activeBtns)
end

local function SetupBagDock(isPad)
	local sm = cfg.standardMode
	if not (sm and sm.integrateBags) then
		return
	end
	if not bagDock then
		-- Docked on the right outer wing (outside the Angel statue)
		bagDock = CreateDock("Roth_UIBagDock", "Bag Bar", 465, 8, 175, 32)
	end
	if isPad then
		bagDock:Hide()
		return
	end
	bagDock:Show()

	local activeBtns = {}
	for _, name in ipairs(BAG_LIST) do
		local btn = _G[name]
		if btn and (name ~= "KeyRingButton" or btn:IsShown()) then
			activeBtns[#activeBtns + 1] = btn
		end
	end
	if #activeBtns == 0 then
		return
	end

	local scale = 0.76
	local gap = 3
	local totalW = 0
	for i, btn in ipairs(activeBtns) do
		Blizz.SetScale(btn, scale)
		Blizz.ClearAllPoints(btn)
		local bw = (btn:GetWidth() or 32) * scale
		if i == 1 then
			Blizz.SetPoint(btn, "RIGHT", bagDock, "RIGHT", -2 / scale, 0)
		else
			Blizz.SetPoint(btn, "RIGHT", activeBtns[i - 1], "LEFT", -gap / scale, 0)
		end
		totalW = totalW + bw + (i > 1 and gap or 0)
	end
	bagDock:SetWidth(math.max(120, totalW + 8))
	WireDockHover(bagDock, activeBtns)
end

-- Apply mode-appropriate layout (always runs out of combat)
function StandardMode:Apply()
	if not (cfg.standardMode and cfg.standardMode.enabled) then
		return
	end
	if InCombatLockdown() then
		pendingApply = true
		return
	end
	pendingApply = false

	local isPad = self:IsGamepad()
	local sm = cfg.standardMode
	local orbX = isPad and (sm.padOrbX or 325) or (sm.standardOrbX or 265)
	local demonX = -(orbX + 30)
	local angelX = orbX + 25
	local bottomW = isPad and 670 or 550

	local pframe = _G.Roth_UIPlayerFrame
	local powerOrb = _G.Roth_UIPowerOrb
	local demon = _G.Roth_UIDemonFrame
	local angel = _G.Roth_UIAngelFrame
	local bottomLine = _G.Roth_UIBottomLine
	local barBg = _G.Roth_UIActionBarBackground

	if pframe and not IsUserMoved("Roth_UIPlayerFrame") then
		pframe:ClearAllPoints()
		pframe:SetPoint("BOTTOM", UIParent, "BOTTOM", -orbX, cfg.units.player.pos.y or 10)
	end
	if powerOrb and not IsUserMoved("Roth_UIPowerOrb") then
		powerOrb:ClearAllPoints()
		powerOrb:SetPoint("BOTTOM", UIParent, "BOTTOM", orbX, cfg.units.player.pos.y or 10)
	end
	if demon and not IsUserMoved("Roth_UIDemonFrame") then
		demon:ClearAllPoints()
		demon:SetPoint("BOTTOM", UIParent, "BOTTOM", demonX, cfg.units.player.art.demon.pos.y or 6)
	end
	if angel and not IsUserMoved("Roth_UIAngelFrame") then
		angel:ClearAllPoints()
		angel:SetPoint("BOTTOM", UIParent, "BOTTOM", angelX, cfg.units.player.art.angel.pos.y or 6)
	end
	if bottomLine and not IsUserMoved("Roth_UIBottomLine") then
		bottomLine:SetSize(bottomW, 112)
	end

	-- Refresh bar1/bar2/bar3 stone grid & XP/Rep bar layout
	if ns.PlayerArt and ns.PlayerArt.refresh then
		ns.PlayerArt.refresh()
	end
	if ns.bars and ns.bars.UpdateStatusBarLayout then
		ns.bars.UpdateStatusBarLayout()
	end

	-- Position Potion Belt: in Gamepad mode beside Health Orb; in Standard mode above the Health Orb's inner shoulder so it clears the 3 action bar rows
	local belt = _G.Roth_UIBelt
	if belt and not IsUserMoved("Roth_UIBelt") and pframe then
		belt:ClearAllPoints()
		if isPad then
			belt:SetPoint("BOTTOMLEFT", pframe, "BOTTOMRIGHT", cfg.belt.x or 6, cfg.belt.y or 24)
		else
			belt:SetPoint("BOTTOM", pframe, "TOP", 0, -6)
		end
	end

	if not isPad then
		HideBlizzardBarArt()
		if sm.integrateActionBars and barBg then
			FitActionBarRow("ActionButton", 23, barBg)
			if MultiBarBottomLeft and MultiBarBottomLeft:IsShown() then
				FitActionBarRow("MultiBarBottomLeftButton", 54, barBg)
				if MultiBarBottomRight and MultiBarBottomRight:IsShown() then
					FitActionBarRow("MultiBarBottomRightButton", 91, barBg)
				end
			elseif MultiBarBottomRight and MultiBarBottomRight:IsShown() then
				FitActionBarRow("MultiBarBottomRightButton", 54, barBg)
			end
		end
	end

	SetupMicroDock(isPad)
	SetupBagDock(isPad)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if pendingApply then
			StandardMode:Apply()
		end
		return
	end
	StandardMode:Apply()
	if C_Timer and C_Timer.After then
		C_Timer.After(0.4, function()
			StandardMode:Apply()
		end)
	end
end)

if MultiBarBottomLeft then
	MultiBarBottomLeft:HookScript("OnShow", function()
		StandardMode:Apply()
	end)
	MultiBarBottomLeft:HookScript("OnHide", function()
		StandardMode:Apply()
	end)
end
if MultiBarBottomRight then
	MultiBarBottomRight:HookScript("OnShow", function()
		StandardMode:Apply()
	end)
	MultiBarBottomRight:HookScript("OnHide", function()
		StandardMode:Apply()
	end)
end
