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
--
-- The player bars are divided into the 6 raid groups (G1..G6, 5 players
-- each), in pre-boss phase empty slots are shown as drop targets and
-- players can be rearranged by drag & drop (like the InviteEngine raid
-- group panel).
-- ============================================================

RLSuite.raidFrame = {}
local RF = RLSuite.raidFrame

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

local RF_GROUPS = 6
local RF_PER_GROUP = 5
local RF_MAX_CDS = 4
local RF_HEADER_H = 14
local RF_GROUP_GAP = 8

-- Drop-target outline for empty slots (pre-boss only). Transparent fill,
-- subtle border: it is a placeholder, not a HUD backdrop.
local RF_EMPTY_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

-- Ace3: eventi (roster/aura/combat-log) via AceEvent-3.0, il refresh
-- periodico a 0.5s via AceTimer-3.0 (al posto del vecchio frame OnUpdate).
LibStub("AceEvent-3.0"):Embed(RF)
LibStub("AceTimer-3.0"):Embed(RF)

function RF:Init()
    self.db = RLSuite.db.profile.raidframe
    self.rows = {}          -- populated slots, dense (for tests + UpdateAll)
    self.slots = {}         -- 30 slot frames (6 groups x 5 players)
    self.groupHeaders = {}  -- 6 group labels (G1..G6)
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

    -- Groups + slots (G1..G6) live in this container.
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

-- Raid roster divided into the 6 groups: groups[g][s] = member or nil.
-- Debug mode reads the sparse simulated slots (slot -> group/row); real
-- mode reads GetRaidRosterInfo's subgroup, ordered by raid index.
function RF:GetGroupedRoster()
    local groups = { {}, {}, {}, {}, {}, {} }
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        local slots = RLSuite:DebugRaidSlots()
        for i = 1, RF_GROUPS * RF_PER_GROUP do
            local m = slots[i]
            if m then
                local g = math.floor((i - 1) / RF_PER_GROUP) + 1
                local s = (i - 1) % RF_PER_GROUP + 1
                if g >= 1 and g <= RF_GROUPS then
                    groups[g][s] = {
                        name = m.name,
                        class = m.class or "WARRIOR",
                        unit = m.isPlayer and "player" or nil,
                        fake = not m.isPlayer,
                        slot = i,
                    }
                end
            end
        end
        return groups
    end

    local num = GetNumRaidMembers() or 0
    local groupCount = { 0, 0, 0, 0, 0, 0 }
    for i = 1, num do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name then
            local class = select(2, UnitClass("raid" .. i)) or "WARRIOR"
            subgroup = tonumber(subgroup) or 1
            if subgroup < 1 then subgroup = 1 end
            if subgroup > RF_GROUPS then subgroup = RF_GROUPS end
            groupCount[subgroup] = groupCount[subgroup] + 1
            local s = groupCount[subgroup]
            if s <= RF_PER_GROUP then
                groups[subgroup][s] = {
                    name = name,
                    class = class,
                    unit = "raid" .. i,
                    fake = false,
                    raidIndex = i,
                }
            end
        end
    end
    return groups
end

-- ------------------------------------------------------------------
-- Layout metrics
-- ------------------------------------------------------------------
function RF:LayoutMetrics()
    local db = self.db or {}
    local iconSize = (db.appearance and db.appearance.iconSize) or 16
    local barHeight = (db.appearance and db.appearance.barHeight) or 20
    local barWidth = (db.appearance and db.appearance.barWidth) or 180
    local nameFontSize = (db.appearance and db.appearance.nameFontSize) or 11
    local abw = 0
    if db.showAbilityBar ~= false and (self.abilityCount or 0) > 0 then
        abw = (db.appearance and db.appearance.abilityBarWidth) or 110
    end
    local gap = (abw > 0) and 8 or 0
    -- Layout per row: [flask][food] ... [HP bar = barWidth] ... [up to 4 CDs]
    local leftArea = 4 + 2 * iconSize + 4
    local cdReserve = 4 * iconSize + 3 * 2 + 4
    local rowWidth = leftArea + barWidth + cdReserve + 4
    local W = rowWidth + abw + gap
    local rowHeight = math.max(barHeight, iconSize) + 4
    return {
        W = W, abw = abw, rowWidth = rowWidth,
        barWidth = barWidth, barHeight = barHeight,
        iconSize = iconSize, nameFontSize = nameFontSize,
        rowHeight = rowHeight,
    }
