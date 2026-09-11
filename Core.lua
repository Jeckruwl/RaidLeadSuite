-- ============================================================
-- RLSuite - Core
-- ============================================================

RLSuite = RLSuite or {}
RLSuite.version = "1.4.0"

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")

-- ============================================================
-- Defaults (AceDB-3.0). Everything lives in the shared "profile"
-- section; the database uses the global "Default" profile so the
-- settings stay account-wide exactly like the old flat saved table.
-- ============================================================
local defaults = {
    profile = {
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
        groupmaking = {
            raid = "",
            difficulty = "10",
            hc = false,
            reserved = {},
            reservedText = "",
            aim = "",
            otherReq = "",
            comp = {},
            spamChannels = {"General", "Trade"},
            spamInterval = 60,
            showSpecsInMessage = false,
        },
        whisplist = {
            entries = {},
            autoinvite = {
                mode = "manual",   -- "manual" | "calendar"
                names = "",
                hour = 19,
                minute = 0,
                eventIndex = nil,
                eventTitle = nil,
                eventDay = nil,
                eventCount = 0,
                enabled = false,
            },
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
            font = "Fonts\\FRIZQT__.TTF",
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
    },
}

-- ============================================================
-- AceAddon-3.0 addon object. AceEvent and AceConsole are embedded, so
-- RLSuite gains RegisterEvent / RegisterChatCommand. AceDB-3.0 is not
-- embeddable: it is called directly (AceDB:New) inside OnInitialize.
-- ============================================================
RLSuite = AceAddon:NewAddon(RLSuite, "RLSuite", "AceEvent-3.0", "AceConsole-3.0")

-- One-time migration of the pre-Ace3 flat saved table (RLSuiteDB.* at the
-- root) into the new profile section. Runs before any module touches db.
local function MergeLegacy(dest, src)
    for k, v in pairs(src) do
        if k == "profile" or k == "profiles" or k == "profileKeys" then
            -- legacy/non-data keys, ignored
        elseif type(v) == "table" then
            if type(dest[k]) ~= "table" then dest[k] = {} end
            MergeLegacy(dest[k], v)
        else
            dest[k] = v
        end
    end
end

function RLSuite:OnInitialize()
    -- Detect a legacy flat DB before AceDB restructures the saved table.
    local sv = _G.RLSuiteDB
    local legacy = nil
    if type(sv) == "table" and sv.profileKeys == nil and sv.profiles == nil then
        legacy = sv
    end

    self.db = AceDB:New("RLSuiteDB", defaults, true)

    if legacy then
        MergeLegacy(self.db.profile, legacy)
    end

    -- Folder name is the addon name. Canonical: RaidLeadSuite (RLSuite kept
    -- for backward compatibility). AceAddon stores it on baseName.
    self.addonFolder = self.baseName or "RaidLeadSuite"

    self:RegisterChatCommand("rls", "ChatCommand")
    self:RegisterChatCommand("rlsuite", "ChatCommand")

    self.utils:Print(string.format(L["v%s loaded. Type /rls to open."], RLSuite.version))
end

function RLSuite:OnEnable()
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnRaidRosterUpdate")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerRegenEnabled")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnPlayerRegenDisabled")
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
    self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "OnWhisperInform")
    self:RegisterEvent("CHAT_MSG_RAID", "OnRaidMessage")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnRaidMessage")
    self:RegisterEvent("CHAT_MSG_LOOT", "OnLootMessage")
    self:InitModules()
end

function RLSuite:OnDisable()
    self:UnregisterAllEvents()
end

-- ============================================================
-- AceEvent-3.0 handlers (previously a single raw event frame)
-- ============================================================
function RLSuite:OnRaidRosterUpdate()
    self:UpdateRaidContext()
end

function RLSuite:OnPlayerRegenEnabled()
    self.context = "preboss"
    self:UpdatePhaseUI()
end

function RLSuite:OnPlayerRegenDisabled()
    self.context = "infight"
    self:UpdatePhaseUI()
end

