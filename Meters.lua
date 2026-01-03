-- CozierCamps - Meters.lua
-- Visual meters for Anguish, Exhaustion, and Temperature systems
local CC = CozierCamps

-- Forward declarations for functions used before they're defined
local CalculateConstitution

-- Performance optimization: Cache frequently accessed values
local cachedSettings = {
	meterDisplayMode = nil,
	AnguishEnabled = nil,
	exhaustionEnabled = nil,
	hungerEnabled = nil,
	thirstEnabled = nil,
	temperatureEnabled = nil
}

-- Cache math functions locally for performance
local math_abs = math.abs
local math_min = math.min

-- Smooth alpha interpolation (used for status icon fading)
local function LerpAlpha(current, target, speed, elapsed)
	local diff = target - current
	if math_abs(diff) < 0.01 then
		return target
	end
	return current + diff * math_min(1, speed * elapsed)
end

-- Meter configuration
local METER_WIDTH = 150
local METER_HEIGHT = 16
local METER_SPACING = 4
local METER_PADDING = 2
local GLOW_SIZE = 2 -- Glow extends this many pixels beyond bar (reduced to avoid overlap)
local GLOW_PULSE_SPEED = 3 -- Speed of glow pulsing animation

-- Temperature meter specific
local TEMP_METER_WIDTH = 150
local TEMP_ARROW_SIZE = 20

-- Weather button specific
local WEATHER_BUTTON_SIZE = 24
local weatherButton = nil

-- Status icons row (Classic parity)
local statusIconsRow = nil
local STATUS_ICON_SIZE = 18
local STATUS_ROW_HEIGHT = 30 -- Height of the status icons area

-- Hunger glow tracking (pulse on 0.1 intervals)
local lastHungerTenth = 0
local hungerGlowPulseTimer = 0
local HUNGER_PULSE_DURATION = 0.5 -- How long the pulse lasts

-- Thirst glow tracking (pulse on 0.1 intervals)
local lastThirstTenth = 0
local thirstGlowPulseTimer = 0
local THIRST_PULSE_DURATION = 0.5 -- How long the pulse lasts

-- Available bar textures
local BAR_TEXTURES = { "Interface\\TargetingFrame\\UI-StatusBar", -- Blizzard default
					   "Interface\\RaidFrame\\Raid-Bar-Hp-Fill", -- Blizzard Raid
					   "Interface\\AddOns\\CozierCamps\\assets\\UI-StatusBar", -- Smooth (custom if exists, fallback to Blizzard)
					   "Interface\\Buttons\\WHITE8x8", -- Flat/Solid
					   "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar", -- Gloss
					   "Interface\\TARGETINGFRAME\\UI-TargetingFrame-BarFill", -- Minimalist
					   "Interface\\Tooltips\\UI-Tooltip-Background", -- Otravi-like
					   "Interface\\RaidFrame\\Raid-Bar-Resource-Fill", -- Striped
					   "Interface\\Buttons\\WHITE8x8" -- Solid
}

-- Available bar fonts (index 1 = inherit/default, no override)
local BAR_FONTS = { {
						name = "Default",
						path = nil
					}, -- Inherit from UI/other addons
					{
						name = "Friz Quadrata",
						path = "Fonts\\FRIZQT__.TTF"
					}, -- Default WoW font
					{
						name = "Arial Narrow",
						path = "Fonts\\ARIALN.TTF"
					}, -- Clean narrow
					{
						name = "Skurri",
						path = "Fonts\\skurri.TTF"
					}, -- Stylized
					{
						name = "Morpheus",
						path = "Fonts\\MORPHEUS.TTF"
					}, -- Fantasy
					{
						name = "2002",
						path = "Fonts\\2002.TTF"
					}, -- Bold
					{
						name = "2002 Bold",
						path = "Fonts\\2002B.TTF"
					}, -- Extra bold
					{
						name = "Express Way",
						path = "Fonts\\EXPRESSWAY.TTF"
					}, -- Modern
					{
						name = "Nimrod MT",
						path = "Fonts\\NIM_____.TTF"
					} -- Serif
}

-- Get the current bar texture path
local function GetBarTexture()
	local textureIndex = CC.GetSetting and CC.GetSetting("meterBarTexture") or 1
	return BAR_TEXTURES[textureIndex] or BAR_TEXTURES[1]
end

-- Get the current font path (nil means use default font object)
local function GetGeneralFont()
	local fontIndex = CC.GetSetting and CC.GetSetting("generalFont") or 1
	local fontData = BAR_FONTS[fontIndex]
	if fontData and fontData.path then
		return fontData.path
	end
	return nil -- Use default
end

-- Alias for backwards compatibility
local GetBarFont = GetGeneralFont

-- Forward declaration for helper function (defined after metersContainer)
local StartMovingMetersContainer

-- Colors (vibrant and saturated)
local Anguish_COLOR = {
	r = 0.9,
	g = 0.1,
	b = 0.1
} -- Saturated red
local Anguish_DECAY_COLOR = {
	r = 0.1,
	g = 0.9,
	b = 0.2
} -- Vibrant green when healing
local EXHAUSTION_COLOR = {
	r = 0.6,
	g = 0.3,
	b = 0.9
} -- Purple to match vial fill
local EXHAUSTION_DECAY_COLOR = {
	r = 0.1,
	g = 0.9,
	b = 0.2
} -- Vibrant green when decaying

-- Temperature colors (gradient from cold to hot)
local TEMP_COLD_LIGHT = {
	r = 0.6,
	g = 0.8,
	b = 1.0
} -- Light blue (near center)
local TEMP_COLD_DARK = {
	r = 0.1,
	g = 0.3,
	b = 0.9
} -- Dark blue (far left)
local TEMP_HOT_LIGHT = {
	r = 1.0,
	g = 1.0,
	b = 0.6
} -- Light yellow (near center)
local TEMP_HOT_DARK = {
	r = 1.0,
	g = 0.4,
	b = 0.1
} -- Dark orange (far right)

-- Hunger colors
local HUNGER_DECAY_COLOR = {
	r = 0.9,
	g = 0.6,
	b = 0.2
} -- Orange/amber for hunger
local HUNGER_COLOR = {
	r = 0.1,
	g = 0.9,
	b = 0.2
} -- Green when eating/recovering

-- Thirst colors
local THIRST_COLOR = {
	r = 0.4,
	g = 0.7,
	b = 1.0
} -- Blue for thirst
local THIRST_DECAY_COLOR = {
	r = 0.1,
	g = 0.9,
	b = 0.2
} -- Green when drinking/recovering

-- Constitution colors (for bar mode)
local CONSTITUTION_BAR_COLOR = {
	r = 0.13,
	g = 0.45,
	b = 0.18
} -- Deep dark green to match the vial

-- Glow colors (super vibrant for visibility)
local GLOW_RED = {
	r = 1.0,
	g = 0.1,
	b = 0.1
} -- Pure vibrant red for damage
local GLOW_GREEN = {
	r = 0.3,
	g = 1.0,
	b = 0.4
} -- Bright vibrant green for healing (doubled brightness)
local GLOW_ORANGE = {
	r = 1.0,
	g = 0.5,
	b = 0.1
} -- Orange for negative effects (accumulating)

-- Pulse sizes based on damage type (1=normal, 2=crit, 3=daze)
local PULSE_SIZES = { 3, 5, 8 } -- Smaller glow sizes to avoid overlap

-- Glow sizes based on movement type (1=mounted, 2=walking, 3=combat)
local GLOW_SIZES = { 3, 4, 6 }
local GLOW_SIZE_IDLE = 2 -- Smaller glow for standing idle
local GLOW_SIZE_PAUSED = -12 -- Negative to shrink inside the bar edges

-- Meter frames
local AnguishMeter = nil
local exhaustionMeter = nil
local hungerMeter = nil
local thirstMeter = nil
local temperatureMeter = nil
local metersContainer = nil
local constitutionMeter = nil -- Orb/vial meter

-- Helper function to start moving metersContainer with normalized anchor
-- This prevents jumps caused by inconsistent anchor states
StartMovingMetersContainer = function()
	if metersContainer and not CC.GetSetting("metersLocked") then
		local left, bottom = metersContainer:GetLeft(), metersContainer:GetBottom()
		if left and bottom then
			metersContainer:ClearAllPoints()
			metersContainer:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
		end
		metersContainer:StartMoving()
	end
end
local constitutionBarMeter = nil -- Bar mode meter (top of stack)

-- Constitution meter configuration
local CONSTITUTION_ORB_SIZE = 62 -- Size of the constitution orb
local CONSTITUTION_WEIGHTS = {
	anguish = 0.30,
	exhaustion = 0.30,
	hunger = 0.15,
	thirst = 0.15,
	temperature = 0.10
}

-- Constitution state tracking - simple flash on change
local lastConstitution = 100
local constitutionGlowState = "none" -- "green" = improving, "orange" = declining, "none" = stable
local constitutionGlowTimer = 0 -- how long current glow has been showing
local CONSTITUTION_GLOW_DURATION = 2.0 -- seconds to show glow after a change

-- Adventure Mode UI hiding state
-- Tracks what we've hidden so we can restore it
local adventureModeUIState = {
	playerFrameHidden = false,
	targetFrameHidden = false,
	nameplatesDisabled = false,
	actionBarsHidden = false,
	mapDisabled = false,
	previousNameplateSettings = {},
	lastConstitutionThreshold = 100, -- Track which threshold we're at
	heartbeatPlaying = false, -- Track if heartbeat sound is playing
	heartbeatHandle = nil, -- Handle for the heartbeat sound loop ticker
	mapHookInstalled = false -- Track if map hook is installed
}

-- Heartbeat sound looping (replays every 2 seconds to simulate loop)
local HEARTBEAT_INTERVAL = 2.0 -- seconds between heartbeat sound plays
local function StartHeartbeatSound()
	if adventureModeUIState.heartbeatPlaying then
		return
	end
	if not CC.GetSetting or not CC.GetSetting("playSoundHeartbeat") then
		return
	end
	-- Only play if constitution meter is enabled
	if not CC.GetSetting("constitutionEnabled") then
		return
	end
	-- Don't play below minimum level
	if not CC.IsPlayerEligible() then
		return
	end

	adventureModeUIState.heartbeatPlaying = true
	-- Play immediately
	PlaySoundFile("Interface\\AddOns\\CozierCamps\\assets\\heartbeat.wav", "SFX")

	-- Set up repeating ticker
	adventureModeUIState.heartbeatHandle = C_Timer.NewTicker(HEARTBEAT_INTERVAL, function()
		if adventureModeUIState.heartbeatPlaying and CC.GetSetting("playSoundHeartbeat") and
				CC.GetSetting("constitutionEnabled") and CC.IsPlayerEligible() then
			PlaySoundFile("Interface\\AddOns\\CozierCamps\\assets\\heartbeat.wav", "SFX")
		else
			-- Stop if no longer needed
			if adventureModeUIState.heartbeatHandle then
				adventureModeUIState.heartbeatHandle:Cancel()
				adventureModeUIState.heartbeatHandle = nil
			end
			adventureModeUIState.heartbeatPlaying = false
		end
	end)
	CC.Debug("Adventure Mode: Heartbeat sound started", "constitution")
end

local function StopHeartbeatSound()
	if not adventureModeUIState.heartbeatPlaying then
		return
	end

	adventureModeUIState.heartbeatPlaying = false
	if adventureModeUIState.heartbeatHandle then
		adventureModeUIState.heartbeatHandle:Cancel()
		adventureModeUIState.heartbeatHandle = nil
	end
	CC.Debug("Adventure Mode: Heartbeat sound stopped", "constitution")
end

-- Adventure Mode UI hiding thresholds
local ADVENTURE_THRESHOLD_TARGET = 75 -- Hide target frame and nameplates below this
local ADVENTURE_THRESHOLD_PLAYER = 50 -- Hide player frame below this
local ADVENTURE_THRESHOLD_BARS = 25 -- Hide action bars and map below this

-- Fade animation tracking for UI elements
local UI_FADE_SPEED = 3.0 -- Alpha change per second
local frameFadeState = {
	playerFrame = {
		current = 1,
		target = 1,
		shown = true
	},
	targetFrame = {
		current = 1,
		target = 1,
		shown = true
	}
}

-- Update fade animations for UI frames (called every frame)
local function UpdateUIFadeAnimations(elapsed)
	if InCombatLockdown() then
		return
	end

	-- Player Frame fade
	local pf = frameFadeState.playerFrame
	if pf.target ~= pf.current then
		local diff = pf.target - pf.current
		if math.abs(diff) < 0.01 then
			pf.current = pf.target
		else
			pf.current = pf.current + (diff * UI_FADE_SPEED * elapsed)
		end
		pf.current = math.max(0, math.min(1, pf.current))

		if PlayerFrame then
			PlayerFrame:SetAlpha(pf.current)
			if pf.current <= 0.01 and pf.target == 0 then
				PlayerFrame:Hide()
				pf.shown = false
			elseif pf.current > 0 and not pf.shown then
				PlayerFrame:Show()
				pf.shown = true
			end
		end
	end

	-- Target Frame fade
	local tf = frameFadeState.targetFrame
	if TargetFrame then
		-- Interpolate alpha toward target
		if tf.target ~= tf.current then
			local diff = tf.target - tf.current
			if math.abs(diff) < 0.02 then
				tf.current = tf.target
			else
				tf.current = tf.current + (diff * UI_FADE_SPEED * elapsed)
			end
			tf.current = math.max(0, math.min(1, tf.current))
		end

		-- Always apply alpha to frame
		TargetFrame:SetAlpha(tf.current)

		-- Sync combo frames alpha with target frame (try all possible frame names)
		if ComboFrame then
			ComboFrame:SetAlpha(tf.current)
		end
		if ComboPointPlayerFrame then
			ComboPointPlayerFrame:SetAlpha(tf.current)
		end
		-- Individual combo point textures (Classic WoW style)
		for i = 1, 5 do
			local cp = _G["ComboPoint" .. i]
			if cp then
				cp:SetAlpha(tf.current)
			end
		end

		-- Hide when fully faded out
		if tf.current < 0.02 and tf.target == 0 then
			if TargetFrame:IsShown() then
				TargetFrame:Hide()
			end

			-- Also hide combo frames (rogue combo points) when target is hidden
			if ComboFrame and ComboFrame:IsShown() then
				ComboFrame:Hide()
			end
			if ComboPointPlayerFrame and ComboPointPlayerFrame:IsShown() then
				ComboPointPlayerFrame:Hide()
			end
			for i = 1, 5 do
				local cp = _G["ComboPoint" .. i]
				if cp and cp:IsShown() then
					cp:Hide()
				end
			end
			-- Show when should be visible and there's a target
		elseif tf.target == 1 and UnitExists("target") and not TargetFrame:IsShown() then
			TargetFrame:Show()
		end
	end
end

-- Fade out player frame (instead of instant hide)
local function FadeOutPlayerFrame()
	if InCombatLockdown() then
		return false
	end
	frameFadeState.playerFrame.target = 0
	if PlayerFrame and not frameFadeState.playerFrame.shown then
		PlayerFrame:Show()
		frameFadeState.playerFrame.shown = true
	end
	return true
end

-- Fade in player frame (instead of instant show)
local function FadeInPlayerFrame()
	if InCombatLockdown() then
		return false
	end
	frameFadeState.playerFrame.target = 1
	if PlayerFrame and not frameFadeState.playerFrame.shown then
		PlayerFrame:Show()
		frameFadeState.playerFrame.shown = true
	end
	return true
end

-- Fade in target frame (instead of instant show)
local function FadeInTargetFrame()
	if InCombatLockdown() then
		return false
	end
	frameFadeState.targetFrame.target = 1
	if TargetFrame and UnitExists("target") and not frameFadeState.targetFrame.shown then
		TargetFrame:Show()
		frameFadeState.targetFrame.shown = true
	end
	return true
end

-- Safe frame hide/show that handles protected frames and errors
local function SafeHideFrame(frame)
	if not frame then
		return false
	end
	if InCombatLockdown() then
		return false
	end -- Can't modify protected frames in combat
	local success, err = pcall(function()
		frame:Hide()
	end)
	if not success then
		CC.Debug("Adventure Mode: Failed to hide frame - " .. tostring(err), "constitution")
	end
	return success
end

local function SafeShowFrame(frame)
	if not frame then
		return false
	end
	if InCombatLockdown() then
		return false
	end -- Can't modify protected frames in combat
	local success, err = pcall(function()
		-- Force complete visual reset to avoid ghost artifacts
		frame:SetAlpha(1)
		frame:Show()
		-- Force layout update if possible
		if frame.SetShown then
			frame:SetShown(true)
		end
		-- For action bars, ensure buttons are also visible
		if frame.GetName then
			local frameName = frame:GetName()
			if frameName and (frameName:match("Bar") or frameName == "MainMenuBar") then
				-- Reset alpha on any child buttons
				for i = 1, 12 do
					local buttonName = frameName == "MainMenuBar" and ("ActionButton" .. i) or
							(frameName .. "Button" .. i)
					local button = _G[buttonName]
					if button then
						button:SetAlpha(1)
						if not button:IsShown() then
							button:Show()
						end
					end
				end
			end
		end
	end)
	if not success then
		CC.Debug("Adventure Mode: Failed to show frame - " .. tostring(err), "constitution")
	end
	return success
end

-- Update Adventure Mode UI visibility based on constitution
local function UpdateAdventureModeUI(constitution)
	-- Don't modify UI during combat (protected frames)
	if InCombatLockdown() then
		return
	end

	if not CC.GetSetting or not CC.GetSetting("constitutionEnabled") then
		-- Adventure mode not enabled, restore everything
		if adventureModeUIState.playerFrameHidden or adventureModeUIState.targetFrameHidden or
				adventureModeUIState.actionBarsHidden or adventureModeUIState.nameplatesDisabled then
			-- Fade in player/target frames (not handled by unified API)
			FadeInPlayerFrame()
			if UnitExists("target") then
				FadeInTargetFrame()
			end
			-- Release constitution override - let ActionBars.lua handle the rest
			if adventureModeUIState.actionBarsHidden and CC.SetConstitutionOverride then
				CC.SetConstitutionOverride(false)
			end
			-- Restore nameplates
			if adventureModeUIState.nameplatesDisabled then
				pcall(function()
					SetCVar("nameplateShowAll", adventureModeUIState.previousNameplateSettings.showAll or "1")
					SetCVar("nameplateShowFriends", adventureModeUIState.previousNameplateSettings.showFriends or "0")
					SetCVar("nameplateShowEnemies", adventureModeUIState.previousNameplateSettings.showEnemies or "1")
				end)
			end
			-- Reset state
			adventureModeUIState.playerFrameHidden = false
			adventureModeUIState.targetFrameHidden = false
			adventureModeUIState.nameplatesDisabled = false
			adventureModeUIState.actionBarsHidden = false
			adventureModeUIState.mapDisabled = false
		end
		-- Stop heartbeat sound when adventure mode is disabled
		StopHeartbeatSound()
		return
	end

	-- In instances or on flights, constitution is paused - restore UI that was hidden and skip restrictions
	local inInstance = CC.IsInDungeonOrRaid and CC.IsInDungeonOrRaid()
	local onTaxi = UnitOnTaxi("player")
	if inInstance or onTaxi then
		-- Restore player frame if it was hidden
		if adventureModeUIState.playerFrameHidden then
			FadeInPlayerFrame()
			frameFadeState.playerFrame.target = 1
			if PlayerFrame then
				PlayerFrame:SetAlpha(1)
				PlayerFrame:Show()
			end
			adventureModeUIState.playerFrameHidden = false
		end

		-- Restore target frame if it was hidden
		if adventureModeUIState.targetFrameHidden then
			FadeInTargetFrame()
			frameFadeState.targetFrame.target = 1
			if TargetFrame then
				TargetFrame:SetAlpha(1)
				if UnitExists("target") then
					TargetFrame:Show()
				end
			end
			-- Restore combo frames alpha
			if ComboFrame then
				ComboFrame:SetAlpha(1)
			end
			if ComboPointPlayerFrame then
				ComboPointPlayerFrame:SetAlpha(1)
			end
			for i = 1, 5 do
				local cp = _G["ComboPoint" .. i]
				if cp then
					cp:SetAlpha(1)
				end
			end
			adventureModeUIState.targetFrameHidden = false
		end

		-- Restore action bars if they were hidden by constitution
		if adventureModeUIState.actionBarsHidden then
			if CC.SetConstitutionOverride then
				CC.SetConstitutionOverride(false)
			end
			adventureModeUIState.actionBarsHidden = false
		end

		-- Restore nameplates if they were disabled
		if adventureModeUIState.nameplatesDisabled then
			pcall(function()
				SetCVar("nameplateShowAll", adventureModeUIState.previousNameplateSettings.showAll or "1")
				SetCVar("nameplateShowFriends", adventureModeUIState.previousNameplateSettings.showFriends or "0")
				SetCVar("nameplateShowEnemies", adventureModeUIState.previousNameplateSettings.showEnemies or "1")
			end)
			adventureModeUIState.nameplatesDisabled = false
		end

		-- Allow map usage while paused
		if adventureModeUIState.mapDisabled then
			adventureModeUIState.mapDisabled = false
		end

		-- Heartbeat should never play while paused
		StopHeartbeatSound()
		return
	end

	-- Check if player is dead or ghost - if so, restore all UI elements
	local isPlayerDead = UnitIsDead("player") or UnitIsGhost("player")

	-- Below 75%: Hide target frame and disable nameplates (with fade animation)
	-- But NOT when dead - player needs full UI access
	if constitution < ADVENTURE_THRESHOLD_TARGET and not isPlayerDead then
		if not adventureModeUIState.targetFrameHidden then
			adventureModeUIState.targetFrameHidden = true
			CC.Debug("Adventure Mode: Target frame fading out (constitution < 75%)", "constitution")
		end
		-- Continuously enforce target frame fade out
		if TargetFrame then
			frameFadeState.targetFrame.target = 0
			-- If frame was just shown (e.g. new target acquired), sync alpha to start fade from current
			if TargetFrame:IsShown() then
				local actualAlpha = TargetFrame:GetAlpha()
				if actualAlpha > frameFadeState.targetFrame.current + 0.1 then
					frameFadeState.targetFrame.current = actualAlpha
				end
			end
		end
		-- Save nameplate settings only once (first time we disable)
		if not adventureModeUIState.nameplatesDisabled then
			pcall(function()
				adventureModeUIState.previousNameplateSettings.showAll = GetCVar("nameplateShowAll")
				adventureModeUIState.previousNameplateSettings.showFriends = GetCVar("nameplateShowFriends")
				adventureModeUIState.previousNameplateSettings.showEnemies = GetCVar("nameplateShowEnemies")
			end)
			adventureModeUIState.nameplatesDisabled = true
			CC.Debug("Adventure Mode: Nameplates disabled (constitution < 75%)", "constitution")
		end
		-- Always enforce nameplate CVars while below threshold (in case something resets them)
		pcall(function()
			if GetCVar("nameplateShowEnemies") ~= "0" then
				SetCVar("nameplateShowAll", "0")
				SetCVar("nameplateShowFriends", "0")
				SetCVar("nameplateShowEnemies", "0")
				CC.Debug("Adventure Mode: Re-enforcing nameplate CVars", "constitution")
			end
		end)
	else
		-- Constitution above 75% - ensure target frame can be visible
		if TargetFrame then
			frameFadeState.targetFrame.target = 1
		end
		if adventureModeUIState.targetFrameHidden then
			adventureModeUIState.targetFrameHidden = false
			CC.Debug("Adventure Mode: Target frame fading in", "constitution")
		end
		if adventureModeUIState.nameplatesDisabled then
			-- Restore nameplate settings
			pcall(function()
				SetCVar("nameplateShowAll", adventureModeUIState.previousNameplateSettings.showAll or "1")
				SetCVar("nameplateShowFriends", adventureModeUIState.previousNameplateSettings.showFriends or "0")
				SetCVar("nameplateShowEnemies", adventureModeUIState.previousNameplateSettings.showEnemies or "1")
			end)
			adventureModeUIState.nameplatesDisabled = false
			CC.Debug("Adventure Mode: Nameplates restored", "constitution")
		end
	end

	-- Below 50%: Hide player frame (with fade animation)
	-- But NOT when dead - player needs full UI access
	if constitution < ADVENTURE_THRESHOLD_PLAYER and not isPlayerDead then
		if not adventureModeUIState.playerFrameHidden then
			if FadeOutPlayerFrame() then
				adventureModeUIState.playerFrameHidden = true
				CC.Debug("Adventure Mode: Player frame fading out (constitution < 50%)", "constitution")
			end
		end
	else
		if adventureModeUIState.playerFrameHidden then
			if FadeInPlayerFrame() then
				adventureModeUIState.playerFrameHidden = false
				CC.Debug("Adventure Mode: Player frame fading in", "constitution")
			end
		end
	end

	-- Below 25%: Hide action bars, minimap, and disable map using unified hiding system
	-- But NOT when dead - player needs full UI access
	if constitution < ADVENTURE_THRESHOLD_BARS and not isPlayerDead then
		-- Use unified action bar hiding API from ActionBars.lua
		-- This hides all action bars, minimap, reputation bar, etc. consistently
		if not adventureModeUIState.actionBarsHidden then
			if CC.SetConstitutionOverride then
				CC.SetConstitutionOverride(true)
			end
			adventureModeUIState.actionBarsHidden = true
			CC.Debug("Adventure Mode: UI hidden via unified API (constitution < 25%)", "constitution")
		end

		-- Map blocking (separate from action bar system)
		-- Only block map if the blockMap setting is enabled
		if CC.GetSetting("blockMap") then
			if not adventureModeUIState.mapDisabled then
				-- Hook the map to prevent opening (only install hook once)
				if not adventureModeUIState.mapHookInstalled then
					pcall(function()
						hooksecurefunc("ToggleWorldMap", function()
							-- Allow map when dead, in combat, or when blockMap setting is disabled
							if adventureModeUIState.mapDisabled and CC.GetSetting("blockMap") and not InCombatLockdown() and
									not UnitIsDead("player") and not UnitIsGhost("player") and WorldMapFrame and
									WorldMapFrame:IsShown() then
								WorldMapFrame:Hide()
								print("|cff88CCFFCozierCamps:|r |cffFF6666Map disabled - constitution too low!|r")
							end
						end)
					end)
					adventureModeUIState.mapHookInstalled = true
				end
				adventureModeUIState.mapDisabled = true
				-- Close map if open (only outside combat)
				if not InCombatLockdown() then
					pcall(function()
						if WorldMapFrame and WorldMapFrame:IsShown() then
							WorldMapFrame:Hide()
						end
					end)
				end
				CC.Debug("Adventure Mode: Map disabled (constitution < 25%)", "constitution")
			else
				-- Re-enforce map closure if map somehow got opened (only outside combat)
				if not InCombatLockdown() then
					pcall(function()
						if WorldMapFrame and WorldMapFrame:IsShown() then
							WorldMapFrame:Hide()
							print("|cff88CCFFCozierCamps:|r |cffFF6666Map disabled - constitution too low!|r")
						end
					end)
				end
			end
		end

		-- Start heartbeat sound if enabled
		StartHeartbeatSound()
	else
		-- Constitution recovered - release the override
		if adventureModeUIState.actionBarsHidden then
			adventureModeUIState.actionBarsHidden = false

			-- Release constitution override - ActionBars.lua will handle the rest
			-- based on hideActionBarsMode setting (show if near fire/rested, etc.)
			if CC.SetConstitutionOverride then
				CC.SetConstitutionOverride(false)
			end
			CC.Debug("Adventure Mode: Constitution override released", "constitution")
		end
		if adventureModeUIState.mapDisabled then
			adventureModeUIState.mapDisabled = false
			CC.Debug("Adventure Mode: Map enabled", "constitution")
		end

		-- Stop heartbeat sound when constitution recovers
		StopHeartbeatSound()
	end

	-- Also clear mapDisabled if blockMap setting is turned off (regardless of constitution)
	if adventureModeUIState.mapDisabled and not CC.GetSetting("blockMap") then
		adventureModeUIState.mapDisabled = false
		CC.Debug("Adventure Mode: Map enabled (blockMap setting disabled)", "constitution")
	end
end

-- Animation state
-- Atlas textures for glow effects
-- GarrMission_LevelUpBanner - Red damage glow for Anguish (note: two r's in Garr)
-- Use same atlas for green but tint it - ensures consistent size
local ATLAS_RED = "GarrMission_LevelUpBanner"
local ATLAS_GREEN = "GarrMission_LevelUpBanner" -- Same atlas, will be tinted green
local ATLAS_PAUSED = "search-highlight" -- Yellow glow for paused state

-- Create glow frame using atlas textures for beautiful glow effects
local function CreateGlowFrame(meter, isAnguish)
	local glow = CreateFrame("Frame", nil, meter)
	glow:SetFrameLevel(meter:GetFrameLevel() + 10) -- Well above the meter for visibility
	glow:EnableMouse(false) -- Allow mouse events to pass through for tooltip

	-- Position glow around the meter with padding
	local glowPadding = GLOW_SIZE + 8
	glow:SetPoint("TOPLEFT", meter, "TOPLEFT", -glowPadding, glowPadding + 1)
	glow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", glowPadding, -glowPadding - 1)

	if isAnguish then
		-- Single texture for red (symmetric atlas)
		glow.texture = glow:CreateTexture(nil, "ARTWORK")
		glow.texture:SetAllPoints()
		glow.texture:SetAtlas(ATLAS_RED)
		glow.texture:SetBlendMode("ADD")
		glow.isTwoSided = false
	else
		-- White/pearl glow - use the same atlas, tinted cool white
		glow.texture = glow:CreateTexture(nil, "ARTWORK")
		glow.texture:SetAllPoints()
		glow.texture:SetAtlas(ATLAS_RED) -- Use same atlas as red
		glow.texture:SetVertexColor(0.85, 0.9, 1.0) -- Cool white/pearl tint (less red)
		glow.texture:SetBlendMode("ADD")
		glow.isTwoSided = false
	end

	-- Store current atlas for color switching
	glow.currentAtlas = isAnguish and ATLAS_RED or "GarrMission_ListGlow-Highlight"
	glow.isAnguish = isAnguish

	-- Store color for easy access (used for state tracking)
	glow.r = 1
	glow.g = 0.2
	glow.b = 0.2
	glow.isGreen = false -- Track if we're showing green (decay) glow
	glow.isOrange = false -- Track if we're showing orange (negative) glow
	glow.isPaused = false -- Track if we're showing paused glow

	-- Explicitly show the glow frame (alpha will control visibility)
	glow:Show()
	glow:SetAlpha(0)
	glow.currentAlpha = 0
	glow.targetAlpha = 0
	glow.currentSize = GLOW_SIZE
	glow.targetSize = GLOW_SIZE
	glow.pulsePhase = 0 -- For pulsing effect

	return glow
end

-- Update glow color/atlas based on state
local function SetGlowColor(glow, r, g, b, isPaused)
	glow.r = r
	glow.g = g
	glow.b = b

	-- Determine color type: green (healing/decay), orange (negative), or default
	local isGreen = g > 0.5 and r < 0.5
	local isOrange = r > 0.8 and g > 0.2 and g < 0.6 and b < 0.3

	if isPaused and not glow.isPaused then
		-- Switch to paused state - use native atlas color (yellow/blue)
		glow.texture:SetAtlas(ATLAS_PAUSED)
		glow.texture:SetVertexColor(1, 1, 1) -- No tint, use native color
		glow.isGreen = false
		glow.isOrange = false
		glow.isPaused = true
	elseif not isPaused and glow.isPaused then
		-- Exiting paused state - restore based on current color request
		glow.texture:SetAtlas(ATLAS_RED)
		glow.isPaused = false
		-- Fall through to color handling below
	end

	-- Handle color switching when not paused
	if not isPaused then
		if isGreen and not glow.isGreen then
			-- Switch to green - tint the atlas green
			glow.texture:SetAtlas(ATLAS_GREEN)
			glow.texture:SetVertexColor(0.2, 1.0, 0.3) -- Green tint
			glow.isGreen = true
			glow.isOrange = false
		elseif isOrange and not glow.isOrange then
			-- Switch to orange - tint the atlas orange
			glow.texture:SetAtlas(ATLAS_RED)
			glow.texture:SetVertexColor(1.0, 0.5, 0.1) -- Orange tint
			glow.isGreen = false
			glow.isOrange = true
		elseif not isGreen and not isOrange and (glow.isGreen or glow.isOrange) then
			-- Switch back to original/default color
			glow.texture:SetAtlas(ATLAS_RED)
			if glow.isAnguish then
				glow.texture:SetVertexColor(1, 1, 1) -- No tint for red (atlas is already red)
			else
				glow.texture:SetVertexColor(0.85, 0.9, 1.0) -- Cool white/pearl tint
			end
			glow.isGreen = false
			glow.isOrange = false
		end
	end
end

-- Update glow size dynamically
local function UpdateGlowSize(glow, meter, size)
	local verticalOffset = 3 -- Vertical offset for centering (nudge down)

	-- For paused state (negative size), match temperature cold glow styling
	if size < 0 then
		-- Paused: tight vertical glow like temperature cold effect
		-- No horizontal extension, just 2px vertical extension
		glow:ClearAllPoints()
		glow:SetPoint("TOPLEFT", meter, "TOPLEFT", 0, 2)
		glow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", 0, -2)
	else
		-- Normal: glow extends beyond the bar
		local glowPadding = size + 8
		glow:ClearAllPoints()
		glow:SetPoint("TOPLEFT", meter, "TOPLEFT", -glowPadding, glowPadding + verticalOffset)
		glow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", glowPadding, -glowPadding - verticalOffset)
	end
end

-- Create milestone notches on a meter bar (for Anguish checkpoints)
local function CreateMilestoneNotches(meter)
	local barWidth = METER_WIDTH - (METER_PADDING * 2)
	local barHeight = METER_HEIGHT - (METER_PADDING * 2)

	meter.notches = {}
	local milestones = { 25, 50, 75 }

	for _, pct in ipairs(milestones) do
		local notch = meter:CreateTexture(nil, "OVERLAY", nil, 6)
		notch:SetSize(1, barHeight) -- 1 pixel wide, full height
		-- Position at percentage point along the bar
		local xOffset = METER_PADDING + (barWidth * (pct / 100))
		notch:SetPoint("LEFT", meter, "LEFT", xOffset, 0)
		notch:SetColorTexture(0, 0, 0, 0.5) -- Subtle dark line
		table.insert(meter.notches, notch)
	end
end

-- Icon size for meter icons
local ICON_SIZE = 14

-- Create a single meter frame
local function CreateMeter(name, parent, yOffset, iconPath, isAnguish)
	local meter = CreateFrame("Frame", "CozierCamps" .. name .. "Meter", parent, "BackdropTemplate")
	meter:SetSize(METER_WIDTH, METER_HEIGHT)
	meter:SetPoint("TOP", parent, "TOP", 0, yOffset)

	-- Background with shadow effect
	meter:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		insets = {
			left = 2,
			right = 2,
			top = 2,
			bottom = 2
		}
	})
	meter:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	meter:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	-- Status bar (lower frame level so icon/text appear above)
	meter.bar = CreateFrame("StatusBar", nil, meter)
	meter.bar:SetFrameLevel(meter:GetFrameLevel()) -- Same level as parent, textures will be below OVERLAY
	meter.bar:SetPoint("TOPLEFT", METER_PADDING, -METER_PADDING)
	meter.bar:SetPoint("BOTTOMRIGHT", -METER_PADDING, METER_PADDING)
	meter.bar:SetStatusBarTexture(GetBarTexture())
	meter.bar:SetMinMaxValues(0, 100)
	meter.bar:SetValue(0)
	meter.bar:EnableMouse(false) -- Allow mouse events to pass through to parent for tooltip

	-- Icon on top of the bar, floating at the left/starting position
	-- Created on meter frame with high draw layer to ensure visibility
	if iconPath then
		meter.icon = meter:CreateTexture(nil, "OVERLAY", nil, 7) -- Sub-layer 7 for highest priority
		meter.icon:SetSize(ICON_SIZE, ICON_SIZE)
		meter.icon:SetPoint("LEFT", meter.bar, "LEFT", 2, 0)
		meter.icon:SetTexture(iconPath)
		meter.icon:SetVertexColor(1, 1, 1, 1) -- Full white, full opacity
	end

	-- Glow frame (outlines the bar) - pass isAnguish to determine atlas color
	meter.glow = CreateGlowFrame(meter, isAnguish)

	-- Percentage text (no label needed since icon identifies the bar)
	meter.percent = meter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	local fontPath = GetBarFont()
	if fontPath then
		meter.percent:SetFont(fontPath, 10, "OUTLINE")
	end
	meter.percent:SetPoint("RIGHT", meter.bar, "RIGHT", -4, 0)
	meter.percent:SetText("0%")
	meter.percent:SetTextColor(1, 1, 1, 0.9)

	-- Enable mouse for tooltip and drag forwarding to container
	meter:EnableMouse(true)
	meter:RegisterForDrag("LeftButton")
	meter:SetScript("OnDragStart", function()
		StartMovingMetersContainer()
	end)
	meter:SetScript("OnDragStop", function()
		if metersContainer then
			metersContainer:StopMovingOrSizing()
			-- Save absolute screen coordinates of top-left corner for consistent placement
			if not CC.GetSetting("metersLocked") then
				local left = metersContainer:GetLeft()
				local top = metersContainer:GetTop()
				if CC.db and left and top then
					CC.db.meterPosition = {
						screenLeft = left,
						screenTop = top
					}
				end
			end
		end
	end)

	return meter
