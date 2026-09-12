-- ============================================================
-- RLSuite - GroupMaking Module
-- ============================================================

RLSuite.groupmaking = {}
local GM = RLSuite.groupmaking

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

local SLOT_SIZE = 36
local SLOT_SPACING = 2
local GROUP_LABEL_H = 17

-- Raid Group panel (InviteEngine rib): the REAL raid, one vertical column
-- per raid group, each holding up to 5 class-colored name bars.
local WL_BAR_H = 16
local WL_BAR_GAP = 2
local WL_COL_GAP = 4
local WL_GROUP_LABEL_H = 14

-- Extra vertical room the InviteEngine rib needs for the tabbed panel
-- below the fixed Raid Group box (AceGUI-3.0 TabGroup: tab strip + border).
-- The rib keeps following Groupmaking's minimum resize height.
local IE_TAB_EXTRA = 53

-- All Groupmaking window fonts are +2pt over the default game fonts
-- (window titles keep their large size).
local FONT_FILE = "Fonts\\FRIZQT__.TTF"
local function FontStr(parent, layer, size)
    local fs = parent:CreateFontString(nil, layer, nil)
    fs:SetFont(FONT_FILE, size, "OUTLINE")
    return fs
end

local ROLE_COLORS = {
    tank   = {r=0.2, g=0.4, b=1.0},
    healer = {r=0.2, g=1.0, b=0.2},
    mdps   = {r=1.0, g=0.45, b=0.15},
    rdps   = {r=1.0, g=0.2, b=0.2},
    dps    = {r=1.0, g=0.2, b=0.2},
}

-- Icone di ruolo di default WotLK (LFG frame, quadranti tank/healer/dps).
local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_ICON_COORDS = {
    tank   = { 0,       0.296875, 0.34375, 0.640625 },
    healer = { 0.3125,  0.609375, 0.015625, 0.3125 },
    dps    = { 0.3125,  0.609375, 0.34375, 0.640625 },
}
ROLE_ICON_COORDS.mdps = ROLE_ICON_COORDS.dps
ROLE_ICON_COORDS.rdps = ROLE_ICON_COORDS.dps

local function RoleIconCoords(role)
    role = role or "dps"
    return ROLE_ICON_COORDS[role] or ROLE_ICON_COORDS.dps
end

function GM:Init()
    self.db = RLSuite.db.profile.groupmaking
    self.whisperDB = RLSuite.db.profile.whisplist
    -- Autoinviter: stato salvato + default per i campi mancanti. "enabled"
    -- torna sempre false al reload (i timer AceTimer non sopravvivono).
    RLSuite.db.profile.whisplist.autoinvite = RLSuite.db.profile.whisplist.autoinvite or {}
    self.autoinvite = RLSuite.db.profile.whisplist.autoinvite
    local ai = self.autoinvite
    ai.mode = ai.mode or "manual"
    -- La lista manuale ora e' un array di nomi (prima era una stringa
    -- multilinea). Migrazione: una vecchia stringa viene splittata.
    if type(ai.names) == "string" then
        local arr = {}
        for name in (ai.names or ""):gmatch("[^%s,;]+") do
            if name ~= "" and name ~= "-" then arr[#arr + 1] = name end
        end
        ai.names = arr
    end
    ai.names = ai.names or {}
    ai.hour = ai.hour or 19
    ai.minute = ai.minute or 0
    ai.enabled = false
    self.spamActive = false
    self.compSlots = {}
    self.whisperEntries = {}
    self.selectedEntry = nil
    self.loadingComp = true
    self:EmbedAceLibraries()
    self:RegisterModuleEvents()
    self:CreateMainWindow()
    self:CreateWhisplistWindow()
    self:LoadCompFromDB()
    self.loadingComp = false
end

-- Eventi del modulo via AceEvent-3.0 (prima erano due frame dedicati creati
-- al load del file: saveFrame per PLAYER_LOGOUT e rosterFrame per il roster).
function GM:RegisterModuleEvents()
    self:RegisterEvent("PLAYER_LOGOUT", function()
        self:SaveComp()
    end)
    self:RegisterEvent("RAID_ROSTER_UPDATE", function()
        self:UpdateWLGroups()
    end)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        self:UpdateWLGroups()
    end)
end

-- Incorpora le librerie Ace per le nuove funzioni (eventi del Calendario
-- via AceEvent-3.0, pianificazione degli inviti via AceTimer-3.0). Le
-- tab dell'InviteEngine usano invece il widget TabGroup di AceGUI-3.0.
function GM:EmbedAceLibraries()
    if not LibStub then return end
    local AceEvent = LibStub("AceEvent-3.0", true)
    local AceTimer = LibStub("AceTimer-3.0", true)

    if AceEvent and AceEvent.Embed and not self.RegisterEvent then
        AceEvent:Embed(self)
        -- Il Calendario puo' cambiare fuori dall'addon: aggiorna il dropdown.
        self:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST", function()
            self:OnCalendarChanged()
        end)
        self:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES", function()
            self:OnCalendarChanged()
        end)
        self:RegisterEvent("CALENDAR_NEW_EVENT", function()
            self:OnCalendarEventCreated()
        end)
        self:RegisterEvent("CALENDAR_UPDATE_EVENT", function()
            self:OnCalendarEventCreated()
        end)
        self:RegisterEvent("CALENDAR_CLOSE_EVENT", function()
            self:OnCalendarChanged()
        end)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            self:OnCalendarChanged()
        end)
    end
    if AceTimer and AceTimer.Embed and not self.ScheduleTimer then
        AceTimer:Embed(self)
    end
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
    f:SetSize(560, 600)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    f:Hide()
    self.mainFrame = f
    RLSuite.utils:SkinFrame(f)
    RLSuite.utils:ClampWindow(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -10)
    title:SetText("Group Making")

    local raidLabel = FontStr(f, "OVERLAY", 14)
    raidLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -36)
    raidLabel:SetText("Raid:")

    self.raidDropdown = RLSuite.utils:CreateDropdown(f, "RLSuiteRaidDropdown", 180, 22)
    self.raidDropdown:SetPoint("LEFT", raidLabel, "RIGHT", 8, 0)
    -- Backdrop pieno e ben visibile (non trasparente): colore solido piu'
    -- chiaro del riempimento della finestra, con bordo netto.
    self.raidDropdown:SetBackdropColor(0.13, 0.13, 0.17, 1)
    self.raidDropdown:SetBackdropBorderColor(0.55, 0.55, 0.58, 1)
    self:PopulateRaidDropdown()

    local diffLabel = FontStr(f, "OVERLAY", 14)
    diffLabel:SetPoint("LEFT", self.raidDropdown, "RIGHT", 12, 0)
    diffLabel:SetText("Diff:")

    -- Due tasti al posto del dropdown: il tasto attivo resta evidenziato.
    self.diffBtn10 = CreateFrame("Button", "RLSuiteDiffBtn10", f, "UIPanelButtonTemplate")
    self.diffBtn10:SetSize(30, 22)
    self.diffBtn10:SetPoint("LEFT", diffLabel, "RIGHT", 8, 0)
    self.diffBtn10:SetText("10")
    self.diffBtn10:SetScript("OnClick", function() self:SetDifficulty("10") end)

    self.diffBtn25 = CreateFrame("Button", "RLSuiteDiffBtn25", f, "UIPanelButtonTemplate")
    self.diffBtn25:SetSize(30, 22)
    self.diffBtn25:SetPoint("LEFT", self.diffBtn10, "RIGHT", 4, 0)
    self.diffBtn25:SetText("25")
    self.diffBtn25:SetScript("OnClick", function() self:SetDifficulty("25") end)

    self:UpdateDiffButtons()

    -- Checkbox HC: aggiunge "HC" al messaggio subito dopo la difficolta'.
    self.hcCheck = CreateFrame("CheckButton", "RLSuiteHCCheck", f, "UICheckButtonTemplate")
    self.hcCheck:SetSize(24, 24)
    self.hcCheck:SetPoint("LEFT", self.diffBtn25, "RIGHT", 10, 0)
    self.hcCheck:SetChecked(self.db.hc and true or false)
    self.hcCheck:SetScript("OnClick", function(s)
        self.db.hc = s:GetChecked() and true or false
        self:UpdateMessagePreview()
        self:SaveComp()
    end)

    local hcLbl = FontStr(f, "OVERLAY", 12)
    hcLbl:SetPoint("LEFT", self.hcCheck, "RIGHT", 0, 0)
    hcLbl:SetText("HC")
    hcLbl:SetTextColor(1, 0.82, 0)

    self.topRow = CreateFrame("Frame", nil, f)
    self.topRow:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -66)
    self.topRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -66)
    self.topRow:SetHeight(200)

    self.compBox = CreateFrame("Frame", nil, self.topRow)
    self.compBox:SetPoint("TOPLEFT", self.topRow, "TOPLEFT", 0, 0)
    self.compBox:SetPoint("BOTTOMLEFT", self.topRow, "BOTTOMLEFT", 0, 0)
    self.compBox:SetWidth(204)
    RLSuite.utils:SkinBox(self.compBox)

    local compLabel = FontStr(self.compBox, "OVERLAY", 14)
    compLabel:SetPoint("TOPLEFT", self.compBox, "TOPLEFT", 8, -6)
    compLabel:SetText(L["Composition"])
    compLabel:SetTextColor(1, 0.82, 0)

    self.compFrame = CreateFrame("Frame", nil, self.compBox)
    self.compFrame:SetPoint("TOPLEFT", self.compBox, "TOPLEFT", 8, -24)
    self.compFrame:SetSize((SLOT_SIZE + SLOT_SPACING) * 5 - SLOT_SPACING, (SLOT_SIZE + SLOT_SPACING) * 2 - SLOT_SPACING)

    self.classBox = CreateFrame("Frame", nil, self.topRow)
    self.classBox:SetPoint("TOPRIGHT", self.topRow, "TOPRIGHT", 0, 0)
    self.classBox:SetPoint("BOTTOMRIGHT", self.topRow, "BOTTOMRIGHT", 0, 0)
    self.classBox:SetWidth(200)
    RLSuite.utils:SkinBox(self.classBox)

    local classBarLabel = FontStr(self.classBox, "OVERLAY", 14)
    classBarLabel:SetPoint("TOPLEFT", self.classBox, "TOPLEFT", 8, -6)
    classBarLabel:SetText(L["Click a spec to add"])
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
    self.reqBox:SetHeight(150)
    RLSuite.utils:SkinBox(self.reqBox)

    -- Campo "Aim": nota libera del raid leader, sopra a Reserved items.
    local aimLabel = FontStr(self.reqBox, "OVERLAY", 12)
    aimLabel:SetPoint("TOPLEFT", self.reqBox, "TOPLEFT", 8, -8)
    aimLabel:SetText(L["Aim"])
    aimLabel:SetTextColor(1, 0.82, 0)

    self.aimEdit = CreateFrame("EditBox", "RLSuiteAimEdit", self.reqBox, "InputBoxTemplate")
    self.aimEdit:SetHeight(20)
    self.aimEdit:SetPoint("TOPLEFT", aimLabel, "BOTTOMLEFT", 4, -4)
    self.aimEdit:SetPoint("RIGHT", self.reqBox, "RIGHT", -12, 0)
    self.aimEdit:SetAutoFocus(false)
    self.aimEdit:SetMaxLetters(250)
    self.aimEdit:SetScript("OnTextChanged", function() self:SaveComp() end)
    self.aimEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    self.aimEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)

    local reservedLabel = FontStr(self.reqBox, "OVERLAY", 12)
    reservedLabel:SetPoint("TOPLEFT", self.aimEdit, "BOTTOMLEFT", -4, -6)
    reservedLabel:SetText(L["Reserved items"])
    reservedLabel:SetTextColor(1, 0.82, 0)

    self.reservedEdit = CreateFrame("EditBox", "RLSuiteReservedEdit", self.reqBox, "InputBoxTemplate")
    self.reservedEdit:SetHeight(20)
    self.reservedEdit:SetPoint("TOPLEFT", reservedLabel, "BOTTOMLEFT", 4, -4)
    self.reservedEdit:SetAutoFocus(false)
    self.reservedEdit:SetMaxLetters(250)
    self.reservedEdit:SetScript("OnTextChanged", function() self:SaveComp() end)
    self.reservedEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    self.reservedEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    RLSuite.utils:RegisterInsertLink(self.reservedEdit, function()
        GM:SaveComp()
        GM:UpdateMessagePreview()
    end)

    self.atlasBtn = CreateFrame("Button", nil, self.reqBox, "UIPanelButtonTemplate")
    self.atlasBtn:SetSize(80, 20)
    self.atlasBtn:SetPoint("RIGHT", self.reqBox, "RIGHT", -10, 0)
    self.atlasBtn:SetPoint("TOP", self.reservedEdit, "TOP", 0, 0)
    self.atlasBtn:SetText("AtlasLoot")
    self.atlasBtn:SetScript("OnClick", function() self:OpenAtlasLoot() end)
    -- Il bordo destro di "Pezzi riservati" si ferma a sinistra del tasto AtlasLoot
    -- (margine 10 + larghezza tasto 80 + spazio 6), senza creare dipendenze circolari.
    self.reservedEdit:SetPoint("RIGHT", self.reqBox, "RIGHT", -96, 0)

    local otherLabel = FontStr(self.reqBox, "OVERLAY", 12)
    otherLabel:SetPoint("TOPLEFT", self.reservedEdit, "BOTTOMLEFT", -4, -6)
    otherLabel:SetText(L["Other requirements"])
    otherLabel:SetTextColor(1, 0.82, 0)

    self.otherEdit = CreateFrame("EditBox", "RLSuiteOtherEdit", self.reqBox, "InputBoxTemplate")
    self.otherEdit:SetHeight(20)
    self.otherEdit:SetPoint("TOPLEFT", otherLabel, "BOTTOMLEFT", 4, -4)
    self.otherEdit:SetPoint("RIGHT", self.reqBox, "RIGHT", -12, 0)
    self.otherEdit:SetAutoFocus(false)
    self.otherEdit:SetMaxLetters(250)
    self.otherEdit:SetScript("OnTextChanged", function() self:SaveComp() end)
    self.otherEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    self.otherEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    RLSuite.utils:RegisterInsertLink(self.otherEdit, function()
        GM:SaveComp()
        GM:UpdateMessagePreview()
    end)

    self.previewBox = CreateFrame("Frame", nil, f)
    self.previewBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
    self.previewBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
    self.previewBox:SetHeight(58)
    RLSuite.utils:SkinBox(self.previewBox)

    self.previewText = FontStr(self.previewBox, "OVERLAY", 12)
    self.previewText:SetPoint("TOPLEFT", self.previewBox, "TOPLEFT", 8, -8)
    self.previewText:SetPoint("BOTTOMRIGHT", self.previewBox, "BOTTOMRIGHT", -8, 8)
    self.previewText:SetJustifyH("LEFT")
    self.previewText:SetJustifyV("TOP")
    self.previewText:SetText(L["Message preview..."])

    self.spamBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.spamBtn:SetSize(100, 24)
    self.spamBtn:SetPoint("BOTTOMLEFT", self.previewBox, "TOPLEFT", 0, 8)
    self.spamBtn:SetText("Start Spam")
    self.spamBtn:SetScript("OnClick", function() self:ToggleSpam() end)

    self.previewBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.previewBtn:SetSize(100, 24)
    self.previewBtn:SetPoint("LEFT", self.spamBtn, "RIGHT", 8, 0)
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

    local specsLbl = FontStr(f, "OVERLAY", 12)
    specsLbl:SetPoint("LEFT", self.showSpecsCheck, "RIGHT", 0, 0)
    specsLbl:SetText("Show specs in message")
    specsLbl:SetTextColor(1, 0.82, 0)

    -- InviteEngine (ex-Whisplist): il bottone sta a DESTRA della checkbox
    -- "Show specs in message", come richiesto.
    self.whisplistBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    self.whisplistBtn:SetSize(100, 24)
    self.whisplistBtn:SetPoint("LEFT", specsLbl, "RIGHT", 10, 0)
    self.whisplistBtn:SetText("InviteEngine")
    self.whisplistBtn:SetScript("OnClick", function() self:ToggleWhisplist() end)

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
function GM:GroupRowHeight()
    return GROUP_LABEL_H + SLOT_SIZE + SLOT_SPACING
