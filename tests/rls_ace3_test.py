import sys, os
from lupa import LuaRuntime

# ---------------------------------------------------------------------------
# Mock WoW environment (rich enough for the real Ace3 libs + the addon)
# ---------------------------------------------------------------------------
MOCK = r"""
LOGGED_IN = false
CHAT_LOG = {}
EVENT_REG = {}          -- frame -> {event=true}
FRAMES = {}             -- name -> frame

local methods = {}
local FrameMT = { __index = methods }

local function newFrame(t)
    local o = setmetatable(t or {}, FrameMT)
    o._w = 0; o._h = 0; o._shown = true
    o._points = {}; o._text = ""; o._checked = false; o._scripts = {}
    o._backdropColor = {0,0,0,1}; o._isFontString = false
    o._wordWrap = false; o._locked = false; o._highlight = false
    o._fontHeight = 14
    return o
end

function methods:SetPoint(...) self._points[#self._points+1] = {...}; return self end
function methods:ClearAllPoints() self._points = {}; return self end
function methods:GetPoint(i)
    local p = self._points[i or 1] or {}
    return unpack(p)
end
function methods:SetSize(w,h) self._w=w; self._h=h; return self end
function methods:SetWidth(w) self._w=w; return self end
function methods:SetHeight(h) self._h=h; return self end
function methods:GetWidth() return self._w end
function methods:GetHeight() return self._h end
function methods:Show() self._shown=true; return self end
function methods:Hide() self._shown=false; return self end
function methods:IsShown() return self._shown end
function methods:IsVisible() return self._shown end
function methods:SetParent(p) self._parent=p; return self end
function methods:GetParent() return self._parent end
function methods:SetFrameStrata(s) self._strata = s; return self end
function methods:SetFrameLevel(l) self._level = l; return self end
function methods:EnableMouse(b) self._enabledMouse = b and true or false; return self end
function methods:EnableKeyboard(b) return self end
function methods:SetMovable(b) return self end
function methods:SetResizable(b) return self end
function methods:RegisterForDrag(...) self._dragButtons = {...}; return self end
function methods:RegisterForClicks(...) self._clickButtons = {...}; return self end
function methods:SetAttribute(k, v) self._attrs = self._attrs or {}; self._attrs[k] = v; return self end
function methods:GetAttribute(k) return self._attrs and self._attrs[k] or nil end
function methods:RegisterEvent(e)
    EVENT_REG[self] = EVENT_REG[self] or {}
    EVENT_REG[self][e] = true
    return self
end
function methods:UnregisterEvent(e)
    if EVENT_REG[self] then EVENT_REG[self][e] = nil end
    return self
end
function methods:SetScript(k, fn) self._scripts[k]=fn; return self end
function methods:GetScript(k) return self._scripts[k] end
function methods:HookScript(k, fn)
    local old = self._scripts[k]
    self._scripts[k] = function(...) if old then old(...) end fn(...) end
    return self
end
function methods:SetBackdrop(b) self._backdrop=b; return self end
function methods:SetBackdropColor(r,g,b,a) self._backdropColor={r,g,b,a}; return self end
function methods:SetBackdropBorderColor(r,g,b,a) self._backdropBorderColor={r,g,b,a}; return self end
function methods:CreateTexture(n, layer) local t=newFrame({_parent=self}); t._layer=layer; return t end
function methods:CreateFontString(n, layer, tmpl) local f=newFrame({}); f._layer=layer; f._isFontString=true; return f end
function methods:SetText(t) self._text = t or ""; return self end
function methods:GetText() return self._text end
function methods:SetFont(...) self._fontArgs = {...}; return self end
function methods:SetJustifyH(...) return self end
function methods:SetJustifyV(...) return self end
function methods:SetWordWrap(b) self._wordWrap = b and true or false; return self end
function methods:SetTextColor(...) self._tc = {...}; return self end
function methods:SetShadowColor(...) return self end
function methods:SetShadowOffset(...) return self end
function methods:SetMaxLines(...) return self end
function methods:GetStringHeight()
    if self._isFontString then
        if self._wordWrap and self._w and self._w > 0 then
            local cpl = math.max(1, math.floor(self._w / 7))
            local n = math.max(1, math.ceil(#tostring(self._text) / cpl))
            return n * self._fontHeight
        end
        return self._fontHeight
    end
    return 0
end
function methods:GetStringWidth() return #tostring(self._text) * 7 end
function methods:SetNormalTexture(...) return self end
function methods:SetPushedTexture(...) return self end
function methods:SetHighlightTexture(...) return self end
function methods:SetChecked(b) self._checked = b and true or false; return self end
function methods:GetChecked() return self._checked end
function methods:SetAutoFocus(...) return self end
function methods:SetMaxLetters(...) return self end
function methods:SetNumeric(...) return self end
function methods:SetMultiLine(...) return self end
function methods:ClearFocus() return self end
function methods:HasFocus() return false end
function methods:Insert(t) return self end
function methods:SetScrollChild(c) self._scrollChild=c; return self end
function methods:SetVerticalScroll(v) return self end
function methods:GetVerticalScrollRange() return 0 end
function methods:SetValue(v) self._value=v; return self end
function methods:SetValueStep(s) self._valueStep=s; return self end
function methods:GetValueStep() return self._valueStep end
function methods:SetObeyStepOnDrag(...) return self end
function methods:SetThumbTexture(...) return self end
function methods:GetMinMaxValues() return 0, 100 end
function methods:GetValue() return self._value end
function methods:SetMinMaxValues(...) return self end
function methods:SetStatusBarTexture(...) self._statusbarTex = select(1, ...); return self end
function methods:SetStatusBarColor(...) return self end
function methods:SetAlpha(a) self._alpha = a; return self end
function methods:StartMoving() self._moving = true; return self end
function methods:StopMovingOrSizing() self._moving = false; return self end
function methods:StartSizing(...) return self end
function methods:SetMinResize(...) return self end
function methods:SetClampedToScreen(b) return self end
function methods:SetAllPoints(...) return self end
function methods:SetTexCoord(...) return self end
function methods:SetTexture(t) self._texture = t; return self end
function methods:SetBlendMode(...) return self end
function methods:SetVertexColor(...) return self end
function methods:SetColorTexture(...) return self end
function methods:SetHitRectInsets(...) return self end
function methods:SetID(...) return self end
function methods:SetScale(...) return self end
function methods:SetClipsChildren(...) return self end
function methods:GetName() return self._name end
function methods:SetOwner(...) return self end
function methods:AddLine(...) return self end
function methods:AddDoubleLine(...) return self end
function methods:AddMessage(m) table.insert(CHAT_LOG, tostring(m)); return self end
function methods:LockHighlight() self._highlight=true; self._locked=true; return self end
function methods:UnlockHighlight() self._highlight=false; self._locked=false; return self end
function methods:GetHighlightTexture() return nil end
function methods:Disable() self._disabled=true; return self end
function methods:Enable() self._disabled=false; return self end
function methods:IsEnabled() return not self._disabled end
function methods:GetFrameLevel() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:GetNumChildren() return 0 end
function methods:GetRegions() return {} end
function methods:GetChildren() return {} end
function methods:SetFormattedText(...) return self end


function methods:SetDrawLayer(...) return self end
function methods:EnableMouseWheel(b) return self end
function methods:EnableMouse(b) self._enabledMouse = b and true or false; return self end
function methods:SetToplevel(b) return self end
function methods:Raise() return self end
function methods:Lower() return self end
function methods:GetTop() return self end
function methods:IsMouseOver() return false end
function methods:SetTextInsets(...) return self end
function methods:SetCursorPosition(...) return self end
function methods:GetCursorPosition() return 0 end
function methods:HighlightText(...) return self end
function methods:SetHistoryLines(...) return self end
function methods:SetMaxBytes(...) return self end
function methods:GetNumber() return 0 end
function methods:SetNumber(...) return self end
function methods:AddHistoryLine(...) return self end
function methods:SetAutocomplete(...) return self end
function methods:SetOrientation(...) return self end
function methods:SetButtonState(...) return self end
function methods:GetButtonState() return "NORMAL" end
function methods:SetDisabledTexture(...) return self end
function methods:SetNormalFontObject(...) return self end
function methods:SetHighlightFontObject(...) return self end
function methods:SetFontObject(...) return self end
function methods:GetFontObject() return nil end
function methods:GetFont() return "Font", 12, "" end
function methods:SetHorizontalScroll(...) return self end
function methods:GetHorizontalScrollRange() return 0 end
function methods:GetScrollChild() return self._scrollChild end
function methods:GetRegions() return {} end
function methods:GetAnimationGroups() return {} end
function methods:GetObjectType() return self._type or "Frame" end
function methods:GetNumPoints() return #self._points end
function methods:SetPropagateKeyboardInput(...) return self end
function methods:SetPropagateMouseClicks(...) return self end
function methods:GetBackdrop() return self._backdrop end
function methods:GetBackdropColor() return unpack(self._backdropColor) end
function methods:IsForbidden() return false end
function methods:IsProtected() return false end
function methods:IsObjectType(t) return t == (self._type or "Frame") end
function methods:GetScale() return 1 end
function methods:GetAlpha() return 1 end
function methods:GetRight() return 0 end
function methods:GetLeft() return 0 end
function methods:GetTopEdge() return 0 end
function methods:GetBottom() return 0 end
function methods:GetCenter() return 0, 0 end
function methods:SetMovable(...) return self end
function methods:IsMovable() return true end
function methods:IsResizable() return false end
function methods:GetClampedToScreen() return true end
function methods:GetIndentedWordWrap() return false end
function methods:SetIndentedWordWrap(...) return self end

CreateFrame = function(typ, name, parent, template)
    local o = newFrame({ _type=typ, _name=name, _template=template, _parent = parent })
    if name then _G[name] = o; FRAMES[name] = o end
    return o
end
UIParent = newFrame({ _name = "UIParent" })
UIParent._w = 1920; UIParent._h = 1080
Minimap = newFrame({ _name = "Minimap" })
Minimap._w = 156; Minimap._h = 156
GameTooltip = newFrame({ _name = "GameTooltip" })
DEFAULT_CHAT_FRAME = newFrame({ _name = "DEFAULT_CHAT_FRAME" })
SlashCmdList = {}
hash_SlashCmdList = {}

LAST_ERROR = nil
function geterrorhandler() return function(err) LAST_ERROR = err; return err end end
function IsLoggedIn() return LOGGED_IN end
function GetTime() return os.clock() end
function IsMouseButtonDown(btn) return false end  -- mock: sempre rilasciato
function InCombatLockdown() return false end      -- mock: mai in combat
function TargetUnit(u) LAST_TARGET = u end          -- mock: registra target
function TargetByName(n) LAST_TARGNAME = n end       -- mock: registra target-by-name
function UnitExists(u) return false end             -- mock: nessuna unit reale (debug)
function time() return os.time() end
function date(fmt, t) return "2026-09-11" end
function GetGameTime() return 20, 30 end
function GetRealmName() return "TestRealm" end
function GetLocale() return "enUS" end
function UnitName(u) return "Testplayer" end
function UnitClass(u) return "Warrior", "WARRIOR" end
function UnitRace(u) return "Human" end
function UnitFactionGroup(u) return "Alliance" end
function UnitAffectingCombat(u) return false end
function IsInRaid() return false end
function GetNumRaidMembers() return 0 end
function GetNumGroupMembers() return 0 end
function GetRaidRosterInfo(i) return nil end
function IsRaidLeader() return false end
function IsRaidOfficer() return false end
function InviteUnit(name) end
function SendChatMessage(msg, typ, lang, dest) CHAT_LOG = CHAT_LOG or {}; CHAT_LOG[#CHAT_LOG+1] = tostring(typ) .. '|' .. tostring(msg) end
function GetItemInfo(link) return "Item", link, 4, 1, 1, 1, 1, 1, 1, "Interface\\Icons\\INV_Misc_QuestionMark" end
function GetItemQualityColor(q) return 1, 0.5, 0 end
function GetSpellInfo(id) return "Spell" end
function IsShiftKeyDown() return false end
function FormatWhisperTime(t) return tostring(t) end
function DoReadyCheck() end
function GetChannelName(c) return nil end
function UnitExists(u) return u == "player" end
function GetAddOnMetadata(...) return nil end
function IsAddOnLoaded(...) return false end
function LoadAddOn(...) return true, "loaded" end
function wipe(t) for k in pairs(t) do t[k]=nil end return t end
getglobal = function(name) return _G[name] end
setglobal = function(name, value) _G[name] = value end
tinsert = table.insert
tconcat = table.concat
tremove = table.remove
tselect = select

-- Lua 5.1 / WoW global compatibility shims (host runtime is Lua 5.5)
loadstring = load
unpack = table.unpack
strmatch = string.match
strfind = string.find
strsub = string.sub
strrep = string.rep
strlower = string.lower
strupper = string.upper
format = string.format
gsub = string.gsub
gmatch = string.gmatch
strsplit = function(sep, s)
    if not s then return nil end
    local parts = {}
    for part in string.gmatch(s, "([^" .. sep .. "]+)") do table.insert(parts, part) end
    return unpack(parts)
end
strjoin = function(sep, ...)
    local parts = {...}
    return table.concat(parts, sep)
end

-- ===== AceGUI / AceConfig support (real libraries) =====
-- WoW 3.3.5 extends the string library with these; host Lua 5.5 does not.
strtrim = function(s, chars)
    if type(s) ~= "string" then return "" end
    if chars then
        return (s:gsub("^[" .. chars .. "]+", ""):gsub("[" .. chars .. "]+$", ""))
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
string.trim = strtrim
string.split = strsplit
string.join = strjoin

local function makeFont(name)
    return newFrame({ _isFontString = true, _name = name, _text = name })
end
GameFontNormal = makeFont("GameFontNormal")
GameFontNormalSmall = makeFont("GameFontNormalSmall")
GameFontNormalLarge = makeFont("GameFontNormalLarge")
GameFontHighlight = makeFont("GameFontHighlight")
GameFontHighlightSmall = makeFont("GameFontHighlightSmall")
GameFontHighlightLarge = makeFont("GameFontHighlightLarge")
GameFontDisable = makeFont("GameFontDisable")
ChatFontNormal = makeFont("ChatFontNormal")
NumberFontNormal = makeFont("NumberFontNormal")

PlaySound = function() end
hooksecurefunc = function() end
unhooksecurefunc = function() end
SetDesaturation = function() end
GetDesaturation = function() return false end
PanelTemplates_TabResize = function() end
PanelTemplates_SetDisabledTabState = function() end
PanelTemplates_SelectTab = function() end
PanelTemplates_DeselectTab = function() end
PanelTemplates_GetTabWidth = function() return 64 end
PanelTemplates_DisableTab = function() end
PanelTemplates_EnableTab = function() end
-- Additional Unit APIs exercised by the Raid Frame HUD / debug path.
UnitHealth = function() return 100 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 100 end
UnitPowerMax = function() return 100 end
UnitIsDeadOrGhost = function() return false end
UnitIsConnected = function() return true end
UnitBuff = function() return nil end
UnitAura = function() return nil end
UnitLevel = function() return 80 end
UnitIsPlayer = function() return true end
UnitIsUnit = function() return true end
UnitGUID = function() return "guid" end
UnitPosition = function() return 0, 0, 0 end
UnitClassification = function() return "normal" end
UnitCreatureType = function() return "Humanoid" end
UnitGroupRolesAssigned = function() return "NONE" end
UnitHasSpellBuff = function() return nil end
UnitMana = function() return 100 end
UnitManaMax = function() return 100 end
UnitPowerType = function() return 0 end
UnitIsGhost = function() return false end
UnitIsDead = function() return false end
GetSpellCooldown = function() return 0, 0 end
GetSpellInfo = function() return "Spell", nil, "Interface\\Icons\\INV_Misc_QuestionMark" end
GetTime = function() return os.clock() end
CLOSE = "Close"
GetBuildInfo = function() return "3.3.5", 30300, 30300, 30300 end
CloseSpecialWindows = function() return nil end
StaticPopupDialogs = {}
StaticPopup_Show = function() return nil end
StaticPopup_Hide = function() return nil end
UIDropDownMenu_CreateInfo = function() return {} end
UIDropDownMenu_Initialize = function() end
UIDropDownMenu_AddButton = function() end
UIDropDownMenu_SetSelectedValue = function() end
UIDropDownMenu_SetText = function() end
UIDropDownMenu_GetSelectedValue = function() return nil end
ToggleDropDownMenu = function() end
CloseDropDownMenus = function() end
UIDropDownMenu_JustifyText = function() end
ColorPickerFrame = newFrame({ _name = "ColorPickerFrame" })
ColorPickerFrame.SetColorRGB = function() end
ColorPickerFrame.GetColorRGB = function() return 0, 0, 0 end
OpacitySliderFrame = newFrame({ _name = "OpacitySliderFrame" })
FauxScrollFrame_OnVerticalScroll = function() end
FauxScrollFrame_Update = function() end
FauxScrollFrame_GetOffset = function() return 0 end
GetNumMacroIcons = function() return 0 end
GetMacroIconInfo = function() return nil end
UISpecialFrames = {}

-- WoW returns children as varargs; AceGUI's fixlevels/fixstrata iterate
-- them with select(), so GetChildren must return no values, not a table.
function methods:GetChildren() end

-- Region getters AceGUI widgets rely on.
function methods:GetFontString()
    if not self._fontString then
        self._fontString = newFrame({ _isFontString = true, _name = (self:GetName() or "") .. "Text", _parent = self })
    end
    return self._fontString
end
local function _makeRegion(self, key)
    self._regions = self._regions or {}
    if not self._regions[key] then
        self._regions[key] = newFrame({ _name = (self:GetName() or "") .. key, _parent = self })
    end
    return self._regions[key]
end
function methods:GetNormalTexture() return _makeRegion(self, "NormalTexture") end
function methods:GetPushedTexture() return _makeRegion(self, "PushedTexture") end
function methods:GetHighlightTexture() return _makeRegion(self, "HighlightTexture") end
function methods:GetCheckedTexture() return _makeRegion(self, "CheckedTexture") end
function methods:GetDisabledTexture() return _makeRegion(self, "DisabledTexture") end
function methods:GetThumbTexture() return _makeRegion(self, "ThumbTexture") end
function methods:GetTexture() return self end
function methods:GetFrameStrata() return "DIALOG" end
function methods:GetNumLetters() return 0 end
function methods:GetTextWidth() return self:GetStringWidth() end
function methods:GetRightBorderWidth() return 0 end
function methods:GetVerticalScroll() return 0 end
function methods:SetCountInvisibleLetters(b) return self end
function methods:SetDesaturated(b) self._desat = b and true or false; return self end
function methods:SetGradient(...) return self end
function methods:SetGradientAlpha(...) return self end
function methods:SetSnapToPixelGrid(...) return self end
function methods:SetFocus() return self end
function methods:SetMaxResize(...) return self end
function methods:SetUserPlaced(b) return self end
function methods:SetHighlight(...) return self end
function methods:SetHighlightTexCoord(...) return self end

-- Synthesize the child regions that XML templates would normally create.
local _origCreateFrame = CreateFrame
local function _templateChildren(o, name, template)
    if not name then return end
    if template == "UIDropDownMenuTemplate" then
        local suffixes = {"Left", "Middle", "Right", "Button", "Text", "Icon", "NormalTexture", "HighlightTexture", "DisabledTexture", "List", "Menu"}
        for _, s in ipairs(suffixes) do
            _G[name .. s] = newFrame({ _name = name .. s, _parent = o })
        end
    elseif template == "OptionsFrameTabButtonTemplate" then
        local suffixes = {"Text", "Left", "Middle", "Right", "HighlightTexture", "CheckedTexture"}
        for _, s in ipairs(suffixes) do
            _G[name .. s] = newFrame({ _name = name .. s, _parent = o })
        end
    elseif template == "UIPanelScrollFrameTemplate" then
        _G[name .. "ScrollBar"] = newFrame({ _name = name .. "ScrollBar", _parent = o })
        _G[name .. "ScrollBarScrollUpButton"] = newFrame({ _name = name .. "ScrollBarScrollUpButton", _parent = o })
        _G[name .. "ScrollBarScrollDownButton"] = newFrame({ _name = name .. "ScrollBarScrollDownButton", _parent = o })
    elseif template == "OptionsListButtonTemplate" then
        -- AceGUI TreeGroup buttons: Blizzard's OptionsListButtonTemplate
        -- exposes a `text` FontString and a `toggle` expand/collapse button
        -- via XML `key` attributes (button.text / button.toggle).
        o.toggle = newFrame({ _name = name .. "Toggle", _parent = o })
        o.text = newFrame({ _name = name .. "Text", _parent = o, _isFontString = true })
    end
end
CreateFrame = function(typ, name, parent, template)
    local o = _origCreateFrame(typ, name, parent, template)
    _templateChildren(o, name, template)
    return o
end
"""

