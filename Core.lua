-- ============================================================
-- RLSuite - Core
-- ============================================================

RLSuite = RLSuite or {}
RLSuite.version = "1.3.0"

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
        buttons = 12,
        columns = 12,
        buttonSize = 32,
        spacing = 2,
        backdrop = true,
        showEmpty = true,
        mouseover = false,
        inheritGlobalFade = false,
        backdropSpacing = 2,
        heightMult = 1,
        widthMult = 1,
        alpha = 1,
        actionPaging = "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 8; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10;",
        visibility = "",
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
        reservedText = "",
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
        locked = false,
        scale = 1.0,
        width = 350,
        height = 400,
        point = "LEFT",
        relPoint = "LEFT",
        x = 10,
        y = 0,
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
        edgeSize = 32,
        bg = { r = 0.08, g = 0.08, b = 0.10, a = 1 },
        fill = { r = 0.05, g = 0.05, b = 0.07, a = 1 },
        border = { r = 0.70, g = 0.70, b = 0.70, a = 1 },
    },
    layout = {
        main = { width = 660, height = 700, scale = 1 },
        groupmaking = { scale = 1 },
        whisplist = { scale = 1 },
        ms = { scale = 1 },
        loot = { scale = 1 },
        config = { scale = 1 },
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

-- WotLK 3.3.5 baselines. Combat log uses spellId (locale-safe); player uses GetSpellCooldown.
RLSuite.abilityByName = {
    ["Shield Wall"]              = { cd = 300,  icon = "Interface\\Icons\\Ability_Warrior_ShieldWall" },
    ["Last Stand"]               = { cd = 180,  icon = "Interface\\Icons\\Spell_Holy_AshesToAshes" },
    ["Divine Protection"]        = { cd = 120,  icon = "Interface\\Icons\\Spell_Holy_Restoration" },
    ["Lay on Hands"]             = { cd = 1200, icon = "Interface\\Icons\\Spell_Holy_LayOnHands" },
    ["Hand of Sacrifice"]        = { cd = 120,  icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    ["Misdirection"]             = { cd = 30,   icon = "Interface\\Icons\\Ability_Hunter_Misdirection" },
    ["Deterrence"]               = { cd = 90,   icon = "Interface\\Icons\\Ability_Whirlwind" },
    ["Tricks of the Trade"]      = { cd = 30,   icon = "Interface\\Icons\\Ability_Rogue_TricksOftheTrade" },
    ["Vanish"]                   = { cd = 180,  icon = "Interface\\Icons\\Ability_Vanish" },
    ["Pain Suppression"]         = { cd = 180,  icon = "Interface\\Icons\\Spell_Holy_PainSupression" },
    ["Guardian Spirit"]          = { cd = 180,  icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit" },
    ["Divine Hymn"]              = { cd = 480,  icon = "Interface\\Icons\\Spell_Holy_DivineHymn" },
    ["Icebound Fortitude"]       = { cd = 120,  icon = "Interface\\Icons\\Spell_DeathKnight_IceBoundFortitude" },
    ["Anti-Magic Shell"]         = { cd = 45,   icon = "Interface\\Icons\\Spell_Shadow_AntiMagicShell" },
    ["Vampiric Blood"]           = { cd = 60,   icon = "Interface\\Icons\\Spell_Shadow_LifeDrain" },
    ["Heroism"]                  = { cd = 300,  icon = "Interface\\Icons\\Ability_Shaman_Heroism" },
    ["Bloodlust"]                = { cd = 300,  icon = "Interface\\Icons\\Spell_Nature_BloodLust" },
    ["Nature's Swiftness"]       = { cd = 180,  icon = "Interface\\Icons\\Spell_Nature_RavenForm" },
    ["Ice Block"]                = { cd = 300,  icon = "Interface\\Icons\\Spell_Frost_Frost" },
    ["Invisibility"]             = { cd = 180,  icon = "Interface\\Icons\\Ability_Mage_Invisibility" },
    ["Soulstone"]                = { cd = 900,  icon = "Interface\\Icons\\Spell_Shadow_SoulGem" },
    ["Demonic Circle: Teleport"] = { cd = 30,   icon = "Interface\\Icons\\Spell_Shadow_DemonicCircleTeleport" },
    ["Tranquility"]              = { cd = 480,  icon = "Interface\\Icons\\Spell_Nature_Tranquility" },
    ["Rebirth"]                  = { cd = 600,  icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
    ["Barkskin"]                 = { cd = 60,   icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem" },
    ["Innervate"]                = { cd = 180,  icon = "Interface\\Icons\\Spell_Nature_Lightning" },
}

RLSuite.abilityBySpellId = {
    [871] = "Shield Wall", [12975] = "Last Stand",
    [498] = "Divine Protection", [6940] = "Hand of Sacrifice",
    [633] = "Lay on Hands", [2800] = "Lay on Hands", [10310] = "Lay on Hands",
    [27154] = "Lay on Hands", [48788] = "Lay on Hands",
    [34477] = "Misdirection", [19263] = "Deterrence",
    [57934] = "Tricks of the Trade",
    [1856] = "Vanish", [1857] = "Vanish", [26889] = "Vanish",
    [33206] = "Pain Suppression", [47788] = "Guardian Spirit", [64843] = "Divine Hymn",
    [48792] = "Icebound Fortitude", [48707] = "Anti-Magic Shell", [55233] = "Vampiric Blood",
    [32182] = "Heroism", [2825] = "Bloodlust", [16188] = "Nature's Swiftness",
    [45438] = "Ice Block", [66] = "Invisibility",
    [20707] = "Soulstone", [20762] = "Soulstone", [20763] = "Soulstone",
    [20764] = "Soulstone", [20765] = "Soulstone", [27239] = "Soulstone",
    [47883] = "Soulstone", [47884] = "Soulstone",
    [48020] = "Demonic Circle: Teleport",
    [740] = "Tranquility", [8918] = "Tranquility", [9862] = "Tranquility",
    [9863] = "Tranquility", [26983] = "Tranquility", [48446] = "Tranquility", [48447] = "Tranquility",
    [20484] = "Rebirth", [20739] = "Rebirth", [20742] = "Rebirth", [20747] = "Rebirth",
    [20748] = "Rebirth", [26994] = "Rebirth", [48477] = "Rebirth",
    [22812] = "Barkskin", [29166] = "Innervate",
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
        -- Folder name is the addon name. Canonical: RLSuite. GitHub clone: RaidLeadSuite.
        if addon == "RLSuite" or addon == "RaidLeadSuite" then
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

function RLSuite:PrintHelp()
    local p = function(t) self.utils:Print(t) end
    p("Comandi disponibili:")
    p("  /rls              Finestra principale")
    p("  /rls help         Questo elenco")
    p("  /rls group        Tab Groupmaking")
    p("  /rls whisplist    Tab Whisplist")
    p("  /rls macro        Tab Macrobar (editor)")
    p("  /rls macrobar     HUD MacroBar")
    p("  /rls raidframe    Tab Raid Frame (impostazioni)")
    p("  /rls rfhud        HUD Raid Frame")
    p("  /rls ms           Tab MS Manager")
    p("  /rls loot         Tab Loot Manager")
    p("  /rls config       Tab Config")
end

SLASH_RLSUITE1 = "/rls"
SLASH_RLSUITE2 = "/rlsuite"
SlashCmdList["RLSUITE"] = function(msg)
    msg = string.gsub(string.gsub(msg or "", "^%s+", ""), "%s+$", "")
    msg = string.lower(msg)
    if msg == "help" or msg == "?" then
        RLSuite:PrintHelp()
    elseif msg == "macrobar" then
        if RLSuite.macrobar then RLSuite.macrobar:Toggle() end
    elseif msg == "rfhud" then
        if RLSuite.raidFrame then RLSuite.raidFrame:Toggle() end
    elseif msg == "group" then
        if RLSuite.mainWindow then RLSuite.mainWindow:ShowTab("group") end
    elseif msg == "whisplist" or msg == "wl" then
        if RLSuite.mainWindow then RLSuite.mainWindow:ShowTab("whisplist") end
    elseif msg == "macro" then
        if RLSuite.mainWindow then RLSuite.mainWindow:ShowTab("macro") end
    elseif msg == "raidframe" or msg == "rf" then
        if RLSuite.mainWindow then RLSuite.mainWindow:ShowTab("raidframe") end
    elseif msg == "ms" then
        if RLSuite.mainWindow then RLSuite.mainWindow:ShowTab("ms") end
    elseif msg == "loot" then
        if RLSuite.mainWindow then RLSuite.mainWindow:ShowTab("loot") end
    elseif msg == "config" then
        if RLSuite.mainWindow then RLSuite.mainWindow:ShowTab("config") end
    elseif msg == "" then
        if RLSuite.mainWindow then RLSuite.mainWindow:Toggle() end
    else
        RLSuite.utils:Print("Comando sconosciuto. /rls help per l'elenco.")
        RLSuite:PrintHelp()
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
    if self.config and self.config.ApplyTheme then
        self.config:ApplyTheme(RLSuiteDB.appearance and RLSuiteDB.appearance.theme)
    end
    if self.utils and self.utils.SkinAllWindows then
        self.utils:SkinAllWindows()
    end
    self:UpdateRaidContext()
end
