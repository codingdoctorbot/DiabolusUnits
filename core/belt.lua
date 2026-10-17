---------------------------------------------
--  DiabolusUnits - Potion Belt
---------------------------------------------
-- Diablo's belt: four glass flask slots beside the health orb, holding your
-- best health potion, healthstone, best mana potion (or mana gem) and bandage
-- from your bags. Each shows how many you carry and its cooldown, uses the
-- item on click, and has a key binding (Key Bindings › AddOns › DiabolusUnits:
-- Belt 1-4), like the belt keys 1-4 in Diablo.
--
-- The buttons are secure; what they hold can only change out of combat, so
-- a potion looted in a fight takes its slot when the fight ends. Counts and
-- cooldowns update in combat.

local _, ns = ...

local cfg = ns.cfg
local Secrets = ns.Secrets

local Belt = {}
ns.Belt = Belt

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"
local SLOTS = { "health", "healthstone", "mana", "bandage" }
local SIZE, GAP = 34, 6
local LIQUID = {
	health = { 0.85, 0.08, 0.05 },
	healthstone = { 0.3, 0.85, 0.2 },
	mana = { 0.15, 0.4, 1 },
	bandage = { 0.85, 0.78, 0.6 },
}
local FILL_W, FILL_H, FILL_Y = 76 / 128, 87 / 128, (64 - 60.5) / 128

local CONSUMABLE = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
local SUB = (Enum and Enum.ItemConsumableSubclass) or {}
local POTION, BANDAGE = SUB.Potion or 1, SUB.Bandage or 7
local MANA_GEMS = { "mana agate", "mana jade", "mana citrine", "mana ruby", "mana emerald" }

local function Opt(key, default)
	local b = cfg.belt
	if b and b[key] ~= nil then
		return b[key]
	end
	return default
end

local function ItemSpellName(itemID)
	if not (C_Item and C_Item.GetItemSpell) then
		return nil
	end
	local ok, name = pcall(C_Item.GetItemSpell, itemID)
	return ok and type(name) == "string" and name or nil
end

local function HasAny(text, words)
	for _, word in ipairs(words) do
		if text:find(word, 1, true) then
			return true
		end
	end
	return false
end

local function ClassifyBeltItem(name, classID, subclassID, spell)
	if classID ~= CONSUMABLE then
		return nil
	end
	local lower = (name or ""):lower()
	local spellLower = (spell or ""):lower()
	if lower:find("healthstone", 1, true) then
		return "healthstone"
	elseif HasAny(lower, MANA_GEMS) then
		return "mana"
	elseif subclassID == POTION then
		if spellLower:find("mana", 1, true) or lower:find("mana", 1, true) then
			return "mana"
		elseif spellLower:find("heal", 1, true) or lower:find("heal", 1, true) or spell == nil then
			return "health"
		end
	elseif subclassID == BANDAGE or lower:find("bandage", 1, true) then
		return "bandage"
	end
	return nil
end

function Belt:ScanBags()
	local best, seen = {}, {}
	local lastBag = rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS") or rawget(_G, "NUM_BAG_SLOTS") or 4
	for bag = 0, lastBag do
		for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local itemID = info and info.itemID
			if itemID and not seen[itemID] then
				seen[itemID] = true
				local _, _, _, _, icon, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
				local name, _, _, itemLevel = C_Item.GetItemInfo(itemID)
				local spell = ItemSpellName(itemID)
				local cat = ClassifyBeltItem(name, classID, subclassID, spell)
				if cat then
					local lvl = (Secrets and Secrets.Number(itemLevel))
						or (type(itemLevel) == "number" and itemLevel)
						or 0
					local cur = best[cat]
					if not cur or lvl > cur.level then
						best[cat] = {
							itemID = itemID,
							value = "item:" .. itemID,
							icon = icon or info.iconFileID,
							level = lvl,
						}
					end
				end
			end
		end
	end
	return best
end

