-- Collectors/InstanceLocks.lua
-- Erfasst gespeicherte Instanz-IDs (Schlachtzugs-Locks) des aktuellen Charakters.
--
-- Ablauf (eventgetrieben, wie /raidinfo):
--   PLAYER_ENTERING_WORLD / BOSS_KILL  -> RequestRaidInfo() (gedrosselt)
--   UPDATE_INSTANCE_INFO               -> Scan (entprellt, buendelt Event-Stuerme)
--
-- Gespeichert wird resetAt als ABSOLUTER Unix-Timestamp (Login-Zeit + Restsekunden),
-- damit die Anzeige auch fuer ausgeloggte Alts korrekt herunterzaehlt.

local _, Exo = ...

local Collector = {}
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.InstanceLocks = Collector

local REQUEST_THROTTLE = 5     -- Sekunden: RequestRaidInfo maximal alle 5s
local SCAN_DEBOUNCE = 1        -- Sekunden: UPDATE_INSTANCE_INFO-Stuerme buendeln

-- Scan -------------------------------------------------------------------------

function Collector.Scan()
	if not Exo.Store:IsReady() then return end

	local W = Exo.WowAPI
	local locks = {}

	for i = 1, W.GetNumSavedInstances() do
		local name, lockID, reset, difficultyID, locked, extended, _, isRaid,
			maxPlayers, difficultyName, numEncounters, encounterProgress = W.GetSavedInstanceInfo(i)

		if locked or extended then
			locks[#locks + 1] = {
				name = name,
				lockID = lockID,
				resetAt = W.Now() + (tonumber(reset) or 0),
				difficultyID = difficultyID,
				difficultyName = difficultyName or "",
				extended = not not extended,
				isRaid = not not isRaid,
				maxPlayers = maxPlayers or 0,
				bossesTotal = numEncounters or 0,
				bossesKilled = encounterProgress or 0,
			}
		end
	end

	Exo.Store:WriteCharacterData(Exo.Store:GetCurrentKey(), "instanceLocks", locks)
	Exo.Log:Debug("InstanceLocks: %d Lock(s) erfasst.", #locks)
end

-- Event-Verkabelung ---------------------------------------------------------------

local function requestRaidInfo()
	Exo.Scheduler:Throttle("instancelocks-request", REQUEST_THROTTLE, function()
		Exo.WowAPI.RequestRaidInfo()
	end)
end

Exo.EventBus:RegisterWowEvent("PLAYER_ENTERING_WORLD", requestRaidInfo, Collector)
Exo.EventBus:RegisterWowEvent("BOSS_KILL", requestRaidInfo, Collector)

Exo.EventBus:RegisterWowEvent("UPDATE_INSTANCE_INFO", function()
	Exo.Scheduler:Debounce("instancelocks-scan", SCAN_DEBOUNCE, Collector.Scan)
end, Collector)
