-- ============================================================
-- RLSuite - MacroBar Module
-- ============================================================

RLSuite.macrobar = {}
local MB = RLSuite.macrobar

local KEYPAD_BTN_W = 75
local KEYPAD_BTN_H = 22
local KEYPAD_GAP = 6
local KEYPAD_PAD = 8
local KEYPAD_COUNT = 4

function MB:Init()
    self.db = RLSuiteDB.macrobar
    self:EnsurePhases()
    self.buttons = {}
    self.keypadButtons = {}
    self:CreateFrame()
    self:CreateButtons()
    self:CreateKeypad()
    self:ApplyLayout()
    self:LoadKeybinds()
    self:UpdatePhase()
end

function MB:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then
        self.frame:Hide()
        return
    end
    local pset = self:PhaseSettings()
    if pset and pset.enabled == false then
        RLSuite.utils:Print("Macrobar disabilitata in Config.")
        return
    end
    self.frame:Show()
end

function MB:KeypadSize()
    local w = KEYPAD_PAD * 2 + KEYPAD_COUNT * KEYPAD_BTN_W + (KEYPAD_COUNT - 1) * KEYPAD_GAP
    local h = KEYPAD_PAD * 2 + KEYPAD_BTN_H
    return w, h
end

function MB:SaveHolderPosition()
    local f = self.frame
    if not f then return end
    local point, _, relPoint, x, y = f:GetPoint()
    local p = self:PhaseSettings()
    if not p then return end
    p.point = point
    p.relPoint = relPoint
    p.x = x
    p.y = y
end

function MB:EndShiftDrag()
    if not self._shiftDrag then return end
    if self.frame then
        self.frame:StopMovingOrSizing()
    end
    self:SaveHolderPosition()
    self._shiftDrag = false
end

function MB:BeginShiftDrag()
    local p = self:PhaseSettings()
    if p and p.locked and not (RLSuiteDB and RLSuiteDB.anchorMode) then return end
    if not self.frame then return end
    self._shiftDrag = true
    self.frame:StartMoving()
end

function MB:AttachShiftDrag(fr)
    if not fr then return end
    fr:EnableMouse(true)
    fr:SetScript("OnMouseDown", function(s, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            MB:BeginShiftDrag()
        end
    end)
    fr:SetScript("OnMouseUp", function(s, button)
        if MB._shiftDrag then
            MB:EndShiftDrag()
        end
    end)
end

-- Anchor mode (stile ElvUI): la HUD diventa trascinabile anche da
-- bloccata, quando "Toggle Anchors" e' attivo in Config.
function MB:SetAnchorMode(on)
    local f = self.frame
    if not f then return end
    on = on and true or false
    local function start(self2)
        if not (RLSuiteDB and RLSuiteDB.anchorMode) then return end
        self2:StartMoving()
    end
    local function stop(self2)
        self2:StopMovingOrSizing()
        MB:SaveHolderPosition()
    end
    if on then
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", start)
        f:SetScript("OnDragStop", stop)
        if self.macroHost then
            self.macroHost:RegisterForDrag("LeftButton")
            self.macroHost:SetScript("OnDragStart", start)
            self.macroHost:SetScript("OnDragStop", stop)
        end
    else
        f:SetScript("OnDragStart", nil)
        f:SetScript("OnDragStop", nil)
        if self.macroHost then
            self.macroHost:SetScript("OnDragStart", nil)
            self.macroHost:SetScript("OnDragStop", nil)
        end
        local p = self:PhaseSettings()
        f:SetMovable(not p.locked)
    end
end

function MB:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteMacroBar", UIParent)
    f:SetSize(350, 80)
    local ps = self:PhaseSettings()
    f:SetPoint(ps.point or "CENTER", UIParent, ps.relPoint or "CENTER", ps.x or 0, ps.y or 100)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetBackdrop(nil)
    f:Hide()
    self.frame = f
    self:AttachShiftDrag(f)

    local host = CreateFrame("Frame", "RLSuiteMacroHost", f)
    host:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    host:SetSize(350, 40)
    host:EnableMouse(true)
    self.macroHost = host
    self:AttachShiftDrag(host)

    self.phaseText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.phaseText:SetPoint("BOTTOM", host, "TOP", 0, 2)
    self.phaseText:SetText("MacroBar")
end

-- FIX: Non usare ActionButtonTemplate, crea bottoni custom
function MB:CreateButtons()
    local btnSize = 36
    local spacing = 4
    for i = 1, 12 do
        -- FIX: Usa un frame normale invece di ActionButtonTemplate
        local btn = CreateFrame("Button", "RLSuiteMacroBtn" .. i, self.macroHost or self.frame)
        btn:SetSize(btnSize, btnSize)
        local col = (i - 1) % 6
        local row = math.floor((i - 1) / 6)
        btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10 + col * (btnSize + spacing), -20 - row * (btnSize + spacing))
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetFrameLevel((self.frame:GetFrameLevel() or 1) + 10)

        -- Background visibile
        btn:SetBackdrop({
            bgFile = "Interface\Buttons\UI-Quickslot",
            edgeFile = "Interface\Buttons\UI-Quickslot",
            tile = false, tileSize = 32, edgeSize = 32,
        })
        btn:SetBackdropColor(0.2, 0.2, 0.2, 0.8)

        -- Icon texture (CREATA MANUALMENTE)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints(btn)
        btn.icon:SetTexture("Interface\Icons\INV_Misc_QuestionMark")
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Highlight
        btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.highlight:SetAllPoints(btn)
        btn.highlight:SetTexture("Interface\Buttons\ButtonHilight-Square")
        btn.highlight:SetBlendMode("ADD")
        btn.highlight:Hide()
        btn:SetHighlightTexture(btn.highlight)

        -- Pushed
        btn.pushed = btn:CreateTexture(nil, "OVERLAY")
        btn.pushed:SetAllPoints(btn)
        btn.pushed:SetTexture("Interface\Buttons\UI-Quickslot-Depress")
        btn.pushed:Hide()
        btn:SetPushedTexture(btn.pushed)

        btn.macroText = ""
        btn.index = i
        self:WireButtonClicks(btn, i)

        btn.hotkey = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.hotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
        btn.hotkey:SetFont("Fonts\FRIZQT__.TTF", 9, "OUTLINE")
        btn.hotkey:SetText("")

        btn.numText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.numText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
        btn.numText:SetFont("Fonts\FRIZQT__.TTF", 8, "OUTLINE")
        btn.numText:SetText(i)

        RLSuite.utils:SkinMacroButton(btn)
        self.buttons[i] = btn
    end
    self:ApplyLayout()
