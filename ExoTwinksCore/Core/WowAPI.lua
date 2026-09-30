-- Core/WowAPI.lua
-- Duenner Wrapper um alle verwendeten WoW-APIs.
-- Zweck: (1) ein zentraler Ort bei API-Bruechen durch Patches,
--        (2) vollstaendige Mockbarkeit in Unit-Tests.
-- Regel: Collectors/UI rufen NIEMALS WoW-Globals direkt auf, immer Exo.WowAPI.*

local addonName, Exo = ...

local W = {}
Exo.WowAPI = W

-- Zeit & Frames -------------------------------------------------------------

function W.GetTime()
	return GetTime()
end

function W.CreateFrame(frameType, name, parent, template)
	return CreateFrame(frameType, name, parent, template)
end

-- Addon-Metadaten -----------------------------------------------------------

function W.GetMetadata(field)
	return C_AddOns.GetAddOnMetadata(addonName, field)
end

function W.LoadAddOn(name)
	return C_AddOns.LoadAddOn(name)
end

function W.IsAddOnLoaded(name)
	return C_AddOns.IsAddOnLoaded(name)
end

-- Spieler-Identitaet ---------------------------------------------------------

function W.GetPlayerName()
	return UnitName("player")
end

function W.GetRealmName()
	return GetRealmName()
end

function W.GetPlayerFaction()
	return UnitFactionGroup("player")
end

function W.GetPlayerLevel()
	return UnitLevel("player")
end

function W.GetPlayerClassID()
	return (select(3, UnitClass("player")))
end

function W.GetPlayerRaceID()
	return (select(3, UnitRace("player")))
end

function W.GetMoney()
	return GetMoney()
end

-- Unix-Zeit (WoW-Global 'time'), getrennt von GetTime() (Sitzungs-Uptime)
function W.Now()
	return time()
end

-- Lesender Zugriff auf fremde Globals (nur fuer LegacyImport!)
function W.GetGlobal(name)
	return _G[name]
end

-- Schreibender Zugriff auf fremde Globals (NUR fuer Services/Compat --
-- Umbenennung der Slash-Tokens des alten Altoholic!)
function W.SetGlobal(name, value)
	_G[name] = value
end

-- XP & Spielzeit --------------------------------------------------------------

function W.GetXP()
	return UnitXP("player")
end

function W.GetXPMax()
	return UnitXPMax("player")
end

function W.GetRestXP()
	return GetXPExhaustion() or 0
end

function W.RequestTimePlayed()
	RequestTimePlayed()
end

function W.GetZoneText()
	return GetRealZoneText()
end

-- Container (Taschen/Bank/Kriegsmeute) ------------------------------------------
-- Bag-ID-Bereiche zentral definiert: bei Patch-Aenderungen NUR hier anpassen.

W.BAG_IDS = { first = 0, last = 5 }                  -- Rucksack, 4 Taschen, Reagenzientasche
W.BANK_IDS = { container = -1, reagent = -3, first = 6, last = 12 } -- Bankfach + Reagenzienbank + Banktaschen
W.WARBAND_IDS = { first = 13, last = 17 }             -- Kriegsmeutenbank-Tabs

function W.GetContainerNumSlots(bagID)
	return C_Container.GetContainerNumSlots(bagID) or 0
end

-- Liefert (itemID, count) oder nil fuer leere Slots
function W.GetContainerItem(bagID, slot)
	local info = C_Container.GetContainerItemInfo(bagID, slot)
	if info and info.itemID then
		return info.itemID, info.stackCount or 1
	end
end

-- Waehrungen ---------------------------------------------------------------------

function W.GetCurrencyCount()
	return C_CurrencyInfo.GetCurrencyListSize() or 0
end

-- Liefert (currencyID, name, qty, max) oder nil fuer Header/unbekannte Eintraege
function W.GetCurrencyEntry(index)
	local info = C_CurrencyInfo.GetCurrencyListInfo(index)
	if not info or info.isHeader then return end

	local link = C_CurrencyInfo.GetCurrencyListLink(index)
	local currencyID = link and C_CurrencyInfo.GetCurrencyIDFromLink(link)
	if not currencyID then return end

	return currencyID, info.name or "", info.quantity or 0, info.maxQuantity or 0
end

-- Ausruestung ---------------------------------------------------------------------

