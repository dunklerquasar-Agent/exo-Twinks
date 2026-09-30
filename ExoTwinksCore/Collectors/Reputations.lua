-- ExoTwinksCore/Collectors/Reputations.lua
-- Ruf-Staende (0.17.0): beim Einloggen und bei jeder Ruf-Aenderung
-- (UPDATE_FACTION, entprellt -- das Event feuert in Stuermen).
--
-- Datenlayout (Sektion "reputations"):
--   [factionID] = { name, standingID (1-8), value, max }

local Collector = {}
local _, Exo = ...
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Reputations = Collector

local SCAN_DEBOUNCE = 1.0

function Collector.Scan()
	local Store = Exo.Store
	if not Store:IsReady() then return end

	local result = {}
	for _, faction in ipairs(Exo.WowAPI.GetReputationList()) do
		result[faction.factionID] = {
			name = faction.name,
			standingID = faction.standingID,
			value = faction.value,
			max = faction.max,
		}
	end
	Store:WriteCharacterData(Store:GetCurrentKey(), "reputations", result)
end

-- Event-Verkabelung ---------------------------------------------------------------

local Bus = Exo.EventBus

local function debouncedScan()
	Exo.Scheduler:Debounce("reputations-scan", SCAN_DEBOUNCE, Collector.Scan)
end

Bus:RegisterWowEvent("PLAYER_ENTERING_WORLD", debouncedScan, Collector)
Bus:RegisterWowEvent("UPDATE_FACTION", debouncedScan, Collector)
