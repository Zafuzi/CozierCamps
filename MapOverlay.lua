-- CozierCamps - MapOverlay.lua
-- Shows survival icons on the world map (fires, inns, first aid trainers, cooking trainers)
-- Midnight (Retail 12.0.1 / Interface 120001) compatible

local CC = CozierCamps

------------------------------------------------------------
-- Safe helpers (load-order safe)
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

local function SetSetting(key, value)
	if CC and CC.SetSetting then
		CC.SetSetting(key, value)
	end
end

local function Debug(msg)
	if CC and CC.Debug then
		CC.Debug(msg, "general")
	end
end

------------------------------------------------------------
-- Pin pools & state
------------------------------------------------------------
local firePinPool, innPinPool, trainerPinPool, cookingPinPool = {}, {}, {}, {}
local activeFirePins, activeInnPins, activeTrainerPins, activeCookingPins = {}, {}, {}, {}

local MAP_PIN_SIZE = 16
local INN_PIN_SIZE = 12 -- 25% smaller for inn pins

-- Icon textures
local FIRE_ICON = "Interface\\AddOns\\CozierCamps\\assets\\fireicon"
local INN_ICON = "Interface\\AddOns\\CozierCamps\\assets\\exhaustionicon"
local TRAINER_ICON = "Interface\\AddOns\\CozierCamps\\assets\\anguishicon"
local COOKING_ICON = "Interface\\AddOns\\CozierCamps\\assets\\hungericon"

-- Faction constants in your location DB
local FACTION_ALLIANCE = "A"
local FACTION_HORDE = "H"
local FACTION_NEUTRAL = "N"

local function GetPlayerFactionTag()
	local faction = UnitFactionGroup("player")
	if faction == "Alliance" then
		return FACTION_ALLIANCE
	end
	return FACTION_HORDE
end

local function ShouldShowForFaction(locationFaction)
	if locationFaction == FACTION_NEUTRAL then
		return true
	end
	return locationFaction == GetPlayerFactionTag()
end

