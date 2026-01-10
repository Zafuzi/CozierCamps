local config = {
	name = "DebugPanel",
	width = 400,
	height = 300,
	color = GUI_COLORS.headerColor,
	backgroundColor = GUI_COLORS.cardBg,
	borderColor = GUI_COLORS.cardBorder,
}

local padding = 16
DebugPanel = OpenModal(config.name, config.width, config.height)
DebugPanel:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Style scrollbar
local scrollFrame = DebugPanel.scrollFrame
local scrollBar = scrollFrame.ScrollBar
if scrollBar then
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -21, -5)
	scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -21, 21)
end

local body = CreateFrame('SimpleHTML', nil, scrollFrame);
body:SetSize(scrollFrame:GetSize())
body:SetFont("h1", FONTS.Friz, 18, "");
body:SetFont("h2", FONTS.Friz, 16, "");
body:SetFont("h3", FONTS.Friz, 14, "");
body:SetFont("p", FONTS.Friz, 12, "");
body:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
body:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, 0)
DebugPanel.scrollFrame:SetScrollChild(body)

local bodyHTML = "<html><body>"
local bodyEND = "</body></html>"

local bodyContent = ""

local function addToBody(string)
	bodyContent = bodyContent .. string
end

local function h1(string, color)
	color = tostring(color or COLORS.ADDON)
	addToBody("<h1>" .. color .. string .. "|r</h1>")
end

local function h2(string, color)
	color = tostring(color or COLORS.ADDON)
	addToBody("<h2>" .. color .. string .. "|r</h2>")
end

local function h3(string, color)
	color = tostring(color or COLORS.ADDON)
	addToBody("<h3>" .. color .. string .. "|r</h3>")
end

local function p(string, color)
	color = tostring(color or COLORS.ADDON)
	addToBody("<p>" .. color .. string .. "|r</p>")
end

local function br()
	addToBody("<br/>")
end

local function hr()
	addToBody("<hr/>")
end

DebugPanel:SetScript("OnShow", function(self)
	PlaySound(808)
end)

DebugPanel:SetScript("OnUpdate", function(self, elapsed)
	bodyContent = ""

	self:debug_hunger()
	self:debug_thirst()
	self:debug_database()

	body:SetText(bodyHTML .. bodyContent .. bodyEND)
end)

DebugPanel.debug_database = function()
	if GetSetting("debug_database") then
		br()
		h2("DB", COLORS.WARNING)

		for k, v in pairs(Addon.DB) do
			p(tostring(k) .. ": " .. tostring(v))
		end

		br()
		h2("CharDB", COLORS.WARNING)

		for k, v in pairs(Addon.CharDB) do
			p(tostring(k) .. ": " .. tostring(v))
		end
	end
end

DebugPanel.debug_hunger = function()
	if not Addon.hungerCache then
		h2("Missing hungerCache", COLORS.ERROR)
		return
	end

	if GetSetting("debug_hunger") then
		p("Hunger: " .. floatToTwoString(Addon.hungerCache.current, 3) .. "%", COLORS.HUNGER)
	end
end

DebugPanel.debug_thirst = function()
	if not Addon.thirstCache then
		h2("Missing thirstCache", COLORS.ERROR)
		return
	end

	if GetSetting("debug_thirst") then
		p("Thirst: " .. floatToTwoString(Addon.thirstCache.current, 3) .. "%", COLORS.THIRST)
	end
end

DebugPanel:SetScript("OnEvent", function(self, event, arg)
	if event == "PLAYER_ENTERING_WORLD" and GetSetting("show_debug_panel") then
		DebugPanel:Show()
	end
end)