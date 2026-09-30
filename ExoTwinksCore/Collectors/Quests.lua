-- ExoTwinksCore/Collectors/Quests.lua
-- Questlog (0.17.0): aktive Quests des eingeloggten Charakters, beim
-- Einloggen und bei jeder Questlog-Aenderung (entprellt).
--
-- Datenlayout (Sektion "quests"): [questID] = title

local Collector = {}
local _, Exo = ...
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Quests = Collector

local SCAN_DEBOUNCE = 1.0

function Collector.Scan()
	local Store = Exo.Store
	if not Store:IsReady() then return end
	Store:WriteCharacterData(Store:GetCurrentKey(), "quests", Exo.WowAPI.GetQuestLog())
end

-- Event-Verkabelung ---------------------------------------------------------------

local Bus = Exo.EventBus

local function debouncedScan()
	Exo.Scheduler:Debounce("quests-scan", SCAN_DEBOUNCE, Collector.Scan)
end

Bus:RegisterWowEvent("PLAYER_ENTERING_WORLD", debouncedScan, Collector)
Bus:RegisterWowEvent("QUEST_LOG_UPDATE", debouncedScan, Collector)
