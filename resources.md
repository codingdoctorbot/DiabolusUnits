# Resources — DiabolusUnits

Index of everything available for working on this addon. Paths are absolute unless noted.

## The addon
- Repo: `/Users/erik2/Developer/WoW/DiabolusUnits` (git, `origin` = `github.com/codingdoctorbot/DiabolusUnits`, branch `master`).
- Client symlink: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/DiabolusUnits` → repo. Edits are live after `/reload`.
- Start here: `handoff.md` (current state and open investigations), `session.md` (chronological log of the 2026-10-17 Gemini sessions).
- Key files: `config.lua` (`cfg.standardMode`), `core/standardmode.lua` (gamepad/standard layout, bar fitting, wing docks, pet bar, belt anchor), `core/belt.lua` (potion belt), `core/bars.lua` (bar art, XP/rep), `units/player.lua` (orbs, statues, bar background), `core/editmode.lua` + `core/lib.lua` (edit mode, saved layout), `core/blizzsafe.lua` (`ns.Blizz` — C base methods for Edit Mode frames).
- SavedVariables: `/Applications/World of Warcraft/_classic_beta_/WTF/Account/*/SavedVariables/Roth_UI.lua` (`Roth_UI_DB`; shares the name with the precursor).

## Precursor
- `Roth_UI`: `/Users/erik2/Developer/WoW/Roth_UI` (private repo `codingdoctorbot/Roth_UI`). DiabolusUnits was salvaged from it on 2026-10-17. Has `DESIGN.md`, `TESTING.md`, `HANDOVER.md`, headless tests in `tests/`.
- Original TBC 3.1.1 base of the port: `~/Downloads/Roth_UI`.
- Zips: `/Users/erik2/Developer/WoW/Roth_UI.zip`.

## Game client (WoW Forever, `_classic_beta_`, Interface 11508)
- Lua errors / taint: `/Applications/World of Warcraft/_classic_beta_/Logs/General.log` (flushed in bursts), `Logs/taint.log` when `/console taintLog 1|2` is set before login.
- Crash/freeze dumps: `/Applications/World of Warcraft/_classic_beta_/Errors/*.txt`.
- Blizzard UI source for this client: `/Users/erik2/Developer/WoW/_reference/Blizzard_Source/wow-ui-source-forever/Interface/AddOns` (relevant: `Blizzard_ActionBar`, `Blizzard_ActionBarController`, `Blizzard_EditMode`, `Blizzard_UIParent`, `Blizzard_GamepadActionBars`, `Blizzard_APIDocumentationGenerated`).
- Also: `_reference/Blizzard_Source/BlizzardInterfaceCode-main`, `BlizzardInterfaceResources-live` (retail, for comparison only).

## Screenshots (in-game, `~/Desktop`)
- 2026-10-17 session: `Screenshot 2026-10-17 at 10.45.57` … `12.46.46`.
  - `12.42.19` — pet bar back at Blizzard default (bottom-left above chat), potion belt missing.
  - `12.46.46` — same scene after `/reload`: intended look (pet bar on top action row, belt above bag wing).
  - `12.31.17` — pet bar unanchored after toggling action bars.
  - `12.17.56` — clean `/reload` verified; `12.05.33` — after `/diabolus reset`.
  - `11.22.58` — Blizzard default layout reset (micro menu left, bags right).
- Older Roth_UI references: `~/Developer/WoWScrnShot_*.jpg`, `~/Developer/wowscrnshot_*.jpg`.
- Icon art: `~/Desktop/Diabolus_Spell_Icons`, `~/Desktop/RothUI_Icons`.

## Gemini (Antigravity) transcripts
- Main DiabolusUnits session: `~/.gemini/antigravity/brain/67c501a7-2265-4a44-be7f-ec6338695312/.system_generated/logs/transcript.jsonl` (43 user messages, 10:3x–12:41). User uploads (old Roth UI look references) in `.user_uploaded/`.
- Side-question sessions the same day: other folders in `~/.gemini/antigravity/brain/` dated 2026-10-17.
- Treat Gemini's technical claims as unverified until checked against the Blizzard source (several earlier claims were wrong).

## Reference addons
- `/Users/erik2/Developer/Reference addons/`: ConsolePort-3.2.5, ControllerForever, EasyController, GamepadVibration, ImprovedForever_Vibration, PulseHaptics (read-only).
- `/Users/erik2/Developer/WoW/_reference/Reference_Addons/`: ConsolePort, DBM-Core, DBM-Dungeons, GamepadVibration.
- `~/Downloads/`: Bartender4 (action bar handling on Forever), ForeverUnitFrames, MSUF-6, ZPerl-7, Grid2-4, Plater (Camelot build), EasyController, HanharEnhancementHUD, DynamicCam.
- Other repos in `~/Developer`: `WoWAddonAPIAgents-main`, `wow-addon-dev-main`.

## Notes from earlier sessions
- Research/review docs: `~/Developer/WoW_Forever_RothUI_Code_Review.md`, `WoW_Forever_Reference_Addons_Research.md`, `WoW_Forever_Live_Error_Log.md`.
- Verified platform facts (secret values, Edit Mode `*Base` methods, forbidden panel calls, BLP format) are kept in Claude's memory and in Roth_UI `DESIGN.md`.

## Tools available here
- `luajit` (syntax / global-write checks: `luajit -bl file | grep GSET`), `luacheck` config in `.luacheckrc`, Python 3 with Pillow (image crops, TGA work), `sips`.
