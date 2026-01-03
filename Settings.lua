-- CozierCamps - Settings.lua
-- Modern configuration UI with tabbed interface
local CC = CozierCamps
local settingsFrame = nil
local controls = {}
local currentTab = "general"
local tabFrames = {}
local tabButtons = {}

-- Color scheme - Black/Slate with Orange accents
local COLORS = {
	bg = { 0.06, 0.06, 0.08, 0.97 },
	headerBg = { 0.08, 0.08, 0.10, 1 },
	accent = { 1.0, 0.6, 0.2, 1 }, -- Orange
	accentDark = { 0.8, 0.45, 0.1, 1 }, -- Darker orange
	accentGlow = { 1.0, 0.7, 0.3, 0.3 }, -- Orange glow
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

-- Forward declaration (defined after PRESETS)
local UpdatePresetButtonVisuals

local function CreateModernCheckbox(parent, label, tooltip, setting, yOffset)
	local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	container:SetSize(340, 28)
	container:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
	container:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1
	})
	container:SetBackdropColor(0.09, 0.09, 0.11, 0.95)
	container:SetBackdropBorderColor(0.18, 0.18, 0.2, 1)

	-- Checkbox button
	local cb = CreateFrame("CheckButton", nil, container)
	cb:SetSize(20, 20)
	cb:SetPoint("LEFT", 4, 0)

	-- Checkbox background
	local cbBg = cb:CreateTexture(nil, "BACKGROUND")
	cbBg:SetAllPoints()
	cbBg:SetColorTexture(0.15, 0.15, 0.2, 1)

	-- Checkbox border
	local cbBorder = cb:CreateTexture(nil, "BORDER")
	cbBorder:SetPoint("TOPLEFT", -1, 1)
	cbBorder:SetPoint("BOTTOMRIGHT", 1, -1)
	cbBorder:SetColorTexture(0.3, 0.3, 0.35, 1)
	cbBorder:SetDrawLayer("BORDER", -1)

	-- Checkmark
	local check = cb:CreateTexture(nil, "ARTWORK")
	check:SetSize(14, 14)
	check:SetPoint("CENTER")
	check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	check:SetDesaturated(true)
	check:SetVertexColor(unpack(COLORS.accent))
	cb.check = check

	-- Label
	local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("LEFT", cb, "RIGHT", 10, 0)
	text:SetText(label)
	text:SetTextColor(unpack(COLORS.text))

	-- State
	local function UpdateVisual()
		if cb:GetChecked() then
			check:Show()
			cbBg:SetColorTexture(0.2, 0.35, 0.5, 1)
		else
			check:Hide()
			cbBg:SetColorTexture(0.15, 0.15, 0.2, 1)
		end
		UpdatePresetButtonVisuals()
	end

	cb:SetChecked(CC.GetSetting(setting))
	cb.setting = setting
	cb.isManuallyDisabled = false -- Manual tracking of disabled state
	UpdateVisual()

	cb:SetScript("OnClick", function(self)
		-- Don't process clicks if checkbox is disabled (use manual tracking)
		if self.isManuallyDisabled then
			self:SetChecked(not self:GetChecked()) -- Revert the click
			return
		end
		CC.SetSetting(setting, self:GetChecked())
		UpdateVisual()
	end)

	local disabledTooltip = nil
	function cb:SetDisabledTooltip(tooltipText)
		disabledTooltip = tooltipText
	end

	cb:SetScript("OnEnter", function(self)
		if self.isManuallyDisabled and disabledTooltip then
			cbBorder:SetColorTexture(unpack(COLORS.danger))
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(label .. " |cffFF6666(Disabled)|r", 1, 0.3, 0.3)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Why is this disabled?", 1, 0.8, 0.4)
			GameTooltip:AddLine(disabledTooltip, 1, 1, 1, true)
			GameTooltip:Show()
		else
			cbBorder:SetColorTexture(unpack(COLORS.accent))
			if tooltip then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(label, 1, 1, 1)
				GameTooltip:AddLine(tooltip, unpack(COLORS.textDim))
				GameTooltip:Show()
			end
		end
	end)
	cb:SetScript("OnLeave", function(self)
		-- Always reset to neutral gray border on leave (danger color only on hover)
		cbBorder:SetColorTexture(0.3, 0.3, 0.35, 1)
		GameTooltip:Hide()
	end)

	controls[setting] = {
		checkbox = cb,
		label = text,
		update = UpdateVisual
	}
	return container, -32
end

