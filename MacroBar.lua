-- ============================================================
-- RLSuite - MacroBar Module
-- ============================================================

RLSuite.macrobar = {}
local MB = RLSuite.macrobar

function MB:Init()
    self.db = RLSuiteDB.macrobar
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
    if self.db and self.db.enabled == false then
        RLSuite.utils:Print("Macrobar disabilitata in Config.")
        return
    end
    self.frame:Show()
end

function MB:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteMacroBar", UIParent)
    f:SetSize(350, 80)
    f:SetPoint(self.db.point or "CENTER", UIParent, self.db.relPoint or "CENTER", self.db.x or 0, self.db.y or 100)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self2)
        if not RLSuiteDB.macrobar.locked then
            self2:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self2)
        self2:StopMovingOrSizing()
        local point, _, relPoint, x, y = self2:GetPoint()
        RLSuiteDB.macrobar.point = point
        RLSuiteDB.macrobar.relPoint = relPoint
        RLSuiteDB.macrobar.x = x
        RLSuiteDB.macrobar.y = y
    end)
    f:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 12,
        insets = {left=3, right=3, top=3, bottom=3}
    })
    f:Hide()
    self.frame = f
    RLSuite.utils:SkinFrame(f)

    self.phaseText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.phaseText:SetPoint("TOP", f, "TOP", 0, -5)
    self.phaseText:SetText("MacroBar")
end

-- FIX: Non usare ActionButtonTemplate, crea bottoni custom
function MB:CreateButtons()
    local btnSize = 36
    local spacing = 4
    for i = 1, 12 do
        -- FIX: Usa un frame normale invece di ActionButtonTemplate
        local btn = CreateFrame("Button", "RLSuiteMacroBtn" .. i, self.frame)
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

function MB:ApplyLayout()
    local db = self:DB()
    if not db or not self.frame then return end

    if db.enabled == false then
        self.frame:Hide()
        return
    end

    local n = tonumber(db.buttons) or 12
    if n < 1 then n = 1 end
    if n > 12 then n = 12 end
    local cols = tonumber(db.columns) or 12
    if cols < 1 then cols = 1 end
    local size = tonumber(db.buttonSize) or 32
    local sp = tonumber(db.spacing) or 2
    local bs = tonumber(db.backdropSpacing) or 2
    local wm = tonumber(db.widthMult) or 1
    local hm = tonumber(db.heightMult) or 1
    if wm < 1 then wm = 1 end
    if hm < 1 then hm = 1 end
    local rows = math.ceil(n / cols)
    local innerW = cols * size + (cols - 1) * sp
    local innerH = rows * size + (rows - 1) * sp
    local extraW = (wm - 1) * (size + sp)
    local extraH = (hm - 1) * (size + sp)
    local showBd = db.backdrop ~= false
    local pad = showBd and (bs + 4) or 2
    local w = innerW + extraW + pad * 2
    local h = innerH + extraH + pad * 2
    self.frame:SetSize(w, h)
    self.frame:SetScale(db.scale or 1)

    local point = db.point or "CENTER"
    local rel = db.relPoint or point
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, rel, db.x or 0, db.y or 0)

    if self.phaseText then
        self.phaseText:ClearAllPoints()
        self.phaseText:SetPoint("BOTTOM", self.frame, "TOP", 0, 2)
    end

    for i = 1, 12 do
        local btn = self.buttons[i]
        if btn then
            if i <= n then
                btn:SetSize(size, size)
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", pad + col * (size + sp), -pad - row * (size + sp))
                if RLSuite.utils.SkinMacroButton then
                    RLSuite.utils:SkinMacroButton(btn)
                end
                btn:EnableMouse(true)
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetFrameLevel((self.frame:GetFrameLevel() or 1) + 10)
                self:WireButtonClicks(btn, i)
                btn:Show()
            else
                btn:Hide()
            end
        end
    end

    self:UpdateEmptyButtons()

    if showBd then
        RLSuite.utils:SkinFrame(self.frame)
    else
        if self.frame.rlsBgFill then self.frame.rlsBgFill:Hide() end
        self.frame:SetBackdrop(nil)
    end

    if self.keypadFrame then
        self.keypadFrame:SetWidth(math.max(w, 280))
        if showBd then RLSuite.utils:SkinFrame(self.keypadFrame) end
    end

    local locked = db.locked
    self.frame:EnableMouse(not locked)
    self.frame:SetMovable(not locked)

    self:ApplyVisibility()
    self:SetupHover()
end

function MB:UpdateEmptyButtons()
    local db = self:DB()
    if not db then return end
    local n = db.buttons or 12
    local showEmpty = db.showEmpty ~= false
    local phase = RLSuite.context or "preraid"
    local macros = (db.macros and db.macros[phase]) or {}
    for i = 1, 12 do
        local btn = self.buttons[i]
        if btn and i <= n then
            local data = macros[i]
            local filled = data and data.text and data.text ~= ""
            if showEmpty or filled then
                btn:Show()
            else
                btn:Hide()
            end
        elseif btn then
            btn:Hide()
        end
    end
