-- CozierCamps - Exhaustion.lua
-- Exhaustion system - accumulates while moving, decays near fires or while resting
-- Updated/hardened for Midnight (Retail 12.0.1 / Interface 120001)

local CC = CozierCamps

------------------------------------------------------------
-- Safe helpers (Retail/Midnight load-order safe)
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

local function Debug(msg)
	if CC and CC.Debug then
		CC.Debug(msg, "exhaustion")
	end
end

local function IsEligible()
	if CC and CC.IsPlayerEligible then
		return CC.IsPlayerEligible()
	end
	return GetSetting("enabled", true) and (UnitLevel("player") or 0) >= 6
end

local function CheckDungeonStatus()
	if CC and CC.IsInDungeonOrRaid then
		return CC.IsInDungeonOrRaid()
	end
	local inInstance, instanceType = IsInInstance()
	return inInstance and (instanceType == "party" or instanceType == "raid")
end

------------------------------------------------------------
-- State
------------------------------------------------------------
local exhaustion = 0
local savedExhaustion = 0
local maxExhaustion = 100
local isInDungeon = false

-- ============================================
-- EXHAUSTION OVERLAY SYSTEM (screen darkening at 20/40/60/80)
-- ============================================
local EXHAUST_TEXTURES = {
	"Interface\\AddOns\\CozierCamps\\assets\\exhaustion20.png",
	"Interface\\AddOns\\CozierCamps\\assets\\exhaustion40.png",
	"Interface\\AddOns\\CozierCamps\\assets\\exhaustion60.png",
	"Interface\\AddOns\\CozierCamps\\assets\\exhaustion80.png"
}

local exhaustOverlayFrames = {}
local exhaustOverlayCurrentAlphas = {0, 0, 0, 0}
local exhaustOverlayTargetAlphas = {0, 0, 0, 0}

-- Pulse effect for exhaustion overlays
local exhaustOverlayPulsePhase = 0
local EXHAUST_OVERLAY_PULSE_SPEED = 0.5
local EXHAUST_OVERLAY_PULSE_MIN = 0.7
local EXHAUST_OVERLAY_PULSE_MAX = 1.0

-- Get overlay level based on exhaustion (0-4)
local function GetExhaustOverlayLevel()
	if exhaustion >= 80 then
		return 4
	elseif exhaustion >= 60 then
		return 3
	elseif exhaustion >= 40 then
		return 2
	elseif exhaustion >= 20 then
		return 1
	else
		return 0
	end
end

-- Create exhaustion overlay frame for a specific level
local function CreateExhaustOverlayFrame(level)
	if exhaustOverlayFrames[level] then
		return exhaustOverlayFrames[level]
	end

	local frame = CreateFrame("Frame", "CozierCampsExhaustOverlay_" .. level, UIParent)
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(90 + level)

	frame.texture = frame:CreateTexture(nil, "BACKGROUND")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture(EXHAUST_TEXTURES[level])
	frame.texture:SetBlendMode("BLEND")

	frame:SetAlpha(0)
	frame:Hide()

	exhaustOverlayFrames[level] = frame
	return frame
end

-- Create all exhaustion overlay frames
local function CreateAllExhaustOverlayFrames()
	for i = 1, 4 do
		CreateExhaustOverlayFrame(i)
	end
end

-- Check if exhaustion overlays should be shown
local function ShouldShowExhaustOverlay()
	if not GetSetting("exhaustionEnabled", true) then
		return false
	end
	if not IsEligible() then
		return false
	end
	if isInDungeon then
		return false
	end
	if UnitOnTaxi("player") then
		return false
	end
	if UnitIsDead("player") or UnitIsGhost("player") then
		return false
	end
	return true
end

