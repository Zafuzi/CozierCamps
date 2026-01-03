-- CozierCamps - MapBlock.lua
-- Standalone map blocking system
-- Updated for Midnight (Retail 12.0.1 / Interface 120001) compatibility

local CC = CozierCamps

local mapHooksInstalled = false
local mapBlocked = false

------------------------------------------------------------
-- Safe helpers
------------------------------------------------------------
local function Debug(msg)
	if CC and CC.Debug then
		CC.Debug(msg, "general")
	end
end

local function GetSetting(key, default)
	if CC and CC.GetSetting then
		local v = CC.GetSetting(key)
		if v ~= nil then
			return v
		end
	end
	return default
end

local function IsEligible()
	if CC and CC.IsPlayerEligible then
		return CC.IsPlayerEligible()
	end
	return GetSetting("enabled", true) and (UnitLevel("player") or 0) >= 6
end

local function CanUseMap()
	if CC and CC.CanUseMap then
		return CC.CanUseMap()
	end
	-- If Core isn't ready for some reason, do not block.
	return true
end

local function RegisterCallback(event, fn)
	if CC and CC.RegisterCallback then
		CC.RegisterCallback(event, fn)
		return true
	end
	return false
end

local function ShowBlockedMessage(which)
-- UIErrorsFrame is a clean, non-spammy way to notify in Retail
	if UIErrorsFrame then
		UIErrorsFrame:AddMessage(
			(which == "battlefield" and "Battlefield map is blocked. Find a campfire or inn." or "Map is blocked. Find a campfire or inn."),
			1.0, 0.3, 0.2, 1.0
		)
	end
	Debug((which == "battlefield") and "Battlefield map blocked - find a campfire or inn" or "Map blocked - find a campfire or inn")
end

------------------------------------------------------------
-- Hook installers (avoid taint: do NOT override ToggleWorldMap)
------------------------------------------------------------
local function CloseWorldMapIfBlocked()
	if not mapBlocked then
		return
	end
	if CanUseMap() then
		return
	end

	if WorldMapFrame and WorldMapFrame:IsShown() then
		WorldMapFrame:Hide()
		ShowBlockedMessage("world")
	end
end

local function CloseBattlefieldMapIfBlocked()
	if not mapBlocked then
		return
	end
	if CanUseMap() then
		return
	end

	if BattlefieldMapFrame and BattlefieldMapFrame:IsShown() then
		BattlefieldMapFrame:Hide()
		ShowBlockedMessage("battlefield")
	end
end

local function InstallMapHooks()
	if mapHooksInstalled then
		return true
	end

	-- World Map
	if WorldMapFrame and WorldMapFrame.HookScript then
		WorldMapFrame:HookScript("OnShow", function()
		-- If user opens map while blocked, immediately close it.
			CloseWorldMapIfBlocked()
		end)
	else
		return false
	end

	-- Battlefield Map (may not exist immediately on some UIs)
	if BattlefieldMapFrame and BattlefieldMapFrame.HookScript then
		BattlefieldMapFrame:HookScript("OnShow", function()
			CloseBattlefieldMapIfBlocked()
		end)
	end

	mapHooksInstalled = true
	Debug("MapBlock hooks installed", "general")
	return true
end

------------------------------------------------------------
-- State transitions
------------------------------------------------------------
local function BlockMap()
	if mapBlocked then
		return
	end
	mapBlocked = true
	Debug("Map blocking enabled", "general")

	-- If map is currently open and blocked, close it.
	CloseWorldMapIfBlocked()
	CloseBattlefieldMapIfBlocked()
end

local function UnblockMap()
	if not mapBlocked then
		return
	end
	mapBlocked = false
	Debug("Map blocking disabled", "general")
end

local function UpdateMapBlocking()
	if not GetSetting("blockMap", false) then
		UnblockMap()
		return
	end

	if not IsEligible() then
		UnblockMap()
		return
	end

	BlockMap()
end

------------------------------------------------------------
-- Event handling
------------------------------------------------------------
local frame = CreateFrame("Frame", "CozierCampsMapBlockFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")

local function TryInit()
-- Try to install hooks; if frames aren't ready yet, retry briefly.
	if InstallMapHooks() then
		UpdateMapBlocking()
		return
	end

	-- Retry a few times (some UI elements initialize slightly after login)
	local tries = 0
	local ticker
	ticker = C_Timer.NewTicker(0.5, function()
		tries = tries + 1
		if InstallMapHooks() then
			UpdateMapBlocking()
			ticker:Cancel()
		elseif tries >= 10 then
		-- Give up quietly; we won't block if we can't hook safely.
			Debug("MapBlock: Could not hook WorldMapFrame after retries", "general")
			ticker:Cancel()
		end
	end)
end

frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		C_Timer.After(0.5, TryInit)

	elseif event == "PLAYER_LEVEL_UP" then
		C_Timer.After(0.2, UpdateMapBlocking)

	else
	-- Re-evaluate and close maps if needed
		C_Timer.After(0.1, function()
			UpdateMapBlocking()
			CloseWorldMapIfBlocked()
			CloseBattlefieldMapIfBlocked()
		end)
	end
end)

------------------------------------------------------------
-- CozierCamps callbacks (load-order safe)
------------------------------------------------------------
RegisterCallback("FIRE_STATE_CHANGED", function()
-- If map is open and we lost access, close it.
	CloseWorldMapIfBlocked()
	CloseBattlefieldMapIfBlocked()
end)

RegisterCallback("SETTINGS_CHANGED", function(key)
	if key == "blockMap" or key == "ALL" then
		UpdateMapBlocking()
		CloseWorldMapIfBlocked()
		CloseBattlefieldMapIfBlocked()
	end
end)

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function CC.IsMapBlocked()
	return mapBlocked and not CanUseMap()
end
