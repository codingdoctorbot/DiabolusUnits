---------------------------------------------
--  Roth_UI - private aura slots on group frames
---------------------------------------------
-- Boss mechanics marked private (C_UnitAuras private auras) never reach
-- addon code: UnitAura does not list them and their fields cannot be read.
-- The client draws them itself into frames we offer as anchors
-- (C_UnitAuras.AddPrivateAuraAnchor), so the mechanic shows on Roth's frame
-- as on Blizzard's. Nothing about the aura is read here.
--
-- Anchors are per unit token: when a header frame changes unit they are
-- removed and added again. Grid2 (modules/IndicatorPrivateAuras.lua) waits
-- for the end of combat to do that; so does this.

local _, ns = ...

local PrivateAuras = {}
ns.PrivateAuras = PrivateAuras

local MAX = 2

local pending = {}
local waiter = CreateFrame("Frame")

local function Clear(slots)
	local remove = C_UnitAuras and C_UnitAuras.RemovePrivateAuraAnchor
	for i, id in ipairs(slots.ids) do
		if remove then
			pcall(remove, id)
		end
		slots.ids[i] = nil
	end
	slots.unit = nil
end

function PrivateAuras.Update(frame)
	local slots = frame.RothPrivateAuras
	local add = C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor
	if not (slots and add) then
		return
	end
	local unit = frame.unit
	if unit == slots.unit then
		return
	end
	if InCombatLockdown() then
		pending[frame] = true
		waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	Clear(slots)
	if not unit then
		return
	end
	for i, slot in ipairs(slots.frames) do
		local ok, id = pcall(add, {
			unitToken = unit,
			auraIndex = i,
			parent = slot,
			showCooldownFrame = true,
			showCountdownNumbers = false,
			iconInfo = {
				iconAnchor = { point = "CENTER", relativeTo = slot, relativePoint = "CENTER", offsetX = 0, offsetY = 0 },
				iconWidth = slots.size,
				iconHeight = slots.size,
			},
		})
		if ok and id then
			slots.ids[#slots.ids + 1] = id
		end
	end
	slots.unit = unit
end

waiter:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	for frame in pairs(pending) do
		pending[frame] = nil
		PrivateAuras.Update(frame)
	end
end)

-- Two slots inside the right end of the health bar (the middle holds the
-- ready check and status icons). Grid2 notes the client may draw private
-- auras under the unit frame after re-anchoring: the slots sit one strata
-- higher.
function PrivateAuras.Attach(frame, parent, size)
	if frame.RothPrivateAuras or not (C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor) then
		return
	end
	local slots = { frames = {}, ids = {}, size = size }
	for i = 1, MAX do
		local slot = CreateFrame("Frame", nil, parent)
		slot:SetSize(size, size)
		slot:SetPoint("RIGHT", parent, "RIGHT", -2 - (i - 1) * (size + 2), 0)
		slot:SetFrameStrata("MEDIUM")
		slots.frames[i] = slot
	end
	frame.RothPrivateAuras = slots
	PrivateAuras.Update(frame)
end
