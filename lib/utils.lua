function floatToTwoString(x, precision)
	precision = precision or 2
	local fmtStr = string.format("%%0.%sf", precision)
	return string.format(fmtStr, x)
end

function IsPlayerEating()
	-- Fast paths
	for auraName in pairs(EATING_AURAS) do
		if AuraByName(auraName) then
			return true
		end
	end

	-- Full scan
	return AnyHelpfulAuraMatches(function(aura)
		local name = aura.name
		if not name then
			return false
		end
		return EATING_AURAS[name] == true
	end)
end

-- Check if player is drinking
function IsPlayerDrinking()
	if AuraByName("Drink") or AuraByName("Food & Drink") or AuraByName("Refreshment") then
		return true
	end

	return AnyHelpfulAuraMatches(function(aura)
		local name = aura.name
		if not name then
			return false
		end
		return name == "Drink" or name == "Food & Drink" or name == "Refreshment"
	end)
end

------------------------------------------------------------
-- Retail-safe aura helpers (NO UnitBuff)
------------------------------------------------------------
function AuraByName(name)
	return AuraUtil.FindAuraByName(name, "player", "HELPFUL")
end

function AnyHelpfulAuraMatches(pred)
	local found = false
	AuraUtil.ForEachAura("player", "HELPFUL", nil, function(aura)
		if not aura then
			return
		end
		if pred(aura) then
			found = true
			return true -- stop iteration
		end
	end)
	return found
end

function GetMovementState()
	if UnitAffectingCombat("player") then
		return "combat"
	end

	if IsSwimming() then
		return "swimming"
	end

	local speed = GetPlayerProp("speed")

	if IsMounted() then
		if speed > 0 then
			if speed <= 3 then
				return "walking"
			else
				return IsFlying() and "flying" or "mounted"
			end
		else
			return "idle"
		end
	end

	if speed > 7 then
		return "running"
	elseif speed > 0 then
		return "walking"
	end

	return "idle"
end

--- @param prop string - name,level,health
function GetPlayerProp(prop)
	if prop == "name" then
		return UnitName("player") or "Player"
	end

	if prop == "level" then
		return UnitLevel("player") or 0
	end

	if prop == "health" then
		return UnitHealth("player") or 0
	end

	if prop == "speed" then
		local isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
		if canGlide and isGliding then
			return forwardSpeed or 0
		else
			return GetUnitSpeed("player") or 0
		end
	end
end

function Dump(o)
	if type(o) == 'table' then
		local s = COLORS.ERROR

		for k, v in pairs(o) do
			s = s .. "<br/> {" .. k .. " = " .. Dump(v) .. "},"
		end

		return s .. "|r"
	else
		return tostring(o)
	end
end

-- Debug (optimized with lookup tables)
function Debug(msg, category)
	category = category or "general"

	local settingKey = DEBUG_SETTINGS[category]
	local isCategoryOn = GetSetting(settingKey)

	if isCategoryOn then
		local color = DEBUG_COLORS[category] or DEBUG_COLORS.ADDON
		print(color .. Addon.name .. ":|r " .. msg)
	end
end

-- Callback System
function RegisterCallback(eventOrFunc, callback)
	if type(eventOrFunc) == "function" then
		if not Addon.callbacks["LEGACY"] then
			Addon.callbacks["LEGACY"] = {}
		end
		table.insert(Addon.callbacks["LEGACY"], eventOrFunc)
		return true
	end
	if type(callback) ~= "function" then
		return false
	end
	if not Addon.callbacks[eventOrFunc] then
		Addon.callbacks[eventOrFunc] = {}
	end
	table.insert(Addon.callbacks[eventOrFunc], callback)
	return true
end

function FireCallbacks(event, ...)
	if Addon.callbacks[event] then
		for _, callback in ipairs(Addon.callbacks[event]) do
			pcall(callback, ...)
		end
	end
	if event == "FIRE_STATE_CHANGED" and Addon.callbacks["LEGACY"] then
		for _, callback in ipairs(Addon.callbacks["LEGACY"]) do
			pcall(callback, Addon.isNearFire, Addon.inCombat)
		end
	end
end

function GetTexture(texture)
	local textureIndex = texture or GetSetting("meterBarTexture") or"default"
	return TEXTURES[textureIndex]
end

function GetFont(fontName)
	local fontIndex = fontName or GetSetting("generalFont") or "Default"
	return FONTS[fontIndex]
end

function hex_to_rgb_normalized(hex)
	-- Remove the # prefix if present
	hex = hex:gsub("#", "")

	-- Remove |cff prefix if present
	hex = hex:gsub("|cff", "")

	-- Parse the hex values for red, green, and blue
	local r, g, b = tonumber("0x" .. hex:sub(1, 2)), tonumber("0x" .. hex:sub(3, 4)), tonumber("0x" .. hex:sub(5, 6))

	-- Normalize to range [0, 1]
	return {r / 255, g / 255, b / 255}
end