-- Update exhaustion overlay alphas
local function UpdateExhaustOverlayAlphas(elapsed)
-- Update pulse phase
	exhaustOverlayPulsePhase = exhaustOverlayPulsePhase + elapsed * EXHAUST_OVERLAY_PULSE_SPEED
	if exhaustOverlayPulsePhase > 1 then
		exhaustOverlayPulsePhase = exhaustOverlayPulsePhase - 1
	end

	local pulseRange = EXHAUST_OVERLAY_PULSE_MAX - EXHAUST_OVERLAY_PULSE_MIN
	local pulseMod = EXHAUST_OVERLAY_PULSE_MIN +
	(pulseRange * (0.5 + 0.5 * math.sin(exhaustOverlayPulsePhase * math.pi * 2)))

	-- Determine target alphas based on exhaustion
	if not ShouldShowExhaustOverlay() then
		for i = 1, 4 do
			exhaustOverlayTargetAlphas[i] = 0
		end
	else
		local level = GetExhaustOverlayLevel()
		for i = 1, 4 do
			if i <= level then
				exhaustOverlayTargetAlphas[i] = 0.7
				if exhaustOverlayFrames[i] and not exhaustOverlayFrames[i]:IsShown() then
					exhaustOverlayFrames[i]:SetAlpha(0)
					exhaustOverlayFrames[i]:Show()
				end
			else
				exhaustOverlayTargetAlphas[i] = 0
			end
		end
	end

	-- Smooth interpolation for exhaustion overlays
	for i = 1, 4 do
		local frame = exhaustOverlayFrames[i]
		if frame then
			local diff = exhaustOverlayTargetAlphas[i] - exhaustOverlayCurrentAlphas[i]
			if math.abs(diff) < 0.01 then
				exhaustOverlayCurrentAlphas[i] = exhaustOverlayTargetAlphas[i]
			else
				local speed = diff > 0 and 2.0 or 1.0
				exhaustOverlayCurrentAlphas[i] = exhaustOverlayCurrentAlphas[i] + (diff * speed * elapsed)
			end
			exhaustOverlayCurrentAlphas[i] = math.max(0, math.min(1, exhaustOverlayCurrentAlphas[i]))
			frame:SetAlpha(exhaustOverlayCurrentAlphas[i] * pulseMod)

			if exhaustOverlayCurrentAlphas[i] <= 0.01 and exhaustOverlayTargetAlphas[i] == 0 then
				frame:Hide()
				exhaustOverlayCurrentAlphas[i] = 0
			end
		end
	end
end

------------------------------------------------------------
-- Movement accumulation rates (per second while moving)
------------------------------------------------------------
local RATE_ON_FOOT = 0.025 -- Walking/running
local RATE_ON_MOUNT = 0.005 -- Mounted travel
local RATE_IN_COMBAT = 0.05  -- In combat (halved from 0.1)
local RATE_SWIMMING = 0.04  -- Swimming (faster than walking, less than combat)

------------------------------------------------------------
-- Low constitution penalty (walk-only enforcement)
------------------------------------------------------------
local LOW_CONSTITUTION_THRESHOLD = 25 -- Below this, running incurs heavy penalty
local LOW_CONSTITUTION_RUN_MULTIPLIER = 3.0 -- 3x exhaustion when running at low constitution
local LOW_CONSTITUTION_WALK_SPEED = 7 -- Speed below this is considered walking
local lowConstitutionWarningCooldown = 0 -- Cooldown for warning message

------------------------------------------------------------
-- Glow tracking for meter UI
-- Glow types: 0=none, 0.5=idle, 1=mounted, 2=walking, 2.5=swimming, 3=combat
------------------------------------------------------------
local currentGlowType = 0
local currentGlowIntensity = 0
local GLOW_DECAY_RATE = 3.0 -- How fast glow fades when not accumulating
local isDecaying = false -- Track if exhaustion is currently decaying

------------------------------------------------------------
-- Core logic
------------------------------------------------------------
local function CanDecayExhaustion()
	if CC and CC.inCombat then
		return false
	end
	if UnitOnTaxi("player") then
		return false
	end
	if isInDungeon then
		return false
	end
	if IsResting() then
		return true
	end
	if CC and CC.isNearFire then
		return true
	end
	return false
end

local function ShouldAccumulateExhaustion()
	if not GetSetting("exhaustionEnabled", true) then
		return false
	end
	if not IsEligible() then
		return false
	end
	if isInDungeon then
		return false
	end
	if UnitOnTaxi("player") then
		return false
	end

	-- LITE MODE: Only do proximity checks when /rest is used (Manual Rest Mode)
	local onlyExhaustion =
		GetSetting("exhaustionEnabled", true)
		and not GetSetting("AnguishEnabled", false)
		and not GetSetting("hungerEnabled", false)
		and not GetSetting("temperatureEnabled", false)

	if onlyExhaustion then
	-- If in Manual Rest Mode, only allow accumulation if manual rest is active
		if GetSetting("fireDetectionMode", 1) == 2 then
			return CC and CC.isManualRestActive == true
		end
		-- In Auto Detect mode, always accumulate (no proximity check)
		return true
	end

	-- Normal mode: block accumulation if resting; (near-fire behavior is decay, not block)
	if IsResting() then
		return false
	end
	return true
