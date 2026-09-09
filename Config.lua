-- ============================================================
-- RLSuite - Config (ElvUI-style: left categories, right subtabs)
-- Appearance / layout only — no feature settings.
-- ============================================================

RLSuite.config = {}
local CFG = RLSuite.config

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
        { key = "groupmaking", label = "Groupmaking" },
        { key = "whisplist",   label = "Whisplist" },
        { key = "macrobar",    label = "Macrobar" },
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
            { key = "look", label = "Aspetto" },
            { key = "font", label = "Font" },
            { key = "window", label = "Finestra" },
        }
    elseif key == "macrobar" then
        return {
            { key = "layout", label = "Barra" },
        }
    elseif key == "raidframe" then
        return {
            { key = "layout", label = "Layout" },
            { key = "pos", label = "Posizione" },
        }
    end
    return { { key = "layout", label = "Layout" } }
end

function CFG:BuildSubtabs(subs)
    if self.subTabBtns then
        for _, b in ipairs(self.subTabBtns) do
            b:Hide()
            b:SetParent(nil)
        end
    end
    self.subTabBtns = {}
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
    if self.content then
        self.content:Hide()
        self.content:SetParent(nil)
    end
    self.content = CreateFrame("Frame", nil, self.panel)
    self.content:SetAllPoints(self.panel)
    self.y = -4
    self.widgetId = self.widgetId or 0
end

function CFG:NextY(h)
    local y = self.y
    self.y = self.y - (h or 30)
    return y
end

