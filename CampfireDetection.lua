-- CozyCamps - CampfireDetection.lua
-- Proximity detection for campfires with Auto Detect and Manual Rest modes
-- Updated for Midnight (Retail 12.0.1 / 120001) compatibility
--
-- FIX: UnitBuff() is nil in this client; replaced UnitBuff-based checks with AuraUtil-based scanning.
-- The original UnitBuff loops were in HasBasicCampfireBuff and CheckManualRestProximity. :contentReference[oaicite:2]{index=2} :contentReference[oaicite:3]{index=3}

local CC = CozyCamps
local frame = CreateFrame("Frame", "CozyCampsDetectionFrame", UIParent)

local CHECK_INTERVAL = 0.5
local MOVEMENT_CHECK_INTERVAL = 0.1
local accumulator = 0
local movementAccumulator = 0

-- Movement detection threshold (map units)
local MOVEMENT_THRESHOLD = 0.0001

-- ============================================
-- WARMTH OVERLAY SYSTEM (shows when near campfire)
-- ============================================
local warmthOverlay = nil
local warmthCurrentAlpha = 0
local warmthTargetAlpha = 0
local warmthPulsePhase = 0
local WARMTH_LERP_SPEED = 2.0
local WARMTH_PULSE_SPEED = 0.6
local WARMTH_MAX_ALPHA = 1.0

local function Debug(msg, category)
	if CC and CC.Debug then
		CC.Debug(msg, category or "general")
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

-- Create warmth overlay frame (orange-tinted version of full-health-overlay)
local function CreateWarmthOverlay()
	if warmthOverlay then
		return warmthOverlay
	end

	warmthOverlay = CreateFrame("Frame", "CozyCampsWarmthOverlay", UIParent)
	warmthOverlay:SetAllPoints(UIParent)
	warmthOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
	warmthOverlay:SetFrameLevel(50)

	warmthOverlay.texture = warmthOverlay:CreateTexture(nil, "ARTWORK")
	warmthOverlay.texture:SetAllPoints()
	warmthOverlay.texture:SetTexture("Interface\\AddOns\\CozyCamps\\assets\\full-health-overlay.png")
	warmthOverlay.texture:SetBlendMode("ADD")
	warmthOverlay.texture:SetDesaturated(true)
	warmthOverlay.texture:SetVertexColor(1.0, 0.5, 0.1, 1.0)

	warmthOverlay:SetAlpha(0)
	warmthOverlay:EnableMouse(false)

	Debug("Warmth overlay frame created", "general")
	return warmthOverlay
end

local function ShouldShowWarmthOverlay()
	if not (CC and CC.GetSetting and GetSetting("enabled", true)) then
		return false
	end
	if not (CC and CC.IsPlayerEligible and CC.IsPlayerEligible()) then
		return false
	end
	if UnitIsDead("player") or UnitIsGhost("player") then
		return false
	end
	if CC.inCombat then
		return false
	end
	if IsMounted() then
		return false
	end
	return CC.isNearFireRaw == true
end

local function UpdateWarmthOverlay(elapsed)
	if not warmthOverlay then
		CreateWarmthOverlay()
	end

	local shouldShow = ShouldShowWarmthOverlay()
	local prevTarget = warmthTargetAlpha
	warmthTargetAlpha = shouldShow and WARMTH_MAX_ALPHA or 0

	if prevTarget ~= warmthTargetAlpha then
		if warmthTargetAlpha > 0 then
			Debug("Warmth overlay activating (near fire)", "general")
		else
			Debug("Warmth overlay deactivating", "general")
		end
	end

	local diff = warmthTargetAlpha - warmthCurrentAlpha
	if math.abs(diff) < 0.001 then
		warmthCurrentAlpha = warmthTargetAlpha
	else
		warmthCurrentAlpha = warmthCurrentAlpha + (diff * WARMTH_LERP_SPEED * elapsed)
	end

	warmthCurrentAlpha = math.max(0, math.min(1, warmthCurrentAlpha))

	local finalAlpha = warmthCurrentAlpha
	if warmthCurrentAlpha > 0.01 then
		warmthPulsePhase = warmthPulsePhase + elapsed * WARMTH_PULSE_SPEED
		if warmthPulsePhase > 1 then
			warmthPulsePhase = warmthPulsePhase - 1
		end
		local pulseMod = 0.9 + 0.1 * math.sin(warmthPulsePhase * math.pi * 2)
		finalAlpha = warmthCurrentAlpha * pulseMod
	end

	warmthOverlay:SetAlpha(finalAlpha)

	if finalAlpha > 0.001 then
		if not warmthOverlay:IsShown() then
			warmthOverlay:Show()
		end
	else
		if warmthOverlay:IsShown() then
			warmthOverlay:Hide()
		end
	end
