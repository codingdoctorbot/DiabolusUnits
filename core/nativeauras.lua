---------------------------------------------
--  Roth_UI - auras drawn by the client (in combat too)
---------------------------------------------
-- In combat WoW Forever hands add-on code the auras of most units as secret
-- values: C_UnitAuras.GetAuraDataByIndex returns a secret table (or secret
-- fields, a secret auraInstanceID among them), and the calls that would turn
-- an instance ID into a duration or a dispel colour refuse secret arguments
-- from add-on code (SecretArguments = "AllowedWhenUntainted"). oUF's aura
-- element can then show nothing: Moonfire on an enemy and Rejuvenation on a
-- friendly target vanished as soon as combat started (client test
-- 2026-10-16 22:51).
--
-- The client's own aura container (Blizzard_AuraContainer,
-- CustomAuraContainerTemplate) reads the auras itself and fills buttons we
-- style once, at creation: icon, swipe, stack count and the debuff border
-- coloured by dispel type all keep working while the values are secret.
-- Here the oUF Buffs / Debuffs rows of a unit frame are replaced by such a
-- container, laid out from the same settings (size, spacing, anchor,
-- growth, number, "only mine"). Clients without the template keep oUF's
-- rows unchanged.
--
-- Limits of the container (not ours to change): its buttons refuse add-on
-- code while auras are secret, so they are styled only in initializeFrame;
-- other frames must not be anchored to the container (it resizes itself
-- with untrusted layout scripts forbidden).

local _, ns = ...

local cfg = ns.cfg

local NativeAuras = {}
ns.NativeAuras = NativeAuras

local TEMPLATE = "CustomAuraContainerTemplate"
local NEEDED = {
	"SetUnit",
	"UpdateAllAuras",
	"AddAuraGroup",
	"SetFlowLayoutAnchorPoint",
	"SetFlowLayoutGrowthDirection",
	"SetFlowLayoutMaximumLineSize",
}

local supported

-- One hidden test container, made once per session.
function NativeAuras.Supported()
	if supported == nil then
		supported = false
		local ok, probe = pcall(CreateFrame, "AuraContainer", nil, UIParent, TEMPLATE)
		if ok and type(probe) == "table" then
			probe:Hide()
			supported = true
			for _, method in ipairs(NEEDED) do
				if type(probe[method]) ~= "function" then
					supported = false
				end
			end
		end
	end
	return supported
end

-- Diablo look, as func.createAuraIcon gives oUF's icons (core/lib.lua).
local function StyleButton(button, size, isDebuff, showType)
	button:SetSize(size, size)

	local icon = button:CreateTexture(nil, "BORDER")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

	local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cd:SetPoint("TOPLEFT", 1, -1)
	cd:SetPoint("BOTTOMRIGHT", -1, 1)
	cd:SetReverse(true)
	-- the client's own countdown numbers: our timer text cannot read a secret duration
	if cd.SetHideCountdownNumbers then
		cd:SetHideCountdownNumbers(false)
	end

	local top = CreateFrame("Frame", nil, button)
	top:SetAllPoints(button)
	top:SetFrameLevel(cd:GetFrameLevel() + 2)
	local count = top:CreateFontString(nil, "OVERLAY")
	count:SetFont(cfg.font, size / 1.8, "THINOUTLINE")
	count:SetPoint("TOPRIGHT", 4, 4)
	count:SetTextColor(0.9, 0.9, 0.9)

	button:SetIcon(icon)
	button:SetDurationCooldown(cd)
	button:SetApplicationCount(count)

	if isDebuff and showType then
		-- oUF's debuff frame art; the client tints it by dispel type
		local border = top:CreateTexture(nil, "OVERLAY")
		border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		border:SetAllPoints(button)
		local style = Enum.CustomAuraButtonDispelTypeTextureStyle
		button:AddDispelTypeTexture(border, {
			style = style and style.PreserveAsset,
			showWithoutDispelType = true,
		})
	end

	if button.SetTooltipAnchorPoint then
		button:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT")
	end
	return count
end

-- oUF's growth settings -> the container's flow.
local function Flow(element)
	local FLOW = AnchorUtil.FlowDirection
	local h = element["growth-x"] == "LEFT" and FLOW.Left or FLOW.Right
	local v = element["growth-y"] == "UP" and FLOW.Up or FLOW.Down
	return element.initialAnchor or "BOTTOMLEFT", h, v
end

local containers = {}