local function CreateModernSlider(parent, label, tooltip, setting, minVal, maxVal, step, yOffset, fmt)
	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(340, 50)
	container:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)

	-- Label
	local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", 0, 0)
	text:SetText(label)
	text:SetTextColor(unpack(COLORS.text))

	-- Value display
	fmt = fmt or function(v)
		return string.format("%.1f", v)
	end
	local valText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	valText:SetPoint("TOPRIGHT", 0, 0)
	valText:SetTextColor(unpack(COLORS.accent))

	-- Slider track background
	local trackBg = container:CreateTexture(nil, "BACKGROUND")
	trackBg:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -8)
	trackBg:SetSize(280, 6)
	trackBg:SetColorTexture(unpack(COLORS.sliderBg))

	-- Slider fill
	local trackFill = container:CreateTexture(nil, "BORDER")
	trackFill:SetPoint("TOPLEFT", trackBg, "TOPLEFT")
	trackFill:SetHeight(6)
	trackFill:SetColorTexture(unpack(COLORS.sliderFill))

	-- Slider - create with unique name to avoid nil issues
	local sliderName = "CozierCampsSlider" .. setting
	local slider = CreateFrame("Slider", sliderName, container, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", trackBg, "TOPLEFT", 0, 3)
	slider:SetSize(280, 12)
	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)

	-- Hide default textures safely
	local thumbTex = slider:GetThumbTexture()
	if thumbTex then
		thumbTex:SetTexture(nil)
	end

	local lowText = _G[sliderName .. "Low"]
	local highText = _G[sliderName .. "High"]
	local sliderText = _G[sliderName .. "Text"]
	if lowText then
		lowText:Hide()
	end
	if highText then
		highText:Hide()
	end
	if sliderText then
		sliderText:Hide()
	end

	-- Custom thumb
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(16, 16)
	thumb:SetPoint("CENTER", slider:GetThumbTexture(), "CENTER")
	thumb:SetColorTexture(1, 1, 1, 1)
	slider.customThumb = thumb

	local function UpdateSlider(value)
		local pct = (value - minVal) / (maxVal - minVal)
		trackFill:SetWidth(math.max(1, 280 * pct))
		valText:SetText(fmt(value))
	end

	local currentVal = CC.GetSetting(setting) or minVal
	slider:SetValue(currentVal)
	UpdateSlider(currentVal)

	slider:SetScript("OnValueChanged", function(self, value)
		CC.SetSetting(setting, value)
		UpdateSlider(value)
	end)

	slider:SetScript("OnEnter", function(self)
		thumb:SetColorTexture(unpack(COLORS.accent))
		if tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(label, 1, 1, 1)
			GameTooltip:AddLine(tooltip, unpack(COLORS.textDim))
			GameTooltip:Show()
		end
	end)
	slider:SetScript("OnLeave", function(self)
		thumb:SetColorTexture(1, 1, 1, 1)
		GameTooltip:Hide()
	end)

	-- Register slider in controls table for reset handling
	controls[setting] = {
		update = function()
			local newVal = CC.GetSetting(setting) or minVal
			slider:SetValue(newVal)
			UpdateSlider(newVal)
		end
	}

	return container, -55
end

local function CreateModernDropdown(parent, label, tooltip, setting, options, yOffset, optionTooltips, values)
	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(340, 55)
	container:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)

	-- Label
	local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", 0, 0)
	text:SetText(label)
	text:SetTextColor(unpack(COLORS.text))

	-- Dropdown button
	local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
	btn:SetSize(200, 28)
	btn:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -5)
	btn:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1
	})
	btn:SetBackdropColor(0.1, 0.1, 0.12, 1)
	btn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

	local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btnText:SetPoint("LEFT", 10, 0)
	btnText:SetTextColor(unpack(COLORS.text))

	-- Arrow using simple text (more reliable than special chars)
	local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	arrow:SetPoint("RIGHT", -10, 0)
	arrow:SetText("v")
	arrow:SetTextColor(unpack(COLORS.accent))

	-- Dropdown menu
	local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
	menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
	menu:SetSize(200, #options * 26 + 6)
	menu:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1
	})
	menu:SetBackdropColor(0.08, 0.08, 0.1, 0.98)
	menu:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
	menu:SetFrameStrata("TOOLTIP")
	menu:Hide()

	for i, opt in ipairs(options) do
		local item = CreateFrame("Button", nil, menu)
		item:SetSize(194, 24)
		item:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 26)

		local itemBg = item:CreateTexture(nil, "BACKGROUND")
		itemBg:SetAllPoints()
		itemBg:SetColorTexture(0, 0, 0, 0)
		item.bg = itemBg

		local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		itemText:SetPoint("LEFT", 8, 0)
		itemText:SetText(opt)
		itemText:SetTextColor(unpack(COLORS.text))

		item:SetScript("OnEnter", function(self)
			itemBg:SetColorTexture(1.0, 0.6, 0.2, 0.3)
			if optionTooltips and optionTooltips[i] then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(opt, 1, 1, 1)
				GameTooltip:AddLine(optionTooltips[i], unpack(COLORS.textDim))
				GameTooltip:Show()
			end
		end)
		item:SetScript("OnLeave", function(self)
			itemBg:SetColorTexture(0, 0, 0, 0)
			GameTooltip:Hide()
		end)
		item:SetScript("OnClick", function()
			local valueToSet = values and values[i] or i
			CC.SetSetting(setting, valueToSet)
			btnText:SetText(opt)
			menu:Hide()
		end)
	end

	local function UpdateDropdown()
		local val = CC.GetSetting(setting) or (values and values[1] or 1)
		-- Find the matching option index
		if values then
			for i, v in ipairs(values) do
				if v == val then
					btnText:SetText(options[i] or options[1])
					return
				end
			end
		end
		btnText:SetText(options[val] or options[1])
	end
	UpdateDropdown()

	btn:SetScript("OnClick", function()
		if menu:IsShown() then
			menu:Hide()
		else
			menu:Show()
		end
	end)
	btn:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(unpack(COLORS.accent))
	end)
	btn:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
	end)

	-- Close menu when clicking elsewhere
	menu:SetScript("OnShow", function(self)
		self:SetFrameLevel(parent:GetFrameLevel() + 100)
	end)

	controls[setting] = {
		update = UpdateDropdown
	}
	return container, -60
end

local function CreateSectionHeader(parent, text, yOffset, color)
	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(360, 30)
	container:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)

	-- Icon/accent bar
	local accent = container:CreateTexture(nil, "ARTWORK")
	accent:SetSize(4, 20)
	accent:SetPoint("LEFT", 0, 0)
	accent:SetColorTexture(unpack(color or COLORS.accent))

	-- Header text
	local header = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	header:SetPoint("LEFT", accent, "RIGHT", 10, 0)
	header:SetText(text)
	header:SetTextColor(unpack(COLORS.text))

	return container, -35
end

