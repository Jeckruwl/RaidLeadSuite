-- ============================================================
-- RLSuite - LootManager Module
-- ============================================================

RLSuite.lootManager = {}
local LM = RLSuite.lootManager

local L = RLSuite.L

-- Non-overlapping roll/reroll countdowns (AceTimer named timers):
-- restarting a roll cancels the previous timer instead of stacking a
-- second one (which used to double the announcements).
LibStub("AceTimer-3.0"):Embed(LM)

function LM:Init()
    self.db = RLSuiteDB.loot
    self.history = self.db.history or {}
    self.db.history = self.history
    self.currentRoll = nil
    self.preMessage = ""
    self:CreateFrame()
end

function LM:Toggle()
    if RLSuite.mainWindow and RLSuite.mainWindow.ShowTab then
        RLSuite.mainWindow:ShowTab("loot")
        return
    end
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
    f:Hide()
    self.frame = f
    RLSuite.utils:SkinFrame(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -10)
    title:SetText("Loot Manager")
    self.titleFS = title

    self.preMsgText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.preMsgText:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -32)
    self.preMsgText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -32)
    self.preMsgText:SetJustifyH("LEFT")
    self.preMsgText:SetText("")

    local histLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    histLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -50)
    histLabel:SetText("Loot History")

    local filterFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -152, -54)
    filterFS:SetText("Rarity threshold")

    self.rarityFilter = (self.db and self.db.rarityFilter) or "all"
    self.rarityDropdown = RLSuite.utils:CreateDropdown(f, "RLSuiteLootRarityDD", 130, 20)
    self.rarityDropdown:ClearAllPoints()
    self.rarityDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -50)
    RLSuite.utils:SetupDropdown(self.rarityDropdown, {
        { text = "All", value = "all" },
        { text = "Poor", value = 0 },
        { text = "Common", value = 1 },
        { text = "Uncommon", value = 2 },
        { text = "Rare", value = 3 },
        { text = "Epic", value = 4 },
        { text = "Legendary", value = 5 },
    }, self.rarityFilter, function(value)
        LM.rarityFilter = value
        if LM.db then LM.db.rarityFilter = value end
        LM:UpdateHistory()
    end)

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -74)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -74)
    header:SetHeight(18)
    self.histHeader = header
    self:PaintHeader(header)

    self.histBox = CreateFrame("Frame", nil, f)
    self.histBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    self.histBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 78)
    self:SkinBox(self.histBox)

    self.histScroll = CreateFrame("ScrollFrame", "RLSuiteLootHistory", self.histBox, "UIPanelScrollFrameTemplate")
    self.histScroll:SetPoint("TOPLEFT", self.histBox, "TOPLEFT", 6, -6)
    self.histScroll:SetPoint("BOTTOMRIGHT", self.histBox, "BOTTOMRIGHT", -26, 6)

    self.histContent = CreateFrame("Frame", nil, self.histScroll)
    self.histContent:SetWidth(420)
    self.histContent:SetHeight(1)
    self.histScroll:SetScrollChild(self.histContent)
    self.histScroll:SetScript("OnSizeChanged", function(s, w, h)
        if LM.histContent and w and w > 50 then
            LM.histContent:SetWidth(w)
        end
    end)

    self.selBox = CreateFrame("Frame", nil, f)
    self.selBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 40)
    self.selBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 40)
    self.selBox:SetHeight(34)
    self:SkinBox(self.selBox)

    self.selectedItem = nil
    self.selectedItemIcon = self.selBox:CreateTexture(nil, "ARTWORK")
    self.selectedItemIcon:SetSize(24, 24)
    self.selectedItemIcon:SetPoint("LEFT", self.selBox, "LEFT", 8, 0)
    self.selectedItemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.selectedItemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    self.selectedItemText = self.selBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.selectedItemText:SetPoint("LEFT", self.selectedItemIcon, "RIGHT", 8, 0)
    self.selectedItemText:SetPoint("RIGHT", self.selBox, "RIGHT", -8, 0)
    self.selectedItemText:SetJustifyH("LEFT")
    self.selectedItemText:SetText(L["No item selected"])

    self.rollMSBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.rollMSBtn:SetSize(80, 24)
    self.rollMSBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 10)
    self.rollMSBtn:SetText("Roll MS")
    self.rollMSBtn:SetScript("OnClick", function() self:StartRoll("MS") end)

    self.rollOSBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.rollOSBtn:SetSize(80, 24)
    self.rollOSBtn:SetPoint("LEFT", self.rollMSBtn, "RIGHT", 6, 0)
    self.rollOSBtn:SetText("Roll OS")
    self.rollOSBtn:SetScript("OnClick", function() self:StartRoll("OS") end)

    self.rollOtherBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.rollOtherBtn:SetSize(80, 24)
    self.rollOtherBtn:SetPoint("LEFT", self.rollOSBtn, "RIGHT", 6, 0)
    self.rollOtherBtn:SetText("Roll FFA")
    self.rollOtherBtn:SetScript("OnClick", function() self:StartRoll("FFA") end)

    self.rerollBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.rerollBtn:SetSize(80, 24)
    self.rerollBtn:SetPoint("LEFT", self.rollOtherBtn, "RIGHT", 6, 0)
    self.rerollBtn:SetText("Reroll")
    self.rerollBtn:Disable()
    self.rerollBtn:SetScript("OnClick", function() self:DoReroll() end)

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)

    self:EnsureTicker()