end

function MB:DB()
    if RLSuiteDB and RLSuiteDB.macrobar then
        self.db = RLSuiteDB.macrobar
    end
    return self.db
end

MB.phaseList = { "preraid", "preboss", "infight" }

function MB:PhaseDefaults()
    return {
        enabled = true,
        locked = true,
        scale = 1,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 100,
        buttons = 12,
        columns = 12,
        buttonSize = 32,
        spacing = 2,
        backdrop = true,
        showEmpty = true,
        mouseover = false,
        inheritGlobalFade = false,
        backdropSpacing = 2,
        heightMult = 1,
        widthMult = 1,
        alpha = 1,
        actionPaging = "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 8; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10;",
        visibility = "",
        keybinds = {},
    }
end

function MB:EnsurePhases()
    local db = self:DB() or (RLSuiteDB and RLSuiteDB.macrobar)
    if not db then return end
    self.db = db
    local defs = self:PhaseDefaults()
    if db.phases then
        local src = db.phases.preraid or db.phases.preboss or db.phases.infight
        if src then
            for k, _ in pairs(defs) do
                if src[k] ~= nil then
                    db[k] = src[k]
                end
            end
        end
        db.phases = nil
    end
    for k, def in pairs(defs) do
        if db[k] == nil then
            if k == "keybinds" then
                db[k] = {}
            else
                db[k] = def
            end
        end
    end
    db.keybinds = db.keybinds or {}
end

function MB:PhaseSettings(phase)
    self:EnsurePhases()
    return self.db
end

