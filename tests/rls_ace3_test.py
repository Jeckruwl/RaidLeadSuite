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
function methods:SetFrameStrata(s) return self end
function methods:SetFrameLevel(l) return self end
function methods:EnableMouse(b) return self end
function methods:EnableKeyboard(b) return self end
function methods:SetMovable(b) return self end
function methods:SetResizable(b) return self end
function methods:RegisterForDrag(...) return self end
function methods:RegisterForClicks(...) return self end
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
function methods:CreateTexture(n, layer) local t=newFrame({}); t._layer=layer; return t end
function methods:CreateFontString(n, layer, tmpl) local f=newFrame({}); f._layer=layer; f._isFontString=true; return f end
function methods:SetText(t) self._text = t or ""; return self end
function methods:GetText() return self._text end
function methods:SetFont(...) return self end
function methods:SetJustifyH(...) return self end
function methods:SetJustifyV(...) return self end
function methods:SetWordWrap(b) self._wordWrap = b and true or false; return self end
function methods:SetTextColor(...) return self end
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
function methods:SetStatusBarTexture(...) return self end
function methods:SetStatusBarColor(...) return self end
function methods:SetAlpha(a) return self end
function methods:StartMoving() return self end
function methods:StopMovingOrSizing() return self end
function methods:StartSizing(...) return self end
function methods:SetMinResize(...) return self end
function methods:SetClampedToScreen(b) return self end
function methods:SetAllPoints(...) return self end
function methods:SetTexCoord(...) return self end
function methods:SetTexture(...) return self end
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
function methods:EnableMouse(b) return self end
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
function methods:SetWidth(...) return self end
function methods:GetIndentedWordWrap() return false end
function methods:SetIndentedWordWrap(...) return self end

CreateFrame = function(typ, name, parent, template)
    local o = newFrame({ _type=typ, _name=name, _template=template, _parent = parent })
    if name then _G[name] = o; FRAMES[name] = o end
    return o
end
UIParent = newFrame({ _name = "UIParent" })
UIParent._w = 1920; UIParent._h = 1080
GameTooltip = newFrame({ _name = "GameTooltip" })
DEFAULT_CHAT_FRAME = newFrame({ _name = "DEFAULT_CHAT_FRAME" })
SlashCmdList = {}
hash_SlashCmdList = {}

LAST_ERROR = nil
function geterrorhandler() return function(err) LAST_ERROR = err; return err end end
function IsLoggedIn() return LOGGED_IN end
function GetTime() return os.clock() end
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
function SendChatMessage(msg, typ, lang, dest) end
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
function methods:SetDesaturated(b) return self end
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

# --- Autoinviter calendar mirror: no event -> link/create hint ---
rt.execute("RLSuite.groupmaking:SelectAutoinviteEvent('none', true)")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoEventTitle:GetText() == 'No calendar event linked'")), "calendar mirror shows 'No calendar event linked' when nothing exists")
check(bool(rt.eval("RLSuite.groupmaking.ieAutoEventCreate ~= nil")), "Create event button exists for the calendar mode")

check(rt.eval("LAST_ERROR") is None or rt.eval("LAST_ERROR") == None, "no errors during Scenario D (LAST_ERROR=%r)" % rt.eval("LAST_ERROR"))

print()
if fails:
    print("RESULT: %d FAILURES: %s" % (len(fails), fails))
    sys.exit(1)
print("RESULT: ALL CHECKS PASSED")
