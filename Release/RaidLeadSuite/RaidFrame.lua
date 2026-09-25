-- ============================================================
-- RLSuite - RaidFrame Module
-- ============================================================
-- HUD "clean": NO background/backdrop/border/close button on the frame
-- itself. One horizontal StatusBar per player with the player name inside
-- the bar; the fill is the HP% and the bar color is the class color.
--   left   : flask / Well Fed icons (shown when the player is missing them)
--   right  : class key cooldowns (combat-log tracked)
--   far right : vertical ability-check bar (ability per buff/debuff covered
--              by the raid; greyed when present, flashing border when missing)
--   below  : pre-boss alert buff bar / in-fight alert debuff bar
--
-- The player bars are divided into the 6 raid groups (G1..G6, 5 players
-- each), in pre-boss phase empty slots are shown as drop targets and
-- players can be rearranged by drag & drop (like the InviteEngine raid
-- group panel).
-- ============================================================

RLSuite.raidFrame = {}
local RF = RLSuite.raidFrame

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

-- Diagnostica click icone (solo debug): ogni passaggio del click lascia una
-- riga in chat, cosi' un eventuale punto morto e' VISIBILE subito in game.
local function rfDbg(fmt, ...)
    if RLSuite.db and RLSuite.db.profile and RLSuite.db.profile.debug then
        local ok, txt = pcall(string.format, fmt, ...)
        RLSuite.utils:Print("RF " .. (ok and txt or tostring(fmt)))
    end
end

-- Poller di riserva per il CLICK NUDO SINISTRO sulla BARRA del player
-- (= target!). Le righe hanno RegisterForDrag("LeftButton") in pre-boss:
-- su client dove OnMouseUp-left viene digerito, il release viene rilevato
-- qui via IsMouseButtonDown. Cursore mosso > 6px = drag → cancello; 4s
-- tenuto giu' = cancello. La dedup di RF:TargetRow evita doppioni con
-- OnMouseUp. Si AUTODISARMA e viene riarmato a ogni down sinistro.
local function RowBodyPoller(s, elapsed)
    if not s._pendingRowClick then
        s:SetScript("OnUpdate", nil)
        return
    end
    if s._manualDrag then
        s._pendingRowClick = nil
        s:SetScript("OnUpdate", nil)
        return -- era un drag player: il poller NON targetta
    end
    if GetTime and (GetTime() - (s._rowPollT0 or 0)) > 4 then
        s._pendingRowClick = nil
        s:SetScript("OnUpdate", nil)
        return
    end
    if s._pressX and GetCursorPosition then
        local x, y = GetCursorPosition()
        if x then
            local dx, dy = x - s._pressX, (y or 0) - (s._pressY or 0)
            if dx > 6 or dx < -6 or dy > 6 or dy < -6 then
                s._pendingRowClick = nil
                s:SetScript("OnUpdate", nil)
                return
            end
        end
    end
    if not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
        s._pendingRowClick = nil
        s:SetScript("OnUpdate", nil)
        RF:RowPlainClick(s, "LeftButton")
    end
end

local RF_GROUPS = 6
local RF_PER_GROUP = 5
local RF_MAX_CDS = 4
-- Font dei timer dei cooldown nelle icone a destra della barra (era 8: si
-- leggeva male). Il nome del player resta a nameFontSize, configurabile.
local RF_CD_FONT = 10
-- DURABILITY: slot di equipaggiamento controllati (4 = camicia e 19 = tabard
-- non hanno durability). Per gli ALTRI player il client espone solo "oggetto
-- rotto" (GetInventoryItemBroken); la percentuale esatta si legge solo sul
-- proprio personaggio (GetInventoryItemDurability).
local RF_DUR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local RF_DUR_ALERT_PCT = 20      -- sotto questa % conta come "da riparare"
local RF_DUR_REFRESH = 4         -- ricalcolo ogni N passate da 0,5s (2s)
local RF_FAR_YARDS = 999         -- oltre le 40 yard UnitInRange non da' numeri
-- Tolleranza del gesto di trascinamento (px): prendere una barra a 5-6 px di
-- distanza deve FUNZIONARE. Con le righe da ~20 px un click "a filo" finiva
-- nel vuoto e il gesto non faceva niente: da fuori sembrava che quel player
-- non si potesse piu' spostare.
local RF_DRAG_SNAP = 10
local RF_HEADER_H = 14
local RF_GROUP_GAP = 8
local RF_TANK_COUNT = 2     -- Tanks group sopra G1: barra MT + barra OT
-- Geometria del pannello "Raid Buffs" (matrice categorie x giocatori):
local RF_BP_NAME_W = 84     -- colonna nome (class color)
local RF_BP_CELL_W = 24      -- passo colonne DEFAULT (iconSize + iconSpacing)
local RF_BP_HEADER_H = 16  -- non piu' usato: l'header 45° usa RF_MATRIX_HDR_H
local RF_MATRIX_HDR_H = 80 -- DEPRECATA (era la strip dei testi a 45°): ora l'altezza della testata-icone = cellW + 4
-- Ordine di IMPORTANZA delle colonne della matrice (i buff piu' importanti
-- a sinistra): benedizioni/stats e stamina prima, utility e % danno dopo.
local RF_BP_PRIORITY = {
    stats = 1, stamina = 2, wild = 3, intellect = 4, spirit = 5, shadow = 6,
    armor = 7, mp5 = 8, atkpower = 9, apIncrease = 10, hp = 11, strAgi = 12,
    spellPower = 13, spellHaste = 14, meleeHaste = 15, meleeCrit = 16,
    spellCrit = 17, focusMagic = 18, damage = 19, haste = 20,
    dmgReduction = 21, healReceived = 22, physReduction = 23, replen = 24,
    retAura = 25,
}
local RF_BP_BTN_W = 72

-- --- Check buff CONSAPEVOLE DELLA COMPOSIZIONE -----------------------
-- Colori dell'icona di intestazione di una categoria della matrice:
--   NORMAL   categoria disponibile (il check puo' essere soddisfatto)
--   NODATA   categoria NON disponibile con questa composizione (nessun
--            fornitore nel raid) -> icona grigio scuro, niente "accensione"
--   RED      overlay rosso sopra l'icona quando la categoria e' disponibile
--            ma il check NON e' soddisfatto (stile spell non utilizzabile)
local RF_HDR_NORMAL = 0.8
local RF_HDR_NODATA = 0.35
local RF_HDR_RED = { 0.85, 0.05, 0.05, 0.55 }
-- Focus Magic (3.3.5): il buff vive sul BERSAGLIO, quindi l'unico modo per
-- sapere QUALE mago non l'ha dato e' il combat log (SPELL_AURA_APPLIED ha
-- la fonte). Il conteggio delle aure resta la fonte di verita' del check.
local RF_FM_SPELL = 54646

-- Bordino DORATO di drop: indica lo slot in cui il player trascinato
-- atterrerebbe se rilasciassi ADESSO (blocco pieno = swap, vuoto = move).
-- Decorazione pura: bordo su frame figlio (MAI toccare il backdrop dello
-- slot, che in pre-boss e' gia' occupato dai placeholder dei vuoti).
local RF_DROP_GLOW_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

-- Ace3: eventi (roster/aura/combat-log) via AceEvent-3.0, il refresh
-- periodico a 0.5s via AceTimer-3.0 (al posto del vecchio frame OnUpdate).
LibStub("AceEvent-3.0"):Embed(RF)
LibStub("AceTimer-3.0"):Embed(RF)

function RF:Init()
    self.db = RLSuite.db.profile.raidframe
    self.rows = {}          -- populated slots, dense (for tests + UpdateAll)
    self.slots = {}         -- 30 slot frames (6 groups x 5 players)
    self.groupHeaders = {}  -- 6 group labels (G1..G6)
    self.cdTracker = {}
    self:CreateFrame()
    self:RegisterEvents()
    self:ApplyLayout()
    self:UpdatePhase()
    -- Version fingerprint (solo debug): cosi' verifichi SUBITO quale codice
    -- sta girando nel client, senza fraintendimenti di pull stale.
    rfDbg("RaidFrame %s click-module attivo (secure overlay + press-target)", tostring(RLSuite.version))
end

function RF:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        if self.db and self.db.enabled == false then
            RLSuite.utils:Print(L["Raid Frame is disabled in Config."])
            return
        end
        self.frame:Show()
        self:Update()
    end
end

-- Salvataggio posizione finestra dopo lo spostamento con Shift+destro.
function RF:PersistAnchor(fr, db)
    if not (fr and fr.GetPoint and db) then return end
    local point, _, relPoint, x, y = fr:GetPoint()
    if point then
        db.point = point
        db.relPoint = relPoint
        db.x = x
        db.y = y
    end
end

function RF:CreateFrame()
    local db = self.db or {}
    local f = CreateFrame("Frame", "RLSuiteRaidFrame", UIParent)
    f:SetSize(db.width or 380, 300)
    f:SetPoint(db.point or "LEFT", UIParent, db.relPoint or "LEFT", db.x or 10, db.y or 0)
    -- Strata MEDIUM (non LOW): l'HUD e' trasparente, ma in LOW le righe e le
    -- icone finivano SOTTO il chrome default della UI nell'hit-test e alcuni
    -- click venivano divorati da pannelli invisibili soprastanti.
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    RLSuite.utils:ClampWindow(f)
    -- Move della finestra: SOLO Shift+Tasto DESTRO, via StartMoving MANUALE.
    -- NESSUN RegisterForDrag qui: in 3.3.5 la registrazione-drag di un
    -- antenato fa digerire al drag manager i rilasci di quel tasto in TUTTO
    -- l'albero (per 4 release i click sinistri sulle icone risultavano morti
    -- proprio per questo). Shift separa i gesti: click nudi = messaggi,
    -- shift+gesti = drag.
    f:SetScript("OnMouseDown", function(self2, button)
        if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
            if (not db.locked) or (RLSuite.db.profile.anchorMode == true) then
                self2._rlsMoving = true
                self2:StartMoving()
            end
        end
    end)
    f:SetScript("OnMouseUp", function(self2, button)
        if button == "RightButton" and self2._rlsMoving then
            self2._rlsMoving = false
            self2:StopMovingOrSizing()
            RF:PersistAnchor(self2, db)
        end
    end)
    f:Hide()
    self.frame = f

    -- Groups + slots (G1..G6) live in this container.
    self.content = CreateFrame("Frame", nil, f)
    self.content:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    self:_InitDragPoller()

end

function RF:RegisterEvents()
    self:RegisterEvent("RAID_ROSTER_UPDATE", function() RF:Rebuild() end)
    self:RegisterEvent("UNIT_HEALTH", "OnUnitEvent")
    self:RegisterEvent("UNIT_MANA", "OnUnitEvent")
    self:RegisterEvent("UNIT_AURA", "OnUnitEvent")
    self:RegisterEvent("UNIT_TARGET", function() RF:UpdateTankTargets() end)
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")
    -- refresh periodico (prima un frame OnUpdate con accumulo a 0.5s)
    self:ScheduleRepeatingTimer("UpdateAll", 0.5)
end

function RF:OnUnitEvent(event, unit)
    self:UpdateUnit(unit)
end

function RF:OnCombatLog(event, ...)
    -- 3.3.5: timestamp, subEvent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, ...
    local _, subEvent, _, sourceName, _, _, destName, _, spellId = ...
    if subEvent == "SPELL_CAST_SUCCESS" then
        self:OnSpellCast(sourceName, spellId)
    elseif subEvent == "SPELL_AURA_APPLIED" and spellId == RF_FM_SPELL and sourceName then
        -- Focus Magic: l'aura vive sul BERSAGLIO, la FONTE e' il mago che
        -- l'ha lanciata. E' l'unico modo per dire NELL'ALERT quale mago non
        -- l'ha ancora dato (contare le aure non basta a fare i nomi).
        self.fmCasters = self.fmCasters or {}
        self.fmCasters[sourceName] = destName or true
    end
end

function RF:GetRoster()
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        -- The simulated roster (Core) is the single source of truth in debug
        -- mode: it starts with just the player and grows when fake players
        -- accept an invite. This is what the Raid Frame and the Raid Group
        -- panel both read, so an accepted invite updates everything.
        local list = {}
        for i, m in ipairs(RLSuite:DebugRoster()) do
            if m.isPlayer then
                table.insert(list, { unit = "player", name = m.name, class = m.class, fake = false })
            else
                table.insert(list, { unit = nil, name = m.name, class = m.class, fake = true })
            end
        end
        return list
    end
    local list = {}
    local num = GetNumRaidMembers() or 0
    for i = 1, num do
        local unit = "raid" .. i
        table.insert(list, {
            unit = unit,
            name = UnitName(unit) or "Unknown",
            class = select(2, UnitClass(unit)) or "WARRIOR",
            fake = false,
        })
    end
    return list
end

-- Raid roster divided into the 6 groups: groups[g][s] = member or nil.
-- Debug mode reads the sparse simulated slots (slot -> group/row); real
-- mode reads GetRaidRosterInfo's subgroup, ordered by raid index.
function RF:GetGroupedRoster()
    local groups = { {}, {}, {}, {}, {}, {} }
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        local slots = RLSuite:DebugRaidSlots()
        for i = 1, RF_GROUPS * RF_PER_GROUP do
            local m = slots[i]
            if m then
                local g = math.floor((i - 1) / RF_PER_GROUP) + 1
                local s = (i - 1) % RF_PER_GROUP + 1
                if g >= 1 and g <= RF_GROUPS then
                    groups[g][s] = {
                        name = m.name,
                        class = m.class or "WARRIOR",
                        unit = m.isPlayer and "player" or nil,
                        fake = not m.isPlayer,
                        slot = i,
                    }
                end
            end
        end
        return groups
    end

    local num = GetNumRaidMembers() or 0
    local groupCount = { 0, 0, 0, 0, 0, 0 }
    for i = 1, num do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name then
            local class = select(2, UnitClass("raid" .. i)) or "WARRIOR"
            subgroup = tonumber(subgroup) or 1
            if subgroup < 1 then subgroup = 1 end
            if subgroup > RF_GROUPS then subgroup = RF_GROUPS end
            groupCount[subgroup] = groupCount[subgroup] + 1
            local s = groupCount[subgroup]
            if s <= RF_PER_GROUP then
                groups[subgroup][s] = {
                    name = name,
                    class = class,
                    unit = "raid" .. i,
                    fake = false,
                    raidIndex = i,
                }
            end
        end
    end
    return groups
end

