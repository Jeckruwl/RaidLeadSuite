-- ============================================================
-- RLSuite - RaidProfile Module (Main Window)
-- ============================================================

RLSuite.mainWindow = {}
local MW = RLSuite.mainWindow

function MW:Init()
    self:CreateFrame()
    self:RegisterAllWindows()
end

function MW:Toggle()
    if self.frame and self.frame:IsShown() then
        self:CloseTab()
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
        self:CloseTab()
        -- /rls mostra anche l'HUD MacroBar (se abilitata e non gia' visibile)
        self:ShowMacrobarHud()
    end
end

-- Mostra la HUD MacroBar insieme alla barra (usata da /rls).
function MW:ShowMacrobarHud()
    local mb = RLSuite.macrobar
    if not mb or not mb.frame then return end
    if RLSuiteDB.macrobar and RLSuiteDB.macrobar.enabled == false then return end
    local pset = mb.PhaseSettings and mb:PhaseSettings()
    if pset and pset.enabled == false then return end
    if not mb.frame:IsShown() then
        mb.frame:Show()
        if mb.ApplyLayout then mb:ApplyLayout() end
    end
    self:RefreshTabHighlights()
end

function MW:ShowTab(key)
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
    self:HideAllWindows()
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
    local pane = self:PaneForTab(key)
    if pane then pane:Hide() end
    if self.currentTab == key then self.currentTab = nil end
    self:UpdateTabHighlight(key)
end