------------------------------------------------------------
-- Location DBs (unchanged from your file)
------------------------------------------------------------
-- Inn location database with faction tags
local INN_LOCATIONS = {
	-- Alliance - Eastern Kingdoms
	["Stormwind City"] = {{x = 60.5, y = 75.4, name = "Innkeeper Allison", subZone = "Trade District", f = "A"}},
	["Elwynn Forest"] = {{x = 43.8, y = 65.8, name = "Innkeeper Farley", subZone = "Goldshire", f = "A"}},
	["Westfall"] = {{x = 52.8, y = 53.6, name = "Innkeeper Belm", subZone = "Sentinel Hill", f = "A"}},
	["Duskwood"] = {{x = 73.8, y = 44.5, name = "Innkeeper Heather", subZone = "Darkshire", f = "A"}},
	["Loch Modan"] = {{x = 35.5, y = 48.4, name = "Innkeeper Helbrek", subZone = "Thelsamar", f = "A"}},
	["Ironforge"] = {{x = 18.5, y = 51.5, name = "Innkeeper Firebrew", subZone = "The Commons", f = "A"}},
	["Wetlands"] = {{x = 10.6, y = 60.9, name = "Innkeeper Shyria", subZone = "Menethil Harbor", f = "A"}},
	["Redridge Mountains"] = {{x = 26.5, y = 41.5, name = "Innkeeper Brianna", subZone = "Lakeshire", f = "A"}},
	["Arathi Highlands"] = {{x = 46.0, y = 47.0, name = "Innkeeper Anderson", subZone = "Refuge Pointe", f = "A"}},
	["Dun Morogh"] = {{x = 46.8, y = 52.3, name = "Innkeeper Skindle", subZone = "Kharanos", f = "A"}},
	["The Hinterlands"] = {{x = 14.0, y = 44.5, name = "Innkeeper Thulfram", subZone = "Aerie Peak", f = "A"}},
	["Blasted Lands"] = {{x = 65.5, y = 24.2, name = "Innkeeper Jayka", subZone = "Nethergarde Keep", f = "A"}},

	-- Alliance - Kalimdor
	["Teldrassil"] = {{x = 55.5, y = 52.2, name = "Innkeeper Keldamyr", subZone = "Dolanaar", f = "A"}},
	["Darnassus"] = {{x = 62.2, y = 33.0, name = "Innkeeper Saelienne", subZone = "Craftsmen's Terrace", f = "A"}},
	["Darkshore"] = {{x = 36.5, y = 44.6, name = "Innkeeper Shaussiy", subZone = "Auberdine", f = "A"}},
	["Stonetalon Mountains"] = {{x = 36.5, y = 7.2, name = "Innkeeper Lyshaerya", subZone = "Stonetalon Peak", f = "A"}},

	-- Horde - Eastern Kingdoms
	["Tirisfal Glades"] = {{x = 61.5, y = 59.2, name = "Innkeeper Renee", subZone = "Brill", f = "H"}},
	["Undercity"] = {{x = 68.0, y = 8.0, name = "Innkeeper Norman", subZone = "Trade Quarter", f = "H"}},
	["Silverpine Forest"] = {{x = 44.5, y = 39.8, name = "Innkeeper Bates", subZone = "The Sepulcher", f = "H"}},
	["Hillsbrad Foothills"] = {{x = 62.0, y = 19.2, name = "Innkeeper Shay", subZone = "Tarren Mill", f = "H"}},

	-- Horde - Kalimdor
	["Durotar"] = {{x = 52.2, y = 41.2, name = "Innkeeper Grosk", subZone = "Razor Hill", f = "H"}},
	["Orgrimmar"] = {{x = 54.0, y = 68.5, name = "Innkeeper Gryshka", subZone = "Valley of Strength", f = "H"}},
	["Mulgore"] = {{x = 47.0, y = 60.5, name = "Innkeeper Kauth", subZone = "Bloodhoof Village", f = "H"}},
	["Thunder Bluff"] = {{x = 45.5, y = 64.0, name = "Innkeeper Pala", subZone = "Lower Rise", f = "H"}},
	["Thousand Needles"] = {{x = 45.2, y = 50.8, name = "Innkeeper Abeqwa", subZone = "Freewind Post", f = "H"}},

	-- Contested zones with both factions
	["Dustwallow Marsh"] = {
		{x = 66.5, y = 45.2, name = "Innkeeper Trelayne", subZone = "Theramore Isle", f = "A"},
		{x = 35.1, y = 30.5, name = "Innkeeper Linkee", subZone = "Brackenwall Village", f = "H"}
	},
	["Ashenvale"] = {
		{x = 37.0, y = 51.2, name = "Innkeeper Kimlya", subZone = "Astranaar", f = "A"},
		{x = 73.2, y = 61.5, name = "Innkeeper Kaylisk", subZone = "Splintertree Post", f = "H"}
	},
	["Feralas"] = {
		{x = 30.5, y = 43.2, name = "Innkeeper Greul", subZone = "Feathermoon Stronghold", f = "A"},
		{x = 75.0, y = 44.5, name = "Innkeeper Kauth", subZone = "Camp Mojache", f = "H"}
	},
	["Desolace"] = {
		{x = 36.5, y = 7.8, name = "Innkeeper Sikewa", subZone = "Nijel's Point", f = "A"},
		{x = 23.0, y = 70.0, name = "Innkeeper Greul", subZone = "Shadowprey Village", f = "H"}
	},
	["The Barrens"] = {
		{x = 51.5, y = 30.2, name = "Innkeeper Boorand", subZone = "Crossroads", f = "H"},
		{x = 62.5, y = 37.5, name = "Innkeeper Wiley", subZone = "Ratchet", f = "N"},
		{x = 44.5, y = 59.2, name = "Innkeeper Janene", subZone = "Camp Taurajo", f = "H"}
	},

	-- Neutral
	["Stranglethorn Vale"] = {{x = 26.9, y = 77.2, name = "Innkeeper Skindle", subZone = "Booty Bay", f = "N"}},
	["Tanaris"] = {{x = 52.5, y = 27.0, name = "Innkeeper Vizzie", subZone = "Gadgetzan", f = "N"}},
	["Winterspring"] = {{x = 59.6, y = 51.2, name = "Innkeeper Vizzie", subZone = "Everlook", f = "N"}},

	-- TBC Outland
	["Hellfire Peninsula"] = {
		{x = 54.3, y = 63.5, name = "Floyd Pinkus", subZone = "Honor Hold", f = "A"},
		{x = 56.7, y = 37.5, name = "Innkeeper Bazil Olof'taz", subZone = "Thrallmar", f = "H"},
		{x = 23.4, y = 36.5, name = "Caregiver Inaara", subZone = "Temple of Telhamat", f = "A"},
		{x = 26.8, y = 59.9, name = "Caregiver Topher Loaal", subZone = "Falcon Watch", f = "H"}
	},
	["Zangarmarsh"] = {
		{x = 78.5, y = 63.0, name = "Innkeeper Coryth Stoktron", subZone = "Cenarion Refuge", f = "N"},
		{x = 41.8, y = 28.8, name = "Innkeeper Kerp", subZone = "Telredor", f = "A"},
		{x = 85.2, y = 54.8, name = "Caregiver Ophera Windfury", subZone = "Swamprat Post", f = "H"},
		{x = 32.4, y = 49.8, name = "Caregiver Isel", subZone = "Zabra'jin", f = "H"}
	},
	["Terokkar Forest"] = {
		{x = 57.2, y = 53.2, name = "Innkeeper Biribi", subZone = "Allerian Stronghold", f = "A"},
		{x = 48.9, y = 45.1, name = "Innkeeper Grilka", subZone = "Stonebreaker Hold", f = "H"}
	},
	["Nagrand"] = {
		{x = 54.2, y = 75.5, name = "Caregiver Mumra", subZone = "Telaar", f = "A"},
		{x = 55.4, y = 37.2, name = "Caregiver Lashim", subZone = "Garadar", f = "H"}
	},
	["Blade's Edge Mountains"] = {
		{x = 61.9, y = 68.2, name = "Innkeeper Shaunessy", subZone = "Sylvanaar", f = "A"},
		{x = 52.0, y = 54.0, name = "Innkeeper Remi Dodoso", subZone = "Thunderlord Stronghold", f = "H"},
		{x = 62.5, y = 38.5, name = "Mingo", subZone = "Mok'Nathal Village", f = "H"},
		{x = 37.5, y = 61.5, name = "Eyonix", subZone = "Evergrove", f = "N"}
	},
	["Netherstorm"] = {
		{x = 32.5, y = 64.0, name = "Innkeeper Daresha", subZone = "Area 52", f = "N"},
		{x = 44.2, y = 36.5, name = "Innkeeper Haelthol", subZone = "The Stormspire", f = "N"}
	},
	["Shadowmoon Valley"] = {
		{x = 37.0, y = 58.5, name = "Innkeeper Drix'l", subZone = "Wildhammer Stronghold", f = "A"},
		{x = 30.2, y = 28.0, name = "Caregiver Abigail", subZone = "Shadowmoon Village", f = "H"},
		{x = 62.5, y = 28.5, name = "Dreg Cloudsweeper", subZone = "Altar of Sha'tar", f = "N"}
	},
	["Shattrath City"] = {
		{x = 28.1, y = 48.9, name = "Innkeeper Haelthol", subZone = "Aldor Rise", f = "N"},
		{x = 56.5, y = 81.5, name = "Innkeeper Haelthol", subZone = "Scryer's Tier", f = "N"}
	}
}

