-- spec/scheduler_spec.lua
local mock = require("spec.wow_mock")

describe("Scheduler", function()
	local Exo, S

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		S = Exo.Scheduler
	end)

	describe("After", function()
		it("feuert erst nach Ablauf der Verzoegerung", function()
			local fired = false
			S:After(5, function() fired = true end)

			S:OnTick(4.9)
			assert.is_false(fired)

			S:OnTick(5.0)
			assert.is_true(fired)
			assert.equal(0, S:PendingTimers())
		end)

		it("Timer duerfen im Handler neue Timer setzen", function()
			local chained = false
			S:After(1, function()
				S:After(1, function() chained = true end)
			end)

			S:OnTick(1)
			assert.is_false(chained)
			S:OnTick(2)
			assert.is_true(chained)
		end)
	end)

	describe("Debounce", function()
		it("buendelt schnelle Aufruffolgen zu einem einzigen Callback", function()
			local calls = 0
			-- Simuliert BAG_UPDATE-Sturm: 3 Aufrufe kurz hintereinander
			S:Debounce("bags", 1.0, function() calls = calls + 1 end)
			mock.AdvanceTime(0.5) ; S:Debounce("bags", 1.0, function() calls = calls + 1 end)
			mock.AdvanceTime(0.5) ; S:Debounce("bags", 1.0, function() calls = calls + 1 end)

			S:OnTick(mock.Now() + 0.99)
			assert.equal(0, calls)

			S:OnTick(mock.Now() + 1.0)
			assert.equal(1, calls)
		end)

		it("verschiedene Keys stoeren sich nicht", function()
			local a, b = 0, 0
			S:Debounce("a", 1, function() a = a + 1 end)
			S:Debounce("b", 1, function() b = b + 1 end)

			S:OnTick(1)
			assert.equal(1, a)
			assert.equal(1, b)
		end)
	end)

	describe("Throttle", function()
		it("feuert sofort, unterdrueckt dann bis zum Intervallende", function()
			local calls = 0
			local fn = function() calls = calls + 1 end

			assert.is_true(S:Throttle("t", 10, fn))   -- leading edge
			assert.is_false(S:Throttle("t", 10, fn))  -- unterdrueckt
			assert.equal(1, calls)

			mock.AdvanceTime(10)
			assert.is_true(S:Throttle("t", 10, fn))
			assert.equal(2, calls)
		end)
	end)

	describe("Enqueue", function()
		it("arbeitet maximal tasksPerTick Tasks pro Tick ab", function()
			S.tasksPerTick = 2
			local done = 0
			for _ = 1, 5 do
				S:Enqueue(function() done = done + 1 end)
			end

			S:OnTick(0)
			assert.equal(2, done)
			assert.equal(3, S:QueueSize())

			S:OnTick(0)
			S:OnTick(0)
			assert.equal(5, done)
			assert.equal(0, S:QueueSize())
		end)

		it("ein werfender Task blockiert die Queue nicht", function()
			local done = false
			S:Enqueue(function() error("boom") end)
			S:Enqueue(function() done = true end)

			S:OnTick(0)
			assert.is_true(done)
		end)
	end)

	it("wird ueber den OnUpdate-Frame aus Init getaktet", function()
		local fired = false
		S:After(1, function() fired = true end)

		mock.AdvanceTime(1) -- treibt den Ticker-Frame aus Init.lua
		assert.is_true(fired)
	end)
end)
