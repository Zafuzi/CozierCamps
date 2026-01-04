local function update()
	PLAYER_STATE = {
		name = GetPlayerProp("name") or "Player",
		level = GetPlayerProp("level") or 0,
		health = GetPlayerProp("health") or 0,
		speed = GetPlayerProp("speed") or 0,
		activity = GetMovementState() or "idle",
	}

	HUNGER = {
		current = GetPlayerHunger(),
		state = PLAYER_STATE.activity,
		rate = GetHungerRate()
	}
end

local function onUpdate(self, elapsed)
	update()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnUpdate", onUpdate)
f:SetScript("OnEvent", function(self, event, arg)
	if event == "PLAYER_ENTERING_WORLD" then
		update()
	end

	if event == "PLAYER_LOGOUT" then
		-- TODO: SaveVariables
	end
end)
