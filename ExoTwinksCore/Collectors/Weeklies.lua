-- Collectors/Weeklies.lua
-- Wochenaufgaben des aktuellen Charakters (SavedInstances-Ersatz):
-- prueft die in ExoTwinksData gepflegte Quest-Liste (Exo.Data.WeeklyQuests)
-- gegen C_QuestLog.IsQuestFlaggedCompleted und speichert erledigt/offen.
--
-- Die Liste ist saisonabhaengig und liegt bewusst im Data-Addon
-- (ExoTwinksData/Season.lua) - dort pro Saison pflegen.
--
-- Event-Strategie:
--   PLAYER_ENTERING_WORLD -> Scan entprellt
--   QUEST_TURNED_IN       -> Scan entprellt (Weekly gerade abgegeben)

local _, Exo = ...

local Collector = {}
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Weeklies = Collector

local SCAN_DEBOUNCE = 1

function Collector.Scan()
	local Store = Exo.Store
	if not Store:IsReady() then return end

	local quests = (Exo.Data and Exo.Data.WeeklyQuests) or {}
	local weeklies = {}
	for _, quest in ipairs(quests) do
		if quest.id then
			weeklies[quest.id] = Exo.WowAPI.IsQuestCompleted(quest.id)
		end
	end

	Store:WriteCharacterData(Store:GetCurrentKey(), "weeklies", weeklies)
end

local function debouncedScan()
	Exo.Scheduler:Debounce("weeklies-scan", SCAN_DEBOUNCE, Collector.Scan)
end

Exo.EventBus:RegisterWowEvent("PLAYER_ENTERING_WORLD", debouncedScan, Collector)
Exo.EventBus:RegisterWowEvent("QUEST_TURNED_IN", debouncedScan, Collector)
