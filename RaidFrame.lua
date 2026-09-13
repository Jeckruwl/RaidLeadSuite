-- ============================================================
-- RLSuite - RaidFrame Module
-- ============================================================
-- HUD "clean": NO background/backdrop/border/close button on the frame
-- itself. One horizontal StatusBar per player with the player name inside
-- the bar; the fill is the HP% and the bar color is the class color.
--   left   : flask / Well Fed icons (shown when the player is missing them)
--   right  : class key cooldowns (combat-log tracked)
--   far right : vertical ability-check bar (ability per buff/debuff covered
--              by the raid; greyed when present, flashing border when missing)
--   below  : pre-boss alert buff bar / in-fight alert debuff bar
-- ============================================================

RLSuite.raidFrame = {}
local RF = RLSuite.raidFrame

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

-- Ace3: eventi (roster/aura/combat-log) via AceEvent-3.0, il refresh
-- periodico a 0.5s via AceTimer-3.0 (al posto del vecchio frame OnUpdate).
LibStub("AceEvent-3.0"):Embed(RF)
LibStub("AceTimer-3.0"):Embed(RF)

function RF:Init()
    self.db = RLSuite.db.profile.raidframe
    self.rows = {}
    self.cdTracker = {}
    self.abilityButtons = {}
    self:CreateFrame()
    self:RegisterEvents()
    self:ApplyLayout()
    self:UpdatePhase()
end

function RF:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        if self.db and self.db.enabled == false then
            RLSuite.utils:Print(L["Raid Frame is disabled in Config."])
            return
        end
        self.frame:Show()
        self:Update()
    end
end

function RF:CreateFrame()
    local db = self.db or {}
    local f = CreateFrame("Frame", "RLSuiteRaidFrame", UIParent)
    f:SetSize(db.width or 380, 300)
    f:SetPoint(db.point or "LEFT", UIParent, db.relPoint or "LEFT", db.x or 10, db.y or 0)
    f:SetFrameStrata("LOW")
    f:SetMovable(true)
    f:EnableMouse(true)
    RLSuite.utils:ClampWindow(f)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self2)
        if not db.locked or (RLSuite.db.profile.anchorMode == true) then
            self2:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self2)
        self2:StopMovingOrSizing()
        local point, _, relPoint, x, y = self2:GetPoint()
        db.point = point
        db.relPoint = relPoint
        db.x = x
        db.y = y
    end)
    f:Hide()
    self.frame = f

    -- Rows (one horizontal bar per player).
    self.content = CreateFrame("Frame", nil, f)
    self.content:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    -- Vertical ability-check bar (right side of the whole frame).
    self.abilityBar = CreateFrame("Frame", nil, f)
    self.abilityBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    self.abilityBar:Hide()

    -- Alert bars (pre-boss buffs / in-fight debuffs), below the rows.
    self.buffBar = self:CreateAlertBar()
    self.debuffBar = self:CreateAlertBar()
end

function RF:CreateAlertBar()
    local bar = CreateFrame("Frame", nil, self.frame)
    bar.items = {}
    bar:Hide()
    return bar
end

function RF:RegisterEvents()
    self:RegisterEvent("RAID_ROSTER_UPDATE", function() RF:Rebuild() end)
    self:RegisterEvent("UNIT_HEALTH", "OnUnitEvent")
    self:RegisterEvent("UNIT_MANA", "OnUnitEvent")
    self:RegisterEvent("UNIT_AURA", "OnUnitEvent")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")
    -- refresh periodico (prima un frame OnUpdate con accumulo a 0.5s)
    self:ScheduleRepeatingTimer("UpdateAll", 0.5)
end

function RF:OnUnitEvent(event, unit)
    self:UpdateUnit(unit)
end

function RF:OnCombatLog(event, ...)
    -- 3.3.5: timestamp, subEvent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, ...
    local _, subEvent, _, sourceName, _, _, _, _, spellId = ...
    if subEvent == "SPELL_CAST_SUCCESS" then
        self:OnSpellCast(sourceName, spellId)
    end
end

