-- CozierCamps - Core.lua
-- Standalone addon for campfire-based gameplay restrictions
--- @global CozierCamps
CozierCamps = {
	version = "0.0.1",
	name = "CozierCamps",
	isNearFire = false,
	isNearFireRaw = false, -- True proximity, ignores combat
	inCombat = false,
	isManualRestActive = false, -- For Manual Rest Mode
	lastPlayerX = nil, -- For movement detection
	lastPlayerY = nil,
	callbacks = {}
}

local CC = CozierCamps
local MIN_LEVEL = 6

-- Shared constants for colors (reduces string allocations)
CC.COLORS = {
	ADDON = "|cff88CCFF",
	PROXIMITY = "|cff88FF88",
	EXHAUSTION = "|cffFFAA88",
	ANGUISH = "|cffFF6688",
	HUNGER = "|cffFFBB44",
	THIRST = "|cff66B8FF",
	TEMPERATURE = "|cffFFCC55",
	WARNING = "|cffFF6600",
	SUCCESS = "|cff00FF00",
	ERROR = "|cffFF0000"
}

-- Shared asset path prefix
CC.ASSET_PATH = "Interface\\AddOns\\CozierCamps\\assets\\"

-- Debug category to setting mapping (optimization for Debug function)
local DEBUG_SETTINGS = {
	general = "debugEnabled",
	proximity = "proximityDebugEnabled",
	exhaustion = "exhaustionDebugEnabled",
	Anguish = "AnguishDebugEnabled",
	hunger = "hungerDebugEnabled",
	thirst = "thirstDebugEnabled",
	temperature = "temperatureDebugEnabled"
}

-- Debug category to color mapping
local DEBUG_COLORS = {
	general = CC.COLORS.ADDON,
	proximity = CC.COLORS.PROXIMITY,
	exhaustion = CC.COLORS.EXHAUSTION,
	Anguish = CC.COLORS.ANGUISH,
	hunger = CC.COLORS.HUNGER,
	thirst = CC.COLORS.THIRST,
	temperature = CC.COLORS.TEMPERATURE
}

-- Reusable status table (avoids allocation on every GetStatus call)
local cachedStatus = {}

-- Shared dungeon check function (used by Exhaustion, Hunger, Anguish)
function CC.IsInDungeonOrRaid()
	local inInstance, instanceType = IsInInstance()
	return inInstance and (instanceType == "party"
			or instanceType == "raid"
			or instanceType == "scenario"
			or instanceType == "delve")
end

