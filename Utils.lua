-- ============================================================
-- RLSuite - Utils
-- ============================================================

RLSuite = RLSuite or {}
RLSuite.utils = {}
local Utils = RLSuite.utils

function Utils:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RLSuite]|r " .. tostring(msg))
end

function Utils:Debug(msg)
    if RLSuiteDB and RLSuiteDB.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff999999[RLSuite-Debug]|r " .. tostring(msg))
    end
end

function Utils:TableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function Utils:CopyTable(src, dest)
    dest = dest or {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = self:CopyTable(v)
        else
            dest[k] = v
        end
    end
    return dest
end

function Utils:GetClassColor(class)
    local colors = {
        WARRIOR     = {r=0.78, g=0.61, b=0.43},
        PALADIN     = {r=0.96, g=0.55, b=0.73},
        HUNTER      = {r=0.67, g=0.83, b=0.45},
        ROGUE       = {r=1.00, g=0.96, b=0.41},
        PRIEST      = {r=1.00, g=1.00, b=1.00},
        DEATHKNIGHT = {r=0.77, g=0.12, b=0.23},
        SHAMAN      = {r=0.00, g=0.44, b=0.87},
        MAGE        = {r=0.25, g=0.78, b=0.92},
        WARLOCK     = {r=0.53, g=0.53, b=0.93},
        DRUID       = {r=1.00, g=0.49, b=0.04},
    }
    local c = colors[(class or "WARRIOR"):upper()] or {r=1, g=1, b=1}
    return c.r, c.g, c.b
end

function Utils:FormatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

function Utils:FormatCD(seconds)
    seconds = math.floor(seconds + 0.5)
    if seconds >= 60 then
        return tostring(math.floor(seconds / 60)) .. "m"
    end
    return tostring(seconds)
end

function Utils:SendChat(msg, channel)
    if not msg or msg == "" then return end
    channel = channel or "RAID"
    if RLSuiteDB and RLSuiteDB.debug then
        local me = UnitName("player")
        if me then
            SendChatMessage("[" .. channel .. "] " .. msg, "WHISPER", nil, me)
        end
        return
    end
    if channel == "RAID_WARNING" and not IsRaidLeader() and not IsRaidOfficer() then
        channel = "RAID"
    end
    SendChatMessage(msg, channel)
end

function Utils:Whisper(name, msg)
    if not msg or msg == "" then return end
    local dest = name
    if RLSuiteDB and RLSuiteDB.debug then
        dest = UnitName("player")
    end
    if dest then
        SendChatMessage(msg, "WHISPER", nil, dest)
    end
end

function Utils:StripColorCodes(text)
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Full WotLK 3.3.5 hyperlink: |cffffffff|Hitem:id:ench:g1:g2:g3:g4:suffix:unique:level|h[Name]|h|r
function Utils:GetItemLinkFromChat(text)
    if not text or text == "" then return nil end
    local full = text:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if full then return full end
    local inner = text:match("|H(item:[^|]+)|h")
    if inner then return inner end
    return text:match("(item:%d+[:%d]*)")
end

function Utils:ClassIcon(class)
    local icons = {
        WARRIOR = "Interface\\Icons\\INV_Sword_04",
        PALADIN = "Interface\\Icons\\INV_Hammer_01",
        HUNTER = "Interface\\Icons\\INV_Weapon_Bow_07",
        ROGUE = "Interface\\Icons\\INV_ThrowingKnife_04",
        PRIEST = "Interface\\Icons\\INV_Staff_30",
        DEATHKNIGHT = "Interface\\Icons\\Spell_Deathknight_ClassIcon",
        SHAMAN = "Interface\\Icons\\INV_Jewelry_Talisman_04",
        MAGE = "Interface\\Icons\\INV_Staff_13",
        WARLOCK = "Interface\\Icons\\INV_Staff_30",
        DRUID = "Interface\\Icons\\Ability_Druid_Maul",
    }
    return icons[(class or "WARRIOR"):upper()] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Utils:GetSpecInfo(class, specName)
    if not specName or specName == "" then return nil end
    local data = RLSuite.classData and RLSuite.classData[(class or ""):upper()]
    if not data or not data.specs then return nil end
    local want = string.lower(specName)
    for _, spec in ipairs(data.specs) do
        if type(spec) == "table" then
            local name = string.lower(spec.name or "")
            if name == want then return spec end
        elseif type(spec) == "string" and string.lower(spec) == want then
            return {name = spec, role = "dps"}
        end
    end
    -- partial match: "feral" -> first feral*, "prot" -> protection
    for _, spec in ipairs(data.specs) do
        if type(spec) == "table" then
            local name = string.lower(spec.name or "")
            if string.find(name, want, 1, true) or string.find(want, name, 1, true) then
                return spec
            end
        end
    end
    return nil
end

function Utils:SpecIcon(class, specName)
    local info = self:GetSpecInfo(class, specName)
    if info and info.icon then return info.icon end
    return self:ClassIcon(class)
end

function Utils:RoleFromSpec(class, specName)
    local info = self:GetSpecInfo(class, specName)
    if info and info.role then return info.role end
    return nil
end

function Utils:SpecShortName(class, specName)
    local info = self:GetSpecInfo(class, specName)
    if info and info.short then return info.short end
    return specName or ""
end

function Utils:NormalizeRole(role, class, spec)
    if role == "mdps" or role == "rdps" or role == "tank" or role == "healer" then
        return role
    end
    local fromSpec = self:RoleFromSpec(class, spec)
    if fromSpec then return fromSpec end
    if role == "dps" then return "mdps" end
    return role or "mdps"
end

function Utils:EnsureInsertLinkHook()
    if self._insertLinkHooked then return end
    self._insertLinkHooked = true
    self.insertLinkTargets = self.insertLinkTargets or {}
    local orig = ChatEdit_InsertLink
    ChatEdit_InsertLink = function(text)
        for _, t in ipairs(Utils.insertLinkTargets) do
            local edit = t.edit
            if text and edit and edit.IsShown and edit:IsShown() and edit.HasFocus and edit:HasFocus() then
                if edit.Insert then
                    edit:Insert(text)
                else
                    edit:SetText((edit:GetText() or "") .. text)
                end
                if t.onInsert then t.onInsert(text) end
                return true
            end
        end
        if orig then return orig(text) end
    end
end

function Utils:RegisterInsertLink(edit, onInsert)
    if not edit then return end
    self:EnsureInsertLinkHook()
    self.insertLinkTargets = self.insertLinkTargets or {}
    table.insert(self.insertLinkTargets, {edit = edit, onInsert = onInsert})
end

function Utils:ClassLabel(class)
    local labels = {
        WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
        ROGUE = "Rogue", PRIEST = "Priest", DEATHKNIGHT = "DK",
        SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
    }
    return labels[(class or ""):upper()] or class or "?"
end

-- ============================================================
-- Dropdown (3.3.5, no Ace)
-- ============================================================

-- ============================================================
-- Window skin (opaque backgrounds for 3.3.5)
-- DialogBox-Background is mostly transparent; ChatFrameBackground is solid.
-- ============================================================

function Utils:ThemePresets()
    return {
        default = { fill = {0.05, 0.05, 0.07, 1}, bg = {0.08, 0.08, 0.10, 1}, border = {0.70, 0.70, 0.70, 1} },
        dark    = { fill = {0.02, 0.02, 0.04, 1}, bg = {0.04, 0.04, 0.06, 1}, border = {0.40, 0.40, 0.48, 1} },
        gold    = { fill = {0.10, 0.07, 0.01, 1}, bg = {0.12, 0.09, 0.02, 1}, border = {0.85, 0.70, 0.20, 1} },
    }
end

function Utils:ColorToArray(c)
    if not c then return {0.08, 0.08, 0.10, 1} end
    if c.r then return {c.r, c.g, c.b, c.a or 1} end
    return {c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1}
end

function Utils:GetThemeColors(theme)
    local a = RLSuiteDB and RLSuiteDB.appearance or {}
    if a.bg and a.bg.r then
        return {
            fill = self:ColorToArray(a.fill),
            bg = self:ColorToArray(a.bg),
            border = self:ColorToArray(a.border),
        }
    end
    theme = theme or a.theme or "default"
    return self:ThemePresets()[theme] or self:ThemePresets().default
end

function Utils:GetUIFont()
    local a = RLSuiteDB and RLSuiteDB.appearance or {}
    return a.font or "Fonts\\FRIZQT__.TTF", a.fontSize or 12
end

function Utils:WindowBackdrop(f)
    -- Tooltip border sits on the frame edge. insets 0 = fill goes to that same edge.
    local edge = 16
    if RLSuiteDB and RLSuiteDB.appearance and RLSuiteDB.appearance.edgeSize then
        edge = RLSuiteDB.appearance.edgeSize
    end
    if edge > 16 then edge = 16 end
    if edge < 8 then edge = 8 end
    if f and f.GetWidth then
        local w, h = f:GetWidth() or 200, f:GetHeight() or 200
        local minSide = math.min(w, h)
        if minSide < 80 and edge > 10 then edge = 10 end
    end
    return {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = edge,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    }
end

function Utils:SkinMacroButton(btn)
    if not btn then return end
    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    local c = self:GetThemeColors()
    btn:SetBackdropColor(0.10, 0.10, 0.12, 1)
    btn:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)

    if not btn.slotBg then
        btn.slotBg = btn:CreateTexture(nil, "BACKGROUND")
        btn.slotBg:SetDrawLayer("BACKGROUND", 1)
    end
    btn.slotBg:SetTexture("Interface\\Buttons\\UI-Quickslot")
    btn.slotBg:ClearAllPoints()
    btn.slotBg:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    btn.slotBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.slotBg:SetVertexColor(0.9, 0.9, 0.9, 1)
    btn.slotBg:Show()

    if not btn.slotBorder then
        btn.slotBorder = btn:CreateTexture(nil, "BORDER")
        btn.slotBorder:SetDrawLayer("BORDER", 7)
    end
    btn.slotBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    btn.slotBorder:ClearAllPoints()
    btn.slotBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", -8, 8)
    btn.slotBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 8, -8)
    btn.slotBorder:Show()

    if btn.icon then
        btn.icon:SetDrawLayer("ARTWORK", 0)
        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
        btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if btn.highlight then
        btn.highlight:ClearAllPoints()
        btn.highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        btn.highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
    if btn.pushed then
        btn.pushed:ClearAllPoints()
        btn.pushed:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        btn.pushed:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
