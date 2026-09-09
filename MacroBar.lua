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
    self:LoadKeybinds()
    self:UpdatePhase()
end

function MB:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
    end
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
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

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
        btn:SetScript("OnClick", function(s, button)
            if button == "RightButton" then
                MB:OpenMacroEdit(i)
            else
                MB:ExecuteMacro(i)
            end
        end)

        btn.hotkey = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.hotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
        btn.hotkey:SetFont("Fonts\FRIZQT__.TTF", 9, "OUTLINE")
        btn.hotkey:SetText("")

        btn.numText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.numText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
        btn.numText:SetFont("Fonts\FRIZQT__.TTF", 8, "OUTLINE")
        btn.numText:SetText(i)

        self.buttons[i] = btn
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
            if string.sub(line, 1, 1) == "/" then
                ChatFrame1EditBox:SetText(line)
                ChatEdit_SendText(ChatFrame1EditBox, 1)
            else
                RLSuite.utils:SendChat(line, "RAID_WARNING")
            end
        end
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

function MB:LoadKeybinds()
    for i = 1, 12 do
        local key = self.db.keybinds[i]
        if key and self.buttons[i] and self.buttons[i].hotkey then
            self.buttons[i].hotkey:SetText(key)
            SetBindingClick(key, "RLSuiteMacroBtn" .. i)
        end
    end
end

function MB:StartPullTimer(seconds)
    if not IsRaidLeader() and not IsRaidOfficer() then
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
    DoReadyCheck()
end
