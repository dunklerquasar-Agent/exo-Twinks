-- luacheck-Konfiguration fuer AltoNG
std = "lua51"
max_line_length = 160
self = false            -- erlaubt ungenutztes 'self' in Methoden
exclude_files = {
	"**/Libs/**",
	".luacheckrc",
}

-- Vom Addon selbst definierte Globals
globals = {
	"Exo",
	"ExoTwinksDB",
	"AltoCoreDB", -- Uebergangsweise: Daten-Uebernahme alter Installationen
	"ExoTwinks_OnAddonCompartmentClick",
	"SLASH_EXO1",
	"SLASH_EXO2",
	"SlashCmdList",
	"BINDING_HEADER_EXOTWINKS",
	"BINDING_NAME_EXO_TOGGLE",
}

-- WoW-API (nur lesend)
read_globals = {
	-- Frames & Zeit
	"CreateFrame",
	"GetTime",
	"time",
	-- Namespaces
	"C_AddOns",
	"C_Timer",
	-- Spieler
	"UnitName",
	"GetRealmName",
	"UnitFactionGroup",
	"UnitLevel",
	"UnitClass",
	"UnitRace",
	"GetMoney",
	-- Instanz-Locks
	"RequestRaidInfo",
	"GetNumSavedInstances",
	"GetSavedInstanceInfo",
	-- XP & Spielzeit
	"UnitXP",
	"UnitXPMax",
	"GetXPExhaustion",
	"RequestTimePlayed",
	"GetRealZoneText",
	-- Container / Waehrungen / Ausruestung
	"C_Container",
	"C_TradeSkillUI",
	"C_AuctionHouse",
	"C_Reputation",
	"C_QuestLog",
	"GetProfessions",
	"GetInventoryItemID",
	"GetInboxNumItems",
	"GetInboxHeaderInfo",
	"GetInboxItem",
	"ATTACHMENTS_MAX_RECEIVE",
	"GetGuildInfo",
	"GetNumGuildBankTabs",
	"GetGuildBankItemInfo",
	"GetGuildBankItemLink",
	"GetGuildBankTabInfo",
	"MAX_GUILDBANK_SLOTS_PER_TAB",
	"IsShiftKeyDown",
	"IsAltKeyDown",
	"UISpecialFrames",
	"IsInGroup",
	"IsInRaid",
	"SendChatMessage",
	"ChatEdit_InsertLink",
	"GetProfessionInfo",
	"C_CurrencyInfo",
	"C_Item",
	"GetInventoryItemID",
	"GetInventoryItemLink",
	"GetAverageItemLevel",
	-- UI
	"UIParent",
	"Minimap",
	"GameTooltip",
	"GetExpansionLevel",
	"GetMaxLevelForPlayerExpansion",
	-- Tooltip-Pipeline
	"TooltipDataProcessor",
	"Enum",
	-- Mythic+ / Grosse Schatzkammer
	"C_ChallengeMode",
	"C_MythicPlus",
	"C_QuestLog",
	"C_WeeklyRewards",
}

files["spec/**/*.lua"] = {
	std = "+busted",
	globals = { "Exo", "ExoTwinksDB", "AltoCoreDB" },
	read_globals = { "loadfile" },
}