function RLSuite:OnWhisper(event, msg, sender)
    if self.groupmaking and self.groupmaking.OnWhisper then
        self.groupmaking:OnWhisper(sender, msg)
    end
    self:HandleDebugMSWhisper(sender, msg)
end

function RLSuite:OnWhisperInform(event, msg, target)
    self:HandleDebugMSWhisper(UnitName("player") or target, msg)
end

function RLSuite:OnRaidMessage(event, msg, sender)
    if self.msManager and self.msManager.ParseMSMessage then
        self.msManager:ParseMSMessage(sender, msg)
    end
end

function RLSuite:OnLootMessage(event, msg)
    if self.lootManager and self.lootManager.OnLootMessage then
        self.lootManager:OnLootMessage(msg)
    end
end

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

-- Reverse lookup: ability name -> list of spell IDs. GetSpellCooldown(spellId)
-- is locale-safe (the name form requires the spell to be in the player's
-- spellbook), so the player's own cooldowns are queried by ID.
RLSuite.abilitySpellIdByName = {}
for spellId, name in pairs(RLSuite.abilityBySpellId) do
    local list = RLSuite.abilitySpellIdByName[name]
    if not list then
        list = {}
        RLSuite.abilitySpellIdByName[name] = list
    end
    table.insert(list, spellId)
end

-- WotLK 3.3.5 buff/flask/food checks by spellId (locale-safe). Names are
-- resolved at runtime via GetSpellInfo(id) and UnitBuff compares the
-- returned spellId. Food buffs are the "Well Fed" family (one spell per
-- food); feasts apply one of these.
RLSuite.buffData = {
    flask = {
        53755, -- Flask of the Frost Wyrm
        53760, -- Flask of Endless Rage
        54212, -- Flask of Pure Mojo
        53758, -- Flask of Stoneblood
        67016, -- Flask of the North (Spell Power)
        67017, -- Flask of the North (Attack Power)
        67018, -- Flask of the North (Strength)
    },
    food = {
        57079, -- Well Fed (60 AP, 40 Stam)
        57097, -- Well Fed (35 SP, 40 Stam)
        57111, -- Well Fed (60 AP, 30 Stam)
        57139, -- Well Fed (35 SP, 30 Stam)
        57294, -- Well Fed (Great Feast: 60 AP, 35 SP, 30 Stam)
        57325, -- Well Fed (Mega Mammoth Meal: 80 AP, 40 Stam)
        57327, -- Well Fed (Tender Shoveltusk Steak: 46 SP, 40 Stam)
        57399, -- Well Fed (Fish Feast: 80 AP, 46 SP, 40 Stam)
        64057, -- Well Fed (Spiced Worm Burger)
        65412, -- Well Fed
        65414, -- Well Fed
        66623, -- Well Fed
    },
    buffs = {
        48469, -- Mark of the Wild
        48470, -- Gift of the Wild
        48161, -- Power Word: Fortitude
        48162, -- Prayer of Fortitude
        43002, -- Arcane Brilliance
        42995, -- Arcane Intellect
        20217, -- Blessing of Kings
        25898, -- Greater Blessing of Kings
        48932, -- Blessing of Might
        48934, -- Greater Blessing of Might
        48936, -- Blessing of Wisdom
        48938, -- Greater Blessing of Wisdom
    },
}

-- (Events, slash commands, database setup and module init are now handled
--  by AceAddon-3.0 / AceEvent-3.0 / AceConsole-3.0 / AceDB-3.0 above.)

function RLSuite:PrintHelp()
    local p = function(t) self.utils:Print(t) end
    p(L["Available commands:"])
    p(L["  /rls              Tab bar"])
    p(L["  /rls help         This list"])
    p(L["  /rls group        Groupmaking tab"])
    p(L["  /rls inviteengine InviteEngine panel (whisper + auto-invite)"])
    p(L["  /rls whisplist    InviteEngine panel (alias)"])
    p(L["  /rls macro        Config -> Macros (editor)"])
    p(L["  /rls macrobar     HUD MacroBar"])
    p(L["  /rls raidframe    Raid Frame tab (settings)"])
    p(L["  /rls rfhud        HUD Raid Frame"])
    p(L["  /rls ms           MS Manager tab"])
    p(L["  /rls loot         Loot Manager tab"])
    p(L["  /rls config       Config window"])
