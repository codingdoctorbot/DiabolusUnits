--get the addon namespace
local addon, ns = ...

--get oUF namespace (just in case needed)
local oUF = ns.oUF or oUF
local Secrets = ns.Secrets
local LSM = LibStub("LibSharedMedia-3.0")

--get the config
local cfg = ns.cfg
local mediapath = "Interface\\AddOns\\DiabolusUnits\\media\\"

--object container
local func = CreateFrame("Frame")
ns.func = func

---------------------------------------------
-- GLOBAL PROTECTION STATE
-- Prevents addon callbacks from running during protected states
-- (game menu, logout, combat) to avoid ADDON_ACTION_FORBIDDEN errors
---------------------------------------------
ns.isProtected = false
ns.isLoggingOut = false
ns.isGameMenuOpen = false

-- Use shared protection state tracker (Roth_UI_Protection global from rLib)
Roth_UI_Protection = Roth_UI_Protection or {}

function ns.IsProtected()
	return Roth_UI_Protection.isLoggingOut or Roth_UI_Protection.isGameMenuOpen or InCombatLockdown()
end

-- Global safe callback wrapper
function ns.SafeCallback(func)
	return function()
		if ns.IsProtected() then
			return
		end
		pcall(func)
	end
end

---------------------------------------------
-- SAFE TIMER WRAPPER
-- Single-frame scheduler to avoid creating a new frame per timer call
---------------------------------------------
local timerQueue = {}
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function(self, delta)
	if #timerQueue == 0 then
		return
	end
	local i = 1
	while i <= #timerQueue do
		local entry = timerQueue[i]
		entry.elapsed = entry.elapsed + delta
		if entry.elapsed >= entry.delay then
			table.remove(timerQueue, i)
			if not ns.IsProtected() then
				pcall(entry.callback)
			end
		else
			i = i + 1
		end
	end
end)

