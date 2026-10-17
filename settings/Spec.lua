-- DiabolusUnits — settings/Spec.lua
--
-- What the settings window contains, as data: one build function per page returning a flat
-- array of row specs (kinds: header, text, checkbox, slider, dropdown, button, color — see
-- settings/Rows.lua). Pages are built the first time they are opened.
--
-- Sources:
--   * Orbs: the old orb panel's save/load/update functions (core/panel.lua, ns.panel), so
--     every orb setting keeps its Roth_UI_DB_CHAR key and live update. Its window is no
--     longer shown; its StaticPopup / UIDropDownMenu routes are not reached from here.
--   * Layout and belt: config.lua values through ns.Settings (settings/Settings.lua).
--   * Fonts and profiles: the AceDB profile (Roth_Config / RothFont).
--   * The edit layout itself stays in core/editmode.lua; the window only opens it.

local ADDON_NAME, ns = ...

local Panel = ns.UI.Panel
local Popup = Panel.Popup
local Settings = ns.Settings

local Spec = {}
Panel.Spec = Spec

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"

local function print_(msg)
	print("|cffdb9e47DiabolusUnits:|r " .. msg)
end

local function reloadButton(label)
	return {
		kind = "button",
		label = label or "Apply everything",
		buttonText = "Reload UI",
		tooltip = "Some changes (fonts, switching an integration off) only fully apply after a reload.",
		onClick = function()
			ReloadUI()
		end,
	}
end

-- ── cfg-backed rows ───────────────────────────────────────────────────────────

local function cfgCheckbox(path, label, tooltip, after)
	return {
		kind = "checkbox",
		label = label,
		tooltip = tooltip,
		get = function()
			return Settings.Get(path) and true or false
		end,
		set = function(value)
			Settings.Set(path, value)
			if after then
				after(value)
			end
		end,
	}
end

local function cfgSlider(path, label, tooltip, min, max, step, after)
	return {
		kind = "slider",
		label = label,
		tooltip = tooltip,
		min = min,
		max = max,
		step = step,
		get = function()
			return Settings.Get(path)
		end,
		set = function(value)
			Settings.Set(path, value)
			if after then
				after(value)
			end
		end,
	}
end

local function layout()
	Settings.QueueLayout()
end

-- ── Overview ──────────────────────────────────────────────────────────────────

