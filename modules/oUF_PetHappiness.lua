--[[
# Element: Pet Happiness

Toggles the visibility of an indicator based on the Pets Happiness

## Widget

.texture - A `Texture` used to display the group role icon.

PetHappiness - A `Frame` used to display the group role icon.

## Notes

A default texture will be applied if the widget is a Texture and doesn't have a texture or a color set.

oUF Element: .PetHappiness

Options regarding visual layout:
	-	<element>.Texture
		Texture to display the pets happiness

	- <element>.Override

## Examples

    -- Position and size
    local PetHappiness = CreateFrame('Frame', nil, self)
	PetHappiness:SetSize(16, 16)

    -- Register it with oUF
    self.PetHappiness = PetHappiness
--]]
local _, ns = ...
local oUF = (ns.oUF or oUF) or (ns.SUF or SUF)
local Secrets = ns.Secrets
assert(oUF, "oUF_PetHappiness was unable to locate oUF install.")

local function Update(self, event)
	local element = self.PetHappiness
	if not element then
		return
	end

	--[[ Callback: PetHappiness:PreUpdate()
	Called before the element has been updated.

	* self - the PetHappiness element
	--]]
	if element.PreUpdate then
		element:PreUpdate()
	end

	if self.unit ~= "pet" then
		return
	end

	-- WoW Forever has only C_PetInfo.GetPetHappiness (the global GetPetHappiness is gone,
	-- which kept this hidden); Blizzard_FrameXML/PetHappiness.lua reads it the same way
	local happiness, damagePercentage, loyaltyRate
	local get = (C_PetInfo and C_PetInfo.GetPetHappiness) or rawget(_G, "GetPetHappiness")
	if get then
		happiness, damagePercentage, loyaltyRate = get()
	end
	local hasPetUI = false
	if type(HasPetUI) == "function" then
		local _, hpUI = HasPetUI()
		hasPetUI = Secrets and Secrets.Boolean(hpUI, false) or (hpUI == true)
	end

	local happyNum = Secrets and Secrets.Number(happiness) or (type(happiness) == "number" and happiness or nil)
	local dmgNum = Secrets and Secrets.Number(damagePercentage)
		or (type(damagePercentage) == "number" and damagePercentage or nil)
	local loyNum = Secrets and Secrets.Number(loyaltyRate) or (type(loyaltyRate) == "number" and loyaltyRate or nil)

	if hasPetUI and happyNum and happyNum >= 1 and happyNum <= 3 then
		if happyNum == 1 then
			element.texture:SetTexCoord(0.375, 0.5625, 0, 0.359375)
		elseif happyNum == 2 then
			element.texture:SetTexCoord(0.1875, 0.375, 0, 0.359375)
		elseif happyNum == 3 then
			element.texture:SetTexCoord(0, 0.1875, 0, 0.359375)
		end

		element.tooltip = _G["PET_HAPPINESS" .. happyNum] or ("Happiness " .. happyNum)
		-- what the pet eats, as Blizzard's indicator shows it
		local diet = C_PetInfo and C_PetInfo.GetPetFoodTypes and C_PetInfo.GetPetFoodTypes()
		if type(diet) == "table" and #diet > 0 and _G.PET_DIET_TEMPLATE then
			element.tooltipDiet = format(_G.PET_DIET_TEMPLATE, table.concat(diet, _G.PET_FOOD_DELIMIT or ", "))
		else
			element.tooltipDiet = nil
		end
		if dmgNum and _G.PET_DAMAGE_PERCENTAGE then
			element.tooltipDamage = format(_G.PET_DAMAGE_PERCENTAGE, dmgNum)
		else
			element.tooltipDamage = nil
		end
		if loyNum and loyNum < 0 then
			element.tooltipLoyalty = _G["LOSING_LOYALTY"]
		elseif loyNum and loyNum > 0 then
			element.tooltipLoyalty = _G["GAINING_LOYALTY"]
		else
			element.tooltipLoyalty = nil
		end

		element:Show()
	else
		element:Hide()
	end

	--[[ Callback: PetHappiness:PostUpdate(role)
	Called after the element has been updated.

	* self - the PetHappiness element
	* unit      - the unit for which the update has been triggered (string)
	* happiness        - the numerical happiness value of the pet (1 = unhappy, 2 = content, 3 = happy) (number)
	* damagePercentage - damage modifier, happiness affects this (unhappy = 75%, content = 100%, happy = 125%) (number)
	--]]
	if element.PostUpdate then
		return element:PostUpdate(self.unit, happiness, damagePercentage)
	end
end

local function Path(self, ...)
	--[[ Override: PetHappiness.Override(self, event, ...)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* ...   - the arguments accompanying the event
	--]]
	return (self.PetHappiness.Override or Update)(self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, "ForceUpdate")
end

local function Enable(self)
	local element = self.PetHappiness
	if element then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		if self.unit == "pet" then
			self:RegisterEvent("UNIT_HAPPINESS", Path, true)
			self:RegisterEvent("PET_UI_UPDATE", Path, true)
			-- a newly summoned pet: the frame's unit does not change, so oUF does not update
			self:RegisterEvent("UNIT_PET", Path, true)
		else
			return
		end

		if not element.texture then
			element.texture = element:CreateTexture(nil, "OVERLAY")
			element.texture:SetAllPoints(element)
		end

		if element.texture:IsObjectType("Texture") and not element.texture:GetTexture() then
			element.texture:SetTexture([[Interface\PetPaperDollFrame\UI-PetHappiness]])
		end

		element:SetScript("OnEnter", function()
			local element = self.PetHappiness
			if element.tooltip then
				GameTooltip:SetOwner(element, "ANCHOR_RIGHT")
				GameTooltip:SetText(element.tooltip)
				if element.tooltipDamage then
					GameTooltip:AddLine(element.tooltipDamage, "", 1, 1, 1)
				end
				if element.tooltipLoyalty then
					GameTooltip:AddLine(element.tooltipLoyalty, "", 1, 1, 1)
				end
				if element.tooltipDiet then
					GameTooltip:AddLine(element.tooltipDiet, 1, 1, 1, true)
				end
				GameTooltip:Show()
			end
		end)

		element:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		return true
	end
end

local function Disable(self)
	local element = self.PetHappiness
	if element then
		element:Hide()

		self:UnregisterEvent("UNIT_HAPPINESS", Path)
		self:UnregisterEvent("PET_UI_UPDATE", Path)
		self:UnregisterEvent("UNIT_PET", Path)
	end
end

oUF:AddElement("PetHappiness", Path, Enable, Disable)