ns.SafeTimer = function(delay, callback)
	timerQueue[#timerQueue + 1] = { delay = delay, callback = callback, elapsed = 0 }
end

---------------------------------------------
-- VARIABLES
---------------------------------------------

local tinsert, tremove, floor, mod, format = tinsert, tremove, floor, mod, format

---------------------------------------------
-- FUNCTIONS
---------------------------------------------

--number format func (secret-safe)
func.numFormat = function(v)
	if type(v) == "nil" then
		return "0"
	end
	if Secrets.IsSecret(v) then
		return Secrets.Abbreviate(v)
	end
	if type(v) ~= "number" then
		local n = tonumber(v)
		if not n then
			return tostring(v)
		end
		v = n
	end
	if v > 1E10 then
		return (floor(v / 1E9)) .. "b"
	elseif v > 1E9 then
		return (floor((v / 1E9) * 10) / 10) .. "b"
	elseif v > 1E7 then
		return (floor(v / 1E6)) .. "m"
	elseif v > 1E6 then
		return (floor((v / 1E6) * 10) / 10) .. "m"
	elseif v > 1E4 then
		return (floor(v / 1E3)) .. "k"
	elseif v > 1E3 then
		return (floor((v / 1E3) * 10) / 10) .. "k"
	else
		return floor(v + 0.5) -- no long decimals from fractional values
	end
end

--round number
func.round = function(val)
	local n = Secrets.Number(val)
	if not n then
		return 0
	end
	return floor(n * 1000) / 1000
end

--format time func
func.GetFormattedTime = function(time)
	local t = Secrets.Number(time)
	if not t then
		return ""
	end
	local hr, m, s, text
	if t <= 0 then
		text = ""
	elseif t < 3600 and t > 60 then
		hr = floor(t / 3600)
		m = floor(mod(t, 3600) / 60 + 1)
		text = format("%dm", m)
	elseif t < 60 then
		m = floor(t / 60)
		s = mod(t, 60)
		text = (m == 0 and format("%ds", s))
	else
		hr = floor(t / 3600 + 1)
		text = format("%dh", hr)
	end
	return text
end

--backdrop func
func.createBackdrop = function(f)
	if f.SetBackdrop then
		f:SetBackdrop(cfg.backdrop)
		f:SetBackdropColor(0, 0, 0, 0.7)
		f:SetBackdropBorderColor(0, 0, 0, 1)
	end
end

--create debuff func
func.createDebuffs = function(self)
	if self.cfg.vertical then
		local f = CreateFrame("Frame", nil, self)
		f.size = self.cfg.auras.size
		if self.cfg.style == "targettarget" then
			f.num = 8
		else
			f.num = cfg.units.party.auras.number
		end
		f:SetHeight((f.size + 5) * (f.num / 4))
		f:SetWidth((f.size + 5) * 4)
		if self.cfg.style == "targettarget" then
			f:SetPoint("BOTTOM", self, "RIGHT", 0, 0)
		else
			f:SetPoint("TOP", self, "RIGHT", 50, -5)
		end
		f.initialAnchor = "TOPLEFT"
		f["growth-x"] = "RIGHT"
		f["growth-y"] = "DOWN"
		f.spacing = 5
		f.showDebuffType = self.cfg.auras.showDebuffType
		f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerDebuffs
		f.filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY"
		self.Debuffs = f
	else
		local f = CreateFrame("Frame", nil, self)
		f.size = self.cfg.auras.size
		if self.cfg.style == "targettarget" then
			f.num = 8
		else
			f.num = cfg.units.party.auras.number
		end
		f:SetHeight((f.size + 5) * (f.num / 9))
		f:SetWidth((f.size + 5) * 4)
		if self.cfg.style == "targettarget" then
			f:SetPoint("BOTTOM", self, "RIGHT", -90, -40)
		else
			f:SetPoint("TOP", self, "RIGHT", -60, -67)
		end
		f.initialAnchor = "TOPLEFT"
		f["growth-x"] = "RIGHT"
		f["growth-y"] = "DOWN"
		f.spacing = 5
		f.showDebuffType = self.cfg.auras.showDebuffType
		f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerDebuffs
		f.filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY"
		self.Debuffs = f
	end
end

--create buff func
func.createBuffs = function(self)
	if self.cfg.auras.hideBuffs == true then
		return
	end
	if self.cfg.vertical == false then
		local f = CreateFrame("Frame", nil, self)
		f.size = self.cfg.auras.size
		if self.cfg.style == "targettarget" then
			f.num = 8
		else
			f.num = cfg.units.party.auras.number
		end
		f:SetHeight((f.size + 5) * (f.num / 9))
		f:SetWidth((f.size + 5) * 4)
		f:SetPoint("TOP", self, "RIGHT", -60, -27)
		f.initialAnchor = "TOPLEFT"
		f["growth-x"] = "RIGHT"
		f["growth-y"] = "DOWN"
		f.spacing = 5
		f.showBuffType = self.cfg.auras.showBuffType
		f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerBuffs
		f.filter = "HELPFUL"
		self.Buffs = f
	else
		local f = CreateFrame("Frame", nil, self)
		f.size = self.cfg.auras.size
		if self.cfg.style == "targettarget" then
			f.num = 8
		else
			f.num = cfg.units.party.auras.number
		end
		f:SetHeight((f.size + 5) * (f.num / 9))
		f:SetWidth((f.size + 5) * 9)
		f:SetPoint("TOP", self, "RIGHT", 117.5, 30)
		f.initialAnchor = "TOPLEFT"
		f["growth-x"] = "RIGHT"
		f["growth-y"] = "UP"
		f.spacing = 5
		f.showBuffType = self.cfg.auras.showBuffType
		f.onlyShowPlayer = self.cfg.auras.onlyShowPlayerBuffs
		f.filter = "HELPFUL"
		self.Buffs = f
	end
end

--Desaturated and Button CD
func.postUpdateDebuff = function(element, unit, button, index, duration, expirationTime)
	if Secrets.Bool(UnitIsFriend, "player", unit) or button.isPlayer then
		button.icon:SetDesaturated(false)
	else
		button.icon:SetDesaturated(true)
	end
	button.icon.duration = Secrets.Number(duration)
	button.icon.timeLeft = Secrets.Number(expirationTime)
	button.icon.first = true
end

--aura icon func
func.createAuraIcon = function(icons, button)
	local size = icons.size or button:GetWidth()
	button.cd:SetFrameStrata("MEDIUM")
	button.cd:SetPoint("TOPLEFT", 1, -1)
	button.cd:SetPoint("BOTTOMRIGHT", -1, 1)
	button.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

	if button.cd.SetHideCountdownNumbers then
		button.cd:SetHideCountdownNumbers(true)
	end

	button.countFrame = CreateFrame("Frame", nil, button)
	button.countFrame:SetAllPoints()
	button.countFrame:SetFrameStrata("MEDIUM")
	button.countFrame:SetFrameLevel(button.cd:GetFrameLevel() + 2)
	button.count:SetParent(button.countFrame)
	button.count:ClearAllPoints()
	button.count:SetPoint("TOPRIGHT", 4, 4)
	button.count:SetTextColor(0.9, 0.9, 0.9)
	button.count:SetFont(cfg.font, size / 1.8, "THINOUTLINE")

	if not button.timer then
		button.timer = button:CreateFontString(nil, "OVERLAY")
		button.timer:SetParent(button.countFrame)
		button.timer:SetPoint("CENTER", button, "CENTER", 0, 0)
		button.timer:SetJustifyH("CENTER")
		button.timer:SetJustifyV("MIDDLE")
	end
	local timerFontSize = math.max(8, math.min(size * 0.35, 18))
	button.timer:SetFont(cfg.font, timerFontSize, "OUTLINE")
	button.timer:SetTextColor(1, 1, 1, 1)
	button.timer:SetText("")

	-- Single SetCooldown hook: hides default text and drives custom timer when plain numbers;
	-- falls back to C++ countdown numbers when duration is secret.
	if button.cd.SetCooldown then
		local originalSetCooldown = button.cd.SetCooldown
		button.cd.SetCooldown = function(self, start, duration)
			originalSetCooldown(self, start, duration)

			if button.cd._timerActive then
				button.cd:SetScript("OnUpdate", nil)
				button.cd._timerActive = nil
			end

			local s, d = Secrets.Number(start), Secrets.Number(duration)
			if s and d and d > 0 and s > 0 and button.timer then
				if self.SetHideCountdownNumbers then
					self:SetHideCountdownNumbers(true)
				end
				local accumulator = 0
				button.cd._timerActive = true
				button.cd:SetScript("OnUpdate", function(cdSelf, elapsed)
					accumulator = accumulator + elapsed
					if accumulator >= 0.1 then
						accumulator = 0
						local remaining = (s + d) - GetTime()
						if remaining > 0 then
							if remaining >= 3600 then
								button.timer:SetText(
									string.format(
										"%dh%dm",
										math.floor(remaining / 3600),
										math.floor((remaining % 3600) / 60)
									)
								)
							elseif remaining >= 60 then
								button.timer:SetText(string.format("%dm", math.floor(remaining / 60)))
							else
								button.timer:SetText(string.format("%d", math.floor(remaining)))
							end
						else
							button.timer:SetText("")
							cdSelf:SetScript("OnUpdate", nil)
							button.cd._timerActive = nil
						end
					end
				end)
			else
				if button.timer then
					button.timer:SetText("")
				end
				if self.SetHideCountdownNumbers and (Secrets.IsSecret(start) or Secrets.IsSecret(duration)) then
					self:SetHideCountdownNumbers(false)
				end
			end
		end
	end

	if button.cd.SetCooldownFromDurationObject then
		local origSetFromDur = button.cd.SetCooldownFromDurationObject
		button.cd.SetCooldownFromDurationObject = function(self, durObj, clearIfZero)
			if button.cd._timerActive then
				button.cd:SetScript("OnUpdate", nil)
				button.cd._timerActive = nil
			end
			if button.timer then
				button.timer:SetText("")
			end
			if self.SetHideCountdownNumbers then
				self:SetHideCountdownNumbers(false)
			end
			return origSetFromDur(self, durObj, clearIfZero)
		end
	end

	button.overlay:SetTexture(mediapath .. "gloss2")
	button.overlay:SetTexCoord(0, 1, 0, 1)
	button.overlay:SetPoint("TOPLEFT", -1, 1)
	button.overlay:SetPoint("BOTTOMRIGHT", 1, -1)
	button.overlay:SetVertexColor(0.4, 0.35, 0.35, 1)
	button.overlay:Show()
	button.overlay.Hide = function() end
	local back = button:CreateTexture(nil, "BACKGROUND")
	back:SetPoint("TOPLEFT", button.icon, "TOPLEFT", -0.18 * size, 0.18 * size)
	back:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 0.18 * size, -0.18 * size)
	back:SetTexture(mediapath .. "simplesquare_glow")
	back:SetVertexColor(0, 0, 0, 1)