-- Il tab resta evidenziato finche' la sua finestra e' aperta.
function MW:UpdateTabHighlight(key)
    local tab = self.tabs and self.tabs[key]
    if not tab then return end
    local open
    if key == "macro" then
        open = RLSuite.macrobar and RLSuite.macrobar.frame and RLSuite.macrobar.frame:IsShown()
    else
        open = self:IsTabOpen(key)
    end
    if open then
        tab:LockHighlight()
    else
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
    local ALL_KEYS = { "group", "whisplist", "raidframe", "ms", "loot", "config" }
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
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    self.frame = f
    RLSuite.utils:SkinFrame(f)

    -- Niente titolo: la barra contiene solo i bottoni (matrice + fase +
    -- X di chiusura e rotellina Config). Il tab Config e' la rotellina.

    self.tabDefs = {
        { key = "group",     label = "Groupmaking" },
        { key = "whisplist", label = "Whisplist" },
        { key = "macro",     label = "Macrobar" },
        { key = "raidframe", label = "Raid Frame" },
        { key = "ms",        label = "MS" },
        { key = "loot",      label = "Loot" },
    }
    self.tabs = {}
    self.tabPanels = {}
    self.currentTab = nil

    -- Matrice colonne x righe configurabile: 6 tab
    self.matrixButtons = {}
    for i, def in ipairs(self.tabDefs) do
        local tab = CreateFrame("Button", "RLSuiteTab" .. def.key, f, "UIPanelButtonTemplate")
        tab:SetSize(90, 22)
        tab:SetText(def.label)
        tab.tabKey = def.key
        tab:SetScript("OnClick", function() self:OnTabClick(def.key) end)
        self.tabs[def.key] = tab
        table.insert(self.matrixButtons, tab)
    end

    -- Icona fase singola: sotto la rotellina Config, cambia in base alla
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
    RLSuite.utils:SkinBox(self.phaseBtn)
    local phaseIcon = self.phaseBtn:CreateTexture(nil, "ARTWORK")
    phaseIcon:SetPoint("TOPLEFT", self.phaseBtn, "TOPLEFT", 3, -3)
    phaseIcon:SetPoint("BOTTOMRIGHT", self.phaseBtn, "BOTTOMRIGHT", -3, 3)
    self.phaseBtn.icon = phaseIcon
    self.phaseBtn:SetScript("OnClick", function()
        if RLSuite.CycleContextPhase then
            RLSuite:CycleContextPhase()
        end
    end)
    self.phaseBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(s.label or "Fase")
        GameTooltip:Show()
    end)
    self.phaseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Testo con il nome della fase, mostrato accanto all'icona fase
    -- quando c'e' spazio sufficiente fino alla X di chiusura.
    self.phaseText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.phaseText:SetTextColor(1, 0.82, 0)
    self.phaseText:SetJustifyH("LEFT")
    self.phaseText:Hide()

    self:CreateRaidFrameSubTab()

    self.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    self.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    self.closeBtn:SetScript("OnClick", function()
        self:CloseTab()
        f:Hide()
    end)

    -- Config: icona a rotellina sotto la X rossa (sostituisce il tab Config)
    self.configBtn = CreateFrame("Button", nil, f)
    self.configBtn:SetSize(26, 26)
    RLSuite.utils:SkinBox(self.configBtn)
    local gear = self.configBtn:CreateTexture(nil, "ARTWORK")
    gear:SetPoint("TOPLEFT", self.configBtn, "TOPLEFT", 3, -3)
    gear:SetPoint("BOTTOMRIGHT", self.configBtn, "BOTTOMRIGHT", -3, 3)
    gear:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    self.configBtn:SetScript("OnClick", function() self:ShowTab("config") end)
    self.configBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Config")
        GameTooltip:Show()
    end)
    self.configBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- SaveRaid: icona salvataggio tra la rotellina Config e l'icona fase
    self.saveRaidBtn = CreateFrame("Button", "RLSuiteSaveRaidBtn", f)
    self.saveRaidBtn:SetSize(26, 26)
    RLSuite.utils:SkinBox(self.saveRaidBtn)
    local saveIcon = self.saveRaidBtn:CreateTexture(nil, "ARTWORK")
    saveIcon:SetPoint("TOPLEFT", self.saveRaidBtn, "TOPLEFT", 3, -3)
    saveIcon:SetPoint("BOTTOMRIGHT", self.saveRaidBtn, "BOTTOMRIGHT", -3, 3)
    saveIcon:SetTexture(RLSuite:AddonTexture("media\\save.blp"))
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
    local L = RLSuiteDB and RLSuiteDB.layout and RLSuiteDB.layout.main
    if not self.frame then return end
    L = L or {}
    local cols = math.max(1, math.min(8, tonumber(L.matrixCols) or 2))
    local rows = math.max(1, math.min(8, tonumber(L.matrixRows) or 4))
    -- la matrice deve sempre contenere tutti i bottoni (6 tab):
    -- se le colonne sono poche, le righe minime crescono per non sforare
    local nButtons = #(self.matrixButtons or {})
    if nButtons > 0 then
        rows = math.max(rows, math.ceil(nButtons / cols))
    end

    -- Bottoni matrice: colonne x righe configurabili dalla Config.
    local bw, bh, gapX, gapY = 90, 22, 8, 4
    local PAD = 12
    local iconSize = 26                       -- icone (rotellina/save/fase)
    local iconGap = 4                         -- spazio tra le icone
    local xSize = 32                          -- X di chiusura
    local rowGap = 6                          -- spazio tra riga icone e matrice

    local matrixW = cols * bw + (cols - 1) * gapX
    local matrixH = rows * bh + (rows - 1) * gapY

    -- Riga icone in alto, larga quanto la matrice: le 3 icone a sinistra,
    -- spazio vuoto, X rossa a destra. Se la matrice e' piu' stretta delle
    -- icone, riga e barra si allargano al minimo per contenerle.
    local iconRowH = math.max(iconSize, xSize)
    local iconsW = 3 * iconSize + 2 * iconGap
    local minRowW = iconsW + iconGap + xSize
    local contentW = math.max(matrixW, minRowW)

    local h = 2 * PAD + iconRowH + rowGap + matrixH
    local w = 2 * PAD + contentW

    self.frame:SetSize(w, h)
    self.frame:SetScale(L.scale or 1)

    -- matrice (sotto la riga icone, allineata a sinistra)
    local x0 = PAD
    local topY = -PAD - iconRowH - rowGap
    for i, btn in ipairs(self.matrixButtons or {}) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        btn:ClearAllPoints()
        btn:SetSize(bw, bh)
        btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x0 + col * (bw + gapX), topY - row * (bh + gapY))
    end

    -- riga icone in alto: rotellina -> save -> fase a sinistra, X a destra
    local iconY = -(iconRowH - iconSize) / 2
    if self.configBtn then
        self.configBtn:ClearAllPoints()
        self.configBtn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -PAD + iconY)
    end
    if self.saveRaidBtn then
        self.saveRaidBtn:ClearAllPoints()
        self.saveRaidBtn:SetPoint("TOPLEFT", self.configBtn or self.frame, "TOPRIGHT", iconGap, 0)
    end
    if self.phaseBtn then
        self.phaseBtn:ClearAllPoints()
        self.phaseBtn:SetPoint("TOPLEFT", self.saveRaidBtn or self.configBtn or self.frame, "TOPRIGHT", iconGap, 0)
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
    local u = RLSuite.utils
    u:SkinBox(self.rfPreview)
    u:SkinBox(self.rfAlertBox)
