-- ============================================================
-- RLSuite - GroupMaking Module
-- ============================================================

RLSuite.groupmaking = {}
local GM = RLSuite.groupmaking

local SLOT_SIZE = 32
local SLOT_SPACING = 4

local ROLE_COLORS = {
    tank   = {r=0.2, g=0.4, b=1.0},
    healer = {r=0.2, g=1.0, b=0.2},
    dps    = {r=1.0, g=0.2, b=0.2},
}

function GM:Init()
    self.db = RLSuiteDB.groupmaking
    self.whisperDB = RLSuiteDB.whisplist
    self.spamActive = false
    self.compSlots = {}
    self.whisperEntries = {}
    self.selectedEntry = nil
    self.loadingComp = true
    self:CreateMainWindow()
    self:CreateWhisplistWindow()
    self:LoadCompFromDB()
    self.loadingComp = false
end

function GM:Toggle()
    if RLSuite.mainWindow and RLSuite.mainWindow.ShowTab then
        RLSuite.mainWindow:ShowTab("group")
        return
    end
    if self.mainFrame and self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    elseif self.mainFrame then
        self.mainFrame:Show()
    end
end

-- ============================================================
-- MAIN WINDOW
-- ============================================================
function GM:CreateMainWindow()
    local f = CreateFrame("Frame", "RLSuiteGroupMaking", UIParent)
    f:SetSize(500, 600)
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
    self.mainFrame = f
    RLSuite.utils:SkinFrame(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -10)
    title:SetText("Group Making")

    local raidLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -36)
    raidLabel:SetText("Raid:")

    self.raidDropdown = RLSuite.utils:CreateDropdown(f, "RLSuiteRaidDropdown", 180, 22)
    self.raidDropdown:SetPoint("LEFT", raidLabel, "RIGHT", 8, 0)
    self:PopulateRaidDropdown()

    local diffLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diffLabel:SetPoint("LEFT", self.raidDropdown, "RIGHT", 12, 0)
    diffLabel:SetText("Diff:")

    self.diffDropdown = RLSuite.utils:CreateDropdown(f, "RLSuiteDiffDropdown", 60, 22)
    self.diffDropdown:SetPoint("LEFT", diffLabel, "RIGHT", 8, 0)
    RLSuite.utils:SetupDropdown(self.diffDropdown, {"10", "25"}, self.db.difficulty or "10", function(value)
        self:SetDifficulty(value)
    end)

    local diff10 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    diff10:SetSize(30, 22)
    diff10:SetPoint("LEFT", self.diffDropdown, "RIGHT", 6, 0)
    diff10:SetText("10")
    diff10:SetScript("OnClick", function() self:SetDifficulty("10") end)

    local diff25 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    diff25:SetSize(30, 22)
    diff25:SetPoint("LEFT", diff10, "RIGHT", 2, 0)
    diff25:SetText("25")
    diff25:SetScript("OnClick", function() self:SetDifficulty("25") end)

    self.topRow = CreateFrame("Frame", nil, f)
    self.topRow:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -66)
    self.topRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -66)
    self.topRow:SetHeight(200)

    self.compBox = CreateFrame("Frame", nil, self.topRow)
    self.compBox:SetPoint("TOPLEFT", self.topRow, "TOPLEFT", 0, 0)
    self.compBox:SetPoint("BOTTOMLEFT", self.topRow, "BOTTOMLEFT", 0, 0)
    self.compBox:SetWidth(200)
    RLSuite.utils:SkinBox(self.compBox)

    local compLabel = self.compBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    compLabel:SetPoint("TOPLEFT", self.compBox, "TOPLEFT", 8, -6)
    compLabel:SetText("Composizione")
    compLabel:SetTextColor(1, 0.82, 0)

    self.compFrame = CreateFrame("Frame", nil, self.compBox)
    self.compFrame:SetPoint("TOPLEFT", self.compBox, "TOPLEFT", 8, -24)
    self.compFrame:SetSize((SLOT_SIZE + SLOT_SPACING) * 5 - SLOT_SPACING, (SLOT_SIZE + SLOT_SPACING) * 2 - SLOT_SPACING)

    self.classBox = CreateFrame("Frame", nil, self.topRow)
    self.classBox:SetPoint("TOPRIGHT", self.topRow, "TOPRIGHT", 0, 0)
    self.classBox:SetPoint("BOTTOMRIGHT", self.topRow, "BOTTOMRIGHT", 0, 0)
    self.classBox:SetWidth(200)
    RLSuite.utils:SkinBox(self.classBox)

    local classBarLabel = self.classBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classBarLabel:SetPoint("TOPLEFT", self.classBox, "TOPLEFT", 8, -6)
    classBarLabel:SetText("Clicca spec per aggiungere")
    classBarLabel:SetTextColor(1, 0.82, 0)

    self.classBar = CreateFrame("Frame", nil, self.classBox)
    self.classBar:SetPoint("TOPLEFT", self.classBox, "TOPLEFT", 8, -24)
    self.classBar:SetPoint("TOPRIGHT", self.classBox, "TOPRIGHT", -8, -24)
    self.classBar:SetHeight(160)

    self.topRow:SetScript("OnSizeChanged", function(s, w, h)
        GM:LayoutGroupPanels(w)
    end)

    self.reqBox = CreateFrame("Frame", nil, f)
    self.reqBox:SetPoint("TOPLEFT", self.topRow, "BOTTOMLEFT", 0, -8)
    self.reqBox:SetPoint("TOPRIGHT", self.topRow, "BOTTOMRIGHT", 0, -8)
    self.reqBox:SetHeight(88)
    RLSuite.utils:SkinBox(self.reqBox)

    local reservedLabel = self.reqBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reservedLabel:SetPoint("TOPLEFT", self.reqBox, "TOPLEFT", 8, -8)
    reservedLabel:SetText("Pezzi riservati")
    reservedLabel:SetTextColor(1, 0.82, 0)

    self.reservedEdit = CreateFrame("EditBox", "RLSuiteReservedEdit", self.reqBox, "InputBoxTemplate")
    self.reservedEdit:SetHeight(20)
    self.reservedEdit:SetPoint("TOPLEFT", reservedLabel, "BOTTOMLEFT", 4, -4)
    self.reservedEdit:SetPoint("RIGHT", self.reqBox, "RIGHT", -12, 0)
    self.reservedEdit:SetAutoFocus(false)
    self.reservedEdit:SetScript("OnTextChanged", function() self:SaveComp() end)

    local otherLabel = self.reqBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    otherLabel:SetPoint("TOPLEFT", self.reservedEdit, "BOTTOMLEFT", -4, -6)
    otherLabel:SetText("Altre richieste")
    otherLabel:SetTextColor(1, 0.82, 0)

    self.otherEdit = CreateFrame("EditBox", "RLSuiteOtherEdit", self.reqBox, "InputBoxTemplate")
    self.otherEdit:SetHeight(20)
    self.otherEdit:SetPoint("TOPLEFT", otherLabel, "BOTTOMLEFT", 4, -4)
    self.otherEdit:SetPoint("RIGHT", self.reqBox, "RIGHT", -12, 0)
    self.otherEdit:SetAutoFocus(false)
    self.otherEdit:SetScript("OnTextChanged", function() self:SaveComp() end)

    self.previewBox = CreateFrame("Frame", nil, f)
    self.previewBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
    self.previewBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
    self.previewBox:SetHeight(58)
    RLSuite.utils:SkinBox(self.previewBox)

    self.previewText = self.previewBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.previewText:SetPoint("TOPLEFT", self.previewBox, "TOPLEFT", 8, -8)
    self.previewText:SetPoint("BOTTOMRIGHT", self.previewBox, "BOTTOMRIGHT", -8, 8)
    self.previewText:SetJustifyH("LEFT")
    self.previewText:SetJustifyV("TOP")
    self.previewText:SetText("Anteprima messaggio...")

    self.spamBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.spamBtn:SetSize(100, 24)
    self.spamBtn:SetPoint("BOTTOMLEFT", self.previewBox, "TOPLEFT", 0, 8)
    self.spamBtn:SetText("Start Spam")
    self.spamBtn:SetScript("OnClick", function() self:ToggleSpam() end)

    self.whisplistBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.whisplistBtn:SetSize(100, 24)
    self.whisplistBtn:SetPoint("LEFT", self.spamBtn, "RIGHT", 8, 0)
    self.whisplistBtn:SetText("Whisplist")
    self.whisplistBtn:SetScript("OnClick", function() self:ToggleWhisplist() end)

    self.previewBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.previewBtn:SetSize(100, 24)
    self.previewBtn:SetPoint("LEFT", self.whisplistBtn, "RIGHT", 8, 0)
    self.previewBtn:SetText("Preview Msg")
    self.previewBtn:SetScript("OnClick", function() self:ShowMessagePreview() end)

    self.showSpecsCheck = CreateFrame("CheckButton", "RLSuiteShowSpecsCheck", f, "UICheckButtonTemplate")
    self.showSpecsCheck:SetSize(24, 24)
    self.showSpecsCheck:SetPoint("LEFT", self.previewBtn, "RIGHT", 6, 0)
    self.showSpecsCheck:SetChecked(self.db.showSpecsInMessage and true or false)
    self.showSpecsCheck:SetScript("OnClick", function(s)
        self.db.showSpecsInMessage = s:GetChecked() and true or false
        self:UpdateMessagePreview()
        self:SaveComp()
    end)

    local specsLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    specsLbl:SetPoint("LEFT", self.showSpecsCheck, "RIGHT", 0, 0)
    specsLbl:SetText("Show specs in message")
    specsLbl:SetTextColor(1, 0.82, 0)

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ORA posso chiamare BuildCompSlots e BuildClassBar (previewText esiste)
    self:BuildCompSlots()
    self:BuildClassBar()
