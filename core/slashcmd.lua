--  DiabolusForever - slashcmd

local addon, ns = ...

-- FRAME LISTS

Roth_UI_Bars = {
	"Roth_UIExpBar",
	"Roth_UIRepBar",
	"Roth_UISoulShardPower",
	"Roth_UIBurningEmberPower",
	"Roth_UIHolyPower",
	"Roth_UIHarmonyPower",
	"Roth_UIShadowOrbPower",
	"Roth_UIEclipsePower",
	"Roth_UIRuneBar",
	"Roth_UIComboPoints",
	"Roth_UIArcanePower",
	"Roth_DruidMana",
	"Roth_UIArtifactPower",
	"Roth_TotemFrame",
}
Roth_UI_Orbs = {
	"Roth_UIPowerOrb",
	"Roth_UIPlayerFrame",
}

Roth_UI_Units = {
	"Roth_UITargetFrame",
	"Roth_UITargetTargetFrame",
	"Roth_UIPetTargetFrame",
	"Roth_UIPetFrame",
	"Roth_UIFocusTargetFrame",
	"Roth_UIFocusFrame",
}

Roth_UI_Art = {
	"Roth_UIActionBarBackground",
	"Roth_UIAngelFrame",
	"Roth_UIDemonFrame",
	"Roth_UIBottomLine",
	"Roth_UIPlayerPortrait",
	"Roth_UITargetPortrait",
}

local categoryLists = {
	art = Roth_UI_Art,
	bars = Roth_UI_Bars,
	units = Roth_UI_Units,
	orbs = Roth_UI_Orbs,
}

