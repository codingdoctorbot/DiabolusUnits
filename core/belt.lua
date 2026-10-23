-- Potion belt: health, healthstone, class resource, food, bandage, and optional drink.
-- core/beltdata.lua ranks known items; unknown items use the bag-scan fallback.
-- Secure button assignments change only out of combat; counts and cooldowns update live.
-- Food warnings retain the last readable Well Fed state while auras are restricted.

local _, ns = ...

local cfg = ns.cfg
local Secrets = ns.Secrets
local Data = ns.BeltData

local Belt = {}
ns.Belt = Belt

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"
local SLOTS = { "health", "healthstone", "mana", "food", "bandage", "drink" }
local SIZE, GAP = 34, 8
local LIQUID = {
	health = { 0.85, 0.08, 0.05 },
	healthstone = { 0.3, 0.85, 0.2 },
	mana = { 0.15, 0.4, 1 },
	rage = { 0.95, 0.35, 0.08 },
	energy = { 0.95, 0.8, 0.15 },
	food = { 0.85, 0.55, 0.15 },
	bandage = { 0.85, 0.78, 0.6 },
	drink = { 0.25, 0.65, 0.95 },
}

local CONSUMABLE = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
local SUB = (Enum and Enum.ItemConsumableSubclass) or {}
local POTION, BANDAGE = SUB.Potion or 1, SUB.Bandage or 7
local MANA_GEMS = { "mana agate", "mana jade", "mana citrine", "mana ruby", "mana emerald" }

local _, playerClass = UnitClass("player")
-- what the third socket holds for this class
local THIRD = (playerClass == "WARRIOR" and "rage") or (playerClass == "ROGUE" and "energy") or "mana"

local function Opt(key, default)
	local b = cfg.belt
	if b and b[key] ~= nil then
		return b[key]
	end
	return default
end

local LABELS = {
	"Health potion",
	"Healthstone",
	THIRD == "rage" and "Rage potion" or THIRD == "energy" and "Thistle Tea" or "Mana / gem",
	"Food",
	"Bandage",
	"Drink",
}
local PLACEHOLDER = {
	health = "Interface\\Icons\\INV_Potion_54",
	healthstone = "Interface\\Icons\\INV_Stone_04",
	mana = "Interface\\Icons\\INV_Potion_76",
	rage = "Interface\\Icons\\INV_Potion_24",
	energy = "Interface\\Icons\\INV_Drink_Milk_05",
	food = "Interface\\Icons\\INV_Misc_Food_14",
	bandage = "Interface\\Icons\\INV_Misc_Bandage_12",
	drink = "Interface\\Icons\\INV_Drink_07",
}
Belt.labels = LABELS

local function Active(cat)
	return cat ~= "drink" or Opt("showDrink", false)
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

local function Num(v)
	if Secrets then
		return Secrets.Number(v)
	end
	return type(v) == "number" and v or nil
end

local function Count(itemID)
	local n = C_Item.GetItemCount(itemID, false, false)
	return Num(n) or 0
end

-- The client remains authoritative for food and bandage skill requirements.
-- Potions use their known level requirement: IsUsableItem also rejects a potion
-- when its resource is full, which must not remove it from the socket.
local LEVEL_GATED = { food = true, bandage = true, drink = true }
local AUTO_STAT = {
	WARRIOR = "str",
	ROGUE = "agi",
	HUNTER = "agi",
	MAGE = "int",
	WARLOCK = "int",
	PRIEST = "spi",
	PALADIN = "sta",
	DRUID = "sta",
	SHAMAN = "sta",
}
Belt.powerType = THIRD

local function BattlegroundContext()
	local inside, kind = IsInInstance()
	if not inside or kind ~= "pvp" then
		return false
	end
	local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	-- A flag room or other interior can have its own map. Bound the parent walk.
	for _ = 1, 12 do
		if not map or map == 0 then
			break
		end
		if Data.BG_CODES[map] then
			return true, Data.BG_CODES[map]
		end
		local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
		local parent = info and info.parentMapID
		if parent == map then
			break
		end
		map = parent
	end
	return true
end