end

function GM:BuildCompSlots()
    local maxSlots = 25
    self.compSlots = {}
    self.groupLabels = {}
    for g = 1, 5 do
        local fs = FontStr(self.compFrame, "OVERLAY", 12)
        fs:SetPoint("TOPLEFT", self.compFrame, "TOPLEFT", 0, -((g - 1) * self:GroupRowHeight()))
        fs:SetText("Group " .. g)
        fs:SetTextColor(1, 0.82, 0)
        self.groupLabels[g] = fs
    end
    for i = 1, maxSlots do
        local slot = CreateFrame("Button", "RLSuiteCompSlot"..i, self.compFrame)
        slot:SetSize(SLOT_SIZE, SLOT_SIZE)
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        local y = -(row * self:GroupRowHeight() + GROUP_LABEL_H)
        slot:SetPoint("TOPLEFT", self.compFrame, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), y)
        -- Slot background + thin border (the class color is applied to the
        -- border on fill). No oversized overlay texture: it used to cover the
        -- spec icon and poke into the "Group N" labels.
        slot:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-Quickslot",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 32, edgeSize = 8,
            insets = {left=2, right=2, top=2, bottom=2}
        })
        slot:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
        slot:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        slot:Show()
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        slot:SetScript("OnClick", function(s, button)
            if button == "RightButton" then
                self:ClearSlot(i)
            end
        end)

        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 3, -3)
        slot.icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -3, 3)
        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.icon:Hide()

        -- Semi-transparent backing so the role glyph stays readable on bright
        -- spec icons. It lives on ARTWORK (above the spec icon, below the
        -- OVERLAY glyph) so it can never cover the role icon.
        slot.roleIconBg = slot:CreateTexture(nil, "ARTWORK")
        slot.roleIconBg:SetSize(20, 20)
        slot.roleIconBg:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -1, -1)
        slot.roleIconBg:SetTexture(0, 0, 0, 0.6)
        slot.roleIconBg:Hide()

        slot.roleIcon = slot:CreateTexture(nil, "OVERLAY")
        slot.roleIcon:SetSize(18, 18)
        slot.roleIcon:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -2, -2)
        slot.roleIcon:SetTexture(ROLE_ICON_TEXTURE)
        slot.roleIcon:Hide()

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
    self:UpdateDiffButtons()
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
    for g, fs in ipairs(self.groupLabels or {}) do
        if g <= rows then fs:Show() else fs:Hide() end
    end
    local newHeight = rows * self:GroupRowHeight() - SLOT_SPACING
    self.compFrame:SetSize((SLOT_SIZE + SLOT_SPACING) * 5 - SLOT_SPACING, newHeight)
    self:LayoutGroupPanels()
    self:UpdateWLGroups()
    self:UpdateMessagePreview()
    self:SaveComp()
    -- la composizione 25 occupa piu' spazio: riallinea la finestra
    if self.mainFrame then
        RLSuite.utils:EnforceWindowMin(self.mainFrame, "groupmaking")
    end
end

-- Evidenzia il tasto di difficolta' attivo (10 o 25).
function GM:UpdateDiffButtons()
    local d = self.db.difficulty or "10"
    if self.diffBtn10 then
        if d == "10" then self.diffBtn10:LockHighlight() else self.diffBtn10:UnlockHighlight() end
    end
    if self.diffBtn25 then
        if d == "25" then self.diffBtn25:LockHighlight() else self.diffBtn25:UnlockHighlight() end
    end
end

function GM:LayoutGroupPanels(rowW)
    if not self.topRow then return end
    if self._layoutLock then return end
    self._layoutLock = true
    local w = rowW or self.topRow:GetWidth() or 400
    local COMP_W = 204
    local GAP = 8
    if self.compBox then self.compBox:SetWidth(COMP_W) end
    if self.classBox then
        local classW = w - COMP_W - GAP
        if classW < 160 then classW = 160 end
        self.classBox:SetWidth(classW)
    end

    local numSlots = tonumber(self.db and self.db.difficulty or "10") or 10
    local slotRows = math.ceil(numSlots / 5)
    local rowH = GROUP_LABEL_H + SLOT_SIZE + SLOT_SPACING
    local compH = slotRows * rowH - SLOT_SPACING + 36
    self:LayoutClassBar()
    local specH = (self._specBarHeight or 120) + 36
    local h = math.max(compH, specH, 140)
    self.topRow:SetHeight(h)
    if self.classBar then
        self.classBar:SetHeight(math.max(40, h - 32))
    end
    self._layoutLock = false
    self:SyncWhisplistHeight()
end

-- Altezza minima di resize di Groupmaking: topRow (dipende da 10/25) piu'
-- la pila fissa di title+dropdown, box richieste e blocco anteprima+bottoni.
-- IE_TAB_EXTRA copre la striscia a tab che l'InviteEngine aggiunge sotto
-- Raid Group: cosi' lista e dettaglio restano alti come prima.
function GM:MinHeight()
    local topH = 156
    if self.topRow then
        local th = self.topRow:GetHeight()
        if th and th > 60 then topH = th end
    end
    return topH + 336 + IE_TAB_EXTRA
end

-- L'InviteEngine e' una costola di Groupmaking: la sua altezza segue sempre
-- l'altezza minima di resize di Groupmaking.
function GM:SyncWhisplistHeight()
    if not self.whisplistFrame then return end
    self.whisplistFrame:SetHeight(self:MinHeight())
    self:LayoutInviteEngineTabs()
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
    slot:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    if slot.roleIconBg then slot.roleIconBg:Hide() end
    if slot.roleIcon then slot.roleIcon:Hide() end
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
    slot:SetBackdropBorderColor(r, g, b, 1)
    if slot.roleIconBg then slot.roleIconBg:Show() end
    if slot.roleIcon then
        local coords = RoleIconCoords(slot.role)
        slot.roleIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        slot.roleIcon:Show()
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
        local nameFS = FontStr(cell, "OVERLAY", 12)
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
                btn:EnableMouse(true)
                btn:RegisterForClicks("LeftButtonUp")
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
        RLSuite.utils:Print(string.format(L["No available slot for %s"], (spec or class or "?")))
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
local RAID_SHORT = {
    ["Icecrown Citadel"] = "ICC",
    ["Ruby Sanctum"] = "RS",
    ["Trial of the Crusader"] = "TOC",
    ["Ulduar"] = "ULD",
    ["Vault of Archavon"] = "VOA",
    ["The Eye of Eternity"] = "EOE",
    ["Eye of Eternity"] = "EOE",
    ["Naxxramas"] = "NAXX",
    ["Onyxia's Lair"] = "ONYXIA",
    ["The Obsidian Sanctum"] = "OS",
    ["Obsidian Sanctum"] = "OS",
}

function GM:RaidShortName(raid)
    raid = raid or (self.db and self.db.raid) or "Raid"
    return RAID_SHORT[raid] or raid
end

function GM:BuildSpamMessage()
    local diff = self.db.difficulty or "10"
    local msg = "LFM " .. self:RaidShortName() .. tostring(diff)
    if self.db.hc then
        msg = msg .. " HC"
    end

    -- "Lim" (campo Aim): nota libera inserita subito dopo la difficolta' e
    -- prima dei Need, come da richiesta.
    local aimText = self.aimEdit and self.aimEdit:GetText() or ""
    if aimText ~= "" then
        msg = msg .. " - " .. aimText
    end

    local needed = {tank = 0, healer = 0, mdps = 0, rdps = 0}
    local specLists = {tank = {}, healer = {}, mdps = {}, rdps = {}}
    local hasComp = false
    local numSlots = tonumber(diff) or 10
    for i = 1, numSlots do
        local slot = self.compSlots[i]
        if slot and slot.filled then
            hasComp = true
            if not slot.playerName then
                local role = RLSuite.utils:NormalizeRole(slot.role, slot.class, slot.spec)
                needed[role] = (needed[role] or 0) + 1
                if specLists[role] then
                    local specName = RLSuite.utils:SpecShortName(slot.class, slot.spec)
                    if specName and specName ~= "" then
                        table.insert(specLists[role], specName)
                    end
                end
            end
        end
    end

    local roleOrder = {
        {key = "tank", label = "TANK"},
        {key = "healer", label = "HEAL"},
        {key = "mdps", label = "MDPS"},
        {key = "rdps", label = "RDPS"},
    }
    local function fmtCount(n)
        if n > 5 then return "rest" end
        return tostring(n)
    end
    local roles = {}
    local showSpecs = self.db and self.db.showSpecsInMessage
    if showSpecs then
        for _, def in ipairs(roleOrder) do
            if needed[def.key] and needed[def.key] > 0 then
                table.insert(roles, def.label .. "(" .. table.concat(specLists[def.key], ", ") .. ")")
            end
        end
    else
        for _, def in ipairs(roleOrder) do
            if needed[def.key] and needed[def.key] > 0 then
                table.insert(roles, fmtCount(needed[def.key]) .. " " .. def.label)
            end
        end
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
        RLSuite.utils:Print(string.format(L["Message: %s"], (self.previewText:GetText() or "")))
    end
end

function GM:OpenAtlasLoot()
    if SlashCmdList and SlashCmdList["ATLASLOOT"] then
        SlashCmdList["ATLASLOOT"]("")
        return
    end
    if SlashCmdList and SlashCmdList["AL"] then
        SlashCmdList["AL"]("")
        return
    end
    if AtlasLootDefaultFrame then
        if AtlasLootDefaultFrame:IsShown() then
            AtlasLootDefaultFrame:Hide()
        else
            AtlasLootDefaultFrame:Show()
        end
        return
    end
    RLSuite.utils:Print(L["AtlasLoot is not loaded."])
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
    local interval = self.db.spamInterval or 60
    if self.spamTimer then self:CancelTimer(self.spamTimer) end
    self.spamTimer = self:ScheduleRepeatingTimer("DoSpam", interval)
    -- Debug mode: simuliamo 10 whisper fittizi per testare la Whisplist.
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        self:StartDebugWhispers()
    end
    RLSuite.utils:Print(L["Spammer started."])
end

function GM:StopSpam()
    self.spamActive = false
    if self.spamBtn then self.spamBtn:SetText("Start Spam") end
    if self.spamTimer then
        self:CancelTimer(self.spamTimer)
        self.spamTimer = nil
    end
    self:StopDebugWhispers()
    RLSuite.utils:Print(L["Spammer stopped."])
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
            SendChatMessage(RLSuite.utils:SanitizeChat(msg), "CHANNEL", nil, chNum)
        end
    end
end

-- ============================================================
-- DEBUG MODE: 10 fake whispers to exercise the Whisplist while the
-- spammer is running. Each one goes through GM:OnWhisper, so they land
-- in "Received whispers" exactly like real players.
-- ============================================================
local DEBUG_WHISPER_POOL = {
    { name = "Drakbot",   class = "WARRIOR",     role = "tank",   spec = "prot",  gs = 5900 },
    { name = "Holymoon",  class = "PALADIN",     role = "healer", spec = "holy",  gs = 6100 },
    { name = "Zapdora",   class = "MAGE",        role = "dps",    spec = "arcane", gs = 5700 },
    { name = "Stabbitha", class = "ROGUE",       role = "dps",    spec = "combat", gs = 5800 },
    { name = "Moowrath",  class = "DRUID",       role = "tank",   spec = "feral", gs = 6000 },
    { name = "Holylite",  class = "PRIEST",      role = "healer", spec = "holy",  gs = 5950 },
    { name = "Totemly",   class = "SHAMAN",      role = "healer", spec = "resto", gs = 5850 },
    { name = "Frostbite", class = "DEATHKNIGHT", role = "dps",    spec = "frost", gs = 6050 },
    { name = "Warlocky",  class = "WARLOCK",     role = "dps",    spec = "destro", gs = 5750 },
    { name = "Arrowz",    class = "HUNTER",      role = "dps",    spec = "marks", gs = 5900 },
}

function GM:StartDebugWhispers()
    self:StopDebugWhispers()
    self.debugWhisperIndex = 0
    self.debugWhisperTimer = self:ScheduleRepeatingTimer("DebugWhisperTick", 0.5)
end

function GM:StopDebugWhispers()
    if self.debugWhisperTimer and self.CancelTimer then
        self:CancelTimer(self.debugWhisperTimer)
    end
    self.debugWhisperTimer = nil
    self.debugWhisperIndex = nil
end

-- Emette il prossimo whisper fittizio e si ferma dopo il 10o.
function GM:DebugWhisperTick()
    if not (RLSuite.DebugMode and RLSuite:DebugMode()) then
        self:StopDebugWhispers()
        return
    end
    if not self.spamActive then
        self:StopDebugWhispers()
        return
    end
    self.debugWhisperIndex = (self.debugWhisperIndex or 0) + 1
    local fake = DEBUG_WHISPER_POOL[self.debugWhisperIndex]
    if not fake then
        self:StopDebugWhispers()
        return
    end
    local msg = string.lower(fake.class) .. " " .. fake.role .. " spec " .. fake.spec .. " " .. fake.gs .. " gs"
    self:OnWhisper(fake.name, msg)
    if self.debugWhisperIndex >= #DEBUG_WHISPER_POOL then
        self:StopDebugWhispers()
    end
end

-- ============================================================
-- WHISPER
-- ============================================================
local function FormatWhisperTime(t)
    if not t or not date then return "" end
    local ok, s = pcall(date, "%H:%M", t)
    if ok and type(s) == "string" and s ~= "" then return s end
    return ""
end

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

    -- Un solo ingresso per giocatore: i messaggi vengono accodati.
    local entries = self.whisperDB.entries
    local entry
    for i = #entries, 1, -1 do
        if entries[i].name == sender then
            entry = entries[i]
            table.remove(entries, i)
            break
        end
    end

    if not entry then
        entry = {
            name = sender,
            class = self:ExtractClassFromWhisper(msg),
            role = self:ExtractRoleFromWhisper(msg),
            spec = self:ExtractSpecFromWhisper(msg),
            gs = self:ExtractGSFromWhisper(msg),
            invited = false,
            messages = {},
        }
    else
        -- integra solo le info ancora mancanti
        local class = self:ExtractClassFromWhisper(msg)
        if class and not entry.class then entry.class = class end
        if not entry.role then entry.role = self:ExtractRoleFromWhisper(msg) end
        local spec = self:ExtractSpecFromWhisper(msg)
        if spec and not entry.spec then entry.spec = spec end
        local gs = self:ExtractGSFromWhisper(msg)
        if gs then entry.gs = gs end
        entry.messages = entry.messages or {}
        -- migra un eventuale dato vecchio (rawMsg singolo)
        if #entry.messages == 0 and entry.rawMsg then
            table.insert(entry.messages, { msg = entry.rawMsg, time = entry.time })
            entry.rawMsg = nil
        end
    end

    table.insert(entry.messages, { msg = msg, time = time() })
    table.insert(entries, 1, entry)

    if self.selectedEntry == entry then
        -- Il giocatore e' gia' aperto: il messaggio appare subito, in fondo,
        -- come nella chat di gioco.
        entry.unread = false
        self:RenderSelectedMessages()
    else
        -- Accento "nuovi whisp" sulla riga finche' non la si legge.
        entry.unread = true
    end

    self:UpdateWhisplist()
    RLSuite.utils:Print(string.format(L["Whisper from %s received."], sender))