function RF:GetRoster()
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        -- The simulated roster (Core) is the single source of truth in debug
        -- mode: it starts with just the player and grows when fake players
        -- accept an invite. This is what the Raid Frame and the Raid Group
        -- panel both read, so an accepted invite updates everything.
        local list = {}
        for i, m in ipairs(RLSuite:DebugRoster()) do
            if m.isPlayer then
                table.insert(list, { unit = "player", name = m.name, class = m.class, fake = false })
            else
                table.insert(list, { unit = nil, name = m.name, class = m.class, fake = true })
            end
        end
        return list
    end
    local list = {}
    local num = GetNumRaidMembers() or 0
    for i = 1, num do
        local unit = "raid" .. i
        table.insert(list, {
            unit = unit,
            name = UnitName(unit) or "Unknown",
            class = select(2, UnitClass(unit)) or "WARRIOR",
            fake = false,
        })
    end
    return list
end

-- ------------------------------------------------------------------
-- Layout metrics
-- ------------------------------------------------------------------
function RF:LayoutMetrics()
    local db = self.db or {}
    local W = db.width or 380
    local abw = 0
    if db.showAbilityBar ~= false and (self.abilityCount or 0) > 0 then
        abw = (db.appearance and db.appearance.abilityBarWidth) or 110
    end
    local gap = (abw > 0) and 8 or 0
    local cw = math.max(120, W - abw - gap)
    local barHeight = (db.appearance and db.appearance.barHeight) or 20
    local iconSize = (db.appearance and db.appearance.iconSize) or 16
    local rowHeight = math.max(barHeight, iconSize) + 4
    return { W = W, abw = abw, cw = cw, barHeight = barHeight, iconSize = iconSize, rowHeight = rowHeight }
end

-- ------------------------------------------------------------------
-- Player rows
-- ------------------------------------------------------------------
function RF:Rebuild()
    for _, row in ipairs(self.rows) do
        row:Hide()
    end
    self.rows = {}

    local roster = self:GetRoster()
    local numMembers = #roster
    if numMembers == 0 then
        self:BuildAbilityBar()
        self:RefreshAlertBars()
        return
    end

    local m = self:LayoutMetrics()
    for i = 1, numMembers do
        local info = roster[i]
        local row = self:CreateRow(info, i, m)
        self.rows[i] = row
    end

    self:BuildAbilityBar()
    self:RefreshAlertBars()
end

