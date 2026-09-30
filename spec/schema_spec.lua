-- spec/schema_spec.lua
local mock = require("spec.wow_mock")

describe("Schema", function()
	local Exo, Schema

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		Schema = Exo.Schema
	end)

	describe("ApplyDefaults", function()
		it("fuellt fehlende Keys rekursiv auf", function()
			local t = Schema.ApplyDefaults({}, Schema.charDefaults)
			assert.equal(0, t.gold)
			assert.equal("", t.meta.name)
			assert.same({}, t.bags)
		end)

		it("ueberschreibt vorhandene Werte NIE (non-destruktiv)", function()
			local t = { gold = 999, meta = { name = "Bestand" } }
			Schema.ApplyDefaults(t, Schema.charDefaults)
			assert.equal(999, t.gold)
			assert.equal("Bestand", t.meta.name)
			assert.equal(0, t.meta.level) -- fehlender Key wurde ergaenzt
		end)

		it("Default-Tables werden kopiert, nicht geteilt (kein Alias!)", function()
			local a = Schema.NewCharacter()
			local b = Schema.NewCharacter()
			a.bags[1] = { size = 16 }
			assert.is_nil(b.bags[1])
			assert.same({}, Schema.charDefaults.bags) -- Defaults selbst unveraendert
		end)

		it("repariert falsch-typisierte Felder (String statt Table)", function()
			local t = { bags = "kaputt" }
			Schema.ApplyDefaults(t, Schema.charDefaults)
			assert.same({}, t.bags)
		end)
	end)

	describe("CharKey", function()
		it("baut und zerlegt Keys symmetrisch", function()
			local key = Schema.BuildCharKey("Default", "Die Aldor", "Xyz")
			assert.equal("Default.Die Aldor.Xyz", key)

			local account, realm, name = Schema.ParseCharKey(key)
			assert.equal("Default", account)
			assert.equal("Die Aldor", realm)
			assert.equal("Xyz", name)
		end)

		it("liefert nil bei kaputten Keys", function()
			assert.is_nil(Schema.ParseCharKey("nur-ein-teil"))
		end)
	end)

	it("VERSION entspricht der hoechsten registrierten Migration", function()
		assert.equal(Schema.VERSION, Exo.Migrations:LatestVersion())
	end)
end)