function MB:ApplyLayout()
    local db = self:DB()
    if not db or not self.frame then return end
    local p = self:PhaseSettings()

    if p.enabled == false then
        self.frame:Hide()
        return
    end

    local filled = self:FilledSlots()
    local n = #filled
    local cols = tonumber(p.columns) or 12
    if cols < 1 then cols = 1 end
    if n == 0 then
        cols = 1
    elseif cols > n then
        cols = n
    end
    local size = tonumber(p.buttonSize) or 32
    local sp = tonumber(p.spacing) or 2
    local bs = tonumber(p.backdropSpacing) or 2
    local wm = tonumber(p.widthMult) or 1
    local hm = tonumber(p.heightMult) or 1
    if wm < 1 then wm = 1 end
    if hm < 1 then hm = 1 end
    local rows = 1
    if n > 0 then
        rows = math.ceil(n / cols)
    end
    local innerW = cols * size + (cols - 1) * sp
    local innerH = rows * size + (rows - 1) * sp
    local extraW = (wm - 1) * (size + sp)
    local extraH = (hm - 1) * (size + sp)
    local showBd = p.backdrop ~= false
    local pad = 2
    local kw, kh = self:KeypadSize()
    local hostW = math.max(kw, innerW + extraW + pad * 2)
    local hostH = innerH + extraH + pad * 2
    if hostH < size then hostH = size end

    local keypadOn = self.keypadFrame and self.keypadFrame:IsShown()
    local gap = 4
    local holderH = hostH
    if keypadOn then
        holderH = hostH + gap + kh
    end
    self.frame:SetBackdrop(nil)
    if self.frame.rlsBgFill then self.frame.rlsBgFill:Hide() end
    self.frame:SetSize(hostW, holderH)
    self.frame:SetScale(p.scale or 1)

    local point = p.point or "CENTER"
    local rel = p.relPoint or point
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, rel, p.x or 0, p.y or 0)

    if self.macroHost then
        self.macroHost:ClearAllPoints()
        self.macroHost:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        self.macroHost:SetSize(hostW, hostH)
    end

    if self.phaseText then
        self.phaseText:ClearAllPoints()
        self.phaseText:SetPoint("BOTTOM", self.macroHost or self.frame, "TOP", 0, 2)
    end

    for i = 1, 12 do
        local btn = self.buttons[i]
        if btn then btn:Hide() end
    end
    for vis, slot in ipairs(filled) do
        local btn = self.buttons[slot]
        if btn then
            btn:SetSize(size, size)
            local col = (vis - 1) % cols
            local row = math.floor((vis - 1) / cols)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.macroHost or self.frame, "TOPLEFT", pad + col * (size + sp), -pad - row * (size + sp))
            if RLSuite.utils.SkinMacroButton then
                RLSuite.utils:SkinMacroButton(btn)
            end
            btn:EnableMouse(true)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetFrameLevel((self.frame:GetFrameLevel() or 1) + 10)
            self:WireButtonClicks(btn, slot)
            btn:Show()
        end
    end

    if self.keypadFrame then
        self.keypadFrame:SetSize(kw, kh)
        self.keypadFrame:ClearAllPoints()
        self.keypadFrame:SetPoint("TOP", self.macroHost or self.frame, "BOTTOM", 0, -gap)
        if showBd then
            RLSuite.utils:SkinFrame(self.keypadFrame)
        else
            if self.keypadFrame.rlsBgFill then self.keypadFrame.rlsBgFill:Hide() end
            self.keypadFrame:SetBackdrop(nil)
        end
        local kpad = KEYPAD_PAD
        for i, kbtn in ipairs(self.keypadButtons or {}) do
            kbtn:ClearAllPoints()
            kbtn:SetSize(KEYPAD_BTN_W, KEYPAD_BTN_H)
            kbtn:SetPoint("TOPLEFT", self.keypadFrame, "TOPLEFT", kpad + (i - 1) * (KEYPAD_BTN_W + KEYPAD_GAP), -kpad)
        end
    end

    self.frame:EnableMouse(true)
    self.frame:SetMovable((not p.locked) or (RLSuiteDB and RLSuiteDB.anchorMode == true))
    if self.macroHost then
        self.macroHost:EnableMouse(true)
    end

    self:ApplyVisibility()
    self:SetupHover()
end

function MB:UpdateEmptyButtons()
    if self.ApplyLayout then
        self:ApplyLayout()
    end
end

function MB:SetBarAlpha(override)
    local db = self:DB()
    if not db or not self.frame then return end
    local a = override
    local p = self:PhaseSettings()
    if a == nil then a = p.alpha or 1 end
    if p.inheritGlobalFade then
        a = a * (UIParent:GetAlpha() or 1)
    end
    if a < 0 then a = 0 end
    if a > 1 then a = 1 end
    self.frame:SetAlpha(a)
end

