-- ============================================================
-- RLSuite - CombatLog Module ("Fight log" in-game, stile MRT)
-- ============================================================
-- Registra i combat log event (CLEU) per segmento di combattimento
-- (pull), li aggrega on-demand e li mostra in una finestra stile
-- Method/Exorsus Raid Tools: tab Damage/Healing/Enemies/Interrupts/
-- Auras/Players/Power + tab Graphs (DPS/Health/Power con zoom e
-- tooltip hover). Su 3.3.5a NON esistono ENCOUNTER_START/END: la
-- segmentazione usa PLAYER_REGEN_DISABLED/ENABLED; kill/wipe si deduce
-- dalla morte di un boss noto (UNIT_DIED su NPC id in CL_BOSS_NPC).
-- Persistenza: i pull chiusi vanno nel profilo (db.combatlog.fights),
-- scrittura SOLO a fine combat (mai live: i SavedVariables scrivono a
-- disco). Cap eventi per pull + cap numero pull salvati.
-- ============================================================

RLSuite.combatLog = {}
local CL = RLSuite.combatLog

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

LibStub("AceTimer-3.0"):Embed(CL)
LibStub("AceEvent-3.0"):Embed(CL)

-- Indici posizionali di un evento registrato (array compatto).
local CL_E = {
    T = 1, SUB = 2, SRC = 3, SRCF = 4, DST = 5, DSTF = 6,
    SID = 7, SNAME = 8, AMT = 9, OVER = 10, ABS = 11, BLOCK = 12,
    CRIT = 13, AURA = 14, PTYPE = 15, EXTRA = 16,
    -- 17: bersaglio del colpo = NPC BOSS noto. E' il dato che distingue il
    -- "danno UTILE" (sui boss) dal danno sullo spazzino, come fa UwU Logs.
    BOSS = 17,
}
-- Indici evento esposti anche ai test (le tabelle evento sono array compatti).
CL.E = CL_E

-- Flag bit del combat log (potenze di due, dal FrameXML 3.3.5).
local CL_FLAG_PLAYER = 1024
local CL_FLAG_NPC = 2048
local CL_FLAG_PET = 4096
local CL_FLAG_FRIENDLY = 16

-- Boss noti WotLK (NPC id -> nome): usati per nome pull e kill/wipe.
local CL_BOSS_NPC = {
    -- Icecrown Citadel
    [36612] = "Lord Marrowgar", [36855] = "Lady Deathwhisper",
    [37813] = "Deathbringer Saurfang", [36627] = "Rotface",
    [36626] = "Festergut", [36678] = "Professor Putricide",
    [37970] = "Blood Prince Council", [37972] = "Blood Prince Council",
    [37973] = "Blood Prince Council", [37955] = "Blood-Queen Lana'thel",
    [36789] = "Valithria Dreamwalker", [36853] = "Sindragosa",
    [36597] = "The Lich King",
    -- Ruby Sanctum
    [39863] = "Halion",
    -- Trial of the Crusader
    [34796] = "Gormok the Impaler", [35144] = "Acidmaw",
    [34799] = "Dreadscale", [34797] = "Icehowl",
    [34780] = "Lord Jaraxxus", [34497] = "Fjola Lightbane",
    [34496] = "Eydis Darkbane", [34564] = "Anub'arak",
    -- Ulduar
    [33113] = "Flame Leviathan", [33118] = "Ignis the Furnace Master",
    [33186] = "Razorscale", [33293] = "XT-002 Deconstructor",
    [32930] = "Kologarn", [33515] = "Auriaya",
    [32845] = "Hodir", [32865] = "Thorim", [32906] = "Freya",
    [33350] = "Mimiron", [33271] = "General Vezax",
    [33288] = "Yogg-Saron", [32871] = "Algalon the Observer",
    -- Naxxramas
    [15956] = "Anub'Rekhan", [15953] = "Grand Widow Faerlina",
    [15952] = "Maexxna", [15954] = "Noth the Plaguebringer",
    [15936] = "Heigan the Unclean", [16011] = "Loatheb",
    [16028] = "Patchwerk", [15931] = "Grobbulus", [15932] = "Gluth",
    [15928] = "Thaddius", [16061] = "Instructor Razuvious",
    [16060] = "Gothik the Harvester", [15989] = "Sapphiron",
    [15990] = "Kel'Thuzad",
    -- Singoli
    [10184] = "Onyxia", [28860] = "Sartharion", [28859] = "Malygos",
    [31125] = "Archavon the Stone Watcher", [33993] = "Emalon the Storm Watcher",
    [35013] = "Koralon the Flame Watcher", [38433] = "Toravon the Ice Watcher",
}

-- Set di id per il test rapido "questo bersaglio e' un boss?" (danno utile).
local CL_BOSS_SET = {}
for id in pairs(CL_BOSS_NPC) do CL_BOSS_SET[id] = true end

-- Consumabili tracciati dal tab "Consumables": solo NOMI/ID noti, nessuna
-- detection euristica. I flask e il "Well Fed" arrivano dalle liste gia'
-- curate in RLSuite.buffData (Core); pozioni/elisir si riconoscono dal nome
-- della spell (client inglese) perche' i loro id cambiano fra item e rank.
local CL_CONSUM_PATTERNS = {
    "potion", "elixir", "flask", "well fed", "feast", "rum", "firecracker",
    "kibler", "sashimi", "biscuit", "tequila", "mammoth", "shoveltusk",
    "blackened", "dragonfin", "snapper", "bold", "spiced", "great feast",
}

-- subEvent -> categoria di cattura.
local CL_CATS = {
    SWING_DAMAGE = "damage", SPELL_DAMAGE = "damage", RANGE_DAMAGE = "damage",
    SPELL_PERIODIC_DAMAGE = "damage", DAMAGE_SHIELD = "damage", DAMAGE_SPLIT = "damage",
    ENVIRONMENTAL_DAMAGE = "damage",
    SPELL_HEAL = "heal", SPELL_PERIODIC_HEAL = "heal",
    UNIT_DIED = "death", UNIT_DESTROYED = "death",
    SPELL_AURA_APPLIED = "aura", SPELL_AURA_REMOVED = "aura",
    SPELL_AURA_APPLIED_DOSE = "aura", SPELL_AURA_REMOVED_DOSE = "aura",
    SPELL_AURA_REFRESH = "aura", SPELL_AURA_BROKEN_SPELL = "aura",
    SPELL_CAST_START = "cast", SPELL_CAST_SUCCESS = "cast", SPELL_SUMMON = "cast",
    SPELL_INTERRUPT = "interrupt",
    SPELL_DISPEL = "dispel", SPELL_STOLEN = "dispel",
    SPELL_ENERGIZE = "energize", SPELL_PERIODIC_ENERGIZE = "energize",
}

local CL_POWER_NAMES = {
    [0] = "Mana", [1] = "Rage", [2] = "Focus", [3] = "Energy",
    [4] = "Happiness", [5] = "Rune", [6] = "Runic Power",
}

local CL_MAX_SAMPLES = 600      -- 10 minuti di fight a 1 Hz
local CL_UI_TABS = {
    { key = "damage",     label = "Damage" },
    { key = "healing",    label = "Healing" },
    { key = "enemies",    label = "Enemies" },
    { key = "interrupts", label = "Interrupts" },
    { key = "auras",      label = "Auras" },
    { key = "players",    label = "Players spells" },
    { key = "power",      label = "Power" },
    { key = "graphs",     label = "Graphs" },
}

-- ------------------------------------------------------------------
-- Helpers flag/nomi/GUID (concetti da MRT Functions.lua, zero bit-lib)
-- ------------------------------------------------------------------
local function FlagHas(f, m)
    return math.floor(((f or 0) / m)) % 2 == 1
end
function CL:IsPlayerFlag(f) return FlagHas(f, CL_FLAG_PLAYER) end
function CL:IsNPCFlag(f) return FlagHas(f, CL_FLAG_NPC) end
function CL:IsPetFlag(f) return FlagHas(f, CL_FLAG_PET) end
function CL:IsFriendlyFlag(f) return FlagHas(f, CL_FLAG_FRIENDLY) end
-- affiliation mine/party/raid = uno qualsiasi dei 3 bit bassi (mask 0x7).
function CL:IsRaidGroupFlag(f) return ((f or 0) % 8) > 0 end

-- NPC id dal GUID: formato 3.3.5 (esadecimale, high "F1xx", entry = chars 9-12)
-- o formato moderno "Creature-0-...-ID-spawnID".
-- NPC id dal GUID: implementazione unica in Utils (NpcIdFromGUID), qui resta
-- solo il delegato per compatibilita' col resto del modulo.
function CL:NpcIdFromGUID(guid)
    if RLSuite.utils and RLSuite.utils.NpcIdFromGUID then
        return RLSuite.utils:NpcIdFromGUID(guid)
    end
    if type(guid) ~= "string" or guid == "" then return nil end
    if guid:find("-", 1, true) then
        local parts = { strsplit("-", guid) }
        return tonumber(parts[6])
    end
    if guid:sub(3, 4) == "F1" then
        return tonumber(guid:sub(9, 12), 16)
    end
    return nil
end

-- Boss morto: aggiorna il counter di progressione (raid -> boss) per le
-- macro in-fight. Accetta un GUID (usato da OnCLEU) o direttamente un id.
function CL:NoteBossKill(guidOrId)
    if not (RLSuite and RLSuite.RecordBossKill) then return false end
    local id = guidOrId
    if type(guidOrId) == "string" then id = self:NpcIdFromGUID(guidOrId) end
    if not id then return false end
    return RLSuite:RecordBossKill(id) and true or false
end

-- "Nome-Realm" -> "Nome" se il realm e' il nostro (rpmeno suffissi in chat).
function CL:ShortName(name)
    if type(name) ~= "string" then return name end
    if self._realmKey == nil then
        self._realmKey = (GetRealmName and GetRealmName() or ""):gsub("[ %-]", "")
    end
    local n, server = strsplit("-", name)
    if server == nil then return name end
    if server:gsub(" ", "") == self._realmKey or server == self._realmKey then
        return n
    end
    return name
end

function CL:ClassColor(name)
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, n do
        local nm, _, _, _, _, class = GetRaidRosterInfo(i)
        if nm == name and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local cc = RAID_CLASS_COLORS[class]
            return cc.r, cc.g, cc.b
        end
    end
    if name == (UnitName and UnitName("player")) then
        local _, cls = UnitClass("player")
        local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if cc then return cc.r, cc.g, cc.b end
    end
    return 1, 1, 1
end

