-- ============================================================
-- RLSuite - Core
-- ============================================================

RLSuite = RLSuite or {}
RLSuite.version = "1.3.0"

local defaults = {
    profile = "",
    difficulty = "10",
    debug = false,
    anchorMode = false,
    savedRaids = {},
    macrobar = {
        enabled = true,
        locked = true,
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
        showSpecsInMessage = false,
    },
    whisplist = {
        entries = {},
    },
    raidframe = {
        enabled = true,
        showBuffs = true,
        showFlask = true,
        showFood = true,
        locked = true,
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
        rarityFilter = "all",
        tradeWindow = 7200,
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
        macro = { scale = 1 },
        raidframe = { scale = 1 },
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

-- WotLK item IDs used only by debug-mode fake loot.
RLSuite.debugLoot = {
    ["Icecrown Citadel"] = {49623,50730,50429,50735,50737,50738,50070,50444,50733,49919,50428,50727,49908,52025,52026,52027,50411,50412,50603,50731},
    ["Trial of the Crusader"] = {47515,47516,47517,47233,47422,47520,47239,47528,47475,47548,47261,47545},
    ["Ulduar"] = {45620,45457,45570,45613,45449,45038,46017,45171,45443,45442,45232,45587,45448,45618},
    ["Naxxramas"] = {40384,40402,40406,40386,39714,39417,40343,40408,39245,39344,40396,40189},
    ["The Obsidian Sanctum"] = {40491,40497,40489,40488,40626,40625,40627,44006},
    ["The Eye of Eternity"] = {40455,40486,40497,40489,40626,40625,40627,43952},
    ["Onyxia's Lair"] = {49437,49298,49303,49465,49297,49299,49494,49296},
    ["Ruby Sanctum"] = {53132,53125,53127,53134,54580,54581,54582,54583},
    ["Vault of Archavon"] = {43954,43988,43998,44000,50415,50442,50709,50444},
}

RLSuite.classData = {
    WARRIOR = {
        roles = {"Tank", "DPS"},
        specs = {
            {name = "Arms", short = "ArmsWarr", role = "mdps", icon = "Interface\\Icons\\Ability_Warrior_SavageBlow"},
            {name = "Fury", short = "Fury", role = "mdps", icon = "Interface\\Icons\\Ability_Warrior_InnerRage"},
            {name = "Protection", short = "PWar", role = "tank", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance"},
        },
    },
    PALADIN = {
        roles = {"Tank", "Healer", "DPS"},
        specs = {
            {name = "Holy", short = "HPala", role = "healer", icon = "Interface\\Icons\\Spell_Holy_HolyBolt"},
            {name = "Protection", short = "PPala", role = "tank", icon = "Interface\\Icons\\Spell_Holy_DevotionAura"},
            {name = "Retribution", short = "RPala", role = "mdps", icon = "Interface\\Icons\\Spell_Holy_AuraOfLight"},
        },
    },
    HUNTER = {
        roles = {"DPS"},
        specs = {
            {name = "Beast Mastery", short = "BMHunt", role = "rdps", icon = "Interface\\Icons\\Ability_Hunter_BeastTaming"},
            {name = "Marksmanship", short = "MMHunt", role = "rdps", icon = "Interface\\Icons\\Ability_Marksmanship"},
            {name = "Survival", short = "Survival", role = "rdps", icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike"},
        },
    },
    ROGUE = {
        roles = {"DPS"},
        specs = {
            {name = "Assassination", short = "AssaRog", role = "mdps", icon = "Interface\\Icons\\Ability_Rogue_Eviscerate"},
            {name = "Combat", short = "CRog", role = "mdps", icon = "Interface\\Icons\\Ability_BackStab"},
            {name = "Subtlety", short = "SubRog", role = "mdps", icon = "Interface\\Icons\\Ability_Stealth"},
        },
    },
    PRIEST = {
        roles = {"Healer", "DPS"},
        specs = {
            {name = "Discipline", short = "Disco", role = "healer", icon = "Interface\\Icons\\Spell_Holy_WordFortitude"},
            {name = "Holy", short = "HPriest", role = "healer", icon = "Interface\\Icons\\Spell_Holy_HolyBolt"},
            {name = "Shadow", short = "Shadow", role = "rdps", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain"},
        },
    },
    DEATHKNIGHT = {
        roles = {"Tank", "DPS"},
        specs = {
            {name = "Blood", short = "BDK", role = "tank", icon = "Interface\\Icons\\Spell_Deathknight_BloodPresence"},
            {name = "Frost", short = "FDK", role = "mdps", icon = "Interface\\Icons\\Spell_Deathknight_FrostPresence"},
            {name = "Unholy", short = "UDK", role = "mdps", icon = "Interface\\Icons\\Spell_Deathknight_UnholyPresence"},
        },
    },
    SHAMAN = {
        roles = {"Healer", "DPS"},
        specs = {
            {name = "Elemental", short = "Ele", role = "rdps", icon = "Interface\\Icons\\Spell_Nature_Lightning"},
            {name = "Enhancement", short = "Enha", role = "mdps", icon = "Interface\\Icons\\Spell_Nature_LightningShield"},
            {name = "Restoration", short = "RSham", role = "healer", icon = "Interface\\Icons\\Spell_Nature_MagicImmunity"},
        },
    },
    MAGE = {
        roles = {"DPS"},
        specs = {
            {name = "Arcane", short = "Arcane", role = "rdps", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry"},
            {name = "Fire", short = "FireMage", role = "rdps", icon = "Interface\\Icons\\Spell_Fire_FireBolt02"},
            {name = "Frost", short = "FrostMage", role = "rdps", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02"},
        },
    },
    WARLOCK = {
        roles = {"DPS"},
        specs = {
            {name = "Affliction", short = "Affly", role = "rdps", icon = "Interface\\Icons\\Spell_Shadow_DeathCoil"},
            {name = "Demonology", short = "Demo", role = "rdps", icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis"},
            {name = "Destruction", short = "Destro", role = "rdps", icon = "Interface\\Icons\\Spell_Shadow_RainOfFire"},
        },
    },
    DRUID = {
        roles = {"Tank", "Healer", "DPS"},
        specs = {
            {name = "Balance", short = "Boomie", role = "rdps", icon = "Interface\\Icons\\Spell_Nature_StarFall"},
            {name = "Feral Bear", short = "Bear", role = "tank", icon = "Interface\\Icons\\Ability_Racial_BearForm"},
            {name = "Feral Cat", short = "Cat", role = "mdps", icon = "Interface\\Icons\\Ability_Druid_CatForm"},
            {name = "Restoration", short = "RDudu", role = "healer", icon = "Interface\\Icons\\Spell_Nature_HealingTouch"},
        },
    },
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
frame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
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
        RLSuite:UpdatePhaseUI()
    elseif event == "PLAYER_REGEN_DISABLED" then
        RLSuite.context = "infight"
        RLSuite:UpdatePhaseUI()
    elseif event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        if RLSuite.groupmaking and RLSuite.groupmaking.OnWhisper then
            RLSuite.groupmaking:OnWhisper(sender, msg)
        end
        RLSuite:HandleDebugMSWhisper(sender, msg)
    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        local msg, target = ...
        RLSuite:HandleDebugMSWhisper(UnitName("player") or target, msg)
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
    p("  /rls              Barra tab")
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

function RLSuite:HandleDebugMSWhisper(who, msg)
    if not self:DebugMode() then return end
    if not self.msManager or not self.msManager.ParseMSMessage then return end
    local clean = string.gsub(msg or "", "^%[[^%]]+%]%s*", "")
    self.msManager:ParseMSMessage(who or UnitName("player") or "?", clean)
end

function RLSuite:DebugMode()
    return RLSuiteDB and RLSuiteDB.debug == true
end

function RLSuite:InRaid()
    if self:DebugMode() then return true end
    return GetNumRaidMembers() > 0
end

function RLSuite:IsOfficer()
    if self:DebugMode() then return true end
    return (IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())
end

function RLSuite:ApplyDebugMode()
    self:UpdateRaidContext()
    if self:DebugMode() then
        self.utils:Print("|cffff9900DEBUG MODE ON|r — raid simulato, messaggi in whisper a te.")
        if self.lootManager and self.lootManager.SpawnDebugLoot then
            self.lootManager:SpawnDebugLoot()
        end
        if self.raidFrame and self.raidFrame.Rebuild then
            self.raidFrame:Rebuild()
            if self.raidFrame.UpdateAll then self.raidFrame:UpdateAll() end
        end
    else
        self.utils:Print("Debug mode OFF.")
        if self.raidFrame and self.raidFrame.Rebuild then
            self.raidFrame:Rebuild()
        end
    end
    self:UpdatePhaseUI()
end

function RLSuite:UpdateRaidContext()
    local inRaid = self:InRaid()
    local inCombat = UnitAffectingCombat("player")
    if not inRaid then
        self.context = "preraid"
    elseif inCombat then
        self.context = "infight"
    else
        self.context = "preboss"
    end
    self:UpdatePhaseUI()
end

-- Forza la fase dell'addon (preraid / preboss / infight) dai bottoni
-- della barra. Il contesto automatico torna a prevalere al prossimo
-- evento (roster/regen), come prima.
function RLSuite:SetContextPhase(phase)
    if phase ~= "preraid" and phase ~= "preboss" and phase ~= "infight" then return end
    self.context = phase
    self:UpdatePhaseUI()
    self.utils:Print("Fase impostata: " .. phase)
end

-- Sincronizza tutta la UI dipendente dal contesto (barra, MacroBar, keypad).
function RLSuite:UpdatePhaseUI()
    if self.mainWindow and self.mainWindow.UpdatePhaseButtons then
        self.mainWindow:UpdatePhaseButtons()
    end
    if self.macrobar then
        if self.macrobar.UpdatePhase then
            self.macrobar:UpdatePhase()
        end
        if self.macrobar.ShowKeypad then
            self.macrobar:ShowKeypad(self.context == "preboss")
        end
    end
end

-- ============================================================
-- Saved Raids (SaveRaid)
-- Salva: Comp (groupmaking + whisplist), MacroBar e i pannelli di
-- Config esclusa la categoria General (quindi scale delle finestre e
-- impostazioni macrobar/raidframe, non aspetto/font/finestra/debug).
-- ============================================================

local SAVED_RAID_BRANCHES = { "groupmaking", "whisplist", "macrobar", "raidframe" }
local SAVED_RAID_LAYOUT_KEYS = { "groupmaking", "whisplist", "macro", "raidframe", "ms", "loot", "config" }

function RLSuite:SaveRaid(title)
    title = title or ""
    title = string.gsub(title, "^%s+", "")
    title = string.gsub(title, "%s+$", "")
    if title == "" then
        self.utils:Print("Salvataggio annullato: titolo vuoto.")
        return nil
    end
    RLSuiteDB.savedRaids = RLSuiteDB.savedRaids or {}
    if self.groupmaking and self.groupmaking.SaveComp then
        self.groupmaking:SaveComp()
    end
    local data = {}
    for _, k in ipairs(SAVED_RAID_BRANCHES) do
        if RLSuiteDB[k] then
            data[k] = self.utils:CopyTable(RLSuiteDB[k])
        end
    end
    local scales = {}
    for _, k in ipairs(SAVED_RAID_LAYOUT_KEYS) do
        local L = RLSuiteDB.layout and RLSuiteDB.layout[k]
        if L and L.scale then scales[k] = L.scale end
    end
    data.layout = scales
    local id = 1
    for _, e in ipairs(RLSuiteDB.savedRaids) do
        if (e.id or 0) >= id then id = e.id + 1 end
    end
    local entry = { id = id, title = title, time = time(), data = data }
    table.insert(RLSuiteDB.savedRaids, entry)
    self:RefreshSavedRaidsPanel()
    self.utils:Print("SaveRaid \"" .. title .. "\" salvato (" .. #RLSuiteDB.savedRaids .. " totali).")
    return id
end

function RLSuite:RefreshSavedRaidsPanel()
    local cfg = self.config
    if cfg and cfg.frame and cfg.frame:IsShown() and cfg.currentCat == "savedraids"
        and cfg.RebuildPanel then
        cfg:RebuildPanel()
    end
end

function RLSuite:GetSavedRaid(id)
    for _, e in ipairs(RLSuiteDB.savedRaids or {}) do
        if e.id == id then return e end
    end
    return nil
end

function RLSuite:DeleteSavedRaid(id)
    for i, e in ipairs(RLSuiteDB.savedRaids or {}) do
        if e.id == id then
            table.remove(RLSuiteDB.savedRaids, i)
            self:RefreshSavedRaidsPanel()
            self.utils:Print("SaveRaid \"" .. (e.title or "?") .. "\" eliminato.")
            return true
        end
    end
    return false
end

function RLSuite:LoadRaid(id)
    local entry = self:GetSavedRaid(id)
    if not entry then
        self.utils:Print("Salvataggio non trovato (id " .. tostring(id) .. ").")
        return false
    end
    local d = entry.data or {}
    for _, k in ipairs(SAVED_RAID_BRANCHES) do
        if d[k] then
            RLSuiteDB[k] = self.utils:CopyTable(d[k])
        end
    end
    if d.layout then
        RLSuiteDB.layout = RLSuiteDB.layout or {}
        for k, s in pairs(d.layout) do
            if not RLSuiteDB.layout[k] then RLSuiteDB.layout[k] = {} end
            RLSuiteDB.layout[k].scale = s
        end
    end
    self:ApplySavedRaidToUI()
    self.utils:Print("SaveRaid \"" .. (entry.title or "?") .. "\" caricato.")
    return true
end

function RLSuite:ApplySavedRaidToUI()
    -- GroupMaking
    if self.groupmaking then
        local gm = self.groupmaking
        gm.db = RLSuiteDB.groupmaking
        gm.whisperDB = RLSuiteDB.whisplist
        if gm.mainFrame then
            local comp = {}
            if RLSuiteDB.groupmaking and RLSuiteDB.groupmaking.comp then
                for i, c in pairs(RLSuiteDB.groupmaking.comp) do
                    comp[i] = self.utils:CopyTable(c)
                end
            end
            local difficulty = RLSuiteDB.groupmaking and RLSuiteDB.groupmaking.difficulty or "10"
            if gm.SetDifficulty then gm:SetDifficulty(difficulty) end
            for i, c in pairs(comp) do
                if gm.FillSlot then
                    gm:FillSlot(tonumber(i), c.class, c.role, c.playerName, c.spec)
                end
            end
            if RLSuiteDB.groupmaking then
                local reserved = ""
                if type(RLSuiteDB.groupmaking.reservedText) == "string" then
                    reserved = RLSuiteDB.groupmaking.reservedText
                elseif type(RLSuiteDB.groupmaking.reserved) == "string" then
                    reserved = RLSuiteDB.groupmaking.reserved
                end
                if gm.reservedEdit then gm.reservedEdit:SetText(reserved) end
                if gm.otherEdit then gm.otherEdit:SetText(RLSuiteDB.groupmaking.otherReq or "") end
                gm.db.comp = {}
                if gm.SaveComp then gm:SaveComp() end
                if gm.UpdateMessagePreview then gm:UpdateMessagePreview() end
                if gm.PopulateRaidDropdown then gm:PopulateRaidDropdown() end
            end
        end
    end
    -- Whisplist
    if self.groupmaking and self.groupmaking.whisplistFrame and self.groupmaking.whisplistFrame:IsShown() then
        if self.groupmaking.UpdateWhisplist then
            self.groupmaking:UpdateWhisplist()
        end
    end
    -- MacroBar
    if self.macrobar and self.macrobar.frame then
        local mb = self.macrobar
        mb.db = RLSuiteDB.macrobar
        if mb.EnsurePhases then mb:EnsurePhases() end
        if mb.ApplyLayout then mb:ApplyLayout() end
        if mb.UpdatePhase then mb:UpdatePhase() end
    end
    -- Raid Frame
    if self.raidFrame and self.raidFrame.frame then
        local rf = self.raidFrame
        rf.db = RLSuiteDB.raidframe
        if rf.ApplyLayout then rf:ApplyLayout() end
        if rf.Rebuild then rf:Rebuild() end
        if rf.UpdateAll then rf:UpdateAll() end
    end
    -- Macro editor (se visibile)
    if self.mainWindow and self.mainWindow.frame and self.mainWindow.tabPanels
        and self.mainWindow.tabPanels.macro and self.mainWindow.tabPanels.macro:IsShown() then
        local mw = self.mainWindow
        if mw.RefreshMacroTab then mw:RefreshMacroTab() end
        if mw.OpenMacroEditor then
            mw:OpenMacroEditor(mw.macroEditIndex or 1)
        end
    end
    -- Config apply (scale finestre)
    if self.config and self.config.ApplyAll then
        self.config:ApplyAll()
    end
    self:ApplyAnchorMode(RLSuiteDB.anchorMode == true)
end

-- ============================================================
-- Anchors stile ElvUI per le HUD (Raid Frame + MacroBar)
-- ============================================================
function RLSuite:ApplyAnchorMode(on)
    RLSuiteDB.anchorMode = on and true or false
    local u = self.utils
    if self.raidFrame and self.raidFrame.frame then
        u:SetAnchorVisual(self.raidFrame.frame, RLSuiteDB.anchorMode)
        if RLSuiteDB.anchorMode and RLSuiteDB.raidframe and RLSuiteDB.raidframe.enabled ~= false then
            if not self.raidFrame.frame:IsShown() then
                self.raidFrame.frame:Show()
                if self.raidFrame.ApplyLayout then self.raidFrame:ApplyLayout() end
            end
        end
    end
    if self.macrobar and self.macrobar.frame then
        u:SetAnchorVisual(self.macrobar.frame, RLSuiteDB.anchorMode)
        if self.macrobar.SetAnchorMode then
            self.macrobar:SetAnchorMode(RLSuiteDB.anchorMode)
        end
        if RLSuiteDB.anchorMode and RLSuiteDB.macrobar and RLSuiteDB.macrobar.enabled ~= false then
            self.macrobar.frame:Show()
            if self.macrobar.ApplyLayout then self.macrobar:ApplyLayout() end
        end
    end
    if self.config and self.config.frame and self.config.UpdateAnchorCheck then
        self.config:UpdateAnchorCheck()
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
