-- Storage/Schema.lua
-- Deklariertes SavedVariables-Schema. Eine einzige Quelle der Wahrheit fuer
-- die Struktur von ExoTwinksDB. Migrationen veraendern die Struktur, das
-- Schema hier beschreibt immer den AKTUELLEN Zielzustand.
--
-- Designentscheidungen (bewusst anders als das Original):
--  * Klartext-Felder statt Bit-Packing (lesbar, debugbar, diffbar)
--  * itemID + count statt vollstaendiger ItemLinks wo moeglich (SV-Groesse)
--  * ein Sub-Table pro Collector -> Collector besitzt "seinen" Teilbaum

local _, Exo = ...

local Schema = {
	-- Aktuelle Schema-Version. Muss der hoechsten registrierten Migration entsprechen.
	VERSION = 1,
}
Exo.Schema = Schema

-- Wurzelstruktur von ExoTwinksDB ------------------------------------------------

Schema.rootDefaults = {
	-- schemaVersion wird ausschliesslich vom Migrations-Runner gesetzt
	chars = {},     -- ["Account.Realm.Name"] = char-Table (s.u.)
	guilds = {},    -- ["Account.Realm.Gildenname"] = guild-Table
	account = {
		options = {},
		warbandBank = {},   -- Kriegsmeutenbank (accountweit)
	},
}

-- Struktur eines Charakter-Eintrags ---------------------------------------------

Schema.charDefaults = {
	meta = {
		name = "",
		realm = "",
		account = "Default",
		level = 0,
		classID = 0,        -- numerische ID; Anzeige-Name kommt zur Laufzeit via C_CreatureInfo
		raceID = 0,
		faction = "",       -- "Alliance" | "Horde" | "Neutral" | ""
		zone = "",
		guild = "",         -- Gildenname (fuer Gildensteuer u. a.)
		lastSeen = 0,       -- Unix-Timestamp des letzten Logins/Logouts
		playedTotal = 0,    -- Sekunden Gesamtspielzeit
		xp = 0,
		xpMax = 0,
		restXP = 0,
	},
	gold = 0,               -- in Kupfer
	bags = {},              -- [bagID 0-5] = { size = n, items = { [slot] = { id, count } } }
	bank = {},              -- [bagID -1, 6-12] = wie bags (nur bei Bankbesuch aktualisiert)
	currencies = {},        -- [currencyID] = { name, qty, max }
	weeklies = {},          -- [questID] = true/false (erledigt diese Woche)
	professions = {},       -- [skillLineID] = { rank, maxRank, recipes = {} }
	mails = {},             -- Phase 5
	quests = {},            -- Phase 5
	reputations = {},       -- Phase 5
	guildtax = {},          -- { income, owed } in Kupfer (Gildensteuer, 1.2.0)
	auctions = {},          -- Phase 5
	equipment = {},         -- { avgItemLevel, avgItemLevelEquipped, slots = { [slot] = { id, ilvl } } }
	mythicplus = {},        -- { rating, keystone = {mapID,name,level},
	                        --   dungeons = {[mapID]={name,level,score,inTime}},
	                        --   vault = { {type,index,progress,threshold,level} } }
	instanceLocks = {},     -- Array: { name, lockID, resetAt, difficultyID, difficultyName,
	                        --          extended, isRaid, maxPlayers, bossesKilled, bossesTotal }
}

-- Helfer -------------------------------------------------------------------------

-- Fuellt fehlende Keys in target rekursiv mit (Kopien der) Defaults auf.
-- Vorhandene Werte werden NIE ueberschrieben (non-destruktiv).
function Schema.ApplyDefaults(target, defaults)
	assert(type(target) == "table", "Schema.ApplyDefaults: target muss eine Table sein")
	for key, defaultValue in pairs(defaults) do
		if type(defaultValue) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			Schema.ApplyDefaults(target[key], defaultValue)
		elseif target[key] == nil then
			target[key] = defaultValue
		end
	end
	return target
end

-- Erzeugt einen frischen Charakter-Eintrag nach aktuellem Schema
function Schema.NewCharacter()
	return Schema.ApplyDefaults({}, Schema.charDefaults)
end

-- Baut den kanonischen Charakter-Key
function Schema.BuildCharKey(account, realm, name)
	return string.format("%s.%s.%s", account or "Default", realm, name)
end

-- Zerlegt einen Charakter-Key (Realm-Namen koennen Leerzeichen enthalten,
-- aber keine Punkte -- gleiche Annahme wie im Original)
function Schema.ParseCharKey(key)
	local account, realm, name = string.match(key, "^([^.]+)%.([^.]+)%.([^.]+)$")
	return account, realm, name
end
