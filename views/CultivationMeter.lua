function MilestoneReached(next)
	local next_color = Cultivation_colors[next]
	SetCharSetting("cultivation_color", next_color)
	CultivationMeter:UpdateBgColor(next_color)
end

function GetCultivationColor()
	if not Addon.cultivationCache then
		return Cultivation_colors[1]
	end

	return Addon.cultivationCache.color
end

local smoothedCultivationDisplay = nil
local CULTIVATION_DISPLAY_LERP_SPEED = 3.0 -- How fast display catches up to actual value

-- Update cultivation meter
-- TODO: move to draw / update calls and remove dependence on platform where you can
local nameText = ""
local milestone = 1
local milestone_value = GetMilestoneValue(milestone)
local cultivation = 0
local multiplier = 1

function UpdateCultivationMeter(elapsed)
	milestone = Addon.cultivationCache.milestone
	milestone_value = GetMilestoneValue(milestone)

	cultivation = Addon.cultivationCache.current or 0

	-- Smooth the display value to prevent flickering from exhaustion-scaled calculations
	local targetDisplay = 100 * (cultivation / milestone_value)

	if smoothedCultivationDisplay == nil then
		smoothedCultivationDisplay = targetDisplay
	else
		-- Lerp toward target value
		local diff = targetDisplay - smoothedCultivationDisplay

		smoothedCultivationDisplay = smoothedCultivationDisplay +
			diff * math.min(1, CULTIVATION_DISPLAY_LERP_SPEED * elapsed)
	end

	local displayValue = smoothedCultivationDisplay

	-- Update bar value (inverted: full bar = 0% cultivation, empty bar = 100% cultivation)
	CultivationMeter.bar:SetValue(displayValue)

	-- Format percentage text
	nameText = ""
	nameText = nameText .. Dump(cultivation, 0) .. " "
	multiplier = GetCultivationMultiplier()
	if multiplier < 1 then
		nameText = nameText .. "(" .. Dump((100 - (100 * multiplier)), 0) .. "% reduction)"
	end

	-- Apply text based on hideVialText setting
	CultivationMeter.name:SetText("Cultivation")
end

function SetupCultivationTooltip(self)
	self.tooltip = function(_self)
		local color = hex_to_rgb_normalized(Cultivation_colors[milestone])
		local nextMilestone = GetNextMilestone()
		local nextColor = hex_to_rgb_normalized(Cultivation_colors[nextMilestone])
		GameTooltip:AddLine("Cultivation", unpack(hex_to_rgb_normalized(COLORS.CULTIVATION)))
		GameTooltip:AddLine("Core: " .. Dump(Cultivation_tiers[milestone]), unpack(color))
		GameTooltip:AddLine("Next: " .. Dump(Cultivation_tiers[nextMilestone]), unpack(nextColor))
		GameTooltip:AddLine("Current: " .. Dump(cultivation), 1, 1, 1)
		GameTooltip:AddLine("Reduction: " .. Dump(GetCultivationMultiplier()), 1, 1, 1)
		GameTooltip:AddLine("Rate: " .. Dump(GetCultivationRate()), 1, 1, 1)
	end
end
