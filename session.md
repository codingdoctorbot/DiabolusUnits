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

### 9. Combat Taint & Pet Bar Dynamic Re-Anchoring Technical Specification (`Screenshot 2026-10-17 at 12.31.17.png`)

#### A. Issue 1: Combat Taint & Action Blockage
- **Observed Behavior**: During combat or upon state transitions in combat, Blizzard displays: `the game refused Roth_UIActionBarBackground:Show() (DiabolusUnits, blocked)`. In previous tests before swapping belt positions, combat also caused the Potion Belt (`Roth_UIBelt`) to anchor to the screen bottom or fail to reposition.
- **Underlying Mechanism & Root Cause**:
  - `Roth_UIPlayerFrame` is an `oUF` unit frame constructed with `CreateFrame("Button", "Roth_UIPlayerFrame", UIParent, "SecureUnitButtonTemplate")`.
  - In `units/player.lua`, the decorative background and statue frames were instantiated as children of `Roth_UIPlayerFrame`:
    - `Roth_UIActionBarBackground`: `CreateFrame("Frame", "Roth_UIActionBarBackground", self)`
    - `Roth_UIAngelFrame`: `CreateFrame("Frame", "Roth_UIAngelFrame", self)`
    - `Roth_UIDemonFrame`: `CreateFrame("Frame", "Roth_UIDemonFrame", self)`
    - `Roth_UIBottomLine`: `CreateFrame("Frame", "Roth_UIBottomLine", self)`
  - Under Blizzard's secure template system, any frame whose parent hierarchy traces up to a `SecureUnitButtonTemplate` is treated as part of the secure button's execution subtree.
  - Calling `:Show()`, `:Hide()`, `:SetPoint()`, or altering attributes on any node within a secure subtree during `InCombatLockdown()` triggers an execution taint violation, resulting in Blizzard raising `ADDON_ACTION_BLOCKED`.
  - When `setupBarTexture()` ran in response to combat events or vehicle transitions, calling `f:Show()` on `Roth_UIActionBarBackground` directly triggered the execution block.
- **Implemented Fix in Working Tree (`units/player.lua`)**:
  1. Decoupled all decorative art frames from `self` by reparenting directly to `UIParent`:
     - `CreateFrame("Frame", "Roth_UIActionBarBackground", UIParent)`
     - `CreateFrame("Frame", "Roth_UIAngelFrame", UIParent)`
     - `CreateFrame("Frame", "Roth_UIDemonFrame", UIParent)`
     - `CreateFrame("Frame", "Roth_UIBottomLine", UIParent)`
  2. Added an explicit lockdown guard at the head of `setupBarTexture()`:
     ```lua
     if InCombatLockdown() then
         return
     end
     ```

#### B. Issue 2: Pet Action Bar Unanchoring on Action Bar Activation
- **Observed Behavior**: In `Screenshot 2026-10-17 at 12.31.17.png`, after activating additional action bar rows in Interface Options, the Pet Action Bar (`PetActionBarFrame` / `PetActionBar`) detached from the stone action bar and reverted to Blizzard's default position (bottom-left of screen, hovering above the chat frame). It remained detached until the user performed a `/reload`.
- **Underlying Mechanisms & Root Causes**:
  1. **Classic Positioning Engine vs. Modern Edit Mode**:
     - WoW Forever (`_classic_beta_`, Interface `11508`) uses a hybrid engine: the client supports modern Lua APIs, but action bar management and pet bar layout still rely on Classic's `UIParent_ManageFramePositions()`.
     - When action bar rows are toggled via Interface Options (e.g. enabling `MultiBarBottomLeft` or `MultiBarBottomRight`), Blizzard's options callback does not invoke EditMode's `ApplySystemAnchor` on `PetActionBarFrame`. Instead, it executes `UIParent_ManageFramePositions()`, which calls `petBar:ClearAllPoints()` and `petBar:SetPoint()` directly to place the pet bar in its hardcoded default screen coordinates.
     - Because `core/standardmode.lua` previously only hooked `petBar.ApplySystemAnchor`, Blizzard's positioning pass executed undetected and uncorrected.
  2. **Stale Closure Reference in `SetupPetBar`**:
     - `SetupPetBar(isPad, topRowFirstBtn)` previously took `topRowFirstBtn` as an input parameter and captured it inside an anonymous closure attached to `ApplySystemAnchor`.
     - Because the hook was guarded by `if not anchorHooked[petBar]`, it executed only once during addon initialization, capturing `ActionButton1`.
     - When the player enabled Bar 2 (`MultiBarBottomLeft`) or Bar 3 (`MultiBarBottomRight`), the closure still referenced `ActionButton1` and never updated to the newly active upper row.
  3. **Layout Pass Race Condition on Action Bar Show/Hide**:
     - Hooking `MultiBarBottomLeft:HookScript("OnShow", ...)` and `OnHide` triggered `StandardMode:Apply()` synchronously at the exact moment the bar began showing.
     - Blizzard's internal layout sequence executes `UIParent_ManageFramePositions()` *after* the `OnShow` script handler returns.
     - As a result, `StandardMode:Apply()` placed the pet bar, and milliseconds later Blizzard's engine cleared all points and placed the pet bar at the bottom-left above chat.
  4. **Combat Lockdown and Protected Frame Integrity**:
     - `PetActionBar` is a protected Blizzard frame containing 10 pet action buttons (`PetActionButton1..10`).
     - Modifying anchors or calling `ClearAllPoints()` / `SetPoint()` on `PetActionBar` during `InCombatLockdown()` produces taint and `ADDON_ACTION_BLOCKED`.
     - Re-anchoring logic must strictly verify `InCombatLockdown()`: if in combat, defer repositioning via `pendingApply = true` and execute immediately upon `PLAYER_REGEN_ENABLED`.

