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

## 3. Active Investigations & Architectural Fixes

### Combat Taint Analysis & Isolation (`units/player.lua`)
- **Observed Behavior**: In-game error popup / chat log: `the game refused Roth_UIActionBarBackground:Show() (DiabolusUnits, blocked)`.
- **Mechanism & Root Cause**:
  - `Roth_UIPlayerFrame` is created in `units/player.lua` as an `oUF` unit frame inheriting `SecureUnitButtonTemplate` (`ClickCastHeader` / secure action button).
  - In earlier revisions, `createActionBarBackground`, `createAngelFrame`, `createDemonFrame`, and `createBottomLine` passed `self` (`Roth_UIPlayerFrame`) as the parent argument to `CreateFrame`.
  - In Blizzard's secure execution model, calling `:Show()`, `:Hide()`, or modifying geometry on any child of a secure unit button during `InCombatLockdown()` flags the execution thread as tainted, resulting in `ADDON_ACTION_BLOCKED`.
  - When combat-triggered events or vehicle state updates ran `setupBarTexture()`, `f:Show()` was called on `Roth_UIActionBarBackground`, triggering the block.
- **Resolution**:
  1. Decoupled all decorative art frames (`Roth_UIActionBarBackground`, `Roth_UIAngelFrame`, `Roth_UIDemonFrame`, and `Roth_UIBottomLine`) by reparenting them directly to `UIParent`.
  2. Added an explicit `if InCombatLockdown() then return end` early-exit guard inside `setupBarTexture()`.

### Pet Action Bar Re-Anchoring Architecture (`core/standardmode.lua`)
- **Observed Behavior**: Toggling active action bar rows (enabling/disabling Bar 2 or Bar 3 in Settings) detaches `PetActionBar` from above the action bar and reverts it to Blizzard's default position (bottom-left of screen, hovering above chat) until the user executes `/reload`.
- **Root Cause Breakdown**:
  1. **Classic Positioning Engine**: WoW Forever (`_classic_beta_`, Interface `11508`) runs a modern engine build with Classic UI conventions. Toggling action bar rows in Interface Options calls Blizzard's legacy `UIParent_ManageFramePositions()`. This function executes `petBar:ClearAllPoints()` and `petBar:SetPoint()` directly on `PetActionBarFrame` / `PetActionBar`. Because DiabolusUnits hooked `petBar.ApplySystemAnchor` (an EditMode-specific method), Blizzard's repositioning pass bypassed our hook entirely.
  2. **Stale Closure Reference**: In `SetupPetBar(isPad, topRowFirstBtn)`, the reference `topRowFirstBtn` was passed as a static argument and captured in an anonymous closure registered once (`if not anchorHooked[petBar]`). When the player activated Bar 2 or Bar 3, the closure retained the initial button (`ActionButton1`), preventing dynamic recalculation of the topmost row.
  3. **Layout Pass Race Condition**: Synchronous hooks on `MultiBarBottomLeft:HookScript("OnShow", ...)` and `OnHide` invoked `StandardMode:Apply()` before Blizzard completed its internal multi-pass layout update. Blizzard subsequently executed `UIParent_ManageFramePositions()`, overwriting DiabolusUnits' custom anchor.
  4. **Combat Lockdown Constraints**: `PetActionBar` inherits secure templates and controls pet abilities. Calling `ClearAllPoints()` or `SetPoint()` on `PetActionBar` during `InCombatLockdown()` produces taint and blocked actions.
