-- Queue initialization callbacks until login/world entry and a safe UI state.
-- OnUpdate supplies the delay; callbacks run once and report failures.

local addon, ns = ...
local InitCoordinator = {}
ns.InitCoordinator = InitCoordinator

local initFrame = CreateFrame("Frame")
local callbacks = {}
local initialized = false
-- Use shared protection state tracker (Roth_UI_Protection global from rLib)
Roth_UI_Protection = Roth_UI_Protection or {}
local function IsProtectedState()
  return Roth_UI_Protection.isLoggingOut or Roth_UI_Protection.isGameMenuOpen or InCombatLockdown()
end

-- Use OnUpdate for delayed execution
local executionFrame = CreateFrame("Frame")
local needsExecution = false
local executionTimer = 0

executionFrame:SetScript("OnUpdate", function(self, elapsed)
  if not needsExecution then return end
  if IsProtectedState() then return end
  
  executionTimer = executionTimer + elapsed
  if executionTimer >= 0.5 then
    needsExecution = false
    
    if not initialized then
      initialized = true
    end
    
    -- Execute all registered callbacks
    for _, callbackData in ipairs(callbacks) do
      if not callbackData.executed and not IsProtectedState() then
        local success, err = pcall(callbackData.callback)
        if success then
          callbackData.executed = true
        else
          -- Report once through the error handler; mark executed to prevent repeated failures.
          callbackData.executed = true
          local label = callbackData.name or "unnamed"
          local msg = ("|cFFFF6060Roth_UI:|r init callback '%s' failed: %s")
            :format(label, tostring(err))
          if geterrorhandler then
            pcall(geterrorhandler(), msg)
          else
            print(msg)
          end
        end
      end
    end
  end
end)

-- Use multiple events to trigger initialization
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("ADDON_LOADED")

initFrame:SetScript("OnEvent", function(self, event, addonName)
  if IsProtectedState() then return end
  
  if event == "ADDON_LOADED" and addonName == "Blizzard_ActionBar" then
    needsExecution = true
    executionTimer = 0
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    needsExecution = true
    executionTimer = 0
  end
end)

-- Public API: Register callback for when frames are ready
function InitCoordinator:OnFramesReady(callback, name)
  if IsProtectedState() then return end
  
  local callbackData = {
    callback = callback,
    name = name or "unnamed",
    executed = false
  }
  
  table.insert(callbacks, callbackData)
  if initialized then
    needsExecution = true
    executionTimer = 0.4
  end
end

-- Public API: Register callback for when player is ready
function InitCoordinator:OnPlayerReady(callback, name)
  self:OnFramesReady(callback, name)
end

-- Public API: Register callback for when world is ready
function InitCoordinator:OnWorldReady(callback, name)
  self:OnFramesReady(callback, name)
end

-- Public API: Check if initialized
function InitCoordinator:IsInitialized()
  return initialized
end
