-- CozierCamps - Hunger.lua
-- Hunger system that scales with temperature and exhaustion
-- Updated for Midnight (Retail 12.0.1 / Interface 120001) compatibility
--
-- FIX: UnitBuff() is nil in this client. Replaced UnitBuff-based Well Fed / Eating detection
-- in HasWellFedBuff() and IsPlayerEating(). :contentReference[oaicite:1]{index=1}

local CC = CozierCamps

------------------------------------------------------------
-- Safe helpers (load-order safe)
------------------------------------------------------------
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

local function Debug(msg)
	if CC and CC.Debug then
		CC.Debug(msg, "hunger")
	end
end

local function RegisterCallback(event, fn)
	if CC and CC.RegisterCallback then
		CC.RegisterCallback(event, fn)
		return true
	end
	return false
end

local function IsInDungeonOrRaid()
	if CC and CC.IsInDungeonOrRaid then
		return CC.IsInDungeonOrRaid()
	end
	local inInstance, instanceType = IsInInstance()
	return inInstance and (instanceType == "party" or instanceType == "raid")
end

------------------------------------------------------------
-- Hunger value (0-100)
------------------------------------------------------------
hunger = 0
HUNGER_UPDATE_DELAY = 2.5 -- in seconds

local MIN_HUNGER = 0
local MAX_HUNGER = 100

------------------------------------------------------------
-- Base hunger rates (per tick)
------------------------------------------------------------
local HUNGER_EATING_RECOVERY_RATE = (15 / HUNGER_UPDATE_DELAY) -- about 15 seconds
local HUNGER_RATE_IDLE = 1 / 30 -- about 30 minutes
local HUNGER_RATE_MOUNTED = 1 / 25
local HUNGER_RATE_WALKING = 1 / 20
local HUNGER_RATE_RUNNING = 1 / 15
local HUNGER_RATE_SWIMMING = 1 / 10
local HUNGER_RATE_COMBAT = 1 / 5

-- Checkpoints (food cannot reduce below these based on location)
local CHECKPOINT_WORLD = 25
local CHECKPOINT_FIRE = 50
local CHECKPOINT_RESTED = 75
local CHECKPOINT_TRAINER = 100

-- Tracking
local isInDungeon = false
local isDecaying = false

------------------------------------------------------------
-- HUNGER DARKNESS OVERLAY (Retail/Midnight safe layering)
------------------------------------------------------------
local hungerDarknessFrame = nil
local hungerDarknessCurrentAlpha = 0
local hungerDarknessTargetAlpha = 0
local HUNGER_DARKNESS_LERP_SPEED = 0.8

local function CreateHungerDarknessFrame()
	if hungerDarknessFrame then
		return hungerDarknessFrame
	end

	local frame = CreateFrame("Frame", "CozierCampsHungerDarkness", UIParent)
	frame:SetAllPoints(UIParent)

	-- Midnight/Retail: ensure it's above the 3D world, but below most UI
	frame:SetFrameStrata("FULLSCREEN")
	frame:SetFrameLevel(10)

	frame.texture = frame:CreateTexture(nil, "ARTWORK")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\tunnel_vision_4.png")
	frame.texture:SetBlendMode("BLEND")

	frame:SetAlpha(0)
	frame:Hide()
	frame:EnableMouse(false)

	hungerDarknessFrame = frame
	return frame
end

local function GetHungerDarknessTarget()
	if not GetSetting("hungerEnabled", false) then
		return 0
	end
	if not IsEligible() then
		return 0
	end

	local maxDarkness = GetSetting("hungerMaxDarkness", 0.25) or 0.25
	if maxDarkness <= 0 then
		return 0
	end
	if isInDungeon or UnitOnTaxi("player") then
		return 0
	end
	if UnitIsDead("player") or UnitIsGhost("player") then
		return 0
	end

	return (hunger / MAX_HUNGER) * maxDarkness
end