end

--create AltPowerBar
func.createAltPowerBar = function(self, name)
	local t, f
	local num = 4
	local w = 64 * num
	local h = 22

	local bar = CreateFrame("StatusBar", name, self)
	bar:SetPoint(
		self.cfg.altpower.pos.a1,
		self.cfg.altpower.pos.af,
		self.cfg.altpower.pos.a2,
		self.cfg.altpower.pos.x,
		self.cfg.altpower.pos.y
	)
	bar:SetSize(w, h)
	bar:SetStatusBarTexture(self.cfg.altpower.texture)
	bar:SetStatusBarColor(self.cfg.altpower.color.r, self.cfg.altpower.color.g, self.cfg.altpower.color.b)
	bar.colorTexture = true --color the altpower bar
	--bar:SetMinMaxValues(0,100)
	--bar:SetValue(70)

	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("LEFT", -64, 0)
	t:SetTexture(mediapath .. "combo_left")
	bar.leftedge = t

	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64, 64)
	t:SetPoint("RIGHT", 64, 0)
	t:SetTexture(mediapath .. "combo_right")
	bar.rightedge = t

	t = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64 * num, 64)
	t:SetPoint("LEFT", 0, 0)
	t:SetTexture(mediapath .. "combo_back")
	bar.back = t

	local g = CreateFrame("Frame", nil, bar)
	g:SetAllPoints(bar)

	t = g:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetSize(64 * num, 64)
	t:SetPoint("LEFT", 0, 0)
	t:SetAlpha(0.7)
	t:SetBlendMode("BLEND")
	t:SetTexture(mediapath .. "combo_highlight2")

	f = func.createFontString(g, cfg.font, 24, "THINOUTLINE")
	f:SetPoint("CENTER", 0, 0)
	f:SetTextColor(0.8, 0.8, 0.8)
	self:Tag(f, "[diablo:altpower]")

	bar:SetScale(self.cfg.altpower.scale)
	func.simpleDragFunc(bar)
	self.AltPowerBar = bar
end

