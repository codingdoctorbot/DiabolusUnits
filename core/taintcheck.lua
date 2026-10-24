-- Read-only Blizzard-state diagnostics: /roth taint and /roth auras.
-- Reports use issecurevariable and are saved in DiabolusForeverDB_GLOB.taintReport/auraProbe
-- under the account's SavedVariables/DiabolusUnits.lua.

local _, ns = ...

local Check = {}
ns.TaintCheck = Check

local function Say(msg)
	print("|c00FF3300Roth_UI:|r " .. msg)
end

local function Store(key, lines)
	if type(DiabolusForeverDB_GLOB) == "table" then
		DiabolusForeverDB_GLOB[key] = { time = date("%Y-%m-%d %H:%M:%S"), lines = lines }
	end
end

-- Blizzard objects on the paths that failed in the client (buff timers,
-- loot / popup freeze, raid frames, Edit Mode, tooltips).
local WATCHED = {
	"EditModeManagerFrame",
	"BuffFrame",
	"DebuffFrame",
	"PlayerFrame",
	"TargetFrame",
	"GameTooltip",
	"StaticPopup1",
	"LootFrame",
	"GamepadMainActionBarFrame",
	"SmartNavigation",
	"UIParentBottomManagedFrameContainer",
	"UIParentRightManagedFrameContainer",
	"MinimapCluster",
	"ChatFrame1",
	"PlayerCastingBarFrame",
	"MainStatusTrackingBarContainer",
	"CompactRaidFrameContainer",
	"CompactPartyFrame",
	"PartyFrame",
	"DamageMeter",
}

-- Our own globals (frames, saved variables, slash and binding strings).
local function Ours(name)
	return name:find("^Roth") ~= nil
		or name:find("^r[A-Z]") ~= nil
		or name:find("^SLASH_") ~= nil
		or name:find("^BINDING_") ~= nil
		or name:find("^ShinyBuffs") ~= nil
		or name:find("^PhanxFont") ~= nil
		or name:find("^riS_") ~= nil
		or name:find("^AceGUI") ~= nil
		or name:find("^LibStub") ~= nil
end

function Check:Run()
	local secure = rawget(_G, "issecurevariable")
	if not secure then
		Say("issecurevariable is not available on this client.")
		return
	end
	local lines = {}
	local function add(s)
		lines[#lines + 1] = s
	end

	-- 1. refusals since login
	local TF = ns.TaintFix
	add(
		("blocked/forbidden since login: %d%s"):format(
			TF and TF.count or 0,
			TF and TF.guarding and " (popup guard on)" or ""
		)
	)
	for i, e in ipairs(TF and TF.recent or {}) do
		if i > 8 then
			break
		end
		add(
			("  %s %s %s %s"):format(
				e.time,
				e.addon,
				e.event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked",
				e.func
			)
		)
	end

	-- 2. tainted fields on the watched Blizzard objects
	for _, name in ipairs(WATCHED) do
		local t = rawget(_G, name)
		if type(t) == "table" then
			local bad = {}
			for k in pairs(t) do
				if type(k) == "string" then
					local ok, isSecure, by = pcall(secure, t, k)
					if ok and not isSecure then
						bad[#bad + 1] = k .. (by and by ~= "" and (" (" .. by .. ")") or "")
					end
				end
			end
			if #bad > 0 then
				table.sort(bad)
				add(("%s: %d tainted field(s): %s"):format(name, #bad, table.concat(bad, ", ", 1, math.min(#bad, 12))))
			end
		end
	end

	-- 3. globals written by add-on code that are not ours
	local foreign = {}
	for k in pairs(_G) do
		if type(k) == "string" and not Ours(k) then
			local ok, isSecure, by = pcall(secure, k)
			if ok and not isSecure then
				foreign[#foreign + 1] = k .. (by and by ~= "" and (" (" .. by .. ")") or "")
			end
		end
	end
	table.sort(foreign)
	add(("globals written by add-ons (not Roth's own names): %d"):format(#foreign))
	for i = 1, math.min(#foreign, 40) do
		add("  " .. foreign[i])
	end

	Say("taint report (also saved as DiabolusForeverDB_GLOB.taintReport):")
	for _, line in ipairs(lines) do
		print("  " .. line)
	end
	Store("taintReport", lines)
end

-- /roth auras: what the aura API hands add-on code for the target right now
local FIELDS =
	{ "name", "icon", "applications", "duration", "expirationTime", "auraInstanceID", "sourceUnit", "dispelName" }

local function IsSecret(v)
	local f = rawget(_G, "issecretvalue")
	return f ~= nil and f(v) == true
end

function Check:ProbeAuras(unit)
	unit = unit or "target"
	local lines = {}
	local function add(s)
		lines[#lines + 1] = s
	end
	local secretsOn = C_Secrets and C_Secrets.ShouldAurasBeSecret and select(2, pcall(C_Secrets.ShouldAurasBeSecret))
	add(
		("unit %s, exists %s, in combat %s, ShouldAurasBeSecret %s"):format(
			unit,
			tostring(UnitExists(unit)),
			tostring(InCombatLockdown()),
			tostring(secretsOn)
		)
	)
	for _, filter in ipairs({ "HARMFUL|INCLUDE_NAME_PLATE_ONLY", "HARMFUL", "HELPFUL" }) do
		local n, secretFields, errors = 0, {}, {}
		for i = 1, 40 do
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
			if not ok then
				errors[#errors + 1] = tostring(aura)
				break
			end
			if aura == nil then
				break
			end
			n = n + 1
			if IsSecret(aura) then
				secretFields["(whole table)"] = true
			else
				for _, f in ipairs(FIELDS) do
					if IsSecret(aura[f]) then
						secretFields[f] = true
					end
				end
			end
		end
		local list = {}
		for f in pairs(secretFields) do
			list[#list + 1] = f
		end
		table.sort(list)
		local okIDs, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, filter)
		local idText
		if not okIDs then
			idText = "refused: " .. tostring(ids)
		elseif type(ids) ~= "table" or IsSecret(ids) then
			idText = IsSecret(ids) and "secret" or "none"
		else
			idText = #ids .. " id(s)"
		end
		add(
			("%s: GetAuraDataByIndex %d aura(s); secret: %s; GetUnitAuraInstanceIDs %s%s"):format(
				filter,
				n,
				#list > 0 and table.concat(list, ", ") or "none",
				idText,
				#errors > 0 and ("; error: " .. errors[1]) or ""
			)
		)
	end
	local frame = rawget(_G, "Roth_UITargetFrame")
	if frame then
		local NA = ns.NativeAuras
		add(
			("Roth target frame: client-drawn rows, %s debuff and %s buff button(s) in use"):format(
				tostring(NA.Count(frame, "Debuffs")),
				tostring(NA.Count(frame, "Buffs"))
			)
		)
	end
	Say("aura probe (also saved as DiabolusForeverDB_GLOB.auraProbe):")
	for _, line in ipairs(lines) do
		print("  " .. line)
	end
	Store("auraProbe", lines)
end