- **Architectural Solution**:
  1. **Dynamic Top Button Resolver (`StandardMode:GetTopRowFirstButton()`)**:
     - Evaluates visibility of action bars at runtime:
       - If `MultiBarBottomLeft:IsShown()` and `MultiBarBottomRight:IsShown()` -> returns `MultiBarBottomRightButton1`.
       - If `MultiBarBottomLeft:IsShown()` only -> returns `MultiBarBottomLeftButton1`.
       - If `MultiBarBottomRight:IsShown()` only -> returns `MultiBarBottomRightButton1`.
       - Otherwise -> returns `ActionButton1`.
  2. **Zero-Taint Re-Anchoring Method (`StandardMode:AnchorPetBar()`)**:
     - Implements an `inPetAnchor` boolean re-entrancy guard.
     - Strictly enforces `if InCombatLockdown() then pendingApply = true; return end`.
     - Utilizes raw C base methods (`Blizz.ClearAllPoints(petBar)` and `Blizz.SetPoint(petBar, "BOTTOMLEFT", topBtn, "TOPLEFT", 0, 6)`).
  3. **Blizzard SetPoint Hooking (`hooksecurefunc`)**:
     - Hooks `hooksecurefunc(petBar, "SetPoint", ...)` on both `PetActionBar` and `PetActionBarFrame`.
     - Catches Blizzard's internal `UIParent_ManageFramePositions()` repositions without overriding Blizzard execution logic.
     - Safe against recursion via the `inPetAnchor` guard.
  4. **Debounced Layout Queue**:
     - Uses `C_Timer.After(0.02, ...)` and `C_Timer.After(0.1, ...)` following `OnShow`/`OnHide` on `MultiBarBottomLeft`/`MultiBarBottomRight` and `SettingsPanel:OnHide` / `InterfaceOptionsFrame:OnHide`, allowing Blizzard's layout pass to complete before applying anchors.
  5. **Event Coverage**:
     - Handles `PET_BAR_UPDATE`, `PET_BAR_UPDATE_USABLE`, `UNIT_PET`, `ACTIONBAR_PAGE_CHANGED`, `UPDATE_BONUS_ACTIONBAR`, and `UPDATE_MULTI_CAST_ACTIONBAR`, queuing re-anchoring if fired during combat and applying immediately if out of combat.

---

## 4. Configuration & Settings Reference ([`config.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/config.lua))
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

