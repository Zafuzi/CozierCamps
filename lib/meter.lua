-- Create a single meter frame
function CreateMeter(name, parent, iconPath, color)
	local bgColor = hex_to_rgb_normalized(color or COLORS.ADDON)
	local textColor = hex_to_rgb_normalized(COLORS.ADDON)

	local meter = CreateFrame("Frame", "Cultivation - " .. name .. " - Meter", parent, "BackdropTemplate")
	meter:SetSize(METER_WIDTH, METER_HEIGHT)
	meter:SetPoint("TOP", parent, "TOP", 0, 0)

	-- Background with shadow effect
	meter:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		insets = {
			left = 2,
			right = 2,
			top = 2,
			bottom = 2
		}
	})
	meter:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	meter:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	-- Status bar (lower frame level so icon/text appear above)
	meter.bar = CreateFrame("StatusBar", nil, meter)
	meter.bar:SetFrameLevel(meter:GetFrameLevel()) -- Same level as parent, textures will be below OVERLAY
	meter.bar:SetPoint("TOPLEFT", METER_PADDING, -METER_PADDING)
	meter.bar:SetPoint("BOTTOMRIGHT", -METER_PADDING, METER_PADDING)
	meter.bar:SetStatusBarTexture(GetTexture("tooltip"))
	meter.bar:SetStatusBarColor(unpack(bgColor))
	meter.bar:SetMinMaxValues(0, 100)
	meter.bar:SetValue(0)
	meter.bar:EnableMouse(true) -- Allow mouse events to pass through to parent for tooltip

	-- Icon on top of the bar, floating at the left/starting position
	-- Created on meter frame with high draw layer to ensure visibility
	if iconPath then
		meter.icon = meter:CreateTexture(nil, "OVERLAY", nil, 7) -- Sub-layer 7 for highest priority
		meter.icon:SetSize(ICON_SIZE, ICON_SIZE)
		meter.icon:SetPoint("LEFT", meter.bar, "LEFT", 2, 0)
		meter.icon:SetTexture(iconPath)
		meter.icon:SetVertexColor(unpack(textColor))
	end

	local fontPath = GetFont("Arial")

	meter.name = meter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	meter.name:SetPoint("LEFT", meter.icon, "RIGHT", METER_SPACING, 0)
	meter.name:SetText(name)
	meter.name:SetTextColor(unpack(textColor))

	-- Glow frame (outlines the bar) - pass isAnguish to determine atlas color
	--meter.glow = CreateGlowFrame(meter, isAnguish)

	-- Percentage text (no label needed since icon identifies the bar)
	meter.percent = meter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	meter.percent:SetPoint("RIGHT", meter.bar, "RIGHT", -4, 0)
	meter.percent:SetText("0% - 0h 0m 0s")
	meter.percent:SetTextColor(unpack(textColor))

	meter.percent:SetFont(fontPath, METER_FONT_SIZE)
	meter.name:SetFont(fontPath, METER_FONT_SIZE)

	return meter
end