end

-- Lista dei messaggi di un ingresso (gestisce anche il vecchio formato).
function GM:GetEntryMessages(entry)
    if entry and entry.messages and #entry.messages > 0 then
        return entry.messages
    elseif entry and entry.rawMsg then
        return { { msg = entry.rawMsg, time = entry.time } }
    end
    return {}
end

-- Cached class keywords: English plus the localized male/female class names
-- of the current client, so whispers like "guerriero" or "Krieger" are
-- recognized as well as "warrior".
function GM:ClassKeywords()
    if self._classKeywords then return self._classKeywords end
    local map = {
        WARRIOR     = { "warrior" },
        PALADIN     = { "paladin" },
        HUNTER      = { "hunter" },
        ROGUE       = { "rogue" },
        PRIEST      = { "priest" },
        DEATHKNIGHT = { "dk", "deathknight", "death knight" },
        SHAMAN      = { "shaman" },
        MAGE        = { "mage" },
        WARLOCK     = { "warlock" },
        DRUID       = { "druid" },
    }
    local function addLocalized(tblName)
        local tbl = _G[tblName]
        if type(tbl) ~= "table" then return end
        for class, words in pairs(map) do
            local name = tbl[class]
            if type(name) == "string" and name ~= "" then
                local lower = string.lower(name)
                local dup = false
                for _, w in ipairs(words) do
                    if w == lower then dup = true break end
                end
                if not dup then table.insert(words, lower) end
            end
        end
    end
    addLocalized("LOCALIZED_CLASS_NAMES_MALE")
    addLocalized("LOCALIZED_CLASS_NAMES_FEMALE")
    self._classKeywords = map
    return map
end

function GM:ExtractClassFromWhisper(msg)
    local lower = string.lower(msg or "")
    for class, words in pairs(self:ClassKeywords()) do
        for _, word in ipairs(words) do
            if string.find(lower, word, 1, true) then return class end
        end
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
    -- "spec fury", "spec: fury", "fury spec" ("spec" is universal WoW slang).
    local spec = string.match(msg or "", "[Ss]pec[:%-]?%s*(%a+)")
    if not spec then
        spec = string.match(msg or "", "(%a+)%s+[Ss]pec")
    end
    return spec
end

function GM:ExtractGSFromWhisper(msg)
    if not msg then return nil end
    -- "GS" is locale-neutral (GearScore). Accept both "5500 gs" and "gs 5500",
    -- with optional colon/dash separators.
    local gs = string.match(msg, "(%d%d%d%d%d?%d?)%s*[Gg][Ss]")
    if not gs then
        gs = string.match(msg, "[Gg][Ss]%s*[:%-]?%s*(%d%d%d%d%d?%d?)")
    end
    return gs and tonumber(gs) or nil
end

-- ============================================================
-- INVITEENGINE PANEL (rib anchored to the Groupmaking window)
-- Rebrand dell'ex "Whisplist": Raid Group fisso in alto e, sotto, un
-- vero sistema a tab (Whisplist + Autoinviter) basato su AceGUI-3.0.
-- ============================================================
function GM:CreateWhisplistWindow()
    -- Aperto a destra della finestra Groupmaking e ancorato ad essa: si
    -- sposta con lei e non e' trascinabile da solo.
    local f = CreateFrame("Frame", "RLSuiteInviteEngine", self.mainFrame)
    f:SetPoint("TOPLEFT", self.mainFrame, "TOPRIGHT", 6, 0)
    f:SetWidth(380)
    f:SetHeight(self:MinHeight())
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:Hide()
    self.whisplistFrame = f
    RLSuite.utils:SkinFrame(f)
    -- Costola ancorata a Groupmaking: resta comunque dentro lo schermo
    -- anche quando la finestra madre e' spinta contro il bordo destro.
    RLSuite.utils:ClampWindow(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -10)
    title:SetText(L["InviteEngine"])

    -- ==== Raid Group (fisso in alto): gruppi riempiti dal raid REALE ====
    self.wlGroupBox = CreateFrame("Frame", nil, f)
    self.wlGroupBox:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -34)
    self.wlGroupBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -34)
    RLSuite.utils:SkinBox(self.wlGroupBox)

    local groupLabel = FontStr(self.wlGroupBox, "OVERLAY", 12)
    groupLabel:SetPoint("TOPLEFT", self.wlGroupBox, "TOPLEFT", 8, -6)
    groupLabel:SetText(L["Raid Group"])
    groupLabel:SetTextColor(1, 0.82, 0)

    self:BuildWLGroupColumns()

    -- ==== Sistema a tab sotto Raid Group (AceGUI-3.0 TabGroup) ====
    self:CreateInviteEngineTabs()

    -- ==== Pagine delle tab ====
    self:BuildWhisplistPage()
    self:BuildAutoinviterPage()

    -- Tab predefinita: Whisplist.
    if self.ieTabGroup and self.ieTabGroup.SelectTab then
        self.ieTabGroup:SelectTab("whisper")
    else
        self:SetInviteEngineTab("whisper")
    end

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)
end

-- Crea la barra a tab con AceGUI-3.0 (widget TabGroup) e posiziona il suo
-- frame sotto il riquadro Raid Group, fino in fondo alla costola.
function GM:CreateInviteEngineTabs()
    local f = self.whisplistFrame
    if not f then return end

    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI or not AceGUI.Create then return end

    local tg = AceGUI:Create("TabGroup")
    if not tg then return end
    self.ieTabGroup = tg

    -- Disabilita l'altezza automatica del TabGroup. Senza figli AceGUI il
    -- widget si "collasserebbe" all'altezza minima (striscia tab + bordo)
    -- in LayoutFinished, sovrascrivendo la nostra SetHeight: le pagine
    -- Whisplist/Autoinviter sono frame normali, non figli AceGUI.
    if tg.SetAutoAdjustHeight then
        tg:SetAutoAdjustHeight(false)
    else
        tg.noAutoHeight = true
    end

    tg:SetTabs({
        { text = L["Whisplist"], value = "whisper" },
        { text = L["Autoinviter"], value = "auto" },
    })
    tg:SetCallback("OnGroupSelected", function(widget, event, value)
        self:SetInviteEngineTab(value)
    end)

    -- Il frame del widget vive dentro la costola, sotto Raid Group.
    tg.frame:SetParent(f)
    tg.frame:SetFrameStrata("HIGH")
    tg.frame:SetPoint("TOPLEFT", self.wlGroupBox, "BOTTOMLEFT", 0, -4)
    self:LayoutInviteEngineTabs()
end

-- Ridimensiona il TabGroup alla costola corrente e ricalcola l'area di
-- contenuto sotto le tab. Richiamato a ogni cambio di altezza/difficolta'.
function GM:LayoutInviteEngineTabs()
    local f = self.whisplistFrame
    local tg = self.ieTabGroup
    if not f or not tg then return end

    local w = (f:GetWidth() or 380) - 16
    if w < 200 then w = 200 end
    -- Altezza disponibile sotto il riquadro Raid Group (fisso in alto).
    local groupH = self.wlGroupBox and self.wlGroupBox:GetHeight() or 134
    local topOffset = 34 + (groupH or 0) + 4
    local h = (f:GetHeight() or 0) - topOffset - 8
    if h < 120 then h = 120 end

    if tg.SetWidth then tg:SetWidth(w) end
    if tg.SetHeight then tg:SetHeight(h) end
end

-- Pagina "Whisplist": la lista dei whisper ricevuti e il dettaglio del
-- giocatore vivono ora dentro il contenuto del TabGroup.
function GM:BuildWhisplistPage()
    -- Le pagine si ancorano al bordo del TabGroup (non al content interno
    -- AceGUI) per sfruttare tutta la larghezza/altezza disponibili.
    local area = self.ieTabGroup and self.ieTabGroup.border
    if not area then return end

    local page = CreateFrame("Frame", nil, area)
    page:SetPoint("TOPLEFT", area, "TOPLEFT", 1, -1)
    page:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -1, 1)
    self.wlPage = page

    -- ==== Received whispers ====
    self.wlListBox = CreateFrame("Frame", nil, page)
    self.wlListBox:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    self.wlListBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    self.wlListBox:SetHeight(140)
    RLSuite.utils:SkinBox(self.wlListBox)

    local listLabel = FontStr(self.wlListBox, "OVERLAY", 12)
    listLabel:SetPoint("TOPLEFT", self.wlListBox, "TOPLEFT", 8, -6)
    listLabel:SetText(L["Received whispers"])
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

    self.wlDetailBox = CreateFrame("Frame", nil, page)
    self.wlDetailBox:SetPoint("TOPLEFT", self.wlListBox, "BOTTOMLEFT", 0, -8)
    self.wlDetailBox:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    RLSuite.utils:SkinBox(self.wlDetailBox)
    self.wlDetailPanel = self.wlDetailBox

    self.wlDetailName = FontStr(self.wlDetailBox, "OVERLAY", 14)
    self.wlDetailName:SetPoint("TOPLEFT", self.wlDetailBox, "TOPLEFT", 10, -10)
    self.wlDetailName:SetPoint("TOPRIGHT", self.wlDetailBox, "TOPRIGHT", -10, -10)
    self.wlDetailName:SetJustifyH("LEFT")
    self.wlDetailName:SetText(L["Select a player"])
    self.wlDetailName:SetTextColor(1, 0.82, 0)

    self.wlDetailInfo = FontStr(self.wlDetailBox, "OVERLAY", 12)
    self.wlDetailInfo:SetPoint("TOPLEFT", self.wlDetailName, "BOTTOMLEFT", 0, -6)
    self.wlDetailInfo:SetPoint("RIGHT", self.wlDetailBox, "RIGHT", -10, 0)
    self.wlDetailInfo:SetJustifyH("LEFT")
    self.wlDetailInfo:SetText("")

    self.wlChat = CreateFrame("Frame", nil, self.wlDetailBox)
    self.wlChat:SetPoint("TOPLEFT", self.wlDetailInfo, "BOTTOMLEFT", 0, -8)
    self.wlChat:SetPoint("RIGHT", self.wlDetailBox, "RIGHT", -10, 0)
    self.wlChat:SetHeight(90)
    RLSuite.utils:SkinBox(self.wlChat)

    -- Scroll: qui si vedono TUTTI i messaggi del giocatore selezionato.
    self.wlChatScroll = CreateFrame("ScrollFrame", "RLSuiteWLChatScroll", self.wlChat, "UIPanelScrollFrameTemplate")
    self.wlChatScroll:SetPoint("TOPLEFT", self.wlChat, "TOPLEFT", 6, -6)
    self.wlChatScroll:SetPoint("BOTTOMRIGHT", self.wlChat, "BOTTOMRIGHT", -26, 6)

    -- SetScrollChild richiede un Frame: il testo vive dentro wlChatContent.
    self.wlChatContent = CreateFrame("Frame", nil, self.wlChatScroll)
    self.wlChatContent:SetWidth(200)
    self.wlChatScroll:SetScrollChild(self.wlChatContent)

    self.wlChatText = self.wlChatContent:CreateFontString(nil, "OVERLAY", nil)
    self.wlChatText:SetPoint("TOPLEFT", self.wlChatContent, "TOPLEFT", 0, 0)
    self.wlChatText:SetPoint("TOPRIGHT", self.wlChatContent, "TOPRIGHT", 0, 0)
    self.wlChatText:SetFont(FONT_FILE, 12, "")
    self.wlChatText:SetJustifyH("LEFT")
    self.wlChatText:SetJustifyV("TOP")
    self.wlChatText:SetWordWrap(true)
    self.wlChatText:SetText("")

    self.wlChatScroll:SetScript("OnSizeChanged", function(s, w, h)
        if GM.wlChatContent and w and w > 20 then
            GM.wlChatContent:SetWidth(w)
            if GM.wlChatText and GM.wlChatText.GetStringHeight then
                GM.wlChatContent:SetHeight(math.max(GM.wlChatText:GetStringHeight(), 1))
            end
        end
    end)

    self.wlInviteBtn = CreateFrame("Button", nil, self.wlDetailBox, "UIPanelButtonTemplate")
    self.wlInviteBtn:SetSize(66, 22)
    self.wlInviteBtn:SetPoint("BOTTOMLEFT", self.wlDetailBox, "BOTTOMLEFT", 10, 36)
    self.wlInviteBtn:SetText("Invite")
    self.wlInviteBtn:SetScript("OnClick", function() self:InviteSelected() end)

    self.wlAskGusBtn = CreateFrame("Button", nil, self.wlDetailBox, "UIPanelButtonTemplate")
    self.wlAskGusBtn:SetSize(66, 22)
    self.wlAskGusBtn:SetPoint("LEFT", self.wlInviteBtn, "RIGHT", 4, 0)
    self.wlAskGusBtn:SetText("Ask GS")
    self.wlAskGusBtn:SetScript("OnClick", function() self:AskGS() end)

    self.wlAskAchiBtn = CreateFrame("Button", nil, self.wlDetailBox, "UIPanelButtonTemplate")
    self.wlAskAchiBtn:SetSize(66, 22)
    self.wlAskAchiBtn:SetPoint("LEFT", self.wlAskGusBtn, "RIGHT", 4, 0)
    self.wlAskAchiBtn:SetText("Ask Achi")
    self.wlAskAchiBtn:SetScript("OnClick", function() self:AskAchi() end)

    self.wlDeclineBtn = CreateFrame("Button", nil, self.wlDetailBox, "UIPanelButtonTemplate")
    self.wlDeclineBtn:SetSize(66, 22)
    self.wlDeclineBtn:SetPoint("LEFT", self.wlAskAchiBtn, "RIGHT", 4, 0)
    self.wlDeclineBtn:SetText("Decline")
    self.wlDeclineBtn:SetScript("OnClick", function() self:DeclineSelected() end)

    local customLabel = FontStr(self.wlDetailBox, "OVERLAY", 12)
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
end

-- Cambia la tab attiva dell'InviteEngine (mostra una pagina e nasconde
-- l'altra). Viene chiamata dal callback "OnGroupSelected" del TabGroup.
function GM:SetInviteEngineTab(value)
    value = value or "whisper"
    self.ieActiveTab = value
    if self.wlPage then
        if value == "whisper" then self.wlPage:Show() else self.wlPage:Hide() end
    end
    if self.ieAutoPage then
        if value == "auto" then self.ieAutoPage:Show() else self.ieAutoPage:Hide() end
    end
    if value == "whisper" then
        self:UpdateWhisplist()
        self:UpdateWLGroups()
    elseif value == "auto" then
        self:RefreshAutoinviter()
    end
end