## 5. Key Files
- [`config.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/config.lua) — Master HUD settings and mode configuration.
- [`core/standardmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/standardmode.lua) — Gamepad <-> Standard Mode layout engine, 12-slot fitting, paging `+/-` buttons, wing docks, PetBar, and Belt anchors.
- [`units/player.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/units/player.lua) — Decoupled art frames and combat lockdown protection.
- [`core/bars.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/bars.lua) — `Roth_UIActionBarBackground`, `Roth_UIBottomLine`, and 10-segment Diablo `Roth_UIExpBar` / `Roth_UIRepBar`.
- [`core/belt.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/belt.lua) — 4-slot `SecureActionButtonTemplate` Diablo Potion Belt (`Roth_UIBelt`).
- [`core/editmode.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/editmode.lua) & [`core/lib.lua`](file:///Users/erik2/Developer/WoW/DiabolusUnits/core/lib.lua) — `/diabolus edit`, `/diabolus reset`, and `RestoreSavedLayout()`.
- [`session.md`](file:///Users/erik2/Developer/WoW/DiabolusUnits/session.md) — Chronological session changelog and verification log.

---

## 6. Claude Code session 2026-10-17 ~13:00 — corrected root causes (uncommitted, needs in-game check)

Resource index: `resources.md`.

1. **Pet bar snapping back to Blizzard's default (Screenshot 12.42.19 vs 12.46.46).** Not `UIParent_ManageFramePositions`. In the Forever source, `EditModeManagerFrameMixin:UpdateBottomActionBarPositions()` (`Blizzard_EditMode/Shared/EditModeManager.lua:645`) calls `bar:ClearAllPoints()` / `bar:SetPoint()` on every bottom bar in default position, `PetActionBar` included, without going through `ApplySystemAnchor`. It runs on action bar toggles, override bar changes and on every `StatusTrackingBarContainerMixin:UpdateShownState()` (XP/rep bar shown-state changes, `Blizzard_StatusTrackingBar/Shared/StatusTrackingManager.lua:230`). Fix: `hooksecurefunc(EditModeManagerFrame, "UpdateBottomActionBarPositions", ...)` plus `ApplySystemAnchor` and `OnShow` hooks → `StandardMode:AnchorPetBar()`, which reads the top row at call time (`StandardMode:GetTopRowFirstButton()`), and queues a full Apply for `PLAYER_REGEN_ENABLED` when called in combat.
2. **Potion belt vanishing.** `core/belt.lua` `Place()` ran on every bag update / end of combat and re-anchored the belt beside the health orb (behind the action buttons), overriding the bag-wing anchor that only `StandardMode:Apply()` set. `Place()` now delegates to `StandardMode:AnchorBelt()` and refuses to move the (protected, because of its secure buttons) holder in combat.
3. **`Roth_UIActionBarBackground:Show()` blocked.** The parent was not the cause (a child of a secure frame does not become protected). The action buttons are anchored to this frame, which makes it protected through anchoring during combat. The reparent to `UIParent` is harmless and kept; the real fix is the combat guard in `setupBarTexture()`, which now also re-runs on `PLAYER_REGEN_ENABLED` instead of silently dropping the update.
4. **Scale balance.** `cfg.standardMode.standardBarScale = 1.30` (was 1.18), new `standardOrbScale = 0.85` and `standardStatueScale = 0.85`, `standardOrbX = 325`. Statue offsets, wing offsets and bottom-line width are derived from these. These are defaults: `EditMode:GetScale()` falls back to `StandardMode:DefaultScale()`, so a scale saved in the edit layout still wins, and wheel-scaling starts from the on-screen value. Positions are set with `PlaceAtBottom()`, which converts UIParent units into the frame's own scale.
5. **Reset UI pinned scales.** `ResetAllToDefault()` saved `frameScales[name] = 1` for every frame. It now shows the layout default for orbs/statues/bar without saving, and `RestoreSavedLayout()` runs a one-time cleanup (`db.layoutScaleDefaults`) that drops saved `1`s for those four frames.

Still open: wing (micro menu / bag bar) placement polish after seeing the new scales in game; `StanceBar` is not fitted into the stone grid; legacy `Roth_UI:ApplyResizeOptions()` still writes orb/statue scales at PLAYER_LOGIN (the layout overrides it afterwards).

## 7. Settings window + minimap button (Claude Code, 2026-10-17 afternoon, uncommitted, not yet seen in game)

- New `settings/` tree: one window for every setting (edit layout excluded, opened from it). Framework (Theme, Popup, Rows, Sidebar, Gamepad, Content) ported from PulseHaptics `UI/Panel` with a Diablo palette; `Spec.lua` (pages), `Panel.lua` (window, Esc > Options > AddOns canvas entry), `Settings.lua` (cfg overrides saved in `profile.settings["path.key"]`, re-applied at ADDON_LOADED), `Minimap.lua` (left-click settings, right-click edit layout, account-wide in `Roth_UI_DB_GLOB.minimap`).
- Pages: DiabolusUnits (overview, edit layout, minimap, resets), Layout (stone bar/orb/statue scales, orb distance, integrations, wing fade, pixel-perfect scale), Health orb, Power orb (all old orb-panel settings + templates), Potion belt, Fonts, Profiles (AceDB), Help.
- Taint choices: plain Show + UISpecialFrames (no ShowUIPanel), no Blizzard Menu / StaticPopup inside, closes on PLAYER_REGEN_DISABLED, the AddOns entry does not close Blizzard's settings window. Colour rows use ColorPickerFrame (Forever shows it with a plain Show, not ShowUIPanel) — verify with the gamepad UI on.
- Entry points: `/diabolus`, `/diabolus config`, minimap button, AddOns list. The AceConfig registration in `embeds/Roth_Config/Roth_Config.lua` is removed; the old orb panel (`core/panel.lua`) is no longer opened but still loads, because the orb pages call its save/load/update functions. Retiring its UI half is a follow-up.
- Headless smoke test of all pages: see `luajit` stub script in the session; 110 rows build and round-trip.