local DEFAULT_SETTINGS = {
	-- Core features
	enabled = true,
	campfireRange = 2, -- Default to 2 yards (clamped 2-4)
	detectPlayerCampfires = false,

	-- Fire Detection Mode: 1 = Auto Detect (default), 2 = Manual Rest Mode
	fireDetectionMode = 1,

	-- Action bar hiding: 1=Disabled, 2=Always hide, 3=Rested areas only
	hideActionBarsMode = 1,

	-- Hide minimap when action bars are hidden (constitution override still hides it)
	hideMinimapWithBars = true,

	-- Meter/bar scaling (0.5 = 50%, 1.0 = 100%, 1.5 = 150%)
	meterScale = 1.0,

	-- Map blocking
	blockMap = false,

	-- Show survival icons on world map (fires, inns, first aid trainers)
	showSurvivalIcons = false,

	-- Play sound when near fire
	playSoundNearFire = true,

	-- Play sound when anguish is relieved (innkeeper/first aid trainer)
	playSoundAnguishRelief = false,

	-- Play sound when hunger is relieved (cooking trainer)
	playSoundHungerRelief = false,

	-- Play heartbeat sound when constitution is below 25%
	playSoundHeartbeat = false,

	-- Meters locked (cannot be moved)
	metersLocked = false,

	-- Exhaustion system (movement-based)
	exhaustionEnabled = true,
	exhaustionDecayRate = 0.5, -- Fire recovery rate
	exhaustionInnDecayRate = 1.5, -- Inn/rested area recovery rate (faster)

	-- Anguish system (damage-based)
	AnguishEnabled = false,
	AnguishScale = 1, -- 1=0.1x, 2=0.5x, 3=3x
	innkeeperHealsAnguish = false, -- Reset anguish when talking to innkeepers
	innkeeperResetsHunger = true, -- Reset hunger when talking to innkeepers (on by default)
	innkeeperResetsThirst = true, -- Reset thirst when talking to innkeepers (on by default)

	-- Hunger system (scales with temperature and exhaustion)
	hungerEnabled = false,
	hungerMaxDarkness = 0.25, -- Maximum screen darkness at 100% hunger (0-1, default 25%)

	-- Thirst system (scales with temperature and exhaustion)
	thirstEnabled = false,
	thirstMaxDarkness = 0.25, -- Maximum screen darkness at 100% thirst (0-1, default 25%)

	-- Temperature system (zone and weather-based)
	temperatureEnabled = false,
	manualWeatherEnabled = true, -- Manual weather toggle button (on by default)
	wetScreenEffectEnabled = false, -- Screen overlay when wet (off by default)

	-- Constitution/Adventure Mode (requires at least 2 meters enabled)
	constitutionEnabled = false, -- Disabled by default for Lite

	-- HP Tunnel Vision (agnostic of other settings)
	hpTunnelVisionEnabled = false, -- Off by default

	-- Meter bar texture (index into texture list)
	meterBarTexture = 1,

	-- General font (index into font list) - used for all addon text
	generalFont = 1,

	-- Meter display mode: "bar" = horizontal bars, "vial" = vertical potion vials
	meterDisplayMode = "vial",

	-- Hide vial text (percentage numbers on vials)
	hideVialText = false,

	-- Tooltip display mode: "detailed" = full info, "minimal" = current values only, "disabled" = no tooltips
	tooltipDisplayMode = "detailed",

	-- Debug
	debugEnabled = false,
	proximityDebugEnabled = false,
	exhaustionDebugEnabled = false,
	AnguishDebugEnabled = false,
	hungerDebugEnabled = false,
	thirstDebugEnabled = false,
	temperatureDebugEnabled = false
}

local function InitializeSavedVariables()
	if not CozierCampsDB then
		CozierCampsDB = {}
	end
	for key, default in pairs(DEFAULT_SETTINGS) do
		if CozierCampsDB[key] == nil then
			CozierCampsDB[key] = default
		end
	end
	CC.db = CozierCampsDB

	-- Initialize character-specific saved variables
	if not CozierCampsCharDB then
		CozierCampsCharDB = {}
	end
	CC.charDB = CozierCampsCharDB
end

function CC.GetSetting(key)
	if CC.db and CC.db[key] ~= nil then
		return CC.db[key]
	end
	return DEFAULT_SETTINGS[key]
end

function CC.SetSetting(key, value)
	if CC.db then
		CC.db[key] = value

		-- Handle master toggle disable - reset related settings
		if key == "enabled" and value == false then
			CC.db.blockMap = false
			CC.db.showSurvivalIcons = false
			CC.db.debugEnabled = false
			CC.db.proximityDebugEnabled = false
			CC.db.exhaustionDebugEnabled = false
			CC.db.AnguishDebugEnabled = false
			CC.db.thirstDebugEnabled = false
			CC.db.temperatureDebugEnabled = false
		end

		CC.FireCallbacks("SETTINGS_CHANGED", key, value)
	end
end

function CC.ResetSettings()
	for key, value in pairs(DEFAULT_SETTINGS) do
		CC.db[key] = value
	end
	CC.FireCallbacks("SETTINGS_CHANGED", "ALL", nil)
end

function CC.GetDefaultSetting(key)
	return DEFAULT_SETTINGS[key]
end

function CC.GetMinLevel()
	return MIN_LEVEL
end

function CC.IsPlayerEligible()
	-- Check master toggle first
	if not CC.GetSetting("enabled") then
		return false
	end
	return UnitLevel("player") >= MIN_LEVEL
end