local function GetFrameList(c)
	if c == "all" then
		local a = {}
		for _, list in pairs(categoryLists) do
			for _, v in ipairs(list) do
				a[#a + 1] = v
			end
		end
		return a
	end
	return categoryLists[c] or {}
end

local function DragHint()
	if ns.EditMode and ns.EditMode.active then
		return "Drag to move"
	end
	return "Hold down ALT+SHIFT to drag!"
end

function Roth_UIUnlock(c, quiet)
	if not quiet then
		print("|c00FF3300DiabolusForever:|r " .. c .. " unlocked")
	end
	for _, v in ipairs(GetFrameList(c)) do
		local f = _G[v]
		if f and f.dragframe then
			f.dragframe:Show()
			f.dragframe:EnableMouse(true)
			f.dragframe:RegisterForDrag("LeftButton")
			f.dragframe:SetScript("OnEnter", function(s)
				GameTooltip:SetOwner(s, "ANCHOR_TOP")
				GameTooltip:AddLine(s:GetParent():GetName(), 0, 1, 0.5, 1, 1, 1)
				if ns.EditMode and ns.EditMode.active then
					GameTooltip:AddLine("Click to select | Drag to move", 1, 1, 1)
					GameTooltip:AddLine("Mouse Wheel: Change size (scale)", 0.2, 0.8, 1)
					GameTooltip:AddLine("Shift + Wheel: Change spacing", 0.2, 0.8, 1)
				else
					GameTooltip:AddLine(DragHint(), 1, 1, 1, 1, 1, 1)
				end
				GameTooltip:Show()
			end)
			f.dragframe:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		end
	end
end

function Roth_UILock(c, quiet)
	if not quiet then
		print("|c00FF3300DiabolusForever:|r " .. c .. " locked")
	end
	for _, v in ipairs(GetFrameList(c)) do
		local f = _G[v]
		if f and f.dragframe then
			f.dragframe:Hide()
			f.dragframe:EnableMouse(false)
			f.dragframe:RegisterForDrag()
			f.dragframe:SetScript("OnEnter", nil)
			f.dragframe:SetScript("OnLeave", nil)
		end
	end
end

function Roth_UIReset(c)
	if InCombatLockdown() then
		print("|c00FF3300DiabolusForever:|r Resetting frames is not possible in combat.")
		return
	end
	print("|c00FF3300DiabolusForever:|r " .. c .. " reset")
	for _, v in ipairs(GetFrameList(c)) do
		local f = _G[v]
		if f and f.defaultPosition then
			f:ClearAllPoints()
			local pos = f.defaultPosition
			local relTo = (type(pos.af) == "string" and _G[pos.af]) or pos.af or UIParent
			if pos.af and pos.a2 then
				f:SetPoint(pos.a1 or "CENTER", relTo, pos.a2, pos.x or 0, pos.y or 0)
			elseif pos.af then
				f:SetPoint(pos.a1 or "CENTER", relTo, pos.x or 0, pos.y or 0)
			else
				f:SetPoint(pos.a1 or "CENTER", pos.x or 0, pos.y or 0)
			end
		end
	end
end

local function SlashCmd(cmd)
	cmd = (cmd or ""):match("^%s*(.-)%s*$")
	if cmd == "wingdebug" then
		if ns.StandardMode then ns.StandardMode:DebugWings() end
	elseif cmd == "taint" then
		if ns.TaintCheck then
			ns.TaintCheck:Run()
		end
	elseif cmd == "belt" then
		if ns.Belt and ns.Belt.Debug then
			ns.Belt.Debug()
		end
	elseif cmd == "food" then
		if ns.Belt and ns.Belt.DebugFood then
			ns.Belt.DebugFood()
		end
	elseif cmd == "auras" then
		if ns.TaintCheck then
			ns.TaintCheck:ProbeAuras("target")
		end
	elseif cmd == "" or cmd:match("config") or cmd == "settings" then
		ns.UI.Panel.Toggle()
	elseif cmd:match("resettemplates") then
		ns.db.resetTemplates()
	elseif cmd == "edit" or cmd:match("^unlock") then
		if ns.EditMode and ns.EditMode.Toggle then
			if cmd == "edit" then
				ns.EditMode:Toggle()
			else
				ns.EditMode:SetActive(true)
			end
		end
	elseif cmd:match("^lock") then
		if ns.EditMode then
			ns.EditMode:SetActive(false)
		end
	elseif cmd:match("resetart") then
		Roth_UIReset("art")
	elseif cmd:match("resetbars") then
		Roth_UIReset("bars")
	elseif cmd:match("resetunits") then
		Roth_UIReset("units")
	elseif cmd:match("resetorbs") then
		Roth_UIReset("orbs")
	elseif cmd:match("resetall") then
		Roth_UIReset("bars")
		Roth_UIReset("units")
		Roth_UIReset("art")
		Roth_UIReset("orbs")
		if ns.EditMode and ns.EditMode.ResetAllToDefault then
			ns.EditMode:ResetAllToDefault()
		end
	elseif cmd:match("screen") or cmd:match("res") then
		local m = ns.GetScreenMetrics and ns.GetScreenMetrics()
		if m then
			print("|c00FF3300DiabolusForever Screen Metrics:|r")
			print(
				string.format("  Physical: %d x %d (Aspect: %.2f:1)", m.physicalWidth, m.physicalHeight, m.aspectRatio)
			)
			print(
				string.format(
					"  UI Space: %.0f x %.0f (Effective Scale: %.0f%%)",
					m.uiWidth,
					m.uiHeight,
					m.uiScale * 100
				)
			)
			print(
				string.format(
					"  Pixel-Perfect Scale (768/h): %.4f (%.1f%%)",
					m.pixelPerfectScale,
					m.pixelPerfectScale * 100
				)
			)
			print(string.format("  DPI / Pixel Ratio: %.2f physical px / UI unit", m.pixelRatio))
			local gs = ns.EditMode and ns.EditMode.GetGlobalScale and ns.EditMode:GetGlobalScale() or 1.0
			print(string.format("  Global UI Size: %d%%", math.floor(gs * 100 + 0.5)))
		end
	elseif cmd:match("autoscale") then
		local arg = cmd:match("autoscale%s+(%a+)")
		local prof = ns.LayoutProfile and ns.LayoutProfile()
		if arg == "off" or arg == "disable" then
			if prof then
				prof.autoScale = false
			end
			print("|c00FF3300DiabolusForever:|r Auto UI scale disabled. Blizzard UI scale will not be modified.")
		elseif arg == "on" or arg == "enable" then
			if prof then
				prof.autoScale = true
			end
			if ns.func and ns.func.ApplyPixelPerfectScale then
				ns.func.ApplyPixelPerfectScale()
			end
			local m = ns.GetScreenMetrics and ns.GetScreenMetrics()
			print(
				string.format(
					"|c00FF3300DiabolusForever:|r Auto UI scale enabled (768/h = %.1f%%).",
					(m and m.pixelPerfectScale or 1) * 100
				)
			)
		else
			local state = (not prof or prof.autoScale ~= false) and "enabled" or "disabled"
			print(
				string.format(
					"|c00FF3300DiabolusForever:|r Auto UI scale is currently |cffffd100%s|r. Use |c00FF3300/roth autoscale on|r or |c00FF3300/roth autoscale off|r.",
					state
				)
			)
		end
	elseif cmd:match("scale") then
		local numStr = cmd:match("scale%s+([%d%.]+)")
		if numStr then
			local val = tonumber(numStr)
			if val then
				if val > 5 then
					val = val / 100
				end
				if ns.EditMode and ns.EditMode.SetGlobalScale then
					ns.EditMode:SetGlobalScale(val)
					print(
						string.format(
							"|c00FF3300DiabolusForever:|r Global UI size set to %d%%.",
							math.floor(val * 100 + 0.5)
						)
					)
				end
			end
		else
			local gs = ns.EditMode and ns.EditMode.GetGlobalScale and ns.EditMode:GetGlobalScale() or 1.0
			print(
				string.format(
					"|c00FF3300DiabolusForever:|r Current Global UI size is %d%%. Use |c00FF3300/diabolus scale <number>|r to change it.",
					math.floor(gs * 100 + 0.5)
				)
			)
		end
	else
		print("|c00FF3300DiabolusForever command list:|r")
		print(
			"|c00FF3300/diabolus edit|r or |c00FF3300/dforever edit|r, to toggle Edit Mode (move, resize, enable/disable frames)"
		)
		print("|c00FF3300/diabolus lockall|r, to finish editing and lock frames")
		print("|c00FF3300/diabolus resetall|r, to reset all frames to default layout")
		print("|c00FF3300/diabolus|r or |c00FF3300/dforever|r, to open the settings window")
		print("|c00FF3300/diabolus resettemplates|r, to reset orb templates")
		print("|c00FF3300/diabolus scale <number>|r, to scale all unit frames and art globally")
		print("|c00FF3300/diabolus autoscale [on|off]|r, to toggle pixel-perfect (768/h) UI scaling")
		print("|c00FF3300/diabolus screen|r, to display resolution, DPI, and pixel metrics")
		print("|c00FF3300/diabolus belt|r, to inspect potion belt choices and context")
		print("|c00FF3300/diabolus auras|r, to inspect target aura API output")
		print("|c00FF3300/diabolus taint|r, to list refused actions and taint diagnostics")
	end
end

-- Register /roth, /diabolus, and /dforever slash commands
if not SlashCmdList["roth"] then
	SlashCmdList["roth"] = SlashCmd
	SLASH_roth1 = "/roth"
	SLASH_roth2 = "/diabolus"
	SLASH_roth3 = "/dforever"

	local loadMessagePrinted = _G.Roth_UI_loadMessagePrinted
	if not loadMessagePrinted then
		local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
		local version = (meta and (meta(addon, "Version") or meta("DiabolusForever", "Version") or meta("DiabolusUnits", "Version"))) or "1.0.0"
		print(
			"|c00FF3300DiabolusForever v"
				.. version
				.. " loaded. Type |r|c00FF3300/diabolus edit|r|c00FF3300 to customize frames or |r|c00FF3300/diabolus|r|c00FF3300 for settings.|r"
		)
		_G.Roth_UI_loadMessagePrinted = true
	end
end
