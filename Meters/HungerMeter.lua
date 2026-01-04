local hunger = 50
function GetPlayerHunger()
	local rate = GetHungerRate()
	hunger = hunger + rate

	-- clamp hunger 0 - 100
	return math.min(100, math.max(0, hunger))
end

function GetHungerRate()
	local rate = 1 / 5000
	if PLAYER_STATE.activity == "idle" then
		rate = 1 / 3000
	end

	if PLAYER_STATE.activity == "mounted" then
		rate = 1 / 2000
	end

	if PLAYER_STATE.activity == "walking" then
		rate = 1 / 1500
	end

	if PLAYER_STATE.activity == "running" or PLAYER_STATE.activity == "flying" then
		rate = 1 / 1000
	end

	if PLAYER_STATE.activity == "swimming" then
		rate = 1 / 800
	end

	if PLAYER_STATE.activity == "combat" then
		rate = 1 / 400
	end

	if IsPlayerEating() then
		rate = -1 / 20
	end

	return rate
end
