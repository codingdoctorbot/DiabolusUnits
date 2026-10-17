local _, ns = ...
local oUF = ns.oUF or oUF
local Secrets = ns.Secrets

local smoothing = {}
Roth_UI_Protection = Roth_UI_Protection or {}

local function Smooth(self, value)
	local cur = self:GetValue()
	if Secrets and (Secrets.IsSecret(value) or Secrets.IsSecret(cur)) then
		smoothing[self] = nil
		if Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut then
			self:SetValue_(value, Enum.StatusBarInterpolation.ExponentialEaseOut)
		else
			self:SetValue_(value)
		end
		return
	end
	if value ~= cur or value == 0 then
		smoothing[self] = value
	else
		smoothing[self] = nil
	end
end

local function InstantSet(self, value)
	smoothing[self] = nil
	self:SetValue_(value)
end

local function SmoothBar(self, bar)
	bar.SetValue_ = bar.SetValue
	bar.SetValue = Smooth
	bar.SetValueInstant = InstantSet
end

local function hook(frame)
	frame.SmoothBar = SmoothBar
	if frame.Health and frame.Health.Smooth then
		frame:SmoothBar(frame.Health)
	end
	if frame.Power and frame.Power.Smooth then
		frame:SmoothBar(frame.Power)
	end
	if frame.TotalAbsorb and frame.TotalAbsorb.Smooth then
		frame:SmoothBar(frame.TotalAbsorb)
	end

	local unit = frame.unit
	if unit == "target" or unit == "focus" then
		local snapEvent = unit == "target" and "PLAYER_TARGET_CHANGED" or "PLAYER_FOCUS_CHANGED"
		local snapFrame = CreateFrame("Frame")
		snapFrame:RegisterEvent(snapEvent)
		snapFrame:SetScript("OnEvent", function()
			if frame.Health and frame.Health.SetValueInstant then
				local hp = UnitHealth(unit)
				local hpMax = UnitHealthMax(unit)
				if not (Secrets and Secrets.Present(hp)) then
					hp = 0
				end
				if not (Secrets and Secrets.Present(hpMax)) then
					hpMax = 1
				end
				frame.Health:SetMinMaxValues(0, hpMax)
				frame.Health:SetValueInstant(hp)
			end
			if frame.Power and frame.Power.SetValueInstant then
				local pp = UnitPower(unit)
				local ppMax = UnitPowerMax(unit)
				if not (Secrets and Secrets.Present(pp)) then
					pp = 0
				end
				if not (Secrets and Secrets.Present(ppMax)) then
					ppMax = 1
				end
				frame.Power:SetMinMaxValues(0, ppMax)
				frame.Power:SetValueInstant(pp)
			end
			if frame.TotalAbsorb and frame.TotalAbsorb.SetValueInstant then
				local absorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)
				local hpMax = UnitHealthMax(unit)
				if not (Secrets and Secrets.Present(absorb)) then
					absorb = 0
				end
				if not (Secrets and Secrets.Present(hpMax)) then
					hpMax = 1
				end
				frame.TotalAbsorb:SetMinMaxValues(0, hpMax)
				frame.TotalAbsorb:SetValueInstant(absorb)
			end
		end)
	end
end

for i, frame in ipairs(oUF.objects) do
	hook(frame)
end
oUF:RegisterInitCallback(hook)

local f, min, max, abs = CreateFrame("Frame"), math.min, math.max, math.abs
local lastUpdate, div, new, cur = 0, 15, 0, 0
f:SetScript("OnUpdate", function(self, elapsed)
	if Roth_UI_Protection.isLoggingOut then
		return
	end
	if next(smoothing) == nil then
		return
	end
	lastUpdate = lastUpdate + elapsed
	if lastUpdate > 1 then
		div = 15 * GetFramerate() / 30
		lastUpdate = 0
	end
	for bar, value in pairs(smoothing) do
		cur = bar:GetValue()
		if Secrets and (Secrets.IsSecret(value) or Secrets.IsSecret(cur)) then
			smoothing[bar] = nil
			if Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut then
				bar:SetValue_(value, Enum.StatusBarInterpolation.ExponentialEaseOut)
			else
				bar:SetValue_(value)
			end
		else
			new = cur + (value - cur) / div
			bar:SetValue_(new)
			if cur == value or abs(cur - value) < 1 then
				bar:SetValue_(value)
				smoothing[bar] = nil
			end
		end
	end
end)
