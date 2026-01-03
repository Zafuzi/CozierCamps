-- CozyCamps - Anguish.lua
-- Anguish system (OnUpdate-only, no RegisterEvent) - Midnight 12.0.1 / 120001 SAFE
--
-- FIX: Some UIs/taint states are blocking ANY Frame:RegisterEvent() from CozyCamps, producing:
-- [ADDON_ACTION_FORBIDDEN] AddOn 'CozyCamps' tried to call the protected function 'Frame:RegisterEvent()'.
-- This file therefore uses ZERO event registration and runs entirely via OnUpdate + callbacks.

local CC = CozyCamps
if not CC then return end

------------------------------------------------------------
-- Safe helpers
------------------------------------------------------------
local function GetSetting(key, default)
    if CC and CC.GetSetting then
        local v = CC.GetSetting(key)
        if v ~= nil then return v end
    end
    return default
end

local function Debug(msg)
    if CC and CC.Debug then
        CC.Debug(msg, "Anguish")
    end
end

local function IsEligible()
    if CC and CC.IsPlayerEligible then
        return CC.IsPlayerEligible()
    end
    return GetSetting("enabled", true) and (UnitLevel("player") or 0) >= 6
end

------------------------------------------------------------
-- Secret-value safe numeric usage (Midnight)
------------------------------------------------------------
local function IsSafeNumber(v)
    if type(v) ~= "number" then return false end
    return pcall(function() local _ = v + 0 return _ end)
end

local function CoerceSafeNumber(v)
    if IsSafeNumber(v) then return v end
    local n
    local ok = pcall(function() n = tonumber(v) end)
    if not ok then return nil end
    if IsSafeNumber(n) then return n end
    return nil
end

local function SafeUnitHealth(unit)
    if type(UnitHealth) ~= "function" then return nil end
    local ok, v = pcall(UnitHealth, unit)
    if not ok then return nil end
    return CoerceSafeNumber(v)
end

local function SafeUnitHealthMax(unit)
    if type(UnitHealthMax) ~= "function" then return nil end
    local ok, v = pcall(UnitHealthMax, unit)
    if not ok then return nil end
    return CoerceSafeNumber(v)
end

------------------------------------------------------------
-- State
------------------------------------------------------------
local anguish = 0
local savedAnguish = 0
local wasInDungeon = false
local MAX_ANGUISH = 100

-- Polling timers
local pollHealthTimer = 0
local HEALTH_POLL_INTERVAL = 0.10

local pollAuraTimer = 0
local AURA_POLL_INTERVAL = 0.25

-- Health tracking (damage detection)
local lastHealth = nil
local lastMaxHealth = nil

-- Daze tracking (spellId 1604)
local DAZED_SPELL_ID = 1604
local isDazed = false

-- Scale options (kept compatible with your previous settings)
local SCALE_VALUES = {0.01, 0.05, 0.30} -- Default/Hard/Insane
local function GetScaleMultiplier()
    local setting = GetSetting("AnguishScale", 1)
    return SCALE_VALUES[setting] or 0.01
end

-- Multipliers
local CRIT_MULTIPLIER = 5.0
local DAZE_MULTIPLIER = 5.0

-- Pulse info for meters (0 none, 1 normal, 2 crit, 3 daze)
local currentPulseType = 0
local currentPulseIntensity = 0
local PULSE_DECAY_RATE = 0.8

-- Decay / activity
local isDecaying = false
local lastActivity = nil

-- Healing checkpoint logic (same behavior style as before)
local function GetMinHealableAnguish()
    if anguish >= 75 then return 75
    elseif anguish >= 50 then return 50
    elseif anguish >= 25 then return 25
    else return 0 end
end

------------------------------------------------------------
-- Overlays (optional)
------------------------------------------------------------
local OVERLAY_TEXTURES = {
    "Interface\\AddOns\\CozyCamps\\assets\\anguish20.png",
    "Interface\\AddOns\\CozyCamps\\assets\\anguish40.png",
    "Interface\\AddOns\\CozyCamps\\assets\\anguish60.png",
    "Interface\\AddOns\\CozyCamps\\assets\\anguish80.png"
}

