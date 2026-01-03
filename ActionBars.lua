-- CozierCamps - ActionBars.lua
-- Standalone action bar hiding system with smooth transitions
local CC = CozierCamps

-- Action bars with numbered buttons (Classic Era)
local ACTION_BAR_FRAMES = { "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",

							"BonusActionBarFrame", "ShapeshiftBarFrame" }

-- Additional UI frames to hide (no numbered buttons)
local EXTRA_UI_FRAMES = { "StanceBarFrame", "PetActionBar", "PetActionBarFrame",
	-- Action bar page arrows (Classic Era names)
						  "ActionBarUpButton", "ActionBarDownButton", "MainMenuBarPageNumber",
	-- Action bar page switching arrows and art
						  "MainMenuBarArtFrame", "MainMenuBarArtFrameBackground", "ActionBarPageUpButton",
						  "ActionBarPageDownButton", -- Bag buttons
						  "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
						  "BagBarExpandToggle", -- Micro menu buttons
						  "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton", "SocialsMicroButton",
						  "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton", "AchievementMicroButton",
						  "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton", "StoreMicroButton",
	-- Classic UI elements
						  "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "MainMenuBarTexture0",
						  "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3", "MainMenuExpBar",
						  "ReputationWatchBar", "MainMenuBarMaxLevelBar",
						  "MicroButtonAndBagsBar", "BagsBar", "MicroMenu", "MainMenuBarVehicleLeaveButton",
						  "MainStatusTrackingBarContainer", "StatusTrackingBarManager" }

-- Minimap frames (hidden separately, controlled by hideMinimapWithBars setting)
-- Constitution override will still hide these regardless of the setting
local MINIMAP_FRAMES = { "MinimapCluster", "Minimap", "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn",
						 "MinimapZoomOut", "MinimapBackdrop", "GameTimeFrame", "MiniMapTracking",
						 "MiniMapMailFrame", "MiniMapBattlefieldFrame", "MiniMapWorldMapButton" }

local barsHidden = false
local introShown = false

-- Constitution-based hiding override (takes priority over other modes)
local constitutionOverrideActive = false

-- Animation state
local currentAlpha = 1
local targetAlpha = 1
local FADE_SPEED = 4 -- Alpha change per second (0.25 seconds for full fade)
local isAnimating = false

-- Minimap-only animation state (for settings toggle fade)
local minimapCurrentAlpha = 1
local minimapTargetAlpha = 1
local isMinimapAnimating = false

-- Track which frames were visible before hiding (to restore only those)
local frameVisibilityState = {}

local animFrame = CreateFrame("Frame")

-- Check if an action bar should be shown when restoring visibility
-- Uses recorded visibility state first (most reliable), falls back to settings checks
local function IsBarEnabledInSettings(frameName)
	-- If we recorded this bar's visibility state, use that
	-- This is the most reliable way to restore bars after hiding
	if frameVisibilityState[frameName] == true then
		return true
	end

	-- MainMenuBar is always enabled
	if frameName == "MainMenuBar" then
		return true
	end

	-- Check multi-bar CVars (Classic Era) - used for initial state detection
	if frameName == "MultiBarBottomLeft" then
		return GetCVar("SHOW_MULTI_ACTIONBAR_1") == "1"
	elseif frameName == "MultiBarBottomRight" then
		return GetCVar("SHOW_MULTI_ACTIONBAR_2") == "1"
	elseif frameName == "MultiBarRight" then
		return GetCVar("SHOW_MULTI_ACTIONBAR_3") == "1"
	elseif frameName == "MultiBarLeft" then
		return GetCVar("SHOW_MULTI_ACTIONBAR_4") == "1"
	end

	-- Pet bar - check if player has a pet AND bar is shown (initial state only)
	if frameName == "PetActionBarFrame" or frameName == "PetActionBar" then
		local petFrame = _G["PetActionBarFrame"]
		return petFrame and petFrame:IsShown()
	end

	-- Stance/Shapeshift bar - check if player has stances
	if frameName == "StanceBarFrame" or frameName == "ShapeshiftBarFrame" then
		local numForms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
		return numForms > 0
	end

	-- BonusActionBarFrame (for things like warrior stance bars)
	if frameName == "BonusActionBarFrame" then
		local frame = _G[frameName]
		return frame and frame:IsShown()
	end

	-- Default: assume it's enabled
	return true
