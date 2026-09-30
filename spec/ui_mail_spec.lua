-- spec/ui_mail_spec.lua
-- Post-Tab (0.16.0) + Shift-Klick-Itemlinks
local mock = require("spec.wow_mock")

describe("ExoTwinksUI / Post-Tab", function()
	local Exo, Tab

	local function seedMails(charKey, scannedAt, list)
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = 2
		Exo.Store:WriteCharacterData(charKey, "mails",
			{ scannedAt = scannedAt, list = list })
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
		Tab = Exo.UI.MailTab
	end)

	describe("ExpiryText", function()
		it("faerbt nach Dringlichkeit", function()
			assert.matches("|cffff4538", Tab.ExpiryText(2))    -- < 3 Tage rot
			assert.matches("|cffffd700", Tab.ExpiryText(5))    -- < 7 Tage gelb
			assert.matches("|cff808080", Tab.ExpiryText(20))   -- sonst grau
			assert.matches("Std", Tab.ExpiryText(0.5))         -- unter 1 Tag in Stunden
		end)
	end)

	describe("BuildRows", function()
		it("Hinweis ohne Maildaten", function()
			assert.matches("Keine Maildaten", Tab.BuildRows()[1].text)
		end)

		it("Kopfzeile pro Char + eine Zeile je Mail", function()
			seedMails("Default.Testrealm.Anna", Exo.WowAPI.Now(), {
				{ sender = "Bob", subject = "Kraeuter", money = 0, daysLeft = 2,
					items = { { id = 777, count = 20 } } },
				{ sender = "AH", subject = "", money = 150000, daysLeft = 29, items = {} },
			})
			local rows = Tab.BuildRows()
			assert.matches("laeuft in unter 3 Tagen ab", rows[1].text) -- Summary
			assert.is_true(rows[2].header)
			assert.matches("Anna", rows[2].label)
			assert.matches("2 Mails", rows[2].label)
			assert.matches("Kraeuter", rows[3].text)
			assert.matches("von|r Bob", rows[3].text)
			assert.matches("Item 777 x20", rows[3].text) -- 1.2.1: Itemnamen statt Zaehler
			assert.matches("kein Betreff", rows[4].text)
			assert.matches("15", rows[4].text) -- 150000 Kupfer = 15g
		end)
	end)

	describe("Render + Registrierung", function()
		it("Post ist 8. Reiter (vor Designer)", function()
			assert.equal(Tab, Exo.UI.tabsById["mail"])
			assert.equal("mail", Exo.UI.tabs[8].id)
			assert.equal("reputations", Exo.UI.tabs[9].id)
			assert.equal("designer", Exo.UI.tabs[10].id)
		end)

		it("Warnzeile oben, Footer zaehlt Mails", function()
			seedMails("Default.Testrealm.Anna", Exo.WowAPI.Now(), {
				{ sender = "B", subject = "bald", money = 0, daysLeft = 1, items = {} },
			})
			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.matches("1 Mail laeuft in unter 3 Tagen ab",
				Tab._GetScroller():GetData()[1].text)
			assert.matches("1 Mail bei 1 Charakter", Tab._GetFooter():GetText())
		end)
	end)
end)

describe("Shift-Klick-Itemlinks (0.16.0)", function()
	local Exo

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		mock.LoadExoUI()
	end)

	it("Suche-Zeile fuegt bei Shift-Klick den Itemlink ein", function()
		local Search = Exo.UI.SearchTab
		Search.ResetFilters()
		Search.query = ""
		local key = Exo.Store:GetCurrentKey()
		Exo.Store:WriteCharacterData(key, "bags", {
			[0] = { size = 16, free = 15, items = { [1] = { id = 777, count = 5 } } },
		})
		mock.SetItemNames({ [777] = "Friedensblume" })

		local content = CreateFrame("Frame")
		Search.query = "friedensblume"
		Search:Render(content)

		local scroller = Search._GetScroller()
		assert.is_true(#scroller:GetData() >= 1)
		local row = scroller.rows[1]
		assert.equal(777, row._itemID)

		-- ohne Shift passiert nichts
		row._scripts.OnMouseDown(row)
		assert.equal(0, #mock.GetChatLinks())

		mock.SetShiftDown(true)
		row._scripts.OnMouseDown(row)
		assert.equal(1, #mock.GetChatLinks())
		assert.matches("777", mock.GetChatLinks()[1])
	end)
end)
