-- spec/init_spec.lua
local mock = require("spec.wow_mock")

describe("Init / Bootstrap", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
	end)

	it("exportiert genau einen globalen Namen: Exo", function()
		assert.equal(Exo, _G.Exo)
	end)

	it("liest die Version aus den TOC-Metadaten", function()
		assert.equal("0.1.0-test", Exo.version)
	end)

	it("initialisiert ExoTwinksDB (migriert) und feuert EXO_CORE_READY bei ADDON_LOADED", function()
		local ready = false
		Exo.EventBus:Register("EXO_CORE_READY", function() ready = true end)

		mock.FireEvent("ADDON_LOADED", "IrgendeinAnderesAddon")
		assert.is_false(ready)
		assert.is_nil(_G.ExoTwinksDB)

		mock.FireEvent("ADDON_LOADED", "ExoTwinksCore")
		assert.is_true(ready)
		assert.equal(Exo.Schema.VERSION, _G.ExoTwinksDB.schemaVersion)
		assert.is_table(_G.ExoTwinksDB.chars)
	end)

	it("uebernimmt alte AltoCoreDB-Daten als ExoTwinksDB (Umbenennung 0.11.2)", function()
		_G.AltoCoreDB = {
			schemaVersion = Exo.Schema.VERSION,
			chars = { ["Default.Testrealm.Alt"] = { meta = { name = "Alt" } } },
			guilds = {},
			account = { options = { ["theme.accent"] = "ffd700" }, warbandBank = {} },
		}
		mock.FireEvent("ADDON_LOADED", "ExoTwinksCore")
		assert.is_nil(_G.AltoCoreDB)
		assert.is_table(_G.ExoTwinksDB.chars["Default.Testrealm.Alt"])
		assert.equal("ffd700", _G.ExoTwinksDB.account.options["theme.accent"])
	end)

	it("bevorzugt ExoTwinksDB, wenn beide SavedVariables existieren", function()
		_G.ExoTwinksDB = {
			schemaVersion = Exo.Schema.VERSION,
			chars = {}, guilds = {},
			account = { options = { neu = true }, warbandBank = {} },
		}
		_G.AltoCoreDB = { account = { options = { alt = true } } }
		mock.FireEvent("ADDON_LOADED", "ExoTwinksCore")
		assert.is_true(_G.ExoTwinksDB.account.options.neu)
		assert.is_nil(_G.ExoTwinksDB.account.options.alt)
	end)

	it("laesst vorhandene Nutzdaten in SavedVariables unangetastet", function()
		_G.ExoTwinksDB = {
			schemaVersion = 1,
			chars = { ["Default.R.Bestand"] = { gold = 42 } },
			guilds = {}, account = { options = { eigene = true } },
		}
		mock.FireEvent("ADDON_LOADED", "ExoTwinksCore")
		assert.equal(42, _G.ExoTwinksDB.chars["Default.R.Bestand"].gold)
		assert.is_true(_G.ExoTwinksDB.account.options.eigene)
	end)

	describe("/alto Kommandos", function()
		local function run(msg)
			_G.SlashCmdList["EXO"](msg)
		end

		it("registriert /exo, /twinks und die alten /alto-Aliase", function()
			assert.equal("/exo", _G.SLASH_EXO1)
			assert.equal("/twinks", _G.SLASH_EXO2)
			assert.equal("/alto", _G.SLASH_EXO3)
			assert.equal("/altong", _G.SLASH_EXO4)
			assert.is_function(_G.SlashCmdList["EXO"])
		end)

		it("'version' druckt die Versionsnummer", function()
			run("version")
			assert.truthy(mock.printed[#mock.printed]:find("0.1.0-test", 1, true))
		end)

		it("'debug' aktiviert verbose, 'debug off' deaktiviert", function()
			run("debug")
			assert.is_true(Exo.Log.verbose)
			run("debug off")
			assert.is_false(Exo.Log.verbose)
		end)

		it("'debug dump' listet den Puffer", function()
			Exo.Log:Info("marker-eintrag")
			run("debug dump")
			local found = false
			for _, line in ipairs(mock.printed) do
				if line:find("marker-eintrag", 1, true) then found = true end
			end
			assert.is_true(found)
		end)

		it("unbekannte Kommandos verweisen auf /alto help", function()
			run("gibtsnicht")
			assert.truthy(mock.printed[#mock.printed]:find("help", 1, true))
		end)

		it("'' (leer) laedt ExoTwinksUI on demand und ruft Toggle", function()
			-- ExoTwinksUI-Platzhalter simulieren
			Exo.UI = { toggled = 0 }
			function Exo.UI:Toggle() self.toggled = self.toggled + 1 end

			run("")
			assert.equal(1, Exo.UI.toggled)
		end)

		it("meldet Warnung, wenn ExoTwinksUI nicht ladbar ist", function()
			mock.SetLoadAddOnResult(false)
			run("")
			local last = mock.printed[#mock.printed]
			assert.truthy(last:find("ExoTwinksUI", 1, true))
		end)
	end)
end)
