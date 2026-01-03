-- CozyCamps - Thirst.lua
-- Thirst system that scales with temperature and exhaustion
local CC = CozyCamps

-- Thirst value (0-100)
local thirst = 0

-- Constants
local MIN_THIRST = 0
local MAX_THIRST = 100

-- Base thirst rates (per second) - similar to hunger rates
local THIRST_RATE_IDLE = 0.0018 -- When idle (halved)
local THIRST_RATE_WALKING = 0.0072 -- When walking (halved)
local THIRST_RATE_RUNNING = 0.0108 -- When running (halved)
local THIRST_RATE_MOUNTED = 0.0054 -- When mounted (halved)
local THIRST_RATE_COMBAT = 0.0225 -- In combat (halved)
local THIRST_RATE_SWIMMING = 0.0135 -- When swimming (halved)

-- Recovery rates (per second)
local DRINKING_RECOVERY_RATE = 0.4 -- Recovery while drinking buff active
local RESTED_DRINKING_RECOVERY = 0.6 -- Faster when rested + drinking
local RAIN_RECOVERY_RATE = 0.008 -- Very slow recovery while in rain
local SWIMMING_RECOVERY_RATE = 0.004 -- Half as fast as rain, still very slow

-- Checkpoints (drinks cannot reduce below these based on location)
local CHECKPOINT_WORLD = 75 -- Open world: can drink down to 75%
local CHECKPOINT_FIRE = 50 -- Near fire: can drink down to 50%
local CHECKPOINT_RESTED = 25 -- Rested areas: can drink down to 25%
local CHECKPOINT_TRAINER = 0 -- Cooking trainer: resets to 0%

-- Tracking
local isInDungeon = false
local isDecaying = false

-- Mana potion thirst quenching (2 minutes, down to 50%)
local manaPotionQuenchingActive = false
local manaPotionQuenchingRemaining = 0
local MANA_POTION_QUENCH_DURATION = 120.0 -- 2 minutes
local MANA_POTION_QUENCH_CHECKPOINT = 50 -- Can quench down to 50% thirst (50% hydration)
local MANA_POTION_QUENCH_RATE = 0.15 -- Recovery rate per second

-- ============================================
-- THIRST DARKNESS OVERLAY SYSTEM (tunnel vision effect)
-- ============================================
local thirstDarknessFrame = nil
local thirstDarknessCurrentAlpha = 0
local thirstDarknessTargetAlpha = 0
local THIRST_DARKNESS_LERP_SPEED = 0.8 -- How fast darkness transitions (lower = smoother)

-- Create thirst darkness overlay frame using tunnel_vision_4 texture
local function CreateThirstDarknessFrame()
	if thirstDarknessFrame then
		return thirstDarknessFrame
	end

	local frame = CreateFrame("Frame", "CozyCampsThirstDarkness", UIParent)
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata("BACKGROUND")
	frame:SetFrameLevel(0)

	-- Single texture using tunnel_vision_4.png
	frame.texture = frame:CreateTexture(nil, "BACKGROUND")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture("Interface\\AddOns\\CozyCamps\\assets\\tunnel_vision_4.png")
	frame.texture:SetBlendMode("BLEND")
	-- Give it a blue tint to distinguish from hunger
	frame.texture:SetVertexColor(0.7, 0.8, 1.0)

	frame:SetAlpha(0)
	frame:Show() -- Always shown, just adjust alpha

	-- Make it non-interactive (click-through)
	frame:EnableMouse(false)

	thirstDarknessFrame = frame
	return frame
end

-- Get target darkness alpha based on thirst state
local function GetThirstDarknessTarget()
	if not CC.GetSetting("thirstEnabled") then
		return 0
	end
	if not CC.IsPlayerEligible() then
		return 0
	end
	local maxDarkness = CC.GetSetting("thirstMaxDarkness") or 0.25
	if maxDarkness <= 0 then
		return 0
	end
	if isInDungeon then
		return 0
	end
	if UnitOnTaxi("player") then
		return 0
	end
	if UnitIsDead("player") or UnitIsGhost("player") then
		return 0
	end
	-- Linear interpolation: 0% thirst = 0 darkness, 100% thirst = max darkness
	return (thirst / MAX_THIRST) * maxDarkness
