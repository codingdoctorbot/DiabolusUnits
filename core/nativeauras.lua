---------------------------------------------
--  Roth_UI - auras drawn by the client (in combat too)
---------------------------------------------
-- In combat WoW Forever hands add-on code the auras of most units as secret
-- values: C_UnitAuras.GetAuraDataByIndex returns a secret table (or secret
-- fields, a secret auraInstanceID among them), and the calls that would turn
-- an instance ID into a duration or a dispel colour refuse secret arguments
-- from add-on code (SecretArguments = "AllowedWhenUntainted"). A Lua aura
-- row can then show nothing: Moonfire on an enemy and Rejuvenation on a
-- friendly target vanished as soon as combat started (client test
-- 2026-10-16 22:51).
--
-- oUF 14's Auras element is the client's own aura container
-- (Blizzard_AuraContainer, CustomAuraContainerTemplate): it reads the auras
-- itself and fills buttons we style once, at creation: icon, swipe, stack
-- count and the debuff border coloured by dispel type all keep working while
-- the values are secret. oUF hands it the frame's unit on every full update
-- (target / focus change, header reassignment, the eventless units' timer).
-- Each unit frame's Buffs / Debuffs row is built here from the layout's
-- settings (size, spacing, holder, growth, number, "only mine", blacklist).
--
-- Limits of the container (not ours to change): its buttons refuse add-on
-- code while auras are secret, so they are styled only in initializeFrame;
-- other frames must not be anchored to the container (it resizes itself
-- with untrusted layout scripts forbidden). Each row therefore hangs from a
-- plain holder frame the layout places; the container sits in the holder's
-- initialAnchor corner.

local _, ns = ...

local cfg = ns.cfg

local NativeAuras = {}
ns.NativeAuras = NativeAuras

local MEDIA = "Interface\\AddOns\\DiabolusUnits\\media\\"

-- The Diablo look: gloss rim, dark glow behind, stack count top right, the
-- client's countdown numbers (our timer text cannot read a secret duration).
local function StyleButton(button, size, opts)
	button:SetSize(size, size)

	local back = button:CreateTexture(nil, "BACKGROUND")
	back:SetPoint("TOPLEFT", button, "TOPLEFT", -0.18 * size, 0.18 * size)
	back:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0.18 * size, -0.18 * size)
	back:SetTexture(MEDIA .. "simplesquare_glow")
	back:SetVertexColor(0, 0, 0, 1)

	local icon = button:CreateTexture(nil, "BORDER")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

	local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cd:SetPoint("TOPLEFT", 1, -1)
	cd:SetPoint("BOTTOMRIGHT", -1, 1)
	cd:SetReverse(true)
	if cd.SetHideCountdownNumbers then
		cd:SetHideCountdownNumbers(false)
	end

	local top = CreateFrame("Frame", nil, button)
	top:SetAllPoints(button)
	top:SetFrameLevel(cd:GetFrameLevel() + 2)

	local gloss = top:CreateTexture(nil, "ARTWORK")
	gloss:SetTexture(MEDIA .. "gloss2")
	gloss:SetPoint("TOPLEFT", -1, 1)
	gloss:SetPoint("BOTTOMRIGHT", 1, -1)
	gloss:SetVertexColor(0.4, 0.35, 0.35, 1)

	local count = top:CreateFontString(nil, "OVERLAY")
	count:SetFont(cfg.font, size / 1.8, "THINOUTLINE")
	count:SetPoint("TOPRIGHT", 4, 4)
	count:SetTextColor(0.9, 0.9, 0.9)

	button:SetIcon(icon)
	button:SetDurationCooldown(cd)
	button:SetApplicationCount(count)

	local style = Enum.CustomAuraButtonDispelTypeTextureStyle
	if opts.showType then
		-- oUF 1.x's debuff frame art; the client tints it by dispel type
		local border = top:CreateTexture(nil, "OVERLAY")
		border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		border:SetAllPoints(button)
		button:AddDispelTypeTexture(border, {
			style = style and style.PreserveAsset,
			showWithoutDispelType = true,
		})
	end

	if opts.stealable then
		local stealable = top:CreateTexture(nil, "OVERLAY", nil, 1)
		stealable:SetPoint("TOPLEFT", -3, 3)
		stealable:SetPoint("BOTTOMRIGHT", 3, -3)
		stealable:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
		stealable:SetBlendMode("ADD")
		local filter = Enum.CustomAuraButtonDispelTypeStealableFilter
		button:AddDispelTypeTexture(stealable, {
			style = style and style.PreserveAsset,
			showWhenHelpful = true,
			showWithoutDispelType = true,
			stealableFilter = filter and filter.Stealable,
		})
	end

	if button.SetTooltipAnchorPoint then
		button:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT")
	end
	return count
end

local rows = {}

local function Anchor(row, initialAnchor, growthX, growthY)
	local element = row.element
	element:ClearAllPoints()
	element:SetPoint(initialAnchor, row.holder, initialAnchor)
	element:SetFlowLayoutAnchorPoint(initialAnchor)
	local FLOW = AnchorUtil.FlowDirection
	element:SetFlowLayoutGrowthDirection(
		growthX == "LEFT" and FLOW.Left or FLOW.Right,
		growthY == "UP" and FLOW.Up or FLOW.Down
	)
end

local function Find(frame, key)
	for _, row in ipairs(rows) do
		if row.frame == frame and row.key == key then
			return row
		end
	end
end