function MB:SetupHover()
    local db = self:DB()
    local f = self.frame
    if not db or not f then return end
    local p = self:PhaseSettings()
    local function over()
        if MouseIsOver(f) then return true end
        if self.keypadFrame and self.keypadFrame:IsShown() and MouseIsOver(self.keypadFrame) then return true end
        return false
    end
    local function enter()
        self:SetBarAlpha()
    end
    local function leave()
        if p.mouseover and not over() then
            self:SetBarAlpha(0)
        end
    end
    self._hoverEnter = enter
    self._hoverLeave = leave
    if p.mouseover then
        self:SetBarAlpha(0)
        f:SetScript("OnEnter", enter)
        f:SetScript("OnLeave", leave)
    else
        self:SetBarAlpha()
        f:SetScript("OnEnter", nil)
        f:SetScript("OnLeave", nil)
    end
    for i, btn in ipairs(self.buttons or {}) do
        self:WireButtonClicks(btn, i)
    end
end

function MB:ApplyVisibility()
    local f = self.frame
    local db = self:DB()
    if not f or not db then return end
    local vis = self:PhaseSettings().visibility or ""
    if UnregisterStateDriver then
        UnregisterStateDriver(f, "visibility")
    end
    if vis ~= "" and RegisterStateDriver then
        RegisterStateDriver(f, "visibility", vis)
    end
end

function MB:CreateKeypad()
    local kw, kh = self:KeypadSize()
    self.keypadFrame = CreateFrame("Frame", "RLSuiteMacroKeypad", self.frame)
    self.keypadFrame:SetSize(kw, kh)
    self.keypadFrame:SetPoint("TOP", self.macroHost or self.frame, "BOTTOM", 0, -4)
    self:AttachShiftDrag(self.keypadFrame)

    local buttons = {
        {text = "Pull 15", func = function() MB:StartPullTimer(15) end},
        {text = "Pull 20", func = function() MB:StartPullTimer(20) end},
        {text = "Pull 30", func = function() MB:StartPullTimer(30) end},
        {text = "Ready", func = function() MB:DoReadyCheck() end},
    }

    for i, data in ipairs(buttons) do
        local btn = CreateFrame("Button", nil, self.keypadFrame, "UIPanelButtonTemplate")
        btn:SetSize(KEYPAD_BTN_W, KEYPAD_BTN_H)
        btn:SetPoint("TOPLEFT", self.keypadFrame, "TOPLEFT", KEYPAD_PAD + (i - 1) * (KEYPAD_BTN_W + KEYPAD_GAP), -KEYPAD_PAD)
        btn:SetText(data.text)
        btn:SetScript("OnClick", function()
            if IsShiftKeyDown() or MB._shiftDrag then
                MB:EndShiftDrag()
                return
            end
            data.func()
        end)
        self:AttachShiftDrag(btn)
        -- AttachShiftDrag overwrites OnMouseDown; keep click via OnClick
        self.keypadButtons[i] = btn
    end

    RLSuite.utils:SkinFrame(self.keypadFrame)
    self.keypadFrame:Hide()
end

function MB:ShowKeypad(show)
    if not self.keypadFrame then return end
    if show then
        self.keypadFrame:Show()
    else
        self.keypadFrame:Hide()
    end
    if self.ApplyLayout then
        self:ApplyLayout()
    end
end

function MB:UpdatePhase()
    local phase = RLSuite.context or "preraid"
    if self.phaseText then
        self.phaseText:SetText("Fase: " .. string.upper(phase))
    end
    self:LoadMacrosForPhase(phase)
    self:LoadKeybinds(phase)
    if self.ApplyLayout then
        self:ApplyLayout()
    end
end

function MB:MacroIsFilled(data)
    if not data then return false end
    if data.text and data.text ~= "" then return true end
    if data.name and data.name ~= "" then return true end
    return false
end

function MB:FilledSlots(phase)
    local list = {}
    for i = 1, 12 do
        if self:MacroIsFilled(self:GetMacroData(i, phase)) then
            table.insert(list, i)
        end
    end
    return list
end

function MB:GetMacroData(index, phase)
    phase = phase or RLSuite.context or "preraid"
    local db = self:DB() or (RLSuiteDB and RLSuiteDB.macrobar)
    if not db then return nil end
    db.macros = db.macros or {}
    local macros = db.macros[phase] or {}
    return macros[index] or macros[tostring(index)]
end

