--  Roth_UI - group member status icon
-- One icon in the middle of a group frame, in the priority order of
-- Blizzard's compact frames (CompactUnitFrame_GetCenterStatusIconState):
--
--   summon pending / accepted / declined
--   resurrection on the way
--   in another phase (only when the member is in range, as Blizzard does)
--   away (AFK), as text in Roth's font
--
-- UnitPhaseReason and UnitIsAFK can be secret (identity restriction, chat
-- lockdown); a secret answer counts as "no status" and is never tested.

local _, ns = ...

local cfg = ns.cfg
local Secrets = ns.Secrets

local Status = {}
ns.Status = Status

local summonAtlas, summonEnum
local function SummonAtlas(status)
	local e = Enum and Enum.SummonStatus
	if not e then
		return nil
	end
	if e ~= summonEnum then
		summonEnum = e
		summonAtlas = {
			[e.Pending] = "RaidFrame-Icon-SummonPending",
			[e.Accepted] = "RaidFrame-Icon-SummonAccepted",
			[e.Declined] = "RaidFrame-Icon-SummonDeclined",
		}
	end
	return status ~= nil and summonAtlas[status] or nil
end

local function Plain(fn, ...)
	if not fn then
		return nil
	end
	local ok, v = pcall(fn, ...)
	if not ok or Secrets.IsSecret(v) then
		return nil
	end
	return v
end

-- What the icon shows for a unit: an atlas name, "AFK" or nil.
function Status.State(unit)
	if not unit or not UnitExists(unit) then
		return nil
	end
	local summon = C_IncomingSummon
	if summon and Plain(summon.HasIncomingSummon, unit) then
		local atlas = SummonAtlas(Plain(summon.IncomingSummonStatus, unit))
		if atlas then
			return atlas
		end
	end
	if Plain(UnitHasIncomingResurrection, unit) then
		return "RaidFrame-Icon-Rez"
	end
	if Plain(UnitInRange, unit) and Plain(UnitPhaseReason, unit) then
		return "RaidFrame-Icon-Phasing"
	end
	if Plain(UnitIsAFK, unit) and not UnitIsUnit(unit, "player") then
		return "AFK"
	end
	return nil
end

function Status.Update(frame)
	local s = frame.RothStatus
	if not s then
		return
	end
	local state = Status.State(frame.__unit)
	if state == "AFK" then
		s.icon:Hide()
		s.text:Show()
	elseif state then
		s.icon:SetAtlas(state)
		s.icon:Show()
		s.text:Hide()
	else
		s.icon:Hide()
		s.text:Hide()
	end
end

local EVENTS = {
	"INCOMING_SUMMON_CHANGED",
	"INCOMING_RESURRECT_CHANGED",
	"UNIT_PHASE",
	"UNIT_FLAGS",
	"PLAYER_FLAGS_CHANGED",
	"UNIT_CONNECTION",
}

local function OnEvent(frame, _, unit)
	if unit == nil or Secrets.IsSecret(unit) or unit == frame.__unit then
		Status.Update(frame)
	end
end

-- parent: the region to centre on (the health bar).
function Status.Attach(frame, parent, size)
	if frame.RothStatus then
		return frame.RothStatus
	end
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetAllPoints(parent)
	holder:SetFrameLevel(parent:GetFrameLevel() + 6)
	local icon = holder:CreateTexture(nil, "OVERLAY", nil, 5)
	icon:SetSize(size, size)
	icon:SetPoint("CENTER")
	icon:Hide()
	local text = holder:CreateFontString(nil, "OVERLAY")
	text:SetFont(cfg.font, 11, "THINOUTLINE")
	text:SetPoint("CENTER")
	text:SetTextColor(0.9, 0.2, 0.1)
	text:SetText(AFK or "AFK")
	text:Hide()
	frame.RothStatus = { holder = holder, icon = icon, text = text }
	for _, event in ipairs(EVENTS) do
		frame:RegisterEvent(event, OnEvent)
	end
	return frame.RothStatus
end