end

-- ============================================================
-- COMP SLOTS
-- ============================================================
function GM:BuildCompSlots()
    local maxSlots = 25
    self.compSlots = {}
    for i = 1, maxSlots do
        local slot = CreateFrame("Button", "RLSuiteCompSlot"..i, self.compFrame)
        slot:SetSize(SLOT_SIZE, SLOT_SIZE)
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        slot:SetPoint("TOPLEFT", self.compFrame, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), -row * (SLOT_SIZE + SLOT_SPACING))
        -- Sfondo slot visibile
        slot:SetBackdrop({
            bgFile = "Interface\Buttons\UI-Quickslot",
            edgeFile = "Interface\Buttons\UI-Quickslot",
            tile = false, tileSize = 32, edgeSize = 32,
            insets = {left=0, right=0, top=0, bottom=0}
        })
        slot:SetBackdropColor(0.3, 0.3, 0.3, 0.9)
        slot:Show()
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        slot:SetScript("OnClick", function(s, button)
            if button == "RightButton" then
                self:ClearSlot(i)
            end
        end)

        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints(slot)
        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.icon:Hide()

        slot.roleBorder = slot:CreateTexture(nil, "OVERLAY")
        slot.roleBorder:SetTexture("Interface\Buttons\UI-ActionButton-Border")
        slot.roleBorder:SetSize(SLOT_SIZE + 12, SLOT_SIZE + 12)
        slot.roleBorder:SetPoint("CENTER", slot, "CENTER")
        slot.roleBorder:Hide()

        slot.roleText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slot.roleText:SetPoint("BOTTOM", slot, "BOTTOM", 0, 2)
        slot.roleText:SetFont("Fonts\FRIZQT__.TTF", 8, "OUTLINE")

        slot.index = i
        slot.class = nil
        slot.role = nil
        slot.spec = nil
        slot.filled = false
        slot.playerName = nil

        self.compSlots[i] = slot
    end
    self:SetDifficulty(self.db.difficulty or "10")
