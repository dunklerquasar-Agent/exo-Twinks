-- spec/characters_spec.lua
local mock = require("spec.wow_mock")

describe("Characters-Collector", function()
	local Exo

	local function currentChar()
		return Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	it("Vollscan bei PLAYER_ENTERING_WORLD: Meta + Gold", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")

		local char = currentChar()
		assert.equal(80, char.meta.level)
		assert.equal(8, char.meta.classID)      -- Magier
		assert.equal(1, char.meta.raceID)       -- Mensch
		assert.equal("Alliance", char.meta.faction)
		assert.equal("Dornogal", char.meta.zone)
		assert.equal(55000, char.meta.xp)
		assert.equal(100000, char.meta.xpMax)
		assert.equal(12000, char.meta.restXP)
		assert.equal(1234567, char.gold)
	end)

	it("fordert die Spielzeit genau EINMAL pro Sitzung an", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.FireEvent("PLAYER_ENTERING_WORLD") -- z.B. nach Instanz-Portal
		assert.equal(1, mock.TimePlayedRequestCount())
	end)

	it("TIME_PLAYED_MSG aktualisiert die Gesamtspielzeit", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.FireEvent("TIME_PLAYED_MSG", 987654, 1234)

		assert.equal(987654, currentChar().meta.playedTotal)
	end)

	it("PLAYER_MONEY aktualisiert nur das Gold (sofort, ohne Debounce)", function()
		mock.SetMoney(42)
		mock.FireEvent("PLAYER_MONEY")
		assert.equal(42, currentChar().gold)
	end)

	it("PLAYER_LEVEL_UP scannt sofort neu", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.SetPlayerLevel(81)
		mock.FireEvent("PLAYER_LEVEL_UP")
		assert.equal(81, currentChar().meta.level)
	end)

	it("Zonenwechsel wird entprellt uebernommen", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.SetZone("Der Ringende Abgrund")
		mock.FireEvent("ZONE_CHANGED_NEW_AREA")

		assert.equal("Dornogal", currentChar().meta.zone) -- Debounce laeuft noch
		mock.AdvanceTime(1)
		assert.equal("Der Ringende Abgrund", currentChar().meta.zone)
	end)

	it("PLAYER_LOGOUT stempelt lastSeen", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.AdvanceTime(3600)
		mock.FireEvent("PLAYER_LOGOUT")

		assert.equal(1700003600, currentChar().meta.lastSeen)
	end)

	it("Scan erhaelt playedTotal (gehoert TIME_PLAYED_MSG)", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.FireEvent("TIME_PLAYED_MSG", 500000, 100)
		mock.FireEvent("PLAYER_LEVEL_UP") -- Vollscan darf playedTotal nicht nullen

		assert.equal(500000, currentChar().meta.playedTotal)
	end)
end)
