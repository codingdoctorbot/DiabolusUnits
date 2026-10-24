-- Optional Diabolic UI (2016, MIT) art: portrait frames, orb rings, minimap
-- ring and small ToT/focus bar frames. Each piece is a switch in
-- cfg.diabolicArt; off keeps the original Roth art. Textures register here when
-- their frames are built so Refresh() can switch styles without a reload.
-- Only texture files, coordinates, colors and region anchors change: no
-- protected frame is moved, so refreshing in combat is safe.
local _, ns = ...
local Art = {}
ns.DiabolicArt = Art

local MEDIA = "Interface\\AddOns\\DiabolusForever\\media\\"
local DIABOLIC = MEDIA .. "diabolic\\"

local portraits, orbs, bars = {}, {}, {}
local minimapRing, minimapHidden

local function config()
	return ns.cfg.diabolicArt or {}
end

-- Texture coordinates that put each 2016 opening exactly where the Roth opening
-- was (Roth portrait_border opening 58-197 of 256; 2016 border 36-93 of 128),
-- so frames keep their size and the portrait inset.
local PORTRAIT_BORDER = { 0.095, 0.916 }
local PORTRAIT_BACK = { 0.135, 0.861 }

local function applyPortrait(entry)
	local diabolic = config().portraits
	local border, back = entry.border, entry.back
	if border then
		if diabolic then
			border:SetTexture(DIABOLIC .. "portrait_border")
			border:SetTexCoord(PORTRAIT_BORDER[1], PORTRAIT_BORDER[2], PORTRAIT_BORDER[1], PORTRAIT_BORDER[2])
			border:SetVertexColor(1, 1, 1)
		else
			border:SetTexture(MEDIA .. "portrait_border")
			border:SetTexCoord(0, 1, 0, 1)
			border:SetVertexColor(0.6, 0.5, 0.5)
		end
	end
	if back then
		if diabolic then
			back:SetTexture(DIABOLIC .. "portrait_back")
			back:SetTexCoord(PORTRAIT_BACK[1], PORTRAIT_BACK[2], PORTRAIT_BACK[1], PORTRAIT_BACK[2])
			back:SetVertexColor(0.55, 0.55, 0.55, 0.95)
		else
			back:SetTexture(MEDIA .. "portrait_back")
			back:SetTexCoord(0, 1, 0, 1)
			back:SetVertexColor(0.1, 0.1, 0.1, 0.9)
		end
	end
end

-- Either texture may be nil (a 3D portrait border has no back of its own).
function Art.Portrait(border, back)
	local entry = { border = border, back = back }
	portraits[#portraits + 1] = entry
	applyPortrait(entry)
end

-- The 2016 globe opening (57-197 of 256) wraps the orb's outer rim (13-242 of
-- 256 in orb_back2), so the ring texture is 1.63 times the orb, centered.
local RING_SCALE = 230 / 141

local function applyOrb(orb)
	local style = config().orbRing or "none"
	local ring = orb.diabolicRing
	if style == "none" then
		if ring then ring:Hide() end
		return
	end
	if not ring then
		ring = orb.diabolicRingHolder:CreateTexture(nil, "BACKGROUND", nil, 5)
		ring:SetPoint("CENTER", orb, "CENTER", 0, 0)
		orb.diabolicRing = ring
	end
	local size = orb:GetWidth()
	if not size or size <= 0 then size = orb.diabolicRingSize or 0 end
	ring:SetSize(size * RING_SCALE, size * RING_SCALE)
	ring:SetTexture(DIABOLIC .. (style == "glass" and "globe_ring_glass" or "globe_ring"))
	ring:Show()
end

-- overlay: the orb's gloss layer. It lives inside the orb's clipping ScrollFrame,
-- so the larger ring gets its own holder on the orb one level above it.
function Art.Orb(orb, overlay, size)
	local holder = CreateFrame("Frame", nil, orb)
	holder:SetAllPoints(orb)
	holder:SetFrameLevel(overlay:GetFrameLevel() + 1)
	if holder.EnableMouse then holder:EnableMouse(false) end
	orb.diabolicRingHolder, orb.diabolicRingSize = holder, size
	orbs[#orbs + 1] = orb
	applyOrb(orb)
end

-- Small single-bar frames: border/backdrop texture size and the bar opening in
-- texture pixels (left, right, top, bottom; inclusive), measured from the files.
-- top/bottom: first and last painted rows of the rims.
local BAR_ART = {
	bar114 = { w = 256, h = 64, l = 73, r = 182, t = 27, b = 37, top = 14, bottom = 51 },
	bar80 = { w = 256, h = 64, l = 89, r = 166, t = 28, b = 33, top = 19, bottom = 47 },
}
local RIM_OVERLAP = 2 -- UI units the two frames' rims may share

local function wrapBar(texture, bar, art)
	local width, height = bar:GetWidth(), bar:GetHeight()
	if not width or width <= 0 or not height or height <= 0 then return end
	local sx = width / (art.r - art.l + 1)
	local sy = height / (art.b - art.t + 1)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", bar, "TOPLEFT", -art.l * sx, art.t * sy)
	texture:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", (art.w - art.r - 1) * sx, -(art.h - art.b - 1) * sy)
end

local function layoutBars(entry)
	for _, part in ipairs(entry.parts) do wrapBar(part.texture, part.bar, BAR_ART[part.art]) end
end

-- The 114 frame's bottom rim would cover the power bar where Roth places it, so
-- the compact style hangs the power bar under that rim; its anchors are restored
-- when the style is switched off.
local function placePower(entry, compact, force)
	local health, power = entry.health, entry.power
	if not (health and power) then return end
	if compact == entry.powerMoved and not force then return end
	if compact and health:GetHeight() <= 0 then return end -- retried from OnSizeChanged
	if compact and not entry.powerMoved then
		local current = power:GetHeight()
		entry.powerHeight = current > 0 and current or health:GetHeight() - 2
	end
	power:ClearAllPoints()
	if compact then
		local hb, pb = BAR_ART.bar114, BAR_ART.bar80
		local height = entry.powerHeight
		local gap = (hb.bottom - hb.b) * health:GetHeight() / (hb.b - hb.t + 1)
			+ (pb.t - pb.top) * height / (pb.b - pb.t + 1) - RIM_OVERLAP
		power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 4, -gap)
		power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", -4, -gap)
		power:SetHeight(height)
	else
		for _, point in ipairs(entry.powerPoints) do power:SetPoint(unpack(point)) end
	end
	entry.powerMoved = compact
