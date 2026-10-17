--get the addon namespace
local addon, ns = ...

--object container
local bars = CreateFrame("Frame")
ns.bars = bars

--get the functions
local func = ns.func
local cfg = ns.cfg
local barposition = ns.player
local mediapath = "Interface\\AddOns\\DiabolusUnits\\media\\"

---------------------------------------------
-- FUNCTIONS
---------------------------------------------

-- Add dark stone trough border and 10-segment Diablo tick marks (10%..90%)
local function decorateDiabloBar(bar)
	if bar._diabloDecorated then
		return
	end
	bar._diabloDecorated = true

	local trough = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	trough:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
	trough:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
	trough:SetColorTexture(0.05, 0.04, 0.03, 0.88)
	bar.trough = trough

	local topRim = bar:CreateTexture(nil, "OVERLAY", nil, 2)
	topRim:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
	topRim:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
	topRim:SetHeight(1)
	topRim:SetColorTexture(0.38, 0.30, 0.20, 0.85)

	local botRim = bar:CreateTexture(nil, "OVERLAY", nil, 2)
	botRim:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1)
	botRim:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
	botRim:SetHeight(1)
	botRim:SetColorTexture(0.22, 0.17, 0.11, 0.90)

	bar.ticks = {}
	for i = 1, 9 do
		local tick = bar:CreateTexture(nil, "OVERLAY", nil, 3)
		tick:SetWidth(1)
		tick:SetColorTexture(0.08, 0.06, 0.04, 0.85)
		bar.ticks[i] = tick
	end

	local function layoutTicks(s)
		local w = s:GetWidth()
		if not w or w <= 0 then
			return
		end
		for i = 1, 9 do
			local tick = s.ticks[i]
			tick:ClearAllPoints()
			tick:SetPoint("TOPLEFT", s, "TOPLEFT", math.floor(w * (i / 10) + 0.5), 0)
			tick:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", math.floor(w * (i / 10) + 0.5), 0)
		end
	end

	bar:HookScript("OnSizeChanged", layoutTicks)
	layoutTicks(bar)
end

--create the exp bar
bars.createExpBar = function(self)
	local cfg = self.cfg.expbar
	if not cfg.show then
		return
	end

	local w, h = 365, 10

	local f = CreateFrame("StatusBar", "Roth_UIExpBar", UIParent)
	f:SetFrameStrata("LOW")
	f:SetFrameLevel(5)
	f:SetSize(w, h)
	local pos = cfg.pos or { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 14 }
	f:ClearAllPoints()
	local relTo = (type(pos.af) == "string" and _G[pos.af]) or pos.af or UIParent
	f:SetPoint(pos.a1 or "BOTTOM", relTo, pos.a2 or "BOTTOM", pos.x or 0, pos.y or 14)
	f.defaultPosition = { a1 = "BOTTOMLEFT", af = "Roth_UIPlayerFrame", a2 = "BOTTOMRIGHT", x = -8, y = 4 }
	f:SetScale(cfg.scale or 1)
	f:SetStatusBarTexture(cfg.texture)
	f:SetStatusBarColor(cfg.color.r, cfg.color.g, cfg.color.b)

	local r = CreateFrame("StatusBar", nil, f)
	r:SetAllPoints(f)
	r:SetStatusBarTexture(cfg.texture)
	r:SetStatusBarColor(cfg.rested.color.r, cfg.rested.color.g, cfg.rested.color.b)

	func.applyDragFunctionality(f)

	local t = r:CreateTexture(nil, "BACKGROUND", nil, -6)
	t:SetAllPoints(r)
	t:SetTexture(cfg.texture)
	t:SetVertexColor(cfg.color.r, cfg.color.g, cfg.color.b, 0.25)
	f.bg = t

	decorateDiabloBar(f)

	f:SetScript("OnEnter", function(s)
		local Secrets = ns.Secrets
		local mxp = Secrets and Secrets.Number(UnitXPMax("player")) or UnitXPMax("player")
		local xp = Secrets and Secrets.Number(UnitXP("player")) or UnitXP("player")
		local rxp = Secrets and Secrets.Number(GetXPExhaustion()) or GetXPExhaustion()
		local lvl = Secrets and Secrets.Number(UnitLevel("player")) or UnitLevel("player")
		local maxLvl = ns.Compat.MaxPlayerLevel()
		GameTooltip:SetOwner(s, "ANCHOR_TOP")
		GameTooltip:AddLine("Experience / Rested", 0, 1, 0.5, 1, 1, 1)
		if (not lvl or not maxLvl or lvl ~= maxLvl) and xp and mxp and mxp > 0 then
			local pct = math.floor((xp / mxp) * 1000) / 10
			GameTooltip:AddDoubleLine(
				COMBAT_XP_GAIN or "XP",
				xp .. "/" .. mxp .. " (" .. pct .. "%)",
				cfg.color.r,
				cfg.color.g,
				cfg.color.b,
				1,
				1,
				1
			)
			if rxp then
				local rpct = math.floor((rxp / mxp) * 1000) / 10
				GameTooltip:AddDoubleLine(
					TUTORIAL_TITLE26 or "Rested",
					rxp .. " (" .. rpct .. "%)",
					cfg.rested.color.r,
					cfg.rested.color.g,
					cfg.rested.color.b,
					1,
					1,
					1
				)
			end
		end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function(s)
		GameTooltip:Hide()
	end)

	self.Experience = f
	self.Experience.Rested = r