end

local function YardsToMapUnits(yards)
	return yards * 0.001
end

local function GetNormalizedCoord(value)
	return value > 1.0 and value / 100 or value
end

local function GetPlayerPosition()
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then
		return nil, nil, nil
	end
	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then
		return nil, nil, nil
	end
	return pos.x, pos.y, GetZoneText()
end

local function HasPlayerMoved()
	local x, y = GetPlayerPosition()
	if not x or not y then
		return false
	end

	if CC.lastPlayerX and CC.lastPlayerY then
		local dx = math.abs(x - CC.lastPlayerX)
		local dy = math.abs(y - CC.lastPlayerY)
		local moved = (dx > MOVEMENT_THRESHOLD or dy > MOVEMENT_THRESHOLD)

		CC.lastPlayerX = x
		CC.lastPlayerY = y
		return moved
	end

	CC.lastPlayerX = x
	CC.lastPlayerY = y
	return false
end

-- Midnight-safe outdoors/indoors check:
local function CanPlayerMount()
	if type(IsOutdoors) == "function" then
		if not IsOutdoors() then
			return false
		end
	elseif type(IsIndoors) == "function" then
		if IsIndoors() then
			return false
		end
	end

	if IsSwimming() then
		return false
	end
	return true
end

local function CheckStaticFireProximity()
	if GetSetting("fireDetectionMode", 1) == 2 then
		return false, GetZoneText()
	end

	local playerX, playerY, zone = GetPlayerPosition()
	if not playerX or not zone then
		return false, nil
	end

	local rangeYards = GetSetting("campfireRange", 3) or 3
	local range = YardsToMapUnits(rangeYards)

	local closestDist = 999
	local closestIdx = 0
	local closestSource = ""

	-- Check main database
	local zoneFires = CozyCampsFireDB and CozyCampsFireDB[zone]
	if zoneFires then
		for i, fire in ipairs(zoneFires) do
			local fx = GetNormalizedCoord(fire.x)
			local fy = GetNormalizedCoord(fire.y)
			local dx = fx - playerX
			local dy = fy - playerY
			local dist = math.sqrt(dx * dx + dy * dy)

			if dist < closestDist then
				closestDist = dist
				closestIdx = i
				closestSource = "main"
			end

			if dist < range then
				if fire.noMount and CanPlayerMount() then
					if GetSetting("proximityDebugEnabled", false) then
						Debug(string.format("Skipping noMount fire %d (player can mount)", i), "proximity")
					end
				else
					if GetSetting("proximityDebugEnabled", false) then
						Debug(string.format("FOUND fire %d at %.1f yds (main DB)", i, dist / 0.001), "proximity")
					end
					return true, zone
				end
			end
		end
	end

	-- Check logged fires database (from /logfire command)
	local loggedFires = CozyCampsLoggedFires and CozyCampsLoggedFires[zone]
	if loggedFires then
		for i, fire in ipairs(loggedFires) do
			local fx = GetNormalizedCoord(fire.x)
			local fy = GetNormalizedCoord(fire.y)
			local dx = fx - playerX
			local dy = fy - playerY
			local dist = math.sqrt(dx * dx + dy * dy)

			if dist < closestDist then
				closestDist = dist
				closestIdx = i
				closestSource = "logged"
			end

			if dist < range then
				if fire.noMount and CanPlayerMount() then
					if GetSetting("proximityDebugEnabled", false) then
						Debug(string.format("Skipping noMount logged fire %d (player can mount)", i), "proximity")
					end
				else
					if GetSetting("proximityDebugEnabled", false) then
						Debug(string.format("FOUND logged fire %d at %.1f yds", i, dist / 0.001), "proximity")
					end
					return true, zone
				end
			end
		end
	end

	if not zoneFires and not loggedFires then
		Debug("No fires in zone: " .. zone, "proximity")
	elseif GetSetting("proximityDebugEnabled", false) and closestIdx > 0 then
		local closestYards = closestDist / 0.001
		Debug(string.format("Closest fire #%d (%s) is %.1f yds away (need < %d)",
			closestIdx, closestSource, closestYards, rangeYards), "proximity")
	end

	return false, zone
