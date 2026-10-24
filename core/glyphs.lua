---------------------------------------------
--  DiabolusForever - pad glyphs
---------------------------------------------
-- Controller button badges in the Diablo kit: a dark stone disc,
-- the game's active controller button glyph, an iron ring and gloss.
-- Uses InputIconTextureSetUtility to follow Xbox, PlayStation, or Steam Deck.

local addon, ns = ...

local MEDIA = "Interface\\AddOns\\DiabolusForever\\media\\"

local Glyphs = {}
ns.Glyphs = Glyphs

local FILL = {
	combo_orb_border = 0.50,
	combo_orb_bg = 0.59,
	combo_orb_glow = 0.53,
	combo_orb_highlight = 0.32,
	orb_back2 = 0.91,
	orb_gloss = 0.88,
}

function Glyphs.Round(texture, file, diameter)
	texture:SetTexture(file)
	local name = file:match("([%w_]+)$")
	local size = diameter / (FILL[name] or 1)
	texture:SetSize(size, size)
	return texture
end

local FALLBACK = {
	PADDUP = "gamepad-xbox1-dpadup-normal",
	PADDRIGHT = "gamepad-xbox1-dpadright-normal",
	PADDDOWN = "gamepad-xbox1-dpaddown-normal",
	PADDLEFT = "gamepad-xbox1-dpadleft-normal",
	PAD1 = "gamepad-xbox1-buttona-normal",
	PAD2 = "gamepad-xbox1-buttonb-normal",
	PAD3 = "gamepad-xbox1-buttonx-normal",
	PAD4 = "gamepad-xbox1-buttony-normal",
	PADLSHOULDER = "gamepad-xbox1-trigger-lb-normal",
	PADRSHOULDER = "gamepad-xbox1-trigger-rb-normal",
	PADLTRIGGER = "gamepad-xbox1-trigger-lt-normal",
	PADRTRIGGER = "gamepad-xbox1-trigger-rt-normal",
	PADLSTICK = "gamepad-xbox1-stick-l-normal",
	PADRSTICK = "gamepad-xbox1-stick-r-normal",
}

function Glyphs:Atlas(key)
	local util = InputIconTextureSetUtility
	if util and util.GetNormalActiveInputIconButtonTexture then
		local ok, atlas = pcall(util.GetNormalActiveInputIconButtonTexture, key)
		if ok and type(atlas) == "string" then
			return atlas
		end
	end
	return FALLBACK[key]
end

local badges = {}

local BadgeMixin = {}

function BadgeMixin:SetKey(key)
	self.key = key
	if not key then
		self.glyph:Hide()
		return
	end
	local atlas = Glyphs:Atlas(key)
	if atlas then
		self.glyph:SetAtlas(atlas)
		self.glyph:Show()
	else
		self.glyph:Hide()
	end
end

function BadgeMixin:SetLit(lit)
	self.lit = lit and true or false
	if self.lit then
		self.halo:Show()
		self:SetAlpha(1)
		self.glyph:SetDesaturated(false)
	else
		self.halo:Hide()
		self:SetAlpha(self.dimAlpha)
		self.glyph:SetDesaturated(true)
	end
end

function Glyphs:CreateBadge(parent, size, key)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.dimAlpha = 0.65

	local bg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
	Glyphs.Round(bg, MEDIA .. "combo_orb_bg", size * 1.02)
	bg:SetPoint("CENTER")

	local glyph = f:CreateTexture(nil, "ARTWORK")
	glyph:SetPoint("CENTER")
	glyph:SetSize(size * 0.68, size * 0.68)
	f.glyph = glyph

	local ring = f:CreateTexture(nil, "OVERLAY", nil, 1)
	Glyphs.Round(ring, MEDIA .. "combo_orb_border", size * 1.08)
	ring:SetPoint("CENTER")
	ring:SetVertexColor(0.75, 0.62, 0.45)

	local gloss = f:CreateTexture(nil, "OVERLAY", nil, 2)
	Glyphs.Round(gloss, MEDIA .. "combo_orb_highlight", size * 0.6)
	gloss:SetPoint("CENTER")
	gloss:SetAlpha(0.35)

	local halo = f:CreateTexture(nil, "BACKGROUND", nil, -2)
	Glyphs.Round(halo, MEDIA .. "combo_orb_glow", size * 1.6)
	halo:SetPoint("CENTER")
	halo:SetVertexColor(1, 0.55, 0.1)
	halo:SetBlendMode("ADD")
	halo:Hide()
	f.halo = halo

	for k, v in pairs(BadgeMixin) do
		f[k] = v
	end
	f:SetKey(key)
	f:SetLit(false)
	badges[#badges + 1] = f
	return f
end

function Glyphs:Refresh()
	for _, badge in ipairs(badges) do
		badge:SetKey(badge.key)
	end
end

-- Update badges whenever controller icon set or input device switches
local eventFrame = CreateFrame("Frame")
if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("INPUT_DEVICE_INTERFACE_TRANSITION") then
	eventFrame:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
end
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
	local manager = InputDeviceIconSetManager
	if manager and manager.RegisterActiveInputDeviceIconSetUpdatedCallback and not Glyphs.hooked then
		Glyphs.hooked = true
		manager:RegisterActiveInputDeviceIconSetUpdatedCallback(function()
			Glyphs:Refresh()
		end, Glyphs)
	end
	Glyphs:Refresh()
end)
