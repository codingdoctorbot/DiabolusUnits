-- Optional per-character cfg overrides; the legacy Loral example remains below.

  local addon, ns = ...

  local cfg = ns.cfg
  if cfg.playername == "Loral" and cfg.playerclass == "DRUID" then
    cfg.units.focus.auras.showBuffs = false
    cfg.units.target.healprediction.show = true
    cfg.units.focus.healprediction.show = true
  end

  --