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
    ai.names = ai.names or ""
    ai.hour = ai.hour or 19
    ai.minute = ai.minute or 0
    ai.enabled = false
    self.spamActive = false
    self.compSlots = {}
    self.whisperEntries = {}
    self.selectedEntry = nil
    self.loadingComp = true
    self:EmbedAceLibraries()
    self:CreateMainWindow()
    self:CreateWhisplistWindow()
    self:LoadCompFromDB()
    self.loadingComp = false
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
            self:RefreshAutoinviterCalendar()
        end)
        self:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES", function()
            self:RefreshAutoinviterCalendar()
        end)
        self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            self:RefreshAutoinviterCalendar()
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
    RLSuite.utils:Print(L["Spammer started."])
end

function GM:StopSpam()
    self.spamActive = false
    if self.spamBtn then self.spamBtn:SetText("Start Spam") end
    if self.spamFrame then
        self.spamFrame:SetScript("OnUpdate", nil)
        self.spamFrame:Hide()
    end
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

    -- Pannello lista manuale.
    self.ieAutoManualBox = CreateFrame("Frame", nil, page)
    self.ieAutoManualBox:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -38)
    self.ieAutoManualBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", -8, -38)
    self.ieAutoManualBox:SetHeight(96)
    RLSuite.utils:SkinBox(self.ieAutoManualBox)

    local namesLbl = FontStr(self.ieAutoManualBox, "OVERLAY", 12)
    namesLbl:SetPoint("TOPLEFT", self.ieAutoManualBox, "TOPLEFT", 8, -6)
    namesLbl:SetText(L["Names (one per line)"])
    namesLbl:SetTextColor(1, 0.82, 0)

    self.ieAutoNamesEdit = CreateFrame("EditBox", "RLSuiteIEAutoNames", self.ieAutoManualBox, "InputBoxTemplate")
    self.ieAutoNamesEdit:SetMultiLine(true)
    self.ieAutoNamesEdit:SetPoint("TOPLEFT", namesLbl, "BOTTOMLEFT", 0, -6)
    self.ieAutoNamesEdit:SetPoint("BOTTOMRIGHT", self.ieAutoManualBox, "BOTTOMRIGHT", -8, 6)
    self.ieAutoNamesEdit:SetAutoFocus(false)
    self.ieAutoNamesEdit:SetMaxLetters(2048)
    self.ieAutoNamesEdit:SetScript("OnTextChanged", function()
        GM:SaveAutoinviter()
        GM:RefreshAutoinviterStatus()
    end)
    self.ieAutoNamesEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)

    -- Pannello evento di Calendario.
    self.ieAutoCalBox = CreateFrame("Frame", nil, page)
    self.ieAutoCalBox:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -38)
    self.ieAutoCalBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", -8, -38)
    self.ieAutoCalBox:SetHeight(96)
    RLSuite.utils:SkinBox(self.ieAutoCalBox)

    local eventLbl = FontStr(self.ieAutoCalBox, "OVERLAY", 12)
    eventLbl:SetPoint("TOPLEFT", self.ieAutoCalBox, "TOPLEFT", 8, -6)
    eventLbl:SetText(L["Raid event"])
    eventLbl:SetTextColor(1, 0.82, 0)

    self.ieAutoEventDropdown = RLSuite.utils:CreateDropdown(self.ieAutoCalBox, "RLSuiteIEAutoEvent", 190, 22)
    self.ieAutoEventDropdown:SetPoint("TOPLEFT", eventLbl, "BOTTOMLEFT", 0, -4)

    self.ieAutoEventRefresh = CreateFrame("Button", nil, self.ieAutoCalBox, "UIPanelButtonTemplate")
    self.ieAutoEventRefresh:SetSize(70, 22)
    self.ieAutoEventRefresh:SetPoint("LEFT", self.ieAutoEventDropdown, "RIGHT", 6, 0)
    self.ieAutoEventRefresh:SetText(L["Refresh"])
    self.ieAutoEventRefresh:SetScript("OnClick", function() self:RefreshAutoinviterCalendar() end)

    self.ieAutoEventInfo = FontStr(self.ieAutoCalBox, "OVERLAY", 12)
    self.ieAutoEventInfo:SetPoint("TOPLEFT", self.ieAutoEventDropdown, "BOTTOMLEFT", 0, -8)
    self.ieAutoEventInfo:SetPoint("RIGHT", self.ieAutoCalBox, "RIGHT", -8, 0)
    self.ieAutoEventInfo:SetJustifyH("LEFT")
    self.ieAutoEventInfo:SetText("")

    -- Ora di invito (comune alle due modalita').
    local timeLbl = FontStr(page, "OVERLAY", 12)
    timeLbl:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -144)
    timeLbl:SetText(L["Invite at"])
    timeLbl:SetTextColor(1, 0.82, 0)

    self.ieAutoHourEdit = CreateFrame("EditBox", "RLSuiteIEAutoHour", page, "InputBoxTemplate")
    self.ieAutoHourEdit:SetSize(34, 20)
    self.ieAutoHourEdit:SetPoint("LEFT", timeLbl, "RIGHT", 8, 0)
    self.ieAutoHourEdit:SetAutoFocus(false)
    self.ieAutoHourEdit:SetMaxLetters(2)
    self.ieAutoHourEdit:SetNumeric(true)
    self.ieAutoHourEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    self.ieAutoHourEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)

    local colonLbl = FontStr(page, "OVERLAY", 12)
    colonLbl:SetPoint("LEFT", self.ieAutoHourEdit, "RIGHT", 2, 0)
    colonLbl:SetText(":")

    self.ieAutoMinuteEdit = CreateFrame("EditBox", "RLSuiteIEAutoMinute", page, "InputBoxTemplate")
    self.ieAutoMinuteEdit:SetSize(34, 20)
    self.ieAutoMinuteEdit:SetPoint("LEFT", colonLbl, "RIGHT", 2, 0)
    self.ieAutoMinuteEdit:SetAutoFocus(false)
    self.ieAutoMinuteEdit:SetMaxLetters(2)
    self.ieAutoMinuteEdit:SetNumeric(true)
    self.ieAutoMinuteEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    self.ieAutoMinuteEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)

    local timeHint = FontStr(page, "OVERLAY", 12)
    timeHint:SetPoint("LEFT", self.ieAutoMinuteEdit, "RIGHT", 6, 0)
    timeHint:SetText(L["(server time)"])
    timeHint:SetTextColor(0.6, 0.6, 0.6)

    -- Bottone arma/disarma.
    self.ieAutoArmBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    self.ieAutoArmBtn:SetSize(120, 24)
    self.ieAutoArmBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -180)
    self.ieAutoArmBtn:SetText(L["Start auto-invite"])
    self.ieAutoArmBtn:SetScript("OnClick", function() self:ToggleAutoinviter() end)

    -- Stato / avanzamento.
    self.ieAutoStatus = FontStr(page, "OVERLAY", 12)
    self.ieAutoStatus:SetPoint("LEFT", self.ieAutoArmBtn, "RIGHT", 8, 0)
    self.ieAutoStatus:SetPoint("RIGHT", page, "RIGHT", -8, 0)
    self.ieAutoStatus:SetJustifyH("LEFT")
    self.ieAutoStatus:SetText("")
    self.ieAutoStatus:SetTextColor(1, 0.82, 0)
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
    if manual and self.ieAutoNamesEdit then
        self.ieAutoNamesEdit:SetText(db.names or "")
    end
    if self.ieAutoHourEdit then self.ieAutoHourEdit:SetText(string.format("%02d", db.hour or 19)) end
    if self.ieAutoMinuteEdit then self.ieAutoMinuteEdit:SetText(string.format("%02d", db.minute or 0)) end

    if not manual then self:RefreshAutoinviterCalendar() end
    self:RefreshAutoinviterStatus()
    self:RefreshAutoinviterArmButton()