end

--create the reputation bar
bars.createRepBar = function(self)
	local cfg = self.cfg.repbar
	if not cfg.show then
		return
	end

	local w, h = 365, 9

	local f = CreateFrame("StatusBar", "Roth_UIRepBar", UIParent)
	f:SetFrameStrata("LOW")
	f:SetFrameLevel(5)
	f:SetSize(w, h)
	local pos = cfg.pos or { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 4 }
	f:ClearAllPoints()
	local relTo = (type(pos.af) == "string" and _G[pos.af]) or pos.af or UIParent
	f:SetPoint(pos.a1 or "BOTTOM", relTo, pos.a2 or "BOTTOM", pos.x or 0, pos.y or 4)
	f.defaultPosition = { a1 = "BOTTOMLEFT", af = "Roth_UIPlayerFrame", a2 = "BOTTOMRIGHT", x = -8, y = 4 }
	f:SetScale(cfg.scale or 1)
	f:SetStatusBarTexture(cfg.texture)
	f:SetStatusBarColor(0, 0.7, 0)

	func.applyDragFunctionality(f)

	local t = f:CreateTexture(nil, "BACKGROUND", nil, -6)
	t:SetAllPoints(f)
	t:SetTexture(cfg.texture)
	t:SetVertexColor(0, 0.7, 0)
	t:SetAlpha(0.25)
	f.bg = t

	decorateDiabloBar(f)

	f:SetScript("OnEnter", function(s)
		-- Use compat shim so we read from C_Reputation.GetWatchedFactionData
		-- on clients where the legacy global is gone.
		local GetWatchedFactionInfoCompat = (ns.Compat and ns.Compat.GetWatchedFactionInfo) or GetWatchedFactionInfo
		if not GetWatchedFactionInfoCompat then
			return
		end
		-- (the lookup was fetched but never called: the tooltip came up empty and unanchored)
		local name, standing, minrep, maxrep, value = GetWatchedFactionInfoCompat()
		if not name then
			return
		end
		GameTooltip:SetOwner(s, "ANCHOR_TOP")
		local Secrets = ns.Secrets
		local valNum = Secrets and Secrets.Number(value) or value
		local minNum = Secrets and Secrets.Number(minrep) or minrep
		local maxNum = Secrets and Secrets.Number(maxrep) or maxrep
		local stdNum = Secrets and Secrets.Number(standing) or standing
		if name and stdNum and minNum and maxNum and valNum then
			-- Guard FACTION_BAR_COLORS[standing] — out-of-range standings or
			-- partial data return nil and the original indexed color.r directly.
			local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[stdNum]
			local r, g, b = 1, 1, 1
			if color then
				r, g, b = color.r, color.g, color.b
			end
			local span = maxNum - minNum
			local pct = (span > 0) and (floor((valNum - minNum) / span * 1000) / 10) or 0
			GameTooltip:AddDoubleLine(FACTION, name, r, g, b, 1, 1, 1)
			GameTooltip:AddDoubleLine(STANDING, _G["FACTION_STANDING_LABEL" .. stdNum] or "", r, g, b, 1, 1, 1)
			GameTooltip:AddDoubleLine(
				REPUTATION,
				(valNum - minNum) .. "/" .. span .. " (" .. pct .. "%)",
				r,
				g,
				b,
				1,
				1,
				1
			)
		elseif name then
			GameTooltip:AddDoubleLine(FACTION, name, 1, 1, 1, 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function(s)
		GameTooltip:Hide()
	end)

	self.Reputation = f
end

-- Dynamically stretch status bars (XP / Rep) from health orb to power orb
bars.UpdateStatusBarLayout = function()
	local exp = rawget(_G, "Roth_UIExpBar")
	local rep = rawget(_G, "Roth_UIRepBar")
	if not exp and not rep then
		return
	end

	local p = cfg.units and cfg.units.player
	if not p then
		return
	end

	local Secrets = ns.Secrets
	local pLevel = Secrets and Secrets.Number(UnitLevel("player")) or UnitLevel("player")
	local maxLvl = ns.Compat and ns.Compat.MaxPlayerLevel and ns.Compat.MaxPlayerLevel() or 60
	local showExp = p.expbar and p.expbar.show and (pLevel ~= maxLvl)
	local getWatchedFaction = GetWatchedFactionInfo or (ns.Compat and ns.Compat.GetWatchedFactionInfo)
	local showRep = p.repbar and p.repbar.show and (getWatchedFaction and getWatchedFaction() ~= nil)

	local count = 0
	if showExp then
		count = count + 1
	end
	if showRep then
		count = count + 1
	end

	local pframe = rawget(_G, "Roth_UIPlayerFrame")
	local powerOrb = rawget(_G, "Roth_UIPowerOrb")

	local prof = ns.LayoutProfile and ns.LayoutProfile()
	local expMoved = prof and prof.framePositions and prof.framePositions["Roth_UIExpBar"]
	local repMoved = prof and prof.framePositions and prof.framePositions["Roth_UIRepBar"]

	if exp then
		exp:SetFrameStrata("LOW")
		exp:SetFrameLevel(5)
	end
	if rep then
		rep:SetFrameStrata("LOW")
		rep:SetFrameLevel(5)
	end

	if count == 0 then
		if exp and not expMoved then
			exp:Hide()
		end
		if rep and not repMoved then
			rep:Hide()
		end
		return
	end

	if pframe and powerOrb then
		if count == 2 then
			if exp and showExp then
				if not expMoved then
					exp:ClearAllPoints()
					exp:SetPoint("BOTTOMLEFT", pframe, "BOTTOMRIGHT", -10, 14)
					exp:SetPoint("BOTTOMRIGHT", powerOrb, "BOTTOMLEFT", 10, 14)
					exp:SetHeight(9)
				end
				exp:Show()
			elseif exp and not expMoved then
				exp:Hide()
			end

			if rep and showRep then
				if not repMoved then
					rep:ClearAllPoints()
					rep:SetPoint("BOTTOMLEFT", pframe, "BOTTOMRIGHT", -10, 4)
					rep:SetPoint("BOTTOMRIGHT", powerOrb, "BOTTOMLEFT", 10, 4)
					rep:SetHeight(9)
				end
				rep:Show()
			elseif rep and not repMoved then
				rep:Hide()
			end
		elseif count == 1 then
			local activeBar = showExp and exp or rep
			local inactiveBar = showExp and rep or exp
			local isMoved = showExp and expMoved or repMoved

			if inactiveBar and not (showExp and repMoved or expMoved) then
				inactiveBar:Hide()
			end

			if activeBar then
				if not isMoved then
					activeBar:ClearAllPoints()
					activeBar:SetPoint("BOTTOMLEFT", pframe, "BOTTOMRIGHT", -10, 5)
					activeBar:SetPoint("BOTTOMRIGHT", powerOrb, "BOTTOMLEFT", 10, 5)
					activeBar:SetHeight(12)
				end
				activeBar:Show()
			end
		end
	else
		-- Fallback if orbs are not yet spawned
		if exp and showExp then
			if not expMoved then
				exp:ClearAllPoints()
				exp:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, count == 2 and 14 or 12)
				exp:SetSize(365, count == 2 and 10 or 12)
			end
			exp:Show()
		end
		if rep and showRep then
			if not repMoved then
				rep:ClearAllPoints()
				rep:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 2)
				rep:SetSize(365, count == 2 and 10 or 12)
			end
			rep:Show()
		end
	end
