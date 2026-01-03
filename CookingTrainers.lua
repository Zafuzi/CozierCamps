-- CozyCamps - CookingTrainers.lua
-- Dynamic detection of Cooking trainers via trainer API and gossip
-- Works with ALL cooking trainers across all expansions in retail
-- Updated for Midnight (Retail 12.0.1 / Interface 120001)

local CC = CozyCamps

------------------------------------------------------------
-- Safe helpers
------------------------------------------------------------
local function Debug(msg)
	if CC and CC.Debug then
		CC.Debug(msg, "hunger")
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

local function IsEligible()
	if CC and CC.IsPlayerEligible then
		return CC.IsPlayerEligible()
	end
	return true
end

local function GetNpcName()
	local name = UnitName("npc")
	if name and name ~= "" then
		return name
	end
	name = UnitName("target")
	if name and name ~= "" then
		return name
	end
	return nil
end

------------------------------------------------------------
-- Cooking Trainer Detection
-- In retail, cooking trainers can be detected via:
-- 1. NPC name/subtitle containing cooking-related keywords
-- 2. TRAINER_SHOW event + checking trainer skill line
-- 3. Gossip text mentioning cooking
------------------------------------------------------------
local COOKING_SKILL_LINE = 185 -- Cooking profession ID

-- Helper to get NPC subtitle/title from tooltip (e.g., "<Cooking Trainer>")
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
	if not CozyCampsCookingScanTooltip then
		CozyCampsCookingScanTooltip = CreateFrame("GameTooltip", "CozyCampsCookingScanTooltip", nil, "GameTooltipTemplate")
		CozyCampsCookingScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	end

	CozyCampsCookingScanTooltip:ClearLines()
	CozyCampsCookingScanTooltip:SetUnit("npc")

	local numLines = CozyCampsCookingScanTooltip:NumLines()
	if numLines >= 2 then
		local line2 = _G["CozyCampsCookingScanTooltipTextLeft2"]
		if line2 then
			local text = line2:GetText()
			if text and text ~= "" then
				return text
			end
		end
	end

	return nil
end

local function IsCookingTrainer()
	local npcName = GetNpcName()
	if not npcName then
		return false
	end

	-- Method 1: Check NPC name for cooking keywords
	local lowerName = npcName:lower()
	if lowerName:find("cook") or lowerName:find("chef") or
	lowerName:find("culinary") or lowerName:find("cooking trainer") or
	lowerName:find("cuisine") or lowerName:find("sous") then
		return true
	end

	-- Method 2: Check NPC subtitle/title (e.g., "<Cooking Trainer>")
	local subtitle = GetNpcSubtitle()
	if subtitle then
		local lowerSubtitle = subtitle:lower()
		if lowerSubtitle:find("cook") or lowerSubtitle:find("chef") or
		lowerSubtitle:find("culinary") then
			return true
		end
	end

	-- Method 2: Check if NPC teaches cooking via profession API
	if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
		local skillLineID = C_TradeSkillUI.GetTradeSkillLine()
		if skillLineID == COOKING_SKILL_LINE then
			return true
		end
	end

	-- Method 3: Check gossip options for cooking-related text
	if C_GossipInfo and C_GossipInfo.GetOptions then
		local options = C_GossipInfo.GetOptions()
		if options then
			for _, option in ipairs(options) do
				local optionName = option.name or ""
				local lowerOption = optionName:lower()
				if lowerOption:find("cook") or lowerOption:find("recipe") or
				lowerOption:find("culinary") or lowerOption:find("chef") then
					return true
				end
			end
		end
	end

	-- Method 4: Check gossip text itself
	if C_GossipInfo and C_GossipInfo.GetText then
		local gossipText = C_GossipInfo.GetText() or ""
		local lowerText = gossipText:lower()
		if lowerText:find("cook") or lowerText:find("recipe") or
		lowerText:find("culinary") or lowerText:find("chef") then
			return true
		end
	end

	return false
end

-- Fallback static list for edge cases
CC.CookingTrainers = CC.CookingTrainers or {}

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function CC.IsCookingTrainer(npcName)
-- First check dynamic detection
	if IsCookingTrainer() then
		return true
	end
	-- Fallback to static list
	if npcName and CC.CookingTrainers[npcName] then
		return true
	end
	return false
end

function CC.GetCookingTrainerInfo(npcName)
	return CC.CookingTrainers[npcName]
end

function CC.GetFactionCookingTrainers()
	local faction = UnitFactionGroup("player")
	local trainers = {}
	for name, info in pairs(CC.CookingTrainers) do
		if info.faction == faction or info.faction == "Neutral" then
			trainers[name] = info
		end
	end
	return trainers
end

------------------------------------------------------------
-- Interaction detection (Retail/Midnight safe)
------------------------------------------------------------
local cookingFrame = CreateFrame("Frame")
cookingFrame:RegisterEvent("GOSSIP_SHOW")
cookingFrame:RegisterEvent("TRAINER_SHOW")

-- Track last processed to avoid double-firing
local lastProcessedTime = 0
local PROCESS_COOLDOWN = 1.0

cookingFrame:SetScript("OnEvent", function(_, event)
-- Extra guard: sometimes events can fire without a real NPC
	if not UnitExists("npc") and not UnitExists("target") then
		return
	end

	local targetName = GetNpcName()
	if not targetName then
		return
	end

	-- Check if this is a cooking trainer
	if not CC.IsCookingTrainer(targetName) then
		return
	end

	local now = GetTime()
	if (now - lastProcessedTime) < PROCESS_COOLDOWN then
		return
	end
	lastProcessedTime = now

	-- Player is interacting with a cooking trainer
	if CC.GetHunger and CC.ResetHungerFromTrainer then
		local currentHunger = CC.GetHunger()
		if currentHunger and currentHunger > 0 then
			CC.ResetHungerFromTrainer()

			print("|cff88CCFFCozyCamps:|r " .. targetName ..
			" shares a hearty meal with you. |cff00FF00Hunger fully satisfied!|r")

			Debug("Hunger reset by Cooking trainer: " .. targetName)

			-- Play relief sound if enabled
			if GetSetting("playSoundHungerRelief", false)
			and GetSetting("hungerEnabled", false)
			and IsEligible()
			then
				PlaySoundFile("Interface\\AddOns\\CozyCamps\\assets\\hungerrelief.wav", "SFX")
			end
		end
	end
end)