end

-- Update thirst darkness overlay with smooth transitions
local function UpdateThirstDarkness(elapsed)
	if not thirstDarknessFrame then
		return
	end

	-- Calculate target alpha
	thirstDarknessTargetAlpha = GetThirstDarknessTarget()

	-- Smooth transition using lerp
	local diff = thirstDarknessTargetAlpha - thirstDarknessCurrentAlpha
	if math.abs(diff) < 0.001 then
		thirstDarknessCurrentAlpha = thirstDarknessTargetAlpha
	else
		thirstDarknessCurrentAlpha = thirstDarknessCurrentAlpha + (diff * THIRST_DARKNESS_LERP_SPEED * elapsed)
	end

	-- Apply alpha
	thirstDarknessFrame:SetAlpha(thirstDarknessCurrentAlpha)
end

-- Check if thirst system should update
local function ShouldUpdateThirst()
	if not CC.GetSetting("thirstEnabled") then
		return false
	end
	if not CC.IsPlayerEligible() then
		return false
	end
	if UnitIsDead("player") or UnitIsGhost("player") then
		return false
	end
	return true
end

-- Retail-safe aura helpers (NO UnitBuff)
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
			return true
		end
	end)
	return found
end

-- Check if player has Refreshed buff (stops thirst completely)
local function HasRefreshedBuff()
	if AuraByName("Refreshed") then
		return true
	end
	return AnyHelpfulAuraMatches(function(aura)
		local name = aura.name
		if not name then
			return false
		end
		return name:match("Refreshed") ~= nil
	end)
end

-- Check if player is drinking
local function IsPlayerDrinking()
	if AuraByName("Drink") or AuraByName("Food & Drink") or AuraByName("Refreshment") then
		return true
	end
	return AnyHelpfulAuraMatches(function(aura)
		local name = aura.name
		if not name then
			return false
		end
		return name == "Drink" or name == "Food & Drink" or name == "Refreshment"
	end)
end

-- Get movement state for thirst rate
local function GetMovementState()
	if UnitAffectingCombat("player") then
		return "combat"
	end
	if IsSwimming() then
		return "swimming"
	end
	if IsMounted() then
		if GetUnitSpeed("player") > 0 then
			return "mounted"
		else
			return "idle" -- Mounted but stationary = no thirst accumulation
		end
	end

	local speed = GetUnitSpeed("player")
	if speed > 0 then
		if speed > 7 then
			return "running"
		else
			return "walking"
		end
	end

	return "idle"
end

-- Get base thirst rate based on movement
local function GetBaseThirstRate()
	local state = GetMovementState()
	if state == "combat" then
		return THIRST_RATE_COMBAT
	elseif state == "swimming" then
		return THIRST_RATE_SWIMMING
	elseif state == "mounted" then
		return THIRST_RATE_MOUNTED
	elseif state == "running" then
		return THIRST_RATE_RUNNING
	elseif state == "walking" then
		return THIRST_RATE_WALKING
	end
	return THIRST_RATE_IDLE
end

-- Calculate thirst multiplier based on temperature and exhaustion
-- Hot temperatures increase thirst, cold temperatures have no effect
local function GetThirstMultiplier()
	local tempFactor = 1.0
	local exhaustionFactor = 1.0

	-- Temperature factor: only if temperature system is enabled
	if CC.GetSetting and CC.GetSetting("temperatureEnabled") then
		local temp = CC.GetTemperature and CC.GetTemperature() or 0
		if temp > 0 then
		-- Hot: 1.0 at temp=0, up to 2.0 at temp=100
		-- Being hot makes you sweat and need more water
			tempFactor = 1.0 + (temp / 100) * 1.0
		end
	-- Cold temperatures don't affect thirst (stays at 1.0)
	end

	-- Exhaustion factor: only if exhaustion system is enabled
	if CC.GetSetting and CC.GetSetting("exhaustionEnabled") then
		local exhaustion = CC.GetExhaustion and CC.GetExhaustion() or 0
		-- 1.0 at exhaustion=0, up to 1.5 at exhaustion=100
		-- Being tired makes you thirstier
		exhaustionFactor = 1.0 + (exhaustion / 100) * 0.5
	end

	-- Combined multiplier
	return tempFactor * exhaustionFactor