function CFG:RebuildPanel()
    self:WipePanel()
    local cat, sub = self.currentCat, self.currentSub
    if cat == "general" and sub == "look" then
        self:PanelGeneralLook()
    elseif cat == "general" and sub == "font" then
        self:PanelGeneralFont()
    elseif cat == "general" and sub == "window" then
        self:PanelMain()
    elseif cat == "groupmaking" then
        self:PanelScale("groupmaking", "Groupmaking")
    elseif cat == "whisplist" then
        self:PanelScale("whisplist", "Whisplist")
    elseif cat == "macrobar" then
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
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, self:NextY(18))
    fs:SetWidth(420)
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
    local y = self:NextY(36)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    fs:SetText(label)

    self.widgetId = self.widgetId + 1
    local sl = CreateFrame("Slider", "RLSuiteCfgSlider" .. self.widgetId, self.content, "OptionsSliderTemplate")
    sl:SetSize(sliderWidth or 200, 16)
    sl:SetPoint("LEFT", fs, "LEFT", 150, 0)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    getglobal(sl:GetName() .. "Low"):SetText(tostring(minV))
    getglobal(sl:GetName() .. "High"):SetText(tostring(maxV))

    local edit = CreateFrame("EditBox", "RLSuiteCfgSliderEdit" .. self.widgetId, self.content, "InputBoxTemplate")
    edit:SetSize(48, 18)
    edit:SetPoint("LEFT", sl, "RIGHT", 12, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(6)
    if step >= 1 and minV >= 0 then
        edit:SetNumeric(true)
    end

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
    box:SetSize(410, height)
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
    local y = self:NextY(30)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    fs:SetText(label)
    self.widgetId = self.widgetId + 1
    local dd = RLSuite.utils:CreateDropdown(self.content, "RLSuiteCfgDD" .. self.widgetId, 180, 22)
    dd:SetPoint("LEFT", fs, "LEFT", 150, 0)
    RLSuite.utils:SetupDropdown(dd, options, getValue(), function(value)
        setValue(value)
        self:ApplyAll()
    end)
    return dd
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
    local sl = CreateFrame("Slider", "RLSuiteCfgSlider" .. self.widgetId, self.content, "OptionsSliderTemplate")
    sl:SetSize(width, 16)
    sl:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y - 14)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    local low = getglobal(sl:GetName() .. "Low")
    local high = getglobal(sl:GetName() .. "High")
    if low then low:SetText(tostring(minV)) end
    if high then high:SetText(tostring(maxV)) end
    local edit = CreateFrame("EditBox", "RLSuiteCfgSliderEdit" .. self.widgetId, self.content, "InputBoxTemplate")
    edit:SetSize(36, 16)
    edit:SetPoint("CENTER", sl, "CENTER", 0, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(6)
    if step >= 1 and minV >= 0 then edit:SetNumeric(true) end
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
    box:SetSize(width, height)
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
    self:Header("Aspetto generale")
    self:Note("Preset, colori sfondo/bordo. Non cambia le funzionalita'.")
    self:AddDropdown("Tema:", {
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
    self:AddColor("Sfondo:", a.fill)
    self:AddColor("Sfondo pannelli:", a.bg)
    self:AddColor("Bordi:", a.border)
    self:AddSlider("Spessore bordo", 8, 48, 2, function() return a.edgeSize or 32 end, function(v) a.edgeSize = v end)
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
    self:AddSlider("Grandezza font", 8, 20, 1, function() return a.fontSize or 12 end, function(v) a.fontSize = v end)
end

function CFG:Layout(key)
    self.db.layout = self.db.layout or {}
    self.db.layout[key] = self.db.layout[key] or { scale = 1 }
    return self.db.layout[key]
end

function CFG:PanelMain()
    local L = self:Layout("main")
    L.width = L.width or 660
    L.height = L.height or 700
    L.scale = L.scale or 1
    self:Header("Finestra principale")
    self:AddSlider("Larghezza", 500, 900, 20, function() return L.width end, function(v) L.width = v end, 220)
    self:AddSlider("Altezza", 500, 900, 20, function() return L.height end, function(v) L.height = v end, 220)
    self:AddSlider("Scala", 0.70, 1.30, 0.05, function() return L.scale end, function(v) L.scale = v end, 220)
end

function CFG:PanelScale(key, title)
    local L = self:Layout(key)
    L.scale = L.scale or 1
    self:Header(title)
    self:AddSlider("Scala", 0.70, 1.30, 0.05, function() return L.scale end, function(v) L.scale = v end, 220)
end

function CFG:RestoreMacroBar()
    local mb = self.db.macrobar
    mb.enabled = true
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
    if RLSuite.macrobar and RLSuite.macrobar.frame then
        RLSuite.macrobar.frame:ClearAllPoints()
        RLSuite.macrobar.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 4, 4)
    end
    self:ApplyAll()
    self:RebuildPanel()
end

function CFG:PanelMacroLayout()
    local mb = RLSuiteDB.macrobar
    self.db = RLSuiteDB
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

    self:PlaceCheck(4, -4, "Enable", function() return mb.enabled ~= false end, function(v) mb.enabled = v end)
    local restore = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    restore:SetSize(110, 20)
    restore:SetPoint("TOPLEFT", self.content, "TOPLEFT", 160, -6)
    restore:SetText("Restore Bar")
    restore:SetScript("OnClick", function() self:RestoreMacroBar() end)
    self:PlaceCheck(280, -4, "Lock", function() return mb.locked end, function(v) mb.locked = v end)

    self:PlaceCheck(4, -28, "Backdrop", function() return mb.backdrop ~= false end, function(v) mb.backdrop = v end)
    self:PlaceCheck(110, -28, "Show Empty Buttons", function() return mb.showEmpty ~= false end, function(v) mb.showEmpty = v end)
    self:PlaceCheck(250, -28, "Mouse Over", function() return mb.mouseover end, function(v) mb.mouseover = v end)
    self:PlaceCheck(4, -50, "Inherit Global Fade", function() return mb.inheritGlobalFade end, function(v) mb.inheritGlobalFade = v end)

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
    local col, gap = 104, 4
    self:PlaceDropdown(4, -76, col - 4, "Anchor Point", anchors, function() return mb.point or "CENTER" end, function(v)
        mb.point = v
        mb.relPoint = v
    end)
    self:PlaceCompactSlider(4 + col, -76, col - gap, "Buttons", 1, 12, 1, function() return mb.buttons end, function(v) mb.buttons = v end)
    self:PlaceCompactSlider(4 + col * 2, -76, col - gap, "Buttons Per Row", 1, 12, 1, function() return mb.columns end, function(v) mb.columns = v end)
    self:PlaceCompactSlider(4 + col * 3, -76, col - gap, "Button Size", 15, 60, 1, function() return mb.buttonSize end, function(v) mb.buttonSize = v end)

    self:PlaceCompactSlider(4, -128, col - gap, "Button Spacing", -3, 20, 1, function() return mb.spacing end, function(v) mb.spacing = v end)
    self:PlaceCompactSlider(4 + col, -128, col - gap, "Backdrop Spacing", 0, 10, 1, function() return mb.backdropSpacing end, function(v) mb.backdropSpacing = v end)
    self:PlaceCompactSlider(4 + col * 2, -128, col - gap, "Height Multiplier", 1, 5, 1, function() return mb.heightMult end, function(v) mb.heightMult = v end)
    self:PlaceCompactSlider(4 + col * 3, -128, col - gap, "Width Multiplier", 1, 5, 1, function() return mb.widthMult end, function(v) mb.widthMult = v end)

    self:PlaceCompactSlider(4, -180, col - gap, "Alpha", 0, 100, 1, function() return math.floor((mb.alpha or 1) * 100 + 0.5) end, function(v) mb.alpha = v / 100 end)
    self:PlaceCompactSlider(4 + col, -180, col - gap, "Scale", 0.50, 2.00, 0.05, function() return mb.scale or 1 end, function(v) mb.scale = v end)

    self:PlaceTextArea(4, -232, 410, 48, "Action Paging", function() return mb.actionPaging end, function(v) mb.actionPaging = v end)
    self:PlaceTextArea(4, -318, 410, 48, "Visibility State", function() return mb.visibility end, function(v) mb.visibility = v end)
end

function CFG:PanelRaidLayout()
    local rf = self.db.raidframe
    rf.appearance = rf.appearance or {}
    rf.width = rf.width or 350
    rf.scale = rf.scale or 1
    self:Header("Raid Frame — layout HUD")
    self:AddSlider("Larghezza", 220, 500, 20, function() return rf.width end, function(v) rf.width = v end, 220)
    self:AddSlider("Altezza barra HP", 12, 32, 1, function() return rf.appearance.barHeight or 20 end, function(v) rf.appearance.barHeight = v end)
    self:AddSlider("Dimensione icone", 10, 24, 1, function() return rf.appearance.iconSize or 16 end, function(v) rf.appearance.iconSize = v end)
    self:AddSlider("Scala", 0.70, 1.50, 0.05, function() return rf.scale end, function(v) rf.scale = v end, 220)
end

function CFG:PanelRaidPos()
    local rf = self.db.raidframe
    self:Header("Raid Frame — posizione")
    self:AddCheck("Blocca posizione", function() return rf.locked end, function(v) rf.locked = v end)
    local y = self:NextY(28)
    local btn = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    btn:SetSize(160, 22)
    btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    btn:SetText("Reset posizione")
    btn:SetScript("OnClick", function()
        rf.point, rf.relPoint, rf.x, rf.y = "LEFT", "LEFT", 10, 0
        if RLSuite.raidFrame and RLSuite.raidFrame.frame then
            RLSuite.raidFrame.frame:ClearAllPoints()
            RLSuite.raidFrame.frame:SetPoint("LEFT", UIParent, "LEFT", 10, 0)
        end
    end)
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
    local L = self.db.layout or {}
    local function scale(fr, key)
        if not fr or not L[key] or not L[key].scale then return end
        local parent = fr.GetParent and fr:GetParent()
        if RLSuite.mainWindow and RLSuite.mainWindow.contentArea and parent == RLSuite.mainWindow.contentArea then
            fr:SetScale(1)
            return
        end
        fr:SetScale(L[key].scale)
    end
    scale(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame, "groupmaking")
    scale(RLSuite.groupmaking and RLSuite.groupmaking.whisplistFrame, "whisplist")
    scale(RLSuite.msManager and RLSuite.msManager.frame, "ms")
    scale(RLSuite.lootManager and RLSuite.lootManager.frame, "loot")
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