-- Callback System
function CC.RegisterCallback(eventOrFunc, callback)
	if type(eventOrFunc) == "function" then
		if not CC.callbacks["LEGACY"] then
			CC.callbacks["LEGACY"] = {}
		end
		table.insert(CC.callbacks["LEGACY"], eventOrFunc)
		return true
	end
	if type(callback) ~= "function" then
		return false
	end
	if not CC.callbacks[eventOrFunc] then
		CC.callbacks[eventOrFunc] = {}
	end
	table.insert(CC.callbacks[eventOrFunc], callback)
	return true
end

function CC.FireCallbacks(event, ...)
	if CC.callbacks[event] then
		for _, callback in ipairs(CC.callbacks[event]) do
			pcall(callback, ...)
		end
	end
	if event == "FIRE_STATE_CHANGED" and CC.callbacks["LEGACY"] then
		for _, callback in ipairs(CC.callbacks["LEGACY"]) do
			pcall(callback, CC.isNearFire, CC.inCombat)
		end
	end
end

-- Debug (optimized with lookup tables)
function CC.Debug(msg, category)
	category = category or "general"
	local settingKey = DEBUG_SETTINGS[category]
	if not settingKey or not CC.GetSetting(settingKey) then
		return
	end
	local color = DEBUG_COLORS[category] or CC.COLORS.ADDON
	print(color .. "CozierCamps:|r " .. msg)
end

-- Utility functions
function CC.ShouldShowActionBars()
	local mode = CC.GetSetting("hideActionBarsMode") or 2
	-- Mode 1: Never hide (disabled)
	if mode == 1 then
		return true
	end
	if not CC.IsPlayerEligible() then
		return true
	end
	if CC.IsInDungeonOrRaid and CC.IsInDungeonOrRaid() then
		return true
	end
	if CC.inCombat then
		return false
	end
	-- Mode 3: Only show in rested areas
	if mode == 3 then
		return IsResting()
	end
	-- Mode 2: Show near fire, rested, taxi, dead, or ghost
	return CC.isNearFire or IsResting() or UnitOnTaxi("player") or UnitIsDead("player") or UnitIsGhost("player")
end

function CC.CanUseMap()
	if not CC.GetSetting("blockMap") then
		return true
	end
	if not CC.IsPlayerEligible() then
		return true
	end
	if CC.IsInDungeonOrRaid and CC.IsInDungeonOrRaid() then
		return true
	end
	if IsResting() then
		return true
	end
	if UnitOnTaxi("player") then
		return true
	end
	if UnitIsDead("player") or UnitIsGhost("player") then
		return true
	end
	-- Block map if constitution is at or below 25%
	local constitution = CC.GetConstitution and CC.GetConstitution()
	if constitution and constitution <= 25 then
		return false
	end
	return CC.isNearFire
end

function CC.GetStatus()
	-- Reuse cached table to avoid allocation
	cachedStatus.isNearFire = CC.isNearFire
	cachedStatus.inCombat = CC.inCombat
	cachedStatus.isManualRestActive = CC.isManualRestActive
	cachedStatus.shouldShowBars = CC.ShouldShowActionBars()
	cachedStatus.canUseMap = CC.CanUseMap()
	cachedStatus.exhaustion = CC.GetExhaustion and CC.GetExhaustion() or 0
	cachedStatus.Anguish = CC.GetAnguish and CC.GetAnguish() or 0
	cachedStatus.hunger = CC.GetHunger and CC.GetHunger() or 0
	cachedStatus.thirst = CC.GetThirst and CC.GetThirst() or 0
	cachedStatus.temperature = CC.GetTemperature and CC.GetTemperature() or 0
	cachedStatus.exhaustionEnabled = CC.GetSetting("exhaustionEnabled")
	cachedStatus.AnguishEnabled = CC.GetSetting("AnguishEnabled")
	cachedStatus.hungerEnabled = CC.GetSetting("hungerEnabled")
	cachedStatus.thirstEnabled = CC.GetSetting("thirstEnabled")
	cachedStatus.temperatureEnabled = CC.GetSetting("temperatureEnabled")
	cachedStatus.hideActionBars = CC.GetSetting("hideActionBars")
	cachedStatus.blockMap = CC.GetSetting("blockMap")
	cachedStatus.fireDetectionMode = CC.GetSetting("fireDetectionMode")
	cachedStatus.playerLevel = UnitLevel("player")
	cachedStatus.minLevel = MIN_LEVEL
	cachedStatus.version = CC.version
	return cachedStatus
