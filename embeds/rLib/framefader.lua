
-- rLib: framefader
-- zork, 2016

-----------------------------
-- Variables
-----------------------------

local A, L = ...

local SpellFlyout = SpellFlyout

-- Protection state tracking

-- Use shared protection state tracker (Roth_UI_Protection global from rLib)
Roth_UI_Protection = Roth_UI_Protection or {}
local function IsProtected()
  return Roth_UI_Protection.isLoggingOut or Roth_UI_Protection.isGameMenuOpen or InCombatLockdown()
end

-----------------------------
-- Functions
-----------------------------

local function FaderOnFinished(self)
  self.__owner:SetAlpha(self.finAlpha)
end

local function CreateFaderAnimation(frame)
  if frame.fader then return end
  frame.fader = frame:CreateAnimationGroup()
  frame.fader.__owner = frame
  frame.fader.direction = nil
  frame.fader.anim = frame.fader:CreateAnimation("Alpha")
  frame.fader:HookScript("OnFinished", FaderOnFinished)
end

function L:StartFadeIn(frame)
  if frame.fader.direction == "in" then return end
  frame.fader:Pause()
  frame.fader.anim:SetFromAlpha(frame.faderConfig.fadeOutAlpha or 0)
  frame.fader.anim:SetToAlpha(frame.faderConfig.fadeInAlpha or 1)
  frame.fader.anim:SetDuration(frame.faderConfig.fadeInDuration or 0.3)
  frame.fader.anim:SetSmoothing(frame.faderConfig.fadeInSmooth or "OUT")
  --start right away
  frame.fader.anim:SetStartDelay(frame.faderConfig.fadeInDelay or 0)
  frame.fader.finAlpha = frame.faderConfig.fadeInAlpha
  frame.fader.direction = "in"
  frame.fader:Play()
end

function L:StartFadeOut(frame)
  if frame.fader.direction == "out" then return end
  frame.fader:Pause()
  frame.fader.anim:SetFromAlpha(frame.faderConfig.fadeInAlpha or 1)
  frame.fader.anim:SetToAlpha(frame.faderConfig.fadeOutAlpha or 0)
  frame.fader.anim:SetDuration(frame.faderConfig.fadeOutDuration or 0.3)
  frame.fader.anim:SetSmoothing(frame.faderConfig.fadeOutSmooth or "OUT")
  --wait for some time before starting the fadeout
  frame.fader.anim:SetStartDelay(frame.faderConfig.fadeOutDelay or 0)
  frame.fader.finAlpha = frame.faderConfig.fadeOutAlpha
  frame.fader.direction = "out"
  frame.fader:Play()
end

local function IsMouseOverFrame(frame)
  if MouseIsOver(frame) then return true end
  if not SpellFlyout or not SpellFlyout:IsShown() then return false end
  if not SpellFlyout.__faderParent then return false end
  if SpellFlyout.__faderParent == frame and MouseIsOver(SpellFlyout) then return true end
  return false
end

local function FrameHandler(frame)
  if IsMouseOverFrame(frame) then
    L:StartFadeIn(frame)
  else
    L:StartFadeOut(frame)
  end
end

local function OffFrameHandler(self)
  if not self.__faderParent then return end
  FrameHandler(self.__faderParent)
end

local function SpellFlyoutOnShow(self)
  if not SpellFlyout then return end
  local frame = self:GetParent():GetParent():GetParent()
  if not frame or not frame.fader then return end
  self.__faderParent = frame
  if not self.__faderHook then
    SpellFlyout:HookScript("OnEnter", OffFrameHandler)
    SpellFlyout:HookScript("OnLeave", OffFrameHandler)
    self.__faderHook = true
  end
  for i=1, NUM_ACTIONBAR_BUTTONS do
    local button = _G["SpellFlyoutButton"..i]
    if not button then break end
    button.__faderParent = frame
    if not button.__faderHook then
      button:HookScript("OnEnter", OffFrameHandler)
      button:HookScript("OnLeave", OffFrameHandler)
      button.__faderHook = true
    end
  end
