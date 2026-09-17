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

-- Drop-target outline for empty slots (pre-boss only). Transparent fill,
-- subtle border: it is a placeholder, not a HUD backdrop.
local RF_EMPTY_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

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


end

function RF:RegisterEvents()
    self:RegisterEvent("RAID_ROSTER_UPDATE", function() RF:Rebuild() end)
    self:RegisterEvent("UNIT_HEALTH", "OnUnitEvent")
    self:RegisterEvent("UNIT_MANA", "OnUnitEvent")
    self:RegisterEvent("UNIT_AURA", "OnUnitEvent")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")
    -- refresh periodico (prima un frame OnUpdate con accumulo a 0.5s)
    self:ScheduleRepeatingTimer("UpdateAll", 0.5)
end

function RF:OnUnitEvent(event, unit)
    self:UpdateUnit(unit)
end

function RF:OnCombatLog(event, ...)
    -- 3.3.5: timestamp, subEvent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, ...
    local _, subEvent, _, sourceName, _, _, _, _, spellId = ...
    if subEvent == "SPELL_CAST_SUCCESS" then
        self:OnSpellCast(sourceName, spellId)
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
    local barHeight = app.barHeight or 20
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
    -- Area della colonna matrice SEMPRE riservata (quando c'e' un roster):
    -- la riga d'intestazione delle categorie e' PERMANENTE (fuori dal
    -- pannello toggle): il tasto "Raid Buffs" accende/spegne solo le icone.
    local mwx = 0
    if self.rows and self.rows[1] then
        mwx = #self:_MatrixCols() * cellW + 10
    end
    -- Layout per row: [flask][food] ... [HP bar = barWidth] ... [up to 4 CDs]
    local leftArea = 4 + 2 * iconSize + 4
    local cdReserve = 4 * iconSize + 3 * 2 + 4
    local rowWidth = leftArea + barWidth + cdReserve + 4
    local W = rowWidth + abw + gap + mwx
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
    -- Bottone "Raid Buffs": stessa riga dell'header Tanks, bordo DESTRO di
    -- tutta l'elemento (barra + cd). Apre/chiude il pannello matrice.
    local btn = CreateFrame("Button", "RLSuiteRaidBuffsBtn", self.content)
    btn:SetSize(RF_BP_BTN_W, RF_HEADER_H)
    btn:EnableMouse(true)
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
            if button == "LeftButton" and RF:IsDragEnabled() and self2.member and not self2.isTank then
                -- SHIFT+sinistro = drag player MANUALE: source + mostra vuoti.
                RF._rfDragSource = self2
                self2._manualDrag = true
                RF:RefreshDropTargets()
                RF:_ArmManualDragWatchdog()
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
            local src = RF._rfDragSource
            RF._rfDragSource = nil
            if src then src._manualDrag = nil end
            if src and src.member then
                local t = RF:SlotAtCursor()
                if t and t ~= src then
                    RF:MoveSlot(src, t)
                end
            end
            RF:RefreshDropTargets()
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
        local tag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tag:SetPoint("LEFT", row, "LEFT", 8, 0)
        tag:SetText(tankTag)
        tag:SetTextColor(1, 0.82, 0)
        row.tankTag = tag
    else
        row.flaskIcon = self:MakeConsumableIcon(row, "flask")
        row.foodIcon = self:MakeConsumableIcon(row, "food")
    end

    -- HP bar (name + % inside), fill = HP%, color = class color.
    local bar = CreateFrame("StatusBar", nil, row)
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
    row.cdIcons = {}
    for j = 1, RF_MAX_CDS do
        local cd = row:CreateTexture(nil, "OVERLAY")
        cd:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local timer = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timer:SetPoint("CENTER", cd, "CENTER", 0, 0)
        timer:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
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
                cd.timer:SetFont(fontFile, 8, flags)
            end
        end
    end
    for j, cd in ipairs(slot.cdIcons or {}) do
        cd:ClearAllPoints()
        cd:SetSize(iconSize, iconSize)
        cd:SetPoint("LEFT", slot.bar, "RIGHT", 4 + (j - 1) * (iconSize + 2), 0)
    end
end

function RF:ApplySlotCDs(slot, class)
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

    if slot._cdClass ~= member.class then
        self:ApplySlotCDs(slot, member.class)
    end

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
    end
    return target
end

