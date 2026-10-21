-- Cosmetic adapters for native frames. No reparenting, input hooks or layout ownership.
local _, ns = ...
local Skin = {}
ns.InterfaceSkin = Skin

local groups = {}
local started, queued = false, false
local conflicts = {
	chat = { "ElvUI", "Tukui", "Prat-3.0", "Chatter", "Glass" },
	minimap = { "ElvUI", "Tukui", "SexyMap", "Chinchilla" },
	objectives = { "ElvUI", "Tukui", "KalielsTracker", "DugisGuideViewerZ", "Quester" },
	gamepad = { "ElvUI", "Tukui", "ConsolePort" },
}

local function config()
	return ns.cfg.interfaceSkin
end

function Skin.GetConflict(kind)
	for _, name in ipairs(conflicts[kind] or {}) do
		if ns.Compat.IsAddOnLoaded(name) then return name end
	end
end

local function enabled(kind)
	local c = config()
	return c.enabled and c[kind] and not (c.respectOtherAddons and Skin.GetConflict(kind))
end

local function group(kind)
	if not groups[kind] then
		groups[kind] = { colors = {}, fonts = {}, decorations = {} }
	end
	return groups[kind]
end

local function tint(kind, region, color, alpha)
	if not region or not region.GetVertexColor then return end
	local records = group(kind).colors
	if not records[region] then records[region] = { region:GetVertexColor() } end
	region:SetVertexColor(color.r, color.g, color.b, alpha or 1)
end

local function text(kind, region, color)
	if not region or not region.GetTextColor then return end
	local records = group(kind).colors
	if not records[region] then records[region] = { region:GetTextColor() } end
	region:SetTextColor(color.r, color.g, color.b)
	if config().headerFont and region.GetFont then
		local fonts = group(kind).fonts
		if not fonts[region] then fonts[region] = { region:GetFont() } end
		local old = fonts[region]
		if old[1] then region:SetFont(ns.cfg.font, old[2], old[3]) end
	end
end

local function restore(kind)
	local g = groups[kind]
	if not g then return end
	for region, color in pairs(g.colors) do
		if region.GetTextColor then region:SetTextColor(unpack(color))
		else region:SetVertexColor(unpack(color)) end
	end
	for region, font in pairs(g.fonts) do
		if font[1] then region:SetFont(unpack(font)) end
	end
	for _, decoration in pairs(g.decorations) do
		for _, region in ipairs(decoration) do region:Hide() end
	end
	g.colors, g.fonts = {}, {}
end

-- Regions inherit the native frame's scale, visibility and alpha without intercepting input.
local function decorate(kind, frame, padding)
	if not frame or not frame.CreateTexture then return end
	local g, c = group(kind), config()
	local d = g.decorations[frame]
	if not d then
		d = {}
		g.decorations[frame] = d
		for i = 1, 6 do
			d[i] = frame:CreateTexture(nil, i == 1 and "BACKGROUND" or "BORDER", nil, i == 1 and -8 or 0)
		end
		local fill, top, bottom, left, right, accent = unpack(d)
		fill:SetPoint("TOPLEFT", frame, "TOPLEFT", -padding, padding)
		fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", padding, -padding)
		top:SetPoint("TOPLEFT", fill, "TOPLEFT")
		top:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
		bottom:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT")
		bottom:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
		left:SetPoint("TOPLEFT", fill, "TOPLEFT")
		left:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT")
		right:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
		right:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
		accent:SetPoint("TOPLEFT", fill, "TOPLEFT", 1, -1)
		accent:SetPoint("TOPRIGHT", fill, "TOPRIGHT", -1, -1)
	end
	d[1]:SetColorTexture(0.035, 0.03, 0.025, c.backgroundOpacity)
	for i = 2, 5 do
		d[i]:SetColorTexture(c.border.r, c.border.g, c.border.b, 0.9)
	end
	d[2]:SetHeight(c.borderWidth)
	d[3]:SetHeight(c.borderWidth)
	d[4]:SetWidth(c.borderWidth)
	d[5]:SetWidth(c.borderWidth)
	d[6]:SetHeight(1)
	d[6]:SetColorTexture(c.accent.r, c.accent.g, c.accent.b, 0.3)
	for _, region in ipairs(d) do region:Show() end
end

local function nineSlice(kind, frame, hideCenter)
	if not frame then return end
	for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
		"TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }) do
		tint(kind, frame[key], config().border, hideCenter and key == "Center" and 0 or 1)
	end
end

local function tabStyle(tab, selected)
	if not enabled("chat") or not tab then return end
	local label = tab.Text or (tab.GetFontString and tab:GetFontString())
	text("chat", label, selected and config().accent or config().text)
	for _, key in ipairs({ "Left", "Middle", "Right" }) do tint("chat", tab[key], config().border) end
	for _, key in ipairs({ "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft", "HighlightMiddle", "HighlightRight" }) do
		tint("chat", tab[key], config().accent)
	end
