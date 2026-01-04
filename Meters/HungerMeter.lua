EATING_AURAS = {
	["Food"] = true,
	["Refreshment"] = true,
	["Food & Drink"] = true,
}

function IsPlayerEating()
	-- Fast paths
	for auraName in pairs(EATING_AURAS) do
		if AuraByName(auraName) then
			return true
		end
	end

	-- Full scan
	return AnyHelpfulAuraMatches(function(aura)
		local name = aura.name
		if not name then
			return false
		end
		return EATING_AURAS[name] == true
	end)
end

local hunger = 50 -- TODO move to saved variables
TIME_TO_STARVE_IN_HOURS = 1 -- TODO move to save variables and a setting the user can control

--- @param elapsed number the amount of time elapsed since last frame
function GetPlayerHunger(elapsed)
	local rate = GetHungerRate()
	hunger = Clamp(hunger + (rate * elapsed), 0, 100)
	return hunger
end

function GetHungerRate()
	-- eating overrides everything
	if PLAYER_STATE.activity == "idle" and PLAYER_STATE.eating then
		-- 20s of eating = full
		return -(100 / 20)
	end

	local rate = TIME_TO_STARVE_IN_HOURS

	if PLAYER_STATE.activity == "idle" then
		rate = TIME_TO_STARVE_IN_HOURS
	end

	if PLAYER_STATE.activity == "mounted" then
		rate = TIME_TO_STARVE_IN_HOURS / 2
	end

	if PLAYER_STATE.activity == "walking" then
		rate = TIME_TO_STARVE_IN_HOURS / 3
	end

	if PLAYER_STATE.activity == "running" or PLAYER_STATE.activity == "flying" then
		rate = TIME_TO_STARVE_IN_HOURS / 4
	end

	if PLAYER_STATE.activity == "swimming" then
		rate = TIME_TO_STARVE_IN_HOURS / 6
	end

	if PLAYER_STATE.activity == "combat" then
		-- combat is very demanding
		rate = TIME_TO_STARVE_IN_HOURS / 50
	end

	if PLAYER_STATE.resting then
		-- 50% reduced decay when resting
		-- because math works the other way we multiply to get a "slower" rate
		rate = rate * 2
	end

	return 1 / (60 * rate)
end
