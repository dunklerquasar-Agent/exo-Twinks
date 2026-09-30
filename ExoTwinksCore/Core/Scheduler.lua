-- Core/Scheduler.lua
-- Zeitsteuerung und Lastbegrenzung:
--   After(delay, fn)            -- einmalig nach delay Sekunden
--   Debounce(key, delay, fn)    -- fn erst, wenn delay lang KEIN weiterer Aufruf kam
--                                  (z.B. BAG_UPDATE-Stuerme buendeln)
--   Throttle(key, interval, fn) -- fn sofort, dann max. 1x pro interval (leading edge)
--   Enqueue(fn)                 -- Task-Queue, budgetiert pro Tick abgearbeitet
-- Der Scheduler wird von aussen getaktet (OnUpdate-Frame in Init.lua bzw.
-- manuell in Tests) -> deterministisch testbar.

local _, Exo = ...

local Scheduler = {
	tasksPerTick = 5,   -- Budget: max. Tasks aus der Queue pro Tick
}
Exo.Scheduler = Scheduler

local timers = {}     -- array of { at = time, fn = fn, key = key or nil }
local throttles = {}  -- key -> naechster erlaubter Zeitpunkt
local queue = {}      -- FIFO-Task-Queue
local queueFirst, queueLast = 1, 0

-- Uhr ist injizierbar (Tests); Default: WowAPI.GetTime
function Scheduler.clock()
	return Exo.WowAPI.GetTime()
end

-- Timer ----------------------------------------------------------------------

function Scheduler:After(delay, fn)
	assert(type(fn) == "function", "Scheduler:After: fn muss eine Funktion sein")
	timers[#timers + 1] = { at = self.clock() + delay, fn = fn }
end

function Scheduler:Debounce(key, delay, fn)
	assert(key ~= nil, "Scheduler:Debounce: key erforderlich")
	-- bestehenden Timer mit gleichem Key verwerfen (Zeit neu starten)
	for i = #timers, 1, -1 do
		if timers[i].key == key then
			table.remove(timers, i)
		end
	end
	timers[#timers + 1] = { at = self.clock() + delay, fn = fn, key = key }
end

function Scheduler:Throttle(key, interval, fn)
	assert(key ~= nil, "Scheduler:Throttle: key erforderlich")
	local now = self.clock()
	local nextAllowed = throttles[key]
	if nextAllowed and now < nextAllowed then
		return false -- unterdrueckt
	end
	throttles[key] = now + interval
	local ok, err = pcall(fn)
	if not ok then
		Exo.Log:Error("Scheduler:Throttle('%s') fehlgeschlagen: %s", tostring(key), tostring(err))
	end
	return true
end

-- Task-Queue ------------------------------------------------------------------

function Scheduler:Enqueue(fn)
	assert(type(fn) == "function", "Scheduler:Enqueue: fn muss eine Funktion sein")
	queueLast = queueLast + 1
	queue[queueLast] = fn
end

function Scheduler:QueueSize()
	return queueLast - queueFirst + 1
end

-- Tick ------------------------------------------------------------------------
-- Wird pro Frame (OnUpdate) bzw. in Tests manuell aufgerufen.

function Scheduler:OnTick(now)
	now = now or self.clock()

	-- 1. faellige Timer feuern (Kopie, damit Handler neue Timer setzen duerfen)
	local due = {}
	for i = #timers, 1, -1 do
		if timers[i].at <= now then
			due[#due + 1] = timers[i]
			table.remove(timers, i)
		end
	end
	-- in Einfuege-Reihenfolge ausfuehren
	for i = #due, 1, -1 do
		local ok, err = pcall(due[i].fn)
		if not ok then
			Exo.Log:Error("Scheduler-Timer fehlgeschlagen: %s", tostring(err))
		end
	end

	-- 2. Task-Queue budgetiert abarbeiten
	local budget = self.tasksPerTick
	while budget > 0 and queueFirst <= queueLast do
		local fn = queue[queueFirst]
		queue[queueFirst] = nil
		queueFirst = queueFirst + 1
		budget = budget - 1

		local ok, err = pcall(fn)
		if not ok then
			Exo.Log:Error("Scheduler-Task fehlgeschlagen: %s", tostring(err))
		end
	end
	if queueFirst > queueLast then
		queueFirst, queueLast = 1, 0 -- Queue-Indizes zuruecksetzen
	end
end

-- Test-/Debug-Helfer
function Scheduler:PendingTimers()
	return #timers
end

function Scheduler:Reset()
	timers = {}
	throttles = {}
	queue = {}
	queueFirst, queueLast = 1, 0
end
