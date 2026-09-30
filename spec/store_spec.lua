-- spec/store_spec.lua
local mock = require("spec.wow_mock")

describe("Store", function()
	local Exo, Store

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		Store = Exo.Store
	end)

	describe("Init (via ADDON_LOADED)", function()
		it("legt den aktuellen Charakter an und setzt Meta-Basisdaten", function()
			mock.SimulateLogin()

			local key = Store:GetCurrentKey()
			assert.equal("Default.Testrealm.Testchar", key)

			local char = Store:GetCharacter(key)
			assert.equal("Testchar", char.meta.name)
			assert.equal("Testrealm", char.meta.realm)
			assert.equal("Alliance", char.meta.faction)
			assert.equal(1700000000, char.meta.lastSeen)
		end)

		it("feuert EXO_STORE_READY mit dem aktuellen Key", function()
			local gotKey
			Exo.EventBus:Register("EXO_STORE_READY", function(_, key) gotKey = key end)
			mock.SimulateLogin()
			assert.equal("Default.Testrealm.Testchar", gotKey)
		end)

		it("migriert eine frische DB auf die aktuelle Schema-Version", function()
			mock.SimulateLogin()
			assert.equal(Exo.Schema.VERSION, _G.ExoTwinksDB.schemaVersion)
		end)

		it("ergaenzt bei bestehender DB fehlende Char-Felder (Addon-Update)", function()
			_G.ExoTwinksDB = {
				schemaVersion = 1,
				chars = { ["Default.R.Alt"] = { gold = 42 } }, -- ohne meta/bags/...
				guilds = {}, account = { options = {} },
			}
			mock.SimulateLogin()

			local alt = Store:GetCharacter("Default.R.Alt")
			assert.equal(42, alt.gold)
			assert.is_table(alt.meta)
			assert.is_table(alt.currencies)
		end)
	end)

	describe("Charakter-Verwaltung", function()
		before_each(mock.SimulateLogin)

		it("GetOrCreateCharacter feuert EXO_CHAR_ADDED nur beim Anlegen", function()
			local added = {}
			Exo.EventBus:Register("EXO_CHAR_ADDED", function(_, key) added[#added + 1] = key end)

			Store:GetOrCreateCharacter("Default.R.Neu")
			Store:GetOrCreateCharacter("Default.R.Neu") -- zweiter Aufruf: kein Event

			assert.same({ "Default.R.Neu" }, added)
		end)

		it("GetCharacterKeys liefert sortierte Liste", function()
			Store:GetOrCreateCharacter("Default.R.Zebra")
			Store:GetOrCreateCharacter("Default.R.Anton")

			local keys = Store:GetCharacterKeys()
			assert.equal(3, #keys) -- inkl. Testchar
			assert.equal("Default.R.Anton", keys[1])
			assert.equal("Default.R.Zebra", keys[2])
		end)

		it("DeleteCharacter entfernt und feuert EXO_CHAR_DELETED", function()
			Store:GetOrCreateCharacter("Default.R.Weg")
			local deleted
			Exo.EventBus:Register("EXO_CHAR_DELETED", function(_, key) deleted = key end)

			assert.is_true(Store:DeleteCharacter("Default.R.Weg"))
			assert.equal("Default.R.Weg", deleted)
			assert.is_nil(Store:GetCharacter("Default.R.Weg"))
			assert.is_false(Store:DeleteCharacter("Default.R.Weg")) -- schon weg
		end)
	end)

	describe("WriteCharacterData", function()
		before_each(mock.SimulateLogin)

		it("schreibt Sektion und feuert EXO_CHAR_UPDATED", function()
			local got
			Exo.EventBus:Register("EXO_CHAR_UPDATED", function(_, key, section)
				got = { key = key, section = section }
			end)

			Store:WriteCharacterData("Default.Testrealm.Testchar", "gold", 777)

			assert.equal(777, Store:GetCharacter("Default.Testrealm.Testchar").gold)
			assert.same({ key = "Default.Testrealm.Testchar", section = "gold" }, got)
		end)

		it("lehnt Sektionen ab, die nicht im Schema deklariert sind", function()
			assert.has_error(function()
				Store:WriteCharacterData("Default.Testrealm.Testchar", "tippfehler", {})
			end)
		end)
	end)

	it("Zugriff vor Init wirft einen verstaendlichen Fehler", function()
		assert.has_error(function() Store:GetCurrentKey() end)
	end)
end)