-- ============================================================
-- AUTOINVITER TAB (inviti programmati: lista manuale o evento di
-- Calendario). La pianificazione usa AceTimer-3.0, gli aggiornamenti del
-- Calendario arrivano via AceEvent-3.0.
-- ============================================================
-- Nome localizzato del giorno della settimana (1 = domenica), come Blizzard.
local function CalWeekdayName(weekday)
    if CALENDAR_WEEKDAY_NAMES and CALENDAR_WEEKDAY_NAMES[weekday] then
        return CALENDAR_WEEKDAY_NAMES[weekday]
    end
    local g = {
        [1] = WEEKDAY_SUNDAY or "Sunday", [2] = WEEKDAY_MONDAY or "Monday",
        [3] = WEEKDAY_TUESDAY or "Tuesday", [4] = WEEKDAY_WEDNESDAY or "Wednesday",
        [5] = WEEKDAY_THURSDAY or "Thursday", [6] = WEEKDAY_FRIDAY or "Friday",
        [7] = WEEKDAY_SATURDAY or "Saturday",
    }
    return g[weekday] or ""
end

-- Nome del mese per la data completa (CALENDAR_FULLDATE_MONTH_NAMES, come Blizzard).
local function CalFullDateMonthName(month)
    if CALENDAR_FULLDATE_MONTH_NAMES and CALENDAR_FULLDATE_MONTH_NAMES[month] then
        return CALENDAR_FULLDATE_MONTH_NAMES[month]
    end
    local names = CALENDAR_MONTH_NAMES or {}
    return names[month] or tostring(month or "")
end

-- Data completa stile calendario di gioco (fallback senza FULLDATE globale).
function GM:CalendarFullDate(weekday, month, day, year)
    return string.format("%s, %s %d, %d", CalWeekdayName(weekday), CalFullDateMonthName(month), day or 0, year or 0)
end

-- Ora formattata come il calendario di gioco.
function GM:CalendarFormattedTime(hour, minute)
    if GameTime_GetFormattedTime then
        return GameTime_GetFormattedTime(hour or 0, minute or 0, true)
    end
    return string.format("%02d:%02d", hour or 0, minute or 0)
end

-- Texture dell'icona per tipo evento (stessi path di Blizzard 3.3.5).
local function CalendarEventTypeTexture(eventType)
    local t = tonumber(eventType) or 1
    local map = {
        [1] = "Interface\\LFGFrame\\LFGIcon-Raid",          -- RAID
        [2] = "Interface\\LFGFrame\\LFGIcon-Dungeon",       -- DUNGEON
        [3] = "Interface\\Calendar\\UI-Calendar-Event-PVP", -- PVP (fallback)
        [4] = "Interface\\Calendar\\MeetingIcon",           -- MEETING
        [5] = "Interface\\Calendar\\UI-Calendar-Event-Other", -- OTHER
    }
    if t == 3 and UnitFactionGroup then
        local faction = UnitFactionGroup("player")
        if faction == "Alliance" then
            return "Interface\\Calendar\\UI-Calendar-Event-PVP02"
        elseif faction == "Horde" then
            return "Interface\\Calendar\\UI-Calendar-Event-PVP01"
        end
    end
    return map[t]
end

-- Colore di classe (RAID_CLASS_COLORS come Blizzard, fallback su Utils).
local function CalClassColor(classFilename)
    local c = RAID_CLASS_COLORS and classFilename and RAID_CLASS_COLORS[classFilename]
    if c then return c.r, c.g, c.b end
    return RLSuite.utils:GetClassColor(classFilename)
end

-- Colore di un font color globale Blizzard, con fallback.
local function CalFontColor(globalName, fr, fg, fb)
    local c = _G[globalName]
    if c then return c.r, c.g, c.b end
    return fr, fg, fb
end

-- FontString con oggetto font Blizzard (per una copia fedele), con fallback.
local function CalFontStr(parent, layer, fontObjName, fallbackSize)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", nil)
    local obj = _G[fontObjName]
    if obj and fs.SetFontObject then
        fs:SetFontObject(obj)
    elseif fs.SetFont then
        fs:SetFont(FONT_FILE, fallbackSize or 12, "")
    end
    return fs
end

function GM:BuildAutoinviterPage()
    local area = self.ieTabGroup and self.ieTabGroup.border
    if not area then return end

    local page = CreateFrame("Frame", nil, area)
    page:SetPoint("TOPLEFT", area, "TOPLEFT", 1, -1)
    page:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -1, 1)
    page:Hide()
    self.ieAutoPage = page

    local db = self.autoinvite

    -- Sorgente: lista manuale oppure evento di Calendario (mutualmente esclusive).
    self.ieAutoManualCheck = CreateFrame("CheckButton", "RLSuiteIEAutoManualCheck", page, "UICheckButtonTemplate")
    self.ieAutoManualCheck:SetSize(24, 24)
    self.ieAutoManualCheck:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -8)
    self.ieAutoManualCheck:SetScript("OnClick", function(s)
        if s:GetChecked() then
            db.mode = "manual"
            if self.ieAutoCalendarCheck then self.ieAutoCalendarCheck:SetChecked(false) end
        else
            db.mode = "calendar"
            if self.ieAutoCalendarCheck then self.ieAutoCalendarCheck:SetChecked(true) end
        end
        self:RefreshAutoinviter()
        self:SaveAutoinviter()
    end)

    local manualLbl = FontStr(page, "OVERLAY", 12)
    manualLbl:SetPoint("LEFT", self.ieAutoManualCheck, "RIGHT", 0, 0)
    manualLbl:SetText(L["Manual list"])

    self.ieAutoCalendarCheck = CreateFrame("CheckButton", "RLSuiteIEAutoCalendarCheck", page, "UICheckButtonTemplate")
    self.ieAutoCalendarCheck:SetSize(24, 24)
    self.ieAutoCalendarCheck:SetPoint("LEFT", manualLbl, "RIGHT", 16, 0)
    self.ieAutoCalendarCheck:SetScript("OnClick", function(s)
        if s:GetChecked() then
            db.mode = "calendar"
            if self.ieAutoManualCheck then self.ieAutoManualCheck:SetChecked(false) end
        else
            db.mode = "manual"
            if self.ieAutoManualCheck then self.ieAutoManualCheck:SetChecked(true) end
        end
        self:RefreshAutoinviter()
        self:SaveAutoinviter()
    end)

    local calLbl = FontStr(page, "OVERLAY", 12)
    calLbl:SetPoint("LEFT", self.ieAutoCalendarCheck, "RIGHT", 0, 0)
    calLbl:SetText(L["Calendar event"])

    -- ============================================================
    -- Barra inferiore: ora di invito + tasti + stato (l'ultima cosa
    -- in fondo, sotto i riquadri manuale/calendario, senza clippare).
    -- ============================================================
    self.ieAutoFooter = CreateFrame("Frame", nil, page)
    self.ieAutoFooter:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    self.ieAutoFooter:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    self.ieAutoFooter:SetHeight(76)

    self.ieAutoStatus = FontStr(self.ieAutoFooter, "OVERLAY", 12)
    self.ieAutoStatus:SetPoint("BOTTOMLEFT", self.ieAutoFooter, "BOTTOMLEFT", 8, 4)
    self.ieAutoStatus:SetPoint("RIGHT", self.ieAutoFooter, "RIGHT", -8, 0)
    self.ieAutoStatus:SetJustifyH("LEFT")
    self.ieAutoStatus:SetText("")
    self.ieAutoStatus:SetTextColor(1, 0.82, 0)

    self.ieAutoArmBtn = CreateFrame("Button", nil, self.ieAutoFooter, "UIPanelButtonTemplate")
    self.ieAutoArmBtn:SetSize(130, 24)
    self.ieAutoArmBtn:SetPoint("BOTTOMLEFT", self.ieAutoFooter, "BOTTOMLEFT", 8, 26)
    self.ieAutoArmBtn:SetText(L["Start Autoinviter"])
    self.ieAutoArmBtn:SetScript("OnClick", function() self:ToggleAutoinviter() end)

    self.ieAutoNowBtn = CreateFrame("Button", nil, self.ieAutoFooter, "UIPanelButtonTemplate")
    self.ieAutoNowBtn:SetSize(130, 24)
    self.ieAutoNowBtn:SetPoint("LEFT", self.ieAutoArmBtn, "RIGHT", 8, 0)
    self.ieAutoNowBtn:SetText(L["Auto invite now"])
    self.ieAutoNowBtn:SetScript("OnClick", function() self:AutoInviteNow() end)

    local timeLbl = FontStr(self.ieAutoFooter, "OVERLAY", 12)
    timeLbl:SetPoint("BOTTOMLEFT", self.ieAutoFooter, "BOTTOMLEFT", 8, 52)
    timeLbl:SetText(L["Invite at"])
    timeLbl:SetTextColor(1, 0.82, 0)

    self.ieAutoHourEdit = CreateFrame("EditBox", "RLSuiteIEAutoHour", self.ieAutoFooter, "InputBoxTemplate")
    self.ieAutoHourEdit:SetSize(34, 20)
    self.ieAutoHourEdit:SetPoint("LEFT", timeLbl, "RIGHT", 8, 0)
    self.ieAutoHourEdit:SetAutoFocus(false)
    self.ieAutoHourEdit:SetMaxLetters(2)
    self.ieAutoHourEdit:SetNumeric(true)
    self.ieAutoHourEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    self.ieAutoHourEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)

    local colonLbl = FontStr(self.ieAutoFooter, "OVERLAY", 12)
    colonLbl:SetPoint("LEFT", self.ieAutoHourEdit, "RIGHT", 2, 0)
    colonLbl:SetText(":")

    self.ieAutoMinuteEdit = CreateFrame("EditBox", "RLSuiteIEAutoMinute", self.ieAutoFooter, "InputBoxTemplate")
    self.ieAutoMinuteEdit:SetSize(34, 20)
    self.ieAutoMinuteEdit:SetPoint("LEFT", colonLbl, "RIGHT", 2, 0)
    self.ieAutoMinuteEdit:SetAutoFocus(false)
    self.ieAutoMinuteEdit:SetMaxLetters(2)
    self.ieAutoMinuteEdit:SetNumeric(true)
    self.ieAutoMinuteEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    self.ieAutoMinuteEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)

    local timeHint = FontStr(self.ieAutoFooter, "OVERLAY", 12)
    timeHint:SetPoint("LEFT", self.ieAutoMinuteEdit, "RIGHT", 6, 0)
    timeHint:SetText(L["(server time)"])
    timeHint:SetTextColor(0.6, 0.6, 0.6)

    -- ============================================================
    -- Pannello lista manuale.
    -- ============================================================
    self.ieAutoManualBox = CreateFrame("Frame", nil, page)
    self.ieAutoManualBox:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -38)
    self.ieAutoManualBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", -8, -38)
    self.ieAutoManualBox:SetPoint("BOTTOM", self.ieAutoFooter, "TOP", 0, -4)
    RLSuite.utils:SkinBox(self.ieAutoManualBox)

    local namesLbl = FontStr(self.ieAutoManualBox, "OVERLAY", 12)
    namesLbl:SetPoint("TOPLEFT", self.ieAutoManualBox, "TOPLEFT", 8, -6)
    namesLbl:SetText(L["Add player"])
    namesLbl:SetTextColor(1, 0.82, 0)

    self.ieAutoNamesEdit = CreateFrame("EditBox", "RLSuiteIEAutoNames", self.ieAutoManualBox, "InputBoxTemplate")
    self.ieAutoNamesEdit:SetPoint("TOPLEFT", namesLbl, "BOTTOMLEFT", 0, -4)
    self.ieAutoNamesEdit:SetPoint("TOPRIGHT", self.ieAutoManualBox, "TOPRIGHT", -8, -26)
    self.ieAutoNamesEdit:SetHeight(20)
    self.ieAutoNamesEdit:SetAutoFocus(false)
    self.ieAutoNamesEdit:SetMaxLetters(32)
    self.ieAutoNamesEdit:SetScript("OnEnterPressed", function(s)
        GM:AddAutoName(s:GetText())
    end)
    self.ieAutoNamesEdit:SetScript("OnEscapePressed", function(s)
        s:SetText("")
        s:ClearFocus()
    end)

    local hint = FontStr(self.ieAutoManualBox, "OVERLAY", 10)
    hint:SetPoint("TOPLEFT", self.ieAutoNamesEdit, "BOTTOMLEFT", 0, -2)
    hint:SetText(L["Enter to add - click X to remove"])
    hint:SetTextColor(0.6, 0.6, 0.6)

    self.ieAutoNamesList = CreateFrame("Frame", nil, self.ieAutoManualBox)
    self.ieAutoNamesList:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -2)
    self.ieAutoNamesList:SetPoint("BOTTOMRIGHT", self.ieAutoManualBox, "BOTTOMRIGHT", -8, 4)
    self.ieAutoNamesList:EnableMouse(true)

    self.ieAutoNamesScroll = CreateFrame("ScrollFrame", "RLSuiteIEAutoNamesScroll", self.ieAutoNamesList, "UIPanelScrollFrameTemplate")
    self.ieAutoNamesScroll:SetPoint("TOPLEFT", self.ieAutoNamesList, "TOPLEFT", 0, 0)
    self.ieAutoNamesScroll:SetPoint("BOTTOMRIGHT", self.ieAutoNamesList, "BOTTOMRIGHT", -16, 0)

    self.ieAutoNamesContent = CreateFrame("Frame", nil, self.ieAutoNamesScroll)
    self.ieAutoNamesContent:SetSize(200, 10)
    self.ieAutoNamesScroll:SetScrollChild(self.ieAutoNamesContent)

    -- ============================================================
    -- Pannello evento di Calendario: riquadro con "Link or create an
    -- event" + "Edit event", e sotto la copia esatta della schermata
    -- evento del calendario di gioco.
    -- ============================================================
    self.ieAutoCalBox = CreateFrame("Frame", nil, page)
    self.ieAutoCalBox:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -38)
    self.ieAutoCalBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", -8, -38)
    self.ieAutoCalBox:SetPoint("BOTTOM", self.ieAutoFooter, "TOP", 0, -4)
    RLSuite.utils:SkinBox(self.ieAutoCalBox)

    self.ieAutoLinkBtn = CreateFrame("Button", nil, self.ieAutoCalBox, "UIPanelButtonTemplate")
    self.ieAutoLinkBtn:SetSize(190, 24)
    self.ieAutoLinkBtn:SetPoint("TOPLEFT", self.ieAutoCalBox, "TOPLEFT", 8, -8)
    self.ieAutoLinkBtn:SetText(L["Link or create an event"])
    self.ieAutoLinkBtn:SetScript("OnClick", function() self:OpenCalendarToLink() end)

    self.ieAutoEditBtn = CreateFrame("Button", nil, self.ieAutoCalBox, "UIPanelButtonTemplate")
    self.ieAutoEditBtn:SetSize(120, 24)
    self.ieAutoEditBtn:SetPoint("TOPRIGHT", self.ieAutoCalBox, "TOPRIGHT", -8, -8)
    self.ieAutoEditBtn:SetText(L["Edit event"])
    self.ieAutoEditBtn:SetScript("OnClick", function() self:EditLinkedCalendarEvent() end)
    self.ieAutoEditBtn:Hide()

    -- Area "mirror" (copia della CalendarViewEventFrame).
    self.ieAutoMirror = CreateFrame("Frame", nil, self.ieAutoCalBox)
    self.ieAutoMirror:SetPoint("TOPLEFT", self.ieAutoCalBox, "TOPLEFT", 8, -40)
    self.ieAutoMirror:SetPoint("BOTTOMRIGHT", self.ieAutoCalBox, "BOTTOMRIGHT", -8, 8)
    self.ieAutoMirror:EnableMouse(true)

    -- icona evento (60x60 come CalendarViewEventIcon)
    self.ieAutoMirrorIcon = self.ieAutoMirror:CreateTexture(nil, "ARTWORK")
    self.ieAutoMirrorIcon:SetSize(60, 60)
    self.ieAutoMirrorIcon:SetPoint("TOPLEFT", self.ieAutoMirror, "TOPLEFT", 16, -26)
    self.ieAutoMirrorIcon:SetTexCoord(0, 1, 0, 1)

    -- titolo (GameFontNormal, sinistra)
    self.ieAutoMirrorTitle = CalFontStr(self.ieAutoMirror, "OVERLAY", "GameFontNormal", 13)
    self.ieAutoMirrorTitle:SetPoint("TOPLEFT", self.ieAutoMirrorIcon, "TOPRIGHT", 2, 0)
    self.ieAutoMirrorTitle:SetPoint("RIGHT", self.ieAutoMirror, "RIGHT", -16, 0)
    self.ieAutoMirrorTitle:SetJustifyH("LEFT")
    self.ieAutoMirrorTitle:SetText("")

    -- tipo evento (GameFontNormalSmall)
    self.ieAutoMirrorType = CalFontStr(self.ieAutoMirror, "OVERLAY", "GameFontNormalSmall", 11)
    self.ieAutoMirrorType:SetPoint("TOPLEFT", self.ieAutoMirrorTitle, "BOTTOMLEFT", 0, 0)
    self.ieAutoMirrorType:SetPoint("RIGHT", self.ieAutoMirror, "RIGHT", -16, 0)
    self.ieAutoMirrorType:SetJustifyH("LEFT")
    self.ieAutoMirrorType:SetText("")

    -- creatore (GameFontNormalSmall)
    self.ieAutoMirrorCreator = CalFontStr(self.ieAutoMirror, "OVERLAY", "GameFontNormalSmall", 11)
    self.ieAutoMirrorCreator:SetPoint("TOPLEFT", self.ieAutoMirrorType, "BOTTOMLEFT", 0, 0)
    self.ieAutoMirrorCreator:SetPoint("RIGHT", self.ieAutoMirror, "RIGHT", -16, 0)
    self.ieAutoMirrorCreator:SetJustifyH("LEFT")
    self.ieAutoMirrorCreator:SetText("")

    -- data (GameFontHighlightSmall)
    self.ieAutoMirrorDate = CalFontStr(self.ieAutoMirror, "OVERLAY", "GameFontHighlightSmall", 11)
    self.ieAutoMirrorDate:SetPoint("TOPLEFT", self.ieAutoMirrorCreator, "BOTTOMLEFT", 0, 0)
    self.ieAutoMirrorDate:SetPoint("RIGHT", self.ieAutoMirror, "RIGHT", -16, 0)
    self.ieAutoMirrorDate:SetJustifyH("LEFT")
    self.ieAutoMirrorDate:SetText("")

    -- ora (GameFontHighlightSmall)
    self.ieAutoMirrorTime = CalFontStr(self.ieAutoMirror, "OVERLAY", "GameFontHighlightSmall", 11)
    self.ieAutoMirrorTime:SetPoint("TOPLEFT", self.ieAutoMirrorDate, "BOTTOMLEFT", 0, 0)
    self.ieAutoMirrorTime:SetPoint("RIGHT", self.ieAutoMirror, "RIGHT", -16, 0)
    self.ieAutoMirrorTime:SetJustifyH("LEFT")
    self.ieAutoMirrorTime:SetText("")

    -- box descrizione (tooltip background/border, come CalendarViewEventDescriptionContainer)
    self.ieAutoMirrorDescBox = CreateFrame("Frame", nil, self.ieAutoMirror)
    self.ieAutoMirrorDescBox:SetPoint("TOPLEFT", self.ieAutoMirror, "TOPLEFT", 16, -95)
    self.ieAutoMirrorDescBox:SetPoint("RIGHT", self.ieAutoMirror, "RIGHT", -16, 0)
    self.ieAutoMirrorDescBox:SetHeight(65)
    self.ieAutoMirrorDescBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    self.ieAutoMirrorDescBox:SetBackdropColor(0, 0, 0, 0.9)
    if TOOLTIP_DEFAULT_COLOR then
        self.ieAutoMirrorDescBox:SetBackdropBorderColor(
            TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1)
    end

    self.ieAutoMirrorDescScroll = CreateFrame("ScrollFrame", "RLSuiteIEAutoEventDesc", self.ieAutoMirrorDescBox, "UIPanelScrollFrameTemplate")
    self.ieAutoMirrorDescScroll:SetPoint("TOPLEFT", self.ieAutoMirrorDescBox, "TOPLEFT", 4, -4)
    self.ieAutoMirrorDescScroll:SetPoint("BOTTOMRIGHT", self.ieAutoMirrorDescBox, "BOTTOMRIGHT", -18, 4)

    self.ieAutoMirrorDescContent = CreateFrame("Frame", nil, self.ieAutoMirrorDescScroll)
    self.ieAutoMirrorDescContent:SetWidth(200)
    self.ieAutoMirrorDescScroll:SetScrollChild(self.ieAutoMirrorDescContent)

    self.ieAutoMirrorDesc = CalFontStr(self.ieAutoMirrorDescContent, "OVERLAY", "GameFontNormalSmall", 11)
    self.ieAutoMirrorDesc:SetPoint("TOPLEFT", self.ieAutoMirrorDescContent, "TOPLEFT", 0, 0)
    self.ieAutoMirrorDesc:SetPoint("TOPRIGHT", self.ieAutoMirrorDescContent, "TOPRIGHT", 0, 0)
    self.ieAutoMirrorDesc:SetJustifyH("LEFT")
    self.ieAutoMirrorDesc:SetJustifyV("TOP")
    self.ieAutoMirrorDesc:SetWordWrap(true)
    self.ieAutoMirrorDesc:SetText("")

    -- divisore sopra l'elenco invitati (come CalendarViewEventDivider)
    self.ieAutoMirrorDivider = self.ieAutoMirror:CreateTexture(nil, "BORDER")
    self.ieAutoMirrorDivider:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Divider")
    self.ieAutoMirrorDivider:SetSize(303, 16)
    self.ieAutoMirrorDivider:SetPoint("TOPLEFT", self.ieAutoMirrorDescBox, "BOTTOMLEFT", 6, -8)
    self.ieAutoMirrorDivider:SetTexCoord(0, 0.75390625, 0, 0.5)

    -- elenco partecipanti (copia di CalendarViewEventInviteList)
    self.ieAutoMirrorInviteList = CreateFrame("ScrollFrame", "RLSuiteIEAutoEventInvites", self.ieAutoMirror, "UIPanelScrollFrameTemplate")
    self.ieAutoMirrorInviteList:SetPoint("TOPLEFT", self.ieAutoMirrorDivider, "BOTTOMLEFT", 0, -4)
    self.ieAutoMirrorInviteList:SetPoint("BOTTOMRIGHT", self.ieAutoMirror, "BOTTOMRIGHT", -8, 0)

    self.ieAutoMirrorInviteContent = CreateFrame("Frame", nil, self.ieAutoMirrorInviteList)
    self.ieAutoMirrorInviteContent:SetSize(200, 10)
    self.ieAutoMirrorInviteList:SetScrollChild(self.ieAutoMirrorInviteContent)
