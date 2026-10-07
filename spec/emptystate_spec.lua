-- spec/emptystate_spec.lua
-- Einheitlicher Leerzustand (1.19.0): Exo.UI.EmptyState-Widget + Anbindung
-- in den Reitern Bank / KM-Bank / KM-Items / Inventar / Charaktere /
-- Berufe / Ruf / Post / Suche / Uebersicht / Char-Details.
local mock = require("spec.wow_mock")

describe("Exo.UI.EmptyState (1.19.0)", function()
	local Exo, ES

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		ES = Exo.UI.EmptyState
	end)

	describe("Widget", function()
		it("Attach ist idempotent (dieselbe Host-Flaeche)", function()
			local content = CreateFrame("Frame")
			local first = ES.Attach(content, { top = 10, bottom = 5 })
			local second = ES.Attach(content, { top = 99, bottom = 99 })
			assert.are.same(first, second)
			assert.is_false(first.host:IsShown())
		end)

		it("Show: Titel + Tipp zentriert, grau gefaerbt", function()
			local content = CreateFrame("Frame")
			ES.Show(content, "Noch keine Bankdaten.", "Einmal die Bank oeffnen.")
			local es = content._emptyState
			assert.is_true(es.host:IsShown())
			assert.matches("|cff808080Noch keine Bankdaten.|r", es.title:GetText())
			assert.matches("|cff808080Einmal die Bank oeffnen.|r", es.hint:GetText())
			assert.is_true(es.hint:IsShown())
		end)

		it("Show ohne Tipp versteckt die Tipp-Zeile", function()
			local content = CreateFrame("Frame")
			ES.Show(content, "Keine Treffer.")
			local es = content._emptyState
			assert.is_true(es.host:IsShown())
			assert.is_false(es.hint:IsShown())
			assert.equal("", es.hint:GetText())
		end)

		it("Hide: Host wird ausgeblendet und ist wiederverwendbar", function()
			local content = CreateFrame("Frame")
			ES.Show(content, "Noch keine Daten.", "Tipp.")
			ES.Hide(content)
			local es = content._emptyState
			assert.is_false(es.host:IsShown())
			-- Wiederverwendung: zweites Show zeigt denselben Host
			ES.Show(content, "Noch keine Daten.", "Tipp.")
			assert.is_true(es.host:IsShown())
		end)

		it("Hide ohne Attach ist ein No-Op", function()
			local content = CreateFrame("Frame")
			assert.has_no.errors(function() ES.Hide(content) end)
		end)

		it("Text(): fertiger grauer Zeilen-Text mit optionalem Tipp", function()
			assert.equal("|cff808080Noch keine Daten.|r", ES.Text("Noch keine Daten."))
			assert.equal("|cff808080Noch keine Auktionsdaten.|r  |cff808080Auktionshaus einmal oeffnen.|r",
				ES.Text("Noch keine Auktionsdaten.", "Auktionshaus einmal oeffnen."))
		end)
	end)

	describe("ItemList-Integration (Bank / KM-Bank / KM-Items)", function()
		it("Bank: Daten vorhanden -> Leerzustand ausgeblendet", function()
			local Store = Exo.Store
			local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
			anna.meta.name = "Anna"
			anna.meta.realm = "Testrealm"
			anna.meta.classID = 8
			Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
				[6] = { size = 98, free = 96, items = { [1] = { id = 901, count = 3 } } },
			})
			mock.SetItemNames({ [901] = "Kriegsgebundenes Schwert" })
			mock.SetItemDetails({ [901] = { bindType = 2, quality = 4, icon = 1111 } })

			local Tab = Exo.UI.BankTab
			Tab.targetIndex = 1
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.is_true(#Tab._GetScroller().items > 0)
			assert.is_false(content._emptyState.host:IsShown())
		end)

		it("KM-Items: ohne Chars -> Leerzustand, nach Daten -> ausgeblendet", function()
			local Tab = Exo.UI.WarboundTab
			local content = CreateFrame("Frame")

			Tab:Render(content) -- noch keine Chars
			assert.is_true(content._emptyState.host:IsShown())
			assert.truthy(content._emptyState.title:GetText():find(
				"Noch keine kriegsmeutengebundenen", 1, true))

			-- Char mit warbound-Item anlegen
			local Store = Exo.Store
			local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
			anna.meta.name = "Anna"
			anna.meta.realm = "Testrealm"
			anna.meta.classID = 8
			Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
				[0] = { size = 16, free = 15, items = { [1] = { id = 901, count = 2 } } },
			})
			mock.SetItemNames({ [901] = "Kriegsgebundenes Schwert" })
			mock.SetItemDetails({ [901] = { bindType = 8, quality = 4, icon = 1111 } })

			Tab:Render(content)
			assert.is_false(content._emptyState.host:IsShown())
			assert.is_true(#Tab._GetScroller().items > 0)
		end)
	end)

	describe("Suche: 0 Treffer bei gueltiger Eingabe (1.19.0)", function()
		local Tab

		before_each(function()
			Tab = Exo.UI.SearchTab
			Tab.query = ""
		end)

		it("0 Treffer -> 'Keine Treffer.' statt leerer Liste", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab.query = "xyznichts"
			Tab:Render(content)
			assert.equal(0, #Tab._GetScroller():GetData())
			local es = content._emptyState
			assert.is_true(es.host:IsShown())
			assert.truthy(es.title:GetText():find("Keine Treffer", 1, true))
			assert.truthy(es.hint:GetText():find("Suchbegriff oder Filter", 1, true))
		end)

		it("zu kurze Eingabe = Eingabe-Zustand, kein Leerzustand", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab.query = "x"
			Tab:Render(content)
			assert.is_false(content._emptyState.host:IsShown())
			assert.truthy(Tab._GetFooter():GetText():find("Mindestens", 1, true))
		end)

		it("mit Treffer wird der Leerzustand wieder ausgeblendet", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab.query = "xyznichts"
			Tab:Render(content)
			assert.is_true(content._emptyState.host:IsShown())

			-- Item anlegen, das auf "xyznichts" trifft
			local Store = Exo.Store
			local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
			anna.meta.name = "Anna"
			anna.meta.realm = "Testrealm"
			anna.meta.classID = 8
			Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
				[0] = { size = 16, free = 15, items = { [1] = { id = 777, count = 1 } } },
			})
			mock.SetItemNames({ [777] = "xyznichts-Bot" })
			mock.SetItemDetails({ [777] = { bindType = 2, quality = 1, icon = 4444 } })

			Tab:Render(content)
			assert.is_false(content._emptyState.host:IsShown())
			assert.is_true(#Tab._GetScroller():GetData() > 0)
		end)
	end)

	describe("Charaktere: Detail-Modus blendet Leerzustand aus (1.19.0)", function()
		it("leere Matrix zeigt Widget, Detail-Panel und Daten ausblenden es", function()
			local Tab = Exo.UI.CharactersTab
			local content = CreateFrame("Frame")

			-- Simulierten Login-Char loeschen, damit die Matrix wirklich leer ist
			Exo.Store:DeleteCharacter(Exo.Store:GetCurrentKey())
			Tab:Render(content) -- keine Chars
			assert.is_true(content._emptyState.host:IsShown())

			-- Char anlegen
			local Store = Exo.Store
			local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
			anna.meta.name = "Anna"
			anna.meta.realm = "Testrealm"
			anna.meta.classID = 8
			Tab:Render(content)
			assert.is_false(content._emptyState.host:IsShown()) -- Daten da

			-- Detail-Panel: Widget bleibt ausgeblendet
			Tab:OpenDetail("Default.Testrealm.Anna")
			Tab:Render(content)
			assert.is_true(Tab.detailKey ~= nil)
			assert.is_false(content._emptyState.host:IsShown())

			-- Detail schliessen: Widget bleibt ausgeblendet
			Tab.detailKey = nil
			Tab:Render(content)
			assert.is_false(content._emptyState.host:IsShown())
		end)
	end)

	describe("Uebersicht + Char-Details: einheitliche Leerzeilen (1.19.0)", function()
		it("leeres Uebersichts-Modul zeigt 'Noch keine Daten.'", function()
			local Overview = Exo.UI.OverviewTab
			local rows = Overview.BuildRows()
			local found = false
			for _, row in ipairs(rows) do
				if row.text and row.text:find("Noch keine Daten", 1, true) then
					found = true
				end
			end
			assert.is_true(found) -- z. B. Modul "currencies" ohne Daten
		end)

		it("Char-Details: leere Sektionen tragen einheitliche Leerzeilen", function()
			local Store = Exo.Store
			local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
			anna.meta.name = "Anna"
			anna.meta.realm = "Testrealm"
			anna.meta.classID = 8
			local Detail = Exo.UI.CharacterDetail
			local rows = Detail.BuildDetailRows("Default.Testrealm.Anna", nil)
			local text = ""
			for _, row in ipairs(rows) do text = text .. (row.label or "") .. "\n" end
			assert.truthy(text:find("Noch keine aktiven Raid-IDs", 1, true))
			assert.truthy(text:find("Noch keine aktiven Quests", 1, true))
			assert.truthy(text:find("Noch keine Waehrungen", 1, true))
		end)
	end)

	describe("Inventar: Suche-Modus verwendet eigenen Leerzustand (1.19.0)", function()
		it("in der Suche ist der Browse-Leerzustand ausgeblendet", function()
			local Tab = Exo.UI.InventoryTab
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab:SetMode("search")
			Tab:Render(content)
			assert.is_false(content._emptyState.host:IsShown())
		end)
	end)
end)