function MB:LoadMacrosForPhase(phase)
    for i = 1, 12 do
        local btn = self.buttons[i]
        if btn and btn.icon then
            local macroData = self:GetMacroData(i, phase)
            if macroData and ((macroData.text and macroData.text ~= "") or (macroData.name and macroData.name ~= "") or macroData.icon) then
                btn.macroText = macroData.text or ""
                btn.icon:SetTexture(macroData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            else
                btn.macroText = ""
                btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
    end
    if self.UpdateEmptyButtons then
        self:UpdateEmptyButtons()
    end
    if RLSuite.mainWindow and RLSuite.mainWindow.RefreshMacroPreview then
        if RLSuite.mainWindow.macroPhase == phase then
            RLSuite.mainWindow:RefreshMacroPreview()
        end
    end
end

function MB:ExecuteMacro(index)
    local data = self:GetMacroData(index)
    local text = (data and data.text) or ""
    if text == "" then
        local btn = self.buttons[index]
        text = (btn and btn.macroText) or ""
    end
    if text == "" then return end
    local lines = {strsplit("\n", text)}
    for _, line in ipairs(lines) do
        line = string.gsub(string.gsub(line, "^%s+", ""), "%s+$", "")
        if line ~= "" then
            MB:RunMacroLine(line)
        end
    end
end

function MB:RunMacroLine(line)
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        local cmd, rest = string.match(line, "^/(%S+)%s*(.*)$")
        if not cmd then
            RLSuite.utils:SendChat(line, "RAID_WARNING")
            return
        end
        local c = string.lower(cmd)
        local talk = {
            rw = "RAID_WARNING", raidwarning = "RAID_WARNING",
            raid = "RAID", ra = "RAID", r = "RAID",
            s = "SAY", say = "SAY", y = "YELL", yell = "YELL",
            p = "PARTY", party = "PARTY", g = "GUILD", guild = "GUILD",
        }
        if talk[c] then
            RLSuite.utils:SendChat((rest ~= "" and rest) or line, talk[c])
            return
        end
        if c == "readycheck" then
            RLSuite.utils:SendChat("Ready check!", "RAID")
            return
        end
    end
    if string.sub(line, 1, 1) == "/" then
        local edit = ChatFrame1EditBox or ChatFrameEditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
        if edit then
            edit:SetText(line)
            ChatEdit_SendText(edit, 1)
        else
            RLSuite.utils:Print("Chat edit box non trovato.")
        end
    else
        RLSuite.utils:SendChat(line, "RAID_WARNING")
    end
end

function MB:OpenMacroEdit(index)
    if self.editFrame then self.editFrame:Hide() end
    local f = CreateFrame("Frame", "RLSuiteMacroEdit", UIParent)
    f:SetSize(300, 250)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("Modifica Macro " .. index)

    local phaseLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phaseLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -40)
    phaseLabel:SetText("Fase:")

    local phase = RLSuite.context or "preraid"
    local phaseText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phaseText:SetPoint("LEFT", phaseLabel, "RIGHT", 5, 0)
    phaseText:SetText(phase)

    local macroLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    macroLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -65)
    macroLabel:SetText("Macro (max 10 righe):")

    local edit = CreateFrame("EditBox", "RLSuiteMacroEditBox", f)
    edit:SetMultiLine(true)
    edit:SetSize(270, 100)
    edit:SetPoint("TOPLEFT", macroLabel, "BOTTOMLEFT", 0, -5)
    edit:SetFontObject("ChatFontNormal")
    edit:SetBackdrop({
        bgFile = "Interface\Tooltips\UI-Tooltip-Background",
        tile = true, tileSize = 16,
    })
    edit:SetBackdropColor(0, 0, 0, 0.8)
    edit:SetTextInsets(5, 5, 5, 5)
    edit:SetAutoFocus(true)

    local macros = self.db.macros[phase] or {}
    local current = macros[index] or {text = "", icon = ""}
    edit:SetText(current.text or "")

    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetSize(80, 22)
    saveBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 15)
    saveBtn:SetText("Salva")
    saveBtn:SetScript("OnClick", function()
        self.db.macros[phase] = self.db.macros[phase] or {}
        self.db.macros[phase][index] = {
            text = edit:GetText(),
            icon = current.icon or "Interface\Icons\INV_Misc_QuestionMark",
        }
        self:LoadMacrosForPhase(phase)
        if RLSuite.mainWindow and RLSuite.mainWindow.RefreshMacroTab then
            RLSuite.mainWindow:RefreshMacroTab()
        end
        f:Hide()
        RLSuite.utils:Print("Macro " .. index .. " salvata per fase " .. phase)
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
    closeBtn:SetText("Annulla")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    RLSuite.utils:SkinFrame(f)
    self.editFrame = f
    f:Show()
end

function MB:WireButtonClicks(btn, index)
    if not btn then return end
    index = index or btn.index
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnMouseDown", function(s, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            MB:BeginShiftDrag()
        end
    end)
    btn:SetScript("OnClick", function(s, button)
        if IsShiftKeyDown() or MB._shiftDrag then
            MB:EndShiftDrag()
            return
        end
        if button == "RightButton" then
            MB:OpenMacroEdit(index)
        else
            MB:ExecuteMacro(index)
        end
    end)
    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Macro " .. tostring(index), 1, 0.82, 0)
        local data = MB:GetMacroData(index)
        local name = data and data.name or ""
        local txt = (data and data.text) or s.macroText or ""
        if name ~= "" then
            GameTooltip:AddLine(name, 1, 1, 1)
        end
        if txt ~= "" then
            GameTooltip:AddLine(txt, 0.9, 0.9, 0.9, true)
        elseif name == "" then
            GameTooltip:AddLine("Vuota", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
        if MB._hoverEnter then MB._hoverEnter() end
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if MB._hoverLeave then MB._hoverLeave() end
    end)
