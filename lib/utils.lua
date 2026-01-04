EATING_AURAS = {
	["Food"] = true,
	["Refreshment"] = true,
	["Food & Drink"] = true,
}

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
			return IsFlying() and "flying" or "mounted"
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
		return UnitName("player")
	end

	if prop == "level" then
		return UnitLevel("player")
	end

	if prop == "health" then
		return UnitHealth("player")
	end

	if prop == "speed" then
		local isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
		if canGlide and isGliding then
			return forwardSpeed
		else
			return GetUnitSpeed("player")
		end
	end
end