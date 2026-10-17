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

local _, ns = ...

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
		{
			"standardMode.standardBarScale",
			"Stone bar and buttons",
			"Size of the stone bar and the action buttons in it.",
			1.0,
			1.6,
			0.01,
		},
		{ "standardMode.standardOrbScale", "Orbs", "Size of the health and power orbs.", 0.6, 1.2, 0.01 },
		{
			"standardMode.standardStatueScale",
			"Demon and angel",
			"Size of the statues beside the orbs.",
			0.6,
			1.2,
			0.01,
		},
		{
			"standardMode.standardOrbX",
			"Orb distance",
			"How far each orb sits from the centre of the screen.",
			260,
			420,
			1,
		},
	}
	for _, r in ipairs(scaleRows) do
		local row = cfgSlider(r[1], r[2], r[3], r[4], r[5], r[6], layout)
		row.child = true
		row.enabledWhen = sm
		rows[#rows + 1] = row
	end

	rows[#rows + 1] = {
		kind = "dropdown",
		child = true,
		label = "Pet bar",
		tooltip = "Where the pet bar sits over the highest action bar row. Centred keeps it clear of a chat box at the bottom left.",
		enabledWhen = sm,
		options = function()
			return ns.StandardMode.PET_BAR_ANCHORS
		end,
		get = function()
			return Settings.Get("standardMode.petBarAnchor") or "center"
		end,
		set = function(value)
			Settings.Set("standardMode.petBarAnchor", value)
			layout()
		end,
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		child = true,
		label = "Pet frame",
		tooltip = "Where the pet's portrait goes. Above the power orb is clear of chat and the quest tracker. Above the health orb sits by your own orb but under a chat box at the bottom left. Beside the pet bar keeps it next to the pet's buttons: on the left it can reach under a chat box at the bottom left, on the right it can meet the cast bar. A position set in the edit layout wins.",
		enabledWhen = sm,
		options = function()
			return ns.StandardMode.PET_FRAME_ANCHORS
		end,
		get = function()
			return Settings.Get("standardMode.petFrameAnchor") or "healthOrb"
		end,
		set = function(value)
			Settings.Set("standardMode.petFrameAnchor", value)
			-- picking an anchor puts the frame there, even if it was dragged before
			local prof = ns.LayoutProfile and ns.LayoutProfile()
			if prof and prof.framePositions then
				prof.framePositions["Roth_UIPetFrame"] = nil
			end
			layout()
		end,
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		child = true,
		label = "Target frame",
		tooltip = "Where the target frame sits. Above the power orb places it opposite the pet frame over the health orb. Top of the screen restores the classic position. A position set in the edit layout wins.",
		enabledWhen = sm,
		options = function()
			return ns.StandardMode.TARGET_FRAME_ANCHORS
		end,
		get = function()
			return Settings.Get("standardMode.targetFrameAnchor") or "powerOrb"
		end,
		set = function(value)
			Settings.Set("standardMode.targetFrameAnchor", value)
			local prof = ns.LayoutProfile and ns.LayoutProfile()
			if prof and prof.framePositions then
				prof.framePositions["Roth_UITargetFrame"] = nil
			end
			layout()
		end,
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		child = true,
		label = "Target of target",
		tooltip = "Where the target of target frame is anchored relative to the target frame. Top-right sits over the right side of the target frame. A position set in the edit layout wins.",
		enabledWhen = sm,
		options = function()
			return ns.StandardMode.TARGETTARGET_FRAME_ANCHORS
		end,
		get = function()
			return Settings.Get("standardMode.targetTargetFrameAnchor") or "topright"
		end,
		set = function(value)
			Settings.Set("standardMode.targetTargetFrameAnchor", value)
			local prof = ns.LayoutProfile and ns.LayoutProfile()
			if prof and prof.framePositions then
				prof.framePositions["Roth_UITargetTargetFrame"] = nil
			end
			layout()
		end,
	}

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
	rows[#rows + 1] = {
		kind = "slider",
		child = true,
		label = "Left wing distance",
		tooltip = "Distance of the game menu wing outward from the demon statue.",
		min = 180,
		max = 350,
		step = 5,
		enabledWhen = sm,
		get = function()
			return Settings.Get("standardMode.microDockOffset")
		end,
		set = function(value)
			Settings.Set("standardMode.microDockOffset", value)
			layout()
		end,
	}
	rows[#rows + 1] = {
		kind = "slider",
		child = true,
		label = "Right wing distance",
		tooltip = "Distance of the bag bar wing outward from the angel statue.",
		min = 180,
		max = 350,
		step = 5,
		enabledWhen = sm,
		get = function()
			return Settings.Get("standardMode.bagDockOffset")
		end,
		set = function(value)
			Settings.Set("standardMode.bagDockOffset", value)
			layout()
		end,
	}

	rows[#rows + 1] = { kind = "header", label = "Tooltip" }
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Tooltip position",
		tooltip = "Where tooltips appear. Each spot is clear of the orbs, wings, belt and pet frame. Following the mouse works with keyboard and mouse only.",
		options = function()
			return {
				{ value = "bottomright", label = "Bottom right, above the belt" },
				{ value = "bottomleft", label = "Bottom left, above the game menu" },
				{ value = "center", label = "Above the action bars" },
				{ value = "cursor", label = "Follow the mouse" },
			}
		end,
		get = function()
			return Settings.Get("rtooltip.anchor") or "bottomright"
		end,
		set = function(value)
			Settings.Set("rtooltip.anchor", value)
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
		body = "Five sockets, the best of each from your bags: health potion, healthstone, mana potion "
			.. "(mana gem first for mages, rage potion for warriors, Thistle Tea for rogues), buff food "
			.. "and bandage. Bandages always go on yourself; inside a battleground its free draughts "
			.. "and bandages come first. An empty socket goes dark.\n\nThe food socket is for the Well Fed "
			.. "buff: its swipe shows how much of the buff is left and its rim pulses when the buff is "
			.. "missing or running low.\n\n"
			.. "Key bindings: Key Bindings > AddOns > DiabolusUnits.",
	}
	rows[#rows + 1] = cfgCheckbox("belt.show", "Show the potion belt", "Hide or show the belt.", function(value)
		if ns.Belt and ns.Belt.SetShown then
			ns.Belt.SetShown(value)
		end
	end)
	rows[#rows + 1] = cfgSlider(
		"belt.foodWarnMinutes",
		"Warn when Well Fed has less than (minutes)",
		"The food socket's rim pulses below this, and when the buff is gone, as long as you carry buff food.",
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
	rows[#rows + 1] =
		color("FillingColor", "Liquid colour", "Used when colouring by class / power type is off.", autoColorOff)

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
			Popup.Confirm(
				"Reset the profile in use to the defaults? This also resets the edit layout.",
				"Reset profile",
				function()
					if adb() then
						adb():ResetProfile()
						ReloadUI()
					end
				end
			)
		end,
	}
	return rows
end

-- ── Unit Frames ───────────────────────────────────────────────────────────────

-- ── Unit Frames Subtab Helpers ──────────────────────────────────────────────

local function refreshTarget()
	if ns.func and ns.func.refreshTargetFrame then
		ns.func.refreshTargetFrame()
	end
end
local function refreshFocus()
	if ns.func and ns.func.refreshFocusFrame then
		ns.func.refreshFocusFrame()
	end
end
local function refreshTargetTarget()
	if ns.func and ns.func.refreshTargetTargetFrame then
		ns.func.refreshTargetTargetFrame()
	end
end
local function refreshFocusTarget()
	if ns.func and ns.func.refreshFocusTargetFrame then
		ns.func.refreshFocusTargetFrame()
	end
end
local function refreshPet()
	if ns.func and ns.func.refreshPetFrame then
		ns.func.refreshPetFrame()
	end
end
local function refreshPetTarget()
	if ns.func and ns.func.refreshPetTargetFrame then
		ns.func.refreshPetTargetFrame()
	end
end
local function refreshParty()
	if ns.Group and ns.Group.RefreshHealthTags then
		ns.Group.RefreshHealthTags("party")
	end
	if ns.Group and ns.Group.RefreshRangeAlpha then
		ns.Group.RefreshRangeAlpha("party")
	end
	if ns.Group and ns.Group.RefreshScale then
		ns.Group.RefreshScale("party")
	end
end
local function refreshRaid()
	if ns.Group and ns.Group.RefreshHealthTags then
		ns.Group.RefreshHealthTags("raid")
	end
	if ns.Group and ns.Group.RefreshRangeAlpha then
		ns.Group.RefreshRangeAlpha("raid")
	end
	if ns.Group and ns.Group.RefreshScale then
		ns.Group.RefreshScale("raid")
	end
end

-- ── Target Subtab ─────────────────────────────────────────────────────────────

function Spec.BuildTargetUnitTab()
	local rows = {}
	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = function()
			local hFmt = Settings.Get("units.target.healthFormat") or "both"
			local pFmt = Settings.Get("units.target.powerFormat") or "both"
			local auraPl = Settings.Get("units.target.auras.placement") or "right"

			local sampleHp = {
				both = "|cffffffff48,250|r  |cffffcc00(67%)|r",
				value = "|cffffffff48,250|r",
				percent = "|cffffcc0067%|r",
				deficit = "|cffff4444-23,750|r",
				current = "|cffffffff48.2k|r",
				none = "|cff888888(Hidden)|r",
			}
			local samplePp = {
				both = "|cff80b0ff3,200|r  |cffffcc00(64%)|r",
				value = "|cff80b0ff3,200|r",
				percent = "|cffffcc0064%|r",
				deficit = "|cffff4444-1,800|r",
				current = "|cff80b0ff3.2k|r",
				none = "|cff888888(Hidden)|r",
			}

			local name = Settings.Get("units.target.details.showName") ~= false and "Skeleton King" or ""
			local lvl = Settings.Get("units.target.details.showLevel") ~= false and "[70+]" or ""
			local cType = Settings.Get("units.target.details.showCreatureType") and "Undead" or ""
			local classif = Settings.Get("units.target.details.showClassification") ~= false and "Boss" or ""
			local headerParts = {}
			if lvl ~= "" then
				headerParts[#headerParts + 1] = lvl
			end
			if name ~= "" then
				headerParts[#headerParts + 1] = name
			end
			if cType ~= "" then
				headerParts[#headerParts + 1] = ("(%s)"):format(cType)
			end
			if classif ~= "" then
				headerParts[#headerParts + 1] = ("<%s>"):format(classif)
			end
			local titleLine = table.concat(headerParts, " ")
			if titleLine == "" then
				titleLine = "(All details hidden)"
			end

			return (
				"|cffdfaa46[Live Preview]|r  |cffffd100%s|r\n"
				.. "  • |cffaaaaaaHealth:|r %s   |cffaaaaaaPower:|r %s\n"
				.. "  • |cffaaaaaaAuras Grow:|r |cffffffff%s|r"
			):format(titleLine, sampleHp[hFmt] or hFmt, samplePp[pFmt] or pFmt, auraPl:upper())
		end,
	}

	rows[#rows + 1] = { kind = "header", label = "Target frame" }
	rows[#rows + 1] = cfgCheckbox(
		"units.target.show",
		"Enable target frame",
		"Show Roth's Diablo target frame. Turning it off takes full effect after a reload.",
		layout
	)
	rows[#rows + 1] = cfgSlider(
		"units.target.scale",
		"Target frame scale",
		"Base scale of the target frame.",
		0.6,
		2.0,
		0.05,
		function(s)
			local tf = rawget(_G, "Roth_UITargetFrame")
			if tf and not InCombatLockdown() then
				tf:SetScale(s)
			end
			layout()
		end
	)
	rows[#rows + 1] = cfgSlider(
		"units.target.width",
		"Target frame width",
		"Width of the target status bar and border art (default: 240).",
		180,
		320,
		5,
		function(w)
			local tf = rawget(_G, "Roth_UITargetFrame")
			if tf and not InCombatLockdown() then
				tf:SetWidth(w)
			end
			layout()
		end
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Health text format",
		tooltip = "Choose how health is displayed on the target bar.",
		options = function()
			return ns.StandardMode and ns.StandardMode.TARGET_HEALTH_FORMATS
		end,
		get = function()
			return Settings.Get("units.target.healthFormat") or "both"
		end,
		set = function(value)
			Settings.Set("units.target.healthFormat", value)
			refreshTarget()
		end,
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Power text format",
		tooltip = "Choose how mana/energy/rage is displayed on the target bar.",
		options = function()
			return ns.StandardMode and ns.StandardMode.TARGET_POWER_FORMATS
		end,
		get = function()
			return Settings.Get("units.target.powerFormat") or "both"
		end,
		set = function(value)
			Settings.Set("units.target.powerFormat", value)
			refreshTarget()
		end,
	}

	-- Target Details & Text
	rows[#rows + 1] = { kind = "header", label = "Target text & details" }
	rows[#rows + 1] = cfgCheckbox(
		"units.target.details.showName",
		"Target name",
		"Show the target's name above the health bar.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.details.showLevel",
		"Target level",
		"Display the target unit level in the info string.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.details.showCreatureType",
		"Creature type / Race",
		"Display creature family (Beast, Undead, Demon...) or player race.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.details.showClassification",
		"Classification",
		"Display Boss, Rare, or Elite classification tag.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.details.showClass",
		"Player class",
		"Display player class name for player targets.",
		refreshTarget
	)

	-- Target Visuals & Elements
	rows[#rows + 1] = { kind = "header", label = "Target visuals & elements" }
	rows[#rows + 1] = cfgCheckbox(
		"units.target.showDragonCrest",
		"Dragon crest",
		"Horned Diablo dragon crest atop Elite, Rare, and Boss frames.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.threatGlow",
		"Threat glow",
		"The frame art glows red or orange when the target is attacking you.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.castbar.show",
		"Target cast bar",
		"Show the spell cast bar under the target frame.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.portrait.show",
		"Target portrait",
		"Show the standalone 2D/3D portrait frame beside the target.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.portrait.use3D",
		"Animated 3D portrait model",
		"Use an animated 3D character model instead of a flat 2D texture.",
		refreshTarget
	)

	-- Target Auras
	rows[#rows + 1] = { kind = "header", label = "Target auras (buffs & debuffs)" }
	rows[#rows + 1] = cfgCheckbox(
		"units.target.auras.show",
		"Show auras",
		"Display buff and debuff rows for the target frame.",
		refreshTarget
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Aura placement",
		tooltip = "Where buffs and debuffs sit relative to the target frame.",
		options = function()
			return ns.StandardMode and ns.StandardMode.TARGET_AURA_PLACEMENTS
		end,
		get = function()
			return Settings.Get("units.target.auras.placement") or "right"
		end,
		set = function(value)
			Settings.Set("units.target.auras.placement", value)
			refreshTarget()
		end,
	}
	rows[#rows + 1] = cfgSlider(
		"units.target.auras.size",
		"Aura icon size",
		"Size of target buff and debuff icons.",
		12,
		36,
		1,
		function(sz)
			if ns.AuraSize and ns.AuraSize.Set then
				ns.AuraSize.Set("target", sz)
			end
			refreshTarget()
		end
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.auras.onlyShowPlayerBuffs",
		"Only show my buffs",
		"Hide target buffs cast by other players.",
		reloadButton
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.auras.showStealableBuffs",
		"Highlight stealable / dispellable buffs",
		"Emphasize buffs you can Spellsteal or Purge.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.auras.onlyShowPlayerDebuffs",
		"Only show my debuffs",
		"Hide target debuffs cast by other players.",
		refreshTarget
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.target.auras.showDebuffType",
		"Color debuffs by dispel type",
		"Tint debuff borders by Magic (blue), Curse (purple), Poison (green), or Disease (brown).",
		refreshTarget
	)
	return rows
end

-- ── Focus Subtab ──────────────────────────────────────────────────────────────

function Spec.BuildFocusUnitTab()
	local rows = {}
	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = function()
			local hFmt = Settings.Get("units.focus.healthFormat") or "both"
			local pFmt = Settings.Get("units.focus.powerFormat") or "value"
			local sampleHp = {
				both = "|cffffffff32,400|r  |cffffcc00(54%)|r",
				value = "|cffffffff32,400|r",
				percent = "|cffffcc0054%|r",
				deficit = "|cffff4444-27,600|r",
				current = "|cffffffff32.4k|r",
				none = "|cff888888(Hidden)|r",
			}
			local samplePp = {
				both = "|cff80b0ff2,100|r  |cffffcc00(50%)|r",
				value = "|cff80b0ff2,100|r",
				percent = "|cffffcc0050%|r",
				deficit = "|cffff4444-2,100|r",
				current = "|cff80b0ff2.1k|r",
				none = "|cff888888(Hidden)|r",
			}
			return (
				"|cffdfaa46[Live Preview]|r  |cffffd100[70] Archmage Vargoth|r\n"
				.. "  • |cffaaaaaaHealth:|r %s   |cffaaaaaaPower:|r %s"
			):format(sampleHp[hFmt] or hFmt, samplePp[pFmt] or pFmt)
		end,
	}

	rows[#rows + 1] = { kind = "header", label = "Focus frame" }
	rows[#rows + 1] = cfgCheckbox("units.focus.show", "Enable focus frame", "Show the focus unit frame.", layout)
	rows[#rows + 1] = cfgSlider(
		"units.focus.scale",
		"Focus frame scale",
		"Scale of the focus unit frame.",
		0.5,
		1.6,
		0.05,
		function(s)
			local ff = rawget(_G, "Roth_UIFocusFrame")
			if ff and not InCombatLockdown() then
				ff:SetScale(s)
			end
			layout()
		end
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Focus health format",
		tooltip = "Choose how health is displayed on the focus bar.",
		options = function()
			return ns.StandardMode and ns.StandardMode.TARGET_HEALTH_FORMATS
		end,
		get = function()
			return Settings.Get("units.focus.healthFormat") or "both"
		end,
		set = function(value)
			Settings.Set("units.focus.healthFormat", value)
			refreshFocus()
		end,
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Focus power format",
		tooltip = "Choose how mana/energy/rage is displayed below the focus bar.",
		options = function()
			return ns.StandardMode and ns.StandardMode.TARGET_POWER_FORMATS
		end,
		get = function()
			return Settings.Get("units.focus.powerFormat") or "value"
		end,
		set = function(value)
			Settings.Set("units.focus.powerFormat", value)
			refreshFocus()
		end,
	}

	-- Visuals & Cast Bar
	rows[#rows + 1] = { kind = "header", label = "Focus visuals & cast bar" }
	rows[#rows + 1] = cfgCheckbox(
		"units.focus.castbar.show",
		"Focus cast bar",
		"Show spell cast bar with the interrupt-ready burn.",
		refreshFocus
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.focus.portrait.show",
		"Focus portrait",
		"Show portrait attached to the focus frame.",
		refreshFocus
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.focus.portrait.use3D",
		"Focus 3D animated portrait",
		"Use animated 3D model instead of 2D texture.",
		refreshFocus
	)

	-- Focus Auras
	rows[#rows + 1] = { kind = "header", label = "Focus auras" }
	rows[#rows + 1] = cfgCheckbox(
		"units.focus.auras.show",
		"Show focus debuffs",
		"Display harmful debuffs on the focus frame.",
		refreshFocus
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.focus.auras.showBuffs",
		"Show focus buffs",
		"Display helpful buffs on the focus frame.",
		refreshFocus
	)
	rows[#rows + 1] = cfgSlider(
		"units.focus.auras.size",
		"Focus aura icon size",
		"Size of focus buff and debuff icons.",
		12,
		32,
		1,
		function(sz)
			if ns.AuraSize and ns.AuraSize.Set then
				ns.AuraSize.Set("focus", sz)
			end
			refreshFocus()
		end
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.focus.auras.onlyShowPlayerDebuffs",
		"Only show my debuffs on focus",
		"Hide focus debuffs cast by other players.",
		refreshFocus
	)
	return rows
end

-- ── Target of Target Subtab ───────────────────────────────────────────────────

function Spec.BuildToTUnitTab()
	local rows = {}
	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = function()
			local totFmt = Settings.Get("units.targettarget.healthFormat") or "deficit"
			local ftFmt = Settings.Get("units.focustarget.healthFormat") or "deficit"
			local sample = {
				both = "24.5k / 35.0k (70%)",
				value = "24,500",
				percent = "70%",
				deficit = "-10,500",
				current = "24.5k",
				none = "(Hidden)",
			}
			return (
				"|cffdfaa46[Live Preview]|r\n"
				.. "  • |cffaaaaaaToT Bar Text:|r |cffffffff%s|r\n"
				.. "  • |cffaaaaaaFocus Target Text:|r |cffffffff%s|r"
			):format(sample[totFmt] or totFmt, sample[ftFmt] or ftFmt)
		end,
	}

	rows[#rows + 1] = { kind = "header", label = "Target of target" }
	rows[#rows + 1] = cfgCheckbox(
		"units.targettarget.show",
		"Show target of target",
		"Enable Roth's forged iron target of target frame.",
		layout
	)
	rows[#rows + 1] = cfgSlider(
		"units.targettarget.scale",
		"Target of target scale",
		"Scale of the target of target frame.",
		0.5,
		1.6,
		0.05,
		function(s)
			local tot = rawget(_G, "Roth_UITargetTargetFrame")
			if tot and not InCombatLockdown() then
				tot:SetScale(s)
			end
			layout()
		end
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Target of target health format",
		tooltip = "Choose how health is displayed on the target of target frame.",
		options = function()
			return ns.StandardMode and ns.StandardMode.UNIT_HEALTH_FORMATS
		end,
		get = function()
			return Settings.Get("units.targettarget.healthFormat") or "deficit"
		end,
		set = function(value)
			Settings.Set("units.targettarget.healthFormat", value)
			refreshTargetTarget()
		end,
	}
	rows[#rows + 1] = cfgCheckbox(
		"units.targettarget.auras.show",
		"Show debuffs on target of target",
		"Display harmful debuffs on the target of target frame.",
		refreshTargetTarget
	)
	rows[#rows + 1] = cfgSlider(
		"units.targettarget.auras.size",
		"Target of target aura size",
		"Size of target of target debuff icons.",
		12,
		32,
		1,
		function(sz)
			if ns.AuraSize and ns.AuraSize.Set then
				ns.AuraSize.Set("targettarget", sz)
			end
			refreshTargetTarget()
		end
	)

	rows[#rows + 1] = { kind = "header", label = "Focus target" }
	rows[#rows + 1] =
		cfgCheckbox("units.focustarget.show", "Show focus target", "Enable the target of focus unit frame.", layout)
	rows[#rows + 1] = cfgSlider(
		"units.focustarget.scale",
		"Focus target scale",
		"Scale of the focus target unit frame.",
		0.5,
		1.5,
		0.05,
		layout
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Focus target health format",
		tooltip = "Choose how health is displayed on the focus target frame.",
		options = function()
			return ns.StandardMode and ns.StandardMode.UNIT_HEALTH_FORMATS
		end,
		get = function()
			return Settings.Get("units.focustarget.healthFormat") or "deficit"
		end,
		set = function(value)
			Settings.Set("units.focustarget.healthFormat", value)
			refreshFocusTarget()
		end,
	}
	return rows
end

-- ── Pet Subtab ────────────────────────────────────────────────────────────────

function Spec.BuildPetUnitTab()
	local rows = {}
	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = function()
			local petFmt = Settings.Get("units.pet.healthFormat") or "deficit"
			local ptFmt = Settings.Get("units.pettarget.healthFormat") or "deficit"
			local hasHap = Settings.Get("units.pet.happiness.show") ~= false
			local sample = {
				both = "7,800 / 9,200 (84%)",
				value = "7,800",
				percent = "84%",
				deficit = "-1,400",
				current = "7.8k",
				none = "(Hidden)",
			}
			return (
				"|cffdfaa46[Live Preview]|r\n"
				.. "  • |cffaaaaaaPet Health Text:|r |cffffffff%s|r  |cffaaaaaaHappiness Diamond:|r %s\n"
				.. "  • |cffaaaaaaPet Target Text:|r |cffffffff%s|r"
			):format(
				sample[petFmt] or petFmt,
				hasHap and "|cff40ff40Green (Happy)|r" or "|cff888888Off|r",
				sample[ptFmt] or ptFmt
			)
		end,
	}

	rows[#rows + 1] = { kind = "header", label = "Pet frame" }
	rows[#rows + 1] = cfgCheckbox("units.pet.show", "Show pet frame", "Enable pet unit frame.", layout)
	rows[#rows + 1] = cfgSlider(
		"units.pet.scale",
		"Pet frame scale",
		"Scale of the pet unit frame.",
		0.5,
		1.5,
		0.02,
		function(s)
			local pf = rawget(_G, "Roth_UIPetFrame")
			if pf and not InCombatLockdown() then
				pf:SetScale(s)
			end
			layout()
		end
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Pet health text format",
		tooltip = "Choose how health is displayed on the pet frame.",
		options = function()
			return ns.StandardMode and ns.StandardMode.UNIT_HEALTH_FORMATS
		end,
		get = function()
			return Settings.Get("units.pet.healthFormat") or "deficit"
		end,
		set = function(value)
			Settings.Set("units.pet.healthFormat", value)
			refreshPet()
		end,
	}
	rows[#rows + 1] =
		cfgCheckbox("units.pet.castbar.show", "Pet cast bar", "Show spell cast bar for your pet.", refreshPet)
	rows[#rows + 1] = cfgCheckbox(
		"units.pet.happiness.show",
		"Pet happiness diamond",
		"Display Hunter pet happiness indicator (Happy, Content, Unhappy).",
		refreshPet
	)
	rows[#rows + 1] =
		cfgCheckbox("units.pet.portrait.show", "Pet portrait", "Show portrait beside the pet frame.", refreshPet)

	rows[#rows + 1] = { kind = "header", label = "Pet target" }
	rows[#rows + 1] = cfgCheckbox("units.pettarget.show", "Show pet target", "Enable pet's target unit frame.", layout)
	rows[#rows + 1] = cfgSlider(
		"units.pettarget.scale",
		"Pet target scale",
		"Scale of the pet target unit frame.",
		0.5,
		1.5,
		0.05,
		layout
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Pet target health format",
		tooltip = "Choose how health is displayed on the pet target frame.",
		options = function()
			return ns.StandardMode and ns.StandardMode.UNIT_HEALTH_FORMATS
		end,
		get = function()
			return Settings.Get("units.pettarget.healthFormat") or "deficit"
		end,
		set = function(value)
			Settings.Set("units.pettarget.healthFormat", value)
			refreshPetTarget()
		end,
	}
	return rows
end

-- ── Party Subtab ──────────────────────────────────────────────────────────────

function Spec.BuildPartyUnitTab()
	local rows = {}
	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = function()
			local partyFmt = Settings.Get("units.party.healthFormat") or "deficit"
			local alpha = Settings.Get("units.party.alpha.notinrange") or 0.5
			local sample = {
				both = "18.2k / 22.0k (82%)",
				value = "18,200",
				percent = "82%",
				deficit = "-3,800",
				current = "18.2k",
				none = "(Hidden)",
			}
			return (
				"|cffdfaa46[Live Preview]|r\n"
				.. "  • |cffaaaaaaParty Health Text:|r |cffffffff%s|r\n"
				.. "  • |cffaaaaaaOut-of-Range Fade:|r |cffffffff%d%% opacity|r"
			):format(sample[partyFmt] or partyFmt, math.floor(alpha * 100))
		end,
	}

	rows[#rows + 1] = { kind = "header", label = "Party frames" }
	rows[#rows + 1] =
		cfgCheckbox("units.party.show", "Enable party frames", "Show Roth's Diablo party frame column.", layout)
	rows[#rows + 1] = cfgSlider(
		"units.party.scale",
		"Party column scale",
		"Scale of the party frames.",
		0.6,
		1.6,
		0.05,
		function(s)
			if ns.Group and ns.Group.RefreshScale then
				ns.Group.RefreshScale("party")
			end
			layout()
		end
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Party health text format",
		tooltip = "Choose how health is displayed on party members.",
		options = function()
			return ns.StandardMode and ns.StandardMode.UNIT_HEALTH_FORMATS
		end,
		get = function()
			return Settings.Get("units.party.healthFormat") or "deficit"
		end,
		set = function(value)
			Settings.Set("units.party.healthFormat", value)
			refreshParty()
		end,
	}
	rows[#rows + 1] = cfgCheckbox(
		"units.party.auras.showBuffs",
		"Show your HoTs & shields on party",
		"Display your Rejuvenation, Renew, Power Word: Shield icons on party members.",
		refreshParty
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.party.auras.show",
		"Show harmful debuffs on party",
		"Display raid-relevant debuffs under each party member.",
		refreshParty
	)
	rows[#rows + 1] = cfgCheckbox(
		"units.party.attributes.showPlayer",
		"Include player in party column",
		"Display your own character in the party column (useful for gamepad targeting).",
		reloadButton
	)
	rows[#rows + 1] = cfgSlider(
		"units.party.alpha.notinrange",
		"Party out of range opacity",
		"Fade party members who are out of range.",
		0.2,
		0.9,
		0.05,
		refreshParty
	)
	return rows
end

-- ── Raid Subtab ───────────────────────────────────────────────────────────────

function Spec.BuildRaidUnitTab()
	local rows = {}
	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = function()
			local raidFmt = Settings.Get("units.raid.healthFormat") or "deficit"
			local rlayout = Settings.Get("units.raid.layout") or "tiles"
			local alpha = Settings.Get("units.raid.alpha.notinrange") or 0.4
			local sample = {
				both = "12.4k / 16.0k (77%)",
				value = "12,400",
				percent = "77%",
				deficit = "-3,600",
				current = "12.4k",
				none = "(Hidden)",
			}
			return (
				"|cffdfaa46[Live Preview]|r\n"
				.. "  • |cffaaaaaaLayout Style:|r |cffffffff%s|r\n"
				.. "  • |cffaaaaaaRaid Health Text:|r |cffffffff%s|r\n"
				.. "  • |cffaaaaaaOut-of-Range Fade:|r |cffffffff%d%% opacity|r"
			):format(
				rlayout == "tiles" and "Gothic Blood Tiles (40-man compact)" or "Classic Forged Iron Bars",
				sample[raidFmt] or raidFmt,
				math.floor(alpha * 100)
			)
		end,
	}

	rows[#rows + 1] = { kind = "header", label = "Raid frames" }
	rows[#rows + 1] = cfgCheckbox("units.raid.show", "Enable raid frames", "Show Roth's Diablo raid frames.", layout)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Raid layout style",
		tooltip = "Diablo square tiles with rising blood liquid (40-man compact) vs Zork's classic horizontal iron bars. Taking full effect requires a reload.",
		options = function()
			return ns.StandardMode and ns.StandardMode.RAID_LAYOUT_OPTIONS
		end,
		get = function()
			return Settings.Get("units.raid.layout") or "tiles"
		end,
		set = function(value)
			Settings.Set("units.raid.layout", value)
			reloadButton()
		end,
	}
	rows[#rows + 1] = cfgSlider(
		"units.raid.scale",
		"Raid scale",
		"Scale of the raid frames.",
		0.5,
		1.5,
		0.05,
		function(s)
			if ns.Group and ns.Group.RefreshScale then
				ns.Group.RefreshScale("raid")
			end
			layout()
		end
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Raid health text format",
		tooltip = "Choose how health is displayed on raid members (deficit is standard for healing).",
		options = function()
			return ns.StandardMode and ns.StandardMode.UNIT_HEALTH_FORMATS
		end,
		get = function()
			return Settings.Get("units.raid.healthFormat") or "deficit"
		end,
		set = function(value)
			Settings.Set("units.raid.healthFormat", value)
			refreshRaid()
		end,
	}
	rows[#rows + 1] = cfgCheckbox(
		"units.raid.special.chains",
		"Decorative gothic chains (bars mode)",
		"Show decorative hanging iron chains between raid bars.",
		refreshRaid
	)
	rows[#rows + 1] = cfgSlider(
		"units.raid.tiles.buffs",
		"Max HoTs / shields on tiles",
		"Maximum player HoT and shield icons in the top-right corner of each tile.",
		1,
		5,
		1,
		refreshRaid
	)
	rows[#rows + 1] = cfgSlider(
		"units.raid.tiles.debuffs",
		"Max debuffs on tiles",
		"Maximum harmful debuffs shown along the bottom of each tile.",
		1,
		4,
		1,
		refreshRaid
	)
	rows[#rows + 1] = cfgSlider(
		"units.raid.alpha.notinrange",
		"Raid out of range opacity",
		"Fade raid members who are out of range.",
		0.2,
		0.8,
		0.05,
		refreshRaid
	)
	return rows
end

-- Fallback for direct page callers
function Spec.BuildUnitFramesPage()
	return Spec.BuildTargetUnitTab()
end

-- ── Nameplates ────────────────────────────────────────────────────────────────

function Spec.BuildNameplatesPage()
	local rows = {}
	local function refreshPlates()
		if ns.NamePlates and ns.NamePlates.Refresh then
			ns.NamePlates.Refresh()
		end
	end

	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = "Roth's Diablo nameplates: zork's forged iron bar art with health inside, name and level "
			.. "above, threat colours on the iron, gold target outline, cast bar with interrupt burn, and player debuffs.\n"
			.. "Yields automatically if Plater or other nameplate addons are active.",
	}

	rows[#rows + 1] = { kind = "header", label = "Diablo nameplates" }
	rows[#rows + 1] = cfgCheckbox(
		"nameplates.enabled",
		"Enable Diablo nameplates",
		"Replace Blizzard's standard nameplates with Roth's forged iron Diablo plates.",
		refreshPlates
	)
	rows[#rows + 1] = cfgCheckbox(
		"nameplates.friendly",
		"Show on friendly units",
		"Draw Diablo nameplates on friendly players and NPCs too (unchecking leaves Blizzard plates for friends).",
		refreshPlates
	)
	rows[#rows + 1] = cfgSlider(
		"nameplates.scale",
		"Nameplate scale",
		"Overall scale of the nameplates.",
		0.6,
		1.6,
		0.05,
		refreshPlates
	)
	rows[#rows + 1] = cfgSlider(
		"nameplates.targetScale",
		"Target scale multiplier",
		"Enlarges your current target's nameplate for clear visibility.",
		1.0,
		1.5,
		0.05,
		refreshPlates
	)

	rows[#rows + 1] = { kind = "header", label = "Elements & Visuals" }
	rows[#rows + 1] = cfgCheckbox(
		"nameplates.healthText",
		"Health percentage text",
		"Show numeric health percentage inside the iron bar.",
		refreshPlates
	)
	rows[#rows + 1] = cfgCheckbox(
		"nameplates.threat",
		"Threat border color",
		"Tint the iron border according to threat status (red/orange when tanking or losing threat).",
		refreshPlates
	)
	rows[#rows + 1] = cfgCheckbox(
		"nameplates.heads",
		"Diablo demon heads",
		"Display a sculpted Diablo head below the bar for Elites (demon), Rares (gargoyle), and Bosses (skull).",
		refreshPlates
	)
	rows[#rows + 1] = cfgCheckbox(
		"nameplates.castbar",
		"Cast bar",
		"Show spell cast bar with the orange interrupt-ready burn.",
		refreshPlates
	)
	rows[#rows + 1] = cfgCheckbox(
		"nameplates.debuffs",
		"Show your debuffs",
		"Display your harmful debuffs with countdown sweeps above the nameplate.",
		refreshPlates
	)
	rows[#rows + 1] = cfgSlider(
		"nameplates.maxDebuffs",
		"Maximum debuffs shown",
		"Maximum number of player debuff icons displayed per nameplate.",
		1,
		5,
		1,
		refreshPlates
	)

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
		{
			id = "layout",
			label = "Layout",
			indent = 1,
			icon = "Interface\\Icons\\INV_Misc_Gear_01",
			build = Spec.BuildLayoutPage,
		},
		{
			id = "unitframes",
			label = "Unit frames",
			indent = 1,
			icon = "Interface\\Icons\\Spell_Holy_PrayerofShadowProtection",
			tabs = {
				{ id = "target", label = "Target", frameName = "Roth_UITargetFrame", build = Spec.BuildTargetUnitTab },
				{ id = "focus", label = "Focus", frameName = "Roth_UIFocusFrame", build = Spec.BuildFocusUnitTab },
				{
					id = "tot",
					label = "Target of Target",
					frameName = "Roth_UITargetTargetFrame",
					build = Spec.BuildToTUnitTab,
				},
				{ id = "pet", label = "Pet", frameName = "Roth_UIPetFrame", build = Spec.BuildPetUnitTab },
				{ id = "party", label = "Party", frameName = "Roth_UIPartyDragFrame", build = Spec.BuildPartyUnitTab },
				{ id = "raid", label = "Raid", frameName = "Roth_UIRaidDragFrame", build = Spec.BuildRaidUnitTab },
			},
			build = Spec.BuildUnitFramesPage,
		},
		{
			id = "nameplates",
			label = "Nameplates",
			indent = 1,
			icon = "Interface\\Icons\\INV_Shield_06",
			build = Spec.BuildNameplatesPage,
		},
		{
			id = "health",
			label = "Health orb",
			indent = 1,
			icon = "Interface\\Icons\\INV_Potion_54",
			build = Spec.BuildHealthOrbPage,
		},
		{
			id = "power",
			label = "Power orb",
			indent = 1,
			icon = "Interface\\Icons\\INV_Potion_76",
			build = Spec.BuildPowerOrbPage,
		},
		{
			id = "belt",
			label = "Potion belt",
			indent = 1,
			icon = "Interface\\Icons\\INV_Belt_03",
			build = Spec.BuildBeltPage,
		},
		{
			id = "fonts",
			label = "Fonts",
			indent = 1,
			icon = "Interface\\Icons\\INV_Misc_Note_01",
			build = Spec.BuildFontsPage,
		},
		{
			id = "profiles",
			label = "Profiles",
			indent = 1,
			icon = "Interface\\Icons\\INV_Misc_Book_09",
			build = Spec.BuildProfilesPage,
		},
		{
			id = "help",
			label = "Help",
			indent = 1,
			icon = "Interface\\Icons\\INV_Misc_QuestionMark",
			build = Spec.BuildHelpPage,
		},
	}
end
