---------------------------------------------
--  Roth UI
---------------------------------------------

--  Diabolus Orbs Forever: a Diablo themed unitframe layout for oUF (Roth UI for WoW Forever, private alpha)
--  zork (Lars Norberg) - Original Creator (~2008-2016)
--  Galaxy119/Joker119 - Maintainer (2012-2018)
--  EchoZulu69er - TBC Anniversary edition (2025) - assisted by Grok and Cursor AI
--  codingdoctorbot - WoW Forever edition (2026) - assisted by Claude and Gemini
--  Full credits: CREDITS.md; version: Roth_UI.toc
---------------------------------------------

--get the addon namespace
local addon, ns = ...
local oUF = ns.oUF
mediapath = "Interface\\AddOns\\DiabolusUnits\\media\\"
local addonName, Roth_UI = ...
local LSM = LibStub("LibSharedMedia-3.0")

--object container
local cfg = {}
ns.cfg = cfg
local locale = GetLocale()
---------------------------------------------
-- // CONFIG // --
---------------------------------------------

---------------------------------------------
-- // Incoming heals and absorbs // --
---------------------------------------------
-- On group, target and focus frames (core/healbars.lua).
cfg.healbars = {
	heals = true, -- your heals bright, other healers' darker green
	absorbs = true, -- shields as gold stripes, heal absorbs dark red
}

-- A spark runs once around the mana orb for the five seconds after you spend
-- mana (spirit regeneration paused).
cfg.fiveSecondRule = true

-- While you cast, the part of the power orb the spell will use glows.
cfg.powerCost = true

-- Your shields as a gold crescent up the rim of the health orb.
cfg.orbShield = true

-- Roth's movable buff / debuff anchors (modules/MovableBuffs.lua,
-- MovableDebuffs.lua). Off on WoW Forever: moving Blizzard's aura frames from
-- add-on code taints their timers in combat. Move them with Edit Mode instead.
cfg.movableAuras = false

-- A dark inner rim on both orbs, so the liquid reads as inside the glass.
cfg.orbInnerShadow = true

