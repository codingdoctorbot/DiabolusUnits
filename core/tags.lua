  local addon, ns = ...

  local oUF = ns.oUF or oUF
  local Secrets = ns.Secrets

  local cfg = ns.cfg
  local db = ns.db
  local func = ns.func

  local format, floor = format, floor

  -- Pre-allocated color tables (avoid per-tag-call GC pressure)
  local TAG_COLOR_WHITE = {r = 1, g = 1, b = 1}
  local TAG_COLOR_GREY  = {r = 0.5, g = 0.5, b = 0.5}

  -- Cache TRP3 compat function once at load
  local IsAddOnLoadedCompat = IsAddOnLoaded or (C_AddOns and C_AddOns.IsAddOnLoaded) or function() return false end
  local hasTRP3 = nil

  -- TAGS

  local function RGBPercToHex(r, g, b)
    r = r <= 1 and r >= 0 and r or 1
    g = g <= 1 and g >= 0 and g or 1
    b = b <= 1 and b >= 0 and b or 1
    return format("%02x%02x%02x", r*255, g*255, b*255)
  end

  oUF.Tags.Methods["diablo:color"] = function(unit)
    local color = TAG_COLOR_WHITE
    if Secrets.Bool(UnitIsDeadOrGhost, unit) or not Secrets.Bool(UnitIsConnected, unit) then
      color = TAG_COLOR_GREY
    elseif Secrets.Bool(UnitIsPlayer, unit) then
      local r, g, b = Secrets.UnitClassColor(unit)
      if r and g and b then
        return RGBPercToHex(r, g, b)
      end
    elseif Secrets.UnitIsUnit(unit, "target") and Secrets.Bool(UnitIsTapDenied, "target") then
      color = TAG_COLOR_GREY
    else
      local reaction = Secrets.Number(UnitReaction(unit, "player"))
      color = reaction and FACTION_BAR_COLORS[reaction]
    end
    if color then
      return RGBPercToHex(color.r,color.g,color.b)
    else
      return "ffffff"
    end
  end

  oUF.Tags.Methods["diablo:colorsimple"] = function(unit)
    if Secrets.Bool(UnitIsDeadOrGhost, unit) or not Secrets.Bool(UnitIsConnected, unit) then
      return RGBPercToHex(TAG_COLOR_GREY.r, TAG_COLOR_GREY.g, TAG_COLOR_GREY.b)
    end
    return RGBPercToHex(TAG_COLOR_WHITE.r, TAG_COLOR_WHITE.g, TAG_COLOR_WHITE.b)
  end

  oUF.Tags.Methods["diablo:name"] = function(unit)
    if unit == "target" and cfg and cfg.units and cfg.units.target and cfg.units.target.details and cfg.units.target.details.showName == false then
      return ""
    end
    local color = oUF.Tags.Methods["diablo:color"](unit)
    if hasTRP3 == nil then hasTRP3 = IsAddOnLoadedCompat("Totalrp3") and true or false end
    local fullName
    if hasTRP3 and TRP3_API and TRP3_API.utils and TRP3_API.utils.str then
      local ok, unitID = pcall(TRP3_API.utils.str.getUnitID, unit)
      if ok and unitID and not Secrets.IsSecret(unitID) and TRP3_API.chat then
        fullName = TRP3_API.chat.getFullnameForUnitUsingChatMethod(unitID)
      end
    end
    local name = fullName or UnitName(unit) or ""
    return Secrets.Wrap(name, "|cff"..color, "|r")
  end
  oUF.Tags.Events["diablo:name"] = "UNIT_NAME_UPDATE UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --status tag
  oUF.Tags.Methods["diablo:status"] = function(unit, rolf)
    local color = oUF.Tags.Methods["diablo:colorsimple"](unit)
    local status
    if Secrets.Bool(UnitIsDeadOrGhost, unit) then
      status = "Dead"
    elseif not Secrets.Bool(UnitIsConnected, unit) then
      status = "Offline"
    end
    return "|cff"..color..(status or "").."|r"
  end
  oUF.Tags.Events["diablo:status"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --hp value
  oUF.Tags.Methods["diablo:hpval"] = function(unit)
    local color = oUF.Tags.Methods["diablo:colorsimple"](unit)
    if Secrets.Bool(UnitIsDeadOrGhost, unit) then
      return "|cff"..color.."Dead|r"
    elseif not Secrets.Bool(UnitIsConnected, unit) then
      return "|cff"..color.."Offline|r"
    else
      local cur = func.numFormat(UnitHealth(unit) or 0)
      local max = oUF.Tags.Methods["maxshp"](unit)
      local joined = Secrets.Join(" / ", cur, max)
      return Secrets.Wrap(joined, "|cff"..color, "|r")
    end
  end
  oUF.Tags.Events["diablo:hpval"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --power value
  oUF.Tags.Methods["diablo:ppval"] = function(unit)
    local cur = func.numFormat(UnitPower(unit) or 0)
    local max = oUF.Tags.Methods["maxspp"](unit)
    return Secrets.Join(" / ", cur, max)
  end
  oUF.Tags.Events["diablo:ppval"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER"

  oUF.Tags.Methods["diablo:misshp"] = function(unit)
    local color = oUF.Tags.Methods["diablo:colorsimple"](unit)
    if Secrets.Bool(UnitIsDeadOrGhost, unit) then
      return "|cff"..color.."Dead|r"
    elseif not Secrets.Bool(UnitIsConnected, unit) then
      return "|cff"..color.."Offline|r"
    else
      local max, min = Secrets.Number(UnitHealthMax(unit)), Secrets.Number(UnitHealth(unit))
      if max and min then
        if max - min > 0 then
          return "|cff"..color.."-"..func.numFormat(max - min).."|r"
        end
        return ""
      elseif UnitHealthMissing then
        local missing = Secrets.FormatMissing(UnitHealthMissing(unit))
        -- a secret string cannot be compared; TruncateWhenZero already gives "" at full health
        if Secrets.IsSecret(missing) then
          -- TruncateWhenZero gives the bare number: add the sign
          return Secrets.Wrap(missing, "|cff"..color.."-", "|r")
        elseif Secrets.Present(missing) and missing ~= "" then
          -- a plain value comes back from FormatMissing already signed
          return "|cff"..color..missing.."|r"
        end
      end
    end
    return ""
  end
  oUF.Tags.Events["diablo:misshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  oUF.Tags.Methods["diablo:raidhp"] = function(unit, rolf)
    local color = oUF.Tags.Methods["diablo:color"](unit)
    if Secrets.Bool(UnitIsDeadOrGhost, unit) or not Secrets.Bool(UnitIsConnected, unit) then
      local name = UnitName(rolf or unit) or ""
      return Secrets.Wrap(name, "|cff"..color, "|r")
    else
      local max, min = Secrets.Number(UnitHealthMax(unit)), Secrets.Number(UnitHealth(unit))
      if max and min then
        if max - min > 0 then
          return "|cffffffff-"..func.numFormat(max - min).."|r"
        end
      end
      local name = UnitName(rolf or unit) or ""
      return Secrets.Wrap(name, "|cff"..color, "|r")
    end
  end
  oUF.Tags.Events["diablo:raidhp"] = "UNIT_NAME_UPDATE UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  oUF.Tags.Methods["diablo:altbosspower"] = function(unit)
    local altIndex = ALTERNATE_POWER_INDEX or (Enum and Enum.PowerType and Enum.PowerType.Alternate) or 10
    local cur = Secrets.Number(UnitPower(unit, altIndex))
    local max = Secrets.Number(UnitPowerMax(unit, altIndex))
    local color = "0099ff"
    if(cur and max and max > 0 and not Secrets.Bool(UnitIsDeadOrGhost, unit)) then
      return "|cff"..color..("%s%%"):format(floor(cur/max*100)).."|cff666666 / |r"
    end
  end
  oUF.Tags.Events["diablo:altbosspower"] = "UNIT_POWER_UPDATE"

  oUF.Tags.Methods["diablo:altpower"] = function(unit)
    local altIndex = ALTERNATE_POWER_INDEX or (Enum and Enum.PowerType and Enum.PowerType.Alternate) or 10
    local cur = Secrets.Number(UnitPower(unit, altIndex))
    local max = Secrets.Number(UnitPowerMax(unit, altIndex))
    if cur and cur > 0 and max and max > 0 then
      return floor(cur).." / "..floor(max)
    end
  end
  oUF.Tags.Events["diablo:altpower"] = "UNIT_POWER_UPDATE"

  --boss health value
  oUF.Tags.Methods["diablo:bosshp"] = function(unit)
    local val = oUF.Tags.Methods["perhp"](unit)
    return val or ""
  end
  oUF.Tags.Events["diablo:bosshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_TARGETABLE_CHANGED"
  
  --boss power value
  oUF.Tags.Methods["diablo:bosspp"] = function(unit)
    if Secrets.Bool(UnitIsDeadOrGhost, unit) then return "" end
    local altIndex = ALTERNATE_POWER_INDEX or (Enum and Enum.PowerType and Enum.PowerType.Alternate) or 10
    local pp_max = Secrets.Number(UnitPowerMax(unit))
    local ap_max = Secrets.Number(UnitPowerMax(unit, altIndex))
    if not pp_max then
      local perpp = oUF.Tags.Methods["perpp"](unit)
      return Secrets.Wrap(perpp, "", "%")
    end
    local str = ""
    if pp_max > 0 then
      local perpp = oUF.Tags.Methods["perpp"](unit)
      if Secrets.IsSecret(perpp) then
        return Secrets.Wrap(perpp, "", "%")
      end
      str = str..perpp.."%"
    end
    local color = "0099ff"
    if pp_max > 0 and ap_max and ap_max > 0 then
      str = str.." ("
    end
    if ap_max and ap_max > 0 then
      local ap_cur = Secrets.Number(UnitPower(unit, altIndex)) or 0
      str = str.."|cff"..color..("%s%%"):format(floor(ap_cur/ap_max*100)).."|r"
    end
    if pp_max > 0 and ap_max and ap_max > 0 then
      str = str..")"
    end
    return str or ""
  end
  oUF.Tags.Events["diablo:bosspp"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_TARGETABLE_CHANGED"

  --topdefhp - the top healthorb value
  oUF.Tags.Methods["topdefhp"] = function(unit)
    local val = oUF.Tags.Methods["perhp"](unit)
    return val or ""
  end
  oUF.Tags.Events["topdefhp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --botdefhp - the bottom healthorb value
  oUF.Tags.Methods["botdefhp"] = function(unit)
    if Secrets.Bool(UnitIsDeadOrGhost, unit) then
      return "Dead"
    elseif not Secrets.Bool(UnitIsConnected, unit) then
      return "Offline"
    end
    local val = oUF.Tags.Methods["curhp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["botdefhp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --topdefpp - the top powerorb value
  oUF.Tags.Methods["topdefpp"] = function(unit)
    local powertype = Secrets.String(select(2, UnitPowerType(unit)))
    local val
    if powertype ~= "MANA" then
      val = oUF.Tags.Methods["curpp"](unit)
      val = func.numFormat(val)
    else
      val = oUF.Tags.Methods["perpp"](unit)
    end
    return val or ""
  end
  oUF.Tags.Events["topdefpp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  --botdefpp - the bottom powerorb value
  oUF.Tags.Methods["botdefpp"] = function(unit)
    local powertype = Secrets.String(select(2, UnitPowerType(unit)))
    local val
    if powertype ~= "MANA" then
      val = oUF.Tags.Methods["perpp"](unit)
    else
      val = oUF.Tags.Methods["curpp"](unit)
      val = func.numFormat(val)
    end
    return val or ""
  end
  oUF.Tags.Events["botdefpp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  --curshp - curhp short
  oUF.Tags.Methods["curshp"] = function(unit)
    local val = oUF.Tags.Methods["curhp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["curshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --maxshp - maxhp short
  oUF.Tags.Methods["maxshp"] = function(unit)
    local val = oUF.Tags.Methods["maxhp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["maxshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --cmaxhp - curhp / maxhp
  oUF.Tags.Methods["cmaxhp"] = function(unit)
    local cur = oUF.Tags.Methods["curhp"](unit)
    local max = oUF.Tags.Methods["maxhp"](unit)
    return Secrets.Join("/", cur, max)
  end
  oUF.Tags.Events["cmaxhp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --cmaxshp - curhp / maxhp short
  oUF.Tags.Methods["cmaxshp"] = function(unit)
    local cur = oUF.Tags.Methods["curhp"](unit)
    local max = oUF.Tags.Methods["maxhp"](unit)
    return Secrets.Join("/", func.numFormat(cur), func.numFormat(max))
  end
  oUF.Tags.Events["cmaxshp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --curspp - curpp short
  oUF.Tags.Methods["curspp"] = function(unit)
    local val = oUF.Tags.Methods["curpp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["curspp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  --maxspp - maxpp short
  oUF.Tags.Methods["maxspp"] = function(unit)
    local val = oUF.Tags.Methods["maxpp"](unit)
    val = func.numFormat(val)
    return val or ""
  end
  oUF.Tags.Events["maxspp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  --cmaxpp - curpp / maxpp
  oUF.Tags.Methods["cmaxpp"] = function(unit)
    local cur = oUF.Tags.Methods["curpp"](unit)
    local max = oUF.Tags.Methods["maxpp"](unit)
    return Secrets.Join("/", cur, max)
  end
  oUF.Tags.Events["cmaxpp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  --cmaxspp - curpp / maxpp short
  oUF.Tags.Methods["cmaxspp"] = function(unit)
    local cur = oUF.Tags.Methods["curpp"](unit)
    local max = oUF.Tags.Methods["maxpp"](unit)
    return Secrets.Join("/", func.numFormat(cur), func.numFormat(max))
  end
  oUF.Tags.Events["cmaxspp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  --perphp - hp percent with %
  oUF.Tags.Methods["perphp"] = function(unit)
    if Secrets.Bool(UnitIsDeadOrGhost, unit) then
      return "Dead"
    elseif not Secrets.Bool(UnitIsConnected, unit) then
      return "Offline"
    else
      local perhp = oUF.Tags.Methods["perhp"](unit)
      return Secrets.Wrap(perhp, "", "%")
    end
  end
  oUF.Tags.Events["perphp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

  --perppp - pp percent with %
  oUF.Tags.Methods["perppp"] = function(unit)
    local perpp = oUF.Tags.Methods["perpp"](unit)
    return Secrets.Wrap(perpp, "", "%")
  end
  oUF.Tags.Events["perppp"] = "UNIT_DISPLAYPOWER UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_CONNECTION"

  --HealthOrbTop
  oUF.Tags.Methods["diablo:HealthOrbTop"] = function(unit)
    if db.char["HEALTH"].value.top.tag == "null" then return "" end
    local methodName = db.char["HEALTH"].value.top.tag.."hp"
    return oUF.Tags.Methods[methodName] and oUF.Tags.Methods[methodName](unit) or ""
  end

  --HealthOrbBottom
  oUF.Tags.Methods["diablo:HealthOrbBottom"] = function(unit)
    if db.char["HEALTH"].value.bottom.tag == "null" then return "" end
    local methodName = db.char["HEALTH"].value.bottom.tag.."hp"
    return oUF.Tags.Methods[methodName] and oUF.Tags.Methods[methodName](unit) or ""
  end

  --PowerOrbTop
  oUF.Tags.Methods["diablo:PowerOrbTop"] = function(unit)
    if db.char["POWER"].value.top.tag == "null" then return "" end
    local methodName = db.char["POWER"].value.top.tag.."pp"
    return oUF.Tags.Methods[methodName] and oUF.Tags.Methods[methodName](unit) or ""
  end

  --PowerOrbBottom
  oUF.Tags.Methods["diablo:PowerOrbBottom"] = function(unit)
    if db.char["POWER"].value.bottom.tag == "null" then return "" end
    local methodName = db.char["POWER"].value.bottom.tag.."pp"
    return oUF.Tags.Methods[methodName] and oUF.Tags.Methods[methodName](unit) or ""
  end

