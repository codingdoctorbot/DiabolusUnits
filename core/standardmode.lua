---------------------------------------------
--  DiabolusUnits - Seamless Gamepad <-> Standard Mode
---------------------------------------------
-- Automatically adapts the Diablo HUD between:
--   1. Gamepad Mode (WoW Forever's native Crossbar):
--      - Orbs wide (±325), Statues at (-355 / +350), Bottom Stone Ledge (670px),
--        Potion Belt beside Health Orb, Crossbar unobstructed.
--   2. Standard (Keyboard/Mouse) Mode:
--      - Orbs hug the scaled 12-slot stone bar (±300, Statues at -330 / +325),
--        zork's bar1/bar2/bar3 crossed-sword slot grid (512x256 @ 1.18x) shown at bottom,
--        Blizzard's ActionButton1..12, MultiBars & Paging +/- buttons aligned out of combat
--        directly into the stone slots via ns.Blizz (C base methods, zero taint),
--        Potion Belt anchored to the top-left of the uppermost active action bar row,
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

-- Weak-key tables to track hooks on Blizzard frames without writing fields onto Blizzard tables (zero taint)
local artHooked = setmetatable({}, { __mode = "k" })
local layoutHooked = setmetatable({}, { __mode = "k" })
local hoverHooked = setmetatable({}, { __mode = "k" })
local anchorHooked = setmetatable({}, { __mode = "k" })
local mouseDisabledHooked = setmetatable({}, { __mode = "k" })
local krbHooked = setmetatable({}, { __mode = "k" })
local krbTextureHooked = setmetatable({}, { __mode = "k" })

local BAG_LIST = {
	"MainMenuBarBackpackButton",
	"CharacterBag0Slot",
	"CharacterBag1Slot",
	"CharacterBag2Slot",
	"CharacterBag3Slot",
	"CharacterReagentBag0Slot",
	"KeyRingButton",
}

-- Drop Blizzard action bar containers to BACKGROUND and disable mouse input so they cannot
-- intercept clicks over buttons situated in the stone grid (e.g. Action Bar 3 row)
local function DeactivateBarContainerMouse(bar)
	if not bar then
		return
	end
	if not InCombatLockdown() then
		bar:EnableMouse(false)
		bar:SetFrameStrata("BACKGROUND")
		bar:SetFrameLevel(0)
	end
	if not mouseDisabledHooked[bar] then
		mouseDisabledHooked[bar] = true
		hooksecurefunc(bar, "EnableMouse", function(self, enabled)
			if enabled and not InCombatLockdown() then
				self:EnableMouse(false)
			end
		end)
		if bar.SetFrameStrata then
			hooksecurefunc(bar, "SetFrameStrata", function(self, strata)
				if strata ~= "BACKGROUND" and not InCombatLockdown() then
					self:SetFrameStrata("BACKGROUND")
				end
			end)
		end
		if bar.SetFrameLevel then
			hooksecurefunc(bar, "SetFrameLevel", function(self, level)
				if level ~= 0 and not InCombatLockdown() then
					self:SetFrameLevel(0)
				end
			end)
		end
	end
end

local KEY_ICON = "Interface\\Icons\\INV_Misc_Key_03"

local function EnsureKeyRingTexture(krb)
	if not krb then
		return
	end
	local icon = krb.icon or _G.KeyRingButtonIconTexture or krb.Icon
	if not icon and krb.CreateTexture then
		icon = krb:CreateTexture(krb:GetName() and (krb:GetName() .. "IconTexture") or nil, "BORDER")
		icon:SetAllPoints()
		krb.icon = icon
	end
	if icon then
		icon:SetTexture(KEY_ICON)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:SetAlpha(1)
		icon:Show()
		if not krbTextureHooked[icon] then
			krbTextureHooked[icon] = true
			if icon.SetTexture then
				hooksecurefunc(icon, "SetTexture", function(self, tex)
					if not tex or tex == "" or tex == "Interface\\PaperDoll\\UI-Backpack-EmptySlot" then
						self:SetTexture(KEY_ICON)
						self:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					end
				end)
			end
			if icon.SetAtlas then
				hooksecurefunc(icon, "SetAtlas", function(self, atlas)
					if not atlas or atlas == "" or (type(atlas) == "string" and atlas:find("Slot")) then
						self:SetTexture(KEY_ICON)
						self:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					end
				end)
			end
		end
	end
	if krb.GetNormalTexture then
		local nt = krb:GetNormalTexture()
		if nt and not nt:GetTexture() then
			nt:SetTexture(KEY_ICON)
			nt:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			nt:SetAlpha(1)
		end
	end
end

local function CustomKeyRingOnClick(self, button)
	if CursorHasItem and CursorHasItem() and PutKeyInKeyRing then
		PutKeyInKeyRing()
	elseif ToggleBag then
		ToggleBag(KEYRING_CONTAINER or -2)
	elseif OpenBag and CloseBag and IsBagOpen then
		local id = KEYRING_CONTAINER or -2
		if IsBagOpen(id) then
			CloseBag(id)
		else
			OpenBag(id)
		end
	end
end

local function SetupKeyRingButton(krb)
	if not krb then
		return
	end
	if SetCVar and GetCVar and GetCVar("showKeyring") ~= nil then
		pcall(SetCVar, "showKeyring", 1)
	end
	krb.includeInLayout = false
	krb:Enable()
	if not InCombatLockdown() then
		krb:Show()
		krb:SetAlpha(1)
		krb:SetSize(33, 45)
	end
	EnsureKeyRingTexture(krb)

	krb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	krb:SetScript("OnClick", CustomKeyRingOnClick)

	if not krb:GetScript("OnEnter") then
		krb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(KEYRING or "Keyring", 1, 1, 1)
			GameTooltip:Show()
		end)
		krb:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
	else
		if not krbHooked[krb] then
			krb:HookScript("OnEnter", function(self)
				if not GameTooltip:IsShown() then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:SetText(KEYRING or "Keyring", 1, 1, 1)
					GameTooltip:Show()
				end
			end)
		end
	end

	if not krbHooked[krb] then
		krbHooked[krb] = true
		hooksecurefunc(krb, "Disable", function(self)
			self:Enable()
		end)
		hooksecurefunc(krb, "Hide", function(self)
			if not InCombatLockdown() then
				self:Show()
			end
		end)
		hooksecurefunc(krb, "SetScript", function(self, scriptType, handler)
			if scriptType == "OnClick" and handler ~= CustomKeyRingOnClick then
				self:SetScript("OnClick", CustomKeyRingOnClick)
			end
		end)
		if krb.UpdateTextures then
			hooksecurefunc(krb, "UpdateTextures", function(self)
				EnsureKeyRingTexture(self)
			end)
		end
		if krb.OnBagUpdate then
			hooksecurefunc(krb, "OnBagUpdate", function(self)
				EnsureKeyRingTexture(self)
			end)
		end
		if krb.Update then
			hooksecurefunc(krb, "Update", function(self)
				EnsureKeyRingTexture(self)
			end)
		end
	end
