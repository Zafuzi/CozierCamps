local hungerIcon = "Interface\\AddOns\\CozierCamps\\assets\\hungericon.blp"
local hungerMeter = CreateMeter("Hunger", UIParent, hungerIcon, false)
hungerMeter:SetScale(2.0)
hungerMeter:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
hungerMeter:Show()
hungerMeter:SetScript("OnUpdate", function(self, elapsed)
	UpdateHungerMeter(elapsed)
end)

local smoothedHungerDisplay = nil
local HUNGER_DISPLAY_LERP_SPEED = 3.0 -- How fast display catches up to actual value

-- Update hunger meter
function UpdateHungerMeter(elapsed)
	if not hungerMeter or not Addon.hungerCache then
		return
	end

	local hunger = Addon.hungerCache.current or 0

	-- Smooth the display value to prevent flickering from exhaustion-scaled calculations
	local targetDisplay = 100 - hunger
	if smoothedHungerDisplay == nil then
		smoothedHungerDisplay = targetDisplay
	else
		-- Lerp toward target value
		local diff = targetDisplay - smoothedHungerDisplay
		smoothedHungerDisplay = smoothedHungerDisplay + diff * math.min(1, HUNGER_DISPLAY_LERP_SPEED * elapsed)
	end
	local displayValue = smoothedHungerDisplay

	-- Update bar value (inverted: full bar = 0% hunger, empty bar = 100% hunger)
	hungerMeter.bar:SetValue(displayValue)

	-- Format percentage text
	-- Both bar and vial modes show inverted value (100 = full/good, 0 = empty/bad)
	-- This matches the inverted bar display where full bar = 0% hunger
	local percentText
	percentText = string.format("%.0f%%", displayValue)

	-- Apply text based on hideVialText setting
	hungerMeter.percent:SetText(percentText)
end
