-- ============================================================
-- RLSuite - RaidProfile Module (Main Window)
-- ============================================================

RLSuite.mainWindow = {}
local MW = RLSuite.mainWindow

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

-- MISURE DELLA BARRETTA IN ALTO (unico posto): alzandola e ingrandendo
-- l'icona di fase, la larghezza della barretta cresce da sola (e' la somma
-- dei suoi elementi) e il nome della fase si sposta di conseguenza.
local TITLE_BAR_H = 26     -- altezza della barretta di Raid Control
local PHASE_ICON = 22      -- icona di fase (era 16: "allarga la barra e ingrandisci l'icona")
local PHASE_GAP = 6        -- distacco fra icona e nome della fase

function MW:Init()
    self:CreateFrame()
    self:RegisterAllWindows()
    self:SyncVisibilityWithRaidFrame()
end

function MW:Toggle()
    -- Visibilita' della raid control bar vincolata al Raid Frame.
    -- Toggle comanda l'apertura/chiusura del pannello matrice tasti sotto la barra.
    if not self.frame then return end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
    if self._updateArrowDir then self:_updateArrowDir() end
    if RLSuite.SyncDebugPanel then RLSuite:SyncDebugPanel() end
    local rf = RLSuite.raidFrame
    if rf and rf.ApplyLayout then rf:ApplyLayout() end
end

function MW:SyncVisibilityWithRaidFrame()
    local rf = RLSuite.raidFrame
    local rfShown = rf and rf.frame and rf.frame:IsShown()

    -- REGOLA ASSOLUTA: se il Raid Frame non è a schermo,
    -- la Raid Control bar e il suo pannello NON DEVONO ESISTERE a schermo.
    local show = rfShown and true or false

    if self.titleBar then
        if show then
            self.titleBar:Show()
            if self.phaseBtn then self.phaseBtn:Show() end
            if self.phaseText then self.phaseText:Show() end
        else
            self.titleBar:Hide()
            if self.phaseBtn then self.phaseBtn:Hide() end
            if self.phaseText then self.phaseText:Hide() end
            if self.frame then self.frame:Hide() end
        end
    end
    if self._updateArrowDir then self:_updateArrowDir() end
    if RLSuite.SyncDebugPanel then
        RLSuite:SyncDebugPanel()
    end
end

function MW:ShowTab(key)
    if key == "config" then
        if RLSuite.config and RLSuite.config.Toggle then
            RLSuite.config:Toggle()
        end
        return
    end
    if not self.frame then return end
    self.frame:Show()
    self:SelectTab(key)
end

function MW:OnTabClick(key)
    if not self.frame then return end
    -- Il tasto Macrobar mostra/nasconde l'HUD (non apre una finestra tab).
    if key == "macro" then
        if RLSuite.macrobar and RLSuite.macrobar.Toggle then
            RLSuite.macrobar:Toggle()
        end
        self:RefreshTabHighlights()
        return
    end

    if self:IsTabOpen(key) then
        self:CloseOneTab(key)
        return
    end
    self.frame:Show()
    self:SelectTab(key)
end

function MW:CloseTab()
    -- SOLO reset dello stato tab: MAI nascondere le altre finestre.
    -- La freccia sulla barra, la X e /rls aprono e chiudono la main window
    -- senza toccare le finestre dei moduli (in fight si chiude il pannello
    -- senza chiudere tutte le finestre).
    self.currentTab = nil
    self:RefreshTabHighlights()
end

-- Una finestra e' "aperta" quando il suo pannello e' visibile.
function MW:IsTabOpen(key)
    local pane = self:PaneForTab(key)
    return pane ~= nil and pane:IsShown()
end

-- Chiude una singola finestra e aggiorna l'evidenziazione del suo tab.
function MW:CloseOneTab(key)
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    local pane = self:PaneForTab(key)
    if pane then pane:Hide() end
    if self.currentTab == key then self.currentTab = nil end
    self:UpdateTabHighlight(key)
end

-- I tab restano bistabili (click = apri/chiudi la finestra) ma non
-- vengono piu' illuminati quando la finestra e' aperta: il bottone torna
-- al suo aspetto normale (evidenziato solo al passaggio del mouse).
function MW:UpdateTabHighlight(key)
    local tab = self.tabs and self.tabs[key]
    if not tab then return end
    if tab.UnlockHighlight then
        tab:UnlockHighlight()
    end
end

function MW:RefreshTabHighlights()
    for _, def in ipairs(self.tabDefs or {}) do
        self:UpdateTabHighlight(def.key)
    end
end

-- Offset a cascata per le finestre senza posizione salvata: cosi'
-- aprendone piu' d'una non si sovrappongono tutte nello stesso punto.
function MW:DefaultCascadeOffset(ignoreKey)
    local ALL_KEYS = { "group", "raidframe", "ms", "loot" }
    local n = 0
    for _, k in ipairs(ALL_KEYS) do
        if k ~= ignoreKey and self:IsTabOpen(k) then
            n = n + 1
        end
    end
    local m = n % 6
    return m * 26, -(m * 26)