end

function RLSuite:ChatCommand(input)
    local msg = string.gsub(string.gsub(input or "", "^%s+", ""), "%s+$", "")
    msg = string.lower(msg)
    if msg == "help" or msg == "?" then
        self:PrintHelp()
    elseif msg == "macrobar" then
        if self.macrobar then self.macrobar:Toggle() end
    elseif msg == "rfhud" then
        if self.raidFrame then self.raidFrame:Toggle() end
    elseif msg == "group" then
        if self.mainWindow then self.mainWindow:ShowTab("group") end
    elseif msg == "whisplist" or msg == "wl" or msg == "inviteengine" or msg == "ie" then
        if self.mainWindow then self.mainWindow:ShowTab("group") end
        if self.groupmaking and self.groupmaking.OpenWhisplist then
            self.groupmaking:OpenWhisplist()
        end
    elseif msg == "macro" then
        if self.config and self.config.OpenMacroEditorPanel then
            self.config:OpenMacroEditorPanel()
        end
    elseif msg == "raidframe" or msg == "rf" then
        if self.mainWindow then self.mainWindow:ShowTab("raidframe") end
    elseif msg == "ms" then
        if self.mainWindow then self.mainWindow:ShowTab("ms") end
    elseif msg == "loot" then
        if self.mainWindow then self.mainWindow:ShowTab("loot") end
    elseif msg == "config" then
        if self.config then self.config:Toggle() end
    elseif msg == "" then
        if self.mainWindow then self.mainWindow:Toggle() end
    else
        self.utils:Print(L["Unknown command. Type /rls help for the list."])
        self:PrintHelp()
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
    return self.db and self.db.profile.debug == true
end

-- ============================================================
-- DEBUG MODE: simulated raid roster.
-- In debug mode the real raid API returns nothing, so the addon keeps
-- its own roster here. The player is always present; fake players join
-- when they are "invited" (whisper list, comp slot or autoinviter).
-- Both the Raid Group panel (GroupMaking) and the Raid Frame read from
-- this table in debug mode, so an accepted fake invite updates the UI
-- exactly like a real invite would.
-- ============================================================
function RLSuite:DebugRoster()
    if not self.debugRaid then self:ResetDebugRaid() end
    return self.debugRaid.members
end

function RLSuite:ResetDebugRaid()
    local me = UnitName("player") or "Player"
    local myClass = select(2, UnitClass("player")) or "WARRIOR"
    self.debugRaid = {
        members = {
            { name = me, class = myClass, isPlayer = true, subgroup = 1 },
        },
    }
end

