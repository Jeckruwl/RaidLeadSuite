-- ============================================================
-- RLSuite - RaidProfile Module (Main Window)
-- ============================================================

RLSuite.mainWindow = {}
local MW = RLSuite.mainWindow

function MW:Init()
    self:CreateFrame()
end

function MW:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
        self:SelectTab(self.currentTab or "group")
    end
end

function MW:ShowTab(key)
    if not self.frame then return end
    self.frame:Show()
    self:SelectTab(key)
end

function MW:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteMainWindow", UIParent)
    f:SetSize(660, 700)
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

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("RLSuite v" .. RLSuite.version)
    self.titleFS = title

    self.tabDefs = {
        { key = "group",     label = "Groupmaking" },
        { key = "whisplist", label = "Whisplist" },
        { key = "macro",     label = "Macrobar" },
        { key = "raidframe", label = "Raid Frame" },
        { key = "ms",        label = "MS" },
        { key = "loot",      label = "Loot" },
        { key = "config",    label = "Config" },
    }
    self.tabs = {}
    self.tabPanels = {}
    self.currentTab = "group"

    for i, def in ipairs(self.tabDefs) do
        local tab = CreateFrame("Button", "RLSuiteTab" .. def.key, f, "UIPanelButtonTemplate")
        tab:SetSize(84, 22)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + (i - 1) * 90, -40)
        tab:SetText(def.label)
        tab.tabKey = def.key
        tab:SetScript("OnClick", function() self:SelectTab(def.key) end)
        self.tabs[def.key] = tab
    end

    self.contentArea = CreateFrame("Frame", nil, f)
    self.contentArea:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70)
    self.contentArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)

    self:CreateMacrobarSubTab()
    self:CreateRaidFrameSubTab()

    self.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    self.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    self.closeBtn:SetScript("OnClick", function() f:Hide() end)

    self:SelectTab("group")
    self:ApplyLayout()
end

function MW:ApplyLayout()
    local L = RLSuiteDB and RLSuiteDB.layout and RLSuiteDB.layout.main
    if not L or not self.frame then return end
    self.frame:SetSize(L.width or 660, L.height or 700)
    self.frame:SetScale(L.scale or 1)
    local font, size = RLSuite.utils:GetUIFont()
    if self.titleFS then
        self.titleFS:SetFont(font, size + 2)
        self.titleFS:SetText("RLSuite v" .. RLSuite.version)
    end
    RLSuite.utils:SkinFrame(self.frame)
end

function MW:Dock(frame)
    if not frame then return end
    frame:SetParent(self.contentArea)
    frame:ClearAllPoints()
    frame:SetAllPoints(self.contentArea)
    frame:SetFrameStrata(self.frame:GetFrameStrata())
    frame:SetFrameLevel(self.contentArea:GetFrameLevel() + 3)
    frame:SetMovable(false)
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    if frame.closeBtn then frame.closeBtn:Hide() end
    RLSuite.utils:SkinFrame(frame)
    frame:Show()
end

function MW:HideDocked()
    local frames = {
        RLSuite.groupmaking and RLSuite.groupmaking.mainFrame,
        RLSuite.groupmaking and RLSuite.groupmaking.whisplistFrame,
        RLSuite.msManager and RLSuite.msManager.frame,
        RLSuite.lootManager and RLSuite.lootManager.frame,
        RLSuite.config and RLSuite.config.frame,
        self.tabPanels and self.tabPanels.macro,
        self.tabPanels and self.tabPanels.raidframe,
    }
    for _, fr in ipairs(frames) do
        if fr then fr:Hide() end
    end
end

