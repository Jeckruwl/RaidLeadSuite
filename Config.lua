-- ============================================================
-- RLSuite - Config (ElvUI-style: left categories, right subtabs)
-- Appearance / layout only - no feature settings.
-- ============================================================

RLSuite.config = {}
local CFG = RLSuite.config

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

function CFG:Init()
    self.db = RLSuiteDB
    self.widgetId = 0
    self:CreateFrame()
end

function CFG:Toggle()
    if RLSuite.mainWindow and RLSuite.mainWindow.ShowTab then
        RLSuite.mainWindow:ShowTab("config")
        return
    end
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
    end
end

function CFG:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteConfig", UIParent)
    f:SetSize(620, 580)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    self.frame = f
    RLSuite.utils:SkinFrame(f)
    RLSuite.utils:ClampWindow(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
    title:SetText("Config")
    self.titleFS = title

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)

    self.left = CreateFrame("Frame", nil, f)
    self.left:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -36)
    self.left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    self.left:SetWidth(140)
    RLSuite.utils:SkinFrame(self.left)

    self.right = CreateFrame("Frame", nil, f)
    self.right:SetPoint("TOPLEFT", self.left, "TOPRIGHT", 6, 0)
    self.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    RLSuite.utils:SkinFrame(self.right)

    self.categories = {
        { key = "general",     label = "General" },
        { key = "savedraids",  label = "Saved Raids" },
        { key = "groupmaking", label = "Groupmaking" },
        { key = "macros",      label = "Macros" },
        { key = "raidframe",   label = "Raid Frame" },
        { key = "ms",          label = "MS" },
        { key = "loot",        label = "Loot" },
    }
    self.navBtns = {}
    for i, cat in ipairs(self.categories) do
        local btn = CreateFrame("Button", nil, self.left, "UIPanelButtonTemplate")
        btn:SetSize(124, 22)
        btn:SetPoint("TOPLEFT", self.left, "TOPLEFT", 8, -10 - (i - 1) * 26)
        btn:SetText(cat.label)
        btn.catKey = cat.key
        btn:SetScript("OnClick", function() self:SelectCategory(cat.key) end)
        self.navBtns[cat.key] = btn
    end

    self.subTabBar = CreateFrame("Frame", nil, self.right)
    self.subTabBar:SetPoint("TOPLEFT", self.right, "TOPLEFT", 8, -8)
    self.subTabBar:SetPoint("TOPRIGHT", self.right, "TOPRIGHT", -8, -8)
    self.subTabBar:SetHeight(24)

    self.panel = CreateFrame("Frame", nil, self.right)
    self.panel:SetPoint("TOPLEFT", self.subTabBar, "BOTTOMLEFT", 0, -6)
    self.panel:SetPoint("BOTTOMRIGHT", self.right, "BOTTOMRIGHT", -8, 8)

    self:SelectCategory("general")
end

function CFG:SelectCategory(key)
    self.currentCat = key
    for k, btn in pairs(self.navBtns or {}) do
        if k == key then btn:LockHighlight() else btn:UnlockHighlight() end
    end
    local subs = self:SubtabsFor(key)
    self:BuildSubtabs(subs)
    self:SelectSubtab(subs[1] and subs[1].key or "main")
end

function CFG:SubtabsFor(key)
    if key == "general" then
        return {
            { key = "look", label = L["Appearance"] },
            { key = "font", label = "Font" },
            { key = "window", label = L["Window"] },
            { key = "debug", label = "Debug" },
        }
    elseif key == "savedraids" then
        return { { key = "main", label = "Saved Raids" } }
    elseif key == "macros" then
        return {
            { key = "layout", label = "Bar Layout" },
            { key = "editor", label = "Macro Editor" },
        }
    elseif key == "raidframe" then
        return {
            { key = "layout", label = "Layout" },
            { key = "pos", label = L["Position"] },
        }
    end
    return { { key = "layout", label = "Layout" } }
end

function CFG:LayoutPanelForSubtabs(showBar)
    if not self.panel then return end
    self.panel:ClearAllPoints()
    if showBar then
        self.subTabBar:Show()
        self.panel:SetPoint("TOPLEFT", self.subTabBar, "BOTTOMLEFT", 0, -6)
    else
        self.subTabBar:Hide()
        self.panel:SetPoint("TOPLEFT", self.right, "TOPLEFT", 8, -8)
    end
    self.panel:SetPoint("BOTTOMRIGHT", self.right, "BOTTOMRIGHT", -8, 8)
end

function CFG:BuildSubtabs(subs)
    if self.subTabBtns then
        for _, b in ipairs(self.subTabBtns) do
            b:Hide()
            b:SetParent(nil)
        end
    end
    self.subTabBtns = {}
    local show = subs and #subs > 1
    self:LayoutPanelForSubtabs(show)
    if not show then return end
    for i, s in ipairs(subs) do
        local btn = CreateFrame("Button", nil, self.subTabBar, "UIPanelButtonTemplate")
        btn:SetSize(90, 20)
        btn:SetPoint("LEFT", self.subTabBar, "LEFT", (i - 1) * 96, 0)
        btn:SetText(s.label)
        btn.subKey = s.key
        btn:SetScript("OnClick", function() self:SelectSubtab(s.key) end)
        self.subTabBtns[i] = btn
    end
end

function CFG:SelectSubtab(key)
    self.currentSub = key
    for _, btn in ipairs(self.subTabBtns or {}) do
        if btn.subKey == key then btn:LockHighlight() else btn:UnlockHighlight() end
    end
    self:RebuildPanel()
end

function CFG:WipePanel()
    if self.scroll then
        self.scroll:Hide()
        self.scroll:SetParent(nil)
    end
    if self.content then
        self.content:Hide()
        self.content:SetParent(nil)
    end
    self.widgetId = (self.widgetId or 0) + 1
    local scroll = CreateFrame("ScrollFrame", "RLSuiteCfgScroll" .. self.widgetId, self.panel)
    scroll:SetAllPoints(self.panel)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", "RLSuiteCfgContent" .. self.widgetId, scroll)
    content:SetWidth(400)
    content:SetHeight(400)
    scroll:SetScrollChild(content)
    local function fit()
        local w = scroll:GetWidth() or 0
        if w < 80 then w = 80 end
        content:SetWidth(w)
        local need = math.abs(self.y or 0) + 24
        local vis = scroll:GetHeight() or 0
        if need < vis then need = vis end
        if need < 80 then need = 80 end
        content:SetHeight(need)
    end
    scroll:SetScript("OnSizeChanged", function() fit() end)
    scroll:SetScript("OnMouseWheel", function(s, delta)
        local max = s:GetVerticalScrollRange() or 0
        local nxt = (s:GetVerticalScroll() or 0) - delta * 28
        if nxt < 0 then nxt = 0 end
        if nxt > max then nxt = max end
        s:SetVerticalScroll(nxt)
    end)
    -- Lo ScrollFrame cattura i click sull'area impostazioni: riporta il
    -- Config in primo piano anche quando si clicca qui (non solo sul titolo
    -- o sulla colonna delle categorie), cosi' con piu' finestre aperte non
    -- resta mai coperto dal background di un'altra finestra.
    scroll:SetScript("OnMouseDown", function()
        if CFG.frame and RLSuite.utils and RLSuite.utils.RaiseWindow then
            RLSuite.utils:RaiseWindow(CFG.frame)
        end
    end)
    self._fitPanel = fit
    self._rowLayouts = {}
    self.scroll = scroll
    self.content = content
    self.y = -4
end

function CFG:FinishPanel()
    if self._fitPanel then self._fitPanel() end
    for _, fn in ipairs(self._rowLayouts or {}) do
        fn()
    end
end

function CFG:NextY(h)
    local y = self.y
    self.y = self.y - (h or 30)
    return y
end