--create aura watch func
func.createAuraWatch = function(self)
	local auras = {}
	-- WoW Forever spells (Classic data: one spell ID per rank), from Grid2's
	-- GridPlayerSpellsForever.lua. Each entry is one icon; all its ranks light it.
	local spellIDs
	if cfg.playerclass == "PRIEST" then
		spellIDs = {
			{ 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, 27606 }, -- Renew
			{ 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 22187, 27607 }, -- Power Word: Shield
			{ 6346 }, -- Fear Ward
			{ 10060 }, -- Power Infusion
		}
	elseif cfg.playerclass == "PALADIN" then
		spellIDs = {
			{ 1022, 5599, 10278 }, -- Blessing of Protection
			{ 1044 }, -- Blessing of Freedom
			{ 6940, 20729 }, -- Blessing of Sacrifice
		}
	elseif cfg.playerclass == "DRUID" then
		spellIDs = {
			{ 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 }, -- Rejuvenation
			{ 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 }, -- Regrowth
			{ 29166 }, -- Innervate
		}
	elseif cfg.playerclass == "SHAMAN" then
		spellIDs = {
			{ 16177, 16236, 16237 }, -- Ancestral Fortitude
			{ 29203 }, -- Healing Way
		}
	else
		spellIDs = {}
	end

	auras.onlyShowPresent = false
	auras.presentAlpha = 1
	auras.PostCreateIcon = func.createAuraIcon

	-- Set any other AuraWatch settings
	auras.icons = {}
	do -- (was gated on the party layout's setting, so no icon was ever made)
		local columns = 2
		local xGrowth = 19
		local yGrowth = -20
		local parentAnchorPoint = "TOPRIGHT"
		local iconAnchorPoint = "TOPRIGHT"
		for i, ranks in ipairs(spellIDs) do
			local sid = ranks[1]
			local icon = CreateFrame("Frame", nil, self)
			icon:SetFrameStrata("BACKGROUND")
			icon.spellID = sid
			icon.spellIDs = ranks
			-- set the dimensions and positions
			icon:SetSize(self.cfg.auras.size, self.cfg.auras.size)
			auras.icons[sid] = icon
			local xOffset = (i % columns) * xGrowth
			local yOffset = math.floor(i / columns) * yGrowth + 60
			icon:SetPoint(iconAnchorPoint, self, parentAnchorPoint, xOffset, yOffset)
			-- Set any other AuraWatch icon settings
			local cd = CreateFrame("Cooldown", nil, icon)
			cd:SetFrameStrata("TOOLTIP")
			cd:SetAllPoints(icon)
			icon.cd = cd
		end
	end
	auras.PostCreateIcon = func.createAuraIcon

	--call aurawatch
	self.AuraWatch = auras
end

-- Pre-allocated color tables to avoid per-update garbage
local COLOR_TAPPED = { r = 0.65, g = 0.65, b = 0.65 }
local COLOR_DEAD = { r = 0.4, g = 0.4, b = 0.4 }
local COLOR_OFFLINE = { r = 0.4, g = 0.4, b = 0.4 }
local COLOR_FALLBACK = { r = 0.5, g = 0.5, b = 0.5 }
local COLOR_POWER_FALLBACK = { r = 1, g = 0.5, b = 0.25 }
local COLOR_CLASS_TMP = { r = 1, g = 1, b = 1 }

func.updateHealth = function(bar, unit, min, max)
	if bar.__owner and bar.__owner.RothHealBars then
		ns.HealBars.Update(bar.__owner)
	end
	local minNum, maxNum = Secrets.Number(min), Secrets.Number(max)
	local d = (minNum and maxNum and maxNum > 0) and floor(minNum / maxNum * 100) or nil
	local color
	local dead
	local offline

	if unit and Secrets.Bool(UnitIsTapDenied, unit) then
		color = COLOR_TAPPED
	elseif Secrets.Bool(UnitIsDeadOrGhost, unit) then
		color = COLOR_DEAD
		dead = 1
	elseif not Secrets.Bool(UnitIsConnected, unit) then
		color = COLOR_OFFLINE
		offline = 1
	elseif not cfg.colorswitcher.classcolored then
		color = cfg.colorswitcher.bright
	elseif Secrets.Bool(UnitIsPlayer, unit) then
		local r, g, b = Secrets.UnitClassColor(unit)
		if r and g and b then
			COLOR_CLASS_TMP.r, COLOR_CLASS_TMP.g, COLOR_CLASS_TMP.b = r, g, b
			color = COLOR_CLASS_TMP
		end
	else
		local reaction = Secrets.Number(UnitReaction(unit, "player"))
		color = reaction and FACTION_BAR_COLORS[reaction]
	end
	if not color then
		color = COLOR_FALLBACK
	end
	--dead
	if offline == 1 then
		bar:SetStatusBarColor(0.4, 0.4, 0.4, 0.4)
		bar.glow:SetVertexColor(0, 0, 0, 0)
	else
		--alive
		if cfg.colorswitcher.useBrightForeground then
			bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
			bar.bg:SetVertexColor(
				cfg.colorswitcher.dark.r,
				cfg.colorswitcher.dark.g,
				cfg.colorswitcher.dark.b,
				cfg.colorswitcher.dark.a
			)
		else
			bar:SetStatusBarColor(
				cfg.colorswitcher.dark.r,
				cfg.colorswitcher.dark.g,
				cfg.colorswitcher.dark.b,
				cfg.colorswitcher.dark.a
			)
			bar.bg:SetVertexColor(color.r, color.g, color.b, color.a or 1)
		end
	end
	--low hp
	if (d and d <= 25) or dead == 1 then
		bar.highlight:SetAlpha(0)
		if cfg.colorswitcher.useBrightForeground then
			bar.glow:SetVertexColor(1, 0, 0, 0.6)
			bar:SetStatusBarColor(1, 0, 0, 1)
			bar.bg:SetVertexColor(0.2, 0, 0, 0.9)
		else
			bar.glow:SetVertexColor(1, 0, 0, 1)
		end
	else
		--inner shadow
		bar.glow:SetVertexColor(0, 0, 0, 0.7)
		bar.highlight:SetAlpha(cfg.highlightMultiplier)
	end
	-- Secret health (combat): the <= 25 % test above cannot run, so a red
	-- inner glow takes its alpha from a step curve instead (1 below 25 %).
	if not d and not dead and bar.glow and Secrets.LowHealthCurve and UnitHealthPercent then
		if not bar.lowhpSecret then
			bar.lowhpSecret = bar:CreateTexture(nil, "OVERLAY", nil, -3)
			bar.lowhpSecret:SetTexture(bar.glow:GetTexture())
			bar.lowhpSecret:SetAllPoints(bar.glow)
			bar.lowhpSecret:SetVertexColor(1, 0, 0, 1)
			bar.lowhpSecret:SetBlendMode("ADD")
		end
		local curve = Secrets.LowHealthCurve()
		local ok, alpha = pcall(UnitHealthPercent, unit, true, curve)
		if curve and ok and alpha then -- truthiness only: alpha may be secret
			bar.lowhpSecret:SetAlpha(alpha)
			bar.lowhpSecret:Show()
		else
			bar.lowhpSecret:Hide()
		end
	elseif bar.lowhpSecret then
		bar.lowhpSecret:Hide()
	end
end

--update power func
func.updatePower = function(bar, unit, min, max)
	local powerToken = Secrets.String(select(2, UnitPowerType(unit)))
	local color = powerToken and cfg.powercolors[powerToken]
	if not color then
		color = COLOR_POWER_FALLBACK
	end
	bar:SetStatusBarColor(color.r, color.g, color.b, 1)
	bar.bg:SetVertexColor(color.r, color.g, color.b, 0.2)
end

--debuffglow
func.createDebuffGlow = function(self)
	local t = self:CreateTexture(nil, "BACKGROUND", nil, -5)
	if self.cfg.style == "target" then
		t:SetTexture(mediapath .. "target_debuffglow")
	else
		t:SetTexture(mediapath .. "targettarget_debuffglow")
	end
	if self.cfg.style == "party" then
		if cfg.units.party.vertical == true then
			t:SetPoint("TOP", 0, 29)
			t:SetPoint("LEFT", 0, 0)
			t:SetPoint("RIGHT", 0, 0)
			t:SetPoint("BOTTOM", 0, -10)
		else
			t:SetPoint("TOP", 0, 19)
			t:SetPoint("LEFT", 0, 0)
			t:SetPoint("RIGHT", 0, 0)
			t:SetPoint("BOTTOM", 0, -15)
		end
	elseif self.cfg.style == "target" then
		t:SetPoint("TOP", 0, 25)
		t:SetPoint("LEFT", -60, 0)
		t:SetPoint("RIGHT", 60, 0)
		t:SetPoint("BOTTOM", 0, -15)
	else
		t:SetAllPoints()
	end
	t:SetBlendMode("BLEND")
	t:SetVertexColor(0, 1, 1, 0) -- set alpha to 0 to hide the texture
	self.DebuffHighlight = t
	self.DebuffHighlightAlpha = 1
	self.DebuffHighlightFilter = false
end

--check threat
func.checkThreat = function(self, event, unit)
	if unit then
		if self.unit ~= unit then
			return
		end
		local threat = Secrets.Number(UnitThreatSituation(unit))
		if threat and threat > 0 then
			local r, g, b = GetThreatStatusColor(threat)
			if self.Border then
				self.Border:SetVertexColor(r, g, b)
				self.PortraitBack:SetVertexColor(r, g, b, 1)
			end
		else
			if self.Border then
				self.Border:SetVertexColor(0.6, 0.5, 0.5)
				self.PortraitBack:SetVertexColor(0.1, 0.1, 0.1, 0.9)
			end
		end
	end
end

--create portrait func
func.createPortrait = function(self)
	local back = CreateFrame("Frame", nil, self)
	back:SetSize(self.cfg.width, self.cfg.width)

	if self.cfg.style == "party" then
		if cfg.units.party.vertical == false then
			back:SetPoint("BOTTOM", self, "TOP", 0, -35)
		else
			back:SetPoint("BOTTOM", self, "LEFT", 10, -38)
		end
	else
		back:SetPoint("BOTTOM", self, "TOP", 0, -35)
	end
	-- cfg.portrait.size shrinks the whole portrait (art, border, offsets) from the
	-- frame-wide default; the anchor offset is in the holder's scale, so it shrinks too
	local size = self.cfg.portrait and self.cfg.portrait.size
	if size and self.cfg.style ~= "party" and size < self.cfg.width then
		back:SetScale(size / self.cfg.width)
	end
	self.PortraitHolder = back

	local t = back:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetAllPoints(back)
	t:SetTexture(mediapath .. "portrait_back")
	t:SetVertexColor(0.1, 0.1, 0.1, 0.9)
	self.PortraitBack = t

	if self.cfg.style == "party" then
		if self.cfg.portrait.use3D then
			self.Portrait = CreateFrame("PlayerModel", nil, back)
			self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 22, -20)
			self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -19, 21)

			local borderholder = CreateFrame("Frame", nil, self.Portrait)
			borderholder:SetAllPoints(back)
			self.BorderHolder = borderholder

			local border = borderholder:CreateTexture(nil, "BACKGROUND", nil, -6)
			border:SetAllPoints(borderholder)
			border:SetTexture(mediapath .. "portrait_border")
			border:SetVertexColor(0.6, 0.5, 0.5)
			--border:SetVertexColor(1,0,0,1) --threat test
			self.Border = border

			local gloss = borderholder:CreateTexture(nil, "BACKGROUND", nil, -5)
			gloss:SetAllPoints(borderholder)
			gloss:SetTexture(mediapath .. "portrait_gloss")
			gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
		else
			self.Portrait = back:CreateTexture(nil, "BACKGROUND", nil, -7)
			self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 21, -21)
			self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -21, 21)
			self.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

			local border = back:CreateTexture(nil, "BACKGROUND", nil, -6)
			border:SetAllPoints(back)
			border:SetTexture(mediapath .. "portrait_border")
			border:SetVertexColor(0.6, 0.5, 0.5)
			self.Border = border

			local gloss = back:CreateTexture(nil, "BACKGROUND", nil, -5)
			gloss:SetAllPoints(back)
			gloss:SetTexture(mediapath .. "portrait_gloss")
			gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
		end
	else
		if self.cfg.portrait.use3D then
			self.Portrait = CreateFrame("PlayerModel", nil, back)
			self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 27, -27)
			self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -27, 27)

			local borderholder = CreateFrame("Frame", nil, self.Portrait)
			borderholder:SetAllPoints(back)
			self.BorderHolder = borderholder

			local border = borderholder:CreateTexture(nil, "BACKGROUND", nil, -6)
			border:SetAllPoints(borderholder)
			border:SetTexture(mediapath .. "portrait_border")
			border:SetVertexColor(0.6, 0.5, 0.5)
			--border:SetVertexColor(1,0,0,1) --threat test
			self.Border = border

			local gloss = borderholder:CreateTexture(nil, "BACKGROUND", nil, -5)
			gloss:SetAllPoints(borderholder)
			gloss:SetTexture(mediapath .. "portrait_gloss")
			gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
		else
			self.Portrait = back:CreateTexture(nil, "BACKGROUND", nil, -7)
			self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", 27, -27)
			self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -27, 27)
			self.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

			local border = back:CreateTexture(nil, "BACKGROUND", nil, -6)
			border:SetAllPoints(back)
			border:SetTexture(mediapath .. "portrait_border")
			border:SetVertexColor(0.6, 0.5, 0.5)
			self.Border = border

			local gloss = back:CreateTexture(nil, "BACKGROUND", nil, -5)
			gloss:SetAllPoints(back)
			gloss:SetTexture(mediapath .. "portrait_gloss")
			gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
		end
	end

	if self.cfg.vertical == true then
		self.Name:SetPoint("CENTER", 0, 0)
	else
		self.Name:SetPoint("BOTTOM", self, "TOP", 0, self.cfg.width - 53)
	end
