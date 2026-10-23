local addonName, Roth_UI = ...
local LSM = LibStub("LibSharedMedia-3.0")
local defaults = {
	profile = {
		-- Resize options defaults
		resizeOptions = {
			-- Main UI Scale (bars 1-3, micromenu, stancebar, bags, keyring, art, orbs)
			-- 1.0 means "use original config scales", any other number multiplies original scale
			mainUIScale = 1.0, -- 1.0 = use original config scales (no change)
			-- Store original scales for reference (populated on first load)
			originalScales = {},
			-- Unit Frames
			targetFrameScale = 1,
			targetDebuffSize = 26,
			focusAuraSize = 28,
			totAuraSize = 28,
			targettargetFrameScale = 1,
			focusFrameScale = 0.85,
			-- Other Elements
			chatFontSize = 12,
			minimapAlpha = 0.85,
			minimapZoneFont = "Morpheus",
			minimapZoneFontSize = 12,
		},
	},
	char = {},
}

-- Merge module defaults before LoadConfig; legacy option arguments are ignored.
function Roth_UI:AddConfig(key, newOptions, profileDefaults, characterDefaults)
	if profileDefaults then
		for k, v in pairs(profileDefaults) do
			defaults.profile[k] = v
		end
	end
	if characterDefaults then
		for k, v in pairs(characterDefaults) do
			defaults.char[k] = v
		end
	end
end