end

-- Aggiorna checkbox/pannelli/stato in base alla modalita' salvata.
function GM:RefreshAutoinviter()
    if not self.ieAutoPage then return end
    local db = self.autoinvite
    if db.mode ~= "calendar" then db.mode = "manual" end
    local manual = (db.mode == "manual")

    if self.ieAutoManualCheck then self.ieAutoManualCheck:SetChecked(manual) end
    if self.ieAutoCalendarCheck then self.ieAutoCalendarCheck:SetChecked(not manual) end
    if self.ieAutoManualBox then
        if manual then self.ieAutoManualBox:Show() else self.ieAutoManualBox:Hide() end
    end
    if self.ieAutoCalBox then
        if manual then self.ieAutoCalBox:Hide() else self.ieAutoCalBox:Show() end
    end
    if manual then
        self:BuildAutoNameListUI()
    end
    if self.ieAutoHourEdit then self.ieAutoHourEdit:SetText(string.format("%02d", db.hour or 19)) end
    if self.ieAutoMinuteEdit then self.ieAutoMinuteEdit:SetText(string.format("%02d", db.minute or 0)) end

    if not manual then self:RenderLinkedEvent() end
    self:RefreshAutoinviterStatus()
    self:RefreshAutoinviterArmButton()
end

-- Assicura che l'addon Blizzard_Calendar sia caricato (e' LoadOnDemand).
function GM:EnsureCalendarLoaded()
    if LoadAddOn and (CalendarGetEventInfo == nil or CalendarGetEventIndex == nil) then
        pcall(LoadAddOn, "Blizzard_Calendar")
    end
    return CalendarGetEventInfo ~= nil and CalendarGetEventIndex ~= nil
end

-- Apre il calendario di gioco per linkare/creare l'evento raid.
function GM:OpenCalendarToLink()
    if not self:EnsureCalendarLoaded() then
        RLSuite.utils:Print(L["Calendar addon could not be loaded."])
        return
    end
    self:EnsureRLSCalendarUI()
    if Calendar_Show then
        Calendar_Show()
    elseif Calendar_Toggle and CalendarFrame and not CalendarFrame:IsShown() then
        Calendar_Toggle()
    end
    RLSuite.utils:Print(L["Open your raid event and tick 'Link to RLS'."])
end

-- Legge i dati dell'evento attualmente APERTO nel calendario. nil se nessuno.
function GM:GetOpenCalendarEventInfo()
    if not self:EnsureCalendarLoaded() then return nil end
    local ok, title, description, creator, eventType, repeatOption, maxSize, textureIndex,
        weekday, month, day, year, hour, minute,
        lockoutWeekday, lockoutMonth, lockoutDay, lockoutYear, lockoutHour, lockoutMinute,
        locked, autoApprove, pendingInvite, inviteStatus, inviteType, calendarType = pcall(CalendarGetEventInfo)
    if not ok or not title then return nil end
    return {
        title = title,
        description = description or "",
        creator = creator or "",
        eventType = tonumber(eventType) or 1,
        textureIndex = textureIndex,
        weekday = weekday, month = month, day = day, year = year,
        hour = hour or 0, minute = minute or 0,
        locked = locked and true or false,
        autoApprove = autoApprove and true or false,
        inviteStatus = inviteStatus,
        inviteType = inviteType,
        calendarType = calendarType,
    }
end

-- Identita' (monthOffset, day, index) dell'evento aperto.
function GM:GetOpenCalendarEventIndex()
    if not self:EnsureCalendarLoaded() then return nil end
    local ok, monthOffset, day, index = pcall(CalendarGetEventIndex)
    if not ok or not day or not index then return nil end
    return monthOffset, day, index
end

-- Elenco completo degli invitati dell'evento aperto.
function GM:GetOpenCalendarInviteList()
    local list = {}
    if not self:EnsureCalendarLoaded() then return list end
    if not CalendarEventGetNumInvites or not CalendarEventGetInvite then return list end
    local n = CalendarEventGetNumInvites() or 0
    for i = 1, n do
        local ok, name, level, className, classFilename, status, modStatus = pcall(CalendarEventGetInvite, i)
        if ok and name and name ~= "" then
            table.insert(list, {
                name = name,
                className = className or "",
                class = classFilename or "WARRIOR",
                status = tonumber(status) or 1,
                mod = modStatus or "",
            })
        end
    end
    return list
end

-- Cattura l'evento aperto e lo salva come snapshot completo.
function GM:CaptureOpenCalendarEvent()
    local info = self:GetOpenCalendarEventInfo()
    if not info then return nil end
    local monthOffset, day, index = self:GetOpenCalendarEventIndex()
    info.monthOffset = monthOffset
    info.eventDay = day
    info.eventIndex = index
    info.invitees = self:GetOpenCalendarInviteList()
    return info
end

-- Collega l'evento attualmente aperto (chiamato dalla checkbox nel calendario).
function GM:LinkOpenCalendarEvent()
    local snapshot = self:CaptureOpenCalendarEvent()
    if not snapshot then
        RLSuite.utils:Print(L["Create/save the event first, then tick 'Link to RLS'."])
        return false
    end
    self.autoinvite.linkedEvent = snapshot
    -- sincronizza l'orario di invito con quello dell'evento
    self.autoinvite.hour = snapshot.hour
    self.autoinvite.minute = snapshot.minute
    if self.ieAutoHourEdit then self.ieAutoHourEdit:SetText(string.format("%02d", snapshot.hour)) end
    if self.ieAutoMinuteEdit then self.ieAutoMinuteEdit:SetText(string.format("%02d", snapshot.minute)) end
    self:SaveAutoinviter()
    self:RenderLinkedEvent()
    RLSuite.utils:Print(string.format(L["Event linked: %s"], snapshot.title))
    return true
end

-- Scollega l'evento.
function GM:UnlinkCalendarEvent()
    self.autoinvite.linkedEvent = nil
    self:SaveAutoinviter()
    self:RenderLinkedEvent()
    RLSuite.utils:Print(L["Event unlinked."])
end

-- Crea la checkbox "Link to RLS" dentro le schermate evento del calendario
-- (vista + modifica) e aggancia gli aggiornamenti. Chiamata una sola volta.


-- Apre il calendario di gioco sull'evento collegato, per modificarlo.
function GM:EditLinkedCalendarEvent()
    local link = self.autoinvite and self.autoinvite.linkedEvent
    if not link or not link.title then
        RLSuite.utils:Print(L["No event linked yet."])
        return
    end
    if not self:EnsureCalendarLoaded() then
        RLSuite.utils:Print(L["Calendar addon could not be loaded."])
        return
    end
    self:EnsureRLSCalendarUI()
    if Calendar_Show then Calendar_Show() end

    -- naviga al mese dell'evento, poi trova e apre l'evento per titolo
    if CalendarSetAbsMonth and link.month and link.year then
        pcall(CalendarSetAbsMonth, link.month, link.year)
    end
    local opened = false
    local day = link.eventDay or link.day
    if CalendarGetNumDayEvents and CalendarGetDayEvent and CalendarOpenEvent and day then
        local okN, n = pcall(CalendarGetNumDayEvents, 0, day)
        if okN and n and n > 0 then
            for i = 1, n do
                local okT, t = pcall(CalendarGetDayEvent, 0, day, i)
                if okT and t == link.title then
                    pcall(CalendarOpenEvent, 0, day, i)
                    opened = true
                    break
                end
            end
        end
    end
    -- fallback: usa gli identificativi salvati al momento del link
    if not opened then
        pcall(CalendarOpenEvent, link.monthOffset or 0, link.eventDay, link.eventIndex)
    end
