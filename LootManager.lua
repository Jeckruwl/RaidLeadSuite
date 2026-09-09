-- ============================================================
-- RLSuite - LootManager Module
-- ============================================================

RLSuite.lootManager = {}
local LM = RLSuite.lootManager

function LM:Init()
    self.db = RLSuiteDB.loot
    self.history = self.db.history or {}
    self.db.history = self.history
    self.currentRoll = nil
    self.preMessage = ""
    self:CreateFrame()
end

function LM:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
        self:UpdateHistory()
    end
end

function LM:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteLootManager", UIParent)
    f:SetSize(500, 500)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
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
    title:SetText("Loot Manager")

    self.preMsgText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.preMsgText:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -40)
    self.preMsgText:SetWidth(470)
    self.preMsgText:SetJustifyH("LEFT")
    self.preMsgText:SetText("")

    local histLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    histLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -65)
    histLabel:SetText("Loot History:")

    self.histScroll = CreateFrame("ScrollFrame", "RLSuiteLootHistory", f, "UIPanelScrollFrameTemplate")
    self.histScroll:SetPoint("TOPLEFT", histLabel, "BOTTOMLEFT", 0, -5)
    self.histScroll:SetSize(460, 280)

    self.histContent = CreateFrame("Frame")
    self.histContent:SetSize(460, 1)
    self.histScroll:SetScrollChild(self.histContent)

    self.selectedItem = nil
    self.selectedItemIcon = f:CreateTexture(nil, "ARTWORK")
    self.selectedItemIcon:SetSize(32, 32)
    self.selectedItemIcon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 50)
    self.selectedItemIcon:SetTexture("Interface\Icons\INV_Misc_QuestionMark")

    self.selectedItemText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.selectedItemText:SetPoint("LEFT", self.selectedItemIcon, "RIGHT", 5, 0)
    self.selectedItemText:SetText("Nessun item selezionato")

    self.rollMSBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.rollMSBtn:SetSize(80, 25)
    self.rollMSBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 15)
    self.rollMSBtn:SetText("Roll MS")
    self.rollMSBtn:SetScript("OnClick", function() self:StartRoll("MS") end)

    self.rollOSBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.rollOSBtn:SetSize(80, 25)
    self.rollOSBtn:SetPoint("LEFT", self.rollMSBtn, "RIGHT", 5, 0)
    self.rollOSBtn:SetText("Roll OS")
    self.rollOSBtn:SetScript("OnClick", function() self:StartRoll("OS") end)

    self.rollOtherBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.rollOtherBtn:SetSize(80, 25)
    self.rollOtherBtn:SetPoint("LEFT", self.rollOSBtn, "RIGHT", 5, 0)
    self.rollOtherBtn:SetText("Roll Other")
    self.rollOtherBtn:SetScript("OnClick", function() self:StartRoll("OTHER") end)

    self.rerollBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.rerollBtn:SetSize(80, 25)
    self.rerollBtn:SetPoint("LEFT", self.rollOtherBtn, "RIGHT", 5, 0)
    self.rerollBtn:SetText("Reroll")
    self.rerollBtn:Disable()
    self.rerollBtn:SetScript("OnClick", function() self:DoReroll() end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
end

function LM:SetPreMessage(msg)
    self.preMessage = msg or ""
    if self.preMsgText then
        self.preMsgText:SetText(msg)
    end
end

function LM:OnLootMessage(msg)
    local itemLink = RLSuite.utils:GetItemLinkFromChat(msg or "")
    if not itemLink then return end
    local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
    if itemName then
        self:AddToHistory(itemLink, itemName, itemTexture)
    else
        self:QueuePendingLoot(itemLink)
    end
end

function LM:QueuePendingLoot(itemLink)
    self.pendingLoot = self.pendingLoot or {}
    table.insert(self.pendingLoot, {link = itemLink, tries = 0})
    if self.pendingFrame then return end
    local f = CreateFrame("Frame")
    f.elapsed = 0
    f:SetScript("OnUpdate", function(self2, elapsed)
        self2.elapsed = self2.elapsed + elapsed
        if self2.elapsed < 0.25 then return end
        self2.elapsed = 0
        local pending = LM.pendingLoot or {}
        if #pending == 0 then
            self2:SetScript("OnUpdate", nil)
            LM.pendingFrame = nil
            return
        end
        for i = #pending, 1, -1 do
            local p = pending[i]
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            pcall(function() GameTooltip:SetHyperlink(p.link) end)
            GameTooltip:Hide()
            local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(p.link)
            if itemName then
                LM:AddToHistory(p.link, itemName, itemTexture)
                table.remove(pending, i)
            else
                p.tries = (p.tries or 0) + 1
                if p.tries > 20 then
                    LM:AddToHistory(p.link, "Unknown Item", "Interface\\Icons\\INV_Misc_QuestionMark")
                    table.remove(pending, i)
                end
            end
        end
    end)
    self.pendingFrame = f
end

function LM:AddToHistory(itemLink, itemName, itemTexture)
    local entry = {
        id = #self.history + 1,
        itemLink = itemLink,
        itemName = itemName,
        itemTexture = itemTexture or "Interface\Icons\INV_Misc_QuestionMark",
        boss = "Unknown",
        itemType = self:DetectItemType(itemLink),
        time = time(),
        assignedTo = nil,
    }
    table.insert(self.history, entry)
    self:UpdateHistory()
end

function LM:DetectItemType(itemLink, itemName)
    local lower = string.lower(itemName or itemLink or "")
    if string.find(lower, "pattern") or string.find(lower, "formula") or string.find(lower, "schematic") or string.find(lower, "design") then
        return "PATTERN"
    end
    if string.find(lower, "primordial saronite") or string.find(lower, "orb") then
        return "ORB"
    end
    if string.find(lower, "token") or string.find(lower, "conqueror") or string.find(lower, "protector") or string.find(lower, "vanquisher") or string.find(lower, "regalia") then
        return "TOKEN"
    end
    return "BOP"
end

function LM:UpdateHistory()
    for _, child in ipairs({self.histContent:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local y = 0
    for i = #self.history, 1, -1 do
        local entry = self.history[i]
        local row = CreateFrame("Button", nil, self.histContent)
        row:SetSize(460, 28)
        row:SetPoint("TOPLEFT", self.histContent, "TOPLEFT", 0, -y)
        row.entry = entry

        local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("LEFT", row, "LEFT", 5, 0)
        num:SetText("#" .. (entry.id or 0))
        num:SetWidth(30)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
        icon:SetPoint("LEFT", num, "RIGHT", 5, 0)
        icon:SetTexture(entry.itemTexture or "Interface\Icons\INV_Misc_QuestionMark")

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        name:SetText(entry.itemName or "Unknown")
        name:SetWidth(150)

        local boss = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        boss:SetPoint("LEFT", name, "RIGHT", 5, 0)
        boss:SetText(entry.boss or "Unknown")
        boss:SetWidth(80)

        local itype = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itype:SetPoint("LEFT", boss, "RIGHT", 5, 0)
        itype:SetText(entry.itemType or "BOP")
        itype:SetWidth(50)

        local assigned = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        assigned:SetPoint("LEFT", itype, "RIGHT", 5, 0)
        assigned:SetText(entry.assignedTo or "-")

        row:SetScript("OnClick", function()
            self:SelectItem(entry)
        end)

        y = y + 30
    end
    self.histContent:SetHeight(math.max(y, 1))
end

function LM:SelectItem(entry)
    self.selectedItem = entry
    if self.selectedItemIcon then
        self.selectedItemIcon:SetTexture(entry.itemTexture or "Interface\Icons\INV_Misc_QuestionMark")
    end
    if self.selectedItemText then
        self.selectedItemText:SetText(entry.itemName or "Unknown")
    end
end

function LM:StartRoll(rollType)
    if not self.selectedItem then
        RLSuite.utils:Print("Seleziona un item dalla history!")
        return
    end

    self.currentRoll = {
        item = self.selectedItem,
        type = rollType,
        rolls = {},
        timer = self.db.rollDuration or 10,
        active = true,
    }

    local msg = "Roll " .. (rollType or "MS") .. " for " .. (self.selectedItem.itemName or "Unknown")
    if self.preMessage and self.preMessage ~= "" then
        msg = self.preMessage .. " " .. msg
    end
    RLSuite.utils:SendChat(msg, "RAID")

    if self.rollMSBtn then self.rollMSBtn:Disable() end
    if self.rollOSBtn then self.rollOSBtn:Disable() end
    if self.rollOtherBtn then self.rollOtherBtn:Disable() end

    local remaining = self.currentRoll.timer
    local timerFrame = CreateFrame("Frame")
    timerFrame:SetScript("OnUpdate", function(self2, elapsed)
        self2.elapsed = (self2.elapsed or 0) + elapsed
        if self2.elapsed >= 1 then
            self2.elapsed = 0
            remaining = remaining - 1
            if remaining <= 0 then
                LM:AnnounceWinner()
                self2:SetScript("OnUpdate", nil)
                self2:Hide()
                return
            end
            if remaining <= 3 then
                RLSuite.utils:SendChat("Roll ending in " .. remaining .. "...", "RAID")
            end
        end
    end)
    timerFrame:Show()
    self.rollTimerFrame = timerFrame

    if self.rollFrame then
        self.rollFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
    end
    self.rollFrame = CreateFrame("Frame")
    self.rollFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    self.rollFrame:SetScript("OnEvent", function(self2, event, msg)
        LM:OnSystemRoll(msg)
    end)
end

function LM:OnSystemRoll(msg)
    if not self.currentRoll or not self.currentRoll.active then return end
    local name, roll, minRoll, maxRoll = string.match(msg or "", "(.+) rolls (%d+) %((%d+)%-(%d+)%)%.")
    if name and roll and maxRoll == "100" then
        table.insert(self.currentRoll.rolls, {name = name, roll = tonumber(roll)})
    end
end

function LM:AnnounceWinner()
    if not self.currentRoll then return end
    self.currentRoll.active = false

    if #self.currentRoll.rolls == 0 then
        RLSuite.utils:SendChat("No rolls received for " .. (self.currentRoll.item.itemName or "Unknown"), "RAID")
        self:ResetButtons()
        return
    end

    table.sort(self.currentRoll.rolls, function(a, b) return a.roll > b.roll end)
    local winner = self.currentRoll.rolls[1]
    local winners = {winner}

    for i = 2, #self.currentRoll.rolls do
        if self.currentRoll.rolls[i].roll == winner.roll then
            table.insert(winners, self.currentRoll.rolls[i])
        else
            break
        end
    end

    if #winners > 1 then
        self.currentRoll.rerollWinners = winners
        if self.rerollBtn then self.rerollBtn:Enable() end
        local names = {}
        for _, w in ipairs(winners) do table.insert(names, w.name or "?") end
        RLSuite.utils:SendChat("Tie! Reroll between: " .. table.concat(names, ", "), "RAID")
    else
        RLSuite.utils:SendChat((winner.name or "?") .. " wins " .. (self.currentRoll.item.itemName or "Unknown") .. " with roll " .. (winner.roll or 0) .. "! Please trade.", "RAID")
        self.currentRoll.item.assignedTo = winner.name
        self:ShowTradeWindow(self.currentRoll.item)
        self:UpdateHistory()
    end

    self:ResetButtons()
    if self.rollFrame then
        self.rollFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
    end
end

function LM:DoReroll()
    if not self.currentRoll or not self.currentRoll.rerollWinners then return end

    local winners = self.currentRoll.rerollWinners
    local names = {}
    for _, w in ipairs(winners) do table.insert(names, w.name or "?") end

    RLSuite.utils:SendChat("Reroll! Only " .. table.concat(names, ", ") .. " can roll for " .. (self.currentRoll.item.itemName or "Unknown"), "RAID")

    self.currentRoll.rolls = {}
    self.currentRoll.active = true
    if self.rerollBtn then self.rerollBtn:Disable() end

    local remaining = self.db.rerollDuration or 5
    local timerFrame = CreateFrame("Frame")
    timerFrame:SetScript("OnUpdate", function(self2, elapsed)
        self2.elapsed = (self2.elapsed or 0) + elapsed
        if self2.elapsed >= 1 then
            self2.elapsed = 0
            remaining = remaining - 1
            if remaining <= 0 then
                LM:ProcessReroll()
                self2:SetScript("OnUpdate", nil)
                self2:Hide()
                return
            end
        end
    end)
    timerFrame:Show()
end

function LM:ProcessReroll()
    if not self.currentRoll then return end
    self.currentRoll.active = false

    local validRolls = {}
    for _, roll in ipairs(self.currentRoll.rolls) do
        for _, w in ipairs(self.currentRoll.rerollWinners) do
            if roll.name == w.name then
                table.insert(validRolls, roll)
                break
            end
        end
    end

    if #validRolls == 0 then
        RLSuite.utils:SendChat("No valid rerolls!", "RAID")
        return
    end

    table.sort(validRolls, function(a, b) return a.roll > b.roll end)
    local winner = validRolls[1]
    RLSuite.utils:SendChat((winner.name or "?") .. " wins the reroll for " .. (self.currentRoll.item.itemName or "Unknown") .. " with " .. (winner.roll or 0) .. "! Please trade.", "RAID")
    self.currentRoll.item.assignedTo = winner.name
    self:ShowTradeWindow(self.currentRoll.item)
    self:UpdateHistory()
end

function LM:ResetButtons()
    if self.rollMSBtn then self.rollMSBtn:Enable() end
    if self.rollOSBtn then self.rollOSBtn:Enable() end
    if self.rollOtherBtn then self.rollOtherBtn:Enable() end
    if self.rerollBtn then self.rerollBtn:Disable() end
end

function LM:ShowTradeWindow(item)
    if not item then return end
    local f = CreateFrame("Frame", "RLSuiteTradeWindow", UIParent)
    f:SetSize(200, 100)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
    })

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("TOP", f, "TOP", 0, -15)
    icon:SetTexture(item.itemTexture or "Interface\Icons\INV_Misc_QuestionMark")

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOP", icon, "BOTTOM", 0, -5)
    text:SetText("Click to pick up item")

    local btn = CreateFrame("Button", nil, f)
    btn:SetAllPoints(icon)
    btn:SetScript("OnClick", function()
        if item.itemLink then
            PickupItem(item.itemLink)
        end
        if TradeFrame and TradeFrame:IsShown() then
            ClickTradeButton(1)
        end
        f:Hide()
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
end
