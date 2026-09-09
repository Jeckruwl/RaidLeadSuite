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
    f:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    f:Hide()
    self.frame = f
    RLSuite.utils:SkinFrame(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("MS Change Manager")

    self.listScroll = CreateFrame("ScrollFrame", "RLSuiteMSList", f, "UIPanelScrollFrameTemplate")
    self.listScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -45)
    self.listScroll:SetSize(200, 250)

    self.listContent = CreateFrame("Frame")
    self.listContent:SetSize(200, 1)
    self.listScroll:SetScrollChild(self.listContent)

    local addLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", self.listScroll, "BOTTOMLEFT", 0, -10)
    addLabel:SetText("Aggiungi manuale:")

    self.addName = CreateFrame("EditBox", "RLSuiteMSAddName", f, "InputBoxTemplate")
    self.addName:SetSize(100, 20)
    self.addName:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 5, -5)
    self.addName:SetAutoFocus(false)
    self.addName:SetText("Nome")

    self.addSpec = CreateFrame("EditBox", "RLSuiteMSAddSpec", f, "InputBoxTemplate")
    self.addSpec:SetSize(100, 20)
    self.addSpec:SetPoint("LEFT", self.addName, "RIGHT", 10, 0)
    self.addSpec:SetAutoFocus(false)
    self.addSpec:SetText("Spec")

    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("LEFT", self.addSpec, "RIGHT", 10, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function() self:AddManual() end)

    self.genMsgBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.genMsgBtn:SetSize(150, 25)
    self.genMsgBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    self.genMsgBtn:SetText("Genera Messaggio")
    self.genMsgBtn:SetScript("OnClick", function() self:GenerateMessage() end)

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)
end

function MSM:ParseMSMessage(sender, msg)
    local lower = string.lower(msg or "")
    local spec = string.match(lower, "^ms%s+(.+)")
    if spec then
        spec = string.gsub(string.gsub(spec, "^%s+", ""), "%s+$", "")
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
    for _, child in ipairs({self.listContent:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local y = 0
    for i, entry in ipairs(self.db) do
        local row = CreateFrame("Frame", nil, self.listContent)
        row:SetSize(200, 22)
        row:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, -y)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", row, "LEFT", 5, 0)
        text:SetText((entry.name or "?") .. ": " .. (entry.spec or "?"))

        local delBtn = CreateFrame("Button", nil, row)
        delBtn:SetSize(14, 14)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        delBtn:SetNormalTexture("Interface\Buttons\UI-Panel-MinimizeButton-Up")
        delBtn:SetScript("OnClick", function()
            self:RemoveEntry(i)
        end)

        y = y + 24
    end
    self.listContent:SetHeight(math.max(y, 1))
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
    RLSuite.utils:Print("Messaggio generato: " .. msg)
end