function MW:SelectTab(key)
    if type(key) == "number" then
        local def = self.tabDefs and self.tabDefs[key]
        key = def and def.key or "group"
    end
    self.currentTab = key or "group"
    for k, tab in pairs(self.tabs or {}) do
        if k == self.currentTab then
            tab:LockHighlight()
        else
            tab:UnlockHighlight()
        end
    end

    self:HideDocked()

    if key == "group" then
        self:Dock(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame)
        if RLSuite.groupmaking and RLSuite.groupmaking.UpdateMessagePreview then
            RLSuite.groupmaking:UpdateMessagePreview()
        end
    elseif key == "whisplist" then
        self:Dock(RLSuite.groupmaking and RLSuite.groupmaking.whisplistFrame)
        if RLSuite.groupmaking and RLSuite.groupmaking.UpdateWhisplist then
            RLSuite.groupmaking:UpdateWhisplist()
        end
    elseif key == "macro" then
        if self.tabPanels.macro then
            self.tabPanels.macro:SetParent(self.contentArea)
            self.tabPanels.macro:ClearAllPoints()
            self.tabPanels.macro:SetAllPoints(self.contentArea)
            self.tabPanels.macro:Show()
        end
        self:RefreshMacroTab()
    elseif key == "raidframe" then
        if self.tabPanels.raidframe then
            self.tabPanels.raidframe:SetParent(self.contentArea)
            self.tabPanels.raidframe:ClearAllPoints()
            self.tabPanels.raidframe:SetAllPoints(self.contentArea)
            self.tabPanels.raidframe:Show()
        end
    elseif key == "ms" then
        self:Dock(RLSuite.msManager and RLSuite.msManager.frame)
        if RLSuite.msManager and RLSuite.msManager.UpdateList then
            RLSuite.msManager:UpdateList()
        end
    elseif key == "loot" then
        self:Dock(RLSuite.lootManager and RLSuite.lootManager.frame)
        if RLSuite.lootManager and RLSuite.lootManager.UpdateHistory then
            RLSuite.lootManager:UpdateHistory()
        end
    elseif key == "config" then
        self:Dock(RLSuite.config and RLSuite.config.frame)
    end
end

function MW:CreateMacrobarSubTab()
    local sc = CreateFrame("Frame", nil, self.contentArea)
    sc:SetAllPoints(self.contentArea)
    sc:Hide()
    self.tabPanels = self.tabPanels or {}
    self.tabPanels.macro = sc
    self.macroPhase = RLSuite.context or "preraid"
    self.macroPreviewBtns = {}
    self.macroEdits = {}
    self.macroPhaseBtns = {}
    self.macroLoading = false

    local mbLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mbLabel:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -10)
    mbLabel:SetText("Macrobar (collegate al DB, 12 slot):")

    local mbPreview = CreateFrame("Frame", nil, sc)
    mbPreview:SetSize(300, 80)
    mbPreview:SetPoint("TOPLEFT", mbLabel, "BOTTOMLEFT", 0, -5)
    RLSuite.utils:SkinFrame(mbPreview)

    for i = 1, 12 do
        local btn = CreateFrame("Button", nil, mbPreview)
        btn:SetSize(32, 32)
        local col = (i - 1) % 6
        local row = math.floor((i - 1) / 6)
        btn:SetPoint("TOPLEFT", mbPreview, "TOPLEFT", 8 + col * 36, -8 - row * 36)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-Quickslot",
            edgeFile = "Interface\\Buttons\\UI-Quickslot",
            tile = false, tileSize = 32, edgeSize = 32,
        })
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints(btn)
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(s, button)
            if button == "RightButton" and RLSuite.macrobar and RLSuite.macrobar.OpenMacroEdit then
                RLSuite.macrobar:OpenMacroEdit(i)
            elseif self.macroEdits[i] then
                self.macroEdits[i]:SetFocus()
            end
        end)
        local num = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
        num:SetFont("Fonts\\FRIZQT__.TTF", 8)
        num:SetText(i)
        self.macroPreviewBtns[i] = btn
    end

    local phaseLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phaseLabel:SetPoint("TOPLEFT", mbPreview, "BOTTOMLEFT", 0, -12)
    phaseLabel:SetText("Fase:")

    local phases = {
        {key = "preraid", label = "Pre-raid"},
        {key = "preboss", label = "Pre-boss"},
        {key = "infight", label = "In-fight"},
    }
    for i, pdata in ipairs(phases) do
        local btn = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
        btn:SetSize(80, 20)
        btn:SetPoint("LEFT", phaseLabel, "RIGHT", 8 + (i - 1) * 86, 0)
        btn:SetText(pdata.label)
        btn.phaseKey = pdata.key
        btn:SetScript("OnClick", function()
            self:SelectMacroPhase(pdata.key)
        end)
        self.macroPhaseBtns[pdata.key] = btn
    end

    local hint = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", phaseLabel, "BOTTOMLEFT", 0, -8)
    hint:SetText("Testo salvato automaticamente. Tasto destro sull'icona per l'editor avanzato.")

    for j = 1, 12 do
        local lab = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lab:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6 - (j - 1) * 20)
        lab:SetWidth(20)
        lab:SetJustifyH("LEFT")
        lab:SetText(tostring(j))

        local edit = CreateFrame("EditBox", "RLSuiteMainMacroEdit" .. j, sc, "InputBoxTemplate")
        edit:SetSize(500, 18)
        edit:SetPoint("LEFT", lab, "RIGHT", 8, 0)
        edit:SetAutoFocus(false)
        edit.slotIndex = j
        edit:SetScript("OnTextChanged", function(s)
            if MW.macroLoading then return end
            MW:SaveMacroLine(s.slotIndex, s:GetText())
        end)
        self.macroEdits[j] = edit
    end

    local openBtn = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
    openBtn:SetSize(130, 22)
    openBtn:SetPoint("TOPLEFT", mbPreview, "TOPRIGHT", 15, -5)
    openBtn:SetText("Mostra/Nascondi HUD")
    openBtn:SetScript("OnClick", function()
        if RLSuite.macrobar and RLSuite.macrobar.Toggle then
            RLSuite.macrobar:Toggle()
        end
    end)

    self:SelectMacroPhase(self.macroPhase)