end

local function SetBarsAlpha(alpha)
	-- Handle action bars with numbered buttons
	for _, frameName in ipairs(ACTION_BAR_FRAMES) do
		local frame = _G[frameName]
		if frame then
			if alpha > 0 then
				-- SHOWING: Only restore bars that are enabled in WoW settings AND were visible before
				if IsBarEnabledInSettings(frameName) and frameVisibilityState[frameName] ~= false then
					-- Skip Show() during combat to avoid protected function errors
					if not frame:IsShown() and not InCombatLockdown() then
						frame:Show()
					end
					frame:SetAlpha(alpha)
					-- Restore button visibility
					for i = 1, 12 do
						local buttonName = frameName == "MainMenuBar" and ("ActionButton" .. i) or
								(frameName .. "Button" .. i)
						local button = _G[buttonName]
						if button then
							button:SetAlpha(1)
							if button.cooldown then
								button.cooldown:SetAlpha(1)
							end
						end
					end
				end
			else
				-- HIDING: Hide all visible bars regardless of settings
				-- Record visibility state before hiding
				if frameVisibilityState[frameName] == nil then
					frameVisibilityState[frameName] = frame:IsShown()
				end
				-- When fully hidden, also hide to prevent interaction and flashes
				-- Skip Hide() during combat to avoid protected function errors
				frame:SetAlpha(0)
				if not InCombatLockdown() then
					frame:Hide()
				end
				-- Hide all action button cooldown/GCD flash overlays
				for i = 1, 12 do
					local buttonName = frameName == "MainMenuBar" and ("ActionButton" .. i) or
							(frameName .. "Button" .. i)
					local button = _G[buttonName]
					if button then
						button:SetAlpha(0)
						if button.cooldown then
							button.cooldown:SetAlpha(0)
						end
						if button.Flash then
							button.Flash:Hide()
						end
						-- Hide the GCD flash specifically
						local flash = _G[buttonName .. "Flash"]
						if flash then
							flash:Hide()
						end
					end
				end
			end
		end
	end

	-- Handle extra UI frames (no numbered buttons)
	for _, frameName in ipairs(EXTRA_UI_FRAMES) do
		local frame = _G[frameName]
		if frame then
			if alpha > 0 then
				-- SHOWING: Only restore frames that are enabled AND were visible before
				if IsBarEnabledInSettings(frameName) and frameVisibilityState[frameName] == true then
					-- Skip Show() during combat to avoid protected function errors
					if not frame:IsShown() and not InCombatLockdown() then
						frame:Show()
					end
					frame:SetAlpha(alpha)
				end
			else
				-- HIDING: Hide all visible frames regardless of settings
				-- Record visibility state before hiding
				if frameVisibilityState[frameName] == nil then
					frameVisibilityState[frameName] = frame:IsShown()
				end
				-- Skip Hide() during combat to avoid protected function errors
				frame:SetAlpha(0)
				if not InCombatLockdown() then
					frame:Hide()
				end
			end
		end
	end

	-- Handle minimap frames (conditional based on hideMinimapWithBars setting)
	-- Constitution override always hides minimap regardless of setting
	local shouldHideMinimap = constitutionOverrideActive or CC.GetSetting("hideMinimapWithBars")
	if shouldHideMinimap then
		for _, frameName in ipairs(MINIMAP_FRAMES) do
			local frame = _G[frameName]
			if frame then
				if alpha > 0 then
					-- Only show if it was visible before we hid it
					if frameVisibilityState[frameName] == true then
						if not frame:IsShown() then
							frame:Show()
						end
						frame:SetAlpha(alpha)
					end
				else
					-- Record visibility state before hiding
					if frameVisibilityState[frameName] == nil then
						frameVisibilityState[frameName] = frame:IsShown()
					end
					frame:SetAlpha(0)
					frame:Hide()
				end
			end
		end
	elseif alpha > 0 then
		-- Minimap hiding disabled and showing bars - restore minimap if it was hidden
		for _, frameName in ipairs(MINIMAP_FRAMES) do
			local frame = _G[frameName]
			if frame and frameVisibilityState[frameName] == true then
				if not frame:IsShown() then
					frame:Show()
				end
				frame:SetAlpha(1)
			end
		end
	end

	-- Special handling for PetActionBarFrame (Classic compatibility)
	-- Classic's PetActionBarFrame OnUpdate expects slideTimer and timeToSlide to exist
	local petFrame = _G["PetActionBarFrame"]
	if petFrame then
		-- Initialize slide-related fields if they don't exist (Classic client fix)
		if petFrame.slideTimer == nil then
			petFrame.slideTimer = 0
		end
		if petFrame.timeToSlide == nil then
			petFrame.timeToSlide = 0
		end
		if alpha > 0 then
			-- Only show if it was visible before
			if frameVisibilityState["PetActionBarFrame"] == true then
				if not petFrame:IsShown() then
					petFrame:Show()
				end
				petFrame:SetAlpha(alpha)
			end
		else
			-- Record visibility state before hiding
			if frameVisibilityState["PetActionBarFrame"] == nil then
				frameVisibilityState["PetActionBarFrame"] = petFrame:IsShown()
			end
			petFrame:SetAlpha(0)
			-- Don't call Hide() on PetActionBarFrame in Classic - just use alpha
			-- The frame's OnUpdate handler may still run and expects slide fields
		end
	end

	-- Special handling for action bar page switcher
	-- These may be nested children or use different naming conventions
	local mainMenuBar = _G["MainMenuBar"]
	if mainMenuBar then
		-- Try to find page number as a child
		local pageNumber = mainMenuBar.ActionBarPageNumber or mainMenuBar.PageNumber
		if pageNumber then
			local pageKey = "MainMenuBar.PageNumber"
			if alpha > 0 then
				if frameVisibilityState[pageKey] == true then
					if not pageNumber:IsShown() then
						pageNumber:Show()
					end
					pageNumber:SetAlpha(alpha)
				end
			else
				if frameVisibilityState[pageKey] == nil then
					frameVisibilityState[pageKey] = pageNumber:IsShown()
				end
				pageNumber:SetAlpha(0)
				pageNumber:Hide()
			end
		end

		-- Try to hide all children that look like page buttons
		for _, child in pairs({ mainMenuBar:GetChildren() }) do
			local name = child:GetName()
			if name and (name:find("Page") or name:find("Arrow") or name:find("UpButton") or name:find("DownButton")) then
				local childKey = name or tostring(child)
				if alpha > 0 then
					if frameVisibilityState[childKey] == true then
						if not child:IsShown() then
							child:Show()
						end
						child:SetAlpha(alpha)
					end
				else
					if frameVisibilityState[childKey] == nil then
						frameVisibilityState[childKey] = child:IsShown()
					end
					child:SetAlpha(0)
					child:Hide()
				end
			end
		end
	end

	-- Also check MainMenuBarArtFrame for page controls
	local artFrame = _G["MainMenuBarArtFrame"]
	if artFrame then
		for _, child in pairs({ artFrame:GetChildren() }) do
			local name = child:GetName()
			if name and
					(name:find("Page") or name:find("Arrow") or name:find("UpButton") or name:find("DownButton") or
							name:find("Number")) then
				local childKey = name or tostring(child)
				if alpha > 0 then
					if frameVisibilityState[childKey] == true then
						if not child:IsShown() then
							child:Show()
						end
						child:SetAlpha(alpha)
					end
				else
					if frameVisibilityState[childKey] == nil then
						frameVisibilityState[childKey] = child:IsShown()
					end
					child:SetAlpha(0)
					child:Hide()
				end
			end
			-- Also hide unnamed children that might be page controls
			if not name then
				-- Check if it has button-like properties
				if child.GetNormalTexture or child.SetNormalTexture then
					local childKey = tostring(child)
					if alpha > 0 then
						if frameVisibilityState[childKey] == true then
							if not child:IsShown() then
								child:Show()
							end
							child:SetAlpha(alpha)
						end
					else
						if frameVisibilityState[childKey] == nil then
							frameVisibilityState[childKey] = child:IsShown()
						end
						child:SetAlpha(0)
						child:Hide()
					end
				end
			end
		end
		-- Hide the art frame itself if alpha is 0
		if alpha <= 0 then
			if frameVisibilityState["MainMenuBarArtFrame"] == nil then
				frameVisibilityState["MainMenuBarArtFrame"] = artFrame:IsShown()
			end
			artFrame:SetAlpha(0)
			artFrame:Hide()
		elseif frameVisibilityState["MainMenuBarArtFrame"] == true then
			artFrame:SetAlpha(alpha)
			if not artFrame:IsShown() then
				artFrame:Show()
			end
		end
	end

	-- MainActionBar.ActionBarPageNumber (page switcher with arrows)
	local mainActionBar = _G["MainActionBar"]
	if mainActionBar and mainActionBar.ActionBarPageNumber then
		local pageNum = mainActionBar.ActionBarPageNumber
		local pageKey = "MainActionBar.PageNumber"
		if alpha > 0 then
			if frameVisibilityState[pageKey] == true then
				if not pageNum:IsShown() then
					pageNum:Show()
				end
				pageNum:SetAlpha(alpha)
			end
		else
			if frameVisibilityState[pageKey] == nil then
				frameVisibilityState[pageKey] = pageNum:IsShown()
			end
			pageNum:SetAlpha(0)
			pageNum:Hide()
		end
	end