end

function LM:SkinBox(box)
    RLSuite.utils:SkinBox(box)
end

function LM:SkinInner()
    self:SkinBox(self.histBox)
    self:SkinBox(self.selBox)
end

function LM:HistMetrics(w)
    w = tonumber(w) or 420
    local timeW, assignedW, typeW, gap, padR = 64, 72, 48, 6, 8
    local itemX = 58
    local assignedX = w - padR - timeW - gap - assignedW
    local typeX = assignedX - gap - typeW
    local inner = typeX - itemX - gap
    if inner < 120 then inner = 120 end
    local itemW = math.floor(inner * 0.58)
    local bossW = inner - itemW
    local bossX = itemX + itemW + gap
    return {
        itemX = itemX, itemW = itemW,
        bossX = bossX, bossW = bossW,
        typeX = typeX, typeW = typeW,
        assignedX = assignedX, assignedW = assignedW,
        timeW = timeW, padR = padR,
    }
end

function LM:PaintHeader(header)
    self.histHeads = {}
    local function add(key, text)
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetText(text)
        fs:SetTextColor(1, 0.82, 0)
        self.histHeads[key] = fs
        return fs
    end
    add("num", "#"):SetPoint("LEFT", header, "LEFT", 6, 0)
    add("item", "Item")
    add("boss", "Boss")
    add("type", "Type")
    add("assigned", "Assigned")
    local tfs = add("time", "Time left")
    tfs:SetJustifyH("RIGHT")
    self:LayoutHeader()
end

function LM:LayoutHeader()
    local header = self.histHeader
    if not header or not self.histHeads then return end
    local w = header:GetWidth()
    if not w or w < 80 then w = 420 end
    local m = self:HistMetrics(w)
    local h = self.histHeads
    h.item:ClearAllPoints()
    h.item:SetPoint("LEFT", header, "LEFT", m.itemX, 0)
    h.boss:ClearAllPoints()
    h.boss:SetPoint("LEFT", header, "LEFT", m.bossX, 0)
    h.type:ClearAllPoints()
    h.type:SetPoint("LEFT", header, "LEFT", m.typeX, 0)
    h.assigned:ClearAllPoints()
    h.assigned:SetPoint("LEFT", header, "LEFT", m.assignedX, 0)
    h.time:ClearAllPoints()
    h.time:SetPoint("RIGHT", header, "RIGHT", -m.padR, 0)
end

function LM:EnsureTicker()
    if self.remainTicker then return end
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(s, elapsed)
        s.t = (s.t or 0) + elapsed
        if s.t < 1 then return end
        s.t = 0
        for _, rec in ipairs(LM.remainTexts or {}) do
            if rec.fs and rec.entry then
                rec.fs:SetText(LM:TradeRemaining(rec.entry))
            end
        end
    end)
    self.remainTicker = f
end

function LM:SetPreMessage(msg)
    self.preMessage = msg or ""
    if self.preMsgText then
        self.preMsgText:SetText(msg)
    end
end