-- ------------------------------------------------------------------
-- Layout metrics
-- ------------------------------------------------------------------
function RF:LayoutMetrics()
    local db = self.db or {}
    local app = db.appearance or {}
    local iconSize = app.iconSize or 16
    local barHeight = iconSize -- barre: altezza AUTOMATICA = icon size (non piu' configurabile)
    local barWidth = app.barWidth or 180
    local nameFontSize = app.nameFontSize or 11
    -- Spacing configurabili (Config -> Raid Frame -> Layout)
    local iconSpacing = app.iconSpacing or 8            -- gap tra le icone della matrice
    local rowSpacing = app.rowSpacing or 0              -- gap tra le barre nei gruppi
    local groupSpacing = app.groupSpacing or 8          -- gap tra i gruppi
    local groupHeaderH = (app.groupHeaderFontSize or 10) + 4
    local cellW = math.max(12, iconSize + iconSpacing)  -- passo colonne matrice
    local abw = 0 -- buff bar / ability bar rimosse (redesign in corso)
    local gap = 0
    -- L'AREA DELLE COLONNE MATRICE NON E' COPERTA DALLA FINESTRA: la window
    -- finisce al bordo destro delle barre e TUTTA la grafica matrice (icone,
    -- strip, backdrop) viene disegnata OLTRE il bordo destro. Cosi' la zona
    -- buff e' COMPLETAMENTE CLICK-THROUGH, a matrice aperta o chiusa.
    -- Layout per row: [flask][food] ... [HP bar = barWidth] ... [up to 4 CDs]
    local leftArea = 4 + 2 * iconSize + 4
    local cdReserve = 4 * iconSize + 3 * 2 + 4
    local rowWidth = leftArea + barWidth + cdReserve + 4
    local W = rowWidth + abw + gap
    local rowHeight = math.max(barHeight, iconSize) + 4
    return {
        W = W, abw = abw, rowWidth = rowWidth,
        barWidth = barWidth, barHeight = barHeight,
        iconSize = iconSize, nameFontSize = nameFontSize,
        rowHeight = rowHeight,
        iconSpacing = iconSpacing, rowSpacing = rowSpacing,
        groupSpacing = groupSpacing, groupHeaderH = groupHeaderH,
        cellW = cellW,
    }
end

-- ------------------------------------------------------------------
-- Group headers + slot frames (created once, reused)
-- ------------------------------------------------------------------
function RF:EnsureSlots()
    self.groupHeaders = self.groupHeaders or {}
    self.slots = self.slots or {}
    for g = 1, RF_GROUPS do
        if not self.groupHeaders[g] then
            local lbl = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetText("G" .. g)
            lbl:SetTextColor(1, 0.82, 0)
            lbl:SetJustifyH("LEFT")
            self.groupHeaders[g] = lbl
        end
        for s = 1, RF_PER_GROUP do
            local i = (g - 1) * RF_PER_GROUP + s
            if not self.slots[i] then
                self.slots[i] = self:CreateSlotFrame(i, g)
            end
        end
    end
    self:EnsureTanks()
end

-- Gruppo "Tanks" (sopra G1): header dorato + 2 barre MT/OT. Le barre sono
-- slot normali SENZA icone consumabili (al loro posto il tag MT/OT) e non
-- fanno parte di self.slots: niente drag player su di esse.
function RF:EnsureTanks()
    if self.tankHeader then return end
    local hdr = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetText(L["Tanks"])
    hdr:SetTextColor(1, 0.82, 0)
    hdr:SetJustifyH("LEFT")
    hdr:Hide()
    self.tankHeader = hdr
    self.tankSlots = {}
    self.tankSlots[1] = self:CreateSlotFrame("MT", 0, "MT")
    self.tankSlots[2] = self:CreateSlotFrame("OT", 0, "OT")
    for _, t in ipairs(self.tankSlots) do
        t.slot = nil   -- fuori dalla geometria di drop dei gruppi
    end
    -- Bottone "Raid Buffs": A DESTRA DELLA BARRA OT (secondo slot tank).
    -- Apre/chiude la matrice E la riga d'intestazione delle icone.
    local btn = CreateFrame("Button", "RLSuiteRaidBuffsBtn", self.content)
    btn:SetSize(RF_BP_BTN_W, RF_HEADER_H)
    btn:EnableMouse(true)
    RLSuite.utils:SkinButton(btn)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER", btn, "CENTER", 0, 0)
    lbl:SetText(L["Raid Buffs"])
    lbl:SetTextColor(1, 0.82, 0)
    btn.label = lbl
    btn:SetScript("OnClick", function() RF:ToggleBuffMatrix() end)
    btn:Hide()
    self.buffPanelBtn = btn
end

-- HANDLER CONDIVISI fra la riga-Button e l'overlay SECURE (la zona
-- coperta dal secure overlay non consegna piu' input alla riga sotto: per
-- questo aggiungi un misero correlate handler anche li').
local function RowBodyOnMouseDown(self2, button)
        if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
            local f = RF.frame
            if f and (not RF.db.locked or RLSuite.db.profile.anchorMode == true) then
                f._rlsMoving = true
                f:StartMoving()
            end
            self2._pressBtn = nil
            return -- gesto con shift: mai trattato come click-icona
        end
        if IsShiftKeyDown and IsShiftKeyDown() then
            self2._pressBtn = nil
            -- SHIFT+sinistro = drag player MANUALE. Le barre Tanks (MT/OT)
            -- restano FUORI dal drag (come prima): si trascinano solo le barre
            -- giocatore dei gruppi.
            if button == "LeftButton" and RF:IsDragEnabled() and self2.member then
                -- Anche le barre Tanks arrivano qui: _StartDragFromSlot le
                -- risolve nella riga della griglia che mostra lo stesso membro.
                RF:_StartDragFromSlot(self2)
            end
            return -- gesti con shift: mai click/icone/target
        end
        self2._manualDrag = nil -- click nuovo: reset di un eventuale drag appeso
        self2._pressBtn = button
        self2._pressX, self2._pressY = nil, nil
        if GetCursorPosition then
            local x, y = GetCursorPosition()
            self2._pressX, self2._pressY = x, y
        end
        if button == "LeftButton" then
            -- TARGET ALLA PRESSIONE: il mouse-down e' l'evento che in client
            -- arriva SEMPRE (il bonk/click del widget lo dimostra), come fanno
            -- Grid/VuhDo/HealBot. Release/poller deduppano via row._targetT.
            RF:TargetRow(self2)
            -- Poller di riserva (stessa forma delle icone): senza drag
            -- registrati l'OnMouseUp ora arriva, ma se qualche client lo
            -- mangiasse comunque il release viene rilevato qui comunque.
            self2._rowPollT0 = (GetTime and GetTime()) or 0
            self2._pendingRowClick = true
            self2:SetScript("OnUpdate", RowBodyPoller)
        end
end

local function RowBodyOnMouseUp(self2, button)
        if button == "RightButton" then
            local f = RF.frame
            if f and f._rlsMoving then
                f._rlsMoving = false
                f:StopMovingOrSizing()
                RF:PersistAnchor(f, RF.db)
            end
        end
        -- Completamento drag player MANUALE: al release, slot sotto il
        -- cursore → move/swap. Serve anche se lo shift e' gia' rilasciato.
        if button == "LeftButton" and RF._rfDragSource then
            RF:_FinishDrag()
            return -- era un drag: NON un click-icona, NON un target
        end
        if IsShiftKeyDown and IsShiftKeyDown() then return end -- gesti con shift: NO messaggi
        local pressed = self2._pressBtn
        self2._pressBtn = nil
        if pressed ~= button then return end
        if button ~= "LeftButton" and button ~= "RightButton" then return end
        if RF._rfDragSource then return end -- era un drag, non un click
        if self2._pressX and GetCursorPosition then
            local x, y = GetCursorPosition()
            if x and (math.abs(x - self2._pressX) > 5 or math.abs((y or 0) - (self2._pressY or 0)) > 5) then
                return -- il cursore si e' mosso: era un drag
            end
        end
        self2._pressX, self2._pressY = nil, nil
        RF:RowPlainClick(self2, button)
end

function RF:CreateSlotFrame(slotIndex, group, tankTag)
    local row = CreateFrame("Button", "RLSuiteRaidRow" .. slotIndex, self.content)
    row.slot = slotIndex
    row.group = group
    row.member = nil
    if tankTag then row.isTank = true end
    -- slotIndex puo' essere "MT"/"OT" (barre Tanks): fakeHP comunque numerico.
    local hpSeed = tonumber(slotIndex) or (tankTag == "MT" and 61 or 62)
    row.fakeHP = 70 + ((hpSeed * 13) % 31)
    -- MAI disabilitare il mouse sullo slot (vedi UpdateDragState): in 3.3.5
    -- EnableMouse(false) sul genitore blocca la hit-region ANCHE dei figli,
    -- quindi le icone consumabili diventavano non cliccabili fuori pre-boss.
    row:EnableMouse(true)

    -- Left: flask / Well Fed missing-consumable icons.
    -- Le barre TANK non li hanno: al loro posto il tag MT/OT dorato.
    if row.isTank then
        -- Anche il tag MT/OT fuori dalla riga (stessa regola della barra).
        local tag = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        -- Posizionato in LayoutSlotGeometry: ATTACCATO a sinistra della barra.
        tag:SetText(tankTag)
        tag:SetTextColor(1, 0.82, 0)
        row.tankTag = tag
        row.tankTagText = tankTag -- per le tracce di debug ("barra MT/OT")
        -- Barra TARGET del tank: al posto dei CD del player, a destra della
        -- barra HP. Mostra nome + HP% del bersaglio attuale del tank.
        local tbar = CreateFrame("StatusBar", nil, row)
        tbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        tbar:SetMinMaxValues(0, 100)
        tbar:SetValue(0)
        local tbg = tbar:CreateTexture(nil, "BACKGROUND")
        tbg:SetAllPoints(tbar)
        tbg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        tbg:SetVertexColor(0, 0, 0, 0.45)
        tbar.bg = tbg
        local tfs = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tfs:SetPoint("LEFT", tbar, "LEFT", 3, 0)
        tfs:SetTextColor(1, 1, 1)
        tbar.nameText = tfs
        row.targetBar = tbar
    else
        row.flaskIcon = self:MakeConsumableIcon(row, "flask")
        row.foodIcon = self:MakeConsumableIcon(row, "food")
    end

    -- HP bar (name + % inside), fill = HP%, color = class color.
    -- FIGLIA DI CONTENT, NON DELLA RIGA (v1.11.76): come le icone consumabili.
    -- Se la riga non si mostra (in combat puo' succedere: riga invisibile =
    -- figli invisibili) la barra spariva mentre le icone restavano: la
    -- grafica del player NON deve dipendere dalla visibilita' della riga,
    -- perche' la riga serve solo come zona di click.
    local bar = CreateFrame("StatusBar", nil, self.content)
    bar:SetFrameLevel((self.content.GetFrameLevel and self.content:GetFrameLevel() or 1) + 20)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
    row.bar = bar

    -- Subtle track behind the fill (a status bar needs a readable track;
    -- this is a per-bar background, not a HUD backdrop).
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0, 0, 0, 0.45)
    bar.bg = bg

    local nameFS = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("LEFT", bar, "LEFT", 3, 0)
    nameFS:SetText("")
    nameFS:SetTextColor(1, 1, 1)
    bar.nameText = nameFS

    -- Niente percentuale HP: la barra mostra solo il nome del player.

    -- Class key cooldowns (up to 4, pooled; filled per class in ApplySlotCDs).
    -- Anche questi FUORI dalla riga: le texture stanno su un supporto figlio
    -- di content, sopra le righe (content+21), cosi' restano visibili anche
    -- quando la riga non si mostra (stesso motivo della barra HP).
    row.cdIcons = {}
    local cdHolder = CreateFrame("Frame", nil, self.content)
    cdHolder:SetFrameLevel((self.content.GetFrameLevel and self.content:GetFrameLevel() or 1) + 21)
    cdHolder:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    cdHolder:SetSize(1, 1)
    cdHolder:EnableMouse(false)
    row.cdHolder = cdHolder
    for j = 1, RF_MAX_CDS do
        local cd = cdHolder:CreateTexture(nil, "OVERLAY")
        cd:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cd:Hide() -- le barre tank non li usano mai (restano spenti)
        local timer = cdHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timer:SetPoint("CENTER", cd, "CENTER", 0, 0)
        timer:SetFont("Fonts\\FRIZQT__.TTF", RF_CD_FONT, "OUTLINE")
        timer:SetText("")
        cd.timer = timer
        row.cdIcons[j] = cd
    end
    row._cdClass = nil

    -- Drag player SHIFT+SINISTRO = gestito INTERAMENTE A MANO
    -- (OnMouseDown/Up + watchdog su frame dedicato), come il move HUD.
    -- MAI piu' RegisterForDrag sulle righe: in 3.3.5 la registrazione-drag
    -- fa digerire al drag manager GLI SCRIPT di pressione/rilascio di quel
    -- tasto (i widget Button suonano comunque il click: per questo si
    -- sentiva "il rumore" ma non partiva mai nulla, nemmeno con unit
    -- valida). Senza registrazione, i click nudi sulle barre arrivano
    -- sempre agli script.

    -- Fallback SICURO per il click sulle icone + proxy dei gesti con SHIFT:
    --   * Shift+destro sulla riga: le righe coprono il piano della finestra,
    --     il "sposta HUD" parte da qui.
    --   * Click nudo (nessuno shift): se il cursore e' su un'icona, hit-test
    --     e messaggio; sulla BARRA = target del player.
    row:SetScript("OnMouseDown", RowBodyOnMouseDown)
    row:SetScript("OnMouseUp", RowBodyOnMouseUp)

    -- LAYERS SICURO ANTIFALLIMENTO: il "clicco il nome → target" lo fa
    -- l'ENGINE stessa, come Grid/VuhDo/Clique: SecureActionButtonTemplate
    -- type1="target" + unit=..., ALLA PRESSIONE (LeftButtonDown). Zero
    -- scripting Lua per il target → nulla può mangiare l'evento: è la via
    -- standard e immutabile degli unit frame. Livello: sopra la riga (+5),
    -- SOTTO le icone consumabili (content+30) → le icone mantengono le loro
    -- zone. Gli handler Lua condivisi coprono TUTTO il resto (Shift+destro
    -- sposta HUD, Shift+sinistro drag player, hit-test icone, tracce di debug).
    local sec = CreateFrame("Button", nil, self.content, "SecureActionButtonTemplate")
    sec:SetAllPoints(row)
    sec:SetFrameLevel((self.content.GetFrameLevel and self.content:GetFrameLevel() or 1) + 5)
    sec:RegisterForClicks("LeftButtonDown")
    sec:SetAttribute("type1", "target")
    sec:Hide() -- mostrato quando la riga ha un'unit reale (vedi FillSlot)
    row.secTarget = sec
    sec:SetScript("OnMouseDown", function(s, button) RowBodyOnMouseDown(row, button) end)
    sec:SetScript("OnMouseUp", function(s, button) RowBodyOnMouseUp(row, button) end)

    -- Indicatore di DROP puro-visuale: bordino dorato su frame figlio.
    -- EnableMouse(false) qui e' SICURO (decorazione, NON lo slot): non
    -- ruba click, non tocca la hit-region della riga — mostra solo dove
    -- atterra il player durante il drag manuale.
    local glow = CreateFrame("Frame", nil, row)
    glow:SetAllPoints(row)
    glow:SetFrameLevel((row.GetFrameLevel and row:GetFrameLevel() or 1) + 2)
    glow:EnableMouse(false)
    glow:SetBackdrop(RF_DROP_GLOW_BACKDROP)
    glow:SetBackdropColor(0, 0, 0, 0)
    glow:SetBackdropBorderColor(1, 0.82, 0, 1) -- dorato
    glow:Hide()
    row.dropGlow = glow

    -- PIANO DI RILASCIO (v1.11.75): frame SEMPLICE (nessun template, nessun
    -- attributo, mai protetto -> in combat il client non puo' bloccarne
    -- ne' Show/EnableMouse ne' i click). E' quello che si VEDE e che riceve
    -- il mouse durante un drag player:
    --   bordo tenue + riempimento scuro = slot vuoto, bersaglio possibile
    --   bordo tenue senza riempimento = riga occupata (li' si fa lo swap)
    --   bordo DORATO = bersaglio sotto il cursore (dove atterra il player)
    -- Fuori dal drag e' nascosto e col mouse spento: i click passano alle
    -- righe/icone come sempre.
    -- Perche' non basta la riga: in combat la riga (e i suoi figli, glow
    -- compreso) poteva restare invisibile -> niente bordo, niente hit-test,
    -- drop a vuoto. Le barre dei tank non sono drop target: nessun piano.
    if not row.isTank then
        local plane = CreateFrame("Frame", nil, self.content)
        plane:SetAllPoints(row)
        plane:SetFrameLevel((self.content.GetFrameLevel and self.content:GetFrameLevel() or 1) + 40)
        plane:SetBackdrop(RF_DROP_GLOW_BACKDROP)
        plane:SetBackdropColor(0, 0, 0, 0)
        plane:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.55)
        plane:EnableMouse(false)
        plane:Hide()
        plane.slot = row
        plane:SetScript("OnMouseDown", function(_, button) RowBodyOnMouseDown(row, button) end)
        plane:SetScript("OnMouseUp", function(_, button) RowBodyOnMouseUp(row, button) end)
        row.dropPlane = plane
    end

    row:Hide()
    return row
end

function RF:MakeConsumableIcon(row, atype)
    -- Figlie di CONTENT (sorelle delle righe), NON delle righe-Button:
    -- dentro un Button con drag attivo il mouse-down viene intercettato
    -- dal drag del genitore e il click del figlio non si chiude mai (in
    -- gioco gli alert non partivano proprio per questo). L'ancora resta
    -- alla riga in LayoutSlotGeometry, quindi posizione e show/hide non
    -- cambiano.
    local btn = CreateFrame("Button", nil, self.content)
    btn.consType = atype
    btn:EnableMouse(true)
    btn:SetFrameLevel((self.content.GetFrameLevel and self.content:GetFrameLevel() or 1) + 30)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexture(self:GetAlertIcon(atype))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon
    -- CANALE DI RISERVA per il click sinistro (sudo storico: con la finestra
    -- draggabile, l'antenato con RegisterForDrag("LeftButton") divorava il
    -- release nell'albero - oggi il drag del frame e' manuale Shift+destro e
    -- quella causa e' sparita, ma il pollo resta come rete di sicurezza).
    -- Funziona cosi': OnUpdate poll di IsMouseButtonDown - quando il tasto
    -- risulta rilasciato e il cursore non si e' mosso (> 6px = drag →
    -- cancello; >= 4s tenuto fermo = non click → cancello) e' un CLICK
    -- sinistro → whisper. La TTL in OnAlertClick evita doppioni se arriva
    -- anche OnMouseUp. NB: il poller si AUTODISARMA (SetScript nil) dopo
    -- uso; ogni mouse-down sinistro (senza shift) lo RIARMA esplicitamente.
    local function Poller(s, elapsed)
        if not s._pendingLeft then
            s:SetScript("OnUpdate", nil)
            return
        end
        -- Tenuto giu' troppo a lungo immobile: non lo tratto come click.
        if GetTime and (GetTime() - (s._t0 or 0)) > 4 then
            s._pendingLeft = nil
            s:SetScript("OnUpdate", nil)
            return
        end
        -- Cursore mosso oltre soglia => e' un drag: cancello il click.
        if s._px and GetCursorPosition then
            local x, y = GetCursorPosition()
            if x then
                local dx, dy = x - s._px, (y or 0) - (s._py or 0)
                if dx > 6 or dx < -6 or dy > 6 or dy < -6 then
                    s._pendingLeft = nil
                    s:SetScript("OnUpdate", nil)
                    return
                end
            end
        end
        -- Rilascio rilevato dal poll: e' un CLICK sinistro.
        if not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
            s._pendingLeft = nil
            rfDbg("poll fire: %s", tostring(atype))
            s:SetScript("OnUpdate", nil)
            if self:OnAlertClick(row, atype, "LeftButton") then
                return
            end
        end
    end
    -- CLICK NUDI (nessuno Shift) sulle icone = messaggi missing buff.
    -- Shift+click = gesti di drag (player/HUD): qui NON deve partire nulla.
    -- Il rilascio ora arriva col normale OnMouseUp (nessun antenato ha piu'
    -- RegisterForDrag, lo shift separa i gesti); il POLLLING di riserva
    -- (IsMouseButtonDown) resta armato solo senza shift: se qualche client
    -- mangiasse comunque l'OnMouseUp-sinistro, il pollo salva il click e
    -- la TTL di OnAlertClick ammazza l'eventuale doppione.
    btn:SetScript("OnMouseDown", function(s, button)
        s._pressed = button
        s._shiftedAtDown = (IsShiftKeyDown and IsShiftKeyDown()) and true or nil
        -- Diagnostica in-game (solo debug): prova che l'input arriva.
        if RLSuite.db and RLSuite.db.profile and RLSuite.db.profile.debug then
            RLSuite.utils:Print("RF icon down: " .. tostring(button) .. " " .. tostring(atype))
        end
        if button == "LeftButton" and not s._shiftedAtDown then
            if GetCursorPosition then
                s._px, s._py = GetCursorPosition()
            else
                s._px, s._py = nil, nil
            end
            s._t0 = (GetTime and GetTime()) or 0
            s._pendingLeft = true
            s:SetScript("OnUpdate", Poller) -- riserva: si disarma da solo
        end
    end)
    btn:SetScript("OnMouseUp", function(s, button)
        rfDbg("icon up: %s %s", tostring(button), tostring(atype))
        local pressed, shifted = s._pressed, s._shiftedAtDown
        s._pressed, s._shiftedAtDown = nil, nil
        if shifted then return end -- gesto con shift: mai un messaggio
        if pressed == button and (button == "LeftButton" or button == "RightButton") then
            self:OnAlertClick(row, atype, button)
        end
    end)
    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        if atype == "flask" then
            GameTooltip:SetText(L["Missing flask"])
        else
            GameTooltip:SetText(L["Missing food buff"])
        end
        GameTooltip:AddLine(L["Left click: whisper"], 1, 1, 1)
        GameTooltip:AddLine(L["Right click: raid warning (everyone missing)"], 1, 1, 1)
        GameTooltip:AddLine(L["Shift + left drag on a row: move player"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Shift + right drag: move window"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:Hide()
    return btn
end

-- Positions + resizes every widget of a slot from the layout metrics.
-- Called from ApplyLayout so Config changes (bar width/height, icon size,
-- name font size) apply immediately without a full roster rebuild.
function RF:LayoutSlotGeometry(slot, m)
    slot:SetSize(m.rowWidth, m.rowHeight)
    local iconSize = m.iconSize
    if slot.flaskIcon then
        slot.flaskIcon:ClearAllPoints()
        slot.flaskIcon:SetSize(iconSize, iconSize)
        slot.flaskIcon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, 0)
    end
    if slot.foodIcon then
        slot.foodIcon:ClearAllPoints()
        slot.foodIcon:SetSize(iconSize, iconSize)
        slot.foodIcon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2 + iconSize + 2, 0)
    end
    if slot.bar then
        local leftX = 4 + 2 * iconSize + 4
        slot.bar:ClearAllPoints()
        slot.bar:SetSize(m.barWidth, m.barHeight)
        slot.bar:SetPoint("TOPLEFT", slot, "TOPLEFT", leftX, 0)
        -- Tag MT/OT: ATTACCATO al bordo sinistro della barra (non fluttuante
        -- nello spazio consumabili).
        if slot.tankTag then
            slot.tankTag:ClearAllPoints()
            slot.tankTag:SetPoint("RIGHT", slot.bar, "LEFT", -3, 0)
        end
        -- Barra TARGET dove prima c'erano i CD (solo tank).
        if slot.targetBar then
            slot.targetBar:ClearAllPoints()
            slot.targetBar:SetSize(m.rowWidth - leftX - m.barWidth - 4, m.barHeight)
            slot.targetBar:SetPoint("TOPLEFT", slot.bar, "TOPRIGHT", 4, 0)
            local tex = self.db and self.db.appearance and self.db.appearance.barTexture
                or "Interface\\TargetingFrame\\UI-StatusBar"
            slot.targetBar:SetStatusBarTexture(tex)
            if slot.targetBar.bg then slot.targetBar.bg:SetTexture(tex) end
            local fontFile = (self.db and self.db.appearance and self.db.appearance.font) or RLSuite.utils:GetUIFont()
            local tflags = (self.db and self.db.appearance and self.db.appearance.fontOutline == false) and "" or "OUTLINE"
            if slot.targetBar.nameText then
                slot.targetBar.nameText:SetFont(fontFile, m.nameFontSize, tflags)
            end
        end
        -- Texture della barra (fill + track), configurabile.
        local app = self.db and self.db.appearance or {}
        local tex = app.barTexture or "Interface\\TargetingFrame\\UI-StatusBar"
        slot.bar:SetStatusBarTexture(tex)
        if slot.bar.bg then slot.bar.bg:SetTexture(tex) end
        -- Font del nome: tipo, dimensione e outline configurabili.
        local fontFile = app.font or RLSuite.utils:GetUIFont()
        local flags = (app.fontOutline == false) and "" or "OUTLINE"
        if slot.bar.nameText then
            slot.bar.nameText:SetFont(fontFile, m.nameFontSize, flags)
        end
        for j, cd in ipairs(slot.cdIcons or {}) do
            if cd and cd.timer then
                cd.timer:SetFont(fontFile, RF_CD_FONT, flags)
            end
        end
    end
    for j, cd in ipairs(slot.cdIcons or {}) do
        if slot.isTank then
            -- Barre tank: MAI i CD del player a destra; al loro posto la
            -- barra target del tank (slot.targetBar).
            cd:Hide()
        else
            cd:ClearAllPoints()
            cd:SetSize(iconSize, iconSize)
            cd:SetPoint("LEFT", slot.bar, "RIGHT", 4 + (j - 1) * (iconSize + 2), 0)
        end
    end
