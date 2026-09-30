-- spec/containers_spec.lua
local mock = require("spec.wow_mock")

describe("Containers-Collector", function()
	local Exo

	local function currentChar()
		return Exo.Store:GetCharacter(Exo.Store:GetCurrentKey())
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()

		-- Rucksack (bagID 0): 16 Slots, 2 Items; Tasche 1: 30 Slots, 1 Item
		mock.SetContainer(0, 16, {
			[1] = { id = 6948, count = 1 },    -- Ruhestein
			[5] = { id = 190320, count = 200 },
		})
		mock.SetContainer(1, 30, {
			[12] = { id = 194017, count = 5 },
		})
	end)

	describe("Taschen", function()
		it("BAG_UPDATE-Sturm fuehrt zu genau EINEM entprellten Scan", function()
			mock.FireEvent("BAG_UPDATE", 0)
			mock.FireEvent("BAG_UPDATE", 0)
			mock.FireEvent("BAG_UPDATE", 1)

			assert.same({}, currentChar().bags) -- noch nichts
			mock.AdvanceTime(0.5)

			local bags = currentChar().bags
			assert.equal(16, bags[0].size)
			assert.equal(14, bags[0].free)
			assert.same({ id = 190320, count = 200 }, bags[0].items[5])
			assert.equal(30, bags[1].size)
			assert.equal(29, bags[1].free)
		end)

		it("PLAYER_ENTERING_WORLD stoesst initialen Taschen-Scan an", function()
			mock.FireEvent("PLAYER_ENTERING_WORLD")
			mock.AdvanceTime(0.5)
			assert.equal(16, currentChar().bags[0].size)
		end)

		it("nicht vorhandene Taschen (size 0) werden nicht gespeichert", function()
			mock.FireEvent("BAG_UPDATE")
			mock.AdvanceTime(0.5)
			assert.is_nil(currentChar().bags[3]) -- Slot 3 hat keine Tasche
		end)
	end)

	describe("Bank", function()
		before_each(function()
			-- Bankfach (-1) + eine Banktasche (6)
			mock.SetContainer(-1, 28, { [3] = { id = 172230, count = 20 } })
			mock.SetContainer(6, 34, { [1] = { id = 191529, count = 3 } })
		end)

		it("wird NICHT gescannt, solange die Bank zu ist", function()
			mock.FireEvent("PLAYERBANKSLOTS_CHANGED", 3)
			mock.AdvanceTime(1)
			assert.same({}, currentChar().bank)
		end)

		it("BANKFRAME_OPENED scannt Bankfach + Banktaschen sofort", function()
			mock.FireEvent("BANKFRAME_OPENED")

			local bank = currentChar().bank
			assert.equal(28, bank[-1].size)
			assert.same({ id = 172230, count = 20 }, bank[-1].items[3])
			assert.equal(34, bank[6].size)
		end)

		it("scannt die Reagenzienbank (-3) mit, wenn der Client sie kennt", function()
			mock.SetContainer(-3, 98, { [1] = { id = 190452, count = 200 } })
			mock.FireEvent("BANKFRAME_OPENED")
			local bank = currentChar().bank
			assert.equal(98, bank[-3].size)
			assert.same({ id = 190452, count = 200 }, bank[-3].items[1])
		end)

		it("Aenderungen waehrend offener Bank werden entprellt uebernommen", function()
			mock.FireEvent("BANKFRAME_OPENED")
			mock.SetContainer(-1, 28, { [3] = { id = 172230, count = 99 } })

			mock.FireEvent("PLAYERBANKSLOTS_CHANGED", 3)
			mock.AdvanceTime(0.5)

			assert.equal(99, currentChar().bank[-1].items[3].count)
		end)

		it("nach BANKFRAME_CLOSED wird nicht mehr gescannt", function()
			mock.FireEvent("BANKFRAME_OPENED")
			mock.FireEvent("BANKFRAME_CLOSED")
			mock.SetContainer(-1, 28, { [3] = { id = 172230, count = 1 } })

			mock.FireEvent("PLAYERBANKSLOTS_CHANGED", 3)
			mock.AdvanceTime(1)

			assert.equal(20, currentChar().bank[-1].items[3].count) -- alter Stand
		end)
	end)

	describe("Altlasten-Bereinigung (1.6.4, Screenshot-Bug)", function()
		local function seedStaleChar(charKey)
			local char = Exo.Store:GetOrCreateCharacter(charKey)
			local _, realm, name = Exo.Schema.ParseCharKey(charKey)
			char.meta.name = name
			char.meta.realm = realm
			-- Altbestand von VOR 1.6.2: Warband-Tab 12 klebt in der CHAR-Bank
			char.bank = {
				[6] = { size = 98, free = 97, items = { [1] = { id = 555, count = 1 } } },
				[12] = { size = 98, free = 0, items = { [1] = { id = 111, count = 616 } } },
			}
		end

		before_each(function()
			-- 11.2-Layout: Kriegsmeute = 12-16
			mock.SetBagIndex({
				CharacterBankTab_1 = 6, CharacterBankTab_2 = 7,
				AccountBankTab_1 = 12, AccountBankTab_2 = 13,
				AccountBankTab_3 = 14, AccountBankTab_4 = 15,
				AccountBankTab_5 = 16,
			})
			seedStaleChar("Default.Testrealm.Adelmo")
			seedStaleChar("Default.Testrealm.Malzira")
			seedStaleChar("Default.Testrealm.Myrnia")
			seedStaleChar("Default.Testrealm.Rabisu")
		end)

		it("reproduziert den Screenshot: 4 x 616 = 2464 statt 616", function()
			local counts = Exo.API.GetItemCounts(111)
			assert.equal(2464, counts.total) -- der Bug aus dem Screenshot
		end)

		it("CleanupStaleBankTabs entfernt die Duplikate, echte Bank bleibt", function()
			Exo.Collectors.Containers.CleanupStaleBankTabs()
			local counts = Exo.API.GetItemCounts(111)
			assert.equal(0, counts.total) -- Duplikate weg (Warband liefert beim
			                              -- naechsten Bankbesuch die echten 616)
			-- Charakterbank-Tab 6 blieb unangetastet
			local bank = Exo.Store:GetCharacter("Default.Testrealm.Adelmo").bank
			assert.equal(1, bank[6].items[1].count)
			assert.is_nil(bank[12])
		end)

		it("laeuft automatisch beim Core-Start (EXO_CORE_READY)", function()
			Exo.EventBus:Fire("EXO_CORE_READY")
			assert.is_nil(Exo.Store:GetCharacter("Default.Testrealm.Myrnia").bank[12])
		end)

		it("altes Layout (ohne Enum): nur 13-17 gelten als Warband", function()
			mock.SetBagIndex(nil)
			local char = Exo.Store:GetOrCreateCharacter("Default.Testrealm.Alt")
			char.bank = {
				[12] = { size = 34, free = 30, items = { [1] = { id = 9, count = 2 } } },
				[13] = { size = 98, free = 0, items = { [1] = { id = 8, count = 5 } } },
			}
			Exo.Collectors.Containers.CleanupStaleBankTabs()
			assert.is_not_nil(char.bank[12]) -- legitime alte Banktasche
			assert.is_nil(char.bank[13])     -- Fallback-Warband-ID -> raus
		end)
	end)

	describe("Container-Struktur-Audit (1.6.3)", function()
		it("Taschen-IDs kommen aus Enum.BagIndex (Fallback 0-5)", function()
			assert.same({ 0, 1, 2, 3, 4, 5 }, Exo.WowAPI.GetCharacterBagIDs())
			mock.SetBagIndex({ Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3,
				Bag_4 = 4, ReagentBag = 5 })
			assert.same({ 0, 1, 2, 3, 4, 5 }, Exo.WowAPI.GetCharacterBagIDs())
		end)

		it("GetBagItemID nur fuer echte Char-Taschen (1-5)", function()
			mock.SetEquippedBag(1, 194017)
			assert.equal(194017, Exo.WowAPI.GetBagItemID(1))
			assert.is_nil(Exo.WowAPI.GetBagItemID(0))  -- Rucksack
			assert.is_nil(Exo.WowAPI.GetBagItemID(6))  -- Bank-Tab: kein Inv-Slot
			assert.is_nil(Exo.WowAPI.GetBagItemID(12)) -- Kriegsmeuten-Tab
		end)

		it("Gildenbank: Slot-Zahl vom Client, Tab-Namen werden gespeichert", function()
			mock.SetGuildBank("Die Nachtwache", {
				[1] = { [1] = { id = 777, count = 40 } },
				[2] = { [5] = { id = 555, count = 3 } },
			}, { [1] = "Mats", [2] = "Raid-Zeug" })
			mock.FireEvent("GUILDBANKFRAME_OPENED")
			local guild = Exo.Store:GetGuilds()["Die Nachtwache"]
			assert.equal(98, guild.bank[1].size) -- MAX_GUILDBANK_SLOTS_PER_TAB
			assert.equal("Mats", guild.bank[1].name)
			assert.equal("Raid-Zeug", guild.bank[2].name)
			assert.equal(97, guild.bank[2].free)
		end)
	end)

	describe("Bank-Umbau 11.2+ (Enum.BagIndex, 1.6.2)", function()
		before_each(function()
			-- Neues Layout: Charakterbank-Tabs 6-11, Kriegsmeute 12-16
			mock.SetBagIndex({
				CharacterBankTab_1 = 6, CharacterBankTab_2 = 7,
				CharacterBankTab_3 = 8, CharacterBankTab_4 = 9,
				CharacterBankTab_5 = 10, CharacterBankTab_6 = 11,
				AccountBankTab_1 = 12, AccountBankTab_2 = 13,
				AccountBankTab_3 = 14, AccountBankTab_4 = 15,
				AccountBankTab_5 = 16,
			})
		end)

		it("Wrapper liefern die Enum-IDs (sonst Fallback)", function()
			assert.same({ 12, 13, 14, 15, 16 }, Exo.WowAPI.GetWarbandBagIDs())
			assert.same({ 6, 7, 8, 9, 10, 11 }, Exo.WowAPI.GetBankBagIDs())
			mock.SetBagIndex(nil)
			assert.same({ 13, 14, 15, 16, 17 }, Exo.WowAPI.GetWarbandBagIDs())
		end)

		it("Kriegsmeuten-Tab 1 (ID 12) wird jetzt mitgescannt (Bugreport)", function()
			-- Petbattle-Items liegen im ERSTEN Tab -> ID 12
			mock.SetContainer(12, 98, {
				[1] = { id = 44822, count = 10 }, -- Blauer Zwergen-Welpe o. ae.
				[2] = { id = 71153, count = 5 },
			})
			mock.SetContainer(13, 98, { [1] = { id = 210796, count = 500 } })
			mock.FireEvent("BANKFRAME_OPENED")

			local warband = Exo.Store:GetAccount().warbandBank
			assert.equal(10, warband[12].items[1].count) -- vorher: fehlte komplett!
			assert.equal(5, warband[12].items[2].count)
			assert.equal(500, warband[13].items[1].count)
		end)

		it("BAG_UPDATE fuer ID 12 routet zum Warband-Rescan", function()
			mock.FireEvent("BANKFRAME_OPENED")
			mock.SetContainer(12, 98, { [1] = { id = 44822, count = 7 } })
			mock.FireEvent("BAG_UPDATE", 12)
			mock.AdvanceTime(0.5)
			assert.equal(7, Exo.Store:GetAccount().warbandBank[12].items[1].count)
		end)

		it("Charakterbank nutzt die Tab-IDs 6-11", function()
			mock.SetContainer(6, 98, { [1] = { id = 191529, count = 3 } })
			mock.SetContainer(11, 98, { [1] = { id = 555, count = 1 } })
			mock.FireEvent("BANKFRAME_OPENED")
			assert.equal(3, currentChar().bank[6].items[1].count)
			assert.equal(1, currentChar().bank[11].items[1].count)
		end)
	end)

	describe("Kriegsmeutenbank", function()
		it("Nachzuegler: spaet geladene Tab-Inhalte werden nachgefasst (1.6.1)", function()
			-- Bank oeffnet, Client hat die Warband-Tabs noch NICHT geliefert
			mock.FireEvent("BANKFRAME_OPENED")
			assert.same({}, Exo.Store:GetAccount().warbandBank)

			-- Inhalte treffen verspaetet ein (ohne weiteres Event)
			mock.SetContainer(13, 98, { [1] = { id = 210796, count = 500 } })
			mock.AdvanceTime(1)
			local warband = Exo.Store:GetAccount().warbandBank
			assert.equal(500, warband[13].items[1].count)
		end)

		it("BAG_UPDATE eines Warband-Tabs rescanct bei offener Bank (1.6.1)", function()
			mock.SetContainer(13, 98, { [1] = { id = 210796, count = 500 } })
			mock.FireEvent("BANKFRAME_OPENED")
			mock.AdvanceTime(1)

			-- Einzahlung waehrend die Bank offen ist
			mock.SetContainer(13, 98, {
				[1] = { id = 210796, count = 500 },
				[2] = { id = 999, count = 7 },
			})
			mock.FireEvent("BAG_UPDATE", 13)
			mock.AdvanceTime(0.5)
			assert.equal(7, Exo.Store:GetAccount().warbandBank[13].items[2].count)

			-- nach dem Schliessen: kein Scan mehr
			mock.FireEvent("BANKFRAME_CLOSED")
			mock.SetContainer(13, 98, {})
			mock.FireEvent("BAG_UPDATE", 13)
			mock.AdvanceTime(1)
			assert.equal(7, Exo.Store:GetAccount().warbandBank[13].items[2].count)
		end)

		it("BAG_UPDATE eines Bank-Tabs rescanct die Bank (1.6.1)", function()
			mock.SetContainer(6, 34, { [1] = { id = 191529, count = 3 } })
			mock.FireEvent("BANKFRAME_OPENED")
			mock.SetContainer(6, 34, { [1] = { id = 191529, count = 9 } })
			mock.FireEvent("BAG_UPDATE", 6)
			mock.AdvanceTime(0.5)
			assert.equal(9, currentChar().bank[6].items[1].count)
		end)

		it("wird beim Bankbesuch accountweit gespeichert", function()
			mock.SetContainer(13, 98, { [1] = { id = 210796, count = 500 } })

			local accountEvent
			Exo.EventBus:Register("EXO_ACCOUNT_UPDATED", function(_, section)
				accountEvent = section
			end)

			mock.FireEvent("BANKFRAME_OPENED")

			local warband = Exo.Store:GetAccount().warbandBank
			assert.equal(98, warband[13].size)
			assert.same({ id = 210796, count = 500 }, warband[13].items[1])
			assert.equal("warbandBank", accountEvent)
		end)
	end)

	describe("GetBagSpace (0.13.0)", function()
		it("zaehlt freie/gesamte Plaetze; free-Feld optional", function()
			local key = Exo.Store:GetCurrentKey()
			Exo.Store:WriteCharacterData(key, "bags", {
				[0] = { size = 16, free = 10, items = { [1] = { id = 1, count = 1 } } },
				[1] = { size = 20, free = 20, items = {} },
			})
			-- Bank-Scan ohne free-Feld (alter Datenstand) -> wird berechnet
			Exo.Store:WriteCharacterData(key, "bank", {
				[-1] = { size = 28, items = { [1] = { id = 2, count = 5 }, [7] = { id = 3, count = 1 } } },
			})
			local space = Exo.API.GetBagSpace(key)
			assert.equal(30, space.bagsFree)
			assert.equal(36, space.bagsSize)
			assert.equal(26, space.bankFree)
			assert.equal(28, space.bankSize)
		end)

		it("nil fuer unbekannte Charaktere", function()
			assert.is_nil(Exo.API.GetBagSpace("Default.Nix.Niemand"))
		end)
	end)
end)