-- A fake player accepts the invite: add them to the simulated roster and
-- refresh every UI that reads it (Raid Group panel + Raid Frame).
function RLSuite:DebugInviteAccept(name, class, subgroup)
    if not name or name == "" then return nil end
    local roster = self:DebugRoster()
    for _, m in ipairs(roster) do
        if m.name == name then
            return m
        end
    end
    local member = {
        name = name,
        class = class or "WARRIOR",
        isPlayer = false,
        subgroup = subgroup or ((#roster % 5) + 1),
    }
    table.insert(roster, member)
    self:DebugRosterChanged()
    return member
end

-- Rebalance subgroups 1..ngroups round-robin after the roster changes, so
-- the Raid Group columns fill evenly like a real raid assistant would.
function RLSuite:DebugRebalanceGroups(ngroups)
    local roster = self:DebugRoster()
    ngroups = tonumber(ngroups) or math.ceil(#roster / 5)
    if ngroups < 2 then ngroups = 2 end
    if ngroups > 5 then ngroups = 5 end
    for i, m in ipairs(roster) do
        m.subgroup = ((i - 1) % ngroups) + 1
    end
end

-- Called whenever the simulated roster changes (invite accepted, debug
-- toggled, ...). Refreshes the Raid Group panel and the Raid Frame. Every
-- refresh is protected: an error in one UI must NEVER block the other (the
-- "raid group stays empty after a debug invite" bug happened because a
-- RaidFrame failure could abort before the Raid Group update ran).
function RLSuite:DebugRosterChanged()
    -- Raid Group (InviteEngine) per primo: e' il pannello che l'utente guarda.
    if self.groupmaking and self.groupmaking.UpdateWLGroups then
        local ok, err = pcall(self.groupmaking.UpdateWLGroups, self.groupmaking)
        if not ok and self.utils and self.utils.Debug then
            self.utils:Debug("UpdateWLGroups error: " .. tostring(err))
        end
    end
    if self.raidFrame then
        if self.raidFrame.Rebuild then
            local ok, err = pcall(self.raidFrame.Rebuild, self.raidFrame)
            if not ok and self.utils and self.utils.Debug then
                self.utils:Debug("RaidFrame Rebuild error: " .. tostring(err))
            end
        end
        if self.raidFrame.UpdateAll then
            pcall(self.raidFrame.UpdateAll, self.raidFrame)
        end
    end
end

-- Percorso di una risorsa dentro la cartella dell'addon, usando il nome
-- cartella reale (RLSuite o RaidLeadSuite a seconda di come e' installato).
function RLSuite:AddonTexture(rel)
    local folder = self.addonFolder or "RaidLeadSuite"
    return "Interface\\AddOns\\" .. folder .. "\\" .. rel
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
    -- The simulated roster always restarts from just the player when debug
    -- mode is toggled, so stale fake members never leak between sessions.
    self.debugRaid = nil
    if self:DebugMode() then
        self.utils:Print("|cffff9900" .. L["DEBUG MODE ON"] .. "|r - " .. L["Simulated raid, messages are whispered to you."])
        if self.lootManager and self.lootManager.SpawnDebugLoot then
            self.lootManager:SpawnDebugLoot()
        end
    else
        self.utils:Print("Debug mode OFF.")
    end
    -- Rinfresca TUTTE le UI che leggono il roster (Raid Group + Raid Frame):
    -- in debug si parte dal solo giocatore, fuori dal debug si torna al
    -- raid reale. Prima non veniva aggiornato il pannello Raid Group, che
    -- restava vuoto finche' non arrivava il primo invito.
    self:DebugRosterChanged()
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
    self.utils:Print(string.format(L["Phase set: %s"], phase))
end

-- Cicla preraid -> preboss -> infight -> preraid (usato dall'icona fase).
-- dir =  1 -> fase successiva (clic sinistro)
-- dir = -1 -> fase precedente   (clic destro)
function RLSuite:CycleContextPhase(dir)
    local order = { "preraid", "preboss", "infight" }
    local cur = self.context or "preraid"
    local idx
    for i, k in ipairs(order) do
        if k == cur then idx = i break end
    end
    idx = idx or 1
    if dir and dir < 0 then
        idx = ((idx - 2) % 3) + 1
    else
        idx = (idx % 3) + 1
    end
    self:SetContextPhase(order[idx])
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
        if self.macrobar.UpdateKeypad then
            self.macrobar:UpdateKeypad(self.context)
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
local SAVED_RAID_LAYOUT_KEYS = { "groupmaking", "raidframe", "ms", "loot", "config" }

function RLSuite:SaveRaid(title)
    title = title or ""
    title = string.gsub(title, "^%s+", "")
    title = string.gsub(title, "%s+$", "")
    if title == "" then
        self.utils:Print(L["Save cancelled: empty title."])
        return nil
    end
    self.db.profile.savedRaids = self.db.profile.savedRaids or {}
    if self.groupmaking and self.groupmaking.SaveComp then
        self.groupmaking:SaveComp()
    end
    local data = {}
    for _, k in ipairs(SAVED_RAID_BRANCHES) do
        if self.db.profile[k] then
            data[k] = self.utils:CopyTable(self.db.profile[k])
        end
    end
    local scales = {}
    for _, k in ipairs(SAVED_RAID_LAYOUT_KEYS) do
        local lay = self.db.profile.layout and self.db.profile.layout[k]
        if lay and lay.scale then scales[k] = lay.scale end
    end
    data.layout = scales
    local id = 1
    for _, e in ipairs(self.db.profile.savedRaids) do
        if (e.id or 0) >= id then id = e.id + 1 end
    end
    local entry = { id = id, title = title, time = time(), data = data }
    table.insert(self.db.profile.savedRaids, entry)
    self:RefreshSavedRaidsPanel()
    self.utils:Print(string.format(L['SaveRaid "%s" saved (%d total).'], title, #self.db.profile.savedRaids))
    return id
end

function RLSuite:RefreshSavedRaidsPanel()
    local cfg = self.config
    if cfg and cfg.IsOpen and cfg:IsOpen() and cfg.NotifyChange then
        cfg:NotifyChange()
    end
end

function RLSuite:GetSavedRaid(id)
    for _, e in ipairs(self.db.profile.savedRaids or {}) do
        if e.id == id then return e end
    end
    return nil
end

function RLSuite:DeleteSavedRaid(id)
    for i, e in ipairs(self.db.profile.savedRaids or {}) do
        if e.id == id then
            table.remove(self.db.profile.savedRaids, i)
            self:RefreshSavedRaidsPanel()
            self.utils:Print(string.format(L['SaveRaid "%s" deleted.'], (e.title or "?")))
            return true
        end
    end
    return false
end

function RLSuite:LoadRaid(id)
    local entry = self:GetSavedRaid(id)
    if not entry then
        self.utils:Print(string.format(L["Save not found (id %s)."], tostring(id)))
        return false
    end
    local d = entry.data or {}
    for _, k in ipairs(SAVED_RAID_BRANCHES) do
        if d[k] then
            self.db.profile[k] = self.utils:CopyTable(d[k])
        end
    end
    if d.layout then
        self.db.profile.layout = self.db.profile.layout or {}
        for k, s in pairs(d.layout) do
            if not self.db.profile.layout[k] then self.db.profile.layout[k] = {} end
            self.db.profile.layout[k].scale = s
        end
    end
    self:ApplySavedRaidToUI()
    self.utils:Print(string.format(L['SaveRaid "%s" loaded.'], (entry.title or "?")))
    return true
end

function RLSuite:ApplySavedRaidToUI()
    -- GroupMaking
    if self.groupmaking then
        local gm = self.groupmaking
        gm.db = self.db.profile.groupmaking
        gm.whisperDB = self.db.profile.whisplist
        if gm.mainFrame then
            local comp = {}
            if self.db.profile.groupmaking and self.db.profile.groupmaking.comp then
                for i, c in pairs(self.db.profile.groupmaking.comp) do
                    comp[i] = self.utils:CopyTable(c)
                end
            end
            local difficulty = self.db.profile.groupmaking and self.db.profile.groupmaking.difficulty or "10"
            if gm.SetDifficulty then gm:SetDifficulty(difficulty) end
            for i, c in pairs(comp) do
                if gm.FillSlot then
                    gm:FillSlot(tonumber(i), c.class, c.role, c.playerName, c.spec)
                end
            end
            if self.db.profile.groupmaking then
                local reserved = ""
                if type(self.db.profile.groupmaking.reservedText) == "string" then
                    reserved = self.db.profile.groupmaking.reservedText
                elseif type(self.db.profile.groupmaking.reserved) == "string" then
                    reserved = self.db.profile.groupmaking.reserved
                end
                if gm.reservedEdit then gm.reservedEdit:SetText(reserved) end
                if gm.aimEdit then gm.aimEdit:SetText(self.db.profile.groupmaking.aim or "") end
                if gm.otherEdit then gm.otherEdit:SetText(self.db.profile.groupmaking.otherReq or "") end
                gm.db.comp = {}
                if gm.SaveComp then gm:SaveComp() end
                if gm.UpdateMessagePreview then gm:UpdateMessagePreview() end
                if gm.PopulateRaidDropdown then gm:PopulateRaidDropdown() end
            end
        end
    end
    -- InviteEngine (ex-Whisplist)
    if self.groupmaking and self.groupmaking.whisplistFrame and self.groupmaking.whisplistFrame:IsShown() then
        if self.groupmaking.UpdateWhisplist then
            self.groupmaking:UpdateWhisplist()
        end
        if self.groupmaking.ieActiveTab == "auto" and self.groupmaking.RefreshAutoinviter then
            self.groupmaking:RefreshAutoinviter()
        end
    end
    -- MacroBar
    if self.macrobar and self.macrobar.frame then
        local mb = self.macrobar
        mb.db = self.db.profile.macrobar
        if mb.EnsurePhases then mb:EnsurePhases() end
        if mb.ApplyLayout then mb:ApplyLayout() end
        if mb.UpdatePhase then mb:UpdatePhase() end
    end
    -- Raid Frame
    if self.raidFrame and self.raidFrame.frame then
        local rf = self.raidFrame
        rf.db = self.db.profile.raidframe
        if rf.ApplyLayout then rf:ApplyLayout() end
        if rf.Rebuild then rf:Rebuild() end
        if rf.UpdateAll then rf:UpdateAll() end
    end
    -- Macro editor (se visibile)
    if self.config and self.config.RefreshMacroTab and self.config.macroEditorPanel
        and self.config.macroEditorPanel:IsShown() then
        self.config:RefreshMacroTab()
        if self.config.OpenMacroEditor then
            self.config:OpenMacroEditor(self.config.macroEditIndex or 1)
        end
    end
    -- Config apply (scale finestre)
    if self.config and self.config.ApplyAll then
        self.config:ApplyAll()
    end
    -- dopo un load le finestre non devono restare sotto il minimo di contenuto
    local u = self.utils
    if u and u.EnforceWindowMin then
        u:EnforceWindowMin(self.groupmaking and self.groupmaking.mainFrame, "groupmaking")
        u:EnforceWindowMin(self.msManager and self.msManager.frame, "ms")
        u:EnforceWindowMin(self.lootManager and self.lootManager.frame, "loot")
    end
    self:ApplyAnchorMode(self.db.profile.anchorMode == true)
end

-- ============================================================
-- Anchors stile ElvUI per le HUD (Raid Frame + MacroBar)
-- ============================================================
function RLSuite:ApplyAnchorMode(on)
    self.db.profile.anchorMode = on and true or false
    local u = self.utils
    if self.raidFrame and self.raidFrame.frame then
        u:SetAnchorVisual(self.raidFrame.frame, self.db.profile.anchorMode)
        if self.db.profile.anchorMode and self.db.profile.raidframe and self.db.profile.raidframe.enabled ~= false then
            if not self.raidFrame.frame:IsShown() then
                self.raidFrame.frame:Show()
                if self.raidFrame.ApplyLayout then self.raidFrame:ApplyLayout() end
            end
        end
    end
    if self.macrobar and self.macrobar.frame then
        u:SetAnchorVisual(self.macrobar.frame, self.db.profile.anchorMode)
        if self.macrobar.SetAnchorMode then
            self.macrobar:SetAnchorMode(self.db.profile.anchorMode)
        end
        if self.db.profile.anchorMode and self.db.profile.macrobar and self.db.profile.macrobar.enabled ~= false then
            self.macrobar.frame:Show()
            if self.macrobar.ApplyLayout then self.macrobar:ApplyLayout() end
        end
    end
    if self.config and self.config.UpdateAnchorCheck then
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
        self.config:ApplyTheme(self.db.profile.appearance and self.db.profile.appearance.theme)
    end
    if self.utils and self.utils.SkinAllWindows then
        self.utils:SkinAllWindows()
    end
    self:UpdateRaidContext()
    -- Se il debug era gia' attivo al login (flag salvato nelle SavedVariables
    -- e /reload), il roster simulato parte e le UI che lo leggono (Raid Group
    -- + Raid Frame) vengono subito allineate, senza aspettare un invito.
    if self:DebugMode() then
        self:DebugRosterChanged()
    end
end