end

--create harmony power bar
bars.createHarmonyPowerBar = function(self)
	self.Harmony = {}

	local t
	local bar = CreateFrame("Frame", "Roth_UIHarmonyPower", self)
	bar.maxOrbs = 6
	local w = 64 * (bar.maxOrbs + 2) --create the bar for
	local h = 64
	--bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	bar:SetPoint(
		self.cfg.harmony.pos.a1,
		self.cfg.harmony.pos.af,
		self.cfg.harmony.pos.a2,
		self.cfg.harmony.pos.x,
		self.cfg.harmony.pos.y
	)
	bar:SetWidth(w)
	bar:SetHeight(h)

	--color
	bar.color = self.cfg.harmony.color

	--left edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("LEFT", 0, 0)
	t:SetTexture(mediapath .. "combo_left")
	bar.leftEdge = t

	--right edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("RIGHT", 0, 0)
	t:SetTexture(mediapath .. "combo_right")
	bar.rightEdge = t

	for i = 1, bar.maxOrbs do
		local orb = CreateFrame("Frame", nil, bar)
		self.Harmony[i] = orb

		orb:SetSize(64, 64)
		orb:SetPoint("LEFT", i * 64, 0)

		local orbSizeMultiplier = 0.85

		--bar background
		orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
		orb.barBg:SetSize(64, 64)
		orb.barBg:SetPoint("CENTER")
		orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

		--orb background
		orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
		orb.bg:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.bg:SetPoint("CENTER")
		orb.bg:SetTexture(mediapath .. "combo_orb_bg")

		--orb filling
		orb.fill = orb:CreateTexture(nil, "BACKGROUND", nil, -6)
		orb.fill:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.fill:SetPoint("CENTER")
		orb.fill:SetTexture(mediapath .. "combo_orb_fill1")
		orb.fill:SetVertexColor(self.cfg.harmony.color.r, self.cfg.harmony.color.g, self.cfg.harmony.color.b)
		--orb.fill:SetBlendMode("ADD")

		--orb border
		orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
		orb.border:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.border:SetPoint("CENTER")
		orb.border:SetTexture(mediapath .. "combo_orb_border")

		--orb glow
		orb.glow = orb:CreateTexture(nil, "BACKGROUND", nil, -4)
		orb.glow:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.glow:SetPoint("CENTER")
		orb.glow:SetTexture(mediapath .. "combo_orb_glow")
		orb.glow:SetVertexColor(self.cfg.harmony.color.r, self.cfg.harmony.color.g, self.cfg.harmony.color.b)
		orb.glow:SetBlendMode("BLEND")

		--orb highlight
		orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
		orb.highlight:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.highlight:SetPoint("CENTER")
		orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
	end

	bar:SetScale(self.cfg.harmony.scale)
	func.applyDragFunctionality(bar)
	--combat fading
	if self.cfg.harmony.combat.enable then
		rCombatFrameFader(bar, self.cfg.harmony.combat.fadeIn, self.cfg.harmony.combat.fadeOut) --frame, buttonList, fadeIn, fadeOut
	end

	self.HarmonyPowerBar = bar