function CFG:RebuildPanel()
    self:WipePanel()
    self:HideMacroEditor()
    local cat, sub = self.currentCat, self.currentSub
    if cat == "macros" and sub == "editor" then
        self:ShowMacroEditor()
        return
    elseif cat == "general" and sub == "look" then
        self:PanelGeneralLook()
    elseif cat == "general" and sub == "font" then
        self:PanelGeneralFont()
    elseif cat == "general" and sub == "window" then
        self:PanelMain()
    elseif cat == "general" and sub == "debug" then
        self:PanelGeneralDebug()
    elseif cat == "savedraids" then
        self:PanelSavedRaids()
    elseif cat == "groupmaking" then
        self:PanelScale("groupmaking", "Groupmaking")
    elseif cat == "macros" and sub == "layout" then
        self:PanelMacroLayout()
    elseif cat == "raidframe" and sub == "layout" then
        self:PanelRaidLayout()
    elseif cat == "raidframe" and sub == "pos" then
        self:PanelRaidPos()
    elseif cat == "ms" then
        self:PanelScale("ms", "MS Manager")
    elseif cat == "loot" then
        self:PanelScale("loot", "Loot Manager")
    end
    self:FinishPanel()
end

-- ============================================================
-- Widgets
-- ============================================================

function CFG:Header(text)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, self:NextY(22))
    fs:SetText(text)
    return fs
end

function CFG:Note(text)
    local y = self:NextY(18)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    fs:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -8, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

function CFG:SnapSlider(val, minV, maxV, step)
    if val < minV then val = minV end
    if val > maxV then val = maxV end
    if not step or step <= 0 then return val end
    val = math.floor((val / step) + 0.5) * step
    if val < minV then val = minV end
    if val > maxV then val = maxV end
    if step >= 1 then
        return math.floor(val + 0.5)
    end
    return tonumber(string.format("%.2f", val))
end

function CFG:AddSlider(label, minV, maxV, step, getValue, setValue, sliderWidth)
    local y = self:NextY(42)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    fs:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -64, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    fs:SetTextColor(1, 0.82, 0)

    self.widgetId = self.widgetId + 1
    local edit = CreateFrame("EditBox", "RLSuiteCfgSliderEdit" .. self.widgetId, self.content, "InputBoxTemplate")
    edit:SetSize(52, 18)
    edit:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -8, y + 2)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(6)
    edit:SetJustifyH("CENTER")
    edit:SetFrameLevel((self.content:GetFrameLevel() or 1) + 8)
    if step >= 1 and minV >= 0 then
        edit:SetNumeric(true)
    end

    local sl = CreateFrame("Slider", "RLSuiteCfgSlider" .. self.widgetId, self.content, "OptionsSliderTemplate")
    sl:SetHeight(16)
    sl:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y - 16)
    sl:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -8, y - 16)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    local low = getglobal(sl:GetName() .. "Low")
    local high = getglobal(sl:GetName() .. "High")
    if low then low:Hide() end
    if high then high:Hide() end

    local function fmt(v)
        if step < 1 then return string.format("%.2f", v) end
        return tostring(math.floor(v + 0.5))
    end

    local applying = false
    local function commit(val, fromEdit)
        val = self:SnapSlider(val, minV, maxV, step)
        applying = true
        sl:SetValue(val)
        applying = false
        setValue(val)
        edit:SetText(fmt(val))
        if fromEdit then edit:ClearFocus() end
        self:ApplyAll()
        return val
    end

    sl:SetValue(getValue())
    edit:SetText(fmt(getValue()))

    sl:SetScript("OnValueChanged", function(s, val)
        if applying then return end
        commit(val, false)
    end)

    edit:SetScript("OnEnterPressed", function(s)
        local val = tonumber(s:GetText())
        if not val then
            s:SetText(fmt(getValue()))
            s:ClearFocus()
            return
        end
        commit(val, true)
    end)
    edit:SetScript("OnEscapePressed", function(s)
        s:SetText(fmt(getValue()))
        s:ClearFocus()
    end)
    edit:SetScript("OnEditFocusLost", function(s)
        local val = tonumber(s:GetText())
        if not val then
            s:SetText(fmt(getValue()))
            return
        end
        commit(val, false)
    end)
    return sl
end

function CFG:AddCheck(label, getValue, setValue)
    local y = self:NextY(28)
    local cb = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y)
    cb:SetChecked(getValue() and 1 or nil)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(s)
        setValue(s:GetChecked() and true or false)
        self:ApplyAll()
    end)
    return cb
end

function CFG:AddCheckGrid(items)
    for i, it in ipairs(items) do
        local col = (i - 1) % 2
        local y
        if col == 0 then
            y = self:NextY(26)
            self._gridY = y
        else
            y = self._gridY or self.y
        end
        local cb = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4 + col * 210, y)
        cb:SetChecked(it.get() and 1 or nil)
        local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        fs:SetText(it.label)
        cb:SetScript("OnClick", function(s)
            it.set(s:GetChecked() and true or false)
            self:ApplyAll()
        end)
    end
end

function CFG:AddTextArea(label, height, getValue, setValue)
    self:Header(label)
    local y = self:NextY(height + 6)
    local box = CreateFrame("Frame", nil, self.content)
    box:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    box:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -8, y)
    box:SetHeight(height)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    box:SetBackdropColor(0, 0, 0, 0.85)
    self.widgetId = self.widgetId + 1
    local edit = CreateFrame("EditBox", "RLSuiteCfgArea" .. self.widgetId, box)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 6)
    edit:EnableMouse(true)
    edit:SetText(getValue() or "")
    edit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    local ay = self:NextY(26)
    local acc = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    acc:SetSize(70, 20)
    acc:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, ay)
    acc:SetText("Accept")
    acc:SetScript("OnClick", function()
        setValue(edit:GetText() or "")
        self:ApplyAll()
    end)
    return edit
end

function CFG:AddColor(label, colorTbl)
    local y = self:NextY(28)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    fs:SetText(label)

    local swatch = CreateFrame("Button", nil, self.content)
    swatch:SetSize(22, 22)
    swatch:SetPoint("LEFT", fs, "LEFT", 150, 0)
    local tex = swatch:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(swatch)
    tex:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    tex:SetVertexColor(colorTbl.r or 1, colorTbl.g or 1, colorTbl.b or 1)
    local border = swatch:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    border:SetAllPoints(swatch)
    swatch:EnableMouse(true)
    swatch:RegisterForClicks("LeftButtonUp")
    swatch:SetScript("OnClick", function()
        local r0, g0, b0 = colorTbl.r, colorTbl.g, colorTbl.b
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            colorTbl.r, colorTbl.g, colorTbl.b = r, g, b
            tex:SetVertexColor(r, g, b)
            if self.db and self.db.appearance then
                self.db.appearance.theme = "custom"
            end
            CFG:ApplyAll()
        end
        ColorPickerFrame.cancelFunc = function()
            colorTbl.r, colorTbl.g, colorTbl.b = r0, g0, b0
            tex:SetVertexColor(r0, g0, b0)
            CFG:ApplyAll()
        end
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(colorTbl.r or 1, colorTbl.g or 1, colorTbl.b or 1)
        ColorPickerFrame:Show()
    end)
    return swatch
end

function CFG:AddDropdown(label, options, getValue, setValue)
    local y = self:NextY(42)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    fs:SetText(label)
    fs:SetTextColor(1, 0.82, 0)
    self.widgetId = self.widgetId + 1
    local dd = RLSuite.utils:CreateDropdown(self.content, "RLSuiteCfgDD" .. self.widgetId, 180, 22)
    dd:ClearAllPoints()
    dd:SetHeight(22)
    dd:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y - 16)
    dd:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -8, y - 16)
    RLSuite.utils:SetupDropdown(dd, options, getValue(), function(value)
        setValue(value)
        self:ApplyAll()
    end)
    return dd