function Spec.BuildOverviewPage()
	local rows = {}
	rows[#rows + 1] = {
		kind = "text",
		gap = 12,
		body = "Diablo-style orbs, unit frames and action bar art for WoW Forever.\n\n"
			.. "Everything you can set lives in this window. Moving and sizing frames is done "
			.. "in the |cffdb9e47edit layout|r, which opens on top of the game so you can drag "
			.. "frames where you want them.",
	}
	rows[#rows + 1] = {
		kind = "button",
		label = "Move and size frames",
		buttonText = "Open edit layout",
		tooltip = "Drag frames, scroll to resize, right-click to reset one frame. Also opens with Blizzard's Edit Mode.",
		onClick = function()
			if InCombatLockdown() then
				print_("the edit layout can't open in combat.")
				return
			end
			Panel.Close()
			if ns.EditMode and ns.EditMode.Toggle then
				ns.EditMode:Toggle()
			end
		end,
	}
	rows[#rows + 1] = {
		kind = "checkbox",
		label = "Minimap button",
		tooltip = "Left-click opens this window, right-click opens the edit layout. Account-wide.",
		get = function()
			return ns.UI.Minimap and ns.UI.Minimap:IsShownSetting()
		end,
		set = function(value)
			if ns.UI.Minimap then
				ns.UI.Minimap:SetShown(value)
			end
		end,
	}
	rows[#rows + 1] = { kind = "header", label = "Reset" }
	rows[#rows + 1] = {
		kind = "button",
		label = "Frame positions and sizes",
		buttonText = "Reset layout",
		tooltip = "Puts every frame back in its default place and size (the edit layout's Reset UI).",
		onClick = function()
			Popup.Confirm("Reset every frame's position and size to the default layout?", "Reset layout", function()
				if ns.EditMode and ns.EditMode.ResetAllToDefault then
					ns.EditMode:ResetAllToDefault()
				end
			end)
		end,
	}
	rows[#rows + 1] = {
		kind = "button",
		label = "Settings on the Layout and Belt pages",
		buttonText = "Reset settings",
		tooltip = "Returns the Layout and Belt pages to config.lua's defaults. Orbs, fonts and frame positions are not touched.",
		onClick = function()
			Popup.Confirm("Return the Layout and Belt settings to their defaults?", "Reset settings", function()
				Settings.ResetAll()
				layout()
				Panel.MarkDirty()
			end)
		end,
	}
	rows[#rows + 1] = reloadButton("Reload the interface")
	return rows
end

-- ── Layout ────────────────────────────────────────────────────────────────────

function Spec.BuildLayoutPage()
	local rows = {}
	local function sm()
		return Settings.Get("standardMode.enabled")
	end

	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = "Keyboard and mouse layout. With the gamepad interface on, the orbs sit around the "
			.. "native crossbar instead and these do not apply. A scale or position you set for a "
			.. "frame in the edit layout wins over the defaults here.",
	}
	rows[#rows + 1] = cfgCheckbox(
		"standardMode.enabled",
		"Diablo bottom layout",
		"Fit Blizzard's action bars into the stone bar and place orbs, statues, wings, belt and pet bar around it. Turning it off takes full effect after a reload.",
		layout
	)

	rows[#rows + 1] = { kind = "header", label = "Sizes" }
	local scaleRows = {
		{ "standardMode.standardBarScale", "Stone bar and buttons", "Size of the stone bar and the action buttons in it.", 1.0, 1.6, 0.01 },
		{ "standardMode.standardOrbScale", "Orbs", "Size of the health and power orbs.", 0.6, 1.2, 0.01 },
		{ "standardMode.standardStatueScale", "Demon and angel", "Size of the statues beside the orbs.", 0.6, 1.2, 0.01 },
		{ "standardMode.standardOrbX", "Orb distance", "How far each orb sits from the centre of the screen.", 260, 420, 1 },
	}
	for _, r in ipairs(scaleRows) do
		local row = cfgSlider(r[1], r[2], r[3], r[4], r[5], r[6], layout)
		row.child = true
		row.enabledWhen = sm
		rows[#rows + 1] = row
	end

	rows[#rows + 1] = { kind = "header", label = "What goes into the stone bar" }
	local integ = {
		{ "standardMode.integrateActionBars", "Action bars", "Fit action bars 1-3 into the stone slots." },
		{ "standardMode.integrateMicroMenu", "Game menu buttons", "Dock the micro menu on the left stone wing." },
		{ "standardMode.integrateBags", "Bag buttons", "Dock the bag bar on the right stone wing." },
		{ "standardMode.integratePetBar", "Pet bar", "Put the pet bar on top of the highest action bar row." },
	}
	for _, r in ipairs(integ) do
		local row = cfgCheckbox(r[1], r[2], r[3] .. " Switching off takes full effect after a reload.", layout)
		row.child = true
		row.enabledWhen = sm
		rows[#rows + 1] = row
	end
	rows[#rows + 1] = {
		kind = "slider",
		child = true,
		label = "Wing button fade",
		tooltip = "How visible the game menu and bag buttons are until you point at them.",
		min = 0.2,
		max = 1,
		step = 0.05,
		enabledWhen = sm,
		get = function()
			return Settings.Get("standardMode.dockFadeAlpha")
		end,
		set = function(value)
			Settings.Set("standardMode.dockFadeAlpha", value)
			layout()
		end,
	}

	rows[#rows + 1] = { kind = "header", label = "Interface scale" }
	rows[#rows + 1] = {
		kind = "checkbox",
		label = "Pixel-perfect UI scale",
		tooltip = "Sets the UI scale to 768 / screen height so the art is drawn 1:1. Off leaves Blizzard's UI scale alone (takes effect after a reload).",
		get = function()
			local prof = ns.LayoutProfile and ns.LayoutProfile()
			return not prof or prof.autoScale ~= false
		end,
		set = function(value)
			local prof = ns.LayoutProfile and ns.LayoutProfile()
			if prof then
				prof.autoScale = value and true or false
			end
			if value and ns.func and ns.func.ApplyPixelPerfectScale then
				ns.func.ApplyPixelPerfectScale()
			end
		end,
	}
	rows[#rows + 1] = reloadButton()
	return rows
end

-- ── Belt ──────────────────────────────────────────────────────────────────────

function Spec.BuildBeltPage()
	local rows = {}
	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = "Five flasks, the best of each from your bags: health potion, healthstone, mana potion "
			.. "(mana gem first for mages, rage potion for warriors, Thistle Tea for rogues), buff food "
			.. "and bandage. Bandages always go on yourself; inside a battleground its free draughts "
			.. "and bandages come first.\n\nThe food flask is for the Well Fed buff: its liquid shows how "
			.. "much of the buff is left and it pulses when the buff is missing or running low.\n\n"
			.. "Key bindings: Key Bindings > AddOns > DiabolusUnits.",
	}
	rows[#rows + 1] = cfgCheckbox("belt.show", "Show the potion belt", "Hide or show the belt.", function(value)
		if ns.Belt and ns.Belt.SetShown then
			ns.Belt.SetShown(value)
		end
	end)
	rows[#rows + 1] = cfgCheckbox(
		"belt.icons",
		"Item icons in the flasks",
		"Show the item's icon and cooldown swipe inside each flask. Off, the liquid colour tells them apart and still drains on cooldown.",
		function(value)
			for _, b in ipairs(ns.Belt and ns.Belt.buttons or {}) do
				b.icon:SetShown(value)
				b.cooldown:SetAlpha(value and 1 or 0)
			end
		end
	)
	rows[#rows + 1] = cfgSlider(
		"belt.foodWarnMinutes",
		"Warn when Well Fed has less than (minutes)",
		"The food flask pulses below this, and when the buff is gone, as long as you carry buff food.",
		1,
		30,
		1,
		function()
			if ns.Belt and ns.Belt.UpdateFoodWarning then
				ns.Belt:UpdateFoodWarning()
			end
		end
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Place the belt",
		tooltip = "Keyboard layout only; with a gamepad the belt sits beside the health orb. A position set in the edit layout wins.",
		options = function()
			return {
				{ value = "bags", label = "Above the bag wing" },
				{ value = "actionbar", label = "Above the action bars" },
			}
		end,
		get = function()
			return Settings.Get("standardMode.beltAnchor") or "bags"
		end,
		set = function(value)
			Settings.Set("standardMode.beltAnchor", value)
			layout()
		end,
	}
	return rows
end

-- ── Orbs ──────────────────────────────────────────────────────────────────────

local function orbList(list)
	local out = {}
	for _, item in ipairs(list or {}) do
		if item.menuList then
			for _, sub in ipairs(item.menuList) do
				out[#out + 1] = { value = sub.value, label = sub.key, category = item.key }
			end
		else
			out[#out + 1] = { value = item.value, label = item.key or tostring(item.value) }
		end
	end
	return out
end

-- Builds one orb page. `orb` is "Health" or "Power" (the old panel's function names),
-- `kind` is "HEALTH" or "POWER" (the db.char key).
local function buildOrbPage(orb, kind)
	local panel = ns.panel
	local db = ns.db
	local rows = {}
	if not panel or not db then
		rows[1] = { kind = "text", body = "Orb settings are not loaded." }
		return rows
	end

	local function fn(prefix, key)
		return panel[prefix .. orb .. "Orb" .. key]
	end
	local function value(key)
		local load = fn("load", key)
		return load and load()
	end
	local function write(key, ...)
		local save, update = fn("save", key), fn("update", key)
		if save then
			save(...)
		end
		if update then
			update()
		end
	end
	local function slider(key, label, tooltip, min, max, step, when)
		return {
			kind = "slider",
			child = true,
			label = label,
			tooltip = tooltip,
			min = min,
			max = max,
			step = step,
			enabledWhen = when,
			get = function()
				return value(key)
			end,
			set = function(v)
				write(key, v)
			end,
		}
	end
	local function check(key, label, tooltip, after)
		return {
			kind = "checkbox",
			child = true,
			label = label,
			tooltip = tooltip,
			get = function()
				return value(key) and true or false
			end,
			set = function(v)
				write(key, v)
				if after then
					after()
				end
			end,
		}
	end
	local function color(key, label, tooltip, when)
		return {
			kind = "color",
			child = true,
			label = label,
			tooltip = tooltip,
			enabledWhen = when,
			get = function()
				local c = value(key)
				if type(c) ~= "table" then
					return 1, 1, 1
				end
				return c.r, c.g, c.b
			end,
			set = function(r, g, b)
				write(key, r, g, b)
			end,
		}
	end
	local function dropdown(key, label, tooltip, list, when)
		return {
			kind = "dropdown",
			child = true,
			label = label,
			tooltip = tooltip,
			enabledWhen = when,
			options = function()
				return orbList(list())
			end,
			get = function()
				return value(key)
			end,
			set = function(v)
				write(key, v)
			end,
		}
	end
	local function autoColorOff()
		return not value("FillingColorAuto")
	end
	local function modelOn()
		return value("ModelEnable") and true or false
	end

	rows[#rows + 1] = { kind = "header", label = "Liquid" }
	rows[#rows + 1] = dropdown("FillingTexture", "Texture", "The liquid inside the orb.", db.getListFillingTexture)
	rows[#rows + 1] = check(
		"FillingColorAuto",
		"Colour by class / power type",
		"Health takes your class colour, power takes the colour of your power type (mana, rage, energy).",
		function()
			-- the auto colour overwrites the manual one; re-apply the manual one when switched off
			local update = fn("update", "FillingColor")
			if update and autoColorOff() then
				update()
			end
		end
	)
	rows[#rows + 1] = color("FillingColor", "Liquid colour", "Used when colouring by class / power type is off.", autoColorOff)

	rows[#rows + 1] = { kind = "header", label = "Effects" }
	rows[#rows + 1] = slider("GalaxiesAlpha", "Swirls", "The slow swirling layer.", 0, 1, 0.01)
	rows[#rows + 1] = slider("BubblesAlpha", "Bubbles", "Rising bubbles in the liquid.", 0, 1, 0.01)
	rows[#rows + 1] = slider("SparkAlpha", "Surface spark", "The bright line on the liquid's surface.", 0, 1, 0.01)
	rows[#rows + 1] = slider("HighlightAlpha", "Glass shine", "The reflection on the orb's glass.", 0, 1, 0.01)

	rows[#rows + 1] = { kind = "header", label = "3D model" }
	rows[#rows + 1] = check("ModelEnable", "Show a 3D model in the orb", "An animated model drawn inside the liquid.")
	rows[#rows + 1] = dropdown("ModelAnimation", "Model", "Which model to show.", db.getListModel, modelOn)
	rows[#rows + 1] = slider("ModelAlpha", "Opacity", nil, 0, 1, 0.01, modelOn)
	rows[#rows + 1] = slider("ModelScale", "Camera distance", nil, 0.1, 6, 0.01, modelOn)
	rows[#rows + 1] = slider("ModelPosX", "Horizontal position", nil, -5, 5, 0.01, modelOn)
	rows[#rows + 1] = slider("ModelPosY", "Vertical position", nil, -5, 5, 0.01, modelOn)
	rows[#rows + 1] = slider("ModelRotation", "Rotation", nil, -4, 4, 0.01, modelOn)
	rows[#rows + 1] = slider("ModelZoom", "Portrait zoom", nil, 0, 1, 0.01, modelOn)

	rows[#rows + 1] = { kind = "header", label = "Numbers" }
	rows[#rows + 1] = dropdown("ValueTopTag", "Top line", "What the large number shows.", db.getListTag)
	rows[#rows + 1] = color("ValueTopColor", "Top line colour")
	rows[#rows + 1] = dropdown("ValueBottomTag", "Bottom line", "What the small number shows.", db.getListTag)
	rows[#rows + 1] = color("ValueBottomColor", "Bottom line colour")
	rows[#rows + 1] = slider("ValueAlpha", "Opacity", nil, 0, 1, 0.01)
	rows[#rows + 1] = check("ValueHideEmpty", "Hide when empty", "No numbers while the orb is empty.")
	rows[#rows + 1] = check("ValueHideFull", "Hide when full", "No numbers while the orb is full.")

	rows[#rows + 1] = { kind = "header", label = "Templates" }
	rows[#rows + 1] = {
		kind = "text",
		gap = 6,
		font = "GameFontDisableSmall",
		body = "A template is a saved orb look, shared by all your characters and both orbs.",
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Load a template",
		placeholder = "Choose...",
		tooltip = "Copies the template's look onto this orb.",
		options = function()
			local out = {}
			for _, t in ipairs(db.getListTemplate() or {}) do
				out[#out + 1] = { value = t.value, label = t.key }
			end
			return out
		end,
		get = function()
			return nil
		end,
		set = function(name)
			db.loadTemplate(name, kind)
			Panel.MarkDirty()
		end,
	}
	rows[#rows + 1] = {
		kind = "button",
		label = "Save this orb's look",
		buttonText = "Save as template",
		onClick = function()
			Popup.Prompt("Name for the template (letters and digits):", "", "Save", function(text)
				text = (text or ""):gsub("%s", "")
				if text == "" or text:match("%W") then
					print_("template names can only use letters and digits.")
					return
				end
				db.saveTemplate(text, kind)
			end)
		end,
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Delete a template",
		placeholder = "Choose...",
		tooltip = "Removes a saved template for all characters.",
		options = function()
			local out = {}
			for _, t in ipairs(db.getListTemplate() or {}) do
				out[#out + 1] = { value = t.value, label = t.key }
			end
			return out
		end,
		get = function()
			return nil
		end,
		set = function(name)
			Popup.Confirm(('Delete the template "%s"?'):format(name), "Delete", function()
				db.deleteTemplate(name)
				Panel.MarkDirty()
			end)
		end,
	}
	rows[#rows + 1] = {
		kind = "button",
		label = "Back to the default look",
		buttonText = "Reset orb",
		onClick = function()
			Popup.Confirm(("Reset the %s orb to its default look?"):format(orb:lower()), "Reset orb", function()
				db.loadCharacterDataDefaults(kind)
				Panel.MarkDirty()
			end)
		end,
	}
	return rows
end

function Spec.BuildHealthOrbPage()
	return buildOrbPage("Health", "HEALTH")
end

function Spec.BuildPowerOrbPage()
	return buildOrbPage("Power", "POWER")
end

-- ── Fonts ─────────────────────────────────────────────────────────────────────

function Spec.BuildFontsPage()
	local rows = {}
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	local function prof()
		return ns.configDB and ns.configDB.profile
	end
	local function fontOptions()
		local out = {}
		for _, name in ipairs(LSM and LSM:List("font") or {}) do
			out[#out + 1] = { value = name, label = name }
		end
		return out
	end
	local function fontRow(key, label, tooltip)
		return {
			kind = "dropdown",
			label = label,
			tooltip = tooltip .. " Applies after a reload.",
			options = fontOptions,
			get = function()
				return prof() and prof()[key]
			end,
			set = function(v)
				if prof() then
					prof()[key] = v
				end
			end,
		}
	end
	local function scaleRow(key, label)
		return {
			kind = "slider",
			child = true,
			label = label,
			tooltip = "Relative to the game's default size. Applies after a reload.",
			min = 0.5,
			max = 2,
			step = 0.05,
			get = function()
				return prof() and prof()[key] or 1
			end,
			set = function(v)
				if prof() then
					prof()[key] = v
				end
			end,
		}
	end
	rows[#rows + 1] = fontRow("headerFont", "Header font", "Large text: names, titles, headers.")
	rows[#rows + 1] = scaleRow("headerScale", "Header size")
	rows[#rows + 1] = fontRow("textFont", "Text font", "Detail text: quest text, cooldowns, class strings.")
	rows[#rows + 1] = scaleRow("textScale", "Text size")
	rows[#rows + 1] = fontRow("chatFont", "Chat font", "Chat windows.")
	rows[#rows + 1] = scaleRow("chatScale", "Chat size")
	rows[#rows + 1] = reloadButton("Apply font changes")
	return rows
end

-- ── Profiles ──────────────────────────────────────────────────────────────────

function Spec.BuildProfilesPage()
	local rows = {}
	local function adb()
		return ns.configDB
	end
	local function names(exceptCurrent)
		local out = {}
		local db = adb()
		if not db then
			return out
		end
		local current = db:GetCurrentProfile()
		for _, name in ipairs(db:GetProfiles({}) or {}) do
			if not (exceptCurrent and name == current) then
				out[#out + 1] = { value = name, label = name }
			end
		end
		table.sort(out, function(a, b)
			return a.label < b.label
		end)
		return out
	end

	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = "A profile holds the edit layout (frame positions and sizes), the Layout and Belt "
			.. "pages and the fonts. Orb looks are per character; templates share them. "
			.. "Switching profile reloads the interface.",
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Profile in use",
		options = function()
			return names(false)
		end,
		get = function()
			return adb() and adb():GetCurrentProfile()
		end,
		set = function(name)
			if adb() and name ~= adb():GetCurrentProfile() then
				adb():SetProfile(name)
			end
		end,
	}
	rows[#rows + 1] = {
		kind = "button",
		label = "Start a new profile",
		buttonText = "New profile",
		tooltip = "Creates an empty profile with the defaults and switches to it.",
		onClick = function()
			Popup.Prompt("Name for the new profile:", "", "Create", function(text)
				text = strtrim(text or "")
				if text ~= "" and adb() then
					adb():SetProfile(text)
				end
			end)
		end,
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Copy settings from",
		placeholder = "Choose...",
		tooltip = "Overwrites the profile in use with a copy of another profile.",
		options = function()
			return names(true)
		end,
		get = function()
			return nil
		end,
		set = function(name)
			Popup.Confirm(('Overwrite the profile in use with "%s"?'):format(name), "Copy", function()
				if adb() then
					adb():CopyProfile(name)
					ReloadUI()
				end
			end)
		end,
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Delete a profile",
		placeholder = "Choose...",
		options = function()
			return names(true)
		end,
		get = function()
			return nil
		end,
		set = function(name)
			Popup.Confirm(('Delete the profile "%s"?'):format(name), "Delete", function()
				if adb() then
					adb():DeleteProfile(name)
					Panel.MarkDirty()
				end
			end)
		end,
	}
	rows[#rows + 1] = {
		kind = "button",
		label = "Profile in use back to defaults",
		buttonText = "Reset profile",
		onClick = function()
			Popup.Confirm("Reset the profile in use to the defaults? This also resets the edit layout.", "Reset profile", function()
				if adb() then
					adb():ResetProfile()
					ReloadUI()
				end
			end)
		end,
	}
	return rows
end

-- ── Help ──────────────────────────────────────────────────────────────────────

function Spec.BuildHelpPage()
	return {
		{ kind = "header", label = "Commands" },
		{
			kind = "text",
			gap = 10,
			body = "|cffdb9e47/diabolus|r  open this window  (|cffdb9e47/roth|r works too)\n"
				.. "|cffdb9e47/diabolus edit|r  open the edit layout\n"
				.. "|cffdb9e47/diabolus resetall|r  reset every frame to the default layout\n"
				.. "|cffdb9e47/diabolus autoscale on|off|r  pixel-perfect UI scale\n"
				.. "|cffdb9e47/diabolus food|r  list your buffs (checks Well Fed detection)\n"
				.. "|cffdb9e47/diabolus taint|r, |cffdb9e47/diabolus auras|r  diagnostics",
		},
		{ kind = "header", label = "Gamepad" },
		{
			kind = "text",
			gap = 10,
			body = "D-pad moves, A selects, B goes back, LB / RB switch pages, LT / RT scroll, "
				.. "Back closes. The window closes when combat starts.",
		},
		{ kind = "header", label = "Credits" },
		{
			kind = "text",
			gap = 10,
			body = "|cffdb9e47zork|r — Roth UI and the Diablo orbs (2008-2016)\n"
				.. "|cffdb9e47Galaxy|r — maintainer (2012-2018)\n"
				.. "|cffdb9e47EchoZulu69er|r — TBC Anniversary edition (2025)\n"
				.. "|cffdb9e47codingdoctorbot|r — DiabolusUnits for WoW Forever (2026), with Claude and Gemini\n\n"
				.. "oUF by Haste, rLib by zork, Diabolic UI art by Goldpaw, Ace3, LibSharedMedia. "
				.. "Settings window from PulseHaptics. Full list in CREDITS.md.",
		},
	}
end

-- ── Page list ─────────────────────────────────────────────────────────────────

function Spec.BuildPages()
	return {
		{ id = "overview", label = "DiabolusUnits", icon = MEDIA .. "d2_skull", build = Spec.BuildOverviewPage },
		{ id = "layout", label = "Layout", indent = 1, icon = "Interface\\Icons\\INV_Misc_Gear_01", build = Spec.BuildLayoutPage },
		{ id = "health", label = "Health orb", indent = 1, icon = "Interface\\Icons\\INV_Potion_54", build = Spec.BuildHealthOrbPage },
		{ id = "power", label = "Power orb", indent = 1, icon = "Interface\\Icons\\INV_Potion_76", build = Spec.BuildPowerOrbPage },
		{ id = "belt", label = "Potion belt", indent = 1, icon = "Interface\\Icons\\INV_Belt_03", build = Spec.BuildBeltPage },
		{ id = "fonts", label = "Fonts", indent = 1, icon = "Interface\\Icons\\INV_Misc_Note_01", build = Spec.BuildFontsPage },
		{ id = "profiles", label = "Profiles", indent = 1, icon = "Interface\\Icons\\INV_Misc_Book_09", build = Spec.BuildProfilesPage },
		{ id = "help", label = "Help", indent = 1, icon = "Interface\\Icons\\INV_Misc_QuestionMark", build = Spec.BuildHelpPage },
	}
end
