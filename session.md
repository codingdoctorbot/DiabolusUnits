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

### 6. In-Game Verification (`Screenshot 2026-10-17 at 12.05.33.png`, commit `f77292c`)
- Verified in `~/Desktop/Screenshot 2026-10-17 at 12.05.33.png` after `/diabolus reset`:
  - **Confirmed Working**: `1.18x` scaled 12-slot stone bar (`ActionButton1..12`, `MultiBarBottomLeftButton1..12`, `MultiBarBottomRightButton1..12`), `^ 1 v` ActionBar paging buttons on the left stone shoulder, widened Orbs/Statues (`±300`, `-330` / `+325`), and Potion Belt (`Roth_UIBelt`) anchored to the top-left of Row 3.
  - **Logged in `handoff.md` for Next Session**:
    1. Shift `Roth_UIMicroDock` ~25px further left (`demonX - 240`) and raise button vertical center from `31 / scale` to `35.5 / scale` so the `?` button clears the Demon's left skull/foot and sits centered above the lower stone bevel.
    2. Set `includeInLayout = false` + `SetSize(0.001, 0.001)` on `KeyRingButton` / `CharacterReagentBag0Slot` / `BagBarExpandToggle` before `BagsBar:Layout()` and raise `y` to `35.5 / scale` so the 5 bags sit centered in the right wing bay.
    3. Lower single XP/Rep bar `y` from `5` to `2` (`height = 9`) in `core/bars.lua` so it clears Row 1's bottom stone border at `1.18x` scale.

### 7. Fixed `/reload` Layout Disappearance Bug (`Screenshot 2026-10-17 at 12.09.56.png` -> Verified Fixed in `12.17.56.png`)
- **Root Cause Found**:
  1. In [`core/lib.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/lib.lua#L995-L1082), `func.applyDragFunctionality` and `func.simpleDragFunc` called `f:SetUserPlaced(true)` on named frames (`Roth_UIPlayerFrame`, etc.). When `ApplyPixelPerfectScale()` changed `UIParent:SetScale(768 / physicalHeight)` (`0.4267` on `2880x1800` Retina) during `PLAYER_LOGIN`, WoW's C++ `layout-local.txt` restoration applied pre-scale coordinates to `Roth_UIPlayerFrame`, moving `Roth_UIPlayerFrame` (and its `CENTER`-anchored child `Roth_UIHealthOrb`) off-screen while `UIParent`-anchored children (`Roth_UIPowerOrb`, `Roth_UIActionBarBackground`, `Roth_UIAngelFrame`, `Roth_UIDemonFrame`) stayed on screen.
  2. In [`core/editmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/editmode.lua#L1556-L1651), `RestoreSavedLayout()` ran on `PLAYER_LOGIN` after `ApplyPixelPerfectScale()` and applied `db.frameScales` (which `ResetAllToDefault()` had populated with `1.0` for `Roth_UIActionBarBackground`), without calling `ns.StandardMode:Apply()` afterward.
- **Fix Applied**:
  - Changed `f:SetUserPlaced(true)` to `f:SetUserPlaced(false)` in `core/lib.lua` (both on creation and immediately after `StopMovingOrSizing()`) and cleared `SetUserPlaced(false)` across all `EDITABLE_FRAMES` in `RestoreSavedLayout()`, so `Roth_UI_DB.profile.framePositions` is the single source of truth and WoW's `layout-local.txt` never hijacks frame coordinates across `/reload`.
  - Called `ns.StandardMode:Apply()` at the end of `RestoreSavedLayout()` in `core/editmode.lua`.
- **Verified**: In `~/Desktop/Screenshot 2026-10-17 at 12.17.56.png`, a clean `/reload` (with no reset needed) renders the entire HUD identically to the post-reset state.

### 8. Potion Belt on Bags Wing & Pet Action Bar Anchor
- **Design Decision Implemented**:
  1. **Potion Belt on Bags**: Anchored `Roth_UIBelt` directly above `Roth_UIBagDock` (the right outer stone wing) in Standard Mode when `cfg.standardMode.beltAnchor == "bags"` (`belt:SetPoint("BOTTOM", bagDock, "TOP", 0, -2)`). This groups consumables/potions right above the bag bar and frees the top-left of the action bars for pet/stance commands.
  2. **Pet Action Bar on Action Bar**: Anchored `PetActionBar` / `PetActionBarFrame` (with `PetActionButton1..10`) to the top-left of the uppermost activated action bar row (`topRowFirstBtn` = `ActionButton1`, `MultiBarBottomLeftButton1`, or `MultiBarBottomRightButton1`) with `scale = 0.85` and `BOTTOMLEFT -> TOPLEFT, 0, 6`, hooked to `ApplySystemAnchor` without reparenting (zero taint).
  3. **Wing Alignment Polish**: Raised button centers from `31 / scale` to `35 / scale` in both `SetupMicroDock` and `SetupBagDock`, shifted MicroDock ~20px further left (`demonX - 235`) to clear the Demon's skull, and excluded `KeyRingButton` (when empty), `CharacterReagentBag0Slot`, and `BagBarExpandToggle` from `BagsBar:Layout()` so the 5 visible bags sit centered inside `d3_wing_dock.tga`.
  4. **XP Bar Seating**: Lowered single-bar `y` from `5` to `2` (`height = 9`) in `core/bars.lua` so it seats cleanly inside the stone trough below Row 1 under `1.18x` bar scale.
  5. **Settings Documented**: Documented `beltAnchor = "bags"`, `integratePetBar = true`, and the `/reload` scale integrity architecture in `config.lua` (`cfg.standardMode`).
