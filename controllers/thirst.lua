-- TODO: convert to a module that requires ZERO utils
function UpdatePlayerThirst(elapsed)
	local rate = GetThirstRate()
	SetCharSetting("thirst_rate", rate)

	local thirst = Clamp(Addon.thirstCache.current + rate * elapsed, 0, 100)
	SetCharSetting("thirst_current", thirst)
end

--- @param elapsed number the amount of time elapsed since last frame
function GetPlayerThirst(elapsed)
	return Addon.thirstCache.current
end

function GetThirstRate()
	-- drinking overrides everything
	if Addon.playerCache.activity == "idle" and Addon.playerCache.drinking then
		-- 20s of drinking = full
		return -(100 / 20)
	end

	local tts = Addon.thirstCache.thirst_timeToDehydrationInHours or ONE_THIRD
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
		return 0
	end

	if Addon.playerCache.resting then
		-- 50% reduced decay when resting
		-- because math works the other way we multiply to get a "slower" rate
		rate = rate * 2
	end

	return RateAfterCultivation(rate)
end