end

-- Elenca gli eventi RAID di oggi (tipo CALENDAR_EVENTTYPE_RAID == 1).
function GM:GetTodayRaidEvents()
    local events = {}
    if not CalendarGetNumDayEvents or not CalendarGetDate then return events end
    local weekday, month, day, year = CalendarGetDate()
    if not day then return events end
    local n = CalendarGetNumDayEvents(0, day) or 0
    for i = 1, n do
        local title, hour, minute, calendarType, sequenceType, eventType =
            CalendarGetDayEvent(0, day, i)
        if title and tonumber(eventType) == 1 then
            table.insert(events, { index = i, day = day, title = title, hour = hour or 0, minute = minute or 0 })
        end
    end
    return events
end

-- Riempie il dropdown con gli eventi raid di oggi e riallinea la selezione.
function GM:RefreshAutoinviterCalendar()
    if not self.ieAutoCalBox or not self.ieAutoEventDropdown then return end
    local db = self.autoinvite
    local events = self:GetTodayRaidEvents()
    self._autoEvents = events

    local options = {}
    for _, e in ipairs(events) do
        table.insert(options, {
            text = string.format("%s (%02d:%02d)", e.title, e.hour, e.minute),
            value = tostring(e.index),
        })
    end
    if #options == 0 then
        options = { { text = L["No raid events today"], value = "none" } }
    end

    -- Il giorno e' cambiato? Allora la selezione salvata non e' piu' valida.
    local today = events[1] and events[1].day or 0
    if db.eventDay and today ~= 0 and db.eventDay ~= today then
        db.eventIndex = nil
        db.eventTitle = nil
    end

    RLSuite.utils:SetupDropdown(self.ieAutoEventDropdown, options, db.eventIndex or "", function(value)
        self:SelectAutoinviteEvent(value)
    end)
    self:SelectAutoinviteEvent(db.eventIndex or (events[1] and tostring(events[1].index) or "none"), true)
    self:RefreshAutoinviterStatus()