end

function CFG:AddInline(items)
    local y = self:NextY(26)
    local prev
    for _, it in ipairs(items) do
        if it.type == "button" then
            local btn = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
            btn:SetSize(it.width or 100, 20)
            if prev then
                btn:SetPoint("LEFT", prev, "RIGHT", 12, 0)
            else
                btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y - 2)
            end
            btn:SetText(it.label)
            btn:SetScript("OnClick", it.click)
            prev = btn
        else
            local cb = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
            if prev then
                cb:SetPoint("LEFT", prev, "RIGHT", 12, 0)
            else
                cb:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y + 2)
            end
            cb:SetChecked(it.get() and 1 or nil)
            local lfs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lfs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            lfs:SetText(it.label)
            cb:SetScript("OnClick", function(s)
                it.set(s:GetChecked() and true or false)
                self:ApplyAll()
            end)
            prev = lfs
        end
    end
end


function CFG:Row3(height)
    local y = self:NextY(height)
    local row = CreateFrame("Frame", nil, self.content)
    row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y)
    row:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -4, y)
    row:SetHeight(height)
    local cells = {}
    for i = 1, 3 do
        local c = CreateFrame("Frame", nil, row)
        c:SetHeight(height)
        cells[i] = c
    end
    local function layout()
        local w = row:GetWidth() or 0
        if w < 90 then return end
        local gap = 8
        local cw = (w - gap * 2) / 3
        for i = 1, 3 do
            local c = cells[i]
            c:ClearAllPoints()
            c:SetWidth(cw)
            c:SetHeight(height)
            c:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (cw + gap), 0)
        end
    end
    row:SetScript("OnSizeChanged", function() layout() end)
    self._rowLayouts = self._rowLayouts or {}
    table.insert(self._rowLayouts, layout)
    layout()
    return cells[1], cells[2], cells[3]
end

function CFG:CellCheck(cell, label, getValue, setValue)
    if not cell then return end
    local cb = CreateFrame("CheckButton", nil, cell, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 2)
    cb:SetChecked(getValue() and 1 or nil)
    local fs = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    cb:SetScript("OnClick", function(s)
        setValue(s:GetChecked() and true or false)
        self:ApplyAll()
    end)
    return cb
end

function CFG:CellButton(cell, label, onClick)
    if not cell then return end
    local btn = CreateFrame("Button", nil, cell, "UIPanelButtonTemplate")
    btn:SetHeight(20)
    btn:SetPoint("TOPLEFT", cell, "TOPLEFT", 4, -2)
    btn:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -4, -2)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

function CFG:CellTwoButtons(cell, label1, onClick1, label2, onClick2)
    if not cell then return end
    local b1 = CreateFrame("Button", nil, cell, "UIPanelButtonTemplate")
    b1:SetHeight(20)
    b1:SetText(label1)
    b1:SetScript("OnClick", onClick1)
    local b2 = CreateFrame("Button", nil, cell, "UIPanelButtonTemplate")
    b2:SetHeight(20)
    b2:SetText(label2)
    b2:SetScript("OnClick", onClick2)
    local function layout()
        local w = cell:GetWidth() or 0
        if w < 40 then return end
        local gap = 4
        local bw = math.max(24, math.floor((w - gap) / 2))
        b1:ClearAllPoints()
        b1:SetWidth(bw)
        b1:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, -2)
        b2:ClearAllPoints()
        b2:SetWidth(bw)
        b2:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 0, -2)
    end
    cell:SetScript("OnSizeChanged", function() layout() end)
    layout()
    return b1, b2
end

function CFG:CellDropdown(cell, label, options, getValue, setValue)
    if not cell then return end
    local fs = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", cell, "TOPLEFT", 2, -2)
    fs:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 0, -2)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    fs:SetTextColor(1, 0.82, 0)
    self.widgetId = (self.widgetId or 0) + 1
    local dd = RLSuite.utils:CreateDropdown(cell, "RLSuiteCfgDD" .. self.widgetId, 80, 22)
    dd:ClearAllPoints()
    dd:SetHeight(22)
    dd:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, -16)
    dd:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 0, -16)
    RLSuite.utils:SetupDropdown(dd, options, getValue(), function(value)
        setValue(value)
        self:ApplyAll()
    end)
    return dd
end

function CFG:CellSlider(cell, label, minV, maxV, step, getValue, setValue)
    if not cell then return end
    local fs = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", cell, "TOPLEFT", 2, -2)
    fs:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -42, -2)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    fs:SetTextColor(1, 0.82, 0)

    self.widgetId = (self.widgetId or 0) + 1
    local edit = CreateFrame("EditBox", "RLSuiteCfgSliderEdit" .. self.widgetId, cell, "InputBoxTemplate")
    edit:SetSize(40, 16)
    edit:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 0, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(6)
    edit:SetJustifyH("CENTER")
    edit:SetFrameLevel((cell:GetFrameLevel() or 1) + 8)
    if step >= 1 and minV >= 0 then edit:SetNumeric(true) end

    local sl = CreateFrame("Slider", "RLSuiteCfgSlider" .. self.widgetId, cell, "OptionsSliderTemplate")
    sl:SetHeight(16)
    sl:SetPoint("TOPLEFT", cell, "TOPLEFT", 2, -18)
    sl:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 0, -18)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    local low = getglobal(sl:GetName() .. "Low")
    local high = getglobal(sl:GetName() .. "High")
    if low then low:Hide() end
    if high then high:Hide() end

    local function fmt(v)
        if step < 1 then return string.format("%.2f", v) end
        return tostring(math.floor(v + 0.5))
    end
    local applying = false
    local function commit(val, fromEdit)
        val = self:SnapSlider(val, minV, maxV, step)
        applying = true
        sl:SetValue(val)
        applying = false
        setValue(val)
        edit:SetText(fmt(val))
        if fromEdit then edit:ClearFocus() end
        self:ApplyAll()
        return val
    end
    local cur = getValue() or minV
    sl:SetValue(cur)
    edit:SetText(fmt(cur))
    sl:SetScript("OnValueChanged", function(s, val)
        if applying then return end
        commit(val, false)
    end)
    edit:SetScript("OnEnterPressed", function(s)
        local val = tonumber(s:GetText())
        if not val then s:SetText(fmt(getValue() or minV)) s:ClearFocus() return end
        commit(val, true)
    end)
    edit:SetScript("OnEscapePressed", function(s)
        s:SetText(fmt(getValue() or minV))
        s:ClearFocus()
    end)
    edit:SetScript("OnEditFocusLost", function(s)
        local val = tonumber(s:GetText())
        if not val then s:SetText(fmt(getValue() or minV)) return end
        commit(val, false)
    end)
    return sl
end

function CFG:PlaceCheck(x, y, label, getValue, setValue)
    local cb = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
    cb:SetChecked(getValue() and 1 or nil)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(s)
        setValue(s:GetChecked() and true or false)
        self:ApplyAll()
    end)
    return cb
end