-- Mostra/nasconde i blocchi vuoti dei gruppi e gli header dei gruppi
-- vuoti: visibili SOLO in pre-boss mentre un drag e' attivo (servono come
-- drop target); altrimenti l'HUD resta denso (solo player + header pieni).
function RF:RefreshDropTargets()
    local dragging = self:IsDragEnabled() and self._rfDragSource ~= nil
    for g = 1, RF_GROUPS do
        local anyMember = false
        for s = 1, RF_PER_GROUP do
            local slot = self.slots and self.slots[(g - 1) * RF_PER_GROUP + s]
            if slot then
                if slot.member then
                    anyMember = true
                elseif dragging then
                    slot:SetBackdrop(RF_EMPTY_BACKDROP)
                    slot:SetBackdropColor(0, 0, 0, 0)
                    slot:SetBackdropBorderColor(0.32, 0.32, 0.36, 0.9)
                    slot:Show()
                else
                    slot:SetBackdrop(nil)
                    slot:Hide()
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
        self:ClearSlot(slot)
        slot:SetBackdrop(RF_EMPTY_BACKDROP)
        slot:SetBackdropColor(0, 0, 0, 0)
        slot:SetBackdropBorderColor(0.32, 0.32, 0.36, 0.9)
        slot:Show()
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

    self.rows = {}
    for g = 1, RF_GROUPS do
        for s = 1, RF_PER_GROUP do
            local slot = self.slots[(g - 1) * RF_PER_GROUP + s]
            local member = groups[g][s]
            if member then
                self:FillSlot(slot, member)
                self.rows[#self.rows + 1] = slot
            else
                self:ClearSlot(slot)
            end
        end
    end

    self:RebuildTanks()
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
    for _, row in ipairs(self.rows) do
        self:UpdateRow(row)
    end
    for _, t in ipairs(self.tankSlots or {}) do
        self:UpdateRow(t)
    end
    self:RefreshBuffMatrix()
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
        self:SetConsumable(row.flaskIcon, showFlask and "missing" or "off")
        self:SetConsumable(row.foodIcon, showFood and "missing" or "off")
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
function RF:RowPlainClick(row, button)
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
        buff = L["Hey $name, you're missing some raid buffs!"],
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

-- Players can be rearranged only in pre-boss phase (like the InviteEngine
-- raid group panel is used while organizing the raid).
function RF:IsDragEnabled()
    return (RLSuite.context or "preraid") == "preboss"
end

function RF:UpdateDragState()
    -- Drag delle righe = MANUALE (nessun RegisterForDrag, manco per fase):
    -- le righe restano SEMPRE con mouse attivo e click liberi; il drag del
    -- player parte su Shift+down in pre-boss (OnMouseDown → _rfDragSource).
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
            local src = RF._rfDragSource
            RF._rfDragSource = nil
            if src then src._manualDrag = nil end
            if src and src.member then
                local t = RF:SlotAtCursor()
                if t and t ~= src then
                    RF:MoveSlot(src, t)
                end
            end
            RF:RefreshDropTargets()
        end
    end)
end

-- Slot under the mouse cursor (nil if none). Mirrors GroupMaking's
-- WlSlotAtCursor: computes the target from the cursor coordinates because
-- OnReceiveDrag is not always delivered on nested frames.
function RF:SlotAtCursor()
    if not GetCursorPosition then return nil end
    local x, y = GetCursorPosition()
    if not x or not y then return nil end
    for _, slot in ipairs(self.slots or {}) do
        if slot and slot.IsShown and slot:IsShown() then
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
            if left and right and bottom and top
                and cx >= left and cx <= right and cy >= bottom and cy <= top then
                return slot
            end
        end
    end
    return nil
end

-- Reorganizes the groups by dragging a player between slots. src/dst are
-- the two slot frames (source and destination). Empty destination = move,
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
    if not src.raidIndex then return end
    if dst.member and dst.raidIndex then
        -- Swap: SwapRaidSubgroup exchanges the two players.
        pcall(SwapRaidSubgroup, src.raidIndex, dst.raidIndex)
    else
        -- Move: SetRaidSubgroup moves the player to the target group.
        pcall(SetRaidSubgroup, src.raidIndex, dst.group)
    end
end

