local addonName, Roth_UI = ...
local LSM = LibStub("LibSharedMedia-3.0")
local fonts = AceGUIWidgetLSMlists.font
local order = 1
local options = {
	type = "group",
	args = {},
}

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

--- Method to add module configuration into the Roth UI config block.
--  This method should not be invoked after LoadConfig has been called.
--  @param key The option key to add the local options to the options table.
--  @param newOptions The new options to add
--  @param profileDefaults Any defaults to be added at the profile level.
--  @param characterDefaults Any defaults to be added at the character level.
function Roth_UI:AddConfig(key, newOptions, profileDefaults, characterDefaults)
	newOptions.order = order
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
	options.args[key] = newOptions
	order = order + 1
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

--- Method to both load configuration from the SavedVariables and initialize the options window.
function Roth_UI:LoadConfig()
	Roth_UI.configDB = LibStub("AceDB-3.0"):New("Roth_UI_DB", defaults)
	Roth_UI.configDB.RegisterCallback(Roth_UI, "OnProfileChanged", function()
		Roth_UI:ApplyResizeOptions()
		ReloadUI()
	end)
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(Roth_UI.configDB)

	-- Apply saved resize options after loading
	Roth_UI:ApplyResizeOptions()

	-- Add Layout & Edit Mode tab
	options.args.resize = {
		type = "group",
		name = "Edit Layout",
		order = 50,
		args = {
			header = {
				type = "description",
				name = "|cFF8B0000DiabolusUnits Layout & Edit Mode|r\n\nMove, resize, and toggle visibility for all unit frames, orbs, statues, and bars.\n",
				order = 1,
				fontSize = "medium",
			},
			editButton = {
				type = "execute",
				name = "Toggle Edit Mode",
				desc = "Open or close the interactive Edit Mode overlay",
				func = function()
					local ns = _G[addonName] or Roth_UI
					if ns and ns.EditMode and ns.EditMode.Toggle then
						ns.EditMode:Toggle()
					end
				end,
				order = 2,
			},
			resetButton = {
				type = "execute",
				name = "Reset All Frames",
				desc = "Reset all unit frames, orbs, statues, and bars to default positions and sizes",
				func = function()
					local ns = _G[addonName] or Roth_UI
					if ns and ns.EditMode and ns.EditMode.ResetAllToDefault then
						ns.EditMode:ResetAllToDefault()
					end
				end,
				order = 3,
			},
			reloadButton = {
				type = "execute",
				name = "Reload UI",
				desc = "Reload the UI",
				func = function()
					ReloadUI()
				end,
				order = 4,
			},
			spacer_reload = {
				type = "description",
				name = " ",
				order = 5,
			},
			layout_note = {
				type = "description",
				name = "|cFFFFD100Frame sizes, positions, aura icon sizes and showing / hiding frames|r are all configured live in |cFFFFD100Edit Mode|r: "
					.. "click |cFFFFD100Toggle Edit Mode|r above, open Blizzard's Edit Mode, or type |cFFFFD100/roth edit|r.",
				fontSize = "medium",
				order = 40,
			},
		},
	}

	-- Add Slash Commands tab
	options.args.commands = {
		type = "group",
		name = "Slash Commands",
		order = 90,
		args = {
			header = {
				type = "description",
				name = "|cFF8B0000Roth UI Slash Commands Reference|r\n\nBelow are all available slash commands for Roth UI and its modules.\n",
				order = 1,
				fontSize = "medium",
			},
			roth_header = {
				type = "header",
				name = "Main Commands (/roth)",
				order = 10,
			},
			roth_config = {
				type = "description",
				name = "|cFFFFFFFF/roth config|r - Opens the orb configuration panel",
				order = 11,
			},
			roth_edit = {
				type = "description",
				name = "|cFFFFFFFF/roth edit|r - Toggle Edit Mode: move, resize, show or hide every frame (also opens with Blizzard's Edit Mode)",
				order = 12,
			},
			roth_lockall = {
				type = "description",
				name = "|cFFFFFFFF/roth lockall|r - Finishes editing and locks frames",
				order = 13,
			},
			roth_resetall = {
				type = "description",
				name = "|cFFFFFFFF/roth resetall|r - Resets every frame to default layout",
				order = 14,
			},
			roth_scale = {
				type = "description",
				name = "|cFFFFFFFF/roth scale <number>|r - Scales all unit frames and art globally",
				order = 15,
			},
			roth_autoscale = {
				type = "description",
				name = "|cFFFFFFFF/roth autoscale [on|off]|r - Toggles pixel-perfect (768/h) UI scaling",
				order = 16,
			},
		},
	}

	-- Add Credits tab
	options.args.credits = {
		type = "group",
		name = "Credits",
		order = 200,
		args = {
			header = {
				type = "description",
				name = "|cFF8B0000DiabolusUnits - Credits & History|r\n\nDiablo-Themed Unit Frames, Orbs, Art & Nameplates for World of Warcraft\n",
				order = 1,
				fontSize = "large",
			},
			spacer1 = {
				type = "description",
				name = " ",
				order = 2,
			},
			original_header = {
				type = "header",
				name = "Original Creator",
				order = 10,
			},
			original_author = {
				type = "description",
				name = "|cFFFFD700zork (Lars Norberg)|r - Created Roth UI and oUF_Diablo (~2008-2016)\n\nThe project began during Wrath of the Lich King. zork created the iconic Diablo-style health/mana orbs and overall aesthetic that defines Roth UI.\n\n|cFF888888GitHub: github.com/zorker/rothui|r",
				order = 11,
				fontSize = "medium",
			},
			spacer2 = {
				type = "description",
				name = " ",
				order = 19,
			},
			previous_header = {
				type = "header",
				name = "Previous Maintainer",
				order = 20,
			},
			previous_author = {
				type = "description",
				name = "|cFFFFD700Galaxy (Galaxy119/Joker119)|r - Maintainer (2012-2018)\n\nTook over unofficially around Mists of Pandaria (~2012). At Legion launch, zork officially handed the project to Galaxy.\n\n|cFF888888GitHub: github.com/joker-119/Roth_UI|r",
				order = 21,
				fontSize = "medium",
			},
			spacer3 = {
				type = "description",
				name = " ",
				order = 29,
			},
			current_header = {
				type = "header",
				name = "TBC Anniversary Edition",
				order = 30,
			},
			current_author = {
				type = "description",
				name = "|cFFFFD700EchoZulu69er|r - TBC Anniversary edition (2025)\n\nCompatibility fixes and modernization.\nAssisted by Grok and Cursor AI.",
				order = 31,
				fontSize = "medium",
			},
			forever_header = {
				type = "header",
				name = "DiabolusUnits (WoW Forever)",
				order = 32,
			},
			forever_author = {
				type = "description",
				name = "|cFFFFD700codingdoctorbot|r - WoW Forever edition (2026)\n\nSecret-value port, party and raid frames, healer features, Edit Mode layout system.\nAssisted by Claude (Anthropic) and Gemini (Google).\nIdeas and data from ForeverUnitFrames, MidnightSimpleUnitFrames and Grid2 - see CREDITS.md.",
				order = 33,
				fontSize = "medium",
			},
			spacer4 = {
				type = "description",
				name = " ",
				order = 39,
			},
			libraries_header = {
				type = "header",
				name = "Third-Party Libraries",
				order = 40,
			},
			libraries = {
				type = "description",
				name = "|cFFAAAAAA- oUF|r by Haste - Unit frame framework\n|cFFAAAAAA- rLib|r by zork - Drag frames and utilities\n|cFFAAAAAA- Diabolic UI|r by Goldpaw - Target frame artwork\n|cFFAAAAAA- Ace3|r by Ace3 Development Team - Configuration libraries\n|cFFAAAAAA- LibSharedMedia-3.0|r by Elkano - Media sharing",
				order = 41,
				fontSize = "medium",
			},
		},
	}

	-- The AceConfig pages (Esc > Options > AddOns) are replaced by the DiabolusUnits settings
	-- window (settings/); `options` is still built so AddConfig callers keep working.
	order = 1
	Roth_UI.cfg.font = LSM:Fetch("font", Roth_UI.configDB.profile.chatFont)
end
