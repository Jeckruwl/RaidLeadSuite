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

-- ------------------------------------------------------------------
-- Category tree (AceGUI TreeGroup) + node -> options path map.
-- Leaves map to an AceConfig path; the Macro Editor is a leaf whose
-- content is the bespoke in-window editor, not an AceConfig group.
-- ------------------------------------------------------------------
local CATEGORIES = {
    { value = "general", text = "General", children = {
        { value = "look",   text = "Appearance" },
        { value = "font",   text = "Font" },
        { value = "window", text = "Window" },
        { value = "debug",  text = "Debug" },
    } },
    { value = "savedraids", text = "Saved Raids" },
    { value = "groupmaking", text = "Groupmaking" },
    { value = "macros", text = "Macros", children = {
        { value = "layout", text = "Bar Layout" },
        { value = "editor", text = "Macro Editor" },
    } },
    { value = "raidframe", text = "Raid Frame", children = {
        { value = "layout", text = "Layout" },
        { value = "pos",    text = "Position" },
    } },
    { value = "ms", text = "MS" },
    { value = "loot", text = "Loot" },
}

local EDITOR_NODE = "macros\001editor"

local NODES = {
    ["general\001look"]    = { "general", "look" },
    ["general\001font"]    = { "general", "font" },
    ["general\001window"]  = { "general", "window" },
    ["general\001debug"]   = { "general", "debug" },
    ["savedraids"]         = { "savedraids" },
    ["groupmaking"]        = { "groupmaking" },
    ["macros\001layout"]   = { "macros", "layout" },
    [EDITOR_NODE]          = "__editor__",
    ["raidframe\001layout"] = { "raidframe", "layout" },
    ["raidframe\001pos"]    = { "raidframe", "pos" },
    ["ms"]                 = { "ms" },
    ["loot"]               = { "loot" },
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
    self:SelectNode("general\001look")
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

    -- --- General / Appearance ------------------------------------
    local look = {
        theme = select(L["Theme:"], L["Presets and background/border colors. Does not change functionality."], 1, themeValues,
            function() return a.theme or "default" end,
            function(_, v) self:ApplyTheme(v) end),
        fill = { type = "color", name = L["Background:"], desc = L["Window fill color."], order = 2,
            hasAlpha = true,
            get = function() return a.fill.r, a.fill.g, a.fill.b, a.fill.a or 1 end,
            set = function(_, r, g, b, alpha)
                a.fill = { r = r, g = g, b = b, a = alpha or 1 }
                a.theme = "custom"
                self:ApplyAll()
                self:NotifyChange()
            end },
        bg = { type = "color", name = L["Panel background:"], desc = L["Inner panel color."], order = 3,
            hasAlpha = true,
            get = function() return a.bg.r, a.bg.g, a.bg.b, a.bg.a or 1 end,
            set = function(_, r, g, b, alpha)
                a.bg = { r = r, g = g, b = b, a = alpha or 1 }
                a.theme = "custom"
                self:ApplyAll()
                self:NotifyChange()
            end },
        border = { type = "color", name = L["Borders:"], desc = L["Window border color."], order = 4,
            hasAlpha = true,
            get = function() return a.border.r, a.border.g, a.border.b, a.border.a or 1 end,
            set = function(_, r, g, b, alpha)
                a.border = { r = r, g = g, b = b, a = alpha or 1 }
                a.theme = "custom"
                self:ApplyAll()
                self:NotifyChange()
            end },
        edgeSize = slider(L["Border thickness"], nil, 5, 8, 48, 2,
            function() return a.edgeSize or 32 end,
            function(_, v) a.edgeSize = v; self:ApplyAll() end),
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

    -- --- General / Window ----------------------------------------
    local main = self:Layout("main")
    main.height = main.height or 700
    main.matrixCols = main.matrixCols or 2
    main.matrixRows = main.matrixRows or 4

    local window = {
        height = slider(L["Default window height"], nil, 1, 400, 900, 20,
            function() return main.height end,
            function(_, v) main.height = v end),
        barScale = slider(L["Bar scale"], nil, 2, 0.70, 1.30, 0.05,
            function() return main.scale or 1 end,
            function(_, v) main.scale = v end),
        matrixCols = slider(L["Columns"], L["Columns in the bar button matrix."], 3, 1, 8, 1,
            function() return main.matrixCols end,
            function(_, v) main.matrixCols = v end),
        matrixRows = slider(L["Buttons per column"], nil, 4, 1, 8, 1,
            function() return main.matrixRows end,
            function(_, v) main.matrixRows = v end),
        anchors = toggle(L["Toggle Anchors"], L["Unlocks the Raid Frame and MacroBar HUDs as movable placeholders."], 5,
            function() return prof().anchorMode == true end,
            function(_, v)
                if RLSuite.ApplyAnchorMode then
                    RLSuite:ApplyAnchorMode(v and true or false)
                end
            end),
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
        fakeLoot = execute(L["Fill fake loot"], nil, 2, function()
            if RLSuite.lootManager and RLSuite.lootManager.SpawnDebugLoot then
                RLSuite.lootManager:SpawnDebugLoot()
            end
        end),
    }

    local general = {
        look = { type = "group", name = L["Appearance"], order = 1, args = look },
        font = { type = "group", name = L["Font"], order = 2, args = font },
        window = { type = "group", name = L["Window"], order = 3, args = window },
        debug = { type = "group", name = L["Debug"], order = 4, args = debug },
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

    local savedraids = { type = "group", name = L["Saved Raids"], order = 2, args = savedArgs }

    -- --- Groupmaking ---------------------------------------------
    local groupmaking = {
        scale = slider(L["Scale"], nil, 1, 0.70, 1.30, 0.05,
            function() return self:Layout("groupmaking").scale end,
            function(_, v) self:Layout("groupmaking").scale = v; self:ApplyAll() end),
    }

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
        enable = toggle(L["Enable"], nil, 1,
            function() return mb.enabled ~= false end,
            function(_, v) mb.enabled = v; self:ApplyAll() end),
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
        scale = slider(L["Scale"], nil, 14, 0.50, 2.00, 0.05,
            function() return mb.scale or 1 end,
            function(_, v) mb.scale = v; self:ApplyAll() end),
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
    rf.width = rf.width or 350
    rf.scale = rf.scale or 1

    local raidLayout = {
        width = slider(L["Width"], nil, 1, 220, 500, 20,
            function() return rf.width end,
            function(_, v) rf.width = v; self:ApplyAll() end),
        barHeight = slider(L["HP bar height"], nil, 2, 12, 32, 1,
            function() return rf.appearance.barHeight or 20 end,
            function(_, v) rf.appearance.barHeight = v; self:ApplyAll() end),
        iconSize = slider(L["Icon size"], nil, 3, 10, 24, 1,
            function() return rf.appearance.iconSize or 16 end,
            function(_, v) rf.appearance.iconSize = v; self:ApplyAll() end),
        scale = slider(L["Scale"], nil, 4, 0.70, 1.50, 0.05,
            function() return rf.scale end,
            function(_, v) rf.scale = v; self:ApplyAll() end),
    }

    local raidPos = {
        locked = toggle(L["Lock position"], nil, 1,
            function() return rf.locked end,
            function(_, v) rf.locked = v end),
        reset = execute(L["Reset position"], nil, 2, function()
            rf.point, rf.relPoint, rf.x, rf.y = "LEFT", "LEFT", 10, 0
            if RLSuite.raidFrame and RLSuite.raidFrame.frame then
                RLSuite.raidFrame.frame:ClearAllPoints()
                RLSuite.raidFrame.frame:SetPoint("LEFT", UIParent, "LEFT", 10, 0)
            end
        end),
    }

    local raidframe = {
        layout = { type = "group", name = L["Layout"], order = 1, args = raidLayout },
        pos = { type = "group", name = L["Position"], order = 2, args = raidPos },
    }

    -- --- MS / Loot scales ----------------------------------------
    local ms = {
        scale = slider(L["Scale"], nil, 1, 0.70, 1.30, 0.05,
            function() return self:Layout("ms").scale end,
            function(_, v) self:Layout("ms").scale = v; self:ApplyAll() end),
    }
    local loot = {
        scale = slider(L["Scale"], nil, 1, 0.70, 1.30, 0.05,
            function() return self:Layout("loot").scale end,
            function(_, v) self:Layout("loot").scale = v; self:ApplyAll() end),
    }

    return {
        type = "group",
        name = "RLSuite",
        args = {
            general = { type = "group", name = L["General"], order = 1, args = general },
            savedraids = savedraids,
            groupmaking = { type = "group", name = L["Groupmaking"], order = 3, args = groupmaking },
            macros = { type = "group", name = L["Macros"], order = 4, args = macros },
            raidframe = { type = "group", name = L["Raid Frame"], order = 5, args = raidframe },
            ms = { type = "group", name = L["MS Manager"], order = 6, args = ms },
            loot = { type = "group", name = L["Loot Manager"], order = 7, args = loot },
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

    -- riga 1: selezione fase + toggle HUD
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
        btn:SetSize(70, 20)
        btn:SetPoint("LEFT", phaseLabel, "RIGHT", 6 + (i - 1) * 76, 0)
        btn:SetText(pdata.label)
        btn.phaseKey = pdata.key
        btn:SetScript("OnClick", function()
            self:SelectMacroPhase(pdata.key)
        end)
        self.macroPhaseBtns[pdata.key] = btn
    end

    local hudBtn = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
    hudBtn:SetSize(120, 20)
    hudBtn:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -8, -6)
    hudBtn:SetText("HUD on/off")
    hudBtn:SetScript("OnClick", function()
        if RLSuite.macrobar and RLSuite.macrobar.Toggle then
            RLSuite.macrobar:Toggle()
        end
    end)

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
    capsBtn:SetSize(56, 18)
    capsBtn:SetPoint("LEFT", util, "LEFT", 8 * 22 + 6, 0)
    capsBtn:SetText("CAPS")
    capsBtn:SetScript("OnClick", function()
        self:ToggleMacroCaps()
    end)

    self:HookMacroInsertLink()
    self:CreateMacroIconPicker(editor)
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

    local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() picker:Hide() end)

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

function CFG:GetMacroDB(phase)
    phase = phase or self.macroPhase or "preraid"
    if not RLSuite.db or not RLSuite.db.profile.macrobar then return {} end
    RLSuite.db.profile.macrobar.macros = RLSuite.db.profile.macrobar.macros or {}
    RLSuite.db.profile.macrobar.macros[phase] = RLSuite.db.profile.macrobar.macros[phase] or {}
    return RLSuite.db.profile.macrobar.macros[phase]
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
    local lay = self.db.layout or {}
    local function scale(fr, key)
        if not fr or not lay[key] or not lay[key].scale then return end
        local parent = fr.GetParent and fr:GetParent()
        if RLSuite.mainWindow and RLSuite.mainWindow.frame and parent == RLSuite.mainWindow.frame then
            fr:SetScale(1)
            return
        end
        fr:SetScale(lay[key].scale)
    end
    scale(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame, "groupmaking")
    scale(RLSuite.msManager and RLSuite.msManager.frame, "ms")
    scale(RLSuite.lootManager and RLSuite.lootManager.frame, "loot")
    local mw = RLSuite.mainWindow
    if mw and mw.tabPanels then
        scale(mw.tabPanels.raidframe, "raidframe")
    end
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
