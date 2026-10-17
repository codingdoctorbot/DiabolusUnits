---------------------------------------------
--  Roth_UI - missing buffs on group frames
---------------------------------------------
-- Out of combat, what your group is missing:
--
--   on each member's frame  a small icon per buff they lack (bright) or
--                           that is running out (dim), top left
--   above the group frames  one icon per buff with how many lack it, and
--                           in grey how many have it running out
--
-- Which buffs: the long class buffs someone in the group can cast
-- (MSUF Game/Forever/GroupFrames/MSUF_GroupFrames_BuffCoverage.lua does the
-- same): Power Word / Prayer of Fortitude, Arcane Intellect / Brilliance
-- (mana users only), Mark / Gift of the Wild. Your own extras when you know
-- them: Divine Spirit (mana users), Shadow Protection (off by default:
-- cfg.buffCoverage.shadowProtection), and for a paladin "no blessing from
-- you". Every rank and group form counts (IDs: ForeverUnitFrames
-- Raid/BuffData.lua). "Running out": under a third of its duration left
-- (ForeverUnitFrames' buff watch).
--
-- Nothing is guessed: while the client keeps auras secret
-- (C_Secrets.ShouldAurasBeSecret) or an aura answers secret, a member is
-- unknown and shows nothing. In combat everything hides. Scanned at most
-- twice a second after a change and every 10 s in a group (a buff runs low
-- without an event).

local _, ns = ...

local cfg = ns.cfg
local Secrets = ns.Secrets

local Coverage = {}
ns.BuffCoverage = Coverage

local BLESSINGS = {
	19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916, -- Might
	19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918, -- Wisdom
	20217, 25898, -- Kings
	1038, 25895, -- Salvation
	19977, 19978, 19979, 25890, -- Light
	20911, 20912, 20913, 20914, 25899, -- Sanctuary
}

-- key, caster class, every rank / form, icon spell, who gets it, how known
Coverage.BUFFS = {
	{ key = "fortitude", class = "PRIEST", ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
	{ key = "intellect", class = "MAGE", ids = { 1459, 1460, 1461, 10156, 10157, 23028 }, manaOnly = true },
	{ key = "wild", class = "DRUID", ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 } },
	{ key = "spirit", class = "PRIEST", ids = { 14752, 14818, 14819, 27841, 27681 }, manaOnly = true, own = true },
	{ key = "shadowProtection", class = "PRIEST", ids = { 976, 10957, 10958, 27683 }, own = true, off = true },
	{ key = "blessing", class = "PALADIN", ids = BLESSINGS, own = true, mine = true },
}

local NO_MANA = { WARRIOR = true, ROGUE = true }
local MAX_ICONS = 3
local RESCAN = 10

local lookup = {} -- spell ID -> buff
for _, b in ipairs(Coverage.BUFFS) do
	for _, id in ipairs(b.ids) do
		lookup[id] = b
	end
end

local function Opt(key, default)
	local c = cfg.buffCoverage
	if type(c) == "table" and c[key] ~= nil then
		return c[key]
	end
	if c == false then
		return false
	end
	return default
end

local function Plain(v)
	if Secrets.IsSecret(v) then
		return nil
	end
	return v
end

local function Known(b)
	if not IsSpellKnown then
		return false
	end
	for _, id in ipairs(b.ids) do
		local ok, known = pcall(IsSpellKnown, id)
		if ok and Plain(known) then
			return true
		end
	end
	return false
end

-- The group's units, you included; none when solo.
function Coverage.Units()
	local units = {}
	if IsInRaid() then
		for i = 1, 40 do
			if UnitExists("raid" .. i) then
				units[#units + 1] = "raid" .. i
			end
		end
	elseif IsInGroup() then
		units[1] = "player"
		for i = 1, 4 do
			if UnitExists("party" .. i) then
				units[#units + 1] = "party" .. i
			end
		end
	end
	return units
end

-- The buffs watched for this group, in order.
function Coverage.Watched(units)
	local classes = { [cfg.playerclass] = true }
	for _, unit in ipairs(units) do
		local _, class = UnitClass(unit)
		if Plain(class) then
			classes[class] = true
		end
	end
	local out = {}
	for _, b in ipairs(Coverage.BUFFS) do
		local wanted = Opt(b.key, not b.off)
		if wanted then
			if b.own then
				wanted = b.class == cfg.playerclass and Known(b)
			else
				wanted = classes[b.class] == true
			end
		end
		if wanted then
			out[#out + 1] = b
		end
	end
	return out
end

local function AurasSecret()
	local s = C_Secrets and C_Secrets.ShouldAurasBeSecret
	if not s then
		return false
	end
	local ok, secret = pcall(s)
	return not ok or secret ~= false
end

-- buff -> "ok" | "low" for what the unit carries; nil when unknown.
function Coverage.Carried(unit, now)
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not get then
		return nil
	end
	local carried = {}
	for i = 1, 40 do
		local aura = get(unit, i, "HELPFUL")
		if not aura then
			break
		end
		local id = aura.spellId
		if Secrets.IsSecret(id) then
			return nil
		end
		local b = lookup[id]
		if b then
			local fromYou = true
			if b.mine then
				local source = Plain(aura.sourceUnit)
				fromYou = source ~= nil and UnitIsUnit(source, "player")
			end
			if fromYou then
				local duration, expires = Plain(aura.duration), Plain(aura.expirationTime)
				local low = duration and expires and duration > 0 and (expires - now) < duration / 3
				if carried[b] ~= "ok" then
					carried[b] = low and "low" or "ok"
				end
			end
		end
	end
	return carried
end

-- unit -> { { buff, "missing" | "low" }, ... } for the units given.
function Coverage.Scan(units, watched)
	local states = {}
	if InCombatLockdown() or #watched == 0 or AurasSecret() then
		return states
	end
	local now = GetTime()
	for _, unit in ipairs(units) do
		if Plain(UnitIsConnected(unit)) and not Secrets.Bool(UnitIsDeadOrGhost, unit) then
			local carried = Coverage.Carried(unit, now)
			if carried then
				local _, class = UnitClass(unit)
				class = Plain(class)
				local list = {}
				for _, b in ipairs(watched) do
					if not (b.manaOnly and (class == nil or NO_MANA[class])) then
						local have = carried[b]
						if have == nil then
							list[#list + 1] = { b, "missing" }
						elseif have == "low" then
							list[#list + 1] = { b, "low" }
						end
					end
				end
				states[unit] = list
			end
		end
	end
	return states
end

---------------------------------------------
-- DISPLAY
---------------------------------------------

local frames = {}
local states = {}
local watched = {}

local function Icon(parent, size)
	local t = parent:CreateTexture(nil, "OVERLAY", nil, 4)
	t:SetSize(size, size)
	t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	t:Hide()
	return t
end

local function SpellIcon(b)
	return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(b.ids[1])) or 136243
end

function Coverage.Update(frame)
	local icons = frame.RothMissingBuffs
	if not icons then
		return
	end
	local list = frame.__unit and states[frame.__unit] or nil
	for i, icon in ipairs(icons) do
		local entry = list and list[i]
		if entry then
			icon:SetTexture(SpellIcon(entry[1]))
			icon:SetAlpha(entry[2] == "missing" and 0.9 or 0.4)
			icon:Show()
		else
			icon:Hide()
		end
	end
end

-- the summary row above the party / raid frames
local summary = CreateFrame("Frame", "Roth_UIBuffSummary", UIParent)
summary:SetSize(1, 22)
summary:Hide()
summary.cells = {}

local function Cell(i)
	local c = summary.cells[i]
	if not c then
		c = CreateFrame("Frame", nil, summary)
		c:SetSize(22, 22)
		c:SetPoint("LEFT", summary, "LEFT", (i - 1) * 46, 0)
		c.icon = Icon(c, 20)
		c.icon:SetPoint("LEFT")
		c.icon:Show()
		c.count = c:CreateFontString(nil, "OVERLAY")
		c.count:SetFont(cfg.font, 13, "THINOUTLINE")
		c.count:SetPoint("LEFT", c.icon, "RIGHT", 2, 3)
		c.count:SetTextColor(1, 0.82, 0.4)
		c.low = c:CreateFontString(nil, "OVERLAY")
		c.low:SetFont(cfg.font, 10, "THINOUTLINE")
		c.low:SetPoint("TOPLEFT", c.count, "BOTTOMLEFT", 0, -1)
		c.low:SetTextColor(0.6, 0.6, 0.6)
		summary.cells[i] = c
	end
	return c
end

function Coverage.Summary()
	local counts = {}
	for _, list in pairs(states) do
		for _, entry in ipairs(list) do
			local b = entry[1]
			counts[b] = counts[b] or { missing = 0, low = 0 }
			counts[b][entry[2]] = counts[b][entry[2]] + 1
		end
	end
	local n = 0
	for _, b in ipairs(watched) do
		local c = counts[b]
		if c then
			n = n + 1
			local cell = Cell(n)
			cell.icon:SetTexture(SpellIcon(b))
			cell.count:SetText(c.missing > 0 and c.missing or "")
			cell.low:SetText(c.low > 0 and ("+" .. c.low) or "")
			cell.icon:SetAlpha(c.missing > 0 and 1 or 0.5)
			cell:Show()
		end
	end
	for i = n + 1, #summary.cells do
		summary.cells[i]:Hide()
	end
	local anchor = rawget(_G, IsInRaid() and "Roth_UIRaidDragFrame" or "Roth_UIPartyDragFrame")
	if n > 0 and anchor and Opt("summary", true) and not InCombatLockdown() then
		summary:ClearAllPoints()
		summary:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
		summary:SetWidth(n * 46)
		summary:Show()
	else
		summary:Hide()
	end
	return counts
end

function Coverage.Refresh()
	local units = Coverage.Units()
	watched = Opt("enabled", true) and Coverage.Watched(units) or {}
	states = Coverage.Scan(units, watched)
	for _, frame in ipairs(frames) do
		Coverage.Update(frame)
	end
	Coverage.Summary()
end

local pending = false
function Coverage.Queue()
	if pending then
		return
	end
	pending = true
	C_Timer.After(0.5, function()
		pending = false
		Coverage.Refresh()
	end)
end

local function OnAura(frame, _, unit)
	if unit == frame.__unit or Secrets.IsSecret(unit) then
		Coverage.Queue()
	end
end

function Coverage.Attach(frame, parent)
	if frame.RothMissingBuffs or cfg.buffCoverage == false then
		return
	end
	local icons = {}
	for i = 1, MAX_ICONS do
		local icon = Icon(parent, 12)
		icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 1 + (i - 1) * 13, -1)
		icons[i] = icon
	end
	frame.RothMissingBuffs = icons
	frames[#frames + 1] = frame
	frame:RegisterEvent("UNIT_AURA", OnAura)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
	events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		-- nothing to rebuff in a fight: hide at once
		wipe(states)
		for _, frame in ipairs(frames) do
			Coverage.Update(frame)
		end
		summary:Hide()
	else
		Coverage.Queue()
	end
end)

local ticker = 0
events:SetScript("OnUpdate", function(_, elapsed)
	ticker = ticker + elapsed
	if ticker >= RESCAN then
		ticker = 0
		if IsInGroup() and not InCombatLockdown() then
			Coverage.Refresh()
		end
	end
end)