function RF:CreateRow(info, i, m)
    local row = CreateFrame("Button", "RLSuiteRaidRow" .. i, self.content)
    row:SetSize(m.cw, m.rowHeight)
    row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(i - 1) * m.rowHeight)
    row.unit = info.unit
    row.name = info.name or "Unknown"
    row.class = info.class or "WARRIOR"
    row.fake = info.fake
    row.fakeHP = 70 + ((i * 13) % 31)

    -- Left: flask / Well Fed missing-consumable icons.
    row.flaskIcon = self:MakeConsumableIcon(row, "flask", 1, m)
    row.foodIcon = self:MakeConsumableIcon(row, "food", 2, m)

    -- HP bar (name + % inside), fill = HP%, color = class color.
    local leftX = 4 + 2 * m.iconSize + 4
    local cdCount = #(RLSuite.keyAbilities[row.class] or {})
    local cdArea = (cdCount > 0) and (cdCount * m.iconSize + (cdCount - 1) * 2 + 4) or 0

    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetHeight(m.barHeight)
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", leftX, 0)
    bar:SetPoint("RIGHT", row, "RIGHT", -cdArea, 0)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)
    row.bar = bar

    -- Subtle track behind the fill (a status bar needs a readable track;
    -- this is a per-bar background, not a HUD backdrop).
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0, 0, 0, 0.45)
    bar.bg = bg

    local nameFS = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("LEFT", bar, "LEFT", 3, 0)
    nameFS:SetText(row.name)
    nameFS:SetTextColor(1, 1, 1)
    bar.nameText = nameFS

    local pctFS = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pctFS:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    pctFS:SetText("100%")
    pctFS:SetTextColor(1, 1, 1)
    bar.hpText = pctFS

    local r, g, b = RLSuite.utils:GetClassColor(row.class)
    bar:SetStatusBarColor(r, g, b)

    -- Right: class key cooldowns.
    row.cdIcons = {}
    local abilities = RLSuite.keyAbilities[row.class] or {}
    for j, ability in ipairs(abilities) do
        local cd = row:CreateTexture(nil, "OVERLAY")
        cd:SetSize(m.iconSize, m.iconSize)
        cd:SetPoint("RIGHT", row, "RIGHT", -((j - 1) * (m.iconSize + 2)) - 2, 0)
        local meta = RLSuite.abilityByName and RLSuite.abilityByName[ability]
        cd:SetTexture((meta and meta.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
        cd:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cd.ability = ability
        local timer = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timer:SetPoint("CENTER", cd, "CENTER", 0, 0)
        timer:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        timer:SetText("")
        cd.timer = timer
        row.cdIcons[j] = cd
    end

    row:Show()
    return row
end

function RF:MakeConsumableIcon(row, atype, idx, m)
    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(m.iconSize, m.iconSize)
    btn:SetPoint("TOPLEFT", row, "TOPLEFT", 2 + (idx - 1) * (m.iconSize + 2), 0)
    btn.consType = atype
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexture(self:GetAlertIcon(atype))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon
    btn:SetScript("OnClick", function() self:OnAlertClick(row, atype) end)
    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        if atype == "flask" then
            GameTooltip:SetText(L["Missing flask"])
        else
            GameTooltip:SetText(L["Missing food buff"])
        end
        GameTooltip:AddLine(L["Left click: whisper"], 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

-- ------------------------------------------------------------------
-- Per-row updates
-- ------------------------------------------------------------------
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
    self:UpdateAbilityButtons()
    self:UpdateAlertItems()
end

function RF:UpdateRow(row)
    if not row or not row.bar then return end
    local bar = row.bar
    if row.fake then
        local pct = row.fakeHP or 100
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(pct)
        bar.hpText:SetText(pct .. "%")
        self:UpdateConsumables(row)
        return
    end
    local unit = row.unit
    if not unit or not UnitExists(unit) then
        return
    end

    local hp = UnitHealth(unit) or 0
    local hpMax = UnitHealthMax(unit) or 1
    local pct = math.floor((hp / hpMax) * 100)
    bar:SetMinMaxValues(0, hpMax)
    bar:SetValue(hp)
    bar.hpText:SetText(pct .. "%")

    self:UpdateConsumables(row)

    for _, cd in ipairs(row.cdIcons) do
        if cd and cd.ability then
            local remaining = self:GetAbilityRemaining(row.name, unit, cd.ability)
            if remaining and remaining > 0 then
                cd:SetVertexColor(0.35, 0.35, 0.35)
                if cd.timer then
                    cd.timer:SetText(RLSuite.utils:FormatCD(remaining))
                end
            else
                cd:SetVertexColor(1, 1, 1)
                if cd.timer then cd.timer:SetText("") end
            end
        end
    end
end

function RF:UpdateConsumables(row)
    if not row then return end
    local showFlask = self.db.showFlask ~= false
    local showFood = self.db.showFood ~= false

    if row.fake then
        self:SetConsumable(row.flaskIcon, showFlask and "missing" or "off")
        self:SetConsumable(row.foodIcon, showFood and "missing" or "off")
        return
    end

    local unit = row.unit
    if not unit or not UnitExists(unit) then
        self:SetConsumable(row.flaskIcon, "off")
        self:SetConsumable(row.foodIcon, "off")
        return
    end

    if showFlask then
        local has = self:HasAnySpellBuff(unit, RLSuite.buffData and RLSuite.buffData.flask)
        self:SetConsumable(row.flaskIcon, has and "off" or "missing")
    else
        self:SetConsumable(row.flaskIcon, "off")
    end

    if showFood then
        local has = self:HasAnySpellBuff(unit, RLSuite.buffData and RLSuite.buffData.food)
        self:SetConsumable(row.foodIcon, has and "off" or "missing")
    else
        self:SetConsumable(row.foodIcon, "off")
    end
end

function RF:SetConsumable(btn, state)
    if not btn then return end
    if state == "off" then
        btn:Hide()
    else
        btn:Show()
        if btn.icon then
            btn.icon:SetVertexColor(1, 1, 1)
        end
    end
end

-- GetSpellCooldown only works for the player. Raid members are tracked via combat log + known CD.
-- Queries are made by spellId (locale-safe): the name form of GetSpellCooldown
-- requires the spell to be in the player's spellbook and uses localized names.
function RF:GetAbilityRemaining(playerName, unit, ability)
    if unit and UnitIsUnit(unit, "player") then
        local ids = RLSuite.abilitySpellIdByName and RLSuite.abilitySpellIdByName[ability]
        for _, spellId in ipairs(ids or {}) do
            local start, duration = GetSpellCooldown(spellId)
            if start and duration and duration > 1.5 then
                local rem = start + duration - GetTime()
                if rem > 0 then return rem end
            end
        end
    end
    local expire = self.cdTracker and self.cdTracker[playerName] and self.cdTracker[playerName][ability]
    if expire then
        local rem = expire - GetTime()
        if rem > 0 then return rem end
    end
    return 0
end

function RF:OnSpellCast(sourceName, spellId)
    if not sourceName or not spellId then return end
    local ability = RLSuite.abilityBySpellId and RLSuite.abilityBySpellId[spellId]
    if not ability then return end
    local meta = RLSuite.abilityByName and RLSuite.abilityByName[ability]
    if not meta or not meta.cd then return end
    self.cdTracker = self.cdTracker or {}
    self.cdTracker[sourceName] = self.cdTracker[sourceName] or {}
    self.cdTracker[sourceName][ability] = GetTime() + meta.cd
end

-- ------------------------------------------------------------------
-- Locale-safe aura helpers
-- ------------------------------------------------------------------
function RF:UnitHasSpellBuff(unit, spellId)
    if not unit or not spellId then return false end
    local name = GetSpellInfo(spellId)
    if not name then return false end
    local buffName, _, _, _, _, _, _, _, _, _, buffSpellId = UnitBuff(unit, name)
    if not buffName then return false end
    if buffSpellId and buffSpellId ~= spellId then return false end
    return true
end

function RF:UnitHasSpellDebuff(unit, spellId)
    if not unit or not spellId then return false end
    local name = GetSpellInfo(spellId)
    if not name then return false end
    local debuffName, _, _, _, _, _, _, _, _, _, debuffSpellId = UnitDebuff(unit, name)
    if not debuffName then return false end
    if debuffSpellId and debuffSpellId ~= spellId then return false end
    return true
end

function RF:HasAnySpellBuff(unit, spellIds)
    for _, spellId in ipairs(spellIds or {}) do
        if self:UnitHasSpellBuff(unit, spellId) then return true end
    end
    return false
end

function RF:GetAlertIcon(alertType)
    local icons = {
        flask = "Interface\\Icons\\INV_Alchemy_EndlessFlask_01",
        food = "Interface\\Icons\\INV_Misc_Food_15",
        buff = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
    }
    return icons[alertType] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function RF:OnAlertClick(row, atype)
    if not row or not atype then return end
    local name = row.name
    local alerts = self.db.alerts or {}
    local msg = alerts[atype] or self:GetDefaultAlertMessage(atype)
    if msg and name then
        msg = string.gsub(msg, "%$name", name)
        RLSuite.utils:Whisper(name, msg)
    end
end

function RF:GetDefaultAlertMessage(alertType)
    local msgs = {
        flask = L["Hey $name, you're missing a flask!"],
        food = L["Hey $name, you're missing food buff!"],
        buff = L["Hey $name, you're missing some raid buffs!"],
    }
    return msgs[alertType]
end

-- ------------------------------------------------------------------
-- Coverage checks (pre-boss buffs / in-fight debuffs)
-- ------------------------------------------------------------------
function RF:AllChecks()
    local list = {}
    for _, c in ipairs(RLSuite.raidBuffChecks or {}) do
        c.kind = "buff"
        table.insert(list, c)
    end
    for _, c in ipairs(RLSuite.raidDebuffChecks or {}) do
        c.kind = "debuff"
        table.insert(list, c)
    end
    return list
end

function RF:GetCompClasses()
    local set = {}
    for _, info in ipairs(self:GetRoster()) do
        set[(info.class or "WARRIOR"):upper()] = true
    end
    return set
end

function RF:CheckCoverage(check)
    if not check then return false end
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        -- No real auras in the simulated environment: everything reads as
        -- "missing" so the alert UI still renders (and never errors).
        return false
    end
    if check.kind == "debuff" then
        return self:CheckDebuffCoverage(check)
    end
    return self:CheckBuffCoverage(check)
end

function RF:CheckBuffCoverage(check)
    local spells = check.spells or {}
    for _, info in ipairs(self:GetRoster()) do
        local unit = info.unit
        if unit and UnitExists(unit) then
            for _, spellId in ipairs(spells) do
                if self:UnitHasSpellBuff(unit, spellId) then return true end
            end
        end
    end
    return false
end

function RF:CheckDebuffCoverage(check)
    local spells = check.spells or {}
    local units = { "target", "focus", "boss1", "boss2", "boss3", "boss4" }
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            for _, spellId in ipairs(spells) do
                if self:UnitHasSpellDebuff(unit, spellId) then return true end
            end
        end
    end
    return false
end

-- ------------------------------------------------------------------
-- Vertical ability-check bar
-- ------------------------------------------------------------------
function RF:BuildAbilityBar()
    if not self.abilityBar then return end
    for _, btn in ipairs(self.abilityButtons) do
        btn:Hide()
    end
    self.abilityButtons = {}

    local show = self.db.showAbilityBar ~= false
    if not show then
        self.abilityBar:Hide()
        self.abilityCount = 0
        self:ApplyLayout()
        return
    end

    local comp = self:GetCompClasses()
    local checks = self:AllChecks()
    local m = self:LayoutMetrics()
    local idx = 0
    for _, check in ipairs(checks) do
        local relevant = false
        for _, cls in ipairs(check.classes or {}) do
            if comp[cls] then
                relevant = true
                break
            end
        end
        if relevant then
            idx = idx + 1
            local btn = self:GetAbilityButton(idx)
            self:FillAbilityButton(btn, check)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.abilityBar, "TOPLEFT", 2, -(idx - 1) * 20)
            btn:SetSize(math.max(10, m.abw - 4), 18)
        end
    end

    self.abilityCount = idx
    if idx == 0 then
        self.abilityBar:Hide()
    else
        self.abilityBar:Show()
    end
    self:ApplyLayout()
    self:UpdateAbilityButtons()
end

function RF:GetAbilityButton(idx)
    if self.abilityButtons[idx] then return self.abilityButtons[idx] end
    local btn = CreateFrame("Button", "RLSuiteRaidAbility" .. idx, self.abilityBar)
    btn:SetHeight(18)
    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(0, 0, 0, 0.35)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", btn, "LEFT", 1, 0)
    btn.icon = icon

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 3, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -1, 0)
    label:SetJustifyH("LEFT")
    btn.label = label

    self.abilityButtons[idx] = btn
    return btn
end

function RF:FillAbilityButton(btn, check)
    btn.check = check
    btn.icon:SetTexture(check.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.label:SetText(check.label or check.key)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.check and (self.check.label or self.check.key) or "")
        local prov = table.concat(self.check and self.check.classes or {}, ", ")
        GameTooltip:AddLine(L["Provided by: "] .. prov, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:Show()
end

function RF:UpdateAbilityButtons()
    for _, btn in ipairs(self.abilityButtons) do
        local check = btn.check
        if check then
            self:SetAbilityButtonState(btn, self:CheckCoverage(check))
        end
    end
end

function RF:SetAbilityButtonState(btn, present)
    if present then
        -- Covered: greyed out, no glow.
        btn:SetScript("OnUpdate", nil)
        btn.icon:SetVertexColor(0.35, 0.35, 0.35)
        btn.label:SetTextColor(0.5, 0.5, 0.5)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    else
        -- Missing: full color + flashing bright border.
        btn.icon:SetVertexColor(1, 1, 1)
        btn.label:SetTextColor(1, 1, 1)
        btn:SetBackdropBorderColor(1, 0.55, 0, 1)
        btn._flash = 0
        btn._flashOn = false
        btn:SetScript("OnUpdate", function(self, elapsed)
            self._flash = (self._flash or 0) + elapsed
            if self._flash >= 0.5 then
                self._flash = 0
                self._flashOn = not self._flashOn
                self:SetBackdropBorderColor(1, 0.55, 0, self._flashOn and 0.2 or 1)
            end
        end)
    end
end

-- ------------------------------------------------------------------
-- Pre-boss / in-fight alert bars
-- ------------------------------------------------------------------
function RF:UpdatePhase()
    self:BuildAbilityBar()
    self:RefreshAlertBars()
end

function RF:RefreshAlertBars()
    local phase = RLSuite.context or "preraid"

    local showBuff = phase == "preboss" and self.db.showBuffBar ~= false
    local showDebuff = phase == "infight" and self.db.showDebuffBar ~= false

    if self.buffBar then
        if showBuff then self.buffBar:Show() else self.buffBar:Hide() end
    end
    if self.debuffBar then
        if showDebuff then self.debuffBar:Show() else self.debuffBar:Hide() end
    end

    self:PopulateAlertBar(self.buffBar, RLSuite.raidBuffChecks, showBuff)
    self:PopulateAlertBar(self.debuffBar, RLSuite.raidDebuffChecks, showDebuff)
    self:ApplyLayout()
    self:UpdateAlertItems()
end

function RF:PopulateAlertBar(bar, checks, active)
    if not bar then return end
    for _, it in ipairs(bar.items) do
        it:Hide()
    end
    bar.items = {}
    bar.count = 0
    if not active then return end

    local comp = self:GetCompClasses()
    local idx = 0
    for _, check in ipairs(checks or {}) do
        local relevant = true
        if check.onlyWithClass then
            relevant = false
            for _, cls in ipairs(check.classes or {}) do
                if comp[cls] then
                    relevant = true
                    break
                end
            end
        end
        if relevant then
            idx = idx + 1
            local it = self:GetAlertItem(bar, idx)
            self:FillAlertItem(it, check)
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -(idx - 1) * 14)
            it:SetWidth(math.max(60, self.frame:GetWidth() - 4))
        end
    end
    bar.count = idx
end

function RF:GetAlertItem(bar, idx)
    if bar.items[idx] then return bar.items[idx] end
    local it = CreateFrame("Button", nil, bar)
    it:SetHeight(14)

    local icon = it:CreateTexture(nil, "ARTWORK")
    icon:SetSize(12, 12)
    icon:SetPoint("LEFT", it, "LEFT", 0, 0)
    it.icon = icon

    local label = it:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 3, 0)
    label:SetPoint("RIGHT", it, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    it.label = label

    it:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.check and (self.check.label or self.check.key) or "")
        GameTooltip:Show()
    end)
    it:SetScript("OnLeave", function() GameTooltip:Hide() end)

    bar.items[idx] = it
    return it
