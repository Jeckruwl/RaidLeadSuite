-- ============================================================
-- RLSuite - Core
-- ============================================================

RLSuite = RLSuite or {}
RLSuite.version = "1.10.6"

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
            width = 380,
            height = 400,
            point = "LEFT",
            relPoint = "LEFT",
            x = 10,
            y = 0,
            alpha = 1.0,            -- overall HUD transparency
            appearance = {
                barWidth = 180,
                iconSize = 16,
                nameFontSize = 11,
                iconSpacing = 8,        -- gap tra le icone della matrice Raid Buffs
                rowSpacing = 0,         -- gap tra le barre dentro i gruppi
                groupSpacing = 8,       -- gap tra i gruppi
                groupHeaderFontSize = 10,
                matrixBackdrop = { r = 0.5, g = 0.5, b = 0.5, a = 0.35 },
                fontColor = { r = 1, g = 1, b = 1, a = 1 },
                border = true,
                font = "Fonts\\FRIZQT__.TTF",
                fontOutline = true,
                barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
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
            filters = { recipes = false, boe = false, gems = false, shards = false },
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
        minimap = {
            angle = 220,
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
LibStub("AceTimer-3.0"):Embed(RLSuite)

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
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:InitModules()
    self:EnsureMinimapIcon()
end

-- La minimappa (frame globale "Minimap") non sempre esiste gia' al
-- PLAYER_LOGIN (dipende dal client e dagli addon di minimappa caricati):
-- riproviamo qui e, se serve, con un timer (vedi EnsureMinimapIcon).
function RLSuite:OnPlayerEnteringWorld()
    self:EnsureMinimapIcon()
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

-- ============================================================
-- Raid buff/debuff "coverage" checks for the Raid Frame HUD.
-- Each entry describes a category the raid leader wants covered:
--   key      unique id (used for tooltips/logic)
--   label    short label shown in the alert bars / ability bar
--   icon     texture path
--   classes  provider classes (drives the vertical ability bar: the
--            button only appears when one of these classes is in the
--            raid composition)
--   spells   spellIds to look for (aura present if ANY is found on a
--            raid member, or on the boss for debuffs). Faction variations
--            are covered by listing both faction spell IDs in the same
--            list (e.g. Bloodlust 2825 + Heroism 32182 for "Haste").
--   onlyWithClass (optional) for the alert bar: hide the entry entirely
--            unless at least one provider class is in the comp
-- Checks are locale-safe: spellIds resolve to names via GetSpellInfo and
-- the aura's returned spellId is compared (see RaidFrame.lua).
-- ============================================================

-- ============================================================
-- RAID BUFF MATRIX COLUMNS (pannello "Raid Buffs" a scomparsa del Raid Frame)
-- 21 categorie di buff: colonne della tabella; le righe sono i giocatori.
-- Per ogni cella si scansionano le aure del player (UnitBuff per indice) e
-- si mostra l'icona della spell che copre la categoria. Campi:
--   label          nome sintetico (header colonna)
--   icon           icona di fallback (anche icona fissa per byNameSpell)
--   spells         lista spellId che coprono la categoria (match per id)
--   classes        classi che possono fornirla (solo informativa)
--   byNameSpell    se presente: match per NOME aura (nome risolto via
--                  GetSpellInfo(byNameSpell) => locale-safe, copre tutte le
--                  varianti della stessa aura, es. "Well Fed" di ogni cibo)
-- ============================================================
RLSuite.raidBuffColumns = {
        { key = "stats",       label = "%stat",   icon = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
      classes = { "PALADIN" }, spells = { 20217, 25898, 20911 } },
    { key = "mp5",         label = "MP5",     icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom",
      classes = { "PALADIN", "SHAMAN" }, spells = { 48936, 48938, 58774 } },
        { key = "atkpower",    label = "ATK",     icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
      classes = { "PALADIN", "WARRIOR", "HUNTER" }, spells = { 48932, 48934, 47436 } },
    { key = "hp",          label = "HP",      icon = "Interface\\Icons\\Ability_Warrior_RallyingCry",
      classes = { "WARRIOR", "WARLOCK" }, spells = { 47440, 27267, 47982 } },
        { key = "spirit",      label = "Spirit",  icon = "Interface\\Icons\\Spell_Holy_DivineSpirit",
      classes = { "PRIEST", "WARLOCK" }, spells = { 48073, 48075, 57567 } },
    { key = "stamina",     label = "Stamina", icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
      classes = { "PRIEST" }, spells = { 48161, 48162 } },
        { key = "intellect",   label = "Int",     icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
      classes = { "MAGE", "WARLOCK" }, spells = { 42995, 43002, 61316, 57567 } },
    { key = "armor",       label = "Armor",   icon = "Interface\\Icons\\Spell_Holy_DevotionAura",
      classes = { "PALADIN", "DRUID" }, spells = { 48942, 48941, 48470 } },
    { key = "wild",        label = "Gift",    icon = "Interface\\Icons\\Spell_Nature_Regeneration",
      classes = { "DRUID" }, spells = { 21849, 21850, 48470 } },
    { key = "strAgi",      label = "S+Agi",   icon = "Interface\\Icons\\Spell_Nature_Strength",
      classes = { "DEATHKNIGHT", "SHAMAN" }, spells = { 57330, 58643 } },
    { key = "focusMagic",  label = "FM",      icon = "Interface\\Icons\\Spell_Arcane_FocusedPower",
      classes = { "MAGE" }, spells = { 54646 } },
        { key = "haste",       label = "Haste",   icon = "Interface\\Icons\\Ability_Druid_ImprovedMoonkinForm",
      classes = { "DRUID", "PALADIN" }, spells = { 24907, 53648 } },
    { key = "spellCrit",   label = "SpC",     icon = "Interface\\Icons\\Spell_Nature_MoonGlow",
      classes = { "DRUID", "SHAMAN" }, spells = { 24907, 51470 } },
    { key = "shadow",      label = "ShProt",  icon = "Interface\\Icons\\Spell_Shadow_AntiShadow",
      classes = { "PRIEST" }, spells = { 48169, 48170 } },
    { key = "retAura",     label = "Ret",     icon = "Interface\\Icons\\Spell_Holy_AuraMastery",
      classes = { "PALADIN" }, spells = { 54043, 54044 } },
        { key = "meleeCrit",   label = "MCrit",   icon = "Interface\\Icons\\Ability_CriticalStrike",
      classes = { "DRUID", "WARRIOR" }, spells = { 17007, 24932, 29801 } },
        { key = "meleeHaste",  label = "MHaste",  icon = "Interface\\Icons\\Spell_Nature_Windfury",
      classes = { "SHAMAN", "DEATHKNIGHT" }, spells = { 55610, 8512, 8515, 8516 } },
        { key = "spellPower",  label = "SPow",    icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
      classes = { "WARLOCK", "SHAMAN" }, spells = { 47240, 30706, 58656 } },
        { key = "damage",      label = "Dmg%",    icon = "Interface\\Icons\\Ability_Hunter_FerociousInspiration",
      classes = { "HUNTER", "PALADIN", "MAGE" }, spells = { 31583, 34460, 31869 } },
    -- Nuove categorie allineate a Icy Veins WotLK Raid Buffs guide:
    { key = "apIncrease",  label = "AP%",     icon = "Interface\\Icons\\Ability_TrueShot",
      classes = { "HUNTER", "SHAMAN", "DEATHKNIGHT" }, spells = { 19506, 30809, 53138 } },
    { key = "dmgReduction", label = "DR%",    icon = "Interface\\Icons\\Spell_Nature_LightningShield",
      classes = { "PALADIN", "PRIEST" }, spells = { 20911, 57472, 57479 } },
    { key = "healReceived", label = "Heal+",  icon = "Interface\\Icons\\Ability_Druid_TreeofLife",
      classes = { "DRUID", "PALADIN" }, spells = { 34123 } }, -- Tree of Life aura (Improved Devotion non lascia aura propria)
    { key = "physReduction", label = "Armor+", icon = "Interface\\Icons\\Spell_Nature_UndyingStrength",
      classes = { "SHAMAN", "PRIEST" }, spells = { 16240, 16239, 16236, 16235, 16176, 15363, 15359, 15358, 15277 } },
    { key = "replen",      label = "Repl",    icon = "Interface\\Icons\\Ability_Warlock_ImprovedSoulLeech",
      classes = { "MAGE", "HUNTER", "WARLOCK", "PALADIN", "PRIEST" }, spells = { 44561, 53292, 54118, 31878, 34914 } },
    { key = "spellHaste",  label = "SpH",     icon = "Interface\\Icons\\Spell_Nature_SlowingTotem",
      classes = { "SHAMAN" }, spells = { 3738 } },
    { key = "flask",       label = "Flask",   icon = "Interface\\Icons\\INV_Alchemy_EndlessFlask_05",
      classes = {}, spells = { 53755, 53760, 54212, 53758, 67016, 67017, 67018 } },
    { key = "wellfed",     label = "Food",    icon = "Interface\\Icons\\Spell_Misc_Food",
      classes = {}, byNameSpell = 57399 },
}

RLSuite.raidBuffChecks = {
        { key = "stats",       label = "%stat",   icon = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
      classes = { "PALADIN" }, spells = { 20217, 25898, 20911 } },
    { key = "mp5",         label = "MP5",      icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom",
      classes = { "PALADIN", "SHAMAN" }, spells = { 48936, 48938, 58774 } },
        { key = "atkpower",    label = "ATK",     icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
      classes = { "PALADIN", "WARRIOR", "HUNTER" }, spells = { 48932, 48934, 47436 } },
    { key = "hp",          label = "HP",       icon = "Interface\\Icons\\Ability_Warrior_RallyingCry",
      classes = { "WARRIOR", "WARLOCK" }, spells = { 47440, 27267, 47982 } },
        { key = "spirit",      label = "Spirit",  icon = "Interface\\Icons\\Spell_Holy_DivineSpirit",
      classes = { "PRIEST", "WARLOCK" }, spells = { 48073, 48075, 57567 } },
    { key = "stamina",     label = "Stamina",  icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
      classes = { "PRIEST" }, spells = { 48161, 48162 } },
        { key = "intellect",   label = "Int",     icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
      classes = { "MAGE", "WARLOCK" }, spells = { 42995, 43002, 61316, 57567 } },
    { key = "armor",       label = "Armor",    icon = "Interface\\Icons\\Spell_Holy_DevotionAura",
      classes = { "PALADIN", "DRUID" }, spells = { 48942, 48941, 48470 } },
    { key = "wild",        label = "Gift",     icon = "Interface\\Icons\\Spell_Nature_Regeneration",
      classes = { "DRUID" }, spells = { 21849, 21850, 48470 } },
    { key = "strAgi",      label = "Str+Agi",  icon = "Interface\\Icons\\Spell_Nature_Strength",
      classes = { "DEATHKNIGHT", "SHAMAN" }, spells = { 57330, 58643 } },
    { key = "focusMagic",  label = "Focus Magic", icon = "Interface\\Icons\\Spell_Arcane_FocusedPower",
      classes = { "MAGE" }, onlyWithClass = true, spells = { 54646 } },
    -- Beyond-request 3.3.5 additions -------------------------------------
        { key = "haste",       label = "Haste",   icon = "Interface\\Icons\\Ability_Druid_ImprovedMoonkinForm",
      classes = { "DRUID", "PALADIN" }, spells = { 24907, 53648 } },
    { key = "spellCrit",   label = "Spell crit", icon = "Interface\\Icons\\Spell_Nature_MoonGlow",
      classes = { "DRUID", "SHAMAN" }, spells = { 24907, 51470 } },
    { key = "shadow",      label = "Shadow Prot", icon = "Interface\\Icons\\Spell_Shadow_AntiShadow",
      classes = { "PRIEST" }, spells = { 48169, 48170 } },
    { key = "retAura",     label = "Ret Aura", icon = "Interface\\Icons\\Spell_Holy_AuraMastery",
      classes = { "PALADIN" }, spells = { 54043, 54044 } },
    { key = "meleeCrit",   label = "Melee crit", icon = "Interface\\Icons\\Ability_CriticalStrike",
      classes = { "DRUID", "WARRIOR" }, spells = { 17007, 24932, 29801 } },
    { key = "meleeHaste",  label = "Melee haste", icon = "Interface\\Icons\\Spell_Nature_Windfury",
      classes = { "SHAMAN", "DEATHKNIGHT" }, spells = { 55610, 8512, 8515, 8516 } },
    { key = "spellPower",  label = "Spell power", icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
      classes = { "WARLOCK", "SHAMAN" }, spells = { 47240, 30706, 58656 } },
    { key = "damage",      label = "Damage %", icon = "Interface\\Icons\\Ability_Hunter_FerociousInspiration",
      classes = { "HUNTER", "PALADIN", "MAGE" }, spells = { 31583, 34460, 31869 } },
    { key = "apIncrease",  label = "Atk power %", icon = "Interface\\Icons\\Ability_TrueShot",
      classes = { "HUNTER", "SHAMAN", "DEATHKNIGHT" }, spells = { 19506, 30809, 53138 } },
    { key = "dmgReduction", label = "Dmg reduction", icon = "Interface\\Icons\\Spell_Nature_LightningShield",
      classes = { "PALADIN", "PRIEST" }, spells = { 20911, 57472, 57479 } },
    { key = "healReceived", label = "Healing rec.", icon = "Interface\\Icons\\Ability_Druid_TreeofLife",
      classes = { "DRUID", "PALADIN" }, spells = { 34123 } },
    { key = "physReduction", label = "Phys red.", icon = "Interface\\Icons\\Spell_Nature_UndyingStrength",
      classes = { "SHAMAN", "PRIEST" }, spells = { 16240, 16239, 16236, 16235, 16176, 15363, 15359, 15358, 15277 } },
    { key = "replen",      label = "Replenishment", icon = "Interface\\Icons\\Ability_Warlock_ImprovedSoulLeech",
      classes = { "MAGE", "HUNTER", "WARLOCK", "PALADIN", "PRIEST" }, spells = { 44561, 53292, 54118, 31878, 34914 } },
    { key = "spellHaste",  label = "Spell haste", icon = "Interface\\Icons\\Spell_Nature_SlowingTotem",
      classes = { "SHAMAN" }, spells = { 3738 } },
}

RLSuite.raidDebuffChecks = {
    { key = "magicTaken",   label = "%magic",   icon = "Interface\\Icons\\Spell_Nature_FaerieFire",
      classes = { "DRUID", "WARLOCK", "DEATHKNIGHT", "HUNTER", "PALADIN" },
      spells = { 770, 778, 9749, 9907, 26993, 16857, 17390, 17391, 17392, 27002,
                 47865, 51161, 51735, 60431, 60432, 60433 } },
    { key = "physicalTaken", label = "%physical", icon = "Interface\\Icons\\Ability_Warrior_BloodFrenzy",
      classes = { "ROGUE", "WARRIOR" }, spells = { 51682, 51683, 29859, 29860 } },
    { key = "critTaken",    label = "%crit",    icon = "Interface\\Icons\\Spell_Holy_CrusaderStrike",
      classes = { "PALADIN", "ROGUE", "SHAMAN" },
      spells = { 20335, 20336, 20337, 58410, 58411, 30706, 57720, 57721, 57722 } },
    { key = "armorReduction", label = "Armor",  icon = "Interface\\Icons\\Ability_Warrior_Sunder",
      classes = { "WARRIOR", "ROGUE", "DRUID", "HUNTER" },
      spells = { 7386, 47467, 8647, 48660, 770, 16857, 64382, 55749 } },
    { key = "bleedTaken",   label = "%bleed",   icon = "Interface\\Icons\\Ability_Druid_Mangle",
      classes = { "DRUID", "WARRIOR" }, spells = { 48564, 48566, 46855, 46856 } },
    -- Beyond-request 3.3.5 addition --------------------------------------
    { key = "spellHit",     label = "%spell hit", icon = "Interface\\Icons\\Spell_Shadow_MindRot",
      classes = { "PRIEST", "DRUID" }, spells = { 33191, 33192, 33193, 33600, 33601, 33602 } },
    { key = "apReduction",  label = "AP red",   icon = "Interface\\Icons\\Ability_Warrior_WarCry",
      classes = { "WARLOCK", "DRUID", "WARRIOR", "PALADIN" },
      spells = { 50511, 47437, 48560, 26016 } },
    { key = "attackSpeedReduction", label = "Spd red", icon = "Interface\\Icons\\Spell_Nature_ThunderClap",
      classes = { "DEATHKNIGHT", "DRUID", "PALADIN", "WARRIOR" },
      spells = { 47502, 49909, 51456, 48485, 53696 } },
    { key = "castSpeedReduction", label = "Cast red", icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
      classes = { "WARLOCK", "HUNTER", "ROGUE", "MAGE" },
      spells = { 11719, 12891, 31589, 58611 } },
    { key = "healingReduction", label = "Wound",    icon = "Interface\\Icons\\Ability_Warrior_SavageBlow",
      classes = { "WARRIOR", "ROGUE", "HUNTER", "WARLOCK" },
      spells = { 23132, 40599, 12294, 54680 } },

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
    p(L["  /rls raidframe    Raid Frame HUD"])
    p(L["  /rls rfhud        Raid Frame HUD (alias)"])
    p(L["  /rls ms           MS Manager tab"])
    p(L["  /rls debugbuff    Diagnose Raid Buffs header icons"])
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
        if self.raidFrame then self.raidFrame:Toggle() end
    elseif msg == "ms" then
        if self.mainWindow then self.mainWindow:ShowTab("ms") end
    elseif msg == "loot" then
        if self.mainWindow then self.mainWindow:ShowTab("loot") end
    elseif msg == "minimap" then
        self:DiagnoseMinimapIcon()
    elseif msg == "debugbuff" then
        if self.raidFrame and self.raidFrame.DiagnoseBuffCatIcons then
            self.raidFrame:DiagnoseBuffCatIcons()
        else
            self.utils:Print(L["Raid frame not initialized yet."])
        end
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
--
-- La struttura di verita' e' un ARRAY SPARSO di slot (1..30): lo slot i-esimo
-- contiene un membro oppure nil. Questo permette di spostare/scambiare i
-- giocatori tra slot liberi e occupati (drag&drop nel pannello Raid Group)
-- senza dover "ricompattare" la lista. DebugRoster() restituisce una vista
-- DENSA (senza buchi) per chi vuole solo la lista dei membri (Raid Frame).
-- ============================================================
local DEBUG_MAX_SLOTS = 30
local DEBUG_MAX_GROUPS = 6

-- Vista DENSA del roster simulato (gli slot vuoti vengono saltati): usata
-- dal Raid Frame, dai test e ovunque serva una lista compatta dei membri.
function RLSuite:DebugRoster()
    if not self.debugRaid then self:ResetDebugRaid() end
    local list = {}
    for i = 1, DEBUG_MAX_SLOTS do
        local m = self.debugRaid.slots[i]
        if m then list[#list + 1] = m end
    end
    return list
end

-- Array sparso degli slot (1..30): la fonte di verita' per la disposizione
-- dei gruppi. Lo slot i-esimo sta nella colonna floor((i-1)/5)+1, riga
-- (i-1)%5+1.
function RLSuite:DebugRaidSlots()
    if not self.debugRaid then self:ResetDebugRaid() end
    return self.debugRaid.slots
end

function RLSuite:ResetDebugRaid()
    local me = UnitName("player") or "Player"
    local myClass = select(2, UnitClass("player")) or "WARRIOR"
    local player = { name = me, class = myClass, isPlayer = true, subgroup = 1 }
    self.debugRaid = {
        slots = { [1] = player },
    }
end

-- Ricalcola m.subgroup dalla posizione dello slot (una colonna = un gruppo).
function RLSuite:DebugSyncSubgroups()
    if not self.debugRaid then self:ResetDebugRaid() end
    for i, m in pairs(self.debugRaid.slots) do
        if m then
            local sub = math.floor((i - 1) / 5) + 1
            if sub < 1 then sub = 1 end
            if sub > DEBUG_MAX_GROUPS then sub = DEBUG_MAX_GROUPS end
            m.subgroup = sub
        end
    end
end

-- Primo slot libero dell'intero pannello, oppure del sottogruppo indicato.
function RLSuite:DebugFindEmptySlot(subgroup)
    if not self.debugRaid then self:ResetDebugRaid() end
    if subgroup then
        local base = (tonumber(subgroup) - 1) * 5
        for s = 1, 5 do
            local idx = base + s
            if idx >= 1 and idx <= DEBUG_MAX_SLOTS and not self.debugRaid.slots[idx] then
                return idx
            end
        end
        return nil
    end
    for i = 1, DEBUG_MAX_SLOTS do
        if not self.debugRaid.slots[i] then return i end
    end
    return nil
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
    local slot = self:DebugFindEmptySlot(subgroup)
    if not slot then return nil end
    local member = {
        name = name,
        class = class or "WARRIOR",
        isPlayer = false,
        subgroup = math.floor((slot - 1) / 5) + 1,
    }
    self.debugRaid.slots[slot] = member
    self:DebugSyncSubgroups()
    self:DebugRosterChanged()
    return member
end

-- Riempie i sottogruppi IN ORDINE, come un display raid normale: il gruppo 1
-- si riempie per primo (slot 1..5), poi il gruppo 2, e cosi' via. niente
-- distribuzione round-robin (che riempiva da sinistra a destra).
-- Ricompatta anche eventuali buchi lasciati dal drag&drop.
function RLSuite:DebugRebalanceGroups(ngroups)
    local max = ngroups or DEBUG_MAX_GROUPS
    if max < 1 then max = 1 end
    if max > DEBUG_MAX_GROUPS then max = DEBUG_MAX_GROUPS end
    local roster = self:DebugRoster()
    self.debugRaid.slots = {}
    for i, m in ipairs(roster) do
        self.debugRaid.slots[i] = m
    end
    self:DebugSyncSubgroups()
end

-- Called whenever the simulated roster changes (invite accepted, debug
-- toggled, ...). Refreshes the Raid Group panel and the Raid Frame. Every
-- refresh is protected: an error in one UI must NEVER block the other (the
-- "raid group stays empty after a debug invite" bug happened because a
-- RaidFrame failure could abort before the Raid Group update ran).
function RLSuite:DebugRosterChanged()
    if self.utils and self.utils.Debug then
        self.utils:Debug(string.format("DebugRosterChanged: %d membri nel roster", #self:DebugRoster()))
    end
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

-- Determina il nome della cartella dell'addon. baseName (dalla ADDON_LOADED)
-- e' di solito gia' corretto; come ulteriore sicurezza cerchiamo la cartella
-- tra gli addon caricati confrontando il titolo del .toc (robusto anche con
-- cartelle rinominate).
function RLSuite:DetectAddonFolder()
    local folder = self.baseName or "RaidLeadSuite"
    if GetNumAddOns and GetAddOnInfo then
        local n = GetNumAddOns()
        if n and n > 0 then
            for i = 1, n do
                local name, title = GetAddOnInfo(i)
                local t = tostring(title or ""):lower()
                local nm = tostring(name or ""):lower()
                if t:find("rlsuite", 1, true) or t:find("raid leading", 1, true)
                    or nm:find("raidlead", 1, true) then
                    folder = name
                    break
                end
            end
        end
    end
    return folder
end

-- Percorso di una risorsa dentro la cartella dell'addon, usando il nome
-- cartella reale (RLSuite o RaidLeadSuite a seconda di come e' installato).
function RLSuite:AddonTexture(rel)
    local folder = self:DetectAddonFolder()
    return "Interface\\AddOns\\" .. folder .. "\\" .. rel
end

-- ============================================================
-- MINIMAP ICON
-- Fazione: personaggio dell'Orda -> hordeicon, altrimenti allianceicon
-- (file .blp forniti dall'utente, con fallback sul .tga originale).
-- L'icona e' QUADRATA 32x32 e riempie tutto il bottone, senza anellino.
-- Click sinistro  = apre/chiude la main bar di RLS.
-- Click destro    = apre la Config.
-- Shift + click sinistro + drag = sposta l'icona lungo la minimappa
-- (l'angolo viene salvato nel profilo).
-- ============================================================
function RLSuite:IsHorde()
    if UnitFactionGroup then
        return UnitFactionGroup("player") == "Horde"
    end
    return false
end

-- Raggio dell'anello della minimappa. La minimappa classica 3.3.5 ha un
-- diametro di circa 140px; usiamo la larghezza reale della Minimap se e'
-- plausibile, altrimenti il raggio standard.
function RLSuite:MinimapIconRadius()
    if Minimap and Minimap.GetWidth then
        local w = tonumber(Minimap:GetWidth())
        if w and w >= 40 then
            return w / 2
        end
    end
    return 70
end

-- Angolo salvato (in gradi, 0 = est, cresce in senso antiorario).
function RLSuite:MinimapIconAngle()
    local mm = self.db and self.db.profile.minimap
    local a = mm and tonumber(mm.angle)
    if a then return a end
    return 220
end

-- Crea l'icona della minimappa appena possibile: prova subito, e se la
-- minimappa non e' ancora pronta (o la creazione fallisce) riprova ogni
-- secondo via timer, finche' il bottone non esiste davvero. Idempotente.
function RLSuite:EnsureMinimapIcon()
    if self.minimapIcon then return end
    if self._mmTimer then return end -- tentativo gia' programmato

    if Minimap then
        local ok, err = pcall(self.CreateMinimapIcon, self)
        if not ok and self.utils and self.utils.Print then
            self.utils:Print(string.format(L["RLSuite minimap error: %s"], tostring(err)))
        end
    end

    if self.minimapIcon then return end
    self._mmRetries = (self._mmRetries or 0) + 1
    if self._mmRetries <= 60 and self.ScheduleTimer then
        self._mmTimer = self:ScheduleTimer("OnMinimapRetry", 1)
    end
end

function RLSuite:OnMinimapRetry()
    self._mmTimer = nil
    self:EnsureMinimapIcon()
end

-- Tiene il bottone della minimappa SEMPRE sopra lo sfondo della barra in cui
-- viene raccolto (MinimapButtonFrame e simili). MBF ripara i livelli durante
-- i propri scan; qui li ripristiniamo subito, in modo deterministico e
-- indipendente dall'ordine di caricamento/scan.
function RLSuite:KeepMinimapButtonOnTop()
    local btn = self.minimapIcon
    if not btn or not btn.SetFrameLevel or not btn.SetFrameStrata then
        -- Il bottone non c'e' piu': ferma il timer.
        if self._mmTopTimer and self.CancelTimer then
            self:CancelTimer(self._mmTopTimer, true)
        end
        self._mmTopTimer = nil
        return
    end

    local par = (btn.GetParent and btn:GetParent()) or nil
    local base = 0
    if par and par.GetFrameLevel then
        base = tonumber(par:GetFrameLevel()) or 0
    end

    -- Livello ben sopra quello del genitore (e quindi sopra il suo sfondo),
    -- qualunque valore usi l'addon che raccoglie i bottoni.
    local want = base + 100
    if (tonumber(btn:GetFrameLevel()) or 0) < want then
        btn:SetFrameLevel(want)
    end
    if btn:GetFrameStrata() ~= "MEDIUM" then
        btn:SetFrameStrata("MEDIUM")
    end
end

-- Chiede a MinimapButtonFrame (se installato) di riscansare subito: il suo
-- scan singolo parte ~3s dopo il load e, se la minimappa non era ancora
-- pronta in quel momento, il nostro bottone non verrebbe raccolto e
-- resterebbe dietro il quadrato. Chiamando MBF_Scan appena il bottone esiste,
-- la raccolta avviene sempre, a prescindere dall'ordine reload/login.
function RLSuite:TriggerMBFRescan()
    if InCombatLockdown and InCombatLockdown() then return end
    if type(MBF_Scan) == "function" then
        pcall(MBF_Scan)
    end
    self:KeepMinimapButtonOnTop()
end

-- Crea l'icona della minimappa (una sola volta, al login o appena la
-- minimappa e' disponibile).
function RLSuite:CreateMinimapIcon()
    if self.minimapIcon then return end
    if not Minimap then
        if self.utils and self.utils.Print then
            self.utils:Print("|cffff9900RLSuite: Minimap not ready, will retry at PLAYER_ENTERING_WORLD|r")
        end
        return
    end

    -- Il bottone e' figlio di Minimap, come ogni normale bottone da minimappa:
    -- cosi' MinimapButtonFrame (MBF) lo trova scandendo Minimap:GetChildren()
    -- e lo raccoglie nella sua barra (lo riparenta e gestisce strata/livello).
    -- Il nome NON deve contenere "MinimapIcon": MBF lo userebbe come match per
    -- escludere i pin della minimappa e lo ignorerebbe.
    local btn = CreateFrame("Button", "RLSuiteMinimapButton", Minimap)
    btn:SetSize(32, 32)
    -- Strata/livello iniziali: visibile sul bordo della minimappa finche' MBF
    -- non lo raccoglie; il livello viene poi gestito da KeepMinimapButtonOnTop
    -- per restare SEMPRE sopra lo sfondo della barra di MBF.
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(10)

    -- ICONA DELL'UTENTE da media/ (priorita' assoluta): hordeicon per
    -- l'Orda, allianceicon altrimenti. Quadrata 32x32, riempie il bottone.
    local file = self:IsHorde() and "media\\hordeicon.blp" or "media\\allianceicon.blp"
    -- Texture CON NOME: alcuni addon che raccolgono i bottoni (MBF) iterano
    -- i figli del bottone e usano GetName() come chiave; una texture senza
    -- nome li manderebbe in errore e bloccherebbe la raccolta nella barra.
    local tex = btn:CreateTexture("RLSuiteMMBtnIcon", "ARTWORK")
    tex:SetAllPoints(btn)
    tex:SetTexture(self:AddonTexture(file))

    -- Se il .blp non viene caricato, riproviamo con il .tga originale
    -- (sempre l'icona dell'utente, sempre da media/).
    if not tex:GetTexture() then
        local tgafile = self:IsHorde() and "media\\hordeicon.tga" or "media\\allianceicon.tga"
        tex:SetTexture(self:AddonTexture(tgafile))
    end
    btn.icon = tex

    -- Sfondo quadrato dietro l'icona (OPZIONALE): niente SetColorTexture
    -- (non disponibile su tutti i client 3.3.5), usiamo la texture bianca
    -- standard + SetVertexColor. E' isolato in un pcall: se dovesse fallire
    -- per qualunque motivo NON deve impedire la creazione del bottone.
    local ok = pcall(function()
        local bg = btn:CreateTexture("RLSuiteMMBtnBg", "BACKGROUND")
        bg:SetAllPoints(btn)
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.09, 0.09, 0.11, 1)
    end)

    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    btn:SetScript("OnClick", function(self2, button)
        if button == "RightButton" then
            if RLSuite.config and RLSuite.config.Toggle then
                RLSuite.config:Toggle()
            end
        else
            if RLSuite.mainWindow and RLSuite.mainWindow.Toggle then
                RLSuite.mainWindow:Toggle()
            end
        end
    end)

    -- Solo con Shift premuto parte lo spostamento: un click sinistro
    -- semplice resta un click (apre la barra), un drag semplice non fa
    -- nulla, un drag con Shift sposta l'icona.
    btn:SetScript("OnDragStart", function(self2)
        if IsShiftKeyDown and IsShiftKeyDown() then
            self2.dragging = true
            self2:StartMoving()
        end
    end)

    btn:SetScript("OnDragStop", function(self2)
        self2:StopMovingOrSizing()
        self2.dragging = nil
        RLSuite:SaveMinimapIconPosition(self2)
    end)

    btn:SetScript("OnEnter", function(self2)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self2, "ANCHOR_LEFT")
        GameTooltip:SetText("RLSuite")
        GameTooltip:AddLine(L["Left click: open RLS"], 1, 1, 1)
        GameTooltip:AddLine(L["Right click: config"], 1, 1, 1)
        GameTooltip:AddLine(L["Shift + left drag: move"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)

    btn:Show()
    self.minimapIcon = btn
    self:PlaceMinimapIcon()

    -- SELF-HEAL dello z-order: MBF (e addon simili) riparentano il bottone e
    -- durante i propri scan ne reimpostano strata/livello. Un timer leggero
    -- riporta il livello SEMPRE sopra lo sfondo della barra, cosi' il bottone
    -- non finisce mai "sotto il quadrato" (il bug prima cambiava tra /reload
    -- e logout/login perche' dipendeva dall'ordine degli scan).
    if self.ScheduleRepeatingTimer and not self._mmTopTimer then
        self._mmTopTimer = self:ScheduleRepeatingTimer("KeepMinimapButtonOnTop", 0.25)
    end

    -- Ogni volta che il bottone viene mostrato (anche dopo un reparent di
    -- MBF), ripristina subito il livello sopra lo sfondo.
    btn:SetScript("OnShow", function() RLSuite:KeepMinimapButtonOnTop() end)

    -- Forza la raccolta di MBF appena il bottone esiste: se lo scan singolo
    -- di MBF e' gia' passato, lo facciamo riscansare ora (e di nuovo tra
    -- poco, per sicurezza). Senza questo, al /reload il bottone poteva
    -- restare figlio della minimappa e finire dietro il quadrato di MBF.
    if self.ScheduleTimer then
        self:ScheduleTimer("TriggerMBFRescan", 0.5)
        self:ScheduleTimer("TriggerMBFRescan", 2.5)
    end

    -- Diagnostica: al login stampa il percorso risolto e l'esito del
    -- caricamento, cosi' da verificare subito se l'icona e' stata trovata.
    if self.utils and self.utils.Print then
        local finalPath = tex:GetTexture()
        if type(finalPath) == "string" then
            self.utils:Print(string.format(L["Minimap icon: %s"],
                string.format("%s (%s)", finalPath, self:IsHorde() and "Horde" or "Alliance")))
        else
            self.utils:Print("|cffff0000" .. string.format(L["RLSuite minimap error: %s"],
                string.format("icon not loaded from %s (folder=%s)",
                    self:AddonTexture(file), self:DetectAddonFolder())) .. "|r")
        end
    end
end

-- Posiziona l'icona sulla minimappa all'angolo salvato.
function RLSuite:PlaceMinimapIcon()
    local btn = self.minimapIcon
    if not btn or not Minimap then return end
    local angle = math.rad(self:MinimapIconAngle())
    local radius = self:MinimapIconRadius()
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- Salva la posizione dopo il drag: calcola l'angolo dal centro della
-- minimappa e riporta l'icona esattamente sul bordo dell'anello.
function RLSuite:SaveMinimapIconPosition(btn)
    if not btn or not Minimap then return end
    if not Minimap.GetCenter then return end
    local cx, cy = Minimap:GetCenter()
    if not cx then return end
    local x = (btn:GetLeft() or 0) + (btn:GetWidth() or 32) / 2
    local y = (btn:GetBottom() or 0) + (btn:GetHeight() or 32) / 2
    local angle = math.deg(math.atan2(y - cy, x - cx))
    if angle < 0 then angle = angle + 360 end
    local mm = self.db.profile.minimap
    if not mm then
        mm = {}
        self.db.profile.minimap = mm
    end
    mm.angle = angle
    self:PlaceMinimapIcon()
end

-- Diagnostica completa dell'icona minimappa (/rls minimap): stampa cartella
-- rilevata, percorso risolto, stato della texture, posizione e visibilita'.
function RLSuite:DiagnoseMinimapIcon()
    local p = function(t) if self.utils and self.utils.Print then self.utils:Print(t) end end
    p("|cff00ccffRLSuite minimap diagnostic:|r")
    p("  baseName: " .. tostring(self.baseName))
    p("  detected folder: " .. tostring(self:DetectAddonFolder()))
    p("  faction: " .. (self:IsHorde() and "Horde" or "Alliance"))
    p("  Minimap frame exists: " .. tostring(Minimap ~= nil))
    local btn = self.minimapIcon
    if not btn then
        p("  minimap button not created yet; creating now...")
        local ok, err = pcall(self.CreateMinimapIcon, self)
        if ok and self.minimapIcon then
            p("  created on demand: OK")
        else
            p("|cffff0000  create FAILED: " .. tostring(err) .. "|r")
        end
        btn = self.minimapIcon
        if not btn then return end
    end
    p("  button shown: " .. tostring(btn:IsShown()))
    if btn.GetParent then
        local par = btn:GetParent()
        local pname = (par and par.GetName and par:GetName()) or "?"
        local pstrata = (par and par.GetFrameStrata and par:GetFrameStrata()) or "?"
        local plevel = (par and par.GetFrameLevel and par:GetFrameLevel()) or "?"
        p("  button parent: " .. tostring(pname) .. " (strata " .. tostring(pstrata) .. ", level " .. tostring(plevel) .. ")")
    end
    if btn.GetFrameStrata and btn.GetFrameLevel then
        p("  button strata/level: " .. tostring(btn:GetFrameStrata()) .. " / " .. tostring(btn:GetFrameLevel()))
    end
    if Minimap and Minimap.GetFrameStrata then
        p("  Minimap strata/level: " .. tostring(Minimap:GetFrameStrata()) .. " / " .. tostring(Minimap:GetFrameLevel()))
    end
    if MinimapButtonFrame then
        p("  MBF bar strata/level: " .. tostring(MinimapButtonFrame:GetFrameStrata()) .. " / " .. tostring(MinimapButtonFrame:GetFrameLevel()))
    end
    if btn.GetLeft and btn.GetBottom then
        p("  button pos: " .. tostring(btn:GetLeft()) .. ", " .. tostring(btn:GetBottom()))
    end
    local tex = btn.icon
    if tex then
        local tp = tex:GetTexture()
        if type(tp) == "string" then
            p("  icon texture: " .. tp)
        else
            p("|cffff0000  icon texture: NOT LOADED (path/folder wrong, or file missing)|r")
        end
        p("  icon texture region size: " .. tostring(tex:GetWidth()) .. "x" .. tostring(tex:GetHeight()))
    end
    p("  expected path: " .. self:AddonTexture(self:IsHorde() and "media\\hordeicon.blp" or "media\\allianceicon.blp"))
end

function RLSuite:InRaid()
    if self:DebugMode() then return true end
    return GetNumRaidMembers() > 0
end

function RLSuite:IsOfficer()
    if self:DebugMode() then return true end
    return (IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())
end

-- ============================================================
-- MAIN TANK / MAIN ASSIST (tasti MT / OT della barra principale)
-- SetPartyAssignment(role, unit) e' una TOGGLE nel client 3.3.5: se
-- l'unita' ha gia' l'assegnazione viene tolta, altrimenti impostata.
-- Richiede RL/organizzatore nel raid (in debug sempre consentito).
-- ============================================================
function RLSuite:AssignPartyRole(role)
    local label = (role == "MAINTANK") and "Main Tank" or "Main Assist"
    if type(SetPartyAssignment) ~= "function" then
        self.utils:Print(string.format(L["%s assignment is not available on this client."], label))
        return false
    end
    if not (UnitExists and UnitExists("target")) then
        self.utils:Print(string.format(L["Target a raid member first to assign %s."], label))
        return false
    end
    if not self:IsOfficer() then
        self.utils:Print(L["Only the raid leader or an assist can assign Main Tank / Main Assist."])
        return false
    end
    SetPartyAssignment(role, "target")
    local name = UnitName("target") or "?"
    self.utils:Print(string.format(L["%s toggled as %s."], name, label))
    return true
end

function RLSuite:ApplyDebugMode()
    self:UpdateRaidContext()
    -- The simulated roster always restarts from just the player when debug
    -- mode is toggled, so stale fake members never leak between sessions.
    self.debugRaid = nil
    self.debugTanks = nil   -- assegnazioni MT/OT simulate (debug)
    self.debugBuffs = nil   -- aure simulati dei fake (debug)
    if self:DebugMode() then
        self.utils:Print("|cffff9900" .. L["DEBUG MODE ON"] .. "|r - " .. L["Simulated raid, messages are whispered to you."])
        if self.lootManager and self.lootManager.SpawnDebugLoot then
            self.lootManager:SpawnDebugLoot()
        end
    else
        self.utils:Print("Debug mode OFF.")
        -- Il Loot Manager si SVUOTA uscendo dalla debug mode: storico,
        -- roll in corso e finestre "click to pick up" contenevano solo
        -- dati finti e non devono restare aperti nella UI reale.
        if self.lootManager and self.lootManager.ClearHistory then
            self.lootManager:ClearHistory()
        end
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
    if self.raidFrame and self.raidFrame.UpdatePhase then
        self.raidFrame:UpdatePhase()
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