local function UpdateHungerDarkness(elapsed)
	if not hungerDarknessFrame then
		return
	end

	hungerDarknessTargetAlpha = GetHungerDarknessTarget()

	local diff = hungerDarknessTargetAlpha - hungerDarknessCurrentAlpha
	if math.abs(diff) < 0.001 then
		hungerDarknessCurrentAlpha = hungerDarknessTargetAlpha
	else
		hungerDarknessCurrentAlpha = hungerDarknessCurrentAlpha + (diff * HUNGER_DARKNESS_LERP_SPEED * elapsed)
	end

	hungerDarknessCurrentAlpha = math.max(0, math.min(1, hungerDarknessCurrentAlpha))

	if hungerDarknessCurrentAlpha > 0.001 then
		if not hungerDarknessFrame:IsShown() then
			hungerDarknessFrame:Show()
		end
		hungerDarknessFrame:SetAlpha(hungerDarknessCurrentAlpha)
	else
		hungerDarknessFrame:SetAlpha(0)
		if hungerDarknessFrame:IsShown() then
			hungerDarknessFrame:Hide()
		end
	end
end

------------------------------------------------------------
-- Update gating
------------------------------------------------------------
local function ShouldUpdateHunger()
	if not GetSetting("hungerEnabled", false) then
		return false
	end
	if not IsEligible() then
		return false
	end
	if isInDungeon or UnitOnTaxi("player") then
		return false
	end
	if UnitIsDead("player") or UnitIsGhost("player") then
		return false
	end
	return true
end

------------------------------------------------------------
-- Retail-safe aura helpers (NO UnitBuff)
------------------------------------------------------------
local function AuraByName(name)
	if AuraUtil and AuraUtil.FindAuraByName then
		return AuraUtil.FindAuraByName(name, "player", "HELPFUL")
	end
	return nil
end

local function AnyHelpfulAuraMatches(pred)
	if not (AuraUtil and AuraUtil.ForEachAura) then
		return false
	end
	local found = false
	AuraUtil.ForEachAura("player", "HELPFUL", nil, function(aura)
		if not aura then
			return
		end
		if pred(aura) then
			found = true
			return true -- stop iteration
		end
	end)
	return found
end

------------------------------------------------------------
-- Well Fed / Eating detection
------------------------------------------------------------
local WELL_FED_BUFFS = {
	["Well Fed"] = true,
	["Mana Regeneration"] = true,
	["Increased Stamina"] = true,
	["Increased Intellect"] = true,
	["Increased Spirit"] = true,
	["Increased Agility"] = true,
	["Increased Strength"] = true,
	["Blessing of Blackfathom"] = true,
	["Spirit of Zanza"] = true,
	["Gordok Green Grog"] = true,
	["Rumsey Rum Black Label"] = true,
	["Sagefish Delight"] = true,
	["Nightfin Soup"] = true,
	["Runn Tum Tuber Surprise"] = true,
	["Monster Omelet"] = true,
	["Tender Wolf Steak"] = true,
	["Grilled Squid"] = true,
	["Smoked Desert Dumplings"] = true,
	["Dragonbreath Chili"] = true
}

local EATING_AURAS = {
	["Food"] = true,
	["Refreshment"] = true,
	["Food & Drink"] = true,
}

local function HasWellFedBuff()
	-- Fast path for the common one
	if AuraByName("Well Fed") then
		return true
	end

	-- Full scan (Retail-safe)
	return AnyHelpfulAuraMatches(function(aura)
		local name = aura.name
		if not name then
			return false
		end
		if WELL_FED_BUFFS[name] then
			return true
		end
		if name:match("Well Fed") then
			return true
		end
		return false
	end)
end

local function IsPlayerEating()
	-- Fast paths
	for auraName in pairs(EATING_AURAS) do
		if AuraByName(auraName) then
			return true
		end
	end

	-- Full scan
	return AnyHelpfulAuraMatches(function(aura)
		local name = aura.name
		if not name then
			return false
		end
		return EATING_AURAS[name] == true
	end)
end

