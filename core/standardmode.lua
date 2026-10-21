-- Keyboard/gamepad HUD layout, action-bar fitting, and wing docks.
-- Defaults live in cfg.standardMode and cfg.gamepadLayout; saved layout overrides win.
-- Protected placement is deferred until combat ends.

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

local applyQueued, fittingDock = false, false
local applyingLayout = false
local function QueueApply()
	if fittingDock or applyQueued then return end
	if InCombatLockdown() then
		pendingApply = true
		return
	end
	applyQueued = true
	C_Timer.After(0, function()
		applyQueued = false
		StandardMode:Apply()
	end)
end

function StandardMode:RequestLayout(reason)
	if reason ~= "initial geometry" then self.geometryRetries = 0 end
	QueueApply()
end

local function QueueDockApply()
	if not StandardMode:IsGamepad() then QueueApply() end
end

-- Track hooks in addon-owned weak tables, avoiding fields on Blizzard frames.
local artHooked = setmetatable({}, { __mode = "k" })
local layoutHooked = setmetatable({}, { __mode = "k" })
local hoverHooked = setmetatable({}, { __mode = "k" })
local anchorHooked = setmetatable({}, { __mode = "k" })
local mouseDisabledHooked = setmetatable({}, { __mode = "k" })
local krbHooked = setmetatable({}, { __mode = "k" })
local krbTextureHooked = setmetatable({}, { __mode = "k" })
local dockControlHooked = setmetatable({}, { __mode = "k" })
local dockLayoutHooked = setmetatable({}, { __mode = "k" })

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
		krb:SetSize(45, 45)
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
		if ns.GamepadLayout then return ns.GamepadLayout:DefaultScales() end
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
		Roth_UIMicroDock = 1, Roth_UIBagDock = 1, Roth_UIBelt = 1,
		Roth_UIActionBarBackground = sm.standardBarScale or 1.18,
		Roth_UIPlayerFrame = sm.standardOrbScale or 1, -- both orbs: the power orb is its child
		Roth_UIDemonFrame = sm.standardStatueScale or 1,
		Roth_UIAngelFrame = sm.standardStatueScale or 1,
		-- the cast bar is a child of the player frame: undo the orb scale so it keeps its size
		Roth_UIPlayerFrameCastBarDragFrame = 1 / (sm.standardOrbScale or 1),
		Roth_UITargetFrame = sm.targetScale or 1,
		Roth_UITargetFrameCastBarDragFrame = 1.4,
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
	f:SetPoint("BOTTOM", ns.LayoutShift and ns.LayoutShift.anchor or UIParent, "BOTTOM", x / k, y / k)
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