LIBS = [
    "Libs/LibStub/LibStub.lua",
    "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "Libs/AceAddon-3.0/AceAddon-3.0.lua",
    "Libs/AceEvent-3.0/AceEvent-3.0.lua",
    "Libs/AceDB-3.0/AceDB-3.0.lua",
    "Libs/AceConsole-3.0/AceConsole-3.0.lua",
    "Libs/AceTimer-3.0/AceTimer-3.0.lua",
    "Libs/AceLocale-3.0/AceLocale-3.0.lua",
    "Libs/AceGUI-3.0/AceGUI-3.0.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIContainer-BlizOptionsGroup.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIContainer-DropDownGroup.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIContainer-Frame.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIContainer-InlineGroup.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIContainer-ScrollFrame.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIContainer-SimpleGroup.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIContainer-TabGroup.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIContainer-TreeGroup.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIContainer-Window.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-Button.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-CheckBox.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-ColorPicker.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-DropDown.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-DropDown-Items.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-EditBox.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-Heading.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-Icon.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-InteractiveLabel.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-Keybinding.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-Label.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-MultiLineEditBox.lua",
    "Libs/AceGUI-3.0/widgets/AceGUIWidget-Slider.lua",
    "Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua",
    "Libs/AceConfig-3.0/AceConfigCmd-3.0/AceConfigCmd-3.0.lua",
    "Libs/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua",
    "Libs/AceConfig-3.0/AceConfig-3.0.lua",
]
ADDON_FILES = [
    "Locale.lua", "Utils.lua", "Core.lua", "RaidProfile.lua",
    "MacroBar.lua", "GroupMaking.lua", "RaidFrame.lua",
    "MSManager.lua", "LootManager.lua", "Config.lua",
]

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

LEGACY = r"""
_G.RLSuiteDB = {
    groupmaking = { raid = "Ulduar", difficulty = "25", hc = true,
        reserved = {}, reservedText = "res", aim = "aim", otherReq = "",
        comp = { { class="WARRIOR", role="tank" } },
        spamChannels = {"General"}, spamInterval = 90, showSpecsInMessage = true },
    whisplist = { entries = { { name="X", messages={} } }, autoinvite = { mode="calendar", hour=20 } },
    macrobar = { enabled = true, locked = false, buttons = 99, macros = { preraid = { { icon=1, text="hi" } } } },
    raidframe = { enabled = true, width = 500, alerts = { flask = "msg" } },
    loot = { history = { { id=7 } }, rollDuration = 15 },
    mschanges = { { name="P", spec="Frost" } },
    appearance = { theme = "classic", fontSize = 14 },
    layout = { main = { width = 800, height = 900, scale = 0.9 }, loot = { scale = 1.2 } },
    savedRaids = { { id=1, title="SaveA", time=123, data={} } },
    debug = true,
    anchorMode = true,
    difficulty = "25",
}
"""

def new_runtime(seed_legacy=False):
    rt = LuaRuntime(unpack_returned_tuples=True)
    rt.execute(MOCK)
    for path in LIBS:
        rt.execute(open(path, encoding="utf-8", errors="replace").read())
    for f in ADDON_FILES:
        rt.execute(open(f, encoding="utf-8", errors="replace").read())
    if seed_legacy:
        rt.execute(LEGACY)
    return rt

def fire(rt, frame_name, event, *args):
    code = "local f = FRAMES[%r]\n" % frame_name
    code += "if f and f._scripts.OnEvent then f._scripts.OnEvent(f, %r" % event
    for a in args:
        code += ", " + repr(a)
    code += ") end"
    rt.execute(code)

fails = []
def check(cond, label):
    print(("PASS: " if cond else "FAIL: ") + label)
    if not cond:
        fails.append(label)

# ---------------------------------------------------------------------------
# Scenario A: fresh database
# ---------------------------------------------------------------------------
print("== Scenario A: fresh database ==")
rt = new_runtime()
g = rt.globals()
fire(rt, "AceAddon30Frame", "ADDON_LOADED", "RaidLeadSuite")

RLS = g.RLSuite
check(RLS.db is not None, "RLSuite.db (AceDB object) exists after OnInitialize")
check(RLS.db.profile.macrobar.buttons == 12, "defaults live in db.profile (macrobar.buttons=12)")
check(RLS.db.profile.groupmaking.spamInterval == 60, "nested default present (groupmaking.spamInterval=60)")
check(RLS.addonFolder == "RaidLeadSuite", "addonFolder set from AceAddon.baseName (got %r)" % RLS.addonFolder)

sc = g.SlashCmdList
check(sc is not None and sc["ACECONSOLE_RLS"] is not None, "ACECONSOLE_RLS slash handler registered")
check(g.SLASH_ACECONSOLE_RLS1 == "/rls", "SLASH_ACECONSOLE_RLS1 == '/rls'")
check(g.SLASH_ACECONSOLE_RLSUITE1 == "/rlsuite", "SLASH_ACECONSOLE_RLSUITE1 == '/rlsuite'")

rt.execute("LOGGED_IN = true")
fire(rt, "AceAddon30Frame", "PLAYER_LOGIN")


check(RLS.groupmaking is not None and RLS.groupmaking.mainFrame is not None, "GroupMaking initialized (mainFrame created)")
check(RLS.macrobar is not None and RLS.macrobar.frame is not None, "MacroBar initialized (frame created)")
check(RLS.raidFrame is not None and RLS.raidFrame.frame is not None, "RaidFrame initialized")
check(RLS.msManager is not None and RLS.msManager.frame is not None, "MSManager initialized")
check(RLS.lootManager is not None and RLS.lootManager.frame is not None, "LootManager initialized")
check(RLS.config is not None and RLS.config.window is not None, "Config initialized (Ace3 window)")
check(RLS.mainWindow is not None and RLS.mainWindow.frame is not None, "MainWindow initialized")

