-- Lazy model browser using the orb's existing catalogue and save/update helpers.
local _, ns = ...
local Panel = ns.UI.Panel
local Theme = Panel.Theme
local Gallery = {}
Panel.OrbGallery = Gallery

local COLUMNS, PAGE_SIZE = 4, 8
local WIDTH, HEIGHT = 640, 540
local frame, catcher, state

function Gallery.Entries(query, currentID)
	local entries, seen = {}, {}
	local search = (query or ""):lower():match("^%s*(.-)%s*$")
	local function add(item, category)
		if type(item.value) ~= "number" or seen[item.value] then return end
		seen[item.value] = true
		local label = item.key or tostring(item.value)
		local haystack = (label .. " " .. category .. " " .. item.value):lower()
		if search == "" or haystack:find(search, 1, true) then
			entries[#entries + 1] = { id = item.value, label = label, category = category }
		end
	end
	for _, category in ipairs(ns.db.getListModel() or {}) do
		if category.menuList then
			for _, item in ipairs(category.menuList) do add(item, category.key or "Other") end
		else add(category, "Other") end
	end
	if currentID and not seen[currentID] then add({ value = currentID, key = "Current model" }, "Custom") end
	return entries
end

local function helper(prefix, suffix)
	return ns.panel[prefix .. state.orb .. "Orb" .. suffix]
end

local function write(id, enable)
	if InCombatLockdown() then return false end
	helper("save", "ModelAnimation")(id)
	helper("save", "ModelEnable")(enable)
	helper("update", "ModelAnimation")()
	helper("update", "ModelEnable")()
	Panel.MarkDirty()
	return true
end

local function clearPreviews()
	if not frame then return end
	frame.generation = (frame.generation or 0) + 1
	for _, tile in ipairs(frame.tiles) do
		tile.Model:Hide()
		tile.Model:ClearModel()
		tile.item = nil
	end
end

function Gallery.Close()
	if catcher then catcher:Hide() end
end

local function camera(model)
	local c = state and ns.db.char[state.kind].model
	if not c then return end
	model:SetCamDistanceScale(c.camDistanceScale)
	model:SetPosition(0, c.pos_x, c.pos_y)
	model:SetRotation(c.rotation)
	model:SetPortraitZoom(c.portraitZoom)
end

local function modelLoaded(model)
	camera(model)
	if model.tile then model.tile.Status:SetText("") end
end

local function preview(tile, item, generation)
	tile.Model:Hide()
	tile.Model:ClearModel()
	tile.item = item
	if not item then tile:Hide(); return end
	tile.Label:SetText(item.label)
	tile.ID:SetText(item.category .. " / " .. item.id)
	tile.Status:SetText("Loading...")
	tile:Show()
	tile.Model:Show()
	local ok = pcall(function()
		camera(tile.Model)
		tile.Model:SetDisplayInfo(item.id)
	end)
	if not ok then tile.Status:SetText("Preview unavailable"); return end
	C_Timer.After(1.5, function()
		if not state or not catcher:IsShown() or frame.generation ~= generation or tile.item ~= item then return end
		local fileID = tile.Model:GetModelFileID()
		if fileID and not (issecretvalue and issecretvalue(fileID)) and fileID ~= 0 then
			tile.Status:SetText("")
		else tile.Status:SetText("Preview not loaded") end
	end)
end

local function refresh(reload)
	if not state then return end
	local pages = math.max(1, math.ceil(#state.entries / PAGE_SIZE))
	state.page = math.max(1, math.min(pages, state.page))
	if reload then frame.generation = (frame.generation or 0) + 1 end
	local currentID = helper("load", "ModelAnimation")()
	for index, tile in ipairs(frame.tiles) do
		local entryIndex = (state.page - 1) * PAGE_SIZE + index
		local item = state.entries[entryIndex]
		if reload then preview(tile, item, frame.generation) end
		local c = entryIndex == state.selected and Theme.COLOR_FOCUS or Theme.COLOR_BORDER
		tile.Edge:SetColorTexture(c.r, c.g, c.b, 1)
		tile.Applied:SetShown(item ~= nil and item.id == currentID)
	end
	frame.PageText:SetText(("Page %d / %d  |  %d models"):format(state.page, pages, #state.entries))
	frame.Previous:SetEnabled(state.page > 1)
	frame.Next:SetEnabled(state.page < pages)
	frame.Use:SetEnabled(state.entries[state.selected] ~= nil)
	frame.Empty:SetShown(#state.entries == 0)
	local chosen = state.entries[state.selected]
	frame.Selection:SetText(chosen and (chosen.label .. " / " .. chosen.id) or "No matching models")
end

function Gallery.Search(query)
	if not state then return end
	local currentID = helper("load", "ModelAnimation")()
	state.entries = Gallery.Entries(query, currentID)
	state.selected, state.page = 1, 1
	refresh(true)
end

function Gallery.Move(delta)
	if not state or #state.entries == 0 then return end
	local oldPage = state.page
	state.selected = math.max(1, math.min(#state.entries, state.selected + delta))
	state.page = math.floor((state.selected - 1) / PAGE_SIZE) + 1
	refresh(oldPage ~= state.page)
end

function Gallery.ChangePage(delta)
	if not state or #state.entries == 0 then return end
	local oldPage = state.page
	local pages = math.ceil(#state.entries / PAGE_SIZE)
	state.page = math.max(1, math.min(pages, state.page + delta))
	state.selected = math.min(#state.entries, (state.page - 1) * PAGE_SIZE + (state.selected - 1) % PAGE_SIZE + 1)
	refresh(oldPage ~= state.page)
end

function Gallery.UseSelection()
	if not state then return end
	local entry = state.entries[state.selected]
	if entry and write(entry.id, true) then refresh(false) end
end

function Gallery.RestorePrevious()
	if state and write(state.original.id, state.original.enable) then refresh(false) end
end

function Gallery.HandleGamepad(key)
	if not state or not catcher:IsShown() then return false end
	if key == "PADDLEFT" then Gallery.Move(-1)
	elseif key == "PADDRIGHT" then Gallery.Move(1)
	elseif key == "PADDUP" then Gallery.Move(-COLUMNS)
	elseif key == "PADDDOWN" then Gallery.Move(COLUMNS)
	elseif key == "PADLSHOULDER" then Gallery.ChangePage(-1)
	elseif key == "PADRSHOULDER" then Gallery.ChangePage(1)
	elseif key == "PAD1" then Gallery.UseSelection()
	elseif key == "PAD3" then Gallery.RestorePrevious()
	elseif key == "PAD2" or key == "PADBACK" then Gallery.Close() end
	return true
end

local function button(label, width, onClick)
	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(width, 24)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	Theme.StyleActionButton(b, false)
	return b
end

local function label(parent, font, text)
	local f = parent:CreateFontString(nil, "OVERLAY", font)
	f:SetText(text or "")
	return f
end

local function ensureBuilt()
	if frame then return end
	catcher = CreateFrame("Button", nil, UIParent)
	catcher:Hide()
	catcher:SetAllPoints(UIParent)
	catcher:SetFrameStrata("FULLSCREEN_DIALOG")
	catcher:SetScript("OnClick", Gallery.Close)
	Theme.MarkIgnored(catcher)
	frame = CreateFrame("Frame", "DiabolusOrbModelGallery", catcher)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER")
	frame:SetFrameLevel(catcher:GetFrameLevel() + 10)
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(_, delta) Gallery.ChangePage(delta > 0 and -1 or 1) end)
	Theme.CreateSurface(frame, Theme.COLOR_BG)
	Theme.MarkIgnored(frame)
	frame.tiles = {}
	frame.Title = label(frame, Theme.HEADER_TITLE_FONT)
	frame.Title:SetPoint("TOPLEFT", 20, -16)
	local close = button("Close", 64, Gallery.Close)
	close:SetPoint("TOPRIGHT", -16, -16)
	frame.Search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.Search:SetSize(340, 24)
	frame.Search:SetPoint("TOPLEFT", 26, -58)
	frame.Search:SetAutoFocus(false)
	frame.Search:SetMaxLetters(80)
	frame.Search:SetScript("OnTextChanged", function(self) Gallery.Search(self:GetText()) end)
	frame.Search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Gallery.Close() end)
	frame.Search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	local clear = button("Clear search", 100, function() frame.Search:SetText(""); frame.Search:ClearFocus() end)
	clear:SetPoint("LEFT", frame.Search, "RIGHT", 12, 0)
	local searchHint = label(frame, Theme.FONT_CHILD, "Search name, category or display ID")
	searchHint:SetPoint("TOPLEFT", 24, -86)
	for index = 1, PAGE_SIZE do
		local tile = CreateFrame("Button", nil, frame)
		tile:SetSize(144, 150)
		tile:SetPoint("TOPLEFT", 20 + ((index - 1) % COLUMNS) * 152, -110 - math.floor((index - 1) / COLUMNS) * 158)
		local _, edge = Theme.CreateSurface(tile, Theme.COLOR_SURFACE)
		tile.Edge = edge
		local clip = CreateFrame("ScrollFrame", nil, tile)
		clip:SetPoint("TOPLEFT", 4, -4)
		clip:SetSize(136, 108)
		clip:EnableMouse(false)
		local child = CreateFrame("Frame", nil, clip)
		child:SetSize(136, 108)
		clip:SetScrollChild(child)
		tile.Model = CreateFrame("PlayerModel", nil, child)
		tile.Model:SetAllPoints(child)
		tile.Model:EnableMouse(false)
		tile.Model.tile = tile
		tile.Model:SetScript("OnModelLoaded", modelLoaded)
		local overlay = CreateFrame("Frame", nil, tile)
		overlay:SetAllPoints(tile)
		overlay:SetFrameLevel(tile.Model:GetFrameLevel() + 2)
		overlay:EnableMouse(false)
		tile.Status = label(overlay, Theme.FONT_CHILD)
		tile.Status:SetPoint("CENTER", clip, "CENTER")
		tile.Label = label(tile, Theme.FONT_NORMAL)
		tile.Label:SetPoint("TOPLEFT", 6, -114)
		tile.Label:SetSize(132, 15)
		tile.ID = label(tile, Theme.FONT_CHILD)
		tile.ID:SetPoint("TOPLEFT", 6, -132)
		tile.ID:SetSize(132, 13)
		tile.Applied = label(overlay, Theme.FONT_CHILD, "Current")
		tile.Applied:SetPoint("TOPRIGHT", -7, -6)
		tile.Applied:SetTextColor(Theme.COLOR_ACCENT.r, Theme.COLOR_ACCENT.g, Theme.COLOR_ACCENT.b)
		tile:SetScript("OnClick", function()
			if state then state.selected = (state.page - 1) * PAGE_SIZE + index; refresh(false) end
		end)
		tile:SetScript("OnEnter", function()
			if tile.item then Theme.ShowTooltip(tile, tile.item.label, "Display ID " .. tile.item.id .. ". Select, then Use model. Previews use your current camera settings at full opacity.") end
		end)
		tile:SetScript("OnLeave", Theme.HideTooltip)
		frame.tiles[index] = tile
	end
	frame.Empty = label(frame, Theme.FONT_NORMAL, "No models match your search.")
	frame.Empty:SetPoint("CENTER", frame, "CENTER", 0, 20)
	frame.Previous = button("Previous", 90, function() Gallery.ChangePage(-1) end)
	frame.Previous:SetPoint("TOPLEFT", 20, -430)
	frame.Next = button("Next", 90, function() Gallery.ChangePage(1) end)
	frame.Next:SetPoint("TOPRIGHT", -20, -430)
	frame.PageText = label(frame, Theme.FONT_CHILD)
	frame.PageText:SetPoint("TOP", 0, -436)
	frame.Selection = label(frame, Theme.FONT_NORMAL)
	frame.Selection:SetPoint("TOPLEFT", 20, -468)
	frame.Selection:SetWidth(290)
	frame.Use = button("Use model", 112, Gallery.UseSelection)
	frame.Use:SetPoint("TOPRIGHT", -20, -462)
	local undo = button("Restore previous", 138, Gallery.RestorePrevious)
	undo:SetPoint("RIGHT", frame.Use, "LEFT", -8, 0)
	local hint = label(frame, Theme.FONT_CHILD, "D-pad Browse   A Use   B Close   LB/RB Pages   X Restore previous")
	hint:SetPoint("BOTTOM", 0, 28)
	local note = label(frame, Theme.FONT_CHILD, "Use model enables the 3D layer; your camera, opacity and other orb effects are kept.")
	note:SetPoint("BOTTOM", 0, 10)
	frame:EnableKeyboard(true)
	frame:SetScript("OnKeyDown", function(self, key)
		if InCombatLockdown() then return end
		local handled = key == "ESCAPE" or (not frame.Search:HasFocus() and (key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN" or key == "ENTER"))
		self:SetPropagateKeyboardInput(not handled)
		if key == "ESCAPE" then Gallery.Close()
		elseif handled then
			if key == "ENTER" then Gallery.UseSelection()
			else Gallery.Move(key == "LEFT" and -1 or key == "RIGHT" and 1 or key == "UP" and -COLUMNS or COLUMNS) end
		end
	end)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:SetScript("OnEvent", Gallery.Close)
	frame:SetScript("OnHide", function()
		clearPreviews()
		frame.Search:ClearFocus()
		Theme.HideTooltip()
		state = nil
	end)
end

function Gallery.Open(orb, kind)
	if InCombatLockdown() or (kind ~= "HEALTH" and kind ~= "POWER") then return end
	if not ns.db or not ns.panel or not Panel.IsShown() then return end
	Panel.Popup.CloseAll()
	ensureBuilt()
	local c = ns.db.char[kind].model
	frame.Title:SetText(orb .. " orb models")
	frame:SetScale(math.min(1, (UIParent:GetWidth() - 32) / WIDTH, (UIParent:GetHeight() - 32) / HEIGHT))
	frame.Search:SetText("")
	state = { orb = orb, kind = kind, original = { id = c.displayInfo, enable = c.enable }, selected = 1, page = 1,
		entries = Gallery.Entries("", c.displayInfo) }
	for index, entry in ipairs(state.entries) do if entry.id == c.displayInfo then state.selected = index; break end end
	state.page = math.floor((state.selected - 1) / PAGE_SIZE) + 1
	catcher:Show()
	refresh(true)
end