-- Preset configurations
local PRESETS = {
	adventure = {
		name = "Adventure",
		description = "Full survival experience with all meters and restrictions.",
		settings = {
			enabled = true,
			exhaustionEnabled = true,
			AnguishEnabled = true,
			hungerEnabled = true,
			thirstEnabled = true,
			temperatureEnabled = true,
			hideActionBarsMode = 2, -- Near Fire or Rested
			blockMap = true,
			showSurvivalIcons = true,
			innkeeperHealsAnguish = true,
			meterDisplayMode = "vial",
			wetScreenEffectEnabled = false
		}
	},
	lite = {
		name = "Lite",
		description = "Minimal experience - exhaustion meter only, no restrictions.",
		settings = {
			enabled = true,
			exhaustionEnabled = true,
			AnguishEnabled = false,
			hungerEnabled = false,
			thirstEnabled = false,
			temperatureEnabled = false,
			hideActionBarsMode = 1, -- Always Visible
			blockMap = false,
			showSurvivalIcons = false,
			innkeeperHealsAnguish = false,
			wetScreenEffectEnabled = false
		}
	}
}

local currentPreset = "lite" -- Default preset

local function ApplyPreset(presetKey)
	local preset = PRESETS[presetKey]
	if not preset then
		return
	end

	for setting, value in pairs(preset.settings) do
		CC.SetSetting(setting, value)
	end

	-- Force-enable Constitution for Adventure preset
	if presetKey == "adventure" then
		CC.SetSetting("constitutionEnabled", true)
		if controls["constitutionEnabled"] and controls["constitutionEnabled"].checkbox then
			controls["constitutionEnabled"].checkbox:Enable()
			controls["constitutionEnabled"].checkbox:SetChecked(true)
		end
	end

	currentPreset = presetKey

	-- Update all controls
	for setting, ctrl in pairs(controls) do
		if ctrl.checkbox then
			ctrl.checkbox:SetChecked(CC.GetSetting(setting))
		end
		if ctrl.update then
			ctrl.update()
		end
	end

	UpdatePresetButtonVisuals()
	print("|cff88CCFFCozierCamps:|r Applied preset: " .. preset.name)
end

local presetButtons = {}

local function CreatePresetButton(parent, presetKey, xOffset, yOffset)
	local preset = PRESETS[presetKey]

	local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
	btn:SetSize(150, 50)
	btn:SetPoint("TOPLEFT", xOffset, yOffset)
	btn:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 2
	})
	btn:SetBackdropColor(0.12, 0.12, 0.14, 1)
	btn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

	local btnTitle = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btnTitle:SetPoint("TOP", 0, -8)
	btnTitle:SetText(preset.name)
	btnTitle:SetTextColor(unpack(COLORS.accent))

	local btnDesc = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	btnDesc:SetPoint("TOP", btnTitle, "BOTTOM", 0, -4)
	btnDesc:SetText(presetKey == "adventure" and "All Features" or "Exhaustion Only")
	btnDesc:SetTextColor(unpack(COLORS.textDim))

	btn:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(unpack(COLORS.accent))
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(preset.name .. " Preset", 1, 1, 1)
		GameTooltip:AddLine(preset.description, unpack(COLORS.textDim))
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function(self)
		UpdatePresetButtonVisuals()
		GameTooltip:Hide()
	end)
	btn:SetScript("OnClick", function()
		ApplyPreset(presetKey)
	end)

	presetButtons[presetKey] = btn
	return btn
end

local function IsPresetActive(presetKey)
	local preset = PRESETS[presetKey]
	if not preset then
		return false
	end
	for setting, value in pairs(preset.settings) do
		if CC.GetSetting(setting) ~= value then
			return false
		end
	end
	return true
end

UpdatePresetButtonVisuals = function()
	local active = nil
	if IsPresetActive("adventure") then
		active = "adventure"
	elseif IsPresetActive("lite") then
		active = "lite"
	else
		active = "custom"
	end

	for key, btn in pairs(presetButtons) do
		if key == active then
			btn:SetBackdropBorderColor(unpack(COLORS.accent))
		else
			btn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
		end
	end

	if presetButtons["custom"] then
		if active == "custom" then
			presetButtons["custom"]:Show()
		else
			presetButtons["custom"]:Hide()
		end
	end
end

local function CreateTabButton(parent, tabKey, label, xOffset)
	local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
	btn:SetSize(90, 28)
	btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", xOffset, 0)
	btn:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8"
	})

	local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btnText:SetPoint("CENTER", 0, 0)
	btnText:SetText(label)
	btn.text = btnText
	btn.tabKey = tabKey

	local function UpdateTabVisual()
		if currentTab == tabKey then
			btn:SetBackdropColor(unpack(COLORS.tabActive))
			btnText:SetTextColor(unpack(COLORS.accent))
		else
			btn:SetBackdropColor(unpack(COLORS.tabInactive))
			btnText:SetTextColor(unpack(COLORS.textDim))
		end
	end
	btn.UpdateVisual = UpdateTabVisual
	UpdateTabVisual()

	btn:SetScript("OnClick", function()
		currentTab = tabKey
		for _, tb in pairs(tabButtons) do
			tb:UpdateVisual()
		end
		for key, frame in pairs(tabFrames) do
			if key == tabKey then
				frame:Show()
			else
				frame:Hide()
			end
		end
	end)
	btn:SetScript("OnEnter", function(self)
		if currentTab ~= tabKey then
			btnText:SetTextColor(unpack(COLORS.text))
		end
	end)
	btn:SetScript("OnLeave", function(self)
		UpdateTabVisual()
	end)

	tabButtons[tabKey] = btn
	return btn
end