-- Function to apply saved resize options to config and frames
-- Only applies to config values - bars will read these on initialization
local resizeAfterCombat
function Roth_UI:ApplyResizeOptions()
	if not Roth_UI.configDB or not Roth_UI.configDB.profile.resizeOptions then
		return
	end
	-- SetScale on the secure unit frames is blocked in combat (the "Roth_UI has
	-- been blocked from an action" popup after a /reload in a fight): wait.
	if InCombatLockdown() then
		if not resizeAfterCombat then
			resizeAfterCombat = CreateFrame("Frame")
			resizeAfterCombat:SetScript("OnEvent", function(self)
				self:UnregisterEvent("PLAYER_REGEN_ENABLED")
				Roth_UI:ApplyResizeOptions()
			end)
		end
		resizeAfterCombat:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end

	local resizeOpts = Roth_UI.configDB.profile.resizeOptions

	-- Apply to config if available (ns.cfg is set in config.lua)
	-- Only modify config values - don't touch frame positions
	local ns = _G[addonName] or Roth_UI
	if ns and ns.cfg then
		-- Apply Main UI Scale to bars 1-3, micromenu, stancebar, bags
		-- ONLY modify config values - bars will read these during initialization
		-- DO NOT apply directly to frames here to avoid position issues
		local mainUIBars = { bar1 = true, bar2 = true, bar3 = true, micromenu = true, stancebar = true, bags = true }
		local mainUIScaleValue = resizeOpts.mainUIScale or 1.0

		-- Define true original scales from config.lua (hardcoded to ensure accuracy)
		local TRUE_ORIGINAL_SCALES = {
			bar1 = 1,
			bar2 = 1,
			bar3 = 1,
			micromenu = 0.6,
			stancebar = 0.6,
			bags = 0.5,
			art_actionbarbackground = 1,
			art_angel = 1,
			art_demon = 1,
			art_bottomline = 1,
			player = 1,
		}

		if ns.cfg.bars then
			-- Always reset and store original scales from TRUE_ORIGINAL_SCALES to ensure accuracy
			-- This prevents issues where original scales were stored incorrectly
			if not resizeOpts.originalScales or not next(resizeOpts.originalScales) then
				resizeOpts.originalScales = {}
			end

			-- Always reset original scales from true values to ensure accuracy
			-- This fixes cases where original scales were stored incorrectly
			for k, v in pairs(ns.cfg.bars) do
				if type(v) == "table" and mainUIBars[k] and v.scale ~= nil then
					if TRUE_ORIGINAL_SCALES[k] then
						resizeOpts.originalScales[k] = TRUE_ORIGINAL_SCALES[k]
					end
				end
			end

			-- Always reset art frame scales from true values
			local artFrames = { "actionbarbackground", "angel", "demon", "bottomline" }
			for _, artName in ipairs(artFrames) do
				local key = "art_" .. artName
				if TRUE_ORIGINAL_SCALES[key] then
					resizeOpts.originalScales[key] = TRUE_ORIGINAL_SCALES[key]
				end
			end

			-- Always reset player orb scale from true value
			if TRUE_ORIGINAL_SCALES.player then
				resizeOpts.originalScales.player = TRUE_ORIGINAL_SCALES.player
			end
			-- Always apply mainUIScale (even if 1.0, to ensure consistency)
			-- This ensures all components scale together proportionally
			for k, v in pairs(ns.cfg.bars) do
				if type(v) == "table" and mainUIBars[k] and v.scale ~= nil then
					local originalScale = resizeOpts.originalScales[k]
					if originalScale then
						v.scale = originalScale * mainUIScaleValue
					end
				end
			end
		end

		-- Apply to art frames (stored in cfg.units.player.art.*.scale)
		-- Always apply mainUIScale to ensure all components scale together
		if ns.cfg.units and ns.cfg.units.player and ns.cfg.units.player.art then
			local artFrames = { "actionbarbackground", "angel", "demon", "bottomline" }
			for _, artName in ipairs(artFrames) do
				if ns.cfg.units.player.art[artName] and ns.cfg.units.player.art[artName].scale ~= nil then
					local originalScale = resizeOpts.originalScales["art_" .. artName]
					if originalScale then
						ns.cfg.units.player.art[artName].scale = originalScale * mainUIScaleValue
					end
				end
			end
		end

		-- Apply to player orbs (player frame scale affects orbs)
		if ns.cfg.units and ns.cfg.units.player and ns.cfg.units.player.scale ~= nil then
			local originalScale = resizeOpts.originalScales.player
			if originalScale then
				ns.cfg.units.player.scale = originalScale * mainUIScaleValue
			end
		end

		-- Apply scale directly to art frames and orbs if they exist (for live updates)
		-- Store original scales for art frames if not stored
		if not resizeOpts.originalScales then
			resizeOpts.originalScales = {}
		end

		-- Apply to art frames directly
		local artFrameNames = {
			actionbarbackground = "Roth_UIActionBarBackground",
			angel = "Roth_UIAngelFrame",
			demon = "Roth_UIDemonFrame",
			bottomline = "Roth_UIBottomLine",
		}

		for artName, frameName in pairs(artFrameNames) do
			local frame = _G[frameName]
			if frame then
				-- Get original scale from config if not stored
				if
					ns.cfg.units
					and ns.cfg.units.player
					and ns.cfg.units.player.art
					and ns.cfg.units.player.art[artName]
				then
					if not resizeOpts.originalScales["art_" .. artName] then
						-- Store the original scale from config (before any modifications)
						resizeOpts.originalScales["art_" .. artName] = ns.cfg.units.player.art[artName].scale or 1.0
					end
					local originalScale = resizeOpts.originalScales["art_" .. artName]
					local mainUIScaleValue = resizeOpts.mainUIScale or 1.0
					local targetScale = originalScale * mainUIScaleValue
					frame:SetScale(targetScale)
				end
			end
		end

		-- Apply to player orbs directly
		local orbFrames = { "Roth_UIPowerOrb", "Roth_UIPlayerFrame" }
		for _, frameName in ipairs(orbFrames) do
			local frame = _G[frameName]
			if frame then
				-- Get original scale from config if not stored
				if ns.cfg.units and ns.cfg.units.player and ns.cfg.units.player.scale then
					if not resizeOpts.originalScales.player then
						-- Store the original scale from config (before any modifications)
						resizeOpts.originalScales.player = ns.cfg.units.player.scale or 1.0
					end
					local originalScale = resizeOpts.originalScales.player
					local mainUIScaleValue = resizeOpts.mainUIScale or 1.0
					local targetScale = originalScale * mainUIScaleValue
					frame:SetScale(targetScale)
				end
			end
		end

		-- Unit frame sizes and aura icon sizes are Edit layout's (core/editmode.lua,
		-- ns.AuraSize in core/nativeauras.lua); this used to set them too, and the
		-- two fought at every login.
	end

	-- Note: Bar frames will need /reload to apply changes since they're set up during initialization
	-- We don't modify existing bar frames here to avoid position issues
end

-- Initialize profile storage and apply the existing resize/font defaults.
function Roth_UI:LoadConfig()
	Roth_UI.configDB = LibStub("AceDB-3.0"):New("Roth_UI_DB", defaults)
	Roth_UI.configDB.RegisterCallback(Roth_UI, "OnProfileChanged", function()
		Roth_UI:ApplyResizeOptions()
		ReloadUI()
	end)
	Roth_UI:ApplyResizeOptions()
	Roth_UI.cfg.font = LSM:Fetch("font", Roth_UI.configDB.profile.chatFont)
end
