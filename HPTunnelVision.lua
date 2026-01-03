-- CozierCamps - HPTunnelVision.lua
-- HP-based tunnel vision effect (independent of other CozierCamps settings)
-- Midnight (Retail 12.0.1 / Interface 120001) compatibility
--
-- FIX: UnitHealth("player") may return a "secret value" that can report type == "number"
-- but throws on arithmetic/comparison. We now validate numeric values via pcall before use.
-- This replaces the earlier type-based sanitization that still allowed secret values through. :contentReference[oaicite:1]{index=1}

local CC = CozierCamps
if not CC then
	return
end

------------------------------------------------------------
-- Safe helpers
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

local function RegisterCallback(event, fn)
	if CC and CC.RegisterCallback then
		CC.RegisterCallback(event, fn)
		return true
	end
	return false
end

------------------------------------------------------------
-- HP thresholds and corresponding textures
-- Each level adds on top of the previous for cumulative effect
------------------------------------------------------------
local HP_TEXTURES = {
	"Interface\\AddOns\\CozierCamps\\assets\\tunnel_vision_1.png", -- Level 1: 80% HP
	"Interface\\AddOns\\CozierCamps\\assets\\tunnel_vision_2.png", -- Level 2: 60% HP
	"Interface\\AddOns\\CozierCamps\\assets\\tunnel_vision_3.png", -- Level 3: 40% HP
	"Interface\\AddOns\\CozierCamps\\assets\\tunnel_vision_4.png"  -- Level 4: 20% HP
}

-- HP thresholds (percent) where each level activates (cumulative)
local HP_THRESHOLDS = {0.80, 0.60, 0.40, 0.20}

------------------------------------------------------------
-- Overlay frames and alpha tracking (one frame per level)
------------------------------------------------------------
local overlayFrames = {}
local currentAlphas = {0, 0, 0, 0}
local targetAlphas = {0, 0, 0, 0}

-- Smooth transition speed
local LERP_SPEED = 3.0

------------------------------------------------------------
-- Create overlay frame for a specific level
------------------------------------------------------------
local function CreateOverlayFrame(level)
	if overlayFrames[level] then
		return overlayFrames[level]
	end

	local frame = CreateFrame("Frame", "CozierCampsHPTunnelVision_" .. level, UIParent)
	frame:SetAllPoints(UIParent)

	frame:SetFrameStrata("FULLSCREEN")
	frame:SetFrameLevel(100 + level)

	frame.texture = frame:CreateTexture(nil, "ARTWORK")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture(HP_TEXTURES[level])
	frame.texture:SetBlendMode("BLEND")

	frame:SetAlpha(0)
	frame:Hide()
	frame:EnableMouse(false)

	overlayFrames[level] = frame
	return frame
end

local function CreateAllOverlayFrames()
	for i = 1, 4 do
		CreateOverlayFrame(i)
	end
end

------------------------------------------------------------
-- Secret-value-safe numeric validation
------------------------------------------------------------
local function IsSafeNumber(v)
-- Must look like a number...
	if type(v) ~= "number" then
		return false
	end
	-- ...and must be usable in arithmetic (secret values fail here).
	local ok = pcall(function()
		local _ = v + 0
		return _
	end)
	return ok
end

local function CoerceSafeNumber(v)
	if IsSafeNumber(v) then
		return v
	end

	-- Sometimes numeric strings happen; convert, then validate arithmetic safety.
	local n
	local ok = pcall(function()
		n = tonumber(v)
	end)
	if not ok then
		return nil
	end
	if IsSafeNumber(n) then
		return n
	end
	return nil
end

local function SafeUnitHealth(unit)
	if type(UnitHealth) ~= "function" then
		return nil
	end
	local ok, v = pcall(UnitHealth, unit)
	if not ok then
		return nil
	end
	return CoerceSafeNumber(v)
end

