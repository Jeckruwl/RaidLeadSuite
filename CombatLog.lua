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
}

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
function CL:NpcIdFromGUID(guid)
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
    self.graphStep = 1
    self.liveUpdate = false
    self:CreateFrame()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnRegenDisabled")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
end

function CL:Toggle()
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
        local pw, pwm = UnitPower(u), UnitPowerMax(u)
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

-- Serie DPS per il grafico: bucket per step secondi (fill zeri).
function CL:DpsSeries(f, srcName, step)
    step = tonumber(step) or 1
    if step <= 0 then step = 1 end
    local buckets, maxB = {}, 0
    for _, ev in ipairs(f.events) do
        if CL_CATS[ev[CL_E.SUB]] == "damage" and self:IsRaidGroupFlag(ev[CL_E.SRCF]) then
            if srcName == nil or ev[CL_E.SRC] == srcName then
                local b = math.floor(ev[CL_E.T] / step)
                buckets[b] = (buckets[b] or 0) + (ev[CL_E.AMT] or 0)
                if b > maxB then maxB = b end
            end
        end
    end
    local pts = {}
    for b = 0, maxB do
        pts[#pts + 1] = { b * step, (buckets[b] or 0) / step }
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
    g:SetClipsChildren(true)
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

    g._linePool = {}
    g._vlinePool = {}
    g:EnableMouse(true)
    g:SetScript("OnUpdate", function(s)
        if not s._hoverOn or not s.series or #s.series == 0 then return end
        if not (GetCursorPosition and IsMouseButtonDown) then
            s._showTip = false
            GameTooltip:Hide()
            return
        end
    end)
    g:SetScript("OnEnter", function(s) s._hoverOn = true end)
    g:SetScript("OnLeave", function(s) s._hoverOn = false; if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)
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

    g.Reload = function(s)
        for _, t in ipairs(s._linePool) do t:Hide() end
        for _, t in ipairs(s._vlinePool) do t:Hide() end
        local x0, x1 = s.xMin or 0, s.xMax or 1
        local span = x1 - x0
        if span <= 0 then span = 1 end
        local yMax = 0
        for _, p in ipairs(s.series) do
            local x, y = p[1] or 0, p[2] or 0
            if x >= x0 and x <= x1 and y > yMax then yMax = y end
        end
        if yMax <= 0 then yMax = 1 end
        s.maxText:SetText(CL:ShortNum(yMax))
        local used = 0
        local prevX, prevY
        for _, p in ipairs(s.series) do
            local x, y = p[1] or 0, p[2] or 0
            if x >= x0 and x <= x1 then
                local px = (x - x0) / span * (s.width - 4) + 2
                local py = (y / yMax) * (s.height - 6) + 2
                if prevX then
                    local dx, dy = px - prevX, py - prevY
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 0.5 then
                        used = used + 1
                        local tex = s._linePool[used]
                        if not tex then
                            tex = s:CreateTexture(nil, "ARTWORK")
                            s._linePool[used] = tex
                            -- ancoriamo le linee al grafico: rotate texture
                        end
                        SetSolidColor(tex, 0.2, 0.9, 0.35, 0.9)
                        tex:ClearAllPoints()
                        -- segmento come texture ruotata tra prev e cur
                        local cx, cy = (prevX + px) / 2, (prevY + py) / 2
                        tex:SetSize(len, 2)
                        tex:SetPoint("CENTER", s, "BOTTOMLEFT", cx, cy)
                        if tex.SetRotation then
                            tex:SetRotation(math.atan2(dy, dx))
                        end
                        tex:Show()
                        tex._segFrom, tex._segTo = { prevX, prevY }, { px, py }
                    end
                end
                prevX, prevY = px, py
            end
        end
        for i = used + 1, #s._linePool do s._linePool[i]:Hide() end
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
                local px = (x - x0) / span * (s.width - 4) + 2
                tex:ClearAllPoints()
                tex:SetSize(2, s.height - 4)
                tex:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", px, 2)
                tex:Show()
            end
        end
    end

    return g
end

-- ------------------------------------------------------------------
-- UI
-- ------------------------------------------------------------------
local CL_ROW_H = 18

function CL:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteCombatLog", UIParent)
    f:SetSize(730, 540)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -80)
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

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -10)
    title:SetText(L["Combat log"])

    -- Fight selector (dropdown in alto a destra)
    local fightLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fightLbl:SetPoint("TOPRIGHT", f, "TOPRIGHT", -296, -14)
    fightLbl:SetText(L["Select fight"])
    self.fightDropdown = RLSuite.utils:CreateDropdown(f, "RLSuiteCombatLogFightDD", 240, 20)
    self.fightDropdown:ClearAllPoints()
    self.fightDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -10)

    -- Tab bar
    self.tabBtns = {}
    local tx = 16
    for _, def in ipairs(CL_UI_TABS) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        RLSuite.utils:SkinButton(b)
        b:SetSize(86, 20)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", tx, -36)
        b:SetText(L[def.label])
        b.tabKey = def.key
        b:SetScript("OnClick", function() CL:SelectTab(def.key) end)
        self.tabBtns[def.key] = b
        tx = tx + 88
    end

    -- Pannelli lista (sx = sorgenti, dx = breakdown/eventi)
    self.leftHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.leftHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -62)
    self.leftHeader:SetText("")

    self.leftBox = CreateFrame("Frame", nil, f)
    self.leftBox:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -78)
    self.leftBox:SetSize(250, 398)
    RLSuite.utils:SkinBox(self.leftBox)
    self.leftScroll = CreateFrame("ScrollFrame", "RLSuiteCombatLogLeft", self.leftBox, "UIPanelScrollFrameTemplate")
    self.leftScroll:SetPoint("TOPLEFT", 4, -4)
    self.leftScroll:SetPoint("BOTTOMRIGHT", -24, 4)
    self.leftContent = CreateFrame("Frame", nil, self.leftScroll)
    self.leftContent:SetWidth(214)
    self.leftContent:SetHeight(1)
    self.leftScroll:SetScrollChild(self.leftContent)

    self.rightHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.rightHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 280, -62)
    self.rightHeader:SetText("")

    self.rightBox = CreateFrame("Frame", nil, f)
    self.rightBox:SetPoint("TOPLEFT", f, "TOPLEFT", 274, -78)
    self.rightBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -78)
    self.rightBox:SetHeight(398)
    RLSuite.utils:SkinBox(self.rightBox)
    self.rightScroll = CreateFrame("ScrollFrame", "RLSuiteCombatLogRight", self.rightBox, "UIPanelScrollFrameTemplate")
    self.rightScroll:SetPoint("TOPLEFT", 4, -4)
    self.rightScroll:SetPoint("BOTTOMRIGHT", -24, 4)
    self.rightContent = CreateFrame("Frame", nil, self.rightScroll)
    self.rightContent:SetWidth(390)
    self.rightContent:SetHeight(1)
    self.rightScroll:SetScrollChild(self.rightContent)

    -- Pannello GRAFICO (visibile solo nel tab Graphs: copre entrambe le liste)
    self.graphPane = CreateFrame("Frame", nil, f)
    self.graphPane:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -78)
    self.graphPane:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -78)
    self.graphPane:SetHeight(398)
    RLSuite.utils:SkinBox(self.graphPane)
    self.graphPane:Hide()

    -- controlli del grafico: mode DPS/Health/Power + step
    self.graphModeBtns = {}
    for i, m in ipairs({ "dps", "health", "power" }) do
        local b = CreateFrame("Button", nil, self.graphPane, "UIPanelButtonTemplate")
        RLSuite.utils:SkinButton(b)
        b:SetSize(70, 20)
        b:SetPoint("TOPLEFT", self.graphPane, "TOPLEFT", 8 + (i - 1) * 74, -8)
        b:SetText(L[m == "dps" and "DPS" or (m == "health" and "Health" or "Power")])
        b.graphMode = m
        b:SetScript("OnClick", function() CL.graphMode = m; CL:RefreshGraph() end)
        self.graphModeBtns[m] = b
    end
    local stepLbl = self.graphPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stepLbl:SetPoint("LEFT", self.graphModeBtns.power, "RIGHT", 10, 0)
    stepLbl:SetText(L["Step, sec."])
    self.stepDropdown = RLSuite.utils:CreateDropdown(self.graphPane, "RLSuiteCombatLogStepDD", 70, 20)
    self.stepDropdown:ClearAllPoints()
    self.stepDropdown:SetPoint("LEFT", stepLbl, "RIGHT", 6, 0)

    -- player selector nel grafico (riusa la selezione sinistra: click lista = player)
    self.graph = self:NewGraph(self.graphPane, 640, 330)
    self.graph:SetPoint("TOPLEFT", self.graphPane, "TOPLEFT", 30, -52)
    self.graphHint = self.graphPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.graphHint:SetPoint("TOPLEFT", self.graphPane, "TOPLEFT", 30, -34)
    self.graphHint:SetTextColor(1, 0.82, 0)

    -- Barra inferiore: report/clear/live + info
    self.reportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.reportBtn)
    self.reportBtn:SetSize(100, 24)
    self.reportBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 10)
    self.reportBtn:SetText(L["Send report"])
    self.reportBtn:SetScript("OnClick", function() CL:SendReport() end)

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
    self.infoText:SetPoint("LEFT", liveLbl, "RIGHT", 12, 0)
    self.infoText:SetText("")

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnShow", function() CL:RefreshUI() end)
end

