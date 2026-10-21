-- Lazy page definitions for the settings window.
-- Orb rows reuse core/panel.lua helpers and Roth_UI_DB_CHAR; cfg rows use ns.Settings.
-- Fonts/profiles use AceDB. Moving and sizing frames stays in core/editmode.lua.

local _, ns = ...

local Panel = ns.UI.Panel
local Popup = Panel.Popup
local Settings = ns.Settings

local Spec = {}
Panel.Spec = Spec

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

-- cfg-backed rows

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
  format = path:lower():find("scale", 1, true) and function(value) return ("%d%%"):format(value * 100 + 0.5) end or nil,
		get = function()
   if path == "units.target.scale" and ns.EditMode and _G.Roth_UITargetFrame then
    return ns.EditMode:GetScale(_G.Roth_UITargetFrame)
   end
			return Settings.Get(path)
		end,
		set = function(value)
			Settings.Set(path, value)
   if path == "units.target.scale" and ns.EditMode and _G.Roth_UITargetFrame then
    ns.EditMode:SetScale(_G.Roth_UITargetFrame, value)
   end
			if after then
				after(value)
			end
		end,
	}
end

local function layout()
	Settings.QueueLayout()
end

-- Overview

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
		tooltip = "Resets frame positions and sizes in the active keyboard or gamepad layout. The other layout is kept.",
		onClick = function()
			Popup.Confirm("Reset frame positions and sizes in the active input layout? The other input layout is kept.", "Reset layout", function()
				if ns.EditMode and ns.EditMode.ResetAllToDefault then
					ns.EditMode:ResetAllToDefault()
				end
			end)
		end,
	}
	rows[#rows + 1] = {
		kind = "button",
		label = "Addon option defaults",
		buttonText = "Reset settings",
		tooltip = "Resets addon options in this profile. Saved frame positions, fonts and per-character orb appearance are kept.",
		onClick = function()
			Popup.Confirm("Reset addon options in this profile? Saved frame positions, fonts and orb appearance are kept.", "Reset settings", function()
				Settings.ResetAll()
    if ns.CastBars then ns.CastBars.RefreshAppearance() end
    if ns.Tooltips then ns.Tooltips.Refresh() end
    if ns.InterfaceSkin then ns.InterfaceSkin.Refresh() end
				layout()
				Panel.MarkDirty()
			end)
		end,
	}
	rows[#rows + 1] = reloadButton("Reload the interface")
	return rows
end

-- Layout

function Spec.BuildGamepadPage()
 local rows = {
  { kind = "text", body = "Gamepad has its own saved positions, sizes and visibility. Use Edit Layout while gamepad mode is active. Keyboard keeps its existing layout. Changes in combat wait until combat ends." },
  cfgCheckbox("gamepadLayout.followCrossbar", "Follow the gamepad actionbar", "Default orbs, art and castbar follow the native actionbar. Move or scale the bar in Forever Edit Mode. Saved Diabolus positions take priority.", layout),
  { kind = "header", label = "Gamepad starting layout" },
  { kind = "text", body = "Saved Edit Layout positions and sizes take priority over these defaults. Reset UI affects only the active input mode." },
 }
 for _, item in ipairs({
  { "orbX", "Orb distance from center", 280, 550, 5 },
  { "orbY", "Orb height", 0, 150, 1 },
  { "orbScale", "Orb scale", 0.5, 1.2, 0.01 },
  { "artScale", "Statue art scale", 0.5, 1.2, 0.01 },
  { "artY", "Statue base height", -20, 40, 1 },
  { "castGap", "Castbar gap above actionbar", 24, 140, 1 },
  { "castScale", "Castbar scale", 0.5, 1.5, 0.01 },
  { "swingGap", "Weapon timer gap", 8, 80, 1 },
  { "targetScale", "Target scale", 0.5, 1.5, 0.01 },
  { "beltScale", "Potion belt scale", 0.5, 1.2, 0.01 },
  { "beltY", "Potion belt height", 0, 150, 1 },
 }) do
  rows[#rows + 1] = cfgSlider("gamepadLayout." .. item[1], item[2], nil, item[3], item[4], item[5], layout)
 end
 rows[#rows + 1] = cfgCheckbox("gamepadLayout.arrangePanels", "Separate chat and quest panels", "Keep gamepad chat on the left and quests on the right. Keyboard panel positions are restored when switching back.", layout)
 rows[#rows + 1] = { kind = "header", label = "Native radial menu" }
 rows[#rows + 1] = cfgCheckbox("gamepadLayout.centerRadial", "Center the radial menu", "Keep the native menu and controller navigation, with a centered position.", layout)
 rows[#rows + 1] = cfgSlider("gamepadLayout.radialScale", "Radial menu scale", nil, 0.6, 1.2, 0.01, layout)
 return rows
end

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
		kind = "dropdown",
		child = true,
		label = "Wing style",
		tooltip = "Artwork behind the game menu and bag buttons. Carved stone is the original; the harness styles frame the buttons with caps and rails.",
		enabledWhen = sm,
		options = function()
			local options = { { value = "stone", label = "Carved stone (original)" } }
			for _, kit in ipairs(ns.WingLayout and ns.WingLayout.HarnessKits or {}) do
				options[#options + 1] = { value = kit.id, label = kit.label }
			end
			return options
		end,
		get = function()
			return Settings.Get("standardMode.wingStyle") or "stone"
		end,
		set = function(value)
			Settings.Set("standardMode.wingStyle", value)
			layout()
		end,
	}
	rows[#rows + 1] = {
		kind = "dropdown",
		child = true,
		label = "Harness tint",
		tooltip = "Color grade for the harness styles. Warm pulls metal toward the statues' bronze; dark sinks it into the stone bar.",
		enabledWhen = function()
			return sm() and (Settings.Get("standardMode.wingStyle") or "stone") ~= "stone"
		end,
		options = function()
			return {
				{ value = "natural", label = "Natural" },
				{ value = "warm", label = "Warm bronze" },
				{ value = "dark", label = "Darkened" },
			}
		end,
		get = function()
			return Settings.Get("standardMode.wingTint") or "natural"
		end,
		set = function(value)
			Settings.Set("standardMode.wingTint", value)
			layout()
		end,
	}
	for _, wing in ipairs({ { "micro", "Game menu" }, { "bag", "Bags" } }) do
		for _, dimension in ipairs({
			{ "BodyHeight", "button height", "Height of the painted button body before the wing's requested scale.", 20, 36 },
			{ "ButtonGap", "button spacing", "Clear space between the painted button bodies.", 0, 6 },
			{ "JoinOffset", "statue join offset", "Adjust the wing's default join beside the statue. A saved wing position takes priority.", -160, 160 },
		}) do
			local row = cfgSlider("standardMode." .. wing[1] .. dimension[1],
				wing[2] .. " " .. dimension[2], dimension[3], dimension[4], dimension[5], 1, layout)
			row.child = true
			row.enabledWhen = sm
			rows[#rows + 1] = row
		end
	end

	rows[#rows + 1] = { kind = "header", label = "Experience bar" }
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "XP and rested colors",
		tooltip = "Applies to both keyboard/mouse and gamepad layouts. Rested XP extends beyond your current XP and appears only while a rested bonus is available.",
		options = function()
			return {
				{ value = "purple", label = "Purple XP / blue rested" },
				{ value = "amber", label = "Amber XP / deep amber rested" },
			}
		end,
		get = function()
			return Settings.Get("units.player.expbar.colorStyle") or "amber"
		end,
		set = function(value)
			Settings.Set("units.player.expbar.colorStyle", value)
			if ns.bars and ns.bars.RefreshExperienceAppearance then
				ns.bars.RefreshExperienceAppearance()
			end
		end,
	}
	rows[#rows + 1] = {
		kind = "text",
		body = "The bright fill is earned XP. The darker amber or blue extension is your remaining rested bonus, capped at the end of this level. Hover the bar for exact amounts.",
	}

 rows[#rows + 1] = cfgSlider("standardMode.dockY", "Wing height", "Raise or lower both default wings. A wing moved in Edit Layout keeps its saved position.", -10, 30, 1, layout)

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

-- Belt

function Spec.BuildBeltPage()
	local rows = {}
	rows[#rows + 1] = {
		kind = "text",
		gap = 8,
		body = "Five sockets, the best of each from your bags: health potion, healthstone, mana potion "
			.. "(mana gem first for mages, rage potion for warriors, Thistle Tea for rogues), food "
			.. "and bandage, plus an optional sixth drink socket. Bandages always go on yourself; inside a battleground its free draughts "
			.. "and bandages come first. An empty socket shows a dim category icon.\n\nThe food socket is for the Well Fed "
			.. "buff: its swipe shows how much of the buff is left and its rim pulses when the buff is "
			.. "missing or running low.\n\n"
			.. "Key bindings: Key Bindings > AddOns > DiabolusUnits.",
	}
	rows[#rows + 1] = cfgCheckbox("belt.show", "Show the potion belt", "Hide or show the belt.", function(value)
		if ns.Belt and ns.Belt.SetShown then
			ns.Belt.SetShown(value)
		end
	end)
	local function refreshPolicy()
		if ns.Belt then
			ns.Belt:PolicyChanged()
		end
	end
	rows[#rows + 1] = cfgCheckbox(
		"belt.buffFoodFirst",
		"Prefer buff food when Well Fed is missing",
		"Choose a stat meal when the buff is known to be missing. Otherwise use ordinary food first.",
		refreshPolicy
	)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Preferred food stat",
		tooltip = "Prioritize meals with this bonus. Other food remains available if you have none. Auto uses a class default; choose a stat for your role.",
		options = function()
			return {
				{ value = "auto", label = "Auto (class default)" },
				{ value = "str", label = "Strength" },
				{ value = "agi", label = "Agility" },
				{ value = "sta", label = "Stamina" },
				{ value = "int", label = "Intellect" },
				{ value = "spi", label = "Spirit" },
				{ value = "mp5", label = "Mana regeneration" },
				{ value = "hp5", label = "Health regeneration" },
			}
		end,
		get = function()
			return Settings.Get("belt.foodStat") or "auto"
		end,
		set = function(value)
			Settings.Set("belt.foodStat", value)
			refreshPolicy()
		end,
	}
	if ns.Belt and ns.Belt.powerType == "mana" then
		rows[#rows + 1] = cfgCheckbox(
			"belt.includeRejuvenation",
			"Allow rejuvenation potions",
			"Allow potions that restore both health and mana in the mana socket. Mage gems still come first.",
			refreshPolicy
		)
	end
	rows[#rows + 1] = cfgSlider(
		"belt.foodWarnMinutes",
		"Well Fed warning (minutes)",
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
	rows[#rows + 1] = cfgCheckbox(
		"belt.showDrink",
		"Show a separate drink socket",
		"Add water as socket 6. The first five sockets and bindings stay in the same order. Changes wait until combat ends.",
		refreshPolicy
	)
	rows[#rows + 1] = { kind = "header", label = "Action bar shortcuts" }
	rows[#rows + 1] = {
		kind = "text",
		body = "Create a shortcut, then place the macro from your cursor onto an action bar. Each macro clicks one belt socket and follows its selected item.\n\nDirect bindings are also available under Key Bindings > AddOns > DiabolusUnits (Belt 1–6). You can use either method, or both.",
	}
	rows[#rows + 1] = cfgCheckbox(
		"belt.macroStopCasting",
		"Stop casting from bar macros",
		"Add /stopcasting before each shortcut's /click. Off by default. Direct belt clicks and direct key bindings keep their normal behavior.",
		refreshPolicy
	)
	for index = 1, 6 do
		local slot = index
		rows[#rows + 1] = {
			kind = "button",
			label = "Belt " .. slot .. ": " .. (ns.Belt and ns.Belt.labels[slot] or tostring(slot)),
			buttonText = "Create / pick up macro",
			tooltip = "Creates a character macro on request, or picks up the existing belt shortcut. Custom macros are preserved.",
			enabledWhen = function()
				return slot ~= 6 or Settings.Get("belt.showDrink")
			end,
			onClick = function()
				if ns.Belt then
					local _, message = ns.Belt:PickupMacro(slot)
					print_(message)
				end
			end,
		}
	end
	rows[#rows + 1] = { kind = "header", label = "Above the bags" }
	rows[#rows + 1] = { kind = "text", body = "The keyboard belt follows the bag wing. Dragging it in Edit Layout adjusts these preferences. Automatic fitting keeps the requested size and offsets saved. Gamepad placement is separate." }
	for _, definition in ipairs({
		{ "Horizontal offset", -300, 300, false },
		{ "Gap above the shelf", 4, 150, true },
	}) do
		local isGap = definition[4]
		rows[#rows + 1] = {
			kind = "slider", label = definition[1], min = definition[2], max = definition[3], step = 1,
			tooltip = "Preferred offset in UI units. Fitting may adjust its applied position to keep the belt clear.",
			enabledWhen = function() return ns.StandardMode and ns.StandardMode:IsDockedBelt() end,
			get = function()
				if not ns.StandardMode then return isGap and 6 or 0 end
				local x, gap = ns.StandardMode:GetBeltDockOffsets()
				return isGap and gap or x
			end,
			set = function(value)
				if ns.StandardMode then
					if isGap then ns.StandardMode:SetBeltDockOffsets(nil, value)
					else ns.StandardMode:SetBeltDockOffsets(value, nil) end
				end
			end,
		}
	end
	return rows
end

-- Orbs

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
	rows[#rows + 1] = {
		kind = "button", child = true, label = "Visual model gallery", buttonText = "Browse models",
		tooltip = "Preview eight models at a time, search by name/category/ID, and choose a model. Browsing keeps your orb unchanged until you use a selection.",
		onClick = function() if Panel.OrbGallery then Panel.OrbGallery.Open(orb, kind) end end,
	}
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

-- Fonts

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

-- Profiles

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

-- Castbars

local function refreshCastbars()
 if ns.CastBars then ns.CastBars.RefreshAppearance() end
end

local function castbarTab(unit)
 local path = "units." .. unit .. ".castbar."
 local frameName = ({ player = "Roth_UIPlayerFrame", target = "Roth_UITargetFrame", focus = "Roth_UIFocusFrame" })[unit] .. "CastBarDragFrame"
 local rows = {
  { kind = "text", body = "Move and scale the whole castbar in Edit Layout. These options change its contents and proportions; keyboard and gamepad keep their saved placements." },
  { kind = "header", label = "Appearance" },
  cfgSlider(path .. "width", "Bar width", "Width of the fill; the stone frame follows it.", 160, 420, 5, refreshCastbars),
  cfgSlider(path .. "height", "Bar height", "Height of the fill inside the stone frame.", 10, 26, 1, refreshCastbars),
  {
   kind = "slider", label = "Frame scale (current layout)", min = 0.5, max = 2, step = 0.05,
   tooltip = "The same scale as Edit Layout. Changes only the active keyboard or gamepad layout. Enable this castbar and reload if its frame does not exist yet.",
   enabledWhen = function() return rawget(_G, frameName) ~= nil end,
   format = function(value) return ("%d%%"):format(value * 100 + 0.5) end,
   get = function() return ns.EditMode and ns.EditMode:GetScale(rawget(_G, frameName)) or 1 end,
   set = function(value)
    if ns.EditMode then ns.EditMode:SetScale(rawget(_G, frameName), value) end
   end,
  },
  cfgSlider(path .. "TextSize", "Text size", "Spell name, countdown and pushback text size before frame scaling.", 8, 18, 1, refreshCastbars),
  cfgCheckbox(path .. "showName", "Spell name", "Show the name of the spell being cast.", refreshCastbars),
  cfgCheckbox(path .. "showTime", "Remaining time", "Show the cast or channel countdown.", refreshCastbars),
  cfgSlider(path .. "timeToHold", "Interrupted / failed hold", "Seconds to keep a failed or interrupted cast visible. Zero hides it immediately.", 0, 2, 0.1, refreshCastbars),
 }
 rows[#rows + 1] = { kind = "header", label = unit == "player" and "Casting feedback" or "Interrupts" }
 if unit == "player" then
  rows[#rows + 1] = cfgCheckbox(path .. "showDelay", "Cast pushback", "Show added cast time in red (+seconds), or channel time lost (-seconds).", refreshCastbars)
  rows[#rows + 1] = cfgCheckbox(path .. "latency", "Latency zone", "Shade the latency allowance using your current connection latency.", refreshCastbars)
  rows[#rows + 1] = cfgCheckbox(path .. "channelTicks", "Channel tick marks", "Mark the known tick intervals for supported channeled spells.", refreshCastbars)
 else
  rows[#rows + 1] = cfgCheckbox(path .. "interruptReady", "Interrupt-ready glow", "Glow during an interruptible hostile cast when your interrupt is ready.", refreshCastbars)
 end
 return rows
end

function Spec.BuildPlayerCastbarTab() return castbarTab("player") end
function Spec.BuildTargetCastbarTab() return castbarTab("target") end
function Spec.BuildFocusCastbarTab() return castbarTab("focus") end

-- Tooltips

local function refreshTooltips()
 if ns.Tooltips then ns.Tooltips.Refresh() end
end

function Spec.BuildTooltipPage()
 local rows = {
  { kind = "text", body = "Custom Diablo tooltips. Dragged Edit Layout positions take priority; choosing an anchor restores its default placement. Width and height are minima, so longer content still fits." },
  { kind = "header", label = "Appearance" },
  cfgSlider("rtooltip.scale", "Tooltip scale", "Scale tooltips, including item comparisons.", 0.5, 2, 0.05, refreshTooltips),
  cfgSlider("rtooltip.width", "Minimum width", "Zero uses the content width. Longer content can expand beyond this minimum.", 0, 500, 10, refreshTooltips),
  cfgSlider("rtooltip.height", "Minimum height", "Zero uses the content height. Longer tooltips can expand so text stays visible.", 0, 500, 10, refreshTooltips),
  cfgSlider("rtooltip.opacity", "Background opacity", "Opacity of the tooltip background. Text and borders stay readable.", 0.4, 1, 0.05, refreshTooltips),
  cfgCheckbox("rtooltip.itemDress", "Item decorations", "Add the Diablo title plate and footer to item tooltips.", refreshTooltips),
  cfgCheckbox("rtooltip.itemIcon", "Item icon", "Show the framed icon beside decorated item tooltips.", refreshTooltips),
  cfgCheckbox("rtooltip.qualityBorder", "Item quality border", "Color item borders by quality. Off uses the neutral frame.", refreshTooltips),
  { kind = "header", label = "Details" },
  cfgCheckbox("rtooltip.showSpellID", "Spell IDs", "Include the spell ID on spell and aura tooltips."),
  cfgCheckbox("rtooltip.showTarget", "Unit's target", "Include the hovered unit's current target."),
  cfgCheckbox("rtooltip.showHealth", "Unit health bar", "Show the thin health bar above unit tooltips.", refreshTooltips),
  { kind = "header", label = "Keyboard and mouse" },
 }
 local function position(path, label, gamepad)
  return {
   kind = "dropdown", label = label,
   tooltip = "Choosing an anchor clears that mode's dragged position. Directly anchored button tooltips keep their own placement.",
   options = function()
    local options = {
     { value = "bottomright", label = "Bottom right" },
     { value = "bottomleft", label = "Bottom left" },
     { value = "center", label = "Above the action bars" },
    }
    if gamepad then
     table.insert(options, 1, { value = "top", label = "Top center" })
    else
     options[#options + 1] = { value = "cursor", label = "Follow the mouse" }
    end
    return options
   end,
   get = function() return Settings.Get(path) end,
   set = function(value)
    Settings.Set(path, value)
    local db = ns.BaseLayoutProfile and ns.BaseLayoutProfile()
    if gamepad then db = db and db.gamepadLayout end
    if db and db.framePositions then db.framePositions.Roth_UITooltipAnchor = nil end
    refreshTooltips()
   end,
  }
 end
 rows[#rows + 1] = position("rtooltip.anchor", "Tooltip position", false)
 rows[#rows + 1] = cfgSlider("rtooltip.offsetX", "Horizontal offset", "Move the fixed tooltip anchor left or right; cursor mode ignores this.", -400, 400, 5)
 rows[#rows + 1] = cfgSlider("rtooltip.offsetY", "Vertical offset", "Move the fixed tooltip anchor up or down; cursor mode ignores this.", -300, 300, 5)
 rows[#rows + 1] = { kind = "header", label = "Gamepad" }
 rows[#rows + 1] = position("rtooltip.gamepadAnchor", "Gamepad tooltip position", true)
 rows[#rows + 1] = cfgSlider("rtooltip.gamepadOffsetX", "Gamepad horizontal offset", "Adjust the gamepad tooltip anchor independently of mouse mode.", -400, 400, 5)
 rows[#rows + 1] = cfgSlider("rtooltip.gamepadOffsetY", "Gamepad vertical offset", "Adjust the gamepad tooltip anchor independently of mouse mode.", -300, 300, 5)
 return rows
end

-- Unit Frames

-- Unit Frames Subtab Helpers

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

-- Target Subtab

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
				"|cffdfaa46Text sample|r  |cffffd100%s|r\n"
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
		"Size in the active keyboard or gamepad layout. Edit Layout reads and changes the same value.",
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

-- Focus Subtab

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
				"|cffdfaa46Text sample|r  |cffffd100[70] Archmage Vargoth|r\n"
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

-- Target of Target Subtab

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
				"|cffdfaa46Text sample|r\n"
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

-- Pet Subtab

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
				"|cffdfaa46Text sample|r\n"
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

-- Party Subtab

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
				"|cffdfaa46Text sample|r\n"
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

-- Raid Subtab

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
				"|cffdfaa46Text sample|r\n"
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

-- Nameplates

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

-- Help

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
			body = "D-pad moves, A opens a page or edits a setting, B steps back. In Unit frames, Left / Right switches subpages on the tab row; A / Down enters settings and Up from the first setting returns to tabs. X / Y (Square / Triangle) also switches subpages. LB / RB changes categories, LT / RT scrolls, "
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

-- Native interface skin

function Spec.BuildInterfaceSkinPage()
	local function refresh()
		if ns.InterfaceSkin then ns.InterfaceSkin.Refresh() end
	end
	local function color(key, label, tooltip)
		return {
			kind = "color", label = label, tooltip = tooltip,
			get = function()
				local c = Settings.Get("interfaceSkin." .. key)
				return c.r, c.g, c.b
			end,
			set = function(r, g, b)
				Settings.Set("interfaceSkin." .. key, { r = r, g = g, b = b })
				refresh()
			end,
		}
	end
	local rows = {
		{ kind = "text", body = "Restyle the native interface with subtle metal edging and amber accents. Frames keep their normal controls, positions and scale. Changes made in combat apply afterwards. Settings are saved in this profile." },
		cfgCheckbox("interfaceSkin.enabled", "Enable interface skin", "Switch the whole skin on or restore the native appearance.", refresh),
		{ kind = "header", label = "Components" },
		cfgCheckbox("interfaceSkin.chat", "Chat windows and tabs", "Adds a thin border and background; recolors tab labels. Chat messages and channel colors are kept.", refresh),
		cfgCheckbox("interfaceSkin.minimap", "Minimap trim", "Recolors the native circular frame and top trim. Zone text, mail, tracking icons and the map keep their normal colors.", refresh),
		cfgCheckbox("interfaceSkin.objectives", "Objective tracker", "Styles the content background and section headings. Quest text, progress, difficulty colors and quest items remain native.", refresh),
		cfgCheckbox("interfaceSkin.gamepad", "Gamepad actionbar trim", "Tints native button rims, group frames and shoulder backgrounds. Keeps spell icons, cooldowns, equipped-item indicators and focus effects.", refresh),
		cfgCheckbox("interfaceSkin.respectOtherAddons", "Let other skin addons take priority", "Skips components owned by known chat, minimap, tracker or full-interface addons. Disable an individual component for any unrecognized skin addon.", refresh),
		{ kind = "header", label = "Palette" },
		color("border", "Metal border", "Shared trim color for chat, minimap and objective headings."),
		color("accent", "Accent and headings", "Selected chat tabs and objective section headings. Status and warning colors are preserved."),
		color("text", "Inactive tab text", "Readable text for inactive chat tabs. Does not recolor chat messages or quest objectives."),
		color("gamepadBorder", "Gamepad border", "Independent tint for the native gamepad actionbar trim. White restores the texture's original colors."),
		cfgSlider("interfaceSkin.backgroundOpacity", "Background opacity", "Background behind chat and objective tracker content. Minimap and actionbar backgrounds stay native.", 0, 0.8, 0.02, refresh),
		cfgSlider("interfaceSkin.borderWidth", "Border thickness", "Thickness in UI units; follows each component's existing scale. Applies to chat and objective backgrounds.", 1, 3, 1, refresh),
		cfgCheckbox("interfaceSkin.headerFont", "Use addon font for labels", "Uses your configured detail font for chat tabs and objective section headings, at their native size. Chat messages and objective text keep their own font settings.", refresh),
		{ kind = "button", label = "Skin defaults", buttonText = "Reset skin", onClick = function()
			for _, key in ipairs({ "enabled", "chat", "minimap", "objectives", "gamepad", "respectOtherAddons", "border", "accent", "text", "gamepadBorder", "backgroundOpacity", "borderWidth", "headerFont" }) do
				local path = "interfaceSkin." .. key
				Settings.Set(path, Settings.Default(path))
			end
			refresh()
			Panel.MarkDirty()
		end },
	}
	local function art()
		if ns.DiabolicArt then ns.DiabolicArt.Refresh() end
	end
	rows[#rows + 1] = { kind = "header", label = "Diabolic UI art" }
	rows[#rows + 1] = { kind = "text", body = "Optional rose-bronze pieces from the original Diabolic UI (2016, MIT). Each switch keeps the original art when off and applies immediately." }
	rows[#rows + 1] = cfgCheckbox("diabolicArt.portraits", "Portrait frames", "Rose-bronze frames on the player, target, focus and party portraits instead of the plain grey border. Portrait size and position are unchanged.", art)
	rows[#rows + 1] = {
		kind = "dropdown",
		label = "Orb rim",
		tooltip = "A bronze rim around the health and power orbs. The glass version adds Diabolic UI's own glass over the orb's existing gloss.",
		options = function()
			return {
				{ value = "none", label = "None (original)" },
				{ value = "ring", label = "Bronze rim" },
				{ value = "glass", label = "Bronze rim with glass" },
			}
		end,
		get = function() return Settings.Get("diabolicArt.orbRing") or "none" end,
		set = function(value)
			Settings.Set("diabolicArt.orbRing", value)
			art()
		end,
	}
	rows[#rows + 1] = cfgCheckbox("diabolicArt.minimapRing", "Minimap ring", "Spiked bronze ring around the minimap. The native rim is faded underneath and comes back when this is off.", art)
	rows[#rows + 1] = cfgCheckbox("diabolicArt.smallFrames", "Small target-of-target and focus frames", "Single-bar frames sized for these small units instead of the large two-bar target art. The power bar moves just below the health frame. Switching in combat applies afterwards.", art)
	local skipped = {}
	for _, entry in ipairs({ { "chat", "Chat" }, { "minimap", "Minimap" }, { "objectives", "Objectives" }, { "gamepad", "Gamepad" } }) do
		local owner = ns.InterfaceSkin and ns.InterfaceSkin.GetConflict(entry[1])
		if owner then skipped[#skipped + 1] = entry[2] .. ": " .. owner end
	end
	if #skipped > 0 then
		rows[#rows + 1] = { kind = "text", body = "Detected skin addons (priority option above): " .. table.concat(skipped, "; ") .. "." }
	end
	return rows
end

-- Page list

function Spec.BuildPages()
	return {
		{ id = "overview", label = "Overview", icon = "overview", build = Spec.BuildOverviewPage },
		{
			id = "layout",
			label = "Keyboard layout",
			indent = 1,
			icon = "layout",
			build = Spec.BuildLayoutPage,
		},
		{
			id = "gamepad", label = "Gamepad layout", indent = 1,
			icon = "gamepad", build = Spec.BuildGamepadPage,
		},
		{
			id = "unitframes",
			label = "Unit frames",
			indent = 1,
			icon = "unitframes",
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
   id = "castbars", label = "Castbars", indent = 1, icon = "castbars",
   tabs = {
    { id = "player", label = "Player", frameName = "Roth_UIPlayerFrameCastBarDragFrame", build = Spec.BuildPlayerCastbarTab },
    { id = "target", label = "Target", frameName = "Roth_UITargetFrameCastBarDragFrame", build = Spec.BuildTargetCastbarTab },
    { id = "focus", label = "Focus", frameName = "Roth_UIFocusFrameCastBarDragFrame", build = Spec.BuildFocusCastbarTab },
   },
   build = Spec.BuildPlayerCastbarTab,
  },
  { id = "tooltips", label = "Tooltips", indent = 1, icon = "tooltips", build = Spec.BuildTooltipPage },
		{
			id = "nameplates",
			label = "Nameplates",
			indent = 1,
			icon = "nameplates",
			build = Spec.BuildNameplatesPage,
		},
		{
			id = "health",
			label = "Health orb",
			indent = 1,
			icon = "health",
			build = Spec.BuildHealthOrbPage,
		},
		{
			id = "power",
			label = "Power orb",
			indent = 1,
			icon = "power",
			build = Spec.BuildPowerOrbPage,
		},
		{
			id = "belt",
			label = "Potion belt",
			indent = 1,
			icon = "belt",
			build = Spec.BuildBeltPage,
		},
		{ id = "interfaceSkin", label = "Interface skin", indent = 1, icon = "layout", build = Spec.BuildInterfaceSkinPage },
		{
			id = "fonts",
			label = "Fonts",
			indent = 1,
			icon = "fonts",
			build = Spec.BuildFontsPage,
		},
		{
			id = "profiles",
			label = "Profiles",
			indent = 1,
			icon = "profiles",
			build = Spec.BuildProfilesPage,
		},
		{
			id = "help",
			label = "Help",
			indent = 1,
			icon = "help",
			build = Spec.BuildHelpPage,
		},
	}
end
