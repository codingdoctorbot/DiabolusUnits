-- DiabolusUnits: deterministic belt policy built from the consumable facts database.
-- No item order is copied here. Rebuild only when policy/zone changes; bag scans read lists.
local _, ns = ...
local DB = ns.ConsumableDB
local Data = { ITEMS = DB.items, BG_CODES = { [1459] = 1, [1460] = 2, [1461] = 3 }, BG_ONLY = {} }
ns.BeltData = Data
local normal, anyBG, specific = {}, {}, {}
local validTypes = {
	health = true,
	mana = true,
	healthstone = true,
	bandage = true,
	food = true,
	drink = true,
	managem = true,
	rage = true,
	energy = true,
	utility = true,
}
local function number(value)
	return type(value) == "number" and value or -math.huge
end
local function compareField(a, b, key)
	local av, bv = number(a[key]), number(b[key])
	if av ~= bv then
		return av > bv
	end
end
local function restoreOrder(a, b, resource)
	local result = compareField(a, b, resource .. "Percent")
	if result ~= nil then
		return result
	end
	return compareField(a, b, resource)
end
local function buffAmount(row)
	local highest = 0
	for _, amount in pairs(row.stats or {}) do
		highest = math.max(highest, amount)
	end
	return highest
end
local function comparator(kind, preferredStat)
	return function(aid, bid)
		local a, b = Data.ITEMS[aid], Data.ITEMS[bid]
		local result
		if kind == "foodBuff" then
			if preferredStat then
				local am = (a.stats and (a.stats[preferredStat] or 0) > 0) or false
				local bm = (b.stats and (b.stats[preferredStat] or 0) > 0) or false
				if am ~= bm then
					return am
				end
			end
			result = compareField(a, b, "foodRank")
			if result ~= nil then
				return result
			end
			local aa, ba = buffAmount(a), buffAmount(b)
			if aa ~= ba then
				return aa > ba
			end
		end
		if kind == "mana" or kind == "drink" or kind == "managem" then
			result = restoreOrder(a, b, "mana")
			if result ~= nil then
				return result
			end
			result = restoreOrder(a, b, "health")
		elseif kind == "rage" or kind == "energy" then
			result = compareField(a, b, "power")
		else
			result = restoreOrder(a, b, "health")
			if result ~= nil then
				return result
			end
			result = restoreOrder(a, b, "mana")
		end
		if result ~= nil then
			return result
		end
		return aid < bid
	end
end
local function foodGroup(row)
	if row.conjured then
		return "foodConjured"
	end
	if row.holiday then
		return "foodHoliday"
	end
	if (row.foodRank or 0) > 0 then
		return "foodBuff"
	end
	return "food"