end

local function StyleBagItemButton(btn)
	if not btn or btn.__styled then
		return
	end
	if rButtonTemplate and rButtonTemplate.StyleItemButton and ns.itemButtonConfig then
		rButtonTemplate:StyleItemButton(btn, ns.itemButtonConfig)
	end
end

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

-- Default scale per mode for the frames the layout sizes. Edit layout reads these
-- through StandardMode:DefaultScale, so wheel-scaling starts from what is on screen.
function StandardMode:DefaultScales(isPad)
	local sm = cfg.standardMode or {}
	if isPad then
		return {
			Roth_UIActionBarBackground = 1,
			Roth_UIPlayerFrame = 1,
			Roth_UIDemonFrame = 1,
			Roth_UIAngelFrame = 1,
			Roth_UIPlayerFrameCastBarDragFrame = 1,
			Roth_UITargetFrame = sm.targetScale or 1,
		}
	end
	return {
		Roth_UIActionBarBackground = sm.standardBarScale or 1.18,
		Roth_UIPlayerFrame = sm.standardOrbScale or 1, -- both orbs: the power orb is its child
		Roth_UIDemonFrame = sm.standardStatueScale or 1,
		Roth_UIAngelFrame = sm.standardStatueScale or 1,
		-- the cast bar is a child of the player frame: undo the orb scale so it keeps its size
		Roth_UIPlayerFrameCastBarDragFrame = 1 / (sm.standardOrbScale or 1),
		Roth_UITargetFrame = sm.targetScale or 1,
	}
end

function StandardMode:DefaultScale(name)
	if not (cfg.standardMode and cfg.standardMode.enabled) then
		return nil
	end
	return self:DefaultScales(self:IsGamepad())[name]
end

-- BOTTOM-anchor a frame to UIParent with x/y given in UIParent units,
-- whatever the frame's own (possibly inherited) scale is
local function PlaceAtBottom(f, x, y)
	local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
	f:ClearAllPoints()
	f:SetPoint("BOTTOM", UIParent, "BOTTOM", x / k, y / k)
end

local function HideDividerPools(frame)
	if not frame then
		return
	end
	if frame.HorizontalDividersPool and frame.HorizontalDividersPool.EnumerateActive then
		for div in frame.HorizontalDividersPool:EnumerateActive() do
			div:SetAlpha(0)
		end
	end
	if frame.VerticalDividersPool and frame.VerticalDividersPool.EnumerateActive then
		for div in frame.VerticalDividersPool:EnumerateActive() do
			div:SetAlpha(0)
		end
	end
end

-- Safely hide Blizzard's decorative actionbar art, EndCaps (Left/Right), borders, dividers & duplicate status bars
local function HideBlizzardBarArt()
	-- 1. WoW Forever (Camelot) MainActionBar EndCaps, BorderArt, and Dividers (keep ActionBarPageNumber for +/- paging!)
	local mab = _G.MainActionBar
	if mab then
		DeactivateBarContainerMouse(mab)
		if mab.BorderArt then
			mab.BorderArt:SetAlpha(0)
		end
		if mab.EndCaps then
			if mab.EndCaps.LeftEndCap then
				mab.EndCaps.LeftEndCap:SetAlpha(0)
			end
			if mab.EndCaps.RightEndCap then
				mab.EndCaps.RightEndCap:SetAlpha(0)
			end
			mab.EndCaps:SetAlpha(0)
		end
		HideDividerPools(mab)
		if not artHooked[mab] then
			artHooked[mab] = true
			if mab.UpdateEndCaps then
				hooksecurefunc(mab, "UpdateEndCaps", function(self)
					if not StandardMode:IsGamepad() and self.EndCaps then
						if self.EndCaps.LeftEndCap then
							self.EndCaps.LeftEndCap:SetAlpha(0)
						end
						if self.EndCaps.RightEndCap then
							self.EndCaps.RightEndCap:SetAlpha(0)
						end
						self.EndCaps:SetAlpha(0)
					end
				end)
			end
			if mab.UpdateDividers then
				hooksecurefunc(mab, "UpdateDividers", function(self)
					if not StandardMode:IsGamepad() then
						HideDividerPools(self)
					end
				end)
			end
		end
	end

	-- 2. Legacy / classic named textures
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
		end
	end

	local statusFrames = {
		"MainMenuBarPerformanceBar",
		"MainMenuBarPerformanceBarFrame",
		"MainMenuBarPerformanceBarFrameButton",
		"MainMenuBarMaxLevelBar",
		"MainMenuExpBar",
		"ReputationWatchBar",
	}
	for _, name in ipairs(statusFrames) do
		local f = _G[name]
		if f and f.SetAlpha then
			f:SetAlpha(0)
		end
	end

	if Blizz and Blizz.Conceal then
		Blizz.Conceal(_G.StatusTrackingBarManager)
		Blizz.Conceal(_G.MainStatusTrackingBarContainer)
		Blizz.Conceal(_G.SecondaryStatusTrackingBarContainer)
	end
end