end

local function OnUpdate(self, elapsed)
	if not isAnimating then
		return
	end

	local diff = targetAlpha - currentAlpha
	if math.abs(diff) < 0.01 then
		-- Animation complete
		currentAlpha = targetAlpha
		SetBarsAlpha(currentAlpha)
		isAnimating = false
		animFrame:SetScript("OnUpdate", nil)

		if currentAlpha <= 0 then
			barsHidden = true
			CC.Debug("Action bars hidden (fade complete)", "general")
		else
			barsHidden = false
			-- Clear visibility state so next hide captures fresh state
			wipe(frameVisibilityState)
			CC.Debug("Action bars shown (fade complete)", "general")
		end
	else
		-- Animate
		local change = FADE_SPEED * elapsed
		if diff > 0 then
			currentAlpha = math.min(targetAlpha, currentAlpha + change)
		else
			currentAlpha = math.max(targetAlpha, currentAlpha - change)
		end
		SetBarsAlpha(currentAlpha)
	end
end

local function FadeBarsTo(alpha)
	if InCombatLockdown() then
		return
	end

	targetAlpha = alpha

	-- If already at target, nothing to do
	if math.abs(currentAlpha - targetAlpha) < 0.01 then
		return
	end

	-- If showing from hidden state, show frames with proper ordering for layout
	if alpha > 0 and currentAlpha <= 0 then
		-- First, show MainMenuBar and status tracking bars (these affect layout of other bars)
		local mainMenuBar = _G["MainMenuBar"]
		if mainMenuBar and frameVisibilityState["MainMenuBar"] ~= false then
			mainMenuBar:Show()
			mainMenuBar:SetAlpha(0.01)
		end

		-- Show extra UI frames (includes status bars that affect positioning)
		for _, frameName in ipairs(EXTRA_UI_FRAMES) do
			local frame = _G[frameName]
			if frame and frameVisibilityState[frameName] == true then
				frame:Show()
				frame:SetAlpha(0.01)
			end
		end

		-- Delay showing dependent action bars by one frame to let layout recalculate
		-- This prevents MultiBarBottomLeft from jumping when anchors are recalculated
		C_Timer.After(0, function()
			for _, frameName in ipairs(ACTION_BAR_FRAMES) do
				if frameName ~= "MainMenuBar" and IsBarEnabledInSettings(frameName) then
					local frame = _G[frameName]
					if frame and frameVisibilityState[frameName] ~= false then
						frame:Show()
						frame:SetAlpha(currentAlpha > 0.01 and currentAlpha or 0.01)
					end
				end
			end
		end)
	end

	-- Start animation
	isAnimating = true
	animFrame:SetScript("OnUpdate", OnUpdate)
