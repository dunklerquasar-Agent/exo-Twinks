-- spec/release_1_18_1_spec.lua
-- Bugfix "1 Minute" (1.18.1): Format.TimeAgo wurde in Uebersicht und
-- Charakter-Vergleich OHNE `now` aufgerufen -- nil wurde zu 0 und jeder
-- Zeitstempel damit zu "1 Minute". Fehlt `now`, gilt jetzt die aktuelle Zeit.
local mock = require("spec.wow_mock")

describe("Release 1.18.1: TimeAgo ohne now-Parameter", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		mock.AdvanceTime(30 * 86400) -- realistische Uhr (sonst start bei 0)
	end)

	it("nutzt die aktuelle Zeit, wenn now fehlt", function()
		local F = Exo.UI.Format
		assert.equal("2 Stunden", F.TimeAgo(Exo.WowAPI.Now() - 2 * 3600))
		assert.equal("3 Tagen", F.TimeAgo(Exo.WowAPI.Now() - 3 * 86400))
		assert.equal("-", F.TimeAgo(0))
		-- explizites now funktioniert weiterhin
		assert.equal("1 Minute", F.TimeAgo(100, 160))
	end)

	it("Uebersicht zeigt echte Zeitabstaende statt ueberall '1 Minute'", function()
		local charKey = "Default.Testrealm.Alt"
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = 1
		char.meta.level = 80
		char.meta.lastSeen = Exo.WowAPI.Now() - 5 * 3600 -- vor 5 Stunden
		char.equipment = { avgItemLevelEquipped = 400, slots = {} }

		local Tab = Exo.UI.OverviewTab
		local found, current
		for _, row in ipairs(Tab.BuildRows()) do
			if row.header then
				current = row.module
			elseif current == "chars" and row.text and row.text:find(name) then
				found = row.text
			end
		end
		assert.is_string(found)
		assert.matches("5 Stunden", found)
		assert.is_nil(found:find("1 Minute"))
	end)
end)
