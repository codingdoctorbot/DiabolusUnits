---------------------------------------------
--  rTooltip
---------------------------------------------

--  A simple tooltip mod
--  Galaxy - 2016

---------------------------------------------
local addon, ns = ...
local cfg = ns.cfg
if not cfg.embeds.rTooltip then
	return
end

---------------------------------------------
--  VARIABLES
---------------------------------------------

local unpack, type = unpack, type
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local WorldFrame = WorldFrame
local GameTooltip = GameTooltip
local GameTooltipStatusBar = GameTooltipStatusBar
local Secrets = ns.Secrets
local Compat = ns.Compat
local mediapath = "Interface\\AddOns\\DiabolusUnits\\media\\"

---------------------------------------------
--  FUNCTIONS
---------------------------------------------

--change some text sizes
GameTooltipHeaderText:SetFont(cfg.font, 14, "THINOUTLINE")
GameTooltipText:SetFont(cfg.font, 12, "THINOUTLINE")
Tooltip_Small:SetFont(cfg.font, 11, "THINOUTLINE")

--gametooltip statusbar
GameTooltipStatusBar:ClearAllPoints()
GameTooltipStatusBar:SetPoint("LEFT", 5, 0)
GameTooltipStatusBar:SetPoint("RIGHT", -5, 0)
GameTooltipStatusBar:SetPoint("BOTTOM", GameTooltipStatusBar:GetParent(), "TOP", 0, -6)
GameTooltipStatusBar:SetHeight(3)
--gametooltip statusbar bg (kept here, not written into Blizzard's frame table)
local statusBarBg = GameTooltipStatusBar:CreateTexture(nil, "BACKGROUND", nil, -8)
statusBarBg:SetPoint("TOPLEFT", -1, 1)
statusBarBg:SetPoint("BOTTOMRIGHT", 1, -1)
statusBarBg:SetTexture(0, 0, 0)
statusBarBg:SetVertexColor(0, 0, 0, 0.7)

-- The Roth skin. Forever's tooltips draw their frame with a NineSlice and have
-- no SetBackdropColor (GameTooltipTemplate -> SharedTooltipTemplate does not
-- inherit TooltipBackdropTemplate), so the old Mixin/SetBackdrop calls errored
-- on every tooltip. Each tooltip gets a frame of ours in the tooltip skin,
-- drawn under the tooltip's text, and the NineSlice is only faded out (a C
-- call): nothing is written into Blizzard's tooltip tables.
local skins = {}
local function Skin(tooltip)
	local skin = skins[tooltip]
	if not skin then
		skin = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
		skin:SetAllPoints(tooltip)
		skin:SetBackdrop({
			bgFile = mediapath .. "Tooltip_Background",
			edgeFile = mediapath .. "Tooltip_Border",
			tile = false,
			edgeSize = 10,
			insets = { left = 8, right = 8, top = 8, bottom = 8 },
		})
		-- Diablo item dress (shown for items only, ItemDress): a title plate
		-- behind the item name, a footer rule and the item's icon in a frame
		-- on the tooltip's left, all in the item's quality colour.
		local plate = skin:CreateTexture(nil, "BORDER")
		plate:SetTexture(mediapath .. "Tooltip_TitleDecoration")
		plate:SetTexCoord(0, 1, 5 / 64, 59 / 64)
		plate:SetPoint("TOPLEFT", skin, "TOPLEFT", 4, -4)
		plate:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -4, -4)
		plate:SetHeight(28)
		plate:Hide()
		skin.plate = plate
		local footer = skin:CreateTexture(nil, "BORDER")
		footer:SetTexture(mediapath .. "Tooltip_Footer")
		footer:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", 6, 3)
		footer:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -6, 3)
		footer:SetHeight(10)
		footer:Hide()
		skin.footer = footer
		local iconFrame = CreateFrame("Frame", nil, skin)
		iconFrame:SetSize(42, 42)
		iconFrame:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -2, 0)
		local icon = iconFrame:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", 4, -4)
		icon:SetPoint("BOTTOMRIGHT", -4, 4)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local iconBorder = iconFrame:CreateTexture(nil, "OVERLAY")
		iconBorder:SetTexture(mediapath .. "Tooltip_IconBorder")
		iconBorder:SetAllPoints(iconFrame)
		iconFrame:Hide()
		skin.icon, skin.iconBorder, skin.iconFrame = icon, iconBorder, iconFrame
		skins[tooltip] = skin
	end
	-- under the tooltip's own text, whatever level the tooltip is raised to
	skin:SetFrameLevel(math.max(0, tooltip:GetFrameLevel() - 1))
	if tooltip.NineSlice then
		tooltip.NineSlice:SetAlpha(0)
	end
	return skin