local function CreateGeneralTab(parent)
	local content = CreateFrame("Frame", nil, parent)
	content:SetAllPoints()

	local y = -10
	local _, o

	-- Presets Section
	_, o = CreateSectionHeader(content, "Quick Presets", y)
	y = y + o

	-- Preset description
	local presetDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	presetDesc:SetPoint("TOPLEFT", 30, y)
	presetDesc:SetText("Choose a preset to quickly configure CozierCamps:")
	presetDesc:SetTextColor(unpack(COLORS.textDim))
	y = y - 25

	-- Preset buttons (2x2 stack)
	local adventureBtn = CreatePresetButton(content, "adventure", 30, y)
	local liteBtn = CreatePresetButton(content, "lite", 190, y)
	-- Custom below Adventure, Manual below Lite
	local customY = y - 60
	if not presetButtons["custom"] then
		local btn = CreateFrame("Frame", nil, content, "BackdropTemplate")
		btn:SetSize(150, 50)
		btn:SetPoint("TOPLEFT", 30, customY)
		btn:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 2
		})
		btn:SetBackdropColor(0.12, 0.12, 0.14, 1)
		btn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
		local btnTitle = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		btnTitle:SetPoint("TOP", 0, -8)
		btnTitle:SetText("Custom")
		btnTitle:SetTextColor(unpack(COLORS.accent))
		local btnDesc = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		btnDesc:SetPoint("TOP", btnTitle, "BOTTOM", 0, -4)
		btnDesc:SetText("Manual Settings")
		btnDesc:SetTextColor(unpack(COLORS.textDim))
		presetButtons["custom"] = btn
	else
		presetButtons["custom"]:SetPoint("TOPLEFT", 30, customY)
	end
	y = customY - 60

	-- Core Settings
	_, o = CreateSectionHeader(content, "Core Settings", y)
	y = y + o

	_, o = CreateModernCheckbox(content, "Enable CozierCamps", "Master toggle for all CozierCamps features.", "enabled", y)
	y = y + o

	_, o = CreateModernCheckbox(content, "Lock Meters", "Prevent meters from being moved by dragging.", "metersLocked",
			y)
	y = y + o

	_, o = CreateModernCheckbox(content, "HP Tunnel Vision",
			"Adds a gradual tunnel vision effect as HP decreases. The effect intensifies at 80%, 60%, 40%, and 20% HP thresholds.",
			"hpTunnelVisionEnabled", y)
	y = y + o
	y = y - 10

	-- Meter Appearance
	_, o = CreateSectionHeader(content, "Meter Appearance", y)
	y = y + o

	-- Display mode dropdown (bar vs vial)
	_, o = CreateModernDropdown(content, "Display Mode", "Choose between horizontal bars or potion vial style.",
			"meterDisplayMode", { "Bar", "Vial" }, y, { "Traditional horizontal progress bars.",
														"Potion bottle style with vertical fill." }, { "bar", "vial" })
	y = y + o
	_, o = CreateModernSlider(content, "Meter Scale", "Scale all meters up or down (50% to 150%).", "meterScale", 0.5,
			1.5, 0.05, y, function(v)
				return string.format("%.0f%%", v * 100)
			end)
	y = y + o
	_, o = CreateModernDropdown(content, "Tooltip Display", "How much information to show in meter tooltips.",
			"tooltipDisplayMode", { "Detailed", "Minimal", "Disabled" }, y,
			{ "Full explanations with recovery methods, checkpoints, and pause conditions.",
			  "Just current values, trends, and active effects. No how-to information.",
			  "No tooltips shown when hovering over meters." },
			{ "detailed", "minimal", "disabled" })
	y = y + o

	local textureNames = { "Blizzard", "Blizzard Raid", "Smooth", "Flat", "Gloss", "Minimalist", "Otravi", "Striped",
						   "Solid" }
	_, o = CreateModernDropdown(content, "Bar Texture", "Visual style for the meter bars.", "meterBarTexture",
			textureNames, y)
	y = y + o
	local fontNames = { "Default", "Friz Quadrata", "Arial Narrow", "Skurri", "Morpheus", "2002", "2002 Bold",
						"Express Way", "Nimrod MT" }
	_, o = CreateModernDropdown(content, "General Font", "Font for all addon text. 'Default' inherits from UI.",
			"generalFont", fontNames, y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Hide Vial Text", "Hide the percentage numbers on potion vials.",
			"hideVialText", y)
	y = y + o

	return content
end

