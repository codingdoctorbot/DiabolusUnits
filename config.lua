-- DiabolusUnits: defaults for the WoW Forever edition of Roth UI.
-- Original: zork (Erik Raetz); maintained by Galaxy119/Joker119 and EchoZulu69er.
-- Forever edition: codingdoctorbot, with Claude and Gemini assistance.
-- Credits: CREDITS.md. Version and client interface: DiabolusUnits.toc.

local addon, ns = ...
local oUF = ns.oUF
mediapath = "Interface\\AddOns\\DiabolusUnits\\media\\"
local addonName, Roth_UI = ...
local LSM = LibStub("LibSharedMedia-3.0")

local cfg = {}
ns.cfg = cfg
local locale = GetLocale()
-- // CONFIG // --

-- Native interface decoration; each component can defer to another skin addon.
cfg.interfaceSkin = {
    enabled = true,
    chat = true,
    minimap = true,
    objectives = true,
    gamepad = true,
    respectOtherAddons = true,
    border = { r = 0.52, g = 0.46, b = 0.37 },
    accent = { r = 0.78, g = 0.61, b = 0.34 },
    text = { r = 0.76, g = 0.73, b = 0.66 },
    gamepadBorder = { r = 0.70, g = 0.62, b = 0.49 },
    backgroundOpacity = 0.18,
    borderWidth = 1,
    headerFont = false,
}

-- // Incoming heals and absorbs // --
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

-- Legacy movable-aura option; its modules are not bundled. Use Blizzard Edit Mode.
cfg.movableAuras = false

-- A dark inner rim on both orbs, so the liquid reads as inside the glass.
cfg.orbInnerShadow = true

-- Diabolic UI (2016, MIT) art, each optional; off keeps the original art (core/diabolicart.lua).
cfg.diabolicArt = {
	portraits = false, -- rose-bronze portrait frames on player, target, focus and party
	orbRing = "none", -- "none", "ring" (bronze rim) or "glass" (rim with its own glass)
	minimapRing = false, -- spiked bronze ring around the minimap; fades the native rim
	smallFrames = false, -- target-of-target and focus: small single-bar frames instead of the large two-bar art
}