end

-- Get current checkpoint based on location
-- Order matters: rested (25%) > fire (50%) > world (75%)
local function GetCurrentCheckpoint()
	if IsResting() then
		return CHECKPOINT_RESTED -- 25%
	elseif CC.isNearFire then
		return CHECKPOINT_FIRE -- 50%
	else
		return CHECKPOINT_WORLD -- 75%
	end
end

-- Reset thirst from cooking trainer interaction
function CC.ResetThirstFromTrainer()
	thirst = CHECKPOINT_TRAINER
	CC.Debug("Thirst reset by cooking trainer", "thirst")
end

-- Reset thirst from innkeeper (if enabled)
-- Only reduces thirst if currently above threshold (don't make player MORE thirsty)
function CC.ResetThirstFromInnkeeper()
	if CC.GetSetting("innkeeperResetsThirst") then
		local threshold = math.floor(MAX_THIRST * 0.15) -- 15% thirst = 85% hydrated
		-- Only reset if thirst is above the threshold (don't make player MORE thirsty)
		if thirst > threshold then
			thirst = threshold
			CC.Debug("Thirst healed to 85% by innkeeper", "thirst")
			return true
		end
		CC.Debug(string.format("Thirst already at %.1f%% (below 15%%), innkeeper has no effect", thirst), "thirst")
		return false
	end
	return false
end

-- Main thirst update function
local function UpdateThirst(elapsed)
	if not ShouldUpdateThirst() then
		isDecaying = false
		return
	end

	-- Completely pause in dungeons/raids - no accumulation OR recovery
	if isInDungeon then
		isDecaying = false
		return
	end

	-- Pause on taxi
	if UnitOnTaxi("player") then
		isDecaying = false
		return
	end

	local hasRefreshed = HasRefreshedBuff()
	local isDrinking = IsPlayerDrinking()
	local isResting = IsResting()
	local checkpoint = GetCurrentCheckpoint()

	-- Refreshed completely stops thirst accumulation
	if hasRefreshed then
	-- When Refreshed AND drinking, can reduce thirst down to checkpoint (but never increase it)
		if isDrinking then
			if thirst > checkpoint then
			-- Above checkpoint - drinking decreases thirst to checkpoint
				isDecaying = true
				local recoveryRate = isResting and RESTED_DRINKING_RECOVERY or DRINKING_RECOVERY_RATE
				local newThirst = thirst - (recoveryRate * elapsed)
				if newThirst < checkpoint then
					newThirst = checkpoint
				end
				thirst = math.max(MIN_THIRST, newThirst)
				CC.Debug(string.format("Refreshed + Drinking: thirst decreasing %.1f%% -> checkpoint %d%%", thirst,
					checkpoint), "thirst")
			else
			-- At or below checkpoint - no further reduction
				isDecaying = false
			end
		end
		-- Refreshed without drinking - can slowly reduce thirst if resting
		if thirst > checkpoint and isResting then
			isDecaying = true -- Show blue regenerating glow when recovering
			local newThirst = thirst - (DRINKING_RECOVERY_RATE * 0.5 * elapsed);
			if newThirst < checkpoint then
				newThirst = checkpoint
			end
			thirst = math.max(MIN_THIRST, newThirst)
		else
			isDecaying = false
		end
		return
	end

	-- Drinking reduces thirst (with checkpoint limits) - normal behavior without Refreshed
	if isDrinking then
	-- Only reduce thirst if currently above the checkpoint
	-- If already at or below checkpoint, drinking has no effect (can't go lower)
		if thirst > checkpoint then
			isDecaying = true
			local recoveryRate = isResting and RESTED_DRINKING_RECOVERY or DRINKING_RECOVERY_RATE
			local newThirst = thirst - (recoveryRate * elapsed)

			-- Apply checkpoint limit - cannot go below checkpoint
			if newThirst < checkpoint then
				newThirst = checkpoint
			end

			thirst = math.max(MIN_THIRST, newThirst)
			CC.Debug(string.format("Drinking: thirst %.1f%% (checkpoint: %d%%)", thirst, checkpoint), "thirst")
		else
		-- Already at or below checkpoint - drinking does nothing
			isDecaying = false
			CC.Debug(string.format("Drinking: at checkpoint %.1f%% <= %d%% (no effect)", thirst, checkpoint), "thirst")
		end
		return
	end

	isDecaying = false

	-- Mana potion quenching (slow recovery over 2 minutes, up to 50% checkpoint)
	if manaPotionQuenchingActive then
		manaPotionQuenchingRemaining = manaPotionQuenchingRemaining - elapsed
		if manaPotionQuenchingRemaining <= 0 then
			manaPotionQuenchingActive = false
			CC.Debug("Mana potion quenching finished", "thirst")
		elseif thirst > MANA_POTION_QUENCH_CHECKPOINT then
		-- Apply quenching - can reduce thirst down to 50%
			isDecaying = true
			local newThirst = thirst - (MANA_POTION_QUENCH_RATE * elapsed)
			if newThirst < MANA_POTION_QUENCH_CHECKPOINT then
				newThirst = MANA_POTION_QUENCH_CHECKPOINT
			end
			thirst = math.max(MIN_THIRST, newThirst)
			CC.Debug(string.format("Mana potion quenching: thirst %.1f%% (limit: %d%%)", thirst,
				MANA_POTION_QUENCH_CHECKPOINT), "thirst")
		end
	-- Don't return - mana potion doesn't block other effects, just provides slow recovery
	end

	-- Swimming recovery (very slow - half as fast as rain)
	if IsSwimming() then
		if thirst > checkpoint then
			isDecaying = true
			local newThirst = thirst - (SWIMMING_RECOVERY_RATE * elapsed)
			if newThirst < checkpoint then
				newThirst = checkpoint
			end
			thirst = math.max(MIN_THIRST, newThirst)
			CC.Debug(string.format("Swimming: thirst recovering %.1f%% (checkpoint: %d%%)", thirst, checkpoint),
				"thirst")
		end
		return -- Swimming takes priority over normal drain
	end

	-- Rain recovery (very slow but faster than swimming)
	local isRaining = CC.IsRaining and CC.IsRaining()
	if isRaining then
		if thirst > checkpoint then
			isDecaying = true
			local newThirst = thirst - (RAIN_RECOVERY_RATE * elapsed)
			if newThirst < checkpoint then
				newThirst = checkpoint
			end
			thirst = math.max(MIN_THIRST, newThirst)
			CC.Debug(string.format("Rain: thirst recovering %.1f%% (checkpoint: %d%%)", thirst, checkpoint), "thirst")
		end
		return -- Rain stops normal thirst accumulation
	end

	-- Calculate thirst accumulation
	local baseRate = GetBaseThirstRate()
	local multiplier = GetThirstMultiplier()
	local thirstRate = baseRate * multiplier

	-- Apply thirst
	thirst = math.min(MAX_THIRST, thirst + (thirstRate * elapsed))

	-- Debug output
	if CC.GetSetting("thirstDebugEnabled") then
		local state = GetMovementState()
		CC.Debug(string.format("Thirst: %.1f%% | Rate: %.3f/s (base: %.3f x %.2f) | State: %s", thirst, thirstRate,
			baseRate, multiplier, state), "thirst")
	end
end

-- Handle thirst update (called from CampfireDetection OnUpdate on a debounce)
function CC.HandleThirstUpdate(elapsed)
	UpdateThirst(elapsed)
end

-- Handle thirst darkness update (called every frame for smooth transitions)
function CC.HandleThirstDarknessUpdate(elapsed)
	UpdateThirstDarkness(elapsed)
end

-- Dungeon detection (uses shared function from Core.lua)
local function CheckDungeonStatus()
	isInDungeon = CC.IsInDungeonOrRaid()
end

-- Public API
function CC.GetThirst()
	return thirst
end

function CC.SetThirst(value)
	thirst = math.max(MIN_THIRST, math.min(MAX_THIRST, value))
end

function CC.IsThirstDecaying()
	return isDecaying
end

function CC.IsThirstPaused()
	if not CC.GetSetting("thirstEnabled") then
		return false
	end
	if not CC.IsPlayerEligible() then
		return false
	end
	return isInDungeon or UnitOnTaxi("player") or UnitIsDead("player") or UnitIsGhost("player")
end

function CC.GetThirstCheckpoint()
	return GetCurrentCheckpoint()
end

function CC.GetThirstMovementState()
	return GetMovementState()
end

function CC.HasRefreshedBuff()
	return HasRefreshedBuff()
end

function CC.IsPlayerDrinking()
	return IsPlayerDrinking()
end

-- Mana potion thirst quenching API
function CC.StartManaPotionQuenching()
-- Don't activate in dungeons - thirst is paused there
	if isInDungeon then
		return
	end
	manaPotionQuenchingActive = true
	manaPotionQuenchingRemaining = MANA_POTION_QUENCH_DURATION
	CC.Debug(string.format("Mana potion thirst quenching started: %ds (limit: %d%%)", MANA_POTION_QUENCH_DURATION,
		MANA_POTION_QUENCH_CHECKPOINT), "thirst")
end

function CC.IsManaPotionQuenching()
	return manaPotionQuenchingActive
end

function CC.GetManaPotionQuenchRemaining()
	return manaPotionQuenchingRemaining
end

-- Get current thirst activity as descriptive string
function CC.GetThirstActivity()
	if CC.IsThirstPaused() then
		return nil -- Paused, no activity
	end
	-- Recovery activities - be specific about what's causing recovery
	if isDecaying then
	-- Check what's actually causing the recovery
		if IsPlayerDrinking() then
			return "Drinking"
		elseif manaPotionQuenchingActive and thirst > MANA_POTION_QUENCH_CHECKPOINT then
			return "Mana Potion"
		elseif IsSwimming() then
			return "Swimming"
		elseif CC.IsRaining and CC.IsRaining() then
			return "In Rain"
		elseif HasRefreshedBuff() and IsResting() then
			return "Resting (Refreshed)"
		elseif HasRefreshedBuff() then
			return "Refreshed"
		else
			return "Recovering"
		end
	end
	if HasRefreshedBuff() then
		return "Refreshed"
	end
	-- Mana potion quenching even when not decaying (at checkpoint)
	if manaPotionQuenchingActive then
		return "Mana Potion"
	end
	-- Check for swimming/rain even when not decaying (at checkpoint)
	if IsSwimming() then
		return "Swimming"
	end
	local isRaining = CC.IsRaining and CC.IsRaining()
	if isRaining then
		return "In Rain"
	end
	-- Drain activities based on movement state
	local state = GetMovementState()
	if state == "combat" then
		return "In combat"
	elseif state == "mounted" then
		return "Mounted"
	elseif state == "running" then
		return "Running"
	elseif state == "walking" then
		return "Walking"
	end
	return nil -- Idle
end

-- Event handling
local eventFrame = CreateFrame("Frame", "CozyCampsThirstFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
	-- Create thirst darkness overlay frame
		CreateThirstDarknessFrame()
		-- Restore saved thirst
		if CC.charDB and CC.charDB.savedThirst then
			thirst = CC.charDB.savedThirst
			CC.Debug(string.format("Thirst restored: %.1f%%", thirst), "thirst")
		end
		CheckDungeonStatus()
	elseif event == "PLAYER_ENTERING_WORLD" then
		CheckDungeonStatus()
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		CheckDungeonStatus()
	end
end)

-- Save thirst on logout
CC.RegisterCallback("PLAYER_LOGOUT", function()
	if CC.charDB then
		CC.charDB.savedThirst = thirst
	end
end)