end
function Data.Validate()
	local errors = {}
	for id, row in pairs(Data.ITEMS) do
		if type(id) ~= "number" or id <= 0 or id % 1 ~= 0 then
			errors[#errors + 1] = "invalid item ID"
		end
		if not validTypes[row.type] then
			errors[#errors + 1] = "unknown type: " .. tostring(id)
		end
		if row.bg ~= -1 and (type(row.bg) ~= "number" or row.bg < 0 or row.bg % 1 ~= 0) then
			errors[#errors + 1] = "invalid battleground: " .. id
		end
		for _, key in ipairs({ "health", "mana", "power", "healthPercent", "manaPercent", "firstAid", "minLevel" }) do
			if row[key] ~= nil and (type(row[key]) ~= "number" or row[key] < 0) then
				errors[#errors + 1] = "invalid " .. key .. ": " .. id
			end
		end
		if
			(row.type == "health" or row.type == "healthstone" or row.type == "bandage")
			and row.health == nil
			and row.healthPercent == nil
		then
			errors[#errors + 1] = "missing health: " .. id
		end
		if
			(row.type == "mana" or row.type == "managem" or row.type == "drink")
			and row.mana == nil
			and row.manaPercent == nil
		then
			errors[#errors + 1] = "missing mana: " .. id
		end
	end
	return errors
end
local errors = Data.Validate()
assert(#errors == 0, table.concat(errors, "; "))
for id, row in pairs(Data.ITEMS) do
	if row.type ~= "utility" then
		local kind = row.type == "food" and foodGroup(row) or row.type
		local target
		if row.bg == -1 then
			target = anyBG
		elseif row.bg > 0 then
			specific[row.bg] = specific[row.bg] or {}
			target = specific[row.bg]
		else
			target = normal
		end
		target[kind] = target[kind] or {}
		target[kind][#target[kind] + 1] = id
	end
end
local function sortBuckets(buckets)
	for kind, list in pairs(buckets) do
		table.sort(list, comparator(kind))
	end
end
sortBuckets(normal)
sortBuckets(anyBG)
for _, buckets in pairs(specific) do
	sortBuckets(buckets)
end
local function list(bucket, kind)
	return bucket[kind] or {}
end
local function append(target, values, faction, includeRejuvenation)
	for _, id in ipairs(values or {}) do
		local row = Data.ITEMS[id]
		if
			(not faction or not row.faction or row.faction == faction)
			and (includeRejuvenation ~= false or not row.rejuvenation)
		then
			target[#target + 1] = id
		end
	end
end
local exports = {
	HEALTH = "health",
	MANA = "mana",
	HEALTHSTONE = "healthstone",
	BANDAGE = "bandage",
	MANA_GEM = "managem",
	RAGE = "rage",
	ENERGY = "energy",
	FOOD_CONJURED = "foodConjured",
	FOOD_HOLIDAY = "foodHoliday",
	FOOD_BUFF = "foodBuff",
	FOOD_PLAIN = "food",
}
for name, kind in pairs(exports) do
	Data[name] = list(normal, kind)
end
Data.HEALTH_BG = list(anyBG, "health")
Data.MANA_BG = list(anyBG, "mana")
Data.BG_ONLY = specific
Data.FOOD = {}
append(Data.FOOD, Data.FOOD_CONJURED)
append(Data.FOOD, Data.FOOD_HOLIDAY)
append(Data.FOOD, Data.FOOD_PLAIN)
Data.DRINK = {}
local conjuredWater, ordinaryWater = {}, {}
for _, id in ipairs(list(normal, "drink")) do
	local target = Data.ITEMS[id].conjured and conjuredWater or ordinaryWater
	target[#target + 1] = id
end
append(Data.DRINK, conjuredWater)
append(Data.DRINK, ordinaryWater)
-- Compatibility for the current five-button belt. These are derived aliases, not a second database.
Data.MAP_AV, Data.MAP_WSG, Data.MAP_AB = 1459, 1460, 1461
Data.BANDAGE_AV = list(specific[1] or {}, "bandage")
Data.BANDAGE_WSG = list(specific[2] or {}, "bandage")
Data.BANDAGE_AB_ALLIANCE = {}
Data.BANDAGE_AB_HORDE = {}
append(Data.BANDAGE_AB_ALLIANCE, list(specific[3] or {}, "bandage"), "Alliance")
append(Data.BANDAGE_AB_HORDE, list(specific[3] or {}, "bandage"), "Horde")
-- Pure zone/option policy for the next belt refactor; never touches secure button attributes.
function Data.BuildOrder(kind, options)
	options = options or {}
	local result = {}
	if kind == "mana" and options.class == "WARRIOR" then
		append(result, Data.RAGE)
		return result
	end
	if kind == "mana" and options.class == "ROGUE" then
		append(result, Data.ENERGY)
		return result
	end
	if kind == "mana" and options.class == "MAGE" then
		append(result, Data.MANA_GEM)
	end
	if kind == "food" then
		local buffs = {}
		append(buffs, Data.FOOD_BUFF)
		if options.preferredStat then
			table.sort(buffs, comparator("foodBuff", options.preferredStat))
		end
		local first = options.buffFoodFirst == true and options.wellFed == false
		if first then
			append(result, buffs)
		end
		append(result, Data.FOOD)
		if not first then
			append(result, buffs)
		end
		return result
	end
	if kind == "drink" then
		append(result, Data.DRINK)
		return result
	end
	if options.inBattleground then
		append(result, list(specific[options.bgCode] or {}, kind), options.faction, options.includeRejuvenation)
		append(result, list(anyBG, kind), options.faction, options.includeRejuvenation)
	end
	append(result, list(normal, kind), options.faction, options.includeRejuvenation)
	return result
end
