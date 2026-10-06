-- Services/DemoMode.lua
-- Demo-Modus (1.15.0) fuer Screenshots & Praesentationen: /exo demo an|aus.
-- Beim Einschalten werden 8 ERFUNDENE Beispiel-Charaktere angelegt und alle
-- echten Charaktere ausgeblendet (vorheriger Sichtbarkeits-Zustand wird
-- gesichert). Beim Ausschalten werden die Demo-Chars geloescht und der alte
-- Zustand exakt wiederhergestellt. Echte Daten werden NIE veraendert.

local _, Exo = ...

local Demo = {}
Exo.DemoMode = Demo

Demo.REALM = "Sturmklinge" -- frei erfunden
Demo.GUILD = "Die Beispielgilde"
local PREFIX = "Default." .. Demo.REALM .. "."

-- Erfundene Beispiel-Charaktere -------------------------------------------------------
-- classID: 1 Krieger, 2 Paladin, 3 Jaeger, 5 Priester, 7 Schamane,
--          8 Magier, 9 Hexenmeister, 11 Druide

local function demoChars(now)
	local day = 86400
	return {
		{ name = "Thorgrim", classID = 1, level = 90, ilvl = 639, gold = 1264580000,
			lastSeen = now - 2 * 3600, played = 2345678,
			mplus = { rating = 3012,
				keystone = { mapID = 501, name = "Dornenspitze", level = 14 },
				dungeons = {
					[501] = { name = "Dornenspitze", level = 15, score = 165, inTime = true },
					[502] = { name = "Hallen der Daemmerung", level = 14, score = 158, inTime = true },
				},
				vault = {
					{ type = 1, index = 1, progress = 8, threshold = 1, level = 15 },
					{ type = 1, index = 2, progress = 8, threshold = 4, level = 14 },
					{ type = 1, index = 3, progress = 8, threshold = 8, level = 12 },
				} },
			locks = {
				{ name = "Burg Teufelssturz", lockID = 1, resetAt = now + 4 * day,
					difficultyID = 15, difficultyName = "Heroisch", extended = false,
					isRaid = true, maxPlayers = 30, bossesKilled = 6, bossesTotal = 8 },
			},
			profs = { [164] = { name = "Schmiedekunst", rank = 98, maxRank = 100, recipes = {} },
				[186] = { name = "Bergbau", rank = 100, maxRank = 100, recipes = {} } },
			bags = { [0] = { size = 32, free = 11, items = {
				[1] = { id = 2772, count = 20 }, [2] = { id = 10620, count = 17 },
				[3] = { id = 6948, count = 1 }, [4] = { id = 929, count = 5 } } } } },
		{ name = "Lunara", classID = 3, level = 90, ilvl = 628, gold = 487210000,
			lastSeen = now - day, played = 1822222,
			mplus = { rating = 2741,
				keystone = { mapID = 502, name = "Hallen der Daemmerung", level = 12 },
				dungeons = {
					[502] = { name = "Hallen der Daemmerung", level = 12, score = 142, inTime = true },
				},
				vault = {
					{ type = 1, index = 1, progress = 5, threshold = 1, level = 12 },
					{ type = 1, index = 2, progress = 5, threshold = 4, level = 11 },
					{ type = 1, index = 3, progress = 5, threshold = 8, level = 0 },
				} },
			bags = { [0] = { size = 32, free = 20, items = {
				[1] = { id = 2318, count = 14 }, [2] = { id = 4234, count = 9 } } } } },
		{ name = "Seraphine", classID = 5, level = 90, ilvl = 594, gold = 2150000000,
			lastSeen = now - 3 * 3600, played = 3111111,
			profs = { [197] = { name = "Schneiderei", rank = 100, maxRank = 100, recipes = {} },
				[333] = { name = "Verzauberkunst", rank = 87, maxRank = 100, recipes = {} } },
			mails = { list = {
				{ sender = "Auktionshaus", subject = "Auktion erfolgreich",
					money = 1250000, items = {}, daysLeft = 28 },
				{ sender = "Thorgrim", subject = "Stoffe fuer dich",
					items = { { id = 14047, count = 20, name = "" } }, daysLeft = 9 },
			} },
			bags = { [0] = { size = 32, free = 4, items = {
				[1] = { id = 2589, count = 20 }, [2] = { id = 4306, count = 20 },
				[3] = { id = 14047, count = 18 }, [4] = { id = 22445, count = 12 },
				[5] = { id = 21877, count = 20 } } } },
			bank = { [6] = { size = 98, free = 60, items = {
				[1] = { id = 2589, count = 200 }, [2] = { id = 4306, count = 140 },
				[3] = { id = 14047, count = 160 } } } } },
		{ name = "Baelric", classID = 2, level = 88, ilvl = 571, gold = 98320000,
			lastSeen = now - 2 * day, played = 902000 },
		{ name = "Nyxia", classID = 8, level = 90, ilvl = 644, gold = 756400000,
			lastSeen = now - 5 * 3600, played = 2650000,
			mplus = { rating = 3201,
				keystone = { mapID = 503, name = "Sonnenwende", level = 16 },
				dungeons = {
					[503] = { name = "Sonnenwende", level = 16, score = 172, inTime = true },
					[501] = { name = "Dornenspitze", level = 15, score = 164, inTime = false },
				},
				vault = {
					{ type = 1, index = 1, progress = 8, threshold = 1, level = 16 },
					{ type = 1, index = 2, progress = 8, threshold = 4, level = 15 },
					{ type = 1, index = 3, progress = 8, threshold = 8, level = 15 },
				} },
			locks = {
				{ name = "Burg Teufelssturz", lockID = 2, resetAt = now + 4 * day,
					difficultyID = 16, difficultyName = "Mythisch", extended = false,
					isRaid = true, maxPlayers = 20, bossesKilled = 3, bossesTotal = 8 },
			} },
		{ name = "Grombash", classID = 7, level = 82, ilvl = 490, gold = 12750000,
			lastSeen = now - 6 * day, played = 410000, restXP = 219000 },
		{ name = "Elowen", classID = 11, level = 90, ilvl = 602, gold = 334100000,
			lastSeen = now - 12 * 3600, played = 1980000,
			profs = { [182] = { name = "Kraeuterkunde", rank = 100, maxRank = 100, recipes = {} },
				[171] = { name = "Alchemie", rank = 92, maxRank = 100, recipes = {} } },
			bags = { [0] = { size = 32, free = 8, items = {
				[1] = { id = 765, count = 20 }, [2] = { id = 3356, count = 20 },
				[3] = { id = 13463, count = 15 }, [4] = { id = 118, count = 10 } } } } },
		{ name = "Vexxan", classID = 9, level = 75, ilvl = 420, gold = 5420000,
			lastSeen = now - 14 * day, played = 260000, restXP = 310000 },
	}