end

--create standalone portrait func
func.createStandAlonePortrait = function(self)
	local fname
	if self.cfg.style == "player" then
		fname = "Roth_UIPlayerPortrait"
	elseif self.cfg.style == "target" then
		fname = "Roth_UITargetPortrait"
	end

	local pcfg = self.cfg.portrait

	local back = CreateFrame("Frame", fname, self)
	back:SetSize(pcfg.size, pcfg.size)
	back:SetPoint(pcfg.pos.a1, pcfg.pos.af, pcfg.pos.a2, pcfg.pos.x, pcfg.pos.y)

	func.applyDragFunctionality(back)

	local t = back:CreateTexture(nil, "BACKGROUND", nil, -8)
	t:SetAllPoints(back)
	t:SetTexture(mediapath .. "portrait_back")
	t:SetVertexColor(0.1, 0.1, 0.1, 0.9)

	if pcfg.use3D then
		self.Portrait = CreateFrame("PlayerModel", nil, back)
		self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", pcfg.size * 27 / 128, -pcfg.size * 27 / 128)
		self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -pcfg.size * 27 / 128, pcfg.size * 27 / 128)

		local borderholder = CreateFrame("Frame", nil, self.Portrait)
		borderholder:SetAllPoints(back)

		local border = borderholder:CreateTexture(nil, "BACKGROUND", nil, -6)
		border:SetAllPoints(borderholder)
		border:SetTexture(mediapath .. "portrait_border")
		border:SetVertexColor(0.6, 0.5, 0.5)

		local gloss = borderholder:CreateTexture(nil, "BACKGROUND", nil, -5)
		gloss:SetAllPoints(borderholder)
		gloss:SetTexture(mediapath .. "portrait_gloss")
		gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
	else
		self.Portrait = back:CreateTexture(nil, "BACKGROUND", nil, -7)
		self.Portrait:SetPoint("TOPLEFT", back, "TOPLEFT", pcfg.size * 27 / 128, -pcfg.size * 27 / 128)
		self.Portrait:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -pcfg.size * 27 / 128, pcfg.size * 27 / 128)
		self.Portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

		local border = back:CreateTexture(nil, "BACKGROUND", nil, -6)
		border:SetAllPoints(back)
		border:SetTexture(mediapath .. "portrait_border")
		border:SetVertexColor(0.6, 0.5, 0.5)

		local gloss = back:CreateTexture(nil, "BACKGROUND", nil, -5)
		gloss:SetAllPoints(back)
		gloss:SetTexture(mediapath .. "portrait_gloss")
		gloss:SetVertexColor(0.9, 0.95, 1, 0.6)
	end
