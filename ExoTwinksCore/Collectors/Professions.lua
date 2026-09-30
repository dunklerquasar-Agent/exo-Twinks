-- ExoTwinksCore/Collectors/Professions.lua
-- Berufe + Rezepte (0.15.0). Zwei Scans:
--   1. Berufs-Kopfdaten (Name, Skill x/y): beim Einloggen und bei
--      SKILL_LINES_CHANGED -- jederzeit verfuegbar.
--   2. Erlernte Rezepte: nur wenn das Berufsfenster offen ist
--      (TRADE_SKILL_LIST_UPDATE) -- WoW liefert die Liste nur dann.
-- Bereits gescannte Rezepte anderer Berufe bleiben beim Header-Scan erhalten.
--
-- Datenlayout (Sektion "professions"):
--   [skillLineID] = { name, rank, maxRank, recipes = { [recipeID] = name } }

local Collector = {}
local _, Exo = ...
Exo.Collectors = Exo.Collectors or {}
Exo.Collectors.Professions = Collector

local SCAN_DEBOUNCE = 0.5

local function currentProfessions()
	local char = Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	return (char and char.professions) or {}
end

function Collector.ScanHeaders()
	local Store = Exo.Store
	if not Store:IsReady() then return end

	local old = currentProfessions()
	local result = {}
	for _, prof in ipairs(Exo.WowAPI.GetProfessionList()) do
		local previous = old[prof.skillLineID]
		result[prof.skillLineID] = {
			name = prof.name,
			rank = prof.rank,
			maxRank = prof.maxRank,
			recipes = (previous and previous.recipes) or {},
		}
	end
	Store:WriteCharacterData(Store:GetCurrentKey(), "professions", result)
end

function Collector.ScanRecipes()
	local Store = Exo.Store
	if not Store:IsReady() then return end

	local skillLineID, recipes = Exo.WowAPI.GetOpenTradeSkill()
	if not skillLineID then return end

	local result = {}
	for id, prof in pairs(currentProfessions()) do
		result[id] = prof
	end
	local prof = result[skillLineID]
	if not prof then -- Fenster offen, Header noch nicht erfasst
		prof = { name = "?", rank = 0, maxRank = 0, recipes = {} }
		result[skillLineID] = prof
	end
	prof.recipes = {}
	for _, recipe in ipairs(recipes) do
		-- Seit 1.4.0 als Tabelle (Name + Pflicht-Reagenzien). Aeltere Daten
		-- sind reine Strings -- Leser unterstuetzen beide Formate; beim
		-- naechsten Berufsfenster-Besuch wird automatisch angereichert.
		prof.recipes[recipe.id] = { name = recipe.name, reagents = recipe.reagents }
	end
	Store:WriteCharacterData(Store:GetCurrentKey(), "professions", result)
end

-- Event-Verkabelung ---------------------------------------------------------------

local Bus = Exo.EventBus

local function debouncedHeaders()
	Exo.Scheduler:Debounce("professions-headers", SCAN_DEBOUNCE, Collector.ScanHeaders)
end

Bus:RegisterWowEvent("PLAYER_ENTERING_WORLD", debouncedHeaders, Collector)
Bus:RegisterWowEvent("SKILL_LINES_CHANGED", debouncedHeaders, Collector)

Bus:RegisterWowEvent("TRADE_SKILL_LIST_UPDATE", function()
	Exo.Scheduler:Debounce("professions-recipes", SCAN_DEBOUNCE, Collector.ScanRecipes)
end, Collector)
