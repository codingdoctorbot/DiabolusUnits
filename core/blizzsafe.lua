-- Blizzard frame helpers: bypass Edit Mode Lua overrides with *Base methods.
-- Calling the overrides from addon code can taint shared layout state and input handling.
-- Base calls do not update Edit Mode's layout; callers must reapply placement as needed.

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

-- Managed frames stay shown but transparent and mouse-inert: OnHide would relayout
-- shared containers in addon context. Others use the base Hide method.
-- Blizzard may restore managed-frame alpha later; no per-frame method hooks are installed.
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
