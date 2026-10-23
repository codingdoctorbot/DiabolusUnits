-- Independent keyboard / gamepad layout state. Never owns native crossbar input.
local _, ns = ...
local G = { defaults = {}, modes = {}, configDefaults = nil }
ns.GamepadLayout = G

local configPaths = {
	"units.player.art.angel.show",
	"units.player.art.demon.show",
	"units.player.art.bottomline.show",
	"units.player.art.actionbarbackground.show",
	"units.player.expbar.show",
	"units.player.repbar.show",
	"swingTimer.enabled",
	"belt.show",
	"units.party.scale",
	"units.raid.scale",
	"units.player.art.angel.pos.x",
	"units.player.art.demon.pos.x",
	"units.player.art.bottomline.pos.y",
}
local function field(path)
	local t = ns.cfg
	local parts = {}
	for key in path:gmatch("[^.]+") do
		parts[#parts + 1] = key
	end
	for i = 1, #parts - 1 do
		t = t and t[parts[i]]
	end
	return t, parts[#parts]
end
local function configSnapshot()
	local result = {}
	for _, path in ipairs(configPaths) do
		local t, key = field(path)
		if t then
			result[path] = t[key]
		end
	end
	return result
end
local function restoreConfig(values)
	for path, value in pairs(values) do
		local t, key = field(path)
		if t then
			t[key] = value
		end
	end
end
local function snapshot(f)
	local points = {}
	for i = 1, f:GetNumPoints() do
		points[i] = { f:GetPoint(i) }
	end
	return { points = points, scale = f:GetScale(), width = f:GetWidth(), height = f:GetHeight() }
end
local function restore(f, state)
	f:SetScale(state.scale)
	f:SetSize(state.width, state.height)
	f:ClearAllPoints()
	for _, point in ipairs(state.points) do
		f:SetPoint(unpack(point))
	end
end
function G:CaptureDefaults()
	self.configDefaults = self.configDefaults or configSnapshot()
	for _, entry in ipairs(ns.EditMode.FRAMES) do
		local f = _G[entry.id]
		if f and not self.defaults[entry.id] then
			self.defaults[entry.id] = snapshot(f)
		end
	end
end
function G:PrepareMode(isPad)
	local mode = isPad and "gamepad" or "keyboard"
	if mode == ns.activeLayoutMode or InCombatLockdown() then
		return
	end
	self:CaptureDefaults()
	local previous = ns.activeLayoutMode
	local oldProfile = previous and ns.LayoutProfile()
	if previous then
		local saved = { frames = {}, config = configSnapshot() }
		for name in pairs(self.defaults) do
			if _G[name] then
				saved.frames[name] = snapshot(_G[name])
			end
		end
		self.modes[previous] = saved
	end
	ns.activeLayoutMode = mode
	local saved = self.modes[mode]
	restoreConfig(saved and saved.config or self.configDefaults)
	for name, state in pairs(self.defaults) do
		if _G[name] then
			restore(_G[name], saved and saved.frames[name] or state)
		end
	end
	-- Re-enable only frames explicitly hidden by the departing layout. UnitWatch
	-- resumes dynamic unit visibility; it must not force absent targets/pets visible.
	local db = ns.LayoutProfile()
	if isPad then
		self:UpgradeGeometry(db)
	end
	for name, disabled in pairs(oldProfile and oldProfile.disabledElements or {}) do
		local f = _G[name]
		if disabled and f and not (db.disabledElements and db.disabledElements[name]) then
			if f.GetAttribute and f:GetAttribute("unit") then
				_G.RegisterUnitWatch(f)
			else
				f:Show()
			end
		end
	end
	ns.EditMode.RestoreSavedLayout(true)
	for name, disabled in pairs(db.disabledElements or {}) do
		local entry = ns.EditMode:EntryFor(name)
		if entry then
			ns.EditMode:SetElementEnabled(entry, not disabled)
		end
	end
	self:PlaceRadial(isPad)
end
function G:ResetCurrent()
	if InCombatLockdown() then
		return
	end
	local db = ns.LayoutProfile()
	-- A hidden unit must resume its unit watch before its disabled override is removed.
	for name, disabled in pairs(db.disabledElements or {}) do
		local f = _G[name]
		if disabled and f and f.GetAttribute and f:GetAttribute("unit") then
			_G.RegisterUnitWatch(f)
		end
	end
	-- Reset the active layout only; retain settings, profiles and the other mode.
	for _, key in ipairs({
		"framePositions",
		"frameScales",
		"globalScale",
		"disabledElements",
		"angelX",
		"demonX",
		"bottomLineY",
		"xpbarY",
		"repbarY",
		"orbSpacing",
		"barWidth",
		"barHeight",
		"groupOffsetX",
	}) do
		db[key] = nil
	end
	local mode = ns.activeLayoutMode
	for _, entry in ipairs(ns.EditMode.FRAMES) do
		local f = _G[entry.id]
		if f and entry.type ~= "unit" then
			ns.EditMode:SetElementEnabled(entry, true)
		end
	end
	db.disabledElements = nil
	self.modes[mode] = nil
	ns.activeLayoutMode = nil
	ns.StandardMode:Apply()
end
function G:DefaultScales()
	local c = ns.cfg.gamepadLayout
	return {
		Roth_UIPlayerFrame = c.orbScale,
		Roth_UIDemonFrame = c.artScale,
		Roth_UIAngelFrame = c.artScale,
		Roth_UIActionBarBackground = 1,
		Roth_UIPlayerFrameCastBarDragFrame = c.castScale / c.orbScale,
		Roth_UITargetFrame = c.targetScale,
		Roth_UITargetFrameCastBarDragFrame = 1.4,
		Roth_UITargetTargetFrame = 0.85,
		Roth_UIBelt = c.beltScale,
	}
end
local function ratio(f)
	return f:GetEffectiveScale() / UIParent:GetEffectiveScale()
end
-- UIParent coordinates, including the shoulder targeting controls which extend
-- beyond the editable root rectangle. Do not include selection outlines/tooltips.
function G:CrossbarBounds()
	local bar = _G.GamepadMainActionBarFrame
	local width = bar and bar:GetWidth() * ratio(bar) or 656
	local center = UIParent:GetWidth() / 2
	if bar and bar.GetCenter then
		local x = bar:GetCenter()
		if x then
			center = x * ratio(bar)
		end
	end
	local bounds = { left = center - width / 2, right = center + width / 2, top = 227, center = center }
	local function include(region)
		if not region then
			return
		end
		local k = ratio(region)
		local left = region.GetLeft and region:GetLeft()
		local right = region.GetRight and region:GetRight()
		local top = region.GetTop and region:GetTop()
		if left then
			bounds.left = math.min(bounds.left, left * k)
		end
		if right then
			bounds.right = math.max(bounds.right, right * k)
		end
		if top then
			bounds.top = math.max(bounds.top, top * k)
		end
	end
	-- Reset the fallback top when the actual rectangle is available.
	local top = bar and bar:GetTop()
	if top then
		bounds.top = top * ratio(bar)
	end
	include(bar)
	local page = bar and bar.PageUnit
	include(page)
	if page then
		include(page.LeftShoulderBackground)
		include(page.RightShoulderBackground)
	end
	return bounds
end
function G:OrbSpacing()
	local bounds = self:CrossbarBounds()
	local halfWidth = math.max(bounds.center - bounds.left, bounds.right - bounds.center)
	return math.min(math.max(ns.cfg.gamepadLayout.orbX, halfWidth + 38), UIParent:GetWidth() / 2 - 100)
end
function G:OrbCenter()
	if ns.cfg.gamepadLayout.followCrossbar == false then
		return 0
	end
	local x = self:CrossbarBounds().center - UIParent:GetWidth() / 2
	local limit = math.max(0, UIParent:GetWidth() / 2 - self:OrbSpacing() - 100)
	return math.max(-limit, math.min(limit, x))
end
-- Post-hooks observe native Edit Mode movement and scaling. They never write the
-- bar's position, scale, bindings or saved layout. Coalesce changes to one update.
function G:WatchCrossbar()
	local bar = _G.GamepadMainActionBarFrame
	if not bar or self.watchedBar == bar then
		return
	end
	self.watchedBar = bar
	local function queue()
		if self.crossbarQueued then
			return
		end
		self.crossbarQueued = true
		C_Timer.After(0, function()
			self.crossbarQueued = false
			if ns.StandardMode:IsGamepad() then
				ns.StandardMode:Apply()
			end
		end)
	end
	bar:HookScript("OnSizeChanged", queue)
	bar:HookScript("OnShow", queue)
	hooksecurefunc(bar, "SetPoint", queue)
	hooksecurefunc(bar, "SetScale", queue)
end
local function place(name, point, relative, relativePoint, x, y)
	local f = _G[name]
	local db = ns.LayoutProfile()
	if not f or (db.framePositions and db.framePositions[name]) then
		return
	end
	f:ClearAllPoints()
	-- Offsets are expressed in UIParent units, including inherited orb scale.
	local k = ratio(f)
	f:SetPoint(point, relative, relativePoint, x / k, y / k)
end
function G:PlaceHUD()
	if InCombatLockdown() then
		return
	end
	local c = ns.cfg.gamepadLayout
	local bounds = self:CrossbarBounds()
	local x = c.followCrossbar == false and 0 or (bounds.center - UIParent:GetWidth() / 2)
	local top = bounds.top
	place("Roth_UIPlayerFrameCastBarDragFrame", "BOTTOM", UIParent, "BOTTOM", x, top + c.castGap)
	place("Roth_UITargetFrame", "BOTTOM", UIParent, "BOTTOM", self:OrbCenter() - self:OrbSpacing(), top + 70)
	if _G.Roth_UITargetFrame then
		place("Roth_UITargetTargetFrame", "TOPRIGHT", _G.Roth_UITargetFrame, "TOPLEFT", -32, -12)
	end
	if _G.Roth_UIPlayerFrame then
		place("Roth_UIPetFrame", "BOTTOM", _G.Roth_UIPlayerFrame, "TOP", 0, 12)
	end
	self:PlaceTargetCastbar()
	if ns.SwingTimer then
		ns.SwingTimer.Place()
	end
	self:PlaceRadial(true)
end
function G:PlaceRadial(isPad)
	local f = _G.GamepadRadial
	if not f or InCombatLockdown() then
		return
	end
	self.radialDefault = self.radialDefault or snapshot(f)
	if isPad and ns.cfg.gamepadLayout.centerRadial then
		f:SetScale(ns.cfg.gamepadLayout.radialScale)
		f:ClearAllPoints()
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	else
		restore(f, self.radialDefault)
	end
end

function G:PlaceTargetCastbar()
	local target = _G.Roth_UITargetFrame
	if target then
		place("Roth_UITargetFrameCastBarDragFrame", "TOP", target, "BOTTOM", 0, -34)
	end
end

-- Gamepad side panels have their own temporary geometry. Restore the native
-- keyboard geometry on mode exit; never save it into Blizzard's layout files.
function G:ArrangePanels(isPad)
	if InCombatLockdown() then
		return
	end
	self.panelDefaults = self.panelDefaults or {}
	local enabled = isPad and ns.cfg.gamepadLayout.arrangePanels ~= false
	local names = { "ChatFrame1", "ObjectiveTrackerFrame", "DurabilityFrame" }
	for _, name in ipairs(names) do
		local f = _G[name]
		if f then
			if enabled then
				if not self.panelsActive and self.panelDefaults[name] then
					self.panelDefaults[name] = nil
				end
				self.panelDefaults[name] = self.panelDefaults[name] or snapshot(f)
				f:ClearAllPoints()
				if name == "ChatFrame1" then
					f:SetScale(0.9)
					f:SetSize(300, 145)
					f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -165)
				elseif name == "ObjectiveTrackerFrame" then
					f:SetScale(0.85)
					f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -65)
				else
					f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -385)
				end
			elseif self.panelDefaults[name] then
				restore(f, self.panelDefaults[name])
				self.panelDefaults[name] = nil
			end
		end
	end
	self.panelsActive = enabled
end

-- Apply the reviewed layout once, retaining the previous anchors/scales so the
-- user's old gamepad arrangement is recoverable. Orb spacing remains untouched.
function G:UpgradeGeometry(db)
	if db.geometryReview1 then
		return
	end
	local before = { framePositions = {}, frameScales = {} }
	for _, name in ipairs({
		"Roth_UITargetFrame",
		"Roth_UITargetTargetFrame",
		"Roth_UITargetFrameCastBarDragFrame",
		"Roth_UIPlayerFrameCastBarDragFrame",
		"Roth_UISwingTimer",
		"Roth_UIBelt",
	}) do
		if db.framePositions then
			before.framePositions[name] = db.framePositions[name]
			db.framePositions[name] = nil
		end
	end
	for _, name in ipairs({ "Roth_UITargetFrameCastBarDragFrame", "Roth_UITargetTargetFrame" }) do
		if db.frameScales then
			before.frameScales[name] = db.frameScales[name]
			db.frameScales[name] = nil
		end
	end
	db.beforeGeometryReview1 = before
	db.geometryReview1 = true
end
