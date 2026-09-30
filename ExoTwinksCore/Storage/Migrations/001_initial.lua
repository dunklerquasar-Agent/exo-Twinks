-- Storage/Migrations/001_initial.lua
-- v0 -> v1: legt die Wurzelstruktur an (chars/guilds/account).
-- Idempotent: ApplyDefaults ueberschreibt nie vorhandene Daten.

local _, Exo = ...

Exo.Migrations:Register(1, "initial-schema", function(db)
	Exo.Schema.ApplyDefaults(db, Exo.Schema.rootDefaults)
end)
