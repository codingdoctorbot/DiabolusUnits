---------------------------------------------
--  DiabolusForever - ring content
---------------------------------------------
-- Automatically populates the radial rings (core/ring.lua) from bags and spellbook:
--   consume  best health potion, healthstone, best mana potion / gem,
--            bandage, food, drink, then elixirs, flasks, scrolls, oils
--   utility  class utility spells you know, hearthstone, other usable items
--   quest    usable quest items (kept current as bags change)
--   spells   player class spells

local addon, ns = ...

local Ring = ns.Ring
local Secrets = ns.Secrets

if not Ring or not Ring.ring then
	return
end

local Content = {}
ns.RingContent = Content

local MAX = 12
local HEARTHSTONE = 6948
local CONSUMABLE = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
local QUESTITEM = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12
local SUB = (Enum and Enum.ItemConsumableSubclass) or {}
local POTION, ELIXIR, FLASK, SCROLL = SUB.Potion or 1, SUB.Elixir or 2, SUB.Flasksphials or 3, SUB.Scroll or 4
local FOOD, ENHANCE, BANDAGE = SUB.Fooddrink or 5, SUB.Itemenhancement or 6, SUB.Bandage or 7

local MANA_GEMS = { "mana agate", "mana jade", "mana citrine", "mana ruby", "mana emerald" }

