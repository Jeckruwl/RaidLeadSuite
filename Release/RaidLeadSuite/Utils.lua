-- ============================================================
-- RLSuite - Utils
-- ============================================================

RLSuite = RLSuite or {}
RLSuite.utils = {}
local Utils = RLSuite.utils

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

-- ICONE DA FILE media/*.tga: i TGA dell'addon (BCI_*, save.tga, ecc.)
-- hanno SEMPRE reso nel client — formato identico generato per le nostre
-- X e freccia (32x32, 32bpp, type 2, descriptor 0x28, 4114 byte). Disegno
-- via TEXTURE esplicite ARTWORK + HIGHLIGHT (pattern della minimappa/BCI,
-- che RENDE SEMPRE): mai SetNormalTexture/SetHighlightTexture su bottoni.
-- Path SEMPRE via AddonTexture (folder RLSuite|RaidLeadSuite).
function Utils:ApplyIcon(btn, iconRel)
    local tx = RLSuite:AddonTexture(iconRel)
    local t = btn:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(btn)
    t:SetTexture(tx)
    btn.icon = t
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetTexture(tx)
    hl:SetBlendMode("ADD")
    btn.hl = hl
    btn._iconPath = tx
    return btn
end

-- Bottone icona da file, completo: dimensione w x h, highlight glow.
function Utils:MakeIconButton(parent, iconRel, w, h, onclick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 22, h or w or 22)
    b:SetBackdrop(nil)
    Utils:ApplyIcon(b, iconRel)
    if onclick then
        b:EnableMouse(true)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", onclick)
    end
    return b
end

-- X bianca (TGA) per CHIUDERE le finestre: usata da TUTTE le finestre.
function Utils:MakeCloseX(parent, onclick)
    return Utils:MakeIconButton(parent, "media\\close.tga", 11, 11, onclick)
end

function Utils:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RLSuite]|r " .. tostring(msg))
end

function Utils:Debug(msg)
    if RLSuite.db and RLSuite.db.profile.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff999999[RLSuite-Debug]|r " .. tostring(msg))
    end
end

function Utils:TableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function Utils:CopyTable(src, dest)
    dest = dest or {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = self:CopyTable(v)
        else
            dest[k] = v
        end
    end
    return dest
end

function Utils:GetClassColor(class)
    local colors = {
        WARRIOR     = {r=0.78, g=0.61, b=0.43},
        PALADIN     = {r=0.96, g=0.55, b=0.73},
        HUNTER      = {r=0.67, g=0.83, b=0.45},
        ROGUE       = {r=1.00, g=0.96, b=0.41},
        PRIEST      = {r=1.00, g=1.00, b=1.00},
        DEATHKNIGHT = {r=0.77, g=0.12, b=0.23},
        SHAMAN      = {r=0.00, g=0.44, b=0.87},
        MAGE        = {r=0.25, g=0.78, b=0.92},
        WARLOCK     = {r=0.53, g=0.53, b=0.93},
        DRUID       = {r=1.00, g=0.49, b=0.04},
    }
    local c = colors[(class or "WARRIOR"):upper()] or {r=1, g=1, b=1}
    return c.r, c.g, c.b
end

function Utils:FormatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

function Utils:FormatCD(seconds)
    seconds = math.floor(seconds + 0.5)
    if seconds >= 60 then
        return tostring(math.floor(seconds / 60)) .. "m"
    end
    return tostring(seconds)
end

-- Protegge SendChatMessage (3.3.5): una "|" non seguita da una sequenza di
-- escape valida (|c colore, |H..|h link oggetti/incantesimi, |T..|t texture,
-- |r reset, |n newline, |1..|4 forme grammaticali, || pipe letterale) fa
-- scattare "Invalid escape code in chat message". Raddoppia solo le pipe
-- "orfane", lasciando intatti i link degli oggetti (|c..|H..|h..|r).
function Utils:SanitizeChat(text)
    if type(text) ~= "string" then return text end
    local valid = { c=true, C=true, r=true, R=true, h=true, H=true, t=true, T=true,
                    n=true, N=true, ["1"]=true, ["2"]=true, ["3"]=true, ["4"]=true,
                    ["|"]=true }
    local out = {}
    local i = 1
    while i <= #text do
        local c = text:sub(i, i)
        if c == "|" then
            local nxt = text:sub(i + 1, i + 1)
            if nxt ~= "" and valid[nxt] then
                out[#out + 1] = "|"
                out[#out + 1] = nxt
                i = i + 2
            else
                out[#out + 1] = "||"
                i = i + 1
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end

function Utils:SendChat(msg, channel)
    if not msg or msg == "" then return end
    channel = channel or "RAID"
    msg = self:SanitizeChat(msg)
    if RLSuite.db and RLSuite.db.profile.debug then
        local me = UnitName("player")
        if me then
            SendChatMessage("[" .. channel .. "] " .. msg, "WHISPER", nil, me)
        end
        return
    end
    if channel == "RAID_WARNING" and not IsRaidLeader() and not IsRaidOfficer() then
        channel = "RAID"
    end
    SendChatMessage(msg, channel)
end

function Utils:Whisper(name, msg)
    if not msg or msg == "" then return end
    msg = self:SanitizeChat(msg)
    local dest = name
    if RLSuite.db and RLSuite.db.profile.debug then
        dest = UnitName("player")
    end
    if dest then
        SendChatMessage(msg, "WHISPER", nil, dest)
    end
end

function Utils:StripColorCodes(text)
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Full WotLK 3.3.5 hyperlink: |cffffffff|Hitem:id:ench:g1:g2:g3:g4:suffix:unique:level|h[Name]|h|r
function Utils:GetItemLinkFromChat(text)
    if not text or text == "" then return nil end
    local full = text:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if full then return full end
    local inner = text:match("|H(item:[^|]+)|h")
    if inner then return inner end
    return text:match("(item:%d+[:%d]*)")
end

function Utils:ClassIcon(class)
    local icons = {
        WARRIOR = "Interface\\Icons\\INV_Sword_04",
        PALADIN = "Interface\\Icons\\INV_Hammer_01",
        HUNTER = "Interface\\Icons\\INV_Weapon_Bow_07",
        ROGUE = "Interface\\Icons\\INV_ThrowingKnife_04",
        PRIEST = "Interface\\Icons\\INV_Staff_30",
        DEATHKNIGHT = "Interface\\Icons\\Spell_Deathknight_ClassIcon",
        SHAMAN = "Interface\\Icons\\INV_Jewelry_Talisman_04",
        MAGE = "Interface\\Icons\\INV_Staff_13",
        WARLOCK = "Interface\\Icons\\INV_Staff_30",
        DRUID = "Interface\\Icons\\Ability_Druid_Maul",
    }
    return icons[(class or "WARRIOR"):upper()] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Utils:GetSpecInfo(class, specName)
    if not specName or specName == "" then return nil end
    local data = RLSuite.classData and RLSuite.classData[(class or ""):upper()]
    if not data or not data.specs then return nil end
    local want = string.lower(specName)
    for _, spec in ipairs(data.specs) do
        if type(spec) == "table" then
            local name = string.lower(spec.name or "")
            if name == want then return spec end
        elseif type(spec) == "string" and string.lower(spec) == want then
            return {name = spec, role = "dps"}
        end
    end
    -- partial match: "feral" -> first feral*, "prot" -> protection
    for _, spec in ipairs(data.specs) do
        if type(spec) == "table" then
            local name = string.lower(spec.name or "")
            if string.find(name, want, 1, true) or string.find(want, name, 1, true) then
                return spec
            end
        end
    end
    return nil
end

function Utils:SpecIcon(class, specName)
    local info = self:GetSpecInfo(class, specName)
    if info and info.icon then return info.icon end
    return self:ClassIcon(class)
end

function Utils:RoleFromSpec(class, specName)
    local info = self:GetSpecInfo(class, specName)
    if info and info.role then return info.role end
    return nil
end

function Utils:SpecShortName(class, specName)
    local info = self:GetSpecInfo(class, specName)
    if info and info.short then return info.short end
    return specName or ""
end

function Utils:NormalizeRole(role, class, spec)
    if role == "mdps" or role == "rdps" or role == "tank" or role == "healer" then
        return role
    end
    local fromSpec = self:RoleFromSpec(class, spec)
    if fromSpec then return fromSpec end
    if role == "dps" then return "mdps" end
    return role or "mdps"
end

-- ============================================================
-- PARSER CLASSE / SPEC / GS  (v1.11.87)
-- Regole: _dev/Class_Spec_and_GS_parser.md
--
-- Forma di un whisper:  [PREFIX] BODY [SUFFIX]
--   BODY   = la CLASSE: dk / druid+dudu / hunter+hunt / mage /
--            pal+pala+paladin / priest / rog+rogue / sham+shammy+shaman /
--            lock+warlock / war+warr+warrior.
--            Eccezioni della tabella: Boomkin e Boomie sono BODY del druido e
--            valgono Balance; Disco e' BODY del priest e vale Discipline
--            (in entrambi i casi prefisso e suffisso NON sono ammessi).
--   PREFIX = la SPEC scritta PRIMA della classe  ("prot pala")
--   SUFFIX = la SPEC scritta DOPO la classe      ("pala prot")
--   REGOLA GENERALE: o c'e' il prefisso o c'e' il suffisso, mai entrambi.
--   ECCEZIONE: il ferale del druido (Cat/Bear) ammette entrambi; il suffisso
--   puo' essere di due parole ("feral cat", "feral bear") e "feral" da solo
--   resta ambiguo fra Cat e Bear.
--   Maiuscole/minuscole non contano: si confronta tutto in minuscolo.
-- Parole estranee (ruolo, saluti, numeri) non danno fastidio: valgono solo le
-- parole ADIACENTI alla classe ("healer holy pala 5900 gs" e' Holy Paladin).
-- ============================================================

-- Corpo (classe) -> parole accettate. La PRIMA di ogni lista e' quella usata
-- per generare i whisper di prova, non per il match (il match le accetta tutte).
Utils.classBodies = {
    DEATHKNIGHT = { "dk", "deathknight" },
    DRUID       = { "dudu", "druid", "boomkin", "boomie" },
    HUNTER      = { "hunt", "hunter" },
    MAGE        = { "mage" },
    PALADIN     = { "pala", "pal", "paladin" },
    PRIEST      = { "priest", "disco" },
    ROGUE       = { "rog", "rogue" },
    SHAMAN      = { "sham", "shammy", "shaman" },
    WARLOCK     = { "lock", "warlock" },
    WARRIOR     = { "war", "warr", "warrior" },
}

-- BODY che portano con se' la SPEC (e con essa il divieto di prefisso/suffisso)
Utils.bodySpecWords = { boomkin = "Balance", boomie = "Balance", disco = "Discipline" }

-- Spec: prefissi e suffissi della tabella. I nomi delle spec sono quelli
-- canonici di RLSuite.classData (cioe' quelli che usa tutto il resto dell'addon).
-- Con la tabella sono accettate anche le grafie corrette delle voci scritte
-- con un refuso (Afliction -> affliction, Destriction -> destruction,
-- Sublety -> subtlety): un giocatore le scrive come si scrivono davvero.
Utils.specGrammar = {
    DEATHKNIGHT = {
        { spec = "Unholy", prefix = { "u", "uh", "unholy" }, suffix = { "u", "uh", "unholy" } },
        { spec = "Blood",  prefix = { "b", "blood" },        suffix = { "b", "blood" } },
        { spec = "Frost",  prefix = { "f", "frost" },        suffix = { "f", "frost" } },
    },
    DRUID = {
        { spec = "Balance",     prefix = { "balance" },       suffix = { "balance" } },
        -- Il ferale ammette prefisso E suffisso; "feral"/"f" da soli valgono
        -- per ENTRAMBE le spec: Feral Cat e Feral Bear restano due voci
        -- separate e, in quel caso, si lascia la parola comune "Feral".
        { spec = "Feral Cat",   prefix = { "f", "cat", "feral" },
                                suffix = { "feral", "cat", "feral cat", "feralcat" } },
        { spec = "Feral Bear",  prefix = { "f", "bear", "feral" },
                                suffix = { "feral", "bear", "feral bear", "feralbear" } },
        { spec = "Restoration", prefix = { "r", "resto", "restoration" },
                                suffix = { "resto", "restoration" } },
    },
    HUNTER = {
        -- nomi estesi richiesti dal raid leader ("beast mastery", "marksmanship")
        { spec = "Beast Mastery", prefix = { "bm", "beast mastery", "beastmastery" },
                                  suffix = { "bm", "beast mastery", "beastmastery" } },
        { spec = "Marksmanship",  prefix = { "mm", "marksmanship", "marksman" },
                                  suffix = { "mm", "marksmanship", "marksman" } },
        { spec = "Survival",      prefix = { "s", "surv", "survival" }, suffix = { "s", "surv", "survival" } },
    },
    MAGE = {
        { spec = "Fire",   prefix = { "f", "fire" },  suffix = { "fire" } },
        { spec = "Frost",  prefix = { "frost" },      suffix = { "frost" } },
        { spec = "Arcane", prefix = { "arcane" },     suffix = { "arcane" } },
    },
    PALADIN = {
        { spec = "Protection",  prefix = { "p", "prot", "protection" },   suffix = { "prot", "protection" } },
        { spec = "Retribution", prefix = { "r", "ret", "retri", "retribution" }, suffix = { "ret", "retri", "retribution" } },
        { spec = "Holy",        prefix = { "h", "holy" },                 suffix = { "holy" } },
    },
    PRIEST = {
        { spec = "Shadow",     prefix = { "s", "sh", "shadow" },        suffix = { "shadow" } },
        { spec = "Discipline", prefix = { "d", "disci", "discipline" }, suffix = { "disci", "disco" } },
        { spec = "Holy",       prefix = { "h", "holy" },                suffix = { "holy" } },
    },
    ROGUE = {
        { spec = "Combat",        prefix = { "c", "combat" },                  suffix = { "combat" } },
        { spec = "Assassination", prefix = { "assa", "assassination" },        suffix = { "assa", "assassination" } },
        { spec = "Subtlety",      prefix = { "s", "sub", "subtlety", "sublety" }, suffix = { "s", "sub", "subtlety", "sublety" } },
    },
    SHAMAN = {
        { spec = "Enhancement", prefix = { "enha", "enhancement" }, suffix = { "enha", "enhancement" } },
        { spec = "Elemental",   prefix = { "ele", "elemental" },    suffix = { "ele", "elemental" } },
        { spec = "Restoration", prefix = { "r", "resto" },          suffix = { "resto" } },
    },
    WARLOCK = {
        { spec = "Affliction",  prefix = { "aff", "affly", "affliction", "afliction" },  suffix = { "aff", "affly", "affliction", "afliction" } },
        { spec = "Demonology",  prefix = { "demo", "demonology" },          suffix = { "demo", "demonology" } },
        { spec = "Destruction", prefix = { "destro", "destruction", "destriction" }, suffix = { "destro", "destruction", "destriction" } },
    },
    WARRIOR = {
        { spec = "Fury",       prefix = { "f", "fury" },                 suffix = { "fury" } },
        { spec = "Arms",       prefix = { "arms" },                      suffix = { "arms" } },
        { spec = "Protection", prefix = { "p", "prot", "protection" },   suffix = { "prot", "protection" } },
    },
}

-- Parole che non sono ne' classe ne' spec e che si ignorano nel match:
-- "spec" (abitudine diffusa: "spec fury") e i marcatori del GS.
local PARSER_NOISE = { ["spec"] = true, ["gs"] = true, ["k"] = true, ["kgs"] = true, ["kg"] = true }

local function wordSet(list)
    local s = {}
    for _, w in ipairs(list or {}) do s[w] = true end
    return s
end

-- Indice costruito una volta sola: corpo -> classe, e per ogni classe le
-- regole con i set di prefissi/suffissi. Include i nomi localizzati delle
-- classi del client (client non-EN) e la forma "death knight" (due parole).
function Utils:_Gram()
    if self._gram then return self._gram end
    local g = { classes = {}, body = {}, specWords = {} }
    for class, words in pairs(self.classBodies) do
        for _, w in ipairs(words) do g.body[w] = { class = class } end
    end
    g.body["deathknight"] = { class = "DEATHKNIGHT" }
    g.prefixWords = {}
    g.suffixWords = {}
    for _, tab in ipairs({ "LOCALIZED_CLASS_NAMES_MALE", "LOCALIZED_CLASS_NAMES_FEMALE" }) do
        local t = _G[tab]
        if t then
            for class in pairs(self.classBodies) do
                local nm = t[class]
                if type(nm) == "string" and nm ~= "" then
                    g.body[string.lower(nm)] = { class = class }
                end
            end
        end
    end
    for w, spec in pairs(self.bodySpecWords) do
        if g.body[w] then g.body[w].spec = spec end
    end
    for class, rules in pairs(self.specGrammar) do
        g.classes[class] = {}
        for _, r in ipairs(rules) do
            local rule = {
                spec = r.spec, class = class,
                prefix = r.prefix or {}, suffix = r.suffix or {},
                prefixSet = wordSet(r.prefix), suffixSet = wordSet(r.suffix),
            }
            g.classes[class][#g.classes[class] + 1] = rule
            -- unione dei prefissi/suffissi della classe: serve a validare le
            -- forme ATTACCATE ("protpala", "fdudu", "dudubear")
            g.prefixWords[class] = g.prefixWords[class] or {}
            g.suffixWords[class] = g.suffixWords[class] or {}
            for _, w in ipairs(rule.prefix) do g.prefixWords[class][w] = true end
            for _, w in ipairs(rule.suffix) do g.suffixWords[class][w] = true end
            for _, w in ipairs(rule.prefix) do
                g.specWords[#g.specWords + 1] = { word = w, spec = r.spec, class = class, len = #w }
            end
            for _, w in ipairs(rule.suffix) do
                g.specWords[#g.specWords + 1] = { word = w, spec = r.spec, class = class, len = #w }
            end
        end
    end
    -- alias piu' lungo prima: per la spec "nuda" conta la parola piu' specifica
    table.sort(g.specWords, function(a, b) return a.len > b.len end)
    -- elenco dei corpi (classi) per la scansione delle forme attaccate:
    -- prima le piu' lunghe, cosi' "deathknight" vince su "war" ecc.
    g.bodies = {}
    for w, e in pairs(g.body) do
        g.bodies[#g.bodies + 1] = { word = w, class = e.class, spec = e.spec }
    end
    table.sort(g.bodies, function(a, b)
        if #a.word ~= #b.word then return #a.word > #b.word end
        return a.word < b.word
    end)
    self._gram = g
    return g
end

-- Parole del messaggio (solo lettere, minuscole, senza le parole-rumore).
function Utils:_ParserWords(text)
    local lowered = string.lower(text or "")
    lowered = string.gsub(lowered, "death%s*knight", "deathknight")
    local words = {}
    for w in string.gmatch(lowered, "%a+") do
        if not PARSER_NOISE[w] then words[#words + 1] = w end
    end
    return words
end

-- GS. Forme della tabella:
--   gs 6542 | 6542 gs | 6542 | 6k | 6.5k | 6,5k | 6.5 (e "6k gs")
-- Un numero sotto il migliaio e' la forma "corta" (6 / 6.5) e vale migliaia;
-- un numero di 3 cifre non e' un GS (niente falsi positivi: "999" non passa).
function Utils:GSFromText(msg)
    if not msg or msg == "" then return nil end
    local s = string.lower(msg)
    -- virgola: 5,500 -> 5500 (migliaia) e 6,5 -> 6.5 (decimale)
    s = string.gsub(s, "(%d),(%d%d%d)", "%1%2")
    s = string.gsub(s, ",", ".")
    local function value(numStr)
        local v = tonumber(numStr)
        if not v then return nil end
        if v < 1000 then v = v * 1000 end        -- forma corta: 6 / 6.5 / 6k
        v = math.floor(v + 0.5)
        if v < 1000 or v > 20000 then return nil end
        return v
    end
    local num = string.match(s, "(%d+%.?%d*)%s*k%s*g%s*s")
    if not num then num = string.match(s, "(%d+%.?%d*)%s*k%f[%A]") end
    if not num then num = string.match(s, "g%s*s%f[%A]%s*[:%-=]?%s*(%d+%.?%d*)") end
    if not num then num = string.match(s, "(%d+%.?%d*)%s*g%s*s%f[%A]") end
    if not num then num = string.match(s, "(%d+%.%d+)") end          -- 6.5
    if not num then num = string.match(s, "%f[%d](%d%d%d%d%d?)%f[%D]") end  -- 6542
    return num and value(num) or nil
end

-- Ruolo: le stesse parole di prima (tank / heal), altrimenti dps.
function Utils:RoleFromText(msg)
    local lower = string.lower(msg or "")
    if string.find(lower, "tank") then return "tank" end
    if string.find(lower, "heal") then return "healer" end
    return "dps"
end

-- Cuore del parser: [PREFIX] BODY [SUFFIX] -> classe + spec.
-- REGOLA GENERALE: le tre parti possono anche essere ATTACCATE, senza spazi
-- ("fdudu", "udk", "mmhunt", "protpala", "dudubear", "6kgs"). Funzionano in
-- tutte le combinazioni: prefisso+corpo, corpo+suffisso, prefisso+corpo+
-- suffisso (quest'ultima solo dove la tabella la ammette, cioe' il ferale),
-- e in mezzo alle forme normali con gli spazi.
-- Ritorna SEMPRE una tabella:
--   class   classe canonica ("PALADIN") o nil
--   spec    spec canonica ("Protection") o nil
--   specFrom "prefix" | "suffix" | "both" | "body" | "bare" | "generic"
--           ("generic" = parola valida per due spec: resta la parola comune,
--            decide il raid leader)
function Utils:ParseClassSpec(text)
    local out = {}
    if not text or text == "" then return out end
    local g = self:_Gram()
    local words = self:_ParserWords(text)
    if #words == 0 then return out end

    -- Suffissi candidati di una posizione: la parola dopo, le due parole dopo
    -- insieme ("feral cat") e la seconda da sola.
    local function adjacent(i)
        local s1, s2 = words[i + 1], words[i + 2]
        local combined = (s1 and s2) and (s1 .. " " .. s2) or nil
        return { s1, combined, s2 }
    end

    -- Regole di una classe messe alla prova con un prefisso e dei suffissi.
    local function evaluate(class, pres, sufs)
        local cands = {}
        for _, rule in ipairs(g.classes[class] or {}) do
            local pWord
            for _, pre in ipairs(pres or {}) do
                if pre and rule.prefixSet[pre] and (not pWord or #pre > #pWord) then
                    pWord = pre
                end
            end
            local sWord
            for _, cand in ipairs(sufs or {}) do
                if cand and rule.suffixSet[cand] and (not sWord or #cand > #sWord) then
                    sWord = cand
                end
            end
            if pWord or sWord then
                cands[#cands + 1] = {
                    spec = rule.spec,
                    score = (pWord and sWord) and 3 or (pWord and 2 or 1),
                    len = #(pWord or sWord or ""),
                    p = pWord, s = sWord,
                }
            end
        end
        return cands
    end

    -- Sceglie la spec fra i candidati e la scrive in `out`.
    local function choose(cands)
        table.sort(cands, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            if a.len ~= b.len then return a.len > b.len end
            return false
        end)
        local best = cands[1]
        -- Regola generale: o prefisso o suffisso. Se il vincitore ha SOLO il
        -- prefisso e un'altra spec combacia SOLO col suffisso, il messaggio e'
        -- contraddittorio: si tiene la classe e basta ("p pala holy").
        if best.p and not best.s then
            for k = 2, #cands do
                if cands[k].s and not cands[k].p and cands[k].spec ~= best.spec then
                    return false
                end
            end
        end
        out.spec = best.spec
        out.specFrom = (best.p and best.s and "both") or (best.p and "prefix") or "suffix"
        -- Parita' non risolvibile ("feral"/"f" da soli valgono sia per il Cat
        -- sia per il Bear): il parser NON indovina. Feral Cat e Feral Bear
        -- restano due voci separate e la scelta e' del raid leader: resta la
        -- parola comune alle due spec, cioe' "Feral".
        local tied, same = {}, true
        for k = 1, #cands do
            local c = cands[k]
            if c.score == best.score and c.len == best.len and c.spec ~= best.spec then
                if #tied > 0 and tied[1] ~= c.spec then same = false end
                tied[#tied + 1] = c.spec
            end
        end
        if #tied > 0 and same then
            local a, b = {}, {}
            for w in string.gmatch(best.spec, "%a+") do a[#a + 1] = w end
            for w in string.gmatch(tied[1], "%a+") do b[#b + 1] = w end
            local common
            for k = 1, math.min(#a, #b) do
                if a[k] == b[k] then common = a[k] else break end
            end
            if common then
                out.spec = common
                out.specFrom = "generic"
            end
        end
        return true
    end

    for i = 1, #words do
        local w = words[i]

        -- (a) la parola E' una classe: prefisso = parola prima, suffisso = dopo
        local direct = g.body[w]
        if direct then
            out.class = direct.class
            if direct.spec then
                -- Boomkin / Boomie / Disco: la spec sta nel corpo e la tabella
                -- dice che prefisso e suffisso non sono ammessi
                out.spec = direct.spec
                out.specFrom = "body"
                return out
            end
            local prevs = { words[i - 1] }
            if i > 2 then prevs[#prevs + 1] = words[i - 2] .. " " .. words[i - 1] end
            local cands = evaluate(direct.class, prevs, adjacent(i))
            if #cands > 0 and choose(cands) then return out end
            return out
        end

        -- (b) forme ATTACCATE: "fdudu", "udk", "mmhunt", "protpala",
        --     "dudubear", "warriors" (plurale). Le lettere restanti devono
        --     essere un prefisso o un suffisso VERI della classe, altrimenti
        --     non si tocca niente ("Warmane" non e' un warrior).
        for _, b in ipairs(g.bodies) do
            local s, e = string.find(w, b.word, 1, true)
            if s then
                local preTok = string.sub(w, 1, s - 1)
                local sufTok = string.sub(w, e + 1)
                local extra = (sufTok ~= "")
                if sufTok == "s" or sufTok == "es" then sufTok = "" end   -- plurale
                -- i corpi che portano gia' la spec (boomkin/boomie/disco) non
                -- ammettono prefisso ne' suffisso: si salta
                if (preTok ~= "" or extra) and not b.spec then
                    local pOK = (preTok == "") or (g.prefixWords[b.class] or {})[preTok]
                    local sOK = (sufTok == "") or (g.suffixWords[b.class] or {})[sufTok]
                    if pOK and sOK then
                        local sufs = {}
                        if sufTok ~= "" then sufs[#sufs + 1] = sufTok end
                        for _, x in ipairs(adjacent(i)) do sufs[#sufs + 1] = x end
                        local pres
                        if preTok ~= "" then
                            pres = { preTok }
                        else
                            pres = { words[i - 1] }
                            if i > 2 then pres[#pres + 1] = words[i - 2] .. " " .. words[i - 1] end
                        end
                        local cands = evaluate(b.class, pres, sufs)
                        -- la classe si tiene anche senza spec ("warriors"):
                        -- le lettere attaccate erano un alias VERO della classe
                        out.class = b.class
                        if #cands > 0 and choose(cands) then return out end
                        return out
                    end
                end
            end
        end
    end

    -- (c) nessuna classe: la spec scritta da sola ("prot", "resto", "fury").
    -- Vale solo se NON e' ambigua: due spec diverse (o la stessa spec di due
    -- classi, es. "prot" warrior/paladin) non fanno indovinare la classe.
    local seen, hitClasses = {}, {}
    for _, e in ipairs(g.specWords) do
        for _, w in ipairs(words) do
            if w == e.word then
                seen[e.spec] = true
                hitClasses[e.spec] = hitClasses[e.spec] or {}
                hitClasses[e.spec][e.class] = true
            end
        end
    end
    local n, only = 0, nil
    for spec in pairs(seen) do n = n + 1; only = spec end
    if n == 1 then
        out.spec = only
        out.specFrom = "bare"
        local cls, multi = nil, false
        for class in pairs(hitClasses[only] or {}) do
            if cls and cls ~= class then multi = true end
            cls = class
        end
        if cls and not multi then out.class = cls end
    end
    return out
end

-- Una passata: classe, spec, ruolo, GS. E' questa che usano Whisplist e MS.
function Utils:ParseWhisper(msg)
    local out = self:ParseClassSpec(msg)
    out.text = msg or ""
    out.gs = self:GSFromText(msg)
    out.role = self:RoleFromText(msg)
    return out
end

-- Parola di classe "bella" per i whisper di prova ("dk", "dudu", "pala"...).
function Utils:BodyWordFor(class)
    local words = self.classBodies[class]
    return words and words[1] or nil
end

-- Parola di spec della tabella per generare i whisper di prova: si preferisce
-- la piu' lunga (piu' leggibile) fra i prefissi della spec.
function Utils:SpecWordFor(class, spec)
    local rules = (self:_Gram().classes or {})[class] or {}
    -- le parole condivise fra due spec (es. "f" e "feral" del druido) non
    -- vanno usate per i test: meglio "cat" / "bear", che sono univoche.
    local shared, seen = {}, {}
    for _, rule in ipairs(rules) do
        for _, w in ipairs(rule.prefix) do
            if seen[w] and seen[w] ~= rule.spec then shared[w] = true end
            seen[w] = rule.spec
        end
    end
    for _, rule in ipairs(rules) do
        if rule.spec == spec then
            local best
            for _, w in ipairs(rule.prefix) do
                if not shared[w] and (not best or #w > #best) then best = w end
            end
            if not best then
                for _, w in ipairs(rule.prefix) do
                    if not best or #w > #best then best = w end
                end
            end
            return best
        end
    end
    return nil
end

function Utils:EnsureInsertLinkHook()
    if self._insertLinkHooked then return end
    self._insertLinkHooked = true
    self.insertLinkTargets = self.insertLinkTargets or {}
    local orig = ChatEdit_InsertLink
    ChatEdit_InsertLink = function(text)
        for _, t in ipairs(Utils.insertLinkTargets) do
            local edit = t.edit
            if text and edit and edit.IsShown and edit:IsShown() and edit.HasFocus and edit:HasFocus() then
                if edit.Insert then
                    edit:Insert(text)
                else
                    edit:SetText((edit:GetText() or "") .. text)
                end
                if t.onInsert then t.onInsert(text) end
                return true
            end
        end
        if orig then return orig(text) end
    end
end

function Utils:RegisterInsertLink(edit, onInsert)
    if not edit then return end
    self:EnsureInsertLinkHook()
    self.insertLinkTargets = self.insertLinkTargets or {}
    table.insert(self.insertLinkTargets, {edit = edit, onInsert = onInsert})
end

function Utils:ClassLabel(class)
    local labels = {
        WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
        ROGUE = "Rogue", PRIEST = "Priest", DEATHKNIGHT = "DK",
        SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
    }
    return labels[(class or ""):upper()] or class or "?"
end

-- ============================================================
-- Dropdown (3.3.5, no Ace)
-- ============================================================

-- ============================================================
-- Window skin (opaque backgrounds for 3.3.5)
-- DialogBox-Background is mostly transparent; ChatFrameBackground is solid.
-- ============================================================

function Utils:ThemePresets()
    return {
        default = { fill = {0.05, 0.05, 0.07, 1}, bg = {0.08, 0.08, 0.10, 1}, border = {0.70, 0.70, 0.70, 1} },
        dark    = { fill = {0.02, 0.02, 0.04, 1}, bg = {0.04, 0.04, 0.06, 1}, border = {0.40, 0.40, 0.48, 1} },
        gold    = { fill = {0.10, 0.07, 0.01, 1}, bg = {0.12, 0.09, 0.02, 1}, border = {0.85, 0.70, 0.20, 1} },
    }
end

function Utils:ColorToArray(c)
    if not c then return {0.08, 0.08, 0.10, 1} end
    if c.r then return {c.r, c.g, c.b, c.a or 1} end
    return {c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1}
end

function Utils:GetThemeColors(theme)
    local a = RLSuite.db and RLSuite.db.profile.appearance or {}
    if a.bg and a.bg.r then
        return {
            fill = self:ColorToArray(a.fill),
            bg = self:ColorToArray(a.bg),
            border = self:ColorToArray(a.border),
        }
    end
    theme = theme or a.theme or "default"
    return self:ThemePresets()[theme] or self:ThemePresets().default
end

function Utils:GetUIFont()
    local a = RLSuite.db and RLSuite.db.profile.appearance or {}
    return a.font or "Fonts\\FRIZQT__.TTF", a.fontSize or 12
end

function Utils:WindowBackdrop(f)
    -- Tooltip border sits on the frame edge. insets 0 = fill goes to that same edge.
    local edge = 16
    if RLSuite.db and RLSuite.db.profile.appearance and RLSuite.db.profile.appearance.edgeSize then
        edge = RLSuite.db.profile.appearance.edgeSize
    end
    if edge > 16 then edge = 16 end
    if edge < 8 then edge = 8 end
    if f and f.GetWidth then
        local w, h = f:GetWidth() or 200, f:GetHeight() or 200
        local minSide = math.min(w, h)
        if minSide < 80 and edge > 10 then edge = 10 end
    end
    return {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = edge,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    }
end

function Utils:SkinMacroButton(btn)
    if not btn then return end
    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    local c = self:GetThemeColors()
    btn:SetBackdropColor(0.10, 0.10, 0.12, 1)
    btn:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)

    if not btn.slotBg then
        btn.slotBg = btn:CreateTexture(nil, "BACKGROUND")
        btn.slotBg:SetDrawLayer("BACKGROUND", 1)
    end
    btn.slotBg:SetTexture("Interface\\Buttons\\UI-Quickslot")
    btn.slotBg:ClearAllPoints()
    btn.slotBg:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    btn.slotBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.slotBg:SetVertexColor(0.9, 0.9, 0.9, 1)
    btn.slotBg:Show()

    if not btn.slotBorder then
        btn.slotBorder = btn:CreateTexture(nil, "BORDER")
        btn.slotBorder:SetDrawLayer("BORDER", 7)
    end
    btn.slotBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    btn.slotBorder:ClearAllPoints()
    btn.slotBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", -8, 8)
    btn.slotBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 8, -8)
    btn.slotBorder:Show()

    if btn.icon then
        btn.icon:SetDrawLayer("ARTWORK", 0)
        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
        btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if btn.highlight then
        btn.highlight:ClearAllPoints()
        btn.highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        btn.highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
    if btn.pushed then
        btn.pushed:ClearAllPoints()
        btn.pushed:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        btn.pushed:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
end

function Utils:SkinFrame(f)
    if not f or not f.SetBackdrop then return end
    local c = self:GetThemeColors()
    f:SetAlpha(1)
    if f.rlsBgFill then
        f.rlsBgFill:Hide()
    end
    f:SetBackdrop(self:WindowBackdrop(f))
    f:SetBackdropColor(c.fill[1], c.fill[2], c.fill[3], 1)
    -- Le finestre marcate _noOuterBorder (main bar, Groupmaking, Invite
    -- engine, MS Manager, Loot Manager) non hanno il bordo esterno del
    -- dialog: il riempimento resta, il Tooltip-Border diventa invisibile.
    if f._noOuterBorder then
        f:SetBackdropBorderColor(0, 0, 0, 0)
    else
        f:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
    end
end

function Utils:AllWindows()
    local list = {}
    local function add(fr)
        if fr then table.insert(list, fr) end
    end
    add(RLSuite.mainWindow and RLSuite.mainWindow.frame)
    add(RLSuite.macrobar and RLSuite.macrobar.keypadFrame)
    add(RLSuite.macrobar and RLSuite.macrobar.editFrame)
    -- Il Raid Frame HUD non viene mai skinnato: nessuno sfondo/bordo.
    return list
end

function Utils:AllTabPanes()
    local list = {}
    local function add(fr)
        if fr then table.insert(list, fr) end
    end
    add(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame)
    add(RLSuite.msManager and RLSuite.msManager.frame)
    add(RLSuite.lootManager and RLSuite.lootManager.frame)
    return list
end

function Utils:AllDockedPanels()
    -- The Config surface is now a self-contained AceGUI window (not a
    -- docked tab pane with inner panels), so there is nothing to skin.
    return {}
end

function Utils:SkinBox(box)
    if not box or not box.SetBackdrop then return end
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    local c = self:GetThemeColors()
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
end

-- Skin ACE per TUTTI i bottoni di dialogo dell'addon: NIENTE piu' grafica
-- di default Blizzard (grigio UIPanelButtonTemplate); al suo posto il look
-- piatto scuro coerente con le finestre skinnate/AceGUI: sfondo scuro,
-- bordo tooltip fine, bordo DORATO in hover (come le righe selezionate).
function Utils:SkinButton(btn)
    if not btn then return end
    if btn.SetNormalTexture then
        btn:SetNormalTexture(nil)
        if btn.SetPushedTexture then btn:SetPushedTexture(nil) end
        if btn.SetDisabledTexture then btn:SetDisabledTexture(nil) end
    end
    if btn.SetHighlightTexture then
        btn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        local ht = btn.GetHighlightTexture and btn:GetHighlightTexture()
        if ht and ht.SetVertexColor then ht:SetVertexColor(1, 1, 1, 0.08) end
    end
    -- BOTTONI BORDERLESS: niente piu' il bordo "dialog" (UI-Tooltip-Border)
    -- su alcun pulsante dell'addon. Resta il fill scuro; l'hover schiarisce
    -- il riempimento invece di accendere un bordo.
    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        btn:SetBackdropColor(0.16, 0.18, 0.22, 0.95)
    end
    if btn.HookScript then
        btn:HookScript("OnEnter", function(s)
            if s.SetBackdropColor then s:SetBackdropColor(0.26, 0.29, 0.36, 0.98) end
        end)
        btn:HookScript("OnLeave", function(s)
            if s.SetBackdropColor then s:SetBackdropColor(0.16, 0.18, 0.22, 0.95) end
        end)
    end
end

function Utils:SkinRow(row, selected)
    if not row or not row.SetBackdrop then return end
    -- Anche le righe-lista (pulsanti) sono borderless: la selezione non si
    -- affida piu' al bordo oro ma a un riempimento caldo ben piu' marcato.
    row:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    if selected then
        row:SetBackdropColor(0.34, 0.26, 0.06, 0.98)
    else
        row:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
    end
end

function Utils:SkinAllWindows()
    for _, fr in ipairs(self:AllWindows()) do
        self:SkinFrame(fr)
    end
    for _, fr in ipairs(self:AllTabPanes()) do
        if fr.rlsBgFill then fr.rlsBgFill:Hide() end
        self:SkinFrame(fr)
    end
    for _, fr in ipairs(self:AllDockedPanels()) do
        if fr.rlsBgFill then fr.rlsBgFill:Hide() end
        self:SkinBox(fr)
    end
    if RLSuite.lootManager and RLSuite.lootManager.SkinInner then
        RLSuite.lootManager:SkinInner()
    end
    if RLSuite.groupmaking and RLSuite.groupmaking.SkinInner then
        RLSuite.groupmaking:SkinInner()
    end
    if RLSuite.msManager and RLSuite.msManager.SkinInner then
        RLSuite.msManager:SkinInner()
    end
    if RLSuite.mainWindow and RLSuite.mainWindow.SkinInner then
        RLSuite.mainWindow:SkinInner()
    end
end

function Utils:CloseDropdownMenu()
    -- Lo stato si azzera PRIMA di nascondere: cosi' anche se l'OnHide del menu
    -- dovesse fallire non resta nessun riferimento sporco in giro.
    local m = self.activeMenu
    self.activeMenu = nil
    if self.dropCatcher then self.dropCatcher:Hide() end
    if m then m:Hide() end
end

-- Richiesta esplicita: niente cadaveri invisibili sopra i moduli.
function Utils:AssertNoZombieCatcher()
    if self.dropCatcher and self.dropCatcher:IsShown() and not (self.activeMenu and self.activeMenu:IsShown()) then
        self:CloseDropdownMenu()
    end
end

-- ============================================================
-- Scroll clip di INPUT (bug "fstack LootManager"): in 3.3.5 lo scroll
-- clippa solo la GRAFICA. Una riga-Bottone (EnableMouse + click) dello
-- scroll-child fuori dal viewport resta INVISIBILE ma hit-testabile
-- sopra l'intera finestra e ruba i click a tutto il resto. Con tante
-- entry il contenuto diventa alto quanto l'intera UI: "a volte non
-- riesco a cliccare nulla nel Loot Manager".
-- Rimediato in modo generico: le righe che escono dal viewport vengono
-- NASCOSTE (Hide = niente grafica e niente input; la geometria del
-- contenuto non cambia, quindi lo scroll resta identico).
--
-- Uso:
--   1) Utils:RegisterScrollClip(scroll, content) una tantum
--   2) Utils:ClearScrollClip(content) all'inizio di ogni rebuild righe
--   3) Utils:ClipScrollRow(content, row, topOffset, height) per riga
--   4) Utils:RefreshScrollClip(content) alla fine del rebuild
-- ============================================================
function Utils:RegisterScrollClip(scroll, content)
    if not scroll or not content then return end
    content._rlsScrollClip = { scroll = scroll, rows = {} }
    local function refresh()
        Utils:RefreshScrollClip(content)
    end
    scroll:HookScript("OnVerticalScroll", refresh)
    scroll:HookScript("OnMouseWheel", refresh)
    scroll:HookScript("OnSizeChanged", refresh)
end

function Utils:ClearScrollClip(content)
    if content and content._rlsScrollClip then
        content._rlsScrollClip.rows = {}
    end
end

function Utils:ClipScrollRow(content, row, topOffset, h)
    local st = content and content._rlsScrollClip
    if not st or not row then return end
    st.rows[#st.rows + 1] = { row = row, top = topOffset or 0, h = h or 0 }
end

function Utils:RefreshScrollClip(content)
    local st = content and content._rlsScrollClip
    if not st then return end
    local off = (st.scroll.GetVerticalScroll and st.scroll:GetVerticalScroll()) or 0
    local vh = (st.scroll.GetHeight and st.scroll:GetHeight()) or 0
    if vh < 1 then
        -- dimensione non ancora nota: mostra tutto (comportamento pre-fix)
        return
    end
    for _, r in ipairs(st.rows) do
        local vis = (r.top < off + vh) and (r.top + r.h > off)
        if vis then r.row:Show() else r.row:Hide() end
    end
end

function Utils:CreateDropdown(parent, name, width, height)
    local dd = CreateFrame("Frame", name, parent)
    dd:SetSize(width, height)
    dd:EnableMouse(true)
    dd:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left=0, right=0, top=0, bottom=0}
    })
    dd:SetBackdropColor(0.05, 0.05, 0.07, 1)
    dd.text = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dd.text:SetPoint("LEFT", dd, "LEFT", 5, 0)
    dd.text:SetPoint("RIGHT", dd, "RIGHT", -18, 0)
    dd.text:SetJustifyH("LEFT")
    dd.text:SetText("...")

    dd.button = CreateFrame("Button", nil, dd)
    dd.button:SetSize(16, 16)
    dd.button:SetPoint("RIGHT", dd, "RIGHT", -2, 0)
    dd.button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    dd.button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    dd.button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    dd.options = {}
    dd.value = nil
    dd.onSelect = nil

    local function toggle(_, button)
        -- Il tasto DESTRO e' un'azione opzionale del chiamante (es. nel Log
        -- segna il pull come boss/trash): se non la usa, resta un click
        -- normale. Il tasto SINISTRO apre/chiude sempre il menu.
        if button == "RightButton" and type(dd.onRightClick) == "function" then
            dd.onRightClick(dd)
            return
        end
        Utils:ToggleDropdownMenu(dd)
    end
    dd:SetScript("OnMouseUp", toggle)
    -- La freccia NON e' un secondo punto di click: il click passa al frame del
    -- dropdown (OnMouseUp) che e' l'UNICO che apre/chiude. Con due handler sullo
    -- stesso click (OnMouseUp del frame + OnClick del bottone, che in 3.3.5
    -- arrivano entrambi) il menu si apriva e si richiudeva nello stesso istante.
    if dd.button.EnableMouse then dd.button:EnableMouse(false) end
    if dd.button.SetScript then dd.button:SetScript("OnClick", nil) end
    -- Guardia "pannello invisibile" (fstack): il catcher a tutto schermo e
    -- il menu NON devono mai sopravvivere alla propria finestra. Quando la
    -- finestra (o il dropdown stesso) viene nascosta senza che il menu sia
    -- stato chiuso, forza la chiusura: senza questa rete il cadavere del
    -- catcher restava sopra TUTTO e rubava i click a tutta la UI. Vale per
    -- TUTTI i moduli, perche' usano tutti questo CreateDropdown.
    dd:SetScript("OnHide", function()
        if Utils.activeMenu and Utils.activeMenu.owner == dd then
            Utils:CloseDropdownMenu()
        elseif Utils.dropCatcher and Utils.dropCatcher:IsShown() and Utils.activeMenu == nil then
            -- catcher zombie senza menu: ugualmente chiuso
            Utils:CloseDropdownMenu()
        end
    end)
    return dd
end

function Utils:SetupDropdown(dd, options, currentValue, onSelect)
    local normalized = {}
    for _, o in ipairs(options or {}) do
        if type(o) == "table" then
            table.insert(normalized, {text = o.text or tostring(o.value), value = o.value})
        else
            table.insert(normalized, {text = tostring(o), value = o})
        end
    end
    dd.options = normalized
    dd.onSelect = onSelect

    local found
    for _, o in ipairs(normalized) do
        if o.value == currentValue or o.text == currentValue then
            found = o
            break
        end
    end
    if found then
        dd.value = found.value
        dd.text:SetText(found.text)
    elseif currentValue then
        dd.value = currentValue
        dd.text:SetText(tostring(currentValue))
    elseif normalized[1] then
        dd.value = normalized[1].value
        dd.text:SetText(normalized[1].text)
    end
end

-- Apre il menu di un dropdown. Separata dal toggle perche' il chiamante la
-- esegue dentro pcall: un errore qui non deve MAI lasciare in giro il catcher
-- (che e' a schermo intero e mangerebbe ogni click successivo: era una delle
-- vie per cui la dropdown "smetteva di aprirsi").
function Utils:OpenDropdownMenu(dd, options)
    if not self.dropCatcher then
        local catcher = CreateFrame("Button", "RLSuiteDropCatcher", UIParent)
        catcher:SetAllPoints(UIParent)
        -- STRATA PIU' ALTA ESISTENTE ("TOOLTIP"): la finestra di configurazione
        -- e' un AceGUI Window che vive in FULLSCREEN_DIALOG e si ri-alza da sola
        -- a ogni click (SetToplevel). Menu e catcher DEVONO stare sopra di lei,
        -- altrimenti il menu si apre DIETRO la finestra (invisibile) e il click
        -- "fuori" non chiude niente. E' la stessa scelta che fa AceConfigDialog
        -- per i propri popup (AceConfigDialog-3.0.lua: SetFrameStrata("TOOLTIP")).
        catcher:SetFrameStrata("TOOLTIP")
        catcher:SetFrameLevel(1)
        catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        catcher:SetScript("OnClick", function() Utils:CloseDropdownMenu() end)
        -- WATCHDOG (auto-riparazione): finche' il catcher e' visibile, a ogni
        -- frame si controlla che il menu esista DAVVERO. Se per qualunque
        -- ragione (errore, Hide di un antenato, cambio pannello) il menu non
        -- c'e' piu', il catcher si spegne da solo: il "cadavere invisibile a
        -- schermo intero" che ruba i click non puo' piu' sopravvivere.
        catcher:SetScript("OnUpdate", function()
            Utils:AssertNoZombieCatcher()
        end)
        self.dropCatcher = catcher
    end
    self.dropCatcher:Show()
    self.dropCatcher:SetFrameLevel(1)

    -- Riutilizza il menu del dropdown: CREARE un frame nuovo a ogni toggle
    -- (tra l'altro sempre con lo stesso nome globale) lasciava cadaveri in
    -- giro per la UI (memoria + incertezze sullo z-order/FX dell'fstack).
    -- SENZA nome globale: ogni dropdown ha il SUO menu, e creare piu' frame
    -- con lo stesso nome ("RLSuiteDropMenu") e' la classica fonte di guai in
    -- 3.3.5 (il registro dei nomi tiene solo l'ultimo frame creato).
    local menu = dd._rlsDropMenu or CreateFrame("Frame", nil, UIParent)
    dd._rlsDropMenu = menu
    -- Vedi il catcher: TOOLTIP + livello sopra il catcher, cosi' il menu e'
    -- SEMPRE sopra la finestra di config, in qualunque punto dello stack sia.
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(20)
    -- Se il menu svanisce per QUALUNQUE ragione (finestra padre nascosta,
    -- cambio tab, /rls, Hide diretto), IL CATCHER MUORE SEMPRE CON LUI:
    -- e' l'unica difesa affidabile contro lo zombie full-screen invisibile
    -- che "copre tutta la finestra" e blocca ogni click (il bug fstack).
    menu:SetScript("OnHide", function()
        if Utils.dropCatcher and Utils.dropCatcher:IsShown() then
            Utils.dropCatcher:Hide()
        end
        if Utils.activeMenu == menu then
            Utils.activeMenu = nil
        end
    end)
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left=0, right=0, top=0, bottom=0}
    })
    menu:SetBackdropColor(0.05, 0.05, 0.07, 1)
    menu.owner = dd
    local width = math.max(dd:GetWidth(), 80)
    menu:SetSize(width, #options * 20 + 8)
    -- il menu e' RIUSATO tra le aperture (dd._rlsDropMenu): senza ClearAllPoints
    -- gli ancoraggi si accumulano, senza Show() resta NASCOSTO dopo la prima
    -- chiusura -> "le dropdown si aprono una volta sola" (il primo menu era
    -- visibile solo perche' un frame appena creato nasce mostrato).
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)

    -- Se qualsiasi finestra/pannello che OSPITA il dropdown si nasconde,
    -- kill immediato del menu (di killing cascata dal hook 2 anche il catcher).
    local anc = dd
    local hops = 0
    while anc and anc ~= UIParent and hops < 8 do
        if anc.HookScript and not anc._rlsDropMenuKillHook then
            anc._rlsDropMenuKillHook = true
            anc:HookScript("OnHide", function()
                Utils:CloseDropdownMenu()
            end)
        end
        anc = anc.GetParent and anc:GetParent()
        hops = hops + 1
    end

    -- I pulsanti-opzione vengono RIUSATI (e ri-testualizzati) a ogni apertura:
    -- creare bottoni nuovi a ogni click accumulava frames figli del menu per
    -- sempre e, dopo tante aperture, rendeva il menu pesante e inaffidabile.
    menu.optionButtons = menu.optionButtons or {}
    for i, opt in ipairs(options) do
        local btn = menu.optionButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, menu)
            menu.optionButtons[i] = btn
            btn:SetSize(width - 8, 18)
            btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 20)
            btn.txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.txt:SetAllPoints(btn)
            btn.txt:SetJustifyH("LEFT")
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        end
        btn.optValue = opt.value
        btn.optText = opt.text
        btn.txt:SetText(opt.text)
        if dd.value == opt.value then
            btn.txt:SetTextColor(1, 0.82, 0)
        else
            btn.txt:SetTextColor(1, 1, 1)
        end
        -- il click legge SEMPRE l'opzione corrente del bottone (riusato)
        btn:SetScript("OnClick", function()
            dd.value = btn.optValue
            dd.text:SetText(btn.optText)
            Utils:CloseDropdownMenu()
            if dd.onSelect then
                dd.onSelect(btn.optValue, btn.optText)
            end
        end)
        btn:Show()
    end
    -- liste piu' corte della volta precedente: nasconde i bottoni in eccesso
    for i = #options + 1, #menu.optionButtons do
        menu.optionButtons[i]:Hide()
    end

    menu:Show()
    self.activeMenu = menu
    return true
end

-- Apri/chiudi di un dropdown: A OGNI click si riparte da zero, quindi non
-- esiste uno stato interno che possa "consumarsi" dopo N aperture.
function Utils:ToggleDropdownMenu(dd)
    if type(dd) ~= "table" then return end
    local menu = dd._rlsDropMenu
    local wasOpen = (menu ~= nil and menu:IsShown() and self.activeMenu == menu)
    -- chiude SEMPRE ed incondizionatamente (menu, catcher e stato sporco)
    self:CloseDropdownMenu()
    if wasOpen then return end

    local options = dd.options or {}
    if #options == 0 then return end

    local ok = pcall(function() self:OpenDropdownMenu(dd, options) end)
    if not ok then
        -- niente zombie: se l'apertura e' fallita, si spegne tutto e si
        -- riprovera' al prossimo click
        self:CloseDropdownMenu()
    end
end
-- ============================================================
-- Window layout helpers (finestre staccabili / anchors)
-- ============================================================

-- Ritorna (creandola se serve) la sottotabella layout per una finestra.
function Utils:WindowLayout(key)
    RLSuite.db.profile.layout = RLSuite.db.profile.layout or {}
    local t = RLSuite.db.profile.layout[key]
    if not t then
        t = {}
        RLSuite.db.profile.layout[key] = t
    end
    return t
end

-- Salva la posizione corrente di un frame nella layout della finestra.
function Utils:PersistFramePos(frame, key)
    if not frame then return end
    local point, _, relPoint, x, y = frame:GetPoint()
    local L = self:WindowLayout(key)
    L.point = point
    L.relPoint = relPoint
    L.x = x
    L.y = y
end

-- Applica la posizione salvata a una finestra; se non c'e', la ancora
-- sotto la barra principale (comportamento dock-like iniziale) e, se
-- passata, applica un offset a cascata per non sovrapporre le finestre.
-- NOTA: SetPoint(point, relativeTo, relativePoint, x, y): relativeTo
-- deve essere un frame (o il suo nome), relativePoint un punto valido.
function Utils:ApplySavedPos(frame, key, cascadeOffset)
    if not frame then return end
    frame:ClearAllPoints()
    local L = self:WindowLayout(key)
    if L.point then
        frame:SetPoint(L.point, UIParent, L.relPoint or L.point, L.x or 0, L.y or 0)
    else
        local dx, dy = 0, 0
        if type(cascadeOffset) == "function" then
            dx, dy = cascadeOffset()
        end
        local bar = RLSuite.mainWindow and RLSuite.mainWindow.frame
        if bar then
            frame:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", dx, -2 + dy)
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
        end
    end
end

-- Riporta una finestra dentro lo schermo: clamp della dimensione (mai
-- piu' grande dello schermo, in coordinate della scala effettiva) e
-- riposizionamento se un angolo finisce fuori vista. Serve per
-- auto-sanare i salvataggi rovinati (es. dimensioni enormi registrate
-- mentre il vecchio StartSizing litigava con il clamp dello schermo).
function Utils:ClampWindowToScreen(frame)
    if not frame or not (GetScreenWidth and GetScreenHeight) then return end
    local scale = frame:GetEffectiveScale() or 1
    local sw = (GetScreenWidth() or 0) / scale
    local sh = (GetScreenHeight() or 0) / scale
    if sw <= 0 or sh <= 0 then return end
    local w = frame:GetWidth() or 0
    local h = frame:GetHeight() or 0
    if w > sw or h > sh then
        w = math.min(w, sw)
        h = math.min(h, sh)
        frame:SetSize(w, h)
    end
    local left = frame.GetLeft and frame:GetLeft()
    local top = frame.GetTop and frame:GetTop()
    if type(left) == "number" and type(top) == "number" then
        local newLeft = left
        if left < 0 then newLeft = 0 elseif left + w > sw then newLeft = math.max(0, sw - w) end
        local newTop = top
        if top > sh then newTop = sh elseif top - h < 0 then newTop = h end
        if newLeft ~= left or newTop ~= top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newLeft, newTop)
        end
    end
end

-- Porta una finestra in primo piano sopra le altre (stessa strata).
-- Assegna un frame level esplicito e distanziato (passo 50): cosi' i
-- figli con frameLevel relativo (+5..+20: grip di resize, editbox, ecc.)
-- restano dentro la "fascia" della loro finestra e non sbucano sopra le
-- finestre vicine, evitando le sovrapposizioni parziali (parti di una
-- finestra sopra e parti sotto un'altra) quando si spostano le finestre.
-- Riposiziona deterministicamente i livelli di un intero sotto-albero:
-- base = livello corrente del root; ogni figlio prende base+2+2*indice
-- (ordine di CREAZIONE dei figli, stesso ordine del drawing WoW). Causa:
-- qualunque drift pregresso (refreshes + raises) viene cancellato.
function Utils:RepinFrameOrder(root, seenTbl)
    if not root or not root.GetChildren then return end
    local seen = seenTbl or {}
    if seen[root] then return end
    seen[root] = true
    local base = root.GetFrameLevel and root:GetFrameLevel() or 0
    local ok, kids = pcall(function() return { root:GetChildren() } end)
    if not ok or not kids then return end
    for i, kid in ipairs(kids) do
        if kid.SetFrameLevel then
            kid:SetFrameLevel(base + 2 + 2 * i)
        end
        Utils:RepinFrameOrder(kid, seen)
    end
end

local function ShiftSubtree(node, delta, seen)
    -- Sposta il frame E tutta la gerarchia dei figli dello stesso delta:
    -- i livelli 3.3.5 NON ereditano, quindi senza questo shift i figli
    -- restano sotto e l'hit-test finisce sulla finestra invece che sui
    -- bottoni (il bug "le righe del loot manager non ricevono i click").
    if type(node) ~= "table" or seen[node] then return end
    seen[node] = true
    if node.GetFrameLevel and node.SetFrameLevel then
        local lvl = node:GetFrameLevel()
        if lvl then
            local nl = lvl + delta
            if nl < 0 then nl = 0 end
            node:SetFrameLevel(nl)
        end
    end
    if node.GetChildren then
        local ok, kids = pcall(function() return { node:GetChildren() } end)
        if ok and type(kids) == "table" then
            for i = 1, #kids do ShiftSubtree(kids[i], delta, seen) end
        end
    end
end

-- NPC id dal GUID. Formato 3.3.5 (esadecimale, high "F1xx": l'entry sta nei
-- char 9-12, es. 0xF130008F040000AA -> 0x8F04 = 36612 Lord Marrowgar) oppure
-- formato moderno "Creature-0-...-ID-spawnID" (6o campo). Implementazione
-- UNICA: la usano il Combat Log (nomi dei pull, kill/wipe) e il
-- riconoscimento del boss in corso per le macro in-fight.
function Utils:NpcIdFromGUID(guid)
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

-- Riporta un sotto-albero a una posizione di livello PREVEDIBILE rispetto a
-- un riferimento (es. il genitore o la finestra). Se il root si e' allontanato
-- oltre la tolleranza, sposta TUTTO il sotto-albero dello stesso delta: nessun
-- rinumero, quindi l'ordine interno (che in gioco funziona) resta identico.
-- Causa: in 3.3.5 i livelli dei figli non seguono il padre, e dopo ripetuti
-- raise/rebuild una catena puo' restare centinaia di livelli fuori posto
-- (fstack: RLSuiteWLScroll <700> sopra la finestra <200>) e mangiarsi i click.
-- Restituisce true se ha corretto il livello.
function Utils:RealignSubtreeLevel(root, wantLvl, tol)
    if not (root and root.GetFrameLevel and root.SetFrameLevel) then return false end
    if wantLvl == nil then return false end
    tol = tol or 20
    local cur = root:GetFrameLevel() or wantLvl
    local d = wantLvl - cur
    if d < 0 then d = -d end
    if d <= tol then return false end
    ShiftSubtree(root, wantLvl - cur, {})
    return true
end

function Utils:RaiseWindow(frame)
    if not frame then return end
    -- Layering NORMALIZZATO: niente contatore globale +50 a click (livelli
    -- a casaccio). Lo stack delle finestre RLSuite e' ordinato per recency
    -- e a ogni raise i livelli vengono ri-normalizzati a valori piccoli e
    -- stabili (slot da 40, abbastanza ampi per il sotto-albero).
    RLSuite._windowStack = RLSuite._windowStack or {}
    local stack = RLSuite._windowStack
    local found = nil
    for i = 1, #stack do
        if stack[i] == frame then found = i break end
    end
    if found then table.remove(stack, found) end
    stack[#stack + 1] = frame
    local seen = {}
    for idx = 1, #stack do
        local w = stack[idx]
        if type(w) == "table" and w.GetFrameLevel then
            local target = 20 + 40 * idx
            -- Rebase LIVE dal livello reale della finestra (non dal valore
            -- memorizzato): se i contenuti della finestra sono stati
            -- ricostruiti nel frattempo, niente deriva negativa/divergente.
            local prev = w._rlsLevelBase or (w.GetFrameLevel and w:GetFrameLevel()) or 0
            local delta = target - prev
            w._rlsLevelBase = target
            w:SetFrameStrata("HIGH")
            if delta ~= 0 then
                ShiftSubtree(w, delta, seen)
            end
        end
    end
end

-- Clic su una finestra = portala in primo piano. Vale per i click che
-- arrivano al frame (sfondo/titolo): i bottoni figli continuano a fare
-- il loro lavoro. Preserva un eventuale OnMouseDown gia' presente.
function Utils:MakeClickToFront(frame)
    if not frame or frame._rlsFront then return end
    frame._rlsFront = true
    frame:EnableMouse(true)
    local old = frame:GetScript("OnMouseDown")
    frame:SetScript("OnMouseDown", function(self2, button)
        Utils:RaiseWindow(frame)
        if old then old(self2, button) end
    end)
end

-- Impedisce che una finestra venga trascinata (o ridimensionata) fuori
-- dallo schermo: Blizzard riporta il frame dentro UIParent a ogni drag.
-- Vale anche per i pannelli ancorati (es. la costola InviteEngine).
function Utils:ClampWindow(frame)
    if not frame then return end
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end
end

-- Finestra UNIVERSALE come tutte le altre: MakeDraggable + stesso layer
-- finale + BORDO tematico (ricostruito da SkinFrame con _noOuterBorder
-- OFF). Tutte le finestre dell'addon sono cosi': il riush non esce mai
-- dallo schermo (SetClampedToScreen + guard) ed e' SARIAMO come le altre.
function Utils:MakeUniversalWindow(frame, key)
    self:MakeDraggable(frame, key)
    self:MakeClickToFront(frame)
    self:SkinFrameBordered(frame)
    return frame
end

function Utils:SkinFrameBordered(frame)
    if not frame then return end
    frame._noOuterBorder = nil
    self:SkinFrame(frame)
end

-- Rende un frame trascinabile e salva la posizione nel layout.
-- NOTA: non sovrascrive script gia' presenti: si aggancia solo se il
-- frame non ha gia' un comportamento di trascinamento registrato.
function Utils:MakeDraggable(frame, key)
    if not frame then return end
    if frame._rlsDraggable then return end
    frame._rlsDraggable = true
    frame:SetMovable(true)
    frame:EnableMouse(true)
    self:ClampWindow(frame)
    -- Guard anti-bug 3.3.5: SetClampedToScreen NON clamp nella scala <=/ >
    -- (i frame scalati possono uscire dallo schermo durante il drag).
    -- Mentre il drag e' attivo, ogni frame riporta la finestra nei bordi
    -- (clamp scale-aware: GetLeft/GetTop / EffectiveScale) — IDENTICO per
    -- OGNI finestra dell'addon, main bar compresa.
    local guard = CreateFrame("Frame")
    guard:Hide()
    guard:SetScript("OnUpdate", function()
        Utils:ClampWindowToScreen(frame)
    end)
    frame._rlsDragGuard = guard
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self2)
        Utils:RaiseWindow(frame)
        guard:Show()
        self2:StartMoving()
    end)
    local function dragStop(self2)
        guard:Hide()
        self2:StopMovingOrSizing()
        Utils:ClampWindowToScreen(self2)
        Utils:PersistFramePos(self2, key)
    end
    frame:SetScript("OnDragStop", dragStop)
    frame._rlsDragStop = dragStop
end

-- Grip di ridimensionamento in basso a destra. Salva width/height nel
-- layout e (se fornita) invoca la callback dopo il ridimensionamento.
-- I limiti minimi vengono ricalcolati a ogni drag da RLSuite.windowMins
-- (fallback: i valori minW/minH passati qui), cosi' la finestra non puo'
-- diventare piu' piccola del contenuto: SetMinResize blocca durante il
-- trascinamento e OnMouseUp ri-clampa a sicurezza.
function Utils:AddResizeGrip(frame, key, minW, minH, onResized)
    if not frame or frame._rlsGrip then return end
    minW = minW or 300
    minH = minH or 200
    frame._rlsGrip = true
    frame:SetResizable(true)
    local L = self:WindowLayout(key)

    local function currentMin()
        local fn = RLSuite.windowMins and RLSuite.windowMins[key]
        local mw, mh
        if fn then
            mw, mh = fn(frame)
        end
        if not mw or not (mw > 0) then mw = minW end
        if not mh or not (mh > 0) then mh = minH end
        return mw, mh
    end

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    grip:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    grip:EnableMouse(true)

    -- Resize CUSTOM (niente StartSizing): il ridimensionamento nativo
    -- calcola il delta dalle coordinate assolute del cursore e litiga con
    -- SetClampedToScreen: vicino ai bordi la finestra si gonfia a dimensioni
    -- enormi e il grip finisce fuori schermo. Qui il delta e' relativo alla
    -- posizione di partenza del mouse e la dimensione e' SEMPRE clampata
    -- dentro lo schermo (in coordinate della scala effettiva della finestra).
    local sizing = false
    local startW, startH, startCX, startCY, startMW, startMH
    local function finishResize()
        if not sizing then return end
        sizing = false
        local mw, mh = currentMin()
        local w = math.max(mw, frame:GetWidth() or mw)
        local h = math.max(mh, frame:GetHeight() or mh)
        frame:SetSize(w, h)
        L.width = w
        L.height = h
        if onResized then onResized(w, h) end
    end
    grip:SetScript("OnMouseDown", function(self2, button)
        if button ~= "LeftButton" then return end
        sizing = true
        startW = frame:GetWidth() or minW
        startH = frame:GetHeight() or minH
        startMW, startMH = currentMin()
        local scale = frame:GetEffectiveScale() or 1
        local cx, cy = GetCursorPosition()
        startCX = (cx or 0) / scale
        startCY = (cy or 0) / scale
    end)
    grip:SetScript("OnMouseUp", finishResize)
    grip:SetScript("OnUpdate", function()
        if not sizing then return end
        -- lo spostamento finisce anche se il rilascio avviene fuori grip
        if not IsMouseButtonDown("LeftButton") then
            finishResize()
            return
        end
        local scale = frame:GetEffectiveScale() or 1
        local cx, cy = GetCursorPosition()
        local w = startW + ((cx or 0) / scale - startCX)
        local h = startH - ((cy or 0) / scale - startCY)
        -- MAI oltre lo schermo (e oltre lo spazio restante a destra del
        -- bordo sinistro della finestra): niente piu' finestre enormi ne'
        -- grip trascinati fuori vista
        local sw = (GetScreenWidth() or 0) / scale
        local sh = (GetScreenHeight() or 0) / scale
        local left = (frame.GetLeft and frame:GetLeft()) or 0
        if sw > 0 then
            local wMax = sw - (left or 0)
            if wMax < sw then w = math.min(wMax, w) end
            w = math.min(sw, w)
        end
        if sh > 0 then h = math.min(sh, h) end
        frame:SetSize(math.max(startMW, w), math.max(startMH, h))
    end)
    return grip
end

-- Minimo attuale per una finestra, dalla tabella registrata in
-- RLSuite.windowMins (funzioni per-chiave che leggono il contenuto).
function Utils:WindowMin(key, frame)
    local fn = RLSuite.windowMins and RLSuite.windowMins[key]
    if not fn then return nil end
    local mw, mh = fn(frame)
    if mw and mw > 0 and mh and mh > 0 then
        return mw, mh
    end
    return nil
end

-- Allinea una finestra ridimensionabile ai suoi minimi: se la
-- dimensione attuale (o salvata) e' piu' piccola del contenuto,
-- la porta almeno al minimo. Ritorna mw, mh.
function Utils:EnforceWindowMin(frame, key)
    if not frame then return nil end
    local mw, mh = self:WindowMin(key, frame)
    if not mw then return nil end
    local w = math.max(mw, frame:GetWidth() or mw)
    local h = math.max(mh, frame:GetHeight() or mh)
    if w ~= frame:GetWidth() or h ~= frame:GetHeight() then
        frame:SetSize(w, h)
    end
    local L = self:WindowLayout(key)
    if L.width and L.width < mw then L.width = mw end
    if L.height and L.height < mh then L.height = mh end
    if frame.SetMinResize then
        frame:SetMinResize(mw, mh)
    end
    return mw, mh
end

-- Overlay "anchor" (bordo evidenziato) per le HUD quando si usa
-- toggle anchors in Config.
function Utils:SetAnchorVisual(frame, on)
    if not frame then return end
    if not frame.rlsAnchorBox then
        local box = CreateFrame("Frame", nil, frame)
        box:SetAllPoints(frame)
        box:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)
        box:EnableMouse(false)
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.25)
        box:SetBackdropBorderColor(1, 0.82, 0, 0.9)
        box:Hide()
        frame.rlsAnchorBox = box
    end
    if on then
        frame.rlsAnchorBox:Show()
    else
        frame.rlsAnchorBox:Hide()
    end
end

-- ============================================================
-- DBM / BigWigs: timer visibili (pull, MS changes, roll, ecc.)
-- ============================================================

-- Avvia una barra-timer in DBM se l'addon e' presente (fallback:
-- BigWigs). Non genera errori se nessuno dei due e' installato.
-- Ritorna true se il timer e' partito.
function Utils:StartDbmTimer(seconds, label, icon)
    if not seconds or seconds <= 0 then return false end
    label = label or "Timer"
    icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"

    if DBM then
        -- API pubblica "pizza timer" (DBM moderno e classico)
        local ok = pcall(DBM.CreatePizzaTimer, DBM, seconds, label, icon)
        if ok then return true end
        -- fallback: barre interne dei DBM piu' vecchi
        if DBM.Bars and DBM.Bars.CreateBar then
            ok = pcall(DBM.Bars.CreateBar, DBM.Bars, seconds, label, icon)
            if ok then return true end
        end
    end

    if BigWigs then
        if BigWigs.CreatePizzaTimer then
            local ok = pcall(BigWigs.CreatePizzaTimer, BigWigs, seconds, label, icon)
            if ok then return true end
        elseif BigWigs.CreateBar then
            local ok = pcall(BigWigs.CreateBar, BigWigs, seconds, label, icon)
            if ok then return true end
        end
    end

    if RLSuite.db and RLSuite.db.profile.debug then
        self:Debug(string.format(L['DBM/BigWigs not available: timer "%s" not started.'], label))
    end
    return false
end