for want in ["RAID_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "CHAT_MSG_WHISPER", "CHAT_MSG_LOOT", "CHAT_MSG_RAID"]:
    check(bool(rt.eval("(EVENT_REG[FRAMES['AceEvent30Frame']] or {})[%r] == true" % want)), "AceEvent registered %s" % want)

rt.execute("RLSuite.context = 'unknown'")
fire(rt, "AceEvent30Frame", "RAID_ROSTER_UPDATE")
check(g.RLSuite.context == "preraid", "RAID_ROSTER_UPDATE dispatch sets context 'preraid' (got %r)" % g.RLSuite.context)

# slash command dispatch -> ChatCommand
rt.execute("RLSuite.mainWindow.toggleCount = 0; RLSuite.mainWindow.Toggle = function(self) self.toggleCount = self.toggleCount + 1 end")
rt.execute("SlashCmdList['ACECONSOLE_RLS']('')")
check(g.RLSuite.mainWindow.toggleCount == 1, "/rls (empty) toggles the main window")

# minimap icon: faction texture + left/right click + drag + config icon gone
check(bool(rt.eval("RLSuite.minimapIcon ~= nil")), "minimap icon created at login")
check(bool(rt.eval("RLSuite:IsHorde() == false")), "Alliance player -> IsHorde() false")
check(bool(rt.eval("RLSuite.minimapIcon.icon ~= nil")), "minimap icon has a texture")
check(bool(rt.eval("RLSuite.minimapIcon.icon._texture == 'Interface\\\\AddOns\\\\RaidLeadSuite\\\\media\\\\allianceicon.blp'")), "minimap icon uses allianceicon.blp for an Alliance player")
check(bool(rt.eval("RLSuite.mainWindow.configBtn == nil")), "config gear icon removed from the main bar")
rt.execute("RLSuite.mainWindow.toggleCount = 0")
rt.execute("local b = RLSuite.minimapIcon; if b._scripts.OnClick then b._scripts.OnClick(b, 'LeftButton') end")
check(g.RLSuite.mainWindow.toggleCount == 1, "minimap left click toggles the main bar")
rt.execute("local saved = RLSuite.config.Toggle; RLSuite.config.Toggle = function() RLSuite.config._spy = (RLSuite.config._spy or 0) + 1 end; local b = RLSuite.minimapIcon; if b._scripts.OnClick then b._scripts.OnClick(b, 'RightButton') end; RLSuite.config.Toggle = saved")
check(bool(rt.eval("RLSuite.config._spy == 1")), "minimap right click opens Config")
rt.execute("local b = RLSuite.minimapIcon; if b._scripts.OnDragStart then b._scripts.OnDragStart(b) end")
check(bool(rt.eval("RLSuite.minimapIcon.dragging == nil")), "drag without Shift does not move the minimap icon")
rt.execute("IsShiftKeyDown = function() return true end")
rt.execute("local b = RLSuite.minimapIcon; if b._scripts.OnDragStart then b._scripts.OnDragStart(b) end")
check(bool(rt.eval("RLSuite.minimapIcon.dragging == true")), "Shift + left drag starts moving the minimap icon")
rt.execute("IsShiftKeyDown = function() return false end")  # runtime condiviso: ripristina Shift per gli scenari successivi

# save raid + load raid round trip through the new profile
rt.execute("SAVED_ID = RLSuite:SaveRaid('TestRaid')")
rt.execute("RLSuite:LoadRaid(SAVED_ID)")
check(g.SAVED_ID == 1, "SaveRaid returns id 1 on a fresh profile")
check(rt.eval("#RLSuite.db.profile.savedRaids") == 1, "saved raid stored in db.profile.savedRaids")

print()
print("== Scenario B: legacy flat DB migration ==")
rt2 = new_runtime(seed_legacy=True)
g2 = rt2.globals()
fire(rt2, "AceAddon30Frame", "ADDON_LOADED", "RaidLeadSuite")
check(g2.RLSuite.db.profile.groupmaking.raid == "Ulduar", "legacy groupmaking.raid migrated -> 'Ulduar'")
check(g2.RLSuite.db.profile.macrobar.buttons == 99, "legacy macrobar.buttons migrated -> 99")
check(g2.RLSuite.db.profile.debug == True, "legacy debug=true migrated")
check(g2.RLSuite.db.profile.anchorMode == True, "legacy anchorMode=true migrated")
check(rt2.eval("#RLSuite.db.profile.savedRaids") == 1, "legacy savedRaids migrated (1 entry)")
check(g2.RLSuite.db.profile.loot.rollDuration == 15, "legacy loot.rollDuration migrated -> 15")
check(g2.RLSuite.db.profile.whisplist.autoinvite.mode == "calendar", "legacy autoinvite.mode migrated -> 'calendar'")


print()
print("== Scenario A2: module AceTimer/AceEvent behavior ==")
# GroupMaking spammer -> AceTimer
rt.execute("RLSuite.groupmaking:StartSpam()")
check(bool(rt.eval("RLSuite.groupmaking.spamTimer ~= nil")), "StartSpam schedules a repeating AceTimer")
rt.execute("RLSuite.groupmaking:StopSpam()")
check(bool(rt.eval("RLSuite.groupmaking.spamTimer == nil")), "StopSpam cancels the spam AceTimer")

# MSManager 40s listen -> AceTimer one-shot
rt.execute("RLSuite.msManager:RequestChanges()")
check(bool(rt.eval("RLSuite.msManager.listenTimer ~= nil")), "RequestChanges schedules a listen AceTimer")
check(bool(rt.eval("RLSuite.msManager.listening == true")), "RequestChanges sets listening=true")
rt.execute("RLSuite.msManager:StopListening(false)")
check(bool(rt.eval("RLSuite.msManager.listenTimer == nil")), "StopListening cancels the listen AceTimer")

# LootManager roll -> AceEvent CHAT_MSG_SYSTEM registration
rt.execute("RLSuite.lootManager:AddToHistory('|cffff8000|Hitem:1|h[Test]|h|r', 'Test Item', 'tex', 4)")
rt.execute("RLSuite.lootManager:SelectItem(RLSuite.lootManager.history[1])")
rt.execute("RLSuite.lootManager:StartRoll('MS')")
check(bool(rt.eval("(EVENT_REG[FRAMES['AceEvent30Frame']] or {})['CHAT_MSG_SYSTEM'] == true")), "StartRoll registers CHAT_MSG_SYSTEM via AceEvent")
rt.execute("RLSuite.lootManager.currentRoll.rolls = { { name='A', roll=100 } }")
rt.execute("RLSuite.lootManager:AnnounceWinner()")
check(bool(rt.eval("(EVENT_REG[FRAMES['AceEvent30Frame']] or {})['CHAT_MSG_SYSTEM'] ~= true")), "AnnounceWinner unregisters CHAT_MSG_SYSTEM")

# RaidFrame periodic refresh -> AceTimer; unit event -> UpdateUnit
check(bool(rt.eval("RLSuite.raidFrame.RegisterEvent ~= nil")), "RaidFrame embedded AceEvent (RegisterEvent present)")
try:
    fire(rt, "AceEvent30Frame", "UNIT_HEALTH", "player")
    print("PASS: UNIT_HEALTH dispatch -> RF:UpdateUnit (no error)")
except Exception as e:
    check(False, "UNIT_HEALTH dispatch errored: %s" % str(e)[:200])

check(rt.eval("LAST_ERROR") is None or rt.eval("LAST_ERROR") == None, "no errors during scenario A init (LAST_ERROR=%r)" % rt.eval("LAST_ERROR"))
check(rt2.eval("LAST_ERROR") is None or rt2.eval("LAST_ERROR") == None, "no errors during scenario B init (LAST_ERROR=%r)" % rt2.eval("LAST_ERROR"))


print()
print("== Scenario C: Config (single Ace3 window + AceConfigDialog) ==")
# The old raw "Config" frame is gone; the config surface is ONE Ace3 window.
check(bool(rt.eval("RLSuite.config.window ~= nil and RLSuite.config.window.type == 'Window'")), "Config is an AceGUI Window (Ace3)")
check(bool(rt.eval("RLSuite.config.frame == nil")), "old raw 'Config' frame no longer exists")
check(bool(rt.eval("_G.RLSuiteConfig == nil")), "no RLSuiteConfig global frame is created")
check(bool(rt.eval("RLSuite.config.tree ~= nil and RLSuite.config.tree.type == 'TreeGroup'")), "config uses an AceGUI TreeGroup navigation")
check(bool(rt.eval("LibStub('AceConfigRegistry-3.0'):GetOptionsTable('RLSuite', 'dialog', 'AceConfigDialog-3.0') ~= nil")), "RLSuite options table registered with AceConfigRegistry")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().type == 'group'")), "BuildOptionsTable returns a root group")

# Every category from the old window is still present in the options table.
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.general.type == 'group'")), "General category present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.type == 'group'")), "Saved Raids category present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.groupmaking.type == 'group'")), "Groupmaking category present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.macros.args.layout.type == 'group'")), "Macros -> Bar Layout present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.pos ~= nil")), "Raid Frame -> Position present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.ms.type == 'group'")), "MS category present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.loot.type == 'group'")), "Loot category present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.args.save1load ~= nil")), "saved raids rendered as Load/Delete executes (dynamic)")

# The navigation tree lists all 7 categories, with the Macro Editor as a node.
rt.execute("local t = RLSuite.config.tree.tree; CATS = {}; for _,n in ipairs(t) do CATS[n.value] = n end")
check(bool(rt.eval("CATS.general ~= nil and CATS.savedraids ~= nil and CATS.groupmaking ~= nil and CATS.macros ~= nil and CATS.raidframe ~= nil and CATS.ms ~= nil and CATS.loot ~= nil")), "tree lists all 7 categories")
check(bool(rt.eval("CATS.macros.children[1].value == 'layout' and CATS.macros.children[2].value == 'editor'")), "Macros node has Bar Layout + Macro Editor children")
check(bool(rt.eval("CATS.general.children[1].value == 'look' and CATS.general.children[4].value == 'debug'")), "General node has Appearance/Font/Window/Debug children")

# theme select get/set through the AceConfig closures
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.general.args.look.args.theme.get() == 'default'")), "theme get() -> 'default' on fresh profile")
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.look.args.theme.set(nil, 'gold')")
check(bool(rt.eval("RLSuite.db.profile.appearance.theme == 'gold'")), "theme set('gold') writes appearance.theme")
check(bool(rt.eval("RLSuite.db.profile.appearance.fill.r == 0.10")), "theme set applies the gold preset fill color")

# color get returns 4 channels; set writes rgb and switches to 'custom'
rt.execute("local t = RLSuite.config:BuildOptionsTable().args.general.args.look.args.fill; local r,g,b,a = t.get(); C_CHAN = {r,g,b,a}")
check(bool(rt.eval("type(C_CHAN[1]) == 'number' and C_CHAN[4] == 1")), "color get() returns 4 numeric channels")
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.look.args.fill.set(nil, 0.25, 0.5, 0.75, 1)")
check(bool(rt.eval("RLSuite.db.profile.appearance.fill.r == 0.25 and RLSuite.db.profile.appearance.fill.b == 0.75")), "color set() writes r/g/b")
check(bool(rt.eval("RLSuite.db.profile.appearance.theme == 'custom'")), "color set() switches theme to 'custom'")

# anchor toggle drives ApplyAnchorMode
rt.execute("RLSuite.db.profile.anchorMode = false")
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.window.args.anchors.set(nil, true)")
check(bool(rt.eval("RLSuite.db.profile.anchorMode == true")), "anchors set(true) -> ApplyAnchorMode -> anchorMode=true")

# debug toggle
rt.execute("RLSuite.db.profile.debug = false")
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.debug.args.debugMode.set(nil, true)")
check(bool(rt.eval("RLSuite.db.profile.debug == true")), "debugMode set(true) writes profile.debug")

# saved raids dynamic list via NotifyChange
rt.execute("local idC = RLSuite:SaveRaid('ScenarioC'); SC_ID = idC")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.args.save2load ~= nil")), "saved raid appears as a Load execute in the options table")
rt.execute("RLSuite:DeleteSavedRaid(SC_ID)")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.args.save2load == nil")), "deleting the raid removes its option")

# Node selection feeds the matching AceConfig path into the tree content.
check(bool(rt.eval("RLSuite.config.OpenMacroEditorPanel ~= nil and RLSuite.config.CreateMacroEditor ~= nil")), "Macro Editor API preserved")
rt.execute("RLSuite.config:SelectNode('general' .. string.char(1) .. 'look')")
check(bool(rt.eval("RLSuite.config.currentNode == 'general' .. string.char(1) .. 'look'")), "SelectNode routes to general/look")
check(bool(rt.eval("RLSuite.config.tree:GetUserData('basepath') ~= nil and RLSuite.config.tree:GetUserData('basepath')[1] == 'general' and RLSuite.config.tree:GetUserData('basepath')[2] == 'look'")), "general/look feeds at the general.look path")
check(bool(rt.eval("#RLSuite.config.tree.children == 1")), "options rendered into the tree content area")

# The Macro Editor lives inside the same window, under the Macros node.
rt.execute("RLSuite.config:OpenMacroEditorPanel()")
check(bool(rt.eval("RLSuite.config.currentNode == 'macros' .. string.char(1) .. 'editor'")), "OpenMacroEditorPanel selects the Macros -> Macro Editor node")
check(bool(rt.eval("RLSuite.config.macroEditorPanel ~= nil and RLSuite.config.macroEditorPanel:IsShown()")), "editor shown inside the window")
check(bool(rt.eval("RLSuite.config.macroEditorPanel:GetParent() == RLSuite.config.tree.content")), "editor parented inside the tree content area")
check(bool(rt.eval("#RLSuite.config.tree.children == 0")), "AceConfig controls released while the editor is open")

# Switching back to Bar Layout hides the editor and re-renders the options.
rt.execute("RLSuite.config:SelectNode('macros' .. string.char(1) .. 'layout')")
check(bool(rt.eval("RLSuite.config.macroEditorPanel:IsShown() == false")), "switching to Bar Layout hides the editor")
check(bool(rt.eval("RLSuite.config.tree:GetUserData('basepath') ~= nil and RLSuite.config.tree:GetUserData('basepath')[1] == 'macros' and RLSuite.config.tree:GetUserData('basepath')[2] == 'layout'")), "Bar Layout feeds at the macros.layout path")

# Toggle / NotifyChange through the Ace3 window
rt.execute("RLSuite.config:CloseWindow()")
check(bool(rt.eval("RLSuite.config:IsOpen() == false")), "window closed via CloseWindow")
rt.execute("RLSuite.config:Toggle()")
check(bool(rt.eval("RLSuite.config:IsOpen() == true and RLSuite.config.window.frame:IsShown() == true")), "Toggle opens the Ace3 window")
rt.execute("RLSuite.config:SelectNode('savedraids')")
check(bool(rt.eval("RLSuite.config.tree:GetUserData('basepath') ~= nil and RLSuite.config.tree:GetUserData('basepath')[1] == 'savedraids'")), "savedraids node feeds at the savedraids path")
rt.execute("RLSuite.config:NotifyChange()")
check(bool(rt.eval("RLSuite.config.currentNode == 'savedraids'")), "NotifyChange re-renders the current node without error")
rt.execute("RLSuite.config:Toggle()")
check(bool(rt.eval("RLSuite.config:IsOpen() == false")), "Toggle closes the Ace3 window")

print()
print("== Scenario D: new features (Lim/Aim spam, phase, debug roster/whispers, Autoinviter) ==")

# --- Phase indicator: left = forward, right = backward ---
rt.execute("RLSuite:SetContextPhase('preraid')")
rt.execute("RLSuite:CycleContextPhase(1)")
check(g.RLSuite.context == "preboss", "phase forward: preraid -> preboss (left click)")
rt.execute("RLSuite:CycleContextPhase(1)")
check(g.RLSuite.context == "infight", "phase forward: preboss -> infight")
rt.execute("RLSuite:CycleContextPhase(-1)")
check(g.RLSuite.context == "preboss", "phase backward: infight -> preboss (right click)")
rt.execute("RLSuite:CycleContextPhase(-1)")
check(g.RLSuite.context == "preraid", "phase backward: preboss -> preraid")

# --- Spammer "Lim" = the Aim field, between difficulty/HC and Need ---
rt.execute("RLSuite.groupmaking.db.hc = false")
rt.execute("RLSuite.groupmaking.db.showSpecsInMessage = false")
rt.execute("RLSuite.groupmaking.aimEdit:SetText('GS 5800+')")
rt.execute("RLSuite.groupmaking.reservedEdit:SetText('Valanyr')")
rt.execute("RLSuite.groupmaking.otherEdit:SetText('no hunters')")
rt.execute("RLSuite.groupmaking:FillSlot(1, 'WARRIOR', 'tank', nil, 'prot')")
rt.execute("SPAM_MSG = RLSuite.groupmaking:BuildSpamMessage()")
check(bool(rt.eval("SPAM_MSG:find('LFM ', 1, true) == 1")), "spam starts with LFM")
check(bool(rt.eval("SPAM_MSG:find('GS 5800+', 1, true) ~= nil")), "Aim ('Lim') text present in the message")
check(bool(rt.eval("(SPAM_MSG:find('GS 5800+', 1, true) or 0) < (SPAM_MSG:find('Need', 1, true) or 0)")), "Aim text sits before 'Need'")
check(bool(rt.eval("(SPAM_MSG:find('Need', 1, true) or 0) < (SPAM_MSG:find('Res', 1, true) or 0)")), "'Need' sits before 'Res'")
check(bool(rt.eval("(SPAM_MSG:find('Res', 1, true) or 0) < (SPAM_MSG:find('no hunters', 1, true) or 0)")), "Other requirements still at the end (after Res)")
rt.execute("RLSuite.groupmaking:ClearSlot(1)")

# --- Debug mode: shared simulated roster used by Raid Frame + Raid Group ---
rt.execute("RLSuite.db.profile.debug = true")
rt.execute("RLSuite:ApplyDebugMode()")
check(bool(rt.eval("#RLSuite:DebugRoster() == 1")), "debug roster starts with just the player")
rt.execute("local t = RLSuite.groupmaking.wlGroupSlots[1].nameFS and RLSuite.groupmaking.wlGroupSlots[1].nameFS:GetText() or ''; P_IN_GROUP = t")
check(bool(rt.eval("P_IN_GROUP == 'Testplayer'")), "Raid Group panel shows the player right after debug is enabled")
rt.execute("RLSuite:DebugInviteAccept('Drakbot', 'WARRIOR')")
check(bool(rt.eval("#RLSuite:DebugRoster() == 2")), "DebugInviteAccept adds the fake player")
check(bool(rt.eval("#RLSuite.raidFrame:GetRoster() == 2")), "Raid Frame reads the shared debug roster (2 members)")
check(bool(rt.eval("#RLSuite.raidFrame.rows == 2")), "Raid Frame rebuilds its rows from the debug roster after invite")
rt.execute("local found=false; for _,s in ipairs(RLSuite.groupmaking.wlGroupSlots) do if s.nameFS and s.nameFS:GetText()=='Drakbot' then found=true end end; DRAK_IN_GROUP = found")
check(bool(rt.eval("DRAK_IN_GROUP == true")), "Raid Group panel shows the accepted fake player")
rt.execute("local b = RLSuite.groupmaking.wlGroupSlots[1]; SLOT_OK = (b ~= nil and b:IsShown() and (b:GetWidth() or 0) > 0 and b.nameFS ~= nil and type(b.GetObjectType) == 'function' and b:GetObjectType() == 'Button')")
check(bool(rt.eval("SLOT_OK == true")), "Raid Group slots are visible Buttons with explicit size")

# --- Debug fake whispers: spammer active -> 10 whispers into the Whisplist ---
rt.execute("RLSuite.groupmaking:StartSpam()")
check(bool(rt.eval("RLSuite.groupmaking.debugWhisperTimer ~= nil")), "StartSpam (debug) schedules the fake-whisper timer")
rt.execute("for i=1,10 do RLSuite.groupmaking:DebugWhisperTick() end")
check(bool(rt.eval("#RLSuite.groupmaking.whisperDB.entries == 10")), "10 fake whispers produce 10 Whisplist entries")
check(bool(rt.eval("RLSuite.groupmaking.debugWhisperTimer == nil")), "fake-whisper timer stops after the 10th whisper")
rt.execute("RLSuite.groupmaking:StopSpam()")

# --- Inviting a fake whisperer behaves like a real accept ---
rt.execute("RLSuite.groupmaking:SelectWhisperEntry(1)")
rt.execute("INV_NAME = RLSuite.groupmaking.selectedEntry and RLSuite.groupmaking.selectedEntry.name")
check(bool(rt.eval("INV_NAME ~= nil")), "a whisper entry is selected")
rt.execute("RLSuite.groupmaking:InviteSelected()")
check(bool(rt.eval("#RLSuite:DebugRoster() == 3")), "InviteSelected (debug) accepts the fake player into the roster")

# --- Right-click removal defers the rebuild so future clicks stay alive ---
rt.execute("RLSuite.groupmaking:SelectWhisperEntry(1)")
rt.execute("RTARGET = RLSuite.groupmaking.selectedEntry")
rt.execute("RLSuite.groupmaking:QueueRemoveWhisperEntry(RTARGET)")
check(bool(rt.eval("#RLSuite.groupmaking.whisperDB.entries == 9")), "right-click removal drops the entry data")
check(bool(rt.eval("RLSuite.groupmaking._wlRebuildTimer ~= nil")), "right-click removal defers the list rebuild (AceTimer)")
rt.execute("RLSuite.groupmaking:FlushWhisperRebuild()")
check(bool(rt.eval("#RLSuite.groupmaking.wlRows == 9")), "deferred rebuild renders the remaining rows")
rt.execute("RLSuite.groupmaking:SelectWhisperEntryByRef(RLSuite.groupmaking.whisperDB.entries[1])")
check(bool(rt.eval("RLSuite.groupmaking.selectedEntry == RLSuite.groupmaking.whisperDB.entries[1]")), "left-click selects the next row by reference after removal")

# --- Whisper rows are pooled (never destroyed): the click-bug root cause ---
rt.execute("ROW_1 = RLSuite.groupmaking.wlRows[1]")
rt.execute("RLSuite.groupmaking:UpdateWhisplist()")
check(bool(rt.eval("RLSuite.groupmaking.wlRows[1] == ROW_1")), "row frames are REUSED across rebuilds (no destroy/recreate)")
rt.execute("RLSuite.groupmaking:QueueRemoveWhisperEntry(RLSuite.groupmaking.whisperDB.entries[1])")
rt.execute("RLSuite.groupmaking:FlushWhisperRebuild()")
rt.execute("ROW_1B = RLSuite.groupmaking.wlRows[1]")
rt.execute("RLSuite.groupmaking:UpdateWhisplist()")
check(bool(rt.eval("RLSuite.groupmaking.wlRows[1] == ROW_1B")), "row frames stay identical after right-click removal + rebuild")
# Simulate a left-click on a reused row: it must select the right entry.
rt.execute("TARGET = RLSuite.groupmaking.whisperDB.entries[1]")
rt.execute("local r = RLSuite.groupmaking.wlRows[1]; if r and r._scripts.OnClick then r._scripts.OnClick(r, 'LeftButton') end")
check(bool(rt.eval("RLSuite.groupmaking.selectedEntry == TARGET")), "clicking a reused row selects its current entry")

# --- Autoinviter manual list: typeable + Enter adds + Auto invite now + label ---
check(bool(rt.eval("RLSuite.groupmaking.ieAutoArmBtn:GetText() == 'Start Autoinviter'")), "arm button reads 'Start Autoinviter'")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoNowBtn ~= nil")), "Auto invite now button exists")
rt.execute("RLSuite.groupmaking.autoinvite.names = {}")
rt.execute("RLSuite.groupmaking.ieAutoNamesEdit:SetText('Holymoon')")
rt.execute("RLSuite.groupmaking:AddAutoName(RLSuite.groupmaking.ieAutoNamesEdit:GetText())")
rt.execute("RLSuite.groupmaking.ieAutoNamesEdit:SetText('  Zapdora  ')")
rt.execute("RLSuite.groupmaking:AddAutoName(RLSuite.groupmaking.ieAutoNamesEdit:GetText())")
check(bool(rt.eval("#RLSuite.groupmaking:AutoNameList() == 2")), "Enter/AddAutoName appends names (with trimming)")
rt.execute("RLSuite.groupmaking:RemoveAutoName('Holymoon')")
check(bool(rt.eval("#RLSuite.groupmaking:AutoNameList() == 1 and RLSuite.groupmaking:AutoNameList()[1] == 'Zapdora'")), "right-click RemoveAutoName removes the name")
rt.execute("N_BEFORE = #RLSuite:DebugRoster()")
rt.execute("RLSuite.groupmaking:AutoInviteNow()")
check(bool(rt.eval("#RLSuite:DebugRoster() == N_BEFORE + 1")), "Auto invite now accepts the listed fake player")

# --- Raid Group fill order: vertical, G1 fills first then G2 (not round-robin) ---
rt.execute("RLSuite:ResetDebugRaid()")
rt.execute("for i=1,6 do RLSuite:DebugInviteAccept('Fake'..i, 'WARRIOR') end")
rt.execute("local subs={}; for _,m in ipairs(RLSuite:DebugRoster()) do subs[#subs+1]=m.name..':'..tostring(m.subgroup) end; SUBS=subs")
check(bool(rt.eval("table.concat(SUBS, ',') == 'Testplayer:1,Fake1:1,Fake2:1,Fake3:1,Fake4:1,Fake5:2,Fake6:2'")), "groups fill vertically: G1 fills first (5), then G2")

# --- Raid Group G6 column + widened rib + drag&drop reorder ---
check(bool(rt.eval("#RLSuite.groupmaking.wlGroupSlots == 30")), "Raid Group now builds 30 slots (6 groups x 5)")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupLabels[6] ~= nil and RLSuite.groupmaking.wlGroupLabels[6]:GetText() == 'G6'")), "Raid Group shows the G6 label")
check(bool(rt.eval("RLSuite.groupmaking.whisplistFrame:GetWidth() == 450")), "InviteEngine rib widened to 450 for the 6th column")

# Drop onto an EMPTY slot (OnReceiveDrag path): move there exactly.
rt.execute("RLSuite:ResetDebugRaid()")
rt.execute("for i=1,4 do RLSuite:DebugInviteAccept('Mv'..i, 'WARRIOR') end")
rt.execute("local s=RLSuite.groupmaking.wlGroupSlots[2]; if s._scripts.OnDragStart then s._scripts.OnDragStart(s, 'LeftButton') end")
rt.execute("local s=RLSuite.groupmaking.wlGroupSlots[6]; if s._scripts.OnReceiveDrag then s._scripts.OnReceiveDrag(s) end")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[2].playerName == nil")), "drag onto empty slot empties the source slot")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[6].playerName == 'Mv1'")), "dragged player lands exactly in the empty destination slot")
check(bool(rt.eval("#RLSuite:DebugRoster() == 5")), "moving keeps the roster size unchanged")