end

--create holy power bar
bars.createHolyPowerBar = function(self)
	self.HolyPower = {}

	local t
	local bar = CreateFrame("Frame", "Roth_UIHolyPower", self)
	bar.maxOrbs = 5
	local w = 64 * (bar.maxOrbs + 2) --create the bar for
	local h = 64
	--bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	bar:SetPoint(
		self.cfg.holypower.pos.a1,
		self.cfg.holypower.pos.af,
		self.cfg.holypower.pos.a2,
		self.cfg.holypower.pos.x,
		self.cfg.holypower.pos.y
	)
	bar:SetWidth(w)
	bar:SetHeight(h)

	--color
	bar.color = self.cfg.holypower.color

	--left edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("LEFT", 0, 0)
	t:SetTexture(mediapath .. "combo_left")
	bar.leftEdge = t

	--right edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("RIGHT", 0, 0)
	t:SetTexture(mediapath .. "combo_right")
	bar.rightEdge = t

	for i = 1, bar.maxOrbs do
		local orb = CreateFrame("Frame", nil, bar)
		self.HolyPower[i] = orb

		orb:SetSize(64, 64)
		orb:SetPoint("LEFT", i * 64, 0)

		local orbSizeMultiplier = 0.85

		--bar background
		orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
		orb.barBg:SetSize(64, 64)
		orb.barBg:SetPoint("CENTER")
		orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

		--orb background
		orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
		orb.bg:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.bg:SetPoint("CENTER")
		orb.bg:SetTexture(mediapath .. "combo_orb_bg")

		--orb filling
		orb.fill = orb:CreateTexture(nil, "BACKGROUND", nil, -6)
		orb.fill:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.fill:SetPoint("CENTER")
		orb.fill:SetTexture(mediapath .. "combo_orb_fill1")
		orb.fill:SetVertexColor(self.cfg.holypower.color.r, self.cfg.holypower.color.g, self.cfg.holypower.color.b)
		--orb.fill:SetBlendMode("ADD")

		--orb border
		orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
		orb.border:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.border:SetPoint("CENTER")
		orb.border:SetTexture(mediapath .. "combo_orb_border")

		--orb glow
		orb.glow = orb:CreateTexture(nil, "BACKGROUND", nil, -4)
		orb.glow:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.glow:SetPoint("CENTER")
		orb.glow:SetTexture(mediapath .. "combo_orb_glow")
		orb.glow:SetVertexColor(self.cfg.holypower.color.r, self.cfg.holypower.color.g, self.cfg.holypower.color.b)
		orb.glow:SetBlendMode("BLEND")

		--orb highlight
		orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
		orb.highlight:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.highlight:SetPoint("CENTER")
		orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
	end

	bar:SetScale(self.cfg.holypower.scale)
	func.applyDragFunctionality(bar)
	--combat fading
	if self.cfg.holypower.combat.enable then
		rCombatFrameFader(bar, self.cfg.holypower.combat.fadeIn, self.cfg.holypower.combat.fadeOut) --frame, buttonList, fadeIn, fadeOut
	end

	self.HolyPowerBar = bar