end

function Utils:SkinFrame(f)
    if not f or not f.SetBackdrop then return end
    local c = self:GetThemeColors()
    f:SetAlpha(1)
    if f.rlsBgFill then
        f.rlsBgFill:Hide()
    end
    f:SetBackdrop(self:WindowBackdrop(f))
    f:SetBackdropColor(c.fill[1], c.fill[2], c.fill[3], 1)
    f:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
end

function Utils:AllWindows()
    local list = {}
    local function add(fr)
        if fr then table.insert(list, fr) end
    end
    add(RLSuite.mainWindow and RLSuite.mainWindow.frame)
    add(RLSuite.macrobar and RLSuite.macrobar.keypadFrame)
    add(RLSuite.macrobar and RLSuite.macrobar.editFrame)
    add(RLSuite.raidFrame and RLSuite.raidFrame.frame)
    return list
end

function Utils:AllTabPanes()
    local list = {}
    local function add(fr)
        if fr then table.insert(list, fr) end
    end
    add(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame)
    add(RLSuite.groupmaking and RLSuite.groupmaking.whisplistFrame)
    add(RLSuite.msManager and RLSuite.msManager.frame)
    add(RLSuite.lootManager and RLSuite.lootManager.frame)
    add(RLSuite.config and RLSuite.config.frame)
    if RLSuite.mainWindow and RLSuite.mainWindow.tabPanels then
        add(RLSuite.mainWindow.tabPanels.macro)
        add(RLSuite.mainWindow.tabPanels.raidframe)
    end
    return list