end

local function chat()
	for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
		local name = "ChatFrame" .. i
		local frame = _G[name]
		if frame then
			decorate("chat", frame, 4)
			-- Native mouseover fading remains active; suppress only its decorative textures.
			for _, suffix in ipairs(_G.CHAT_FRAME_TEXTURES or {}) do
				tint("chat", _G[name .. suffix], config().border, 0)
			end
			local selected = frame == _G.SELECTED_CHAT_FRAME or not frame.isDocked
			tabStyle(_G[name .. "Tab"], selected)
		end
	end
end

local function minimap()
	-- Tint the native circular frame; retain its mask, compass and all status icons.
	tint("minimap", _G.MinimapCompassTexture or _G.MinimapBorder, config().border)
	local cluster = _G.MinimapCluster
	if cluster then
		nineSlice("minimap", cluster.BorderTop)
		if cluster.Tracking then tint("minimap", cluster.Tracking.Background, config().border) end
	end
	-- Zone text carries friendly/hostile/contested information and keeps its native color.
end

local function header(frame)
	if not frame or not frame.Header then return end
	text("objectives", frame.Header.Text, config().accent)
	tint("objectives", frame.Header.Background, config().border)
end

local function objectives()
	local tracker = _G.ObjectiveTrackerFrame
	if not tracker then return end
	-- NineSlice wraps actual content; the tracker itself can be an 800-unit edit region.
	if tracker.NineSlice then
		decorate("objectives", tracker.NineSlice, 0)
		nineSlice("objectives", tracker.NineSlice, true)
	end
	header(tracker)
	for _, module in ipairs(tracker.modules or {}) do header(module) end
	-- Some modules are in separate native containers rather than the main tracker.
	for _, name in ipairs({ "QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "AchievementObjectiveTracker",
		"ScenarioObjectiveTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker",
		"ProfessionsRecipeTracker", "MonthlyActivitiesObjectiveTracker", "AdventureObjectiveTracker" }) do
		header(_G[name])
	end
end

local function gamepad()
	local root = _G.GamepadMainActionBarFrame
	local page = root and root.PageUnit
	if not page then return end
	local color = config().gamepadBorder
	tint("gamepad", page.LeftShoulderBackground, color)
	tint("gamepad", page.RightShoulderBackground, color)
	for _, bar in pairs(page.actionBars or {}) do
		tint("gamepad", bar.LeftButtonFrame, color)
		tint("gamepad", bar.RightButtonFrame, color)
		for _, side in ipairs({ "Left", "Right" }) do
			local buttons = bar[side]
			for i = 1, 4 do
				local button = buttons and buttons["ActionButton" .. i]
				if button then
					-- Border is the equipped/proc indicator; only NormalTexture is decorative.
					tint("gamepad", button.NormalTexture, color)
				end
			end
		end
	end
end

local adapters = { chat = chat, minimap = minimap, objectives = objectives, gamepad = gamepad }

local function apply()
	queued = false
	if not started or InCombatLockdown() then return end
	for kind, adapter in pairs(adapters) do
		restore(kind)
		if enabled(kind) then adapter() end
	end
end

function Skin.Refresh()
	if not started or queued then return end
	queued = true
	C_Timer.After(0, apply)
end

local function installHooks()
	local crossbar = _G.GamepadMainActionBarFrame
	if crossbar and not Skin.crossbarHook then
		Skin.crossbarHook = true
		crossbar:HookScript("OnShow", Skin.Refresh)
	end
	if type(_G.FCFTab_UpdateColors) == "function" and not Skin.tabHook then
		Skin.tabHook = true
		hooksecurefunc("FCFTab_UpdateColors", function(tab, selected)
			if InCombatLockdown() or not enabled("chat") then return end
			-- Capture Blizzard's freshly applied colors, including temporary conversation tabs.
			local records = group("chat").colors
			local label = tab.Text or (tab.GetFontString and tab:GetFontString())
			if label then records[label] = nil end
			for _, key in ipairs({ "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft", "HighlightMiddle", "HighlightRight" }) do
				if tab[key] then records[tab[key]] = nil end
			end
			tabStyle(tab, selected)
		end)
	end
	for _, name in ipairs({ "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow" }) do
		Skin.hooks = Skin.hooks or {}
		if type(_G[name]) == "function" and not Skin.hooks[name] then
			Skin.hooks[name] = true
			hooksecurefunc(name, Skin.Refresh)
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then started = true end
	if started then
		installHooks()
		Skin.Refresh()
	end
end)