# Drop onto an OCCUPIED slot (OnReceiveDrag path): the two players swap.
rt.execute("local s=RLSuite.groupmaking.wlGroupSlots[1]; if s._scripts.OnDragStart then s._scripts.OnDragStart(s, 'LeftButton') end")
rt.execute("local s=RLSuite.groupmaking.wlGroupSlots[3]; if s._scripts.OnReceiveDrag then s._scripts.OnReceiveDrag(s) end")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[1].playerName == 'Mv2' and RLSuite.groupmaking.wlGroupSlots[3].playerName == 'Testplayer'")), "dropping onto an occupied slot swaps the two players")
check(bool(rt.eval("#RLSuite:DebugRoster() == 5")), "swapping keeps the roster size unchanged")

# Releasing on the SAME slot must not reorder anything.
rt.execute("local s=RLSuite.groupmaking.wlGroupSlots[1]; if s._scripts.OnDragStart then s._scripts.OnDragStart(s, 'LeftButton') end")
rt.execute("local s=RLSuite.groupmaking.wlGroupSlots[1]; if s._scripts.OnReceiveDrag then s._scripts.OnReceiveDrag(s) end")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[1].playerName == 'Mv2'")), "dropping on the source slot itself leaves it unchanged")

# OnDragStop fallback: target computed from the cursor coordinates.
rt.execute("RLSuite:ResetDebugRaid()")
rt.execute("for i=1,4 do RLSuite:DebugInviteAccept('Mv'..i, 'WARRIOR') end")
rt.execute("""
GetCursorPosition = function() return 101, 104 end
UIParent.GetEffectiveScale = function() return 1 end
local slots = RLSuite.groupmaking.wlGroupSlots
for i, b in ipairs(slots) do
    if i == 6 then
        b.GetLeft = function() return 100 end
        b.GetRight = function() return 120 end
        b.GetBottom = function() return 100 end
        b.GetTop = function() return 116 end
    else
        b.GetLeft = function() return 0 end
        b.GetRight = function() return 10 end
        b.GetBottom = function() return 0 end
        b.GetTop = function() return 10 end
    end
end
RLSuite.groupmaking.wlGroupSlots[2]._scripts.OnDragStart(RLSuite.groupmaking.wlGroupSlots[2], 'LeftButton')
RLSuite.groupmaking.wlGroupSlots[2]._scripts.OnDragStop(RLSuite.groupmaking.wlGroupSlots[2])
""")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[2].playerName == nil")), "OnDragStop fallback empties the source slot")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[6].playerName == 'Mv1'")), "OnDragStop fallback moves the player to the slot under the cursor")

# --- Calendar Event tab redo: editable event + class sidebar ---
check(bool(rt.eval("RLSuite.groupmaking.ieAutoCalBox ~= nil")), "Calendar Event tab has the event box")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoLinkBtn == nil")), "'Link or create an event' button removed")
check(bool(rt.eval("RLSuite.groupmaking.ieCalTitleEdit ~= nil")), "editable title field exists")
check(bool(rt.eval("RLSuite.groupmaking.ieCalTypeDD ~= nil")), "editable type dropdown exists")
check(bool(rt.eval("RLSuite.groupmaking.ieCalDayEdit ~= nil and RLSuite.groupmaking.ieCalMonthDD ~= nil and RLSuite.groupmaking.ieCalYearEdit ~= nil")), "editable day/month/year controls exist")
check(bool(rt.eval("RLSuite.groupmaking.ieCalHourEdit ~= nil and RLSuite.groupmaking.ieCalMinuteEdit ~= nil")), "editable hour/minute controls exist")
check(bool(rt.eval("RLSuite.groupmaking.ieCalSidebar ~= nil")), "class sidebar exists")
check(bool(rt.eval("RLSuite.groupmaking.ieCalSidebar:GetWidth() == 40")), "class sidebar is narrow (icons + counts only)")
check(bool(rt.eval("RLSuite.groupmaking.ieCalClassButtons ~= nil and RLSuite.groupmaking.ieCalClassButtons['WARRIOR'] ~= nil and RLSuite.groupmaking.ieCalClassButtons['DEATHKNIGHT'] ~= nil")), "class sidebar has a class icon per class")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoEventRefresh == nil")), "old Refresh button removed")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoEventCreate == nil")), "old Create event button removed")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoEventDropdown == nil")), "old Raid event dropdown removed")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoEventTitle == nil")), "old mirror title removed")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoMirrorTitle == nil")), "old read-only mirror title removed")
check(bool(rt.eval("type(RLSuite.groupmaking.OpenCalendarToLink) == 'function'")), "OpenCalendarToLink wired")
check(bool(rt.eval("type(RLSuite.groupmaking.EnsureRLSCalendarUI) == 'function'")), "EnsureRLSCalendarUI wired")

# --- empty linked-event state ---
rt.execute("RLSuite.groupmaking.autoinvite.linkedEvent = nil")
rt.execute("RLSuite.groupmaking:RenderLinkedEvent()")
check(bool(rt.eval("RLSuite.groupmaking.ieCalEmptyLabel:GetText() == 'No event linked yet.'")), "empty state shows 'No event linked yet.'")
check(bool(rt.eval("RLSuite.groupmaking.ieCalEmptyLabel:IsShown() == true")), "empty label is shown")

# --- linked-event renders into the editable fields ---
rt.execute("RLSuite.groupmaking.autoinvite.linkedEvent = { title='Test Raid', description='Bring consumables', creator='Testplayer', eventType=1, weekday=1, month=9, day=12, year=2026, hour=20, minute=30, invitees={ { name='Fake1', className='Warrior', class='WARRIOR', status=2, mod='CREATOR' } } }")
rt.execute("RLSuite.groupmaking:RenderLinkedEvent()")
check(bool(rt.eval("RLSuite.groupmaking.ieCalTitleEdit:GetText() == 'Test Raid'")), "title field shows the event title")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoMirrorDesc:GetText() == 'Bring consumables'")), "description field shows the event description")
check(bool(rt.eval("RLSuite.groupmaking.ieCalDayEdit:GetText() == '12'")), "day field shows the event day")
check(bool(rt.eval("RLSuite.groupmaking.ieCalYearEdit:GetText() == '2026'")), "year field shows the event year")
check(bool(rt.eval("RLSuite.groupmaking.ieCalHourEdit:GetText() == '20' and RLSuite.groupmaking.ieCalMinuteEdit:GetText() == '30'")), "time fields show the event time")
check(bool(rt.eval("RLSuite.groupmaking.ieCalEmptyLabel:IsShown() == false")), "empty label is hidden")
check(bool(rt.eval("#RLSuite.groupmaking._autoMirrorInviteRows == 1")), "mirror renders one invite row")

# --- class sidebar counts attending invitees per class ---
rt.execute("RLSuite.groupmaking.autoinvite.linkedEvent = { title='Test Raid', invitees={ { name='Fake1', class='WARRIOR', status=2 }, { name='Fake2', class='WARRIOR', status=4 }, { name='Fake3', class='MAGE', status=1 }, { name='Fake4', class='MAGE', status=3 } } }")
rt.execute("RLSuite.groupmaking:ResetCalendarWorking()")
rt.execute("RLSuite.groupmaking:RenderLinkedEvent()")
check(bool(rt.eval("RLSuite.groupmaking.ieCalClassButtons['WARRIOR'].count:GetText() == '2'")), "sidebar counts 2 attending warriors")
check(bool(rt.eval("RLSuite.groupmaking.ieCalClassButtons['MAGE'].count:GetText() == ''")), "sidebar ignores invited/declined (non-attending) mages")

# --- calendar mode invite queue comes from the linked snapshot ---
rt.execute("RLSuite.groupmaking.autoinvite.mode = 'calendar'")
rt.execute("RLSuite.groupmaking.autoinvite.linkedEvent = { title='Test Raid', invitees={ { name='Fake1', status=1 } } }")
rt.execute("RLSuite.groupmaking:ResetCalendarWorking()")
rt.execute("Q = RLSuite.groupmaking:BuildAutoinviteQueue()")
check(bool(rt.eval("table.concat(Q, ',') == 'Fake1'")), "calendar queue is built from linked invitees")