local function CreateFireTab(parent)
	local content = CreateFrame("Frame", nil, parent)
	content:SetAllPoints()

	local y = -10
	local _, o

	-- Detection Mode Section
	_, o = CreateSectionHeader(content, "Fire Detection", y)
	y = y + o
	_, o = CreateModernDropdown(content, "Detection Mode", "How fire proximity is detected", "fireDetectionMode",
			{ "Auto Detect", "Manual Rest Mode" }, y, { "Automatically detect nearby campfires.",
														"Use /rest command to activate. More performance-friendly." })
	y = y + o
	_, o = CreateModernCheckbox(content, "Detect Player Campfires", "Count Basic Campfire spell as a rest point.",
			"detectPlayerCampfires", y)
	y = y + o
	_, o = CreateModernSlider(content, "Detection Range", "How close to be considered 'near fire'.", "campfireRange", 2,
			4, 1, y, function(v)
				return v .. " yards"
			end)
	y = y + o
	y = y - 10

	-- Fire Restrictions
	_, o = CreateSectionHeader(content, "Fire Restrictions", y)
	y = y + o
	_, o = CreateModernDropdown(content, "Show Action Bars", "When action bars are visible (requires level 6+)",
			"hideActionBarsMode", { "Always Visible", "Near Fire or Rested", "Rested Areas Only" }, y,
			{ "Action bars always visible (restriction disabled).", "Show near campfires, in inns/cities, on taxi, or dead.",
			  "Show only in rested areas (inns/cities)." })
	y = y + o
	_, o = CreateModernCheckbox(content, "Block Map Access",
			"Prevent opening the map when not rested or near a campfire. Requires level 6+.", "blockMap", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Hide Minimap with Action Bars",
			"Also fade the minimap when action bars are hidden. Constitution override (25%) will still hide it.",
			"hideMinimapWithBars", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Show Survival Icons on Map",
			"Display icons on the world map for campfires, inns, and first aid trainers in the current zone.",
			"showSurvivalIcons", y)
	y = y + o

	-- Logic to disable Survival Icons checkbox in Manual Rest Mode
	local function UpdateSurvivalIconsState()
		local isManualMode = CC.GetSetting("fireDetectionMode") == 2
		local control = controls["showSurvivalIcons"]
		local cb = control and control.checkbox
		local label = control and control.label
		if cb then
			if isManualMode then
				-- Disable in Manual Rest Mode with red styling
				cb.isManuallyDisabled = true
				cb:SetChecked(false)
				CC.SetSetting("showSurvivalIcons", false)
				if control.update then
					control.update()
				end
				cb:SetDisabledTooltip(
						"Map icons are disabled in Manual Rest Mode for performance. Switch to Auto Detect mode to enable icons.")
				if label then
					label:SetTextColor(0.5, 0.5, 0.5, 1)
				end
				cb:GetParent():SetBackdropColor(0.12, 0.12, 0.12, 0.7)
				cb:GetParent():SetBackdropBorderColor(unpack(COLORS.danger))
			else
				-- Re-enable checkbox in Auto Detect mode
				cb.isManuallyDisabled = false
				cb:SetDisabledTooltip(nil)
				if label then
					label:SetTextColor(unpack(COLORS.text))
				end
				cb:GetParent():SetBackdropColor(0.09, 0.09, 0.11, 0.95)
				cb:GetParent():SetBackdropBorderColor(0.18, 0.18, 0.2, 1)
			end
		end
	end
	-- Register callback for when fireDetectionMode changes
	CC.RegisterCallback("SETTINGS_CHANGED", function(key)
		if key == "fireDetectionMode" or key == "ALL" then
			UpdateSurvivalIconsState()
		end
	end)
	-- Initial state check
	UpdateSurvivalIconsState()

	_, o = CreateModernCheckbox(content, "Play Sound Near Fire", "Play a sound when you enter campfire range.",
			"playSoundNearFire", y)
	y = y + o

	return content
end

