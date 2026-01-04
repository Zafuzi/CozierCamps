function floatToTwoString(x, precision)
	precision = precision or 2
	local fmtStr = string.format("%%0.%sf", precision)
	return string.format(fmtStr, x)
end

--function clamp(value, min, max)
--	return math.max(min, math.min(max, value))
--end
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