# --- declined invitees are skipped by the calendar queue ---
rt.execute("RLSuite.groupmaking.autoinvite.linkedEvent = { title='Test Raid', invitees={ { name='Fake1', status=1 }, { name='Fake2', status=3 } } }")
rt.execute("Q = RLSuite.groupmaking:BuildAutoinviteQueue()")
check(bool(rt.eval("table.concat(Q, ',') == 'Fake1'")), "declined invitees are skipped by the calendar queue")

# --- three real tabs: Whisplist / Manual list / Calendar event ---
check(bool(rt.eval("RLSuite.groupmaking.ieManualPage ~= nil")), "Manual list is its own tab page")
check(bool(rt.eval("RLSuite.groupmaking.ieCalPage ~= nil")), "Calendar event is its own tab page")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoPage == nil")), "old combined 'Autoinviter' page removed")

# --- manual footer: time + invite buttons live at the bottom (no clipping) ---
check(bool(rt.eval("RLSuite.groupmaking.ieManualFooter ~= nil")), "manual footer frame exists")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoArmBtn:GetParent() == RLSuite.groupmaking.ieManualFooter")), "arm button anchored to the footer")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoNowBtn:GetParent() == RLSuite.groupmaking.ieManualFooter")), "now button anchored to the footer")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoHourEdit:GetParent() == RLSuite.groupmaking.ieManualFooter")), "hour edit anchored to the footer")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoMinuteEdit:GetParent() == RLSuite.groupmaking.ieManualFooter")), "minute edit anchored to the footer")

# --- calendar footer: the 3 buttons + status ---
check(bool(rt.eval("RLSuite.groupmaking.ieCalFooter ~= nil")), "calendar footer frame exists")
check(bool(rt.eval("RLSuite.groupmaking.ieCalAtBtn ~= nil")), "'Autoinvite at set time' button exists")
check(bool(rt.eval("RLSuite.groupmaking.ieCalAtBtn:GetText() == 'Autoinvite at set time'")), "'Autoinvite at set time' is labelled correctly")
check(bool(rt.eval("RLSuite.groupmaking.ieCalNowBtn ~= nil")), "'Auto invite now' button exists")
check(bool(rt.eval("RLSuite.groupmaking.ieCalUpdateBtn ~= nil")), "Update button exists")
check(bool(rt.eval("RLSuite.groupmaking.ieCalUpdateBtn:GetText() == 'Create/Update'")), "Update button reads 'Create/Update'")
check(bool(rt.eval("RLSuite.groupmaking.ieCalInviteEdit ~= nil")), "'invite a player' edit box exists")
check(bool(rt.eval("RLSuite.groupmaking.ieCalInviteBtn ~= nil")), "'Invite new member' button exists")

# --- the three calendar buttons sit on one inline row ---
check(bool(rt.eval("select(2, RLSuite.groupmaking.ieCalNowBtn:GetPoint(1)) == RLSuite.groupmaking.ieCalAtBtn")), "'Auto invite now' is inline next to 'Autoinvite at set time'")
check(bool(rt.eval("select(2, RLSuite.groupmaking.ieCalUpdateBtn:GetPoint(1)) == RLSuite.groupmaking.ieCalNowBtn")), "'Update' is inline next to 'Auto invite now' (not on a lower row)")

# --- the sidebar shows only per-class counts (no header/total) ---
check(bool(rt.eval("RLSuite.groupmaking.ieCalClassTotal == nil")), "sidebar has no 'attending' total line")
check(bool(rt.eval("select(1, RLSuite.groupmaking.ieAutoMirrorDescBox:GetPoint(2)) == 'TOPRIGHT'")), "description box is pinned to the top (not vertically centered)")

# --- calendar 'Autoinvite at set time' arms the calendar queue ---
check(bool(rt.eval("type(RLSuite.groupmaking.ToggleAutoinviterCalendar) == 'function'")), "ToggleAutoinviterCalendar wired")
rt.execute("RLSuite.groupmaking.autoinvite.names = {}")
rt.execute("RLSuite.groupmaking.autoinvite.linkedEvent = { title='Test Raid', invitees={ { name='Fake1', status=1 } } }")
rt.execute("RLSuite.groupmaking:ResetCalendarWorking()")
rt.execute("RLSuite.groupmaking:ToggleAutoinviterCalendar()")
check(bool(rt.eval("RLSuite.groupmaking.autoinviteActive == true")), "calendar Autoinvite at set time arms the autoinviter")
check(bool(rt.eval("RLSuite.groupmaking.autoinviteQueue ~= nil and RLSuite.groupmaking.autoinviteQueue[1] == 'Fake1'")), "armed queue comes from the calendar invitees")
check(bool(rt.eval("RLSuite.groupmaking.ieCalAtBtn:GetText() == 'Stop Autoinviter'")), "armed calendar button reads 'Stop Autoinviter'")
rt.execute("RLSuite.groupmaking:StopAutoinviter()")

# --- Update button activates only on pending changes ---
check(bool(rt.eval("type(RLSuite.groupmaking.UpdateLinkedCalendarEvent) == 'function'")), "UpdateLinkedCalendarEvent wired")
check(bool(rt.eval("type(RLSuite.groupmaking.OpenLinkedCalendarEvent) == 'function'")), "OpenLinkedCalendarEvent wired")
rt.execute("RLSuite.groupmaking.autoinvite.linkedEvent = { title='Test Raid', description='d', creator='c', eventType=1, weekday=1, month=9, day=12, year=2026, hour=20, minute=30, invitees={} }")
rt.execute("RLSuite.groupmaking:ResetCalendarWorking()")
rt.execute("RLSuite.groupmaking:RenderLinkedEvent()")
check(bool(rt.eval("not RLSuite.groupmaking.ieCalUpdateBtn:IsEnabled()")), "Update button disabled when no changes")
rt.execute("RLSuite.groupmaking:MarkCalendarDirty()")
check(bool(rt.eval("RLSuite.groupmaking.ieCalUpdateBtn:IsEnabled()")), "Update button enabled after a change")
rt.execute("RLSuite.groupmaking:ResetCalendarWorking()")
check(bool(rt.eval("not RLSuite.groupmaking.ieCalUpdateBtn:IsEnabled()")), "Update button disabled after reset")

# --- calendar invite list: add/remove mark pending changes ---
rt.execute("RLSuite.groupmaking.autoinvite.linkedEvent = { title='Test Raid', invitees={ { name='Fake1', className='Warrior', class='WARRIOR', status=2, mod='CREATOR' } } }")
rt.execute("RLSuite.groupmaking:ResetCalendarWorking()")
rt.execute("RLSuite.groupmaking.ieCalInviteEdit:SetText('Newbie')")
rt.execute("RLSuite.groupmaking:CalendarAddInvitee()")
check(bool(rt.eval("#RLSuite.groupmaking:CalendarWorkingInvitees() == 2")), "adding a member grows the working invite list")
check(bool(rt.eval("RLSuite.groupmaking.calDirty == true")), "adding a member marks changes pending")
check(bool(rt.eval("RLSuite.groupmaking._autoMirrorInviteRows[2] ~= nil and RLSuite.groupmaking._autoMirrorInviteRows[2].xBtn ~= nil")), "invite rows have an X button")
rt.execute("RLSuite.groupmaking:CalendarRemoveInvitee('Fake1')")
check(bool(rt.eval("#RLSuite.groupmaking:CalendarWorkingInvitees() == 1")), "removing a member shrinks the working invite list")
check(bool(rt.eval("RLSuite.groupmaking.calRemoved[1] == 'Fake1'")), "removed member tracked for update")

# --- manual list: X button removes the player ---
rt.execute("RLSuite.groupmaking.autoinvite.names = {}")
rt.execute("RLSuite.groupmaking:AddAutoName('Zap')")
check(bool(rt.eval("#RLSuite.groupmaking:AutoNameList() == 1")), "manual list has one entry")
check(bool(rt.eval("RLSuite.groupmaking._autoNameRows[1].xBtn ~= nil")), "manual row has an X button")
rt.execute("RLSuite.groupmaking._autoNameRows[1].xBtn._scripts.OnClick(RLSuite.groupmaking._autoNameRows[1].xBtn)")
check(bool(rt.eval("#RLSuite.groupmaking:AutoNameList() == 0")), "clicking X removes the player from the manual list")

check(rt.eval("LAST_ERROR") is None or rt.eval("LAST_ERROR") == None, "no errors during Scenario D (LAST_ERROR=%r)" % rt.eval("LAST_ERROR"))

print()
print("== Scenario E: Raid Frame HUD rework ==")
# --- tab renamed + toggles the HUD (no settings window) ---
rt.execute("RLSuite.mainWindow._rfTabLabel = nil; for _, t in ipairs(RLSuite.mainWindow.tabDefs) do if t.key == 'raidframe' then RLSuite.mainWindow._rfTabLabel = t.label end end")
check(bool(rt.eval("RLSuite.mainWindow._rfTabLabel == 'Raid Frame'")), "Raid Manager tab renamed to 'Raid Frame'")
rt.execute("RLSuite.raidFrame.toggleCount = 0; RLSuite.raidFrame._origToggle = RLSuite.raidFrame.Toggle; RLSuite.raidFrame.Toggle = function(self) self.toggleCount = (self.toggleCount or 0) + 1 end")
rt.execute("RLSuite.mainWindow:OnTabClick('raidframe')")
check(bool(rt.eval("RLSuite.raidFrame.toggleCount == 1")), "Raid Frame tab toggles the HUD (like Macrobar)")
rt.execute("RLSuite.raidFrame.Toggle = RLSuite.raidFrame._origToggle")

# --- old settings window moved to Config ---
check(bool(rt.eval("RLSuite.mainWindow.tabPanels == nil")), "old Raid Frame settings window removed from the tab bar")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.behavior ~= nil")), "Raid Frame -> Checks present in Config")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.alerts ~= nil")), "Raid Frame -> Alert Messages present in Config")

# --- Raid Frame config: right panel shows a tab window (one tab per sub-item) ---
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.childGroups == 'tab'")), "Raid Frame group renders sub-items as tabs")
rt.execute("RF_TREE = RLSuite.config.tree.tree; RF_NODE = nil; for _, n in ipairs(RF_TREE) do if n.value == 'raidframe' then RF_NODE = n end end")
check(bool(rt.eval("RF_NODE ~= nil and RF_NODE.children == nil")), "Raid Frame is a leaf node (tabs live in the right panel)")
rt.execute("RLSuite.config:SelectNode('raidframe')")
check(bool(rt.eval("RLSuite.config.currentNode == 'raidframe'")), "selecting Raid Frame node renders without error")
check(bool(rt.eval("LAST_ERROR == nil or LAST_ERROR == None")), "no error rendering the Raid Frame tab window")

# --- Layout tab controls ---
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args.iconSize ~= nil")), "Layout -> Icon size present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args.barHeight ~= nil")), "Layout -> Player bar height present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args.barWidth ~= nil")), "Layout -> Player bar width present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args.nameFontSize ~= nil")), "Layout -> Name font size present")

# --- clean HUD: no backdrop / border / close button ---
check(bool(rt.eval("RLSuite.raidFrame.frame:GetBackdrop() == nil")), "HUD has no backdrop")
check(bool(rt.eval("RLSuite.raidFrame.frame.closeBtn == nil")), "HUD has no red-X close button")

# --- rows: name inside the HP bar, left consumables, right CDs ---
check(bool(rt.eval("RLSuite.raidFrame.rows ~= nil and #RLSuite.raidFrame.rows >= 2")), "debug roster renders rows")
rt.execute("E5_ROW = RLSuite.raidFrame.rows and RLSuite.raidFrame.rows[1] or nil")
check(bool(rt.eval("E5_ROW ~= nil and E5_ROW.bar ~= nil and E5_ROW.bar.nameText ~= nil and E5_ROW.bar.hpText == nil")), "row has one HP bar with the name inside (no %% text)")
check(bool(rt.eval("E5_ROW ~= nil and E5_ROW.flaskIcon ~= nil and E5_ROW.foodIcon ~= nil")), "row has left flask + Well Fed icons")
check(bool(rt.eval("E5_ROW ~= nil and E5_ROW.cdIcons ~= nil and #E5_ROW.cdIcons > 0")), "row has class key CDs on the right")
check(bool(rt.eval("E5_ROW ~= nil and E5_ROW.bar:GetWidth() == RLSuite.db.profile.raidframe.appearance.barWidth")), "player HP bar uses the configured bar width")

# --- vertical ability bar (driven by the composition) ---
check(bool(rt.eval("RLSuite.raidFrame.abilityButtons ~= nil and #RLSuite.raidFrame.abilityButtons >= 4")), "ability bar shows abilities for the WARRIOR-heavy comp")

# --- pre-boss buff bar / in-fight debuff bar switch by phase ---
check(bool(rt.eval("#RLSuite.raidBuffChecks >= 11")), "pre-boss buff checks defined (>= 11)")
check(bool(rt.eval("#RLSuite.raidDebuffChecks >= 5")), "in-fight debuff checks defined (>= 5)")
rt.execute("RLSuite:SetContextPhase('preboss')")
check(bool(rt.eval("RLSuite.raidFrame.buffBar:IsShown() == true")), "pre-boss: buff bar shown")
check(bool(rt.eval("#RLSuite.raidFrame.buffBar.items >= 11")), "pre-boss: buff bar lists the buff categories")
rt.execute("RLSuite:SetContextPhase('infight')")
check(bool(rt.eval("RLSuite.raidFrame.debuffBar:IsShown() == true")), "in-fight: debuff bar shown")
check(bool(rt.eval("RLSuite.raidFrame.buffBar:IsShown() == false")), "in-fight: buff bar hidden")
check(bool(rt.eval("#RLSuite.raidFrame.debuffBar.items >= 5")), "in-fight: debuff bar lists the debuff categories")
rt.execute("RLSuite:SetContextPhase('preraid')")
check(bool(rt.eval("RLSuite.raidFrame.buffBar:IsShown() == false and RLSuite.raidFrame.debuffBar:IsShown() == false")), "preraid: both alert bars hidden")

check(rt.eval("LAST_ERROR") is None or rt.eval("LAST_ERROR") == None, "no errors during Scenario E (LAST_ERROR=%r)" % rt.eval("LAST_ERROR"))

print()
print("== Scenario F: Raid Frame groups + pre-boss drag & drop ==")
rt.execute("RLSuite:ResetDebugRaid()")
rt.execute("RLSuite.db.profile.debug = true; RLSuite:ApplyDebugMode()")
rt.execute("for i=1,5 do RLSuite:DebugInviteAccept('F'..i, 'WARRIOR') end")

# --- bars divided into 6 groups (G1..G6, 5 players each) ---
check(bool(rt.eval("#RLSuite.raidFrame.slots == 30")), "Raid Frame builds 30 slots (6 groups x 5 players)")
check(bool(rt.eval("#RLSuite.raidFrame.groupHeaders == 6")), "Raid Frame has 6 group headers (G1..G6)")
check(bool(rt.eval("#RLSuite.raidFrame.rows == 6")), "6 players render 6 populated rows")
check(bool(rt.eval("RLSuite.raidFrame.slots[1].member ~= nil and RLSuite.raidFrame.slots[1].member.name == 'Testplayer'")), "player sits in G1 slot 1")
check(bool(rt.eval("RLSuite.raidFrame.slots[6].member ~= nil and RLSuite.raidFrame.slots[6].member.name == 'F5'")), "6th member lands in G2 slot 1 (groups fill in order)")