end

function MW:PaneForTab(key)
    if key == "group" then
        return RLSuite.groupmaking and RLSuite.groupmaking.mainFrame
    elseif key == "whisplist" then
        return RLSuite.groupmaking and RLSuite.groupmaking.whisplistFrame
    elseif key == "raidframe" then
        return self.tabPanels and self.tabPanels.raidframe
    elseif key == "ms" then
        return RLSuite.msManager and RLSuite.msManager.frame
    elseif key == "loot" then
        return RLSuite.lootManager and RLSuite.lootManager.frame
    elseif key == "config" then
        return RLSuite.config and RLSuite.config.frame
    end
    return nil
end

-- Layout key usato per salvare posizione/dimensione di ogni tab.
function MW:LayoutKeyForTab(key)
    if key == "group" then return "groupmaking" end
    if key == "whisplist" then return "whisplist" end
    if key == "raidframe" then return "raidframe" end
    return key -- ms / loot / config
end

function MW:HideAllWindows()
    local keys = { "group", "whisplist", "raidframe", "ms", "loot", "config" }
    for _, k in ipairs(keys) do
        local pane = self:PaneForTab(k)
        if pane then pane:Hide() end
    end
end

function MW:RegisterAllWindows()
    -- Minimi di contenuto per le finestre ridimensionabili.
    -- Vengono ri-calcolati a ogni drag; quello di Groupmaking dipende
    -- dalla composizione corrente (10/25), gli altri sono fissi perche'
    -- i loro layout interni non cambiano con la difficolta'.
    RLSuite.windowMins = RLSuite.windowMins or {}
    RLSuite.windowMins.groupmaking = function()
        -- Larghezza minima: fila di controlli in basso (3 bottoni +
        -- checkbox "Show specs in message") e le due colonne comp/class.
        -- Altezza: pila verticale title+dropdowns, gruppo slot (topRow),
        -- box "richieste" e blocco basso anteprima+bottoni.
        local topH = 156
        local gm = RLSuite.groupmaking
        if gm and gm.topRow then
            local th = gm.topRow:GetHeight()
            if th and th > 60 then topH = th end
        end
        return 500, topH + 286
    end
    RLSuite.windowMins.whisplist = function()
        -- La meta' destra (wlDetailBox) deve contenere la riga di bottoni
        -- Invite / Ask GS / Ask Achi: se i bottoni sono piu' larghi del
        -- box, la larghezza minima cresce per non farli uscire.
        local gm = RLSuite.groupmaking
        local btnW = 66
        if gm and gm.wlInviteBtn then
            btnW = gm.wlInviteBtn:GetWidth() or 66
        end
        local rowW = 10 + 3 * btnW + 2 * 4 + 10
        local minW = math.max(500, (rowW + 22) * 2)
        return minW, 380
    end
    RLSuite.windowMins.ms = function()
        return 350, 280
    end
    RLSuite.windowMins.loot = function()
        return 480, 340
    end
    RLSuite.windowMins.raidframe = function()
        -- label+bottono HUD, box anteprima (100) e box Alert Messages
        -- con 3 righe di edit: larghezza/altezza minime per il pannello tab.
        return 420, 320
    end

    -- Aggancia trascinamento + posizione persistente alle finestre dei tab.
    local layoutKeys = {
        group = "groupmaking",
        whisplist = "whisplist",
        raidframe = "raidframe",
        ms = "ms",
        loot = "loot",
        config = "config",
    }
    for key, lkey in pairs(layoutKeys) do
        local pane = self:PaneForTab(key)
        if pane and not pane._rlsWindow then
            pane._rlsWindow = true
            RLSuite.utils:MakeDraggable(pane, lkey)
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

    -- Grip di resize per Groupmaking, Whisplist, MS, Loot e Raid Frame tab
    local resizable = {
        group = { "groupmaking", 420, 380, "groupmaking" },
        whisplist = { "whisplist", 360, 300, "whisplist" },
        ms = { "ms", 320, 260, "ms" },
        loot = { "loot", 440, 300, "loot" },
        raidframe = { "raidframe", 420, 320, "raidframe" },
    }
    for key, cfg in pairs(resizable) do
        local pane = self:PaneForTab(key)
        if pane then
            RLSuite.utils:AddResizeGrip(pane, cfg[1], cfg[2], cfg[3], function()
                if key == "group" and RLSuite.groupmaking then
                    if RLSuite.groupmaking.LayoutGroupPanels then RLSuite.groupmaking:LayoutGroupPanels() end
                end
                if key == "whisplist" and RLSuite.groupmaking then
                    if RLSuite.groupmaking.UpdateWhisplist then RLSuite.groupmaking:UpdateWhisplist() end
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
    if key ~= "group" and key ~= "whisplist" and key ~= "raidframe"
        and key ~= "ms" and key ~= "loot" and key ~= "config" then
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
        local mL = (RLSuiteDB.layout and RLSuiteDB.layout.main) or {}
        local pw = L.width or mL.width or 660
        local ph = L.height or mL.height or 700
        -- mai piu' piccolo del contenuto della finestra
        local mw, mh = RLSuite.utils:WindowMin(lkey, pane)
        if mw then
            pw = math.max(pw, mw)
            ph = math.max(ph, mh)
        end
        pane:SetSize(pw, ph)
        RLSuite.utils:ApplySavedPos(pane, lkey, function()
            return self:DefaultCascadeOffset(key)
        end)
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
    elseif key == "whisplist" then
        if RLSuite.groupmaking and RLSuite.groupmaking.UpdateWhisplist then
            RLSuite.groupmaking:UpdateWhisplist()
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

function MW:CreateRaidFrameSubTab()
    local sc = CreateFrame("Frame", "RLSuiteRaidFrameTab", self.frame)
    sc:SetSize(660, 700)
    sc:Hide()
    self.tabPanels = self.tabPanels or {}
    self.tabPanels.raidframe = sc

    local rfLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rfLabel:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -10)
    rfLabel:SetText("Raid Frame Appearance:")

    local hudBtn = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
    hudBtn:SetSize(160, 22)
    hudBtn:SetPoint("LEFT", rfLabel, "RIGHT", 16, 0)
    hudBtn:SetText("Mostra/Nascondi HUD")
    hudBtn:SetScript("OnClick", function()
        if RLSuite.raidFrame and RLSuite.raidFrame.Toggle then
            RLSuite.raidFrame:Toggle()
        end
    end)

    local preview = CreateFrame("Frame", nil, sc)
    preview:SetPoint("TOPLEFT", rfLabel, "BOTTOMLEFT", 0, -10)
    preview:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -10, -42)
    preview:SetHeight(100)
    RLSuite.utils:SkinBox(preview)
    self.rfPreview = preview

    local example = CreateFrame("Frame", nil, preview)
    example:SetSize(280, 22)
    example:SetPoint("TOPLEFT", preview, "TOPLEFT", 10, -10)

    local alert = example:CreateTexture(nil, "OVERLAY")
    alert:SetSize(16, 16)
    alert:SetPoint("LEFT", example, "LEFT")
    alert:SetTexture("Interface\Icons\INV_Alchemy_EndlessFlask_01")

    local name = example:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", alert, "RIGHT", 5, 0)
    name:SetText("PlayerName")
    name:SetTextColor(1, 0.8, 0.2)

    local hpBar = CreateFrame("StatusBar", nil, example)
    hpBar:SetSize(100, 16)
    hpBar:SetPoint("LEFT", name, "RIGHT", 10, 0)
    hpBar:SetStatusBarTexture("Interface\TargetingFrame\UI-StatusBar")
    hpBar:SetStatusBarColor(0, 1, 0)
    hpBar:SetMinMaxValues(0, 100)
    hpBar:SetValue(75)

    local hpText = hpBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hpText:SetPoint("CENTER", hpBar, "CENTER")
    hpText:SetText("75%")

    for j = 1, 3 do
        local cd = example:CreateTexture(nil, "OVERLAY")
        cd:SetSize(16, 16)
        cd:SetPoint("LEFT", hpBar, "RIGHT", 10 + (j-1)*18, 0)
        cd:SetTexture("Interface\Icons\INV_Misc_QuestionMark")
    end

    local alertBox = CreateFrame("Frame", nil, sc)
    alertBox:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -10)
    alertBox:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -10, 10)
    RLSuite.utils:SkinBox(alertBox)
    self.rfAlertBox = alertBox

    local alertLabel = alertBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alertLabel:SetPoint("TOPLEFT", alertBox, "TOPLEFT", 10, -10)
    alertLabel:SetText("Alert Messages")
    alertLabel:SetTextColor(1, 0.82, 0)

    local alertTypes = {"flask", "food", "buff"}
    for i, atype in ipairs(alertTypes) do
        local aLabel = alertBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        aLabel:SetPoint("TOPLEFT", alertBox, "TOPLEFT", 10, -32 - (i-1)*30)
        aLabel:SetWidth(50)
        aLabel:SetText(string.upper(atype) .. ":")

        local edit = CreateFrame("EditBox", "RLSuiteAlertEdit_" .. atype, alertBox, "InputBoxTemplate")
        edit:SetHeight(18)
        edit:SetPoint("LEFT", aLabel, "RIGHT", 8, 0)
        edit:SetPoint("RIGHT", alertBox, "RIGHT", -16, 0)
        edit:SetAutoFocus(false)
        local alerts = RLSuiteDB.raidframe.alerts or {}
        edit:SetText(alerts[atype] or "")
        edit:SetScript("OnTextChanged", function(s)
            RLSuiteDB.raidframe.alerts = RLSuiteDB.raidframe.alerts or {}
            RLSuiteDB.raidframe.alerts[atype] = s:GetText()
        end)
    end
end


-- ============================================================
-- SaveRaid: prompt titolo + salvataggio
-- ============================================================
function MW:OnSaveRaid()
    self:AskRaidTitle(function(title)
        if not title or title == "" then
            RLSuite.utils:Print("SaveRaid annullato: nessun titolo inserito.")
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
    label:SetText("Titolo del SaveRaid:")

    local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    edit:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    edit:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -40)
    edit:SetHeight(20)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(64)
    f.edit = edit

    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(90, 22)
    ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    ok:SetText("Salva")
    ok:SetScript("OnClick", function()
        local cb = f._cb
        f:Hide()
        if cb then cb(edit:GetText() or "") end
    end)

    local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancel:SetSize(90, 22)
    cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
    cancel:SetText("Annulla")
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
