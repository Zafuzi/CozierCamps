-- CozyCamps - Innkeepers.lua
-- Dynamic detection of Innkeepers via gossip options
-- Works with ALL innkeepers across all expansions in retail
-- Updated for Midnight (Retail 12.0.1 / Interface 120001)

local CC = CozyCamps

------------------------------------------------------------
-- Safe helpers (load-order safe)
------------------------------------------------------------
local function GetSetting(key, default)
    if CC and CC.GetSetting then
        local v = CC.GetSetting(key)
        if v ~= nil then return v end
    end
    return default
end

local function Debug(msg, category)
    if CC and CC.Debug then
        CC.Debug(msg, category or "general")
    end
end

local function IsEligible()
    if CC and CC.IsPlayerEligible then
        return CC.IsPlayerEligible()
    end
    -- Fallback: enabled + level >= 6
    return GetSetting("enabled", true) and (UnitLevel("player") or 0) >= 6
end

local function GetNpcName()
    local name = UnitName("npc")
    if name and name ~= "" then return name end
    name = UnitName("target")
    if name and name ~= "" then return name end
    return nil
end

------------------------------------------------------------
-- Innkeeper Detection via Gossip Options and NPC Title
-- In retail, innkeepers have a gossip option to bind hearthstone
-- The gossip option type for binding is "binder" or contains "home"
------------------------------------------------------------

-- Helper to get NPC subtitle/title from tooltip (e.g., "<Innkeeper>")
local function GetNpcSubtitle()
    -- Method 1: Try C_TooltipInfo API (modern retail)
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local data = C_TooltipInfo.GetUnit("npc")
        if data and data.lines then
            for i, line in ipairs(data.lines) do
                if i == 2 and line.leftText then
                    return line.leftText
                end
            end
        end
    end

    -- Method 2: Scan GameTooltip directly
    if GameTooltip and GameTooltip:IsShown() then
        local line2 = _G["GameTooltipTextLeft2"]
        if line2 then
            local text = line2:GetText()
            if text and text ~= "" then
                return text
            end
        end
    end

    -- Method 3: Create scanning tooltip as fallback
    if not CozyCampsInnkeeperScanTooltip then
        CozyCampsInnkeeperScanTooltip = CreateFrame("GameTooltip", "CozyCampsInnkeeperScanTooltip", nil, "GameTooltipTemplate")
        CozyCampsInnkeeperScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    CozyCampsInnkeeperScanTooltip:ClearLines()
    CozyCampsInnkeeperScanTooltip:SetUnit("npc")

    local numLines = CozyCampsInnkeeperScanTooltip:NumLines()
    if numLines >= 2 then
        local line2 = _G["CozyCampsInnkeeperScanTooltipTextLeft2"]
        if line2 then
            local text = line2:GetText()
            if text and text ~= "" then
                return text
            end
        end
    end

    return nil
end

local function IsGossipInnkeeper()
    -- Method 1: Check NPC subtitle/title (e.g., "<Innkeeper>")
    local subtitle = GetNpcSubtitle()
    if subtitle then
        local lowerSubtitle = subtitle:lower()
        if lowerSubtitle:find("innkeeper") then
            return true
        end
    end

    -- Method 2: Use retail C_GossipInfo API
    if not C_GossipInfo or not C_GossipInfo.GetOptions then
        return false
    end

    local options = C_GossipInfo.GetOptions()
    if not options then return false end

    for _, option in ipairs(options) do
        -- Check gossip option icon or name for innkeeper binding
        -- Innkeeper bind option typically has icon 132594 (hearthstone icon)
        -- or the text contains "home" or "inn"
        local name = option.name or ""
        local gossipOptionID = option.gossipOptionID

        -- Common innkeeper phrases across languages
        local lowerName = name:lower()
        if lowerName:find("make this") or lowerName:find("home") or
           lowerName:find("inn") or lowerName:find("bind") or
           lowerName:find("hearthstone") then
            return true
        end

        -- Check for the standard innkeeper gossip option icon (hearthstone)
        if option.icon and option.icon == 132594 then
            return true
        end
    end

    return false
end

