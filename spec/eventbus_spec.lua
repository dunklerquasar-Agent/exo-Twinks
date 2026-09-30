-- spec/eventbus_spec.lua
local mock = require("spec.wow_mock")

describe("EventBus", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
	end)

	it("stellt Handler zu und uebergibt Event-Name + Argumente", function()
		local got
		Exo.EventBus:Register("EXO_TEST", function(event, a, b)
			got = { event = event, a = a, b = b }
		end)

		local n = Exo.EventBus:Fire("EXO_TEST", 1, "x")

		assert.equal(1, n)
		assert.same({ event = "EXO_TEST", a = 1, b = "x" }, got)
	end)

	it("unterstuetzt mehrere Handler pro Event", function()
		local calls = 0
		Exo.EventBus:Register("E", function() calls = calls + 1 end)
		Exo.EventBus:Register("E", function() calls = calls + 1 end)

		Exo.EventBus:Fire("E")

		assert.equal(2, calls)
	end)

	it("Unregister per Owner entfernt nur dessen Handler", function()
		local ownerA, calls = {}, {}
		Exo.EventBus:Register("E", function() calls[#calls + 1] = "a" end, ownerA)
		Exo.EventBus:Register("E", function() calls[#calls + 1] = "b" end, "ownerB")

		Exo.EventBus:Unregister("E", ownerA)
		Exo.EventBus:Fire("E")

		assert.same({ "b" }, calls)
	end)

	it("UnregisterAll entfernt Owner aus allen Events", function()
		local owner = {}
		Exo.EventBus:Register("E1", function() end, owner)
		Exo.EventBus:Register("E2", function() end, owner)

		Exo.EventBus:UnregisterAll(owner)

		assert.equal(0, Exo.EventBus:CountListeners("E1"))
		assert.equal(0, Exo.EventBus:CountListeners("E2"))
	end)

	it("ein werfender Handler stoppt den Dispatch nicht", function()
		local reached = false
		Exo.EventBus:Register("E", function() error("boom") end)
		Exo.EventBus:Register("E", function() reached = true end)

		local n = Exo.EventBus:Fire("E")

		assert.is_true(reached)
		assert.equal(1, n) -- nur der erfolgreiche zaehlt
	end)

	it("Handler duerfen waehrend des Dispatches unregistrieren (Snapshot)", function()
		local owner = {}
		local secondRan = false
		Exo.EventBus:Register("E", function()
			Exo.EventBus:UnregisterAll(owner)
		end)
		Exo.EventBus:Register("E", function() secondRan = true end, owner)

		Exo.EventBus:Fire("E") -- Snapshot: zweiter Handler laeuft noch
		assert.is_true(secondRan)

		secondRan = false
		Exo.EventBus:Fire("E") -- jetzt ist er weg
		assert.is_false(secondRan)
	end)

	it("leitet WoW-Events in den Bus um", function()
		local got
		Exo.EventBus:RegisterWowEvent("BAG_UPDATE", function(event, bagID)
			got = { event = event, bagID = bagID }
		end)

		mock.FireEvent("BAG_UPDATE", 3)

		assert.same({ event = "BAG_UPDATE", bagID = 3 }, got)
	end)
end)