end

local pending
local function applyBars(entry)
	local compact = config().smallFrames and true or false
	if compact ~= (entry.powerMoved or false) and InCombatLockdown() then
		pending = true
		return
	end
	placePower(entry, compact)
	for _, region in ipairs(entry.original) do region:SetShown(not compact) end
	for _, part in ipairs(entry.parts) do part.texture:SetShown(compact) end
	if compact then layoutBars(entry) end
end

-- frame: ToT/focus unit frame. original: Roth regions the compact style hides
-- (frame art and glows sized for it). Health gets the 114 frame, power the 80.
function Art.SmallFrame(frame, original)
	local entry = { original = original, parts = {}, health = frame.Health, power = frame.Power,
		powerPoints = {}, powerMoved = false }
	if frame.Power then
		for i = 1, frame.Power:GetNumPoints() do entry.powerPoints[i] = { frame.Power:GetPoint(i) } end
	end
	local function add(bar, art)
		if not bar then return end
		for _, kind in ipairs({ "back", "border" }) do
			local holder = kind == "border" and CreateFrame("Frame", nil, bar) or bar
			local texture = holder:CreateTexture(nil, kind == "border" and "OVERLAY" or "BACKGROUND",
				nil, kind == "border" and 6 or -7)
			texture:SetTexture(DIABOLIC .. art .. "_" .. kind)
			if kind == "back" then texture:SetVertexColor(0.6, 0.6, 0.6, 0.9) end
			texture:Hide()
			entry.parts[#entry.parts + 1] = { texture = texture, bar = bar, art = art }
		end
		bar:HookScript("OnSizeChanged", function()
			if not config().smallFrames then return end
			if bar == entry.health and not InCombatLockdown() then placePower(entry, true, true) end
			layoutBars(entry)
		end)
	end
	add(frame.Health, "bar114")
	add(frame.Power, "bar80")
	bars[#bars + 1] = entry
	applyBars(entry)
end

-- Ring opening 74-182 of 256 fits the round minimap; the native rim is faded
-- under it and restored when switched off.
local function applyMinimap()
	local map = _G.Minimap
	if not map then return end
	local native = _G.MinimapCompassTexture or _G.MinimapBorder
	local on = config().minimapRing
	if on and not minimapRing then
		local holder = CreateFrame("Frame", nil, map)
		holder:SetAllPoints(map)
		holder:SetFrameLevel(map:GetFrameLevel() + 1)
		if holder.EnableMouse then holder:EnableMouse(false) end
		minimapRing = holder:CreateTexture(nil, "ARTWORK", nil, 1)
		minimapRing:SetTexture(DIABOLIC .. "minimap_ring")
		minimapRing:SetPoint("CENTER", map, "CENTER", 0, 0)
	end
	if minimapRing then
		local size = map:GetWidth() * 256 / 109
		minimapRing:SetSize(size, size)
		minimapRing:SetShown(on and true or false)
	end
	if native then
		if on then
			native:SetAlpha(0)
			minimapHidden = true
		elseif minimapHidden then
			native:SetAlpha(1)
			minimapHidden = nil
		end
	end
end

function Art.Refresh()
	for _, entry in ipairs(portraits) do applyPortrait(entry) end
	for _, orb in ipairs(orbs) do applyOrb(orb) end
	for _, entry in ipairs(bars) do applyBars(entry) end
	applyMinimap()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then
			pending = nil
			for _, entry in ipairs(bars) do applyBars(entry) end
		end
		return
	end
	-- Saved settings are restored at ADDON_LOADED, after the frames were built.
	Art.Refresh()
	if _G.Minimap then _G.Minimap:HookScript("OnSizeChanged", applyMinimap) end
end)