local TRAINER_LOCATIONS = {
	["Teldrassil"] = {{x = 55.2, y = 56.8, name = "Byancie", subZone = "Dolanaar", f = "A"}},
	["Darnassus"] = {{x = 55.0, y = 24.0, name = "Dannelor", subZone = "Craftsmen's Terrace", f = "A"}},
	["Elwynn Forest"] = {{x = 43.5, y = 65.5, name = "Michelle Belle", subZone = "Goldshire", f = "A"}},
	["Stormwind City"] = {{x = 52.2, y = 45.5, name = "Shaina Fuller", subZone = "Cathedral Square", f = "A"}},
	["Dun Morogh"] = {{x = 47.2, y = 52.5, name = "Thamner Pol", subZone = "Kharanos", f = "A"}},
	["Ironforge"] = {{x = 54.5, y = 58.5, name = "Nissa Firestone", subZone = "The Great Forge", f = "A"}},
	["Wetlands"] = {{x = 10.5, y = 59.2, name = "Fremal Doohickey", subZone = "Menethil Harbor", f = "A"}},

	["Tirisfal Glades"] = {{x = 61.8, y = 52.5, name = "Nurse Neela", subZone = "Brill", f = "H"}},
	["Undercity"] = {{x = 73.0, y = 55.0, name = "Mary Edras", subZone = "The Rogues' Quarter", f = "H"}},
	["Mulgore"] = {{x = 46.5, y = 58.2, name = "Vira Younghoof", subZone = "Bloodhoof Village", f = "H"}},
	["Thunder Bluff"] = {{x = 29.5, y = 21.5, name = "Pand Stonebinder", subZone = "Spirit Rise", f = "H"}},
	["Durotar"] = {{x = 54.2, y = 42.0, name = "Rawrk", subZone = "Razor Hill", f = "H"}},
	["Orgrimmar"] = {{x = 34.0, y = 84.5, name = "Arnok", subZone = "Valley of Spirits", f = "H"},

	},

	["Dustwallow Marsh"] = {
		{x = 67.8, y = 48.9, name = "Doctor Gustaf VanHowzen", subZone = "Theramore Isle", f = "A"},
		{x = 36.0, y = 30.5, name = "Balai Lok'wein", subZone = "Brackenwall Village", f = "H"}
	},
	["Arathi Highlands"] = {
		{x = 27.0, y = 58.5, name = "Deneb Walker", subZone = "Stromgarde Keep", f = "A"},
		{x = 73.5, y = 36.5, name = "Doctor Gregory Victor", subZone = "Hammerfall", f = "H"}
	},

	["Hellfire Peninsula"] = {
		{x = 54.6, y = 63.6, name = "Burko", subZone = "Honor Hold", f = "A"},
		{x = 56.6, y = 36.7, name = "Aresella", subZone = "Thrallmar", f = "H"}
	},
	["Zangarmarsh"] = {{x = 78.5, y = 62.5, name = "Fera", subZone = "Cenarion Refuge", f = "N"}},
	["Terokkar Forest"] = {
		{x = 57.5, y = 52.8, name = "Anchorite Ensham", subZone = "Allerian Stronghold", f = "A"},
		{x = 49.0, y = 45.8, name = "Apothecary Antonivich", subZone = "Stonebreaker Hold", f = "H"}
	},
	["Shattrath City"] = {{x = 64.5, y = 42.5, name = "Mildred Fletcher", subZone = "Lower City", f = "N"}}
}

