# Diabolus Orbs Forever — credits

Diabolus Orbs Forever is the WoW Forever edition of Roth UI, and many people's work. This file lists who made what. It is a **private alpha**: please don't redistribute it.

## Lineage

| Years | Who | What |
|---|---|---|
| ~2008–2016 | **zork** (Lars Norberg) | Created oUF_Diablo and Roth UI: the Diablo orbs, the art, the layout. MIT licence. <https://github.com/zorker/rothui> |
| 2012–2018 | **Galaxy** (Galaxy119 / Joker119) | Maintainer; zork handed the project over at Legion launch (2016). rTooltip ("Galaxy – 2016"). <https://github.com/joker-119/Roth_UI> |
| 2025 | **EchoZulu69er** | TBC Anniversary edition: compatibility fixes and modernisation (assisted by Grok and Cursor AI). |
| 2026 | **codingdoctorbot** | WoW Forever edition (Interface 16001): secret-value port; gamepad layer; party and raid frames; rings; rumble; healer features; potion belt; pad HUD mover. Built with AI assistance: Claude (Anthropic) wrote most of the code and tests from stage 0 on; Gemini / Antigravity (Google) did the first port pass and two audits. |

## Embedded addons and libraries

These ship inside Roth UI and keep their own authors and licences.

| Part | Author | Licence |
|---|---|---|
| oUF 1.6.8 (`embeds/oUF`) | Trond A. Ekseth (haste), with oUF contributors | MIT (`embeds/oUF/LICENSE`) |
| rLib, rChat, rMinimap, rInfostrings, rActionBarStyler and the other `r*` embeds | zork | MIT (Roth UI) |
| rTooltip | Galaxy | MIT (Roth UI) |
| ShinyBuffs (`embeds/Roth_ShinyBuffs`) | Seerah, edited for Roth UI | to confirm before any release |
| RothFont (keeps the saved variable `PhanxFontDB`) | probably derived from Phanx's PhanxFont | origin and licence to confirm |
| Target frame art | Goldpaw (Diabolic UI) | to confirm before any release |
| Fonts in `media/`: Diablo Std (titles), Expressway (text), Cracked Narrow | not recorded in the add-on | to confirm before any release (nine unused fonts were removed in stage 25) |
| Ace3 (AceAddon, AceEvent, AceConsole, AceHook, AceLocale, AceDB, AceDBOptions, AceGUI, AceConfig), CallbackHandler, LibStub — current release, taken from Bartender4 4.18.3.1's libs | Ace3 Development Team | BSD-style (`Libs/Ace3-LICENSE.txt`) |
| LibSharedMedia-3.0 | Elkano | LGPL 2.1 |
| AceGUI-3.0-SharedMediaWidgets (current release, from Bartender4's libs) | Yssaril and contributors | to confirm |

## What the WoW Forever edition took from other add-ons

Code that was copied keeps a pointer to its source in the file's header comment.

| Roth file | Taken from | What | Source licence |
|---|---|---|---|
| `core/healbars.lua`, `core/orbshield.lua`, `core/powercost.lua` | **ForeverUnitFrames** (StephanRosin): `Elements/HealPrediction.lua`, `Absorb.lua`, `PowerCost.lua` | The technique: status bars on the health scale that hang from the fill, cut by a clipping frame, with secret values passed through untouched. Roth's code is its own. | No licence file (all rights reserved): technique only |
| `core/buffcoverage.lua` | ForeverUnitFrames `Raid/BuffData.lua`; **MSUF** (Mapko) `MSUF_GroupFrames_BuffCoverage.lua` | Spell IDs for every rank (game data); "running low" at a third of the duration; the group-wide model | No licence file: data and ideas only |
| `core/castbars.lua` | **MSUF**: `MSUF_CastbarChannelTicks.lua`, `MSUF_InterruptReady.lua` | Channel tick counts per spell ID (client data that MSUF measured); the Vanilla interrupt list | No licence file: data and ideas only |
| `core/fivesecond.lua` | ForeverUnitFrames `FiveSecondRule.lua` | Passing a secret spell ID straight to `GetSpellPowerCost` | Technique only |
| `modules/oUF_AuraWatch.lua` spell list | **Grid2** (Pastamancer, Maia, Jerry, Toadkiller): `GridPlayerSpellsForever.lua` | Spell IDs for every rank | zlib |
| `pad/nav.lua`, `pad/mover.lua` | MSUF `Game/Forever/PadNavigation.lua` | Navigation on one owned input frame, never registered with SmartNavigation; stick deadzone and speed ramp | Ideas only |
| `pad/mover.lua` | **ControllerApex** (codingdoctorbot) `UI/LiveHUDMover.lua` | Pieces, stick moving, cancel | Own add-on |
| `pad/ring.lua` | **ControllerApex** (codingdoctorbot) `Modules/Rings/RingFrame.lua` | The secure ring engine, cut down | Own add-on |
| `pad/haptics.lua`, `pad/hapticcues.lua`, `pad/hapticdevices.lua`, `pad/haptictextures.lua`, `pad/hapticsocial.lua` | **PulseHaptics** (codingdoctorbot) | Rumble engine, cue shapes, controller profiles | Own add-on |
| `pad/hapticcompass.lua` | **PulseCompass** (codingdoctorbot) `Radar.lua` | Bearing maths, stereo pan, distance cadence | Own add-on |
| `pad/hapticbossmods.lua` | **Deadly Boss Mods** (MysticalOS, QartemisT and the DBM team) | Only calls DBM's public `DBM_Announce` callback; no code copied | API use only |
| `pad/grouptarget.lua`, `pad/hapticnav.lua` | Blizzard's WoW Forever UI source | Uses the game's own SmartNavigation and GroupTargeting callbacks | — |
| `units/nameplates.lua` | **Plater** (Terciob and contributors), its WoW Forever build (`Plater_Camelot.toc`, `libs/DF/unitframe_midnight.lua`, `Plater_Auras.lua`) | Techniques only: keeping Blizzard's plate hidden with a hook on its Show; cast bars on `UnitCastingDuration` → `SetTimerDuration`; aura timers on `GetAuraDuration` → `SetCooldownFromDurationObject`. Roth's code is its own | GPLv2 (per its CurseForge page; no licence file in the download): no code copied, so nothing of Plater's is in Roth |
| `units/nameplates.lua` | Blizzard's `Blizzard_NamePlates` (Forever) | The plate life cycle and the soft-target icon (`SetUnitCursorTexture` with the `SoftTargetIcon*` settings) | — |

**Before any public release:** confirm permission or licences for ShinyBuffs, RothFont / PhanxFont, the Diabolic UI art, the fonts and the Diablo-style artwork in `media/`. ForeverUnitFrames and MSUF ship no licence file. Roth uses their techniques and game-data tables, not their code, but ask their authors before publishing anyway.

## Thanks

- The oUF community.
- WoWInterface and CurseForge, for hosting Roth UI over the years.
- Everyone who has played with Roth UI since 2008.

## Easy Controller - Forever (merged)

`embeds/EasyController/` is **Easy Controller - Forever** by **moust4ki**
(https://github.com/moust4ki/EasyControllerWowForever), MIT License (its
`LICENSE` is kept in that folder). Merged by `tools/ec_merge.py` without its
chat keyboard's word prediction and dictionaries, and without the parts it
took from ConsolePort (Artistic License 2.0). Roth's changes are in
`embeds/EasyController/_roth_pre.lua` and `_roth_post.lua`.

## Potion belt item rankings

The ranked item lists in `core/beltdata.lua` (health and mana potions,
healthstones, bandages, food, battleground items) follow **AutoPotion** by
**ollidiemaus** (version 3.17.2, its `Core/*/Forever.lua` lists). AutoPotion
is "all rights reserved"; only item IDs and their order (game data) were
taken, the belt code is DiabolusUnits' own. Licensing to be settled before
any public release.

The settings window framework (`settings/`) is ported from **PulseHaptics**
(same author as DiabolusUnits).