end

function rLib:CreateFrameFader(frame, faderConfig)
  if frame.faderConfig then return end
  frame.faderConfig = faderConfig
  frame:EnableMouse(true)
  CreateFaderAnimation(frame)
  frame:HookScript("OnEnter", FrameHandler)
  frame:HookScript("OnLeave", FrameHandler)
  FrameHandler(frame)
end

  local defaultFadeIn = {time = 0.4, alpha = 1}
  local defaultFadeOut = {time = 0.3, alpha = 0}

  --rButtonBarFader func
  function rButtonBarFader(frame,buttonList,fadeIn,fadeOut)
    if not frame or not buttonList then return end
    if not fadeIn then fadeIn = defaultFadeIn end
    if not fadeOut then fadeOut = defaultFadeOut end
    frame:EnableMouse(true)
    
    -- Track mouse state
    local mouseOverBar = false
    
    -- Helper function to check if mouse is over frame or any button
    local function IsMouseOverBar()
      if MouseIsOver(frame) then return true end
      for _, button in pairs(buttonList) do
        if button and MouseIsOver(button) then return true end
      end
      return false
    end
    
    -- Delayed fade out state tracking - use OnUpdate instead of C_Timer.After
    local pendingFadeOut = false
    local fadeOutTimer = 0
    local fadeOutChecker = CreateFrame("Frame")
    
    fadeOutChecker:SetScript("OnUpdate", function(self, elapsed)
      if not pendingFadeOut then return end
      if IsProtected() then
        pendingFadeOut = false
        return
      end
      
      fadeOutTimer = fadeOutTimer + elapsed
      if fadeOutTimer >= 0.1 then
        pendingFadeOut = false
        if not IsMouseOverBar() then
          mouseOverBar = false
          pcall(UIFrameFadeOut, frame, fadeOut.time, frame:GetAlpha(), fadeOut.alpha)
        else
          mouseOverBar = true
        end
      end
    end)
    
    -- Frame handlers with proper mouse detection
    frame:HookScript("OnEnter", function() 
      if IsProtected() then return end
      mouseOverBar = true
      pendingFadeOut = false
      pcall(UIFrameFadeIn, frame, fadeIn.time, frame:GetAlpha(), fadeIn.alpha)
    end)
    frame:HookScript("OnLeave", function() 
      if IsProtected() then return end
      mouseOverBar = false
      -- Schedule fade out check via OnUpdate
      pendingFadeOut = true
      fadeOutTimer = 0
    end)
    
    -- Initial fade out (only if fadeOut alpha is less than 1)
    if fadeOut.alpha < 1 then
      pcall(UIFrameFadeOut, frame, fadeOut.time, frame:GetAlpha(), fadeOut.alpha)
    end
    
    -- Button handlers
    for _, button in pairs(buttonList) do
      if button then
        -- Ensure empty buttons can receive mouse events
        button:EnableMouse(true)
        button:HookScript("OnEnter", function() 
          if IsProtected() then return end
          mouseOverBar = true
          pendingFadeOut = false
          pcall(UIFrameFadeIn, frame, fadeIn.time, frame:GetAlpha(), fadeIn.alpha)
        end)
        button:HookScript("OnLeave", function() 
          if IsProtected() then return end
          -- Schedule fade out check via OnUpdate
          pendingFadeOut = true
          fadeOutTimer = 0
        end)
      end
    end
  end

function rLib:CreateButtonFrameFader(frame, buttonList, faderConfig)
  rLib:CreateFrameFader(frame, faderConfig)
  for i, button in next, buttonList do
    if not button.__faderParent then
      button.__faderParent = frame
      button:HookScript("OnEnter", OffFrameHandler)
      button:HookScript("OnLeave", OffFrameHandler)
    end
  end
end
