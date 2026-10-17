
-- rLib: core
-- zork, 2016

-----------------------------
-- Variables
-----------------------------

local A, L = ...
L.addonName = A

-- Shared protection state tracker (single instance for entire addon)
Roth_UI_Protection = Roth_UI_Protection or {}
if not Roth_UI_Protection._initialized then
  Roth_UI_Protection._initialized = true
  Roth_UI_Protection.isLoggingOut = false
  Roth_UI_Protection.isGameMenuOpen = false

  -- PLAYER_LEAVING_WORLD fires on EVERY zone/instance/BG transition (just
  -- before the load screen), not only on real logout. Without resetting the
  -- flag on PLAYER_ENTERING_WORLD, isLoggingOut stays true permanently after
  -- the first zone change, and every consumer (MovableBuffs / MovableDebuffs
  -- OnUpdate processors, oUF_Smooth, framefader, etc.) silently bails on
  -- their work for the rest of the session — buffs don't re-anchor, smooth
  -- bars don't update, etc.
  local pf = CreateFrame("Frame")
  pf:RegisterEvent("PLAYER_LOGOUT")
  pf:RegisterEvent("PLAYER_LEAVING_WORLD")
  pf:RegisterEvent("PLAYER_ENTERING_WORLD")
  pf:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
      -- We made it through the load screen; we weren't actually logging
      -- out. Real logout doesn't fire PLAYER_ENTERING_WORLD afterward.
      Roth_UI_Protection.isLoggingOut = false
    else
      Roth_UI_Protection.isLoggingOut = true
    end
  end)

  local gmt = CreateFrame("Frame")
  gmt:SetScript("OnUpdate", function()
    if GameMenuFrame then
      Roth_UI_Protection.isGameMenuOpen = GameMenuFrame:IsShown()
    end
  end)
end

local function IsProtectedState()
  return Roth_UI_Protection.isLoggingOut or Roth_UI_Protection.isGameMenuOpen or InCombatLockdown()
end

-----------------------------
-- rLib Global
-----------------------------

rLib = {}
rLib.addonName = A

-----------------------------
-- Functions
-----------------------------

--rLib:CopyTable
function rLib:CopyTable(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[rLib:CopyTable(orig_key)] = rLib:CopyTable(orig_value)
    end
    setmetatable(copy, rLib:CopyTable(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

--rLib:RegisterCallback
function rLib:RegisterCallback(event, callback, ...)
  if not self.eventFrame then
    self.eventFrame = CreateFrame("Frame")
    function self.eventFrame:OnEvent(event, ...)
      -- Don't execute callbacks during protected states
      if IsProtectedState() then return end
      for callback, args in next, self.callbacks[event] do
        -- Double-check before each callback
        if not IsProtectedState() then
          local success = pcall(callback, args, ...)
          -- Silently ignore errors during protected transitions
        end
      end
    end
    self.eventFrame:SetScript("OnEvent", self.eventFrame.OnEvent)
  end
  if not self.eventFrame.callbacks then self.eventFrame.callbacks = {} end
  if not self.eventFrame.callbacks[event] then self.eventFrame.callbacks[event] = {} end
  self.eventFrame.callbacks[event][callback] = {...}
  self.eventFrame:RegisterEvent(event)
end

--rLib:CallElementFunction
function rLib:CallElementFunction(element, func, ...)
  if element and func and element[func] then
    element[func](element, ...)
  end
end

--L:GetPoint
function L:GetPoint(frame)
  if not frame then return end
  local point = {}
  point.a1, point.af, point.a2, point.x, point.y = frame:GetPoint()
  if point.af and point.af:GetName() then
    point.af = point.af:GetName()
  end
  return point
end

--L:GetSize
function L:GetSize(frame)
  if not frame then return end
  local size = {}
  size.w, size.h = frame:GetWidth(), frame:GetHeight()
  return size
end

--L:ResetPoint
function L:ResetPoint(frame)
  if not frame then return end
  if not frame.defaultPoint then return end
  if InCombatLockdown() then return end
  local point = frame.defaultPoint
  frame:ClearAllPoints()
  if point.af and point.a2 then
    frame:SetPoint(point.a1 or "CENTER", point.af, point.a2, point.x or 0, point.y or 0)
  elseif point.af then
    frame:SetPoint(point.a1 or "CENTER", point.af, point.x or 0, point.y or 0)
  else
    frame:SetPoint(point.a1 or "CENTER", point.x or 0, point.y or 0)
  end
end

--L:ResetSize
function L:ResetSize(frame)
  if not frame then return end
  if not frame.defaultSize then return end
  if InCombatLockdown() then return end
  frame:SetSize(frame.defaultSize.w,frame.defaultSize.h)
end

--L:UnlockFrame
function L:UnlockFrame(frame)
  if not frame then return end
  if not frame:IsUserPlaced() then return end
  frame.dragFrame:Show()
end

--L:LockFrame
function L:LockFrame(frame)
  if not frame then return end
  if not frame:IsUserPlaced() then return end
  frame.dragFrame:Hide()
end

--L:UnlockFrames
function L:UnlockFrames(frames,str)
  if not frames then return end
  for idx, frame in next, frames do
    self:UnlockFrame(frame)
  end
  print(str)
end

--L:LockFrames
function L:LockFrames(frames,str)
  if not frames then return end
  for idx, frame in next, frames do
    self:LockFrame(frame)
  end
  print(str)
end

--L:ResetFrames
function L:ResetFrames(frames,str)
  if not frames then return end
  if InCombatLockdown() then
    print("|c00FF0000ERROR:|r "..str.." not allowed while in combat!")
    return
  end
  for idx, frame in next, frames do
    self:ResetPoint(frame)
    self:ResetSize(frame)
  end
  print(str)
end

