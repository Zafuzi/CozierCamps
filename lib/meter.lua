-- Create a single meter frame
function CreateMeter(name, parent, iconPath, isAnguish)
	local meter = CreateFrame("Frame", "CozierCamps - " .. name .. " - Meter", parent, "BackdropTemplate")
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
	meter.bar:SetStatusBarTexture(GetBarTexture())
	meter.bar:SetMinMaxValues(0, 100)
	meter.bar:SetValue(0)
	meter.bar:EnableMouse(false) -- Allow mouse events to pass through to parent for tooltip

	-- Icon on top of the bar, floating at the left/starting position
	-- Created on meter frame with high draw layer to ensure visibility
	if iconPath then
		meter.icon = meter:CreateTexture(nil, "OVERLAY", nil, 7) -- Sub-layer 7 for highest priority
		meter.icon:SetSize(ICON_SIZE, ICON_SIZE)
		meter.icon:SetPoint("LEFT", meter.bar, "LEFT", 2, 0)
		meter.icon:SetTexture(iconPath)
		meter.icon:SetVertexColor(1, 1, 1, 1) -- Full white, full opacity
	end

	-- Glow frame (outlines the bar) - pass isAnguish to determine atlas color
	--meter.glow = CreateGlowFrame(meter, isAnguish)

	-- Percentage text (no label needed since icon identifies the bar)
	meter.percent = meter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	local fontPath = GetGeneralFont()
	if fontPath then
		meter.percent:SetFont(fontPath, 10, "OUTLINE")
	end
	meter.percent:SetPoint("RIGHT", meter.bar, "RIGHT", -4, 0)
	meter.percent:SetText("0%")
	meter.percent:SetTextColor(1, 1, 1, 0.9)

	return meter
end