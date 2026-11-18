-- ============================================================
-- RLSuite - MSManager Module
-- ============================================================

RLSuite.msManager = {}
local MSM = RLSuite.msManager

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })
local MS_CHAT_LIMIT = 255
local MS_SPEC_SHORT_NAMES = {
    ["assassination"] = "Assa",
    ["beast mastery"] = "BM",
    ["balance"] = "Boomie",
    ["destruction"] = "Destro",
    ["demonology"] = "Demo",
    ["discipline"] = "Disco",
    ["elemental"] = "Ele",
    ["enhancement"] = "Enha",
    ["feral bear"] = "Bear",
    ["feral cat"] = "Cat",
    ["marksmanship"] = "MM",
    ["protection"] = "Prot",
    ["restoration"] = "Resto",
    ["retribution"] = "Ret",
    ["subtlety"] = "Sub",
    ["survival"] = "Surv",
    ["affliction"] = "Affly",
}

-- Ace3: il conto alla rovescia dei 40s di ascolto usa AceTimer-3.0
-- (prima era un frame OnUpdate con accumulo manuale del tempo).
LibStub("AceTimer-3.0"):Embed(MSM)

function MSM:Init()
    self.db = RLSuite.db.profile.mschanges or {}
    RLSuite.db.profile.mschanges = self.db
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
    f._noOuterBorder = true
    self.frame = f
    RLSuite.utils:SkinFrame(f)
    RLSuite.utils:ClampWindow(f)

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
    RLSuite.utils:RegisterScrollClip(self.listScroll, self.listContent)
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
    self.addName:SetText(L["Name"])

    self.addSpec = CreateFrame("EditBox", "RLSuiteMSAddSpec", self.addBox, "InputBoxTemplate")
    self.addSpec:SetSize(100, 20)
    self.addSpec:SetPoint("LEFT", self.addName, "RIGHT", 8, 0)
    self.addSpec:SetAutoFocus(false)
    self.addSpec:SetText(L["Spec"])

    local addBtn = CreateFrame("Button", nil, self.addBox, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(addBtn)
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("LEFT", self.addSpec, "RIGHT", 8, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function() self:AddManual() end)

    self.requestBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.requestBtn)
    self.requestBtn:SetSize(150, 24)
    self.requestBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 10)
    self.requestBtn:SetText("Request MS Change")
    self.requestBtn:SetScript("OnClick", function() self:RequestChanges() end)

    self.genMsgBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.genMsgBtn)
    self.genMsgBtn:SetSize(150, 24)
    self.genMsgBtn:SetPoint("LEFT", self.requestBtn, "RIGHT", 8, 0)
    self.genMsgBtn:SetText("Announce Changes")
    self.genMsgBtn:SetScript("OnClick", function() self:GenerateMessage() end)

    f.closeBtn = RLSuite.utils:MakeCloseX(f, function() f:Hide() end)
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
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
    if self.listenTimer then
        self:CancelTimer(self.listenTimer)
        self.listenTimer = nil
    end
    if announce then
        RLSuite.utils:SendChat("MS CHANGES closed, no more MS changes will be saved", "RAID_WARNING")
    end
end

-- Il comando resta "ms <qualcosa>"; il <qualcosa> viene letto con lo stesso
-- parser della Whisplist (tabella _dev/Class_Spec_and_GS_parser.md), quindi
-- vanno bene tutte le forme: "ms f dk", "ms dk frost", "ms frost dk",
-- "ms unholy", "ms prot pala", "ms resto"...
-- La spec viene salvata col nome canonico ("prot" -> "Protection",
-- "f dk" -> "Frost" + classe DEATHKNIGHT); se il parser non la riconosce si
-- tiene il testo scritto, come prima.
function MSM:ParseMSMessage(sender, msg)
    if not self.listening then return end
    local text = string.gsub(string.gsub(msg or "", "^%s+", ""), "%s+$", "")
    if text == "" then return end
    local lower = string.lower(text)
    -- "ms changes" e' la richiesta del leader, non un cambio di spec
    if string.find(lower, "^ms%s*changes") then return end

    local body = string.match(text, "^[Mm][Ss]%s*[:%-=]?%s*(.+)$")
    if not body or body == "" then return end

    local parsed = RLSuite.utils:ParseWhisper(body)
    local spec = parsed.spec or body
    self:AddEntry(sender, spec, parsed.class)
    RLSuite.utils:Print(string.format(L["MS change detected: %s -> %s"], sender, spec))
end

function MSM:AddEntry(name, spec, class)
    for i, entry in ipairs(self.db) do
        if entry.name == name then
            table.remove(self.db, i)
            break
        end
    end
    table.insert(self.db, {name = name, spec = spec, class = class, time = time()})
    self:UpdateList()
end

function MSM:AddManual()
    local name = self.addName and self.addName:GetText() or ""
    local spec = self.addSpec and self.addSpec:GetText() or ""
    if name ~= "" and name ~= L["Name"] and spec ~= "" and spec ~= L["Spec"] then
        self:AddEntry(name, spec)
        self.addName:SetText(L["Name"])
        self.addSpec:SetText(L["Spec"])
    end
end

function MSM:RemoveEntry(index)
    table.remove(self.db, index)
    self:UpdateList()
end