-- Reorders the simulated roster in debug: swaps two members (occupied slot)
-- or moves a member exactly into the empty destination slot. The slots are
-- SPARSE, so a move leaves a hole in the source slot (shown by both the
-- InviteEngine Raid Group panel and this HUD).
function RF:MoveSlotDebug(src, dst)
    local slots = RLSuite:DebugRaidSlots()
    local srcMember = slots[src.slot]
    local dstMember = slots[dst.slot]
    if not srcMember then return end

    if dstMember then
        slots[src.slot], slots[dst.slot] = dstMember, srcMember
    else
        slots[dst.slot] = srcMember
        slots[src.slot] = nil
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
    self.frame:SetScale(db.scale or 1)
    -- Trasparenza complessiva dell'HUD (Config -> Raid Frame -> Layout).
    self.frame:SetAlpha(db.alpha or 1)

    -- Pack group headers + visible slots vertically (Tanks, G1..G6).
    local y = 0
    local shown = false
    -- MATRICE "Raid Buffs" attiva? Riga d'intestazione IN CIMA con i nomi
    -- sintetici delle categorie, poi il resto (Tanks compreso) scende.
    local matrixOn = self.buffMatrixOn and self.rows and self.rows[1] ~= nil
    -- La RIGA D'INTESTAZIONE e' PERMANENTE: fuori dal pannello toggle,
    -- visibile INDIPENDENTEMENTE dal tasto "Raid Buffs" finche' c'e' un
    -- roster. Il tasto accende/spegne SOLO le icone dei player.
    local headersOn = self.rows and self.rows[1] ~= nil
    local mCols = headersOn and self:_MatrixCols() or nil
    if headersOn then
        -- Testata a ICONE (BCI_<c-1>.tga): strip sottile alta cellW+4 px sopra
        -- le colonne, allineata 1:1 col passo delle colonne.
        for c, col in ipairs(mCols) do
            local btn = self:_MatrixHeaderBtn(c)
            btn._col = col
            -- Icona = la custom dell'utente: media\BUFFCATICONS\BCI_<c-1>.tga.
            -- UNA SetTexture diretta: niente blp, niente fallback, niente detection.
            btn._icon:SetTexture(self:_BuffCatIconPath(c))
            btn._icon:ClearAllPoints()
            btn._icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn._icon:SetSize(m.cellW, m.cellW) -- size = iconSize + iconSpacing, FISSO
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
                m.rowWidth + 4 + (c - 1) * m.cellW, -1)
            btn:SetSize(m.cellW, m.cellW + 4)
            btn:Show() -- SEMPRE VISIBILE: mai nascosta finche' c'e' un roster
        end
        y = y - (m.cellW + 4)
    end

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
    -- GRUPPO TANKS sopra G1: header + barre MT/OT (sempre 2, piene o vuote).
    if self.tankHeader and self.tankHeader:IsShown() then
        self.tankHeader:ClearAllPoints()
        self.tankHeader:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, y)
        self.tankHeader:SetWidth(m.rowWidth)
        local tankHdrY = y
        y = y - m.groupHeaderH
        for ti = 1, RF_TANK_COUNT do
            local t = self.tankSlots and self.tankSlots[ti]
            if t then
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
                self:LayoutSlotGeometry(t, m)
                y = y - m.rowHeight - m.rowSpacing
            end
        end
        y = y - m.groupSpacing
        shown = true
        -- Bottone "Raid Buffs": stessa riga dell'header Tanks, a DESTRA di
        -- tutta l'elemento (fine barra + cd = bordo destro della riga).
        if self.buffPanelBtn then
            self.buffPanelBtn:ClearAllPoints()
            self.buffPanelBtn:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, tankHdrY)
            self.buffPanelBtn:Show()
        end
    elseif self.buffPanelBtn then
        self.buffPanelBtn:Hide()
    end
    for g = 1, RF_GROUPS do
        local hdr = self.groupHeaders and self.groupHeaders[g]
        local hdrShown = hdr ~= nil and hdr:IsShown()
        if hdrShown then
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, y)
            hdr:SetWidth(m.rowWidth)
            y = y - m.groupHeaderH
            shown = true
        end
        local anySlot = false
        for s = 1, RF_PER_GROUP do
            local slot = self.slots and self.slots[(g - 1) * RF_PER_GROUP + s]
            if slot and slot:IsShown() then
                slot:ClearAllPoints()
                slot:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
                self:LayoutSlotGeometry(slot, m)
                if matrixOn and slot.member then
                    self:_LayoutMatrixRow(slot, m, y, mCols)
                end
                y = y - m.rowHeight - m.rowSpacing
                anySlot = true
                shown = true
            end
        end
        if g < RF_GROUPS and (hdrShown or anySlot) then
            y = y - m.groupSpacing
        end
    end
    local rowsH = shown and -y or 0

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
        tex:SetVertexColor(0.8, 0.8, 0.8) -- "spento"; hover accende a piena luce
        btn._icon = tex
        btn:SetScript("OnEnter", function(s)
            if s._icon then s._icon:SetVertexColor(1, 1, 1) end
            if GameTooltip and GameTooltip.SetOwner and s._col then
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(s._col.label or s._col.key or "")
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(s)
            if s._icon then s._icon:SetVertexColor(0.8, 0.8, 0.8) end
            if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
        end)
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("OnClick", function(s)
            if s._col then RF:WarnBuffCategory(s._col) end
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
            tostring(col and col.key or "?"), tostring(self:_BuffCatIconPath(c)),
            btn and "Y" or "N", sz))
    end
