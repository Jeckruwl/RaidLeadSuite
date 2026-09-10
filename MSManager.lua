-- ============================================================
-- RLSuite - MSManager Module
-- ============================================================

RLSuite.msManager = {}
local MSM = RLSuite.msManager

function MSM:Init()
    self.db = RLSuiteDB.mschanges or {}
    RLSuiteDB.mschanges = self.db
    self:CreateFrame()
end

function MSM:Toggle()
    if RLSuite.mainWindow and RLSuite.mainWindow.ShowTab then
        RLSuite.mainWindow:ShowTab("ms")
        return
    end
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
        self:UpdateList()
    end
end

function MSM:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteMSManager", UIParent)
    f:SetSize(350, 400)
    f:SetPoint("CENTER", UIParent, "CENTER", -300, 0)
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
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -10)
    title:SetText("MS Change Manager")

    self.listBox = CreateFrame("Frame", nil, f)
    self.listBox:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -36)
    self.listBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 78)
    RLSuite.utils:SkinBox(self.listBox)

    local listLabel = self.listBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listLabel:SetPoint("TOPLEFT", self.listBox, "TOPLEFT", 8, -6)
    listLabel:SetText("MS changes")
    listLabel:SetTextColor(1, 0.82, 0)

    self.listScroll = CreateFrame("ScrollFrame", "RLSuiteMSList", self.listBox, "UIPanelScrollFrameTemplate")
    self.listScroll:SetPoint("TOPLEFT", self.listBox, "TOPLEFT", 6, -24)
    self.listScroll:SetPoint("BOTTOMRIGHT", self.listBox, "BOTTOMRIGHT", -26, 6)

    self.listContent = CreateFrame("Frame", nil, self.listScroll)
    self.listContent:SetWidth(200)
    self.listContent:SetHeight(1)
    self.listScroll:SetScrollChild(self.listContent)
    self.listScroll:SetScript("OnSizeChanged", function(s, w, h)
        if MSM.listContent and w and w > 40 then
            MSM.listContent:SetWidth(w)
        end
    end)

    self.addBox = CreateFrame("Frame", nil, f)
    self.addBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 40)
    self.addBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 40)
    self.addBox:SetHeight(36)
    RLSuite.utils:SkinBox(self.addBox)

    local addLabel = self.addBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("LEFT", self.addBox, "LEFT", 8, 0)
    addLabel:SetText("Add")
    addLabel:SetTextColor(1, 0.82, 0)

    self.addName = CreateFrame("EditBox", "RLSuiteMSAddName", self.addBox, "InputBoxTemplate")
    self.addName:SetSize(100, 20)
    self.addName:SetPoint("LEFT", addLabel, "RIGHT", 8, 0)
    self.addName:SetAutoFocus(false)
    self.addName:SetText("Nome")

    self.addSpec = CreateFrame("EditBox", "RLSuiteMSAddSpec", self.addBox, "InputBoxTemplate")
    self.addSpec:SetSize(100, 20)
    self.addSpec:SetPoint("LEFT", self.addName, "RIGHT", 8, 0)
    self.addSpec:SetAutoFocus(false)
    self.addSpec:SetText("Spec")

    local addBtn = CreateFrame("Button", nil, self.addBox, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("LEFT", self.addSpec, "RIGHT", 8, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function() self:AddManual() end)

    self.requestBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.requestBtn:SetSize(150, 24)
    self.requestBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 10)
    self.requestBtn:SetText("Request MS Change")
    self.requestBtn:SetScript("OnClick", function() self:RequestChanges() end)

    self.genMsgBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.genMsgBtn:SetSize(150, 24)
    self.genMsgBtn:SetPoint("LEFT", self.requestBtn, "RIGHT", 8, 0)
    self.genMsgBtn:SetText("Announce Changes")
    self.genMsgBtn:SetScript("OnClick", function() self:GenerateMessage() end)

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)
end

function MSM:SkinInner()
    RLSuite.utils:SkinBox(self.listBox)
    RLSuite.utils:SkinBox(self.addBox)
end

function MSM:IsListening()
    return self.listening == true
end

