local function update(elapsed)
	PLAYER_STATE = {
		name = GetPlayerProp("name") or "Player",
		level = GetPlayerProp("level") or 0,
		health = GetPlayerProp("health") or 0,
		speed = GetPlayerProp("speed") or 0,
		activity = GetMovementState() or "idle",
		resting = IsResting(),
		eating = IsPlayerEating(),
	}

	HUNGER = {
		current = GetPlayerHunger(elapsed),
		rate = GetHungerRate()
	}
end

local function onUpdate(self, elapsed)
	update(elapsed)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnUpdate", onUpdate)
f:SetScript("OnEvent", function(self, event, arg)
	if event == "PLAYER_LOGOUT" then
		-- TODO: SaveVariables
	end
end)
