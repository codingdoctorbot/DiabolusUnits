# Handoff Guide — DiabolusUnits

## 1. Repository & Symlink Setup
- **Source Repository**: [`/Users/erik2/Developer/WoW/DiabolusUnits`](file:///Users/erik2/Developer/WoW/DiabolusUnits) (`https://github.com/codingdoctorbot/DiabolusUnits.git`)
- **Client Symlink**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/DiabolusUnits -> /Users/erik2/Developer/WoW/DiabolusUnits`
- **Target Client**: WoW Forever (`_classic_beta_`, Interface `11508`, Camelot / modern hybrid API).
- **SavedVariables**: `Roth_UI_DB`, `Roth_UI_DB_Char`.

---

## 2. Latest In-Game Verification (`~/Desktop/Screenshot 2026-10-17 at 12.05.33.png`)

### Confirmed Working in `12.05.33.png`
1. **1.18x Action Bar Scale & 12-Slot Stone Grid**:
   - `Roth_UIActionBarBackground` (`bar1.tga` / `bar2.tga` / `bar3.tga`) scales to `1.18x` in Standard Mode (`standardBarScale = 1.18`), and all 12 buttons per row (`ActionButton1..12`, `MultiBarBottomLeftButton1..12`, `MultiBarBottomRightButton1..12`) fit squarely inside the 12 crossed-sword stone slots.
   - Health & Power Orbs (`standardOrbX = 300`), Demon (`-330`) & Angel (`+325`) statues, and `Roth_UIBottomLine` (`780px` width) hug the scaled bar cleanly.
2. **ActionBar Paging `+/-` Buttons (`MainActionBar.ActionBarPageNumber`)**:
   - Visible (`^ 1 v`) on the carved left stone shoulder of `bar1.tga` just to the left of `ActionButton1`.
3. **Dynamic Potion Belt (`Roth_UIBelt`) Anchor**:
   - Automatically anchors to the top-left of the uppermost activated action bar row (Row 3 `MultiBarBottomRightButton1` in `12.05.33.png`).

---

## 3. Exact Polish Items Remaining (Observed in `12.05.33.png`)

1. **Left Micro Menu Wing (`SetupMicroDock` in [`core/standardmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/standardmode.lua#L430-L519))**:
   - **Observation**: The rightmost Micro Menu button (`?` Main Menu) still slightly overlaps the Demon statue's left skull/foot at the bottom-right of the wing, and the row of buttons sits ~4px low (touching the bottom stone bevel of `d3_wing_dock.tga`).
   - **Fix**:
     - Shift `defaultX` ~25px further left: change `local defaultX = (demonX or -330) - 215` to `(demonX or -330) - 240` (or compute from `wingW` so the right edge of the recessed bay `defaultX + 0.34375 * wingW` sits left of `demonX - 118`).
     - Raise vertical anchor in `SetupMicroDock` from `31 / scale` to `35.5 / scale` so the buttons sit centered vertically in the dark recessed bay above the lower stone lip.

2. **Right Bag Bar Wing (`SetupBagDock` in [`core/standardmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/standardmode.lua#L521-L598))**:
   - **Observation**: The 5 bag buttons (`MainMenuBarBackpackButton` + `CharacterBag0..3Slot`) sit slightly toward the left half of the recessed bay (leaving empty dark bay space on the right) and ~4px low (`31 / scale`).
   - **Fix**:
     - Before calling `pcall(bb.Layout, bb)`, set `includeInLayout = false` and `SetSize(0.001, 0.001)` on hidden children (`_G.KeyRingButton`, `_G.CharacterReagentBag0Slot`, `_G.BagBarExpandToggle`) so Blizzard's `GridLayoutFrame:Layout()` computes `BagsBar`'s width strictly from the 5 visible bag buttons.
     - Raise vertical anchor in `SetupBagDock` from `31 / scale` to `35.5 / scale` (and nudge `defaultX` from `(angelX or 325) + 195` to `(angelX or 325) + 215` if needed so the leftmost bag clears the Angel statue's foot).

3. **XP / Rep Bar Vertical Seating at `1.18x` Bar Scale ([`core/bars.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/bars.lua#L290-L332))**:
   - **Observation**: Because `Roth_UIActionBarBackground` is scaled by `1.18x`, the single XP bar (`y = 5, height = 12`) slightly overlaps the bottom stone border below `ActionButton1..12` by ~2px.
   - **Fix**: In `bars.UpdateStatusBarLayout()` ([`core/bars.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/bars.lua#L326-L328)), lower single-bar `y` from `5` to `2` and `SetHeight(9)` (and for `count == 2`, use `y = 11` / `y = 2` with `SetHeight(8)`) so the status bar sits cleanly inside the bottom dark stone trough.

4. **Chat Welcome Message String**:
   - In `12.05.33.png`, the login message still says `Type /roth edit to customize frames or /roth for commands.` (in [`core/editmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/editmode.lua)); update the printed string to `/diabolus edit` / `/diabolus` (while keeping `/roth` as an alias).

---

## 4. Key Files Reference
- [`config.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/config.lua) — `cfg.standardMode` (`padOrbX = 325`, `standardOrbX = 300`, `standardBarScale = 1.18`, `dockFadeAlpha = 0.85`).
- [`core/standardmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/standardmode.lua) — Gamepad <-> Standard Mode layout engine, 12-slot fitting, paging `+/-` buttons, wing docks (`Roth_UIMicroDock`, `Roth_UIBagDock`), and dynamic Potion Belt anchoring.
- [`core/bars.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/bars.lua) — `Roth_UIActionBarBackground`, `Roth_UIBottomLine`, and 10-segment Diablo `Roth_UIExpBar` / `Roth_UIRepBar`.
- [`core/belt.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/belt.lua) — 4-slot `SecureActionButtonTemplate` Diablo Potion Belt (`Roth_UIBelt`).
- [`core/editmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/editmode.lua) — `/diabolus edit` and `/diabolus reset`.
