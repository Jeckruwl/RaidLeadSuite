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

function Utils:GetItemLinkFromChat(text)
    return text:match("(item:%d+:%d+:%d+:%d+)")
end

function Utils:ClassIcon(class)
    local icons = {
        WARRIOR = "Interface\Icons\INV_Sword_04",
        PALADIN = "Interface\Icons\INV_Hammer_01",
        HUNTER = "Interface\Icons\INV_Weapon_Bow_07",
        ROGUE = "Interface\Icons\INV_ThrowingKnife_04",
        PRIEST = "Interface\Icons\INV_Staff_30",
        DEATHKNIGHT = "Interface\Icons\Spell_Deathknight_ClassIcon",
        SHAMAN = "Interface\Icons\INV_Jewelry_Talisman_04",
        MAGE = "Interface\Icons\INV_Staff_13",
        WARLOCK = "Interface\Icons\INV_Staff_30",
        DRUID = "Interface\Icons\Ability_Druid_Maul",
    }
    return icons[(class or "WARRIOR"):upper()] or "Interface\Icons\INV_Misc_QuestionMark"
end
