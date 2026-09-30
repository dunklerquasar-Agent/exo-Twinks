-- spec/release_1_2_1_spec.lua
-- 1.2.1: Mail-Inhalte, Gildenbank-Browse, Warband-Freiplaetze.
local mock = require("spec.wow_mock")

describe("Release 1.2.1", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
	end)

	describe("Mail-Inhalte (Punkt 8)", function()
		local mail = { sender = "Bob", subject = "Kram", money = 150000, daysLeft = 10,
			items = {
				{ id = 777, count = 20, name = "Friedensblume" },
				{ id = 778, count = 1 },
				{ id = 555, count = 3, name = "Kupferbarren" },
				{ id = 556, count = 1, name = "Zinnbarren" },
			} }

		it("ContentText nennt Itemnamen, kappt bei 3, haengt Gold an", function()
			mock.SetItemNames({ [778] = "Silberblatt" })
			mock.SetItemDetails({ [777] = { quality = 2, classID = 7, type = "X" } })
			local text = Exo.UI.MailTab.ContentText(mail)
			assert.matches("Friedensblume", text)
			assert.matches("x20", text)
			assert.matches("|cff1eff00", text)      -- Qualitaetsfarbe (gruen)
			assert.matches("Silberblatt", text)     -- Name aus dem Item-Cache
			assert.matches("%+1 weitere", text)     -- Zinnbarren gekappt
			assert.matches("15", text)              -- Gold
		end)

		it("Shift-Klick auf die Mail-Zeile fuegt alle Anhaenge als Links ein", function()
			local char = Exo.Store:GetOrCreateCharacter("Default.Testrealm.Anna")
			char.meta.name = "Anna"
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mails",
				{ scannedAt = Exo.WowAPI.Now(), list = { mail } })
			mock.SetItemNames({ [777] = "Friedensblume", [778] = "Silberblatt",
				[555] = "Kupferbarren", [556] = "Zinnbarren" })

			local Tab = Exo.UI.MailTab
			Tab:Render(CreateFrame("Frame"))
			-- Zeile 1 = Char-Kopf, Zeile 2 = Mail
			local row = Tab._GetScroller().rows[2]
			assert.is_table(row._mailItems)

			mock.SetShiftDown(true)
			row._scripts.OnMouseDown(row)
			mock.SetShiftDown(false)
			assert.equal(4, #mock.GetChatLinks())
			assert.matches("777", mock.GetChatLinks()[1])
		end)
	end)

	describe("Gildenbank-Browse (Punkt 5)", function()
		before_each(function()
			mock.SetGuildBank("Nachtwache", {
				[1] = { [1] = { id = 777, count = 40 }, [2] = { id = 555, count = 3 } },
			})
			mock.FireEvent("GUILDBANKFRAME_OPENED")
			mock.SetItemNames({ [777] = "Friedensblume", [555] = "Kupferbarren" })
		end)

		it("GetGuildItems aggregiert die Gildenbank", function()
			local items = Exo.API.GetGuildItems("Nachtwache")
			assert.equal(2, #items)
			local total = 0
			for _, item in ipairs(items) do total = total + item.total end
			assert.equal(43, total)
			assert.same({}, Exo.API.GetGuildItems("Unbekannt"))
		end)

		it("Inventar bietet die Gildenbank als Ziel; GatherItems liefert", function()
			local Tab = Exo.UI.InventoryTab
			local found
			for _, target in ipairs(Tab.GetTargets()) do
				if target.key == "__guild:Nachtwache" then found = target end
			end
			assert.is_table(found)
			assert.matches("Gildenbank", found.label)
			assert.matches("Nachtwache", found.label)

			local items = Tab.GatherItems("__guild:Nachtwache")
			assert.equal(2, #items)
			assert.is_string(items[1].name) -- Namen aufgeloest
		end)
	end)

	describe("Warband-Freiplaetze (Punkt 7)", function()
		before_each(function()
			Exo.Store:WriteAccountData("warbandBank", {
				[13] = { size = 98, free = 90, items = { [1] = { id = 1, count = 8 } } },
				[14] = { size = 98, items = { [1] = { id = 2, count = 1 } } }, -- ohne free
			})
		end)

		it("GetWarbandSpace summiert (free-Feld optional)", function()
			local space = Exo.API.GetWarbandSpace()
			assert.equal(196, space.size)
			assert.equal(187, space.free) -- 90 + (98-1)
		end)

		it("Modul 'Taschenplaetze' zeigt die Kriegsmeuten-Zeile", function()
			local rows = Exo.UI.OverviewTab.BuildModuleRows("bags")
			local all = ""
			for _, row in ipairs(rows) do all = all .. row.text .. "\n" end
			assert.matches("Kriegsmeute", all)
			assert.matches("187/196 frei", all)
		end)

		it("Inventar-Footer zeigt Frei-Plaetze fuer die Kriegsmeute", function()
			local Tab = Exo.UI.InventoryTab
			Tab.mode = "browse"
			local content = CreateFrame("Frame")
			Tab:Render(content)
			-- Ziel auf Kriegsmeute stellen
			for index, target in ipairs(Tab.GetTargets()) do
				if target.key == "__warband" then Tab.targetIndex = index end
			end
			Tab:Render(content)
			assert.matches("Frei: 187/196 Plaetze", Tab._GetFooter():GetText())
		end)
	end)
end)
