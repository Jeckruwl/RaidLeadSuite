-- ============================================================
-- RLSuite - Utils
-- ============================================================

RLSuite = RLSuite or {}
RLSuite.utils = {}
local Utils = RLSuite.utils

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

-- ICONE DA FILE media/*.tga: i TGA dell'addon (BCI_*, save.tga, ecc.)
-- hanno SEMPRE reso nel client — formato identico generato per le nostre
-- X e freccia (32x32, 32bpp, type 2, descriptor 0x28, 4114 byte). Disegno
-- via TEXTURE esplicite ARTWORK + HIGHLIGHT (pattern della minimappa/BCI,
-- che RENDE SEMPRE): mai SetNormalTexture/SetHighlightTexture su bottoni.
-- Path SEMPRE via AddonTexture (folder RLSuite|RaidLeadSuite).
function Utils:ApplyIcon(btn, iconRel)
    local tx = RLSuite:AddonTexture(iconRel)
    local t = btn:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(btn)
    t:SetTexture(tx)
    btn.icon = t
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetTexture(tx)
    hl:SetBlendMode("ADD")
    btn.hl = hl
    btn._iconPath = tx
    return btn
end

-- Bottone icona da file, completo: dimensione w x h, highlight glow.
function Utils:MakeIconButton(parent, iconRel, w, h, onclick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 22, h or w or 22)
    b:SetBackdrop(nil)
    Utils:ApplyIcon(b, iconRel)
    if onclick then
        b:EnableMouse(true)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", onclick)
    end
    return b
end

-- X bianca (TGA) per CHIUDERE le finestre: usata da TUTTE le finestre.
function Utils:MakeCloseX(parent, onclick)
    return Utils:MakeIconButton(parent, "media\\close.tga", 11, 11, onclick)
end

function Utils:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[RLSuite]|r " .. tostring(msg))
end

function Utils:Debug(msg)
    if RLSuite.db and RLSuite.db.profile.debug then
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

-- Protegge SendChatMessage (3.3.5): una "|" non seguita da una sequenza di
-- escape valida (|c colore, |H..|h link oggetti/incantesimi, |T..|t texture,
-- |r reset, |n newline, |1..|4 forme grammaticali, || pipe letterale) fa
-- scattare "Invalid escape code in chat message". Raddoppia solo le pipe
-- "orfane", lasciando intatti i link degli oggetti (|c..|H..|h..|r).
function Utils:SanitizeChat(text)
    if type(text) ~= "string" then return text end
    local valid = { c=true, C=true, r=true, R=true, h=true, H=true, t=true, T=true,
                    n=true, N=true, ["1"]=true, ["2"]=true, ["3"]=true, ["4"]=true,
                    ["|"]=true }
    local out = {}
    local i = 1
    while i <= #text do
        local c = text:sub(i, i)
        if c == "|" then
            local nxt = text:sub(i + 1, i + 1)
            if nxt ~= "" and valid[nxt] then
                out[#out + 1] = "|"
                out[#out + 1] = nxt
                i = i + 2
            else
                out[#out + 1] = "||"
                i = i + 1
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end

function Utils:SendChat(msg, channel)
    if not msg or msg == "" then return end
    channel = channel or "RAID"
    msg = self:SanitizeChat(msg)
    if RLSuite.db and RLSuite.db.profile.debug then
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
    msg = self:SanitizeChat(msg)
    local dest = name
    if RLSuite.db and RLSuite.db.profile.debug then
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
    local a = RLSuite.db and RLSuite.db.profile.appearance or {}
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
    local a = RLSuite.db and RLSuite.db.profile.appearance or {}
    return a.font or "Fonts\\FRIZQT__.TTF", a.fontSize or 12
end

function Utils:WindowBackdrop(f)
    -- Tooltip border sits on the frame edge. insets 0 = fill goes to that same edge.
    local edge = 16
    if RLSuite.db and RLSuite.db.profile.appearance and RLSuite.db.profile.appearance.edgeSize then
        edge = RLSuite.db.profile.appearance.edgeSize
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
    -- Le finestre marcate _noOuterBorder (main bar, Groupmaking, Invite
    -- engine, MS Manager, Loot Manager) non hanno il bordo esterno del
    -- dialog: il riempimento resta, il Tooltip-Border diventa invisibile.
    if f._noOuterBorder then
        f:SetBackdropBorderColor(0, 0, 0, 0)
    else
        f:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
    end
end

function Utils:AllWindows()
    local list = {}
    local function add(fr)
        if fr then table.insert(list, fr) end
    end
    add(RLSuite.mainWindow and RLSuite.mainWindow.frame)
    add(RLSuite.macrobar and RLSuite.macrobar.keypadFrame)
    add(RLSuite.macrobar and RLSuite.macrobar.editFrame)
    -- Il Raid Frame HUD non viene mai skinnato: nessuno sfondo/bordo.
    return list
end

function Utils:AllTabPanes()
    local list = {}
    local function add(fr)
        if fr then table.insert(list, fr) end
    end
    add(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame)
    add(RLSuite.msManager and RLSuite.msManager.frame)
    add(RLSuite.lootManager and RLSuite.lootManager.frame)
    return list
end

function Utils:AllDockedPanels()
    -- The Config surface is now a self-contained AceGUI window (not a
    -- docked tab pane with inner panels), so there is nothing to skin.
    return {}
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

-- Skin ACE per TUTTI i bottoni di dialogo dell'addon: NIENTE piu' grafica
-- di default Blizzard (grigio UIPanelButtonTemplate); al suo posto il look
-- piatto scuro coerente con le finestre skinnate/AceGUI: sfondo scuro,
-- bordo tooltip fine, bordo DORATO in hover (come le righe selezionate).
function Utils:SkinButton(btn)
    if not btn then return end
    if btn.SetNormalTexture then
        btn:SetNormalTexture(nil)
        if btn.SetPushedTexture then btn:SetPushedTexture(nil) end
        if btn.SetDisabledTexture then btn:SetDisabledTexture(nil) end
    end
    if btn.SetHighlightTexture then
        btn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        local ht = btn.GetHighlightTexture and btn:GetHighlightTexture()
        if ht and ht.SetVertexColor then ht:SetVertexColor(1, 1, 1, 0.08) end
    end
    -- BOTTONI BORDERLESS: niente piu' il bordo "dialog" (UI-Tooltip-Border)
    -- su alcun pulsante dell'addon. Resta il fill scuro; l'hover schiarisce
    -- il riempimento invece di accendere un bordo.
    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        btn:SetBackdropColor(0.16, 0.18, 0.22, 0.95)
    end
    if btn.HookScript then
        btn:HookScript("OnEnter", function(s)
            if s.SetBackdropColor then s:SetBackdropColor(0.26, 0.29, 0.36, 0.98) end
        end)
        btn:HookScript("OnLeave", function(s)
            if s.SetBackdropColor then s:SetBackdropColor(0.16, 0.18, 0.22, 0.95) end
        end)
    end
end

function Utils:SkinRow(row, selected)
    if not row or not row.SetBackdrop then return end
    -- Anche le righe-lista (pulsanti) sono borderless: la selezione non si
    -- affida piu' al bordo oro ma a un riempimento caldo ben piu' marcato.
    row:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    if selected then
        row:SetBackdropColor(0.34, 0.26, 0.06, 0.98)
    else
        row:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
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

-- Richiesta esplicita: niente cadaveri invisibili sopra i moduli.
function Utils:AssertNoZombieCatcher()
    if self.dropCatcher and self.dropCatcher:IsShown() and not (self.activeMenu and self.activeMenu:IsShown()) then
        self:CloseDropdownMenu()
    end
end

-- ============================================================
-- Scroll clip di INPUT (bug "fstack LootManager"): in 3.3.5 lo scroll
-- clippa solo la GRAFICA. Una riga-Bottone (EnableMouse + click) dello
-- scroll-child fuori dal viewport resta INVISIBILE ma hit-testabile
-- sopra l'intera finestra e ruba i click a tutto il resto. Con tante
-- entry il contenuto diventa alto quanto l'intera UI: "a volte non
-- riesco a cliccare nulla nel Loot Manager".
-- Rimediato in modo generico: le righe che escono dal viewport vengono
-- NASCOSTE (Hide = niente grafica e niente input; la geometria del
-- contenuto non cambia, quindi lo scroll resta identico).
--
-- Uso:
--   1) Utils:RegisterScrollClip(scroll, content) una tantum
--   2) Utils:ClearScrollClip(content) all'inizio di ogni rebuild righe
--   3) Utils:ClipScrollRow(content, row, topOffset, height) per riga
--   4) Utils:RefreshScrollClip(content) alla fine del rebuild
-- ============================================================
function Utils:RegisterScrollClip(scroll, content)
    if not scroll or not content then return end
    content._rlsScrollClip = { scroll = scroll, rows = {} }
    local function refresh()
        Utils:RefreshScrollClip(content)
    end
    scroll:HookScript("OnVerticalScroll", refresh)
    scroll:HookScript("OnMouseWheel", refresh)
    scroll:HookScript("OnSizeChanged", refresh)
end

function Utils:ClearScrollClip(content)
    if content and content._rlsScrollClip then
        content._rlsScrollClip.rows = {}
    end
end

function Utils:ClipScrollRow(content, row, topOffset, h)
    local st = content and content._rlsScrollClip
    if not st or not row then return end
    st.rows[#st.rows + 1] = { row = row, top = topOffset or 0, h = h or 0 }
end

function Utils:RefreshScrollClip(content)
    local st = content and content._rlsScrollClip
    if not st then return end
    local off = (st.scroll.GetVerticalScroll and st.scroll:GetVerticalScroll()) or 0
    local vh = (st.scroll.GetHeight and st.scroll:GetHeight()) or 0
    if vh < 1 then
        -- dimensione non ancora nota: mostra tutto (comportamento pre-fix)
        return
    end
    for _, r in ipairs(st.rows) do
        local vis = (r.top < off + vh) and (r.top + r.h > off)
        if vis then r.row:Show() else r.row:Hide() end
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
    -- Guardia "pannello invisibile" (fstack): il catcher a tutto schermo e
    -- il menu NON devono mai sopravvivere alla propria finestra. Quando la
    -- finestra (o il dropdown stesso) viene nascosta senza che il menu sia
    -- stato chiuso, forza la chiusura: senza questa rete il cadavere del
    -- catcher restava sopra TUTTO e rubava i click a tutta la UI. Vale per
    -- TUTTI i moduli, perche' usano tutti questo CreateDropdown.
    dd:SetScript("OnHide", function()
        if Utils.activeMenu and Utils.activeMenu.owner == dd then
            Utils:CloseDropdownMenu()
        elseif Utils.dropCatcher and Utils.dropCatcher:IsShown() and Utils.activeMenu == nil then
            -- catcher zombie senza menu: ugualmente chiuso
            Utils:CloseDropdownMenu()
        end
    end)
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
        catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        catcher:SetScript("OnClick", function() Utils:CloseDropdownMenu() end)
        self.dropCatcher = catcher
    end
    self.dropCatcher:Show()
    self.dropCatcher:SetFrameLevel(1)

    -- Riutilizza il menu del dropdown: CREARE un frame nuovo a ogni toggle
    -- (tra l'altro sempre con lo stesso nome globale) lasciava cadaveri in
    -- giro per la UI (memoria + incertezze sullo z-order/FX dell'fstack).
    local menu = dd._rlsDropMenu or CreateFrame("Frame", "RLSuiteDropMenu", UIParent)
    dd._rlsDropMenu = menu
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(10)
    -- Se il menu svanisce per QUALUNQUE ragione (finestra padre nascosta,
    -- cambio tab, /rls, Hide diretto), IL CATCHER MUORE SEMPRE CON LUI:
    -- e' l'unica difesa affidabile contro lo zombie full-screen invisibile
    -- che "copre tutta la finestra" e blocca ogni click (il bug fstack).
    menu:SetScript("OnHide", function()
        if Utils.dropCatcher and Utils.dropCatcher:IsShown() then
            Utils.dropCatcher:Hide()
        end
        if Utils.activeMenu == menu then
            Utils.activeMenu = nil
        end
    end)
    -- pulisce i vecchi pulsanti-opzione del rebuild precedente
    if menu.optionButtons then
        for _, ob in ipairs(menu.optionButtons) do ob:Hide() end
    end
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

    -- Se qualsiasi finestra/pannello che OSPITA il dropdown si nasconde,
    -- kill immediato del menu (di killing cascata dal hook 2 anche il catcher).
    local anc = dd
    local hops = 0
    while anc and anc ~= UIParent and hops < 8 do
        if anc.HookScript and not anc._rlsDropMenuKillHook then
            anc._rlsDropMenuKillHook = true
            anc:HookScript("OnHide", function()
                Utils:CloseDropdownMenu()
            end)
        end
        anc = anc.GetParent and anc:GetParent()
        hops = hops + 1
    end

    menu.optionButtons = {}
    for i, opt in ipairs(options) do
        local btn = CreateFrame("Button", nil, menu)
        menu.optionButtons[i] = btn
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

-- ============================================================
-- Window layout helpers (finestre staccabili / anchors)
-- ============================================================

-- Ritorna (creandola se serve) la sottotabella layout per una finestra.
function Utils:WindowLayout(key)
    RLSuite.db.profile.layout = RLSuite.db.profile.layout or {}
    local t = RLSuite.db.profile.layout[key]
    if not t then
        t = {}
        RLSuite.db.profile.layout[key] = t
    end
    return t
end

-- Salva la posizione corrente di un frame nella layout della finestra.
function Utils:PersistFramePos(frame, key)
    if not frame then return end
    local point, _, relPoint, x, y = frame:GetPoint()
    local L = self:WindowLayout(key)
    L.point = point
    L.relPoint = relPoint
    L.x = x
    L.y = y
end

-- Applica la posizione salvata a una finestra; se non c'e', la ancora
-- sotto la barra principale (comportamento dock-like iniziale) e, se
-- passata, applica un offset a cascata per non sovrapporre le finestre.
-- NOTA: SetPoint(point, relativeTo, relativePoint, x, y): relativeTo
-- deve essere un frame (o il suo nome), relativePoint un punto valido.
function Utils:ApplySavedPos(frame, key, cascadeOffset)
    if not frame then return end
    frame:ClearAllPoints()
    local L = self:WindowLayout(key)
    if L.point then
        frame:SetPoint(L.point, UIParent, L.relPoint or L.point, L.x or 0, L.y or 0)
    else
        local dx, dy = 0, 0
        if type(cascadeOffset) == "function" then
            dx, dy = cascadeOffset()
        end
        local bar = RLSuite.mainWindow and RLSuite.mainWindow.frame
        if bar then
            frame:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", dx, -2 + dy)
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
        end
    end
end

-- Riporta una finestra dentro lo schermo: clamp della dimensione (mai
-- piu' grande dello schermo, in coordinate della scala effettiva) e
-- riposizionamento se un angolo finisce fuori vista. Serve per
-- auto-sanare i salvataggi rovinati (es. dimensioni enormi registrate
-- mentre il vecchio StartSizing litigava con il clamp dello schermo).
function Utils:ClampWindowToScreen(frame)
    if not frame or not (GetScreenWidth and GetScreenHeight) then return end
    local scale = frame:GetEffectiveScale() or 1
    local sw = (GetScreenWidth() or 0) / scale
    local sh = (GetScreenHeight() or 0) / scale
    if sw <= 0 or sh <= 0 then return end
    local w = frame:GetWidth() or 0
    local h = frame:GetHeight() or 0
    if w > sw or h > sh then
        w = math.min(w, sw)
        h = math.min(h, sh)
        frame:SetSize(w, h)
    end
    local left = frame.GetLeft and frame:GetLeft()
    local top = frame.GetTop and frame:GetTop()
    if type(left) == "number" and type(top) == "number" then
        local newLeft = left
        if left < 0 then newLeft = 0 elseif left + w > sw then newLeft = math.max(0, sw - w) end
        local newTop = top
        if top > sh then newTop = sh elseif top - h < 0 then newTop = h end
        if newLeft ~= left or newTop ~= top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newLeft, newTop)
        end
    end
end

-- Porta una finestra in primo piano sopra le altre (stessa strata).
-- Assegna un frame level esplicito e distanziato (passo 50): cosi' i
-- figli con frameLevel relativo (+5..+20: grip di resize, editbox, ecc.)
-- restano dentro la "fascia" della loro finestra e non sbucano sopra le
-- finestre vicine, evitando le sovrapposizioni parziali (parti di una
-- finestra sopra e parti sotto un'altra) quando si spostano le finestre.
-- Riposiziona deterministicamente i livelli di un intero sotto-albero:
-- base = livello corrente del root; ogni figlio prende base+2+2*indice
-- (ordine di CREAZIONE dei figli, stesso ordine del drawing WoW). Causa:
-- qualunque drift pregresso (refreshes + raises) viene cancellato.
function Utils:RepinFrameOrder(root, seenTbl)
    if not root or not root.GetChildren then return end
    local seen = seenTbl or {}
    if seen[root] then return end
    seen[root] = true
    local base = root.GetFrameLevel and root:GetFrameLevel() or 0
    local ok, kids = pcall(function() return { root:GetChildren() } end)
    if not ok or not kids then return end
    for i, kid in ipairs(kids) do
        if kid.SetFrameLevel then
            kid:SetFrameLevel(base + 2 + 2 * i)
        end
        Utils:RepinFrameOrder(kid, seen)
    end
end

local function ShiftSubtree(node, delta, seen)
    -- Sposta il frame E tutta la gerarchia dei figli dello stesso delta:
    -- i livelli 3.3.5 NON ereditano, quindi senza questo shift i figli
    -- restano sotto e l'hit-test finisce sulla finestra invece che sui
    -- bottoni (il bug "le righe del loot manager non ricevono i click").
    if type(node) ~= "table" or seen[node] then return end
    seen[node] = true
    if node.GetFrameLevel and node.SetFrameLevel then
        local lvl = node:GetFrameLevel()
        if lvl then
            local nl = lvl + delta
            if nl < 0 then nl = 0 end
            node:SetFrameLevel(nl)
        end
    end
    if node.GetChildren then
        local ok, kids = pcall(function() return { node:GetChildren() } end)
        if ok and type(kids) == "table" then
            for i = 1, #kids do ShiftSubtree(kids[i], delta, seen) end
        end
    end
end

-- NPC id dal GUID. Formato 3.3.5 (esadecimale, high "F1xx": l'entry sta nei
-- char 9-12, es. 0xF130008F040000AA -> 0x8F04 = 36612 Lord Marrowgar) oppure
-- formato moderno "Creature-0-...-ID-spawnID" (6o campo). Implementazione
-- UNICA: la usano il Combat Log (nomi dei pull, kill/wipe) e il
-- riconoscimento del boss in corso per le macro in-fight.
function Utils:NpcIdFromGUID(guid)
    if type(guid) ~= "string" or guid == "" then return nil end
    if guid:find("-", 1, true) then
        local parts = { strsplit("-", guid) }
        return tonumber(parts[6])
    end
    if guid:sub(3, 4) == "F1" then
        return tonumber(guid:sub(9, 12), 16)
    end
    return nil
end

-- Riporta un sotto-albero a una posizione di livello PREVEDIBILE rispetto a
-- un riferimento (es. il genitore o la finestra). Se il root si e' allontanato
-- oltre la tolleranza, sposta TUTTO il sotto-albero dello stesso delta: nessun
-- rinumero, quindi l'ordine interno (che in gioco funziona) resta identico.
-- Causa: in 3.3.5 i livelli dei figli non seguono il padre, e dopo ripetuti
-- raise/rebuild una catena puo' restare centinaia di livelli fuori posto
-- (fstack: RLSuiteWLScroll <700> sopra la finestra <200>) e mangiarsi i click.
-- Restituisce true se ha corretto il livello.
function Utils:RealignSubtreeLevel(root, wantLvl, tol)
    if not (root and root.GetFrameLevel and root.SetFrameLevel) then return false end
    if wantLvl == nil then return false end
    tol = tol or 20
    local cur = root:GetFrameLevel() or wantLvl
    local d = wantLvl - cur
    if d < 0 then d = -d end
    if d <= tol then return false end
    ShiftSubtree(root, wantLvl - cur, {})
    return true
end

function Utils:RaiseWindow(frame)
    if not frame then return end
    -- Layering NORMALIZZATO: niente contatore globale +50 a click (livelli
    -- a casaccio). Lo stack delle finestre RLSuite e' ordinato per recency
    -- e a ogni raise i livelli vengono ri-normalizzati a valori piccoli e
    -- stabili (slot da 40, abbastanza ampi per il sotto-albero).
    RLSuite._windowStack = RLSuite._windowStack or {}
    local stack = RLSuite._windowStack
    local found = nil
    for i = 1, #stack do
        if stack[i] == frame then found = i break end
    end
    if found then table.remove(stack, found) end
    stack[#stack + 1] = frame
    local seen = {}
    for idx = 1, #stack do
        local w = stack[idx]
        if type(w) == "table" and w.GetFrameLevel then
            local target = 20 + 40 * idx
            -- Rebase LIVE dal livello reale della finestra (non dal valore
            -- memorizzato): se i contenuti della finestra sono stati
            -- ricostruiti nel frattempo, niente deriva negativa/divergente.
            local prev = w._rlsLevelBase or (w.GetFrameLevel and w:GetFrameLevel()) or 0
            local delta = target - prev
            w._rlsLevelBase = target
            w:SetFrameStrata("HIGH")
            if delta ~= 0 then
                ShiftSubtree(w, delta, seen)
            end
        end
    end
end

-- Clic su una finestra = portala in primo piano. Vale per i click che
-- arrivano al frame (sfondo/titolo): i bottoni figli continuano a fare
-- il loro lavoro. Preserva un eventuale OnMouseDown gia' presente.
function Utils:MakeClickToFront(frame)
    if not frame or frame._rlsFront then return end
    frame._rlsFront = true
    frame:EnableMouse(true)
    local old = frame:GetScript("OnMouseDown")
    frame:SetScript("OnMouseDown", function(self2, button)
        Utils:RaiseWindow(frame)
        if old then old(self2, button) end
    end)
end

-- Impedisce che una finestra venga trascinata (o ridimensionata) fuori
-- dallo schermo: Blizzard riporta il frame dentro UIParent a ogni drag.
-- Vale anche per i pannelli ancorati (es. la costola InviteEngine).
function Utils:ClampWindow(frame)
    if not frame then return end
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end
end

-- Finestra UNIVERSALE come tutte le altre: MakeDraggable + stesso layer
-- finale + BORDO tematico (ricostruito da SkinFrame con _noOuterBorder
-- OFF). Tutte le finestre dell'addon sono cosi': il riush non esce mai
-- dallo schermo (SetClampedToScreen + guard) ed e' SARIAMO come le altre.
function Utils:MakeUniversalWindow(frame, key)
    self:MakeDraggable(frame, key)
    self:MakeClickToFront(frame)
    self:SkinFrameBordered(frame)
    return frame
end

function Utils:SkinFrameBordered(frame)
    if not frame then return end
    frame._noOuterBorder = nil
    self:SkinFrame(frame)
end

-- Rende un frame trascinabile e salva la posizione nel layout.
-- NOTA: non sovrascrive script gia' presenti: si aggancia solo se il
-- frame non ha gia' un comportamento di trascinamento registrato.
function Utils:MakeDraggable(frame, key)
    if not frame then return end
    if frame._rlsDraggable then return end
    frame._rlsDraggable = true
    frame:SetMovable(true)
    frame:EnableMouse(true)
    self:ClampWindow(frame)
    -- Guard anti-bug 3.3.5: SetClampedToScreen NON clamp nella scala <=/ >
    -- (i frame scalati possono uscire dallo schermo durante il drag).
    -- Mentre il drag e' attivo, ogni frame riporta la finestra nei bordi
    -- (clamp scale-aware: GetLeft/GetTop / EffectiveScale) — IDENTICO per
    -- OGNI finestra dell'addon, main bar compresa.
    local guard = CreateFrame("Frame")
    guard:Hide()
    guard:SetScript("OnUpdate", function()
        Utils:ClampWindowToScreen(frame)
    end)
    frame._rlsDragGuard = guard
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self2)
        Utils:RaiseWindow(frame)
        guard:Show()
        self2:StartMoving()
    end)
    local function dragStop(self2)
        guard:Hide()
        self2:StopMovingOrSizing()
        Utils:ClampWindowToScreen(self2)
        Utils:PersistFramePos(self2, key)
    end
    frame:SetScript("OnDragStop", dragStop)
    frame._rlsDragStop = dragStop
end

-- Grip di ridimensionamento in basso a destra. Salva width/height nel
-- layout e (se fornita) invoca la callback dopo il ridimensionamento.
-- I limiti minimi vengono ricalcolati a ogni drag da RLSuite.windowMins
-- (fallback: i valori minW/minH passati qui), cosi' la finestra non puo'
-- diventare piu' piccola del contenuto: SetMinResize blocca durante il
-- trascinamento e OnMouseUp ri-clampa a sicurezza.
function Utils:AddResizeGrip(frame, key, minW, minH, onResized)
    if not frame or frame._rlsGrip then return end
    minW = minW or 300
    minH = minH or 200
    frame._rlsGrip = true
    frame:SetResizable(true)
    local L = self:WindowLayout(key)

    local function currentMin()
        local fn = RLSuite.windowMins and RLSuite.windowMins[key]
        local mw, mh
        if fn then
            mw, mh = fn(frame)
        end
        if not mw or not (mw > 0) then mw = minW end
        if not mh or not (mh > 0) then mh = minH end
        return mw, mh
    end

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    grip:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    grip:EnableMouse(true)

    -- Resize CUSTOM (niente StartSizing): il ridimensionamento nativo
    -- calcola il delta dalle coordinate assolute del cursore e litiga con
    -- SetClampedToScreen: vicino ai bordi la finestra si gonfia a dimensioni
    -- enormi e il grip finisce fuori schermo. Qui il delta e' relativo alla
    -- posizione di partenza del mouse e la dimensione e' SEMPRE clampata
    -- dentro lo schermo (in coordinate della scala effettiva della finestra).
    local sizing = false
    local startW, startH, startCX, startCY, startMW, startMH
    local function finishResize()
        if not sizing then return end
        sizing = false
        local mw, mh = currentMin()
        local w = math.max(mw, frame:GetWidth() or mw)
        local h = math.max(mh, frame:GetHeight() or mh)
        frame:SetSize(w, h)
        L.width = w
        L.height = h
        if onResized then onResized(w, h) end
    end
    grip:SetScript("OnMouseDown", function(self2, button)
        if button ~= "LeftButton" then return end
        sizing = true
        startW = frame:GetWidth() or minW
        startH = frame:GetHeight() or minH
        startMW, startMH = currentMin()
        local scale = frame:GetEffectiveScale() or 1
        local cx, cy = GetCursorPosition()
        startCX = (cx or 0) / scale
        startCY = (cy or 0) / scale
    end)
    grip:SetScript("OnMouseUp", finishResize)
    grip:SetScript("OnUpdate", function()
        if not sizing then return end
        -- lo spostamento finisce anche se il rilascio avviene fuori grip
        if not IsMouseButtonDown("LeftButton") then
            finishResize()
            return
        end
        local scale = frame:GetEffectiveScale() or 1
        local cx, cy = GetCursorPosition()
        local w = startW + ((cx or 0) / scale - startCX)
        local h = startH - ((cy or 0) / scale - startCY)
        -- MAI oltre lo schermo (e oltre lo spazio restante a destra del
        -- bordo sinistro della finestra): niente piu' finestre enormi ne'
        -- grip trascinati fuori vista
        local sw = (GetScreenWidth() or 0) / scale
        local sh = (GetScreenHeight() or 0) / scale
        local left = (frame.GetLeft and frame:GetLeft()) or 0
        if sw > 0 then
            local wMax = sw - (left or 0)
            if wMax < sw then w = math.min(wMax, w) end
            w = math.min(sw, w)
        end
        if sh > 0 then h = math.min(sh, h) end
        frame:SetSize(math.max(startMW, w), math.max(startMH, h))
    end)
    return grip
end

-- Minimo attuale per una finestra, dalla tabella registrata in
-- RLSuite.windowMins (funzioni per-chiave che leggono il contenuto).
function Utils:WindowMin(key, frame)
    local fn = RLSuite.windowMins and RLSuite.windowMins[key]
    if not fn then return nil end
    local mw, mh = fn(frame)
    if mw and mw > 0 and mh and mh > 0 then
        return mw, mh
    end
    return nil
end

-- Allinea una finestra ridimensionabile ai suoi minimi: se la
-- dimensione attuale (o salvata) e' piu' piccola del contenuto,
-- la porta almeno al minimo. Ritorna mw, mh.
function Utils:EnforceWindowMin(frame, key)
    if not frame then return nil end
    local mw, mh = self:WindowMin(key, frame)
    if not mw then return nil end
    local w = math.max(mw, frame:GetWidth() or mw)
    local h = math.max(mh, frame:GetHeight() or mh)
    if w ~= frame:GetWidth() or h ~= frame:GetHeight() then
        frame:SetSize(w, h)
    end
    local L = self:WindowLayout(key)
    if L.width and L.width < mw then L.width = mw end
    if L.height and L.height < mh then L.height = mh end
    if frame.SetMinResize then
        frame:SetMinResize(mw, mh)
    end
    return mw, mh
end

-- Overlay "anchor" (bordo evidenziato) per le HUD quando si usa
-- toggle anchors in Config.
function Utils:SetAnchorVisual(frame, on)
    if not frame then return end
    if not frame.rlsAnchorBox then
        local box = CreateFrame("Frame", nil, frame)
        box:SetAllPoints(frame)
        box:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)
        box:EnableMouse(false)
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.25)
        box:SetBackdropBorderColor(1, 0.82, 0, 0.9)
        box:Hide()
        frame.rlsAnchorBox = box
    end
    if on then
        frame.rlsAnchorBox:Show()
    else
        frame.rlsAnchorBox:Hide()
    end
end

-- ============================================================
-- DBM / BigWigs: timer visibili (pull, MS changes, roll, ecc.)
-- ============================================================

-- Avvia una barra-timer in DBM se l'addon e' presente (fallback:
-- BigWigs). Non genera errori se nessuno dei due e' installato.
-- Ritorna true se il timer e' partito.
function Utils:StartDbmTimer(seconds, label, icon)
    if not seconds or seconds <= 0 then return false end
    label = label or "Timer"
    icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"

    if DBM then
        -- API pubblica "pizza timer" (DBM moderno e classico)
        local ok = pcall(DBM.CreatePizzaTimer, DBM, seconds, label, icon)
        if ok then return true end
        -- fallback: barre interne dei DBM piu' vecchi
        if DBM.Bars and DBM.Bars.CreateBar then
            ok = pcall(DBM.Bars.CreateBar, DBM.Bars, seconds, label, icon)
            if ok then return true end
        end
    end

    if BigWigs then
        if BigWigs.CreatePizzaTimer then
            local ok = pcall(BigWigs.CreatePizzaTimer, BigWigs, seconds, label, icon)
            if ok then return true end
        elseif BigWigs.CreateBar then
            local ok = pcall(BigWigs.CreateBar, BigWigs, seconds, label, icon)
            if ok then return true end
        end
    end

    if RLSuite.db and RLSuite.db.profile.debug then
        self:Debug(string.format(L['DBM/BigWigs not available: timer "%s" not started.'], label))
    end
    return false
end
