-- Roth UI Blizz Bar Nil Fix - Minimal Version
-- Prevents nil comparison errors in Blizzard's MultiActionBars.lua
-- Bar positioning is handled by Edit Mode - this file only prevents errors.

local f = CreateFrame("Frame")
local isLoggingOut = false

-- Track logout to stop any frame modifications.
--
-- PLAYER_LEAVING_WORLD fires on every zone/instance/BG transition, not
-- only on real logout, so we have to clear the flag on PLAYER_ENTERING_WORLD
-- or it stays true forever after the first zone change and the ArtFrame
-- retry sequence below silently bails for the rest of the session.
local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
logoutFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
logoutFrame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_ENTERING_WORLD" then
    isLoggingOut = false
  else
    isLoggingOut = true
  end
end)

-- Ensure MainMenuBarArtFrame exists early with proper geometry
local function EnsureArtFrame()
  if isLoggingOut then return end
  if not MainMenuBarArtFrame then
    MainMenuBarArtFrame = CreateFrame("Frame", "MainMenuBarArtFrame", UIParent)
    MainMenuBarArtFrame:SetSize(512, 53)
    MainMenuBarArtFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    MainMenuBarArtFrame:Show()
    MainMenuBarArtFrame:SetAlpha(0)
    MainMenuBarArtFrame:SetScale(1)
    MainMenuBarArtFrame:EnableMouse(false)
  end
  
  -- Ensure it has valid geometry (GetLeft/GetBottom return numbers, not nil)
  if MainMenuBarArtFrame then
    local left = MainMenuBarArtFrame:GetLeft()
    local bottom = MainMenuBarArtFrame:GetBottom()
    
    -- If geometry is nil, reposition to ensure valid values
    if not left or not bottom then
      MainMenuBarArtFrame:ClearAllPoints()
      MainMenuBarArtFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
      MainMenuBarArtFrame:Show()
    end
  end
end

-- Try to create the frame immediately
pcall(EnsureArtFrame)

-- Ensure frame exists on key events
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGIN")

local artFrameTimer = 0
local artFrameAttempts = 0
local needsArtFrameCheck = false

local function ArtFrameOnUpdate(self, elapsed)
  if not needsArtFrameCheck then return end
  if isLoggingOut then return end
  
  artFrameTimer = artFrameTimer + elapsed
  local intervals = {0.1, 0.5, 1.0}
  if artFrameAttempts < #intervals and artFrameTimer >= intervals[artFrameAttempts + 1] then
    artFrameAttempts = artFrameAttempts + 1
    pcall(EnsureArtFrame)
    if artFrameAttempts >= #intervals then
      needsArtFrameCheck = false
      self:SetScript("OnUpdate", nil)
    end
  end
end

f:SetScript("OnEvent", function(self, event)
  if isLoggingOut then return end
  pcall(EnsureArtFrame)
  if event == "PLAYER_ENTERING_WORLD" then
    needsArtFrameCheck = true
    artFrameTimer = 0
    artFrameAttempts = 0
    -- (Re-)attach OnUpdate for the retry sequence; ArtFrameOnUpdate clears
    -- itself once retries complete.
    self:SetScript("OnUpdate", ArtFrameOnUpdate)
  end
end)

-- Do NOT install a permanent OnUpdate here. The previous version attached
-- ArtFrameOnUpdate at file load, and even though the handler early-exits
-- when needsArtFrameCheck is false, it still ran every single frame for the
-- entire session. The PLAYER_ENTERING_WORLD branch above attaches it on
-- demand, and the handler self-detaches after the retry intervals exhaust.

-- NOTE: Do NOT set oldActionBarSettings/oldGridSettings on Blizzard bar frames
-- from addon code. Writing to Blizzard frames taints them, which propagates
-- through EditMode → CompactUnitFrame_UpdateAll → CompactPartyFrame SetSize(),
-- causing ADDON_ACTION_BLOCKED errors. Any nil field errors from Blizzard's
-- EditMode code are cosmetic and far less harmful than taint.
