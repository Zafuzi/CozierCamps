-- CozyCamps - Temperature.lua
-- Temperature system - bidirectional meter that tracks heat/cold based on zone, weather, and activities
local CC = CozyCamps

-- Temperature scale: -100 (Freezing) to +100 (Scorching), 0 is neutral
local temperature = 0
local savedTemperature = 0
local MIN_TEMPERATURE = -100
local MAX_TEMPERATURE = 100
local isInDungeon = false

-- Update tracking
local updateTimer = 0
local UPDATE_INTERVAL = 1.0 -- Update every second

-- ============================================
-- TEMPERATURE OVERLAY SYSTEM
-- ============================================
-- Texture paths for cold overlays (negative temperature)
local COLD_TEXTURES = {"Interface\\AddOns\\CozyCamps\\assets\\cold20.png",
	"Interface\\AddOns\\CozyCamps\\assets\\cold40.png",
	"Interface\\AddOns\\CozyCamps\\assets\\cold60.png",
	"Interface\\AddOns\\CozyCamps\\assets\\cold80.png"}

-- Texture paths for hot overlays (positive temperature)
local HOT_TEXTURES = {"Interface\\AddOns\\CozyCamps\\assets\\hot20.png",
	"Interface\\AddOns\\CozyCamps\\assets\\hot40.png",
	"Interface\\AddOns\\CozyCamps\\assets\\hot60.png",
	"Interface\\AddOns\\CozyCamps\\assets\\hot80.png"}

-- Overlay frames and alpha tracking
local coldOverlayFrames = {}
local coldOverlayCurrentAlphas = {0, 0, 0, 0}
local coldOverlayTargetAlphas = {0, 0, 0, 0}

local hotOverlayFrames = {}
local hotOverlayCurrentAlphas = {0, 0, 0, 0}
local hotOverlayTargetAlphas = {0, 0, 0, 0}
-- Wet overlay (single layer, shown when wet effect is active)
local WET_TEXTURE = "Interface\\AddOns\\CozyCamps\\assets\\wet.png"
local wetOverlayFrame = nil
local wetOverlayCurrentAlpha = 0
local wetOverlayTargetAlpha = 0
local WET_OVERLAY_MAX_ALPHA = 0.35 -- Higher alpha with darkened texture
local WET_OVERLAY_FADE_SPEED = 1.5 -- Fade in/out speed

-- Drying overlay (orange glow on screen edges when drying off)
local DRYING_TEXTURE = "Interface\\AddOns\\CozyCamps\\assets\\hot20.png"
local dryingOverlayFrame = nil
local dryingOverlayCurrentAlpha = 0
local dryingOverlayTargetAlpha = 0
local DRYING_OVERLAY_MAX_ALPHA = 0.85 -- Strong visible warming effect
local DRYING_OVERLAY_FADE_SPEED = 2.0 -- Slightly faster fade
local dryingOverlayPulsePhase = 0
local DRYING_PULSE_SPEED = 0.8 -- Pulse speed
local DRYING_PULSE_MIN = 0.5
local DRYING_PULSE_MAX = 1.0

-- Pulse effect for temperature overlays
local tempOverlayPulsePhase = 0
local TEMP_OVERLAY_PULSE_SPEED = 0.5
local TEMP_OVERLAY_PULSE_MIN = 0.7
local TEMP_OVERLAY_PULSE_MAX = 1.0

-- Get overlay level based on temperature (0-4)
local function GetColdOverlayLevel()
	local absTemp = math.abs(temperature)
	if temperature >= 0 then
		return 0
	end
	if absTemp >= 80 then
		return 4
	elseif absTemp >= 60 then
		return 3
	elseif absTemp >= 40 then
		return 2
	elseif absTemp >= 20 then
		return 1
	else
		return 0
	end
end

local function GetHotOverlayLevel()
	if temperature <= 0 then
		return 0
	end
	if temperature >= 80 then
		return 4
	elseif temperature >= 60 then
		return 3
	elseif temperature >= 40 then
		return 2
	elseif temperature >= 20 then
		return 1
	else
		return 0
	end
end

-- Check if temperature overlays should be shown
local function ShouldShowTemperatureOverlay()
	if not CC.GetSetting("temperatureEnabled") then
		return false
	end
	if not CC.IsPlayerEligible() then
		return false
	end
	if isInDungeon then
		return false
	end
	if UnitOnTaxi("player") then
		return false
	end
	return true
end

-- Create cold overlay frame for a specific level
local function CreateColdOverlayFrame(level)
	if coldOverlayFrames[level] then
		return coldOverlayFrames[level]
	end

	local frame = CreateFrame("Frame", "CozyCampsColdOverlay_" .. level, UIParent)
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(80 + level) -- Temperature is lowest layer

	frame.texture = frame:CreateTexture(nil, "BACKGROUND")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture(COLD_TEXTURES[level])
	frame.texture:SetBlendMode("BLEND")

	frame:SetAlpha(0)
	frame:Hide()

	coldOverlayFrames[level] = frame
	return frame
end

-- Create hot overlay frame for a specific level
local function CreateHotOverlayFrame(level)
	if hotOverlayFrames[level] then
		return hotOverlayFrames[level]
	end

	local frame = CreateFrame("Frame", "CozyCampsHotOverlay_" .. level, UIParent)
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(80 + level) -- Temperature is lowest layer

	frame.texture = frame:CreateTexture(nil, "BACKGROUND")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture(HOT_TEXTURES[level])
	frame.texture:SetBlendMode("BLEND")

	frame:SetAlpha(0)
	frame:Hide()

	hotOverlayFrames[level] = frame
	return frame
end

-- Create wet overlay frame (lowest layer, behind temperature overlays)
local function CreateWetOverlayFrame()
	if wetOverlayFrame then
		return wetOverlayFrame
	end

	local frame = CreateFrame("Frame", "CozyCampsWetOverlay", UIParent)
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata("LOW") -- Behind UI elements
	frame:SetFrameLevel(1) -- Lowest level in this strata

	frame.texture = frame:CreateTexture(nil, "BACKGROUND")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture(WET_TEXTURE)
	frame.texture:SetBlendMode("ADD")
	frame.texture:SetVertexColor(0.4, 0.5, 0.6) -- Darken and add slight blue tint

	frame:SetAlpha(0)
	frame:Hide()

	wetOverlayFrame = frame
	return frame
end

-- Create drying overlay frame (orange glow on edges when drying)
local function CreateDryingOverlayFrame()
	if dryingOverlayFrame then
		return dryingOverlayFrame
	end

	local frame = CreateFrame("Frame", "CozyCampsDryingOverlay", UIParent)
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata("LOW") -- Behind UI elements
	frame:SetFrameLevel(2) -- Just above wet overlay

	frame.texture = frame:CreateTexture(nil, "BACKGROUND")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture(DRYING_TEXTURE)
	frame.texture:SetBlendMode("ADD")
	frame.texture:SetVertexColor(1.0, 0.6, 0.2) -- Orange tint

	frame:SetAlpha(0)
	frame:Hide()

	dryingOverlayFrame = frame
	return frame
end

-- Create all temperature overlay frames
local function CreateAllTemperatureOverlayFrames()
	for i = 1, 4 do
		CreateColdOverlayFrame(i)
		CreateHotOverlayFrame(i)
	end
	CreateWetOverlayFrame() -- Also create wet overlay
	CreateDryingOverlayFrame() -- Also create drying overlay
end