function Belt:RebuildOrder(only)
	self.order = self.order or {}
	local bg, code = BattlegroundContext()
	local stat = Opt("foodStat", "auto")
	if stat == "auto" then
		stat = AUTO_STAT[playerClass]
	end
	local options = {
		class = playerClass,
		inBattleground = bg,
		bgCode = code,
		faction = UnitFactionGroup("player"),
		includeRejuvenation = Opt("includeRejuvenation", true),
		buffFoodFirst = Opt("buffFoodFirst", true),
		preferredStat = stat,
		wellFed = self.wellFed,
	}
	for _, cat in ipairs(SLOTS) do
		if not only or only == cat then
			self.order[cat] = Data.BuildOrder(cat, options)
		end
	end
end

function Belt:PolicyChanged()
	self:RebuildOrder()
	self:Refresh()
end

local function Resolve(cat)
	local level = UnitLevel("player")
	for _, id in ipairs(Belt.order[cat]) do
		local row = Data.ITEMS[id]
		if Count(id) > 0 and (not level or level <= 0 or (row.minLevel or 0) <= level) then
			if not LEVEL_GATED[cat] or not C_Item.IsUsableItem then
				return id
			end
			local ok, usable = pcall(C_Item.IsUsableItem, id)
			if ok and usable ~= false then
				return id
			end
		end
	end
end

-- Fallback scan for categories the ranked lists left empty
local function ScanUnlisted(want)
	local best, seen = {}, {}
	local lastBag = rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS") or rawget(_G, "NUM_BAG_SLOTS") or 4
	for bag = 0, lastBag do
		for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local itemID = info and info.itemID
			if itemID and not Data.ITEMS[itemID] and not seen[itemID] then
				seen[itemID] = true
				local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
				local name, _, _, itemLevel, minLevel = C_Item.GetItemInfo(itemID)
				local cat = ClassifyBeltItem(name, classID, subclassID, ItemSpellName(itemID))
				local level = UnitLevel("player")
				local usable = true
				if cat and LEVEL_GATED[cat] and C_Item.IsUsableItem then
					local ok, value = pcall(C_Item.IsUsableItem, itemID)
					usable = ok and value ~= false
				end
				if cat and want[cat] and usable and (not minLevel or not level or minLevel <= level) then
					local lvl = Num(itemLevel) or 0
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
	if not self.order then
		self:RebuildOrder()
	end
	local picked, missing = {}, {}
	for _, cat in ipairs(SLOTS) do
		picked[cat] = Active(cat) and Resolve(cat) or nil
		if
			Active(cat)
			and not picked[cat]
			and cat ~= "food"
			and cat ~= "drink"
			and not (cat == "mana" and THIRD ~= "mana")
		then
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

-- Well Fed
-- Detect Well Fed by icon, with an English-name fallback. Read only unrestricted auras;
-- retain the last state otherwise. /diabolus food prints a diagnostic list.
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
			local duration = Num(aura.duration)
			local expires = Num(aura.expirationTime)
			found = { duration = duration or 0, expires = expires or 0 }
			break
		end
	end
	local changed = (self.wellFed == false) ~= (found == false) or self.wellFed == nil
	self.wellFed = found
	if changed and self.order then
		self:RebuildOrder("food")
	end
	return changed
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
		print(
			("  %s  %s  %s%s"):format(
				tostring(aura.name),
				tostring(aura.spellId),
				tostring(aura.icon),
				IsWellFed(aura) and "  <- Well Fed" or ""
			)
		)
	end
end

local holder = CreateFrame("Frame", "Roth_UIBelt", UIParent)
holder:SetSize(5 * SIZE + 4 * GAP, SIZE)
holder:SetFrameStrata("MEDIUM")
holder:SetClampedToScreen(true)
holder:SetClampRectInsets(-44, 44, 0, 0)
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

	-- Let the active layout own default placement; bag updates must preserve it.
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

-- Round item socket with count, binding, cooldown, and stock-coloured rim.
local ART = SIZE * 2.25 -- socket art is 128 px with a 64 px ring: ring ~38 px across
local ICON = SIZE - 6
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