local COOKING_LOCATIONS = {
	["Elwynn Forest"] = {{x = 44.5, y = 66.2, name = "Tomas", subZone = "Goldshire", f = "A"}},
	["Stormwind City"] = {{x = 77.6, y = 53.0, name = "Stephen Ryback", subZone = "Trade District", f = "A"}},
	["Ironforge"] = {{x = 60.1, y = 36.5, name = "Daryl Riknussun", subZone = "The Great Forge", f = "A"}},
	["Dun Morogh"] = {{x = 47.5, y = 52.8, name = "Gremlock Pilsnor", subZone = "Kharanos", f = "A"}},
	["Darnassus"] = {{x = 62.5, y = 22.0, name = "Alegorn", subZone = "Craftsmen's Terrace", f = "A"}},
	["Teldrassil"] = {{x = 57.0, y = 61.5, name = "Zarrin", subZone = "Dolanaar", f = "A"}},
	["Darkshore"] = {{x = 37.8, y = 41.5, name = "Laird", subZone = "Auberdine", f = "A"}},

	["Undercity"] = {{x = 62.5, y = 43.5, name = "Eunice Burch", subZone = "Trade Quarter", f = "H"}},
	["Tirisfal Glades"] = {{x = 61.5, y = 52.0, name = "Ronald Burch", subZone = "Brill", f = "H"}},
	["Thunder Bluff"] = {{x = 51.0, y = 53.0, name = "Pyall Silentstride", subZone = "Middle Rise", f = "H"}},
	["Mulgore"] = {{x = 46.2, y = 57.8, name = "Aska Mistrunner", subZone = "Bloodhoof Village", f = "H"}},
	["Orgrimmar"] = {{x = 57.5, y = 53.5, name = "Zamja", subZone = "Valley of Honor", f = "H"}},
	["Durotar"] = {{x = 51.5, y = 41.8, name = "Drac Roughcut", subZone = "Razor Hill", f = "H"}},

	["Dustwallow Marsh"] = {
		{x = 66.8, y = 45.8, name = "Craig Nollward", subZone = "Theramore Isle", f = "A"},
		{x = 35.5, y = 30.8, name = "Ogg'marr", subZone = "Brackenwall Village", f = "H"}
	},
	["The Barrens"] = {
		{x = 51.8, y = 30.5, name = "Drac Roughcut", subZone = "Crossroads", f = "H"},
		{x = 62.8, y = 37.8, name = "Grub", subZone = "Ratchet", f = "N"}
	},
	["Stranglethorn Vale"] = {{x = 26.8, y = 77.5, name = "Kelsey Yance", subZone = "Booty Bay", f = "N"}},
	["Tanaris"] = {{x = 52.8, y = 28.0, name = "Dirge Quikcleave", subZone = "Gadgetzan", f = "N"}},

	["Hellfire Peninsula"] = {
		{x = 54.1, y = 63.8, name = "Gaston", subZone = "Honor Hold", f = "A"},
		{x = 56.4, y = 37.0, name = "Baxter", subZone = "Thrallmar", f = "H"}
	},
	["Zangarmarsh"] = {{x = 78.2, y = 63.0, name = "Naka", subZone = "Cenarion Refuge", f = "N"}},
	["Terokkar Forest"] = {
		{x = 57.0, y = 53.5, name = "Allison", subZone = "Allerian Stronghold", f = "A"},
		{x = 49.5, y = 46.2, name = "Baxter", subZone = "Stonebreaker Hold", f = "H"}
	},
	["Nagrand"] = {
		{x = 53.6, y = 75.2, name = "Uriku", subZone = "Telaar", f = "A"},
		{x = 56.5, y = 38.2, name = "Nula the Butcher", subZone = "Garadar", f = "H"}
	},
	["Shattrath City"] = {{x = 61.5, y = 15.0, name = "Jack Trapper", subZone = "Lower City", f = "N"}}
}