end

function GM:SetDifficulty(diff)
    self.db.difficulty = diff
    if self.diffDropdown and self.diffDropdown.text then
        self.diffDropdown.text:SetText(diff)
    end
    local numSlots = tonumber(diff) or 10
    for i, slot in ipairs(self.compSlots) do
        if slot then
            if i <= numSlots then
                slot:Show()
            else
                slot:Hide()
                self:ClearSlot(i)
            end
        end
    end
    local rows = math.ceil(numSlots / 5)
    local newHeight = rows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
    self.compFrame:SetSize((SLOT_SIZE + SLOT_SPACING) * 5 - SLOT_SPACING, newHeight)
    self:LayoutGroupPanels()
    self:UpdateMessagePreview()
    self:SaveComp()
end

function GM:LayoutGroupPanels(rowW)
    if not self.topRow then return end
    if self._layoutLock then return end
    self._layoutLock = true
    local w = rowW or self.topRow:GetWidth() or 400
    local half = math.max(80, math.floor((w - 8) / 2))
    if self.compBox then self.compBox:SetWidth(half) end
    if self.classBox then self.classBox:SetWidth(half) end

    local numSlots = tonumber(self.db and self.db.difficulty or "10") or 10
    local slotRows = math.ceil(numSlots / 5)
    local compH = slotRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + 36
    self:LayoutClassBar()
    local specH = (self._specBarHeight or 120) + 36
    local h = math.max(compH, specH, 140)
    self.topRow:SetHeight(h)
    if self.classBar then
        self.classBar:SetHeight(math.max(40, h - 32))
    end
    self._layoutLock = false
end

function GM:ClearSlot(index)
    local slot = self.compSlots[index]
    if not slot then return end
    slot.class = nil
    slot.role = nil
    slot.spec = nil
    slot.filled = false
    slot.playerName = nil
    if slot.icon then slot.icon:Hide() end
    if slot.roleBorder then slot.roleBorder:Hide() end
    if slot.roleText then slot.roleText:SetText("") end
    self:UpdateMessagePreview()
    self:SaveComp()
end

function GM:FillSlot(index, class, role, playerName, spec)
    local slot = self.compSlots[index]
    if not slot or not class then return end
    slot.class = class
    slot.spec = spec
    local fromSpec = RLSuite.utils:RoleFromSpec(class, spec)
    slot.role = fromSpec or role or "dps"
    slot.filled = true
    slot.playerName = playerName or nil
    if slot.icon then
        slot.icon:SetTexture(RLSuite.utils:SpecIcon(class, slot.spec))
        slot.icon:Show()
    end
    local r, g, b = RLSuite.utils:GetClassColor(class)
    if slot.roleBorder then
        slot.roleBorder:SetVertexColor(r, g, b)
        slot.roleBorder:Show()
    end
    if slot.roleText then
        slot.roleText:SetText((slot.role or "dps"):sub(1,1):upper())
    end
    self:UpdateMessagePreview()
    self:SaveComp()
end

function GM:FindEmptySlotForRole(role)
    local numSlots = tonumber(self.db.difficulty or "10")
    if role then
        for i = 1, numSlots do
            local slot = self.compSlots[i]
            if slot and not slot.filled and slot.role == role then
                return i
            end
        end
    end
    for i = 1, numSlots do
        local slot = self.compSlots[i]
        if slot and not slot.filled then
            return i
        end
    end
    return nil
end

