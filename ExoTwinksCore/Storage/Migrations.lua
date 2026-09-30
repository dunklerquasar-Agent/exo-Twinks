-- Storage/Migrations.lua
-- Migrations-Registry + Runner.
-- Regeln:
--  * Migrationen sind nummeriert (1, 2, 3, ...) und laufen strikt aufsteigend.
--  * Jede Migration ist idempotent formuliert (mehrfaches Ausfuehren schadet nicht).
--  * Der Runner setzt db.schemaVersion NACH jeder erfolgreichen Migration
--    -> ein Absturz mittendrin laesst die DB in einem definierten Zustand.
--  * Eine DB mit HOEHERER Version als bekannt wird NICHT angefasst (Downgrade-Schutz).

local _, Exo = ...

local Migrations = {}
Exo.Migrations = Migrations

local registry = {}   -- version -> { name = string, fn = function(db) }

function Migrations:Register(version, name, fn)
	assert(type(version) == "number" and version > 0, "Migration: version muss > 0 sein")
	assert(type(fn) == "function", "Migration: fn muss eine Funktion sein")
	assert(registry[version] == nil,
		string.format("Migration %d ist bereits registriert (%s)", version, registry[version] and registry[version].name or "?"))
	registry[version] = { name = name or ("migration-" .. version), fn = fn }
end

function Migrations:LatestVersion()
	local latest = 0
	for version in pairs(registry) do
		if version > latest then
			latest = version
		end
	end
	return latest
end

-- Fuehrt alle ausstehenden Migrationen aus.
-- Rueckgabe: applied (Anzahl), err (nil oder Fehlertext)
function Migrations:Run(db)
	assert(type(db) == "table", "Migrations:Run: db muss eine Table sein")
	db.schemaVersion = db.schemaVersion or 0

	local latest = self:LatestVersion()

	-- Downgrade-Schutz: DB stammt von einer neueren Addon-Version
	if db.schemaVersion > latest then
		Exo.Log:Warn(
			"ExoTwinksDB hat Schema v%d, dieses Addon kennt nur v%d - Daten werden nicht angefasst. Bitte Addon aktualisieren.",
			db.schemaVersion, latest)
		return 0, "db-neuer-als-addon"
	end

	local applied = 0
	for version = db.schemaVersion + 1, latest do
		local migration = registry[version]
		if not migration then
			return applied, string.format("Migration %d fehlt (Luecke in der Registry)", version)
		end

		local ok, err = pcall(migration.fn, db)
		if not ok then
			Exo.Log:Error("Migration %d (%s) fehlgeschlagen: %s", version, migration.name, tostring(err))
			return applied, tostring(err)
		end

		db.schemaVersion = version
		applied = applied + 1
		Exo.Log:Info("Migration %d (%s) angewendet.", version, migration.name)
	end

	return applied, nil
end

-- Nur fuer Tests: Registry zuruecksetzen
function Migrations:_ResetRegistry()
	registry = {}
end