end

local function SetBorderColor(tooltip, r, g, b)
	local skin = Skin(tooltip)
	skin:SetBackdropColor(1, 1, 1, 1)
	skin:SetBackdropBorderColor(r, g, b, 1)
end

-- Shows (texture and quality colour) or hides (nil) the Diablo item dress.
local function ItemDress(tooltip, texture, r, g, b)
	local skin = Skin(tooltip)
	if not texture then
		skin.plate:Hide()
		skin.footer:Hide()
		skin.iconFrame:Hide()
		return
	end
	skin.plate:SetVertexColor(r, g, b, 0.9)
	skin.plate:Show()
	skin.footer:SetVertexColor(r, g, b, 0.8)
	skin.footer:Show()
	skin.icon:SetTexture(texture)
	skin.iconBorder:SetVertexColor(r, g, b)
	skin.iconFrame:Show()
end

--HookScript GameTooltip OnTooltipCleared
-- (no GameTooltip_ClearStatusBars here: Blizzard's own OnTooltipCleared
-- already releases the bars, and calling it from this hook released
-- Blizzard's status bar pool from tainted code)
GameTooltip:HookScript("OnTooltipCleared", function(self)
	SetBorderColor(self, 1, 1, 1)
	ItemDress(self, nil)
end)

--hooksecurefunc GameTooltip_SetDefaultAnchor
-- Blizzard's GameTooltip_SetDefaultAnchor has already called
-- SetOwner(parent, "ANCHOR_NONE"); a second SetOwner from here re-runs the
-- tooltip's OnTooltipCleared scripts (Blizzard's included) in add-on
-- context, which taints the tooltip's fields. Only the position is changed.
-- The cursor-following tooltip needs its own SetOwner, so it stays a mouse
-- mode option: in the gamepad UI there is no cursor to follow.
-- Anchor choices (cfg.rtooltip.anchor), each clear of the bottom HUD: above the bag wing and
-- belt, its mirror above the game menu wing (above the pet frame's height), or centred above
-- the action bar / cast bar / swing timer stack.
local TOOLTIP_POINTS = {
	bottomleft = { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, 257 },
	center = { "BOTTOM", UIParent, "BOTTOM", 0, 310 },
}

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
	local pad = ns.Pad and ns.Pad:IsActive()
	local anchor = cfg.rtooltip.anchor
	if (anchor == "cursor" or cfg.rtooltip.cursorfocus) and not pad then
		tooltip:SetOwner(parent, "ANCHOR_CURSOR")
	else
		tooltip:ClearAllPoints()
		tooltip:SetPoint(unpack(TOOLTIP_POINTS[anchor] or cfg.rtooltip.pos))
	end
end)

--func AddSpellIdRow
local function AddSpellIdRow(tooltip, spellid)
	local sid = Secrets and Secrets.Number(spellid) or (type(spellid) == "number" and spellid or nil)
	if sid then
		tooltip:AddDoubleLine("|cff0099ffSpell ID|r", sid)
		tooltip:Show()
	end
end

--func AddBossDebuffRow
local function AddBossDebuffRow(tooltip, isBossDebuff)
	tooltip:AddDoubleLine("|cff0099ffBossDebuff|r", "Yes")
	tooltip:Show()
end

--hooksecurefunc GameTooltip SetUnitBuff
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, ...)
	local spellid = select(10, Compat.UnitBuff(...))
	if spellid then
		AddSpellIdRow(self, spellid)
	end
end)

--hooksecurefunc GameTooltip SetUnitDebuff
hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, ...)
	local spellid = select(10, Compat.UnitDebuff(...))
	if spellid then
		AddSpellIdRow(self, spellid)
	end
	local isBossDebuff = select(12, Compat.UnitDebuff(...))
	if isBossDebuff then
		AddBossDebuffRow(self, isBossDebuff)
	end
end)

--hooksecurefunc GameTooltip SetUnitAura
hooksecurefunc(GameTooltip, "SetUnitAura", function(self, ...)
	local spellid = select(10, Compat.UnitAura(...))
	if spellid then
		AddSpellIdRow(self, spellid)
	end
	local isBossDebuff = select(12, Compat.UnitAura(...))
	if isBossDebuff then
		AddBossDebuffRow(self, isBossDebuff)
	end
end)

