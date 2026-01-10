thirstMeter = CreateMeter("Thirst", UIParent, ICONS.drink, COLORS.THIRST)
thirstMeter:SetPoint("TOPLEFT", hungerMeter, "BOTTOMLEFT", 0, -METER_SPACING)
thirstMeter:Show()
thirstMeter:SetScript("OnUpdate", function(self, elapsed)
	UpdateThirstMeter(elapsed)
end)

local smoothedThirstDisplay = nil
local THIRST_DISPLAY_LERP_SPEED = 3.0 -- How fast display catches up to actual value

-- Update thirst meter
-- TODO: move to draw / update calls and remove dependence on platform where you can
function UpdateThirstMeter(elapsed)
	if not thirstMeter or not Addon.thirstCache then
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

	--local tts = ((100 - Addon.thirstCache.current) / 100) * (Addon.thirstCache.timeToStarveInHours or 1)

	--local tts_hours = 0
	--local tts_min = 0
	--local tts_sec = 0
	--local tts_ms = 0

	--tts_hours, tts_min = math.modf(tts)
	--tts_min, tts_sec = math.modf(tts_min * 60)
	--tts_sec, tts_ms = math.modf(tts_sec * 60)


	-- Update bar value (inverted: full bar = 0% thirst, empty bar = 100% thirst)
	thirstMeter.bar:SetValue(displayValue)

	-- Format percentage text
	-- Both bar and vial modes show inverted value (100 = full/good, 0 = empty/bad)
	-- This matches the inverted bar display where full bar = 0% thirst
	local percentText
	percentText = string.format("%.0f%%", displayValue)

	-- Apply text based on hideVialText setting
	thirstMeter.percent:SetText(percentText)
end