end

--create soulshard power bar
bars.createSoulShardPowerBar = function(self)
	self.SoulShards = {}

	local t
	local bar = CreateFrame("Frame", "Roth_UISoulShardPower", self)
	bar.maxOrbs = 5
	local w = 64 * (bar.maxOrbs + 2) --create the bar for
	local h = 64
	--bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	bar:SetPoint(
		self.cfg.soulshards.pos.a1,
		self.cfg.soulshards.pos.af,
		self.cfg.soulshards.pos.a2,
		self.cfg.soulshards.pos.x,
		self.cfg.soulshards.pos.y
	)
	bar:SetWidth(w)
	bar:SetHeight(h)
	bar:Hide() --hide bar (it will become available if the spec matches)

	--color
	bar.color = self.cfg.soulshards.color

	--left edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("LEFT", 0, 0)
	t:SetTexture(mediapath .. "combo_left")
	bar.leftEdge = t

	--right edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("RIGHT", 64, 0)
	t:SetTexture(mediapath .. "combo_right")
	bar.rightEdge = t

	for i = 1, bar.maxOrbs do
		local orb = CreateFrame("Frame", nil, bar)
		self.SoulShards[i] = orb
		orb:SetSize(64, 64)
		orb:SetPoint("LEFT", i * 64, 0)

		local orbSizeMultiplier = 0.95

		--bar background
		orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
		orb.barBg:SetSize(64, 64)
		orb.barBg:SetPoint("CENTER")
		orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

		--orb background
		orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
		orb.bg:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.bg:SetPoint("CENTER")
		orb.bg:SetTexture(mediapath .. "combo_gem_bg")

		--orb filling
		orb.fill = orb:CreateTexture(nil, "BACKGROUND", nil, -6)
		orb.fill:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.fill:SetPoint("CENTER")
		orb.fill:SetTexture(mediapath .. "combo_gem_fill1")
		orb.fill:SetVertexColor(self.cfg.soulshards.color.r, self.cfg.soulshards.color.g, self.cfg.soulshards.color.b)
		--orb.fill:SetBlendMode("ADD")

		--orb border
		orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
		orb.border:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.border:SetPoint("CENTER")
		orb.border:SetTexture(mediapath .. "combo_gem_border")

		--orb glow
		orb.glow = orb:CreateTexture(nil, "BACKGROUND", nil, -4)
		orb.glow:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.glow:SetPoint("CENTER")
		orb.glow:SetTexture(mediapath .. "combo_gem_glow")
		orb.glow:SetVertexColor(self.cfg.soulshards.color.r, self.cfg.soulshards.color.g, self.cfg.soulshards.color.b)
		orb.glow:SetBlendMode("BLEND")

		--orb highlight
		orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
		orb.highlight:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.highlight:SetPoint("CENTER")
		orb.highlight:SetTexture(mediapath .. "combo_gem_highlight")
	end

	bar:SetScale(self.cfg.soulshards.scale)
	func.applyDragFunctionality(bar)
	--combat fading
	if self.cfg.soulshards.combat.enable then
		rCombatFrameFader(bar, self.cfg.soulshards.combat.fadeIn, self.cfg.soulshards.combat.fadeOut) --frame, buttonList, fadeIn, fadeOut
	end

	self.SoulShardPowerBar = bar