end

--create castbar func
func.createCastbar = function(f)
	local frame = CreateFrame("Frame", "$parentCastBarDragFrame", f)
	frame:SetPoint(
		f.cfg.castbar.pos.a1,
		f.cfg.castbar.pos.af,
		f.cfg.castbar.pos.a2,
		f.cfg.castbar.pos.x + 8,
		f.cfg.castbar.pos.y
	)
	frame:SetSize(100, 10)
	local c = CreateFrame("StatusBar", "$parentCastbar", frame)
	--wow is this outdated...man I really need to rewrite how the drag stuff is handled
	tinsert(Roth_UI_Bars, frame:GetName())
	c:SetSize(265, 15)
	c:SetStatusBarTexture(f.cfg.castbar.texture)
	c:SetScale(f.cfg.castbar.scale)
	c:SetPoint("CENTER", frame, 0, 0)
	c:SetFrameStrata("HIGH")
	c:SetStatusBarColor(
		f.cfg.castbar.color.bar.r,
		f.cfg.castbar.color.bar.g,
		f.cfg.castbar.color.bar.b,
		f.cfg.castbar.color.bar.a
	)
	--c:SetStatusBarColor(0,0,0,1)

	c.background = c:CreateTexture(nil, "BACKGROUND", nil, -8)
	c.background:SetTexture(mediapath .. "castbar")
	c.background:SetPoint("TOP", 0, 24.9)
	c.background:SetPoint("LEFT", -170, 0)
	c.background:SetPoint("RIGHT", 170, 0)
	c.background:SetPoint("BOTTOM", 0, -24.2)

	c.bg = c:CreateTexture(nil, "BACKGROUND", nil, -6)
	c.bg:SetTexture(f.cfg.castbar.texture)
	c.bg:SetAllPoints(c)
	c.bg:SetVertexColor(
		f.cfg.castbar.color.bg.r,
		f.cfg.castbar.color.bg.g,
		f.cfg.castbar.color.bg.b,
		f.cfg.castbar.color.bg.a
	)

	c.Text = func.createFontString(c, cfg.font, f.cfg.castbar.TextSize, "THINOUTLINE")
	c.Text:SetPoint("LEFT", 5, 0)
	c.Text:SetJustifyH("LEFT")

	c.Time = func.createFontString(c, cfg.font, f.cfg.castbar.TextSize, "THINOUTLINE")
	c.Time:SetPoint("RIGHT", -2, 0)

	c.Text:SetPoint("RIGHT", -50, 0)
	--c.Text:SetPoint("RIGHT", c.Time, "LEFT", -10, 0) --right point of text will anchor left point of time

	c.Spark = c:CreateTexture(nil, "OVERLAY", nil, -7)
	c.Spark:SetBlendMode("ADD")
	c.Spark:SetVertexColor(0.8, 0.6, 0, 1)

	c.glow = c:CreateTexture(nil, "OVERLAY", nil, -4)
	c.glow:SetTexture(mediapath .. "castbar_glow")
	c.glow:SetPoint("TOP", 0, 26.5)
	c.glow:SetPoint("LEFT", -35, 0)
	c.glow:SetPoint("RIGHT", 35, 0)
	c.glow:SetPoint("BOTTOM", 0, -24.2)
	c.glow:SetVertexColor(0, 0, 0, 1)

	c.highlight = c:CreateTexture(nil, "OVERLAY", nil, -3)
	c.highlight:SetTexture(mediapath .. "castbar_highlight")
	c.highlight:SetPoint("TOP", 0, 26.5)
	c.highlight:SetPoint("LEFT", -35, 0)
	c.highlight:SetPoint("RIGHT", 35, 0)
	c.highlight:SetPoint("BOTTOM", 0, -24.2)

	if f.cfg.style == "target" then
		c.Shield = c:CreateTexture(nil, "BACKGROUND", nil, -8)
		c.Shield:SetColorTexture(0, 0, 0, 0)
	end

	--safezone
	if f.cfg.style == "player" and f.cfg.castbar.latency then
		c.SafeZone = c:CreateTexture(nil, "OVERLAY")
		c.SafeZone:SetTexture(f.cfg.castbar.texture)
		c.SafeZone:SetVertexColor(0.6, 0, 0, 0.6)
		c.SafeZone:SetPoint("TOPRIGHT")
		c.SafeZone:SetPoint("BOTTOMRIGHT")
	end

	func.applyDragFunctionality(frame)

	f.Castbar = c
