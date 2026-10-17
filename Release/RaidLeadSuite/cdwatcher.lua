-- ============================================================
-- RLSuite - CD Watcher
-- ============================================================
-- Cooldown tracking and display extracted from RaidFrame.lua. The Raid Frame
-- remains responsible for the roster/HUD; this module owns the cooldown
-- combat-log tracker and its standalone window.
-- ============================================================

RLSuite.cdwatcher = {}
local CDW = RLSuite.cdwatcher

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

local MAX_CDS = 4
local ICON_SIZE = 22
local ICON_GAP = 4
local ROW_HEIGHT = 28
local NAME_WIDTH = 132
local CONTENT_WIDTH = NAME_WIDTH + 8 + MAX_CDS * (ICON_SIZE + ICON_GAP) + 8
local WINDOW_WIDTH = CONTENT_WIDTH + 44
local TITLE_HEIGHT = 30
local WINDOW_PAD = 8
local MAX_LIST_HEIGHT = 560
local TIMER_FONT_SIZE = 11

LibStub("AceEvent-3.0"):Embed(CDW)
LibStub("AceTimer-3.0"):Embed(CDW)

function CDW:Init()
    self.cdTracker = {}
    self.rows = {}
    self._rosterDirty = true
    self:EnsureWindow()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnRosterChanged")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnRosterChanged")
    self:ScheduleRepeatingTimer("Update", 0.5)
end

function CDW:EnsureWindow()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "RLSuiteCDWatcherWindow", UIParent)
    f:SetSize(WINDOW_WIDTH, 280)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:Hide()
    self.frame = f

    RLSuite.utils:MakeUniversalWindow(f, "cdwatcher")
    RLSuite.utils:ApplySavedPos(f, "cdwatcher")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", f, "TOPLEFT", WINDOW_PAD, -TITLE_HEIGHT / 2)
    title:SetText(L["CD Watcher"])
    title:SetTextColor(1, 0.82, 0)
    f.title = title

    f.closeBtn = RLSuite.utils:MakeCloseX(f, function() f:Hide() end)
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    self.listScroll = CreateFrame("ScrollFrame", "RLSuiteCDWatcherScroll", f, "UIPanelScrollFrameTemplate")
    self.listScroll:SetPoint("TOPLEFT", f, "TOPLEFT", WINDOW_PAD, -TITLE_HEIGHT)
    self.listScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, WINDOW_PAD)

    self.listContent = CreateFrame("Frame", nil, self.listScroll)
    self.listContent:SetSize(CONTENT_WIDTH, 1)
    self.listScroll:SetScrollChild(self.listContent)
    RLSuite.utils:RegisterScrollClip(self.listScroll, self.listContent)
    self.listScroll:SetScript("OnSizeChanged", function(_, width)
        if width and width > 40 and CDW.listContent then
            CDW.listContent:SetWidth(width)
        end
    end)

    f:SetScript("OnShow", function()
        CDW._rosterDirty = true
        CDW:RefreshRoster()
    end)
    f:SetScript("OnHide", function()
        for _, row in ipairs(CDW.rows or {}) do row:Hide() end
    end)

    return f
end

function CDW:Toggle()
    local f = self:EnsureWindow()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

function CDW:GetRoster()
    local rf = RLSuite.raidFrame
    if rf and rf.GetRoster then
        local ok, roster = pcall(rf.GetRoster, rf)
        if ok and type(roster) == "table" then return roster end
    end
    return {}
end

function CDW:RosterSignature(roster)
    local parts = {}
    for _, member in ipairs(roster or {}) do
        parts[#parts + 1] = table.concat({
            tostring(member.name or ""),
            tostring(member.class or ""),
            tostring(member.unit or ""),
            member.fake and "1" or "0",
        }, "|")
    end
    return table.concat(parts, "\n")
end

function CDW:EnsureRow(index)
    self.rows = self.rows or {}
    local row = self.rows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, self.listContent)
    row:SetSize(CONTENT_WIDTH, ROW_HEIGHT)
    row:EnableMouse(false)
    row.icons = {}

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", row, "LEFT", 4, 0)
    name:SetWidth(NAME_WIDTH)
    name:SetJustifyH("LEFT")
    row.nameText = name

    for j = 1, MAX_CDS do
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("LEFT", row, "LEFT", NAME_WIDTH + 8 + (j - 1) * (ICON_SIZE + ICON_GAP), 0)
        icon:Hide()

        local timer = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timer:SetPoint("CENTER", icon, "CENTER", 0, 0)
        timer:SetFont("Fonts\\FRIZQT__.TTF", TIMER_FONT_SIZE, "OUTLINE")
        timer:SetText("")
        icon.timer = timer
        row.icons[j] = icon
    end

    row:Hide()
    self.rows[index] = row
    return row
end

