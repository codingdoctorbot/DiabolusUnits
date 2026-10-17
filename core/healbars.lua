---------------------------------------------
--  Roth_UI - incoming heals, absorbs, heal absorbs
---------------------------------------------
-- oUF 14's Health element fills these from the client's heal prediction
-- calculator (CreateUnitHealPredictionCalculator): on WoW Forever the values
-- are secret, so nothing is added, compared or clamped in Lua. Status bars
-- as long as the health bar (oUF keeps them sized) and on its scale
-- (0 .. max health) hang from the end of the health fill; a clipping frame
-- over the health bar cuts them at full health.
--
--   HealingPlayer  your own incoming heals, bright emerald
--   HealingAll     everyone's incoming heals, darker green (what shows past
--                  your own is other healers')
--   DamageAbsorb   shields, gold stripes after the incoming heals
--   HealAbsorb     necrotic-style "absorb healing" effects, dark red, drawn
--                  back over the end of the health
--
-- HealBars.Attach(frame, healthBar) from a style function, before oUF
-- enables the Health element; a vertical health bar (the raid tiles) gets
-- bars that stack upwards from the top of its fill.

local _, ns = ...

local cfg = ns.cfg

local HealBars = {}
ns.HealBars = HealBars

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Opt(key, default)
	local h = cfg.healbars
	if h and h[key] ~= nil then
		return h[key]
	end
	return default
end

local function Bar(parent, level, r, g, b, a)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetFrameLevel(level)
	bar:SetStatusBarTexture(WHITE)
	bar:SetStatusBarColor(r, g, b, a)
	return bar
end

-- frame: an oUF frame; health: its Health StatusBar.
function HealBars.Attach(frame, health)
	if frame.RothHealBars then
		return frame.RothHealBars
	end
	local fill = health:GetStatusBarTexture()
	local base = health:GetFrameLevel()

	-- everything is cut at the end of the health bar
	local clip = CreateFrame("Frame", nil, health)
	clip:SetClipsChildren(true)
	clip:SetAllPoints(health)
	clip:SetFrameLevel(base + 1)

	local vertical = health.GetOrientation and health:GetOrientation() == "VERTICAL"
	-- where each bar starts: after the end of the one before it
	local function After(bar, prev)
		if vertical then
			bar:SetOrientation("VERTICAL")
			bar:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, 0)
			bar:SetPoint("BOTTOMRIGHT", prev, "TOPRIGHT", 0, 0)
		else
			bar:SetPoint("TOPLEFT", prev, "TOPRIGHT", 0, 0)
			bar:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 0, 0)
		end
	end

	local hb = { clip = clip }

	if Opt("heals", true) then
		hb.all = Bar(clip, base + 1, 0.05, 0.55, 0.2, 0.55)
		hb.mine = Bar(clip, base + 2, 0.15, 0.95, 0.35, 0.7)
		After(hb.all, fill)
		After(hb.mine, fill)
		health.HealingAll = hb.all
		health.HealingPlayer = hb.mine
	end

	if Opt("absorbs", true) then
		-- shields after all incoming heals: gold, with Roth's stripe overlay
		hb.absorb = Bar(clip, base + 3, 1, 0.82, 0.35, 0.35)
		After(hb.absorb, hb.all and hb.all:GetStatusBarTexture() or fill)
		local stripes = hb.absorb:CreateTexture(nil, "OVERLAY")
		stripes:SetTexture(MEDIA .. "absorb_statusbar_overlay", "REPEAT", "REPEAT")
		stripes:SetHorizTile(true)
		stripes:SetVertTile(true)
		stripes:SetVertexColor(1, 0.85, 0.4, 0.9)
		stripes:SetAllPoints(hb.absorb:GetStatusBarTexture())
		health.DamageAbsorb = hb.absorb

		-- heal absorbs: from the end of the health back over it (reverse fill)
		hb.healAbsorb = Bar(clip, base + 4, 0.35, 0, 0.05, 0.75)
		hb.healAbsorb:SetReverseFill(true)
		if vertical then
			hb.healAbsorb:SetOrientation("VERTICAL")
			hb.healAbsorb:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
			hb.healAbsorb:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
		else
			hb.healAbsorb:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
			hb.healAbsorb:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
		end
		health.HealAbsorb = hb.healAbsorb
	end

	frame.RothHealBars = hb
	return hb
end
