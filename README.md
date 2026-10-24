# Diabolus Forever

**Diabolus Forever** (`DiabolusForever`) is a focused World of Warcraft (`_classic_beta_` / WoW Forever) unit frame, artwork, and status bar addon extracted and modernized from Roth UI (oUF_Diablo).

## Included Features
- **Unit Frames (`units/`)**:
  - **Player Health & Power Orbs**: Classic Diablo orbs with animated models, bubbles, galaxies, spark, 5-second rule indicator, power cost preview, and shield crescent.
  - **Target & Target of Target**: Ornate Diablo frames with secret-safe native/oUF auras and elite/rare/boss skull headers.
  - **Focus & Focus Target**: Full unit frames with aura tracking.
  - **Pet & Pet Target**: Unit frames with Pet Happiness indicator.
  - **Party & Raid Frames**: Diablo party bars and 40-player raid tiles/bars with incoming heal prediction, absorb shields, dispellable debuff glows, private auras, and missing class buff coverage.
  - **Boss Frames**: Up to 5 boss frames (`boss1`..`boss5`).
  - **Diablo Nameplates**: Custom iron bar nameplates with castbars, threat glow, elite/boss heads, and player debuffs.
- **Diablo Art (`units/player.lua`)**:
  - Angel & Demon statues, bottom stone line, and optional action bar stone background.
- **Status & Class Bars (`core/bars.lua`, `modules/`)**:
  - Experience & Rested bar, Reputation bar (dynamically stretched between orbs by default), Combo Points, Druid Mana, Soul Shards, Holy Power, Runes, Totems, and Alt Power.
- **Castbars & Swing Timer (`core/castbars.lua`, `core/swingtimer.lua`)**:
  - Player, Target, and Focus castbars with latency safezone, interruptible shield art, and a Diablo melee/ranged swing timer.
- **Diablo Tooltips (`embeds/rTooltip/`)**:
  - Custom Diablo-bordered tooltips with item quality dressing and unit class/reaction coloring.
- **Interactive Edit Mode (`core/editmode.lua`)**:
  - Full mouse-driven Edit Mode (`/diabolus edit`, `/dforever edit`, or Blizzard's Edit Mode) with per-element popup dialog for scale, X/Y offset, spacing/aura icon size, and enable/disable toggles.

## Slash Commands
- `/diabolus edit` or `/dforever edit` — Toggle Edit Mode (drag frames, click any frame for its settings popup)
- `/diabolus lockall` — Finish editing and lock frames
- `/diabolus resetall` — Reset all frames to default positions and scales
- `/diabolus` or `/dforever` — Open the Settings and Orb Configuration panel
- `/diabolus scale <50-150>` — Set global UI scale for all DiabolusForever frames
- `/diabolus autoscale [on|off]` — Toggle pixel-perfect (`768 / physicalHeight`) UI scaling
- `/diabolus auras` — Inspect target aura API output
- `/diabolus taint` — List refused actions and taint diagnostics
