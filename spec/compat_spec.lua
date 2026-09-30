-- spec/compat_spec.lua
-- Reproduziert den In-Game-Bugreport: altes Altoholic installiert ->
-- "/alto" oeffnete das alte Fenster statt AltoNG.
local mock = require("spec.wow_mock")

describe("Compat / Koexistenz mit altem Altoholic", function()
	local Exo

	-- Simuliert das alte Altoholic: geladen + eigene Slash-Registrierung
	local function installOldAltoholic()
		mock.SetAddonLoaded("Altoholic")
		_G.SLASH_ALTOHOLIC1 = "/altoholic"
		_G.SLASH_ALTOHOLIC2 = "/alto"
		_G.SlashCmdList["ALTOHOLIC"] = function() end
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	it("benennt die /alto-Registrierung des alten Altoholic beim Login um", function()
		installOldAltoholic()
		mock.FireEvent("PLAYER_ENTERING_WORLD")

		assert.equal("/altoholic", _G.SLASH_ALTOHOLIC1)     -- bleibt erreichbar
		assert.equal("/altoholicold2", _G.SLASH_ALTOHOLIC2) -- /alto freigegeben
		assert.equal("/alto", _G.SLASH_EXO3)               -- gehoert exo-Twinks
	end)

	it("informiert den Nutzer einmalig ueber die Uebernahme", function()
		installOldAltoholic()
		mock.FireEvent("PLAYER_ENTERING_WORLD")

		local out = table.concat(mock.printed, "\n")
		assert.truthy(out:find("'/alto' oeffnet jetzt exo-Twinks", 1, true))
		assert.truthy(out:find("/altoholic erreichbar", 1, true))

		-- zweites PLAYER_ENTERING_WORLD (Instanz-Portal): kein zweiter Hinweis
		local before = #mock.printed
		mock.FireEvent("PLAYER_ENTERING_WORLD")
		local after = table.concat(mock.printed, "\n", before + 1)
		assert.is_nil(after:find("oeffnet jetzt exo-Twinks", 1, true))
	end)

	it("tut NICHTS, wenn das alte Altoholic nicht laeuft", function()
		_G.SLASH_ALTOHOLIC2 = "/alto" -- Token existiert, aber Addon nicht geladen
		mock.FireEvent("PLAYER_ENTERING_WORLD")

		assert.equal("/alto", _G.SLASH_ALTOHOLIC2) -- unangetastet
	end)

	it("tut NICHTS, wenn das alte Altoholic /alto gar nicht nutzt", function()
		mock.SetAddonLoaded("Altoholic")
		_G.SLASH_ALTOHOLIC1 = "/altoholic"

		assert.is_false(Exo.Services.Compat.ReclaimSlashCommand())
		assert.equal("/altoholic", _G.SLASH_ALTOHOLIC1)
	end)

	it("ist gross-/kleinschreibungs-tolerant (/ALTO)", function()
		mock.SetAddonLoaded("Altoholic")
		_G.SLASH_ALTOHOLIC2 = "/ALTO"

		assert.is_true(Exo.Services.Compat.ReclaimSlashCommand())
		assert.equal("/altoholicold2", _G.SLASH_ALTOHOLIC2)
	end)
end)