--hooksecurefunc SetItemRef
hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
	if string.find(link, "^spell:") then
		local spellid = string.sub(link, 7)
		AddSpellIdRow(ItemRefTooltip, spellid)
	end
end)

-- WoW Forever has no OnTooltipSetSpell / OnTooltipSetUnit scripts (the
-- tooltip data processor replaced them); HookScript on them raised an error
-- that stopped this file halfway, so the Roth skin never reached the
-- tooltips. Post-calls through TooltipDataProcessor where it exists.
local function OnTooltipData(kind, scriptName, fn)
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType and Enum.TooltipDataType[kind] then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType[kind], function(tooltip, ...)
			if tooltip == GameTooltip then
				fn(tooltip, ...)
			end
		end)
	elseif GameTooltip:HasScript(scriptName) then
		GameTooltip:HookScript(scriptName, fn)
	end
end

--spell id row on spell tooltips
OnTooltipData("Spell", "OnTooltipSetSpell", function(self)
	local spellid = select(3, self:GetSpell())
	if spellid then
		AddSpellIdRow(self, spellid)
	end
end)

--func GetHexColor
local function GetHexColor(color)
	return ("%.2x%.2x%.2x"):format(color.r * 255, color.g * 255, color.b * 255)
end

local classColors, reactionColors = {}, {}

for class, color in pairs(RAID_CLASS_COLORS) do
	classColors[class] = GetHexColor(RAID_CLASS_COLORS[class])
end

for i = 1, #FACTION_BAR_COLORS do
	reactionColors[i] = GetHexColor(FACTION_BAR_COLORS[i])
end

local function GetTarget(unit)
	if not unit then
		return nil
	end
	if Secrets and Secrets.UnitIsUnit(unit, "player") then
		return ("|cffff0000%s|r"):format("<YOU>")
	end
	local isPlayer = Secrets and Secrets.Bool(UnitIsPlayer, unit)
	local uName = (Secrets and Secrets.String(UnitName(unit))) or UnitName(unit) or "Unknown"
	if isPlayer then
		local _, unitClass = UnitClass(unit)
		local hex = (unitClass and classColors[unitClass]) or "ffffff"
		return ("|cff%s%s|r"):format(hex, uName)
	end
	local reaction = Secrets and Secrets.Number(UnitReaction(unit, "player"))
		or (type(UnitReaction) == "function" and UnitReaction(unit, "player") or nil)
	if reaction and reactionColors[reaction] then
		return ("|cff%s%s|r"):format(reactionColors[reaction], uName)
	end
	return ("|cffffffff%s|r"):format(uName)
end