function MSM:UpdateList()
    if not self.listContent then return end
    self:SkinInner()
    for _, child in ipairs(self.listRows or {}) do
        child:Hide()
        child:SetParent(nil)
    end
    self.listRows = {}
    RLSuite.utils:ClearScrollClip(self.listContent)
    if self.listScroll then
        local w = self.listScroll:GetWidth()
        if w and w > 40 then self.listContent:SetWidth(w) end
    end

    local y = 0
    for i, entry in ipairs(self.db) do
        local row = CreateFrame("Frame", nil, self.listContent)
        self.listRows[#self.listRows + 1] = row
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", self.listContent, "TOPRIGHT", 0, -y)
        RLSuite.utils:SkinRow(row, false)
        RLSuite.utils:ClipScrollRow(self.listContent, row, y, 24)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", row, "LEFT", 8, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -18, 0)
        text:SetJustifyH("LEFT")
        text:SetText((entry.name or "?") .. ": " .. (entry.spec or "?"))

        local delBtn = CreateFrame("Button", nil, row)
        delBtn:SetSize(10, 10)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        -- X bianca dal TGA in media/ (formato BCI: nel client rende sempre).
        RLSuite.utils:ApplyIcon(delBtn, "media\\close.tga")
        -- Livelli espliciti: la X resta SEMPRE cliccabile sopra la riga.
        row:SetFrameLevel((row:GetFrameLevel() or 1) + 1)
        delBtn:SetFrameLevel(row:GetFrameLevel() + 2)
        delBtn:EnableMouse(true)
        delBtn:RegisterForClicks("LeftButtonUp")
        delBtn:SetScript("OnClick", function()
            self:RemoveEntry(i)
        end)

        y = y + 26
    end
    self.listContent:SetHeight(math.max(y, 1))
    RLSuite.utils:RepinFrameOrder(self.listContent)
    RLSuite.utils:RefreshScrollClip(self.listContent)
end

function MSM:RequestChanges()
    self:StopListening(false)
    self.listening = true
    local dur = 40
    self.listenUntil = GetTime() + dur
    local msg = L["Requesting MS changes - type in raid: ms <spec> you have only 40s"]
    RLSuite.utils:SendChat(msg, "RAID_WARNING")
    -- bar timer in DBM/BigWigs if installed
    RLSuite.utils:StartDbmTimer(dur, "MS Changes", "Interface\\Icons\\Spell_Nature_AstralRecall")
    self.listenTimer = self:ScheduleTimer("OnListenExpire", dur)
end

function MSM:OnListenExpire()
    if not self.listening then return end
    self:StopListening(true)
end

function MSM:FormatChangeEntries(abbreviateSpecs)
    local parts = {}
    for _, entry in ipairs(self.db or {}) do
        local spec = tostring(entry.spec or "?")
        if abbreviateSpecs then
            local short
            if entry.class and RLSuite.utils and RLSuite.utils.SpecShortName then
                local candidate = RLSuite.utils:SpecShortName(entry.class, spec)
                if type(candidate) == "string" and candidate ~= "" and #candidate < #spec then
                    short = candidate
                end
            end
            if not short then
                short = MS_SPEC_SHORT_NAMES[string.lower(spec)]
            end
            if short and short ~= "" then spec = short end
        end
        table.insert(parts, tostring(entry.name or "?") .. ": " .. spec)
    end
    return parts
end

function MSM:GetChangesMessages()
    if not self.db or #self.db == 0 then return {} end

    local fullEntries = self:FormatChangeEntries(false)
    local fullMessage = "MS CHANGES: " .. table.concat(fullEntries, " | ")
    -- Abbreviate specs only when the full announcement would exceed the
    -- 255-character limit imposed by the WoW chat API.
    local entries = #fullMessage > MS_CHAT_LIMIT
        and self:FormatChangeEntries(true) or fullEntries

    local messages = {}
    local prefix = "MS CHANGES: "
    local current = prefix
    for _, entry in ipairs(entries) do
        local separator = current == prefix and "" or " | "
        if #current + #separator + #entry > MS_CHAT_LIMIT and current ~= prefix then
            table.insert(messages, current)
            current = prefix
            separator = ""
        end

        -- Character names and canonical spec names normally fit in one entry;
        -- this guard also keeps malformed/manual entries under the chat limit.
        local maxEntryLength = MS_CHAT_LIMIT - #prefix
        while #entry > maxEntryLength do
            local cut = maxEntryLength
            for i = maxEntryLength, 1, -1 do
                if string.sub(entry, i, i) == " " then
                    cut = i - 1
                    break
                end
            end
            if cut < 1 then cut = maxEntryLength end
            table.insert(messages, prefix .. string.sub(entry, 1, cut))
            entry = string.gsub(string.sub(entry, cut + 1), "^%s+", "")
            current = prefix
            separator = ""
        end
        current = current .. separator .. entry
    end

    if current ~= prefix then table.insert(messages, current) end
    return messages
end

function MSM:GetChangesMessage()
    return table.concat(self:GetChangesMessages(), "\n")
end

function MSM:RefreshLootPreMessage()
    if RLSuite.lootManager and RLSuite.lootManager.SetPreMessage then
        RLSuite.lootManager:SetPreMessage(self:GetChangesMessage())
    end
end

function MSM:GenerateMessage()
    local messages = self:GetChangesMessages()
    if #messages == 0 then
        RLSuite.utils:Print(L["No MS changes recorded."])
        return
    end
    local msg = table.concat(messages, "\n")
    self:RefreshLootPreMessage()
    for _, part in ipairs(messages) do
        RLSuite.utils:SendChat(part, "RAID_WARNING")
    end
    RLSuite.utils:Print("Announce Changes: " .. msg)
end