local overlayFrames = {}
local overlayCurrent = {0,0,0,0}
local overlayTarget  = {0,0,0,0}
local overlayPulsePhase = 0
local OVERLAY_PULSE_SPEED = 0.5
local OVERLAY_PULSE_MIN = 0.75
local OVERLAY_PULSE_MAX = 1.0

local function CreateOverlay(i)
    if overlayFrames[i] then return overlayFrames[i] end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(100 + i)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetTexture(OVERLAY_TEXTURES[i])
    t:SetBlendMode("BLEND")
    f.texture = t
    f:SetAlpha(0)
    f:Hide()
    overlayFrames[i] = f
    return f
end

local function EnsureOverlays()
    for i=1,4 do CreateOverlay(i) end
end

local function GetOverlayLevel()
    if anguish >= 80 then return 4
    elseif anguish >= 60 then return 3
    elseif anguish >= 40 then return 2
    elseif anguish >= 20 then return 1
    else return 0 end
end

local function UpdateOverlays(elapsed)
    if not GetSetting("AnguishEnabled", false) then
        for i=1,4 do overlayTarget[i] = 0 end
    else
        local lvl = GetOverlayLevel()
        for i=1,4 do
            overlayTarget[i] = (i <= lvl) and 0.7 or 0
            if overlayFrames[i] and overlayTarget[i] > 0 and not overlayFrames[i]:IsShown() then
                overlayFrames[i]:SetAlpha(0)
                overlayFrames[i]:Show()
            end
        end
    end

    overlayPulsePhase = overlayPulsePhase + elapsed * OVERLAY_PULSE_SPEED
    if overlayPulsePhase > 1 then overlayPulsePhase = overlayPulsePhase - 1 end
    local pulseRange = OVERLAY_PULSE_MAX - OVERLAY_PULSE_MIN
    local pulseMod = OVERLAY_PULSE_MIN + (pulseRange * (0.5 + 0.5 * math.sin(overlayPulsePhase * math.pi * 2)))

    for i=1,4 do
        local f = overlayFrames[i]
        if f then
            local diff = overlayTarget[i] - overlayCurrent[i]
            if math.abs(diff) < 0.01 then
                overlayCurrent[i] = overlayTarget[i]
            else
                local speed = (diff > 0) and 2.0 or 1.0
                overlayCurrent[i] = overlayCurrent[i] + diff * speed * elapsed
            end
            overlayCurrent[i] = math.max(0, math.min(1, overlayCurrent[i]))
            f:SetAlpha(overlayCurrent[i] * pulseMod)
            if overlayCurrent[i] <= 0.01 and overlayTarget[i] == 0 then
                f:Hide()
                overlayCurrent[i] = 0
            end
        end
    end
end

------------------------------------------------------------
-- Aura polling (Dazed)
------------------------------------------------------------
local function IsDazedAuraUp()
    if AuraUtil and AuraUtil.ForEachAura then
        local found = false
        AuraUtil.ForEachAura("player", "HARMFUL", nil, function(aura)
            if aura and aura.spellId == DAZED_SPELL_ID then
                found = true
                return true
            end
        end)
        return found
    end
    return false
end

local function UpdateDazeState()
    local now = IsDazedAuraUp()
    if now and not isDazed then
        isDazed = true
        -- Small immediate bump (like your old behavior)
        anguish = math.min(MAX_ANGUISH, anguish + 1.0)
        currentPulseType = 3
        currentPulseIntensity = 1.0
        lastActivity = "Dazed"
        Debug("Dazed detected (aura) - Anguish +1 and daze multiplier active")
    elseif (not now) and isDazed then
        isDazed = false
        Debug("Dazed ended (aura)")
    end
end