local CLASS_SPELLS = {
	HUNTER = { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah", "Aspect of the Pack", "Aspect of the Wild", "Aspect of the Beast", "Track Beasts", "Track Humanoids", "Track Undead", "Track Hidden", "Call Pet", "Revive Pet", "Feed Pet", "Mend Pet" },
	WARLOCK = { "Summon Imp", "Summon Voidwalker", "Summon Succubus", "Summon Felhunter", "Create Healthstone", "Create Soulstone", "Ritual of Summoning", "Demon Armor", "Demon Skin", "Unending Breath", "Detect Invisibility", "Eye of Kilrogg" },
	SHAMAN = { "Ghost Wolf", "Water Walking", "Water Breathing", "Astral Recall", "Far Sight", "Ancestral Spirit", "Strength of Earth Totem", "Stoneskin Totem", "Tremor Totem", "Healing Stream Totem", "Mana Spring Totem", "Windfury Totem", "Grace of Air Totem", "Grounding Totem" },
	DRUID = { "Bear Form", "Dire Bear Form", "Cat Form", "Travel Form", "Aquatic Form", "Moonkin Form", "Mark of the Wild", "Thorns", "Rebirth", "Innervate", "Teleport: Moonglade", "Remove Curse" },
	PALADIN = { "Seal of Righteousness", "Seal of the Crusader", "Seal of Command", "Seal of Wisdom", "Seal of Light", "Devotion Aura", "Retribution Aura", "Concentration Aura", "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Redemption", "Summon Warhorse", "Summon Charger" },
	MAGE = { "Arcane Intellect", "Frost Armor", "Ice Armor", "Mage Armor", "Conjure Water", "Conjure Food", "Conjure Mana Agate", "Slow Fall", "Teleport: Stormwind", "Teleport: Ironforge", "Teleport: Darnassus", "Teleport: Orgrimmar", "Teleport: Undercity", "Teleport: Thunder Bluff" },
	PRIEST = { "Power Word: Fortitude", "Divine Spirit", "Shadow Protection", "Inner Fire", "Fear Ward", "Shadowform", "Levitate", "Resurrection", "Mind Vision", "Dispel Magic", "Cure Disease" },
	ROGUE = { "Stealth", "Sprint", "Evasion", "Vanish", "Pick Lock", "Detect Traps", "Disarm Trap", "Distract", "Pick Pocket" },
	WARRIOR = { "Battle Stance", "Defensive Stance", "Berserker Stance", "Battle Shout", "Demoralizing Shout", "Challenging Shout", "Intimidating Shout", "Berserker Rage" },
}

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

function Content.Classify(itemID, name, classID, subclassID, equipLoc, spell, quest)
	local lower = (name or ""):lower()
	local spellLower = (spell or ""):lower()
	if quest and (quest.questID or quest.isQuestItem) and (spell or quest.questID) then
		return "quest", "quest"
	end
	if classID == QUESTITEM and spell then
		return "quest", "quest"
	end
	if itemID == HEARTHSTONE or lower:find("hearthstone", 1, true) then
		return "utility", "hearth"
	end
	if classID == CONSUMABLE then
		if lower:find("healthstone", 1, true) then
			return "consume", "healthstone"
		elseif HasAny(lower, MANA_GEMS) then
			return "consume", "mana"
		elseif subclassID == POTION then
			if spellLower:find("mana", 1, true) or lower:find("mana", 1, true) then
				return "consume", "mana"
			elseif spellLower:find("heal", 1, true) or lower:find("heal", 1, true) or spell == nil then
				return "consume", "health"
			end
			return "consume", "potion"
		elseif subclassID == BANDAGE or lower:find("bandage", 1, true) then
			return "consume", "bandage"
		elseif subclassID == FOOD then
			if spellLower:find("drink", 1, true) or lower:find("water", 1, true) or lower:find("milk", 1, true) or lower:find("juice", 1, true) then
				return "consume", "drink"
			end
			return "consume", "food"
		elseif subclassID == ELIXIR or subclassID == FLASK then
			return "consume", "elixir"
		elseif subclassID == SCROLL then
			return "consume", "scroll"
		elseif subclassID == ENHANCE then
			return "consume", "enhance"
		elseif spell then
			return "utility", "other"
		end
		return nil
	end
	if spell and (equipLoc == nil or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE") then
		return "utility", "other"
	end
	return nil
end

local CONSUME_BEST = { "health", "healthstone", "mana", "bandage", "food", "drink" }
local CONSUME_LISTS = { "potion", "elixir", "scroll", "enhance" }
local SHORT = {
	health = "Health",
	healthstone = "Stone",
	mana = "Mana",
	bandage = "Bandage",
	food = "Food",
	drink = "Drink",
	hearth = "Hearth",
}

function Content:ScanBags()
	local best, lists, seen = {}, {}, {}
	self.missingInfo = false
	local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = 0, lastBag do
		local numSlots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
		for slot = 1, numSlots do
			local info = (C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)) or (GetContainerItemInfo and GetContainerItemInfo(bag, slot))
			local itemID = info and info.itemID
			if itemID and not seen[itemID] then
				seen[itemID] = true
				local _, _, _, equipLoc, icon, classID, subclassID = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(itemID)
				local name, _, _, itemLevel = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(itemID)
				if not name then
					self.missingInfo = true
				end
				local quest = C_Container and C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
				local spell = ItemSpellName(itemID)
				local ring, cat = Content.Classify(itemID, name, classID, subclassID, equipLoc, spell, quest)
				if ring then
					local entry = {
						kind = "item",
						value = "item:" .. itemID,
						itemID = itemID,
						name = name or ("item " .. itemID),
						icon = icon or (info and info.iconFileID),
						short = SHORT[cat] or "",
						level = (Secrets and Secrets.Number and Secrets.Number(itemLevel)) or (type(itemLevel) == "number" and itemLevel) or 0,
					}
					local key = ring .. ":" .. cat
					local current = best[key]
					if not current or entry.level > current.level then
						best[key] = entry
					end
					lists[key] = lists[key] or {}
					table.insert(lists[key], entry)
				end
			end
		end
	end
	return best, lists
end

local function KnownSpells()
	local known = {}
	local book = C_SpellBook
	if book and book.GetNumSpellBookSkillLines then
		local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
		for line = 1, (tonumber(book.GetNumSpellBookSkillLines()) or 0) do
			local info = book.GetSpellBookSkillLineInfo(line)
			if type(info) == "table" then
				local first = (info.itemIndexOffset or 0) + 1
				local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
				for index = first, last do
					local ok, name = pcall(book.GetSpellBookItemName, index, bank)
					if ok and type(name) == "string" then
						known[name:lower()] = name
					end
				end
			end
		end
	end
	return known
end

local function SpellIcon(name)
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, icon = pcall(C_Spell.GetSpellTexture, name)
		if ok and icon then
			return icon
		end
	end
	return GetSpellTexture and GetSpellTexture(name)
end

local function Shorten(name)
	return (name:gsub("^Aspect of the ", ""):gsub("^Summon ", ""):gsub("^Seal of the ", ""):gsub("^Seal of ", ""):gsub(" Totem$", ""):gsub("^Teleport: ", ""))
end

Content.KnownSpells = KnownSpells
Content.SpellIcon = SpellIcon
Content.Shorten = Shorten

function Content:ClassSpells()
	local _, class = UnitClass("player")
	local list, out = CLASS_SPELLS[class], {}
	if not list then
		return out
	end
	local known = KnownSpells()
	for _, spell in ipairs(list) do
		local name = known[spell:lower()]
		if name then
			out[#out + 1] = { kind = "spell", value = name, name = name, short = Shorten(name), icon = SpellIcon(name) }
		end
	end
	return out
end

local function Append(out, entries)
	for _, e in ipairs(entries or {}) do
		if #out >= MAX then
			return
		end
		out[#out + 1] = e
	end
end

function Content:Build()
	local best, lists = self:ScanBags()

	local consume = {}
	for _, cat in ipairs(CONSUME_BEST) do
		if best["consume:" .. cat] and #consume < MAX then
			consume[#consume + 1] = best["consume:" .. cat]
		end
	end
	for _, cat in ipairs(CONSUME_LISTS) do
		Append(consume, lists["consume:" .. cat])
	end

	local utility = {}
	Append(utility, self:ClassSpells())
	local items = {}
	Append(items, lists["utility:hearth"])
	Append(items, lists["utility:other"])
	local room = math.max(MAX - #utility, math.min(2, #items))
	while #utility > MAX - room do
		table.remove(utility)
	end
	Append(utility, items)

	local quest = {}
	Append(quest, lists["quest:quest"])

	local spells = {}
	Append(spells, self:ClassSpells())

	return { consume = consume, utility = utility, quest = quest, spells = spells }
end

local HINTS = {
	consume = "put potions, food, drink, bandages or elixirs in your bags",
	utility = "no class utility spell or usable item found",
	quest = "no usable quest items in your bags",
	spells = "no class spells found in your spellbook",
}

function Content:Refresh()
	if InCombatLockdown() then
		self.pending = true
		return
	end
	self.pending = false
	local rings = self:Build()
	for kind, entries in pairs(rings) do
		Ring:Define(kind, entries, HINTS[kind])
	end
end

local queued = false
local function Queue(delay)
	if queued then
		return
	end
	queued = true
	C_Timer.After(delay or 0.5, function()
		queued = false
		Content:Refresh()
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if Content.pending then
			Queue(0.2)
		end
		return
	end
	if event == "GET_ITEM_INFO_RECEIVED" and not Content.missingInfo then
		return
	end
	Queue(event == "SPELLS_CHANGED" and 1 or 0.5)
end)