function CDW:ApplyAbilities(row, member)
    local abilities = RLSuite.keyAbilities and RLSuite.keyAbilities[member.class] or {}
    for j = 1, MAX_CDS do
        local icon = row.icons[j]
        local ability = abilities[j]
        if icon and ability then
            local meta = RLSuite.abilityByName and RLSuite.abilityByName[ability]
            icon:SetTexture((meta and meta.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
            icon.ability = ability
            icon:Show()
        elseif icon then
            icon.ability = nil
            icon:SetVertexColor(1, 1, 1)
            if icon.timer then icon.timer:SetText("") end
            icon:Hide()
        end
    end
end

function CDW:RefreshRoster(roster)
    if not self.frame then return end
    roster = roster or self:GetRoster()
    self.roster = roster
    self._rosterSignature = self:RosterSignature(roster)
    self._rosterDirty = false

    local rowHeight = ROW_HEIGHT
    for i, member in ipairs(roster) do
        local row = self:EnsureRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row:SetSize(CONTENT_WIDTH, rowHeight)
        row.member = member
        row.name = member.name
        row.unit = member.unit
        row.fake = member.fake

        local r, g, b = RLSuite.utils:GetClassColor(member.class)
        row.nameText:SetText(member.name or "Unknown")
        row.nameText:SetTextColor(r, g, b, 1)
        self:ApplyAbilities(row, member)
        row:Show()
    end

    for i = #roster + 1, #self.rows do
        local row = self.rows[i]
        if row then
            row.member = nil
            for _, icon in ipairs(row.icons or {}) do
                icon.ability = nil
                if icon.timer then icon.timer:SetText("") end
                icon:Hide()
            end
            row:Hide()
        end
    end

    local contentHeight = math.max(1, #roster * rowHeight)
    self.listContent:SetSize(CONTENT_WIDTH, contentHeight)
    local visibleHeight = math.min(math.max(rowHeight, contentHeight), MAX_LIST_HEIGHT)
    self.frame:SetSize(WINDOW_WIDTH, TITLE_HEIGHT + visibleHeight + WINDOW_PAD * 2)
    self:UpdateCooldownIcons()
end

function CDW:OnRosterChanged()
    self._rosterDirty = true
    if self.frame and self.frame:IsShown() then
        self:RefreshRoster()
    end
end

function CDW:Update()
    if not (self.frame and self.frame:IsShown()) then return end
    local roster = self:GetRoster()
    local signature = self:RosterSignature(roster)
    if self._rosterDirty or signature ~= self._rosterSignature then
        self:RefreshRoster(roster)
    else
        self:UpdateCooldownIcons()
    end
end

function CDW:UpdateCooldownIcons()
    for _, row in ipairs(self.rows or {}) do
        local member = row.member
        if member and row:IsShown() then
            for _, icon in ipairs(row.icons or {}) do
                if icon.ability then
                    local remaining = self:GetAbilityRemaining(row.name, row.unit, icon.ability)
                    if remaining and remaining > 0 then
                        icon:SetVertexColor(0.35, 0.35, 0.35)
                        if icon.timer then
                            icon.timer:SetText(RLSuite.utils:FormatCD(remaining))
                        end
                    else
                        icon:SetVertexColor(1, 1, 1)
                        if icon.timer then icon.timer:SetText("") end
                    end
                end
            end
        end
    end
end

-- GetSpellCooldown works for the local player. Other raid members are
-- tracked from the combat log and the WotLK cooldown baselines in Core.lua.
function CDW:GetAbilityRemaining(playerName, unit, ability)
    if unit and UnitIsUnit and UnitIsUnit(unit, "player") and GetSpellCooldown then
        local ids = RLSuite.abilitySpellIdByName and RLSuite.abilitySpellIdByName[ability]
        for _, spellId in ipairs(ids or {}) do
            local start, duration = GetSpellCooldown(spellId)
            if start and duration and duration > 1.5 then
                local remaining = start + duration - (GetTime and GetTime() or 0)
                if remaining > 0 then return remaining end
            end
        end
    end

    local tracker = self.cdTracker and self.cdTracker[playerName]
    local expire = tracker and tracker[ability]
    if expire then
        local remaining = expire - (GetTime and GetTime() or 0)
        if remaining > 0 then return remaining end
    end
    return 0
end

function CDW:OnCombatLog(event, ...)
    local _, subEvent, _, sourceName, _, _, _, _, spellId = ...
    if subEvent == "SPELL_CAST_SUCCESS" then
        self:OnSpellCast(sourceName, spellId)
    end
end

function CDW:OnSpellCast(sourceName, spellId)
    if not sourceName or not spellId then return end
    local ability = RLSuite.abilityBySpellId and RLSuite.abilityBySpellId[spellId]
    if not ability then return end
    local meta = RLSuite.abilityByName and RLSuite.abilityByName[ability]
    if not meta or not meta.cd then return end

    self.cdTracker = self.cdTracker or {}
    self.cdTracker[sourceName] = self.cdTracker[sourceName] or {}
    self.cdTracker[sourceName][ability] = (GetTime and GetTime() or 0) + meta.cd
    if self.frame and self.frame:IsShown() then
        self:UpdateCooldownIcons()
    end
end