function CFG:PlaceCompactSlider(x, y, width, label, minV, maxV, step, getValue, setValue)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
    fs:SetText(label)
    fs:SetTextColor(1, 0.82, 0)
    self.widgetId = (self.widgetId or 0) + 1
    local edit = CreateFrame("EditBox", "RLSuiteCfgSliderEdit" .. self.widgetId, self.content, "InputBoxTemplate")
    edit:SetSize(40, 16)
    edit:SetPoint("TOPRIGHT", self.content, "TOPLEFT", x + width, y + 2)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(6)
    edit:SetJustifyH("CENTER")
    edit:SetFrameLevel((self.content:GetFrameLevel() or 1) + 6)
    if step >= 1 and minV >= 0 then edit:SetNumeric(true) end
    local sl = CreateFrame("Slider", "RLSuiteCfgSlider" .. self.widgetId, self.content, "OptionsSliderTemplate")
    sl:SetHeight(16)
    sl:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y - 16)
    sl:SetPoint("TOPRIGHT", self.content, "TOPLEFT", x + width, y - 16)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    local low = getglobal(sl:GetName() .. "Low")
    local high = getglobal(sl:GetName() .. "High")
    if low then low:Hide() end
    if high then high:Hide() end
    local function fmt(v)
        if step < 1 then return string.format("%.2f", v) end
        return tostring(math.floor(v + 0.5))
    end
    local applying = false
    local function commit(val)
        val = self:SnapSlider(val, minV, maxV, step)
        applying = true
        sl:SetValue(val)
        applying = false
        setValue(val)
        edit:SetText(fmt(val))
        self:ApplyAll()
        return val
    end
    sl:SetValue(getValue())
    edit:SetText(fmt(getValue()))
    sl:SetScript("OnValueChanged", function(s, val)
        if applying then return end
        commit(val)
    end)
    edit:SetScript("OnEnterPressed", function(s)
        local val = tonumber(s:GetText())
        if not val then s:SetText(fmt(getValue())) s:ClearFocus() return end
        commit(val)
        s:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function(s)
        s:SetText(fmt(getValue()))
        s:ClearFocus()
    end)
    edit:SetScript("OnEditFocusLost", function(s)
        local val = tonumber(s:GetText())
        if not val then s:SetText(fmt(getValue())) return end
        commit(val)
    end)
    return sl
end

function CFG:PlaceDropdown(x, y, width, label, options, getValue, setValue)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
    fs:SetText(label)
    fs:SetTextColor(1, 0.82, 0)
    self.widgetId = (self.widgetId or 0) + 1
    local dd = RLSuite.utils:CreateDropdown(self.content, "RLSuiteCfgDD" .. self.widgetId, width, 22)
    dd:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y - 16)
    RLSuite.utils:SetupDropdown(dd, options, getValue(), function(value)
        setValue(value)
        self:ApplyAll()
    end)
    return dd
end

function CFG:PlaceTextArea(x, y, width, height, label, getValue, setValue)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
    fs:SetText(label)
    fs:SetTextColor(1, 0.82, 0)
    local box = CreateFrame("Frame", nil, self.content)
    box:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y - 16)
    if width then
        box:SetSize(width, height)
    else
        box:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -8, y - 16)
        box:SetHeight(height)
    end
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    box:SetBackdropColor(0, 0, 0, 0.9)
    self.widgetId = (self.widgetId or 0) + 1
    local edit = CreateFrame("EditBox", "RLSuiteCfgArea" .. self.widgetId, box)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
    edit:EnableMouse(true)
    edit:SetText(getValue() or "")
    edit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    local acc = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    acc:SetSize(64, 18)
    acc:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
    acc:SetText("Accept")
    acc:SetScript("OnClick", function()
        setValue(edit:GetText() or "")
        self:ApplyAll()
    end)
    return edit
end

-- ============================================================
-- Panels
-- ============================================================

function CFG:EnsureAppearance()
    local a = self.db.appearance
    a.bg = a.bg or { r = 0.08, g = 0.08, b = 0.10, a = 1 }
    a.fill = a.fill or { r = 0.05, g = 0.05, b = 0.07, a = 1 }
    a.border = a.border or { r = 0.70, g = 0.70, b = 0.70, a = 1 }
    return a
end

function CFG:PanelGeneralLook()
    local a = self:EnsureAppearance()
    self:Header(L["General Appearance"])
    self:Note(L["Presets and background/border colors. Does not change functionality."])
    self:AddDropdown(L["Theme:"], {
        { text = "Default", value = "default" },
        { text = "Dark", value = "dark" },
        { text = "Gold", value = "gold" },
        { text = "Custom", value = "custom" },
    }, function() return a.theme or "default" end, function(v)
        a.theme = v
        if v ~= "custom" then
            local p = RLSuite.utils:ThemePresets()[v]
            if p then
                a.fill = { r = p.fill[1], g = p.fill[2], b = p.fill[3], a = 1 }
                a.bg = { r = p.bg[1], g = p.bg[2], b = p.bg[3], a = 1 }
                a.border = { r = p.border[1], g = p.border[2], b = p.border[3], a = 1 }
            end
        end
    end)
    self:AddColor(L["Background:"], a.fill)
    self:AddColor(L["Panel background:"], a.bg)
    self:AddColor(L["Borders:"], a.border)
    self:AddSlider(L["Border thickness"], 8, 48, 2, function() return a.edgeSize or 32 end, function(v) a.edgeSize = v end)
end

function CFG:PanelGeneralFont()
    local a = self:EnsureAppearance()
    self:Header("Font")
    self:AddDropdown("Font:", {
        { text = "Friz Quadrata", value = "Fonts\\FRIZQT__.TTF" },
        { text = "Arial Narrow", value = "Fonts\\ARIALN.TTF" },
        { text = "Morpheus", value = "Fonts\\MORPHEUS.TTF" },
        { text = "Skurri", value = "Fonts\\SKURRI.TTF" },
    }, function() return a.font or "Fonts\\FRIZQT__.TTF" end, function(v) a.font = v end)
    self:AddSlider(L["Font size"], 8, 20, 1, function() return a.fontSize or 12 end, function(v) a.fontSize = v end)
end

function CFG:Layout(key)
    self.db.layout = self.db.layout or {}
    self.db.layout[key] = self.db.layout[key] or { scale = 1 }
    return self.db.layout[key]
end

function CFG:PanelGeneralDebug()
    self:Header("Debug mode")
    self:Note(L["Simulates a raid group. Macros, LFM, rolls, loot and MS changes are whispered to you. Fake loot uses the raid selected in Groupmaking."])
    self:AddCheck(L["Enable debug mode"], function()
        return RLSuiteDB.debug == true
    end, function(v)
        RLSuiteDB.debug = v and true or false
        if RLSuite.ApplyDebugMode then
            RLSuite:ApplyDebugMode()
        end
    end)
    local y = self:NextY(28)
    local btn = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    btn:SetSize(160, 22)
    btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    btn:SetText(L["Fill fake loot"])
    btn:SetScript("OnClick", function()
        if RLSuite.lootManager and RLSuite.lootManager.SpawnDebugLoot then
            RLSuite.lootManager:SpawnDebugLoot()
        end
    end)
end

function CFG:PanelMain()
    local lay = self:Layout("main")
    lay.height = lay.height or 700
    lay.scale = lay.scale or 1
    lay.matrixCols = lay.matrixCols or 2
    lay.matrixRows = lay.matrixRows or 4
    self:Header(L["Bar and tab windows"])
    self:Note(L["The bar automatically adapts to the matrix and the top icon row (Config, SaveRaid, phase). Here you set the default height of the tab windows and the bar scale."])
    self:AddSlider(L["Default window height"], 400, 900, 20, function() return lay.height end, function(v) lay.height = v end, 220)
    self:AddSlider(L["Bar scale"], 0.70, 1.30, 0.05, function() return lay.scale end, function(v) lay.scale = v end, 220)

    self:Header(L["Button matrix (bar only)"])
    self:Note(L["How many columns and buttons per column to use for the bar buttons. Above the matrix sit the icons (Config, SaveRaid, phase); the phase icon shows the current phase and cycles to the next on click."])
    self:AddSlider(L["Columns"], 1, 8, 1, function() return lay.matrixCols end, function(v) lay.matrixCols = v end, 220)
    self:AddSlider(L["Buttons per column"], 1, 8, 1, function() return lay.matrixRows end, function(v) lay.matrixRows = v end, 220)

    self:Header(L["HUD anchors (ElvUI style)"])
    self:Note(L["Unlocks the Raid Frame and MacroBar HUDs and shows them as movable placeholders. Other windows stay as usual."])
    local cb = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, self:NextY(24))
    cb:SetChecked(RLSuiteDB.anchorMode and 1 or nil)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText("Toggle Anchors")
    fs:SetTextColor(1, 0.82, 0)
    cb:SetScript("OnClick", function(s)
        local on = s:GetChecked() and true or false
        if RLSuite.ApplyAnchorMode then
            RLSuite:ApplyAnchorMode(on)
        end
    end)
    self.anchorCheck = cb