end

function Utils:AllDockedPanels()
    local list = {}
    local function add(fr)
        if fr then table.insert(list, fr) end
    end
    add(RLSuite.config and RLSuite.config.left)
    add(RLSuite.config and RLSuite.config.right)
    return list
end

function Utils:SkinBox(box)
    if not box or not box.SetBackdrop then return end
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    local c = self:GetThemeColors()
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
end

function Utils:SkinRow(row, selected)
    if not row or not row.SetBackdrop then return end
    row:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    if selected then
        row:SetBackdropColor(0.25, 0.18, 0.02, 0.95)
        row:SetBackdropBorderColor(0.85, 0.70, 0.20, 1)
    else
        row:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        row:SetBackdropBorderColor(0.45, 0.45, 0.48, 1)
    end
end

function Utils:SkinAllWindows()
    for _, fr in ipairs(self:AllWindows()) do
        self:SkinFrame(fr)
    end
    for _, fr in ipairs(self:AllTabPanes()) do
        if fr.rlsBgFill then fr.rlsBgFill:Hide() end
        self:SkinFrame(fr)
    end
    for _, fr in ipairs(self:AllDockedPanels()) do
        if fr.rlsBgFill then fr.rlsBgFill:Hide() end
        self:SkinBox(fr)
    end
    if RLSuite.lootManager and RLSuite.lootManager.SkinInner then
        RLSuite.lootManager:SkinInner()
    end
    if RLSuite.groupmaking and RLSuite.groupmaking.SkinInner then
        RLSuite.groupmaking:SkinInner()
    end
    if RLSuite.msManager and RLSuite.msManager.SkinInner then
        RLSuite.msManager:SkinInner()
    end
    if RLSuite.mainWindow and RLSuite.mainWindow.SkinInner then
        RLSuite.mainWindow:SkinInner()
    end
