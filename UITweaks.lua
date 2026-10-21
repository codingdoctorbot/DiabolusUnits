-- Conceal default cast/status bars and move loot rolls above the action bars.

local addon, ns = ...
local cfg = ns.cfg

-- Configuration options (edit these to customize)
local HIDE_CAST_BAR = true        -- Hide Blizzard's default cast bar
local HIDE_XP_BAR = true          -- Completely hide the XP/rep bar
local SCALE_XP_BAR = false        -- Scale the XP/rep bar smaller (disabled since hiding)
local XP_BAR_SCALE = 0.5          -- Scale factor (0.5 = 50% size)
local XP_BAR_POSITION = {         -- Position for the XP bar
  point = "BOTTOM",
  relativePoint = "BOTTOM",
  x = 0,
  y = 2,
}

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGIN")

local setupDone = false
local setupTimer = 0
local setupDelay = 0.5

local function SetupTweaks()
  if setupDone then return end
  if InCombatLockdown() then return end
  
  -- Hide default cast bar
  if HIDE_CAST_BAR then
    -- Modern WoW cast bar names
    local castBars = {
      "PlayerCastingBarFrame",
      "CastingBarFrame", 
      "PetCastingBarFrame",
    }
    
    -- Without its events the bar never shows again. ns.Blizz.Conceal keeps
    -- PlayerCastingBarFrame's Edit Mode Hide override (and, when it is a
    -- managed frame, the managed container's layout) out of our context.
    for _, barName in ipairs(castBars) do
      local bar = _G[barName]
      if bar then
        bar:UnregisterAllEvents()
        ns.Blizz.Conceal(bar)
      end
    end
  end
  
  -- Handle XP/Rep bar (StatusTrackingBarManager)
  if HIDE_XP_BAR then
    -- Fade managed tracking containers instead of running their OnHide layout in addon context.
    ns.Blizz.Conceal(StatusTrackingBarManager)
    ns.Blizz.Conceal(MainStatusTrackingBarContainer)
    setupDone = true
  elseif SCALE_XP_BAR then
    -- Scale and reposition
    local barContainer = MainStatusTrackingBarContainer or StatusTrackingBarManager
    if barContainer then
      barContainer:SetScale(XP_BAR_SCALE)
      barContainer:ClearAllPoints()
      barContainer:SetPoint(
        XP_BAR_POSITION.point,
        UIParent,
        XP_BAR_POSITION.relativePoint,
        XP_BAR_POSITION.x,
        XP_BAR_POSITION.y
      )
      setupDone = true
    end
  else
    setupDone = true
  end
end

-- Retry setup after the delay once combat permits it.
local needsSetup = false
f:SetScript("OnEvent", function(self, event)
  needsSetup = true
  setupTimer = 0
end)

f:SetScript("OnUpdate", function(self, elapsed)
  if not needsSetup then return end
  
  setupTimer = setupTimer + elapsed
  if setupTimer < setupDelay then return end
  
  if not InCombatLockdown() then
    SetupTweaks()
    if setupDone then
      needsSetup = false
      self:SetScript("OnUpdate", nil)
    end
  end
end)

-- Trigger initial setup
needsSetup = true

-- Move loot roll frames up so they don't overlap action bars
local ROLL_FRAME_Y_OFFSET = 150
local repositioning = false

local function HookRollFrame(frame)
  hooksecurefunc(frame, "SetPoint", function(self)
    if repositioning then return end
    repositioning = true
    local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
    if point and y then
      self:SetPoint(point, relativeTo, relativePoint, x, y + ROLL_FRAME_Y_OFFSET)
    end
    repositioning = false
  end)
end

local function RepositionRollFrames()
  local container = _G["GroupLootContainer"]
  if container then
    HookRollFrame(container)
    return
  end

  for i = 1, 4 do
    local frame = _G["GroupLootFrame" .. i]
    if frame then
      HookRollFrame(frame)
    end
  end
end

local rollFrame = CreateFrame("Frame")
rollFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
rollFrame:SetScript("OnEvent", function(self)
  RepositionRollFrames()
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