end

local function HideBars()
	if InCombatLockdown() then
		return
	end
	FadeBarsTo(0)
end

local function ShowBars()
	if InCombatLockdown() then
		return
	end
	FadeBarsTo(1)
end

-- Force show all bars (used when master toggle is disabled)
local function ForceShowAllBars()
	if InCombatLockdown() then
		return
	end
	FadeBarsTo(1)
	barsHidden = false
end

-- Set minimap frames alpha directly
local function SetMinimapAlpha(alpha)
	for _, frameName in ipairs(MINIMAP_FRAMES) do
		local frame = _G[frameName]
		if frame then
			if alpha > 0 then
				if frameVisibilityState[frameName] == true then
					if not frame:IsShown() then
						frame:Show()
					end
					frame:SetAlpha(alpha)
				end
			else
				if frameVisibilityState[frameName] == nil then
					frameVisibilityState[frameName] = frame:IsShown()
				end
				frame:SetAlpha(0)
				frame:Hide()
			end
		end
	end
end

-- Minimap-only animation OnUpdate
local minimapAnimFrame = CreateFrame("Frame")
local function OnMinimapUpdate(self, elapsed)
	if not isMinimapAnimating then
		return
	end

	local diff = minimapTargetAlpha - minimapCurrentAlpha
	if math.abs(diff) < 0.01 then
		minimapCurrentAlpha = minimapTargetAlpha
		SetMinimapAlpha(minimapCurrentAlpha)
		isMinimapAnimating = false
		minimapAnimFrame:SetScript("OnUpdate", nil)
	else
		local change = FADE_SPEED * elapsed
		if diff > 0 then
			minimapCurrentAlpha = math.min(minimapTargetAlpha, minimapCurrentAlpha + change)
		else
			minimapCurrentAlpha = math.max(minimapTargetAlpha, minimapCurrentAlpha - change)
		end
		SetMinimapAlpha(minimapCurrentAlpha)
	end
