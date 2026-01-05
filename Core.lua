-- CozierCamps
-- Standalone addon for campfire-based gameplay restrictions

local f = CreateFrame("Frame", "CozierCamps")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg)
	if event == "ADDON_LOADED" and arg == Addon.name then
		Addon.isLoaded = true
	end
end)

local t = 0
local delay = 1 / 60
f:SetScript("OnUpdate", function(self, elapsed)
	if Addon.isLoaded and t >= delay then
		Addon.playerCache.name = GetPlayerProp("name")
		Addon.playerCache.level = GetPlayerProp("level")
		Addon.playerCache.health = GetPlayerProp("health")
		Addon.playerCache.speed = GetPlayerProp("speed")
		Addon.playerCache.resting = IsResting()
		Addon.playerCache.eating = IsPlayerEating()
		Addon.playerCache.activity = GetMovementState()

		UpdatePlayerHunger(elapsed)

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

	if command == "debug" then
		ToggleModal(DebugPanel)
	end

	if command == "clear" then
		ResetSettings()
	end
end
