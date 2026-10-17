local parent, ns = ...
local oUF = ns.oUF
local Secrets = ns.Secrets

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- Edit Mode frames on WoW Forever (16001) carry the original C Hide as "HideBase";
-- calling their overridden Hide would write into the Edit Mode manager, and
-- hiding a managed one re-lays its container from our context. ns.Blizz
-- (core/blizzsafe.lua) handles both.
local function SafeHide(frame)
	if not frame then return end
	ns.Blizz.Conceal(frame)
end

local function UnregisterChild(child)
	if child and child.UnregisterAllEvents then
		child:UnregisterAllEvents()
	end
end

local HandleFrame = function(baseName)
	local frame
	if type(baseName) == "string" then
		frame = _G[baseName]
	else
		frame = baseName
	end

	if frame then
		frame:UnregisterAllEvents()
		if InCombatLockdown and InCombatLockdown() then
			frame:SetAlpha(0)
			return
		end

		frame:SetAlpha(0)
		if frame.EnableMouse then
			pcall(frame.EnableMouse, frame, false)
		end
		SafeHide(frame)
		-- reparenting hides a managed frame just the same (its OnHide runs)
		if not ns.Blizz.IsManagedFrame(frame) and not (Secrets and Secrets.Bool(frame.IsProtected, frame) ~= false) then
			pcall(frame.SetParent, frame, hiddenParent)
		end

		local health = frame.healthBar or frame.healthbar or frame.HealthBar or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar)
		local power = frame.manabar or frame.ManaBar or frame.PowerBar
		local spell = frame.spellbar or frame.castBar or frame.CastingBarFrame
		local altpowerbar = frame.powerBarAlt or frame.PowerBarAlt
		local buffFrame = frame.BuffFrame or frame.AurasFrame
		local debuffFrame = frame.DebuffFrame

		UnregisterChild(health)
		UnregisterChild(power)
		UnregisterChild(spell)
		UnregisterChild(altpowerbar)
		UnregisterChild(buffFrame)
		UnregisterChild(debuffFrame)
	end
end

function oUF:DisableBlizzard(unit)
	if not unit then return end

	if unit == "player" then
		HandleFrame(PlayerFrame)
		if PlayerFrame then
			PlayerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
			PlayerFrame:RegisterEvent("UNIT_ENTERING_VEHICLE")
			PlayerFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
			PlayerFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
			PlayerFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
		end
	elseif unit == "pet" then
		HandleFrame(PetFrame)
	elseif unit == "target" then
		HandleFrame(TargetFrame)
		HandleFrame(ComboFrame)
	elseif unit == "focus" then
		HandleFrame(FocusFrame)
		HandleFrame(TargetofFocusFrame)
	elseif unit == "targettarget" then
		HandleFrame(TargetFrameToT)
	elseif unit:match("(boss)%d?$") == "boss" then
		local id = unit:match("boss(%d)")
		if id then
			HandleFrame("Boss" .. id .. "TargetFrame")
		else
			for i = 1, 5 do
				HandleFrame(("Boss%dTargetFrame"):format(i))
			end
		end
	elseif unit:match("(party)%d?$") == "party" then
		-- Do not taint CompactPartyFrame / PartyFrame during combat
	end
end
