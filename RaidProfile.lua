-- ============================================================
-- RLSuite - RaidProfile Module (Main Window)
-- ============================================================

RLSuite.mainWindow = {}
local MW = RLSuite.mainWindow

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

function MW:Init()
    self:CreateFrame()
    self:RegisterAllWindows()
end

function MW:Toggle()
    -- La BARRA e' una finestra vera: Toggle apre/chiude la BARRRA (e con lei
    -- il pannello). Il pannello si apre/chiude anche SOLO con la freccia
    -- sulla barra; la barra resta come finestra autonoma.
    if not self.frame then return end
    if self.titleBar and self.titleBar:IsShown() then
        self.frame:Hide()
        self.titleBar:Hide()
    else
        if self.titleBar then self.titleBar:Show() end
        self.frame:Show()
        -- /rls mostra anche l'HUD MacroBar (se abilitata e non gia' visibile)
        self:ShowMacrobarHud()
    end
end

-- Mostra la HUD MacroBar insieme alla barra (usata da /rls).
function MW:ShowMacrobarHud()
    local mb = RLSuite.macrobar
    if not mb or not mb.frame then return end
    if RLSuite.db.profile.macrobar and RLSuite.db.profile.macrobar.enabled == false then return end
    local pset = mb.PhaseSettings and mb:PhaseSettings()
    if pset and pset.enabled == false then return end
    if not mb.frame:IsShown() then
        mb.frame:Show()
        if mb.ApplyLayout then mb:ApplyLayout() end
    end
    self:RefreshTabHighlights()
end