end

--create rune orbs bar
bars.createRuneBar = function(self)
	self.RuneOrbs = {}

	local t
	local bar = CreateFrame("Frame", "Roth_UIRuneBar", self)
	bar.maxOrbs = 6
	local w = 64 * (bar.maxOrbs + 2) --create the bar for
	local h = 64
	bar:SetPoint(
		self.cfg.runes.pos.a1,
		self.cfg.runes.pos.af,
		self.cfg.runes.pos.a2,
		self.cfg.runes.pos.x,
		self.cfg.runes.pos.y
	)
	bar:SetWidth(w)
	bar:SetHeight(h)
	bar:Hide() --hide bar (it will become available if the spec matches)

	--left edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("LEFT", 0, 0)
	t:SetTexture(mediapath .. "combo_left")
	bar.leftEdge = t

	--right edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("RIGHT", 0, 0)
	t:SetTexture(mediapath .. "combo_right")
	bar.rightEdge = t

	for i = 1, bar.maxOrbs do
		local orb = CreateFrame("Frame", nil, bar)
		self.RuneOrbs[i] = orb
		orb:SetSize(64, 64)
		orb:SetPoint("LEFT", i * 64, 0)

		local orbSizeMultiplier = 0.85

		--bar background
		orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
		orb.barBg:SetSize(64, 64)
		orb.barBg:SetPoint("CENTER")
		orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

		--orb background
		orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
		orb.bg:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.bg:SetPoint("CENTER")
		orb.bg:SetTexture(mediapath .. "combo_orb_bg")

		--orb filling
		orb.fill = CreateFrame("StatusBar", nil, orb)
		orb.fill:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
		orb.fill:SetPoint("CENTER")
		local fill = orb.fill:CreateTexture(nil, "BACKGROUND", nil, -6)
		fill:SetTexture(mediapath .. "combo_orb_fill64_1")
		orb.fill:SetStatusBarTexture(fill)
		orb.fill:SetOrientation("VERTICAL")

		--stack another frame to correct the texture stacking
		local helper = CreateFrame("Frame", nil, orb.fill)
		helper:SetAllPoints(orb)

		--orb border
		orb.border = helper:CreateTexture(nil, "BACKGROUND", nil, -5)
		orb.border:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.border:SetPoint("CENTER")
		orb.border:SetTexture(mediapath .. "combo_orb_border")

		--orb glow
		orb.glow = helper:CreateTexture(nil, "BACKGROUND", nil, -4)
		orb.glow:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.glow:SetPoint("CENTER")
		orb.glow:SetTexture(mediapath .. "combo_orb_glow")
		orb.glow:SetBlendMode("BLEND")
		orb.glow:Hide()

		--orb highlight
		orb.highlight = helper:CreateTexture(nil, "BACKGROUND", nil, -3)
		orb.highlight:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.highlight:SetPoint("CENTER")
		orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
	end

	bar:SetScale(self.cfg.runes.scale)
	func.applyDragFunctionality(bar)
	--combat fading
	if self.cfg.runes.combat.enable then
		rCombatFrameFader(bar, self.cfg.runes.combat.fadeIn, self.cfg.runes.combat.fadeOut) --frame, buttonList, fadeIn, fadeOut
	end
	self.RuneBar = bar