-- ============================================================
-- CLASS BAR - FIX: non usare GetNormalTexture()
-- ============================================================
function GM:BuildClassBar()
    local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
    self.specCells = {}
    for _, class in ipairs(classes) do
        local data = RLSuite.classData[class]
        local specs = data and data.specs or {}
        local cr, cg, cb = RLSuite.utils:GetClassColor(class)
        local cell = CreateFrame("Frame", nil, self.classBar)
        local nameFS = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, 0)
        nameFS:SetText(RLSuite.utils:ClassLabel(class))
        nameFS:SetTextColor(cr, cg, cb)
        local buttons = {}
        for _, spec in ipairs(specs) do
            if type(spec) == "table" then
                local btn = CreateFrame("Button", nil, cell)
                btn:SetSize(22, 22)
                btn:SetBackdrop({
                    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 8,
                    insets = {left = 1, right = 1, top = 1, bottom = 1},
                })
                btn:SetBackdropColor(0, 0, 0, 0.8)
                btn:SetBackdropBorderColor(cr, cg, cb, 1)

                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
                tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
                tex:SetTexture(spec.icon or RLSuite.utils:ClassIcon(class))
                tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                btn.bgTex = tex

                btn.class = class
                btn.spec = spec.name
                btn.role = spec.role
                btn:SetScript("OnClick", function(s)
                    self:OnClassBarClick(s.class, s.role, s.spec)
                end)
                btn:SetScript("OnEnter", function(s)
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(s.spec or "?", 1, 0.82, 0)
                    GameTooltip:AddLine(RLSuite.utils:ClassLabel(s.class) .. "  " .. (s.role or ""), cr, cg, cb)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                btn:Show()
                table.insert(buttons, btn)
            end
        end
        table.insert(self.specCells, {frame = cell, buttons = buttons})
    end
    self.classBar:SetScript("OnSizeChanged", function()
        GM:LayoutClassBar()
    end)
    self:LayoutClassBar()
    self:LayoutGroupPanels()
end

function GM:LayoutClassBar()
    if not self.classBar or not self.specCells then return end
    local w = self.classBar:GetWidth() or 0
    if w < 40 then return end
    local COLS = 3
    local ICON_COLS = 3
    local GAP = 2
    local ROW_GAP = 0
    local NAME_H = 12
    local iconGap = 1
    local colW = math.floor((w - GAP * (COLS - 1)) / COLS)
    if colW < 40 then colW = 40 end

    local maxInRow = 3
    for _, cell in ipairs(self.specCells) do
        if #cell.buttons > 0 and #cell.buttons < maxInRow then
            maxInRow = #cell.buttons
        end
    end
    if maxInRow < 1 then maxInRow = 1 end
    local iconSize = math.floor((colW - 2 - (maxInRow - 1) * iconGap) / maxInRow)
    if iconSize > 36 then iconSize = 36 end
    if iconSize < 24 then iconSize = 24 end

    local function cellHeight(n)
        local n = n or 1
        if n < 1 then n = 1 end
        local ir = math.ceil(n / ICON_COLS)
        return NAME_H + ir * iconSize + (ir - 1) * iconGap
    end

    local rows = math.ceil(#self.specCells / COLS)
    local rowH = {}
    for r = 1, rows do
        local h = 0
        for c = 1, COLS do
            local cell = self.specCells[(r - 1) * COLS + c]
            if cell then
                local ch = cellHeight(#cell.buttons)
                if ch > h then h = ch end
            end
        end
        rowH[r] = h
    end

    local y = 0
    for i, cell in ipairs(self.specCells) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        if col == 0 and row > 0 then
            y = y - (rowH[row] + ROW_GAP)
        end
        local x = col * (colW + GAP)
        local ch = rowH[row + 1]
        cell.frame:ClearAllPoints()
        cell.frame:SetSize(colW, ch)
        cell.frame:SetPoint("TOPLEFT", self.classBar, "TOPLEFT", x, y)
        for j, btn in ipairs(cell.buttons) do
            local ic = (j - 1) % ICON_COLS
            local ir = math.floor((j - 1) / ICON_COLS)
            btn:SetSize(iconSize, iconSize)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", cell.frame, "TOPLEFT", ic * (iconSize + iconGap), -(NAME_H + ir * (iconSize + iconGap)))
        end
    end
    local total = 0
    for r = 1, rows do
        total = total + rowH[r]
        if r < rows then total = total + ROW_GAP end
    end
    self._specBarHeight = total
end

function GM:OnClassBarClick(class, role, spec)
    local slotIndex = self:FindEmptySlotForRole(nil)
    if slotIndex then
        self:FillSlot(slotIndex, class, role, nil, spec)
    else
        RLSuite.utils:Print("Nessuno slot disponibile per " .. (spec or class or "?"))
    end
end

-- ============================================================
-- DROPDOWN
-- ============================================================
function GM:PopulateRaidDropdown()
    local raids = {}
    for name, _ in pairs(RLSuite.raidDB) do
        table.insert(raids, name)
    end
    table.sort(raids)
    self.raidList = raids
    local current = self.db.raid
    if not current or current == "" or not RLSuite.raidDB[current] then
        current = raids[1]
        self.db.raid = current
    end
    RLSuite.utils:SetupDropdown(self.raidDropdown, raids, current, function(value)
        self.db.raid = value
        self:UpdateMessagePreview()
        self:SaveComp()
    end)
end

-- ============================================================
-- MESSAGE
-- ============================================================
function GM:BuildSpamMessage()
    local raid = self.db.raid or "Raid"
    local diff = self.db.difficulty or "10"
    local msg = "LF " .. diff .. "m " .. raid

    local needed = {tank = 0, healer = 0, dps = 0}
    local specLists = {tank = {}, healer = {}, dps = {}}
    local hasComp = false
    local numSlots = tonumber(diff) or 10
    for i = 1, numSlots do
        local slot = self.compSlots[i]
        if slot and slot.filled then
            hasComp = true
            if not slot.playerName then
                local role = slot.role
                if not role then
                    role = RLSuite.utils:RoleFromSpec(slot.class, slot.spec) or "dps"
                end
                needed[role] = (needed[role] or 0) + 1
                local specName = RLSuite.utils:SpecShortName(slot.class, slot.spec)
                if specName and specName ~= "" then
                    table.insert(specLists[role], specName)
                end
            end
        end
    end

    local roles = {}
    local showSpecs = self.db and self.db.showSpecsInMessage
    if showSpecs then
        for _, role in ipairs({"tank", "healer", "dps"}) do
            if needed[role] and needed[role] > 0 then
                table.insert(roles, role .. "(" .. table.concat(specLists[role], ", ") .. ")")
            end
        end
    else
        if needed.tank > 0 then table.insert(roles, needed.tank .. " tank") end
        if needed.healer > 0 then table.insert(roles, needed.healer .. " healer") end
        if needed.dps > 0 then table.insert(roles, needed.dps .. " dps") end
    end
    if #roles > 0 then
        msg = msg .. " - Need: " .. table.concat(roles, ", ")
    elseif hasComp then
        msg = msg .. " - FULL"
    end

    local reservedText = self.reservedEdit and self.reservedEdit:GetText() or ""
    if reservedText ~= "" then
        msg = msg .. " | Res: " .. reservedText
    end

    local otherText = self.otherEdit and self.otherEdit:GetText() or ""
    if otherText ~= "" then
        msg = msg .. " | " .. otherText
    end

    return msg
end

function GM:UpdateMessagePreview()
    if self.previewText then
        self.previewText:SetText(self:BuildSpamMessage())
    end
end

function GM:ShowMessagePreview()
    self:UpdateMessagePreview()
    if self.previewText then
        RLSuite.utils:Print("Messaggio: " .. (self.previewText:GetText() or ""))
    end
end

-- ============================================================
-- SPAMMER
-- ============================================================
function GM:ToggleSpam()
    if self.spamActive then
        self:StopSpam()
    else
        self:StartSpam()
    end
end

function GM:StartSpam()
    self.spamActive = true
    if self.spamBtn then self.spamBtn:SetText("Stop Spam") end
    self:DoSpam()
    self.spamElapsed = 0
    self.spamInterval = self.db.spamInterval or 60
    if not self.spamFrame then
        self.spamFrame = CreateFrame("Frame")
    end
    self.spamFrame:SetScript("OnUpdate", function(self2, elapsed)
        GM.spamElapsed = GM.spamElapsed + elapsed
        if GM.spamElapsed >= GM.spamInterval then
            GM.spamElapsed = 0
            GM:DoSpam()
        end
    end)
    self.spamFrame:Show()
    RLSuite.utils:Print("Spammer attivato.")
end

function GM:StopSpam()
    self.spamActive = false
    if self.spamBtn then self.spamBtn:SetText("Start Spam") end
    if self.spamFrame then
        self.spamFrame:SetScript("OnUpdate", nil)
        self.spamFrame:Hide()
    end
    RLSuite.utils:Print("Spammer fermato.")
end

function GM:DoSpam()
    local msg = self:BuildSpamMessage()
    self.lastSpamMsg = msg
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        RLSuite.utils:SendChat(msg, "LFM")
        return
    end
    local channels = self.db.spamChannels or {"General", "Trade"}
    for _, ch in ipairs(channels) do
        local chNum = GetChannelName(ch)
        if chNum and chNum > 0 then
            SendChatMessage(msg, "CHANNEL", nil, chNum)
        end
    end
end

-- ============================================================
-- WHISPER
-- ============================================================
function GM:OnWhisper(sender, msg)
    if not self.spamActive then return end
    local me = UnitName("player")
    if sender == me then
        if self.lastSpamMsg and (msg == self.lastSpamMsg or string.find(msg, self.lastSpamMsg, 1, true)) then
            return
        end
        if string.find(msg or "", "^%[") then
            return
        end
    end
    local entry = {
        name = sender,
        rawMsg = msg,
        class = self:ExtractClassFromWhisper(msg),
        role = self:ExtractRoleFromWhisper(msg),
        spec = self:ExtractSpecFromWhisper(msg),
        gs = self:ExtractGSFromWhisper(msg),
        time = time(),
        invited = false,
    }
    table.insert(self.whisperDB.entries, 1, entry)
    self:UpdateWhisplist()
    RLSuite.utils:Print("Whisper da " .. sender .. " ricevuto.")
end

function GM:ExtractClassFromWhisper(msg)
    local lower = string.lower(msg or "")
    local classMap = {
        warrior = "WARRIOR", paladin = "PALADIN", hunter = "HUNTER",
        rogue = "ROGUE", priest = "PRIEST", dk = "DEATHKNIGHT",
        deathknight = "DEATHKNIGHT", shaman = "SHAMAN", mage = "MAGE",
        warlock = "WARLOCK", druid = "DRUID",
    }
    for key, class in pairs(classMap) do
        if string.find(lower, key) then return class end
    end
    return nil
end

function GM:ExtractRoleFromWhisper(msg)
    local lower = string.lower(msg or "")
    if string.find(lower, "tank") then return "tank" end
    if string.find(lower, "heal") then return "healer" end
    return "dps"
end

function GM:ExtractSpecFromWhisper(msg)
    local spec = string.match(msg or "", "[Ss]pec[:%-]?%s*(%a+)")
    return spec
end

function GM:ExtractGSFromWhisper(msg)
    local gs = string.match(msg or "", "(%d%d%d?%d?)%s*[Gg][Ss]")
    return gs and tonumber(gs) or nil
end

-- ============================================================
-- WHISPLIST WINDOW
-- ============================================================
function GM:CreateWhisplistWindow()
    local f = CreateFrame("Frame", "RLSuiteWhisplist", UIParent)
    f:SetSize(500, 450)
    f:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    self.whisplistFrame = f
    RLSuite.utils:SkinFrame(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -10)
    title:SetText("Whisplist")

    self.wlCompBox = CreateFrame("Frame", nil, f)
    self.wlCompBox:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -36)
    self.wlCompBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -36)
    self.wlCompBox:SetHeight(52)
    RLSuite.utils:SkinBox(self.wlCompBox)

    local compLabel = self.wlCompBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    compLabel:SetPoint("TOPLEFT", self.wlCompBox, "TOPLEFT", 8, -6)
    compLabel:SetText("Comp")
    compLabel:SetTextColor(1, 0.82, 0)

    self.wlCompFrame = CreateFrame("Frame", nil, self.wlCompBox)
    self.wlCompFrame:SetPoint("TOPLEFT", self.wlCompBox, "TOPLEFT", 8, -22)
    self:BuildWLCompSlots()

    self.wlListBox = CreateFrame("Frame", nil, f)
    self.wlListBox:SetPoint("TOPLEFT", self.wlCompBox, "BOTTOMLEFT", 0, -8)
    self.wlListBox:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 16)
    RLSuite.utils:SkinBox(self.wlListBox)

    local listLabel = self.wlListBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listLabel:SetPoint("TOPLEFT", self.wlListBox, "TOPLEFT", 8, -6)
    listLabel:SetText("Whispers ricevuti")
    listLabel:SetTextColor(1, 0.82, 0)

    self.wlScroll = CreateFrame("ScrollFrame", "RLSuiteWLScroll", self.wlListBox, "UIPanelScrollFrameTemplate")
    self.wlScroll:SetPoint("TOPLEFT", self.wlListBox, "TOPLEFT", 6, -24)
    self.wlScroll:SetPoint("BOTTOMRIGHT", self.wlListBox, "BOTTOMRIGHT", -26, 6)

    self.wlContent = CreateFrame("Frame", nil, self.wlScroll)
    self.wlContent:SetWidth(200)
    self.wlContent:SetHeight(1)
    self.wlScroll:SetScrollChild(self.wlContent)
    self.wlScroll:SetScript("OnSizeChanged", function(s, w, h)
        if GM.wlContent and w and w > 40 then
            GM.wlContent:SetWidth(w)
        end
    end)

    self.wlDetailBox = CreateFrame("Frame", nil, f)
    self.wlDetailBox:SetPoint("TOPRIGHT", self.wlCompBox, "BOTTOMRIGHT", 0, -8)
    self.wlDetailBox:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 16)
    RLSuite.utils:SkinBox(self.wlDetailBox)
    self.wlDetailPanel = self.wlDetailBox

    self.wlDetailName = self.wlDetailBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.wlDetailName:SetPoint("TOPLEFT", self.wlDetailBox, "TOPLEFT", 10, -10)
    self.wlDetailName:SetPoint("TOPRIGHT", self.wlDetailBox, "TOPRIGHT", -10, -10)
    self.wlDetailName:SetJustifyH("LEFT")
    self.wlDetailName:SetText("Seleziona un giocatore")
    self.wlDetailName:SetTextColor(1, 0.82, 0)

    self.wlDetailInfo = self.wlDetailBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.wlDetailInfo:SetPoint("TOPLEFT", self.wlDetailName, "BOTTOMLEFT", 0, -6)
    self.wlDetailInfo:SetPoint("RIGHT", self.wlDetailBox, "RIGHT", -10, 0)
    self.wlDetailInfo:SetJustifyH("LEFT")
    self.wlDetailInfo:SetText("")

    self.wlChat = CreateFrame("Frame", nil, self.wlDetailBox)
    self.wlChat:SetPoint("TOPLEFT", self.wlDetailInfo, "BOTTOMLEFT", 0, -8)
    self.wlChat:SetPoint("RIGHT", self.wlDetailBox, "RIGHT", -10, 0)
    self.wlChat:SetHeight(90)
    RLSuite.utils:SkinBox(self.wlChat)

    self.wlChatText = self.wlChat:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.wlChatText:SetPoint("TOPLEFT", self.wlChat, "TOPLEFT", 6, -6)
    self.wlChatText:SetPoint("BOTTOMRIGHT", self.wlChat, "BOTTOMRIGHT", -6, 6)
    self.wlChatText:SetJustifyH("LEFT")
    self.wlChatText:SetJustifyV("TOP")
    self.wlChatText:SetText("")

    self.wlInviteBtn = CreateFrame("Button", nil, self.wlDetailBox, "UIPanelButtonTemplate")
    self.wlInviteBtn:SetSize(80, 22)
    self.wlInviteBtn:SetPoint("BOTTOMLEFT", self.wlDetailBox, "BOTTOMLEFT", 10, 36)
    self.wlInviteBtn:SetText("Invite")
    self.wlInviteBtn:SetScript("OnClick", function() self:InviteSelected() end)

    self.wlAskGusBtn = CreateFrame("Button", nil, self.wlDetailBox, "UIPanelButtonTemplate")
    self.wlAskGusBtn:SetSize(80, 22)
    self.wlAskGusBtn:SetPoint("LEFT", self.wlInviteBtn, "RIGHT", 6, 0)
    self.wlAskGusBtn:SetText("Ask GS")
    self.wlAskGusBtn:SetScript("OnClick", function() self:AskGS() end)

    self.wlAskAchiBtn = CreateFrame("Button", nil, self.wlDetailBox, "UIPanelButtonTemplate")
    self.wlAskAchiBtn:SetSize(80, 22)
    self.wlAskAchiBtn:SetPoint("LEFT", self.wlAskGusBtn, "RIGHT", 6, 0)
    self.wlAskAchiBtn:SetText("Ask Achi")
    self.wlAskAchiBtn:SetScript("OnClick", function() self:AskAchi() end)

    local customLabel = self.wlDetailBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    customLabel:SetPoint("BOTTOMLEFT", self.wlDetailBox, "BOTTOMLEFT", 10, 16)
    customLabel:SetText("Custom msg")
    customLabel:SetTextColor(1, 0.82, 0)

    self.wlCustomMsg = CreateFrame("EditBox", "RLSuiteWLCustomMsg", self.wlDetailBox, "InputBoxTemplate")
    self.wlCustomMsg:SetHeight(20)
    self.wlCustomMsg:SetPoint("LEFT", customLabel, "RIGHT", 8, 0)
    self.wlCustomMsg:SetPoint("RIGHT", self.wlDetailBox, "RIGHT", -12, 0)
    self.wlCustomMsg:SetAutoFocus(false)
    self.wlCustomMsg:SetScript("OnEnterPressed", function()
        self:SendCustomMessage()
    end)

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)
end