end

function MB:LoadKeybinds(phase)
    local p = self:PhaseSettings(phase)
    p.keybinds = p.keybinds or {}
    if self._boundKeys then
        for _, key in ipairs(self._boundKeys) do
            if key and key ~= "" then
                SetBinding(key)
            end
        end
    end
    self._boundKeys = {}
    for i = 1, 12 do
        local key = p.keybinds[i]
        if self.buttons[i] and self.buttons[i].hotkey then
            self.buttons[i].hotkey:SetText(key or "")
        end
        if key and key ~= "" then
            SetBindingClick(key, "RLSuiteMacroBtn" .. i)
            table.insert(self._boundKeys, key)
        end
    end
    self:RefreshKeybindUI()
end

function MB:ClearKeybind(index)
    local p = self:PhaseSettings(self.bindPhase)
    p.keybinds = p.keybinds or {}
    local old = p.keybinds[index]
    if old and old ~= "" then
        SetBinding(old)
    end
    p.keybinds[index] = nil
    if self.buttons[index] and self.buttons[index].hotkey then
        self.buttons[index].hotkey:SetText("")
    end
    if SaveBindings and GetCurrentBindingSet then
        SaveBindings(GetCurrentBindingSet())
    end
    self:RefreshKeybindUI()
end

function MB:SetKeybind(index, key)
    if not key or key == "" then
        self:ClearKeybind(index)
        return
    end
    local p = self:PhaseSettings(self.bindPhase)
    p.keybinds = p.keybinds or {}
    for i = 1, 12 do
        if i ~= index and p.keybinds[i] == key then
            self:ClearKeybind(i)
        end
    end
    local old = p.keybinds[index]
    if old and old ~= "" and old ~= key then
        SetBinding(old)
    end
    p.keybinds[index] = key
    SetBindingClick(key, "RLSuiteMacroBtn" .. index)
    if self.buttons[index] and self.buttons[index].hotkey then
        self.buttons[index].hotkey:SetText(key)
    end
    if SaveBindings and GetCurrentBindingSet then
        SaveBindings(GetCurrentBindingSet())
    end
    RLSuite.utils:Print("Macro " .. index .. " -> " .. key)
    self:RefreshKeybindUI()
end

function MB:BindingFromKey(key)
    if not key or key == "" then return nil end
    local skip = {
        LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
        LALT = true, RALT = true, UNKNOWN = true,
    }
    if skip[key] then return nil end
    if key == "ESCAPE" then return "ESCAPE" end
    local bind = key
    if IsShiftKeyDown() then bind = "SHIFT-" .. bind end
    if IsControlKeyDown() then bind = "CTRL-" .. bind end
    if IsAltKeyDown() then bind = "ALT-" .. bind end
    return bind
end