end

function CFG:UpdateAnchorCheck()
    if self.anchorCheck then
        self.anchorCheck:SetChecked(RLSuiteDB.anchorMode and 1 or nil)
    end
end

function CFG:PanelScale(key, title)
    local lay = self:Layout(key)
    lay.scale = lay.scale or 1
    self:Header(title)
    self:AddSlider(L["Scale"], 0.70, 1.30, 0.05, function() return lay.scale end, function(v) lay.scale = v end, 220)
end

function CFG:RestoreMacroBar()
    if RLSuite.macrobar and RLSuite.macrobar.EnsurePhases then
        RLSuite.macrobar:EnsurePhases()
    end
    local mb = RLSuiteDB.macrobar
    mb.enabled = true
    mb.locked = true
    mb.backdrop = true
    mb.showEmpty = true
    mb.mouseover = false
    mb.inheritGlobalFade = false
    mb.buttons = 12
    mb.columns = 12
    mb.buttonSize = 32
    mb.spacing = 2
    mb.backdropSpacing = 2
    mb.heightMult = 1
    mb.widthMult = 1
    mb.alpha = 1
    mb.scale = 1
    mb.point, mb.relPoint, mb.x, mb.y = "BOTTOMLEFT", "BOTTOMLEFT", 4, 4
    mb.actionPaging = "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 8; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10;"
    mb.visibility = ""
    mb.keybinds = {}
    if RLSuite.macrobar and RLSuite.macrobar.frame then
        RLSuite.macrobar.frame:ClearAllPoints()
        RLSuite.macrobar.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 4, 4)
    end
    self:ApplyAll()
    self:RebuildPanel()
end

function CFG:PanelMacroLayout()
    self.db = RLSuiteDB
    if RLSuite.macrobar and RLSuite.macrobar.EnsurePhases then
        RLSuite.macrobar:EnsurePhases()
    end
    local mb = RLSuiteDB.macrobar
    mb.buttons = mb.buttons or 12
    mb.columns = mb.columns or 12
    mb.buttonSize = mb.buttonSize or 32
    mb.spacing = mb.spacing or 2
    mb.backdropSpacing = mb.backdropSpacing or 2
    mb.heightMult = mb.heightMult or 1
    mb.widthMult = mb.widthMult or 1
    mb.alpha = mb.alpha or 1
    mb.scale = mb.scale or 1
    mb.actionPaging = mb.actionPaging or ""
    mb.visibility = mb.visibility or ""

    self:Header("Macrobar")
    self:Note(L["The visible HUD buttons match the macros filled in the current phase."])

    local c1, c2, c3 = self:Row3(26)
    self:CellCheck(c1, "Enable", function() return mb.enabled ~= false end, function(v) mb.enabled = v end)
    self:CellCheck(c2, "Lock", function() return mb.locked end, function(v) mb.locked = v end)
    self:CellTwoButtons(c3, "Restore Bar", function()
        self:RestoreMacroBar()
    end, "Keybind", function()
        if RLSuite.macrobar and RLSuite.macrobar.OpenKeybindUI then
            RLSuite.macrobar:OpenKeybindUI()
        end
    end)

    c1, c2, c3 = self:Row3(26)
    self:CellCheck(c1, "Backdrop", function() return mb.backdrop ~= false end, function(v) mb.backdrop = v end)
    self:CellCheck(c2, "Mouse Over", function() return mb.mouseover end, function(v) mb.mouseover = v end)
    self:CellCheck(c3, "Inherit Global Fade", function() return mb.inheritGlobalFade end, function(v) mb.inheritGlobalFade = v end)

    local anchors = {
        { text = "TOPLEFT", value = "TOPLEFT" },
        { text = "TOP", value = "TOP" },
        { text = "TOPRIGHT", value = "TOPRIGHT" },
        { text = "LEFT", value = "LEFT" },
        { text = "CENTER", value = "CENTER" },
        { text = "RIGHT", value = "RIGHT" },
        { text = "BOTTOMLEFT", value = "BOTTOMLEFT" },
        { text = "BOTTOM", value = "BOTTOM" },
        { text = "BOTTOMRIGHT", value = "BOTTOMRIGHT" },
    }
    c1, c2, c3 = self:Row3(44)
    self:CellDropdown(c1, "Anchor Point", anchors, function() return mb.point or "CENTER" end, function(v)
        mb.point = v
        mb.relPoint = v
    end)
    self:CellSlider(c2, "Buttons Per Row", 1, 12, 1, function() return mb.columns end, function(v) mb.columns = v end)

    c1, c2, c3 = self:Row3(44)
    self:CellSlider(c1, "Button Size", 15, 60, 1, function() return mb.buttonSize end, function(v) mb.buttonSize = v end)
    self:CellSlider(c2, "Button Spacing", -3, 20, 1, function() return mb.spacing end, function(v) mb.spacing = v end)
    self:CellSlider(c3, "Backdrop Spacing", 0, 10, 1, function() return mb.backdropSpacing end, function(v) mb.backdropSpacing = v end)

    c1, c2, c3 = self:Row3(44)
    self:CellSlider(c1, "Height Multiplier", 1, 5, 1, function() return mb.heightMult end, function(v) mb.heightMult = v end)
    self:CellSlider(c2, "Width Multiplier", 1, 5, 1, function() return mb.widthMult end, function(v) mb.widthMult = v end)
    self:CellSlider(c3, "Alpha", 0, 100, 1, function() return math.floor((mb.alpha or 1) * 100 + 0.5) end, function(v) mb.alpha = v / 100 end)

    c1, c2, c3 = self:Row3(44)
    self:CellSlider(c1, "Scale", 0.50, 2.00, 0.05, function() return mb.scale or 1 end, function(v) mb.scale = v end)

    self:AddTextArea("Action Paging", 52, function() return mb.actionPaging end, function(v) mb.actionPaging = v end)
    self:AddTextArea("Visibility State", 52, function() return mb.visibility end, function(v) mb.visibility = v end)
end

function CFG:PanelRaidLayout()
    local rf = self.db.raidframe
    rf.appearance = rf.appearance or {}
    rf.width = rf.width or 350
    rf.scale = rf.scale or 1
    self:Header(L["Raid Frame - HUD layout"])
    self:AddSlider(L["Width"], 220, 500, 20, function() return rf.width end, function(v) rf.width = v end, 220)
    self:AddSlider(L["HP bar height"], 12, 32, 1, function() return rf.appearance.barHeight or 20 end, function(v) rf.appearance.barHeight = v end)
    self:AddSlider(L["Icon size"], 10, 24, 1, function() return rf.appearance.iconSize or 16 end, function(v) rf.appearance.iconSize = v end)
    self:AddSlider(L["Scale"], 0.70, 1.50, 0.05, function() return rf.scale end, function(v) rf.scale = v end, 220)
end

function CFG:PanelRaidPos()
    local rf = self.db.raidframe
    self:Header(L["Raid Frame - position"])
    self:AddCheck(L["Lock position"], function() return rf.locked end, function(v) rf.locked = v end)
    local y = self:NextY(28)
    local btn = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    btn:SetSize(160, 22)
    btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    btn:SetText(L["Reset position"])
    btn:SetScript("OnClick", function()
        rf.point, rf.relPoint, rf.x, rf.y = "LEFT", "LEFT", 10, 0
        if RLSuite.raidFrame and RLSuite.raidFrame.frame then
            RLSuite.raidFrame.frame:ClearAllPoints()
            RLSuite.raidFrame.frame:SetPoint("LEFT", UIParent, "LEFT", 10, 0)
        end
    end)