------------------------------------------------------------
-- Pin creation helpers (use WorldMapFrame canvas when available)
------------------------------------------------------------
local function GetMapCanvas()
	if not WorldMapFrame then
		return nil
	end
	if WorldMapFrame.GetCanvas then
		return WorldMapFrame:GetCanvas()
	end
	-- Fallback if API changes
	return WorldMapFrame.ScrollContainer or WorldMapFrame
end

local function CreatePinBase(size, texturePath, color, glowColor, frameLevel, tooltipTitle, tooltipColor, extraLine)
	local canvas = GetMapCanvas()
	if not canvas then
		return nil
	end

	local pin = CreateFrame("Frame", nil, canvas)
	pin:SetSize(size, size)
	pin:SetFrameStrata("HIGH")
	pin:SetFrameLevel(frameLevel)
	pin:SetHitRectInsets(4, 4, 4, 4)

	local icon = pin:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(texturePath)
	icon:SetVertexColor(color[1], color[2], color[3], color[4])
	pin.icon = icon

	local glow = pin:CreateTexture(nil, "BACKGROUND")
	glow:SetSize(size + 8, size + 8)
	glow:SetPoint("CENTER")
	glow:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu\\swordglow")
	glow:SetVertexColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4])
	glow:SetBlendMode("ADD")
	pin.glow = glow

	pin:EnableMouse(true)
	pin:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(tooltipTitle, tooltipColor[1], tooltipColor[2], tooltipColor[3])
		if self.pinData then
			if self.pinData.name and self.pinData.name ~= "" then
				GameTooltip:AddLine(self.pinData.name, 1, 1, 1)
			end
			if self.pinData.subZone and self.pinData.subZone ~= "" then
				GameTooltip:AddLine(self.pinData.subZone, 0.7, 0.7, 0.7)
			end
			if self.pinData.description and self.pinData.description ~= "" and self.pinData.description ~= "fire" then
				GameTooltip:AddLine(self.pinData.description, 0.7, 0.7, 0.7)
			end
			if self.pinData.noMount then
				GameTooltip:AddLine("Indoor/No Mount", 0.8, 0.4, 0.4)
			end
		end
		if extraLine then
			GameTooltip:AddLine(extraLine, 0.7, 0.7, 0.7)
		end
		GameTooltip:Show()
		self.icon:SetVertexColor(0.3, 0.3, 0.3, 1.0)
	end)
	pin:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		self.icon:SetVertexColor(color[1], color[2], color[3], color[4])
	end)

	pin:Hide()
	return pin