# --- pre-boss: empty slots + empty headers hidden by default; drag enabled ---
check(bool(rt.eval("RLSuite.raidFrame:IsDragEnabled() == true")), "drag & drop enabled in pre-boss (debug)")
check(bool(rt.eval("RLSuite.raidFrame.frame._strata == 'MEDIUM'")), "RF HUD sits on MEDIUM strata (clicks not eaten by UI chrome)")
check(bool(rt.eval("RLSuite.raidFrame.slots[7]._enabledMouse == true")), "slots are ALWAYS mouse-enabled (children stay clickable)")
check(bool(rt.eval("RLSuite.raidFrame.slots[7]._dragButtons == nil or RLSuite.raidFrame.slots[7]._dragButtons[1] == nil")), "rows have NO drag registered at all (drag-eats-click-scripts root cause removed everywhere)")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].flaskIcon:GetParent() == RLSuite.raidFrame.content")), "consumable icons are siblings of the rows (no drag-swallowing ancestor)")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].flaskIcon._level ~= nil and RLSuite.raidFrame.rows[1].flaskIcon._level > (RLSuite.raidFrame.rows[1]._level or 1)")), "consumable icons sit above the rows (explicit frame level)")
check(bool(rt.eval("RLSuite.raidFrame.slots[7]:IsShown() == false")), "empty slots hidden by default (even in pre-boss)")
check(bool(rt.eval("RLSuite.raidFrame.groupHeaders[3]:IsShown() == false")), "empty group headers hidden by default")
check(bool(rt.eval("RLSuite.raidFrame.groupHeaders[1]:IsShown() == true")), "non-empty group headers shown")
# --- empty blocks appear ONLY while a player is being dragged (SHIFT+left MANUAL drag) ---
rt.execute("""
local row = RLSuite.raidFrame.slots[6]
SAVED_ISD = IsShiftKeyDown
IsShiftKeyDown = function() return false end
row._scripts.OnMouseDown(row, 'LeftButton')
row._scripts.OnMouseUp(row, 'LeftButton')
NOSHIFT_SRC = RLSuite.raidFrame._rfDragSource
IsShiftKeyDown = function() return true end
row._scripts.OnMouseDown(row, 'LeftButton')
""")
check(bool(rt.eval("NOSHIFT_SRC == nil")), "no Shift: plain click does NOT start a player drag (shift gates drag from clicks)")
check(bool(rt.eval("RLSuite.raidFrame.slots[7]:IsShown() == true")), "shift+drag: empty slots become visible ONLY while dragging a player")
check(bool(rt.eval("RLSuite.raidFrame.groupHeaders[3]:IsShown() == true")), "shift+drag: empty group headers appear during the drag (drop targets)")
rt.execute("""
local row = RLSuite.raidFrame.slots[6]
row._scripts.OnMouseUp(row, 'LeftButton')  -- manual drop (watchdog covers release fuori HUD)
IsShiftKeyDown = SAVED_ISD
""")
check(bool(rt.eval("RLSuite.raidFrame.slots[7]:IsShown() == false")), "empty slots hidden again after the drag ends")
check(bool(rt.eval("RLSuite.raidFrame.groupHeaders[3]:IsShown() == false")), "empty group headers hidden again after the drag")
check(bool(rt.eval("RLSuite.raidFrame._rfDragSource == nil")), "manual drag source cleared on release")

# --- move a player into an empty slot ---
rt.execute("RLSuite.raidFrame:MoveSlot(RLSuite.raidFrame.slots[6], RLSuite.raidFrame.slots[7])")
check(bool(rt.eval("RLSuite.raidFrame.slots[7].member ~= nil and RLSuite.raidFrame.slots[7].member.name == 'F5'")), "drag onto empty slot moves the player there")
check(bool(rt.eval("RLSuite.raidFrame.slots[6].member == nil")), "source slot is left empty after the move")

# --- swap two occupied slots ---
rt.execute("RLSuite.raidFrame:MoveSlot(RLSuite.raidFrame.slots[1], RLSuite.raidFrame.slots[7])")
check(bool(rt.eval("RLSuite.raidFrame.slots[1].member ~= nil and RLSuite.raidFrame.slots[1].member.name == 'F5'")), "drag onto occupied slot swaps the two players")
check(bool(rt.eval("RLSuite.raidFrame.slots[7].member ~= nil and RLSuite.raidFrame.slots[7].member.name == 'Testplayer'")), "swapped player lands in the source slot")

# --- non pre-boss: empty slots hidden, drag disabled ---
rt.execute("RLSuite:SetContextPhase('infight')")
check(bool(rt.eval("RLSuite.raidFrame:IsDragEnabled() == false")), "drag & drop disabled outside pre-boss")
check(bool(rt.eval("RLSuite.raidFrame.slots[1]._enabledMouse == true and (RLSuite.raidFrame.slots[1]._dragButtons == nil or RLSuite.raidFrame.slots[1]._dragButtons[1] == nil)")), "outside pre-boss: mouse still ENABLED, only the drag registration is removed")
check(bool(rt.eval("RLSuite.raidFrame.slots[8]:IsShown() == false")), "outside pre-boss empty slots are hidden")
check(bool(rt.eval("RLSuite.raidFrame.groupHeaders[3]:IsShown() == false")), "outside pre-boss empty groups hide their header")
check(bool(rt.eval("RLSuite.raidFrame.groupHeaders[1]:IsShown() == true")), "groups with members keep their header")

# --- F.2 consumable alerts: left click = whisper, right click = raid warning with ALL missing ---
# NB: in debug un print diagnostico ("RF icon down") finisce anch'esso nel log:
# le asserzioni scansionano CHAT_LOG per pattern, non per indice.
rt.execute("RLSuite:SetContextPhase('preboss')")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].bar.hpText == nil")), "no percentage text on player bars")
rt.execute("""
CHAT_LOG = {}
local row = RLSuite.raidFrame.rows[1]
ALERT_NAME = row.member.name
MISSING_NAME = RLSuite.raidFrame.rows[2].member.name
row._lastAlert = nil
-- sinistro: la finestra non ha piu' RegisterForDrag, l'OnMouseUp arriva;
-- se qualche client lo mangiasse comunque, il poller di riserva copre
-- (stesso click, dedup TTL → sempre E SOLO un messaggio)
local b = row.flaskIcon
b._scripts.OnMouseDown(b, 'LeftButton')
b._scripts.OnMouseUp(b, 'LeftButton')          -- canale primario (up-piece)
b._scripts.OnUpdate(b, 0.016)                  -- canale riserva (deduppo via TTL)
FOUND_W = 0
for _, e in ipairs(CHAT_LOG) do
    if string.sub(e, 1, 8) == 'WHISPER|' and string.find(e, ALERT_NAME) then FOUND_W = FOUND_W + 1 end
end
""")
check(rt.eval("FOUND_W") == 1, "left click on a consumable icon whispers the single player (debug: whisper to self with the player's message)")
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
row._lastAlert = nil
row.foodIcon._scripts.OnMouseDown(row.foodIcon, 'RightButton')
row.foodIcon._scripts.OnMouseUp(row.foodIcon, 'RightButton')
FOUND_RW_ALL = false
for _, e in ipairs(CHAT_LOG) do
    if string.find(e, '%[RAID_WARNING%]') and string.find(e, ALERT_NAME) and string.find(e, MISSING_NAME) then
        FOUND_RW_ALL = true
    end
end
""")
check(bool(rt.eval("FOUND_RW_ALL")), "right click on a consumable icon warns the whole raid listing ALL players missing it")

# --- F.2b ROW-LEVEL fallback (the channel client-proven by drag): cursor hit-test on the icons ---
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
local b = row.flaskIcon
b.GetLeft = function() return 11 end; b.GetRight = function() return 27 end
b.GetBottom = function() return 101 end; b.GetTop = function() return 117 end
local f = row.foodIcon
f.GetLeft = function() return 29 end; f.GetRight = function() return 45 end
f.GetBottom = function() return 101 end; f.GetTop = function() return 117 end
SAVED_GCP = GetCursorPosition
GetCursorPosition = function() return 15, 110 end
CHAT_LOG = {}
row._lastAlert = nil
row._scripts.OnMouseDown(row, 'LeftButton')
row._scripts.OnMouseUp(row, 'LeftButton')
RFB_W = 0
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then RFB_W = RFB_W + 1 end end
""")  # scan-pattern (i print diagnostici debug riempiono la chat-log)
check(rt.eval("RFB_W") == 1, "row fallback: left click under the cursor on the icon whispers the player")
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
GetCursorPosition = function() return 35, 110 end  -- sopra l'icona food
row._lastAlert = nil
row._scripts.OnMouseDown(row, 'RightButton')
row._scripts.OnMouseUp(row, 'RightButton')
RFB_RW = false
for _, e in ipairs(CHAT_LOG) do
    if string.find(e, '%[RAID_WARNING%]') and string.find(e, MISSING_NAME) then RFB_RW = true end
end
""")
check(bool(rt.eval("RFB_RW")), "row fallback: right click on the icon warns everyone missing")
# press elsewhere on the row (NOT on the icons) -> nothing
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
GetCursorPosition = function() return 200, 110 end
row._lastAlert = nil
local before = 0
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then before = before + 1 end end
row._scripts.OnMouseDown(row, 'LeftButton')
row._scripts.OnMouseUp(row, 'LeftButton')
RFB_BODY = 0
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then RFB_BODY = RFB_BODY + 1 end end
RFB_BODY = RFB_BODY - before
""")
check(rt.eval("RFB_BODY") == 0, "clicking the row body (not an icon) sends nothing")
# drag-detect: cursor moved between down and up -> nothing
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
local before = 0
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then before = before + 1 end end
GetCursorPosition = function() return 15, 110 end
row._scripts.OnMouseDown(row, 'LeftButton')
GetCursorPosition = function() return 60, 118 end
row._scripts.OnMouseUp(row, 'LeftButton')
RFB_DRAG = 0
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then RFB_DRAG = RFB_DRAG + 1 end end
RFB_DRAG = RFB_DRAG - before
""")
check(rt.eval("RFB_DRAG") == 0, "moved cursor between down/up (drag) sends nothing")
# dedupe: same click through icon(poll) + row(fallback) -> one whisper only; later click fires again
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
local b = row.flaskIcon
SAVED_GT = GetTime
T_DEDUP = 1000
GetTime = function() return T_DEDUP end
CHAT_LOG = {}
GetCursorPosition = function() return 15, 110 end
local function wcount()
    local n = 0
    for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then n = n + 1 end end
    return n
end
b._scripts.OnMouseDown(b, 'LeftButton'); b._pressed = nil; b._scripts.OnUpdate(b, 0.016)
T_DEDUP = 1000.1
row._scripts.OnMouseDown(row, 'LeftButton'); row._scripts.OnMouseUp(row, 'LeftButton')
DEDUP1 = wcount()
T_DEDUP = 1001.0
row._scripts.OnMouseDown(row, 'LeftButton'); row._scripts.OnMouseUp(row, 'LeftButton')
DEDUP2 = wcount()
GetTime = SAVED_GT
GetCursorPosition = SAVED_GCP
local b2 = RLSuite.raidFrame.rows[1].flaskIcon
b2.GetLeft, b2.GetRight, b2.GetBottom, b2.GetTop = nil, nil, nil, nil
RLSuite.raidFrame.rows[1].foodIcon.GetLeft = nil
b2._pendingLeft = nil
b2:SetScript('OnUpdate', nil)
""")
check(rt.eval("DEDUP1") == 1, "icon + row double channel of the SAME click dedupes to one message")
check(rt.eval("DEDUP2") == 2, "a later identical click (> 0.3s) fires again")

# --- F.2c left-click vs drag on the icon: moved cursor cancels, no double-fire ---
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
local b = row.flaskIcon
CHAT_LOG = {}
row._lastAlert = nil
SAVED_GCP2 = GetCursorPosition
SAVED_IMBD = IsMouseButtonDown
GetCursorPosition = function() return 100, 100 end
IsMouseButtonDown = function() return true end  -- tenuto giu'
b._scripts.OnMouseDown(b, 'LeftButton')
GetCursorPosition = function() return 160, 130 end  -- mosso mentre tenuto giu' => drag
b._scripts.OnUpdate(b, 0.016)
DRAG1 = 0  -- conta solo i MESSAGGI (il print diagnostico down polucia il log)
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then DRAG1 = DRAG1 + 1 end end
IsMouseButtonDown = function() return false end -- ora rilascia: nessun click (era drag)
if b._scripts.OnUpdate then b._scripts.OnUpdate(b, 0.016) end  -- disarmato dal dopo-drag: non deve esserci
DRAG2 = 0
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then DRAG2 = DRAG2 + 1 end end
GetCursorPosition = SAVED_GCP2
IsMouseButtonDown = SAVED_IMBD
""")
check(rt.eval("DRAG1") == 0, "holding left and moving the cursor on the icon is a drag, no message")
check(bool(rt.eval("DRAG2 == 0 and RLSuite.raidFrame.rows[1].flaskIcon._pendingLeft == nil")), "canceled drag: release sends nothing, poller disarmed")

# --- F.2d user interaction model: Shift gates drag, plain clicks send messages ---
check(bool(rt.eval("RLSuite.raidFrame.frame._dragButtons == nil or RLSuite.raidFrame.frame._dragButtons[1] == nil")),
    "HUD window has NO RegisterForDrag at all (drag-eats-clicks root cause removed)")
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
local b = row.flaskIcon
CHAT_LOG = {}
row._lastAlert = nil
SAVED_ISD2 = IsShiftKeyDown
IsShiftKeyDown = function() return true end
b._scripts.OnMouseDown(b, 'LeftButton'); b._scripts.OnMouseUp(b, 'LeftButton'); if b._scripts.OnUpdate then b._scripts.OnUpdate(b, 0.016) end
b._scripts.OnMouseDown(b, 'RightButton'); b._scripts.OnMouseUp(b, 'RightButton')
SW = 0
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' or string.find(e, '%[RAID_WARNING%]') then SW = SW + 1 end end
SHIFT_PENDING = b._pendingLeft
IsShiftKeyDown = SAVED_ISD2
""")
check(rt.eval("SW") == 0, "Shift held on the icons sends NO message (left nor right) - drag gestures don't conflict")
check(bool(rt.eval("SHIFT_PENDING == nil")), "Shift held: reserve poller never armed")
# Shift+right on a row moves the HUD window; plain right on a row does not
rt.execute("""
local f = RLSuite.raidFrame.frame
local row = RLSuite.raidFrame.rows[1]
f._rlsMoving = nil; f._moving = false
row._scripts.OnMouseDown(row, 'RightButton')
PLAIN_MOVING = f._rlsMoving; PLAIN_WAS_MOVING = f._moving
row._scripts.OnMouseUp(row, 'RightButton')
SAVED_ISD3 = IsShiftKeyDown
IsShiftKeyDown = function() return true end
row._scripts.OnMouseDown(row, 'RightButton')
SHIFT_MOVING = f._rlsMoving; SHIFT_WAS_MOVING = f._moving
row._scripts.OnMouseUp(row, 'RightButton')
SHIFT_AFTER = f._rlsMoving; SHIFT_AFTER_MOVING = f._moving
IsShiftKeyDown = SAVED_ISD3
""")
check(bool(rt.eval("PLAIN_MOVING == nil and PLAIN_WAS_MOVING == false")), "plain right on a row does NOT move the HUD window")
check(bool(rt.eval("SHIFT_MOVING == true and SHIFT_WAS_MOVING == true")), "Shift+right on a row starts moving the HUD window (proxy)")
check(bool(rt.eval("(not SHIFT_AFTER) and SHIFT_AFTER_MOVING == false")), "releasing Shift+right stops the HUD window move")
# same on the window background itself
rt.execute("""
local f = RLSuite.raidFrame.frame
f._rlsMoving = nil; f._moving = false
f._scripts.OnMouseDown(f, 'RightButton')
FPLAIN = f._rlsMoving
IsShiftKeyDown = function() return true end
f._scripts.OnMouseDown(f, 'RightButton')
FSHIFT = f._rlsMoving; FSHIFT_MOVING = f._moving
f._scripts.OnMouseUp(f, 'RightButton')
IsShiftKeyDown = SAVED_ISD2
""")
check(bool(rt.eval("FPLAIN == nil and FSHIFT == true and FSHIFT_MOVING == true")), "Shift+right on the HUD background also starts/stops the move")

