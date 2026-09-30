-- Collectors/MythicPlus.lua
-- Mythic+-Daten des aktuellen Charakters: Season-Wertung, eigener Schluesselstein,
-- Season-Bestleistungen pro Dungeon und der Fortschritt der Grossen Schatzkammer.
--
-- Event-Strategie:
--   PLAYER_ENTERING_WORLD        -> RequestMythicPlusData + Vollscan entprellt
--   CHALLENGE_MODE_COMPLETED     -> Vollscan entprellt (neuer Run beendet)
--   CHALLENGE_MODE_MAPS_UPDATE   -> Vollscan entprellt (Serverdaten eingetroffen)
--   WEEKLY_REWARDS_UPDATE        -> Vollscan entprellt (Schatzkammer-Fortschritt)
--   BAG_UPDATE                   -> Vollscan entprellt (Keystone gewechselt/erhalten)

local _, Exo = ...

local Collector = {}
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.MythicPlus = Collector

local SCAN_DEBOUNCE_KEY = "mythicplus-scan"
local SCAN_DEBOUNCE = 1

Collector.Scan = function()
	if not Exo.Store:IsReady() then return end
	local W = Exo.WowAPI

	local data = {
		rating = W.GetMythicPlusRating(),
		keystone = nil,
		dungeons = {},
		vault = {},
	}

	local mapID, level = W.GetOwnedKeystone()
	if mapID then
		data.keystone = {
			mapID = mapID,
			level = level,
			name = W.GetChallengeMapName(mapID) or ("Map " .. mapID),
		}
	end

	for _, id in ipairs(W.GetMythicPlusMaps()) do
		local bestLevel, score, inTime = W.GetSeasonBestForMap(id)
		if bestLevel then
			data.dungeons[id] = {
				name = W.GetChallengeMapName(id) or ("Map " .. id),
				level = bestLevel,
				score = score,
				inTime = inTime,
			}
		end
	end

	for _, activity in ipairs(W.GetWeeklyRewardActivities()) do
		data.vault[#data.vault + 1] = {
			type = activity.type,
			index = activity.index,
			progress = activity.progress,
			threshold = activity.threshold,
			level = activity.level,
		}
	end

	-- Abhol-Erinnerung: Belohnungen der Vorwoche liegen bereit
	data.vaultRewards = W.HasAvailableVaultRewards()

	-- Wochen-Runs fuer den Schatzkammer-Tooltip: Anzahl + Top-Runs (Level absteigend)
	local history = W.GetMythicPlusRunHistory()
	data.runsThisWeek = #history
	local runs = {}
	for _, run in ipairs(history) do
		runs[#runs + 1] = {
			mapID = run.mapChallengeModeID,
			name = W.GetChallengeMapName(run.mapChallengeModeID)
				or ("Map " .. tostring(run.mapChallengeModeID)),
			level = run.level or 0,
			completed = run.completed and true or false,
		}
	end
	table.sort(runs, function(a, b)
		if a.level ~= b.level then return a.level > b.level end
		return a.name < b.name
	end)
	data.topRuns = {}
	for i = 1, math.min(8, #runs) do
		data.topRuns[i] = runs[i]
	end

	local Store = Exo.Store
	Store:WriteCharacterData(Store:GetCurrentKey(), "mythicplus", data)
end

local function debouncedScan()
	Exo.Scheduler:Debounce(SCAN_DEBOUNCE_KEY, SCAN_DEBOUNCE, Collector.Scan)
end

local Bus = Exo.EventBus

Bus:RegisterWowEvent("PLAYER_ENTERING_WORLD", function()
	Exo.WowAPI.RequestMythicPlusData()
	debouncedScan()
end, Collector)

Bus:RegisterWowEvent("CHALLENGE_MODE_COMPLETED", debouncedScan, Collector)
Bus:RegisterWowEvent("CHALLENGE_MODE_MAPS_UPDATE", debouncedScan, Collector)
Bus:RegisterWowEvent("WEEKLY_REWARDS_UPDATE", debouncedScan, Collector)
Bus:RegisterWowEvent("BAG_UPDATE", debouncedScan, Collector)
