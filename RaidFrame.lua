-- ============================================================
-- RLSuite - RaidFrame Module
-- ============================================================

RLSuite.raidFrame = {}
local RF = RLSuite.raidFrame

function RF:Init()
    self.db = RLSuiteDB.raidframe
    self.rows = {}
    self:CreateFrame()
    self:RegisterEvents()
end

function RF:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
        self:Update()
    end
end

function RF:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteRaidFrame", UIParent)
    f:SetSize(350, 400)
    f:SetPoint("LEFT", UIParent, "LEFT", 10, 0)
    f:SetFrameStrata("LOW")
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
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("RLSuite - Raid Frame")

    self.content = CreateFrame("Frame", nil, f)
    self.content:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -35)
    self.content:SetSize(330, 360)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
end

function RF:RegisterEvents()
    local f = CreateFrame("Frame")
    f:RegisterEvent("RAID_ROSTER_UPDATE")
    f:RegisterEvent("UNIT_HEALTH")
    f:RegisterEvent("UNIT_MANA")
    f:RegisterEvent("UNIT_AURA")
    f:SetScript("OnEvent", function(self2, event, ...)
        if event == "RAID_ROSTER_UPDATE" then
            RF:Rebuild()
        elseif event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "UNIT_AURA" then
            local unit = ...
            RF:UpdateUnit(unit)
        end
    end)
    f:SetScript("OnUpdate", function(self2, elapsed)
        self2.timer = (self2.timer or 0) + elapsed
        if self2.timer > 0.5 then
            self2.timer = 0
            RF:UpdateAll()
        end
    end)
end

function RF:Rebuild()
    for _, row in ipairs(self.rows) do
        row:Hide()
    end
    self.rows = {}

    local numMembers = GetNumRaidMembers()
    if numMembers == 0 then return end

    local barHeight = self.db.appearance.barHeight or 20
    local iconSize = self.db.appearance.iconSize or 16
    local rowHeight = math.max(barHeight, iconSize) + 2

    for i = 1, numMembers do
        local unit = "raid" .. i
        local name = UnitName(unit) or "Unknown"
        local class = select(2, UnitClass(unit)) or "WARRIOR"

        local row = CreateFrame("Button", "RLSuiteRaidRow" .. i, self.content)
        row:SetSize(330, rowHeight)
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(i - 1) * rowHeight)
        row.unit = unit
        row.name = name
        row.class = class

        row.alert = row:CreateTexture(nil, "OVERLAY")
        row.alert:SetSize(iconSize, iconSize)
        row.alert:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.alert:SetTexture("Interface\Icons\INV_Misc_QuestionMark")
        row.alert:Hide()
        row.alertFrame = CreateFrame("Button", nil, row)
        row.alertFrame:SetSize(iconSize, iconSize)
        row.alertFrame:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.alertFrame:SetScript("OnClick", function()
            self:OnAlertClick(row)
        end)

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row.alert, "RIGHT", 4, 0)
        row.nameText:SetText(name)
        local r, g, b = RLSuite.utils:GetClassColor(class)
        row.nameText:SetTextColor(r, g, b)

        row.healthBar = CreateFrame("StatusBar", nil, row)
        row.healthBar:SetSize(120, barHeight - 4)
        row.healthBar:SetPoint("LEFT", row.nameText, "RIGHT", 5, 0)
        row.healthBar:SetStatusBarTexture("Interface\TargetingFrame\UI-StatusBar")
        row.healthBar:SetStatusBarColor(0, 1, 0)
        row.healthBar:SetMinMaxValues(0, 100)
        row.healthBar:SetValue(100)

        row.healthText = row.healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.healthText:SetPoint("CENTER", row.healthBar, "CENTER")
        row.healthText:SetFont("Fonts\FRIZQT__.TTF", 8)
        row.healthText:SetText("100%")

        row.manaBar = CreateFrame("StatusBar", nil, row)
        row.manaBar:SetSize(120, 4)
        row.manaBar:SetPoint("TOP", row.healthBar, "BOTTOM", 0, -1)
        row.manaBar:SetStatusBarTexture("Interface\TargetingFrame\UI-StatusBar")
        row.manaBar:SetStatusBarColor(0, 0.5, 1)
        row.manaBar:SetMinMaxValues(0, 100)
        row.manaBar:SetValue(100)

        row.cdIcons = {}
        local abilities = RLSuite.keyAbilities[class] or {}
        for j, ability in ipairs(abilities) do
            local cd = row:CreateTexture(nil, "OVERLAY")
            cd:SetSize(iconSize, iconSize)
            cd:SetPoint("LEFT", row.manaBar, "RIGHT", 10 + (j-1)*(iconSize+2), 0)
            cd:SetTexture("Interface\Icons\INV_Misc_QuestionMark")
            cd:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            cd.ability = ability
            row.cdIcons[j] = cd
        end

        row:Show()
        self.rows[i] = row
    end

    self.content:SetHeight(numMembers * rowHeight)
