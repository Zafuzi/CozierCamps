MetersContainer = nil
function OpenMeters()
	MetersContainer = OpenModal("Meters", METER_WIDTH, METER_HEIGHT, UIParent, { isMovable = true })
	MetersContainer:SetPoint("TOPLEFT", UIParent, "CENTER", 0, 0)
	MetersContainer.isFirstRun = true

	HungerMeter = CreateMeter("Hunger", MetersContainer, ICONS.food, COLORS.HUNGER)
	HungerMeter:SetPoint("TOPLEFT", MetersContainer, "TOPLEFT", METER_PADDING, -METER_PADDING)
	HungerMeter:SetScript("OnUpdate", function(self, elapsed)
		UpdateHungerMeter(elapsed)
	end)

	ThirstMeter = CreateMeter("Thirst", MetersContainer, ICONS.drink, COLORS.THIRST)
	ThirstMeter:SetPoint("TOPLEFT", HungerMeter, "BOTTOMLEFT", 0, -METER_PADDING)
	ThirstMeter:SetScript("OnUpdate", function(self, elapsed)
		UpdateThirstMeter(elapsed)
	end)

	CultivationMeter = CreateMeter("Cultivation", MetersContainer, ICONS.cultivation, Cultivation_colors[1])
	CultivationMeter:SetPoint("TOPLEFT", ThirstMeter, "BOTTOMLEFT", 0, -METER_PADDING)
	CultivationMeter:SetScript("OnUpdate", function(self, elapsed)
		local color = Addon.cultivationCache.color
		CultivationMeter:UpdateBgColor(color)

		UpdateCultivationMeter(elapsed)
	end)

	SetupCultivationTooltip(CultivationMeter)


	local children = #{ MetersContainer:GetChildren() }
	MetersContainer:SetWidth(METER_WIDTH + (METER_PADDING * 2))
	MetersContainer:SetHeight((children * METER_HEIGHT) + (children * METER_PADDING) + (METER_PADDING * 2))
	MetersContainer:Show()

	MetersContainer:SetScript("OnUpdate", function(self)
		if MetersContainer.isFirstRun then
			MetersContainer.isFirstRun = false
		end
	end)
end
