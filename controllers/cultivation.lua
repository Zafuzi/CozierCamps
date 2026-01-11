CultivationMilestones = { 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e10 }
Cultivation_colors = { "#FF0000", "#FF9900", "#ffff00", "#00ff00", "#0000ff", "#ff00ff", "#ffffff" }
Cultivation_tiers = { "Red", "Orange", "Yellow", "Green", "Blue", "Violet", "White" }
-- these slow down all other meters by xRate -> Higher cultivation = less dmg, less hunger, etc...
CultivationMultipliers = { 1, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4 }

local currentMilestone = 1

function GetCultivationMultiplier()
	return CultivationMultipliers[GetCurrentMilestone()] or 1
end

function GetCurrentMilestone()
	return Addon.cultivationCache.milestone or 1
end

function GetNextMilestone()
	local milestone = Addon.cultivationCache.milestone or 1
	local next = milestone + 1

	if next > #CultivationMilestones then
		return milestone
	end

	return next
end

function GetPrevMilestone()
	local milestone = Addon.cultivationCache.milestone or 1
	local prev = milestone - 1

	if prev < 1 then
		return milestone
	end

	return prev
end

function GetMilestoneValue(milestone)
	milestone = milestone or Addon.cultivationCache.milestone or 1
	return CultivationMilestones[milestone] or 0
end

--- @param elapsed number the amount of time elapsed since last frame
function GetPlayerCultivation(elapsed)
	return Addon.cultivationCache.current
end

function GetCultivationRate()
	local rate = 1

	if IsPlayerCultivating() then
		if IsResting() then
			rate = 5
		else
			-- stop cultivating in open world, too dangerous, unless near a campfire
			if Addon.playerCache.camping then
				rate = 4
			else
				rate = 1
			end
		end
	end

	if Addon.playerCache.activity == "combat" then
		rate = 3
	end

	if Addon.playerCache.resting then
		-- 10% boost when resting
		rate = rate * 1.1
	end


	if not rate then
		return 1
	end

	-- campfire adds a small 10% boost
	if Addon.playerCache.camping then
		rate = rate * 1.1
	end

	return rate
end

function UpdatePlayerCultivation(elapsed)
	-- load into caches
	Addon.cultivationCache = {
		current = GetCharSetting("cultivation_current"),
		rate = GetCharSetting("cultivation_rate"),
		milestone = GetCharSetting("cultivation_milestone"),
		color = GetCharSetting("cultivation_color"),
		active = GetCharSetting("cultivation_active"),
	}

	currentMilestone = Addon.cultivationCache.milestone or 1
	if currentMilestone == #CultivationMilestones then
		return
	end

	local rate = GetCultivationRate()
	local current = Addon.cultivationCache.current
	local milestone_value = GetMilestoneValue(currentMilestone)
	local next = GetNextMilestone()
	local next_value = GetMilestoneValue(next)

	SetCharSetting("cultivation_rate", rate)
	local cultivation = Clamp(current + (rate * elapsed), 0, next_value)

	if cultivation >= milestone_value then
		currentMilestone = next
		milestone_value = next_value

		Debug("milestone reached! new milestone: " .. milestone_value)
		SetCharSetting("cultivation_milestone", currentMilestone)
		MilestoneReached(currentMilestone)
	end

	SetCharSetting("cultivation_current", cultivation)
end