-- Update temperature overlay alphas
local function UpdateTemperatureOverlayAlphas(elapsed)
-- Update pulse phase
	tempOverlayPulsePhase = tempOverlayPulsePhase + elapsed * TEMP_OVERLAY_PULSE_SPEED
	if tempOverlayPulsePhase > 1 then
		tempOverlayPulsePhase = tempOverlayPulsePhase - 1
	end

	local pulseRange = TEMP_OVERLAY_PULSE_MAX - TEMP_OVERLAY_PULSE_MIN
	local pulseMod = TEMP_OVERLAY_PULSE_MIN + (pulseRange * (0.5 + 0.5 * math.sin(tempOverlayPulsePhase * math.pi * 2)))

	-- Determine target alphas based on temperature
	if not ShouldShowTemperatureOverlay() then
		for i = 1, 4 do
			coldOverlayTargetAlphas[i] = 0
			hotOverlayTargetAlphas[i] = 0
		end
	else
		local coldLevel = GetColdOverlayLevel()
		local hotLevel = GetHotOverlayLevel()

		for i = 1, 4 do
		-- Cold overlays
			if i <= coldLevel then
				coldOverlayTargetAlphas[i] = 0.7
				if coldOverlayFrames[i] and not coldOverlayFrames[i]:IsShown() then
					coldOverlayFrames[i]:SetAlpha(0)
					coldOverlayFrames[i]:Show()
				end
			else
				coldOverlayTargetAlphas[i] = 0
			end

			-- Hot overlays
			if i <= hotLevel then
				hotOverlayTargetAlphas[i] = 0.7
				if hotOverlayFrames[i] and not hotOverlayFrames[i]:IsShown() then
					hotOverlayFrames[i]:SetAlpha(0)
					hotOverlayFrames[i]:Show()
				end
			else
				hotOverlayTargetAlphas[i] = 0
			end
		end
	end

	-- Smooth interpolation for cold overlays
	for i = 1, 4 do
		local frame = coldOverlayFrames[i]
		if frame then
			local diff = coldOverlayTargetAlphas[i] - coldOverlayCurrentAlphas[i]
			if math.abs(diff) < 0.01 then
				coldOverlayCurrentAlphas[i] = coldOverlayTargetAlphas[i]
			else
				local speed = diff > 0 and 2.0 or 1.0
				coldOverlayCurrentAlphas[i] = coldOverlayCurrentAlphas[i] + (diff * speed * elapsed)
			end
			coldOverlayCurrentAlphas[i] = math.max(0, math.min(1, coldOverlayCurrentAlphas[i]))
			frame:SetAlpha(coldOverlayCurrentAlphas[i] * pulseMod)

			if coldOverlayCurrentAlphas[i] <= 0.01 and coldOverlayTargetAlphas[i] == 0 then
				frame:Hide()
				coldOverlayCurrentAlphas[i] = 0
			end
		end
	end

	-- Smooth interpolation for hot overlays
	for i = 1, 4 do
		local frame = hotOverlayFrames[i]
		if frame then
			local diff = hotOverlayTargetAlphas[i] - hotOverlayCurrentAlphas[i]
			if math.abs(diff) < 0.01 then
				hotOverlayCurrentAlphas[i] = hotOverlayTargetAlphas[i]
			else
				local speed = diff > 0 and 2.0 or 1.0
				hotOverlayCurrentAlphas[i] = hotOverlayCurrentAlphas[i] + (diff * speed * elapsed)
			end
			hotOverlayCurrentAlphas[i] = math.max(0, math.min(1, hotOverlayCurrentAlphas[i]))
			frame:SetAlpha(hotOverlayCurrentAlphas[i] * pulseMod)

			if hotOverlayCurrentAlphas[i] <= 0.01 and hotOverlayTargetAlphas[i] == 0 then
				frame:Hide()
				hotOverlayCurrentAlphas[i] = 0
			end
		end
	end
end