end

-- Fade minimap to target alpha (used for settings toggle)
local function FadeMinimapTo(alpha)
	if InCombatLockdown() then
		return
	end

	minimapTargetAlpha = alpha

	if math.abs(minimapCurrentAlpha - minimapTargetAlpha) < 0.01 then
		return
	end

	-- If showing from hidden, show frames first
	if alpha > 0 and minimapCurrentAlpha <= 0 then
		for _, frameName in ipairs(MINIMAP_FRAMES) do
			local frame = _G[frameName]
			if frame and frameVisibilityState[frameName] == true then
				frame:Show()
				frame:SetAlpha(0.01)
			end
		end
	end

	isMinimapAnimating = true
	minimapAnimFrame:SetScript("OnUpdate", OnMinimapUpdate)
end

local function UpdateActionBarVisibility()
	-- Constitution override takes absolute priority - hide everything immediately
	if constitutionOverrideActive then
		HideBars()
		return
	end

	local mode = CC.GetSetting("hideActionBarsMode") or 1

	-- Mode 1: Disabled - always show
	if mode == 1 then
		ShowBars()
		return
	end

	if not CC.IsPlayerEligible() then
		ShowBars()
		return
	end

	-- Mode 3: Rested areas only - only show in inns/cities
	if mode == 3 then
		if IsResting() then
			ShowBars()
		else
			HideBars()
		end
		return
	end

	-- Mode 2: Always (not near fire/rested) - original behavior
	if CC.ShouldShowActionBars() then
		ShowBars()
	else
		HideBars()
	end
end

local function ShowIntroPopup()
	if introShown then
		return
	end
	introShown = true

	StaticPopupDialogs["CozierCamps_ACTIONBARS_INTRO"] = {
		text = "Congratulations on reaching level " .. CC.GetMinLevel() ..
				"!\n\nYour action bars will now be hidden when away from campfires. Find a fire or visit an inn to access them. Alternatively, use /cozy to access settings and tailor to your liking.",
		button1 = "I Understand",
		timeout = 0,
		whileDead = true,
		hideOnEscape = true
	}
	StaticPopup_Show("CozierCamps_ACTIONBARS_INTRO")
end