#### C. Architectural Solution Specification
- **1. Dynamic Upper Row Detection (`StandardMode:GetTopRowFirstButton()`)**:
  - Dynamically inspects frame visibility at runtime rather than storing static button references:
    ```lua
    function StandardMode:GetTopRowFirstButton()
        local mbLeft = _G.MultiBarBottomLeft
        local mbRight = _G.MultiBarBottomRight
        if mbLeft and mbLeft:IsShown() then
            if mbRight and mbRight:IsShown() then
                return _G.MultiBarBottomRightButton1 or _G.MultiBarBottomLeftButton1 or _G.ActionButton1
            end
            return _G.MultiBarBottomLeftButton1 or _G.ActionButton1
        elseif mbRight and mbRight:IsShown() then
            return _G.MultiBarBottomRightButton1 or _G.ActionButton1
        end
        return _G.ActionButton1
    end
    ```
- **2. Re-entrancy-Guarded Re-anchoring (`StandardMode:AnchorPetBar()`)**:
  - Protects against recursion using a local boolean `inPetAnchor`:
    ```lua
    local inPetAnchor = false
    function StandardMode:AnchorPetBar()
        if inPetAnchor then return end
        if self:IsGamepad() then return end
        local sm = cfg.standardMode
        if not (sm and sm.integratePetBar) then return end
        if InCombatLockdown() then
            pendingApply = true
            return
        end
        local petBar = _G.PetActionBar or _G.PetActionBarFrame
        if not petBar then return end
        local topBtn = self:GetTopRowFirstButton()
        if not topBtn then return end

        inPetAnchor = true
        HideDividerPools(petBar)
        if petBar.BorderArt then petBar.BorderArt:SetAlpha(0) end
        for i = 1, (rawget(_G, "NUM_PET_ACTION_SLOTS") or 10) do
            local pb = _G["PetActionButton" .. i]
            if pb then StyleActionButtonForStoneSlot(pb) end
        end
        local scale = 0.85
        Blizz.SetScale(petBar, scale)
        Blizz.ClearAllPoints(petBar)
        Blizz.SetPoint(petBar, "BOTTOMLEFT", topBtn, "TOPLEFT", 0, 6)
        inPetAnchor = false
    end
    ```
- **3. Hooking Blizzard's Internal SetPoint (`hooksecurefunc`)**:
  - Hooks `petBar:SetPoint` directly so that whenever Blizzard's `UIParent_ManageFramePositions()` moves `PetActionBar`, DiabolusUnits' secure hook catches it and snaps it back to `topBtn`:
    ```lua
    local function HookPetBar(petBar)
        if not petBar or anchorHooked[petBar] then return end
        anchorHooked[petBar] = true
        hooksecurefunc(petBar, "SetPoint", function()
            if not inPetAnchor and not StandardMode:IsGamepad() and not InCombatLockdown() then
                StandardMode:AnchorPetBar()
            end
        end)
        if petBar.ApplySystemAnchor then
            hooksecurefunc(petBar, "ApplySystemAnchor", function()
                if not inPetAnchor and not StandardMode:IsGamepad() and not InCombatLockdown() then
                    StandardMode:AnchorPetBar()
                end
            end)
        end
    end
    ```
  - Safe against infinite recursion: when `AnchorPetBar()` calls `Blizz.SetPoint`, `inPetAnchor` is `true`, causing the hook to return immediately.
  - Safe against taint: `hooksecurefunc` does not overwrite the Blizzard method pointer; it merely appends an unprivileged post-hook.
