-- CozierCamps - FirstAidTrainers.lua
-- Dynamic detection of Medical NPCs for Anguish healing
-- Note: First Aid profession was removed in BFA. This now detects
-- medical NPCs like doctors, medics, nurses, and bandage vendors.
-- Updated for Midnight (Retail 12.0.1 / Interface 120001)

local CC = CozierCamps

------------------------------------------------------------
-- Safe helpers (load-order safe)
------------------------------------------------------------
local function Debug(msg)
	if CC and CC.Debug then
		CC.Debug(msg, "Anguish")
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
	-- Fallback: enabled + level >= 6
	return GetSetting("enabled", true) and (UnitLevel("player") or 0) >= 6
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
-- Medical NPC Detection
-- Detects NPCs that could provide medical assistance:
-- - NPCs with "medic", "doctor", "nurse", "healer" in name/title
-- - Bandage trainers (legacy First Aid trainers)
-- - NPCs that sell bandages or medical supplies
-- - Field medics and combat medics
------------------------------------------------------------

-- Helper to get NPC subtitle/title from tooltip (e.g., "<Bandage Trainer>")
local function GetNpcSubtitle()
	local subtitle = nil

	-- Method 1: Try C_TooltipInfo API (modern retail)
	if C_TooltipInfo and C_TooltipInfo.GetUnit then
		local data = C_TooltipInfo.GetUnit("npc")
		if data and data.lines then
			for i, line in ipairs(data.lines) do
				if i == 2 and line.leftText then
					subtitle = line.leftText
					Debug("GetNpcSubtitle: C_TooltipInfo found: " .. tostring(subtitle))
					return subtitle
				end
			end
		end
		Debug("GetNpcSubtitle: C_TooltipInfo returned no line 2")
	else
		Debug("GetNpcSubtitle: C_TooltipInfo.GetUnit not available")
	end

	-- Method 2: Scan GameTooltip directly (it may have NPC info cached)
	if GameTooltip and GameTooltip:IsShown() then
		local line2 = _G["GameTooltipTextLeft2"]
		if line2 then
			local text = line2:GetText()
			if text and text ~= "" then
				Debug("GetNpcSubtitle: GameTooltip found: " .. tostring(text))
				return text
			end
		end
	end

	-- Method 3: Create scanning tooltip as fallback
	if not CozierCampsScanTooltip then
		CozierCampsScanTooltip = CreateFrame("GameTooltip", "CozierCampsScanTooltip", nil, "GameTooltipTemplate")
		CozierCampsScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	end

	CozierCampsScanTooltip:ClearLines()
	CozierCampsScanTooltip:SetUnit("npc")

	-- Check line 2 for subtitle
	local numLines = CozierCampsScanTooltip:NumLines()
	Debug("GetNpcSubtitle: Scan tooltip has " .. tostring(numLines) .. " lines")
	if numLines >= 2 then
		local line2 = _G["CozierCampsScanTooltipTextLeft2"]
		if line2 then
			local text = line2:GetText()
			if text and text ~= "" then
				Debug("GetNpcSubtitle: Scan tooltip found: " .. tostring(text))
				return text
			end
		end
	end

	Debug("GetNpcSubtitle: No subtitle found")
	return nil
end

-- Keywords that indicate a medical/bandage NPC
local MEDICAL_KEYWORDS = {
	"medic", "doctor", "nurse", "healer", "surgeon", "physician",
	"bandage", "first aid", "trauma", "aid station", "bandage trainer"
}

