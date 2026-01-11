local config = {
	name = "DebugPanel",
	width = 400,
	height = 300,
	color = GUI_COLORS.headerColor,
	backgroundColor = GUI_COLORS.cardBg,
	borderColor = GUI_COLORS.cardBorder,
}

local padding = 16
DebugPanel = OpenModal(config.name, config.width, config.height, UIParent, { isScrollable = true })
DebugPanel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
DebugPanel:RegisterEvent("PLAYER_ENTERING_WORLD")
DebugPanel:SetIgnoreParentAlpha(true)

-- Style scrollbar
local scrollFrame = DebugPanel.scrollFrame

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
local bodyEND = "<br/><br/></body></html>"

local bodyContent = ""

local function addToBody(string)
	bodyContent = bodyContent .. string
end

local function h1(string, color)
	color = tostring(color or COLORS.WHITE)
	addToBody("<h1>" .. color .. string .. "|r</h1>")
end

local function h2(string, color)
	color = tostring(color or COLORS.WHITE)
	addToBody("<h2>" .. color .. string .. "|r</h2>")
end

local function h3(string, color)
	color = tostring(color or COLORS.WHITE)
	addToBody("<h3>" .. color .. string .. "|r</h3>")
end

local function p(string, color)
	color = tostring(color or COLORS.WHITE)
	addToBody("<p>" .. color .. string .. "|r</p>")
end

local function br()
	addToBody("<br/>")
end

local function hr()
	addToBody("<hr/>")
end

local function renderTable(title, table, color)
	color = color or COLORS.ADDON
	br()
	h2(title, color)
	for k, v in pairs(table) do
		p(Dump(k) .. " = " .. Dump(v), COLORS.TABLE)
	end
end

DebugPanel:SetScript("OnShow", function(self)
	PlaySound(808)
end)

DebugPanel:SetScript("OnUpdate", function(self, elapsed)
	bodyContent = ""

	self:debug_hunger()
	self:debug_thirst()
	self:debug_cultivation()
	self:debug_player()
	self:debug_database()

	body:SetText(bodyHTML .. bodyContent .. bodyEND)
end)

DebugPanel.debug_player = function()
	if GetSetting("debug_player") then
		renderTable("PlayerCache", Addon.playerCache, COLORS.WHITE)
	end
end

DebugPanel.debug_database = function()
	if GetSetting("debug_database") then
		renderTable("Settings", Addon.DB, COLORS.EXHAUSTION)
	end
end

DebugPanel.debug_hunger = function()
	if not Addon.hungerCache then
		h2("Missing hungerCache", COLORS.ERROR)
		return
	end

	if GetSetting("debug_hunger") then
		renderTable("Hunger", Addon.hungerCache, COLORS.HUNGER)
	end
end

DebugPanel.debug_thirst = function()
	if not Addon.thirstCache then
		h2("Missing thirstCache", COLORS.ERROR)
		return
	end

	if GetSetting("debug_thirst") then
		renderTable("Thirst", Addon.thirstCache, COLORS.THIRST)
	end
end

DebugPanel.debug_cultivation = function()
	if not Addon.cultivationCache then
		h2("Missing cultivationCache", COLORS.ERROR)
		return
	end

	if GetSetting("debug_cultivation") then
		renderTable("Cultivation", Addon.cultivationCache, COLORS.CULTIVATION)
	end
end

DebugPanel:SetScript("OnEvent", function(self, event, arg)
	if event == "PLAYER_ENTERING_WORLD" and GetSetting("debug_panel") then
		DebugPanel:Show()
	end
end)