------------------------------------------------------------
-- Damage detection (health polling)
------------------------------------------------------------
local function TriggerPulse(ptype, intensity)
    currentPulseType = ptype
    currentPulseIntensity = math.max(0.25, math.min(1.0, (intensity or 0.4) * 2.0))
end

local function UpdatePulse(elapsed)
    if currentPulseIntensity > 0 then
        currentPulseIntensity = currentPulseIntensity - (PULSE_DECAY_RATE * elapsed)
        if currentPulseIntensity <= 0 then
            currentPulseIntensity = 0
            currentPulseType = 0
        end
    end
end

local function ShouldAccumulate()
    if not GetSetting("AnguishEnabled", false) then return false end
    if not IsEligible() then return false end
    if UnitOnTaxi("player") then return false end
    if UnitIsDead("player") or UnitIsGhost("player") then return false end
    if CC and CC.IsInDungeonOrRaid and CC.IsInDungeonOrRaid() then return false end
    return true
end

local function PollHealthForDamage()
    if not ShouldAccumulate() then
        lastHealth = nil
        lastMaxHealth = nil
        return
    end

    local h = SafeUnitHealth("player")
    local mh = SafeUnitHealthMax("player")
    if not h or not mh or mh <= 0 then
        -- Secret values / bad reads: fail safe (no change)
        return
    end

    if lastHealth == nil or lastMaxHealth == nil or (not IsSafeNumber(lastHealth)) then
        lastHealth = h
        lastMaxHealth = mh
        return
    end

    local dmg = lastHealth - h
    if dmg > 0 then
        local scale = GetScaleMultiplier()
        local add = (dmg / mh) * MAX_ANGUISH * scale

        -- Heuristic crit: very large chunk => treat as crit
        local isCrit = (dmg / mh) >= 0.18
        if isCrit then
            add = add * CRIT_MULTIPLIER
        end
        if isDazed then
            add = add * DAZE_MULTIPLIER
        end

        anguish = math.min(MAX_ANGUISH, anguish + add)

        local ptype = isDazed and 3 or (isCrit and 2 or 1)
        TriggerPulse(ptype, dmg / mh)
        lastActivity = isDazed and "Dazed damage" or (isCrit and "Critical hit" or "Took damage")
    end

    lastHealth = h
    lastMaxHealth = mh
end

------------------------------------------------------------
-- Passive recovery (resting / near fire)
------------------------------------------------------------
local function UpdateRecovery(elapsed)
    isDecaying = false

    if not GetSetting("AnguishEnabled", false) then return end
    if not IsEligible() then return end

    local resting = IsResting() == true
    local nearFire = (CC and CC.isNearFire) == true

    if UnitIsDead("player") or UnitIsGhost("player") then return end
    if UnitOnTaxi("player") then return end
    if CC and CC.IsInDungeonOrRaid and CC.IsInDungeonOrRaid() then return end

    -- Recover down to 25 while resting, down toward 0 if resting+fire (feel-good)
    local targetFloor = resting and 25 or 0
    if resting and nearFire then targetFloor = 0 end

    if anguish > targetFloor then
        local rate = resting and 0.5 or (nearFire and 0.5 or 0)
        if rate > 0 then
            local nv = anguish - (rate * elapsed)
            if nv < targetFloor then nv = targetFloor end
            if nv ~= anguish then
                anguish = nv
                isDecaying = true
                lastActivity = resting and (nearFire and "Resting by fire" or "Resting") or "Warming by fire"
            end
        end
    end
end

local function UpdateDungeonPauseState()
    local inDungeon = CC and CC.IsInDungeonOrRaid and CC.IsInDungeonOrRaid()
    if inDungeon and not wasInDungeon then
        savedAnguish = anguish
        if CC.charDB then
            CC.charDB.savedAnguishPreDungeon = savedAnguish
        end
        Debug(string.format("Entering dungeon - Anguish paused at %.1f%%", savedAnguish))
    elseif not inDungeon and wasInDungeon then
        anguish = savedAnguish
        Debug(string.format("Leaving dungeon - Anguish restored to %.1f%%", anguish))
    end
    wasInDungeon = inDungeon or false
