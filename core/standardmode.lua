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

local function IsUserScaled(frameName)
	local prof = ns.LayoutProfile and ns.LayoutProfile()
	return prof and prof.frameScales and prof.frameScales[frameName] ~= nil
end

-- Safely hide Blizzard's decorative actionbar art, EndCaps (Left/Right), borders, dividers & duplicate status bars
local function HideBlizzardBarArt()
	-- 1. WoW Forever (Camelot) MainActionBar EndCaps, BorderArt, and Dividers
	local mab = _G.MainActionBar
	if mab then
		mab.hideBarArt = true
		if mab.BorderArt then
			mab.BorderArt:SetAlpha(0)
			mab.BorderArt:Hide()
		end
		if mab.EndCaps then
			if mab.EndCaps.LeftEndCap then
				if mab.EndCaps.LeftEndCap.SetVisibilitySetting then
					pcall(mab.EndCaps.LeftEndCap.SetVisibilitySetting, mab.EndCaps.LeftEndCap, false)
				end
				mab.EndCaps.LeftEndCap:SetAlpha(0)
				mab.EndCaps.LeftEndCap:Hide()
			end
			if mab.EndCaps.RightEndCap then
				if mab.EndCaps.RightEndCap.SetVisibilitySetting then
					pcall(mab.EndCaps.RightEndCap.SetVisibilitySetting, mab.EndCaps.RightEndCap, false)
				end
				mab.EndCaps.RightEndCap:SetAlpha(0)
				mab.EndCaps.RightEndCap:Hide()
			end
			mab.EndCaps:SetAlpha(0)
			mab.EndCaps:Hide()
		end
		if mab.HorizontalDividersPool then
			mab.HorizontalDividersPool:ReleaseAll()
		end
		if mab.VerticalDividersPool then
			mab.VerticalDividersPool:ReleaseAll()
		end
		if not mab._diabolusArtHooked then
			mab._diabolusArtHooked = true
			if mab.UpdateEndCaps then
				hooksecurefunc(mab, "UpdateEndCaps", function(self)
					if not StandardMode:IsGamepad() and self.EndCaps then
						self.EndCaps:SetAlpha(0)
						self.EndCaps:Hide()
					end
				end)
			end
			if mab.UpdateDividers then
				hooksecurefunc(mab, "UpdateDividers", function(self)
					if not StandardMode:IsGamepad() then
						if self.HorizontalDividersPool then
							self.HorizontalDividersPool:ReleaseAll()
						end
						if self.VerticalDividersPool then
							self.VerticalDividersPool:ReleaseAll()
						end
					end
				end)
			end
		end
	end

	-- 2. Legacy / classic named textures and duplicate status bars
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

	local hiddenFrames = {
		"MainMenuBarPerformanceBar",
		"MainMenuBarPerformanceBarFrame",
		"MainMenuBarPerformanceBarFrameButton",
		"MainMenuBarMaxLevelBar",
		"MainMenuExpBar",
		"ReputationWatchBar",
	}
	for _, name in ipairs(hiddenFrames) do
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

