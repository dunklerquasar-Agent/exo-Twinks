-- spec/release_1_1_1_spec.lua
-- 1.1.1-Feinschliff: Alt-Klick, klickbarer Scan-Status, Post-Summary,
-- Footer-Zaehlungen, /exo help, ESC, Rezeptsuche-Sortierung.
local mock = require("spec.wow_mock")

describe("Release 1.1.1 (Feinschliff)", function()
	local Exo

	local function seedChar(charKey, opts)
		opts = opts or {}
		local char = Exo.Store:GetOrCreateCharacter(charKey)
		local _, realm, name = Exo.Schema.ParseCharKey(charKey)
		char.meta.name = name
		char.meta.realm = realm
		char.meta.classID = opts.classID or 1
		char.equipment = { avgItemLevelEquipped = opts.ilvl or 0, slots = {} }
		return char
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
	end)

	describe("Uebersicht", function()
		before_each(function() mock.LoadExoUI() end)

		it("MoveModuleBackward schiebt nach hinten; letzter bleibt letzter", function()
			local Tab = Exo.UI.OverviewTab
			Tab.MoveModuleBackward("chars")
			assert.equal("currencies", Tab.GetOrder()[1])
			assert.equal("chars", Tab.GetOrder()[2])
			local last = Tab.GetOrder()[#Tab.GetOrder()]
			Tab.MoveModuleBackward(last)
			assert.equal(last, Tab.GetOrder()[#Tab.GetOrder()])
		end)

		it("Alt-Klick auf die Kopfzeile nutzt MoveModuleBackward", function()
			local Tab = Exo.UI.OverviewTab
			local content = CreateFrame("Frame")
			Tab:Render(content)
			local row = Tab._GetScroller().rows[1]
			row._module = "chars"
			mock.SetAltDown(true)
			row._scripts.OnMouseDown(row)
			mock.SetAltDown(false)
			assert.equal("chars", Tab.GetOrder()[2])
			assert.is_false(Tab.IsCollapsed("chars")) -- kein Collapse ausgeloest
		end)

		it("Scan-Status-Zeilen tragen einen klickbaren Hinweis", function()
			seedChar("Default.Testrealm.Anna")
			local rows = Exo.UI.OverviewTab.BuildModuleRows("scan")
			assert.is_string(rows[1].hint)
			assert.matches("Anna", rows[1].hint)
			assert.matches("Bank besuchen", rows[1].hint)
		end)
	end)

	describe("Post", function()
		before_each(function() mock.LoadExoUI() end)

		it("Summary-Zeile oben bei dringenden Mails; Footer zaehlt", function()
			seedChar("Default.Testrealm.Anna")
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mails", {
				scannedAt = Exo.WowAPI.Now(),
				list = {
					{ sender = "B", subject = "bald", money = 0, daysLeft = 1, items = {} },
					{ sender = "C", subject = "ok", money = 0, daysLeft = 20, items = {} },
				},
			})
			local Tab = Exo.UI.MailTab
			local rows = Tab.BuildRows()
			assert.matches("1 Mail laeuft in unter 3 Tagen ab", rows[1].text)
			assert.matches("|cffff4538", rows[1].text)

			local content = CreateFrame("Frame")
			Tab:Render(content)
			assert.matches("2 Mails bei 1 Charakter", Tab._GetFooter():GetText())
		end)
	end)

	describe("Berufe", function()
		it("0 Rezepte -> gelbe Warnzeile mit Aktion", function()
			mock.LoadExoUI()
			seedChar("Default.Testrealm.Anna")
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "professions", {
				[171] = { name = "Alchemie", rank = 10, maxRank = 175, recipes = {} },
			})
			local rows = Exo.UI.ProfessionsTab.BuildRows("")
			assert.matches("|cffffd700", rows[2].text)
			assert.matches("Berufsfenster einmal oeffnen", rows[2].text)
		end)

		it("Rezeptsuche: meiste Koenner zuerst", function()
			local function seedProf(charKey, recipes)
				seedChar(charKey)
				Exo.Store:WriteCharacterData(charKey, "professions", {
					[171] = { name = "Alchemie", rank = 1, maxRank = 175,
						recipes = recipes },
				})
			end
			seedProf("Default.Testrealm.Anna",
				{ [1] = "Elixier A", [2] = "Elixier B" })
			seedProf("Default.Testrealm.Bob", { [2] = "Elixier B" })
			local results = Exo.API.SearchRecipes("elixier")
			assert.equal("Elixier B", results[1].name) -- 2 Koenner vor 1
			assert.equal(2, #results[1].knownBy)
		end)
	end)

	describe("Ruf-Footer", function()
		it("zaehlt Fraktionen", function()
			mock.LoadExoUI()
			seedChar("Default.Testrealm.Anna")
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "reputations", {
				[1] = { name = "Alpha", standingID = 6, value = 0, max = 100 },
				[2] = { name = "Beta", standingID = 4, value = 0, max = 100 },
			})
			local Tab = Exo.UI.ReputationsTab
			Tab.query = ""
			Tab:Render(CreateFrame("Frame"))
			assert.matches("2 Fraktionen", Tab._GetFooter():GetText())
		end)
	end)

	describe("/exo help + ESC", function()
		it("help listet keys, vault und mail", function()
			local before = #mock.printed
			_G.SlashCmdList["EXO"]("help")
			local out = table.concat(mock.printed, "\n", before + 1)
			assert.matches("/exo keys", out)
			assert.matches("/exo vault", out)
			assert.matches("/exo mail", out)
		end)

		it("Hauptfenster ist per ESC schliessbar (UISpecialFrames)", function()
			mock.LoadExoUI()
			Exo.UI:Show()
			local found = false
			for _, name in ipairs(_G.UISpecialFrames) do
				if name == "ExoTwinksMainWindow" then found = true end
			end
			assert.is_true(found)
		end)
	end)

	describe("Minimap: Scan-Luecken-Zeile", function()
		it("erscheint nur, wenn etwas fehlt", function()
			seedChar("Default.Testrealm.Anna") -- Bank/Post nie gescannt
			local all = table.concat(Exo.BuildMinimapTooltipLines(), "\n")
			assert.matches("Scan unvollstaendig", all)
		end)
	end)
end)