W.EQUIPMENT_SLOTS = { first = 1, last = 19 } -- INVSLOT_HEAD .. INVSLOT_TABARD

-- Liefert (itemID, ilvl) oder nil fuer leere Slots
function W.GetInventoryItem(slot)
	local itemID = GetInventoryItemID("player", slot)
	if not itemID then return end

	local link = GetInventoryItemLink("player", slot)
	local ilvl = link and C_Item.GetDetailedItemLevelInfo(link) or 0
	return itemID, ilvl
end

function W.GetAverageItemLevel()
	local overall, equipped = GetAverageItemLevel()
	return overall or 0, equipped or 0
end

-- Item-Infos & Tooltips ---------------------------------------------------------

-- Name eines Items (kann nil sein, wenn der Client das Item noch nicht kennt)
function W.GetItemName(itemID)
	return C_Item.GetItemInfo(itemID)
end

-- Registriert einen Post-Handler fuer Item-Tooltips: fn(tooltip, data), data.id = itemID
function W.AddItemTooltipPostCall(fn)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)
end

-- Instanz-Locks (Schlachtzugs-IDs) --------------------------------------------

function W.RequestRaidInfo()
	RequestRaidInfo()
end

function W.GetNumSavedInstances()
	return GetNumSavedInstances()
end

function W.GetSavedInstanceInfo(index)
	return GetSavedInstanceInfo(index)
end

-- Slash-Kommandos -----------------------------------------------------------
-- (Zugriff auf SlashCmdList gekapselt, damit Tests ihn abfangen koennen)

function W.RegisterSlashCommand(key, commands, handler)
	for i, cmd in ipairs(commands) do
		_G["SLASH_" .. key .. i] = cmd
	end
	SlashCmdList[key] = handler
end

-- Mythic+ / Grosse Schatzkammer ---------------------------------------------------

-- Season-Gesamtwertung des Charakters (0 wenn keine)
function W.GetMythicPlusRating()
	if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
		return C_ChallengeMode.GetOverallDungeonScore() or 0
	end
	return 0
end

-- Eigener Schluesselstein: mapID, level (nil wenn keiner in den Taschen)
function W.GetOwnedKeystone()
	if not (C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID) then return nil end
	local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	if not mapID then return nil end
	return mapID, C_MythicPlus.GetOwnedKeystoneLevel() or 0
end

-- Name einer Challenge-Map
function W.GetChallengeMapName(mapID)
	if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
		return (C_ChallengeMode.GetMapUIInfo(mapID))
	end
end

-- Alle Challenge-Maps der aktuellen Season
function W.GetMythicPlusMaps()
	if C_ChallengeMode and C_ChallengeMode.GetMapTable then
		return C_ChallengeMode.GetMapTable() or {}
	end
	return {}
end

-- Season-Bestleistung fuer eine Map: level, score, inTime (nil wenn nie gelaufen)
function W.GetSeasonBestForMap(mapID)
	if not (C_MythicPlus and C_MythicPlus.GetSeasonBestForMap) then return nil end
	local inTime, overTime = C_MythicPlus.GetSeasonBestForMap(mapID)
	local best = inTime or overTime
	if not best then return nil end
	return best.level or 0, best.dungeonScore or 0, inTime ~= nil
end

-- Grosse Schatzkammer: Array { type, index, progress, threshold, level }
function W.GetWeeklyRewardActivities()
	if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
		return C_WeeklyRewards.GetActivities() or {}
	end
	return {}
end

-- Fordert die M+-Daten vom Server an (asynchron, Events folgen)
function W.RequestMythicPlusData()
	if C_MythicPlus and C_MythicPlus.RequestMapInfo then
		C_MythicPlus.RequestMapInfo()
	end
end

-- Belohnungen der Vorwoche warten in der Grossen Schatzkammer auf Abholung
function W.HasAvailableVaultRewards()
	if C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards then
		return C_WeeklyRewards.HasAvailableRewards() or false
	end
	return false
end

-- M+-Runs der aktuellen Woche (inkl. nicht in der Zeit beendeter)
-- Eintraege: { mapChallengeModeID, level, completed }
function W.GetMythicPlusRunHistory()
	if C_MythicPlus and C_MythicPlus.GetRunHistory then
		return C_MythicPlus.GetRunHistory(false, true) or {}
	end
	return {}
