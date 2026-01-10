-- Shared constants for colors (reduces string allocations)
COLORS = {
	ADDON = "|cffFAFAFA",
	PROXIMITY = "|cff88FF88",
	EXHAUSTION = "|cffFFAA88",
	ANGUISH = "|cffFF6688",
	HUNGER = "|cffFFBB44",
	THIRST = "|cff0074c7",
	TEMPERATURE = "|cffFFCC55",
	WARNING = "|cffFF6600",
	SUCCESS = "|cff00FF00",
	ERROR = "|cffDD0033"
}

-- Debug category to setting mapping (optimization for Debug function)
DEBUG_SETTINGS = {
	general = "debug_general",
	hunger = "debug_hunger",
	database = "debug_database",
}

-- Debug category to color mapping
DEBUG_COLORS = {
	general = COLORS.ADDON,
	proximity = COLORS.PROXIMITY,
	exhaustion = COLORS.EXHAUSTION,
	Anguish = COLORS.ANGUISH,
	hunger = COLORS.HUNGER,
	thirst = COLORS.THIRST,
	temperature = COLORS.TEMPERATURE
}

-- Addon defaults
DEFAULT_SETTINGS = {
	debug_general = true,
	debug_database = true,
	debug_hunger = true,
}

-- Initialize character-specific saved variables
DEFAULT_CHAR_SETTINGS = {
	hunger_current = 0,
	hunger_rate = 0,
	hunger_timeToStarveInHours = 1,
}

EATING_AURAS = {
	["Food"] = true,
	["Refreshment"] = true,
	["Food & Drink"] = true,
}

-- Meter configuration
METER_WIDTH = 150
METER_HEIGHT = 16
METER_SPACING = 4
METER_PADDING = 2
ICON_SIZE = 14

-- Available bar textures
BAR_TEXTURES = {
	"Interface\\TargetingFrame\\UI-StatusBar", -- Blizzard default
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
BAR_FONTS = {
	{ name = "Default", path = nil },
	{ name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
	{ name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ name = "Skurri", path = "Fonts\\skurri.TTF" },
	{ name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
	{ name = "2002", path = "Fonts\\2002.TTF" },
	{ name = "2002 Bold", path = "Fonts\\2002B.TTF" },
	{ name = "Express Way", path = "Fonts\\EXPRESSWAY.TTF" },
	{ name = "Nimrod MT", path = "Fonts\\NIM_____.TTF" }
}

-- Available bar fonts (index 1 = inherit/default, no override)
FONTS = {
	Friz = "Fonts\\FRIZQT__.TTF"
	--[[
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
	--]]
}

Addon = {
	version = "0.0.1",
	name = "CozierCamps",

	isLoaded = false,

	callbacks = {},

	playerCache = {
		name = "Player",
		level = 0,
		health = 0,
		speed = 0,
		resting = false,
		eating = false,
		activity = "idle"
	},
}