end

function Utils:CloseDropdownMenu()
    if self.dropCatcher then self.dropCatcher:Hide() end
    if self.activeMenu then
        self.activeMenu:Hide()
        self.activeMenu = nil
    end
end

function Utils:CreateDropdown(parent, name, width, height)
    local dd = CreateFrame("Frame", name, parent)
    dd:SetSize(width, height)
    dd:EnableMouse(true)
    dd:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left=0, right=0, top=0, bottom=0}
    })
    dd:SetBackdropColor(0.05, 0.05, 0.07, 1)
    dd.text = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dd.text:SetPoint("LEFT", dd, "LEFT", 5, 0)
    dd.text:SetPoint("RIGHT", dd, "RIGHT", -18, 0)
    dd.text:SetJustifyH("LEFT")
    dd.text:SetText("...")

    dd.button = CreateFrame("Button", nil, dd)
    dd.button:SetSize(16, 16)
    dd.button:SetPoint("RIGHT", dd, "RIGHT", -2, 0)
    dd.button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    dd.button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    dd.button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    dd.options = {}
    dd.value = nil
    dd.onSelect = nil

    local function toggle()
        Utils:ToggleDropdownMenu(dd)
    end
    dd:SetScript("OnMouseUp", toggle)
    dd.button:SetScript("OnClick", toggle)
    return dd
end

function Utils:SetupDropdown(dd, options, currentValue, onSelect)
    local normalized = {}
    for _, o in ipairs(options or {}) do
        if type(o) == "table" then
            table.insert(normalized, {text = o.text or tostring(o.value), value = o.value})
        else
            table.insert(normalized, {text = tostring(o), value = o})
        end
    end
    dd.options = normalized
    dd.onSelect = onSelect

    local found
    for _, o in ipairs(normalized) do
        if o.value == currentValue or o.text == currentValue then
            found = o
            break
        end
    end
    if found then
        dd.value = found.value
        dd.text:SetText(found.text)
    elseif currentValue then
        dd.value = currentValue
        dd.text:SetText(tostring(currentValue))
    elseif normalized[1] then
        dd.value = normalized[1].value
        dd.text:SetText(normalized[1].text)
    end
end

function Utils:ToggleDropdownMenu(dd)
    if self.activeMenu and self.activeMenu.owner == dd then
        self:CloseDropdownMenu()
        return
    end
    self:CloseDropdownMenu()

    local options = dd.options or {}
    if #options == 0 then return end

    if not self.dropCatcher then
        local catcher = CreateFrame("Button", "RLSuiteDropCatcher", UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        catcher:SetFrameLevel(1)
        catcher:SetScript("OnClick", function() Utils:CloseDropdownMenu() end)
        self.dropCatcher = catcher
    end
    self.dropCatcher:Show()
    self.dropCatcher:SetFrameLevel(1)

    local menu = CreateFrame("Frame", "RLSuiteDropMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(10)
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left=0, right=0, top=0, bottom=0}
    })
    menu:SetBackdropColor(0.05, 0.05, 0.07, 1)
    menu.owner = dd
    local width = math.max(dd:GetWidth(), 80)
    menu:SetSize(width, #options * 20 + 8)
    menu:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)

    for i, opt in ipairs(options) do
        local btn = CreateFrame("Button", nil, menu)
        btn:SetSize(width - 8, 18)
        btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 20)
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetAllPoints(btn)
        txt:SetJustifyH("LEFT")
        txt:SetText(opt.text)
        if dd.value == opt.value then
            txt:SetTextColor(1, 0.82, 0)
        end
        btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        btn:SetScript("OnClick", function()
            dd.value = opt.value
            dd.text:SetText(opt.text)
            Utils:CloseDropdownMenu()
            if dd.onSelect then
                dd.onSelect(opt.value, opt.text)
            end
        end)
    end

    self.activeMenu = menu
end
