-- CozierCamps - Core.lua
-- Standalone addon for campfire-based gameplay restrictions
--- @global CozierCamps
CozierCamps = {
	version = "0.0.1",
	name = "CozierCamps",
}

SLASH_COZIER1 = "/cozier"
SLASH_COZIER2 = "/cc"
SlashCmdList["COZIER"] = function()
	ToggleModal(DebugPanel)
end