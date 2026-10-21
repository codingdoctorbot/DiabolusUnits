--  Roth_UI - WoW Forever (16001) Secret Value & Curve Compatibility Layer
--  Provides safe helpers for WoW Forever / Midnight Secret Values (issecretvalue),
--  LuaCurveObject / LuaColorCurveObject evaluation (C_CurveUtil),
--  DurationObject helpers (C_UnitAuras.GetAuraDuration, UnitCastingDuration),
--  and secret-safe string/number formatting.

local addon, ns = ...

local Secrets = {}
ns.Secrets = Secrets

local type = type
local pcall = pcall
local tostring = tostring
local math_floor = math.floor
local issecretvalue = _G.issecretvalue

-- Probe whether a value is a restricted secret value.
function Secrets.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Presence check that never tests truthiness on a secret value.
function Secrets.Present(v)
    return type(v) ~= "nil"
end

-- Returns v if v is a plain (non-secret) Lua number, or nil if secret/non-number.
function Secrets.Number(v)
    if Secrets.IsSecret(v) or type(v) ~= "number" then
        return nil
    end
    return v
end

-- Returns v if v is a plain (non-secret) Lua string, or nil if secret/non-string.
function Secrets.String(v)
    if Secrets.IsSecret(v) or type(v) ~= "string" then
        return nil
    end
    return v
end

-- Returns a plain boolean for v, or defaultIfSecret (defaults to false) if v is secret.
function Secrets.Boolean(v, defaultIfSecret)
    if type(v) == "nil" then
        return false
    end
    if Secrets.IsSecret(v) then
        if defaultIfSecret ~= nil then
            return defaultIfSecret
        end
        return false
    end
    return v == true or v == 1
end