end

-- ------------------------------------------------------------------
-- Group headers + slot frames (created once, reused)
-- ------------------------------------------------------------------
function RF:EnsureSlots()
    self.groupHeaders = self.groupHeaders or {}
    self.slots = self.slots or {}
    for g = 1, RF_GROUPS do
        if not self.groupHeaders[g] then
            local lbl = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetText("G" .. g)
            lbl:SetTextColor(1, 0.82, 0)
            lbl:SetJustifyH("LEFT")
            self.groupHeaders[g] = lbl
        end
        for s = 1, RF_PER_GROUP do
            local i = (g - 1) * RF_PER_GROUP + s
            if not self.slots[i] then
                self.slots[i] = self:CreateSlotFrame(i, g)
            end
        end
    end
end

function RF:CreateSlotFrame(slotIndex, group)
    local row = CreateFrame("Button", "RLSuiteRaidRow" .. slotIndex, self.content)
    row.slot = slotIndex
    row.group = group
    row.member = nil
    row.fakeHP = 70 + ((slotIndex * 13) % 31)

    -- Left: flask / Well Fed missing-consumable icons.
    row.flaskIcon = self:MakeConsumableIcon(row, "flask")
    row.foodIcon = self:MakeConsumableIcon(row, "food")

    -- HP bar (name + % inside), fill = HP%, color = class color.
    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
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
    nameFS:SetText("")
    nameFS:SetTextColor(1, 1, 1)
    bar.nameText = nameFS

    local pctFS = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pctFS:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    pctFS:SetText("")
    pctFS:SetTextColor(1, 1, 1)
    bar.hpText = pctFS

    -- Class key cooldowns (up to 4, pooled; filled per class in ApplySlotCDs).
    row.cdIcons = {}
    for j = 1, RF_MAX_CDS do
        local cd = row:CreateTexture(nil, "OVERLAY")
        cd:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local timer = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timer:SetPoint("CENTER", cd, "CENTER", 0, 0)
        timer:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        timer:SetText("")
        cd.timer = timer
        row.cdIcons[j] = cd
    end
    row._cdClass = nil

    -- Drag & drop (active only in pre-boss, enabled via UpdateDragState).
    row:SetScript("OnDragStart", function(self2)
        if not RF:IsDragEnabled() then return end
        RF._rfDragSource = (self2.member and self2) or nil
    end)
    row:SetScript("OnDragStop", function()
        local src = RF._rfDragSource
        RF._rfDragSource = nil
        if src and src.member then
            local target = RF:SlotAtCursor()
            if target and target ~= src then
                RF:MoveSlot(src, target)
            end
        end
    end)
    row:SetScript("OnReceiveDrag", function(self2)
        local src = RF._rfDragSource
        RF._rfDragSource = nil
        if src and src ~= self2 and src.member then
            RF:MoveSlot(src, self2)
        end
    end)

    row:Hide()
    return row
end

function RF:MakeConsumableIcon(row, atype)
    local btn = CreateFrame("Button", nil, row)
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
    btn:Hide()
    return btn
end

-- Positions + resizes every widget of a slot from the layout metrics.
-- Called from ApplyLayout so Config changes (bar width/height, icon size,
-- name font size) apply immediately without a full roster rebuild.
function RF:LayoutSlotGeometry(slot, m)
    slot:SetSize(m.rowWidth, m.rowHeight)
    local iconSize = m.iconSize
    if slot.flaskIcon then
        slot.flaskIcon:ClearAllPoints()
        slot.flaskIcon:SetSize(iconSize, iconSize)
        slot.flaskIcon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, 0)
    end
    if slot.foodIcon then
        slot.foodIcon:ClearAllPoints()
        slot.foodIcon:SetSize(iconSize, iconSize)
        slot.foodIcon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2 + iconSize + 2, 0)
    end
    if slot.bar then
        local leftX = 4 + 2 * iconSize + 4
        slot.bar:ClearAllPoints()
        slot.bar:SetSize(m.barWidth, m.barHeight)
        slot.bar:SetPoint("TOPLEFT", slot, "TOPLEFT", leftX, 0)
        if slot.bar.nameText then
            slot.bar.nameText:SetFont(RLSuite.utils:GetUIFont(), m.nameFontSize, "OUTLINE")
        end
        if slot.bar.hpText then
            slot.bar.hpText:SetFont(RLSuite.utils:GetUIFont(), m.nameFontSize, "OUTLINE")
        end
    end
    for j, cd in ipairs(slot.cdIcons or {}) do
        cd:ClearAllPoints()
        cd:SetSize(iconSize, iconSize)
        cd:SetPoint("LEFT", slot.bar, "RIGHT", 4 + (j - 1) * (iconSize + 2), 0)
    end