end

-- Seleziona un evento raid nel dropdown: salva la scelta, copia l'orario
-- dell'evento nei campi HH:MM e mostra il numero di invitati.
function GM:SelectAutoinviteEvent(value, silent)
    local db = self.autoinvite
    local events = self._autoEvents or self:GetTodayRaidEvents()
    local found
    for _, e in ipairs(events) do
        if tostring(e.index) == tostring(value) then
            found = e
            break
        end
    end
    if not found then
        -- selezione non piu' valida: ripiega sul primo evento
        found = events[1]
    end
    db.eventIndex = found and tostring(found.index) or "none"
    db.eventTitle = found and found.title or ""
    db.eventDay = found and found.day or nil

    if found then
        db.hour = found.hour
        db.minute = found.minute
    end

    if self.ieAutoEventInfo then
        if found then
            local list = self:GetEventInviteeNames(found)
            db.eventCount = #list
            self.ieAutoEventInfo:SetText(string.format(L["%d players signed up"], #list))
        else
            db.eventCount = 0
            self.ieAutoEventInfo:SetText(L["No raid events today"])
        end
    end
    if not silent then
        if self.ieAutoHourEdit then self.ieAutoHourEdit:SetText(string.format("%02d", db.hour or 19)) end
        if self.ieAutoMinuteEdit then self.ieAutoMinuteEdit:SetText(string.format("%02d", db.minute or 0)) end
        self:SaveAutoinviter()
    end
end

-- Nomi dei partecipanti all'evento (esclusi i declinati).
function GM:GetEventInviteeNames(ev)
    local names = {}
    if not ev or not CalendarOpenEvent or not CalendarEventGetNumInvites or not CalendarEventGetInvite then
        return names
    end
    local ok = pcall(CalendarOpenEvent, 0, ev.day, ev.index)
    if not ok then return names end
    local n = CalendarEventGetNumInvites() or 0
    for i = 1, n do
        local name, _, _, _, status = CalendarEventGetInvite(i)
        -- CALENDAR_INVITESTATUS_DECLINED == 3
        if name and name ~= "" and status ~= 3 then
            table.insert(names, name)
        end
    end
    return names
end

-- Risolve l'evento selezionato (per indice, poi per titolo).
function GM:ResolveAutoinviteEvent()
    local db = self.autoinvite
    local events = self:GetTodayRaidEvents()
    for _, e in ipairs(events) do
        if tostring(e.index) == tostring(db.eventIndex) then return e end
    end
    for _, e in ipairs(events) do
        if e.title == db.eventTitle then return e end
    end
    return events[1]
end

-- Costruisce la lista dei nomi da invitare per la modalita' corrente.
function GM:BuildAutoinviteQueue()
    local db = self.autoinvite
    local queue = {}
    if db.mode == "calendar" then
        local ev = self:ResolveAutoinviteEvent()
        if ev then
            for _, n in ipairs(self:GetEventInviteeNames(ev)) do
                queue[#queue + 1] = n
            end
        end
    else
        local text = self.ieAutoNamesEdit and self.ieAutoNamesEdit:GetText() or (db.names or "")
        -- I nomi dei giocatori non contengono spazi: si splitta su spazi,
        -- virgole, punti e virgola e a capo.
        for name in (text or ""):gmatch("[^%s,;]+") do
            if name ~= "" and name ~= "-" then
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

-- Invita un singolo nome (in debug stampa e non invita).
function GM:InviteAutoName(name)
    if not name then return end
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        RLSuite.utils:Print("[DBG] Autoinvite " .. name)
        return
    end
    if InviteUnit then InviteUnit(name) end
end

-- Salva lo stato dell'autoinviter nel DB (il flag enabled non deve
-- sopravvivere al reload: il timer non esiste piu' dopo un riavvio).
function GM:SaveAutoinviter()
    local db = self.autoinvite
    if not db then return end
    if self.ieAutoNamesEdit and db.mode == "manual" then
        db.names = self.ieAutoNamesEdit:GetText() or ""
    end
    db.enabled = self.autoinviteActive and true or false
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
        self.ieAutoArmBtn:SetText(L["Stop auto-invite"])
    else
        self.ieAutoArmBtn:SetText(L["Start auto-invite"])
    end
end

function GM:BuildWLGroupColumns()
    self.wlGroupCols = {}
    self.wlGroupLabels = {}
    self.wlGroupSlots = {}
    local box = self.wlGroupBox
    for g = 1, 5 do
        local col = CreateFrame("Frame", nil, box)
        col:SetWidth(64)
        self.wlGroupCols[g] = col

        local lbl = FontStr(col, "OVERLAY", 12)
        lbl:SetText("G" .. g)
        lbl:SetTextColor(1, 0.82, 0)
        lbl:SetJustifyH("CENTER")
        self.wlGroupLabels[g] = lbl

        for s = 1, 5 do
            local i = (g - 1) * 5 + s
            local bar = CreateFrame("Frame", nil, col)
            bar:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 6,
                insets = {left=1, right=1, top=1, bottom=1},
            })
            bar:SetBackdropColor(0.16, 0.16, 0.16, 1)
            bar:SetBackdropBorderColor(0, 0, 0, 0.6)

            local nameFS = FontStr(bar, "OVERLAY", 11)
            nameFS:SetPoint("CENTER", bar, "CENTER", 0, 0)
            nameFS:SetJustifyH("CENTER")
            nameFS:SetTextColor(0, 0, 0)
            -- ombra chiara: il nome nero resta leggibile anche sui colori
            -- di classe piu' scuri (DK, Warlock)
            nameFS:SetShadowColor(1, 1, 1, 0.7)
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
function GM:UpdateWLGroups()
    if not self.wlGroupSlots then return end

    local byGroup = { {}, {}, {}, {}, {} }
    local num = 0
    if IsInRaid and IsInRaid() and GetNumRaidMembers then
        num = GetNumRaidMembers()
    end
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

    -- Numero di colonne dalla difficolta' di Groupmaking (2 per il 10, 5 per il 25).
    local numSlots = tonumber(self.db.difficulty or "10") or 10
    local ngroups = math.ceil(numSlots / 5)
    if ngroups < 2 then ngroups = 2 end

    for g = 1, 5 do
        local col = self.wlGroupCols and self.wlGroupCols[g]
        if col then
            if g <= ngroups then col:Show() else col:Hide() end
        end
        for s = 1, 5 do
            local bar = self.wlGroupSlots[(g - 1) * 5 + s]
            if bar then
                local member = byGroup[g][s]
                if member then
                    local r, gg, b = RLSuite.utils:GetClassColor(member.class)
                    bar:SetBackdropColor(r, gg, b, 1)
                    if bar.nameFS then bar.nameFS:SetText(member.name) end
                else
                    bar:SetBackdropColor(0.16, 0.16, 0.16, 1)
                    if bar.nameFS then bar.nameFS:SetText("") end
                end
            end
        end
    end
    self:LayoutWLGroupColumns(ngroups)
end

-- Posiziona le colonne (una per gruppo raid) e le barre verticali al loro
-- interno, dentro il riquadro Raid Group.
function GM:LayoutWLGroupColumns(ngroups)
    local box = self.wlGroupBox
    if not box then return end
    ngroups = ngroups or 5
    local w = box:GetWidth() or 0
    local inner = w - 12
    local colW = math.floor((inner - (ngroups - 1) * WL_COL_GAP) / ngroups)
    if colW > 100 then colW = 100 end
    if colW < 50 then colW = 50 end
    local totalW = ngroups * colW + (ngroups - 1) * WL_COL_GAP
    local startX = 6 + math.floor(math.max(0, (inner - totalW) / 2))
    for g = 1, 5 do
        local col = self.wlGroupCols and self.wlGroupCols[g]
        if col then
            col:ClearAllPoints()
            col:SetWidth(colW)
            col:SetPoint("TOPLEFT", box, "TOPLEFT", startX + (g - 1) * (colW + WL_COL_GAP), -24)
            local lbl = self.wlGroupLabels and self.wlGroupLabels[g]
            if lbl then
                lbl:ClearAllPoints()
                lbl:SetPoint("TOP", col, "TOP", 0, 0)
            end
            for s = 1, 5 do
                local bar = self.wlGroupSlots and self.wlGroupSlots[(g - 1) * 5 + s]
                if bar then
                    bar:ClearAllPoints()
                    bar:SetSize(colW, WL_BAR_H)
                    if s == 1 then
                        bar:SetPoint("TOP", col, "TOP", 0, -WL_GROUP_LABEL_H)
                    else
                        bar:SetPoint("TOP", self.wlGroupSlots[(g - 1) * 5 + s - 1], "BOTTOM", 0, -WL_BAR_GAP)
                    end
                end
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

function GM:UpdateWhisplist()
    if not self.wlContent then return end
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    if self.SkinInner then self:SkinInner() end
    for _, child in ipairs(self.wlRows or {}) do
        if child.SetScript then child:SetScript("OnUpdate", nil) end
        child:Hide()
        child:SetParent(nil)
    end
    self.wlRows = {}
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
        local row = CreateFrame("Button", nil, self.wlContent)
        self.wlRows[#self.wlRows + 1] = row
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", self.wlContent, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", self.wlContent, "TOPRIGHT", 0, -y)
        row.entry = entry

        local text = FontStr(row, "OVERLAY", 12)
        text:SetPoint("LEFT", row, "LEFT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        text:SetJustifyH("LEFT")
        local info = entry.name or "Unknown"
        if entry.class then
            info = info .. " (" .. string.sub(entry.class, 1, 1) .. string.lower(string.sub(entry.class, 2)) .. ")"
        end
        if entry.gs then info = info .. " GS:" .. entry.gs end
        local n = #self:GetEntryMessages(entry)
        if n > 1 then info = info .. "  [" .. n .. "]" end
        text:SetText(info)
        row.text = text

        row:SetScript("OnClick", function(s, button)
            if button == "RightButton" then
                -- Debug mode: il clic destro elimina il giocatore senza
                -- inviare il messaggio di decline. Rimando la rimozione di
                -- un frame per non distruggere il bottone durante il click
                -- (altrimenti i click successivi possono bloccarsi).
                if RLSuite.DebugMode and RLSuite:DebugMode() and row.entry then
                    self._wlRemoveNext = row.entry
                    if not self._wlRemoveFrame then
                        self._wlRemoveFrame = CreateFrame("Frame")
                    end
                    self._wlRemoveFrame:SetScript("OnUpdate", function(fr)
                        fr:SetScript("OnUpdate", nil)
                        if self._wlRemoveNext then
                            local e = self._wlRemoveNext
                            self._wlRemoveNext = nil
                            self:RemoveWhisperEntry(e)
                        end
                    end)
                end
                return
            end
            self:SelectWhisperEntry(i)
        end)

        y = y + 26
    end
    self.wlContent:SetHeight(math.max(y, 1))
    self:StyleWhisperRows()
end

-- Stile delle righe dei giocatori: riga selezionata evidenziata, righe con
-- messaggi non letti con l'accento dorato "pulsante" stile Blizzard.
function GM:StyleWhisperRows()
    for i, row in ipairs(self.wlRows or {}) do
        local entry = row.entry
        local isSelected = (i == self.selectedEntryIndex)
        if isSelected then
            RLSuite.utils:SkinRow(row, true)
            row:SetScript("OnUpdate", nil)
            if row.text then row.text:SetTextColor(1, 1, 1) end
        elseif entry and entry.unread then
            RLSuite.utils:SkinRow(row, false)
            row:SetBackdropColor(0.22, 0.16, 0.02, 0.95)
            row:SetBackdropBorderColor(1, 0.82, 0, 1)
            row:SetScript("OnUpdate", function(r)
                local v = (math.sin((GetTime() or 0) * 5) + 1) / 2
                r:SetBackdropBorderColor(0.45 + 0.55 * v, 0.32 + 0.50 * v, 0.05, 1)
            end)
            if row.text then row.text:SetTextColor(1, 0.82, 0) end
        else
            RLSuite.utils:SkinRow(row, false)
            row:SetScript("OnUpdate", nil)
            if row.text then
                if entry and entry.invited then
                    row.text:SetTextColor(0.5, 0.5, 0.5)
                else
                    row.text:SetTextColor(1, 1, 1)
                end
            end
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
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        RLSuite.utils:Print("[DBG] Invite " .. (self.selectedEntry.name or "?"))
        RLSuite.utils:Whisper(self.selectedEntry.name, "You are invited (debug).")
        return
    end
    InviteUnit(self.selectedEntry.name)
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

local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function()
    if RLSuite.groupmaking and RLSuite.groupmaking.SaveComp then
        RLSuite.groupmaking:SaveComp()
    end
end)

-- Il pannello Raid Group mostra il raid reale: si aggiorna a ogni cambio
-- del roster (inviti, spostamenti di gruppo, uscite).
local rosterFrame = CreateFrame("Frame")
rosterFrame:RegisterEvent("RAID_ROSTER_UPDATE")
rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterFrame:SetScript("OnEvent", function()
    if RLSuite.groupmaking and RLSuite.groupmaking.UpdateWLGroups then
        RLSuite.groupmaking:UpdateWLGroups()
    end
end)