-- The dock origin is the opening center; sculpted art may extend asymmetrically.
local function CreateDock(name, labelText, defaultX)
    local dock = CreateFrame("Frame", name, UIParent)
    dock:SetSize(330, 56)
    dock:SetFrameStrata("LOW")
    dock:SetFrameLevel(0)
    dock:SetPoint("BOTTOM", UIParent, "BOTTOM", defaultX, 0)
    dock.defaultPosition = { a1="BOTTOM", af="UIParent", a2="BOTTOM", x=defaultX, y=0 }
    dock:Hide()
    hooksecurefunc(dock, "SetScale", QueueDockApply)
    if func and func.applyDragFunctionality then
        func.applyDragFunctionality(dock)
        dock:SetClampedToScreen(false)
        if dock.dragframe then
            local label = dock.dragframe:CreateFontString(nil, "OVERLAY")
            label:SetFont(cfg.font or "Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
            label:SetPoint("CENTER")
            label:SetText(labelText)
        end
    end
    return dock
end

function StandardMode:EnsureDockRoots()
    local sm = cfg.standardMode
    if not (sm and sm.enabled) then return end
    if not microDock then microDock = CreateDock("Roth_UIMicroDock", "Micro Menu Wing", -590) end
    if not bagDock then bagDock = CreateDock("Roth_UIBagDock", "Bag Bar Wing", 590) end
end

function StandardMode:OwnsFrameScale(name)
    if not (cfg.standardMode and cfg.standardMode.enabled) then return false end
    return name == "Roth_UIMicroDock" or name == "Roth_UIBagDock" or name == "Roth_UIBelt"
        or name == "Roth_UIPowerOrb" or self:DefaultScale(name) ~= nil
end

function StandardMode:GetWingFit(frame)
    local data = frame and frame.wingFit
    if data then return data.requested, data.effective end
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

-- Visible border bounds from the 2x MicroMenu atlas (alpha >= 8):
-- Up background 64x82, painted half-open box (8,8)-(58,77). The native
-- 32x41 quad is centered on the 32x40 button; notifications are excluded.
local nativeMetrics = setmetatable({}, { __mode = "k" })
local function BodyMetric(button, side)
    local w,h=button:GetWidth(),button:GetHeight()
    if not w or not h or w<=0 or h<=0 then return end
    local bg=side=="micro" and button.Background
    local bw,bh,atlas,point,relative,relativePoint,dx,dy
    if bg then
        bw,bh=bg:GetSize()
        atlas=bg.GetAtlas and bg:GetAtlas()
        point,relative,relativePoint,dx,dy=bg:GetPoint()
    end
    local m=nativeMetrics[button]
    if m and m.nativeW==w and m.nativeH==h and m.bgW==bw and m.bgH==bh
        and m.atlas==atlas and m.dx==dx and m.dy==dy and m.point==point
        and m.relative==relative and m.relativePoint==relativePoint then return m end
    m={l=0,r=w,b=0,t=h,nativeW=w,nativeH=h,bgW=bw,bgH=bh,atlas=atlas,
        point=point,relative=relative,relativePoint=relativePoint,dx=dx,dy=dy,
        source=side=="micro" and "unmapped native frame" or "Roth normal border",calibrated=side~="micro"}
    if atlas=="UI-HUD-MicroMenu-ButtonBG-Up" and bw and bh and bw>0 and bh>0
        and point=="CENTER" and relative==button and relativePoint=="CENTER" then
        m.l=w*.5+(dx or 0)-bw*.5+bw*8/64
        m.r=w*.5+(dx or 0)-bw*.5+bw*58/64
        m.b=h*.5+(dy or 0)-bh*.5+bh*5/82
        m.t=h*.5+(dy or 0)-bh*.5+bh*74/82
        m.source,m.calibrated="MicroMenu Up border (2x alpha bounds)",true
    end
    nativeMetrics[button]=m
    return m
end

local function SetControlScale(frame, value)
    local previous = fittingDock
    fittingDock = true
    Blizz.SetScale(frame, value)
    fittingDock = previous
end

local function WatchControls(container, layoutFrame, buttons)
    if not dockControlHooked[container] then
        dockControlHooked[container] = true
        container:HookScript("OnSizeChanged", QueueDockApply)
        hooksecurefunc(container, "SetScale", QueueDockApply)
        if container.ApplySystemAnchor then hooksecurefunc(container, "ApplySystemAnchor", QueueDockApply) end
    end
    if layoutFrame and not dockLayoutHooked[layoutFrame] then
        dockLayoutHooked[layoutFrame] = true
        if layoutFrame.Layout then hooksecurefunc(layoutFrame, "Layout", QueueDockApply) end
        if layoutFrame.ResetMicroMenuPosition then hooksecurefunc(layoutFrame, "ResetMicroMenuPosition", QueueDockApply) end
    end
    for _, button in ipairs(buttons) do
        if not dockControlHooked[button] then
            dockControlHooked[button] = true
            button:HookScript("OnShow", QueueDockApply)
            button:HookScript("OnHide", QueueDockApply)
            button:HookScript("OnSizeChanged", QueueDockApply)
        end
    end
end

local function LayoutRoot()
    return ns.LayoutShift and ns.LayoutShift.anchor or UIParent
end

local function RootCenterUI()
    local root = LayoutRoot()
    local q = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x = root:GetCenter()
    return x and x*q or UIParent:GetWidth()*0.5
end

local function PlaceDock(dock, solution)
    SetControlScale(dock, solution.q)
    dock:ClearAllPoints()
    dock:SetPoint("BOTTOM", LayoutRoot(), "BOTTOM", (solution.cx-RootCenterUI())/solution.q, solution.bottom/solution.q)
end

local function CopyPoint(p)
    if not p then return end
    local out = {}
    for k,v in pairs(p) do out[k]=v end
    return out
end

local function BackupLayout(prof)
    if prof.wingLayoutV1Backup then return prof.wingLayoutV1Backup end
    local b = { positions={}, scales={}, beltAnchor=cfg.standardMode.beltAnchor }
    for _, name in ipairs({"Roth_UIMicroDock", "Roth_UIBagDock", "Roth_UIBelt"}) do
        b.positions[name] = CopyPoint(prof.framePositions and prof.framePositions[name])
        b.scales[name] = prof.frameScales and prof.frameScales[name]
    end
    prof.wingLayoutV1Backup = b
    return b
end

local function CaptureFrame(frame)
    local saved={frame=frame,w=frame:GetWidth(),h=frame:GetHeight(),scale=frame:GetScale(),points={}}
    for i=1,frame:GetNumPoints() do saved.points[i]={frame:GetPoint(i)} end
    return saved
end

local function RestoreFrame(saved)
    local f=saved.frame
    SetControlScale(f,saved.scale)
    f:SetSize(saved.w,saved.h)
    f:ClearAllPoints()
    for _,p in ipairs(saved.points) do f:SetPoint(unpack(p)) end
end

local function ApplyStoredPoint(frame,pos)
    if not pos then return false end
    local relative=UIParent
    if pos.relativeTo then
        relative=_G[pos.relativeTo]
        if not relative then return false end
    end
    if relative==UIParent then relative=LayoutRoot() end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "BOTTOM",relative,pos.relativePoint or "BOTTOM",pos.x or 0,pos.y or 0)
    return true
