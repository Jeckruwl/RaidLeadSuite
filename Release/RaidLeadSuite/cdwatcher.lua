-- ============================================================
-- RLSuite - CD Watcher (WotLK 3.3.5)
-- ============================================================
-- Categorized cooldown/debuff monitor. This window is independent from the
-- Raid Frame; bars may be dropped on player rows to assign targets, and players
-- may be dropped into Tank Defensive to fill empty MT/OT assignments.
-- ============================================================

RLSuite.cdwatcher = {}
local CDW = RLSuite.cdwatcher
local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

local ROW_H, HEADER_H, SUBHEADER_H = 24, 24, 18
local TITLE_H, PAD, ICON_SIZE = 30, 8, 24
local DEFAULT_BAR_WIDTH, INSPECT_W = 240, 390
local TANK_PROMPT_H = 38
local DEAD_ICON = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local OFFLINE_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local STATUSBAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local STATUS_SQUARE_SIZE, STATUS_ICON_SIZE = 8, 14
local CUSTOM_PICKER_COLUMNS, CUSTOM_PICKER_BAR_WIDTH, CUSTOM_PICKER_COLUMN_GAP = 4, 200, 12
local CUSTOM_PICKER_CATEGORY_GAP = 4
local CUSTOM_PICKER_CATEGORY_ORDER = {
    {"raid_wide_offensive","single_target_offensive","battle_res","mana_regen","raid_party_defensive"},
    {"single_target_defensive","utility_dispel","tank_defensive"},
    {"threat","interrupts"},
    {"cc"},
}
local CDW_BAR_DRAG_START_DISTANCE = 6
local CLASS_LABELS = {
    WARRIOR="Warrior", PALADIN="Paladin", HUNTER="Hunter", ROGUE="Rogue", PRIEST="Priest",
    DEATHKNIGHT="Death Knight", SHAMAN="Shaman", MAGE="Mage", WARLOCK="Warlock", DRUID="Druid",
}
local function localizedClassName(class)
    local names=LOCALIZED_CLASS_NAMES_MALE or LOCALIZED_CLASS_NAMES_FEMALE
    return (names and names[class]) or CLASS_LABELS[class] or tostring(class or "Other")
end

-- Spell IDs are WotLK 3.3.5 IDs. Ranks and aliases are included where useful.
local CATEGORIES = {
    { key = "tank_defensive", title = "Tank Defensive", abilities = {
        { key="shield_wall", name="Shield Wall", class="WARRIOR", ids={871}, cd=300 },
        { key="last_stand", name="Last Stand", class="WARRIOR", ids={12975}, cd=180, specs={"Protection"}, tank=true },
        { key="icebound_fortitude", name="Icebound Fortitude", class="DEATHKNIGHT", ids={48792}, cd=120 },
        { key="anti_magic_shell", name="Anti-Magic Shell", class="DEATHKNIGHT", ids={48707}, cd=45 },
        { key="vampiric_blood", name="Vampiric Blood", class="DEATHKNIGHT", ids={55233}, cd=60, specs={"Blood"}, tank=true },
        { key="barkskin", name="Barkskin", class="DRUID", ids={22812}, cd=60, tank=true },
        { key="survival_instincts", name="Survival Instincts", class="DRUID", ids={61336}, cd=180, specs={"Feral"}, tank=true },
        { key="frenzied_regeneration", name="Frenzied Regeneration", class="DRUID", ids={22842}, cd=180, specs={"Feral"}, tank=true },
        { key="divine_protection", name="Divine Protection", class="PALADIN", ids={498}, cd=120 },
    } },
    { key = "raid_wide_offensive", title = "Raid Wide Offensive", abilities = {
        { key="bloodlust", name="Bloodlust / Heroism", class="SHAMAN", ids={2825,32182}, cd=300, duration=40, auraIds={2825,32182} },
        { key="shattering_throw", name="Shattering Throw", class="WARRIOR", ids={64382}, cd=300, specs={"Arms"}, duration=10, auraIds={64382} },
    } },
    { key = "raid_party_defensive", title = "Raid/Party Wide Defensive", abilities = {
        { key="aura_mastery", name="Aura Mastery", class="PALADIN", ids={31821}, cd=120, specs={"Holy"}, duration=6, auraIds={31821} },
        { key="divine_sacrifice", name="Divine Sacrifice", class="PALADIN", ids={64205}, cd=120, specs={"Protection"}, duration=10, auraIds={64205} },
        { key="divine_hymn", name="Divine Hymn", class="PRIEST", ids={64843}, cd=480, duration=8, auraIds={64843} },
        { key="anti_magic_zone", name="Anti-Magic Zone", class="DEATHKNIGHT", ids={51052}, cd=120, specs={"Unholy"}, duration=10, auraIds={51052} },
        { key="tranquility", name="Tranquility", class="DRUID", ids={48447,26983,9863,740}, cd=480, duration=8, auraIds={48447,26983} },
    } },
    { key = "single_target_offensive", title = "Single Target Offensive", abilities = {
        { key="power_infusion", name="Power Infusion", class="PRIEST", ids={10060}, cd=180, specs={"Discipline"}, duration=15, auraIds={10060}, target=true },
        { key="hysteria", name="Hysteria", class="DEATHKNIGHT", ids={49016}, cd=180, specs={"Blood"}, duration=30, auraIds={49016}, target=true },
    } },
    { key = "single_target_defensive", title = "Single Target Defensive", abilities = {
        { key="hand_of_sacrifice", name="Hand of Sacrifice", class="PALADIN", ids={6940}, cd=120, duration=12, auraIds={6940}, target=true },
        { key="hand_of_protection", name="Hand of Protection", class="PALADIN", ids={1022,5599,10278}, cd=300, duration=10, auraIds={1022,5599,10278}, target=true },
        { key="lay_on_hands", name="Lay on Hands", class="PALADIN", ids={633,2800,10310,27154,48788}, cd=1200, auraIds={633,2800,10310,27154,48788}, target=true },
        { key="pain_suppression", name="Pain Suppression", class="PRIEST", ids={33206}, cd=180, specs={"Discipline"}, duration=8, auraIds={33206}, target=true },
        { key="guardian_spirit", name="Guardian Spirit", class="PRIEST", ids={47788}, cd=180, specs={"Holy"}, duration=10, auraIds={47788}, target=true },
    } },
    { key = "battle_res", title = "Battle Resurrection", abilities = {
        { key="rebirth", name="Rebirth", class="DRUID", ids={48477,26994,20748,20484}, cd=600, target=true },
        { key="soulstone", name="Soulstone", class="WARLOCK", ids={47884,47883,27239,20765,20764,20763,20762,20707}, cd=900, duration=900, auraIds={47883,47884}, state="soulstone", target=true },
    } },
    { key = "mana_regen", title = "Mana Regeneration", abilities = {
        { key="innervate", name="Innervate", class="DRUID", ids={29166}, cd=180, duration=10, auraIds={29166}, target=true },
        { key="mana_tide_totem", name="Mana Tide Totem", class="SHAMAN", ids={16190}, cd=300, duration=12, auraIds={16190} },
        { key="hymn_of_hope", name="Hymn of Hope", class="PRIEST", ids={64901}, cd=360, duration=8, auraIds={64901} },
    } },
    { key = "threat", title = "Threat (Taunt and Aggro)", abilities = {
        { key="misdirection", name="Misdirection", class="HUNTER", ids={34477}, cd=30, duration=4, auraIds={34477}, target=true },
        { key="tricks_of_the_trade", name="Tricks of the Trade", class="ROGUE", ids={57934}, cd=30, duration=6, auraIds={57934}, target=true },
        { key="taunt", name="Taunt", class="WARRIOR", ids={355}, cd=8 },
        { key="hand_of_reckoning", name="Hand of Reckoning", class="PALADIN", ids={62124}, cd=8 },
        { key="righteous_defense", name="Righteous Defense", class="PALADIN", ids={31789}, cd=8 },
        { key="hand_of_salvation", name="Hand of Salvation", class="PALADIN", ids={1038,25895}, cd=120, duration=10, auraIds={1038,25895}, target=true },
        { key="dark_command", name="Dark Command", class="DEATHKNIGHT", ids={56222}, cd=8 },
        { key="death_grip", name="Death Grip", class="DEATHKNIGHT", ids={49576}, cd=35 },
        { key="growl", name="Growl", class="DRUID", ids={6795}, cd=8 },
    } },
    { key = "interrupts", title = "Interrupt Rotation", abilities = {
        { key="pummel", name="Pummel", class="WARRIOR", ids={6552}, cd=10 },
        { key="shield_bash", name="Shield Bash", class="WARRIOR", ids={72}, cd=12, shield=true },
        { key="silencing_shot", name="Silencing Shot", class="HUNTER", ids={34490}, cd=20, specs={"Marksmanship"} },
        { key="kick", name="Kick", class="ROGUE", ids={1766}, cd=10 },
        { key="mind_freeze", name="Mind Freeze", class="DEATHKNIGHT", ids={47528}, cd=10 },
        { key="strangulate", name="Strangulate", class="DEATHKNIGHT", ids={47476}, cd=120 },
        { key="wind_shear", name="Wind Shear", class="SHAMAN", ids={57994}, cd=6 },
        { key="counterspell", name="Counterspell", class="MAGE", ids={2139}, cd=24 },
        { key="spell_lock", name="Spell Lock (Felhunter)", class="WARLOCK", ids={19647}, cd=24, pet="Felhunter" },
    } },
    { key = "cc", title = "Crowd Control", abilities = {
        { key="polymorph", name="Polymorph", class="MAGE", ids={118,12824,12825,12826,28271,28272,61025}, auraIds={118,12824,12825,12826,28271,28272,61025}, cd=1.5, duration=50, target=true },
        { key="cyclone", name="Cyclone", class="DRUID", ids={33786}, auraIds={33786}, cd=1.5, duration=6, target=true },
        { key="entangling_roots", name="Entangling Roots", class="DRUID", ids={339,1062,5195,5196,9852,9853,26989}, auraIds={339,1062,5195,5196,9852,9853,26989}, cd=1.5, duration=27, target=true },
        { key="hex", name="Hex", class="SHAMAN", ids={51514}, auraIds={51514}, cd=45, duration=10, target=true },
        { key="blind", name="Blind", class="ROGUE", ids={2094}, auraIds={2094}, cd=180, duration=10, target=true },
        { key="freezing_trap", name="Freezing Trap", class="HUNTER", ids={14311,14310,14309,3355}, auraIds={3355}, cd=30, duration=60, target=true },
        { key="sap", name="Sap", class="ROGUE", ids={6770,2070,11297,51724}, auraIds={6770,2070,11297,51724}, cd=1.5, duration=25, target=true },
        { key="wyvern_sting", name="Wyvern Sting", class="HUNTER", ids={49012,49011}, auraIds={49012,49011}, cd=60, duration=12, target=true },
        { key="fear", name="Fear", class="WARLOCK", ids={5782,6213,6215}, auraIds={5782,6213,6215}, cd=1.5, duration=20, target=true, encounter="toc" },
        { key="banish", name="Banish", class="WARLOCK", ids={710,18647,18648}, auraIds={710,18647,18648}, cd=1.5, duration=60, target=true, encounter="toc" },
    } },
    { key = "utility_dispel", title = "Utility / Dispel", abilities = {
        { key="fear_ward", name="Fear Ward", class="PRIEST", ids={6346}, auraIds={6346}, cd=180, duration=180, target=true },
        { key="tremor_totem", name="Tremor Totem", class="SHAMAN", ids={8143}, cd=1.5, duration=120, totem=true },
        { key="mass_dispel", name="Mass Dispel", class="PRIEST", ids={32375}, cd=15 },
        { key="tranquilizing_shot", name="Tranquilizing Shot", class="HUNTER", ids={19801}, cd=10 },
        { key="purge", name="Purge", class="SHAMAN", ids={370,8012,27626,33625}, cd=1.5 },
        { key="grounding_totem", name="Grounding Totem", class="SHAMAN", ids={8177}, cd=15, duration=45, totem=true },
        { key="spellsteal", name="Spellsteal", class="MAGE", ids={30449}, cd=1.5 },
        { key="divine_intervention", name="Divine Intervention", class="PALADIN", ids={19752}, auraIds={19752}, cd=1200, duration=120, target=true },
    } },
}