end

-- Create constitution bar meter (for bar mode - appears at top of stack)
local function CreateConstitutionBarMeter(parent, yOffset)
	local meter = CreateFrame("Frame", "CozierCampsConstitutionBarMeter", parent, "BackdropTemplate")
	meter:SetSize(METER_WIDTH, METER_HEIGHT)
	meter:SetPoint("TOP", parent, "TOP", 0, yOffset)

	-- Background with shadow effect
	meter:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		insets = {
			left = 2,
			right = 2,
			top = 2,
			bottom = 2
		}
	})
	meter:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	meter:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	-- Status bar
	meter.bar = CreateFrame("StatusBar", nil, meter)
	meter.bar:SetFrameLevel(meter:GetFrameLevel())
	meter.bar:SetPoint("TOPLEFT", METER_PADDING, -METER_PADDING)
	meter.bar:SetPoint("BOTTOMRIGHT", -METER_PADDING, METER_PADDING)
	meter.bar:SetStatusBarTexture(GetBarTexture())
	meter.bar:SetMinMaxValues(0, 100)
	meter.bar:SetValue(100)
	meter.bar:SetStatusBarColor(CONSTITUTION_BAR_COLOR.r, CONSTITUTION_BAR_COLOR.g, CONSTITUTION_BAR_COLOR.b)
	meter.bar:EnableMouse(false) -- Allow mouse events to pass through to parent for tooltip

	-- Constitution icon
	meter.icon = meter:CreateTexture(nil, "OVERLAY", nil, 7)
	meter.icon:SetSize(ICON_SIZE * 1.1, ICON_SIZE * 1.1) -- Slightly larger like Anguish
	meter.icon:SetPoint("LEFT", meter.bar, "LEFT", 2, 0)
	meter.icon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\constitutionicon.blp")
	meter.icon:SetVertexColor(1, 1, 1, 1)

	-- Glow frame (same style as Anguish - using atlas)
	meter.glow = CreateGlowFrame(meter, true) -- Use Anguish-style red glow

	-- Percentage text
	meter.percent = meter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	local fontPath = GetBarFont()
	if fontPath then
		meter.percent:SetFont(fontPath, 10, "OUTLINE")
	end
	meter.percent:SetPoint("RIGHT", meter.bar, "RIGHT", -4, 0)
	meter.percent:SetText("100%")
	meter.percent:SetTextColor(1, 1, 1, 0.9)

	-- State tracking for glow
	meter.glowState = "green" -- "green" or "orange"
	meter.glowCooldown = 0

	-- Enable mouse for tooltip and drag
	meter:EnableMouse(true)
	meter:RegisterForDrag("LeftButton")
	meter:SetScript("OnDragStart", function()
		StartMovingMetersContainer()
	end)
	meter:SetScript("OnDragStop", function()
		if metersContainer then
			metersContainer:StopMovingOrSizing()
			-- Save absolute screen coordinates of top-left corner for consistent placement
			if not CC.GetSetting("metersLocked") then
				local left = metersContainer:GetLeft()
				local top = metersContainer:GetTop()
				if CC.db and left and top then
					CC.db.meterPosition = {
						screenLeft = left,
						screenTop = top
					}
				end
			end
		end
	end)

	return meter
end

-- Setup constitution bar tooltip (reuses logic from orb tooltip)
local function SetupConstitutionBarTooltip(meter)
	-- Use hitbox for vial meters, otherwise use meter itself
	local tooltipTarget = meter.hitbox or meter

	-- Ensure hitbox is properly configured for mouse events
	if meter.hitbox then
		meter.hitbox:EnableMouse(true)
		meter.hitbox:Show()
	end

	tooltipTarget:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

		local constitution, contributions = CalculateConstitution()
		if not constitution then
			GameTooltip:SetText("Constitution", 0.8, 0.2, 0.2)
			GameTooltip:AddLine("Requires at least 2 survival meters enabled", 0.7, 0.7, 0.7)
			GameTooltip:Show()
			return
		end

		-- Check if all ENABLED systems are paused (disabled systems treated as paused)
		local anguishEnabled = CC.GetSetting and CC.GetSetting("AnguishEnabled")
		local exhaustionEnabled = CC.GetSetting and CC.GetSetting("exhaustionEnabled")
		local hungerEnabled = CC.GetSetting and CC.GetSetting("hungerEnabled")
		local thirstEnabled = CC.GetSetting and CC.GetSetting("thirstEnabled")
		local temperatureEnabled = CC.GetSetting and CC.GetSetting("temperatureEnabled")
		local anguishPaused = (not anguishEnabled) or (CC.IsAnguishPaused and CC.IsAnguishPaused() or false)
		local exhaustionPaused = (not exhaustionEnabled) or (CC.IsExhaustionPaused and CC.IsExhaustionPaused() or false)
		local hungerPaused = (not hungerEnabled) or (CC.IsHungerPaused and CC.IsHungerPaused() or false)
		local thirstPaused = (not thirstEnabled) or (CC.IsThirstPaused and CC.IsThirstPaused() or false)
		local temperaturePaused = (not temperatureEnabled) or
				(CC.IsTemperaturePaused and CC.IsTemperaturePaused() or false)
		local isPaused = anguishPaused and exhaustionPaused and hungerPaused and thirstPaused and temperaturePaused

		-- Title based on paused or glow state
		local trendText, trendR, trendG, trendB
		if isPaused then
			trendText = " - Paused"
			trendR, trendG, trendB = 0.5, 0.7, 1.0
		elseif constitutionGlowState == "green" then
			trendText = " - Improving"
			trendR, trendG, trendB = 0.2, 1.0, 0.3
		elseif constitutionGlowState == "orange" then
			trendText = " - Declining"
			trendR, trendG, trendB = 1.0, 0.5, 0.2
		else
			trendText = " - Stable"
			trendR, trendG, trendB = 0.7, 0.7, 0.7
		end

		GameTooltip:SetText("Constitution" .. trendText, trendR, trendG, trendB)
		GameTooltip:AddLine(string.format("Overall Health: %.0f%%", constitution), 1, 1, 1)
		GameTooltip:AddLine(" ")

		-- Active Effects section at the top (shows current status of each meter)
		GameTooltip:AddLine("Active Effects:", 1, 0.9, 0.5)

		local totalWeight = 0
		if anguishEnabled then
			totalWeight = totalWeight + CONSTITUTION_WEIGHTS.anguish
		end
		if exhaustionEnabled then
			totalWeight = totalWeight + CONSTITUTION_WEIGHTS.exhaustion
		end
		if hungerEnabled then
			totalWeight = totalWeight + CONSTITUTION_WEIGHTS.hunger
		end
		if thirstEnabled then
			totalWeight = totalWeight + CONSTITUTION_WEIGHTS.thirst
		end
		if temperatureEnabled then
			totalWeight = totalWeight + CONSTITUTION_WEIGHTS.temperature
		end

		local anguishPct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.anguish / totalWeight * 100) or 0
		local exhaustionPct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.exhaustion / totalWeight * 100) or 0
		local hungerPct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.hunger / totalWeight * 100) or 0
		local thirstPct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.thirst / totalWeight * 100) or 0
		local temperaturePct = totalWeight > 0 and (CONSTITUTION_WEIGHTS.temperature / totalWeight * 100) or 0

		if anguishEnabled then
			local anguish = CC.GetAnguish and CC.GetAnguish() or 0
			local status = anguishPaused and "Resting" or
					(anguish > 50 and "Wounded" or (anguish > 20 and "Bruised" or "Healthy"))
			local statusColor = anguish > 50 and { 1, 0.4, 0.4 } or (anguish > 20 and { 1, 0.8, 0.4 } or { 0.4, 1, 0.4 })
			GameTooltip:AddLine(string.format("  Anguish: %s", status), statusColor[1],
					statusColor[2], statusColor[3])
		end

		if exhaustionEnabled then
			local exhaustion = CC.GetExhaustion and CC.GetExhaustion() or 0
			local status = exhaustionPaused and "Resting" or
					(exhaustion > 50 and "Tired" or (exhaustion > 20 and "Fatigued" or "Energized"))
			local statusColor = exhaustion > 50 and { 1, 0.4, 0.4 } or
					(exhaustion > 20 and { 1, 0.8, 0.4 } or { 0.4, 1, 0.4 })
			GameTooltip:AddLine(string.format("  Exhaustion: %s (%.0f%%)", status, exhaustionPct), statusColor[1],
					statusColor[2], statusColor[3])
		end

		if hungerEnabled then
			local hunger = CC.GetHunger and CC.GetHunger() or 0
			local isWellFed = CC.HasWellFedBuff and CC.HasWellFedBuff() or false
			local status = isWellFed and "Well Fed" or
					(hungerPaused and "Satisfied" or
							(hunger > 50 and "Hungry" or (hunger > 20 and "Peckish" or "Satisfied")))
			local statusColor = isWellFed and { 0.4, 1, 0.8 } or
					(hunger > 50 and { 1, 0.4, 0.4 } or (hunger > 20 and { 1, 0.8, 0.4 } or { 0.4, 1, 0.4 }))
			GameTooltip:AddLine(string.format("  Hunger: %s (%.0f%%)", status, hungerPct), statusColor[1],
					statusColor[2], statusColor[3])
		end

		if thirstEnabled then
			local thirst = CC.GetThirst and CC.GetThirst() or 0
			local hasRefreshed = CC.HasRefreshedBuff and CC.HasRefreshedBuff() or false
			local status = hasRefreshed and "Refreshed" or
					(thirstPaused and "Hydrated" or
							(thirst > 50 and "Parched" or (thirst > 20 and "Thirsty" or "Hydrated")))
			local statusColor = hasRefreshed and { 0.4, 1, 0.8 } or
					(thirst > 50 and { 1, 0.4, 0.4 } or (thirst > 20 and { 1, 0.8, 0.4 } or { 0.4, 1, 0.4 }))
			GameTooltip:AddLine(string.format("  Thirst: %s (%.0f%%)", status, thirstPct), statusColor[1],
					statusColor[2], statusColor[3])
		end

		if temperatureEnabled then
			local temp = CC.GetTemperature and CC.GetTemperature() or 0
			local status = temperaturePaused and "Comfortable" or (temp < -30 and "Freezing" or
					(temp < -10 and "Cold" or
							(temp > 30 and "Overheating" or (temp > 10 and "Warm" or "Comfortable"))))
			local statusColor = (math.abs(temp) > 30) and { 1, 0.4, 0.4 } or
					(math.abs(temp) > 10 and { 1, 0.8, 0.4 } or { 0.4, 1, 0.4 })
			GameTooltip:AddLine(string.format("  Temperature: %s (%.0f%%)", status, temperaturePct), statusColor[1],
					statusColor[2], statusColor[3])
		end

		GameTooltip:AddLine(" ")

		-- Show contribution from each meter (detailed mode only)
		if tooltipMode == "detailed" then
			GameTooltip:AddLine("Impact Breakdown:", 0.8, 0.8, 0.8)
			if contributions.anguish then
				local impactColor = contributions.anguish > 5 and { 1, 0.4, 0.4 } or { 0.4, 1, 0.4 }
				GameTooltip:AddLine(string.format("  Anguish: -%.1f%%", contributions.anguish), impactColor[1],
						impactColor[2], impactColor[3])
			end
			if contributions.exhaustion then
				local impactColor = contributions.exhaustion > 5 and { 1, 0.4, 0.4 } or { 0.4, 1, 0.4 }
				GameTooltip:AddLine(string.format("  Exhaustion: -%.1f%%", contributions.exhaustion), impactColor[1],
						impactColor[2], impactColor[3])
			end
			if contributions.hunger then
				local impactColor = contributions.hunger > 5 and { 1, 0.4, 0.4 } or { 0.4, 1, 0.4 }
				GameTooltip:AddLine(string.format("  Hunger: -%.1f%%", contributions.hunger), impactColor[1],
						impactColor[2], impactColor[3])
			end
			if contributions.thirst then
				local impactColor = contributions.thirst > 5 and { 1, 0.4, 0.4 } or { 0.4, 1, 0.4 }
				GameTooltip:AddLine(string.format("  Thirst: -%.1f%%", contributions.thirst), impactColor[1],
						impactColor[2], impactColor[3])
			end
			if contributions.temperature then
				local impactColor = contributions.temperature > 5 and { 1, 0.4, 0.4 } or { 0.4, 1, 0.4 }
				GameTooltip:AddLine(string.format("  Temperature: -%.1f%%", contributions.temperature), impactColor[1],
						impactColor[2], impactColor[3])
			end

			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Adventure Mode Restrictions:", 1.0, 0.7, 0.4)
			local c75 = constitution < 75 and "|cffFF6666Active|r" or "|cff666666Inactive|r"
			local c50 = constitution < 50 and "|cffFF6666Active|r" or "|cff666666Inactive|r"
			local c25 = constitution < 25 and "|cffFF6666Active|r" or "|cff666666Inactive|r"
			GameTooltip:AddLine("  Below 75%: Target frame, nameplates hidden " .. c75, 0.7, 0.7, 0.7)
			GameTooltip:AddLine("  Below 50%: Player frame hidden " .. c50, 0.7, 0.7, 0.7)
			GameTooltip:AddLine("  Below 25%: Action bars, map disabled " .. c25, 0.7, 0.7, 0.7)

			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
			GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
		end

		GameTooltip:Show()
	end)
	tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

-- Setup Anguish meter tooltip
local function SetupAnguishTooltip(meter)
	-- Use hitbox for vial meters, otherwise use meter itself
	local tooltipTarget = meter.hitbox or meter
	tooltipTarget:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

		-- Get state for title
		local t = CC.GetAnguish and CC.GetAnguish() or 0
		local isPaused = CC.IsAnguishPaused and CC.IsAnguishPaused()
		local isDecaying = CC.IsAnguishDecaying and CC.IsAnguishDecaying()
		local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"
		local isVial = displayMode == "vial"

		-- Title with state
		if isPaused then
			GameTooltip:SetText("Anguish - Paused", 0.5, 0.7, 1.0)
		elseif isDecaying then
			GameTooltip:SetText("Anguish - Recovering", 0.2, 1.0, 0.3)
		else
			GameTooltip:SetText("Anguish", 1, 0.7, 0.7)
		end

		-- Show value appropriate to display mode
		if isVial then
			GameTooltip:AddLine(string.format("Vitality: %.0f%% (Anguish: %.1f%%)", 100 - t, t), 1, 1, 1)
		else
			GameTooltip:AddLine(string.format("Current: %.1f%%", t), 1, 1, 1)
		end
		local checkpoint = CC.GetAnguishCheckpoint and CC.GetAnguishCheckpoint() or 0
		if checkpoint > 0 then
			if isVial then
				GameTooltip:AddLine(string.format("Recovery stops at: %d%% vitality", 100 - checkpoint), 1, 0.8, 0.5)
			else
				GameTooltip:AddLine(string.format("Next checkpoint: %d%%", checkpoint), 1, 0.8, 0.5)
			end
		end

		-- Show current activity (both minimal and detailed)
		local activity = CC.GetAnguishActivity and CC.GetAnguishActivity()
		if activity then
			local actR, actG, actB = 0.7, 0.7, 0.7
			if activity == "Bandaging" or activity == "Potion healing" or activity == "Resting in town" then
				actR, actG, actB = 0.2, 1.0, 0.3 -- Green for recovery
			elseif activity == "In combat" or activity == "Dazed" then
				actR, actG, actB = 1.0, 0.4, 0.4 -- Red for danger
			end
			GameTooltip:AddLine("Activity: " .. activity, actR, actG, actB)
		end

		-- Detailed mode only: show drains, recovery methods, checkpoints, and pause conditions
		if tooltipMode == "detailed" then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Drains from:", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("  Taking damage", 0.8, 0.6, 0.6)
			GameTooltip:AddLine("  Critical hits (5x)", 1, 0.4, 0.4)
			GameTooltip:AddLine("  Being dazed (+1%, 5x while active)", 1, 0.4, 0.4)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Recovery:", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("  Bandages: 0.2%/tick while channeling", 0.6, 0.8, 0.6)
			GameTooltip:AddLine("     Stops at checkpoints", 0.5, 0.6, 0.5)
			GameTooltip:AddLine("  Potions: 0.5% every 5sec for 30sec (3% total)", 0.6, 0.8, 0.6)
			GameTooltip:AddLine("     Stops at checkpoints", 0.5, 0.6, 0.5)
			GameTooltip:AddLine("  Resting in town: slowly recovers to 75%", 0.6, 0.8, 0.6)
			GameTooltip:AddLine("     Ignores checkpoints", 0.5, 0.6, 0.5)
			if CC.GetSetting("innkeeperHealsAnguish") then
				GameTooltip:AddLine("  Innkeeper: heals up to 85% vitality", 0.4, 1, 0.4)
			end
			GameTooltip:AddLine("  First Aid Trainer: full recovery", 0.4, 1, 0.4)
			GameTooltip:AddLine(" ")
			if isVial then
				GameTooltip:AddLine("Checkpoints: 75%, 50%, 25% vitality", 1, 0.7, 0.4)
				GameTooltip:AddLine("Bandages and potions cannot recover past these.", 0.7, 0.6, 0.4)
			else
				GameTooltip:AddLine("Checkpoints: 25%, 50%, 75%", 1, 0.7, 0.4)
				GameTooltip:AddLine("Bandages and potions cannot heal past these.", 0.7, 0.6, 0.4)
			end
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
			GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
		end
		GameTooltip:Show()
	end)
	tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

-- Setup exhaustion meter tooltip
local function SetupExhaustionTooltip(meter)
	-- Use hitbox for vial meters, otherwise use meter itself
	local tooltipTarget = meter.hitbox or meter
	tooltipTarget:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

		-- Get state for title
		local e = CC.GetExhaustion and CC.GetExhaustion() or 0
		local isPaused = CC.IsExhaustionPaused and CC.IsExhaustionPaused()
		local isDecaying = CC.IsExhaustionDecaying and CC.IsExhaustionDecaying()
		local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"
		local isVial = displayMode == "vial"

		-- Title with state
		if isPaused then
			GameTooltip:SetText("Exhaustion - Paused", 0.5, 0.7, 1.0)
		elseif isDecaying then
			GameTooltip:SetText("Exhaustion - Recovering", 0.2, 1.0, 0.3)
		else
			GameTooltip:SetText("Exhaustion", 0.7, 0.8, 1)
		end

		-- Show value appropriate to display mode
		if isVial then
			GameTooltip:AddLine(string.format("Stamina: %.0f%% (Exhaustion: %.1f%%)", 100 - e, e), 1, 1, 1)
		else
			GameTooltip:AddLine(string.format("Current: %.1f%%", e), 1, 1, 1)
		end

		-- Show current activity (both minimal and detailed)
		local activity = CC.GetExhaustionActivity and CC.GetExhaustionActivity()
		if activity then
			local actR, actG, actB = 0.7, 0.7, 0.7
			if activity == "Resting by fire" or activity == "Resting in town" or activity == "Recovering" then
				actR, actG, actB = 0.2, 1.0, 0.3 -- Green for recovery
			elseif activity == "In combat" then
				actR, actG, actB = 1.0, 0.4, 0.4 -- Red for combat
			elseif activity == "On foot" or activity == "Mounted" then
				actR, actG, actB = 1.0, 0.8, 0.4 -- Yellow for movement
			end
			GameTooltip:AddLine("Activity: " .. activity, actR, actG, actB)
		end

		-- Detailed mode only: show drains, recovery, and pause conditions
		if tooltipMode == "detailed" then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Drains from:", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("  Walking/running: slow", 0.6, 0.8, 0.6)
			GameTooltip:AddLine("  Swimming: moderate", 0.6, 0.7, 0.8)
			GameTooltip:AddLine("  Mounted travel: very slow", 0.6, 0.8, 0.6)
			GameTooltip:AddLine("  In combat: fast", 0.8, 0.6, 0.6)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Recovery:", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("  Near campfire: slow recovery", 0.6, 0.8, 0.6)
			GameTooltip:AddLine("  Resting in town: rapid recovery", 0.6, 0.8, 0.6)

			-- Show effects on other meters
			local hungerEnabled = CC.GetSetting and CC.GetSetting("hungerEnabled")
			local thirstEnabled = CC.GetSetting and CC.GetSetting("thirstEnabled")
			if hungerEnabled or thirstEnabled then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("Effects on other meters:", 0.8, 0.8, 0.8)
				if hungerEnabled then
					GameTooltip:AddLine("  High exhaustion: faster hunger drain", 0.9, 0.6, 0.4)
				end
				if thirstEnabled then
					GameTooltip:AddLine("  High exhaustion: faster thirst drain", 0.9, 0.6, 0.4)
				end
			end
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
			GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
		end
		GameTooltip:Show()
	end)
	tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

-- Smoothed hunger display value to prevent flickering
local smoothedHungerDisplay = nil
local HUNGER_DISPLAY_LERP_SPEED = 3.0 -- How fast display catches up to actual value

-- Smoothed thirst display value (same lerp system as hunger for consistent refill animation)
local smoothedThirstDisplay = nil
local THIRST_DISPLAY_LERP_SPEED = 3.0 -- How fast display catches up to actual value

-- Smoothed anguish display value (same lerp system as hunger for consistent refill animation)
local smoothedAnguishDisplay = nil
local ANGUISH_DISPLAY_LERP_SPEED = 3.0 -- How fast display catches up to actual value

-- Update thirst meter
local function UpdateThirstMeter(elapsed)
	if not thirstMeter then
		return
	end

	local thirst = CC.GetThirst and CC.GetThirst() or 0
	local isDecaying = CC.IsThirstDecaying and CC.IsThirstDecaying() or false
	local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"

	-- Smooth the display value to prevent flickering
	local targetDisplay = 100 - thirst
	if smoothedThirstDisplay == nil then
		smoothedThirstDisplay = targetDisplay
	else
		local diff = targetDisplay - smoothedThirstDisplay
		smoothedThirstDisplay = smoothedThirstDisplay + diff * math.min(1, THIRST_DISPLAY_LERP_SPEED * elapsed)
	end
	local displayValue = smoothedThirstDisplay

	-- Update bar value (inverted: full bar = 0% thirst, empty bar = 100% thirst)
	thirstMeter.bar:SetValue(displayValue)

	-- Format percentage text
	local percentText
	if displayMode == "vial" then
		percentText = string.format("%.0f", displayValue)
	else
		percentText = string.format("%d%%", math.floor(displayValue))
	end

	-- Apply text based on hideVialText setting
	local hideText = displayMode == "vial" and CC.GetSetting("hideVialText")
	if hideText then
		thirstMeter.percent:SetText("")
		if thirstMeter.percentShadows then
			for _, shadow in ipairs(thirstMeter.percentShadows) do
				shadow:SetText("")
			end
		end
	else
		thirstMeter.percent:SetText(percentText)
		if displayMode == "vial" and thirstMeter.percentShadows then
			for _, shadow in ipairs(thirstMeter.percentShadows) do
				shadow:SetText(percentText)
			end
		end
	end

	-- Update bar color (green when drinking/decaying)
	if isDecaying then
		thirstMeter.bar:SetStatusBarColor(THIRST_DECAY_COLOR.r, THIRST_DECAY_COLOR.g, THIRST_DECAY_COLOR.b)
	else
		thirstMeter.bar:SetStatusBarColor(THIRST_COLOR.r, THIRST_COLOR.g, THIRST_COLOR.b)
	end

	-- Check if system is paused (dungeon, taxi)
	local isPaused = CC.IsThirstPaused and CC.IsThirstPaused()

	-- Check if Refreshed (fully satisfied)
	local hasRefreshed = CC.HasRefreshedBuff and CC.HasRefreshedBuff()

	-- Track thirst crossing 0.1 intervals for pulse effect
	local currentTenth = math.floor(thirst * 10)
	if currentTenth > lastThirstTenth and not isPaused and not isDecaying and not hasRefreshed then
		thirstGlowPulseTimer = THIRST_PULSE_DURATION
	end
	lastThirstTenth = currentTenth

	-- Decrease pulse timer
	if thirstGlowPulseTimer > 0 then
		thirstGlowPulseTimer = thirstGlowPulseTimer - elapsed
	end

	-- VIAL MODE: Use new glow system (blue=paused, gold=refreshed, green=recovering, orange=negative)
	if displayMode == "vial" and thirstMeter.glowGreen then
		local targetAlpha = 0
		local glowType = "none" -- "green", "orange", "blue", "gold", or "none"

		if isPaused then
			targetAlpha = 0.7
			glowType = "blue"
		elseif hasRefreshed and not isDecaying then
			targetAlpha = 0.9
			glowType = "gold"
		elseif isDecaying then
			targetAlpha = 1.0
			glowType = "green"
		elseif thirst >= 75 then
			targetAlpha = 0.8
			glowType = "orange"
		elseif thirstGlowPulseTimer > 0 then
			local pulseProgress = thirstGlowPulseTimer / THIRST_PULSE_DURATION
			targetAlpha = 0.8 * pulseProgress
			glowType = "orange"
		end

		thirstMeter.glowTargetAlpha = targetAlpha

		-- Apply pulsing effect
		if targetAlpha > 0 then
			thirstMeter.glowPulsePhase = (thirstMeter.glowPulsePhase or 0) + elapsed * 0.8
			local pulseMod = 0.7 + 0.3 * math.sin(thirstMeter.glowPulsePhase * math.pi * 2)
			thirstMeter.glowTargetAlpha = thirstMeter.glowTargetAlpha * pulseMod
		end

		-- Smooth alpha interpolation
		local alphaDiff = thirstMeter.glowTargetAlpha - (thirstMeter.glowCurrentAlpha or 0)
		if math.abs(alphaDiff) < 0.01 then
			thirstMeter.glowCurrentAlpha = thirstMeter.glowTargetAlpha
		else
			local speed = alphaDiff > 0 and 3.0 or 1.5
			thirstMeter.glowCurrentAlpha = (thirstMeter.glowCurrentAlpha or 0) + (alphaDiff * speed * elapsed)
		end
		thirstMeter.glowCurrentAlpha = math.max(0, math.min(1, thirstMeter.glowCurrentAlpha))

		local alpha = thirstMeter.glowCurrentAlpha
		thirstMeter.glowGreen:SetAlpha(glowType == "green" and alpha or 0)
		thirstMeter.glowOrange:SetAlpha(glowType == "orange" and alpha or 0)
		thirstMeter.glowBlue:SetAlpha(glowType == "blue" and alpha or 0)
		if thirstMeter.glowGold then
			thirstMeter.glowGold:SetAlpha(glowType == "gold" and alpha or 0)
		end
	else
		-- BAR MODE: Use atlas glow system
		local glow = thirstMeter.glow
		if not glow then
			return
		end

		if isPaused then
			SetGlowColor(glow, 1, 0.9, 0.3, true)
			glow.targetAlpha = 0.7
			glow.targetSize = GLOW_SIZE_PAUSED
		elseif hasRefreshed and not isDecaying then
			SetGlowColor(glow, 1.0, 0.85, 0.2, false)
			glow.targetAlpha = 0.9
			glow.targetSize = GLOW_SIZE
		elseif isDecaying then
			SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
			glow.targetAlpha = 1.0
			glow.targetSize = GLOW_SIZE
		elseif thirst >= 75 then
			SetGlowColor(glow, GLOW_RED.r, GLOW_RED.g, GLOW_RED.b, false)
			glow.targetAlpha = 0.8
			glow.targetSize = GLOW_SIZE
		elseif thirstGlowPulseTimer > 0 then
			SetGlowColor(glow, THIRST_COLOR.r, THIRST_COLOR.g, THIRST_COLOR.b, false)
			local pulseProgress = thirstGlowPulseTimer / THIRST_PULSE_DURATION
			glow.targetAlpha = 0.8 * pulseProgress
			glow.targetSize = GLOW_SIZE
		else
			glow.targetAlpha = 0
			glow.targetSize = GLOW_SIZE
		end

		-- Apply pulsing effect when glow is active
		if glow.targetAlpha > 0 then
			glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
			local pulseMod = 0.7 + 0.3 * math.sin(glow.pulsePhase * math.pi * 2)
			glow.targetAlpha = glow.targetAlpha * pulseMod
		end

		-- Smooth alpha interpolation
		local alphaDiff = glow.targetAlpha - glow.currentAlpha
		if math.abs(alphaDiff) < 0.01 then
			glow.currentAlpha = glow.targetAlpha
		else
			local speed = alphaDiff > 0 and 8.0 or 3.0
			glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
		end
		glow.currentAlpha = math.max(0, math.min(1, glow.currentAlpha))
		glow:SetAlpha(glow.currentAlpha)

		-- Size update
		if glow.targetSize < 0 then
			glow.currentSize = glow.targetSize
		else
			local sizeDiff = glow.targetSize - glow.currentSize
			if math.abs(sizeDiff) < 0.5 then
				glow.currentSize = glow.targetSize
			else
				glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
			end
		end
		UpdateGlowSize(glow, thirstMeter, glow.currentSize)
	end
end

-- Update hunger meter
local function UpdateHungerMeter(elapsed)
	if not hungerMeter then
		return
	end

	local hunger = CC.GetHunger and CC.GetHunger() or 0
	local isDecaying = CC.IsHungerDecaying and CC.IsHungerDecaying() or false
	local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"

	-- Smooth the display value to prevent flickering from exhaustion-scaled calculations
	local targetDisplay = 100 - hunger
	if smoothedHungerDisplay == nil then
		smoothedHungerDisplay = targetDisplay
	else
		-- Lerp toward target value
		local diff = targetDisplay - smoothedHungerDisplay
		smoothedHungerDisplay = smoothedHungerDisplay + diff * math.min(1, HUNGER_DISPLAY_LERP_SPEED * elapsed)
	end
	local displayValue = smoothedHungerDisplay

	-- Update bar value (inverted: full bar = 0% hunger, empty bar = 100% hunger)
	hungerMeter.bar:SetValue(displayValue)

	-- Format percentage text
	-- Both bar and vial modes show inverted value (100 = full/good, 0 = empty/bad)
	-- This matches the inverted bar display where full bar = 0% hunger
	local percentText
	if displayMode == "vial" then
		-- Vial mode: just the number (no % symbol)
		percentText = string.format("%.0f", displayValue)
	else
		-- Bar mode: integer percentage (round to nearest)
		percentText = string.format("%.0f%%", displayValue)
	end
	-- Apply text based on hideVialText setting
	local hideText = displayMode == "vial" and CC.GetSetting("hideVialText")
	if hideText then
		hungerMeter.percent:SetText("")
		if hungerMeter.percentShadows then
			for _, shadow in ipairs(hungerMeter.percentShadows) do
				shadow:SetText("")
			end
		end
	else
		hungerMeter.percent:SetText(percentText)
		if displayMode == "vial" and hungerMeter.percentShadows then
			for _, shadow in ipairs(hungerMeter.percentShadows) do
				shadow:SetText(percentText)
			end
		end
	end

	-- Update bar color (green when eating/decaying)
	if isDecaying then
		hungerMeter.bar:SetStatusBarColor(HUNGER_DECAY_COLOR.r, HUNGER_DECAY_COLOR.g, HUNGER_DECAY_COLOR.b)
	else
		hungerMeter.bar:SetStatusBarColor(HUNGER_COLOR.r, HUNGER_COLOR.g, HUNGER_COLOR.b)
	end

	-- Check if system is paused (dungeon, taxi)
	local isPaused = CC.IsHungerPaused and CC.IsHungerPaused()

	-- Check if Well Fed (fully satisfied)
	local hasWellFed = CC.HasWellFedBuff and CC.HasWellFedBuff()

	-- Track hunger crossing 0.1 intervals for pulse effect
	local currentTenth = math.floor(hunger * 10)
	if currentTenth > lastHungerTenth and not isPaused and not isDecaying and not hasWellFed then
		-- Hunger increased past a 0.1 threshold - trigger pulse
		hungerGlowPulseTimer = HUNGER_PULSE_DURATION
	end
	lastHungerTenth = currentTenth

	-- Decrease pulse timer
	if hungerGlowPulseTimer > 0 then
		hungerGlowPulseTimer = hungerGlowPulseTimer - elapsed
	end

	-- VIAL MODE: Use new glow system (blue=paused, gold=well fed, green=recovering, orange=negative)
	if displayMode == "vial" and hungerMeter.glowGreen then
		local targetAlpha = 0
		local glowType = "none" -- "green", "orange", "blue", "gold", or "none"

		if isPaused then
			targetAlpha = 0.7
			glowType = "blue"
		elseif hasWellFed and not isDecaying then
			-- Well Fed without active eating - gold glow (locked state)
			targetAlpha = 0.9
			glowType = "gold"
		elseif isDecaying then
			-- Actively eating/recovering - green glow
			targetAlpha = 1.0
			glowType = "green"
		elseif hunger >= 75 then
			targetAlpha = 0.8
			glowType = "orange"
		elseif hungerGlowPulseTimer > 0 then
			local pulseProgress = hungerGlowPulseTimer / HUNGER_PULSE_DURATION
			targetAlpha = 0.8 * pulseProgress
			glowType = "orange"
		end

		hungerMeter.glowTargetAlpha = targetAlpha

		-- Apply pulsing effect
		if targetAlpha > 0 then
			hungerMeter.glowPulsePhase = (hungerMeter.glowPulsePhase or 0) + elapsed * 0.8
			local pulseMod = 0.7 + 0.3 * math.sin(hungerMeter.glowPulsePhase * math.pi * 2)
			hungerMeter.glowTargetAlpha = hungerMeter.glowTargetAlpha * pulseMod
		end

		-- Smooth alpha interpolation
		local alphaDiff = hungerMeter.glowTargetAlpha - (hungerMeter.glowCurrentAlpha or 0)
		if math.abs(alphaDiff) < 0.01 then
			hungerMeter.glowCurrentAlpha = hungerMeter.glowTargetAlpha
		else
			local speed = alphaDiff > 0 and 3.0 or 1.5
			hungerMeter.glowCurrentAlpha = (hungerMeter.glowCurrentAlpha or 0) + (alphaDiff * speed * elapsed)
		end
		hungerMeter.glowCurrentAlpha = math.max(0, math.min(1, hungerMeter.glowCurrentAlpha))

		-- Show appropriate glow, hide others
		local alpha = hungerMeter.glowCurrentAlpha
		hungerMeter.glowGreen:SetAlpha(glowType == "green" and alpha or 0)
		hungerMeter.glowOrange:SetAlpha(glowType == "orange" and alpha or 0)
		hungerMeter.glowBlue:SetAlpha(glowType == "blue" and alpha or 0)
		if hungerMeter.glowGold then
			hungerMeter.glowGold:SetAlpha(glowType == "gold" and alpha or 0)
		end
	else
		-- BAR MODE: Use atlas glow system
		local glow = hungerMeter.glow
		if not glow then
			return
		end

		if isPaused then
			SetGlowColor(glow, 1, 0.9, 0.3, true)
			glow.targetAlpha = 0.7
			glow.targetSize = GLOW_SIZE_PAUSED
		elseif hasWellFed and not isDecaying then
			-- Well Fed without active eating - gold glow (locked state)
			SetGlowColor(glow, 1.0, 0.85, 0.2, false) -- Gold color
			glow.targetAlpha = 0.9
			glow.targetSize = GLOW_SIZE
		elseif isDecaying then
			-- Actively eating/recovering - green glow
			SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
			glow.targetAlpha = 1.0
			glow.targetSize = GLOW_SIZE
		elseif hunger >= 75 then
			SetGlowColor(glow, GLOW_RED.r, GLOW_RED.g, GLOW_RED.b, false)
			glow.targetAlpha = 0.8
			glow.targetSize = GLOW_SIZE
		elseif hungerGlowPulseTimer > 0 then
			SetGlowColor(glow, HUNGER_COLOR.r, HUNGER_COLOR.g, HUNGER_COLOR.b, false)
			local pulseProgress = hungerGlowPulseTimer / HUNGER_PULSE_DURATION
			glow.targetAlpha = 0.8 * pulseProgress
			glow.targetSize = GLOW_SIZE
		else
			glow.targetAlpha = 0
			glow.targetSize = GLOW_SIZE
		end

		-- Apply pulsing effect when glow is active
		if glow.targetAlpha > 0 then
			glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
			local pulseMod = 0.7 + 0.3 * math.sin(glow.pulsePhase * math.pi * 2)
			glow.targetAlpha = glow.targetAlpha * pulseMod
		end

		-- Smooth alpha interpolation
		local alphaDiff = glow.targetAlpha - glow.currentAlpha
		if math.abs(alphaDiff) < 0.01 then
			glow.currentAlpha = glow.targetAlpha
		else
			local speed = alphaDiff > 0 and 8.0 or 3.0
			glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
		end
		glow.currentAlpha = math.max(0, math.min(1, glow.currentAlpha))
		glow:SetAlpha(glow.currentAlpha)

		-- Size update: snap immediately to paused size, interpolate others
		if glow.targetSize < 0 then
			-- Paused state: snap immediately to avoid large glow flash
			glow.currentSize = glow.targetSize
		else
			-- Normal state: smooth interpolation
			local sizeDiff = glow.targetSize - glow.currentSize
			if math.abs(sizeDiff) < 0.5 then
				glow.currentSize = glow.targetSize
			else
				glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
			end
		end
		UpdateGlowSize(glow, hungerMeter, glow.currentSize)
	end