-- Style an individual action button so its empty slot background is transparent
-- (allowing zork's crossed-sword stone slot grid bar1/bar2/bar3 to show through)
local function StyleActionButtonForStoneSlot(btn)
	if btn.SlotArt then
		btn.SlotArt:SetAlpha(0)
	end
	if btn.SlotBackground then
		btn.SlotBackground:SetAlpha(0)
	end
	local nt = btn.GetNormalTexture and btn:GetNormalTexture()
	if nt then
		nt:SetAlpha(0.25)
	end
	if not artHooked[btn] and btn.UpdateButtonArt then
		artHooked[btn] = true
		hooksecurefunc(btn, "UpdateButtonArt", function(self)
			if self.SlotArt then
				self.SlotArt:SetAlpha(0)
			end
			if self.SlotBackground then
				self.SlotBackground:SetAlpha(0)
			end
		end)
	end
end

-- Position the Action Bar paging +/- buttons and page number on the left stone shoulder beside ActionButton1
local function FitActionBarPaging(barFrame)
	if not barFrame then
		return
	end
	local barEff = barFrame:GetEffectiveScale() or 1
	local mab = _G.MainActionBar
	local pageFrame = mab and mab.ActionBarPageNumber
	if pageFrame then
		pageFrame:SetAlpha(1)
		if pageFrame.Show then
			pageFrame:Show()
		end
		if pageFrame.UpButton then
			pageFrame.UpButton:SetAlpha(1)
			pageFrame.UpButton:Show()
		end
		if pageFrame.DownButton then
			pageFrame.DownButton:SetAlpha(1)
			pageFrame.DownButton:Show()
		end
		if pageFrame.Text then
			pageFrame.Text:SetAlpha(1)
			pageFrame.Text:Show()
		end
		local unitScale = 0.90
		local parent = pageFrame:GetParent()
		local parentEff = (parent and parent:GetEffectiveScale()) or barEff
		local pScale = unitScale * (barEff / parentEff)
		Blizz.SetScale(pageFrame, pScale)
		Blizz.ClearAllPoints(pageFrame)
		-- Slot 1 center is at x = -173.0 (left edge -188); place paging +/- buttons & number on the stone shoulder at x = -197, y = 36.5
		Blizz.SetPoint(pageFrame, "CENTER", barFrame, "BOTTOM", -197 / unitScale, 36.5 / unitScale)
		return
	end

	-- Fallback for classic global ActionBarUpButton / ActionBarDownButton / MainMenuBarPageNumber
	local upBtn = _G.ActionBarUpButton
	local downBtn = _G.ActionBarDownButton
	local pageNum = _G.MainMenuBarPageNumber
	if upBtn and downBtn then
		local unitScale = 0.80
		for _, f in ipairs({ upBtn, downBtn }) do
			f:SetAlpha(1)
			f:Show()
			local parent = f:GetParent()
			local parentEff = (parent and parent:GetEffectiveScale()) or barEff
			Blizz.SetScale(f, unitScale * (barEff / parentEff))
			Blizz.ClearAllPoints(f)
		end
		Blizz.SetPoint(upBtn, "CENTER", barFrame, "BOTTOM", -197 / unitScale, 45 / unitScale)
		Blizz.SetPoint(downBtn, "CENTER", barFrame, "BOTTOM", -197 / unitScale, 28 / unitScale)
		if pageNum then
			pageNum:SetAlpha(1)
			pageNum:ClearAllPoints()
			pageNum:SetPoint("CENTER", barFrame, "BOTTOM", -197, 36.5)
		end
	end
end

-- Fit a 12-button Blizzard action bar row into zork's bar1/bar2/bar3 512x256 stone slot grid:
-- In the 512x256 texture, the 12 slots have centers at x = -173.0 + (i-1)*31.45 from center,
-- with row 1 center at y = 36.5, row 2 center at y = 67.5, row 3 center at y = 104.5 from bottom.
local function FitActionBarRow(prefix, rowBottomY, barFrame)
	if not barFrame then
		return
	end
	local firstBtn = _G[prefix .. "1"]
	if not firstBtn then
		return
	end
	local rawW = firstBtn:GetWidth() or 45
	if rawW <= 0 then
		rawW = 45
	end
	-- Target visual button size = 29px inside each 30px stone slot (in barFrame's 512x256 coordinate space)
	local targetSize = 29
	local unitScale = targetSize / rawW
	local barEff = barFrame:GetEffectiveScale() or 1
	local slotY = rowBottomY + 13.5

	for i = 1, 12 do
		local btn = _G[prefix .. i]
		if btn then
			if btn.container and btn.container.SetScale then
				Blizz.SetScale(btn.container, 1.0)
			end
			local parent = btn:GetParent()
			local parentEff = (parent and parent:GetEffectiveScale()) or barEff
			local btnScale = unitScale * (barEff / parentEff)

			Blizz.SetScale(btn, btnScale)
			Blizz.ClearAllPoints(btn)
			local slotX = -173.0 + (i - 1) * 31.45
			Blizz.SetPoint(btn, "CENTER", barFrame, "BOTTOM", slotX / unitScale, slotY / unitScale)
			btn:SetFrameStrata("MEDIUM")
			btn:SetFrameLevel(10)
			StyleActionButtonForStoneSlot(btn)
		end
	end
end

local function HookActionBarForStandardMode(bar)
	if not bar then
		return
	end
	DeactivateBarContainerMouse(bar)
	if layoutHooked[bar] then
		return
	end
	layoutHooked[bar] = true
	local function reapply()
		if not StandardMode:IsGamepad() and not InCombatLockdown() then
			StandardMode:Apply()
		end
	end
	if bar.UpdateSystemSettingIconSize then
		hooksecurefunc(bar, "UpdateSystemSettingIconSize", reapply)
	end
	if bar.UpdateGridLayout then
		hooksecurefunc(bar, "UpdateGridLayout", reapply)
	end
end

-- Create a sculpted Diablo stone wing dock (using d3_wing_dock.tga) that tucks behind the Demon/Angel statue
local function CreateDock(name, labelText, defaultX, defaultY, artWidth, artHeight, mirrorUV)
	local dock = CreateFrame("Frame", name, UIParent)
	dock:SetSize(artWidth, 56)
	dock:SetFrameStrata("LOW")
	dock:SetFrameLevel(0)
	dock:SetPoint("BOTTOM", UIParent, "BOTTOM", defaultX, defaultY)
	dock.defaultPosition = { a1 = "BOTTOM", af = "UIParent", a2 = "BOTTOM", x = defaultX, y = defaultY }

	-- Sculpted Diablo stone wing pedestal (matches bar1.tga & d3_bottom.tga moldings and recessed bay)
	local art = dock:CreateTexture(nil, "BACKGROUND", nil, -6)
	art:SetPoint("BOTTOM", dock, "BOTTOM", 0, 0)
	art:SetSize(artWidth, artHeight)
	art:SetTexture(MEDIA .. "d3_wing_dock")
	if mirrorUV then
		art:SetTexCoord(1, 0, 0, 1)
	end
	dock.art = art

	if func and func.applyDragFunctionality then
		func.applyDragFunctionality(dock)
		-- applyDragFunctionality clamps to the screen, but a wing is wider than the room
		-- beside its statue and is meant to run off the edge: clamped, the game pinned it
		-- there, so outward / downward offsets (and the edit layout's X slider) did nothing
		dock:SetClampedToScreen(false)
		if dock.dragframe then
			local lbl = dock.dragframe:CreateFontString(nil, "OVERLAY")
			lbl:SetFont(cfg.font or "Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
			lbl:SetPoint("CENTER", 0, 0)
			lbl:SetText(labelText)
		end
	end

	return dock
end

local function WireDockHover(dock, targetFrame, buttons)
	local idleAlpha = (cfg.standardMode and cfg.standardMode.dockFadeAlpha) or 0.85
	dock:SetAlpha(1)
	if targetFrame and targetFrame.SetAlpha then
		targetFrame:SetAlpha(idleAlpha)
	end

	local function onEnter()
		if targetFrame and targetFrame.SetAlpha then
			targetFrame:SetAlpha(1)
		end
	end
	local function onLeave()
		if not dock:IsMouseOver() and not (targetFrame and targetFrame.IsMouseOver and targetFrame:IsMouseOver()) then
			if targetFrame and targetFrame.SetAlpha then
				targetFrame:SetAlpha(idleAlpha)
			end
		end
	end

	if not hoverHooked[dock] then
		hoverHooked[dock] = true
		dock:HookScript("OnEnter", onEnter)
		dock:HookScript("OnLeave", onLeave)
	end
	for _, btn in ipairs(buttons) do
		if btn and not hoverHooked[btn] then
			hoverHooked[btn] = true
			btn:HookScript("OnEnter", onEnter)
			btn:HookScript("OnLeave", onLeave)
		end
	end
end

-- Measure visible button bounds (in screen coordinates) relative to container's center so we can center visible buttons in the stone bay
local function MeasureVisibleButtonsBounds(container, buttons, fallbackWidth)
	local cScale = container:GetEffectiveScale() or 1
	local uScale = UIParent:GetEffectiveScale() or 1
	local cLeft = container:GetLeft()
	local cRight = container:GetRight()
	local cCenter = (cLeft and cRight) and ((cLeft + cRight) * 0.5 * cScale / uScale) or nil

	local minL, maxR = nil, nil
	for _, btn in ipairs(buttons) do
		if btn and btn:IsShown() and (btn:GetAlpha() or 1) > 0.05 then
			local bScale = btn:GetEffectiveScale() or cScale
			local l = btn:GetLeft()
			local r = btn:GetRight()
			if l and r and r > l then
				local ls = l * bScale / uScale
				local rs = r * bScale / uScale
				if not minL or ls < minL then
					minL = ls
				end
				if not maxR or rs > maxR then
					maxR = rs
				end
			end
		end
	end

	if minL and maxR and maxR > minL and cCenter then
		local visWidth = maxR - minL
		local visCenter = (minL + maxR) * 0.5
		local shiftX = cCenter - visCenter
		return visWidth, shiftX
	end
	return fallbackWidth, 0
end

local function SetupMicroDock(isPad, demonX, statueScale)
	local sm = cfg.standardMode
	if not (sm and sm.integrateMicroMenu) then
		return
	end
	-- wing centre from the demon statue. Measured in game (2026-10-17): the dock used to be
	-- clamped to the screen, which held it ~125 px further in than the old formula said;
	-- these offsets reproduce that spot plus a little more room outward.
	local defaultX = (demonX or -330) - (sm.microDockOffset or 215) * (statueScale or 1) / 0.85
	if not microDock then
		microDock = CreateDock("Roth_UIMicroDock", "Micro Menu Wing", defaultX, 0, 330, 114, false)
	end
	local dockY = sm.dockY or 0
	microDock.defaultPosition.x = defaultX
	microDock.defaultPosition.y = dockY
	if isPad then
		microDock:Hide()
		return
	end
	microDock:Show()
	if not IsUserMoved("Roth_UIMicroDock") then
		microDock:ClearAllPoints()
		microDock:SetPoint("BOTTOM", UIParent, "BOTTOM", defaultX, dockY)
	end

	local mm = _G.MicroMenu
	local mmc = _G.MicroMenuContainer
	local activeBtns = {}
	if mm and mm.GetChildren then
		for _, child in ipairs({ mm:GetChildren() }) do
			if child and child.layoutIndex and child:IsShown() then
				Blizz.SetScale(child, 1.0)
				activeBtns[#activeBtns + 1] = child
			end
		end
	end

	if mm then
		if mm.BorderArt then
			mm.BorderArt:SetAlpha(0)
		end
		if mm.BackgroundArt then
			mm.BackgroundArt:SetAlpha(0)
		end
		if mm.Layout then
			pcall(mm.Layout, mm)
		end
	end

	local container = mmc or mm
	if container then
		local scale = 0.72
		Blizz.SetScale(container, scale)
		if mm and mm ~= container then
			Blizz.SetScale(mm, 1.0)
			Blizz.ClearAllPoints(mm)
			Blizz.SetPoint(mm, "CENTER", container, "CENTER", 0, 0)
		end
		Blizz.ClearAllPoints(container)
		Blizz.SetPoint(container, "CENTER", microDock, "BOTTOM", 0, 35 / scale)

		local visW, shiftX = MeasureVisibleButtonsBounds(
			container,
			activeBtns,
			((mm and mm:GetWidth()) or container:GetWidth() or 275) * scale
		)
		Blizz.ClearAllPoints(container)
		Blizz.SetPoint(container, "CENTER", microDock, "BOTTOM", (shiftX + (sm.microButtonsX or 0)) / scale, 35 / scale)

		-- Recessed bay is 68.75% of d3_wing_dock.tga width; add 24px breathing margin inside the stone bay
		local wingW = math.max(330, (visW + 24) / 0.6875)
		microDock:SetSize(wingW, 56)
		if microDock.art then
			microDock.art:SetSize(wingW, 114)
		end
		WireDockHover(microDock, container, activeBtns)

		if mm and not anchorHooked[mm] and mm.ResetMicroMenuPosition then
			anchorHooked[mm] = true
			hooksecurefunc(mm, "ResetMicroMenuPosition", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() then
					SetupMicroDock(false, demonX, statueScale)
				end
			end)
		end
		if container.ApplySystemAnchor and not anchorHooked[container] then
			anchorHooked[container] = true
			hooksecurefunc(container, "ApplySystemAnchor", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() then
					SetupMicroDock(false, demonX, statueScale)
				end
			end)
		end
	end
end

local function SetupBagDock(isPad, angelX, statueScale)
	local sm = cfg.standardMode
	if not (sm and sm.integrateBags) then
		return
	end
	local defaultX = (angelX or 325) + (sm.bagDockOffset or 220) * (statueScale or 1) / 0.85
	if not bagDock then
		bagDock = CreateDock("Roth_UIBagDock", "Bag Bar Wing", defaultX, 0, 330, 114, true)
	end
	local dockY = sm.dockY or 0
	bagDock.defaultPosition.x = defaultX
	bagDock.defaultPosition.y = dockY
	if isPad then
		bagDock:Hide()
		return
	end
	bagDock:Show()
	if not IsUserMoved("Roth_UIBagDock") then
		bagDock:ClearAllPoints()
		bagDock:SetPoint("BOTTOM", UIParent, "BOTTOM", defaultX, dockY)
	end

	-- Keyholder (KeyRingButton) setup & styling
	local krb = _G.KeyRingButton
	if krb then
		SetupKeyRingButton(krb)
		StyleBagItemButton(krb)
	end

	-- Restore CharacterReagentBag0Slot
	local reagentBag = _G.CharacterReagentBag0Slot
	if reagentBag then
		reagentBag.includeInLayout = false
		reagentBag:SetAlpha(1)
		reagentBag:SetSize(45, 45)
		reagentBag:Show()
		StyleBagItemButton(reagentBag)
	end

	if _G.BagBarExpandToggle then
		_G.BagBarExpandToggle.includeInLayout = false
		_G.BagBarExpandToggle:SetAlpha(0)
		_G.BagBarExpandToggle:SetSize(0.001, 0.001)
		_G.BagBarExpandToggle:Hide()
	end

	local bb = _G.BagsBar
	if bb then
		HideDividerPools(bb)
		if bb.BorderArt then
			bb.BorderArt:SetAlpha(0)
		end
		if bb.Layout then
			pcall(bb.Layout, bb)
		end
		HideDividerPools(bb)

		-- Anchor CharacterReagentBag0Slot directly to the left of CharacterBag3Slot
		local bag3 = _G.CharacterBag3Slot
		if reagentBag and bag3 then
			reagentBag:ClearAllPoints()
			reagentBag:SetPoint("RIGHT", bag3, "LEFT", -2, 0)
			reagentBag:SetSize(45, 45)
			reagentBag:SetAlpha(1)
			reagentBag:Show()
		end

		-- Anchor KeyRingButton directly to the left of CharacterReagentBag0Slot (or bag3 fallback)
		if krb then
			local anchorTarget = (reagentBag and reagentBag:IsShown()) and reagentBag or bag3
			if anchorTarget then
				krb:ClearAllPoints()
				krb:SetPoint("RIGHT", anchorTarget, "LEFT", -2, 0)
				krb:SetSize(33, 45)
				krb:SetAlpha(1)
				krb:Show()
			end
		end

		local scale = 0.72
		Blizz.SetScale(bb, scale)
		Blizz.ClearAllPoints(bb)
		Blizz.SetPoint(bb, "CENTER", bagDock, "BOTTOM", 0, 39 / scale)

		local activeBtns = {}
		for _, name in ipairs(BAG_LIST) do
			local btn = _G[name]
			if btn and btn:IsShown() and (btn:GetAlpha() or 1) > 0.05 then
				Blizz.SetScale(btn, 1.0)
				activeBtns[#activeBtns + 1] = btn
			end
		end

		local visW, shiftX = MeasureVisibleButtonsBounds(bb, activeBtns, 185 * scale)
		Blizz.ClearAllPoints(bb)
		Blizz.SetPoint(bb, "CENTER", bagDock, "BOTTOM", (shiftX + (sm.bagButtonsX or 0)) / scale, 39 / scale)

		local wingW = math.max(330, (visW + 24) / 0.6875)
		bagDock:SetSize(wingW, 56)
		if bagDock.art then
			bagDock.art:SetSize(wingW, 114)
		end
		WireDockHover(bagDock, bb, activeBtns)

		if bb.ApplySystemAnchor and not anchorHooked[bb] then
			anchorHooked[bb] = true
			hooksecurefunc(bb, "ApplySystemAnchor", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() then
					SetupBagDock(false, angelX, statueScale)
				end
			end)
		end
		if bb.Layout and not layoutHooked[bb] then
			layoutHooked[bb] = true
			hooksecurefunc(bb, "Layout", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() then
					local b3 = _G.CharacterBag3Slot
					local rb = _G.CharacterReagentBag0Slot
					if rb and b3 then
						rb:ClearAllPoints()
						rb:SetPoint("RIGHT", b3, "LEFT", -2, 0)
						rb:SetSize(45, 45)
						rb:SetAlpha(1)
						rb:Show()
					end
					local kr = _G.KeyRingButton
					if kr then
						local target = (rb and rb:IsShown()) and rb or b3
						if target then
							kr:ClearAllPoints()
							kr:SetPoint("RIGHT", target, "LEFT", -2, 0)
							kr:SetSize(33, 45)
							kr:SetAlpha(1)
							kr:Show()
						end
					end
				end
			end)
		end
	end
end

-- First button of the uppermost action bar row that is fitted into the stone grid
-- (read at call time, so toggling Bar 2 / Bar 3 is picked up)
function StandardMode:GetTopRowFirstButton()
	local mbLeft = _G.MultiBarBottomLeft
	local mbRight = _G.MultiBarBottomRight
	local leftShown = mbLeft and mbLeft:IsShown()
	local rightShown = mbRight and mbRight:IsShown()
	if rightShown then
		return _G.MultiBarBottomRightButton1 or _G.ActionButton1
	elseif leftShown then
		return _G.MultiBarBottomLeftButton1 or _G.ActionButton1
	end
	return _G.ActionButton1
end

local inPetAnchor = false

-- Anchor the Pet Action Bar to the top-left of the uppermost active action bar row.
-- PetActionBar is protected, so this only runs out of combat; in combat it queues
-- a full Apply for PLAYER_REGEN_ENABLED.
function StandardMode:AnchorPetBar()
	if inPetAnchor then
		return
	end
	local sm = cfg.standardMode
	if not (sm and sm.enabled and sm.integratePetBar) or self:IsGamepad() then
		return
	end
	local petBar = _G.PetActionBar or _G.PetActionBarFrame
	if not petBar then
		return
	end
	if InCombatLockdown() then
		pendingApply = true
		return
	end
	local topBtn = self:GetTopRowFirstButton()
	if not topBtn then
		return
	end
	-- cfg.standardMode.petBarAnchor: "center" (default; button 6's right edge is the row's
	-- middle, which keeps the bar's left end clear of the chat box over the health orb),
	-- "left" or "right" end of the row
	local side = sm.petBarAnchor or "center"
	local prefix = (topBtn:GetName() or ""):gsub("1$", "")
	local midBtn, lastBtn = _G[prefix .. "6"], _G[prefix .. "12"]
	inPetAnchor = true
	HideDividerPools(petBar)
	if petBar.BorderArt then
		petBar.BorderArt:SetAlpha(0)
	end
	for i = 1, (rawget(_G, "NUM_PET_ACTION_SLOTS") or 10) do
		local pb = _G["PetActionButton" .. i]
		if pb then
			StyleActionButtonForStoneSlot(pb)
		end
	end
	Blizz.SetScale(petBar, 0.85)
	Blizz.ClearAllPoints(petBar)
	if side == "right" and lastBtn then
		Blizz.SetPoint(petBar, "BOTTOMRIGHT", lastBtn, "TOPRIGHT", 0, 6)
	elseif side == "center" and midBtn then
		Blizz.SetPoint(petBar, "BOTTOM", midBtn, "TOPRIGHT", 1, 6)
	else
		Blizz.SetPoint(petBar, "BOTTOMLEFT", topBtn, "TOPLEFT", 0, 6)
	end
	inPetAnchor = false
end

-- Blizzard moves the pet bar back into its default bottom stack from
-- EditModeManagerFrame:UpdateBottomActionBarPositions(), which calls
-- bar:ClearAllPoints()/SetPoint() directly (not ApplySystemAnchor). It runs when
-- action bars are toggled, the pet bar shows, the override bar changes and
-- whenever the XP/rep tracking bars change shown state
-- (StatusTrackingBarContainerMixin:UpdateShownState). Re-anchor after each pass.
local function HookPetBarMovers()
	local petBar = _G.PetActionBar or _G.PetActionBarFrame
	local function reanchor()
		if not inPetAnchor then
			StandardMode:AnchorPetBar()
		end
	end
	local emm = _G.EditModeManagerFrame
	if emm and emm.UpdateBottomActionBarPositions and not anchorHooked[emm] then
		anchorHooked[emm] = true
		hooksecurefunc(emm, "UpdateBottomActionBarPositions", reanchor)
	end
	if petBar and not anchorHooked[petBar] then
		anchorHooked[petBar] = true
		if petBar.ApplySystemAnchor then
			hooksecurefunc(petBar, "ApplySystemAnchor", reanchor)
		end
		petBar:HookScript("OnShow", reanchor)
	end
end

-- Position the Potion Belt (skipped while the user has a saved position for it):
--   - Gamepad mode: beside the Health Orb
--   - Standard mode, beltAnchor = "bags" (default): on top of the bag wing (Roth_UIBagDock)
--   - Standard mode, beltAnchor = "actionbar": top-left of the uppermost active action bar row
-- The belt holds secure buttons, so it can only be moved out of combat.
-- Returns true when it placed the belt.
function StandardMode:AnchorBelt()
	local sm = cfg.standardMode
	local belt = _G.Roth_UIBelt
	local pframe = _G.Roth_UIPlayerFrame
	if not (sm and sm.enabled) or not belt or not pframe or IsUserMoved("Roth_UIBelt") then
		return false
	end
	if InCombatLockdown() then
		pendingApply = true
		return true
	end
	belt:ClearAllPoints()
	if self:IsGamepad() then
		belt:SetPoint("BOTTOMLEFT", pframe, "BOTTOMRIGHT", cfg.belt.x or 6, cfg.belt.y or 24)
	elseif sm.beltAnchor ~= "actionbar" and bagDock and bagDock:IsShown() then
		local offsetX = sm.beltDockX or 18
		local offsetY = sm.beltDockY or 8 -- 8px elevation ensures potion sockets do not clip into bag buttons below

		-- Backup screen-edge protection:
		-- If the belt's right gothic bracket would clear/exceed the screen edge,
		-- calculate the inward offset so it automatically corrects and stays on screen.
		local uiWidth = UIParent:GetWidth() or 1440
		local dockRelX = (bagDock.defaultPosition and bagDock.defaultPosition.x) or 540
		local bScale = belt:GetEffectiveScale() or 1
		local uScale = UIParent:GetEffectiveScale() or 1
		local scaleRatio = (uScale > 0) and (bScale / uScale) or 1

		-- Belt visual half-width: 101px holder half-width + 44px right gothic bracket = 145px
		local beltVisualHalfW = 145 * scaleRatio
		local screenRightLimit = (uiWidth * 0.5) - 6 -- 6px margin from the screen edge
		local desiredRight = (dockRelX + offsetX) * scaleRatio + beltVisualHalfW

		if desiredRight > screenRightLimit then
			local overflow = desiredRight - screenRightLimit
			offsetX = offsetX - (overflow / scaleRatio)
		end

		belt:SetPoint("BOTTOM", bagDock, "TOP", offsetX, offsetY)
	else
		belt:SetPoint("BOTTOMLEFT", self:GetTopRowFirstButton() or pframe, "TOPLEFT", -4, 8)
	end
	return true
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
	local orbX = isPad and (sm.padOrbX or 325) or (sm.standardOrbX or 325)
	local statueScale = isPad and 1 or (sm.standardStatueScale or 1)
	-- statue offsets from the orb centre shrink with the statue art
	local demonX = -(orbX + 30 * statueScale)
	local angelX = orbX + 25 * statueScale
	local bottomW = isPad and 670 or (2 * orbX + 180)

	local pframe = _G.Roth_UIPlayerFrame
	local powerOrb = _G.Roth_UIPowerOrb
	local demon = _G.Roth_UIDemonFrame
	local angel = _G.Roth_UIAngelFrame
	local bottomLine = _G.Roth_UIBottomLine
	local barBg = _G.Roth_UIActionBarBackground

	-- Mode default scales (orbs, statues, stone bar); a scale saved in the edit layout wins
	local gs = (ns.EditMode and ns.EditMode.GetGlobalScale and ns.EditMode:GetGlobalScale()) or 1
	for name in pairs(self:DefaultScales(isPad)) do
		local f = _G[name]
		if f then
			local s = (ns.EditMode and ns.EditMode.GetScale and ns.EditMode:GetScale(f)) or self:DefaultScale(name)
			f:SetScale(s * gs)
		end
	end

	local orbY = cfg.units.player.pos.y or 10
	if pframe and not IsUserMoved("Roth_UIPlayerFrame") then
		PlaceAtBottom(pframe, -orbX, orbY)
	end
	if powerOrb and not IsUserMoved("Roth_UIPowerOrb") then
		PlaceAtBottom(powerOrb, orbX, orbY)
	end
	if demon and not IsUserMoved("Roth_UIDemonFrame") then
		PlaceAtBottom(demon, demonX, cfg.units.player.art.demon.pos.y or 6)
	end
	if angel and not IsUserMoved("Roth_UIAngelFrame") then
		PlaceAtBottom(angel, angelX, cfg.units.player.art.angel.pos.y or 6)
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

	if not isPad then
		HideBlizzardBarArt()
		HookActionBarForStandardMode(_G.MainActionBar)
		HookActionBarForStandardMode(_G.MultiBarBottomLeft)
		HookActionBarForStandardMode(_G.MultiBarBottomRight)
		if sm.integrateActionBars and barBg then
			FitActionBarRow("ActionButton", 23, barBg)
			FitActionBarPaging(barBg)
			local mbLeft = _G.MultiBarBottomLeft
			local mbRight = _G.MultiBarBottomRight
			-- Bar 2 = MultiBarBottomLeft, Bar 3 = MultiBarBottomRight; Bar 3 alone takes row 2
			if mbLeft and mbLeft:IsShown() then
				FitActionBarRow("MultiBarBottomLeftButton", 54, barBg)
				if mbRight and mbRight:IsShown() then
					FitActionBarRow("MultiBarBottomRightButton", 91, barBg)
				end
			elseif mbRight and mbRight:IsShown() then
				FitActionBarRow("MultiBarBottomRightButton", 54, barBg)
			end
		end
	end

	SetupMicroDock(isPad, demonX, statueScale)
	SetupBagDock(isPad, angelX, statueScale)
	HookPetBarMovers()
	self:AnchorPetBar()
	self:AnchorBelt()
	-- frame edges are only known once the anchors above have resolved
	C_Timer.After(0, function()
		StandardMode:PlaceStack()
	end)
end

-- Top of a frame in UIParent units (nil until it has a position)
local function TopInUI(f)
	local top = f and f:GetTop()
	if not top then
		return nil
	end
	return top * f:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- The bottom stack above the stone bar, keyboard layout only:
--   top action row -> pet bar (space kept even without a pet, so nothing jumps when one
--   is summoned) -> player cast bar -> swing timer (core/swingtimer.lua anchors it to
--   the cast bar's top).
-- The pet frame sits above the power orb: the right side is empty, while the chat box
-- covers the area above the health orb and the quest tracker the right edge higher up.
-- Frames moved in the edit layout keep their place.
function StandardMode:PlaceStack()
	local sm = cfg.standardMode
	if not (sm and sm.enabled) or self:IsGamepad() then
		return
	end
	if InCombatLockdown() then
		pendingApply = true
		return
	end

	local rowTop = TopInUI(self:GetTopRowFirstButton())
	if rowTop then
		local pb = _G.PetActionButton1
		local petH = (pb and pb:GetHeight() > 0)
				and (pb:GetHeight() * pb:GetEffectiveScale() / UIParent:GetEffectiveScale())
			or 32
		local stackTop = rowTop + 6 + petH + 6
		local cast = _G.Roth_UIPlayerFrameCastBarDragFrame
		if cast and not IsUserMoved("Roth_UIPlayerFrameCastBarDragFrame") then
			-- centred; the cast bar's stone frame reaches ~24 below its centre line
			PlaceAtBottom(cast, 0, stackTop + 24)
		end
		self:PlacePetFrame(rowTop, petH)
	end
	self:PlaceTargetFrame()
	self:PlaceTargetTargetFrame()
end

-- Choices shared by the settings window and the edit layout's pet and target dialogs
StandardMode.PET_FRAME_ANCHORS = {
	{ value = "healthOrb", label = "Above the health orb" },
	{ value = "orb", label = "Above the power orb" },
	{ value = "petbarLeft", label = "Left of the pet bar" },
	{ value = "petbarRight", label = "Right of the pet bar" },
}
StandardMode.PET_BAR_ANCHORS = {
	{ value = "left", label = "Left end of the row" },
	{ value = "center", label = "Centred" },
	{ value = "right", label = "Right end of the row" },
}
StandardMode.TARGET_FRAME_ANCHORS = {
	{ value = "powerOrb", label = "Above the power orb" },
	{ value = "healthOrb", label = "Above the health orb" },
	{ value = "top", label = "Top of the screen" },
}
StandardMode.TARGETTARGET_FRAME_ANCHORS = {
	{ value = "topright", label = "Top-right above target" },
	{ value = "topleft", label = "Top-left above target" },
	{ value = "left", label = "Left of target" },
	{ value = "right", label = "Right of target" },
}

StandardMode.TARGET_HEALTH_FORMATS = {
	{ value = "both", label = "Both (cur/max & %)" },
	{ value = "value", label = "Value (cur/max)" },
	{ value = "percent", label = "Percent (%)" },
	{ value = "deficit", label = "Deficit (-loss)" },
	{ value = "current", label = "Current HP" },
	{ value = "none", label = "None" },
}
ns.TARGET_HEALTH_FORMATS = StandardMode.TARGET_HEALTH_FORMATS

StandardMode.TARGET_POWER_FORMATS = {
	{ value = "both", label = "Both (cur/max & %)" },
	{ value = "value", label = "Value (cur/max)" },
	{ value = "percent", label = "Percent (%)" },
	{ value = "none", label = "None" },
}
ns.TARGET_POWER_FORMATS = StandardMode.TARGET_POWER_FORMATS

StandardMode.TARGET_AURA_PLACEMENTS = {
	{ value = "right", label = "Right" },
	{ value = "above", label = "Above" },
	{ value = "below", label = "Below" },
	{ value = "left", label = "Left" },
}
ns.TARGET_AURA_PLACEMENTS = StandardMode.TARGET_AURA_PLACEMENTS

StandardMode.UNIT_HEALTH_FORMATS = {
	{ value = "deficit", label = "Deficit (-loss)" },
	{ value = "percent", label = "Percent (%)" },
	{ value = "value", label = "Value (cur/max)" },
	{ value = "current", label = "Current HP" },
	{ value = "both", label = "Both (cur/max & %)" },
	{ value = "none", label = "None" },
}
ns.UNIT_HEALTH_FORMATS = StandardMode.UNIT_HEALTH_FORMATS

StandardMode.RAID_LAYOUT_OPTIONS = {
	{ value = "tiles", label = "Diablo square tiles (upward liquid fill)" },
	{ value = "bars", label = "Classic horizontal iron bars" },
}
ns.RAID_LAYOUT_OPTIONS = StandardMode.RAID_LAYOUT_OPTIONS

-- Pet frame, choices (cfg.standardMode.petFrameAnchor):
--   "orb"    above the power orb. The right side is empty: the chat box covers the
--            area above the health orb and the quest tracker the right edge higher up.
--   "healthOrb" above the health orb, by the player's own orb; under a chat box that
--            sits at the bottom left.
--   "petbarLeft" / "petbarRight"  up and to the left / right of the pet bar, next to
--            the pet's own buttons. On the left it can reach under a chat box at the
--            bottom left; on the right it can meet the cast bar when the bar is centred.
function StandardMode:PlacePetFrame(rowTop, petH)
	local sm = cfg.standardMode
	local pet = _G.Roth_UIPetFrame
	if not pet or IsUserMoved("Roth_UIPetFrame") then
		return
	end
	local uiEff = UIParent:GetEffectiveScale()
	local mode = sm.petFrameAnchor
	if mode == "petbar" then
		mode = "petbarLeft" -- earlier name
	end
	if mode == "petbarLeft" or mode == "petbarRight" then
		-- where the pet bar's left end is, from the buttons it is anchored to (the bar itself
		-- may be hidden without a pet and then has no position)
		local first = self:GetTopRowFirstButton()
		local prefix = first and (first:GetName() or ""):gsub("1$", "") or ""
		local petBar = _G.PetActionBar or _G.PetActionBarFrame
		local side = sm.petBarAnchor or "center"
		local ref, edge
		if side == "right" then
			ref, edge = _G[prefix .. "12"], "right"
		elseif side == "center" then
			ref, edge = _G[prefix .. "6"], "center"
		else
			ref, edge = first, "left"
		end
		local refX = ref and ((edge == "left") and ref:GetLeft() or ref:GetRight())
		if refX and petBar then
			local x = refX * ref:GetEffectiveScale() / uiEff - UIParent:GetWidth() / 2
			local barW = petBar:GetWidth() * petBar:GetEffectiveScale() / uiEff
			local barLeft = (edge == "left" and x) or (edge == "right" and x - barW) or (x - barW / 2)
			local petW = pet:GetWidth() * pet:GetEffectiveScale() / uiEff
			-- overlapping the bar's end by 16, bottom a little above the bar's top
			local px
			if mode == "petbarRight" then
				px = barLeft + barW - 16 + petW / 2
			else
				px = barLeft + 16 - petW / 2
			end
			PlaceAtBottom(pet, px, rowTop + 6 + petH + 8)
			return
		end
	end
	local onHealth = mode ~= "orb"
	local orbTop = TopInUI(onHealth and _G.Roth_UIHealthOrb or _G.Roth_UIPowerOrb)
	if orbTop then
		-- with the portrait beside the frame, centre portrait + frame together over the orb
		local shift = 0
		local holder = pet.portraitSide and pet.PortraitHolder
		if holder then
			shift = holder:GetWidth() * 0.6 * holder:GetEffectiveScale() / uiEff / 2
		end
		PlaceAtBottom(
			pet,
			(onHealth and -1 or 1) * (sm.standardOrbX or 325) + shift,
			orbTop + (sm.petFrameOrbGap or -10)
		)
	end
end

-- Target frame, choices (cfg.standardMode.targetFrameAnchor):
--   "powerOrb"  above the power orb (default: symmetrical to pet frame above health orb)
--   "healthOrb" above the health orb
--   "top"       top of the screen (classic Roth UI layout)
function StandardMode:PlaceTargetFrame()
	local sm = cfg.standardMode
	local target = _G.Roth_UITargetFrame
	if not target or IsUserMoved("Roth_UITargetFrame") then
		return
	end
	if InCombatLockdown() then
		pendingApply = true
		return
	end
	local mode = sm.targetFrameAnchor or "powerOrb"
	if mode == "top" then
		target:ClearAllPoints()
		local pos = (cfg.units and cfg.units.target and cfg.units.target.pos) or {}
		target:SetPoint(pos.a1 or "TOP", (pos.af and _G[pos.af]) or UIParent, pos.a2 or "TOP", pos.x or 0, pos.y or -80)
		self:PlaceTargetTargetFrame()
		return
	end
	local onHealth = (mode == "healthOrb")
	local orb = onHealth and _G.Roth_UIHealthOrb or _G.Roth_UIPowerOrb
	local orbTop = TopInUI(orb)
	if orbTop then
		local x = (onHealth and -1 or 1) * (sm.standardOrbX or 325)
		if not onHealth then
			-- over the power orb: 25% of the frame left of the orb's midpoint, 75% to the right
			local w = target:GetWidth() * target:GetEffectiveScale() / UIParent:GetEffectiveScale()
			x = x + w * 0.25
		end
		PlaceAtBottom(target, x, orbTop + (sm.targetFrameOrbGap or -10))
		self:PlaceTargetTargetFrame()
	end
end

-- Target of Target frame, choices (cfg.standardMode.targetTargetFrameAnchor):
--   "topright"  top-right above target frame (BOTTOMRIGHT -> TOPRIGHT, 0, 6)
--   "topleft"   top-left above target frame (BOTTOMLEFT -> TOPLEFT, 0, 6)
--   "left"      left of target frame (TOPRIGHT -> TOPLEFT, -6, -10)
--   "right"     right of target frame (TOPLEFT -> TOPRIGHT, 6, -10)
function StandardMode:PlaceTargetTargetFrame()
	local sm = cfg.standardMode
	local tot = _G.Roth_UITargetTargetFrame
	local target = _G.Roth_UITargetFrame
	if not tot or not target or IsUserMoved("Roth_UITargetTargetFrame") then
		return
	end
	if InCombatLockdown() then
		pendingApply = true
		return
	end
	local mode = sm.targetTargetFrameAnchor or "topright"
	tot:ClearAllPoints()
	if mode == "topleft" then
		tot:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 6)
	elseif mode == "left" then
		tot:SetPoint("TOPRIGHT", target, "TOPLEFT", -6, -10)
	elseif mode == "right" then
		tot:SetPoint("TOPLEFT", target, "TOPRIGHT", 6, -10)
	else
		-- "topright" default
		tot:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, 6)
	end
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

if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		if C_Timer and C_Timer.After then
			C_Timer.After(0.05, function()
				StandardMode:Apply()
			end)
		else
			StandardMode:Apply()
		end
	end, StandardMode)
end

-- Toggling Bar 2 / Bar 3 changes which row is on top. Apply once on the next
-- frame, after Blizzard's own layout pass for the toggle has finished.
local applyQueued = false
local function QueueApply()
	if applyQueued then
		return
	end
	applyQueued = true
	C_Timer.After(0, function()
		applyQueued = false
		StandardMode:Apply()
	end)
end
for _, bar in ipairs({ _G.MultiBarBottomLeft, _G.MultiBarBottomRight }) do
	bar:HookScript("OnShow", QueueApply)
	bar:HookScript("OnHide", QueueApply)
end
