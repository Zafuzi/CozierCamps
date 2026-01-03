-- CozyCamps - Hunger.lua
-- Hunger system that scales with temperature and exhaustion
-- Updated for Midnight (Retail 12.0.1 / Interface 120001) compatibility
--
-- FIX: UnitBuff() is nil in this client. Replaced UnitBuff-based Well Fed / Eating detection
-- in HasWellFedBuff() and IsPlayerEating(). :contentReference[oaicite:1]{index=1}

local CC = CozyCamps

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
local hunger = 0

local MIN_HUNGER = 0
local MAX_HUNGER = 100

------------------------------------------------------------
-- Base hunger rates (per second)
-- (your existing values preserved)
------------------------------------------------------------
local HUNGER_RATE_IDLE = 0.0018 -- unused (idle doesn't accumulate)
local HUNGER_RATE_WALKING = 0.0072
local HUNGER_RATE_RUNNING = 0.0108
local HUNGER_RATE_MOUNTED = 0.0054
local HUNGER_RATE_COMBAT = 0.0225
local HUNGER_RATE_SWIMMING = 0.0135

-- Recovery rates (per second - with 2.5s tick, these give ~1 per tick base, ~1.5 when rested)
local EATING_RECOVERY_RATE = 0.4
local RESTED_EATING_RECOVERY = 0.6

-- Checkpoints (food cannot reduce below these based on location)
local CHECKPOINT_WORLD = 75
local CHECKPOINT_FIRE = 50
local CHECKPOINT_RESTED = 25
local CHECKPOINT_TRAINER = 0

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

	local frame = CreateFrame("Frame", "CozyCampsHungerDarkness", UIParent)
	frame:SetAllPoints(UIParent)

	-- Midnight/Retail: ensure it's above the 3D world, but below most UI
	frame:SetFrameStrata("FULLSCREEN")
	frame:SetFrameLevel(10)

	frame.texture = frame:CreateTexture(nil, "ARTWORK")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture("Interface\\AddOns\\CozyCamps\\assets\\tunnel_vision_4.png")
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
	return 0 -- no accumulation when idle
end

local function GetHungerMultiplier()
	local tempFactor = 1.0
	local exhaustionFactor = 1.0

	if GetSetting("temperatureEnabled", false) then
		local temp = (CC and CC.GetTemperature and CC.GetTemperature()) or 0
		tempFactor = 1.0 + (math.abs(temp) / 100) * 1.0
	end

	if GetSetting("exhaustionEnabled", true) then
		local ex = (CC and CC.GetExhaustion and CC.GetExhaustion()) or 0
		exhaustionFactor = 1.0 + (ex / 100) * 0.5
	end

	return tempFactor * exhaustionFactor
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
	if not ShouldUpdateHunger() then
		isDecaying = false
		return
	end

	local hasWellFed = HasWellFedBuff()
	local isEating = IsPlayerEating()
	local isResting = IsResting()
	local checkpoint = GetCurrentCheckpoint()

	-- Well Fed: stop accumulation; allow normalization if eating; allow slow recovery if resting
	if hasWellFed then
		if isEating then
			local recoveryRate = isResting and RESTED_EATING_RECOVERY or EATING_RECOVERY_RATE
			if hunger < checkpoint then
				isDecaying = false
				hunger = math.min(MAX_HUNGER, math.min(checkpoint, hunger + (recoveryRate * elapsed)))
				Debug(string.format("Well Fed + Eating: hunger increasing %.1f%% -> checkpoint %d%%", hunger, checkpoint))
			elseif hunger > checkpoint then
				isDecaying = true
				hunger = math.max(MIN_HUNGER, math.max(checkpoint, hunger - (recoveryRate * elapsed)))
				Debug(string.format("Well Fed + Eating: hunger decreasing %.1f%% -> checkpoint %d%%", hunger, checkpoint))
			else
				isDecaying = false
			end
			return
		end

		if hunger > checkpoint and isResting then
			isDecaying = true
			local newHunger = hunger - (EATING_RECOVERY_RATE * 0.5 * elapsed); if newHunger < checkpoint then
				newHunger = checkpoint
			end; hunger = math.max(MIN_HUNGER, newHunger)
		else
			isDecaying = false
		end
		return
	end

	-- Eating (no Well Fed): reduce hunger down to checkpoint
	if isEating then
		if hunger > checkpoint then
			isDecaying = true
			local recoveryRate = isResting and RESTED_EATING_RECOVERY or EATING_RECOVERY_RATE
			local newHunger = hunger - (recoveryRate * elapsed)
			if newHunger < checkpoint then
				newHunger = checkpoint
			end
			hunger = math.max(MIN_HUNGER, newHunger)
			Debug(string.format("Eating: hunger %.1f%% (checkpoint: %d%%)", hunger, checkpoint))
		else
			isDecaying = false
		end
		return
	end

	isDecaying = false

	-- Paused in dungeon/taxi
	if isInDungeon or UnitOnTaxi("player") then
		return
	end

	local baseRate = GetBaseHungerRate()
	local multiplier = GetHungerMultiplier()
	local hungerRate = baseRate * multiplier

	hunger = math.min(MAX_HUNGER, hunger + (hungerRate * elapsed))

	if GetSetting("hungerDebugEnabled", false) then
		Debug(string.format(
			"Hunger: %.1f%% | Rate: %.3f/s (base: %.3f x %.2f) | State: %s",
			hunger, hungerRate, baseRate, multiplier, GetMovementState()
		))
	end
end

------------------------------------------------------------
-- Update hooks called by CampfireDetection.lua
------------------------------------------------------------
function CC.HandleHungerUpdate(elapsed)
	UpdateHunger(elapsed)
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
	if isDecaying then
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
	return nil
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "CozyCampsHungerFrame")
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