-- Diablo nameplates (units/nameplates.lua): zork's iron bar art over the
-- game's plates, health inside, name and level above, a head for elites /
-- rares / bosses, threat colour on the iron, a gold glow on your target, a
-- cast bar with the interrupt-ready burn, and the debuffs you applied.
cfg.nameplates = {
	enabled = true,
	friendly = true, -- Roth plates on friendly units too (false: Blizzard's for them)
	scale = 1,
	targetScale = 1.15, -- your target's plate a little bigger
	healthText = true, -- percent inside the bar
	threat = true, -- threat colour on the iron
	heads = true, -- Diablo heads for elites, rares and bosses
	castbar = true,
	debuffs = true,
	maxDebuffs = 4, -- yours only, up to 5
}

-- Diablo swing timer above the cast bar: fills toward your next melee swing
-- or Auto Shot, flashes on each one, fades out after the last.
cfg.swingTimer = {
	enabled = true,
	ranged = true, -- Auto Shot, wands and throwing too
	scale = 1,
	gap = 10, -- above the player cast bar
}

-- Out of combat, missing class buffs: icons on each member's frame and a
-- count row above the group frames. Fortitude / Intellect / Mark of the
-- Wild when someone in the group casts them; your own extras when known.
cfg.buffCoverage = {
	enabled = true,
	summary = true, -- the count row above the party / raid frames
	spirit = true, -- Divine Spirit (you, a priest who knows it)
	shadowProtection = false, -- Shadow Protection (you, a priest)
	blessing = true, -- paladin: members without a blessing from you
}

---------------------------------------------
-- // Embeds // --
---------------------------------------------
cfg.embeds = {
	rChat = false,
	rActionBarStyler = false,
	rButtonTemplate = true, -- Styles custom Diablo buttons and aura icons
	rMinimap = false,
	rInfoStrings = false,
	rRaidManager = false,
	rRaidScale = false,
	rGroupFinder = false,
	rTooltip = true, -- Diablo styled tooltips
	Roth_ShinyBuffs = false,
	rObjectiveTracker = false,
	RothFont = true, -- makes game client use a font (as defined in config file) for all game text
}
----------------------------------------
-- colorswitcher define your color for healthbars here
----------------------------------------

--color is in RGB (red (r), green (g), blue (b), alpha (a)), values are from 0 (dark color) to 1 (bright color). 1,1,1 = white / 0,0,0 = black / 1,0,0 = red etc
cfg.colorswitcher = {
	bright = { r = 1, g = 0, b = 0, a = 1 }, -- the bright color
	dark = { r = 1, g = 0, b = 0, a = 0.1 }, -- the dark color
	classcolored = true, -- true   -> override the bright color with the unit specific color (class, faction, happiness, threat), if false uses the predefined color
	useBrightForeground = true, -- true   -> use bright color in foreground and dark color in background
	-- false  -> use dark color in foreground and bright color in background
	threatColored = true, -- true/false -> enable threat coloring of the health plate for raidframes
}

--frames have a new highlight that fades on hp loss, if that is still not enough you can adjust a multiplier here
cfg.highlightMultiplier = 0 --range 0-1

----------------------------------------
--units
----------------------------------------

cfg.units = {
	-- PLAYER
	player = {
		show = true,
		size = 160,
		scale = 1,
		pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -325, y = 10 },
		health = {
			frequentUpdates = true,
			smooth = true,
		},
		power = {
			frequentUpdates = true,
			smooth = true,
		},
		healprediction = { --WIP; added nil-check compat
			show = false,
			color = {
				myself = { r = 0, g = 1, b = 0, a = 1 },
				other = { r = 0, g = 1, b = 0, a = 0.7 },
			},
		},
		icons = {
			pvp = {
				show = true,
				pos = { a1 = "CENTER", a2 = "CENTER", x = -95, y = 42 }, --position in relation to self object
			},
			combat = {
				show = true,
				pos = { a1 = "CENTER", a2 = "CENTER", x = 0, y = 86 }, --position in relation to self object
			},
			resting = {
				show = true,
				pos = { a1 = "CENTER", a2 = "CENTER", x = -72, y = 60 }, --position in relation to self object
			},
		},
		TotemBar = {
			show = false,
		},
		castbar = {
			show = true,
			TextSize = 11,
			hideDefault = true, --if you hide the Roth_UI castbar, should the Blizzard castbar be shown?
			latency = true,
			texture = (mediapath .. "statusbar3"),
			scale = 1 / 1, --divide 1 by current unit scale if you want to prevent scaling of the castbar based on unit scale
			color = {
				bar = { r = 0, g = 0.5, b = 1, a = 0.8 },
				bg = { r = 0.1, g = 0.1, b = 0.1, a = 0.7 },
			},
			pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 170.5 }, -- Minor shift for bar compat
		},
		combobar = {
			show = true,
			scale = 0.40,
			color = { r = 0.9, g = 0.59, b = 0 },
			pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 650 },
			combat = { --fade the bar in/out in combat/out of combat
				enable = false,
				fadeIn = { time = 0.4, alpha = 1 },
				fadeOut = { time = 0.3, alpha = 0.2 },
			},
		},
		altpower = {
			show = false,
			scale = 0.5,
			color = { r = 1, g = 0, b = 1 },
			texture = (mediapath .. "statusbar"),
			pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = 0, y = 0 },
		},
		expbar = { --experience
			show = true,
			pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 14 }, -- default between orbs
			texture = (mediapath .. "statusbar2"),
			scale = 1,
			color = { r = 0.85, g = 0.65, b = 0.15 }, -- Rich amber gold (Diablo aesthetic)
			rested = {
				color = { r = 0.0, g = 0.45, b = 0.9 }, -- Deep rested azure
			},
		},
		repbar = { --reputation
			show = true,
			pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 6 }, -- default between orbs
			texture = (mediapath .. "statusbar2"),
			scale = 1,
		},
		art = {
			actionbarbackground = {
				show = false,
				width = 788, -- size of the stone bar (mouse: /roth unlockart, drag the corner grip; pad: the HUD mover's "Bar size")
				height = 220,
				pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 0 },
				scale = 1,
			},
			angel = {
				show = true,
				pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 330, y = 6 },
				scale = 1,
			},
			demon = {
				show = true,
				pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -335, y = 6 },
				scale = 1,
			},
			bottomline = {
				show = true,
				pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 2 },
				scale = 1,
			},
		},
		portrait = {
			pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = -100, y = 0 },
			size = 150,
			show = false,
			use3D = true,
		},
	},

	-- TARGET (minor pos tweak for minimap cluster)
	target = {
		show = true,
		threatGlow = true, -- the frame glows red / orange while the target is attacking you
		scale = 1.5,
		width = 300,
		height = 64,
		pos = { a1 = "TOP", a2 = "TOP", af = "UIParent", x = 0, y = -80 }, -- Down 10px
		health = {
			frequentUpdates = true,
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:hpval]", -- Added class color support if tag allows
			fontSize = 7,
			point = "RIGHT",
			x = 25,
			y = -30,
		},
		healper = {
			frequentUpdates = true,
			tag = "[perphp]",
			fontSize = 10,
			point = "CENTER",
			x = 0,
			y = 0,
		},
		powper = {
			frequentUpdates = true,
			tag = "[perpp]%",
			fontSize = 7,
			point = "CENTER",
			x = 0,
			y = 0,
		},
		power = {
			frequentUpdates = true,
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:ppval]",
			fontSize = 7,
			point = "LEFT",
			x = -25,
			y = -30,
		},
		misc = {
			classFontSize = 13,
			NameFontSize = 16,
		},
		auras = {
			show = true,
			size = 15,
			onlyShowPlayerBuffs = false,
			showStealableBuffs = true,
			onlyShowPlayerDebuffs = false,
			showDebuffType = true,
			desaturateDebuffs = false,
			buffs = {
				pos = { a1 = "BOTTOMLEFT", a2 = "TOPRIGHT", x = 0, y = -15 },
				initialAnchor = "BOTTOMLEFT",
				growthx = "RIGHT",
				growthy = "UP",
			},
			debuffs = {
				pos = { a1 = "TOPLEFT", a2 = "BOTTOMRIGHT", x = 0, y = 15 },
				initialAnchor = "TOPLEFT",
				growthx = "RIGHT",
				growthy = "DOWN",
			},
		},
		castbar = {
			show = true,
			TextSize = 11,
			texture = (mediapath .. "statusbar3"),
			scale = 1 / 1.9, --divide 1 by current unit scale if you want to prevent scaling of the castbar based on unit scale
			color = {
				bar = { r = 0, g = 0.5, b = 1, a = 0.7 },
				bg = { r = 0.1, g = 0.1, b = 0.1, a = 1 },
				shieldbar = { r = 0.5, g = 0.5, b = 0.5, a = 1 }, --the castbar color while target casting a shielded spell
				shieldbg = { r = 0.1, g = 0.1, b = 0.1, a = 0.7 }, --the castbar background color while target casting a shielded spell
			},
			pos = { a1 = "TOP", a2 = "TOP", af = "UIParent", x = -10, y = -135 }, -- Minor shift
		},
		portrait = {
			pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = 100, y = 0 },
			size = 150,
			show = false,
			use3D = true,
		},
		healprediction = {
			show = true,
			texture = (mediapath .. "statusbar3"),
			color = {
				myself = { r = 0, g = 1, b = 0, a = 1 },
				other = { r = 0, g = 1, b = 0, a = 0.7 },
			},
			maxoverflow = 1.00,
		},
		totalabsorb = {
			show = true,
			texture = (mediapath .. "absorb_statusbar_overlay"),
			color = {
				bar = { r = 0.7, g = 1, b = 1, a = 0.9 },
			},
		},
	},

	--TARGETTARGET
	targettarget = {
		show = true,
		width = 150,
		height = 64,
		scale = 1.3,
		pos = { a1 = "TOP", a2 = "TOP", af = "UIParent", x = -238, y = -90 }, -- Shift
		auras = {
			show = true,
			size = 22,
			onlyShowPlayerDebuffs = false,
			showDebuffType = true,
		},
		health = {
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:misshp]",
		},
		power = {
			texture = (mediapath .. "statusbar3"),
		},
		healprediction = {
			show = true,
			texture = (mediapath .. "statusbar3"),
			color = {
				myself = { r = 0, g = 1, b = 0, a = 1 },
				other = { r = 0, g = 1, b = 0, a = 0.7 },
			},
			maxoverflow = 1.00,
		},
	},

	--PET
	pet = {
		show = true,
		scale = 0.85,
		width = 128,
		height = 64,
		pos = { a1 = "RIGHT", a2 = "RIGHT", af = "UIParent", x = -30, y = -150 }, -- Shift
		auras = {
			show = true,
			size = 22,
			onlyShowPlayerDebuffs = false,
			showDebuffType = false,
		},
		happiness = {
			scale = 1.25,
			pos = { a1 = "LEFT", a2 = "LEFT", af = "self.Name", x = -5, y = 0 },
		},
		health = {
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:misshp]",
		},
		power = {
			texture = (mediapath .. "statusbar3"),
		},
		altpower = {
			show = false,
			scale = 0.5,
			color = { r = 1, g = 0, b = 1 },
			texture = (mediapath .. "statusbar3"),
			pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = 0, y = 0 },
		},
		portrait = {
			show = true,
			use3D = false,
		},
		castbar = {
			show = false,
			hideDefault = true, --if you hide the Roth_UI castbar, should the Blizzard castbar be shown?
			texture = "Interface\\AddOns\\DiabolusUnits\\media\\statusbar3",
			scale = 1 / 0.85, --divide 1 by current unit scale if you want to prevent scaling of the castbar based on unit scale
			color = {
				bar = { r = 1, g = 0.7, b = 0, a = 1 },
				bg = { r = 0.1, g = 0.1, b = 0.1, a = 0.7 },
			},
			pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 480 }, -- Shift
		},
		totalabsorb = {
			show = true,
			texture = (mediapath .. "absorb_statusbar_overlay"),
			color = {
				bar = { r = 0.7, g = 1, b = 1, a = 0.9 },
			},
		},
	},

	--FOCUS
	focus = {
		show = true,
		width = 128,
		height = 64,
		scale = 0.85,
		pos = { a1 = "CENTER", a2 = "BOTTOM", af = "UIParent", x = 0, y = 350 },
		aurawatch = {
			show = false,
			size = 20,
		},
		auras = {
			show = true,
			size = 22,
			onlyShowPlayerDebuffs = false,
			showDebuffType = false,
			showBuffs = true,
			onlyShowPlayerBuffs = false,
			showBuffType = false,
		},
		health = {
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:misshp]",
		},
		power = {
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:ppval]", -- Show mana/power value below bar
			fontSize = 10,
			point = "TOP",
			x = 0,
			y = -5,
		},
		portrait = {
			show = true,
			use3D = false,
		},
		castbar = {
			show = false,
			TextSize = 11,
			texture = (mediapath .. "statusbar3"),
			scale = 1 / 1.9, --divide 1 by current unit scale if you want to prevent scaling of the castbar based on unit scale
			color = {
				bar = { r = 1, g = 0.7, b = 0, a = 1 },
				bg = { r = 0.1, g = 0.1, b = 0.1, a = 0.7 },
			},
			pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 420 },
		},
		healprediction = {
			show = true,
			texture = (mediapath .. "statusbar128_3"),
			color = {
				myself = { r = 0, g = 1, b = 0, a = 1 },
				other = { r = 0, g = 1, b = 0, a = 0.7 },
			},
			maxoverflow = 1.00,
		},
		totalabsorb = {
			show = true,
			texture = (mediapath .. "absorb_statusbar_overlay"),
			color = {
				bar = { r = 0.7, g = 1, b = 1, a = 0.9 },
			},
		},
	},

	--PETTARGET
	pettarget = {
		show = false,
		width = 128,
		height = 64,
		scale = 0.85,
		pos = { a1 = "LEFT", a2 = "LEFT", af = "UIParent", x = 140, y = -140 },
		auras = {
			show = true,
			size = 22,
			onlyShowPlayerDebuffs = false,
			showDebuffType = false,
		},
		health = {
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:misshp]",
		},
		power = {
			texture = (mediapath .. "statusbar3"),
		},
		portrait = {
			show = true,
			use3D = true,
		},
	},

	--FOCUSTARGET
	focustarget = {
		show = false,
		width = 128,
		height = 64,
		scale = 0.85,
		pos = { a1 = "LEFT", a2 = "LEFT", af = "UIParent", x = 140, y = 40 },
		auras = {
			show = true,
			size = 22,
			onlyShowPlayerDebuffs = false,
			showDebuffType = false,
		},
		health = {
			texture = (mediapath .. "statusbar128_3"),
			tag = "[diablo:misshp]",
		},
		power = {
			texture = (mediapath .. "statusbar128_3"),
		},
		portrait = {
			show = true,
			use3D = true,
		},
	},

	--PARTY
	party = {
		show = true, -- Roth party frames (units/party.lua); Blizzard's are ghosted (DESIGN.md §5.3)
		vertical = true, -- read by shared helpers in core/lib.lua (aura watch, absorb); the party column is always vertical
		alpha = {
			notinrange = 0.5,
		},
		scale = 1.1,
		pos = { a1 = "CENTER", a2 = "CENTER", af = "UIParent", x = -335, y = 150 },
		auras = {
			show = true,
			size = 20,
			num = 5,
			number = 5, -- read by func.createDebuffs/createBuffs for other units
			showBuffs = true, -- your own HoTs / shields (HELPFUL|PLAYER|RAID_IN_COMBAT)
			debuffPos = { a1 = "TOPLEFT", a2 = "BOTTOMLEFT", x = 30, y = 20 },
			buffPos = { a1 = "LEFT", a2 = "RIGHT", x = -26, y = 0 },
			blacklist = {},
		},
		health = {
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:misshp]",
		},
		power = {
			texture = (mediapath .. "statusbar3"),
		},
		attributes = {
			visibility = "custom [group:party,nogroup:raid] show; hide",
			showPlayer = true, --you are in the column too (LB + A targets you in gamepad mode)
			showSolo = false,
			showParty = true,
			showRaid = false,
			hideInArena = false, --hides the party frame while inside an arena
			point = "TOP",
			yOffset = -14, --room for the debuff row under each member
		},
	},

	--RAID
	raid = {
		show = true,
		layout = "tiles", -- "tiles": square Diablo tiles, health filling upwards (fits 40); "bars": zork's bar frames
		tiles = {
			spacing = 4, -- gap between tiles
			debuffs = 2,
			debuffSize = 14, -- along the bottom
			buffs = 3,
			buffSize = 10, -- your own HoTs / shields, top right
		},
		special = {
			chains = false, --should the raidframe include the chain textures?
		},
		alpha = {
			notinrange = 0.4,
		},
		scale = 0.8,
		pos = { a1 = "TOPLEFT", a2 = "TOPLEFT", af = "UIParent", x = 5, y = -15 }, -- Shift for anniv
		health = {
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:misshp]", --tag for the second line
		},
		power = {
			texture = (mediapath .. "statusbar3"),
		},
		aurawatch = {
			show = false,
		},
		auras = {
			--put every single spellid here that you want to be tracked, be it buff or debuff doesn't matter
			whitelist = {
				223306, -- Bestow Faith
				53563, -- Beacon of Light
				6940, -- Blessing of Sacrifice
				287280, -- Glimmer of Light
				156910, -- Beacon of Faith
				200025, -- Beacon of Virtue
				313255, -- Slow
				344916, -- Tuft of smoldering Plumage
				29203,
				32593,
				32594,
				31956,
				53601,
				66922,
			},
			blacklist = {
				--these are abilities that should definetly not be shown
				164545,
				164547,
				54149,
			},
			show = true,
			disableCooldown = false,
			showBuffType = true,
			showDebuffType = true,
			doNotUseCustomFilter = false,
			size = 14,
			num = 4,
			spacing = 3,
			debuffPos = { a1 = "CENTER", x = 0, y = -23 },
			buffPos = { a1 = "CENTER", x = 0, y = 12 },
		},
		attributes = {
			visibility = "custom [group:raid] show; hide",
			showPlayer = true,
			showSolo = false,
			showParty = false,
			showRaid = true,
			showInArena = false, --shows this frame while in an arena
			point = "TOP",
			yOffset = 15, --zork's overlap: the art has room above and below the bar
			columnSpacing = -20,
			columnAnchorPoint = "LEFT", --groups as columns, left to right (matches Blizzard's "keep groups together")
		},
	},

	--BOSSFRAMES
	boss = {
		show = true,
		scale = 1,
		width = 128,
		height = 64,
		pos = { a1 = "TOP", a2 = "BOTTOM", af = "Minimap", x = 0, y = -90 }, -- Shift for cluster
		health = {
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:bosshp]%",
		},
		power = {
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:bosspp]",
		},
	},
}