for i, cat in ipairs(SLOTS) do
	local b = CreateFrame("Button", "Roth_UIBelt" .. i, holder, "SecureActionButtonTemplate")
	b:SetSize(SIZE, SIZE)
	b:SetPoint("LEFT", holder, "LEFT", (i - 1) * (SIZE + GAP), 0)
	b:RegisterForClicks("AnyDown")
	b:SetAttribute("useOnKeyDown", true)
	b.cat = cat
	b.liquidKey = (cat == "mana") and THIRD or cat

	local socket = b:CreateTexture(nil, "BACKGROUND", nil, -8)
	socket:SetTexture(MEDIA .. "combo_orb_bg")
	socket:SetPoint("CENTER")
	socket:SetSize(ART, ART)

	local mask = b:CreateMaskTexture()
	mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetPoint("CENTER")
	mask:SetSize(ICON, ICON)

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	icon:SetSize(ICON, ICON)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:AddMaskTexture(mask)
	b.icon = icon

	local over = CreateFrame("Frame", nil, b)
	over:SetAllPoints(b)
	over:SetFrameLevel(b:GetFrameLevel() + 2)

	local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	cd:SetPoint("CENTER")
	cd:SetSize(ICON, ICON)
	cd:SetSwipeTexture(MASK)
	cd:SetSwipeColor(0, 0, 0, 0.75)
	cd:SetUseCircularEdge(true)
	cd:SetDrawEdge(false)
	cd:SetHideCountdownNumbers(true)
	cd:SetFrameLevel(b:GetFrameLevel() + 1)
	b.cooldown = cd

	-- rim in the slot's colour, under the metal ring
	local rim = over:CreateTexture(nil, "OVERLAY", nil, -3)
	rim:SetTexture(MEDIA .. "combo_orb_glow")
	rim:SetPoint("CENTER")
	rim:SetSize(ART, ART)
	rim:SetBlendMode("ADD")
	local c = LIQUID[b.liquidKey]
	rim:SetVertexColor(c[1], c[2], c[3])
	rim:SetAlpha(0.55)
	b.rim = rim

	local ring = over:CreateTexture(nil, "OVERLAY", nil, -2)
	ring:SetTexture(MEDIA .. "combo_orb_border")
	ring:SetPoint("CENTER")
	ring:SetSize(ART, ART)

	local gloss = over:CreateTexture(nil, "OVERLAY", nil, -1)
	gloss:SetTexture(MEDIA .. "combo_orb_highlight")
	gloss:SetPoint("CENTER")
	gloss:SetSize(ART, ART)
	gloss:SetBlendMode("ADD")
	gloss:SetAlpha(0.35)

	local count = over:CreateFontString(nil, "OVERLAY")
	count:SetFont(cfg.font, 12, "THINOUTLINE")
	count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
	count:SetTextColor(1, 0.9, 0.7)
	b.count = count

	local key = over:CreateFontString(nil, "OVERLAY")
	key:SetFont(cfg.font, 10, "THINOUTLINE")
	key:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
	key:SetTextColor(0.7, 0.6, 0.5)
	b.key = key

	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(MEDIA .. "combo_orb_glow")
	hl:SetPoint("CENTER")
	hl:SetSize(ART, ART)
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0.6)

	if cat == "food" then
		-- the rim pulses while Well Fed is missing or running out and you carry buff food
		local pulse = rim:CreateAnimationGroup()
		pulse:SetLooping("BOUNCE")
		local fade = pulse:CreateAnimation("Alpha")
		fade:SetFromAlpha(0.25)
		fade:SetToAlpha(1)
		fade:SetDuration(0.8)
		fade:SetSmoothing("IN_OUT")
		b.warnPulse = pulse
	end

	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if self.itemID then
			GameTooltip:SetItemByID(self.itemID)
		else
			GameTooltip:AddLine(LABELS[i])
			GameTooltip:AddLine("No usable item in your bags", 0.7, 0.7, 0.7)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	Belt.buttons[i] = b
end

-- Empty sockets keep a dim, desaturated placeholder icon and no stock rim.
local function ShowStock(b)
	local have = (b.have or 0) > 0
	b.icon:SetDesaturated(not have)
	b.icon:SetAlpha(have and 1 or 0.22)
	if not (b.warnPulse and b.warnPulse:IsPlaying()) then
		b.rim:SetAlpha(have and 0.55 or 0)
	end
end

function Belt:Update()
	for _, b in ipairs(self.buttons) do
		local id = b.itemID
		if id then
			local n = Num(C_Item.GetItemCount(id, false, true)) or 0
			b.have = n
			b.count:SetText(n > 1 and n or "")
			if b.cat ~= "food" then
				local start, duration, enable = C_Container.GetItemCooldown(id)
				start, duration, enable = Num(start), Num(duration), Num(enable)
				if enable and enable ~= 0 and start and duration and duration > 0 then
					b.cooldown:SetCooldown(start, duration)
				else
					b.cooldown:Clear()
				end
			end
		else
			b.have = 0
			b.count:SetText("")
			b.cooldown:Clear()
		end
		ShowStock(b)
		local bound = GetBindingKey("CLICK " .. b:GetName() .. ":LeftButton")
		b.key:SetText(bound and GetBindingText(bound, true) or "")
	end
	self:UpdateFoodWarning()
