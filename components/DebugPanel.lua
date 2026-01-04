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
DebugPanel.playerLevel:SetPoint("TOPLEFT", DebugPanel.playerName, "BOTTOMLEFT", 0, 0)

DebugPanel.health = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.health:SetPoint("TOPLEFT", DebugPanel.playerLevel, "BOTTOMLEFT", 0, 0)

DebugPanel.speed = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.speed:SetPoint("TOPLEFT", DebugPanel.health, "BOTTOMLEFT", 0, 0)

DebugPanel.hunger = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.hunger:SetPoint("TOPLEFT", DebugPanel.speed, "BOTTOMLEFT", 0, 0)

DebugPanel.resting = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.resting:SetPoint("TOPLEFT", DebugPanel.hunger, "BOTTOMLEFT", 0, 0)

DebugPanel.eating = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.eating:SetPoint("TOPLEFT", DebugPanel.resting, "BOTTOMLEFT", 0, 0)

DebugPanel:SetScript("OnShow", function(self)
	PlaySound(808)
end)

DebugPanel:SetScript("OnUpdate", function(self)
	DebugPanel.playerName:SetText("Character: " .. PLAYER_STATE.name)
	DebugPanel.playerLevel:SetText("Level: " .. PLAYER_STATE.level)
	DebugPanel.health:SetText("Health: " .. floatToTwoString(PLAYER_STATE.health))
	DebugPanel.speed:SetText("Speed: " .. floatToTwoString(PLAYER_STATE.speed))

	DebugPanel.hunger:SetText("Hunger: " .. floatToTwoString(HUNGER.current or 0) .. " (" .. PLAYER_STATE.activity .. " @" .. floatToTwoString(HUNGER.rate, 4) .. "x)")
	DebugPanel.resting:SetText("Resting: " .. tostring(PLAYER_STATE.resting))
	DebugPanel.eating:SetText("Eating: " .. tostring(PLAYER_STATE.eating))
end)

DebugPanel:SetScript("OnEvent", function(self, event, arg)
	if event == "PLAYER_ENTERING_WORLD" then
		DebugPanel:Show()
	end
end)

