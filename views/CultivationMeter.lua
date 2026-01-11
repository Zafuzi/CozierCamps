-- should be 1:1 length with CultivationMilestones
CultivationMeter = CreateMeter("Cultivation", ThirstMeter, ICONS.cultivation, Cultivation_colors[1])
CultivationMeter:RegisterEvent("VARIABLES_LOADED")
CultivationMeter:SetPoint("TOPLEFT", ThirstMeter, "BOTTOMLEFT", 0, -METER_SPACING)
CultivationMeter:Show()

local isCacheLoaded = false
local isFirstRun = true
CultivationMeter:SetScript("OnUpdate", function(self, elapsed)
	if not Addon.cultivationCache then
		return
	end

	isCacheLoaded = true

	if isFirstRun then
		isFirstRun = false
		local color = Addon.cultivationCache.color
		CultivationMeter:UpdateBgColor(color)
	end
	UpdateCultivationMeter(elapsed)
end)

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
function UpdateCultivationMeter(elapsed)
	if not CultivationMeter or not Addon.cultivationCache then
		return
	end

	local milestone = Addon.cultivationCache.milestone
	local milestone_value = GetMilestoneValue(milestone)
	local next = GetMilestoneValue(GetNextMilestone())
	local prev = GetMilestoneValue(GetPrevMilestone())

	local cultivation = Addon.cultivationCache.current or 0

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
	local percentText
	percentText = string.format("%.0f%%", displayValue)

	-- Apply text based on hideVialText setting
	CultivationMeter.percent:SetText("x" .. Addon.cultivationCache.rate .. " " .. percentText)
	CultivationMeter.name:SetText("Cultivation: (-" .. 100 - (100 * GetCultivationMultiplier()) .. "%)")
end
