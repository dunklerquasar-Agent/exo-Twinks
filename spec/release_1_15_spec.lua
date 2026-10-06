-- spec/release_1_15_spec.lua
-- Demo-Modus (1.15.0): /exo demo an|aus -- erfundene Beispiel-Chars fuer
-- Screenshots; echte Chars werden solange ausgeblendet und danach exakt
-- wiederhergestellt. Echte Daten bleiben unangetastet.
local mock = require("spec.wow_mock")

describe("Release 1.15.0: Demo-Modus", function()
	local Exo

	local ECHT = "Default.Testrealm.Echt"
	local VERSTECKT = "Default.Testrealm.Versteckt"

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()

		local echt = Exo.Store:GetOrCreateCharacter(ECHT)
		echt.meta.name = "Echt"
		Exo.Store:WriteCharacterData(ECHT, "bags", {
			[0] = { size = 16, free = 10, items = { [1] = { id = 2589, count = 7 } } },
		})
		Exo.Store:GetOrCreateCharacter(VERSTECKT).meta.name = "Versteckt"
		Exo.API.SetCharacterHidden(VERSTECKT, true)
	end)

	it("Enable blendet echte Chars aus und legt 8 Demo-Chars an", function()
		assert.is_true(Exo.DemoMode.Enable())
		assert.is_true(Exo.DemoMode.IsActive())

		local visible = Exo.API.GetCharacterKeys()
		assert.equal(8, #visible)
		for _, key in ipairs(visible) do
			assert.truthy(key:find("Default.Sturmklinge.", 1, true))
		end
		assert.is_true(Exo.API.IsCharacterHidden(ECHT))
	end)

	it("Demo-Chars haben volle Beispieldaten (Gold, M+, Berufe, Post)", function()
		Exo.DemoMode.Enable()
		local thorgrim = Exo.Store:GetCharacter("Default.Sturmklinge.Thorgrim")
		assert.equal(1264580000, thorgrim.gold)
		assert.equal(3012, Exo.API.GetMythicPlus("Default.Sturmklinge.Thorgrim").rating)
		assert.equal("Seraphine",
			Exo.API.GetCharacterInfo("Default.Sturmklinge.Seraphine").name)
		assert.equal(2, #Exo.API.GetMails("Default.Sturmklinge.Seraphine").mails)
	end)

	it("Tooltip-Zaehler zeigen im Demo-Modus nur Demo-Chars", function()
		-- Echt hat 7x Leinenstoff -- im Demo-Modus zaehlt nur Seraphine
		Exo.DemoMode.Enable()
		local counts = Exo.API.GetItemCounts(2589)
		assert.is_nil(counts.chars[ECHT])
		local sera = counts.chars["Default.Sturmklinge.Seraphine"]
		assert.equal(20, sera.bags)
		assert.equal(200, sera.bank)
	end)

	it("Disable loescht Demo-Chars und stellt Sichtbarkeit exakt wieder her", function()
		Exo.DemoMode.Enable()
		assert.is_true(Exo.DemoMode.Disable())
		assert.is_false(Exo.DemoMode.IsActive())

		assert.equal(0, #Exo.DemoMode.GetDemoKeys())
		assert.is_nil(Exo.Store:GetCharacter("Default.Sturmklinge.Thorgrim"))
		-- Echt wieder sichtbar, Versteckt bleibt versteckt
		assert.is_false(Exo.API.IsCharacterHidden(ECHT))
		assert.is_true(Exo.API.IsCharacterHidden(VERSTECKT))
		-- echte Daten unangetastet
		assert.equal(7, Exo.API.GetItemCounts(2589).chars[ECHT].bags)
	end)

	it("doppeltes Ein-/Ausschalten ist abgesichert", function()
		assert.is_true(Exo.DemoMode.Enable())
		local ok, err = Exo.DemoMode.Enable()
		assert.is_nil(ok)
		assert.equal("already_on", err)
		Exo.DemoMode.Disable()
		local ok2, err2 = Exo.DemoMode.Disable()
		assert.is_nil(ok2)
		assert.equal("already_off", err2)
	end)

	it("/exo demo an|aus schaltet den Modus", function()
		Exo._internal.onSlashCommand("demo an")
		assert.is_true(Exo.DemoMode.IsActive())
		Exo._internal.onSlashCommand("demo")       -- Status, aendert nichts
		assert.is_true(Exo.DemoMode.IsActive())
		Exo._internal.onSlashCommand("demo aus")
		assert.is_false(Exo.DemoMode.IsActive())
	end)
end)