end

function MW:CreateFrame()
    local parentFrame = (RLSuite.raidFrame and RLSuite.raidFrame.frame) or UIParent
    local f = CreateFrame("Frame", "RLSuiteMainWindow", parentFrame)
    f:SetSize(240, 150)
    f:SetFrameStrata("HIGH")
    -- NIENTE drag: la barra e' ANCORATA (bordo alto dello schermo, a una
    -- distanza dal lato destro pari alla larghezza del Raid Frame). La
    -- posizione la impone ApplyLayout a ogni ricalcolo; restano skin e
    -- "click to front" come per le altre finestre.
    RLSuite.utils:MakeClickToFront(f)
    RLSuite.utils:ClampWindow(f)
    f:Hide()
    f._noOuterBorder = true
    self.frame = f
    RLSuite.utils:SkinFrame(f)
    RLSuite.utils:ClampWindow(f)

    -- === Barretta titolo (26px) SOPRA la main bar =============
    -- Eredita la larghezza della main bar (anchor a tutti e due gli
    -- angoli). Figlia di parentFrame (Raid Frame) così se il Raid Frame
    -- è nascosto, il motore di WoW nasconde automaticamente la barra!
    local tb = CreateFrame("Frame", "RLSuiteMainTitleBar", parentFrame)
    -- ALTEZZA ALZATA (era 20px): la barretta di Raid Control aveva i tasti
    -- schiacciati sul bordo. Icona di fase e X restano centrate, il tasto
    -- "Raid Control" cresce con lei.
    tb:SetHeight(TITLE_BAR_H)
    -- gap 2px: barretta STACCATA dalla main bar (non incollata)
    tb:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    tb:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 2)
    tb:SetFrameStrata(f:GetFrameStrata() or "HIGH")
    tb:EnableMouse(true)
    tb:Hide()
    self.titleBar = tb

    -- HARD SAFETY GUARD: Se per qualunque motivo esterno o chiamata di layout
    -- qualcuno chiama :Show() sulla barretta mentre il Raid Frame NON è visibile,
    -- intercettiamo OnShow e la richiudiamo all'istante.
    tb:SetScript("OnShow", function(this)
        local rf = RLSuite.raidFrame
        local rfShown = rf and rf.frame and rf.frame:IsShown()
        if not rfShown then
            this:Hide()
        end
    end)
    -- SOLO skin: la barretta NON si trascina piu' (niente drag, niente
    -- posizione salvata). La barra e' ANCORATA al bordo alto dello schermo e
    -- la sua posizione la calcola ApplyLayout: un drag la farebbe solo
    -- "staccare" dal posto in cui deve stare. Niente Tooltip/Dialog border
    -- Blizzard: stesso trattamento borderless della matrice pulsanti.
    tb._noOuterBorder = true
    RLSuite.utils:SkinFrame(tb)

    -- La barretta resta cliccabile (i suoi bottoni) ma NON trascinabile: la
    -- posizione e' fissa (bordo alto, alla distanza dal lato destro pari alla
    -- larghezza del Raid Frame).
    tb:EnableMouse(true)

    -- Niente piu' la scritta "RLS": al suo posto (creati piu' sotto) l'icona
    -- di fase e il nome della fase, cosi' la barretta dice qualcosa di utile.

    -- Pulsante "Raid Control": apre e chiude il pannello dei tasti sotto la barretta.
    local rcBtn = CreateFrame("Button", "RLSuiteRaidControlBtn", tb, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(rcBtn)
    rcBtn:SetHeight(20)
    rcBtn:SetText("Raid Control")
    local probe = tb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    probe:SetText("Raid Control")
    local textW = (probe.GetStringWidth and probe:GetStringWidth()) or 84
    probe:Hide()
    rcBtn:SetWidth(math.max(78, (textW or 84) + 16))
    rcBtn:SetPoint("RIGHT", tb, "RIGHT", -4, 0)
    rcBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Raid Control")
        GameTooltip:AddLine(L["Shows or hides the button panel under this bar."], 1, 1, 1)
        GameTooltip:Show()
    end)
    rcBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Evidenzia il pulsante quando il pannello e' aperto (prima lo faceva la
    -- freccia girandosi). Nome storico mantenuto: _updateArrowDir.
    local function MW_UpdateArrowDir()
        if not (rcBtn and rcBtn.LockHighlight) then return end
        if f:IsShown() then rcBtn:LockHighlight() else rcBtn:UnlockHighlight() end
        -- Stesso legame anche quando il pannello si apre/chiude per altre vie
        -- (X della barretta, /rls, ShowTab): il pannello debug segue sempre.
        if RLSuite.SyncDebugPanel then RLSuite:SyncDebugPanel() end
    end
    MW._updateArrowDir = MW_UpdateArrowDir
    f:HookScript("OnShow", MW_UpdateArrowDir)
    f:HookScript("OnHide", MW_UpdateArrowDir)

    rcBtn:SetScript("OnClick", function()
        if f:IsShown() then
            f:Hide()
        else
            f:Show()
        end
        MW_UpdateArrowDir()
        -- RLS DEBUG vive e muore con il pannello dei tasti: si chiude con lui
        -- e ricompare a OGNI apertura (se il debug e' attivo).
        if RLSuite.SyncDebugPanel then RLSuite:SyncDebugPanel() end
    end)
    tb.raidControlBtn = rcBtn
    tb.arrowBtn = rcBtn            -- alias storico (stesso bottone)
    self.raidControlBtn = rcBtn    -- usato da ApplyLayout per la larghezza
    MW_UpdateArrowDir()

    -- Niente titolo dentro la finestra: i bottoni restano (matrice + fase +
    -- X di chiusura e icona SaveRaid). La Config si apre dalla minimappa
    -- (clic destro) o da /rls config.

    -- ORDINE DEI TASTI DELLA MATRICE (richiesto): Pugger, Raid Frame,
    -- MS, Macrobar, MT & OT, Loot, SaveRaid. I tab si creano in
    -- quest'ordine e la griglia li dispone riga per riga (vedi matrixOrder).
    self.tabDefs = {
        { key = "group",     label = "Pugger" },
        { key = "ms",        label = "MS" },
        { key = "macro",     label = "Macrobar" },
        { key = "loot",      label = "Loot" },
    }
    self.tabs = {}
    self.currentTab = nil

    -- Matrice colonne x righe configurabile: 5 tab
    self.matrixButtons = {}
    for i, def in ipairs(self.tabDefs) do
        local tab = CreateFrame("Button", "RLSuiteTab" .. def.key, f, "UIPanelButtonTemplate")
        RLSuite.utils:SkinButton(tab)
        tab:SetSize(90, 22)
        tab:SetText(def.label)
        tab.tabKey = def.key
        tab:SetScript("OnClick", function() self:OnTabClick(def.key) end)
        self.tabs[def.key] = tab
        table.insert(self.matrixButtons, tab)
    end

    -- MT / OT: due mezzi tasti che occupano UNA sola cella della matrice.
    -- Assegnano (o rimuovono, se gia' assegnato) il target corrente come
    -- Main Tank / Main Assist via SetPartyAssignment (solo RL/assist,
    -- RLSuite:AssignPartyRole fa i controlli e avvisa in chat).
    -- SetPartyAssignment e' PROTETTA su 3.3.5 (forbidden da codice addon):
    -- l'assegnazione passa da un bottone SECURE che esegue lo slash macro
    -- ("/maintank Nome" / "/mainassist Nome"), identico a una macro fatta a mano.
    -- Il macrotext viene compilato in PreClick (SOLO fuori combattimento: gli
    -- attributi protetti non si toccano in combat) e svuotato in PostClick.
    local function MakeRoleSecBtn(name, text, roleCmd)
        local b = CreateFrame("Button", name, f, "SecureActionButtonTemplate, UIPanelButtonTemplate")
        RLSuite.utils:SkinButton(b)
        b:SetText(text)
        b:RegisterForClicks("LeftButtonDown")
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "")
        b:SetScript("PreClick", function(s)
            s:SetAttribute("macrotext", "")
            if InCombatLockdown and InCombatLockdown() then
                RLSuite.utils:Print(L["Cannot assign Main Tank / Main Assist while in combat."])
                return
            end
            if not (UnitExists and UnitExists("target")) then
                RLSuite.utils:Print(L["Target a raid member first to assign %s."]:format(
                    roleCmd == "maintank" and "Main Tank" or "Main Assist"))
                return
            end
            local name = UnitName and UnitName("target")
            -- DEBUG: invece della macro (fallirebbe su player fittizi), i
            -- tasti MT/OT toccano lo store simulato debugTanks -> le barre
            -- Tanks del Raid Frame si riempiono anche coi fake.
            if RLSuite.DebugMode and RLSuite:DebugMode() then
                if name and name ~= "" then
                    RLSuite.debugTanks = RLSuite.debugTanks or {}
                    local key = (roleCmd == "maintank") and "mt" or "ot"
                    local cur = RLSuite.debugTanks[key]
                    if cur == name then
                        RLSuite.debugTanks[key] = false -- svuotato intenzionalmente: niente auto-refill
                    else
                        RLSuite.debugTanks[key] = name
                    end
                    RLSuite.utils:Print(string.format(L["%s toggled as %s."], name,
                        roleCmd == "maintank" and L["Main tank"] or L["Main assist"]))
                    local rf = RLSuite.raidFrame
                    if rf and rf.Rebuild then rf:Rebuild() end
                end
                return
            end
            if RLSuite.IsOfficer and not RLSuite:IsOfficer() then
                RLSuite.utils:Print(L["Only the raid leader or an assist can assign Main Tank / Main Assist."])
                return
            end
            if name and name ~= "" then
                s:SetAttribute("macrotext", "/" .. roleCmd .. " " .. name)
            end
        end)
        b:SetScript("PostClick", function(s)
            s:SetAttribute("macrotext", "")
        end)
        return b
    end
    self.mtBtn = MakeRoleSecBtn("RLSuiteMTBtn", "MT", "maintank")
    self.otBtn = MakeRoleSecBtn("RLSuiteOTBtn", "OT", "mainassist")
    local function mtPairTooltip(btn, titleKey, lineKey)
        btn:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[titleKey])
            GameTooltip:AddLine(L[lineKey], 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    mtPairTooltip(self.mtBtn, "Main Tank (MT)", "Assign/remove your current target as Main Tank.")
    mtPairTooltip(self.otBtn, "Main Assist (OT)", "Assign/remove your current target as Main Assist.")

    -- Icona fase singola: accanto all'icona SaveRaid, cambia in base alla
    -- fase (occhio LFG animato / clessidra / spade da combattimento).
    -- Clic = passa alla fase successiva.
    self.phaseDefs = {
        preraid = { label = "Pre-raid",
            file = "Interface\\LFGFrame\\LFG-Eye",
            static = { 0, 0.125, 0, 0.25 },
            anim = { frames = 29, cols = 8, rows = 4, delay = 0.1 } },
        preboss = { label = "Pre-boss",
            file = "Interface\\Icons\\Spell_Holy_BorrowedTime" },
        infight = { label = "In-fight",
            file = "Interface\\CharacterFrame\\UI-StateIcon",
            static = { 0.5, 1.0, 0, 0.5 } },
    }
    -- L'icona di fase vive NELLA BARRETTA del titolo (al posto di "RLS"):
    -- PHASE_ICON px, ingrandita insieme alla barretta (era 16).
    self.phaseBtn = CreateFrame("Button", "RLSuitePhaseBtn", tb)
    self.phaseBtn:SetSize(PHASE_ICON, PHASE_ICON)
    self.phaseBtn:EnableMouse(true)
    self.phaseBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    RLSuite.utils:SkinBox(self.phaseBtn)
    local phaseIcon = self.phaseBtn:CreateTexture(nil, "ARTWORK")
    phaseIcon:SetPoint("TOPLEFT", self.phaseBtn, "TOPLEFT", 2, -2)
    phaseIcon:SetPoint("BOTTOMRIGHT", self.phaseBtn, "BOTTOMRIGHT", -2, 2)
    self.phaseBtn.icon = phaseIcon
    self.phaseBtn:SetScript("OnClick", function(s, button)
        if not RLSuite.CycleContextPhase then return end
        if button == "RightButton" then
            RLSuite:CycleContextPhase(-1)
        else
            RLSuite:CycleContextPhase(1)
        end
    end)
    self.phaseBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Phase indicator"])
        GameTooltip:AddLine(L["Left click: next phase"], 1, 1, 1)
        GameTooltip:AddLine(L["Right click: previous phase"], 1, 1, 1)
        GameTooltip:Show()
    end)
    self.phaseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Testo con il nome della fase, mostrato accanto all'icona fase
    -- quando c'e' spazio sufficiente fino alla X di chiusura.
    self.phaseText = tb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.phaseText:SetTextColor(1, 0.82, 0)
    self.phaseText:SetJustifyH("LEFT")
    self.phaseText:Hide()
    tb.title = self.phaseText

    -- Larghezza del nome di fase piu' lungo (una volta sola): e' il posto che
    -- la barretta riserva al nome, cosi' la larghezza non cambia mai al
    -- cambiare della fase.
    local widest = 0
    for _, pd in pairs(self.phaseDefs or {}) do
        self.phaseText:SetText(pd.label or "")
        local w = (self.phaseText.GetStringWidth and self.phaseText:GetStringWidth()) or 0
        if w > widest then widest = w end
    end
    self._phaseLabelW = math.ceil(widest + 2)
    self.phaseText:SetText("")


    -- Config: accessibile dal clic destro sull'icona della minimappa e da
    -- /rls config (niente piu' icona rotellina nella barra principale).

    -- SaveRaid: TORNA A ESSERE UN PULSANTE (non un'icona): stesso stile e
    -- stessa taglia dei tasti della matrice, entra nella griglia come settimo
    -- tasto (la riga di icone in alto non esiste piu').
    self.saveRaidBtn = CreateFrame("Button", "RLSuiteSaveRaidBtn", f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.saveRaidBtn)
    self.saveRaidBtn:SetSize(90, 22)
    self.saveRaidBtn:SetText("SaveRaid")
    self.saveRaidBtn:RegisterForClicks("LeftButtonUp")
    self.saveRaidBtn:SetScript("OnClick", function() self:OnSaveRaid() end)
    self.saveRaidBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("SaveRaid")
        GameTooltip:AddLine(L["Saves the current setup (Comp, MacroBar, Config)."], 1, 1, 1)
        GameTooltip:Show()
    end)
    self.saveRaidBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- ORDINE DELLE CELLE DELLA MATRICE: la coppia MT & OT occupa UNA cella e
    -- sta al 5o posto (prima era "appesa" sotto Raid Frame, con i tasti
    -- seguenti che scalavano di uno: con un ordine esplicito non serve piu'
    -- nessun caso particolare).
    self.matrixOrder = {
        { btn = self.tabs["group"] },
        { btn = self.tabs["macro"] },
        { role = true },                    -- MT & OT nella stessa cella
        { btn = self.tabs["ms"] },
        { btn = self.tabs["loot"] },
        { btn = self.saveRaidBtn },
    }
    -- Elenco piatto dei BOTTONI (senza la cella della coppia): comodo per i
    -- controlli e per chi conta i tasti.
    self.matrixButtons = {}
    for _, c in ipairs(self.matrixOrder) do
        if c.btn then self.matrixButtons[#self.matrixButtons + 1] = c.btn end
    end

    self:ApplyLayout()
end

-- Larghezza del RAID FRAME (HUD) come la vede l'utente: icone food/flask +
-- barra giocatore + barre CD. La matrice dei buff NON e' compresa: le colonne
-- dei buff sono disegnate OLTRE il bordo destro del frame (RaidFrame.lua:
-- matrix a x = rowWidth + 4), quindi m.W e' gia' "senza buff".
-- Ritorna la larghezza EFFETTIVA a schermo (metrica x scala del frame).
function MW:RaidFrameWidth()
    local rf = RLSuite.raidFrame
    if not (rf and rf.LayoutMetrics) then return 0 end
    local ok, m = pcall(function() return rf:LayoutMetrics() end)
    if not ok or type(m) ~= "table" then return 0 end
    local scale = (rf.db and rf.db.scale) or 1
    return (m.W or 0) * scale
end

function MW:ApplyLayout()
    local L = RLSuite.db and RLSuite.db.profile.layout and RLSuite.db.profile.layout.main
    if not self.frame then return end
    L = L or {}
    local cols = math.max(1, math.min(8, tonumber(L.matrixCols) or 2))
    local rows = math.max(1, math.min(8, tonumber(L.matrixRows) or 4))
    -- Celle della matrice: una per tasto, una per la coppia MT & OT.
    local cells = self.matrixOrder
    if not cells or #cells == 0 then
        cells = {}
        for _, b in ipairs(self.matrixButtons or {}) do cells[#cells + 1] = { btn = b } end
    end
    local nCells = #cells
    if nCells > 0 then
        rows = math.max(rows, math.ceil(nCells / cols))
    end

    -- Bottoni matrice: colonne x righe configurabili dalla Config.
    -- La vecchia RIGA DI ICONE in alto non esiste piu': l'icona di fase sta
    -- nella barretta del titolo e "SaveRaid" e' tornato un pulsante della
    -- matrice. Quindi la barra e' PIU' BASSA di tutta quella riga.
    local bw, bh, gapX, gapY = 74, 22, 6, 4
    local PAD = 4

    local matrixW = cols * bw + (cols - 1) * gapX
    local matrixH = rows * bh + (rows - 1) * gapY

    local tbPad, tbGap = 4, 4
    local phaseIconW = PHASE_ICON
    local phaseNameW = self._phaseLabelW or 58
    local rcBtnRef = self.raidControlBtn or (self.titleBar and self.titleBar.raidControlBtn)
    local rcW = (rcBtnRef and rcBtnRef:GetWidth()) or 96
    local titleW = tbPad + phaseIconW + tbGap + phaseNameW + tbGap + rcW + tbPad
    self._titleRowW = titleW

    local contentW = matrixW
    local h = 2 * PAD + matrixH
    local w = 2 * PAD + contentW

    self.frame:SetSize(w, h)
    self.frame:SetScale(L.scale or 1)

    if self.titleBar then
        self.titleBar:ClearAllPoints()
        self.titleBar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self:RaidFrameWidth(), 0)
    end
    self.frame:ClearAllPoints()
    if self.titleBar then
        self.frame:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 0, -2)
    else
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self:RaidFrameWidth(), -TITLE_BAR_H - 2)
    end

    -- Bottoni matrice: colonne x righe configurabili dalla Config.
    -- La coppia MT/OT sta SOTTO il tasto "Raid Frame" (cella
    -- i_raidframe + colonne) se quella cella e' dentro la matrice: i
    -- tasti seguenti scalano di una cella per lasciare il posto libero.
    -- Altrimenti (colonne troppe larghe) la coppia finisce nella cella
    -- subito dopo l'ultimo tasto, come prima.
    local x0 = PAD
    local topY = -PAD
    -- POSIZIONAMENTO IN ORDINE: riga per riga, da sinistra a destra
    -- (Pugger, Raid Frame / MS, Macrobar / MT & OT, Loot / SaveRaid
    -- con 2 colonne). La cella della coppia MT & OT ospita i due mezzi tasti.
    local halfGap = 4
    local halfW = (bw - halfGap) / 2
    for idx, c in ipairs(cells) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local cellX = x0 + col * (bw + gapX)
        local cellY = topY - row * (bh + gapY)
        if c.role then
            if self.mtBtn and self.otBtn then
                self.mtBtn:ClearAllPoints()
                self.mtBtn:SetSize(halfW, bh)
                self.mtBtn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", cellX, cellY)
                self.otBtn:ClearAllPoints()
                self.otBtn:SetSize(bw - halfW - halfGap, bh)
                self.otBtn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", cellX + halfW + halfGap, cellY)
            end
        elseif c.btn then
            c.btn:ClearAllPoints()
            c.btn:SetSize(bw, bh)
            c.btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", cellX, cellY)
        end
    end

    -- BARRETTA DEL TITOLO: larghezza = SOMMA DEI SUOI ELEMENTI e ancorata a
    -- sinistra sopra il pannello (non piu' stirata sulla larghezza della
    -- matrice: con la matrice larga restava un vuoto enorme in mezzo).
    if self.titleBar then
        self.titleBar:SetWidth(titleW)
    end
    if self.phaseBtn then
        self.phaseBtn:ClearAllPoints()
        self.phaseBtn:SetPoint("LEFT", self.titleBar or self.frame, "LEFT", tbPad, 0)
    end
    if self.phaseText and self.phaseBtn then
        self.phaseText:ClearAllPoints()
        self.phaseText:SetPoint("LEFT", self.phaseBtn, "RIGHT", PHASE_GAP, 0)
        -- Il nome della fase ha un posto RISERVATO nel calcolo della
        -- larghezza (phaseNameW): qui si mostra sempre se la titleBar e' mostrata.
        local rf = RLSuite.raidFrame
        local rfShown = rf and rf.frame and rf.frame:IsShown()
        if self.titleBar and self.titleBar:IsShown() and rfShown then
            self.phaseText:Show()
        else
            self.phaseText:Hide()
        end
    end
    if self.raidControlBtn and self.titleBar then
        self.raidControlBtn:ClearAllPoints()
        self.raidControlBtn:SetPoint("RIGHT", self.titleBar, "RIGHT", -tbPad, 0)
    end
    if self.closeBtn then
        self.closeBtn:ClearAllPoints()
        self.closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -PAD)
    end

    RLSuite.utils:SkinFrame(self.frame)
    self:UpdatePhaseButtons()
    self:SyncVisibilityWithRaidFrame()
