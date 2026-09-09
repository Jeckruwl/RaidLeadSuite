-- ============================================================
-- RLSuite - Core
-- ============================================================

RLSuite = RLSuite or {}
RLSuite.version = "1.0.0"

local defaults = {
    profile = "",
    difficulty = "10",
    debug = false,
    macrobar = {
        enabled = true,
        locked = false,
        scale = 1.0,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 100,
        keybinds = {},
        macros = {
            preraid = {},
            preboss = {},
            infight = {},
        },
    },
    profiles = {},
    groupmaking = {
        raid = "",
        difficulty = "10",
        reserved = {},
        otherReq = "",
        comp = {},
        spamChannels = {"General", "Trade"},
        spamInterval = 60,
    },
    whisplist = {
        entries = {},
    },
    raidframe = {
        enabled = true,
        showBuffs = true,
        showFlask = true,
        showFood = true,
        appearance = {
            barHeight = 20,
            iconSize = 16,
            border = true,
        },
        alerts = {},
    },
    mschanges = {},
    loot = {
        history = {},
        rollDuration = 10,
        rerollDuration = 5,
    },
    appearance = {
        theme = "default",
        font = "Fonts\FRIZQT__.TTF",
        fontSize = 12,
    },
}

RLSuite.raidDB = {
    ["Icecrown Citadel"] = {
        bosses = {"Lord Marrowgar", "Lady Deathwhisper", "Gunship Battle", "Deathbringer Saurfang",
                  "Rotface", "Festergut", "Professor Putricide", "Blood Prince Council",
                  "Blood-Queen Lana'thel", "Valithria Dreamwalker", "Sindragosa", "The Lich King"},
        sizes = {10, 25},
    },
    ["Trial of the Crusader"] = {
        bosses = {"Northrend Beasts", "Lord Jaraxxus", "Faction Champions", "Twin Val'kyr", "Anub'arak"},
        sizes = {10, 25},
    },
    ["Ulduar"] = {
        bosses = {"Flame Leviathan", "Ignis the Furnace Master", "Razorscale", "XT-002 Deconstructor",
                  "Assembly of Iron", "Kologarn", "Auriaya", "Hodir", "Thorim", "Freya",
                  "Mimiron", "General Vezax", "Yogg-Saron", "Algalon the Observer"},
        sizes = {10, 25},
    },
    ["Naxxramas"] = {
        bosses = {"Anub'Rekhan", "Grand Widow Faerlina", "Maexxna", "Noth the Plaguebringer",
                  "Heigan the Unclean", "Loatheb", "Instructor Razuvious", "Gothik the Harvester",
                  "The Four Horsemen", "Patchwerk", "Grobbulus", "Gluth", "Thaddius",
                  "Sapphiron", "Kel'Thuzad"},
        sizes = {10, 25},
    },
    ["The Obsidian Sanctum"] = {bosses = {"Sartharion"}, sizes = {10, 25}},
    ["The Eye of Eternity"] = {bosses = {"Malygos"}, sizes = {10, 25}},
    ["Onyxia's Lair"] = {bosses = {"Onyxia"}, sizes = {10, 25}},
    ["Ruby Sanctum"] = {bosses = {"Halion"}, sizes = {10, 25}},
    ["Vault of Archavon"] = {
        bosses = {"Archavon", "Emalon", "Koralon", "Toravon"},
        sizes = {10, 25},
    },
}

RLSuite.classData = {
    WARRIOR     = {roles = {"Tank", "DPS"}, specs = {"Arms", "Fury", "Protection"}},
    PALADIN     = {roles = {"Tank", "Healer", "DPS"}, specs = {"Holy", "Protection", "Retribution"}},
    HUNTER      = {roles = {"DPS"}, specs = {"Beast Mastery", "Marksmanship", "Survival"}},
    ROGUE       = {roles = {"DPS"}, specs = {"Assassination", "Combat", "Subtlety"}},
    PRIEST      = {roles = {"Healer", "DPS"}, specs = {"Discipline", "Holy", "Shadow"}},
    DEATHKNIGHT = {roles = {"Tank", "DPS"}, specs = {"Blood", "Frost", "Unholy"}},
    SHAMAN      = {roles = {"Healer", "DPS"}, specs = {"Elemental", "Enhancement", "Restoration"}},
    MAGE        = {roles = {"DPS"}, specs = {"Arcane", "Fire", "Frost"}},
    WARLOCK     = {roles = {"DPS"}, specs = {"Affliction", "Demonology", "Destruction"}},
    DRUID       = {roles = {"Tank", "Healer", "DPS"}, specs = {"Balance", "Feral", "Restoration"}},
}

RLSuite.keyAbilities = {
    WARRIOR     = {"Shield Wall", "Last Stand"},
    PALADIN     = {"Divine Protection", "Lay on Hands", "Hand of Sacrifice"},
    HUNTER      = {"Misdirection", "Deterrence"},
    ROGUE       = {"Tricks of the Trade", "Vanish"},
    PRIEST      = {"Pain Suppression", "Guardian Spirit", "Divine Hymn"},
    DEATHKNIGHT = {"Icebound Fortitude", "Anti-Magic Shell", "Vampiric Blood"},
    SHAMAN      = {"Heroism", "Bloodlust", "Nature's Swiftness"},
    MAGE        = {"Ice Block", "Invisibility"},
    WARLOCK     = {"Soulstone", "Demonic Circle: Teleport"},
    DRUID       = {"Tranquility", "Rebirth", "Barkskin", "Innervate"},
}