end
function GM:EnsureRLSCalendarUI()
    if self._rlsCalHooked then return end
    if not self:EnsureCalendarLoaded() then return end
    if not CalendarViewEventFrame or not CalendarCreateEventFrame then return end
    self._rlsCalHooked = true

    local function attachLabel(cb)
        local label = FontStr(cb, "OVERLAY", 12)
        label:SetText(L["Link to RLS"])
        label:SetTextColor(1, 0.82, 0)
        cb.label = label
        return label
    end

    local function onClick(self)
        if self:GetChecked() then
            -- Vista: l'evento esiste gia' e si puo' linkare subito.
            -- Creazione/modifica: l'intento viene catturato al salvataggio
            -- (CALENDAR_NEW_EVENT / CALENDAR_UPDATE_EVENT).
            if self.isView then
                GM:LinkOpenCalendarEvent()
            end
        else
            GM:UnlinkCalendarEvent()
        end
    end

    -- Vista evento (non moderatore): in basso, sotto descrizione/lista invitati.
    self._rlsCalCheckView = CreateFrame("CheckButton", nil, CalendarViewEventFrame, "UICheckButtonTemplate")
    self._rlsCalCheckView:SetSize(24, 24)
    self._rlsCalCheckView:SetPoint("BOTTOMLEFT", CalendarViewEventFrame, "BOTTOMLEFT", 14, 12)
    self._rlsCalCheckView.isView = true
    local viewLabel = attachLabel(self._rlsCalCheckView)
    viewLabel:SetPoint("LEFT", self._rlsCalCheckView, "RIGHT", 4, 0)
    self._rlsCalCheckView:SetScript("OnClick", onClick)

    -- Creazione/modifica evento: sotto il box della descrizione, accanto
    -- alla checkbox "Lock event" di Blizzard (stessa riga, subito a sinistra).
    self._rlsCalCheckEdit = CreateFrame("CheckButton", nil, CalendarCreateEventFrame, "UICheckButtonTemplate")
    self._rlsCalCheckEdit:SetSize(24, 24)
    local lockCheck = CalendarCreateEventLockEventCheck
    if lockCheck then
        self._rlsCalCheckEdit:SetPoint("RIGHT", lockCheck, "LEFT", -8, 0)
    else
        self._rlsCalCheckEdit:SetPoint("TOPLEFT", CalendarCreateEventDescriptionContainer, "BOTTOMLEFT", 0, -8)
    end
    local editLabel = attachLabel(self._rlsCalCheckEdit)
    editLabel:SetPoint("RIGHT", self._rlsCalCheckEdit, "LEFT", -4, 0)
    self._rlsCalCheckEdit:SetScript("OnClick", onClick)
    -- il testo sta a SINISTRA della casella: allarga l'area cliccabile.
    local editLabelW = editLabel:GetStringWidth() or 0
    if editLabelW > 0 then
        self._rlsCalCheckEdit:SetHitRectInsets(-editLabelW - 4, 0, 0, 0)
    end

    -- In una nuova schermata di creazione (CREATE) azzera l'intento residuo.
    CalendarCreateEventFrame:HookScript("OnShow", function(frame)
        if frame.mode == "create" and self._rlsCalCheckEdit then
            self._rlsCalCheckEdit:SetChecked(false)
        end
    end)

    local function refresh()
        GM:RefreshRLSCalendarCheckboxes()
    end
    if hooksecurefunc then
        hooksecurefunc("CalendarViewEventFrame_Update", refresh)
        hooksecurefunc("CalendarCreateEventFrame_Update", refresh)
        hooksecurefunc("CalendarFrame_CloseEvent", refresh)
    end
end

-- Chiamato quando un evento viene creato/aggiornato nel calendario: se la
-- checkbox "Link to RLS" della schermata di creazione e' spuntata, il nuovo
-- evento (ora aperto) viene catturato come evento collegato.
function GM:OnCalendarEventCreated()
    if self._rlsCalCheckEdit and self._rlsCalCheckEdit:GetChecked() then
        self:LinkOpenCalendarEvent()
    end
    self:OnCalendarChanged()
end

-- Allinea le checkbox "Link to RLS" e, se l'evento collegato e' aperto,
-- aggiorna lo snapshot (lista invitati fresca) e il mirror.
function GM:RefreshRLSCalendarCheckboxes()
    local info = self:GetOpenCalendarEventInfo()
    local link = self.autoinvite and self.autoinvite.linkedEvent
    local isLinked = false
    if info and link and link.title then
        if info.title == link.title
            and tostring(info.month) == tostring(link.month)
            and tostring(info.day) == tostring(link.day)
            and tostring(info.year) == tostring(link.year) then
            isLinked = true
        end
    end

    if isLinked then
        self.autoinvite.linkedEvent = self:CaptureOpenCalendarEvent()
    end

    -- Checkbox della vista: riflette l'evento attualmente aperto.
    local viewCb = self._rlsCalCheckView
    if viewCb then
        if info then
            viewCb:Enable()
            viewCb:SetChecked(isLinked)
        else
            viewCb:SetChecked(false)
            viewCb:Disable()
        end
    end

    -- Checkbox della creazione/modifica: sempre attiva mentre la schermata e'
    -- visibile. In EDIT di un evento gia' linkato riflette lo stato; in CREATE
    -- lascia invariato l'intento dell'utente (catturato al salvataggio).
    local editCb = self._rlsCalCheckEdit
    if editCb then
        if CalendarCreateEventFrame and CalendarCreateEventFrame:IsShown() then
            editCb:Enable()
            if info and CalendarCreateEventFrame.mode == "edit" then
                editCb:SetChecked(isLinked)
            end
        else
            editCb:SetChecked(false)
            editCb:Disable()
        end
    end

    self:RenderLinkedEvent()
end

-- Aggiornamento del calendario (eventi AceEvent): aggancia la UI se serve e
-- riallinea checkbox + mirror.
function GM:OnCalendarChanged()
    if not self:EnsureCalendarLoaded() then return end
    self:EnsureRLSCalendarUI()
    self:RefreshRLSCalendarCheckboxes()
end

-- Copia esatta della schermata evento del calendario di gioco, dentro la
-- tab Calendar event. Disegna dallo snapshot collegato.
-- Copia ESATTA della schermata evento del calendario di gioco
-- (CalendarViewEventFrame_Update). Disegna dallo snapshot collegato usando
-- gli stessi font, colori e formati di Blizzard.
function GM:RenderLinkedEvent()
    local link = self.autoinvite and self.autoinvite.linkedEvent

    -- stato vuoto
    if not link or not link.title then
        if self.ieAutoEditBtn then self.ieAutoEditBtn:Hide() end
        if self.ieAutoMirrorTitle then self.ieAutoMirrorTitle:SetText(L["No event linked yet."]) end
        if self.ieAutoMirrorType then self.ieAutoMirrorType:SetText("") end
        if self.ieAutoMirrorCreator then self.ieAutoMirrorCreator:SetText("") end
        if self.ieAutoMirrorDate then self.ieAutoMirrorDate:SetText("") end
        if self.ieAutoMirrorTime then self.ieAutoMirrorTime:SetText("") end
        if self.ieAutoMirrorDesc then self.ieAutoMirrorDesc:SetText("") end
        if self.ieAutoMirrorIcon then
            self.ieAutoMirrorIcon:SetTexture("")
            if SetDesaturation then SetDesaturation(self.ieAutoMirrorIcon, false) end
        end
        self:ClearAutoinviteMirrorInvites()
        return
    end

    if self.ieAutoEditBtn then self.ieAutoEditBtn:Show() end

    local locked = link.locked
    local title = link.title or ""

    local nr, ng, nb = CalFontColor("NORMAL_FONT_COLOR", 1, 1, 1)
    local hr, hg, hb = CalFontColor("HIGHLIGHT_FONT_COLOR", 1, 0.82, 0)
    local gr, gg, gb = CalFontColor("GRAY_FONT_COLOR", 0.5, 0.5, 0.5)

    -- icona (event type texture, come CalendarViewEventIcon)
    if self.ieAutoMirrorIcon then
        local tex = CalendarEventTypeTexture(link.eventType)
        self.ieAutoMirrorIcon:SetTexture(tex or "")
        self.ieAutoMirrorIcon:SetTexCoord(0, 1, 0, 1)
        if SetDesaturation then
            SetDesaturation(self.ieAutoMirrorIcon, locked and true or false)
        end
    end

    -- titolo (con "(Locked)" e colori quando bloccato, come Blizzard)
    if self.ieAutoMirrorTitle then
        if locked and CALENDAR_VIEW_EVENTTITLE_LOCKED then
            self.ieAutoMirrorTitle:SetFormattedText(CALENDAR_VIEW_EVENTTITLE_LOCKED, title)
        else
            self.ieAutoMirrorTitle:SetText(title)
        end
    end

    -- tipo evento ("Raid", ecc.)
    local typeName = ""
    if CalendarEventGetTypes then
        local ok, name = pcall(function()
            local names = { CalendarEventGetTypes() }
            return names[link.eventType or 1] or names[1] or ""
        end)
        if ok then typeName = name end
    end
    if self.ieAutoMirrorType then
        self.ieAutoMirrorType:SetText(typeName)
        if locked then
            self.ieAutoMirrorType:SetTextColor(gr, gg, gb)
        else
            self.ieAutoMirrorType:SetTextColor(nr, ng, nb)
        end
    end

    -- creatore ("Created by X")
    if self.ieAutoMirrorCreator then
        local creator = link.creator
        if creator and creator ~= "" then
            local fmt = CALENDAR_EVENT_CREATORNAME or L["Created by %s"]
            self.ieAutoMirrorCreator:SetFormattedText(fmt, creator)
        else
            self.ieAutoMirrorCreator:SetText("")
        end
        if locked then
            self.ieAutoMirrorCreator:SetTextColor(gr, gg, gb)
        else
            self.ieAutoMirrorCreator:SetTextColor(nr, ng, nb)
        end
    end

    -- data (FULLDATE: "weekday, month day, year")
    if self.ieAutoMirrorDate then
        if FULLDATE then
            self.ieAutoMirrorDate:SetFormattedText(FULLDATE,
                CalWeekdayName(link.weekday), CalFullDateMonthName(link.month), link.day or 0, link.year or 0)
        else
            self.ieAutoMirrorDate:SetText(self:CalendarFullDate(link.weekday, link.month, link.day, link.year))
        end
        self.ieAutoMirrorDate:SetTextColor(hr, hg, hb)
    end

    -- ora (GameTime_GetFormattedTime)
    if self.ieAutoMirrorTime then
        self.ieAutoMirrorTime:SetText(self:CalendarFormattedTime(link.hour, link.minute))
        self.ieAutoMirrorTime:SetTextColor(hr, hg, hb)
    end

    -- descrizione
    if self.ieAutoMirrorDesc then
        self.ieAutoMirrorDesc:SetText(link.description or "")
        if locked then
            self.ieAutoMirrorDesc:SetTextColor(gr, gg, gb)
        else
            self.ieAutoMirrorDesc:SetTextColor(nr, ng, nb)
        end
        if self.ieAutoMirrorDescContent and self.ieAutoMirrorDesc.GetStringHeight then
            self.ieAutoMirrorDescContent:SetHeight(math.max(self.ieAutoMirrorDesc:GetStringHeight(), 1))
        end
    end

    self:RenderAutoinviteMirrorInvites(link)
end
-- Svuota l'elenco invitati del mirror.
function GM:ClearAutoinviteMirrorInvites()
    for _, row in ipairs(self._autoMirrorInviteRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self._autoMirrorInviteRows = {}
end

-- Nome localizzato dello stato di un invitato (come il calendario di gioco).
-- Nome localizzato dello stato di un invitato (CALENDAR_STATUS_*, come il
-- calendario di gioco).
local function InviteStatusText(status)
    local names = {
        [1] = CALENDAR_STATUS_INVITED or L["Invited"],
        [2] = CALENDAR_STATUS_ACCEPTED or L["Accepted"],
        [3] = CALENDAR_STATUS_DECLINED or L["Declined"],
        [4] = CALENDAR_STATUS_CONFIRMED or L["Confirmed"],
        [5] = CALENDAR_STATUS_OUT or L["Out"],
        [6] = CALENDAR_STATUS_STANDBY or L["Standby"],
        [7] = CALENDAR_STATUS_SIGNEDUP or L["Signed up"],
        [8] = CALENDAR_STATUS_NOT_SIGNEDUP or L["Not signed up"],
        [9] = CALENDAR_STATUS_TENTATIVE or L["Tentative"],
    }
    return names[tonumber(status) or 1] or names[1]
end

-- Colore dello stato, identico al calendario di gioco (font color globali).
local function InviteStatusColor(status)
    local globals = {
        [1] = "NORMAL_FONT_COLOR", [2] = "GREEN_FONT_COLOR", [3] = "RED_FONT_COLOR",
        [4] = "GREEN_FONT_COLOR", [5] = "RED_FONT_COLOR", [6] = "ORANGE_FONT_COLOR",
        [7] = "GREEN_FONT_COLOR", [8] = "NORMAL_FONT_COLOR", [9] = "ORANGE_FONT_COLOR",
    }
    local key = globals[tonumber(status) or 1] or "NORMAL_FONT_COLOR"
    local c = _G[key]
    if c then return c.r, c.g, c.b end
    local fallback = {
        [1] = { 1, 1, 1 }, [2] = { 0, 1, 0 }, [3] = { 1, 0.1, 0.1 },
        [4] = { 0, 1, 0 }, [5] = { 1, 0.1, 0.1 }, [6] = { 1, 0.5, 0.25 },
        [7] = { 0, 1, 0 }, [8] = { 1, 1, 1 }, [9] = { 1, 0.5, 0.25 },
    }
    local f = fallback[tonumber(status) or 1] or { 1, 1, 1 }
    return f[1], f[2], f[3]
end
function GM:RenderAutoinviteMirrorInvites(link)
    self:ClearAutoinviteMirrorInvites()
    if not self.ieAutoMirrorInviteContent then return end
    local content = self.ieAutoMirrorInviteContent
    local y = 0
    for _, invite in ipairs(link.invitees or {}) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(240, 16)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)

        local modIcon = row:CreateTexture(nil, "OVERLAY")
        modIcon:SetSize(14, 14)
        modIcon:SetPoint("LEFT", row, "LEFT", 0, 0)
        if invite.mod == "CREATOR" then
            modIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            modIcon:Show()
        elseif invite.mod == "MODERATOR" then
            modIcon:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
            modIcon:Show()
        else
            modIcon:SetTexture()
            modIcon:Hide()
        end

        -- nome + classe colorati come RAID_CLASS_COLORS (come Blizzard)
        local classFilename = invite.class
        local r, g, b = CalClassColor(classFilename)

        local nameFS = FontStr(row, "OVERLAY", 12)
        nameFS:SetPoint("LEFT", row, "LEFT", 16, 0)
        nameFS:SetWidth(120)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetText(invite.name)
        nameFS:SetTextColor(r, g, b)

        local classFS = FontStr(row, "OVERLAY", 11)
        classFS:SetPoint("LEFT", nameFS, "RIGHT", 4, 0)
        classFS:SetText(invite.className or "")
        classFS:SetTextColor(r, g, b)

        local statusFS = FontStr(row, "OVERLAY", 11)
        statusFS:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        local sr, sg, sb = InviteStatusColor(invite.status)
        statusFS:SetTextColor(sr, sg, sb)
        statusFS:SetText(InviteStatusText(invite.status))

        table.insert(self._autoMirrorInviteRows, row)
        y = y - 17
    end
    content:SetHeight(math.max(-y + 2, 10))
    if self.ieAutoMirrorInviteList and self.ieAutoMirrorInviteList.UpdateScrollChildRect then
        self.ieAutoMirrorInviteList:UpdateScrollChildRect()
    end
