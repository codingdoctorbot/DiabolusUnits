---------------------------------------------
--  DiabolusUnits - Potion Belt
---------------------------------------------
-- Diablo's belt: five glass flasks holding the best of each from your bags:
--   1 health potion   2 healthstone   3 mana potion (rage potion for warriors,
--   Thistle Tea for rogues, mana gems first for mages)   4 food   5 bandage
-- "Best" comes from ranked item lists (core/beltdata.lua); an item that is not
-- listed is still found by its type and name, ranked by item level. Inside a
-- battleground the free draughts and bandages are used first. Items you are too
-- low level for are skipped. Bandages always go on yourself.
--
-- Each flask shows the item's icon, how many you carry and its cooldown (the
-- liquid drains and refills). The food flask is about the Well Fed buff, not
-- about eating to regenerate: it prefers buff food, its liquid shows how much of
-- the buff is left, and it pulses when the buff is missing or about to run out
-- (cfg.belt.foodWarnMinutes) while you carry buff food. Key bindings: Key
-- Bindings > AddOns > DiabolusUnits: Belt 1-5.
--
-- The buttons are secure; what they hold can only change out of combat, so an
-- item looted in a fight takes its slot when the fight ends. Counts and
-- cooldowns update in combat. Auras are secret in combat on Forever, so the food
-- flask keeps its last known buff state until the fight ends.

local _, ns = ...

local cfg = ns.cfg
local Secrets = ns.Secrets
local Data = ns.BeltData

local Belt = {}
ns.Belt = Belt

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"
local SLOTS = { "health", "healthstone", "mana", "food", "bandage" }
local SIZE, GAP = 34, 6
local LIQUID = {
	health = { 0.85, 0.08, 0.05 },
	healthstone = { 0.3, 0.85, 0.2 },
	mana = { 0.15, 0.4, 1 },
	rage = { 0.95, 0.35, 0.08 },
	energy = { 0.95, 0.8, 0.15 },
	food = { 0.85, 0.55, 0.15 },
	bandage = { 0.85, 0.78, 0.6 },
}
local FILL_W, FILL_H, FILL_Y = 76 / 128, 87 / 128, (64 - 60.5) / 128

local CONSUMABLE = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
local SUB = (Enum and Enum.ItemConsumableSubclass) or {}
local POTION, BANDAGE = SUB.Potion or 1, SUB.Bandage or 7
local MANA_GEMS = { "mana agate", "mana jade", "mana citrine", "mana ruby", "mana emerald" }

local _, playerClass = UnitClass("player")
-- what the third flask holds for this class
local THIRD = (playerClass == "WARRIOR" and "rage") or (playerClass == "ROGUE" and "energy") or "mana"

local function Opt(key, default)
	local b = cfg.belt
	if b and b[key] ~= nil then
		return b[key]
	end
	return default
end

local function ItemSpellName(itemID)
	if not (C_Item and C_Item.GetItemSpell) then
		return nil
	end
	local ok, name = pcall(C_Item.GetItemSpell, itemID)
	return ok and type(name) == "string" and name or nil
end

local function HasAny(text, words)
	for _, word in ipairs(words) do
		if text:find(word, 1, true) then
			return true
		end
	end
	return false
end

-- Fallback for items the ranked lists do not know (new Forever items): type + English name
local function ClassifyBeltItem(name, classID, subclassID, spell)
	if classID ~= CONSUMABLE then
		return nil
	end
	local lower = (name or ""):lower()
	local spellLower = (spell or ""):lower()
	if lower:find("healthstone", 1, true) then
		return "healthstone"
	elseif HasAny(lower, MANA_GEMS) then
		return "mana"
	elseif subclassID == POTION then
		if spellLower:find("mana", 1, true) or lower:find("mana", 1, true) then
			return "mana"
		elseif spellLower:find("heal", 1, true) or lower:find("heal", 1, true) or spell == nil then
			return "health"
		end
	elseif subclassID == BANDAGE or lower:find("bandage", 1, true) then
		return "bandage"
	end
	return nil
end

local function Count(itemID)
	local n = C_Item.GetItemCount(itemID, false, false)
	return (Secrets and Secrets.Number(n)) or (type(n) == "number" and n) or 0
end