------------------------------------------------------------
-- Movement / rate calculation
------------------------------------------------------------
local function GetMovementState()
	if UnitAffectingCombat("player") then
		return "combat"
	end
	if IsSwimming() then
		return "swimming"
	end

	local speed = GetUnitSpeed("player") or 0

	if IsMounted() then
		if speed > 0 then
			return "mounted"
		else
			return "idle"
		end
	end

	if speed > 7 then
		return "running"
	elseif speed > 0 then
		return "walking"
	end
	return "idle"
end

local function GetBaseHungerRate()
	local state = GetMovementState()
	if state == "combat" then
		return HUNGER_RATE_COMBAT
	elseif state == "swimming" then
		return HUNGER_RATE_SWIMMING
	elseif state == "mounted" then
		return HUNGER_RATE_MOUNTED
	elseif state == "running" then
		return HUNGER_RATE_RUNNING
	elseif state == "walking" then
		return HUNGER_RATE_WALKING
	end
	return HUNGER_RATE_IDLE
end

local function GetHungerMultiplier()
	local tempFactor = 1.0
	local exhaustionFactor = 1.0

	if CC.GetSetting("temperatureEnabled") then
		local temp = (CC and CC.GetTemperature and CC.GetTemperature()) or 0
		tempFactor = 1.0 + (math.abs(temp) / 100) * 1.0
		Debug("TempFactor: " .. (tempFactor))
	end

	if CC.GetSetting("exhaustionEnabled") then
		local ex = (CC and CC.GetExhaustion and CC.GetExhaustion()) or 0
		exhaustionFactor = 1.0 + (ex / 100) * 0.5
		Debug("ExhaustionFactor: " .. (exhaustionFactor))
	end

	return (tempFactor * exhaustionFactor)
end

local function GetCurrentCheckpoint()
	if IsResting() then
		return CHECKPOINT_RESTED
	elseif CC and CC.isNearFire then
		return CHECKPOINT_FIRE
	end
	return CHECKPOINT_WORLD
end

------------------------------------------------------------
-- Public reset helpers
------------------------------------------------------------
function CC.ResetHungerFromTrainer()
	hunger = CHECKPOINT_TRAINER
	Debug("Hunger reset by cooking trainer")
end

function CC.ResetHungerFromInnkeeper()
	if GetSetting("innkeeperResetsHunger", true) then
		local threshold = math.floor(MAX_HUNGER * 0.15) -- 15% hunger = 85% satiated
		if hunger > threshold then
			hunger = threshold
			Debug("Hunger healed to 85% by innkeeper")
			return true
		else
			Debug(string.format("Hunger already at %.1f%% (<= 15%%), innkeeper has no effect", hunger))
			return false
		end
	end
	return false
end

------------------------------------------------------------
-- Main hunger update (called on a slower tick by CampfireDetection)
------------------------------------------------------------
local function UpdateHunger(elapsed)
	isDecaying = false

	if not ShouldUpdateHunger() then
		return
	end

	-- Paused in dungeon/taxi
	if isInDungeon or UnitOnTaxi("player") then
		return
	end

	Debug("hunger: " .. hunger)

	local hasWellFed = HasWellFedBuff()
	local isEating = IsPlayerEating()
	local isResting = IsResting()
	local checkpoint = GetCurrentCheckpoint()
	local hungerBaseIncreaseRate = GetBaseHungerRate()
	local hungerIncreaseMultiplier = GetHungerMultiplier()

	local hungerIncreaseRate = hungerBaseIncreaseRate * hungerIncreaseMultiplier
	local hungerDecreaseRate = 0

	if isEating then
		hungerDecreaseRate = HUNGER_EATING_RECOVERY_RATE
		isDecaying = false
	end

	hunger = hunger - (hungerDecreaseRate * elapsed)

	-- allow eating, but stop decaying if well fed
	if not hasWellFed and not isEating then
		isDecaying = true
		hunger = hunger + (hungerIncreaseRate * elapsed)
	end

	if hunger > MAX_HUNGER then
		hunger = MAX_HUNGER
	end

	if hunger < MIN_HUNGER then
		hunger = MIN_HUNGER
	end

	if 100 - hunger > checkpoint then
		hunger = 100 - checkpoint
	end

	if CC.GetSetting("hungerDebugEnabled") then
		Debug("inc: " .. hungerIncreaseRate)
		Debug("dec: " .. hungerDecreaseRate)
		Debug("mul: " .. hungerIncreaseMultiplier)
		Debug("hunger: " .. hunger)
		Debug("checkpoint: " .. checkpoint)

		local tts = ((100 - hunger) / 100) / (hungerIncreaseRate - hungerDecreaseRate)
		local tts_min, tts_sec = math.modf(tts)
		tts_sec = tts_sec * 60
		Debug("Starving in: " .. tts_min .. "m " .. math.floor(tts_sec) .. "s")
	end
