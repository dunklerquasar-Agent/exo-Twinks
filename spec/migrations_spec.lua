-- spec/migrations_spec.lua
local mock = require("spec.wow_mock")

describe("Migrations", function()
	local Exo, M

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		M = Exo.Migrations
	end)

	it("frische DB (v0) wird auf die aktuelle Version migriert", function()
		local db = {}
		local applied, err = M:Run(db)

		assert.is_nil(err)
		assert.equal(M:LatestVersion(), db.schemaVersion)
		assert.equal(M:LatestVersion(), applied)
		-- Migration 001 hat die Wurzelstruktur angelegt:
		assert.is_table(db.chars)
		assert.is_table(db.guilds)
		assert.is_table(db.account.options)
	end)

	it("erneutes Ausfuehren ist ein No-Op (idempotent)", function()
		local db = {}
		M:Run(db)
		db.chars["Default.R.X"] = { gold = 5 }

		local applied, err = M:Run(db)

		assert.is_nil(err)
		assert.equal(0, applied)
		assert.equal(5, db.chars["Default.R.X"].gold) -- Daten unangetastet
	end)

	it("DB von einer NEUEREN Addon-Version wird nicht angefasst", function()
		local db = { schemaVersion = 99, chars = { wichtig = true } }
		local applied, err = M:Run(db)

		assert.equal(0, applied)
		assert.equal("db-neuer-als-addon", err)
		assert.equal(99, db.schemaVersion)
		assert.is_true(db.chars.wichtig)
	end)

	it("doppelte Registrierung derselben Version wirft", function()
		assert.has_error(function()
			M:Register(1, "doppelt", function() end)
		end)
	end)

	it("Luecke in der Registry wird als Fehler gemeldet", function()
		M:Register(Exo.Schema.VERSION + 2, "mit-luecke", function() end) -- +1 fehlt
		local db = {}
		local _, err = M:Run(db)
		assert.truthy(err and err:find("fehlt"))
	end)

	it("werfende Migration stoppt den Lauf, Version bleibt konsistent", function()
		M:Register(Exo.Schema.VERSION + 1, "kaputt", function() error("boom") end)
		local db = {}
		local applied, err = M:Run(db)

		assert.truthy(err)
		assert.equal(Exo.Schema.VERSION, db.schemaVersion) -- alle davor liefen sauber
		assert.equal(Exo.Schema.VERSION, applied)
	end)
end)
