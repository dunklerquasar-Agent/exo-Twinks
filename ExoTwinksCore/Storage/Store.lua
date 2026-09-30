-- Storage/Store.lua
-- EINZIGER Zugriffspunkt auf SavedVariables (ExoTwinksDB).
-- Collectors schreiben, API/UI lesen -- beide ausschliesslich hierueber.
-- Regel 2 der Architektur: UI liest niemals SavedVariables direkt.

local _, Exo = ...

local Store = {}
Exo.Store = Store

local db          -- Referenz auf ExoTwinksDB (nach Init)
local currentKey  -- Key des eingeloggten Charakters

local function assertReady()
	assert(db, "Store: noch nicht initialisiert (Init laeuft bei ADDON_LOADED)")
end

-- Initialisierung ---------------------------------------------------------------
-- Wird von Core/Init.lua bei ADDON_LOADED aufgerufen.
-- Nimmt die (moeglicherweise nil) SavedVariables entgegen und gibt die
-- fertig migrierte DB zurueck, die Init wieder in die Global schreibt.

function Store:Init(savedVariables)
	db = savedVariables or {}

	-- 1. Migrationen (legen bei frischer DB auch die Wurzelstruktur an)
	local applied, err = Exo.Migrations:Run(db)
	if err then
		Exo.Log:Error("Store:Init: Migrationsfehler: %s", tostring(err))
	elseif applied > 0 then
		Exo.Log:Info("Store: %d Migration(en) angewendet, Schema v%d.", applied, db.schemaVersion)
	end

	-- 2. Defaults auffuellen (nach Addon-Updates koennen neue Felder dazukommen)
	Exo.Schema.ApplyDefaults(db, Exo.Schema.rootDefaults)
	for _, char in pairs(db.chars) do
		Exo.Schema.ApplyDefaults(char, Exo.Schema.charDefaults)
	end

	-- 3. aktuellen Charakter registrieren und Basis-Meta aktualisieren
	local W = Exo.WowAPI
	currentKey = Exo.Schema.BuildCharKey("Default", W.GetRealmName(), W.GetPlayerName())

	local char = self:GetOrCreateCharacter(currentKey)
	local meta = char.meta
	meta.name = W.GetPlayerName()
	meta.realm = W.GetRealmName()
	meta.account = "Default"
	meta.faction = W.GetPlayerFaction() or meta.faction
	meta.lastSeen = W.Now()

	Exo.EventBus:Fire("EXO_STORE_READY", currentKey)
	return db
end

-- Zugriff -------------------------------------------------------------------------

function Store:IsReady()
	return db ~= nil
end

function Store:GetCurrentKey()
	assertReady()
	return currentKey
end

function Store:GetCharacter(charKey)
	assertReady()
	return db.chars[charKey]
end

function Store:GetOrCreateCharacter(charKey)
	assertReady()
	local char = db.chars[charKey]
	if not char then
		char = Exo.Schema.NewCharacter()
		db.chars[charKey] = char
		Exo.EventBus:Fire("EXO_CHAR_ADDED", charKey)
	end
	return char
end

function Store:DeleteCharacter(charKey)
	assertReady()
	if db.chars[charKey] then
		db.chars[charKey] = nil
		Exo.EventBus:Fire("EXO_CHAR_DELETED", charKey)
		return true
	end
	return false
end

-- Sortierte Liste aller Charakter-Keys (stabil fuer UI-Anzeige)
function Store:GetCharacterKeys()
	assertReady()
	local keys = {}
	for key in pairs(db.chars) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

function Store:CountCharacters()
	assertReady()
	local n = 0
	for _ in pairs(db.chars) do
		n = n + 1
	end
	return n
end

function Store:GetAccount()
	assertReady()
	return db.account
end

-- Schreib-Helfer fuer Collectors ----------------------------------------------------
-- Collector schreibt seinen Teilbaum und meldet die Aenderung als Event.
-- Beispiel: Store:WriteCharacterData(key, "gold", 123456)

function Store:WriteCharacterData(charKey, section, data)
	assertReady()
	local char = self:GetOrCreateCharacter(charKey)
	assert(Exo.Schema.charDefaults[section] ~= nil,
		string.format("Store: unbekannte Sektion '%s' (nicht im Schema deklariert)", tostring(section)))
	char[section] = data
	Exo.EventBus:Fire("EXO_CHAR_UPDATED", charKey, section)
end

-- Accountweite Daten (z.B. Kriegsmeutenbank)
function Store:WriteAccountData(section, data)
	assertReady()
	assert(Exo.Schema.rootDefaults.account[section] ~= nil,
		string.format("Store: unbekannte Account-Sektion '%s' (nicht im Schema deklariert)", tostring(section)))
	db.account[section] = data
	Exo.EventBus:Fire("EXO_ACCOUNT_UPDATED", section)
end

-- Gildenbank (0.16.0): pro Gilde ein Eintrag { name, bank = BagSet, scannedAt }
function Store:GetGuilds()
	assertReady()
	return db.guilds
end

function Store:WriteGuildBank(guildName, bank)
	assertReady()
	local guild = db.guilds[guildName] or { name = guildName }
	guild.bank = bank
	guild.scannedAt = Exo.WowAPI.Now()
	db.guilds[guildName] = guild
	Exo.EventBus:Fire("EXO_GUILD_UPDATED", guildName)
end

-- Nur fuer Tests
function Store:_Reset()
	db = nil
	currentKey = nil
end