end

local function PreferredDock(dock,buttons,side,requested)
    local prof=ns.LayoutProfile and ns.LayoutProfile()
    local pos=prof and prof.framePositions and prof.framePositions[dock:GetName()]
    if not pos then return nil,cfg.standardMode.dockY or 0,true end
    local saved=CaptureFrame(dock)
    local legacy
    SetControlScale(dock,requested)
    if not pos.wingV2 then
        local width,height,count=0,0,0
        for _,button in ipairs(buttons) do
            if button:IsShown() then
                local m=BodyMetric(button,side)
                if m then width=width+m.nativeW;height=math.max(height,m.nativeH);count=count+1 end
            end
        end
        width=width+math.max(0,count-1)*(side=="micro" and -5 or 2)
        dock:SetSize((width*.72+4)*512/356,height*.72+13)
    end
    local valid=ApplyStoredPoint(dock,pos)
    local rect=valid and ns.WingLayout.FrameRectUI(dock)
    if rect and not pos.wingV2 then
        BackupLayout(prof)
        legacy=CaptureFrame(dock)
        pos={point="BOTTOM",relativeTo="UIParent",relativePoint="BOTTOM",wingV2=true,
            x=((rect.l+rect.r)*.5-RootCenterUI())/requested,y=rect.b/requested}
        prof.framePositions[dock:GetName()]=pos
    end
    RestoreFrame(saved)
    if rect then return (rect.l+rect.r)*.5,rect.b,true,legacy end
    return nil,nil,false
end

local pendingBag,nativeBagBounds
local CommitControls

local function StatueRects(frame,kind)
    local art=cfg.units and cfg.units.player and cfg.units.player.art
    if not frame and art and art[kind] and art[kind].show==false then return {} end
    return ns.WingLayout.StatueRectsUI(frame,kind)
end