function MSM:StopListening(announce)
    self.listening = false
    self.listenUntil = nil
    if self.listenFrame then
        self.listenFrame:SetScript("OnUpdate", nil)
        self.listenFrame:Hide()
        self.listenFrame = nil
    end
    if announce then
        RLSuite.utils:SendChat("MS CHANGES closed, no more MS changes will be saved", "RAID")
    end
end

function MSM:ParseMSMessage(sender, msg)
    if not self.listening then return end
    local lower = string.lower(msg or "")
    if string.find(lower, "^ms%s+changes") then
        return
    end
    local spec = string.match(lower, "^ms%s+(.+)")
    if spec then
        spec = string.gsub(string.gsub(spec, "^%s+", ""), "%s+$", "")
        if spec == "" then return end
        self:AddEntry(sender, spec)
        RLSuite.utils:Print("MS change rilevato: " .. sender .. " -> " .. spec)
    end
end

function MSM:AddEntry(name, spec)
    for i, entry in ipairs(self.db) do
        if entry.name == name then
            table.remove(self.db, i)
            break
        end
    end
    table.insert(self.db, {name = name, spec = spec, time = time()})
    self:UpdateList()
end

function MSM:AddManual()
    local name = self.addName and self.addName:GetText() or ""
    local spec = self.addSpec and self.addSpec:GetText() or ""
    if name ~= "" and name ~= "Nome" and spec ~= "" and spec ~= "Spec" then
        self:AddEntry(name, spec)
        self.addName:SetText("Nome")
        self.addSpec:SetText("Spec")
    end
end

function MSM:RemoveEntry(index)
    table.remove(self.db, index)
    self:UpdateList()
end

function MSM:UpdateList()
    if not self.listContent then return end
    self:SkinInner()
    for _, child in ipairs(self.listContent:GetChildren()) do
        child:Hide()
        child:SetParent(nil)
    end
    if self.listScroll then
        local w = self.listScroll:GetWidth()
        if w and w > 40 then self.listContent:SetWidth(w) end
    end

    local y = 0
    for i, entry in ipairs(self.db) do
        local row = CreateFrame("Frame", nil, self.listContent)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", self.listContent, "TOPRIGHT", 0, -y)
        RLSuite.utils:SkinRow(row, false)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", row, "LEFT", 8, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -22, 0)
        text:SetJustifyH("LEFT")
        text:SetText((entry.name or "?") .. ": " .. (entry.spec or "?"))

        local delBtn = CreateFrame("Button", nil, row)
        delBtn:SetSize(14, 14)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        delBtn:SetNormalTexture("Interface\Buttons\UI-Panel-MinimizeButton-Up")
        delBtn:SetScript("OnClick", function()
            self:RemoveEntry(i)
        end)

        y = y + 26
    end
    self.listContent:SetHeight(math.max(y, 1))
end

function MSM:RequestChanges()
    self:StopListening(false)
    self.listening = true
    local dur = 40
    self.listenUntil = GetTime() + dur
    local msg = "Requesting MS changes — type in raid: ms <spec> you have only 40s"
    RLSuite.utils:SendChat(msg, "RAID")
    -- barra-timer in DBM/BigWigs se installati
    RLSuite.utils:StartDbmTimer(dur, "MS Changes", "Interface\\Icons\\Spell_Nature_AstralRecall")
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self2, elapsed)
        if not MSM.listening or not MSM.listenUntil then
            MSM:StopListening(false)
            return
        end
        if GetTime() >= MSM.listenUntil then
            MSM:StopListening(true)
        end
    end)
    f:Show()
    self.listenFrame = f
end

function MSM:GenerateMessage()
    if #self.db == 0 then
        RLSuite.utils:Print("Nessun MS change registrato.")
        return
    end
    local parts = {}
    for _, entry in ipairs(self.db) do
        table.insert(parts, (entry.name or "?") .. ": " .. (entry.spec or "?"))
    end
    local msg = "MS CHANGES: " .. table.concat(parts, " | ")
    if RLSuite.lootManager and RLSuite.lootManager.SetPreMessage then
        RLSuite.lootManager:SetPreMessage(msg)
    end
    RLSuite.utils:SendChat(msg, "RAID")
    RLSuite.utils:Print("Announce Changes: " .. msg)
end