end

-- Food swipe shows remaining Well Fed time; the rim warns when missing/low.
-- Buff state is refreshed only out of combat.
function Belt:UpdateFoodWarning()
	for _, b in ipairs(self.buttons) do
		if b.cat == "food" then
			local wf = self.wellFed
			if wf and wf.duration and wf.duration > 0 and wf.expires and wf.expires > 0 then
				b.cooldown:SetReverse(true)
				b.cooldown:SetCooldown(wf.expires - wf.duration, wf.duration)
			else
				b.cooldown:SetReverse(false)
				b.cooldown:Clear()
			end
			local _, low = WellFedState(GetTime())
			local buffFood = b.itemID and self.isBuffFood and self.isBuffFood[b.itemID]
			local warn = low and buffFood and (b.have or 0) > 0 and not InCombatLockdown()
			if warn and not b.warnPulse:IsPlaying() then
				b.warnPulse:Play()
			elseif not warn and b.warnPulse:IsPlaying() then
				b.warnPulse:Stop()
			end
			ShowStock(b)
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

-- Exact single-socket macro format is the ownership boundary. Modified user macros
-- and account macros are never rewritten. Creation happens only on an explicit click.
local GetNumMacros = rawget(_G, "GetNumMacros")
local MACRO_NAMES = { "DU Health", "DU Stone", "DU Power", "DU Food", "DU Bandage", "DU Drink" }
local function MacroLimits()
	local constants = rawget(_G, "Constants")
	return constants and constants.MacroConsts
end
local function MacroText(index)
	local b = Belt.buttons[index]
	local tooltip = b.itemID and ("#showtooltip item:" .. b.itemID) or "#showtooltip"
	local stop = Opt("macroStopCasting", false) and "/stopcasting\n" or ""
	return tooltip .. "\n#DU:Belt:" .. index .. "\n" .. stop .. "/click " .. b:GetName() .. " LeftButton 1"
end
local function OwnedMacro(index, text)
	if type(text) ~= "string" then
		return false
	end
	local rest = text:match("^#showtooltip item:%d+\n(.*)$") or text:match("^#showtooltip\n(.*)$")
	if not rest then
		return false
	end
	local click = "/click " .. Belt.buttons[index]:GetName() .. " LeftButton 1"
	return rest == "#DU:Belt:" .. index .. "\n" .. click or rest == "#DU:Belt:" .. index .. "\n/stopcasting\n" .. click
end
local function FindMacro(index)
	local limits = MacroLimits()
	if not (limits and GetNumMacros and GetMacroInfo) then
		return nil
	end
	local _, count = GetNumMacros()
	for offset = 1, count do
		local id = limits.MAX_ACCOUNT_MACROS + offset
		local name, icon, body = GetMacroInfo(id)
		if name == MACRO_NAMES[index] then
			return id, icon, body
		end
	end
end
function Belt:UpdateMacros()
	if InCombatLockdown() then
		return
	end
	for index, button in ipairs(self.buttons) do
		local id, oldIcon, body = FindMacro(index)
		if id and OwnedMacro(index, body) then
			local text = MacroText(index)
			local icon = button.itemID and ItemIcon(button.itemID) or PLACEHOLDER[button.liquidKey]
			if body ~= text or oldIcon ~= icon then
				EditMacro(id, nil, icon, text)
			end
		end
	end