end

--create combo
bars.createComboBar = function(self)
	self.ComboPoints = {}
	local class = (ns.Secrets and ns.Secrets.String(select(2, UnitClass("player")))) or select(2, UnitClass("player"))
	local t
	local max
	local bar = CreateFrame("Frame", "Roth_UIComboPoints", self)
	local maxPoints = MAX_COMBO_POINTS or 5
	local w = 64 * (maxPoints + 2)
	local h = 64
	-- TBC Anniversary: GetTalentInfo uses (tabIndex, talentIndex) not MoP-style
	-- (tab,row,col). Use pcall + fallback to MAX_COMBO_POINTS.
	local has6cp = false
	if class == "ROGUE" and GetTalentInfo then
		pcall(function()
			local _, _, _, _, rank = GetTalentInfo(3, 9) -- Assassination tab, Seal Fate (TBC)
			if rank and rank > 0 then
				has6cp = true
			end
		end)
	end
	if has6cp then
		max = 6
	else
		max = maxPoints
	end
	--bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	bar:SetPoint(
		self.cfg.combobar.pos.a1,
		self.cfg.combobar.pos.af,
		self.cfg.combobar.pos.a2,
		self.cfg.combobar.pos.x,
		self.cfg.combobar.pos.y
	)
	bar:SetWidth(w)
	bar:SetHeight(h)
	bar:SetScale(self.cfg.combobar.scale)

	--color
	bar.color = self.cfg.combobar.color

	--left edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("LEFT", 0, 0)
	t:SetTexture(mediapath .. "combo_left")
	bar.leftEdge = t

	--right edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("RIGHT", 0, 0)
	t:SetTexture(mediapath .. "combo_right")
	bar.rightEdge = t

	for i = 1, max do
		local orb = CreateFrame("Frame", nil, bar)
		self.ComboPoints[i] = orb

		orb:SetSize(64, 64)
		orb:SetPoint("LEFT", i * 64, 0)

		local orbSizeMultiplier = 0.85

		--bar background
		orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
		orb.barBg:SetSize(64, 64)
		orb.barBg:SetPoint("CENTER")
		orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

		--orb background
		orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
		orb.bg:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.bg:SetPoint("CENTER")
		orb.bg:SetTexture(mediapath .. "combo_orb_bg")

		--orb filling
		orb.fill = orb:CreateTexture(nil, "BACKGROUND", nil, -6)
		orb.fill:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.fill:SetPoint("CENTER")
		orb.fill:SetTexture(mediapath .. "combo_orb_fill1")
		orb.fill:SetVertexColor(self.cfg.combobar.color.r, self.cfg.combobar.color.g, self.cfg.combobar.color.b)
		--orb.fill:SetBlendMode("ADD")

		--orb border
		orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
		orb.border:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.border:SetPoint("CENTER")
		orb.border:SetTexture(mediapath .. "combo_orb_border")

		--orb glow
		orb.glow = orb:CreateTexture(nil, "BACKGROUND", nil, -4)
		orb.glow:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.glow:SetPoint("CENTER")
		orb.glow:SetTexture(mediapath .. "combo_orb_glow")
		orb.glow:SetVertexColor(self.cfg.combobar.color.r, self.cfg.combobar.color.g, self.cfg.combobar.color.b)
		orb.glow:SetBlendMode("BLEND")

		--orb highlight
		orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
		orb.highlight:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.highlight:SetPoint("CENTER")
		orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
	end

	func.applyDragFunctionality(bar)
	--combat fading
	if self.cfg.combobar.combat.enable then
		rCombatFrameFader(bar, self.cfg.combobar.combat.fadeIn, self.cfg.combobar.combat.fadeOut) --frame, buttonList, fadeIn, fadeOut
	end
	self.ComboBar = bar