end

-- Setup hunger meter tooltip
local function SetupHungerTooltip(meter)
	-- Use hitbox for vial meters, otherwise use meter itself
	local tooltipTarget = meter.hitbox or meter
	tooltipTarget:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

		-- Get state for title
		local h = CC.GetHunger and CC.GetHunger() or 0
		local isPaused = CC.IsHungerPaused and CC.IsHungerPaused()
		local isDecaying = CC.IsHungerDecaying and CC.IsHungerDecaying()
		local hasWellFed = CC.HasWellFedBuff and CC.HasWellFedBuff()
		local checkpoint = CC.GetHungerCheckpoint and CC.GetHungerCheckpoint() or 50
		local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"
		local activity = CC.GetHungerActivity and CC.GetHungerActivity()
		local isEating = activity == "Eating"
		local isVial = displayMode == "vial"

		-- Title with state
		if isPaused then
			GameTooltip:SetText("Hunger - Paused", 0.5, 0.7, 1.0)
		elseif isDecaying then
			GameTooltip:SetText("Hunger - Idle", CC.COLORS.WARNING)
		elseif isEating then
			GameTooltip:SetText("Hunger - Eating", CC.COLORS.SUCCESS)
		elseif hasWellFed then
			GameTooltip:SetText("Hunger - Well Fed", 0.2, 1.0, 0.3)
		else
			GameTooltip:SetText("Hunger", 0.9, 0.6, 0.2)
		end

		-- Show value appropriate to display mode
		if isVial then
			GameTooltip:AddLine(string.format("Satiation: %.0f%% (Hunger: %.1f%%)", 100 - h, h), 1, 1, 1)
			GameTooltip:AddLine(string.format("Can eat to: %d%% satiation", checkpoint), 0.7, 0.7, 0.7)
		else
			GameTooltip:AddLine(string.format("Current: %.0f%%", h), 1, 1, 1)
			GameTooltip:AddLine(string.format("Checkpoint: %d%%", checkpoint), 0.7, 0.7, 0.7)
		end

		-- Show current activity (both minimal and detailed)
		if activity then
			local actR, actG, actB = 0.7, 0.7, 0.7
			if activity == "Eating" or activity == "Well Fed" or activity == "Resting (Well Fed)" or activity == "Recovering" then
				actR, actG, actB = 0.2, 1.0, 0.3 -- Green for recovery/good
			elseif activity == "In combat" then
				actR, actG, actB = 1.0, 0.4, 0.4 -- Red for combat
			elseif activity == "Running" or activity == "Swimming" then
				actR, actG, actB = 1.0, 0.8, 0.4 -- Yellow for high drain
			elseif activity == "Walking" or activity == "Mounted" or activity == "Idle" then
				actR, actG, actB = 0.8, 0.8, 0.6 -- Pale yellow for low drain
			end
			GameTooltip:AddLine("Activity: " .. activity, actR, actG, actB)
		end

		-- Detailed mode only: show drains, recovery, checkpoints, and pause conditions
		if tooltipMode == "detailed" then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Drains from:", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("  Movement (walking, running, mounted)", 0.6, 0.7, 0.8)
			GameTooltip:AddLine("  Combat: faster drain", 0.8, 0.6, 0.6)

			-- Only show scaling info if those systems are enabled
			local tempEnabled = CC.GetSetting and CC.GetSetting("temperatureEnabled")
			local exhaustEnabled = CC.GetSetting and CC.GetSetting("exhaustionEnabled")
			if tempEnabled then
				GameTooltip:AddLine("  Cold temperatures: faster drain", 0.5, 0.7, 1.0)
			end
			if exhaustEnabled then
				GameTooltip:AddLine("  Scales with exhaustion", 0.7, 0.7, 0.7)
			end

			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Recovery:", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("  Eating food: restores satiation", 0.6, 0.8, 0.6)
			GameTooltip:AddLine("  Well Fed buff: stops drain", 0.4, 1, 0.4)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Checkpoints:", 1, 0.7, 0.4)
			if isVial then
				GameTooltip:AddLine("  Open world: can eat to 25% satiation", 0.7, 0.6, 0.5)
				GameTooltip:AddLine("  Near fire: can eat to 50% satiation", 0.9, 0.6, 0.3)
				GameTooltip:AddLine("  Rested area: can eat to 75% satiation", 0.6, 0.8, 0.6)
				if CC.GetSetting("innkeeperResetsHunger") then
					GameTooltip:AddLine("  Innkeeper: heals up to 85% satiation", 0.4, 1, 0.4)
				end
				GameTooltip:AddLine("  Cooking trainer: fully restores", 0.4, 1, 0.4)
			else
				GameTooltip:AddLine("  Open world: can eat to 25%", 0.7, 0.6, 0.5)
				GameTooltip:AddLine("  Near fire: can eat to 50%", 0.9, 0.6, 0.3)
				GameTooltip:AddLine("  Rested area: can eat to 75%", 0.6, 0.8, 0.6)
				GameTooltip:AddLine("  Cooking trainer: resets to 0%", 0.4, 1, 0.4)
			end
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
			GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
		end
		GameTooltip:Show()
	end)
	tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

-- Vial meter constants (styled like constitution orb)
local VIAL_SCALE = 0.75 -- Scale down vials by 25%
local VIAL_SIZE_BASE = 62 -- Base orb size before scaling
local VIAL_SIZE = VIAL_SIZE_BASE * VIAL_SCALE -- Scaled orb size (46.5)
local VIAL_SPACING = -32 -- Negative to bring vials closer together
local VIAL_DISPLAY_SIZE_BASE = 120 -- Base vial overlay size before scaling
local VIAL_DISPLAY_SIZE = VIAL_DISPLAY_SIZE_BASE * VIAL_SCALE -- Scaled vial overlay (90)
local VIAL_Y_OFFSET = -7 * VIAL_SCALE -- Scaled offset
local VIAL_FRAME_WIDTH = (VIAL_SIZE_BASE + 60) * VIAL_SCALE -- Frame width (91.5)
local VIAL_FRAME_HEIGHT = (VIAL_SIZE_BASE + 90) * VIAL_SCALE -- Frame height (114)

-- Create a vial-style meter (vertical potion bottle - styled like constitution orb)
local function CreateVialMeter(name, parent, xOffset, color, vialTexturePath, fillTexturePath)
	local meter = CreateFrame("Frame", "CozierCamps" .. name .. "VialMeter", parent)
	meter:SetSize(VIAL_FRAME_WIDTH, VIAL_FRAME_HEIGHT) -- Use pre-calculated scaled frame size
	meter:SetPoint("LEFT", parent, "LEFT", xOffset, 0)

	-- Glow frame (behind everything) - 3 layers like constitution orb
	meter.glowFrame = CreateFrame("Frame", nil, meter)
	meter.glowFrame:SetAllPoints()
	meter.glowFrame:SetFrameLevel(meter:GetFrameLevel())
	meter.glowFrame:EnableMouse(false) -- Allow mouse events to pass through

	local GLOW_Y_OFFSET = VIAL_Y_OFFSET -- Aligned with fill (no extra offset)

	-- Glow size - use CircleGlow atlas for all (it works and scales well)
	local VIAL_GLOW_SIZE = VIAL_SIZE * 1.5 -- Scale glow to cover the orb nicely

	-- Green glow (positive/improving) - CircleGlow desaturated and tinted bright green
	meter.glowGreen = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	meter.glowGreen:SetSize(VIAL_GLOW_SIZE, VIAL_GLOW_SIZE)
	meter.glowGreen:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
	meter.glowGreen:SetAtlas("ChallengeMode-Runes-CircleGlow")
	meter.glowGreen:SetDesaturated(true) -- Remove blue, make it grayscale
	meter.glowGreen:SetVertexColor(0.2, 1.0, 0.3, 1) -- Bright green tint
	meter.glowGreen:SetBlendMode("ADD")
	meter.glowGreen:SetAlpha(0)

	-- Orange glow (negative/declining) - CircleGlow desaturated and tinted orange
	meter.glowOrange = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	meter.glowOrange:SetSize(VIAL_GLOW_SIZE, VIAL_GLOW_SIZE)
	meter.glowOrange:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
	meter.glowOrange:SetAtlas("ChallengeMode-Runes-CircleGlow")
	meter.glowOrange:SetDesaturated(true) -- Remove blue, make it grayscale
	meter.glowOrange:SetVertexColor(1.0, 0.4, 0.05, 1) -- Orange tint
	meter.glowOrange:SetBlendMode("ADD")
	meter.glowOrange:SetAlpha(0)

	-- Blue glow (paused) - CircleGlow (natural blue, no tint needed)
	meter.glowBlue = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 3)
	meter.glowBlue:SetSize(VIAL_GLOW_SIZE, VIAL_GLOW_SIZE)
	meter.glowBlue:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
	meter.glowBlue:SetAtlas("ChallengeMode-Runes-CircleGlow")
	meter.glowBlue:SetBlendMode("ADD")
	meter.glowBlue:SetAlpha(0)

	-- Gold glow (Well Fed/locked state) - CircleGlow desaturated and tinted gold
	meter.glowGold = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 4)
	meter.glowGold:SetSize(VIAL_GLOW_SIZE, VIAL_GLOW_SIZE)
	meter.glowGold:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
	meter.glowGold:SetAtlas("ChallengeMode-Runes-CircleGlow")
	meter.glowGold:SetDesaturated(true)
	meter.glowGold:SetVertexColor(1.0, 0.85, 0.2, 1) -- Bright gold tint
	meter.glowGold:SetBlendMode("ADD")
	meter.glowGold:SetAlpha(0)

	-- Legacy references for compatibility (point to green glow by default)
	meter.glow1 = meter.glowGreen
	meter.glow2 = meter.glowGreen
	meter.glow3 = meter.glowGreen

	-- Glow state tracking
	meter.glowCurrentAlpha = 0
	meter.glowTargetAlpha = 0
	meter.glowPulsePhase = math.random() * math.pi * 2
	meter.glowIsGreen = true
	meter.glowState = "green" -- "green", "orange", "blue", or "gold"

	-- Orb visual size (scaled down 7% total to show more vial edges)
	local ORB_VISUAL_SIZE = VIAL_SIZE * 0.93

	-- Background (dark orb shape)
	meter.orbBg = meter:CreateTexture(nil, "BACKGROUND", nil, 1)
	meter.orbBg:SetSize(ORB_VISUAL_SIZE, ORB_VISUAL_SIZE)
	meter.orbBg:SetPoint("CENTER", 0, VIAL_Y_OFFSET)
	meter.orbBg:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\globered.png")
	meter.orbBg:SetVertexColor(0.1, 0.1, 0.1, 0.9)

	-- Fill bar (vertical StatusBar) - use custom fill texture per meter type
	meter.fillBar = CreateFrame("StatusBar", nil, meter)
	meter.fillBar:SetSize(ORB_VISUAL_SIZE, ORB_VISUAL_SIZE)
	meter.fillBar:SetPoint("CENTER", 0, VIAL_Y_OFFSET)
	meter.fillBar:SetOrientation("VERTICAL")
	meter.fillBar:SetMinMaxValues(0, 100)
	meter.fillBar:SetValue(0)
	local fillTex = fillTexturePath or "Interface\\AddOns\\CozierCamps\\assets\\globetextured.png"
	meter.fillBar:SetStatusBarTexture(fillTex)
	meter.fillBar:SetStatusBarColor(color.r, color.g, color.b, 0.95)
	meter.fillBar:SetFrameLevel(meter:GetFrameLevel() + 1)
	meter.fillBar:EnableMouse(false) -- Allow mouse events to pass through to parent for tooltip

	-- Vial overlay frame (must be higher frame level than fillBar to appear on top)
	meter.vialOverlayFrame = CreateFrame("Frame", nil, meter)
	meter.vialOverlayFrame:SetAllPoints()
	meter.vialOverlayFrame:SetFrameLevel(meter.fillBar:GetFrameLevel() + 2)
	meter.vialOverlayFrame:EnableMouse(false) -- Allow mouse events to pass through

	-- Vial overlay (potion bottle texture)
	-- Custom potion images are 128x128 but need to maintain proper aspect ratio
	meter.vialOverlay = meter.vialOverlayFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	meter.vialOverlay:SetSize(VIAL_DISPLAY_SIZE, VIAL_DISPLAY_SIZE)
	meter.vialOverlay:SetPoint("CENTER", meter, "CENTER", 0, VIAL_DISPLAY_SIZE * 0.10)
	meter.vialOverlay:SetTexture(vialTexturePath)
	-- No tint - custom potions have their own colors
	meter.vialOverlay:SetVertexColor(1, 1, 1, 1)

	-- Store the color for later use
	meter.meterColor = color

	-- Text frame for percentage (above fill bar for visibility)
	meter.textFrame = CreateFrame("Frame", nil, meter)
	meter.textFrame:SetAllPoints()
	meter.textFrame:SetFrameLevel(meter.fillBar:GetFrameLevel() + 10)
	meter.textFrame:EnableMouse(false) -- Allow mouse events to pass through to parent

	-- Create shadow texts (multiple offsets for thick shadow like constitution orb)
	meter.percentShadows = {}
	local shadowOffsets = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
	local fontPath = GetBarFont()
	local fontSize = 10 * VIAL_SCALE -- Scale font size too
	for _, offset in ipairs(shadowOffsets) do
		local shadow = meter.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		shadow:SetPoint("CENTER", offset[1], offset[2] + VIAL_Y_OFFSET)
		shadow:SetText("0")
		shadow:SetTextColor(0, 0, 0, 1)
		if fontPath then
			shadow:SetFont(fontPath, fontSize, "OUTLINE")
		end
		table.insert(meter.percentShadows, shadow)
	end

	-- Main percentage text
	meter.percent = meter.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	meter.percent:SetPoint("CENTER", 0, VIAL_Y_OFFSET)
	meter.percent:SetText("0")
	meter.percent:SetTextColor(1, 1, 1, 1)
	if fontPath then
		meter.percent:SetFont(fontPath, fontSize, "OUTLINE")
	end

	-- Reference to the bar for compatibility with update functions
	meter.bar = meter.fillBar

	-- State tracking
	meter.currentFillLevel = 0
	meter.targetFillLevel = 0

	-- Create a hitbox frame on TOP of everything for tooltip and drag
	-- This ensures mouse events work regardless of other frame layers
	meter.hitbox = CreateFrame("Frame", nil, meter)
	-- Use VIAL_SIZE for width to prevent hitbox overlap with adjacent vials
	local hitboxWidth = VIAL_SIZE + 10 -- Slightly larger than orb but not overlapping neighbors
	meter.hitbox:SetSize(hitboxWidth, VIAL_DISPLAY_SIZE) -- Width prevents overlap, height covers full vial
	meter.hitbox:SetPoint("CENTER", 0, VIAL_DISPLAY_SIZE * 0.10) -- Match vial overlay position
	meter.hitbox:SetFrameLevel(meter.textFrame:GetFrameLevel() + 5) -- Above everything
	meter.hitbox:EnableMouse(true)

	-- Store reference to parent for tooltip and drag scripts
	meter.hitbox.parentMeter = meter

	-- Dragging support (on hitbox)
	meter.hitbox:RegisterForDrag("LeftButton")
	meter.hitbox:SetScript("OnDragStart", function()
		StartMovingMetersContainer()
	end)
	meter.hitbox:SetScript("OnDragStop", function()
		if metersContainer then
			metersContainer:StopMovingOrSizing()
			-- Save absolute screen coordinates of top-left corner for consistent placement
			if not CC.GetSetting("metersLocked") then
				local left = metersContainer:GetLeft()
				local top = metersContainer:GetTop()
				if CC.db and left and top then
					CC.db.meterPosition = {
						screenLeft = left,
						screenTop = top
					}
				end
			end
		end
	end)

	-- Also enable mouse on parent for fallback
	meter:EnableMouse(true)
	meter:RegisterForDrag("LeftButton")
	meter:SetScript("OnDragStart", function()
		StartMovingMetersContainer()
	end)
	meter:SetScript("OnDragStop", function()
		if metersContainer then
			metersContainer:StopMovingOrSizing()
		end
	end)

	return meter
end

-- Create temperature meter (bidirectional, center-starting)
local function CreateTemperatureMeter(parent, yOffset)
	local meter = CreateFrame("Frame", "CozierCampsTemperatureMeter", parent, "BackdropTemplate")
	meter:SetSize(TEMP_METER_WIDTH, METER_HEIGHT)
	meter:SetPoint("TOP", parent, "TOP", 0, yOffset)

	-- Background with shadow effect
	meter:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		insets = {
			left = 2,
			right = 2,
			top = 2,
			bottom = 2
		}
	})
	meter:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	meter:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	-- Create gradient background (cold on left, hot on right)
	local barWidth = TEMP_METER_WIDTH - (METER_PADDING * 2)
	local barHeight = METER_HEIGHT - (METER_PADDING * 2)

	-- Left side gradient (cold - blue)
	meter.coldBar = meter:CreateTexture(nil, "ARTWORK")
	meter.coldBar:SetPoint("LEFT", meter, "LEFT", METER_PADDING, 0)
	meter.coldBar:SetSize(barWidth / 2, barHeight)
	meter.coldBar:SetTexture(GetBarTexture())
	meter.coldBar:SetVertexColor(TEMP_COLD_LIGHT.r, TEMP_COLD_LIGHT.g, TEMP_COLD_LIGHT.b, 0.3)

	-- Right side gradient (hot - orange/yellow)
	meter.hotBar = meter:CreateTexture(nil, "ARTWORK")
	meter.hotBar:SetPoint("RIGHT", meter, "RIGHT", -METER_PADDING, 0)
	meter.hotBar:SetSize(barWidth / 2, barHeight)
	meter.hotBar:SetTexture(GetBarTexture())
	meter.hotBar:SetVertexColor(TEMP_HOT_LIGHT.r, TEMP_HOT_LIGHT.g, TEMP_HOT_LIGHT.b, 0.3)

	-- Center line (neutral marker)
	meter.centerLine = meter:CreateTexture(nil, "OVERLAY", nil, 5)
	meter.centerLine:SetSize(2, barHeight + 4)
	meter.centerLine:SetPoint("CENTER", meter, "CENTER", 0, 0)
	meter.centerLine:SetColorTexture(1, 1, 1, 0.5)

	-- Fill bar (shows current temperature level from center)
	meter.fillBar = meter:CreateTexture(nil, "ARTWORK", nil, 1)
	meter.fillBar:SetTexture(GetBarTexture())
	meter.fillBar:SetHeight(barHeight)
	meter.fillBar:SetPoint("LEFT", meter, "CENTER", 0, 0)
	meter.fillBar:SetWidth(1) -- Will be updated dynamically

	-- Moving spark indicator - switches atlas based on hot/cold side
	meter.arrow = meter:CreateTexture(nil, "OVERLAY", nil, 7)
	meter.arrow:SetSize(TEMP_ARROW_SIZE * 0.5, TEMP_ARROW_SIZE * 1.5) -- Reduced width by 33%
	meter.arrow:SetPoint("CENTER", meter, "CENTER", 0, 0)
	meter.arrow:SetAtlas("bonusobjectives-bar-spark") -- Default to cold spark
	meter.arrow:SetBlendMode("ADD") -- Removes black background, creates glow effect

	-- Cold icon on the left side (10% smaller)
	local coldIconSize = ICON_SIZE * 0.9
	local coldIcon = "Interface\\AddOns\\CozierCamps\\assets\\coldicon.blp"
	meter.coldIcon = meter:CreateTexture(nil, "OVERLAY", nil, 7)
	meter.coldIcon:SetSize(coldIconSize, coldIconSize)
	meter.coldIcon:SetPoint("LEFT", meter, "LEFT", METER_PADDING + 2, 0)
	meter.coldIcon:SetTexture(coldIcon)
	meter.coldIcon:SetVertexColor(0.6, 0.8, 1.0, 1) -- Slight blue tint
	meter.coldIconPulse = 0 -- For pulsing animation

	-- Fire icon on the right side (21% larger - increased by 10%)
	local fireIconSize = ICON_SIZE * 1.21
	local fireIcon = "Interface\\AddOns\\CozierCamps\\assets\\fireicon.blp"
	meter.fireIcon = meter:CreateTexture(nil, "OVERLAY", nil, 7)
	meter.fireIcon:SetSize(fireIconSize, fireIconSize)
	meter.fireIcon:SetPoint("RIGHT", meter, "RIGHT", -METER_PADDING - 2, 0)
	meter.fireIcon:SetTexture(fireIcon)
	meter.fireIcon:SetVertexColor(1.0, 0.8, 0.5, 1) -- Warm tint
	meter.fireIconPulse = 0 -- For pulsing animation

	-- Glow frame for cold (blue) - EXACT same as paused glow on exhaustion/anguish
	meter.coldGlow = CreateFrame("Frame", nil, meter)
	meter.coldGlow:SetFrameLevel(meter:GetFrameLevel() + 10)
	meter.coldGlow:EnableMouse(false) -- Allow mouse events to pass through for tooltip
	-- Use exact same padding calculation as paused glow: GLOW_SIZE_PAUSED (-12) + 8 = -4
	local coldGlowPadding = GLOW_SIZE_PAUSED + 8 -- = -4
	meter.coldGlow:SetPoint("TOPLEFT", meter, "TOPLEFT", 0, coldGlowPadding + 6) -- (0, 2)
	meter.coldGlow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", 0, -coldGlowPadding - 6) -- (0, -2)
	meter.coldGlow.texture = meter.coldGlow:CreateTexture(nil, "ARTWORK")
	meter.coldGlow.texture:SetAllPoints()
	meter.coldGlow.texture:SetAtlas(ATLAS_PAUSED)
	meter.coldGlow.texture:SetVertexColor(0.3, 0.5, 1.0) -- Blue tint
	meter.coldGlow.texture:SetBlendMode("ADD")
	meter.coldGlow:SetAlpha(0)
	meter.coldGlow.currentAlpha = 0
	meter.coldGlow.targetAlpha = 0
	meter.coldGlow.pulsePhase = 0
	meter.coldGlow.currentSize = GLOW_SIZE_PAUSED

	-- Glow frame for hot (orange) - uses Anguish-style red atlas
	meter.hotGlow = CreateFrame("Frame", nil, meter)
	meter.hotGlow:SetFrameLevel(meter:GetFrameLevel() + 10)
	meter.hotGlow:EnableMouse(false) -- Allow mouse events to pass through for tooltip
	-- Use same padding as Anguish meter glow
	local hotGlowPadding = GLOW_SIZE + 8
	meter.hotGlow:SetPoint("TOPLEFT", meter, "TOPLEFT", -hotGlowPadding, hotGlowPadding + 1)
	meter.hotGlow:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", hotGlowPadding, -hotGlowPadding - 1)
	meter.hotGlow.texture = meter.hotGlow:CreateTexture(nil, "ARTWORK")
	meter.hotGlow.texture:SetAllPoints()
	meter.hotGlow.texture:SetAtlas(ATLAS_RED) -- Same atlas as Anguish meter
	meter.hotGlow.texture:SetVertexColor(1.0, 0.6, 0.2) -- Orange tint
	meter.hotGlow.texture:SetBlendMode("ADD")
	meter.hotGlow:SetAlpha(0)
	meter.hotGlow.currentAlpha = 0
	meter.hotGlow.targetAlpha = 0
	meter.hotGlow.pulsePhase = 0
	meter.hotGlow.currentSize = GLOW_SIZE

	-- Store current bar color for arrow matching
	meter.currentBarR = 0.5
	meter.currentBarG = 0.5
	meter.currentBarB = 0.5

	-- Percentage text (hidden for now - icons indicate hot/cold)
	meter.percent = meter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	local fontPath = GetBarFont()
	if fontPath then
		meter.percent:SetFont(fontPath, 10, "OUTLINE")
	end
	meter.percent:SetPoint("RIGHT", meter, "RIGHT", -METER_PADDING - 2, 0)
	meter.percent:SetText("0")
	meter.percent:SetTextColor(1, 1, 1, 0.9)
	meter.percent:Hide() -- Hidden for now

	-- Enable mouse for tooltip and drag forwarding
	meter:EnableMouse(true)
	meter:RegisterForDrag("LeftButton")
	meter:SetScript("OnDragStart", function()
		StartMovingMetersContainer()
	end)
	meter:SetScript("OnDragStop", function()
		if metersContainer then
			metersContainer:StopMovingOrSizing()
			-- Save absolute screen coordinates of top-left corner for consistent placement
			if not CC.GetSetting("metersLocked") then
				local left = metersContainer:GetLeft()
				local top = metersContainer:GetTop()
				if CC.db and left and top then
					CC.db.meterPosition = {
						screenLeft = left,
						screenTop = top
					}
				end
			end
		end
	end)

	-- Create a hitbox frame on TOP of everything for tooltip and drag
	-- This ensures mouse events work regardless of glow frame layers
	meter.hitbox = CreateFrame("Frame", nil, meter)
	-- Temperature meter is always a bar (even in vial mode), so use bar dimensions
	-- Add some padding for easier mouse interaction
	meter.hitbox:SetSize(TEMP_METER_WIDTH + 10, METER_HEIGHT + 10)
	meter.hitbox:SetPoint("CENTER", 0, 0)
	meter.hitbox:SetFrameLevel(meter:GetFrameLevel() + 15) -- Above all glows
	meter.hitbox:EnableMouse(true)
	meter.hitbox.parentMeter = meter

	-- Dragging support (on hitbox)
	meter.hitbox:RegisterForDrag("LeftButton")
	meter.hitbox:SetScript("OnDragStart", function()
		StartMovingMetersContainer()
	end)
	meter.hitbox:SetScript("OnDragStop", function()
		if metersContainer then
			metersContainer:StopMovingOrSizing()
			-- Save absolute screen coordinates of top-left corner for consistent placement
			if not CC.GetSetting("metersLocked") then
				local left = metersContainer:GetLeft()
				local top = metersContainer:GetTop()
				if CC.db and left and top then
					CC.db.meterPosition = {
						screenLeft = left,
						screenTop = top
					}
				end
			end
		end
	end)

	return meter
end

-- Resize temperature meter to a new width (for vial mode)
local function ResizeTemperatureMeter(meter, newWidth)
	if not meter then
		return
	end

	local barWidth = newWidth - (METER_PADDING * 2)
	local barHeight = METER_HEIGHT - (METER_PADDING * 2)

	-- Resize the main frame
	meter:SetWidth(newWidth)

	-- Resize the cold and hot background bars
	if meter.coldBar then
		meter.coldBar:SetSize(barWidth / 2, barHeight)
	end
	if meter.hotBar then
		meter.hotBar:SetSize(barWidth / 2, barHeight)
	end

	-- Reposition the milestone notches (at 50% on each side)
	if meter.leftNotch then
		meter.leftNotch:ClearAllPoints()
		meter.leftNotch:SetPoint("CENTER", meter, "CENTER", -(barWidth / 4), 0)
	end
	if meter.rightNotch then
		meter.rightNotch:ClearAllPoints()
		meter.rightNotch:SetPoint("CENTER", meter, "CENTER", (barWidth / 4), 0)
	end

	-- Resize the hitbox to match the new bar width
	if meter.hitbox then
		meter.hitbox:SetSize(newWidth + 10, METER_HEIGHT + 10)
	end
end

-- Setup thirst meter tooltip
local function SetupThirstTooltip(meter)
	local tooltipTarget = meter.hitbox or meter
	tooltipTarget:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

		local t = CC.GetThirst and CC.GetThirst() or 0
		local isPaused = CC.IsThirstPaused and CC.IsThirstPaused()
		local isDecaying = CC.IsThirstDecaying and CC.IsThirstDecaying()
		local hasRefreshed = CC.HasRefreshedBuff and CC.HasRefreshedBuff()
		local checkpoint = CC.GetThirstCheckpoint and CC.GetThirstCheckpoint() or 50
		local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"
		local isVial = displayMode == "vial"

		if isPaused then
			GameTooltip:SetText("Thirst - Paused", 0.5, 0.7, 1.0)
		elseif isDecaying then
			local activity = CC.GetThirstActivity and CC.GetThirstActivity()
			if activity == "Swimming" then
				GameTooltip:SetText("Thirst - Swimming", 0.2, 1.0, 0.3)
			elseif activity == "In Rain" then
				GameTooltip:SetText("Thirst - In Rain", 0.2, 1.0, 0.3)
			else
				GameTooltip:SetText("Thirst - Drinking", 0.2, 1.0, 0.3)
			end
		elseif hasRefreshed then
			GameTooltip:SetText("Thirst - Refreshed", 0.2, 1.0, 0.3)
		else
			GameTooltip:SetText("Thirst", 0.4, 0.7, 1.0)
		end

		if isVial then
			GameTooltip:AddLine(string.format("Hydration: %.0f%% (Thirst: %.1f%%)", 100 - t, t), 1, 1, 1)
			GameTooltip:AddLine(string.format("Can drink to: %d%% hydration", 100 - checkpoint), 0.7, 0.7, 0.7)
		else
			GameTooltip:AddLine(string.format("Current: %.1f%%", t), 1, 1, 1)
			GameTooltip:AddLine(string.format("Checkpoint: %d%%", checkpoint), 0.7, 0.7, 0.7)
		end

		local activity = CC.GetThirstActivity and CC.GetThirstActivity()
		if activity then
			local actR, actG, actB = 0.7, 0.7, 0.7
			if activity == "Drinking" or activity == "Refreshed" or activity == "Resting (Refreshed)" or activity ==
					"Recovering" or activity == "Swimming" or activity == "In Rain" then
				actR, actG, actB = 0.2, 1.0, 0.3
			elseif activity == "In combat" then
				actR, actG, actB = 1.0, 0.4, 0.4
			elseif activity == "Running" then
				actR, actG, actB = 1.0, 0.8, 0.4
			elseif activity == "Walking" or activity == "Mounted" then
				actR, actG, actB = 0.8, 0.8, 0.6
			end
			GameTooltip:AddLine("Activity: " .. activity, actR, actG, actB)
		end

		if tooltipMode == "detailed" then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Drains from:", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("  Movement (walking, running, mounted)", 0.6, 0.7, 0.8)
			GameTooltip:AddLine("  Combat: faster drain", 0.8, 0.6, 0.6)
			local tempEnabled = CC.GetSetting and CC.GetSetting("temperatureEnabled")
			if tempEnabled then
				GameTooltip:AddLine("  Hot temperatures: faster drain", 1.0, 0.5, 0.3)
			end

			local exhaustEnabled = CC.GetSetting and CC.GetSetting("exhaustionEnabled")
			if exhaustEnabled then
				GameTooltip:AddLine("  Scales with exhaustion", 0.7, 0.7, 0.7)
			end

			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Recovery:", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("  Drinking: restores hydration", 0.6, 0.8, 0.6)
			GameTooltip:AddLine("  Rain: very slow recovery", 0.5, 0.7, 1.0)
			GameTooltip:AddLine("  Swimming: extremely slow recovery", 0.4, 0.6, 0.9)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Checkpoints:", 0.4, 0.7, 1.0)
			if isVial then
				GameTooltip:AddLine("  Open world: can drink to 25% hydration", 0.7, 0.6, 0.5)
				GameTooltip:AddLine("  Near fire: can drink to 50% hydration", 0.9, 0.6, 0.3)
				GameTooltip:AddLine("  Rested area: can drink to 75% hydration", 0.6, 0.8, 0.6)
				if CC.GetSetting and CC.GetSetting("innkeeperResetsThirst") then
					GameTooltip:AddLine("  Innkeeper: heals up to 85% hydration", 0.4, 1, 0.4)
				end
				GameTooltip:AddLine("  Cooking trainer: fully restores", 0.4, 1, 0.4)
			else
				GameTooltip:AddLine("  Open world: can drink to 75%", 0.7, 0.6, 0.5)
				GameTooltip:AddLine("  Near fire: can drink to 50%", 0.9, 0.6, 0.3)
				GameTooltip:AddLine("  Rested area: can drink to 25%", 0.6, 0.8, 0.6)
				GameTooltip:AddLine("  Cooking trainer: resets to 0%", 0.4, 1, 0.4)
			end
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Paused while:", 0.7, 0.7, 0.7)
			GameTooltip:AddLine("  On a flight path", 0.5, 0.6, 0.5)
			GameTooltip:AddLine("  In a dungeon or raid", 0.5, 0.6, 0.5)
		end

		GameTooltip:Show()
	end)
	tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

