-- Core/EventBus.lua
-- Interner Pub/Sub-Dispatcher. Entkoppelt Collectors, Storage und UI.
-- Zwei Event-Raeume:
--   1. Interne Events ("EXO_*")  -> EventBus:Fire / :Register
--   2. WoW-Events (z.B. BAG_UPDATE) -> EventBus:RegisterWowEvent
-- Handler-Fehler brechen niemals den Dispatch ab (pcall + Log).

local _, Exo = ...

local EventBus = {}
Exo.EventBus = EventBus

local listeners = {}     -- event -> array of { fn = fn, owner = owner }
local wowFrame           -- lazy erzeugter Frame fuer WoW-Events
local wowEvents = {}     -- WoW-Event-Name -> true (bereits registriert)

-- Interne Events -------------------------------------------------------------

function EventBus:Register(event, fn, owner)
	assert(type(event) == "string" and event ~= "", "EventBus:Register: event muss ein String sein")
	assert(type(fn) == "function", "EventBus:Register: fn muss eine Funktion sein")

	local list = listeners[event]
	if not list then
		list = {}
		listeners[event] = list
	end
	list[#list + 1] = { fn = fn, owner = owner }
end

-- Entfernt Handler per Owner ODER per Funktionsreferenz
function EventBus:Unregister(event, ownerOrFn)
	local list = listeners[event]
	if not list then return end

	for i = #list, 1, -1 do
		local entry = list[i]
		if entry.owner == ownerOrFn or entry.fn == ownerOrFn then
			table.remove(list, i)
		end
	end
	if #list == 0 then
		listeners[event] = nil
	end
end

-- Entfernt ALLE Registrierungen eines Owners (z.B. beim Modul-Teardown)
function EventBus:UnregisterAll(owner)
	for event in pairs(listeners) do
		self:Unregister(event, owner)
	end
end

function EventBus:Fire(event, ...)
	local list = listeners[event]
	if not list then return 0 end

	-- Kopie, damit Handler waehrend des Dispatches sicher (un)registrieren koennen
	local snapshot = {}
	for i = 1, #list do
		snapshot[i] = list[i]
	end

	local dispatched = 0
	for i = 1, #snapshot do
		local entry = snapshot[i]
		local ok, err = pcall(entry.fn, event, ...)
		if ok then
			dispatched = dispatched + 1
		else
			Exo.Log:Error("EventBus-Handler fuer '%s' fehlgeschlagen: %s", event, tostring(err))
		end
	end
	return dispatched
end

function EventBus:CountListeners(event)
	local list = listeners[event]
	return list and #list or 0
end

-- WoW-Events -----------------------------------------------------------------
-- Leitet WoW-Events 1:1 in den Bus um: ein registriertes WoW-Event wird als
-- gleichnamiges internes Event gefeuert. Collectors abonnieren also einheitlich.

function EventBus:RegisterWowEvent(event, fn, owner)
	if not wowFrame then
		wowFrame = Exo.WowAPI.CreateFrame("Frame")
		wowFrame:SetScript("OnEvent", function(_, wowEvent, ...)
			EventBus:Fire(wowEvent, ...)
		end)
	end
	if not wowEvents[event] then
		wowFrame:RegisterEvent(event)
		wowEvents[event] = true
	end
	self:Register(event, fn, owner)
end
