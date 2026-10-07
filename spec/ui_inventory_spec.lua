-- spec/ui_inventory_spec.lua
local mock = require("spec.wow_mock")

describe("ExoTwinksUI / Inventar-Tab", function()
	local Exo, Tab

	local function seed()
		local Store = Exo.Store

		local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
		anna.meta.name = "Anna"
		anna.meta.realm = "Testrealm"
		anna.meta.classID = 8 -- Magier
		Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
			[0] = { size = 16, free = 13, items = {
				[1] = { id = 777, count = 10 },
				[2] = { id = 778, count = 4 },
				[3] = { id = 777, count = 5 },  -- zweiter Stack -> muss aggregiert werden
			} },
		})
		Store:WriteCharacterData("Default.Testrealm.Anna", "bank", {
			[6] = { size = 98, free = 97, items = { [1] = { id = 777, count = 7 } } },
		})

		local borg = Store:GetOrCreateCharacter("Default.Testrealm.Borg")
		borg.meta.name = "Borg"
		borg.meta.realm = "Testrealm"

		Store:WriteAccountData("warbandBank", {
			[13] = { size = 98, free = 97, items = { [1] = { id = 778, count = 20 } } },
		})

		mock.SetItemNames({ [777] = "Friedensblume", [778] = "Silberblatt" })
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.InventoryTab
		Tab.targetIndex = 1
		Tab.sortBy, Tab.sortDesc = "total", true
		Tab.viewMode = "list"
		Tab.mode = "browse"
		Tab.groupModeIndex = 1
		-- Login-Char loeschen, damit die Zahlen deterministisch sind
		Exo.Store:DeleteCharacter(Exo.Store:GetCurrentKey())
		seed()
	end)

	describe("API.GetCharacterItems", function()
		it("aggregiert Stacks ueber Taschen und Bank", function()
			local items = Exo.API.GetCharacterItems("Default.Testrealm.Anna")
			local byId = {}
			for _, item in ipairs(items) do byId[item.itemID] = item end

			assert.equal(15, byId[777].bags)   -- 10 + 5 (zwei Stacks)
			assert.equal(7, byId[777].bank)
			assert.equal(22, byId[777].total)
			assert.equal(4, byId[778].total)
		end)

		it("liefert leere Liste fuer unbekannte/leere Chars", function()
			assert.same({}, Exo.API.GetCharacterItems("Default.Testrealm.Nix"))
			assert.same({}, Exo.API.GetCharacterItems("Default.Testrealm.Borg"))
		end)
	end)

	describe("API.GetWarbandItems", function()
		it("liefert die Kriegsmeutenbank mit Gesamtzahl", function()
			local items = Exo.API.GetWarbandItems()
			assert.equal(1, #items)
			assert.equal(778, items[1].itemID)
			assert.equal(20, items[1].total)
		end)
	end)

	describe("GetTargets", function()
		it("listet Chars Realm-sortiert plus Kriegsmeutenbank am Ende", function()
			local targets = Tab.GetTargets()
			assert.equal(3, #targets)
			assert.equal("Default.Testrealm.Anna", targets[1].key)
			assert.equal("Default.Testrealm.Borg", targets[2].key)
			assert.equal("__warband", targets[3].key)
			-- Klassenfarbe im Label (Anna = Magier)
			assert.truthy(targets[1].label:find("|cff69ccf0Anna|r", 1, true))
		end)
	end)

	describe("GatherItems + SortItems", function()
		it("loest Namen auf und sortiert nach Anzahl absteigend", function()
			local items = Tab.SortItems(Tab.GatherItems("Default.Testrealm.Anna"), "total", true)
			assert.equal("Friedensblume", items[1].name)
			assert.equal(22, items[1].total)
			assert.equal("Silberblatt", items[2].name)
		end)

		it("sortiert nach Name aufsteigend", function()
			local items = Tab.SortItems(Tab.GatherItems("Default.Testrealm.Anna"), "name", false)
			assert.equal("Friedensblume", items[1].name)
		end)
	end)

	describe("Gruppierung + Qualitaetsfarben (0.10.1)", function()
		before_each(function()
			mock.SetItemDetails({
				[777] = { quality = 2, classID = 7, type = "Handwerksmaterial" },
				[778] = { quality = 4, classID = 4, type = "Ruestung" },
			})
		end)

		it("GatherItems liefert Qualitaet und Itemklasse mit", function()
			local items = Tab.GatherItems("Default.Testrealm.Anna")
			local byId = {}
			for _, item in ipairs(items) do byId[item.itemID] = item end
			assert.equal(2, byId[777].quality)
			assert.equal(7, byId[777].classID)
			assert.equal("Handwerksmaterial", byId[777].typeName)
		end)

		it("BuildRows gruppiert nach Typ in fester Reihenfolge (Ruestung vor Handwerk)", function()
			local rows = Tab.BuildRows(Tab.GatherItems("Default.Testrealm.Anna"), "total", true)
			assert.equal(4, #rows)
			assert.is_true(rows[1].section)
			assert.equal("Ruestung", rows[1].label)
			assert.equal(778, rows[2].itemID)
			assert.is_true(rows[3].section)
			assert.equal("Handwerksmaterial", rows[3].label)
			assert.equal(777, rows[4].itemID)
			assert.equal(1, rows[3].count)
			assert.equal(22, rows[3].pieces)
		end)

		it("Items ohne Klassen-Info landen unter 'Sonstiges' am Ende", function()
			mock.SetItemDetails({ [778] = { quality = 4, classID = 4, type = "Ruestung" } })
			local rows = Tab.BuildRows(Tab.GatherItems("Default.Testrealm.Anna"), "total", true)
			assert.equal("Ruestung", rows[1].label)
			assert.equal("Sonstiges", rows[3].label)
		end)

		it("Format.ItemName faerbt nach Seltenheit", function()
			local Format = Exo.UI.Format
			assert.equal("|cffa335eeEpicgurt|r", Format.ItemName("Epicgurt", 4))
			assert.equal("|cff1eff00Kraut|r", Format.ItemName("Kraut", 2))
			assert.equal("Unbekannt", Format.ItemName("Unbekannt", nil))
		end)

		it("Namenszelle nutzt die Qualitaetsfarbe", function()
			local items = Tab.GatherItems("Default.Testrealm.Anna")
			local byId = {}
			for _, item in ipairs(items) do byId[item.itemID] = item end
			local nameCol
			for _, col in ipairs(Tab.COLUMNS) do
				if col.id == "name" then nameCol = col end
			end
			assert.equal("|cffa335eeSilberblatt|r |cff808080(778)|r", nameCol.text(byId[778]))
		end)
	end)

	describe("Erweiterungs-Prioritaet + Symbolansicht (0.10.2)", function()
		before_each(function()
			-- beide Items im selben Typ, aber verschiedene Erweiterungen:
			-- 778 (Midnight, exp 11) muss VOR 777 (alt, exp 5) stehen,
			-- obwohl 777 die groessere Anzahl hat (22 vs 4)
			mock.SetItemDetails({
				[777] = { quality = 2, classID = 7, type = "Handwerksmaterial",
					expansion = 5, icon = 133939 },
				[778] = { quality = 4, classID = 7, type = "Handwerksmaterial",
					expansion = 11, icon = 134571 },
			})
		end)

		it("aktuelle Erweiterung steht in der Gruppe zuerst", function()
			local rows = Tab.BuildRows(Tab.GatherItems("Default.Testrealm.Anna"), "total", true)
			assert.is_true(rows[1].section)
			assert.equal(778, rows[2].itemID) -- Midnight zuerst
			assert.equal(777, rows[3].itemID) -- Altbestand danach
		end)

		it("GatherItems markiert aktuelle Erweiterung und liefert Icons", function()
			local items = Tab.GatherItems("Default.Testrealm.Anna")
			local byId = {}
			for _, item in ipairs(items) do byId[item.itemID] = item end
			assert.is_true(byId[778].isCurrentExpac)
			assert.is_false(byId[777].isCurrentExpac)
			assert.equal(134571, byId[778].icon)
		end)

		it("BuildIconRows: Sektionen + Icon-Zeilen mit perRow-Grenze", function()
			local items = Tab.GatherItems("Default.Testrealm.Anna")
			local rows = Tab.BuildIconRows(items, "total", true, 1)
			-- 1 Sektion + 2 Icon-Zeilen (perRow = 1)
			assert.equal(3, #rows)
			assert.is_true(rows[1].section)
			assert.equal(778, rows[2].icons[1].itemID)
			assert.equal(777, rows[3].icons[1].itemID)

			rows = Tab.BuildIconRows(items, "total", true, 18)
			assert.equal(2, #rows) -- 1 Sektion + 1 Icon-Zeile mit beiden Items
			assert.equal(2, #rows[2].icons)
		end)

		it("Umschalter wechselt zwischen Liste und Symbolen", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.equal("list", Tab.viewMode)
			assert.equal(3, #Tab._GetScroller():GetData())
			assert.equal(0, #Tab._GetIconScroller():GetData())
			assert.equal("Symbole", Tab._GetViewButton():GetText())

			Tab:OnViewClick()
			assert.equal("icons", Tab.viewMode)
			assert.equal(0, #Tab._GetScroller():GetData())
			assert.equal(2, #Tab._GetIconScroller():GetData()) -- Sektion + Icon-Zeile
			assert.equal("Liste", Tab._GetViewButton():GetText())

			Tab:OnViewClick()
			assert.equal("list", Tab.viewMode)
			assert.equal(3, #Tab._GetScroller():GetData())
		end)
	end)

	describe("Ziel-Aufklappliste (1.4.1)", function()
		it("Klick auf den Charakter-Button oeffnet/schliesst die Liste", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.is_false(Tab._GetTargetDropdown():IsShown())

			Tab:OnTargetClick()
			assert.is_true(Tab._GetTargetDropdown():IsShown())
			local targets = Tab.GetTargets()
			assert.equal(#targets, #Tab._GetDropdownScroller():GetData())

			Tab:OnTargetClick() -- zweiter Klick schliesst
			assert.is_false(Tab._GetTargetDropdown():IsShown())
		end)

		it("Klick auf einen Eintrag waehlt das Ziel und schliesst", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab:OnTargetClick()
			local row = Tab._GetDropdownScroller().rows[2]
			assert.equal(2, row._targetIndex)
			row._scripts.OnMouseDown(row)
			assert.equal(2, Tab.targetIndex)
			assert.is_false(Tab._GetTargetDropdown():IsShown())
			assert.equal(Tab.GetTargets()[2].label, Tab._GetTargetButton():GetText())
		end)

		it("Suche-Modus schliesst die Liste", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab:OnTargetClick()
			assert.is_true(Tab._GetTargetDropdown():IsShown())
			Tab:SetMode("search")
			assert.is_false(Tab._GetTargetDropdown():IsShown())
			Tab:SetMode("browse")
		end)
	end)

	describe("Modus Bestand | Suche (0.13.0)", function()
		it("Suche-Modus versteckt die Browse-UI und bettet die Suche ein", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.is_false(Tab._GetSearchHost():IsShown())
			assert.is_true(Tab._GetModeButtons().browse._selected)

			Tab:SetMode("search")
			assert.is_true(Tab._GetSearchHost():IsShown())
			assert.is_true(Tab._GetModeButtons().search._selected)
			assert.is_false(Tab._GetTargetButton():IsShown())
			assert.is_false(Tab._GetScroller():GetFrame():IsShown())
			-- die eingebettete Suche hat in den Host gerendert
			assert.equal(Tab._GetSearchHost(), Exo.UI.SearchTab._content)

			Tab:SetMode("browse")
			assert.is_false(Tab._GetSearchHost():IsShown())
			assert.is_true(Tab._GetTargetButton():IsShown())
		end)
	end)

	describe("Scroll-Fix + vergroesserbares Fenster (0.10.4)", function()
		it("versteckt den inaktiven Scroller (sonst schluckt er das Mausrad)", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.is_true(Tab._GetScroller():GetFrame():IsShown())
			assert.is_false(Tab._GetIconScroller():GetFrame():IsShown())

			Tab:OnViewClick() -- auf Symbole
			assert.is_false(Tab._GetScroller():GetFrame():IsShown())
			assert.is_true(Tab._GetIconScroller():GetFrame():IsShown())

			Tab:OnViewClick() -- zurueck auf Liste
			assert.is_true(Tab._GetScroller():GetFrame():IsShown())
			assert.is_false(Tab._GetIconScroller():GetFrame():IsShown())
		end)

		it("IconsPerRow passt sich der Fensterbreite an", function()
			assert.equal(Tab.ICONS_PER_ROW, Tab.IconsPerRow(nil)) -- Fallback
			local content = CreateFrame("Frame")
			content.GetWidth = function() return 368 end -- (368-8)/36 = 10
			assert.equal(10, Tab.IconsPerRow(content))
			content.GetWidth = function() return 1088 end -- (1088-8)/36 = 30
			assert.equal(30, Tab.IconsPerRow(content))
			content.GetWidth = function() return 50 end -- Untergrenze 4
			assert.equal(4, Tab.IconsPerRow(content))
		end)
	end)

	describe("Gruppierungs-Modi wie BetterBags (0.10.3)", function()
		before_each(function()
			mock.SetItemDetails({
				[777] = { quality = 2, classID = 7, subclassID = 9, type = "Handwerksmaterial",
					subtype = "Kraeuter", expansion = 5, icon = 133939 },
				[778] = { quality = 4, classID = 7, subclassID = 7, type = "Handwerksmaterial",
					subtype = "Erz", expansion = 11, icon = 134571 },
			})
		end)

		local function sectionLabels(rows)
			local labels = {}
			for _, row in ipairs(rows) do
				if row.section then labels[#labels + 1] = row.label end
			end
			return labels
		end

		it("Unterart: eigene Sektion pro Subklasse", function()
			local items = Tab.GatherItems("Default.Testrealm.Anna")
			local rows = Tab.BuildRows(items, "total", true, "subtype")
			-- gleiche Klasse (7), aber zwei Unterarten -> zwei Sektionen
			assert.same({ "Erz", "Kraeuter" }, sectionLabels(rows))
		end)

		it("Seltenheit: hoechste Qualitaet zuerst", function()
			local items = Tab.GatherItems("Default.Testrealm.Anna")
			local rows = Tab.BuildRows(items, "total", true, "quality")
			assert.same({ "Episch", "Ungewoehnlich" }, sectionLabels(rows))
			assert.equal(778, rows[2].itemID)
		end)

		it("Erweiterung: neueste zuerst, unbekannte ans Ende", function()
			local items = Tab.GatherItems("Default.Testrealm.Anna")
			local rows = Tab.BuildRows(items, "total", true, "expansion")
			assert.same({ "Midnight", "Warlords of Draenor" }, sectionLabels(rows))

			mock.SetItemDetails({ [778] = { quality = 4, classID = 7, type = "X", expansion = 11 } })
			rows = Tab.BuildRows(Tab.GatherItems("Default.Testrealm.Anna"), "total", true, "expansion")
			assert.same({ "Midnight", "Unbekannt" }, sectionLabels(rows))
		end)

		it("Gruppe-Button zykliert Typ -> Unterart -> Seltenheit -> Erweiterung -> Typ", function()
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.equal("Gruppe: Typ", Tab._GetGroupButton():GetText())

			Tab:OnGroupClick()
			assert.equal("subtype", Tab:GetGroupMode().id)
			assert.equal("Gruppe: Unterart", Tab._GetGroupButton():GetText())
			-- Liste zeigt jetzt zwei Unterart-Sektionen + 2 Items
			assert.equal(4, #Tab._GetScroller():GetData())

			Tab:OnGroupClick()
			assert.equal("quality", Tab:GetGroupMode().id)
			Tab:OnGroupClick()
			assert.equal("expansion", Tab:GetGroupMode().id)
			Tab:OnGroupClick()
			assert.equal("type", Tab:GetGroupMode().id)
		end)

		it("Symbolansicht respektiert den Gruppierungs-Modus", function()
			local items = Tab.GatherItems("Default.Testrealm.Anna")
			local rows = Tab.BuildIconRows(items, "total", true, 18, "quality")
			assert.equal("Episch", rows[1].label)
			assert.equal(778, rows[2].icons[1].itemID)
			assert.equal("Ungewoehnlich", rows[3].label)
		end)
	end)

	describe("Render + Interaktion", function()
		local content

		before_each(function()
			content = CreateFrame("Frame")
			Tab:Render(content)
		end)

		it("zeigt die Items des ersten Charakters mit Typ-Kopfzeile und Fusszeile", function()
			-- 1 Sektions-Kopfzeile ("Sonstiges", keine Item-Details gemockt) + 2 Items
			local data = Tab._GetScroller():GetData()
			assert.equal(3, #data)
			assert.is_true(data[1].section)
			assert.equal("Sonstiges", data[1].label)
			local text = Tab._GetFooter():GetText()
			assert.truthy(text:find("2 Items in 1 Kategorie", 1, true))
			assert.truthy(text:find("26 Stueck gesamt", 1, true)) -- 22 + 4
		end)

		it("Zyklus-Button wechselt zum naechsten Char und zeigt Hinweis bei leeren Daten", function()
			Tab:CycleTarget() -- -> Borg (keine Taschendaten)
			assert.equal(0, #Tab._GetScroller():GetData())
			assert.truthy(Tab._GetFooter():GetText():find("Keine Daten", 1, true))
		end)

		it("Zyklus-Button erreicht die Kriegsmeutenbank und startet wieder vorn", function()
			Tab:CycleTarget() -- Borg
			Tab:CycleTarget() -- Kriegsmeute
			assert.equal(2, #Tab._GetScroller():GetData()) -- Kopfzeile + 1 Item
			assert.equal(20, Tab._GetScroller():GetData()[2].total)

			Tab:CycleTarget() -- wieder Anna
			assert.equal(3, #Tab._GetScroller():GetData())
		end)

		it("Header-Klick wechselt die Sortierung", function()
			Tab:OnHeaderClick("name")
			assert.equal("name", Tab.sortBy)
			assert.is_false(Tab.sortDesc)

			Tab:OnHeaderClick("name")
			assert.is_true(Tab.sortDesc)
			-- data[1] ist die Typ-Kopfzeile, data[2] das erste Item
			assert.equal("Silberblatt", Tab._GetScroller():GetData()[2].name)
		end)
	end)

	describe("Fenster-Integration", function()
		it("Inventar-Tab ist zwischen Suche und Schlachtzuegen registriert", function()
			assert.equal(Tab, Exo.UI.tabsById["inventory"])
			assert.equal("inventory", Exo.UI.tabs[3].id)
		end)
	end)
end)