- **4. Debounced Timer Dispatch**:
  - Toggling action bars in settings or closing the settings dialog triggers deferred layout passes via `C_Timer.After(0.02, ...)` and `C_Timer.After(0.1, ...)`.
  - This guarantees that Blizzard's multi-pass layout engine finishes all internal calculations before DiabolusUnits computes and applies stone slot geometry and pet bar anchors.
- **5. Event Lifecycle Coverage**:
  - Registers `PET_BAR_UPDATE`, `PET_BAR_UPDATE_USABLE`, `UNIT_PET`, `ACTIONBAR_PAGE_CHANGED`, `UPDATE_BONUS_ACTIONBAR`, and `UPDATE_MULTI_CAST_ACTIONBAR`.
  - All event handlers route through `InCombatLockdown()` check: if in combat, flag `pendingApply = true`; if out of combat, run `DelayedApply()`.



---

### 10. Embedded oUF Upgrade: 1.6.8 → 14.2.0 (uncommitted, branch `claude/anchors-settings-belt`)

Replaced the WoD-era embedded oUF (Gemini-patched 1.6.8) with upstream **oUF 14.2.0** (`/Users/erik2/Downloads/oUF`), which targets WoW Forever directly (`Interface: 16001`, `AllowLoadGameType: standard, camelot`). Done as a direct refactor of DiabolusUnits — no compatibility shims or alias tables. All new APIs were checked against the Forever UI source snapshot (`SetRolesets`, `C_Secrets.CanCompareUnitTokens`, `CreateUnitHealPredictionCalculator`, `Enum.StatusBarInterpolation`, `CustomAuraContainerTemplate`, `SetVertexColorFromBoolean` / `EvaluateColorValueFromBoolean`).

#### A. The embed
- `embeds/oUF/` is upstream 14.2.0 verbatim (same `oUF.xml` entry point in the TOC), with **one local patch** in `elements/castbar.lua`, marked `DiabolusUnits local patch`: upstream hides `PlayerCastingBarFrame` / `PetCastingBarFrame` with `:Hide()`, which on Forever is the Edit Mode Lua override (taint source, see `core/blizzsafe.lua`); the patch uses `ns.Blizz.Conceal` instead.
- Blizzard unit frames are now suppressed by upstream's C-level `frame:SetRolesets('alwaysBlocked')` instead of the old Lua hide/reparent.
- `CREDITS.md` updated (version, authors, `LICENSE.txt`, the local patch).

#### B. Breaking API changes handled
- **`frame.unit` → `frame.__unit`**: oUF 14 no longer sets `.unit`. Rewritten in `core/` (lib, buffcoverage, status, privateauras, panel), `units/` (target, group, player) and every module. `core/castbars.lua` reads `__unit`, falling back to `.unit` only for Roth's own nameplates (not oUF frames).
- **Unitless events must pass `true`** (`self:RegisterEvent(event, fn, true)`), otherwise oUF 14 asserts: target `PLAYER_TARGET_CHANGED` / `PLAYER_REGEN_ENABLED`, ComboPoints `UPDATE_SHAPESHIFT_FORM`, Experience `PLAYER_LEVEL_UP` / `UPDATE_EXHAUSTION` (payloads checked in the API docs). Experience tags also gained `oUF.Tags.SharedEvents.UPDATE_EXHAUSTION`.
- **Renamed elements** (renamed in place across `units/`):
  - `RaidIcon` → `RaidTargetIndicator` (target, tot, focus, focustarget, pet, pettarget, boss, group)
  - `ReadyCheck` → `ReadyCheckIndicator`; `Resting` / `Combat` / `PvP` → `RestingIndicator` / `CombatIndicator` / `PvPIndicator`
  - `LFDRole` → `GroupRoleIndicator`, with an `Override` (Forever's `UnitFrameUtil` path would replace Roth's `lfd_role` art)
  - `Leader` → `LeaderIndicator`, with a `PostUpdate` that restores the crown (oUF sets an atlas)
  - `DruidMana` → `AdditionalPower` (`colorPower = true`); `AltPowerBar` → `AlternativePower` (frame names `Roth_DruidMana`, `oUF_AltPower*` kept for saved positions)
