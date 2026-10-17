# Handoff Guide — DiabolusUnits

## 1. Repository & Symlink Setup
- **Source Repository**: [`/Users/erik2/Developer/WoW/DiabolusUnits`](file:///Users/erik2/Developer/WoW/DiabolusUnits)
- **Client Symlink**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/DiabolusUnits -> /Users/erik2/Developer/WoW/DiabolusUnits`
- **Target Client**: WoW Forever (`_classic_beta_`, Interface `11508`, Camelot / modern hybrid API).
- **SavedVariables**: `Roth_UI_DB`, `Roth_UI_DB_Char` (kept compatible with existing settings while migrating out of `Roth_UI`).

---

## 2. Architecture & Key Files
- [`DiabolusUnits.toc`](file:///Users/erik2/Developer/WoW/DiabolusUnits/DiabolusUnits.toc) — Addon manifest; loads core, units, and modules in order.
- [`config.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/config.lua) — Default configuration:
  - `cfg.standardMode` (`lines 106–115`):
    - `enabled = true`
    - `padOrbX = 325` (Gamepad Mode orb offset)
    - `standardOrbX = 300` (Standard Mode orb offset around the `1.18x` 12-slot bar)
    - `standardBarScale = 1.18` (Scale of `Roth_UIActionBarBackground` and fitted action buttons in Standard Mode)
    - `integrateActionBars = true`, `integrateBags = true`, `integrateMicroMenu = true`
    - `dockFadeAlpha = 0.85`
- [`core/standardmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/standardmode.lua) — Seamless **Gamepad Mode <-> Standard Mode** layout engine:
  - `StandardMode:IsGamepad()` checks `C_InputInterfaceStyle.GetCurrentStyle()` and `GamepadMainActionBarFrame:IsShown()`.
  - `HideBlizzardBarArt()` hides `MainActionBar.EndCaps` (`LeftEndCap`/`RightEndCap`), `MainActionBar.BorderArt`, dividers, and duplicate status bars while keeping `MainActionBar.ActionBarPageNumber` available.
  - `FitActionBarRow(prefix, rowBottomY, barFrame)` positions and scales `ActionButton1..12`, `MultiBarBottomLeftButton1..12`, and `MultiBarBottomRightButton1..12` into the 12 stone slots of `bar1.tga` / `bar2.tga` / `bar3.tga` using `ns.Blizz` C base methods (zero taint).
  - `SetupActionBarPaging(barFrame)` places `MainActionBar.ActionBarPageNumber` (`+/-` buttons & page number) on the carved left stone shoulder of `bar1.tga` (`x = -196.5`, `y = 36.5` in `512x256` space).
  - `SetupMicroDock(isPad, demonX)` and `SetupBagDock(isPad, angelX)` create `Roth_UIMicroDock` and `Roth_UIBagDock` using [`media/d3_wing_dock.tga`](file:///Users/erik2/Developer/WoW/DiabolusUnits/media/d3_wing_dock.tga), positioning their recessed bays just outside the Demon (`demonX - 92`) and Angel (`angelX + 92`) statues and centering the visible buttons via `ComputeVisibleButtonsCenterBias()`.
  - Anchors `Roth_UIBelt` (Potion Belt) to the top-left of the uppermost activated action bar row (`ActionButton1`, `MultiBarBottomLeftButton1`, or `MultiBarBottomRightButton1`) in Standard Mode, or beside the Health Orb in Gamepad Mode.
- [`core/bars.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/bars.lua) — Creates `Roth_UIExpBar`, `Roth_UIRepBar` (with 10-segment Diablo tick marks via `decorateDiabloBar`), `Roth_UIActionBarBackground` (`bar1`/`bar2`/`bar3`), `Roth_UIBottomLine` (`d3_bottom.tga`), and `ns.PlayerArt.refresh()`.
- [`core/belt.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/belt.lua) — 4-slot `SecureActionButtonTemplate` Diablo Potion Belt (`Roth_UIBelt`) with automatic bag scanning for Healthstone/Healing Potion, Mana Gem/Mana Potion, Bandage, and Hearthstone/Custom Item.
- [`core/editmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/editmode.lua) & [`core/lib.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/lib.lua) — Interactive `/diabolus edit` mode (Left-drag move, MouseWheel scale, Right-click reset) synced with Blizzard's Edit Mode (`EditMode.Enter` / `EditMode.Exit`).

---

## 3. What to Test Next In-Game (`/reload`)
1. **Run `/reload` in WoW Forever** (and if any frame was previously dragged in `/diabolus edit`, run `/diabolus reset` or right-click its teal overlay in `/diabolus edit` to pick up the new default coordinates).
2. **Verify Standard Mode (commit `71568dd`)**:
   - **Action Bar Scale (`1.18x`)**: Check that the 12 action buttons and stone grid are comfortably larger and the Health/Power Orbs (`±300`) and Demon/Angel statues (`-330` / `+325`) hug the bar cleanly.
   - **ActionBar Paging `+/-` Buttons**: Check the carved left stone shoulder just to the left of `ActionButton1` — `MainActionBar.ActionBarPageNumber` (`UpButton`, `DownButton`, and page number) should sit on that flat stone shoulder. If it needs a slight `x`/`y` nudge, adjust `SetupActionBarPaging` in [`core/standardmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/standardmode.lua#L256-L275).
   - **Left Micro Menu Wing & Right Bag Bar Wing**: Verify that neither the Demon nor the Angel statue overlaps any Micro Menu or Bag button, and that the buttons sit centered in the recessed bays of `d3_wing_dock.tga`.
   - **Potion Belt Anchor**: Toggle Action Bar 2 / Action Bar 3 in Options -> ActionBars and verify `Roth_UIBelt` automatically moves to the top-left of the highest visible action bar row (Row 1, Row 2, or Row 3).
3. **Verify Gamepad Mode Transition**:
   - Press a controller button to trigger `INPUT_DEVICE_INTERFACE_TRANSITION` and confirm that `Roth_UIActionBarBackground`, `Roth_UIMicroDock`, and `Roth_UIBagDock` hide while the Orbs widen to `±325` and the Potion Belt moves beside the Health Orb.

---

## 4. Useful Slash Commands
- `/diabolus edit` (or `/diablo edit`) — Toggle DiabolusUnits Edit Mode overlays (Left-drag to move, Scroll to scale, Right-click to reset single frame).
- `/diabolus reset` — Reset all DiabolusUnits frames to their default positions and scales.
- `/diabolus belt` — Scan bags and print current Potion Belt assignments.
- `/diabolus belt slot4 <itemID|reset>` — Set custom utility item in Belt Slot 4.
