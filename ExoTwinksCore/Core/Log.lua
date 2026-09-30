-- Core/Log.lua
-- Leichtgewichtiges Logging mit Levels und Ringpuffer.
-- Regeln: kein _G-Zugriff, alles haengt am Addon-Namespace (2. Vararg).

local _, Exo = ...

local Log = {
	-- Level: je hoeher, desto gespraechiger
	LEVELS = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 },
	level = 3,          -- ab diesem Level wird gepuffert (INFO)
	printLevel = 2,     -- ab diesem Level (und niedriger) wird in den Chat gedruckt (WARN/ERROR)
	verbose = false,    -- true: alles auch in den Chat (Debug-Modus)
	maxEntries = 200,
}
Exo.Log = Log

local buffer = {}       -- Ringpuffer: { time, level, msg }
local writeIndex = 0
local levelNames = {}
for name, num in pairs(Log.LEVELS) do
	levelNames[num] = name
end

-- Chat-Ausgabe kapseln, damit Tests sie ersetzen koennen
function Log.emit(text)
	print(text)
end

local function record(levelNum, fmt, ...)
	if levelNum > Log.level and not Log.verbose then
		return
	end

	local ok, msg
	if select("#", ...) > 0 then
		ok, msg = pcall(string.format, fmt, ...)
		if not ok then
			msg = "LOG-FORMAT-ERROR: " .. tostring(fmt)
		end
	else
		msg = tostring(fmt)
	end

	writeIndex = (writeIndex % Log.maxEntries) + 1
	buffer[writeIndex] = {
		time = Exo.WowAPI and Exo.WowAPI.GetTime() or 0,
		level = levelNum,
		msg = msg,
	}

	if Log.verbose or levelNum <= Log.printLevel then
		Log.emit(string.format("|cff69ccf0exo-Twinks|r [%s] %s", levelNames[levelNum], msg))
	end
end

function Log:Error(fmt, ...) record(self.LEVELS.ERROR, fmt, ...) end
function Log:Warn(fmt, ...)  record(self.LEVELS.WARN, fmt, ...) end
function Log:Info(fmt, ...)  record(self.LEVELS.INFO, fmt, ...) end
function Log:Debug(fmt, ...) record(self.LEVELS.DEBUG, fmt, ...) end

function Log:SetLevel(name)
	local num = self.LEVELS[string.upper(tostring(name))]
	if num then
		self.level = num
		return true
	end
	return false
end

function Log:SetVerbose(flag)
	self.verbose = not not flag
end

-- Liefert die Eintraege in chronologischer Reihenfolge (aeltester zuerst)
function Log:GetEntries()
	local result = {}
	for i = 1, Log.maxEntries do
		local idx = ((writeIndex + i - 1) % Log.maxEntries) + 1
		local entry = buffer[idx]
		if entry then
			result[#result + 1] = entry
		end
	end
	return result
end

function Log:Clear()
	buffer = {}
	writeIndex = 0
end

function Log:LevelName(num)
	return levelNames[num] or "?"
end
