-- Geometry for keyboard wings and the docked belt. Solvers never touch frames.
-- Rectangles use absolute UIParent units; texture metadata uses source pixels.
local _, ns = ...
local Layout = {}
ns.WingLayout = Layout

local abs, min, max, huge = math.abs, math.min, math.max, math.huge
local EPS = 0.0000001
local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\d3_wing_dock_v2"

Layout.Atlas = {
	width = 256, height = 128, channel = 36, top = 4, base = 6,
	cap = { 4, 4, 92, 96 }, center = { 100, 4, 212, 96 }, join = { 220, 4, 244, 96 },
	capWidth = 44, centerWidth = 56, joinWidth = 12, heightUnits = 46,
}
Layout.MAX_CENTER_TILES = 128
-- Target optical sizes, not claims that an arbitrary native atlas is calibrated.
Layout.DefaultMetrics = {
	micro = { bodyHeight = 28, gap = 1, padding = 2 },
	bags = { bodyHeight = 30, gap = 2, padding = 2 },
}
Layout.StatueMetricSource = { width = 512, height = 256, bandHeight = 8, alphaThreshold = 32 }

-- Original d3_*2.tga alpha >= 32, horizontal source bands of eight pixels.
-- Bounds are exclusive at their right/bottom source edges. Source is 512 x 256.
Layout.StatueBands = {
	demon = {
		{121,88,165,96}, {100,96,180,104}, {89,104,188,112}, {84,112,188,120},
		{74,120,187,128}, {66,128,197,136}, {58,136,203,144}, {58,144,213,152},
		{55,152,217,160}, {49,160,219,168}, {46,168,222,176}, {45,176,224,184},
		{45,184,226,192}, {49,192,226,200}, {44,200,223,208}, {24,208,209,216},
		{23,216,216,224}, {14,224,233,232}, {13,232,245,240}, {12,240,254,248},
		{8,248,257,256},
	},
	angel = {
		{343,104,413,112}, {339,112,426,120}, {327,120,439,128}, {323,128,446,136},
		{320,136,458,144}, {318,144,460,152}, {311,152,464,160}, {310,160,467,168},
		{309,168,473,176}, {304,176,473,184}, {304,184,473,192}, {304,192,478,200},
		{307,200,478,208}, {304,208,486,216}, {300,216,490,224}, {284,224,491,232},
		{271,232,493,240}, {262,240,501,248}, {259,248,506,256},
	},
}

local function number(n) return type(n) == "number" and n == n and abs(n) < huge end
local function rect(r)
	return type(r) == "table" and number(r.l) and number(r.r) and number(r.b) and number(r.t)
		and r.r > r.l and r.t > r.b
end
local function clamp(n, l, r) return min(r, max(l, n)) end
local function intersectsY(b, t, r, gap)
	return t > r.b - (gap or 0) + EPS and b < r.t + (gap or 0) - EPS
end
local function line(a, b) return { a, b } end
local function value(v, q) return v[1] + v[2] * q end

-- The intersection of affine inequalities is one scale interval. Solving it
-- analytically avoids assuming monotonicity across changing statue bands.
local function feasibleScale(lowers, uppers, low, high)
	for _, lower in ipairs(lowers) do
		for _, upper in ipairs(uppers) do
			local a, b = lower[1] - upper[1], lower[2] - upper[2]
			if abs(b) < EPS then
				if a > EPS then return nil end
			elseif b > 0 then high = min(high, -a / b)
			else low = max(low, -a / b) end
		end
	end
	if high + EPS < low then return nil end
	return max(low, high)
end
local function interval(lowers, uppers, q)
	local l, r = -huge, huge
	for _, v in ipairs(lowers) do l = max(l, value(v, q)) end
	for _, v in ipairs(uppers) do r = min(r, value(v, q)) end
	if l > r + EPS then return nil end
	return l, max(l, r)
