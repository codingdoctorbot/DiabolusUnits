---------------------------------------------
--  Roth_UI - cast bar extras
---------------------------------------------
-- Channel ticks (player): a thin gold line wherever a channel ticks, so a
-- Drain Life or Arcane Missiles can be clipped after the last tick worth
-- having. Counts are MSUF's table for WoW Forever / Classic Era spell data
-- (MSUF_CastbarChannelTicks.lua: SpellDuration / EffectAuraPeriod per rank,
-- build 1.60.1). Fixed counts keep their ticks under haste, so the lines sit
-- at even fractions of the bar and no (possibly secret) time is read.
--
-- Interrupt ready (target, focus): while an enemy casts something you can
-- interrupt and your interrupt is off cooldown, the cast bar burns
-- orange. Interrupts are MSUF's Vanilla table, which Forever uses (Paladins
-- and Hunters have none there). Neither "cannot be interrupted" nor "ready"
-- is tested in Lua: a holder frame takes its alpha from the first, the glow
-- inside it from the second (SetAlphaFromBoolean takes secret booleans).

local _, ns = ...

local cfg = ns.cfg
local Secrets = ns.Secrets

local CastBars = {}
ns.CastBars = CastBars

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"

---------------------------------------------
-- CHANNEL TICKS
---------------------------------------------

local TICKS = {}
do
	local byCount = {
		[3] = {
			5143, -- Arcane Missiles (rank 1)
			15407, 17311, 17312, 17313, 17314, 18807, -- Mind Flay
			401417, 412510, -- Regeneration, Mass Regeneration
		},
		[4] = {
			5144, -- Arcane Missiles (rank 2)
			5740, 6219, 11677, 11678, -- Rain of Fire
		},
		[5] = {
			5145, 8416, 8417, 10211, 10212, 25345, -- Arcane Missiles (ranks 3-8)
			689, 699, 709, 7651, 11699, 11700, -- Drain Life
			5138, 6226, 11703, 11704, -- Drain Mana
			1120, 8288, 8289, 11675, -- Drain Soul
			136, 3111, 3661, 3662, 13542, 13543, 13544, -- Mend Pet
			740, 8918, 9862, 9863, -- Tranquility
			1260270, -- Rapid Regeneration
		},
		[6] = {
			10797, 19296, 19299, 19302, 19303, 19304, 19305, -- Starshards
			1510, 14294, 14295, -- Volley
			413259, -- Mind Sear
			1316697, -- Wrack
		},
		[8] = {
			10, 6141, 8427, 10185, 10186, 10187, -- Blizzard
		},
		[10] = {
			755, 3698, 3699, 3700, 11693, 11694, 11695, -- Health Funnel
			16914, 17401, 17402, -- Hurricane
		},
		[15] = {
			1949, 11683, 11684, -- Hellfire
		},
	}
	for count, ids in pairs(byCount) do
		for _, id in ipairs(ids) do
			TICKS[id] = count
		end
	end
end
CastBars.TICKS = TICKS

local function Chain(bar, key, fn)
	local old = bar[key]
	bar[key] = function(...)
		if old then
			old(...)
		end
		fn(...)
	end
end

local function HideTicks(bar)
	for _, line in ipairs(bar.RothTicks) do
		line:Hide()
	end
end

-- spellID: plain number or nil (oUF passes nil for a secret one).
function CastBars.ShowTicks(bar, spellID)
	HideTicks(bar)
	local count = spellID and TICKS[spellID]
	if not count then
		return
	end
	local width = bar:GetWidth()
	if type(width) ~= "number" or width <= 0 then
		return
	end
	for i = 1, count - 1 do
		local line = bar.RothTicks[i]
		if not line then
			line = bar:CreateTexture(nil, "OVERLAY", nil, -6)
			line:SetColorTexture(1, 0.8, 0.35, 0.8)
			line:SetWidth(1)
			bar.RothTicks[i] = line
		end
		line:ClearAllPoints()
		line:SetPoint("TOP", bar, "TOPLEFT", width * i / count, 0)
		line:SetPoint("BOTTOM", bar, "BOTTOMLEFT", width * i / count, 0)
		line:Show()
	end
end

function CastBars.AddChannelTicks(bar)
	if bar.RothTicks then
		return
	end
	bar.RothTicks = {}
	Chain(bar, "PostChannelStart", function(self, _, _, spellID)
		CastBars.ShowTicks(self, spellID)
	end)
	for _, key in ipairs({ "PostCastStart", "PostChannelStop", "PostCastStop", "PostCastFailed", "PostCastInterrupted" }) do
		Chain(bar, key, HideTicks)
	end
end

---------------------------------------------
-- INTERRUPT READY
---------------------------------------------