----------------------------------------
-- Button / Cooldown Styling
----------------------------------------
cfg.bars = {
	showMacroName = true,
	showCooldown = true,
	showHotkey = false,
	showStackCount = true,
	cooldownFont = {
		font = nil,
		size = 14,
		outline = "OUTLINE",
		color = { 1, 1, 1, 1 },
	},
}

----------------------------------------
-- frame movement
----------------------------------------

--setting this to false will use the default frame positions, true allows moving
cfg.framesUserplaced = true

--setting this to true will lock the frames in place, false unlocks them
cfg.framesLocked = true

----------------------------------------
-- player specific data
----------------------------------------

--player stuff
cfg.playername = UnitName("player")
cfg.playerclass = select(2, UnitClass("player"))
cfg.playercolor = RAID_CLASS_COLORS[cfg.playerclass]

----------------------------------------
-- Embeds
----------------------------------------
--rTooltip
cfg.rtooltip = {
	scale = 1.15,
	pos = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 150 },
	cursorfocus = false,
	itemDress = true, -- item tooltips: Diablo title plate, footer rule and the item's icon beside it, in its quality colour
}

--rObjectiveTracker
cfg.tracker = {
	scale = 1,
	point = { "TOPRIGHT", -190, -200 },
	size = { 260, 450 },
}
--rInfostrings
cfg.frame = {
	scale = 0.95,
	pos = { a1 = "TOP", af = "Minimap", a2 = "TOP", x = 0, y = -5 }, -- Just inside the top of the minimap
	userplaced = true, --want to place the bar somewhere else?
}
cfg.showXpRep = true --show xp or reputation as string
cfg.showMail = false --show mail as text

