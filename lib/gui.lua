-- Color scheme - Black/Slate with Orange accents
GUI_COLORS = {
	bg = { 0.06, 0.06, 0.08, 0.97 },
	headerBg = { 0.08, 0.08, 0.10, 1 },
	primary = { 1.0, 0.6, 0.2, 1 }, -- Orange
	primary_dark = { 0.8, 0.45, 0.1, 1 }, -- Darker orange
	primary_glow = { 1.0, 0.7, 0.3, 0.3 }, -- Orange glow
	text = { 0.9, 0.9, 0.9, 1 },
	textDim = { 0.55, 0.55, 0.55, 1 },
	success = { 0.4, 0.9, 0.4, 1 },
	warning = { 1.0, 0.8, 0.2, 1 },
	danger = { 0.9, 0.3, 0.3, 1 },
	cardBg = { 0.09, 0.09, 0.11, 0.95 },
	cardBorder = { 0.18, 0.18, 0.2, 1 },
	sliderBg = { 0.12, 0.12, 0.14, 1 },
	sliderFill = { 1.0, 0.6, 0.2, 0.9 }, -- Orange
	ember = { 1.0, 0.4, 0.1, 1 }, -- Ember orange
	Anguish = { 0.9, 0.3, 0.3, 1 }, -- Anguish red
	tabInactive = { 0.1, 0.1, 0.12, 1 },
	tabActive = { 0.15, 0.15, 0.18, 1 }
}

--- @param name string
--- @param width number
--- @param height number
--- @param parent any
function OpenModal(name, width, height, parent)
	name = name or "Modal"
	name = "Cultivation - " .. name
	parent = parent or UIParent
	local PFrame = CreateFrame("Frame", name, parent, "BackdropTemplate")

	PFrame:SetSize(width or 100, height or 100)
	PFrame:SetPoint("CENTER", parent, "CENTER", 0, 0)
	PFrame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 2
	})
	PFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
	PFrame:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)
	PFrame:SetMovable(true)
	PFrame:EnableMouse(true)
	PFrame:RegisterForDrag("LeftButton")
	PFrame:SetScript("OnDragStart", PFrame.StartMoving)
	PFrame:SetScript("OnDragStop", PFrame.StopMovingOrSizing)

	PFrame:SetScript("OnShow", function(self)
		PlaySound(808)
	end)

	PFrame:SetScript("OnHide", function(self)
		PlaySound(808)
	end)

	PFrame:SetFrameStrata("DIALOG")
	PFrame:SetClampedToScreen(true)

	-- Title
	PFrame.title = PFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	PFrame.title:SetPoint("TOPLEFT", PFrame, "TOPLEFT", 5, -5)
	PFrame.title:SetText(name)

	-- ScrollFrame
	local scrollFrame = CreateFrame("ScrollFrame", name, PFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetSize(width, height)
	scrollFrame:SetPoint("TOPLEFT", PFrame.title, "BOTTOMLEFT", 0, -5)
	scrollFrame:SetPoint("BOTTOMRIGHT", PFrame, "BOTTOMRIGHT", -5, 5)
	PFrame.scrollFrame = scrollFrame

	-- This makes escape work to close this modal
	--table.insert(UISpecialFrames, name)

	PFrame:Hide()

	return PFrame
end

--- @param frame any
function ToggleModal(frame)
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end
