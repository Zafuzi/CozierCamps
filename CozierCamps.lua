-- CozierCamps - Core.lua
-- Standalone addon for campfire-based gameplay restrictions
--- @global CozierCamps
CozierCamps = {
	version = "0.0.1",
	name = "CozierCamps",
}

PLAYER_STATE = {}

HUNGER = {}

SLASH_COZIER1 = "/cozier"
SLASH_COZIER2 = "/cc"
SlashCmdList["COZIER"] = function()
	ToggleModal(DebugPanel)
end

local total = 0

local hunger = 50
local rate = 1/5000
local function GetPlayerHunger()

	if PLAYER_STATE.activity == "idle" then
		rate = 1/3000
	end

	if PLAYER_STATE.activity == "mounted" then
		rate = 1/2000
	end

	if PLAYER_STATE.activity == "walking" then
		rate = 1/1500
	end

	if PLAYER_STATE.activity == "running" or PLAYER_STATE.activity == "flying" then
		rate = 1/1000
	end

	if PLAYER_STATE.activity == "swimming" then
		rate = 1/800
	end

	if PLAYER_STATE.activity == "combat" then
		rate = 1/400
	end

	if IsPlayerEating() then
		rate = -1/20
	end

	hunger = hunger + rate

	-- clamp hunger 0 - 100
	return math.min(100, math.max(0, hunger))
end

local function update()
	PLAYER_STATE = {
		name=GetPlayerProp("name") or "Player",
		level=GetPlayerProp("level") or 0,
		health=GetPlayerProp("health") or 0,
		activity=GetMovementState() or "idle",
	}

	HUNGER = {
		current = GetPlayerHunger(),
		state = PLAYER_STATE.activity,
		rate = rate
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