end
function Belt:PickupMacro(index)
	if InCombatLockdown() then
		return false, "Leave combat before creating or picking up a belt macro."
	end
	if not self.buttons[index] then
		return false, "Unknown belt socket."
	end
	if not Active(self.buttons[index].cat) then
		return false, "Enable the drink socket first."
	end
	if GetCursorInfo() then
		return false, "Place or clear the item already on your cursor first."
	end
	local limits = MacroLimits()
	if not (limits and CreateMacro and PickupMacro and GetNumMacros and GetMacroInfo and EditMacro) then
		return false, "Macro controls are unavailable on this client."
	end
	local id, _, body = FindMacro(index)
	if id and not OwnedMacro(index, body) then
		return false,
			"A character macro named '"
				.. MACRO_NAMES[index]
				.. "' already exists with custom text. Rename it to keep both."
	end
	if not id then
		local _, count = GetNumMacros()
		if count >= limits.MAX_CHARACTER_MACROS then
			return false, "Your character macro slots are full."
		end
		local button = self.buttons[index]
		local icon = button.itemID and ItemIcon(button.itemID) or PLACEHOLDER[button.liquidKey]
		local ok, result = pcall(CreateMacro, MACRO_NAMES[index], icon, MacroText(index), true)
		if not ok or type(result) ~= "number" or result <= limits.MAX_ACCOUNT_MACROS then
			return false, "The client could not create this character macro."
		end
		id = result
	end
	self:UpdateMacros()
	PickupMacro(id)
	return true, "Place " .. MACRO_NAMES[index] .. " on an action bar, or find it under Character Macros."
end

function Belt:Refresh()
	if InCombatLockdown() then
		self.pending = true
		return
	end
	self.pending = false
	self:ScanWellFed()
	local visible = Opt("showDrink", false) and 6 or 5
	holder:SetSize(visible * SIZE + (visible - 1) * GAP, SIZE)
	local picked = self:ScanBags()
	for _, b in ipairs(self.buttons) do
		b:SetShown(Active(b.cat))
		local id = picked[b.cat]
		b.itemID = id
		b:SetAttribute("type", id and "item" or nil)
		b:SetAttribute("item", id and ("item:" .. id) or nil)
		-- bandages always on yourself, whatever you have targeted
		b:SetAttribute("unit", (id and b.cat == "bandage") and "player" or nil)
		b.icon:SetTexture(id and ItemIcon(id) or PLACEHOLDER[b.liquidKey])
	end
	self:UpdateMacros()
	Place()
	local prof = ns.LayoutProfile and ns.LayoutProfile()
	local disabled = prof and prof.disabledElements and prof.disabledElements["Roth_UIBelt"]
	holder:SetShown(not disabled and Opt("show", true))
	self:Update()
end

function Belt.Debug()
	local bg, code = BattlegroundContext()
	print(
		("DiabolusUnits belt: %s; BG %s; Well Fed %s; pending %s"):format(
			playerClass,
			bg and (code or "unknown") or "none",
			Belt.wellFed == nil and "unknown" or (Belt.wellFed and "active" or "missing"),
			tostring(Belt.pending or false)
		)
	)
	for _, button in ipairs(Belt.buttons) do
		local id = button.itemID
		local row = id and Data.ITEMS[id]
		print(
			("  %s: %s (%s), carried %d"):format(
				button.cat,
				row and row.name or "empty/unlisted",
				id or "-",
				id and Count(id) or 0
			)
		)
	end
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
	"ZONE_CHANGED_NEW_AREA",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"PLAYER_LEVEL_UP",
	"SKILL_LINES_CHANGED",
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
		if Belt:ScanWellFed() then
			Belt:Refresh()
		end
		Belt:UpdateFoodWarning()
	elseif event == "PLAYER_REGEN_DISABLED" then
		Belt:UpdateFoodWarning()
	elseif event == "PLAYER_REGEN_ENABLED" then
		local changed = Belt:ScanWellFed()
		if Belt.pending or changed then
			Belt:Refresh()
		end
		Belt:UpdateFoodWarning()
	else
		if event == "PLAYER_ENTERING_WORLD" or event:find("ZONE_CHANGED", 1, true) then
			Belt.order = nil
		end
		if queued then
			return
		end
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
	_G["BINDING_NAME_CLICK Roth_UIBelt" .. i .. ":LeftButton"] = "Belt " .. i .. " — " .. LABELS[i]
end

-- which item IDs give Well Fed (only those make the food socket pulse)
Belt.isBuffFood = {}
for id, item in pairs(Data.ITEMS) do
	if item.type == "food" and (item.foodRank or 0) > 0 then
		Belt.isBuffFood[id] = true
	end
end

-- Well Fed runs out without an event; look again every 5 s
C_Timer.NewTicker(5, function()
	if Belt:ScanWellFed() then
		Belt:Refresh()
	end
	Belt:UpdateFoodWarning()
end)
