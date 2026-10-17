# DiabolusUnits

**DiabolusUnits** is a focused World of Warcraft (`_classic_beta_` / WoW Forever) unit frame, artwork, and status bar addon extracted from Roth UI (oUF_Diablo).

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
  - Full mouse-driven Edit Mode (`/roth edit`, `/diabolus edit`, or Blizzard's Edit Mode) with per-element popup dialog for scale, X/Y offset, spacing/aura icon size, and enable/disable toggles.

## Slash Commands
- `/roth edit` or `/diabolus edit` — Toggle Edit Mode (drag frames, click any frame for its settings popup)
- `/roth lockall` — Finish editing and lock frames
- `/roth resetall` — Reset all frames to default positions and scales
- `/roth config` — Open the Orb Configuration panel (colors, 3D models, fillings, tags)
- `/roth scale <50-150>` — Set global UI scale for all DiabolusUnits frames
- `/roth autoscale [on|off]` — Toggle pixel-perfect (`768 / physicalHeight`) UI scaling
- `/roth auras` — Inspect target aura API output
- `/roth taint` — List refused actions and taint diagnostics