-- Replaces unitFrame[key] ("Buffs" / "Debuffs", made but not yet enabled by
-- oUF, i.e. called from the style function) with a client aura container in
-- the same place, reading unit (oUF sets unitFrame.unit only after the style
-- function). Returns the container, or nil when the client has none (the
-- oUF row then stays).
function NativeAuras.Replace(unitFrame, key, unit)
	local element = unitFrame[key]
	local anchorUtil = rawget(_G, "AnchorUtil")
	if not (element and anchorUtil and anchorUtil.FlowDirection and NativeAuras.Supported()) then
		return nil
	end
	local isDebuff = key == "Debuffs"
	local size = element.size or 16
	local spacing = element.spacing or 0
	local filter = element.filter or (isDebuff and "HARMFUL" or "HELPFUL")
	if element.onlyShowPlayer then
		filter = filter .. "|PLAYER"
	end
	local showType = (isDebuff and element.showDebuffType)
		or (not isDebuff and element.showBuffType)
		or element.showType

	local ok, container = pcall(CreateFrame, "AuraContainer", nil, unitFrame, TEMPLATE)
	if not ok or type(container) ~= "table" then
		return nil
	end
	-- Edit Mode would fill it with made-up auras
	if container.SetEditModePreviewEnabled then
		container:SetEditModePreviewEnabled(false)
	end

	local anchor, h, v = Flow(element)
	container:SetPoint(anchor, element, anchor)
	container:SetFlowLayoutAnchorPoint(anchor)
	container:SetFlowLayoutGrowthDirection(h, v)
	local width = element:GetWidth()
	if width and width > size then
		container:SetFlowLayoutMaximumLineSize(width)
	end

	-- size can change later (Edit layout's aura icon size, NativeAuras.SetSize)
	local entry = { container = container, frame = unitFrame, key = key, size = size, spacing = spacing, buttons = {} }
	container:AddAuraGroup(key, filter, {
		maxFrameCount = element.num or 40,
		layout = { elementSpacing = spacing, lineSpacing = spacing, elementWidth = size, elementHeight = size },
		initializeFrame = function(button)
			entry.buttons[button] = StyleButton(button, entry.size, isDebuff, showType)
		end,
	})
	container:SetUnit(unit or unitFrame.unit or "none")

	-- oUF never sees the row; its frame stays as the container's anchor
	element:Hide()
	unitFrame[key] = nil
	unitFrame["RothNative" .. key] = container
	containers[#containers + 1] = entry
	return container
end

-- UNIT_AURA is the container's own; a new target / focus / pet behind the
-- same token is not, so it is told to read again.
local refresh = CreateFrame("Frame")
refresh:RegisterEvent("PLAYER_TARGET_CHANGED")
refresh:RegisterEvent("PLAYER_FOCUS_CHANGED")
refresh:RegisterUnitEvent("UNIT_PET", "player")
refresh:RegisterEvent("PLAYER_ENTERING_WORLD")
refresh:SetScript("OnEvent", function()
	for _, entry in ipairs(containers) do
		pcall(entry.container.UpdateAllAuras, entry.container)
	end
end)

-- For /roth auras: icons the container shows now.
function NativeAuras.Count(unitFrame, key)
	local container = unitFrame and unitFrame["RothNative" .. key]
	if not (container and container.GetAuraGroupFrameCount) then
		return nil
	end
	local ok, n = pcall(container.GetAuraGroupFrameCount, container, key)
	return ok and n or nil
end

-- New icon size for a client-drawn row: the layout takes it at once, the
-- buttons made so far are resized out of combat (they refuse add-on code
-- while auras are secret), new ones are made at the new size.
function NativeAuras.SetSize(unitFrame, key, size)
	for _, entry in ipairs(containers) do
		if entry.frame == unitFrame and entry.key == key then
			entry.size = size
			pcall(entry.container.SetAuraGroupLayout, entry.container, key, {
				elementSpacing = entry.spacing,
				lineSpacing = entry.spacing,
				elementWidth = size,
				elementHeight = size,
			})
			if not InCombatLockdown() then
				for button, count in pairs(entry.buttons) do
					pcall(button.SetSize, button, size, size)
					if count then
						pcall(count.SetFont, count, cfg.font, size / 1.8, "THINOUTLINE")
					end
				end
			end
			return true
		end
	end
	return false
end

---------------------------------------------
-- AURA ICON SIZE (Edit layout's per-frame option)
---------------------------------------------
-- One size per frame, saved in the layout profile's resizeOptions (the keys
-- the old settings page used, so earlier choices carry over). Applied to the
-- client-drawn rows and to oUF rows alike; again at every login.
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
	for _, key in ipairs({ "Buffs", "Debuffs" }) do
		if not NativeAuras.SetSize(frame, key, size) then
			local element = rawget(frame, key)
			if type(element) == "table" then
				element.size = size
				if element.ForceUpdate then
					element:ForceUpdate()
				end
			end
		end
	end
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