function GM:BuildWLCompSlots()
    self.wlCompSlots = {}
    local numSlots = tonumber(self.db.difficulty or "10")
    for i = 1, numSlots do
        local slot = CreateFrame("Button", nil, self.wlCompFrame)
        slot:SetSize(20, 20)
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        slot:SetPoint("TOPLEFT", self.wlCompFrame, "TOPLEFT", col * 24, -row * 24)
        slot:SetBackdrop({
            bgFile = "Interface\Buttons\UI-Quickslot",
            tile = false, tileSize = 20, edgeSize = 20,
        })
        slot.index = i
        slot:SetScript("OnClick", function(s)
            if self.selectedEntry then
                self:InvitePlayerToSlot(self.selectedEntry, s.index)
            end
        end)
        self.wlCompSlots[i] = slot
    end
    self.wlCompFrame:SetSize(5 * 24, math.ceil(numSlots / 5) * 24)
end

function GM:ToggleWhisplist()
    if RLSuite.mainWindow and RLSuite.mainWindow.ShowTab then
        RLSuite.mainWindow:ShowTab("whisplist")
        return
    end
    if self.whisplistFrame and self.whisplistFrame:IsShown() then
        self.whisplistFrame:Hide()
    elseif self.whisplistFrame then
        self.whisplistFrame:Show()
        self:UpdateWhisplist()
    end
