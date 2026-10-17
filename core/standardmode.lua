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
			StyleActionButtonForStoneSlot(btn)
		end
	end
end

local function HookActionBarForStandardMode(bar)
	if not bar or layoutHooked[bar] then
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

local function SetupMicroDock(isPad, demonX)
	local sm = cfg.standardMode
	if not (sm and sm.integrateMicroMenu) then
		return
	end
	local defaultX = (demonX or -330) - 235
	if not microDock then
		microDock = CreateDock("Roth_UIMicroDock", "Micro Menu Wing", defaultX, 0, 300, 114, false)
	end
	microDock.defaultPosition.x = defaultX
	if isPad then
		microDock:Hide()
		return
	end
	microDock:Show()
	if not IsUserMoved("Roth_UIMicroDock") then
		microDock:ClearAllPoints()
		microDock:SetPoint("BOTTOM", UIParent, "BOTTOM", defaultX, 0)
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
		Blizz.SetPoint(container, "CENTER", microDock, "BOTTOM", shiftX / scale, 35 / scale)

		-- Recessed bay is 68.75% of d3_wing_dock.tga width; add 24px breathing margin inside the stone bay
		local wingW = math.max(295, (visW + 24) / 0.6875)
		microDock:SetSize(wingW, 56)
		if microDock.art then
			microDock.art:SetSize(wingW, 114)
		end
		WireDockHover(microDock, container, activeBtns)

		if mm and not anchorHooked[mm] and mm.ResetMicroMenuPosition then
			anchorHooked[mm] = true
			hooksecurefunc(mm, "ResetMicroMenuPosition", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() then
					SetupMicroDock(false, demonX)
				end
			end)
		end
		if container.ApplySystemAnchor and not anchorHooked[container] then
			anchorHooked[container] = true
			hooksecurefunc(container, "ApplySystemAnchor", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() then
					SetupMicroDock(false, demonX)
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
	local defaultX = (angelX or 325) + 210
	if not bagDock then
		bagDock = CreateDock("Roth_UIBagDock", "Bag Bar Wing", defaultX, 0, 260, 114, true)
	end
	bagDock.defaultPosition.x = defaultX
	if isPad then
		bagDock:Hide()
		return
	end
	bagDock:Show()
	if not IsUserMoved("Roth_UIBagDock") then
		bagDock:ClearAllPoints()
		bagDock:SetPoint("BOTTOM", UIParent, "BOTTOM", defaultX, 0)
	end

	-- Hide KeyRingButton when player has no keys so only the 5 main bags sit cleanly in the bay
	if _G.KeyRingButton and (not _G.HasKey or not _G.HasKey()) then
		_G.KeyRingButton.includeInLayout = false
		_G.KeyRingButton:SetAlpha(0)
		_G.KeyRingButton:SetSize(0.001, 0.001)
		_G.KeyRingButton:Hide()
	end

	local activeBtns = {}
	for _, name in ipairs(BAG_LIST) do
		local btn = _G[name]
		if btn and btn:IsShown() and (btn:GetAlpha() or 1) > 0.05 then
			Blizz.SetScale(btn, 1.0)
			activeBtns[#activeBtns + 1] = btn
		end
	end

	local bb = _G.BagsBar
	if bb then
		HideDividerPools(bb)
		if bb.BorderArt then
			bb.BorderArt:SetAlpha(0)
		end
		if _G.CharacterReagentBag0Slot then
			_G.CharacterReagentBag0Slot.includeInLayout = false
			_G.CharacterReagentBag0Slot:SetAlpha(0)
			_G.CharacterReagentBag0Slot:SetSize(0.001, 0.001)
			_G.CharacterReagentBag0Slot:Hide()
		end
		if _G.BagBarExpandToggle then
			_G.BagBarExpandToggle.includeInLayout = false
			_G.BagBarExpandToggle:SetAlpha(0)
			_G.BagBarExpandToggle:SetSize(0.001, 0.001)
			_G.BagBarExpandToggle:Hide()
		end
		if bb.Layout then
			pcall(bb.Layout, bb)
		end
		HideDividerPools(bb)

		local scale = 0.72
		Blizz.SetScale(bb, scale)
		Blizz.ClearAllPoints(bb)
		Blizz.SetPoint(bb, "CENTER", bagDock, "BOTTOM", 0, 35 / scale)

		local visW, shiftX = MeasureVisibleButtonsBounds(bb, activeBtns, 165 * scale)
		Blizz.ClearAllPoints(bb)
		Blizz.SetPoint(bb, "CENTER", bagDock, "BOTTOM", shiftX / scale, 35 / scale)

		local wingW = math.max(255, (visW + 24) / 0.6875)
		bagDock:SetSize(wingW, 56)
		if bagDock.art then
			bagDock.art:SetSize(wingW, 114)
		end
		WireDockHover(bagDock, bb, activeBtns)

		if bb.ApplySystemAnchor and not anchorHooked[bb] then
			anchorHooked[bb] = true
			hooksecurefunc(bb, "ApplySystemAnchor", function()
				if not StandardMode:IsGamepad() and not InCombatLockdown() then
					SetupBagDock(false, angelX)
				end
			end)
		end
	end
end

-- Anchor the Pet Action Bar (PetActionBar / PetActionBarFrame) to the top-left of the uppermost active action bar row
local function SetupPetBar(isPad, topRowFirstBtn)
	local sm = cfg.standardMode
	if isPad or not (sm and sm.integratePetBar) or not topRowFirstBtn then
		return
	end
	local petBar = _G.PetActionBar or _G.PetActionBarFrame
	if not petBar then
		return
	end
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
	local scale = 0.85
	Blizz.SetScale(petBar, scale)
	Blizz.ClearAllPoints(petBar)
	Blizz.SetPoint(petBar, "BOTTOMLEFT", topRowFirstBtn, "TOPLEFT", 0, 6)

	if petBar.ApplySystemAnchor and not anchorHooked[petBar] then
		anchorHooked[petBar] = true
		hooksecurefunc(petBar, "ApplySystemAnchor", function()
			if not StandardMode:IsGamepad() and not InCombatLockdown() and topRowFirstBtn then
				Blizz.ClearAllPoints(petBar)
				Blizz.SetPoint(petBar, "BOTTOMLEFT", topRowFirstBtn, "TOPLEFT", 0, 6)
			end
		end)
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
	local bottomW = isPad and 670 or 780
	local barScale = isPad and 1.0 or (sm.standardBarScale or 1.18)

	local pframe = _G.Roth_UIPlayerFrame
	local powerOrb = _G.Roth_UIPowerOrb
	local demon = _G.Roth_UIDemonFrame
	local angel = _G.Roth_UIAngelFrame
	local bottomLine = _G.Roth_UIBottomLine
	local barBg = _G.Roth_UIActionBarBackground

	if barBg then
		barBg:SetScale(barScale)
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
			FitActionBarPaging(barBg)
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

	SetupMicroDock(isPad, demonX)
	SetupBagDock(isPad, angelX)
	SetupPetBar(isPad, topRowFirstBtn)

	-- Position Potion Belt:
	--   - Gamepad mode: beside Health Orb
	--   - Standard mode (default beltAnchor = "bags"): directly on top of the Right Bag Bar Wing (Roth_UIBagDock)
	--   - Standard mode (beltAnchor = "actionbar"): top-left of the uppermost activated action bar row
	local belt = _G.Roth_UIBelt
	if belt and not IsUserMoved("Roth_UIBelt") and pframe then
		belt:ClearAllPoints()
		if isPad then
			belt:SetPoint("BOTTOMLEFT", pframe, "BOTTOMRIGHT", cfg.belt.x or 6, cfg.belt.y or 24)
		elseif sm.beltAnchor ~= "actionbar" and bagDock then
			belt:SetPoint("BOTTOM", bagDock, "TOP", 0, -2)
		elseif topRowFirstBtn then
			belt:SetPoint("BOTTOMLEFT", topRowFirstBtn, "TOPLEFT", -4, 8)
		else
			belt:SetPoint("BOTTOM", pframe, "TOP", 0, -6)
		end
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
