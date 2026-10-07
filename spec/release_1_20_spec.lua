-- spec/release_1_20_spec.lua
-- Ausbau (1.20.0):
--  a) /exo help ist die zentrale Kurzreferenz: JEDES registrierte Subcommand
--     wird gelistet (dynamisch geprueft), plus Bedien-Tipps.
--  b) Leerzustaende Bank/KM: Der Bank-Tipp nennt den gewaehlten Charakter;
--     ohne Charaktere fuehrt er zum ersten Login. KM-Bank zeigt den
--     einheitlichen Leerzustand mit eigenem Titel.
local mock = require("spec.wow_mock")

describe("Release 1.20.0: /exo help Kurzreferenz + Bank/KM-Leerzustaende", function()
	local Exo

	local function run(msg)
		Exo._internal.onSlashCommand(msg)
	end

	local function helpOutput()
		run("help")
		return table.concat(mock.printed, "\n")
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	it("listet JEDES registrierte Subcommand (dynamisch)", function()
		local out = helpOutput()
		for name in pairs(Exo._internal.subcommands) do
			assert.truthy(out:find("/exo " .. name, 1, true),
				"Subcommand fehlt in /exo help: " .. name)
		end
	end)

	it("enthaelt Kopf, Gruppen und Bedien-Tipps", function()
		local out = helpOutput()
		assert.truthy(out:find("Kurzreferenz", 1, true))
		assert.truthy(out:find(tostring(Exo.version), 1, true))
		for _, group in ipairs({ "Fenster", "Berichte", "Werkzeuge", "Tipps" }) do
			assert.truthy(out:find(group, 1, true), "Gruppe fehlt: " .. group)
		end
		assert.truthy(out:find("Waehrungs%-Gruppen"))
		assert.truthy(out:find("Shift%-Klick"))
	end)

	describe("Bank/KM-Leerzustaende", function()
		before_each(function()
			mock.LoadExoUI()
		end)

		it("Bank: Tipp nennt den aktuell gewaehlten Charakter", function()
			local Tab = Exo.UI.BankTab
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.is_true(content._emptyState.host:IsShown())
			local target = Tab:GetSelectedTarget()
			assert.is_table(target) -- eingeloggter Char ist immer da
			assert.truthy(content._emptyState.hint:GetText()
				:find(target.name, 1, true))
		end)

		it("Bank mit gewaehltem Charakter ohne Bankdaten: Tipp nennt den Namen", function()
			local anna = Exo.Store:GetOrCreateCharacter("Default.Testrealm.Anna")
			anna.meta.name = "Anna"
			anna.meta.realm = "Testrealm"
			anna.meta.classID = 8

			local Tab = Exo.UI.BankTab
			Tab.targetIndex = 1
			local content = CreateFrame("Frame")
			Tab:Render(content)
			-- der eingeloggte Mock-Char koennte Target 1 sein -> gezielt Anna waehlen
			local targets = Tab.GetTargets()
			for index, t in ipairs(targets) do
				if t.name == "Anna" then Tab.targetIndex = index end
			end
			Tab:Render(content)
			assert.is_true(content._emptyState.host:IsShown())
			assert.truthy(content._emptyState.hint:GetText():find("Anna", 1, true))
		end)

		it("KM-Bank ohne Daten: einheitlicher Leerzustand mit eigenem Titel", function()
			local Tab = Exo.UI.WarbandBankTab
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.is_true(content._emptyState.host:IsShown())
			assert.truthy(content._emptyState.title:GetText()
				:find("Kriegsmeutenbank", 1, true))
		end)
	end)
end)