local CATEGORY_BY_KEY, ABILITY_BY_KEY, ABILITY_BY_NAME = {}, {}, {}
local SPELL_TO_ABILITY, AURA_TO_ABILITY, ORDER_KEYS = {}, {}, {}
for _, category in ipairs(CATEGORIES) do
    CATEGORY_BY_KEY[category.key] = category
    ORDER_KEYS[#ORDER_KEYS + 1] = category.key
    for i, ability in ipairs(category.abilities) do
        ability.category, ability.order = category.key, i
        ability.ids, ability.auraIds = ability.ids or {}, ability.auraIds or {}
        ability.cd = tonumber(ability.cd) or 0
        ABILITY_BY_KEY[ability.key] = ability
        ABILITY_BY_NAME[ability.name] = ability
        for _, id in ipairs(ability.ids) do SPELL_TO_ABILITY[id] = ability end
        for _, id in ipairs(ability.auraIds) do AURA_TO_ABILITY[id] = ability end
    end
end

-- Macro layouts put related categories in their own floating windows.
-- Single Target Offensive is kept with the other offensive tools so every
-- existing category remains available in one of the macro groups.
local MACRO_GROUPS = {
    { key="offensive", title="Offensive", categories={
        "raid_wide_offensive", "single_target_offensive", "utility_dispel", "battle_res", "mana_regen",
    } },
    { key="defensive", title="Defensive", categories={
        "raid_party_defensive", "single_target_defensive",
    } },
    { key="tank_threat", title="Tank & Threat", categories={
        "tank_defensive", "threat",
    } },
    { key="int_cc", title="Int & CC", categories={
        "interrupts", "cc",
    } },
}
local MACRO_GROUP_BY_KEY, MACRO_GROUP_BY_CATEGORY = {}, {}
for _, group in ipairs(MACRO_GROUPS) do
    MACRO_GROUP_BY_KEY[group.key] = group
    for _, key in ipairs(group.categories) do MACRO_GROUP_BY_CATEGORY[key] = group end
end

local function isMacroLayout(mode)
    return mode == "macro"
end

local SPEC_TREES = {
    WARRIOR={"Arms","Fury","Protection"}, PALADIN={"Holy","Protection","Retribution"},
    HUNTER={"Beast Mastery","Marksmanship","Survival"}, ROGUE={"Assassination","Combat","Subtlety"},
    PRIEST={"Discipline","Holy","Shadow"}, DEATHKNIGHT={"Blood","Frost","Unholy"},
    SHAMAN={"Elemental","Enhancement","Restoration"}, MAGE={"Arcane","Fire","Frost"},
    WARLOCK={"Affliction","Demonology","Destruction"}, DRUID={"Balance","Feral","Restoration"},
}

LibStub("AceEvent-3.0"):Embed(CDW)
LibStub("AceTimer-3.0"):Embed(CDW)

local function shortName(name) return tostring(name or ""):gsub("%-.*$", "") end
local function sameName(a, b) return a and b and (a == b or shortName(a) == shortName(b)) end
local function clock() return (GetTime and GetTime()) or 0 end

function CDW:GetSettings()
    local profile = RLSuite.db and RLSuite.db.profile or {}
    profile.cdwatcher = profile.cdwatcher or {}
    return profile.cdwatcher
end

function CDW:NormalizeColor(color, fallback)
    if type(color) ~= "table" then color = fallback end
    return {
        r = tonumber(color and (color.r or color[1])) or fallback.r,
        g = tonumber(color and (color.g or color[2])) or fallback.g,
        b = tonumber(color and (color.b or color[3])) or fallback.b,
        a = 1,
    }
end

function CDW:NormalizeSettings()
    local s = self:GetSettings()
    if s.layoutMode ~= "separate" and s.layoutMode ~= "custom" and not isMacroLayout(s.layoutMode) then
        -- Retire the former single-panel and per-macro-group layouts.
        s.layoutMode = "macro"
    end
    s.categories, s.collapsed = s.categories or {}, s.collapsed or {}
    s.targetAssignments = type(s.targetAssignments) == "table" and s.targetAssignments or {}
    s.tankAssignments = type(s.tankAssignments) == "table" and s.tankAssignments or {}
    if s.groupMode ~= "caster" and s.groupMode ~= "spells" and s.groupMode ~= "none" then
        -- Migrate profiles saved with the former boolean checkbox.
        if s.groupMode == nil and s.groupByCaster == true then s.groupMode = "caster"
        else s.groupMode = "none" end
    end
    s.groupByCaster = s.groupMode == "caster" -- legacy compatibility
    s.customPanels = type(s.customPanels) == "table" and s.customPanels or {}
    for key in pairs(s.customPanels) do
        if type(key) ~= "number" or key < 1 or key > 6 or key % 1 ~= 0 then s.customPanels[key] = nil end
    end
    for index = 1, 6 do
        local panel = type(s.customPanels[index]) == "table" and s.customPanels[index] or {}
        local name = tostring(panel.name or "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then name = L["Panel %d"]:format(index) end
        panel.name = string.sub(name, 1, 32)
        panel.enabled = panel.enabled == true
        if panel.groupMode ~= "caster" and panel.groupMode ~= "spells" and panel.groupMode ~= "none" then
            -- Existing custom panels inherit the former global setting once,
            -- then keep their own persisted grouping mode independently.
            panel.groupMode = s.groupMode
        end
        local spells, seen = {}, {}
        local function addSpell(key)
            key = tostring(key or "")
            local ability = ABILITY_BY_KEY[key]
            if ability and ability.category and not seen[key] then
                spells[#spells+1], seen[key] = key, true
            end
        end
        if type(panel.spells) == "table" then
            for _, key in ipairs(panel.spells) do addSpell(key) end
            for key, enabled in pairs(panel.spells) do
                if type(key) ~= "number" and enabled == true then addSpell(key) end
            end
        end
        panel.spells = spells
        s.customPanels[index] = panel
    end
    if s.autoInspect == nil then s.autoInspect = true end
    s.hideTooltips = s.hideTooltips == true
    s.hideBackdrop = s.hideBackdrop == true
    s.showIcons = s.showIcons ~= false
    s.useClassColor = s.useClassColor ~= false
    s.barHeight = math.max(10, math.min(32, tonumber(s.barHeight) or ROW_H))
    s.barWidth = math.max(100, math.min(300, tonumber(s.barWidth) or DEFAULT_BAR_WIDTH))
    s.barTexture = type(s.barTexture) == "string" and s.barTexture or STATUSBAR_TEXTURE
    s.readyColor = self:NormalizeColor(s.readyColor, { r=0.20, g=0.75, b=0.25 })
    s.cooldownColor = self:NormalizeColor(s.cooldownColor, { r=0.95, g=0.60, b=0.12 })
    s.deadColor = self:NormalizeColor(s.deadColor, { r=0.30, g=0.30, b=0.32 })
    s.disconnectedColor = self:NormalizeColor(s.disconnectedColor, { r=0.48, g=0.40, b=0.18 })
    s.fontFace = type(s.fontFace) == "string" and s.fontFace or "Fonts\\FRIZQT__.TTF"
    s.fontSize = math.max(8, math.min(24, tonumber(s.fontSize) or 11))
    if s.fontOutline == nil then s.fontOutline = true end
    s.fontColor = self:NormalizeColor(s.fontColor, { r=1, g=1, b=1 })
    local order, seen = {}, {}
    for _, key in ipairs(s.categoryOrder or {}) do
        if CATEGORY_BY_KEY[key] and not seen[key] then order[#order+1], seen[key] = key, true end
    end
    for _, key in ipairs(ORDER_KEYS) do if not seen[key] then order[#order+1] = key end end
    s.categoryOrder = order
    return s
end

function CDW:IsMacroLayout(mode)
    return isMacroLayout(mode or self:NormalizeSettings().layoutMode)
end

function CDW:GetMacroGroupsForLayout(mode)
    mode = mode or self:NormalizeSettings().layoutMode
    return mode == "macro" and MACRO_GROUPS or {}
end

function CDW:MacroGroupForCategory(categoryKey)
    return MACRO_GROUP_BY_CATEGORY[categoryKey]
end

function CDW:IsMacroGroupSelected(groupKey, mode)
    mode = mode or self:NormalizeSettings().layoutMode
    return mode == "macro" and MACRO_GROUP_BY_KEY[groupKey] ~= nil
end

function CDW:MacroGroupHasEnabledCategories(group)
    if not group then return false end
    for _, key in ipairs(group.categories) do
        if self:IsCategoryEnabled(key) then return true end
    end
    return false
end

function CDW:GetMacroGroupCategoryOrder(group)
    local members, order={},{}
    for _,key in ipairs(group and group.categories or {}) do members[key]=true end
    for _,key in ipairs(self:GetCategoryOrder()) do
        if members[key] then order[#order+1]=key end
    end
    return order
end

function CDW:GetCustomPanels() return self:NormalizeSettings().customPanels end

function CDW:IsCustomPanelEditMode() return self.customPanelEditMode == true end

function CDW:SetCustomPanelNameDraft(index, name)
    index=tonumber(index)
    if not index or index<1 or index>6 then return end
    self.customPanelNameDrafts=self.customPanelNameDrafts or {}
    self.customPanelNameDrafts[index]=tostring(name or "")
end

function CDW:RenameCustomPanel(index, name)
    index=tonumber(index)
    if not index or index<1 or index>6 then return false end
    local panels=self:NormalizeSettings().customPanels
    local value=name
    if value==nil then
        if not self.customPanelNameDrafts or self.customPanelNameDrafts[index]==nil then return false end
        value=self.customPanelNameDrafts[index]
    end
    value=tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value=="" then value=L["Panel %d"]:format(index) end
    panels[index].name=string.sub(value,1,32)
    if self.customPanelNameDrafts then self.customPanelNameDrafts[index]=nil end
    if self.customWindows and self.customWindows[index] then
        self.customWindows[index].titleText:SetText(panels[index].name)
    end
    self:RefreshAll()
    return true
end

function CDW:SetCustomPanelEnabled(index, enabled)
    index=tonumber(index)
    if not index or index<1 or index>6 then return false end
    local panel=self:NormalizeSettings().customPanels[index]
    panel.enabled=enabled and true or false
    self:RefreshAll()
    if self:NormalizeSettings().layoutMode=="custom" then
        if panel.enabled then
            self.isOpen=true
            local window=self:EnsureCustomPanelWindow(index)
            window:Show()
            if self.customPanelEditMode then self:RaiseCustomSpellPicker() end
        elseif self.customWindows and self.customWindows[index] then
            self.customWindows[index]:Hide()
            self.isOpen=self:IsOpen()
        end
    end
    return true
end

function CDW:AddCustomPanelSpell(index, abilityKey)
    index=tonumber(index)
    if not index or index<1 or index>6 then return false end
    local ability=ABILITY_BY_KEY[abilityKey]
    if not ability then return false end
    local panel=self:NormalizeSettings().customPanels[index]
    for _,key in ipairs(panel.spells) do if key==abilityKey then return false end end
    panel.spells[#panel.spells+1]=abilityKey
    self:RefreshAll()
    return true
end

function CDW:RemoveCustomPanelSpell(index, abilityKey)
    index=tonumber(index)
    if not index or index<1 or index>6 then return false end
    local panel=self:NormalizeSettings().customPanels[index]
    for i,key in ipairs(panel.spells) do
        if key==abilityKey then table.remove(panel.spells,i); self:RefreshAll(); return true end
    end
    return false
end

function CDW:MoveCustomPanelSpell(sourceIndex, targetIndex, abilityKey)
    if sourceIndex==targetIndex then return false end
    if not self:AddCustomPanelSpell(targetIndex,abilityKey) then return false end
    self:RemoveCustomPanelSpell(sourceIndex,abilityKey)
    return true
end

function CDW:IsCustomSpellPickerAtCursor(ignorePanelOcclusion)
    local picker=self.customSpellPickerFrame
    if not (picker and picker:IsShown() and self:CursorInsideFrame(picker)) then return false end
    if ignorePanelOcclusion then return true end
    local pickerLevel=picker.GetFrameLevel and picker:GetFrameLevel() or 0
    for index=1,6 do
        local panel=self:NormalizeSettings().customPanels[index]
        local window=self.customWindows and self.customWindows[index]
        local level=window and window.GetFrameLevel and window:GetFrameLevel() or 0
        if panel.enabled and window and window:IsShown() and self:CursorInsideFrame(window) and level>pickerLevel then
            return false
        end
    end
    return true
end

function CDW:GetCustomPanelAtCursor(ignorePickerOcclusion,excludeIndex)
    local picker=self.customSpellPickerFrame
    local pickerAtCursor=picker and picker:IsShown() and self:CursorInsideFrame(picker)
    local pickerLevel=pickerAtCursor and picker.GetFrameLevel and picker:GetFrameLevel() or -1
    local target,targetLevel=nil,-1
    for index=1,6 do
        local panel=self:NormalizeSettings().customPanels[index]
        local window=self.customWindows and self.customWindows[index]
        if index~=excludeIndex and panel.enabled and window and window:IsShown() and self:CursorInsideFrame(window) then
            local level=window.GetFrameLevel and window:GetFrameLevel() or 0
            if (ignorePickerOcclusion or not pickerAtCursor or level>pickerLevel) and level>targetLevel then
                target,targetLevel=index,level
            end
        end
    end
    return target
end

function CDW:RaiseCustomSpellPicker()
    local picker=self.customSpellPickerFrame
    if picker and picker:IsShown() and RLSuite.utils and RLSuite.utils.RaiseWindow then
        RLSuite.utils:RaiseWindow(picker)
    end
end

function CDW:OnCustomSpellDragStop(frame)
    local model=frame and frame.data
    if not self.customPanelEditMode or not (model and model.customCatalogSpell and model.ability and model.ability.key) then return end
    local panelIndex=self:GetCustomPanelAtCursor(true)
    if panelIndex then self:AddCustomPanelSpell(panelIndex,model.ability.key) end
end

function CDW:OnCustomPanelBarDragStop(frame)
    local model=frame and frame.data
    if not self.customPanelEditMode or not (model and model.ability and model.ability.key) then
        return self:OnBarDragStop(frame)
    end
    -- In edit mode the spell picker intentionally stays above all custom
    -- panels; resolve drop targets by geometry rather than obscuring catalog
    -- rows by raising the panel windows over the editor.
    local targetIndex=self:GetCustomPanelAtCursor(true,model.customPanelIndex)
    if targetIndex then
        self:MoveCustomPanelSpell(model.customPanelIndex,targetIndex,model.ability.key)
    elseif self:IsCustomSpellPickerAtCursor(true) then
        self:RemoveCustomPanelSpell(model.customPanelIndex,model.ability.key)
    end
end

function CDW:IsManualBarDragCandidate(frame)
    local model=frame and frame.data
    return model and model.ability and model.ability.key and not model.preview
        and (not model.customCatalogSpell or self.customPanelEditMode)
end

function CDW:GetManualBarAtCursor()
    if not GetCursorPosition then return nil end
    local target,targetLevel=nil,-1
    for _,window in ipairs(self:GetWindows()) do
        local windowVisible=window.IsVisible and window:IsVisible()
        if windowVisible==nil and window.IsShown then windowVisible=window:IsShown() end
        if windowVisible then
            for _,row in pairs(window.barFrames or {}) do
                local rowVisible=row.IsVisible and row:IsVisible()
                if rowVisible==nil and row.IsShown then rowVisible=row:IsShown() end
                if rowVisible and self:IsManualBarDragCandidate(row) and self:CursorInsideFrame(row) then
                    local level=row.GetFrameLevel and row:GetFrameLevel() or 0
                    if level>targetLevel then target,targetLevel=row,level end
                end
            end
        end
    end
    return target
end

function CDW:QueueManualBarDrag(frame,button)
    if button~="LeftButton" or not self:IsManualBarDragCandidate(frame) or self._barDragSource then return end
    local x,y
    if GetCursorPosition then x,y=GetCursorPosition() end
    if not self._barDragButtonDown then
        self._barDragStartX,self._barDragStartY=x,y
        self._barDragCandidate=frame
    elseif not self._barDragCandidate then
        self._barDragCandidate=frame
        if not self._barDragStartX then self._barDragStartX,self._barDragStartY=x,y end
    end
    self._barDragButtonDown=true
end

function CDW:StartManualBarDrag(frame)
    if self._barDragSource or not self:IsManualBarDragCandidate(frame) then return false end
    self._barDragSource=frame
    self._barDragCandidate=frame
    local model=frame.data
    if model.customCatalogSpell then
        self.draggedCustomSpell=frame
    elseif model.customPanelIndex and self.customPanelEditMode then
        self.draggedCustomPanelSpell=frame
    else
        self.draggedBar=frame
    end
    return true
end

function CDW:FinishManualBarDrag()
    local frame=self._barDragSource
    if not frame then return false end
    local model=frame.data
    self._barDragSource,self._barDragCandidate=nil,nil
    self._barDragStartX,self._barDragStartY=nil,nil
    self._barDragButtonDown=false
    if model and model.customCatalogSpell then
        self:OnCustomSpellDragStop(frame)
    elseif model and model.customPanelIndex and self.customPanelEditMode then
        self:OnCustomPanelBarDragStop(frame)
    elseif model and not model.preview then
        self:OnBarDragStop(frame)
    end
    self.draggedCustomSpell,self.draggedCustomPanelSpell,self.draggedBar=nil,nil,nil
    if self.customPanelEditMode and model and (model.customCatalogSpell or model.customPanelIndex) then
        self:RaiseCustomSpellPicker()
    end
    return true
end

function CDW:HandleManualBarMouseUp(_,button)
    if button~="LeftButton" or not self._barDragButtonDown then return end
    local candidate=self._barDragCandidate
    local x,y
    if GetCursorPosition then x,y=GetCursorPosition() end
    if not self._barDragSource and candidate and x and self._barDragStartX
        and (math.abs(x-self._barDragStartX)>=CDW_BAR_DRAG_START_DISTANCE
            or math.abs((y or 0)-(self._barDragStartY or 0))>=CDW_BAR_DRAG_START_DISTANCE) then
        self:StartManualBarDrag(candidate)
    end
    if self._barDragSource then
        self:FinishManualBarDrag()
    else
        self._barDragButtonDown=false
        self._barDragCandidate=nil
        self._barDragStartX,self._barDragStartY=nil,nil
    end
end

function CDW:_InitManualBarDragPoller()
    if self._barDragPoller then return end
    local poller=CreateFrame("Frame",nil,UIParent)
    poller:SetSize(1,1)
    poller:EnableMouse(false)
    poller:Show()
    local elapsedTotal=0
    poller:SetScript("OnUpdate",function(_,elapsed)
        elapsedTotal=elapsedTotal+(elapsed or 0)
        if elapsedTotal<0.03 then return end
        elapsedTotal=0
        local down=IsMouseButtonDown and IsMouseButtonDown("LeftButton") or false
        if down then
            if not CDW._barDragButtonDown then
                CDW._barDragButtonDown=true
                CDW._barDragCandidate=CDW:GetManualBarAtCursor()
                if GetCursorPosition then CDW._barDragStartX,CDW._barDragStartY=GetCursorPosition() end
            elseif not CDW._barDragCandidate and not CDW._barDragSource then
                CDW._barDragCandidate=CDW:GetManualBarAtCursor()
                if CDW._barDragCandidate and GetCursorPosition then
                    CDW._barDragStartX,CDW._barDragStartY=GetCursorPosition()
                end
            end
            local candidate=CDW._barDragCandidate
            local x,y
            if GetCursorPosition then x,y=GetCursorPosition() end
            if candidate and not CDW._barDragSource and x and CDW._barDragStartX
                and (math.abs(x-CDW._barDragStartX)>=CDW_BAR_DRAG_START_DISTANCE
                    or math.abs((y or 0)-(CDW._barDragStartY or 0))>=CDW_BAR_DRAG_START_DISTANCE) then
                CDW:StartManualBarDrag(candidate)
            end
        elseif CDW._barDragButtonDown then
            local candidate=CDW._barDragCandidate
            local x,y
            if GetCursorPosition then x,y=GetCursorPosition() end
            if not CDW._barDragSource and candidate and x and CDW._barDragStartX
                and (math.abs(x-CDW._barDragStartX)>=CDW_BAR_DRAG_START_DISTANCE
                    or math.abs((y or 0)-(CDW._barDragStartY or 0))>=CDW_BAR_DRAG_START_DISTANCE) then
                CDW:StartManualBarDrag(candidate)
            end
            CDW._barDragButtonDown=false
            if CDW._barDragSource then
                CDW:FinishManualBarDrag()
            else
                CDW._barDragCandidate=nil
                CDW._barDragStartX,CDW._barDragStartY=nil,nil
            end
        end
    end)
    self._barDragPoller=poller
end

function CDW:GetCategoryOrder() return self:NormalizeSettings().categoryOrder end
function CDW:IsCategoryEnabled(key) return self:NormalizeSettings().categories[key] ~= false end
function CDW:GetBarHeight() return self:NormalizeSettings().barHeight end
function CDW:GetBarWidth() return self:NormalizeSettings().barWidth end

function CDW:ShouldForceCustomPanelBackdrop(frame)
    return self.customPanelEditMode == true and frame ~= nil
        and (frame.customPanelIndex ~= nil or frame._cdwCustomSpellPicker == true)
end

function CDW:ApplyBackdropSettings()
    local settings = self:NormalizeSettings()
    for _, frame in ipairs(self:GetWindows()) do
        frame._cdwWindow = true
        frame._noOuterBorder = true
        frame._cdwHideBackdrop = settings.hideBackdrop and not self:ShouldForceCustomPanelBackdrop(frame)
        if RLSuite.utils and RLSuite.utils.SkinFrame then RLSuite.utils:SkinFrame(frame) end
    end
end

function CDW:ApplyBarSettings()
    self._customSpellPickerDirty=true
    local settings=self:NormalizeSettings()
    self:ApplyBackdropSettings()
    if settings.hideTooltips and GameTooltip then GameTooltip:Hide() end
    self:RefreshAll()
end

function CDW:OpenConfig(section)
    local config = RLSuite.config
    if not config then return end
    if config.OpenCDWatcher then config:OpenCDWatcher(section or "general")
    elseif config.Open then config:Open() end
end

function CDW:SetCategoryEnabled(key, enabled)
    if not CATEGORY_BY_KEY[key] then return end
    local settings=self:NormalizeSettings()
    settings.categories[key] = enabled and true or false
    if not enabled and self.categoryWindows and self.categoryWindows[key] then self.categoryWindows[key]:Hide() end
    self:RefreshAll()
    if enabled and self.isOpen then
        if settings.layoutMode == "separate" then
            self:EnsureCategoryWindow(key):Show()
        elseif self:IsMacroLayout(settings.layoutMode) then
            local group=self:MacroGroupForCategory(key)
            if group and self:IsMacroGroupSelected(group.key,settings.layoutMode) then
                self:EnsureMacroGroupWindow(group.key):Show()
            end
        end
    end
end

function CDW:SetGroupMode(mode)
    if mode ~= "caster" and mode ~= "spells" and mode ~= "none" then return end
    local settings=self:NormalizeSettings()
    settings.groupMode=mode
    settings.groupByCaster=mode=="caster"
    self:RefreshAll()
end

function CDW:SetGroupByCaster(enabled)
    self:SetGroupMode(enabled and "caster" or "none")
end

function CDW:SetCustomPanelGroupMode(index, mode)
    index=tonumber(index)
    if not index or index<1 or index>6 or index%1~=0 then return false end
    if mode~="caster" and mode~="spells" and mode~="none" then return false end
    local panel=self:NormalizeSettings().customPanels[index]
    panel.groupMode=mode
    self:RefreshAll()
    return true
end

function CDW:SetAutoInspect(enabled)
    self:NormalizeSettings().autoInspect = enabled and true or false
    self:RefreshAll()
end

function CDW:IsOpen()
    if self.inspectFrame and self.inspectFrame:IsShown() then return true end
    if self.customSpellPickerFrame and self.customSpellPickerFrame:IsShown() then return true end
    for _, frame in pairs(self.categoryWindows or {}) do if frame:IsShown() then return true end end
    for _, frame in pairs(self.groupWindows or {}) do if frame:IsShown() then return true end end
    for _, frame in pairs(self.customWindows or {}) do if frame:IsShown() then return true end end
    return false
end

function CDW:PrepareWindow(frame, key)
    frame._cdwWindow = true
    frame._noOuterBorder = true
    local hideBackdrop=self:NormalizeSettings().hideBackdrop
    frame._cdwHideBackdrop=hideBackdrop and not self:ShouldForceCustomPanelBackdrop(frame)
    RLSuite.utils:MakeDraggable(frame, key)
    -- CD Watcher bars need the left mouse button for manual drag/drop. In
    -- WoW 3.3.5 a parent registered with RegisterForDrag can consume input
    -- from every child, so window movement is manual (titlebar drag or
    -- Shift+right-drag) and never registers the left button with the client.
    if frame.RegisterForDrag then frame:RegisterForDrag() end
    frame:SetScript("OnDragStart",nil)
    frame:SetScript("OnDragStop",nil)
    frame:SetScript("OnMouseDown",function(self2,button)
        local canMove=button=="RightButton" and IsShiftKeyDown and IsShiftKeyDown()
        if button=="LeftButton" and GetCursorPosition then
            local x,y=GetCursorPosition()
            local scale=frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
            if not scale or scale<=0 then scale=1 end
            local left,right,top=frame:GetLeft(),frame:GetRight(),frame:GetTop()
            if x and y and left and right and top then
                x,y=x/scale,y/scale
                canMove=x>=left and x<=right and y<=top and y>=top-TITLE_H
            end
        end
        if canMove then
            self2._cdwManualMoving=true
            self2._cdwManualMoveButton=button
            if frame._rlsDragGuard then frame._rlsDragGuard:Show() end
            self2:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp",function(self2,button)
        if button==self2._cdwManualMoveButton and self2._cdwManualMoving then
            self2._cdwManualMoving=nil
            self2._cdwManualMoveButton=nil
            if frame._rlsDragStop then frame._rlsDragStop(self2) end
        end
    end)
    if frame._rlsDragGuard and frame._rlsDragGuard.HookScript then
        frame._rlsDragGuard:HookScript("OnUpdate",function()
            local moveButton=frame._cdwManualMoveButton
            if frame._cdwManualMoving and moveButton and IsMouseButtonDown
                and not IsMouseButtonDown(moveButton) then
                frame._cdwManualMoving=nil
                frame._cdwManualMoveButton=nil
                if frame._rlsDragStop then frame._rlsDragStop(frame) end
            end
        end)
    end
    if frame.customPanelIndex then
        -- Editing keeps the spell catalog in front; panel windows remain
        -- valid drop targets by bounds and must not cover catalog spells.
        frame._rlsFront = true
        local oldMouseDown=frame:GetScript("OnMouseDown")
        frame:SetScript("OnMouseDown",function(self2,button)
            if CDW.customPanelEditMode then
                CDW:RaiseCustomSpellPicker()
            elseif RLSuite.utils and RLSuite.utils.RaiseWindow then
                RLSuite.utils:RaiseWindow(frame)
            end
            if oldMouseDown then oldMouseDown(self2,button) end
        end)
    else
        RLSuite.utils:MakeClickToFront(frame)
    end
    frame._noOuterBorder = true
    if RLSuite.utils.SkinFrame then RLSuite.utils:SkinFrame(frame) end
end

function CDW:CreateWindow(name, title, key, width, categoryKey, macroGroupKey, customPanelIndex)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, 260)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:Hide()
    frame.categoryKey, frame.macroGroupKey, frame.customPanelIndex = categoryKey, macroGroupKey, customPanelIndex
    frame.barFrames, frame.headerFrames, frame.subheaderFrames, frame.promptFrames = {}, {}, {}, {}
    self:PrepareWindow(frame, key)
    RLSuite.utils:ApplySavedPos(frame, key, function()
        local idx = 1
        if macroGroupKey then
            for i, group in ipairs(MACRO_GROUPS) do if group.key == macroGroupKey then idx = i break end end
        elseif categoryKey then
            for i, cat in ipairs(self:GetCategoryOrder()) do if cat == categoryKey then idx = i break end end
        end
        return ((idx - 1) % 3) * 34, -math.floor((idx - 1) / 3) * 34
    end)

    frame.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.titleText:SetPoint("LEFT", frame, "TOPLEFT", PAD, -TITLE_H / 2)
    frame.titleText:SetWidth(math.max(80,width-60))
    frame.titleText:SetJustifyH("LEFT")
    frame.titleText:SetText(title)
    frame.titleText:SetTextColor(1, 0.82, 0)
    frame.closeBtn = RLSuite.utils:MakeCloseX(frame, function() frame:Hide() end)
    frame.closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TITLE_H)
    frame.content:SetSize(width - 40, 1)
    frame:SetScript("OnShow", function() CDW:RefreshAll() end)
    frame:SetScript("OnHide", function()
        local mode = CDW:NormalizeSettings().layoutMode
        if frame.categoryKey and mode == "separate" then
            local any = false
            for _, f in pairs(CDW.categoryWindows or {}) do if f:IsShown() then any = true break end end
            if not any then CDW.isOpen = false end
        elseif frame.macroGroupKey and isMacroLayout(mode) then
            local any = false
            for _, f in pairs(CDW.groupWindows or {}) do if f:IsShown() then any = true break end end
            if not any then CDW.isOpen = false end
        elseif frame.customPanelIndex and mode == "custom" then
            local any = (CDW.inspectFrame and CDW.inspectFrame:IsShown())
                or (CDW.customSpellPickerFrame and CDW.customSpellPickerFrame:IsShown()) or false
            for _, f in pairs(CDW.customWindows or {}) do if f:IsShown() then any = true break end end
            if not any then CDW.isOpen = false end
        end
    end)
    return frame
end

function CDW:EnsureCategoryWindow(key)
    if self.categoryWindows[key] then return self.categoryWindows[key] end
    local category = CATEGORY_BY_KEY[key]
    if not category then return nil end
    self.categoryWindows[key] = self:CreateWindow("RLSuiteCDW_" .. key, L[category.title] or category.title,
        "cdwatcher_" .. key, self:GetBarWidth() + 40, key)
    return self.categoryWindows[key]
end

function CDW:EnsureMacroGroupWindow(key)
    self.groupWindows = self.groupWindows or {}
    if self.groupWindows[key] then return self.groupWindows[key] end
    local group = MACRO_GROUP_BY_KEY[key]
    if not group then return nil end
    self.groupWindows[key] = self:CreateWindow("RLSuiteCDWGroup_" .. key, L[group.title] or group.title,
        "cdwatcher_group_" .. key, self:GetBarWidth() + 40, nil, key)
    return self.groupWindows[key]
end

function CDW:CustomPanelLayoutKey(index)
    return "cdwatcher_custom_panel_"..tostring(index)
end

function CDW:CustomPanelRowHeight(row)
    local first=(row-1)*3+1
    local height=0
    for index=first,first+2 do
        local frame=self.customWindows and self.customWindows[index]
        if frame then height=math.max(height,tonumber(frame:GetHeight()) or 0) end
    end
    if height>0 then return height end
    local screenHeight=UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    if screenHeight<=0 and GetScreenHeight then screenHeight=GetScreenHeight() end
    return math.max(260,(tonumber(screenHeight) or 768)*0.42)
end

function CDW:PositionDefaultCustomPanels()
    local panelWidth=self:GetBarWidth()+40
    local gapX=12
    for index=1,6 do
        local frame=self.customWindows and self.customWindows[index]
        if frame then
            local layout=RLSuite.utils:WindowLayout(self:CustomPanelLayoutKey(index))
            if not layout.point then
                local col=(index-1)%3
                local row=math.floor((index-1)/3)
                local x=col*(panelWidth+gapX)
                local y=0
                for priorRow=1,row do y=y-(self:CustomPanelRowHeight(priorRow)+16) end
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,y)
            end
        end
    end
end

function CDW:EnsureCustomPanelWindow(index)
    index=tonumber(index)
    if not index or index<1 or index>6 then return nil end
    self.customWindows=self.customWindows or {}
    if self.customWindows[index] then return self.customWindows[index] end
    local panel=self:NormalizeSettings().customPanels[index]
    local key=self:CustomPanelLayoutKey(index)
    local window=self:CreateWindow("RLSuiteCDWCustomPanel"..index,panel.name,key,self:GetBarWidth()+40,nil,nil,index)
    window.emptyText=window.content:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    window.emptyText:SetPoint("TOPLEFT",window.content,"TOPLEFT",8,-10)
    window.emptyText:SetWidth(self:GetBarWidth()-12)
    window.emptyText:SetWordWrap(true)
    window.emptyText:SetTextColor(0.85,0.85,0.85,1)
    window.emptyText:Hide()
    self.customWindows[index]=window
    return window
end

function CDW:EnsureCustomSpellPickerWindow()
    if self.customSpellPickerFrame then return self.customSpellPickerFrame end
    local screenWidth=UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    local screenHeight=UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    if screenWidth<=0 and GetScreenWidth then screenWidth=GetScreenWidth() end
    if screenHeight<=0 and GetScreenHeight then screenHeight=GetScreenHeight() end
    screenWidth=tonumber(screenWidth) or 1280
    screenHeight=tonumber(screenHeight) or 768
    local width=math.max(480,math.min(900,screenWidth-24))
    local height=math.max(420,math.min(760,screenHeight*0.86))
    local key="cdwatcher_custom_spell_picker"
    local window=self:CreateWindow("RLSuiteCDWCustomSpellPicker",L["Custom panel editor"],key,width)
    window:SetSize(width,height)
    local layout=RLSuite.utils:WindowLayout(key)
    if not layout.point then
        window:ClearAllPoints()
        window:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-12,-40)
    end
    local scroll=CreateFrame("ScrollFrame","RLSuiteCDWCustomSpellPickerScroll",window,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",window,"TOPLEFT",PAD,-TITLE_H)
    scroll:SetPoint("BOTTOMRIGHT",window,"BOTTOMRIGHT",-28,PAD)
    scroll:SetSize(width-40,height-TITLE_H-PAD*2)
    if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
    if scroll.SetScript then
        scroll:SetScript("OnMouseWheel",function(frame,delta)
            if IsShiftKeyDown and IsShiftKeyDown() and frame.GetHorizontalScrollRange and frame.SetHorizontalScroll then
                local current=frame.GetHorizontalScroll and frame:GetHorizontalScroll() or 0
                local range=frame:GetHorizontalScrollRange() or 0
                frame:SetHorizontalScroll(math.max(0,math.min(range,current-delta*36)))
            else
                local current=frame.GetVerticalScroll and frame:GetVerticalScroll() or 0
                local range=frame.GetVerticalScrollRange and frame:GetVerticalScrollRange() or 0
                frame:SetVerticalScroll(math.max(0,math.min(range,current-delta*36)))
            end
        end)
    end
    window.content:SetParent(scroll)
    window.content:ClearAllPoints()
    window.content:SetPoint("TOPLEFT",scroll,"TOPLEFT",0,0)
    window.content:SetSize(math.max(width-64,CUSTOM_PICKER_COLUMNS*CUSTOM_PICKER_BAR_WIDTH
        +(CUSTOM_PICKER_COLUMNS-1)*CUSTOM_PICKER_COLUMN_GAP),1)
    scroll:SetScrollChild(window.content)
    window.scroll=scroll
    window.columnCount=CUSTOM_PICKER_COLUMNS
    window.customCategoryHeaders={}
    window.customClassHeaders={}
    window._cdwCustomSpellPicker=true
    self.customSpellPickerFrame=window
    self:ApplyBackdropSettings()
    window:SetScript("OnHide",function()
        local wasEditing=CDW.customPanelEditMode
        CDW.customPanelEditMode=false
        CDW:ApplyBackdropSettings()
        CDW.isOpen=CDW:IsOpen()
        if wasEditing and RLSuite.config and RLSuite.config.NotifyChange then
            RLSuite.config:NotifyChange()
        end
    end)
    return window
end

function CDW:EnsureInspectWindow()
    if self.inspectFrame then return self.inspectFrame end
    local f = self:CreateWindow("RLSuiteCDWInspect", L["CD Watcher: Inspect required"], "cdwatcher_inspect", INSPECT_W)
    f.inspectRows = {}
    f:SetScript("OnHide", function() CDW._inspectDismissed = true end)
    self.inspectFrame = f
    return f
end

function CDW:GetWindows()
    local result = {}
    if self.inspectFrame then result[#result+1] = self.inspectFrame end
    if self.previewWindow then result[#result+1] = self.previewWindow end
    for _, category in ipairs(CATEGORIES) do
        if self.categoryWindows and self.categoryWindows[category.key] then result[#result+1] = self.categoryWindows[category.key] end
    end
    for _, group in ipairs(MACRO_GROUPS) do
        if self.groupWindows and self.groupWindows[group.key] then result[#result+1] = self.groupWindows[group.key] end
    end
    for index=1,6 do
        if self.customWindows and self.customWindows[index] then result[#result+1]=self.customWindows[index] end
    end
    if self.customSpellPickerFrame then result[#result+1]=self.customSpellPickerFrame end
    return result
end

function CDW:Init()
    self:NormalizeSettings()
    self.cdTracker, self.activeAuras, self.activePlayerStates = self.cdTracker or {}, self.activeAuras or {}, self.activePlayerStates or {}
    self.soulstoneStates, self.totemStates = self.soulstoneStates or {}, self.totemStates or {}
    self.inspectCache, self.inspectStatus, self.inspectQueue = self.inspectCache or {}, self.inspectStatus or {}, self.inspectQueue or {}
    self.categoryWindows, self.groupWindows, self.customWindows, self.rows = self.categoryWindows or {}, self.groupWindows or {}, self.customWindows or {}, self.rows or {}
    self.customPanelNameDrafts = self.customPanelNameDrafts or {}
    self.customPanelEditMode = false
    self._customSpellPickerDirty = true
    self._nextInspectAt = 0
    self._rosterDirty = true
    self.initialized = true
    self:_InitManualBarDragPoller()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnRosterChanged")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnRosterChanged")
    self:RegisterEvent("INSPECT_READY", "OnInspectReady")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnInspectPermissionChanged")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnRosterChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnRosterChanged")
    self:RegisterEvent("UPDATE_INSTANCE_INFO", "OnRosterChanged")
    self:ScheduleRepeatingTimer("Update", 0.5)
    self:RefreshAll()
end

function CDW:ShowCurrentMode()
    self._inspectDismissed = false
    local mode, shown = self:NormalizeSettings().layoutMode, false
    if mode == "separate" then
        if self.customPanelEditMode then
            self.customPanelEditMode=false
            self:ApplyBackdropSettings()
        end
        if self.customSpellPickerFrame then self.customSpellPickerFrame:Hide() end
        for _, frame in pairs(self.groupWindows or {}) do frame:Hide() end
        for _, frame in pairs(self.customWindows or {}) do frame:Hide() end
        for _, key in ipairs(self:GetCategoryOrder()) do
            if self:IsCategoryEnabled(key) then
                self:EnsureCategoryWindow(key):Show(); shown=true
            elseif self.categoryWindows[key] then
                self.categoryWindows[key]:Hide()
            end
        end
    elseif self:IsMacroLayout(mode) then
        if self.customPanelEditMode then
            self.customPanelEditMode=false
            self:ApplyBackdropSettings()
        end
        if self.customSpellPickerFrame then self.customSpellPickerFrame:Hide() end
        for _, frame in pairs(self.categoryWindows) do frame:Hide() end
        for _, frame in pairs(self.customWindows or {}) do frame:Hide() end
        local selected={}
        for _, group in ipairs(self:GetMacroGroupsForLayout(mode)) do
            selected[group.key]=true
            if self:MacroGroupHasEnabledCategories(group) then
                self:EnsureMacroGroupWindow(group.key):Show(); shown=true
            elseif self.groupWindows[group.key] then
                self.groupWindows[group.key]:Hide()
            end
        end
        for key, frame in pairs(self.groupWindows or {}) do
            if not selected[key] then frame:Hide() end
        end
    elseif mode == "custom" then
        for _, frame in pairs(self.categoryWindows) do frame:Hide() end
        for _, frame in pairs(self.groupWindows or {}) do frame:Hide() end
        for index=1,6 do
            local panel=self:NormalizeSettings().customPanels[index]
            if panel.enabled then
                self:EnsureCustomPanelWindow(index):Show(); shown=true
            elseif self.customWindows[index] then
                self.customWindows[index]:Hide()
            end
        end
        if self.customPanelEditMode then
            self:EnsureCustomSpellPickerWindow():Show(); shown=true
        elseif self.customSpellPickerFrame then
            self.customSpellPickerFrame:Hide()
        end
    end
    if #((self.inspectItems) or {}) > 0 then self:EnsureInspectWindow():Show(); shown=true end
    self.isOpen=shown
    if not shown then self:OpenConfig("general") end
end

function CDW:Toggle()
    local mode, displayOpen = self:NormalizeSettings().layoutMode, false
    if mode == "separate" then
        for _, frame in pairs(self.categoryWindows) do if frame:IsShown() then displayOpen=true break end end
    elseif mode == "custom" then
        for _, frame in pairs(self.customWindows or {}) do if frame:IsShown() then displayOpen=true break end end
        if self.customSpellPickerFrame and self.customSpellPickerFrame:IsShown() then displayOpen=true end
    else
        for key, frame in pairs(self.groupWindows or {}) do
            if frame:IsShown() and self:IsMacroGroupSelected(key,mode) then displayOpen=true break end
        end
    end
    if displayOpen then
        self.isOpen=false
        self.customPanelEditMode=false
        self:ApplyBackdropSettings()
        if self.inspectFrame then self.inspectFrame:Hide() end
        if self.customSpellPickerFrame then self.customSpellPickerFrame:Hide() end
        for _, frame in pairs(self.categoryWindows) do frame:Hide() end
        for _, frame in pairs(self.groupWindows or {}) do frame:Hide() end
        for _, frame in pairs(self.customWindows or {}) do frame:Hide() end
        return
    end
    self:ShowCurrentMode()
end

function CDW:SetLayoutMode(mode)
    if mode ~= "separate" and mode ~= "custom" and not isMacroLayout(mode) then return end
    local wasOpen = self:IsOpen()
    self:NormalizeSettings().layoutMode = mode
    self.customPanelEditMode=false
    self:ApplyBackdropSettings()
    if self.inspectFrame then self.inspectFrame:Hide() end
    if self.customSpellPickerFrame then self.customSpellPickerFrame:Hide() end
    for _, frame in pairs(self.categoryWindows) do frame:Hide() end
    for _, frame in pairs(self.groupWindows or {}) do frame:Hide() end
    for _, frame in pairs(self.customWindows or {}) do frame:Hide() end
    self.isOpen, self._inspectDismissed = wasOpen, false
    self:RefreshAll()
    if wasOpen then self:ShowCurrentMode() end
end

function CDW:SetCustomPanelEditMode(enabled)
    if self:NormalizeSettings().layoutMode~="custom" then return false end
    self.customPanelEditMode=enabled and true or false
    self:ApplyBackdropSettings()
    if self.customPanelEditMode then
        self.isOpen=true
        self:RefreshAll()
        for index=1,6 do
            local panel=self:NormalizeSettings().customPanels[index]
            if panel.enabled then self:EnsureCustomPanelWindow(index):Show() end
        end
        self:EnsureCustomSpellPickerWindow():Show()
        -- Keep the picker above panel backdrops throughout editing. Panel drop
        -- targets are resolved from cursor geometry, so their windows never
        -- need to be raised over (and obscure) the spell catalog.
        self:RaiseCustomSpellPicker()
    else
        if self.customSpellPickerFrame then self.customSpellPickerFrame:Hide() end
        self:RefreshAll()
        self.isOpen=self:IsOpen()
    end
    return true
end

function CDW:RetryInspection()
    self.inspectQueue = {}
    for _, item in ipairs(self.inspectItems or {}) do
        local key = shortName(item.name)
        self.inspectCache[key], self.inspectStatus[key] = nil, nil
        self.inspectQueue[#self.inspectQueue+1] = { name=item.name, unit=item.unit }
    end
    self._nextInspectAt, self._inspectDismissed = 0, false
    self:RefreshAll()
    self:TryInspectQueue(true)
end

function CDW:GetRoster()
    local rf = RLSuite.raidFrame
    if rf and rf.GetRoster then
        local ok, roster = pcall(rf.GetRoster, rf)
        if ok and type(roster) == "table" then return roster end
    end
    return {}
end

function CDW:FindMember(name)
    for _, member in ipairs(self.roster or self:GetRoster()) do if sameName(member.name, name) then return member end end
    return nil
end

function CDW:ReadSpec(inspect, class)
    if not GetTalentTabInfo then return nil end
    local group = 1
    if GetActiveTalentGroup then
        local ok, activeGroup = pcall(GetActiveTalentGroup, inspect and true or false, false)
        if ok and tonumber(activeGroup) and tonumber(activeGroup) > 0 then group = tonumber(activeGroup) end
    end
    local best, points = nil, -1
    for tab = 1, 3 do
        local ok, tabName, icon, spent = pcall(GetTalentTabInfo, tab, inspect and true or false, false, group)
        spent = ok and tonumber(spent) or nil
        if spent and spent > points then best, points = tab, spent end
    end
    if not best or points <= 0 then return nil end
    return (SPEC_TREES[class or ""] or {})[best]
end

function CDW:GetSpec(member)
    if not member or member.fake then return nil end
    local cached = self.inspectCache and self.inspectCache[shortName(member.name)]
    if cached then return cached.spec end
    if member.unit and UnitIsUnit and UnitIsUnit(member.unit, "player") then return self:ReadSpec(false, member.class) end
    return nil
end

function CDW:GetTankAssignments(roster)
    roster = roster or self.roster or self:GetRoster()
    local members, assigned, roles = {}, {}, { mt=nil, ot=nil }
    for _, member in ipairs(roster) do members[shortName(member.name)] = member end
    local function add(role, name, source)
        if not name then return end
        local key = shortName(name)
        local member = members[key]
        if not member then return end
        roles[role] = member.name
        assigned[key] = assigned[key] or { name=member.name, role=role, source=source }
    end

    local rf = RLSuite.raidFrame
    local slots = rf and rf.tankSlots or {}
    for index, slot in ipairs(slots) do
        local role = index == 1 and "mt" or (index == 2 and "ot" or nil)
        local name = slot and slot.member and slot.member.name or (slot and slot.name)
        if role and name then add(role, name, "raidframe") end
    end
    if GetPartyAssignment then
        for _, member in ipairs(roster) do
            local unit = member.unit or member.name
            if unit then
                if not roles.mt and GetPartyAssignment("MAINTANK", unit) then add("mt", member.name, "raidframe") end
                if not roles.ot and GetPartyAssignment("MAINASSIST", unit) then add("ot", member.name, "raidframe") end
            end
        end
    end

    local settings = self:NormalizeSettings()
    for _, role in ipairs({ "mt", "ot" }) do
        if not roles[role] and settings.tankAssignments[role] then
            add(role, settings.tankAssignments[role], "cdwatcher")
        elseif settings.tankAssignments[role] and not members[shortName(settings.tankAssignments[role])] then
            settings.tankAssignments[role] = nil
        end
    end
    self.assignedTankMembers, self.tankAssignmentRoles = assigned, roles
    return assigned, roles
end

function CDW:IsTank(member)
    if not member or not member.name then return false end
    local assigned = self.assignedTankMembers or self:GetTankAssignments(self.roster)
    return assigned[shortName(member.name)] ~= nil
end

function CDW:AddInspectNeed(needs, member, reason)
    if not member or member.fake or not member.name then return end
    local key = shortName(member.name)
    local item = needs[key]
    if not item then item = { name=member.name, unit=member.unit, class=member.class, reasons={} }; needs[key] = item end
    item.reasons[reason] = true
end

function CDW:HasShield(member, afterInspect)
    local cached = self.inspectCache and self.inspectCache[shortName(member.name)]
    if cached and cached.hasShield ~= nil then return cached.hasShield end
    if not member.unit or not GetInventoryItemLink then return nil end
    if not (UnitIsUnit and UnitIsUnit(member.unit, "player")) and not cached and not afterInspect then return nil end
    local link = GetInventoryItemLink(member.unit, 17)
    if not link then return false end
    if not GetItemInfo then return nil end
    local _, _, _, _, _, itemType, subType = GetItemInfo(link)
    if not subType then return nil end
    local lowered=string.lower(tostring(subType))
    return string.find(lowered,"shield",1,true)~=nil or string.find(lowered,"scudo",1,true)~=nil
end

function CDW:HasFelhunter(member)
    if not member.unit or not UnitCreatureFamily or not UnitExists then return nil end
    local petUnit = member.unit .. "pet"
    if not UnitExists(petUnit) then return nil end
    local family = UnitCreatureFamily(petUnit)
    if not family then return nil end
    local lowered=string.lower(tostring(family))
    return string.find(lowered,"felhunter",1,true)~=nil or string.find(lowered,"vilsegugio",1,true)~=nil
end

function CDW:IsTrialOfTheCrusader10Or25()
    local instanceName, instanceType, difficultyID, difficultyName, maxPlayers
    if GetInstanceInfo then
        instanceName, instanceType, difficultyID, difficultyName, maxPlayers = GetInstanceInfo()
    end
    local zone = GetRealZoneText and GetRealZoneText() or nil
    local name = string.lower(tostring(instanceName or zone or ""))
    local isTrial = name == "trial of the crusader" or name == "trial of the grand crusader"
    if not isTrial or (instanceType and instanceType ~= "raid") then return false end

    local size = tonumber(maxPlayers)
    local difficulty = tonumber(difficultyID)
    if size ~= 10 and size ~= 25 then
        if difficulty == 3 or difficulty == 5 then size = 10
        elseif difficulty == 4 or difficulty == 6 then size = 25 end
    end
    if size ~= 10 and size ~= 25 then
        local label = string.lower(tostring(difficultyName or ""))
        if string.find(label, "10", 1, true) then size = 10
        elseif string.find(label, "25", 1, true) then size = 25 end
    end
    return size == 10 or size == 25
end

function CDW:CanTrack(ability, member, needs)
    if ability.encounter == "toc" and not self:IsTrialOfTheCrusader10Or25() then return false, false end
    if ability.allPlayers then return true, false end
    if not member or member.class ~= ability.class then return false, false end
    local unknown, spec = false, self:GetSpec(member)
    if ability.specs then
        if not spec then unknown = true; self:AddInspectNeed(needs, member, L["Talent specialization required"])
        else
            local found = false
            for _, value in ipairs(ability.specs) do if value == spec then found = true break end end
            if not found then return false, false end
        end
    end
    if ability.tank then
        local tank = self:IsTank(member)
        if tank == false then return false, false end
        if tank == nil then unknown = true; self:AddInspectNeed(needs, member, L["Tank role / specialization required"]) end
    end
    if ability.shield then
        local shield = self:HasShield(member)
        if shield == false then return false, false end
        if shield == nil then unknown = true; self:AddInspectNeed(needs, member, L["Shield availability requires inspect"]) end
    end
    if ability.pet and not member.fake then
        local hasPet = self:HasFelhunter(member)
        if hasPet == false then return false, false end
        if hasPet == nil then unknown = true; self:AddInspectNeed(needs, member, L["Felhunter availability requires inspect"]) end
    end
    return true, unknown
end

function CDW:ClassColor(class)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r or 0.7, color.g or 0.7, color.b or 0.7 end
    if RLSuite.utils and RLSuite.utils.GetClassColor then return RLSuite.utils:GetClassColor(class) end
    return 0.7, 0.7, 0.7
end

function CDW:GetAbilityRemaining(playerName, unit, ability)
    local def = type(ability) == "table" and ability or ABILITY_BY_KEY[ability] or ABILITY_BY_NAME[ability]
    if not def then return 0 end
    local member = self:FindMember(playerName)
    if unit and (not member or not member.fake) and UnitIsUnit and UnitIsUnit(unit, "player") and GetSpellCooldown and def.cd > 1.5 then
        for _, id in ipairs(def.ids or {}) do
            local start, duration = GetSpellCooldown(id)
            if start and duration and duration > 1.5 then
                local left = start + duration - clock()
                if left > 0 then return left end
            end
        end
    end
    local cd = self.cdTracker and (self.cdTracker[shortName(playerName)] or self.cdTracker[playerName])
    local expire = cd and (cd[def.key] or cd[def.name])
    return expire and math.max(0, expire - clock()) or 0
end

function CDW:GetActive(ability, casterName, playerName)
    local state
    if ability.allPlayers then
        local byPlayer = self.activePlayerStates[shortName(playerName or "")] or {}
        state = byPlayer[ability.key]
    elseif ability.state == "soulstone" then
        state = self.soulstoneStates[shortName(casterName or "")]
    elseif ability.totem then
        local byCaster = self.totemStates[shortName(casterName or "")] or {}
        state = byCaster[ability.key]
    else
        local byCaster = self.activeAuras[ability.key] or {}
        state = byCaster[shortName(casterName or "")]
    end
    if not state then return nil end
    local left = (state.expiresAt or clock()) - clock()
    if left <= 0 then return nil end
    state.remaining = left
    return state
end

function CDW:LifeState(member)
    if not member or member.fake or not member.unit then return "alive" end
    if UnitIsConnected and not UnitIsConnected(member.unit) then return "disconnected" end
    if UnitExists and not UnitExists(member.unit) then return "alive" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(member.unit) then return "dead" end
    if UnitIsDead and UnitIsDead(member.unit) then return "dead" end
    if UnitIsGhost and UnitIsGhost(member.unit) then return "dead" end
    return "alive"
end

function CDW:BuildModels()
    local roster = self:GetRoster()
    self.roster = roster
    local orderByName, memberByName = {}, {}
    for i, member in ipairs(roster) do
        orderByName[shortName(member.name)] = i
        memberByName[shortName(member.name)] = member
    end
    local assignedTanks, tankRoles = self:GetTankAssignments(roster)
    local settings = self:NormalizeSettings()
    local needs, modelsByCategory = {}, {}
    for _, category in ipairs(CATEGORIES) do
        local candidates, models = {}, {}
        for _, ability in ipairs(category.abilities) do
            for _, member in ipairs(roster) do
                local selectedTank = category.key ~= "tank_defensive"
                    or assignedTanks[shortName(member.name)] ~= nil
                if selectedTank then
                    local canTrack, unknown
                    if ability.allPlayers then canTrack, unknown = true, false
                    else canTrack, unknown = self:CanTrack(ability, member, needs) end
                    if canTrack then
                        local key = ability.key .. "@" .. shortName(member.name)
                        local targetAssigned = settings.targetAssignments[key]
                        candidates[#candidates + 1] = {
                            key=key, assignmentKey=key, ability=ability,
                            sourceName=member.name, ownerName=member.name, member=member,
                            unknown=unknown, assignedTarget=targetAssigned,
                            assigned=targetAssigned ~= nil,
                            tankRole=assignedTanks[shortName(member.name)] and assignedTanks[shortName(member.name)].role,
                            rosterOrder=orderByName[shortName(member.name)] or 999,
                        }
                    end
                end
            end
        end
        table.sort(candidates, function(a,b)
            if a.assigned ~= b.assigned then return a.assigned end
            if a.rosterOrder ~= b.rosterOrder then return a.rosterOrder < b.rosterOrder end
            if a.ability.order ~= b.ability.order then return a.ability.order < b.ability.order end
            return tostring(a.sourceName or "") < tostring(b.sourceName or "")
        end)
        for _, model in ipairs(candidates) do
            model.cooldown = self:GetAbilityRemaining(model.sourceName, model.member.unit, model.ability)
            model.active = self:GetActive(model.ability, model.sourceName, model.sourceName)
            model.activeLeft = model.active and model.active.remaining or nil
            model.ready = model.cooldown <= 0 and not (model.ability.stateOnly and model.active)
            model.life = self:LifeState(model.member)
            model.categoryOrder = model.ability.order
            model.targetName = model.assignedTarget or (model.active and model.ability.target and model.active.targetName)
            models[#models+1] = model
        end
        modelsByCategory[category.key] = models
    end
    local inspectItems = {}
    for _, item in pairs(needs) do
        local reasons = {}
        for reason in pairs(item.reasons) do reasons[#reasons+1] = reason end
        table.sort(reasons)
        item.reason = table.concat(reasons, ", ")
        item.status = self.inspectStatus[shortName(item.name)] or L["pending"]
        inspectItems[#inspectItems+1] = item
    end
    table.sort(inspectItems, function(a,b) return a.name < b.name end)
    self.modelsByCategory, self.inspectItems, self.memberByName = modelsByCategory, inspectItems, memberByName
    self.tankAssignmentRoles, self.assignedTankMembers = tankRoles, assignedTanks
    self.hasTankAssignments = next(assignedTanks) ~= nil
    self._rosterSignature = self:RosterSignature(roster)
    self._rosterDirty = false
end

function CDW:RosterSignature(roster)
    local bits = {}
    for _, member in ipairs(roster or {}) do bits[#bits+1] = table.concat({tostring(member.name or ""), tostring(member.class or ""), tostring(member.unit or ""), member.fake and "1" or "0"}, "|") end
    return table.concat(bits, "\n")
end

function CDW:SortModels(models)
    table.sort(models, function(a,b)
        if a.ready ~= b.ready then return a.ready end
        if not a.ready and math.abs(a.cooldown-b.cooldown) > 0.01 then return a.cooldown < b.cooldown end
        if a.rosterOrder ~= b.rosterOrder then return a.rosterOrder < b.rosterOrder end
        if a.categoryOrder ~= b.categoryOrder then return a.categoryOrder < b.categoryOrder end
        return a.ability.name < b.ability.name
    end)
    return models
end

function CDW:GroupModels(models, groupMode)
    local groups, lookup = {}, {}
    if groupMode~="caster" and groupMode~="spells" and groupMode~="none" then
        groupMode=self:NormalizeSettings().groupMode
    end
    for _, model in ipairs(models) do
        local key, name
        if groupMode == "spells" then
            key=tostring(model.ability.key or model.ability.name)
            name=model.ability.name
        else
            key=shortName(model.ownerName)
            name=model.ownerName
        end
        local group = lookup[key]
        if not group then
            group = { name=name, order=model.rosterOrder, models={}, ready=false, soonest=nil }
            lookup[key], groups[#groups+1] = group, group
        end
        group.models[#group.models+1] = model
        if model.ready then group.ready = true elseif not group.soonest or model.cooldown < group.soonest then group.soonest = model.cooldown end
    end
    for _, group in ipairs(groups) do self:SortModels(group.models) end
    table.sort(groups, function(a,b)
        if a.ready ~= b.ready then return a.ready end
        if a.soonest and b.soonest and a.soonest ~= b.soonest then return a.soonest < b.soonest end
        return a.order < b.order
    end)
    return groups
end

function CDW:EnsureBar(window, model, width)
    local row = window.barFrames[model.key]
    if row then return row end
    row = CreateFrame("Button", nil, window.content)
    row:SetSize(width, self:GetBarHeight())
    row:EnableMouse(true)
    -- No RegisterForDrag: the client drag manager in 3.3.5 can swallow
    -- mouse input for the whole frame tree. The manual poller below handles it.
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetTexture(WHITE_TEXTURE)
    row.bg:SetAllPoints(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.08,0.92,0.08,0.92)
    row.icons = {row.icon}
    row.statusIcon = row:CreateTexture(nil, "OVERLAY")
    row.statusIcon:SetTexture(WHITE_TEXTURE)
    row.statusIcon:SetSize(STATUS_SQUARE_SIZE, STATUS_SQUARE_SIZE)
    row.statusIcon:SetPoint("RIGHT", row, "RIGHT", -1, 0)
    row.statusIcon:Hide()
    -- Preserve the old field name for integrations that used the alive marker.
    row.alive = row.statusIcon
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture(self:NormalizeSettings().barTexture or STATUSBAR_TEXTURE)
    -- Parent the text to the StatusBar so it is drawn above its changing fill.
    row.label = row.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("CENTER", row.bar, "CENTER", 0, 0)
    row.label:SetJustifyH("CENTER")
    row.label:SetWordWrap(false)
    -- Legacy consumers read the visible cooldown label through icon.timer.
    row.timer = row.label
    row.icon.timer = row.label
    row:SetScript("OnMouseDown",function(frame,button)
        CDW:QueueManualBarDrag(frame,button)
    end)
    row:SetScript("OnMouseUp",function(frame,button)
        CDW:HandleManualBarMouseUp(frame,button)
    end)
    row:SetScript("OnEnter", function(frame)
        if frame.data and frame.data.customCatalogSpell and GameTooltip and not CDW:NormalizeSettings().hideTooltips then
            GameTooltip:SetOwner(frame,"ANCHOR_TOPLEFT")
            GameTooltip:SetText(frame.data.ability.name or "?")
            GameTooltip:AddLine(L["Drag this spell to an active custom panel."],1,1,1)
            GameTooltip:Show()
        elseif frame.data and not frame.data.preview and not CDW:NormalizeSettings().hideTooltips then
            CDW:ShowBarTooltip(frame)
        end
    end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    row:Hide()
    window.barFrames[model.key] = row
    return row
end

function CDW:IconFor(ability)
    if ability.ids and ability.ids[1] and GetSpellInfo then
        local _, _, icon = GetSpellInfo(ability.ids[1])
        if icon and icon ~= QUESTION_ICON then return icon end
    end
    return ability.icon or QUESTION_ICON
end

function CDW:FormatTime(value)
    if not value or value <= 0 then return L["READY"] end
    if RLSuite.utils and RLSuite.utils.FormatCD then return RLSuite.utils:FormatCD(value) end
    return tostring(math.ceil(value)) .. "s"
end

function CDW:RenderBar(window, model, y, width, groupMode)
    local row = self:EnsureBar(window, model, width)
    local settings = self:NormalizeSettings()
    local height = self:GetBarHeight()
    local font = settings.fontFace or "Fonts\\FRIZQT__.TTF"
    local fontSize = math.min(tonumber(settings.fontSize) or 11, math.max(8,height-2))
    local fontFlags = settings.fontOutline and "OUTLINE" or nil
    local fontColor = settings.fontColor or { r=1, g=1, b=1 }
    local iconSize = math.min(ICON_SIZE, math.max(8, height - 2))
    local inCooldown = (tonumber(model.cooldown) or 0) > 0
    local stateIconSize = math.min(STATUS_ICON_SIZE, math.max(8,height-2))
    local barLeft = 4

    row.data, row.modelKey, row.ability = model, model.key, model.ability.key
    row.icons[1].ability = model.ability.key
    row:EnableMouse(not model.preview)
    row.bg:SetVertexColor(0.08,0.08,0.1,0.92)
    row.bar:SetStatusBarTexture(settings.barTexture or STATUSBAR_TEXTURE)
    row.bar:ClearAllPoints()
    row.icon:ClearAllPoints()
    row.icon:SetSize(iconSize,iconSize)
    if settings.showIcons then
        row.icon:SetPoint("LEFT",row,"LEFT",0,0)
        barLeft=iconSize+4
        -- Spell icons always identify the ability; life state belongs to the
        -- separate status marker at the far right of the row.
        row.icon:SetTexture(self:IconFor(model.ability))
        row.icon:SetVertexColor(1,1,1,1)
        row.icon:Show()
    else
        row.icon:Hide()
    end

    local life = model.life or "alive"
    if life == "dead" then
        row.statusIcon:SetTexture(DEAD_ICON)
        row.statusIcon:SetTexCoord(0.08,0.92,0.08,0.92)
        row.statusIcon:SetSize(stateIconSize,stateIconSize)
        row.statusIcon:SetVertexColor(1,1,1,1)
        row.statusIcon:Show()
    elseif life == "disconnected" then
        row.statusIcon:SetTexture(OFFLINE_ICON)
        row.statusIcon:SetTexCoord(0.08,0.92,0.08,0.92)
        row.statusIcon:SetSize(stateIconSize,stateIconSize)
        row.statusIcon:SetVertexColor(1,1,1,1)
        row.statusIcon:Show()
    elseif model.ready and not inCooldown then
        row.statusIcon:SetTexture(WHITE_TEXTURE)
        row.statusIcon:SetTexCoord(0,1,0,1)
        row.statusIcon:SetSize(STATUS_SQUARE_SIZE,STATUS_SQUARE_SIZE)
        row.statusIcon:SetVertexColor(0.10,0.9,0.2,1)
        row.statusIcon:Show()
    else
        -- Cooldown bars have no alive/ready square; only dead/offline use icons.
        row.statusIcon:Hide()
    end

    row.bar:SetPoint("TOPLEFT",row,"TOPLEFT",barLeft,-2)
    -- Reserve the right edge for the alive/dead/offline status marker.
    row.bar:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-16,2)
    row.bar:SetMinMaxValues(0,model.ability.stateOnly and (model.ability.duration or 1)
        or (model.ability.cd>0 and model.ability.cd or (model.ability.duration or 1)))
    local max = model.ability.stateOnly and (model.ability.duration or 1)
        or (model.ability.cd>0 and model.ability.cd or (model.ability.duration or 1))
    local remaining = model.ability.stateOnly and model.activeLeft or (model.cooldown or 0)
    remaining = math.max(0,math.min(max,tonumber(remaining) or 0))
    local fill = max - remaining
    row.bar:SetValue(math.max(0,math.min(max,fill)))

    local r,g,b
    if model.life=="dead" then
        r,g,b=settings.deadColor.r,settings.deadColor.g,settings.deadColor.b
        row.bg:SetVertexColor(0.10,0.10,0.11,1)
    elseif model.life=="disconnected" then
        r,g,b=settings.disconnectedColor.r,settings.disconnectedColor.g,settings.disconnectedColor.b
        row.bg:SetVertexColor(0.10,0.10,0.11,1)
    elseif model.customCatalogSpell then
        r,g,b=self:ClassColor(model.ability.class)
    elseif settings.useClassColor then
        r,g,b=self:ClassColor(model.member and model.member.class)
    elseif model.ready then
        r,g,b=settings.readyColor.r,settings.readyColor.g,settings.readyColor.b
    else
        r,g,b=settings.cooldownColor.r,settings.cooldownColor.g,settings.cooldownColor.b
    end
    row.bar:SetStatusBarColor(r,g,b,1)
    row.bar:SetAlpha(inCooldown and 0.6 or 1)

    local spellName=model.ability.name or "?"
    local casterName=model.ownerName or "?"
    local labelText
    if model.customSpell then
        labelText=spellName
    else
        if groupMode~="caster" and groupMode~="spells" and groupMode~="none" then
            groupMode=settings.groupMode
        end
        if groupMode == "caster" then
            labelText=spellName
        elseif groupMode == "spells" then
            labelText=casterName
        else
            labelText=spellName..":"..casterName
        end
    end
    if inCooldown then labelText=labelText.."  "..self:FormatTime(model.cooldown) end
    row.label:SetWidth(math.max(20,width-barLeft-22))
    row.label:SetFont(font,fontSize,fontFlags)
    row.label:SetTextColor(fontColor.r or 1,fontColor.g or 1,fontColor.b or 1,1)
    row.label:SetText(labelText)
    row.label:Show()
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT",window.content,"TOPLEFT",0,-y)
    row:SetSize(width,height)
    row:Show()
    return row
end

function CDW:EnsureCategoryHeader(window,key,width)
    local header = window.headerFrames[key]
    if header then return header end
    header = CreateFrame("Frame",nil,window.content)
    header:SetSize(width,HEADER_H)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header.bg = header:CreateTexture(nil,"BACKGROUND")
    header.bg:SetTexture(WHITE_TEXTURE)
    header.bg:SetAllPoints(header)
    header.bg:SetVertexColor(0.18,0.18,0.2,0.95)
    header.title = header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    header.title:SetPoint("LEFT",header,"LEFT",28,0)
    header.visible = CreateFrame("Button",nil,header,"UIPanelButtonTemplate")
    header.visible:SetSize(22,18)
    header.visible:SetPoint("LEFT",header,"LEFT",2,0)
    header.visible:SetScript("OnClick",function() CDW:SetCategoryEnabled(key,not CDW:IsCategoryEnabled(key)) end)
    header.collapse = CreateFrame("Button",nil,header,"UIPanelButtonTemplate")
    header.collapse:SetSize(22,18)
    header.collapse:SetPoint("RIGHT",header,"RIGHT",-2,0)
    header.collapse:SetScript("OnClick",function()
        local s=CDW:NormalizeSettings(); s.collapsed[key]=not s.collapsed[key]; CDW:RefreshAll()
    end)
    header:SetScript("OnDragStart",function() CDW.dragCategory=key end)
    header:SetScript("OnDragStop",function() CDW:OnCategoryDragStop(key) end)
    header:SetScript("OnEnter",function(frame)
        if GameTooltip and not CDW:NormalizeSettings().hideTooltips then
            GameTooltip:SetOwner(frame,"ANCHOR_TOPLEFT")
            GameTooltip:SetText(L["Drag this category header to change its order."])
            GameTooltip:Show()
        end
    end)
    header:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    header:Hide()
    window.headerFrames[key]=header
    return header
end

function CDW:EnsureSubheader(window,name)
    local key=shortName(name)
    local h=window.subheaderFrames[key]
    if not h then
        h=CreateFrame("Frame",nil,window.content)
        h.text=h:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        h.text:SetPoint("LEFT",h,"LEFT",8,0)
        h:Hide(); window.subheaderFrames[key]=h
    end
    h.text:SetText(name)
    return h
end

function CDW:EnsurePrompt(window,key,width)
    local prompt=window.promptFrames[key]
    if not prompt then
        prompt=CreateFrame("Frame",nil,window.content)
        prompt:EnableMouse(false)
        prompt.bg=prompt:CreateTexture(nil,"BACKGROUND")
        prompt.bg:SetTexture(WHITE_TEXTURE)
        prompt.bg:SetAllPoints(prompt)
        prompt.bg:SetVertexColor(0.16,0.12,0.04,0.9)
        prompt.text=prompt:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        prompt.text:SetPoint("LEFT",prompt,"LEFT",6,0)
        prompt.text:SetJustifyH("LEFT")
        prompt.text:SetWordWrap(true)
        prompt.text:SetTextColor(1,0.82,0.25,1)
        window.promptFrames[key]=prompt
    end
    prompt:SetWidth(width)
    prompt.text:SetWidth(math.max(50,width-12))
    prompt.text:SetText(L["assign MT, OT or drag&drop Tanks here from Raid Frame"])
    local textHeight=prompt.text.GetStringHeight and prompt.text:GetStringHeight() or TANK_PROMPT_H-6
    prompt:SetHeight(math.max(TANK_PROMPT_H,textHeight+6))
    return prompt
end

function CDW:CategoryAtCursor()
    if not GetCursorPosition then return nil end
    local cursorX,cursorY=GetCursorPosition()
    if not cursorX or not cursorY then return nil end
    local windows={}
    for _,window in pairs(self.categoryWindows or {}) do windows[#windows+1]=window end
    for _,window in pairs(self.groupWindows or {}) do windows[#windows+1]=window end
    for _,window in ipairs(windows) do
        if window:IsShown() then
            local scale=window:GetEffectiveScale() or 1
            if scale<=0 then scale=1 end
            local x,y=cursorX/scale,cursorY/scale
            for key,header in pairs(window.headerFrames or {}) do
                if header:IsShown() and type(header:GetLeft())=="number"
                    and x>=header:GetLeft() and x<=header:GetRight()
                    and y>=header:GetBottom() and y<=header:GetTop() then
                    return key,y>=(header:GetBottom()+header:GetTop())/2
                end
            end
        end
    end
end

function CDW:MoveCategory(source,target,before)
    if not CATEGORY_BY_KEY[source] or not CATEGORY_BY_KEY[target] then return false end
    local order=self:GetCategoryOrder(); local a,b
    for i,key in ipairs(order) do if key==source then a=i end if key==target then b=i end end
    if not a or not b or a==b then return false end
    table.remove(order,a); if a<b then b=b-1 end; if not before then b=b+1 end
    table.insert(order,math.max(1,math.min(#order+1,b)),source)
    self:NormalizeSettings().categoryOrder=order; self:RefreshAll(); return true
end

function CDW:OnCategoryDragStop(source)
    local target,before=self:CategoryAtCursor(); local from=self.dragCategory or source; self.dragCategory=nil
    if target and target~=from then self:MoveCategory(from,target,before) end
end

function CDW:RenderRows(window,key,models,y,width,usedBars,usedSubs,groupMode)
    local s=self:NormalizeSettings()
    if s.collapsed[key] then return y end
    if groupMode~="caster" and groupMode~="spells" and groupMode~="none" then
        groupMode=s.groupMode
    end
    local sorted={}; for _,m in ipairs(models or {}) do sorted[#sorted+1]=m end
    self:SortModels(sorted)
    local function renderOne(model)
        if key=="interrupts" and model.ready and not self._nextInterruptMarked then model.nextInterrupt=true; self._nextInterruptMarked=true else model.nextInterrupt=false end
        local row=self:RenderBar(window,model,y,width,groupMode); usedBars[row]=true; y=y+self:GetBarHeight()
    end
    self._nextInterruptMarked=false
    local function renderGroups(list)
        for _,group in ipairs(self:GroupModels(list,groupMode)) do
            local h=self:EnsureSubheader(window,group.name); h:ClearAllPoints(); h:SetPoint("TOPLEFT",window.content,"TOPLEFT",0,-y)
            h:SetSize(width-10,SUBHEADER_H); h:Show(); usedSubs[h]=true; y=y+SUBHEADER_H
            for _,model in ipairs(group.models) do renderOne(model) end
        end
    end
    if groupMode == "caster" then
        local ready, cooling = {}, {}
        for _, model in ipairs(sorted) do
            if model.ready then ready[#ready+1]=model else cooling[#cooling+1]=model end
        end
        renderGroups(ready)
        renderGroups(cooling)
    elseif groupMode == "spells" then
        renderGroups(sorted)
    else
        for _,model in ipairs(sorted) do renderOne(model) end
    end
    return y
end

function CDW:FinalizeWindow(window,height,width,usedBars,usedHeads,usedSubs,usedPrompts)
    for _,row in pairs(window.barFrames) do if not usedBars[row] then row:Hide() end end
    for _,row in pairs(window.headerFrames) do if not usedHeads[row] then row:Hide() end end
    for _,row in pairs(window.subheaderFrames) do if not usedSubs[row] then row:Hide() end end
    for _,row in pairs(window.promptFrames or {}) do if not usedPrompts or not usedPrompts[row] then row:Hide() end end
    window.content:SetSize(width-40,math.max(1,height))
    window:SetSize(width,TITLE_H+math.max(self:GetBarHeight(),height)+PAD*2)
end

function CDW:RenderSeparate()
    local width=self:GetBarWidth()+40; local contentWidth=width-40
    self.rows={}
    for _,key in ipairs(self:GetCategoryOrder()) do
        if self:IsCategoryEnabled(key) then
            local w=self:EnsureCategoryWindow(key); local usedBars,usedHeads,usedSubs,usedPrompts={}, {}, {}, {}; local y=2
            if key=="tank_defensive" and not self.hasTankAssignments then
                local prompt=self:EnsurePrompt(w,key,contentWidth)
                prompt:ClearAllPoints(); prompt:SetPoint("TOPLEFT",w.content,"TOPLEFT",0,-y)
                prompt:Show(); usedPrompts[prompt]=true; y=y+prompt:GetHeight()
            else
                y=self:RenderRows(w,key,self.modelsByCategory[key],y,contentWidth,usedBars,usedSubs)
            end
            self:FinalizeWindow(w,y,width,usedBars,usedHeads,usedSubs,usedPrompts)
            if #self.rows==0 then for _,row in pairs(w.barFrames) do if row:IsShown() then self.rows[#self.rows+1]=row end end end
        elseif self.categoryWindows[key] then self.categoryWindows[key]:Hide() end
    end
end

function CDW:RenderMacroGroup(group)
    local width=self:GetBarWidth()+40; local contentWidth=width-40
    local window=self:EnsureMacroGroupWindow(group.key)
    local usedBars,usedHeads,usedSubs,usedPrompts={}, {}, {}, {}
    local categoryOrder=self:GetMacroGroupCategoryOrder(group)
    local y=2
    for _,key in ipairs(categoryOrder) do
        local category=CATEGORY_BY_KEY[key]
        local header=self:EnsureCategoryHeader(window,key,contentWidth)
        header:ClearAllPoints(); header:SetPoint("TOPLEFT",window.content,"TOPLEFT",0,-y)
        header:SetSize(contentWidth,HEADER_H)
        header.title:SetText(L[category.title] or category.title)
        header.visible:SetText(self:IsCategoryEnabled(key) and "ON" or "--")
        header.collapse:SetText(self:NormalizeSettings().collapsed[key] and "+" or "−")
        header:Show(); usedHeads[header]=true; y=y+HEADER_H
        if self:IsCategoryEnabled(key) then
            if key=="tank_defensive" and not self.hasTankAssignments then
                local prompt=self:EnsurePrompt(window,key,contentWidth)
                prompt:ClearAllPoints(); prompt:SetPoint("TOPLEFT",window.content,"TOPLEFT",0,-y)
                prompt:Show(); usedPrompts[prompt]=true; y=y+prompt:GetHeight()+4
            else
                y=self:RenderRows(window,key,self.modelsByCategory[key],y,contentWidth,usedBars,usedSubs)+4
            end
        else
            y=y+2
        end
    end
    self:FinalizeWindow(window,y,width,usedBars,usedHeads,usedSubs,usedPrompts)
    for _,key in ipairs(categoryOrder) do
        for _,row in pairs(window.barFrames) do
            if row:IsShown() and row.data and row.data.ability.category==key then self.rows[#self.rows+1]=row end
        end
    end
end

function CDW:RenderMacroGroups()
    self.rows={}
    local selected={}
    for _,group in ipairs(self:GetMacroGroupsForLayout()) do
        if self:MacroGroupHasEnabledCategories(group) then
            selected[group.key]=true
            self:RenderMacroGroup(group)
        elseif self.groupWindows and self.groupWindows[group.key] then
            self.groupWindows[group.key]:Hide()
        end
    end
    for key,window in pairs(self.groupWindows or {}) do
        if not selected[key] then window:Hide() end
    end
end

function CDW:RenderCustomPanel(index)
    local panel=self:NormalizeSettings().customPanels[index]
    local window=self:EnsureCustomPanelWindow(index)
    local width=self:GetBarWidth()+40
    local usedBars,usedHeads,usedSubs,usedPrompts={}, {}, {}, {}
    local y,count=2,0
    local models={}
    window.titleText:SetText(panel.name)
    for _,abilityKey in ipairs(panel.spells) do
        local ability=ABILITY_BY_KEY[abilityKey]
        if ability and self:IsCategoryEnabled(ability.category) then
            for _,source in ipairs(self.modelsByCategory[ability.category] or {}) do
                if source.ability and source.ability.key==abilityKey then
                    local model={}
                    for key,value in pairs(source) do model[key]=value end
                    model.customPanelIndex=index
                    models[#models+1]=model
                end
            end
        end
    end
    count=#models
    if count>0 then
        y=self:RenderRows(window,"custom_panel_"..index,models,y,width-40,usedBars,usedSubs,panel.groupMode)
        for row in pairs(usedBars) do self.rows[#self.rows+1]=row end
    end
    if count==0 then
        window.emptyText:SetText(#panel.spells==0 and L["No spells assigned to this panel. Use Modify panels to add spells."]
            or L["No cooldowns to display for this panel."])
        window.emptyText:Show()
        y=math.max(y,window.emptyText:GetStringHeight()+16)
    else
        window.emptyText:Hide()
    end
    self:FinalizeWindow(window,y,width,usedBars,usedHeads,usedSubs,usedPrompts)
end

function CDW:RenderCustomSpellPicker()
    local window=self:EnsureCustomSpellPickerWindow()
    local width=window:GetWidth()
    -- Pin the editor hierarchy to small, predictable levels above its backdrop.
    -- Every catalog spell button uses the SAME level (and every status bar the
    -- same child level); never assign per-spell or increasing frame levels.
    local pickerLevel=window.GetFrameLevel and window:GetFrameLevel() or 1
    if window.scroll and window.scroll.SetFrameLevel then
        window.scroll:SetFrameLevel(pickerLevel+2)
    end
    if window.content.SetFrameLevel then window.content:SetFrameLevel(pickerLevel+3) end
    local catalogHeaderFrameLevel=pickerLevel+4
    local catalogSpellFrameLevel=pickerLevel+5
    local columnWidth,barHeight=CUSTOM_PICKER_BAR_WIDTH,self:GetBarHeight()
    local columnGap=CUSTOM_PICKER_COLUMN_GAP
    local gridWidth=CUSTOM_PICKER_COLUMNS*columnWidth+(CUSTOM_PICKER_COLUMNS-1)*columnGap
    local contentWidth=math.max(width-64,gridWidth)
    local categoryByKey,categoryBlocks,columnEnds,placed={}, {}, {}, {}
    for _,category in ipairs(CATEGORIES) do categoryByKey[category.key]=category end

    local function appendCategory(category,column)
        local groups,classOrder={},{}
        for _,ability in ipairs(category.abilities or {}) do
            local class=ability.class or "OTHER"
            if not groups[class] then groups[class]={}; classOrder[#classOrder+1]=class end
            groups[class][#groups[class]+1]=ability
        end
        local blockHeight=HEADER_H+2
        for _,class in ipairs(classOrder) do
            blockHeight=blockHeight+SUBHEADER_H+#groups[class]*barHeight+2
        end
        categoryBlocks[#categoryBlocks+1]={
            category=category,groups=groups,classOrder=classOrder,
            column=column,blockHeight=blockHeight,
        }
        placed[category.key]=true
    end

    for column,categoryKeys in ipairs(CUSTOM_PICKER_CATEGORY_ORDER) do
        for _,key in ipairs(categoryKeys) do
            local category=categoryByKey[key]
            if category then appendCategory(category,column-1) end
        end
    end

    -- Keep future categories in the catalog even if they have not yet been
    -- added to the explicit four-column order above.
    local fallbackCounts={}
    for _,block in ipairs(categoryBlocks) do
        fallbackCounts[block.column]=(fallbackCounts[block.column] or 0)+1
    end
    for _,category in ipairs(CATEGORIES) do
        if not placed[category.key] then
            local column,smallestCount=0,math.huge
            for candidate=0,CUSTOM_PICKER_COLUMNS-1 do
                local count=fallbackCounts[candidate] or 0
                if count<smallestCount then column,smallestCount=candidate,count end
            end
            appendCategory(category,column)
            fallbackCounts[column]=(fallbackCounts[column] or 0)+1
        end
    end

    local contentHeight=2
    for _,block in ipairs(categoryBlocks) do
        block.y=columnEnds[block.column] or 2
        columnEnds[block.column]=block.y+block.blockHeight+CUSTOM_PICKER_CATEGORY_GAP
        contentHeight=math.max(contentHeight,block.y+block.blockHeight+2)
    end

    local usedBars,usedCategories,usedClasses={},{},{}
    window.titleText:SetText(L["Custom panel editor"])
    for _,block in ipairs(categoryBlocks) do
        local category=block.category
        local x=block.column*(columnWidth+columnGap)
        local y=block.y
        local header=window.customCategoryHeaders[category.key]
        if not header then
            header=CreateFrame("Frame",nil,window.content)
            header.bg=header:CreateTexture(nil,"BACKGROUND")
            header.bg:SetTexture(WHITE_TEXTURE)
            header.bg:SetAllPoints(header)
            header.bg:SetVertexColor(0.18,0.18,0.2,0.95)
            header.title=header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            header.title:SetPoint("LEFT",header,"LEFT",6,0)
            window.customCategoryHeaders[category.key]=header
        end
        if header.SetFrameLevel then header:SetFrameLevel(catalogHeaderFrameLevel) end
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT",window.content,"TOPLEFT",x,-y)
        header:SetSize(columnWidth,HEADER_H)
        header.title:SetWidth(columnWidth-12)
        header.title:SetText(L[category.title] or category.title)
        header:Show()
        usedCategories[header]=true
        y=y+HEADER_H+2

        for _,class in ipairs(block.classOrder) do
            local classHeaderKey=category.key..":"..class
            local classHeader=window.customClassHeaders[classHeaderKey]
            if not classHeader then
                classHeader=CreateFrame("Frame",nil,window.content)
                classHeader.bg=classHeader:CreateTexture(nil,"BACKGROUND")
                classHeader.bg:SetTexture(WHITE_TEXTURE)
                classHeader.bg:SetAllPoints(classHeader)
                classHeader.title=classHeader:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                classHeader.title:SetPoint("LEFT",classHeader,"LEFT",6,0)
                window.customClassHeaders[classHeaderKey]=classHeader
            end
            if classHeader.SetFrameLevel then classHeader:SetFrameLevel(catalogHeaderFrameLevel) end
            local r,g,b=self:ClassColor(class~="OTHER" and class or nil)
            classHeader:ClearAllPoints()
            classHeader:SetPoint("TOPLEFT",window.content,"TOPLEFT",x,-y)
            classHeader:SetSize(columnWidth,SUBHEADER_H)
            classHeader.title:SetWidth(columnWidth-12)
            classHeader.bg:SetVertexColor(r*0.22,g*0.22,b*0.22,0.95)
            classHeader.title:SetText(localizedClassName(class~="OTHER" and class or nil))
            classHeader.title:SetTextColor(r,g,b,1)
            classHeader:Show()
            usedClasses[classHeader]=true
            y=y+SUBHEADER_H

            for _,ability in ipairs(block.groups[class]) do
                local model={
                    key="custom_catalog_"..ability.key,
                    ability=ability,
                    member={class=ability.class},
                    ownerName="",
                    life="alive",
                    ready=true,
                    cooldown=0,
                    customSpell=true,
                    customCatalogSpell=true,
                }
                local row=self:RenderBar(window,model,y,columnWidth)
                if row.SetFrameLevel then row:SetFrameLevel(catalogSpellFrameLevel) end
                if row.bar and row.bar.SetFrameLevel then row.bar:SetFrameLevel(catalogSpellFrameLevel+1) end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT",window.content,"TOPLEFT",x,-y)
                row:SetSize(columnWidth,barHeight)
                usedBars[row]=true
                y=y+barHeight
            end
            y=y+2
        end
    end

    for _,row in pairs(window.barFrames) do if not usedBars[row] then row:Hide() end end
    for _,header in pairs(window.customCategoryHeaders) do if not usedCategories[header] then header:Hide() end end
    for _,header in pairs(window.customClassHeaders) do if not usedClasses[header] then header:Hide() end end
    window.content:SetSize(contentWidth,math.max(1,contentHeight))
    if window.scroll and window.scroll.SetVerticalScroll then window.scroll:SetVerticalScroll(0) end
    if window.scroll and window.scroll.SetHorizontalScroll then window.scroll:SetHorizontalScroll(0) end
end

function CDW:RenderCustomPanels()
    local panels=self:NormalizeSettings().customPanels
    self.rows={}
    for index=1,6 do
        local panel=panels[index]
        if panel.enabled then
            self:RenderCustomPanel(index)
        elseif self.customWindows and self.customWindows[index] then
            self.customWindows[index]:Hide()
        end
    end
    self:PositionDefaultCustomPanels()
    if self.customPanelEditMode then
        local picker=self:EnsureCustomSpellPickerWindow()
        if self._customSpellPickerDirty or not picker._catalogRendered then
            self:RenderCustomSpellPicker()
            picker._catalogRendered=true
            self._customSpellPickerDirty=false
        end
    elseif self.customSpellPickerFrame then
        self.customSpellPickerFrame:Hide()
    end
end

function CDW:EnsurePreviewWindow()
    if self.previewWindow then return self.previewWindow end
    self.previewWindow=self:CreateWindow("RLSuiteCDWPreview",L["CD Watcher preview"],"cdwatcher_preview",self:GetBarWidth()+40)
    return self.previewWindow
end

function CDW:GetPreviewModels(mode)
    local definitions={
        { key="preview_ready", ability="shield_wall", ownerName="Aldor", class="WARRIOR", life="alive", ready=true, cooldown=0 },
        { key="preview_cooldown", ability="icebound_fortitude", ownerName="Mira", class="DEATHKNIGHT", life="alive", ready=false, cooldown=73 },
        { key="preview_dead", ability="barkskin", ownerName="Thalan", class="DRUID", life="dead", ready=false, cooldown=118 },
        { key="preview_disconnected", ability="divine_protection", ownerName="Elaria", class="PALADIN", life="disconnected", ready=false, cooldown=42 },
    }
    if mode~="fake" then definitions={definitions[2]} end
    local models={}
    for _,definition in ipairs(definitions) do
        local source=ABILITY_BY_KEY[definition.ability]
        local ability={}
        for key,value in pairs(source or {}) do ability[key]=value end
        local model={
            key=definition.key, ability=ability, ownerName=definition.ownerName,
            member={name=definition.ownerName,class=definition.class}, class=definition.class,
            life=definition.life, ready=definition.ready, cooldown=definition.cooldown,
            preview=true,
        }
        if definition.key=="preview_cooldown" then model.targetName="Sinder" end
        models[#models+1]=model
    end
    return models
end

function CDW:RenderPreview(mode)
    local window=self:EnsurePreviewWindow()
    local width=self:GetBarWidth()+40; local contentWidth=width-40
    local usedBars,usedHeads,usedSubs={}, {}, {}; local y=2
    window.titleText:SetText(L["CD Watcher preview"])
    for _,model in ipairs(self:GetPreviewModels(mode)) do
        local row=self:RenderBar(window,model,y,contentWidth)
        usedBars[row]=true; y=y+self:GetBarHeight()
    end
    self:FinalizeWindow(window,y,width,usedBars,usedHeads,usedSubs)
end

function CDW:ShowPreview(mode)
    self.previewMode=mode=="fake" and "fake" or "single"
    self:EnsurePreviewWindow():Show()
    self:RenderPreview(self.previewMode)
end

function CDW:RenderInspector()
    if not self.inspectItems or #self.inspectItems==0 then
        if self.inspectFrame then self.inspectFrame:Hide() end
        self._inspectDismissed=false; return
    end
    local w=self:EnsureInspectWindow(); local used={}; local y=4
    for _,item in ipairs(self.inspectItems) do
        local key="inspect:"..shortName(item.name); local row=w.inspectRows[key]
        if not row then
            row=CreateFrame("Frame",nil,w.content); row.nameText=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            row.nameText:SetPoint("LEFT",row,"LEFT",4,0); row.reason=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            row.reason:SetPoint("LEFT",row.nameText,"RIGHT",6,0); row.button=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
            row.button:SetSize(70,20); row.button:SetPoint("RIGHT",row,"RIGHT",-2,0); w.inspectRows[key]=row
        end
        row:SetSize(INSPECT_W-40,ROW_H); row:ClearAllPoints(); row:SetPoint("TOPLEFT",w.content,"TOPLEFT",0,-y)
        row.nameText:SetWidth(110); row.nameText:SetText(item.name.." ("..tostring(item.class or "?")..")")
        row.reason:SetWidth(150); row.reason:SetText((item.reason or L["Unknown specialization"]).." · "..tostring(item.status or "pending"))
        row.button:SetText(item.status==L["in progress"] and L["Inspecting"] or L["Inspect"])
        local inspectName=item.name
        row.button:SetScript("OnClick",function() CDW:RequestInspect(inspectName,true) end)
        row:Show(); used[row]=true; y=y+ROW_H
    end
    for key,row in pairs(w.inspectRows) do if not used[row] then row:Hide() end end
    w.content:SetSize(INSPECT_W-40,math.max(1,y)); w:SetSize(INSPECT_W,TITLE_H+y+PAD*2)
    if not self._inspectDismissed and self.isOpen then w:Show() end
end

function CDW:QueueInspectNeeds()
    local queued={}; for _,item in ipairs(self.inspectQueue) do queued[shortName(item.name)]=true end
    if self.inspectInFlight then queued[shortName(self.inspectInFlight.name)]=true end
    for _,item in ipairs(self.inspectItems or {}) do
        local key=shortName(item.name)
        if not self.inspectCache[key] and not queued[key] then self.inspectQueue[#self.inspectQueue+1]={name=item.name,unit=item.unit}; queued[key]=true end
    end
end

function CDW:RefreshAll()
    if not self.initialized then return end
    self:BuildModels(); self:QueueInspectNeeds()
    local layoutMode=self:NormalizeSettings().layoutMode
    if layoutMode=="separate" then self:RenderSeparate()
    elseif layoutMode=="custom" then self:RenderCustomPanels()
    else self:RenderMacroGroups() end
    self:RenderInspector()
    if self.previewWindow and self.previewWindow:IsShown() then self:RenderPreview(self.previewMode) end
end

function CDW:RefreshRoster(roster)
    if roster then self.roster=roster end
    self._rosterDirty=true; self:RefreshAll()
end

function CDW:OnRosterChanged()
    self._rosterDirty=true; self._inspectDismissed=false; self:RefreshAll()
end

function CDW:Update()
    if not self.initialized then return end
    local roster=self:GetRoster(); local signature=self:RosterSignature(roster)
    if self._rosterDirty or signature~=self._rosterSignature or self:IsOpen() then self:RefreshAll() end
    self:TryInspectQueue(false)
end

function CDW:TryInspectQueue(force)
    if self.inspectInFlight then
        if clock()-(self.inspectInFlight.time or 0)>8 then
            local failed=self.inspectInFlight
            if ClearInspectPlayer then ClearInspectPlayer() end
            self.inspectStatus[shortName(failed.name)]=L["inspect timed out"]
            self.inspectInFlight=nil
            self.inspectQueue[#self.inspectQueue+1]={name=failed.name,unit=failed.unit}
            self._nextInspectAt=clock()+2
        else return end
    end
    if not force and (not self:NormalizeSettings().autoInspect or clock()<(self._nextInspectAt or 0)) then return end
    local attempts=#self.inspectQueue
    while attempts>0 and #self.inspectQueue>0 do
        local item=table.remove(self.inspectQueue,1); attempts=attempts-1
        if not self.inspectCache[shortName(item.name)] then
            if self:RequestInspect(item.name,true) then return end
            self.inspectQueue[#self.inspectQueue+1]=item
        end
    end
    if #self.inspectQueue>0 then self._nextInspectAt=clock()+5 end
end

function CDW:RequestInspect(name,force)
    local member=self:FindMember(name)
    if not member or member.fake or not member.unit then self.inspectStatus[shortName(name)]=L["not inspectable"]; self:RenderInspector(); return false end
    if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        self.inspectStatus[shortName(name)]=L["wait until combat ends"]; self:RenderInspector(); return false
    end
    if CanInspect and not CanInspect(member.unit) then self.inspectStatus[shortName(name)]=L["not in inspect range"]; self:RenderInspector(); return false end
    if not NotifyInspect then self.inspectStatus[shortName(name)]=L["inspect unavailable"]; self:RenderInspector(); return false end
    self.inspectInFlight={name=member.name,unit=member.unit,time=clock()}
    self.inspectStatus[shortName(name)]=L["in progress"]; self._nextInspectAt=clock()+2
    NotifyInspect(member.unit)
    return true
end

function CDW:OnInspectReady(event,guid)
    local pending=self.inspectInFlight; if not pending then return end
    local unitGuid=UnitGUID and UnitGUID(pending.unit); if guid and unitGuid and guid~=unitGuid then return end
    local member=self:FindMember(pending.name)
    local spec=self:ReadSpec(true,member and member.class)
    local shield
    if member then shield=self:HasShield(member,true) end
    local key=shortName(pending.name)
    self.inspectCache[key]={spec=spec,hasShield=shield,inspectedAt=clock()}
    self.inspectStatus[key]=spec and string.format(L["Spec: %s"],spec) or L["inspect complete; spec unavailable"]
    self.inspectInFlight=nil; if ClearInspectPlayer then ClearInspectPlayer() end
    self._nextInspectAt=clock()+1.5; self._rosterDirty=true; self:RefreshAll()
end

function CDW:OnInspectPermissionChanged() self._nextInspectAt=0; self:TryInspectQueue(true) end

function CDW:CursorInsideFrame(frame)
    if not frame or not GetCursorPosition then return false end
    local x, y = GetCursorPosition()
    if not x or not y then return false end
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    if not scale or scale <= 0 then scale = 1 end
    x, y = x / scale, y / scale
    local left, right = frame:GetLeft(), frame:GetRight()
    local bottom, top = frame:GetBottom(), frame:GetTop()
    return type(left)=="number" and type(right)=="number" and type(bottom)=="number" and type(top)=="number"
        and x>=left and x<=right and y>=bottom and y<=top
end

function CDW:OnBarDragStop(frame)
    local model=frame and frame.data; if not model then return end
    local target=RLSuite.raidFrame and RLSuite.raidFrame.MemberRowAtCursor and RLSuite.raidFrame:MemberRowAtCursor(14)
    if not target or not target.name then
        RLSuite.utils:Print(L["Drop the cooldown bar on a player row in the Raid Frame."])
        return
    end
    self:AssignTarget(model,target.name)
end

function CDW:AssignTarget(model,name)
    if not model or not name then return false end
    local targets=self:NormalizeSettings().targetAssignments
    local key=model.assignmentKey or model.key
    if sameName(model.assignedTarget,name) then targets[key]=nil else targets[key]=name end
    self:RefreshAll()
    return true
end

function CDW:TryRaidFrameTankDrop(name,role)
    if not name or not self:IsCategoryEnabled("tank_defensive") then return false end
    local settings=self:NormalizeSettings()
    local windows={}
    if settings.layoutMode=="separate" then
        local tankWindow=self.categoryWindows and self.categoryWindows.tank_defensive
        if tankWindow and tankWindow:IsShown() then windows[#windows+1]=tankWindow end
    elseif self:IsMacroLayout(settings.layoutMode) and self:IsMacroGroupSelected("tank_threat",settings.layoutMode) then
        local tankWindow=self.groupWindows and self.groupWindows.tank_threat
        if tankWindow and tankWindow:IsShown() then windows[#windows+1]=tankWindow end
    end
    if #windows==0 then return false end

    local hit=false
    for _,window in ipairs(windows) do
        local prompt=window.promptFrames and window.promptFrames.tank_defensive
        local header=window.headerFrames and window.headerFrames.tank_defensive
        if prompt and prompt:IsShown() and self:CursorInsideFrame(prompt) then hit=true end
        if header and header:IsShown() and self:CursorInsideFrame(header) then hit=true end
        for _,bar in pairs(window.barFrames or {}) do
            if bar:IsShown() and bar.data and bar.data.ability.category=="tank_defensive"
                and self:CursorInsideFrame(bar) then hit=true end
        end
    end
    if not hit then return false end

    local assigned,roles=self:GetTankAssignments(self.roster or self:GetRoster())
    if role~="mt" and role~="ot" then role=nil end
    if not role then
        if sameName(roles.mt,name) then role="mt"
        elseif sameName(roles.ot,name) then role="ot"
        elseif not roles.mt then role="mt"
        elseif not roles.ot then role="ot"
        else
            RLSuite.utils:Print(L["Both MT and OT are already assigned."])
            return true
        end
    end
    if (roles.mt and sameName(roles.mt,name) and role~="mt") or (roles.ot and sameName(roles.ot,name) and role~="ot") then
        RLSuite.utils:Print(L["This player is already assigned to a tank role."])
        return true
    end
    settings.tankAssignments[role]=name
    self._rosterDirty=true
    self:RefreshAll()
    return true
end

function CDW:ShowBarTooltip(frame)
    local model=frame and frame.data
    if not model or not GameTooltip or self:NormalizeSettings().hideTooltips then return end
    GameTooltip:SetOwner(frame,"ANCHOR_RIGHT")
    GameTooltip:SetText(model.ability.name or L["Cooldown"])
    GameTooltip:AddLine(string.format(L["Caster: %s"],model.sourceName or model.ownerName or "?"),1,1,1)
    if model.nextInterrupt then GameTooltip:AddLine(L["Next interrupt"],1,0.35,0.25) end
    if model.targetName then GameTooltip:AddLine(string.format(L["Target: %s"],model.targetName),1,1,1) end
    if model.assignedTarget then GameTooltip:AddLine(L["Manually assigned target"],0.8,0.8,0.8) end
    local cooldownText=model.cooldown and model.cooldown>0 and self:FormatTime(model.cooldown) or "0s"
    GameTooltip:AddLine(string.format(L["Cooldown: %s"],cooldownText),1,0.82,0.25)
    if not model.cooldown or model.cooldown<=0 then GameTooltip:AddLine(L["READY"],0.25,1,0.25) end
    if model.life=="dead" then GameTooltip:AddLine(L["DEAD"],1,0.3,0.3)
    elseif model.life=="disconnected" then GameTooltip:AddLine(L["DISCONNECTED"],1,0.7,0.2)
    else GameTooltip:AddLine(L["ALIVE"],0.25,1,0.25) end
    if model.unknown then GameTooltip:AddLine(L["Inspect needed"],1,0.82,0.25) end
    if model.active then
        GameTooltip:AddLine(model.active.status or L["ACTIVE"],0.4,0.9,1)
        if model.activeLeft and model.activeLeft>0 then
            GameTooltip:AddLine(string.format(L["Expires in %s"],self:FormatTime(model.activeLeft)),0.8,0.8,0.8)
        end
    end
    if model.tankRole then
        GameTooltip:AddLine(model.tankRole=="mt" and L["Main Tank"] or L["Off Tank"],1,0.82,0.25)
    end
    GameTooltip:AddLine(L["Drag this cooldown bar onto a player row in the Raid Frame to assign its target."],0.8,0.8,0.8)
    if model.assignedTarget then GameTooltip:AddLine(L["Drop it on its assigned target to clear the target override."],0.8,0.8,0.8) end
    GameTooltip:Show()
end

function CDW:OnCombatLog(event,...)
    local _,subEvent,_,sourceName,_,_,destName,_,spellId=...
    spellId=tonumber(spellId)
    if subEvent=="UNIT_DIED" or subEvent=="UNIT_DESTROYED" then self:OnUnitDied(destName); return end
    if subEvent=="SPELL_CAST_SUCCESS" or subEvent=="SPELL_SUMMON" then self:OnSpellCast(sourceName,spellId,destName) end
    if subEvent=="SPELL_AURA_APPLIED" or subEvent=="SPELL_AURA_REFRESH" then self:OnAuraApplied(sourceName,destName,spellId)
    elseif subEvent=="SPELL_AURA_REMOVED" then self:OnAuraRemoved(sourceName,destName,spellId) end
end

function CDW:OnSpellCast(sourceName,spellId,destName)
    spellId=tonumber(spellId)
    if not sourceName or not spellId then return end
    local ability=SPELL_TO_ABILITY[spellId]
    if not ability then return end
    if ability.cd>0 then self.cdTracker[shortName(sourceName)]=self.cdTracker[shortName(sourceName)] or {}; self.cdTracker[shortName(sourceName)][ability.key]=clock()+ability.cd end
    if ability.totem then self.totemStates[shortName(sourceName)]=self.totemStates[shortName(sourceName)] or {}; self.totemStates[shortName(sourceName)][ability.key]={expiresAt=clock()+(ability.duration or 120),status=L["TOTEM ACTIVE"]} end
    if ability.state=="soulstone" then self.soulstoneStates[shortName(sourceName)]={expiresAt=clock()+(ability.duration or 900),targetName=destName,status=L["PLACED"]} end
    if self:IsOpen() then self:RefreshAll() end
end

function CDW:OnAuraApplied(sourceName,destName,spellId)
    spellId=tonumber(spellId)
    local ability=AURA_TO_ABILITY[spellId]; if not ability then return end
    local state={expiresAt=clock()+(ability.duration or 0),targetName=destName,sourceName=sourceName,status=L["ACTIVE"]}
    if ability.allPlayers then
        self.activePlayerStates[shortName(destName)]=self.activePlayerStates[shortName(destName)] or {}
        self.activePlayerStates[shortName(destName)][ability.key]=state
    else
        self.activeAuras[ability.key]=self.activeAuras[ability.key] or {}
        self.activeAuras[ability.key][shortName(sourceName)]=state
        if ability.state=="soulstone" then self.soulstoneStates[shortName(sourceName)]={expiresAt=clock()+(ability.duration or 900),targetName=destName,status=L["PLACED"]} end
    end
    if self:IsOpen() then self:RefreshAll() end
end

function CDW:OnAuraRemoved(sourceName,destName,spellId)
    spellId=tonumber(spellId)
    local ability=AURA_TO_ABILITY[spellId]; if not ability then return end
    if ability.allPlayers then
        local p=self.activePlayerStates[shortName(destName)]; if p then p[ability.key]=nil end
    else
        local c=self.activeAuras[ability.key] or {}
        if sourceName then c[shortName(sourceName)]=nil else
            for name,state in pairs(c) do if sameName(state.targetName,destName) then c[name]=nil end end
        end
        if ability.state=="soulstone" and sourceName then self.soulstoneStates[shortName(sourceName)]={expiresAt=clock()+(ability.cd or 900),targetName=destName,status=L["CONSUMED"]} end
    end
    if self:IsOpen() then self:RefreshAll() end
end

function CDW:OnUnitDied(name)
    if not name then return end
    for _,state in pairs(self.soulstoneStates) do
        if sameName(state.targetName,name) and state.status==L["PLACED"] then state.status=L["CONSUMED"]; state.expiresAt=clock()+((ABILITY_BY_KEY.soulstone and ABILITY_BY_KEY.soulstone.cd) or 900) end
    end
    if self:IsOpen() then self:RefreshAll() end
end

function CDW:UpdateCooldownIcons() if self:IsOpen() then self:RefreshAll() end end
function CDW:ApplyAppearance() self:ApplyBackdropSettings() end
function CDW:ApplyLayoutMode() self:SetLayoutMode(self:NormalizeSettings().layoutMode) end

CDW.Categories, CDW.AbilitiesByKey, CDW.AbilitiesByName = CATEGORIES, ABILITY_BY_KEY, ABILITY_BY_NAME
CDW.MacroGroups, CDW.MacroGroupsByKey = MACRO_GROUPS, MACRO_GROUP_BY_KEY
