local config = {
	name = "DebugPanel",
	width = 500,
	height = 350,
	color = COLORS.headerColor,
	backgroundColor = COLORS.cardBg,
	borderColor = COLORS.cardBorder,
}

DebugPanel = OpenModal(config.name, config.width, config.height)
DebugPanel:RegisterEvent("PLAYER_ENTERING_WORLD")

DebugPanel.playerName = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.playerName:SetPoint("TOPLEFT", DebugPanel, "TOPLEFT", 15, -35)

DebugPanel.playerLevel = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.playerLevel:SetPoint("TOPLEFT", DebugPanel, "TOPLEFT", 15, -50)

DebugPanel.health = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.health:SetPoint("TOPLEFT", DebugPanel, "TOPLEFT", 15, -65)

DebugPanel.speed = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.speed:SetPoint("TOPLEFT", DebugPanel, "TOPLEFT", 15, -80)

DebugPanel.hunger = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.hunger:SetPoint("TOPLEFT", DebugPanel, "TOPLEFT", 15, -95)

DebugPanelChild = OpenModal("DebugPanelChild", config.width, config.height, DebugPanel)

DebugPanel:SetScript("OnShow", function(self)
	PlaySound(808)
end)

DebugPanel:SetScript("OnUpdate", function(self)
	DebugPanel.playerName:SetText("Character: " .. GetPlayerProp("name"))
	DebugPanel.playerLevel:SetText("Level: " .. GetPlayerProp("level"))
	DebugPanel.health:SetText("Health: " .. GetPlayerProp("health"))
	DebugPanel.speed:SetText("Speed: " .. GetPlayerProp("speed"))

	DebugPanel.hunger:SetText("Hunger: " .. string.format("%.2f%%", HUNGER.current or 0) .. " (" .. HUNGER.state .. " x" .. HUNGER.rate .. ")")
end)

DebugPanel:SetScript("OnEvent", function(self, event, arg)
	if event == "PLAYER_ENTERING_WORLD" then
		DebugPanel:Show()
	end
end)