end

------------------------------------------------------------
-- Public API expected by other files
------------------------------------------------------------
function CC.GetAnguish() return anguish end
function CC.GetAnguishPercent() return anguish / MAX_ANGUISH end

function CC.SetAnguish(v)
    v = tonumber(v)
    if not v then return false end
    anguish = math.max(0, math.min(MAX_ANGUISH, v))
    return true
end

function CC.ResetAnguish()
    -- Your old behavior: innkeeper heals to 85% (i.e., sets anguish to 15)
    anguish = math.floor(MAX_ANGUISH * 0.15)
end

function CC.HealAnguishFully()
    anguish = 0
end

function CC.IsAnguishDecaying()
    return isDecaying and anguish > 0
end

function CC.GetAnguishPulse()
    return currentPulseType, currentPulseIntensity
end

function CC.GetAnguishCheckpoint()
    return GetMinHealableAnguish()
end

function CC.IsDazed()
    return isDazed
end

function CC.IsAnguishPaused()
    if not GetSetting("AnguishEnabled", false) then return false end
    if not IsEligible() then return false end
    return (CC and CC.IsInDungeonOrRaid and CC.IsInDungeonOrRaid())
        or UnitOnTaxi("player")
        or UnitIsDead("player")
        or UnitIsGhost("player")
end

function CC.GetAnguishActivity()
    if CC.IsAnguishPaused() then return nil end
    return lastActivity
end

------------------------------------------------------------
-- Main update entrypoint (called by CampfireDetection OnUpdate)
------------------------------------------------------------
local initialized = false

function CC.HandleAnguishUpdate(elapsed)
    if not initialized then
        initialized = true
        EnsureOverlays()

        -- Restore from charDB if present
        if CC.charDB and type(CC.charDB.savedAnguish) == "number" then
            anguish = math.max(0, math.min(MAX_ANGUISH, CC.charDB.savedAnguish))
        end
        if CC and CC.IsInDungeonOrRaid and CC.IsInDungeonOrRaid() then
            if CC.charDB and type(CC.charDB.savedAnguishPreDungeon) == "number" then
                savedAnguish = CC.charDB.savedAnguishPreDungeon
                Debug(string.format("Pre-dungeon Anguish restored: %.1f%%", savedAnguish))
            end
            wasInDungeon = true
        end

        lastHealth = SafeUnitHealth("player")
        lastMaxHealth = SafeUnitHealthMax("player")

        Debug("Anguish initialized (OnUpdate-only)")
    end

    -- Timed polling
    pollAuraTimer = pollAuraTimer + elapsed
    if pollAuraTimer >= AURA_POLL_INTERVAL then
        pollAuraTimer = pollAuraTimer - AURA_POLL_INTERVAL
        UpdateDazeState()
    end

    pollHealthTimer = pollHealthTimer + elapsed
    if pollHealthTimer >= HEALTH_POLL_INTERVAL then
        pollHealthTimer = pollHealthTimer - HEALTH_POLL_INTERVAL
        PollHealthForDamage()
    end

    UpdateDungeonPauseState()
    UpdateRecovery(elapsed)
    UpdatePulse(elapsed)
    UpdateOverlays(elapsed)
end

------------------------------------------------------------
-- Optional: persist on logout if your Core fires callbacks (no events here)
------------------------------------------------------------
if CC.RegisterCallback then
    CC.RegisterCallback("PLAYER_LOGOUT", function()
        if CC.charDB then
            CC.charDB.savedAnguish = anguish
            if wasInDungeon then
                CC.charDB.savedAnguishPreDungeon = savedAnguish
            else
                CC.charDB.savedAnguishPreDungeon = nil
            end
        end
    end)
end