end

function MW:SelectMacroPhase(phase)
    self.macroPhase = phase or "preraid"
    for key, btn in pairs(self.macroPhaseBtns or {}) do
        if key == self.macroPhase then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end
    self:RefreshMacroTab()
end

function MW:GetMacroDB(phase)
    phase = phase or self.macroPhase or "preraid"
    if not RLSuiteDB or not RLSuiteDB.macrobar then return {} end
    RLSuiteDB.macrobar.macros = RLSuiteDB.macrobar.macros or {}
    RLSuiteDB.macrobar.macros[phase] = RLSuiteDB.macrobar.macros[phase] or {}
    return RLSuiteDB.macrobar.macros[phase]
end

function MW:SaveMacroLine(index, text)
    local phase = self.macroPhase or "preraid"
    local macros = self:GetMacroDB(phase)
    local current = macros[index] or {text = "", icon = "Interface\\Icons\\INV_Misc_QuestionMark"}
    current.text = text or ""
    current.icon = current.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    macros[index] = current
    if RLSuite.macrobar and RLSuite.macrobar.LoadMacrosForPhase then
        if (RLSuite.context or "preraid") == phase then
            RLSuite.macrobar:LoadMacrosForPhase(phase)
        end
    end
    self:RefreshMacroPreview()
end

function MW:RefreshMacroTab()
    if not self.macroEdits then return end
    self.macroLoading = true
    local macros = self:GetMacroDB(self.macroPhase)
    for j = 1, 12 do
        local data = macros[j]
        local text = (data and data.text) or ""
        if self.macroEdits[j] then
            self.macroEdits[j]:SetText(text)
        end
    end
    self.macroLoading = false
    self:RefreshMacroPreview()
end

function MW:RefreshMacroPreview()
    local macros = self:GetMacroDB(self.macroPhase)
    for i, btn in ipairs(self.macroPreviewBtns or {}) do
        local data = macros[i]
        if btn and btn.icon then
            if data and data.text and data.text ~= "" then
                btn.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            else
                btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
    end
end

function MW:CreateRaidFrameSubTab()
    local sc = CreateFrame("Frame", nil, self.contentArea)
    sc:SetAllPoints(self.contentArea)
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
    preview:SetSize(300, 100)
    preview:SetPoint("TOPLEFT", rfLabel, "BOTTOMLEFT", 0, -10)
    RLSuite.utils:SkinFrame(preview)

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

    local alertLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alertLabel:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -20)
    alertLabel:SetText("Alert Messages:")

    local alertTypes = {"flask", "food", "buff"}
    for i, atype in ipairs(alertTypes) do
        local aLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        aLabel:SetPoint("TOPLEFT", alertLabel, "BOTTOMLEFT", 0, -10 - (i-1)*30)
        aLabel:SetText(string.upper(atype) .. ":")

        local edit = CreateFrame("EditBox", "RLSuiteAlertEdit_" .. atype, sc, "InputBoxTemplate")
        edit:SetSize(400, 18)
        edit:SetPoint("LEFT", aLabel, "RIGHT", 10, 0)
        edit:SetAutoFocus(false)
        local alerts = RLSuiteDB.raidframe.alerts or {}
        edit:SetText(alerts[atype] or "")
        edit:SetScript("OnTextChanged", function(s)
            RLSuiteDB.raidframe.alerts = RLSuiteDB.raidframe.alerts or {}
            RLSuiteDB.raidframe.alerts[atype] = s:GetText()
        end)
    end
end

