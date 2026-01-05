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

DebugPanel.starving = DebugPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugPanel.starving:SetPoint("TOPLEFT", DebugPanel.eating, "BOTTOMLEFT", 0, 0)

DebugPanel:SetScript("OnShow", function(self)
	PlaySound(808)
end)

DebugPanel:SetScript("OnUpdate", function(self, elapsed)

	if not Addon.hungerCache then
		return
	end

	DebugPanel.playerName:SetText("Character: " .. Addon.playerCache.name)
	DebugPanel.playerLevel:SetText("Level: " .. Addon.playerCache.level)
	DebugPanel.health:SetText("Health: " .. floatToTwoString(Addon.playerCache.health, 0))
	DebugPanel.speed:SetText("Speed: " .. floatToTwoString(Addon.playerCache.speed, 2))

	DebugPanel.hunger:SetText("Hunger: " .. floatToTwoString(Addon.hungerCache.current, 3) .. " (" .. Addon.playerCache.activity .. " @" .. floatToTwoString(Addon.hungerCache.rate * 100, 1) .. "x)")
	DebugPanel.resting:SetText("Resting: " .. tostring(Addon.playerCache.resting))
	DebugPanel.eating:SetText("Eating: " .. tostring(Addon.playerCache.eating))

	local tts = ((100 - Addon.hungerCache.current) / 100) * (Addon.hungerCache.timeToStarveInHours or 1)

	local tts_hours = 0
	local tts_min = 0
	local tts_sec = 0
	local tts_ms = 0

	tts_hours, tts_min = math.modf(tts)
	tts_min, tts_sec = math.modf(tts_min * 60)
	tts_sec, tts_ms = math.modf(tts_sec * 60)

	--DebugPanel.starving:SetText("Starving in: " .. tts)
	DebugPanel.starving:SetText("Satiation: " .. floatToTwoString(tts * 100, 0) .. "% |> Starving in: " .. tts_hours .. "h " .. tts_min .. "m " .. tts_sec .. "s ")
end)

DebugPanel:SetScript("OnEvent", function(self, event, arg)
	if event == "PLAYER_ENTERING_WORLD" then
		DebugPanel:Show()
	end
end)