end

-- Manual Rest Mode functions
function CC.ActivateManualRest()
	if CC.GetSetting("fireDetectionMode") ~= 2 then
		return false
	end
	CC.isManualRestActive = true
	-- Fire callback first (triggers grace period in CampfireDetection)
	CC.FireCallbacks("MANUAL_REST_CHANGED", true)
	-- Make the player sit after callback
	DoEmote("SIT")
	CC.Debug("Manual rest activated", "general")
	return true
end

function CC.DeactivateManualRest()
	if not CC.isManualRestActive then
		return false
	end
	CC.isManualRestActive = false
	CC.Debug("Manual rest deactivated", "general")
	CC.FireCallbacks("MANUAL_REST_CHANGED", false)
	return true
end

function CC.IsManualRestMode()
	return CC.GetSetting("fireDetectionMode") == 2
end

-- Get fire locations for a zone (used by MapOverlay)
function CC.GetFireLocations(zoneName)
	if not CozierCampsFireDB then
		return nil
	end
	return CozierCampsFireDB[zoneName]
end

-- UHC Conflict Detection
local function CheckUHCConflict()
	local hasConflict = false
	local conflicts = {}

	-- Check if UHC is loaded (handle API differences between WoW versions)
	local uhcLoaded = false
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		uhcLoaded = C_AddOns.IsAddOnLoaded("UltraHardcore")
	elseif IsAddOnLoaded then
		uhcLoaded = IsAddOnLoaded("UltraHardcore")
	end

	if uhcLoaded and GLOBAL_SETTINGS then
		if GLOBAL_SETTINGS.routePlanner and CC.GetSetting("blockMap") then
			hasConflict = true
			table.insert(conflicts, "Route Planner (map blocking)")
		end
		if GLOBAL_SETTINGS.hideActionBars and CC.GetSetting("hideActionBars") then
			hasConflict = true
			table.insert(conflicts, "Hide Action Bars")
		end
	end

	if hasConflict then
		local msg = "|cffFF6600CozierCamps Warning:|r UltraHardcore has conflicting settings enabled:\n"
		for _, c in ipairs(conflicts) do
			msg = msg .. "  - " .. c .. "\n"
		end
		msg = msg .. "Please disable these in UHC or CozierCamps to avoid issues."

		-- Show after a delay to ensure chat is ready
		C_Timer.After(5, function()
			print(msg)
		end)
	end

	return hasConflict, conflicts
end