-- Setup temperature meter tooltip
local function SetupTemperatureTooltip(meter)
	-- Use hitbox for vial meters, otherwise use meter itself
	local tooltipTarget = meter.hitbox or meter
	tooltipTarget:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end

		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

		-- Get current state
		local temp = CC.GetTemperature and CC.GetTemperature() or 0
		local isPaused = CC.IsTemperaturePaused and CC.IsTemperaturePaused()
		local isBalanced = CC.IsTemperatureBalanced and CC.IsTemperatureBalanced()
		local isRecovering = CC.IsTemperatureRecovering and CC.IsTemperatureRecovering()
		local envTemp, baseTemp = 20, 20
		if CC.GetEnvironmentalTemperature then
			envTemp, baseTemp = CC.GetEnvironmentalTemperature()
		end
		local equilibrium = CC.GetTemperatureEquilibrium and CC.GetTemperatureEquilibrium() or 0

		-- Determine status text and color
		local status = "Neutral"
		local r, g, b = 0.7, 0.7, 0.7
		if temp < -50 then
			status = "Freezing"
			r, g, b = 0.3, 0.5, 1.0
		elseif temp < -20 then
			status = "Cold"
			r, g, b = 0.5, 0.7, 1.0
		elseif temp < -5 then
			status = "Chilly"
			r, g, b = 0.6, 0.8, 1.0
		elseif temp > 50 then
			status = "Scorching"
			r, g, b = 1.0, 0.4, 0.1
		elseif temp > 20 then
			status = "Hot"
			r, g, b = 1.0, 0.6, 0.3
		elseif temp > 5 then
			status = "Warm"
			r, g, b = 1.0, 0.8, 0.5
		end

		-- Title with state
		if isPaused then
			GameTooltip:SetText("Temperature - Paused", 0.5, 0.7, 1.0)
		elseif isBalanced then
			GameTooltip:SetText("Temperature - Balanced", 0.2, 1.0, 0.3)
		elseif isRecovering then
			GameTooltip:SetText("Temperature - Recovering", 0.2, 1.0, 0.3)
		else
			GameTooltip:SetText("Temperature", 0.9, 0.9, 0.5)
		end

		-- Trend info (at top for visibility)
		local trend = CC.GetTemperatureTrend and CC.GetTemperatureTrend() or 0
		local trendText, trendR, trendG, trendB
		if isBalanced then
			trendText = "Stable"
			trendR, trendG, trendB = 0.2, 1.0, 0.3
		elseif isRecovering then
			trendText = "Recovering"
			trendR, trendG, trendB = 0.2, 1.0, 0.3
		elseif trend > 0 then
			trendText = "Warming"
			trendR, trendG, trendB = 1.0, 0.7, 0.4
		elseif trend < 0 then
			trendText = "Cooling"
			trendR, trendG, trendB = 0.5, 0.7, 1.0
		else
			trendText = "Stable"
			trendR, trendG, trendB = 0.7, 0.7, 0.7
		end
		GameTooltip:AddLine("Trend: " .. trendText, trendR, trendG, trendB)

		-- Current temperature status
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(string.format("Current: %.0f (%s)", temp, status), r, g, b)

		-- Target equilibrium with color coding
		local eqR, eqG, eqB = 0.7, 0.7, 0.7
		local eqLabel = "Target"
		if equilibrium < -30 then
			eqR, eqG, eqB = 0.5, 0.7, 1.0 -- Blue for cold
			eqLabel = "Target (Cold)"
		elseif equilibrium > 30 then
			eqR, eqG, eqB = 1.0, 0.7, 0.4 -- Orange for hot
			eqLabel = "Target (Hot)"
		else
			eqLabel = "Target (Comfortable)"
			eqR, eqG, eqB = 0.3, 1.0, 0.4 -- Green for comfortable
		end
		GameTooltip:AddLine(string.format("%s: %.0f", eqLabel, equilibrium), eqR, eqG, eqB)

		-- Active modifiers section (shown in both minimal and detailed)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Active Modifiers:", 1, 0.9, 0.5)
		if CC.GetTemperatureEffects then
			local effects = CC.GetTemperatureEffects()
			if effects and #effects > 0 then
				for _, effect in ipairs(effects) do
					GameTooltip:AddLine("  " .. effect, 0.9, 0.9, 1)
				end
			else
				GameTooltip:AddLine("  None", 0.7, 0.7, 0.7)
			end
		else
			GameTooltip:AddLine("  (Modifiers unavailable)", 0.7, 0.7, 0.7)
		end

		-- Detailed mode only: show warming/cooling help
		if tooltipMode == "detailed" then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Warming: Fire, Inns, Well Fed, Alcohol", 1.0, 0.7, 0.4)
			GameTooltip:AddLine("Cooling: Swimming, Wet, Drinking, Rain, Mana Potions", 0.5, 0.7, 1.0)

			-- Show effects on other meters
			local hungerEnabled = CC.GetSetting and CC.GetSetting("hungerEnabled")
			local thirstEnabled = CC.GetSetting and CC.GetSetting("thirstEnabled")
			if hungerEnabled or thirstEnabled then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("Effects on other meters:", 0.8, 0.8, 0.8)
				if hungerEnabled then
					GameTooltip:AddLine("  Cold: faster hunger drain", 0.5, 0.7, 1.0)
				end
				if thirstEnabled then
					GameTooltip:AddLine("  Hot: faster thirst drain", 1.0, 0.5, 0.3)
				end
			end
		end

		GameTooltip:Show()
	end)
	tooltipTarget:SetScript("OnLeave", GameTooltip_Hide)
end

-- Calculate constitution value from weighted meter values
CalculateConstitution = function()
	local anguishEnabled = CC.GetSetting and CC.GetSetting("AnguishEnabled")
	local exhaustionEnabled = CC.GetSetting and CC.GetSetting("exhaustionEnabled")
	local hungerEnabled = CC.GetSetting and CC.GetSetting("hungerEnabled")
	local thirstEnabled = CC.GetSetting and CC.GetSetting("thirstEnabled")
	local temperatureEnabled = CC.GetSetting and CC.GetSetting("temperatureEnabled")

	-- Count enabled meters
	local enabledCount = 0
	if anguishEnabled then
		enabledCount = enabledCount + 1
	end
	if exhaustionEnabled then
		enabledCount = enabledCount + 1
	end
	if hungerEnabled then
		enabledCount = enabledCount + 1
	end
	if thirstEnabled then
		enabledCount = enabledCount + 1
	end
	if temperatureEnabled then
		enabledCount = enabledCount + 1
	end

	-- Need at least 2 meters for constitution
	if enabledCount < 2 then
		return nil, nil
	end

	-- Calculate total weight from enabled meters
	local totalWeight = 0
	if anguishEnabled then
		totalWeight = totalWeight + CONSTITUTION_WEIGHTS.anguish
	end
	if exhaustionEnabled then
		totalWeight = totalWeight + CONSTITUTION_WEIGHTS.exhaustion
	end
	if hungerEnabled then
		totalWeight = totalWeight + CONSTITUTION_WEIGHTS.hunger
	end
	if thirstEnabled then
		totalWeight = totalWeight + CONSTITUTION_WEIGHTS.thirst
	end
	if temperatureEnabled then
		totalWeight = totalWeight + CONSTITUTION_WEIGHTS.temperature
	end

	-- Calculate weighted constitution (100 = full health, 0 = depleted)
	-- Each meter contributes negatively to constitution as it increases
	local constitution = 100
	local meterContributions = {}

	if anguishEnabled then
		local anguish = CC.GetAnguish and CC.GetAnguish() or 0
		local normalizedWeight = CONSTITUTION_WEIGHTS.anguish / totalWeight
		local contribution = (anguish / 100) * normalizedWeight * 100
		constitution = constitution - contribution
		meterContributions.anguish = contribution
	end

	if exhaustionEnabled then
		local exhaustion = CC.GetExhaustion and CC.GetExhaustion() or 0
		local normalizedWeight = CONSTITUTION_WEIGHTS.exhaustion / totalWeight
		local contribution = (exhaustion / 100) * normalizedWeight * 100
		constitution = constitution - contribution
		meterContributions.exhaustion = contribution
	end

	if hungerEnabled then
		local hunger = CC.GetHunger and CC.GetHunger() or 0
		local normalizedWeight = CONSTITUTION_WEIGHTS.hunger / totalWeight
		local contribution = (hunger / 100) * normalizedWeight * 100
		constitution = constitution - contribution
		meterContributions.hunger = contribution
	end

	if thirstEnabled then
		local thirst = CC.GetThirst and CC.GetThirst() or 0
		local normalizedWeight = CONSTITUTION_WEIGHTS.thirst / totalWeight
		local contribution = (thirst / 100) * normalizedWeight * 100
		constitution = constitution - contribution
		meterContributions.thirst = contribution
	end

	if temperatureEnabled then
		-- Temperature is bidirectional: both extremes hurt constitution
		local temp = CC.GetTemperature and CC.GetTemperature() or 0
		local normalizedWeight = CONSTITUTION_WEIGHTS.temperature / totalWeight
		local contribution = (math.abs(temp) / 100) * normalizedWeight * 100
		constitution = constitution - contribution
		meterContributions.temperature = contribution
	end

	return math.max(0, math.min(100, constitution)), meterContributions
end

-- Public API to get current constitution value
-- Returns nil if constitution system is not active (less than 2 meters enabled or disabled)
function CC.GetConstitution()
	if not CC.GetSetting or not CC.GetSetting("constitutionEnabled") then
		return nil
	end
	local constitution = CalculateConstitution()
	return constitution
end

-- Check if constitution meter should be shown
local function ShouldShowConstitution()
	if not CC.GetSetting then
		return false
	end
	if not CC.GetSetting("constitutionEnabled") then
		return false
	end

	-- Count enabled meters - need at least 2
	local enabledCount = 0
	if CC.GetSetting("AnguishEnabled") then
		enabledCount = enabledCount + 1
	end
	if CC.GetSetting("exhaustionEnabled") then
		enabledCount = enabledCount + 1
	end
	if CC.GetSetting("hungerEnabled") then
		enabledCount = enabledCount + 1
	end
	if CC.GetSetting("thirstEnabled") then
		enabledCount = enabledCount + 1
	end
	if CC.GetSetting("temperatureEnabled") then
		enabledCount = enabledCount + 1
	end

	return enabledCount >= 2
end

-- Create constitution meter
local function CreateConstitutionMeter(parent)
	local meter = CreateFrame("Frame", "CozierCampsConstitutionMeter", parent)
	-- Extra height for potion cork/neck extending above, plus glow space
	meter:SetSize(CONSTITUTION_ORB_SIZE + 60, CONSTITUTION_ORB_SIZE + 90)
	meter:SetFrameStrata("MEDIUM")
	meter:SetFrameLevel(5)

	-- Glow frame for trend indication (behind everything so edges peek out)
	meter.glowFrame = CreateFrame("Frame", nil, meter)
	meter.glowFrame:SetFrameLevel(meter:GetFrameLevel() - 1) -- Behind orb content
	meter.glowFrame:SetAllPoints()
	meter.glowFrame:EnableMouse(false) -- Allow mouse events to pass through for tooltip

	-- Glow Y offset for constitution orb
	local GLOW_Y_OFFSET = -7
	local CONST_GLOW_SIZE = CONSTITUTION_ORB_SIZE + 80 -- Base glow size (increased for visibility)

	-- Green glow (positive/improving) - bright green tint
	meter.glowGreen = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	meter.glowGreen:SetSize(CONST_GLOW_SIZE, CONST_GLOW_SIZE)
	meter.glowGreen:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
	meter.glowGreen:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\globewhite.png")
	meter.glowGreen:SetBlendMode("ADD")
	meter.glowGreen:SetVertexColor(0.4, 1.0, 0.6, 1) -- Doubled brightness
	meter.glowGreen:SetAlpha(0)

	-- Orange glow (negative/declining) - orange tint
	meter.glowOrange = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	meter.glowOrange:SetSize(CONST_GLOW_SIZE, CONST_GLOW_SIZE)
	meter.glowOrange:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
	meter.glowOrange:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\globewhite.png")
	meter.glowOrange:SetBlendMode("ADD")
	meter.glowOrange:SetVertexColor(1.0, 0.4, 0.05, 1)
	meter.glowOrange:SetAlpha(0)

	-- Blue glow (paused state) - blue tint
	meter.glowBlue = meter.glowFrame:CreateTexture(nil, "ARTWORK", nil, 3)
	meter.glowBlue:SetSize(CONST_GLOW_SIZE, CONST_GLOW_SIZE)
	meter.glowBlue:SetPoint("CENTER", 0, GLOW_Y_OFFSET)
	meter.glowBlue:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\globewhite.png")
	meter.glowBlue:SetBlendMode("ADD")
	meter.glowBlue:SetVertexColor(0.3, 0.5, 1.0, 1)
	meter.glowBlue:SetAlpha(0)

	-- Glow state tracking
	meter.glowCurrentAlpha = 0
	meter.glowTargetAlpha = 0
	meter.glowPulsePhase = 0
	meter.glowIsGreen = true -- Track current glow color
	meter.glowState = "green" -- "green", "orange", or "blue"

	-- Background orb (dark/empty state) using globewhite tinted dark
	-- Offset down slightly to align with potion glass body
	local ORB_Y_OFFSET = -7
	local ORB_VISUAL_SIZE = CONSTITUTION_ORB_SIZE * 0.98 -- Scaled down 2% to show more glass
	meter.orbBg = meter:CreateTexture(nil, "BACKGROUND", nil, 1)
	meter.orbBg:SetSize(ORB_VISUAL_SIZE, ORB_VISUAL_SIZE)
	meter.orbBg:SetPoint("CENTER", 0, ORB_Y_OFFSET)
	meter.orbBg:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\globewhite.png")
	meter.orbBg:SetVertexColor(0.15, 0.05, 0.05, 1) -- Very dark red background

	-- Fill StatusBar with vertical orientation (blood rising/falling effect)
	meter.fillBar = CreateFrame("StatusBar", nil, meter)
	meter.fillBar:SetSize(ORB_VISUAL_SIZE, ORB_VISUAL_SIZE)
	meter.fillBar:SetPoint("CENTER", 0, ORB_Y_OFFSET)
	meter.fillBar:SetStatusBarTexture("Interface\\AddOns\\CozierCamps\\assets\\globetextured.png")
	meter.fillBar:SetOrientation("VERTICAL")
	meter.fillBar:SetMinMaxValues(0, 100)
	meter.fillBar:SetValue(100)
	meter.fillBar:SetFrameLevel(meter:GetFrameLevel() + 1)

	-- Border overlay (circular frame) - hidden since potion provides the border
	meter.border = meter:CreateTexture(nil, "OVERLAY", nil, 5)
	meter.border:SetSize(CONSTITUTION_ORB_SIZE + 2, CONSTITUTION_ORB_SIZE + 2)
	meter.border:SetPoint("CENTER")
	meter.border:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\globeborder.png")
	meter.border:SetVertexColor(0, 0, 0, 1) -- Black border
	meter.border:Hide() -- Hidden - potion overlay provides visual framing

	-- Potion bottle overlay (goes on top of the orb, provides glass bottle look)
	-- Image is 128x128, scale up so glass body properly frames the 62px orb
	local POTION_DISPLAY_SIZE = 120 -- Larger to properly frame the orb
	meter.potionOverlay = meter:CreateTexture(nil, "OVERLAY", nil, 6)
	meter.potionOverlay:SetSize(POTION_DISPLAY_SIZE, POTION_DISPLAY_SIZE)
	-- Offset upward so the round glass body aligns with the orb center
	meter.potionOverlay:SetPoint("CENTER", 0, POTION_DISPLAY_SIZE * 0.10)
	meter.potionOverlay:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\potion.png")

	-- Constitution value text in center with shadow effect
	-- Create a text container frame above the fillBar to ensure visibility
	meter.textFrame = CreateFrame("Frame", nil, meter)
	meter.textFrame:SetAllPoints()
	meter.textFrame:SetFrameLevel(meter.fillBar:GetFrameLevel() + 10) -- Well above the fill bar
	meter.textFrame:EnableMouse(false) -- Allow mouse events to pass through for tooltip

	-- Text offset to match orb position
	local TEXT_Y_OFFSET = -7

	-- Potion heart decoration (behind the text, text sits on top)
	-- Anchor to the percent text itself so it's always centered on it
	meter.potionHeart = meter.textFrame:CreateTexture(nil, "BACKGROUND")
	meter.potionHeart:SetSize(160, 160) -- 1.5x reduced from 240
	meter.potionHeart:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\potionheart.png")
	-- Will anchor after percent text is created

	-- Create shadow texts first (multiple offsets for thick shadow)
	meter.percentShadows = {}
	local shadowOffsets = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
	for _, offset in ipairs(shadowOffsets) do
		local shadow = meter.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		shadow:SetPoint("CENTER", offset[1], offset[2] + TEXT_Y_OFFSET)
		shadow:SetText("100")
		shadow:SetTextColor(0, 0, 0, 1)
		table.insert(meter.percentShadows, shadow)
	end

	-- Main constitution value text
	meter.percent = meter.textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	meter.percent:SetPoint("CENTER", 0, TEXT_Y_OFFSET)
	meter.percent:SetText("100")
	meter.percent:SetTextColor(1, 1, 1, 1)

	-- Now anchor the heart to the percent text (created above)
	-- The heart graphic is at the bottom of the texture, so offset up to center on text
	meter.potionHeart:SetPoint("CENTER", meter.percent, "CENTER", 0, 17)

	-- State tracking
	meter.currentFillLevel = 100 -- 0-100 for StatusBar
	meter.targetFillLevel = 100

	-- Enable mouse for tooltip (will be set up by SetupConstitutionBarTooltip later)
	meter:EnableMouse(true)

	-- Forward drag events to parent (metersContainer) so orb moves with meters
	meter:RegisterForDrag("LeftButton")
	meter:SetScript("OnDragStart", function()
		StartMovingMetersContainer()
	end)
	meter:SetScript("OnDragStop", function()
		if metersContainer then
			metersContainer:StopMovingOrSizing()
			-- Save absolute screen coordinates of top-left corner for consistent placement
			if not CC.GetSetting("metersLocked") then
				local left = metersContainer:GetLeft()
				local top = metersContainer:GetTop()
				if CC.db and left and top then
					CC.db.meterPosition = {
						screenLeft = left,
						screenTop = top
					}
				end
			end
		end
	end)

	return meter
end

-- Update constitution meter visual (orb style)
local function UpdateConstitutionMeter(elapsed)
	if not constitutionMeter then
		return
	end

	local constitution = CalculateConstitution()
	if not constitution then
		constitutionMeter:Hide()
		return
	end

	constitutionMeter:Show()

	-- Simple change detection - flash glow on any change
	local delta = constitution - lastConstitution
	if delta < -0.01 then
		-- Constitution went down - orange glow
		constitutionGlowState = "orange"
		constitutionGlowTimer = CONSTITUTION_GLOW_DURATION
	elseif delta > 0.01 then
		-- Constitution went up - green glow
		constitutionGlowState = "green"
		constitutionGlowTimer = CONSTITUTION_GLOW_DURATION
	end
	lastConstitution = constitution

	-- Count down glow timer
	if constitutionGlowTimer > 0 then
		constitutionGlowTimer = constitutionGlowTimer - elapsed
		if constitutionGlowTimer <= 0 then
			constitutionGlowState = "none"
		end
	end

	-- Update target fill level (0-100 for StatusBar)
	constitutionMeter.targetFillLevel = constitution

	-- Smooth fill level interpolation
	local fillDiff = constitutionMeter.targetFillLevel - constitutionMeter.currentFillLevel
	if math.abs(fillDiff) < 0.5 then
		constitutionMeter.currentFillLevel = constitutionMeter.targetFillLevel
	else
		local speed = 3.0 -- Slightly faster for smoother orb animation
		constitutionMeter.currentFillLevel = constitutionMeter.currentFillLevel + (fillDiff * speed * elapsed)
	end

	-- Update StatusBar fill value
	constitutionMeter.fillBar:SetValue(constitutionMeter.currentFillLevel)

	-- Update percentage text and shadows (respect hideVialText setting)
	local percentText = string.format("%.0f", constitution)
	local hideText = CC.GetSetting("hideVialText")
	if hideText then
		constitutionMeter.percent:SetText("")
		for _, shadow in ipairs(constitutionMeter.percentShadows) do
			shadow:SetText("")
		end
	else
		constitutionMeter.percent:SetText(percentText)
		for _, shadow in ipairs(constitutionMeter.percentShadows) do
			shadow:SetText(percentText)
		end
	end

	-- Glow based on change direction (peeks out from behind potion)
	-- Blue = paused, Green = improving, Orange = declining, None = stable
	local MAX_GLOW_ALPHA = 1.0

	-- Check if all ENABLED systems are paused (disabled systems treated as paused)
	local anguishEnabled = CC.GetSetting and CC.GetSetting("AnguishEnabled")
	local exhaustionEnabled = CC.GetSetting and CC.GetSetting("exhaustionEnabled")
	local hungerEnabled = CC.GetSetting and CC.GetSetting("hungerEnabled")
	local temperatureEnabled = CC.GetSetting and CC.GetSetting("temperatureEnabled")
	local anguishPaused = (not anguishEnabled) or (CC.IsAnguishPaused and CC.IsAnguishPaused() or false)
	local exhaustionPaused = (not exhaustionEnabled) or (CC.IsExhaustionPaused and CC.IsExhaustionPaused() or false)
	local hungerPaused = (not hungerEnabled) or (CC.IsHungerPaused and CC.IsHungerPaused() or false)
	local temperaturePaused = (not temperatureEnabled) or (CC.IsTemperaturePaused and CC.IsTemperaturePaused() or false)
	local isPaused = anguishPaused and exhaustionPaused and hungerPaused and temperaturePaused

	-- Override glow state if paused
	local effectiveGlowState = constitutionGlowState
	if isPaused then
		effectiveGlowState = "blue"
	end

	-- Apply glow based on effective state
	if effectiveGlowState == "blue" then
		-- Paused - show blue glow
		constitutionMeter.glowTargetAlpha = 0.7
	elseif effectiveGlowState == "green" then
		-- Improving - show bright green glow
		constitutionMeter.glowTargetAlpha = MAX_GLOW_ALPHA
	elseif effectiveGlowState == "orange" then
		-- Declining - show bright orange glow
		constitutionMeter.glowTargetAlpha = MAX_GLOW_ALPHA
	else
		-- Stable - no glow
		constitutionMeter.glowTargetAlpha = 0
	end

	-- Gentle pulse
	constitutionMeter.glowPulsePhase = constitutionMeter.glowPulsePhase + elapsed * 0.8
	if constitutionMeter.glowTargetAlpha > 0 then
		local pulseMod = 0.85 + 0.15 * math.sin(constitutionMeter.glowPulsePhase * math.pi * 2)
		constitutionMeter.glowTargetAlpha = constitutionMeter.glowTargetAlpha * pulseMod
	end

	-- Smooth glow alpha
	local alphaDiff = constitutionMeter.glowTargetAlpha - constitutionMeter.glowCurrentAlpha
	if math.abs(alphaDiff) < 0.005 then
		constitutionMeter.glowCurrentAlpha = constitutionMeter.glowTargetAlpha
	else
		local speed = alphaDiff > 0 and 3.0 or 1.5
		constitutionMeter.glowCurrentAlpha = constitutionMeter.glowCurrentAlpha + (alphaDiff * speed * elapsed)
	end

	local glowAlpha = math.max(0, math.min(1, constitutionMeter.glowCurrentAlpha))

	-- When constitution is critically low (below 35%) and declining, intensify the orange glow
	local criticalIntensity = 1.0
	if constitution < 35 and effectiveGlowState == "orange" then
		glowAlpha = math.max(glowAlpha, 0.45)
		criticalIntensity = 1.3
	end

	-- Show appropriate glow, hide others based on effective state
	if constitutionMeter.glowGreen and constitutionMeter.glowOrange and constitutionMeter.glowBlue then
		if effectiveGlowState == "blue" then
			constitutionMeter.glowGreen:SetAlpha(0)
			constitutionMeter.glowOrange:SetAlpha(0)
			constitutionMeter.glowBlue:SetAlpha(glowAlpha)
		elseif effectiveGlowState == "green" then
			constitutionMeter.glowGreen:SetAlpha(glowAlpha)
			constitutionMeter.glowOrange:SetAlpha(0)
			constitutionMeter.glowBlue:SetAlpha(0)
		elseif effectiveGlowState == "orange" then
			constitutionMeter.glowGreen:SetAlpha(0)
			constitutionMeter.glowOrange:SetAlpha(math.min(1, glowAlpha * criticalIntensity))
			constitutionMeter.glowBlue:SetAlpha(0)
		else
			-- No glow (stable)
			constitutionMeter.glowGreen:SetAlpha(0)
			constitutionMeter.glowOrange:SetAlpha(0)
			constitutionMeter.glowBlue:SetAlpha(0)
		end
	end

	-- Update Adventure Mode UI hiding based on constitution level
	UpdateAdventureModeUI(constitution)
end

-- Update constitution bar meter (bar mode version)
local function UpdateConstitutionBarMeter(elapsed)
	if not constitutionBarMeter then
		return
	end

	local constitution = CalculateConstitution()
	if not constitution then
		constitutionBarMeter:Hide()
		return
	end

	constitutionBarMeter:Show()

	-- Update glow state
	-- (Only if orb meter isn't visible, to avoid double-calculation)
	if not constitutionMeter or not constitutionMeter:IsShown() then
		-- Simple change detection - flash glow on any change
		local delta = constitution - lastConstitution
		if delta < -0.01 then
			-- Constitution went down - orange glow
			constitutionGlowState = "orange"
			constitutionGlowTimer = CONSTITUTION_GLOW_DURATION
		elseif delta > 0.01 then
			-- Constitution went up - green glow
			constitutionGlowState = "green"
			constitutionGlowTimer = CONSTITUTION_GLOW_DURATION
		end
		lastConstitution = constitution

		-- Count down glow timer
		if constitutionGlowTimer > 0 then
			constitutionGlowTimer = constitutionGlowTimer - elapsed
			if constitutionGlowTimer <= 0 then
				constitutionGlowState = "none"
			end
		end
	end

	-- Update bar value
	constitutionBarMeter.bar:SetValue(constitution)
	constitutionBarMeter.percent:SetText(string.format("%.0f%%", constitution))

	-- Check if all ENABLED systems are paused (disabled systems treated as paused)
	local anguishEnabled = cachedSettings.AnguishEnabled
	local exhaustionEnabled = cachedSettings.exhaustionEnabled
	local hungerEnabled = cachedSettings.hungerEnabled
	local temperatureEnabled = cachedSettings.temperatureEnabled

	local anguishPaused = (not anguishEnabled) or (CC.IsAnguishPaused and CC.IsAnguishPaused() or false)
	local exhaustionPaused = (not exhaustionEnabled) or (CC.IsExhaustionPaused and CC.IsExhaustionPaused() or false)
	local hungerPaused = (not hungerEnabled) or (CC.IsHungerPaused and CC.IsHungerPaused() or false)
	local temperaturePaused = (not temperatureEnabled) or (CC.IsTemperaturePaused and CC.IsTemperaturePaused() or false)
	local isPaused = anguishPaused and exhaustionPaused and hungerPaused and temperaturePaused

	-- Override glow state if paused
	local effectiveGlowState = constitutionGlowState
	if isPaused then
		effectiveGlowState = "blue"
	end

	-- Set bar color and glow based on state
	-- Bar always stays green to match vial mode
	local glow = constitutionBarMeter.glow
	constitutionBarMeter.bar:SetStatusBarColor(CONSTITUTION_BAR_COLOR.r, CONSTITUTION_BAR_COLOR.g,
			CONSTITUTION_BAR_COLOR.b)

	if effectiveGlowState == "blue" then
		-- Paused - blue glow
		SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, true) -- isPaused=true triggers blue
		glow.targetAlpha = 0.7
		glow.targetSize = GLOW_SIZE_PAUSED
	elseif effectiveGlowState == "green" then
		-- Improving - bright green glow
		SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
		glow.targetAlpha = 1.0
		glow.targetSize = GLOW_SIZE
	elseif effectiveGlowState == "orange" then
		-- Declining - bright orange glow (but bar stays green)
		SetGlowColor(glow, 1.0, 0.4, 0.1, false)
		glow.targetAlpha = 1.0
		glow.targetSize = GLOW_SIZE
	else
		-- Stable - no glow
		glow.targetAlpha = 0
		glow.targetSize = GLOW_SIZE
	end

	-- Clamp glow alpha
	glow.targetAlpha = math.min(1.0, glow.targetAlpha)

	-- Critical state (below 35%) - intensify warning
	if constitution < 35 and effectiveGlowState == "orange" then
		SetGlowColor(glow, GLOW_RED.r, GLOW_RED.g, GLOW_RED.b, false)
		glow.targetAlpha = 0.9
	end

	-- Gentle pulse
	glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
	if glow.targetAlpha > 0 then
		local pulseMod = 0.8 + 0.2 * math.sin(glow.pulsePhase * math.pi * 2)
		glow.targetAlpha = glow.targetAlpha * pulseMod
	end

	-- Smooth alpha interpolation
	local alphaDiff = glow.targetAlpha - glow.currentAlpha
	if math.abs(alphaDiff) < 0.01 then
		glow.currentAlpha = glow.targetAlpha
	else
		local speed = alphaDiff > 0 and 5.0 or 2.0
		glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
	end
	glow.currentAlpha = math.max(0, math.min(1, glow.currentAlpha))
	glow:SetAlpha(glow.currentAlpha)

	-- Size update: snap immediately to paused size, interpolate others
	if glow.targetSize < 0 then
		-- Paused state: snap immediately to avoid large glow flash
		glow.currentSize = glow.targetSize
	else
		-- Normal state: smooth interpolation
		local sizeDiff = glow.targetSize - glow.currentSize
		if math.abs(sizeDiff) < 0.5 then
			glow.currentSize = glow.targetSize
		else
			glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
		end
	end
	UpdateGlowSize(glow, constitutionBarMeter, glow.currentSize)

	-- Update Adventure Mode UI hiding based on constitution level
	UpdateAdventureModeUI(constitution)
end

