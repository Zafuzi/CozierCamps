local smoothedHungerDisplay = nil
local HUNGER_DISPLAY_LERP_SPEED = 3.0 -- How fast display catches up to actual value

-- Update hunger meter
function UpdateHungerMeter(elapsed)
	if not HungerMeter or not Addon.hungerCache then
		return
	end

	local hunger = 100 - (Addon.hungerCache.current or 0)

	-- Smooth the display value to prevent flickering from exhaustion-scaled calculations
	local targetDisplay = hunger
	if smoothedHungerDisplay == nil then
		smoothedHungerDisplay = targetDisplay
	else
		-- Lerp toward target value
		local diff = targetDisplay - smoothedHungerDisplay
		smoothedHungerDisplay = smoothedHungerDisplay + diff * math.min(1, HUNGER_DISPLAY_LERP_SPEED * elapsed)
	end
	local displayValue = smoothedHungerDisplay

	-- Update bar value (inverted: full bar = 0% hunger, empty bar = 100% hunger)
	HungerMeter.bar:SetValue(displayValue)
end
