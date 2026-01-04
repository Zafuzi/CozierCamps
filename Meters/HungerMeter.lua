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

local hunger = 100 -- TODO move to saved variables
--- @param elapsed number the amount of time elapsed since last frame
function GetPlayerHunger(elapsed)
	local rate = GetHungerRate()
	hunger = Clamp(hunger + (rate * elapsed), 0, 100)
	return hunger
end

function GetHungerRate()
	local rate = 1 / 50

	if PLAYER_STATE.activity == "idle" then
		rate = 1 / 30
	end

	if PLAYER_STATE.activity == "mounted" then
		rate = 1 / 20
	end

	if PLAYER_STATE.activity == "walking" then
		rate = 1 / 15
	end

	if PLAYER_STATE.activity == "running" or PLAYER_STATE.activity == "flying" then
		rate = 1 / 10
	end

	if PLAYER_STATE.activity == "swimming" then
		rate = 1 / 8
	end

	if PLAYER_STATE.activity == "combat" then
		rate = 1 / 4
	end

	if PLAYER_STATE.activity == "idle" and PLAYER_STATE.eating then
		-- this is based on 20sec of eating ... 100%/20s
		rate = -5
	end

	-- small buff to decay when resting
	if PLAYER_STATE.resting then
		rate = rate - (1 / 100)
	end

	return rate
end
