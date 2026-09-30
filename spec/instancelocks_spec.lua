-- spec/instancelocks_spec.lua
local mock = require("spec.wow_mock")

-- Realistische Beispieldaten (wie GetSavedInstanceInfo sie liefert)
local function sampleInstances()
	return {
		{ name = "Befreiung von Lorenhall", id = 101, reset = 3 * 86400, difficultyID = 15,
		  locked = true, extended = false, isRaid = true, maxPlayers = 30,
		  difficultyName = "Heroisch", numEncounters = 8, encounterProgress = 5 },
		{ name = "Nerub-ar Palast", id = 102, reset = 86400, difficultyID = 16,
		  locked = true, extended = true, isRaid = true, maxPlayers = 20,
		  difficultyName = "Mythisch", numEncounters = 8, encounterProgress = 8 },
		{ name = "Die Steinsaele", id = 103, reset = 3600, difficultyID = 23,
		  locked = true, extended = false, isRaid = false, maxPlayers = 5,
		  difficultyName = "Mythisch", numEncounters = 4, encounterProgress = 4 },
		{ name = "Alter abgelaufener Eintrag", id = 104, reset = 0, difficultyID = 15,
		  locked = false, extended = false, isRaid = true, maxPlayers = 30,
		  difficultyName = "Heroisch", numEncounters = 8, encounterProgress = 2 },
	}
end

describe("InstanceLocks-Collector", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	it("fordert RaidInfo bei PLAYER_ENTERING_WORLD an (gedrosselt)", function()
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		mock.FireEvent("PLAYER_ENTERING_WORLD") -- innerhalb der Drossel
		assert.equal(1, mock.RaidInfoRequestCount())

		mock.AdvanceTime(5)
		mock.FireEvent("BOSS_KILL")
		assert.equal(2, mock.RaidInfoRequestCount())
	end)

	it("scannt bei UPDATE_INSTANCE_INFO entprellt und speichert nur aktive Locks", function()
		mock.SetSavedInstances(sampleInstances())

		mock.FireEvent("UPDATE_INSTANCE_INFO")
		mock.FireEvent("UPDATE_INSTANCE_INFO") -- Event-Sturm: nur EIN Scan
		local char = Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
		assert.same({}, char.instanceLocks) -- noch nichts (Debounce laeuft)

		mock.AdvanceTime(1)

		char = Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
		assert.equal(3, #char.instanceLocks) -- Eintrag 104 (locked=false, extended=false) fehlt
	end)

	it("speichert resetAt als absoluten Unix-Timestamp", function()
		mock.SetSavedInstances(sampleInstances())
		mock.FireEvent("UPDATE_INSTANCE_INFO")
		mock.AdvanceTime(1)

		local char = Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
		local lorenhall
		for _, lock in ipairs(char.instanceLocks) do
			if lock.lockID == 101 then lorenhall = lock end
		end
		-- Mock-Unix-Zeit beim Scan: 1700000001 (Login + 1s Debounce)
		assert.equal(1700000001 + 3 * 86400, lorenhall.resetAt)
		assert.equal(5, lorenhall.bossesKilled)
		assert.equal(8, lorenhall.bossesTotal)
		assert.is_true(lorenhall.isRaid)
	end)

	it("feuert EXO_CHAR_UPDATED mit Sektion instanceLocks", function()
		local got
		Exo.EventBus:Register("EXO_CHAR_UPDATED", function(_, key, section)
			got = { key = key, section = section }
		end)

		mock.SetSavedInstances(sampleInstances())
		mock.FireEvent("UPDATE_INSTANCE_INFO")
		mock.AdvanceTime(1)

		assert.same({ key = "Default.Testrealm.Testchar", section = "instanceLocks" }, got)
	end)
end)

describe("Exo.API (Instanz-Locks)", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.SetSavedInstances(sampleInstances())
		mock.FireEvent("UPDATE_INSTANCE_INFO")
		mock.AdvanceTime(1)
	end)

	it("GetRaidLocks liefert nur Schlachtzuege", function()
		local locks = Exo.API.GetRaidLocks(Exo.Store:GetCurrentKey())
		assert.equal(2, #locks)
		for _, lock in ipairs(locks) do
			assert.is_true(lock.isRaid)
		end
	end)

	it("GetInstanceLocks filtert abgelaufene Locks heraus", function()
		mock.AdvanceTime(2 * 86400) -- 2 Tage: Palast (1T) und Steinsaele (1h) abgelaufen

		local key = Exo.Store:GetCurrentKey()
		assert.equal(1, #Exo.API.GetInstanceLocks(key))
		assert.equal(3, #Exo.API.GetInstanceLocks(key, { includeExpired = true }))
	end)

	it("Rueckgaben sind Kopien: Schreibzugriffe korrumpieren die DB nicht", function()
		local key = Exo.Store:GetCurrentKey()
		local locks = Exo.API.GetRaidLocks(key)
		locks[1].name = "MANIPULIERT"

		local fresh = Exo.API.GetRaidLocks(key)
		assert.not_equal("MANIPULIERT", fresh[1].name)
	end)

	it("unbekannter Charakter liefert leere Liste", function()
		assert.same({}, Exo.API.GetRaidLocks("Default.Nix.Niemand"))
	end)
end)