-- Update temperature meter visual
local function UpdateTemperatureMeter(elapsed)
	if not temperatureMeter then
		return
	end

	local temp = CC.GetTemperature and CC.GetTemperature() or 0
	local isPaused = CC.IsTemperaturePaused and CC.IsTemperaturePaused() or false

	-- Use actual meter width (may have been resized for vial mode)
	local actualWidth = temperatureMeter:GetWidth()
	local barWidth = actualWidth - (METER_PADDING * 2)
	local halfWidth = barWidth / 2

	-- Calculate fill width and position based on temperature
	local fillPercent = math.abs(temp) / 100
	local fillWidth = halfWidth * fillPercent

	-- Calculate bar color and store for arrow
	local barR, barG, barB = 0.5, 0.5, 0.5

	if temp < 0 then
		-- Cold - fill from center to left
		temperatureMeter.fillBar:ClearAllPoints()
		temperatureMeter.fillBar:SetPoint("RIGHT", temperatureMeter, "CENTER", 0, 0)
		temperatureMeter.fillBar:SetWidth(math.max(1, fillWidth))

		-- Gradient color from light blue (near center) to dark blue (far left)
		local t = fillPercent
		barR = TEMP_COLD_LIGHT.r + (TEMP_COLD_DARK.r - TEMP_COLD_LIGHT.r) * t
		barG = TEMP_COLD_LIGHT.g + (TEMP_COLD_DARK.g - TEMP_COLD_LIGHT.g) * t
		barB = TEMP_COLD_LIGHT.b + (TEMP_COLD_DARK.b - TEMP_COLD_LIGHT.b) * t
		temperatureMeter.fillBar:SetVertexColor(barR, barG, barB, 1)

	elseif temp > 0 then
		-- Hot - fill from center to right
		temperatureMeter.fillBar:ClearAllPoints()
		temperatureMeter.fillBar:SetPoint("LEFT", temperatureMeter, "CENTER", 0, 0)
		temperatureMeter.fillBar:SetWidth(math.max(1, fillWidth))

		-- Gradient color from light yellow (near center) to dark orange (far right)
		local t = fillPercent
		barR = TEMP_HOT_LIGHT.r + (TEMP_HOT_DARK.r - TEMP_HOT_LIGHT.r) * t
		barG = TEMP_HOT_LIGHT.g + (TEMP_HOT_DARK.g - TEMP_HOT_LIGHT.g) * t
		barB = TEMP_HOT_LIGHT.b + (TEMP_HOT_DARK.b - TEMP_HOT_LIGHT.b) * t
		temperatureMeter.fillBar:SetVertexColor(barR, barG, barB, 1)

	else
		-- Neutral - no fill
		temperatureMeter.fillBar:SetWidth(1)
		temperatureMeter.fillBar:SetVertexColor(0.5, 0.5, 0.5, 0.5)
		barR, barG, barB = 0.7, 0.7, 0.7
	end

	-- Store bar color for arrow matching (used by atlas-based sparks)
	temperatureMeter.currentBarR = barR
	temperatureMeter.currentBarG = barG
	temperatureMeter.currentBarB = barB

	-- Calculate arrow position based on temperature
	local arrowOffset = (temp / 100) * halfWidth

	-- Switch spark atlas based on state
	-- isBalanced = near 0 AND stable with counter-force (fire/inn in cold zone)
	local isBalanced = CC.IsTemperatureBalanced and CC.IsTemperatureBalanced()
	local trend = CC.GetTemperatureTrend and CC.GetTemperatureTrend() or 0

	-- Use hysteresis to prevent flickering when temp is near 0
	-- Keep track of last "side" we were on (hot or cold)
	temperatureMeter.lastTempSide = temperatureMeter.lastTempSide or 0

	-- Only show white centered spark when actually near 0 (balanced state)
	-- NOT when at zone equilibrium far from 0
	if isBalanced then
		-- Balanced (near 0 with counter-forces) - use Blizzard Spark, neutral white
		temperatureMeter.arrow:SetTexture(130877) -- Blizzard Spark
		temperatureMeter.arrow:SetVertexColor(1, 1, 1, 1) -- Neutral white
		temperatureMeter.lastTempSide = 0 -- Reset side tracking
		-- Force arrow to center when balanced (near 0)
		arrowOffset = 0
	elseif math.abs(temp) < 2 and trend == 0 then
		-- Very close to 0 and stable - use neutral spark to avoid flickering
		temperatureMeter.arrow:SetTexture(130877) -- Blizzard Spark
		temperatureMeter.arrow:SetVertexColor(1, 1, 1, 1) -- Neutral white
	elseif temp > 3 or (temp >= 0 and temperatureMeter.lastTempSide >= 0 and temp > -3) then
		-- Clearly hot, or staying on hot side with hysteresis
		temperatureMeter.arrow:SetAtlas("Legionfall_BarSpark") -- Hot/orange spark (moving)
		temperatureMeter.arrow:SetVertexColor(barR, barG, barB, 1) -- Match bar color
		temperatureMeter.lastTempSide = 1
	elseif temp < -3 or (temp < 0 and temperatureMeter.lastTempSide <= 0 and temp < 3) then
		-- Clearly cold, or staying on cold side with hysteresis
		temperatureMeter.arrow:SetAtlas("bonusobjectives-bar-spark") -- Cold/blue spark (moving)
		temperatureMeter.arrow:SetVertexColor(barR, barG, barB, 1) -- Match bar color
		temperatureMeter.lastTempSide = -1
	else
		-- Fallback to neutral when in ambiguous zone
		temperatureMeter.arrow:SetTexture(130877)
		temperatureMeter.arrow:SetVertexColor(1, 1, 1, 1)
	end

	-- Position arrow
	temperatureMeter.arrow:ClearAllPoints()
	temperatureMeter.arrow:SetPoint("CENTER", temperatureMeter, "CENTER", arrowOffset, 0)

	-- Update percentage text (currently hidden, but keep logic for if re-enabled)
	-- local absTemp = math.floor(math.abs(temp))
	-- if temp < 0 then
	--     temperatureMeter.percent:SetText("-" .. absTemp)
	--     temperatureMeter.percent:SetTextColor(0.5, 0.7, 1.0)
	-- elseif temp > 0 then
	--     temperatureMeter.percent:SetText("+" .. absTemp)
	--     temperatureMeter.percent:SetTextColor(1.0, 0.7, 0.4)
	-- else
	--     temperatureMeter.percent:SetText("0")
	--     temperatureMeter.percent:SetTextColor(0.7, 0.7, 0.7)
	-- end

	-- Update glows based on state
	local coldGlow = temperatureMeter.coldGlow
	local hotGlow = temperatureMeter.hotGlow

	-- Reset glow targets
	coldGlow.targetAlpha = 0
	hotGlow.targetAlpha = 0

	-- trend was already retrieved above for spark logic

	-- Glow intensity based on how extreme the temperature is
	local glowIntensity = math.min(1.0, math.abs(temp) / 50)

	if isPaused then
		-- Paused (flight, dungeon, raid) - blue glow
		coldGlow.texture:SetVertexColor(1, 1, 1) -- Native atlas color (blue/yellow)
		coldGlow.targetAlpha = 0.7
	elseif isBalanced then
		-- Balanced (reached equilibrium near 0, stable) - NO glow, just equilibrium spark
		-- All glows stay at 0
	elseif trend < 0 then
		-- Getting colder - blue glow (even if near fire warming up from cold)
		coldGlow.texture:SetVertexColor(0.3, 0.5, 1.0)
		coldGlow.targetAlpha = math.max(0.3, glowIntensity) -- Minimum glow while moving
	elseif trend > 0 then
		-- Getting warmer - orange glow (e.g., warming up by fire when cold)
		hotGlow.targetAlpha = math.max(0.3, glowIntensity) -- Minimum glow while moving
	end
	-- trend == 0 and not balanced = no glow (at natural equilibrium or truly stable)

	-- Apply pulsing and interpolation for cold glow
	if coldGlow.targetAlpha > 0 then
		coldGlow.pulsePhase = (coldGlow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
		local pulseMod = 0.6 + 0.4 * math.sin(coldGlow.pulsePhase * math.pi * 2)
		coldGlow.targetAlpha = coldGlow.targetAlpha * pulseMod
	end
	local coldDiff = coldGlow.targetAlpha - coldGlow.currentAlpha
	if math.abs(coldDiff) < 0.01 then
		coldGlow.currentAlpha = coldGlow.targetAlpha
	else
		local speed = coldDiff > 0 and 8.0 or 3.0
		coldGlow.currentAlpha = coldGlow.currentAlpha + (coldDiff * speed * elapsed)
	end
	coldGlow.currentAlpha = math.max(0, math.min(1, coldGlow.currentAlpha))
	coldGlow:SetAlpha(coldGlow.currentAlpha)

	-- Apply pulsing and interpolation for hot glow
	if hotGlow.targetAlpha > 0 then
		hotGlow.pulsePhase = (hotGlow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
		local pulseMod = 0.6 + 0.4 * math.sin(hotGlow.pulsePhase * math.pi * 2)
		hotGlow.targetAlpha = hotGlow.targetAlpha * pulseMod
	end
	local hotDiff = hotGlow.targetAlpha - hotGlow.currentAlpha
	if math.abs(hotDiff) < 0.01 then
		hotGlow.currentAlpha = hotGlow.targetAlpha
	else
		local speed = hotDiff > 0 and 8.0 or 3.0
		hotGlow.currentAlpha = hotGlow.currentAlpha + (hotDiff * speed * elapsed)
	end
	hotGlow.currentAlpha = math.max(0, math.min(1, hotGlow.currentAlpha))
	hotGlow:SetAlpha(hotGlow.currentAlpha)

	-- Breathing effect on icons based on temperature trend
	-- Cold icon breathes when getting colder (trend < 0)
	-- Fire icon breathes when getting warmer (trend > 0)
	local BREATHE_SPEED = 1.0 -- Slow, gentle breathing (1 cycle per second)

	if trend < 0 and not isPaused then
		-- Getting colder - cold icon breathes (brightness pulse)
		temperatureMeter.coldIconPulse = (temperatureMeter.coldIconPulse or 0) + elapsed * BREATHE_SPEED
		local breathe = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(temperatureMeter.coldIconPulse * math.pi * 2))
		temperatureMeter.coldIcon:SetVertexColor(0.5 * breathe + 0.3, 0.75 * breathe + 0.2, 1.0, 1)
	else
		temperatureMeter.coldIcon:SetVertexColor(0.6, 0.8, 1.0, 1) -- Normal color
	end

	if trend > 0 and not isPaused then
		-- Getting warmer - fire icon breathes (brightness pulse)
		temperatureMeter.fireIconPulse = (temperatureMeter.fireIconPulse or 0) + elapsed * BREATHE_SPEED
		local breathe = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(temperatureMeter.fireIconPulse * math.pi * 2))
		temperatureMeter.fireIcon:SetVertexColor(1.0, 0.6 * breathe + 0.2, 0.3 * breathe + 0.1, 1)
	else
		temperatureMeter.fireIcon:SetVertexColor(1.0, 0.8, 0.5, 1) -- Normal color
	end
end

-- ============================================
-- WEATHER BUTTON
-- ============================================

-- Weather type constants (must match Temperature.lua)
local WEATHER_TYPE_NONE = 0
local WEATHER_TYPE_RAIN = 1
local WEATHER_TYPE_SNOW = 2
local WEATHER_TYPE_DUST = 3
local WEATHER_TYPE_STORM = 4 -- Arcane/Netherstorm

-- Weather type constants for visual effects
local WEATHER_GLOW_ATLASES = {
	[WEATHER_TYPE_RAIN] = {
		circleGlow = "ChallengeMode-Runes-CircleGlow",
		relicGlow = "Relic-Water-TraitGlow",
		circleColor = { 0.4, 0.6, 1.0 }, -- Blue
		relicColor = { 0.5, 0.7, 1.0 }, -- Light blue
		circleSize = WEATHER_BUTTON_SIZE, -- Inner glow smaller
		relicSize = WEATHER_BUTTON_SIZE + 16 -- Outer relic larger
	},
	[WEATHER_TYPE_SNOW] = {
		circleGlow = "Relic-Rankselected-circle",
		relicGlow = "Relic-Frost-TraitGlow",
		circleColor = { 0.6, 0.8, 1.0 }, -- Ice blue
		relicColor = { 0.7, 0.9, 1.0 }, -- Frost white
		circleSize = WEATHER_BUTTON_SIZE + 6, -- Inner glow smaller
		relicSize = WEATHER_BUTTON_SIZE + 16 -- Outer relic larger
	},
	[WEATHER_TYPE_DUST] = {
		circleGlow = "Neutraltrait-Glow",
		relicGlow = "Relic-Fire-TraitGlow",
		circleColor = { 1.0, 0.7, 0.3 }, -- Orange
		relicColor = { 1.0, 0.5, 0.2 }, -- Fire orange
		circleSize = WEATHER_BUTTON_SIZE + 8, -- Inner glow smaller
		relicSize = WEATHER_BUTTON_SIZE + 16 -- Outer relic larger
	},
	[WEATHER_TYPE_STORM] = {
		circleGlow = "Relic-Arcane-TraitGlow",
		relicGlow = "Relic-Arcane-TraitGlow",
		circleColor = { 0.6, 0.4, 1.0 }, -- Purple/arcane
		relicColor = { 0.8, 0.5, 1.0 }, -- Bright purple
		circleSize = WEATHER_BUTTON_SIZE + 10, -- Inner glow
		relicSize = WEATHER_BUTTON_SIZE + 18 -- Outer relic larger
	}
}

-- Paused glow atlas (gold, same as the original active state glow)
local WEATHER_PAUSED_ATLAS = "ChallengeMode-KeystoneSlotFrameGlow"

-- Create status icons row (Classic parity: icons above meters, independent of weather button)
local function CreateStatusIconsRow(parent)
	local row = CreateFrame("Frame", "CozierCampsStatusIconsRow", parent)
	row:SetSize(100, STATUS_ROW_HEIGHT) -- Width will be adjusted in RepositionMeters

	-- Wet status icon (left of center)
	local WET_ICON_SIZE = STATUS_ICON_SIZE
	row.wetIcon = row:CreateTexture(nil, "ARTWORK")
	row.wetIcon:SetSize(WET_ICON_SIZE, WET_ICON_SIZE)
	row.wetIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
	row.wetIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\weticon.png")
	row.wetIcon:SetAlpha(0)

	local WET_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.wetGlow = row:CreateTexture(nil, "BACKGROUND")
	row.wetGlow:SetSize(WET_GLOW_SIZE, WET_GLOW_SIZE)
	row.wetGlow:SetPoint("CENTER", row.wetIcon, "CENTER")
	row.wetGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.wetGlow:SetVertexColor(0.5, 0.8, 1.0)
	row.wetGlow:SetBlendMode("ADD")
	row.wetGlow:SetAlpha(0)

	row.wetGlowAG = row.wetGlow:CreateAnimationGroup()
	row.wetGlowAG:SetLooping("REPEAT")
	local wetSpin = row.wetGlowAG:CreateAnimation("Rotation")
	wetSpin:SetDegrees(-360)
	wetSpin:SetDuration(4)
	row.wetGlowAG:Play()

	row.wetHitbox = CreateFrame("Frame", nil, row)
	row.wetHitbox:SetSize(STATUS_ICON_SIZE + 8, STATUS_ICON_SIZE + 8)
	row.wetHitbox:SetPoint("CENTER", row.wetIcon, "CENTER")
	row.wetHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.wetHitbox:EnableMouse(true)
	row.wetHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not CC.IsWetEffectActive or not CC.IsWetEffectActive() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Wet", 0.3, 0.6, 1.0)
		local remaining = CC.GetWetEffectRemaining and CC.GetWetEffectRemaining() or 0
		local minutes = math.floor(remaining / 60)
		local seconds = math.floor(remaining % 60)
		local timeStr = minutes > 0 and string.format("%d:%02d remaining", minutes, seconds) or
				string.format("%d seconds remaining", seconds)
		GameTooltip:AddLine(timeStr, 1, 1, 1)
		GameTooltip:AddLine(" ")
		local temp = CC.GetTemperature and CC.GetTemperature() or 0
		if temp < 0 then
			GameTooltip:AddLine("You feel colder while wet", 0.5, 0.7, 1.0)
		elseif temp > 0 then
			GameTooltip:AddLine("Evaporative cooling helps you stay cool", 0.5, 0.7, 1.0)
		else
			GameTooltip:AddLine("Being wet affects your temperature", 0.7, 0.7, 0.7)
		end
		local isDrying = CC.isNearFire or IsResting()
		if isDrying then
			GameTooltip:AddLine("Drying off faster near warmth", 1.0, 0.6, 0.2)
		end
		GameTooltip:Show()
	end)
	row.wetHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Swimming status icon (left of center)
	local SWIMMING_ICON_SIZE = STATUS_ICON_SIZE
	row.swimmingIcon = row:CreateTexture(nil, "ARTWORK")
	row.swimmingIcon:SetSize(SWIMMING_ICON_SIZE, SWIMMING_ICON_SIZE)
	row.swimmingIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
	row.swimmingIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\swimmingicon.png")
	row.swimmingIcon:SetAlpha(0)

	local SWIMMING_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.swimmingGlow = row:CreateTexture(nil, "BACKGROUND")
	row.swimmingGlow:SetSize(SWIMMING_GLOW_SIZE, SWIMMING_GLOW_SIZE)
	row.swimmingGlow:SetPoint("CENTER", row.swimmingIcon, "CENTER")
	row.swimmingGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.swimmingGlow:SetVertexColor(0.4, 0.65, 1.0)
	row.swimmingGlow:SetBlendMode("ADD")
	row.swimmingGlow:SetAlpha(0)

	row.swimmingGlowAG = row.swimmingGlow:CreateAnimationGroup()
	row.swimmingGlowAG:SetLooping("REPEAT")
	local swimmingSpin = row.swimmingGlowAG:CreateAnimation("Rotation")
	swimmingSpin:SetDegrees(-360)
	swimmingSpin:SetDuration(3)
	row.swimmingGlowAG:Play()

	row.swimmingHitbox = CreateFrame("Frame", nil, row)
	row.swimmingHitbox:SetSize(SWIMMING_ICON_SIZE + 8, SWIMMING_ICON_SIZE + 8)
	row.swimmingHitbox:SetPoint("CENTER", row.swimmingIcon, "CENTER")
	row.swimmingHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.swimmingHitbox:EnableMouse(true)
	row.swimmingHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not IsSwimming() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Swimming", 0.4, 0.65, 1.0)
		local temp = CC.GetTemperature and CC.GetTemperature() or 0
		if temp > 0 then
			GameTooltip:AddLine("Cooling off in the water", 0.5, 0.7, 1.0)
		else
			GameTooltip:AddLine("Getting colder in the water", 0.5, 0.7, 1.0)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Becoming drenched", 0.5, 0.8, 1.0)
		local thirstEnabled = CC.GetSetting and CC.GetSetting("thirstEnabled")
		if thirstEnabled then
			GameTooltip:AddLine("Slowly recovering thirst", 0.4, 1.0, 0.6)
		end
		GameTooltip:AddLine("Exhaustion drains faster", 0.9, 0.6, 0.4)
		GameTooltip:Show()
	end)
	row.swimmingHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Bandage status icon (left of center)
	local BANDAGE_ICON_SIZE = STATUS_ICON_SIZE
	row.bandageIcon = row:CreateTexture(nil, "ARTWORK")
	row.bandageIcon:SetSize(BANDAGE_ICON_SIZE, BANDAGE_ICON_SIZE)
	row.bandageIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
	row.bandageIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\bandageicon.png")
	row.bandageIcon:SetAlpha(0)

	local BANDAGE_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.bandageGlow = row:CreateTexture(nil, "BACKGROUND")
	row.bandageGlow:SetSize(BANDAGE_GLOW_SIZE, BANDAGE_GLOW_SIZE)
	row.bandageGlow:SetPoint("CENTER", row.bandageIcon, "CENTER")
	row.bandageGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.bandageGlow:SetVertexColor(0.3, 1.0, 0.4)
	row.bandageGlow:SetBlendMode("ADD")
	row.bandageGlow:SetAlpha(0)

	row.bandageGlowAG = row.bandageGlow:CreateAnimationGroup()
	row.bandageGlowAG:SetLooping("REPEAT")
	local bandageSpin = row.bandageGlowAG:CreateAnimation("Rotation")
	bandageSpin:SetDegrees(360)
	bandageSpin:SetDuration(4)
	row.bandageGlowAG:Play()

	row.bandageHitbox = CreateFrame("Frame", nil, row)
	row.bandageHitbox:SetSize(BANDAGE_ICON_SIZE + 8, BANDAGE_ICON_SIZE + 8)
	row.bandageHitbox:SetPoint("CENTER", row.bandageIcon, "CENTER")
	row.bandageHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.bandageHitbox:EnableMouse(true)
	row.bandageHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not CC.IsBandaging or not CC.IsBandaging() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Bandaging", 0.3, 1.0, 0.4)
		GameTooltip:AddLine("Healing anguish while channeling", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("0.2% per tick", 0.6, 0.8, 0.6)
		GameTooltip:Show()
	end)
	row.bandageHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Potion status icon (left of center)
	local POTION_ICON_SIZE = STATUS_ICON_SIZE
	row.potionIcon = row:CreateTexture(nil, "ARTWORK")
	row.potionIcon:SetSize(POTION_ICON_SIZE, POTION_ICON_SIZE)
	row.potionIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
	row.potionIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\potionicon.png")
	row.potionIcon:SetAlpha(0)

	local POTION_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.potionGlow = row:CreateTexture(nil, "BACKGROUND")
	row.potionGlow:SetSize(POTION_GLOW_SIZE, POTION_GLOW_SIZE)
	row.potionGlow:SetPoint("CENTER", row.potionIcon, "CENTER")
	row.potionGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.potionGlow:SetVertexColor(0.3, 1.0, 0.4)
	row.potionGlow:SetBlendMode("ADD")
	row.potionGlow:SetAlpha(0)

	row.potionGlowAG = row.potionGlow:CreateAnimationGroup()
	row.potionGlowAG:SetLooping("REPEAT")
	local potionSpin = row.potionGlowAG:CreateAnimation("Rotation")
	potionSpin:SetDegrees(360)
	potionSpin:SetDuration(5)
	row.potionGlowAG:Play()

	row.potionHitbox = CreateFrame("Frame", nil, row)
	row.potionHitbox:SetSize(POTION_ICON_SIZE + 8, POTION_ICON_SIZE + 8)
	row.potionHitbox:SetPoint("CENTER", row.potionIcon, "CENTER")
	row.potionHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.potionHitbox:EnableMouse(true)
	row.potionHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not CC.IsPotionHealing or not CC.IsPotionHealing() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Potion Effect", 0.3, 1.0, 0.4)
		GameTooltip:AddLine("Slowly healing anguish", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("3% over 2 minutes", 0.6, 0.8, 0.6)
		GameTooltip:Show()
	end)
	row.potionHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Cozy/fire status icon (center)
	local COZY_ICON_SIZE = STATUS_ICON_SIZE
	row.cozyIcon = row:CreateTexture(nil, "ARTWORK")
	row.cozyIcon:SetSize(COZY_ICON_SIZE, COZY_ICON_SIZE)
	row.cozyIcon:SetPoint("CENTER", row, "CENTER", 0, 0)
	row.cozyIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\cozyicon.png")
	row.cozyIcon:SetAlpha(0)

	local COZY_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.cozyGlow = row:CreateTexture(nil, "BACKGROUND")
	row.cozyGlow:SetSize(COZY_GLOW_SIZE, COZY_GLOW_SIZE)
	row.cozyGlow:SetPoint("CENTER", row.cozyIcon, "CENTER")
	row.cozyGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.cozyGlow:SetVertexColor(1.0, 0.7, 0.2)
	row.cozyGlow:SetBlendMode("ADD")
	row.cozyGlow:SetAlpha(0)

	row.cozyGlowAG = row.cozyGlow:CreateAnimationGroup()
	row.cozyGlowAG:SetLooping("REPEAT")
	local cozySpin = row.cozyGlowAG:CreateAnimation("Rotation")
	cozySpin:SetDegrees(360)
	cozySpin:SetDuration(3)
	row.cozyGlowAG:Play()

	row.cozyHitbox = CreateFrame("Frame", nil, row)
	row.cozyHitbox:SetSize(COZY_ICON_SIZE + 8, COZY_ICON_SIZE + 8)
	row.cozyHitbox:SetPoint("CENTER", row.cozyIcon, "CENTER")
	row.cozyHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.cozyHitbox:EnableMouse(true)
	row.cozyHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not CC.isNearFire then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Near Campfire", 1.0, 0.7, 0.2)
		local temp = CC.GetTemperature and CC.GetTemperature() or 0
		if temp < 0 then
			GameTooltip:AddLine("Warming up by the fire", 1.0, 0.8, 0.5)
		else
			GameTooltip:AddLine("Staying cozy by the fire", 1.0, 0.8, 0.5)
		end
		if CC.IsWetEffectActive and CC.IsWetEffectActive() then
			GameTooltip:AddLine("Drying off 3x faster", 0.5, 1.0, 0.5)
		end
		GameTooltip:Show()
	end)
	row.cozyHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Rested status icon (center, replaces fire when resting)
	local RESTED_ICON_SIZE = STATUS_ICON_SIZE
	row.restedIcon = row:CreateTexture(nil, "ARTWORK")
	row.restedIcon:SetSize(RESTED_ICON_SIZE, RESTED_ICON_SIZE)
	row.restedIcon:SetPoint("CENTER", row, "CENTER", 0, 0)
	row.restedIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\restedicon.png")
	row.restedIcon:SetAlpha(0)

	local RESTED_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.restedGlow = row:CreateTexture(nil, "BACKGROUND")
	row.restedGlow:SetSize(RESTED_GLOW_SIZE, RESTED_GLOW_SIZE)
	row.restedGlow:SetPoint("CENTER", row.restedIcon, "CENTER")
	row.restedGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.restedGlow:SetVertexColor(1.0, 0.7, 0.2)
	row.restedGlow:SetBlendMode("ADD")
	row.restedGlow:SetAlpha(0)

	row.restedGlowAG = row.restedGlow:CreateAnimationGroup()
	row.restedGlowAG:SetLooping("REPEAT")
	local restedSpin = row.restedGlowAG:CreateAnimation("Rotation")
	restedSpin:SetDegrees(360)
	restedSpin:SetDuration(4)
	row.restedGlowAG:Play()

	row.restedHitbox = CreateFrame("Frame", nil, row)
	row.restedHitbox:SetSize(RESTED_ICON_SIZE + 8, RESTED_ICON_SIZE + 8)
	row.restedHitbox:SetPoint("CENTER", row.restedIcon, "CENTER")
	row.restedHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.restedHitbox:EnableMouse(true)
	row.restedHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not IsResting() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Rested Area", 1.0, 0.7, 0.2)
		GameTooltip:AddLine("Relaxing in a safe zone", 1.0, 0.8, 0.5)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Hunger drains slower", 0.5, 1.0, 0.5)
		GameTooltip:AddLine("Temperature is more comfortable", 0.5, 1.0, 0.5)
		if CC.IsWetEffectActive and CC.IsWetEffectActive() then
			GameTooltip:AddLine("Drying off 3x faster", 0.5, 1.0, 0.5)
		end
		GameTooltip:Show()
	end)
	row.restedHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Well-fed status icon (right of center)
	local WELLFED_ICON_SIZE = STATUS_ICON_SIZE
	row.wellFedIcon = row:CreateTexture(nil, "ARTWORK")
	row.wellFedIcon:SetSize(WELLFED_ICON_SIZE, WELLFED_ICON_SIZE)
	row.wellFedIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
	row.wellFedIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\wellfedicon.png")
	row.wellFedIcon:SetAlpha(0)

	local WELLFED_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.wellFedGlow = row:CreateTexture(nil, "BACKGROUND")
	row.wellFedGlow:SetSize(WELLFED_GLOW_SIZE, WELLFED_GLOW_SIZE)
	row.wellFedGlow:SetPoint("CENTER", row.wellFedIcon, "CENTER")
	row.wellFedGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.wellFedGlow:SetVertexColor(1.0, 0.95, 0.8)
	row.wellFedGlow:SetBlendMode("ADD")
	row.wellFedGlow:SetAlpha(0)

	row.wellFedGlowAG = row.wellFedGlow:CreateAnimationGroup()
	row.wellFedGlowAG:SetLooping("REPEAT")
	local wellFedSpin = row.wellFedGlowAG:CreateAnimation("Rotation")
	wellFedSpin:SetDegrees(360)
	wellFedSpin:SetDuration(5)
	row.wellFedGlowAG:Play()

	row.wellFedHitbox = CreateFrame("Frame", nil, row)
	row.wellFedHitbox:SetSize(WELLFED_ICON_SIZE + 8, WELLFED_ICON_SIZE + 8)
	row.wellFedHitbox:SetPoint("CENTER", row.wellFedIcon, "CENTER")
	row.wellFedHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.wellFedHitbox:EnableMouse(true)
	row.wellFedHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not CC.HasWellFedBuff or not CC.HasWellFedBuff() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Well Fed", 1.0, 0.95, 0.8)
		local isHealingHunger = CC.IsHungerDecaying and CC.IsHungerDecaying()
		if isHealingHunger then
			GameTooltip:AddLine("Healing hunger, cold resistance +50%", 0.5, 1.0, 0.5)
		else
			GameTooltip:AddLine("Hunger paused, cold resistance +50%", 0.5, 1.0, 0.5)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Food buffs stop hunger drain and", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("reduce cold accumulation by half.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	row.wellFedHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Combat status icon (right of center)
	local COMBAT_ICON_SIZE = STATUS_ICON_SIZE
	row.combatIcon = row:CreateTexture(nil, "ARTWORK")
	row.combatIcon:SetSize(COMBAT_ICON_SIZE, COMBAT_ICON_SIZE)
	row.combatIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
	row.combatIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\combaticon.png")
	row.combatIcon:SetAlpha(0)

	local COMBAT_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.combatGlow = row:CreateTexture(nil, "BACKGROUND")
	row.combatGlow:SetSize(COMBAT_GLOW_SIZE, COMBAT_GLOW_SIZE)
	row.combatGlow:SetPoint("CENTER", row.combatIcon, "CENTER")
	row.combatGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.combatGlow:SetVertexColor(1.0, 0.2, 0.2)
	row.combatGlow:SetBlendMode("ADD")
	row.combatGlow:SetAlpha(0)

	row.combatGlowAG = row.combatGlow:CreateAnimationGroup()
	row.combatGlowAG:SetLooping("REPEAT")
	local combatSpin = row.combatGlowAG:CreateAnimation("Rotation")
	combatSpin:SetDegrees(-360)
	combatSpin:SetDuration(2)
	row.combatGlowAG:Play()

	row.combatHitbox = CreateFrame("Frame", nil, row)
	row.combatHitbox:SetSize(COMBAT_ICON_SIZE + 8, COMBAT_ICON_SIZE + 8)
	row.combatHitbox:SetPoint("CENTER", row.combatIcon, "CENTER")
	row.combatHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.combatHitbox:EnableMouse(true)
	row.combatHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not UnitAffectingCombat("player") then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("In Combat", 1.0, 0.2, 0.2)
		GameTooltip:AddLine("Your survival needs are intensified", 0.8, 0.8, 0.8)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Hunger drains faster during combat", 1.0, 0.6, 0.6)
		GameTooltip:AddLine("Anguish builds more quickly", 1.0, 0.6, 0.6)
		GameTooltip:Show()
	end)
	row.combatHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Alcohol status icon (right of center)
	local ALCOHOL_ICON_SIZE = STATUS_ICON_SIZE
	row.alcoholIcon = row:CreateTexture(nil, "ARTWORK")
	row.alcoholIcon:SetSize(ALCOHOL_ICON_SIZE, ALCOHOL_ICON_SIZE)
	row.alcoholIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
	row.alcoholIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\alcoholicon.png")
	row.alcoholIcon:SetAlpha(0)

	local ALCOHOL_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.alcoholGlow = row:CreateTexture(nil, "BACKGROUND")
	row.alcoholGlow:SetSize(ALCOHOL_GLOW_SIZE, ALCOHOL_GLOW_SIZE)
	row.alcoholGlow:SetPoint("CENTER", row.alcoholIcon, "CENTER")
	row.alcoholGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.alcoholGlow:SetVertexColor(0.7, 0.3, 1.0)
	row.alcoholGlow:SetBlendMode("ADD")
	row.alcoholGlow:SetAlpha(0)

	row.alcoholGlowAG = row.alcoholGlow:CreateAnimationGroup()
	row.alcoholGlowAG:SetLooping("REPEAT")
	local alcoholSpin = row.alcoholGlowAG:CreateAnimation("Rotation")
	alcoholSpin:SetDegrees(360)
	alcoholSpin:SetDuration(4)
	row.alcoholGlowAG:Play()

	row.alcoholHitbox = CreateFrame("Frame", nil, row)
	row.alcoholHitbox:SetSize(ALCOHOL_ICON_SIZE + 8, ALCOHOL_ICON_SIZE + 8)
	row.alcoholHitbox:SetPoint("CENTER", row.alcoholIcon, "CENTER")
	row.alcoholHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.alcoholHitbox:EnableMouse(true)
	row.alcoholHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		local drunkLevel = CC.GetDrunkLevel and CC.GetDrunkLevel() or 0
		if drunkLevel == 0 then
			return
		end
		local levelNames = {
			[1] = "Tipsy",
			[2] = "Drunk",
			[3] = "Completely Smashed"
		}
		local warmthBonus = CC.GetDrunkWarmthBonus and CC.GetDrunkWarmthBonus() or 0
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(levelNames[drunkLevel] or "Tipsy", 0.7, 0.3, 1.0)
		GameTooltip:AddLine("Drunk Jacket Effect", 0.8, 0.8, 0.8)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(string.format("Cold reduced by %d%%", warmthBonus * 100), 0.8, 0.6, 1.0)
		local remaining = CC.GetDrunkRemaining and CC.GetDrunkRemaining() or 0
		if remaining > 0 then
			local minutes = math.floor(remaining / 60)
			local seconds = math.floor(remaining % 60)
			GameTooltip:AddLine(string.format("Fades in %d:%02d", minutes, seconds), 0.6, 0.6, 0.6)
		end
		GameTooltip:Show()
	end)
	row.alcoholHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Mana potion status icon (left of center)
	local MANA_ICON_SIZE = STATUS_ICON_SIZE
	row.manaIcon = row:CreateTexture(nil, "ARTWORK")
	row.manaIcon:SetSize(MANA_ICON_SIZE, MANA_ICON_SIZE)
	row.manaIcon:SetPoint("CENTER", row, "CENTER", -30, 0)
	row.manaIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\manapotionicon.png")
	row.manaIcon:SetAlpha(0)

	local MANA_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.manaGlow = row:CreateTexture(nil, "BACKGROUND")
	row.manaGlow:SetSize(MANA_GLOW_SIZE, MANA_GLOW_SIZE)
	row.manaGlow:SetPoint("CENTER", row.manaIcon, "CENTER")
	row.manaGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.manaGlow:SetVertexColor(0.2, 0.3, 0.9)
	row.manaGlow:SetBlendMode("ADD")
	row.manaGlow:SetAlpha(0)

	row.manaGlowAG = row.manaGlow:CreateAnimationGroup()
	row.manaGlowAG:SetLooping("REPEAT")
	local manaSpin = row.manaGlowAG:CreateAnimation("Rotation")
	manaSpin:SetDegrees(-360)
	manaSpin:SetDuration(5)
	row.manaGlowAG:Play()

	row.manaHitbox = CreateFrame("Frame", nil, row)
	row.manaHitbox:SetSize(MANA_ICON_SIZE + 8, MANA_ICON_SIZE + 8)
	row.manaHitbox:SetPoint("CENTER", row.manaIcon, "CENTER")
	row.manaHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.manaHitbox:EnableMouse(true)
	row.manaHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		local isCooling = CC.IsManaPotionCooling and CC.IsManaPotionCooling()
		local isQuenching = CC.IsManaPotionQuenching and CC.IsManaPotionQuenching()
		if not isCooling and not isQuenching then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Mana Potion", 0.2, 0.3, 0.9)
		GameTooltip:AddLine("Refreshing magical energy", 0.8, 0.8, 0.8)
		GameTooltip:AddLine(" ")
		-- Show cooling effect if temperature enabled
		if isCooling then
			GameTooltip:AddLine("Reducing heat buildup", 0.5, 0.6, 1.0)
			local coolRemaining = CC.GetManaPotionCoolingRemaining and CC.GetManaPotionCoolingRemaining() or 0
			if coolRemaining > 0 then
				local minutes = math.floor(coolRemaining / 60)
				local seconds = math.floor(coolRemaining % 60)
				GameTooltip:AddLine(string.format("  Cooling: %d:%02d", minutes, seconds), 0.6, 0.6, 0.6)
			end
		end
		-- Show quenching effect if thirst enabled
		if isQuenching then
			GameTooltip:AddLine("Quenching thirst (to 50%)", 0.4, 0.7, 1.0)
			local quenchRemaining = CC.GetManaPotionQuenchRemaining and CC.GetManaPotionQuenchRemaining() or 0
			if quenchRemaining > 0 then
				local minutes = math.floor(quenchRemaining / 60)
				local seconds = math.floor(quenchRemaining % 60)
				GameTooltip:AddLine(string.format("  Quenching: %d:%02d", minutes, seconds), 0.6, 0.6, 0.6)
			end
		end
		GameTooltip:Show()
	end)
	row.manaHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Constitution warning icon (right of center)
	local CONST_ICON_SIZE = STATUS_ICON_SIZE
	row.constIcon = row:CreateTexture(nil, "ARTWORK")
	row.constIcon:SetSize(CONST_ICON_SIZE, CONST_ICON_SIZE)
	row.constIcon:SetPoint("CENTER", row, "CENTER", 30, 0)
	row.constIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\constitutionicon.png")
	row.constIcon:SetAlpha(0)

	local CONST_GLOW_SIZE = STATUS_ICON_SIZE + 12
	row.constGlow = row:CreateTexture(nil, "BACKGROUND")
	row.constGlow:SetSize(CONST_GLOW_SIZE, CONST_GLOW_SIZE)
	row.constGlow:SetPoint("CENTER", row.constIcon, "CENTER")
	row.constGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	row.constGlow:SetVertexColor(1.0, 0.2, 0.2)
	row.constGlow:SetBlendMode("ADD")
	row.constGlow:SetAlpha(0)

	row.constGlowAG = row.constGlow:CreateAnimationGroup()
	row.constGlowAG:SetLooping("REPEAT")
	row.constSpin = row.constGlowAG:CreateAnimation("Rotation")
	row.constSpin:SetDegrees(-360)
	row.constSpin:SetDuration(6)
	row.constGlowAG:Play()

	row.constHitbox = CreateFrame("Frame", nil, row)
	row.constHitbox:SetSize(CONST_ICON_SIZE + 8, CONST_ICON_SIZE + 8)
	row.constHitbox:SetPoint("CENTER", row.constIcon, "CENTER")
	row.constHitbox:SetFrameLevel(row:GetFrameLevel() + 10)
	row.constHitbox:EnableMouse(true)
	row.constHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		local constitution = CC.GetConstitution and CC.GetConstitution() or 100
		if constitution > 75 then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if constitution <= 25 then
			GameTooltip:SetText("Critical Condition!", 1.0, 0.2, 0.2)
			GameTooltip:AddLine("Your constitution is dangerously low", 1.0, 0.5, 0.5)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Adventure Mode Restrictions:", 1.0, 0.6, 0.6)
			GameTooltip:AddLine("  Target frame hidden", 1.0, 0.4, 0.4)
			GameTooltip:AddLine("  Nameplates disabled", 1.0, 0.4, 0.4)
			GameTooltip:AddLine("  Player frame hidden", 1.0, 0.4, 0.4)
			GameTooltip:AddLine("  UI and map disabled", 1.0, 0.4, 0.4)
		elseif constitution <= 50 then
			GameTooltip:SetText("Low Constitution", 1.0, 0.5, 0.2)
			GameTooltip:AddLine("Your constitution is getting low", 1.0, 0.7, 0.5)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Adventure Mode Restrictions:", 1.0, 0.7, 0.5)
			GameTooltip:AddLine("  Target frame hidden", 1.0, 0.6, 0.4)
			GameTooltip:AddLine("  Nameplates disabled", 1.0, 0.6, 0.4)
			GameTooltip:AddLine("  Player frame hidden", 1.0, 0.6, 0.4)
		else
			GameTooltip:SetText("Constitution Warning", 1.0, 0.7, 0.3)
			GameTooltip:AddLine("Your constitution is below optimal", 1.0, 0.8, 0.6)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Adventure Mode Restrictions:", 1.0, 0.8, 0.5)
			GameTooltip:AddLine("  Target frame hidden", 1.0, 0.8, 0.5)
			GameTooltip:AddLine("  Nameplates disabled", 1.0, 0.8, 0.5)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(string.format("Current: %.0f%%", constitution), 1, 1, 1)
		GameTooltip:AddLine("Rest or visit an innkeeper to recover", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	row.constHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Status icon state tracking
	row.wetIconAlpha = 0
	row.wetIconTargetAlpha = 0
	row.wetPulsePhase = 0
	row.wetIconBaseSize = STATUS_ICON_SIZE
	row.wetGlowAlpha = 0
	row.swimmingIconAlpha = 0
	row.swimmingGlowAlpha = 0
	row.bandageIconAlpha = 0
	row.bandagePulsePhase = 0
	row.bandageGlowAlpha = 0
	row.potionIconAlpha = 0
	row.potionPulsePhase = 0
	row.potionGlowAlpha = 0
	row.cozyIconAlpha = 0
	row.cozyIconTargetAlpha = 0
	row.cozyPulsePhase = 0
	row.cozyGlowAlpha = 0
	row.restedIconAlpha = 0
	row.restedIconTargetAlpha = 0
	row.restedPulsePhase = 0
	row.restedGlowAlpha = 0
	row.wellFedIconAlpha = 0
	row.wellFedIconTargetAlpha = 0
	row.wellFedPulsePhase = 0
	row.wellFedGlowAlpha = 0
	row.combatIconAlpha = 0
	row.combatIconTargetAlpha = 0
	row.combatPulsePhase = 0
	row.combatGlowAlpha = 0
	row.alcoholIconAlpha = 0
	row.alcoholPulsePhase = 0
	row.alcoholGlowAlpha = 0
	row.manaIconAlpha = 0
	row.manaPulsePhase = 0
	row.manaGlowAlpha = 0
	row.constIconAlpha = 0
	row.constPulsePhase = 0
	row.constGlowAlpha = 0
	row.constLastSpinDuration = 6

	return row
end

-- Create weather toggle button (appears below temperature meter)
local function CreateWeatherButton(parent)
	local button = CreateFrame("Button", "CozierCampsWeatherButton", parent)
	button:SetSize(WEATHER_BUTTON_SIZE, WEATHER_BUTTON_SIZE)

	-- Background (dark circle)
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.bg:SetTexture("Interface\\COMMON\\Indicator-Gray")
	button.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

	-- Circle glow layer (below icon) - weather type specific
	button.circleGlow = button:CreateTexture(nil, "BORDER")
	button.circleGlow:SetSize(WEATHER_BUTTON_SIZE + 20, WEATHER_BUTTON_SIZE + 20)
	button.circleGlow:SetPoint("CENTER", 0, 0.5)
	button.circleGlow:SetAtlas("ChallengeMode-Runes-CircleGlow")
	button.circleGlow:SetBlendMode("ADD")
	button.circleGlow:SetAlpha(0)

	-- Weather icon (using tempicon for now)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetSize(WEATHER_BUTTON_SIZE - 4, WEATHER_BUTTON_SIZE - 4)
	button.icon:SetPoint("CENTER", 0, -1)
	button.icon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\temperatureicon.blp")
	button.icon:SetVertexColor(1, 1, 1, 1)

	-- Relic glow layer (above icon) - weather type specific
	button.relicGlow = button:CreateTexture(nil, "ARTWORK", nil, 1)
	button.relicGlow:SetSize(WEATHER_BUTTON_SIZE + 24, WEATHER_BUTTON_SIZE + 24)
	button.relicGlow:SetPoint("CENTER", 0, 0.5)
	button.relicGlow:SetAtlas("Relic-Water-TraitGlow")
	button.relicGlow:SetBlendMode("ADD")
	button.relicGlow:SetAlpha(0)

	-- Relic glow spin animation
	button.relicGlowAG = button.relicGlow:CreateAnimationGroup()
	button.relicGlowAG:SetLooping("REPEAT")
	local relicSpin = button.relicGlowAG:CreateAnimation("Rotation")
	relicSpin:SetDegrees(-360)
	relicSpin:SetDuration(6)
	button.relicGlowAG:Play()

	-- Paused glow (yellow, for indoor state)
	button.pausedGlow = button:CreateTexture(nil, "OVERLAY")
	button.pausedGlow:SetSize(WEATHER_BUTTON_SIZE + 16, WEATHER_BUTTON_SIZE + 16)
	button.pausedGlow:SetPoint("CENTER")
	button.pausedGlow:SetAtlas(WEATHER_PAUSED_ATLAS)
	button.pausedGlow:SetBlendMode("ADD")
	button.pausedGlow:SetAlpha(0)

	-- Golden glow for active state - outlines the circular icon (kept as fallback)
	button.glow = button:CreateTexture(nil, "OVERLAY")
	button.glow:SetSize(WEATHER_BUTTON_SIZE + 16, WEATHER_BUTTON_SIZE + 16)
	button.glow:SetPoint("CENTER")
	button.glow:SetAtlas("ChallengeMode-KeystoneSlotFrameGlow")
	button.glow:SetBlendMode("ADD")
	button.glow:SetAlpha(0)

	-- Wet status icon (on cold side of temperature bar)
	button.wetIcon = button:CreateTexture(nil, "ARTWORK")
	button.wetIcon:SetSize(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	-- Will be repositioned after temperature meter is created
	button.wetIcon:SetPoint("CENTER", button, "LEFT", -20, -1)
	button.wetIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\weticon.png")
	button.wetIcon:SetAlpha(0)

	-- Wet icon spinning glow (blue)
	local WET_GLOW_SIZE = STATUS_ICON_SIZE + 12
	button.wetGlow = button:CreateTexture(nil, "BACKGROUND")
	button.wetGlow:SetSize(WET_GLOW_SIZE, WET_GLOW_SIZE)
	button.wetGlow:SetPoint("CENTER", button.wetIcon, "CENTER")
	button.wetGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	button.wetGlow:SetVertexColor(0.3, 0.6, 1.0) -- Blue tint
	button.wetGlow:SetBlendMode("ADD")
	button.wetGlow:SetAlpha(0)

	-- Wet glow spin animation
	button.wetGlowAG = button.wetGlow:CreateAnimationGroup()
	button.wetGlowAG:SetLooping("REPEAT")
	local wetSpin = button.wetGlowAG:CreateAnimation("Rotation")
	wetSpin:SetDegrees(-360)
	wetSpin:SetDuration(4)
	button.wetGlowAG:Play()

	-- Wet icon tooltip hitbox
	button.wetHitbox = CreateFrame("Frame", nil, button)
	button.wetHitbox:SetSize(STATUS_ICON_SIZE + 8, STATUS_ICON_SIZE + 8)
	button.wetHitbox:SetPoint("CENTER", button.wetIcon, "CENTER")
	button.wetHitbox:EnableMouse(true)
	button.wetHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not CC.IsWetEffectActive or not CC.IsWetEffectActive() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Wet", 0.3, 0.6, 1.0)
		local remaining = CC.GetWetEffectRemaining and CC.GetWetEffectRemaining() or 0
		local minutes = math.floor(remaining / 60)
		local seconds = math.floor(remaining % 60)
		local timeStr = minutes > 0 and string.format("%d:%02d remaining", minutes, seconds) or
				string.format("%d seconds remaining", seconds)
		GameTooltip:AddLine(timeStr, 1, 1, 1)
		GameTooltip:AddLine(" ")
		local temp = CC.GetTemperature and CC.GetTemperature() or 0
		if temp < 0 then
			GameTooltip:AddLine("You feel colder while wet", 0.5, 0.7, 1.0)
		elseif temp > 0 then
			GameTooltip:AddLine("Evaporative cooling helps you stay cool", 0.5, 0.7, 1.0)
		else
			GameTooltip:AddLine("Being wet affects your temperature", 0.7, 0.7, 0.7)
		end
		local isDrying = CC.isNearFire or IsResting()
		if isDrying then
			GameTooltip:AddLine("Drying off faster near warmth", 1.0, 0.6, 0.2)
		end
		GameTooltip:Show()
	end)
	button.wetHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Cozy/fire status icon (right of weather button) - 30% larger
	local COZY_ICON_SIZE = STATUS_ICON_SIZE * 1.3
	button.cozyIcon = button:CreateTexture(nil, "ARTWORK")
	button.cozyIcon:SetSize(COZY_ICON_SIZE, COZY_ICON_SIZE)
	button.cozyIcon:SetPoint("CENTER", button, "RIGHT", 20, -1)
	button.cozyIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\cozyicon.png")
	button.cozyIcon:SetAlpha(0)

	-- Cozy icon spinning glow (orange/yellow) - same size as wet glow
	local COZY_GLOW_SIZE = STATUS_ICON_SIZE + 12
	button.cozyGlow = button:CreateTexture(nil, "BACKGROUND")
	button.cozyGlow:SetSize(COZY_GLOW_SIZE, COZY_GLOW_SIZE)
	button.cozyGlow:SetPoint("CENTER", button.cozyIcon, "CENTER")
	button.cozyGlow:SetAtlas("ArtifactsFX-SpinningGlowys")
	button.cozyGlow:SetVertexColor(1.0, 0.7, 0.2) -- Orange/yellow tint
	button.cozyGlow:SetBlendMode("ADD")
	button.cozyGlow:SetAlpha(0)

	-- Cozy glow spin animation
	button.cozyGlowAG = button.cozyGlow:CreateAnimationGroup()
	button.cozyGlowAG:SetLooping("REPEAT")
	local cozySpin = button.cozyGlowAG:CreateAnimation("Rotation")
	cozySpin:SetDegrees(360)
	cozySpin:SetDuration(3)
	button.cozyGlowAG:Play()

	-- Cozy icon tooltip hitbox
	button.cozyHitbox = CreateFrame("Frame", nil, button)
	button.cozyHitbox:SetSize(COZY_ICON_SIZE + 8, COZY_ICON_SIZE + 8)
	button.cozyHitbox:SetPoint("CENTER", button.cozyIcon, "CENTER")
	button.cozyHitbox:EnableMouse(true)
	button.cozyHitbox:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		if not CC.isNearFire then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Near Campfire", 1.0, 0.7, 0.2)
		local temp = CC.GetTemperature and CC.GetTemperature() or 0
		if temp < 0 then
			GameTooltip:AddLine("Warming up by the fire", 1.0, 0.8, 0.5)
		else
			GameTooltip:AddLine("Staying cozy by the fire", 1.0, 0.8, 0.5)
		end
		if CC.IsWetEffectActive and CC.IsWetEffectActive() then
			GameTooltip:AddLine("Drying off 3x faster", 0.5, 1.0, 0.5)
		end
		GameTooltip:Show()
	end)
	button.cozyHitbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Status icon state tracking
	button.wetIconAlpha = 0
	button.wetIconTargetAlpha = 0
	button.wetPulsePhase = 0
	button.wetIconBaseSize = STATUS_ICON_SIZE
	button.wetGlowAlpha = 0
	button.cozyIconAlpha = 0
	button.cozyIconTargetAlpha = 0
	button.cozyPulsePhase = 0
	button.cozyIconBaseSize = COZY_ICON_SIZE
	button.cozyGlowAlpha = 0

	-- State tracking
	button.currentWeatherType = WEATHER_TYPE_NONE
	button.isActive = false
	button.isPaused = false -- Indoor paused state
	button.glowAlpha = 0
	button.targetGlowAlpha = 0
	button.circleGlowAlpha = 0
	button.relicGlowAlpha = 0
	button.pausedGlowAlpha = 0
	button.iconAlpha = 1
	button.targetIconAlpha = 1
	button.pulsePhase = 0
	button.relicPulsePhase = 0

	-- Click handler
	button:SetScript("OnClick", function()
		if CC.ToggleManualWeather then
			local success = CC.ToggleManualWeather()
			if success then
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			end
		end
	end)

	-- Tooltip
	button:SetScript("OnEnter", function(self)
		local tooltipMode = CC.GetSetting and CC.GetSetting("tooltipDisplayMode") or "detailed"
		if tooltipMode == "disabled" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local weatherNames = {
			[WEATHER_TYPE_NONE] = "No Weather",
			[WEATHER_TYPE_RAIN] = "Rain",
			[WEATHER_TYPE_SNOW] = "Snow",
			[WEATHER_TYPE_DUST] = "Dust Storm",
			[WEATHER_TYPE_STORM] = "Arcane Storm"
		}
		local weatherName = weatherNames[self.currentWeatherType] or "Unknown"
		GameTooltip:SetText("Weather Toggle", 1, 0.82, 0)
		GameTooltip:AddLine(" ")
		if self.currentWeatherType == WEATHER_TYPE_NONE then
			GameTooltip:AddLine("No weather possible in this zone", 0.5, 0.5, 0.5)
		else
			GameTooltip:AddLine("Zone weather: " .. weatherName, 0.8, 0.8, 0.8)
			GameTooltip:AddLine(" ")
			if self.isPaused then
				GameTooltip:AddLine("Weather is PAUSED", 1.0, 0.85, 0.2)
				GameTooltip:AddLine("Reason: You are indoors", 0.6, 0.6, 0.6)
				GameTooltip:AddLine("Click to disable", 0.6, 0.6, 0.6)
			elseif self.isActive then
				GameTooltip:AddLine("Weather is ACTIVE", 0.2, 1.0, 0.2)
				GameTooltip:AddLine("Click to disable", 0.6, 0.6, 0.6)
			else
				GameTooltip:AddLine("Weather is inactive", 0.6, 0.6, 0.6)
				GameTooltip:AddLine("Click to enable", 0.6, 0.6, 0.6)
			end
			GameTooltip:AddLine(" ")
			if self.currentWeatherType == WEATHER_TYPE_RAIN then
				GameTooltip:AddLine("Effect: Cooling (-0.4/sec)", 0.5, 0.7, 1.0)
			elseif self.currentWeatherType == WEATHER_TYPE_SNOW then
				GameTooltip:AddLine("Effect: Strong cooling (-1.0/sec)", 0.3, 0.5, 1.0)
			elseif self.currentWeatherType == WEATHER_TYPE_DUST then
				GameTooltip:AddLine("Effect: Heating (+1.0/sec)", 1.0, 0.6, 0.3)
			elseif self.currentWeatherType == WEATHER_TYPE_STORM then
				GameTooltip:AddLine("Effect: Arcane warming (+0.5/sec)", 0.7, 0.5, 1.0)
			end
			if self.isPaused then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("(Effect paused while indoors)", 1.0, 0.85, 0.2)
			end
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)

	return button