-- First carried item of a ranked list. With `levelGated`, items the client calls
-- unusable (too high a level requirement) are skipped; potions are not gated because
-- IsUsableItem also says "unusable" for reasons the lists already handle (power type).
local function FirstCarried(list, levelGated)
	for _, id in ipairs(list) do
		if Count(id) > 0 then
			if not levelGated or not C_Item.IsUsableItem then
				return id
			end
			local ok, usable = pcall(C_Item.IsUsableItem, id)
			if not ok or usable ~= false then
				return id
			end
		end
	end
	return nil
end

local function InBattleground()
	local inInstance, instanceType = IsInInstance()
	return inInstance and instanceType == "pvp"
end

local function BattlegroundBandages()
	local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	if map == Data.MAP_AV then
		return Data.BANDAGE_AV
	elseif map == Data.MAP_WSG then
		return Data.BANDAGE_WSG
	elseif map == Data.MAP_AB then
		return UnitFactionGroup("player") == "Alliance" and Data.BANDAGE_AB_ALLIANCE or Data.BANDAGE_AB_HORDE
	end
	return nil
end

-- category -> ranked lists to try, in order
local function RankedLists(cat)
	local bg = InBattleground()
	if cat == "health" then
		return { bg and Data.HEALTH_BG, Data.HEALTH }
	elseif cat == "healthstone" then
		return { Data.HEALTHSTONE }
	elseif cat == "mana" then
		if THIRD == "rage" then
			return { Data.RAGE }
		elseif THIRD == "energy" then
			return { Data.ENERGY }
		end
		return { playerClass == "MAGE" and Data.MANA_GEM, bg and Data.MANA_BG, Data.MANA }
	elseif cat == "food" then
		return { Data.FOOD_BUFF, Data.FOOD }
	elseif cat == "bandage" then
		return { bg and BattlegroundBandages(), Data.BANDAGE }
	end
	return {}
end

-- Food and bandages carry level requirements; potions are listed per class already
local LEVEL_GATED = { food = true, bandage = true }

local function Resolve(cat)
	for _, list in ipairs(RankedLists(cat)) do
		local id = list and FirstCarried(list, LEVEL_GATED[cat])
		if id then
			return id
		end
	end
	return nil
end

-- Fallback scan for categories the ranked lists left empty
local function ScanUnlisted(want)
	local best, seen = {}, {}
	local lastBag = rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS") or rawget(_G, "NUM_BAG_SLOTS") or 4
	for bag = 0, lastBag do
		for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local itemID = info and info.itemID
			if itemID and not seen[itemID] then
				seen[itemID] = true
				local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
				local name, _, _, itemLevel = C_Item.GetItemInfo(itemID)
				local cat = ClassifyBeltItem(name, classID, subclassID, ItemSpellName(itemID))
				if cat and want[cat] then
					local lvl = (Secrets and Secrets.Number(itemLevel)) or (type(itemLevel) == "number" and itemLevel) or 0
					if not best[cat] or lvl > best[cat].level then
						best[cat] = { itemID = itemID, level = lvl }
					end
				end
			end
		end
	end
	return best
end

function Belt:ScanBags()
	local picked, missing = {}, {}
	for _, cat in ipairs(SLOTS) do
		picked[cat] = Resolve(cat)
		if not picked[cat] and cat ~= "food" and not (cat == "mana" and THIRD ~= "mana") then
			missing[cat] = true
		end
	end
	if next(missing) then
		for cat, entry in pairs(ScanUnlisted(missing)) do
			picked[cat] = entry.itemID
		end
	end
	return picked
end

-- ── Well Fed ──────────────────────────────────────────────────────────────────
-- Classic's Well Fed buffs share the Spell_Misc_Food icon; the English name is a
-- fallback. Read only while auras are not secret (out of combat); the last known
-- state is kept otherwise. /diabolus food lists your buffs to check this in game.
local WELL_FED_ICONS = { [136000] = true, ["interface\\icons\\spell_misc_food"] = true }
local WELL_FED_NAMES = { ["well fed"] = true }

local function AurasSecret()
	local s = C_Secrets and C_Secrets.ShouldAurasBeSecret
	if not s then
		return false
	end
	local ok, secret = pcall(s)
	return not ok or secret ~= false
