-- spec/log_spec.lua
local mock = require("spec.wow_mock")

describe("Log", function()
	local Exo, Log

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		Log = Exo.Log
		Log:Clear()
	end)

	it("puffert Eintraege bis einschliesslich des eingestellten Levels", function()
		Log:Info("info %d", 1)
		Log:Debug("debug") -- Level DEBUG > INFO -> verworfen

		local entries = Log:GetEntries()
		assert.equal(1, #entries)
		assert.equal("info 1", entries[1].msg)
	end)

	it("druckt WARN/ERROR in den Chat, INFO nicht", function()
		local before = #mock.printed
		Log:Info("leise")
		assert.equal(before, #mock.printed)

		Log:Warn("achtung")
		assert.equal(before + 1, #mock.printed)
		assert.truthy(mock.printed[#mock.printed]:find("achtung", 1, true))
	end)

	it("verbose-Modus druckt auch DEBUG", function()
		Log:SetVerbose(true)
		local before = #mock.printed
		Log:Debug("sichtbar")
		assert.equal(before + 1, #mock.printed)
	end)

	it("fehlerhafte Formatstrings werfen nicht", function()
		assert.has_no.errors(function()
			Log:Warn("kaputt %d", "kein-numeric")
		end)
	end)

	it("Ringpuffer behaelt nur maxEntries und bleibt chronologisch", function()
		local oldMax = Log.maxEntries
		Log.maxEntries = 3
		Log:Clear()

		for i = 1, 5 do
			Log:Info("msg %d", i)
		end

		local entries = Log:GetEntries()
		assert.equal(3, #entries)
		assert.equal("msg 3", entries[1].msg)
		assert.equal("msg 5", entries[3].msg)

		Log.maxEntries = oldMax
	end)

	it("SetLevel akzeptiert nur bekannte Level", function()
		assert.is_true(Log:SetLevel("debug"))
		assert.is_false(Log:SetLevel("quatsch"))
	end)
end)