end

local function CreateFirePin()
	return CreatePinBase(
		MAP_PIN_SIZE, FIRE_ICON,
		{0.1, 0.1, 0.1, 0.9},
		{1.0, 0.5, 0.1, 0.3},
		2000,
		"Campfire", {1, 0.6, 0.2},
		nil
	)
end

local function CreateInnPin()
	local pin = CreatePinBase(
		INN_PIN_SIZE, INN_ICON,
		{0.1, 0.1, 0.1, 0.9},
		{0.9, 0.3, 0.3, 0.3},
		2001,
		"Innkeeper", {0.9, 0.3, 0.3},
		"Heals Anguish"
	)
	if pin then
		pin:SetHitRectInsets(3, 3, 3, 3)
		pin.glow:SetSize(INN_PIN_SIZE + 6, INN_PIN_SIZE + 6)
	end
	return pin
end

local function CreateTrainerPin()
	return CreatePinBase(
		MAP_PIN_SIZE, TRAINER_ICON,
		{0.1, 0.1, 0.1, 0.9},
		{0.8, 0.2, 0.2, 0.3},
		2002,
		"First Aid Trainer", {0.8, 0.2, 0.2},
		nil
	)
end

local function CreateCookingPin()
	return CreatePinBase(
		MAP_PIN_SIZE, COOKING_ICON,
		{0.1, 0.1, 0.1, 0.9},
		{0.9, 0.6, 0.2, 0.3},
		2003,
		"Cooking Trainer", {0.9, 0.6, 0.2},
		"Reduces Hunger"
	)
end

------------------------------------------------------------
-- Pin pool management
------------------------------------------------------------
local function AcquirePin(pool, creator)
	local pin = table.remove(pool)
	if not pin then
		pin = creator()
	end
	return pin
end

local function ReleasePin(pool, pin)
	if not pin then
		return
	end
	pin:Hide()
	pin:ClearAllPoints()
	pin.pinData = nil
	table.insert(pool, pin)
end

local function ClearAllPins()
	for _, pin in ipairs(activeFirePins) do
		ReleasePin(firePinPool, pin)
	end
	for _, pin in ipairs(activeInnPins) do
		ReleasePin(innPinPool, pin)
	end
	for _, pin in ipairs(activeTrainerPins) do
		ReleasePin(trainerPinPool, pin)
	end
	for _, pin in ipairs(activeCookingPins) do
		ReleasePin(cookingPinPool, pin)
	end

	activeFirePins, activeInnPins, activeTrainerPins, activeCookingPins = {}, {}, {}, {}
end

local function GetNormalizedCoord(coord)
	return (tonumber(coord) or 0) / 100
end