local holder = CreateFrame("Frame", "Roth_UIBelt", UIParent)
holder:SetSize(#SLOTS * SIZE + (#SLOTS - 1) * GAP, SIZE)
holder:SetFrameStrata("MEDIUM")
Belt.holder = holder
Belt.buttons = {}
holder.defaultPosition = { a1 = "BOTTOMLEFT", af = "Roth_UIPlayerFrame", a2 = "BOTTOMRIGHT", x = -12, y = 26 }
holder:SetScript("OnMouseDown", function(s)
	if ns.EditMode and ns.EditMode.active and ns.EditMode.SelectFrame then
		ns.EditMode:SelectFrame(s)
	end
end)

local function Place()
	holder:ClearAllPoints()
	local prof = ns.LayoutProfile and ns.LayoutProfile()
	if prof and prof.framePositions and prof.framePositions["Roth_UIBelt"] then
		local pos = prof.framePositions["Roth_UIBelt"]
		local relTo = (pos.relativeTo and rawget(_G, pos.relativeTo)) or UIParent
		holder:SetPoint(pos.point or "BOTTOM", relTo, pos.relativePoint or "BOTTOM", pos.x or -12, pos.y or 26)
		return
	end

	local pframe = rawget(_G, "Roth_UIPlayerFrame")
	if pframe then
		holder:SetPoint("BOTTOMLEFT", pframe, "BOTTOMRIGHT", Opt("x", -12), Opt("y", 26))
	else
		holder:SetPoint("BOTTOM", UIParent, "BOTTOM", -235, Opt("y", 26))
	end
end

-- the strap and its buckles
do
	local strap = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
	strap:SetTexture(MEDIA .. "combo_back2")
	strap:SetPoint("LEFT", holder, "LEFT", -6, 0)
	strap:SetPoint("RIGHT", holder, "RIGHT", 6, 0)
	strap:SetHeight(SIZE * 1.1)
	strap:SetVertexColor(0.8, 0.7, 0.6)
	for _, side in ipairs({ "LEFT", "RIGHT" }) do
		local cap = holder:CreateTexture(nil, "BACKGROUND", nil, -7)
		cap:SetTexture(MEDIA .. (side == "LEFT" and "combo_bar_left" or "combo_bar_right"))
		cap:SetSize(SIZE * 1.4, SIZE * 1.4)
		if side == "LEFT" then
			cap:SetPoint("RIGHT", holder, "LEFT", 4, 0)
		else
			cap:SetPoint("LEFT", holder, "RIGHT", -4, 0)
		end
	end
end

for i, cat in ipairs(SLOTS) do
	local b = CreateFrame("Button", "Roth_UIBelt" .. i, holder, "SecureActionButtonTemplate")
	b:SetSize(SIZE, SIZE)
	b:SetPoint("LEFT", holder, "LEFT", (i - 1) * (SIZE + GAP), 0)
	b:RegisterForClicks("AnyDown")
	b:SetAttribute("useOnKeyDown", true)
	b.cat = cat

	local bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetTexture(MEDIA .. "combo_pot_bg")
	bg:SetPoint("CENTER")
	bg:SetSize(SIZE * 1.5, SIZE * 1.5)

	local liquid = CreateFrame("StatusBar", nil, b)
	liquid:SetSize(SIZE * 1.5 * FILL_W, SIZE * 1.5 * FILL_H)
	liquid:SetPoint("CENTER", b, "CENTER", 0, SIZE * 1.5 * FILL_Y)
	liquid:SetOrientation("VERTICAL")
	liquid:SetStatusBarTexture(MEDIA .. "combo_pot_fill1")
	local c = LIQUID[cat]
	liquid:SetStatusBarColor(c[1], c[2], c[3])
	liquid:SetMinMaxValues(0, 1)
	liquid:SetValue(1)
	liquid:SetFrameLevel(b:GetFrameLevel())
	b.liquid = liquid

	local over = CreateFrame("Frame", nil, b)
	over:SetAllPoints(b)
	over:SetFrameLevel(liquid:GetFrameLevel() + 2)

	local icons = Opt("icons", false)
	local icon = over:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	icon:SetSize(SIZE - 14, SIZE - 14)
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	icon:SetShown(icons)
	b.icon = icon

	local cd = CreateFrame("Cooldown", nil, over, "CooldownFrameTemplate")
	cd:SetAllPoints(icon)
	cd:SetDrawEdge(false)
	cd:SetAlpha(icons and 1 or 0)
	b.cooldown = cd
	local border = over:CreateTexture(nil, "OVERLAY", nil, -2)
	border:SetTexture(MEDIA .. "combo_pot_border")
	border:SetPoint("CENTER")
	border:SetSize(SIZE * 1.5, SIZE * 1.5)
	local gloss = over:CreateTexture(nil, "OVERLAY", nil, -1)
	gloss:SetTexture(MEDIA .. "combo_pot_highlight")
	gloss:SetAllPoints(border)
	gloss:SetBlendMode("ADD")
	gloss:SetAlpha(0.5)

	local count = over:CreateFontString(nil, "OVERLAY")
	count:SetFont(cfg.font, 12, "THINOUTLINE")
	count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
	count:SetTextColor(1, 0.9, 0.7)
	b.count = count

	local key = over:CreateFontString(nil, "OVERLAY")
	key:SetFont(cfg.font, 10, "THINOUTLINE")
	key:SetPoint("TOPLEFT", b, "TOPLEFT", 1, 0)
	key:SetTextColor(0.7, 0.6, 0.5)
	b.key = key

	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(MEDIA .. "combo_pot_glow")
	hl:SetAllPoints(border)
	hl:SetBlendMode("ADD")

	b:SetScript("OnEnter", function(self)
		if self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetItemByID(self.itemID)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	Belt.buttons[i] = b
end

local function Num(v)
	if Secrets then
		return Secrets.Number(v)
	end
	return type(v) == "number" and v or nil
end

local function Level(b, now)
	if (b.have or 0) == 0 then
		return 0, false
	end
	local start, duration = b.cdStart, b.cdDuration
	if start and duration and duration > 1.5 then
		local p = (now - start) / duration
		if p < 1 then
			return math.max(0, p), true
		end
	end
	return 1, false
end

local driver = CreateFrame("Frame", nil, holder)
driver:Hide()
driver:SetScript("OnUpdate", function()
	local now, running = GetTime(), false
	for _, b in ipairs(Belt.buttons) do
		local v, busy = Level(b, now)
		b.liquid:SetValue(v)
		running = running or busy
	end
	if not running then
		driver:Hide()
	end
end)

function Belt:Update()
	for _, b in ipairs(self.buttons) do
		local id = b.itemID
		b.cdStart, b.cdDuration = nil, nil
		if id then
			local n = Num(C_Item.GetItemCount(id, false, true)) or 0
			b.have = n
			b.count:SetText(n > 1 and n or "")
			b.icon:SetDesaturated(n == 0)
			local start, duration, enable = C_Container.GetItemCooldown(id)
			start, duration, enable = Num(start), Num(duration), Num(enable)
			if enable and enable ~= 0 and start and duration and duration > 0 then
				b.cdStart, b.cdDuration = start, duration
				b.cooldown:SetCooldown(start, duration)
			else
				b.cooldown:Clear()
			end
		else
			b.have = 0
			b.count:SetText("")
			b.cooldown:Clear()
		end
		local v = Level(b, GetTime())
		b.liquid:SetValue(v)
		local c = LIQUID[b.cat]
		if (b.have or 0) == 0 then
			b.liquid:SetStatusBarColor(0.3, 0.3, 0.3)
		else
			b.liquid:SetStatusBarColor(c[1], c[2], c[3])
		end
		local bound = GetBindingKey("CLICK " .. b:GetName() .. ":LeftButton")
		b.key:SetText(bound and GetBindingText(bound, true) or "")
	end
	driver:Show()
end

function Belt:Refresh()
	if InCombatLockdown() then
		self.pending = true
		return
	end
	self.pending = false
	local best = self:ScanBags()
	for _, b in ipairs(self.buttons) do
		local entry = best[b.cat]
		b.itemID = entry and entry.itemID or nil
		b:SetAttribute("type", entry and "item" or nil)
		b:SetAttribute("item", entry and entry.value or nil)
		b.icon:SetTexture(entry and entry.icon or nil)
	end
	Place()
	local prof = ns.LayoutProfile and ns.LayoutProfile()
	local disabled = prof and prof.disabledElements and prof.disabledElements["Roth_UIBelt"]
	holder:SetShown(not disabled and Opt("show", true))
	self:Update()
end

Belt.Place = Place

function Belt.SetShown(shown)
	if not InCombatLockdown() then
		holder:SetShown(shown)
	end
end

-- Edit Mode integration
do
	local box = holder:CreateTexture(nil, "OVERLAY", nil, 7)
	box:SetPoint("TOPLEFT", -10, 10)
	box:SetPoint("BOTTOMRIGHT", 10, -10)
	box:SetColorTexture(0, 1, 0, 0.2)
	box:Hide()
	holder:SetMovable(true)
	holder:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	holder:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if ns.EditMode and ns.EditMode.SaveFramePosition then
			ns.EditMode:SaveFramePosition(self)
		end
		if ns.EditMode and ns.EditMode.UpdateDialog then
			ns.EditMode:UpdateDialog()
		end
	end)
	function Belt.SetEditing(on)
		box:SetShown(on)
		holder:EnableMouse(on)
		if on then
			holder:RegisterForDrag("LeftButton")
		else
			holder:RegisterForDrag()
		end
		for _, b in ipairs(Belt.buttons) do
			b:EnableMouse(not on)
		end
	end
end

local events = CreateFrame("Frame")
for _, e in ipairs({
	"PLAYER_ENTERING_WORLD",
	"BAG_UPDATE_DELAYED",
	"GET_ITEM_INFO_RECEIVED",
	"PLAYER_REGEN_ENABLED",
	"BAG_UPDATE_COOLDOWN",
	"UPDATE_BINDINGS",
}) do
	events:RegisterEvent(e)
end
local queued = false
events:SetScript("OnEvent", function(_, event)
	if event == "BAG_UPDATE_COOLDOWN" or event == "UPDATE_BINDINGS" then
		Belt:Update()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if Belt.pending then
			Belt:Refresh()
		end
	elseif not queued then
		queued = true
		C_Timer.After(0.3, function()
			queued = false
			Belt:Refresh()
			Belt:Update()
		end)
	end
end)

_G["BINDING_HEADER_DIABOLUSUNITS"] = "DiabolusUnits"
for i = 1, #SLOTS do
	_G["BINDING_NAME_CLICK Roth_UIBelt" .. i .. ":LeftButton"] = "Belt " .. i
end
