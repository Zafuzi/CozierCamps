function UpdatePlayerHunger(elapsed)
	-- load into caches
	local rate = GetHungerRate()
	SetCharSetting("hunger_rate", rate)

	local hunger = Clamp(Addon.hungerCache.current + rate * elapsed, 0, 100)
	SetCharSetting("hunger_current", hunger)
end

--- @param elapsed number the amount of time elapsed since last frame
function GetPlayerHunger(elapsed)
	return Addon.hungerCache.current
end

function GetHungerRate()
	-- eating overrides everything
	if Addon.playerCache.activity == "idle" and Addon.playerCache.eating then
		-- 20s of eating = full
		return -(100 / 20)
	end

	local tts = Addon.hungerCache.timeToStarveInHours
	local rate = tts

	if Addon.playerCache.activity == "idle" then
		rate = tts
	end

	if Addon.playerCache.activity == "mounted" then
		rate = tts / 2
	end

	if Addon.playerCache.activity == "walking" then
		rate = tts / 3
	end

	if Addon.playerCache.activity == "running" or Addon.playerCache.activity == "flying" then
		rate = tts / 4
	end

	if Addon.playerCache.activity == "swimming" then
		rate = tts / 6
	end

	if Addon.playerCache.activity == "combat" then
		-- combat is very demanding
		rate = tts / 50
	end

	if not rate then
		rate = 1
	end

	if Addon.playerCache.resting then
		-- 50% reduced decay when resting
		-- because math works the other way we multiply to get a "slower" rate
		rate = rate * 2
	end

	return RateAfterCultivation(rate)
end