end

local function IsPlayerMounted()
	return IsMounted() or UnitOnTaxi("player")
end

local function GetMovementRate()
	if CC and CC.inCombat then
		return RATE_IN_COMBAT
	elseif IsSwimming() then
		return RATE_SWIMMING
	elseif IsPlayerMounted() then
		return RATE_ON_MOUNT
	else
		return RATE_ON_FOOT
	end
end

local function GetConstitution()
	if CC and CC.GetConstitution then
		return CC.GetConstitution()
	end
	return nil
end

local function CheckMovementAndAccumulate(elapsed)
	if not ShouldAccumulateExhaustion() then
		currentGlowType = 0
		return
	end

	-- Update low constitution warning cooldown
	if lowConstitutionWarningCooldown > 0 then
		lowConstitutionWarningCooldown = lowConstitutionWarningCooldown - elapsed
	end

	-- Check if player is actively moving
	local playerSpeed = GetUnitSpeed("player") or 0
	local isActivelyMoving = playerSpeed > 0
	local isRunning = playerSpeed > LOW_CONSTITUTION_WALK_SPEED

	-- Check constitution for walk-only enforcement
	local constitution = GetConstitution()
	local lowConstitutionPenalty = false
	if constitution and constitution < LOW_CONSTITUTION_THRESHOLD and isRunning and not IsPlayerMounted() then
		lowConstitutionPenalty = true
		-- Show warning message (with cooldown to prevent spam)
		if lowConstitutionWarningCooldown <= 0 then
			print("|cffFF6600CozierCamps:|r |cffFFAAAAYou're too weak to run! Walking is safer.|r")
			lowConstitutionWarningCooldown = 10 -- seconds
		end
	end

	-- Update glow effect based on current state
	if CC and CC.inCombat then
		currentGlowType = 3
		currentGlowIntensity = 1.0
	elseif IsSwimming() then
	-- Swimming drains faster than walking
		currentGlowType = 2.5
		currentGlowIntensity = 0.9
	elseif isActivelyMoving then
		if IsPlayerMounted() then
			currentGlowType = 1
			currentGlowIntensity = 0.5
		else
			currentGlowType = 2
			currentGlowIntensity = lowConstitutionPenalty and 1.0 or 0.75
		end
	else
		currentGlowType = 0
		currentGlowIntensity = 0
	end

	-- Accumulate exhaustion while moving (per-frame, no debounce)
	if isActivelyMoving or (CC and CC.inCombat) then
		local rate = GetMovementRate()
		if lowConstitutionPenalty then
			rate = rate * LOW_CONSTITUTION_RUN_MULTIPLIER
		end

		local increase = rate * elapsed
		exhaustion = math.min(maxExhaustion, exhaustion + increase)
	end
end

local logTimer = 0

-- Update glow intensity decay
local function UpdateGlow(elapsed)
	if currentGlowType == 0 and currentGlowIntensity > 0 then
		currentGlowIntensity = currentGlowIntensity - (GLOW_DECAY_RATE * elapsed)
		if currentGlowIntensity <= 0 then
			currentGlowIntensity = 0
		end
	end
end

function CC.HandleExhaustionDecay(elapsed)
	UpdateGlow(elapsed)
	UpdateExhaustOverlayAlphas(elapsed)

	-- Movement accumulation and glow
	CheckMovementAndAccumulate(elapsed)

	-- Check for decay (separate from accumulation)
	if not CanDecayExhaustion() or exhaustion <= 0 then
		isDecaying = false
		return
	end

	-- Actively decaying
	isDecaying = true

	-- Use faster rate for inns/rested areas, slower rate for campfires
	local rate
	if IsResting() then
		rate = GetSetting("exhaustionInnDecayRate", 1.5)
	else
		rate = GetSetting("exhaustionDecayRate", 0.5)
	end

	exhaustion = math.max(0, exhaustion - rate * elapsed)

	logTimer = logTimer + elapsed
	if logTimer >= 1.0 then
		logTimer = 0
		if GetSetting("exhaustionDebugEnabled", false) then
			local location = IsResting() and "resting" or "near fire"
			Debug(string.format("Recovering (%s @ %.1f/sec)... Exhaustion: %.1f%%", location, rate, exhaustion))
		end
	end
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function CC.GetExhaustionGlow()
	return currentGlowType, currentGlowIntensity