end

-- Maxlevel der aktuellen Erweiterung (fuer "Level 90" statt "90.0" & Erholt-Anzeige)
function W.GetMaxPlayerLevel()
	if GetMaxLevelForPlayerExpansion then
		return GetMaxLevelForPlayerExpansion() or 0
	end
	return 0
end

-- Weekly-/Daily-Quest erledigt? (accountweiter Flag-Check des aktuellen Chars)
function W.IsQuestCompleted(questID)
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		return C_QuestLog.IsQuestFlaggedCompleted(questID) or false
	end
	return false
end

-- Item-Qualitaet (0 grau .. 7 erbstueck); nil wenn unbekannt/nicht gecacht
function W.GetItemQuality(itemID)
	if C_Item.GetItemQualityByID then
		return C_Item.GetItemQualityByID(itemID)
	end
	local _, _, quality = C_Item.GetItemInfo(itemID)
	return quality
end

-- Ist das konkrete EXEMPLAR in diesem Taschenplatz "kriegsmeutengebunden
-- bis zum Anlegen"? Diese Bindung haengt am Exemplar, nicht an der Item-ID:
-- viele Drops sind vom Typ her BoE und erst das gedroppte Stueck ist
-- warbound. Deshalb wird sie beim Scannen erfasst und mitgespeichert.
function W.IsSlotWarbound(bagID, slot)
	local CI = _G.C_Item
	if CI and CI.IsBoundToAccountUntilEquip and _G.ItemLocation then
		local ok, bound = pcall(CI.IsBoundToAccountUntilEquip,
			_G.ItemLocation:CreateFromBagAndSlot(bagID, slot))
		if ok and bound then return true end
	end
	return false
end

-- Bindungstyp eines Items (14. Rueckgabewert von GetItemInfo, Enum.ItemBind).
-- nil, solange der Client das Item noch nicht geladen hat.
function W.GetItemBindType(itemID)
	return (select(14, C_Item.GetItemInfo(itemID)))
end