end

function GM:SkinInner()
    local u = RLSuite.utils
    u:SkinBox(self.compBox)
    u:SkinBox(self.classBox)
    u:SkinBox(self.reqBox)
    u:SkinBox(self.previewBox)
    u:SkinBox(self.wlCompBox)
    u:SkinBox(self.wlListBox)
    u:SkinBox(self.wlDetailBox)
    u:SkinBox(self.wlChat)
end

function GM:UpdateWhisplist()
    if not self.wlContent then return end
    if self.SkinInner then self:SkinInner() end
    for _, child in ipairs({self.wlContent:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    if self.wlScroll then
        local w = self.wlScroll:GetWidth()
        if w and w > 40 then self.wlContent:SetWidth(w) end
    end

    local entries = self.whisperDB.entries or {}
    local y = 0
    for i, entry in ipairs(entries) do
        local row = CreateFrame("Button", nil, self.wlContent)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", self.wlContent, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", self.wlContent, "TOPRIGHT", 0, -y)
        RLSuite.utils:SkinRow(row, self.selectedEntryIndex == i)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", row, "LEFT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        text:SetJustifyH("LEFT")
        local info = entry.name or "Unknown"
        if entry.class then
            info = info .. " (" .. string.sub(entry.class, 1, 1) .. string.lower(string.sub(entry.class, 2)) .. ")"
        end
        if entry.gs then info = info .. " GS:" .. entry.gs end
        text:SetText(info)
        if entry.invited then
            text:SetTextColor(0.5, 0.5, 0.5)
        else
            text:SetTextColor(1, 1, 1)
        end

        row:SetScript("OnClick", function()
            self:SelectWhisperEntry(i)
            self:UpdateWhisplist()
        end)

        y = y + 26
    end
    self.wlContent:SetHeight(math.max(y, 1))
end

function GM:SelectWhisperEntry(index)
    local entries = self.whisperDB.entries or {}
    local entry = entries[index]
    if not entry then return end
    self.selectedEntry = entry
    self.selectedEntryIndex = index

    if self.wlDetailName then self.wlDetailName:SetText(entry.name or "Unknown") end
    local info = ""
    if entry.class then info = info .. "Class: " .. entry.class .. "\n" end
    if entry.role then info = info .. "Role: " .. entry.role .. "\n" end
    if entry.spec then info = info .. "Spec: " .. entry.spec .. "\n" end
    if entry.gs then info = info .. "GS: " .. entry.gs .. "\n" end
    if self.wlDetailInfo then self.wlDetailInfo:SetText(info) end
    if self.wlChatText then self.wlChatText:SetText("Whisper: " .. (entry.rawMsg or "")) end
end

function GM:InviteSelected()
    if not self.selectedEntry then return end
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        RLSuite.utils:Print("[DBG] Invite " .. (self.selectedEntry.name or "?"))
        RLSuite.utils:Whisper(self.selectedEntry.name, "You are invited (debug).")
        return
    end
    InviteUnit(self.selectedEntry.name)
end

function GM:AskGS()
    if not self.selectedEntry then return end
    RLSuite.utils:Whisper(self.selectedEntry.name, "What's your GS?")
end

function GM:AskAchi()
    if not self.selectedEntry then return end
    RLSuite.utils:Whisper(self.selectedEntry.name, "Do you have the achievement for this raid?")
end

function GM:SendCustomMessage()
    if not self.selectedEntry then return end
    local msg = self.wlCustomMsg and self.wlCustomMsg:GetText() or ""
    if msg ~= "" then
        RLSuite.utils:Whisper(self.selectedEntry.name, msg)
        self.wlCustomMsg:SetText("")
    end
end

function GM:InvitePlayerToSlot(entry, slotIndex)
    if not entry or not slotIndex then return end
    local slot = self.compSlots[slotIndex]
    if not slot or slot.playerName then
        RLSuite.utils:Print("Slot già occupato!")
        return
    end
    local class = entry.class or slot.class
    if not class then
        RLSuite.utils:Print("Classe non riconosciuta per " .. (entry.name or "?"))
        return
    end
    local spec = entry.spec or slot.spec
    local role = RLSuite.utils:RoleFromSpec(class, spec) or entry.role or slot.role or "dps"
    self:FillSlot(slotIndex, class, role, entry.name, spec)
    entry.invited = true
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        RLSuite.utils:Print("[DBG] Invite " .. (entry.name or "?") .. " slot " .. slotIndex)
    else
        InviteUnit(entry.name)
    end
    self:UpdateWhisplist()
    self:UpdateMessagePreview()
    RLSuite.utils:Print((entry.name or "?") .. " invitato nello slot " .. slotIndex)
end

-- ============================================================
-- SAVE / LOAD
-- ============================================================
function GM:LoadCompFromDB()
    local reserved = ""
    if type(self.db.reservedText) == "string" then
        reserved = self.db.reservedText
    elseif type(self.db.reserved) == "string" then
        reserved = self.db.reserved
    end
    if self.reservedEdit then self.reservedEdit:SetText(reserved) end
    if self.otherEdit then self.otherEdit:SetText(self.db.otherReq or "") end
    if self.db.comp then
        for i, data in pairs(self.db.comp) do
            if self.compSlots[i] then
                self:FillSlot(i, data.class, data.role, data.playerName, data.spec)
            end
        end
    end
    self:UpdateMessagePreview()
end

function GM:SaveComp()
    if self.loadingComp then return end
    if not self.db then return end
    self.db.comp = {}
    for i, slot in ipairs(self.compSlots or {}) do
        if slot and slot.filled then
            self.db.comp[i] = {
                class = slot.class,
                role = slot.role,
                spec = slot.spec,
                playerName = slot.playerName,
            }
        end
    end
    if self.reservedEdit then
        self.db.reservedText = self.reservedEdit:GetText() or ""
    end
    if self.otherEdit then
        self.db.otherReq = self.otherEdit:GetText() or ""
    end
end

local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function()
    if RLSuite.groupmaking and RLSuite.groupmaking.SaveComp then
        RLSuite.groupmaking:SaveComp()
    end
end)
