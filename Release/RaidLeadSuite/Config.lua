-- ============================================================
-- RLSuite - Config
-- The config surface is now ONE Ace3 window: an AceGUI "Window"
-- hosting an AceGUI "TreeGroup" (left navigation) and the AceConfig
-- options rendered by AceConfigDialog into the tree's content area.
-- Every setting from the old window lives in the same options table.
-- The bespoke 12-slot Macro Editor / icon picker (no AceConfig
-- equivalent) is hosted inside that same window under the "Macros"
-- node, as the "Macro Editor" leaf. The old raw "Config" frame no
-- longer exists: there is exactly one config window, the Ace3 one.
-- ============================================================

RLSuite.config = {}
local CFG = RLSuite.config

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local APP = "RLSuite"

-- ------------------------------------------------------------------
-- Shared profile access
-- ------------------------------------------------------------------
local function prof()
    return RLSuite.db.profile
end

-- ------------------------------------------------------------------
-- Option builders (thin wrappers over the AceConfig model)
-- ------------------------------------------------------------------
local function slider(name, desc, order, minV, maxV, stepV, get, set)
    return { type = "range", name = name, desc = desc, order = order,
             min = minV, max = maxV, step = stepV, get = get, set = set }
end

local function toggle(name, desc, order, get, set)
    return { type = "toggle", name = name, desc = desc, order = order,
             get = get, set = set }
end

local function select(name, desc, order, values, get, set)
    return { type = "select", name = name, desc = desc, order = order,
             values = values, get = get, set = set }
end

local function execute(name, desc, order, func)
    return { type = "execute", name = name, desc = desc, order = order,
             func = func }
end

local function textarea(name, desc, order, get, set)
    return { type = "input", name = name, desc = desc, order = order,
             multiline = 2, get = get, set = set }
end

-- Piccolo campo numerico a meta' larghezza (es. numero canale chat).
local function numinput(name, desc, order, get, set)
    return { type = "input", name = name, desc = desc, order = order,
             width = "half", get = get, set = set }
end

-- ------------------------------------------------------------------
-- Category tree (AceGUI TreeGroup) + node -> options path map.
-- Leaves map to an AceConfig path; the Macro Editor is a leaf whose
-- content is the bespoke in-window editor, not an AceConfig group.
-- ------------------------------------------------------------------
local CATEGORIES = {
    { value = "general", text = "General" },
    { value = "modulemenu", text = "Module Menu" },
    { value = "groupmaking", text = "Groupmaking" },
    { value = "macros", text = "Macros", children = {
        { value = "layout", text = "Bar Layout" },
        { value = "editor", text = "Macro Editor" },
    } },
    { value = "raidframe", text = "Raid Frame" },
    { value = "savedraids", text = "Saved Raids" },
    -- Lista ignora degli item di loot (v1.11.94): la voce va anche QUI,
    -- non solo nella tabella opzioni, altrimenti nel pannello non compare.
    { value = "loot", text = "Loot" },
    { value = "debug", text = "Debug" },
}

local EDITOR_NODE = "macros\001editor"

local NODES = {
    -- General e' flat: Opzioni font + Scale, senza sotto-voci.
    ["general"]            = { "general" },
    ["modulemenu"]         = { "modulemenu" },
    ["groupmaking"]        = { "groupmaking" },
    ["macros\001layout"]   = { "macros", "layout" },
    [EDITOR_NODE]          = "__editor__",
    -- Raid Frame e' un nodo singolo: solo il contenuto Layout (checks,
    -- positions e alerts sono stati eliminati dal pannello).
    ["raidframe"]          = { "raidframe" },
    ["savedraids"]         = { "savedraids" },
    ["loot"]               = { "loot" },
    ["debug"]              = { "debug" },
}

-- ------------------------------------------------------------------
-- Lifecycle
-- ------------------------------------------------------------------
function CFG:Init()
    self.db = RLSuite.db.profile
    self.widgetId = 0
    AceConfig:RegisterOptionsTable(APP, function()
        return self:BuildOptionsTable()
    end)
    self:CreateWindow()
    self:SelectNode("general")
end

function CFG:Toggle()
    if self:IsOpen() then
        self:CloseWindow()
    else
        self:Open()
    end
end

function CFG:Open()
    if not self.window then self:CreateWindow() end
    self.window:Show()
    if self.window.frame then
        self.window.frame:Raise()
    end
    -- Re-render the current node so dynamic values (saved raids,
    -- theme, anchors, ...) are in sync every time the window opens.
    if self.currentNode then
        self:OnNodeSelected(self.currentNode)
    else
        self:SelectNode("general\001look")
    end
end

function CFG:CloseWindow()
    if self.window then self.window:Hide() end
end

function CFG:IsOpen()
    return self.window ~= nil and self.window.frame ~= nil
        and self.window.frame:IsShown() == true
end

-- Re-renders the current options view (used after Saved Raids change,
-- macro bar restore, anchor toggling, theme/color changes, etc.).
function CFG:NotifyChange()
    AceConfigRegistry:NotifyChange(APP)
    -- The bundled AceConfigDialog (r50) only auto-refreshes standalone
    -- windows and Blizzard options, NOT custom containers; re-render the
    -- current node ourselves so dynamic values stay in sync.
    if self:IsOpen() and self.currentNode and NODES[self.currentNode] ~= "__editor__" then
        self:FeedNode(NODES[self.currentNode])
    end
end

function CFG:CreateWindow()
    -- Single Ace3 window: an AceGUI Window + AceGUI TreeGroup navigation.
    self.window = AceGUI:Create("Window")
    self.window:SetTitle("RLSuite")
    self.window:SetLayout("Fill")
    self.window:SetWidth(780)
    self.window:SetHeight(560)
    RLSuite.utils:ClampWindow(self.window.frame)

    self.tree = AceGUI:Create("TreeGroup")
    self.tree:SetLayout("Fill")
    self.tree:SetTreeWidth(185, true)
    self.tree:SetTree(CATEGORIES)
    self.tree:SetCallback("OnGroupSelected", function(_, _, unique)
        self:OnNodeSelected(unique)
    end)
    self.window:AddChild(self.tree)

    -- Share the AceConfigDialog root status table so every re-open
    -- (including the internal refresh after a control is changed)
    -- keeps the tree expanded and the right node selected.
    local status = AceConfigDialog:GetStatusTable(APP)
    status.groups = status.groups or {}
    for _, c in ipairs(CATEGORIES) do
        if c.children then status.groups[c.value] = true end
    end
    status.width = 780
    status.height = 560
    status.treewidth = 185
    status.treesizable = true
    self.status = status

    self:CreateMacroEditor(self.tree.content)

    self.window:Hide()
end

-- ------------------------------------------------------------------
-- Node navigation (single AceGUI tree, inside the window)
-- ------------------------------------------------------------------
function CFG:OnNodeSelected(unique)
    if not unique then return end
    self.currentNode = unique
    if unique == EDITOR_NODE then
        self:ShowMacroEditor()
        return
    end
    self:HideMacroEditor()
    local path = NODES[unique]
    if path then
        if self.status then self.status.selected = unique end
        self:FeedNode(path)
    end
end

-- Feeds the given AceConfig path into the tree's content area.
function CFG:FeedNode(path)
    AceConfigDialog:Open(APP, self.tree, unpack(path))