local function CreateSurvivalTab(parent)
	local content = CreateFrame("Frame", nil, parent)
	content:SetAllPoints()

	local y = -10
	local _, o

	-- Anguish System (First)
	_, o = CreateSectionHeader(content, "Anguish System", y, COLORS.Anguish)
	y = y + o
	_, o = CreateModernCheckbox(content, "Enable Anguish", "Screen overlay intensifies as you take damage.",
			"AnguishEnabled", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Innkeepers Heal Anguish",
			"Talking to an innkeeper heals your Anguish up to 85% vitality.", "innkeeperHealsAnguish", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Play Relief Sound",
			"Play a soothing sound when your Anguish is healed by an innkeeper or first aid trainer.", "playSoundAnguishRelief", y)
	y = y + o
	_, o = CreateModernDropdown(content, "Difficulty", nil, "AnguishScale",
			CC.GetAnguishScaleNames and CC.GetAnguishScaleNames() or { "Default", "Hard", "Insane" }, y,
			CC.GetAnguishScaleTooltips and CC.GetAnguishScaleTooltips() or nil)
	y = y + o
	y = y - 10

	-- Exhaustion System (Second)
	_, o = CreateSectionHeader(content, "Exhaustion System", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Enable Exhaustion",
			"Builds while moving, decays near fires or in rested areas.", "exhaustionEnabled", y)
	y = y + o
	y = y - 10

	-- Hunger System (Third)
	local HUNGER_COLOR = { 0.9, 0.6, 0.2, 1 } -- Orange/amber
	_, o = CreateSectionHeader(content, "Hunger System", y, HUNGER_COLOR)
	y = y + o
	_, o = CreateModernCheckbox(content, "Enable Hunger",
			"Track hunger that builds from movement and activity. Eating food reduces hunger, with checkpoints based on location.",
			"hungerEnabled", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Innkeepers Reset Hunger",
			"Talking to an innkeeper heals your Hunger up to 85% satiation.", "innkeeperResetsHunger", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Play Relief Sound",
			"Play a pleasant sound when your Hunger is satisfied by talking to a cooking trainer.", "playSoundHungerRelief", y)
	y = y + o
	_, o = CreateModernSlider(content, "Max Darkness",
			"Maximum screen vignette darkness when fully hungry (100%). Creates a subtle darkening around screen edges.",
			"hungerMaxDarkness", 0, 0.75, 0.05, y, function(v)
				return string.format("%.0f%%", v * 100)
			end)
	y = y + o
	y = y - 10

	-- Thirst System (Fourth)
	local THIRST_COLOR = { 0.4, 0.7, 1.0, 1 } -- Blue
	_, o = CreateSectionHeader(content, "Thirst System", y, THIRST_COLOR)
	y = y + o
	_, o = CreateModernCheckbox(content, "Enable Thirst",
			"Track thirst that builds from movement and activity. Drinking reduces thirst, with checkpoints based on location. Hot temperatures increase thirst drain.",
			"thirstEnabled", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Innkeepers Reset Thirst",
			"Talking to an innkeeper heals your Thirst up to 85% hydration.", "innkeeperResetsThirst", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Play Relief Sound",
			"Play a pleasant sound when your Thirst is satisfied by talking to a cooking trainer.", "playSoundThirstRelief",
			y)
	y = y + o
	_, o = CreateModernSlider(content, "Max Darkness",
			"Maximum screen vignette darkness when fully thirsty (100%). Creates a subtle darkening around screen edges with a blue tint.",
			"thirstMaxDarkness", 0, 0.75, 0.05, y, function(v)
				return string.format("%.0f%%", v * 100)
			end)
	y = y + o
	y = y - 10

	-- Constitution System (NEW)
	y = y - 10 -- Extra spacing before
	local CONSTITUTION_COLOR = { 0.6, 0.9, 0.6, 1 } -- Green
	_, o = CreateSectionHeader(content, "Constitution System", y, CONSTITUTION_COLOR)
	y = y + o
	y = y - 8 -- Extra spacing before checkbox
	local constitutionCheckbox, constitutionOffset = CreateModernCheckbox(content, "Enable Constitution",
			"Combines all survival meters into one overall health score. Progressively hides UI as constitution drops:\n\n" ..
					"• Below 75%: Target frame & nameplates hidden\n" ..
					"• Below 50%: Player frame hidden\n" ..
					"• Below 25%: Action bars, map disabled\n\n" ..
					"Requires at least two other meters enabled.",
			"constitutionEnabled", y)
	y = y + constitutionOffset
	_, o = CreateModernCheckbox(content, "Play Heartbeat Sound",
			"Play a looping heartbeat sound when your Constitution drops below 25%, creating an urgent atmosphere.", "playSoundHeartbeat", y)
	y = y + o
	y = y - 8 -- Extra spacing after checkbox

	-- Logic to enable/disable Constitution checkbox
	local function UpdateConstitutionCheckboxState()
		local enabledCount = 0
		if CC.GetSetting("exhaustionEnabled") then
			enabledCount = enabledCount + 1
		end
		if CC.GetSetting("AnguishEnabled") then
			enabledCount = enabledCount + 1
		end
		if CC.GetSetting("hungerEnabled") then
			enabledCount = enabledCount + 1
		end
		if CC.GetSetting("thirstEnabled") then
			enabledCount = enabledCount + 1
		end
		if CC.GetSetting("temperatureEnabled") then
			enabledCount = enabledCount + 1
		end
		local canEnable = enabledCount >= 2
		local control = controls["constitutionEnabled"]
		local cb = control and control.checkbox
		local label = control and control.label
		if cb then
			if not canEnable then
				-- Use manual disabled tracking
				cb.isManuallyDisabled = true
				cb:SetChecked(false)
				CC.SetSetting("constitutionEnabled", false)
				-- Update visual state (hide checkmark)
				if control.update then
					control.update()
				end
				cb:SetDisabledTooltip(
						"Enable at least two other meters (Exhaustion, Anguish, Hunger, Thirst, Temperature) to unlock Constitution.")
				if label then
					label:SetTextColor(0.5, 0.5, 0.5, 1)
				end
				cb:GetParent():SetBackdropColor(0.12, 0.12, 0.12, 0.7)
				cb:GetParent():SetBackdropBorderColor(unpack(COLORS.danger))
			else
				-- Re-enable checkbox
				cb.isManuallyDisabled = false
				cb:SetDisabledTooltip(nil)
				if label then
					label:SetTextColor(unpack(COLORS.text))
				end
				cb:GetParent():SetBackdropColor(0.09, 0.09, 0.11, 0.95)
				cb:GetParent():SetBackdropBorderColor(0.18, 0.18, 0.2, 1)
			end
		end
	end
	-- Temperature System (Fifth/Last)
	local TEMP_COLOR = { 1.0, 0.7, 0.3, 1 } -- Warm orange/yellow
	_, o = CreateSectionHeader(content, "Temperature System", y, TEMP_COLOR)
	y = y + o
	_, o = CreateModernCheckbox(content, "Enable Temperature",
			"Track temperature based on zones, weather, and activities. Cold zones make you cold, hot zones make you hot.",
			"temperatureEnabled", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Manual Weather Toggle",
			"Show a weather toggle button below the temperature meter. Click it to simulate current weather effects (rain, snow, dust storms) since Classic WoW cannot detect weather automatically. Only available in zones where weather can occur.",
			"manualWeatherEnabled", y)
	y = y + o
	_, o = CreateModernCheckbox(content, "Wetness Screen Effect",
			"Show a subtle water droplet overlay on the screen when your character is wet from swimming or rain.",
			"wetScreenEffectEnabled", y)
	y = y + o

	-- Hook constitution checkbox state update AFTER all meter checkboxes are created
	for _, dep in ipairs({ "exhaustionEnabled", "AnguishEnabled", "hungerEnabled", "thirstEnabled", "temperatureEnabled" }) do
		if controls[dep] and controls[dep].checkbox then
			controls[dep].checkbox:HookScript("OnClick", UpdateConstitutionCheckboxState)
		end
	end
	UpdateConstitutionCheckboxState()

	return content
end