function CL:ShortNum(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
    if n >= 1000 then return string.format("%.1fk", n / 1000) end
    return tostring(math.floor(n + 0.5))
end

-- ------------------------------------------------------------------
-- DB
-- ------------------------------------------------------------------
function CL:DB()
    if RLSuite.db and RLSuite.db.profile.combatlog then
        self.db = RLSuite.db.profile.combatlog
    end
    if self.db and not self.db.fights then self.db.fights = {} end
    return self.db
end

function CL:Init()
    self:DB()
    self.selFight = nil       -- fight attualmente visualizzato
    self.selTab = "damage"
    self.selSource = nil      -- sorgente selezionata (click nella lista sx)
    self.selSpell = nil
    self.graphMode = "dps"    -- dps | health | power
    -- 0 = "Avg whole fight" (media cumulativa, default come UwU), poi 1/2/3/5/10s
    self.graphStep = 0
    self.showGraph = true
    self.liveUpdate = false
    -- La finestra si costruisce dentro un pcall: un errore di UI (es. un
    -- CreateFrame che esplode in 3.3.5) NON deve impedire il caricamento
    -- dell'addon — la cattura dei pull resta attiva anche senza pannello.
    local ok, err = pcall(function() CL:CreateFrame() end)
    if not ok and RLSuite.utils and RLSuite.utils.Print then
        RLSuite.utils:Print("Log window error: " .. tostring(err))
    end
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnRegenDisabled")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
end

function CL:Toggle()
    if not self.frame then return end
    if RLSuite.mainWindow and RLSuite.mainWindow.ShowTab then
        RLSuite.mainWindow:ShowTab("log")
        return
    end
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
        self:RefreshUI()
    end
end

-- ------------------------------------------------------------------
-- Segmentazione per pull
-- ------------------------------------------------------------------
function CL:OnRegenDisabled()
    if not (self.db and self.db.enabled) then return end
    if self.current then return end -- gia' in combat
    self.current = {
        startTime = GetTime(),
        startUTC = time(),
        events = {},
        count = 0,
        dropped = 0,
        boss = nil,
        bossGUID = nil,
        kill = nil,
        samples = { health = {}, power = {} },
    }
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCLEU")
    self.sampleTimer = self:ScheduleRepeatingTimer("SampleTick", 1)
    if self.liveUpdate and self.frame and self.frame:IsShown() then
        self:SelectFight(self.current)
        self:RefreshUI()
    end
end

function CL:OnRegenEnabled()
    local f = self.current
    if not f then return end
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    if self.sampleTimer then
        self:CancelTimer(self.sampleTimer)
        self.sampleTimer = nil
    end
    f.duration = GetTime() - f.startTime
    f.kill = f.kill and true or false
    f.name = f.boss or "Combat"
    f.player = UnitName and UnitName("player") or "?"
    -- Chiudi le aure aperte alla durata del fight (per gli uptime).
    f.auraOpen = nil
    self.current = nil
    -- Ring buffer dei pull salvati: in testa il piu' recente.
    if self.db and self.db.fights then
        table.insert(self.db.fights, 1, f)
        local cap = tonumber(self.db.saveFights) or 15
        if cap < 1 then cap = 1 end
        while #self.db.fights > cap do
            table.remove(self.db.fights)
        end
    end
    if self.selFight == f then
        -- niente da fare: la vista resta sul pull appena chiuso
    end
    self:RefreshUI()
end

-- ------------------------------------------------------------------
-- Cattura CLEU (normalizzazione args 3.3.5: timestamp, subEvent,
-- srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, suffix...)
-- ------------------------------------------------------------------
local CL_MAX_GUID_RESCAN = 40

function CL:OnCLEU(_, ts, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local f = self.current
    if not f then return end
    local cat = CL_CATS[sub]
    -- Nome del pull: primo boss noto che appare come sorgente/destinazione.
    if not f.boss then
        for _, g in ipairs({ dstGUID, srcGUID }) do
            local id = self:NpcIdFromGUID(g)
            if id and CL_BOSS_NPC[id] then
                f.boss = CL_BOSS_NPC[id]
                if g == srcGUID and not f.bossGUID then f.bossGUID = g end
                if g == dstGUID then f.bossGUID = g end
                break
            end
        end
    end
    -- Kill: un boss noto muore durante il pull.
    if sub == "UNIT_DIED" then
        local id = self:NpcIdFromGUID(dstGUID)
        if id and CL_BOSS_NPC[id] then
            f.boss = CL_BOSS_NPC[id]
            f.kill = true
            -- Counter di progressione (macro in-fight per boss): in debug NO,
            -- i pull finti del debug non devono sporcare la progressione vera.
            if not (RLSuite.DebugMode and RLSuite:DebugMode()) then
                self:NoteBossKill(dstGUID)
            end
        end
    end
    if not cat then return end
    -- Filtri di cattura (checkbox db) + opzione memoria "disable buffs".
    local fl = self.db.filters or {}
    if fl[cat] == false then return end
    if cat == "aura" and self.db.options and self.db.options.disableBuffs then return end

    local maxEv = tonumber(self.db.maxEvents) or 3000
    if f.count >= maxEv then
        f.dropped = f.dropped + 1
        return
    end

    local ev = { GetTime() - f.startTime, sub,
        self:ShortName(srcName), srcFlags or 0, self:ShortName(dstName), dstFlags or 0 }
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 = ...
    if sub == "SWING_DAMAGE" then
        ev[CL_E.SID] = 0; ev[CL_E.SNAME] = "Melee"
        ev[CL_E.AMT] = a1; ev[CL_E.OVER] = a2
        ev[CL_E.BLOCK] = a5; ev[CL_E.ABS] = a6; ev[CL_E.CRIT] = (a7 == 1)
    elseif cat == "damage" then
        -- SPELL_*: id, name, school, amount, overkill, school2, resisted, blocked, absorbed, critical
        if sub == "ENVIRONMENTAL_DAMAGE" then
            ev[CL_E.SID] = -1; ev[CL_E.SNAME] = tostring(a1)
            ev[CL_E.AMT] = a2; ev[CL_E.OVER] = a3
            ev[CL_E.BLOCK] = a7; ev[CL_E.ABS] = a8; ev[CL_E.CRIT] = (a9 == 1)
        else
            ev[CL_E.SID] = a1; ev[CL_E.SNAME] = a2
            ev[CL_E.AMT] = a4; ev[CL_E.OVER] = a5
            ev[CL_E.BLOCK] = a8; ev[CL_E.ABS] = a9; ev[CL_E.CRIT] = (a10 == 1)
        end
    elseif cat == "heal" then
        ev[CL_E.SID] = a1; ev[CL_E.SNAME] = a2
        ev[CL_E.AMT] = a4; ev[CL_E.OVER] = a5 -- overheal qui
        ev[CL_E.ABS] = a6; ev[CL_E.CRIT] = (a7 == 1)
    elseif cat == "aura" then
        ev[CL_E.SID] = a1; ev[CL_E.SNAME] = a2; ev[CL_E.AURA] = a4
        ev[CL_E.AMT] = a5
    elseif cat == "cast" then
        ev[CL_E.SID] = a1; ev[CL_E.SNAME] = a2
    elseif cat == "interrupt" then
        ev[CL_E.SID] = a1; ev[CL_E.SNAME] = a2
        ev[CL_E.EXTRA] = a5 -- extraSpellName (lo spell interrotto)
    elseif cat == "dispel" then
        ev[CL_E.SID] = a1; ev[CL_E.SNAME] = a2
        ev[CL_E.EXTRA] = a5; ev[CL_E.AURA] = a7
    elseif cat == "energize" then
        ev[CL_E.SID] = a1; ev[CL_E.SNAME] = a2
        ev[CL_E.AMT] = a4; ev[CL_E.PTYPE] = a5
    elseif cat == "death" then
        -- nessun suffix: dst e' il morto
    else
        return
    end
    -- Danno "utile": il bersaglio e' un boss noto (vedi CL_E.BOSS).
    if cat == "damage" and self:IsNPCFlag(dstFlags) then
        local bid = self:NpcIdFromGUID(dstGUID)
        if bid and CL_BOSS_SET[bid] then ev[CL_E.BOSS] = true end
    end
    f.count = f.count + 1
    f.events[f.count] = ev
    if self.liveUpdate and self.frame and self.frame:IsShown() then
        self._liveDirty = true
    end
end

-- Sampling HP%/Power% dei raid membri + del boss (via target dei raid members).
function CL:SampleTick()
    local f = self.current
    if not f then return end
    local t = GetTime() - f.startTime
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    local function addSample(store, key, pct)
        if not key or not pct then return end
        local s = store[key]
        if not s then s = {}; store[key] = s end
        if #s >= CL_MAX_SAMPLES then return end
        s[#s + 1] = { t, pct }
    end
    for i = 1, n do
        local u = "raid" .. i
        local name = UnitName(u)
        local hp, hpm = UnitHealth(u), UnitHealthMax(u)
        if name and hpm and hpm > 0 then
            addSample(f.samples.health, name, hp / hpm * 100)
        end
        local pw, pwm = UnitMana(u), UnitManaMax(u)
        if name and pwm and pwm > 0 then
            addSample(f.samples.power, name, pw / pwm * 100)
        end
        -- boss: qualsiasi raid member che targetta un boss noto lo traccia
        local tt = u .. "target"
        local tg = UnitGUID(tt)
        if tg and f.bossGUID and tg == f.bossGUID then
            local bhp, bhpm = UnitHealth(tt), UnitHealthMax(tt)
            if bhpm and bhpm > 0 then
                addSample(f.samples.health, "[BOSS] " .. (f.boss or "?"), bhp / bhpm * 100)
            end
        end
    end
end

-- ------------------------------------------------------------------
-- Aggregazioni on-demand
-- ------------------------------------------------------------------
function CL:FightDuration(f)
    if not f then return 0 end
    if f.duration then return f.duration end
    if self.current == f then return math.max(0.01, GetTime() - f.startTime) end
    return 1
end

-- Totali per sorgente su una categoria ("damage"|"heal"|"cast").
-- Ritorna rows (ordinati desc) e totale complessivo.
function CL:AggTotals(f, cat)
    local rows, total, catSub = {}, 0, nil
    local acc = {}
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == cat then
            local src = ev[CL_E.SRC]
            if cat == "damage" or cat == "heal" or cat == "cast" or true then
                catSub = ev[CL_E.SRCF]
                -- solo fonti del raid group (o pet): i colpi dei boss non sono "dps dei player"
                if cat ~= "enemies" and self:IsRaidGroupFlag(catSub) then
                    local amtKey = (cat == "cast") and 1 or (ev[CL_E.AMT] or 0)
                    acc[src] = (acc[src] or 0) + amtKey
                    total = total + amtKey
                end
            end
        end
    end
    for name, amt in pairs(acc) do
        rows[#rows + 1] = { name = name, amt = amt }
    end
    table.sort(rows, function(a, b) return a.amt > b.amt end)
    return rows, total
end

-- Breakdown per spell di una sorgente (damage/heal) o conteggio cast.
function CL:AggSpells(f, cat, srcName)
    local acc, total = {}, 0
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == cat and ev[CL_E.SRC] == srcName then
            local k = ev[CL_E.SNAME] or "?"
            local s = acc[k]
            if not s then
                s = { name = k, sid = ev[CL_E.SID], amt = 0, casts = 0, over = 0, abs = 0, blocked = 0, crits = 0 }
                acc[k] = s
            end
            if cat == "cast" then
                s.casts = s.casts + 1
                total = total + 1
            else
                s.amt = s.amt + (ev[CL_E.AMT] or 0)
                s.casts = s.casts + 1
                s.over = s.over + (ev[CL_E.OVER] or 0)
                s.abs = s.abs + (ev[CL_E.ABS] or 0)
                s.blocked = s.blocked + (ev[CL_E.BLOCK] or 0)
                if ev[CL_E.CRIT] then s.crits = s.crits + 1 end
                total = total + (ev[CL_E.AMT] or 0)
            end
        end
    end
    local rows = {}
    for _, s in pairs(acc) do rows[#rows + 1] = s end
    if cat == "cast" then
        table.sort(rows, function(a, b) return a.casts > b.casts end)
    else
        table.sort(rows, function(a, b) return a.amt > b.amt end)
    end
    return rows, total
end

-- Nemici: danno SUBITO da ciascun NPC ostile dai membri del raid.
function CL:AggEnemies(f)
    local acc, total = {}, 0
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == "damage" and self:IsRaidGroupFlag(ev[CL_E.SRCF])
            and self:IsNPCFlag(ev[CL_E.DSTF]) then
            local dst = ev[CL_E.DST] or "?"
            acc[dst] = (acc[dst] or 0) + (ev[CL_E.AMT] or 0)
            total = total + (ev[CL_E.AMT] or 0)
        end
    end
    local rows = {}
    for name, amt in pairs(acc) do rows[#rows + 1] = { name = name, amt = amt } end
    table.sort(rows, function(a, b) return a.amt > b.amt end)
    return rows, total
end

-- Righe evento per interrupt/dispel (con testo pronto).
function CL:AggInterrupts(f, cat)
    local rows = {}
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == cat then
            local verb = (cat == "interrupt") and "interrupt" or
                (ev[CL_E.SUB] == "SPELL_STOLEN" and "steal" or "dispel")
            rows[#rows + 1] = {
                t = ev[CL_E.T],
                src = ev[CL_E.SRC],
                text = (ev[CL_E.SRC] or "?") .. " " .. verb .. " " .. (ev[CL_E.DST] or "?")
                    .. " with " .. (ev[CL_E.SNAME] or "?")
                    .. (ev[CL_E.EXTRA] and (" (" .. tostring(ev[CL_E.EXTRA]) .. ")") or ""),
            }
        end
    end
    return rows
end

-- Uptime aure: APPLIED(+dose) apre, REMOVED(-dose/finale) chiude.
-- Ritorna righe per (spell,auraType) con uptime secondi e % sul fight.
function CL:AggAuras(f)
    local dur = self:FightDuration(f)
    if dur <= 0 then dur = 1 end
    local spells = {}
    local open = {}
    local function keyOf(sid, name, auraType) return tostring(sid) .. "|" .. tostring(auraType) end
    for _, ev in ipairs(f.events) do
        local sub = ev[CL_E.SUB]
        if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_APPLIED_DOSE" then
            local k = keyOf(ev[CL_E.SID], ev[CL_E.SNAME], ev[CL_E.AURA])
            local sk = k .. "|" .. tostring(ev[CL_E.DST])
            local st = open[sk]
            if not st then
                st = { t = ev[CL_E.T], n = 0 }
                open[sk] = st
            end
            if st.n == 0 then st.t = ev[CL_E.T] end
            st.n = st.n + 1
            local skey = k
            local sp = spells[skey]
            if not sp then
                sp = { name = ev[CL_E.SNAME], sid = ev[CL_E.SID], auraType = ev[CL_E.AURA], count = 0, up = 0, dests = {} }
                spells[skey] = sp
            end
            if sub == "SPELL_AURA_APPLIED" then
                sp.count = sp.count + 1
            end
        elseif sub == "SPELL_AURA_REMOVED" or sub == "SPELL_AURA_REMOVED_DOSE" or sub == "SPELL_AURA_BROKEN_SPELL" then
            local k = keyOf(ev[CL_E.SID], ev[CL_E.SNAME], ev[CL_E.AURA])
            local sk = k .. "|" .. tostring(ev[CL_E.DST])
            local st = open[sk]
            if st then
                if sub == "SPELL_AURA_REMOVED_DOSE" and st.n > 1 then
                    st.n = st.n - 1
                else
                    local dt = ev[CL_E.T] - st.t
                    if dt > 0 then
                        local skey = k
                        local sp = spells[skey]
                        if not sp then
                            sp = { name = ev[CL_E.SNAME], sid = ev[CL_E.SID], auraType = ev[CL_E.AURA], count = 0, up = 0, dests = {} }
                            spells[skey] = sp
                        end
                        sp.up = sp.up + dt
                        sp.dests[ev[CL_E.DST] or "?"] = (sp.dests[ev[CL_E.DST] or "?"] or 0) + dt
                    end
                    open[sk] = nil
                end
            end
        end
    end
    -- aure ancora aperte alla fine: chiuse sulla durata del fight
    for sk, st in pairs(open) do
        local kB, kA, kD = strsplit("|", sk)
        local skey = kB .. "|" .. kA
        local sp = spells[skey]
        if sp then
            local dt = dur - st.t
            if dt > 0 then
                sp.up = sp.up + dt
                sp.dests[kD or "?"] = (sp.dests[kD or "?"] or 0) + dt
            end
        end
    end
    local rows = {}
    for _, sp in pairs(spells) do
        sp.uptime = math.min(100, sp.up / dur * 100)
        rows[#rows + 1] = sp
    end
    table.sort(rows, function(a, b) return a.up > b.up end)
    return rows
end

-- Power: totali energize per (dest, ptype); righe per ptype e breakdown.
function CL:AggPower(f)
    local byType, byPlayer = {}, {}
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == "energize" then
            local pt = CL_POWER_NAMES[ev[CL_E.PTYPE]] or ("Power " .. tostring(ev[CL_E.PTYPE] or "?"))
            byType[pt] = (byType[pt] or 0) + (ev[CL_E.AMT] or 0)
            if self:IsRaidGroupFlag(ev[CL_E.DSTF]) then
                local k = pt .. "|" .. tostring(ev[CL_E.DST])
                byPlayer[k] = (byPlayer[k] or 0) + (ev[CL_E.AMT] or 0)
            end
        end
    end
    local rows = {}
    for pt, amt in pairs(byType) do rows[#rows + 1] = { name = pt, amt = amt } end
    table.sort(rows, function(a, b) return a.amt > b.amt end)
    return rows, byPlayer
end

-- ------------------------------------------------------------------
-- Report (v1.11.63): aggregazioni per le viste stile UwU Logs.
-- Tutte le funzioni prendono un fight (o un fight "unito" dei segmenti) e
-- tornano tabelle pronte per la griglia: {rows=..., cols=...}.
-- ------------------------------------------------------------------

-- Tabella principale: per giocatore danno utile/totale, cure, danno subito.
function CL:AggPlayerStats(f)
    local dur = self:FightDuration(f)
    if dur <= 0 then dur = 1 end
    local acc = {}
    local function get(name)
        local a = acc[name]
        if not a then a = { name = name, useful = 0, total = 0, heal = 0, taken = 0 }; acc[name] = a end
        return a
    end
    for _, ev in ipairs(f.events) do
        local cat = CL_CATS[ev[CL_E.SUB]]
        local amt = ev[CL_E.AMT] or 0
        if cat == "damage" then
            local src = ev[CL_E.SRC]
            if src and self:IsRaidGroupFlag(ev[CL_E.SRCF]) then
                local a = get(src)
                a.total = a.total + amt
                if ev[CL_E.BOSS] then a.useful = a.useful + amt end
            end
            local dst = ev[CL_E.DST]
            if dst and self:IsRaidGroupFlag(ev[CL_E.DSTF]) then
                get(dst).taken = get(dst).taken + amt
            end
        elseif cat == "heal" then
            local src = ev[CL_E.SRC]
            if src and self:IsRaidGroupFlag(ev[CL_E.SRCF]) then
                get(src).heal = get(src).heal + amt
            end
        end
    end
    local rows, tot = {}, {
        name = "Total", useful = 0, total = 0, heal = 0, taken = 0, isTotal = true,
    }
    for _, a in pairs(acc) do
        if (a.total > 0) or (a.heal > 0) or (a.taken > 0) then
            rows[#rows + 1] = a
            tot.useful = tot.useful + a.useful
            tot.total = tot.total + a.total
            tot.heal = tot.heal + a.heal
            tot.taken = tot.taken + a.taken
        end
    end
    table.sort(rows, function(x, y)
        if x.useful ~= y.useful then return x.useful > y.useful end
        if x.total ~= y.total then return x.total > y.total end
        return x.name < y.name
    end)
    return { rows = rows, total = tot, duration = dur }
end

-- Matrice danno per (giocatore, bersaglio NPC) + totali per colonna.
function CL:AggTargets(f)
    local byPlayer, targetTotal, targetIsBoss, playerTotal = {}, {}, {}, {}
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == "damage" and self:IsRaidGroupFlag(ev[CL_E.SRCF])
            and ev[CL_E.DST] and self:IsNPCFlag(ev[CL_E.DSTF]) then
            local src, dst, amt = ev[CL_E.SRC], ev[CL_E.DST], (ev[CL_E.AMT] or 0)
            if src then
                local t = byPlayer[src]
                if not t then t = {}; byPlayer[src] = t end
                t[dst] = (t[dst] or 0) + amt
                playerTotal[src] = (playerTotal[src] or 0) + amt
                targetTotal[dst] = (targetTotal[dst] or 0) + amt
                if ev[CL_E.BOSS] then targetIsBoss[dst] = true end
            end
        end
    end
    local cols = {}
    for name, amt in pairs(targetTotal) do
        cols[#cols + 1] = { name = name, amt = amt, boss = targetIsBoss[name] and true or false }
    end
    -- i bersaglio "utili" (boss) restano in testa, poi per danno
    table.sort(cols, function(a, b)
        if a.boss ~= b.boss then return a.boss end
        if a.amt ~= b.amt then return a.amt > b.amt end
        return a.name < b.name
    end)
    local rows = {}
    for name, t in pairs(byPlayer) do
        local useful = 0
        for tn, amt in pairs(t) do if targetIsBoss[tn] then useful = useful + amt end end
        rows[#rows + 1] = { name = name, byTarget = t, total = playerTotal[name] or 0, useful = useful }
    end
    table.sort(rows, function(a, b)
        if a.useful ~= b.useful then return a.useful > b.useful end
        if a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)
    local totRow = { name = "Total", isTotal = true, byTarget = {}, total = 0, useful = 0 }
    for _, c in ipairs(cols) do totRow.byTarget[c.name] = c.amt; totRow.total = totRow.total + c.amt end
    for _, r in ipairs(rows) do totRow.useful = totRow.useful + r.useful end
    return { rows = rows, targetCols = cols, totalRow = totRow }
end

-- Un nome di spell e' un consumabile? (match per parola sul nome inglese)
function CL:IsConsumableName(name)
    if not name then return false end
    local n = string.lower(name)
    for _, pat in ipairs(CL_CONSUM_PATTERNS) do
        if string.find(n, pat, 1, true) then return true end
    end
    return false
end

-- Consumabili usati per giocatore (flask/food dalle liste curate, pozioni ed
-- elisir per nome). Un "uso" = un cast o un'aura: si prende il massimo fra i
-- due conteggi, cosi' una pozione con cast+aura non viene contata due volte.
function CL:AggConsumables(f)
    local flaskIds, foodIds = {}, {}
    for _, id in ipairs((RLSuite.buffData and RLSuite.buffData.flask) or {}) do flaskIds[id] = true end
    for _, id in ipairs((RLSuite.buffData and RLSuite.buffData.food) or {}) do foodIds[id] = true end
    local casts, auras, info, playerTotal = {}, {}, {}, {}
    local function bump(store, player, sid, name, kind)
        if not player then return end
        local key = tostring(sid or 0) .. "|" .. tostring(name or "?")
        info[key] = info[key] or { key = key, sid = sid, name = name or "?", kind = kind }
        store[player] = store[player] or {}
        store[player][key] = (store[player][key] or 0) + 1
    end
    for _, ev in ipairs(f.events) do
        local sub = ev[CL_E.SUB]
        local sid, sname = ev[CL_E.SID], ev[CL_E.SNAME]
        if sub == "SPELL_AURA_APPLIED" and self:IsRaidGroupFlag(ev[CL_E.DSTF]) then
            if flaskIds[sid] then
                bump(auras, ev[CL_E.DST], sid, sname or "Flask", "flask")
            elseif foodIds[sid] then
                bump(auras, ev[CL_E.DST], sid, sname or "Well Fed", "food")
            elseif self:IsConsumableName(sname) then
                bump(auras, ev[CL_E.DST], sid, sname, "other")
            end
        elseif sub == "SPELL_CAST_SUCCESS" and self:IsRaidGroupFlag(ev[CL_E.SRCF]) then
            if self:IsConsumableName(sname) then bump(casts, ev[CL_E.SRC], sid, sname, "potion") end
        elseif (sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL")
            and ev[CL_E.SRC] == ev[CL_E.DST] and self:IsConsumableName(sname) then
            bump(auras, ev[CL_E.SRC], sid, sname, "potion")
        end
    end
    local cells, totals = {}, {}
    for player, t in pairs(auras) do
        for key, n in pairs(t) do
            local c = (casts[player] and casts[player][key]) or 0
            if c > n then n = c end
            cells[player] = cells[player] or {}
            cells[player][key] = n
            totals[key] = (totals[key] or 0) + n
            playerTotal[player] = (playerTotal[player] or 0) + n
        end
    end
    for player, t in pairs(casts) do
        for key, n in pairs(t) do
            if not (cells[player] and cells[player][key]) then
                cells[player] = cells[player] or {}
                cells[player][key] = n
                totals[key] = (totals[key] or 0) + n
                playerTotal[player] = (playerTotal[player] or 0) + n
            end
        end
    end
    local cols = {}
    for key, n in pairs(totals) do
        local i = info[key] or { key = key, name = "?" }
        i.key = key; i.amt = n; i.count = n
        cols[#cols + 1] = i
    end
    table.sort(cols, function(a, b)
        if a.kind ~= b.kind then return tostring(a.kind) < tostring(b.kind) end
        if a.amt ~= b.amt then return a.amt > b.amt end
        return tostring(a.name) < tostring(b.name)
    end)
    local players = {}
    for name, n in pairs(playerTotal) do players[#players + 1] = { name = name, uses = n } end
    table.sort(players, function(a, b)
        if a.uses ~= b.uses then return a.uses > b.uses end
        return a.name < b.name
    end)
    return { cells = cells, cols = cols, players = players }
end

-- Matrice aure per (giocatore, spellId): applicazioni + uptime%.
function CL:AggAuraMatrix(f)
    local dur = self:FightDuration(f)
    if dur <= 0 then dur = 1 end
    local open, cells, info, auraTotal, playerTotal = {}, {}, {}, {}, {}
    local function cell(p, sid)
        local t = cells[p]
        if not t then t = {}; cells[p] = t end
        local c = t[sid]
        if not c then c = { count = 0, up = 0 }; t[sid] = c end
        return c
    end
    for _, ev in ipairs(f.events) do
        local sub = ev[CL_E.SUB]
        local sid = ev[CL_E.SID]
        if sid and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_APPLIED_DOSE"
            or sub == "SPELL_AURA_REMOVED" or sub == "SPELL_AURA_REMOVED_DOSE"
            or sub == "SPELL_AURA_BROKEN_SPELL") then
            local dst, k = ev[CL_E.DST], sid .. "|" .. tostring(ev[CL_E.DST])
            if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_APPLIED_DOSE" then
                local st = open[k]
                if not st then
                    st = { t = ev[CL_E.T], n = 0, sid = sid, dst = dst,
                           raid = self:IsRaidGroupFlag(ev[CL_E.DSTF]) and true or false }
                    open[k] = st
                end
                if st.n == 0 then st.t = ev[CL_E.T] end
                st.n = st.n + 1
                if st.raid and dst and sub == "SPELL_AURA_APPLIED" then
                    cell(dst, sid).count = cell(dst, sid).count + 1
                end
                if dst then info[sid] = info[sid] or { sid = sid, name = ev[CL_E.SNAME] } end
            else
                local st = open[k]
                if st then
                    if sub == "SPELL_AURA_REMOVED_DOSE" and st.n > 1 then
                        st.n = st.n - 1
                    else
                        local dt = ev[CL_E.T] - st.t
                        open[k] = nil
                        if st.raid and st.dst and dt > 0 then
                            local c = cell(st.dst, sid)
                            c.up = c.up + dt
                            auraTotal[sid] = (auraTotal[sid] or 0) + dt
                            playerTotal[st.dst] = (playerTotal[st.dst] or 0) + dt
                        end
                    end
                end
            end
        end
    end
    -- aure ancora aperte a fine fight: contate fino alla fine del pull
    for _, st in pairs(open) do
        if st.raid and st.dst then
            local dt = dur - st.t
            if dt > 0 then
                local c = cell(st.dst, st.sid)
                c.up = c.up + dt
                auraTotal[st.sid] = (auraTotal[st.sid] or 0) + dt
                playerTotal[st.dst] = (playerTotal[st.dst] or 0) + dt
            end
        end
    end
    local cols = {}
    for sid, up in pairs(auraTotal) do
        local i = info[sid] or { sid = sid, name = "?" }
        i.up = up; i.amt = up
        cols[#cols + 1] = i
    end
    table.sort(cols, function(a, b)
        if a.up ~= b.up then return a.up > b.up end
        return tostring(a.name) < tostring(b.name)
    end)
    local players = {}
    for name, up in pairs(playerTotal) do
        players[#players + 1] = { name = name, up = up }
    end
    for _, p in ipairs(players) do p.pct = math.min(100, p.up / dur * 100) end
    table.sort(players, function(a, b)
        if a.up ~= b.up then return a.up > b.up end
        return a.name < b.name
    end)
    return { cells = cells, cols = cols, players = players, duration = dur }
end

-- Somma di una tabella di numeri (utility per i totali di colonna).
function sumAll(t)
    local n = 0
    for _, v in pairs(t or {}) do n = n + (v or 0) end
    return n
end

-- Matrice potere per (giocatore, spell che ha energizzato) + totali.
function CL:AggPowerMatrix(f)
    local cells, info, totals, playerTotal = {}, {}, {}, {}
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == "energize" and self:IsRaidGroupFlag(ev[CL_E.DSTF]) then
            local dst, sid, sname = ev[CL_E.DST], ev[CL_E.SID], ev[CL_E.SNAME]
            local amt = ev[CL_E.AMT] or 0
            if dst then
                local key = tostring(sid or 0) .. "|" .. tostring(sname or "?")
                info[key] = info[key] or { key = key, sid = sid, name = sname or "?",
                    ptype = CL_POWER_NAMES[ev[CL_E.PTYPE]] or ("Power " .. tostring(ev[CL_E.PTYPE] or "?")) }
                local t = cells[dst]
                if not t then t = {}; cells[dst] = t end
                t[key] = (t[key] or 0) + amt
                totals[key] = (totals[key] or 0) + amt
                playerTotal[dst] = (playerTotal[dst] or 0) + amt
            end
        end
    end
    local cols = {}
    for key, amt in pairs(totals) do
        local i = info[key] or { key = key, name = "?" }
        i.amt = amt
        cols[#cols + 1] = i
    end
    table.sort(cols, function(a, b)
        if a.amt ~= b.amt then return a.amt > b.amt end
        return tostring(a.name) < tostring(b.name)
    end)
    local players = {}
    for name, amt in pairs(playerTotal) do players[#players + 1] = { name = name, amt = amt } end
    table.sort(players, function(a, b)
        if a.amt ~= b.amt then return a.amt > b.amt end
        return a.name < b.name
    end)
    return { cells = cells, cols = cols, players = players, total = sumAll(totals) }
end

-- Morti del raid (nome, istante, chi ha dato il colpo finale).
function CL:AggDeaths(f)
    local out = {}
    for _, ev in ipairs(f.events) do
        if ev[CL_E.SUB] == "UNIT_DIED" and ev[CL_E.DST]
            and self:IsPlayerFlag(ev[CL_E.DSTF]) and self:IsRaidGroupFlag(ev[CL_E.DSTF]) then
            out[#out + 1] = { name = ev[CL_E.DST], t = ev[CL_E.T], killer = nil }
        end
    end
    -- Colpo finale: un solo passaggio sugli eventi (l'ultimo danno ricevuto
    -- da ciascun morto PRIMA della sua morte).
    local last = {}
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == "damage" and ev[CL_E.DST] then
            local cur = last[ev[CL_E.DST]]
            local t = ev[CL_E.T] or 0
            if not cur or t >= cur.t then last[ev[CL_E.DST]] = { t = t, src = ev[CL_E.SRC] } end
        end
    end
    for _, d in ipairs(out) do
        local l = last[d.name]
        if l and l.t <= (d.t or 0) then d.killer = l.src end
        d.lastHit = l and l.t or nil
    end
    table.sort(out, function(a, b) return (a.t or 0) < (b.t or 0) end)
    return out
end

-- "Flag" della riga di dettaglio (come la colonna FLAG di UwU: il come).
local CL_DEATH_FLAG = {
    SWING_DAMAGE = "SWING", RANGE_DAMAGE = "RANGE", SPELL_DAMAGE = "SPELL",
    SPELL_PERIODIC_DAMAGE = "PERIODIC", DAMAGE_SHIELD = "SHIELD",
    DAMAGE_SPLIT = "SPLIT", ENVIRONMENTAL_DAMAGE = "ENV",
    SPELL_HEAL = "SPELL", SPELL_PERIODIC_HEAL = "HOT",
    SPELL_CAST_SUCCESS = "SUCCESS", SPELL_CAST_START = "START",
    SPELL_AURA_APPLIED = "APPLIED", SPELL_AURA_REMOVED = "REMOVED",
}

-- Dettaglio di una morte: la morte + gli ultimi secondi di colpi/cure subiti.
function CL:DeathDetail(f, name, tDeath, window)
    window = tonumber(window) or 12
    tDeath = tonumber(tDeath) or 0
    local rows = { {
        t = tDeath, rel = 0, kind = "DIED", flag = "", src = "", spell = "",
        val = "", over = "", isDeath = true,
    } }
    for _, ev in ipairs(f.events) do
        local et = ev[CL_E.T] or 0
        if et <= tDeath and et >= (tDeath - window) and ev[CL_E.DST] == name then
            local cat = CL_CATS[ev[CL_E.SUB]]
            if cat == "damage" or cat == "heal" or cat == "cast" then
                local val = ev[CL_E.AMT]
                rows[#rows + 1] = {
                    t = et, rel = et - tDeath,
                    kind = (cat == "damage" and "DAMAGE") or (cat == "heal" and "HEAL") or "CAST",
                    flag = CL_DEATH_FLAG[ev[CL_E.SUB]] or "",
                    src = ev[CL_E.SRC] or "",
                    spell = ev[CL_E.SNAME] or "",
                    val = val and tostring(val) or "",
                    over = (ev[CL_E.OVER] and ev[CL_E.OVER] > 0) and tostring(ev[CL_E.OVER]) or "",
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if (a.t or 0) ~= (b.t or 0) then return (a.t or 0) > (b.t or 0) end
        return (a.kind or "") < (b.kind or "")
    end)
    return rows
end

-- "m:ss.mmm" (con segno) per le righe del death recap.
function CL:RelStamp(dt)
    local neg = (dt or 0) < 0
    local a = math.abs(dt or 0)
    local m = math.floor(a / 60)
    local s = a - m * 60
    return string.format("%s%d:%06.3f", neg and "-" or "", m, s)
end

-- Fight "unito" dei segmenti di un boss ("All Lady Deathwhisper segments"):
-- copia gli eventi dei pull di quel boss su una linea temporale continua.
function CL:MergedFight(bossName, maxFights)
    local db = self.db or {}
    local list = {}
    for _, f in ipairs(db.fights or {}) do
        if (f.name or "Combat") == bossName then list[#list + 1] = f end
    end
    if #list == 0 then return nil end
    maxFights = tonumber(maxFights) or 8
    -- db.fights e' "il piu' recente per primo": tengo i piu' recenti e li
    -- concateno in ORDINE CRONOLOGICO (il piu' vecchio per primo).
    while #list > maxFights do table.remove(list) end
    local chrono = {}
    for i = #list, 1, -1 do chrono[#chrono + 1] = list[i] end
    list = chrono
    local out = {
        merged = true, name = bossName, events = {}, count = 0,
        duration = 0, kill = false, startUTC = list[1] and list[1].startUTC or nil,
        player = list[1] and list[1].player or nil,
        samples = { health = {}, power = {} }, boss = bossName,
    }
    out.segments = #list
    local off = 0
    for _, f in ipairs(list) do
        local d = self:FightDuration(f)
        for i = 1, (f.count or #(f.events or {})) do
            local ev = f.events[i]
            if ev then
                local c = {}
                for k = 1, 17 do c[k] = ev[k] end
                c[CL_E.T] = (ev[CL_E.T] or 0) + off
                out.count = out.count + 1
                out.events[out.count] = c
            end
        end
        for kind, store in pairs(out.samples) do
            local src = (f.samples or {})[kind]
            for key, arr in pairs(src or {}) do
                local dst = store[key]
                if not dst then dst = {}; store[key] = dst end
                for _, pt in ipairs(arr) do dst[#dst + 1] = { (pt[1] or 0) + off, pt[2] } end
            end
        end
        off = off + d
        if f.kill then out.kill = true end
    end
    out.duration = off
    out.kill = out.kill and true or false
    out.startTime = 0
    return out
end

-- Serie DPS per il grafico: bucket per step secondi (fill zeri).
-- step = 0 -> "Avg whole fight": media CUMULATIVA (danno fino a t / t secondi),
-- la curva che sale e si appiattisce come nel grafico di UwU Logs.
function CL:DpsSeries(f, srcName, step)
    step = tonumber(step) or 1
    local running = (step <= 0)
    local bucket = running and 1 or step
    local buckets, maxB = {}, 0
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == "damage" and self:IsRaidGroupFlag(ev[CL_E.SRCF]) then
            if srcName == nil or ev[CL_E.SRC] == srcName then
                local b = math.floor((ev[CL_E.T] or 0) / bucket)
                buckets[b] = (buckets[b] or 0) + (ev[CL_E.AMT] or 0)
                if b > maxB then maxB = b end
            end
        end
    end
    local pts = {}
    if running then
        local cum = 0
        for b = 0, maxB do
            cum = cum + (buckets[b] or 0)
            pts[#pts + 1] = { b + 1, cum / (b + 1) }
        end
    else
        for b = 0, maxB do
            pts[#pts + 1] = { b * step, (buckets[b] or 0) / step }
        end
    end
    -- decimazione se troppi punti (max ~400 segmenti draw)
    local MAXPTS = 400
    if #pts > MAXPTS then
        local stride = math.ceil(#pts / MAXPTS)
        local dec = {}
        for i = 1, #pts, stride do dec[#dec + 1] = pts[i] end
        pts = dec
    end
    return pts
end

function CL:SampleSeries(f, kind, key)
    local s = f and f.samples and f.samples[kind]
    local arr = s and s[key]
    if not arr then return {} end
    return arr
end

function CL:FightPlayers(f)
    local seen, out = {}, {}
    for _, ev in ipairs(f.events) do
        for _, io in ipairs({ { ev[CL_E.SRC], ev[CL_E.SRCF] }, { ev[CL_E.DST], ev[CL_E.DSTF] } }) do
            local nm, fl = io[1], io[2]
            if nm and not seen[nm] and self:IsPlayerFlag(fl) and self:IsRaidGroupFlag(fl) then
                seen[nm] = true
                out[#out + 1] = nm
            end
        end
    end
    table.sort(out)
    return out
end

-- ------------------------------------------------------------------
-- Graph widget (port del concetto ExLib.CreateGraph: assi, serie,
-- linee verticali evento, max label, hover tooltip, zoom a trascina)
-- ------------------------------------------------------------------
local function SetSolidColor(tex, r, g, b, a)
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    tex:SetVertexColor(r, g, b, a or 1)
end

function CL:NewGraph(parent, w, h)
    local g = CreateFrame("Button", nil, parent)
    g:SetSize(w, h)
    g:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    g.width, g.height = w, h

    g.axisX = g:CreateTexture(nil, "BACKGROUND")
    g.axisX:SetSize(w, 2)
    g.axisX:SetPoint("TOPLEFT", g, "BOTTOMLEFT", 0, 0)
    SetSolidColor(g.axisX, 0.6, 0.6, 1, 1)
    g.axisY = g:CreateTexture(nil, "BACKGROUND")
    g.axisY:SetSize(2, h)
    g.axisY:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, 0)
    SetSolidColor(g.axisY, 0.6, 0.6, 1, 1)

    g.maxText = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    g.maxText:SetPoint("TOPRIGHT", g.axisY, "TOPLEFT", -2, -2)
    g.maxText:SetText("")

    g._linePool = {}          -- colonne del riempimento (area sotto la curva)
    g._capPool = {}           -- "linea" luminosa sopra ogni colonna
    g._gridPool = {}          -- righe di griglia orizzontali
    g._vlinePool = {}

    -- Valore della serie interpolato in un punto x (usata sia dal disegno sia
    -- dal tooltip del mouse). Le serie sono ordinate per x.
    g.ValueAt = function(s, xv)
        local pts = s.series
        if not pts or #pts == 0 then return nil end
        if xv <= (pts[1][1] or 0) then return pts[1][2] or 0 end
        local n = #pts
        if xv >= (pts[n][1] or 0) then return pts[n][2] or 0 end
        local lo, hi = 1, n
        while hi - lo > 1 do
            local mid = math.floor((lo + hi) / 2)
            if (pts[mid][1] or 0) <= xv then lo = mid else hi = mid end
        end
        local x1, v1 = pts[lo][1] or 0, pts[lo][2] or 0
        local x2, v2 = pts[hi][1] or 0, pts[hi][2] or 0
        if x2 <= x1 then return v2 end
        local t = (xv - x1) / (x2 - x1)
        return v1 + (v2 - v1) * t
    end

    g:EnableMouse(true)
    -- Lettura al passaggio del mouse (come negli addon seri): tempo + valore
    -- nel punto sotto il cursore.
    g:SetScript("OnUpdate", function(s, elapsed)
        if not s._hoverOn then return end
        s._tipT = (s._tipT or 0) + (elapsed or 0)
        if s._tipT < 0.08 then return end
        s._tipT = 0
        if not (GetCursorPosition and s.series and #s.series > 0 and GameTooltip) then return end
        local scale = (s.GetEffectiveScale and s:GetEffectiveScale()) or 1
        local mx = (select(1, GetCursorPosition()) or 0) / scale
        local px = mx - (s:GetLeft() or 0) - 2
        local plotW = s.width - 4
        if px < 0 or px > plotW then
            s._tipX = nil
            GameTooltip:Hide()
            return
        end
        local x0, x1 = s.xMin or 0, s.xMax or 1
        local xv = x0 + (x1 - x0) * (px / plotW)
        local v = s:ValueAt(xv)
        s._tipX = xv
        local unit = (s.opts and s.opts.unit) or "DPS"
        local total = math.floor(xv)
        GameTooltip:SetOwner(s, "ANCHOR_CURSOR")
        if GameTooltip.ClearLines then GameTooltip:ClearLines() end
        GameTooltip:AddLine(string.format("%d:%02d", math.floor(total / 60), total % 60))
        GameTooltip:AddLine(CL:ShortNum(v) .. " " .. unit, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    g:SetScript("OnEnter", function(s) s._hoverOn = true end)
    g:SetScript("OnLeave", function(s)
        s._hoverOn = false
        s._tipX = nil
        if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)
    g:SetScript("OnMouseDown", function(s)
        local x = select(1, GetCursorPosition()) or 0
        local scale = (s.GetEffectiveScale and s:GetEffectiveScale()) or 1
        s._zoomStartX = x / scale - (s:GetLeft() or 0)
    end)
    g:SetScript("OnMouseUp", function(s)
        if not s._zoomStartX then return end
        local x = select(1, GetCursorPosition()) or 0
        local scale = (s.GetEffectiveScale and s:GetEffectiveScale()) or 1
        local x2 = x / scale - (s:GetLeft() or 0)
        local a, b = math.min(s._zoomStartX, x2), math.max(s._zoomStartX, x2)
        s._zoomStartX = nil
        local x0, x1 = s.xMin or 0, s.xMax or 1
        local span = x1 - x0
        if b - a > 20 then
            s.xMin = x0 + span * (a / s.width)
            s.xMax = x0 + span * (b / s.width)
            s:Reload()
        else
            -- click singolo: reset zoom
            s.xMin, s.xMax = s._fullXMin or 0, s._fullXMax or 1
            s:Reload()
        end
    end)

    g.SetData = function(s, series, vlines, opts)
        s.series = series or {}
        s.vlines = vlines or {}
        s.opts = opts or {}
        -- range completo
        local xMax = 1
        for _, p in ipairs(s.series) do
            local x = p[1] or 0
            if x > xMax then xMax = x end
        end
        s._fullXMin, s._fullXMax = 0, xMax
        s.xMin, s.xMax = 0, xMax
        s:Reload()
    end

    -- ------------------------------------------------------------
    -- DISEGNO. Prima qui si provava a tracciare una POLILINEA: ogni tratto
    -- era una texture ruotata con Texture:SetRotation. Ma SetRotation ruota
    -- il DISEGNO dentro la texture, non il rettangolo: su un colore pieno
    -- (WHITE8x8) non cambia assolutamente niente, quindi tutti i tratti
    -- restavano orizzontali -> "l'accrocchio di barrette" invece della linea.
    -- Ora si disegna come fanno Recount/Skada: colonne verticali che
    -- riempiono l'area sotto la curva, con una linea luminosa sul bordo
    -- superiore. Nessuna rotazione richiesta, e la curva e' CONTINUA.
    -- ------------------------------------------------------------
    local COL_W = 2                     -- larghezza di una colonna (px)
    local PADX, PADY = 2, 2

    g.Reload = function(s)
        for _, t in ipairs(s._linePool) do t:Hide() end
        for _, t in ipairs(s._capPool) do t:Hide() end
        for _, t in ipairs(s._gridPool) do t:Hide() end
        for _, t in ipairs(s._vlinePool) do t:Hide() end

        local x0, x1 = s.xMin or 0, s.xMax or 1
        local span = x1 - x0
        if span <= 0 then span = 1 end
        local plotW = s.width - 2 * PADX
        local plotH = s.height - 2 * PADY

        -- massimo nel range visibile (scala Y)
        local yMax = 0
        for _, p in ipairs(s.series) do
            local x, y = p[1] or 0, p[2] or 0
            if x >= x0 and x <= x1 and y > yMax then yMax = y end
        end
        -- ai bordi conta anche il valore interpolato (la curva puo' salire
        -- subito dopo l'inizio del range)
        local vA, vB = s:ValueAt(x0), s:ValueAt(x1)
        if (vA or 0) > yMax then yMax = vA end
        if (vB or 0) > yMax then yMax = vB end
        if yMax <= 0 then yMax = 1 end
        s.maxText:SetText(CL:ShortNum(yMax))
        s._yMax, s._yScale = yMax, plotH / yMax

        -- griglia orizzontale al 25/50/75% (100% e' il massimo)
        local gi = 0
        for q = 1, 3 do
            gi = gi + 1
            local tex = s._gridPool[gi]
            if not tex then
                tex = s:CreateTexture(nil, "BACKGROUND")
                s._gridPool[gi] = tex
            end
            SetSolidColor(tex, 0.6, 0.6, 1, 0.12)
            local y = (q / 4) * plotH
            tex:ClearAllPoints()
            tex:SetSize(plotW + PADX, 1)
            tex:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", PADX, PADY + y)
            tex:Show()
        end

        -- CURVA: una colonna ogni COL_W px, dal basso fino al valore
        local cols = math.floor(plotW / COL_W)
        local used = 0
        if cols > 0 and s.series and #s.series > 0 then
            for i = 0, cols - 1 do
                local xa = x0 + span * (i / cols)
                local xb = x0 + span * ((i + 1) / cols)
                -- valore interpolato al centro della colonna E ai due bordi:
                -- l'inviluppo [min..max] rende la linea continua (nessun
                -- gradino visibile, anche con serie crescenti ripide)
                local vc = s:ValueAt((xa + xb) / 2) or 0
                local vb2 = s:ValueAt(xb) or 0
                local vTop = vc > vb2 and vc or vb2
                local vBot = vc < vb2 and vc or vb2
                local hTop = vTop * s._yScale
                local hBot = vBot * s._yScale
                if hTop < 1 then hTop = 1 end

                used = used + 1
                local fill = s._linePool[used]
                if not fill then
                    fill = s:CreateTexture(nil, "ARTWORK")
                    s._linePool[used] = fill
                end
                SetSolidColor(fill, 0.16, 0.75, 0.32, 0.45)
                fill:ClearAllPoints()
                fill:SetSize(COL_W, hTop)
                fill:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT",
                    PADX + i * COL_W, PADY)
                fill:Show()

                -- "linea": span verticale fra i due estremi della colonna,
                -- cosi' il bordo superiore e' la curva vera (interpolata)
                local cap = s._capPool[used]
                if not cap then
                    cap = s:CreateTexture(nil, "OVERLAY")
                    s._capPool[used] = cap
                end
                SetSolidColor(cap, 0.35, 1, 0.55, 0.95)
                cap:ClearAllPoints()
                cap:SetSize(COL_W, math.max(2, hTop - hBot))
                cap:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT",
                    PADX + i * COL_W, PADY + hBot)
                cap:Show()
            end
        end
        for i = used + 1, #s._linePool do s._linePool[i]:Hide() end
        for i = used + 1, #s._capPool do s._capPool[i]:Hide() end

        -- lens verticale sotto il cursore (lettura del grafico)
        if s._tipX and s._hoverOn then
            local gi2 = #s._gridPool + 1
            local tex = s._gridPool[gi2]
            if not tex then
                tex = s:CreateTexture(nil, "OVERLAY")
                s._gridPool[gi2] = tex
            end
            SetSolidColor(tex, 1, 1, 1, 0.45)
            local px = (s._tipX - x0) / span * plotW + PADX
            tex:ClearAllPoints()
            tex:SetSize(1, plotH)
            tex:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", px, PADY)
            tex:Show()
        end

        -- vline eventi (morti, ecc.)
        for i, vt in ipairs(s.vlines) do
            local x = vt[1] or 0
            if x >= x0 and x <= x1 then
                local tex = s._vlinePool[i]
                if not tex then
                    tex = s:CreateTexture(nil, "OVERLAY")
                    s._vlinePool[i] = tex
                end
                SetSolidColor(tex, 1, 0.25, 0.25, 0.65)
                local px = (x - x0) / span * plotW + PADX
                tex:ClearAllPoints()
                tex:SetSize(2, plotH)
                tex:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", px, PADY)
                tex:Show()
            end
        end
    end

    return g
end

-- ------------------------------------------------------------------
-- UI (v1.11.63) — layout stile UwU Logs
--   [durata + nome boss + esito + ora]              [player] [fight ▼]
--   [Show graph] [Avg whole fight ▼] [DPS][Health][Power]  <etichetta>
--   +------------------------- GRAFICO (altezza fissa) ----------------+
--   [Damage][Targets][Consumables][Auras][Deaths][Powers][...]
--   +------------------------- contenuto del tab ----------------------+
--   [Send report][Clear][Live]  info
-- ------------------------------------------------------------------
local CL_ROW_H = 18
local CL_GRID_ROW_H = 20
local CL_WIN_W, CL_WIN_H = 900, 660
local CL_PAD = 14
local CL_TAB_W, CL_TAB_GAP = 78, 5
local CL_GRAPH_H = 150
-- larghezza utile di una griglia a tutta larghezza (finestra - margini -
-- barra di scorrimento verticale)
local CL_GRID_W = CL_WIN_W - 2 * CL_PAD - 34
local CL_TABS_Y = -218
local CL_CONTENT_Y = -244
local CL_FOOTER_H = 42

local CL_UI_TABS = {
    { key = "damage",      label = "Damage" },
    { key = "targets",     label = "Targets" },
    { key = "consumables", label = "Consumables" },
    { key = "auras",       label = "Auras" },
    { key = "deaths",      label = "Deaths" },
    { key = "powers",      label = "Powers" },
    { key = "healing",     label = "Healing" },
    { key = "spells",      label = "Spells" },
    { key = "enemies",     label = "Entities" },
    { key = "interrupts",  label = "Interrupts" },
}
-- Tab disegnati con la GRIGLIA (gli altri usano le due liste storiche).
local CL_GRID_TABS = {
    damage = true, targets = true, consumables = true, auras = true, powers = true,
}

-- Discretizzazioni del grafico (terzo screen di UwU): 0 = media dell'intero
-- fight (curva cumulativa), poi bucket da 1/2/3/5/10 secondi.
local CL_GRAPH_STEPS = {
    { step = 0,  text = "Avg whole fight" },
    { step = 1,  text = "Avg every second" },
    { step = 2,  text = "Avg every 2 seconds" },
    { step = 3,  text = "Avg every 3 seconds" },
    { step = 5,  text = "Avg every 5 seconds" },
    { step = 10, text = "Avg every 10 seconds" },
}

-- Esposte anche fuori dal file (test/debug): ordine dei tab e passi del grafico.
CL.uiTabs = CL_UI_TABS
CL.graphSteps = CL_GRAPH_STEPS

local function Trunc(s, n)
    s = tostring(s or "")
    if #s > n then s = s:sub(1, n - 1) .. "." end
    return s
end

-- ==================================================================
-- Testo che sta DENTRO la larghezza della colonna: niente word wrap (andando
-- a capo il testo usciva dall'altezza riga e si sovrapponeva alla riga sotto,
-- da cui le tabelle "incasinate" della v1.11.63) e troncamento misurato.
local function FitText(fs, text, w)
    fs:SetText(text or "")
    if not fs.GetStringWidth or not w or w < 8 then return end
    local sw = fs:GetStringWidth() or 0
    if sw <= w then return end
    local t = tostring(text or "")
    local n = math.max(1, math.floor(#t * w / sw) - 1)
    for _ = 1, 8 do
        fs:SetText(t:sub(1, n) .. "..")
        sw = fs:GetStringWidth() or 0
        if sw <= w or n <= 1 then break end
        n = n - 1
    end
end
CL.FitText = FitText

-- GRIGLIA riutilizzabile: header (testo o icona, con tooltip) + righe
-- scrollabili. cols = { {label=, w=, fix=, align=, kind=, ic=, tip=}, ... }
-- rows[i] = { {t=, r=,g=,b=, frac=, barR=,barG=,barB=, tip=}, ... , name= }
-- ==================================================================
function CL:NewGrid(parent, name)
    local g = CreateFrame("Frame", nil, parent)
    g:SetAllPoints(parent)
    g.hdr = CreateFrame("Frame", nil, g)
    g.hdr:SetPoint("TOPLEFT", g, "TOPLEFT", 4, 0)
    g.hdr:SetPoint("TOPRIGHT", g, "TOPRIGHT", -26, 0)
    g.hdr:SetHeight(24)
    -- NOME OBBLIGATORIO: in 3.3.5 ScrollFrame_OnLoad fa
    -- self:GetName().."ScrollBar", quindi uno ScrollFrame SENZA nome con
    -- UIPanelScrollFrameTemplate va in errore ("attempt to concatenate a nil
    -- value", UIPanelTemplates.lua:255) e blocca il load dell'addon.
    g.scroll = CreateFrame("ScrollFrame", name, g, "UIPanelScrollFrameTemplate")
    g.scroll:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -24)
    g.scroll:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -26, 4)
    g.content = CreateFrame("Frame", nil, g.scroll)
    g.content:SetWidth(400)
    g.content:SetHeight(1)
    g.scroll:SetScrollChild(g.content)
    RLSuite.utils:RegisterScrollClip(g.scroll, g.content)
    g.hdrPool = {}
    g.pool = {}
    return g
end

-- Larghezze: le colonne "fix" hanno w in pixel, le altre w = peso sul resto.
function CL:GridMeasure(g, cols, width)
    local avail = (width or CL_GRID_W) - 6
    local fixed, flex = 0, 0
    for _, c in ipairs(cols) do
        c.w = tonumber(c.w) or 60          -- mai aritmetica su nil
        if c.fix then fixed = fixed + c.w else flex = flex + c.w end
    end
    local free = avail - fixed
    if free < 40 then free = 40 end
    local x = 0
    for _, c in ipairs(cols) do
        c.x = x
        c.px = c.fix and c.w or ((flex > 0) and (c.w / flex * free) or 0)
        if c.px < 20 then c.px = 20 end
        x = x + c.px
    end
    return x
end

function CL:MakeGridRow(g, n, rownum)
    local row = CreateFrame("Button", nil, g.content)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")
    row:SetHeight(CL_GRID_ROW_H)
    row.cells = {}
    for i = 1, n do
        local c = {}
        c.row = row
        c.bar = row:CreateTexture(nil, "BACKGROUND")
        c.fill = row:CreateTexture(nil, "ARTWORK")
        c.fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        -- una riga, sempre: mai testo a capo dentro una cella
        if c.fs.SetWordWrap then c.fs:SetWordWrap(false) end
        if c.fs.SetNonSpaceWrap then c.fs:SetNonSpaceWrap(false) end
        if c.fs.SetMaxLines then c.fs:SetMaxLines(1) end
        if c.fs.SetJustifyV then c.fs:SetJustifyV("MIDDLE") end
        c.bar:Hide(); c.fill:Hide()
        row.cells[i] = c
    end
    -- Striscia di sfondo (riga TOTAL / zebra): sotto le barre, stessa area.
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetDrawLayer("BACKGROUND", -8)
    row.stripe:SetAllPoints(row)
    row.stripe:Hide()
    return row
end

function CL:GridRender(g, cols, rows, opt)
    if not (g and cols) then return end
    opt = opt or {}
    rows = rows or {}
    -- Larghezza = quella VERA della griglia a schermo (la finestra si puo'
    -- ridimensionare): se non e' ancora nota si usa il valore di progetto.
    local width = opt.width
    local live = (g.GetWidth and g:GetWidth()) or 0
    if live and live > 200 then width = live - 30 end   -- barra di scorrimento
    if not width or width < 200 then width = CL_GRID_W end
    local totalW = self:GridMeasure(g, cols, width)
    g.content:SetWidth(math.max(1, totalW))
    g.cols = cols

    -- HEADER
    for i, c in ipairs(cols) do
        local h = g.hdrPool[i]
        if not h then
            local btn = CreateFrame("Button", nil, g.hdr)
            btn:EnableMouse(true)
            btn:SetHeight(24)
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn:SetScript("OnEnter", function(s)
                if s._tip then
                    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
                    pcall(function()
                        GameTooltip:SetText(s._tip)
                        GameTooltip:Show()
                    end)
                end
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            h = { btn = btn }
            g.hdrPool[i] = h
        end
        local btn = h.btn
        btn._tip = c.tip or c.label
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", g.hdr, "TOPLEFT", c.x, 0)
        btn:SetSize(math.max(18, c.px), 24)
        if c.ic then
            btn.icon:SetTexture(c.ic)
            btn.icon:ClearAllPoints()
            btn.icon:SetSize(18, 18)
            btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.icon:Show()
            btn.fs:SetText("")
            btn.fs:Hide()
        else
            btn.icon:Hide()
            btn.fs:ClearAllPoints()
            if c.align == "RIGHT" then
                btn.fs:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                btn.fs:SetJustifyH("RIGHT")
            elseif c.align == "CENTER" then
                btn.fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
                btn.fs:SetJustifyH("CENTER")
            else
                btn.fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
                btn.fs:SetJustifyH("LEFT")
            end
            btn.fs:SetWidth(math.max(18, c.px - 8))
            btn.fs:SetTextColor(1, 0.82, 0)
            btn.fs:Show()
            FitText(btn.fs, c.label or "", math.max(18, c.px - 8))
        end
        btn:Show()
    end
    for i = #cols + 1, #g.hdrPool do g.hdrPool[i].btn:Hide() end

    -- RIGHE (pool per numero di colonne)
    local key = #cols
    local pool = g.pool[key]
    if not pool then
        pool = {}
        g.pool[key] = pool
    end
    for _, r in ipairs(pool) do r:Hide() end
    RLSuite.utils:ClearScrollClip(g.content)
    local y = 0
    for ri, data in ipairs(rows) do
        local row = pool[ri]
        if not row then
            row = self:MakeGridRow(g, key, ri)
            pool[ri] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", g.content, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", g.content, "TOPRIGHT", 0, -y)
        RLSuite.utils:ClipScrollRow(g.content, row, y, CL_GRID_ROW_H)
        for ci, c in ipairs(cols) do
            local cell = row.cells[ci]
            local d = data[ci]
            if not d then
                cell.fs:SetText("")
                cell.bar:Hide(); cell.fill:Hide()
            else
                cell.fs:ClearAllPoints()
                if c.align == "RIGHT" then
                    cell.fs:SetPoint("RIGHT", row, "LEFT", c.x + c.px - 4, 0)
                    cell.fs:SetJustifyH("RIGHT")
                elseif c.align == "CENTER" then
                    cell.fs:SetPoint("CENTER", row, "LEFT", c.x + c.px / 2, 0)
                    cell.fs:SetJustifyH("CENTER")
                else
                    cell.fs:SetPoint("LEFT", row, "LEFT", c.x + 4, 0)
                    cell.fs:SetJustifyH("LEFT")
                end
                local cw = math.max(18, c.px - 8)
                cell.fs:SetWidth(cw)
                FitText(cell.fs, d.t or "", cw)
                cell.fs:SetTextColor(d.r or 1, d.g or 1, d.b or 1)
                cell.fs:Show()
                if c.kind == "bar" then
                    local frac = d.frac or 0
                    if frac > 1 then frac = 1 end
                    if frac < 0 then frac = 0 end
                    local bw = math.max(2, c.px - 8)
                    local bw2 = math.max(1, bw * frac)
                    cell.bar:ClearAllPoints()
                    cell.bar:SetSize(bw, CL_GRID_ROW_H - 2)
                    cell.bar:SetPoint("LEFT", row, "LEFT", c.x + 4, 0)
                    cell.bar:SetTexture(0.06, 0.06, 0.06, 0.55)
                    cell.fill:ClearAllPoints()
                    cell.fill:SetSize(bw2, CL_GRID_ROW_H - 2)
                    cell.fill:SetPoint("LEFT", row, "LEFT", c.x + 4, 0)
                    cell.fill:SetTexture(d.barR or 0.72, d.barG or 0.12, d.barB or 0.12, 0.55)
                    cell.bar:Show(); cell.fill:Show()
                else
                    cell.bar:Hide(); cell.fill:Hide()
                end
            end
        end
        if data.isTotal then
            row.stripe:SetTexture(0.35, 0.3, 0.6, 0.25)
            row.stripe:Show()
        elseif ri % 2 == 0 then
            row.stripe:SetTexture(1, 1, 1, 0.04)
            row.stripe:Show()
        else
            row.stripe:Hide()
        end
        local tip = data.tip
        if tip then
            row:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                pcall(function()
                    GameTooltip:SetText(tip)
                    if data.tip2 then GameTooltip:AddLine(data.tip2, 0.85, 0.85, 0.85) end
                    GameTooltip:Show()
                end)
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
        end
        if opt.onClick and data.name then
            row:SetScript("OnClick", function() opt.onClick(data) end)
        else
            row:SetScript("OnClick", nil)
        end
        row:Show()
        y = y + CL_GRID_ROW_H
    end
    g.content:SetHeight(math.max(y, 1))
    g.rowCount = #rows
    RLSuite.utils:RefreshScrollClip(g.content)
    if g.hint then g.hint:SetText(opt.hint or "") end
end

-- ==================================================================
-- COSTRUZIONE DEI TAB (tornano cols, rows pronti per GridRender)
-- ==================================================================

-- Colonna "barra" con il numero in fondo: utile per i valori di danno.
local function BarCell(self, v, maxv, txt, r, g, b)
    local frac = (maxv and maxv > 0) and (v / maxv) or 0
    return { t = txt or self:ShortNum(v), frac = frac, barR = r, barG = g, barB = b }
end

-- 1) DAMAGE: la tabella principale (screen 1 di UwU).
function CL:BuildDamageTab(f)
    local st = self:AggPlayerStats(f)
    local dur = st.duration
    local tot = st.total
    local maxU, maxH, maxT = 1, 1, 1
    for _, a in ipairs(st.rows) do
        if a.useful > maxU then maxU = a.useful end
        if a.heal > maxH then maxH = a.heal end
        if a.taken > maxT then maxT = a.taken end
    end
    if tot.useful > maxU then maxU = tot.useful end
    if tot.heal > maxH then maxH = tot.heal end
    if tot.taken > maxT then maxT = tot.taken end
    local cols = {
        { label = "Name", w = 1.7, tip = "Giocatore" },
        { label = "Rank", w = 0.42, align = "RIGHT", tip = "Posizione in classifica" },
        { label = "Dps%", w = 0.8, align = "RIGHT", tip = "DPS sul danno UTILE (danno ai boss / durata)" },
        { label = "Useful Damage", w = 1.5, align = "RIGHT", kind = "bar",
          tip = "Danno ai BOSS (danno utile). Passa il mouse su una riga per il dettaglio" },
        { label = "Heal", w = 1.3, align = "RIGHT", kind = "bar", tip = "Cure fatte" },
        { label = "Damage Taken", w = 1.5, align = "RIGHT", kind = "bar", tip = "Danno subito" },
    }
    local rows = {
        { -- riga TOTAL (in per-secondo come UwU)
            { t = "Total", r = 1, g = 0.82, b = 0 },
            { t = "" },
            { t = self:ShortNum(tot.useful / dur), r = 1, g = 1, b = 1 },
            BarCell(self, tot.useful, maxU, self:ShortNum(tot.useful), 0.72, 0.12, 0.12),
            BarCell(self, tot.heal, maxH, self:ShortNum(tot.heal), 0.12, 0.6, 0.2),
            BarCell(self, tot.taken, maxT, self:ShortNum(tot.taken), 0.72, 0.12, 0.12),
            isTotal = true, name = nil,
            tip = string.format("TOTALE raid — durata %d:%02d", math.floor(dur / 60), math.floor(dur % 60)),
            tip2 = "Dps% = danno utile al secondo. Heal/Damage Taken per giocatore sono valori grezzi.",
        },
    }
    for i, a in ipairs(st.rows) do
        local r, g, b = self:ClassColor(a.name)
        rows[#rows + 1] = {
            { t = a.name, r = r, g = g, b = b },
            { t = tostring(i) },
            { t = string.format("%.1f", a.useful / dur) },
            BarCell(self, a.useful, maxU, self:ShortNum(a.useful), 0.72, 0.12, 0.12),
            BarCell(self, a.heal, maxH, self:ShortNum(a.heal), 0.12, 0.6, 0.2),
            BarCell(self, a.taken, maxT, self:ShortNum(a.taken), 0.72, 0.12, 0.12),
            name = a.name,
            tip = a.name,
            tip2 = string.format("Danno utile %s (%.1f dps) | totale %s | cure %s | subito %s",
                self:ShortNum(a.useful), a.useful / dur, self:ShortNum(a.total),
                self:ShortNum(a.heal), self:ShortNum(a.taken)),
        }
    end
    return cols, rows
end

-- 2) TARGETS: danno per giocatore e per bersaglio (screen 4).
function CL:BuildTargetsTab(f)
    local tg = self:AggTargets(f)
    local nameW, fixW = 132, 74
    local free = CL_GRID_W - nameW - 2 * fixW
    local n = math.floor(free / 92)
    if n < 1 then n = 1 end
    if n > #tg.targetCols then n = #tg.targetCols end
    local w = math.min((n > 0) and (free / n) or 92, 110)
    local cols = {
        { label = "Name", w = nameW, fix = true, tip = "Giocatore" },
        { label = "Useful", w = fixW, fix = true, align = "RIGHT", tip = "Danno ai boss (utile)" },
        { label = "Total", w = fixW, fix = true, align = "RIGHT", tip = "Danno totale su NPC" },
    }
    for i = 1, n do
        local c = tg.targetCols[i]
        cols[#cols + 1] = {
            label = Trunc(c.name, (c.boss and 13) or 14),
            w = w, fix = true, align = "RIGHT",
            tip = c.name .. (c.boss and "  (BOSS: conta come danno utile)" or "  (spazzino)"),
        }
    end
    local maxv = 1
    for _, r in ipairs(tg.rows) do if r.total > maxv then maxv = r.total end end
    local rows = {}
    for i, r in ipairs(tg.rows) do
        local rr, gg, bb = self:ClassColor(r.name)
        local line = {
            { t = i .. ". " .. r.name, r = rr, g = gg, b = bb },
            { t = self:ShortNum(r.useful), r = 1, g = 0.85, b = 0.4 },
            { t = self:ShortNum(r.total) },
        }
        for ci = 1, n do
            local amt = r.byTarget[tg.targetCols[ci].name]
            line[#line + 1] = { t = amt and self:ShortNum(amt) or "",
                r = amt and 1 or 0.5, g = amt and 1 or 0.5, b = amt and 1 or 0.5 }
        end
        line.name = r.name
        line.tip = r.name
        line.tip2 = string.format("Utile %s | totale %s — click: grafico su questo giocatore",
            self:ShortNum(r.useful), self:ShortNum(r.total))
        rows[#rows + 1] = line
    end
    local tot = tg.totalRow
    local trow = {
        { t = "Total", r = 1, g = 0.82, b = 0 },
        { t = self:ShortNum(tot.useful), r = 1, g = 0.85, b = 0.4 },
        { t = self:ShortNum(tot.total) },
    }
    for ci = 1, n do
        local amt = tot.byTarget[tg.targetCols[ci].name] or 0
        trow[#trow + 1] = { t = self:ShortNum(amt) }
    end
    trow.isTotal = true
    rows[#rows + 1] = trow
    if #tg.targetCols > n then
        cols.tip = string.format("%d bersagli in piu' non entrano nella larghezza", #tg.targetCols - n)
    end
    return cols, rows
end

-- 3) CONSUMABLES: flask/food/pozioni per giocatore (screen 5).
function CL:BuildConsumablesTab(f)
    local ag = self:AggConsumables(f)
    local nameW, usesW = 150, 56
    local free = CL_GRID_W - nameW - usesW
    local n = math.floor(free / 46)
    if n < 1 then n = 1 end
    if n > #ag.cols then n = #ag.cols end
    local w = math.min((n > 0) and (free / n) or 46, 56)
    local cols = {
        { label = "Name", w = nameW, fix = true, tip = "Giocatore" },
        { label = "Uses", w = usesW, fix = true, align = "RIGHT", tip = "Consumabili usati in totale" },
    }
    for i = 1, n do
        local c = ag.cols[i]
        local tex
        if GetSpellTexture and c.sid then
            local ok, t = pcall(GetSpellTexture, c.sid)
            if ok then tex = t end
        end
        cols[#cols + 1] = { label = "", w = w, fix = true, align = "CENTER", ic = tex,
            tip = c.name .. (c.kind and ("  [" .. tostring(c.kind) .. "]") or "") }
    end
    local rows = {}
    for i, p in ipairs(ag.players) do
        local rr, gg, bb = self:ClassColor(p.name)
        local line = {
            { t = i .. ". " .. p.name, r = rr, g = gg, b = bb },
            { t = tostring(p.uses), r = 1, g = 0.82, b = 0 },
        }
        for ci = 1, n do
            local key = ag.cols[ci].key
            local cnt = ag.cells[p.name] and ag.cells[p.name][key] or nil
            line[#line + 1] = { t = cnt and tostring(cnt) or "",
                r = cnt and 1 or 0.45, g = cnt and 0.9 or 0.45, b = cnt and 0.4 or 0.45 }
        end
        line.name = p.name
        line.tip = p.name
        line.tip2 = string.format("%d consumabili usati", p.uses)
        rows[#rows + 1] = line
    end
    if #rows == 0 then rows[1] = { { t = "No consumables detected" } } end
    return cols, rows
end

-- 4) AURAS: applicazioni + uptime% per giocatore (screen 6).
function CL:BuildAurasTab(f)
    local am = self:AggAuraMatrix(f)
    local dur = am.duration
    local nameW = 150
    local free = CL_GRID_W - nameW
    local n = math.floor(free / 66)
    if n < 1 then n = 1 end
    if n > #am.cols then n = #am.cols end
    local w = math.min((n > 0) and (free / n) or 66, 78)
    local cols = { { label = "Name", w = nameW, fix = true, tip = "Giocatore" } }
    for i = 1, n do
        local c = am.cols[i]
        local tex
        if GetSpellTexture and c.sid then
            local ok, t = pcall(GetSpellTexture, c.sid)
            if ok then tex = t end
        end
        cols[#cols + 1] = { label = "", w = w, fix = true, align = "CENTER", ic = tex,
            tip = (c.name or "?") .. "  (applicazioni / uptime)" }
    end
    local rows = {}
    for i, p in ipairs(am.players) do
        local rr, gg, bb = self:ClassColor(p.name)
        local line = {
            { t = i .. ". " .. p.name, r = rr, g = gg, b = bb },
        }
        for ci = 1, n do
            local sid = am.cols[ci].sid
            local cell = am.cells[p.name] and am.cells[p.name][sid] or nil
            if cell and (cell.count > 0 or cell.up > 0) then
                local pct = math.min(100, cell.up / dur * 100)
                line[#line + 1] = { t = string.format("%d  %.0f%%", cell.count or 0, pct),
                    r = 0.5, g = 1, b = 0.6 }
            else
                line[#line + 1] = { t = "", r = 0.45, g = 0.45, b = 0.45 }
            end
        end
        line.name = p.name
        line.tip = p.name
        line.tip2 = string.format("%d aure tracciate, uptime totale %.0fs", #am.cols, p.up or 0)
        rows[#rows + 1] = line
    end
    if #rows == 0 then rows[1] = { { t = "No auras detected" } } end
    return cols, rows
end

-- 5) POWERS: risorsa generata per giocatore e per spell (screen 8).
function CL:BuildPowersTab(f)
    local pm = self:AggPowerMatrix(f)
    local nameW, totW = 150, 84
    local free = CL_GRID_W - nameW - totW
    local n = math.floor(free / 66)
    if n < 1 then n = 1 end
    if n > #pm.cols then n = #pm.cols end
    local w = math.min((n > 0) and (free / n) or 66, 78)
    local cols = { { label = "Name", w = nameW, fix = true, tip = "Giocatore" } }
    for i = 1, n do
        local c = pm.cols[i]
        local tex
        if GetSpellTexture and c.sid then
            local ok, t = pcall(GetSpellTexture, c.sid)
            if ok then tex = t end
        end
        cols[#cols + 1] = { label = "", w = w, fix = true, align = "RIGHT", ic = tex,
            tip = (c.name or "?") .. (c.ptype and ("  (" .. c.ptype .. ")") or "") }
    end
    cols[#cols + 1] = { label = "TOTAL", w = totW, fix = true, align = "RIGHT", tip = "Risorsa totale generata" }
    local rows = {}
    for i, p in ipairs(pm.players) do
        local rr, gg, bb = self:ClassColor(p.name)
        local line = {
            { t = i .. ". " .. p.name, r = rr, g = gg, b = bb },
        }
        for ci = 1, n do
            local key = pm.cols[ci].key
            local amt = pm.cells[p.name] and pm.cells[p.name][key] or nil
            line[#line + 1] = { t = amt and self:ShortNum(amt) or "",
                r = amt and 0.5 or 0.45, g = amt and 0.8 or 0.45, b = amt and 1 or 0.45 }
        end
        line[#line + 1] = { t = self:ShortNum(p.amt), r = 1, g = 0.82, b = 0 }
        line.name = p.name
        line.tip = p.name
        line.tip2 = string.format("Risorsa totale %s", self:ShortNum(p.amt))
        rows[#rows + 1] = line
    end
    local trow = { { t = "Total", r = 1, g = 0.82, b = 0 } }
    for ci = 1, n do
        local key = pm.cols[ci].key
        local s = 0
        for _, p in ipairs(pm.players) do
            if pm.cells[p.name] and pm.cells[p.name][key] then s = s + pm.cells[p.name][key] end
        end
        trow[#trow + 1] = { t = self:ShortNum(s), r = 1, g = 1, b = 1 }
    end
    trow[#trow + 1] = { t = self:ShortNum(pm.total), r = 1, g = 1, b = 1 }
    trow.isTotal = true
    rows[#rows + 1] = trow
    if #rows == 1 then rows[1] = { { t = "No power events" } } end
    return cols, rows
end

-- 6) DEATHS: a sinistra i morti, a destra il recap dei colpi (screen 7).
function CL:BuildDeathDetail(f, death)
    local cols = {
        { label = "Time", w = 86, fix = true, tip = "Tempo relativo alla morte" },
        { label = "Flag", w = 76, fix = true, tip = "Tipo di evento" },
        { label = "Source", w = 1.1, tip = "Chi ha agito" },
        { label = "Spell", w = 1.4, tip = "Spell" },
        { label = "Type", w = 76, fix = true, tip = "Come (SPELL/SUCCESS/HOT/SWING...)" },
        { label = "Value", w = 84, fix = true, align = "RIGHT", tip = "Valore" },
        { label = "Over/Stacks", w = 96, fix = true, align = "RIGHT", tip = "Overkill / overheal / stacks" },
    }
    local rows = {}
    if not death then
        rows[1] = { { t = "Select a death" } }
        return cols, rows
    end
    local drows = self:DeathDetail(f, death.name, death.t, 12)
    local flagColor = {
        DIED = { 1, 0.3, 0.3 }, DAMAGE = { 1, 0.45, 0.45 },
        HEAL = { 0.35, 1, 0.45 }, CAST = { 0.6, 0.8, 1 },
    }
    for _, d in ipairs(drows) do
        local c = flagColor[d.kind] or { 1, 1, 1 }
        local line = {
            { t = (d.isDeath and "0:00.000") or self:RelStamp(d.rel or 0), r = c[1], g = c[2], b = c[3] },
            { t = d.kind or "", r = c[1], g = c[2], b = c[3] },
            { t = d.src or "", r = 0.9, g = 0.9, b = 0.9 },
            { t = d.spell or "" },
            { t = d.flag or "", r = 0.7, g = 0.7, b = 0.7 },
            { t = d.val or "" },
            { t = d.over or "", r = 1, g = 0.6, b = 0.4 },
        }
        rows[#rows + 1] = line
    end
    return cols, rows
end

-- Riga a due testi (liste storiche + lista dei morti).
local function MakeRow(parent, onClick)
    local row = CreateFrame("Button", nil, parent)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")
    row:SetHeight(CL_ROW_H)
    row.txt1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.txt1:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.txt1:SetJustifyH("LEFT")
    row.txt2 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.txt2:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.txt2:SetJustifyH("RIGHT")
    if onClick then row:SetScript("OnClick", onClick) end
    return row
end

function CL:_FillRows(content, poolName, rows, paintFn, clickFn)
    local pool = self[poolName] or {}
    self[poolName] = pool
    for _, r in ipairs(pool) do r:Hide() end
    RLSuite.utils:ClearScrollClip(content)
    local y = 0
    for i, data in ipairs(rows or {}) do
        local row = pool[i]
        if not row then
            row = MakeRow(content, nil)
            pool[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        RLSuite.utils:ClipScrollRow(content, row, y, CL_ROW_H)
        paintFn(row, data, i)
        if clickFn then
            row:SetScript("OnClick", function() clickFn(data) end)
        else
            row:SetScript("OnClick", nil)
        end
        row:Show()
        y = y + CL_ROW_H
    end
    content:SetHeight(math.max(y, 1))
    RLSuite.utils:RefreshScrollClip(content)
end

-- ==================================================================
-- TAB GROUP: un contenitore unico con i tab ATTACCATI (stile Blizzard).
-- Nomi: RLSuiteCombatLogTabs / RLSuiteCombatLogTabsTab<i> -> cosi' funziona
-- anche PanelTemplates (che cerca <parent>Tab<id> per evidenziare l'attivo).
-- ==================================================================
function CL:BuildTabGroup(parent)
    local group = CreateFrame("Frame", "RLSuiteCombatLogTabs", parent)
    group:SetPoint("TOPLEFT", parent, "TOPLEFT", CL_PAD, CL_TABS_Y)
    group:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -CL_PAD, CL_TABS_Y)
    group:SetHeight(26)
    -- strip unica sotto i tab: il gruppo si legge come UNA barra di tab
    local bg = group:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(group)
    bg:SetTexture(0.06, 0.06, 0.10, 0.9)
    self.tabGroup = group
    self.tabBtns = {}
    self.tabOrder = {}
    for i, def in ipairs(CL_UI_TABS) do
        local name = "RLSuiteCombatLogTabsTab" .. i
        local ok, btn = pcall(CreateFrame, "Button", name, group, "CharacterFrameTabButtonTemplate")
        if not ok or type(btn) ~= "table" then
            -- template dei tab non disponibile: ripiego su un pulsante (il
            -- gruppo resta unico e i tab restano attaccati: overlap 0)
            btn = CreateFrame("Button", name, group, "UIPanelButtonTemplate")
            RLSuite.utils:SkinButton(btn)
            btn._plainTab = true
        end
        btn:SetID(i)
        btn:SetText(L[def.label])
        btn.tabKey = def.key
        btn._sel = btn:CreateTexture(nil, "OVERLAY")
        btn._sel:SetAllPoints(btn)
        btn._sel:SetTexture(0.25, 0.5, 1, 0.30)
        btn._sel:Hide()
        btn:SetScript("OnClick", function() CL:SelectTab(def.key) end)
        self.tabBtns[def.key] = btn
        self.tabOrder[i] = def
    end
    if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, group, #self.tabOrder) end
    group:SetScript("OnSizeChanged", function() CL:LayoutTabs() end)
    self:LayoutTabs()
    return group
end

-- I tab riempiono ESATTAMENTE la larghezza del gruppo e si toccano (con il
-- template di Blizzard si sovrappongono di 16px, come i tab del client).
function CL:LayoutTabs()
    local group = self.tabGroup
    if not (group and self.tabOrder and #self.tabOrder > 0) then return end
    local n = #self.tabOrder
    local first = self.tabBtns[self.tabOrder[1].key]
    local ov = (first and first._plainTab) and 0 or 16
    local w = (group.GetWidth and group:GetWidth()) or 0
    if not w or w < 100 then w = CL_WIN_W - 2 * CL_PAD end
    local tabW = math.floor((w + ov * (n - 1)) / n)
    local prev
    for i, def in ipairs(self.tabOrder) do
        local b = self.tabBtns[def.key]
        b:ClearAllPoints()
        if i == 1 then
            b:SetPoint("LEFT", group, "LEFT", 0, 0)
        else
            b:SetPoint("LEFT", prev, "RIGHT", -ov, 0)
        end
        b:SetWidth(tabW)
        if not b._plainTab then b:SetHeight(26) end
        -- anche l'etichetta del tab non deve mai andare a capo
        local fst = b.GetFontString and b:GetFontString()
        if fst then
            if fst.SetWordWrap then fst:SetWordWrap(false) end
            if fst.SetNonSpaceWrap then fst:SetNonSpaceWrap(false) end
            FitText(fst, L[def.label], math.max(20, tabW - 16))
        end
        prev = b
    end
    group._tabW = tabW
    group._tabOverlap = ov
end

-- ==================================================================
-- FINESTRA
-- ==================================================================
function CL:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteCombatLog", UIParent)
    f:SetSize(CL_WIN_W, CL_WIN_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    f._noOuterBorder = true
    self.frame = f
    RLSuite.utils:SkinFrame(f)
    RLSuite.utils:ClampWindow(f)

    -- ---- riga 1: nome del fight (durata, boss, esito) + dropdown a destra
    self.titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("TOPLEFT", f, "TOPLEFT", CL_PAD, -8)
    self.titleText:SetJustifyH("LEFT")
    self.titleText:SetText(L["Combat log"])

    self.subText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.subText:SetJustifyH("RIGHT")
    self.subText:SetText("")
    -- ancorato a SINISTRA del dropdown: data/player non finiscono mai
    -- sotto o dentro il selettore dei fight (era il caso a finestra larga)

    self.fightDropdown = RLSuite.utils:CreateDropdown(f, "RLSuiteCombatLogFightDD", 244, 20)
    self.fightDropdown:ClearAllPoints()
    -- bordo destro a -28: lascia libera la X di chiusura (11px a -4)
    self.fightDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -8)
    self.subText:SetPoint("RIGHT", self.fightDropdown, "LEFT", -10, -4)

    -- ---- riga 2: controllo del grafico
    self.showGraphCheck = CreateFrame("CheckButton", "RLSuiteCombatLogShowGraph", f, "UICheckButtonTemplate")
    self.showGraphCheck:SetSize(20, 20)
    self.showGraphCheck:SetPoint("TOPLEFT", f, "TOPLEFT", CL_PAD, -36)
    self.showGraphCheck:SetChecked(true)
    local gLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gLbl:SetPoint("LEFT", self.showGraphCheck, "RIGHT", 2, 0)
    gLbl:SetText(L["Show graph"])
    self.showGraphCheck:SetScript("OnClick", function(btn)
        CL.showGraph = btn:GetChecked() and true or false
        if CL.graphPane then
            if CL.showGraph then CL.graphPane:Show() else CL.graphPane:Hide() end
        end
    end)

    self.stepDropdown = RLSuite.utils:CreateDropdown(f, "RLSuiteCombatLogStepDD", 170, 20)
    self.stepDropdown:ClearAllPoints()
    self.stepDropdown:SetPoint("LEFT", gLbl, "RIGHT", 12, 0)

    self.graphModeBtns = {}
    for i, m in ipairs({ "dps", "health", "power" }) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        RLSuite.utils:SkinButton(b)
        b:SetSize(58, 20)
        b:SetPoint("LEFT", self.stepDropdown, "RIGHT", 8 + (i - 1) * 60, 0)
        b:SetText(L[m == "dps" and "DPS" or (m == "health" and "Health" or "Power")])
        b.graphMode = m
        b:SetScript("OnClick", function() CL.graphMode = m; CL:RefreshGraph() end)
        self.graphModeBtns[m] = b
    end

    self.graphHint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.graphHint:SetPoint("LEFT", self.graphModeBtns.power, "RIGHT", 10, 0)
    self.graphHint:SetJustifyH("LEFT")
    self.graphHint:SetTextColor(1, 0.82, 0)

    -- ---- grafico: SEMPRE visibile, altezza fissa
    self.graphPane = CreateFrame("Frame", nil, f)
    self.graphPane:SetPoint("TOPLEFT", f, "TOPLEFT", CL_PAD, -62)
    self.graphPane:SetPoint("TOPRIGHT", f, "TOPRIGHT", -CL_PAD, -62)
    self.graphPane:SetHeight(CL_GRAPH_H)
    RLSuite.utils:SkinBox(self.graphPane)
    self.graph = self:NewGraph(self.graphPane, CL_WIN_W - 2 * CL_PAD - 44, CL_GRAPH_H - 22)
    self.graph:SetPoint("TOPLEFT", self.graphPane, "TOPLEFT", 30, -14)

    -- ---- TAB GROUP (un solo gruppo di tab, non pulsanti sparsi)
    self:BuildTabGroup(f)

    -- ---- contenuto: griglia / due liste storiche / morti
    self.gridPane = CreateFrame("Frame", nil, f)
    self.gridPane:SetPoint("TOPLEFT", f, "TOPLEFT", CL_PAD, CL_CONTENT_Y)
    self.gridPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -CL_PAD, CL_FOOTER_H)
    RLSuite.utils:SkinBox(self.gridPane)
    self.grid = self:NewGrid(self.gridPane, "RLSuiteCombatLogGrid")
    self.grid.hint = self.gridPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.grid.hint:SetPoint("BOTTOMLEFT", self.gridPane, "BOTTOMLEFT", 6, 4)
    self.grid.hint:SetTextColor(0.8, 0.8, 0.8)

    self.legacyPane = CreateFrame("Frame", nil, f)
    self.legacyPane:SetPoint("TOPLEFT", f, "TOPLEFT", CL_PAD, CL_CONTENT_Y)
    self.legacyPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -CL_PAD, CL_FOOTER_H)

    self.leftHeader = self.legacyPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.leftHeader:SetPoint("TOPLEFT", self.legacyPane, "TOPLEFT", 8, -2)
    self.leftHeader:SetText("")

    self.leftBox = CreateFrame("Frame", nil, self.legacyPane)
    self.leftBox:SetPoint("TOPLEFT", self.legacyPane, "TOPLEFT", 0, -18)
    self.leftBox:SetPoint("BOTTOMLEFT", self.legacyPane, "BOTTOMLEFT", 0, 0)
    self.leftBox:SetWidth(300)
    RLSuite.utils:SkinBox(self.leftBox)
    self.leftScroll = CreateFrame("ScrollFrame", "RLSuiteCombatLogLeft", self.leftBox, "UIPanelScrollFrameTemplate")
    self.leftScroll:SetPoint("TOPLEFT", 4, -4)
    self.leftScroll:SetPoint("BOTTOMRIGHT", -24, 4)
    self.leftContent = CreateFrame("Frame", nil, self.leftScroll)
    self.leftContent:SetWidth(264)
    self.leftContent:SetHeight(1)
    self.leftScroll:SetScrollChild(self.leftContent)
    RLSuite.utils:RegisterScrollClip(self.leftScroll, self.leftContent)

    self.rightHeader = self.legacyPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.rightHeader:SetPoint("TOPLEFT", self.legacyPane, "TOPLEFT", 320, -2)
    self.rightHeader:SetText("")

    self.rightBox = CreateFrame("Frame", nil, self.legacyPane)
    self.rightBox:SetPoint("TOPLEFT", self.legacyPane, "TOPLEFT", 312, -18)
    self.rightBox:SetPoint("BOTTOMRIGHT", self.legacyPane, "BOTTOMRIGHT", 0, 0)
    RLSuite.utils:SkinBox(self.rightBox)
    self.rightScroll = CreateFrame("ScrollFrame", "RLSuiteCombatLogRight", self.rightBox, "UIPanelScrollFrameTemplate")
    self.rightScroll:SetPoint("TOPLEFT", 4, -4)
    self.rightScroll:SetPoint("BOTTOMRIGHT", -24, 4)
    self.rightContent = CreateFrame("Frame", nil, self.rightScroll)
    self.rightContent:SetWidth(470)
    self.rightContent:SetHeight(1)
    self.rightScroll:SetScrollChild(self.rightContent)
    RLSuite.utils:RegisterScrollClip(self.rightScroll, self.rightContent)

    -- ---- tab DEATHS: lista a sinistra + recap a destra
    self.deathPane = CreateFrame("Frame", nil, f)
    self.deathPane:SetPoint("TOPLEFT", f, "TOPLEFT", CL_PAD, CL_CONTENT_Y)
    self.deathPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -CL_PAD, CL_FOOTER_H)

    self.deathHeader = self.deathPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.deathHeader:SetPoint("TOPLEFT", self.deathPane, "TOPLEFT", 8, -2)
    self.deathHeader:SetText("")

    self.deathListBox = CreateFrame("Frame", nil, self.deathPane)
    self.deathListBox:SetPoint("TOPLEFT", self.deathPane, "TOPLEFT", 0, -18)
    self.deathListBox:SetPoint("BOTTOMLEFT", self.deathPane, "BOTTOMLEFT", 0, 0)
    self.deathListBox:SetWidth(170)
    RLSuite.utils:SkinBox(self.deathListBox)
    self.deathScroll = CreateFrame("ScrollFrame", "RLSuiteCombatLogDeaths", self.deathListBox, "UIPanelScrollFrameTemplate")
    self.deathScroll:SetPoint("TOPLEFT", 4, -4)
    self.deathScroll:SetPoint("BOTTOMRIGHT", -24, 4)
    self.deathContent = CreateFrame("Frame", nil, self.deathScroll)
    self.deathContent:SetWidth(134)
    self.deathContent:SetHeight(1)
    self.deathScroll:SetScrollChild(self.deathContent)
    RLSuite.utils:RegisterScrollClip(self.deathScroll, self.deathContent)

    self.deathDetailHeader = self.deathPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.deathDetailHeader:SetPoint("TOPLEFT", self.deathPane, "TOPLEFT", 188, -2)
    self.deathDetailHeader:SetText("")

    self.deathDetailBox = CreateFrame("Frame", nil, self.deathPane)
    self.deathDetailBox:SetPoint("TOPLEFT", self.deathPane, "TOPLEFT", 180, -18)
    self.deathDetailBox:SetPoint("BOTTOMRIGHT", self.deathPane, "BOTTOMRIGHT", 0, 0)
    RLSuite.utils:SkinBox(self.deathDetailBox)
    self.deathGrid = self:NewGrid(self.deathDetailBox, "RLSuiteCombatLogDeathGrid")
    self.deathGrid.hint = self.deathDetailBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.deathGrid.hint:SetPoint("BOTTOMLEFT", self.deathDetailBox, "BOTTOMLEFT", 6, 4)
    self.deathGrid.hint:SetTextColor(0.8, 0.8, 0.8)

    -- ---- footer
    self.reportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.reportBtn)
    self.reportBtn:SetSize(100, 24)
    self.reportBtn:SetText(L["Send report"])
    self.reportBtn:SetScript("OnClick", function() CL:SendReport() end)
    self.reportBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", CL_PAD, 10)

    self.clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.clearBtn)
    self.clearBtn:SetSize(70, 24)
    self.clearBtn:SetPoint("LEFT", self.reportBtn, "RIGHT", 6, 0)
    self.clearBtn:SetText(L["Clear"])
    self.clearBtn:SetScript("OnClick", function()
        if IsShiftKeyDown and IsShiftKeyDown() then
            if CL.db and CL.db.fights then
                for k in pairs(CL.db.fights) do CL.db.fights[k] = nil end
            end
            CL.selFight = nil
            CL.selSegment = nil
            CL._mergeStamp = (CL._mergeStamp or 0) + 1
            CL:RefreshUI()
        else
            RLSuite.utils:Print(L["Shift+click to wipe the saved fights."])
        end
    end)

    self.liveCheck = CreateFrame("CheckButton", "RLSuiteCombatLogLive", f, "UICheckButtonTemplate")
    self.liveCheck:SetSize(20, 20)
    self.liveCheck:SetPoint("LEFT", self.clearBtn, "RIGHT", 8, 0)
    self.liveCheck:SetScript("OnClick", function(btn)
        CL.liveUpdate = btn:GetChecked() and true or false
        if CL.liveUpdate then CL:EnsureLiveTicker() end
    end)
    local liveLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    liveLbl:SetPoint("LEFT", self.liveCheck, "RIGHT", 2, 0)
    liveLbl:SetText(L["Live"])

    self.infoText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.infoText:SetPoint("LEFT", liveLbl, "RIGHT", 14, 0)
    self.infoText:SetJustifyH("LEFT")
    self.infoText:SetText("")

    f.closeBtn = RLSuite.utils:MakeCloseX(f, function() f:Hide() end)
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    self.showGraph = true
    self.gridPane:Hide()
    self.legacyPane:Hide()
    self.deathPane:Hide()
    self:SelectTab(self.selTab or "damage")

    f:SetScript("OnShow", function() CL:RefreshUI() end)
end

function CL:SkinInner()
    RLSuite.utils:SkinBox(self.gridPane)
    RLSuite.utils:SkinBox(self.leftBox)
    RLSuite.utils:SkinBox(self.rightBox)
    RLSuite.utils:SkinBox(self.deathListBox)
    RLSuite.utils:SkinBox(self.deathDetailBox)
    RLSuite.utils:SkinBox(self.graphPane)
end

-- Ticker "live" (2s): aggiorna la vista durante il fight registrato.
function CL:EnsureLiveTicker()
    if self._liveTicker then return end
    self._liveTicker = self:ScheduleRepeatingTimer(function()
        if not CL.liveUpdate then return end
        if CL.current and CL.frame and CL.frame:IsShown() and not CL.selSegment then
            CL.selFight = CL.current
            CL:RefreshUI()
        end
    end, 2)
end

-- ------------------------------------------------------------------
-- Etichette dei fight + dropdown
-- ------------------------------------------------------------------
function CL:FightDurationLabel(f)
    local dur = self:FightDuration(f)
    local mm = math.floor(dur / 60)
    local ss = dur - mm * 60
    return string.format("%d:%06.3f", mm, ss)
end

-- Prefisso taglia+difficolta' ("10N"/"25H") quando e' deducibile.
function CL:FightSizeTag(f)
    local n = tonumber(f and f.raidSize) or 0
    if n < 10 then return "" end
    local size = (n >= 20) and "25" or "10"
    local d = tonumber(f and f.difficulty)
    local tag = ""
    if d == 1 then tag = "N" elseif d == 2 then tag = "N"
    elseif d == 3 then tag = "H" elseif d == 4 then tag = "H" end
    return size .. tag
end

function CL:FightLabel(f, idx)
    local tag = (f.kill and "Kill") or (f.kill == false and "Wipe") or ""
    return string.format("%s | %s  %s", self:FightDurationLabel(f), tag, Trunc(f.name or "Combat", 24))
end

-- Titolo grande in alto a sinistra: "0:02:31.994  10N Gunship  Wipe"
function CL:FightTitle(f)
    if not f then return L["Combat log"] end
    local tag = (f.kill and L["Kill"]) or (f.kill == false and L["Wipe"]) or ""
    local size = self:FightSizeTag(f)
    -- come lo screen di UwU: "0:02:31.994  Gunship 10H  Wipe"
    return string.format("%s  %s%s  %s", self:FightDurationLabel(f),
        f.name or "Combat", (size ~= "" and (" " .. size)) or "", tag)
end

function CL:FightListItems()
    local items = {}
    if self.current then
        items[#items + 1] = { text = L["[LIVE]"] .. " " .. (self.current.boss or "Combat"), value = self.current }
    end
    local seen, bosses = {}, {}
    for i, f in ipairs((self.db and self.db.fights) or {}) do
        items[#items + 1] = { text = self:FightLabel(f, i), value = f }
        local n = f.name or "Combat"
        if not seen[n] then
            seen[n] = true
            bosses[#bosses + 1] = n
        end
    end
    -- "All <boss> segments": tutti i pull di quel boss su una linea di tempo
    for _, n in ipairs(bosses) do
        items[#items + 1] = { text = string.format("All %s segments", n), value = { __segment = n } }
    end
    if #items == 0 then items[1] = { text = L["No fights recorded"], value = false } end
    return items
end

function CL:SelectFight(f)
    if type(f) == "table" and f.__segment then
        self.selSegment = f.__segment
        local merged = self:MergedFight(f.__segment)
        if merged then self.selFight = merged else self.selFight = nil end
    else
        if f ~= false then self.selFight = f end
        self.selSegment = nil
    end
    self.selSource = nil
    self.deathSel = nil
    self:RefreshUI()
end

function CL:SelectTab(key)
    self.selTab = key
    self.selSource = nil
    if CL_GRID_TABS[key] then
        self.gridPane:Show(); self.legacyPane:Hide(); self.deathPane:Hide()
    elseif key == "deaths" then
        self.gridPane:Hide(); self.legacyPane:Hide(); self.deathPane:Show()
    else
        self.gridPane:Hide(); self.legacyPane:Hide(); self.deathPane:Hide()
        self.legacyPane:Show()
    end
    -- stato del TAB GROUP: uno solo selezionato (PanelTemplates + evidenza
    -- nostra, cosi' si vede anche col template di ripiego)
    local idx
    for i, def in ipairs(self.tabOrder or {}) do
        local b = self.tabBtns[def.key]
        if def.key == key then idx = i end
        if b then
            if def.key == key then
                if b._sel then b._sel:Show() end
                b:LockHighlight()
                if b.SetChecked then pcall(b.SetChecked, b, true) end
            else
                if b._sel then b._sel:Hide() end
                b:UnlockHighlight()
                if b.SetChecked then pcall(b.SetChecked, b, false) end
            end
        end
    end
    if idx and PanelTemplates_SetTab and self.tabGroup then
        pcall(PanelTemplates_SetTab, self.tabGroup, idx)
    end
    self:RefreshUI()
end

-- Intestazione + dropdown dei fight.
function CL:RefreshHeader()
    local f = self.selFight
    self.titleText:SetText(self:FightTitle(f))
    if f then
        local when = (f.startUTC and date) and date("%d %b %y, %H:%M", f.startUTC) or ""
        local who = f.player or ""
        local txt = (when ~= "" and (when .. "  -  " .. who)) or who
        if f.merged then txt = string.format("segments: %d pull", f.segments or 0) end
        if f.interrupted then txt = txt .. "  (interrupted)" end
        self.subText:SetText(txt)
    else
        self.subText:SetText("")
    end
    local items = self:FightListItems()
    -- per un segmento il "valore corrente" e' la voce stessa (per TESTO):
    -- SetupDropdown confronta i value per riferimento, non per contenuto.
    local cur = f
    if self.selSegment then
        for _, it in ipairs(items) do
            if type(it.value) == "table" and it.value.__segment == self.selSegment then
                cur = it.text
            end
        end
    end
    RLSuite.utils:SetupDropdown(self.fightDropdown, items, cur, function(v)
        CL:SelectFight(v)
    end)
end

function CL:RefreshUI()
    if not self.frame then return end
    if not (self.titleText and self.gridPane) then return end
    self:RefreshHeader()
    self:EnsureLiveTicker()
    self:RefreshLists()
    self:RefreshGraph()
end

-- Riga di stato in basso (eventi registrati, scarti, dimensione dei dati).
function CL:RefreshInfo(f)
    if not f then
        self.infoText:SetText("")
        return
    end
    local dropped = (f.dropped and f.dropped > 0) and (" (+" .. f.dropped .. " " .. L["dropped"] .. ")") or ""
    self.infoText:SetText(string.format("%s | %d:%02d | %d %s%s",
        f.name or "Combat", math.floor(self:FightDuration(f) / 60), math.floor(self:FightDuration(f) % 60),
        f.count or #f.events, L["Events"], dropped))
end

-- Tab DEATHS: lista dei morti + recap della morte selezionata.
function CL:RefreshDeathPane(f)
    local deaths = self:AggDeaths(f)
    self.deathHeader:SetText(string.format("%s: %d", L["Deaths"], #deaths))
    if #deaths == 0 then
        self.deathSel = nil
    elseif not self.deathSel or not deaths[self.deathSel] then
        self.deathSel = 1
    end
    local rows = {}
    for i, d in ipairs(deaths) do
        rows[#rows + 1] = { name = d.name, idx = i, t = d.t, killer = d.killer }
    end
    self:_FillRows(self.deathContent, "_dRows", rows, function(row, d, i)
        row.txt1:SetText(i .. ". " .. (d.name or "?"))
        row.txt1:SetTextColor(1, 0.55, 0.55)
        row.txt2:SetText(string.format("%d:%02d  %s", math.floor((d.t or 0) / 60),
            math.floor((d.t or 0) % 60), Trunc(d.killer or "", 10)))
        if CL.deathSel == i then
            RLSuite.utils:SkinRow(row, true)
        else
            RLSuite.utils:SkinRow(row, false)
        end
    end, function(d)
        CL.deathSel = d.idx
        CL:RefreshDeathPane(CL.selFight)
    end)
    local sel = deaths[self.deathSel]
    local cols, drows = self:BuildDeathDetail(f, sel)
    self.deathDetailHeader:SetText(sel and string.format("%s  (killer: %s)", sel.name, sel.killer or "?") or "")
    self:GridRender(self.deathGrid, cols, drows, {})  -- larghezza viva del pannello
end

-- Tab storici (Healing / Players spells / Entities / Interrupts): due liste.
function CL:RefreshLegacyLists(f)
    local tab = self.selTab
    local sel = self.selSource
    if tab == "healing" or tab == "spells" then
        local cat = (tab == "healing") and "heal" or "cast"
        local rows, total = self:AggTotals(f, cat)
        self.leftHeader:SetText(((tab == "healing") and L["Healing"] or L["Players spells"])
            .. " — " .. L["Total"] .. ": " .. self:ShortNum(total))
        self:_FillRows(self.leftContent, "_lRows", rows, function(row, d, i)
            local pct = (total > 0) and (d.amt / total * 100) or 0
            row.txt1:SetText(i .. ". " .. d.name)
            row.txt2:SetText(string.format("%s %.1f%%", self:ShortNum(d.amt), pct))
            local rr, gg, bb = self:ClassColor(d.name)
            row.txt1:SetTextColor(rr, gg, bb)
            if sel == d.name then RLSuite.utils:SkinRow(row, true) else RLSuite.utils:SkinRow(row, false) end
        end, function(d)
            CL.selSource = (CL.selSource == d.name) and nil or d.name
            CL:RefreshLists()
        end)
        if sel then
            local srows, stotal = self:AggSpells(f, cat, sel)
            self.rightHeader:SetText(sel .. " — " .. ((cat == "cast") and L["Spells list"] or L["By cast"]))
            self:_FillRows(self.rightContent, "_rRows", srows, function(row, d, i)
                if cat == "cast" then
                    local sidTxt = (self.db.options and self.db.options.showSpellIds and d.sid) and (" [" .. d.sid .. "]") or ""
                    row.txt1:SetText(i .. ". " .. d.name .. sidTxt)
                    row.txt2:SetText(string.format("%d×", d.casts))
                else
                    local pct = (stotal > 0) and (d.amt / stotal * 100) or 0
                    row.txt1:SetText(i .. ". " .. d.name)
                    row.txt2:SetText(string.format("%s (%.1f%%)  %d×", self:ShortNum(d.amt), pct, d.casts))
                    if d.crits > 0 then
                        row.txt2:SetText(string.format("%s (%.1f%%) %d× %d crit",
                            self:ShortNum(d.amt), pct, d.casts, d.crits))
                    end
                end
                row.txt1:SetTextColor(1, 1, 1)
                RLSuite.utils:SkinRow(row, false)
                row:SetScript("OnEnter", function(s)
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    pcall(function()
                        GameTooltip:SetText(d.name)
                        GameTooltip:AddLine(string.format(
                            "Total %s | Hits %d | Crit %d", CL:ShortNum(d.amt), d.casts, d.crits), 1, 1, 1)
                        GameTooltip:AddLine(string.format(
                            "Overkill %s | Absorbed %s | Blocked %s",
                            CL:ShortNum(d.over), CL:ShortNum(d.abs), CL:ShortNum(d.blocked)), 0.8, 0.8, 0.8)
                        GameTooltip:Show()
                    end)
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end)
        else
            self.rightHeader:SetText(L["Select player"])
            self:_FillRows(self.rightContent, "_rRows", {}, function() end)
        end
    elseif tab == "enemies" then
        local rows, total = self:AggEnemies(f)
        self.leftHeader:SetText(L["Enemies"] .. " — " .. L["Total"] .. ": " .. self:ShortNum(total))
        self.rightHeader:SetText("")
        self:_FillRows(self.leftContent, "_lRows", rows, function(row, d, i)
            local pct = (total > 0) and (d.amt / total * 100) or 0
            row.txt1:SetText(i .. ". " .. d.name)
            row.txt2:SetText(string.format("%s %.1f%%", self:ShortNum(d.amt), pct))
            row.txt1:SetTextColor(1, 0.5, 0.35)
            RLSuite.utils:SkinRow(row, false)
        end)
        self:_FillRows(self.rightContent, "_rRows", {}, function() end)
    elseif tab == "interrupts" then
        local rows = self:AggInterrupts(f, "interrupt")
        local rows2 = self:AggInterrupts(f, "dispel")
        self.leftHeader:SetText(L["Interrupts"] .. ": " .. #rows)
        self.rightHeader:SetText(L["Dispels"] .. ": " .. #rows2)
        self:_FillRows(self.leftContent, "_lRows", rows, function(row, d)
            row.txt1:SetText(string.format("%d:%02d %s", math.floor(d.t / 60), math.floor(d.t % 60), d.text))
            row.txt2:SetText("")
            row.txt1:SetTextColor(0.4, 0.75, 1)
            RLSuite.utils:SkinRow(row, false)
        end)
        self:_FillRows(self.rightContent, "_rRows", rows2, function(row, d)
            row.txt1:SetText(string.format("%d:%02d %s", math.floor(d.t / 60), math.floor(d.t % 60), d.text))
            row.txt2:SetText("")
            row.txt1:SetTextColor(0.85, 0.6, 1)
            RLSuite.utils:SkinRow(row, false)
        end)
    end
end

-- Contenuto del tab attivo.
function CL:RefreshLists()
    local f = self.selFight
    self:RefreshInfo(f)
    if not f then
        local tab0 = self.selTab
        if CL_GRID_TABS[tab0] then
            -- colonne valide anche senza dati (prima mancava "w": crash)
            local cols = {
                { label = "Name", w = 200, fix = true },
                { label = "", w = 120, fix = true },
            }
            local rows = { { { t = L["No fights recorded"], r = 1, g = 0.82, b = 0 } } }
            self:GridRender(self.grid, cols, rows, { width = CL_GRID_W })
        elseif tab0 == "deaths" then
            self.deathHeader:SetText(L["Deaths"])
            self.deathDetailHeader:SetText("")
            self:_FillRows(self.deathContent, "_dRows", {}, function() end)
            local cols, drows = self:BuildDeathDetail(nil, nil)
            self:GridRender(self.deathGrid, cols, drows, {})  -- larghezza viva del pannello
        else
            self.leftHeader:SetText(L["No fights recorded"])
            self.rightHeader:SetText("")
            self:_FillRows(self.leftContent, "_lRows", {}, function() end)
            self:_FillRows(self.rightContent, "_rRows", {}, function() end)
        end
        return
    end
    local tab = self.selTab
    if tab == "deaths" then
        self:RefreshDeathPane(f)
        return
    end
    if not CL_GRID_TABS[tab] then
        self:RefreshLegacyLists(f)
        return
    end
    local cols, rows
    if tab == "damage" then
        cols, rows = self:BuildDamageTab(f)
    elseif tab == "targets" then
        cols, rows = self:BuildTargetsTab(f)
    elseif tab == "consumables" then
        cols, rows = self:BuildConsumablesTab(f)
    elseif tab == "auras" then
        cols, rows = self:BuildAurasTab(f)
    elseif tab == "powers" then
        cols, rows = self:BuildPowersTab(f)
    end
    -- click su una riga = sorgente del grafico
    self:GridRender(self.grid, cols, rows, {
        width = CL_GRID_W,
        hint = L["Click a row to plot that player"],
        onClick = function(data)
            CL.selSource = (CL.selSource == data.name) and nil or data.name
            CL:RefreshGraph()
            CL:RefreshLists()
        end,
    })
end

function CL:RefreshGraph()
    if not self.graphPane or not self.graph then return end
    -- Discretizzazioni (terzo screen di UwU): media intero fight + 1/2/3/5/10s
    local items = {}
    for _, st in ipairs(CL_GRAPH_STEPS) do
        items[#items + 1] = { text = L[st.text], value = st.step }
    end
    RLSuite.utils:SetupDropdown(self.stepDropdown, items, self.graphStep, function(v)
        CL.graphStep = v
        CL:RefreshGraph()
    end)
    for _, m in ipairs({ "dps", "health", "power" }) do
        local b = self.graphModeBtns and self.graphModeBtns[m]
        if b then
            if m == self.graphMode then b:LockHighlight() else b:UnlockHighlight() end
        end
    end
    local f = self.selFight
    if not f then
        self.graphHint:SetText(L["No fights recorded"])
        self.graph:SetData({}, {})
        return
    end
    local series, vlines, label = {}, {}, ""
    local mode = self.graphMode
    if mode == "dps" then
        series = self:DpsSeries(f, self.selSource, self.graphStep)
        local stepTxt = L["Avg whole fight"]
        for _, st in ipairs(CL_GRAPH_STEPS) do
            if st.step == self.graphStep then stepTxt = L[st.text] end
        end
        label = ((self.selSource and (self.selSource .. " ")) or (L["Total DPS"] .. " "))
            .. "— " .. stepTxt
        for _, ev in ipairs(f.events) do
            if ev[CL_E.SUB] == "UNIT_DIED" then vlines[#vlines + 1] = { ev[CL_E.T] } end
        end
    elseif mode == "health" then
        local key = (self.selSource and not self.selSource:find("^%[BOSS%]"))
            and self.selSource or (f.boss and ("[BOSS] " .. f.boss) or self.selSource)
        series = self:SampleSeries(f, "health", key)
        label = (key or "?") .. " HP%"
        for _, ev in ipairs(f.events) do
            if ev[CL_E.SUB] == "UNIT_DIED" and self:IsPlayerFlag(ev[CL_E.DSTF]) then
                vlines[#vlines + 1] = { ev[CL_E.T] }
            end
        end
    else
        local key = self.selSource
        series = key and self:SampleSeries(f, "power", key) or {}
        label = (key and (key .. " Power%")) or (L["Select player"] .. " (Power)")
        if not key then
            for _, ev in ipairs(f.events) do
                if ev[CL_E.SUB] == "UNIT_DIED" and self:IsPlayerFlag(ev[CL_E.DSTF]) then
                    vlines[#vlines + 1] = { ev[CL_E.T] }
                end
            end
        end
    end
    self.graphHint:SetText(label .. "  (" .. L["drag: zoom, click: reset, hover: values"] .. ")")
    local unit = (mode == "dps") and "DPS" or (mode == "health" and "HP%" or "Power%")
    self.graph:SetData(series, vlines, { unit = unit })
end

-- Report top-5 del pannello sinistro corrente in raid chat.
function CL:SendReport()
    local f = self.selFight
    if not f then
        RLSuite.utils:Print(L["No fights recorded"])
        return
    end
    -- Sul tab Damage il report e' il danno UTILE (boss) top-5 come la tabella.
    local tab = self.selTab
    local cat = (tab == "healing") and "heal" or (tab == "spells" and "cast" or "damage")
    local mode = (tab == "healing") and "HEALING" or (tab == "spells" and "CASTS" or "DAMAGE")
    if tab == "damage" then
        -- il tab Damage mostra il danno UTILE: il report usa la stessa fonte
        local st = self:AggPlayerStats(f)
        rows, total = {}, st.total.useful
        for _, a in ipairs(st.rows) do rows[#rows + 1] = { name = a.name, amt = a.useful } end
        table.sort(rows, function(x, y) return x.amt > y.amt end)
    end
    local parts = {}
    for i = 1, math.min(5, #rows) do
        local d = rows[i]
        local pct = (total > 0) and (d.amt / total * 100) or 0
        parts[#parts + 1] = string.format("%d.%s %s(%.0f%%)", i, d.name, self:ShortNum(d.amt), pct)
    end
    RLSuite.utils:SendChat(string.format("RLS %s %s: %s", mode, f.name or "Combat", table.concat(parts, " | ")), "RAID")
end
