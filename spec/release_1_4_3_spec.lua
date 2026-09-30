-- spec/release_1_4_3_spec.lua
-- UI-Poliersprint: Hover, Item-Icons, Erststart-Defaults, letzter Tab,
-- Farb-Diaet.
local mock = require("spec.wow_mock")

describe("Release 1.4.3 (UI-Poliersprint)", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
	end)

	describe("Hover-Aufhellung", function()
		it("klickbare Listenzeilen bekommen einen Highlight-Layer", function()
			local Widgets = Exo.UI.Widgets
			local row = CreateFrame("Frame")
			local highlight = Widgets.AddRowHighlight(row)
			assert.is_truthy(highlight)
			assert.equal(highlight, row.highlight)

			-- Verkabelung in den Tabs: Zeilen tragen das Feld nach dem Rendern
			local Overview = Exo.UI.OverviewTab
			Overview:Render(CreateFrame("Frame"))
			assert.is_truthy(Overview._GetScroller().rows[1].highlight)
		end)
	end)

	describe("Item-Icons (Suche/Post/Inventar)", function()
		it("Suche-Zeilen zeigen das Item-Icon", function()
			local key = Exo.Store:GetCurrentKey()
			Exo.Store:WriteCharacterData(key, "bags", {
				[0] = { size = 16, free = 15, items = { [1] = { id = 777, count = 5 } } },
			})
			mock.SetItemNames({ [777] = "Friedensblume" })
			local Search = Exo.UI.SearchTab
			Search.ResetFilters()
			Search.query = "friedensblume"
			Search:Render(CreateFrame("Frame"))
			local row = Search._GetScroller().rows[1]
			assert.is_truthy(row.icon) -- Icon-Textur existiert und wurde gesetzt
		end)

		it("Post-Zeilen zeigen das Icon des ersten Anhangs", function()
			local char = Exo.Store:GetOrCreateCharacter("Default.Testrealm.Anna")
			char.meta.name = "Anna"
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mails", {
				scannedAt = Exo.WowAPI.Now(),
				list = { { sender = "B", subject = "X", money = 0, daysLeft = 10,
					items = { { id = 777, count = 2 } } } },
			})
			local Tab = Exo.UI.MailTab
			Tab:Render(CreateFrame("Frame"))
			assert.is_truthy(Tab._GetScroller().rows[2].icon)
		end)
	end)

	describe("Erststart-Defaults der Uebersicht", function()
		it("klappt beim ersten Render alles ausser chars/keys/scan ein", function()
			local Tab = Exo.UI.OverviewTab
			Tab:Render(CreateFrame("Frame"))
			assert.is_true(Exo.API.GetOption("overview.initialized", false))
			assert.is_false(Tab.IsCollapsed("chars"))
			assert.is_false(Tab.IsCollapsed("keys"))
			assert.is_false(Tab.IsCollapsed("scan"))
			assert.is_true(Tab.IsCollapsed("currencies"))
			assert.is_true(Tab.IsCollapsed("inventory"))
		end)

		it("greift NICHT, wenn die Uebersicht schon benutzt wurde", function()
			Exo.API.SetOption("overview.order", "locks,chars,currencies,inventory,"
				.. "realms,keys,bags,scan,tax,auctions")
			local Tab = Exo.UI.OverviewTab
			Tab:Render(CreateFrame("Frame"))
			assert.is_false(Tab.IsCollapsed("currencies")) -- unangetastet
		end)

		it("laeuft nur einmal (Nutzer-Aenderungen bleiben)", function()
			local Tab = Exo.UI.OverviewTab
			local content = CreateFrame("Frame")
			Tab:Render(content)
			Tab.ToggleCollapsed("currencies") -- Nutzer klappt wieder auf
			Tab:Render(content)
			assert.is_false(Tab.IsCollapsed("currencies"))
		end)
	end)

	describe("Letzten Reiter merken", function()
		it("SelectTab speichert, Show stellt wieder her", function()
			Exo.UI:Show()
			Exo.UI:SelectTab("inventory")
			assert.equal("inventory", Exo.API.GetOption("window.lastTab"))

			Exo.UI.activeTabId = nil -- simulierter Neustart der UI-Session
			Exo.UI:Show()
			assert.equal("inventory", Exo.UI.activeTabId)
		end)

		it("ignoriert gemerkte Reiter, die es nicht mehr gibt", function()
			Exo.API.SetOption("window.lastTab", "gibtsnicht")
			Exo.UI.activeTabId = nil
			Exo.UI:Show()
			assert.equal("overview", Exo.UI.activeTabId)
		end)
	end)

	describe("Farb-Diaet", function()
		it("Charzeile der Uebersicht: M+-Wertung ohne Extra-Farbcode", function()
			local char = Exo.Store:GetOrCreateCharacter("Default.Testrealm.Anna")
			char.meta.name = "Anna"
			char.equipment = { avgItemLevelEquipped = 480, slots = {} }
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mythicplus",
				{ rating = 3044, dungeons = {}, vault = {} })
			local rows = Exo.UI.OverviewTab.BuildModuleRows("chars")
			local line
			for _, row in ipairs(rows) do
				if row.text:find("Anna", 1, true) then line = row.text end
			end
			assert.matches("M%+ 3044", line)
			assert.is_nil(line:find("M%+ |c")) -- keine eigene Wertungsfarbe mehr
		end)
	end)
end)