-- Style an individual action button so its empty slot background is transparent
-- (allowing zork's crossed-sword stone slot grid bar1/bar2/bar3 to show through)
local function StyleActionButtonForStoneSlot(btn)
	if btn.SlotArt then
		btn.SlotArt:SetAlpha(0)
		btn.SlotArt:Hide()
	end
	if btn.SlotBackground then
		btn.SlotBackground:SetAlpha(0)
		btn.SlotBackground:Hide()
	end
	local nt = btn.GetNormalTexture and btn:GetNormalTexture()
	if nt then
		nt:SetAlpha(0.25)
	end
	if not btn._diabolusArtHooked and btn.UpdateButtonArt then
		btn._diabolusArtHooked = true
		hooksecurefunc(btn, "UpdateButtonArt", function(self)
			if self.SlotArt then
				self.SlotArt:SetAlpha(0)
				self.SlotArt:Hide()
			end
			if self.SlotBackground then
				self.SlotBackground:SetAlpha(0)
				self.SlotBackground:Hide()
			end
		end)
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
			StyleActionButtonForStoneSlot(btn)
		end
	end
end

-- Position ActionBarPageNumber (+/- arrows and page number) on the carved left stone shoulder of bar1.tga
local function SetupActionBarPaging(barFrame)
	if not barFrame then
		return
	end
	local mab = _G.MainActionBar
	local pageFrame = mab and mab.ActionBarPageNumber
	if pageFrame then
		pageFrame:SetAlpha(0.92)
		pageFrame:Show()
		local barEff = barFrame:GetEffectiveScale() or 1
		local parent = pageFrame:GetParent()
		local parentEff = (parent and parent:GetEffectiveScale()) or barEff
		local unitScale = 0.80
		local pageScale = unitScale * (barEff / parentEff)
		Blizz.SetScale(pageFrame, pageScale)
		Blizz.ClearAllPoints(pageFrame)
		-- Place on the carved stone shoulder just left of ActionButton1 (slot 1 left edge is -188)
		Blizz.SetPoint(pageFrame, "CENTER", barFrame, "BOTTOM", -196.5 / unitScale, 36.5 / unitScale)
	end
end

local function HookActionBarForStandardMode(bar)
	if not bar or bar._diabolusLayoutHooked then
		return
	end
	bar._diabolusLayoutHooked = true
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
	-- Keep the sculpted stone wing pedestal solid (alpha 1) like bar1.tga, and subtly brighten buttons on hover
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

	if not dock._diabolusHoverHooked then
		dock._diabolusHoverHooked = true
		dock:HookScript("OnEnter", onEnter)
		dock:HookScript("OnLeave", onLeave)
	end
	for _, btn in ipairs(buttons) do
		if btn and not btn._diabolusHoverHooked then
			btn._diabolusHoverHooked = true
			btn:HookScript("OnEnter", onEnter)
			btn:HookScript("OnLeave", onLeave)
		end
	end
end

-- Compute the horizontal offset needed so that the actual visible buttons' bounding box
-- sits dead-center inside container
local function ComputeVisibleButtonsCenterBias(container, buttons)
	local cLeft = container.GetLeft and container:GetLeft()
	local cRight = container.GetRight and container:GetRight()
	if not cLeft or not cRight then
		return 0
	end
	local cMid = 0.5 * (cLeft + cRight)
	local minL, maxR
	for _, btn in ipairs(buttons) do
		if btn and btn.IsShown and btn:IsShown() and (not btn.GetAlpha or btn:GetAlpha() > 0.05) then
			local l = btn.GetLeft and btn:GetLeft()
			local r = btn.GetRight and btn:GetRight()
			if l and r and (r - l) > 2 then
				if not minL or l < minL then
					minL = l
				end
				if not maxR or r > maxR then
					maxR = r
				end
			end
		end
	end
	if minL and maxR then
		return cMid - 0.5 * (minL + maxR)
	end
	return 0
end

local function SetupMicroDock(isPad, demonX)
	local sm = cfg.standardMode
	if not (sm and sm.integrateMicroMenu) then
		return
	end
	if not microDock then
		microDock = CreateDock("Roth_UIMicroDock", "Micro Menu Wing", -535, 0, 290, 114, false)
	end
	if isPad then
		microDock:Hide()
		return
	end
	microDock:Show()

	local mm = _G.MicroMenu
	local mmc = _G.MicroMenuContainer
	local activeBtns = {}
	if mm and mm.GetChildren then
		for _, child in ipairs({ mm:GetChildren() }) do
			if child and child.layoutIndex then
				Blizz.SetScale(child, 1.0)
				activeBtns[#activeBtns + 1] = child
			end
		end
	end

	if mm then
		if mm.BorderArt then
			mm.BorderArt:SetAlpha(0)
			mm.BorderArt:Hide()
		end
		if mm.BackgroundArt then
			mm.BackgroundArt:SetAlpha(0)
			mm.BackgroundArt:Hide()
		end
		if mm.Layout then
			pcall(mm.Layout, mm)
		end
	end

	-- In WoW Forever (Camelot), MicroMenuContainer / MicroMenu is a GridLayoutFrame
	local container = mmc or mm
	if container then
		local scale = 0.68
		Blizz.SetScale(container, scale)
		if mm and mm ~= container then
			Blizz.SetScale(mm, 1.0)
			Blizz.ClearAllPoints(mm)
			Blizz.SetPoint(mm, "CENTER", container, "CENTER", 0, 0)
		end

		local cw = ((mm and mm:GetWidth()) or container:GetWidth() or 275) * scale
		-- Recessed bay is 68.75% of d3_wing_dock.tga width (x = 80..432 of 512px)
		local wingW = math.max(285, (cw + 14) / 0.6875)
		microDock:SetSize(wingW, 56)
		if microDock.art then
			microDock.art:SetSize(wingW, 114)
		end

		-- Position microDock so the right edge of its recessed bay (+0.34375 * wingW) clears the Demon statue's
		-- left foot (demonX - 92), while the right stone shoulder (0.15625 * wingW = ~45px) tucks behind the Demon
		local dockX = (demonX or -330) - 92 - math.floor(0.34375 * wingW)
		microDock.defaultPosition.x = dockX
		if not IsUserMoved("Roth_UIMicroDock") then
			microDock:ClearAllPoints()
			microDock:SetPoint("BOTTOM", UIParent, "BOTTOM", dockX, 0)
		end

		local biasX = ComputeVisibleButtonsCenterBias(container, activeBtns)
		Blizz.ClearAllPoints(container)
		Blizz.SetPoint(container, "CENTER", microDock, "BOTTOM", biasX, 31 / scale)
		WireDockHover(microDock, container, activeBtns)

		if mm and not mm._diabolusDockHooked and mm.ResetMicroMenuPosition then
			mm._diabolusDockHooked = true
			hooksecurefunc(mm, "ResetMicroMenuPosition", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() and microDock then
					local b = ComputeVisibleButtonsCenterBias(container, activeBtns)
					Blizz.ClearAllPoints(container)
					Blizz.SetPoint(container, "CENTER", microDock, "BOTTOM", b, 31 / scale)
				end
			end)
		end
		if container.ApplySystemAnchor and not container._diabolusAnchorHooked then
			container._diabolusAnchorHooked = true
			hooksecurefunc(container, "ApplySystemAnchor", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() and microDock then
					local b = ComputeVisibleButtonsCenterBias(container, activeBtns)
					Blizz.ClearAllPoints(container)
					Blizz.SetPoint(container, "CENTER", microDock, "BOTTOM", b, 31 / scale)
				end
			end)
		end
	end
end

local function SetupBagDock(isPad, angelX)
	local sm = cfg.standardMode
	if not (sm and sm.integrateBags) then
		return
	end
	if not bagDock then
		bagDock = CreateDock("Roth_UIBagDock", "Bag Bar Wing", 505, 0, 240, 114, true)
	end
	if isPad then
		bagDock:Hide()
		return
	end
	bagDock:Show()

	-- Hide KeyRingButton when player has no keys so it doesn't add empty padding on the left of the Bag Bar
	if _G.KeyRingButton and (not _G.HasKey or not _G.HasKey()) then
		_G.KeyRingButton:SetAlpha(0)
		_G.KeyRingButton:Hide()
	end

	local activeBtns = {}
	for _, name in ipairs(BAG_LIST) do
		local btn = _G[name]
		if btn and btn:IsShown() and (not btn.GetAlpha or btn:GetAlpha() > 0.05) then
			Blizz.SetScale(btn, 1.0)
			activeBtns[#activeBtns + 1] = btn
		end
	end

	local bb = _G.BagsBar
	if bb then
		bb.useDividers = false
		if bb.HorizontalDividersPool then
			bb.HorizontalDividersPool:ReleaseAll()
		end
		if bb.VerticalDividersPool then
			bb.VerticalDividersPool:ReleaseAll()
		end
		if bb.BorderArt then
			bb.BorderArt:SetAlpha(0)
			bb.BorderArt:Hide()
		end
		-- Hide unused Classic Reagent Bag slot and zero its width so the 4 bags + backpack pack cleanly
		if _G.CharacterReagentBag0Slot then
			_G.CharacterReagentBag0Slot:SetAlpha(0)
			_G.CharacterReagentBag0Slot:SetSize(0.001, 0.001)
			_G.CharacterReagentBag0Slot:Hide()
		end
		if _G.BagBarExpandToggle then
			_G.BagBarExpandToggle:SetAlpha(0)
			_G.BagBarExpandToggle:SetSize(0.001, 0.001)
			_G.BagBarExpandToggle:Hide()
		end
		if bb.Layout then
			pcall(bb.Layout, bb)
		end

		local scale = 0.68
		Blizz.SetScale(bb, scale)

		local bw = (#activeBtns * 33) * scale
		if bw < 140 then
			bw = 155
		end
		local wingW = math.max(235, (bw + 16) / 0.6875)
		bagDock:SetSize(wingW, 56)
		if bagDock.art then
			bagDock.art:SetSize(wingW, 114)
		end

		-- Position bagDock so the left edge of its recessed bay (-0.34375 * wingW) clears the Angel statue's
		-- right foot/wing (angelX + 92), while the left stone shoulder tucks behind the Angel
		local dockX = (angelX or 325) + 92 + math.floor(0.34375 * wingW)
		bagDock.defaultPosition.x = dockX
		if not IsUserMoved("Roth_UIBagDock") then
			bagDock:ClearAllPoints()
			bagDock:SetPoint("BOTTOM", UIParent, "BOTTOM", dockX, 0)
		end

		local biasX = ComputeVisibleButtonsCenterBias(bb, activeBtns)
		Blizz.ClearAllPoints(bb)
		Blizz.SetPoint(bb, "CENTER", bagDock, "BOTTOM", biasX, 31 / scale)
		WireDockHover(bagDock, bb, activeBtns)

		if bb.ApplySystemAnchor and not bb._diabolusAnchorHooked then
			bb._diabolusAnchorHooked = true
			hooksecurefunc(bb, "ApplySystemAnchor", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() and bagDock then
					local b = ComputeVisibleButtonsCenterBias(bb, activeBtns)
					Blizz.ClearAllPoints(bb)
					Blizz.SetPoint(bb, "CENTER", bagDock, "BOTTOM", b, 31 / scale)
				end
			end)
		end
	end
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
	local orbX = isPad and (sm.padOrbX or 325) or (sm.standardOrbX or 300)
	local demonX = -(orbX + 30)
	local angelX = orbX + 25
	local bottomW = isPad and 670 or 800

	local pframe = _G.Roth_UIPlayerFrame
	local powerOrb = _G.Roth_UIPowerOrb
	local demon = _G.Roth_UIDemonFrame
	local angel = _G.Roth_UIAngelFrame
	local bottomLine = _G.Roth_UIBottomLine
	local barBg = _G.Roth_UIActionBarBackground

	if barBg and not IsUserScaled("Roth_UIActionBarBackground") then
		barBg:SetScale(isPad and 1.0 or (sm.standardBarScale or 1.18))
	end

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

	local topRowFirstBtn = _G.ActionButton1
	if not isPad then
		HideBlizzardBarArt()
		HookActionBarForStandardMode(_G.MainActionBar)
		HookActionBarForStandardMode(_G.MultiBarBottomLeft)
		HookActionBarForStandardMode(_G.MultiBarBottomRight)
		if sm.integrateActionBars and barBg then
			FitActionBarRow("ActionButton", 23, barBg)
			SetupActionBarPaging(barBg)
			local mbLeft = _G.MultiBarBottomLeft
			local mbRight = _G.MultiBarBottomRight
			if mbLeft and mbLeft:IsShown() then
				FitActionBarRow("MultiBarBottomLeftButton", 54, barBg)
				topRowFirstBtn = _G.MultiBarBottomLeftButton1 or topRowFirstBtn
				if mbRight and mbRight:IsShown() then
					FitActionBarRow("MultiBarBottomRightButton", 91, barBg)
					topRowFirstBtn = _G.MultiBarBottomRightButton1 or topRowFirstBtn
				end
			elseif mbRight and mbRight:IsShown() then
				FitActionBarRow("MultiBarBottomRightButton", 54, barBg)
				topRowFirstBtn = _G.MultiBarBottomRightButton1 or topRowFirstBtn
			end
		end
	end

	-- Position Potion Belt:
	--   - In Gamepad mode: beside Health Orb
	--   - In Standard mode: anchored to the top-left of the uppermost activated actionbar row (Bar 1, 2, or 3)
	local belt = _G.Roth_UIBelt
	if belt and not IsUserMoved("Roth_UIBelt") and pframe then
		belt:ClearAllPoints()
		if isPad then
			belt:SetPoint("BOTTOMLEFT", pframe, "BOTTOMRIGHT", cfg.belt.x or 6, cfg.belt.y or 24)
		elseif topRowFirstBtn then
			belt:SetPoint("BOTTOMLEFT", topRowFirstBtn, "TOPLEFT", -4, 8)
		else
			belt:SetPoint("BOTTOM", pframe, "TOP", 0, -6)
		end
	end

	SetupMicroDock(isPad, demonX)
	SetupBagDock(isPad, angelX)
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

if _G.MultiBarBottomLeft then
	_G.MultiBarBottomLeft:HookScript("OnShow", function()
		StandardMode:Apply()
	end)
	_G.MultiBarBottomLeft:HookScript("OnHide", function()
		StandardMode:Apply()
	end)
end
if _G.MultiBarBottomRight then
	_G.MultiBarBottomRight:HookScript("OnShow", function()
		StandardMode:Apply()
	end)
	_G.MultiBarBottomRight:HookScript("OnHide", function()
		StandardMode:Apply()
	end)
end