end

function MB:SetBarAlpha(override)
    local db = self:DB()
    if not db or not self.frame then return end
    local a = override
    if a == nil then a = db.alpha or 1 end
    if db.inheritGlobalFade then
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
    local function over()
        if MouseIsOver(f) then return true end
        if self.keypadFrame and self.keypadFrame:IsShown() and MouseIsOver(self.keypadFrame) then return true end
        return false
    end
    local function enter()
        self:SetBarAlpha()
    end
    local function leave()
        if db.mouseover and not over() then
            self:SetBarAlpha(0)
        end
    end
    self._hoverEnter = enter
    self._hoverLeave = leave
    if db.mouseover then
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
    local vis = db.visibility or ""
    if UnregisterStateDriver then
        UnregisterStateDriver(f, "visibility")
    end
    if vis ~= "" and RegisterStateDriver then
        RegisterStateDriver(f, "visibility", vis)
    end
end

function MB:CreateKeypad()
    self.keypadFrame = CreateFrame("Frame", "RLSuiteMacroKeypad", self.frame)
    self.keypadFrame:SetSize(350, 35)
    self.keypadFrame:SetPoint("TOP", self.frame, "BOTTOM", 0, -5)
    self.keypadFrame:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 12,
    })

    local buttons = {
        {text = "Pull 15", func = function() MB:StartPullTimer(15) end},
        {text = "Pull 20", func = function() MB:StartPullTimer(20) end},
        {text = "Pull 30", func = function() MB:StartPullTimer(30) end},
        {text = "Ready", func = function() MB:DoReadyCheck() end},
    }

    for i, data in ipairs(buttons) do
        local btn = CreateFrame("Button", nil, self.keypadFrame, "UIPanelButtonTemplate")
        btn:SetSize(75, 22)
        btn:SetPoint("TOPLEFT", self.keypadFrame, "TOPLEFT", 10 + (i-1) * 82, -6)
        btn:SetText(data.text)
        btn:SetScript("OnClick", data.func)
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
end

function MB:UpdatePhase()
    local phase = RLSuite.context or "preraid"
    if self.phaseText then
        self.phaseText:SetText("Fase: " .. string.upper(phase))
    end
    self:LoadMacrosForPhase(phase)
end

function MB:LoadMacrosForPhase(phase)
    local macros = self.db.macros[phase] or {}
    for i = 1, 12 do
        local btn = self.buttons[i]
        if btn and btn.icon then
            local macroData = macros[i]
            if macroData and macroData.text and macroData.text ~= "" then
                btn.macroText = macroData.text
                btn.icon:SetTexture(macroData.icon or "Interface\Icons\INV_Misc_QuestionMark")
            else
                btn.macroText = ""
                btn.icon:SetTexture("Interface\Icons\INV_Misc_QuestionMark")
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
    local btn = self.buttons[index]
    if not btn or not btn.macroText or btn.macroText == "" then return end
    local lines = {strsplit("\n", btn.macroText)}
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
    btn:SetScript("OnClick", function(s, button)
        if button == "RightButton" then
            MB:OpenMacroEdit(index)
        else
            MB:ExecuteMacro(index)
        end
    end)
    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Macro " .. tostring(index), 1, 0.82, 0)
        local txt = s.macroText or ""
        if txt ~= "" then
            GameTooltip:AddLine(txt, 1, 1, 1, true)
        else
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

function MB:LoadKeybinds()
    self.db.keybinds = self.db.keybinds or {}
    for i = 1, 12 do
        local key = self.db.keybinds[i]
        if self.buttons[i] and self.buttons[i].hotkey then
            self.buttons[i].hotkey:SetText(key or "")
        end
        if key and key ~= "" then
            SetBindingClick(key, "RLSuiteMacroBtn" .. i)
        end
    end
    self:RefreshKeybindUI()
end

function MB:ClearKeybind(index)
    self.db.keybinds = self.db.keybinds or {}
    local old = self.db.keybinds[index]
    if old and old ~= "" then
        SetBinding(old)
    end
    self.db.keybinds[index] = nil
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
    self.db.keybinds = self.db.keybinds or {}
    for i = 1, 12 do
        if i ~= index and self.db.keybinds[i] == key then
            self:ClearKeybind(i)
        end
    end
    local old = self.db.keybinds[index]
    if old and old ~= "" and old ~= key then
        SetBinding(old)
    end
    self.db.keybinds[index] = key
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

function MB:OpenKeybindUI()
    if self.bindFrame then
        if self.bindFrame:IsShown() then
            self.bindFrame:Hide()
            return
        end
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
    local binds = (self.db and self.db.keybinds) or {}
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