end
-- Costruisce la lista dei nomi da invitare per la modalita' corrente.
function GM:BuildAutoinviteQueue()
    local db = self.autoinvite
    local queue = {}
    if db.mode == "calendar" then
        local link = db.linkedEvent
        if link then
            for _, invite in ipairs(link.invitees or {}) do
                -- CALENDAR_INVITESTATUS_DECLINED == 3
                if invite.name and invite.name ~= "" and invite.status ~= 3 then
                    queue[#queue + 1] = invite.name
                end
            end
        end
    else
        local names = db.names
        if type(names) ~= "table" then names = {} end
        for _, name in ipairs(names) do
            if name and name ~= "" and name ~= "-" then
                queue[#queue + 1] = name
            end
        end
    end
    return queue
end

-- Legge HH:MM dai campi e li salva.
function GM:ReadAutoinviterTime()
    local db = self.autoinvite
    local h = tonumber(self.ieAutoHourEdit and self.ieAutoHourEdit:GetText()) or db.hour or 19
    local m = tonumber(self.ieAutoMinuteEdit and self.ieAutoMinuteEdit:GetText()) or db.minute or 0
    if h < 0 then h = 0 elseif h > 23 then h = 23 end
    if m < 0 then m = 0 elseif m > 59 then m = 59 end
    db.hour = h
    db.minute = m
end

function GM:ToggleAutoinviter()
    if self.autoinviteActive then
        self:StopAutoinviter()
    else
        self:StartAutoinviter()
    end
end

-- Arma l'autoinviter: prepara la coda e avvia il timer AceTimer (1s).
function GM:StartAutoinviter()
    if self.autoinviteActive then return end
    local db = self.autoinvite
    self:ReadAutoinviterTime()

    local queue = self:BuildAutoinviteQueue()
    if #queue == 0 then
        RLSuite.utils:Print(L["Autoinviter: no names to invite."])
        return
    end

    self.autoinviteQueue = queue
    self.autoinviteIndex = 0
    local target = (db.hour or 19) * 60 + (db.minute or 0)
    local h, m = GetGameTime()
    local now = h * 60 + m
    if target <= now then
        -- Ora gia' passata: si parte subito.
        self.autoinviteState = "inviting"
        self.autoinviteTarget = now
    else
        self.autoinviteState = "waiting"
        self.autoinviteTarget = target
    end
    self.autoinviteActive = true
    db.enabled = true

    if self.ScheduleRepeatingTimer then
        self.autoinviteTimer = self:ScheduleRepeatingTimer("AutoinviterTick", 1)
    end

    self:RefreshAutoinviterStatus()
    self:RefreshAutoinviterArmButton()
    RLSuite.utils:Print(string.format(L["Autoinviter armed: %d names."], #queue))
end

-- Ferma l'autoinviter (cancella il timer AceTimer).
function GM:StopAutoinviter()
    if self.autoinviteTimer and self.CancelTimer then
        self:CancelTimer(self.autoinviteTimer)
    end
    self.autoinviteTimer = nil
    self.autoinviteActive = false
    self.autoinviteState = nil
    self.autoinviteQueue = nil
    if self.autoinvite then self.autoinvite.enabled = false end
    self:SaveAutoinviter()
    self:RefreshAutoinviterStatus()
    self:RefreshAutoinviterArmButton()
end

-- Tick del timer AceTimer: attende l'orario, poi invita uno alla volta.
function GM:AutoinviterTick()
    if not self.autoinviteActive then
        self:StopAutoinviter()
        return
    end
    if self.autoinviteState == "waiting" then
        local h, m = GetGameTime()
        local now = h * 60 + m
        if now >= (self.autoinviteTarget or 0) then
            self.autoinviteState = "inviting"
            self.autoinviteIndex = 0
        else
            self:RefreshAutoinviterStatus()
            return
        end
    end
    if self.autoinviteState == "inviting" then
        self.autoinviteIndex = (self.autoinviteIndex or 0) + 1
        local name = self.autoinviteQueue and self.autoinviteQueue[self.autoinviteIndex]
        if name then
            self:InviteAutoName(name)
            self:RefreshAutoinviterStatus()
        else
            RLSuite.utils:Print(L["Autoinviter: all invites sent."])
            self:StopAutoinviter()
        end
    end
end

-- Invita un singolo nome (in debug il giocatore fittizio accetta subito).
function GM:InviteAutoName(name)
    if not name then return end
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        RLSuite.utils:Print("[DBG] Autoinvite " .. name)
        local class = nil
        for _, e in ipairs(self.whisperDB.entries or {}) do
            if e.name == name and e.class then class = e.class break end
        end
        RLSuite:DebugInviteAccept(name, class)
        return
    end
    if InviteUnit then InviteUnit(name) end
end

-- Salva lo stato dell'autoinviter nel DB (il flag enabled non deve
-- sopravvivere al reload: il timer non esiste piu' dopo un riavvio).
function GM:SaveAutoinviter()
    local db = self.autoinvite
    if not db then return end
    if type(db.names) ~= "table" then db.names = {} end
    db.enabled = self.autoinviteActive and true or false
end

-- ============================================================
-- Lista manuale: aggiunta/rimozione nomi e relativa UI.
-- ============================================================
function GM:AutoNameList()
    local db = self.autoinvite
    if not db then return {} end
    if type(db.names) ~= "table" then db.names = {} end
    return db.names
end

-- Invio nel campo nome = il nome entra nella lista.
function GM:AddAutoName(name)
    name = (name or ""):match("^%s*(.-)%s*$") or ""
    name = name:gsub("%s+", "")
    if name == "" then return end
    local names = self:AutoNameList()
    for _, n in ipairs(names) do
        if n == name then
            if self.ieAutoNamesEdit then self.ieAutoNamesEdit:SetText("") end
            return
        end
    end
    names[#names + 1] = name
    if self.ieAutoNamesEdit then self.ieAutoNamesEdit:SetText("") end
    self:BuildAutoNameListUI()
    self:SaveAutoinviter()
    self:RefreshAutoinviterStatus()
end

-- Clic destro su un nome della lista = rimozione.
function GM:RemoveAutoName(name)
    local names = self:AutoNameList()
    for i, n in ipairs(names) do
        if n == name then
            table.remove(names, i)
            break
        end
    end
    self:BuildAutoNameListUI()
    self:SaveAutoinviter()
    self:RefreshAutoinviterStatus()
end

-- Ricostruisce le righe dell'elenco manuale (una riga per nome).
function GM:BuildAutoNameListUI()
    if not self.ieAutoNamesContent then return end
    local content = self.ieAutoNamesContent
    for _, row in ipairs(self._autoNameRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self._autoNameRows = {}

    local names = self:AutoNameList()
    local y = 0
    for i, name in ipairs(names) do
        local row = CreateFrame("Button", nil, content)
        row:SetSize(220, 16)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local text = FontStr(row, "OVERLAY", 12)
        text:SetPoint("LEFT", row, "LEFT", 4, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -22, 0)
        text:SetJustifyH("LEFT")
        text:SetText(name)
        text:SetTextColor(1, 1, 1)
        row.text = text
        row.name = name

        -- "x" in fondo alla barra: rimuove il giocatore dalla lista.
        local xBtn = CreateFrame("Button", nil, row)
        xBtn:SetSize(16, 16)
        xBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        xBtn:SetScript("OnClick", function()
            self:RemoveAutoName(name)
        end)
        row.xBtn = xBtn
        local xText = FontStr(xBtn, "OVERLAY", 12)
        xText:SetPoint("CENTER", xBtn, "CENTER", 0, 0)
        xText:SetText("x")
        xText:SetTextColor(0.8, 0.2, 0.2)
        xBtn:SetScript("OnEnter", function() xText:SetTextColor(1, 0.3, 0.3) end)
        xBtn:SetScript("OnLeave", function() xText:SetTextColor(0.8, 0.2, 0.2) end)

        -- clic destro sull'intera riga = rimozione (compatibilita').
        row:SetScript("OnClick", function(s, button)
            if button == "RightButton" then
                self:RemoveAutoName(s.name)
            end
        end)
        row:SetScript("OnEnter", function(s)
            s.text:SetTextColor(1, 0.82, 0)
        end)
        row:SetScript("OnLeave", function(s)
            s.text:SetTextColor(1, 1, 1)
        end)

        table.insert(self._autoNameRows, row)
        y = y - 17
    end

    content:SetHeight(math.max(-y + 2, 10))
    if self.ieAutoNamesScroll and self.ieAutoNamesScroll.UpdateScrollChildRect then
        self.ieAutoNamesScroll:UpdateScrollChildRect()
    end
end

-- "Auto invite now": invita subito tutta la lista, senza aspettare l'ora.
function GM:AutoInviteNow()
    local db = self.autoinvite
    if not db then return end
    local queue = self:BuildAutoinviteQueue()
    if #queue == 0 then
        RLSuite.utils:Print(L["Autoinviter: no names to invite."])
        return
    end
    RLSuite.utils:Print(string.format(L["Autoinviter: inviting %d names now."], #queue))
    for _, name in ipairs(queue) do
        self:InviteAutoName(name)
    end
end

function GM:RefreshAutoinviterStatus()
    if not self.ieAutoStatus then return end
    if self.autoinviteState == "waiting" then
        local h, m = GetGameTime()
        local now = h * 60 + m
        local left = math.max(0, (self.autoinviteTarget or now) - now)
        self.ieAutoStatus:SetText(string.format(L["Armed: inviting in %d:%02d (%d names)"],
            math.floor(left / 60), left % 60, #(self.autoinviteQueue or {})))
    elseif self.autoinviteState == "inviting" then
        self.ieAutoStatus:SetText(string.format(L["Inviting %d/%d..."],
            self.autoinviteIndex or 0, #(self.autoinviteQueue or {})))
    else
        self.ieAutoStatus:SetText("")
    end
end

function GM:RefreshAutoinviterArmButton()
    if not self.ieAutoArmBtn then return end
    if self.autoinviteActive then
        self.ieAutoArmBtn:SetText(L["Stop Autoinviter"])
    else
        self.ieAutoArmBtn:SetText(L["Start Autoinviter"])
    end
end

function GM:BuildWLGroupColumns()
    self.wlGroupLabels = {}
    self.wlGroupSlots = {}
    local box = self.wlGroupBox
    for g = 1, 5 do
        local lbl = FontStr(box, "OVERLAY", 12)
        lbl:SetText("G" .. g)
        lbl:SetTextColor(1, 0.82, 0)
        lbl:SetJustifyH("CENTER")
        self.wlGroupLabels[g] = lbl

        for s = 1, 5 do
            local i = (g - 1) * 5 + s
            -- Ogni slot e' un Button con dimensione e sfondo ESPLICITI, creato
            -- direttamente dentro il box (niente frame "colonna" intermedi che
            -- potevano restare non posizionati/nascosti). Stesso pattern delle
            -- righe del Raid Frame, che funziona: slot scuro + bordo visibile.
            local bar = CreateFrame("Button", "RLSuiteWLSlot" .. i, box)
            bar:SetSize(50, WL_BAR_H)
            bar:SetBackdrop({
                bgFile = "Interface\\Buttons\\UI-Quickslot",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, tileSize = 32, edgeSize = 8,
                insets = {left=2, right=2, top=2, bottom=2},
            })
            bar:SetBackdropColor(0.15, 0.15, 0.17, 0.95)
            bar:SetBackdropBorderColor(0.40, 0.40, 0.42, 1)
            bar:EnableMouse(true)

            -- Nome in colore di classe su slot scuro (come il Raid Frame):
            -- sempre leggibile, con ombra chiara per i colori piu' scuri.
            local nameFS = FontStr(bar, "OVERLAY", 11)
            nameFS:SetPoint("LEFT", bar, "LEFT", 3, 0)
            nameFS:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
            nameFS:SetJustifyH("CENTER")
            nameFS:SetTextColor(1, 1, 1)
            nameFS:SetShadowColor(1, 1, 1, 0.8)
            nameFS:SetShadowOffset(1, -1)
            bar.nameFS = nameFS

            self.wlGroupSlots[i] = bar
        end
    end
    self:UpdateWLGroups()
end

-- Popola il pannello Raid Group dal raid REALE (non dalla comp di
-- Groupmaking, che e' quella "ideale" aggiornata a mano dal RL per lo
-- spammer). Ogni giocatore finisce nella colonna del suo sottogruppo.
-- In debug mode legge invece il roster simulato (Core), cosi' un invito
-- fittizio accettato appare subito qui come farebbe un invito vero.
function GM:UpdateWLGroups()
    if not self.wlGroupSlots then return end

    local byGroup = { {}, {}, {}, {}, {} }
    local num = 0
    local debugMode = RLSuite.DebugMode and RLSuite:DebugMode()
    if debugMode then
        -- Roster simulato: i sottogruppi sono assegnati da Core.
        local ngroups = self:WlGroupColumnCount()
        RLSuite:DebugRebalanceGroups(ngroups)
        for _, m in ipairs(RLSuite:DebugRoster()) do
            local subgroup = tonumber(m.subgroup) or 1
            if subgroup < 1 then subgroup = 1 end
            if subgroup > 5 then subgroup = 5 end
            table.insert(byGroup[subgroup], { name = m.name, class = m.class or "WARRIOR" })
        end
    elseif IsInRaid and IsInRaid() and GetNumRaidMembers then
        num = GetNumRaidMembers()
    end
    if not debugMode then
        for i = 1, num do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name then
                local class = "WARRIOR"
                if UnitClass then
                    local _, classFile = UnitClass("raid" .. i)
                    if classFile then class = classFile end
                end
                subgroup = tonumber(subgroup) or 1
                if subgroup < 1 then subgroup = 1 end
                if subgroup > 5 then subgroup = 5 end
                table.insert(byGroup[subgroup], { name = name, class = class })
            end
        end
    end

    -- Numero di colonne dalla difficolta' di Groupmaking (2 per il 10, 5 per il 25).
    local ngroups = self:WlGroupColumnCount()

    for g = 1, 5 do
        for s = 1, 5 do
            local bar = self.wlGroupSlots[(g - 1) * 5 + s]
            if bar then
                local member = byGroup[g][s]
                if g <= ngroups then
                    bar:Show()
                else
                    bar:Hide()
                end
                if member then
                    local r, gg, b = RLSuite.utils:GetClassColor(member.class)
                    -- Slot pieno: bordo in colore di classe e nome in colore
                    -- di classe su fondo scuro (leggibile su qualsiasi colore).
                    bar:SetBackdropColor(0.16, 0.16, 0.18, 0.95)
                    bar:SetBackdropBorderColor(r, gg, b, 1)
                    if bar.nameFS then
                        bar.nameFS:SetText(member.name)
                        bar.nameFS:SetTextColor(r, gg, b)
                        bar.nameFS:Show()
                    end
                else
                    -- Slot vuoto: fondo scuro + bordo grigio (comunque visibile).
                    bar:SetBackdropColor(0.12, 0.12, 0.14, 0.95)
                    bar:SetBackdropBorderColor(0.30, 0.30, 0.32, 1)
                    if bar.nameFS then bar.nameFS:SetText("") end
                end
            end
        end
    end
    self:LayoutWLGroupColumns(ngroups)

    -- Diagnostica (solo debug): stampa UNA riga quando il contenuto del
    -- pannello cambia, cosi' in gioco si vede subito se/quanti giocatori
    -- sono stati piazzati nelle colonne.
    if debugMode then
        local names = {}
        for _, m in ipairs(RLSuite:DebugRoster()) do
            names[#names + 1] = m.name
        end
        local summary = table.concat(names, ", ")
        if summary ~= self._lastWLSummary then
            self._lastWLSummary = summary
            if RLSuite.utils and RLSuite.utils.Print then
                RLSuite.utils:Print("|cffffff00[Raid Group]|r " .. #names .. " membri: " .. summary)
            end
        end
    else
        self._lastWLSummary = nil
    end
end

-- Numero di colonne del pannello Raid Group dalla difficolta' di Groupmaking.
function GM:WlGroupColumnCount()
    local numSlots = tonumber(self.db.difficulty or "10") or 10
    local ngroups = math.ceil(numSlots / 5)
    if ngroups < 2 then ngroups = 2 end
    if ngroups > 5 then ngroups = 5 end
    return ngroups
end

-- Posiziona le colonne (una per gruppo raid) e le barre verticali al loro
-- interno, dentro il riquadro Raid Group.
function GM:LayoutWLGroupColumns(ngroups)
    local box = self.wlGroupBox
    if not box then return end
    box:Show()
    ngroups = ngroups or 5
    local w = box:GetWidth() or 0
    local inner = w - 12
    local colW = math.floor((inner - (ngroups - 1) * WL_COL_GAP) / ngroups)
    if colW > 100 then colW = 100 end
    if colW < 50 then colW = 50 end
    local totalW = ngroups * colW + (ngroups - 1) * WL_COL_GAP
    local startX = 6 + math.floor(math.max(0, (inner - totalW) / 2))
    for g = 1, 5 do
        local x = startX + (g - 1) * (colW + WL_COL_GAP)
        local lbl = self.wlGroupLabels and self.wlGroupLabels[g]
        if lbl then
            lbl:ClearAllPoints()
            lbl:SetWidth(colW)
            lbl:SetPoint("TOPLEFT", box, "TOPLEFT", x, -24)
            if g <= ngroups then lbl:Show() else lbl:Hide() end
        end
        for s = 1, 5 do
            local bar = self.wlGroupSlots and self.wlGroupSlots[(g - 1) * 5 + s]
            if bar then
                bar:ClearAllPoints()
                bar:SetSize(colW, WL_BAR_H)
                local y = -24 - WL_GROUP_LABEL_H - (s - 1) * (WL_BAR_H + WL_BAR_GAP)
                bar:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
            end
        end
    end
    box:SetHeight(24 + WL_GROUP_LABEL_H + 5 * WL_BAR_H + 4 * WL_BAR_GAP + 8)
end

function GM:OpenWhisplist()
    if not self.whisplistFrame then return end
    self:SyncWhisplistHeight()
    if self.mainFrame and not self.mainFrame:IsShown() then
        self.mainFrame:Show()
    end
    if not self.whisplistFrame:IsShown() then
        self.whisplistFrame:Show()
    end
    self:UpdateWhisplist()
    self:UpdateWLGroups()
    if self.ieActiveTab == "auto" then
        self:RefreshAutoinviter()
    end
    RLSuite.utils:RaiseWindow(self.mainFrame)
end

function GM:ToggleWhisplist()
    if self.whisplistFrame and self.whisplistFrame:IsShown() then
        self.whisplistFrame:Hide()
    elseif self.whisplistFrame then
        self:OpenWhisplist()
    end
end

function GM:SkinInner()
    local u = RLSuite.utils
    if self.whisplistFrame then u:SkinFrame(self.whisplistFrame) end
    u:SkinBox(self.compBox)
    u:SkinBox(self.classBox)
    u:SkinBox(self.reqBox)
    u:SkinBox(self.previewBox)
    u:SkinBox(self.wlGroupBox)
    u:SkinBox(self.wlListBox)
    u:SkinBox(self.wlDetailBox)
    u:SkinBox(self.wlChat)
    if self.ieAutoManualBox then u:SkinBox(self.ieAutoManualBox) end
    if self.ieAutoCalBox then u:SkinBox(self.ieAutoCalBox) end
end

-- Crea (una sola volta) una riga della Whisplist. Le righe vengono RIUSATE:
-- un bottone non viene MAI distrutto durante il click. Distruggere il frame
-- cliccato dentro l'OnClick lascia il client con lo stato del mouse "morto"
-- e le righe successive smettono di rispondere ai click (questo e' il bug
-- dei nomi non cliccabili). L'handler legge SEMPRE l'entry corrente dal
-- frame (s.entry), mai da una variabile catturata nel loop.
function GM:CreateWhisperRow()
    local row = CreateFrame("Button", nil, self.wlContent)
    row:SetHeight(24)
    row:EnableMouse(true)
    if row.SetMouseClickEnabled then row:SetMouseClickEnabled(true) end
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local text = FontStr(row, "OVERLAY", 12)
    text:SetPoint("LEFT", row, "LEFT", 6, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    text:SetJustifyH("LEFT")
    row.text = text

    row:SetScript("OnClick", function(s, button)
        if button == "RightButton" then
            -- Debug mode: il clic destro elimina il giocatore senza
            -- inviare il messaggio di decline.
            if RLSuite.DebugMode and RLSuite:DebugMode() then
                self:QueueRemoveWhisperEntry(s.entry)
            end
            return
        end
        self:SelectWhisperEntryByRef(s.entry)
    end)
    return row
end

function GM:UpdateWhisplist()
    if not self.wlContent then return end
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    if self.SkinInner then self:SkinInner() end

    -- Pool di righe riusate: le righe non vengono piu' distrutte e ricreate,
    -- vengono solo riposizionate e riempite di nuovi dati. Il pool cresce
    -- fino al massimo numero di giocatori mai mostrato e poi viene riciclato.
    self.wlRowPool = self.wlRowPool or {}
    local pool = self.wlRowPool
    local active = {}

    if self.wlScroll then
        local w = self.wlScroll:GetWidth()
        if w and w > 40 then self.wlContent:SetWidth(w) end
    end

    local entries = self.whisperDB.entries or {}

    -- Selezione per riferimento: sopravvive a riordini e aggregazioni.
    local selectedIndex
    for i, e in ipairs(entries) do
        if e == self.selectedEntry then
            selectedIndex = i
            break
        end
    end
    self.selectedEntryIndex = selectedIndex

    local y = 0
    for i, entry in ipairs(entries) do
        local row = pool[i] or self:CreateWhisperRow()
        pool[i] = row
        row:ClearAllPoints()
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", self.wlContent, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", self.wlContent, "TOPRIGHT", 0, -y)
        row.entry = entry

        local info = entry.name or "Unknown"
        if entry.class then
            info = info .. " (" .. string.sub(entry.class, 1, 1) .. string.lower(string.sub(entry.class, 2)) .. ")"
        end
        if entry.gs then info = info .. " GS:" .. entry.gs end
        local n = #self:GetEntryMessages(entry)
        if n > 1 then info = info .. "  [" .. n .. "]" end
        if row.text then row.text:SetText(info) end
        row:Show()

        active[#active + 1] = row
        y = y + 26
    end

    -- Righe in eccesso: nascoste (e non piu' cliccabili) ma NON distrutte.
    for i = #entries + 1, #pool do
        local row = pool[i]
        if row then
            row:Hide()
            row.entry = nil
        end
    end

    self.wlRows = active
    self.wlContent:SetHeight(math.max(y, 1))
    self:StyleWhisperRows()
end

-- Seleziona una riga per RIFERIMENTO (non per indice): l'indice viene
-- risolto al momento del click, cosi' una lista riordinata non attiva la
-- riga sbagliata.
function GM:SelectWhisperEntryByRef(entry)
    if not entry then return end
    local entries = self.whisperDB.entries or {}
    for i, e in ipairs(entries) do
        if e == entry then
            self:SelectWhisperEntry(i)
            return
        end
    end
end

-- Rimozione "sicura" dal clic destro: i dati escono subito dalla lista,
-- la UI viene ricostruita al tick successivo. Ricostruire i frame dentro
-- il click distrugge il bottone cliccato e blocca i click successivi.
function GM:QueueRemoveWhisperEntry(entry)
    if not entry then return end
    local entries = self.whisperDB.entries or {}
    for i, e in ipairs(entries) do
        if e == entry then
            table.remove(entries, i)
            break
        end
    end
    if self.selectedEntry == entry then
        self.selectedEntry = nil
        self.selectedEntryIndex = nil
        if self.wlDetailName then self.wlDetailName:SetText(L["Select a player"]) end
        if self.wlDetailInfo then self.wlDetailInfo:SetText("") end
        if self.wlChatText then self.wlChatText:SetText("") end
    end
    self._wlRebuildPending = true
    if not self._wlRebuildTimer then
        self._wlRebuildTimer = self:ScheduleTimer("FlushWhisperRebuild", 0.05)
    end
end

function GM:FlushWhisperRebuild()
    self._wlRebuildTimer = nil
    self._wlRebuildPending = nil
    self:UpdateWhisplist()
end

-- Stile delle righe dei giocatori: riga selezionata evidenziata, righe con
-- messaggi non letti con l'accento dorato "pulsante" stile Blizzard. Il
-- lampeggio ora e' un singolo timer AceTimer-3.0 (prima: OnUpdate per riga).
function GM:StyleWhisperRows()
    local anyUnread = false
    for i, row in ipairs(self.wlRows or {}) do
        local entry = row.entry
        local isSelected = (i == self.selectedEntryIndex)
        if isSelected then
            RLSuite.utils:SkinRow(row, true)
            if row.text then row.text:SetTextColor(1, 1, 1) end
        elseif entry and entry.unread then
            anyUnread = true
            RLSuite.utils:SkinRow(row, false)
            row:SetBackdropColor(0.22, 0.16, 0.02, 0.95)
            row:SetBackdropBorderColor(1, 0.82, 0, 1)
            if row.text then row.text:SetTextColor(1, 0.82, 0) end
        else
            RLSuite.utils:SkinRow(row, false)
            if row.text then
                if entry and entry.invited then
                    row.text:SetTextColor(0.5, 0.5, 0.5)
                else
                    row.text:SetTextColor(1, 1, 1)
                end
            end
        end
    end

    -- Un solo timer di lampeggio per tutte le righe non lette.
    if anyUnread then
        if not self.wlPulseTimer then
            self.wlPulseTimer = self:ScheduleRepeatingTimer("PulseUnreadRows", 0.1)
        end
    elseif self.wlPulseTimer then
        self:CancelTimer(self.wlPulseTimer)
        self.wlPulseTimer = nil
    end
end

function GM:PulseUnreadRows()
    local v = (math.sin((GetTime() or 0) * 5) + 1) / 2
    for i, row in ipairs(self.wlRows or {}) do
        if row.entry and row.entry.unread and i ~= self.selectedEntryIndex then
            row:SetBackdropBorderColor(0.45 + 0.55 * v, 0.32 + 0.50 * v, 0.05, 1)
        end
    end
end

-- Riempi il riquadro messaggi con la cronologia completa del giocatore
-- selezionato e scorri in fondo (i messaggi piu' recenti, come la chat).
function GM:RenderSelectedMessages()
    if not self.selectedEntry or not self.wlChatText then return end
    local lines = {}
    for _, m in ipairs(self:GetEntryMessages(self.selectedEntry)) do
        table.insert(lines, "[" .. FormatWhisperTime(m.time) .. "] " .. (m.msg or ""))
    end
    self.wlChatText:SetText(table.concat(lines, "\n"))
    if self.wlChatContent and self.wlChatText.GetStringHeight then
        self.wlChatContent:SetHeight(math.max(self.wlChatText:GetStringHeight(), 1))
    end
    if self.wlChatScroll and self.wlChatScroll.SetVerticalScroll then
        local range = 0
        if self.wlChatScroll.GetVerticalScrollRange then
            local ok, r = pcall(self.wlChatScroll.GetVerticalScrollRange, self.wlChatScroll)
            if ok and type(r) == "number" then range = r end
        end
        self.wlChatScroll:SetVerticalScroll(range)
    end
end

function GM:SelectWhisperEntry(index)
    local entries = self.whisperDB.entries or {}
    local entry = entries[index]
    if not entry then return end
    self.selectedEntry = entry
    self.selectedEntryIndex = index
    entry.unread = false

    if self.wlDetailName then self.wlDetailName:SetText(entry.name or "Unknown") end
    local info = ""
    if entry.class then info = info .. "Class: " .. entry.class .. "\n" end
    if entry.role then info = info .. "Role: " .. entry.role .. "\n" end
    if entry.spec then info = info .. "Spec: " .. entry.spec .. "\n" end
    if entry.gs then info = info .. "GS: " .. entry.gs .. "\n" end
    if self.wlDetailInfo then self.wlDetailInfo:SetText(info) end

    self:RenderSelectedMessages()
    self:StyleWhisperRows()
end

-- Aggiorna solo l'evidenziazione delle righe gia' presenti (niente rebuild):
-- ricostruire la lista dentro il click distrugge il bottone cliccato e
-- puo' bloccare i click successivi nelle altre finestre.
function GM:RefreshWhisperHighlight()
    self:StyleWhisperRows()
end

function GM:InviteSelected()
    if not self.selectedEntry then return end
    local name = self.selectedEntry.name
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        RLSuite.utils:Print("[DBG] Invite " .. (name or "?"))
        -- Il giocatore fittizio accetta subito: entra nel roster simulato e
        -- Raid Group + Raid Frame si aggiornano come con un invito vero.
        RLSuite:DebugInviteAccept(name, self.selectedEntry.class)
        self.selectedEntry.invited = true
        self:UpdateWhisplist()
        return
    end
    InviteUnit(name)
    self.selectedEntry.invited = true
    self:UpdateWhisplist()
end

function GM:AskGS()
    if not self.selectedEntry then return end
    RLSuite.utils:Whisper(self.selectedEntry.name, "What's your GS?")
end

function GM:AskAchi()
    if not self.selectedEntry then return end
    RLSuite.utils:Whisper(self.selectedEntry.name, "Do you have the achievement for this raid?")
end

-- Rimuove una entry (dati + riga) da Received whispers; se era la entry
-- selezionata pulisce anche il pannello dei dettagli.
function GM:RemoveWhisperEntry(entry)
    if not entry then return end
    local entries = self.whisperDB.entries or {}
    for i, e in ipairs(entries) do
        if e == entry then
            table.remove(entries, i)
            break
        end
    end
    if self.selectedEntry == entry then
        self.selectedEntry = nil
        self.selectedEntryIndex = nil
        if self.wlDetailName then self.wlDetailName:SetText(L["Select a player"]) end
        if self.wlDetailInfo then self.wlDetailInfo:SetText("") end
        if self.wlChatText then self.wlChatText:SetText("") end
    end
    self:UpdateWhisplist()
end

-- Decline: avvisa il giocatore che non e' stato preso e rimuove la sua
-- entry (con tutta la cronologia) da Received whispers.
function GM:DeclineSelected()
    if not self.selectedEntry then return end
    local name = self.selectedEntry.name
    RLSuite.utils:Whisper(name, "Sorry, you have not been selected for this raid.")
    self:RemoveWhisperEntry(self.selectedEntry)
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
        RLSuite.utils:Print(L["Slot already taken!"])
        return
    end
    local class = entry.class or slot.class
    if not class then
        RLSuite.utils:Print(string.format(L["Class not recognized for %s"], (entry.name or "?")))
        return
    end
    local spec = entry.spec or slot.spec
    local role = RLSuite.utils:RoleFromSpec(class, spec) or entry.role or slot.role or "dps"
    self:FillSlot(slotIndex, class, role, entry.name, spec)
    entry.invited = true
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        RLSuite.utils:Print("[DBG] Invite " .. (entry.name or "?") .. " slot " .. slotIndex)
        RLSuite:DebugInviteAccept(entry.name, class)
    else
        InviteUnit(entry.name)
    end
    self:UpdateWhisplist()
    self:UpdateMessagePreview()
    RLSuite.utils:Print(string.format(L["%s invited to slot %d"], (entry.name or "?"), slotIndex))
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
    if self.aimEdit then self.aimEdit:SetText(self.db.aim or "") end
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
    if self.aimEdit then
        self.db.aim = self.aimEdit:GetText() or ""
    end
    if self.otherEdit then
        self.db.otherReq = self.otherEdit:GetText() or ""
    end
end
