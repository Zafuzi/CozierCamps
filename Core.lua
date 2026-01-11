local f = CreateFrame("Frame", "Cultivation")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_STOPPED_MOVING")
f:RegisterEvent("PLAYER_UPDATE_RESTING")

f:SetScript("OnEvent", function(self, event, arg)
	if event == "ADDON_LOADED" and arg == Addon.name then
		Addon.isLoaded = true
		print(Addon.name .. " is loaded.")
	end

	if event == "PLAYER_UPDATE_RESTING" then
		print("Player update resting: " .. arg)
	end
end)

local t = 0
local delay = 1 / 120
f:SetScript("OnUpdate", function(self, elapsed)
	if Addon.isLoaded and t >= delay then
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

		t = 0
	end

	t = t + elapsed
end)

SLASH_CULTIVATION1 = "/cultivation"
SLASH_CULTIVATION2 = "/c"
SlashCmdList["CULTIVATION"] = function(msg)
	msg = string.lower(msg or "")
	local command, value = msg:match("([^%s]+)%s*(.*)")
	command = command or ""

	if command == "toggle" then
		ToggleModal(DebugPanel)
	end

	if command == "clear" then
		ResetSettings()
	end

	if command == "cul_cur" then
		SetCharSetting("cultivation_current", value)
	end

	if command == "cultivate" then
		local isOn = GetSetting("cultivation_active") or false
		SetCharSetting("cultivation_active", not isOn)
		print("Set cultivation_active " .. tostring(not isOn))
	end

	if command == "milestone" then
		SetCharSetting("cultivation_milestone", value)
	end

	if command == "debug" then
		local settingKey = DEBUG_SETTINGS[value]
		if settingKey then
			local isOn = GetSetting(settingKey)
			SetSetting(settingKey, not isOn)

			if value == "panel" and isOn then
				ToggleModal(DebugPanel)
			end
		else
			Debug("Debug Setting: " .. value .. " not found")
		end
	end
end
