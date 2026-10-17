# Handoff Guide — DiabolusUnits

## 1. Repository & Symlink Setup
- **Source Repository**: [`/Users/erik2/Developer/WoW/DiabolusUnits`](file:///Users/erik2/Developer/WoW/DiabolusUnits) (`https://github.com/codingdoctorbot/DiabolusUnits.git`)
- **Client Symlink**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/DiabolusUnits -> /Users/erik2/Developer/WoW/DiabolusUnits`
- **Target Client**: WoW Forever (`_classic_beta_`, Interface `11508`, Camelot / modern hybrid API).
- **SavedVariables**: `Roth_UI_DB`, `Roth_UI_DB_Char`.

---

## 2. In-Game Architecture & Design Status

### Confirmed Working & Verified In-Game
1. **`/reload` Persistence & Scale Integrity ([`core/lib.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/lib.lua), [`core/editmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/editmode.lua))**:
   - **Root Cause Solved**: All frames now use `f:SetUserPlaced(false)` so WoW's C++ `layout-local.txt` cannot hijack coordinates when `ApplyPixelPerfectScale()` updates `UIParent:SetScale()`. `RestoreSavedLayout()` explicitly calls `ns.StandardMode:Apply()` at the end of `PLAYER_LOGIN`. Verified in `Screenshot 2026-10-17 at 12.17.56.png` with a clean `/reload`.
2. **1.18x Action Bar Scale & 12-Slot Stone Grid**:
   - `Roth_UIActionBarBackground` (`bar1.tga` / `bar2.tga` / `bar3.tga`) scales to `1.18x` in Standard Mode (`standardBarScale = 1.18`), and all 12 buttons per row (`ActionButton1..12`, `MultiBarBottomLeftButton1..12`, `MultiBarBottomRightButton1..12`) fit squarely inside the 12 crossed-sword stone slots via `ns.Blizz` C base methods (zero taint).
   - Health & Power Orbs (`standardOrbX = 300`), Demon (`-330`) & Angel (`+325`) statues, and `Roth_UIBottomLine` (`780px` width) hug the scaled bar cleanly.
3. **ActionBar Paging `+/-` Buttons (`MainActionBar.ActionBarPageNumber`)**:
   - Styled and anchored (`^ 1 v`) on the carved left stone shoulder of `bar1.tga` just to the left of `ActionButton1`.
4. **Potion Belt (`Roth_UIBelt`) Anchored Above Bags ([`config.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/config.lua), [`core/standardmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/standardmode.lua))**:
   - In Standard Mode (`beltAnchor = "bags"`), the 4-slot Potion Belt anchors directly above the Right Bag Bar Wing (`Roth_UIBagDock` with `BOTTOM -> TOP, 0, -2`).
   - In Gamepad Mode, it anchors beside the Health Orb.
   - Setting `cfg.standardMode.beltAnchor = "actionbar"` reverts it to the top-left of the action bar if preferred.
5. **Pet Action Bar (`PetActionBar` / `PetActionBarFrame`) Anchored to Top Action Bar**:
   - Anchored to the top-left of the uppermost activated action bar row (`topRowFirstBtn` = `ActionButton1`, `MultiBarBottomLeftButton1`, or `MultiBarBottomRightButton1`) with `scale = 0.85` and `BOTTOMLEFT -> TOPLEFT, 0, 6`. Buttons styled with crossed-sword slot backgrounds and zero taint via `ns.Blizz`.
6. **Wing Pedestals (`Roth_UIMicroDock` & `Roth_UIBagDock`)**:
   - Raised button vertical center to `y = 35 / scale` so buttons sit centered above the bottom stone lip of `d3_wing_dock.tga`.
   - MicroDock positioned at `defaultX = (demonX or -330) - 235` to clear the Demon statue's skull.
   - BagDock hides empty `KeyRingButton`, `CharacterReagentBag0Slot`, and `BagBarExpandToggle` from layout so the 5 bags center inside the right stone bay.
7. **XP / Rep Bar Vertical Seating**:
   - Single bar seated at `y = 2`, `height = 9` in [`core/bars.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/bars.lua) so it fits inside the bottom dark stone trough below Row 1 under `1.18x` bar scale.
8. **Chat Command**:
   - Updated login message to `/diabolus edit` and `/diabolus` (with `/roth` alias preserved).

---

## 3. Configuration & Settings Reference ([`config.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/config.lua))
```lua
cfg.standardMode = {
    enabled = true,
    integrateActionBars = true, -- scale & fit ActionButton1..12 / MultiBars into bar1/bar2/bar3 slots
    integrateMicroMenu = true,  -- dock Game Menu micro buttons on the left outer stone wing
    integrateBags = true,       -- dock Bag slots + Backpack on the right outer stone wing
    integratePetBar = true,    -- anchor PetActionBar to the top-left of the uppermost active actionbar row
    beltAnchor = "bags",        -- "bags" = above Roth_UIBagDock; "actionbar" = top-left of top actionbar
    dockFadeAlpha = 0.85,      -- idle alpha for Micro Menu & Bag buttons (1.0 on mouseover)
    padOrbX = 325,              -- orb X offset in Gamepad mode (around crossbar)
    standardOrbX = 300,         -- orb X offset in Standard mode (hugging 1.18x stone bar)
    standardBarScale = 1.18,    -- scale of 12-slot stone bar & action buttons in Standard mode
}
```

---

## 4. Key Files
- [`config.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/config.lua) — Master HUD settings and mode configuration.
- [`core/standardmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/standardmode.lua) — Gamepad <-> Standard Mode layout engine, 12-slot fitting, paging `+/-` buttons, wing docks, PetBar, and Belt anchors.
- [`core/bars.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/bars.lua) — `Roth_UIActionBarBackground`, `Roth_UIBottomLine`, and 10-segment Diablo `Roth_UIExpBar` / `Roth_UIRepBar`.
- [`core/belt.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/belt.lua) — 4-slot `SecureActionButtonTemplate` Diablo Potion Belt (`Roth_UIBelt`).
- [`core/editmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/editmode.lua) & [`core/lib.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/lib.lua) — `/diabolus edit`, `/diabolus reset`, and `RestoreSavedLayout()`.
- [`session.md`](file:///Users/erik2/Developer/WoW/DiabolusUnits/session.md) — Chronological session changelog and verification log.