- **Colours**: `oUF.colors` holds `ColorMixin` objects; `config.lua` now sets `oUF.colors.power.MANA = oUF:CreateColor(0, 0.4, 1)` and the index-0 alias.
- **Callback signatures**: Power `PostUpdate(unit, cur, min, max)` — the player power orb wraps `updateValue`. Castbar: `PostChannelStart` is gone (`PostCastStart` covers channels), `PostCastFailed` → `PostCastFail`, `notInterruptible` is a (possibly secret) callback argument instead of `element.notInterruptible`.
- **Dead options removed**: `Health.frequentUpdates` (UNIT_HEALTH is always frequent in 14), `.Smooth`, `desaturateDebuffs` (config), `func.postUpdateDebuff`.

#### C. Feature migrations
- **RareIcon** (target_boss horns / target_elite crest): moved from `embeds/oUF/elements/rare.lua` to `modules/oUF_RareIcon.lua` (registered in the TOC), same behaviour, `__unit`-based.
- **Auras**: oUF 14 has no Lua aura rows any more. Every row (target, focus, pet, targettarget, focustarget, pettarget, party/raid) is now an oUF `frame:CreateAuras()` element (client `CustomAuraContainerTemplate`) built by `core/nativeauras.lua` (`NativeAuras.Create(frame, key, holder, opts)`):
  - a plain holder frame keeps each row's old position/size; the container sits in its `initialAnchor` corner and wraps at its width;
  - Diablo skin (black glow, gloss rim, stack count, dispel-type border, stealable glow) is applied once in `initializeFrame`; the client draws countdown numbers;
  - oUF drives `SetUnit` on every full update, so the private target/focus/pet refresh frame is gone;
  - the group blacklist is now the client's `candidateFilters.excludeSpellIDs`, so it holds in combat as well;
  - `NativeAuras.SetFlow` / `.Count` / `.SetSize` and `ns.AuraSize` keep the target layout options, `/roth auras` probe and Edit-layout icon size working.
- **Heal prediction & absorbs**: `core/healbars.lua` now provides oUF Health sub-widgets (`HealingAll`, `HealingPlayer`, `DamageAbsorb`, `HealAbsorb`) fed by the client heal prediction calculator; its own events, `Update` and resize hook are gone (oUF sizes the bars). Look and clip frame unchanged; `cfg.healbars` toggles still decide which widgets exist.
- **Smoothing**: `modules/oUF_Smooth.lua` (Lua `OnUpdate` interpolation) deleted; Health/Power bars use `.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut`. The player orbs stay immediate (scroll-frame sync).
- **Castbar**: spark is now anchored by `func.createCastbar` (oUF 14 no longer moves it). The target's "cannot be interrupted" colouring uses `C_CurveUtil.EvaluateColorValueFromBoolean`, never testing the secret flag. `core/castbars.lua` channel ticks and interrupt-ready glow chain the new callback names; Roth nameplates call `PostCastStart` for channels too.
- **ComboFrame**: upstream no longer hides Blizzard's `ComboFrame` (parented to UIParent on Forever); `units/target.lua` conceals it after spawning the target frame.

#### D. Verification
- `wowdev check DiabolusUnits --lint`: Lua 5.1 syntax 61/61 files OK, manifest 179 load files / 0 issues, luacheck **0 errors**. 335 warnings, all pre-existing (baseline taken from the pre-upgrade tree); none added, 4 gone with `oUF_Smooth`. `.luacheckrc` gained `ComboFrame` and `GetTexCoordsForRoleSmallCircle`.
- All `embeds/oUF` files compile with the Lua 5.1 `luac`.
- StyLua applied to touched files that were StyLua-clean before; `core/castbars.lua`, `core/panel.lua`, `core/tags.lua`, `core/buffcoverage.lua` were already non-conforming (hand-laid spell tables etc.) and were left unformatted.
- Pre-upgrade working-tree diff backed up in the session scratchpad (`pre-ouf14-worktree.patch`).