-- Builds frame[key] ("Buffs" / "Debuffs"), an oUF Auras element, from the
-- frame's style function (oUF enables it right after). holder: a plain frame
-- the layout placed and sized; the row fills it from its initialAnchor
-- corner and wraps at its width.
--   opts.filter          aura filter ("HELPFUL", "HARMFUL|RAID_IN_COMBAT", ...)
--   opts.onlyShowPlayer  add "|PLAYER" to the filter
--   opts.size, .spacing, .num
--   opts.initialAnchor, .growthX ("LEFT"/"RIGHT"), .growthY ("UP"/"DOWN")
--   opts.showType        dispel-type border; opts.stealable: stealable glow
--   opts.excludeSpellIDs set of spell IDs never shown (checked by the client)
function NativeAuras.Create(frame, key, holder, opts)
	local size = opts.size or 16
	local spacing = opts.spacing or 0
	local filter = opts.filter or (key == "Debuffs" and "HARMFUL" or "HELPFUL")
	if opts.onlyShowPlayer then
		filter = filter .. "|PLAYER"
	end

	local element = frame:CreateAuras()
	-- Edit Mode would fill it with made-up auras
	if element.SetEditModePreviewEnabled then
		element:SetEditModePreviewEnabled(false)
	end
	local width = holder:GetWidth()
	if width and width > size then
		element:SetFlowLayoutMaximumLineSize(width)
	end

	-- size can change later (Edit layout's aura icon size, NativeAuras.SetSize)
	local row = { frame = frame, key = key, holder = holder, element = element, size = size, spacing = spacing }
	row.buttons = {}
	local candidateFilters
	if opts.excludeSpellIDs and next(opts.excludeSpellIDs) then
		candidateFilters = { excludeSpellIDs = opts.excludeSpellIDs }
	end
	row.group = element:AddGroup(filter, {
		maxFrameCount = opts.num or 40,
		candidateFilters = candidateFilters,
		layout = { elementSpacing = spacing, lineSpacing = spacing, elementWidth = size, elementHeight = size },
		initializeFrame = function(button)
			row.buttons[button] = StyleButton(button, row.size, opts)
		end,
	})
	rows[#rows + 1] = row
	Anchor(row, opts.initialAnchor or "BOTTOMLEFT", opts.growthX, opts.growthY)

	-- the holder only places the row
	holder:Hide()
	element.holder = holder
	frame[key] = element
	return element
end

-- Re-anchors a row in its holder (after the layout moved the holder).
function NativeAuras.SetFlow(frame, key, initialAnchor, growthX, growthY)
	local row = Find(frame, key)
	if row then
		Anchor(row, initialAnchor, growthX, growthY)
		-- (from a style function the row has no unit yet; oUF updates it when enabled)
		if row.element:GetUnit() then
			row.element:ForceUpdate()
		end
	end
end

-- For /roth auras: icons the row shows now.
function NativeAuras.Count(frame, key)
	local row = Find(frame, key)
	if not (row and row.element.GetAuraGroupFrameCount) then
		return nil
	end
	local ok, n = pcall(row.element.GetAuraGroupFrameCount, row.element, row.group)
	return ok and n or nil
end

-- New icon size for a row: the layout takes it at once, the buttons made so
-- far are resized out of combat (they refuse add-on code while auras are
-- secret), new ones are made at the new size.
function NativeAuras.SetSize(frame, key, size)
	local row = Find(frame, key)
	if not row then
		return false
	end
	row.size = size
	pcall(row.element.SetAuraGroupLayout, row.element, row.group, {
		elementSpacing = row.spacing,
		lineSpacing = row.spacing,
		elementWidth = size,
		elementHeight = size,
	})
	if not InCombatLockdown() then
		for button, count in pairs(row.buttons) do
			pcall(button.SetSize, button, size, size)
			if count then
				pcall(count.SetFont, count, cfg.font, size / 1.8, "THINOUTLINE")
			end
		end
	end
	return true
end

---------------------------------------------
-- AURA ICON SIZE (Edit layout's per-frame option)
---------------------------------------------
-- One size per frame, saved in the layout profile's resizeOptions (the keys
-- the old settings page used, so earlier choices carry over). Applied again
-- at every login.
local AuraSize = {}
ns.AuraSize = AuraSize

local KEYS = { target = "targetDebuffSize", focus = "focusAuraSize", targettarget = "totAuraSize" }
local FRAMES = { target = "Roth_UITargetFrame", focus = "Roth_UIFocusFrame", targettarget = "Roth_UITargetTargetFrame" }

local function Options()
	local prof = ns.LayoutProfile and ns.LayoutProfile()
	if prof then
		prof.resizeOptions = prof.resizeOptions or {}
		return prof.resizeOptions
	end
end

function AuraSize.Get(unit)
	local o = Options()
	local v = o and o[KEYS[unit]]
	if type(v) == "number" then
		return v
	end
	local u = cfg.units and cfg.units[unit]
	return (u and u.auras and u.auras.size) or 22
end

local function Apply(unit, size)
	local frame = rawget(_G, FRAMES[unit] or "")
	if not frame then
		return
	end
	NativeAuras.SetSize(frame, "Buffs", size)
	NativeAuras.SetSize(frame, "Debuffs", size)
end

function AuraSize.Set(unit, size)
	if not KEYS[unit] then
		return
	end
	size = math.max(12, math.min(40, math.floor(size + 0.5)))
	local o = Options()
	if o then
		o[KEYS[unit]] = size
	end
	Apply(unit, size)
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
	for unit in pairs(KEYS) do
		local o = Options()
		if o and type(o[KEYS[unit]]) == "number" then
			Apply(unit, o[KEYS[unit]])
		end
	end
end)