end

--Arcane Charges
bars.createArcBar = function(self)
	self.ACharges = {}

	local t
	local bar = CreateFrame("Frame", "Roth_UIArcanePower", self)
	bar.maxOrbs = 4
	local w = 64 * (bar.maxOrbs + 2) --create the bar for
	local h = 64
	--bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	bar:SetPoint(
		self.cfg.arcbar.pos.a1,
		self.cfg.arcbar.pos.af,
		self.cfg.arcbar.pos.a2,
		self.cfg.arcbar.pos.x,
		self.cfg.arcbar.pos.y
	)
	bar:SetWidth(w)
	bar:SetHeight(h)
	bar:Hide() --hide bar (it will become available if the spec matches)

	--color
	bar.color = self.cfg.arcbar.color

	--left edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("LEFT", 0, 0)
	t:SetTexture(mediapath .. "combo_left")
	bar.leftEdge = t

	--right edge
	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("RIGHT", 65, 0)
	t:SetTexture(mediapath .. "combo_right")
	bar.rightEdge = t

	for i = 1, bar.maxOrbs do
		local orb = CreateFrame("Frame", nil, bar)
		self.ACharges[i] = orb

		orb:SetSize(64, 64)
		orb:SetPoint("LEFT", i * 64, 0)

		local orbSizeMultiplier = 0.95

		--bar background
		orb.barBg = orb:CreateTexture(nil, "BACKGROUND", nil, -8)
		orb.barBg:SetSize(64, 64)
		orb.barBg:SetPoint("CENTER")
		orb.barBg:SetTexture(mediapath .. "combo_bar_bg")

		--orb background
		orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -7)
		orb.bg:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.bg:SetPoint("CENTER")
		orb.bg:SetTexture(mediapath .. "combo_orb_bg")

		--orb filling
		orb.fill = orb:CreateTexture(nil, "BACKGROUND", nil, -6)
		orb.fill:SetSize(64 * orbSizeMultiplier, 64 * orbSizeMultiplier)
		orb.fill:SetPoint("CENTER")
		orb.fill:SetTexture([[Interface\PLAYERFRAME\MageArcaneCharges]])
		orb.fill:SetTexCoord(0.25, 0.375, 0.5, 0.75)
		--orb.fill:SetBlendMode("ADD")

		--orb border
		orb.border = orb:CreateTexture(nil, "BACKGROUND", nil, -5)
		orb.border:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.border:SetPoint("CENTER")
		orb.border:SetTexture(mediapath .. "combo_orb_border")

		--orb highlight
		orb.highlight = orb:CreateTexture(nil, "BACKGROUND", nil, -3)
		orb.highlight:SetSize(128 * orbSizeMultiplier, 128 * orbSizeMultiplier)
		orb.highlight:SetPoint("CENTER")
		orb.highlight:SetTexture(mediapath .. "combo_orb_highlight")
	end

	bar:SetScale(self.cfg.arcbar.scale)
	func.applyDragFunctionality(bar)
	--combat fading
	if self.cfg.arcbar.combat.enable then
		rCombatFrameFader(bar, self.cfg.arcbar.combat.fadeIn, self.cfg.arcbar.combat.fadeOut) --frame, buttonList, fadeIn, fadeOut
	end

	self.ArcBar = bar
end