end

function MW:SkinInner()
    -- Il vecchio pannello Raid Frame (preview + alert messages) non esiste
    -- piu' come finestra a tab: le impostazioni vivono in Config e l'HUD
    -- non viene mai "skinnato" (nessuno sfondo/bordo). Niente da fare qui.
end

function MW:PaneForTab(key)
    if key == "group" then
        return RLSuite.groupmaking and RLSuite.groupmaking.mainFrame
    elseif key == "raidframe" then
        -- Il tab Raid Frame non apre piu' una finestra: mostra/nasconde
        -- l'HUD (vedi OnTabClick). Nessun pannello associato.
        return nil
    elseif key == "ms" then
        return RLSuite.msManager and RLSuite.msManager.frame
    elseif key == "loot" then
        return RLSuite.lootManager and RLSuite.lootManager.frame
    end
    return nil
end

-- Layout key usato per salvare posizione/dimensione di ogni tab.
function MW:LayoutKeyForTab(key)
    if key == "group" then return "groupmaking" end
    if key == "raidframe" then return "raidframe" end
    return key -- ms / loot
end

function MW:HideAllWindows()
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    local keys = { "group", "raidframe", "ms", "loot" }
    for _, k in ipairs(keys) do
        local pane = self:PaneForTab(k)
        if pane then pane:Hide() end
    end
    -- L'InviteEngine (ex-Whisplist) e' una costola di Groupmaking:
    -- nascondendo la finestra principale si chiude anche il pannello ancorato.
    if RLSuite.groupmaking and RLSuite.groupmaking.whisplistFrame then
        RLSuite.groupmaking.whisplistFrame:Hide()
    end
