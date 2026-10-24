local addonName, Roth_UI = ...
local LSM = LibStub("LibSharedMedia-3.0")
local mediaCallbacks = {}
local loadedCallbacks = {}
local configLoaded = false
local LoadedHandler = CreateFrame("Frame")

-- Use shared protection state tracker (Roth_UI_Protection global from rLib)
Roth_UI_Protection = Roth_UI_Protection or {}

-- Make state checks accessible globally for other modules
Roth_UI.IsLoggingOut = function()
	return Roth_UI_Protection.isLoggingOut
end
Roth_UI.IsGameMenuShown = function()
	return Roth_UI_Protection.isGameMenuOpen
end
Roth_UI.IsProtectedState = function()
	return Roth_UI_Protection.isLoggingOut or Roth_UI_Protection.isGameMenuOpen or InCombatLockdown()
end

-- Helper function to safely execute callbacks
local function SafeCallback(callback, ...)
	if Roth_UI_Protection.isLoggingOut or Roth_UI_Protection.isGameMenuOpen or InCombatLockdown() then
		return
	end
	local success, err = pcall(callback, ...)
	if not success then
		-- Silently fail during protected states
	end
end
LoadedHandler:RegisterEvent("ADDON_LOADED")
LoadedHandler:SetScript("OnEvent", function(self, event, name)
	if
		(name == addonName or name == "DiabolusForever" or name == "DiabolusUnits")
		and not Roth_UI_Protection.isLoggingOut
		and not InCombatLockdown()
	then
		Roth_UI:LoadConfig()
		configLoaded = true
		for index, callback in pairs(loadedCallbacks) do
			SafeCallback(callback)
		end
	end
end)

-- Apply resize options on PLAYER_LOGIN (only once, before bars initialize)
-- Don't apply on PLAYER_ENTERING_WORLD to avoid interfering with bar setup
local ResizeOptionsFrame = CreateFrame("Frame")
ResizeOptionsFrame:RegisterEvent("PLAYER_LOGIN")
ResizeOptionsFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		-- Apply resize options to config BEFORE bars initialize
		-- This ensures bars read the correct values during setup
		if Roth_UI and Roth_UI.configDB and Roth_UI.configDB.profile.resizeOptions then
			if Roth_UI.ApplyResizeOptions then
				Roth_UI:ApplyResizeOptions()
			end
		end
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)
LSM.RegisterCallback(Roth_UI, "LibSharedMedia_Registered", function(name, mediaType, key)
	if configLoaded and not Roth_UI_Protection.isLoggingOut and not InCombatLockdown() then
		for index, callback in pairs(mediaCallbacks) do
			SafeCallback(callback, name, mediaType, key)
		end
	end
end)
function Roth_UI:ListenForMediaChange(callback)
	table.insert(mediaCallbacks, callback)
end
function Roth_UI:ListenForLoaded(callback)
	table.insert(loadedCallbacks, callback)
end
