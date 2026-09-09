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
    channel = channel or "RAID"
    if channel == "RAID_WARNING" and not IsRaidLeader() and not IsRaidOfficer() then
        channel = "RAID"
    end
    SendChatMessage(msg, channel)
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

-- ============================================================
-- Dropdown (3.3.5, no Ace)
-- ============================================================

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
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left=2, right=2, top=2, bottom=2}
    })
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
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left=2, right=2, top=2, bottom=2}
    })
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