end

-- ============================================================
-- Saved Raids
-- ============================================================

function CFG:PanelSavedRaids()
    self:Header("Saved Raids")
    self:Note(L["Saves created with the SaveRaid button in the top bar. Click Load to restore Comp, MacroBar and Config (except General)."])
    local list = RLSuiteDB.savedRaids or {}
    if #list == 0 then
        self:Note(L["No saves yet."])
        return
    end
    for i, e in ipairs(list) do
        local y = self:NextY(30)
        local row = CreateFrame("Frame", nil, self.content)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
        row:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -8, y)
        RLSuite.utils:SkinRow(row, false)

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("LEFT", row, "LEFT", 8, 0)
        title:SetPoint("RIGHT", row, "RIGHT", -150, 0)
        title:SetJustifyH("LEFT")
        title:SetText(e.title or string.format(L["Save #%d"], i))
        if e.title then title:SetTextColor(0.9, 0.9, 0.9) end

        local loadBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        loadBtn:SetSize(60, 20)
        loadBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        loadBtn:SetText("Load")
        loadBtn:SetScript("OnClick", function()
            if RLSuite.LoadRaid then
                RLSuite:LoadRaid(e.id)
            end
        end)

        local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        delBtn:SetSize(60, 20)
        delBtn:SetPoint("RIGHT", loadBtn, "LEFT", -6, 0)
        delBtn:SetText("Delete")
        delBtn:SetScript("OnClick", function()
            if RLSuite.DeleteSavedRaid then
                RLSuite:DeleteSavedRaid(e.id)
            end
            self:RebuildPanel()
        end)
    end
end

-- ============================================================
-- Macros: editor 12 slot (spostato qui dalla finestra principale)
-- ============================================================

-- Apre il Config sulla categoria Macros -> Macro Editor.
function CFG:OpenMacroEditorPanel()
    if self.frame then
        self.frame:Show()
        if RLSuite.utils and RLSuite.utils.RaiseWindow then
            RLSuite.utils:RaiseWindow(self.frame)
        end
    end
    self:SelectCategory("macros")
    self:SelectSubtab("editor")
end

function CFG:HideMacroEditor()
    if self.macroEditorPanel then
        self.macroEditorPanel:Hide()
    end
    if self.macroIconPicker then
        self.macroIconPicker:Hide()
    end
end

function CFG:ShowMacroEditor()
    if not self.macroEditorPanel then
        self:CreateMacroEditor()
    end
    if self.scroll then self.scroll:Hide() end
    if self.content then self.content:Hide() end
    self.macroEditorPanel:Show()
    self:RefreshMacroTab()
    self:OpenMacroEditor(self.macroEditIndex or 1)
end