RLSuite.buffData = {
    flask = {
        "Flask of the Frost Wyrm", "Flask of Endless Rage", "Flask of Pure Mojo",
        "Flask of Stoneblood", "Flask of the North",
    },
    food = {
        "Fish Feast", "Great Feast", "Small Feast",
        "Spiced Worm Burger", "Mega Mammoth Meal", "Tender Shoveltusk Steak",
        "Rhinolicious Wormsteak", "Hearty Rhino", "Snapper Extreme",
    },
    buffs = {
        "Mark of the Wild", "Gift of the Wild",
        "Power Word: Fortitude", "Prayer of Fortitude",
        "Arcane Brilliance", "Arcane Intellect",
        "Blessing of Kings", "Greater Blessing of Kings",
        "Blessing of Might", "Greater Blessing of Might",
        "Blessing of Wisdom", "Greater Blessing of Wisdom",
    },
}

local frame = CreateFrame("Frame", "RLSuiteCoreFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_RAID")
frame:RegisterEvent("CHAT_MSG_RAID_LEADER")
frame:RegisterEvent("CHAT_MSG_LOOT")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "RLSuite" then
            RLSuiteDB = RLSuiteDB or {}
            RLSuiteCharDB = RLSuiteCharDB or {}
            for k, v in pairs(defaults) do
                if RLSuiteDB[k] == nil then
                    RLSuiteDB[k] = v
                elseif type(v) == "table" and type(RLSuiteDB[k]) == "table" then
                    for k2, v2 in pairs(v) do
                        if RLSuiteDB[k][k2] == nil then
                            RLSuiteDB[k][k2] = v2
                        end
                    end
                end
            end
            RLSuite.utils:Print("v" .. RLSuite.version .. " caricato. Digita /rls per aprire.")
        end
    elseif event == "PLAYER_LOGIN" then
        RLSuite:InitModules()
    elseif event == "RAID_ROSTER_UPDATE" then
        RLSuite:UpdateRaidContext()
    elseif event == "PLAYER_REGEN_ENABLED" then
        RLSuite.context = "preboss"
        if RLSuite.macrobar and RLSuite.macrobar.UpdatePhase then
            RLSuite.macrobar:UpdatePhase()
            RLSuite.macrobar:ShowKeypad(true)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        RLSuite.context = "infight"
        if RLSuite.macrobar and RLSuite.macrobar.UpdatePhase then
            RLSuite.macrobar:UpdatePhase()
            RLSuite.macrobar:ShowKeypad(false)
        end
    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        if RLSuite.groupmaking and RLSuite.groupmaking.OnWhisper then
            RLSuite.groupmaking:OnWhisper(sender, msg)
        end
    elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        local msg, sender = ...
        if RLSuite.msManager and RLSuite.msManager.ParseMSMessage then
            RLSuite.msManager:ParseMSMessage(sender, msg)
        end
    elseif event == "CHAT_MSG_LOOT" then
        local msg = ...
        if RLSuite.lootManager and RLSuite.lootManager.OnLootMessage then
            RLSuite.lootManager:OnLootMessage(msg)
        end
    end
end)

SLASH_RLSUITE1 = "/rls"
SLASH_RLSUITE2 = "/rlsuite"
SlashCmdList["RLSUITE"] = function(msg)
    if msg == "macrobar" then
        if RLSuite.macrobar then RLSuite.macrobar:Toggle() end
    elseif msg == "group" then
        if RLSuite.groupmaking then RLSuite.groupmaking:Toggle() end
    elseif msg == "ms" then
        if RLSuite.msManager then RLSuite.msManager:Toggle() end
    elseif msg == "loot" then
        if RLSuite.lootManager then RLSuite.lootManager:Toggle() end
    elseif msg == "config" then
        if RLSuite.config then RLSuite.config:Toggle() end
    else
        if RLSuite.mainWindow then RLSuite.mainWindow:Toggle() end
    end
end

RLSuite.context = "preraid"

function RLSuite:UpdateRaidContext()
    local inRaid = GetNumRaidMembers() > 0
    local inCombat = UnitAffectingCombat("player")
    if not inRaid then
        self.context = "preraid"
    elseif inCombat then
        self.context = "infight"
    else
        self.context = "preboss"
    end
    if self.macrobar and self.macrobar.UpdatePhase then
        self.macrobar:UpdatePhase()
        self.macrobar:ShowKeypad(self.context == "preboss")
    end
end

function RLSuite:InitModules()
    if self.groupmaking and self.groupmaking.Init then self.groupmaking:Init() end
    if self.macrobar and self.macrobar.Init then self.macrobar:Init() end
    if self.raidFrame and self.raidFrame.Init then self.raidFrame:Init() end
    if self.msManager and self.msManager.Init then self.msManager:Init() end
    if self.lootManager and self.lootManager.Init then self.lootManager:Init() end
    if self.config and self.config.Init then self.config:Init() end
    if self.mainWindow and self.mainWindow.Init then self.mainWindow:Init() end
    self:UpdateRaidContext()
end
