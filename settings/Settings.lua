-- DiabolusUnits — settings/Settings.lua
--
-- The store behind the settings window for values that live in config.lua's `cfg`
-- tables (cfg.standardMode, cfg.belt, ...). config.lua stays the source of defaults; a
-- value changed in the window is written into `cfg` (so the code reading it sees it at
-- once) and saved as an override in the AceDB profile, `profile.settings["path.key"]`.
-- Overrides are put back into `cfg` at ADDON_LOADED, before any layout runs, and follow
-- profile switches (which reload the UI).
--
-- Orb settings keep their own per-character store (core/db.lua, Roth_UI_DB_CHAR); fonts
-- and the edit layout keep theirs in the same AceDB profile.

local ADDON_NAME, ns = ...

local Settings = {}
ns.Settings = Settings

local cfg = ns.cfg

local function profile()
	local adb = ns.configDB
	return adb and adb.profile
end

local function overrides(create)
	local prof = profile()
	if not prof then
		return nil
	end
	if create and type(prof.settings) ~= "table" then
		prof.settings = {}
	end
	return prof.settings
end

-- "standardMode.standardBarScale" -> cfg.standardMode, "standardBarScale"
local function resolve(path)
	local tbl, key = cfg, nil
	for part in string.gmatch(path, "[^%.]+") do
		if key then
			tbl = tbl[key]
			if type(tbl) ~= "table" then
				return nil
			end
		end
		key = part
	end
	return tbl, key
end

local defaults = {}

-- config.lua's value, remembered the first time a path is touched
local function default(path)
	if defaults[path] == nil then
		local tbl, key = resolve(path)
		local v = tbl and tbl[key]
		defaults[path] = (v == nil) and false or v
	end
	return defaults[path]
end

function Settings.Get(path)
	local tbl, key = resolve(path)
	return tbl and tbl[key]
end

function Settings.Default(path)
	return default(path)
end

function Settings.Set(path, value)
	local tbl, key = resolve(path)
	if not tbl then
		return
	end
	default(path)
	tbl[key] = value
	local saved = overrides(true)
	if saved then
		if value == defaults[path] then
			saved[path] = nil
		else
			saved[path] = value
		end
	end
end

function Settings.ResetAll()
	local saved = overrides(false)
	if not saved then
		return
	end
	for path in pairs(saved) do
		local tbl, key = resolve(path)
		if tbl then
			tbl[key] = default(path)
		end
		saved[path] = nil
	end
end

-- Layout changes are coalesced into one StandardMode:Apply on the next frame (sliders
-- fire many times per drag). Apply itself waits for the end of combat.
local applyQueued = false
function Settings.QueueLayout()
	if applyQueued then
		return
	end
	applyQueued = true
	C_Timer.After(0, function()
		applyQueued = false
		if ns.StandardMode and ns.StandardMode.Apply then
			ns.StandardMode:Apply()
		end
	end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
	if name ~= ADDON_NAME then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")
	local saved = overrides(false)
	if not saved then
		return
	end
	for path, value in pairs(saved) do
		local tbl, key = resolve(path)
		if tbl then
			default(path)
			tbl[key] = value
		end
	end
end)