end

-- Update weather button state
local function UpdateWeatherButton(elapsed)
	if not weatherButton then
		return
	end

	-- Check if manual weather feature is enabled
	local manualWeatherEnabled = CC.GetSetting and CC.GetSetting("manualWeatherEnabled")

	-- Legacy: older TBC builds attached wet/cozy icons to the weather button.
	-- Keep those hidden; statusIconsRow handles them now.
	if weatherButton.wetIcon then
		weatherButton.wetIcon:SetAlpha(0)
	end
	if weatherButton.wetGlow then
		weatherButton.wetGlow:SetAlpha(0)
	end
	if weatherButton.cozyIcon then
		weatherButton.cozyIcon:SetAlpha(0)
	end
	if weatherButton.cozyGlow then
		weatherButton.cozyGlow:SetAlpha(0)
	end
	if weatherButton.wetHitbox then
		weatherButton.wetHitbox:EnableMouse(false)
	end
	if weatherButton.cozyHitbox then
		weatherButton.cozyHitbox:EnableMouse(false)
	end

	if not manualWeatherEnabled then
		weatherButton:Hide()
		return
	end

	-- Get current weather state
	local weatherType = CC.GetZoneWeatherType and CC.GetZoneWeatherType() or WEATHER_TYPE_NONE
	local isActive = CC.IsManualWeatherActive and CC.IsManualWeatherActive() or false
	local isIndoors = CC.IsWeatherPaused and CC.IsWeatherPaused() or false

	-- Update button state
	weatherButton.currentWeatherType = weatherType
	weatherButton.isActive = isActive
	weatherButton.isPaused = isActive and isIndoors

	if weatherType == WEATHER_TYPE_NONE then
		weatherButton:Hide()
		return
	end

	weatherButton:Show()

	-- Show button elements for zones with weather
	weatherButton.bg:SetAlpha(0.8)
	weatherButton.icon:SetAlpha(1)

	-- Update icon color based on weather type
	weatherButton:Enable()
	if weatherType == WEATHER_TYPE_RAIN then
		weatherButton.icon:SetVertexColor(0.5, 0.7, 1.0, 1) -- Blue for rain
	elseif weatherType == WEATHER_TYPE_SNOW then
		weatherButton.icon:SetVertexColor(0.8, 0.9, 1.0, 1) -- Light blue/white for snow
	elseif weatherType == WEATHER_TYPE_DUST then
		weatherButton.icon:SetVertexColor(1.0, 0.7, 0.3, 1) -- Orange/tan for dust
	elseif weatherType == WEATHER_TYPE_STORM then
		weatherButton.icon:SetVertexColor(0.7, 0.5, 1.0, 1) -- Purple for arcane storm
	end

	-- Update weather-specific glow atlases and sizes
	local glowConfig = WEATHER_GLOW_ATLASES[weatherType]
	if glowConfig then
		weatherButton.circleGlow:SetAtlas(glowConfig.circleGlow)
		weatherButton.circleGlow:SetVertexColor(glowConfig.circleColor[1], glowConfig.circleColor[2],
				glowConfig.circleColor[3], 1)
		weatherButton.circleGlow:SetSize(glowConfig.circleSize, glowConfig.circleSize)
		weatherButton.relicGlow:SetAtlas(glowConfig.relicGlow)
		weatherButton.relicGlow:SetVertexColor(glowConfig.relicColor[1], glowConfig.relicColor[2],
				glowConfig.relicColor[3], 1)
		weatherButton.relicGlow:SetSize(glowConfig.relicSize, glowConfig.relicSize)
	end

	-- Determine target alphas based on state
	local targetCircleAlpha = 0
	local targetRelicAlpha = 0
	local targetPausedAlpha = 0

	if isActive then
		if weatherButton.isPaused then
			-- Paused state: show yellow paused glow instead of weather glows
			targetPausedAlpha = 0.8
			targetCircleAlpha = 0
			targetRelicAlpha = 0
		else
			-- Active state: show weather-specific glows
			targetCircleAlpha = 0.6
			targetRelicAlpha = 0.8
		end
	end

	-- Animate circle glow (subtle pulse)
	if targetCircleAlpha > 0 then
		weatherButton.pulsePhase = weatherButton.pulsePhase + elapsed * 1.5
		local pulseMod = 0.7 + 0.3 * math.sin(weatherButton.pulsePhase * math.pi * 2)
		targetCircleAlpha = targetCircleAlpha * pulseMod
	end

	-- Animate relic glow (slightly different pulse for layered effect)
	if targetRelicAlpha > 0 then
		weatherButton.relicPulsePhase = weatherButton.relicPulsePhase + elapsed * 2.0
		local relicPulseMod = 0.6 + 0.4 * math.sin(weatherButton.relicPulsePhase * math.pi * 2)
		targetRelicAlpha = targetRelicAlpha * relicPulseMod
	end

	-- Animate paused glow (steady pulse)
	if targetPausedAlpha > 0 then
		weatherButton.pulsePhase = weatherButton.pulsePhase + elapsed * 1.0
		local pausedPulseMod = 0.7 + 0.3 * math.sin(weatherButton.pulsePhase * math.pi * 2)
		targetPausedAlpha = targetPausedAlpha * pausedPulseMod
	end

	-- Smooth transitions for all glows (using LerpAlpha defined at top of function)
	weatherButton.circleGlowAlpha = LerpAlpha(weatherButton.circleGlowAlpha, targetCircleAlpha, 5.0)
	weatherButton.relicGlowAlpha = LerpAlpha(weatherButton.relicGlowAlpha, targetRelicAlpha, 5.0)
	weatherButton.pausedGlowAlpha = LerpAlpha(weatherButton.pausedGlowAlpha, targetPausedAlpha, 5.0)

	-- Apply alphas
	weatherButton.circleGlow:SetAlpha(weatherButton.circleGlowAlpha)
	weatherButton.relicGlow:SetAlpha(weatherButton.relicGlowAlpha)
	weatherButton.pausedGlow:SetAlpha(weatherButton.pausedGlowAlpha)

	-- Hide the old golden glow (replaced by weather-specific glows)
	weatherButton.glow:SetAlpha(0)
end

-- Update status icons (wet, cozy/rested, combat, etc.) - separate from weather button
local function UpdateStatusIcons(elapsed)
	if not statusIconsRow then
		return
	end

	local temperatureEnabled = CC.GetSetting and CC.GetSetting("temperatureEnabled") or false
	local hungerEnabled = CC.GetSetting and CC.GetSetting("hungerEnabled") or false
	local thirstEnabled = CC.GetSetting and CC.GetSetting("thirstEnabled") or false
	local anguishEnabled = CC.GetSetting and CC.GetSetting("AnguishEnabled") or false

	local isWet = temperatureEnabled and CC.IsWetEffectActive and CC.IsWetEffectActive() or false
	local isBandaging = anguishEnabled and CC.IsBandaging and CC.IsBandaging() or false
	local isPotionHealing = anguishEnabled and CC.IsPotionHealing and CC.IsPotionHealing() or false
	local isNearFire = CC.isNearFire or false
	local isWellFed = (hungerEnabled or temperatureEnabled) and CC.HasWellFedBuff and CC.HasWellFedBuff() or false
	local isInCombat = UnitAffectingCombat("player")
	local isDrunk = temperatureEnabled and CC.IsDrunk and CC.IsDrunk() or false
	local drunkLevel = CC.GetDrunkLevel and CC.GetDrunkLevel() or 0
	local isManaCooling = (temperatureEnabled and CC.IsManaPotionCooling and CC.IsManaPotionCooling()) or
			(thirstEnabled and CC.IsManaPotionQuenching and CC.IsManaPotionQuenching()) or false
	local constitution = CC.GetConstitution and CC.GetConstitution() or 100
	local isLowConstitution = constitution <= 75

	-- Wet icon
	if isWet then
		statusIconsRow.wetPulsePhase = statusIconsRow.wetPulsePhase + elapsed * 0.8
		local wetAlphaMod = 0.85 + 0.15 * math.sin(statusIconsRow.wetPulsePhase * math.pi * 2)
		statusIconsRow.wetIconAlpha = LerpAlpha(statusIconsRow.wetIconAlpha, wetAlphaMod, 4.0, elapsed)
	else
		statusIconsRow.wetIconAlpha = LerpAlpha(statusIconsRow.wetIconAlpha, 0, 4.0, elapsed)
	end
	statusIconsRow.wetIcon:SetAlpha(statusIconsRow.wetIconAlpha)
	statusIconsRow.wetGlowAlpha = LerpAlpha(statusIconsRow.wetGlowAlpha, isWet and 0.6 or 0, 4.0, elapsed)
	statusIconsRow.wetGlow:SetAlpha(statusIconsRow.wetGlowAlpha)

	-- Swimming icon
	local isSwimming = IsSwimming()
	statusIconsRow.swimmingIconAlpha = LerpAlpha(statusIconsRow.swimmingIconAlpha, isSwimming and 1.0 or 0, 4.0, elapsed)
	statusIconsRow.swimmingIcon:SetAlpha(statusIconsRow.swimmingIconAlpha)
	statusIconsRow.swimmingGlowAlpha = LerpAlpha(statusIconsRow.swimmingGlowAlpha, isSwimming and 0.6 or 0, 4.0, elapsed)
	statusIconsRow.swimmingGlow:SetAlpha(statusIconsRow.swimmingGlowAlpha)

	-- Bandage icon
	if isBandaging then
		statusIconsRow.bandagePulsePhase = statusIconsRow.bandagePulsePhase + elapsed * 1.0
		local bandageAlphaMod = 0.85 + 0.15 * math.sin(statusIconsRow.bandagePulsePhase * math.pi * 2)
		statusIconsRow.bandageIconAlpha = LerpAlpha(statusIconsRow.bandageIconAlpha, bandageAlphaMod, 4.0, elapsed)
	else
		statusIconsRow.bandageIconAlpha = LerpAlpha(statusIconsRow.bandageIconAlpha, 0, 4.0, elapsed)
	end
	statusIconsRow.bandageIcon:SetAlpha(statusIconsRow.bandageIconAlpha)
	statusIconsRow.bandageGlowAlpha = LerpAlpha(statusIconsRow.bandageGlowAlpha, isBandaging and 0.6 or 0, 4.0, elapsed)
	statusIconsRow.bandageGlow:SetAlpha(statusIconsRow.bandageGlowAlpha)

	-- Potion icon
	if isPotionHealing then
		statusIconsRow.potionPulsePhase = statusIconsRow.potionPulsePhase + elapsed * 0.7
		local potionAlphaMod = 0.85 + 0.15 * math.sin(statusIconsRow.potionPulsePhase * math.pi * 2)
		statusIconsRow.potionIconAlpha = LerpAlpha(statusIconsRow.potionIconAlpha, potionAlphaMod, 4.0, elapsed)
	else
		statusIconsRow.potionIconAlpha = LerpAlpha(statusIconsRow.potionIconAlpha, 0, 4.0, elapsed)
	end
	statusIconsRow.potionIcon:SetAlpha(statusIconsRow.potionIconAlpha)
	statusIconsRow.potionGlowAlpha = LerpAlpha(statusIconsRow.potionGlowAlpha, isPotionHealing and 0.5 or 0, 4.0,
			elapsed)
	statusIconsRow.potionGlow:SetAlpha(statusIconsRow.potionGlowAlpha)

	-- Cozy/fire icon
	if isNearFire then
		statusIconsRow.cozyPulsePhase = statusIconsRow.cozyPulsePhase + elapsed * 0.6
		local cozyAlphaMod = 0.85 + 0.15 * math.sin(statusIconsRow.cozyPulsePhase * math.pi * 2)
		statusIconsRow.cozyIconAlpha = LerpAlpha(statusIconsRow.cozyIconAlpha, cozyAlphaMod, 4.0, elapsed)
	else
		statusIconsRow.cozyIconAlpha = LerpAlpha(statusIconsRow.cozyIconAlpha, 0, 4.0, elapsed)
	end
	statusIconsRow.cozyIcon:SetAlpha(statusIconsRow.cozyIconAlpha)
	statusIconsRow.cozyGlowAlpha = LerpAlpha(statusIconsRow.cozyGlowAlpha, isNearFire and 0.7 or 0, 4.0, elapsed)
	statusIconsRow.cozyGlow:SetAlpha(statusIconsRow.cozyGlowAlpha)

	-- Rested icon
	local isRested = IsResting() and not isNearFire
	if isRested then
		statusIconsRow.restedPulsePhase = statusIconsRow.restedPulsePhase + elapsed * 0.5
		local restedAlphaMod = 0.85 + 0.15 * math.sin(statusIconsRow.restedPulsePhase * math.pi * 2)
		statusIconsRow.restedIconAlpha = LerpAlpha(statusIconsRow.restedIconAlpha, restedAlphaMod, 4.0, elapsed)
	else
		statusIconsRow.restedIconAlpha = LerpAlpha(statusIconsRow.restedIconAlpha, 0, 4.0, elapsed)
	end
	statusIconsRow.restedIcon:SetAlpha(statusIconsRow.restedIconAlpha)
	statusIconsRow.restedGlowAlpha = LerpAlpha(statusIconsRow.restedGlowAlpha, isRested and 0.7 or 0, 4.0, elapsed)
	statusIconsRow.restedGlow:SetAlpha(statusIconsRow.restedGlowAlpha)

	-- Well-fed icon
	if isWellFed then
		statusIconsRow.wellFedPulsePhase = statusIconsRow.wellFedPulsePhase + elapsed * 0.5
		local wellFedAlphaMod = 0.92 + 0.08 * math.sin(statusIconsRow.wellFedPulsePhase * math.pi * 2)
		statusIconsRow.wellFedIconAlpha = LerpAlpha(statusIconsRow.wellFedIconAlpha, wellFedAlphaMod, 4.0, elapsed)
	else
		statusIconsRow.wellFedIconAlpha = LerpAlpha(statusIconsRow.wellFedIconAlpha, 0, 4.0, elapsed)
	end
	statusIconsRow.wellFedIcon:SetAlpha(statusIconsRow.wellFedIconAlpha)
	statusIconsRow.wellFedGlowAlpha = LerpAlpha(statusIconsRow.wellFedGlowAlpha, isWellFed and 0.5 or 0, 4.0, elapsed)
	statusIconsRow.wellFedGlow:SetAlpha(statusIconsRow.wellFedGlowAlpha)

	-- Combat icon
	if isInCombat then
		statusIconsRow.combatPulsePhase = statusIconsRow.combatPulsePhase + elapsed * 1.2
		local combatAlphaMod = 0.80 + 0.20 * math.sin(statusIconsRow.combatPulsePhase * math.pi * 2)
		statusIconsRow.combatIconAlpha = LerpAlpha(statusIconsRow.combatIconAlpha, combatAlphaMod, 4.0, elapsed)
	else
		statusIconsRow.combatIconAlpha = LerpAlpha(statusIconsRow.combatIconAlpha, 0, 4.0, elapsed)
	end
	statusIconsRow.combatIcon:SetAlpha(statusIconsRow.combatIconAlpha)
	statusIconsRow.combatGlowAlpha = LerpAlpha(statusIconsRow.combatGlowAlpha, isInCombat and 0.7 or 0, 4.0, elapsed)
	statusIconsRow.combatGlow:SetAlpha(statusIconsRow.combatGlowAlpha)

	-- Alcohol icon
	if isDrunk then
		statusIconsRow.alcoholPulsePhase = statusIconsRow.alcoholPulsePhase + elapsed * 0.6
		local alcoholAlphaMod = 0.85 + 0.15 * math.sin(statusIconsRow.alcoholPulsePhase * math.pi * 2)
		statusIconsRow.alcoholIconAlpha = LerpAlpha(statusIconsRow.alcoholIconAlpha, alcoholAlphaMod, 4.0, elapsed)
	else
		statusIconsRow.alcoholIconAlpha = LerpAlpha(statusIconsRow.alcoholIconAlpha, 0, 4.0, elapsed)
	end
	statusIconsRow.alcoholIcon:SetAlpha(statusIconsRow.alcoholIconAlpha)
	local alcoholGlowTarget = isDrunk and (0.4 + drunkLevel * 0.15) or 0
	statusIconsRow.alcoholGlowAlpha = LerpAlpha(statusIconsRow.alcoholGlowAlpha, alcoholGlowTarget, 4.0, elapsed)
	statusIconsRow.alcoholGlow:SetAlpha(statusIconsRow.alcoholGlowAlpha)

	-- Mana potion icon
	if isManaCooling then
		statusIconsRow.manaPulsePhase = statusIconsRow.manaPulsePhase + elapsed * 0.5
		local manaAlphaMod = 0.85 + 0.15 * math.sin(statusIconsRow.manaPulsePhase * math.pi * 2)
		statusIconsRow.manaIconAlpha = LerpAlpha(statusIconsRow.manaIconAlpha, manaAlphaMod, 4.0, elapsed)
	else
		statusIconsRow.manaIconAlpha = LerpAlpha(statusIconsRow.manaIconAlpha, 0, 4.0, elapsed)
	end
	statusIconsRow.manaIcon:SetAlpha(statusIconsRow.manaIconAlpha)
	statusIconsRow.manaGlowAlpha = LerpAlpha(statusIconsRow.manaGlowAlpha, isManaCooling and 0.6 or 0, 4.0, elapsed)
	statusIconsRow.manaGlow:SetAlpha(statusIconsRow.manaGlowAlpha)

	-- Constitution icon
	if isLowConstitution then
		statusIconsRow.constPulsePhase = statusIconsRow.constPulsePhase + elapsed * 0.8
		local constAlphaMod = 0.85 + 0.15 * math.sin(statusIconsRow.constPulsePhase * math.pi * 2)
		statusIconsRow.constIconAlpha = LerpAlpha(statusIconsRow.constIconAlpha, constAlphaMod, 4.0, elapsed)

		local spinDuration
		if constitution <= 25 then
			spinDuration = 2
			-- Swap to critical icon
			statusIconsRow.constIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\constitution25.png")
		elseif constitution <= 50 then
			spinDuration = 4
			statusIconsRow.constIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\constitutionicon.png")
		else
			spinDuration = 6
			statusIconsRow.constIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\constitutionicon.png")
		end
		if spinDuration ~= statusIconsRow.constLastSpinDuration then
			statusIconsRow.constSpin:SetDuration(spinDuration)
			statusIconsRow.constGlowAG:Stop()
			statusIconsRow.constGlowAG:Play()
			statusIconsRow.constLastSpinDuration = spinDuration
		end
	else
		statusIconsRow.constIconAlpha = LerpAlpha(statusIconsRow.constIconAlpha, 0, 4.0, elapsed)
		statusIconsRow.constIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\constitutionicon.png")
	end
	statusIconsRow.constIcon:SetAlpha(statusIconsRow.constIconAlpha)

	local constGlowTarget = 0
	if isLowConstitution then
		if constitution <= 25 then
			constGlowTarget = 0.9
		elseif constitution <= 50 then
			constGlowTarget = 0.7
		else
			constGlowTarget = 0.5
		end
	end
	statusIconsRow.constGlowAlpha = LerpAlpha(statusIconsRow.constGlowAlpha, constGlowTarget, 4.0, elapsed)
	statusIconsRow.constGlow:SetAlpha(statusIconsRow.constGlowAlpha)

	-- Enable/disable hitboxes based on visibility (prevents invisible mouse-blockers)
	statusIconsRow.wetHitbox:EnableMouse(statusIconsRow.wetIconAlpha > 0.1)
	statusIconsRow.swimmingHitbox:EnableMouse(statusIconsRow.swimmingIconAlpha > 0.1)
	statusIconsRow.bandageHitbox:EnableMouse(statusIconsRow.bandageIconAlpha > 0.1)
	statusIconsRow.potionHitbox:EnableMouse(statusIconsRow.potionIconAlpha > 0.1)
	statusIconsRow.cozyHitbox:EnableMouse(statusIconsRow.cozyIconAlpha > 0.1)
	statusIconsRow.restedHitbox:EnableMouse(statusIconsRow.restedIconAlpha > 0.1)
	statusIconsRow.wellFedHitbox:EnableMouse(statusIconsRow.wellFedIconAlpha > 0.1)
	statusIconsRow.combatHitbox:EnableMouse(statusIconsRow.combatIconAlpha > 0.1)
	statusIconsRow.alcoholHitbox:EnableMouse(statusIconsRow.alcoholIconAlpha > 0.1)
	statusIconsRow.manaHitbox:EnableMouse(statusIconsRow.manaIconAlpha > 0.1)
	statusIconsRow.constHitbox:EnableMouse(statusIconsRow.constIconAlpha > 0.1)

	-- Dynamic positioning toward center
	local ICON_SPACING = 28

	statusIconsRow.cozyIcon:ClearAllPoints()
	statusIconsRow.cozyIcon:SetPoint("CENTER", statusIconsRow, "CENTER", 0, 0)
	statusIconsRow.restedIcon:ClearAllPoints()
	statusIconsRow.restedIcon:SetPoint("CENTER", statusIconsRow, "CENTER", 0, 0)

	local leftIcons = {}
	if statusIconsRow.manaIconAlpha > 0.01 or isManaCooling then
		table.insert(leftIcons, {
			icon = statusIconsRow.manaIcon
		})
	end
	if statusIconsRow.potionIconAlpha > 0.01 or isPotionHealing then
		table.insert(leftIcons, {
			icon = statusIconsRow.potionIcon
		})
	end
	if statusIconsRow.bandageIconAlpha > 0.01 or isBandaging then
		table.insert(leftIcons, {
			icon = statusIconsRow.bandageIcon
		})
	end
	if statusIconsRow.swimmingIconAlpha > 0.01 or isSwimming then
		table.insert(leftIcons, {
			icon = statusIconsRow.swimmingIcon
		})
	end
	if statusIconsRow.wetIconAlpha > 0.01 or isWet then
		table.insert(leftIcons, {
			icon = statusIconsRow.wetIcon
		})
	end

	for i, iconData in ipairs(leftIcons) do
		local xOffset = -ICON_SPACING * i
		iconData.icon:ClearAllPoints()
		iconData.icon:SetPoint("CENTER", statusIconsRow, "CENTER", xOffset, 0)
	end

	local rightIcons = {}
	if statusIconsRow.wellFedIconAlpha > 0.01 or isWellFed then
		table.insert(rightIcons, {
			icon = statusIconsRow.wellFedIcon
		})
	end
	if statusIconsRow.alcoholIconAlpha > 0.01 or isDrunk then
		table.insert(rightIcons, {
			icon = statusIconsRow.alcoholIcon
		})
	end
	if statusIconsRow.combatIconAlpha > 0.01 or isInCombat then
		table.insert(rightIcons, {
			icon = statusIconsRow.combatIcon
		})
	end
	if statusIconsRow.constIconAlpha > 0.01 or isLowConstitution then
		table.insert(rightIcons, {
			icon = statusIconsRow.constIcon
		})
	end

	for i, iconData in ipairs(rightIcons) do
		local xOffset = ICON_SPACING * i
		iconData.icon:ClearAllPoints()
		iconData.icon:SetPoint("CENTER", statusIconsRow, "CENTER", xOffset, 0)
	end