# --- F.2e silent-kill hardening: empty-string saved msg, missing row.name ---
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
local b = row.flaskIcon
CHAT_LOG = {}
row._lastAlert = nil
RLSuite.raidFrame.db.alerts = { flask = "" }  -- HQ killer: config salvata vuota = STOP silenzioso in ogni versione precedente
b._scripts.OnMouseDown(b, 'LeftButton'); b._scripts.OnMouseUp(b, 'LeftButton'); if b._scripts.OnUpdate then b._scripts.OnUpdate(b, 0.016) end
EMPTYCFG_W = 0
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then EMPTYCFG_W = EMPTYCFG_W + 1 end end
RLSuite.raidFrame.db.alerts = {}
CHAT_LOG = {}
row._lastAlert = nil
SAVED_ROW_NAME = row.name
row.name = nil  -- stessa fonte-datata del ramo destro: member.name
b._scripts.OnMouseDown(b, 'LeftButton'); b._scripts.OnMouseUp(b, 'LeftButton'); if b._scripts.OnUpdate then b._scripts.OnUpdate(b, 0.016) end
NONAME_W = 0
NONAME_DEST = false
for _, e in ipairs(CHAT_LOG) do if string.sub(e, 1, 8) == 'WHISPER|' then NONAME_W = NONAME_W + 1; if string.find(e, row.member.name) then NONAME_DEST = true end end end
row.name = SAVED_ROW_NAME
""")
check(rt.eval("EMPTYCFG_W") == 1, "empty saved alert message now falls back to the default whisper (was a silent dead-end)")
check(rt.eval("NONAME_W") == 1 and bool(rt.eval("NONAME_DEST")), "left click works even with row.name missing (falls back to member.name)")

# --- F.2f click on the PLAYER BAR targets the player (user feature: target on PRESS) ---
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
local function reset_click()
    row._targetT = nil
    row._pendingRowClick = nil
    row._manualDrag = nil
    row:SetScript('OnUpdate', nil)
    LAST_TARGET = nil; LAST_TARGNAME = nil
end
row._lastAlert = nil
SAVED_MU = (row.member and row.member.unit) or nil
SAVED_RU = row.unit
SAVED_RN = row.name
SAVED_MF = row.member and row.member.fake
SAVED_RF = row.fake
SAVED_GCP4 = GetCursorPosition
GetCursorPosition = function() return 200, 110 end  -- su una barra, sotto NESSUNA icona
-- 1) roster finto di debug (caso utente): NESSUN bonk, NESSUN target
reset_click()
row._scripts.OnMouseDown(row, 'LeftButton')
row._scripts.OnMouseUp(row, 'LeftButton')
if row._scripts.OnUpdate then row._scripts.OnUpdate(row, 0.016) end
TGT_FAKE = LAST_TARGET or LAST_TARGNAME
-- 2) unit valida raid reale → TargetUnit ALLA PRESSIONE
reset_click()
if row.member then row.member.unit = 'raid7'; row.member.fake = false end
row.unit = 'raid7'; row.fake = false
SAVED_UE = UnitExists
UnitExists = function(u) return u == 'raid7' end
row._scripts.OnMouseDown(row, 'LeftButton')
TGT_PRESS = LAST_TARGET
row._scripts.OnMouseUp(row, 'LeftButton')
if row._scripts.OnUpdate then row._scripts.OnUpdate(row, 0.016) end
TGT1 = LAST_TARGET
-- 3) NO unit ma NOME reale (barra): TargetByName sul nome esatto
reset_click()
if row.member then row.member.unit = nil end
row.unit = nil
row.name = 'PippoRosso'
row._scripts.OnMouseDown(row, 'LeftButton')
row._scripts.OnMouseUp(row, 'LeftButton')
if row._scripts.OnUpdate then row._scripts.OnUpdate(row, 0.016) end
TGT_NAME = LAST_TARGNAME
-- 4) SHIFT+click: NON targettare (gesto drag player)
reset_click()
if row.member then row.member.unit = 'raid7' end
row.unit = 'raid7'
IsShiftKeyDown = function() return true end
row._scripts.OnMouseDown(row, 'LeftButton')
row._scripts.OnMouseUp(row, 'LeftButton')
if row._scripts.OnUpdate then row._scripts.OnUpdate(row, 0.016) end
TGT2 = LAST_TARGET or LAST_TARGNAME
-- 5) press+move SENZA shift: target-on-press gia' partito (Grid-style)
reset_click()
IsShiftKeyDown = SAVED_ISD2
GetCursorPosition = function() return 200, 110 end
row._scripts.OnMouseDown(row, 'LeftButton')
TGT_PRESS_BEFORE_MOVE = LAST_TARGET
-- cleanup
if row.member then row.member.unit = SAVED_MU; row.member.fake = SAVED_MF end
row.name = SAVED_RN
row.fake = SAVED_RF
row.unit = SAVED_RU
GetCursorPosition = SAVED_GCP4
UnitExists = SAVED_UE
row:SetScript('OnUpdate', nil)
""")
check(bool(rt.eval("TGT_FAKE == nil")), "debug fake roster: bar click does NOT bonk error-invalid-unit (no target for non-existing units)")
check(rt.eval("TGT_PRESS") == 'raid7' and rt.eval("TGT1") == 'raid7', "plain left click on a player bar targets on PRESS (name row, real unit)")
check(rt.eval("TGT_NAME") == 'PippoRosso', "click on the NAME targets the player with THAT name (TargetByName fallback)")
check(bool(rt.eval("TGT2 == nil")), "Shift+left on a bar does NOT target (drag gesture)")
check(rt.eval("TGT_PRESS_BEFORE_MOVE") == 'raid7', "target fires on PRESS even before any movement (Grid-style, cursor-move cannot suppress it)")