function MW:ShowTab(key)
    if key == "config" then
        -- Config is now a self-contained Ace3 window, not a tab pane.
        if RLSuite.config and RLSuite.config.Toggle then
            RLSuite.config:Toggle()
        end
        return
    end
    if not self.frame then return end
    self.frame:Show()
    if self.titleBar then self.titleBar:Show() end
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
    -- Il tasto Raid Frame mostra/nasconde l'HUD del raid (stessa logica
    -- del Macrobar): le impostazioni stanno in Config -> Raid Frame.
    if key == "raidframe" then
        if RLSuite.raidFrame and RLSuite.raidFrame.Toggle then
            RLSuite.raidFrame:Toggle()
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
    local ALL_KEYS = { "group", "raidframe", "ms", "loot", "log" }
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
    local f = CreateFrame("Frame", "RLSuiteMainWindow", UIParent)
    f:SetSize(240, 150)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    -- Finestra UNIVERSALE come tutte le altre dell'addon: drag+clamp
    -- (MakeDraggable), front layer, BORDO tematico. Layout key "main"
    -- (mai ripristinato in base flow: la posizione viene dalla command).
    RLSuite.utils:MakeUniversalWindow(f, "main")
    f:Hide()
    f._noOuterBorder = true
    self.frame = f
    RLSuite.utils:SkinFrame(f)
    RLSuite.utils:ClampWindow(f)

    -- === Barretta titolo 20px SOPRA la main bar ======================
    -- Eredita la larghezza della main bar (anchor a tutti e due gli
    -- angoli). A sinistra: "RLS"; a destra: arrowup.tga (mostra/nasconde
    -- il pannello sotto alla barretta) e close.tga (chiude la main bar).
    local tb = CreateFrame("Frame", "RLSuiteMainTitleBar", UIParent)
    tb:SetHeight(30)
    -- gap 2px: barretta STACCATA dalla main bar (non incollata)
    tb:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    tb:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 2)
    tb:SetFrameStrata(f:GetFrameStrata() or "HIGH")
    tb:EnableMouse(true)
    tb:Hide()
    self.titleBar = tb
    -- la barretta e' una finestra universale anche lei: drag+clamp e stesso
    -- bordo tematico della main bar (e di ogni finestra dell'addon).
    if RLSuite.utils.MakeUniversalWindow then
        RLSuite.utils:MakeUniversalWindow(tb, "titlebar")
    else
        RLSuite.utils:SkinFrame(tb)
    end

    -- La barretta TRASCINA tutta la main bar: clic sinistro + trascina.
    -- La barretta trascina la main bar (proxy), MA con lo stesso guard di
    -- clamp usato da MakeDraggable: durante il drag la finestra non esce
    -- MAI dai bordi (workaround del bug SetClampedToScreen+scala).
    tb:RegisterForDrag("LeftButton")
    tb:EnableMouse(true)
    tb:SetScript("OnDragStart", function()
        f:StartMoving()
        if f._rlsDragGuard then f._rlsDragGuard:Show() end
    end)
    tb:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        if f._rlsDragGuard then f._rlsDragGuard:Hide() end
        RLSuite.utils:ClampWindowToScreen(f)
        RLSuite.utils:PersistFramePos(f, "main")
    end)

    local tbTitle = tb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tbTitle:SetPoint("LEFT", tb, "LEFT", 8, 0)
    tbTitle:SetText("RLS")
    tbTitle:SetTextColor(1, 0.82, 0)
    tb.title = tbTitle

    -- X bianca + freccia dai TGA dell'utente in media/, DIMEZZATE (11px).
    local crashBtn = CreateFrame("Button", nil, tb)
    crashBtn:SetSize(11, 11)
    crashBtn:SetPoint("RIGHT", tb, "RIGHT", -4, 0)
    RLSuite.utils:ApplyIcon(crashBtn, "media\\close.tga")
    crashBtn:SetScript("OnClick", function()
        -- La X chiude SOLO la main window (barra+pannello): le finestre
        -- dei moduli restano aperte (anche in fight).
        f:Hide()
        tb:Hide()
    end)
    tb.closeBtn = crashBtn

    local arrBtn = CreateFrame("Button", nil, tb)
    arrBtn:SetSize(11, 11)
    arrBtn:SetPoint("RIGHT", crashBtn, "LEFT", -4, 0)
    RLSuite.utils:ApplyIcon(arrBtn, "media\\arrowup.tga")

    -- Freccia: punta IN SU col pannello APERTO; SPECCHIATA (in giu') col
    -- pannello CHIUSO. Flip verticale via TexCoord.
    local function MW_UpdateArrowDir()
        local up = f:IsShown()
        if arrBtn.icon and arrBtn.icon.SetTexCoord then
            arrBtn.icon:SetTexCoord(0, 1, up and 0 or 1, up and 1 or 0)
        end
        if arrBtn.hl and arrBtn.hl.SetTexCoord then
            arrBtn.hl:SetTexCoord(0, 1, up and 0 or 1, up and 1 or 0)
        end
    end
    MW._updateArrowDir = MW_UpdateArrowDir
    f:HookScript("OnShow", MW_UpdateArrowDir)
    f:HookScript("OnHide", MW_UpdateArrowDir)

    arrBtn:SetScript("OnClick", function()
        -- La freccia mostra/nasconde SOLO il pannello dei pulsanti sotto
        -- la barretta. In ogni momento, anche in fight: mai altre finestre.
        if f:IsShown() then
            f:Hide()
        else
            f:Show()
        end
        MW_UpdateArrowDir()
    end)
    tb.arrowBtn = arrBtn
    MW_UpdateArrowDir()

    -- Niente titolo dentro la finestra: i bottoni restano (matrice + fase +
    -- X di chiusura e icona SaveRaid). La Config si apre dalla minimappa
    -- (clic destro) o da /rls config.

    self.tabDefs = {
        { key = "group",     label = "Groupmaking" },
        { key = "macro",     label = "Macrobar" },
        { key = "raidframe", label = "Raid Frame" },
        { key = "ms",        label = "MS" },
        { key = "loot",      label = "Loot" },
        { key = "log",       label = "Log" },
    }
    self.tabs = {}
    self.currentTab = nil

    -- Matrice colonne x righe configurabile: 6 tab
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
    self.phaseBtn = CreateFrame("Button", "RLSuitePhaseBtn", f)
    self.phaseBtn:SetSize(26, 26)
    self.phaseBtn:EnableMouse(true)
    self.phaseBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    RLSuite.utils:SkinBox(self.phaseBtn)
    local phaseIcon = self.phaseBtn:CreateTexture(nil, "ARTWORK")
    phaseIcon:SetPoint("TOPLEFT", self.phaseBtn, "TOPLEFT", 3, -3)
    phaseIcon:SetPoint("BOTTOMRIGHT", self.phaseBtn, "BOTTOMRIGHT", -3, 3)
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
    self.phaseText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.phaseText:SetTextColor(1, 0.82, 0)
    self.phaseText:SetJustifyH("LEFT")
    self.phaseText:Hide()


    -- Config: accessibile dal clic destro sull'icona della minimappa e da
    -- /rls config (niente piu' icona rotellina nella barra principale).

    -- SaveRaid: icona salvataggio a sinistra dell'icona fase
    self.saveRaidBtn = CreateFrame("Button", "RLSuiteSaveRaidBtn", f)
    self.saveRaidBtn:SetSize(26, 26)
    RLSuite.utils:SkinBox(self.saveRaidBtn)
    local saveIcon = self.saveRaidBtn:CreateTexture(nil, "ARTWORK")
    saveIcon:SetPoint("TOPLEFT", self.saveRaidBtn, "TOPLEFT", 3, -3)
    saveIcon:SetPoint("BOTTOMRIGHT", self.saveRaidBtn, "BOTTOMRIGHT", -3, 3)
    saveIcon:SetTexture(RLSuite:AddonTexture("media\\save.blp"))
    self.saveRaidBtn:EnableMouse(true)
    self.saveRaidBtn:RegisterForClicks("LeftButtonUp")
    self.saveRaidBtn:SetScript("OnClick", function() self:OnSaveRaid() end)
    self.saveRaidBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("SaveRaid")
        GameTooltip:Show()
    end)
    self.saveRaidBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self:ApplyLayout()
end

function MW:ApplyLayout()
    local L = RLSuite.db and RLSuite.db.profile.layout and RLSuite.db.profile.layout.main
    if not self.frame then return end
    L = L or {}
    local cols = math.max(1, math.min(8, tonumber(L.matrixCols) or 2))
    local rows = math.max(1, math.min(8, tonumber(L.matrixRows) or 4))
    -- la matrice deve sempre contenere tutti i bottoni (6 tab): la coppia
    -- MT/OT occupa UNA cella extra; se le colonne sono poche, le righe
    -- minime crescono per non sforare
    local nButtons = #(self.matrixButtons or {})
    local extraCells = (self.mtBtn and self.otBtn) and 1 or 0
    if nButtons + extraCells > 0 then
        rows = math.max(rows, math.ceil((nButtons + extraCells) / cols))
    end

    -- Bottoni matrice: colonne x righe configurabili dalla Config.
    local bw, bh, gapX, gapY = 90, 22, 8, 4
    local PAD = 12
    local iconSize = 26                       -- icone (save/fase)
    local iconGap = 4                         -- spazio tra le icone
    local xSize = 32                          -- X di chiusura
    local rowGap = 6                          -- spazio tra riga icone e matrice

    local matrixW = cols * bw + (cols - 1) * gapX
    local matrixH = rows * bh + (rows - 1) * gapY

    -- Riga icone in alto, larga quanto la matrice: le 2 icone a sinistra,
    -- spazio vuoto, X rossa a destra. Se la matrice e' piu' stretta delle
    -- icone, riga e barra si allargano al minimo per contenerle.
    local iconRowH = math.max(iconSize, xSize)
    local iconsW = 2 * iconSize + 1 * iconGap
    local minRowW = iconsW + iconGap + xSize
    local contentW = math.max(matrixW, minRowW)

    local h = 2 * PAD + iconRowH + rowGap + matrixH
    local w = 2 * PAD + contentW

    self.frame:SetSize(w, h)
    self.frame:SetScale(L.scale or 1)

    -- Bottoni matrice: colonne x righe configurabili dalla Config.
    -- La coppia MT/OT sta SOTTO il tasto "Raid Frame" (cella
    -- i_raidframe + colonne) se quella cella e' dentro la matrice: i
    -- tasti seguenti scalano di una cella per lasciare il posto libero.
    -- Altrimenti (colonne troppe larghe) la coppia finisce nella cella
    -- subito dopo l'ultimo tasto, come prima.
    local x0 = PAD
    local topY = -PAD - iconRowH - rowGap
    local totalCells = nButtons + extraCells
    local rfIdx = nil
    for i, btn in ipairs(self.matrixButtons or {}) do
        if btn.tabKey == "raidframe" then rfIdx = i break end
    end
    local pinnedIdx = nil
    if rfIdx and extraCells > 0 then
        local p = rfIdx + cols
        if p <= totalCells then pinnedIdx = p end
    end
    local pairCell = pinnedIdx or totalCells
    local cell = 0
    for i, btn in ipairs(self.matrixButtons or {}) do
        cell = cell + 1
        if pinnedIdx and cell == pinnedIdx then cell = cell + 1 end
        local col = (cell - 1) % cols
        local row = math.floor((cell - 1) / cols)
        btn:ClearAllPoints()
        btn:SetSize(bw, bh)
        btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x0 + col * (bw + gapX), topY - row * (bh + gapY))
    end

    -- Coppia MT / OT nella cella scelta sopra: due mezzi tasti affiancati
    -- (insieme occupano lo spazio di un tasto solo).
    if self.mtBtn and self.otBtn then
        local idx = pairCell
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local halfGap = 4
        local halfW = (bw - halfGap) / 2
        local cellX = x0 + col * (bw + gapX)
        local cellY = topY - row * (bh + gapY)
        self.mtBtn:ClearAllPoints()
        self.mtBtn:SetSize(halfW, bh)
        self.mtBtn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", cellX, cellY)
        self.otBtn:ClearAllPoints()
        self.otBtn:SetSize(bw - halfW - halfGap, bh)
        self.otBtn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", cellX + halfW + halfGap, cellY)
    end

    -- riga icone in alto: save -> fase a sinistra, X a destra
    local iconY = -(iconRowH - iconSize) / 2
    if self.saveRaidBtn then
        self.saveRaidBtn:ClearAllPoints()
        self.saveRaidBtn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -PAD + iconY)
    end
    if self.phaseBtn then
        self.phaseBtn:ClearAllPoints()
        self.phaseBtn:SetPoint("TOPLEFT", self.saveRaidBtn or self.frame, "TOPRIGHT", iconGap, 0)
    end
    if self.closeBtn then
        self.closeBtn:ClearAllPoints()
        self.closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -PAD)
    end

    -- nome della fase accanto all'icona, solo se c'e' spazio fino alla X
    if self.phaseText and self.phaseBtn then
        self.phaseText:ClearAllPoints()
        self.phaseText:SetPoint("LEFT", self.phaseBtn, "RIGHT", iconGap + 2, 0)
        local available = contentW - iconsW - xSize - iconGap
        if available >= 58 then
            self.phaseText:Show()
        else
            self.phaseText:Hide()
        end
    end

    RLSuite.utils:SkinFrame(self.frame)
    self:UpdatePhaseButtons()
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
    elseif key == "log" then
        return RLSuite.combatLog and RLSuite.combatLog.frame
    end
    return nil
end

-- Layout key usato per salvare posizione/dimensione di ogni tab.
function MW:LayoutKeyForTab(key)
    if key == "group" then return "groupmaking" end
    if key == "raidframe" then return "raidframe" end
    if key == "log" then return "combatlog" end
    return key -- ms / loot
end

function MW:HideAllWindows()
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    local keys = { "group", "raidframe", "ms", "loot", "log" }
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
    RLSuite.windowMins.log = function()
        -- min width = riga dei tab in alto (16 + 8 tab da 86px + gap da 2),
        -- sotto i 724px i tasti sbordano fuori finestra.
        -- min height = stack reale: 78 (dropdown+tab+header) + 398 (liste)
        -- + ~30 (barra report/clear/live) + margini: sotto i 540 la barra
        -- inferiore clippa le liste.
        return 730, 540
    end

    -- Aggancia trascinamento + posizione persistente alle finestre dei tab.
    local layoutKeys = {
        group = "groupmaking",
        ms = "ms",
        loot = "loot",
        log = "combatlog",
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
        log = { "combatlog", 730, 540, "combatlog" },
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
        and key ~= "ms" and key ~= "loot" and key ~= "log" then
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
