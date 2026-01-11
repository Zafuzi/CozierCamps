local smoothedThirstDisplay = nil
local THIRST_DISPLAY_LERP_SPEED = 3.0 -- How fast display catches up to actual value

-- Update thirst meter
-- TODO: move to draw / update calls and remove dependence on platform where you can
function UpdateThirstMeter(elapsed)
	if not ThirstMeter or not Addon.thirstCache then
		return
	end

	local thirst = 100 - (Addon.thirstCache.current or 0)

	-- Smooth the display value to prevent flickering from exhaustion-scaled calculations
	local targetDisplay = thirst
	if smoothedThirstDisplay == nil then
		smoothedThirstDisplay = targetDisplay
	else
		-- Lerp toward target value
		local diff = targetDisplay - smoothedThirstDisplay
		smoothedThirstDisplay = smoothedThirstDisplay + diff * math.min(1, THIRST_DISPLAY_LERP_SPEED * elapsed)
	end
	local displayValue = smoothedThirstDisplay

	-- Update bar value (inverted: full bar = 0% thirst, empty bar = 100% thirst)
	ThirstMeter.bar:SetValue(displayValue)
end
