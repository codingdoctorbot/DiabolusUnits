-- Move the active layout horizontally with profile.groupOffsetX.
-- Reanchor UIParent-relative frames to Roth_UILayoutShift; descendants follow.
-- Saved positions stay relative to UIParent so the offset is not applied twice.

local _, ns = ...

local LayoutShift = {}
ns.LayoutShift = LayoutShift

LayoutShift.LIMIT = 600

-- group frames sit at the screen sides and keep their place
local SKIP = {
 Roth_UITooltipAnchor = true,
	Roth_UIPartyDragFrame = true,
	Roth_UIRaidDragFrame = true,
	Roth_UIBossFrame1 = true,
}

local anchor = CreateFrame("Frame", "Roth_UILayoutShift", UIParent)
anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
LayoutShift.anchor = anchor

local hooked = {}
local queued, syncing, pending = false, false, false
local applied = 0 -- offset the anchor currently has

local function Clamp(x)
	local limit = LayoutShift.LIMIT
	return math.max(-limit, math.min(limit, math.floor(x + 0.5)))
end

function LayoutShift:Get()
	local db = ns.LayoutProfile and ns.LayoutProfile()
	local x = db and db.groupOffsetX
	return type(x) == "number" and Clamp(x) or 0
end

-- Points on UIParent (or the screen, after a drag) move to the shift anchor.
-- A drag leaves screen coordinates that already include the offset; take it back out
-- (offsets are in the frame's own scale, the shift in UIParent units).
local function Rehome(f, dragged)
	local n = f:GetNumPoints()
	if n == 0 then
		return
	end
	local points, changed = {}, false
	local dx = dragged and LayoutShift:Get() * UIParent:GetEffectiveScale() / f:GetEffectiveScale() or 0
	for i = 1, n do
		local p, rel, rp, x, y = f:GetPoint(i)
		if rel == nil or rel == UIParent then
			rel, changed = anchor, true
			x = (x or 0) - dx
		end
		points[i] = { p, rel, rp or p, x or 0, y or 0 }
	end
	if not changed then
		return
	end
	syncing = true
	f:ClearAllPoints()
	for _, point in ipairs(points) do
		f:SetPoint(unpack(point))
	end
	syncing = false
	return true
end

-- Layout code places frames on UIParent at any time (mode changes, bag updates for the
-- belt, edit layout sliders); move them across on the next frame.
local function NeedsSync()
	local x = LayoutShift:Get()
	if applied ~= x then return true end
	if x == 0 then return false end
	for _, entry in ipairs(ns.EditMode.FRAMES) do
		local f = not SKIP[entry.id] and rawget(_G, entry.id)
		if f and f.GetNumPoints then
			for i = 1, f:GetNumPoints() do
				local _, relative = f:GetPoint(i)
				if relative == nil or relative == UIParent then return true end
			end
		end
	end
	return false
end

local function Queue(frame, point, relative)
	-- Explicit group-anchor and descendant placement already inherit the shift.
	if frame and relative and relative ~= UIParent then return end
	-- also when the other layout's offset is still applied (keyboard <-> gamepad)
	if syncing or queued or (applied == 0 and LayoutShift:Get() == 0) then
		return
	end
	queued = true
	C_Timer.After(0, function()
		queued = false
		if NeedsSync() then LayoutShift:Sync() end
	end)
end

local function MarkDragged(f)
	f.layoutShiftDragged = true
end

local function Hook(f)
	if hooked[f] then
		return
	end
	hooked[f] = true
	hooksecurefunc(f, "SetPoint", Queue)
	hooksecurefunc(f, "StartMoving", MarkDragged)
end

function LayoutShift:Sync(skipRequest)
	queued = false
	-- unit frames and the belt are protected
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local x = self:Get()
	local changed = applied ~= x
	syncing = true
	anchor:ClearAllPoints()
	anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)
	anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", x, 0)
	applied = x
	syncing = false
	for _, entry in ipairs(ns.EditMode.FRAMES) do
		local f = not SKIP[entry.id] and rawget(_G, entry.id)
		if f and f.GetNumPoints then
			Hook(f)
			if x ~= 0 then
				changed = Rehome(f) or changed
			end
		end
	end
	-- the edit layout toolbar shows the offset of the layout now in use
	if ns.EditMode.UpdateTopBar then
		ns.EditMode:UpdateTopBar()
	end
	-- Coordinator calls Sync(true) before measuring. External shifts need a fresh
	-- screen-edge fit after their anchor has reached its final position.
	if changed and not skipRequest and ns.StandardMode and ns.StandardMode.RequestLayout then
		ns.StandardMode:RequestLayout("layout-group-shift")
	end
end

-- Called by EditMode:SaveFramePosition before it reads the frame's point
function LayoutShift:AfterMove(f)
	if not f.layoutShiftDragged then
		return
	end
	f.layoutShiftDragged = nil
	if hooked[f] and self:Get() ~= 0 and not InCombatLockdown() then
		Rehome(f, true)
	end
end

function LayoutShift:Set(x)
	if InCombatLockdown() then
		return
	end
	local db = ns.LayoutProfile and ns.LayoutProfile()
	if not db then
		return
	end
	x = Clamp(x or 0)
	db.groupOffsetX = x ~= 0 and x or nil
	self:Sync()
end

function LayoutShift:Nudge(delta)
	self:Set(self:Get() + delta)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then
			LayoutShift:Sync()
		end
		return
	end
	-- The coordinator performs the ordered sync; do not shift a fitted HUD later.
	if ns.StandardMode and ns.StandardMode.RequestLayout then
		ns.StandardMode:RequestLayout("layout-group-event")
	else
		Queue()
	end
end)