end

-- Reposition meters dynamically based on which are enabled (condense gaps)
-- Order: Anguish, Exhaustion, Hunger, Thirst, Temperature (always bottom when enabled)
local function RepositionMeters()
	if not metersContainer then
		return
	end

	local anguishEnabled = CC.GetSetting and CC.GetSetting("AnguishEnabled")
	local exhaustionEnabled = CC.GetSetting and CC.GetSetting("exhaustionEnabled")
	local hungerEnabled = CC.GetSetting and CC.GetSetting("hungerEnabled")
	local thirstEnabled = CC.GetSetting and CC.GetSetting("thirstEnabled")
	local temperatureEnabled = CC.GetSetting and CC.GetSetting("temperatureEnabled")
	local constitutionEnabled = CC.GetSetting and CC.GetSetting("constitutionEnabled")
	local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"

	local visibleCount = 0

	if displayMode == "vial" then
		-- VIAL MODE: Horizontal layout for vials, temperature bar centered below
		local vialFrameWidth = VIAL_SIZE + 40 -- Width of each vial meter frame
		local vialSpacing = vialFrameWidth + VIAL_SPACING -- Brings vials closer with negative spacing
		local startX = 10
		local xOffset = startX
		local vialCount = 0

		-- Position Constitution vial first (leftmost) - only if enabled
		if constitutionEnabled and constitutionMeter then
			constitutionMeter:ClearAllPoints()
			constitutionMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
			constitutionMeter:Show()
			xOffset = xOffset + vialSpacing
			vialCount = vialCount + 1
			visibleCount = visibleCount + 1
		elseif constitutionMeter then
			constitutionMeter:Hide()
		end

		-- Position other vials horizontally
		if anguishEnabled and AnguishMeter then
			AnguishMeter:ClearAllPoints()
			AnguishMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
			xOffset = xOffset + vialSpacing
			vialCount = vialCount + 1
			visibleCount = visibleCount + 1
		end

		if exhaustionEnabled and exhaustionMeter then
			exhaustionMeter:ClearAllPoints()
			exhaustionMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
			xOffset = xOffset + vialSpacing
			vialCount = vialCount + 1
			visibleCount = visibleCount + 1
		end

		if hungerEnabled and hungerMeter then
			hungerMeter:ClearAllPoints()
			hungerMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
			xOffset = xOffset + vialSpacing
			vialCount = vialCount + 1
			visibleCount = visibleCount + 1
		end

		if thirstEnabled and thirstMeter then
			thirstMeter:ClearAllPoints()
			thirstMeter:SetPoint("LEFT", metersContainer, "LEFT", xOffset, 20)
			xOffset = xOffset + vialSpacing
			vialCount = vialCount + 1
			visibleCount = visibleCount + 1
		end

		-- Calculate total vials width for centering temperature bar
		local totalVialsWidth = (vialCount * vialSpacing) - VIAL_SPACING
		local vialsCenter = startX + (totalVialsWidth / 2)

		-- Position Temperature as a BAR centered below the vials
		-- Nudge right by 3 pixels to visually center the bar (accounting for icon sizes)
		if temperatureEnabled and temperatureMeter then
			temperatureMeter:ClearAllPoints()
			temperatureMeter:SetPoint("TOP", metersContainer, "TOPLEFT", vialsCenter + 3, -VIAL_DISPLAY_SIZE - 35)
			visibleCount = visibleCount + 1

			-- If temperature is the only enabled meter in vial mode, use bar mode width
			if vialCount == 0 then
				ResizeTemperatureMeter(temperatureMeter, TEMP_METER_WIDTH)
			else
				local tempBarWidth = totalVialsWidth - 10 -- Slightly narrower than total vials span
				ResizeTemperatureMeter(temperatureMeter, tempBarWidth)
			end

			-- Position weather button below temperature bar
			if weatherButton then
				weatherButton:ClearAllPoints()
				weatherButton:SetPoint("TOP", temperatureMeter, "BOTTOM", 0, -METER_SPACING)
			end
		end

		-- Position status icons row just above the vials, aligned with temperature bar center
		local hitPadding = 15
		local containerCenterX = (totalVialsWidth + 20 + hitPadding * 2) / 2
		local tempCenterX = vialsCenter + 3
		local statusXOffset = tempCenterX - containerCenterX

		if statusIconsRow then
			statusIconsRow:ClearAllPoints()
			if vialCount == 0 and temperatureEnabled and temperatureMeter then
				statusIconsRow:SetPoint("BOTTOM", temperatureMeter, "TOP", 0, 5)
			else
				statusIconsRow:SetPoint("BOTTOM", metersContainer, "CENTER", statusXOffset,
						20 + VIAL_DISPLAY_SIZE / 2 + 6)
			end
			statusIconsRow:SetSize(totalVialsWidth > 0 and totalVialsWidth or 100, STATUS_ROW_HEIGHT)
		end

		-- Update container size for vial mode
		local contentWidth = totalVialsWidth + 20
		local contentHeight = VIAL_DISPLAY_SIZE + METER_HEIGHT + 75 -- Extra space for glow clearance
		metersContainer:SetSize(contentWidth + (hitPadding * 2), contentHeight + (hitPadding * 2))

	else
		-- BAR MODE: Vertical layout (original)
		-- Start below the status icons row
		local yOffset = -5 - STATUS_ROW_HEIGHT

		-- Position status icons row at the top of the container
		if statusIconsRow then
			statusIconsRow:ClearAllPoints()
			statusIconsRow:SetPoint("TOP", metersContainer, "TOP", 0, -5)
			statusIconsRow:SetSize(METER_WIDTH, STATUS_ROW_HEIGHT)
		end

		-- Position Constitution bar FIRST (always at top when enabled)
		if constitutionEnabled and constitutionBarMeter then
			constitutionBarMeter:ClearAllPoints()
			constitutionBarMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
			constitutionBarMeter:Show()
			yOffset = yOffset - METER_HEIGHT - METER_SPACING
			visibleCount = visibleCount + 1
		elseif constitutionBarMeter then
			constitutionBarMeter:Hide()
		end

		-- Position Anguish
		if anguishEnabled and AnguishMeter then
			AnguishMeter:ClearAllPoints()
			AnguishMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
			AnguishMeter:Show()
			yOffset = yOffset - METER_HEIGHT - METER_SPACING
			visibleCount = visibleCount + 1
		elseif AnguishMeter then
			AnguishMeter:Hide()
		end

		-- Position Exhaustion
		if exhaustionEnabled and exhaustionMeter then
			exhaustionMeter:ClearAllPoints()
			exhaustionMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
			exhaustionMeter:Show()
			yOffset = yOffset - METER_HEIGHT - METER_SPACING
			visibleCount = visibleCount + 1
		elseif exhaustionMeter then
			exhaustionMeter:Hide()
		end

		-- Position Hunger
		if hungerEnabled and hungerMeter then
			hungerMeter:ClearAllPoints()
			hungerMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
			hungerMeter:Show()
			yOffset = yOffset - METER_HEIGHT - METER_SPACING
			visibleCount = visibleCount + 1
		elseif hungerMeter then
			hungerMeter:Hide()
		end

		-- Position Thirst
		if thirstEnabled and thirstMeter then
			thirstMeter:ClearAllPoints()
			thirstMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
			thirstMeter:Show()
			yOffset = yOffset - METER_HEIGHT - METER_SPACING
			visibleCount = visibleCount + 1
		elseif thirstMeter then
			thirstMeter:Hide()
		end

		-- Position Temperature (always last/bottom when enabled)
		if temperatureEnabled and temperatureMeter then
			temperatureMeter:ClearAllPoints()
			temperatureMeter:SetPoint("TOP", metersContainer, "TOP", 0, yOffset)
			temperatureMeter:Show()
			visibleCount = visibleCount + 1
		elseif temperatureMeter then
			temperatureMeter:Hide()
		end

		-- Position Weather button (below temperature if enabled)
		if temperatureEnabled and weatherButton then

			-- Reset temperature bar to original width in bar mode
			ResizeTemperatureMeter(temperatureMeter, TEMP_METER_WIDTH)

			-- Position weather button below temperature meter
			if weatherButton then
				weatherButton:ClearAllPoints()
				weatherButton:SetPoint("TOP", temperatureMeter, "BOTTOM", 0, -METER_SPACING)
			end
		end

		-- Update container size based on visible meters
		local hitPadding = 15
		local barsOnlyHeight = (visibleCount * METER_HEIGHT) + (math.max(0, visibleCount - 1) * METER_SPACING)
		local contentHeight = barsOnlyHeight + 10 + STATUS_ROW_HEIGHT
		-- Only add weather button space if temperature is enabled AND zone has weather
		local weatherType = CC.GetZoneWeatherType and CC.GetZoneWeatherType() or WEATHER_TYPE_NONE
		local manualWeatherEnabled = CC.GetSetting and CC.GetSetting("manualWeatherEnabled")
		local hasWeatherButton = temperatureEnabled and manualWeatherEnabled and weatherType ~= WEATHER_TYPE_NONE
		if hasWeatherButton then
			contentHeight = contentHeight + WEATHER_BUTTON_SIZE + METER_SPACING
		end
		metersContainer:SetSize(METER_WIDTH + 20 + (hitPadding * 2), contentHeight + (hitPadding * 2))

		-- Reposition constitution orb to be vertically centered with just the visible bars
		if constitutionMeter and visibleCount > 0 then
			-- Bars start at -5 from container TOP
			-- Calculate center of bars relative to container TOP
			local barsTopOffset = -5 - STATUS_ROW_HEIGHT
			local barsCenterFromTop = barsTopOffset - (barsOnlyHeight / 2)

			-- Container center is at half the container height from TOP
			local containerHeight = contentHeight + (hitPadding * 2)
			local containerCenterFromTop = -(containerHeight / 2)

			-- Offset needed: how far from container CENTER to bars CENTER
			local verticalOffset = barsCenterFromTop - containerCenterFromTop

			constitutionMeter:ClearAllPoints()
			constitutionMeter:SetPoint("CENTER", metersContainer, "LEFT", -(CONSTITUTION_ORB_SIZE / 2) + 10,
					verticalOffset)
		end
	end
end

-- Create the meters container
local function CreateMetersContainer()
	if metersContainer then
		return metersContainer
	end

	metersContainer = CreateFrame("Frame", "CozierCampsMetersContainer", UIParent)
	-- Larger hit area for easier dragging (extends beyond visible meters)
	local hitPadding = 15
	-- Now supports 5 meters (Anguish, Exhaustion, Hunger, Thirst, Temperature) + weather button
	metersContainer:SetSize(METER_WIDTH + 20 + (hitPadding * 2),
			(METER_HEIGHT * 5) + (METER_SPACING * 5) + WEATHER_BUTTON_SIZE + 20 + (hitPadding * 2))
	metersContainer:SetPoint("TOP", UIParent, "TOP", 0, -100 + hitPadding)
	metersContainer:SetMovable(true)
	metersContainer:EnableMouse(true)
	metersContainer:SetHitRectInsets(-hitPadding, -hitPadding, -hitPadding, -hitPadding)
	metersContainer:RegisterForDrag("LeftButton")
	metersContainer:SetClampedToScreen(true)

	-- Apply meter scale setting
	local scale = CC.GetSetting("meterScale") or 1.0
	metersContainer:SetScale(scale)

	metersContainer:SetScript("OnDragStart", function()
		StartMovingMetersContainer()
	end)
	metersContainer:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- Save absolute screen coordinates of top-left corner for consistent placement
		if not CC.GetSetting("metersLocked") then
			local left = self:GetLeft()
			local top = self:GetTop()
			if CC.db and left and top then
				CC.db.meterPosition = {
					screenLeft = left,
					screenTop = top
				}
			end
		end
	end)

	-- Create status icons row (above meters)
	statusIconsRow = CreateStatusIconsRow(metersContainer)

	-- Create the meters with icons
	-- Using custom BLP icons from assets folder
	local AnguishIcon = "Interface\\AddOns\\CozierCamps\\assets\\Anguishicon.blp"
	local exhaustionIcon = "Interface\\AddOns\\CozierCamps\\assets\\exhaustionicon.blp"
	local hungerIcon = "Interface\\AddOns\\CozierCamps\\assets\\hungericon.blp"
	local thirstIcon = "Interface\\AddOns\\CozierCamps\\assets\\watericon.blp"

	-- Check display mode
	local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"

	if displayMode == "vial" then
		-- VIAL MODE: Create vertical potion-style meters in a horizontal row
		local vialStartX = 10
		local vialSpacing = VIAL_SIZE + 40 + VIAL_SPACING -- Tighter spacing with negative VIAL_SPACING

		-- Vial overlay textures (unique potion bottle for each meter type - 256x256)
		local constitutionVial = "Interface\\AddOns\\CozierCamps\\assets\\constitutionpotion.png"
		local anguishVial = "Interface\\AddOns\\CozierCamps\\assets\\anguishpotion.png"
		local exhaustionVial = "Interface\\AddOns\\CozierCamps\\assets\\exhaustpotion.png"
		local hungerVial = "Interface\\AddOns\\CozierCamps\\assets\\hungerpotion.png"
		local thirstVial = "Interface\\AddOns\\CozierCamps\\assets\\thirstpotion.png"

		-- Fill textures for each meter type
		local constitutionFill = "Interface\\AddOns\\CozierCamps\\assets\\health.png"
		local anguishFill = "Interface\\AddOns\\CozierCamps\\assets\\anguish.png"
		local exhaustionFill = "Interface\\AddOns\\CozierCamps\\assets\\exhaust.png"
		local hungerFill = "Interface\\AddOns\\CozierCamps\\assets\\hunger.png"
		local thirstFill = "Interface\\AddOns\\CozierCamps\\assets\\thirst.png"

		-- Constitution vial first (leftmost)
		constitutionMeter = CreateVialMeter("Constitution", metersContainer, vialStartX, CONSTITUTION_BAR_COLOR,
				constitutionVial, constitutionFill)
		constitutionMeter.isConstitution = true
		constitutionMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)
		-- Remove tinting from constitution fill to show original texture colors
		constitutionMeter.fillBar:SetStatusBarColor(1, 1, 1, 1)

		-- Other vials in order
		AnguishMeter = CreateVialMeter("Anguish", metersContainer, vialStartX + vialSpacing, Anguish_COLOR, anguishVial,
				anguishFill)
		AnguishMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)
		-- Scale down Anguish vial by 3% (it appears slightly larger than others)
		local anguishScale = 0.97
		AnguishMeter.orbBg:SetSize(AnguishMeter.orbBg:GetWidth() * anguishScale,
				AnguishMeter.orbBg:GetHeight() * anguishScale)
		AnguishMeter.fillBar:SetSize(AnguishMeter.fillBar:GetWidth() * anguishScale,
				AnguishMeter.fillBar:GetHeight() * anguishScale)
		AnguishMeter.vialOverlay:SetSize(AnguishMeter.vialOverlay:GetWidth() * anguishScale,
				AnguishMeter.vialOverlay:GetHeight() * anguishScale)
		AnguishMeter.glowGreen:SetSize(AnguishMeter.glowGreen:GetWidth() * anguishScale,
				AnguishMeter.glowGreen:GetHeight() * anguishScale)
		AnguishMeter.glowOrange:SetSize(AnguishMeter.glowOrange:GetWidth() * anguishScale,
				AnguishMeter.glowOrange:GetHeight() * anguishScale)
		AnguishMeter.glowBlue:SetSize(AnguishMeter.glowBlue:GetWidth() * anguishScale,
				AnguishMeter.glowBlue:GetHeight() * anguishScale)
		exhaustionMeter = CreateVialMeter("Exhaustion", metersContainer, vialStartX + vialSpacing * 2, EXHAUSTION_COLOR,
				exhaustionVial, exhaustionFill)
		exhaustionMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)
		hungerMeter = CreateVialMeter("Hunger", metersContainer, vialStartX + vialSpacing * 3, HUNGER_COLOR, hungerVial,
				hungerFill)
		hungerMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)

		thirstMeter = CreateVialMeter("Thirst", metersContainer, vialStartX + vialSpacing * 4, THIRST_COLOR, thirstVial,
				thirstFill)
		thirstMeter.vialOverlay:SetVertexColor(1, 1, 1, 1)

		-- Temperature uses a BAR (not a vial), centered below the vials
		temperatureMeter = CreateTemperatureMeter(metersContainer, 0)
		-- Will be repositioned in RepositionMeters

		-- Weather button below the temperature bar
		weatherButton = CreateWeatherButton(metersContainer)
		weatherButton:SetPoint("TOP", temperatureMeter, "BOTTOM", 0, -METER_SPACING)

		-- Reposition status icons below temperature meter at the ends
		if weatherButton.wetIcon and temperatureMeter then
			weatherButton.wetIcon:ClearAllPoints()
			weatherButton.wetIcon:SetPoint("TOP", temperatureMeter, "BOTTOMLEFT", 12, -4)
			weatherButton.wetGlow:ClearAllPoints()
			weatherButton.wetGlow:SetPoint("CENTER", weatherButton.wetIcon, "CENTER")
			weatherButton.wetHitbox:ClearAllPoints()
			weatherButton.wetHitbox:SetPoint("CENTER", weatherButton.wetIcon, "CENTER")
		end
		if weatherButton.cozyIcon and temperatureMeter then
			weatherButton.cozyIcon:ClearAllPoints()
			weatherButton.cozyIcon:SetPoint("TOP", temperatureMeter, "BOTTOMRIGHT", -12, -4)
			weatherButton.cozyGlow:ClearAllPoints()
			weatherButton.cozyGlow:SetPoint("CENTER", weatherButton.cozyIcon, "CENTER")
			weatherButton.cozyHitbox:ClearAllPoints()
			weatherButton.cozyHitbox:SetPoint("CENTER", weatherButton.cozyIcon, "CENTER")
		end

		-- Resize container for vial mode (horizontal layout)
		local containerWidth = vialSpacing * 5 + VIAL_SIZE + 100
		local containerHeight = VIAL_DISPLAY_SIZE + METER_HEIGHT + 80
		metersContainer:SetSize(containerWidth, containerHeight)

		-- Setup tooltips for vial mode (including constitution)
		SetupConstitutionBarTooltip(constitutionMeter) -- Works for both bar and vial
		SetupAnguishTooltip(AnguishMeter)
		SetupExhaustionTooltip(exhaustionMeter)
		SetupHungerTooltip(hungerMeter)
		SetupThirstTooltip(thirstMeter)
		SetupTemperatureTooltip(temperatureMeter)

	else
		-- BAR MODE: Create horizontal bar meters (original layout)
		-- Constitution bar at the TOP of the stack (positions will be set by RepositionMeters)
		constitutionBarMeter = CreateConstitutionBarMeter(metersContainer, -5)
		SetupConstitutionBarTooltip(constitutionBarMeter)

		-- Create other meters (positions will be set by RepositionMeters)
		AnguishMeter = CreateMeter("Anguish", metersContainer, -5 - METER_HEIGHT - METER_SPACING, AnguishIcon, true)
		exhaustionMeter = CreateMeter("Exhaustion", metersContainer, -5 - (METER_HEIGHT + METER_SPACING) * 2,
				exhaustionIcon, false)
		hungerMeter = CreateMeter("Hunger", metersContainer, -5 - (METER_HEIGHT + METER_SPACING) * 3, hungerIcon, false)

		-- Thirst bar
		thirstMeter = CreateMeter("Thirst", metersContainer, -5 - (METER_HEIGHT + METER_SPACING) * 4, thirstIcon, false)

		-- Create temperature meter (bidirectional)
		temperatureMeter = CreateTemperatureMeter(metersContainer, -5 - (METER_HEIGHT + METER_SPACING) * 5)

		-- Create weather button (below temperature meter, centered)
		weatherButton = CreateWeatherButton(metersContainer)
		weatherButton:SetPoint("TOP", temperatureMeter, "BOTTOM", 0, -METER_SPACING)

		-- Reposition status icons below temperature meter at the ends
		if weatherButton.wetIcon and temperatureMeter then
			weatherButton.wetIcon:ClearAllPoints()
			weatherButton.wetIcon:SetPoint("TOP", temperatureMeter, "BOTTOMLEFT", 12, -4)
			weatherButton.wetGlow:ClearAllPoints()
			weatherButton.wetGlow:SetPoint("CENTER", weatherButton.wetIcon, "CENTER")
			weatherButton.wetHitbox:ClearAllPoints()
			weatherButton.wetHitbox:SetPoint("CENTER", weatherButton.wetIcon, "CENTER")
		end
		if weatherButton.cozyIcon and temperatureMeter then
			weatherButton.cozyIcon:ClearAllPoints()
			weatherButton.cozyIcon:SetPoint("TOP", temperatureMeter, "BOTTOMRIGHT", -12, -4)
			weatherButton.cozyGlow:ClearAllPoints()
			weatherButton.cozyGlow:SetPoint("CENTER", weatherButton.cozyIcon, "CENTER")
			weatherButton.cozyHitbox:ClearAllPoints()
			weatherButton.cozyHitbox:SetPoint("CENTER", weatherButton.cozyIcon, "CENTER")
		end

		-- Create constitution orb (hidden in bar mode, but still created for mode switching)
		constitutionMeter = CreateConstitutionMeter(metersContainer)
		constitutionMeter:Hide() -- Hide the orb in bar mode

		-- Resize Anguish and Hunger icons (10% larger)
		local largerIconSize = ICON_SIZE * 1.1
		if AnguishMeter.icon then
			AnguishMeter.icon:SetSize(largerIconSize, largerIconSize)
		end
		if hungerMeter.icon then
			hungerMeter.icon:SetSize(largerIconSize, largerIconSize)
		end

		-- Thirst icon (watericon.blp) needs to be scaled down - it's naturally larger
		if thirstMeter and thirstMeter.icon then
			local thirstIconSize = ICON_SIZE * 0.85
			thirstMeter.icon:SetSize(thirstIconSize, thirstIconSize)
		end

		-- Add milestone notches to Anguish bar (25%, 50%, 75%)
		CreateMilestoneNotches(AnguishMeter)
		-- Add milestone notches to Hunger bar (25%, 50%, 75%)
		CreateMilestoneNotches(hungerMeter)

		-- Add milestone notches to Thirst bar (25%, 50%, 75%)
		CreateMilestoneNotches(thirstMeter)

		-- Set initial colors
		AnguishMeter.bar:SetStatusBarColor(Anguish_COLOR.r, Anguish_COLOR.g, Anguish_COLOR.b)
		exhaustionMeter.bar:SetStatusBarColor(EXHAUSTION_COLOR.r, EXHAUSTION_COLOR.g, EXHAUSTION_COLOR.b)
		hungerMeter.bar:SetStatusBarColor(HUNGER_COLOR.r, HUNGER_COLOR.g, HUNGER_COLOR.b)
		thirstMeter.bar:SetStatusBarColor(THIRST_COLOR.r, THIRST_COLOR.g, THIRST_COLOR.b)

		-- Set initial glow colors (will be updated dynamically)
		SetGlowColor(AnguishMeter.glow, GLOW_ORANGE.r, GLOW_ORANGE.g, GLOW_ORANGE.b)
		SetGlowColor(exhaustionMeter.glow, GLOW_ORANGE.r, GLOW_ORANGE.g, GLOW_ORANGE.b)
		SetGlowColor(hungerMeter.glow, HUNGER_COLOR.r, HUNGER_COLOR.g, HUNGER_COLOR.b)
		SetGlowColor(thirstMeter.glow, THIRST_COLOR.r, THIRST_COLOR.g, THIRST_COLOR.b)

		-- Setup tooltips
		SetupAnguishTooltip(AnguishMeter)
		SetupExhaustionTooltip(exhaustionMeter)
		SetupHungerTooltip(hungerMeter)
		SetupThirstTooltip(thirstMeter)
		SetupTemperatureTooltip(temperatureMeter)
	end

	-- Initial repositioning
	RepositionMeters()

	return metersContainer
end

-- Update Anguish meter
local function UpdateAnguishMeter(elapsed)
	if not AnguishMeter then
		return
	end

	local Anguish = CC.GetAnguish and CC.GetAnguish() or 0
	local isDecaying = CC.IsAnguishDecaying and CC.IsAnguishDecaying() or false
	local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"

	-- Calculate target display value (inverted: full bar = 0% anguish, empty bar = 100% anguish)
	local targetDisplay = 100 - Anguish

	-- Smooth the display value for refill animation (like hunger at innkeeper)
	if smoothedAnguishDisplay == nil then
		smoothedAnguishDisplay = targetDisplay
	else
		-- Lerp toward target value
		local diff = targetDisplay - smoothedAnguishDisplay
		smoothedAnguishDisplay = smoothedAnguishDisplay + diff * math.min(1, ANGUISH_DISPLAY_LERP_SPEED * elapsed)
	end
	local displayValue = smoothedAnguishDisplay

	-- Update bar value
	AnguishMeter.bar:SetValue(displayValue)

	-- Format percentage text
	-- Both bar and vial modes show inverted value (100 = full/good, 0 = empty/bad)
	-- This matches the inverted bar display where full bar = 0% anguish
	local percentText
	if displayMode == "vial" then
		-- Vial mode: just the number (no % symbol)
		percentText = string.format("%.0f", displayValue)
	else
		-- Bar mode: integer percentage (round to nearest)
		percentText = string.format("%.0f%%", displayValue)
	end
	-- Apply text based on hideVialText setting
	local hideText = displayMode == "vial" and CC.GetSetting("hideVialText")
	if hideText then
		AnguishMeter.percent:SetText("")
		if AnguishMeter.percentShadows then
			for _, shadow in ipairs(AnguishMeter.percentShadows) do
				shadow:SetText("")
			end
		end
	else
		AnguishMeter.percent:SetText(percentText)
		if displayMode == "vial" and AnguishMeter.percentShadows then
			for _, shadow in ipairs(AnguishMeter.percentShadows) do
				shadow:SetText(percentText)
			end
		end
	end

	-- Update bar color (green when decaying)
	if isDecaying then
		AnguishMeter.bar:SetStatusBarColor(Anguish_DECAY_COLOR.r, Anguish_DECAY_COLOR.g, Anguish_DECAY_COLOR.b)
	else
		AnguishMeter.bar:SetStatusBarColor(Anguish_COLOR.r, Anguish_COLOR.g, Anguish_COLOR.b)
	end

	-- Get pulse state for damage glow
	local pulseType, pulseIntensity = 0, 0
	if CC.GetAnguishPulse then
		pulseType, pulseIntensity = CC.GetAnguishPulse()
	end

	-- Check if system is paused (dungeon, taxi)
	local isPaused = CC.IsAnguishPaused and CC.IsAnguishPaused()

	-- Check if at rest and at/below resting threshold (25% or 0%)
	local isResting = IsResting()
	local atRestThreshold = isResting and (Anguish <= 25)

	-- VIAL MODE: Use new glow system (blue=paused, orange=negative, green=positive)
	if displayMode == "vial" and AnguishMeter.glowGreen then
		local targetAlpha = 0
		local glowType = "none"

		if isPaused then
			targetAlpha = 0.7
			glowType = "blue"
		elseif pulseType > 0 and pulseIntensity > 0 then
			targetAlpha = 1.0
			glowType = "orange"
		elseif isDecaying or atRestThreshold then
			targetAlpha = 1.0
			glowType = "green"
		end

		AnguishMeter.glowTargetAlpha = targetAlpha

		-- Apply pulsing effect
		if targetAlpha > 0 then
			AnguishMeter.glowPulsePhase = (AnguishMeter.glowPulsePhase or 0) + elapsed * 0.8
			local pulseMod = 0.7 + 0.3 * math.sin(AnguishMeter.glowPulsePhase * math.pi * 2)
			AnguishMeter.glowTargetAlpha = AnguishMeter.glowTargetAlpha * pulseMod
		end

		-- Smooth alpha interpolation
		local alphaDiff = AnguishMeter.glowTargetAlpha - (AnguishMeter.glowCurrentAlpha or 0)
		if math.abs(alphaDiff) < 0.01 then
			AnguishMeter.glowCurrentAlpha = AnguishMeter.glowTargetAlpha
		else
			local speed = alphaDiff > 0 and 3.0 or 1.5
			AnguishMeter.glowCurrentAlpha = (AnguishMeter.glowCurrentAlpha or 0) + (alphaDiff * speed * elapsed)
		end
		AnguishMeter.glowCurrentAlpha = math.max(0, math.min(1, AnguishMeter.glowCurrentAlpha))

		-- Show appropriate glow, hide others
		local alpha = AnguishMeter.glowCurrentAlpha
		AnguishMeter.glowGreen:SetAlpha(glowType == "green" and alpha or 0)
		AnguishMeter.glowOrange:SetAlpha(glowType == "orange" and alpha or 0)
		AnguishMeter.glowBlue:SetAlpha(glowType == "blue" and alpha or 0)
	else
		-- BAR MODE: Use atlas glow system
		local glow = AnguishMeter.glow
		if not glow then
			return
		end

		if isPaused then
			SetGlowColor(glow, 1, 0.9, 0.3, true)
			glow.targetAlpha = 0.8
			glow.targetSize = GLOW_SIZE_PAUSED
		elseif pulseType > 0 and pulseIntensity > 0 then
			SetGlowColor(glow, GLOW_ORANGE.r, GLOW_ORANGE.g, GLOW_ORANGE.b, false)
			local pulseSize = PULSE_SIZES[pulseType] or GLOW_SIZE
			glow.targetAlpha = 1.0
			glow.targetSize = pulseSize
		elseif isDecaying or atRestThreshold then
			SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
			glow.targetAlpha = 1.0
			glow.targetSize = GLOW_SIZE
		else
			glow.targetAlpha = 0
			glow.targetSize = GLOW_SIZE
		end

		-- Apply pulsing effect when glow is active
		if glow.targetAlpha > 0 then
			glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
			local pulseMod = 0.6 + 0.4 * math.sin(glow.pulsePhase * math.pi * 2)
			glow.targetAlpha = glow.targetAlpha * pulseMod
		end

		-- Smooth alpha interpolation
		local alphaDiff = glow.targetAlpha - glow.currentAlpha
		if math.abs(alphaDiff) < 0.01 then
			glow.currentAlpha = glow.targetAlpha
		else
			local speed = alphaDiff > 0 and 8.0 or 3.0
			glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
		end
		glow.currentAlpha = math.max(0, math.min(1, glow.currentAlpha))
		glow:SetAlpha(glow.currentAlpha)

		-- Size update: snap immediately to paused size, interpolate others
		if glow.targetSize < 0 then
			-- Paused state: snap immediately to avoid large glow flash
			glow.currentSize = glow.targetSize
		else
			-- Normal state: smooth interpolation
			local sizeDiff = glow.targetSize - glow.currentSize
			if math.abs(sizeDiff) < 0.5 then
				glow.currentSize = glow.targetSize
			else
				glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
			end
		end
		UpdateGlowSize(glow, AnguishMeter, glow.currentSize)
	end
end