-- Level requirement popup frame (styled to match settings)
local function CreateLevelRequirementPopup()
	local popup = CreateFrame("Frame", "CozierCampsLevelPopup", UIParent, "BackdropTemplate")
	popup:SetSize(360, 180)
	popup:SetPoint("CENTER", 0, 100)
	popup:SetFrameStrata("DIALOG")
	popup:SetFrameLevel(200)
	popup:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 2
	})
	popup:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
	popup:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)
	popup:EnableMouse(true)
	popup:SetMovable(true)
	popup:RegisterForDrag("LeftButton")
	popup:SetScript("OnDragStart", popup.StartMoving)
	popup:SetScript("OnDragStop", popup.StopMovingOrSizing)

	-- Header bar
	local header = CreateFrame("Frame", nil, popup, "BackdropTemplate")
	header:SetSize(360, 50)
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

	-- Title
	local titleShadow = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	titleShadow:SetPoint("LEFT", iconFrame, "RIGHT", 11, -1)
	titleShadow:SetText("Welcome!")
	titleShadow:SetTextColor(0, 0, 0, 0.5)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", iconFrame, "RIGHT", 10, 0)
	title:SetText("Welcome!")
	title:SetTextColor(1.0, 0.75, 0.35, 1)

	-- Content area
	local content = CreateFrame("Frame", nil, popup, "BackdropTemplate")
	content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -10)
	content:SetPoint("BOTTOMRIGHT", -10, 50)
	content:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1
	})
	content:SetBackdropColor(0.09, 0.09, 0.11, 0.95)
	content:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)

	local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", 0, 0)
	text:SetWidth(320)
	text:SetText(
			"CozierCamps survival systems will activate once you reach |cffFF9933Level 6|r.\n\nUntil then, enjoy your early adventures!")
	text:SetTextColor(0.85, 0.85, 0.85)
	text:SetJustifyH("CENTER")

	-- Styled button
	local okButton = CreateFrame("Button", nil, popup, "BackdropTemplate")
	okButton:SetSize(100, 28)
	okButton:SetPoint("BOTTOM", 0, 12)
	okButton:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1
	})
	okButton:SetBackdropColor(0.12, 0.12, 0.14, 1)
	okButton:SetBackdropBorderColor(1.0, 0.6, 0.2, 1)

	local btnText = okButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btnText:SetPoint("CENTER")
	btnText:SetText("Got it!")
	btnText:SetTextColor(1.0, 0.75, 0.35, 1)

	okButton:SetScript("OnEnter", function(self)
		self:SetBackdropColor(0.18, 0.18, 0.2, 1)
		self:SetBackdropBorderColor(1.0, 0.7, 0.3, 1)
	end)
	okButton:SetScript("OnLeave", function(self)
		self:SetBackdropColor(0.12, 0.12, 0.14, 1)
		self:SetBackdropBorderColor(1.0, 0.6, 0.2, 1)
	end)
	okButton:SetScript("OnClick", function()
		popup:Hide()
		if CC.charDB then
			CC.charDB.seenLevelPopup = true
		end
	end)

	popup:Hide()
	return popup
end

local levelPopup = nil

-- Show level requirement info for new characters
local function ShowLevelRequirementInfo()
	local playerLevel = UnitLevel("player")
	if playerLevel >= MIN_LEVEL then
		return -- Already at or above required level
	end

	-- Show chat message
	print("|cff88CCFFCozierCamps:|r Survival systems will activate at |cffffd700Level " .. MIN_LEVEL ..
			"|r. (Currently Level " .. playerLevel .. ")")

	-- Show popup only once per character
	if CC.charDB and not CC.charDB.seenLevelPopup then
		if not levelPopup then
			levelPopup = CreateLevelRequirementPopup()
		end
		levelPopup:Show()
	end
end

-- Notify when reaching required level
local function OnLevelUp(newLevel)
	if newLevel == MIN_LEVEL then
		print("|cff88CCFFCozierCamps:|r |cff00ff00You've reached Level " .. MIN_LEVEL ..
				"! Survival systems are now active.|r")
		print("|cff88CCFFCozierCamps:|r Type |cffffff00/cozy|r to open settings.")
	end
end

-- Initialization
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_LOGOUT")
initFrame:RegisterEvent("PLAYER_LEVEL_UP")

initFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "CozierCamps" then
		InitializeSavedVariables()
	elseif event == "PLAYER_LOGIN" then
		print("|cff88CCFFCozierCamps|r v" .. CC.version .. " loaded. Type |cffffff00/cozy|r for commands.")
		CheckUHCConflict()
		-- Show level requirement info after a brief delay (let UI settle)
		C_Timer.After(2, ShowLevelRequirementInfo)
		CC.FireCallbacks("PLAYER_LOGIN")
	elseif event == "PLAYER_LOGOUT" then
		CC.FireCallbacks("PLAYER_LOGOUT")
	elseif event == "PLAYER_LEVEL_UP" then
		local newLevel = arg1
		OnLevelUp(newLevel)
	end
end)

-- Slash Commands
SLASH_COZYCAMP1 = "/cozy"
SLASH_COZYCAMP2 = "/CozierCamps"
SLASH_REST1 = "/rest"

SlashCmdList["REST"] = function(msg)
	if CC.GetSetting("fireDetectionMode") == 2 then
		CC.ActivateManualRest()
	else
		print("|cff88CCFFCozierCamps:|r /rest only works in Manual Rest Mode. Change mode in settings.")
	end
end