end

function RF:FillAlertItem(it, check)
    it.check = check
    it.icon:SetTexture(check.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    it.label:SetText(check.label or check.key)
    it:Show()
end

function RF:UpdateAlertItems()
    for _, bar in ipairs({ self.buffBar, self.debuffBar }) do
        if bar and bar:IsShown() then
            for _, it in ipairs(bar.items) do
                if it.check then
                    local present = self:CheckCoverage(it.check)
                    if present then
                        it.icon:SetVertexColor(0.4, 0.75, 0.4)
                        it.label:SetTextColor(0.4, 0.8, 0.4)
                    else
                        it.icon:SetVertexColor(1, 0.5, 0.15)
                        it.label:SetTextColor(1, 0.55, 0.15)
                    end
                end
            end
        end
    end
end

-- ------------------------------------------------------------------
-- Layout / update entry points
-- ------------------------------------------------------------------
function RF:ApplyLayout()
    local db = self.db
    if not db or not self.frame then return end
    local m = self:LayoutMetrics()
    self.frame:SetWidth(m.W)
    self.frame:SetScale(db.scale or 1)

    local numRows = #(self.rows or {})
    local rowsH = numRows * m.rowHeight

    if self.content then
        self.content:ClearAllPoints()
        self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        self.content:SetSize(m.cw, rowsH)
    end

    if self.abilityBar then
        self.abilityBar:ClearAllPoints()
        if db.showAbilityBar ~= false and (self.abilityCount or 0) > 0 then
            self.abilityBar:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
            self.abilityBar:SetSize(m.abw, rowsH)
        else
            self.abilityBar:SetSize(0, 0)
        end
    end

    local alertTop = -(rowsH + 4)
    for _, bar in ipairs({ self.buffBar, self.debuffBar }) do
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, alertTop)
            bar:SetSize(m.W, (bar.count or 0) * 14)
        end
    end

    local alertH = 0
    if self.buffBar and self.buffBar:IsShown() then
        alertH = alertH + (self.buffBar.count or 0) * 14 + 4
    end
    if self.debuffBar and self.debuffBar:IsShown() then
        alertH = alertH + (self.debuffBar.count or 0) * 14 + 4
    end
    self.frame:SetHeight(math.max(20, rowsH + alertH))

    if (RLSuite.InRaid and RLSuite:InRaid()) or (GetNumRaidMembers and GetNumRaidMembers() > 0) then
        self:UpdateAll()
    end
end

function RF:Update()
    self:Rebuild()
    self:UpdateAll()
end