local function SafeUnitHealthMax(unit)
	if type(UnitHealthMax) ~= "function" then
		return nil
	end
	local ok, v = pcall(UnitHealthMax, unit)
	if not ok then
		return nil
	end
	return CoerceSafeNumber(v)
end

------------------------------------------------------------
-- State helpers
------------------------------------------------------------
local function GetPlayerHPPercent()
-- Fail-safe behavior:
-- If health/maxHealth are secret/protected (non-arithmetic-safe), treat as full HP (1.0)
-- so the effect disables rather than spamming errors.

	local health = SafeUnitHealth("player")
	local maxHealth = SafeUnitHealthMax("player")

	if not maxHealth then
		return 1
	end

	-- maxHealth <= 0 can also error if maxHealth is weird; guard with pcall.
	local okMax = pcall(function() return maxHealth <= 0
	end)
	if not okMax or maxHealth <= 0 then
		return 1
	end

	if not health then
		return 1
	end

	-- health < 0 comparison can error for secret values; guard with pcall.
	local okNeg = pcall(function() return health < 0
	end)
	if not okNeg or health < 0 then
		return 1
	end

	local pct
	local okPct = pcall(function()
		pct = health / maxHealth
	end)
	if not okPct or type(pct) ~= "number" then
		return 1
	end

	-- NaN guard
	if pct ~= pct then
		return 1
	end

	if pct < 0 then
		pct = 0
	end
	if pct > 1 then
		pct = 1
	end
	return pct
end

local function ShouldShowHPTunnelVision()
	if not GetSetting("hpTunnelVisionEnabled", false) then
		return false
	end
	if UnitIsDead("player") or UnitIsGhost("player") then
		return false
	end
	return true
end

-- Returns how many tunnel vision layers should be active (0-4)
local function GetHPLevel()
	if not ShouldShowHPTunnelVision() then
		return 0
	end

	local hpPercent = GetPlayerHPPercent()
	local level = 0

	for i, threshold in ipairs(HP_THRESHOLDS) do
		if hpPercent <= threshold then
			level = i
		end
	end

	return level
end

------------------------------------------------------------
-- Update (smooth transitions)
------------------------------------------------------------
local function UpdateHPTunnelVision(elapsed)
	local hpLevel = GetHPLevel()

	for i = 1, 4 do
		if i <= hpLevel then
			targetAlphas[i] = 0.9
			if overlayFrames[i] and not overlayFrames[i]:IsShown() then
				overlayFrames[i]:SetAlpha(0)
				overlayFrames[i]:Show()
			end
		else
			targetAlphas[i] = 0
		end
	end

	for i = 1, 4 do
		local diff = targetAlphas[i] - currentAlphas[i]
		if math.abs(diff) < 0.01 then
			currentAlphas[i] = targetAlphas[i]
		else
			currentAlphas[i] = currentAlphas[i] + (diff * LERP_SPEED * elapsed)
		end

		currentAlphas[i] = math.max(0, math.min(1, currentAlphas[i]))

		local frame = overlayFrames[i]
		if frame then
			frame:SetAlpha(currentAlphas[i])
			if currentAlphas[i] < 0.01 and frame:IsShown() then
				frame:Hide()
			end
		end
	end
end

------------------------------------------------------------
-- Public API for the addon update loop
------------------------------------------------------------
function CC.HandleHPTunnelVisionUpdate(elapsed)
	UpdateHPTunnelVision(elapsed)
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "CozierCampsHPTunnelVisionFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		CreateAllOverlayFrames()
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not overlayFrames[1] then
			CreateAllOverlayFrames()
		end
	end
end)

------------------------------------------------------------
-- Settings change handling (load-order safe)
------------------------------------------------------------
RegisterCallback("SETTINGS_CHANGED", function(key, value)
	if key == "hpTunnelVisionEnabled" or key == "ALL" then
		local enabled = (key == "ALL") and GetSetting("hpTunnelVisionEnabled", false) or (value == true)
		if not enabled then
			for i = 1, 4 do
				targetAlphas[i] = 0
			end
		end
	end
end)