end

------------------------------------------------------------
-- Update hooks called by CampfireDetection.lua
------------------------------------------------------------
function CC.HandleHungerUpdate(elapsed)
	if CC.GetSetting("hungerDebugEnabled") then
		print("--- TOP UPDATING HUNGER ---")
	end
	UpdateHunger(elapsed)

	if CC.GetSetting("hungerDebugEnabled") then
		print("--- END UPDATING HUNGER ---")
	end
end

function CC.HandleHungerDarknessUpdate(elapsed)
	UpdateHungerDarkness(elapsed)
end

------------------------------------------------------------
-- Dungeon detection
------------------------------------------------------------
local function CheckDungeonStatus()
	isInDungeon = IsInDungeonOrRaid()
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function CC.GetHunger()
	return hunger
end

function CC.SetHunger(value)
	hunger = math.max(MIN_HUNGER, math.min(MAX_HUNGER, tonumber(value) or 0))
end

function CC.IsHungerDecaying()
	return isDecaying
end

function CC.IsHungerPaused()
	if not GetSetting("hungerEnabled", false) then
		return false
	end
	if not IsEligible() then
		return false
	end
	return isInDungeon or UnitOnTaxi("player") or UnitIsDead("player") or UnitIsGhost("player")
end

function CC.GetHungerCheckpoint()
	return GetCurrentCheckpoint()
end

function CC.GetHungerMovementState()
	return GetMovementState()
end

function CC.HasWellFedBuff()
	return HasWellFedBuff()
end

function CC.GetHungerActivity()
	if CC.IsHungerPaused() then
		return nil
	end

	if IsPlayerEating() then
		return "Eating"
	end

	if HasWellFedBuff() then
		return "Well Fed"
	end

	local state = GetMovementState()
	if state == "combat" then
		return "In combat"
	elseif state == "swimming" then
		return "Swimming"
	elseif state == "mounted" then
		return "Mounted"
	elseif state == "running" then
		return "Running"
	elseif state == "walking" then
		return "Walking"
	end

	if isDecaying then
		return "Idle"
	end

	return nil
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "CozierCampsHungerFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		CreateHungerDarknessFrame()

		if CC and CC.charDB and CC.charDB.savedHunger then
			hunger = CC.charDB.savedHunger
			Debug(string.format("Hunger restored: %.1f%%", hunger))
		end

		CheckDungeonStatus()

	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		CheckDungeonStatus()
	end
end)

-- Save hunger on logout (load-order safe)
RegisterCallback("PLAYER_LOGOUT", function()
	if CC and CC.charDB then
		CC.charDB.savedHunger = hunger
	end
end)

-- If hunger gets disabled, force the overlay off immediately
RegisterCallback("SETTINGS_CHANGED", function(key)
	if key == "hungerEnabled" or key == "hungerMaxDarkness" or key == "ALL" then
		if hungerDarknessFrame then
			hungerDarknessTargetAlpha = 0
			hungerDarknessCurrentAlpha = 0
			hungerDarknessFrame:SetAlpha(0)
			hungerDarknessFrame:Hide()
		end
	end
end)