end

function RF:ApplySlotCDs(slot, class)
    slot._cdClass = class
    local abilities = RLSuite.keyAbilities[class] or {}
    for j = 1, RF_MAX_CDS do
        local cd = slot.cdIcons and slot.cdIcons[j]
        if cd then
            local ability = abilities[j]
            if ability then
                local meta = RLSuite.abilityByName and RLSuite.abilityByName[ability]
                cd:SetTexture((meta and meta.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
                cd.ability = ability
                cd:Show()
            else
                cd.ability = nil
                cd:Hide()
            end
        end
    end
end

function RF:FillSlot(slot, member)
    slot.member = member
    slot.unit = member.unit
    slot.name = member.name
    slot.class = member.class
    slot.fake = member.fake
    slot.raidIndex = member.raidIndex
    slot:SetBackdrop(nil)
    slot:Show()

    if slot.bar then
        local r, g, b = RLSuite.utils:GetClassColor(member.class)
        slot.bar:SetStatusBarColor(r, g, b)
        slot.bar:SetMinMaxValues(0, 100)
        slot.bar:SetValue(100)
        if slot.bar.nameText then slot.bar.nameText:SetText(member.name) end
        if slot.bar.hpText then slot.bar.hpText:SetText("100%") end
        slot.bar:Show()
    end

    if slot._cdClass ~= member.class then
        self:ApplySlotCDs(slot, member.class)
    end

    self:UpdateRow(slot)
end

function RF:ClearSlot(slot)
    slot.member = nil
    slot.unit = nil
    slot.name = nil
    slot.class = nil
    slot.fake = false
    slot.raidIndex = nil

    if slot.bar then
        slot.bar:SetValue(0)
        if slot.bar.nameText then slot.bar.nameText:SetText("") end
        if slot.bar.hpText then slot.bar.hpText:SetText("") end
    end
    self:SetConsumable(slot.flaskIcon, "off")
    self:SetConsumable(slot.foodIcon, "off")
    for _, cd in ipairs(slot.cdIcons or {}) do
        cd:Hide()
    end

    if self:IsDragEnabled() then
        -- Empty drop target (pre-boss): subtle outline, no fill.
        slot:SetBackdrop(RF_EMPTY_BACKDROP)
        slot:SetBackdropColor(0, 0, 0, 0)
        slot:SetBackdropBorderColor(0.32, 0.32, 0.36, 0.9)
        slot:Show()
    else
        slot:SetBackdrop(nil)
        slot:Hide()
    end
end

-- ------------------------------------------------------------------
-- Rebuild
-- ------------------------------------------------------------------
function RF:Rebuild()
    self:EnsureSlots()
    local m = self:LayoutMetrics()
    local groups = self:GetGroupedRoster()
    local preboss = self:IsDragEnabled()

    self.rows = {}
    for g = 1, RF_GROUPS do
        local anyMember = false
        for s = 1, RF_PER_GROUP do
            local slot = self.slots[(g - 1) * RF_PER_GROUP + s]
            local member = groups[g][s]
            if member then
                self:FillSlot(slot, member)
                self.rows[#self.rows + 1] = slot
                anyMember = true
            else
                self:ClearSlot(slot)
            end
        end
        local hdr = self.groupHeaders[g]
        if anyMember or preboss then
            hdr:Show()
        else
            hdr:Hide()
        end
    end

    self:BuildAbilityBar()
    self:RefreshAlertBars()
    self:UpdateDragState()
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
-- Phase + drag & drop
-- ------------------------------------------------------------------
function RF:UpdatePhase()
    self:Rebuild()
    self:UpdateDragState()
end

-- Players can be rearranged only in pre-boss phase (like the InviteEngine
-- raid group panel is used while organizing the raid).
function RF:IsDragEnabled()
    return (RLSuite.context or "preraid") == "preboss"
end

function RF:UpdateDragState()
    local enabled = self:IsDragEnabled()
    for _, slot in ipairs(self.slots or {}) do
        if enabled then
            slot:EnableMouse(true)
            slot:RegisterForDrag("LeftButton")
        else
            slot:EnableMouse(false)
            slot:RegisterForDrag()
        end
    end
end

-- Slot under the mouse cursor (nil if none). Mirrors GroupMaking's
-- WlSlotAtCursor: computes the target from the cursor coordinates because
-- OnReceiveDrag is not always delivered on nested frames.
function RF:SlotAtCursor()
    if not GetCursorPosition then return nil end
    local x, y = GetCursorPosition()
    if not x or not y then return nil end
    local scale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if scale and scale > 0 then
        x = x / scale
        y = y / scale
    end
    for _, slot in ipairs(self.slots or {}) do
        if slot and slot.IsShown and slot:IsShown() then
            local left = slot:GetLeft()
            local right = slot:GetRight()
            local bottom = slot:GetBottom()
            local top = slot:GetTop()
            if left and right and bottom and top
                and x >= left and x <= right and y >= bottom and y <= top then
                return slot
            end
        end
    end
    return nil
end

-- Reorganizes the groups by dragging a player between slots. src/dst are
-- the two slot frames (source and destination). Empty destination = move,
-- occupied destination = swap.
function RF:MoveSlot(src, dst)
    if not src or not dst or src == dst then return end
    if not src.member then return end

    -- Simulated roster (debug): reorder the shared slot list.
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        self:MoveSlotDebug(src, dst)
        return
    end

    -- Real raid: Blizzard APIs (only the raid leader can rearrange).
    if not (IsRaidLeader and (IsRaidLeader() or IsRaidOfficer())) then
        RLSuite.utils:Print(L["Only the raid leader can rearrange groups."])
        return
    end
    if not src.raidIndex then return end
    if dst.member and dst.raidIndex then
        -- Swap: SwapRaidSubgroup exchanges the two players.
        pcall(SwapRaidSubgroup, src.raidIndex, dst.raidIndex)
    else
        -- Move: SetRaidSubgroup moves the player to the target group.
        pcall(SetRaidSubgroup, src.raidIndex, dst.group)
    end
end

-- Reorders the simulated roster in debug: swaps two members (occupied slot)
-- or moves a member exactly into the empty destination slot. The slots are
-- SPARSE, so a move leaves a hole in the source slot (shown by both the
-- InviteEngine Raid Group panel and this HUD).
function RF:MoveSlotDebug(src, dst)
    local slots = RLSuite:DebugRaidSlots()
    local srcMember = slots[src.slot]
    local dstMember = slots[dst.slot]
    if not srcMember then return end

    if dstMember then
        slots[src.slot], slots[dst.slot] = dstMember, srcMember
    else
        slots[dst.slot] = srcMember
        slots[src.slot] = nil
    end
    RLSuite:DebugSyncSubgroups()
    RLSuite:DebugRosterChanged()
end

-- ------------------------------------------------------------------
-- Pre-boss / in-fight alert bars
-- ------------------------------------------------------------------
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

    -- Pack group headers + visible slots vertically (G1..G6).
    local y = 0
    local shown = false
    for g = 1, RF_GROUPS do
        local hdr = self.groupHeaders and self.groupHeaders[g]
        local hdrShown = hdr ~= nil and hdr:IsShown()
        if hdrShown then
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, y)
            hdr:SetWidth(m.rowWidth)
            y = y - RF_HEADER_H
            shown = true
        end
        local anySlot = false
        for s = 1, RF_PER_GROUP do
            local slot = self.slots and self.slots[(g - 1) * RF_PER_GROUP + s]
            if slot and slot:IsShown() then
                slot:ClearAllPoints()
                slot:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
                self:LayoutSlotGeometry(slot, m)
                y = y - m.rowHeight
                anySlot = true
                shown = true
            end
        end
        if g < RF_GROUPS and (hdrShown or anySlot) then
            y = y - RF_GROUP_GAP
        end
    end
    local rowsH = shown and -y or 0

    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    self.content:SetSize(m.rowWidth, rowsH)

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