#### E. Open — needs in-client testing
1. `/console taintLog 2`, `/reload` out of combat: no Lua errors at login.
2. Target fight: auras stay visible in combat, castbar spark and grey "shield" colouring, RareIcon art for elite / rare / boss.
3. Party: upstream 14.2 now suppresses `PartyFrame` and `CompactPartyFrameMember*` (the old embed deliberately left party alone) — watch `taint.log` for party / Edit Mode entries.
4. Heal / absorb bars on target, focus and group frames; druid `AdditionalPower` while shapeshifted; group role icons and leader crown.

---

## Side session — PulseSensation2 & ControllerApex (2026-10-15/16)

Not DiabolusUnits work; logged here so the notes stay in one place.

### A. PulseSensation2 (`WoW/PulseSensation2`, branch `main`) — uncommitted
- **Quick Setup test buttons** (`PulseHaptics/UI/QuickSetup.lua`): several buttons played modes that don't exist. Renamed `HEAVY_STRIKE` → `HEAVY` / `IMPACT`, `DOUBLE_THUD` → `THUD`, `PULSE_BURST` → `DOUBLE_TAP`, `LEVEL_UP` → `SURGE`. New `testMode()` / `reportTest()` helpers print why a test failed. Feel Strength no longer applies the strength twice.
- **Role / class cues**: `critLanded`, `healCrit` and `healReceived` are incoming events, so they moved to the tank/healer side. New `ROLE_CUES` (tank, healer, melee, ranged) and `CLASS_CUES` (Hunter auto shot, Rogue/Druid combo points, Druid forms). `applyClassAndRole()` resets managed cues that aren't selected to their registry defaults.
- **Game menu entry**: reviewed GitHub commit `345f42b` (GameMenu.lua). It uses SmartNavigation fields that don't exist (`currentTarget`; the real one is `currentButton`), the wrong ignore flag (`smartNavigationIgnored` is the real one), and the watcher lacks `EnableGamePadButton(true)`. Compared ControllerForever (button over the menu, binds Y while open) and EasyController (never opens over the menu).
- **`PulseHaptics/UI/GameMenu2.lua`**: a test version with no SmartNavigation. It binds X to the banner button while the game menu is open and out of combat, re-checks every 0.2 s and on `Gamepad.RefreshFrameFocus`, and clears on hide and when combat starts. Switch versions with `/pulse gamemenu v1|over|after|close` (saved in `PulseDB.gameMenuVariant`; switching to or from v1 needs `/reload`). Also touched: TOC, `Core/Init.lua`, `UI/Panel/Panel.lua`, `.luacheckrc`.
- **Open**: in-game test of the GameMenu2 versions decides the game-menu design for PulseHaptics and ControllerApex. `navigation-test` still fails on the old GameMenu.lua design (pre-existing).

### B. ControllerApex redesign (now `WoW/_reference/ControllerApex`, branch `redesign`)
Six committed stages, version 2.1.0. Headless tests, luacheck, stylua and the BLP check pass; **never run in the client**.

| Stage | Commit | Change |
|---|---|---|
| 0 | `3dc459a` | Features that duplicate Forever's own controller UI moved to `_parked/`; soft targeting kept as its own module |
| 1 | `4134454` | `Input/Binds.lua` follows the game's binding stack, so open windows keep their keys; one Remapping module (paddles, L3/R3, trigger taps, off by default); `/apex probe` |
| 2 | `43a78f3` | Viking art kit (`tools/make_viking_art.py` → `Media/Viking/*.tga`), `UI/Theme.lua`, round dock slots, one HUD root |
| 3 | `7ecf2a8` | `UI/SettingsSpec.lua` drives the 8-page settings window and the wizard |
| 4 | `618ebfe` | Viking rings (disc, hub, pointer, medallions) |
| 5 | `02a9e02` | Viking keyboard and bag markers; `tests/run_tests_static.lua` blocks forbidden calls and stray binding owners; README |

Platform facts found along the way (also in auto-memory): Forever's gamepad binding stack uses `SetOverrideBinding(UIParent, true, …)` and the newest set wins; restricted code in combat can't see non-protected windows; clicking the ADDON_ACTION_FORBIDDEN popup in gamepad mode can loop into a 20 s freeze.

Open: in-game checks (`TESTING.md` 0–0e, `/apex probe` with bags, loot, a popup and the game menu open), the game-menu entry, and merging the 22 OnUpdate handlers into one ticker. The folder has since moved to `_reference/` and the wow-forever-dev skill now lists ControllerApex as retired reference material.
