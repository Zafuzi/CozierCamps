-- CozierCamps - Logger.lua
-- Fire coordinate logging for building FireDB
-- Updated for Midnight (Retail 12.0.1 / Interface 120001) compatibility

CozierCampsLoggedFires = CozierCampsLoggedFires or {}

local OVERLAP_YARDS = 3
local OVERLAP_MAP_UNITS = OVERLAP_YARDS * 0.001
local overlapCheckEnabled = true -- Toggle for overlap checking

------------------------------------------------------------
-- Midnight-safe mountability check
-- Retail may not provide IsIndoors() anymore; prefer IsOutdoors() when available.
------------------------------------------------------------
local function CanPlayerMount()
-- If we can reliably detect outdoors, use that.
	if type(IsOutdoors) == "function" then
		if not IsOutdoors() then
			return false
		end
	elseif type(IsIndoors) == "function" then
		if IsIndoors() then
			return false
		end
	end

	-- Swimming check (still relevant)
	if IsSwimming() then
		return false
	end

	-- If unknown, treat as mountable (logger should not block).
	return true
end

local function GetNormalizedDesc(desc, subZone)
	desc = tostring(desc or "")
	subZone = tostring(subZone or "")

	desc = desc:gsub("^%s+", ""):gsub("%s+$", "")
	if desc ~= "" then
		return desc
	end
	if subZone ~= "" then
		return subZone
	end
	return "fire"
end

local function LogFire(desc, noMount)
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then
		print("|cffFF0000CozierCamps:|r No map ID.")
		return
	end

	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then
		print("|cffFF0000CozierCamps:|r No position.")
		return
	end

	local zone = GetZoneText() or "Unknown Zone"
	local subZone = GetSubZoneText() or ""

	local actualDesc = GetNormalizedDesc(desc, subZone)

	-- Store in "percent" coords like your FireDB (0-100 with 2 decimals)
	local newX = (pos.x or 0) * 100
	local newY = (pos.y or 0) * 100

	-- Overlap check (within 3 yards)
	if overlapCheckEnabled and CozierCampsLoggedFires[zone] then
		for _, existing in ipairs(CozierCampsLoggedFires[zone]) do
			local ex = (tonumber(existing.x) or 0)
			local ey = (tonumber(existing.y) or 0)

			local dx = (ex - newX) / 100
			local dy = (ey - newY) / 100
			local dist = math.sqrt(dx * dx + dy * dy)

			if dist < OVERLAP_MAP_UNITS then
				local distYards = dist / 0.001
				print(string.format("|cffFFAA00CozierCamps:|r Fire already logged %.1f yards away.", distYards))
				return
			end
		end
	end

	local entry = {
		zone = zone,
		subZone = subZone,
		x = math.floor(newX * 100) / 100,
		y = math.floor(newY * 100) / 100,
		description = actualDesc,
		timestamp = date("%Y-%m-%d %H:%M:%S")
	}

	if noMount then
		entry.noMount = true
	end

	CozierCampsLoggedFires[zone] = CozierCampsLoggedFires[zone] or {}
	table.insert(CozierCampsLoggedFires[zone], entry)

	local mountStatus = ""
	if noMount then
		mountStatus = " |cffFF6600[NO MOUNT]|r"
	elseif not CanPlayerMount() then
		mountStatus = " |cffFFFF00(can't mount here)|r"
	end

	print("|cff00FF00CozierCamps:|r Fire logged!" .. mountStatus)
	print(string.format("  %s (%.2f, %.2f) - %s", zone, entry.x, entry.y, actualDesc))
	print("|cff888888Use /logfire export to view all. /reload to save.|r")
end

local function Export()
	local count = 0
	local zones = {}

	for z in pairs(CozierCampsLoggedFires) do
		table.insert(zones, z)
	end
	table.sort(zones)

	print("|cff88CCFF=== CozierCamps Fire Export ===|r")
	print("-- Copy this to FireDB.lua --")

	for _, z in ipairs(zones) do
		local fires = CozierCampsLoggedFires[z]
		if fires and #fires > 0 then
			print(string.format('    ["%s"] = {', z))
			for _, f in ipairs(fires) do
				local x = tonumber(f.x) or 0
				local y = tonumber(f.y) or 0
				local d = tostring(f.description or "fire"):gsub('"', '\\"') -- basic escape

				if f.noMount then
					print(string.format('        { x = %.2f, y = %.2f, description = "%s", noMount = true },', x, y, d))
				else
					print(string.format('        { x = %.2f, y = %.2f, description = "%s" },', x, y, d))
				end
				count = count + 1
			end
			print('    },')
		end
	end

	print(string.format("|cff00FF00Total: %d fires|r", count))
end

SLASH_LOGFIRE1 = "/logfire"

SlashCmdList["LOGFIRE"] = function(msg)
	msg = msg or ""

	local cmd = msg:match("^(%S*)") or ""
	local rest = msg:match("^%S*%s*(.*)") or ""
	cmd = string.lower(cmd or "")

	if cmd == "export" then
		Export()

	elseif cmd == "clear" then
		CozierCampsLoggedFires = {}
		print("|cff88CCFFCozierCamps:|r Fire log cleared.")

	elseif cmd == "count" then
		local c = 0
		for _, fires in pairs(CozierCampsLoggedFires) do
			c = c + (fires and #fires or 0)
		end
		print(string.format("|cff88CCFFCozierCamps:|r %d fires logged.", c))

	elseif cmd == "help" then
		print("|cff88CCFF=== Fire Logger Commands ===|r")
		print("|cffffff00/logfire|r - Log fire at current position")
		print("|cffffff00/logfire <desc>|r - Log with description")
		print("|cffffff00/logfire nomount|r - Log fire as no-mount spot")
		print("|cffffff00/logfire nomount <desc>|r - Log no-mount with description")
		print("|cffffff00/logfire export|r - Show all logged fires")
		print("|cffffff00/logfire count|r - Show fire count")
		print("|cffffff00/logfire clear|r - Clear all logged fires")
		print("|cffffff00/logfire overlap|r - Toggle overlap checking (currently " ..
		(overlapCheckEnabled and "ON" or "OFF") .. ")")

	elseif cmd == "overlap" then
		overlapCheckEnabled = not overlapCheckEnabled
		print("|cff88CCFFCozierCamps:|r Overlap checking " ..
		(overlapCheckEnabled and "|cff00FF00ON|r" or "|cffFF6600OFF|r"))

	elseif cmd == "nomount" then
		LogFire(rest, true)

	else
		LogFire(msg, false)
	end
end
