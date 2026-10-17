# Session Log — DiabolusUnits (2026-10-17)

## Overview
Created **DiabolusUnits** (`/Users/erik2/Developer/WoW/DiabolusUnits`, symlinked to `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/DiabolusUnits`) by repurposing and modernizing `Roth_UI` for **WoW Forever (`_classic_beta_`, Interface `11508`)** as a standalone Diablo III HUD addon that supports both **Gamepad Mode (native Crossbar)** and **Standard (Keyboard/Mouse) Mode** with automatic transition (`INPUT_DEVICE_INTERFACE_TRANSITION`).

---

## Chronological Milestones & Commits

### 1. Initial Salvage & Edit Mode Overhaul (`12f3f3e`)
- Cloned and rebranded `Roth_UI` into `/Users/erik2/Developer/WoW/DiabolusUnits` (`DiabolusUnits.toc`), disabling the legacy `rActionBarStyler` takeover so WoW Forever's native action bars and Gamepad Crossbar remain taint-free.
- Rebuilt [`core/editmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/editmode.lua) and [`core/lib.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/lib.lua):
  - Fixed the broken `/diabolus edit` / `/diablo edit` drag-and-drop workflow (where `Alt+Shift` trapped clicks) so frames are directly Left-Click draggable whenever Edit Mode is active (`ns.editModeActive`).
  - Added MouseWheel scaling (`±2%` per tick, `0.4x`–`2.5x`) and Right-Click reset to default position/scale.
  - Added `ApplySavedFrameLayout(f)` on frame registration so custom positions and scales in `Roth_UI_DB.profile.framePositions` / `frameScales` persist across `/reload`.
  - Hooked Blizzard's `EventRegistry` (`EditMode.Enter` / `EditMode.Exit`) so opening WoW Forever's native Edit Mode automatically toggles DiabolusUnits' teal drag overlays alongside a floating control bar.

### 2. Diablo Potion Belt Module (`a7faa43`)
- Added [`core/belt.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/belt.lua) and [`Bindings.xml`](file:///Users/erik2/Developer/WoW/DiabolusUnits/Bindings.xml):
  - Created `Roth_UIBelt`, a 4-slot `SecureActionButtonTemplate` utility sash styled with `Roth_UI`'s stone border and gloss textures:
    1. **Slot 1 (`[H]`)**: Healthstone (`5512`..`19013`) + Best Healing Potion in bags.
    2. **Slot 2 (`[M]`)**: Mana Gem + Best Mana / Rejuvenation Potion in bags.
    3. **Slot 3 (`[B]`)**: Best Bandage in bags (`target="player"`).
    4. **Slot 4 (`[U]`)**: Hearthstone (`6948`) or custom item ID (`/diabolus belt slot4 <itemID|reset>`).
  - Scans bags automatically on `BAG_UPDATE_DELAYED` and updates secure macro attributes out of combat (or queues update until `PLAYER_REGEN_ENABLED`).

### 3. Bottom Stone Ledge, 10-Segment XP/Rep Trough & Seamless Mode Engine (`245c031`)
- Updated [`core/bars.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/bars.lua):
  - Restored `Roth_UIBottomLine` (`d3_bottom.tga`), `Roth_UIActionBarBackground` (`bar1.tga` / `bar2.tga` / `bar3.tga`), and `Roth_UIPlayerFrameBottom`.
  - Styled `Roth_UIExpBar` and `Roth_UIRepBar` with a dark stone trough (`decorateDiabloBar`) and 9 vertical segment dividers (10 segments = 10% per tick) spanning seamlessly between the Health Orb and Power Orb pedestals.
- Added [`core/standardmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/standardmode.lua):
  - Detects Gamepad vs. Standard mode via `C_InputInterfaceStyle.GetCurrentStyle()` and `GamepadMainActionBarFrame:IsShown()`.
  - Listens to `INPUT_DEVICE_INTERFACE_TRANSITION`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED`, and `EditMode.Exit`.

### 4. Sculpted Stone Wing Pedestals & 12-Slot Action Bar Fitting (`790cf8c`)
- Generated [`media/d3_wing_dock.tga`](file:///Users/erik2/Developer/WoW/DiabolusUnits/media/d3_wing_dock.tga) (`512x128` 32-bit uncompressed RGBA TGA) from the sculpted stone arch, upper/lower moldings, and recessed dark bay of `bar1.tga`, with an alpha-feathered inner shoulder designed to tuck behind the Demon and Angel statues.
- Fixed WoW Forever (`_classic_beta_` / Camelot) `MainActionBar` integration:
  - Hid `MainActionBar.EndCaps` (`LeftEndCap`, `RightEndCap`), `MainActionBar.BorderArt`, and `HorizontalDividersPool` / `VerticalDividersPool`.
  - Hid `btn.SlotArt` and `btn.SlotBackground` on each action button so zork's crossed-sword stone slot grid (`bar1.tga`/`bar2.tga`/`bar3.tga`) shows through empty slots.
  - Normalized `btn.container` scale (`1.0`) and computed scale-invariant `unitScale` relative to `Roth_UIActionBarBackground:GetEffectiveScale()` so all 12 buttons (`ActionButton1..12`, `MultiBarBottomLeftButton1..12`, `MultiBarBottomRightButton1..12`) land squarely inside the 12 stone slots regardless of Blizzard's Icon Size slider.

### 5. Standard Mode Scale, Paging `+/-` Buttons, Wing Alignment & Dynamic Potion Belt (`71568dd`)
- **Larger Default Action Bar (`1.18x`)**:
  - Added `standardBarScale = 1.18` and widened `standardOrbX = 300` in [`config.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/config.lua#L106-L115).
  - Scaled `Roth_UIActionBarBackground` to `1.18x` in Standard Mode (`1.0x` in Gamepad Mode), positioned Demon/Angel statues at `-330` / `+325`, and expanded `Roth_UIBottomLine` width to `800` so the bottom stone ledge bridges behind the statues without gaps.
- **ActionBar Paging `+/-` Buttons (`SetupActionBarPaging`)**:
  - Restored `MainActionBar.ActionBarPageNumber` (the up/down paging arrows and current page number) and anchored it onto the carved left stone shoulder of `Roth_UIActionBarBackground` (`x = -196.5`, `y = 36.5` in `barBg`'s `512x256` space, just left of `ActionButton1`).
- **Micro Menu & Bag Wing Alignment (`SetupMicroDock` / `SetupBagDock`)**:
  - Positioned `Roth_UIMicroDock` and `Roth_UIBagDock` dynamically from `demonX` and `angelX` so the recessed button bays (`68.75%` of `d3_wing_dock.tga`) sit completely outside the Demon (`demonX - 92`) and Angel (`angelX + 92`) statues while the inner stone shoulders still tuck ~45px behind the statues.
  - Added `ComputeVisibleButtonsCenterBias()` to measure the actual visible buttons' bounding box (`minLeft..maxRight`) and center them inside the recessed bay (hiding `KeyRingButton` when empty and collapsing `CharacterReagentBag0Slot` / `BagBarExpandToggle`).
- **Dynamic Potion Belt Anchor**:
  - In Standard Mode, `Roth_UIBelt` now anchors automatically to the top-left of the uppermost activated action bar row (`ActionButton1`, `MultiBarBottomLeftButton1`, or `MultiBarBottomRightButton1` with `BOTTOMLEFT -> TOPLEFT (-4, 8)`).