-- Update wet overlay alpha (fade in/out based on wet effect state)
local function UpdateWetOverlayAlpha(elapsed, isWet)
-- Create frame if needed (in case it wasn't created at init)
	if not wetOverlayFrame then
		CreateWetOverlayFrame()
	end

	-- Check if wet screen effect is enabled
	local wetScreenEnabled = CC.GetSetting and CC.GetSetting("wetScreenEffectEnabled")

	-- Determine target alpha based on wet state and setting
	if isWet and wetScreenEnabled then
		wetOverlayTargetAlpha = WET_OVERLAY_MAX_ALPHA
		if wetOverlayFrame and not wetOverlayFrame:IsShown() then
			wetOverlayFrame:SetAlpha(0)
			wetOverlayFrame:Show()
		end
	else
		wetOverlayTargetAlpha = 0
	end

	-- Smooth interpolation
	if wetOverlayFrame then
		local diff = wetOverlayTargetAlpha - wetOverlayCurrentAlpha
		if math.abs(diff) < 0.01 then
			wetOverlayCurrentAlpha = wetOverlayTargetAlpha
		else
			wetOverlayCurrentAlpha = wetOverlayCurrentAlpha + (diff * WET_OVERLAY_FADE_SPEED * elapsed)
		end
		wetOverlayCurrentAlpha = math.max(0, math.min(1, wetOverlayCurrentAlpha))
		wetOverlayFrame:SetAlpha(wetOverlayCurrentAlpha)

		if wetOverlayCurrentAlpha <= 0.01 and wetOverlayTargetAlpha == 0 then
			wetOverlayFrame:Hide()
			wetOverlayCurrentAlpha = 0
		end
	end
end

-- Update drying overlay alpha (orange glow with pulse when drying off)
local function UpdateDryingOverlayAlpha(elapsed, isWet, isDrying)
-- Create frame if needed
	if not dryingOverlayFrame then
		CreateDryingOverlayFrame()
	end

	-- Update pulse phase
	dryingOverlayPulsePhase = dryingOverlayPulsePhase + elapsed * DRYING_PULSE_SPEED
	if dryingOverlayPulsePhase > 1 then
		dryingOverlayPulsePhase = dryingOverlayPulsePhase - 1
	end

	local pulseRange = DRYING_PULSE_MAX - DRYING_PULSE_MIN
	local pulseMod = DRYING_PULSE_MIN + (pulseRange * (0.5 + 0.5 * math.sin(dryingOverlayPulsePhase * math.pi * 2)))

	-- Show when wet AND drying (near fire or resting)
	if isWet and isDrying then
		dryingOverlayTargetAlpha = DRYING_OVERLAY_MAX_ALPHA
		if dryingOverlayFrame and not dryingOverlayFrame:IsShown() then
			dryingOverlayFrame:SetAlpha(0)
			dryingOverlayFrame:Show()
		end
	else
		dryingOverlayTargetAlpha = 0
	end

	-- Smooth interpolation with pulse
	if dryingOverlayFrame then
		local diff = dryingOverlayTargetAlpha - dryingOverlayCurrentAlpha
		if math.abs(diff) < 0.01 then
			dryingOverlayCurrentAlpha = dryingOverlayTargetAlpha
		else
			dryingOverlayCurrentAlpha = dryingOverlayCurrentAlpha + (diff * DRYING_OVERLAY_FADE_SPEED * elapsed)
		end
		dryingOverlayCurrentAlpha = math.max(0, math.min(1, dryingOverlayCurrentAlpha))

		-- Apply pulse modulation to the alpha
		dryingOverlayFrame:SetAlpha(dryingOverlayCurrentAlpha * pulseMod)

		if dryingOverlayCurrentAlpha <= 0.01 and dryingOverlayTargetAlpha == 0 then
			dryingOverlayFrame:Hide()
			dryingOverlayCurrentAlpha = 0
		end
	end
end

-- Comfortable temperature (baseline for calculating effects)
local COMFORTABLE_TEMP = 20 -- Celsius

-- Zone temperature database (zone key -> base temperature in Celsius)
-- Keys are lowercase with no spaces for reliable matching
local ZONE_BASE_TEMPS = {
	-- === EASTERN KINGDOMS - Outdoor Zones ===
	["elwynnforest"] = 24,
	["westfall"] = 25,
	["redridgemountains"] = 19,
	["duskwood"] = 12,
	["stranglethornvale"] = 30,
	["tirisfalglades"] = 10,
	["silverpineforest"] = 14,
	["hillsbradfoothills"] = 18,
	["arathihighlands"] = 22,
	["wetlands"] = 16,
	["lochmodan"] = 17,
	["thehinterlands"] = 19,
	["hinterlands"] = 19,
	["westernplaguelands"] = 11,
	["easternplaguelands"] = 10,
	["deadwindpass"] = 9,
	["swampofsorrows"] = 23,
	["blastedlands"] = 39,
	["badlands"] = 37,
	["searinggorge"] = 41,
	["burningsteppes"] = 42,
	["dunmorogh"] = -5,
	["alteracmountains"] = 8,

	-- === EASTERN KINGDOMS - Cities ===
	["stormwindcity"] = 22,
	["stormwind"] = 22,
	["ironforge"] = -8,
	["undercity"] = 10,

	-- === KALIMDOR - Outdoor Zones ===
	["durotar"] = 36,
	["mulgore"] = 20,
	["thebarrens"] = 35,
	["barrens"] = 35,
	["teldrassil"] = 15,
	["darkshore"] = 13,
	["ashenvale"] = 12,
	["stonetalonmountains"] = 20,
	["desolace"] = 28,
	["feralas"] = 22,
	["dustwallowmarsh"] = 27,
	["thousandneedles"] = 35,
	["tanaris"] = 40,
	["ungorocrater"] = 33,
	["silithus"] = 38,
	["azshara"] = 29,
	["felwood"] = 12,
	["winterspring"] = -10,
	["moonglade"] = 18,

	-- === KALIMDOR - Cities ===
	["orgrimmar"] = 38,
	["thunderbluff"] = 25,
	["darnassus"] = 16,

	-- === DUNGEONS ===
	["ragefirechasm"] = 42,
	["thewailingcaverns"] = 19,
	["wailingcaverns"] = 19,
	["thedeadmines"] = 25,
	["deadmines"] = 25,
	["shadowfangkeep"] = 18,
	["blackfathomdeeps"] = 11,
	["thestockade"] = 21,
	["stockade"] = 21,
	["gnomeregan"] = 24,
	["razorfenkraul"] = 30,
	["razorfendowns"] = 17,
	["scarletmonastery"] = 19,
	["uldaman"] = 30,
	["zulfarrak"] = 43,
	["maraudon"] = 31,
	["templeofatalhakkar"] = 35,
	["sunkentemple"] = 35,
	["diremaul"] = 30,
	["scholomance"] = 14,
	["stratholme"] = 26,
	["lowerblackrockspire"] = 38,
	["upperblackrockspire"] = 38,
	["blackrockspire"] = 38,
	["blackrockdepths"] = 35,

	-- === RAIDS ===
	["moltencore"] = 60,
	["onyxiaslair"] = 50,
	["blackwinglair"] = 55,
	["zulgurub"] = 35,
	["ruinsofahnqiraj"] = 40,
	["templeofahnqiraj"] = 42,
	["naxxramas"] = -5,

	-- === BATTLEGROUNDS ===
	["warsonggulch"] = 20,
	["arathibasin"] = 22,
	["alteracvalley"] = -8,

	-- Default for unknown zones
	["default"] = 20
}

-- Day/night temperature fluctuation system
-- Peak warm: 2pm (14:00), Peak cold: 2am (02:00)
-- Fluctuation magnitude scales with how extreme the base temp is

-- Get normalized zone key from zone name
local function GetZoneKey(zoneName)
	if not zoneName then
		return "default"
	end
	return zoneName:lower():gsub("%s+", ""):gsub("'", ""):gsub("-", "")
end

-- Get the current time factor (-1 to +1)
-- +1 at 2pm (peak warm), -1 at 2am (peak cold), 0 at 8am/8pm (neutral transition)
local function GetTimeFactor()
	local hour, minute = GetGameTime()
	local timeInHours = hour + (minute / 60)
	-- sin((hour - 8) * π / 12) gives us:
	-- hour=14 (2pm): sin(6π/12) = sin(π/2) = 1.0 (peak warm)
	-- hour=2 (2am): sin(-6π/12) = sin(-π/2) = -1.0 (peak cold)
	-- hour=8 (8am): sin(0) = 0 (neutral, warming up)
	-- hour=20 (8pm): sin(π) = 0 (neutral, cooling down)
	return math.sin((timeInHours - 8) * math.pi / 12)
end

-- Calculate the fluctuation magnitude based on base temperature
-- More extreme base temps = wider fluctuation
local function GetFluctuationMagnitude(baseTemp)
	local distanceFromComfort = math.abs(baseTemp - COMFORTABLE_TEMP)
	-- Base fluctuation of 4 degrees + 0.2 per degree away from comfortable
	-- Elwynn (24): 4 + |24-20|*0.2 = 4.8 degrees swing
	-- Winterspring (-10): 4 + |(-10)-20|*0.2 = 10 degrees swing
	return 4 + (distanceFromComfort * 0.2)
end

-- Get the current environmental temperature for a zone (including day/night effects)
local function GetEnvironmentalTemperature(zoneName)
	local zoneKey = GetZoneKey(zoneName)
	local baseTemp = ZONE_BASE_TEMPS[zoneKey] or ZONE_BASE_TEMPS["default"]
	local timeFactor = GetTimeFactor()
	local fluctuation = GetFluctuationMagnitude(baseTemp)

	-- Apply time-based fluctuation
	-- Positive timeFactor = daytime = warmer
	-- Negative timeFactor = nighttime = colder
	local envTemp = baseTemp + (timeFactor * fluctuation)

	return envTemp, baseTemp, timeFactor, fluctuation
end

-- Rate modifiers for directional temperature change
-- During day: warming is faster, cooling is slower
-- During night: cooling is faster, warming is slower
local DAY_WARM_RATE = 1.5 -- 50% faster warming during day
local DAY_COOL_RATE = 0.6 -- 40% slower cooling during day
local NIGHT_COOL_RATE = 1.5 -- 50% faster cooling at night
local NIGHT_WARM_RATE = 0.6 -- 40% slower warming at night

-- Get the rate modifier based on time of day and temperature change direction
local function GetDirectionalRateModifier(tempChangeDirection)
	local timeFactor = GetTimeFactor()

	if timeFactor > 0 then
	-- Daytime (positive timeFactor)
		if tempChangeDirection > 0 then
			return DAY_WARM_RATE -- Getting warmer during day = faster
		else
			return DAY_COOL_RATE -- Getting colder during day = slower
		end
	else
	-- Nighttime (negative timeFactor)
		if tempChangeDirection < 0 then
			return NIGHT_COOL_RATE -- Getting colder at night = faster
		else
			return NIGHT_WARM_RATE -- Getting warmer at night = slower
		end
	end
end

-- Weather effects on temperature (per second) - reduced by 10x for gradual change
-- Positive values increase heat, negative decrease
local WEATHER_EFFECTS = {
	-- Rain effects (cooling)
	[1] = -0.025, -- Light Rain
	[2] = -0.04, -- Medium Rain
	[3] = -0.05, -- Heavy Rain
	["Rain"] = -0.04,
	["Blood Rain"] = -0.04, -- Same as rain

	-- Snow effects (very cooling)
	[6] = -0.075, -- Light Snow
	[7] = -0.1, -- Medium Snow
	[8] = -0.125, -- Heavy Snow
	["Snow"] = -0.1,

	-- Storm effects (warming - magical/arcane energy)
	["Arcane Storm"] = 0.05,

	-- Dust/Sand storms (very warming)
	["Dust Storm"] = 0.1,
	["Sandstorm"] = 0.125
}

-- Rate modifiers (reduced by 10x for gradual accumulation)
local INDOOR_MODIFIER = 0.3 -- Indoor weather effects are 30% as strong
local SWIMMING_HEAT_REDUCTION = -0.1 -- Swimming cools you down (per second)
local SWIMMING_COLD_INCREASE = -0.075 -- Swimming makes cold worse (per second if already cold)
local WET_DURATION = 300 -- 5 minutes (300 seconds)
local WET_COLD_MULTIPLIER_MAX = 2.0 -- Maximum 2x cooling when very cold
local WET_HEAT_REDUCTION = -0.075 -- Wet effect helps cool you down in hot areas (per second) - halved
local DRINKING_COOLING_RATE = -0.5 -- Drinking water reduces heat powerfully (overpowers any heating)
local MANA_POTION_DURATION = 30 -- Mana potion cooling lasts 30 seconds
local MANA_POTION_HEAT_REDUCTION = 0.20 -- Mana potions reduce 20% of heat buildup
local WELL_FED_COLD_MODIFIER = 0.5 -- Well Fed reduces cold accumulation by 50%
local FIRE_OUTDOOR_RECOVERY = 0.05 -- Fire brings cold back towards 0 (per second)
local FIRE_INDOOR_RECOVERY = 0.2 -- Indoor fire recovers faster (doubled for recovery)
local INN_RECOVERY = 0.5 -- Inns bring temperature back to neutral (doubled for recovery)

-- Recovery rate multiplier (going back toward 0 is faster than accumulating away from 0)
local RECOVERY_RATE_MULTIPLIER = 2.0 -- Double speed when recovering toward 0

-- Equilibrium message tracking
local lastEquilibriumMessage = nil
local equilibriumMessageCooldown = 0
local EQUILIBRIUM_MESSAGE_COOLDOWN = 30 -- Don't spam messages

-- Decay towards neutral when no effects active
local NEUTRAL_DECAY_RATE = 0.01 -- Slowly return to 0 when no active effects

-- ============================================
-- MANUAL WEATHER SYSTEM
-- ============================================

-- Weather types for manual toggle
local WEATHER_TYPE_NONE = 0
local WEATHER_TYPE_RAIN = 1
local WEATHER_TYPE_SNOW = 2
local WEATHER_TYPE_DUST = 3

-- Zone to possible weather type mapping (what weather can occur in each zone)
-- Keys are lowercase with no spaces for reliable matching
local ZONE_WEATHER_TYPES = {
	-- Rain zones (temperate, wet climates)
	["elwynnforest"] = WEATHER_TYPE_RAIN,
	["westfall"] = WEATHER_TYPE_RAIN,
	["redridgemountains"] = WEATHER_TYPE_RAIN,
	["duskwood"] = WEATHER_TYPE_RAIN,
	["stranglethornvale"] = WEATHER_TYPE_RAIN,
	["tirisfalglades"] = WEATHER_TYPE_RAIN,
	["silverpineforest"] = WEATHER_TYPE_RAIN,
	["hillsbradfoothills"] = WEATHER_TYPE_RAIN,
	["arathihighlands"] = WEATHER_TYPE_RAIN,
	["wetlands"] = WEATHER_TYPE_RAIN,
	["lochmodan"] = WEATHER_TYPE_RAIN,
	["thehinterlands"] = WEATHER_TYPE_RAIN,
	["hinterlands"] = WEATHER_TYPE_RAIN,
	["westernplaguelands"] = WEATHER_TYPE_RAIN,
	["easternplaguelands"] = WEATHER_TYPE_RAIN,
	["swampofsorrows"] = WEATHER_TYPE_RAIN,
	["dustwallowmarsh"] = WEATHER_TYPE_RAIN,
	["ashenvale"] = WEATHER_TYPE_RAIN,
	["darkshore"] = WEATHER_TYPE_RAIN,
	["teldrassil"] = WEATHER_TYPE_RAIN,
	["feralas"] = WEATHER_TYPE_RAIN,
	["felwood"] = WEATHER_TYPE_RAIN,
	["stormwindcity"] = WEATHER_TYPE_RAIN,
	["stormwind"] = WEATHER_TYPE_RAIN,
	["darnassus"] = WEATHER_TYPE_RAIN,

	-- Snow zones (cold climates)
	["dunmorogh"] = WEATHER_TYPE_SNOW,
	["alteracmountains"] = WEATHER_TYPE_SNOW,
	["winterspring"] = WEATHER_TYPE_SNOW,
	["ironforge"] = WEATHER_TYPE_SNOW,
	["alteracvalley"] = WEATHER_TYPE_SNOW,

	-- Dust/Sandstorm zones (desert/arid climates)
	["tanaris"] = WEATHER_TYPE_DUST,
	["silithus"] = WEATHER_TYPE_DUST,
	["thousandneedles"] = WEATHER_TYPE_DUST,
	["badlands"] = WEATHER_TYPE_DUST,
	["desolace"] = WEATHER_TYPE_DUST,
	["durotar"] = WEATHER_TYPE_DUST,
	["thebarrens"] = WEATHER_TYPE_DUST,
	["barrens"] = WEATHER_TYPE_DUST,
	["orgrimmar"] = WEATHER_TYPE_DUST,

	-- No weather (indoor, underground, or special zones)
	["undercity"] = WEATHER_TYPE_NONE,
	["deadwindpass"] = WEATHER_TYPE_NONE,
	["blastedlands"] = WEATHER_TYPE_NONE,
	["searinggorge"] = WEATHER_TYPE_NONE,
	["burningsteppes"] = WEATHER_TYPE_NONE,
	["azshara"] = WEATHER_TYPE_NONE,
	["moonglade"] = WEATHER_TYPE_NONE,
	["ungorocrater"] = WEATHER_TYPE_NONE,
	["stonetalonmountains"] = WEATHER_TYPE_NONE,
	["mulgore"] = WEATHER_TYPE_NONE,
	["thunderbluff"] = WEATHER_TYPE_NONE,

	-- Default (no weather for unknown zones)
	["default"] = WEATHER_TYPE_NONE
}

-- Manual weather state
local manualWeatherActive = false
local currentZoneWeatherType = WEATHER_TYPE_NONE
local lastZoneName = nil
local debugWeatherTypeOverride = nil -- Debug override for weather type

-- Weather effect values for manual weather (medium intensity, reduced for gradual change)
local MANUAL_WEATHER_EFFECTS = {
	[WEATHER_TYPE_NONE] = 0,
	[WEATHER_TYPE_RAIN] = -0.04, -- Cooling (same as auto weather)
	[WEATHER_TYPE_SNOW] = -0.1, -- Strong cooling (same as auto weather)
	[WEATHER_TYPE_DUST] = 0.1 -- Heating (same as auto weather)
}

-- Get zone weather type
local function GetZoneWeatherType(zoneName)
	if not zoneName then
		return WEATHER_TYPE_NONE
	end
	local zoneKey = zoneName:lower():gsub("%s+", ""):gsub("'", ""):gsub("-", "")
	return ZONE_WEATHER_TYPES[zoneKey] or ZONE_WEATHER_TYPES["default"]
end

-- Update zone weather type when zone changes
local function UpdateZoneWeatherType()
	local zoneName = GetZoneText()
	if zoneName ~= lastZoneName then
		lastZoneName = zoneName
		currentZoneWeatherType = GetZoneWeatherType(zoneName)
		manualWeatherActive = false -- Reset weather toggle on zone change
		CC.Debug(string.format("Zone changed to %s - weather type: %d, toggle reset", zoneName, currentZoneWeatherType),
			"temperature")
		-- Fire callback for UI to update
		CC.FireCallbacks("ZONE_WEATHER_CHANGED", currentZoneWeatherType, manualWeatherActive)
	end
end

-- Public API for manual weather
function CC.GetZoneWeatherType()
-- Debug override takes priority
	if debugWeatherTypeOverride then
		return debugWeatherTypeOverride
	end
	return currentZoneWeatherType
end

function CC.IsManualWeatherActive()
	return manualWeatherActive
end

function CC.ToggleManualWeather()
	if currentZoneWeatherType == WEATHER_TYPE_NONE then
		return false -- Can't toggle weather in zones with no weather
	end
	manualWeatherActive = not manualWeatherActive
	CC.Debug(string.format("Manual weather toggled: %s", manualWeatherActive and "ON" or "OFF"), "temperature")
	CC.FireCallbacks("MANUAL_WEATHER_CHANGED", manualWeatherActive, currentZoneWeatherType)
	return true
end

function CC.SetManualWeather(active)
	if currentZoneWeatherType == WEATHER_TYPE_NONE then
		manualWeatherActive = false
		return
	end
	manualWeatherActive = active
	CC.FireCallbacks("MANUAL_WEATHER_CHANGED", manualWeatherActive, currentZoneWeatherType)
end

-- Check if weather is paused (indoors)
-- Used by UI to show paused glow on weather button
function CC.IsWeatherPaused()
	return IsIndoors()
end

-- Get manual weather effect (only if enabled and active)
-- Returns 0 when indoors (weather is paused, not just reduced)
local function GetManualWeatherEffect()
	if not CC.GetSetting("manualWeatherEnabled") then
		return 0
	end
	if not manualWeatherActive then
		return 0
	end
	-- Weather is PAUSED (not reduced) when indoors
	if CC.IsWeatherPaused() then
		return 0
	end
	return MANUAL_WEATHER_EFFECTS[currentZoneWeatherType] or 0
end

-- Glow tracking for meter UI
-- Glow types: 0=none, 1=cold, 2=hot, 3=recovering
local currentGlowType = 0
local currentGlowIntensity = 0
local GLOW_DECAY_RATE = 2.0

-- Track temperature change direction for glow
local lastTemperature = 0
local temperatureTrend = 0 -- -1 = cooling, 0 = stable/balanced, 1 = warming
local isTemperatureBalanced = false -- True when forces are balanced (inn, fire, water countering zone)
local hasActiveCounterForce = false -- True when player is using fire/inn/water to counter zone temp

function CC.GetTemperatureTrend()
	return temperatureTrend
end

function CC.IsTemperatureBalanced()
	return isTemperatureBalanced
end

function CC.HasActiveCounterForce()
	return hasActiveCounterForce
end

-- Called during update to track trend and balanced state
local function UpdateTemperatureTrend(newTemp, tempChange, counterForceActive)
	local diff = newTemp - lastTemperature

	-- Track if counter-forces are active (fire, inn, swimming, etc.)
	hasActiveCounterForce = counterForceActive

	-- "Balanced" means we've REACHED equilibrium near 0, not just moving towards it
	-- Only show balanced state (130877 spark, no glow) when:
	-- 1. Counter-force is active AND
	-- 2. Temperature is actually near neutral (-3 to +3) AND
	-- 3. Not significantly moving (stable)
	local nearNeutral = math.abs(newTemp) < 3
	local isStable = math.abs(diff) < 0.05
	isTemperatureBalanced = counterForceActive and nearNeutral and isStable

	-- Use threshold to prevent rapid oscillation between warming/cooling
	-- Lower threshold (0.01) to detect slow temperature changes with reduced rates
	if diff > 0.01 then
		temperatureTrend = 1 -- warming
	elseif diff < -0.01 then
		temperatureTrend = -1 -- cooling
	else
		temperatureTrend = 0 -- stable
	end
	lastTemperature = newTemp
end

-- Tracking states
local isRecovering = false
local lastWeatherType = nil
local lastWeatherIntensity = 0

local function CheckDungeonStatus()
	if CC and CC.IsInDungeonOrRaid then
		return CC.IsInDungeonOrRaid()
	end
	local inInstance, instanceType = IsInInstance()
	return inInstance and (instanceType == "party" or instanceType == "raid")
end

local function ShouldUpdateTemperature()
	if not CC.GetSetting("temperatureEnabled") then
		return false
	end
	if not CC.IsPlayerEligible() then
		return false
	end
	if isInDungeon then
		return false
	end
	if UnitOnTaxi("player") then
		return false
	end
	return true
end

-- Get zone temperature effect (rate of change towards equilibrium)
-- Returns: effect per second, environmental temp, base temp, time factor, equilibrium
local function GetZoneTemperatureEffect()
	local zone = GetZoneText()
	local envTemp, baseTemp, timeFactor, fluctuation = GetEnvironmentalTemperature(zone)

	-- Calculate equilibrium temperature for this zone
	-- Zones at comfortable temp (20°C) = equilibrium 0 (neutral)
	-- Every 10 degrees away from comfortable = ~30 point shift in player temp
	-- So Winterspring (-10°C) = (-10-20)*3 = -90 equilibrium
	-- Tanaris (40°C) = (40-20)*3 = +60 equilibrium
	-- Loch Modan (17°C) = (17-20)*3 = -9 equilibrium
	local equilibrium = (envTemp - COMFORTABLE_TEMP) * 3
	equilibrium = math.max(-90, math.min(90, equilibrium)) -- Cap at ±90

	-- Calculate effect based on distance from equilibrium (not from comfortable)
	-- This makes temperature approach equilibrium and stabilize there
	local distFromEquilibrium = equilibrium - temperature
	local baseEffect = distFromEquilibrium * 0.004 -- Move towards equilibrium

	-- Asymmetric rate: moving AWAY from 0 is slower, returning TO 0 is faster
	local effect = baseEffect
	if temperature >= 0 and baseEffect > 0 then
	-- At or above 0, getting hotter - slow down accumulation
		effect = baseEffect * 0.6 -- Slower when building up heat from neutral
	elseif temperature <= 0 and baseEffect < 0 then
	-- At or below 0, getting colder - slow down accumulation
		effect = baseEffect * 0.6 -- Slower when building up cold from neutral
	elseif temperature > 0 and baseEffect < 0 then
	-- Above 0 and cooling down (recovering to 0) - 4x faster (doubled recovery)
		effect = baseEffect * 4
	elseif temperature < 0 and baseEffect > 0 then
	-- Below 0 and warming up (recovering to 0) - 4x faster (doubled recovery)
		effect = baseEffect * 4
	end

	return effect, envTemp, baseTemp, timeFactor, fluctuation, equilibrium
end

-- Legacy function for compatibility
local function GetZoneTemperatureLevel()
	local effect = GetZoneTemperatureEffect()
	return effect
end

-- Current weather state (updated via WEATHER_UPDATE event)
local currentWeatherType = 0
local currentWeatherIntensity = 0

-- Get current weather effect based on tracked weather state
local function GetWeatherEffect()
	if currentWeatherType == 0 then
		return 0
	end

	local effect = WEATHER_EFFECTS[currentWeatherType] or 0
	return effect * currentWeatherIntensity
end

-- Handle weather update event
local function OnWeatherUpdate(weatherType, intensity)
	currentWeatherType = weatherType or 0
	currentWeatherIntensity = intensity or 0

	-- Map weather types to names for debugging
	local weatherNames = {
		[0] = "Clear",
		[1] = "Light Rain",
		[2] = "Medium Rain",
		[3] = "Heavy Rain",
		[6] = "Light Snow",
		[7] = "Medium Snow",
		[8] = "Heavy Snow",
		[86] = "Sandstorm",
		[90] = "Black Rain"
	}

	local weatherName = weatherNames[weatherType] or ("Unknown(" .. tostring(weatherType) .. ")")
	CC.Debug(string.format("Weather changed: %s (type %d, intensity %.2f)", weatherName, weatherType or 0,
		intensity or 0), "temperature")
end

-- Helper for mount check
local function CanPlayerMount()
	if IsIndoors() then
		return false
	end
	if IsSwimming() then
		return false
	end
	return true
end

-- Check if player is indoors (can't mount)
local function IsPlayerIndoors()
	return IsIndoors() or not CanPlayerMount()
end

-- Check if player is swimming
local function IsPlayerSwimming()
	return IsSwimming()
end

-- Check if player has Well Fed buff
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

local function HasWellFedBuff()
	if AuraByName("Well Fed") then
		return true
	end
	return AnyHelpfulAuraMatches(function(aura)
		local name = aura.name
		if not name then
			return false
		end
		return name:match("Food") ~= nil or name:match("Stamina") ~= nil
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

-- Mana potion cooling tracking (triggered by UNIT_SPELLCAST_SUCCEEDED)
local manaPotionCoolingActive = false
local manaPotionCoolingRemaining = 0
local manaPotionCoolingRate = 0
local MANA_POTION_DURATION = 30 -- Cooling effect lasts 30 seconds
local MANA_POTION_HEAT_REDUCTION = 0.20 -- Reduces 20% of current heat

-- Wet effect tracking (triggered when leaving water)
local wetEffectActive = false
local wetEffectRemaining = 0
local wasSwimmingLastFrame = false

-- Called when a mana potion is detected via UNIT_SPELLCAST_SUCCEEDED
local function StartManaPotionCooling()
	if temperature <= 0 then
		CC.Debug("Mana potion used but not hot - no cooling needed", "temperature")
		return
	end

	-- Calculate cooling: 20% of current heat over 30 seconds
	local heatToRemove = temperature * MANA_POTION_HEAT_REDUCTION
	manaPotionCoolingRate = -heatToRemove / MANA_POTION_DURATION
	manaPotionCoolingRemaining = MANA_POTION_DURATION
	manaPotionCoolingActive = true
	CC.Debug(string.format("Mana potion cooling started: %.1f over %ds (rate: %.3f/s)", heatToRemove,
		MANA_POTION_DURATION, manaPotionCoolingRate), "temperature")
end

-- Main temperature update function
local function UpdateTemperature(elapsed)
	if not ShouldUpdateTemperature() then
		currentGlowType = 0
		return
	end

	local tempChange = 0
	local isIndoors = IsPlayerIndoors()
	local isSwimming = IsPlayerSwimming()
	local hasWellFed = HasWellFedBuff()
	local isNearFire = CC.isNearFire
	local isResting = IsResting()

	-- 1. Zone temperature with day/night fluctuation (approaches equilibrium)
	local zoneEffect, envTemp, baseTemp, timeFactor, fluctuation, equilibrium = GetZoneTemperatureEffect()
	tempChange = tempChange + zoneEffect

	-- 2. Weather effects (reduced indoors)
	local weatherEffect = GetWeatherEffect()
	if weatherEffect ~= 0 then
		if isIndoors then
			weatherEffect = weatherEffect * INDOOR_MODIFIER
		end
		tempChange = tempChange + weatherEffect
	end

	-- 2b. Manual weather effects (if enabled and active)
	local manualWeatherEffect = GetManualWeatherEffect()
	if manualWeatherEffect ~= 0 then
		if isIndoors then
			manualWeatherEffect = manualWeatherEffect * INDOOR_MODIFIER
		end
		tempChange = tempChange + manualWeatherEffect
	end

	-- 3. Swimming effects
	if isSwimming then
		if temperature > 0 then
		-- Swimming reduces heat
			tempChange = tempChange + SWIMMING_HEAT_REDUCTION
		elseif temperature < 0 and zoneEffect < 0 then
		-- Swimming in cold weather makes you colder
			tempChange = tempChange + SWIMMING_COLD_INCREASE
		else
		-- Normal swimming is slightly cooling
			tempChange = tempChange + (SWIMMING_HEAT_REDUCTION * 0.5)
		end
		-- Start/refresh wet effect timer while swimming
		wetEffectActive = true
		wetEffectRemaining = WET_DURATION
	end
	wasSwimmingLastFrame = isSwimming

	-- Rain also triggers wet effect (from manual weather toggle)
	local isRaining = manualWeatherActive and currentZoneWeatherType == WEATHER_TYPE_RAIN
	if isRaining and not isIndoors then
	-- Refresh wet effect while in rain
		wetEffectActive = true
		wetEffectRemaining = WET_DURATION
	end

	-- 3b. Wet effect (after leaving water)
	-- When cold: multiplies cooling based on how cold you are - significant impact in cold areas
	-- When hot: provides passive cooling to help keep you comfortable
	if wetEffectActive and not isSwimming then
	-- Dry 3x faster when near fire or resting (warming by fire or drying off at inn/city)
		local dryingMultiplier = (isNearFire or isResting) and 3.0 or 1.0
		wetEffectRemaining = wetEffectRemaining - (elapsed * dryingMultiplier)
		if wetEffectRemaining <= 0 then
			wetEffectActive = false
			wetEffectRemaining = 0
			CC.Debug("Wet effect finished - you've dried off", "temperature")
		elseif temperature < 0 and tempChange < 0 then
		-- COLD: Calculate wet multiplier based on how cold the temperature is
		-- At temp -10: minor boost, at temp -50+: significant boost
			local coldIntensity = math.min(1, math.abs(temperature) / 50) -- 0 to 1 based on cold
			local wetMultiplier = 1 + (coldIntensity * (WET_COLD_MULTIPLIER_MAX - 1))
			-- Only multiply the cooling portion, not the entire tempChange
			local coolingBoost = (tempChange * wetMultiplier) - tempChange
			tempChange = tempChange + coolingBoost
			CC.Debug(string.format("Wet effect (cold): %.1fx cooling boost (%.1fs remaining)", wetMultiplier, wetEffectRemaining), "temperature")
		elseif temperature > 0 then
		-- HOT: Being wet helps you stay cool via evaporative cooling
			tempChange = tempChange + WET_HEAT_REDUCTION
			CC.Debug(string.format("Wet effect (hot): cooling at %.2f/s (%.1fs remaining)", WET_HEAT_REDUCTION, wetEffectRemaining), "temperature")
		end
	end

	-- 4. Drinking provides continuous cooling while buff is active (only when hot)
	local isDrinking = IsPlayerDrinking()
	if isDrinking and temperature > 0 then
	-- Continuous cooling while drinking buff is active
		tempChange = tempChange + DRINKING_COOLING_RATE
		CC.Debug("Drinking cooling active", "temperature")
	end

	-- 4b. Mana potion cooling (triggered by UNIT_SPELLCAST_SUCCEEDED, not buff detection)
	-- Apply mana potion cooling if active
	if manaPotionCoolingActive and temperature > 0 then
		tempChange = tempChange + manaPotionCoolingRate
		manaPotionCoolingRemaining = manaPotionCoolingRemaining - elapsed
		if manaPotionCoolingRemaining <= 0 then
			manaPotionCoolingActive = false
			manaPotionCoolingRate = 0
			CC.Debug("Mana potion cooling finished", "temperature")
		end
	elseif manaPotionCoolingActive and temperature <= 0 then
	-- Stop cooling if we've reached 0 or below
		manaPotionCoolingActive = false
		manaPotionCoolingRate = 0
	end

	-- 5. Rain reduces temperature if on warm side
	if lastWeatherType and
	(lastWeatherType == "Rain" or lastWeatherType == "Blood Rain" or lastWeatherType == 1 or lastWeatherType == 2 or
	lastWeatherType == 3) then
		if temperature > 0 and not isIndoors then
		-- Extra cooling from rain when warm
			tempChange = tempChange - 0.5
		end
	end

	-- 6. Well Fed reduces cold accumulation
	if tempChange < 0 and hasWellFed then
		tempChange = tempChange * WELL_FED_COLD_MODIFIER
	end

	-- 7. Fire recovery (brings cold back to neutral)
	-- Fire provides gentle warming when cold, scaled to prevent overshoot
	-- When indoors (can't mount), fire allows FULL recovery to 0
	-- When outdoors, fire recovery is limited by zone equilibrium
	if temperature < 0 and isNearFire then
		local baseRecovery = isIndoors and FIRE_INDOOR_RECOVERY or FIRE_OUTDOOR_RECOVERY

		-- Apply recovery rate multiplier (double speed for recovery)
		baseRecovery = baseRecovery * RECOVERY_RATE_MULTIPLIER

		-- Scale recovery based on how far from 0 we are - less recovery when close to 0
		local distanceFrom0 = math.abs(temperature)
		local scaledRecovery = baseRecovery * math.min(1.0, distanceFrom0 / 10)

		-- If current tempChange would still make us colder, fire needs to overcome it
		-- But cap the overshoot prevention to avoid oscillation
		if tempChange < 0 then
		-- Just overcome the cooling, don't add extra
			local netWarming = math.max(scaledRecovery, math.abs(tempChange) * 1.1)
			tempChange = tempChange + netWarming
		else
			tempChange = tempChange + scaledRecovery
		end

		-- When indoors (no mount available), fire allows full recovery to 0
		-- Override the zone equilibrium limit
		if isIndoors and equilibrium < 0 then
		-- Force temperature toward 0 instead of equilibrium
		-- This effectively ignores the cold zone penalty when warming by fire indoors
			local recoveryToward0 = baseRecovery * 2 -- Strong push toward 0
			if temperature < -1 then
				tempChange = tempChange + recoveryToward0
			end
		end
	end

	-- 8. Inn recovery (return to neutral, scaled to prevent overshoot)
	if isResting then
		local distanceFrom0 = math.abs(temperature)
		-- Apply recovery rate multiplier for faster return to 0
		local scaledInnRecovery = INN_RECOVERY * RECOVERY_RATE_MULTIPLIER * math.min(1.0, distanceFrom0 / 10)
		if temperature > 0 then
			tempChange = tempChange - scaledInnRecovery
		elseif temperature < 0 then
			tempChange = tempChange + scaledInnRecovery
		end
	end

	-- 9. Natural decay is now handled by equilibrium system in GetZoneTemperatureEffect()
	-- Temperature naturally approaches zone equilibrium

	-- Apply indoor modifier to accumulation (not recovery)
	if isIndoors and not isResting and not isNearFire then
	-- Reduce rate of getting hotter/colder indoors
		if (tempChange > 0 and temperature >= 0) or (tempChange < 0 and temperature <= 0) then
			tempChange = tempChange * INDOOR_MODIFIER
		end
	end

	-- 10. Apply directional rate modifier based on time of day
	-- During day: warming faster, cooling slower
	-- During night: cooling faster, warming slower
	if tempChange ~= 0 and not isResting and not isNearFire then
		local rateModifier = GetDirectionalRateModifier(tempChange)
		tempChange = tempChange * rateModifier
	end

	-- Apply the change
	local oldTemp = temperature
	temperature = temperature + (tempChange * elapsed)
	temperature = math.max(MIN_TEMPERATURE, math.min(MAX_TEMPERATURE, temperature))

	-- Detect if counter-forces are actively fighting zone temperature
	-- Counter-force = warming when zone wants cold, OR cooling when zone wants hot
	local counterForceActive = false
	local isDrinking = IsPlayerDrinking()
	if equilibrium < -5 then
	-- Cold zone - counter-force if warming (fire, inn, well fed)
		counterForceActive = isNearFire or isResting
	elseif equilibrium > 5 then
	-- Hot zone - counter-force if cooling (swimming, drinking, rain, wet)
		counterForceActive = isSwimming or isDrinking or (isResting and temperature > 0) or wetEffectActive
	end

	-- Only snap to equilibrium if NOT actively fighting with counter-forces
	-- This prevents getting stuck at equilibrium when drinking/swimming in hot zones
	if not counterForceActive and math.abs(temperature - equilibrium) < 1.0 then
		temperature = equilibrium
	end

	-- When near fire/inn AND near 0, snap to 0 to prevent oscillation
	-- Only in cold zones where fire/inn is bringing temp back to 0
	local snappedTo0 = false
	if (isNearFire or isResting) and equilibrium < -5 and math.abs(temperature) < 0.5 then
		temperature = 0
		snappedTo0 = true
	end

	-- Also snap to 0 when indoors with fire in cold zone (full recovery enabled)
	if isIndoors and isNearFire and temperature < 0 and temperature > -0.5 then
		temperature = 0
		snappedTo0 = true
	end

	-- Snap to 0 when wet effect is cooling in a hot zone and temp reaches 0
	-- This prevents ping-pong oscillation where wet cooling pushes below 0,
	-- then equilibrium pushes back above 0, creating a back-and-forth effect
	if wetEffectActive and equilibrium > 5 and math.abs(temperature) < 0.5 then
		temperature = 0
		snappedTo0 = true
	end

	-- Equilibrium message system
	-- Update cooldown
	if equilibriumMessageCooldown > 0 then
		equilibriumMessageCooldown = equilibriumMessageCooldown - elapsed
	end

	-- Check for equilibrium states and display messages
	if equilibriumMessageCooldown <= 0 then
		local messageToShow = nil

		-- Reached comfortable temperature (0)
		if snappedTo0 or (math.abs(temperature) < 0.5 and math.abs(oldTemp) >= 1) then
			if lastEquilibriumMessage ~= "comfortable" then
				messageToShow = "comfortable"
				print("|cff88CCFFCozyCamps:|r |cff00FF00You are at a comfortable temperature.|r")
			end
		-- Hit warming cap (cold zone, can't get warmer outdoors)
		elseif equilibrium < -5 and not isIndoors and temperature < 0 then
		-- Check if we're trying to warm but stuck at equilibrium
			local atWarmingCap = counterForceActive and math.abs(temperature - equilibrium) < 2 and oldTemp <=
			temperature
			if atWarmingCap and temperature < -3 and lastEquilibriumMessage ~= "cant_warm" then
				messageToShow = "cant_warm"
				print("|cff88CCFFCozyCamps:|r |cffFFAAAAYou can't seem to get any warmer.|r")
			end
		-- Hit cooling cap (hot zone, can't get cooler)
		elseif equilibrium > 5 and temperature > 0 then
		-- Check if we're trying to cool but stuck at equilibrium
			local atCoolingCap = counterForceActive and math.abs(temperature - equilibrium) < 2 and oldTemp >=
			temperature
			if atCoolingCap and temperature > 3 and lastEquilibriumMessage ~= "cant_cool" then
				messageToShow = "cant_cool"
				print("|cff88CCFFCozyCamps:|r |cffFFAAAAYou can't seem to get any cooler.|r")
			end
		end

		if messageToShow then
			lastEquilibriumMessage = messageToShow
			equilibriumMessageCooldown = EQUILIBRIUM_MESSAGE_COOLDOWN
		end
	end

	-- Reset message tracking if we move away from equilibrium significantly
	if math.abs(temperature) > 5 and lastEquilibriumMessage == "comfortable" then
		lastEquilibriumMessage = nil
	elseif math.abs(temperature - equilibrium) > 5 then
		if lastEquilibriumMessage == "cant_warm" or lastEquilibriumMessage == "cant_cool" then
			lastEquilibriumMessage = nil
		end
	end

	UpdateTemperatureTrend(temperature, tempChange, counterForceActive)

	-- Update glow state
	isRecovering = (isResting or isNearFire) and temperature ~= 0

	if isRecovering then
		currentGlowType = 3 -- Recovery glow (green)
		currentGlowIntensity = 1.0
	elseif temperature < -10 then
		currentGlowType = 1 -- Cold glow (blue)
		currentGlowIntensity = math.min(1.0, math.abs(temperature) / 50)
	elseif temperature > 10 then
		currentGlowType = 2 -- Hot glow (red)
		currentGlowIntensity = math.min(1.0, math.abs(temperature) / 50)
	else
		currentGlowType = 0
		currentGlowIntensity = 0
	end

	-- Enhanced debug output with environmental temperature info
	-- Check debug setting BEFORE string.format to avoid string allocation when disabled
	if CC.GetSetting("temperatureDebugEnabled") then
		local hour, minute = GetGameTime()
		CC.Debug(string.format("Temp: %.1f | Eq: %.0f | Env: %.1f°C (base: %d) | Change: %.3f/s | Time: %02d:%02d",
			temperature, equilibrium or 0, envTemp, baseTemp, tempChange, hour, minute), "temperature")
	end
end

-- Update glow intensity decay
local function UpdateGlow(elapsed)
	if currentGlowType == 0 and currentGlowIntensity > 0 then
		currentGlowIntensity = currentGlowIntensity - (GLOW_DECAY_RATE * elapsed)
		if currentGlowIntensity <= 0 then
			currentGlowIntensity = 0
		end
	end
end

-- Main update handler
function CC.HandleTemperatureUpdate(elapsed)
	updateTimer = updateTimer + elapsed
	if updateTimer >= UPDATE_INTERVAL then
		UpdateTemperature(updateTimer)
		updateTimer = 0
	end
	UpdateGlow(elapsed)
	UpdateTemperatureOverlayAlphas(elapsed)
	UpdateWetOverlayAlpha(elapsed, wetEffectActive)
	local isDrying = CC.isNearFire or IsResting()
	UpdateDryingOverlayAlpha(elapsed, wetEffectActive, isDrying)
end

-- Public API
function CC.GetTemperature()
	return temperature
end

function CC.IsWetEffectActive()
	return wetEffectActive
end

function CC.GetWetEffectRemaining()
	return wetEffectRemaining
end

-- Debug function to set wet/dry state
function CC.SetWetEffect(active)
	if active then
		wetEffectActive = true
		wetEffectRemaining = WET_DURATION
		CC.Debug("Debug: Wet effect enabled", "temperature")
	else
		wetEffectActive = false
		wetEffectRemaining = 0
		CC.Debug("Debug: Wet effect disabled (dried off)", "temperature")
	end
end

-- Debug weather type override functions
function CC.SetDebugWeatherType(weatherType)
	debugWeatherTypeOverride = weatherType
	if weatherType then
		CC.Debug(string.format("Debug: Weather type override set to %d", weatherType), "temperature")
	else
		CC.Debug("Debug: Weather type override cleared", "temperature")
	end
	-- Fire callback to update UI immediately
	CC.FireCallbacks("ZONE_WEATHER_CHANGED", CC.GetZoneWeatherType(), manualWeatherActive)
end

function CC.GetDebugWeatherType()
	return debugWeatherTypeOverride
end

-- Returns value from -1 to 1 (for meter display)
function CC.GetTemperaturePercent()
	return temperature / MAX_TEMPERATURE
end

-- Returns absolute percentage (0-100) for display
function CC.GetTemperatureAbsolutePercent()
	return math.abs(temperature)
end

function CC.SetTemperature(value)
	value = tonumber(value)
	if not value then
		return false
	end
	temperature = math.max(MIN_TEMPERATURE, math.min(MAX_TEMPERATURE, value))
	CC.Debug(string.format("Temperature set to %.1f", temperature), "temperature")
	return true
end

function CC.ResetTemperature()
	temperature = 0
	CC.Debug("Temperature reset to neutral", "temperature")
end

function CC.IsTemperatureCold()
	return temperature < 0
end

function CC.IsTemperatureHot()
	return temperature > 0
end

function CC.GetTemperatureGlow()
	return currentGlowType, currentGlowIntensity
end

function CC.IsTemperatureRecovering()
	return isRecovering
end

function CC.IsTemperaturePaused()
	if not CC.GetSetting("temperatureEnabled") then
		return false
	end
	if not CC.IsPlayerEligible() then
		return false
	end
	return isInDungeon or UnitOnTaxi("player") or UnitIsDead("player") or UnitIsGhost("player")
end

-- Get the current zone's equilibrium temperature
function CC.GetTemperatureEquilibrium()
	local zone = GetZoneText()
	local envTemp = GetEnvironmentalTemperature(zone)
	local equilibrium = (envTemp - COMFORTABLE_TEMP) * 3
	equilibrium = math.max(-90, math.min(90, equilibrium))
	return equilibrium
end

-- Get environmental temperature for tooltip (public version)
function CC.GetEnvironmentalTemperature()
	local zone = GetZoneText()
	local envTemp, baseTemp = GetEnvironmentalTemperature(zone)
	return envTemp, baseTemp
end

-- Check if temperature is at equilibrium (not moving)
function CC.IsTemperatureAtEquilibrium()
	local equilibrium = CC.GetTemperatureEquilibrium()
	return math.abs(temperature - equilibrium) < 1
end

-- Get current weather info for debugging/display
function CC.GetCurrentWeather()
	return currentWeatherType, currentWeatherIntensity
end

-- Get current environmental temperature info (for UI display)
-- Returns: envTemp (current with day/night), baseTemp, timeFactor (-1 to 1), fluctuationMagnitude
function CC.GetEnvironmentalTemperature()
	local zone = GetZoneText()
	return GetEnvironmentalTemperature(zone)
end

-- Get the current time factor for day/night cycle (-1 to +1)
-- +1 = peak warm (2pm), -1 = peak cold (2am), 0 = neutral (8am/8pm)
function CC.GetTimeFactor()
	return GetTimeFactor()
end

-- Check if it's currently daytime (warming period)
function CC.IsDaytime()
	return GetTimeFactor() > 0
end

-- Reusable table for temperature effects (avoids allocation in tooltip)
local cachedEffects = {}

-- Get list of currently active temperature effects (for tooltip display)
function CC.GetTemperatureEffects()
-- Clear and reuse table to avoid memory allocation
	for i = #cachedEffects, 1, -1 do
		cachedEffects[i] = nil
	end
	local effects = cachedEffects

	-- Check zone effect - simple descriptive text without confusing numbers
	local zone = GetZoneText()
	local envTemp, baseTemp = GetEnvironmentalTemperature(zone)
	if envTemp > COMFORTABLE_TEMP + 20 then
		table.insert(effects, "Very Hot Zone")
	elseif envTemp > COMFORTABLE_TEMP + 5 then
		table.insert(effects, "Hot Zone")
	elseif envTemp < COMFORTABLE_TEMP - 20 then
		table.insert(effects, "Very Cold Zone")
	elseif envTemp < COMFORTABLE_TEMP - 5 then
		table.insert(effects, "Cold Zone")
	else
		table.insert(effects, "Comfortable Zone")
	end

	-- Time of day effect
	local timeFactor = GetTimeFactor()
	if timeFactor > 0.3 then
		table.insert(effects, "Daytime (warming)")
	elseif timeFactor < -0.3 then
		table.insert(effects, "Nighttime (cooling)")
	end

	-- Indoor modifier (swimming is not indoors even though you cannot mount)
	if IsPlayerIndoors() and not IsPlayerSwimming() then
		table.insert(effects, "Indoors (reduced zone effects)")
	end

	-- Swimming
	if IsPlayerSwimming() then
		if temperature > 0 then
			table.insert(effects, "Swimming (cooling)")
		elseif temperature < 0 then
			table.insert(effects, "Swimming (colder)")
		else
			table.insert(effects, "Swimming")
		end
	end

	-- Wet effect (after leaving water)
	if wetEffectActive and not IsPlayerSwimming() then
		local minutes = math.floor(wetEffectRemaining / 60)
		local seconds = math.floor(wetEffectRemaining % 60)
		local timeStr = minutes > 0 and string.format("%d:%02d", minutes, seconds) or string.format("%ds", seconds)
		local dryingNote = (CC.isNearFire or IsResting()) and " [drying 3x]" or ""
		if temperature < 0 then
		-- Cold: Show multiplier intensity based on how cold it is
			local coldIntensity = math.min(1, math.abs(temperature) / 50)
			local wetMultiplier = 1 + (coldIntensity * (WET_COLD_MULTIPLIER_MAX - 1))
			table.insert(effects, string.format("Wet: %.1fx colder (%s)%s", wetMultiplier, timeStr, dryingNote))
		elseif temperature > 0 then
		-- Hot: Show that wetness is helping you cool down
			table.insert(effects, string.format("Wet: evaporative cooling (%s)%s", timeStr, dryingNote))
		else
		-- Neutral: Show that wetness will affect temperature
			table.insert(effects, string.format("Wet: affects temp when hot/cold (%s)%s", timeStr, dryingNote))
		end
	end

	-- Well Fed buff
	if HasWellFedBuff() then
		table.insert(effects, "Well Fed (cold resist)")
	end

	-- Drinking
	if IsPlayerDrinking() and temperature > 0 then
		table.insert(effects, "Drinking (cooling)")
	end

	-- Mana potion cooling (from actual mana potion usage)
	if manaPotionCoolingActive then
		table.insert(effects, string.format("Mana Potion (%ds)", math.ceil(manaPotionCoolingRemaining)))
	end

	-- Fire effects
	if CC.isNearFire then
		if temperature < 0 then
			table.insert(effects, "Campfire (warming)")
		elseif temperature > 0 then
			table.insert(effects, "Campfire (no effect - already warm)")
		else
			table.insert(effects, "Campfire (comfortable)")
		end
	end

	-- Inn/resting recovery
	if IsResting() then
		if temperature > 0 then
			table.insert(effects, "Resting (cooling)")
		elseif temperature < 0 then
			table.insert(effects, "Resting (warming)")
		else
			table.insert(effects, "Resting (neutral)")
		end
	end

	-- Manual weather
	if CC.GetSetting("manualWeatherEnabled") and manualWeatherActive then
		local weatherNames = {
			[1] = "Rain",
			[2] = "Snow",
			[3] = "Dust Storm"
		}
		local weatherName = weatherNames[currentZoneWeatherType] or "Weather"
		if CC.IsWeatherPaused() then
			table.insert(effects, weatherName .. " (paused - indoors)")
		else
			table.insert(effects, weatherName .. " (manual)")
		end
	end

	return effects
end

-- Zone change handling
local function OnZoneChanged()
	local wasInDungeon = isInDungeon
	isInDungeon = CheckDungeonStatus()

	if isInDungeon and not wasInDungeon then
		savedTemperature = temperature
		CC.Debug(string.format("Entering dungeon - temperature paused at %.1f", savedTemperature), "temperature")
	elseif not isInDungeon and wasInDungeon then
		temperature = savedTemperature
		CC.Debug(string.format("Leaving dungeon - temperature restored to %.1f", temperature), "temperature")
	end
end

-- Settings callback
CC.RegisterCallback("SETTINGS_CHANGED", function(key)
	if key == "temperatureEnabled" or key == "ALL" then
		if not CC.GetSetting("temperatureEnabled") then
			currentGlowType = 0
			currentGlowIntensity = 0
		end
	end
end)

-- Event frame
local eventFrame = CreateFrame("Frame", "CozyCampsTemperatureFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
-- Note: WEATHER_UPDATE doesn't exist in Classic WoW, weather detection uses manual toggle instead

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, ...)
	if event == "PLAYER_LOGIN" then
		if CC.charDB and CC.charDB.savedTemperature then
			temperature = CC.charDB.savedTemperature
			CC.Debug(string.format("Temperature restored: %.1f", temperature), "temperature")
		else
			temperature = 0
		end
		savedTemperature = 0
		isInDungeon = CheckDungeonStatus()
		CreateAllTemperatureOverlayFrames()
		-- Initialize zone weather type
		C_Timer.After(0.5, function()
			UpdateZoneWeatherType()
		end)

	elseif event == "PLAYER_LOGOUT" then
		if CC.charDB then
			CC.charDB.savedTemperature = temperature
		end

	elseif event == "PLAYER_DEAD" then
	-- Temperature resets on death
		CC.ResetTemperature()

	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
		OnZoneChanged()
		UpdateZoneWeatherType()

	elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
	-- Detect mana potion usage for cooling effect
	-- TBC Anniversary: arg2 = castGUID (like "Cast-4-5528-530-1-28499-00003BBBB7"), spellID in varargs
	-- Classic Era: arg2 = spellName, arg3 = rank, arg4 = lineID, arg5 = spellID
		local spellName, spellID
		local extraArg = ...

		local function GetSpellNameFromID(id)
			if not id then
				return nil
			end
			if C_Spell and C_Spell.GetSpellInfo then
				local spellInfo = C_Spell.GetSpellInfo(id)
				return spellInfo and spellInfo.name
			end
			if GetSpellInfo then
				return GetSpellInfo(id)
			end
			return nil
		end

		if type(arg2) == "string" and arg2:match("^Cast%-") then
		-- TBC Anniversary format: arg2 is castGUID, extract spellID from it or varargs
		-- castGUID format: Cast-X-XXXX-XXX-X-SPELLID-XXXXXXXX
			local extractedID = arg2:match("Cast%-%d+%-%d+%-%d+%-%d+%-(%d+)")
			spellID = extraArg or (extractedID and tonumber(extractedID))
			spellName = GetSpellNameFromID(spellID)
		elseif type(arg2) == "string" then
		-- Classic Era format: arg2 is spell name directly
			spellName = arg2
			local _, _, _, classicSpellID = ...
			spellID = classicSpellID
		else
		-- Fallback
			spellID = extraArg
			spellName = GetSpellNameFromID(spellID)
		end

		-- Debug all spell casts when temperature debug is enabled
		if CC.GetSetting and CC.GetSetting("temperatureDebugEnabled") then
			CC.Debug(string.format("Spell cast: %s (ID: %s)", tostring(spellName), tostring(spellID)), "temperature")
		end

		if spellName then
		-- Check for mana potions by name patterns
		-- Classic: Minor/Lesser/Greater/Superior/Major Mana Potion

			local isManaPotion = spellName:match("Mana Potion") or spellName:match("Restore Mana") or
			spellName:match("Mana Restored")

			-- Also check mage mana gems
			local isManaGem = spellName:match("Mana Emerald") or spellName:match("Mana Ruby") or
			spellName:match("Mana Citrine") or spellName:match("Mana Jade") or
			spellName:match("Mana Agate")

			-- Check by common mana potion spell IDs (Classic)
			local MANA_POTION_SPELL_IDS = {
				[2023] = true, -- Minor Mana Potion
				[2024] = true, -- Lesser Mana Potion
				[4381] = true, -- Mana Potion
				[11903] = true, -- Greater Mana Potion
				[17530] = true, -- Superior Mana Potion
				[17531] = true -- Major Mana Potion
			}

			if isManaPotion or isManaGem or (spellID and MANA_POTION_SPELL_IDS[spellID]) then
				StartManaPotionCooling()
				-- Also trigger thirst quenching if thirst system is available
				if CC.StartManaPotionQuenching then
					CC.StartManaPotionQuenching()
				end
				CC.Debug(string.format("Mana potion detected: %s (ID: %s)", spellName, tostring(spellID)), "temperature")
			end
		end
	end
end)