-- Diablo nameplates: iron frames, threat/target glows, cast bars, and player debuffs.
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
	gap = 24, -- above the player cast bar (clears the cast bar's stone frame)
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

-- Potion belt: five sockets plus optional drink; bindings are Belt 1-6.
cfg.belt = {
	showDrink = false, -- optional sixth socket; first five bindings retain their order
	macroStopCasting = false, -- prefix the action-bar click macros with /stopcasting
	buffFoodFirst = true, -- prefer a stat meal only when Well Fed is known to be missing
	foodStat = "auto", -- class default; manually choose a stat in settings
	includeRejuvenation = true, -- allow dual-restoration potions in the mana socket
	show = true,
	foodWarnMinutes = 10, -- food socket rim pulses when Well Fed has less than this left (or is missing)
	x = 6, -- offset relative to health orb BOTTOMRIGHT (clear of the orb rim)
	y = 24, -- above bottom stone ledge / XP bar
}

-- Keyboard defaults; gamepad geometry is configured separately below.
-- Saved per-mode layout overrides take precedence.
cfg.standardMode = {
	enabled = true,
	integrateActionBars = true, -- scale & fit ActionButton1..12 / MultiBars into bar1/bar2/bar3 slots
	integrateMicroMenu = true, -- dock Game Menu micro buttons on the left outer stone wing
	integrateBags = true, -- dock Bag slots + Backpack on the right outer stone wing
	integratePetBar = true, -- position the pet bar above the uppermost active action-bar row
	beltAnchor = "bags", -- "bags" = above Roth_UIBagDock in Standard Mode; "actionbar" = top-left of top actionbar
	petBarAnchor = "center", -- pet bar over the top action row: "left", "center" or "right"
	targetScale = 0.9, -- target frame default scale (the edit layout's size wins)
	microDockOffset = 235, -- game menu wing: centre's distance outward from the demon statue
	bagDockOffset = 240, -- bag wing: centre's distance outward from the angel statue
	microBodyHeight = 28, bagBodyHeight = 30,
	microButtonGap = 1, bagButtonGap = 2,
	microJoinOffset = 0, bagJoinOffset = 0,
	dockY = 0, -- complete stone base rests on the screen edge
	wingStyle = "stone", -- "stone" or a WingLayout.HarnessKits id (gothic_silver, antique_bronze, ...)
	wingTint = "natural", -- harness styles only: "natural", "warm" or "dark"
	microButtonsX = 0, -- game menu buttons inside their bay (0 = cleanly centered in the recessed bay)
	bagButtonsX = 0, -- bag buttons inside their bay (0 = cleanly centered in the recessed bay)
	beltDockX = 18, -- horizontal offset of potion belt over bag dock (shifts right to clear angel statue)
	beltDockY = 4, -- compact gap above the bag wing; the fitted rim already clears bag buttons
	petFrameOrbGap = -10, -- pet frame above an orb: its bottom edge vs the orb frame's top (both have empty margins; -10 leaves ~10 px of air)
	petFrameAnchor = "healthOrb", -- "healthOrb" = above the health orb; "orb" = above the power orb;
	-- "petbarLeft" / "petbarRight" = up and left / right of the pet bar
	targetFrameAnchor = "powerOrb", -- "powerOrb" = above power orb; "healthOrb" = above health orb; "top" = top of screen
	targetTargetFrameAnchor = "topright", -- "topright" = top-right over target; "topleft" = top-left; "left" = left; "right" = right
	targetFrameOrbGap = 12, -- target frame above power orb: its bottom edge vs the orb frame's top
	dockFadeAlpha = 0.85, -- idle alpha for Micro Menu & Bag buttons (1.0 on mouseover)
	padOrbX = 325, -- legacy setting; current spacing uses gamepadLayout.orbX
	standardOrbX = 325, -- orb X offset in Standard mode (hugging the 12-slot stone bar)
	standardBarScale = 1.30, -- scale of the 12-slot stone bar & action buttons in Standard mode
	standardOrbScale = 0.85, -- default scale of both orbs in Standard mode (edit layout scale wins)
	standardStatueScale = 0.78, -- default scale of the demon & angel statues in Standard mode
}

-- Gamepad defaults are independent of the keyboard layout. Edit Layout overrides
-- are saved in profile.gamepadLayout; these settings define its starting geometry.
cfg.gamepadLayout = {
 followCrossbar = true, -- follow the native Edit Mode actionbar position and scale
 orbX = 365, orbY = 10, orbScale = 0.82, artScale = 0.72, artY = -2,
 castGap = 36, castScale = 1, swingGap = 28, targetScale = 0.9,
 beltScale = 0.85, beltY = 40,
 arrangePanels = true,
 centerRadial = true, radialScale = 0.85,
}

-- // Embeds // --
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
-- colorswitcher define your color for healthbars here

-- RGBA components range from 0 to 1.
cfg.colorswitcher = {
	bright = { r = 1, g = 0, b = 0, a = 1 }, -- the bright color
	dark = { r = 1, g = 0, b = 0, a = 0.1 }, -- the dark color
	classcolored = true, -- true   -> override the bright color with the unit specific color (class, faction, happiness, threat), if false uses the predefined color
	useBrightForeground = true, -- true   -> use bright color in foreground and dark color in background
	-- false  -> use dark color in foreground and bright color in background
	threatColored = true, -- true/false -> enable threat coloring of the health plate for raidframes
}

-- Strength of the highlight that fades after health loss.
cfg.highlightMultiplier = 0 --range 0-1

--units

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
			colorStyle = "amber", -- paired XP/rested theme; selectable in Settings > Layout
			color = { r = 0.85, g = 0.48, b = 0.10 }, -- warm amber earned XP
			rested = {
				color = { r = 0.55, g = 0.26, b = 0.06 }, -- deeper amber rested extension
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
				show = true, -- shown in Standard (non-console) mode using compact bar1/bar2/bar3 slot grid; auto-hidden in Gamepad mode
				width = 512,
				height = 256,
				pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 0 },
				scale = 1,
			},
			angel = {
				show = true,
				pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 350, y = -2 },
				scale = 1,
			},
			demon = {
				show = true,
				pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = -355, y = -2 },
				scale = 1,
			},
			bottomline = {
				show = true,
				pos = { a1 = "BOTTOM", a2 = "BOTTOM", af = "UIParent", x = 0, y = 0 },
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

	-- TARGET
	target = {
		show = true,
		threatGlow = true, -- the frame glows red / orange while the target is attacking you
		showDragonCrest = true, -- horned dragon crest atop boss / elite targets
		healthFormat = "both", -- "both", "value", "percent", "deficit", "current", "none"
		powerFormat = "both", -- "both", "value", "percent", "none"
		details = {
			showName = true,
			showLevel = true,
			showCreatureType = true,
			showClassification = true,
			showClass = true,
		},
		scale = 1.5,
		width = 240, -- was 270 (originally 300)
		height = 64,
		pos = { a1 = "TOP", a2 = "TOP", af = "UIParent", x = 0, y = -80 },
		health = {
			frequentUpdates = true,
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:hpval]", -- Added class color support if tag allows
			fontSize = 10,
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
			fontSize = 10,
			point = "CENTER",
			x = 0,
			y = 0,
		},
		power = {
			frequentUpdates = true,
			texture = (mediapath .. "statusbar3"),
			tag = "[diablo:ppval]",
			fontSize = 10,
			point = "LEFT",
			x = -25,
			y = -30,
		},
		misc = {
			classFontSize = 11,
			NameFontSize = 14,
		},
		auras = {
			show = true,
			size = 15,
			placement = "right", -- "right", "above", "below", "left"
			onlyShowPlayerBuffs = false,
			showStealableBuffs = true,
			onlyShowPlayerDebuffs = false,
			showDebuffType = true,
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
		healthFormat = "deficit", -- "deficit", "percent", "value", "current", "both", "none"
		width = 150,
		height = 64,
		scale = 1.3,
		pos = { a1 = "BOTTOMRIGHT", a2 = "TOPRIGHT", af = "Roth_UITargetFrame", x = 0, y = 6 }, -- top-right over target frame, follows it
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
		healthFormat = "deficit", -- "deficit", "percent", "value", "current", "both", "none"
		scale = 0.64, -- 25% smaller than 0.85
		width = 128,
		height = 64,
		pos = { a1 = "RIGHT", a2 = "RIGHT", af = "UIParent", x = -30, y = -150 }, -- Shift
		auras = {
			show = true,
			size = 22,
			onlyShowPlayerDebuffs = false,
			showDebuffType = false,
		},
		nameSize = 12,
		nameY = -23, -- name: offset of its bottom from the frame top (lower = closer to the health bar)
		happiness = {
			scale = 1,
			pos = { a1 = "RIGHT", a2 = "LEFT", af = "self.Name", x = -3, y = 0 }, -- just left of the name text
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
			size = 60, -- portrait width (the frame is 128 wide; full width was oversized)
			lift = -14, -- portrait above the frame: move it down onto the health bar (frame units)
			side = true, -- portrait beside the frame on the left instead of above it
			sideX = 73, -- side portrait: horizontal offset (portrait units; higher = closer to the bars)
			sideY = 13, -- side portrait: vertical offset (portrait units)
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
		healthFormat = "both", -- "both", "percent", "deficit", "current", "value", "none"
		powerFormat = "value", -- "value", "percent", "none"
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
		healthFormat = "deficit", -- "deficit", "percent", "value", "current", "both", "none"
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
		healthFormat = "deficit", -- "deficit", "percent", "value", "current", "both", "none"
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
		show = true, -- Custom party frames; native party frames are faded.
		healthFormat = "deficit", -- "deficit", "percent", "value", "current", "both", "none"
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
		healthFormat = "deficit", -- "deficit", "percent", "value", "current", "both", "none"
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

-- Button / Cooldown Styling
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

-- frame movement

--setting this to false will use the default frame positions, true allows moving
cfg.framesUserplaced = true

--setting this to true will lock the frames in place, false unlocks them
cfg.framesLocked = true

-- player specific data

--player stuff
cfg.playername = UnitName("player")
cfg.playerclass = select(2, UnitClass("player"))
cfg.playercolor = RAID_CLASS_COLORS[cfg.playerclass]

-- Castbar presentation; size/position of the whole frame stays in Edit Layout.
for _, unit in ipairs({ "player", "target", "focus", "pet" }) do
 local bar = cfg.units[unit].castbar
 bar.width, bar.height = 265, 15
 bar.showName, bar.showTime = true, true
 bar.timeToHold = 0
 bar.TextSize = bar.TextSize or 11
end
cfg.units.player.castbar.showDelay = true
cfg.units.player.castbar.channelTicks = true
cfg.units.target.castbar.interruptReady = true
cfg.units.focus.castbar.interruptReady = true

-- Embeds
--rTooltip
cfg.rtooltip = {
	scale = 1.15,
 opacity = 1,
 width = 0, height = 0, -- minimum dimensions; zero keeps content-sized tooltips
 offsetX = 0, offsetY = 0,
 gamepadAnchor = "top", gamepadOffsetX = 0, gamepadOffsetY = 0,
 itemIcon = true, qualityBorder = true,
 showSpellID = true, showTarget = true, showHealth = true,
	-- where tooltips go: "bottomright" (above the belt / bag wing), "bottomleft" (mirrored, above
	-- the game menu wing), "center" (above the action bars, cast bar and swing timer), "cursor"
	anchor = "bottomright",
	pos = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 257 }, -- "bottomright"; also the fallback
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

-- other

cfg.Nameplates = {
	showHealthValue = true,
	healthValueAsPercent = true,
	fontSize = 25,
}

-- Copy Blizzard's power colours; writing into PowerBarColor taints its readers.
cfg.powercolors = setmetatable({ MANA = { r = 0, g = 0.4, b = 1 } }, { __index = PowerBarColor })
--the same mana blue for oUF's colorPower (ColorMixin objects, by token and by power type index)
oUF.colors.power.MANA = oUF:CreateColor(0, 0.4, 1)
oUF.colors.power[Enum.PowerType.Mana or 0] = oUF.colors.power.MANA

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