end

-- Hilfen -------------------------------------------------------------------------------

function Demo.IsActive()
	return Exo.API.GetOption("demoMode") == true
end

function Demo.GetDemoKeys()
	local keys = {}
	for _, key in ipairs(Exo.Store:GetCharacterKeys()) do
		if key:sub(1, #PREFIX) == PREFIX then keys[#keys + 1] = key end
	end
	return keys
end

local function seedOne(spec, now)
	local Store = Exo.Store
	local key = PREFIX .. spec.name
	local char = Store:GetOrCreateCharacter(key)
	local meta = char.meta
	meta.name = spec.name
	meta.realm = Demo.REALM
	meta.account = "Default"
	meta.level = spec.level
	meta.classID = spec.classID
	meta.faction = "Alliance"
	meta.guild = Demo.GUILD
	meta.lastSeen = spec.lastSeen
	meta.playedTotal = spec.played
	if spec.restXP then meta.restXP = spec.restXP end

	Store:WriteCharacterData(key, "gold", spec.gold)
	Store:WriteCharacterData(key, "equipment",
		{ avgItemLevelEquipped = spec.ilvl, slots = {} })
	if spec.bags then Store:WriteCharacterData(key, "bags", spec.bags) end
	if spec.bank then Store:WriteCharacterData(key, "bank", spec.bank) end
	if spec.mplus then Store:WriteCharacterData(key, "mythicplus", spec.mplus) end
	if spec.locks then Store:WriteCharacterData(key, "instanceLocks", spec.locks) end
	if spec.profs then Store:WriteCharacterData(key, "professions", spec.profs) end
	if spec.mails then
		spec.mails.scannedAt = now
		Store:WriteCharacterData(key, "mails", spec.mails)
	end
end

-- Ein-/Ausschalten ----------------------------------------------------------------------

-- Rueckgabe: true | nil, "already_on"
function Demo.Enable()
	if Demo.IsActive() then return nil, "already_on" end
	local API = Exo.API

	-- Sichtbarkeits-Zustand der echten Chars sichern, dann alle verstecken
	local backup = {}
	for _, key in ipairs(Exo.Store:GetCharacterKeys()) do
		backup[key] = API.IsCharacterHidden(key) and true or false
		API.SetCharacterHidden(key, true)
	end
	API.SetOption("demoHiddenBackup", backup)

	local now = Exo.WowAPI.Now()
	for _, spec in ipairs(demoChars(now)) do
		seedOne(spec, now)
	end
	API.SetOption("demoMode", true)
	Exo.EventBus:Fire("EXO_CHAR_UPDATED", { demo = true })
	return true
end

-- Rueckgabe: true | nil, "already_off"
function Demo.Disable()
	if not Demo.IsActive() then return nil, "already_off" end
	local API = Exo.API

	for _, key in ipairs(Demo.GetDemoKeys()) do
		Exo.Store:DeleteCharacter(key)
	end

	-- Alten Sichtbarkeits-Zustand exakt wiederherstellen
	local backup = API.GetOption("demoHiddenBackup")
	if type(backup) == "table" then
		for key, wasHidden in pairs(backup) do
			API.SetCharacterHidden(key, wasHidden)
		end
	end
	API.SetOption("demoHiddenBackup", nil)
	API.SetOption("demoMode", nil)
	Exo.EventBus:Fire("EXO_CHAR_UPDATED", { demo = false })
	return true
end