# --- F.2g SECURE anti-failure layer: engine-hardware click-to-target (Grid/Clique style) ---
check(bool(rt.eval("RLSuite.raidFrame.rows[1].secTarget ~= nil")), "every row has the SecureActionButtonTemplate target overlay")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].secTarget:GetAttribute('type1') == 'target'")), "secure overlay: engine action is /target")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].secTarget._clickButtons ~= nil and RLSuite.raidFrame.rows[1].secTarget._clickButtons[1] == 'LeftButtonDown'")), "secure overlay targets AT PRESS (LeftButtonDown)")
# debug fake roster: member F5 fake → overlay hidden; FillSlot real unit → shown + unit
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
SEC_FAKE_HIDDEN = (row.secTarget:IsShown() == false)
local savedMember = row.member
RLSuite.raidFrame:FillSlot(row, { name = 'Realone', class = 'WARRIOR', unit = 'raid9', fake = false, raidIndex = 9 })
SEC_UNIT = row.secTarget:GetAttribute('unit')
SEC_SHOWN = row.secTarget:IsShown()
SAVED_MEMBER_G = savedMember
""")
check(bool(rt.eval("SEC_FAKE_HIDDEN")), "fake/debug unit: secure target overlay stays hidden (Lua path traces instead)")
check(rt.eval("SEC_UNIT") == 'raid9' and bool(rt.eval("SEC_SHOWN")), "real unit: secure overlay shows and stores the exact unit to target")
rt.execute("""
local row = RLSuite.raidFrame.rows[1]
RLSuite.raidFrame:FillSlot(row, SAVED_MEMBER_G)
""")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].member.name == 'F5'")), "roster restored after secure-layer test")

# --- F.3 Raid Frame layout options: font / outline / bar texture / opacity ---
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args.font ~= nil")), "Layout -> Font type present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args.fontOutline ~= nil")), "Layout -> Font outline toggle present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args.barTexture ~= nil")), "Layout -> Bar texture present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args.alpha ~= nil")), "Layout -> Opacity slider present")
rt.execute(r"""
local o = RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args
o.barTexture.set(nil, 'Interface\\Buttons\\WHITE8x8')
o.font.set(nil, 'Fonts\\MORPHEUS.TTF')
o.fontOutline.set(nil, false)
o.alpha.set(nil, 0.8)
""")
check(rt.eval("RLSuite.raidFrame.rows[1].bar._statusbarTex") == r"Interface\Buttons\WHITE8x8", "bar texture option applied to the HP bars")
check(bool(rt.eval(r"RLSuite.raidFrame.rows[1].bar.nameText._fontArgs[1] == 'Fonts\\MORPHEUS.TTF'")), "font type option applied to the player names")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].bar.nameText._fontArgs[3] == ''")), "font outline toggle removes the outline")
check(rt.eval("RLSuite.raidFrame.frame._alpha") == 0.8, "opacity option applied to the whole HUD")
rt.execute(r"""
local o = RLSuite.config:BuildOptionsTable().args.raidframe.args.layout.args
o.barTexture.set(nil, 'Interface\\TargetingFrame\\UI-StatusBar')
o.font.set(nil, 'Fonts\\FRIZQT__.TTF')
o.fontOutline.set(nil, true)
o.alpha.set(nil, 1)
""")

check(rt.eval("LAST_ERROR") is None or rt.eval("LAST_ERROR") == None, "no errors during Scenario F (LAST_ERROR=%r)" % rt.eval("LAST_ERROR"))

print()
print("== Scenario G: main bar MT/OT + realtime config, loot pickup stack, debug-off clear, WL gold drag, real-raid join ==")

# --- G.1 Config -> Window sliders apply to the main bar IN REAL TIME ---
rt.execute("W0 = RLSuite.mainWindow.frame:GetWidth()")
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.window.args.matrixCols.set(nil, 4)")
rt.execute("W1 = RLSuite.mainWindow.frame:GetWidth()")
check(bool(rt.eval("W1 > W0")), "matrix Columns slider re-layouts the main bar in real time (w %d -> %d)" % (rt.eval("W0"), rt.eval("W1")))
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.window.args.matrixCols.set(nil, 2)")
rt.execute("H0 = RLSuite.mainWindow.frame:GetHeight()")
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.window.args.matrixRows.set(nil, 8)")
rt.execute("H1 = RLSuite.mainWindow.frame:GetHeight()")
check(bool(rt.eval("H1 > H0")), "matrix Rows slider re-layouts the main bar in real time (h %d -> %d)" % (rt.eval("H0"), rt.eval("H1")))
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.window.args.matrixRows.set(nil, 4)")

# --- G.2 MT / OT: two small buttons sharing ONE matrix cell ---
check(bool(rt.eval("RLSuite.mainWindow.mtBtn ~= nil and RLSuite.mainWindow.otBtn ~= nil")), "MT / OT buttons exist on the main bar")
check(bool(rt.eval("RLSuite.mainWindow.mtBtn:GetWidth() == 43 and RLSuite.mainWindow.otBtn:GetWidth() == 43")), "MT and OT are half-width ((90-4)/2 = 43px)")
check(bool(rt.eval("RLSuite.mainWindow.mtBtn:GetHeight() == 22 and RLSuite.mainWindow.otBtn:GetHeight() == 22")), "MT / OT keep the matrix button height (22px)")
check(bool(rt.eval("select(1, RLSuite.mainWindow.mtBtn:GetPoint(1)) == 'TOPLEFT' and select(1, RLSuite.mainWindow.otBtn:GetPoint(1)) == 'TOPLEFT'")), "MT / OT positioned inside the matrix")
rt.execute("""
local mw = RLSuite.mainWindow
MTXOF, MTYOF = select(4, mw.mtBtn:GetPoint(1)), select(5, mw.mtBtn:GetPoint(1))
RFXOF, RFYOF = select(4, mw.tabs['raidframe']:GetPoint(1)), select(5, mw.tabs['raidframe']:GetPoint(1))
LOOTXOF, LOOTYOF = select(4, mw.tabs['loot']:GetPoint(1)), select(5, mw.tabs['loot']:GetPoint(1))
""")
check(bool(rt.eval("MTXOF == RFXOF")), "MT / OT pair shares the Raid Frame column (cell under it)")
check(bool(rt.eval("MTYOF == RFYOF - (22 + 4)")), "MT / OT sits directly UNDER the Raid Frame button")
check(bool(rt.eval("LOOTXOF == RFXOF + 90 + 8 and LOOTYOF == MTYOF")), "Loot shifts one cell aside to free the spot under Raid Frame")
rt.execute("""
_OLD_UnitExists = UnitExists
_OLD_UnitName = UnitName
_OLD_IsRaidLeader = IsRaidLeader
MT_CALLS = {}
SetPartyAssignment = function(role, unit) table.insert(MT_CALLS, tostring(role) .. '|' .. tostring(unit)) end
UnitExists = function(u) return u == 'target' end
UnitName = function(u) if u == 'target' then return 'Bossunit' end return 'Testplayer' end
IsRaidLeader = function() return true end
local b = RLSuite.mainWindow.mtBtn
if b and b._scripts.OnClick then b._scripts.OnClick(b, 'LeftButton') end
local o = RLSuite.mainWindow.otBtn
if o and o._scripts.OnClick then o._scripts.OnClick(o, 'LeftButton') end
""")
check(rt.eval("MT_CALLS[1]") == "MAINTANK|target", "MT click assigns target as MAINTANK via SetPartyAssignment")
check(rt.eval("MT_CALLS[2]") == "MAINASSIST|target", "OT click assigns target as MAINASSIST via SetPartyAssignment")
rt.execute("""
UnitExists = function(u) return u == 'player' end
local c = #MT_CALLS
local b = RLSuite.mainWindow.mtBtn
if b and b._scripts.OnClick then b._scripts.OnClick(b, 'LeftButton') end
MT_NOGROW = (#MT_CALLS == c)
""")
check(bool(rt.eval("MT_NOGROW == true")), "MT click with no target does NOT call SetPartyAssignment")
rt.execute("""
UnitExists = _OLD_UnitExists
UnitName = _OLD_UnitName
IsRaidLeader = _OLD_IsRaidLeader
SetPartyAssignment = nil
""")

# --- G.3 Groupmaking: reqBox hugs the button row + thicker icon borders ---
rt.execute("local p, rel, rp, x, y = RLSuite.groupmaking.reqBox:GetPoint(3); REQBOX_OK = (p == 'BOTTOMLEFT' and rel == RLSuite.groupmaking.spamBtn and rp == 'TOPLEFT' and y == 8)")
check(bool(rt.eval("REQBOX_OK == true")), "requirements box bottom-anchored 8px above the buttons (no dead space)")
check(bool(rt.eval("RLSuite.groupmaking.compSlots[1]._backdrop.edgeSize == nil")), "comp slot body has no border anymore (it sat under the spec icon)")
check(bool(rt.eval("RLSuite.groupmaking.compSlots[1].borderFrame ~= nil")), "comp slot has a dedicated border overlay frame")
check(bool(rt.eval("RLSuite.groupmaking.compSlots[1].borderFrame._backdrop.edgeSize == 16 and RLSuite.groupmaking.compSlots[1].borderFrame._backdrop.edgeFile ~= nil")), "comp slot border overlay carries the edge (edgeSize 16)")
check(bool(rt.eval("RLSuite.groupmaking.compSlots[1].borderFrame:GetParent() == RLSuite.groupmaking.compSlots[1]")), "border overlay is a child of the slot (draws above the spec icon)")
check(bool(rt.eval("RLSuite.groupmaking.compSlots[1].roleIcon:GetParent() == RLSuite.groupmaking.compSlots[1].borderFrame")), "role icon lives ON the border overlay (draws above the border)")
check(bool(rt.eval("RLSuite.groupmaking.compSlots[1].roleIconBg:GetParent() == RLSuite.groupmaking.compSlots[1].borderFrame")), "role icon backdrop lives ON the border overlay (draws above the border)")
check(bool(rt.eval("RLSuite.groupmaking.specCells[1].buttons[1]._backdrop.edgeSize == 16")), "class bar spec icons use even thicker borders (edgeSize 16)")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[1]._backdrop.edgeSize == 14")), "Raid Group slots a bit thicker than before without self-clipping (edgeSize 14)")

# --- G.7 Debug OFF empties the Loot Manager (history + pickup windows) ---
rt.execute("RLSuite.lootManager:AddToHistory('|cffff8000|Hitem:1|h[Test]|h|r', 'Test Item', 'tex', 4)")
rt.execute("RLSuite.lootManager:ShowTradeWindow({ itemTexture = 'tex', itemLink = nil })")
check(bool(rt.eval("#RLSuite.lootManager.history > 0 and #RLSuite.lootManager.tradeWindows > 0")), "loot manager populated before debug-off test")
rt.execute("RLSuite.db.profile.debug = false; RLSuite:ApplyDebugMode()")
check(bool(rt.eval("#RLSuite.lootManager.history == 0")), "disabling debug mode empties the loot history")
check(bool(rt.eval("#RLSuite.lootManager.tradeWindows == 0")), "disabling debug mode closes the pickup windows")
check(bool(rt.eval("RLSuite.lootManager.currentRoll == nil")), "disabling debug mode drops the active roll")

# --- G.4 Raid Group populates when JOINING an already formed raid ---
# On a real 3.3.5 client the global IsInRaid() does not exist (4.0+ API).
rt.execute("""
_OLD_IsInRaid = IsInRaid
_OLD_GetNumRaidMembers = GetNumRaidMembers
_OLD_GetRaidRosterInfo = GetRaidRosterInfo
IsInRaid = nil
RLSUITE_RAID = {
    {name='Tanka', subgroup=1}, {name='Heala', subgroup=1},
    {name='Dpsa', subgroup=2}, {name='Dpsb', subgroup=3},
    {name='Dpsc', subgroup=4}, {name='Dpsd', subgroup=5}, {name='Dpse', subgroup=6},
}
GetNumRaidMembers = function() return #RLSUITE_RAID end
GetRaidRosterInfo = function(i)
    local m = RLSUITE_RAID[i]
    if m then return m.name, 0, m.subgroup, 80, 'Warrior', 'WARRIOR', 'Icecrown', true, false end
    return nil
end
RLSuite.groupmaking:UpdateWLGroups()
RAID_NAMES = {}
for _, s in ipairs(RLSuite.groupmaking.wlGroupSlots) do
    if s.nameFS and s.nameFS:GetText() ~= '' then table.insert(RAID_NAMES, s.nameFS:GetText()) end
end
RAID_NAMES = table.concat(RAID_NAMES, ',')
""")
check(bool(rt.eval("RAID_NAMES:find('Tanka', 1, true) ~= nil")), "joining a half-full raid: G1 member shown without global IsInRaid")
check(bool(rt.eval("RAID_NAMES:find('Dpsa', 1, true) ~= nil")), "joining a half-full raid: G2 member shown")
check(bool(rt.eval("RAID_NAMES:find('Dpse', 1, true) ~= nil")), "joining a half-full raid: G6 member shown")
rt.execute("""
IsInRaid = _OLD_IsInRaid
GetNumRaidMembers = _OLD_GetNumRaidMembers
GetRaidRosterInfo = _OLD_GetRaidRosterInfo
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
RLSuite:ResetDebugRaid()
for i=1,3 do RLSuite:DebugInviteAccept('Hl'..i, 'WARRIOR') end
""")

# --- G.5 golden border highlight on the drop-target slot while dragging ---
rt.execute("""
GetCursorPosition = function() return 101, 104 end
local slots = RLSuite.groupmaking.wlGroupSlots
-- Lo Scenario F lascia override di geometria per-istanza sugli slot:
-- azzerarle, cosi' solo lo slot 8 viene colpito dall'hit-test del cursore.
for _, b in ipairs(slots) do
    b.GetLeft, b.GetRight, b.GetBottom, b.GetTop = nil, nil, nil, nil
end
slots[8].GetLeft = function() return 100 end
slots[8].GetRight = function() return 150 end
slots[8].GetBottom = function() return 100 end
slots[8].GetTop = function() return 116 end
local src = slots[1]
src._scripts.OnDragStart(src, 'LeftButton')
RLSuite.groupmaking:WlDragTick()
""")
check(bool(rt.eval("RLSuite.groupmaking.wlDragTracker ~= nil and RLSuite.groupmaking.wlDragTracker:IsShown() == true")), "drag starts the cursor tracker")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[8]._wlDropHl == true")), "slot under the cursor flagged as drop target")
rt.execute("local c = RLSuite.groupmaking.wlGroupSlots[8]._backdropBorderColor; GOLD_OK = (c[1] == 1 and c[2] == 0.82 and c[3] == 0)")
check(bool(rt.eval("GOLD_OK == true")), "drop target slot shows the GOLDEN border while dragging")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[2]._wlDropHl == nil")), "other slots not highlighted")
rt.execute("""
GetCursorPosition = function() return 500, 500 end
RLSuite.groupmaking:WlDragTick()
""")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[8]._wlDropHl == nil")), "moving the cursor away removes the highlight")
rt.execute("local c = RLSuite.groupmaking.wlGroupSlots[8]._backdropBorderColor; GREY_OK = (c[1] == 0.3 and c[3] == 0.32)")
check(bool(rt.eval("GREY_OK == true")), "highlight removed: empty slot border back to grey")
rt.execute("""
GetCursorPosition = function() return 101, 104 end
local src = RLSuite.groupmaking.wlGroupSlots[1]
src._scripts.OnDragStop(src)
""")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[8].playerName == 'Testplayer'")), "drop onto the highlighted slot moves the player there")
check(bool(rt.eval("RLSuite.groupmaking.wlGroupSlots[8]._wlDropHl == nil")), "highlight cleared after the drop")
check(bool(rt.eval("RLSuite.groupmaking.wlDragTracker:IsShown() == false")), "cursor tracker stopped after the drop")
rt.execute("local c = RLSuite.groupmaking.wlGroupSlots[8]._backdropBorderColor; CLASS_OK = math.abs((c[1] or 0) - 0.78) < 0.01")
check(bool(rt.eval("CLASS_OK == true")), "filled slot border back to class color after the drop")

# --- G.6 pickup windows stack one BELOW the other + slim layout ---
rt.execute("RLSuite.lootManager:CloseAllTradeWindows()")
rt.execute("RLSuite.lootManager:ShowTradeWindow({ itemTexture = 'tex', itemLink = '|cffffffff|Hitem:2|h[Loot A]|h|r' })")
rt.execute("RLSuite.lootManager:ShowTradeWindow({ itemTexture = 'tex', itemLink = '|cffffffff|Hitem:3|h[Loot B]|h|r' })")
check(bool(rt.eval("#RLSuite.lootManager.tradeWindows == 2")), "two pickup windows can be open at once")
rt.execute("local p, rel, rp, x, y = RLSuite.lootManager.tradeWindows[2]:GetPoint(1); STACK_OK = (p == 'TOP' and rel == RLSuite.lootManager.tradeWindows[1] and rp == 'BOTTOM' and y == -6)")
check(bool(rt.eval("STACK_OK == true")), "second pickup window anchors BELOW the first (not overlapping)")
check(bool(rt.eval("RLSuite.lootManager.tradeWindows[1]:GetHeight() == 44")), "pickup window is as tall as the item icon (32px) + padding")
rt.execute("local f = RLSuite.lootManager.tradeWindows[1]; local p, rel, rp = f.text:GetPoint(1); TXT_OK = (p == 'LEFT' and rel == f.icon and rp == 'RIGHT')")
check(bool(rt.eval("TXT_OK == true")), "'Click to pick up item' sits to the RIGHT of the icon")
check(bool(rt.eval("RLSuite.lootManager.tradeWindows[1].text:GetText() == 'Click to pick up item'")), "pickup text preserved")
rt.execute("RLSuite.lootManager:CloseTradeWindow(RLSuite.lootManager.tradeWindows[1])")
rt.execute("local p, rel, rp, x, y = RLSuite.lootManager.tradeWindows[1]:GetPoint(1); RISE_OK = (p == 'CENTER' and rel == UIParent and rp == 'CENTER' and y == 140)")
check(bool(rt.eval("RISE_OK == true")), "closing the first pickup window makes the next one rise to the base anchor")
rt.execute("RLSuite.lootManager:CloseAllTradeWindows()")

# --- G.8 Groupmaking: 2-column class bar order + reduced minimum height ---
rt.execute("""
CLASSSEQ = {}
for i, cell in ipairs(RLSuite.groupmaking.specCells) do
    local b = cell.buttons and cell.buttons[1]
    CLASSSEQ[#CLASSSEQ+1] = b and b.class or '?'
end
CLASSSEQ = table.concat(CLASSSEQ, ',')
""")
check(rt.eval("CLASSSEQ") == "WARRIOR,PALADIN,ROGUE,PRIEST,SHAMAN,MAGE,DEATHKNIGHT,WARLOCK,HUNTER,DRUID",
    "class bar order for the 2-column layout (col1 Warrior/Rogue/Shaman/DK/Hunter, col2 Paladin/Priest/Mage/Warlock/Druid)")
rt.execute("""
RLSuite.groupmaking.classBar:SetWidth(316)
RLSuite.groupmaking:LayoutClassBar()
CELLPOS = {}
for i, cell in ipairs(RLSuite.groupmaking.specCells) do
    local p, rel, rp, x, y = cell.frame:GetPoint(1)
    CELLPOS[i] = math.floor((x or 0) + 0.5) .. '/' .. math.floor((y or 0) + 0.5)
end
""")
check(rt.eval("CELLPOS[5]") == "0/-96", "Shaman -> first column, row 3")
check(rt.eval("CELLPOS[6]") == "159/-96", "Mage -> second column, row 3")
check(rt.eval("CELLPOS[8]") == "159/-144", "Warlock -> second column, directly under Mage")
check(rt.eval("CELLPOS[10]") == "159/-192", "Druid -> second column, directly under Warlock")
check(rt.eval("CELLPOS[7]") == "0/-144", "DK -> first column, directly under Shaman")
check(rt.eval("CELLPOS[9]") == "0/-192", "Hunter -> first column, under DK (Shaman column)")
check(bool(rt.eval("RLSuite.groupmaking:MinHeight() == RLSuite.groupmaking.topRow:GetHeight() + 328")), "minimum window height reduced to topRow + 328 (dead space removed)")

# --- G.9 Groupmaking: minimum width = bottom button row overall width ---
check(bool(rt.eval("RLSuite.groupmaking.specsLbl ~= nil")), "'Show specs in message' label reference stored for MinWidth")
check(bool(rt.eval("RLSuite.groupmaking:MinWidth() == 380 + math.ceil(RLSuite.groupmaking.specsLbl:GetStringWidth())")),
    "MinWidth = 16+L-margin + Start Spam(100)+8 + Preview(100)+6 + check(24) + label width + 10 + InviteEngine(100) + 16+R-margin")
check(bool(rt.eval("select(1, RLSuite.windowMins.groupmaking()) == RLSuite.groupmaking:MinWidth()")),
    "registered windowMins.groupmaking uses the button-row width as minimum width")
check(bool(rt.eval("RLSuite.groupmaking:MinWidth() >= 500")), "minimum width fits the whole button row (>= 500)")

# --- G.10 Loot Manager: roll keys -> RAID WARNING, give-to line, keep rolling with pickup open ---
rt.execute("""
RLSuite.db.profile.debug = true
CHAT_LOG = {}
local lm = RLSuite.lootManager
lm:AddToHistory('|cffff8000|Hitem:42|h[Rolled Item]|h|r', 'Rolled Item', 'tex', 4)
lm:SelectItem(lm.history[#lm.history])
lm:StartRoll('MS')
""")
rt.execute("""
FOUND_RW = false
for _, e in ipairs(CHAT_LOG or {}) do
    if string.find(e, '%[RAID_WARNING%]') and string.find(e, 'Roll MS for Rolled Item') then FOUND_RW = true end
end
""")
check(bool(rt.eval("FOUND_RW")), "clicking a roll key sends the announce as RAID WARNING (debug echo: [RAID_WARNING])")
rt.execute("""
local lm = RLSuite.lootManager
lm.currentRoll.rolls = { {name = 'Winnerbot', roll = 99} }  -- deterministic winner (no ties)
lm:AnnounceWinner()
local tw = lm.tradeWindows[#lm.tradeWindows]
W10_WINNER = lm.currentRoll and lm.currentRoll.item.assignedTo
W10_SELTEXT = lm.selectedItemText and lm.selectedItemText:GetText() or '?'
W10_NOSEL = (lm.selectedItem == nil)
W10_GIVETO = (tw and tw.giveTo) and tw.giveTo:GetText() or '?'
W10_GBELOW = false
if tw and tw.giveTo and tw.text then
    local p, rel = tw.giveTo:GetPoint(1)
    W10_GBELOW = (p == 'TOPLEFT' and rel == tw.text)
end
W10_GRAY = false
W10_DESAT = false
for _, row in ipairs(lm.histRows or {}) do
    if row.entry and row.entry.assignedTo == 'Winnerbot' then
        W10_GRAY = row.name and row.name._tc and row.name._tc[1] ~= nil
            and math.abs(row.name._tc[1] - 0.45) < 0.001
        W10_DESAT = row.icon and row.icon._desat == true or false
    end
end
""")
check(rt.eval("W10_WINNER") == "Winnerbot", "winner recorded on the rolled item")
check(bool(rt.eval("W10_NOSEL")), "selected item cleared after the win (roll another piece with pickup open)")
check(rt.eval("W10_SELTEXT") == rt.eval("RLSuite.L['No item selected']"), "selected item row shows 'No item selected' again")
check(rt.eval("W10_GIVETO") == "give to: Winnerbot", "pickup window shows 'give to: <winner>' under the pickup line")
check(bool(rt.eval("W10_GBELOW")), "give-to line is anchored below the 'Click to pick up item' text")
check(bool(rt.eval("W10_GRAY")), "rolled item row is greyed out in the loot list")
check(bool(rt.eval("W10_DESAT")), "rolled item icon is desaturated in the loot list")
rt.execute("RLSuite.lootManager:CloseAllTradeWindows()")

check(rt.eval("LAST_ERROR") is None or rt.eval("LAST_ERROR") == None, "no errors during Scenario G (LAST_ERROR=%r)" % rt.eval("LAST_ERROR"))

print()
if fails:
    print("RESULT: %d FAILURES: %s" % (len(fails), fails))
    sys.exit(1)
print("RESULT: ALL CHECKS PASSED")