--unit tooltips
OnTooltipData("Unit", "OnTooltipSetUnit", function(self, ...)
	local unit = select(2, self:GetUnit()) or ((Secrets and Secrets.UnitExists("mouseover")) and "mouseover")
	if not unit or (unit and type(unit) ~= "string") then
		return
	end
	if not (Secrets and Secrets.UnitGUID(unit) or UnitGUID(unit)) then
		return
	end
	local ricon = GetRaidTargetIndex(unit)
	if ricon and ICON_LIST and ICON_LIST[ricon] then
		local text = GameTooltipTextLeft1:GetText() or ""
		GameTooltipTextLeft1:SetText(("%s %s"):format(ICON_LIST[ricon] .. "14|t", text))
	end
	for i = 2, GameTooltip:NumLines() do
		local line = _G["GameTooltipTextLeft" .. i]
		if line then
			line:SetTextColor(0.5, 0.5, 0.5)
		end
	end
	if Secrets and Secrets.Bool(UnitIsPlayer, unit) then
		local r, g, b = Secrets.UnitClassColor(unit)
		if not r then
			local _, unitClass = UnitClass(unit)
			local color = unitClass and RAID_CLASS_COLORS[unitClass]
			if color then
				r, g, b = color.r, color.g, color.b
			else
				r, g, b = 1, 1, 1
			end
		end
		GameTooltipStatusBar:SetStatusBarColor(r, g, b)
		GameTooltipTextLeft1:SetTextColor(r, g, b)
		if Secrets.Bool(UnitIsAFK, unit) then
			self:AppendText(" |cff00cccc<AFK>|r")
		elseif Secrets.Bool(UnitIsDND, unit) then
			self:AppendText(" |cffcc0000<DND>|r")
		end
		local unitGuild = Secrets.String(GetGuildInfo(unit))
		local text = GameTooltipTextLeft2:GetText()
		if unitGuild and text and text:find("^" .. unitGuild) then
			GameTooltipTextLeft2:SetText("<" .. text .. ">")
			GameTooltipTextLeft2:SetTextColor(255 / 255, 20 / 255, 200 / 255)
		end
	else
		local reaction = Secrets and Secrets.Number(UnitReaction(unit, "player"))
			or (type(UnitReaction) == "function" and UnitReaction(unit, "player") or nil)
		if reaction then
			local color = FACTION_BAR_COLORS[reaction]
			if color then
				GameTooltipStatusBar:SetStatusBarColor(color.r, color.g, color.b)
				GameTooltipTextLeft1:SetTextColor(color.r, color.g, color.b)
			end
		end

		local unitClassification = Secrets and Secrets.String(UnitClassification(unit)) or UnitClassification(unit)
		local uLevel = Secrets and Secrets.Number(UnitLevel(unit)) or UnitLevel(unit)
		if unitClassification == "worldboss" or uLevel == -1 then
			if reaction == 2 then
				--highlight bosses
				GameTooltipTextLeft1:SetTextColor(1, 0.1, 0)
			end
			self:AppendText(" |TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:14:14|t")
		elseif unitClassification == "rare" then
			self:AppendText(" |TInterface\\AddOns\\DiabolusUnits\\media\\diablo:14:14:0:0:16:16:0:15:0:14|t")
		elseif unitClassification == "rareelite" then
			self:AppendText(" |TInterface\\AddOns\\DiabolusUnits\\media\\diablo:14:14:0:0:16:16:0:15:0:14|t")
		elseif unitClassification == "elite" then
			self:AppendText(" |TInterface\\AddOns\\DiabolusUnits\\media\\plus:14:14|t")
		end
	end

	if Secrets and Secrets.Bool(UnitIsGhost, unit) then
		self:AppendText(" |cffaaaaaa<GHOST>|r")
		GameTooltipTextLeft1:SetTextColor(0.5, 0.5, 0.5)
	elseif Secrets and Secrets.Bool(UnitIsDead, unit) then
		self:AppendText(" |cffaaaaaa<DEAD>|r")
		GameTooltipTextLeft1:SetTextColor(0.5, 0.5, 0.5)
	end

	if Secrets and Secrets.UnitExists(unit .. "target") or UnitExists(unit .. "target") then
		GameTooltip:AddDoubleLine("|cffff9999Target|r", GetTarget(unit .. "target") or "Unknown")
	end
end)

--func TooltipOnShow
local function TooltipOnShow(self, ...)
	SetBorderColor(self, 1, 1, 1)
	ItemDress(self, nil)
	if not self.GetItem then
		return
	end
	local _, itemLink = self:GetItem()
	if itemLink and not Secrets.IsSecret(itemLink) then
		local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
		local itemRarity = getInfo and select(3, getInfo(itemLink))
		local r, g, b = 1, 1, 1
		if itemRarity and not Secrets.IsSecret(itemRarity) then
			-- WoW Forever: C_Item.GetItemQualityColor (no global)
			local qualityColor = (C_Item and C_Item.GetItemQualityColor) or rawget(_G, "GetItemQualityColor")
			if qualityColor then
				r, g, b = qualityColor(itemRarity)
			end
			r, g, b = r or 1, g or 1, b or 1
			SetBorderColor(self, r, g, b)
		end
		if cfg.rtooltip.itemDress ~= false then
			local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
			local texture = getInstant and select(5, getInstant(itemLink))
			if texture and not Secrets.IsSecret(texture) then
				ItemDress(self, texture, r, g, b)
			end
		end
	end
end

--func TooltipOnShow
local function TooltipOnHide(self, ...)
	ItemDress(self, nil)
end

--loop over tooltips
local tooltips = { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3, WorldMapTooltip }
for idx, tooltip in ipairs(tooltips) do
	Skin(tooltip)
	tooltip:SetScale(cfg.rtooltip.scale)
	tooltip:HookScript("OnShow", TooltipOnShow)
	tooltip:HookScript("OnHide", TooltipOnHide)
end

--loop over menues
local menues = {
	DropDownList1MenuBackdrop,
	DropDownList2MenuBackdrop,
}
for idx, menu in ipairs(menues) do
	menu:SetScale(cfg.rtooltip.scale)
end