end

local function IsWellFed(aura)
	local icon = aura.icon
	if icon ~= nil and not (Secrets and Secrets.IsSecret(icon)) then
		local key = type(icon) == "string" and icon:lower() or icon
		if WELL_FED_ICONS[key] then
			return true
		end
	end
	local name = aura.name
	if type(name) == "string" and not (Secrets and Secrets.IsSecret(name)) then
		return WELL_FED_NAMES[name:lower()] or false
	end
	return false
end

Belt.wellFed = nil -- { expires = time or 0 for no timer, duration = seconds } or false; nil = unknown

function Belt:ScanWellFed()
	if InCombatLockdown() or AurasSecret() then
		return
	end
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not get then
		return
	end
	local found = false
	for i = 1, 40 do
		local aura = get("player", i, "HELPFUL")
		if not aura then
			break
		end
		if Secrets and Secrets.IsSecret(aura.spellId) then
			return
		end
		if IsWellFed(aura) then
			local duration = Secrets and Secrets.Number(aura.duration) or aura.duration
			local expires = Secrets and Secrets.Number(aura.expirationTime) or aura.expirationTime
			found = { duration = duration or 0, expires = expires or 0 }
			break
		end
	end
	self.wellFed = found
end

-- remaining fraction 0..1 of Well Fed, and whether to warn
local function WellFedState(now)
	local wf = Belt.wellFed
	if wf == nil then
		return 1, false
	end
	if not wf then
		return 0, true
	end
	if not wf.duration or wf.duration <= 0 or not wf.expires or wf.expires <= 0 then
		return 1, false
	end
	local left = wf.expires - now
	if left <= 0 then
		return 0, true
	end
	return math.min(1, left / wf.duration), left < Opt("foodWarnMinutes", 10) * 60
end

function Belt.DebugFood()
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not get then
		print("DiabolusUnits: no C_UnitAuras on this client")
		return
	end
	if AurasSecret() then
		print("DiabolusUnits: auras are secret right now (combat); try again after the fight")
		return
	end
	print("DiabolusUnits: your buffs (name, spell ID, icon) - Well Fed ones are marked")
	for i = 1, 40 do
		local aura = get("player", i, "HELPFUL")
		if not aura then
			break
		end
		print(("  %s  %s  %s%s"):format(tostring(aura.name), tostring(aura.spellId), tostring(aura.icon), IsWellFed(aura) and "  <- Well Fed" or ""))
	end
end