-- Event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_CONTROL_LOST") -- Fires when getting on taxi
frame:RegisterEvent("PLAYER_CONTROL_GAINED") -- Fires when getting off taxi

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		-- Set initial state without animation
		C_Timer.After(1, function()
			local mode = CC.GetSetting("hideActionBarsMode") or 1
			if mode == 1 or not CC.IsPlayerEligible() then
				-- Disabled or not eligible
				currentAlpha = 1
				targetAlpha = 1
				barsHidden = false
				SetBarsAlpha(1)
			elseif mode == 3 then
				-- Rested only
				if IsResting() then
					currentAlpha = 1
					targetAlpha = 1
					barsHidden = false
					SetBarsAlpha(1)
				else
					currentAlpha = 0
					targetAlpha = 0
					barsHidden = true
					SetBarsAlpha(0)
				end
			elseif CC.ShouldShowActionBars() then
				currentAlpha = 1
				targetAlpha = 1
				barsHidden = false
				SetBarsAlpha(1)
			else
				currentAlpha = 0
				targetAlpha = 0
				barsHidden = true
				SetBarsAlpha(0)
			end
		end)

	elseif event == "PLAYER_LEVEL_UP" then
		local newLevel = arg1
		local mode = CC.GetSetting("hideActionBarsMode") or 1
		if mode ~= 1 and newLevel == CC.GetMinLevel() then
			ShowIntroPopup()
		end
		C_Timer.After(0.5, UpdateActionBarVisibility)

	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Entering combat - hide bars immediately (no fade)
		local mode = CC.GetSetting("hideActionBarsMode") or 1
		if mode ~= 1 and CC.IsPlayerEligible() then
			if not InCombatLockdown() then
				targetAlpha = 0
				currentAlpha = 0
				SetBarsAlpha(0)
				barsHidden = true
				isAnimating = false
			end
		end

	elseif event == "PLAYER_REGEN_ENABLED" then
		-- Leaving combat
		C_Timer.After(0.1, UpdateActionBarVisibility)

	elseif event == "PLAYER_UPDATE_RESTING" then
		C_Timer.After(0.1, UpdateActionBarVisibility)

	elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
		C_Timer.After(0.1, UpdateActionBarVisibility)

	elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
		-- Only respond if on taxi (ignore stealth, etc)
		C_Timer.After(0.2, function()
			if UnitOnTaxi("player") or event == "PLAYER_CONTROL_GAINED" then
				UpdateActionBarVisibility()
			end
		end)
	end
end)

-- Register for fire state changes - this is the primary driver
CC.RegisterCallback("FIRE_STATE_CHANGED", function(isNearFire, inCombat)
	if not InCombatLockdown() then
		UpdateActionBarVisibility()
	end
end)

-- Register for settings changes
CC.RegisterCallback("SETTINGS_CHANGED", function(key, value)
	if key == "hideActionBarsMode" or key == "ALL" then
		if not InCombatLockdown() then
			UpdateActionBarVisibility()
		end
	elseif key == "hideMinimapWithBars" then
		if not InCombatLockdown() then
			local hideMinimapEnabled = CC.GetSetting("hideMinimapWithBars")
			if not hideMinimapEnabled and not constitutionOverrideActive then
				-- Toggled OFF: Fade minimap back in smoothly
				-- Record visibility state for frames that should be shown
				for _, frameName in ipairs(MINIMAP_FRAMES) do
					local frameToFade = _G[frameName]
					if frameToFade and frameVisibilityState[frameName] == nil then
						frameVisibilityState[frameName] = frameToFade:IsShown() or frameToFade:GetAlpha() > 0
					end
				end
				minimapCurrentAlpha = 0 -- Start from hidden
				FadeMinimapTo(1)
			elseif hideMinimapEnabled and barsHidden then
				-- Toggled ON while bars are already hidden: fade out minimap smoothly
				-- Record visibility state before hiding
				for _, frameName in ipairs(MINIMAP_FRAMES) do
					local frameToFade = _G[frameName]
					if frameToFade and frameVisibilityState[frameName] == nil then
						frameVisibilityState[frameName] = frameToFade:IsShown()
					end
				end
				minimapCurrentAlpha = 1 -- Start from visible
				FadeMinimapTo(0)
			end
			UpdateActionBarVisibility()
		end
	elseif key == "enabled" then
		if not InCombatLockdown() then
			if value == false then
				-- Master toggle disabled - force show all action bars
				ForceShowAllBars()
			else
				-- Master toggle enabled - apply current settings
				UpdateActionBarVisibility()
			end
		end
	end
end)

-- Public API
function CC.RefreshActionBars()
	UpdateActionBarVisibility()
end

function CC.AreBarsHidden()
	return barsHidden
end

-- Constitution-based hiding API (used by Meters.lua Adventure Mode)
-- This uses the same unified hiding system as regular action bar hiding
function CC.SetConstitutionOverride(active)
	if InCombatLockdown() then
		return false
	end
	local changed = constitutionOverrideActive ~= active
	constitutionOverrideActive = active
	if changed then
		UpdateActionBarVisibility()
		CC.Debug("Constitution override: " .. (active and "ACTIVE" or "INACTIVE"), "general")
	end
	return true
end

function CC.IsConstitutionOverrideActive()
	return constitutionOverrideActive
end