end

function CFG:SelectNode(unique)
    if self.tree and unique then
        self.tree:SelectByValue(unique)
    end
end

-- ------------------------------------------------------------------
-- Appearance helpers (kept for ApplyTheme / ApplyAll)
-- ------------------------------------------------------------------
function CFG:EnsureAppearance()
    local a = prof().appearance
    a.bg = a.bg or { r = 0.08, g = 0.08, b = 0.10, a = 1 }
    a.fill = a.fill or { r = 0.05, g = 0.05, b = 0.07, a = 1 }
    a.border = a.border or { r = 0.70, g = 0.70, b = 0.70, a = 1 }
    return a
end

function CFG:Layout(key)
    local p = prof()
    p.layout = p.layout or {}
    p.layout[key] = p.layout[key] or { scale = 1 }
    return p.layout[key]
end

function CFG:UpdateAnchorCheck()
    -- The anchor toggle is a native AceConfig option reading the profile
    -- directly; refresh the current view whenever anchorMode flips.
    self:NotifyChange()
end

function CFG:RebuildPanel()
    -- Compatibility shim: rebuild the current options view.
    self:NotifyChange()
    if self.currentNode then
        self:OnNodeSelected(self.currentNode)
    end
end

-- ------------------------------------------------------------------
-- Options table (generated on demand)
-- ------------------------------------------------------------------
function CFG:BuildOptionsTable()
    local p = prof()
    local a = self:EnsureAppearance()

    local themeValues = {
        ["default"] = "Default",
        ["dark"] = "Dark",
        ["gold"] = "Gold",
        ["custom"] = "Custom",
    }

    local fontValues = {
        ["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata",
        ["Fonts\\ARIALN.TTF"] = "Arial Narrow",
        ["Fonts\\MORPHEUS.TTF"] = "Morpheus",
        ["Fonts\\SKURRI.TTF"] = "Skurri",
    }

    local anchorValues = {
        ["TOPLEFT"] = "TOPLEFT", ["TOP"] = "TOP", ["TOPRIGHT"] = "TOPRIGHT",
        ["LEFT"] = "LEFT", ["CENTER"] = "CENTER", ["RIGHT"] = "RIGHT",
        ["BOTTOMLEFT"] = "BOTTOMLEFT", ["BOTTOM"] = "BOTTOM", ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
    }

    -- --- General / Font ------------------------------------------
    local font = {
        font = select(L["Font:"], nil, 1, fontValues,
            function() return a.font or "Fonts\\FRIZQT__.TTF" end,
            function(_, v) a.font = v; self:ApplyAll() end),
        fontSize = slider(L["Font size"], nil, 2, 8, 20, 1,
            function() return a.fontSize or 12 end,
            function(_, v) a.fontSize = v; self:ApplyAll() end),
    }

    -- --- Module Menu (ex General/Window): voce top-level a se' -------
    local main = self:Layout("main")
    main.matrixCols = main.matrixCols or 2
    main.matrixRows = main.matrixRows or 4

    local moduleMenu = {
        -- Le tre opzioni della barra moduli (scala, colonne, righe)
        -- applicano il layout SUBITO: ApplyAll rilancia
        -- RLSuite.mainWindow:ApplyLayout() ad ogni cambio dello slider.
        barScale = slider(L["Bar scale"], nil, 1, 0.70, 1.30, 0.05,
            function() return main.scale or 1 end,
            function(_, v) main.scale = v; self:ApplyAll() end),
        matrixCols = slider(L["Columns"], L["Columns in the bar button matrix."], 2, 1, 8, 1,
            function() return main.matrixCols end,
            function(_, v) main.matrixCols = v; self:ApplyAll() end),
        matrixRows = slider(L["Buttons per column"], nil, 3, 1, 8, 1,
            function() return main.matrixRows end,
            function(_, v) main.matrixRows = v; self:ApplyAll() end),
    }

    -- --- General / Debug -----------------------------------------
    local debug = {
        debugMode = toggle(L["Enable debug mode"], L["Simulates a raid group. Macros, LFM, rolls, loot and MS changes are whispered to you."], 1,
            function() return prof().debug == true end,
            function(_, v)
                prof().debug = v and true or false
                if RLSuite.ApplyDebugMode then
                    RLSuite:ApplyDebugMode()
                end
            end),
    }

    -- General: SOLO opzioni font + slider Scale globale (tutti i moduli).
    local general = {
        font = font.font,
        fontSize = font.fontSize,
        scale = slider(L["Scale"], L["Global scale for every module window (they all follow this slider)."], 3, 0.70, 1.30, 0.05,
            function() return a.scale or 1 end,
            function(_, v) a.scale = v; self:ApplyAll() end),
    }

    -- --- Saved Raids (dynamic) -----------------------------------
    local savedArgs = {}
    local list = p.savedRaids or {}
    if #list == 0 then
        savedArgs.none = { type = "description", name = L["No saves yet."], order = 1 }
    else
        for i, e in ipairs(list) do
            local title = e.title or string.format(L["Save #%d"], i)
            local id = e.id
            savedArgs["save" .. i .. "head"] = { type = "header", name = title, order = i * 10 }
            savedArgs["save" .. i .. "load"] = execute(L["Load"],
                L["Restore Comp, MacroBar and Config (except General)."], i * 10 + 1,
                function()
                    if RLSuite.LoadRaid then RLSuite:LoadRaid(id) end
                end)
            savedArgs["save" .. i .. "del"] = execute(L["Delete"], nil, i * 10 + 2,
                function()
                    if RLSuite.DeleteSavedRaid then RLSuite:DeleteSavedRaid(id) end
                end)
        end
    end

    local savedraids = { type = "group", name = L["Saved Raids"], order = 6, args = savedArgs }

    -- --- Groupmaking ---------------------------------------------
    -- Canali per lo spam LFM (General/Trade/LFG/World e il custom "global")
    local function gmSpamGet(chan)
        return function()
            local d = RLSuite.groupmaking and RLSuite.groupmaking.db
            if not d then return false end
            for _, c in ipairs(d.spamChannels or {}) do
                if strlower(c) == strlower(chan) then return true end
            end
            return false
        end
    end
    local function gmSpamSet(chan)
        return function(_, v)
            local d = RLSuite.groupmaking and RLSuite.groupmaking.db
            if not d then return end
            d.spamChannels = d.spamChannels or {}
            local found = false
            for i = #d.spamChannels, 1, -1 do
                if strlower(d.spamChannels[i]) == strlower(chan) then
                    found = true
                    if not v then table.remove(d.spamChannels, i) end
                    break
                end
            end
            if v and not found then table.insert(d.spamChannels, chan) end
        end
    end
    -- (lo slider Scale per-modulo e' eliminato: tutti i moduli seguono lo
    -- snapshot Scale in General)
    local groupmaking = {
        spamDesc = { type = "description", name = L["Spam channels"] .. ":", order = 1, fontSize = "medium" },
    }
    -- Ogni canale: checkbox + campo numero canale affiancato. Numero 0 o
    -- vuoto = risoluzione automatica da GetChannelName(nome); un numero
    -- esplicito > 0 ha la precedenza sul nome.
    local _gmChans = { "General", "Trade", "LookingForGroup", "World", "global" }
    for i, ch in ipairs(_gmChans) do
        local tgl = toggle(L[ch], nil, 1 + i, gmSpamGet(ch), gmSpamSet(ch))
        tgl.width = "half"
        groupmaking["spam_" .. ch] = tgl
        groupmaking["spamNum_" .. ch] = numinput(L["Channel #"], L["Explicit channel number; leave empty (or 0) to auto-detect by name."], 1 + i + 0.01,
            (function(c) return function()
                local d = RLSuite.groupmaking and RLSuite.groupmaking.db
                local n = d and d.spamChannelNums and tonumber(d.spamChannelNums[c])
                return (n and n > 0) and tostring(n) or ""
            end end)(ch),
            (function(c) return function(_, v)
                local d = RLSuite.groupmaking and RLSuite.groupmaking.db
                if not d then return end
                d.spamChannelNums = d.spamChannelNums or {}
                local n = tonumber(v)
                d.spamChannelNums[c] = (n and n > 0) and n or nil
            end end)(ch))
    end

    -- --- Macros / Bar Layout -------------------------------------
    if RLSuite.macrobar and RLSuite.macrobar.EnsurePhases then
        RLSuite.macrobar:EnsurePhases()
    end
    local mb = p.macrobar
    mb.buttons = mb.buttons or 12
    mb.columns = mb.columns or 12
    mb.buttonSize = mb.buttonSize or 32
    mb.spacing = mb.spacing or 2
    mb.backdropSpacing = mb.backdropSpacing or 2
    mb.heightMult = mb.heightMult or 1
    mb.widthMult = mb.widthMult or 1
    mb.alpha = mb.alpha or 1
    mb.scale = mb.scale or 1

    local macroLayout = {
        -- (checkbox "Enable" eliminata: la barra si governa dai comandi
        -- della sua HUD/keybind, non da qui)
        lock = toggle(L["Lock"], nil, 2,
            function() return mb.locked end,
            function(_, v) mb.locked = v; self:ApplyAll() end),
        backdrop = toggle(L["Backdrop"], nil, 3,
            function() return mb.backdrop ~= false end,
            function(_, v) mb.backdrop = v; self:ApplyAll() end),
        mouseover = toggle(L["Mouse Over"], nil, 4,
            function() return mb.mouseover end,
            function(_, v) mb.mouseover = v; self:ApplyAll() end),
        inheritFade = toggle(L["Inherit Global Fade"], nil, 5,
            function() return mb.inheritGlobalFade end,
            function(_, v) mb.inheritGlobalFade = v; self:ApplyAll() end),
        anchor = select(L["Anchor Point"], nil, 6, anchorValues,
            function() return mb.point or "CENTER" end,
            function(_, v) mb.point = v; mb.relPoint = v; self:ApplyAll() end),
        columns = slider(L["Buttons Per Row"], nil, 7, 1, 12, 1,
            function() return mb.columns end,
            function(_, v) mb.columns = v; self:ApplyAll() end),
        buttonSize = slider(L["Button Size"], nil, 8, 15, 60, 1,
            function() return mb.buttonSize end,
            function(_, v) mb.buttonSize = v; self:ApplyAll() end),
        spacing = slider(L["Button Spacing"], nil, 9, -3, 20, 1,
            function() return mb.spacing end,
            function(_, v) mb.spacing = v; self:ApplyAll() end),
        backdropSpacing = slider(L["Backdrop Spacing"], nil, 10, 0, 10, 1,
            function() return mb.backdropSpacing end,
            function(_, v) mb.backdropSpacing = v; self:ApplyAll() end),
        heightMult = slider(L["Height Multiplier"], nil, 11, 1, 5, 1,
            function() return mb.heightMult end,
            function(_, v) mb.heightMult = v; self:ApplyAll() end),
        widthMult = slider(L["Width Multiplier"], nil, 12, 1, 5, 1,
            function() return mb.widthMult end,
            function(_, v) mb.widthMult = v; self:ApplyAll() end),
        alpha = slider(L["Alpha"], nil, 13, 0, 100, 1,
            function() return math.floor((mb.alpha or 1) * 100 + 0.5) end,
            function(_, v) mb.alpha = v / 100; self:ApplyAll() end),
        actionPaging = textarea(L["Action Paging"], nil, 15,
            function() return mb.actionPaging end,
            function(_, v) mb.actionPaging = v; self:ApplyAll() end),
        visibility = textarea(L["Visibility State"], nil, 16,
            function() return mb.visibility end,
            function(_, v) mb.visibility = v; self:ApplyAll() end),
        restore = execute(L["Restore Bar"], L["Reset the MacroBar to its default layout."], 17,
            function() self:RestoreMacroBar() end),
        keybind = execute(L["Keybind"], nil, 18,
            function()
                if RLSuite.macrobar and RLSuite.macrobar.OpenKeybindUI then
                    RLSuite.macrobar:OpenKeybindUI()
                end
            end),
    }

    local macros = {
        layout = { type = "group", name = L["Bar Layout"], order = 1, args = macroLayout },
    }

    -- --- Raid Frame ----------------------------------------------
    local rf = p.raidframe
    rf.appearance = rf.appearance or {}
    rf.width = rf.width or 380
    rf.scale = rf.scale or 1
    rf.appearance.barWidth = rf.appearance.barWidth or 180
    rf.appearance.nameFontSize = rf.appearance.nameFontSize or 11

    local raidLayout = {
        iconSize = slider(L["Icon size"], nil, 1, 10, 24, 1,
            function() return rf.appearance.iconSize or 16 end,
            function(_, v) rf.appearance.iconSize = v; self:ApplyAll() end),
        barWidth = slider(L["Player bar width"], nil, 3, 100, 300, 5,
            function() return rf.appearance.barWidth or 180 end,
            function(_, v) rf.appearance.barWidth = v; self:ApplyAll() end),
        nameFontSize = slider(L["Name font size"], nil, 4, 8, 16, 1,
            function() return rf.appearance.nameFontSize or 11 end,
            function(_, v) rf.appearance.nameFontSize = v; self:ApplyAll() end),
        font = select(L["Font"], L["Font used for the player name on the bars."], 7, {
            ["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata (default)",
            ["Fonts\\ARIALN.TTF"] = "Arial Narrow",
            ["Fonts\\SKURRI.TTF"] = "Skurri",
            ["Fonts\\MORPHEUS.TTF"] = "Morpheus",
        },
            function() return rf.appearance.font or "Fonts\\FRIZQT__.TTF" end,
            function(_, v) rf.appearance.font = v; self:ApplyAll() end),
        fontOutline = toggle(L["Font outline"], L["Draw the player name with an outline."], 8,
            function() return rf.appearance.fontOutline ~= false end,
            function(_, v) rf.appearance.fontOutline = v; self:ApplyAll() end),
        barTexture = select(L["Bar texture"], L["Texture of the player HP bars."], 9, {
            ["Interface\\TargetingFrame\\UI-StatusBar"] = "Blizzard (default)",
            ["Interface\\PAPERDOLLINFOFRAME\\UI-Character-Skills-Bar"] = "Skill bar",
            ["Interface\\Buttons\\WHITE8x8"] = "Flat",
        },
            function() return rf.appearance.barTexture or "Interface\\TargetingFrame\\UI-StatusBar" end,
            function(_, v) rf.appearance.barTexture = v; self:ApplyAll() end),
        alpha = slider(L["Opacity"], L["Overall transparency of the Raid Frame HUD."], 10, 0.30, 1.00, 0.05,
            function() return rf.alpha or 1 end,
            function(_, v) rf.alpha = v; self:ApplyAll() end),
        distanceFade = select(L["Distance fade"], L["Player bars fade out beyond this distance (0 = off)."], 17, {
            ["0"] = L["Off"],
            ["10"] = "10 yards",
            ["15"] = "15 yards",
            ["20"] = "20 yards",
            ["25"] = "25 yards",
            ["30"] = "30 yards",
            ["35"] = "35 yards",
            ["40"] = "40 yards",
        },
            function() return tostring(rf.appearance.distanceFade or 0) end,
            function(_, v) rf.appearance.distanceFade = tonumber(v) or 0; self:ApplyAll() end),
        distanceAlpha = slider(L["Fade transparency"], L["Transparency of the bars beyond the distance."], 18, 0.20, 1.00, 0.05,
            function() return rf.appearance.distanceAlpha or 0.40 end,
            function(_, v) rf.appearance.distanceAlpha = v; self:ApplyAll() end),
        iconSpacing = slider(L["Icon spacing"], L["Gap between the Raid Buffs matrix icons."], 12, 0, 16, 1,
            function() return rf.appearance.iconSpacing or 8 end,
            function(_, v) rf.appearance.iconSpacing = v; self:ApplyAll() end),
        rowSpacing = slider(L["Row spacing"], L["Gap between the player bars inside each group."], 13, -10, 12, 1,
            function() return rf.appearance.rowSpacing or 0 end,
            function(_, v) rf.appearance.rowSpacing = v; self:ApplyAll() end),
        groupSpacing = slider(L["Group spacing"], L["Gap between the groups (Tanks, G1..G6)."], 14, 0, 24, 1,
            function() return rf.appearance.groupSpacing or 8 end,
            function(_, v) rf.appearance.groupSpacing = v; self:ApplyAll() end),
        groupHeaderFontSize = slider(L["Group header font size"], L["Font size of the group labels (Tanks, G1..G6)."], 15, 8, 16, 1,
            function() return rf.appearance.groupHeaderFontSize or 10 end,
            function(_, v) rf.appearance.groupHeaderFontSize = v; self:ApplyAll() end),
        matrixBackdrop = {
            name = L["Buff check backdrop"],
            desc = L["Backdrop color and transparency of the Raid Buffs matrix rows."],
            type = "color",
            hasAlpha = true,
            order = 16,
            get = function()
                local c = rf.appearance.matrixBackdrop or { r = 0.5, g = 0.5, b = 0.5, a = 0.35 }
                return c.r or 0.5, c.g or 0.5, c.b or 0.5, c.a or 0.35
            end,
            set = function(_, r, g, b, a)
                rf.appearance.matrixBackdrop = { r = r, g = g, b = b, a = a }
                self:ApplyAll()
            end,
        },
        fontColor = {
            name = L["Font color"],
            desc = L["Color of the player name on the bars."],
            type = "color",
            hasAlpha = false,
            order = 11,
            get = function()
                local c = rf.appearance.fontColor or { r = 1, g = 1, b = 1 }
                return c.r or 1, c.g or 1, c.b or 1
            end,
            set = function(_, r, g, b)
                rf.appearance.fontColor = { r = r, g = g, b = b, a = 1 }
                self:ApplyAll()
            end,
        },
    }

    -- Checks, Alert Messages e Position: eliminati dal pannello (solo
    -- Layout resta configurabile per il Raid Frame).

    local raidframe = raidLayout

    -- --- Loot ----------------------------------------------------
    -- La LISTA IGNORA (item singoli) sta qui, modificabile a mano: una riga
    -- per item, "id" oppure "id: Nome" (o incollando direttamente il link).
    -- Si riempie da sola col ctrl+click su una riga dello storico loot.
    local function filterToggle(key, name, order)
        return { type = "toggle", name = name, order = order,
            desc = L["Never capture or show this category of loot."],
            get = function()
                local lm = RLSuite.lootManager
                return (lm and lm.db and lm.db.filters and lm.db.filters[key]) and true or false
            end,
            set = function(_, v)
                local lm = RLSuite.lootManager
                if lm and lm.SetCategoryIgnored then lm:SetCategoryIgnored(key, v) end
            end }
    end

    local loot = {
        ignoreNote = { type = "description", order = 1,
            name = L["Ctrl+click a loot row to ignore that item: it is never captured nor shown again. The list below is editable (one item per line: ID, or ID: name, or paste the item link)."] },
        ignoreList = { type = "input", name = L["Ignored items"],
            desc = L["One item per line: ID, or ID: name. Empty the list to stop ignoring items."],
            multiline = 12, width = "full", order = 2,
            get = function()
                local lm = RLSuite.lootManager
                if not (lm and lm.IgnoredListText) then return "" end
                return lm:IgnoredListText()
            end,
            set = function(_, v)
                local lm = RLSuite.lootManager
                if lm and lm.SetIgnoredListText then
                    local n = lm:SetIgnoredListText(v)
                    RLSuite.utils:Print(string.format(L["Ignore list saved (%d items)."], n))
                end
            end },
        ignoreClear = execute(L["Clear ignored items"],
            L["Removes every item from the ignore list: loot that was ignored starts being captured again."],
            3,
            function()
                local lm = RLSuite.lootManager
                if lm and lm.ClearIgnoredItems then
                    local n = lm:ClearIgnoredItems()
                    lm:UpdateHistory()
                    RLSuite.utils:Print(string.format(L["Ignore list cleared (%d items removed)."], n))
                    if RLSuite.config then RLSuite.config:NotifyChange() end
                end
            end),
        filtersHead = { type = "header", name = L["Ignore loot categories"], order = 4 },
        fRecipes = filterToggle("recipes", L["recipes"], 5),
        fBoe = filterToggle("boe", L["BOE"], 6),
        fGems = filterToggle("gems", L["gems"], 7),
        fShards = filterToggle("shards", L["shards"], 8),
        fProjectiles = filterToggle("projectiles", L["projectiles"], 9),
    }

    return {
        type = "group",
        name = "RLSuite",
        args = {
            general = { type = "group", name = L["General"], order = 1, args = general },
            modulemenu = { type = "group", name = L["Module Menu"], order = 2, args = moduleMenu },
            groupmaking = { type = "group", name = L["Groupmaking"], order = 3, args = groupmaking },
            macros = { type = "group", name = L["Macros"], order = 4, args = macros },
            raidframe = { type = "group", name = L["Raid Frame"], order = 5, args = raidframe },
            savedraids = savedraids,
            loot = { type = "group", name = L["Loot"], order = 7, args = loot },
            debug = { type = "group", name = L["Debug"], order = 8, args = debug },
        },
    }
end

-- ============================================================
-- Macros: 12-slot editor + icon picker (bespoke, kept as-is)
-- ============================================================

function CFG:OpenMacroEditorPanel()
    if not self.window then self:CreateWindow() end
    self.window:Show()
    if self.window.frame then self.window.frame:Raise() end
    self:SelectNode(EDITOR_NODE)
end

function CFG:HideMacroEditor()
    if self.macroEditorPanel then
        self.macroEditorPanel:Hide()
    end
    if self.macroIconPicker then
        self.macroIconPicker:Hide()
    end
end

function CFG:ShowMacroEditor()
    if not self.macroEditorPanel then
        self:CreateMacroEditor(self.tree and self.tree.content)
    end
    -- Release the AceConfig controls so the editor is the only thing in
    -- the content area while the "Macro Editor" node is selected.
    if self.tree then self.tree:ReleaseChildren() end
    self.macroEditorPanel:Show()
    self:UpdateMacroBossSelectors()
    self:RefreshMacroTab()
    self:OpenMacroEditor(self.macroEditIndex or 1)
end

function CFG:CreateMacroEditor(parent)
    parent = parent or UIParent
    local ed = CreateFrame("Frame", "RLSuiteCfgMacroEditor", parent)
    ed:SetAllPoints(parent)
    ed:Hide()
    ed:EnableMouse(true)
    ed:SetScript("OnMouseDown", function()
        if CFG.frame and RLSuite.utils and RLSuite.utils.RaiseWindow then
            RLSuite.utils:RaiseWindow(CFG.frame)
        end
    end)
    self.macroEditorPanel = ed

    self.macroPhase = RLSuite.context or "preraid"
    self.macroPreviewBtns = {}
    self.macroPhaseBtns = {}
    self.macroLoading = false
    self.macroEditIndex = nil
    self.macroEditIcon = nil

    -- riga 1: selezione fase
    local phaseLabel = ed:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    phaseLabel:SetPoint("TOPLEFT", ed, "TOPLEFT", 10, -8)
    phaseLabel:SetText(L["Phase:"])

    local phases = {
        {key = "preraid", label = "Pre-raid"},
        {key = "preboss", label = "Pre-boss"},
        {key = "infight", label = "In-fight"},
    }
    for i, pdata in ipairs(phases) do
        local btn = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
        RLSuite.utils:SkinButton(btn)
        btn:SetSize(70, 20)
        btn:SetPoint("LEFT", phaseLabel, "RIGHT", 6 + (i - 1) * 76, 0)
        btn:SetText(pdata.label)
        btn.phaseKey = pdata.key
        btn:SetScript("OnClick", function()
            self:SelectMacroPhase(pdata.key)
        end)
        self.macroPhaseBtns[pdata.key] = btn
    end

    -- riga 2: anteprima 12 slot (2 righe x 6)
    local preview = CreateFrame("Frame", nil, ed)
    preview:SetPoint("TOPLEFT", phaseLabel, "BOTTOMLEFT", 0, -8)
    preview:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -8, -30)
    preview:SetHeight(90)
    RLSuite.utils:SkinBox(preview)
    self.macroPreview = preview

    for i = 1, 12 do
        local btn = CreateFrame("Button", nil, preview)
        btn:SetSize(36, 36)
        local col = (i - 1) % 6
        local row = math.floor((i - 1) / 6)
        btn:SetPoint("TOPLEFT", preview, "TOPLEFT", 8 + col * 44, -8 - row * 42)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        RLSuite.utils:SkinMacroButton(btn)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function()
            self:OpenMacroEditor(i)
        end)
        local num = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
        num:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        num:SetText(i)
        self.macroPreviewBtns[i] = btn
    end

    -- ------------------------------------------------------------
    -- Selettori RAID + BOSS delle MACRO IN-FIGHT.
    -- Compaiono SOLO quando la fase selezionata e' In-fight, nello spazio a
    -- destra delle 12 icone (sotto i tasti di fase). Con raid + boss scelti,
    -- anteprima / elenco / campi lavorano sul set db.bossMacros[raid][boss]:
    -- in fight la barra usa il set del boss che stai affrontando (target,
    -- poi boss1..4) e senza boss non mostra nessuna macro.
    -- 272 = subito a destra della sesta colonna di icone (8 + 6*44).
    -- ------------------------------------------------------------
    local bossSel = CreateFrame("Frame", "RLSuiteCfgMacroBossSel", preview)
    bossSel:SetPoint("TOPLEFT", preview, "TOPLEFT", 272, -8)
    bossSel:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -6, 6)
    bossSel:Hide()
    self.macroBossSel = bossSel

    local raidLbl = bossSel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raidLbl:SetPoint("TOPLEFT", bossSel, "TOPLEFT", 0, -4)
    raidLbl:SetText(L["Raid:"])

    local raidDD = RLSuite.utils:CreateDropdown(bossSel, "RLSuiteCfgMacroRaidDD", 150, 20)
    raidDD:SetPoint("LEFT", raidLbl, "RIGHT", 4, 0)
    raidDD:SetPoint("RIGHT", bossSel, "RIGHT", 0, 0)
    self.macroRaidDD = raidDD

    local bossLbl = bossSel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossLbl:SetPoint("TOPLEFT", bossSel, "TOPLEFT", 0, -30)
    bossLbl:SetText(L["Boss:"])

    local bossDD = RLSuite.utils:CreateDropdown(bossSel, "RLSuiteCfgMacroBossDD", 150, 20)
    bossDD:SetPoint("LEFT", bossLbl, "RIGHT", 4, 0)
    bossDD:SetPoint("RIGHT", bossSel, "RIGHT", 0, 0)
    self.macroBossDD = bossDD

    local bossHint = bossSel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossHint:SetPoint("TOPLEFT", bossLbl, "BOTTOMLEFT", 0, -6)
    bossHint:SetPoint("RIGHT", bossSel, "RIGHT", 0, 0)
    bossHint:SetJustifyH("LEFT")
    bossHint:SetTextColor(0.65, 0.65, 0.65)
    bossHint:SetText(L["In fight the bar uses the boss you are facing"])
    self.macroBossHint = bossHint

    -- area editor sotto l'anteprima
    local editor = CreateFrame("Frame", "RLSuiteCfgMacroEditorBox", ed)
    editor:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -6)
    editor:SetPoint("BOTTOMRIGHT", ed, "BOTTOMRIGHT", -8, 8)
    RLSuite.utils:SkinBox(editor)
    editor:Show()
    self.macroEditor = editor

    -- elenco macro a destra
    local list = CreateFrame("Frame", nil, editor)
    list:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -6, -6)
    list:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -6, 6)
    list:SetWidth(150)
    RLSuite.utils:SkinBox(list)
    self.macroListFrame = list

    local listTitle = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listTitle:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -5)
    listTitle:SetText(L["All macros"])
    self.macroListTitle = listTitle

    self.macroListRows = {}
    for i = 1, 12 do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(16)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -20 - (i - 1) * 17)
        row:SetPoint("RIGHT", list, "RIGHT", -4, 0)
        local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("LEFT", row, "LEFT", 2, 0)
        num:SetWidth(12)
        num:SetJustifyH("LEFT")
        num:SetText(tostring(i))
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", num, "RIGHT", 2, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        fs:SetJustifyH("LEFT")
        fs:SetText("")
        row.fs = fs
        row.idx = i
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", function()
            self:OpenMacroEditor(i)
        end)
        self.macroListRows[i] = row
    end

    -- lato sinistro: titolo slot, nome, icona
    local slotFS = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotFS:SetPoint("TOPLEFT", editor, "TOPLEFT", 8, -6)
    slotFS:SetText(L["Macro"])
    self.macroSlotFS = slotFS

    local nameLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", slotFS, "BOTTOMLEFT", 0, -6)
    nameLabel:SetText(L["Name:"])

    local nameEdit = CreateFrame("EditBox", "RLSuiteCfgMacroNameEdit", editor, "InputBoxTemplate")
    nameEdit:SetSize(110, 18)
    nameEdit:SetPoint("LEFT", nameLabel, "RIGHT", 4, 0)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(32)
    nameEdit:SetScript("OnTextChanged", function()
        self:SaveMacroSlot()
    end)
    nameEdit:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    nameEdit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    self.macroNameEdit = nameEdit

    local iconBtn = CreateFrame("Button", nil, editor)
    iconBtn:SetSize(30, 30)
    iconBtn:SetPoint("LEFT", nameEdit, "RIGHT", 8, 0)
    iconBtn.icon = iconBtn:CreateTexture(nil, "ARTWORK")
    iconBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    iconBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    RLSuite.utils:SkinMacroButton(iconBtn)
    iconBtn:EnableMouse(true)
    iconBtn:RegisterForClicks("LeftButtonUp")
    iconBtn:SetScript("OnClick", function()
        self:ToggleMacroIconPicker()
    end)
    self.macroIconBtn = iconBtn

    -- corpo della macro
    local bodyFrame = CreateFrame("Frame", nil, editor)
    bodyFrame:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -6)
    bodyFrame:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 8, 26)
    bodyFrame:SetPoint("RIGHT", list, "LEFT", -6, 0)
    bodyFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    bodyFrame:SetBackdropColor(0, 0, 0, 0.85)
    self.macroBodyFrame = bodyFrame

    local body = CreateFrame("EditBox", "RLSuiteCfgMacroBodyEdit", bodyFrame)
    body:SetMultiLine(true)
    body:SetAutoFocus(false)
    body:SetFontObject(ChatFontNormal)
    body:SetTextInsets(6, 6, 6, 6)
    body:SetMaxLetters(1024)
    body:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", 6, -6)
    body:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", -6, 6)
    body:EnableMouse(true)
    body:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    body:SetScript("OnTextChanged", function()
        self:SaveMacroSlot()
    end)
    self.macroBodyEdit = body

    -- barra utility: target marker + CAPS
    local util = CreateFrame("Frame", nil, editor)
    util:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 8, 5)
    util:SetPoint("RIGHT", list, "LEFT", -6, 0)
    util:SetHeight(20)
    self.macroUtilBar = util

    local raidIcons = {
        { token = "{rt1}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
        { token = "{rt2}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
        { token = "{rt3}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
        { token = "{rt4}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
        { token = "{rt5}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
        { token = "{rt6}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
        { token = "{rt7}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
        { token = "{rt8}", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    }
    for i, data in ipairs(raidIcons) do
        local ib = CreateFrame("Button", nil, util)
        ib:SetSize(18, 18)
        ib:SetPoint("LEFT", util, "LEFT", (i - 1) * 22, 0)
        local tex = ib:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(ib)
        tex:SetTexture(data.tex)
        ib:EnableMouse(true)
        ib:RegisterForClicks("LeftButtonUp")
        ib:SetScript("OnClick", function()
            self:InsertMacroText(data.token)
        end)
    end

    local capsBtn = CreateFrame("Button", nil, util, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(capsBtn)
    capsBtn:SetSize(56, 18)
    capsBtn:SetPoint("LEFT", util, "LEFT", 8 * 22 + 6, 0)
    capsBtn:SetText("CAPS")
    capsBtn:SetScript("OnClick", function()
        self:ToggleMacroCaps()
    end)

    self:HookMacroInsertLink()
    self:CreateMacroIconPicker(editor)
    self:UpdateMacroBossSelectors()
end

function CFG:HookMacroInsertLink()
    if self._insertLinkHooked then return end
    self._insertLinkHooked = true
    RLSuite.utils:RegisterInsertLink(self.macroBodyEdit, function()
        CFG:SaveMacroSlot()
    end)
end

function CFG:CreateMacroIconPicker(parent)
    local picker = CreateFrame("Frame", "RLSuiteCfgMacroIconPicker", parent)
    picker:SetSize(280, 220)
    picker:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 12, 44)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    RLSuite.utils:SkinFrame(picker)
    picker:Hide()
    picker:EnableMouse(true)
    self.macroIconPicker = picker

    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -8)
    title:SetText(L["Macro icon"])

    local close = RLSuite.utils:MakeCloseX(picker, function() picker:Hide() end)
    close:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -2, -2)

    local scroll = CreateFrame("ScrollFrame", "RLSuiteCfgMacroIconScroll", picker, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", picker, "TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -28, 8)
    scroll:SetScript("OnVerticalScroll", function(s, offset)
        FauxScrollFrame_OnVerticalScroll(s, offset, 32, function()
            CFG:UpdateMacroIconPicker()
        end)
    end)
    self.macroIconScroll = scroll

    self.macroIconBtns = {}
    local cols, rows, size, gap = 10, 6, 28, 2
    for i = 1, cols * rows do
        local btn = CreateFrame("Button", nil, picker)
        btn:SetSize(size, size)
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        btn:SetPoint("TOPLEFT", scroll, "TOPLEFT", col * (size + gap), -row * (size + gap))
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints(btn)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("OnClick", function(s)
            if s.texPath then
                CFG:SetMacroIcon(s.texPath)
            end
        end)
        self.macroIconBtns[i] = btn
    end
end

function CFG:GetMacroIconList()
    if self.macroIconList then return self.macroIconList end
    local list = {}
    if GetNumMacroIcons and GetMacroIconInfo then
        local n = GetNumMacroIcons() or 0
        for i = 1, n do
            local tex = GetMacroIconInfo(i)
            if tex then table.insert(list, tex) end
        end
    end
    if #list == 0 then
        table.insert(list, "Interface\\Icons\\INV_Misc_QuestionMark")
        if RLSuite.abilityByName then
            for _, meta in pairs(RLSuite.abilityByName) do
                if meta.icon then table.insert(list, meta.icon) end
            end
        end
    end
    self.macroIconList = list
    return list
end

function CFG:ToggleMacroIconPicker()
    if not self.macroIconPicker then return end
    if self.macroIconPicker:IsShown() then
        self.macroIconPicker:Hide()
        return
    end
    self:GetMacroIconList()
    self.macroIconPicker:Show()
    self:UpdateMacroIconPicker()
end

function CFG:UpdateMacroIconPicker()
    local list = self:GetMacroIconList()
    local cols, rows = 10, 6
    local per = cols * rows
    local numRows = math.ceil(#list / cols)
    FauxScrollFrame_Update(self.macroIconScroll, numRows, rows, 32)
    local offset = FauxScrollFrame_GetOffset(self.macroIconScroll) or 0
    for i = 1, per do
        local idx = offset * cols + i
        local btn = self.macroIconBtns[i]
        local tex = list[idx]
        if tex then
            btn.icon:SetTexture(tex)
            btn.texPath = tex
            btn:Show()
        else
            btn.texPath = nil
            btn:Hide()
        end
    end
end

function CFG:SetMacroIcon(tex)
    self.macroEditIcon = tex
    if self.macroIconBtn and self.macroIconBtn.icon then
        self.macroIconBtn.icon:SetTexture(tex)
    end
    if self.macroIconPicker then self.macroIconPicker:Hide() end
    self:SaveMacroSlot()
end

function CFG:OpenMacroEditor(index)
    self.macroEditIndex = index
    if self.macroEditor then self.macroEditor:Show() end
    if self.macroIconPicker then self.macroIconPicker:Hide() end
    for i, btn in ipairs(self.macroPreviewBtns or {}) do
        if btn and not btn.sel then
            btn.sel = btn:CreateTexture(nil, "OVERLAY")
            btn.sel:SetAllPoints(btn)
            btn.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            btn.sel:SetBlendMode("ADD")
            btn.sel:Hide()
        end
        if btn and btn.sel then
            if i == index then btn.sel:Show() else btn.sel:Hide() end
        end
    end
    if self.macroSlotFS then
        self.macroSlotFS:SetText("Macro " .. tostring(index))
    end
    local macros = self:GetMacroDB()
    local data = macros[index] or {}
    self.macroLoading = true
    self.macroEditIcon = data.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    if self.macroNameEdit then
        self.macroNameEdit:SetText(data.name or "")
    end
    if self.macroBodyEdit then
        self.macroBodyEdit:SetText(data.text or "")
        self.macroBodyEdit:SetFocus()
    end
    if self.macroIconBtn and self.macroIconBtn.icon then
        self.macroIconBtn.icon:SetTexture(self.macroEditIcon)
    end
    self.macroLoading = false
    self:RefreshMacroList()
end

function CFG:InsertMacroText(token)
    if not self.macroBodyEdit then return end
    self.macroBodyEdit:SetFocus()
    self.macroBodyEdit:Insert(token)
    self:SaveMacroSlot()
end

function CFG:ToggleMacroCaps()
    local edit = self.macroBodyEdit
    if not edit then return end
    local full = edit:GetText() or ""
    if full == "" then return end
    edit:SetFocus()
    edit:Insert("\001")
    local after = edit:GetText() or ""
    local pos = string.find(after, "\001", 1, true)
    local selected, s, e
    if not pos then
        selected, s, e = full, 1, string.len(full)
        edit:SetText(full)
    else
        local prefix = string.sub(after, 1, pos - 1)
        local suffix = string.sub(after, pos + 1)
        s = string.len(prefix) + 1
        e = string.len(full) - string.len(suffix)
        if e < s then
            selected, s, e = full, 1, string.len(full)
        else
            selected = string.sub(full, s, e)
            if selected == "" then
                selected, s, e = full, 1, string.len(full)
            end
        end
    end
    local repl
    if selected == string.upper(selected) then
        repl = string.lower(selected)
    else
        repl = string.upper(selected)
    end
    local newText = string.sub(full, 1, s - 1) .. repl .. string.sub(full, e + 1)
    self.macroLoading = true
    edit:SetText(newText)
    self.macroLoading = false
    self:SaveMacroSlot()
end

function CFG:SelectMacroPhase(phase)
    self.macroPhase = phase or "preraid"
    self:UpdateMacroBossSelectors()
    for key, btn in pairs(self.macroPhaseBtns or {}) do
        if key == self.macroPhase then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end
    self:RefreshMacroTab()
    if self.macroEditIndex then
        self:OpenMacroEditor(self.macroEditIndex)
    end
end

-- ------------------------------------------------------------
-- MACRO IN-FIGHT: raid + boss nell'editor
-- ------------------------------------------------------------
-- Boss di default: quello che stai affrontando adesso (target, poi boss1..4);
-- se non c'e', il raid scelto in Group Making col suo primo boss.
function CFG:DefaultMacroBoss()
    local raid, boss = RLSuite:CurrentBossInfo()
    if raid and boss and (RLSuite.raidDB or {})[raid] then return raid, boss end
    local gm = RLSuite.db and RLSuite.db.profile and RLSuite.db.profile.groupmaking
    local r = gm and gm.raid
    if not (r and (RLSuite.raidDB or {})[r]) then
        local names = {}
        for k in pairs(RLSuite.raidDB or {}) do names[#names + 1] = k end
        table.sort(names)
        r = names[1]
    end
    local info = r and RLSuite.raidDB[r]
    local list = (info and info.bosses) or {}
    return r, list[1]
end

function CFG:PopulateMacroRaidDropdown()
    if not self.macroRaidDD then return end
    local raids = {}
    for name in pairs(RLSuite.raidDB or {}) do raids[#raids + 1] = name end
    table.sort(raids)
    -- Mai svuotare un menu gia' popolato: una tendina senza opzioni diventa
    -- "muta" (il toggle non apre niente) e sembra rotta.
    if #raids == 0 then return end
    if not (self.macroRaid and RLSuite.raidDB[self.macroRaid]) then
        self.macroRaid, self.macroBoss = self:DefaultMacroBoss()
    end
    RLSuite.utils:SetupDropdown(self.macroRaidDD, raids, self.macroRaid, function(value)
        self.macroRaid = value
        self.macroBoss = nil
        self:PopulateMacroBossDropdown()
        self:RefreshMacroTab()
        if self.macroEditIndex then self:OpenMacroEditor(self.macroEditIndex) end
    end)
end

function CFG:PopulateMacroBossDropdown()
    if not self.macroBossDD then return end
    local info = RLSuite.raidDB[self.macroRaid or ""]
    local bosses = (info and info.bosses) or {}
    -- Vedi sopra: con una lista vuota si esce SENZA toccare le opzioni gia'
    -- presenti, cosi' il menu continua a funzionare.
    if #bosses == 0 then return end
    local valid = false
    for i = 1, #bosses do
        if bosses[i] == self.macroBoss then valid = true end
    end
    if not valid then self.macroBoss = bosses[1] end
    RLSuite.utils:SetupDropdown(self.macroBossDD, bosses, self.macroBoss, function(value)
        self.macroBoss = value
        self:RefreshMacroTab()
        if self.macroEditIndex then self:OpenMacroEditor(self.macroEditIndex) end
    end)
end

-- I due menu vivono solo sulla fase in-fight (basta selezionarla): le altre
-- fasi continuano a usare il set unico di fase.
function CFG:UpdateMacroBossSelectors()
    local sel = self.macroBossSel
    if not sel then return end
    if (self.macroPhase or "preraid") == "infight" then
        if not (self.macroRaid and self.macroBoss) then
            self.macroRaid, self.macroBoss = self:DefaultMacroBoss()
        end
        self:PopulateMacroRaidDropdown()
        self:PopulateMacroBossDropdown()
        sel:Show()
        if self.macroListTitle then
            self.macroListTitle:SetText(string.format(L["Boss macros: %s"],
                tostring(self.macroBoss or "?")))
        end
    else
        sel:Hide()
        if self.macroListTitle then self.macroListTitle:SetText(L["All macros"]) end
    end
end

-- Set macro che l'editor sta modificando. In-fight e' il set del raid+boss
-- scelti nei due menu (NESSUN fallback: se per quel boss non hai scritto
-- niente, gli slot sono vuoti anche in fight).
function CFG:GetMacroDB(phase)
    phase = phase or self.macroPhase or "preraid"
    local bar = RLSuite.db and RLSuite.db.profile and RLSuite.db.profile.macrobar
    if not bar then return {} end
    if phase == "infight" then
        if not (self.macroRaid and self.macroBoss) then
            self.macroRaid, self.macroBoss = self:DefaultMacroBoss()
        end
        if not (self.macroRaid and self.macroBoss) then return {} end
        local mb = RLSuite.macrobar
        if mb and mb.BossMacroTable then
            return mb:BossMacroTable(self.macroRaid, self.macroBoss, true) or {}
        end
    end
    bar.macros = bar.macros or {}
    bar.macros[phase] = bar.macros[phase] or {}
    return bar.macros[phase]
end

function CFG:SaveMacroSlot()
    if self.macroLoading then return end
    local index = self.macroEditIndex
    if not index then return end
    local macros = self:GetMacroDB()
    local current = macros[index] or {}
    current.text = (self.macroBodyEdit and self.macroBodyEdit:GetText()) or current.text or ""
    current.name = (self.macroNameEdit and self.macroNameEdit:GetText()) or current.name or ""
    current.icon = self.macroEditIcon or current.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    macros[index] = current
    local phase = self.macroPhase or "preraid"
    if RLSuite.macrobar and RLSuite.macrobar.LoadMacrosForPhase then
        if (RLSuite.context or "preraid") == phase then
            RLSuite.macrobar:LoadMacrosForPhase(phase)
        end
    end
    self:RefreshMacroPreview()
end

function CFG:SaveMacroLine(index, text)
    local macros = self:GetMacroDB()
    local current = macros[index] or {text = "", icon = "Interface\\Icons\\INV_Misc_QuestionMark"}
    current.text = text or ""
    current.icon = current.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    macros[index] = current
    local phase = self.macroPhase or "preraid"
    if RLSuite.macrobar and RLSuite.macrobar.LoadMacrosForPhase then
        if (RLSuite.context or "preraid") == phase then
            RLSuite.macrobar:LoadMacrosForPhase(phase)
        end
    end
    self:RefreshMacroPreview()
end

function CFG:RefreshMacroTab()
    self:RefreshMacroPreview()
end

function CFG:MacroPreviewText(data)
    if not data then return "" end
    local name = data.name or ""
    local text = data.text or ""
    text = string.gsub(text, "\n", " | ")
    if name ~= "" and text ~= "" then
        return name .. "  " .. text
    end
    if name ~= "" then return name end
    return text
end

function CFG:RefreshMacroList()
    local macros = self:GetMacroDB(self.macroPhase)
    local sel = self.macroEditIndex
    for i, row in ipairs(self.macroListRows or {}) do
        local data = macros[i]
        if row.fs then
            local line = self:MacroPreviewText(data)
            if line == "" then line = " " end
            row.fs:SetText(line)
            if sel == i then
                row.fs:SetTextColor(1, 0.82, 0)
            else
                row.fs:SetTextColor(0.9, 0.9, 0.9)
            end
        end
    end
end

function CFG:RefreshMacroPreview()
    local macros = self:GetMacroDB(self.macroPhase)
    for i, btn in ipairs(self.macroPreviewBtns or {}) do
        local data = macros[i]
        if btn and btn.icon then
            local icon = (data and data.icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
            if data and ((data.text and data.text ~= "") or (data.name and data.name ~= "") or data.icon) then
                btn.icon:SetTexture(icon)
            else
                btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
    end
    self:RefreshMacroList()
end

-- ============================================================
-- Apply
-- ============================================================

function CFG:RestoreMacroBar()
    if RLSuite.macrobar and RLSuite.macrobar.EnsurePhases then
        RLSuite.macrobar:EnsurePhases()
    end
    local mb = RLSuite.db.profile.macrobar
    mb.enabled = true
    mb.locked = true
    mb.backdrop = true
    mb.showEmpty = true
    mb.mouseover = false
    mb.inheritGlobalFade = false
    mb.buttons = 12
    mb.columns = 12
    mb.buttonSize = 32
    mb.spacing = 2
    mb.backdropSpacing = 2
    mb.heightMult = 1
    mb.widthMult = 1
    mb.alpha = 1
    mb.scale = 1
    mb.point, mb.relPoint, mb.x, mb.y = "BOTTOMLEFT", "BOTTOMLEFT", 4, 4
    mb.actionPaging = "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 8; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10;"
    mb.visibility = ""
    mb.keybinds = {}
    if RLSuite.macrobar and RLSuite.macrobar.frame then
        RLSuite.macrobar.frame:ClearAllPoints()
        RLSuite.macrobar.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 4, 4)
    end
    self:ApplyAll()
    self:NotifyChange()
end

function CFG:ApplyAll()
    self.db = RLSuite.db.profile
    -- scale globale propagata ai moduli con layout proprio (Raid Frame
    -- HUD e MacroBar leggono la scala dal loro db)
    local gscale0 = ((self:EnsureAppearance() or {}).scale) or 1
    if self.db.raidframe then self.db.raidframe.scale = gscale0 end
    if self.db.macrobar then self.db.macrobar.scale = gscale0 end
    if RLSuite.macrobar then
        RLSuite.macrobar.db = RLSuite.db and RLSuite.db.profile.macrobar
        if RLSuite.macrobar.ApplyLayout then
            RLSuite.macrobar:ApplyLayout()
        end
    end
    RLSuite.utils:SkinAllWindows()
    if RLSuite.macrobar and RLSuite.macrobar.ApplyLayout then
        RLSuite.macrobar:ApplyLayout()
    end
    if RLSuite.raidFrame and RLSuite.raidFrame.ApplyLayout then
        RLSuite.raidFrame:ApplyLayout()
    end
    if RLSuite.mainWindow and RLSuite.mainWindow.ApplyLayout then
        RLSuite.mainWindow:ApplyLayout()
    end
    -- Scala GLOBALE: lo slider Scale di General governa TUTTI i moduli
    -- (i cursori per-modulo sono stati rimossi dal pannello).
    local gscale = ((self:EnsureAppearance() or {}).scale) or 1
    local function scale(fr)
        if not fr then return end
        local parent = fr.GetParent and fr:GetParent()
        if RLSuite.mainWindow and RLSuite.mainWindow.frame and parent == RLSuite.mainWindow.frame then
            fr:SetScale(1)
            return
        end
        fr:SetScale(gscale)
    end
    scale(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame)
    scale(RLSuite.msManager and RLSuite.msManager.frame)
    scale(RLSuite.lootManager and RLSuite.lootManager.frame)
    scale(RLSuite.combatLog and RLSuite.combatLog.frame)
end

function CFG:ApplyTheme(theme)
    local a = self:EnsureAppearance()
    if theme then a.theme = theme end
    if a.theme and a.theme ~= "custom" then
        local p = RLSuite.utils:ThemePresets()[a.theme]
        if p then
            a.fill = { r = p.fill[1], g = p.fill[2], b = p.fill[3], a = 1 }
            a.bg = { r = p.bg[1], g = p.bg[2], b = p.bg[3], a = 1 }
            a.border = { r = p.border[1], g = p.border[2], b = p.border[3], a = 1 }
        end
    end
    self:ApplyAll()
    self:NotifyChange()
end
