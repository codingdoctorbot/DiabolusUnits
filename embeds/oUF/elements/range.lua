--[[ Element: Range Fader

 Widget

 Range - A table containing opacity values.

 Options

 .outsideAlpha - Opacity when the unit is out of range. Values 0 (fully
                 transparent) - 1 (fully opaque).
 .insideAlpha  - Opacity when the unit is within range. Values 0 (fully
                 transparent) - 1 (fully opaque).

 Examples

   -- Register with oUF
   self.Range = {
      insideAlpha = 1,
      outsideAlpha = 1/2,
   }

 Hooks

]]

local parent, ns = ...
local oUF = ns.oUF
local Secrets = ns.Secrets

local _FRAMES = {}
local OnRangeFrame

local UnitInRange, UnitIsConnected = UnitInRange, UnitIsConnected

-- updating of range.
local timer = 0
local OnRangeUpdate = function(self, elapsed)
	timer = timer + elapsed

	if(timer >= .20) then
		for _, object in next, _FRAMES do
			if(object:IsShown()) then
				local range = object.Range
				local isConnected = Secrets.Bool(UnitIsConnected, object.unit)
				if(isConnected) then
					local inRange, checkedRange = UnitInRange(object.unit)
					if(Secrets.IsSecret(inRange) or Secrets.IsSecret(checkedRange)) then
						if(range.Override) then
							range.Override(object, 'inside')
						elseif(object.SetAlphaFromBoolean) then
							object:SetAlphaFromBoolean(inRange, range.insideAlpha, range.outsideAlpha)
						elseif(C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean) then
							object:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(inRange, range.insideAlpha, range.outsideAlpha))
						else
							object:SetAlpha(range.insideAlpha)
						end
					elseif(checkedRange and not inRange) then
						if(range.Override) then
							range.Override(object, 'outside')
						else
							object:SetAlpha(range.outsideAlpha)
						end
					else
						if(range.Override) then
							range.Override(object, 'inside')
						else
							object:SetAlpha(range.insideAlpha)
						end
					end
				else
					if(range.Override) then
						range.Override(object, 'offline')
					else
						object:SetAlpha(range.insideAlpha)
					end
				end
			end
		end

		timer = 0
	end
end

local Enable = function(self)
	local range = self.Range
	if(range and range.insideAlpha and range.outsideAlpha) then
		table.insert(_FRAMES, self)

		if(not OnRangeFrame) then
			OnRangeFrame = CreateFrame"Frame"
			OnRangeFrame:SetScript("OnUpdate", OnRangeUpdate)
		end

		OnRangeFrame:Show()

		return true
	end
end

local Disable = function(self)
	local range = self.Range
	if(range) then
		for k, frame in next, _FRAMES do
			if(frame == self) then
				table.remove(_FRAMES, k)
				break
			end
		end
		self:SetAlpha(1)

		if(#_FRAMES == 0) then
			OnRangeFrame:Hide()
		end
	end
end

if oUF and oUF.AddElement then
	oUF:AddElement('Range', nil, Enable, Disable)
end