-- Calls fn(...) safely; returns nil if it errors or returns a secret value,
-- or true/false if the return value is plain.
function Secrets.Bool(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, v = pcall(fn, ...)
    if not ok or Secrets.IsSecret(v) then
        return nil
    end
    return v and true or false
end

-- Secret-safe UnitExists check: if UnitExists returns a secret boolean, the unit exists.
function Secrets.UnitExists(unit)
    if Secrets.IsSecret(unit) or type(unit) ~= "string" or unit == "" then
        return false
    end
    local ex = UnitExists(unit)
    if Secrets.IsSecret(ex) then
        return true
    end
    return ex == true or ex == 1
end

-- Secret-safe UnitIsUnit check.
function Secrets.UnitIsUnit(u1, u2)
    if Secrets.IsSecret(u1) or Secrets.IsSecret(u2) then
        return false
    end
    if type(u1) ~= "string" or type(u2) ~= "string" then
        return false
    end
    if u1 == u2 then
        return true
    end
    local same = UnitIsUnit(u1, u2)
    if Secrets.IsSecret(same) then
        return false
    end
    return same == true or same == 1
end

-- Secret-safe UnitGUID check: returns nil if secret so callers don't compare or key tables with it.
function Secrets.UnitGUID(unit)
    if Secrets.IsSecret(unit) or type(unit) ~= "string" then
        return nil
    end
    local guid = UnitGUID(unit)
    if Secrets.IsSecret(guid) or type(guid) ~= "string" then
        return nil
    end
    return guid
end

-- Secret-safe number formatting matching Roth_UI's numFormat.
-- When v is secret, delegates to AbbreviateLargeNumbers (AllowedWhenTainted) or returns v as-is
-- so FontString:SetText / SetFormattedText can render it in C++.
function Secrets.Abbreviate(v)
    if type(v) == "nil" then
        return ""
    end
    if not Secrets.IsSecret(v) then
        if type(v) ~= "number" then
            return tostring(v)
        end
        if v > 1E10 then
            return (math_floor(v / 1E9)) .. "b"
        elseif v > 1E9 then
            return (math_floor((v / 1E9) * 10) / 10) .. "b"
        elseif v > 1E7 then
            return (math_floor(v / 1E6)) .. "m"
        elseif v > 1E6 then
            return (math_floor((v / 1E6) * 10) / 10) .. "m"
        elseif v > 1E4 then
            return (math_floor(v / 1E3)) .. "k"
        elseif v > 1E3 then
            return (math_floor((v / 1E3) * 10) / 10) .. "k"
        else
            return tostring(v)
        end
    end
    if type(AbbreviateLargeNumbers) == "function" then
        return AbbreviateLargeNumbers(v)
    end
    return v
end

-- Missing health/power string formatting without Lua comparison on secret values.
function Secrets.FormatMissing(v)
    if type(v) == "nil" then
        return ""
    end
    if not Secrets.IsSecret(v) then
        if type(v) == "number" and v > 0 then
            return "-" .. Secrets.Abbreviate(v)
        end
        return ""
    end
    if C_StringUtil and type(C_StringUtil.TruncateWhenZero) == "function" then
        return C_StringUtil.TruncateWhenZero(v)
    end
    return ""
end

-- 0..1 -> 0..100 linear curve for UnitHealthPercent / UnitPowerPercent.
local percentCurve
function Secrets.PercentCurve()
    if percentCurve then
        return percentCurve
    end
    if _G.CurveConstants and _G.CurveConstants.ScaleTo100 then
        percentCurve = _G.CurveConstants.ScaleTo100
        return percentCurve
    end
    if C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function" then
        percentCurve = C_CurveUtil.CreateCurve()
        percentCurve:SetType(Enum.LuaCurveType.Linear)
        percentCurve:AddPoint(0, 0)
        percentCurve:AddPoint(1, 100)
    end
    return percentCurve
end

-- Step curve: returns 1 when health <= 25%, 0 when > 25%.
local lowHealthCurve
function Secrets.LowHealthCurve()
    if not lowHealthCurve and C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function" then
        lowHealthCurve = C_CurveUtil.CreateCurve()
        lowHealthCurve:SetType(Enum.LuaCurveType.Step)
        lowHealthCurve:AddPoint(0, 1)
        lowHealthCurve:AddPoint(0.251, 0)
    end
    return lowHealthCurve
end

-- Linear highlight alpha curve: 0 at 0%, 0.08 at 50%, 0 at 100% (matches Roth_UI bar highlight math).
local highlightAlphaCurve
function Secrets.HighlightAlphaCurve()
    if not highlightAlphaCurve and C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function" then
        highlightAlphaCurve = C_CurveUtil.CreateCurve()
        highlightAlphaCurve:SetType(Enum.LuaCurveType.Linear)
        highlightAlphaCurve:AddPoint(0, 0)
        highlightAlphaCurve:AddPoint(0.5, 0.08)
        highlightAlphaCurve:AddPoint(1, 0)
    end
    return highlightAlphaCurve
end

-- Step curves per combo point orb index (1..maxPoints).
local comboCurves = {}
function Secrets.ComboOrbCurve(orbIndex, maxPoints)
    maxPoints = maxPoints or 5
    local key = orbIndex .. ":" .. maxPoints
    local curve = comboCurves[key]
    if not curve and C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function" then
        curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, 0)
        curve:AddPoint((orbIndex - 0.5) / maxPoints, 1)
        comboCurves[key] = curve
    end
    return curve
end

-- Step color curve for debuff dispel types (Enum.AuraDispelType -> ColorMixin).
local dispelCurve
function Secrets.DispelCurve()
    if not dispelCurve and C_CurveUtil and type(C_CurveUtil.CreateColorCurve) == "function" and Enum and Enum.AuraDispelType then
        dispelCurve = C_CurveUtil.CreateColorCurve()
        dispelCurve:SetType(Enum.LuaCurveType.Step)
        local dtc = _G.DebuffTypeColor or {}
        local none = dtc["none"] or { r = 0.8, g = 0, b = 0 }
        local magic = dtc["Magic"] or { r = 0.2, g = 0.6, b = 1.0 }
        local curse = dtc["Curse"] or { r = 0.6, g = 0.0, b = 1.0 }
        local disease = dtc["Disease"] or { r = 0.6, g = 0.4, b = 0.0 }
        local poison = dtc["Poison"] or { r = 0.0, g = 0.6, b = 0.0 }
        dispelCurve:AddPoint(Enum.AuraDispelType.None, CreateColor(none.r, none.g, none.b, 1))
        dispelCurve:AddPoint(Enum.AuraDispelType.Magic, CreateColor(magic.r, magic.g, magic.b, 1))
        dispelCurve:AddPoint(Enum.AuraDispelType.Curse, CreateColor(curse.r, curse.g, curse.b, 1))
        dispelCurve:AddPoint(Enum.AuraDispelType.Disease, CreateColor(disease.r, disease.g, disease.b, 1))
        dispelCurve:AddPoint(Enum.AuraDispelType.Poison, CreateColor(poison.r, poison.g, poison.b, 1))
    end
    return dispelCurve