local holder = CreateFrame("Frame", "Roth_UIBelt", UIParent)
holder:SetSize(#SLOTS * SIZE + (#SLOTS - 1) * GAP, SIZE)
holder:SetFrameStrata("MEDIUM")
Belt.holder = holder
Belt.buttons = {}
holder.defaultPosition = { a1 = "BOTTOMLEFT", af = "Roth_UIPlayerFrame", a2 = "BOTTOMRIGHT", x = -12, y = 26 }
holder:SetScript("OnMouseDown", function(s)
	if ns.EditMode and ns.EditMode.active and ns.EditMode.SelectFrame then
		ns.EditMode:SelectFrame(s)
	end
end)

local function Place()
	-- the belt's secure buttons make the holder protected: no moving it in combat
	if InCombatLockdown() then
		Belt.pending = true
		return
	end
	holder:ClearAllPoints()
	local prof = ns.LayoutProfile and ns.LayoutProfile()
	if prof and prof.framePositions and prof.framePositions["Roth_UIBelt"] then
		local pos = prof.framePositions["Roth_UIBelt"]
		local relTo = (pos.relativeTo and rawget(_G, pos.relativeTo)) or UIParent
		holder:SetPoint(pos.point or "BOTTOM", relTo, pos.relativePoint or "BOTTOM", pos.x or -12, pos.y or 26)
		return
	end

	-- Standard/gamepad layout owns the default position (bag wing or beside the orb);
	-- without this, every bag update put the belt back beside the orb, behind the action buttons
	if ns.StandardMode and ns.StandardMode:AnchorBelt() then
		return
	end

	local pframe = rawget(_G, "Roth_UIPlayerFrame")
	if pframe then
		holder:SetPoint("BOTTOMLEFT", pframe, "BOTTOMRIGHT", Opt("x", -12), Opt("y", 26))
	else
		holder:SetPoint("BOTTOM", UIParent, "BOTTOM", -235, Opt("y", 26))
	end
end

-- the strap and its buckles
do
	local strap = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
	strap:SetTexture(MEDIA .. "combo_back2")
	strap:SetPoint("LEFT", holder, "LEFT", -6, 0)
	strap:SetPoint("RIGHT", holder, "RIGHT", 6, 0)
	strap:SetHeight(SIZE * 1.1)
	strap:SetVertexColor(0.8, 0.7, 0.6)
	for _, side in ipairs({ "LEFT", "RIGHT" }) do
		local cap = holder:CreateTexture(nil, "BACKGROUND", nil, -7)
		cap:SetTexture(MEDIA .. (side == "LEFT" and "combo_bar_left" or "combo_bar_right"))
		cap:SetSize(SIZE * 1.4, SIZE * 1.4)
		if side == "LEFT" then
			cap:SetPoint("RIGHT", holder, "LEFT", 4, 0)
		else
			cap:SetPoint("LEFT", holder, "RIGHT", -4, 0)
		end
	end
end

for i, cat in ipairs(SLOTS) do
	local b = CreateFrame("Button", "Roth_UIBelt" .. i, holder, "SecureActionButtonTemplate")
	b:SetSize(SIZE, SIZE)
	b:SetPoint("LEFT", holder, "LEFT", (i - 1) * (SIZE + GAP), 0)
	b:RegisterForClicks("AnyDown")
	b:SetAttribute("useOnKeyDown", true)
	b.cat = cat
	b.liquidKey = (cat == "mana") and THIRD or cat

	local bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetTexture(MEDIA .. "combo_pot_bg")
	bg:SetPoint("CENTER")
	bg:SetSize(SIZE * 1.5, SIZE * 1.5)

	local liquid = CreateFrame("StatusBar", nil, b)
	liquid:SetSize(SIZE * 1.5 * FILL_W, SIZE * 1.5 * FILL_H)
	liquid:SetPoint("CENTER", b, "CENTER", 0, SIZE * 1.5 * FILL_Y)
	liquid:SetOrientation("VERTICAL")
	liquid:SetStatusBarTexture(MEDIA .. "combo_pot_fill1")
	local c = LIQUID[b.liquidKey]
	liquid:SetStatusBarColor(c[1], c[2], c[3])
	liquid:SetMinMaxValues(0, 1)
	liquid:SetValue(1)
	liquid:SetFrameLevel(b:GetFrameLevel())
	b.liquid = liquid

	local over = CreateFrame("Frame", nil, b)
	over:SetAllPoints(b)
	over:SetFrameLevel(liquid:GetFrameLevel() + 2)

	local icons = Opt("icons", true)
	local icon = over:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	icon:SetSize(SIZE - 14, SIZE - 14)
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	icon:SetShown(icons)
	b.icon = icon

	local cd = CreateFrame("Cooldown", nil, over, "CooldownFrameTemplate")
	cd:SetAllPoints(icon)
	cd:SetDrawEdge(false)
	cd:SetAlpha(icons and 1 or 0)
	b.cooldown = cd
	local border = over:CreateTexture(nil, "OVERLAY", nil, -2)
	border:SetTexture(MEDIA .. "combo_pot_border")
	border:SetPoint("CENTER")
	border:SetSize(SIZE * 1.5, SIZE * 1.5)
	local gloss = over:CreateTexture(nil, "OVERLAY", nil, -1)
	gloss:SetTexture(MEDIA .. "combo_pot_highlight")
	gloss:SetAllPoints(border)
	gloss:SetBlendMode("ADD")
	gloss:SetAlpha(0.5)

	local count = over:CreateFontString(nil, "OVERLAY")
	count:SetFont(cfg.font, 12, "THINOUTLINE")
	count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
	count:SetTextColor(1, 0.9, 0.7)
	b.count = count

	local key = over:CreateFontString(nil, "OVERLAY")
	key:SetFont(cfg.font, 10, "THINOUTLINE")
	key:SetPoint("TOPLEFT", b, "TOPLEFT", 1, 0)
	key:SetTextColor(0.7, 0.6, 0.5)
	b.key = key

	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(MEDIA .. "combo_pot_glow")
	hl:SetAllPoints(border)
	hl:SetBlendMode("ADD")

	if cat == "food" then
		-- pulses while Well Fed is missing or running out and you carry buff food
		local warn = over:CreateTexture(nil, "OVERLAY", nil, 1)
		warn:SetTexture(MEDIA .. "combo_pot_glow")
		warn:SetAllPoints(border)
		warn:SetBlendMode("ADD")
		warn:SetVertexColor(1, 0.6, 0.15)
		warn:SetAlpha(0)
		local pulse = warn:CreateAnimationGroup()
		pulse:SetLooping("BOUNCE")
		local fade = pulse:CreateAnimation("Alpha")
		fade:SetFromAlpha(0.15)
		fade:SetToAlpha(0.9)
		fade:SetDuration(0.8)
		fade:SetSmoothing("IN_OUT")
		b.warn, b.warnPulse = warn, pulse
	end

	b:SetScript("OnEnter", function(self)
		if self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetItemByID(self.itemID)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	Belt.buttons[i] = b
end

local function Num(v)
	if Secrets then
		return Secrets.Number(v)
	end
	return type(v) == "number" and v or nil
end

local function Level(b, now)
	if b.cat == "food" then
		-- the food flask shows how much Well Fed is left, not the food's cooldown
		return (WellFedState(now))
	end
	if (b.have or 0) == 0 then
		return 0, false
	end
	local start, duration = b.cdStart, b.cdDuration
	if start and duration and duration > 1.5 then
		local p = (now - start) / duration
		if p < 1 then
			return math.max(0, p), true
		end
	end
	return 1, false
end

local driver = CreateFrame("Frame", nil, holder)
driver:Hide()
driver:SetScript("OnUpdate", function()
	local now, running = GetTime(), false
	for _, b in ipairs(Belt.buttons) do
		local v, busy = Level(b, now)
		b.liquid:SetValue(v)
		running = running or busy
	end
	if not running then
		driver:Hide()
	end
end)

function Belt:Update()
	for _, b in ipairs(self.buttons) do
		local id = b.itemID
		b.cdStart, b.cdDuration = nil, nil
		if id then
			local n = Num(C_Item.GetItemCount(id, false, true)) or 0
			b.have = n
			b.count:SetText(n > 1 and n or "")
			b.icon:SetDesaturated(n == 0)
			local start, duration, enable = C_Container.GetItemCooldown(id)
			start, duration, enable = Num(start), Num(duration), Num(enable)
			if enable and enable ~= 0 and start and duration and duration > 0 then
				b.cdStart, b.cdDuration = start, duration
				b.cooldown:SetCooldown(start, duration)
			else
				b.cooldown:Clear()
			end
		else
			b.have = 0
			b.count:SetText("")
			b.cooldown:Clear()
		end
		local v = Level(b, GetTime())
		b.liquid:SetValue(v)
		local c = LIQUID[b.liquidKey]
		if (b.have or 0) == 0 then
			b.liquid:SetStatusBarColor(0.3, 0.3, 0.3)
		else
			b.liquid:SetStatusBarColor(c[1], c[2], c[3])
		end
		local bound = GetBindingKey("CLICK " .. b:GetName() .. ":LeftButton")
		b.key:SetText(bound and GetBindingText(bound, true) or "")
	end
	self:UpdateFoodWarning()
	driver:Show()
end

-- Food flask: liquid follows Well Fed's time left; pulse when it is missing or low
-- and buff food is in the bags. Out of combat only (that is when you can eat).
function Belt:UpdateFoodWarning()
	for _, b in ipairs(self.buttons) do
		if b.cat == "food" then
			local fraction, low = WellFedState(GetTime())
			b.liquid:SetValue(fraction)
			local buffFood = b.itemID and self.isBuffFood and self.isBuffFood[b.itemID]
			local warn = low and buffFood and (b.have or 0) > 0 and not InCombatLockdown()
			if warn and not b.warnPulse:IsPlaying() then
				b.warnPulse:Play()
			elseif not warn and b.warnPulse:IsPlaying() then
				b.warnPulse:Stop()
				b.warn:SetAlpha(0)
			end
		end
	end
end

local function ItemIcon(id)
	if C_Item.GetItemIconByID then
		local icon = C_Item.GetItemIconByID(id)
		if icon then
			return icon
		end
	end
	local _, _, _, _, icon = C_Item.GetItemInfoInstant(id)
	return icon
end

function Belt:Refresh()
	if InCombatLockdown() then
		self.pending = true
		return
	end
	self.pending = false
	local picked = self:ScanBags()
	for _, b in ipairs(self.buttons) do
		local id = picked[b.cat]
		b.itemID = id
		b:SetAttribute("type", id and "item" or nil)
		b:SetAttribute("item", id and ("item:" .. id) or nil)
		-- bandages always on yourself, whatever you have targeted
		b:SetAttribute("unit", (id and b.cat == "bandage") and "player" or nil)
		b.icon:SetTexture(id and ItemIcon(id) or nil)
	end
	self:ScanWellFed()
	Place()
	local prof = ns.LayoutProfile and ns.LayoutProfile()
	local disabled = prof and prof.disabledElements and prof.disabledElements["Roth_UIBelt"]
	holder:SetShown(not disabled and Opt("show", true))
	self:Update()
end

Belt.Place = Place

function Belt.SetShown(shown)
	if not InCombatLockdown() then
		holder:SetShown(shown)
	end
end

-- Edit Mode integration
do
	local box = holder:CreateTexture(nil, "OVERLAY", nil, 7)
	box:SetPoint("TOPLEFT", -10, 10)
	box:SetPoint("BOTTOMRIGHT", 10, -10)
	box:SetColorTexture(0, 1, 0, 0.2)
	box:Hide()
	holder:SetMovable(true)
	holder:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	holder:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if ns.EditMode and ns.EditMode.SaveFramePosition then
			ns.EditMode:SaveFramePosition(self)
		end
		if ns.EditMode and ns.EditMode.UpdateDialog then
			ns.EditMode:UpdateDialog()
		end
	end)
	function Belt.SetEditing(on)
		box:SetShown(on)
		holder:EnableMouse(on)
		if on then
			holder:RegisterForDrag("LeftButton")
		else
			holder:RegisterForDrag()
		end
		for _, b in ipairs(Belt.buttons) do
			b:EnableMouse(not on)
		end
	end
end

local events = CreateFrame("Frame")
for _, e in ipairs({
	"PLAYER_ENTERING_WORLD",
	"BAG_UPDATE_DELAYED",
	"GET_ITEM_INFO_RECEIVED",
	"PLAYER_REGEN_ENABLED",
	"BAG_UPDATE_COOLDOWN",
	"UPDATE_BINDINGS",
	"PLAYER_REGEN_DISABLED",
}) do
	events:RegisterEvent(e)
end
events:RegisterUnitEvent("UNIT_AURA", "player")
local queued = false
events:SetScript("OnEvent", function(_, event)
	if event == "BAG_UPDATE_COOLDOWN" or event == "UPDATE_BINDINGS" then
		Belt:Update()
	elseif event == "UNIT_AURA" then
		Belt:ScanWellFed()
		Belt:UpdateFoodWarning()
	elseif event == "PLAYER_REGEN_DISABLED" then
		Belt:UpdateFoodWarning()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if Belt.pending then
			Belt:Refresh()
		end
		Belt:ScanWellFed()
		Belt:UpdateFoodWarning()
	elseif not queued then
		queued = true
		C_Timer.After(0.3, function()
			queued = false
			Belt:Refresh()
			Belt:Update()
		end)
	end
end)

_G["BINDING_HEADER_DIABOLUSUNITS"] = "DiabolusUnits"
for i = 1, #SLOTS do
	_G["BINDING_NAME_CLICK Roth_UIBelt" .. i .. ":LeftButton"] = "Belt " .. i
end

-- which item IDs give Well Fed (only those make the food flask pulse)
Belt.isBuffFood = {}
for _, id in ipairs(Data.FOOD_BUFF) do
	Belt.isBuffFood[id] = true
end

-- Well Fed runs out without an event; look again every 5 s
C_Timer.NewTicker(5, function()
	Belt:ScanWellFed()
	Belt:UpdateFoodWarning()
end)

