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

function MW:SkinInner()
    local u = RLSuite.utils
    u:SkinBox(self.macroPreview)
    u:SkinBox(self.macroEditor)
    u:SkinBox(self.macroListFrame)
    u:SkinBox(self.macroBodyFrame)
    u:SkinBox(self.rfPreview)
    u:SkinBox(self.rfAlertBox)
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
    self.macroPhaseBtns = {}
    self.macroLoading = false
    self.macroEditIndex = nil
    self.macroEditIcon = nil

    local phaseLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phaseLabel:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -10)
    phaseLabel:SetText("Fase:")

    local phases = {
        {key = "preraid", label = "Pre-raid"},
        {key = "preboss", label = "Pre-boss"},
        {key = "infight", label = "In-fight"},
    }
    for i, pdata in ipairs(phases) do
        local btn = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
        btn:SetSize(90, 22)
        btn:SetPoint("LEFT", phaseLabel, "RIGHT", 8 + (i - 1) * 96, 0)
        btn:SetText(pdata.label)
        btn.phaseKey = pdata.key
        btn:SetScript("OnClick", function()
            self:SelectMacroPhase(pdata.key)
        end)
        self.macroPhaseBtns[pdata.key] = btn
    end

    local openBtn = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
    openBtn:SetSize(150, 22)
    openBtn:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -10, -8)
    openBtn:SetText("Mostra/Nascondi HUD")
    openBtn:SetScript("OnClick", function()
        if RLSuite.macrobar and RLSuite.macrobar.Toggle then
            RLSuite.macrobar:Toggle()
        end
    end)

    local hudLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hudLabel:SetPoint("TOPLEFT", phaseLabel, "BOTTOMLEFT", 0, -12)
    hudLabel:SetText("Anteprima HUD (clic sinistro = editor):")

    local mbPreview = CreateFrame("Frame", nil, sc)
    mbPreview:SetSize(616, 52)
    mbPreview:SetPoint("TOPLEFT", hudLabel, "BOTTOMLEFT", 0, -4)
    RLSuite.utils:SkinBox(mbPreview)
    self.macroPreview = mbPreview

    for i = 1, 12 do
        local btn = CreateFrame("Button", nil, mbPreview)
        btn:SetSize(36, 36)
        btn:SetPoint("TOPLEFT", mbPreview, "TOPLEFT", 10 + (i - 1) * 50, -8)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        RLSuite.utils:SkinMacroButton(btn)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function()
            MW:OpenMacroEditor(i)
        end)
        local num = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
        num:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        num:SetText(i)
        self.macroPreviewBtns[i] = btn
    end

    local editor = CreateFrame("Frame", "RLSuiteMacroEditor", sc)
    editor:SetPoint("TOPLEFT", mbPreview, "BOTTOMLEFT", 0, -8)
    editor:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -10, 10)
    RLSuite.utils:SkinBox(editor)
    editor:Show()
    self.macroEditor = editor

    local list = CreateFrame("Frame", nil, editor)
    list:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -8, -8)
    list:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -8, 8)
    list:SetWidth(300)
    RLSuite.utils:SkinBox(list)
    self.macroListFrame = list

    local listTitle = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -8)
    listTitle:SetText("Tutte le macro")

    self.macroListRows = {}
    for i = 1, 12 do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -26 - (i - 1) * 22)
        row:SetPoint("RIGHT", list, "RIGHT", -6, 0)
        local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("LEFT", row, "LEFT", 2, 0)
        num:SetWidth(16)
        num:SetJustifyH("LEFT")
        num:SetText(tostring(i))
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", num, "RIGHT", 4, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        fs:SetJustifyH("LEFT")
        fs:SetText("")
        row.fs = fs
        row.idx = i
        row:SetScript("OnClick", function()
            MW:OpenMacroEditor(i)
        end)
        self.macroListRows[i] = row
    end

    local slotFS = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotFS:SetPoint("TOPLEFT", editor, "TOPLEFT", 12, -10)
    slotFS:SetText("Macro")
    self.macroSlotFS = slotFS

    local nameLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", slotFS, "BOTTOMLEFT", 0, -10)
    nameLabel:SetText("Nome:")

    local nameEdit = CreateFrame("EditBox", "RLSuiteMacroNameEdit", editor, "InputBoxTemplate")
    nameEdit:SetSize(140, 20)
    nameEdit:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(32)
    nameEdit:SetScript("OnTextChanged", function()
        MW:SaveMacroSlot()
    end)
    nameEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    nameEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    self.macroNameEdit = nameEdit

    local iconBtn = CreateFrame("Button", nil, editor)
    iconBtn:SetSize(36, 36)
    iconBtn:SetPoint("LEFT", nameEdit, "RIGHT", 16, 0)
    iconBtn.icon = iconBtn:CreateTexture(nil, "ARTWORK")
    iconBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    iconBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    RLSuite.utils:SkinMacroButton(iconBtn)
    iconBtn:SetScript("OnClick", function()
        MW:ToggleMacroIconPicker()
    end)
    self.macroIconBtn = iconBtn

    local iconHint = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconHint:SetPoint("LEFT", iconBtn, "RIGHT", 8, 0)
    iconHint:SetText("Clic = scegli icona")

    local bodyFrame = CreateFrame("Frame", nil, editor)
    bodyFrame:SetPoint("TOPLEFT", editor, "TOPLEFT", 12, -78)
    bodyFrame:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 12, 40)
    bodyFrame:SetPoint("RIGHT", list, "LEFT", -8, 0)
    bodyFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    bodyFrame:SetBackdropColor(0, 0, 0, 0.85)
    self.macroBodyFrame = bodyFrame

    local body = CreateFrame("EditBox", "RLSuiteMacroBodyEdit", bodyFrame)
    body:SetMultiLine(true)
    body:SetAutoFocus(false)
    body:SetFontObject(ChatFontNormal)
    body:SetTextInsets(6, 6, 6, 6)
    body:SetMaxLetters(1024)
    body:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", 6, -6)
    body:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", -6, 6)
    body:EnableMouse(true)
    body:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    body:SetScript("OnTextChanged", function()
        MW:SaveMacroSlot()
    end)
    self.macroBodyEdit = body

    local util = CreateFrame("Frame", nil, editor)
    util:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 10, 8)
    util:SetPoint("RIGHT", list, "LEFT", -8, 0)
    util:SetHeight(26)
    self.macroUtilBar = util

    local raidIcons = {
        { token = "{rt1}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
        { token = "{rt2}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
        { token = "{rt3}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
        { token = "{rt4}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
        { token = "{rt5}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
        { token = "{rt6}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
        { token = "{rt7}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
        { token = "{rt8}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    }
    for i, data in ipairs(raidIcons) do
        local ib = CreateFrame("Button", nil, util)
        ib:SetSize(22, 22)
        ib:SetPoint("LEFT", util, "LEFT", (i - 1) * 26, 0)
        local tex = ib:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(ib)
        tex:SetTexture(data.tex)
        ib:SetScript("OnClick", function()
            MW:InsertMacroText(data.token)
        end)
    end

    local capsBtn = CreateFrame("Button", nil, util, "UIPanelButtonTemplate")
    capsBtn:SetSize(70, 22)
    capsBtn:SetPoint("LEFT", util, "LEFT", 8 * 26 + 8, 0)
    capsBtn:SetText("CAPS")
    capsBtn:SetScript("OnClick", function()
        MW:ToggleMacroCaps()
    end)

    self:HookMacroInsertLink()
    self:CreateMacroIconPicker(editor)
    self:SelectMacroPhase(self.macroPhase)
    self:OpenMacroEditor(1)
end

function MW:HookMacroInsertLink()
    if self._insertLinkHooked then return end
    self._insertLinkHooked = true
    local orig = ChatEdit_InsertLink
    ChatEdit_InsertLink = function(text)
        local edit = MW.macroBodyEdit
        if text and edit and edit:IsShown() and edit:HasFocus() then
            edit:Insert(text)
            MW:SaveMacroSlot()
            return true
        end
        if orig then
            return orig(text)
        end
    end
end

function MW:CreateMacroIconPicker(parent)
    local picker = CreateFrame("Frame", "RLSuiteMacroIconPicker", parent)
    picker:SetSize(280, 220)
    picker:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 12, 44)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    RLSuite.utils:SkinFrame(picker)
    picker:Hide()
    picker:EnableMouse(true)
    self.macroIconPicker = picker

    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -8)
    title:SetText("Icona macro")

    local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() picker:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "RLSuiteMacroIconScroll", picker, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", picker, "TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -28, 8)
    scroll:SetScript("OnVerticalScroll", function(s, offset)
        FauxScrollFrame_OnVerticalScroll(s, offset, 32, function()
            MW:UpdateMacroIconPicker()
        end)
    end)
    self.macroIconScroll = scroll

    self.macroIconBtns = {}
    local cols, rows, size, gap = 10, 6, 28, 2
    for i = 1, cols * rows do
        local btn = CreateFrame("Button", nil, picker)
        btn:SetSize(size, size)
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        btn:SetPoint("TOPLEFT", scroll, "TOPLEFT", col * (size + gap), -row * (size + gap))
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints(btn)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn:SetScript("OnClick", function(s)
            if s.texPath then
                MW:SetMacroIcon(s.texPath)
            end
        end)
        self.macroIconBtns[i] = btn
    end
end

function MW:GetMacroIconList()
    if self.macroIconList then return self.macroIconList end
    local list = {}
    if GetNumMacroIcons and GetMacroIconInfo then
        local n = GetNumMacroIcons() or 0
        for i = 1, n do
            local tex = GetMacroIconInfo(i)
            if tex then table.insert(list, tex) end
        end
    end
    if #list == 0 then
        table.insert(list, "Interface\\Icons\\INV_Misc_QuestionMark")
        if RLSuite.abilityByName then
            for _, meta in pairs(RLSuite.abilityByName) do
                if meta.icon then table.insert(list, meta.icon) end
            end
        end
    end
    self.macroIconList = list
    return list
end

function MW:ToggleMacroIconPicker()
    if not self.macroIconPicker then return end
    if self.macroIconPicker:IsShown() then
        self.macroIconPicker:Hide()
        return
    end
    self:GetMacroIconList()
    self.macroIconPicker:Show()
    self:UpdateMacroIconPicker()
end

function MW:UpdateMacroIconPicker()
    local list = self:GetMacroIconList()
    local cols, rows = 10, 6
    local per = cols * rows
    local numRows = math.ceil(#list / cols)
    FauxScrollFrame_Update(self.macroIconScroll, numRows, rows, 32)
    local offset = FauxScrollFrame_GetOffset(self.macroIconScroll) or 0
    for i = 1, per do
        local idx = offset * cols + i
        local btn = self.macroIconBtns[i]
        local tex = list[idx]
        if tex then
            btn.icon:SetTexture(tex)
            btn.texPath = tex
            btn:Show()
        else
            btn.texPath = nil
            btn:Hide()
        end
    end
end

function MW:SetMacroIcon(tex)
    self.macroEditIcon = tex
    if self.macroIconBtn and self.macroIconBtn.icon then
        self.macroIconBtn.icon:SetTexture(tex)
    end
    if self.macroIconPicker then self.macroIconPicker:Hide() end
    self:SaveMacroSlot()
end

function MW:OpenMacroEditor(index)
    self.macroEditIndex = index
    if self.macroEditor then self.macroEditor:Show() end
    if self.macroIconPicker then self.macroIconPicker:Hide() end
    for i, btn in ipairs(self.macroPreviewBtns or {}) do
        if btn and not btn.sel then
            btn.sel = btn:CreateTexture(nil, "OVERLAY")
            btn.sel:SetAllPoints(btn)
            btn.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            btn.sel:SetBlendMode("ADD")
            btn.sel:Hide()
        end
        if btn and btn.sel then
            if i == index then btn.sel:Show() else btn.sel:Hide() end
        end
    end
    if self.macroSlotFS then
        self.macroSlotFS:SetText("Macro " .. tostring(index))
    end
    local macros = self:GetMacroDB()
    local data = macros[index] or {}
    self.macroLoading = true
    self.macroEditIcon = data.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    if self.macroNameEdit then
        self.macroNameEdit:SetText(data.name or "")
    end
    if self.macroBodyEdit then
        self.macroBodyEdit:SetText(data.text or "")
        self.macroBodyEdit:SetFocus()
    end
    if self.macroIconBtn and self.macroIconBtn.icon then
        self.macroIconBtn.icon:SetTexture(self.macroEditIcon)
    end
    self.macroLoading = false
    self:RefreshMacroList()
end

function MW:InsertMacroText(token)
    if not self.macroBodyEdit then return end
    self.macroBodyEdit:SetFocus()
    self.macroBodyEdit:Insert(token)
    self:SaveMacroSlot()
end

function MW:ToggleMacroCaps()
    local edit = self.macroBodyEdit
    if not edit then return end
    local full = edit:GetText() or ""
    if full == "" then return end
    edit:SetFocus()
    edit:Insert("\001")
    local after = edit:GetText() or ""
    local pos = string.find(after, "\001", 1, true)
    local selected, s, e
    if not pos then
        selected, s, e = full, 1, string.len(full)
        edit:SetText(full)
    else
        local prefix = string.sub(after, 1, pos - 1)
        local suffix = string.sub(after, pos + 1)
        s = string.len(prefix) + 1
        e = string.len(full) - string.len(suffix)
        if e < s then
            selected, s, e = full, 1, string.len(full)
        else
            selected = string.sub(full, s, e)
            if selected == "" then
                selected, s, e = full, 1, string.len(full)
            end
        end
    end
    local repl
    if selected == string.upper(selected) then
        repl = string.lower(selected)
    else
        repl = string.upper(selected)
    end
    local newText = string.sub(full, 1, s - 1) .. repl .. string.sub(full, e + 1)
    self.macroLoading = true
    edit:SetText(newText)
    self.macroLoading = false
    self:SaveMacroSlot()
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
    if self.macroEditIndex then
        self:OpenMacroEditor(self.macroEditIndex)
    end
end

function MW:GetMacroDB(phase)
    phase = phase or self.macroPhase or "preraid"
    if not RLSuiteDB or not RLSuiteDB.macrobar then return {} end
    RLSuiteDB.macrobar.macros = RLSuiteDB.macrobar.macros or {}
    RLSuiteDB.macrobar.macros[phase] = RLSuiteDB.macrobar.macros[phase] or {}
    return RLSuiteDB.macrobar.macros[phase]
end

function MW:SaveMacroSlot()
    if self.macroLoading then return end
    local index = self.macroEditIndex
    if not index then return end
    local macros = self:GetMacroDB()
    local current = macros[index] or {}
    current.text = (self.macroBodyEdit and self.macroBodyEdit:GetText()) or current.text or ""
    current.name = (self.macroNameEdit and self.macroNameEdit:GetText()) or current.name or ""
    current.icon = self.macroEditIcon or current.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    macros[index] = current
    local phase = self.macroPhase or "preraid"
    if RLSuite.macrobar and RLSuite.macrobar.LoadMacrosForPhase then
        if (RLSuite.context or "preraid") == phase then
            RLSuite.macrobar:LoadMacrosForPhase(phase)
        end
    end
    self:RefreshMacroPreview()
end

function MW:SaveMacroLine(index, text)
    local macros = self:GetMacroDB()
    local current = macros[index] or {text = "", icon = "Interface\\Icons\\INV_Misc_QuestionMark"}
    current.text = text or ""
    current.icon = current.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    macros[index] = current
    local phase = self.macroPhase or "preraid"
    if RLSuite.macrobar and RLSuite.macrobar.LoadMacrosForPhase then
        if (RLSuite.context or "preraid") == phase then
            RLSuite.macrobar:LoadMacrosForPhase(phase)
        end
    end
    self:RefreshMacroPreview()
end

function MW:RefreshMacroTab()
    self:RefreshMacroPreview()
end

function MW:MacroPreviewText(data)
    if not data then return "" end
    local name = data.name or ""
    local text = data.text or ""
    text = string.gsub(text, "\n", " | ")
    if name ~= "" and text ~= "" then
        return name .. "  " .. text
    end
    if name ~= "" then return name end
    return text
end

function MW:RefreshMacroList()
    local macros = self:GetMacroDB(self.macroPhase)
    local sel = self.macroEditIndex
    for i, row in ipairs(self.macroListRows or {}) do
        local data = macros[i]
        if row.fs then
            local line = self:MacroPreviewText(data)
            if line == "" then line = " " end
            row.fs:SetText(line)
            if sel == i then
                row.fs:SetTextColor(1, 0.82, 0)
            else
                row.fs:SetTextColor(0.9, 0.9, 0.9)
            end
        end
    end
end

function MW:RefreshMacroPreview()
    local macros = self:GetMacroDB(self.macroPhase)
    for i, btn in ipairs(self.macroPreviewBtns or {}) do
        local data = macros[i]
        if btn and btn.icon then
            local icon = (data and data.icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
            if data and ((data.text and data.text ~= "") or (data.name and data.name ~= "") or data.icon) then
                btn.icon:SetTexture(icon)
            else
                btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
    end
    self:RefreshMacroList()
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