function CFG:CreateMacroEditor()
    local ed = CreateFrame("Frame", "RLSuiteCfgMacroEditor", self.panel)
    ed:SetAllPoints(self.panel)
    ed:Hide()
    ed:EnableMouse(true)
    ed:SetScript("OnMouseDown", function()
        if CFG.frame and RLSuite.utils and RLSuite.utils.RaiseWindow then
            RLSuite.utils:RaiseWindow(CFG.frame)
        end
    end)
    self.macroEditorPanel = ed

    self.macroPhase = RLSuite.context or "preraid"
    self.macroPreviewBtns = {}
    self.macroPhaseBtns = {}
    self.macroLoading = false
    self.macroEditIndex = nil
    self.macroEditIcon = nil

    -- riga 1: selezione fase + toggle HUD
    local phaseLabel = ed:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    phaseLabel:SetPoint("TOPLEFT", ed, "TOPLEFT", 10, -8)
    phaseLabel:SetText(L["Phase:"])

    local phases = {
        {key = "preraid", label = "Pre-raid"},
        {key = "preboss", label = "Pre-boss"},
        {key = "infight", label = "In-fight"},
    }
    for i, pdata in ipairs(phases) do
        local btn = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
        btn:SetSize(70, 20)
        btn:SetPoint("LEFT", phaseLabel, "RIGHT", 6 + (i - 1) * 76, 0)
        btn:SetText(pdata.label)
        btn.phaseKey = pdata.key
        btn:SetScript("OnClick", function()
            self:SelectMacroPhase(pdata.key)
        end)
        self.macroPhaseBtns[pdata.key] = btn
    end

    local hudBtn = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
    hudBtn:SetSize(120, 20)
    hudBtn:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -8, -6)
    hudBtn:SetText("HUD on/off")
    hudBtn:SetScript("OnClick", function()
        if RLSuite.macrobar and RLSuite.macrobar.Toggle then
            RLSuite.macrobar:Toggle()
        end
    end)

    -- riga 2: anteprima 12 slot (2 righe x 6)
    local preview = CreateFrame("Frame", nil, ed)
    preview:SetPoint("TOPLEFT", phaseLabel, "BOTTOMLEFT", 0, -8)
    preview:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -8, -30)
    preview:SetHeight(90)
    RLSuite.utils:SkinBox(preview)
    self.macroPreview = preview

    for i = 1, 12 do
        local btn = CreateFrame("Button", nil, preview)
        btn:SetSize(36, 36)
        local col = (i - 1) % 6
        local row = math.floor((i - 1) / 6)
        btn:SetPoint("TOPLEFT", preview, "TOPLEFT", 8 + col * 44, -8 - row * 42)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        RLSuite.utils:SkinMacroButton(btn)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function()
            self:OpenMacroEditor(i)
        end)
        local num = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
        num:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        num:SetText(i)
        self.macroPreviewBtns[i] = btn
    end

    -- area editor sotto l'anteprima
    local editor = CreateFrame("Frame", "RLSuiteCfgMacroEditorBox", ed)
    editor:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -6)
    editor:SetPoint("BOTTOMRIGHT", ed, "BOTTOMRIGHT", -8, 8)
    RLSuite.utils:SkinBox(editor)
    editor:Show()
    self.macroEditor = editor

    -- elenco macro a destra
    local list = CreateFrame("Frame", nil, editor)
    list:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -6, -6)
    list:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -6, 6)
    list:SetWidth(150)
    RLSuite.utils:SkinBox(list)
    self.macroListFrame = list

    local listTitle = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listTitle:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -5)
    listTitle:SetText(L["All macros"])

    self.macroListRows = {}
    for i = 1, 12 do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(16)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -20 - (i - 1) * 17)
        row:SetPoint("RIGHT", list, "RIGHT", -4, 0)
        local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("LEFT", row, "LEFT", 2, 0)
        num:SetWidth(12)
        num:SetJustifyH("LEFT")
        num:SetText(tostring(i))
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", num, "RIGHT", 2, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        fs:SetJustifyH("LEFT")
        fs:SetText("")
        row.fs = fs
        row.idx = i
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", function()
            self:OpenMacroEditor(i)
        end)
        self.macroListRows[i] = row
    end

    -- lato sinistro: titolo slot, nome, icona
    local slotFS = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotFS:SetPoint("TOPLEFT", editor, "TOPLEFT", 8, -6)
    slotFS:SetText(L["Macro"])
    self.macroSlotFS = slotFS

    local nameLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", slotFS, "BOTTOMLEFT", 0, -6)
    nameLabel:SetText(L["Name:"])

    local nameEdit = CreateFrame("EditBox", "RLSuiteCfgMacroNameEdit", editor, "InputBoxTemplate")
    nameEdit:SetSize(110, 18)
    nameEdit:SetPoint("LEFT", nameLabel, "RIGHT", 4, 0)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(32)
    nameEdit:SetScript("OnTextChanged", function()
        self:SaveMacroSlot()
    end)
    nameEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    nameEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    self.macroNameEdit = nameEdit

    local iconBtn = CreateFrame("Button", nil, editor)
    iconBtn:SetSize(30, 30)
    iconBtn:SetPoint("LEFT", nameEdit, "RIGHT", 8, 0)
    iconBtn.icon = iconBtn:CreateTexture(nil, "ARTWORK")
    iconBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    iconBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    RLSuite.utils:SkinMacroButton(iconBtn)
    iconBtn:EnableMouse(true)
    iconBtn:RegisterForClicks("LeftButtonUp")
    iconBtn:SetScript("OnClick", function()
        self:ToggleMacroIconPicker()
    end)
    self.macroIconBtn = iconBtn

    -- corpo della macro
    local bodyFrame = CreateFrame("Frame", nil, editor)
    bodyFrame:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -6)
    bodyFrame:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 8, 26)
    bodyFrame:SetPoint("RIGHT", list, "LEFT", -6, 0)
    bodyFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    bodyFrame:SetBackdropColor(0, 0, 0, 0.85)
    self.macroBodyFrame = bodyFrame

    local body = CreateFrame("EditBox", "RLSuiteCfgMacroBodyEdit", bodyFrame)
    body:SetMultiLine(true)
    body:SetAutoFocus(false)
    body:SetFontObject(ChatFontNormal)
    body:SetTextInsets(6, 6, 6, 6)
    body:SetMaxLetters(1024)
    body:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", 6, -6)
    body:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", -6, 6)
    body:EnableMouse(true)
    body:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    body:SetScript("OnTextChanged", function()
        self:SaveMacroSlot()
    end)
    self.macroBodyEdit = body

    -- barra utility: target marker + CAPS
    local util = CreateFrame("Frame", nil, editor)
    util:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 8, 5)
    util:SetPoint("RIGHT", list, "LEFT", -6, 0)
    util:SetHeight(20)
    self.macroUtilBar = util

    local raidIcons = {
        { token = "{rt1}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
        { token = "{rt2}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
        { token = "{rt3}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
        { token = "{rt4}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
        { token = "{rt5}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
        { token = "{rt6}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
        { token = "{rt7}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
        { token = "{rt8}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    }
    for i, data in ipairs(raidIcons) do
        local ib = CreateFrame("Button", nil, util)
        ib:SetSize(18, 18)
        ib:SetPoint("LEFT", util, "LEFT", (i - 1) * 22, 0)
        local tex = ib:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(ib)
        tex:SetTexture(data.tex)
        ib:EnableMouse(true)
        ib:RegisterForClicks("LeftButtonUp")
        ib:SetScript("OnClick", function()
            self:InsertMacroText(data.token)
        end)
    end

    local capsBtn = CreateFrame("Button", nil, util, "UIPanelButtonTemplate")
    capsBtn:SetSize(56, 18)
    capsBtn:SetPoint("LEFT", util, "LEFT", 8 * 22 + 6, 0)
    capsBtn:SetText("CAPS")
    capsBtn:SetScript("OnClick", function()
        self:ToggleMacroCaps()
    end)

    self:HookMacroInsertLink()
    self:CreateMacroIconPicker(editor)
end

function CFG:HookMacroInsertLink()
    if self._insertLinkHooked then return end
    self._insertLinkHooked = true
    RLSuite.utils:RegisterInsertLink(self.macroBodyEdit, function()
        CFG:SaveMacroSlot()
    end)
end

function CFG:CreateMacroIconPicker(parent)
    local picker = CreateFrame("Frame", "RLSuiteCfgMacroIconPicker", parent)
    picker:SetSize(280, 220)
    picker:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 12, 44)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    RLSuite.utils:SkinFrame(picker)
    picker:Hide()
    picker:EnableMouse(true)
    self.macroIconPicker = picker

    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -8)
    title:SetText(L["Macro icon"])

    local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() picker:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "RLSuiteCfgMacroIconScroll", picker, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", picker, "TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -28, 8)
    scroll:SetScript("OnVerticalScroll", function(s, offset)
        FauxScrollFrame_OnVerticalScroll(s, offset, 32, function()
            CFG:UpdateMacroIconPicker()
        end)
    end)
    self.macroIconScroll = scroll

    self.macroIconBtns = {}
    local cols, rows, size, gap = 10, 6, 28, 2
    for i = 1, cols * rows do
        local btn = CreateFrame("Button", nil, picker)
        btn:SetSize(size, size)
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        btn:SetPoint("TOPLEFT", scroll, "TOPLEFT", col * (size + gap), -row * (size + gap))
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints(btn)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("OnClick", function(s)
            if s.texPath then
                CFG:SetMacroIcon(s.texPath)
            end
        end)
        self.macroIconBtns[i] = btn
    end
end

function CFG:GetMacroIconList()
    if self.macroIconList then return self.macroIconList end
    local list = {}
    if GetNumMacroIcons and GetMacroIconInfo then
        local n = GetNumMacroIcons() or 0
        for i = 1, n do
            local tex = GetMacroIconInfo(i)
            if tex then table.insert(list, tex) end
        end
    end
    if #list == 0 then
        table.insert(list, "Interface\\Icons\\INV_Misc_QuestionMark")
        if RLSuite.abilityByName then
            for _, meta in pairs(RLSuite.abilityByName) do
                if meta.icon then table.insert(list, meta.icon) end
            end
        end
    end
    self.macroIconList = list
    return list
end

function CFG:ToggleMacroIconPicker()
    if not self.macroIconPicker then return end
    if self.macroIconPicker:IsShown() then
        self.macroIconPicker:Hide()
        return
    end
    self:GetMacroIconList()
    self.macroIconPicker:Show()
    self:UpdateMacroIconPicker()
end

function CFG:UpdateMacroIconPicker()
    local list = self:GetMacroIconList()
    local cols, rows = 10, 6
    local per = cols * rows
    local numRows = math.ceil(#list / cols)
    FauxScrollFrame_Update(self.macroIconScroll, numRows, rows, 32)
    local offset = FauxScrollFrame_GetOffset(self.macroIconScroll) or 0
    for i = 1, per do
        local idx = offset * cols + i
        local btn = self.macroIconBtns[i]
        local tex = list[idx]
        if tex then
            btn.icon:SetTexture(tex)
            btn.texPath = tex
            btn:Show()
        else
            btn.texPath = nil
            btn:Hide()
        end
    end
end

function CFG:SetMacroIcon(tex)
    self.macroEditIcon = tex
    if self.macroIconBtn and self.macroIconBtn.icon then
        self.macroIconBtn.icon:SetTexture(tex)
    end
    if self.macroIconPicker then self.macroIconPicker:Hide() end
    self:SaveMacroSlot()
end

function CFG:OpenMacroEditor(index)
    self.macroEditIndex = index
    if self.macroEditor then self.macroEditor:Show() end
    if self.macroIconPicker then self.macroIconPicker:Hide() end
    for i, btn in ipairs(self.macroPreviewBtns or {}) do
        if btn and not btn.sel then
            btn.sel = btn:CreateTexture(nil, "OVERLAY")
            btn.sel:SetAllPoints(btn)
            btn.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            btn.sel:SetBlendMode("ADD")
            btn.sel:Hide()
        end
        if btn and btn.sel then
            if i == index then btn.sel:Show() else btn.sel:Hide() end
        end
    end
    if self.macroSlotFS then
        self.macroSlotFS:SetText("Macro " .. tostring(index))
    end
    local macros = self:GetMacroDB()
    local data = macros[index] or {}
    self.macroLoading = true
    self.macroEditIcon = data.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    if self.macroNameEdit then
        self.macroNameEdit:SetText(data.name or "")
    end
    if self.macroBodyEdit then
        self.macroBodyEdit:SetText(data.text or "")
        self.macroBodyEdit:SetFocus()
    end
    if self.macroIconBtn and self.macroIconBtn.icon then
        self.macroIconBtn.icon:SetTexture(self.macroEditIcon)
    end
    self.macroLoading = false
    self:RefreshMacroList()
end

function CFG:InsertMacroText(token)
    if not self.macroBodyEdit then return end
    self.macroBodyEdit:SetFocus()
    self.macroBodyEdit:Insert(token)
    self:SaveMacroSlot()
end

function CFG:ToggleMacroCaps()
    local edit = self.macroBodyEdit
    if not edit then return end
    local full = edit:GetText() or ""
    if full == "" then return end
    edit:SetFocus()
    edit:Insert("\001")
    local after = edit:GetText() or ""
    local pos = string.find(after, "\001", 1, true)
    local selected, s, e
    if not pos then
        selected, s, e = full, 1, string.len(full)
        edit:SetText(full)
    else
        local prefix = string.sub(after, 1, pos - 1)
        local suffix = string.sub(after, pos + 1)
        s = string.len(prefix) + 1
        e = string.len(full) - string.len(suffix)
        if e < s then
            selected, s, e = full, 1, string.len(full)
        else
            selected = string.sub(full, s, e)
            if selected == "" then
                selected, s, e = full, 1, string.len(full)
            end
        end
    end
    local repl
    if selected == string.upper(selected) then
        repl = string.lower(selected)
    else
        repl = string.upper(selected)
    end
    local newText = string.sub(full, 1, s - 1) .. repl .. string.sub(full, e + 1)
    self.macroLoading = true
    edit:SetText(newText)
    self.macroLoading = false
    self:SaveMacroSlot()
end

function CFG:SelectMacroPhase(phase)
    self.macroPhase = phase or "preraid"
    for key, btn in pairs(self.macroPhaseBtns or {}) do
        if key == self.macroPhase then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end
    self:RefreshMacroTab()
    if self.macroEditIndex then
        self:OpenMacroEditor(self.macroEditIndex)
    end
end

function CFG:GetMacroDB(phase)
    phase = phase or self.macroPhase or "preraid"
    if not RLSuiteDB or not RLSuiteDB.macrobar then return {} end
    RLSuiteDB.macrobar.macros = RLSuiteDB.macrobar.macros or {}
    RLSuiteDB.macrobar.macros[phase] = RLSuiteDB.macrobar.macros[phase] or {}
    return RLSuiteDB.macrobar.macros[phase]
end

function CFG:SaveMacroSlot()
    if self.macroLoading then return end
    local index = self.macroEditIndex
    if not index then return end
    local macros = self:GetMacroDB()
    local current = macros[index] or {}
    current.text = (self.macroBodyEdit and self.macroBodyEdit:GetText()) or current.text or ""
    current.name = (self.macroNameEdit and self.macroNameEdit:GetText()) or current.name or ""
    current.icon = self.macroEditIcon or current.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    macros[index] = current
    local phase = self.macroPhase or "preraid"
    if RLSuite.macrobar and RLSuite.macrobar.LoadMacrosForPhase then
        if (RLSuite.context or "preraid") == phase then
            RLSuite.macrobar:LoadMacrosForPhase(phase)
        end
    end
    self:RefreshMacroPreview()
end

function CFG:SaveMacroLine(index, text)
    local macros = self:GetMacroDB()
    local current = macros[index] or {text = "", icon = "Interface\\Icons\\INV_Misc_QuestionMark"}
    current.text = text or ""
    current.icon = current.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    macros[index] = current
    local phase = self.macroPhase or "preraid"
    if RLSuite.macrobar and RLSuite.macrobar.LoadMacrosForPhase then
        if (RLSuite.context or "preraid") == phase then
            RLSuite.macrobar:LoadMacrosForPhase(phase)
        end
    end
    self:RefreshMacroPreview()
end

function CFG:RefreshMacroTab()
    self:RefreshMacroPreview()
end

function CFG:MacroPreviewText(data)
    if not data then return "" end
    local name = data.name or ""
    local text = data.text or ""
    text = string.gsub(text, "\n", " | ")
    if name ~= "" and text ~= "" then
        return name .. "  " .. text
    end
    if name ~= "" then return name end
    return text
end

function CFG:RefreshMacroList()
    local macros = self:GetMacroDB(self.macroPhase)
    local sel = self.macroEditIndex
    for i, row in ipairs(self.macroListRows or {}) do
        local data = macros[i]
        if row.fs then
            local line = self:MacroPreviewText(data)
            if line == "" then line = " " end
            row.fs:SetText(line)
            if sel == i then
                row.fs:SetTextColor(1, 0.82, 0)
            else
                row.fs:SetTextColor(0.9, 0.9, 0.9)
            end
        end
    end
end

function CFG:RefreshMacroPreview()
    local macros = self:GetMacroDB(self.macroPhase)
    for i, btn in ipairs(self.macroPreviewBtns or {}) do
        local data = macros[i]
        if btn and btn.icon then
            local icon = (data and data.icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
            if data and ((data.text and data.text ~= "") or (data.name and data.name ~= "") or data.icon) then
                btn.icon:SetTexture(icon)
            else
                btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
    end
    self:RefreshMacroList()
end

-- ============================================================
-- Apply
-- ============================================================

function CFG:ApplyAll()
    self.db = RLSuiteDB
    if RLSuite.macrobar then
        RLSuite.macrobar.db = RLSuiteDB and RLSuiteDB.macrobar
        if RLSuite.macrobar.ApplyLayout then
            RLSuite.macrobar:ApplyLayout()
        end
    end
    RLSuite.utils:SkinAllWindows()
    if RLSuite.macrobar and RLSuite.macrobar.ApplyLayout then
        RLSuite.macrobar:ApplyLayout()
    end
    if RLSuite.raidFrame and RLSuite.raidFrame.ApplyLayout then
        RLSuite.raidFrame:ApplyLayout()
    end
    if RLSuite.mainWindow and RLSuite.mainWindow.ApplyLayout then
        RLSuite.mainWindow:ApplyLayout()
    end
    local lay = self.db.layout or {}
    local function scale(fr, key)
        if not fr or not lay[key] or not lay[key].scale then return end
        local parent = fr.GetParent and fr:GetParent()
        if RLSuite.mainWindow and RLSuite.mainWindow.frame and parent == RLSuite.mainWindow.frame then
            fr:SetScale(1)
            return
        end
        fr:SetScale(lay[key].scale)
    end
    scale(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame, "groupmaking")
    scale(RLSuite.msManager and RLSuite.msManager.frame, "ms")
    scale(RLSuite.lootManager and RLSuite.lootManager.frame, "loot")
    local mw = RLSuite.mainWindow
    if mw and mw.tabPanels then
        scale(mw.tabPanels.raidframe, "raidframe")
    end
    local font, size = RLSuite.utils:GetUIFont()
    if self.titleFS then self.titleFS:SetFont(font, size + 2) end
    if RLSuite.mainWindow and RLSuite.mainWindow.frame then
        -- title is first fontstring-ish; skip if missing
    end
end

function CFG:ApplyTheme(theme)
    local a = self:EnsureAppearance()
    if theme then a.theme = theme end
    if a.theme and a.theme ~= "custom" then
        local p = RLSuite.utils:ThemePresets()[a.theme]
        if p then
            a.fill = { r = p.fill[1], g = p.fill[2], b = p.fill[3], a = 1 }
            a.bg = { r = p.bg[1], g = p.bg[2], b = p.bg[3], a = 1 }
            a.border = { r = p.border[1], g = p.border[2], b = p.border[3], a = 1 }
        end
    end
    self:ApplyAll()
end