--rChat
cfg.hideChatTabBackgrounds = true
cfg.selectedTabColor = { 1, 0.75, 0 }
cfg.selectedTabAlpha = 1
cfg.notSelectedTabColor = { 0.5, 0.5, 0.5 }
cfg.notSelectedTabAlpha = 0.3
cfg.HideCustomCombatLog = true
cfg.ScrollingEmotes = false

--rMinimap
cfg.minimap = {
	scale = 1,
	alpha = 0.85,
	point = { "TOPRIGHT", 0, -33 }, -- Shift for anniv (under header)
}

----------------------------------------
-- other
----------------------------------------

cfg.Nameplates = {
	showHealthValue = true,
	healthValueAsPercent = true,
	fontSize = 25,
}

-- Roth's power colours: its own mana blue, the rest read from Blizzard's
-- PowerBarColor. Never written into PowerBarColor itself: that table is
-- Blizzard's, and an entry written by an add-on taints every Blizzard frame
-- that reads it (the player / compact frames errored on secret values).
cfg.powercolors = setmetatable({ MANA = { r = 0, g = 0.4, b = 1 } }, { __index = PowerBarColor })
--fix the oUF mana color
oUF.colors.power["MANA"] = { 0, 0.4, 1 }

--font
if locale == "enUS" or locale == "enGB" then
	cfg.font = (mediapath .. "Expressway.ttf")
	cfg.chat = {
		font = (mediapath .. "Expressway.ttf"),
	}
else
	cfg.font = LSM:Fetch("font", "Expressway") or STANDARD_TEXT_FONT -- Fallback to LSM for compat
	cfg.chat = {
		font = LSM:Fetch("font", "Expressway") or STANDARD_TEXT_FONT,
	}
end
-- Diablo's display face for titles and the target's name. It only has Latin
-- letters, so other clients keep the text font.
if locale == "enUS" or locale == "enGB" then
	cfg.headerFont = (mediapath .. "Diablo Std Regular.otf")
else
	cfg.headerFont = cfg.font
end

--backdrop
cfg.backdrop = {
	bgFile = (mediapath .. "Tooltip_Background"),
	edgeFile = (mediapath .. "Tooltip_Border"),
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
-- Anniv Compat: Override early hide if needed
cfg.bars.visibility = "show" -- Ensure not hidden too early