-- Fallback: Static list for Classic innkeepers that might not have gossip options
-- This covers edge cases where gossip detection fails
CC.Innkeepers = CC.Innkeepers or {}

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function CC.IsInnkeeper(npcName)
    -- First check dynamic gossip-based detection
    if IsGossipInnkeeper() then
        return true
    end
    -- Fallback to static list for edge cases
    if npcName and CC.Innkeepers[npcName] then
        return true
    end
    return false
end

function CC.GetInnkeeperInfo(npcName)
    return CC.Innkeepers[npcName]
end

function CC.GetFactionInnkeepers()
    local faction = UnitFactionGroup("player")
    local innkeepers = {}
    for name, info in pairs(CC.Innkeepers) do
        if info.faction == faction or info.faction == "Neutral" then
            innkeepers[name] = info
        end
    end
    return innkeepers
end

------------------------------------------------------------
-- Interaction detection (Midnight/Retail safe)
------------------------------------------------------------
local innkeeperFrame = CreateFrame("Frame")
innkeeperFrame:RegisterEvent("GOSSIP_SHOW")

-- Prevent double-processing in quick succession
local lastProcessedTime = 0
local PROCESS_COOLDOWN = 1.0

innkeeperFrame:SetScript("OnEvent", function(_, event)
    if event ~= "GOSSIP_SHOW" then return end

    -- Extra guard: event can fire without a real NPC unit in some UI flows
    if not UnitExists("npc") and not UnitExists("target") then
        return
    end

    local targetName = GetNpcName()
    if not targetName then
        Debug("Innkeeper check: No NPC name found", "Anguish")
        return
    end

    -- Check if this is an innkeeper (dynamic detection)
    if not CC.IsInnkeeper(targetName) then
        return
    end

    local now = GetTime()
    if (now - lastProcessedTime) < PROCESS_COOLDOWN then
        return
    end
    lastProcessedTime = now

    Debug("Innkeeper detected: " .. targetName, "Anguish")

    local messages = {}

    -- Anguish healing (optional)
    if GetSetting("innkeeperHealsAnguish", false) then
        Debug("Innkeeper recognized for Anguish: " .. targetName, "Anguish")
        if CC and CC.GetAnguish and CC.ResetAnguish then
            local currentAnguish = CC.GetAnguish()
            Debug("Current Anguish: " .. tostring(currentAnguish), "Anguish")

            -- Only heal if anguish is above 15% (vitality below 85%)
            if type(currentAnguish) == "number" and currentAnguish > 15 then
                CC.ResetAnguish()
                table.insert(messages, "|cff00FF00Anguish healed to 85%!|r")
                Debug("Anguish reset by Innkeeper: " .. targetName, "Anguish")

                if GetSetting("playSoundAnguishRelief", false)
                    and GetSetting("AnguishEnabled", false)
                    and IsEligible()
                then
                    PlaySoundFile("Interface\\AddOns\\CozyCamps\\assets\\anguishrelief.wav", "SFX")
                end
            end
        else
            Debug("Innkeeper: GetAnguish or ResetAnguish not found", "Anguish")
        end
    end

    -- Hunger reset (optional)
    if GetSetting("innkeeperResetsHunger", true) then
        if CC and CC.GetHunger and CC.ResetHungerFromInnkeeper then
            local currentHunger = CC.GetHunger()
            if type(currentHunger) == "number" and currentHunger > 0 then
                CC.ResetHungerFromInnkeeper()
                table.insert(messages, "|cff00FF00Hunger fully satisfied!|r")
                Debug("Hunger reset by Innkeeper: " .. targetName, "hunger")
            end
        end
    end

    -- Thirst reset (optional)
    if GetSetting("innkeeperResetsThirst", true) then
        if CC and CC.GetThirst and CC.ResetThirstFromInnkeeper then
            local currentThirst = CC.GetThirst()
            if type(currentThirst) == "number" and currentThirst > 0 then
                local didReset = CC.ResetThirstFromInnkeeper()
                if didReset then
                    table.insert(messages, "|cff00FF00Thirst healed to 85% hydration!|r")
                    Debug("Thirst reset by Innkeeper: " .. targetName, "thirst")
                end
            end
        end
    end

    if #messages > 0 then
        print("|cff88CCFFCozyCamps:|r " .. targetName ..
            " provides comfort and rest. " .. table.concat(messages, " "))
    end
end)
