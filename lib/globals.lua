--[[ KEEP AT TOP JUST CUS I LIKE IT HERE ]]--
-- TODO: these need to be split into more files to make globals easier to manage
-- i.e. _globals/colors.lua, _globals/icons.lua, etc...
--[[ Addon defaults ]]--
Addon = {
	version = "0.0.1",
	name = "Cultivation",

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

-- Debug category to setting mapping (optimization for Debug function)
DEBUG_SETTINGS = {
	general = "debug_general",
	hunger = "debug_hunger",
	thirst = "debug_thirst",
	database = "debug_database",
	panel = "show_debug_panel"
}

DEFAULT_SETTINGS = {
	debug_general = false,
	show_debug_panel = false,
	debug_database = false,
	debug_hunger = false,
	debug_thirst = false,
}

-- Initialize character-specific saved variables
DEFAULT_CHAR_SETTINGS = {
	hunger_current = 0,
	hunger_rate = 0,
	hunger_timeToStarveInHours = 1,

	thirst_current = 0,
	thirst_rate = 0,
	thirst_timeToDehydrationInHours = 1 / 3,
}
--[[ END DEFAULTS ]]--

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

EATING_AURAS = {
	["Food"] = true,
	["Refreshment"] = true,
	["Food & Drink"] = true,
}

-- Meter configuration
METER_WIDTH = 300
METER_HEIGHT = 32
METER_FONT_SIZE = METER_HEIGHT / 2
METER_SPACING = 4
METER_PADDING = 2
ICON_SIZE = METER_FONT_SIZE + METER_SPACING

TEXTURES = {
	default = "Interface\\TargetingFrame\\UI-StatusBar",
	raid = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill", -- Blizzard Raid
	flat = "Interface\\Buttons\\WHITE8x8", -- Flat/Solid
	gloss = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar", -- Gloss
	minimal = "Interface\\TARGETINGFRAME\\UI-TargetingFrame-BarFill", -- Minimalist
	tooltip = "Interface\\Tooltips\\UI-Tooltip-Background", -- Otravi-like
	striped = "Interface\\RaidFrame\\Raid-Bar-Resource-Fill", -- Striped
}

FONTS = {
	Default = nil,
	Friz = "Fonts\\FRIZQT__.TTF",
	Arial = "Fonts\\ARIALN.TTF",
	Skurri = "Fonts\\skurri.TTF",
	Morpheus = "Fonts\\MORPHEUS.TTF",
	TwoThousand = "Fonts\\2002.TTF",
	TwoThousandBold = "Fonts\\2002B.TTF",
	ExpressWay = "Fonts\\EXPRESSWAY.TTF",
	NimrodMT = "Fonts\\NIM_____.TTF",
}

ICONS = {
	food = "Interface\\AddOns\\Cultivation\\assets\\food.tga",
	drink = "Interface\\AddOns\\Cultivation\\assets\\drink.tga"
}