local function IsMedicalNpc()
	local npcName = GetNpcName()
	if not npcName then
		return false
	end

	-- Debug print to chat (temporary - remove after debugging)
	local debugMode = CC and CC.GetSetting and CC.GetSetting("debugMode")

	-- Check NPC name for medical keywords
	local lowerName = npcName:lower()
	for _, keyword in ipairs(MEDICAL_KEYWORDS) do
		if lowerName:find(keyword) then
			if debugMode then
				print("|cffFFFF00[CC Debug]|r Medical NPC by name: " .. npcName .. " (keyword: " .. keyword .. ")")
			end
			return true
		end
	end

	-- Check NPC subtitle/title (e.g., "<Bandage Trainer>")
	local subtitle = GetNpcSubtitle()
	if debugMode then
		print("|cffFFFF00[CC Debug]|r NPC: " .. npcName .. " | Subtitle: " .. tostring(subtitle))
	end

	if subtitle then
		local lowerSubtitle = subtitle:lower()
		for _, keyword in ipairs(MEDICAL_KEYWORDS) do
			if lowerSubtitle:find(keyword) then
				if debugMode then
					print("|cffFFFF00[CC Debug]|r Medical NPC by subtitle: " .. subtitle .. " (keyword: " .. keyword .. ")")
				end
				return true
			end
		end
	end

	-- Check gossip text for medical-related content
	if C_GossipInfo and C_GossipInfo.GetText then
		local gossipText = C_GossipInfo.GetText() or ""
		local lowerText = gossipText:lower()
		if lowerText:find("heal") or lowerText:find("wound") or
		lowerText:find("bandage") or lowerText:find("medical") or
		lowerText:find("injury") or lowerText:find("mend") or
		lowerText:find("first aid") or lowerText:find("trauma") then
			return true
		end
	end

	-- Check gossip options for medical-related options
	if C_GossipInfo and C_GossipInfo.GetOptions then
		local options = C_GossipInfo.GetOptions()
		if options then
			for _, option in ipairs(options) do
				local optionName = option.name or ""
				local lowerOption = optionName:lower()
				if lowerOption:find("heal") or lowerOption:find("bandage") or
				lowerOption:find("medical") or lowerOption:find("wound") or
				lowerOption:find("first aid") or lowerOption:find("train") then
					return true
				end
			end
		end
	end

	return false
end

-- Legacy API compatibility - empty table since First Aid is removed
CC.FirstAidTrainers = CC.FirstAidTrainers or {}

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function CC.IsFirstAidTrainer(npcName)
-- Dynamic medical NPC detection
	if IsMedicalNpc() then
		return true
	end
	-- Legacy fallback
	if npcName and CC.FirstAidTrainers[npcName] then
		return true
	end
	return false
end

-- Alias for consistency
CC.IsMedicalNpc = CC.IsFirstAidTrainer

function CC.GetFirstAidTrainerInfo(npcName)
	return CC.FirstAidTrainers[npcName]
end

function CC.GetFactionTrainers()
	local faction = UnitFactionGroup("player")
	local trainers = {}
	for name, info in pairs(CC.FirstAidTrainers) do
		if info.faction == faction then
			trainers[name] = info
		end
	end
	return trainers
end

------------------------------------------------------------
-- Interaction detection (Midnight/Retail safe)
------------------------------------------------------------
local medicalFrame = CreateFrame("Frame")
medicalFrame:RegisterEvent("GOSSIP_SHOW")
medicalFrame:RegisterEvent("TRAINER_SHOW")

-- Prevent double-firing within same interaction window
local lastProcessedTime = 0
local lastProcessedNpc = nil
local PROCESS_COOLDOWN = 1.0

local function ProcessMedicalNpc(eventName)
-- Extra guard: sometimes events can fire without a real NPC unit.
	if not UnitExists("npc") and not UnitExists("target") then
		Debug("No NPC or target exists for " .. eventName)
		return
	end

	local targetName = GetNpcName()
	if not targetName then
		Debug("Could not get NPC name for " .. eventName)
		return
	end

	Debug("Checking NPC: " .. targetName .. " (event: " .. eventName .. ")")

	-- Check if this is a medical NPC
	local isMedical = CC.IsFirstAidTrainer(targetName)
	Debug("Is medical NPC: " .. tostring(isMedical))

	if not isMedical then
		return
	end

	local now = GetTime()
	if (now - lastProcessedTime) < PROCESS_COOLDOWN and lastProcessedNpc == targetName then
		Debug("Skipping - cooldown active for " .. targetName)
		return
	end
	lastProcessedTime = now
	lastProcessedNpc = targetName

	Debug("Processing medical NPC: " .. targetName)

	if CC.GetAnguish and CC.HealAnguishFully then
		local currentAnguish = CC.GetAnguish()
		Debug("Current anguish: " .. tostring(currentAnguish))
		if currentAnguish and currentAnguish > 0 then
			CC.HealAnguishFully()

			print("|cff88CCFFCozierCamps:|r " .. targetName ..
			" tends to your wounds. |cff00FF00Anguish fully healed!|r")

			Debug("Anguish fully healed by Medical NPC: " .. targetName)

			-- Play relief sound if enabled and eligible
			if GetSetting("playSoundAnguishRelief", false)
			and GetSetting("AnguishEnabled", false)
			and IsEligible()
			then
				PlaySoundFile("Interface\\AddOns\\CozierCamps\\assets\\anguishrelief.wav", "SFX")
			end
		else
			Debug("Anguish is 0 or nil, no healing needed")
		end
	else
		Debug("GetAnguish or HealAnguishFully not available")
	end
end

medicalFrame:SetScript("OnEvent", function(_, event)
	ProcessMedicalNpc(event)
end)