end

local LSM = LibStub("LibSharedMedia-3.0")

--fontstring func
func.createFontString = function(f, font, size, outline, layer)
	local fs = f:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(font, size, outline)
	fs:SetShadowColor(0, 0, 0, 1)
	return fs
end

local function CheckFont()
	if Roth_UI.configDB == nil then
		return false
	elseif LSM:Fetch("font", Roth_UI.configDB.profile.chatFont) == nil then
		return false
	else
		return true
	end
end

--allows frames to become movable but frames can be locked or set to default positions
-- Uses custom drag system (ALT+SHIFT to drag) instead of Blizzard's buggy Edit Mode
func.applyDragFunctionality = function(f, special)
	--save the default position
	local getPoint = function(self)
		local pos = {}
		pos.a1, pos.af, pos.a2, pos.x, pos.y = self:GetPoint()
		if pos.af and pos.af:GetName() then
			pos.af = pos.af:GetName()
		end
		return pos
	end
	if not f.defaultPosition then
		f.defaultPosition = getPoint(f)
	end

	-- Always use custom drag system (we disabled Blizzard's Edit Mode due to bugs)
	--new form of dragframe
	local df = CreateFrame("Frame", nil, f)
	df:SetAllPoints(f)
	df:SetFrameStrata("HIGH")
	--df:SetHitRectInsets(-15,-15,-15,-15)
	df:SetScript("OnDragStart", function(self)
		-- ALT+SHIFT, or nothing at all while the layout is being edited (core/editmode.lua)
		if (IsAltKeyDown() and IsShiftKeyDown()) or (ns.EditMode and ns.EditMode.active) then
			self:GetParent():StartMoving()
		end
	end)
	df:SetScript("OnDragStop", function(self)
		local parent = self:GetParent()
		parent:StopMovingOrSizing()
		if parent.SetUserPlaced then
			parent:SetUserPlaced(false)
		end
		if ns.EditMode and ns.EditMode.SaveFramePosition then
			ns.EditMode:SaveFramePosition(parent)
		end
	end)
	local t = df:CreateTexture(nil, "OVERLAY", nil, 6)
	t:SetAllPoints(df)
	t:SetColorTexture(0, 1, 0)
	t:SetAlpha(0.2)
	df.texture = t
	df:EnableMouseWheel(true)
	df:SetScript("OnMouseDown", function(self)
		if ns.EditMode and ns.EditMode.active and ns.EditMode.SelectFrame then
			ns.EditMode:SelectFrame(self:GetParent())
		end
	end)
	df:SetScript("OnMouseWheel", function(self, delta)
		if ns.EditMode and ns.EditMode.active then
			if IsShiftKeyDown() and ns.EditMode.NudgeSpacing then
				ns.EditMode:NudgeSpacing(delta > 0 and 1 or -1)
			elseif ns.EditMode.NudgeScale then
				ns.EditMode:NudgeScale(self:GetParent(), delta > 0 and 0.05 or -0.05)
			end
		end
	end)
	f.dragframe = df
	f.dragframe:Hide()
	if not special then
		f:SetClampedToScreen(true)
	end
	if not cfg.framesUserplaced then
		f:SetMovable(false)
	else
		f:SetMovable(true)
		f:SetUserPlaced(false)
		if not cfg.framesLocked then
			f.dragframe:Show()
			f.dragframe:EnableMouse(true)
			f.dragframe:RegisterForDrag("LeftButton")
			f.dragframe:SetScript("OnEnter", function(s)
				GameTooltip:SetOwner(s, "ANCHOR_TOP")
				GameTooltip:AddLine(s:GetParent():GetName(), 0, 1, 0.5, 1, 1, 1)
				GameTooltip:AddLine(
					(ns.EditMode and ns.EditMode.active) and "Drag to move" or "Hold down ALT+SHIFT to drag!",
					1,
					1,
					1,
					1,
					1,
					1
				)
				GameTooltip:Show()
			end)
			f.dragframe:SetScript("OnLeave", function(s)
				GameTooltip:Hide()
			end)
		end
	end
	--print(f:GetName())
	--print(f:IsUserPlaced())
end

--simple frame movement
func.simpleDragFunc = function(f)
	f:SetHitRectInsets(-15, -15, -15, -15)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetUserPlaced(false)

	f:EnableMouse(true)

	f:RegisterForDrag("LeftButton")
	--[[
    f:SetScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_CURSOR")
      GameTooltip:AddLine(s:GetName(), 0, 1, 0.5, 1, 1, 1)
      GameTooltip:AddLine("Hold down ALT+SHIFT to drag!", 1, 1, 1, 1, 1, 1)
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(s) GameTooltip:Hide() end)
    ]]
	--
	--f:SetScript("OnDragStart", function(s) if IsAltKeyDown() and IsShiftKeyDown() then s:StartMoving() end end)
	f:SetScript("OnDragStart", function(s)
		s:StartMoving()
	end)
	f:SetScript("OnDragStop", function(s)
		s:StopMovingOrSizing()
		if s.SetUserPlaced then
			s:SetUserPlaced(false)
		end
	end)