end
local function partitions(low, high, breaks)
	local points = { low, high }
	for _, q in ipairs(breaks) do
		if number(q) and q > low + EPS and q < high - EPS then points[#points + 1] = q end
	end
	table.sort(points)
	local unique = {}
	for _, q in ipairs(points) do
		if #unique == 0 or q - unique[#unique] > EPS then unique[#unique + 1] = q end
	end
	return unique
end
local function statues(spec)
	local result = spec.statueRects or spec.statueBands or {}
	for _, r in ipairs(result) do if not rect(r) then return nil end end
	return result
end

function Layout.FrameRectUI(first, second)
	local frame = first == Layout and second or first
	if not frame or not UIParent then return nil end
	local u, f = UIParent:GetEffectiveScale(), frame:GetEffectiveScale()
	local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
	if not (number(u) and u > 0 and number(f) and f > 0 and number(l) and number(r)
		and number(b) and number(t)) then return nil end
	local q = f / u
	local result = { l = l * q, r = r * q, b = b * q, t = t * q }
	return rect(result) and result or nil
end

function Layout.StatueRectsUI(first, second, third)
	local frame, kind = first, second
	if first == Layout then frame, kind = second, third end
	local source = Layout.StatueBands[kind]
	if source and frame and frame.IsShown and not frame:IsShown() then return {} end
	local f = source and Layout.FrameRectUI(frame)
	if not f then return nil end
	local result, w, h = {}, f.r - f.l, f.t - f.b
	for _, s in ipairs(source) do
		result[#result + 1] = { l = f.l + s[1] / 512 * w, r = f.l + s[3] / 512 * w,
			b = f.t - s[4] / 256 * h, t = f.t - s[2] / 256 * h }
	end
	return result
end

function Layout.SolveWing(first, second)
	local s = first == Layout and second or first
	if type(s) ~= "table" or (s.side ~= "micro" and s.side ~= "bags")
		or not rect(s.screen) or not number(s.bodyWidth) or s.bodyWidth <= 0
		or not number(s.bodyHeight) or s.bodyHeight <= 0
		or not number(s.requestedScale) or s.requestedScale <= 0 then return nil, "invalid-geometry" end
	local obstacles = statues(s)
	if not obstacles then return nil, "invalid-statue-geometry" end
	local padding = number(s.padding) and max(0, s.padding) or 2
	local height, width = s.bodyHeight + padding * 2, s.bodyWidth + padding * 2
	local piece = height / Layout.Atlas.channel
	local cap, join, base, artH = 44 * piece, 12 * piece, 6 * piece, 46 * piece
	-- Tile capacity is independent of the eventual fitted q: shrinking the whole
	-- composition cannot reduce its number of source tiles.
	if math.ceil(width / (Layout.Atlas.centerWidth * piece)) > Layout.MAX_CENTER_TILES then
		return nil, "too-many-center-tiles"
	end
	local screen, requested = s.screen, s.requestedScale
	local bottom = max(screen.b, number(s.bottom) and s.bottom or screen.b)
	local floor = min(requested, 0.5)
	local high = min(requested, (screen.t - 6 - bottom) / artH)
	if high < floor - EPS then return nil, "insufficient-wing-space" end
	local breaks, cb, ct = {}, base + padding, base + padding + s.bodyHeight
	for _, o in ipairs(obstacles) do
		breaks[#breaks + 1], breaks[#breaks + 2] = (o.b - bottom) / ct, (o.t - bottom) / cb
	end
	local function limits(q)
		local lower, upper, edge = {}, {}, nil
		if s.side == "micro" then
			lower = { line(screen.l + 6, width / 2), line(screen.l, width / 2 + cap * 0.6) }
			upper = { line(screen.r - 6, -width / 2 - join) }
		else
			lower = { line(screen.l + 6, width / 2 + join) }
			upper = { line(screen.r - 6, -width / 2), line(screen.r, -width / 2 - cap * 0.6) }
		end
		for _, o in ipairs(obstacles) do
			if intersectsY(bottom + cb * q, bottom + ct * q, o) then
				if s.side == "micro" then edge = min(edge or o.l, o.l)
				else edge = max(edge or o.r, o.r) end
			end
		end
		if edge then
			if s.side == "micro" then upper[#upper + 1] = line(edge, -s.bodyWidth / 2 - 4)
			else lower[#lower + 1] = line(edge, s.bodyWidth / 2 + 4) end
		end
		return lower, upper, edge
	end
	local points = partitions(floor, high, breaks)
	local bestQ, bestL, bestR, bestEdge
	local function consider(q)
		local lower, upper, edge = limits(q)
		local l, r = interval(lower, upper, q)
		if l and (not bestQ or q > bestQ) then bestQ, bestL, bestR, bestEdge = q, l, r, edge end
	end
	for i = #points, 1, -1 do
		consider(points[i])
		if i > 1 then
			local low, hi = points[i - 1], points[i]
			local lower, upper = limits((low + hi) / 2)
			local q = feasibleScale(lower, upper, low, hi)
			if q then consider(q) end
		end
	end
	if not bestQ then return nil, "insufficient-wing-space" end
	local q, preferred = bestQ, s.preferredCenterX
	if not number(preferred) then
		if bestEdge then
			local outward = (s.bodyWidth / 2 + 4) * q + (number(s.joinOffsetUI) and s.joinOffsetUI or 0)
			preferred = bestEdge + (s.side == "micro" and -outward or outward)
		else preferred = s.side == "micro" and bestL or bestR end
	end
	local cx = clamp(preferred, bestL, bestR)
	local bay = { l = cx - width * q / 2, r = cx + width * q / 2,
		b = bottom + base * q, t = bottom + (base + height) * q }
	local body = { l = cx - s.bodyWidth * q / 2, r = cx + s.bodyWidth * q / 2,
		b = bottom + cb * q, t = bottom + ct * q }
	local localL = -width / 2 - (s.side == "micro" and cap or join)
	local localR = width / 2 + (s.side == "micro" and join or cap)
	return { q = q, cx = cx, bottom = bottom, bodyUI = body, bayUI = bay,
		paintUI = { l = cx + localL * q, r = cx + localR * q, b = bottom, t = bottom + artH * q },
		paintLocal = { l = localL, r = localR, b = 0, t = artH }, localWidth = width,
		totalWidth = width + cap + join, bayHeight = height, capWidth = cap, joinWidth = join,
		artHeight = artH, baseHeight = base, pieceScale = piece, requestedScale = requested,
		fitScale = q / requested, fitted = q < requested - EPS,
		status = q < requested - EPS and "fitted" or "requested", side = s.side }
end

function Layout.SolveBelt(first, second)
	local s = first == Layout and second or first
	if type(s) ~= "table" then return nil, "invalid-geometry" end
	local B, row, shelf = s.localPaint or s.beltLocalPaint, s.bagRow or s.bodyUI, s.bagShelf or s.paintUI
	local requested = s.requestedScale or s.requestedBeltScale
	if not rect(B) or not rect(row) or not rect(shelf) or not rect(s.screen)
		or not number(requested) or requested <= 0 then return nil, "invalid-geometry" end
	local obstacles = statues(s)
	if not obstacles then return nil, "invalid-statue-geometry" end
	local screen, floor = s.screen, min(requested, 0.5)
	local gap = max(4, number(s.userGap) and s.userGap or 6)
	local baseBottom = shelf.t + gap
	local preferredCenter = (row.l + row.r) / 2 + (number(s.userOffsetX) and s.userOffsetX or 0)
	local height = B.t - B.b
	local function fitAt(paintedBottom)
		local high = min(requested, (screen.t - 6 - paintedBottom) / height)
		if high < floor - EPS or paintedBottom < screen.b + 6 - EPS then return nil end
		local breaks = {}
		for _, o in ipairs(obstacles) do breaks[#breaks + 1] = (o.b - 4 - paintedBottom) / height end
		local points, best = partitions(floor, high, breaks), nil
		local function lanes(q)
			local active = {}
			for _, o in ipairs(obstacles) do
				if intersectsY(paintedBottom, paintedBottom + height * q, o, 4) then active[#active + 1] = o end
			end
			table.sort(active, function(a, b) return a.l < b.l end)
			local result, previousRight = {}, nil
			for i = 1, #active + 1 do
				local lower = { line(screen.l + 6, -B.l), line(row.l, -(B.l + B.r) / 2) }
				local upper = { line(screen.r - 6, -B.r), line(row.r, -(B.l + B.r) / 2) }
				if previousRight then lower[#lower + 1] = line(previousRight + 4, -B.l) end
				if active[i] then upper[#upper + 1] = line(active[i].l - 4, -B.r) end
				result[#result + 1] = { lower, upper }
				if active[i] then previousRight = max(previousRight or active[i].r, active[i].r) end
			end
			return result
		end
		local function consider(q)
			for _, lane in ipairs(lanes(q)) do
				local l, r = interval(lane[1], lane[2], q)
				if l then
					local x = clamp(preferredCenter - (B.l + B.r) * q / 2, l, r)
					local distance = abs(x + (B.l + B.r) * q / 2 - preferredCenter)
					if not best or q > best.q + EPS or (abs(q - best.q) <= EPS and distance < best.distance) then
						best = { x = x, y = paintedBottom - B.b * q, q = q, distance = distance,
							paintUI = { l = x + B.l * q, r = x + B.r * q,
								b = paintedBottom, t = paintedBottom + height * q } }
					end
				end
			end
		end
		for i = #points, 1, -1 do
			consider(points[i])
			if i > 1 then
				local low, hi = points[i - 1], points[i]
				for _, lane in ipairs(lanes((low + hi) / 2)) do
					local q = feasibleScale(lane[1], lane[2], low, hi)
					if q then consider(q) end
				end
			end
		end
		return best
	end
	local best = fitAt(baseBottom)
	local maxRaise = number(s.maxRaise) and max(0, s.maxRaise) or 24
	if not best then
		local candidates = {}
		for _, o in ipairs(obstacles) do
			local y = o.t + 4
			if y > baseBottom + EPS and y <= baseBottom + maxRaise + EPS then candidates[#candidates + 1] = y end
		end
		table.sort(candidates)
		for _, y in ipairs(candidates) do best = fitAt(y); if best then break end end
	end
	if not best then return nil, "insufficient-belt-space" end
	best.requestedScale, best.fitScale = requested, best.q / requested
	best.fitted, best.raised = best.q < requested - EPS, best.paintUI.b > baseBottom + EPS
	best.shifted = best.distance > EPS
	best.status = best.raised and (best.fitted and "raised-fitted" or "raised")
		or (best.fitted and "fitted" or (best.shifted and "shifted" or "requested"))
	best.distance = nil
	return best
end

-- Preflight before the caller mutates anchors/scales or commits a bag/belt pair.
function Layout.CanRender(first, second, third)
	local s, side = first, second
	if first == Layout then s, side = second, third end
	if type(s) ~= "table" then return nil, "missing-render-geometry" end
	side = side or s.side
	if side ~= "micro" and side ~= "bags" then return nil, "invalid-side" end
	for _, key in ipairs({ "pieceScale", "localWidth", "capWidth", "joinWidth", "artHeight", "totalWidth" }) do
		if not number(s[key]) or s[key] <= 0 then return nil, "invalid-render-geometry" end
	end
	local count = math.ceil(s.localWidth / (Layout.Atlas.centerWidth * s.pieceScale))
	if count > Layout.MAX_CENTER_TILES then return nil, "too-many-center-tiles" end
	return true, count
end

-- The caller owns the dock's actual scale and UIParent anchoring. Its bottom
-- center remains the opening center; selection overlays should use dock.art.
function Layout.Render(first, second, third, fourth)
	local dock, s, side = first, second, third
	if first == Layout then dock, s, side = second, third, fourth end
	if not dock or not s then return nil, "missing-render-geometry" end
	side = side or s.side
	local ready, count = Layout.CanRender(s, side)
	if not ready then return nil, count end
	local tileWidth = Layout.Atlas.centerWidth * s.pieceScale
	if dock.art and not dock.art.__wingV2 then dock.art:Hide(); dock.art = nil end
	local art = dock.art
	if not art then
		art = CreateFrame("Frame", nil, dock)
		art.__wingV2, art.parts = true, {}
		if art.EnableMouse then art:EnableMouse(false) end
		art:SetFrameLevel(dock:GetFrameLevel())
		dock.art = art
	end
	dock:SetSize(s.localWidth, s.artHeight)
	art:ClearAllPoints()
	art:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", -(side == "micro" and s.capWidth or s.joinWidth), 0)
	art:SetSize(s.totalWidth, s.artHeight)
	local used = 0
	local function piece(source, x, width, fraction)
		used = used + 1
		local texture = art.parts[used]
		if not texture then
			texture = art:CreateTexture(nil, "BACKGROUND", nil, -6)
			texture:SetTexture(MEDIA)
			art.parts[used] = texture
		end
		local l, r = source[1] / 256, source[3] / 256
		if side == "bags" then l, r = r, r - (r - l) * (fraction or 1)
		else r = l + (r - l) * (fraction or 1) end
		texture:ClearAllPoints()
		texture:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", x, 0)
		texture:SetSize(width, s.artHeight)
		texture:SetTexCoord(l, r, source[2] / 128, source[4] / 128)
		texture:Show()
	end
	local start
	if side == "micro" then
		piece(Layout.Atlas.cap, 0, s.capWidth)
		start = s.capWidth
		piece(Layout.Atlas.join, start + s.localWidth, s.joinWidth)
	else
		piece(Layout.Atlas.join, 0, s.joinWidth)
		start = s.joinWidth
		piece(Layout.Atlas.cap, start + s.localWidth, s.capWidth)
	end
	local remaining, x = s.localWidth, start
	for _ = 1, count do
		local width = min(tileWidth, remaining)
		piece(Layout.Atlas.center, x, width, width / tileWidth)
		x, remaining = x + width, remaining - width
	end
	for i = used + 1, #art.parts do art.parts[i]:Hide() end
	art:Show()
	dock.paintBounds, dock.bodyBounds, dock.bayBounds = s.paintUI, s.bodyUI, s.bayUI
	dock.wingSolution, dock.fitStatus = s, s.status
	return true
end
