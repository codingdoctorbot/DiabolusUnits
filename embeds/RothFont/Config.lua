local addonName, Roth_UI = ...

-- Font defaults are shared by the existing font application and settings window.
local profileDefaults = {
  headerFont = "Expressway",
  headerScale = 1.0,
  textFont = "Expressway",
  textScale = 1.0,
  chatFont = "Expressway",
  chatScale = 1.0,
}

Roth_UI:AddConfig("fonts", nil, profileDefaults)