local function CreatePanel()
	if settingsFrame then
		return settingsFrame
	end

	-- Main frame
	settingsFrame = CreateFrame("Frame", "CozierCampsSettingsFrame", UIParent, "BackdropTemplate")
	settingsFrame:SetSize(400, 650)
	settingsFrame:SetPoint("CENTER")
	settingsFrame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 2
	})
	settingsFrame:SetBackdropColor(unpack(COLORS.bg))
	settingsFrame:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)
	settingsFrame:SetMovable(true)
	settingsFrame:EnableMouse(true)
	settingsFrame:RegisterForDrag("LeftButton")
	settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
	settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
	settingsFrame:SetFrameStrata("DIALOG")
	settingsFrame:SetFrameLevel(100)
	settingsFrame:Hide()

	-- Header bar
	local header = CreateFrame("Frame", nil, settingsFrame, "BackdropTemplate")
	header:SetSize(400, 60)
	header:SetPoint("TOP")
	header:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8"
	})
	header:SetBackdropColor(unpack(COLORS.headerBg))

	-- Logo container
	local iconFrame = CreateFrame("Frame", nil, header)
	iconFrame:SetSize(40, 40)
	iconFrame:SetPoint("LEFT", 15, 0)

	-- Fire glow (background)
	local fireGlow = iconFrame:CreateTexture(nil, "BACKGROUND")
	fireGlow:SetSize(50, 50)
	fireGlow:SetPoint("CENTER", 0, 2)
	fireGlow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
	fireGlow:SetVertexColor(1.0, 0.5, 0.1, 0.4)
	fireGlow:SetBlendMode("ADD")

	-- Custom logo from assets
	local fireIcon = iconFrame:CreateTexture(nil, "ARTWORK")
	fireIcon:SetSize(36, 36)
	fireIcon:SetPoint("CENTER")
	fireIcon:SetTexture("Interface\\AddOns\\CozierCamps\\assets\\mainlogo.png")
	fireIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Animated glow pulse
	local glowAnim = fireGlow:CreateAnimationGroup()
	glowAnim:SetLooping("REPEAT")
	local pulse1 = glowAnim:CreateAnimation("Alpha")
	pulse1:SetFromAlpha(0.3)
	pulse1:SetToAlpha(0.6)
	pulse1:SetDuration(0.8)
	pulse1:SetOrder(1)
	pulse1:SetSmoothing("IN_OUT")
	local pulse2 = glowAnim:CreateAnimation("Alpha")
	pulse2:SetFromAlpha(0.6)
	pulse2:SetToAlpha(0.3)
	pulse2:SetDuration(0.8)
	pulse2:SetOrder(2)
	pulse2:SetSmoothing("IN_OUT")
	glowAnim:Play()

	-- Title with stylized text
	local titleShadow = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	titleShadow:SetPoint("LEFT", iconFrame, "RIGHT", 11, -1)
	titleShadow:SetText("CozierCamps")
	titleShadow:SetTextColor(0, 0, 0, 0.5)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", iconFrame, "RIGHT", 10, 0)
	title:SetText("CozierCamps")
	title:SetTextColor(1.0, 0.75, 0.35, 1)

	-- Subtitle
	local subtitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	subtitle:SetText("A Survival Experience")
	subtitle:SetTextColor(0.6, 0.6, 0.6, 1)

	-- Version badge
	local versionBg = header:CreateTexture(nil, "ARTWORK")
	versionBg:SetSize(40, 16)
	versionBg:SetPoint("LEFT", title, "RIGHT", 8, 0)
	versionBg:SetColorTexture(1.0, 0.6, 0.2, 0.2)

	local version = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	version:SetPoint("CENTER", versionBg, "CENTER", 0, 0)
	version:SetText("v" .. CC.version)
	version:SetTextColor(1.0, 0.7, 0.3, 1)

	-- Close button
	local closeBtn = CreateFrame("Button", nil, header)
	closeBtn:SetSize(30, 30)
	closeBtn:SetPoint("RIGHT", -10, 0)
	local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	closeText:SetPoint("CENTER")
	closeText:SetText("x")
	closeText:SetTextColor(0.5, 0.5, 0.5, 1)
	closeBtn:SetScript("OnEnter", function()
		closeText:SetTextColor(unpack(COLORS.danger))
	end)
	closeBtn:SetScript("OnLeave", function()
		closeText:SetTextColor(0.5, 0.5, 0.5, 1)
	end)
	closeBtn:SetScript("OnClick", function()
		settingsFrame:Hide()
	end)

	-- Decorative line under header
	local headerLine = header:CreateTexture(nil, "ARTWORK")
	headerLine:SetSize(380, 2)
	headerLine:SetPoint("BOTTOM", header, "BOTTOM", 0, 0)
	headerLine:SetColorTexture(1.0, 0.6, 0.2, 0.3)

	-- Tab bar (below header)
	local tabBar = CreateFrame("Frame", nil, settingsFrame, "BackdropTemplate")
	tabBar:SetSize(400, 30)
	tabBar:SetPoint("TOP", header, "BOTTOM", 0, 0)
	tabBar:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8"
	})
	tabBar:SetBackdropColor(0.05, 0.05, 0.07, 1)

	-- Create tab buttons (3 tabs, evenly spaced)
	local tabWidth = 400 / 3
	CreateTabButton(tabBar, "general", "General", 0)
	tabButtons["general"]:SetSize(tabWidth, 30)
	CreateTabButton(tabBar, "fire", "Fire", tabWidth)
	tabButtons["fire"]:SetSize(tabWidth, 30)
	CreateTabButton(tabBar, "survival", "Survival", tabWidth * 2)
	tabButtons["survival"]:SetSize(tabWidth, 30)

	-- Tab underline indicator
	local tabUnderline = tabBar:CreateTexture(nil, "ARTWORK")
	tabUnderline:SetSize(380, 2)
	tabUnderline:SetPoint("BOTTOM", 0, 0)
	tabUnderline:SetColorTexture(0.2, 0.2, 0.22, 1)

	-- Tab content container
	local tabContainer = CreateFrame("Frame", nil, settingsFrame)
	tabContainer:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, 0)
	tabContainer:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", 0, 50)

	-- Create scroll frames for each tab
	local function CreateTabScrollFrame(tabKey, createContentFunc)
		local scrollFrame = CreateFrame("ScrollFrame", nil, tabContainer, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", 5, -5)
		scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

		-- Style scrollbar
		local scrollBar = scrollFrame.ScrollBar
		if scrollBar then
			scrollBar:ClearAllPoints()
			scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -2, -16)
			scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -2, 16)
		end

		-- Content
		local content = CreateFrame("Frame", nil, scrollFrame)
		content:SetSize(365, 600)
		scrollFrame:SetScrollChild(content)

		-- Create tab-specific content
		local tabContent = createContentFunc(content)

		tabFrames[tabKey] = scrollFrame
		if tabKey ~= "general" then
			scrollFrame:Hide()
		end

		return scrollFrame
	end

	CreateTabScrollFrame("general", CreateGeneralTab)
	CreateTabScrollFrame("fire", CreateFireTab)
	CreateTabScrollFrame("survival", CreateSurvivalTab)

	-- Bottom bar
	local bottomBar = CreateFrame("Frame", nil, settingsFrame, "BackdropTemplate")
	bottomBar:SetSize(400, 50)
	bottomBar:SetPoint("BOTTOM")
	bottomBar:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8"
	})
	bottomBar:SetBackdropColor(unpack(COLORS.headerBg))

	-- Decorative line above bottom bar
	local bottomLine = bottomBar:CreateTexture(nil, "ARTWORK")
	bottomLine:SetSize(380, 1)
	bottomLine:SetPoint("TOP", bottomBar, "TOP", 0, 0)
	bottomLine:SetColorTexture(1.0, 0.6, 0.2, 0.2)

	-- Reset button
	local resetBtn = CreateFrame("Button", nil, bottomBar, "BackdropTemplate")
	resetBtn:SetSize(100, 32)
	resetBtn:SetPoint("LEFT", 15, 0)
	resetBtn:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1
	})
	resetBtn:SetBackdropColor(0.12, 0.12, 0.14, 1)
	resetBtn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
	local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	resetText:SetPoint("CENTER")
	resetText:SetText("Reset All")
	resetText:SetTextColor(0.6, 0.6, 0.6, 1)
	resetBtn:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(unpack(COLORS.warning))
		resetText:SetTextColor(unpack(COLORS.warning))
	end)
	resetBtn:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
		resetText:SetTextColor(0.6, 0.6, 0.6, 1)
	end)
	resetBtn:SetScript("OnClick", function()
		StaticPopup_Show("CozierCamps_RESET")
	end)

	-- Reload UI button (center)
	local reloadBtn = CreateFrame("Button", nil, bottomBar, "BackdropTemplate")
	reloadBtn:SetSize(100, 32)
	reloadBtn:SetPoint("CENTER", 0, 0)
	reloadBtn:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1
	})
	reloadBtn:SetBackdropColor(0.15, 0.15, 0.18, 1)
	reloadBtn:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
	local reloadText = reloadBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	reloadText:SetPoint("CENTER")
	reloadText:SetText("Reload UI")
	reloadText:SetTextColor(0.7, 0.7, 0.7, 1)
	reloadBtn:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(0.5, 0.7, 1.0, 1)
		reloadText:SetTextColor(0.5, 0.7, 1.0, 1)
	end)
	reloadBtn:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
		reloadText:SetTextColor(0.7, 0.7, 0.7, 1)
	end)
	reloadBtn:SetScript("OnClick", function()
		ReloadUI()
	end)

	-- Close button (orange themed)
	local closeBottomBtn = CreateFrame("Button", nil, bottomBar, "BackdropTemplate")
	closeBottomBtn:SetSize(100, 32)
	closeBottomBtn:SetPoint("RIGHT", -15, 0)
	closeBottomBtn:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1
	})
	closeBottomBtn:SetBackdropColor(0.8, 0.45, 0.1, 1)
	closeBottomBtn:SetBackdropBorderColor(1.0, 0.6, 0.2, 1)
	local closeBottomText = closeBottomBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	closeBottomText:SetPoint("CENTER")
	closeBottomText:SetText("Close")
	closeBottomText:SetTextColor(1, 1, 1, 1)
	closeBottomBtn:SetScript("OnEnter", function(self)
		self:SetBackdropColor(1.0, 0.6, 0.2, 1)
	end)
	closeBottomBtn:SetScript("OnLeave", function(self)
		self:SetBackdropColor(0.8, 0.45, 0.1, 1)
	end)
	closeBottomBtn:SetScript("OnClick", function()
		settingsFrame:Hide()
	end)

	-- Reset popup
	StaticPopupDialogs["CozierCamps_RESET"] = {
		text = "Reset all CozierCamps settings to defaults?",
		button1 = "Yes",
		button2 = "No",
		OnAccept = function()
			CC.ResetSettings()
			-- Update all controls
			for setting, ctrl in pairs(controls) do
				if ctrl.checkbox then
					ctrl.checkbox:SetChecked(CC.GetSetting(setting))
				end
				if ctrl.update then
					ctrl.update()
				end
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true
	}

	-- ESC to close
	tinsert(UISpecialFrames, "CozierCampsSettingsFrame")

	return settingsFrame