end

------------------------------------------------------------
-- Retail-safe campfire buff detection (replaces UnitBuff loops)
------------------------------------------------------------
local CAMPFIRE_SPELL_ID = 7353
local CAMPFIRE_NAME = "Cozy Fire"

-- Cooking profession skill line ID
local COOKING_SKILL_LINE_ID = 185

------------------------------------------------------------
-- Profession Spell Focus Detection (NEW - database-free!)
-- Uses C_TradeSkillUI.IsNearProfessionSpellFocus to detect
-- if the player is near ANY valid cooking fire, including:
-- - Player-placed campfires
-- - City braziers and stoves
-- - Tavern cooking fires
-- - NPC cooking stations
------------------------------------------------------------

-- Cache the cooking profession info to avoid repeated lookups
local cachedCookingProfession = nil

local function GetCookingProfessionInfo()
-- Return cached if available
	if cachedCookingProfession then
		return cachedCookingProfession
	end

	-- Try to get profession info by skill line ID
	if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
		local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(COOKING_SKILL_LINE_ID)
		if info then
			cachedCookingProfession = info
			return info
		end
	end

	-- Try to get it from the player's professions
	if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines then
		local skillLines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
		if skillLines then
			for _, skillLineID in ipairs(skillLines) do
				local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
				if info and info.professionID == COOKING_SKILL_LINE_ID then
					cachedCookingProfession = info
					return info
				end
			end
		end
	end

	return nil
end

local function IsNearCookingFire()
	local debugEnabled = GetSetting("proximityDebugEnabled", false)

	-- Method 1: Try IsNearProfessionSpellFocus (doesn't work for cooking fires)
	if C_TradeSkillUI and C_TradeSkillUI.IsNearProfessionSpellFocus then
		local cookingEnum = (Enum and Enum.Profession and Enum.Profession.Cooking) or 5
		local success, isNear = pcall(C_TradeSkillUI.IsNearProfessionSpellFocus, cookingEnum)
		if success and isNear then
			if debugEnabled then
				Debug("Near fire via IsNearProfessionSpellFocus", "proximity")
			end
			return true
		end
	end

	-- Method 2: Check if we can craft a cooking recipe (requires profession window open)
	-- DISABLED: "craftable" doesn't mean "near fire", it means "can craft" (skill/ingredients)
	-- This was giving false positives
	--[[
	if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
		local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs()
		if recipeIDs and #recipeIDs > 0 then
			for i = 1, math.min(5, #recipeIDs) do
				local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeIDs[i])
				if recipeInfo and recipeInfo.craftable then
					if debugEnabled then
						Debug("Near fire - recipe is craftable (window open)", "proximity")
					end
					return true
				end
			end
		end
	end
	]]--

	return false
end

local function HasCampfireAura()
	local debugEnabled = GetSetting("proximityDebugEnabled", false)

	-- Prefer AuraUtil.FindAuraByName (fast path)
	if AuraUtil and AuraUtil.FindAuraByName then
		local aura = AuraUtil.FindAuraByName(CAMPFIRE_NAME, "player", "HELPFUL")
		if aura then
			if debugEnabled then
				Debug("Found Cozy Fire aura via FindAuraByName", "proximity")
			end
			return true
		end
	end

	-- Try C_UnitAuras.GetPlayerAuraBySpellID (Retail modern API)
	if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_SPELL_ID)
		if aura then
			if debugEnabled then
				Debug("Found Cozy Fire aura via GetPlayerAuraBySpellID", "proximity")
			end
			return true
		end
	end

	-- Enumerate auras (Retail)
	if AuraUtil and AuraUtil.ForEachAura then
		local found = false
		AuraUtil.ForEachAura("player", "HELPFUL", nil, function(aura)
			if not aura then
				return
			end
			if aura.spellId == CAMPFIRE_SPELL_ID or aura.name == CAMPFIRE_NAME then
				found = true
				return true -- stop iter
			end
		end)
		if found then
			if debugEnabled then
				Debug("Found Cozy Fire aura via ForEachAura", "proximity")
			end
			return true
		end
	end

	if debugEnabled then
		Debug("No Cozy Fire aura found (spell ID 7353)", "proximity")
	end

	-- If neither AuraUtil function exists, just fail safe (no buff)
	return false
