-- Party column built on units/group.lua: player and party1..4, sorted by party index.

local _, ns = ...

local oUF = ns.oUF or oUF
local cfg = ns.cfg
local Group = ns.Group
local Secrets = ns.Secrets

if not cfg.units.party.show then
	return
end

local function CreateStyle(self)
	Group.Style(self, "party")
end

oUF:RegisterStyle("diablo:party", CreateStyle)
oUF:SetActiveStyle("diablo:party")

local pcfg = cfg.units.party
local attr = pcfg.attributes
local anchor = Group.CreateAnchor("Roth_UIPartyDragFrame", pcfg.pos)

local party = oUF:SpawnHeader(
	"Roth_UIPartyHeader",
	nil,
	attr.visibility,
	"showPlayer",
	attr.showPlayer,
	"showSolo",
	attr.showSolo,
	"showParty",
	attr.showParty,
	"showRaid",
	attr.showRaid,
	"point",
	attr.point,
	"yOffset",
	attr.yOffset,
	"sortMethod",
	"INDEX",
	"oUF-initialConfigFunction",
	Group.InitialConfig("party", 1)
)
party:SetScale(pcfg.scale)
party:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
ns.partyHeader = party

-- Arena: hide the column while inside one (state drivers change out of combat).
if attr.hideInArena then
	local watcher = CreateFrame("Frame")
	local pendingVisibility
	watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	watcher:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			if pendingVisibility and not InCombatLockdown() then
				RegisterStateDriver(party, "visibility", pendingVisibility)
				pendingVisibility = nil
			end
			return
		end
		local isArena = false
		if C_PvP and type(C_PvP.IsArena) == "function" then
			isArena = Secrets.Boolean(C_PvP.IsArena(), false)
		end
		local vis = isArena and "hide" or attr.visibility
		if InCombatLockdown() then
			pendingVisibility = vis
		else
			pendingVisibility = nil
			RegisterStateDriver(party, "visibility", vis)
		end
	end)
end