end

-- Returns health percent (0..100). May return a secret number when unit health is restricted;
-- pass to FontString:SetFormattedText("%.0f", pct) or StatusBar:SetValue(pct).
function Secrets.UnitHealthPercent100(unit)
    local cur = Secrets.Number(UnitHealth(unit))
    local max = Secrets.Number(UnitHealthMax(unit))
    if cur and max then
        if max > 0 then
            return math_floor(cur / max * 100 + 0.5)
        end
        return 0
    end
    if type(UnitHealthPercent) == "function" then
        local curve = Secrets.PercentCurve()
        if curve then
            return UnitHealthPercent(unit, true, curve)
        end
        return UnitHealthPercent(unit, true)
    end
    return 0
end

-- Round display percentages through C_StringUtil so secret values stay opaque.
function Secrets.RoundPercent(v)
    if type(v) == "nil" then
        return nil
    end
    if Secrets.IsSecret(v) then
        local util = _G.C_StringUtil
        if util and type(util.RoundToNearestString) == "function" then
            local ok, text = pcall(util.RoundToNearestString, v)
            if ok and text ~= nil then
                return text
            end
        end
        return v
    end
    if type(v) == "number" then
        return math_floor(v + 0.5)
    end
    return v
end

-- Returns power percent (0..100). May return a secret number when unit power is restricted.
function Secrets.UnitPowerPercent100(unit, powerType)
    local cur = Secrets.Number(UnitPower(unit, powerType))
    local max = Secrets.Number(UnitPowerMax(unit, powerType))
    if cur and max then
        if max > 0 then
            return math_floor(cur / max * 100 + 0.5)
        end
        return 0
    end
    if type(UnitPowerPercent) == "function" then
        local curve = Secrets.PercentCurve()
        if curve then
            return UnitPowerPercent(unit, powerType, false, curve)
        end
        return UnitPowerPercent(unit, powerType, false)
    end
    return 0
end

-- Secret-safe class color lookup (supports secret class strings via C_ClassColor.GetClassColor).
function Secrets.UnitClassColor(unit)
    if not unit then
        return nil
    end
    local _, class = UnitClass(unit)
    if type(class) == "nil" then
        return nil
    end
    if Secrets.IsSecret(class) then
        if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
            local ok, c = pcall(C_ClassColor.GetClassColor, class)
            if ok and c then
                return c.r, c.g, c.b, c.colorStr
            end
        end
        return nil
    end
    local colors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local c = colors and colors[class]
    if c then
        return c.r, c.g, c.b, c.colorStr
    end
    return nil
end

-- Converts a plain or secret value to a string (or secret string) suitable for C_StringUtil.WrapString.
function Secrets.ToString(v)
    if type(v) == "nil" then
        return ""
    end
    if Secrets.IsSecret(v) then
        if type(v) == "string" then
            return v
        end
        if type(AbbreviateNumbers) == "function" then
            local ok, s = pcall(AbbreviateNumbers, v)
            if ok and s ~= nil then
                return s
            end
        end
        if C_StringUtil and type(C_StringUtil.TruncateWhenZero) == "function" then
            local ok, s = pcall(C_StringUtil.TruncateWhenZero, v)
            if ok and s ~= nil then
                return s
            end
        end
        return v
    end
    return tostring(v)
end

-- Wraps `infix` with `prefix` and `suffix` safely even when any argument is a secret value.
function Secrets.Wrap(infix, prefix, suffix)
    if type(infix) == "nil" then
        return ""
    end
    if Secrets.IsSecret(infix) or Secrets.IsSecret(prefix) or Secrets.IsSecret(suffix) then
        local inf = Secrets.ToString(infix)
        local pre = prefix and Secrets.ToString(prefix) or ""
        local suf = suffix and Secrets.ToString(suffix) or ""
        if C_StringUtil and type(C_StringUtil.WrapString) == "function" then
            local ok, res = pcall(C_StringUtil.WrapString, inf, pre, suf)
            if ok and res ~= nil then
                return res
            end
        end
        return inf
    end
    if infix == "" then
        return ""
    end
    return (prefix or "") .. tostring(infix) .. (suffix or "")
end

-- Joins `left` and `right` with `sep` safely even when `left` or `right` is a secret value.
function Secrets.Join(sep, left, right)
    return Secrets.Wrap(sep or " / ", left or "", right or "")
end