SlashCmdList["COZYCAMP"] = function(msg)
	msg = string.lower(msg or "")
	local command, value = msg:match("([^%s]+)%s*(.*)")
	command = command or ""

	if command == "" then
		if CC.OpenSettings then
			CC.OpenSettings()
		else
			print("|cff88CCFFCozierCamps:|r Settings UI not available.")
		end
		return
	elseif command == "status" or command == "s" then
		local s = CC.GetStatus()
		local inDungeon = CC.IsInDungeon and CC.IsInDungeon() or false
		local isResting = IsResting()
		local nearFireRaw = CC.isNearFireRaw or false
		local onTaxi = UnitOnTaxi("player")
		local modeNames = { "Auto Detect", "Manual Rest" }

		print("|cff88CCFFCozierCamps Status:|r")
		print("  Level: " .. s.playerLevel .. " (min " .. s.minLevel .. ")")
		print("  Detection Mode: |cffFFCC00" .. (modeNames[s.fireDetectionMode] or "Unknown") .. "|r")
		print("  Near Fire: " .. (nearFireRaw and "|cff00FF00YES|r" or "|cffFF0000NO|r"))
		if s.fireDetectionMode == 2 then
			print("  Manual Rest: " .. (s.isManualRestActive and "|cff00FF00ACTIVE|r" or "|cff888888INACTIVE|r"))
		end
		print("  Resting: " .. (isResting and "|cff00FF00YES|r" or "|cff888888NO|r"))
		print("  On Flight: " .. (onTaxi and "|cff00FF00YES|r" or "|cff888888NO|r"))
		print("  In Combat: " .. (s.inCombat and "|cffFF8800YES|r" or "|cff888888NO|r"))
		print("  In Dungeon: " .. (inDungeon and "|cffFFAA00YES|r" or "|cff888888NO|r"))
		print("  Indoors: " .. (IsIndoors() and "|cff00FF00YES|r" or "|cff888888NO|r"))

		if not s.hideActionBars then
			print("  Action Bars: |cff888888ALWAYS SHOWN|r")
		else
			print("  Action Bars: " .. (s.shouldShowBars and "|cff00FF00SHOWN|r" or "|cffFF0000HIDDEN|r"))
		end

		if not s.blockMap then
			print("  Map: |cff888888ALWAYS ALLOWED|r")
		else
			print("  Map: " .. (s.canUseMap and "|cff00FF00ALLOWED|r" or "|cffFF0000BLOCKED|r"))
		end

		if not s.exhaustionEnabled then
			print("  Exhaustion: |cff888888DISABLED|r")
		elseif inDungeon then
			print("  Exhaustion: |cffFFAA00PAUSED|r (" .. string.format("%.1f%%", s.exhaustion) .. ")")
		else
			local canDecay = (isResting or s.isNearFire) and not s.inCombat
			local decayStatus = canDecay and " |cff00FF00(recovering)|r" or ""
			print("  Exhaustion: " .. string.format("%.1f%%", s.exhaustion) .. decayStatus)
		end

		if not s.AnguishEnabled then
			print("  Anguish: |cff888888DISABLED|r")
		elseif inDungeon then
			print("  Anguish: |cffFFAA00PAUSED|r (" .. string.format("%.1f%%", s.Anguish) .. ")")
		else
			print("  Anguish: " .. string.format("%.1f%%", s.Anguish))
		end

		if not s.temperatureEnabled then
			print("  Temperature: |cff888888DISABLED|r")
		elseif inDungeon then
			print("  Temperature: |cffFFAA00PAUSED|r (" .. string.format("%.0f", s.temperature) .. ")")
		else
			local tempColor = "|cff888888"
			local tempStatus = "Neutral"
			if s.temperature < -50 then
				tempColor = "|cff3366FF"
				tempStatus = "Freezing"
			elseif s.temperature < -20 then
				tempColor = "|cff5588FF"
				tempStatus = "Cold"
			elseif s.temperature < -5 then
				tempColor = "|cff77AAFF"
				tempStatus = "Chilly"
			elseif s.temperature > 50 then
				tempColor = "|cffFF6622"
				tempStatus = "Scorching"
			elseif s.temperature > 20 then
				tempColor = "|cffFF9933"
				tempStatus = "Hot"
			elseif s.temperature > 5 then
				tempColor = "|cffFFCC55"
				tempStatus = "Warm"
			end
			local isRecovering = CC.IsTemperatureRecovering and CC.IsTemperatureRecovering()
			local recStatus = isRecovering and " |cff00FF00(recovering)|r" or ""
			print(
					"  Temperature: " .. tempColor .. string.format("%.0f", s.temperature) .. " (" .. tempStatus .. ")|r" ..
							recStatus)
		end

	elseif command == "debug" or command == "debugpanel" or command == "dp" or command == "sliders" then
		if CC.ToggleDebugPanel then
			CC.ToggleDebugPanel()
		else
			print("|cff88CCFFCozierCamps:|r Debug panel not available")
		end
		return
	elseif command == "proximity" then
		local current = CC.GetSetting("proximityDebugEnabled")
		CC.SetSetting("proximityDebugEnabled", not current)
		print("|cff88CCFFCozierCamps:|r Proximity debug " .. (not current and "|cff00FF00ON|r" or "|cffFF0000OFF|r"))

	elseif command == "exhaustion" then
		local current = CC.GetSetting("exhaustionDebugEnabled")
		CC.SetSetting("exhaustionDebugEnabled", not current)
		print("|cff88CCFFCozierCamps:|r Exhaustion debug " .. (not current and "|cff00FF00ON|r" or "|cffFF0000OFF|r"))

	elseif command == "Anguish" then
		local current = CC.GetSetting("AnguishDebugEnabled")
		CC.SetSetting("AnguishDebugEnabled", not current)
		print("|cff88CCFFCozierCamps:|r Anguish debug " .. (not current and "|cff00FF00ON|r" or "|cffFF0000OFF|r"))

	elseif command == "temperature" or command == "temp" then
		local current = CC.GetSetting("temperatureDebugEnabled")
		CC.SetSetting("temperatureDebugEnabled", not current)
		print("|cff88CCFFCozierCamps:|r Temperature debug " .. (not current and "|cff00FF00ON|r" or "|cffFF0000OFF|r"))

	elseif command == "debugpanel" or command == "dp" or command == "sliders" then
		if CC.ToggleDebugPanel then
			CC.ToggleDebugPanel()
		else
			print("|cff88CCFFCozierCamps:|r Debug panel not available")
		end

	elseif command == "mode" or command == "displaymode" then
		local currentMode = CC.GetSetting("meterDisplayMode")
		local newMode = currentMode == "bar" and "vial" or "bar"
		CC.SetSetting("meterDisplayMode", newMode)
		print("|cff88CCFFCozierCamps:|r Meter display mode set to |cffFFD700" .. newMode .. "|r")
		print("|cff88CCFFCozierCamps:|r |cffFFFF00/reload required to apply changes|r")

	elseif command == "bar" then
		CC.SetSetting("meterDisplayMode", "bar")
		print("|cff88CCFFCozierCamps:|r Meter display mode set to |cffFFD700bar|r")
		print("|cff88CCFFCozierCamps:|r |cffFFFF00/reload required to apply changes|r")

	elseif command == "vial" then
		CC.SetSetting("meterDisplayMode", "vial")
		print("|cff88CCFFCozierCamps:|r Meter display mode set to |cffFFD700vial|r")
		print("|cff88CCFFCozierCamps:|r |cffFFFF00/reload required to apply changes|r")

	elseif command == "config" or command == "options" or command == "settings" then
		if CC.ToggleSettings then
			CC.ToggleSettings()
		end

	elseif command == "help" or command == "?" or command == "" then
		print("|cff88CCFF=== CozierCamps v" .. CC.version .. " ===|r")
		print("|cffffff00/cozy|r or |cffffff00/CozierCamps|r - Open config page")
		print("|cffffff00/rest|r - Activate rest (Manual Rest Mode only)")
		print("|cffffff00/logfire [desc]|r - Log fire at current position")

	else
		print("|cff88CCFFCozierCamps:|r Unknown command. Use |cffffff00/cozy|r for help.")
	end
end

-- Compatibility alias
CookingRangeCheck = CozierCamps
