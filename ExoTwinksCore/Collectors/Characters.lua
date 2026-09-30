-- Collectors/Characters.lua (Neuimplementierung, Phase-2-Wiederholung)
-- Basisdaten des aktuellen Charakters: Level, Klasse, Zone, XP, Ruhebonus,
-- Gold und Gesamtspielzeit.
--
-- Event-Strategie:
--   PLAYER_ENTERING_WORLD  -> Vollscan + RequestTimePlayed (einmal pro Sitzung)
--   PLAYER_LEVEL_UP        -> Vollscan sofort (seltenes, wichtiges Event)
--   PLAYER_XP_UPDATE       -> Vollscan entprellt (feuert bei jedem Mob)
--   ZONE_CHANGED_NEW_AREA  -> Vollscan entprellt
--   PLAYER_MONEY           -> NUR Gold (billigster Pfad, sofort)
--   TIME_PLAYED_MSG        -> nur playedTotal
--   PLAYER_LOGOUT          -> nur lastSeen-Stempel

local _, Exo = ...

local Collector = {}
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Characters = Collector

local SCAN_DEBOUNCE_KEY = "characters-scan"
local SCAN_DEBOUNCE = 1

local playedRequested = false

-- Guard: fn laeuft nur, wenn der Store initialisiert ist
local function whenReady(fn)
	return function(...)
		if Exo.Store:IsReady() then
			return fn(...)
		end
	end
end

-- Kleiner Helfer: Meta des aktuellen Chars holen, veraendern, zurueckschreiben
local function updateMeta(mutator)
	local Store = Exo.Store
	local key = Store:GetCurrentKey()
	local meta = Store:GetCharacter(key).meta
	mutator(meta)
	Store:WriteCharacterData(key, "meta", meta)
end

-- Scans -----------------------------------------------------------------------

Collector.ScanGold = whenReady(function()
	local Store = Exo.Store
	Store:WriteCharacterData(Store:GetCurrentKey(), "gold", Exo.WowAPI.GetMoney())
end)

Collector.Scan = whenReady(function()
	local W = Exo.WowAPI

	updateMeta(function(meta)
		meta.name = W.GetPlayerName() or meta.name
		meta.realm = W.GetRealmName() or meta.realm
		meta.account = "Default"
		meta.level = W.GetPlayerLevel() or meta.level
		meta.classID = W.GetPlayerClassID() or meta.classID
		meta.raceID = W.GetPlayerRaceID() or meta.raceID
		meta.faction = W.GetPlayerFaction() or meta.faction
		meta.zone = W.GetZoneText() or meta.zone
		meta.guild = W.GetGuildName() or meta.guild or ""
		meta.lastSeen = W.Now()
		meta.xp = W.GetXP() or 0
		meta.xpMax = W.GetXPMax() or 0
		meta.restXP = W.GetRestXP()
		-- meta.playedTotal wird bewusst NICHT angefasst (gehoert TIME_PLAYED_MSG)
	end)

	Collector.ScanGold()
end)

-- Event-Verkabelung --------------------------------------------------------------

local Bus = Exo.EventBus

Bus:RegisterWowEvent("PLAYER_ENTERING_WORLD", function()
	Collector.Scan()
	if not playedRequested then
		playedRequested = true
		Exo.WowAPI.RequestTimePlayed()
	end
end, Collector)

Bus:RegisterWowEvent("PLAYER_LEVEL_UP", Collector.Scan, Collector)

Bus:RegisterWowEvent("PLAYER_XP_UPDATE", function()
	Exo.Scheduler:Debounce(SCAN_DEBOUNCE_KEY, SCAN_DEBOUNCE, Collector.Scan)
end, Collector)

Bus:RegisterWowEvent("ZONE_CHANGED_NEW_AREA", function()
	Exo.Scheduler:Debounce(SCAN_DEBOUNCE_KEY, SCAN_DEBOUNCE, Collector.Scan)
end, Collector)

Bus:RegisterWowEvent("PLAYER_MONEY", Collector.ScanGold, Collector)

Bus:RegisterWowEvent("TIME_PLAYED_MSG", whenReady(function(_, totalTime)
	updateMeta(function(meta)
		meta.playedTotal = tonumber(totalTime) or meta.playedTotal
	end)
end), Collector)

Bus:RegisterWowEvent("PLAYER_LOGOUT", whenReady(function()
	updateMeta(function(meta)
		meta.lastSeen = Exo.WowAPI.Now()
	end)
end), Collector)