end

--create icon func
func.createIcon = function(f, layer, size, anchorframe, anchorpoint1, anchorpoint2, posx, posy, sublevel)
	local icon = f:CreateTexture(nil, layer, nil, sublevel)
	icon:SetSize(size, size)
	icon:SetPoint(anchorpoint1, anchorframe, anchorpoint2, posx, posy)
	return icon
end

-- incoming heals and absorbs: core/healbars.lua (the oUF 1.6 elements
-- these helpers once fed do not exist in the embedded oUF)
func.healPrediction = function(self)
	if ns.HealBars and self.Health then
		ns.HealBars.Attach(self, self.Health)
	end
end
func.totalAbsorb = func.healPrediction

--Register LSM media
LSM:Register("border", "RB border", "Interface\\AddOns\\DiabolusUnits\\media\\5.tga")
LSM:Register("statusbar", "Solid", "Interface\\AddOns\\DiabolusUnits\\media\\Solid.tga")
LSM:Register("statusbar", "Roth_Statusbar1", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar")
LSM:Register("statusbar", "Roth_Statusbar2", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar2")
LSM:Register("statusbar", "Roth_Statusbar3", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar3")
LSM:Register("statusbar", "Roth_Statusbar4", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar4")
LSM:Register("statusbar", "Roth_Statusbar5", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar5")
LSM:Register("statusbar", "Roth_Statusbar6", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar128")
LSM:Register("statusbar", "Roth_Statusbar7", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar128_3")
LSM:Register("statusbar", "Roth_Statusbar8", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar256")
LSM:Register("statusbar", "Roth_Statusbar9", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar256_2")
LSM:Register("statusbar", "Roth_Statusbar10", "Interface\\AddOns\\DiabolusUnits\\media\\statusbar256_3")
LSM:Register("background", "Solid", "Interface\\AddOns\\DiabolusUnits\\media\\Solid.tga")
LSM:Register("font", "Cracked", "Interface\\AddOns\\DiabolusUnits\\media\\Cracked-Narrow.ttf")
LSM:Register("font", "Expressway", "Interface\\AddOns\\DiabolusUnits\\media\\Expressway.ttf")
LSM:Register("font", "Diablo", "Interface\\AddOns\\DiabolusUnits\\media\\Diablo Std Regular.otf")

---------------------------------------------
-- SCREEN & RESOLUTION METRICS
---------------------------------------------
function ns.GetScreenMetrics()
	local GetPhysicalScreenSize = rawget(_G, "GetPhysicalScreenSize")
	local physW, physH
	if GetPhysicalScreenSize then
		physW, physH = GetPhysicalScreenSize()
	end
	local uiW = UIParent:GetWidth() or 1440
	local uiH = UIParent:GetHeight() or 900
	local uiScale = UIParent:GetEffectiveScale() or 1
	local cvarUiScale = tonumber(GetCVar and GetCVar("uiScale") or "1") or 1
	local useUiScale = GetCVar and GetCVar("useUiScale") == "1"

	if not physW or physW == 0 then
		physW = math.floor(uiW * uiScale + 0.5)
		physH = math.floor(uiH * uiScale + 0.5)
	end

	local aspect = (physH and physH > 0) and (physW / physH) or (16 / 10)
	local pixelRatio = (uiH and uiH > 0) and (physH / uiH) or uiScale
	local onePixel = (uiScale and uiScale > 0) and (1 / uiScale) or 1
	local pixelPerfectScale = (physH and physH > 0) and (768 / physH) or 1

	return {
		physicalWidth = physW,
		physicalHeight = physH,
		uiWidth = uiW,
		uiHeight = uiH,
		uiScale = uiScale,
		cvarUiScale = cvarUiScale,
		useUiScale = useUiScale,
		aspectRatio = aspect,
		pixelRatio = pixelRatio,
		onePixel = onePixel,
		pixelPerfectScale = pixelPerfectScale,
	}
end

function func.ApplyPixelPerfectScale()
	if InCombatLockdown and InCombatLockdown() then
		return
	end
	local prof = ns.LayoutProfile and ns.LayoutProfile()
	if prof and prof.autoScale == false then
		return
	end
	local GetPhysicalScreenSize = rawget(_G, "GetPhysicalScreenSize")
	if GetPhysicalScreenSize then
		local _, physicalHeight = GetPhysicalScreenSize()
		if physicalHeight and physicalHeight > 0 then
			local scale = 768 / physicalHeight
			if scale >= 0.35 and scale <= 1.25 then
				UIParent:SetScale(scale)
			end
		end
	end
end
