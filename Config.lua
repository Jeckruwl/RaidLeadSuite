-- ============================================================
-- RLSuite - Config Module
-- ============================================================

RLSuite.config = {}
local CFG = RLSuite.config

function CFG:Init()
    self.db = RLSuiteDB
    self:CreateFrame()
end

function CFG:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
    end
end

function CFG:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteConfig", UIParent)
    f:SetSize(400, 500)
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
    self.frame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("RLSuite - Config")

    -- Appearance
    local appLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    appLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -45)
    appLabel:SetText("Appearance")

    local themeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    themeLabel:SetPoint("TOPLEFT", appLabel, "BOTTOMLEFT", 0, -10)
    themeLabel:SetText("Theme:")

    self.themeDropdown = self:CreateDropdown(f, "RLSuiteThemeDD", 120, 22)
    self.themeDropdown:SetPoint("LEFT", themeLabel, "RIGHT", 10, 0)
    self.themeDropdown.text:SetText(self.db.appearance.theme or "default")

    local fontLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontLabel:SetPoint("TOPLEFT", themeLabel, "BOTTOMLEFT", 0, -15)
    fontLabel:SetText("Font Size:")

    self.fontSlider = CreateFrame("Slider", "RLSuiteFontSlider", f, "OptionsSliderTemplate")
    self.fontSlider:SetSize(150, 16)
    self.fontSlider:SetPoint("LEFT", fontLabel, "RIGHT", 10, 0)
    self.fontSlider:SetMinMaxValues(8, 20)
    self.fontSlider:SetValueStep(1)
    self.fontSlider:SetValue(self.db.appearance.fontSize or 12)
    getglobal(self.fontSlider:GetName() .. "Low"):SetText("8")
    getglobal(self.fontSlider:GetName() .. "High"):SetText("20")
    self.fontSlider:SetScript("OnValueChanged", function(s, val)
        self.db.appearance.fontSize = math.floor(val + 0.5)
    end)

    -- Macrobar
    local mbLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mbLabel:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -25)
    mbLabel:SetText("Macrobar")

    local lockLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockLabel:SetPoint("TOPLEFT", mbLabel, "BOTTOMLEFT", 0, -10)
    lockLabel:SetText("Lock position:")

    self.lockCheck = CreateFrame("CheckButton", "RLSuiteLockCheck", f, "UICheckButtonTemplate")
    self.lockCheck:SetPoint("LEFT", lockLabel, "RIGHT", 5, 0)
    self.lockCheck:SetChecked(self.db.macrobar.locked)
    self.lockCheck:SetScript("OnClick", function(s)
        self.db.macrobar.locked = s:GetChecked()
    end)

    local scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLabel:SetPoint("TOPLEFT", lockLabel, "BOTTOMLEFT", 0, -15)
    scaleLabel:SetText("Scale:")

    self.scaleSlider = CreateFrame("Slider", "RLSuiteScaleSlider", f, "OptionsSliderTemplate")
    self.scaleSlider:SetSize(150, 16)
    self.scaleSlider:SetPoint("LEFT", scaleLabel, "RIGHT", 10, 0)
    self.scaleSlider:SetMinMaxValues(0.5, 2.0)
    self.scaleSlider:SetValueStep(0.1)
    self.scaleSlider:SetValue(self.db.macrobar.scale or 1.0)
    getglobal(self.scaleSlider:GetName() .. "Low"):SetText("0.5")
    getglobal(self.scaleSlider:GetName() .. "High"):SetText("2.0")
    self.scaleSlider:SetScript("OnValueChanged", function(s, val)
        self.db.macrobar.scale = val
        if RLSuite.macrobar and RLSuite.macrobar.frame then
            RLSuite.macrobar.frame:SetScale(val)
        end
    end)

    -- Raid Frame
    local rfLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rfLabel:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -25)
    rfLabel:SetText("Raid Frame")

    local buffLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buffLabel:SetPoint("TOPLEFT", rfLabel, "BOTTOMLEFT", 0, -10)
    buffLabel:SetText("Show buff alerts:")

    self.buffCheck = CreateFrame("CheckButton", "RLSuiteBuffCheck", f, "UICheckButtonTemplate")
    self.buffCheck:SetPoint("LEFT", buffLabel, "RIGHT", 5, 0)
    self.buffCheck:SetChecked(self.db.raidframe.showBuffs)
    self.buffCheck:SetScript("OnClick", function(s)
        self.db.raidframe.showBuffs = s:GetChecked()
    end)

    local flaskLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    flaskLabel:SetPoint("TOPLEFT", buffLabel, "BOTTOMLEFT", 0, -15)
    flaskLabel:SetText("Show flask alerts:")

    self.flaskCheck = CreateFrame("CheckButton", "RLSuiteFlaskCheck", f, "UICheckButtonTemplate")
    self.flaskCheck:SetPoint("LEFT", flaskLabel, "RIGHT", 5, 0)
    self.flaskCheck:SetChecked(self.db.raidframe.showFlask)
    self.flaskCheck:SetScript("OnClick", function(s)
        self.db.raidframe.showFlask = s:GetChecked()
    end)

    local foodLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    foodLabel:SetPoint("TOPLEFT", flaskLabel, "BOTTOMLEFT", 0, -15)
    foodLabel:SetText("Show food alerts:")

    self.foodCheck = CreateFrame("CheckButton", "RLSuiteFoodCheck", f, "UICheckButtonTemplate")
    self.foodCheck:SetPoint("LEFT", foodLabel, "RIGHT", 5, 0)
    self.foodCheck:SetChecked(self.db.raidframe.showFood)
    self.foodCheck:SetScript("OnClick", function(s)
        self.db.raidframe.showFood = s:GetChecked()
    end)

    -- Import/Export
    local ioLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ioLabel:SetPoint("TOPLEFT", foodLabel, "BOTTOMLEFT", 0, -25)
    ioLabel:SetText("Import / Export")

    self.ioEdit = CreateFrame("EditBox", "RLSuiteIOEdit", f)
    self.ioEdit:SetMultiLine(true)
    self.ioEdit:SetSize(360, 80)
    self.ioEdit:SetPoint("TOPLEFT", ioLabel, "BOTTOMLEFT", 0, -5)
    self.ioEdit:SetFontObject("ChatFontNormal")
    self.ioEdit:SetBackdrop({
        bgFile = "Interface\Tooltips\UI-Tooltip-Background",
        tile = true, tileSize = 16,
    })
    self.ioEdit:SetBackdropColor(0, 0, 0, 0.8)
    self.ioEdit:SetTextInsets(5, 5, 5, 5)
    self.ioEdit:SetAutoFocus(false)

    local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exportBtn:SetSize(80, 22)
    exportBtn:SetPoint("TOPLEFT", self.ioEdit, "BOTTOMLEFT", 0, -5)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function() self:ExportData() end)

    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(80, 22)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function() self:ImportData() end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