end

local function HasBasicCampfireBuff()
	if not GetSetting("detectPlayerCampfires", false) then
		return false
	end
	if GetSetting("fireDetectionMode", 1) == 2 then
		return false
	end

	if HasCampfireAura() then
		Debug("Player campfire buff found", "proximity")
		return true
	end
	return false
end

local function CheckManualRestProximity()
-- Check profession spell focus first (most reliable)
	if GetSetting("detectPlayerCampfires", false) and IsNearCookingFire() then
		return true
	end

	local playerX, playerY, zone = GetPlayerPosition()
	if not playerX or not zone then
		return false
	end

	local rangeYards = GetSetting("campfireRange", 3) or 3
	local range = YardsToMapUnits(rangeYards)
	local zoneFires = CozyCampsFireDB and CozyCampsFireDB[zone]

	if zoneFires then
		for _, fire in ipairs(zoneFires) do
			local fx = GetNormalizedCoord(fire.x)
			local fy = GetNormalizedCoord(fire.y)
			local dx = fx - playerX
			local dy = fy - playerY
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist < range then
				if not (fire.noMount and CanPlayerMount()) then
					return true
				end
			end
		end
	end

	if GetSetting("detectPlayerCampfires", false) then
		if HasCampfireAura() then
			return true
		end
	end

	return false
end

local function SafeDeactivateManualRest()
	if CC and CC.DeactivateManualRest then
		CC.DeactivateManualRest()
	else
		if CC then
			CC.isManualRestActive = false
		end
	end
end

local function UpdateFireProximity()
	local mode = GetSetting("fireDetectionMode", 1)
	local foundAny = false

	if mode == 1 then
	-- Priority 1: Profession spell focus (database-free, detects ALL cooking fires)
		local foundProfession = GetSetting("detectPlayerCampfires", false) and IsNearCookingFire()

		-- Priority 2: Cozy Fire aura (player-placed campfires)
		local foundPlayer = HasBasicCampfireBuff()

		-- Priority 3: Static database (fallback for edge cases)
		local foundStatic = CheckStaticFireProximity()

		foundAny = foundProfession or foundPlayer or foundStatic

		if GetSetting("proximityDebugEnabled", false) then
			Debug(string.format("Fire detection: profession=%s, aura=%s, static=%s",
				tostring(foundProfession), tostring(foundPlayer), tostring(foundStatic)), "proximity")
		end
	else
		if CC.isManualRestActive then
			foundAny = CheckManualRestProximity()
			if not foundAny then
				SafeDeactivateManualRest()
				print("|cff88CCFFCozyCamps:|r No campfire nearby. Rest cancelled.")
			end
		end
	end

	local proximityChanged = (CC.isNearFireRaw ~= foundAny)
	CC.isNearFireRaw = foundAny

	local isMounted = IsMounted()
	local newIsNearFire = foundAny and not CC.inCombat and not isMounted
	local safeChanged = (CC.isNearFire ~= newIsNearFire)

	if safeChanged
	and newIsNearFire
	and GetSetting("playSoundNearFire", true)
	and GetSetting("temperatureEnabled", false)
	and (CC.IsPlayerEligible and CC.IsPlayerEligible())
	then
		PlaySoundFile("Interface\\AddOns\\CozyCamps\\assets\\firesound.wav", "SFX")
	end

	if safeChanged then
		CC.isNearFire = newIsNearFire

		if GetSetting("debugEnabled", false) then
			local fire = foundAny and "|cff00FF00FIRE|r" or "|cffFF0000NO FIRE|r"
			local combat = CC.inCombat and "|cffFF0000[COMBAT]|r " or ""
			local result = CC.isNearFire and "|cff00FF00SAFE|r" or "|cffFF0000LOCKED|r"
			print(string.format("|cff88CCFFCozyCamps:|r %s%s -> %s", combat, fire, result))
		end

		if CC and CC.FireCallbacks then
			CC.FireCallbacks("FIRE_STATE_CHANGED", CC.isNearFire, CC.inCombat)
		end
	end

	return safeChanged or proximityChanged