local function FitControls(dock, container, buttons, side, statue, deferred)
    local W = ns.WingLayout
    if not W then return false end
    local sm = cfg.standardMode
    local height = side=="micro" and (sm.microBodyHeight or 28) or (sm.bagBodyHeight or 30)
    local gap = side=="micro" and (sm.microButtonGap or 1) or (sm.bagButtonGap or 2)
    local shown, width = {}, 0
    for _,button in ipairs(buttons) do
        if button:IsShown() and (button:GetAlpha() or 1)>0.05 then
            local m=BodyMetric(button,side)
            if m then
                local scale=height/(m.t-m.b)
                shown[#shown+1]={button=button,metric=m,scale=scale,width=(m.r-m.l)*scale}
                width=width+(m.r-m.l)*scale
            end
        end
    end
    if #shown==0 then dock:Hide(); return true end
    width=width+gap*(#shown-1)
    local requested=(ns.EditMode and ns.EditMode:GetScale(dock) or 1)*(ns.EditMode and ns.EditMode:GetGlobalScale() or 1)
    local cx,bottom,resolved,legacy=PreferredDock(dock,buttons,side,requested)
    if not resolved then dock.layoutStatus="pending-anchor";return false end
    local offset=side=="micro" and (sm.microJoinOffset or 0) or (sm.bagJoinOffset or 0)
    do -- legacy distance differences become an offset, not a scale ratio
        local legacy=side=="micro" and (sm.microDockOffset or 235)-235 or (sm.bagDockOffset or 240)-240
        if legacy~=0 then offset=offset+legacy*(sm.standardStatueScale or .78)/.85 end
    end
    local statueRects=StatueRects(statue,side=="micro" and "demon" or "angel")
    if not statueRects then dock.layoutStatus="pending-statue";return false end
    local solution,reason=W.SolveWing({side=side,bodyWidth=width,bodyHeight=height,padding=2,
        requestedScale=requested,preferredCenterX=cx,bottom=bottom,style=sm.wingStyle,
        joinOffsetUI=offset,screen={l=0,r=UIParent:GetWidth(),b=0,t=UIParent:GetHeight()},
        statueRects=statueRects})
    if not solution then dock.layoutStatus=reason; return false end
    solution.tint=sm.wingTint
    local ready,renderReason=W.CanRender(solution,side)
    if not ready then dock.layoutStatus=renderReason;return false end
    local plan={dock=dock,container=container,buttons=buttons,shown=shown,width=width,height=height,
        gap=gap,solution=solution,requested=requested,side=side,legacy=legacy}
    if deferred then pendingBag=plan;return true end
    return CommitControls(plan)
end

CommitControls=function(plan)
    local dock,container,solution=plan.dock,plan.container,plan.solution
    PlaceDock(dock,solution)
    local rendered,reason=ns.WingLayout.Render(dock,solution,plan.side)
    if not rendered then dock.layoutStatus=reason;return false end
    dock.wingFit={requested=plan.requested,effective=solution.q}
    dock.defaultPosition={a1="BOTTOM",af="UIParent",a2="BOTTOM",
        x=(solution.cx-RootCenterUI())/plan.requested,y=solution.bottom/plan.requested}
    dock.layoutStatus=solution.status
    SetControlScale(container,1)
    Blizz.ClearAllPoints(container)
    Blizz.SetPoint(container,"CENTER",dock,"CENTER",0,0)
    local x=-plan.width*.5
    for _,item in ipairs(plan.shown) do
        local button,m=item.button,item.metric
        local parent=button:GetParent()
        SetControlScale(button,item.scale*dock:GetEffectiveScale()/parent:GetEffectiveScale())
        local targetX=x+item.width*.5
        local targetY=solution.baseHeight+2+plan.height*.5
        local opticalX=(m.l+m.r-m.nativeW)*.5
        local opticalY=(m.b+m.t-m.nativeH)*.5
        Blizz.ClearAllPoints(button)
        Blizz.SetPoint(button,"CENTER",dock,"BOTTOM",targetX/item.scale-opticalX,targetY/item.scale-opticalY)
        x=x+item.width+plan.gap
    end
    dock.controls=plan.shown
    local prof=ns.LayoutProfile and ns.LayoutProfile()
    dock:SetShown(not(prof and prof.disabledElements and prof.disabledElements[dock:GetName()]))
    WireDockHover(dock,container,plan.buttons)
    WatchControls(container,container,plan.buttons)
    if ns.EditMode and ns.EditMode.RefreshWingBounds then ns.EditMode:RefreshWingBounds(dock) end
    return true
end

local function SetupMicroDock(isPad)
    local sm=cfg.standardMode
    if not microDock then return end
    if isPad or not sm.integrateMicroMenu then microDock:Hide(); return end
    local mm,container=_G.MicroMenu,_G.MicroMenuContainer or _G.MicroMenu
    if not (mm and container and mm.GetChildren) then return false end
    if mm.BorderArt then mm.BorderArt:SetAlpha(0) end
    if mm.BackgroundArt then mm.BackgroundArt:SetAlpha(0) end
    local buttons={}
    for _,button in ipairs({mm:GetChildren()}) do
        if button.layoutIndex then buttons[#buttons+1]=button end
    end
    table.sort(buttons,function(a,b)return a.layoutIndex<b.layoutIndex end)
    -- Read native dimensions before calculating each painted border.
    for _,button in ipairs(buttons)do BodyMetric(button,"micro")end
    if mm~=container then
        Blizz.ClearAllPoints(mm);Blizz.SetPoint(mm,"CENTER",container,"CENTER",0,0)
    end
    local ok=FitControls(microDock,container,buttons,"micro",_G.Roth_UIDemonFrame)
    WatchControls(container,mm,buttons)
    return ok
end

local function SetupBagDock(isPad)
    if not bagDock then return end
    if isPad then bagDock:Hide();return end
    local bb=_G.BagsBar
    if not bb then return false end
    if not cfg.standardMode.integrateBags then
        bagDock:Hide()
        local buttons,bounds={},nil
        for _,name in ipairs(BAG_LIST)do
            local button=_G[name]
            if button then
                buttons[#buttons+1]=button
                if button:IsShown() and (button:GetAlpha()or 1)>.05 then
                    local R=ns.WingLayout.FrameRectUI(button)
                    local m=BodyMetric(button,"bags")
                    if R and m then
                        local q=button:GetEffectiveScale()/UIParent:GetEffectiveScale()
                        local p={l=R.l+m.l*q,r=R.l+m.r*q,b=R.b+m.b*q,t=R.b+m.t*q}
                        if not bounds then bounds=p else
                            bounds.l=math.min(bounds.l,p.l);bounds.r=math.max(bounds.r,p.r)
                            bounds.b=math.min(bounds.b,p.b);bounds.t=math.max(bounds.t,p.t)
                        end
                    end
                end
            end
        end
        nativeBagBounds=bounds
        WatchControls(bb,bb,buttons)
        return bounds~=nil
    end
    local krb=_G.KeyRingButton
    if krb then SetupKeyRingButton(krb);StyleBagItemButton(krb)end
    local reagent=_G.CharacterReagentBag0Slot
    if reagent then reagent.includeInLayout=false;reagent:SetSize(45,45);reagent:SetAlpha(1);reagent:Show()end
    local toggle=_G.BagBarExpandToggle
    if toggle then toggle.includeInLayout=false;toggle:SetAlpha(0);toggle:Hide()end
    if bb.BorderArt then bb.BorderArt:SetAlpha(0)end
    HideDividerPools(bb)
    local buttons={}
    for i=#BAG_LIST,1,-1 do
        local button=_G[BAG_LIST[i]]
        if button then StyleBagItemButton(button);BodyMetric(button,"bags");buttons[#buttons+1]=button end
    end
    return FitControls(bagDock,bb,buttons,"bags",_G.Roth_UIAngelFrame,true)
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

-- Reanchor after Blizzard repositions the pet bar through ClearAllPoints/SetPoint.
-- ApplySystemAnchor alone misses action-bar, override-bar, and status-bar changes.
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

function StandardMode:IsDockedBelt()
    return cfg.standardMode and cfg.standardMode.enabled and not self:IsGamepad()
end

function StandardMode:GetBeltDockOffsets()
    local prof=ns.LayoutProfile and ns.LayoutProfile()
    local b=prof and prof.beltDock
    return b and b.xUI or 0,b and b.gapUI or 6
end

function StandardMode:SetBeltDockOffsets(x,gap)
    local prof=ns.LayoutProfile and ns.LayoutProfile()
    if not prof then return end
    BackupLayout(prof)
    local old=prof.beltDock or {}
    prof.beltDock={xUI=x~=nil and x or old.xUI or 0,gapUI=math.max(4,math.min(150,gap~=nil and gap or old.gapUI or 6))}
    prof.wingLayoutVersion=1
    self:RequestLayout("belt offset")
end

function StandardMode:SaveBeltDockPosition(frame)
    if not (bagDock and ns.Belt and ns.Belt.GetPaintBoundsLocal)then return end
    if ns.LayoutShift then ns.LayoutShift:AfterMove(frame)end
    local R=ns.WingLayout.FrameRectUI(frame)
    if not R then return end
    local B=ns.Belt:GetPaintBoundsLocal()
    local q=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local native=not cfg.standardMode.integrateBags
    local body=native and nativeBagBounds or bagDock.bodyBounds
    local shelf=native and nativeBagBounds or bagDock.paintBounds
    if not(body and shelf)then return end
    self:SetBeltDockOffsets(R.l+(B.l+B.r)*q*.5-(body.l+body.r)*.5,R.b+B.b*q-shelf.t)
end

-- Resolve old free anchors only once valid geometry exists. Read without
-- committing preferences or changing the currently painted bag/belt pair.
local function BeltOffsets(prof,belt,requested,row,shelf,legacyBag)
    if prof.beltDock then return prof.beltDock.xUI or 0,prof.beltDock.gapUI or 6,true end
    local pos=prof.framePositions and prof.framePositions.Roth_UIBelt
    if not pos then return 0,6,true end
    local saved,bagSaved=CaptureFrame(belt),legacyBag and CaptureFrame(bagDock)
    if legacyBag then RestoreFrame(legacyBag) end
    SetControlScale(belt,requested)
    local valid=ApplyStoredPoint(belt,pos)
    local R=valid and ns.WingLayout.FrameRectUI(belt)
    if bagSaved then RestoreFrame(bagSaved) end
    RestoreFrame(saved)
    if not R then return nil,nil,false end
    local B=ns.Belt:GetPaintBoundsLocal()
    return R.l+(B.l+B.r)*requested*.5-(row.l+row.r)*.5,
        math.max(4,math.min(150,R.b+B.b*requested-shelf.t)),true
end

function StandardMode:AnchorBelt()
    local belt=_G.Roth_UIBelt
    if not(cfg.standardMode and cfg.standardMode.enabled)then return false end
    if InCombatLockdown()then pendingApply=true;return true end
    if self:IsGamepad()then
        if not belt or IsUserMoved("Roth_UIBelt")then return false end
        local y=cfg.gamepadLayout.beltY
        for _,name in ipairs({"Roth_UIExpBar","Roth_UIRepBar"})do
            local f=_G[name];local top=f and f:IsShown()and f:GetTop()
            if top then y=math.max(y,top*f:GetEffectiveScale()/UIParent:GetEffectiveScale()+16)end
        end
        belt:ClearAllPoints();belt:SetClampedToScreen(true)
        PlaceAtBottom(belt,ns.GamepadLayout:OrbCenter(),y)
        return true
    end
    local plan=pendingBag
    local native=not cfg.standardMode.integrateBags
    local row=native and nativeBagBounds or plan and plan.solution.bodyUI or bagDock and bagDock.bodyBounds
    local shelf=native and nativeBagBounds or plan and plan.solution.paintUI or bagDock and bagDock.paintBounds
    if not(row and shelf)then return false end
    if not(belt and ns.Belt and ns.WingLayout)then
        if plan then return CommitControls(plan)end
        return true
    end
    local prof=ns.LayoutProfile and ns.LayoutProfile()
    if cfg.belt and cfg.belt.show==false or prof and prof.disabledElements and prof.disabledElements.Roth_UIBelt then
        if plan then return CommitControls(plan)end
        return true
    end
    -- Existing bag geometry must resolve before committing either component.
    if not native and not ns.WingLayout.FrameRectUI(bagDock) then belt.layoutStatus="pending-bag";return false end
    if not prof then return false end
    local requested=(ns.EditMode and ns.EditMode:GetScale(belt)or 1)*(ns.EditMode and ns.EditMode:GetGlobalScale()or 1)
    local x,gap,valid=BeltOffsets(prof,belt,requested,row,shelf,plan and plan.legacy)
    if not valid then belt.layoutStatus="pending-belt-anchor";return false end
    local obstacles={}
    for _,kind in ipairs({"angel","demon"})do
        local f=kind=="angel" and _G.Roth_UIAngelFrame or _G.Roth_UIDemonFrame
        local rects=StatueRects(f,kind)
        if not rects then belt.layoutStatus="pending-statue";return false end
        for _,r in ipairs(rects)do obstacles[#obstacles+1]=r end
    end
    local solved,reason=ns.WingLayout.SolveBelt({localPaint=ns.Belt:GetPaintBoundsLocal(),requestedScale=requested,
        bagRow=row,bagShelf=shelf,statueRects=obstacles,
        screen={l=0,r=UIParent:GetWidth(),b=0,t=UIParent:GetHeight()},userOffsetX=x,userGap=gap,maxRaise=24})
    if not solved then belt.layoutStatus=reason;return false end
    if plan and not CommitControls(plan)then return false end
    local R=ns.WingLayout.FrameRectUI(native and LayoutRoot() or bagDock)
    if not R then belt.layoutStatus="pending-bag";return false end
    if not prof.beltDock then
        BackupLayout(prof)
        prof.beltDock={xUI=x,gapUI=gap}
        prof.wingLayoutVersion=1
    end
    SetControlScale(belt,solved.q)
    belt:SetClampedToScreen(false)
    belt:ClearAllPoints()
    belt:SetPoint("BOTTOMLEFT",native and LayoutRoot() or bagDock,"BOTTOMLEFT",(solved.x-R.l)/solved.q,(solved.y-R.b)/solved.q)
    belt.wingFit={requested=requested,effective=solved.q}
    belt.paintBounds=solved.paintUI
    belt.layoutStatus=solved.status
    return true
end

function StandardMode:DebugWings()
    for _,f in ipairs({microDock,bagDock,_G.Roth_UIBelt})do
        local fit=f.wingFit
        local p=f.paintBounds
        print(string.format("%s: %s; requested %.3f, effective %.3f",f:GetName(),f.layoutStatus or "pending",
            fit and fit.requested or 0,fit and fit.effective or 0))
        if p then print(string.format("paint L%.1f R%.1f B%.1f T%.1f",p.l,p.r,p.b,p.t))end
        local item=f.controls and f.controls[1]
        local m=item and item.metric
        if m then print(string.format("border %.1fx%.1f; %s",m.r-m.l,m.t-m.b,m.source))end
    end
end

-- Apply mode-appropriate layout (always runs out of combat)
local function ApplyLayout(self)
	if not (cfg.standardMode and cfg.standardMode.enabled) then
		return
	end
	if InCombatLockdown() then
		pendingApply = true
		return
	end
	pendingBag,nativeBagBounds=nil,nil
	self:EnsureDockRoots()

	local isPad = self:IsGamepad()
	if ns.GamepadLayout then ns.GamepadLayout:PrepareMode(isPad) end
	if ns.GamepadLayout then ns.GamepadLayout:WatchCrossbar() end
	if ns.GamepadLayout then ns.GamepadLayout:ArrangePanels(isPad) end
 if ns.Tooltips and ns.EditMode and ns.EditMode.active then ns.Tooltips.Refresh() end
	local centerX = isPad and ns.GamepadLayout:OrbCenter() or 0
	local sm = cfg.standardMode
	local orbX = isPad and ns.GamepadLayout:OrbSpacing() or (sm.standardOrbX or 325)
	local statueScale = isPad and cfg.gamepadLayout.artScale or (sm.standardStatueScale or 1)
	-- statue offsets from the orb centre shrink with the statue art
	local demonX = centerX - (orbX + 30 * statueScale)
	local angelX = centerX + orbX + 25 * statueScale
	local bottomW = isPad and (2 * orbX + 100) or (2 * orbX + 180)

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
		if f and (isPad or (name~="Roth_UIMicroDock" and name~="Roth_UIBagDock" and name~="Roth_UIBelt")) then
			local s = (ns.EditMode and ns.EditMode.GetScale and ns.EditMode:GetScale(f)) or self:DefaultScale(name)
			f:SetScale(s * gs)
		end
	end

	local orbY = isPad and cfg.gamepadLayout.orbY or (cfg.units.player.pos.y or 10)
	if pframe and not IsUserMoved("Roth_UIPlayerFrame") then
		PlaceAtBottom(pframe, centerX - orbX, orbY)
	end
	if powerOrb and not IsUserMoved("Roth_UIPowerOrb") then
		PlaceAtBottom(powerOrb, centerX + orbX, orbY)
	end
	if demon and not IsUserMoved("Roth_UIDemonFrame") then
		PlaceAtBottom(demon, demonX, isPad and cfg.gamepadLayout.artY or (cfg.units.player.art.demon.pos.y or -2))
	end
	if angel and not IsUserMoved("Roth_UIAngelFrame") then
		PlaceAtBottom(angel, angelX, isPad and cfg.gamepadLayout.artY or (cfg.units.player.art.angel.pos.y or -2))
	end
	if bottomLine and not IsUserMoved("Roth_UIBottomLine") then
		bottomLine:SetSize(bottomW, 112)
		if isPad then
			PlaceAtBottom(bottomLine, centerX, cfg.units.player.art.bottomline.pos.y or 0)
		end
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

	if ns.LayoutShift then ns.LayoutShift:Sync(true) end
	local microOK=SetupMicroDock(isPad)
	local bagOK=SetupBagDock(isPad)
	HookPetBarMovers()
	self:AnchorPetBar()
	local beltOK=self:AnchorBelt()
    if ns.EditMode and ns.EditMode.UpdateDialog then ns.EditMode:UpdateDialog() end
    if (microOK==false or bagOK==false or beltOK==false) and (self.geometryRetries or 0)<1 then
        self.geometryRetries=(self.geometryRetries or 0)+1
        C_Timer.After(0,function() StandardMode:RequestLayout("initial geometry") end)
    end
	-- frame edges are only known once the anchors above have resolved
	C_Timer.After(0, function()
		StandardMode:PlaceStack()
	end)
end

function StandardMode:Apply()
    if applyingLayout then return end
    if not(cfg.standardMode and cfg.standardMode.enabled)then return end
    if InCombatLockdown()then pendingApply=true;return end
    pendingApply=false
    applyingLayout,fittingDock=true,true
    local ok,why=xpcall(function() ApplyLayout(self) end,function(err)return err end)
    applyingLayout,fittingDock=false,false
    pendingBag=nil
    if not ok then
        if geterrorhandler then geterrorhandler()(why) else error(why,0) end
    end
end

-- Top of a frame in UIParent units (nil until it has a position)
local function TopInUI(f)
	local top = f and f:GetTop()
	if not top then
		return nil
	end
	return top * f:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- Keyboard stack: action rows, reserved pet-bar space, player cast bar, swing timer.
-- Saved element positions take precedence; pet-frame placement is configured separately.
function StandardMode:PlaceStack()
	local sm = cfg.standardMode
	if not (sm and sm.enabled) then return end
	if InCombatLockdown() then
		pendingApply = true
		return
	end
	if self:IsGamepad() then
		ns.GamepadLayout:PlaceHUD()
		return
	end
	if ns.SwingTimer then ns.SwingTimer.Place() end

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
	if ns.GamepadLayout then ns.GamepadLayout:PlaceTargetCastbar() end
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

-- Pet-frame anchors: healthOrb, orb (power), petbarLeft, or petbarRight.
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
			-- measured on screen, so take out the "Move all" offset the pet frame gets anyway
			local x = refX * ref:GetEffectiveScale() / uiEff - UIParent:GetWidth() / 2
				- (ns.LayoutShift and ns.LayoutShift:Get() or 0)
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

-- Target-frame anchors: powerOrb (default), healthOrb, or top.
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

-- Target-of-target anchors: topright, topleft, left, or right of the target frame.
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

UIParent:HookScript("OnSizeChanged",QueueApply)
hooksecurefunc(UIParent,"SetScale",QueueApply)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("UI_SCALE_CHANGED")
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
for _, bar in ipairs({ _G.MultiBarBottomLeft, _G.MultiBarBottomRight }) do
	bar:HookScript("OnShow", QueueApply)
	bar:HookScript("OnHide", QueueApply)
end