-- DAUERHAFT kriegsmeutengebunden (bleibt auch nach dem Anlegen
-- verschiebbar): ToWoWAccount=7 und ToBnetAccount=8. Typ 9 ("bis zum
-- Anlegen") gehoert bewusst NICHT hierher -- ein bereits angelegtes
-- Exemplar ist seelengebunden und nicht mehr verschiebbar; solche Items
-- zaehlen nur ueber das beim Scan erfasste Exemplar-Flag (wb).
function W.IsPermanentWarbound(itemID)
	local bind = W.GetItemBindType(itemID)
	if not bind then return false end
	local enum = _G.Enum and _G.Enum.ItemBind
	if bind == ((enum and enum.ToWoWAccount) or 7) then return true end
	if bind == ((enum and enum.ToBnetAccount) or 8) then return true end
	return false
end

-- Kriegsmeutengebunden? Enum.ItemBind: ToWoWAccount=7, ToBnetAccount=8,
-- ToBnetAccountUntilEquipped=9 ("Kriegsmeutengebunden bis zum Anlegen").
-- Enum-first mit numerischem Fallback fuer aeltere Clients/Tests.
function W.IsWarbound(itemID)
	local bind = W.GetItemBindType(itemID)
	if not bind then return false end
	local enum = _G.Enum and _G.Enum.ItemBind
	if bind == ((enum and enum.ToWoWAccount) or 7) then return true end
	if bind == ((enum and enum.ToBnetAccount) or 8) then return true end
	if bind == ((enum and enum.ToBnetAccountUntilEquipped) or 9) then return true end
	return false
end

-- Itemklasse: classID/subclassID (Enum.ItemClass) + lokalisierte Namen
-- ("Ruestung", "Leder"). GetItemInfoInstant ist sofort verfuegbar.
function W.GetItemClass(itemID)
	if C_Item.GetItemInfoInstant then
		local _, itemType, itemSubType, _, _, classID, subclassID =
			C_Item.GetItemInfoInstant(itemID)
		return classID, itemType, subclassID, itemSubType
	end
	return nil, nil, nil, nil
end

-- Erweiterung, aus der ein Item stammt (expansionID, 15. Rueckgabewert)
function W.GetItemExpansion(itemID)
	return (select(15, C_Item.GetItemInfo(itemID)))
end

-- Aktuelle Erweiterungsstufe des Accounts (Midnight = 11)
function W.GetCurrentExpansion()
	if GetExpansionLevel then
		return GetExpansionLevel() or 0
	end
	return 0
end

-- Item-Icon (FileID), sofort verfuegbar
function W.GetItemIcon(itemID)
	if C_Item.GetItemIconByID then
		return C_Item.GetItemIconByID(itemID)
	end
	local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
	return icon
end

-- Berufe (0.15.0) ------------------------------------------------------------------

-- Alle erlernten Berufe des eingeloggten Charakters (inkl. Kochen/Angeln).
-- -> { { name, skillLineID, rank, maxRank }, ... }
function W.GetProfessionList()
	if not GetProfessions then return {} end
	local list = {}
	for i = 1, 5 do
		local index = select(i, GetProfessions())
		if index then
			local name, _, rank, maxRank, _, _, skillLineID = GetProfessionInfo(index)
			if name then
				list[#list + 1] = {
					name = name,
					skillLineID = skillLineID or 0,
					rank = rank or 0,
					maxRank = maxRank or 0,
				}
			end
		end
	end
	return list
end

-- Offenes Berufsfenster: SkillLine-ID + erlernte Rezepte.
-- -> skillLineID, { { id, name }, ... }  oder nil (kein Fenster offen)
function W.GetOpenTradeSkill()
	if not C_TradeSkillUI then return nil end

	local skillLineID
	if C_TradeSkillUI.GetChildProfessionInfo then
		local info = C_TradeSkillUI.GetChildProfessionInfo()
		skillLineID = info and (info.parentProfessionID or info.professionID)
	end
	if not skillLineID or skillLineID == 0 then return nil end

	local recipes = {}
	for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		if info and info.learned and info.name then
			recipes[#recipes + 1] = {
				id = recipeID,
				name = info.name,
				reagents = W.GetRecipeReagents(recipeID), -- nil, wenn API fehlt
			}
		end
	end
	return skillLineID, recipes
end

-- Pflicht-Reagenzien eines Rezepts (1.4.0).
-- -> { { itemID, qty }, ... } | nil (Schematic-API nicht verfuegbar)
function W.GetRecipeReagents(recipeID)
	if not C_TradeSkillUI or not C_TradeSkillUI.GetRecipeSchematic then return nil end
	local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
	if not schematic or not schematic.reagentSlotSchematics then return nil end

	local reagents = {}
	for _, slot in ipairs(schematic.reagentSlotSchematics) do
		local qty = slot.quantityRequired or 0
		local first = slot.reagents and slot.reagents[1]
		if qty > 0 and slot.required ~= false and first and first.itemID then
			reagents[#reagents + 1] = { itemID = first.itemID, qty = qty }
		end
	end
	return reagents
end

-- Briefkasten (0.16.0) -------------------------------------------------------------

-- Alle Mails im geoeffneten Briefkasten.
-- -> { { sender, subject, money, daysLeft, items = { { id, count } } }, ... }
function W.GetInboxMails()
	if not GetInboxNumItems then return {} end
	local mails = {}
	for i = 1, (GetInboxNumItems() or 0) do
		local _, _, sender, subject, money, _, daysLeft, hasItem = GetInboxHeaderInfo(i)
		local items = {}
		if hasItem then
			for attach = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
				local name, itemID, _, count = GetInboxItem(i, attach)
				if itemID then
					items[#items + 1] = { id = itemID, count = count or 1, name = name }
				end
			end
		end
		mails[#mails + 1] = {
			sender = sender or "?",
			subject = subject or "",
			money = money or 0,
			daysLeft = daysLeft or 0,
			items = items,
		}
	end
	return mails
end

-- Gildenbank (0.16.0) --------------------------------------------------------------

function W.GetGuildName()
	if not GetGuildInfo then return nil end
	return (GetGuildInfo("player"))
end

-- Slots pro Gildenbank-Tab: Client-Konstante, Fallback 98 (1.6.3)
local function guildBankSlots()
	return MAX_GUILDBANK_SLOTS_PER_TAB or 98
end

-- Kompletter Gildenbank-Scan im BagSet-Format:
-- { [tab] = { size, free, items, name } } -- name = Tab-Beschriftung
function W.GetGuildBankContents()
	if not GetNumGuildBankTabs then return nil end
	local tabs = GetNumGuildBankTabs() or 0
	if tabs == 0 then return nil end

	local slots = guildBankSlots()
	local bank = {}
	for tab = 1, tabs do
		local bag = { size = slots, free = 0, items = {} }
		if GetGuildBankTabInfo then
			bag.name = (GetGuildBankTabInfo(tab)) -- 1. Rueckgabe = Name
		end
		for slot = 1, slots do
			local link = GetGuildBankItemLink(tab, slot)
			local itemID = link and tonumber(link:match("item:(%d+)"))
			if itemID then
				local _, count = GetGuildBankItemInfo(tab, slot)
				bag.items[slot] = { id = itemID, count = count or 1 }
			else
				bag.free = bag.free + 1
			end
		end
		bank[tab] = bag
	end
	return bank
end

-- Itemlinks (0.16.0) ---------------------------------------------------------------

function W.IsShiftDown()
	return IsShiftKeyDown and IsShiftKeyDown() or false
end

-- Itemlink in die offene Chat-Eingabe einfuegen (Shift-Klick-Verhalten)
function W.InsertItemLink(itemID)
	local link = select(2, C_Item.GetItemInfo(itemID))
	if not link then
		-- Fallback (Item noch nicht im Client-Cache): einfacher Link aus Name
		local name = W.GetItemName(itemID)
		if name then
			link = string.format("|Hitem:%d::|h[%s]|h", itemID, name)
		end
	end
	if link and ChatEdit_InsertLink then
		return ChatEdit_InsertLink(link)
	end
end

-- Ruf (0.17.0) ---------------------------------------------------------------------

-- Alle Fraktionen mit Ruf-Stand (ohne reine Kopfzeilen).
-- -> { { factionID, name, standingID (1-8), value, max }, ... }
function W.GetReputationList()
	if not C_Reputation or not C_Reputation.GetNumFactions then return {} end
	local list = {}
	for i = 1, (C_Reputation.GetNumFactions() or 0) do
		local data = C_Reputation.GetFactionDataByIndex(i)
		if data and data.factionID and data.name
			and (not data.isHeader or data.isHeaderWithRep) then
			local floor = data.currentReactionThreshold or 0
			local ceiling = data.nextReactionThreshold or 0
			list[#list + 1] = {
				factionID = data.factionID,
				name = data.name,
				standingID = data.reaction or 4,
				value = math.max(0, (data.currentStanding or 0) - floor),
				max = math.max(0, ceiling - floor),
			}
		end
	end
	return list
end

-- Questlog (0.17.0) ----------------------------------------------------------------

-- Aktive Quests des eingeloggten Charakters. -> { [questID] = title }
function W.GetQuestLog()
	if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then return {} end
	local quests = {}
	for i = 1, (C_QuestLog.GetNumQuestLogEntries() or 0) do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and info.questID and info.title then
			quests[info.questID] = info.title
		end
	end
	return quests
end

-- Mythic+-Komfort (1.0.0) ----------------------------------------------------------

-- Namen der aktuellen Wochen-Affixe. -> { "Tyrannisch", ... }
function W.GetCurrentAffixes()
	if not C_MythicPlus or not C_MythicPlus.GetCurrentAffixes then return {} end
	local names = {}
	for _, affix in ipairs(C_MythicPlus.GetCurrentAffixes() or {}) do
		local name
		if C_ChallengeMode and C_ChallengeMode.GetAffixInfo then
			name = (C_ChallengeMode.GetAffixInfo(affix.id))
		end
		names[#names + 1] = name or ("Affix " .. tostring(affix.id))
	end
	return names
end

-- Nachricht in den Gruppen-/Schlachtzugschat, sonst lokal ausgeben.
-- -> "group" | "print"
function W.AnnounceChat(message)
	if IsInGroup and IsInGroup() and SendChatMessage then
		SendChatMessage(message, (IsInRaid and IsInRaid()) and "RAID" or "PARTY")
		return "group"
	end
	print(message)
	return "print"
end

function W.IsAltDown()
	return IsAltKeyDown and IsAltKeyDown() or false
end

-- Auktionshaus (1.3.0) -------------------------------------------------------------

function W.QueryOwnedAuctions()
	if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
		C_AuctionHouse.QueryOwnedAuctions({})
	end
end

-- Eigene Auktionen des eingeloggten Charakters.
-- timeLeftBand (Enum.AuctionHouseTimeLeft): 0 <30min, 1 <2h, 2 <12h, 3 <48h
-- -> { { itemID, qty, buyout, bid, timeLeftBand, sold } } | nil (API fehlt)
function W.GetOwnedAuctions()
	if not C_AuctionHouse or not C_AuctionHouse.GetOwnedAuctions then return nil end
	local list = {}
	for _, auction in ipairs(C_AuctionHouse.GetOwnedAuctions() or {}) do
		local itemID = auction.itemKey and auction.itemKey.itemID
		if itemID then
			list[#list + 1] = {
				itemID = itemID,
				qty = auction.quantity or 1,
				buyout = auction.buyoutAmount or 0,
				bid = auction.bidAmount or 0,
				timeLeftBand = auction.timeLeft or 3,
				sold = (auction.status == 1) or nil,
			}
		end
	end
	return list
end

-- Ausgeruestete Tasche eines Taschen-Slots (1.5.0). -> itemID | nil
function W.GetBagItemID(bagID)
	-- Nur ausruestbare Char-Taschen (1-5); Bank-Tabs (11.2+) haben keine
	-- Inventar-Slots -- dort waere ContainerIDToInventoryID ein Fehler.
	if not bagID or bagID < 1 or bagID > 5 then return nil end
	if C_Container and C_Container.ContainerIDToInventoryID and GetInventoryItemID then
		local inventoryID = C_Container.ContainerIDToInventoryID(bagID)
		return inventoryID and GetInventoryItemID("player", inventoryID)
	end
	return nil
end

-- Dynamische Bank-Bag-IDs (1.6.2) --------------------------------------------------
-- Seit dem Bank-Umbau (Patch 11.2) liegen die Kriegsmeuten-Tabs auf
-- AccountBankTab_1..N (beginnt bei 12!) und die Charakterbank auf
-- CharacterBankTab_1..N. Enum.BagIndex ist die Wahrheit; die alten
-- Konstanten bleiben nur als Fallback fuer aeltere Clients.

local function collectEnumIDs(prefix)
	local BagIndex = Enum and Enum.BagIndex
	if not BagIndex then return nil end
	local ids = {}
	for i = 1, 10 do
		local id = BagIndex[prefix .. i]
		if id then ids[#ids + 1] = id end
	end
	if #ids == 0 then return nil end
	table.sort(ids)
	return ids
end

-- Alle Kriegsmeuten-Tab-IDs. -> { 12, 13, ... } (Enum) | { 13..17 } (Fallback)
function W.GetWarbandBagIDs()
	local ids = collectEnumIDs("AccountBankTab_")
	if ids then return ids end
	ids = {}
	for id = W.WARBAND_IDS.first, W.WARBAND_IDS.last do ids[#ids + 1] = id end
	return ids
end

-- Alle Charakterbank-IDs. Enum-Tabs (11.2+) ODER klassisch (-1, 6-12, -3).
function W.GetBankBagIDs()
	local ids = collectEnumIDs("CharacterBankTab_")
	if ids then return ids end
	ids = { W.BANK_IDS.container }
	for id = W.BANK_IDS.first, W.BANK_IDS.last do ids[#ids + 1] = id end
	if W.BANK_IDS.reagent then ids[#ids + 1] = W.BANK_IDS.reagent end
	return ids
end

-- Alle Taschen-IDs des Charakters (1.6.3): Rucksack, Taschen 1-4,
-- Reagenzientasche -- aus Enum.BagIndex, Fallback 0-5.
function W.GetCharacterBagIDs()
	local BagIndex = Enum and Enum.BagIndex
	if BagIndex and BagIndex.Backpack ~= nil then
		local ids = { BagIndex.Backpack }
		for i = 1, 8 do
			local id = BagIndex["Bag_" .. i]
			if id then ids[#ids + 1] = id end
		end
		if BagIndex.ReagentBag then ids[#ids + 1] = BagIndex.ReagentBag end
		table.sort(ids)
		return ids
	end
	local ids = {}
	for id = W.BAG_IDS.first, W.BAG_IDS.last do ids[#ids + 1] = id end
	return ids
end