end

local function OnCombatStart()
	CC.inCombat = true
	local was = CC.isNearFire
	CC.isNearFire = false

	if CC.isManualRestActive then
		SafeDeactivateManualRest()
	end

	Debug("|cffFF0000Combat Started|r", "general")
	if was and CC.FireCallbacks then
		CC.FireCallbacks("FIRE_STATE_CHANGED", CC.isNearFire, CC.inCombat)
	end
end

local function OnCombatEnd()
	CC.inCombat = false
	Debug("|cff00FF00Combat Ended|r", "general")
	UpdateFireProximity()
end

-- Grace period after activating rest to prevent false movement detection
local restGracePeriod = 0

local function CheckMovementForManualRest()
	if not CC.isManualRestActive then
		return
	end
	if GetSetting("fireDetectionMode", 1) ~= 2 then
		return
	end

	if restGracePeriod > 0 then
		restGracePeriod = restGracePeriod - MOVEMENT_CHECK_INTERVAL
		local x, y = GetPlayerPosition()
		CC.lastPlayerX = x
		CC.lastPlayerY = y
		return
	end

	if HasPlayerMoved() then
		SafeDeactivateManualRest()
		print("|cff88CCFFCozyCamps:|r You moved. Rest ended.")
		UpdateFireProximity()
		if CC.RefreshActionBars then
			CC.RefreshActionBars()
		end
	end
end

-- Manual rest callback
if CC and CC.RegisterCallback then
	CC.RegisterCallback("MANUAL_REST_CHANGED", function(isActive)
		if isActive then
			restGracePeriod = 1.0
			local x, y = GetPlayerPosition()
			CC.lastPlayerX = x
			CC.lastPlayerY = y
		end
	end)
end

frame:SetScript("OnUpdate", function(self, elapsed)
	if CC.HandleExhaustionDecay then
		CC.HandleExhaustionDecay(elapsed)
	end
	if CC.HandleAnguishUpdate then
		CC.HandleAnguishUpdate(elapsed)
	end
	if CC.HandleHungerDarknessUpdate then
		CC.HandleHungerDarknessUpdate(elapsed)
	end
	if CC.HandleHPTunnelVisionUpdate then
		CC.HandleHPTunnelVisionUpdate(elapsed)
	end

	if CC.HandleThirstDarknessUpdate then
		CC.HandleThirstDarknessUpdate(elapsed)
	end

	UpdateWarmthOverlay(elapsed)

	if not self.hungerAccumulator then
		self.hungerAccumulator = 0
	end
	self.hungerAccumulator = self.hungerAccumulator + elapsed
	if self.hungerAccumulator >= 2.5 then
		self.hungerAccumulator = self.hungerAccumulator - 2.5
		if CC.HandleHungerUpdate then
			CC.HandleHungerUpdate(2.5)
		end

		if CC.HandleThirstUpdate then
			CC.HandleThirstUpdate(2.5)
		end
	end

	if CC.HandleTemperatureUpdate then
		CC.HandleTemperatureUpdate(elapsed)
	end

	movementAccumulator = movementAccumulator + elapsed
	if movementAccumulator >= MOVEMENT_CHECK_INTERVAL then
		movementAccumulator = movementAccumulator - MOVEMENT_CHECK_INTERVAL
		CheckMovementForManualRest()
	end

	accumulator = accumulator + elapsed
	if accumulator >= CHECK_INTERVAL then
		accumulator = accumulator - CHECK_INTERVAL
		UpdateFireProximity()
	end
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UNIT_AURA")

frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_LOGIN" then
		CC.isNearFire = false
		CC.isNearFireRaw = false
		CC.inCombat = InCombatLockdown()

		local x, y = GetPlayerPosition()
		CC.lastPlayerX = x
		CC.lastPlayerY = y

		CreateWarmthOverlay()
		C_Timer.After(1, UpdateFireProximity)

	elseif event == "PLAYER_REGEN_DISABLED" then
		OnCombatStart()

	elseif event == "PLAYER_REGEN_ENABLED" then
		OnCombatEnd()

	elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
		if CC.isManualRestActive then
			SafeDeactivateManualRest()
		end
		UpdateFireProximity()

	elseif event == "UNIT_AURA" and arg1 == "player" and GetSetting("detectPlayerCampfires", false) then
		UpdateFireProximity()
	end
end)