function MB:OpenKeybindUI(phase)
    self.bindPhase = nil
    if self.bindFrame then
        self.bindFrame:Show()
        self:RefreshKeybindUI()
        return
    end
    local f = CreateFrame("Frame", "RLSuiteMacroKeybindFrame", UIParent)
    f:SetSize(300, 390)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    RLSuite.utils:SkinFrame(f)
    self.bindFrame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    title:SetText("Macrobar Keybinds")
    self.bindTitle = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        self.bindingIndex = nil
        f:Hide()
    end)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -28)
    hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -28)
    hint:SetJustifyH("LEFT")
    hint:SetText("Clicca una riga, poi premi un tasto. Backspace o click destro: togli.")
    self.bindHint = hint

    self.bindRows = {}
    for i = 1, 12 do
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48 - (i - 1) * 26)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -48 - (i - 1) * 26)
        RLSuite.utils:SkinRow(row, false)
        local left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        left:SetPoint("LEFT", row, "LEFT", 8, 0)
        left:SetText("Macro " .. i)
        local right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        right:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        right:SetText("-")
        row.right = right
        row.index = i
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(s, button)
            if button == "RightButton" then
                MB:ClearKeybind(s.index)
                MB.bindingIndex = nil
                MB:RefreshKeybindUI()
                return
            end
            MB.bindingIndex = s.index
            MB:RefreshKeybindUI()
        end)
        self.bindRows[i] = row
    end

    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(s, key)
        local idx = MB.bindingIndex
        if not idx then return end
        local bind = MB:BindingFromKey(key)
        if not bind then return end
        if bind == "ESCAPE" then
            MB.bindingIndex = nil
            MB:RefreshKeybindUI()
            return
        end
        if key == "BACKSPACE" or key == "DELETE" then
            MB:ClearKeybind(idx)
            MB.bindingIndex = nil
            return
        end
        MB:SetKeybind(idx, bind)
        MB.bindingIndex = nil
    end)
    f:SetScript("OnShow", function(s)
        s:EnableKeyboard(true)
        MB:RefreshKeybindUI()
    end)
    f:SetScript("OnHide", function()
        MB.bindingIndex = nil
    end)
    f:Show()
    self:RefreshKeybindUI()
end

function MB:RefreshKeybindUI()
    if not self.bindRows then return end
    local p = self:PhaseSettings(self.bindPhase)
    local binds = (p and p.keybinds) or {}
    if self.bindTitle then
        self.bindTitle:SetText("Macrobar Keybinds")
    end
    for i, row in ipairs(self.bindRows) do
        local key = binds[i]
        if self.bindingIndex == i then
            row.right:SetText("...")
            row.right:SetTextColor(1, 0.82, 0)
            RLSuite.utils:SkinRow(row, true)
        else
            row.right:SetText((key and key ~= "") and key or "-")
            row.right:SetTextColor(0.9, 0.9, 0.9)
            RLSuite.utils:SkinRow(row, false)
        end
    end
    if self.bindHint then
        if self.bindingIndex then
            self.bindHint:SetText("Premi un tasto per Macro " .. self.bindingIndex .. " (Esc annulla).")
        else
            self.bindHint:SetText("Clicca una riga, poi premi un tasto. Backspace o click destro: togli.")
        end
    end
end

function MB:StartPullTimer(seconds)
    if not (RLSuite.IsOfficer and RLSuite:IsOfficer()) then
        RLSuite.utils:Print("Devi essere RL o assist per il pull timer.")
        return
    end
    RLSuite.utils:SendChat("Pull in " .. seconds .. " seconds!", "RAID_WARNING")
    -- barra-timer in DBM/BigWigs se installati
    RLSuite.utils:StartDbmTimer(seconds, "Pull", "Interface\\Icons\\Ability_Warrior_Charge")
    local remaining = seconds
    local timerFrame = CreateFrame("Frame")
    timerFrame:SetScript("OnUpdate", function(self2, elapsed)
        self2.elapsed = (self2.elapsed or 0) + elapsed
        if self2.elapsed >= 1 then
            self2.elapsed = 0
            remaining = remaining - 1
            if remaining <= 0 then
                RLSuite.utils:SendChat("PULL NOW!", "RAID_WARNING")
                self2:SetScript("OnUpdate", nil)
                self2:Hide()
                return
            end
            if remaining <= 5 or remaining == 10 or remaining == 15 or remaining == 20 then
                RLSuite.utils:SendChat("Pull in " .. remaining .. "...", "RAID")
            end
        end
    end)
    timerFrame:Show()
end

function MB:DoReadyCheck()
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        RLSuite.utils:SendChat("Ready check!", "RAID")
        return
    end
    DoReadyCheck()
end
