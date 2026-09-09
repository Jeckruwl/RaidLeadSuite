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
        self:RefreshMacroTab()
    end
end

function MW:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteMainWindow", UIParent)
    f:SetSize(600, 500)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    f:Hide()
    self.frame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("RLSuite v" .. RLSuite.version)

    -- Tabs
    self.tabs = {}
    self.tabContents = {}
    self.currentTab = 1

    local tabNames = {"Raid Profile", "Groupmaking", "Config"}
    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", "RLSuiteTab" .. i, f, "CharacterFrameTabButtonTemplate")
        tab:SetSize(100, 24)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", 15 + (i-1) * 105, -40)
        tab:SetText(name)
        tab:SetID(i)
        tab:SetScript("OnClick", function() self:SelectTab(i) end)
        self.tabs[i] = tab
    end

    self.contentArea = CreateFrame("Frame", nil, f)
    self.contentArea:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -70)
    self.contentArea:SetSize(580, 420)

    self:CreateRaidProfileTab()
    self:CreateGroupmakingTab()
    self:CreateConfigTab()

    self:SelectTab(1)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
end

function MW:SelectTab(index)
    self.currentTab = index
    for i, tab in ipairs(self.tabs) do
        if i == index then
            PanelTemplates_SelectTab(tab)
            if self.tabContents[i] then
                self.tabContents[i]:Show()
            end
        else
            PanelTemplates_DeselectTab(tab)
            if self.tabContents[i] then
                self.tabContents[i]:Hide()
            end
        end
    end
end

-- TAB 1: RAID PROFILE
function MW:CreateRaidProfileTab()
    local content = CreateFrame("Frame", nil, self.contentArea)
    content:SetAllPoints(self.contentArea)
    content:Hide()
    self.tabContents[1] = content

    local subTabs = {"Macrobar", "Raid Frame"}
    self.subTabs = {}
    self.subContents = {}

    for i, name in ipairs(subTabs) do
        local st = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        st:SetSize(90, 22)
        st:SetPoint("TOPLEFT", content, "TOPLEFT", 10 + (i-1) * 95, 0)
        st:SetText(name)
        st:SetScript("OnClick", function() self:SelectSubTab(i) end)
        self.subTabs[i] = st
    end

    self.subContentArea = CreateFrame("Frame", nil, content)
    self.subContentArea:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -30)
    self.subContentArea:SetSize(580, 390)

    self:CreateMacrobarSubTab()
    self:CreateRaidFrameSubTab()
    self:SelectSubTab(1)
end

function MW:SelectSubTab(index)
    for i, st in ipairs(self.subTabs) do
        if i == index then
            st:LockHighlight()
            if self.subContents[i] then
                self.subContents[i]:Show()
            end
        else
            st:UnlockHighlight()
            if self.subContents[i] then
                self.subContents[i]:Hide()
            end
        end
    end
end

function MW:CreateMacrobarSubTab()
    local sc = CreateFrame("Frame", nil, self.subContentArea)
    sc:SetAllPoints(self.subContentArea)
    sc:Hide()
    self.subContents[1] = sc
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
    mbPreview:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 12,
    })

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
    openBtn:SetText("Apri MacroBar")
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
    local sc = CreateFrame("Frame", nil, self.subContentArea)
    sc:SetAllPoints(self.subContentArea)
    sc:Hide()
    self.subContents[2] = sc

    local rfLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rfLabel:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -10)
    rfLabel:SetText("Raid Frame Appearance:")

    local preview = CreateFrame("Frame", nil, sc)
    preview:SetSize(300, 100)
    preview:SetPoint("TOPLEFT", rfLabel, "BOTTOMLEFT", 0, -10)
    preview:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 12,
    })

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

-- TAB 2: GROUPMAKING
function MW:CreateGroupmakingTab()
    local content = CreateFrame("Frame", nil, self.contentArea)
    content:SetAllPoints(self.contentArea)
    content:Hide()
    self.tabContents[2] = content

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", content, "CENTER")
    text:SetText("Usa /rls group per la finestra Groupmaking completa")

    local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btn:SetSize(150, 25)
    btn:SetPoint("TOP", text, "BOTTOM", 0, -10)
    btn:SetText("Apri Groupmaking")
    btn:SetScript("OnClick", function()
        if RLSuite.groupmaking and RLSuite.groupmaking.Toggle then
            RLSuite.groupmaking:Toggle()
        end
    end)
end

-- TAB 3: CONFIG
function MW:CreateConfigTab()
    local content = CreateFrame("Frame", nil, self.contentArea)
    content:SetAllPoints(self.contentArea)
    content:Hide()
    self.tabContents[3] = content

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", content, "CENTER")
    text:SetText("Usa /rls config per la finestra Config completa")

    local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btn:SetSize(150, 25)
    btn:SetPoint("TOP", text, "BOTTOM", 0, -10)
    btn:SetText("Apri Config")
    btn:SetScript("OnClick", function()
        if RLSuite.config and RLSuite.config.Toggle then
            RLSuite.config:Toggle()
        end
    end)
end