end

function CFG:CreateDropdown(parent, name, width, height)
    local dd = CreateFrame("Frame", name, parent)
    dd:SetSize(width, height)
    dd:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left=2, right=2, top=2, bottom=2}
    })
    dd.text = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dd.text:SetPoint("LEFT", dd, "LEFT", 5, 0)
    dd.text:SetText("default")
    return dd
end

function CFG:ExportData()
    local data = {
        version = RLSuite.version,
        profiles = self.db.profiles,
        macrobar = self.db.macrobar,
        raidframe = self.db.raidframe,
        groupmaking = self.db.groupmaking,
    }
    local serialized = self:Serialize(data)
    self.ioEdit:SetText(serialized)
    RLSuite.utils:Print("Dati esportati.")
end

function CFG:ImportData()
    local text = self.ioEdit and self.ioEdit:GetText() or ""
    if text == "" then
        RLSuite.utils:Print("Incolla i dati da importare.")
        return
    end
    local success, data = pcall(function() return self:Deserialize(text) end)
    if success and data then
        if data.macrobar then self.db.macrobar = data.macrobar end
        if data.raidframe then self.db.raidframe = data.raidframe end
        if data.profiles then self.db.profiles = data.profiles end
        RLSuite.utils:Print("Dati importati con successo!")
    else
        RLSuite.utils:Print("Errore nell'importazione dei dati.")
    end
end

function CFG:Serialize(data)
    local function serialize(val)
        if type(val) == "table" then
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, "[" .. serialize(k) .. "]=" .. serialize(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        elseif type(val) == "string" then
            return string.format("%q", val)
        elseif type(val) == "number" then
            return tostring(val)
        elseif type(val) == "boolean" then
            return val and "true" or "false"
        end
        return "nil"
    end
    return serialize(data)
end

function CFG:Deserialize(text)
    local func, err = loadstring("return " .. text)
    if func then
        return func()
    end
    return nil
end