end

function MW:RegisterAllWindows()
    -- Minimi di contenuto per le finestre ridimensionabili.
    -- Vengono ri-calcolati a ogni drag; quello di Groupmaking dipende
    -- dalla composizione corrente (10/25), gli altri sono fissi perche'
    -- i loro layout interni non cambiano con la difficolta'.
    RLSuite.windowMins = RLSuite.windowMins or {}
    RLSuite.windowMins.groupmaking = function()
        -- Larghezza minima: larghezza complessiva della fila di controlli
        -- in basso (Start Spam, Preview Msg, checkbox + "Show specs in
        -- message", InviteEngine) calcolata da Groupmaking:MinWidth().
        -- Altezza: pila verticale title+dropdowns, gruppo slot (topRow),
        -- box "richieste" e blocco basso anteprima+bottoni.
        local gm = RLSuite.groupmaking
        local minW = 560
        if gm and gm.MinWidth then minW = gm:MinWidth() end
        if gm and gm.MinHeight then
            return minW, gm:MinHeight()
        end
        local topH = 156
        if gm and gm.topRow then
            local th = gm.topRow:GetHeight()
            if th and th > 60 then topH = th end
        end
        return minW, topH + 328
    end
    RLSuite.windowMins.ms = function()
        return 350, 280
    end
    RLSuite.windowMins.loot = function()
        -- larghezza minima = spazio reale dei bottoni di roll
        -- (16 + Roll MS/OS/FFA/Reroll 4x80 + Announce Changes 124 + margini):
        -- sotto i 506 il tasto MS "Announce Changes" sborda fuori finestra.
        return 510, 340
    end

    -- Aggancia trascinamento + posizione persistente alle finestre dei tab.
    local layoutKeys = {
        group = "groupmaking",
        ms = "ms",
        loot = "loot",
    }
    for key, lkey in pairs(layoutKeys) do
        local pane = self:PaneForTab(key)
        if pane and not pane._rlsWindow then
            pane._rlsWindow = true
            -- Loot Manager: NON spostabile, si comporta come una finestra
            -- nativa (es. pannello equip): posizione fissa, mai trascinabile.
            if key ~= "loot" then
                RLSuite.utils:MakeDraggable(pane, lkey)
            end
            RLSuite.utils:MakeClickToFront(pane)
            -- la X della finestra chiude anche lo stato del tab nella barra
            if pane.closeBtn then
                local oldClick = pane.closeBtn:GetScript("OnClick")
                pane.closeBtn:SetScript("OnClick", function()
                    pane:Hide()
                    MW:UpdateTabHighlight(key)
                    if MW.currentTab == key then
                        MW.currentTab = nil
                    end
                    if oldClick then oldClick() end
                end)
            end
        end
    end

    -- Grip di resize per Groupmaking, MS e Loot
    local resizable = {
        group = { "groupmaking", 420, 380, "groupmaking" },
        ms = { "ms", 320, 260, "ms" },
        loot = { "loot", 440, 300, "loot" },
    }
    for key, cfg in pairs(resizable) do
        local pane = self:PaneForTab(key)
        if pane then
            RLSuite.utils:AddResizeGrip(pane, cfg[1], cfg[2], cfg[3], function()
                if key == "group" and RLSuite.groupmaking then
                    if RLSuite.groupmaking.LayoutGroupPanels then RLSuite.groupmaking:LayoutGroupPanels() end
                end
                if key == "ms" and RLSuite.msManager then
                    if RLSuite.msManager.UpdateList then RLSuite.msManager:UpdateList() end
                end
                if key == "loot" and RLSuite.lootManager then
                    if RLSuite.lootManager.UpdateHistory then RLSuite.lootManager:UpdateHistory() end
                end
            end)
            -- Se una dimensione salvata in passato era sotto il minimo,
            -- riportala subito a una dimensione che non sovrappone i contenuti.
            RLSuite.utils:EnforceWindowMin(pane, cfg[1])
        end
    end
end

function MW:SelectTab(key)
    if type(key) == "number" then
        local def = self.tabDefs and self.tabDefs[key]
        key = def and def.key or "group"
    end
    if key ~= "group" and key ~= "raidframe"
        and key ~= "ms" and key ~= "loot" then
        key = "group"
    end
    self.currentTab = key

    -- Finestre a schede: si aprono come pannelli indipendenti e spostabili,
    -- e possono restare aperte piu' d'una alla volta.
    local pane = self:PaneForTab(key)
    if pane then
        -- panes creati come figli della barra (raidframe) tornano a UIParent
        if pane:GetParent() == self.frame then
            pane:SetParent(UIParent)
        end
        local lkey = self:LayoutKeyForTab(key)
        local L = RLSuite.utils:WindowLayout(lkey)
        -- Default: come quando i pannelli erano agganciati sotto la barra
        -- (larghezza/altezza della tab in Config -> General -> Finestra).
        local mL = (RLSuite.db.profile.layout and RLSuite.db.profile.layout.main) or {}
        local pw = L.width or mL.width or 660
        local ph = L.height or mL.height or 700
        -- mai piu' piccolo del contenuto della finestra
        local mw, mh = RLSuite.utils:WindowMin(lkey, pane)
        if mw then
            pw = math.max(pw, mw)
            ph = math.max(ph, mh)
        end
        -- auto-sanazione di salvataggi rovinati: la dimensione salvata
        -- non puo' superare lo schermo (ereditato dal vecchio bug resize)
        local swn, shn = (GetScreenWidth and GetScreenWidth()) or 0, (GetScreenHeight and GetScreenHeight()) or 0
        if swn > 0 and pw > swn then pw = swn if L.width and L.width > swn then L.width = swn end end
        if shn > 0 and ph > shn then ph = shn if L.height and L.height > shn then L.height = shn end end
        pane:SetSize(pw, ph)
        if key == "loot" then
            -- finestra tipo equip: posizione fissa nativa (in alto a
            -- sinistra; a DESTRA del trade quando e' aperto), decisa da
            -- LM:AnchorDefault; ignora posizioni salvate storiche.
            if RLSuite.lootManager and RLSuite.lootManager.AnchorDefault then
                RLSuite.lootManager:AnchorDefault()
            else
                pane:ClearAllPoints()
                pane:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
            end
        else
            RLSuite.utils:ApplySavedPos(pane, lkey, function()
                return self:DefaultCascadeOffset(key)
            end)
        end
        if RLSuite.utils.ClampWindowToScreen then
            RLSuite.utils:ClampWindowToScreen(pane)
        end
        -- porta la finestra in primo piano sopra le altre (strata HIGH +
        -- frame level distanziato: niente sovrapposizioni parziali)
        RLSuite.utils:RaiseWindow(pane)
        pane:Show()
        self:RefreshTabContents(key)
        -- evidenzia i tab dopo l'apertura: il tab resta acceso finche'
        -- la sua finestra e' visibile (anche con piu' finestre aperte)
        self:RefreshTabHighlights()
    end
end

function MW:RefreshTabContents(key)
    if key == "group" then
        if RLSuite.groupmaking and RLSuite.groupmaking.UpdateMessagePreview then
            RLSuite.groupmaking:UpdateMessagePreview()
        end
        if RLSuite.groupmaking and RLSuite.groupmaking.LayoutGroupPanels then
            RLSuite.groupmaking:LayoutGroupPanels()
        end
    elseif key == "ms" then
        if RLSuite.msManager and RLSuite.msManager.UpdateList then
            RLSuite.msManager:UpdateList()
        end
    elseif key == "loot" then
        if RLSuite.lootManager and RLSuite.lootManager.UpdateHistory then
            RLSuite.lootManager:UpdateHistory()
        end
    end
end

function MW:UpdatePhaseButtons()
    local phase = RLSuite.context or "preraid"
    local def = self.phaseDefs and self.phaseDefs[phase]
    local btn = self.phaseBtn
    if not btn or not def then return end

    btn.label = def.label
    if self.phaseText then
        self.phaseText:SetText(def.label or "")
    end
    btn.icon:SetTexture(def.file)
    if def.static then
        btn.icon:SetTexCoord(def.static[1], def.static[2], def.static[3], def.static[4])
    elseif not def.anim then
        -- icona intera: azzera il ritaglio lasciato da una fase precedente
        btn.icon:SetTexCoord(0, 1, 0, 1)
    end

    if def.anim then
        local a = btn._anim or {}
        a.frames = def.anim.frames
        a.cols = def.anim.cols
        a.rows = def.anim.rows
        a.delay = def.anim.delay
        a.t = 0
        a.frame = 0
        btn._anim = a
        btn:SetScript("OnUpdate", function(s, elapsed)
            local aa = s._anim
            aa.t = aa.t + elapsed
            while aa.t >= aa.delay do
                aa.t = aa.t - aa.delay
                aa.frame = aa.frame + 1
                if aa.frame >= aa.frames then aa.frame = 0 end
            end
            local col = aa.frame % aa.cols
            local row = math.floor(aa.frame / aa.cols)
            s.icon:SetTexCoord(col / aa.cols, (col + 1) / aa.cols, row / aa.rows, (row + 1) / aa.rows)
        end)
    else
        btn:SetScript("OnUpdate", nil)
    end
end

-- Il vecchio pannello "Raid Frame" (anteprima + messaggi di alert) e'
-- stato rimosso: il tab Raid Frame ora mostra/nasconde l'HUD (OnTabClick)
-- e tutte le impostazioni vivono in Config -> Raid Frame (Config.lua).

-- ============================================================
-- SaveRaid: prompt titolo + salvataggio
-- ============================================================
function MW:OnSaveRaid()
    self:AskRaidTitle(function(title)
        if not title or title == "" then
            RLSuite.utils:Print(L["SaveRaid cancelled: no title entered."])
            return
        end
        if RLSuite.SaveRaid then
            RLSuite:SaveRaid(title)
        end
    end)
end

function MW:AskRaidTitle(callback)
    if self.savePrompt then
        self.savePrompt:Show()
        local edit = self.savePrompt.edit
        edit:SetText("")
        edit:SetFocus()
        self.savePrompt._cb = callback
        return
    end

    local f = CreateFrame("Frame", "RLSuiteSaveRaidPrompt", UIParent)
    f:SetSize(340, 110)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    RLSuite.utils:ClampWindow(f)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    RLSuite.utils:SkinFrame(f)
    f:Hide()

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
    label:SetText(L["SaveRaid title:"])

    local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    edit:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    edit:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -40)
    edit:SetHeight(20)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(64)
    f.edit = edit

    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(ok)
    ok:SetSize(90, 22)
    ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    ok:SetText(L["Save"])
    ok:SetScript("OnClick", function()
        local cb = f._cb
        f:Hide()
        if cb then cb(edit:GetText() or "") end
    end)

    local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(cancel)
    cancel:SetSize(90, 22)
    cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
    cancel:SetText(L["Cancel"])
    cancel:SetScript("OnClick", function()
        f:Hide()
    end)

    edit:SetScript("OnEnterPressed", ok.GetScript(ok, "OnClick"))
    edit:SetScript("OnEscapePressed", function(s) s:ClearFocus() f:Hide() end)
    f.edit = edit
    f._cb = callback

    self.savePrompt = f
    f:Show()
    edit:SetFocus()
end
