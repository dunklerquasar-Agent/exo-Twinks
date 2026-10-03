-- spec/release_1_12_spec.lua
-- Item-Kern komplett (1.12.0): Post-Anhaenge + angelegte Items im Index.
local mock = require("spec.wow_mock")

describe("Release 1.12.0: Item-Kern (Post + Angelegt)", function()
	local Exo

	local function seed()
		local Store = Exo.Store
		local anna = Store:GetOrCreateCharacter("Default.Testrealm.Anna")
		anna.meta.name = "Anna"

		Store:WriteCharacterData("Default.Testrealm.Anna", "bags", {
			[0] = { size = 16, free = 14, items = { [1] = { id = 777, count = 10 } } },
		})
		-- 4 Stueck haengen in der Post
		Store:WriteCharacterData("Default.Testrealm.Anna", "mails", {
			scannedAt = Exo.WowAPI.Now(),
			list = {
				{ sender = "Borg", subject = "Erze", daysLeft = 10,
					items = { { id = 777, count = 3 }, { id = 777, count = 1 } } },
			},
		})
		-- 1 Stueck ist angelegt
		Store:WriteCharacterData("Default.Testrealm.Anna", "equipment", {
			avgItemLevel = 600, avgItemLevelEquipped = 600,
			slots = { [13] = { id = 777, ilvl = 600 } },
		})
	end

	before_each(function()
		mock.Reset()
		Exo = mock.LoadExoCore()
		mock.SimulateLogin()
		seed()
	end)

	it("GetItemCounts zaehlt Post-Anhaenge und angelegte Items", function()
		local counts = Exo.API.GetItemCounts(777)
		assert.equal(15, counts.total) -- 10 Taschen + 4 Post + 1 angelegt
		local anna = counts.chars["Default.Testrealm.Anna"]
		assert.equal(4, anna.mail)
		assert.equal(1, anna.equipped)
	end)

	it("Tooltip zeigt Post und Angelegt mit Einzelmengen", function()
		local tooltip = mock.HoverItem(777)
		assert.truthy(tooltip.lines[1]:find("15 insgesamt", 1, true))
		assert.truthy(tooltip.lines[2]:find(
			"Anna: 15 (Taschen 10, Post 4, Angelegt 1)", 1, true))
	end)

	it("Cache wird bei Mail- und Equipment-Aenderungen invalidiert", function()
		assert.equal(15, Exo.API.GetItemCounts(777).total)

		Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mails", {
			scannedAt = Exo.WowAPI.Now(), list = {},
		})
		assert.equal(11, Exo.API.GetItemCounts(777).total) -- Post geleert

		Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "equipment", {
			avgItemLevel = 600, avgItemLevelEquipped = 600, slots = {},
		})
		assert.equal(10, Exo.API.GetItemCounts(777).total) -- abgelegt
	end)

	it("versteckte Chars werden auch aus Post/Angelegt herausgerechnet", function()
		Exo.API.SetCharacterHidden("Default.Testrealm.Anna", true)
		local counts = Exo.API.GetItemCounts(777)
		assert.equal(0, counts.total)
		assert.is_nil(counts.chars["Default.Testrealm.Anna"])
	end)

	describe("Suche", function()
		before_each(function() mock.LoadExoUI() end)

		it("Ort-Filter Post und Angelegt treffen", function()
			local Tab = Exo.UI.SearchTab
			local result = Exo.API.GetItemCounts(777)

			assert.is_true(Tab.MatchesFilters(result, { location = "mail" }))
			assert.is_true(Tab.MatchesFilters(result, { location = "equipped" }))
			-- Item NUR in Taschen -> Post-Filter greift nicht
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "mails", {
				scannedAt = Exo.WowAPI.Now(), list = {},
			})
			Exo.Store:WriteCharacterData("Default.Testrealm.Anna", "equipment", {
				avgItemLevel = 600, avgItemLevelEquipped = 600, slots = {},
			})
			local fresh = Exo.API.GetItemCounts(777)
			assert.is_false(Tab.MatchesFilters(fresh, { location = "mail" }))
			assert.is_false(Tab.MatchesFilters(fresh, { location = "equipped" }))
		end)

		it("BuildBreakdown nennt Post und Angelegt", function()
			local Tab = Exo.UI.SearchTab
			local text = Tab.BuildBreakdown(Exo.API.GetItemCounts(777))
			assert.truthy(text:find("Post 4", 1, true))
			assert.truthy(text:find("Angelegt 1", 1, true))
			assert.truthy(text:find("Anna", 1, true) and text:find("15", 1, true))
		end)
	end)
end)