end

function RF:ApplySlotCDs(slot, class)
    if slot.isTank then
        for _, cd in ipairs(slot.cdIcons or {}) do cd:Hide() end
        return
    end
    slot._cdClass = class
    local abilities = RLSuite.keyAbilities[class] or {}
    for j = 1, RF_MAX_CDS do
        local cd = slot.cdIcons and slot.cdIcons[j]
        if cd then
            local ability = abilities[j]
            if ability then
                local meta = RLSuite.abilityByName and RLSuite.abilityByName[ability]
                cd:SetTexture((meta and meta.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
                cd.ability = ability
                cd:Show()
            else
                cd.ability = nil
                cd:Hide()
            end
        end
    end
end

function RF:FillSlot(slot, member)
    slot.member = member
    slot.unit = member.unit
    slot.name = member.name
    slot.class = member.class
    slot.fake = member.fake
    slot.raidIndex = member.raidIndex
    slot:SetBackdrop(nil)
    slot:Show()

    -- Overlay sicuro per il target: gli attributi secure si toccano SOLO
    -- fuori combattimento. Se c'e' una unit reale → l'engine targetta alla
    -- pressione; in debug/fake (unit nil) → nascosto: via Lua con le guardie.
    if slot.secTarget then
        if not (InCombatLockdown and InCombatLockdown()) then
            if member.unit and not member.fake then
                slot.secTarget:SetAttribute("unit", member.unit)
                slot.secTarget:Show()
            else
                slot.secTarget:Hide()
            end
        end
    end

    if slot.bar then
        local r, g, b = RLSuite.utils:GetClassColor(member.class)
        slot.bar:SetStatusBarColor(r, g, b)
        slot.bar:SetMinMaxValues(0, 100)
        slot.bar:SetValue(100)
        if slot.bar.nameText then slot.bar.nameText:SetText(member.name) end
        slot.bar:Show()
    end

    -- I CD si rimettono SEMPRE (non solo al cambio di classe): ClearSlot li
    -- spegne, quindi svuotare e riempire lo stesso slot lasciava i CD spenti.
    self:ApplySlotCDs(slot, member.class)

    self:UpdateRow(slot)
end

function RF:ClearSlot(slot)
    slot.member = nil
    slot.unit = nil
    slot.name = nil
    slot.class = nil
    slot.fake = false
    slot.raidIndex = nil
    if slot.secTarget and not (InCombatLockdown and InCombatLockdown()) then
        slot.secTarget:Hide()
    end

    if slot.bar then
        slot.bar:SetValue(0)
        if slot.bar.nameText then slot.bar.nameText:SetText("") end
        slot.bar:Hide() -- fuori dalla riga: non sparisce da sola
    end
    self:SetConsumable(slot.flaskIcon, "off")
    self:SetConsumable(slot.foodIcon, "off")
    for _, cd in ipairs(slot.cdIcons or {}) do
        cd:Hide()
    end

    -- Slot vuoto = invisibile (in QUALSIASI fase). Riemerge come drop
    -- target SOLO mentre un player e' in trascinamento (RefreshDropTargets,
    -- chiamata da OnDragStart/OnDragStop/OnReceiveDrag).
    slot:SetBackdrop(nil)
    slot:Hide()
end

-- Bordino dorato sullo slot di destinazione del drag: la fonte di verità
-- e' il CURSORE (SlotAtCursor), non gli hover dei frame (inaffidabili
-- durante il drag manuale, dove il bottone resta premuto e i frame non
-- risollevano Enter/Leave). Fuori drag → tutto nascosto.
-- Aspetto del piano di rilascio: "empty" (vuoto), "occupied" (riga piena:
-- li' il rilascio scambia), "gold" (bersaglio sotto il cursore).
function RF:StyleDropPlane(slot, state)
    local p = slot and slot.dropPlane
    if not p then return end
    p._state = state
    if state == "gold" then
        p:SetBackdropColor(0, 0, 0, 0.18)
        p:SetBackdropBorderColor(1, 0.82, 0, 1)
    elseif state == "empty" then
        p:SetBackdropColor(0.05, 0.05, 0.05, 0.30)
        p:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.55)
    else
        p:SetBackdropColor(0, 0, 0, 0)
        p:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.35)
    end
    p:Show()
    if p.EnableMouse then p:EnableMouse(true) end
end

function RF:HideDropPlane(slot)
    local p = slot and slot.dropPlane
    if not p then return end
    p._state = nil
    if p.EnableMouse then p:EnableMouse(false) end
    p:Hide()
end

function RF:UpdateDropGlow()
    local target = nil
    local src = self._rfDragSource
    if src and self:IsDragEnabled() then
        target = self:SlotAtCursor()
        if target == src then target = nil end
    end
    for _, slot in ipairs(self.slots or {}) do
        if slot.dropGlow then
            if slot == target then
                slot.dropGlow:Show()
            else
                slot.dropGlow:Hide()
            end
        end
        -- Il piano dice anche DOVE si atterra, e lo dice con un frame che in
        -- combat nessuno puo' bloccare.
        if slot.dropPlane and slot.dropPlane:IsShown() then
            if slot == target then
                self:StyleDropPlane(slot, "gold")
            elseif slot.member then
                self:StyleDropPlane(slot, "occupied")
            else
                self:StyleDropPlane(slot, "empty")
            end
        end
    end
    return target
end

-- Mostra/nasconde i blocchi vuoti dei gruppi e gli header dei gruppi
-- vuoti: visibili SOLO mentre un drag e' attivo, in qualunque fase (servono
-- come drop target); altrimenti l'HUD resta denso (solo player + header
-- pieni).
function RF:RefreshDropTargets()
    local dragging = self:IsDragEnabled() and self._rfDragSource ~= nil
    -- Flag di "drag in corso" che SOPRAVVIVE alla pulizia di _rfDragSource:
    -- nel drop l'hit-test di SlotAtCursor viene fatto DOPO che la sorgente e'
    -- stata azzerata, quindi non puo' dipendere da lei (era il motivo per cui
    -- in combat il rilascio su uno slot vuoto non faceva nulla: riga nascosta
    -- + sorgente gia' nulla = nessun bersaglio trovato).
    self._dropActive = dragging and true or nil
    for g = 1, RF_GROUPS do
        local anyMember = false
        for s = 1, RF_PER_GROUP do
            local slot = self.slots and self.slots[(g - 1) * RF_PER_GROUP + s]
            if slot then
                if slot.member then
                    anyMember = true
                elseif dragging then
                    -- NIENTE bordo "dialog" sulla RIGA: la rendono visibile e
                    -- cliccabile i PIANI (v1.11.75), che in combat non possono
                    -- essere bloccati; la riga resta col suo spazio riservato.
                    slot:SetBackdrop(nil)
                    slot:Show()
                else
                    slot:SetBackdrop(nil)
                    slot:Hide()
                end
                -- Piano di rilascio: attivo durante il drag sugli ALTRI slot
                -- (mai sulla sorgente: li' non si puo' rilasciare).
                if dragging and slot ~= self._rfDragSource then
                    self:StyleDropPlane(slot, slot.member and "occupied" or "empty")
                else
                    self:HideDropPlane(slot)
                end
            end
        end
        local hdr = self.groupHeaders and self.groupHeaders[g]
        if hdr then
            if anyMember or dragging then
                hdr:Show()
            else
                hdr:Hide()
            end
        end
    end
    self:ApplyLayout()
    -- Bordino dorato: segue il cursore durante il drag, sparisce tutto fuori.
    self:UpdateDropGlow()
end

-- Riempie le barre Tanks dalle assegnazioni Blizzard del raid
-- (GetPartyAssignment: MT = primo Main Tank, OT = primo Main Assist).
-- Chiave = unit o nome (i fake del debug hanno solo nome). Il gruppo e'
-- visibile solo quando c'e' almeno una riga di gruppo renderizzata.
function RF:RebuildTanks()
    if not self.tankHeader then return end
    local active = self.rows and self.rows[1] ~= nil
    local mtInfo, otInfo
    if active and RLSuite.DebugMode and RLSuite:DebugMode() then
        -- DEBUG: MT/OT devono funzionare anche coi player FITTIZI (le
        -- assegnazioni Blizzard non esistono per i fake). Store RLSuite.debugTanks:
        --   nil   => mai toccato: auto-fill (MT = primo del roster, OT = primo diverso)
        --   nome  => assegnato manualmente (tasti MT/OT) o auto-fill mantenuto
        --   false => svuotato intenzionalmente dall'utente (NESSUN auto-refill)
        local roster = self:GetRoster()
        local exists = {}
        for _, info in ipairs(roster) do
            exists[info.name or "?"] = info
        end
        local dt = RLSuite.debugTanks
        if not dt then
            dt = {}
            RLSuite.debugTanks = dt
        end
        for _, k in ipairs({ "mt", "ot" }) do
            -- un assegnato sparito dal roster torna ad auto-fill (nil)
            if type(dt[k]) == "string" and not exists[dt[k]] then dt[k] = nil end
        end
        if dt.mt == nil and roster[1] then dt.mt = roster[1].name end
        if dt.ot == nil then
            for _, info in ipairs(roster) do
                if info.name ~= dt.mt then
                    dt.ot = info.name
                    break
                end
            end
        end
        mtInfo = (type(dt.mt) == "string") and exists[dt.mt] or nil
        otInfo = (type(dt.ot) == "string") and exists[dt.ot] or nil
    elseif active and GetPartyAssignment then
        for _, info in ipairs(self:GetRoster()) do
            local key = info.unit or info.name
            if key then
                if not mtInfo and GetPartyAssignment("MAINTANK", key) then mtInfo = info end
                if not otInfo and GetPartyAssignment("MAINASSIST", key) then otInfo = info end
            end
        end
    end
    self:_SetupTankSlot(self.tankSlots[1], mtInfo, active)
    self:_SetupTankSlot(self.tankSlots[2], otInfo, active)
    if active then
        self.tankHeader:Show()
        if self.buffPanelBtn then self.buffPanelBtn:Show() end
    else
        self.tankHeader:Hide()
        if self.buffPanelBtn then self.buffPanelBtn:Hide() end
        -- la matrice buff si spegne da sola: righe assenti => nessuna cella/header
        self:RefreshBuffMatrix()
    end
end

-- Barra Tanks: riempita se c'e' un assegnato, altrimenti placeholder
-- visibile (il gruppo Tanks mostra SEMPRE le 2 barre MT/OT).
function RF:_SetupTankSlot(slot, member, active)
    if not slot then return end
    if not active then
        self:ClearSlot(slot)
        slot._tankFilled = false
        return
    end
    if member then
        self:FillSlot(slot, member)
        slot._tankFilled = true
    else
        -- Slot tank senza assegnazione: nessun bordo "dialog", NIENTE
        -- placeholder: invisibile come gli slot vuoti dei gruppi (non e'
        -- un drop target: MT/OT arrivano da GetPartyAssignment del raid).
        self:ClearSlot(slot)
        slot._tankFilled = false
    end
end