-- Update exhaustion meter
local function UpdateExhaustionMeter(elapsed)
	if not exhaustionMeter then
		return
	end

	local exhaustion = CC.GetExhaustion and CC.GetExhaustion() or 0
	local isDecaying = CC.IsExhaustionDecaying and CC.IsExhaustionDecaying() or false
	local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"

	-- Update bar value (inverted: full bar = 0% exhaustion, empty bar = 100% exhaustion)
	local displayValue = 100 - exhaustion
	exhaustionMeter.bar:SetValue(displayValue)

	-- Format percentage text
	-- Both bar and vial modes show inverted value (100 = full/good, 0 = empty/bad)
	-- This matches the inverted bar display where full bar = 0% exhaustion
	local percentText
	if displayMode == "vial" then
		-- Vial mode: just the number (no % symbol)
		percentText = string.format("%.0f", displayValue)
	else
		-- Bar mode: integer percentage (round to nearest)
		percentText = string.format("%.0f%%", displayValue)
	end
	-- Apply text based on hideVialText setting
	local hideText = displayMode == "vial" and CC.GetSetting("hideVialText")
	if hideText then
		exhaustionMeter.percent:SetText("")
		if exhaustionMeter.percentShadows then
			for _, shadow in ipairs(exhaustionMeter.percentShadows) do
				shadow:SetText("")
			end
		end
	else
		exhaustionMeter.percent:SetText(percentText)
		if displayMode == "vial" and exhaustionMeter.percentShadows then
			for _, shadow in ipairs(exhaustionMeter.percentShadows) do
				shadow:SetText(percentText)
			end
		end
	end

	-- Update bar color (green when decaying)
	if isDecaying then
		exhaustionMeter.bar:SetStatusBarColor(EXHAUSTION_DECAY_COLOR.r, EXHAUSTION_DECAY_COLOR.g,
				EXHAUSTION_DECAY_COLOR.b)
	else
		exhaustionMeter.bar:SetStatusBarColor(EXHAUSTION_COLOR.r, EXHAUSTION_COLOR.g, EXHAUSTION_COLOR.b)
	end

	-- Get glow state based on movement
	local glowType, glowIntensity = 0, 0
	if CC.GetExhaustionGlow then
		glowType, glowIntensity = CC.GetExhaustionGlow()
	end

	-- Check if system is paused (dungeon, taxi)
	local isPaused = CC.IsExhaustionPaused and CC.IsExhaustionPaused()

	-- Check if at rest and at/below zero exhaustion
	local isResting = IsResting()
	local isNearFire = CC.isNearFire
	local atRestThreshold = (isResting or isNearFire) and (exhaustion <= 0)

	-- VIAL MODE: Use new glow system (blue=paused, orange=negative, green=positive)
	if displayMode == "vial" and exhaustionMeter.glowGreen then
		local targetAlpha = 0
		local glowTypeExh = "none"

		if isPaused then
			targetAlpha = 0.7
			glowTypeExh = "blue"
		elseif isDecaying or atRestThreshold then
			-- Exhaustion decreasing (resting/near fire) - show green (prioritize over movement glow)
			targetAlpha = 1.0
			glowTypeExh = "green"
		elseif glowType > 0 and glowIntensity > 0 then
			-- Exhaustion increasing (moving/running) - show orange
			targetAlpha = math.max(0.6, glowIntensity)
			glowTypeExh = "orange"
		end

		exhaustionMeter.glowTargetAlpha = targetAlpha

		-- Apply pulsing effect
		if targetAlpha > 0 then
			exhaustionMeter.glowPulsePhase = (exhaustionMeter.glowPulsePhase or 0) + elapsed * 0.8
			local pulseMod = 0.7 + 0.3 * math.sin(exhaustionMeter.glowPulsePhase * math.pi * 2)
			exhaustionMeter.glowTargetAlpha = exhaustionMeter.glowTargetAlpha * pulseMod
		end

		-- Smooth alpha interpolation
		local alphaDiff = exhaustionMeter.glowTargetAlpha - (exhaustionMeter.glowCurrentAlpha or 0)
		if math.abs(alphaDiff) < 0.01 then
			exhaustionMeter.glowCurrentAlpha = exhaustionMeter.glowTargetAlpha
		else
			local speed = alphaDiff > 0 and 3.0 or 1.5
			exhaustionMeter.glowCurrentAlpha = (exhaustionMeter.glowCurrentAlpha or 0) + (alphaDiff * speed * elapsed)
		end
		exhaustionMeter.glowCurrentAlpha = math.max(0, math.min(1, exhaustionMeter.glowCurrentAlpha))

		-- Show appropriate glow, hide others
		local alpha = exhaustionMeter.glowCurrentAlpha
		exhaustionMeter.glowGreen:SetAlpha(glowTypeExh == "green" and alpha or 0)
		exhaustionMeter.glowOrange:SetAlpha(glowTypeExh == "orange" and alpha or 0)
		exhaustionMeter.glowBlue:SetAlpha(glowTypeExh == "blue" and alpha or 0)
	else
		-- BAR MODE: Use atlas glow system
		local glow = exhaustionMeter.glow
		if not glow then
			return
		end

		if isPaused then
			SetGlowColor(glow, 1, 0.9, 0.3, true)
			glow.targetAlpha = 0.7
			glow.targetSize = GLOW_SIZE_PAUSED
		elseif isDecaying or atRestThreshold then
			SetGlowColor(glow, GLOW_GREEN.r, GLOW_GREEN.g, GLOW_GREEN.b, false)
			glow.targetAlpha = 1.0
			glow.targetSize = GLOW_SIZE
		elseif glowType > 0 and glowIntensity > 0 then
			SetGlowColor(glow, GLOW_ORANGE.r, GLOW_ORANGE.g, GLOW_ORANGE.b, false)
			local glowSize
			if glowType == 0.5 then
				glowSize = GLOW_SIZE_IDLE
			else
				glowSize = GLOW_SIZES[glowType] or GLOW_SIZE
			end
			glow.targetAlpha = glowIntensity
			glow.targetSize = glowSize
		else
			glow.targetAlpha = 0
			glow.targetSize = GLOW_SIZE
		end

		-- Apply pulsing effect when glow is active
		if glow.targetAlpha > 0 then
			glow.pulsePhase = (glow.pulsePhase or 0) + elapsed * GLOW_PULSE_SPEED
			local pulseMod = 0.7 + 0.3 * math.sin(glow.pulsePhase * math.pi * 2)
			glow.targetAlpha = glow.targetAlpha * pulseMod
		end

		-- Smooth alpha interpolation
		local alphaDiff = glow.targetAlpha - glow.currentAlpha
		if math.abs(alphaDiff) < 0.01 then
			glow.currentAlpha = glow.targetAlpha
		else
			local speed = alphaDiff > 0 and 8.0 or 3.0
			glow.currentAlpha = glow.currentAlpha + (alphaDiff * speed * elapsed)
		end
		glow.currentAlpha = math.max(0, math.min(1, glow.currentAlpha))
		glow:SetAlpha(glow.currentAlpha)

		-- Size update: snap immediately to paused size, interpolate others
		if glow.targetSize < 0 then
			-- Paused state: snap immediately to avoid large glow flash
			glow.currentSize = glow.targetSize
		else
			-- Normal state: smooth interpolation
			local sizeDiff = glow.targetSize - glow.currentSize
			if math.abs(sizeDiff) < 0.5 then
				glow.currentSize = glow.targetSize
			else
				glow.currentSize = glow.currentSize + (sizeDiff * 5.0 * elapsed)
			end
		end
		UpdateGlowSize(glow, exhaustionMeter, glow.currentSize)
	end
end

-- Check if meters should be visible
local function ShouldShowMeters()
	if not CC.IsPlayerEligible or not CC.IsPlayerEligible() then
		-- Debug: show why meters are hidden
		local enabled = CC.GetSetting and CC.GetSetting("enabled")
		if not enabled then
			CC.Debug("Meters hidden: master toggle disabled", "general")
		end
		return false
	end
	local AnguishEnabled = CC.GetSetting and CC.GetSetting("AnguishEnabled")
	local exhaustionEnabled = CC.GetSetting and CC.GetSetting("exhaustionEnabled")
	local hungerEnabled = CC.GetSetting and CC.GetSetting("hungerEnabled")
	local thirstEnabled = CC.GetSetting and CC.GetSetting("thirstEnabled")
	local temperatureEnabled = CC.GetSetting and CC.GetSetting("temperatureEnabled")
	local result = AnguishEnabled or exhaustionEnabled or hungerEnabled or thirstEnabled or temperatureEnabled
	if not result then
		CC.Debug("Meters hidden: no meters enabled", "general")
	end
	return result
end

-- Refresh cached settings (called when settings change)
local function RefreshCachedSettings()
	cachedSettings.meterDisplayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"
	cachedSettings.AnguishEnabled = CC.GetSetting and CC.GetSetting("AnguishEnabled")
	cachedSettings.exhaustionEnabled = CC.GetSetting and CC.GetSetting("exhaustionEnabled")
	cachedSettings.hungerEnabled = CC.GetSetting and CC.GetSetting("hungerEnabled")
	cachedSettings.thirstEnabled = CC.GetSetting and CC.GetSetting("thirstEnabled")
	cachedSettings.temperatureEnabled = CC.GetSetting and CC.GetSetting("temperatureEnabled")
end

-- Main update function
local function UpdateMeters(elapsed)
	if not metersContainer then
		return
	end

	-- Check visibility
	if not ShouldShowMeters() then
		if metersContainer:IsShown() then
			metersContainer:Hide()
		end
		return
	end

	if not metersContainer:IsShown() then
		metersContainer:Show()
	end

	-- Status icons are independent of the weather button
	UpdateStatusIcons(elapsed)

	-- Use cached settings (refreshed on SETTINGS_CHANGED)
	local AnguishEnabled = cachedSettings.AnguishEnabled
	local exhaustionEnabled = cachedSettings.exhaustionEnabled
	local hungerEnabled = cachedSettings.hungerEnabled
	local thirstEnabled = cachedSettings.thirstEnabled
	local temperatureEnabled = cachedSettings.temperatureEnabled

	if AnguishEnabled and AnguishMeter then
		AnguishMeter:Show()
		UpdateAnguishMeter(elapsed)
	elseif AnguishMeter then
		AnguishMeter:Hide()
	end

	if exhaustionEnabled and exhaustionMeter then
		exhaustionMeter:Show()
		UpdateExhaustionMeter(elapsed)
	elseif exhaustionMeter then
		exhaustionMeter:Hide()
	end

	if hungerEnabled and hungerMeter then
		hungerMeter:Show()
		UpdateHungerMeter(elapsed)
	elseif hungerMeter then
		hungerMeter:Hide()
	end

	if thirstEnabled and thirstMeter then
		thirstMeter:Show()
		UpdateThirstMeter(elapsed)
	elseif thirstMeter then
		thirstMeter:Hide()
	end

	if temperatureEnabled and temperatureMeter then
		temperatureMeter:Show()
		UpdateTemperatureMeter(elapsed)
		-- Weather button is part of temperature system
		UpdateWeatherButton(elapsed)
	elseif temperatureMeter then
		temperatureMeter:Hide()
		if weatherButton then
			weatherButton:Hide()
		end
	end

	-- Update constitution meters (Adventure Mode)
	local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"
	if ShouldShowConstitution() then
		if displayMode == "vial" then
			-- Vial mode: show orb, hide bar
			UpdateConstitutionMeter(elapsed)
			if constitutionBarMeter then
				constitutionBarMeter:Hide()
			end
		else
			-- Bar mode: show bar, hide orb
			UpdateConstitutionBarMeter(elapsed)
			if constitutionMeter then
				constitutionMeter:Hide()
			end
		end
	else
		-- Constitution disabled - hide both and restore UI
		if constitutionMeter then
			constitutionMeter:Hide()
		end
		if constitutionBarMeter then
			constitutionBarMeter:Hide()
		end
		-- Restore all UI when adventure mode is disabled
		UpdateAdventureModeUI(100)
	end

	-- Update UI fade animations (player/target frame fading)
	UpdateUIFadeAnimations(elapsed)
end

-- Load saved positions
local function LoadMeterPosition()
	-- Load meter bars position
	if CC.db and CC.db.meterPosition then
		local pos = CC.db.meterPosition
		metersContainer:ClearAllPoints()

		-- New format: absolute screen coordinates of top-left corner
		if pos.screenLeft and pos.screenTop then
			metersContainer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.screenLeft, pos.screenTop)
		else
			-- Legacy format fallback
			metersContainer:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0,
					pos.y or 0)
		end
	end
	-- Constitution orb is anchored to metersContainer, so it moves with meters automatically
end

-- Event frame
local eventFrame = CreateFrame("Frame", "CozierCampsMetersFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		RefreshCachedSettings() -- Initialize cached settings
		CreateMetersContainer()
		C_Timer.After(1, LoadMeterPosition)
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- Handle target frame visibility based on constitution state
		-- This prevents ghost frames when acquiring/clearing targets
		if InCombatLockdown() then
			return
		end
		if not CC.GetSetting or not CC.GetSetting("constitutionEnabled") then
			return
		end

		if adventureModeUIState.targetFrameHidden then
			-- Constitution is below 50%, hide the target frame
			SafeHideFrame(TargetFrame)
		else
			-- Constitution is above 50%, let the game handle target frame normally
			-- Only show if there's actually a target to prevent ghost frames
			if UnitExists("target") then
				SafeShowFrame(TargetFrame)
			end
		end
	end
end)

DRAW_DELAY = 1 / 90 -- target 90 FPS
-- OnUpdate for smooth animations
eventFrame:SetScript("OnUpdate", function(self, elapsed)
	if not self.accumulator then
		self.accumulator = 0
		UpdateMeters(DRAW_DELAY)
		return
	end
	self.accumulator = self.accumulator + elapsed
	if self.accumulator >= DRAW_DELAY then
		self.accumulator = self.accumulator - DRAW_DELAY
		UpdateMeters(DRAW_DELAY)
	end
end)

-- Settings callback
CC.RegisterCallback("SETTINGS_CHANGED", function(key)
	-- Always refresh cached settings on any change
	RefreshCachedSettings()

	-- Handle meter scale changes
	if key == "meterScale" or key == "ALL" then
		if metersContainer then
			local scale = CC.GetSetting("meterScale") or 1.0
			metersContainer:SetScale(scale)
		end
	end

	if key == "AnguishEnabled" or key == "exhaustionEnabled" or key == "hungerEnabled" or key == "thirstEnabled" or key ==
			"temperatureEnabled" or key == "constitutionEnabled" or key == "ALL" then
		if metersContainer then
			-- Reposition meters to condense gaps
			RepositionMeters()
		end
	end

	-- Display mode changed - need to recreate meters since structures are different
	if key == "meterDisplayMode" then
		if metersContainer then
			-- Save current position before destroying
			local savedPos = nil
			if CC.db and CC.db.meterPosition then
				savedPos = CC.db.meterPosition
			end

			-- Destroy existing meter frames
			if AnguishMeter then
				AnguishMeter:Hide()
			end
			if exhaustionMeter then
				exhaustionMeter:Hide()
			end
			if hungerMeter then
				hungerMeter:Hide()
			end
			if temperatureMeter then
				temperatureMeter:Hide()
			end
			if constitutionMeter then
				constitutionMeter:Hide()
			end
			if constitutionBarMeter then
				constitutionBarMeter:Hide()
			end
			if weatherButton then
				weatherButton:Hide()
			end
			if statusIconsRow then
				statusIconsRow:Hide()
			end
			metersContainer:Hide()

			-- Clear references
			AnguishMeter = nil
			exhaustionMeter = nil
			hungerMeter = nil
			temperatureMeter = nil
			constitutionMeter = nil
			constitutionBarMeter = nil
			weatherButton = nil
			statusIconsRow = nil
			metersContainer = nil

			-- Recreate container with new display mode
			CreateMetersContainer()

			-- Restore position using new format
			if savedPos then
				metersContainer:ClearAllPoints()
				if savedPos.screenLeft and savedPos.screenTop then
					-- New format: absolute screen coordinates
					metersContainer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", savedPos.screenLeft, savedPos.screenTop)
				elseif savedPos.point then
					-- Legacy format fallback
					metersContainer:SetPoint(savedPos.point, UIParent, savedPos.relativePoint, savedPos.x, savedPos.y)
				end
			end

			local newMode = CC.GetSetting("meterDisplayMode")
			print("|cff88CCFFCozierCamps:|r Switched to " .. (newMode == "vial" and "vial" or "bar") .. " mode")
		end
	end

	-- Update bar textures when texture setting changes (only affects bar mode, not vial/potion mode)
	if key == "meterBarTexture" or key == "ALL" then
		local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"
		-- Only update meter bars if in bar mode (vial mode uses custom potion textures)
		if displayMode == "bar" then
			if AnguishMeter and AnguishMeter.bar then
				AnguishMeter.bar:SetStatusBarTexture(GetBarTexture())
			end
			if exhaustionMeter and exhaustionMeter.bar then
				exhaustionMeter.bar:SetStatusBarTexture(GetBarTexture())
			end
			if hungerMeter and hungerMeter.bar then
				hungerMeter.bar:SetStatusBarTexture(GetBarTexture())
			end
		end
		-- Temperature meter is always bar style
		if temperatureMeter then
			local texture = GetBarTexture()
			temperatureMeter.coldBar:SetTexture(texture)
			temperatureMeter.hotBar:SetTexture(texture)
			temperatureMeter.fillBar:SetTexture(texture)
		end
		-- Update constitution bar texture (only the bar mode version)
		if constitutionBarMeter and constitutionBarMeter.bar then
			constitutionBarMeter.bar:SetStatusBarTexture(GetBarTexture())
		end
	end

	-- Update fonts when font setting changes
	if key == "generalFont" or key == "ALL" then
		local fontPath = GetGeneralFont()
		local displayMode = CC.GetSetting and CC.GetSetting("meterDisplayMode") or "bar"
		local barFontSize = 10
		local vialFontSize = 10 * VIAL_SCALE -- Scaled for vial mode

		-- Helper function to update a meter's font
		local function UpdateMeterFont(meter, fontSize)
			if not meter or not meter.percent then
				return
			end
			if fontPath then
				meter.percent:SetFont(fontPath, fontSize, "OUTLINE")
			else
				meter.percent:SetFontObject(GameFontNormalSmall)
			end
			-- Also update shadows if they exist (vial mode)
			if meter.percentShadows then
				for _, shadow in ipairs(meter.percentShadows) do
					if fontPath then
						shadow:SetFont(fontPath, fontSize, "OUTLINE")
					else
						shadow:SetFontObject(GameFontNormalSmall)
					end
				end
			end
		end

		-- Determine if we're in vial mode
		local isVialMode = displayMode == "vial"
		local fontSize = isVialMode and vialFontSize or barFontSize

		-- Update all meters
		UpdateMeterFont(AnguishMeter, fontSize)
		UpdateMeterFont(exhaustionMeter, fontSize)
		UpdateMeterFont(hungerMeter, fontSize)
		UpdateMeterFont(temperatureMeter, barFontSize) -- Temperature always uses bar mode size
		UpdateMeterFont(constitutionBarMeter, barFontSize)
		if isVialMode and constitutionMeter then
			UpdateMeterFont(constitutionMeter, vialFontSize)
		end
	end
end)

-- Zone weather changed callback (to resize container when weather button visibility changes)
CC.RegisterCallback("ZONE_WEATHER_CHANGED", function()
	if metersContainer then
		RepositionMeters()
	end
end)

-- Debug Panel for meter adjustments (styled to match settings)
local debugPanel = nil

--- @type function @return void
local function CreateDebugPanel()
	if debugPanel then
		return debugPanel
	end

	-- Create main frame with dark theme
	local panel = CreateFrame("Frame", "CozierCampsDebugPanel", UIParent, "BackdropTemplate")
	panel:SetSize(320, 500)
	panel:SetPoint("CENTER")
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(150)
	panel:SetClampedToScreen(true)

	-- Dark backdrop matching settings
	panel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 2
	})
	panel:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
	panel:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)

	-- Header bar
	local header = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	header:SetSize(320, 50)
	header:SetPoint("TOP")
	header:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8"
	})
	header:SetBackdropColor(0.08, 0.08, 0.10, 1)

	-- Logo container (matching main config style)
	local iconFrame = CreateFrame("Frame", nil, header)
	iconFrame:SetSize(40, 40)
	iconFrame:SetPoint("LEFT", 15, 0)

	-- Fire glow (background)
	local fireGlow = iconFrame:CreateTexture(nil, "BACKGROUND")
	fireGlow:SetSize(50, 50)
	fireGlow:SetPoint("CENTER", 0, 2)
	fireGlow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
	fireGlow:SetVertexColor(1.0, 0.5, 0.1, 0.4)
	fireGlow:SetBlendMode("ADD")

	-- Custom logo from assets
	local fireIcon = iconFrame:CreateTexture(nil, "ARTWORK")
	fireIcon:SetSize(36, 36)
	fireIcon:SetPoint("CENTER")
	fireIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\mainlogo.png")
	fireIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Animated glow pulse
	local glowAnim = fireGlow:CreateAnimationGroup()
	glowAnim:SetLooping("REPEAT")
	local pulse1 = glowAnim:CreateAnimation("Alpha")
	pulse1:SetFromAlpha(0.4)
	pulse1:SetToAlpha(0.7)
	pulse1:SetDuration(1.5)
	pulse1:SetOrder(1)
	pulse1:SetSmoothing("IN_OUT")
	local pulse2 = glowAnim:CreateAnimation("Alpha")
	pulse2:SetFromAlpha(0.7)
	pulse2:SetToAlpha(0.4)
	pulse2:SetDuration(1.5)
	pulse2:SetOrder(2)
	pulse2:SetSmoothing("IN_OUT")
	glowAnim:Play()

	-- Title with shadow
	local titleShadow = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	titleShadow:SetPoint("LEFT", iconFrame, "RIGHT", 11, -1)
	titleShadow:SetText("Debug Panel")
	titleShadow:SetTextColor(0, 0, 0, 0.5)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", iconFrame, "RIGHT", 10, 0)
	title:SetText("Debug Panel")
	title:SetTextColor(1.0, 0.75, 0.35, 1)

	-- Custom close button (styled)
	local closeBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
	closeBtn:SetSize(24, 24)
	closeBtn:SetPoint("TOPRIGHT", -8, -13)
	closeBtn:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1
	})
	closeBtn:SetBackdropColor(0.15, 0.15, 0.18, 1)
	closeBtn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

	local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	closeText:SetPoint("CENTER", 0, 1)
	closeText:SetText("×")
	closeText:SetTextColor(0.7, 0.7, 0.7)

	closeBtn:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(0.9, 0.3, 0.3, 1)
		closeText:SetTextColor(0.9, 0.3, 0.3)
	end)
	closeBtn:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
		closeText:SetTextColor(0.7, 0.7, 0.7)
	end)
	closeBtn:SetScript("OnClick", function()
		if InCombatLockdown() then
			print("|cff88CCFFCozierCamps:|r Cannot close debug panel during combat.")
			return
		end
		panel:Hide()
	end)

	-- Scroll frame for content
	local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 5, -5)
	scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

	-- Style scrollbar
	local scrollBar = scrollFrame.ScrollBar
	if scrollBar then
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -2, -16)
		scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -2, 16)
	end

	-- Content area (inside scroll frame)
	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(290, 800) -- Tall enough for all content
	scrollFrame:SetScrollChild(content)

	-- Sliders container
	local yOffset = 0
	local sliders = {}

	-- Create styled slider function (inverted display: 100 = good, 0 = bad)
	local function CreateSlider(name, label, minVal, maxVal, getValue, setValue, formatFunc, isInverted)
		if not getValue or not setValue then
			return nil
		end

		local sliderFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
		sliderFrame:SetSize(290, 44)
		sliderFrame:SetPoint("TOP", content, "TOP", 0, yOffset)
		sliderFrame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1
		})
		sliderFrame:SetBackdropColor(0.09, 0.09, 0.11, 0.95)
		sliderFrame:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)
		yOffset = yOffset - 50

		-- Label
		local sliderLabel = sliderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		sliderLabel:SetPoint("TOPLEFT", 10, -6)
		sliderLabel:SetText(label)
		sliderLabel:SetTextColor(0.85, 0.85, 0.85)

		-- Value display
		local valueText = sliderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		valueText:SetPoint("TOPRIGHT", -10, -6)
		valueText:SetTextColor(1.0, 0.75, 0.35, 1)

		-- Slider track background
		local sliderBg = sliderFrame:CreateTexture(nil, "BACKGROUND")
		sliderBg:SetSize(270, 8)
		sliderBg:SetPoint("BOTTOM", 0, 8)
		sliderBg:SetColorTexture(0.12, 0.12, 0.14, 1)

		-- Slider
		local slider = CreateFrame("Slider", "CozierCampsSlider" .. name, sliderFrame, "OptionsSliderTemplate")
		slider:SetPoint("BOTTOM", 0, 6)
		slider:SetSize(270, 12)
		slider:SetMinMaxValues(minVal, maxVal)
		slider:SetValueStep(1)
		slider:SetObeyStepOnDrag(true)

		-- Hide default labels
		_G[slider:GetName() .. "Low"]:SetText("")
		_G[slider:GetName() .. "High"]:SetText("")
		_G[slider:GetName() .. "Text"]:SetText("")

		-- Update function (handles inversion for display)
		local function UpdateValue()
			local val = getValue()
			if isInverted then
				slider:SetValue(100 - val) -- Inverted: slider shows 100 when val is 0
				valueText:SetText(formatFunc(100 - val))
			else
				slider:SetValue(val)
				valueText:SetText(formatFunc(val))
			end
		end

		slider:SetScript("OnValueChanged", function(self, value)
			if isInverted then
				setValue(100 - value) -- Inverted: set actual value as inverted slider value
				valueText:SetText(formatFunc(value))
			else
				setValue(value)
				valueText:SetText(formatFunc(value))
			end
		end)

		sliderFrame.Update = UpdateValue
		sliderFrame.slider = slider
		UpdateValue()

		return sliderFrame
	end

	-- Create sliders for enabled meters (inverted so 100% = full/good)
	if CC.GetSetting and CC.GetSetting("AnguishEnabled") and CC.GetAnguish and CC.SetAnguish then
		local s = CreateSlider("Anguish", "Anguish", 0, 100, CC.GetAnguish, CC.SetAnguish, function(v)
			return string.format("%.0f%%", v)
		end, true) -- Inverted
		if s then
			table.insert(sliders, s)
		end
	end

	if CC.GetSetting and CC.GetSetting("exhaustionEnabled") and CC.GetExhaustion and CC.SetExhaustion then
		local s = CreateSlider("Exhaustion", "Exhaustion", 0, 100, CC.GetExhaustion, CC.SetExhaustion, function(v)
			return string.format("%.0f%%", v)
		end, true) -- Inverted
		if s then
			table.insert(sliders, s)
		end
	end

	if CC.GetSetting and CC.GetSetting("hungerEnabled") and CC.GetHunger and CC.SetHunger then
		local s = CreateSlider("Hunger", "Hunger", 0, 100, CC.GetHunger, CC.SetHunger, function(v)
			return string.format("%.0f%%", v)
		end, true) -- Inverted
		if s then
			table.insert(sliders, s)
		end
	end

	if CC.GetSetting and CC.GetSetting("thirstEnabled") and CC.GetThirst and CC.SetThirst then
		local s = CreateSlider("Thirst", "Thirst", 0, 100, CC.GetThirst, CC.SetThirst, function(v)
			return string.format("%.0f%%", v)
		end, true) -- Inverted
		if s then
			table.insert(sliders, s)
		end
	end

	if CC.GetSetting and CC.GetSetting("temperatureEnabled") and CC.GetTemperature and CC.SetTemperature then
		local s = CreateSlider("Temperature", "Temperature", -100, 100, CC.GetTemperature, CC.SetTemperature,
				function(v)
					return string.format("%.0f", v)
				end, false) -- Not inverted (temperature uses -100 to +100)
		if s then
			table.insert(sliders, s)
		end
	end

	-- Add debug checkboxes below sliders
	local debugCheckboxYOffset = yOffset - 5
	local debugSettings = { {
								key = "debugEnabled",
								label = "General Debug",
								tooltip = "Show general debug messages in chat."
							}, {
								key = "proximityDebugEnabled",
								label = "Proximity Debug",
								tooltip = "Show fire proximity detection messages."
							}, {
								key = "AnguishDebugEnabled",
								label = "Anguish Debug",
								tooltip = "Show Anguish system messages."
							}, {
								key = "exhaustionDebugEnabled",
								label = "Exhaustion Debug",
								tooltip = "Show exhaustion system messages."
							}, {
								key = "hungerDebugEnabled",
								label = "Hunger Debug",
								tooltip = "Show hunger system messages."
							}, {
								key = "thirstDebugEnabled",
								label = "Thirst Debug",
								tooltip = "Show thirst system messages."
							}, {
								key = "temperatureDebugEnabled",
								label = "Temperature Debug",
								tooltip = "Show temperature system messages."
							} }
	panel.debugCheckboxes = {}
	for _, dbg in ipairs(debugSettings) do
		local cbFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
		cbFrame:SetSize(290, 26)
		cbFrame:SetPoint("TOP", content, "TOP", 0, debugCheckboxYOffset)
		cbFrame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1
		})
		cbFrame:SetBackdropColor(0.09, 0.09, 0.11, 0.95)
		cbFrame:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)
		debugCheckboxYOffset = debugCheckboxYOffset - 30

		local cb = CreateFrame("CheckButton", nil, cbFrame, "ChatConfigCheckButtonTemplate")
		cb:SetPoint("LEFT", 6, 0)
		cb:SetSize(20, 20)
		cb:SetChecked(CC.GetSetting(dbg.key))
		cb:SetScript("OnClick", function(self)
			CC.SetSetting(dbg.key, self:GetChecked())
		end)

		local text = cbFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
		text:SetText(dbg.label)
		text:SetTextColor(0.75, 0.75, 0.75)

		cbFrame:SetScript("OnEnter", function(self)
			self:SetBackdropBorderColor(1.0, 0.6, 0.2, 1)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(dbg.label, 1.0, 0.75, 0.35)
			GameTooltip:AddLine(dbg.tooltip, 0.75, 0.75, 0.75, true)
			GameTooltip:Show()
		end)
		cbFrame:SetScript("OnLeave", function(self)
			self:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)
			GameTooltip:Hide()
		end)

		table.insert(panel.debugCheckboxes, cb)
	end

	-- Add debug toggle buttons section
	local buttonYOffset = debugCheckboxYOffset - 15

	-- Section header for debug toggles
	local toggleHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	toggleHeader:SetPoint("TOP", content, "TOP", 0, buttonYOffset)
	toggleHeader:SetText("Debug Toggles")
	toggleHeader:SetTextColor(1.0, 0.75, 0.35)
	buttonYOffset = buttonYOffset - 20

	-- Helper function to create toggle buttons
	local function CreateToggleButton(label, xOffset, yOff, width, onClick, getState)
		local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
		btn:SetSize(width, 24)
		btn:SetPoint("TOP", content, "TOP", xOffset, yOff)
		btn:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1
		})
		btn:SetBackdropColor(0.12, 0.12, 0.14, 1)
		btn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
		local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetPoint("CENTER")
		text:SetText(label)
		text:SetTextColor(0.7, 0.7, 0.7, 1)
		btn.label = text
		btn:SetScript("OnEnter", function(self)
			self:SetBackdropBorderColor(1.0, 0.6, 0.2, 1)
			text:SetTextColor(1, 1, 1, 1)
		end)
		btn:SetScript("OnLeave", function(self)
			self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
			text:SetTextColor(0.7, 0.7, 0.7, 1)
		end)
		btn:SetScript("OnClick", onClick)
		btn.getState = getState
		return btn
	end

	-- Wet/Dry toggle buttons
	local wetBtn = CreateToggleButton("Set Wet", -75, buttonYOffset, 90, function()
		if CC.SetWetEffect then
			CC.SetWetEffect(true)
			print("|cff88CCFFCozierCamps:|r Debug: Set to WET")
		end
	end)
	local dryBtn = CreateToggleButton("Set Dry", 75, buttonYOffset, 90, function()
		if CC.SetWetEffect then
			CC.SetWetEffect(false)
			print("|cff88CCFFCozierCamps:|r Debug: Set to DRY")
		end
	end)
	buttonYOffset = buttonYOffset - 30

	-- Weather type section header
	local weatherHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	weatherHeader:SetPoint("TOP", content, "TOP", 0, buttonYOffset)
	weatherHeader:SetText("Weather Type Override")
	weatherHeader:SetTextColor(0.6, 0.6, 0.6)
	buttonYOffset = buttonYOffset - 18

	-- Weather type toggle buttons (2 rows of 2)
	local rainBtn = CreateToggleButton("Rain", -75, buttonYOffset, 90, function()
		if CC.SetDebugWeatherType then
			CC.SetDebugWeatherType(1) -- WEATHER_TYPE_RAIN
			print("|cff88CCFFCozierCamps:|r Debug: Weather set to RAIN")
		end
	end)
	local snowBtn = CreateToggleButton("Snow", 75, buttonYOffset, 90, function()
		if CC.SetDebugWeatherType then
			CC.SetDebugWeatherType(2) -- WEATHER_TYPE_SNOW
			print("|cff88CCFFCozierCamps:|r Debug: Weather set to SNOW")
		end
	end)
	buttonYOffset = buttonYOffset - 28

	local dustBtn = CreateToggleButton("Dust", -75, buttonYOffset, 90, function()
		if CC.SetDebugWeatherType then
			CC.SetDebugWeatherType(3) -- WEATHER_TYPE_DUST
			print("|cff88CCFFCozierCamps:|r Debug: Weather set to DUST")
		end
	end)
	local stormBtn = CreateToggleButton("Storm", 75, buttonYOffset, 90, function()
		if CC.SetDebugWeatherType then
			CC.SetDebugWeatherType(4) -- WEATHER_TYPE_STORM
			print("|cff88CCFFCozierCamps:|r Debug: Weather set to STORM")
		end
	end)
	buttonYOffset = buttonYOffset - 28

	local clearBtn = CreateToggleButton("Clear", 0, buttonYOffset, 90, function()
		if CC.SetDebugWeatherType then
			CC.SetDebugWeatherType(nil) -- Clear override
			print("|cff88CCFFCozierCamps:|r Debug: Weather override CLEARED")
		end
	end)
	buttonYOffset = buttonYOffset - 10

	-- Adjust content height based on sliders, checkboxes, and toggle buttons
	local contentHeight = 20 + (#sliders * 50) + (#debugSettings * 30) + 150
	content:SetHeight(math.max(contentHeight, 400))

	-- If no sliders, show message
	if #sliders == 0 then
		local noMeters = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		noMeters:SetPoint("TOP", 0, -20)
		noMeters:SetText("No meters enabled")
		noMeters:SetTextColor(0.55, 0.55, 0.55)
	end

	-- Update timer to keep sliders and checkboxes in sync
	panel.sliders = sliders
	panel:SetScript("OnUpdate", function(self, elapsed)
		self.updateTimer = (self.updateTimer or 0) + elapsed
		if self.updateTimer >= 0.2 then
			self.updateTimer = 0
			for _, s in ipairs(self.sliders) do
				if s.Update then
					s.Update()
				end
			end
			for i, cb in ipairs(self.debugCheckboxes) do
				local dbg = debugSettings[i]
				cb:SetChecked(CC.GetSetting(dbg.key))
			end
		end
	end)

	panel:Hide()
	debugPanel = panel
	return panel
end

function CC.ToggleDebugPanel()
	-- Prevent showing/hiding during combat to avoid taint
	if InCombatLockdown() then
		print("|cff88CCFFCozierCamps:|r Cannot toggle debug panel during combat.")
		return
	end
	local panel = CreateDebugPanel()
	if panel:IsShown() then
		panel:Hide()
	else
		panel:Show()
	end
end

-- Minimap Button for CozierCamps settings
local MINIMAP_BUTTON_SIZE = 32
local minimapButton = nil

local function CreateMinimapButton()
	if minimapButton then
		return minimapButton
	end

	local button = CreateFrame("Button", "CozierCampsMinimapButton", Minimap)
	button:SetSize(MINIMAP_BUTTON_SIZE, MINIMAP_BUTTON_SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetClampedToScreen(true)

	-- Position on minimap edge (default position)
	local angle = CC.GetSetting and CC.GetSetting("minimapButtonAngle") or 220
	button.angle = angle

	local function UpdatePosition()
		local radian = math.rad(button.angle)
		local minSize = math.min(Minimap:GetWidth(), Minimap:GetHeight())
		local radius = (minSize / 2) + 6
		local x = math.cos(radian) * radius
		local y = math.sin(radian) * radius
		button:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end
	UpdatePosition()

	-- Background overlay (solid circle behind icon)
	button.overlay = button:CreateTexture(nil, "BACKGROUND")
	button.overlay:SetSize(25, 25)
	button.overlay:SetPoint("CENTER", -1, 1)
	button.overlay:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

	-- Icon - using CozierCamps fire icon, 1.5x size and orange colored
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetSize(30, 30)
	button.icon:SetPoint("CENTER", -1, 1)
	button.icon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\fireicon")
	button.icon:SetVertexColor(1.0, 0.6, 0.2, 1.0) -- Orange color

	-- Border (the golden ring)
	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetSize(52, 52)
	button.border:SetPoint("TOPLEFT", 0, 0)
	button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	-- Highlight
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	-- Dragging support
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", function(self)
		self.isDragging = true
	end)
	button:SetScript("OnDragStop", function(self)
		self.isDragging = false
		if CC.SetSetting then
			CC.SetSetting("minimapButtonAngle", self.angle)
		end
	end)
	button:SetScript("OnUpdate", function(self)
		if self.isDragging then
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			cx, cy = cx / scale, cy / scale
			self.angle = math.deg(math.atan2(cy - my, cx - mx))
			UpdatePosition()
		end
	end)

	-- Click handler - left click opens settings, shift+left click opens debug, right click opens debug
	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "LeftButton" then
			if IsShiftKeyDown() then
				if CC.ToggleDebugPanel then
					CC.ToggleDebugPanel()
					PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
				end
			else
				if CC.ToggleSettings then
					CC.ToggleSettings()
					PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
				end
			end
		elseif mouseButton == "RightButton" then
			if CC.ToggleSettings then
				CC.ToggleSettings()
				PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
			end
		end
	end)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	-- Tooltip
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("CozierCamps", 1, 0.6, 0)
		GameTooltip:AddLine("Left-click to open settings", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Drag to reposition", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)

	minimapButton = button
	return button
end

-- Initialize minimap button on addon load
local minimapButtonFrame = CreateFrame("Frame")
minimapButtonFrame:RegisterEvent("PLAYER_LOGIN")
minimapButtonFrame:SetScript("OnEvent", function()
	CreateMinimapButton()
end)

-- Expose for external access
function CC.GetMinimapButton()
	return minimapButton
end
