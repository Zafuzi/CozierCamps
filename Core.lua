local f = CreateFrame("Frame", "Cultivation")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg)
	if event == "ADDON_LOADED" and arg == Addon.name then
		Addon.isLoaded = true
		print(Addon.name .. " is loaded.")
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

		UpdatePlayerHunger(elapsed)
		UpdatePlayerThirst(elapsed)

		t = 0
	end

	t = t + elapsed
end)

SLASH_COZIER1 = "/cozier"
SLASH_COZIER2 = "/cc"
SlashCmdList["COZIER"] = function(msg)
	msg = string.lower(msg or "")
	local command, value = msg:match("([^%s]+)%s*(.*)")
	command = command or ""

	if command == "toggle" then
		ToggleModal(DebugPanel)
	end

	if command == "clear" then
		ResetSettings()
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
