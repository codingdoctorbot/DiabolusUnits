  local addon, ns = ...

  local unit = CreateFrame("Frame")
  unit:Hide()

  -- UNITS

  --just in case needed

  -- HANDOVER

  --object container to addon namespace
  ns.unit = unit

  
-- Supplement oUF's polling for nested targets without changing its timers or unit watch.
function unit.WatchTargetChanges(frame, baseUnit)
  if not frame or frame.diabolusTargetWatcher then return end
  local parentEvent = baseUnit == "target" and "PLAYER_TARGET_CHANGED" or "PLAYER_FOCUS_CHANGED"
  local watcher = CreateFrame("Frame", nil, frame)
  watcher:RegisterUnitEvent("UNIT_TARGET", baseUnit)
  watcher:RegisterEvent(parentEvent)
  watcher:SetScript("OnEvent", function(_, event)
    if frame:IsVisible() then frame:UpdateAllElements(event) end
  end)
  frame.diabolusTargetWatcher = watcher
end