function CC.ForceUpdate()
	return UpdateFireProximity()
end

-- API: Check if profession spell focus detection is available
function CC.IsProfessionFireDetectionAvailable()
	return C_TradeSkillUI and C_TradeSkillUI.IsNearProfessionSpellFocus ~= nil
end

-- API: Direct check if near cooking fire (for external use)
function CC.IsNearCookingFire()
	return IsNearCookingFire()
end

-- Debug command to test fire detection
-- Usage: /ccfire
SLASH_COZYCAMPSFIRE1 = "/ccfire"
SlashCmdList["COZYCAMPSFIRE"] = function()
	print("|cff88CCFFCozyCamps Fire Detection Debug:|r")
	print("----------------------------------------")

	-- Check API availability
	local hasTradeSkillUI = C_TradeSkillUI ~= nil
	local hasSpellFocusAPI = hasTradeSkillUI and C_TradeSkillUI.IsNearProfessionSpellFocus ~= nil
	print(string.format("C_TradeSkillUI available: %s", hasTradeSkillUI and "|cff00FF00YES|r" or "|cffFF0000NO|r"))
	print(string.format("IsNearProfessionSpellFocus API: %s", hasSpellFocusAPI and "|cff00FF00YES|r" or "|cffFF0000NO|r"))

	-- Test profession spell focus
	if hasSpellFocusAPI then
	-- First, try to get the profession info
		local profInfo = GetCookingProfessionInfo()
		if profInfo then
			print("|cff00FF00Got cooking profession info:|r")
			print(string.format("  professionID: %s", tostring(profInfo.professionID)))
			print(string.format("  professionName: %s", tostring(profInfo.professionName)))
			print(string.format("  skillLineID: %s", tostring(profInfo.skillLineID)))

			-- Try with profession info object
			local success, result = pcall(C_TradeSkillUI.IsNearProfessionSpellFocus, profInfo)
			if success then
				print(string.format("With profInfo: %s",
					result and "|cff00FF00NEAR FIRE!|r" or "|cffFF0000not near fire|r"))
			else
				print(string.format("|cffFF0000profInfo Error:|r %s", tostring(result):sub(1,60)))
			end
		else
			print("|cffFF0000Could not get cooking profession info|r")
		end

		-- Try with profession enum (5 for cooking based on profInfo.profession)
		local profEnum = profInfo and profInfo.profession or 5
		local success2, result2 = pcall(C_TradeSkillUI.IsNearProfessionSpellFocus, profEnum)
		if success2 then
			print(string.format("With profession enum (%d): %s", profEnum,
				result2 and "|cff00FF00NEAR FIRE!|r" or "|cffFF0000not near fire|r"))
		else
			print(string.format("|cffFF0000Enum %d Error:|r %s", profEnum, tostring(result2):sub(1,50)))
		end

		-- Try with Enum.Profession if it exists
		if Enum and Enum.Profession and Enum.Profession.Cooking then
			local success3, result3 = pcall(C_TradeSkillUI.IsNearProfessionSpellFocus, Enum.Profession.Cooking)
			if success3 then
				print(string.format("With Enum.Profession.Cooking: %s",
					result3 and "|cff00FF00NEAR FIRE!|r" or "|cffFF0000not near fire|r"))
			else
				print(string.format("|cffFF0000Enum.Profession.Cooking Error:|r %s", tostring(result3):sub(1,50)))
			end
		end

		-- Test recipe-based detection
		print("|cffFFFF00Testing recipe-based detection:|r")
		local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs()
		if recipeIDs then
			print(string.format("  GetAllRecipeIDs returned %d recipes", #recipeIDs))
			if #recipeIDs > 0 then
				local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeIDs[1])
				if recipeInfo then
					print(string.format("  Recipe: %s", recipeInfo.name or "?"))
					-- Print ALL fields to see what we have
					for k, v in pairs(recipeInfo) do
						if type(v) ~= "table" then
							print(string.format("    %s = %s", tostring(k), tostring(v)))
						else
							print(string.format("    %s = (table)", tostring(k)))
						end
					end
				end

				-- Check recipe requirements/schematic
				if C_TradeSkillUI.GetRecipeSchematic then
					local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeIDs[1], false)
					if schematic then
						print("  |cffFFFF00Recipe Schematic:|r")
						for k, v in pairs(schematic) do
							if type(v) ~= "table" then
								print(string.format("    %s = %s", tostring(k), tostring(v)))
							end
						end
					end
				end
			end
		else
			print("  GetAllRecipeIDs returned nil (profession window not open?)")
		end

		-- Test ALL professions to see which ones return true
		print("|cffFFFF00Testing IsNearProfessionSpellFocus for ALL professions:|r")
		if Enum and Enum.Profession then
			for name, enumVal in pairs(Enum.Profession) do
				local success, result = pcall(C_TradeSkillUI.IsNearProfessionSpellFocus, enumVal)
				if success and result then
					print(string.format("  |cff00FF00%s (%d): NEAR SPELL FOCUS!|r", name, enumVal))
				elseif success then
				-- Only print first few "not near" to reduce spam
				elseif not success then
					print(string.format("  |cffFF0000%s (%d): ERROR|r", name, enumVal))
				end
			end
			print("  (Only showing professions where we ARE near a spell focus)")
		end

		-- Check if there's a tooltip we can scan
		print("|cffFFFF00Checking mouseover/target:|r")
		if GameTooltip then
			local ttName = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
			print(string.format("  Tooltip line 1: %s", tostring(ttName)))
		end

		-- Check what's under cursor using C_TooltipInfo
		if C_TooltipInfo and C_TooltipInfo.GetUnit then
			local tooltipData = C_TooltipInfo.GetUnit("mouseover")
			if tooltipData then
				print(string.format("  Mouseover unit: %s", tostring(tooltipData.guid)))
			end
		end

		-- Try to get cursor info
		local cursorType, objectID, subType = GetCursorInfo()
		if cursorType then
			print(string.format("  Cursor: type=%s, id=%s", tostring(cursorType), tostring(objectID)))
		end

		-- Try getting info differently
		if C_TradeSkillUI.GetProfessionInfoBySkillLineID then
			local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(COOKING_SKILL_LINE_ID)
			if info then
				print("|cffFFFF00Direct GetProfessionInfoBySkillLineID(185):|r")
				for k, v in pairs(info) do
					print(string.format("  %s = %s", tostring(k), tostring(v)))
				end
			else
				print("|cffFF8800GetProfessionInfoBySkillLineID(185) returned nil|r")
			end
		end
	end

	-- Test Cozy Fire aura
	local hasCozyFire = false
	if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_SPELL_ID)
		hasCozyFire = aura ~= nil
	end
	print(string.format("Cozy Fire aura (7353): %s", hasCozyFire and "|cff00FF00ACTIVE|r" or "|cffFF0000not found|r"))

	-- Test static database
	local playerX, playerY, zone = GetPlayerPosition()
	if zone then
		local zoneFires = CozyCampsFireDB and CozyCampsFireDB[zone]
		local fireCount = zoneFires and #zoneFires or 0
		local loggedFires = CozyCampsLoggedFires and CozyCampsLoggedFires[zone]
		local loggedCount = loggedFires and #loggedFires or 0
		print(string.format("Zone: %s | Main DB: %d | Logged: %d", zone, fireCount, loggedCount))
		print(string.format("Position: %.4f, %.4f", playerX, playerY))
	else
		print("Could not get player position")
	end

	-- Current state
	print("----------------------------------------")
	print(string.format("CC.isNearFire: %s", CC.isNearFire and "|cff00FF00true|r" or "|cffFF0000false|r"))
	print(string.format("CC.isNearFireRaw: %s", CC.isNearFireRaw and "|cff00FF00true|r" or "|cffFF0000false|r"))
	print(string.format("Fire Detection Mode: %d", GetSetting("fireDetectionMode", 1)))
	print(string.format("Detect Player Campfires: %s", GetSetting("detectPlayerCampfires", false) and "YES" or "NO"))
end
