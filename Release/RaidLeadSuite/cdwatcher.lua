-- ============================================================
-- RLSuite - CD Watcher (WotLK 3.3.5)
-- ============================================================
-- Categorized cooldown/debuff monitor. This window is independent from the
-- Raid Frame; the Raid Frame is used only as a manual caster-assignment target.
-- ============================================================

RLSuite.cdwatcher = {}
local CDW = RLSuite.cdwatcher
local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

local ROW_H, HEADER_H, SUBHEADER_H = 34, 24, 18
local TITLE_H, PAD, ICON_SIZE = 30, 8, 24
local MAIN_W, INSPECT_W = 570, 390
local MAX_SCROLL_H = 620
local DEAD_ICON = "Interface\\Icons\\INV_Misc_Bone_Skull_01"
local OFFLINE_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local STATUSBAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

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
    { key = "raid_wide_offensive", title = "RWO — Raid Wide Offensive", abilities = {
        { key="bloodlust", name="Bloodlust / Heroism", class="SHAMAN", ids={2825,32182}, cd=300, duration=40, auraIds={2825,32182} },
        { key="sated_state", name="Sated / Exhaustion", allPlayers=true, auraIds={57724,57723}, cd=0, duration=600, stateOnly=true },
        { key="shattering_throw", name="Shattering Throw", class="WARRIOR", ids={64382}, cd=300, specs={"Arms"}, duration=10, auraIds={64382} },
    } },
    { key = "raid_party_defensive", title = "RPWD — Raid/Party Wide Defensive", abilities = {
        { key="aura_mastery", name="Aura Mastery", class="PALADIN", ids={31821}, cd=120, specs={"Holy"}, duration=6, auraIds={31821} },
        { key="divine_sacrifice", name="Divine Sacrifice", class="PALADIN", ids={64205}, cd=120, specs={"Protection"}, duration=10, auraIds={64205} },
        { key="divine_hymn", name="Divine Hymn", class="PRIEST", ids={64843}, cd=480, duration=8, auraIds={64843} },
        { key="anti_magic_zone", name="Anti-Magic Zone", class="DEATHKNIGHT", ids={51052}, cd=120, specs={"Unholy"}, duration=10, auraIds={51052} },
        { key="tranquility", name="Tranquility", class="DRUID", ids={48447,26983,9863,740}, cd=480, duration=8, auraIds={48447,26983} },
    } },
    { key = "single_target_offensive", title = "STO — Single Target Offensive", abilities = {
        { key="power_infusion", name="Power Infusion", class="PRIEST", ids={10060}, cd=180, specs={"Discipline"}, duration=15, auraIds={10060}, target=true },
        { key="hysteria", name="Hysteria", class="DEATHKNIGHT", ids={49016}, cd=180, specs={"Blood"}, duration=30, auraIds={49016}, target=true },
    } },
    { key = "single_target_defensive", title = "STD — Single Target Defensive", abilities = {
        { key="hand_of_sacrifice", name="Hand of Sacrifice", class="PALADIN", ids={6940}, cd=120, duration=12, auraIds={6940}, target=true },
        { key="hand_of_protection", name="Hand of Protection", class="PALADIN", ids={1022,5599,10278}, cd=300, duration=10, auraIds={1022,5599,10278}, target=true },
        { key="lay_on_hands", name="Lay on Hands", class="PALADIN", ids={633,2800,10310,27154,48788}, cd=1200, auraIds={633,2800,10310,27154,48788}, target=true },
        { key="pain_suppression", name="Pain Suppression", class="PRIEST", ids={33206}, cd=180, specs={"Discipline"}, duration=8, auraIds={33206}, target=true },
        { key="guardian_spirit", name="Guardian Spirit", class="PRIEST", ids={47788}, cd=180, specs={"Holy"}, duration=10, auraIds={47788}, target=true },
    } },
    { key = "battle_res", title = "BR — Battle Res", abilities = {
        { key="rebirth", name="Rebirth", class="DRUID", ids={48477,26994,20748,20484}, cd=600, target=true },
        { key="soulstone", name="Soulstone", class="WARLOCK", ids={47884,47883,27239,20765,20764,20763,20762,20707}, cd=900, duration=900, auraIds={47883,47884}, state="soulstone", target=true },
    } },
    { key = "mana_regen", title = "Mana Regen", abilities = {
        { key="innervate", name="Innervate", class="DRUID", ids={29166}, cd=180, duration=10, auraIds={29166}, target=true },
        { key="mana_tide_totem", name="Mana Tide Totem", class="SHAMAN", ids={16190}, cd=300, duration=12, auraIds={16190} },
        { key="hymn_of_hope", name="Hymn of Hope", class="PRIEST", ids={64901}, cd=360, duration=8, auraIds={64901} },
    } },
    { key = "threat", title = "Threat — Taunt & Aggro", abilities = {
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
    { key = "interrupts", title = "INT — Interrupt rotation", abilities = {
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
    { key = "cc", title = "CC — Active state, target and expiration", abilities = {
        { key="polymorph", name="Polymorph", class="MAGE", ids={118,12824,12825,12826,28271,28272,61025}, auraIds={118,12824,12825,12826,28271,28272,61025}, cd=1.5, duration=50, target=true },
        { key="cyclone", name="Cyclone", class="DRUID", ids={33786}, auraIds={33786}, cd=1.5, duration=6, target=true },
        { key="entangling_roots", name="Entangling Roots", class="DRUID", ids={339,1062,5195,5196,9852,9853,26989}, auraIds={339,1062,5195,5196,9852,9853,26989}, cd=1.5, duration=27, target=true },
        { key="hex", name="Hex", class="SHAMAN", ids={51514}, auraIds={51514}, cd=45, duration=10, target=true },
        { key="blind", name="Blind", class="ROGUE", ids={2094}, auraIds={2094}, cd=180, duration=10, target=true },
        { key="freezing_trap", name="Freezing Trap", class="HUNTER", ids={14311,14310,14309,3355}, auraIds={3355}, cd=30, duration=60, target=true },
        { key="sap", name="Sap", class="ROGUE", ids={6770,2070,11297,51724}, auraIds={6770,2070,11297,51724}, cd=1.5, duration=25, target=true },
        { key="wyvern_sting", name="Wyvern Sting", class="HUNTER", ids={49012,49011}, auraIds={49012,49011}, cd=60, duration=12, target=true },
    } },
    { key = "cc_toc", title = "CC — Solo ToC", abilities = {
        { key="fear", name="Fear", class="WARLOCK", ids={5782,6213,6215}, auraIds={5782,6213,6215}, cd=1.5, duration=20, target=true },
        { key="banish", name="Banish", class="WARLOCK", ids={710,18647,18648}, auraIds={710,18647,18648}, cd=1.5, duration=60, target=true },
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

function CDW:NormalizeSettings()
    local s = self:GetSettings()
    if s.layoutMode ~= "combined" and s.layoutMode ~= "separate" then s.layoutMode = "combined" end
    s.categories, s.collapsed, s.assignments = s.categories or {}, s.collapsed or {}, s.assignments or {}
    if s.groupByCaster == nil then s.groupByCaster = false end
    if s.autoInspect == nil then s.autoInspect = true end
    s.barHeight = math.max(26, math.min(60, tonumber(s.barHeight) or ROW_H))
    s.barWidth = math.max(300, math.min(900, tonumber(s.barWidth) or MAIN_W - 40))
    s.barTexture = type(s.barTexture) == "string" and s.barTexture or STATUSBAR_TEXTURE
    s.showAbilityText = s.showAbilityText ~= false
    s.showPlayerText = s.showPlayerText ~= false
    s.showTimerText = s.showTimerText ~= false
    s.showDetailText = s.showDetailText ~= false
    s.fontFace = type(s.fontFace) == "string" and s.fontFace or "Fonts\\FRIZQT__.TTF"
    s.fontSize = math.max(8, math.min(24, tonumber(s.fontSize) or 11))
    if s.fontOutline == nil then s.fontOutline = true end
    if type(s.fontColor) ~= "table" then s.fontColor = { r = 1, g = 1, b = 1, a = 1 } end
    local order, seen = {}, {}
    for _, key in ipairs(s.categoryOrder or {}) do
        if CATEGORY_BY_KEY[key] and not seen[key] then order[#order+1], seen[key] = key, true end
    end
    for _, key in ipairs(ORDER_KEYS) do if not seen[key] then order[#order+1] = key end end
    s.categoryOrder = order
    return s
end

function CDW:GetCategoryOrder() return self:NormalizeSettings().categoryOrder end
function CDW:IsCategoryEnabled(key) return self:NormalizeSettings().categories[key] ~= false end
function CDW:GetBarHeight() return self:NormalizeSettings().barHeight end
function CDW:GetBarWidth() return self:NormalizeSettings().barWidth end

function CDW:ApplyBarSettings()
    self:NormalizeSettings()
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
    if enabled and settings.layoutMode=="separate" and self.isOpen then
        self:EnsureCategoryWindow(key):Show()
    end
end

function CDW:SetGroupByCaster(enabled)
    self:NormalizeSettings().groupByCaster = enabled and true or false
    self:RefreshAll()
end

function CDW:SetAutoInspect(enabled)
    self:NormalizeSettings().autoInspect = enabled and true or false
    self:RefreshAll()
end

function CDW:IsOpen()
    if self.frame and self.frame:IsShown() then return true end
    if self.inspectFrame and self.inspectFrame:IsShown() then return true end
    for _, frame in pairs(self.categoryWindows or {}) do if frame:IsShown() then return true end end
    return false
end

function CDW:CreateWindow(name, title, key, width, categoryKey)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, 260)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:Hide()
    frame.categoryKey = categoryKey
    frame.barFrames, frame.headerFrames, frame.subheaderFrames = {}, {}, {}
    RLSuite.utils:MakeUniversalWindow(frame, key)
    RLSuite.utils:ApplySavedPos(frame, key, function()
        local idx = 1
        for i, cat in ipairs(self:GetCategoryOrder()) do if cat == categoryKey then idx = i break end end
        return ((idx - 1) % 3) * 34, -math.floor((idx - 1) / 3) * 34
    end)

    frame.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.titleText:SetPoint("LEFT", frame, "TOPLEFT", PAD, -TITLE_H / 2)
    frame.titleText:SetWidth(math.max(80,width-126))
    frame.titleText:SetJustifyH("LEFT")
    frame.titleText:SetText(title)
    frame.titleText:SetTextColor(1, 0.82, 0)
    frame.closeBtn = RLSuite.utils:MakeCloseX(frame, function() frame:Hide() end)
    frame.closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    frame.optionsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.optionsBtn:SetSize(48, 20)
    frame.optionsBtn:SetPoint("RIGHT", frame.closeBtn, "LEFT", -4, 0)
    frame.optionsBtn:SetText(L["Config"])
    frame.optionsBtn:SetScript("OnClick", function() CDW:OpenConfig() end)

    frame.scroll = CreateFrame("ScrollFrame", name .. "Scroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TITLE_H)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, PAD)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(width - 40, 1)
    frame.scroll:SetScrollChild(frame.content)
    RLSuite.utils:RegisterScrollClip(frame.scroll, frame.content)
    frame.scroll:SetScript("OnSizeChanged", function(_, w)
        if w and w > 40 then frame.content:SetWidth(w) end
    end)
    frame:SetScript("OnShow", function() CDW:RefreshAll() end)
    frame:SetScript("OnHide", function()
        if frame == CDW.frame and CDW:NormalizeSettings().layoutMode == "combined" then CDW.isOpen = false end
        if frame.categoryKey and CDW:NormalizeSettings().layoutMode == "separate" then
            local any = false
            for _, f in pairs(CDW.categoryWindows or {}) do if f:IsShown() then any = true break end end
            if not any then CDW.isOpen = false end
        end
    end)
    return frame
end

function CDW:EnsureWindow()
    if self.frame then return self.frame end
    self.frame = self:CreateWindow("RLSuiteCDWatcherWindow", L["CD Watcher"], "cdwatcher", self:GetBarWidth() + 40)
    return self.frame
end

function CDW:EnsureCategoryWindow(key)
    if self.categoryWindows[key] then return self.categoryWindows[key] end
    local category = CATEGORY_BY_KEY[key]
    if not category then return nil end
    self.categoryWindows[key] = self:CreateWindow("RLSuiteCDW_" .. key, L[category.title] or category.title,
        "cdwatcher_" .. key, self:GetBarWidth() + 40, key)
    return self.categoryWindows[key]
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
    if self.frame then result[#result+1] = self.frame end
    if self.inspectFrame then result[#result+1] = self.inspectFrame end
    if self.previewWindow then result[#result+1] = self.previewWindow end
    for _, category in ipairs(CATEGORIES) do
        if self.categoryWindows and self.categoryWindows[category.key] then result[#result+1] = self.categoryWindows[category.key] end
    end
    return result
end

function CDW:Init()
    self:NormalizeSettings()
    self.cdTracker, self.activeAuras, self.activePlayerStates = self.cdTracker or {}, self.activeAuras or {}, self.activePlayerStates or {}
    self.soulstoneStates, self.totemStates = self.soulstoneStates or {}, self.totemStates or {}
    self.inspectCache, self.inspectStatus, self.inspectQueue = self.inspectCache or {}, self.inspectStatus or {}, self.inspectQueue or {}
    self.categoryWindows, self.rows = self.categoryWindows or {}, self.rows or {}
    self._nextInspectAt = 0
    self._rosterDirty = true
    self:EnsureWindow()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnRosterChanged")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnRosterChanged")
    self:RegisterEvent("INSPECT_READY", "OnInspectReady")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnInspectPermissionChanged")
    self:ScheduleRepeatingTimer("Update", 0.5)
    self:RefreshAll()
end

function CDW:ShowCurrentMode()
    self.isOpen, self._inspectDismissed = true, false
    local mode, shown = self:NormalizeSettings().layoutMode, false
    if mode == "combined" then
        self:EnsureWindow():Show()
        shown = true
    else
        self:EnsureWindow():Hide()
        for _, key in ipairs(self:GetCategoryOrder()) do
            if self:IsCategoryEnabled(key) then self:EnsureCategoryWindow(key):Show(); shown=true end
        end
    end
    if #((self.inspectItems) or {}) > 0 then self:EnsureInspectWindow():Show(); shown=true end
    if not shown then self:OpenConfig("general") end
end

function CDW:Toggle()
    local mode, displayOpen = self:NormalizeSettings().layoutMode, false
    if mode == "combined" then
        displayOpen = self.frame and self.frame:IsShown() or false
    else
        for _, frame in pairs(self.categoryWindows) do if frame:IsShown() then displayOpen=true break end end
    end
    if displayOpen then
        self.isOpen = false
        if self.frame then self.frame:Hide() end
        if self.inspectFrame then self.inspectFrame:Hide() end
        for _, frame in pairs(self.categoryWindows) do frame:Hide() end
        return
    end
    self:ShowCurrentMode()
end

function CDW:SetLayoutMode(mode)
    if mode ~= "combined" and mode ~= "separate" then return end
    local wasOpen = self:IsOpen()
    self:NormalizeSettings().layoutMode = mode
    if self.frame then self.frame:Hide() end
    if self.inspectFrame then self.inspectFrame:Hide() end
    for _, frame in pairs(self.categoryWindows) do frame:Hide() end
    self.isOpen, self._inspectDismissed = wasOpen, false
    self:RefreshAll()
    if wasOpen then self:ShowCurrentMode() end
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

function CDW:IsTank(member)
    if not member then return nil end
    local role = string.upper(tostring(member.role or ""))
    if role == "TANK" or role == "MAINTANK" or role == "MAIN TANK" then return true end
    for _, slot in ipairs((RLSuite.raidFrame and RLSuite.raidFrame.tankSlots) or {}) do
        if slot and (sameName(slot.name, member.name) or (slot.member and sameName(slot.member.name, member.name))) then return true end
    end
    local spec = self:GetSpec(member)
    if spec == "Protection" or spec == "Blood" or spec == "Feral" then return true end
    if spec then return false end
    return nil
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

function CDW:CanTrack(ability, member, needs)
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
    local needs, modelsByCategory = {}, {}
    for _, category in ipairs(CATEGORIES) do
        local candidates, models, seen = {}, {}, {}
        for _, ability in ipairs(category.abilities) do
            for _, member in ipairs(roster) do
                local canTrack, unknown
                if ability.allPlayers then canTrack, unknown = true, false
                else canTrack, unknown = self:CanTrack(ability, member, needs) end
                if canTrack then
                    local key = ability.key .. "@" .. shortName(member.name)
                    local assigned = not ability.allPlayers and self:NormalizeSettings().assignments[key] or nil
                    local owner = assigned and memberByName[shortName(assigned)] or member
                    candidates[#candidates + 1] = {
                        key=key, assignmentKey=key, ability=ability, sourceName=member.name,
                        ownerName=(owner and owner.name) or assigned or member.name, member=owner or member,
                        unknown=unknown, assigned=assigned and not sameName(assigned, member.name) or false,
                        rosterOrder=orderByName[shortName(owner and owner.name or member.name)] or orderByName[shortName(member.name)] or 999,
                    }
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
            local ownerKey = model.ability.key .. "@" .. shortName(model.ownerName)
            if not seen[ownerKey] then
                seen[ownerKey] = true
                model.cooldown = self:GetAbilityRemaining(model.ownerName, model.member.unit, model.ability)
                model.active = self:GetActive(model.ability, model.ownerName, model.ownerName)
                model.activeLeft = model.active and model.active.remaining or nil
                model.ready = model.cooldown <= 0 and not (model.ability.stateOnly and model.active)
                model.life = self:LifeState(model.member)
                model.rosterOrder = orderByName[shortName(model.ownerName)] or model.rosterOrder
                model.categoryOrder = model.ability.order
                if model.active and model.ability.target then model.targetName = model.active.targetName end
                models[#models+1] = model
            end
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

function CDW:GroupModels(models)
    local groups, lookup = {}, {}
    for _, model in ipairs(models) do
        local key = shortName(model.ownerName)
        local group = lookup[key]
        if not group then
            group = { name=model.ownerName, order=model.rosterOrder, models={}, ready=false, soonest=nil }
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
    row:RegisterForDrag("LeftButton")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetTexture(WHITE_TEXTURE)
    row.bg:SetAllPoints(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.08,0.92,0.08,0.92)
    row.icons = {row.icon}
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", ICON_SIZE+6, -3)
    row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -14, 3)
    row.bar:SetStatusBarTexture(self:NormalizeSettings().barTexture or STATUSBAR_TEXTURE)
    row.abilityText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.abilityText:SetPoint("TOPLEFT", row.bar, "TOPLEFT", 6, -2)
    row.abilityText:SetWidth(math.floor((width-ICON_SIZE-28)*0.47))
    row.playerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.playerText:SetPoint("TOPRIGHT", row.bar, "TOPRIGHT", -48, -2)
    row.playerText:SetWidth(math.floor((width-ICON_SIZE-28)*0.36))
    row.playerText:SetJustifyH("RIGHT")
    row.detailText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.detailText:SetPoint("BOTTOMLEFT", row.bar, "BOTTOMLEFT", 6, 2)
    row.detailText:SetWidth(math.floor((width-ICON_SIZE-28)*0.72))
    row.timer = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.timer:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", -5, 2)
    row.timer:SetWidth(44)
    row.timer:SetJustifyH("RIGHT")
    row.timer:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    row.icon.timer = row.timer
    row.alive = row:CreateTexture(nil, "OVERLAY")
    row.alive:SetTexture(WHITE_TEXTURE)
    row.alive:SetSize(8,8)
    row.alive:SetPoint("RIGHT", row, "RIGHT", -1, 0)
    row.alive:Hide()
    row:SetScript("OnDragStart", function(frame) if frame.data and not frame.data.preview then CDW.draggedBar = frame end end)
    row:SetScript("OnDragStop", function(frame) if frame.data and not frame.data.preview then CDW:OnBarDragStop(frame) end end)
    row:SetScript("OnEnter", function(frame) if frame.data and not frame.data.preview then CDW:ShowBarTooltip(frame) end end)
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
    local meta = RLSuite.abilityByName and RLSuite.abilityByName[ability.name]
    return (meta and meta.icon) or ability.icon or QUESTION_ICON
end

function CDW:FormatTime(value)
    if not value or value <= 0 then return L["READY"] end
    if RLSuite.utils and RLSuite.utils.FormatCD then return RLSuite.utils:FormatCD(value) end
    return tostring(math.ceil(value)) .. "s"
end

function CDW:RenderBar(window, model, y, width)
    local row = self:EnsureBar(window, model, width)
    local settings = self:NormalizeSettings()
    local height = self:GetBarHeight()
    local textWidth = math.max(100, width - ICON_SIZE - 28)
    local font = settings.fontFace or "Fonts\\FRIZQT__.TTF"
    local fontSize = tonumber(settings.fontSize) or 11
    local fontFlags = settings.fontOutline and "OUTLINE" or nil
    local fontColor = settings.fontColor or { r=1, g=1, b=1 }

    row.data, row.modelKey, row.ability = model, model.key, model.ability.key
    row.icons[1].ability = model.ability.key
    row:EnableMouse(not model.preview)
    row.icon:SetTexture(self:IconFor(model.ability))
    row.icon:SetVertexColor(1,1,1,1)
    row.bg:SetVertexColor(0.08,0.08,0.1,0.92)
    row.bar:SetStatusBarTexture(settings.barTexture or STATUSBAR_TEXTURE)
    row.abilityText:SetWidth(math.floor(textWidth*0.47))
    row.playerText:SetWidth(math.floor(textWidth*0.36))
    row.detailText:SetWidth(math.floor(textWidth*0.72))
    row.timer:SetWidth(math.min(52, math.floor(textWidth*0.20)))
    row.abilityText:SetFont(font,fontSize,fontFlags)
    row.playerText:SetFont(font,fontSize,fontFlags)
    row.detailText:SetFont(font,fontSize,fontFlags)
    row.timer:SetFont(font,fontSize,fontFlags)

    local r,g,b = self:ClassColor(model.member and model.member.class)
    local max = model.ability.cd > 0 and model.ability.cd or (model.ability.duration or 1)
    if model.ability.stateOnly and model.activeLeft then
        row.bar:SetMinMaxValues(0, max)
        row.bar:SetValue(math.max(0,math.min(max,model.activeLeft)))
    else
        row.bar:SetMinMaxValues(0,max)
        row.bar:SetValue(math.max(0,math.min(max,model.cooldown or 0)))
    end
    row.bar:SetStatusBarColor(r,g,b,1)

    if model.life == "dead" then
        row.icon:SetTexture(DEAD_ICON)
        row.bg:SetVertexColor(0.10,0.10,0.11,1)
        row.bar:SetStatusBarColor(0.30,0.30,0.32,1)
    elseif model.life == "disconnected" then
        row.icon:SetTexture(OFFLINE_ICON)
        row.bg:SetVertexColor(0.10,0.10,0.11,1)
        row.bar:SetStatusBarColor(0.30,0.30,0.32,1)
    end

    row.abilityText:SetText(model.ability.name)
    row.abilityText:SetTextColor(fontColor.r or 1,fontColor.g or 1,fontColor.b or 1,1)
    if settings.showAbilityText then row.abilityText:Show() else row.abilityText:Hide() end
    local player = model.ownerName or "?"
    if model.nextInterrupt then player = "[NEXT] " .. player end
    row.playerText:SetText(player)
    row.playerText:SetTextColor(r,g,b,1)
    if settings.showPlayerText then row.playerText:Show() else row.playerText:Hide() end
    local detail = model.life == "dead" and L["DEAD"] or (model.life == "disconnected" and L["DISCONNECTED"] or (model.life == "alive" and L["ALIVE"] or ""))
    if model.unknown then detail = detail ~= "" and (detail .. " · ") or ""; detail = detail .. L["Inspect needed"] end
    if model.targetName then detail = detail ~= "" and (detail .. " · ") or ""; detail = detail .. string.format(L["Target: %s"],model.targetName) end
    if model.active and model.active.status then detail = detail ~= "" and (detail .. " · ") or ""; detail = detail .. model.active.status end
    if model.activeLeft and model.activeLeft > 0 then detail = detail ~= "" and (detail .. " · ") or ""; detail = detail .. string.format(L["Expires in %s"],self:FormatTime(model.activeLeft)) end
    row.detailText:SetText(detail)
    row.detailText:SetTextColor(fontColor.r or 1,fontColor.g or 1,fontColor.b or 1,1)
    if settings.showDetailText then row.detailText:Show() else row.detailText:Hide() end
    if model.cooldown and model.cooldown > 0 then row.timer:SetText(self:FormatTime(model.cooldown))
    elseif model.activeLeft and model.activeLeft > 0 then row.timer:SetText(self:FormatTime(model.activeLeft))
    elseif model.active and model.active.status then row.timer:SetText(model.active.status)
    else row.timer:SetText(L["READY"]) end
    row.timer:SetTextColor(fontColor.r or 1,fontColor.g or 1,fontColor.b or 1,1)
    if settings.showTimerText then row.timer:Show() else row.timer:Hide() end
    if model.life == "alive" then
        if model.ready then row.alive:SetVertexColor(0.10,0.9,0.2,1) else row.alive:SetVertexColor(0.10,0.55,0.18,1) end
        row.alive:Show()
    else row.alive:Hide() end
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
        if GameTooltip then GameTooltip:SetOwner(frame,"ANCHOR_TOPLEFT"); GameTooltip:SetText(L["Drag this category header to change its order."]); GameTooltip:Show() end
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

function CDW:CategoryAtCursor()
    if not GetCursorPosition or not self.frame then return nil end
    local x,y=GetCursorPosition(); local scale=self.frame:GetEffectiveScale() or 1; x,y=x/scale,y/scale
    for key,h in pairs(self.frame.headerFrames or {}) do
        if h:IsShown() and type(h:GetLeft())=="number" and x>=h:GetLeft() and x<=h:GetRight() and y>=h:GetBottom() and y<=h:GetTop() then
            return key,y>=(h:GetBottom()+h:GetTop())/2
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

function CDW:RenderRows(window,key,models,y,width,usedBars,usedSubs)
    local s=self:NormalizeSettings()
    if s.collapsed[key] then return y end
    local sorted={}; for _,m in ipairs(models or {}) do sorted[#sorted+1]=m end
    self:SortModels(sorted)
    local function renderOne(model)
        if key=="interrupts" and model.ready and not self._nextInterruptMarked then model.nextInterrupt=true; self._nextInterruptMarked=true else model.nextInterrupt=false end
        local row=self:RenderBar(window,model,y,width); usedBars[row]=true; y=y+self:GetBarHeight()
    end
    self._nextInterruptMarked=false
    if s.groupByCaster then
        local ready, cooling = {}, {}
        for _, model in ipairs(sorted) do
            if model.ready then ready[#ready+1]=model else cooling[#cooling+1]=model end
        end
        local function renderGroups(list)
            for _,group in ipairs(self:GroupModels(list)) do
                local h=self:EnsureSubheader(window,group.name); h:ClearAllPoints(); h:SetPoint("TOPLEFT",window.content,"TOPLEFT",0,-y)
                h:SetSize(width-10,SUBHEADER_H); h:Show(); usedSubs[h]=true; y=y+SUBHEADER_H
                for _,model in ipairs(group.models) do renderOne(model) end
            end
        end
        renderGroups(ready)
        renderGroups(cooling)
    else
        for _,model in ipairs(sorted) do renderOne(model) end
    end
    return y
end

function CDW:FinalizeWindow(window,height,width,usedBars,usedHeads,usedSubs)
    for _,row in pairs(window.barFrames) do if not usedBars[row] then row:Hide() end end
    for _,row in pairs(window.headerFrames) do if not usedHeads[row] then row:Hide() end end
    for _,row in pairs(window.subheaderFrames) do if not usedSubs[row] then row:Hide() end end
    window.content:SetSize(width-40,math.max(1,height))
    window:SetSize(width,TITLE_H+math.min(math.max(self:GetBarHeight(),height),MAX_SCROLL_H)+PAD*2)
end

function CDW:RenderCombined()
    local width=self:GetBarWidth()+40; local contentWidth=width-40
    local window=self:EnsureWindow(); local usedBars,usedHeads,usedSubs={}, {}, {}; local y=4
    self.rows={}
    for _,key in ipairs(self:GetCategoryOrder()) do
        local cat=CATEGORY_BY_KEY[key]
        local h=self:EnsureCategoryHeader(window,key,contentWidth)
        h:ClearAllPoints(); h:SetPoint("TOPLEFT",window.content,"TOPLEFT",0,-y); h:SetSize(contentWidth,HEADER_H)
        h.title:SetText(L[cat.title] or cat.title); h.visible:SetText(self:IsCategoryEnabled(key) and "ON" or "--")
        h.collapse:SetText(self:NormalizeSettings().collapsed[key] and "+" or "−")
        h:Show(); usedHeads[h]=true; y=y+HEADER_H
        if self:IsCategoryEnabled(key) then
            y=self:RenderRows(window,key,self.modelsByCategory[key],y,contentWidth,usedBars,usedSubs)+4
        else
            y=y+2
        end
    end
    self:FinalizeWindow(window,y,width,usedBars,usedHeads,usedSubs)
    for _,key in ipairs(self:GetCategoryOrder()) do
        for _,row in pairs(window.barFrames) do if row:IsShown() and row.data and row.data.ability.category==key then self.rows[#self.rows+1]=row end end
    end
end

function CDW:RenderSeparate()
    local width=self:GetBarWidth()+40; local contentWidth=width-40
    self.rows={}
    for _,key in ipairs(self:GetCategoryOrder()) do
        if self:IsCategoryEnabled(key) then
            local w=self:EnsureCategoryWindow(key); local usedBars,usedHeads,usedSubs={}, {}, {}; local y=2
            y=self:RenderRows(w,key,self.modelsByCategory[key],y,contentWidth,usedBars,usedSubs)
            self:FinalizeWindow(w,y,width,usedBars,usedHeads,usedSubs)
            if #self.rows==0 then for _,row in pairs(w.barFrames) do if row:IsShown() then self.rows[#self.rows+1]=row end end end
        elseif self.categoryWindows[key] then self.categoryWindows[key]:Hide() end
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
    w.content:SetSize(INSPECT_W-40,math.max(1,y)); w:SetSize(INSPECT_W,TITLE_H+math.min(y,MAX_SCROLL_H)+PAD*2)
    if not self._inspectDismissed and (self.isOpen or self:NormalizeSettings().layoutMode=="combined") then w:Show() end
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
    if not self.frame then return end
    self:BuildModels(); self:QueueInspectNeeds()
    if self:NormalizeSettings().layoutMode=="combined" then self:RenderCombined() else self:RenderSeparate() end
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
    if not self.frame then return end
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

function CDW:OnBarDragStop(frame)
    local model=frame and frame.data; if not model then return end
    local target=RLSuite.raidFrame and RLSuite.raidFrame.MemberRowAtCursor and RLSuite.raidFrame:MemberRowAtCursor(14)
    if not target or not target.name then RLSuite.utils:Print(L["Drop the cooldown bar on a player row in the Raid Frame."]); return end
    self:AssignCaster(model,target.name)
end

function CDW:AssignCaster(model,name)
    if not model or not name then return false end
    local assignments=self:NormalizeSettings().assignments
    if sameName(model.sourceName,name) then assignments[model.assignmentKey]=nil else assignments[model.assignmentKey]=name end
    self:RefreshAll(); return true
end

function CDW:ShowBarTooltip(frame)
    local model=frame and frame.data; if not model or not GameTooltip then return end
    GameTooltip:SetOwner(frame,"ANCHOR_RIGHT"); GameTooltip:SetText(model.ability.name)
    GameTooltip:AddLine(string.format(L["Caster: %s"],model.ownerName or "?"),1,1,1)
    if model.targetName then GameTooltip:AddLine(string.format(L["Target: %s"],model.targetName),1,1,1) end
    GameTooltip:AddLine(L["Drag this cooldown bar onto a player row in the Raid Frame to assign its caster."],0.8,0.8,0.8)
    GameTooltip:AddLine(L["Drop it on the original caster to clear the override."],0.8,0.8,0.8)
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
    if not sourceName or not spellId then return end
    local ability=SPELL_TO_ABILITY[spellId]
    if not ability then
        local oldName=RLSuite.abilityBySpellId and RLSuite.abilityBySpellId[spellId]
        ability=oldName and ABILITY_BY_NAME[oldName]
    end
    if not ability then return end
    if ability.cd>0 then self.cdTracker[shortName(sourceName)]=self.cdTracker[shortName(sourceName)] or {}; self.cdTracker[shortName(sourceName)][ability.key]=clock()+ability.cd end
    if ability.totem then self.totemStates[shortName(sourceName)]=self.totemStates[shortName(sourceName)] or {}; self.totemStates[shortName(sourceName)][ability.key]={expiresAt=clock()+(ability.duration or 120),status=L["TOTEM ACTIVE"]} end
    if ability.state=="soulstone" then self.soulstoneStates[shortName(sourceName)]={expiresAt=clock()+(ability.duration or 900),targetName=destName,status=L["PLACED"]} end
    if self:IsOpen() then self:RefreshAll() end
end

function CDW:OnAuraApplied(sourceName,destName,spellId)
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
function CDW:ApplyAppearance() for _,f in ipairs(self:GetWindows()) do if RLSuite.utils and RLSuite.utils.SkinFrame then RLSuite.utils:SkinFrame(f) end end end
function CDW:ApplyLayoutMode() self:SetLayoutMode(self:NormalizeSettings().layoutMode) end

CDW.Categories, CDW.AbilitiesByKey, CDW.AbilitiesByName = CATEGORIES, ABILITY_BY_KEY, ABILITY_BY_NAME