------------------------------------------------------------
-- Pin update
------------------------------------------------------------
local function UpdateMapPins()
	ClearAllPins()

	if not GetSetting("showSurvivalIcons", false) then
		return
	end

	if not WorldMapFrame or not WorldMapFrame:IsShown() then
		return
	end

	local canvas = GetMapCanvas()
	if not canvas then
		return
	end

	local canvasWidth = canvas.GetWidth and canvas:GetWidth() or 0
	local canvasHeight = canvas.GetHeight and canvas:GetHeight() or 0
	if canvasWidth <= 0 or canvasHeight <= 0 then
	-- Canvas not ready yet; try again shortly.
		C_Timer.After(0.1, UpdateMapPins)
		return
	end

	local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() or nil
	if not mapID then
		return
	end

	local mapInfo = C_Map.GetMapInfo(mapID)
	if not mapInfo or not mapInfo.name then
		return
	end
	local zoneName = mapInfo.name

	-- Fires from FireDB
	if CC and CC.GetFireLocations then
		local fires = CC.GetFireLocations(zoneName)
		if fires then
			for _, fire in ipairs(fires) do
				local pin = AcquirePin(firePinPool, CreateFirePin)
				if pin then
					pin.pinData = fire
					local fx = GetNormalizedCoord(fire.x)
					local fy = GetNormalizedCoord(fire.y)
					pin:SetParent(canvas)
					pin:SetPoint("CENTER", canvas, "TOPLEFT", fx * canvasWidth, -fy * canvasHeight)
					pin:Show()
					table.insert(activeFirePins, pin)
				end
			end
		end
	end

	-- Inns
	local zoneInns = INN_LOCATIONS[zoneName]
	if zoneInns then
		for _, inn in ipairs(zoneInns) do
			if ShouldShowForFaction(inn.f or "N") then
				local pin = AcquirePin(innPinPool, CreateInnPin)
				if pin then
					pin.pinData = inn
					local ix = GetNormalizedCoord(inn.x)
					local iy = GetNormalizedCoord(inn.y)
					pin:SetParent(canvas)
					pin:SetPoint("CENTER", canvas, "TOPLEFT", ix * canvasWidth, -iy * canvasHeight)
					pin:Show()
					table.insert(activeInnPins, pin)
				end
			end
		end
	end

	-- First Aid Trainers
	local zoneTrainers = TRAINER_LOCATIONS[zoneName]
	if zoneTrainers then
		for _, trainer in ipairs(zoneTrainers) do
			if ShouldShowForFaction(trainer.f or "N") then
				local pin = AcquirePin(trainerPinPool, CreateTrainerPin)
				if pin then
					pin.pinData = trainer
					local tx = GetNormalizedCoord(trainer.x)
					local ty = GetNormalizedCoord(trainer.y)
					pin:SetParent(canvas)
					pin:SetPoint("CENTER", canvas, "TOPLEFT", tx * canvasWidth, -ty * canvasHeight)
					pin:Show()
					table.insert(activeTrainerPins, pin)
				end
			end
		end
	end

	-- Cooking Trainers
	local zoneCooking = COOKING_LOCATIONS[zoneName]
	if zoneCooking then
		for _, cooking in ipairs(zoneCooking) do
			if ShouldShowForFaction(cooking.f or "N") then
				local pin = AcquirePin(cookingPinPool, CreateCookingPin)
				if pin then
					pin.pinData = cooking
					local cx = GetNormalizedCoord(cooking.x)
					local cy = GetNormalizedCoord(cooking.y)
					pin:SetParent(canvas)
					pin:SetPoint("CENTER", canvas, "TOPLEFT", cx * canvasWidth, -cy * canvasHeight)
					pin:Show()
					table.insert(activeCookingPins, pin)
				end
			end
		end
	end

	local totalPins = #activeFirePins + #activeInnPins + #activeTrainerPins + #activeCookingPins
	if totalPins > 0 then
		Debug(("Showing %d survival pins for %s (Fires: %d, Inns: %d, Trainers: %d, Cooking: %d)"):format(
			totalPins, zoneName, #activeFirePins, #activeInnPins, #activeTrainerPins, #activeCookingPins
		))
	end
end

------------------------------------------------------------
-- Map checkbox
------------------------------------------------------------
local mapCheckbox = nil

