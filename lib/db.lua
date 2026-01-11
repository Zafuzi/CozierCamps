local f = CreateFrame("Frame", Addon.name .. " - DB")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg)
	if (event == "ADDON_LOADED" and arg == Addon.name) or event == "SETTINGS_CHANGED" then
		if not CultivationDB then
			CultivationDB = {}
			print("Creating CultivationDB: " .. unpack(DEFAULT_SETTINGS))
		end

		Addon.DB = CultivationDB

		for key, default in pairs(DEFAULT_SETTINGS) do
			if Addon.DB[key] == nil then
				Addon.DB[key] = default
			end
		end

		if not CultivationCharDB then
			CultivationCharDB = {}
			print("Creating CultivationCharDB: " .. unpack(DEFAULT_CHAR_SETTINGS))
		end

		Addon.CharDB = CultivationCharDB

		for key, default in pairs(DEFAULT_CHAR_SETTINGS) do
			if Addon.CharDB[key] == nil then
				Debug("resetting " .. tostring(key) .. " to default " .. tostring(default))
				Addon.CharDB[key] = default
			end
		end
	end
end)

function SetSetting(key, value)
	if Addon.DB then
		Addon.DB[key] = value
	end
end

function ResetSettings()
	Debug("RESETTING ALL SETTINGS")
	for key, value in pairs(DEFAULT_SETTINGS) do
		Addon.DB[key] = value
	end

	for key, value in pairs(DEFAULT_CHAR_SETTINGS) do
		Addon.CharDB[key] = value
	end

	FireCallbacks("SETTINGS_CHANGED", "ALL", nil)
end

function GetDefaultSetting(key)
	return DEFAULT_SETTINGS[key]
end

function GetSetting(key)
	if Addon.DB then
		return Addon.DB[key]
	end

	return nil
end

function GetCharSetting(key)
	if Addon.CharDB then
		return Addon.CharDB[key]
	end

	return nil
end

function SetCharSetting(key, value)
	if Addon.CharDB then
		Addon.CharDB[key] = value
	end
end
