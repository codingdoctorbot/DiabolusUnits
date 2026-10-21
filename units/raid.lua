-- Raid frames based on zork's oUF_Diablo wow6.0 layout and units/group.lua.
-- One five-member column per raid group; cfg.units.raid.layout selects tiles or bars.

local _, ns = ...

local oUF = ns.oUF or oUF
local cfg = ns.cfg
local Group = ns.Group

if not cfg.units.raid.show then
	return
end

local function CreateStyle(self)
	Group.Style(self, "raid")
end

oUF:RegisterStyle("diablo:raid", CreateStyle)
oUF:SetActiveStyle("diablo:raid")

local rcfg = cfg.units.raid
local attr = rcfg.attributes
local anchor = Group.CreateAnchor("Roth_UIRaidDragFrame", rcfg.pos)

-- Tiles touch edge to edge with a small gap; the bar art overlaps (zork's offsets).
local tiles = Group.Layout("raid").tile
local spacing = tiles and ((rcfg.tiles and rcfg.tiles.spacing) or 4) or nil
local yOffset = tiles and -spacing or attr.yOffset
local columnGap = tiles and spacing or (attr.columnSpacing or 0)

local groups = {}
for i = 1, (NUM_RAID_GROUPS or 8) do
	local header = oUF:SpawnHeader(
		"Roth_UIRaidGroup" .. i,
		nil,
		attr.visibility,
		"showPlayer", attr.showPlayer,
		"showSolo", attr.showSolo,
		"showParty", attr.showParty,
		"showRaid", attr.showRaid,
		"point", attr.point,
		"yOffset", yOffset,
		"groupFilter", tostring(i),
		"unitsPerColumn", 5,
		"oUF-initialConfigFunction", Group.InitialConfig("raid", 1)
	)
	-- Scale the header, not the members, so column spacing stays in one unit.
	header:SetScale(rcfg.scale)
	if i == 1 then
		header:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
	else
		local prev = groups[i - 1]
		local gap = columnGap
		if attr.columnAnchorPoint == "RIGHT" then
			header:SetPoint("TOPRIGHT", prev, "TOPLEFT", -gap, 0)
		else
			header:SetPoint("TOPLEFT", prev, "TOPRIGHT", gap, 0)
		end
	end
	groups[i] = header
end

ns.raidHeaders = groups