function LM:SpawnDebugLoot()
    local raid = (RLSuiteDB.groupmaking and RLSuiteDB.groupmaking.raid) or "Icecrown Citadel"
    local pool = (RLSuite.debugLoot and RLSuite.debugLoot[raid]) or {49623, 49908, 52025}
    local bosses = (RLSuite.raidDB[raid] and RLSuite.raidDB[raid].bosses) or {"Unknown"}
    local ids = {}
    for _, id in ipairs(pool) do table.insert(ids, id) end
    local n = math.min(6, #ids)
    for i = #ids, 2, -1 do
        local j = math.random(1, i)
        ids[i], ids[j] = ids[j], ids[i]
    end
    for i = 1, n do
        local id = ids[i]
        local itemName, itemLink, quality, _, _, _, _, _, _, itemTexture = GetItemInfo(id)
        if not itemLink then
            itemLink = "|cffff8000|Hitem:" .. id .. ":0:0:0:0:0:0:0:80|h[Debug Item " .. id .. "]|h|r"
            itemName = "Debug Item " .. id
            itemTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
            quality = 5
        end
        local boss = bosses[((i - 1) % #bosses) + 1] or "Unknown"
        table.insert(self.history, {
            id = #self.history + 1,
            itemLink = itemLink,
            itemName = itemName,
            itemTexture = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark",
            boss = "[DBG] " .. boss,
            itemType = self:DetectItemType(itemLink, itemName),
            quality = quality or 4,
            time = time(),
            assignedTo = nil,
        })
    end
    self:UpdateHistory()
    RLSuite.utils:Print(string.format(L["Loot debug: %d items from %s"], n, raid))
end

function LM:OnLootMessage(msg)
    local itemLink = RLSuite.utils:GetItemLinkFromChat(msg or "")
    if not itemLink then return end
    local itemName, _, quality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
    if itemName then
        self:AddToHistory(itemLink, itemName, itemTexture, quality)
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
            local itemName, _, quality, _, _, _, _, _, _, itemTexture = GetItemInfo(p.link)
            if itemName then
                LM:AddToHistory(p.link, itemName, itemTexture, quality)
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

function LM:AddToHistory(itemLink, itemName, itemTexture, quality)
    if quality == nil and itemLink then
        local _, _, q = GetItemInfo(itemLink)
        quality = q
    end
    local entry = {
        id = #self.history + 1,
        itemLink = itemLink,
        itemName = itemName,
        itemTexture = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark",
        boss = "Unknown",
        itemType = self:DetectItemType(itemLink, itemName),
        quality = quality,
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

function LM:EntryQuality(entry)
    if not entry then return -1 end
    if entry.quality ~= nil then return entry.quality end
    if entry.itemLink then
        local _, _, q = GetItemInfo(entry.itemLink)
        if q ~= nil then
            entry.quality = q
            return q
        end
    end
    return -1
end

function LM:MatchesFilter(entry)
    local f = self.rarityFilter
    if self.db and self.db.rarityFilter ~= nil then
        f = self.db.rarityFilter
    end
    if f == nil or f == "all" then return true end
    local q = self:EntryQuality(entry)
    return q >= tonumber(f)
end

function LM:TradeRemaining(entry)
    local start = (entry and entry.time) or 0
    local window = (self.db and self.db.tradeWindow) or 7200
    local left = window - (time() - start)
    if left <= 0 then return "Expired" end
    local h = math.floor(left / 3600)
    local m = math.floor((left % 3600) / 60)
    local s = left % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

function LM:UpdateHistory()
    if not self.histContent then return end
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    self:SkinBox(self.histBox)
    self:SkinBox(self.selBox)
    for _, child in ipairs(self.histRows or {}) do
        child:Hide()
        child:SetParent(nil)
    end
    self.histRows = {}
    self.remainTexts = {}

    local w = self.histContent:GetWidth() or 420
    if self.histScroll then
        local sw = self.histScroll:GetWidth()
        if sw and sw > 50 then
            w = sw
            self.histContent:SetWidth(w)
        end
    end

    local y = 0
    for i = #self.history, 1, -1 do
        local entry = self.history[i]
        if self:MatchesFilter(entry) then
            local row = CreateFrame("Button", nil, self.histContent)
            self.histRows[#self.histRows + 1] = row
            row:EnableMouse(true)
            row:RegisterForClicks("LeftButtonUp")
            row:SetHeight(26)
            row:SetPoint("TOPLEFT", self.histContent, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", self.histContent, "TOPRIGHT", 0, -y)
            row.entry = entry
            RLSuite.utils:SkinRow(row, self.selectedItem == entry)

            local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            num:SetPoint("LEFT", row, "LEFT", 6, 0)
            num:SetWidth(28)
            num:SetJustifyH("LEFT")
            num:SetText("#" .. (entry.id or 0))

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetPoint("LEFT", row, "LEFT", 36, 0)
            icon:SetTexture(entry.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local m = self:HistMetrics(w)
            self:LayoutHeader()

            local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            name:SetPoint("LEFT", row, "LEFT", m.itemX, 0)
            name:SetWidth(m.itemW)
            name:SetJustifyH("LEFT")
            name:SetText(entry.itemName or "Unknown")
            local q = self:EntryQuality(entry)
            if GetItemQualityColor and q and q >= 0 then
                local r, g, b = GetItemQualityColor(q)
                name:SetTextColor(r or 1, g or 1, b or 1)
            end

            local boss = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            boss:SetPoint("LEFT", row, "LEFT", m.bossX, 0)
            boss:SetWidth(m.bossW)
            boss:SetJustifyH("LEFT")
            boss:SetText(entry.boss or "Unknown")

            local itype = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            itype:SetPoint("LEFT", row, "LEFT", m.typeX, 0)
            itype:SetWidth(m.typeW)
            itype:SetJustifyH("LEFT")
            itype:SetText(entry.itemType or "BOP")

            local remain = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            remain:SetPoint("RIGHT", row, "RIGHT", -m.padR, 0)
            remain:SetWidth(m.timeW)
            remain:SetJustifyH("RIGHT")
            remain:SetText(self:TradeRemaining(entry))

            local assigned = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            assigned:SetPoint("LEFT", row, "LEFT", m.assignedX, 0)
            assigned:SetWidth(m.assignedW)
            assigned:SetJustifyH("LEFT")
            assigned:SetText(entry.assignedTo or "-")
            table.insert(self.remainTexts, { fs = remain, entry = entry })

            row:SetScript("OnClick", function()
                self:SelectItem(entry)
                self:RefreshHistoryHighlight()
            end)
            row:SetScript("OnEnter", function(s)
                if entry.itemLink then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    pcall(function() GameTooltip:SetHyperlink(entry.itemLink) end)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            y = y + 28
        end
    end
    self.histContent:SetHeight(math.max(y, 1))
    self:EnsureTicker()
end

function LM:SelectItem(entry)
    self.selectedItem = entry
    if self.selectedItemIcon then
        self.selectedItemIcon:SetTexture(entry.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    if self.selectedItemText then
        self.selectedItemText:SetText(entry.itemName or "Unknown")
    end
end

-- Highlights the selected row without rebuilding the list (see notes on
-- RefreshWhisperHighlight: rebuilding inside the click breaks future clicks).
function LM:RefreshHistoryHighlight()
    for _, row in ipairs(self.histRows or {}) do
        if row and row.SetBackdrop then
            RLSuite.utils:SkinRow(row, self.selectedItem == row.entry)
        end
    end
end

function LM:StartRoll(rollType)
    if not self.selectedItem then
        RLSuite.utils:Print(L["Select an item from the history first!"])
        return
    end

    self.currentRoll = {
        item = self.selectedItem,
        type = rollType,
        rolls = {},
        timer = self.db.rollDuration or 10,
        active = true,
    }

    local typeNames = { MS = "MS", OS = "OS", FFA = "Free For All", OTHER = "Free For All" }
    local msg = "Roll " .. (typeNames[rollType] or rollType or "MS") .. " for " .. (self.selectedItem.itemName or "Unknown")
    if self.preMessage and self.preMessage ~= "" then
        msg = self.preMessage .. " " .. msg
    end
    RLSuite.utils:SendChat(msg, "RAID")
    -- barra-timer in DBM/BigWigs se installati (durata del roll)
    RLSuite.utils:StartDbmTimer(self.db.rollDuration or 10, "Roll " .. (self.selectedItem.itemName or "Unknown"),
        self.selectedItem.itemTexture)

    if RLSuite.DebugMode and RLSuite:DebugMode() then
        local me = UnitName("player") or "You"
        local names = {me, "Tankbot", "Healbot", "Dpsbot", "Huntbot"}
        local template = self:GetRollTemplate()
        for _, n in ipairs(names) do
            if math.random(1, 10) > 2 then
                self:OnSystemRoll(string.format(template, n, math.random(1, 100), 1, 100))
            end
        end
    end

    if self.rollMSBtn then self.rollMSBtn:Disable() end
    if self.rollOSBtn then self.rollOSBtn:Disable() end
    if self.rollOtherBtn then self.rollOtherBtn:Disable() end

    -- Non-overlapping: cancel any previous roll/reroll countdown.
    self:CancelRollTimers()
    self.rollRemaining = self.currentRoll.timer
    self.rollTimer = self:ScheduleRepeatingTimer("RollTick", 1)

    if self.rollFrame then
        self.rollFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
    end
    self.rollFrame = CreateFrame("Frame")
    self.rollFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    self.rollFrame:SetScript("OnEvent", function(self2, event, msg)
        LM:OnSystemRoll(msg)
    end)
end

-- Cancels the running roll and reroll countdown timers, if any.
function LM:CancelRollTimers()
    if self.rollTimer then
        self:CancelTimer(self.rollTimer, true)
        self.rollTimer = nil
    end
    if self.rerollTimer then
        self:CancelTimer(self.rerollTimer, true)
        self.rerollTimer = nil
    end
end

function LM:RollTick()
    self.rollRemaining = (self.rollRemaining or 0) - 1
    if self.rollRemaining <= 0 then
        if self.rollTimer then
            self:CancelTimer(self.rollTimer, true)
            self.rollTimer = nil
        end
        self:AnnounceWinner()
        return
    end
    if self.rollRemaining <= 3 then
        RLSuite.utils:SendChat("Roll ending in " .. self.rollRemaining .. "...", "RAID")
    end
end

-- Localized roll template, e.g. "%s rolls %d (%d-%d)" on enUS.
function LM:GetRollTemplate()
    return RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
end

-- Builds a Lua pattern from the localized RANDOM_ROLL_RESULT template so
-- system roll messages are parsed on any client locale (enUS "Name rolls 42
-- (1-100)", itIT "Name tira 42 (1-100)", deDE "Name wuerfelt 42 (1-100)",
-- etc.) instead of matching English-only wording.
function LM:GetRollPattern()
    if self._rollPattern then return self._rollPattern end
    local t = self:GetRollTemplate()
    -- Mark the substitution tokens so the remaining text can be escaped.
    t = string.gsub(t, "%%s", "\001NAME\001")
    t = string.gsub(t, "%%d", "\001NUM\001")
    -- Escape Lua pattern magic characters in the literal text.
    t = string.gsub(t, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    -- Restore capture groups.
    t = string.gsub(t, "\001NAME\001", "(.+)")
    t = string.gsub(t, "\001NUM\001", "(%%d+)")
    self._rollPattern = t
    return t
end

function LM:OnSystemRoll(msg)
    if not self.currentRoll or not self.currentRoll.active then return end
    local name, roll, _, maxRoll = string.match(msg or "", self:GetRollPattern())
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
        RLSuite.utils:SendChat((winner.name or "?") .. " wins " .. (self.currentRoll.item.itemName or "Unknown") .. " with " .. (winner.roll or 0) .. "! Please trade.", "RAID")
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
    -- barra-timer in DBM/BigWigs se installati (durata del reroll)
    RLSuite.utils:StartDbmTimer(self.db.rerollDuration or 5, "Reroll " .. (self.currentRoll.item.itemName or "Unknown"),
        self.currentRoll.item.itemTexture)

    self.currentRoll.rolls = {}
    self.currentRoll.active = true
    if self.rerollBtn then self.rerollBtn:Disable() end

    -- Non-overlapping: cancel any previous reroll/roll countdown.
    self:CancelRollTimers()
    self.rerollRemaining = self.db.rerollDuration or 5
    self.rerollTimer = self:ScheduleRepeatingTimer("RerollTick", 1)
end

function LM:RerollTick()
    self.rerollRemaining = (self.rerollRemaining or 0) - 1
    if self.rerollRemaining <= 0 then
        if self.rerollTimer then
            self:CancelTimer(self.rerollTimer, true)
            self.rerollTimer = nil
        end
        self:ProcessReroll()
    end
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
    RLSuite.utils:SkinFrame(f)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("TOP", f, "TOP", 0, -15)
    icon:SetTexture(item.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOP", icon, "BOTTOM", 0, -5)
    text:SetText("Click to pick up item")

    local btn = CreateFrame("Button", nil, f)
    btn:SetAllPoints(icon)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function()
        if item.itemLink then
            PickupItem(item.itemLink)
        end
        if TradeFrame and TradeFrame:IsShown() then
            ClickTradeButton(1)
        end
        f:Hide()
    end)

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)
end