end

CC.RegisterCallback("SETTINGS_CHANGED", function(key)
	if key == "ALL" then
		-- Reset was called - update all controls
		for setting, ctrl in pairs(controls) do
			if ctrl.checkbox then
				ctrl.checkbox:SetChecked(CC.GetSetting(setting))
			end
			if ctrl.update then
				ctrl.update()
			end
		end
	elseif controls[key] then
		if controls[key].checkbox then
			controls[key].checkbox:SetChecked(CC.GetSetting(key))
		end
		if controls[key].update then
			controls[key].update()
		end
	end
end)

function CC.ToggleSettings()
	local f = CreatePanel()
	if f:IsShown() then
		f:Hide()
	else
		-- Refresh all controls
		for setting, ctrl in pairs(controls) do
			if ctrl.checkbox then
				ctrl.checkbox:SetChecked(CC.GetSetting(setting))
			end
			if ctrl.update then
				ctrl.update()
			end
		end
		f:Show()
		f:Raise()
	end
end

function CC.OpenSettings()
	local f = CreatePanel()
	for setting, ctrl in pairs(controls) do
		if ctrl.checkbox then
			ctrl.checkbox:SetChecked(CC.GetSetting(setting))
		end
		if ctrl.update then
			ctrl.update()
		end
	end
	f:Show()
	f:Raise()
end

function CC.CloseSettings()
	if settingsFrame then
		settingsFrame:Hide()
	end
end