-- { spellID, spell book bank } per class; Spell Lock is the Felhunter's.
local INTERRUPTS = {
	DRUID = { 16979 }, -- Feral Charge
	MAGE = { 2139 }, -- Counterspell
	PRIEST = { 15487 }, -- Silence (Shadow talent)
	ROGUE = { 1766 }, -- Kick (ranks share the cooldown)
	SHAMAN = { 8042 }, -- Earth Shock (ranks share the cooldown)
	WARLOCK = { 19647, "Pet" }, -- Spell Lock
	WARRIOR = { 6552 }, -- Pummel
}
CastBars.INTERRUPTS = INTERRUPTS

local GCD_MAX = 1.5

local function Known(entry)
	if not IsSpellKnown then
		return true
	end
	local bank = entry[2] and Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank[entry[2]]
	local ok, known = pcall(IsSpellKnown, entry[1], bank)
	if not ok then
		return false
	end
	if Secrets.IsSecret(known) then
		return true -- let the cooldown decide
	end
	return known and true or false
end

-- Is the player's interrupt off cooldown? A plain or secret boolean, or nil
-- when the class has none / it is not learned / nothing can be read.
function CastBars.InterruptReady(class)
	local entry = INTERRUPTS[class or cfg.playerclass]
	if not entry or not Known(entry) then
		return nil
	end
	local spell = C_Spell
	if spell and spell.GetSpellCooldownDuration then
		local ok, d = pcall(spell.GetSpellCooldownDuration, entry[1], true)
		if ok and d and d.IsZero then
			return d:IsZero()
		end
	end
	if spell and spell.GetSpellCooldown then
		local ok, info = pcall(spell.GetSpellCooldown, entry[1])
		if ok and type(info) == "table" then
			local start, duration = info.startTime, info.duration
			if Secrets.IsSecret(start) or Secrets.IsSecret(duration) or Secrets.IsSecret(info.isEnabled) then
				return nil
			end
			if info.isEnabled == false then
				return false
			end
			return (duration or 0) <= GCD_MAX or (start or 0) <= 0
		end
	end
	return nil
end

-- The raw "cannot be interrupted" of the unit's current cast (maybe secret).
local function NotInterruptible(unit)
	local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
	if type(name) ~= "nil" then
		return notInterruptible
	end
	local cname, _, _, _, _, _, cnot = UnitChannelInfo(unit)
	if type(cname) ~= "nil" then
		return cnot
	end
	return true
end

local function Refresh(bar)
	local k = bar.RothKick
	local unit = bar.__owner and bar.__owner.unit
	local hostile = unit and Secrets.Bool(UnitCanAttack, "player", unit)
	-- not "hostile and Ready() or nil": that turns false (on cooldown) into
	-- nil and would test a secret answer's truth
	local ready
	if hostile then
		ready = CastBars.InterruptReady()
	end
	if type(ready) == "nil" then
		k.holder:Hide()
		return
	end
	k.holder:SetAlphaFromBoolean(NotInterruptible(unit), 0, 1)
	k.glow:SetAlphaFromBoolean(ready, 1, 0)
	k.holder:Show()
end
CastBars.RefreshInterrupt = Refresh

-- inset: how far the glow reaches past the bar (top, side, bottom); the
-- default fits the unit frames' cast bars, nameplates pass a smaller one.
function CastBars.AddInterruptReady(bar, inset)
	if bar.RothKick or not INTERRUPTS[cfg.playerclass] then
		return
	end
	inset = inset or { top = 26.5, side = 35, bottom = 24.2 }
	local holder = CreateFrame("Frame", nil, bar)
	holder:SetAllPoints(bar)
	holder:SetFrameLevel(bar:GetFrameLevel() + 2)
	holder:Hide()
	local glow = holder:CreateTexture(nil, "OVERLAY", nil, 2)
	glow:SetTexture(MEDIA .. "castbar_glow")
	glow:SetPoint("TOP", bar, "TOP", 0, inset.top)
	glow:SetPoint("LEFT", bar, "LEFT", -inset.side, 0)
	glow:SetPoint("RIGHT", bar, "RIGHT", inset.side, 0)
	glow:SetPoint("BOTTOM", bar, "BOTTOM", 0, -inset.bottom)
	glow:SetVertexColor(1, 0.45, 0.05, 1)
	glow:SetBlendMode("ADD")
	bar.RothKick = { holder = holder, glow = glow }

	for _, key in ipairs({ "PostCastStart", "PostChannelStart", "PostCastInterruptible", "PostCastNotInterruptible" }) do
		Chain(bar, key, Refresh)
	end
	for _, key in ipairs({ "PostCastStop", "PostChannelStop", "PostCastFailed", "PostCastInterrupted" }) do
		Chain(bar, key, function(self)
			self.RothKick.holder:Hide()
		end)
	end
	-- the cooldown can run out mid-cast: look again a few times a second
	-- while the bar is up
	local elapsed = 0
	holder:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= 0.1 then
			elapsed = 0
			Refresh(bar)
		end
	end)
end