end

function RF:UpdateUnit(unit)
    for _, row in ipairs(self.rows) do
        if row.unit == unit then
            self:UpdateRow(row)
            return
        end
    end
end

function RF:UpdateAll()
    for _, row in ipairs(self.rows) do
        self:UpdateRow(row)
    end
end

function RF:UpdateRow(row)
    local unit = row.unit
    if not unit or not UnitExists(unit) then return end

    local hp = UnitHealth(unit) or 0
    local hpMax = UnitHealthMax(unit) or 1
    local pct = math.floor((hp / hpMax) * 100)
    row.healthBar:SetMinMaxValues(0, hpMax)
    row.healthBar:SetValue(hp)
    row.healthText:SetText(pct .. "%")
    if pct > 60 then
        row.healthBar:SetStatusBarColor(0, 1, 0)
    elseif pct > 30 then
        row.healthBar:SetStatusBarColor(1, 1, 0)
    else
        row.healthBar:SetStatusBarColor(1, 0, 0)
    end

    local mana = UnitMana(unit) or 0
    local manaMax = UnitManaMax(unit) or 1
    row.manaBar:SetMinMaxValues(0, manaMax)
    row.manaBar:SetValue(mana)
    local powerType = UnitPowerType(unit)
    if powerType == 0 then
        row.manaBar:SetStatusBarColor(0, 0.5, 1)
    elseif powerType == 1 then
        row.manaBar:SetStatusBarColor(1, 0, 0)
    elseif powerType == 3 then
        row.manaBar:SetStatusBarColor(1, 1, 0)
    elseif powerType == 6 then
        row.manaBar:SetStatusBarColor(0, 0.8, 0.8)
    end

    local alertType = self:CheckAlerts(unit)
    if alertType then
        row.alert:SetTexture(self:GetAlertIcon(alertType))
        row.alert:Show()
        row.alertFrame:Show()
        row.alertType = alertType
    else
        row.alert:Hide()
        row.alertFrame:Hide()
        row.alertType = nil
    end

    for _, cd in ipairs(row.cdIcons) do
        if cd and cd.ability then
            local start, duration, enabled = GetSpellCooldown(cd.ability)
            if start and duration and duration > 0 then
                local remaining = start + duration - GetTime()
                if remaining > 0 then
                    cd:SetVertexColor(0.3, 0.3, 0.3)
                else
                    cd:SetVertexColor(1, 1, 1)
                end
            else
                cd:SetVertexColor(1, 1, 1)
            end
        end
    end
end

function RF:CheckAlerts(unit)
    if self.db.showFlask then
        local hasFlask = false
        for _, flask in ipairs(RLSuite.buffData.flask) do
            if UnitBuff(unit, flask) then hasFlask = true break end
        end
        if not hasFlask then return "flask" end
    end

    if self.db.showFood then
        local hasFood = false
        for _, food in ipairs(RLSuite.buffData.food) do
            if UnitBuff(unit, food) then hasFood = true break end
        end
        if not hasFood then return "food" end
    end

    if self.db.showBuffs then
        local hasBuff = false
        for _, buff in ipairs(RLSuite.buffData.buffs) do
            if UnitBuff(unit, buff) then hasBuff = true break end
        end
        if not hasBuff then return "buff" end
    end

    return nil
end

function RF:GetAlertIcon(alertType)
    local icons = {
        flask = "Interface\Icons\INV_Alchemy_EndlessFlask_01",
        food = "Interface\Icons\INV_Misc_Food_15",
        buff = "Interface\Icons\Spell_Magic_GreaterBlessingofKings",
    }
    return icons[alertType] or "Interface\Icons\INV_Misc_QuestionMark"
end

function RF:OnAlertClick(row)
    if not row or not row.alertType then return end
    local unit = row.unit
    local name = row.name
    local alerts = self.db.alerts or {}
    local msg = alerts[row.alertType] or self:GetDefaultAlertMessage(row.alertType)
    if msg and name then
        msg = string.gsub(msg, "$name", name)
        SendChatMessage(msg, "WHISPER", nil, name)
    end
end

function RF:GetDefaultAlertMessage(alertType)
    local msgs = {
        flask = "Hey $name, you're missing a flask!",
        food = "Hey $name, you're missing food buff!",
        buff = "Hey $name, you're missing some raid buffs!",
    }
    return msgs[alertType]
end

function RF:Update()
    self:Rebuild()
    self:UpdateAll()
end