local function CreateMapCheckbox()
	if mapCheckbox or not WorldMapFrame then
		return
	end

	local parent = WorldMapFrame.BorderFrame or WorldMapFrame
	mapCheckbox = CreateFrame("CheckButton", "CozierCampsSurvivalIconsCheckbox", parent, "UICheckButtonTemplate")
	mapCheckbox:SetSize(24, 24)

	-- Try to anchor somewhere sensible in modern Retail
	if WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.HaveMinimizeButton then
		mapCheckbox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -60, -2)
	else
		mapCheckbox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -60, -30)
	end

	mapCheckbox.text = mapCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	mapCheckbox.text:SetPoint("RIGHT", mapCheckbox, "LEFT", -2, 0)
	mapCheckbox.text:SetText("Survival Icons")
	mapCheckbox.text:SetTextColor(0.9, 0.7, 0.4)

	mapCheckbox:SetScript("OnClick", function(self)
		SetSetting("showSurvivalIcons", self:GetChecked() and true or false)
		UpdateMapPins()
	end)

	mapCheckbox:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Survival Icons", 1, 0.8, 0.4)
		GameTooltip:AddLine("Toggle display of campfires, inns, first aid trainers, and cooking trainers on the map.", 1, 1, 1, true)
		GameTooltip:Show()
	end)

	mapCheckbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function UpdateCheckboxVisibility()
	if not mapCheckbox then
		return
	end

	-- Preserve your original intent (show checkbox when these systems are relevant)
	local showCheckbox = GetSetting("temperatureEnabled", false) or GetSetting("exhaustionEnabled", false)
	if showCheckbox then
		mapCheckbox:Show()
		mapCheckbox:SetChecked(GetSetting("showSurvivalIcons", false))
	else
		mapCheckbox:Hide()
	end
end

------------------------------------------------------------
-- Midnight-safe map change detection
-- (No OnMapChanged script; hook SetMapID and also watch mapID while map is open)
------------------------------------------------------------
local watcher = CreateFrame("Frame")
local lastMapID = nil
local lastShown = false

local function ForceUpdateSoon()
	C_Timer.After(0.05, UpdateMapPins)
end

local function InstallWorldMapHooks()
	if not WorldMapFrame then
		return false
	end

	CreateMapCheckbox()

	-- Show/hide hooks are safe
	if WorldMapFrame.HookScript then
		WorldMapFrame:HookScript("OnShow", function()
			UpdateCheckboxVisibility()
			lastShown = true
			lastMapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() or nil
			ForceUpdateSoon()
		end)

		WorldMapFrame:HookScript("OnHide", function()
			lastShown = false
			ClearAllPins()
		end)
	end

	-- Hook mapID changes safely (this replaces the broken OnMapChanged usage)
	if WorldMapFrame.SetMapID then
		hooksecurefunc(WorldMapFrame, "SetMapID", function()
			if WorldMapFrame:IsShown() and GetSetting("showSurvivalIcons", false) then
				ForceUpdateSoon()
			end
		end)
	end

	return true
end

-- Poll mapID while the map is open (covers search, zoom, clicking other maps, etc.)
watcher:SetScript("OnUpdate", function(_, elapsed)
	if not WorldMapFrame or not WorldMapFrame.IsShown then
		return
	end
	if not WorldMapFrame:IsShown() then
		return
	end
	if not GetSetting("showSurvivalIcons", false) then
		return
	end

	local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() or nil
	if mapID and mapID ~= lastMapID then
		lastMapID = mapID
		ForceUpdateSoon()
	end
end)

------------------------------------------------------------
-- Initialization
------------------------------------------------------------
local overlayFrame = CreateFrame("Frame")
overlayFrame:RegisterEvent("PLAYER_LOGIN")

overlayFrame:SetScript("OnEvent", function(_, event)
	if event ~= "PLAYER_LOGIN" then
		return
	end

	-- WorldMapFrame may not be ready instantly on login in some UI states
	local tries = 0
	local ticker
	ticker = C_Timer.NewTicker(0.5, function()
		tries = tries + 1
		if InstallWorldMapHooks() then
			ticker:Cancel()
			Debug("MapOverlay hooks installed (Midnight-safe)")
		elseif tries >= 10 then
			ticker:Cancel()
			Debug("MapOverlay: WorldMapFrame not ready; pins will not display until map loads")
		end
	end)
end)

------------------------------------------------------------
-- Expose functions
------------------------------------------------------------
CC.UpdateMapPins = UpdateMapPins
CC.UpdateSurvivalIcons = UpdateMapPins
CC.ClearMapPins = ClearAllPins
CC.UpdateMapCheckboxVisibility = UpdateCheckboxVisibility
