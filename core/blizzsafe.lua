---------------------------------------------
--  Roth_UI - calls on Blizzard frames that leave the game's code untainted
---------------------------------------------
-- WoW Forever's Edit Mode system frames (MinimapCluster, ChatFrame1,
-- PlayerFrame, TargetFrame, PlayerCastingBarFrame, the status tracking bars,
-- LootFrame, BuffFrame, ...) replace SetPoint, ClearAllPoints, SetScale, Hide
-- and SetShown with Lua overrides (Blizzard_EditMode EditModeSystemTemplates
-- .lua, SetupAnchorOverrides / SetupVisibilityFunctionOverrides). Those write
-- into EditModeManagerFrame (editModeSystemAnchorDirty, snapped frames) and,
-- for managed frames, re-lay the bottom/right managed containers. Called from
-- add-on code every one of those writes is tainted, and the next time the
-- game reads them all Edit Mode systems run tainted: the buff frame's timers
-- then fail on secret durations in combat, and the gamepad binding stack's
-- SetPreferredGamepadInteractTarget is blocked (the loot / popup freeze).
--
-- The original C methods stay on each system frame as plain fields
-- (SetPointBase, ClearAllPointsBase, SetScaleBase, HideBase). Calling those
-- moves or hides the frame without running any Blizzard Lua. Edit Mode is
-- then unaware of the move; it re-applies its own layout on Edit Mode exit or
-- a layout switch, and the callers here re-apply theirs on their own events.

local _, ns = ...

local Blizz = {}
ns.Blizz = Blizz

-- The C method behind an Edit Mode override, or the frame's own method.
local function Base(frame, method)
	local base = rawget(frame, method .. "Base")
	if type(base) == "function" then
		return base
	end
	return frame[method]
end

-- True for frames that carry Edit Mode's method overrides.
function Blizz.IsSystemFrame(frame)
	return type(frame) == "table" and type(rawget(frame, "SetPointBase")) == "function"
end

-- True for Edit Mode frames laid out by a managed container: hiding one runs
-- ManagedFrameMixin.OnHide -> container:RemoveManagedFrame -> Layout().
function Blizz.IsManagedFrame(frame)
	return type(frame) == "table" and rawget(frame, "isManagedFrame") == true
end

function Blizz.SetPoint(frame, ...)
	return Base(frame, "SetPoint")(frame, ...)
end

function Blizz.ClearAllPoints(frame)
	return Base(frame, "ClearAllPoints")(frame)
end

function Blizz.SetScale(frame, scale)
	return Base(frame, "SetScale")(frame, scale)
end

local function NoMouse(frame)
	if frame.EnableMouse then
		pcall(frame.EnableMouse, frame, false)
	end
end

-- Hides a Blizzard frame from add-on code with the least Blizzard Lua run.
-- Managed frames are not hidden at all (their OnHide re-lays the managed
-- container in our context): they are made invisible and inert instead
-- (alpha 0, no mouse on them or their children). Their own methods are not
-- hooked (a hooked method on a Forever plate frame came back nil), so the
-- managed-frame system may restore their alpha when the override bar
-- switches (they stay faded again from the next login or /reload).
-- Everything else gets the C Hide; its OnHide script still runs, which for
-- plain Edit Mode systems only clears a selection.
function Blizz.Conceal(frame)
	if not frame then
		return
	end
	frame:SetAlpha(0)
	NoMouse(frame)
	if Blizz.IsManagedFrame(frame) then
		for _, child in ipairs({ frame:GetChildren() }) do
			NoMouse(child)
		end
		return
	end
	Base(frame, "Hide")(frame)
end
