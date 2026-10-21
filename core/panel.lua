-- Legacy orb panel and helpers retained by settings/Spec.lua.
-- The new settings window uses its save/load/update and preview functions.

  local addon, ns = ...
  local oUF = ns.oUF

  local db = ns.db

  local unpack = unpack
  local gsub = gsub
  local tinsert = tinsert
  local wipe = wipe
  local floor = floor
  local strmatch = strmatch
  local strlen = strlen
  local CF = CreateFrame
  local CPF = ColorPickerFrame
  local theEnd  = function() end

  local panel = CF("Frame",addon.."ConfigPanel",UIParent,"ButtonFrameTemplate")
  panel:SetFrameStrata("HIGH")
  panel:Hide()
  ns.panel = panel

  --PANEL SETUP FUNCTIONS

  --setup panel
  do
    panel:SetSize(600,600)
    panel:SetPoint("CENTER")
    panel.title = _G[addon.."ConfigPanelTitleText"]
    panel.title:SetText(addon.." - Orb config panel")
    local icon = panel:CreateTexture("$parentIcon", "OVERLAY", nil, -8)
    icon:SetSize(60,60)
    icon:SetPoint("TOPLEFT",-5,7)
    icon:SetTexture("Interface\\FriendsFrame\\Battlenet-Portrait")
    icon:SetTexCoord(0,1,0,1)
    panel.icon = icon
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:SetUserPlaced(true)
  end

  local createPanelDragFrame = function()
    local frame = CF("Frame", "$parentDragFrame", panel)
    frame:SetHeight(22)
    frame:SetPoint("TOPLEFT",60,0)
    frame:SetPoint("TOPRIGHT",-30,0)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
      if InCombatLockdown() then return end
      self:GetParent():StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
      if InCombatLockdown() then return end
      self:GetParent():StopMovingOrSizing()
    end)
    frame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Drag me!", 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return frame
  end

  local createPanelScrollFrame = function()
    local scrollFrame = CF("ScrollFrame", "$parentScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",10,-65)
    scrollFrame:SetPoint("BOTTOMRIGHT",-37,30)
    --add scrollbar background textures
    local t = scrollFrame:CreateTexture(nil,"BACKGROUND",nil,-6)
    t:SetPoint("TOP",scrollFrame)
    t:SetPoint("RIGHT",scrollFrame,25.5,0)
    t:SetPoint("BOTTOM",scrollFrame)
    t:SetWidth(26)
    t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    t:SetTexCoord(0,0.45,0.1640625,1)
    t:SetAlpha(0.5)
    local t2 = scrollFrame:CreateTexture(nil,"BACKGROUND",nil,-8)
    t2:SetColorTexture(1,1,1)
    t2:SetVertexColor(0,0,0,0.3)
    t2:SetAllPoints(t)
    local scrollChild = CF("Frame",nil,scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    --set scrollchild height
    scrollChild:SetHeight(1020)
    --left background behind health orb settings
    local t = scrollChild:CreateTexture(nil,"BACKGROUND",nil,-4)
    t:SetColorTexture(1,1,1)
    t:SetVertexColor(1,0,0)
    t:SetAlpha(0.1)
    t:SetPoint("TOPLEFT")
    t:SetPoint("BOTTOMLEFT")
    t:SetWidth(scrollFrame:GetWidth()/2-2)
    scrollChild.leftTexture = t
    --right background behind power settings
    local t = scrollChild:CreateTexture(nil,"BACKGROUND",nil,-4)
    t:SetColorTexture(1,1,1)
    t:SetVertexColor(0,0,1)
    t:SetAlpha(0.1)
    t:SetPoint("TOPRIGHT")
    t:SetPoint("BOTTOMRIGHT")
    t:SetWidth(scrollFrame:GetWidth()/2-2)
    scrollChild.rightTexture = t
    --set scrollchild
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame.scrollChild = scrollChild
    return scrollFrame
  end
  --panel drag frame
  panel.dragFrame = createPanelDragFrame()
  --the scroll frame
  panel.scrollFrame = createPanelScrollFrame()

  --CREATE UI PANEL ELEMENT FUNCTIONS

  --basic fontstring func
  local createBasicFontString = function(parent, name, layer, template, text)
    local fs = parent:CreateFontString(name,layer,template)
    fs:SetText(text)
    return fs
  end

  local createHeadlineBackground = function(parent,headline)
    local t = parent:CreateTexture(nil,"BACKGROUND",nil,-2)
    t:SetColorTexture(1,1,1)
    t:SetVertexColor(255,255,255,0.05)
    t:SetPoint("TOP",headline,0,4)
    t:SetPoint("LEFT",headline,-20,0)
    t:SetWidth(275)
    t:SetPoint("BOTTOM",headline,0,-4)
    t:SetBlendMode("ADD")
  end

  local createTooltipButton = function(parent,pointParent,text)
    local button = CF("Button", nil, parent)
    button:SetAllPoints(pointParent)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(text, 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
  end

  local backdrop = {
    bgFile = "",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  }

  --basic button func
  local createBasicButton = function(parent, name, text,adjustWidth, adjustHeight)
    local button = CF("Button", name.."Button", parent, "UIPanelButtonTemplate")
    button.text = _G[button:GetName().."Text"]
    button.text:SetText(text)
    button:SetWidth(button.text:GetStringWidth()+(adjustWidth or 20))
    button:SetHeight(button.text:GetStringHeight()+(adjustHeight or 12))
    return button
  end

  --basic slider func
  local createBasicSlider = function(parent, name, title, minVal, maxVal, valStep)
    local slider = CF("Slider", name, parent, "OptionsSliderTemplate")
    local editbox = CF("EditBox", "$parentEditBox", slider, "InputBoxTemplate")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(valStep)
    slider.text = _G[name.."Text"]
    slider.text:SetText(title)
    slider.textLow = _G[name.."Low"]
    slider.textHigh = _G[name.."High"]
    slider.textLow:SetText(floor(minVal))
    slider.textHigh:SetText(floor(maxVal))
    slider.textLow:SetTextColor(0.4,0.4,0.4)
    slider.textHigh:SetTextColor(0.4,0.4,0.4)
    editbox:SetSize(50,30)
    editbox:ClearAllPoints()
    editbox:SetPoint("LEFT", slider, "RIGHT", 15, 0)
    editbox:SetText(slider:GetValue())
    editbox:SetAutoFocus(false)
    slider:SetScript("OnValueChanged", function(self,value)
      self.editbox:SetText(ns.func.round(value))
    end)
    editbox:SetScript("OnTextChanged", function(self)
      local val = self:GetText()
      if tonumber(val) then
         self:GetParent():SetValue(val)
      end
    end)
    editbox:SetScript("OnEnterPressed", function(self)
      local val = self:GetText()
      if tonumber(val) then
         self:GetParent():SetValue(val)
         self:ClearFocus()
      end
    end)
    slider.editbox = editbox
    return slider
  end

  --basic checkbutton func
  local createBasicCheckButton = function(parent, name, title)
    local button = CF("CheckButton", name, parent, "UICheckButtonTemplate")
    button:SetSize(20,20)
    button.text = button:CreateFontString(name.."Text", "ARTWORK", "GameFontNormal")
    button.text:SetPoint("LEFT", button, "RIGHT", 5, 1)
    button.text:SetText(title)
    button.text:SetTextColor(1,1,1)
    return button
  end

  --basic color picker func
  local createBasicColorPicker = function(parent, name, title, width, height)
    local picker = CF("Button", name, parent)
    picker:SetSize(width, height)
    local color = picker:CreateTexture(nil,"BACKGROUND",nil,-7)
    color:SetPoint("TOPLEFT",4,-4)
    color:SetPoint("BOTTOMRIGHT",-4,4)
    color:SetColorTexture(1,1,1)
    picker.color = color
    picker.text = createBasicFontString(picker,nil,nil,"GameFontNormal",title)
    picker.text:SetTextColor(1,1,1)
    picker.text:SetPoint("LEFT", picker, "RIGHT", 5, 0)
    picker.disabled = false
    --add a Disable() function to the colorpicker element
    function picker:Disable()
      self.disabled = true
      self.color:SetAlpha(0)
      self.text:SetTextColor(0.5,0.5,0.5)
    end
    --add a Enable() function to the colorpicker element
    function picker:Enable()
      self.disabled = false
      self.color:SetAlpha(1)
      self.text:SetTextColor(1,1,1)
    end
    picker.show = function(r,g,b,a,callback)
      CPF:SetColorRGB(r,g,b)
      CPF.hasOpacity, ColorPickerFrame.opacity = (a ~= nil), a
      CPF.previousValues = {r,g,b,a}
      CPF.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = callback, callback, callback
      CPF:Hide() -- Need to run the OnShow handler.
      CPF:Show()
    end
    picker.callback = function(color)
      if picker.disabled then return end
      local r,g,b
      if color then r,g,b = unpack(color) else r,g,b = ColorPickerFrame:GetColorRGB() end
      picker.color:SetVertexColor(r,g,b)
      picker.click(r,g,b)
    end
    picker:SetScript("OnClick", function(self)
      if self.disabled then return end
      -- Clear the stale colour-picker callback before reusing it.
      CPF.func, CPF.opacityFunc, CPF.cancelFunc = theEnd, theEnd, theEnd
      local r,g,b = self.color:GetVertexColor()
      self.show(r,g,b,nil,self.callback)
    end)
    return picker
  end

  -- Legacy Menu-based dropdown helper; avoids UIDropDownMenu shared-global writes.
  -- Callers use click/value, SetSelectedValue, and ToggleMenu.
  local createBasicDropDownMenu = function(parent, name, title, dataFunc, width, displayMode, dynamicList, headline)
    local dropdownMenu = CF("DropdownButton", name, parent, "WowStyle1DropdownTemplate")

    if headline then
      dropdownMenu.headline = createBasicFontString(dropdownMenu,nil,nil,"GameFontNormal",headline)
      dropdownMenu.headline:SetPoint("BOTTOMLEFT", dropdownMenu, "TOPLEFT", 20, 5)
    end

    if width then dropdownMenu:SetWidth(width) end
    dropdownMenu:SetDefaultText(title)

    local function IsSelected(value)
      return dropdownMenu.selectedValue == value
    end
    local function Select(value)
      if dropdownMenu.click then
        dropdownMenu.click({ value = value })
      end
    end
    local function Load()
      if dynamicList or not dropdownMenu.data then
        dropdownMenu.data = dataFunc() or {}
      end
      return dropdownMenu.data
    end
    local function AddEntry(root, data)
      if data.isTitle or data.notClickable then
        root:CreateTitle(data.key)
      elseif data.hasArrow and data.menuList then
        local sub = root:CreateButton(data.key)
        for _, data2 in pairs(data.menuList) do
          AddEntry(sub, data2)
        end
      else
        root:CreateRadio(data.key, IsSelected, Select, data.value)
      end
    end

    dropdownMenu.rothGenerator = function(_, root)
      root:CreateTitle(title)
      local data = Load()
      if #data == 0 then
        root:CreateTitle("|cFFFF0000No data found|r")
      end
      for _, entry in pairs(data) do
        AddEntry(root, entry)
      end
    end
    dropdownMenu:SetupMenu(dropdownMenu.rothGenerator)
    return dropdownMenu
  end

  -- UIDropDownMenu_SetSelectedValue for the dropdowns above
  local SetSelectedValue = function(dropdownMenu, value)
    if not dropdownMenu then return end
    dropdownMenu.selectedValue = value
    if dropdownMenu.GenerateMenu then
      dropdownMenu:GenerateMenu()
    end
  end

  -- ToggleDropDownMenu(..., "cursor") for the template load / delete lists
  local ToggleMenu = function(dropdownMenu, owner)
    if MenuUtil and MenuUtil.CreateContextMenu then
      MenuUtil.CreateContextMenu(owner or dropdownMenu, dropdownMenu.rothGenerator)
    end
  end

  local createDropdownHealthOrbFillingTexture = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelHealthOrbFillingTexture", "Choose texture", db.getListFillingTexture, 196)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      panel.saveHealthOrbFillingTexture(self.value)
      panel.updateHealthOrbFillingTexture()
    end
    return dropdownMenu
  end

  local createDropdownPowerOrbFillingTexture = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelPowerOrbFillingTexture", "Choose texture", db.getListFillingTexture, 196)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      panel.savePowerOrbFillingTexture(self.value)
      panel.updatePowerOrbFillingTexture()
    end
    return dropdownMenu
  end

  local createCheckButtonHealthOrbFillingColorAuto = function(parent)
    local button = createBasicCheckButton(parent, addon.."PanelHealthOrbFillingColorAuto", "Automatic coloring (class/power)?")
    button:SetScript("OnClick", function(self,value)
      panel.saveHealthOrbFillingColorAuto(self:GetChecked())
      panel.updateHealthOrbFillingColorAuto()
      -- Refresh dependent controls when auto-colouring changes.
      panel.updateElementHealthOrbFillingColorAuto()
    end)
    return button
  end

  local createCheckButtonPowerOrbFillingColorAuto = function(parent)
    local button = createBasicCheckButton(parent, addon.."PanelPowerOrbFillingColorAuto", "Automatic coloring (class/power)?")
    button:SetScript("OnClick", function(self,value)
      panel.savePowerOrbFillingColorAuto(self:GetChecked())
      panel.updatePowerOrbFillingColorAuto()
      -- Refresh dependent controls when auto-colouring changes.
      panel.updateElementPowerOrbFillingColorAuto()
    end)
    return button
  end

  local createPickerHealthOrbFillingColor = function(parent)
    local picker = createBasicColorPicker(parent, addon.."PanelHealthOrbFillingColor", "Filling texture color", 75, 25)
    picker.click = function(r,g,b)
      panel.saveHealthOrbFillingColor(r,g,b)
      panel.updateHealthOrbFillingColor()
    end
    return picker
  end

  local createPickerPowerOrbFillingColor = function(parent)
    local picker = createBasicColorPicker(parent, addon.."PanelPowerOrbFillingColor", "Filling texture color", 75, 25)
    picker.click = function(r,g,b)
      panel.savePowerOrbFillingColor(r,g,b)
      panel.updatePowerOrbFillingColor()
    end
    return picker
  end

  local createCheckButtonHealthOrbModelEnable = function(parent)
    local button = createBasicCheckButton(parent, addon.."PanelHealthOrbModelEnable", "Enable")
    button:SetScript("OnClick", function(self,value)
      panel.saveHealthOrbModelEnable(self:GetChecked())
      panel.updateHealthOrbModelEnable()
      -- Refresh dependent control visibility.
      panel.updateElementHealthOrbModelEnable()
    end)
    return button
  end

  local createCheckButtonPowerOrbModelEnable = function(parent)
    local button = createBasicCheckButton(parent, addon.."PanelPowerOrbModelEnable", "Enable")
    button:SetScript("OnClick", function(self,value)
      panel.savePowerOrbModelEnable(self:GetChecked())
      panel.updatePowerOrbModelEnable()
      -- Refresh dependent control visibility.
      panel.updateElementPowerOrbModelEnable()
    end)
    return button
  end

  local createDropdownHealthOrbModelAnimation = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelHealthOrbModelAnimation", "Choose animation", db.getListModel, 196)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      panel.saveHealthOrbModelAnimation(self.value)
      panel.updateHealthOrbModelAnimation()
    end
    return dropdownMenu
  end

  local createDropdownPowerOrbModelAnimation = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelPowerOrbModelAnimation", "Choose animation", db.getListModel, 196)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      panel.savePowerOrbModelAnimation(self.value)
      panel.updatePowerOrbModelAnimation()
    end
    return dropdownMenu
  end

  local createSliderHealthOrbModelAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbModelAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbModelAlpha(value)
      panel.updateHealthOrbModelAlpha()
    end)
    return slider
  end

  local createSliderPowerOrbModelAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbModelAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbModelAlpha(value)
      panel.updatePowerOrbModelAlpha()
    end)
    return slider
  end

  local createSliderHealthOrbModelScale = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbModelScale", "Scale", 0.001, 6, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbModelScale(value)
      panel.updateHealthOrbModelScale()
    end)
    return slider
  end

  local createSliderPowerOrbModelScale = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbModelScale", "Scale", 0.001, 6, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbModelScale(value)
      panel.updatePowerOrbModelScale()
    end)
    return slider
  end

  local createSliderHealthOrbModelPosX = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbModelPosX", "X-Axis", -5, 5, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbModelPosX(value)
      panel.updateHealthOrbModelPosX()
    end)
    return slider
  end

  local createSliderPowerOrbModelPosX = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbModelPosX", "X-Axis", -5, 5, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbModelPosX(value)
      panel.updatePowerOrbModelPosX()
    end)
    return slider
  end

  local createSliderHealthOrbModelPosY = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbModelPosY", "Y-Axis", -5, 5, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbModelPosY(value)
      panel.updateHealthOrbModelPosY()
    end)
    return slider
  end

  local createSliderPowerOrbModelPosY = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbModelPosY", "Y-Axis", -5, 5, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbModelPosY(value)
      panel.updatePowerOrbModelPosY()
    end)
    return slider
  end

  local createSliderHealthOrbModelRotation = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbModelRotation", "Rotation", -4, 4, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbModelRotation(value)
      panel.updateHealthOrbModelRotation()
    end)
    return slider
  end

  local createSliderPowerOrbModelRotation = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbModelRotation", "Rotation", -4, 4, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbModelRotation(value)
      panel.updatePowerOrbModelRotation()
    end)
    return slider
  end

  local createSliderHealthOrbModelZoom = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbModelZoom", "Portrait-Zoom", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbModelZoom(value)
      panel.updateHealthOrbModelZoom()
    end)
    return slider
  end

  local createSliderPowerOrbModelZoom = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbModelZoom", "Portrait-Zoom", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbModelZoom(value)
      panel.updatePowerOrbModelZoom()
    end)
    return slider
  end

  local createSliderHealthOrbHighlightAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbHighlightAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbHighlightAlpha(value)
      panel.updateHealthOrbHighlightAlpha()
    end)
    return slider
  end

  local createSliderPowerOrbHighlightAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbHighlightAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbHighlightAlpha(value)
      panel.updatePowerOrbHighlightAlpha()
    end)
    return slider
  end

  local createSliderHealthOrbSparkAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbSparkAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbSparkAlpha(value)
      panel.updateHealthOrbSparkAlpha()
    end)
    return slider
  end

  local createSliderPowerOrbSparkAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbSparkAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbSparkAlpha(value)
      panel.updatePowerOrbSparkAlpha()
    end)
    return slider
  end
  
  local createSliderHealthOrbGalaxiesAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbGalaxiesAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbGalaxiesAlpha(value)
      panel.updateHealthOrbGalaxiesAlpha()
    end)
    return slider
  end

  local createSliderPowerOrbGalaxiesAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbGalaxiesAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbGalaxiesAlpha(value)
      panel.updatePowerOrbGalaxiesAlpha()
    end)
    return slider
  end
  
  local createSliderHealthOrbBubblesAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbBubblesAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbBubblesAlpha(value)
      panel.updateHealthOrbBubblesAlpha()
    end)
    return slider
  end

  local createSliderPowerOrbBubblesAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbBubblesAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbBubblesAlpha(value)
      panel.updatePowerOrbBubblesAlpha()
    end)
    return slider
  end
  
  local createCheckButtonHealthOrbValueHideEmpty = function(parent)
    local button = createBasicCheckButton(parent, addon.."PanelHealthOrbValueHideEmpty", "Hide on empty*")
    button:SetScript("OnClick", function(self,value)
      panel.saveHealthOrbValueHideEmpty(self:GetChecked())
    end)
    return button
  end

  local createCheckButtonPowerOrbValueHideEmpty = function(parent)
    local button = createBasicCheckButton(parent, addon.."PanelPowerOrbValueHideEmpty", "Hide on empty*")
    button:SetScript("OnClick", function(self,value)
      panel.savePowerOrbValueHideEmpty(self:GetChecked())
    end)
    return button
  end

  local createCheckButtonHealthOrbValueHideFull = function(parent)
    local button = createBasicCheckButton(parent, addon.."PanelHealthOrbValueHideFull", "Hide on full*")
    button:SetScript("OnClick", function(self,value)
      panel.saveHealthOrbValueHideFull(self:GetChecked())
    end)
    return button
  end

  local createCheckButtonPowerOrbValueHideFull = function(parent)
    local button = createBasicCheckButton(parent, addon.."PanelPowerOrbValueHideFull", "Hide on full*")
    button:SetScript("OnClick", function(self,value)
      panel.savePowerOrbValueHideFull(self:GetChecked())
    end)
    return button
  end

  local createSliderHealthOrbValueAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelHealthOrbValueAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.saveHealthOrbValueAlpha(value)
      panel.updateHealthOrbValueAlpha()
    end)
    return slider
  end

  local createSliderPowerOrbValueAlpha = function(parent)
    local slider = createBasicSlider(parent, addon.."PanelPowerOrbValueAlpha", "Alpha", 0, 1, 0.001)
    slider:HookScript("OnValueChanged", function(self,value)
      panel.savePowerOrbValueAlpha(value)
      panel.updatePowerOrbValueAlpha()
    end)
    return slider
  end

  local createPickerHealthOrbValueTopColor = function(parent)
    local picker = createBasicColorPicker(parent, addon.."PanelHealthOrbValueTopColor", "Text color", 75, 25)
    picker.click = function(r,g,b)
      panel.saveHealthOrbValueTopColor(r,g,b)
      panel.updateHealthOrbValueTopColor()
    end
    return picker
  end

  local createPickerPowerOrbValueTopColor = function(parent)
    local picker = createBasicColorPicker(parent, addon.."PanelPowerOrbValueTopColor", "Text color", 75, 25)
    picker.click = function(r,g,b)
      panel.savePowerOrbValueTopColor(r,g,b)
      panel.updatePowerOrbValueTopColor()
    end
    return picker
  end

  local createPickerHealthOrbValueBottomColor = function(parent)
    local picker = createBasicColorPicker(parent, addon.."PanelHealthOrbValueBottomColor", "Text color", 75, 25)
    picker.click = function(r,g,b)
      panel.saveHealthOrbValueBottomColor(r,g,b)
      panel.updateHealthOrbValueBottomColor()
    end
    return picker
  end

  local createPickerPowerOrbValueBottomColor = function(parent)
    local picker = createBasicColorPicker(parent, addon.."PanelPowerOrbValueBottomColor", "Text color", 75, 25)
    picker.click = function(r,g,b)
      panel.savePowerOrbValueBottomColor(r,g,b)
      panel.updatePowerOrbValueBottomColor()
    end
    return picker
  end

  local createDropdownHealthOrbValueTopTag = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelHealthOrbValueTopTag", "Choose top health tag", db.getListTag, 196)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      panel.saveHealthOrbValueTopTag(self.value)
      panel.updateHealthOrbValueTopTag()
    end
    return dropdownMenu
  end

  local createDropdownPowerOrbValueTopTag = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelPowerOrbValueTopTag", "Choose top power tag", db.getListTag, 196)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      panel.savePowerOrbValueTopTag(self.value)
      panel.updatePowerOrbValueTopTag()
    end
    return dropdownMenu
  end

  local createDropdownHealthOrbValueBottomTag = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelHealthOrbValueBottomTag", "Choose bottom health tag", db.getListTag, 196)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      panel.saveHealthOrbValueBottomTag(self.value)
      panel.updateHealthOrbValueBottomTag()
    end
    return dropdownMenu
  end

  local createDropdownPowerOrbValueBottomTag = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelPowerOrbValueBottomTag", "Choose bottom power tag", db.getListTag, 196)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      panel.savePowerOrbValueBottomTag(self.value)
      panel.updatePowerOrbValueBottomTag()
    end
    return dropdownMenu
  end

  --createBottomButtonHealthOrbSave
  local createBottomButtonHealthOrbSave = function(parent)
    --the save button needs a popup with an editbox
    StaticPopupDialogs["Roth_UI_HEALTHORB_SAVE"] = {
      text = "Enter a name for your template:",
      button1 = ACCEPT,
      button2 = CANCEL,
      hasEditBox = 1,
      maxLetters = 24,
      OnAccept = function(self)
        local text = self.editBox:GetText()
        text = text:gsub(" ", "")
        if strmatch(text,"%W") then
          print("|c00FF0000ERROR: Template could not be saved. Non-alphanumerical values found!")
        elseif strlen(text) == 0 then
          print("|c00FF0000ERROR: Template name is empty!")
        else
          db.saveTemplate(text,"HEALTH")
        end
      end,
      EditBoxOnEnterPressed = function(self)
        local text = self:GetParent().editBox:GetText()
        text = text:gsub(" ", "")
        if strmatch(text,"%W") then
          print("|c00FF0000ERROR: Template could not be saved. Non-alphanumerical values found!")
        elseif strlen(text) == 0 then
          print("|c00FF0000ERROR: Template name is empty!")
        else
          db.saveTemplate(text,"HEALTH")
          self:GetParent():Hide()
        end
      end,
      OnShow = function(self)
        self.editBox:SetFocus()
        panel:SetAlpha(0.2)
      end,
      OnHide = function(self)
        ChatEdit_FocusActiveWindow()
        self.editBox:SetText("")
        panel:SetAlpha(1)
      end,
      timeout = 0,
      exclusive = 1,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    }
    local button = createBasicButton(parent, addon.."PanelBottomHealthOrbSave", "Save as template", 30, 20)
    button:HookScript("OnClick", function()
      StaticPopup_Show("Roth_UI_HEALTHORB_SAVE")
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Click here to save the current health orb settings as a template.", 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return button
  end

  --createBottomButtonHealthOrbLoad
  local createBottomButtonHealthOrbLoad = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelHealthOrbLoadTemplate", "Choose template", db.getListTemplate, nil, nil, true)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      db.loadTemplate(self.value,"HEALTH")
    end
    local button = createBasicButton(parent, addon.."PanelBottomHealthOrbLoad", "Load template", 30, 20)
    button:HookScript("OnClick", function(self)
      ToggleMenu(dropdownMenu, self)
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Click here to load a template into your health orb.", 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return button
  end

  --createBottomButtonHealthOrbReset
  local createBottomButtonHealthOrbReset = function(parent)
    local button = createBasicButton(parent, addon.."PanelBottomHealthOrbReset", "Reset")
    button:HookScript("OnClick", function()
      db.loadCharacterDataDefaults("HEALTH")
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Click here to reset the healthorb to default.", 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return button
  end

  --createBottomButtonPowerOrbSave
  local createBottomButtonPowerOrbSave = function(parent)
    --the save button needs a popup with an editbox
    StaticPopupDialogs["Roth_UI_POWERORB_SAVE"] = {
      text = "Enter a name for your template:",
      button1 = ACCEPT,
      button2 = CANCEL,
      hasEditBox = 1,
      maxLetters = 24,
      OnAccept = function(self)
        local text = self.editBox:GetText()
        text = text:gsub(" ", "")
        if strmatch(text,"%W") then
          print("|c00FF0000ERROR: Template could not be saved. Non-alphanumerical values found!")
        elseif strlen(text) == 0 then
          print("|c00FF0000ERROR: Template name is empty!")
        else
          db.saveTemplate(text,"POWER")
        end
      end,
      EditBoxOnEnterPressed = function(self)
        local text = self:GetParent().editBox:GetText()
        text = text:gsub(" ", "")
        if strmatch(text,"%W") then
          print("|c00FF0000ERROR: Template could not be saved. Non-alphanumerical values found!")
        elseif strlen(text) == 0 then
          print("|c00FF0000ERROR: Template name is empty!")
        else
          db.saveTemplate(text,"POWER")
          self:GetParent():Hide()
        end
      end,
      OnShow = function(self)
        self.editBox:SetFocus()
        panel:SetAlpha(0.2)
      end,
      OnHide = function(self)
        ChatEdit_FocusActiveWindow()
        self.editBox:SetText("")
        panel:SetAlpha(1)
      end,
      timeout = 0,
      exclusive = 1,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    }
    local button = createBasicButton(parent, addon.."PanelBottomPowerOrbSave", "Save as template", 30, 20)
    button:HookScript("OnClick", function()
      StaticPopup_Show("Roth_UI_POWERORB_SAVE")
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Click here to save the current power orb settings as a template.", 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return button
  end

  --createBottomButtonPowerOrbLoad
  local createBottomButtonPowerOrbLoad = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelPowerOrbLoadTemplate", "Choose template", db.getListTemplate, nil, nil, true)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      db.loadTemplate(self.value,"POWER")
    end
    local button = createBasicButton(parent, addon.."PanelBottomPowerOrbLoad", "Load template", 30, 20)
    button:HookScript("OnClick", function(self)
      ToggleMenu(dropdownMenu, self)
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Click here to load a template into your power orb.", 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return button
  end

  --createBottomButtonPowerOrbReset
  local createBottomButtonPowerOrbReset = function(parent)
    local button = createBasicButton(parent, addon.."PanelBottomPowerOrbReset", "Reset")
    button:HookScript("OnClick", function()
      db.loadCharacterDataDefaults("POWER")
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Click here to reset the powerorb to default.", 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return button
  end

  --createBottomButtonTemplateDelete
  local createBottomButtonTemplateDelete = function(parent)
    local dropdownMenu = createBasicDropDownMenu(parent, addon.."PanelBottomDeleteTemplate", "Choose template", db.getListTemplate, nil, nil, true)
    dropdownMenu.click = function(self)
      SetSelectedValue(dropdownMenu, self.value)
      db.deleteTemplate(self.value)
    end
    local button = createBasicButton(parent, addon.."PanelBottomTemplateDelete", "Delete")
    button:HookScript("OnClick", function(self)
      ToggleMenu(dropdownMenu, self)
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Click here to delete a template from the database.", 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return button
  end

  --createBottomButtonTemplateReload
  local createBottomButtonTemplateReload = function(parent)
    local button = createBasicButton(parent, addon.."PanelBottomTemplateReload", "Reload UI")
    button:HookScript("OnClick", function()
      db.char.reload = true
      ReloadUI()
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Click here to reload the user interface.", 0, 1, 0.5, 1, 1, 1)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return button
  end

  --SPAWN PANEL ELEMENTS

  --create master headline
  panel.elementHealthMasterHeadline = createBasicFontString(panel,nil,nil,"GameFontNormalLarge","Health Orb Settings")
  panel.elementPowerMasterHeadline = createBasicFontString(panel,nil,nil,"GameFontNormalLarge","Power Orb Settings")
  --create filling headline
  panel.elementHealthFillingHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Filling Texture")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementHealthFillingHeadline,"The following options allow you to edit the filling orb texture and color.")
  panel.elementPowerFillingHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Filling Texture")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementPowerFillingHeadline,"The following options allow you to edit the filling orb texture and color.")
  --create filling texture dropdowns
  panel.elementHealthOrbFillingTexture = createDropdownHealthOrbFillingTexture(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbFillingTexture = createDropdownPowerOrbFillingTexture(panel.scrollFrame.scrollChild)
  --create filling color auto checkbutton
  panel.elementHealthOrbFillingColorAuto = createCheckButtonHealthOrbFillingColorAuto(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbFillingColorAuto = createCheckButtonPowerOrbFillingColorAuto(panel.scrollFrame.scrollChild)
  --create filling color picker
  panel.elementHealthOrbFillingColor = createPickerHealthOrbFillingColor(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbFillingColor = createPickerPowerOrbFillingColor(panel.scrollFrame.scrollChild)
  --create model headline
  panel.elementHealthModelHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Model Animation")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementHealthModelHeadline,"This feature is currently a WIP. Enable at your own risk.")
  panel.elementPowerModelHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Model Animation")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementPowerModelHeadline,"This feature is currently a WIP. Enable at your own risk.")
  --create model enable checkbutton
  panel.elementHealthOrbModelEnable = createCheckButtonHealthOrbModelEnable(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbModelEnable = createCheckButtonPowerOrbModelEnable(panel.scrollFrame.scrollChild)
  --create model animation dropdown
  panel.elementHealthOrbModelAnimation = createDropdownHealthOrbModelAnimation(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbModelAnimation = createDropdownPowerOrbModelAnimation(panel.scrollFrame.scrollChild)
  --create model alpha slider
  panel.elementHealthOrbModelAlpha = createSliderHealthOrbModelAlpha(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbModelAlpha = createSliderPowerOrbModelAlpha(panel.scrollFrame.scrollChild)
  --create model scale slider
  panel.elementHealthOrbModelScale = createSliderHealthOrbModelScale(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbModelScale = createSliderPowerOrbModelScale(panel.scrollFrame.scrollChild)
  --create model pos x slider
  panel.elementHealthOrbModelPosX = createSliderHealthOrbModelPosX(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbModelPosX = createSliderPowerOrbModelPosX(panel.scrollFrame.scrollChild)
  --create model pos y slider
  panel.elementHealthOrbModelPosY = createSliderHealthOrbModelPosY(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbModelPosY = createSliderPowerOrbModelPosY(panel.scrollFrame.scrollChild)
  --create model rotation slider
  panel.elementHealthOrbModelRotation = createSliderHealthOrbModelRotation(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbModelRotation = createSliderPowerOrbModelRotation(panel.scrollFrame.scrollChild)
  --create model zoom slider
  panel.elementHealthOrbModelZoom = createSliderHealthOrbModelZoom(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbModelZoom = createSliderPowerOrbModelZoom(panel.scrollFrame.scrollChild)
  --create highlight headline
  panel.elementHealthHighlightHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Highlight Texture")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementHealthHighlightHeadline,"The following option allows you to adjust the opacity of the highlight texture.")
  panel.elementPowerHighlightHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Highlight Texture")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementPowerHighlightHeadline,"The following option allows you to adjust the opacity of the highlight texture.")
  --create highlight alpha slider
  panel.elementHealthOrbHighlightAlpha = createSliderHealthOrbHighlightAlpha(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbHighlightAlpha = createSliderPowerOrbHighlightAlpha(panel.scrollFrame.scrollChild)
  --create galaxies headline
  panel.elementHealthGalaxiesHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Rotating galaxies")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementHealthGalaxiesHeadline,"The following option allows you to adjust the opacity of the rotating galaxy textures.")
  panel.elementPowerGalaxiesHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Rotating galaxies")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementPowerGalaxiesHeadline,"The following option allows you to adjust the opacity of the rotating galaxy textures.")
  --create galaxies alpha slider
  panel.elementHealthOrbGalaxiesAlpha = createSliderHealthOrbGalaxiesAlpha(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbGalaxiesAlpha = createSliderPowerOrbGalaxiesAlpha(panel.scrollFrame.scrollChild)
    --create bubbles headline
  panel.elementHealthBubblesHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Rotating bubbles")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementHealthBubblesHeadline,"The following option allows you to adjust the opacity of the rotating bubble textures.")
  panel.elementPowerBubblesHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Rotating bubbles")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementPowerBubblesHeadline,"The following option allows you to adjust the opacity of the rotating bubble textures.")
  --create bubbles alpha slider
  panel.elementHealthOrbBubblesAlpha = createSliderHealthOrbBubblesAlpha(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbBubblesAlpha = createSliderPowerOrbBubblesAlpha(panel.scrollFrame.scrollChild)
  --create spark headline
  panel.elementHealthSparkHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Spark Texture")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementHealthSparkHeadline,"The following option allows you to adjust the opacity of the spark texture.\n|cFFFFFFFFThe texture helps blending the filling texture.")
  panel.elementPowerSparkHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Spark Texture")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementPowerSparkHeadline,"The following option allows you to adjust the opacity of the spark texture.\n|cFFFFFFFFThe texture helps blending the filling texture.")
  --create spark alpha slider
  panel.elementHealthOrbSparkAlpha = createSliderHealthOrbSparkAlpha(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbSparkAlpha = createSliderPowerOrbSparkAlpha(panel.scrollFrame.scrollChild)
  panel.elementHealthOrbValueHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Orb Value Visibility")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementHealthOrbValueHeadline, "The following options allow you adjust the orb values.\n|cFFFFFFFF*Some changes will only become visible on config panel close otherwise it would be impossible to set up the orb values.")
  panel.elementPowerOrbValueHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Orb Value Visibility")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementPowerOrbValueHeadline, "The following options allow you adjust the orb values.\n|cFFFFFFFF*Some changes will only become visible on config panel close otherwise it would be impossible to set up the orb values.")
  panel.elementHealthOrbValueHideEmpty = createCheckButtonHealthOrbValueHideEmpty(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbValueHideEmpty = createCheckButtonPowerOrbValueHideEmpty(panel.scrollFrame.scrollChild)
  panel.elementHealthOrbValueHideFull = createCheckButtonHealthOrbValueHideFull(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbValueHideFull = createCheckButtonPowerOrbValueHideFull(panel.scrollFrame.scrollChild)
  panel.elementHealthOrbValueAlpha = createSliderHealthOrbValueAlpha(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbValueAlpha = createSliderPowerOrbValueAlpha(panel.scrollFrame.scrollChild)
  panel.elementHealthOrbValueTopHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Top Orb Value Tag/Color")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementHealthOrbValueTopHeadline, "The following options allow you adjust color and tag of the top orb value.")
  panel.elementPowerOrbValueTopHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Top Orb Value Tag/Color")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementPowerOrbValueTopHeadline, "The following options allow you adjust color and tag of the top orb value.")
  panel.elementHealthOrbValueTopTag = createDropdownHealthOrbValueTopTag(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbValueTopTag = createDropdownPowerOrbValueTopTag(panel.scrollFrame.scrollChild)
  panel.elementHealthOrbValueTopColor = createPickerHealthOrbValueTopColor(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbValueTopColor = createPickerPowerOrbValueTopColor(panel.scrollFrame.scrollChild)
  panel.elementHealthOrbValueBottomHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Bottom Orb Value Tag/Color")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementHealthOrbValueBottomHeadline, "The following options allow you adjust color and tag of the bottom orb value.")
  panel.elementPowerOrbValueBottomHeadline = createBasicFontString(panel.scrollFrame.scrollChild,nil,nil,"GameFontNormalLarge","Bottom Orb Value Tag/Color")
  createTooltipButton(panel.scrollFrame.scrollChild,panel.elementPowerOrbValueBottomHeadline, "The following options allow you adjust color and tag of the bottom orb value.")
  panel.elementHealthOrbValueBottomTag = createDropdownHealthOrbValueBottomTag(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbValueBottomTag = createDropdownPowerOrbValueBottomTag(panel.scrollFrame.scrollChild)
  panel.elementHealthOrbValueBottomColor = createPickerHealthOrbValueBottomColor(panel.scrollFrame.scrollChild)
  panel.elementPowerOrbValueBottomColor = createPickerPowerOrbValueBottomColor(panel.scrollFrame.scrollChild)

  --SPAWN HEADLINE BACKGROUNDS

  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementHealthFillingHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementHealthModelHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementPowerFillingHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementPowerModelHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementHealthHighlightHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementPowerHighlightHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementHealthGalaxiesHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementPowerGalaxiesHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementHealthBubblesHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementPowerBubblesHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementHealthSparkHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementPowerSparkHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementHealthOrbValueHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementPowerOrbValueHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementHealthOrbValueTopHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementPowerOrbValueTopHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementHealthOrbValueBottomHeadline)
  createHeadlineBackground(panel.scrollFrame.scrollChild,panel.elementPowerOrbValueBottomHeadline)

  --SPAWN BOTTOM PANEL BUTTONS

  --createBottomButtonHealthOrbSave
  panel.bottomElementHealthOrbSave = createBottomButtonHealthOrbSave(panel)
  --createBottomButtonHealthOrbLoad
  panel.bottomElementHealthOrbLoad = createBottomButtonHealthOrbLoad(panel)
  --createBottomButtonHealthOrbReset
  panel.bottomElementHealthOrbReset = createBottomButtonHealthOrbReset(panel)
  --createBottomButtonPowerOrbSave
  panel.bottomElementPowerOrbSave = createBottomButtonPowerOrbSave(panel)
  --createBottomButtonPowerOrbLoad
  panel.bottomElementPowerOrbLoad = createBottomButtonPowerOrbLoad(panel)
  --createBottomButtonPowerOrbReset
  panel.bottomElementPowerOrbReset = createBottomButtonPowerOrbReset(panel)
  --createBottomButtonTemplateDelete
  panel.bottomElementTemplateDelete = createBottomButtonTemplateDelete(panel)
  --createBottomButtonTemplateReload
  panel.bottomElementTemplateReload = createBottomButtonTemplateReload(panel)

  --position master headline
  panel.elementHealthMasterHeadline:SetPoint("BOTTOM", panel.scrollFrame, "TOP", (-panel.scrollFrame:GetWidth()/2-2)/2, 14)
  panel.elementPowerMasterHeadline:SetPoint("BOTTOM", panel.scrollFrame, "TOP", (panel.scrollFrame:GetWidth()/2-2)/2, 14)
  --position filling headline
  panel.elementHealthFillingHeadline:SetPoint("TOPLEFT", panel.scrollFrame.scrollChild.leftTexture, 20, -10)
  panel.elementPowerFillingHeadline:SetPoint("TOPLEFT", panel.scrollFrame.scrollChild.rightTexture, 20, -10)
  --position filling texture dropdown
  panel.elementHealthOrbFillingTexture:SetPoint("TOPLEFT", panel.elementHealthFillingHeadline, "BOTTOMLEFT", -20, -10)
  panel.elementPowerOrbFillingTexture:SetPoint("TOPLEFT", panel.elementPowerFillingHeadline, "BOTTOMLEFT", -20, -10)
  --position filling color auto checkbutton
  panel.elementHealthOrbFillingColorAuto:SetPoint("TOPLEFT", panel.elementHealthFillingHeadline, "BOTTOMLEFT", -4, -45)
  panel.elementPowerOrbFillingColorAuto:SetPoint("TOPLEFT", panel.elementPowerFillingHeadline, "BOTTOMLEFT", -4, -45)
  --position filling color picker
  panel.elementHealthOrbFillingColor:SetPoint("TOPLEFT", panel.elementHealthFillingHeadline, "BOTTOMLEFT", -3, -75)
  panel.elementPowerOrbFillingColor:SetPoint("TOPLEFT", panel.elementPowerFillingHeadline, "BOTTOMLEFT", -3, -75)
  --position model headline
  panel.elementHealthModelHeadline:SetPoint("TOPLEFT", panel.elementHealthFillingHeadline, "BOTTOMLEFT", 0, -115)
  panel.elementPowerModelHeadline:SetPoint("TOPLEFT", panel.elementPowerFillingHeadline, "BOTTOMLEFT", 0, -115)
  --position model enable checkbutton
  panel.elementHealthOrbModelEnable:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", -4, -10)
  panel.elementPowerOrbModelEnable:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", -4, -10)
  --position model animation dropdown
  panel.elementHealthOrbModelAnimation:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", -20, -36)
  panel.elementPowerOrbModelAnimation:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", -20, -36)
  --position model alpha slider
  panel.elementHealthOrbModelAlpha:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", 0, -80)
  panel.elementPowerOrbModelAlpha:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", 0, -80)
  --position model scale slider
  panel.elementHealthOrbModelScale:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", 0, -110)
  panel.elementPowerOrbModelScale:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", 0, -110)
  --position model pos x slider
  panel.elementHealthOrbModelPosX:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", 0, -140)
  panel.elementPowerOrbModelPosX:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", 0, -140)
  --position model pos y slider
  panel.elementHealthOrbModelPosY:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", 0, -170)
  panel.elementPowerOrbModelPosY:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", 0, -170)
  --position model rotation slider
  panel.elementHealthOrbModelRotation:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", 0, -200)
  panel.elementPowerOrbModelRotation:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", 0, -200)
  --position model zoom slider
  panel.elementHealthOrbModelZoom:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", 0, -230)
  panel.elementPowerOrbModelZoom:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", 0, -230)
  --position highlight headline
  panel.elementHealthHighlightHeadline:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", 0, -270)
  panel.elementPowerHighlightHeadline:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", 0, -270)
  --position highlight alpha slider
  panel.elementHealthOrbHighlightAlpha:SetPoint("TOPLEFT", panel.elementHealthHighlightHeadline, "BOTTOMLEFT", 0, -20)
  panel.elementPowerOrbHighlightAlpha:SetPoint("TOPLEFT", panel.elementPowerHighlightHeadline, "BOTTOMLEFT", 0, -20)
  --position galaxies headline
  panel.elementHealthGalaxiesHeadline:SetPoint("TOPLEFT", panel.elementHealthHighlightHeadline, "BOTTOMLEFT", 0, -60)
  panel.elementPowerGalaxiesHeadline:SetPoint("TOPLEFT", panel.elementPowerHighlightHeadline, "BOTTOMLEFT", 0, -60)
  --position galaxies alpha slider
  panel.elementHealthOrbGalaxiesAlpha:SetPoint("TOPLEFT", panel.elementHealthGalaxiesHeadline, "BOTTOMLEFT", 0, -20)
  panel.elementPowerOrbGalaxiesAlpha:SetPoint("TOPLEFT", panel.elementPowerGalaxiesHeadline, "BOTTOMLEFT", 0, -20)
  --position bubbles headline
  panel.elementHealthBubblesHeadline:SetPoint("TOPLEFT", panel.elementHealthGalaxiesHeadline, "BOTTOMLEFT", 0, -60)
  panel.elementPowerBubblesHeadline:SetPoint("TOPLEFT", panel.elementPowerGalaxiesHeadline, "BOTTOMLEFT", 0, -60)
  --position bubbles alpha slider
  panel.elementHealthOrbBubblesAlpha:SetPoint("TOPLEFT", panel.elementHealthBubblesHeadline, "BOTTOMLEFT", 0, -20)
  panel.elementPowerOrbBubblesAlpha:SetPoint("TOPLEFT", panel.elementPowerBubblesHeadline, "BOTTOMLEFT", 0, -20)
  --position spark headline
  panel.elementHealthSparkHeadline:SetPoint("TOPLEFT", panel.elementHealthBubblesHeadline, "BOTTOMLEFT", 0, -60)
  panel.elementPowerSparkHeadline:SetPoint("TOPLEFT", panel.elementPowerBubblesHeadline, "BOTTOMLEFT", 0, -60)
  --position spark alpha slider
  panel.elementHealthOrbSparkAlpha:SetPoint("TOPLEFT", panel.elementHealthSparkHeadline, "BOTTOMLEFT", 0, -20)
  panel.elementPowerOrbSparkAlpha:SetPoint("TOPLEFT", panel.elementPowerSparkHeadline, "BOTTOMLEFT", 0, -20)
  panel.elementHealthOrbValueHeadline:SetPoint("TOPLEFT", panel.elementHealthSparkHeadline, "BOTTOMLEFT", 0, -60)
  panel.elementPowerOrbValueHeadline:SetPoint("TOPLEFT", panel.elementPowerSparkHeadline, "BOTTOMLEFT", 0, -60)
  panel.elementHealthOrbValueHideEmpty:SetPoint("TOPLEFT", panel.elementHealthOrbValueHeadline, "BOTTOMLEFT", -4, -10)
  panel.elementPowerOrbValueHideEmpty:SetPoint("TOPLEFT", panel.elementPowerOrbValueHeadline, "BOTTOMLEFT", -4, -10)
  panel.elementHealthOrbValueHideFull:SetPoint("TOPLEFT", panel.elementHealthOrbValueHeadline, "BOTTOMLEFT", -4, -35)
  panel.elementPowerOrbValueHideFull:SetPoint("TOPLEFT", panel.elementPowerOrbValueHeadline, "BOTTOMLEFT", -4, -35)
  panel.elementHealthOrbValueAlpha:SetPoint("TOPLEFT", panel.elementHealthOrbValueHeadline, "BOTTOMLEFT", 0, -73)
  panel.elementPowerOrbValueAlpha:SetPoint("TOPLEFT", panel.elementPowerOrbValueHeadline, "BOTTOMLEFT", 0, -73)
  panel.elementHealthOrbValueTopHeadline:SetPoint("TOPLEFT", panel.elementHealthOrbValueHeadline, "BOTTOMLEFT", 0, -110)
  panel.elementPowerOrbValueTopHeadline:SetPoint("TOPLEFT", panel.elementPowerOrbValueHeadline, "BOTTOMLEFT", 0, -110)
  panel.elementHealthOrbValueTopTag:SetPoint("TOPLEFT", panel.elementHealthOrbValueTopHeadline, "BOTTOMLEFT", -20, -10)
  panel.elementPowerOrbValueTopTag:SetPoint("TOPLEFT", panel.elementPowerOrbValueTopHeadline, "BOTTOMLEFT", -20, -10)
  panel.elementHealthOrbValueTopColor:SetPoint("TOPLEFT", panel.elementHealthOrbValueTopHeadline, "BOTTOMLEFT", -4, -45)
  panel.elementPowerOrbValueTopColor:SetPoint("TOPLEFT", panel.elementPowerOrbValueTopHeadline, "BOTTOMLEFT", -4, -45)
  panel.elementHealthOrbValueBottomHeadline:SetPoint("TOPLEFT", panel.elementHealthOrbValueTopHeadline, "BOTTOMLEFT", 0, -85)
  panel.elementPowerOrbValueBottomHeadline:SetPoint("TOPLEFT", panel.elementPowerOrbValueTopHeadline, "BOTTOMLEFT", 0, -85)
  panel.elementHealthOrbValueBottomTag:SetPoint("TOPLEFT", panel.elementHealthOrbValueBottomHeadline, "BOTTOMLEFT", -20, -10)
  panel.elementPowerOrbValueBottomTag:SetPoint("TOPLEFT", panel.elementPowerOrbValueBottomHeadline, "BOTTOMLEFT", -20, -10)
  panel.elementHealthOrbValueBottomColor:SetPoint("TOPLEFT", panel.elementHealthOrbValueBottomHeadline, "BOTTOMLEFT", -4, -45)
  panel.elementPowerOrbValueBottomColor:SetPoint("TOPLEFT", panel.elementPowerOrbValueBottomHeadline, "BOTTOMLEFT", -4, -45)

  --health orb save/load
  panel.bottomElementHealthOrbSave:SetPoint("BOTTOMLEFT",35,10)
  panel.bottomElementHealthOrbLoad:SetPoint("LEFT", panel.bottomElementHealthOrbSave, "RIGHT", 0, 0)
  panel.bottomElementHealthOrbSave:SetFrameLevel(panel.scrollFrame.scrollChild:GetFrameLevel()+2)
  panel.bottomElementHealthOrbLoad:SetFrameLevel(panel.scrollFrame.scrollChild:GetFrameLevel()+2)
  --power orb save/load
  panel.bottomElementPowerOrbSave:SetPoint("BOTTOMLEFT",315,10)
  panel.bottomElementPowerOrbLoad:SetPoint("LEFT", panel.bottomElementPowerOrbSave, "RIGHT", 0, 0)
  panel.bottomElementPowerOrbSave:SetFrameLevel(panel.scrollFrame.scrollChild:GetFrameLevel()+2)
  panel.bottomElementPowerOrbLoad:SetFrameLevel(panel.scrollFrame.scrollChild:GetFrameLevel()+2)
  panel.bottomElementHealthOrbReset:SetPoint("LEFT", panel.elementHealthMasterHeadline, "RIGHT", 10, 0)
  panel.bottomElementPowerOrbReset:SetPoint("LEFT", panel.elementPowerMasterHeadline, "RIGHT", 10, 0)
  panel.bottomElementTemplateDelete:SetPoint("BOTTOM",-12,-18)
  panel.bottomElementTemplateReload:SetPoint("BOTTOMRIGHT",-12,-18)

  --UPDATE ORB ELEMENTS

  panel.updateHealthOrbFillingTexture = function()
    if not ns.HealthOrb or not ns.HealthOrb.fill then return end
    ns.HealthOrb.fill:SetStatusBarTexture(panel.loadHealthOrbFillingTexture())
  end

  panel.updatePowerOrbFillingTexture = function()
    if not ns.PowerOrb or not ns.PowerOrb.fill then return end
    ns.PowerOrb.fill:SetStatusBarTexture(panel.loadPowerOrbFillingTexture())
  end

  panel.updateHealthOrbFillingColorAuto = function()
    if not ns.HealthOrb or not ns.HealthOrb.fill then return end
    if panel.loadHealthOrbFillingColorAuto() then
      ns.HealthOrb.fill.colorClass = true
      ns.HealthOrb.fill.colorHealth = true
      local color = ns.cfg.playercolor or { r = 1, g = 0, b = 1, }
      ns.HealthOrb.fill:SetStatusBarColor(color.r,color.g,color.b)
      panel.scrollFrame.scrollChild.leftTexture:SetVertexColor(color.r,color.g,color.b)
      panel.elementHealthMasterHeadline:SetTextColor(color.r,color.g,color.b)
    else
      ns.HealthOrb.fill.colorClass = false
      ns.HealthOrb.fill.colorHealth = false
      local color = panel.loadHealthOrbFillingColor()
      ns.HealthOrb.fill:SetStatusBarColor(color.r,color.g,color.b)
      panel.scrollFrame.scrollChild.leftTexture:SetVertexColor(color.r,color.g,color.b)
      panel.elementHealthMasterHeadline:SetTextColor(color.r,color.g,color.b)
    end
  end

  panel.updatePowerOrbFillingColorAuto = function()
    if not ns.PowerOrb or not ns.PowerOrb.fill then return end
    if panel.loadPowerOrbFillingColorAuto() then
      ns.PowerOrb.fill.colorPower = true
      local color = ns.cfg.powercolors[select(2, UnitPowerType("player"))] or { r = 1, g = 0, b = 1, }
      ns.PowerOrb.fill:SetStatusBarColor(color.r,color.g,color.b)
      panel.scrollFrame.scrollChild.rightTexture:SetVertexColor(color.r,color.g,color.b)
      panel.elementPowerMasterHeadline:SetTextColor(color.r,color.g,color.b)
    else
      ns.PowerOrb.fill.colorPower = false
      local color = panel.loadPowerOrbFillingColor()
      ns.PowerOrb.fill:SetStatusBarColor(color.r,color.g,color.b)
      panel.scrollFrame.scrollChild.rightTexture:SetVertexColor(color.r,color.g,color.b)
      panel.elementPowerMasterHeadline:SetTextColor(color.r,color.g,color.b)
    end
  end

  panel.updateHealthOrbFillingColor = function()
    if not ns.HealthOrb or not ns.HealthOrb.fill then return end
    local color = panel.loadHealthOrbFillingColor()
    ns.HealthOrb.fill:SetStatusBarColor(color.r,color.g,color.b)
    panel.scrollFrame.scrollChild.leftTexture:SetVertexColor(color.r,color.g,color.b)
    panel.elementHealthMasterHeadline:SetTextColor(color.r,color.g,color.b)
  end

  panel.updatePowerOrbFillingColor = function()
    if not ns.PowerOrb or not ns.PowerOrb.fill then return end
    local color = panel.loadPowerOrbFillingColor()
    ns.PowerOrb.fill:SetStatusBarColor(color.r,color.g,color.b)
    panel.scrollFrame.scrollChild.rightTexture:SetVertexColor(color.r,color.g,color.b)
    panel.elementPowerMasterHeadline:SetTextColor(color.r,color.g,color.b)
  end

  panel.updateHealthOrbModelEnable = function()
    if not ns.HealthOrb or not ns.HealthOrb.model then return end
    if panel.loadHealthOrbModelEnable() then
      ns.HealthOrb.model:Show()
    else
      ns.HealthOrb.model:Hide()
    end
  end

  panel.updatePowerOrbModelEnable = function()
    if not ns.PowerOrb or not ns.PowerOrb.model then return end
    if panel.loadPowerOrbModelEnable() then
      ns.PowerOrb.model:Show()
    else
      ns.PowerOrb.model:Hide()
    end
  end

  panel.updateHealthOrbModelAnimation = function()
    if not ns.HealthOrb or not ns.HealthOrb.model then return end
    ns.HealthOrb.model:Update() --update the full model with all values, displayId is not enough
  end

  panel.updatePowerOrbModelAnimation = function()
    if not ns.PowerOrb or not ns.PowerOrb.model then return end
    ns.PowerOrb.model:Update() --update the full model with all values, displayId is not enough
  end

  panel.updateHealthOrbModelAlpha = function()
    if not ns.HealthOrb or not ns.HealthOrb.model then return end
    ns.HealthOrb.model:SetAlpha(panel.loadHealthOrbModelAlpha())
  end

  panel.updatePowerOrbModelAlpha = function()
    if not ns.PowerOrb or not ns.PowerOrb.model then return end
    ns.PowerOrb.model:SetAlpha(panel.loadPowerOrbModelAlpha())
  end

  panel.updateHealthOrbModelScale = function()
    if not ns.HealthOrb or not ns.HealthOrb.model then return end
    ns.HealthOrb.model:SetCamDistanceScale(panel.loadHealthOrbModelScale())
  end

  panel.updatePowerOrbModelScale = function()
    if not ns.PowerOrb or not ns.PowerOrb.model then return end
    ns.PowerOrb.model:SetCamDistanceScale(panel.loadPowerOrbModelScale())
  end

  panel.updateHealthOrbModelPosX = function()
    if not ns.HealthOrb or not ns.HealthOrb.model then return end
    local x, y = panel.loadHealthOrbModelPosX(), panel.loadHealthOrbModelPosY()
    ns.HealthOrb.model:SetPosition(0,x,y)
  end

  panel.updatePowerOrbModelPosX =function()
    if not ns.PowerOrb or not ns.PowerOrb.model then return end
    local x, y = panel.loadPowerOrbModelPosX(), panel.loadPowerOrbModelPosY()
    ns.PowerOrb.model:SetPosition(0,x,y)
  end

  panel.updateHealthOrbModelPosY = function()
    if not ns.HealthOrb or not ns.HealthOrb.model then return end
    local x, y = panel.loadHealthOrbModelPosX(), panel.loadHealthOrbModelPosY()
    ns.HealthOrb.model:SetPosition(0,x,y)
  end

  panel.updatePowerOrbModelPosY = function()
    if not ns.PowerOrb or not ns.PowerOrb.model then return end
    local x, y = panel.loadPowerOrbModelPosX(), panel.loadPowerOrbModelPosY()
    ns.PowerOrb.model:SetPosition(0,x,y)
  end

  panel.updateHealthOrbModelRotation = function()
    if not ns.HealthOrb or not ns.HealthOrb.model then return end
    ns.HealthOrb.model:SetRotation(panel.loadHealthOrbModelRotation())
  end

  panel.updatePowerOrbModelRotation = function()
    if not ns.PowerOrb or not ns.PowerOrb.model then return end
    ns.PowerOrb.model:SetRotation(panel.loadPowerOrbModelRotation())
  end

  panel.updateHealthOrbModelZoom = function()
    if not ns.HealthOrb or not ns.HealthOrb.model then return end
    ns.HealthOrb.model:SetPortraitZoom(panel.loadHealthOrbModelZoom())
  end

  panel.updatePowerOrbModelZoom = function()
    if not ns.PowerOrb or not ns.PowerOrb.model then return end
    ns.PowerOrb.model:SetPortraitZoom(panel.loadPowerOrbModelZoom())
  end

  panel.updateHealthOrbHighlightAlpha = function()
    if not ns.HealthOrb or not ns.HealthOrb.highlight then return end
    ns.HealthOrb.highlight:SetAlpha(panel.loadHealthOrbHighlightAlpha())
  end

  panel.updatePowerOrbHighlightAlpha = function()
    if not ns.PowerOrb or not ns.PowerOrb.highlight then return end
    ns.PowerOrb.highlight:SetAlpha(panel.loadPowerOrbHighlightAlpha())
  end
  
  panel.updateHealthOrbGalaxiesAlpha = function()
    if not ns.HealthOrb or not ns.HealthOrb.galaxies then return end
    local alpha = panel.loadHealthOrbGalaxiesAlpha() or 0
    for i, galaxy in pairs(ns.HealthOrb.galaxies) do
      if galaxy.ag:IsPlaying() and alpha == 0 then
        galaxy.ag:Stop()
      elseif not galaxy.ag:IsPlaying() and alpha > 0 then
        galaxy.ag:Play()
      end
      galaxy:SetAlpha(alpha)
    end
  end

  panel.updatePowerOrbGalaxiesAlpha = function()
    if not ns.PowerOrb or not ns.PowerOrb.galaxies then return end
    local alpha = panel.loadPowerOrbGalaxiesAlpha() or 0
    for i, galaxy in pairs(ns.PowerOrb.galaxies) do
      if galaxy.ag:IsPlaying() and alpha == 0 then
        galaxy.ag:Stop()
      elseif not galaxy.ag:IsPlaying() and alpha > 0 then
        galaxy.ag:Play()
      end
      galaxy:SetAlpha(alpha)
    end
  end
  
  panel.updateHealthOrbBubblesAlpha = function()
    if ns.HealthOrb.bubbles then
      local alpha = panel.loadHealthOrbBubblesAlpha() or 0
      for i, bubble in pairs(ns.HealthOrb.bubbles) do
        if bubble.ag:IsPlaying() and alpha == 0 then
          bubble.ag:Stop()
        elseif not bubble.ag:IsPlaying() and alpha > 0 then
          bubble.ag:Play()
        end
        bubble:SetAlpha(alpha)
      end
    end
  end

  panel.updatePowerOrbBubblesAlpha = function()
    if ns.PowerOrb.bubbles then
      local alpha = panel.loadPowerOrbBubblesAlpha() or 0
      for i, bubble in pairs(ns.PowerOrb.bubbles) do
        if bubble.ag:IsPlaying() and alpha == 0 then
          bubble.ag:Stop()
        elseif not bubble.ag:IsPlaying() and alpha > 0 then
          bubble.ag:Play()
        end
        bubble:SetAlpha(alpha)
      end
    end
  end

  panel.updateHealthOrbSparkAlpha = function()
    if not ns.HealthOrb or not ns.HealthOrb.spark then return end
    ns.HealthOrb.spark:SetAlpha(panel.loadHealthOrbSparkAlpha())
  end

  panel.updatePowerOrbSparkAlpha = function()
    if not ns.PowerOrb or not ns.PowerOrb.spark then return end
    ns.PowerOrb.spark:SetAlpha(panel.loadPowerOrbSparkAlpha())
  end

  panel.updateHealthOrbValueAlpha = function()
    if not ns.HealthOrb or not ns.HealthOrb.values then return end
    ns.HealthOrb.values:SetAlpha(panel.loadHealthOrbValueAlpha())
  end

  panel.updatePowerOrbValueAlpha = function()
    if not ns.PowerOrb or not ns.PowerOrb.values then return end
    ns.PowerOrb.values:SetAlpha(panel.loadPowerOrbValueAlpha())
  end

  panel.updateHealthOrbValueTopColor = function()
    if not ns.HealthOrb or not ns.HealthOrb.values or not ns.HealthOrb.values.top then return end
    local color = panel.loadHealthOrbValueTopColor()
    ns.HealthOrb.values.top:SetTextColor(color.r,color.g,color.b)
  end

  panel.updatePowerOrbValueTopColor = function()
    if not ns.PowerOrb or not ns.PowerOrb.values or not ns.PowerOrb.values.top then return end
    local color = panel.loadPowerOrbValueTopColor()
    ns.PowerOrb.values.top:SetTextColor(color.r,color.g,color.b)
  end

  panel.updateHealthOrbValueBottomColor = function()
    if not ns.HealthOrb or not ns.HealthOrb.values or not ns.HealthOrb.values.bottom then return end
    local color = panel.loadHealthOrbValueBottomColor()
    ns.HealthOrb.values.bottom:SetTextColor(color.r,color.g,color.b)
  end

  panel.updatePowerOrbValueBottomColor = function()
    if not ns.PowerOrb or not ns.PowerOrb.values or not ns.PowerOrb.values.bottom then return end
    local color = panel.loadPowerOrbValueBottomColor()
    ns.PowerOrb.values.bottom:SetTextColor(color.r,color.g,color.b)
  end

  panel.updateHealthOrbValueTopTag = function()
    if not ns.HealthOrb or not ns.HealthOrb.values or not ns.HealthOrb.values.top or not ns.unit or not ns.unit.player then return end
    ns.HealthOrb.values.top:SetText(oUF.Tags.Methods["diablo:HealthOrbTop"](ns.unit.player.__unit))
  end

  panel.updatePowerOrbValueTopTag = function()
    if not ns.PowerOrb or not ns.PowerOrb.values or not ns.PowerOrb.values.top or not ns.unit or not ns.unit.player then return end
    ns.PowerOrb.values.top:SetText(oUF.Tags.Methods["diablo:PowerOrbTop"](ns.unit.player.__unit))
  end

  panel.updateHealthOrbValueBottomTag = function()
    if not ns.HealthOrb or not ns.HealthOrb.values or not ns.HealthOrb.values.bottom or not ns.unit or not ns.unit.player then return end
    ns.HealthOrb.values.bottom:SetText(oUF.Tags.Methods["diablo:HealthOrbBottom"](ns.unit.player.__unit))
  end

  panel.updatePowerOrbValueBottomTag = function()
    if not ns.PowerOrb or not ns.PowerOrb.values or not ns.PowerOrb.values.bottom or not ns.unit or not ns.unit.player then return end
    ns.PowerOrb.values.bottom:SetText(oUF.Tags.Methods["diablo:PowerOrbBottom"](ns.unit.player.__unit))
  end

  panel.updateElementHealthOrbTextureFilling = function()
    SetSelectedValue(panel.elementHealthOrbFillingTexture, panel.loadHealthOrbFillingTexture())
  end

  panel.updateElementPowerOrbTextureFilling = function()
    SetSelectedValue(panel.elementPowerOrbFillingTexture, panel.loadPowerOrbFillingTexture())
  end

  panel.updateElementHealthOrbFillingColorAuto = function()
    local value = panel.loadHealthOrbFillingColorAuto()
    panel.elementHealthOrbFillingColorAuto:SetChecked(value)
    --depending on color auto option we want to enable/disable the texture color picker
    if value then
      panel.elementHealthOrbFillingColor:Disable()
    else
      panel.elementHealthOrbFillingColor:Enable()
    end
  end

  panel.updateElementPowerOrbFillingColorAuto = function()
    local value = panel.loadPowerOrbFillingColorAuto()
    panel.elementPowerOrbFillingColorAuto:SetChecked(value)
    --depending on color auto option we want to enable/disable the texture color picker
    if value then
      panel.elementPowerOrbFillingColor:Disable()
    else
      panel.elementPowerOrbFillingColor:Enable()
    end
  end

  panel.updateElementHealthOrbTextureColor = function()
    local color = panel.loadHealthOrbFillingColor()
    panel.elementHealthOrbFillingColor.color:SetVertexColor(color.r,color.g,color.b)
  end

  panel.updateElementPowerOrbTextureColor = function()
    local color = panel.loadPowerOrbFillingColor()
    panel.elementPowerOrbFillingColor.color:SetVertexColor(color.r,color.g,color.b)
  end

  panel.updateElementHealthOrbModelEnable = function()
    local value = panel.loadHealthOrbModelEnable()
    panel.elementHealthOrbModelEnable:SetChecked(value)
    if value then
      panel.elementHealthOrbModelAnimation:Show()
      panel.elementHealthOrbModelAlpha:Show()
      panel.elementHealthOrbModelScale:Show()
      panel.elementHealthOrbModelPosX:Show()
      panel.elementHealthOrbModelPosY:Show()
      panel.elementHealthOrbModelRotation:Show()
      panel.elementHealthOrbModelZoom:Show()
      panel.elementHealthHighlightHeadline:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", 0, -270)
    else
      panel.elementHealthOrbModelAnimation:Hide()
      panel.elementHealthOrbModelAlpha:Hide()
      panel.elementHealthOrbModelScale:Hide()
      panel.elementHealthOrbModelPosX:Hide()
      panel.elementHealthOrbModelPosY:Hide()
      panel.elementHealthOrbModelRotation:Hide()
      panel.elementHealthOrbModelZoom:Hide()
      panel.elementHealthHighlightHeadline:SetPoint("TOPLEFT", panel.elementHealthModelHeadline, "BOTTOMLEFT", 0, -50)
    end
  end

  panel.updateElementPowerOrbModelEnable = function()
    local value = panel.loadPowerOrbModelEnable()
    panel.elementPowerOrbModelEnable:SetChecked(value)
    if value then
      panel.elementPowerOrbModelAnimation:Show()
      panel.elementPowerOrbModelAlpha:Show()
      panel.elementPowerOrbModelScale:Show()
      panel.elementPowerOrbModelPosX:Show()
      panel.elementPowerOrbModelPosY:Show()
      panel.elementPowerOrbModelRotation:Show()
      panel.elementPowerOrbModelZoom:Show()
      panel.elementPowerHighlightHeadline:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", 0, -270)
    else
      panel.elementPowerOrbModelAnimation:Hide()
      panel.elementPowerOrbModelAlpha:Hide()
      panel.elementPowerOrbModelScale:Hide()
      panel.elementPowerOrbModelPosX:Hide()
      panel.elementPowerOrbModelPosY:Hide()
      panel.elementPowerOrbModelRotation:Hide()
      panel.elementPowerOrbModelZoom:Hide()
      panel.elementPowerHighlightHeadline:SetPoint("TOPLEFT", panel.elementPowerModelHeadline, "BOTTOMLEFT", 0, -50)
    end
  end

  panel.updateElementHealthOrbModelAnimation = function()
    SetSelectedValue(panel.elementHealthOrbModelAnimation, panel.loadHealthOrbModelAnimation())
  end

  panel.updateElementPowerOrbModelAnimation = function()
    SetSelectedValue(panel.elementPowerOrbModelAnimation, panel.loadPowerOrbModelAnimation())
  end

  panel.updateElementHealthOrbModelAlpha = function()
    panel.elementHealthOrbModelAlpha:SetValue(panel.loadHealthOrbModelAlpha())
  end

  panel.updateElementPowerOrbModelAlpha = function()
    panel.elementPowerOrbModelAlpha:SetValue(panel.loadPowerOrbModelAlpha())
  end

  panel.updateElementHealthOrbModelScale = function()
    panel.elementHealthOrbModelScale:SetValue(panel.loadHealthOrbModelScale())
  end

  panel.updateElementPowerOrbModelScale = function()
    panel.elementPowerOrbModelScale:SetValue(panel.loadPowerOrbModelScale())
  end

  panel.updateElementHealthOrbModelPosX = function()
    panel.elementHealthOrbModelPosX:SetValue(panel.loadHealthOrbModelPosX())
  end

  panel.updateElementPowerOrbModelPosX = function()
    panel.elementPowerOrbModelPosX:SetValue(panel.loadPowerOrbModelPosX())
  end

  panel.updateElementHealthOrbModelPosY = function()
    panel.elementHealthOrbModelPosY:SetValue(panel.loadHealthOrbModelPosY())
  end

  panel.updateElementPowerOrbModelPosY = function()
    panel.elementPowerOrbModelPosY:SetValue(panel.loadPowerOrbModelPosY())
  end

  panel.updateElementHealthOrbModelRotation = function()
    panel.elementHealthOrbModelRotation:SetValue(panel.loadHealthOrbModelRotation())
  end

  panel.updateElementPowerOrbModelRotation = function()
    panel.elementPowerOrbModelRotation:SetValue(panel.loadPowerOrbModelRotation())
  end

  panel.updateElementHealthOrbModelZoom = function()
    panel.elementHealthOrbModelZoom:SetValue(panel.loadHealthOrbModelZoom())
  end

  panel.updateElementPowerOrbModelZoom = function()
    panel.elementPowerOrbModelZoom:SetValue(panel.loadPowerOrbModelZoom())
  end

  panel.updateElementHealthOrbHighlightAlpha = function()
    panel.elementHealthOrbHighlightAlpha:SetValue(panel.loadHealthOrbHighlightAlpha())
  end

  panel.updateElementPowerOrbHighlightAlpha = function()
    panel.elementPowerOrbHighlightAlpha:SetValue(panel.loadPowerOrbHighlightAlpha())
  end
  
  panel.updateElementHealthOrbGalaxiesAlpha = function()
    panel.elementHealthOrbGalaxiesAlpha:SetValue(panel.loadHealthOrbGalaxiesAlpha() or 0)
  end

  panel.updateElementPowerOrbGalaxiesAlpha = function()
    panel.elementPowerOrbGalaxiesAlpha:SetValue(panel.loadPowerOrbGalaxiesAlpha() or 0)
  end
  
  panel.updateElementHealthOrbBubblesAlpha = function()
    panel.elementHealthOrbBubblesAlpha:SetValue(panel.loadHealthOrbBubblesAlpha() or 0)
  end

  panel.updateElementPowerOrbBubblesAlpha = function()
    panel.elementPowerOrbBubblesAlpha:SetValue(panel.loadPowerOrbBubblesAlpha() or 0)
  end
  
  panel.updateElementHealthOrbSparkAlpha = function()
    panel.elementHealthOrbSparkAlpha:SetValue(panel.loadHealthOrbSparkAlpha())
  end

  panel.updateElementPowerOrbSparkAlpha = function()
    panel.elementPowerOrbSparkAlpha:SetValue(panel.loadPowerOrbSparkAlpha())
  end

  panel.updateElementHealthOrbValueHideEmpty = function()
    panel.elementHealthOrbValueHideEmpty:SetChecked(panel.loadHealthOrbValueHideEmpty())
  end

  panel.updateElementPowerOrbValueHideEmpty = function()
    panel.elementPowerOrbValueHideEmpty:SetChecked(panel.loadPowerOrbValueHideEmpty())
  end

  panel.updateElementHealthOrbValueHideFull = function()
    panel.elementHealthOrbValueHideFull:SetChecked(panel.loadHealthOrbValueHideFull())
  end

  panel.updateElementPowerOrbValueHideFull = function()
    panel.elementPowerOrbValueHideFull:SetChecked(panel.loadPowerOrbValueHideFull())
  end

  panel.updateElementHealthOrbValueAlpha = function()
    panel.elementHealthOrbValueAlpha:SetValue(panel.loadHealthOrbValueAlpha())
  end

  panel.updateElementPowerOrbValueAlpha = function()
    panel.elementPowerOrbValueAlpha:SetValue(panel.loadPowerOrbValueAlpha())
  end

  panel.updateElementHealthOrbValueTopColor = function()
    local color = panel.loadHealthOrbValueTopColor()
    panel.elementHealthOrbValueTopColor.color:SetVertexColor(color.r,color.g,color.b)
  end

  panel.updateElementPowerOrbValueTopColor = function()
    local color = panel.loadPowerOrbValueTopColor()
    panel.elementPowerOrbValueTopColor.color:SetVertexColor(color.r,color.g,color.b)
  end

  panel.updateElementHealthOrbValueBottomColor = function()
    local color = panel.loadHealthOrbValueBottomColor()
    panel.elementHealthOrbValueBottomColor.color:SetVertexColor(color.r,color.g,color.b)
  end

  panel.updateElementPowerOrbValueBottomColor = function()
    local color = panel.loadPowerOrbValueBottomColor()
    panel.elementPowerOrbValueBottomColor.color:SetVertexColor(color.r,color.g,color.b)
  end

  panel.updateElementHealthOrbValueTopTag = function()
    SetSelectedValue(panel.elementHealthOrbValueTopTag, panel.loadHealthOrbValueTopTag())
  end

  panel.updateElementPowerOrbValueTopTag = function()
    SetSelectedValue(panel.elementPowerOrbValueTopTag, panel.loadPowerOrbValueTopTag())
  end

  panel.updateElementHealthOrbValueBottomTag = function()
    SetSelectedValue(panel.elementHealthOrbValueBottomTag, panel.loadHealthOrbValueBottomTag())
  end

  panel.updateElementPowerOrbValueBottomTag = function()
    SetSelectedValue(panel.elementPowerOrbValueBottomTag, panel.loadPowerOrbValueBottomTag())
  end

  --SAVE DATA TO DATABASE

  panel.saveHealthOrbFillingTexture = function(value)
    db.char["HEALTH"].filling.texture = value
  end

  panel.savePowerOrbFillingTexture = function(value)
    db.char["POWER"].filling.texture = value
  end

  panel.saveHealthOrbFillingColorAuto = function(value)
    db.char["HEALTH"].filling.colorAuto = value
  end

  panel.savePowerOrbFillingColorAuto = function(value)
    db.char["POWER"].filling.colorAuto = value
  end

  panel.saveHealthOrbFillingColor = function(r,g,b)
    db.char["HEALTH"].filling.color.r = r
    db.char["HEALTH"].filling.color.g = g
    db.char["HEALTH"].filling.color.b = b
  end

  panel.savePowerOrbFillingColor = function(r,g,b)
    db.char["POWER"].filling.color.r = r
    db.char["POWER"].filling.color.g = g
    db.char["POWER"].filling.color.b = b
  end

  panel.saveHealthOrbModelEnable = function(value)
    db.char["HEALTH"].model.enable = value
  end

  panel.savePowerOrbModelEnable = function(value)
    db.char["POWER"].model.enable = value
  end

  panel.saveHealthOrbModelAnimation = function(value)
    db.char["HEALTH"].model.displayInfo = value
  end

  panel.savePowerOrbModelAnimation = function(value)
    db.char["POWER"].model.displayInfo = value
  end

  panel.saveHealthOrbModelAlpha = function(value)
    db.char["HEALTH"].model.alpha = value
  end

  panel.savePowerOrbModelAlpha = function(value)
    db.char["POWER"].model.alpha = value
  end

  panel.saveHealthOrbModelScale = function(value)
    db.char["HEALTH"].model.camDistanceScale = value
  end

  panel.savePowerOrbModelScale = function(value)
    db.char["POWER"].model.camDistanceScale = value
  end

  panel.saveHealthOrbModelPosX = function(value)
    db.char["HEALTH"].model.pos_x = value
  end

  panel.savePowerOrbModelPosX = function(value)
    db.char["POWER"].model.pos_x = value
  end

  panel.saveHealthOrbModelPosY = function(value)
    db.char["HEALTH"].model.pos_y = value
  end

  panel.savePowerOrbModelPosY = function(value)
    db.char["POWER"].model.pos_y = value
  end

  panel.saveHealthOrbModelRotation = function(value)
    db.char["HEALTH"].model.rotation = value
  end

  panel.savePowerOrbModelRotation = function(value)
    db.char["POWER"].model.rotation = value
  end

  panel.saveHealthOrbModelZoom = function(value)
    db.char["HEALTH"].model.portraitZoom = value
  end

  panel.savePowerOrbModelZoom = function(value)
    db.char["POWER"].model.portraitZoom = value
  end

  panel.saveHealthOrbHighlightAlpha = function(value)
    db.char["HEALTH"].highlight.alpha = value
  end

  panel.savePowerOrbHighlightAlpha = function(value)
    db.char["POWER"].highlight.alpha = value
  end

  panel.saveHealthOrbGalaxiesAlpha = function(value)
    db.char["HEALTH"].galaxies.alpha = value
  end

  panel.savePowerOrbGalaxiesAlpha = function(value)
    db.char["POWER"].galaxies.alpha = value
  end
  
  panel.saveHealthOrbBubblesAlpha = function(value)
    db.char["HEALTH"].bubbles.alpha = value
  end

  panel.savePowerOrbBubblesAlpha = function(value)
    db.char["POWER"].bubbles.alpha = value
  end
  
  panel.saveHealthOrbSparkAlpha = function(value)
    db.char["HEALTH"].spark.alpha = value
  end

  panel.savePowerOrbSparkAlpha = function(value)
    db.char["POWER"].spark.alpha = value
  end

  panel.saveHealthOrbValueHideEmpty = function(value)
    db.char["HEALTH"].value.hideOnEmpty = value
  end

  panel.savePowerOrbValueHideEmpty = function(value)
    db.char["POWER"].value.hideOnEmpty = value
  end

  panel.saveHealthOrbValueHideFull = function(value)
    db.char["HEALTH"].value.hideOnFull = value
  end

  panel.savePowerOrbValueHideFull = function(value)
    db.char["POWER"].value.hideOnFull = value
  end

  panel.saveHealthOrbValueAlpha = function(value)
    db.char["HEALTH"].value.alpha = value
  end

  panel.savePowerOrbValueAlpha = function(value)
    db.char["POWER"].value.alpha = value
  end

  panel.saveHealthOrbValueTopColor = function(r,g,b)
    db.char["HEALTH"].value.top.color.r = r
    db.char["HEALTH"].value.top.color.g = g
    db.char["HEALTH"].value.top.color.b = b
  end

  panel.savePowerOrbValueTopColor = function(r,g,b)
    db.char["POWER"].value.top.color.r = r
    db.char["POWER"].value.top.color.g = g
    db.char["POWER"].value.top.color.b = b
  end

  panel.saveHealthOrbValueBottomColor = function(r,g,b)
    db.char["HEALTH"].value.bottom.color.r = r
    db.char["HEALTH"].value.bottom.color.g = g
    db.char["HEALTH"].value.bottom.color.b = b
  end

  panel.savePowerOrbValueBottomColor = function(r,g,b)
    db.char["POWER"].value.bottom.color.r = r
    db.char["POWER"].value.bottom.color.g = g
    db.char["POWER"].value.bottom.color.b = b
  end

  panel.saveHealthOrbValueTopTag = function(value)
    db.char["HEALTH"].value.top.tag = value
  end

  panel.savePowerOrbValueTopTag = function(value)
    db.char["POWER"].value.top.tag = value
  end

  panel.saveHealthOrbValueBottomTag = function(value)
    db.char["HEALTH"].value.bottom.tag = value
  end

  panel.savePowerOrbValueBottomTag = function(value)
    db.char["POWER"].value.bottom.tag = value
  end

  --LOAD DATA FROM DATABASE

  panel.loadHealthOrbFillingTexture = function()
    return db.char["HEALTH"].filling.texture
  end

  panel.loadPowerOrbFillingTexture = function()
    return db.char["POWER"].filling.texture
  end

  panel.loadHealthOrbFillingColorAuto = function()
    return db.char["HEALTH"].filling.colorAuto
  end

  panel.loadPowerOrbFillingColorAuto = function()
    return db.char["POWER"].filling.colorAuto
  end

  panel.loadHealthOrbFillingColor = function()
    return db.char["HEALTH"].filling.color
  end

  panel.loadPowerOrbFillingColor = function()
    return db.char["POWER"].filling.color
  end

  panel.loadHealthOrbModelEnable = function()
    return db.char["HEALTH"].model.enable
  end

  panel.loadPowerOrbModelEnable = function()
    return db.char["POWER"].model.enable
  end

  panel.loadHealthOrbModelAnimation = function()
    return db.char["HEALTH"].model.displayInfo
  end

  panel.loadPowerOrbModelAnimation = function()
    return db.char["POWER"].model.displayInfo
  end

  panel.loadHealthOrbModelAlpha = function()
    return db.char["HEALTH"].model.alpha
  end

  panel.loadPowerOrbModelAlpha = function()
    return db.char["POWER"].model.alpha
  end

  panel.loadHealthOrbModelScale = function()
    return db.char["HEALTH"].model.camDistanceScale
  end

  panel.loadPowerOrbModelScale = function()
    return db.char["POWER"].model.camDistanceScale
  end

  panel.loadHealthOrbModelPosX = function()
    return db.char["HEALTH"].model.pos_x
  end

  panel.loadPowerOrbModelPosX = function()
    return db.char["POWER"].model.pos_x
  end

  panel.loadHealthOrbModelPosY = function()
    return db.char["HEALTH"].model.pos_y
  end

  panel.loadPowerOrbModelPosY = function()
    return db.char["POWER"].model.pos_y
  end

  panel.loadHealthOrbModelRotation = function()
    return db.char["HEALTH"].model.rotation
  end

  panel.loadPowerOrbModelRotation = function()
    return db.char["POWER"].model.rotation
  end

  panel.loadHealthOrbModelZoom = function()
    return db.char["HEALTH"].model.portraitZoom
  end

  panel.loadPowerOrbModelZoom = function()
    return db.char["POWER"].model.portraitZoom
  end

  panel.loadHealthOrbHighlightAlpha = function()
    return db.char["HEALTH"].highlight.alpha
  end

  panel.loadPowerOrbHighlightAlpha = function()
    return db.char["POWER"].highlight.alpha
  end
  
  panel.loadHealthOrbGalaxiesAlpha = function()
    return db.char["HEALTH"].galaxies.alpha or 0
  end

  panel.loadPowerOrbGalaxiesAlpha = function()
    return db.char["POWER"].galaxies.alpha or 0
  end
  
  panel.loadHealthOrbBubblesAlpha = function()
    return db.char["HEALTH"].bubbles.alpha or 0
  end

  panel.loadPowerOrbBubblesAlpha = function()
    return db.char["POWER"].bubbles.alpha or 0
  end
  
  panel.loadHealthOrbSparkAlpha = function()
    return db.char["HEALTH"].spark.alpha
  end

  panel.loadPowerOrbSparkAlpha = function()
    return db.char["POWER"].spark.alpha
  end

  panel.loadHealthOrbValueHideEmpty = function()
    return db.char["HEALTH"].value.hideOnEmpty
  end

  panel.loadPowerOrbValueHideEmpty = function()
    return db.char["POWER"].value.hideOnEmpty
  end

  panel.loadHealthOrbValueHideFull = function()
    return db.char["HEALTH"].value.hideOnFull
  end

  panel.loadPowerOrbValueHideFull = function()
    return db.char["POWER"].value.hideOnFull
  end

  panel.loadHealthOrbValueAlpha = function()
    return db.char["HEALTH"].value.alpha
  end

  panel.loadPowerOrbValueAlpha = function()
    return db.char["POWER"].value.alpha
  end

  panel.loadHealthOrbValueTopColor = function()
    return db.char["HEALTH"].value.top.color
  end

  panel.loadPowerOrbValueTopColor = function()
    return db.char["POWER"].value.top.color
  end

  panel.loadHealthOrbValueBottomColor = function()
    return db.char["HEALTH"].value.bottom.color
  end

  panel.loadPowerOrbValueBottomColor = function()
    return db.char["POWER"].value.bottom.color
  end

  panel.loadHealthOrbValueTopTag = function()
    return db.char["HEALTH"].value.top.tag
  end

  panel.loadPowerOrbValueTopTag = function()
    return db.char["POWER"].value.top.tag
  end

  panel.loadHealthOrbValueBottomTag = function()
    return db.char["HEALTH"].value.bottom.tag
  end

  panel.loadPowerOrbValueBottomTag = function()
    return db.char["POWER"].value.bottom.tag
  end

  panel.updatePanelView = function()

    if InCombatLockdown() then return end

    panel.updateElementHealthOrbTextureFilling()
    panel.updateElementPowerOrbTextureFilling()
    panel.updateElementHealthOrbFillingColorAuto()
    panel.updateElementPowerOrbFillingColorAuto()
    panel.updateElementHealthOrbTextureColor()
    panel.updateElementPowerOrbTextureColor()
    panel.updateElementHealthOrbModelEnable()
    panel.updateElementPowerOrbModelEnable()
    panel.updateElementHealthOrbModelAnimation()
    panel.updateElementPowerOrbModelAnimation()
    panel.updateElementHealthOrbModelAlpha()
    panel.updateElementPowerOrbModelAlpha()
    panel.updateElementHealthOrbModelScale()
    panel.updateElementPowerOrbModelScale()
    panel.updateElementHealthOrbModelPosX()
    panel.updateElementPowerOrbModelPosX()
    panel.updateElementHealthOrbModelPosY()
    panel.updateElementPowerOrbModelPosY()
    panel.updateElementHealthOrbModelRotation()
    panel.updateElementPowerOrbModelRotation()
    panel.updateElementHealthOrbModelZoom()
    panel.updateElementPowerOrbModelZoom()
    panel.updateElementHealthOrbHighlightAlpha()
    panel.updateElementPowerOrbHighlightAlpha()
    panel.updateElementHealthOrbGalaxiesAlpha()
    panel.updateElementPowerOrbGalaxiesAlpha()
    panel.updateElementHealthOrbBubblesAlpha()
    panel.updateElementPowerOrbBubblesAlpha()
    panel.updateElementHealthOrbSparkAlpha()
    panel.updateElementPowerOrbSparkAlpha()
    panel.updateElementHealthOrbValueHideEmpty()
    panel.updateElementPowerOrbValueHideEmpty()
    panel.updateElementHealthOrbValueHideFull()
    panel.updateElementPowerOrbValueHideFull()
    panel.updateElementHealthOrbValueAlpha()
    panel.updateElementPowerOrbValueAlpha()
    panel.updateElementHealthOrbValueTopColor()
    panel.updateElementPowerOrbValueTopColor()
    panel.updateElementHealthOrbValueBottomColor()
    panel.updateElementPowerOrbValueBottomColor()
    panel.updateElementHealthOrbValueTopTag()
    panel.updateElementPowerOrbValueTopTag()
    panel.updateElementHealthOrbValueBottomTag()
    panel.updateElementPowerOrbValueBottomTag()

  end

  panel.updateOrbView = function()

    if InCombatLockdown() then return end

    panel.updateHealthOrbFillingTexture()
    panel.updatePowerOrbFillingTexture()
    panel.updateHealthOrbFillingColor()
    panel.updatePowerOrbFillingColor()
    --important! since auto coloring rewrites the color it has to be called after filling color
    panel.updateHealthOrbFillingColorAuto()
    panel.updatePowerOrbFillingColorAuto()
    panel.updateHealthOrbModelEnable()
    panel.updatePowerOrbModelEnable()
    panel.updateHealthOrbModelAnimation()
    panel.updatePowerOrbModelAnimation()
    panel.updateHealthOrbModelAlpha()
    panel.updatePowerOrbModelAlpha()
    panel.updateHealthOrbModelScale()
    panel.updatePowerOrbModelScale()
    panel.updateHealthOrbModelPosX()
    panel.updatePowerOrbModelPosX()
    panel.updateHealthOrbModelPosY()
    panel.updatePowerOrbModelPosY()
    panel.updateHealthOrbModelRotation()
    panel.updatePowerOrbModelRotation()
    panel.updateHealthOrbModelZoom()
    panel.updatePowerOrbModelZoom()
    panel.updateHealthOrbHighlightAlpha()
    panel.updatePowerOrbHighlightAlpha()
    panel.updateHealthOrbGalaxiesAlpha()
    panel.updatePowerOrbGalaxiesAlpha()
    panel.updateHealthOrbBubblesAlpha()
    panel.updatePowerOrbBubblesAlpha()
    panel.updateHealthOrbSparkAlpha()
    panel.updatePowerOrbSparkAlpha()
    panel.updateHealthOrbValueAlpha()
    panel.updatePowerOrbValueAlpha()
    panel.updateHealthOrbValueTopColor()
    panel.updatePowerOrbValueTopColor()
    panel.updateHealthOrbValueBottomColor()
    panel.updatePowerOrbValueBottomColor()
    panel.updateHealthOrbValueTopTag()
    panel.updatePowerOrbValueTopTag()
    panel.updateHealthOrbValueBottomTag()
    panel.updatePowerOrbValueBottomTag()

    panel.updatePanelView()

  end

  --FIX THE ORB DISPLAY ON NON-FULLY-FILLED ORBS

  -- Fill empty orbs during preview; ForceUpdate restores live values on close.

  function panel:Enable()
    self.eventHelper:RegisterUnitEvent("UNIT_HEALTH", "player")
    self.eventHelper:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    self.eventHelper:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    self.eventHelper:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    self.eventHelper:SetScript("OnEvent", function(self) self:SetOrbsToMax() end)
    self.eventHelper:SetOrbsToMax()
  end

  function panel:Disable()
    self.eventHelper:UnregisterEvent("UNIT_HEALTH")
    self.eventHelper:UnregisterEvent("UNIT_POWER_UPDATE")
    self.eventHelper:UnregisterEvent("UNIT_POWER_FREQUENT")
    self.eventHelper:UnregisterEvent("UNIT_DISPLAYPOWER")
    self.eventHelper:SetScript("OnEvent", nil)
    self.eventHelper:SetOrbsToDefault()
    --reset the focus to the last active chatwindow
    ChatEdit_FocusActiveWindow()
  end

  do
    local eventHelper = CF("Frame")
    function eventHelper:SetOrbsToMax()
      if not ns.HealthOrb or not ns.HealthOrb.fill or not ns.PowerOrb or not ns.PowerOrb.fill then return end
      local hbar, pbar = ns.HealthOrb.fill, ns.PowerOrb.fill
      local hval, pval = ns.HealthOrb.values, ns.PowerOrb.values
      local hmin, hmax = hbar:GetMinMaxValues()
      local pmin, pmax = pbar:GetMinMaxValues()
      hbar:SetValue(hmax)
      pbar:SetValue(pmax)
      if hval then hval:Show() end
      if pval then pval:Show() end
    end
    function eventHelper:SetOrbsToDefault()
      if not ns.HealthOrb or not ns.HealthOrb.fill or not ns.PowerOrb or not ns.PowerOrb.fill then return end
      local hbar, pbar = ns.HealthOrb.fill, ns.PowerOrb.fill
      local hval, pval = ns.HealthOrb.values, ns.PowerOrb.values
      hbar:ForceUpdate()
      pbar:ForceUpdate()
    end
    panel.eventHelper = eventHelper
    panel:HookScript("OnShow", function(self) self:Enable() end)
    panel:HookScript("OnHide", function(self) self:Disable() end)
  end