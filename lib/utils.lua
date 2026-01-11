ONE_THIRD = 1 / 3

function Dump(value, precision)
	if type(value) == "number" then
		precision = precision or 2
		local fmtStr = string.format("%%0.%sf", precision)
		value = WithCommas(string.format(fmtStr, value))
	end

	if type(value) == "boolean" then
		local isTrue = (not not value) and "x" or " "
		value = "[" .. (isTrue) .. "]"
	end

	if type(value) == "table" then
		local nv = ""
		for key, v in pairs(value) do
			nv = nv .. Dump(key) .. "=" .. Dump(v)
		end
		value = nv
	end

	return tostring(value)
end

-- TODO: Move all these IsPlayer functions to it's own utils file
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

-- Check if player is near a campfire
function IsPlayerCamping()
	if AuraByName("Cozy Fire") then
		return true
	end

	return AnyHelpfulAuraMatches(function(aura)
		local name = aura.name
		if not name then
			return false
		end
		return name == "Cozy Fire"
	end)
end

function IsPlayerCultivating()
	return Addon.cultivationCache and Addon.cultivationCache.active
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

	if prop == "afk" then
		return UnitIsAFK("player") or false
	end

	if prop == "using_vehicle" then
		return UnitUsingVehicle("player") or false
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

-- Debug (optimized with lookup tables)
function Debug(msg, category)
	category = category or "general"

	local isCategoryOn = GetSetting("debug_" .. category)

	if isCategoryOn then
		local color = DEBUG_COLORS[category] or DEBUG_COLORS.ADDON
		print(color .. Addon.name .. ":|r " .. Dump(msg))
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
	local textureIndex = texture or GetSetting("meterBarTexture") or "default"
	return TEXTURES[textureIndex]
end

function GetFont(fontName)
	local fontIndex = fontName or GetSetting("generalFont") or "Default"
	return FONTS[fontIndex]
end

function hex_to_rgb_normalized(hex)
	if not hex or not (type(hex) == "string") then
		return { 1, 1, 1 }
	end

	-- Remove the # prefix if present
	hex = hex:gsub("#", "")

	-- Remove |cff prefix if present
	hex = hex:gsub("|cff", "")

	-- Parse the hex values for red, green, and blue
	local r, g, b = tonumber("0x" .. hex:sub(1, 2)), tonumber("0x" .. hex:sub(3, 4)), tonumber("0x" .. hex:sub(5, 6))

	-- Normalize to range [0, 1]
	return { r / 255, g / 255, b / 255 }
end

function indexOf(array, value)
	for i, v in ipairs(array) do
		if v == value then
			return i
		end
	end
	return nil
end

function RateAfterCultivation(rate)
	return CultivationMultipliers[GetCurrentMilestone()] / (60 * rate)
end

function Cultivate(turnOn)
	SetCharSetting("cultivation_active", turnOn)

	if turnOn then
		DoEmote("SIT")
	else
		DoEmote("STAND")
	end
end

function WithCommas(n)
	local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
	return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end