function CL:SkinInner()
    RLSuite.utils:SkinBox(self.leftBox)
    RLSuite.utils:SkinBox(self.rightBox)
    RLSuite.utils:SkinBox(self.graphPane)
end

-- Ticker "live" (2s): aggiorna la vista durante il fight registrato.
function CL:EnsureLiveTicker()
    if self._liveTicker then return end
    self._liveTicker = self:ScheduleRepeatingTimer(function()
        if not CL.liveUpdate then return end
        if CL.current and CL.frame and CL.frame:IsShown() then
            CL.selFight = CL.current
            CL:RefreshUI()
        end
    end, 2)
end

-- ------------------------------------------------------------------
-- Fight selector/disponi righe
-- ------------------------------------------------------------------
function CL:FightLabel(f, idx)
    local dur = self:FightDuration(f)
    local mm = math.floor(dur / 60)
    local ss = math.floor(dur % 60)
    local when = (f.startUTC and date) and date("%H:%M", f.startUTC) or "??:??"
    local tag = f.kill and "[KILL]" or (f.kill == false and "[WIPE]" or "")
    return string.format("#%d %s %d:%02d %s (%s)", idx or 0, f.name or "Combat", mm, ss, tag, when)
end

function CL:FightListItems()
    local items = {}
    if self.current then
        items[#items + 1] = { text = L["[LIVE]"] .. " " .. (self.current.boss or "Combat"), value = self.current }
    end
    for i, f in ipairs((self.db and self.db.fights) or {}) do
        items[#items + 1] = { text = self:FightLabel(f, i), value = f }
    end
    if #items == 0 then
        items[1] = { text = L["No fights recorded"], value = false }
    end
    return items
end

function CL:SelectFight(f)
    if f ~= false then self.selFight = f end
    self.selSource = nil
    self:RefreshUI()
end

function CL:SelectTab(key)
    self.selTab = key
    self.selSource = nil
    if self.graphPane then
        if key == "graphs" then
            self.leftBox:Hide(); self.rightBox:Hide()
            self.leftHeader:Hide(); self.rightHeader:Hide()
            self.graphPane:Show()
        else
            self.graphPane:Hide()
            self.leftBox:Show(); self.rightBox:Show()
            self.leftHeader:Show(); self.rightHeader:Show()
        end
    end
    self:RefreshUI()
end

-- Refresh completo: dropdown + tab attiva + liste (o grafico).
function CL:RefreshUI()
    if not self.frame then return end
    local items = self:FightListItems()
    local cur = self.selFight
    if not cur and items[1] and items[1].value ~= false then
        cur = items[1].value
        self.selFight = cur
    end
    RLSuite.utils:SetupDropdown(self.fightDropdown, items, cur or false, function(v)
        CL:SelectFight(v)
    end)
    -- evidenzia tab attivo
    for key, b in pairs(self.tabBtns or {}) do
        if b.SetBackdropBorderColor then
            if key == self.selTab then
                b:SetBackdropBorderColor(0.85, 0.70, 0.20, 1)
            else
                b:SetBackdropBorderColor(0.45, 0.45, 0.48, 1)
            end
        end
    end
    if self.selTab == "graphs" then
        self:RefreshGraph()
    else
        self:RefreshLists()
    end
end

-- Costruisce una riga fissa (da pooled rebuild, pattern Loot Manager).
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
    local y = 0
    for i, data in ipairs(rows) do
        local row = pool[i]
        if not row then
            row = MakeRow(content, nil)
            pool[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
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
end

-- Refresh dei due pannelli secondo il tab selezionato.
function CL:RefreshLists()
    local f = self.selFight
    if not f then
        self.leftHeader:SetText(L["No fights recorded"])
        self.rightHeader:SetText("")
        self.infoText:SetText("")
        self:_FillRows(self.leftContent, "_lRows", {}, function() end)
        self:_FillRows(self.rightContent, "_rRows", {}, function() end)
        return
    end
    local dur = self:FightDuration(f)
    -- info bar
    local dropped = (f.dropped and f.dropped > 0) and (" (+" .. f.dropped .. " " .. L["dropped"] .. ")") or ""
    self.infoText:SetText(string.format("%s | %d:%02d | %d %s%s",
        f.name or "Combat", math.floor(dur / 60), math.floor(dur % 60),
        f.count or #f.events, L["Events"], dropped))

    local tab = self.selTab
    local sel = self.selSource

    if tab == "damage" or tab == "healing" or tab == "players" then
        local cat = (tab == "damage" and "damage") or (tab == "healing" and "heal") or "cast"
        local rows, total = self:AggTotals(f, cat)
        self.leftHeader:SetText((tab == "damage" and L["Damage"] or tab == "healing" and L["Healing"] or L["Players spells"])
            .. " — " .. L["Total"] .. ": " .. self:ShortNum(total))
        self:_FillRows(self.leftContent, "_lRows", rows, function(row, d, i)
            local pct = (total > 0) and (d.amt / total * 100) or 0
            row.txt1:SetText(i .. ". " .. d.name)
            row.txt2:SetText(string.format("%s %.1f%%", self:ShortNum(d.amt), pct))
            local rr, gg, bb = self:ClassColor(d.name)
            row.txt1:SetTextColor(rr, gg, bb)
            if sel == d.name then
                RLSuite.utils:SkinRow(row, true)
            else
                RLSuite.utils:SkinRow(row, false)
            end
        end, function(d)
            CL.selSource = (CL.selSource == d.name) and nil or d.name
            CL:RefreshLists()
        end)
        -- dettaglio: breakdown per spell della sorgente selezionata
        if sel then
            local srows, stotal = self:AggSpells(f, cat, sel)
            self.rightHeader:SetText(sel .. " — " .. (cat == "cast" and L["Spells list"] or L["By cast"]))
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

    elseif tab == "auras" then
        local rows = self:AggAuras(f)
        self.leftHeader:SetText(L["Auras"] .. " — " .. L["Uptime"])
        self:_FillRows(self.leftContent, "_lRows", rows, function(row, d, i)
            row.txt1:SetText(i .. ". " .. (d.name or "?") .. ((d.auraType == "DEBUFF") and " [D]" or ""))
            row.txt2:SetText(string.format("%d×  %.0f%%", d.count, d.uptime or 0))
            row.txt1:SetTextColor(d.auraType == "DEBUFF" and 1 or 0.4, d.auraType == "DEBUFF" and 0.5 or 1, 0.5)
            if sel == d.name then RLSuite.utils:SkinRow(row, true) else RLSuite.utils:SkinRow(row, false) end
        end, function(d)
            CL.selSource = (CL.selSource == d.name) and nil or d.name
            CL:RefreshLists()
        end)
        if sel then
            local sp
            for _, d in ipairs(rows) do if d.name == sel then sp = d break end end
            self.rightHeader:SetText(sel .. " — " .. L["By target"])
            local drows = {}
            if sp then
                for dst, up in pairs(sp.dests) do
                    drows[#drows + 1] = { name = dst, amt = up }
                end
                table.sort(drows, function(a, b) return a.amt > b.amt end)
            end
            self:_FillRows(self.rightContent, "_rRows", drows, function(row, d, i)
                row.txt1:SetText(i .. ". " .. d.name)
                row.txt2:SetText(string.format("%.1fs", d.amt))
                row.txt1:SetTextColor(1, 1, 1)
                RLSuite.utils:SkinRow(row, false)
            end)
        else
            self.rightHeader:SetText(L["Select player"])
            self:_FillRows(self.rightContent, "_rRows", {}, function() end)
        end

    elseif tab == "power" then
        local rows, byPlayer = self:AggPower(f)
        self.leftHeader:SetText(L["Power"])
        self:_FillRows(self.leftContent, "_lRows", rows, function(row, d, i)
            row.txt1:SetText(i .. ". " .. d.name)
            row.txt2:SetText(self:ShortNum(d.amt))
            row.txt1:SetTextColor(0.4, 0.6, 1)
            if sel == d.name then RLSuite.utils:SkinRow(row, true) else RLSuite.utils:SkinRow(row, false) end
        end, function(d)
            CL.selSource = (CL.selSource == d.name) and nil or d.name
            CL:RefreshLists()
        end)
        if sel then
            local drows = {}
            for k, amt in pairs(byPlayer) do
                local pt, dst = strsplit("|", k)
                if pt == sel then drows[#drows + 1] = { name = dst, amt = amt } end
            end
            table.sort(drows, function(a, b) return a.amt > b.amt end)
            self.rightHeader:SetText(sel .. " — " .. L["By target"])
            self:_FillRows(self.rightContent, "_rRows", drows, function(row, d, i)
                row.txt1:SetText(i .. ". " .. d.name)
                row.txt2:SetText(self:ShortNum(d.amt))
                row.txt1:SetTextColor(1, 1, 1)
                RLSuite.utils:SkinRow(row, false)
            end)
        else
            self.rightHeader:SetText(L["Select player"])
            self:_FillRows(self.rightContent, "_rRows", {}, function() end)
        end
    end
end

-- Refresh del tab Graphs.
function CL:RefreshGraph()
    if not self.graphPane or not self.graph then return end
    local f = self.selFight
    if not f then
        self.graphHint:SetText(L["No fights recorded"])
        self.graph:SetData({}, {})
        return
    end
    local items = {}
    for _, s in ipairs({ 1, 2, 3, 5, 10 }) do items[#items + 1] = { text = s .. "s", value = s } end
    RLSuite.utils:SetupDropdown(self.stepDropdown, items, self.graphStep, function(v)
        CL.graphStep = v
        CL:RefreshGraph()
    end)
    local series, vlines, label = {}, {}, ""
    local mode = self.graphMode
    if mode == "dps" then
        series = self:DpsSeries(f, self.selSource, self.graphStep)
        label = (self.selSource and (self.selSource .. " ")) or (L["Total DPS"] .. " ")
        for _, ev in ipairs(f.events) do
            if ev[CL_E.SUB] == "UNIT_DIED" then vlines[#vlines + 1] = { ev[CL_E.T] } end
        end
    elseif mode == "health" then
        local key = (self.selSource and not self.selSource:find("^%[BOSS%]"))
            and self.selSource or (f.boss and ("[BOSS] " .. f.boss) or self.selSource)
        series = self:SampleSeries(f, "health", key)
        label = (key or "?") .. " HP% "
        -- health usa i sample: vline = morti pg
        for _, ev in ipairs(f.events) do
            if ev[CL_E.SUB] == "UNIT_DIED" and self:IsPlayerFlag(ev[CL_E.DSTF]) then
                vlines[#vlines + 1] = { ev[CL_E.T] }
            end
        end
    else
        local key = self.selSource
        series = key and self:SampleSeries(f, "power", key) or {}
        label = (key and (key .. " Power% ")) or (L["Select player"] .. " ")
        if not key then
            for _, ev in ipairs(f.events) do
                if ev[CL_E.SUB] == "UNIT_DIED" and self:IsPlayerFlag(ev[CL_E.DSTF]) then
                    vlines[#vlines + 1] = { ev[CL_E.T] }
                end
            end
        end
    end
    self.graphHint:SetText(label .. "(" .. L["drag: zoom, click: reset"] .. ")")
    self.graph:SetData(series, vlines)
end

-- Report top-5 del pannello sinistro corrente in raid chat.
function CL:SendReport()
    local f = self.selFight
    if not f then
        RLSuite.utils:Print(L["No fights recorded"])
        return
    end
    local cat = (self.selTab == "healing") and "heal" or (self.selTab == "players" and "cast" or "damage")
    local rows, total = self:AggTotals(f, cat)
    local mode = (self.selTab == "healing") and "HEALING" or (self.selTab == "players" and "CASTS" or "DAMAGE")
    local parts = {}
    for i = 1, math.min(5, #rows) do
        local d = rows[i]
        local pct = (total > 0) and (d.amt / total * 100) or 0
        parts[#parts + 1] = string.format("%d.%s %s(%.0f%%)", i, d.name, self:ShortNum(d.amt), pct)
    end
    RLSuite.utils:SendChat(string.format("RLS %s %s: %s", mode, f.name or "Combat", table.concat(parts, " | ")), "RAID")
end
