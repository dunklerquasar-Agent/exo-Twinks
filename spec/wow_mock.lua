-- spec/wow_mock.lua
-- Minimaler WoW-Client-Mock fuer busted-Tests.
-- Stellt genau die Globals bereit, die ExoTwinksCore benutzt, plus Test-Helfer:
--   mock.Reset()                 -- frischer Zustand pro Test
--   mock.LoadAddon(files)        -- laedt Addon-Dateien mit geteiltem Namespace
--   mock.FireEvent(event, ...)   -- WoW-Event an alle registrierten Frames
--   mock.AdvanceTime(seconds)    -- Mock-Uhr vorstellen + OnUpdate ausloesen
--   mock.printed                 -- alle print()-Ausgaben

local mock = {}

local state

function mock.Reset()
	state = {
		now = 0,
		frames = {},
		printed = {},
		metadata = { Version = "0.1.0-test" },
		slashHandlers = {},
		loadedAddons = { ExoTwinksCore = true },
		loadAddOnResult = true,
	}
	mock.printed = state.printed

	-- Globals, die ExoTwinksCore braucht -----------------------------------------

	_G.GetTime = function() return state.now end

	-- Permissive Frame-Attrappe: unbekannte Methoden sind No-Ops (fuer UI-Code),
	-- die fuer Tests relevanten Methoden sind echt implementiert.
	local function newFontString()
		local fs = { _text = "", _shown = true }
		fs.SetText = function(self, text) self._text = tostring(text or "") end
		fs.GetText = function(self) return self._text end
		fs.Show = function(self) self._shown = true end
		fs.Hide = function(self) self._shown = false end
		fs.IsShown = function(self) return self._shown end
		return setmetatable(fs, { __index = function() return function() end end })
	end

	_G.CreateFrame = function(frameType, name)
		local frame = {
			_type = frameType,
			_name = name,
			_events = {},
			_scripts = {},
			_shown = true,
			_fontStrings = {},
		}
		frame.RegisterEvent = function(self, event) self._events[event] = true end
		frame.UnregisterEvent = function(self, event) self._events[event] = nil end
		frame.SetScript = function(self, handler, fn) self._scripts[handler] = fn end
		frame.GetScript = function(self, handler) return self._scripts[handler] end
		frame.Show = function(self) self._shown = true end
		frame.Hide = function(self) self._shown = false end
		-- Position/Skalierung nachvollziehbar speichern (1.10.0)
		frame.SetPoint = function(self, point, a, b, c, d)
			if type(a) == "number" then
				self._point = { point = point, relPoint = point, x = a, y = b }
			else
				self._point = { point = point, rel = a,
					relPoint = type(b) == "string" and b or point,
					x = tonumber(c) or 0, y = tonumber(d) or 0 }
			end
		end
		frame.GetPoint = function(self)
			local p = self._point
			if not p then return end
			return p.point, p.rel, p.relPoint, p.x, p.y
		end
		frame.ClearAllPoints = function(self) self._point = nil end
		frame.SetScale = function(self, scale) self._scale = scale end
		frame.GetScale = function(self) return self._scale or 1 end
		frame.IsShown = function(self) return self._shown end
		frame.SetText = function(self, text) self._text = tostring(text or "") end
		frame.GetText = function(self) return self._text end
		frame.CreateFontString = function(self)
			local fs = newFontString()
			self._fontStrings[#self._fontStrings + 1] = fs
			return fs
		end
		frame.CreateTexture = function()
			return setmetatable({}, { __index = function() return function() end end })
		end
		setmetatable(frame, { __index = function() return function() end end })
		state.frames[#state.frames + 1] = frame
		return frame
	end

	state.completedQuests = {}
	_G.C_QuestLog = {
		IsQuestFlaggedCompleted = function(questID)
			return state.completedQuests[questID] or false
		end,
	}

	state.maxPlayerLevel = 90
	state.expansionLevel = 11 -- Midnight
	_G.GetExpansionLevel = function() return state.expansionLevel end
	_G.GetMaxLevelForPlayerExpansion = function() return state.maxPlayerLevel end

	_G.UIParent = _G.CreateFrame("Frame", "UIParent")
	_G.Minimap = _G.CreateFrame("Frame", "Minimap")
	_G.GameTooltip = _G.CreateFrame("GameTooltip", "GameTooltip")

	_G.C_AddOns = {
		GetAddOnMetadata = function(_, field) return state.metadata[field] end,
		IsAddOnLoaded = function(name) return state.loadedAddons[name] or false end,
		LoadAddOn = function(name)
			if state.loadAddOnResult then
				state.loadedAddons[name] = true
				return true
			end
			return false, "DISABLED"
		end,
	}

	_G.UnitName = function() return "Testchar" end
	_G.GetRealmName = function() return "Testrealm" end
	_G.UnitFactionGroup = function() return "Alliance" end
	state.playerLevel = 80
	state.money = 1234567
	state.zone = "Dornogal"
	_G.UnitLevel = function() return state.playerLevel end
	_G.UnitClass = function() return "Magier", "MAGE", 8 end
	_G.UnitRace = function() return "Mensch", "Human", 1 end
	_G.GetMoney = function() return state.money end
	_G.UnitXP = function() return 55000 end
	_G.UnitXPMax = function() return 100000 end
	_G.GetXPExhaustion = function() return 12000 end
	_G.GetRealZoneText = function() return state.zone end

	state.timePlayedRequests = 0
	_G.RequestTimePlayed = function()
		state.timePlayedRequests = state.timePlayedRequests + 1
	end

	-- Mythic+ / Grosse Schatzkammer:
	-- state.mplus = { rating, keystone = {mapID, level}, maps = { [mapID] = name },
	--                 best = { [mapID] = {level, score, inTime} }, vault = { {type,index,progress,threshold,level} } }
	state.mplus = { rating = 0, keystone = nil, maps = {}, best = {}, vault = {},
		hasRewards = false, history = {} }
	_G.C_ChallengeMode = {
		GetOverallDungeonScore = function() return state.mplus.rating end,
		GetMapUIInfo = function(mapID) return state.mplus.maps[mapID] end,
		GetMapTable = function()
			local ids = {}
			for mapID in pairs(state.mplus.maps) do ids[#ids + 1] = mapID end
			table.sort(ids)
			return ids
		end,
	}
	_G.C_MythicPlus = {
		GetOwnedKeystoneChallengeMapID = function()
			return state.mplus.keystone and state.mplus.keystone.mapID
		end,
		GetOwnedKeystoneLevel = function()
			return state.mplus.keystone and state.mplus.keystone.level
		end,
		GetSeasonBestForMap = function(mapID)
			local best = state.mplus.best[mapID]
			if not best then return nil, nil end
			local info = { level = best.level, dungeonScore = best.score }
			if best.inTime then return info, nil end
			return nil, info
		end,
		RequestMapInfo = function() end,
		GetRunHistory = function()
			return state.mplus.history
		end,
	}
	_G.C_WeeklyRewards = {
		GetActivities = function() return state.mplus.vault end,
		HasAvailableRewards = function() return state.mplus.hasRewards end,
	}

	-- Wochen-Affixe (1.0.0)
	_G.C_MythicPlus.GetCurrentAffixes = function()
		return state.mplus.affixes or {}
	end
	_G.C_ChallengeMode.GetAffixInfo = function(id)
		return state.mplus.affixNames and state.mplus.affixNames[id] or nil
	end

	-- Gruppe + Chat-Ansagen (1.0.0)
	state.groupType = nil -- nil | "party" | "raid"
	state.sentChat = {}
	_G.IsInGroup = function() return state.groupType ~= nil end
	_G.IsInRaid = function() return state.groupType == "raid" end
	_G.SendChatMessage = function(message, channel)
		state.sentChat[#state.sentChat + 1] = { message = message, channel = channel }
	end

	-- Auktionshaus: state.ownedAuctions = { { itemID, qty, buyout, bid, band, sold } }
	state.ownedAuctions = {}
	_G.C_AuctionHouse = {
		QueryOwnedAuctions = function() end,
		GetOwnedAuctions = function()
			local list = {}
			for _, auction in ipairs(state.ownedAuctions) do
				list[#list + 1] = {
					itemKey = { itemID = auction.itemID },
					quantity = auction.qty or 1,
					buyoutAmount = auction.buyout or 0,
					bidAmount = auction.bid or 0,
					timeLeft = auction.band or 3,
					status = auction.sold and 1 or 0,
				}
			end
			return list
		end,
	}

	-- Berufe: state.professions = { { name, rank, maxRank, skillLineID }, ... }
	state.professions = {}
	_G.GetProfessions = function()
		local indices = {}
		for i = 1, #state.professions do indices[i] = i end
		return unpack(indices)
	end
	_G.GetProfessionInfo = function(index)
		local prof = state.professions[index]
		if not prof then return nil end
		return prof.name, 134400, prof.rank, prof.maxRank, 0, 0, prof.skillLineID
	end

	-- Offenes Berufsfenster: state.tradeskill = { skillLineID, recipes = { {id,name,learned} } }
	state.tradeskill = nil
	_G.C_TradeSkillUI = {
		GetChildProfessionInfo = function()
			if not state.tradeskill then return nil end
			return { professionID = state.tradeskill.skillLineID,
				parentProfessionID = state.tradeskill.skillLineID }
		end,
		GetAllRecipeIDs = function()
			local ids = {}
			for _, recipe in ipairs((state.tradeskill and state.tradeskill.recipes) or {}) do
				ids[#ids + 1] = recipe.id
			end
			return ids
		end,
		GetRecipeInfo = function(recipeID)
			for _, recipe in ipairs((state.tradeskill and state.tradeskill.recipes) or {}) do
				if recipe.id == recipeID then
					return { name = recipe.name,
						learned = recipe.learned ~= false }
				end
			end
			return nil
		end,
		GetRecipeSchematic = function(recipeID)
			for _, recipe in ipairs((state.tradeskill and state.tradeskill.recipes) or {}) do
				if recipe.id == recipeID then
					local slots = {}
					for _, reagent in ipairs(recipe.reagents or {}) do
						slots[#slots + 1] = {
							quantityRequired = reagent.qty,
							required = true,
							reagents = { { itemID = reagent.itemID } },
						}
					end
					return { reagentSlotSchematics = slots }
				end
			end
			return nil
		end,
	}

	-- Briefkasten: state.inbox = { { sender, subject, money, daysLeft, items = { {id,count,name} } } }
	state.inbox = {}
	_G.GetInboxNumItems = function() return #state.inbox end
	_G.GetInboxHeaderInfo = function(i)
		local mail = state.inbox[i]
		if not mail then return nil end
		return nil, nil, mail.sender, mail.subject, mail.money or 0, 0,
			mail.daysLeft or 30, (#(mail.items or {}) > 0)
	end
	_G.GetInboxItem = function(i, attach)
		local mail = state.inbox[i]
		local item = mail and mail.items and mail.items[attach]
		if not item then return nil end
		return item.name or ("Item " .. item.id), item.id, nil, item.count or 1
	end
	_G.ATTACHMENTS_MAX_RECEIVE = 16

	-- Gildenbank: state.guildName + state.guildBank = { [tab] = { [slot] = { id, count } } }
	state.guildName = nil
	state.guildBank = {}
	state.guildBankTabNames = {}
	_G.GetGuildInfo = function() return state.guildName end
	_G.GetNumGuildBankTabs = function()
		local count = 0
		for _ in pairs(state.guildBank) do count = count + 1 end
		return count
	end
	_G.GetGuildBankItemInfo = function(tab, slot)
		local item = state.guildBank[tab] and state.guildBank[tab][slot]
		return nil, item and item.count or 0
	end
	_G.GetGuildBankTabInfo = function(tab)
		return state.guildBankTabNames[tab]
	end
	_G.MAX_GUILDBANK_SLOTS_PER_TAB = 98
	_G.GetGuildBankItemLink = function(tab, slot)
		local item = state.guildBank[tab] and state.guildBank[tab][slot]
		return item and ("|Hitem:" .. item.id .. "::|h[Item]|h") or nil
	end

	-- Shift-Klick + Chat-Links
	state.shiftDown = false
	state.altDown = false
	_G.IsAltKeyDown = function() return state.altDown end
	_G.UISpecialFrames = {}
	state.chatLinks = {}
	_G.IsShiftKeyDown = function() return state.shiftDown end
	_G.ChatEdit_InsertLink = function(link)
		state.chatLinks[#state.chatLinks + 1] = link
		return true
	end

	-- Ruf: state.reputations = { { factionID, name, reaction, currentStanding,
	--   currentReactionThreshold, nextReactionThreshold, isHeader, isHeaderWithRep } }
	state.reputations = {}
	_G.C_Reputation = {
		GetNumFactions = function() return #state.reputations end,
		GetFactionDataByIndex = function(i) return state.reputations[i] end,
	}

	-- Questlog: state.questlog = { { questID, title, isHeader } }
	state.questlog = {}
	_G.C_QuestLog = _G.C_QuestLog or {}
	_G.C_QuestLog.GetNumQuestLogEntries = function() return #state.questlog end
	_G.C_QuestLog.GetInfo = function(i) return state.questlog[i] end

	-- Container: state.containers[bagID] = { size = n, items = { [slot] = { id, count } } }
	state.containers = {}
	state.equippedBags = {} -- [bagID] = itemID der ausgeruesteten Tasche
	_G.C_Container = {
		ContainerIDToInventoryID = function(bagID) return 30 + bagID end,
		GetContainerNumSlots = function(bagID)
			local bag = state.containers[bagID]
			return bag and bag.size or 0
		end,
		GetContainerItemInfo = function(bagID, slot)
			local bag = state.containers[bagID]
			local item = bag and bag.items and bag.items[slot]
			if item then
				return { itemID = item.id, stackCount = item.count }
			end
		end,
	}

	-- Waehrungen: state.currencies = Array von { id, name, qty, max } oder { header = "..." }
	state.currencies = {}
	_G.C_CurrencyInfo = {
		GetCurrencyListSize = function() return #state.currencies end,
		GetCurrencyListInfo = function(i)
			local c = state.currencies[i]
			if not c then return end
			if c.header then
				return { name = c.header, isHeader = true }
			end
			return { name = c.name, isHeader = false, quantity = c.qty, maxQuantity = c.max }
		end,
		GetCurrencyListLink = function(i)
			local c = state.currencies[i]
			return (c and c.id) and ("currency:" .. c.id) or nil
		end,
		GetCurrencyIDFromLink = function(link)
			return tonumber(link:match("currency:(%d+)"))
		end,
	}

	-- Ausruestung: state.equipment[slot] = { id, ilvl }
	state.equipment = {}
	state.avgItemLevel = { overall = 0, equipped = 0 }
	_G.GetInventoryItemID = function(_, slot)
		-- Taschen-Slots (31-42 via ContainerIDToInventoryID = 30 + bagID)
		if slot and slot >= 31 and slot <= 42 then
			return state.equippedBags[slot - 30]
		end
		local item = state.equipment[slot]
		return item and item.id
	end
	_G.GetInventoryItemLink = function(_, slot)
		local item = state.equipment[slot]
		return item and ("item:" .. item.id) or nil
	end
	_G.ItemLocation = {
		CreateFromBagAndSlot = function(_, bagID, slot)
			return { bagID = bagID, slotIndex = slot }
		end,
		CreateFromEquipmentSlot = function(_, slot)
			return { equipmentSlotIndex = slot }
		end,
	}
	_G.C_Item = {
		IsBoundToAccountUntilEquip = function(loc)
			local bagFlags = state.warboundSlots[loc.bagID]
			return (bagFlags and bagFlags[loc.slotIndex]) and true or false
		end,
		-- Link-basiert: liefert bei aufwertbaren Items nur das BASIS-Level
		GetDetailedItemLevelInfo = function(link)
			local id = tonumber(link:match("item:(%d+)"))
			for _, item in pairs(state.equipment) do
				if item.id == id then return item.baseIlvl or item.ilvl end
			end
			return 0
		end,
		-- Instanz-basiert: echtes Level der konkreten Item-Instanz
		GetCurrentItemLevel = function(loc)
			local item = loc and loc.equipmentSlotIndex
				and state.equipment[loc.equipmentSlotIndex]
			return item and item.ilvl or 0
		end,
		DoesItemExist = function(loc)
			if loc and loc.equipmentSlotIndex then
				return state.equipment[loc.equipmentSlotIndex] ~= nil
			end
			return true
		end,
		GetItemInfo = function(itemID)
			local d = state.itemDetails[itemID]
			return state.itemNames[itemID], nil, nil, nil, nil, nil, nil,
				nil, nil, nil, nil, nil, nil, d and d.bindType, d and d.expansion
		end,
		GetItemIconByID = function(itemID)
			local d = state.itemDetails[itemID]
			return d and d.icon
		end,
		GetItemQualityByID = function(itemID)
			local d = state.itemDetails[itemID]
			return d and d.quality
		end,
		GetItemInfoInstant = function(itemID)
			local d = state.itemDetails[itemID]
			if d then
				return itemID, d.type, d.subtype, nil, d.icon, d.classID, d.subclassID
			end
		end,
	}
	state.itemNames = {}
	state.itemDetails = {}
	state.warboundSlots = {}

	-- Tooltip-Pipeline (TooltipDataProcessor)
	state.tooltipHandlers = {}
	_G.Enum = { TooltipDataType = { Item = 17 } }
	_G.TooltipDataProcessor = {
		AddTooltipPostCall = function(_, fn)
			state.tooltipHandlers[#state.tooltipHandlers + 1] = fn
		end,
	}
	_G.GetAverageItemLevel = function()
		return state.avgItemLevel.overall, state.avgItemLevel.equipped
	end

	-- Gespeicherte Instanzen (Schlachtzugs-IDs), via mock.SetSavedInstances befuellbar
	state.savedInstances = {}
	state.raidInfoRequests = 0
	_G.RequestRaidInfo = function()
		state.raidInfoRequests = state.raidInfoRequests + 1
	end
	_G.GetNumSavedInstances = function() return #state.savedInstances end
	_G.GetSavedInstanceInfo = function(i)
		local s = state.savedInstances[i]
		if not s then return end
		return s.name, s.id, s.reset, s.difficultyID, s.locked, s.extended,
			0, s.isRaid, s.maxPlayers, s.difficultyName, s.numEncounters, s.encounterProgress
	end

	-- WoW-Global 'time' (Unix-Zeit), deterministisch an die Mock-Uhr gekoppelt
	_G.time = function() return 1700000000 + math.floor(state.now) end

	_G.SlashCmdList = state.slashHandlers

	_G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[#parts + 1] = tostring(select(i, ...))
		end
		state.printed[#state.printed + 1] = table.concat(parts, " ")
	end

	_G.ExoTwinksDB = nil
	_G.AltoCoreDB = nil
	_G.Exo = nil

	-- Legacy-SavedVariables (Altoholic/DataStore) aufraeumen
	_G.DataStore_CharacterIDs = nil
	_G.DataStore_Characters_Info = nil
	_G.DataStore_Containers_Characters = nil
	_G.DataStore_Containers_Warbank = nil
	_G.DataStore_Inventory_Characters = nil
	for i = 1, 10 do
		_G["SLASH_ALTOHOLIC" .. i] = nil
	end
end

-- Markiert ein (fremdes) Addon als geladen, z.B. das alte Altoholic
function mock.SetAddonLoaded(name)
	state.loadedAddons[name] = true
end

-- Addon-Loader: simuliert das WoW-Vararg-Protokoll (addonName, addonTable)
function mock.LoadAddon(files, addonName)
	addonName = addonName or "ExoTwinksCore"
	local shared = {}
	for _, path in ipairs(files) do
		local chunk, err = loadfile(path)
		assert(chunk, "Kann Datei nicht laden: " .. tostring(err))
		chunk(addonName, shared)
	end
	return shared
end

-- Standard-Ladefolge von ExoTwinksCore (entspricht der TOC)
function mock.LoadExoCore(root)
	root = root or "ExoTwinksCore"
	return mock.LoadAddon({
		root .. "/Core/Log.lua",
		root .. "/Core/WowAPI.lua",
		root .. "/Core/EventBus.lua",
		root .. "/Core/Scheduler.lua",
		root .. "/Storage/Schema.lua",
		root .. "/Storage/Migrations.lua",
		root .. "/Storage/Migrations/001_initial.lua",
		root .. "/Storage/Store.lua",
		root .. "/Storage/LegacyImport.lua",
		root .. "/API/Public.lua",
		root .. "/API/ItemCounts.lua",
		root .. "/Collectors/Auctions.lua",
		root .. "/Collectors/Characters.lua",
		root .. "/Collectors/Containers.lua",
		root .. "/Collectors/Currencies.lua",
		root .. "/Collectors/Equipment.lua",
		root .. "/Collectors/InstanceLocks.lua",
		root .. "/Collectors/GuildBank.lua",
		root .. "/Collectors/GuildTax.lua",
		root .. "/Collectors/Mail.lua",
		root .. "/Collectors/MythicPlus.lua",
		root .. "/Collectors/Professions.lua",
		root .. "/Collectors/Quests.lua",
		root .. "/Collectors/Reputations.lua",
		root .. "/Collectors/Weeklies.lua",
		root .. "/Services/Minimap.lua",
		root .. "/Services/Tooltip.lua",
		root .. "/Services/Compat.lua",
		root .. "/Core/Init.lua",
	})
end

-- Laedt das Data-Addon (Saisondaten); greift wie die UI ueber das globale Exo zu.
function mock.LoadExoData(root)
	root = root or "ExoTwinksData"
	return mock.LoadAddon({ root .. "/Season.lua" }, "ExoTwinksData")
end

-- Laedt ExoTwinksUI in den bestehenden Exo-Namespace (wie in-game via LoadOnDemand).
-- WICHTIG: ExoTwinksUI greift ueber das globale Exo zu (eigener Vararg-Namespace in-game).
function mock.LoadExoUI(root)
	root = root or "ExoTwinksUI"
	return mock.LoadAddon({
		root .. "/Framework/Format.lua",
		root .. "/Framework/Widgets.lua",
		root .. "/Framework/Theme.lua",
		root .. "/Framework/VirtualScroll.lua",
		root .. "/Framework/ItemList.lua",
		root .. "/Framework/Window.lua",
		root .. "/Tabs/Overview.lua",
		root .. "/Tabs/Characters.lua",
		root .. "/Tabs/CharacterDetail.lua",
		root .. "/Tabs/Search.lua",
		root .. "/Tabs/Inventory.lua",
		root .. "/Tabs/Bank.lua",
		root .. "/Tabs/Warband.lua",
		root .. "/Tabs/Professions.lua",
		root .. "/Tabs/Mail.lua",
		root .. "/Tabs/Reputations.lua",
		root .. "/Tabs/Designer.lua",
		root .. "/Init.lua",
	}, "ExoTwinksUI")
end

-- Simuliert den kompletten Login: ADDON_LOADED -> Store:Init
-- Berufe des eingeloggten Chars setzen (Liste von { name, rank, maxRank, skillLineID })
function mock.SetProfessions(list)
	state.professions = list or {}
end

-- Berufsfenster "oeffnen": skillLineID + Rezepte { { id, name, learned } }
function mock.SetTradeSkill(skillLineID, recipes)
	if skillLineID == nil then
		state.tradeskill = nil
	else
		state.tradeskill = { skillLineID = skillLineID, recipes = recipes or {} }
	end
end

-- Briefkasten setzen (Liste von { sender, subject, money, daysLeft, items })
function mock.SetInbox(mails)
	state.inbox = mails or {}
end

-- Gildenbank setzen: Name + { [tab] = { [slot] = { id, count } } }
-- + optional Tab-Namen { [tab] = "Mats" }
function mock.SetGuildBank(guildName, tabs, tabNames)
	state.guildName = guildName
	state.guildBank = tabs or {}
	state.guildBankTabNames = tabNames or {}
end

function mock.SetShiftDown(down)
	state.shiftDown = down and true or false
end

function mock.SetAltDown(down)
	state.altDown = down and true or false
end

function mock.GetChatLinks()
	return state.chatLinks
end

-- Ruf-Fraktionen setzen: Liste von { factionID, name, standingID, value, max }
function mock.SetReputations(list)
	state.reputations = {}
	for _, rep in ipairs(list or {}) do
		state.reputations[#state.reputations + 1] = {
			factionID = rep.factionID,
			name = rep.name,
			reaction = rep.standingID or 4,
			currentStanding = rep.value or 0,
			currentReactionThreshold = 0,
			nextReactionThreshold = rep.max or 0,
			isHeader = false,
		}
	end
end

-- Questlog setzen: Liste von { questID, title }
function mock.SetQuestLog(list)
	state.questlog = {}
	for _, quest in ipairs(list or {}) do
		state.questlog[#state.questlog + 1] = {
			questID = quest.questID, title = quest.title, isHeader = false,
		}
	end
end

-- Wochen-Affixe setzen: Liste von { id, name }
function mock.SetAffixes(list)
	state.mplus.affixes = {}
	state.mplus.affixNames = {}
	for _, affix in ipairs(list or {}) do
		state.mplus.affixes[#state.mplus.affixes + 1] = { id = affix.id }
		state.mplus.affixNames[affix.id] = affix.name
	end
end

-- Gruppenstatus: nil (solo) | "party" | "raid"
function mock.SetGroup(groupType)
	state.groupType = groupType
end

function mock.GetSentChat()
	return state.sentChat
end

-- Eigene Auktionen setzen: Liste von { itemID, qty, buyout, bid, band, sold }
function mock.SetOwnedAuctions(list)
	state.ownedAuctions = list or {}
end

-- Ausgeruestete Tasche setzen (fuer Bag-Details)
function mock.SetEquippedBag(bagID, itemID)
	state.equippedBags[bagID] = itemID
end

-- Enum.BagIndex setzen (Bank-Umbau 11.2+): map = { AccountBankTab_1 = 12, ... }
function mock.SetBagIndex(map)
	_G.Enum.BagIndex = map
end

function mock.SimulateLogin()
	mock.FireEvent("ADDON_LOADED", "ExoTwinksCore")
end

-- WoW-Event an alle Frames senden, die es registriert haben
function mock.FireEvent(event, ...)
	for _, frame in ipairs(state.frames) do
		if frame._events[event] and frame._scripts.OnEvent then
			frame._scripts.OnEvent(frame, event, ...)
		end
	end
end

-- Uhr vorstellen und OnUpdate-Skripte feuern (1 Tick)
function mock.AdvanceTime(seconds)
	state.now = state.now + (seconds or 0)
	for _, frame in ipairs(state.frames) do
		if frame._scripts.OnUpdate then
			frame._scripts.OnUpdate(frame, seconds)
		end
	end
end

function mock.SetLoadAddOnResult(flag)
	state.loadAddOnResult = flag
end

function mock.SetSavedInstances(list)
	state.savedInstances = list or {}
end

function mock.RaidInfoRequestCount()
	return state.raidInfoRequests
end

-- Setter fuer Phase-2-Collectors -------------------------------------------------

function mock.SetPlayerLevel(level)
	state.playerLevel = level
end

function mock.SetMoney(copper)
	state.money = copper
end

function mock.SetZone(zone)
	state.zone = zone
end

function mock.TimePlayedRequestCount()
	return state.timePlayedRequests
end

-- items = { [slot] = { id = ..., count = ... } }
function mock.SetContainer(bagID, size, items)
	state.containers[bagID] = { size = size, items = items or {} }
end

function mock.ClearContainers()
	state.containers = {}
end

-- list = Array von { id, name, qty, max } oder { header = "Kategorie" }
function mock.SetCurrencies(list)
	state.currencies = list or {}
end

-- slots = { [slot] = { id, ilvl, baseIlvl? } }
-- ilvl = echtes Instanz-Level; baseIlvl = Link-/Basis-Level (aufwertbare Items)
function mock.SetEquipment(slots, avgOverall, avgEquipped)
	state.equipment = slots or {}
	state.avgItemLevel = { overall = avgOverall or 0, equipped = avgEquipped or 0 }
end

-- Mythic+-Zustand setzen (merged in state.mplus)
function mock.SetMythicPlus(data)
	for key, value in pairs(data) do
		state.mplus[key] = value
	end
end

-- names = { [itemID] = "Name" }
-- done = { [questID] = true }
function mock.SetCompletedQuests(done)
	state.completedQuests = done or {}
end

function mock.SetMaxPlayerLevel(level)
	state.maxPlayerLevel = level
end

-- names = { [itemID] = "Name" }
function mock.SetItemNames(names)
	state.itemNames = names or {}
end

-- details = { [itemID] = { quality, classID, type, subclassID, subtype, expansion, icon } }
-- Exemplar-Bindung je Taschenplatz: { [bagID] = { [slot] = true } }
function mock.SetWarboundSlots(slots)
	state.warboundSlots = slots or {}
end

function mock.SetItemDetails(details)
	state.itemDetails = details or {}
end

-- Simuliert das Hovern ueber ein Item: feuert alle Tooltip-Handler.
-- Rueckgabe: Fake-Tooltip mit .lines (alle via AddLine angehaengten Texte)
function mock.HoverItem(itemID)
	local tooltip = { lines = {} }
	function tooltip:AddLine(text)
		self.lines[#self.lines + 1] = tostring(text)
	end
	for _, handler in ipairs(state.tooltipHandlers) do
		handler(tooltip, { id = itemID })
	end
	return tooltip
end

function mock.Now()
	return state.now
end

return mock