end

function CC.IsExhaustionDecaying()
	return isDecaying and exhaustion > 0
end

function CC.GetExhaustion()
	return exhaustion
end

function CC.GetExhaustionPercent()
	return exhaustion / maxExhaustion
end

function CC.SetExhaustion(value)
	value = tonumber(value)
	if not value then
		return false
	end
	exhaustion = math.min(maxExhaustion, math.max(0, value))
	Debug(string.format("Exhaustion set to %.1f%%", exhaustion))
	return true
end

function CC.ResetExhaustion()
	exhaustion = 0
end

function CC.IsInDungeon()
	return isInDungeon
end

function CC.IsExhaustionActive()
	return ShouldAccumulateExhaustion()
end

function CC.IsExhaustionPaused()
-- Returns true only when paused due to dungeon, taxi, dead, or ghost (not resting)
	if not GetSetting("exhaustionEnabled", true) then
		return false
	end
	if not IsEligible() then
		return false
	end
	return isInDungeon or UnitOnTaxi("player") or UnitIsDead("player") or UnitIsGhost("player")
end

function CC.GetExhaustionActivity()
	if CC.IsExhaustionPaused() then
		return nil
	end
	if isDecaying then
		if CC and CC.isNearFire then
			return "Resting by fire"
		elseif IsResting() then
			return "Resting in town"
		end
		return "Recovering"
	end
	-- Check what's causing drain (supports multiple states)
	local states = {}
	local isSwimming = IsSwimming()

	-- Check swimming separately since it can combine with combat
	if isSwimming then
		table.insert(states, "Swimming")
	end

	-- Check primary drain state
	local glowType = currentGlowType
	if glowType >= 3 or (CC and CC.inCombat) then
		table.insert(states, "In combat")
	elseif glowType >= 2 and not isSwimming then
		table.insert(states, "On foot")
	elseif glowType >= 1 and not isSwimming then
	-- Can't be mounted while swimming
		table.insert(states, "Mounted")
	elseif glowType >= 0.5 and not isSwimming then
		table.insert(states, "Idle")
	end

	if #states > 0 then
		return table.concat(states, ", ")
	end
	return nil
end

------------------------------------------------------------
-- Zone / instance transitions
------------------------------------------------------------
local function OnZoneChanged()
	local wasInDungeon = isInDungeon
	isInDungeon = CheckDungeonStatus()

	if isInDungeon and not wasInDungeon then
		savedExhaustion = exhaustion
		Debug(string.format("Entering dungeon - exhaustion paused at %.1f%%", savedExhaustion))
	elseif not isInDungeon and wasInDungeon then
		exhaustion = savedExhaustion
		Debug(string.format("Leaving dungeon - exhaustion restored to %.1f%%", exhaustion))
	end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "CozierCampsExhaustionFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		CreateAllExhaustOverlayFrames()

		if CC and CC.charDB and CC.charDB.savedExhaustion then
			exhaustion = CC.charDB.savedExhaustion
			Debug(string.format("Exhaustion restored: %.1f%%", exhaustion))
		else
			exhaustion = 0
		end

		savedExhaustion = 0
		isInDungeon = CheckDungeonStatus()

		-- Restore saved pre-dungeon value if we're loading inside a dungeon
		if isInDungeon and CC.charDB and CC.charDB.savedExhaustionPreDungeon then
			savedExhaustion = CC.charDB.savedExhaustionPreDungeon
			Debug(string.format("Pre-dungeon exhaustion restored: %.1f%%", savedExhaustion))
		end

	elseif event == "PLAYER_LOGOUT" then
		if CC and CC.charDB then
			CC.charDB.savedExhaustion = exhaustion
			if isInDungeon then
				CC.charDB.savedExhaustionPreDungeon = savedExhaustion
			else
				CC.charDB.savedExhaustionPreDungeon = nil
			end
		end

	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		OnZoneChanged()
	end
end)
