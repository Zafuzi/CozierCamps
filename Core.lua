local f = CreateFrame("Frame", "Cultivation")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_STOPPED_MOVING")
f:RegisterEvent("PLAYER_STARTED_MOVING")
f:RegisterEvent("PLAYER_UPDATE_RESTING")

f:SetScript("OnEvent", function(self, event, arg)
	if event == "ADDON_LOADED" and arg == Addon.name then
		Addon.isLoaded = true
		Debug(Addon.name .. " is loaded.", "event")

		-- first time update
		UpdateAddon(0)
		OpenMeters()
	end

	if event == "PLAYER_UPDATE_RESTING" then
		Debug("Player update resting: " .. tostring(arg), "event")
	end

	if event == "PLAYER_STARTED_MOVING" then
		Debug("Player update started moving: " .. tostring(arg), "event")
		if GetCharSetting("cultivation_active") then
			Cultivate(false)
		end
	end
end)

f:SetScript("OnKeyDown", function(self, key)
	if key == "ESCAPE" then
		Cultivate(false)
	end
end)
f:SetPropagateKeyboardInput(true)

local t = 0
local delay = 1 / 30
function UpdateAddon(elapsed)
	Addon.playerCache.name = GetPlayerProp("name")
	Addon.playerCache.level = GetPlayerProp("level")
	Addon.playerCache.health = GetPlayerProp("health")
	Addon.playerCache.speed = GetPlayerProp("speed")
	Addon.playerCache.resting = IsResting()
	Addon.playerCache.eating = IsPlayerEating()
	Addon.playerCache.drinking = IsPlayerDrinking()
	Addon.playerCache.activity = GetMovementState()
	Addon.playerCache.cultivating = IsPlayerCultivating()
	Addon.playerCache.camping = IsPlayerCamping()
	Addon.playerCache.onVehicle = GetPlayerProp("using_vehicle")

	Addon.hungerCache = {
		current = GetCharSetting("hunger_current"),
		rate = GetCharSetting("hunger_rate"),
		timeToStarveInHours = GetCharSetting("hunger_timeToStarveInHours"),
	}

	Addon.thirstCache = {
		current = GetCharSetting("thirst_current"),
		rate = GetCharSetting("thirst_rate"),
		timeToDehydrationInHours = GetCharSetting("thirst_timeToDehydrationInHours"),
	}

	Addon.cultivationCache = {
		current = GetCharSetting("cultivation_current"),
		rate = GetCharSetting("cultivation_rate"),
		milestone = GetCharSetting("cultivation_milestone"),
		color = GetCharSetting("cultivation_color"),
		active = GetCharSetting("cultivation_active"),
	}


	UpdatePlayerHunger(elapsed)
	UpdatePlayerThirst(elapsed)
	UpdatePlayerCultivation(elapsed)
end

f:SetScript("OnUpdate", function(self, elapsed)
	if Addon.isLoaded and t >= delay then
		UpdateAddon(elapsed)
		t = 0
	end

	t = t + elapsed
end)

SLASH_CULTIVATION1 = "/cultivation"
SLASH_CULTIVATION2 = "/c"
SlashCmdList["CULTIVATION"] = function(msg)
	msg = string.lower(msg or "")
	local command, value = msg:match("([^%s]+)%s*(.*)")
	command = string.lower(command or "")
	value = string.lower(value)

	if command == "clear" then
		if value == "db" then
			ResetDB()
			return
		end

		if value == "char" then
			ResetChar()
			return
		end

		if value == "all" then
			ResetSettings()
			return
		end

		Debug("USAGE: DB|CHAR|ALL")
		return
	end

	if command == "dbg" then
		if value then
			local key = "debug_" .. tostring(value)
			local isOn = not GetSetting(key)
			SetSetting(key, isOn)

			Debug("Toggled " .. tostring(key) .. ": " .. tostring(isOn))
		end

		if not DebugPanel:IsShown() then
			DebugPanel:Show()
		end

		return
	end

	if command == "cultivate" then
		Cultivate(true)
		return
	end
end
