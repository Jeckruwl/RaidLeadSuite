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
        { key = "main",        label = "Finestra" },
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
        }
    elseif key == "macrobar" then
        return {
            { key = "layout", label = "Layout" },
            { key = "pos", label = "Posizione" },
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
    elseif cat == "main" then
        self:PanelMain()
    elseif cat == "groupmaking" then
        self:PanelScale("groupmaking", "Groupmaking")
    elseif cat == "whisplist" then
        self:PanelScale("whisplist", "Whisplist")
    elseif cat == "macrobar" and sub == "layout" then
        self:PanelMacroLayout()
    elseif cat == "macrobar" and sub == "pos" then
        self:PanelMacroPos()
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

function CFG:AddSlider(label, minV, maxV, step, getValue, setValue)
    local y = self:NextY(36)
    local fs = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    fs:SetText(label)

    self.widgetId = self.widgetId + 1
    local sl = CreateFrame("Slider", "RLSuiteCfgSlider" .. self.widgetId, self.content, "OptionsSliderTemplate")
    sl:SetSize(200, 16)
    sl:SetPoint("LEFT", fs, "LEFT", 150, 0)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    sl:SetValue(getValue())
    getglobal(sl:GetName() .. "Low"):SetText(tostring(minV))
    getglobal(sl:GetName() .. "High"):SetText(tostring(maxV))
    local valFS = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valFS:SetPoint("LEFT", sl, "RIGHT", 8, 0)
    local function fmt(v)
        if step < 1 then return string.format("%.2f", v) end
        return tostring(math.floor(v + 0.5))
    end
    valFS:SetText(fmt(getValue()))
    sl:SetScript("OnValueChanged", function(s, val)
        if step >= 1 then val = math.floor(val + 0.5) end
        setValue(val)
        valFS:SetText(fmt(val))
        self:ApplyAll()
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
    self:AddSlider("Larghezza", 500, 900, 10, function() return L.width end, function(v) L.width = v end)
    self:AddSlider("Altezza", 500, 900, 10, function() return L.height end, function(v) L.height = v end)
    self:AddSlider("Scala", 0.6, 1.5, 0.05, function() return L.scale end, function(v) L.scale = v end)
end

function CFG:PanelScale(key, title)
    local L = self:Layout(key)
    L.scale = L.scale or 1
    self:Header(title)
    self:AddSlider("Scala", 0.6, 1.5, 0.05, function() return L.scale end, function(v) L.scale = v end)
end

function CFG:PanelMacroLayout()
    local mb = self.db.macrobar
    mb.buttons = mb.buttons or 12
    mb.columns = mb.columns or 6
    mb.buttonSize = mb.buttonSize or 36
    mb.spacing = mb.spacing or 4
    mb.scale = mb.scale or 1
    self:Header("Macrobar — layout HUD")
    self:Note("Numero bottoni, griglia, dimensioni. I testi delle macro stanno nella tab Macrobar.")
    self:AddSlider("Numero bottoni", 6, 12, 1, function() return mb.buttons end, function(v) mb.buttons = v end)
    self:AddSlider("Colonne", 3, 12, 1, function() return mb.columns end, function(v) mb.columns = v end)
    self:AddSlider("Dimensione bottone", 24, 48, 1, function() return mb.buttonSize end, function(v) mb.buttonSize = v end)
    self:AddSlider("Spaziatura", 0, 12, 1, function() return mb.spacing end, function(v) mb.spacing = v end)
    self:AddSlider("Scala", 0.5, 2.0, 0.05, function() return mb.scale end, function(v) mb.scale = v end)
end

function CFG:PanelMacroPos()
    local mb = self.db.macrobar
    self:Header("Macrobar — posizione")
    self:AddCheck("Blocca posizione", function() return mb.locked end, function(v) mb.locked = v end)
    local y = self:NextY(28)
    local btn = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    btn:SetSize(160, 22)
    btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    btn:SetText("Reset posizione")
    btn:SetScript("OnClick", function()
        mb.point, mb.relPoint, mb.x, mb.y = "CENTER", "CENTER", 0, 100
        if RLSuite.macrobar and RLSuite.macrobar.frame then
            RLSuite.macrobar.frame:ClearAllPoints()
            RLSuite.macrobar.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        end
    end)
end

function CFG:PanelRaidLayout()
    local rf = self.db.raidframe
    rf.appearance = rf.appearance or {}
    rf.width = rf.width or 350
    rf.scale = rf.scale or 1
    self:Header("Raid Frame — layout HUD")
    self:AddSlider("Larghezza", 220, 500, 10, function() return rf.width end, function(v) rf.width = v end)
    self:AddSlider("Altezza barra HP", 12, 32, 1, function() return rf.appearance.barHeight or 20 end, function(v) rf.appearance.barHeight = v end)
    self:AddSlider("Dimensione icone", 10, 24, 1, function() return rf.appearance.iconSize or 16 end, function(v) rf.appearance.iconSize = v end)
    self:AddSlider("Scala", 0.5, 2.0, 0.05, function() return rf.scale end, function(v) rf.scale = v end)
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