-- ------------------------------------------------------------------
-- Rebuild
-- ------------------------------------------------------------------
function RF:Rebuild()
    self:EnsureSlots()
    local m = self:LayoutMetrics()
    local groups = self:GetGroupedRoster()

    -- Ogni riga e' protetta SINGOLARMENTE: un errore su una riga non deve
    -- piu' congelare tutto l'HUD (senza questo, una fill andata male in
    -- combat lasciava le righe vecchie in giro e ogni spostamento successivo
    -- sembrava non fare nulla).
    self.rows = {}
    local failed = 0
    for g = 1, RF_GROUPS do
        for s = 1, RF_PER_GROUP do
            local slot = self.slots[(g - 1) * RF_PER_GROUP + s]
            local member = groups[g][s]
            local ok, err
            if member then
                ok, err = pcall(self.FillSlot, self, slot, member)
                if ok then self.rows[#self.rows + 1] = slot end
            else
                ok, err = pcall(self.ClearSlot, self, slot)
            end
            if not ok then
                failed = failed + 1
                rfDbg("rebuild: slot %s non aggiornato (%s)", tostring(slot and slot.slot), tostring(err))
            end
        end
    end
    if failed > 0 then
        -- Riprova da sola al prossimo giro (0.5s): se il blocco era di combat,
        -- al termine del combat l'HUD si rimette in pari senza /reload.
        self._rebuildDirty = true
    end

    local okT, errT = pcall(self.RebuildTanks, self)
    if not okT then rfDbg("rebuild: barre Tanks non aggiornate (%s)", tostring(errT)) end
    self:UpdateDragState()
    -- Header e blocchi vuoti: gestiti insieme (blocchi solo durante il drag).
    self:RefreshDropTargets()
end

-- ------------------------------------------------------------------
-- Per-row updates
-- ------------------------------------------------------------------
function RF:UpdateUnit(unit)
    for _, row in ipairs(self.rows) do
        if row.unit == unit then
            self:UpdateRow(row)
            return
        end
    end
    for _, t in ipairs(self.tankSlots or {}) do
        if t.unit == unit then
            self:UpdateRow(t)
            return
        end
    end
end

function RF:UpdateAll()
    if self._rebuildDirty then
        self._rebuildDirty = false
        self:Rebuild()
    end
    for _, row in ipairs(self.rows) do
        self:UpdateRow(row)
    end
    for _, t in ipairs(self.tankSlots or {}) do
        self:UpdateRow(t)
    end
    self:UpdateTankTargets()
    -- Fade per distanza: solo le barre dei giocatori nei gruppi (le barre
    -- MT/OT restano come sono, sempre piene).
    for _, row in ipairs(self.rows) do
        self:ApplyDistanceFade(row)
    end
    self:RefreshBuffMatrix()
end

-- Barre TARGET dei tank: nome + HP% del bersaglio attuale di MT e OT.
-- Solo unit reali (mai lookup su player fittizi di debug, regola v1.5.3).
function RF:UpdateTankTargets()
    for ti = 1, RF_TANK_COUNT do
        local slot = self.tankSlots and self.tankSlots[ti]
        local tb = slot and slot.targetBar
        if tb then
            local name, pct, r, g, b = "", 0, 0.75, 0.15, 0.15 -- ostile di default
            if slot.unit and not slot.fake and UnitExists and UnitExists(slot.unit) then
                local tu = slot.unit .. "target"
                if UnitExists(tu) then
                    name = UnitName(tu) or ""
                    local maxhp = UnitHealthMax and UnitHealthMax(tu) or 0
                    pct = maxhp > 0 and (UnitHealth(tu) / maxhp * 100) or 0
                    if UnitIsPlayer and UnitIsPlayer(tu) and UnitClass then
                        local _, cls = UnitClass(tu)
                        local cc = RAID_CLASS_COLORS and cls and RAID_CLASS_COLORS[cls]
                        if cc then r, g, b = cc.r, cc.g, cc.b end
                    elseif UnitIsFriend and UnitIsFriend("player", tu) then
                        r, g, b = 0.2, 0.6, 0.2
                    end
                end
            end
            tb:SetMinMaxValues(0, 100)
            tb:SetValue(pct)
            if tb.SetStatusBarColor then tb:SetStatusBarColor(r, g, b) end
            if tb.nameText then tb.nameText:SetText(name) end
        end
    end
end

function RF:UpdateRow(row)
    if not row or not row.bar then return end
    local bar = row.bar
    if row.fake then
        local pct = row.fakeHP or 100
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(pct)
        self:UpdateConsumables(row)
        return
    end
    local unit = row.unit
    if not unit or not UnitExists(unit) then
        return
    end

    local hp = UnitHealth(unit) or 0
    local hpMax = UnitHealthMax(unit) or 1
    local pct = math.floor((hp / hpMax) * 100)
    bar:SetMinMaxValues(0, hpMax)
    bar:SetValue(hp)

    self:UpdateConsumables(row)

    for _, cd in ipairs(row.cdIcons) do
        if cd and cd.ability then
            local remaining = self:GetAbilityRemaining(row.name, unit, cd.ability)
            if remaining and remaining > 0 then
                cd:SetVertexColor(0.35, 0.35, 0.35)
                if cd.timer then
                    cd.timer:SetText(RLSuite.utils:FormatCD(remaining))
                end
            else
                cd:SetVertexColor(1, 1, 1)
                if cd.timer then cd.timer:SetText("") end
            end
        end
    end
end

function RF:UpdateConsumables(row)
    if not row then return end
    if row.isTank then return end -- niente icone consumabili sulle barre Tanks
    local showFlask = self.db.showFlask ~= false
    local showFood = self.db.showFood ~= false

    if row.fake then
        -- Stessi dati della matrice Raid Buffs: se il simulato dice che ha
        -- flask/food, l'icona NON segnala il mancante (niente contraddizioni).
        local member = row.member or { name = row.name, class = row.class }
        local set = self:_DebugMemberBuffSet(member)
        local function hasAny(ids)
            for _, id in ipairs(ids or {}) do
                if set[id] then return true end
            end
            return false
        end
        local hasFlask = hasAny(RLSuite.buffData and RLSuite.buffData.flask)
        local hasFood = hasAny(RLSuite.buffData and RLSuite.buffData.food)
        self:SetConsumable(row.flaskIcon, (showFlask and not hasFlask) and "missing" or "off")
        self:SetConsumable(row.foodIcon, (showFood and not hasFood) and "missing" or "off")
        return
    end

    local unit = row.unit
    if not unit or not UnitExists(unit) then
        self:SetConsumable(row.flaskIcon, "off")
        self:SetConsumable(row.foodIcon, "off")
        return
    end

    if showFlask then
        local has = self:HasAnySpellBuff(unit, RLSuite.buffData and RLSuite.buffData.flask)
        self:SetConsumable(row.flaskIcon, has and "off" or "missing")
    else
        self:SetConsumable(row.flaskIcon, "off")
    end

    if showFood then
        -- Well Fed per NOME DELL'AURA (scan per indice): la vecchia whitelist
        -- di spellId copriva solo alcuni cibi -> "missing" su tutte le altre
        -- varianti (feast, spezie, ...). Nome derivato da GetSpellInfo di un
        -- ID Well Fed noto -> resta locale-safe su client non-EN.
        local wfName = (GetSpellInfo and GetSpellInfo(57399)) or "Well Fed"
        local has = self:UnitHasBuffName(unit, wfName)
        self:SetConsumable(row.foodIcon, has and "off" or "missing")
    else
        self:SetConsumable(row.foodIcon, "off")
    end
end

function RF:SetConsumable(btn, state)
    if not btn then return end
    if state == "off" then
        btn:Hide()
        btn._missing = false
    else
        btn:Show()
        btn._missing = true -- origine della lista "chi manca" per il destro
        if btn.icon then
            btn.icon:SetVertexColor(1, 1, 1)
        end
    end
end

-- GetSpellCooldown only works for the player. Raid members are tracked via combat log + known CD.
-- Queries are made by spellId (locale-safe): the name form of GetSpellCooldown
-- requires the spell to be in the player's spellbook and uses localized names.
function RF:GetAbilityRemaining(playerName, unit, ability)
    if unit and UnitIsUnit(unit, "player") then
        local ids = RLSuite.abilitySpellIdByName and RLSuite.abilitySpellIdByName[ability]
        for _, spellId in ipairs(ids or {}) do
            local start, duration = GetSpellCooldown(spellId)
            if start and duration and duration > 1.5 then
                local rem = start + duration - GetTime()
                if rem > 0 then return rem end
            end
        end
    end
    local expire = self.cdTracker and self.cdTracker[playerName] and self.cdTracker[playerName][ability]
    if expire then
        local rem = expire - GetTime()
        if rem > 0 then return rem end
    end
    return 0
end

function RF:OnSpellCast(sourceName, spellId)
    if not sourceName or not spellId then return end
    local ability = RLSuite.abilityBySpellId and RLSuite.abilityBySpellId[spellId]
    if not ability then return end
    local meta = RLSuite.abilityByName and RLSuite.abilityByName[ability]
    if not meta or not meta.cd then return end
    self.cdTracker = self.cdTracker or {}
    self.cdTracker[sourceName] = self.cdTracker[sourceName] or {}
    self.cdTracker[sourceName][ability] = GetTime() + meta.cd
end

-- ------------------------------------------------------------------
-- Locale-safe aura helpers
-- ------------------------------------------------------------------
function RF:UnitHasSpellBuff(unit, spellId)
    if not unit or not spellId then return false end
    local name = GetSpellInfo(spellId)
    if not name then return false end
    local buffName, _, _, _, _, _, _, _, _, _, buffSpellId = UnitBuff(unit, name)
    if not buffName then return false end
    if buffSpellId and buffSpellId ~= spellId then return false end
    return true
end

-- Scansione aure per NOME (qualsiasi spellId): serve per i buff generici
-- con decine di varianti (Well Fed di ogni cibo). UnitBuff per indice
-- (1..40) e' immune ai mismatch di spellId delle whitelist.
function RF:UnitHasBuffName(unit, wantName)
    if not (unit and wantName and UnitBuff) then return false end
    for i = 1, 40 do
        local bname = UnitBuff(unit, i)
        if not bname then return false end
        if bname == wantName then return true end
    end
    return false
end

function RF:HasAnySpellBuff(unit, spellIds)
    for _, spellId in ipairs(spellIds or {}) do
        if self:UnitHasSpellBuff(unit, spellId) then return true end
    end
    return false
end

function RF:GetAlertIcon(alertType)
    local icons = {
        flask = "Interface\\Icons\\INV_Alchemy_EndlessFlask_01",
        food = "Interface\\Icons\\INV_Misc_Food_15",
        buff = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
    }
    return icons[alertType] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function RF:OnAlertClick(row, atype, button)
    if not row or not atype then return false end
    rfDbg("alert: %s %s", tostring(atype), tostring(button))
    -- Dedup: icona e riga possono INSEGNARE lo stesso click (icona figlia di
    -- content ABOVE row, entrambe ricevono down/up). Nello stesso click
    -- (stesso tasto, < 0.3s) mando UN SOL messaggio.
    row._lastAlert = row._lastAlert or {}
    local key = atype .. "|" .. tostring(button)
    local now = (GetTime and GetTime()) or 0
    if row._lastAlert[key] and (now - row._lastAlert[key]) < 0.3 then
        rfDbg("dedup: stesso click ignorato")
        return true
    end
    row._lastAlert[key] = now

    if button == "RightButton" then
        -- DESTRO su QUALSIASI icona consumabile: avviso a TUTTO il raid con
        -- TUTTI i player a cui manca quel consumabile.
        return self:SendMissingConsumableAlert(atype)
    end

    -- SINISTRO: whisper al player singolo (in debug: whisper a se stessi
    -- col messaggio che verrebbe mandato al player - vedi Utils:Whisper).
    -- Dati presi dalle stesse fonti del ramo destro (che in game funziona):
    -- nome da member con fallback row; msg vuoto = torna al default.
    local name = row.name or (row.member and row.member.name)
    if not name or name == "" then
        rfDbg("abort: nessun nome sulla riga")
        return false
    end
    local alerts = self.db.alerts or {}
    local msg = alerts[atype]
    if not msg or msg == "" then
        msg = self:GetDefaultAlertMessage(atype)
    end
    if not msg or msg == "" then
        rfDbg("abort: nessun messaggio per %s", tostring(atype))
        return false
    end
    msg = string.gsub(msg, "%$name", name)
    rfDbg("whisper -> %s: %s", tostring(name), tostring(msg))
    RLSuite.utils:Whisper(name, msg)
    return true
end

-- Raid warning elenco di TUTTI i player a cui manca il consumabile, letto
-- dai flag _missing mostrati attualmente sulle righe (cioe' esattamente le
-- icone che il leader vede). In debug SendChat whispera a se stessi col tag
-- [RAID_WARNING].
function RF:SendMissingConsumableAlert(atype)
    local missing = {}
    for _, r in ipairs(self.rows or {}) do
        local btn = (atype == "flask") and r.flaskIcon or r.foodIcon
        if btn and btn._missing and r.member and r.member.name then
            missing[#missing + 1] = r.member.name
        end
    end
    if #missing == 0 then return false end
    local label = (atype == "flask") and "flask" or "food buff"
    RLSuite.utils:SendChat("Missing " .. label .. ": " .. table.concat(missing, ", "), "RAID_WARNING")
    return true
end

-- Fallback di click a livello di RIGA (canale che in client riceve sicuro
-- input, vedi drag pre-boss): hit-test col cursore su TUTTE le icone della
-- riga, come i drop-target del Raid Group.
function RF:FireConsumableFromCursor(row, button)
    if not (GetCursorPosition and UIParent and UIParent.GetEffectiveScale) then return false end
    if not (row and row.member and row.member.name) then return false end
    local x, y = GetCursorPosition()
    if not (x and y) then return false end
    local pair = { flask = row.flaskIcon, food = row.foodIcon }
    for atype, btn in pairs(pair) do
        if btn and btn.IsShown and btn:IsShown() and btn._missing then
            -- Scala EFFETTIVA DELL'ICONA (la finestra RF puo' avere scala
            -- propria): normalizzare per UIParent disallinea l'hit-test.
            local scale = (btn.GetEffectiveScale and btn:GetEffectiveScale()) or 1
            if not (scale and scale > 0) then scale = 1 end
            local cx, cy = x / scale, y / scale
            local l, r, b, t = btn:GetLeft(), btn:GetRight(), btn:GetBottom(), btn:GetTop()
            if l and r and b and t and cx >= l and cx <= r and cy >= b and cy <= t then
                return self:OnAlertClick(row, atype, button)
            end
        end
    end
    return false
end

-- Click nudo (qualsiasi tasto) sulla BARRA di una riga: prima prova il
-- hit-test sulle icone (messaggi missing buff); se nessuna icona, un click
-- SINISTRO sulla barra = target del player.
-- Buff mancanti di UN membro: le categorie che lo riguardano, che la
-- composizione puo' coprire e che NON ha attive. Stessa logica della matrice
-- (destinatari + fornitori presenti), quindi nessun falso allarme.
-- Elenco delle categorie che MANCANO a un membro, ognuna con l'eventuale
-- assegnatario: all'avviso serve "MP5 (Lightwall)", cioe' il buff mancante e,
-- fra parentesi, chi deve provvedere (db.buffAssign).
function RF:MissingBuffEntries(member, group)
    local out = {}
    if not member then return out end
    local entries = {}
    local groups = self:GetGroupedRoster()
    for g = 1, #groups do
        for s = 1, #groups[g] do
            local m = groups[g][s]
            if m then entries[#entries + 1] = { member = m, group = g } end
        end
    end
    for _, col in ipairs(self:_MatrixCols()) do
        if col.kind ~= "durability" then
            local ctx = self:_BuffProviderContext(col, entries)
            if self:_BuffApplicable(member, col) and self:_BuffCoverable(col, ctx, group) then
                if self:_BuffCellIconFor(member, col, group) == nil then
                    out[#out + 1] = { label = col.label or col.key, assign = self:GetBuffAssign(col) }
                end
            end
        end
    end
    return out
end

function RF:MissingBuffLabels(member, group)
    local out = {}
    for _, e in ipairs(self:MissingBuffEntries(member, group)) do
        out[#out + 1] = e.label
    end
    return out
end

-- CTRL+click (sinistro) sul nome/barra del player: avviso IN RAID (raid
-- warning), diretto:
--     Missing buffs on <nome>: <buff>(<chi lo fa>), <buff>, ...
-- Nessun "Hey", nessun giro di parole: e' un messaggio da raid leading.
-- Non e' piu' un whisper al singolo: la richiesta era che l'avviso lo vedesse
-- il raid. Se non manca niente non si manda niente in raid: lo dice solo al
-- leader.
function RF:SendMissingBuffsAlert(row)
    if not row then return false end
    local now = (GetTime and GetTime()) or 0
    -- dedup: pressione, rilascio e poller possono convergere nello stesso click
    if row._buffAlertT and (now - row._buffAlertT) < 0.3 then return true end
    row._buffAlertT = now

    local member = row.member
    local name = row.name or (member and member.name)
    if not name or name == "" then return false end
    local entries = self:MissingBuffEntries(member, row.group)
    if #entries == 0 then
        RLSuite.utils:Print(string.format(L["%s has all the raid buffs."], name))
        return false
    end
    -- "MP5(Lightwall)": il nome del buff e, fra parentesi, chi deve farlo.
    -- Se nessuno e' assegnato resta il solo nome del buff (nessuno da citare).
    local parts = {}
    for _, e in ipairs(entries) do
        if e.assign and e.assign ~= "" then
            parts[#parts + 1] = string.format("%s(%s)", e.label, e.assign)
        else
            parts[#parts + 1] = e.label
        end
    end
    local list = table.concat(parts, ", ")
    local alerts = self.db.alerts or {}
    local msg = alerts.buff
    -- Un profilo vecchio puo' avere salvato il testo "giocoso": si riconosce e
    -- si passa al testo diretto nuovo (non c'e' piu' un editor degli alert).
    local legacy = L["Hey $name, you're missing some raid buffs!"]
    if not msg or msg == "" or msg == legacy then msg = self:GetDefaultAlertMessage("buff") end
    msg = string.gsub(msg or "", "%$name", name)
    msg = msg .. " " .. list
    -- RAID WARNING (Utils:SendChat torna a RAID se non sei leader/officer):
    -- cosi' l'avviso lo vede tutto il raid, assegnatario compreso.
    if #msg > 240 then msg = msg:sub(1, 237) .. "..." end
    RLSuite.utils:SendChat(msg, "RAID_WARNING")
    RLSuite.utils:Print(string.format(L["Missing buffs for %s: %s"], name, list))
    return true
end

function RF:RowPlainClick(row, button)
    -- CTRL+click sinistro: avviso buff mancanti a quel player (e niente
    -- target: il gesto con CTRL non deve cambiare bersaglio).
    if button == "LeftButton" and IsControlKeyDown and IsControlKeyDown() then
        self:SendMissingBuffsAlert(row)
        return true
    end
    local fired = self:FireConsumableFromCursor(row, button)
    if not fired and button == "LeftButton" then
        self:TargetRow(row)
    end
end

-- Target del player della riga. ALLA PRESSIONE di un click sinistro nudo
-- sulla barra (comportamento standard degli unit frame: Grid/VuhDo/HealBot
-- targettano al mouse-down). Dedup TTL 0.3s: press + release + poller
-- possono convergere nello stesso click.
-- Condizione IRROGABILE dell'utente: "clicco il nome → target il player
-- con QUEL nome": prima prova la via unit (TargetUnit su unit valida),
-- altrimenti TargetByName(nome esatto). Mai su fake/debug: l'entita' non
-- esiste nel gioco → nessun bonk di errore Blizzard, solo traccia rfDbg.
function RF:TargetRow(row)
    if not row then return false end
    local now = (GetTime and GetTime()) or 0
    if row._targetT and (now - row._targetT) < 0.3 then return true end
    row._targetT = now
    local name = row.name or (row.member and row.member.name)
    -- TargetUnit() e' PROTETTA: il client la rifiuta da qualsiasi codice
    -- addon ("tainted execution path") -> MAI chiamarla. Il target con unit
    -- reale lo fa l'overlay SecureActionButtonTemplate (engine, alla
    -- pressione). Chiamata Lua solo come fallback PER NOME, quando l'overlay
    -- non e' visibile (es. attributi congelati in combat durante un FillSlot).
    if row.secTarget and row.secTarget:IsShown() then
        rfDbg("target overlay-engine -> %s", tostring(name))
        return true
    end
    if name and name ~= "" and TargetByName and not row.fake then
        rfDbg("target by name -> %s", tostring(name))
        TargetByName(name)
        return true
    end
    -- roster finto/nessuna unit reale: solo traccia, nessun bonk
    rfDbg("target (solo traccia, unita' non reale) -> %s", tostring(name))
    return false
end

function RF:GetDefaultAlertMessage(alertType)
    local msgs = {
        flask = L["Hey $name, you're missing a flask!"],
        food = L["Hey $name, you're missing food buff!"],
        buff = L["Missing buffs on $name:"],
    }
    return msgs[alertType]
end

-- ------------------------------------------------------------------
-- Phase + drag & drop
-- ------------------------------------------------------------------
function RF:UpdatePhase()
    self:Rebuild()
    self:UpdateDragState()
end

-- I player si spostano SEMPRE, in QUALUNQUE fase: anche DURANTE il combat.
-- Spostare qualcuno di gruppo mentre si combatte e' una necessita' vera
-- (meccaniche che prendono 1/2/3 player, soak, "vai in gruppo 3 adesso"),
-- non un'operazione da rimandare a fine pull.
-- Su 3.3.5 SetRaidSubgroup/SwapRaidSubgroup NON sono protette: la protezione
-- arriva con Cataclysm 4.0.1. Fino alla 1.11.73 il blocco era NOSTRO (gate
-- sulla fase "preboss"), quindi in infight il drag non partiva nemmeno e
-- sembrava colpa del client.
function RF:IsDragEnabled()
    return true
end

-- ======================================================================
-- DRAG GIOCATORE: il gesto NON dipende piu' da CHI riceve gli eventi.
-- ======================================================================
-- Storia (costata 3 release): in 3.3.5 la consegna del mouse e' fragile -
-- il drag manager divora rilasci, i frame sicuri/figli possono mangiare la
-- pressione, e un errore in un punto solo faceva "morire" il gesto senza
-- dire niente (sintomo: un player si sposta una volta, poi basta).
-- Qui la REGIA e' di un poller su frame dedicato: legge lo STATO del tasto
-- (IsMouseButtonDown) e la POSIZIONE del cursore, e risolve sorgente e
-- destinazione GEOMETRICAMENTE (hit-test sui rettangoli delle barre).
-- Gli handler delle righe restano come via secondaria: chi arriva primo
-- esegue, l'altro vede _rfDragSource gia' pulito e non fa nulla (nessun
-- doppio spostamento).
function RF:_StartDragFromSlot(slot)
    if not slot or not slot.member then return end
    -- Le barre Tanks (MT/OT) NON si trascinano: non sono mai sorgente.
    if slot.isTank then return end
    if self._rfDragSource == slot then return end
    self._rfDragSource = slot
    slot._manualDrag = true
    rfDbg("drag: parto dallo slot %s (%s)", tostring(slot.slot), tostring(slot.name))
    self:RefreshDropTargets()
    self:_ArmManualDragWatchdog()
end

-- Chiusura del drag (rilascio): risolve il bersaglio sotto il cursore e
-- sposta. Chiamata da TUTTE le vie (mouse-up di riga/piano, watchdog,
-- poller): idempotente perche' azzera _rfDragSource alla prima esecuzione.
function RF:_FinishDrag()
    local src = self._rfDragSource
    if not src then return end
    -- Bersaglio calcolato PRIMA di azzerare la sorgente (l'hit-test conta
    -- sulla geometria, non sulla visibilita' delle righe).
    local t = self:SlotAtCursor()
    self._rfDragSource = nil
    src._manualDrag = nil
    -- Un click nudo rimasto appeso sulla riga di partenza non deve suonare
    -- come "target" dopo un drag.
    src._pendingRowClick = nil
    if src._scripts and src._scripts.OnUpdate then src:SetScript("OnUpdate", nil) end
    if src.member then
        if t and t ~= src then
            rfDbg("drag: rilascio sullo slot %s", tostring(t.slot))
            self:MoveSlot(src, t)
        else
            rfDbg("drag: rilascio senza bersaglio (annullo)")
        end
    end
    self._dropActive = nil
    self:RefreshDropTargets()
end

-- Poller del drag: 20 Hz, spento se la finestra non c'e'. Rising edge del
-- tasto sinistro = possibile inizio; falling edge = rilascio (anche fuori
-- dalle righe). SHIFT puo' arrivare anche DOPO la pressione: se la pressione
-- e' partita su una barra giocatore, il drag parte appena lo shift c'e'.
function RF:_InitDragPoller()
    if self._dragPoller or not self.frame then return end
    local p = CreateFrame("Frame", nil, self.frame)
    p:SetSize(1, 1)
    p:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    p:EnableMouse(false)   -- non deve rubare niente
    p:Show()
    self._dragBtnDown = false
    self._dragPressSlot = nil
    local acc = 0
    p:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 0.03 then return end
        acc = 0
        local down = (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) and true or false
        if down and not RF._dragBtnDown then
            RF._dragBtnDown = true
            -- Diagnostica (debug mode): la pressione su una barra dice SUBITO
            -- cosa vede l'addon - barra piena, barra vuota, o nessuna barra.
            -- Serve a non restare mai piu' con un gesto che "non fa niente".
            local shifted = (IsShiftKeyDown and IsShiftKeyDown()) and true or false
            local hull = RF:SlotAtCursor()
            RF._dragPressSlot = nil
            if hull and hull.member then
                RF._dragPressSlot = hull
                if shifted then
                    rfDbg("shift+left: barra %s (%s)", RF:SlotLabel(hull), tostring(hull.name))
                end
            else
                -- Niente riga sotto il cursore: prima si prova la TOLLERANZA
                -- (il gesto a filo della barra deve funzionare), poi si dice
                -- perche' non si e' agganciato niente.
                local nearRow, nearD = RF:MemberRowAtCursor(RF_DRAG_SNAP)
                if nearRow then
                    RF._dragPressSlot = nearRow
                    if shifted then
                        rfDbg("shift+left: aggancio la barra %s (%s) a %d px (a filo)",
                            RF:SlotLabel(nearRow), tostring(nearRow.name), math.floor(nearD + 0.5))
                    end
                elseif shifted then
                    if hull then
                        rfDbg("shift+left: barra %s VUOTA (nessun player su quella riga)", RF:SlotLabel(hull))
                    else
                        local tank = RF:TankBarAtCursor()
                        if tank then
                            rfDbg("shift+left: barra %s (%s) - le barre Tanks non si spostano; il player si prende dalla sua barra nei gruppi",
                                RF:SlotLabel(tank), tostring(tank.name))
                        elseif RF:IsCursorOverFrame() then
                            local cx, cy = GetCursorPosition()
                            local near, dist = RF:NearestMemberInfo(cx or 0, cy or 0)
                            if near then
                                rfDbg("shift+left: NESSUNA barra sotto %s - piu' vicina: barra %s (%s) a %d px (tolleranza %d)",
                                    RF:CursorText(), RF:SlotLabel(near), tostring(near.name),
                                    math.floor(dist + 0.5), RF_DRAG_SNAP)
                            else
                                rfDbg("shift+left: NESSUNA barra sotto %s - nessuna barra con un player nell'HUD",
                                    RF:CursorText())
                            end
                        end
                    end
                end
            end
            if RF._dragPressSlot and shifted and not RF._dragPressSlot:IsShown() then
                rfDbg("shift+left: la riga %s risulta NON mostrata ma ha %s: la prendo lo stesso",
                    RF:SlotLabel(RF._dragPressSlot), tostring(RF._dragPressSlot.name))
            end
        elseif (not down) and RF._dragBtnDown then
            RF._dragBtnDown = false
            RF._dragPressSlot = nil
            if RF._rfDragSource then RF:_FinishDrag() end
        end
        if down and not RF._rfDragSource and RF._dragPressSlot
            and IsShiftKeyDown and IsShiftKeyDown() then
            RF:_StartDragFromSlot(RF._dragPressSlot)
        end
        if RF._rfDragSource then RF:UpdateDropGlow() end
    end)
    self._dragPoller = p
end

-- Stato geometrico dell'HUD (diagnostica `/rls rfdump`): per ogni barra con
-- un player dice se la riga risulta mostrata, se la barra e' mostrata e i
-- rettangoli dei due. Serve a capire in un colpo se cio' che si VEDE
-- corrisponde a cio' che l'addon puo' prendere col mouse.
function RF:DiagSlotLines()
    local lines = {}
    local function rect(f)
        if not f then return "?" end
        local l, r = f:GetLeft(), f:GetRight()
        local b, t = f:GetBottom(), f:GetTop()
        if type(l) ~= "number" or type(r) ~= "number"
            or type(b) ~= "number" or type(t) ~= "number" then
            return "senza coordinate"
        end
        return string.format("[%d,%d] x [%d,%d]", math.floor(l + 0.5), math.floor(r + 0.5),
            math.floor(b + 0.5), math.floor(t + 0.5))
    end
    local function add(list, label)
        for _, slot in ipairs(list or {}) do
            if slot and slot.member then
                lines[#lines + 1] = string.format("  %s %s  %s | riga %s%s | barra %s %s",
                    label, RF:SlotLabel(slot), tostring(slot.name),
                    slot:IsShown() and "mostrata" or "NASCOSTA",
                    (slot.isTank and " (tank)" or ""),
                    (slot.bar and slot.bar:IsShown()) and "mostrata" or "nascosta",
                    slot.bar and rect(slot.bar) or "?")
            end
        end
    end
    add(self.slots, "riga")
    add(self.tankSlots, "tank")
    if self.frame then
        lines[#lines + 1] = "  finestra: " .. rect(self.frame)
            .. string.format("  scala=%s", tostring(self.frame.GetScale and self.frame:GetScale() or 1))
    end
    if #lines == 0 then lines[#lines + 1] = "  nessuna barra con un player" end
    return lines
end

-- Il cursore e' sopra la finestra dell'HUD? (solo per la diagnostica: se non
-- succede niente, si distingue "non e' la zona giusta" da "la barra non
-- risponde").
function RF:IsCursorOverFrame()
    if not (self.frame and GetCursorPosition) then return false end
    local x, y = GetCursorPosition()
    if not x then return false end
    local l, r = self.frame:GetLeft(), self.frame:GetRight()
    local b, t = self.frame:GetBottom(), self.frame:GetTop()
    if not (l and r and b and t) then return false end
    return x >= l and x <= r and y >= b and y <= t
end

function RF:CursorText()
    if not GetCursorPosition then return "?" end
    local x, y = GetCursorPosition()
    return string.format("%d,%d", tonumber(x) or -1, tonumber(y) or -1)
end

function RF:UpdateDragState()
    -- Drag delle righe = MANUALE (nessun RegisterForDrag, manco per fase):
    -- le righe restano SEMPRE con mouse attivo e click liberi; il drag del
    -- player parte su Shift+down in QUALUNQUE fase, combat compreso
    -- (OnMouseDown → _rfDragSource).
    -- EnableMouse(false) / RegisterForDrag qui in passato rendevano mute le
    -- righe: il tasto premuto veniva divorato dal drag manager di 3.3.5.
    for _, slot in ipairs(self.slots or {}) do
        slot:RegisterForDrag() -- sì: svuota esplicitamente qualunque set ereditato
    end
end

-- Watchdog del drag player MANUALE: se il release avviene FUORI dalle righe
-- (cursore uscito dall'HUD), i singoli OnMouseUp non lo vedono. Pollo su
-- frame dedicato: tasto rilasciato mentre _rfDragSource → drop/cancel.
function RF:_ArmManualDragWatchdog()
    if self._dragWatchArmed then return end
    if not self.frame then return end
    if not self._dragWatch then
        self._dragWatch = CreateFrame("Frame", nil, self.frame)
        self._dragWatch:SetSize(1, 1)
        self._dragWatch:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    end
    self._dragWatch:Show()
    self._dragWatchArmed = true
    self._dragWatch:SetScript("OnUpdate", function()
        if not RF._rfDragSource then
            RF._dragWatchArmed = false
            RF._dragWatch:Hide()
            RF:UpdateDropGlow() -- sicurezza: nessun bordino residuo appeso
            return
        end
        RF:UpdateDropGlow() -- il bordino dorato insegue il cursore
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            RF:_FinishDrag()
        end
    end)
end

-- Slot under the mouse cursor (nil if none). Mirrors GroupMaking's
-- WlSlotAtCursor: computes the target from the cursor coordinates because
-- OnReceiveDrag is not always delivered on nested frames.
-- requireMember: usato per la SORGENTE del drag (solo barre con un player).
function RF:SlotAtCursor(requireMember)
    if not GetCursorPosition then return nil end
    local x, y = GetCursorPosition()
    if not x or not y then return nil end
    -- SOLO righe dei gruppi: le barre Tanks (MT/OT) non sono ne' sorgenti ne'
    -- bersagli di trascinamento (comportamento storico, ripristinato).
    return self:_SlotUnderCursor(self.slots, x, y, requireMember)
end

-- Distanza fra il cursore e il rettangolo di una riga (0 = dentro).
-- nil se la riga non ha coordinate utilizzabili.
function RF:_RectDistance(slot, x, y)
    if not slot then return nil end
    local scale = (slot.GetEffectiveScale and slot:GetEffectiveScale()) or 1
    if not (scale and scale > 0) then scale = 1 end
    local cx, cy = x / scale, y / scale
    local l, r = slot:GetLeft(), slot:GetRight()
    local b, t = slot:GetBottom(), slot:GetTop()
    if type(l) ~= "number" or type(r) ~= "number"
        or type(b) ~= "number" or type(t) ~= "number" then
        return nil
    end
    local dx = math.max(l - cx, 0, cx - r)
    local dy = math.max(b - cy, 0, cy - t)
    return math.sqrt(dx * dx + dy * dy)
end

-- Riga DI GRUPPO con un player sotto il cursore, con tolleranza: serve al
-- gesto vero. Non guarda IsShown() di proposito - dalla 1.11.76 barra e icone
-- vivono su content (fuori dalla riga), quindi puo' esserci una barra VISIBILE
-- con la riga che risulta non mostrata: se il player si vede, si deve
-- prendere. Ritorna riga e distanza (0 = cursore dentro la riga).
function RF:MemberRowAtCursor(tol)
    if not GetCursorPosition then return nil end
    local x, y = GetCursorPosition()
    if not x or not y then return nil end
    local best, bestD = nil, nil
    for _, slot in ipairs(self.slots or {}) do
        if slot and slot.member then
            local d = self:_RectDistance(slot, x, y)
            if d and (not bestD or d < bestD) then best, bestD = slot, d end
        end
    end
    if not best then return nil end
    if tol and bestD > tol then return nil end
    return best, bestD
end

-- Slot di una lista (righe gruppi o barre Tanks) sotto il cursore.
function RF:_SlotUnderCursor(list, x, y, requireMember)
    if not list then return nil end
    -- Durante un drag l'hit-test e' GEOMETRICO: la visibilita' della riga
    -- non deve poter decidere se un drop riesce (in combat la riga poteva
    -- restare invisibile -> SlotAtCursor nil -> nessun rilascio).
    local dragging = self._dropActive or self._rfDragSource ~= nil
    for _, slot in ipairs(list) do
        if slot and (slot:IsShown() or (dragging and slot.dropPlane ~= nil)) then
            -- SCALA: GetLeft/GetBottom/... sono nello spazio della scala
            -- EFFETTIVA DELLO SLOT, non di UIParent. Se la finestra RF ha
            -- una scala propria (config "Scale"), il cursore va riportato in
            -- QUELLA scala: normalizzare per UIParent sposta l'hit-test di
            -- una frazione proporzionale alla distanza dall'ancora (bug
            -- osservato: bordino di drop evidenziato ~un gruppo piu' in
            -- alto del cursore).
            local scale = (slot.GetEffectiveScale and slot:GetEffectiveScale()) or 1
            if not (scale and scale > 0) then scale = 1 end
            local cx, cy = x / scale, y / scale
            local left = slot:GetLeft()
            local right = slot:GetRight()
            local bottom = slot:GetBottom()
            local top = slot:GetTop()
            if type(left) == "number" and type(right) == "number"
                and type(bottom) == "number" and type(top) == "number"
                and cx >= left and cx <= right and cy >= bottom and cy <= top then
                if (not requireMember) or slot.member then
                    return slot
                end
            end
        end
    end
    return nil
end

-- Info sulla barra con un player piu' vicina al cursore: serve alla
-- diagnostica ("nessuna barra sotto: la piu' vicina e' a N px"), cosi' un
-- gesto a vuoto dice SUBITO se il cursore e' in un buco o fuori dalle barre.
function RF:NearestMemberInfo(x, y)
    local best, bestD = nil, nil
    for _, slot in ipairs(self.slots or {}) do
        if slot and slot.member then
            local d = self:_RectDistance(slot, x, y)
            if d and (not bestD or d < bestD) then best, bestD = slot, d end
        end
    end
    return best, bestD
end

-- Etichetta di una barra per le tracce: "12" (riga) oppure "MT"/"OT".
function RF:SlotLabel(slot)
    if not slot then return "?" end
    if slot.slot then return tostring(slot.slot) end
    return tostring(slot.tankTagText or "tank")
end

-- La barra Tanks sotto il cursore (solo per la DIAGNOSTICA: le barre Tanks
-- non si trascinano, ma se l'utente le prende deve leggere il perche').
function RF:TankBarAtCursor()
    if not GetCursorPosition then return nil end
    local x, y = GetCursorPosition()
    if not x or not y then return nil end
    return self:_SlotUnderCursor(self.tankSlots, x, y, true)
end

-- Reorganizes the groups by dragging a player between slots. src/dst are
-- the two slot frames (source and destination). Vale anche in combat: su
-- 3.3.5 i due API dei sottogruppi non sono protetti. Empty destination = move,
-- occupied destination = swap.
function RF:MoveSlot(src, dst)
    if not src or not dst or src == dst then return end
    if not src.member then return end

    -- Simulated roster (debug): reorder the shared slot list.
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        self:MoveSlotDebug(src, dst)
        return
    end

    -- Real raid: Blizzard APIs (only the raid leader can rearrange).
    if not (IsRaidLeader and (IsRaidLeader() or IsRaidOfficer())) then
        RLSuite.utils:Print(L["Only the raid leader can rearrange groups."])
        return
    end
    local srcIdx = src.raidIndex
    if not srcIdx then
        rfDbg("move: nessun indice raid per %s", tostring(src.name))
        return
    end
    if dst.member and dst.raidIndex then
        local dstIdx = dst.raidIndex
        -- Swap: SwapRaidSubgroup exchanges the two players.
        pcall(SwapRaidSubgroup, srcIdx, dstIdx)
    else
        -- Move: SetRaidSubgroup moves the player to the target group.
        pcall(SetRaidSubgroup, srcIdx, dst.group)
    end
end

-- Reorders the simulated roster in debug: swaps two members (occupied slot)
-- or moves a member exactly into the empty destination slot. The slots are
-- SPARSE, so a move leaves a hole in the source slot (shown by both the
-- InviteEngine Raid Group panel and this HUD).
function RF:MoveSlotDebug(src, dst)
    local slots = RLSuite:DebugRaidSlots()
    local srcSlot = tonumber(src.slot)
    if not srcSlot then return end
    local srcMember = slots[srcSlot]
    local dstMember = slots[dst.slot]
    if not srcMember then
        rfDbg("move(debug): slot %s vuoto, niente da spostare", tostring(srcSlot))
        return
    end

    if dstMember then
        slots[srcSlot], slots[dst.slot] = dstMember, srcMember
    else
        slots[dst.slot] = srcMember
        slots[srcSlot] = nil
    end
    RLSuite:DebugSyncSubgroups()
    RLSuite:DebugRosterChanged()
end

-- ------------------------------------------------------------------
-- Layout / update entry points
-- ------------------------------------------------------------------
function RF:ApplyLayout()
    local db = self.db
    if not db or not self.frame then return end
    local m = self:LayoutMetrics()
    self.frame:SetWidth(m.W)
    -- La main bar e' ancorata a una distanza dal lato destro pari alla
    -- larghezza di QUESTO frame (senza i buff): se cambia la larghezza del
    -- Raid Frame (icon size, bar width, scala) la barra si riposiziona.
    if RLSuite.mainWindow and RLSuite.mainWindow.ApplyLayout then
        RLSuite.mainWindow:ApplyLayout()
    end
    self.frame:SetScale(db.scale or 1)
    -- Trasparenza complessiva dell'HUD (Config -> Raid Frame -> Layout).
    self.frame:SetAlpha(db.alpha or 1)

    -- GRIGLIA IMMOBILE (v1.11.62): le posizioni delle barre NON dipendono
    -- dal roster. Ogni gruppo ha SEMPRE il suo blocco (header + 5 righe), il
    -- blocco Tanks (header + MT/OT) e la zona strip in alto sono riservati
    -- sempre, anche se il gruppo e' vuoto o il raid e' vuoto. Cosi' chi sta
    -- in G6 sta IN FONDO anche a raid vuoto, la griglia non si ri-compatta
    -- mai e il buff check resta allineato alle righe.
    local y = 0
    -- MATRICE "Raid Buffs" attiva? Riga d'intestazione IN CIMA con i nomi
    -- sintetici delle categorie, poi il resto (Tanks compreso) scende.
    local matrixOn = self.buffMatrixOn and self.rows and self.rows[1] ~= nil
    -- La RIGA D'INTESTAZIONE e' PERMANENTE: fuori dal pannello toggle,
    -- visibile INDIPENDENTEMENTE dal tasto "Raid Buffs" finche' c'e' un
    -- roster. Il tasto accende/spegne SOLO le icone dei player.
    local headersOn = self.rows and self.rows[1] ~= nil
    local mCols = headersOn and self:_MatrixCols() or nil
    -- Altezza della zona strip (icone di intestazione della matrice):
    -- RISERVATA SEMPRE nel blocco G1, a matrice accesa o spenta.
    local stripH = m.cellW + 4
    if headersOn then
        -- Testata a ICONE CUSTOM (BCI_<c-1>.tga): creazione/refresh qui; la
        -- POSIZIONE vera viene fatta nel loop dei gruppi, ALL'ALTEZZA DELL'
        -- HEADER G1 (vedi sotto). UNA SetTexture diretta sui tga dell'utente:
        -- niente blp, niente fallback, niente detection.
        for c, col in ipairs(mCols) do
            local btn = self:_MatrixHeaderBtn(c)
            btn._col = col
            btn._icon:SetTexture(self:_BuffHeaderIconPath(col, c))
            btn._icon:ClearAllPoints()
            btn._icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn._icon:SetSize(m.cellW, m.cellW) -- size = iconSize + iconSpacing, FISSO
            -- NIENTE Show qui: la riga d'intestazione nasceva permanente, ora
            -- si mostra/nasconde col tasto "Raid Buffs" (RefreshBuffMatrix).
        end
    end
    -- Se la matrice e' spenta, anche lo sfondo della strip si nasconde.
    if self._buffHdrBg and not matrixOn then self._buffHdrBg:Hide() end

    -- Font size configurabile delle intestazioni di gruppo (G1..G6, Tanks).
    local ghApp = (self.db and self.db.appearance) or {}
    local ghFont = ghApp.font or "Fonts\\FRIZQT__.TTF"
    local ghSize = ghApp.groupHeaderFontSize or 10
    local ghFlags = (ghApp.fontOutline ~= false) and "OUTLINE" or ""
    if self.tankHeader and self.tankHeader.SetFont then
        self.tankHeader:SetFont(ghFont, ghSize, ghFlags)
    end
    for g = 1, RF_GROUPS do
        local gh = self.groupHeaders and self.groupHeaders[g]
        if gh and gh.SetFont then gh:SetFont(ghFont, ghSize, ghFlags) end
    end
    -- BLOCCO TANKS (SOPRA G1): header + barre MT/OT (sempre 2, piene o
    -- vuote). SPAZIO RISERVATO SEMPRE: la griglia non si muove quando il
    -- roster appare/sparisce (prima il blocco c'era solo con un roster).
    if self.tankHeader then
        self.tankHeader:ClearAllPoints()
        self.tankHeader:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, y)
        self.tankHeader:SetWidth(m.rowWidth)
        y = y - m.groupHeaderH
        local otSlot = nil
        for ti = 1, RF_TANK_COUNT do
            local t = self.tankSlots and self.tankSlots[ti]
            if t then
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
                self:LayoutSlotGeometry(t, m)
                y = y - m.rowHeight - m.rowSpacing
                if ti == 2 then otSlot = t end -- OT = seconda barra tank
            end
        end
        -- Bottone "Raid Buffs": sotto le barre target dei tank, allineato
        -- come l'header G1: bordo INFERIORE = fondo della zona strip, bordo
        -- DESTRO = fine barra. (Show/Hide li decide RebuildTanks.)
        if self.buffPanelBtn and otSlot and otSlot.targetBar then
            self.buffPanelBtn:ClearAllPoints()
            if headersOn then
                self.buffPanelBtn:SetPoint("BOTTOMRIGHT", self.content, "TOPLEFT",
                    m.rowWidth, y - stripH)
            else
                self.buffPanelBtn:SetPoint("TOPRIGHT", otSlot.targetBar, "BOTTOMRIGHT", 0, 0)
            end
            -- Show/Hide NON qui: lo decide RebuildTanks (spento a roster vuoto).
        end
    elseif self.buffPanelBtn then
        self.buffPanelBtn:Hide()
    end
    -- ZONA STRIP tra Tanks e G1: SEMPRE riservata (cellW+4 = dimensione delle
    -- icone d'intestazione), a matrice accesa o spenta, con o senza roster.
    local stripTop = y
    y = y - stripH
    for g = 1, RF_GROUPS do
        local hdr = self.groupHeaders and self.groupHeaders[g]
        if hdr then
            hdr:ClearAllPoints()
            if g == 1 then
                -- Header G1: ATTACCATO IN BASSO alla sua zona strip (stessa
                -- linea a matrice accesa e spenta).
                hdr:SetPoint("BOTTOMLEFT", self.content, "TOPLEFT", 2, stripTop - stripH)
            else
                hdr:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, y)
            end
            hdr:SetWidth(m.rowWidth)
        end
        if g == 1 then
            -- Icone di intestazione + sfondo della strip: DENTRO la zona
            -- riservata (non spostano niente quando si accendono).
            if matrixOn and mCols then
                for c = 1, #mCols do
                    local btn = self._buffHdrBtns and self._buffHdrBtns[c]
                    if btn then
                        btn:ClearAllPoints()
                        btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
                            m.rowWidth + 4 + (c - 1) * m.cellW, stripTop)
                        btn:SetSize(m.cellW, stripH)
                    end
                end
                -- Backdrop UNICO della strip: valore del backdrop barre
                -- (appearance.matrixBackdrop, Config -> Raid Frame).
                local bg = self._buffHdrBg
                if not bg then
                    bg = self.frame:CreateTexture(nil, "BACKGROUND")
                    self._buffHdrBg = bg
                end
                local bc = (self.db and self.db.appearance and self.db.appearance.matrixBackdrop) or {}
                bg:SetTexture(bc.r or 0.5, bc.g or 0.5, bc.b or 0.5, bc.a or 0.35)
                bg:ClearAllPoints()
                bg:SetPoint("TOPLEFT", self.frame, "TOPLEFT", m.rowWidth + 2, stripTop)
                bg:SetSize(#mCols * m.cellW + 6, stripH)
                bg:Show()
            elseif self._buffHdrBg then
                self._buffHdrBg:Hide()
            end
        else
            -- Header del gruppo: riga sua, riservata sempre.
            y = y - m.groupHeaderH
        end
        -- 5 RIGHE DEL GRUPPO: lo spazio e' RISERVATO SEMPRE (le righe vuote
        -- restano invisibili ma ognuna al suo posto: niente ri-compattamento).
        for s = 1, RF_PER_GROUP do
            local slot = self.slots and self.slots[(g - 1) * RF_PER_GROUP + s]
            if slot then
                slot:ClearAllPoints()
                slot:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
                self:LayoutSlotGeometry(slot, m)
                if matrixOn and slot.member and slot:IsShown() then
                    self:_LayoutMatrixRow(slot, m, y, mCols)
                end
            end
            y = y - m.rowHeight - m.rowSpacing
        end
        if g < RF_GROUPS then y = y - m.groupSpacing end
    end
    -- Altezza della griglia = COSTANTE (non dipende dal roster): la finestra
    -- non cambia mai dimensione, quindi non si sposta mai.
    local rowsH = -y

    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    self.content:SetSize(m.rowWidth, rowsH)

    self.frame:SetHeight(math.max(20, rowsH))

    -- Colore del font dei nomi (Config -> Raid Frame -> Layout -> Font color).
    local fc = db.appearance and db.appearance.fontColor
    local fr, fg, fb = (fc and fc.r) or 1, (fc and fc.g) or 1, (fc and fc.b) or 1
    for _, slot in ipairs(self.slots or {}) do
        if slot.bar and slot.bar.nameText then
            slot.bar.nameText:SetTextColor(fr, fg, fb, 1)
        end
    end
    for _, t in ipairs(self.tankSlots or {}) do
        if t.bar and t.bar.nameText then
            t.bar.nameText:SetTextColor(fr, fg, fb, 1)
        end
    end
    self:RefreshBuffMatrix()

    if (RLSuite.InRaid and RLSuite:InRaid()) or (GetNumRaidMembers and GetNumRaidMembers() > 0) then
        self:UpdateAll()
    end

end

function RF:Update()
    self:Rebuild()
    self:UpdateAll()
end

-- ------------------------------------------------------------------
-- MATRICE "Raid Buffs" (stile Method Raid Tools) INTEGRATA nel Raid
-- Frame: si attiva col tasto "Raid Buffs" (Riga header Tanks). Le icone
-- di ogni categoria stanno LUNGO LA RIGA del player nei gruppi; una riga
-- di intestazione coi nomi sintetici delle categorie appare in cima.
-- Niente pannello separato, niente colonne Flask/Well Fed (le icone
-- consumabili per-riga le controllano gia').
-- ------------------------------------------------------------------
-- Colonne MATRICE visibili: le 21 categorie MENO Flask e Well Fed
-- (gia' controllate dalle icone consumabili per-riga nel Raid Frame).
function RF:_MatrixCols()
    if self._matrixColsCache then return self._matrixColsCache end
    local out = {}
    for _, col in ipairs(RLSuite.raidBuffColumns or {}) do
        if col.key ~= "flask" and col.key ~= "wellfed" then
            out[#out + 1] = col
        end
    end
    -- I buff PIU' IMPORTANTI sono i primi a sinistra (RF_BP_PRIORITY).
    table.sort(out, function(a, b)
        local pa = RF_BP_PRIORITY[a.key] or 99
        local pb = RF_BP_PRIORITY[b.key] or 99
        if pa ~= pb then return pa < pb end
        return (a.label or a.key or "") < (b.label or b.key or "")
    end)
    self._matrixColsCache = out
    return out
end

-- Intestazione matrice: UN BOTTONE per colonna con l'ICONA CUSTOM della
-- categoria (media/BUFFCATICONS/BCI_<c-1>.tga, i file caricati dall'utente).
-- Ordine = colonne da sinistra a destra; size = iconSize + iconSpacing.
-- Hover: l'icona si accende; click: raid warning per quella categoria.
function RF:_BuffCatIconPath(c)
    return RLSuite:AddonTexture("media\\BUFFCATICONS\\BCI_" .. (c - 1) .. ".tga")
end

-- Icona di intestazione di una colonna: le categorie di buff usano i tga
-- caricati dall'utente (BCI_<c-1>.tga, indici INVARIATI perche' la durability
-- sta in fondo), le colonne di servizio usano la loro icona di gioco.
function RF:_BuffHeaderIconPath(col, c)
    if col and col.kind == "durability" then return col.icon end
    return self:_BuffCatIconPath(c)
end

function RF:_MatrixHeaderBtn(c)
    self._buffHdrBtns = self._buffHdrBtns or {}
    local btn = self._buffHdrBtns[c]
    if not btn then
        -- TIRATI FUORI DAL PANNELLO: figli della WINDOW, non di content: la
        -- riga d'intestazione resta SEMPRE visibile, per sempre.
        btn = CreateFrame("Button", nil, self.frame)
        local tex = btn:CreateTexture(nil, "OVERLAY")
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tex:SetPoint("CENTER", btn, "CENTER", 0, 0)
        tex:SetVertexColor(RF_HDR_NORMAL, RF_HDR_NORMAL, RF_HDR_NORMAL)
        btn._icon = tex
        -- Overlay ROSSO sopra l'icona: categoria disponibile ma check non
        -- soddisfatto (stesso linguaggio visivo delle spell non usabili).
        -- Texture bianca tinta via SetVertexColor (SetColorTexture non esiste
        -- su 3.3.5) e sub-layer SOPRA l'icona.
        local red = btn:CreateTexture(nil, "OVERLAY", nil, 1)
        red:SetTexture("Interface\\Buttons\\WHITE8x8")
        red:SetVertexColor(RF_HDR_RED[1], RF_HDR_RED[2], RF_HDR_RED[3], RF_HDR_RED[4])
        red:SetAllPoints(tex)
        red:Hide()
        btn._red = red
        btn:SetScript("OnEnter", function(s)
            -- Categoria NON disponibile con questa composizione: resta spenta
            -- anche in hover (non deve sembrare disponibile).
            if s._icon then
                local v = s._nodata and RF_HDR_NODATA or 1
                s._icon:SetVertexColor(v, v, v)
            end
            -- Tooltip CUSTOM (frame, non GameTooltip): deve contenere la lista
            -- dei fornitori su cui si preme e si trascina.
            if s._col then RF:ShowBuffCatTip(s._col, s) end
        end)
        btn:SetScript("OnLeave", function(s)
            if s._icon then
                local v = s._nodata and RF_HDR_NODATA or RF_HDR_NORMAL
                s._icon:SetVertexColor(v, v, v)
            end
            -- Durante un trascinamento il tooltip resta APERTO: e' la
            -- sorgente da cui si e' preso il nome.
            if not RF._assignDrag then RF:HideBuffCatTip() end
        end)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(s, button)
            if not s._col then return end
            if button == "RightButton" then
                -- Destro: toglie l'assegnazione (se c'e').
                if RF:GetBuffAssign(s._col) then
                    RF:SetBuffAssign(s._col, nil)
                    RLSuite.utils:Print(string.format(L["Assignment removed for %s."],
                        s._col.label or s._col.key or "?"))
                end
                return
            end
            RF:WarnBuffCategory(s._col)
        end)
        btn:Hide()
        self._buffHdrBtns[c] = btn
    end
    return btn
end

-- Left-click su un titolo di categoria: raid warning per quella colonna,
-- con l'elenco dei player che mancano del buff (fake inclusi in debug).
-- `/rls debugbuff`: per OGNI colonna stampa chiave, icona di gioco usata e
-- dimensione della region (info deterministiche, nessun test di caricamento:
-- le icone sono texture interne del gioco, si caricano per definizione).
function RF:DiagnoseBuffCatIcons()
    local p = function(t) RLSuite.utils:Print(t) end
    p(L["Buff headers: per-category game icons (no custom files)"])
    local cols = self._matrixColsCache or self:_MatrixCols()
    for c = 1, #cols do
        local btn = self._buffHdrBtns and self._buffHdrBtns[c]
        local col = btn and btn._col or cols[c]
        local tex = btn and btn._icon
        local sz = tex and (tostring(tex:GetWidth()) .. "x" .. tostring(tex:GetHeight())) or "?"
        p(string.format("  %d %s: %s btn=%s size=%s", c,
            tostring(col and col.key or "?"), tostring(self:_BuffHeaderIconPath(col, c)),
            btn and "Y" or "N", sz))
    end
end

-- ------------------------------------------------------------------
-- CHECK BUFF CONSAPEVOLE DI CLASSE E COMPOSIZIONE
-- Il check classico chiedeva il buff a TUTTI i player e segnalava come
-- "mancante" anche chi non puo' riceverlo (Int su un warrior) o chi non
-- puo' averlo perche' in raid nessuno lo fornisce. Qui, per ogni categoria:
--   applicable  chi ne BENEFICIA (col.beneficiaries; vuoto = tutti)
--   coverable   chi PUO' riceverlo: in raid c'e' un fornitore raid-wide,
--               oppure un fornitore party-only (totem) nel SUO party
--   available   almeno un player applicable+coverable esiste
--   satisfied   tutti i coverable hanno l'aura; per scope "single"/"capped"
--               invece il numero di aure deve raggiungere quello atteso
-- ------------------------------------------------------------------

-- La classe di questo membro puo' fornire la categoria?
function RF:_BuffClassProvides(col, class)
    if not (col and class) then return false end
    local provs = col.classes
    for i = 1, #(provs or {}) do
        if provs[i] == class then return true end
    end
    return false
end

-- La classe e' elencata fra i fornitori la cui versione copre SOLO il party?
function RF:_BuffClassPartyOnly(col, class)
    if not (col and class) then return false end
    local party = col.partyProviders
    for i = 1, #(party or {}) do
        if party[i] == class then return true end
    end
    return false
end

-- La categoria interessa questa classe? (beneficiaries assente/vuoto = tutti)
function RF:_BuffApplicable(member, col)
    local ben = col and col.beneficiaries
    if not (ben and #ben > 0) then return true end
    local class = member and member.class
    if not class then return true end
    for i = 1, #ben do
        if ben[i] == class then return true end
    end
    return false
end

-- Contesto di fornitura dati i membri presenti (entries: {member, group}):
--   providerCount   quanti membri possono fornirla
--   hasRaidProvider esiste un fornitore raid-wide (copre chiunque)
--   partyProvider   [gruppo] = true se li' c'e' un fornitore party-only
function RF:_BuffProviderContext(col, entries)
    local ctx = { providerCount = 0, hasRaidProvider = false, partyProvider = {} }
    for _, e in ipairs(entries or {}) do
        local class = e.member and e.member.class
        if self:_BuffClassProvides(col, class) then
            ctx.providerCount = ctx.providerCount + 1
            if self:_BuffClassPartyOnly(col, class) then
                if e.group then ctx.partyProvider[e.group] = true end
            else
                ctx.hasRaidProvider = true
            end
        end
    end
    return ctx
end

-- Questo membro PUO' ricevere la categoria?
function RF:_BuffCoverable(col, ctx, group)
    -- Le colonne di servizio (durability) non hanno fornitori: valgono per tutti.
    if col.kind == "durability" then return true end
    if ctx.hasRaidProvider then return true end
    if group and ctx.partyProvider[group] then return true end
    return false
end

-- Aggregato per colonna: si riempie DURANTE il refresh della matrice, nella
-- stessa passata di UnitBuff che disegna le celle (nessun scan in piu').
function RF:_BuffAggNew(col, entries)
    return {
        col = col,
        ctx = self:_BuffProviderContext(col, entries),
        count = 0,       -- membri con l'aura (qualunque classe)
        applicable = 0,  -- membri che ne beneficiano
        coverable = 0,   -- membri che possono riceverla
        missing = {},    -- nomi dei coverable senza l'aura
        hasByName = nil, -- solo scope "single": nome -> l'ha
    }
end

function RF:_BuffAggAdd(agg, member, group, has)
    if not (agg and member) then return end
    local col = agg.col
    if has then agg.count = agg.count + 1 end
    if col.scope == "single" then
        agg.hasByName = agg.hasByName or {}
        if has then agg.hasByName[member.name or "?"] = true end
    end
    if not self:_BuffApplicable(member, col) then return end
    agg.applicable = agg.applicable + 1
    if not self:_BuffCoverable(col, agg.ctx, group) then return end
    agg.coverable = agg.coverable + 1
    if not has then agg.missing[#agg.missing + 1] = member.name or "?" end
end

-- Dallo stato aggregato allo stato finale della categoria.
function RF:_BuffStatusFromAgg(agg)
    local col = agg.col
    local st = {
        key = col.key, label = col.label or col.key,
        scope = col.scope or "raid",
        kind = col.kind,
        count = agg.count, applicable = agg.applicable, coverable = agg.coverable,
        missing = agg.missing, missingProviders = {},
    }
    -- Disponibile solo se qualcuno puo' DAVVERO riceverla: cosi' una categoria
    -- senza fornitore in raid (o senza beneficiari presenti) si ingrigisce
    -- invece di produrre un muro di "mancante".
    st.available = (agg.coverable > 0)
    if st.scope == "single" then
        -- Focus Magic: tante aure quanti sono i maghi (uno per mago).
        st.expected = math.min(agg.ctx.providerCount, agg.coverable)
        st.satisfied = (st.expected == 0) or (agg.count >= st.expected)
        if not st.satisfied then
            -- Nomi dei maghi SENZA un FM ancora attivo: dal combat log, quindi
            -- solo per i lanci visti (best effort: il conteggio e' la verita').
            local fm = self.fmCasters or {}
            for _, m in ipairs(self:GetRoster()) do
                if self:_BuffClassProvides(col, m.class) then
                    local dest = fm[m.name]
                    local active = dest and dest ~= true and agg.hasByName and agg.hasByName[dest]
                    if not active then
                        st.missingProviders[#st.missingProviders + 1] = m.name or "?"
                    end
                end
            end
        end
    elseif st.scope == "capped" then
        -- Replenishment copre al massimo `cap` player: pretendere l'aura su
        -- tutti i mana user sarebbe un falso allarme.
        st.expected = math.min(col.cap or agg.coverable, agg.coverable)
        st.satisfied = (st.expected == 0) or (agg.count >= st.expected)
    else
        st.expected = agg.coverable
        st.satisfied = (#agg.missing == 0)
    end
    return st
end

-- Stato COMPLETO di una categoria (ricalcolo): lo usano il click sull'header
-- e il tooltip. Il refresh della matrice non passa da qui: aggrega nella sua
-- passata per non raddoppiare gli scan di UnitBuff.
function RF:BuffCoverage(col)
    if not col then return nil end
    local entries = {}
    local groups = self:GetGroupedRoster()
    for g = 1, #groups do
        for s = 1, #groups[g] do
            local m = groups[g][s]
            if m then entries[#entries + 1] = { member = m, group = g } end
        end
    end
    local agg = self:_BuffAggNew(col, entries)
    for _, e in ipairs(entries) do
        local icon, _, _, _, _, has = self:_BuffCellIconFor(e.member, col, e.group)
        if has == nil then has = (icon ~= nil) end
        self:_BuffAggAdd(agg, e.member, e.group, has)
    end
    return self:_BuffStatusFromAgg(agg)
end

-- ============================================================
-- ASSEGNAZIONE DEI BUFF (chi deve dare quale categoria)
--   db.buffAssign = { [keyColonna] = "NomePlayer" }
-- Il tooltip della categoria NON e' piu' il GameTooltip: e' un frame custom
-- con la lista dei fornitori, perche' su quei nomi bisogna poter PREMERE e
-- TRASCINARE fino all'icona. Regole:
--   * non assegnata -> tooltip con "Provider:" e "<nome player>: <nome buff>"
--   * assegnata     -> tooltip con "Assigned to: <nome player>"
--   * trascina (o clicca) un nome del tooltip sull'icona = assegna
--   * click destro sull'icona = togli l'assegnazione
--   * click sinistro (avviso di categoria) = raid warning + whisper
--     all'assegnato, che deve provvedere col buff assegnato
-- ============================================================
function RF:BuffAssignTable()
    if not self.db.buffAssign then self.db.buffAssign = {} end
    return self.db.buffAssign
end

function RF:GetBuffAssign(col)
    local key = col and (col.key or col.label)
    if not key then return nil end
    local name = self:BuffAssignTable()[key]
    if not name or name == "" then return nil end
    return name
end

function RF:SetBuffAssign(col, name)
    local key = col and (col.key or col.label)
    if not key then return false end
    local t = self:BuffAssignTable()
    t[key] = (name and name ~= "") and name or nil
    rfDbg("buff assign: %s -> %s", tostring(key), tostring(t[key]))
    if self._buffCatTip and self._buffCatTip._col == col then
        self:ShowBuffCatTip(col, self._buffCatTip._anchor)
    end
    return true
end

-- "<nome player>: <nome buff>". Il nome del buff e' quello vero di gioco
-- (GetSpellInfo) quando la categoria ha UNA sola classe fornitrice: cosi' non
-- si attribuisce a un mago la spell di un paladino. Altrimenti la sigla della
-- categoria (es. MP5).
function RF:_BuffProviderBuffName(col, member)
    local list = col.spells or {}
    if #list > 0 and col.classes and #col.classes == 1 and GetSpellInfo then
        local n = GetSpellInfo(list[1])
        if n then return n end
    end
    if col.classes and #col.classes > 1 and GetSpellInfo and col.spellNames then
        local n = col.spellNames[member and member.class]
        if n then return n end
    end
    return col.label or col.key or "?"
end

-- Fornitori PRESENTI in raid per quella categoria, in ordine di roster.
function RF:BuffProviders(col)
    local out = {}
    if col and col.kind == "durability" then return out end
    if not (col and col.classes and #col.classes > 0) then return out end
    local groups = self:GetGroupedRoster()
    for g = 1, #groups do
        for s = 1, #groups[g] do
            local m = groups[g][s]
            if m and self:_BuffClassProvides(col, m.class) then
                out[#out + 1] = { member = m, group = g, buff = self:_BuffProviderBuffName(col, m) }
            end
        end
    end
    return out
end

local RF_TIP_ROWS = 10

function RF:_EnsureBuffCatTip()
    if self._buffCatTip then return self._buffCatTip end
    local f = CreateFrame("Frame", "RLSuiteBuffCatTip", self.frame or UIParent)
    f:SetSize(250, 48)
    f:SetFrameStrata("TOOLTIP")
    f:EnableMouse(true)
    RLSuite.utils:WindowBackdrop(f)
    local function line(prev, anchorPt, dy, tmpl)
        local fs = f:CreateFontString(nil, "OVERLAY", tmpl or "GameFontNormalSmall")
        if prev then
            fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, dy or -3)
        else
            fs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
        end
        fs:SetPoint("RIGHT", f, "RIGHT", -8, 0)
        fs:SetJustifyH("LEFT")
        return fs
    end
    f._title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f._title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
    f._title:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    f._title:SetJustifyH("LEFT")
    f._status = line(f._title, nil, -3)
    f._assign = line(f._status)
    f._provLabel = line(f._assign, nil, -5)
    f._rows = {}
    f:Hide()
    self._buffCatTip = f
    return f
end

function RF:_BuffTipRow(i)
    local f = self:_EnsureBuffCatTip()
    local row = f._rows[i]
    if not row then
        row = CreateFrame("Button", nil, f)
        row:SetHeight(14)
        row:SetPoint("LEFT", f, "LEFT", 8, 0)
        row:SetPoint("RIGHT", f, "RIGHT", -8, 0)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints(row)
        fs:SetJustifyH("LEFT")
        row._text = fs
        row:RegisterForClicks("LeftButtonUp")
        -- Premere su un nome lo prende: da qui si trascina sull'icona.
        row:SetScript("OnMouseDown", function(s, button)
            if button ~= "LeftButton" then return end
            local p = s._provider
            if p and p.member then
                RF:_StartAssignDrag(p.member.name, s._col)
            end
        end)
        -- Rilascio: se il cursore e' su un'icona di categoria si assegna li';
        -- altrimenti vale come click (assegna alla categoria del tooltip).
        row:SetScript("OnMouseUp", function(s, button)
            if button ~= "LeftButton" then return end
            RF:_DropAssignDrag(s)
        end)
        row:SetScript("OnEnter", function(s)
            if s._text then s._text:SetTextColor(1, 1, 1) end
        end)
        row:SetScript("OnLeave", function(s)
            if s._text then s._text:SetTextColor(0.85, 0.85, 0.85) end
        end)
        f._rows[i] = row
    end
    return row
end

-- Mostra il tooltip custom della categoria: titolo, stato (lo stesso testo che
-- dava il GameTooltip), assegnazione e lista dei fornitori.
function RF:ShowBuffCatTip(col, anchorBtn)
    if not col then return end
    local f = self:_EnsureBuffCatTip()
    f._col = col
    f._anchor = anchorBtn
    f._title:SetText(col.label or col.key or "")
    f._title:SetTextColor(1, 0.82, 0)

    local st = self:BuffCoverage(col)
    local txt, r, g, b = nil, nil, nil, nil
    if self._BuffStatusText then txt, r, g, b = self:_BuffStatusText(st) end
    f._status:SetText(txt or "")
    if r then f._status:SetTextColor(r, g, b) end

    local assigned = self:GetBuffAssign(col)
    if assigned then
        f._assign:SetText(string.format(L["Assigned to: %s"], assigned))
        f._assign:SetTextColor(0.2, 1, 0.4)
    else
        f._assign:SetText(L["Not assigned"])
        f._assign:SetTextColor(0.7, 0.7, 0.7)
    end

    local provs = self:BuffProviders(col)
    if #provs > 0 then
        f._provLabel:SetText(string.format(L["Providers (%d) - drag a name onto the icon:"], #provs))
    else
        f._provLabel:SetText(L["No provider available"])
    end

    local shown = 0
    for i = 1, #f._rows do f._rows[i]:Hide() end
    for i = 1, math.min(#provs, RF_TIP_ROWS) do
        local p = provs[i]
        local row = self:_BuffTipRow(i)
        row._provider = p
        row._col = col
        row:SetText(row._text)
        row._text:SetText(string.format("%s (%s): %s",
            tostring(p.member.name or "?"), tostring(p.member.class or "?"), tostring(p.buff)))
        row._text:SetTextColor(0.85, 0.85, 0.85)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(56 + (i - 1) * 14))
        row:SetPoint("RIGHT", f, "RIGHT", -8, 0)
        row:Show()
        shown = shown + 1
    end
    if #provs > RF_TIP_ROWS then
        local more = self:_BuffTipRow(RF_TIP_ROWS + 1)
        more._provider = nil
        more._text:SetText(string.format(L["... and %d more"], #provs - RF_TIP_ROWS))
        more._text:SetTextColor(0.7, 0.7, 0.7)
        more:ClearAllPoints()
        more:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(56 + RF_TIP_ROWS * 14))
        more:SetPoint("RIGHT", f, "RIGHT", -8, 0)
        more:Show()
        shown = shown + 1
    end
    f:SetHeight(math.max(70, 62 + shown * 14))

    local a = anchorBtn or f
    f:ClearAllPoints()
    if a and a.GetLeft then
        local top = a.GetTop and a:GetTop()
        local uiph = UIParent and UIParent.GetHeight and UIParent:GetHeight()
        local h = f:GetHeight()
        if type(top) ~= "number" then top = nil end
        if type(uiph) ~= "number" then uiph = nil end
        if type(h) ~= "number" then h = 0 end
        if top and uiph and (top + h + 4) > uiph then
            -- icona troppo in alto: il tooltip scende sotto l'icona
            f:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -2)
        else
            f:SetPoint("BOTTOMLEFT", a, "TOPLEFT", 0, 2)
        end
    else
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
    end
    f:Show()
end

function RF:HideBuffCatTip()
    if self._buffCatTip then self._buffCatTip:Hide() end
end

-- ============================================================
-- Drag del nome (mini-drag dedicato: NON tocca il drag degli slot, che resta
-- intatto). Il "fantasma" col nome segue il cursore; al rilascio si cerca
-- l'icona di categoria sotto il cursore.
-- ============================================================
function RF:_AssignGhost()
    if self._assignGhost then return self._assignGhost end
    local g = CreateFrame("Frame", "RLSuiteBuffAssignGhost", UIParent)
    g:SetSize(140, 16)
    g:SetFrameStrata("TOOLTIP")
    g:EnableMouse(false)
    g:Hide()
    local fs = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints(g)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(1, 0.82, 0)
    g._text = fs
    g:SetScript("OnUpdate", function(s)
        if not GetCursorPosition then return end
        local x, y = GetCursorPosition()
        if not x then return end
        -- GetCursorPosition e' in pixel fisici: si riporta alla scala dell'interfaccia
        local sc = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if not sc or sc == 0 then sc = 1 end
        s:ClearAllPoints()
        s:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / sc) + 12, (y / sc) - 8)
    end)
    self._assignGhost = g
    return g
end

function RF:_StartAssignDrag(name, col)
    if not name or name == "" then return false end
    self._assignDrag = { name = name, col = col }
    local g = self:_AssignGhost()
    g._text:SetText(name)
    g:Show()
    rfDbg("assign drag: %s", tostring(name))
    return true
end

-- Icona di categoria sotto il cursore (hit-test sui rettangoli dei bottoni).
function RF:_BuffHeaderAtCursor()
    if not GetCursorPosition then return nil end
    local x, y = GetCursorPosition()
    if not x then return nil end
    for c, btn in ipairs(self._buffHdrBtns or {}) do
        if btn and btn:IsShown() then
            local l, r = btn:GetLeft(), btn:GetRight()
            local b, t = btn:GetBottom(), btn:GetTop()
            if l and r and b and t and x >= l and x <= r and y >= b and y <= t then
                return btn, c
            end
        end
    end
    return nil
end

-- Chiude il mini-drag: icona sotto il cursore -> assegnazione li'; nessuna
-- icona -> se il rilascio e' sulla riga di partenza (o comunque nel tooltip)
-- vale come click e assegna alla categoria del tooltip.
function RF:_DropAssignDrag(fromRow)
    local drag = self._assignDrag
    self._assignDrag = nil
    if self._assignGhost then self._assignGhost:Hide() end
    if not drag then return false end
    local btn = self:_BuffHeaderAtCursor()
    local col = (btn and btn._col) or drag.col or (fromRow and fromRow._col)
    if not col then return false end
    self:SetBuffAssign(col, drag.name)
    RLSuite.utils:Print(string.format(L["%s assigned to %s."], drag.name, col.label or col.key or "?"))
    return true
end

-- Whisper all'assegnato quando si clicca l'icona della categoria: chi e'
-- assegnato deve provvedere col buff assegnato.
function RF:BuffAssignWhisper(col)
    local name = self:GetBuffAssign(col)
    if not name or name == "" then return false end
    local alerts = self.db.alerts or {}
    local msg = alerts.buffassign
    if not msg or msg == "" then
        msg = string.format(L["Assignment: provide %s for the raid."],
            col.label or col.key or "?")
    end
    msg = string.gsub(msg, "%$name", name)
    RLSuite.utils:Whisper(name, msg)
    rfDbg("assign whisper -> %s: %s", tostring(name), tostring(msg))
    return true
end

-- Icona di intestazione: grigio scuro se la categoria NON e' disponibile con
-- questa composizione; overlay rosso se e' disponibile ma il check non e'
-- soddisfatto ("non usabile"); altrimenti icona normale.
function RF:ApplyBuffHeaderStatus(btn, st)
    if not (btn and btn._icon) then return end
    btn._status = st
    local nodata = (st ~= nil) and (st.available == false)
    local failing = (st ~= nil) and (st.available == true) and (st.satisfied == false)
    btn._nodata = nodata
    if btn._red then
        if failing then btn._red:Show() else btn._red:Hide() end
    end
    if btn._icon.SetDesaturated then btn._icon:SetDesaturated(failing and true or false) end
    -- Il refresh della matrice gira ogni 0,5s: senza questo guard l'icona
    -- tornerebbe a 0.8 sotto il cursore, spegnendo l'hover a ogni tick.
    local v = nodata and RF_HDR_NODATA or RF_HDR_NORMAL
    if (not nodata) and btn.IsMouseOver and btn:IsMouseOver() then v = 1 end
    btn._icon:SetVertexColor(v, v, v)
end

-- Riga di stato per il tooltip dell'header.
function RF:_BuffStatusText(st)
    if not st then return nil end
    if st.available == false then
        return L["Not available in this composition"], 0.6, 0.6, 0.6
    end
    if st.kind == "durability" then
        if st.satisfied then return L["No broken or low durability gear"], 0.2, 1, 0.2 end
        local shown = {}
        for i = 1, math.min(#st.missing, 4) do shown[i] = st.missing[i] end
        local txt = string.format(L["Gear to repair: %d"], #st.missing)
        if #shown > 0 then txt = txt .. ": " .. table.concat(shown, ", ") end
        return txt, 1, 0.35, 0.35
    end
    if st.scope == "single" or st.scope == "capped" then
        local txt = string.format(L["Covered: %d/%d"], st.count, st.expected)
        if st.satisfied then return txt, 0.2, 1, 0.2 end
        return txt, 1, 0.35, 0.35
    end
    if st.satisfied then return L["OK on everyone"], 0.2, 1, 0.2 end
    local shown = {}
    for i = 1, math.min(#st.missing, 4) do shown[i] = st.missing[i] end
    local txt = string.format(L["Missing: %d"], #st.missing)
    if #shown > 0 then txt = txt .. ": " .. table.concat(shown, ", ") end
    return txt, 1, 0.35, 0.35
end

-- Left-click su un titolo di categoria: raid warning per quella colonna.
-- Il messaggio segue il check consapevole della composizione:
--   non disponibile -> lo dice (niente nomi, non e' colpa di nessuno)
--   scope single    -> aure presenti/attese + maghi che non l'hanno dato
--   scope capped    -> coperte/attese
--   altrimenti      -> elenco dei SOLI player che ne beneficiano e possono
--                      riceverlo
function RF:WarnBuffCategory(col)
    if not col then return end
    local st = self:BuffCoverage(col)
    if not st then return end
    local label = st.label
    local msg
    if st.kind == "durability" then
        -- Avviso attrezzatura: elenco di chi ha oggetti rotti (e, per il
        -- proprio pg, anche la percentuale bassa).
        if st.satisfied then
            msg = L["Gear check: everyone is fine"]
        else
            msg = string.format(L["Gear check: repair needed for %s"], table.concat(st.missing, ", "))
        end
    elseif st.available == false then
        msg = string.format(L["Buff check: %s - not available in this composition"], label)
    elseif st.scope == "single" then
        msg = string.format(L["Buff check: %s - %d/%d"], label, st.count, st.expected)
        if #st.missingProviders > 0 then
            msg = msg .. string.format(L[" - mages missing: %s"],
                table.concat(st.missingProviders, ", "))
        end
    elseif st.scope == "capped" then
        msg = string.format(L["Buff check: %s - %d/%d"], label, st.count, st.expected)
    elseif #st.missing == 0 then
        msg = string.format(L["Buff check: %s - OK on everyone"], label)
    else
        msg = string.format(L["Buff check: %s - missing: %s"], label,
            table.concat(st.missing, ", "))
    end
    if #msg > 240 then msg = msg:sub(1, 237) .. "..." end
    if RLSuite.utils and RLSuite.utils.SendChat then
        RLSuite.utils:SendChat(msg, "RAID_WARNING")
    end
    -- Chi e' assegnato a questa categoria riceve anche il whisper: l'avviso
    -- in raid dice cosa manca, il whisper dice a CHI tocca provvedere.
    self:BuffAssignWhisper(col)
end

-- ============================================================
-- FADE PER DISTANZA (barre giocatore)
-- In 3.3.5 l'unica lettura numerica della distanza e' UnitInRange(unit)
-- (party/raid): restituisce inRange, inYards (0-40). Oltre le 40 yard il
-- numero non c'e' piu' -> RF_FAR_YARDS, cioe' "lontanissimo".
-- Soglia e trasparenza si scelgono in Configurazione -> Raid Frame.
-- ============================================================
function RF:UnitDistanceYards(unit)
    if not unit then return nil end
    if unit == "player" then return 0 end
    if UnitInRange then
        local inRange, yards = UnitInRange(unit)
        if yards then return yards end
        if inRange == false then return RF_FAR_YARDS end
    end
    return nil
end

function RF:ApplyDistanceFade(row)
    if not row then return end
    local app = (self.db and self.db.appearance) or {}
    local thr = tonumber(app.distanceFade) or 0
    local alpha = 1
    if thr > 0 then
        local d = self:UnitDistanceYards(row.unit)
        if d and d > thr then alpha = tonumber(app.distanceAlpha) or 0.40 end
    end
    if row._fadeAlpha ~= alpha then
        row._fadeAlpha = alpha
        if row.SetAlpha then row:SetAlpha(alpha) end
    end
end

-- Toggle dal tasto "Raid Buffs": la matrice appare solo se cliccata.
function RF:ToggleBuffMatrix()
    self.buffMatrixOn = not (self.buffMatrixOn == true)
    self:ApplyLayout()
    self:RefreshBuffMatrix()
end

-- Celle-icona LUNGO LA RIGA del player: texture figlie di content (come le
-- icone consumabili), oltre il bordo destro della riga, centrate in altezza.
function RF:_MatrixCell(slot, c)
    slot._buffCells = slot._buffCells or {}
    local tex = slot._buffCells[c]
    if not tex then
        tex = self.content:CreateTexture(nil, "ARTWORK")
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot._buffCells[c] = tex
    end
    return tex
end

function RF:_LayoutMatrixRow(slot, m, y, mCols)
    -- Backdrop UNO PER RIGA (non tutta la finestra): striscia grigia
    -- semi-trasparente dietro le icone di QUESTO player, tra il bordo destro
    -- della barra+cd e la fine dell'area colonne.
    local bg = slot._matrixBg
    if not bg then
        bg = self.content:CreateTexture(nil, "BACKGROUND")
        slot._matrixBg = bg
    end
    local bc = (self.db and self.db.appearance and self.db.appearance.matrixBackdrop) or {}
    bg:SetTexture(bc.r or 0.5, bc.g or 0.5, bc.b or 0.5, bc.a or 0.35)
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", self.content, "TOPLEFT", m.rowWidth + 2, y - 1)
    bg:SetSize(#mCols * m.cellW + 6, m.rowHeight - 2)
    bg:Show()
    for c = 1, #mCols do
        local tex = self:_MatrixCell(slot, c)
        if tex then
            tex:ClearAllPoints()
            tex:SetSize(m.iconSize, m.iconSize)
            tex:SetPoint("TOPLEFT", self.content, "TOPLEFT",
                m.rowWidth + 4 + (c - 1) * m.cellW + (m.cellW - m.iconSize) / 2,
                y - (m.rowHeight - m.iconSize) / 2)
        end
    end
end

-- Riempie la matrice: icona del buff attivo del player per categoria,
-- nascosta quando manca / matrice spenta / riga senza unita' reale.
function RF:RefreshBuffMatrix()
    -- Le letture di durability costano (19 slot x membro): si rifanno ogni
    -- RF_DUR_REFRESH passate, non a ogni tick da 0,5s.
    self._durPass = (self._durPass or 0) + 1
    if self._durPass >= RF_DUR_REFRESH then
        self._durPass = 0
        self._durStamp = (self._durStamp or 0) + 1
    end
    local on = self.buffMatrixOn and self.rows and self.rows[1] ~= nil
    local cols = on and self:_MatrixCols() or nil
    local headersOn = self.rows and self.rows[1] ~= nil
    -- Aggregati per il check consapevole della composizione: si riempiono
    -- nella STESSA passata che disegna le celle (una UnitBuff sola per cella).
    -- I membri sono presi dagli slot dei gruppi: le barre MT/OT non fanno
    -- parte di self.slots, quindi nessun doppio conteggio.
    local aggs
    if on and cols then
        aggs = {}
        local entries = {}
        for _, slot in ipairs(self.slots or {}) do
            if slot.member and slot:IsShown() then
                entries[#entries + 1] = { member = slot.member, group = slot.group }
            end
        end
        for c = 1, #cols do aggs[c] = self:_BuffAggNew(cols[c], entries) end
        -- Debug: le aure dei finti si generano dalla composizione UNA volta
        -- per passata (la firma evita di rifarlo a ogni cella).
        if RLSuite.DebugMode and RLSuite:DebugMode() then self:_DebugRosterBuffSets() end
    end
    for _, slot in ipairs(self.slots or {}) do
        for c = 1, #(slot._buffCells or {}) do
            local tex = slot._buffCells[c]
            local icon, _, tr, tg, tb, has
            if on and slot:IsShown() and slot.member and cols and cols[c] then
                icon, _, tr, tg, tb, has = self:_BuffCellIconFor(slot.member, cols[c], slot.group)
            end
            if icon then
                tex:SetTexture(icon)
                -- Tinta per cella (usata dalla durability per stato); le
                -- categorie di buff restano bianche come prima.
                tex:SetVertexColor(tr or 1, tg or 1, tb or 1)
                tex:Show()
            else
                tex:Hide()
            end
            if aggs and aggs[c] and slot.member and cols and cols[c] and slot:IsShown() then
                if has == nil then has = (icon ~= nil) end
                self:_BuffAggAdd(aggs[c], slot.member, slot.group, has)
            end
        end
    end
    -- Backdrop PER RIGA: visibile solo a matrice accesa, quando la riga
    -- e' visibile e occupata. Nascosto altrimenti (toglie il tasto "Raid
    -- Buffs" solo le icone e queste strisce, MAI l'intestazione).
    for _, slot in ipairs(self.slots or {}) do
        local bg = slot._matrixBg
        if bg then
            if on and slot:IsShown() and slot.member then
                bg:Show()
            else
                bg:Hide()
            end
        end
    end
    -- LA RIGA D'INTESTAZIONE si accende/spegne COL TASTO "Raid Buffs":
    -- stessa visibility della matrice. La zona strip e' RISERVATA SEMPRE
    -- nella griglia fissa (v1.11.62): le icone si mostrano quando c'e' un
    -- roster, ANCHE se G1 e' vuoto. Prima erano agganciate all'header G1 e
    -- con G1 vuoto il check spariva (raid con pochi gruppi usati).
    local stripReady = self.rows and self.rows[1] ~= nil
    for c, btn in ipairs(self._buffHdrBtns or {}) do
        if on and stripReady and RLSuite.raidBuffColumns and self:_MatrixCols()[c] then
            btn:Show()
            -- Stato della categoria (dall'aggregato di questa passata): grigio
            -- se non disponibile con la composizione, rosso se non soddisfatta.
            if aggs and aggs[c] then
                self:ApplyBuffHeaderStatus(btn, self:_BuffStatusFromAgg(aggs[c]))
            end
        else
            btn:Hide()
        end
    end
end

-- Set di spellId per categoria (cache pigra).
function RF:_BuffColSet(col)
    if not col._set then
        col._set = {}
        for _, id in ipairs(col.spells or {}) do
            col._set[id] = true
        end
    end
    return col._set
end

-- ============================================================
-- DEBUG: aure dei player FITTIZI costruite dalla COMPOSIZIONE SIMULATA.
-- Prima erano CASUALI (seme dal nome, ~55% per categoria): un warrior poteva
-- avere Int/Spirit/Focus Magic, un mago l'ATK, e una categoria senza il suo
-- fornitore in raid risultava verde per caso. Ora la tavola segue la comp:
--   * FORNITORI (col.classes): se nessuna di quelle classi e' nel raid la
--     categoria resta VUOTA per tutti (l'intestazione si ingrigisce, esatta-
--     mente come in un raid vero senza quella classe);
--   * DESTINATARI (col.beneficiaries): un Int non compare su un warrior, un
--     ATK non compare su un mago; se la categoria non ha lista = tutti;
--   * scope "single" (Focus Magic) = una aura per MAGO presente, su un caster
--     diverso dal mago (non si lancia su se stesso);
--   * scope "capped" (Replenishment) = ce l'hanno i primi `cap` beneficiari.
-- Le categorie SENZA classi fornitrici (flask, Well Fed) non sono buff di
-- classe ma CONSUMABILI personali: li hanno tutti tranne l'ultimo gruppo,
-- cosi' restano provabili gli avvisi e i whisper dei consumabili mancanti.
-- Tutto DETERMINISTICO: stessa composizione = stessa tavola (una segnalazione
-- si puo' confrontare con la schermata di un altro). Si ricalcola solo quando
-- il roster cambia: la firma e' nome:classe:gruppo di ogni slot.
--
-- Il risultato va in RLSuite.debugBuffs = { [nome] = { [spellId] = true },
-- __sig = firma } (Core lo azzera quando cambia la debug mode o il roster).
-- ============================================================
function RF:_DebugRosterBuffSets()
    if not (RLSuite.DebugMode and RLSuite:DebugMode()) then return {} end
    local roster = RLSuite:DebugRoster()
    local parts = {}
    for _, m in ipairs(roster) do
        parts[#parts + 1] = tostring(m.name) .. ":" .. tostring(m.class) ..
            ":" .. tostring(m.subgroup or 0)
    end
    local sig = table.concat(parts, ",")
    if RLSuite.debugBuffs and RLSuite.debugBuffs.__sig == sig then
        return RLSuite.debugBuffs
    end

    local sets = { __sig = sig }
    for _, m in ipairs(roster) do sets[m.name] = {} end
    local cols = RLSuite.raidBuffColumns or {}

    for _, col in ipairs(cols) do
        if col.kind ~= "durability" then
        local providers = 0
        for _, m in ipairs(roster) do
            if self:_BuffClassProvides(col, m.class) then providers = providers + 1 end
        end
        local personal = (#(col.classes or {}) == 0)
        if personal then
            -- Consumabili: id della famiglia giusta dal buffData (flask o
            -- Well Fed). Li hanno tutti TRANNE l'ULTIMO GRUPPO con membri
            -- ("i ritardatari"): cosi' restano provabili gli avvisi e i
            -- whisper dei consumabili mancanti anche in debug. Con un raid
            -- pieno l'ultimo gruppo e' il 5.
            local lastGroup = 1
            for _, m in ipairs(roster) do
                local g = m.subgroup or 1
                if g > lastGroup then lastGroup = g end
            end
            local ids
            if col.key == "wellfed" then
                ids = RLSuite.buffData and RLSuite.buffData.food
            else
                ids = RLSuite.buffData and RLSuite.buffData.flask
            end
            for _, m in ipairs(roster) do
                if ids and (m.subgroup or 1) < lastGroup then
                    for _, id in ipairs(ids) do sets[m.name][id] = true end
                end
            end
        elseif providers > 0 then
            local targets = {}
            for _, m in ipairs(roster) do
                if self:_BuffApplicable(m, col) then targets[#targets + 1] = m end
            end
            local id = (col.spells or {})[1]
            if id and #targets > 0 then
                local scope = col.scope or "raid"
                if scope == "single" then
                    local pool = {}
                    for _, m in ipairs(targets) do
                        if not self:_BuffClassProvides(col, m.class) then
                            pool[#pool + 1] = m
                        end
                    end
                    if #pool == 0 then pool = targets end
                    for i = 1, providers do
                        local t = pool[((i - 1) % #pool) + 1]
                        sets[t.name][id] = true
                    end
                elseif scope == "capped" then
                    local cap = col.cap or #targets
                    if cap > #targets then cap = #targets end
                    for i = 1, cap do sets[targets[i].name][id] = true end
                else
                    for _, m in ipairs(targets) do sets[m.name][id] = true end
                end
            end
        end
        -- providers == 0 e categoria non personale: nessuna classe in raid la
        -- fornisce -> nessuno ha l'aura (header grigio). Nessuna azione.
        end   -- fine if col.kind ~= "durability"
    end

    RLSuite.debugBuffs = sets
    return sets
end

-- Set del singolo finto. La costruzione vera la fa _DebugRosterBuffSets
-- (una volta per passata di RefreshBuffMatrix): qui e' solo una lettura.
function RF:_DebugMemberBuffSet(member)
    if not (RLSuite.DebugMode and RLSuite:DebugMode()) or not member then return {} end
    local sets = RLSuite.debugBuffs
    if not (sets and sets[member.name]) then sets = self:_DebugRosterBuffSets() end
    return sets[member.name] or {}
end

-- ============================================================
-- DURABILITY (colonna "Dur" della matrice Raid Buffs)
-- In 3.3.5 GetInventoryItemBroken(unit, slot) funziona su QUALSIASI unit:
-- quindi "rotto" si vede per tutti. La percentuale, invece, si legge solo
-- sul proprio pg (GetInventoryItemDurability non prende l'unita'): per gli
-- altri la cella si colora in base a "nessun oggetto rotto". In debug il
-- roster e' finto: l'ULTIMO GRUPPO con membri ha attrezzatura rotta, cosi'
-- avviso e tooltip restano provabili come per le categorie di buff.
-- ============================================================
function RF:_LastMemberGroup()
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        local last = 1
        for _, m in ipairs(RLSuite:DebugRoster()) do
            local g = m.subgroup or 1
            if g > last then last = g end
        end
        return last
    end
    -- Fuori dal debug la simulazione non serve (i membri non sono fake).
    return 0
end

function RF:MemberDurability(member, group)
    if not member then return { state = "unknown", broken = 0 } end
    self._durCache = self._durCache or {}
    local key = member.name or member.unit or "?"
    local stamp = self._durStamp or 0
    local cached = self._durCache[key]
    if cached and cached.stamp == stamp then return cached end

    local broken, pct, known = 0, nil, true
    if member.fake and RLSuite.DebugMode and RLSuite:DebugMode() then
        local g = group or member.subgroup or 1
        if g >= self:_LastMemberGroup() then broken = 1 end
        pct = 100
    else
        local unit = member.unit
        if unit and GetInventoryItemBroken then
            for i = 1, #RF_DUR_SLOTS do
                local slot = RF_DUR_SLOTS[i]
                local link = GetInventoryItemLink and GetInventoryItemLink(unit, slot)
                if link and GetInventoryItemBroken(unit, slot) then
                    broken = broken + 1
                end
            end
        else
            known = false
        end
        if unit == "player" and GetInventoryItemDurability then
            for i = 1, #RF_DUR_SLOTS do
                local cur, max = GetInventoryItemDurability(RF_DUR_SLOTS[i])
                if cur and max and max > 0 then
                    local p = cur / max * 100
                    if not pct or p < pct then pct = p end
                end
            end
        end
    end

    local state = "ok"
    if not known then
        state = "unknown"
    elseif broken > 0 then
        state = "broken"
    elseif pct and pct < RF_DUR_ALERT_PCT then
        state = "low"
    end
    local e = { state = state, broken = broken, pct = pct, known = known, stamp = stamp }
    self._durCache[key] = e
    return e
end

-- La cella e' "a posto" se non c'e' niente di rotto e la percentuale (quando
-- nota) e' sopra la soglia. Ignota = a posto: non si accusa nessuno.
function RF:_DurCellOk(st)
    if not st then return true end
    if st.broken and st.broken > 0 then return false end
    if st.pct and st.pct < RF_DUR_ALERT_PCT then return false end
    return true
end

function RF:_DurColor(st)
    if not st or st.state == "unknown" then return 0.55, 0.55, 0.55 end
    if st.state == "broken" then return 1, 0.15, 0.15 end
    if st.state == "low" then return 1, 0.75, 0.15 end
    return 0.2, 1, 0.2
end

function RF:_DurText(st)
    if not st or st.state == "unknown" then return L["no data"], 0.6, 0.6, 0.6 end
    if st.broken and st.broken > 0 then
        return string.format(L["%d broken item(s)"], st.broken), 1, 0.35, 0.35
    end
    if st.pct then
        if st.pct < RF_DUR_ALERT_PCT then
            return string.format(L["%d%% durability"], st.pct), 1, 0.75, 0.15
        end
        return string.format(L["%d%% durability"], st.pct), 0.2, 1, 0.2
    end
    return L["no broken items"], 0.2, 1, 0.2
end

-- Icona della cella per un MEMBER: fake in debug -> set simulato (per
-- spellId, tessera della spell reale); altrimenti -> scan aure reale.
function RF:_BuffCellIconFor(member, col, group)
    if not (member and col) then return nil end
    if col.kind == "durability" then
        -- Colonna di servizio: icona dell'equip, tinta dallo stato, e "has"
        -- (per l'aggregato dell'intestazione) = attrezzatura a posto.
        local st = self:MemberDurability(member, group)
        local r, g, b = self:_DurColor(st)
        return col.icon, nil, r, g, b, self:_DurCellOk(st)
    end
    if member.fake and RLSuite.DebugMode and RLSuite:DebugMode() then
        local set = self:_DebugMemberBuffSet(member)
        if col.byNameSpell then
            -- "Well Fed": nel gioco si matcha il NOME dell'aura (un id per
            -- ogni cibo); qui basta un id qualsiasi della famiglia food.
            local food = (RLSuite.buffData and RLSuite.buffData.food) or {}
            for _, id in ipairs(food) do
                if set[id] then return col.icon, id end
            end
            return nil
        end
        for _, id in ipairs(col.spells or {}) do
            if set[id] then
                local tex = GetSpellTexture and GetSpellTexture(id)
                return tex or col.icon, id
            end
        end
        return nil
    end
    return self:_BuffCellIcon(member.unit, col)
end

-- Icona del buff ATTIVO del player che copre la categoria (nil se nessuno).
-- Match per spellId (set) oppure per nome aura (byNameSpell -> locale-safe,
-- copre tutte le varianti, es. Well Fed). Icona = texture della spell reale
-- trovata; per byName si usa l'icona fissa della categoria.
function RF:_BuffCellIcon(unit, col)
    if not (unit and col and UnitBuff) then return nil end
    local set = self:_BuffColSet(col)
    local wantName
    if col.byNameSpell and GetSpellInfo then
        wantName = GetSpellInfo(col.byNameSpell)
    end
    for i = 1, 40 do
        local bname, _, _, _, _, _, _, _, _, _, bid = UnitBuff(unit, i)
        if not bname then return nil end
        if bid and set[bid] then
            local tex = GetSpellTexture and GetSpellTexture(bid)
            return tex or col.icon, bid
        end
        if wantName and bname == wantName then
            return col.icon, bid
        end
    end
    return nil
end