end

function RF:WarnBuffCategory(col)
    if not col then return end
    local label = col.label or col.key or "?"
    local missing = {}
    for _, member in ipairs(self:GetRoster()) do
        if member.unit or member.fake then
            if not self:_BuffCellIconFor(member, col) then
                missing[#missing + 1] = member.name or "?"
            end
        end
    end
    local msg
    if #missing == 0 then
        msg = string.format(L["Buff check: %s - OK on everyone"], label)
    else
        msg = string.format(L["Buff check: %s - missing: %s"], label, table.concat(missing, ", "))
    end
    if #msg > 240 then msg = msg:sub(1, 237) .. "..." end
    if RLSuite.utils and RLSuite.utils.SendChat then
        RLSuite.utils:SendChat(msg, "RAID_WARNING")
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
    local on = self.buffMatrixOn and self.rows and self.rows[1] ~= nil
    local cols = on and self:_MatrixCols() or nil
    local headersOn = self.rows and self.rows[1] ~= nil
    for _, slot in ipairs(self.slots or {}) do
        for c = 1, #(slot._buffCells or {}) do
            local tex = slot._buffCells[c]
            local icon
            if on and slot:IsShown() and slot.member and cols and cols[c] then
                icon = self:_BuffCellIconFor(slot.member, cols[c])
            end
            if icon then
                tex:SetTexture(icon)
                tex:Show()
            else
                tex:Hide()
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
    -- L'INTESTAZIONE e' PERMANENTE: fuori dal pannello, visibile
    -- INDIPENDENTEMENTE dal tasto "Raid Buffs" finche' c'e' un roster.
    for c, btn in ipairs(self._buffHdrBtns or {}) do
        if headersOn and RLSuite.raidBuffColumns and self:_MatrixCols()[c] then
            btn:Show()
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

-- DEBUG: aure simulati dei player FITTIZI (le persone invitate "ricevono
-- buff casuali"). Set stabile in sessione: seme dal nome (LCG), per OGNI
-- categoria ~55% di possibilita' di averne uno, spell scelta a caso.
function RF:_DebugMemberBuffSet(name)
    if not (RLSuite.DebugMode and RLSuite:DebugMode()) or not name then return {} end
    RLSuite.debugBuffs = RLSuite.debugBuffs or {}
    local set = RLSuite.debugBuffs[name]
    if set then return set end
    set = {}
    local seed = 0
    for i = 1, #name do
        seed = (seed * 31 + name:byte(i)) % 2147483647
    end
    local function rnd()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end
    for _, col in ipairs(RLSuite.raidBuffColumns or {}) do
        local sp = col.spells
        if sp and #sp > 0 and rnd() < 0.55 then
            set[sp[math.floor(rnd() * #sp) + 1]] = true
        end
    end
    RLSuite.debugBuffs[name] = set
    return set
end

-- Icona della cella per un MEMBER: fake in debug -> set simulato (per
-- spellId, tessera della spell reale); altrimenti -> scan aure reale.
function RF:_BuffCellIconFor(member, col)
    if not (member and col) then return nil end
    if member.fake and RLSuite.DebugMode and RLSuite:DebugMode() then
        local set = self:_DebugMemberBuffSet(member.name)
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


