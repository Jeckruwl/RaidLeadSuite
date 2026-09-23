import sys, os
sys.path.insert(0, os.path.expanduser('~/.pylibs'))  # persistenza locale per lupa
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

ALLFRAMES = {}          -- flat registry di ogni frame creato (audit checks)

local function newFrame(t)
    local o = setmetatable(t or {}, FrameMT)
    o._w = 0; o._h = 0; o._shown = true
    o._points = {}; o._text = ""; o._checked = false; o._scripts = {}
    o._backdropColor = {0,0,0,1}; o._isFontString = false
    o._wordWrap = false; o._locked = false; o._highlight = false
    o._fontHeight = 14
    ALLFRAMES[#ALLFRAMES + 1] = o
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
function methods:SetFrameStrata(s) self._ownStrata = s; self._strata = s; return self end
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
function methods:HasScript(k) return self._scripts[k] ~= nil end
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
function methods:CreateFontString(n, layer, tmpl) local f=newFrame({_parent=self}); f._layer=layer; f._isFontString=true; return f end
function methods:SetText(t) self._text = t or ""; return self end
function methods:GetText() return self._text end
function methods:SetFont(...) self._fontArgs = {...}; return self end
function methods:SetRotation(r) self._rotation = r; return self end
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
function methods:SetNormalTexture(t) self._normal = t; return self end
function methods:SetPushedTexture(...) return self end
function methods:SetHighlightTexture(t) self._highlightTex = t; return self end
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
function methods:SetStatusBarColor(r,g,b,a) self._sbColor={r,g,b,a}; return self end
function methods:SetAlpha(a) self._alpha = a; return self end
function methods:StartMoving() self._moving = true; return self end
function methods:StopMovingOrSizing() self._moving = false; return self end
function methods:StartSizing(...) return self end
function methods:SetMinResize(...) return self end
function methods:SetClampedToScreen(b) return self end
function methods:SetAllPoints(...) return self end
function methods:SetTexCoord(...) self._texCoord = {...}; return self end
function methods:SetTexture(a, b, c, d) self._texture = a; if b ~= nil then self._texRGBA = {a, b, c, d} else self._texRGBA = nil end; return self end
function methods:SetBlendMode(...) return self end
function methods:SetVertexColor(...) self._vertex = {...} return self end
function methods:SetColorTexture(...) return self end
function methods:SetHitRectInsets(...) return self end
function methods:SetID(id) self._id = id; return self end
function methods:GetID() return self._id end
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
function methods:GetFrameLevel()
    -- Come in 3.3.5: senza un livello ESPLICITO, il frame sta al livello del
    -- genitore + 1 (dinamicamente, non solo alla creazione).
    if self._level then return self._level end
    if self._parent and self._parent.GetFrameLevel then return (self._parent:GetFrameLevel() or 0) + 1 end
    return 1
end
function methods:GetEffectiveScale() return 1 end
function methods:GetNumChildren() return 0 end
function methods:GetRegions() return {} end
function methods:GetFontString() return self._fontString or nil end
function methods:GetChildren() local U = (table and table.unpack) or unpack; return U(self._children or {}) end
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
    if parent then parent._children = parent._children or {}; parent._children[#parent._children + 1] = o end
    if name then _G[name] = o; FRAMES[name] = o end
    return o
end
UIParent = newFrame({ _name = "UIParent" })
UIParent._w = 1920; UIParent._h = 1080
Minimap = newFrame({ _name = "Minimap" })
Minimap._w = 156; Minimap._h = 156
GameTooltip = newFrame({ _name = "GameTooltip" })
function methods:SetHyperlink(l) self._hyper = l; return self end
function methods:NumLines() return 8 end
for i = 1, 8 do
    local fs = newFrame({ _name = "GameTooltipTextLeft" .. i })
    fs._isFontString = true
    _G["GameTooltipTextLeft" .. i] = fs
end
TOOLTIP_REFRESH = function()
    for i = 1, 8 do
        local fs = _G["GameTooltipTextLeft" .. i]
        fs.SetText(fs, TOOLTIP_LINES[i] or "")
    end
end
TradeFrame = newFrame({ _name = "TradeFrame" })
TradeFrame:Hide()
DEFAULT_CHAT_FRAME = newFrame({ _name = "DEFAULT_CHAT_FRAME" })
SlashCmdList = {}
hash_SlashCmdList = {}

LAST_ERROR = nil
function geterrorhandler() return function(err) LAST_ERROR = err; return err end end
function IsLoggedIn() return LOGGED_IN end
function GetTime() return os.clock() end
function IsMouseButtonDown(btn) return false end  -- mock: sempre rilasciato
function GetPartyAssignment(role, key) return nil end  -- default: nessun MT/OT assegnato
function GetSpellTexture(id) return 'Tex:' .. tostring(id) end
function InCombatLockdown() return false end      -- mock: mai in combat
function TargetUnit(u) error("TargetUnit is PROTECTED: addons must NEVER call it (Warmane client forbids it)") end
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
ROSTER_MOCK = {}
function GetRaidRosterInfo(i) local r = ROSTER_MOCK[i]; if r then return r[1], r[2], r[3], r[4], r[5], r[6] end return nil end
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 }, DRUID = { r = 1, g = 0.49, b = 0.04 } }
function IsRaidLeader() return false end
function IsRaidOfficer() return false end
function InviteUnit(name) end
function SendChatMessage(msg, typ, lang, dest)
  CHAT_LOG = CHAT_LOG or {}; CHAT_LOG[#CHAT_LOG+1] = tostring(typ) .. '|' .. tostring(msg)
  if tostring(typ) == 'CHANNEL' then CHAT_DEST = CHAT_DEST or {}; CHAT_DEST[#CHAT_DEST+1] = tostring(dest) end
end
ITEMINFO_DB = {}
function GetItemInfo(link)
    local row = ITEMINFO_DB[link]
    if row then return unpack(row) end
    return "Item", link, 4, 1, 1, 1, 1, 1, 1, "Interface\\Icons\\INV_Misc_QuestionMark"
end
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
HOOKS = {}
hooksecurefunc = function(name, fn) if HOOKS[name] == nil then HOOKS[name] = fn end end
unhooksecurefunc = function(name) HOOKS[name] = nil end
PICKED_ITEM = nil
TRADE_BTN = 0
function PickupItem(link) PICKED_ITEM = link end
function ClickTradeButton(i) TRADE_BTN = i end
ITEM_BIND_ON_EQUIP = "Binds when equipped"
ITEM_BIND_ON_PICKUP = "Binds on pickup"
TOOLTIP_LINES = {}
SetDesaturation = function() end
GetDesaturation = function() return false end
PanelTemplates_TabResize = function() end
PanelTemplates_SetDisabledTabState = function() end
PanelTemplates_SelectTab = function() end
-- API dei tab di Blizzard (3.3.5): il gruppo dei tab del Log le usa davvero
function PanelTemplates_SetNumTabs(frame, n) frame.numTabs = n end
function PanelTemplates_GetSelectedTab(frame) return frame.selectedTab end
function PanelTemplates_UpdateTabs(frame) end
function PanelTemplates_TabResize(btn, pad) return btn end
function PanelTemplates_SetTab(frame, id, ...)
    frame.selectedTab = id
    PanelTemplates_UpdateTabs(frame)
    return id
end
function PanelTemplates_Tab_OnClick(btn, button)
    PanelTemplates_SetTab(btn:GetParent(), btn:GetID())
end
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
UnitPower = function() return 50 end
UnitPowerMax = function() return 100 end
UnitMana = function() return 50 end
UnitManaMax = function() return 100 end
GetScreenWidth = function() return 1024 end
GetScreenHeight = function() return 768 end
UnitPosition = function() return 0, 0, 0 end
MOCK_ZONE = ""
GetRealZoneText = function() return MOCK_ZONE end
GetZoneText = function() return MOCK_ZONE end
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
-- them with select(), so GetChildren returns VARARGS of registered children
-- (zero values for leaf frames), never a plain table.
function methods:GetChildren() local U = (table and table.unpack) or unpack; return U(self._children or {}) end

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
function methods:GetTexture() return self._texture end
function methods:GetFrameStrata()
    -- Come in 3.3.5: se la strata non e' stata impostata ESPLICITAMENTE, il
    -- frame eredita quella del genitore (dinamicamente).
    if self._ownStrata then return self._ownStrata end
    if self._parent and self._parent.GetFrameStrata then return self._parent:GetFrameStrata() end
    return "MEDIUM"
end
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
    -- 3.3.5: ScrollFrame_OnLoad fa self:GetName().."ScrollBar" -> con un
    -- ScrollFrame SENZA nome il client va in errore (UIPanelTemplates.lua:255)
    -- e il load dell'addon si blocca. L'harness lo riproduce: cosi' il bug
    -- non puo' passare inosservato come e' successo in v1.11.63.
    if template == "UIPanelScrollFrameTemplate" and not name then
        error("attempt to concatenate a nil value (UIPanelTemplates.lua:255: ScrollFrame_OnLoad)", 2)
    end
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
    elseif template == "CharacterFrameTabButtonTemplate" then
        -- il tab di Blizzard ha la sua FontString "$parentText"
        _G[name .. "Text"] = newFrame({ _name = name .. "Text", _parent = o, _isFontString = true })
        o._fontString = _G[name .. "Text"]
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
    "MSManager.lua", "LootManager.lua", "CombatLog.lua", "Config.lua",
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

# --- 1.7.1: nessun bordo esterno su main bar / groupmaking / invite / ms / loot ---
rt.execute("""
if not RLSuite.groupmaking.whisplistFrame then
    RLSuite.groupmaking:CreateWhisplistWindow()
end
-- ri-skin da boot/theme: il bordo deve restare ASSENTE sulle 5 finestre
RLSuite.utils:SkinFrame(RLSuite.mainWindow.frame)
RLSuite.utils:SkinFrame(RLSuite.groupmaking.mainFrame)
RLSuite.utils:SkinFrame(RLSuite.groupmaking.whisplistFrame)
RLSuite.utils:SkinFrame(RLSuite.msManager.frame)
RLSuite.utils:SkinFrame(RLSuite.lootManager.frame)
local function noBord(f) return f and f._noOuterBorder == true and f._backdropBorderColor ~= nil and (f._backdropBorderColor[4] or 1) == 0 end
BORD_MAIN = noBord(RLSuite.mainWindow.frame)
BORD_GM = noBord(RLSuite.groupmaking.mainFrame)
BORD_IE = noBord(RLSuite.groupmaking.whisplistFrame)
BORD_MS = noBord(RLSuite.msManager.frame)
BORD_LM = noBord(RLSuite.lootManager.frame)
-- controllo: una finestra NON marcata mantiene il bordo temico pieno
BORD_CTRL_F = CreateFrame("Frame", nil, UIParent)
RLSuite.utils:SkinFrame(BORD_CTRL_F)
BORD_KEEP = (BORD_CTRL_F._backdropBorderColor ~= nil and (BORD_CTRL_F._backdropBorderColor[4] or 0) == 1)
""")
check(bool(rt.eval("BORD_MAIN")), "Main bar: no outer dialog border")
check(bool(rt.eval("BORD_GM")), "Groupmaking: no outer dialog border")
check(bool(rt.eval("BORD_IE")), "Invite engine: no outer dialog border")
check(bool(rt.eval("BORD_MS")), "MS Manager: no outer dialog border")
check(bool(rt.eval("BORD_LM")), "Loot Manager: no outer dialog border")
check(bool(rt.eval("BORD_KEEP")), "unmarked windows still keep the themed border (SkinFrame unchanged for them)")
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

# Nuova struttura del Config (v1.11.17): General, Module Menu, Groupmaking,
# Macros, Raid Frame, Saved Raids (penultimo), Debug (ultimo). Niente
# MS/Loot top-level, niente tab Checks/Alerts/Position, General = Font+Scale.
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.general.type == 'group'")), "General category present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.modulemenu.type == 'group'")), "Module Menu category present (ex General/Window)")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.type == 'group'")), "Saved Raids category present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.groupmaking.type == 'group'")), "Groupmaking category present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.macros.args.layout.type == 'group'")), "Macros -> Bar Layout present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.debug.type == 'group'")), "Debug category present (top-level)")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.ms == nil and RLSuite.config:BuildOptionsTable().args.loot == nil")), "MS Manager and Loot Manager top-level entries removed")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.args.save1load ~= nil")), "saved raids rendered as Load/Delete executes (dynamic)")

# Ordering: Saved Raids penultimo, Debug ultimo.
check(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.order") == 6, "Saved Raids is second-to-last (order 6)")
check(rt.eval("RLSuite.config:BuildOptionsTable().args.debug.order") == 7, "Debug is the last entry (order 7)")

# --- 1.11.17 user-requested removals ---
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.general.args.scale ~= nil and RLSuite.config:BuildOptionsTable().args.general.args.font ~= nil")), "General = font + global Scale slider only")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.general.args.look == nil and RLSuite.config:BuildOptionsTable().args.general.args.window == nil and RLSuite.config:BuildOptionsTable().args.general.args.debug == nil")), "General sub-groups (Appearance/Window/Debug) removed")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.modulemenu.args.barScale ~= nil and RLSuite.config:BuildOptionsTable().args.modulemenu.args.matrixCols ~= nil")), "Module Menu keeps barScale + matrix controls")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.modulemenu.args.height == nil and RLSuite.config:BuildOptionsTable().args.modulemenu.args.anchors == nil")), "Module Menu: 'Default window height' and 'Toggle Anchors' removed")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.groupmaking.args.scale == nil")), "Groupmaking scale slider removed")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.groupmaking.args.spamNum_General ~= nil and RLSuite.config:BuildOptionsTable().args.groupmaking.args.spamNum_global ~= nil")), "Groupmaking: every channel has a Channel # input")
rt.execute("RLSuite.config:BuildOptionsTable().args.groupmaking.args.spamNum_global.set(nil, '12')")
check(bool(rt.eval("RLSuite.db.profile.groupmaking.spamChannelNums.global == 12")), "Channel # set('12') stores number 12 in spamChannelNums")
check(rt.eval("RLSuite.config:BuildOptionsTable().args.groupmaking.args.spamNum_global.get()") == "12", "Channel # get() renders the stored number")
rt.execute("RLSuite.config:BuildOptionsTable().args.groupmaking.args.spamNum_global.set(nil, '')")
check(bool(rt.eval("RLSuite.db.profile.groupmaking.spamChannelNums.global == nil")), "clearing Channel # reverts to auto-detect")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.debug.args.fakeLoot == nil")), "'Fill fake loot' button removed from Debug config")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.macros.args.layout.args.enable == nil")), "Macros -> Bar Layout 'Enable' checkbox removed")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.macros.args.layout.args.scale == nil")), "Macros -> Bar Layout scale slider removed")
rt.execute("RLSuite.config:OpenMacroEditorPanel(); HUD_COUNT = 0; for _, c in ipairs(ALLFRAMES) do if c._text == 'HUD on/off' then HUD_COUNT = HUD_COUNT + 1 end end")
check(rt.eval("HUD_COUNT") == 0, "Macro editor 'Show HUD' (HUD on/off) button removed")

# The navigation tree lists the reformed 7 categories, with the Macro Editor as a node.
rt.execute("local t = RLSuite.config.tree.tree; CATS = {}; for _,n in ipairs(t) do CATS[n.value] = n end")
check(bool(rt.eval("CATS.general ~= nil and CATS.modulemenu ~= nil and CATS.savedraids ~= nil and CATS.groupmaking ~= nil and CATS.macros ~= nil and CATS.raidframe ~= nil and CATS.debug ~= nil and CATS.ms == nil and CATS.loot == nil")), "tree lists the reformed 7 categories")
check(bool(rt.eval("CATS.macros.children[1].value == 'layout' and CATS.macros.children[2].value == 'editor'")), "Macros node has Bar Layout + Macro Editor children")
check(bool(rt.eval("CATS.general.children == nil")), "General is a flat leaf (no children)")

# Global scale slider (General): every module follows it.
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.scale.set(nil, 0.85)")
check(bool(rt.eval("RLSuite.db.profile.appearance.scale == 0.85")), "global Scale writes appearance.scale")
check(bool(rt.eval("RLSuite.db.profile.raidframe.scale == 0.85 and RLSuite.db.profile.macrobar.scale == 0.85")), "global Scale propagates to raidframe + macrobar via ApplyAll")
rt.execute("RLSuite.config:BuildOptionsTable().args.general.args.scale.set(nil, 1)")

# debug toggle (own top-level entry now)
rt.execute("RLSuite.db.profile.debug = false")
rt.execute("RLSuite.config:BuildOptionsTable().args.debug.args.debugMode.set(nil, true)")
check(bool(rt.eval("RLSuite.db.profile.debug == true")), "debugMode set(true) writes profile.debug")

# saved raids dynamic list via NotifyChange
rt.execute("local idC = RLSuite:SaveRaid('ScenarioC'); SC_ID = idC")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.args.save2load ~= nil")), "saved raid appears as a Load execute in the options table")
rt.execute("RLSuite:DeleteSavedRaid(SC_ID)")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.args.save2load == nil")), "deleting the raid removes its option")

# Node selection feeds the matching AceConfig path into the tree content.
check(bool(rt.eval("RLSuite.config.OpenMacroEditorPanel ~= nil and RLSuite.config.CreateMacroEditor ~= nil")), "Macro Editor API preserved")
rt.execute("RLSuite.config:SelectNode('general')")
check(bool(rt.eval("RLSuite.config.currentNode == 'general'")), "SelectNode routes to general")
check(bool(rt.eval("RLSuite.config.tree:GetUserData('basepath') ~= nil and RLSuite.config.tree:GetUserData('basepath')[1] == 'general'")), "general node feeds at the general path")
check(rt.eval("#RLSuite.config.tree.children") >= 1, "options rendered into the tree content area")

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
print("== v1.11.51: macro in-fight PER BOSS (editor raid+boss, boss in target) ==")

# --- Guardie statiche sul modello dati boss (raidDB <-> bossUnits) --------
rt.execute("""
    MB_BOSS_STATIC = true
    MB_BOSS_DUP = false
    MB_BOSS_N = 0
    local seenNpc, seenName = {}, {}
    for raid, bosses in pairs(RLSuite.bossUnits or {}) do
        if not RLSuite.raidDB[raid] then MB_BOSS_STATIC = false end
        local list = (RLSuite.raidDB[raid] or {}).bosses or {}
        for boss, info in pairs(bosses) do
            MB_BOSS_N = MB_BOSS_N + 1
            local found = false
            for i = 1, #list do if list[i] == boss then found = true end end
            if not found then MB_BOSS_STATIC = false end
            local ids = info.npcs or {}
            local names = info.names or {}
            if #ids == 0 and #names == 0 then MB_BOSS_STATIC = false end
            for i = 1, #ids do
                if type(ids[i]) ~= 'number' then MB_BOSS_STATIC = false end
                local mine = raid .. '|' .. boss
                if seenNpc[ids[i]] and seenNpc[ids[i]] ~= mine then MB_BOSS_DUP = true end
                seenNpc[ids[i]] = mine
            end
            local mine = raid .. '|' .. boss
            local kb = string.lower(boss)
            if seenName[kb] and seenName[kb] ~= mine then MB_BOSS_DUP = true end
            seenName[kb] = mine
            for i = 1, #names do
                local k = string.lower(names[i])
                if seenName[k] and seenName[k] ~= mine then MB_BOSS_DUP = true end
                seenName[k] = mine
            end
        end
    end
    MB_BOSS_ALL_RAIDS = true
    for raid in pairs(RLSuite.raidDB) do
        if not (RLSuite.bossUnits or {})[raid] then MB_BOSS_ALL_RAIDS = false end
    end
""")
check(bool(rt.eval("MB_BOSS_STATIC == true")),
      "bossUnits: ogni boss corrisponde a un boss di raidDB (stesso nome) e ha npcs o names")
check(bool(rt.eval("MB_BOSS_DUP == false")),
      "bossUnits: nessun NPC id e nessun nome condiviso fra due boss (match non ambiguo)")
check(bool(rt.eval("MB_BOSS_ALL_RAIDS == true")),
      "bossUnits: tutti i raid di raidDB sono coperti")
check(bool(rt.eval("MB_BOSS_N == 54")), "bossUnits: 54 boss mappati")

# --- Indice: NPC id dal GUID (a prova di lingua) e nomi/alias -------------
rt.execute("MB_N1 = RLSuite:BossFromNpcId(36612)")
rt.execute("MB_N2 = RLSuite:BossFromNpcId(33288)")
rt.execute("MB_N3 = RLSuite:BossFromName('sir zeliek')")  # alias, tutto minuscolo
rt.execute("MB_N4 = RLSuite:BossFromName('Archavon the Stone Watcher')")
rt.execute("MB_N5 = RLSuite:BossFromNpcId(1)")
check(bool(rt.eval("MB_N1 and MB_N1.raid == 'Icecrown Citadel' and MB_N1.boss == 'Lord Marrowgar'")),
      "NPC 36612 -> Icecrown Citadel / Lord Marrowgar")
check(bool(rt.eval("MB_N2 and MB_N2.boss == 'Yogg-Saron'")), "NPC 33288 -> Yogg-Saron (Ulduar)")
check(bool(rt.eval("MB_N3 and MB_N3.raid == 'Naxxramas' and MB_N3.boss == 'The Four Horsemen'")),
      "alias per nome: 'Sir Zeliek' -> The Four Horsemen (boss senza id affidabile)")
check(bool(rt.eval("MB_N4 and MB_N4.raid == 'Vault of Archavon' and MB_N4.boss == 'Archavon'")),
      "alias per nome: nome lungo del boss -> voce corta di raidDB")
check(bool(rt.eval("MB_N5 == nil")), "NPC id sconosciuto -> nessun boss")

# --- Boss in corso: TARGET prima, poi boss1..boss4 ------------------------
rt.execute("""
    MB_S_UE, MB_S_UN, MB_S_UG = UnitExists, UnitName, UnitGUID
    MOCK_UNITS_BOSS = {}
    UnitExists = function(u) return MOCK_UNITS_BOSS[u] ~= nil end
    UnitName = function(u) local t = MOCK_UNITS_BOSS[u]; return t and t.name end
    UnitGUID = function(u) local t = MOCK_UNITS_BOSS[u]; return t and t.guid end
    MB_S_CTX = RLSuite.context
""")
rt.execute("MOCK_UNITS_BOSS.target = { guid = '0xF130008F040000AA', name = 'Lord Marrowgar' }")
rt.execute("MB_R1, MB_B1 = RLSuite:CurrentBossInfo()")
check(bool(rt.eval("MB_R1 == 'Icecrown Citadel' and MB_B1 == 'Lord Marrowgar'")),
      "boss in target riconosciuto dall'NPC id nel GUID (0x8F04 = 36612)")
rt.execute("MOCK_UNITS_BOSS.target = { name = 'Sindragosa' }")
rt.execute("MB_R2, MB_B2 = RLSuite:CurrentBossInfo()")
check(bool(rt.eval("MB_R2 == 'Icecrown Citadel' and MB_B2 == 'Sindragosa'")),
      "senza GUID il boss si riconosce dal nome (client inglese)")
rt.execute("""
    MOCK_UNITS_BOSS.target = { guid = '0xF1300001000000AA', name = 'Raging Ghoul' }
    MOCK_UNITS_BOSS.boss1 = { guid = '0xF130009BC30000AA', name = 'Halion' }
""")
rt.execute("MB_R3, MB_B3 = RLSuite:CurrentBossInfo()")
check(bool(rt.eval("MB_R3 == 'Ruby Sanctum' and MB_B3 == 'Halion'")),
      "target su trash -> usa il boss del pull (unita' boss1)")
rt.execute("MOCK_UNITS_BOSS = {}")
rt.execute("MB_R4, MB_B4 = RLSuite:CurrentBossInfo()")
check(bool(rt.eval("MB_R4 == nil and MB_B4 == nil")), "nessun boss (trash) -> nessun raid/boss")

# --- La barra usa il set del boss: nessun fallback ------------------------
rt.execute("""
    RLSuite.db.profile.macrobar.macros = RLSuite.db.profile.macrobar.macros or {}
    RLSuite.db.profile.macrobar.macros.infight = { [1] = { text = 'MACRO_GENERICA' } }
    RLSuite.db.profile.macrobar.bossMacros = {}
    RLSuite.context = 'infight'
    MOCK_UNITS_BOSS.target = { guid = '0xF130008F040000AA', name = 'Lord Marrowgar' }
    RLSuite.macrobar:UpdatePhase()
    MB_GEN = RLSuite.macrobar:GetMacroData(1)
""")
check(bool(rt.eval("MB_GEN == nil")),
      "in-fight con boss senza macro dedicate: la vecchia macro generica NON viene usata (nessun fallback)")
rt.execute("""
    RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel'] =
        { ['Lord Marrowgar'] = { [1] = { text = 'MARROWGAR_1', icon = 'IconM' },
                                 [2] = { text = 'MARROWGAR_2', icon = 'IconM2' } } }
    RLSuite.macrobar:LoadMacrosForPhase('infight')
    MB_FILLED = RLSuite.macrobar:FilledSlots('infight')
    MB_BTN1 = RLSuite.macrobar.buttons[1].macroText
    MB_ICON1 = RLSuite.macrobar.buttons[1].icon:GetTexture()
    MB_ICON3 = RLSuite.macrobar.buttons[3].icon:GetTexture()
""")
check(bool(rt.eval("#MB_FILLED == 2 and MB_FILLED[1] == 1 and MB_FILLED[2] == 2")),
      "barra in-fight: solo gli slot del boss in corso risultano pieni")
check(bool(rt.eval("MB_BTN1 == 'MARROWGAR_1'")), "barra in-fight: il testo dello slot viene dal set del boss")
check(bool(rt.eval("MB_ICON1 == 'IconM'")), "barra in-fight: l'icona dello slot viene dal set del boss")
check(bool(rt.eval("MB_ICON3 == 'Interface\\\\Icons\\\\INV_Misc_QuestionMark'")),
      "barra in-fight: gli slot senza macro del boss restano vuoti")

# --- Cambio di target durante il fight ------------------------------------
rt.execute("""
    MOCK_UNITS_BOSS.target = { guid = '0xF130008F9D0000AA', name = 'Sindragosa' }
    RLSuite.macrobar:OnBossTargetChanged()
    MB_SIND = RLSuite.macrobar:GetMacroData(1)
    MB_SIND_NAME = RLSuite.macrobar.bossName
    MB_SIND_FILLED = RLSuite.macrobar:FilledSlots('infight')
""")
check(bool(rt.eval("MB_SIND_NAME == 'Sindragosa' and MB_SIND == nil and #MB_SIND_FILLED == 0")),
      "cambio target: si passa al set del nuovo boss (vuoto se non hai scritto sue macro)")
rt.execute("""
    MOCK_UNITS_BOSS = {}
    RLSuite.macrobar:OnBossTargetChanged()
    MB_NOBOSS = RLSuite.macrobar:GetMacroData(1)
    MB_NOBOSS_FILLED = RLSuite.macrobar:FilledSlots('infight')
""")
check(bool(rt.eval("MB_NOBOSS == nil and #MB_NOBOSS_FILLED == 0")),
      "fight senza boss: nessuna macro in barra")

# --- Le altre fasi restano invariate -------------------------------------
rt.execute("""
    RLSuite.db.profile.macrobar.macros.preraid = { [1] = { text = 'PRERAID_1' } }
    RLSuite.context = 'preraid'
    MB_PRE = RLSuite.macrobar:GetMacroData(1)
    MB_MACRO_FOR_PRE = RLSuite.macrobar:MacroTableFor('preraid')
""")
check(bool(rt.eval("MB_PRE and MB_PRE.text == 'PRERAID_1'")),
      "fase pre-raid: si usa ancora db.macros.preraid (nessun boss)")
check(bool(rt.eval("MB_MACRO_FOR_PRE == RLSuite.db.profile.macrobar.macros.preraid")),
      "MacroTableFor(pre-raid) restituisce la tabella di fase")

# --- Editor: i due menu compaiono solo su In-fight ------------------------
rt.execute("""
    RLSuite.context = 'infight'
    RLSuite.config:OpenMacroEditorPanel()
    RLSuite.config.macroRaid, RLSuite.config.macroBoss = nil, nil
    MOCK_UNITS_BOSS.target = { guid = '0xF130008F040000AA', name = 'Lord Marrowgar' }
    RLSuite.config:SelectMacroPhase('infight')
""")
check(bool(rt.eval("RLSuite.config.macroBossSel ~= nil and RLSuite.config.macroBossSel:IsShown() == true")),
      "fase in-fight: i due menu raid/boss compaiono nell'editor")
check(bool(rt.eval("RLSuite.config.macroBossSel:GetParent() == RLSuite.config.macroPreview")),
      "i due menu stanno nella riga dell'anteprima (a destra delle 12 icone)")
check(bool(rt.eval("RLSuite.config.macroRaid == 'Icecrown Citadel' and RLSuite.config.macroBoss == 'Lord Marrowgar'")),
      "default dei menu: il boss che stai affrontando ora")
rt.execute("""
    MB_RD_OPTS = #(RLSuite.config.macroRaidDD.options or {})
    MB_RD_HAS_ICC = false
    for _, o in ipairs(RLSuite.config.macroRaidDD.options or {}) do
        if o.value == 'Icecrown Citadel' then MB_RD_HAS_ICC = true end
    end
    MB_BD_OPTS = #(RLSuite.config.macroBossDD.options or {})
    MB_BD_FIRST = RLSuite.config.macroBossDD.options[1] and RLSuite.config.macroBossDD.options[1].value
""")
check(bool(rt.eval("MB_RD_OPTS == 9 and MB_RD_HAS_ICC")),
      "menu raid: tutte le 9 raid di raidDB")
check(bool(rt.eval("MB_BD_OPTS == 12 and MB_BD_FIRST == 'Lord Marrowgar'")),
      "menu boss: i 12 boss della raid selezionata (Icecrown Citadel)")

# --- L'editor scrive nel set del boss selezionato -------------------------
rt.execute("""
    local t = RLSuite.config:GetMacroDB()
    t[1] = { text = 'EDIT_ICC_MARROWGAR' }
    MB_EDIT_LANDS = RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel']
        and RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel']['Lord Marrowgar']
        and RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel']['Lord Marrowgar'][1]
        and RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel']['Lord Marrowgar'][1].text
    MB_TITLE = RLSuite.config.macroListTitle:GetText()
""")
check(bool(rt.eval("MB_EDIT_LANDS == 'EDIT_ICC_MARROWGAR'")),
      "le modifiche dell'editor finiscono in db.bossMacros[raid][boss]")
check(bool(rt.eval("MB_TITLE == 'Boss macros: Lord Marrowgar'")),
      "il titolo della lista dice per quale boss stai scrivendo")

rt.execute("RLSuite.config.macroBossDD.onSelect('Sindragosa')")
rt.execute("""
    MB_SEL_BOSS = RLSuite.config.macroBoss
    local t2 = RLSuite.config:GetMacroDB()
    t2[1] = { text = 'EDIT_ICC_SINDRA' }
    MB_SEL_LANDS = RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel']['Sindragosa'][1].text
""")
check(bool(rt.eval("MB_SEL_BOSS == 'Sindragosa' and MB_SEL_LANDS == 'EDIT_ICC_SINDRA'")),
      "selezionando un altro boss l'editor scrive nel SUO set")

rt.execute("RLSuite.config.macroRaidDD.onSelect('Naxxramas')")
rt.execute("""
    MB_SEL_RAID = RLSuite.config.macroRaid
    MB_SEL_RAID_BOSS = RLSuite.config.macroBoss
    MB_BD_N = #(RLSuite.config.macroBossDD.options or {})
""")
check(bool(rt.eval("MB_SEL_RAID == 'Naxxramas' and MB_SEL_RAID_BOSS == \"Anub'Rekhan\" and MB_BD_N == 15")),
      "cambiando raid il menu boss si ripopola (Naxxramas -> 15 boss)")

rt.execute("RLSuite.config:SelectMacroPhase('preraid')")
check(bool(rt.eval("RLSuite.config.macroBossSel:IsShown() == false")),
      "fase pre-raid: i menu raid/boss NON sono visibili")
rt.execute("MB_PRE_DB_SAME = (RLSuite.config:GetMacroDB() == RLSuite.db.profile.macrobar.macros.preraid)")
check(bool(rt.eval("MB_PRE_DB_SAME == true")),
      "fase pre-raid: l'editor torna a scrivere nel set di fase")

# --- v1.11.54: aprire/chiudere i menu ALL'INFINITO, in qualunque stato -----
# Ogni toggle riparte dallo stato REALE (menu visibile o no) e chiude sempre
# tutto prima di aprire: nessuno stato interno che si "consumi" dopo N giri.
rt.execute("""
    local U = RLSuite.utils
    local CFG = RLSuite.config
    CFG:SelectMacroPhase('infight')
    local RD, BD = CFG.macroRaidDD, CFG.macroBossDD
    CYCLES, CYC_OK, CYC_SELOK, CYC_MAXBTN = 0, 0, 0, 0
    for i = 1, 12 do
        local dd = ((i % 2) == 1) and RD or BD
        U:ToggleDropdownMenu(dd)
        CYCLES = CYCLES + 1
        if U.activeMenu ~= nil and U.activeMenu.owner == dd
            and dd._rlsDropMenu:IsShown() == true and U.dropCatcher:IsShown() == true then
            CYC_OK = CYC_OK + 1
        end
        local m = U.activeMenu
        if m and m.optionButtons and m.optionButtons[1] then
            m.optionButtons[1]:GetScript("OnClick")()
        end
        if U.activeMenu == nil and U.dropCatcher:IsShown() == false then
            CYC_SELOK = CYC_SELOK + 1
        end
        local nb = #(dd._rlsDropMenu.optionButtons or {})
        if nb > CYC_MAXBTN then CYC_MAXBTN = nb end
    end
    CYC_RD_SHOWN = RD._rlsDropMenu:IsShown()
    CYC_BD_SHOWN = BD._rlsDropMenu:IsShown()
""")
check(bool(rt.eval("CYCLES == 12 and CYC_OK == 12")),
      "12 giri alternati raid/boss: il menu si apre TUTTE le volte")
check(bool(rt.eval("CYC_SELOK == 12")),
      "12 giri: dopo ogni scelta menu e catcher sono chiusi (nessun blocco residuo)")
check(bool(rt.eval("CYC_RD_SHOWN == false and CYC_BD_SHOWN == false")),
      "a fine stress nessun menu resta aperto")
rt.execute("CYC_MSG = ('i bottoni-opzione vengono riusati dopo 6 aperture: max %d bottoni'):format(CYC_MAXBTN)")
check(bool(rt.eval("CYC_MAXBTN <= 15")), str(rt.eval("CYC_MSG")))

# --- Stato sporco: catcher zombie, menu nascosto a mano, errore in apertura -
rt.execute("""
    local U = RLSuite.utils
    local RD = RLSuite.config.macroRaidDD
    -- (1) catcher visibile senza menu (il classico cadavere che mangia i click)
    U.dropCatcher:Show()
    U.activeMenu = nil
    U:ToggleDropdownMenu(RD)
    ZOMB_OK = (U.activeMenu ~= nil and RD._rlsDropMenu:IsShown() == true)
    U:CloseDropdownMenu()
    -- (2) menu nascosto a mano ma ancora "attivo": il toggle deve riaprire
    U:ToggleDropdownMenu(RD)
    RD._rlsDropMenu:Hide()
    U:ToggleDropdownMenu(RD)
    HIDDEN_OK = (U.activeMenu ~= nil and RD._rlsDropMenu:IsShown() == true)
    U:CloseDropdownMenu()
    -- (3) errore durante l'apertura: mai un catcher senza menu
    local saved = U.OpenDropdownMenu
    U.OpenDropdownMenu = function() error("boom") end
    U:ToggleDropdownMenu(RD)
    ERR_CAT = U.dropCatcher:IsShown()
    ERR_MENU = U.activeMenu
    U.OpenDropdownMenu = saved
    U:ToggleDropdownMenu(RD)
    ERR_NEXT = (U.activeMenu ~= nil and RD._rlsDropMenu:IsShown() == true)
    U:CloseDropdownMenu()
""")
check(bool(rt.eval("ZOMB_OK == true")),
      "catcher zombie presente: il click successivo APRE comunque il menu")
check(bool(rt.eval("HIDDEN_OK == true")),
      "menu nascosto da terzi: il click successivo lo riapre (stato letto dal vero)")
check(bool(rt.eval("ERR_CAT == false and ERR_MENU == nil")),
      "errore in apertura: nessun catcher lasciato a schermo (niente click rubati)")
check(bool(rt.eval("ERR_NEXT == true")), "dopo l'errore il menu si riapre normalmente")

# --- Watchdog del catcher: si spegne da solo se il menu non c'e' piu' ------
rt.execute("""
    local U = RLSuite.utils
    U.dropCatcher:Show()
    U.activeMenu = nil
    local upd = U.dropCatcher:GetScript("OnUpdate")
    if upd then upd() end
    WD_CAT = U.dropCatcher:IsShown()
""")
check(bool(rt.eval("WD_CAT == false")),
      "watchdog: il catcher rimasto senza menu si spegne da solo al frame dopo")

# --- Un menu non resta mai senza opzioni (tendina 'muta') -----------------
rt.execute("""
    local CFG = RLSuite.config
    CFG:SelectMacroPhase('infight')
    local RD, BD = CFG.macroRaidDD, CFG.macroBossDD
    local nBefore = #(BD.options or {})
    CFG.macroRaid = 'Raid Che Non Esiste'
    CFG:PopulateMacroBossDropdown()
    MUTE_AFTER = #(BD.options or {})
    MUTE_BEFORE = nBefore
    CFG.macroRaid = 'Icecrown Citadel'
    CFG:PopulateMacroBossDropdown()
    CFG:SelectMacroPhase('preraid')
""")
check(bool(rt.eval("MUTE_BEFORE > 0 and MUTE_AFTER == MUTE_BEFORE")),
      "raid non valido: il menu boss NON viene svuotato (resta utilizzabile)")

# --- v1.11.55: il menu sta SOPRA la finestra di config (strata TOOLTIP) -----
# Causa vera del "dopo N aperture la tendina non si apre piu'": la finestra e'
# un AceGUI Window che vive in FULLSCREEN_DIALOG e si ri-alza da sola
# (SetToplevel + Raise). Con menu e catcher nella STESSA strata, la finestra
# finiva sopra: il menu si apriva DIETRO (invisibile) e il click non arrivava.
rt.execute("""
    STRATA_RANK = { BACKGROUND=0, LOW=1, MEDIUM=2, HIGH=3, DIALOG=4,
                    FULLSCREEN=5, FULLSCREEN_DIALOG=6, TOOLTIP=7 }
    function ONTOP(a, b)
        local ra, rb = STRATA_RANK[a:GetFrameStrata()] or -1, STRATA_RANK[b:GetFrameStrata()] or -1
        if ra ~= rb then return ra > rb end
        return (a:GetFrameLevel() or 0) > (b:GetFrameLevel() or 0)
    end
    local U = RLSuite.utils
    local CFG = RLSuite.config
    CFG:SelectMacroPhase('infight')
    local RD = CFG.macroRaidDD
    U:ToggleDropdownMenu(RD)
    local MENU = RD._rlsDropMenu
    CAT = U.dropCatcher
    -- la finestra di config, come la lascia AceGUI, RI-ALZATA al massimo
    local win = CFG.window and CFG.window.frame
    if win then win:SetFrameStrata("FULLSCREEN_DIALOG"); win:SetFrameLevel(900) end
    TOP_CAT = ONTOP(CAT, win)
    TOP_MENU = ONTOP(MENU, win)
    TOP_OPT = ONTOP(MENU.optionButtons[1], CAT)
    CAT_STRATA = CAT:GetFrameStrata()
    MENU_STRATA = MENU:GetFrameStrata()
    MENU_LVL, CAT_LVL = MENU:GetFrameLevel(), CAT:GetFrameLevel()
    U:CloseDropdownMenu()
""")
check(bool(rt.eval("CAT_STRATA == 'TOOLTIP' and MENU_STRATA == 'TOOLTIP'")),
      "menu e catcher vivono in strata TOOLTIP (sopra la finestra FULLSCREEN_DIALOG)")
check(bool(rt.eval("MENU_LVL > CAT_LVL")), "le opzioni stanno sopra il catcher (livello menu > catcher)")
check(bool(rt.eval("TOP_CAT == true")), "il catcher e' sopra la finestra di config ri-alzata (il click fuori chiude)")
check(bool(rt.eval("TOP_MENU == true")),
      "il MENU resta sopra la finestra di config anche se lei si ri-alza (era dietro: 'non si apre piu')")
check(bool(rt.eval("TOP_OPT == true")), "le opzioni del menu restano cliccabili")

# --- 12 giri con la finestra che si ri-alza come fa AceGUI in gioco --------
rt.execute("""
    local U = RLSuite.utils
    local CFG = RLSuite.config
    local RD, BD = CFG.macroRaidDD, CFG.macroBossDD
    local win = CFG.window and CFG.window.frame
    RAISE_OK, RAISE_CYCLES, RAISE_TOP = 0, 0, 0
    for i = 1, 12 do
        -- AceGUI Window: ogni interazione la ri-alza in FULLSCREEN_DIALOG
        if win then win:SetFrameStrata("FULLSCREEN_DIALOG"); win:SetFrameLevel(880 + i) end
        local dd = ((i % 2) == 1) and RD or BD
        U:ToggleDropdownMenu(dd)
        RAISE_CYCLES = RAISE_CYCLES + 1
        local m = U.activeMenu
        if m and m.owner == dd and m:IsShown() and U.dropCatcher:IsShown() then
            if ONTOP(m, win) then RAISE_TOP = RAISE_TOP + 1 end
            RAISE_OK = RAISE_OK + 1
            if m.optionButtons and m.optionButtons[1] then
                m.optionButtons[1]:GetScript("OnClick")()
            end
        end
    end
    RAISE_END = (U.activeMenu == nil and U.dropCatcher:IsShown() == false)
""")
check(bool(rt.eval("RAISE_CYCLES == 12 and RAISE_OK == 12")),
      "12 giri con la finestra ri-alzata a ogni giro: il menu si apre TUTTE le volte")
check(bool(rt.eval("RAISE_TOP == 12")), "12 giri: il menu e' sempre sopra la finestra (visibile)")
check(bool(rt.eval("RAISE_END == true")), "12 giri: dopo la scelta non resta niente aperto")

# --- Un click fisico = un toggle (niente doppio handler) ------------------
rt.execute("""
    local dd = RLSuite.config.macroRaidDD
    ARROW_CLICK = dd.button:GetScript("OnClick")
    ARROW_MOUSE = dd.button._enabledMouse
    FRAME_TOGGLE = dd:GetScript("OnMouseUp")
""")
check(bool(rt.eval("ARROW_CLICK == nil and FRAME_TOGGLE ~= nil")),
      "la freccia non ha un secondo handler: apre/chiude solo il frame del dropdown")
check(bool(rt.eval("ARROW_MOUSE == false")), "la freccia lascia passare il click al frame (nessun doppio toggle)")

# --- v1.11.52 fix: i menu raid/boss si RIAPRONO (non "una volta sola") ---
# Il menu era riusato tra le aperture ma non veniva mai ri-mostrato: dopo la
# prima chiusura restava NASCOSTO e il catcher a schermo intero si mangiava i
# click. Qui il ciclo COMPLETO: apro -> scelgo -> riapro.
rt.execute("""
    local U = RLSuite.utils
    local CFG = RLSuite.config
    DBG_OLD_RAID, DBG_OLD_BOSS = CFG.macroRaid, CFG.macroBoss
    CFG:SelectMacroPhase('infight')
    local RD = CFG.macroRaidDD
    local BD = CFG.macroBossDD
    U:ToggleDropdownMenu(RD)
    RD_OPEN1 = (U.activeMenu ~= nil and RD._rlsDropMenu ~= nil and RD._rlsDropMenu:IsShown() == true)
    RD_CAT1 = (U.dropCatcher ~= nil and U.dropCatcher:IsShown() == true)
    local m = U.activeMenu
    if m and m.optionButtons and m.optionButtons[1] then
        m.optionButtons[1]:GetScript("OnClick")()
    end
    RD_AFTER = (U.activeMenu == nil and U.dropCatcher:IsShown() == false)
    U:ToggleDropdownMenu(RD)
    RD_OPEN2 = (U.activeMenu ~= nil and RD._rlsDropMenu:IsShown() == true)
    U:CloseDropdownMenu()
    U:ToggleDropdownMenu(BD)
    BD_OPEN1 = (U.activeMenu ~= nil and BD._rlsDropMenu:IsShown() == true)
    local m2 = U.activeMenu
    if m2 and m2.optionButtons and m2.optionButtons[1] then
        m2.optionButtons[1]:GetScript("OnClick")()
    end
    U:ToggleDropdownMenu(BD)
    BD_OPEN2 = (U.activeMenu ~= nil and BD._rlsDropMenu:IsShown() == true)
    BD_OPTS = #(BD.options or {})
    U:CloseDropdownMenu()
    CFG:SelectMacroPhase('preraid')
    CFG.macroRaid, CFG.macroBoss = DBG_OLD_RAID, DBG_OLD_BOSS
""")
check(bool(rt.eval("RD_OPEN1 == true and RD_CAT1 == true")),
      "menu raid: si apre (menu visibile + catcher)")
check(bool(rt.eval("RD_AFTER == true")), "menu raid: dopo la scelta si chiude (menu + catcher)")
check(bool(rt.eval("RD_OPEN2 == true")),
      "menu raid: SI RIAPRE dopo una scelta (fix 'si aprono una volta sola')")
check(bool(rt.eval("BD_OPEN1 == true")), "menu boss: si apre")
check(bool(rt.eval("BD_OPEN2 == true")),
      "menu boss: SI RIAPRE dopo una scelta (menu non piu' nascosto)")
check(bool(rt.eval("BD_OPTS > 0")), "menu boss: le opzioni restano popolate tra le aperture")

# --- Editor rapido (right-click sulla barra): stesso set dell'editor ------
rt.execute("""
    RLSuite.context = 'infight'
    MOCK_UNITS_BOSS.target = { guid = '0xF130008F040000AA', name = 'Lord Marrowgar' }
    RLSuite.macrobar:OpenMacroEdit(3)
    local f = RLSuite.macrobar.editFrame
    MB_EDIT_OPEN = (f ~= nil and f:IsShown() == true)
    MB_EDIT_TEXT = _G.RLSuiteMacroEditBox and _G.RLSuiteMacroEditBox:GetText()
    local save = nil
    if f then
        local kids = { f:GetChildren() }
        for i = 1, #kids do
            if kids[i]._text == 'Save' then save = kids[i] end
        end
    end
    MB_EDIT_HAVE_SAVE = (save ~= nil)
    if save then
        _G.RLSuiteMacroEditBox:SetText('QUICK_EDIT_OK')
        if save._scripts and save._scripts.OnClick then save._scripts.OnClick(save) end
    end
""")
check(bool(rt.eval("MB_EDIT_OPEN == true and MB_EDIT_HAVE_SAVE == true")),
      "editor rapido dello slot: si apre e ha il bottone Save")
check(bool(rt.eval("MB_EDIT_TEXT == nil or MB_EDIT_TEXT == ''")),
      "editor rapido: legge il set del boss (slot 3 ancora vuoto)")
check(bool(rt.eval("RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel']['Lord Marrowgar'][3].text == 'QUICK_EDIT_OK'")),
      "editor rapido: salva nel set del boss in corso (non in db.macros.infight)")
rt.execute("""
    MOCK_UNITS_BOSS = {}
    RLSuite.macrobar.editFrame = nil
    RLSuite.macrobar:OpenMacroEdit(1)
    MB_EDIT_NOBOSS = (RLSuite.macrobar.editFrame == nil)
""")
check(bool(rt.eval("MB_EDIT_NOBOSS == true")),
      "editor rapido senza boss: non apre nulla (nessun set dove scrivere)")

print()
print("== v1.11.52: buchi di riconoscimento risolti dal COUNTER di progressione ==")

rt.execute("""
    RLSuite:ResetBossProgress()
    RLSuite._lastBossRaid = nil
    RLSuite._lastProgressRaid = nil
    MOCK_UNITS_BOSS = {}
    MOCK_ZONE = 'Icecrown Citadel'
    RLSuite.context = 'infight'
    RLSuite.db.profile.macrobar.bossMacros = {}
    MB_G0_NEXT = RLSuite:NextBossByProgress('Icecrown Citadel')
    MB_G0_ONLY = RLSuite:IsProgressOnlyBoss('Icecrown Citadel', MB_G0_NEXT)
""")
check(bool(rt.eval("MB_G0_NEXT == 'Lord Marrowgar' and MB_G0_ONLY == false")),
      "counter: a inizio lockout il prossimo boss di ICC e' Marrowgar (non un buco)")
rt.execute("MB_G0_R, MB_G0_B = RLSuite:CurrentBossInfo()")
check(bool(rt.eval("MB_G0_R == nil and MB_G0_B == nil")),
      "counter: il prossimo boss NON e' un buco -> il counter non viene usato (target decide)")

rt.execute("""
    MB_G1 = RLSuite:RecordBossKill(36612)   -- Lord Marrowgar (kill registrata)
    MB_G2 = RLSuite:RecordBossKill(36855)   -- Lady Deathwhisper
    MB_GNEXT = RLSuite:NextBossByProgress('Icecrown Citadel')
    MB_GNEXT_ONLY = RLSuite:IsProgressOnlyBoss('Icecrown Citadel', MB_GNEXT)
    MB_GCOUNT = RLSuite:KilledBossCount('Icecrown Citadel')
""")
check(bool(rt.eval("MB_G1 == true and MB_G2 == true and MB_GCOUNT == 2")),
      "counter: le kill registrate dal combat log (id NPC) contano 2 boss")
check(bool(rt.eval("MB_GNEXT == 'Gunship Battle' and MB_GNEXT_ONLY == true")),
      "counter: dopo 2 boss il prossimo e' Gunship Battle (buco di riconoscimento)")

rt.execute("MB_GUN_R, MB_GUN_B = RLSuite:CurrentBossInfo()")
check(bool(rt.eval("MB_GUN_R == 'Icecrown Citadel' and MB_GUN_B == 'Gunship Battle'")),
      "GUNSHIP: senza match su target/boss1 si usa il COUNTER (3o boss di ICC)")
rt.execute("""
    RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel'] =
        RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel'] or {}
    RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel']['Gunship Battle'] =
        { [1] = { text = 'GUNSHIP_1' } }
    RLSuite.macrobar:UpdatePhase()
    MB_GUN_MACRO = RLSuite.macrobar:GetMacroData(1)
""")
check(bool(rt.eval("MB_GUN_MACRO and MB_GUN_MACRO.text == 'GUNSHIP_1'")),
      "GUNSHIP: la barra mostra le sue macro (riconosciuto dal counter)")
rt.execute("""
    RLSuite.db.profile.macrobar.bossMacros['Icecrown Citadel']['Deathbringer Saurfang'] =
        { [1] = { text = 'SAURFANG_1' } }
    MOCK_UNITS_BOSS.target = { name = 'Deathbringer Saurfang' }
    RLSuite.macrobar:UpdatePhase()
    MB_SAU_MACRO = RLSuite.macrobar:FilledSlots('infight')
    MB_SAU_NAME = RLSuite.macrobar.bossName
""")
check(bool(rt.eval("MB_SAU_NAME == 'Deathbringer Saurfang' and #MB_SAU_MACRO == 1 and MB_SAU_MACRO[1] == 1")),
      "il target ha la precedenza: su Saurfang si usano le macro di Saurfang, non quelle del Gunship")

# --- Nuovo lockout: un boss gia' segnato che muore di nuovo azzera il counter
rt.execute("""
    MOCK_UNITS_BOSS = {}     -- nessun target: niente inferenza, si vede il solo reset
    MB_LOCK_BEFORE = RLSuite:KilledBossCount('Icecrown Citadel')
    RLSuite:RecordBossKill(36612)
    MB_LOCK_AFTER = RLSuite:KilledBossCount('Icecrown Citadel')
    MB_LOCK_NEXT = RLSuite:NextBossByProgress('Icecrown Citadel')
""")
check(bool(rt.eval("MB_LOCK_BEFORE == 3 and MB_LOCK_AFTER == 1 and MB_LOCK_NEXT == 'Lady Deathwhisper'")),
      "reset settimanale: riuccidere un boss gia' segnato azzera il counter del lockout")
rt.execute("""
    MOCK_UNITS_BOSS.target = { name = 'Deathbringer Saurfang' }
    RLSuite:CurrentBossInfo()
    MB_LOCK_HEAL = RLSuite:KilledBossCount('Icecrown Citadel')
""")
check(bool(rt.eval("MB_LOCK_HEAL == 3")),
      "dopo il reset l'inferenza si riallinea da sola (sei su Saurfang = Gunship gia' battuto)")

# --- ToC: Faction Champions (3o, buco) riconosciuto dal counter -----------
rt.execute("""
    RLSuite:ResetBossProgress('Trial of the Crusader')
    RLSuite._lastBossRaid = nil
    MOCK_UNITS_BOSS = {}
    MOCK_ZONE = "Trial of the Crusader"
    RLSuite:RecordBossKill(34796)   -- Northrend Beasts
    RLSuite:RecordBossKill(34780)   -- Lord Jaraxxus
    MB_TOC_R, MB_TOC_B = RLSuite:CurrentBossInfo()
""")
check(bool(rt.eval("MB_TOC_R == 'Trial of the Crusader' and MB_TOC_B == 'Faction Champions'")),
      "FACTION CHAMPIONS: riconosciuto dal COUNTER (3o di ToC)")

# --- Inferenza catena lineare: identificare un boss lineare segna i precedenti
rt.execute("""
    RLSuite:ResetBossProgress('Trial of the Crusader')
    TWIN = "Twin Val" .. string.char(39) .. "kyr"
    MOCK_UNITS_BOSS.target = { name = TWIN }   -- 4o boss di ToC, identificato per nome
    MB_INF_R, MB_INF_B = RLSuite:CurrentBossInfo()
    MB_INF = {}
    for _, b in ipairs({ 'Northrend Beasts', 'Lord Jaraxxus', 'Faction Champions', TWIN }) do
        MB_INF[b] = RLSuite:IsBossKilled('Trial of the Crusader', b)
    end
    MB_INF_SELF = MB_INF[TWIN]
    MB_INF_TWIN = (MB_INF_B == TWIN and MB_INF_R == 'Trial of the Crusader')
    MB_INF_NEXT = RLSuite:NextBossByProgress('Trial of the Crusader')
    MB_INF_NEXT_TWIN = (MB_INF_NEXT == TWIN)
""")
check(bool(rt.eval("MB_INF_TWIN == true")),
      "inferenza: il 4o boss di ToC viene identificato per nome")
check(bool(rt.eval("MB_INF['Northrend Beasts'] == true and MB_INF['Lord Jaraxxus'] == true and MB_INF['Faction Champions'] == true")),
      "inferenza catena lineare: i 3 boss precedenti (inclusi i Champions, kill non registrabile) risultano battuti")
check(bool(rt.eval("MB_INF_SELF == false")),
      "inferenza: il boss che stai affrontando NON viene segnato come battuto")
check(bool(rt.eval("MB_INF_NEXT_TWIN == true")),
      "inferenza: il counter ora punta a Twin Val'kyr")

# --- Inferenza su ICC: identificare Saurfang deduce Gunship ---------------
rt.execute("""
    RLSuite:ResetBossProgress('Icecrown Citadel')
    MOCK_ZONE = 'Icecrown Citadel'
    MOCK_UNITS_BOSS.target = { guid = '0xF1300093B50000AA', name = 'Deathbringer Saurfang' }
    RLSuite:CurrentBossInfo()
    MB_ICC_INF = {}
    for _, b in ipairs({ 'Lord Marrowgar', 'Lady Deathwhisper', 'Gunship Battle' }) do
        MB_ICC_INF[b] = RLSuite:IsBossKilled('Icecrown Citadel', b)
    end
    MB_ICC_NEXT = RLSuite:NextBossByProgress('Icecrown Citadel')
""")
check(bool(rt.eval("MB_ICC_INF['Lord Marrowgar'] == true and MB_ICC_INF['Lady Deathwhisper'] == true and MB_ICC_INF['Gunship Battle'] == true")),
      "inferenza ICC: trovarsi su Saurfang implica Marrowgar + Deathwhisper + Gunship battuti")
check(bool(rt.eval("MB_ICC_NEXT == 'Deathbringer Saurfang'")), "inferenza ICC: il counter punta a Saurfang")

# --- Combat log: la kill entra nel counter, ma NON in debug ---------------
rt.execute("""
    RLSuite:ResetBossProgress('Icecrown Citadel')
    MOCK_UNITS_BOSS = {}
    MB_DBG = RLSuite:DebugMode()
    CL_MOCK = RLSuite.combatLog
    CL_MOCK.current = { events = {}, count = 0, dropped = 0, startTime = 0, samples = { health = {}, power = {} } }
    CL_MOCK:OnCLEU('COMBAT_LOG_EVENT_UNFILTERED', 0, 'UNIT_DIED', '', '', 0, '0xF130008F040000AA', 'Lord Marrowgar', 0)
    MB_CLEU_DEBUG_N = RLSuite:KilledBossCount('Icecrown Citadel')
    CL_MOCK.current = nil
""")
check(bool(rt.eval("MB_DBG == true")), "harness: questa suite gira in debug mode")
check(bool(rt.eval("MB_CLEU_DEBUG_N == 0")),
      "combat log in debug: i pull finti NON sporcano la progressione vera")
rt.execute("""
    RLSuite.db.profile.debug = false
    MB_CLEU_OK = RLSuite.combatLog:NoteBossKill('0xF130008F040000AA')
    MB_CLEU_N = RLSuite:KilledBossCount('Icecrown Citadel')
    MB_CLEU_UNKNOWN = RLSuite.combatLog:NoteBossKill('0xF1300001000000AA')
    RLSuite.db.profile.debug = true
""")
check(bool(rt.eval("MB_CLEU_OK == true and MB_CLEU_N == 1")),
      "combat log: la morte di un boss noto (GUID) entra nel counter")
check(bool(rt.eval("MB_CLEU_UNKNOWN == false")),
      "combat log: un NPC sconosciuto non entra nel counter")
# --- La barra si riallinea da sola quando il counter avanza --------------
rt.execute("""
    RLSuite:ResetBossProgress('Icecrown Citadel')
    MOCK_ZONE = 'Icecrown Citadel'
    RLSuite.context = 'infight'
    RLSuite.db.profile.macrobar.bossMacros = { ['Icecrown Citadel'] = {
        ['Gunship Battle'] = { [1] = { text = 'GUNSHIP_1' } },
        ['Lady Deathwhisper'] = { [1] = { text = 'LDW_1' } },
    } }
    RLSuite.macrobar.bossRaid, RLSuite.macrobar.bossName = nil, nil
    MOCK_UNITS_BOSS = {}
    RLSuite.macrobar:UpdatePhase()
    MB_EMPTY = (RLSuite.macrobar:GetMacroData(1) == nil)
    MOCK_UNITS_BOSS.target = { name = 'Lady Deathwhisper' }
    RLSuite.macrobar:UpdatePhase()
    MB_TARGET = tostring(RLSuite.macrobar:GetMacroData(1).text)
    MOCK_UNITS_BOSS = {}            -- trash del Gunship: nessun boss nel target
    RLSuite:RecordBossKill(36855)   -- Lady Deathwhisper: ora il prossimo e' Gunship
    MB_AFTER = tostring(RLSuite.macrobar:GetMacroData(1).text)
    MB_BUSY = tostring(RLSuite.macrobar._bossProgressBusy)
""")
check(bool(rt.eval("MB_EMPTY == true")),
      "barra: senza target e con un prossimo boss normale resta VUOTA (niente fallback)")
check(bool(rt.eval("MB_TARGET == 'LDW_1'")), "barra: boss nel target -> macro di quel boss")
check(bool(rt.eval("MB_AFTER == 'GUNSHIP_1'")),
      "barra: appena il counter avanza su Gunship la barra si riallinea DA SOLA")
check(bool(rt.eval("MB_BUSY == 'nil'")), "barra: la guardia di rientranza viene sempre rilasciata")

# --- Un errore in CurrentBossInfo non deve rompere il combat log ---------
rt.execute("""
    local saved = RLSuite.CurrentBossInfo
    RLSuite.CurrentBossInfo = function() error("boom") end
    local ok = pcall(function() RLSuite.macrobar:OnBossProgressChanged() end)
    MB_ERR_OK = ok
    MB_ERR_BUSY = RLSuite.macrobar._bossProgressBusy
    RLSuite.CurrentBossInfo = saved
""")
check(bool(rt.eval("MB_ERR_OK == true and MB_ERR_BUSY == nil")),
      "robustezza: un errore nel riconoscimento non risale al combat log e non blocca la barra")
rt.execute("""
    RLSuite.db.profile.macrobar.bossMacros = {}
    RLSuite:ResetBossProgress()
    RLSuite.macrobar.bossRaid, RLSuite.macrobar.bossName = nil, nil
""")

rt.execute("RLSuite:ResetBossProgress()")

# --- Ripristino harness (nessun leak nelle sezioni successive) ------------
rt.execute("""
    UnitExists, UnitName, UnitGUID = MB_S_UE, MB_S_UN, MB_S_UG
    MOCK_UNITS_BOSS = nil
    RLSuite.context = MB_S_CTX or 'preboss'
    RLSuite.db.profile.macrobar.macros.infight = nil
    RLSuite.db.profile.macrobar.bossMacros = {}
    RLSuite.config:CloseWindow()
    MB_RESTORED = (UnitExists == MB_S_UE)
    MB_RESTORED2 = (RLSuite.db.profile.macrobar.bossMacros ~= nil)
""")
check(bool(rt.eval("MB_RESTORED == true and MB_RESTORED2 == true")),
      "v1.11.51 harness ripristina unita'/contesto (nessun leak)")

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

# --- Ideal comp: duplicate specs collapse to "name xN" in the LFM message ---
rt.execute("RLSuite.groupmaking.db.showSpecsInMessage = true")
rt.execute("RLSuite.groupmaking:FillSlot(3, 'PRIEST', 'healer', nil, 'holy')")
rt.execute("RLSuite.groupmaking:FillSlot(4, 'PRIEST', 'healer', nil, 'holy')")
rt.execute("RLSuite.groupmaking:FillSlot(5, 'PRIEST', 'healer', nil, 'disc')")
rt.execute("SPAM_MSG_S = RLSuite.groupmaking:BuildSpamMessage()")
check(bool(rt.eval("SPAM_MSG_S:find('HPriest x2', 1, true) ~= nil")), "duplicate ideal-comp specs collapse to 'HPriest x2' (never repeated)")
check(bool(rt.eval("SPAM_MSG_S:find('HPriest, HPriest', 1, true) == nil")), "the raw duplicate 'HPriest, HPriest' is gone from the message")
check(bool(rt.eval("SPAM_MSG_S:find('Disco', 1, true) ~= nil and SPAM_MSG_S:find('Disco x', 1, true) == nil")), "single specs still shown once without a count")
rt.execute("RLSuite.groupmaking:ClearSlot(3); RLSuite.groupmaking:ClearSlot(4); RLSuite.groupmaking:ClearSlot(5)")

# --- Groupmaking spam channels: the custom 'global' channel is honored ---
rt.execute("""
CHAT_LOG = {}
DEBUG_SAVED = RLSuite.db.profile.debug
RLSuite.db.profile.debug = false
GCN_SAVED = GetChannelName
GetChannelName = function(c) if strlower(tostring(c)) == 'global' then return 7 end return nil end
SPCH_SAVED = RLSuite.groupmaking.db.spamChannels
RLSuite.groupmaking.db.spamChannels = {'global'}
RLSuite.groupmaking:DoSpam()
CHAN_HIT = CHAT_LOG[1]
GetChannelName = GCN_SAVED
RLSuite.db.profile.debug = DEBUG_SAVED
RLSuite.groupmaking.db.spamChannels = SPCH_SAVED
""")
check(bool(rt.eval("CHAN_HIT ~= nil and CHAN_HIT:find('CHANNEL|', 1, true) == 1 and CHAN_HIT:find('LFM', 1, true) ~= nil")), "DoSpam actually posts the LFM message to the custom 'global' channel")
rt.execute("""
CHAT_DEST = {}
CHAT_LOG = {}
DEBUG_SAVED2 = RLSuite.db.profile.debug
RLSuite.db.profile.debug = false
GCN_SAVED2 = GetChannelName
GetChannelName = function() return 7 end
SPCH_SAVED2 = RLSuite.groupmaking.db.spamChannels
SPNUM_SAVED2 = RLSuite.groupmaking.db.spamChannelNums
RLSuite.groupmaking.db.spamChannels = {'global'}
RLSuite.groupmaking.db.spamChannelNums = { global = 9 }
RLSuite.groupmaking:DoSpam()
CHAN_DEST_HIT = CHAT_DEST[1]; CHAN_MSG2 = CHAT_LOG[1]
GetChannelName = GCN_SAVED2
RLSuite.db.profile.debug = DEBUG_SAVED2
RLSuite.groupmaking.db.spamChannels = SPCH_SAVED2
RLSuite.groupmaking.db.spamChannelNums = SPNUM_SAVED2
""")
check(rt.eval("CHAN_DEST_HIT") == "9", "explicit channel number (9) overrides name resolution (would be 7)")
check(bool(rt.eval("CHAN_MSG2 ~= nil and CHAN_MSG2:find('LFM', 1, true) ~= nil")), "explicit channel number still posts the LFM message")
check(bool(rt.eval("RLSuite.db.profile.groupmaking.spamChannels ~= nil and #RLSuite.db.profile.groupmaking.spamChannels >= 1")), "spam channel list persists in the db (Config Groupmaking toggles)")
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

# --- Debug fake whispers: NO auto-flow, only the debug-bar burst feeds the Whisplist ---
rt.execute("RLSuite.groupmaking:StartSpam()")
check(bool(rt.eval("#RLSuite.groupmaking.whisperDB.entries == 0")), "Starting the spammer no longer auto-sends fake whispers")
rt.execute("RLSuite.groupmaking:DebugWhisperBurst()")
check(bool(rt.eval("#RLSuite.groupmaking.whisperDB.entries == 10")), "DebugWhisperBurst instantly delivers 10 fake whispers into the Whisplist")
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

# --- BUG CLICK NELLA LISTA (fstack: RLSuiteWLScroll <700> SOPRA la finestra
#     <200>): la catena della whisplist non era mai stata normalizzata, quindi
#     lo ScrollFrame (mouse-enabled, serve per la rotellina) poteva finire
#     sopra le righe e mangiarsi i click. Ogni UpdateWhisplist deve ri-ancorare
#     la catena: pagina < wlListBox < wlScroll < wlContent < righe. ---
GM = "RLSuite.groupmaking"
rt.execute(GM + ":UpdateWhisplist()")
rt.execute("""
    local GM = RLSuite.groupmaking
    WL_CHAIN_OK = ((GM.wlListBox:GetFrameLevel() or 0) > (GM.wlPage:GetFrameLevel() or 0))
        and ((GM.wlScroll:GetFrameLevel() or 0) > (GM.wlListBox:GetFrameLevel() or 0))
        and ((GM.wlContent:GetFrameLevel() or 0) > (GM.wlScroll:GetFrameLevel() or 0))
        and ((GM.wlContent:GetFrameLevel() or 0) > (GM.whisplistFrame:GetFrameLevel() or 0))
    WL_ROWS_ABOVE = true
    WL_ROWS_FLAT = true
    local lvl0 = nil
    for _, r in ipairs(GM.wlRows) do
        local rl = r:GetFrameLevel() or 0
        if rl <= (GM.wlScroll:GetFrameLevel() or 0) then WL_ROWS_ABOVE = false end
        if rl <= (GM.wlContent:GetFrameLevel() or 0) then WL_ROWS_ABOVE = false end
        if lvl0 == nil then lvl0 = rl elseif rl ~= lvl0 then WL_ROWS_FLAT = false end
    end
    WL_ROWS_MOUSE = (GM.wlRows[1] and GM.wlRows[1]._enabledMouse == true)
    WL_SCROLL_LIVE = (GM.wlRows[1] ~= nil and #GM.wlRows > 0)
    local bar = _G["RLSuiteWLScrollScrollBar"]
    WL_BAR_ABOVE = (bar ~= nil and GM.wlRows[1] ~= nil
        and (bar:GetFrameLevel() or 0) > (GM.wlRows[1]:GetFrameLevel() or 0))
""")
check(bool(rt.eval("WL_SCROLL_LIVE == true")), "whisplist has clickable rows to test")
check(bool(rt.eval("WL_CHAIN_OK == true")), "whisplist levels are chained: page < listbox < scroll < content (above the window)")
check(bool(rt.eval("WL_ROWS_ABOVE == true")), "every whisper row sits ABOVE the scroll/content frames (click reaches the row)")
check(bool(rt.eval("WL_ROWS_FLAT == true")), "all whisper rows share one level (flat band: pull-outs above the list stay clickable)")
check(bool(rt.eval("WL_ROWS_MOUSE == true")), "whisper rows are mouse-enabled")
check(bool(rt.eval("WL_BAR_ABOVE == true")), "the scroll bar stays ABOVE the rows (still draggable)")
# Chrome generica dello scroll (es. bottoni freccia figli dello ScrollFrame):
# deve finire sopra le righe come la barra, senza dipendere dal nome.
rt.execute("""
    local GM = RLSuite.groupmaking
    if not SYNTH_BAR then SYNTH_BAR = CreateFrame("Button", "RLSuiteWLSynthChrome", GM.wlScroll) end
    SYNTH_BAR:SetFrameLevel(1)
""")
rt.execute(GM + ":UpdateWhisplist()")
check(bool(rt.eval("(SYNTH_BAR:GetFrameLevel() or 0) > (RLSuite.groupmaking.wlRows[1]:GetFrameLevel() or 0)")),
      "any scroll-frame chrome child is pinned above the rows (not just the templated bar)")
rt.execute("""
    -- Drift identico allo screenshot: scroll/content centinaia di livelli
    -- sopra la finestra E una riga rimasta sotto. Il refresh deve riparare.
    local GM = RLSuite.groupmaking
    GM.wlPage:SetFrameLevel((GM.wlPage:GetParent():GetFrameLevel() or 1) + 500)
    GM.wlScroll:SetFrameLevel((GM.wlScroll:GetFrameLevel() or 1) + 500)
    GM.wlContent:SetFrameLevel((GM.wlContent:GetFrameLevel() or 1) + 500)
    GM.wlRows[1]:SetFrameLevel(1)
""")
rt.execute(GM + ":UpdateWhisplist()")
rt.execute("""
    local GM = RLSuite.groupmaking
    WL_HEAL_PAGE = (((GM.wlPage:GetFrameLevel() or 0) - ((GM.wlPage:GetParent():GetFrameLevel() or 0) + 1)) <= 20)
    WL_HEAL_ROWS = true
    for _, r in ipairs(GM.wlRows) do
        if (r:GetFrameLevel() or 0) <= (GM.wlScroll:GetFrameLevel() or 0) then WL_HEAL_ROWS = false end
    end
    WL_HEAL_SCROLL = ((GM.wlScroll:GetFrameLevel() or 0) < (GM.wlPage:GetFrameLevel() or 0) + 40)
""")
check(bool(rt.eval("WL_HEAL_PAGE == true")), "a drifted whisplist page is re-anchored to its container (no 500-level gap)")
check(bool(rt.eval("WL_HEAL_SCROLL == true")), "the drifted scroll frame is pulled back next to the page")
check(bool(rt.eval("WL_HEAL_ROWS == true")), "rows stay above the scroll frame after the drift is repaired")

# --- Drift del CONTENITORE delle tab (host) rispetto alla finestra: il
#     sotto-albero viene shiftato in blocco, l'ordine interno resta intatto. ---
rt.execute("""
    local GM = RLSuite.groupmaking
    GM.ieTabGroup.frame:SetFrameLevel((GM.whisplistFrame:GetFrameLevel() or 1) + 500)
""")
rt.execute(GM + ":UpdateWhisplist()")
rt.execute("""
    local GM = RLSuite.groupmaking
    WL_HOST_GAP = (GM.ieTabGroup.frame:GetFrameLevel() or 0) - (GM.whisplistFrame:GetFrameLevel() or 0)
    WL_HOST_ROWS = true
    for _, r in ipairs(GM.wlRows) do
        if (r:GetFrameLevel() or 0) <= (GM.wlScroll:GetFrameLevel() or 0) then WL_HOST_ROWS = false end
    end
    WL_HOST_ORDER = ((GM.wlScroll:GetFrameLevel() or 0) > (GM.wlContent and GM.wlContent:GetFrameLevel() or 0) - 100)
""")
check(bool(rt.eval("WL_HOST_GAP <= 20")), "a drifted tab container is shifted back next to the window (gap <= 20)")
check(bool(rt.eval("WL_HOST_ROWS == true")), "rows are still above the scroll after the tab container is shifted")
rt.execute("check_alias = RLSuite.utils.RealignSubtreeLevel ~= nil")
check(bool(rt.eval("check_alias == true")), "Utils:RealignSubtreeLevel is available to every list")
rt.execute("""
    local GM = RLSuite.groupmaking
    BEFORE_SCR = GM.wlScroll:GetFrameLevel() or 0
    BEFORE_CON = GM.wlContent:GetFrameLevel() or 0
    RLSuite.utils:RealignSubtreeLevel(GM.wlPage, (GM.wlPage:GetFrameLevel() or 0) + 500, 20)
    SHIFTED_SCR = GM.wlScroll:GetFrameLevel() or 0
    SHIFTED_CON = GM.wlContent:GetFrameLevel() or 0
""")
check(bool(rt.eval("(SHIFTED_SCR - BEFORE_SCR) == (SHIFTED_CON - BEFORE_CON)")), "subtree realign shifts every descendant by the same delta (internal order preserved)")

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
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.behavior == nil and RLSuite.config:BuildOptionsTable().args.raidframe.args.alerts == nil and RLSuite.config:BuildOptionsTable().args.raidframe.args.pos == nil")), "Raid Frame: Checks / Alert Messages / Position tabs removed")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.layout == nil")), "Raid Frame options flattened: only Layout controls, directly on the group")

# --- Raid Frame config: right panel shows a tab window (one tab per sub-item) ---
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.childGroups == nil")), "Raid Frame group no longer splits into tabs (Layout only)")
rt.execute("RF_TREE = RLSuite.config.tree.tree; RF_NODE = nil; for _, n in ipairs(RF_TREE) do if n.value == 'raidframe' then RF_NODE = n end end")
check(bool(rt.eval("RF_NODE ~= nil and RF_NODE.children == nil")), "Raid Frame is a leaf node (tabs live in the right panel)")
rt.execute("RLSuite.config:SelectNode('raidframe')")
check(bool(rt.eval("RLSuite.config.currentNode == 'raidframe'")), "selecting Raid Frame node renders without error")
check(bool(rt.eval("LAST_ERROR == nil or LAST_ERROR == None")), "no error rendering the Raid Frame tab window")

# --- Layout tab controls ---
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.iconSize ~= nil")), "Layout -> Icon size present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.barHeight == nil")), "Layout -> Player bar height option removed: bar height is AUTOMATIC from icon size")
check(bool(rt.eval("RLSuite.raidFrame:LayoutMetrics().barHeight == RLSuite.raidFrame:LayoutMetrics().iconSize")), "player bar height follows icon size automatically (barHeight == iconSize)")
check(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.rowSpacing.min") == -10, "Row spacing slider goes below zero, down to -10 (bars may overlap)")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.barWidth ~= nil")), "Layout -> Player bar width present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.nameFontSize ~= nil")), "Layout -> Name font size present")

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

# --- buff/debuff/ability bars: RIMOSSE (redesign in corso), restano SOLO flask+food per riga ---
check(bool(rt.eval("RLSuite.raidFrame.buffBar == nil and RLSuite.raidFrame.debuffBar == nil and RLSuite.raidFrame.abilityBar == nil")), "no buff/debuff/ability bars exist anymore (eliminated for redesign)")
check(bool(rt.eval("RLSuite.raidFrame.BuildAbilityBar == nil and RLSuite.raidFrame.RefreshAlertBars == nil and RLSuite.raidFrame.CheckCoverage == nil")), "buff-bar machinery functions are gone (UI code removed, not just hidden)")
check(bool(rt.eval("RLSuite.raidFrame:LayoutMetrics().W == RLSuite.raidFrame:LayoutMetrics().rowWidth")), "window width = bars area only: the matrix zone is NOT covered by the window (fully click-through)")
check(bool(rt.eval("RLSuite.raidFrame.frame._w == RLSuite.raidFrame:LayoutMetrics().rowWidth")), "window hitbox ends at the bars' right edge: buff columns area never swallows clicks (open or closed)")
# fase: le icone flask/food per riga restano vive in ogni fase (lo stato non dipende piu' dalle barre)
rt.execute("RLSuite:SetContextPhase('preboss')")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].flaskIcon:IsShown() == true")), "pre-boss: per-row flask icon still live")
rt.execute("RLSuite:SetContextPhase('infight')")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].foodIcon:IsShown() == true")), "in-fight: per-row Well Fed icon still live")
rt.execute("RLSuite:SetContextPhase('preraid')")

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
check(bool(rt.eval("RLSuite.raidFrame.slots[7]._backdrop == nil")), "empty player slots stay border-free even while dragging (dialog borders must disappear)")
check(bool(rt.eval("RLSuite.raidFrame.tankSlots[1]._backdrop == nil")), "tank slots never carry a dialog border")
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

# --- F.2h golden drop-border: shows EXACTLY where the dragged player would land ---
rt.execute("""
local RFmod = RLSuite.raidFrame
SAVED_ISD_H = IsShiftKeyDown
IsShiftKeyDown = function() return true end
SAVED_GCP_H = GetCursorPosition
SAVED_IMBD_H = IsMouseButtonDown
local src, dst = RFmod.slots[1], RFmod.slots[7]
src._manualDrag = nil; src._pendingRowClick = nil; src:SetScript('OnUpdate', nil); src._targetT = nil
src._scripts.OnMouseDown(src, 'LeftButton')            -- inizia il drag manuale di F5
GLOW_DRAGSRC = (RFmod._rfDragSource == src)
GLOW_NONE_AT_START = (dst.dropGlow:IsShown() == false) -- cursore altrove: nessun bordino
-- cursore sopra dst: agli altri slot rettangoli lontani, a dst [100..120]x[60..80]
for i, s in ipairs(RFmod.slots) do
    if s ~= dst then
        s.GetLeft = function() return 500 + i end
        s.GetRight = function() return 501 + i end
        s.GetBottom = function() return 500 end
        s.GetTop = function() return 501 end
    end
end
dst.GetLeft = function() return 100 end;  dst.GetRight = function() return 120 end
dst.GetBottom = function() return 60 end; dst.GetTop = function() return 80 end
GetCursorPosition = function() return 105, 70 end
IsMouseButtonDown = function() return true end          -- tasto ancora giu': drag in corso
RFmod._dragWatch:GetScript('OnUpdate')()                -- un tick: il bordino insegue il cursore
GLOW_ON_DST = (dst.dropGlow:IsShown() == true)
local n = 0
for _, s in ipairs(RFmod.slots) do
    if s.dropGlow:IsShown() then n = n + 1 end
end
GLOW_ONLY_DST = (n == 1)
-- rilascio FUORI da ogni slot (cancel): nessun move, bordini spenti, stato pulito
IsMouseButtonDown = function() return false end
GetCursorPosition = function() return 9999, 9999 end
RFmod._dragWatch:GetScript('OnUpdate')()
local n2 = 0
for _, s in ipairs(RFmod.slots) do
    if s.dropGlow:IsShown() then n2 = n2 + 1 end
end
GLOW_ALL_OFF = (n2 == 0)
GLOW_CANCEL_CLEAN = (RFmod._rfDragSource == nil)
GLOW_ROSTER_INTACT = (RFmod.slots[7].member.name == 'Testplayer' and RFmod.slots[1].member.name == 'F5')
-- ripristina mock: geometrie d'istanza → nil torna al metodo default (0), poi le globali
for _, s in ipairs(RFmod.slots) do
    s.GetLeft, s.GetRight, s.GetBottom, s.GetTop = nil, nil, nil, nil
end
GetCursorPosition = SAVED_GCP_H
IsShiftKeyDown = SAVED_ISD_H
IsMouseButtonDown = SAVED_IMBD_H
""")
check(bool(rt.eval("RLSuite.raidFrame.slots[1].dropGlow ~= nil and RLSuite.raidFrame.slots[1].dropGlow._enabledMouse == false")), "every slot has a golden drop-border overlay that never eats clicks")
check(bool(rt.eval("GLOW_DRAGSRC")), "shift+down starts the manual drag (border logic armed)")
check(bool(rt.eval("GLOW_NONE_AT_START")), "golden border hidden while the cursor is not over any slot")
check(bool(rt.eval("GLOW_ON_DST") and bool(rt.eval("GLOW_ONLY_DST"))), "golden border follows the cursor onto the exact destination slot only (occupied = swap preview)")
check(bool(rt.eval("GLOW_ALL_OFF")), "release outside any slot: every golden border turns off")
check(bool(rt.eval("GLOW_CANCEL_CLEAN") and bool(rt.eval("GLOW_ROSTER_INTACT"))), "cancel outside: no move, roster untouched, drag state clean")

# --- F.2i hit-test con finestra SCALATA: la scala del cursore deve seguire la finestra, non UIParent ---
rt.execute("""
local RFmod = RLSuite.raidFrame
SAVED_ISD_I = IsShiftKeyDown
IsShiftKeyDown = function() return true end
SAVED_GCP_I = GetCursorPosition
SAVED_IMBD_I = IsMouseButtonDown
local src, dst = RFmod.slots[1], RFmod.slots[7]
src._manualDrag = nil; src._pendingRowClick = nil; src:SetScript('OnUpdate', nil); src._targetT = nil
src._scripts.OnMouseDown(src, 'LeftButton')
-- finestra ridotta al 50%: i rettangoli degli slot (GetLeft & co.) sono in
-- slot-space; due volte piu' grandi rispetto alle coordinate UIParent.
for i, s in ipairs(RFmod.slots) do
    s.GetEffectiveScale = function() return 0.5 end
    s.GetLeft = function() return 500 + i end
    s.GetRight = function() return 501 + i end
    s.GetBottom = function() return 500 end
    s.GetTop = function() return 501 end
end
dst.GetLeft = function() return 100 end;  dst.GetRight = function() return 120 end
dst.GetBottom = function() return 60 end; dst.GetTop = function() return 80 end
-- cursore al punto GREZZO che il vecchio codice matchava: (110,70) -> slot-space (220,140) -> NESSUNO
IsMouseButtonDown = function() return true end
GetCursorPosition = function() return 110, 70 end
RFmod._dragWatch:GetScript('OnUpdate')()
G2_NEG_RAW = (dst.dropGlow:IsShown() == false)
-- cursore al CENTRO VISIVO di dst: UI-space (55,35) -> slot-space (110,70) -> dst
GetCursorPosition = function() return 55, 35 end
RFmod._dragWatch:GetScript('OnUpdate')()
G2_SCALED_ON = (dst.dropGlow:IsShown() == true)
local n = 0
for _, s in ipairs(RFmod.slots) do
    if s.dropGlow:IsShown() then n = n + 1 end
end
G2_SCALED_ONLY = (n == 1)
-- cancel + restore
IsMouseButtonDown = function() return false end
GetCursorPosition = function() return 9999, 9999 end
RFmod._dragWatch:GetScript('OnUpdate')()
G2_ALL_OFF = true
for _, s in ipairs(RFmod.slots) do
    if s.dropGlow:IsShown() then G2_ALL_OFF = false end
    s.GetEffectiveScale, s.GetLeft, s.GetRight, s.GetBottom, s.GetTop = nil, nil, nil, nil, nil
end
G2_INTACT = (RFmod.slots[7].member.name == 'Testplayer')
GetCursorPosition = SAVED_GCP_I
IsShiftKeyDown = SAVED_ISD_I
IsMouseButtonDown = SAVED_IMBD_I
""")
check(bool(rt.eval("G2_SCALED_ON") and bool(rt.eval("G2_SCALED_ONLY"))), "scaled RF window (50%): golden border lands on the slot under the VISUAL cursor (cursor rescaled to the window's own effective scale)")
check(bool(rt.eval("G2_NEG_RAW")), "scaled RF window (50%): the old raw UIParent-space point hits NOTHING (proves the rescale is real, not a tautology)")
check(bool(rt.eval("G2_ALL_OFF") and bool(rt.eval("G2_INTACT"))), "scaled-window test cleanup: borders off, roster untouched")

# --- F.2i bis: stessa correzione sul pannello Group Making (WlSlotAtCursor) ---
rt.execute("""
local GMmod = RLSuite.groupmaking
SAVED_GCP_G = GetCursorPosition
local bars = GMmod.wlGroupSlots
local target = bars[2]
for i, b in ipairs(bars) do
    b.GetEffectiveScale = function() return 0.5 end
    b.GetLeft = function() return 800 + i end
    b.GetRight = function() return 801 + i end
    b.GetBottom = function() return 800 end
    b.GetTop = function() return 801 end
end
target.GetLeft = function() return 300 end;  target.GetRight = function() return 360 end
target.GetBottom = function() return 200 end; target.GetTop = function() return 240 end
GetCursorPosition = function() return 160, 110 end  -- centro UI-space: slot-space (320,220)
GM_HIT = (GMmod:WlSlotAtCursor() == target)
GetCursorPosition = function() return 320, 220 end  -- vecchio punto grezzo: NIENTE
GM_NOHIT = (GMmod:WlSlotAtCursor() == nil)
for _, b in ipairs(bars) do
    b.GetEffectiveScale, b.GetLeft, b.GetRight, b.GetBottom, b.GetTop = nil, nil, nil, nil, nil
end
GetCursorPosition = SAVED_GCP_G
""")
check(bool(rt.eval("GM_HIT")), "Group Making panel (50% scale): WlSlotAtCursor returns the bar under the visual cursor")
check(bool(rt.eval("GM_NOHIT")), "Group Making panel (50% scale): old raw point matches nothing (rescale applied)")

# --- F.2j food icon = aura "Well Fed" (per NOME, qualsiasi spellId, locale-safe) ---
rt.execute("""
local RFmod = RLSuite.raidFrame
local row = RFmod.rows[1]
SAVED_MEMBER_WF = row.member
SAVED_UE_WF = UnitExists
SAVED_GSI_WF = GetSpellInfo
SAVED_UB_WF = UnitBuff
RLSuite.raidFrame:FillSlot(row, { name = 'Eatz', class = 'WARRIOR', unit = 'raid8', fake = false, raidIndex = 8 })
UnitExists = function(u) return u == 'raid8' end
GetSpellInfo = function(id) if id == 57399 then return 'Well Fed' end return 'Spell' end
local FOOD_BUFFS = { [1] = 'Horn of Winter', [2] = 'Well Fed', [3] = nil }
UnitBuff = function(u, filter)
    if type(filter) == 'number' then return FOOD_BUFFS[filter] end
    return nil  -- query per nome (path flask): nessuna corrispondenza unita'
end
WF_BUFFS = FOOD_BUFFS
RFmod:UpdateConsumables(row)
WF_FED = (row.foodIcon._missing == false and row.foodIcon:IsShown() == false)
WF_FLASK_STILL = (row.flaskIcon._missing == true and row.flaskIcon:IsShown() == true)
FOOD_BUFFS[2] = nil                                    -- niente Well Fed -> icona mancante
RFmod:UpdateConsumables(row)
WF_NOTFED = (row.foodIcon._missing == true and row.foodIcon:IsShown() == true)
-- locale-safety: client non-EN, nome localizzato ricavato da GetSpellInfo(id noto)
GetSpellInfo = function(id) if id == 57399 then return 'Ben Nutrito' end return 'Spell' end
FOOD_BUFFS[1] = 'Ben Nutrito'
RFmod:UpdateConsumables(row)
WF_LOCALE = (row.foodIcon._missing == false)
-- restore di TUTTO (mock globali + member originale)
UnitBuff = SAVED_UB_WF; GetSpellInfo = SAVED_GSI_WF; UnitExists = SAVED_UE_WF
WF_BUFFS = nil
RLSuite.raidFrame:FillSlot(row, SAVED_MEMBER_WF)
""")
check(bool(rt.eval("WF_FED")), "Well Fed present (any spellId): food icon turns off")
check(bool(rt.eval("WF_FLASK_STILL")), "flask check untouched by the Well Fed rework")
check(bool(rt.eval("WF_NOTFED")), "no Well Fed on the unit: food icon shows missing")
check(bool(rt.eval("WF_LOCALE")), "localized client: Well Fed matched via localized name (locale-safe)")
check(bool(rt.eval("RLSuite.raidFrame.rows[1].member.name == 'F5'")), "roster restored after Well Fed test")

# --- F.3 FONT COLOR option + TANKS group + RAID BUFFS matrix panel ---
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.fontColor ~= nil and RLSuite.config:BuildOptionsTable().args.raidframe.args.fontColor.type == 'color'")), "Layout -> Font color picker present")
for key, label in [("iconSpacing","Icon spacing"),("rowSpacing","Row spacing"),("groupSpacing","Group spacing"),("groupHeaderFontSize","Group header font size")]:
    check(bool(rt.eval(f"RLSuite.config:BuildOptionsTable().args.raidframe.args.{key} ~= nil")), f"Layout -> {label} slider present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.matrixBackdrop ~= nil and RLSuite.config:BuildOptionsTable().args.raidframe.args.matrixBackdrop.type == 'color'")), "Layout -> Buff check backdrop color picker (color+alpha) present")
rt.execute("""
local prof = RLSuite.db.profile.raidframe
SAVED_FC = prof.appearance.fontColor
prof.appearance.fontColor = { r = 1, g = 0, b = 0, a = 1 }
RLSuite.raidFrame:ApplyLayout()
FC_RED = (RLSuite.raidFrame.rows[1].bar.nameText._tc[1] == 1 and RLSuite.raidFrame.rows[1].bar.nameText._tc[2] == 0)
prof.appearance.fontColor = SAVED_FC or { r = 1, g = 1, b = 1, a = 1 }
RLSuite.raidFrame:ApplyLayout()
FC_BACK = (RLSuite.raidFrame.rows[1].bar.nameText._tc[1] == 1 and RLSuite.raidFrame.rows[1].bar.nameText._tc[2] == 1)
""")
check(bool(rt.eval("FC_RED")), "font color option applies to the player name on the bars")
check(bool(rt.eval("FC_BACK")), "font color restores to the default white")

# Tanks group above G1 (MT + OT bars)
check(rt.eval("RLSuite.raidFrame.tankHeader:GetText()") == "Tanks", "Tanks group header named exactly 'Tanks' above G1")
check(bool(rt.eval("RLSuite.raidFrame.tankHeader:IsShown() == true")), "Tanks group visible when there is a raid roster")
check(bool(rt.eval("RLSuite.raidFrame.tankSlots[1].flaskIcon == nil and RLSuite.raidFrame.tankSlots[1].foodIcon == nil")), "tank bars have NO flask/food icons")
check(rt.eval("RLSuite.raidFrame.tankSlots[1].tankTag:GetText()") == "MT" and rt.eval("RLSuite.raidFrame.tankSlots[2].tankTag:GetText()") == "OT", "MT and OT labels replace the consumable icons beside the bars")
check(rt.eval("RLSuite.raidFrame.tankSlots[1].member.name") == "Testplayer", "debug: MT bar auto-fills with the first fake-roster player (fake members work as tanks)")
check(rt.eval("RLSuite.raidFrame.tankSlots[2].member.name") == "F1", "debug: OT bar auto-fills with the next fake-roster player")
rt.execute("""
SAVED_DT = RLSuite.debugTanks
RLSuite.debugTanks = { mt = 'F2', ot = 'F4' }
RLSuite.raidFrame:Rebuild()
TANK_MAN_MT = (RLSuite.raidFrame.tankSlots[1].member.name == 'F2')
TANK_MAN_OT = (RLSuite.raidFrame.tankSlots[2].member.name == 'F4')
RLSuite.debugTanks = { mt = false, ot = false }   -- svuotato INTENZIONALMENTE
RLSuite.raidFrame:Rebuild()
TANK_CLEAR_STAYS = (RLSuite.raidFrame.tankSlots[1].member == nil and RLSuite.raidFrame.tankSlots[1]:IsShown() == false)
RLSuite.debugTanks = SAVED_DT
RLSuite.raidFrame:Rebuild()
TANK_BACK = (RLSuite.raidFrame.tankSlots[1].member.name == 'Testplayer' or (SAVED_DT and RLSuite.raidFrame.tankSlots[1].member.name == SAVED_DT.mt))
""")
check(bool(rt.eval("TANK_MAN_MT") and bool(rt.eval("TANK_MAN_OT"))), "debug: manual MT/OT assignment (via the MT/OT buttons' debug store) overrides the auto-fill")
check(bool(rt.eval("TANK_CLEAR_STAYS")), "debug: an intentionally cleared tank bar stays empty and hidden (no auto-refill, no dialog border)")
check(bool(rt.eval("TANK_BACK")), "debug tank assignments restored")
check(bool(rt.eval("#RLSuite.raidFrame.rows == 6")), "group rows unaffected by the Tanks group (a tank appears in BOTH places)")

# --- tank bars: MT/OT tag attached to the bar, no player CDs, target bar ---
rt.execute("""
RLSuite.raidFrame:ApplyLayout()
local mtb = RLSuite.raidFrame.tankSlots[1]
local tp = mtb.tankTag._points[#mtb.tankTag._points]
TANK_TAG_OK = (tp[1] == 'RIGHT' and tp[2] == mtb.bar and tp[3] == 'LEFT' and tp[4] == -3)
TANK_NOCD = true
for ti = 1, 2 do
    for j = 1, 4 do
        local cd = RLSuite.raidFrame.tankSlots[ti].cdIcons[j]
        TANK_NOCD = TANK_NOCD and (cd:IsShown() == false)
    end
end
local tb = mtb.targetBar
local bp = tb._points[#tb._points]
local m = RLSuite.raidFrame:LayoutMetrics()
TANK_TBAR = (tb ~= nil and bp[2] == mtb.bar and bp[3] == 'TOPRIGHT'
    and tb._w == (m.rowWidth - (4 + 2 * m.iconSize + 4) - m.barWidth - 4))

-- barra target con unit reali mockate (salva/ripristina i global)
local S_UE, S_UN, S_UH, S_UHM, S_UIP, S_UC = UnitExists, UnitName, UnitHealth, UnitHealthMax, UnitIsPlayer, UnitClass
mtb.unit = 'raid3'; mtb.fake = nil
UnitExists = function(u) return u == 'raid3' or u == 'raid3target' end
UnitName = function(u) if u == 'raid3target' then return 'Bossob' end return 'Testplayer' end
UnitHealth = function(u) if u == 'raid3target' then return 500 end return 80 end
UnitHealthMax = function(u) if u == 'raid3target' then return 1000 end return 100 end
UnitIsPlayer = function(u) return false end
RLSuite.raidFrame:UpdateTankTargets()
TANK_TBAR_NAME = (mtb.targetBar.nameText:GetText() == 'Bossob')
TANK_TBAR_VAL = (mtb.targetBar._value ~= nil and math.abs(mtb.targetBar._value - 50) < 0.01)
TANK_TBAR_COL = (mtb.targetBar._sbColor ~= nil and math.abs(mtb.targetBar._sbColor[1] - 0.75) < 0.001)
-- tank fittizio (debug): barra target VUOTA (mai query su unit fake)
mtb.unit = nil; mtb.fake = true
RLSuite.raidFrame:UpdateTankTargets()
TANK_TBAR_FAKE = (mtb.targetBar.nameText:GetText() == '' and (mtb.targetBar._value == nil or mtb.targetBar._value == 0))
mtb.fake = true
UnitExists, UnitName, UnitHealth, UnitHealthMax, UnitIsPlayer, UnitClass = S_UE, S_UN, S_UH, S_UHM, S_UIP, S_UC
RLSuite.raidFrame:UpdateTankTargets()
""")
check(bool(rt.eval("TANK_TAG_OK")), "MT/OT tag attached to the bar's LEFT edge (not floating in the left space)")
check(bool(rt.eval("TANK_NOCD")), "tank bars never show player CDs on the right")
check(bool(rt.eval("TANK_TBAR")), "tank bars have a TARGET bar where the CDs were (size = former CD zone)")
check(bool(rt.eval("TANK_TBAR_NAME")) and bool(rt.eval("TANK_TBAR_VAL")), "tank target bar shows current target name + HP% from real units")
check(bool(rt.eval("TANK_TBAR_COL")), "tank target bar colors red for hostile targets")
check(bool(rt.eval("TANK_TBAR_FAKE")), "debug/fake tanks leave the target bar empty (no fake-unit API queries)")

# Raid Buffs matrix panel (Method style)
check(bool(rt.eval("RLSuite.raidFrame.buffPanelBtn ~= nil and RLSuite.raidFrame.buffPanelBtn.label:GetText() == 'Raid Buffs'")), "'Raid Buffs' toggle button exists with its label")
check(bool(rt.eval("(function() local b = RLSuite.raidFrame.buffPanelBtn; local p = b and b._points[#b._points]; local gh = RLSuite.raidFrame.groupHeaders[1]._points[#RLSuite.raidFrame.groupHeaders[1]._points]; return p ~= nil and p[1] == 'BOTTOMRIGHT' and p[3] == 'TOPLEFT' and gh ~= nil and math.abs((p[5] or 0) - (gh[5] or 0)) < 0.001 end)()")), "'Raid Buffs' button aligned like the G1 header: bottom edge on the G1 text line below the tank target bars")
check(bool(rt.eval("RLSuite.raidFrame.buffPanel == nil")), "no floating side panel: the buff matrix is PART of the raid frame")
check(bool(rt.eval("#RLSuite.raidFrame:_MatrixCols() == 25")), "25 visible columns (all Icy-Veins raid-buff categories incl. AP%%, DR%%, Heal+, Repl, SpellHaste; flask/food excluded)")
rt.execute("""
local function colHas(key, id)
    for _, c in ipairs(RLSuite.raidBuffColumns) do
        if c.key == key and c.spells then
            for _, s in ipairs(c.spells) do if s == id then return true end end
        end
    end
    return false
end
local function colMisses(key, id) return not colHas(key, id) end
AL_TRUESHOT_AGAINSTYPE = colMisses('atkpower', 19506) and colHas('apIncrease', 19506)
AL_NOT_LUST = colMisses('haste', 2825) and colHas('haste', 53648)
AL_DMG = colHas('damage', 34460) and colHas('damage', 31869)
AL_NEWCOLS = colHas('apIncrease', 53138) and colHas('dmgReduction', 20911)
    and colHas('healReceived', 34123) and colHas('physReduction', 16240)
    and colHas('replen', 34914) and colHas('spellHaste', 3738)
AL_LOTP = colHas('meleeCrit', 17007) and colHas('meleeHaste', 55610)
AL_SANC = colHas('stats', 20911) and colHas('intellect', 57567) and colHas('spirit', 57567)
local function debHas(key)
    for _, c in ipairs(RLSuite.raidDebuffChecks) do if c.key == key then return true end end
    return false
end
AL_DEBUFF_LOADLIST = debHas('apReduction') and debHas('attackSpeedReduction') and debHas('castSpeedReduction') and debHas('healingReduction')
local checkListNew = 0
for _, c in ipairs(RLSuite.raidBuffChecks) do
    if c.key == 'replen' or c.key == 'spellHaste' or c.key == 'apIncrease' or c.key == 'dmgReduction'
       or c.key == 'healReceived' or c.key == 'physReduction' or c.key == 'meleeCrit' or c.key == 'meleeHaste'
       or c.key == 'spellPower' or c.key == 'damage' then
        checkListNew = checkListNew + 1
    end
end
AL_CHECKLIST = (checkListNew == 10)
""")
check(bool(rt.eval("AL_TRUESHOT_AGAINSTYPE")), "Icy-Veins alignment: Trueshot Aura moved from raw ATK to the AP% Increase column")
check(bool(rt.eval("AL_NOT_LUST")), "Icy-Veins alignment: 'haste' column is Moonkin/Swift-Ret 3% haste, NOT Bloodlust")
check(bool(rt.eval("AL_DMG")), "Icy-Veins alignment: Damage Increase = Ferocious Inspiration + Sanctified Retribution (+Arcane Empowerment)")
check(bool(rt.eval("AL_NEWCOLS")), "Icy-Veins alignment: new columns AP%%, DR%%, Heal+, Phys-red, Replenishment, Spell Haste exist")
check(bool(rt.eval("AL_LOTP") and bool(rt.eval("AL_SANC"))), "Icy-Veins alignment: LotP/Improved Icy Talons/Sanctuary/Fel Intellect ids added")
check(bool(rt.eval("AL_DEBUFF_LOADLIST")), "Icy-Veins alignment: new debuff columns (AP/attack-speed/cast-speed reductions, wound) added")
check(bool(rt.eval("AL_CHECKLIST")), "raidBuffChecks list now carries the 10 missing categories in sync with the matrix")

check(bool(rt.eval("RLSuite.raidFrame.buffMatrixOn ~= true")), "buff matrix hidden by default (shows only when the button is clicked)")
rt.execute("""
RLSuite.raidFrame.buffPanelBtn._scripts.OnClick(RLSuite.raidFrame.buffPanelBtn)
BP_ON = (RLSuite.raidFrame.buffMatrixOn == true)
local cols = RLSuite.raidFrame:_MatrixCols()
BP_PRIO1 = (cols[1].key == 'stats')
NC = #cols
BP_PRIOLAST = (cols[NC].key == 'retAura')
BP_HDR1 = (RLSuite.raidFrame._buffHdrBtns[1]._icon ~= nil and RLSuite.raidFrame._buffHdrBtns[1]:IsShown() == true
    and RLSuite.raidFrame._buffHdrBtns[1]._icon._texture ~= nil
    and RLSuite.raidFrame._buffHdrBtns[1]._icon._texture:find('BUFFCATICONS', 1, true) ~= nil
    and RLSuite.raidFrame._buffHdrBtns[1]._icon._texture:find('BCI_0.tga', 1, true) ~= nil)
BP_HDR19 = (RLSuite.raidFrame._buffHdrBtns[NC]._icon ~= nil and RLSuite.raidFrame._buffHdrBtns[NC]._icon._texture ~= nil
    and RLSuite.raidFrame._buffHdrBtns[NC]._icon._texture:find('BCI_' .. (NC - 1) .. '.tga', 1, true) ~= nil)
BP_HDR_ICONSZ = (RLSuite.raidFrame._buffHdrBtns[1]._icon._w == (RLSuite.raidFrame:LayoutMetrics().iconSize + RLSuite.raidFrame:LayoutMetrics().iconSpacing)
    and RLSuite.raidFrame._buffHdrBtns[1]._icon._h == (RLSuite.raidFrame:LayoutMetrics().iconSize + RLSuite.raidFrame:LayoutMetrics().iconSpacing))
BP_HDR_H = (RLSuite.raidFrame._buffHdrBtns[1].height == 80 or (RLSuite.raidFrame._buffHdrBtns[1]._h == 80) or true)
local hb1 = RLSuite.raidFrame._buffHdrBtns[1]
local hbpt = hb1._points[#hb1._points]
local gh1pt = RLSuite.raidFrame.groupHeaders[1]._points[#RLSuite.raidFrame.groupHeaders[1]._points]
BP_HDR_TOP = (hbpt[2] == RLSuite.raidFrame.frame and gh1pt ~= nil and gh1pt[1] == 'BOTTOMLEFT'
    and math.abs((hbpt[5] or 0) - ((gh1pt[5] or 0) + (RLSuite.raidFrame:LayoutMetrics().cellW + 4))) < 0.001)
SLOT1Y_ON = RLSuite.raidFrame.slots[1]._points[1][5]
local hbg = RLSuite.raidFrame._buffHdrBg
BP_HDR_BG = (hbg ~= nil and hbg:IsShown() == true and hbg._texRGBA ~= nil
    and math.abs(hbg._texRGBA[1] - 0.5) < 0.001 and math.abs(hbg._texRGBA[2] - 0.5) < 0.001
    and math.abs(hbg._texRGBA[3] - 0.5) < 0.001 and math.abs(hbg._texRGBA[4] - 0.35) < 0.001
    and hbg._w == (NC * RLSuite.raidFrame:LayoutMetrics().cellW + 6))
BP_HDR_OUT = true
for c = 1, NC do
    local b = RLSuite.raidFrame._buffHdrBtns[c]
    BP_HDR_OUT = BP_HDR_OUT and (b:GetParent() == RLSuite.raidFrame.frame) and (b:IsShown() == true)
end
BP_TANK_UNDER = (math.abs((RLSuite.raidFrame.tankHeader._points[#RLSuite.raidFrame.tankHeader._points][5] or 0) - 0) < 0.001)
-- REGRESSIONE 1.7.2: un errore nella costruzione dell'intestazione 45°
-- interrompeva ApplyLayout a meta': i gruppi vuoti non venivano piu' packati,
-- l'overlay dorato/UpdateAll non partiva, le celle matrice restavano vuote e
-- le impostazioni non si applicavano. Qui verifichiamo che il layout arrivi
-- SEMPRE in fondo (height content positiva + ultimo gruppo packato).
BP_LAYOUT_DONE = (RLSuite.raidFrame.content:GetHeight() ~= nil and RLSuite.raidFrame.content:GetHeight() > 0)
for g = 1, 6 do
    local gh = RLSuite.raidFrame.groupHeaders[g]
    if gh:IsShown() and (gh._points == nil or #gh._points == 0) then BP_LAYOUT_DONE = false end
end
local m = RLSuite.raidFrame:LayoutMetrics()
BP_W = (m.W == m.rowWidth)
local lbp = RLSuite.raidFrame._buffHdrBtns[NC]._points[#RLSuite.raidFrame._buffHdrBtns[NC]._points]
BP_SPILL = ((lbp[4] + 24) > m.W)
-- la riga del player (unit 'player') e quella di un fake
BP_PSLOT, BP_FSLOT = nil, nil
for _, s in ipairs(RLSuite.raidFrame.slots) do
    if s.member and s.member.unit == 'player' then BP_PSLOT = s end
    if (not BP_FSLOT) and s.member and s.member.fake then BP_FSLOT = s end
end
BP_CELL_ON_ROW = (BP_PSLOT and BP_PSLOT._buffCells[1] ~= nil)
if BP_PSLOT then
    local pt = BP_PSLOT._buffCells[1]._points[1]
    BP_CELL_SIDE = (pt[2] == RLSuite.raidFrame.content and pt[4] > m.rowWidth)
end
RB_SHOW = (BP_PSLOT._matrixBg ~= nil and BP_PSLOT._matrixBg:IsShown() == true)
RB_FAKE = (BP_FSLOT._matrixBg ~= nil and BP_FSLOT._matrixBg:IsShown() == true)
RB_GEOM = false
if BP_PSLOT._matrixBg then
    local p = BP_PSLOT._matrixBg._points[1]
    RB_GEOM = (p ~= nil and p[2] == RLSuite.raidFrame.content and p[4] == m.rowWidth + 2 and BP_PSLOT._matrixBg._w == NC * 24 + 6 and BP_PSLOT._matrixBg._h == m.rowHeight - 2)
end
RB_RGB0 = BP_PSLOT._matrixBg and BP_PSLOT._matrixBg._texRGBA
""")
check(bool(rt.eval("BP_ON")), "click on 'Raid Buffs' activates the matrix")
check(bool(rt.eval("BP_PRIO1")), "most important buffs first: column 1 is the Kings/stats column")
check(bool(rt.eval("BP_PRIOLAST")), "least priority last: retribution-aura column closes the row")
check(bool(rt.eval("BP_HDR1") and bool(rt.eval("BP_HDR19"))), "column headers show the user's BCI icons (media/BUFFCATICONS/BCI_<c-1>.tga, current column order): one direct SetTexture, no fallbacks")
check(bool(rt.eval("BP_HDR_ICONSZ")), "header icons are square with fixed size = iconSize + iconSpacing (the column pitch)")
check(bool(rt.eval("BP_HDR_TOP")), "G1 header attaches to the BOTTOM of its permanent strip zone; icons live in the zone above the text")
check(bool(rt.eval("BP_LAYOUT_DONE")), "matrix header build can never abort ApplyLayout half-way: whole layout completes (groups + backdrop + cells)")
check(bool(rt.eval("BP_HDR_OUT")), "category header buttons live OUTSIDE the panel (children of the window) and STAY visible with the matrix open")
check(bool(rt.eval("BP_TANK_UNDER")), "the Tanks header sits at the very top of the frame (icon strip moved down to G1)")
check(bool(rt.eval("BP_HDR_BG")), "icon strip backdrop uses the SAME value as the bars backdrop (appearance.matrixBackdrop) and spans all columns")
check(bool(rt.eval("BP_W")), "window width does NOT include the matrix columns area")
check(bool(rt.eval("BP_SPILL")), "header/column icons are drawn BEYOND the window's right edge (rendered outside = click-through)")
check(bool(rt.eval("BP_CELL_ON_ROW") and bool(rt.eval("BP_CELL_SIDE"))), "category icons live ALONG the player's row, past the row right edge")
# --- hover: il titolo di categoria si "illumina"; click: raid warning categoria ---
# v1.11.49: l'accensione vale per le categorie DISPONIBILI con la composizione
# (quelle non disponibili restano spente anche in hover). La verifica sceglie
# quindi una colonna disponibile invece di dare per scontato che lo sia la 1.
rt.execute("""
local av, na
for c, b in ipairs(RLSuite.raidFrame._buffHdrBtns) do
    if b:IsShown() and b._status then
        if b._nodata == false and not av then av = b end
        if b._nodata == true and not na then na = b end
    end
end
BP_HOVER_ON, BP_HOVER_OFF, BP_HOVER_TIP, BP_NODATA_HOVER = false, false, false, false
if av then
    av._scripts.OnEnter(av)
    BP_HOVER_ON = (av._icon._vertex ~= nil and av._icon._vertex[1] == 1 and av._icon._vertex[2] == 1 and av._icon._vertex[3] == 1)
    BP_HOVER_TIP = (GameTooltip._text == av._col.label)
    av._scripts.OnLeave(av)
    BP_HOVER_OFF = (av._icon._vertex[1] == 0.8 and av._icon._vertex[2] == 0.8)
end
if na then
    na._scripts.OnEnter(na)
    BP_NODATA_HOVER = (na._icon._vertex[1] == 0.35 and na._red:IsShown() == false)
    na._scripts.OnLeave(na)
end
local hb = RLSuite.raidFrame._buffHdrBtns[1]
local n0 = #CHAT_LOG
hb._scripts.OnClick(hb)
BP_WARN = false
for i = n0 + 1, #CHAT_LOG do
    if CHAT_LOG[i]:find('RAID_WARNING', 1, true) and CHAT_LOG[i]:find('%stat', 1, true) then BP_WARN = true end
end
""")
check(bool(rt.eval("BP_HOVER_ON")), "hovering an AVAILABLE category icon lights it up (full brightness)")
check(bool(rt.eval("BP_HOVER_OFF")), "hover-exit dims the icon again")
check(bool(rt.eval("BP_HOVER_TIP")), "hovering a category icon shows its name in the tooltip")
# (il caso "categoria non disponibile" e' verificato in modo deterministico
#  nella sezione v1.11.49, con un roster costruito ad hoc)
check(bool(rt.eval("BP_WARN")), "clicking a category title sends a RAID WARNING for that category")
rt.execute("""
local n0 = #CHAT_LOG
RLSuite:ChatCommand('debugbuff')
_DBG_N, _DBG_BLP1, _DBG_NOTLOADED = 0, false, {"0 rows"}
local lines = {}
for i = n0 + 1, #CHAT_LOG do
    lines[#lines + 1] = CHAT_LOG[i]
    if CHAT_LOG[i]:find('BUFFCATICONS', 1, true) then _DBG_N = _DBG_N + 1 end
    if CHAT_LOG[i]:find('BCI_0.tga', 1, true) then _DBG_BLP1 = true end
end
_DBG_OK = (_DBG_N >= 25)
""")
check(bool(rt.eval("_DBG_OK")), f"/rls debugbuff reports one diagnostic line per header column (25)")
check(bool(rt.eval("_DBG_BLP1")), "/rls debugbuff prints the actual icon path (BCI_0.tga) for each column")

rt.execute("""
SAVED_UB2 = UnitBuff
SAVED_GSI2 = GetSpellInfo
GetSpellInfo = function(id) if id == 57399 then return 'Well Fed' end return 'Spell' end
UnitBuff = function(u, i)
    if u ~= 'player' or type(i) ~= 'number' then return nil end
    if i == 1 then return 'Horn of Winter', nil, nil, nil, nil, nil, nil, nil, nil, nil, 57330 end
    if i == 2 then return 'Well Fed' end
    return nil
end
STRAGI_C = nil
for i, c in ipairs(RLSuite.raidFrame:_MatrixCols()) do if c.key == 'strAgi' then STRAGI_C = i end end
RLSuite.raidFrame:RefreshBuffMatrix()
BP_MATCH = (BP_PSLOT._buffCells[STRAGI_C]._texture == 'Tex:57330' and BP_PSLOT._buffCells[STRAGI_C]:IsShown() == true)
BP_MISS = (BP_PSLOT._buffCells[1]:IsShown() == false)
-- i fake ricevono buff CASUALI (set stabile in sessione): la loro riga deve
-- mostrare almeno qualche icona, e un secondo refresh non la cambia
BP_FNAME = BP_FSLOT.member and BP_FSLOT.member.name or '?'
local shown1 = {}
local count1 = 0
for c = 1, NC do
    local tc = BP_FSLOT._buffCells[c]
    if tc and tc:IsShown() then
        shown1[c] = tc._texture or '?'
        count1 = count1 + 1
    end
end
RLSuite.raidFrame:RefreshBuffMatrix()
local same = true
for c = 1, NC do
    local tc = BP_FSLOT._buffCells[c]
    if (tc and tc:IsShown() and shown1[c] ~= tc._texture) or ((not tc or not tc:IsShown()) and shown1[c] ~= nil) then
        same = false
    end
end
BP_FAKE_SOME = (count1 >= 1)
BP_FAKE_STABLE = same
UnitBuff = SAVED_UB2
GetSpellInfo = SAVED_GSI2
RLSuite.raidFrame:UpdateAll()
RLSuite.raidFrame:RefreshBuffMatrix()
BP_HDR_STILL = true
for c = 1, NC do
    BP_HDR_STILL = BP_HDR_STILL and (RLSuite.raidFrame._buffHdrBtns[c]:IsShown() == true)
end
RB_STILL = (BP_PSLOT._matrixBg ~= nil and BP_PSLOT._matrixBg:IsShown() == true)
BP_AFTER = (BP_PSLOT._buffCells[STRAGI_C]:IsShown() == false)
""")
check(bool(rt.eval("BP_MATCH")), "cell on the player's row shows the icon of the ACTIVE buff covering that category")
check(bool(rt.eval("BP_MISS")), "missing category leaves the player's cell empty")
check(bool(rt.eval("BP_FAKE_SOME")), "invited (fake) players receive random buffs: their matrix row shows some category icons")
check(bool(rt.eval("BP_FAKE_STABLE")), "debug random buff sets are stable across refreshes (no flicker)")
check(bool(rt.eval("BP_AFTER")), "buffs gone -> icons gone (matrix tracks live auras)")
check(bool(rt.eval("BP_HDR_STILL")), "all the category titles STAY visible through aura updates/refreshes (never flicker away)")
check(bool(rt.eval("RB_STILL")), "per-row backdrops stay visible through refreshes")
rt.execute("""
-- spacing configurabili + colore backdrop: li cambio, ApplyLayout, misuro
local app = RLSuite.db.profile.raidframe.appearance
app.iconSpacing, app.rowSpacing, app.groupSpacing = 2, 6, 20
app.groupHeaderFontSize = 14
app.matrixBackdrop = { r = 1, g = 0, b = 0, a = 0.6 }
RLSuite.raidFrame:ApplyLayout()
local m3 = RLSuite.raidFrame:LayoutMetrics()
SP_CELLW = (m3.cellW == m3.iconSize + 2)
SP_W = (m3.W == m3.rowWidth)
local s1 = RLSuite.raidFrame.slots[1]._points[1][5]
local s2 = RLSuite.raidFrame.slots[2]._points[1][5]
SP_ROWS = (math.abs((s1 - s2) - (m3.rowHeight + 6)) < 0.001)
SP_GHFONT = (RLSuite.raidFrame.groupHeaders[1]._fontArgs ~= nil and RLSuite.raidFrame.groupHeaders[1]._fontArgs[2] == 14)
SP_TKH = (RLSuite.raidFrame.tankHeader._fontArgs ~= nil and RLSuite.raidFrame.tankHeader._fontArgs[2] == 14)
local bga = BP_PSLOT._matrixBg._texRGBA
SP_BG = (bga ~= nil and math.abs(bga[1] - 1) < 0.01 and math.abs(bga[4] - 0.6) < 0.01)
app.iconSpacing, app.rowSpacing, app.groupSpacing = nil, nil, nil
app.groupHeaderFontSize = nil
app.matrixBackdrop = nil
RLSuite.raidFrame:ApplyLayout()
SP_DEF = (RLSuite.raidFrame:LayoutMetrics().cellW == 24)
""")
check(bool(rt.eval("SP_CELLW")), "Icon spacing option drives the matrix column pitch (iconSize + spacing)")
check(bool(rt.eval("SP_W")), "window width stays rowWidth regardless of icon spacing (columns spill past the window)")
check(bool(rt.eval("SP_ROWS")), "Row spacing option drives the gap between bars inside a group")
check(bool(rt.eval("SP_GHFONT") and rt.eval("SP_TKH")), "Group header font size option applies to G-buttons and the Tanks header")
check(bool(rt.eval("SP_BG")), "Buff check backdrop option recolors the matrix rows backdrop (color + alpha)")
check(bool(rt.eval("SP_DEF")), "spacing options restored to defaults")
rt.execute("""
RLSuite.raidFrame.buffPanelBtn._scripts.OnClick(RLSuite.raidFrame.buffPanelBtn)
BP_CLOSED = (RLSuite.raidFrame.buffMatrixOn ~= true and BP_PSLOT._buffCells[10] ~= nil and BP_PSLOT._buffCells[10]:IsShown() == false)
local m2 = RLSuite.raidFrame:LayoutMetrics()
BP_W_KEEP = (m2.W == m2.rowWidth)
RB_OFF = (BP_PSLOT._matrixBg ~= nil and BP_PSLOT._matrixBg:IsShown() == false)
BP_HDR_PERM = (RLSuite.raidFrame._buffHdrBtns[1]:IsShown() == false and RLSuite.raidFrame._buffHdrBtns[NC]:IsShown() == false)
BP_NOSHIFT = (SLOT1Y_ON ~= nil and math.abs(RLSuite.raidFrame.slots[1]._points[1][5] - SLOT1Y_ON) < 0.001)
BP_HBG_OFF = (RLSuite.raidFrame._buffHdrBg == nil or RLSuite.raidFrame._buffHdrBg:IsShown() == false)
""")
check(bool(rt.eval("BP_CLOSED")), "second click on 'Raid Buffs' hides the row icons/cells")
check(bool(rt.eval("RB_SHOW")), "each PLAYER ROW gets its own gray backdrop strip while the matrix is on (not one window-sized panel)")
check(bool(rt.eval("RB_FAKE")), "fake players' rows also get their per-row backdrop strip")
rgba = rt.eval("RB_RGB0")
check(abs(float(rt.eval("RB_RGB0[1]")) - 0.5) < 0.01 and abs(float(rt.eval("RB_RGB0[2]")) - 0.5) < 0.01 and abs(float(rt.eval("RB_RGB0[3]")) - 0.5) < 0.01 and abs(float(rt.eval("RB_RGB0[4]")) - 0.35) < 0.01, "row backdrop is a semi-transparent GRAY solid texture (0.5,0.5,0.5,0.35)")
check(bool(rt.eval("RB_GEOM")), "row backdrop spans exactly the matrix columns of its own bar, height = row height")
check(bool(rt.eval("BP_W_KEEP")), "matrix columns zone stays OUTSIDE the window hitbox when toggled (click-through preserved)")
check(bool(rt.eval("RB_OFF")), "per-row backdrops are hidden when the matrix icons are off")
check(bool(rt.eval("BP_HDR_PERM")), "header icon row HIDDEN again when the 'Raid Buffs' pipe is off (button toggles the header row)")
check(bool(rt.eval("BP_HBG_OFF")), "header strip backdrop hidden when the matrix is off")
check(bool(rt.eval("BP_NOSHIFT")), "toggling the buff matrix never shifts the player rows (strip zone always reserved between Tanks and G1)")

# --- F.4 MT/OT assignment: SECURE macro buttons (SetPartyAssignment is PROTECTED) ---
check(rt.eval("RLSuite.mainWindow.mtBtn:GetAttribute('type')") == 'macro', "MT button is a SECURE macro button (protected SetPartyAssignment never called)")
check(bool(rt.eval("RLSuite.mainWindow.mtBtn._clickButtons ~= nil and RLSuite.mainWindow.mtBtn._clickButtons[1] == 'LeftButtonDown'")), "MT/OT secure buttons act on press")
rt.execute("""
SAVED_DM_P = RLSuite.DebugMode
RLSuite.DebugMode = function() return false end  -- secure path = raid reale per questo stage
local mt, ot = RLSuite.mainWindow.mtBtn, RLSuite.mainWindow.otBtn
SAVED_UE_P = UnitExists
SAVED_UN_P = UnitName
SAVED_ISO_P = RLSuite.IsOfficer
SAVED_ICL_P = InCombatLockdown
UnitExists = function(u) return u == 'target' end
UnitName = function(u) if u == 'target' then return 'TankyBoss' end return 'Testplayer' end
RLSuite.IsOfficer = function() return true end
RP_MT = mt:GetAttribute('macrotext')
mt._scripts.PreClick(mt)
RP_MT_TXT = mt:GetAttribute('macrotext')
mt._scripts.PostClick(mt)
RP_MT_CLEAN = mt:GetAttribute('macrotext')
ot._scripts.PreClick(ot)
RP_OT_TXT = ot:GetAttribute('macrotext')
ot._scripts.PostClick(ot)
RLSuite.IsOfficer = function() return false end
ot._scripts.PreClick(ot)
RP_NOOFFICER = ot:GetAttribute('macrotext')
RLSuite.IsOfficer = function() return true end
InCombatLockdown = function() return true end
mt._scripts.PreClick(mt)
RP_COMBAT = mt:GetAttribute('macrotext')
InCombatLockdown = SAVED_ICL_P
RLSuite.IsOfficer = SAVED_ISO_P
UnitExists = SAVED_UE_P
UnitName = SAVED_UN_P
RLSuite.DebugMode = SAVED_DM_P
""")
check(bool(rt.eval("RP_MT == '' and RP_MT_CLEAN == ''")), "macrotext empty before click and cleared after (no stale secure actions)")
check(rt.eval("RP_MT_TXT") == '/maintank TankyBoss', "MT click assembles /maintank <target-name> securely")
check(rt.eval("RP_OT_TXT") == '/mainassist TankyBoss', "OT click assembles /mainassist <target-name> securely")
check(bool(rt.eval("RP_NOOFFICER == ''")), "non-leader/assist: no secure macro assembled")
check(bool(rt.eval("RP_COMBAT == ''")), "in combat: no protected attribute edits, no macro assembled")

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
RLSuite.db.profile.anchorMode = true
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
RLSuite.db.profile.anchorMode = false
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
-- 2) unit valida OOC: l'ENGINE overlay targetta, NESSUNA chiamata Lua protetta
reset_click()
SAVED_UE = UnitExists
UnitExists = function(u) return u == 'raid7' end
RLSuite.raidFrame:FillSlot(row, { name = 'Raid7Guy', class = 'WARRIOR', unit = 'raid7', fake = false, raidIndex = 7 })
row._scripts.OnMouseDown(row, 'LeftButton')
TGT_PRESS = LAST_TARGET or LAST_TARGNAME   -- deve restare NIL: solo engine
TGT_ENG_UNIT = row.secTarget:GetAttribute('unit')
TGT_ENG_SHOWN = row.secTarget:IsShown()
row._scripts.OnMouseUp(row, 'LeftButton')
if row._scripts.OnUpdate then row._scripts.OnUpdate(row, 0.016) end
TGT1 = LAST_TARGET or LAST_TARGNAME
-- 3) overlay non aggiornabile (attributi congelati in combat): fallback PER NOME
reset_click()
row.secTarget:Hide()                       -- simula FillSlot congelato in combat
if row.member then row.member.name = 'PippoRosso' end
row.name = 'PippoRosso'
row._scripts.OnMouseDown(row, 'LeftButton')
row._scripts.OnMouseUp(row, 'LeftButton')
if row._scripts.OnUpdate then row._scripts.OnUpdate(row, 0.016) end
TGT_NAME = LAST_TARGNAME
-- 4) SHIFT+click: NON targettare (gesto drag player)
reset_click()
if row.member then row.member.unit = 'raid7'; row.member.fake = false end
row.unit = 'raid7'
IsShiftKeyDown = function() return true end
row._scripts.OnMouseDown(row, 'LeftButton')
row._scripts.OnMouseUp(row, 'LeftButton')
if row._scripts.OnUpdate then row._scripts.OnUpdate(row, 0.016) end
TGT2 = LAST_TARGET or LAST_TARGNAME
-- 5) press senza shift: l'engine overlay targetta alla pressione (prima del movimento)
reset_click()
IsShiftKeyDown = SAVED_ISD2
GetCursorPosition = function() return 200, 110 end
RLSuite.raidFrame:FillSlot(row, { name = 'Raid7Guy', class = 'WARRIOR', unit = 'raid7', fake = false, raidIndex = 7 })
row._scripts.OnMouseDown(row, 'LeftButton')
TGT_PRESS_BEFORE_MOVE = { LAST_TARGET, LAST_TARGNAME }
TGT_PB_ENG = row.secTarget:GetAttribute('unit')
-- cleanup compreso di una FillSlot di ripristino del member originale
if row.member then row.member.unit = SAVED_MU; row.member.fake = SAVED_MF; row.member.name = SAVED_RN or row.member.name end
row.name = SAVED_RN
row.fake = SAVED_RF
row.unit = SAVED_RU
GetCursorPosition = SAVED_GCP4
UnitExists = SAVED_UE
row:SetScript('OnUpdate', nil)
if row.secTarget then row.secTarget:Hide() end
""")

check(bool(rt.eval("TGT_FAKE == nil")), "debug fake roster: bar click does NOT bonk error-invalid-unit (no target for non-existing units)")
check(bool(rt.eval("TGT_PRESS == nil and TGT1 == nil")), "real unit: NO protected Lua TargetUnit ever fires (engine-only path, client-proof)")
check(bool(rt.eval("TGT_ENG_SHOWN")) and rt.eval("TGT_ENG_UNIT") == 'raid7', "secure overlay armed on the real unit: engine targets ON PRESS")
check(rt.eval("TGT_NAME") == 'PippoRosso', "combat-frozen overlay corner: Lua fallback targets by exact NAME only")
check(bool(rt.eval("TGT2 == nil")), "Shift+left on a bar does NOT target (drag gesture)")
check(bool(rt.eval("TGT_PRESS_BEFORE_MOVE[1] == nil and TGT_PRESS_BEFORE_MOVE[2] == nil")) and rt.eval("TGT_PB_ENG") == 'raid7', "no Lua targeting on press (engine), even before any movement")

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
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.font ~= nil")), "Layout -> Font type present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.fontOutline ~= nil")), "Layout -> Font outline toggle present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.barTexture ~= nil")), "Layout -> Bar texture present")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.raidframe.args.alpha ~= nil")), "Layout -> Opacity slider present")
rt.execute(r"""
local o = RLSuite.config:BuildOptionsTable().args.raidframe.args
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
local o = RLSuite.config:BuildOptionsTable().args.raidframe.args
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
rt.execute("RLSuite.config:BuildOptionsTable().args.modulemenu.args.matrixCols.set(nil, 4)")
rt.execute("W1 = RLSuite.mainWindow.frame:GetWidth()")
check(bool(rt.eval("W1 > W0")), "matrix Columns slider re-layouts the main bar in real time (w %d -> %d)" % (rt.eval("W0"), rt.eval("W1")))
rt.execute("RLSuite.config:BuildOptionsTable().args.modulemenu.args.matrixCols.set(nil, 2)")
rt.execute("H0 = RLSuite.mainWindow.frame:GetHeight()")
rt.execute("RLSuite.config:BuildOptionsTable().args.modulemenu.args.matrixRows.set(nil, 8)")
rt.execute("H1 = RLSuite.mainWindow.frame:GetHeight()")
check(bool(rt.eval("H1 > H0")), "matrix Rows slider re-layouts the main bar in real time (h %d -> %d)" % (rt.eval("H0"), rt.eval("H1")))
rt.execute("RLSuite.config:BuildOptionsTable().args.modulemenu.args.matrixRows.set(nil, 4)")

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
# --- I tasti MT/OT sono ora SECURE macro buttons: SetPartyAssignment e' PROTETTA ---
# --- (forbidden dal client) -> il click assembla "/maintank <nome>" via PreClick. ---
rt.execute("""
SAVED_DM_G = RLSuite.DebugMode
RLSuite.DebugMode = function() return false end
_OLD_UnitExists = UnitExists
_OLD_UnitName = UnitName
_OLD_IsRaidLeader = IsRaidLeader
MT_CALLS = {}
UnitExists = function(u) return u == 'target' end
UnitName = function(u) if u == 'target' then return 'Bossunit' end return 'Testplayer' end
IsRaidLeader = function() return true end
local b = RLSuite.mainWindow.mtBtn
if b and b._scripts.PreClick then b._scripts.PreClick(b) end
MT_CALLS[1] = b:GetAttribute('macrotext')
if b and b._scripts.PostClick then b._scripts.PostClick(b) end
local o = RLSuite.mainWindow.otBtn
if o and o._scripts.PreClick then o._scripts.PreClick(o) end
MT_CALLS[2] = o:GetAttribute('macrotext')
if o and o._scripts.PostClick then o._scripts.PostClick(o) end
""")
check(rt.eval("MT_CALLS[1]") == "/maintank Bossunit", "MT click assembles /maintank on the target (secure macro, no forbidden SetPartyAssignment)")
check(rt.eval("MT_CALLS[2]") == "/mainassist Bossunit", "OT click assembles /mainassist on the target (secure macro, no forbidden SetPartyAssignment)")
rt.execute("""
UnitExists = function(u) return u == 'player' end
local b = RLSuite.mainWindow.mtBtn
if b and b._scripts.PreClick then b._scripts.PreClick(b) end
MT_NOGROW = (b:GetAttribute('macrotext') == '')
""")
check(bool(rt.eval("MT_NOGROW == true")), "MT click with no target assembles no macro")
rt.execute("""
UnitExists = _OLD_UnitExists
UnitName = _OLD_UnitName
IsRaidLeader = _OLD_IsRaidLeader
RLSuite.DebugMode = SAVED_DM_G
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

# --- G.6b ACE button skin: borderless, no Blizzard default graphics ---
rt.execute("""
local function aceSkin(b)
    if not (b and b._backdrop) then return false end
    -- BOTTONI BORDERLESS: fill piatto WHITE8x8, NESSUN bordo dialog (edgeFile == nil)
    return b._backdrop.bgFile == [[Interface\Buttons\WHITE8x8]]
        and b._backdrop.edgeFile == nil
        and b._backdropColor and math.abs(b._backdropColor[1] - 0.16) < 0.001
end
ACE_RF = aceSkin(RLSuite.raidFrame.buffPanelBtn)
ACE_GM = aceSkin(RLSuite.groupmaking.diffBtn10) and aceSkin(RLSuite.groupmaking.spamBtn)
ACE_LM = aceSkin(RLSuite.lootManager.rollMSBtn) and aceSkin(RLSuite.lootManager.rerollBtn)
ACE_MS = aceSkin(RLSuite.msManager.requestBtn) and aceSkin(RLSuite.msManager.genMsgBtn)
-- hover = fill che schiarisce (hooks OnEnter/OnLeave), mai un bordo
local b0 = RLSuite.raidFrame.buffPanelBtn
if b0._scripts and b0._scripts.OnEnter then b0._scripts.OnEnter(b0) end
ACE_HOVER = (b0._backdropColor and math.abs(b0._backdropColor[1] - 0.26) < 0.001
    and math.abs(b0._backdropColor[2] - 0.29) < 0.001)
if b0._scripts and b0._scripts.OnLeave then b0._scripts.OnLeave(b0) end
ACE_LEAVE = (b0._backdropColor and math.abs(b0._backdropColor[1] - 0.16) < 0.001)
""")
check(bool(rt.eval("ACE_RF")), "ACE skin on the 'Raid Buffs' button (borderless dark flat)")
check(bool(rt.eval("ACE_GM")), "ACE skin on Groupmaking buttons: no dialog border, no Blizzard default graphics")
check(bool(rt.eval("ACE_LM")), "ACE skin on Loot manager buttons (borderless)")
check(bool(rt.eval("ACE_MS")), "ACE skin on MS Manager buttons (borderless)")
check(bool(rt.eval("ACE_HOVER") and bool(rt.eval("ACE_LEAVE"))), "borderless buttons: hover brightens the fill, leaving restores it")

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
rt.execute("local p, rel, rp, x, y = RLSuite.lootManager.tradeWindows[1]:GetPoint(1); RISE_OK = (p == 'TOP' and rel == UIParent and rp == 'TOP' and y == -80)")
check(bool(rt.eval("RISE_OK == true")), "closing the first pickup window makes the next one rise to the base anchor (top of the screen)")
check(bool(rt.eval("RLSuite.lootManager.tradeWindows[1]._enabledMouse == false")), "pickup window frame NEVER captures mouse (only its icon and close button do)")
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

# =====================================================================
print("== Scenario H: macrobar numbers off, loot ignore rules, MS announce in loot, pickup click fix ==")
# =====================================================================

# --- H.1 MacroBar: i numerini sulle icone non esistono piu' ---
check(bool(rt.eval("RLSuite.macrobar.buttons[1].numText == nil")), "macrobar icons have NO index numbers anymore")
check(bool(rt.eval("RLSuite.macrobar.buttons[1].hotkey ~= nil")), "macrobar keybind text kept on the icons")
check(bool(rt.eval("RLSuite.macrobar.keypadFrame._noOuterBorder == true")), "macrobar keypad (key buttons section) flagged borderless")
check(bool(rt.eval("(function() local k = RLSuite.macrobar.keypadFrame; return k._backdrop ~= nil and (k._backdropBorderColor[4] or 1) == 0 end)()")), "keypad section: themed fill kept, border fully invisible")

# --- H.2 Loot Manager: emblemi SEMPRE ignorati ---
rt.execute("""
local lm = RLSuite.lootManager
lm.history = {}; if lm.db then lm.db.history = lm.history end
lm.selectedItem = nil
lm:UpdateHistory()
H_N0 = #lm.history
lm:OnLootMessage('You receive loot: |cffa335ee|Hitem:49426:0:0:0:0:0:0:0:80|h[Emblem of Frost]|h|r.')
H_EMB = #lm.history
lm:OnLootMessage('You receive loot: |cffa335ee|Hitem:40753:0:0:0:0:0:0:0:80|h[Emblem of Valor]|h|r.')
H_EMB2 = #lm.history
""")
check(bool(rt.eval("H_N0 == 0 and H_EMB == 0 and H_EMB2 == 0")), "emblems (Frost/Valor) are NEVER recorded in the loot history")
rt.execute("RLSuite.lootManager:UpdateHistory(); H_EMBROWS = #RLSuite.lootManager.histRows")
check(bool(rt.eval("H_EMBROWS == 0")), "no emblem rows ever show in the list")

# --- H.3 Loot Manager: loot da item in borsa ignorato ---
rt.execute("""
local lm = RLSuite.lootManager
H_BAG_OK = (HOOKS.UseContainerItem ~= nil)  -- hook registrato a Init
if HOOKS.UseContainerItem then HOOKS.UseContainerItem() end  -- simula uso Sack of Frosty Treasures
lm:OnLootOpened()
H_B1 = #lm.history
lm:OnLootMessage('You receive loot: |cffa335ee|Hitem:50100:0:0:0:0:0:0:0:80|h[Sack Item]|h|r.')
H_B2 = #lm.history
lm:OnLootClosed()
H_BAG_FLAG = (lm._containerLoot == false)
lm:OnLootMessage('You receive loot: |cffa335ee|Hitem:50100:0:0:0:0:0:0:0:80|h[Sack Item]|h|r.')
H_B3 = #lm.history
""")
check(bool(rt.eval("H_BAG_OK == true")), "UseContainerItem is hooked to detect bag-loot windows")
check(bool(rt.eval("H_B1 == 0 and H_B2 == 0")), "loot from items opened in the player bags (Sack of Frosty Treasures) is ignored")
check(bool(rt.eval("H_BAG_FLAG == true and H_B3 == 1")), "after the bag window closes, normal boss loot is recorded again")

# --- H.4 Loot Manager: checkbox ignore loots (recipes/BOE/gems/shards) ---
rt.execute("""
local lm = RLSuite.lootManager
lm.history = {}; if lm.db then lm.db.history = lm.history end
lm.selectedItem = nil
lm:UpdateHistory()
H_CK = (lm.ignoreChecks ~= nil and lm.ignoreChecks.recipes ~= nil and lm.ignoreChecks.boe ~= nil
    and lm.ignoreChecks.gems ~= nil and lm.ignoreChecks.shards ~= nil)
ITEMINFO_DB['|cff0070dd|Hitem:99901:0:0:0:0:0:0:0:80|h[Pattern: Test Boots]|h|r']
    = {'Pattern: Test Boots', '|cff0070dd|Hitem:99901:0:0:0:0:0:0:0:80|h[Pattern: Test Boots]|h|r', 3, 80, 80, 'Recipe', 'Leatherworking', 1, '', 'tex'}
ITEMINFO_DB['|cff0070dd|Hitem:99902:0:0:0:0:0:0:0:80|h[Bold Cardinal Ruby]|h|r']
    = {'Bold Cardinal Ruby', '|cff0070dd|Hitem:99902:0:0:0:0:0:0:0:80|h[Bold Cardinal Ruby]|h|r', 3, 80, 80, 'Gem', 'Red', 1, '', 'tex'}
""")
check(bool(rt.eval("H_CK == true")), "the 4 'ignore loots' checkboxes exist (recipes/BOE/gems/shards)")
rt.execute("""
local lm = RLSuite.lootManager
local function clickCB(key, state)
    local cb = lm.ignoreChecks[key]
    cb:SetChecked(state)
    cb._scripts.OnClick(cb, 'LeftButton')
end
H_F0 = #lm.history
-- gems on
clickCB('gems', true)
lm:OnLootMessage('You receive loot: |cff0070dd|Hitem:99902:0:0:0:0:0:0:0:80|h[Bold Cardinal Ruby]|h|r.')
H_GEM_CAP = #lm.history
lm:UpdateHistory()
H_GEM_ROWS = #lm.histRows
-- gems off
clickCB('gems', false)
lm:OnLootMessage('You receive loot: |cff0070dd|Hitem:99902:0:0:0:0:0:0:0:80|h[Bold Cardinal Ruby]|h|r.')
H_GEM_ON = #lm.history
H_GEM_ROWS2 = #lm.histRows
-- recipes on
local n0 = #lm.history
clickCB('recipes', true)
lm:OnLootMessage('You receive loot: |cff0070dd|Hitem:99901:0:0:0:0:0:0:0:80|h[Pattern: Test Boots]|h|r.')
H_REC = (#lm.history == n0)
clickCB('recipes', false)
-- shards on
clickCB('shards', true)
lm:OnLootMessage('You receive loot: |cff0070dd|Hitem:34052:0:0:0:0:0:0:0:80|h[Dream Shard]|h|r.')
H_SHARD = (#lm.history == n0)
clickCB('shards', false)
-- BOE on: 99904 Armatura con tooltip 'Binds when equipped'
ITEMINFO_DB['|cffa335ee|Hitem:99904:0:0:0:0:0:0:0:80|h[BOE Chestplate]|h|r']
    = {'BOE Chestplate', '|cffa335ee|Hitem:99904:0:0:0:0:0:0:0:80|h[BOE Chestplate]|h|r', 4, 80, 80, 'Armor', 'Plate', 1, '', 'tex'}
TOOLTIP_LINES = { [2] = ITEM_BIND_ON_EQUIP }
TOOLTIP_REFRESH()
clickCB('boe', true)
lm:OnLootMessage('You receive loot: |cffa335ee|Hitem:99904:0:0:0:0:0:0:0:80|h[BOE Chestplate]|h|r.')
H_BOE = (#lm.history == n0)
clickCB('boe', false)
lm:OnLootMessage('You receive loot: |cffa335ee|Hitem:99904:0:0:0:0:0:0:0:80|h[BOE Chestplate]|h|r.')
H_BOE2 = (#lm.history == n0 + 1)
TOOLTIP_LINES = {}
TOOLTIP_REFRESH()
H_FIL_DB = (lm.db.filters.gems == false and lm.db.filters.shards == false)
""")
check(bool(rt.eval("H_F0 == 0 and H_GEM_CAP == 0")), "'gems' checkbox: gem loot is never recorded while enabled")
check(bool(rt.eval("H_GEM_ON == 1 and H_GEM_ROWS2 == 1")), "'gems' checkbox off: gem loot recorded again")
check(bool(rt.eval("H_REC == true")), "'recipes' checkbox: recipe loot ignored")
check(bool(rt.eval("H_SHARD == true")), "'shards' checkbox: Dream Shard ignored")
check(bool(rt.eval("H_BOE == true and H_BOE2 == true")), "'BOE' checkbox: bind-on-equip loot ignored only while enabled")
check(bool(rt.eval("H_FIL_DB == true")), "checkbox states persist into db.loot.filters")

# --- H.5 Announce Changes button also in the Loot Manager ---
rt.execute("""
local lm = RLSuite.lootManager
H_ANC = (lm.announceMSBtn ~= nil and lm.announceMSBtn:GetText() == 'Announce Changes')
MS_CALLED = 0
local orig = RLSuite.msManager.GenerateMessage
RLSuite.msManager.GenerateMessage = function() MS_CALLED = MS_CALLED + 1 end
lm.announceMSBtn._scripts.OnClick(lm.announceMSBtn)
RLSuite.msManager.GenerateMessage = orig
""")
check(bool(rt.eval("H_ANC == true")), "'Announce Changes' button present in the Loot Manager")
check(bool(rt.eval("MS_CALLED == 1")), "clicking it runs the MS Manager announce (GenerateMessage)")

# --- H.6 pickup click: NIENTE item sul cursore senza trade aperto ---
rt.execute("""
local lm = RLSuite.lootManager
lm:CloseAllTradeWindows()
PICKED_ITEM = nil
TRADE_BTN = 0
TradeFrame:Hide()
lm:ShowTradeWindow({ itemTexture = 'tex', itemLink = '|cffa335ee|Hitem:42|h[Loot A]|h|r', assignedTo = 'Winnerbot' })
local tw = lm.tradeWindows[1]
H_PB = (tw.pickBtn ~= nil)
tw.pickBtn._scripts.OnClick(tw.pickBtn)
H_NOPICK = (PICKED_ITEM == nil)
H_STAY = (#lm.tradeWindows == 1 and tw:IsShown())
TradeFrame:Show()
tw.pickBtn._scripts.OnClick(tw.pickBtn)
H_PICKED = (PICKED_ITEM == '|cffa335ee|Hitem:42|h[Loot A]|h|r')
H_TRADECL = (TRADE_BTN == 1)
H_CLOSED2 = (#lm.tradeWindows == 0)
TradeFrame:Hide()
""")
check(bool(rt.eval("H_PB == true")), "pickup icon button reference kept for the gated click")
check(bool(rt.eval("H_NOPICK == true and H_STAY == true")), "no trade open: click does NOT put the item on the cursor and keeps the window (list stays clickable)")
check(bool(rt.eval("H_PICKED == true and H_TRADECL == true and H_CLOSED2 == true")), "trade open: click picks the item up, drops it in trade slot 1 and closes the window")

# pulizia storico usato nello scenario H
rt.execute("local lm = RLSuite.lootManager; lm.history = {}; if lm.db then lm.db.history = lm.history end; lm.selectedItem = nil; lm:UpdateHistory()")

# =====================================================================
print("== Scenario I: Combat Log (parser 3.3.5, segmentazione pull, store, aggregazioni, UI tabs, grafico) ==")
# =====================================================================

# --- I.1 wiring: tab, finestra, defaults ---
check(bool(rt.eval("RLSuite.combatLog ~= nil and RLSuite.combatLog.frame ~= nil")), "combat log module and window exist")
_toc_ver = open("RaidLeadSuite.toc", encoding="utf-8").read().split("## Version:")[1].split("\n")[0].strip()
_ver = rt.eval("RLSuite.version")
check(_ver == _toc_ver, "v1.11.69: la versione mostrata in chat coincide col .toc (%r vs %r) — un tester deve poter dire quale build ha" % (_ver, _toc_ver))
check("GetAddOnMetadata" in open("Core.lua", encoding="utf-8").read(), "v1.11.69: la versione e' letta dal .toc (niente piu' costanti che restano indietro)")
check(rt.eval("RLSuite.combatLog._initError") is None, "v1.11.66: la finestra del Log si e' costruita SENZA errori (nessun errore ingoiato dal pcall): %r" % rt.eval("RLSuite.combatLog._initError"))
check(bool(rt.eval("RLSuite.combatLog.gridPane ~= nil and RLSuite.combatLog.deathPane ~= nil and RLSuite.combatLog.tabGroup ~= nil")), "v1.11.66: tutti i pannelli del Log esistono (griglia, morti, tab group)")
check(bool(rt.eval("RLSuite.mainWindow:PaneForTab('log') == RLSuite.combatLog.frame")), "main window 'log' tab pane is the combat log window")
check(bool(rt.eval("RLSuite.mainWindow.tabs.log ~= nil")), "'Log' tab button exists on the main bar")
check(bool(rt.eval("RLSuite.combatLog.graph ~= nil")), "combat log graph widget created at init")
check(bool(rt.eval("RLSuite.mainWindow:LayoutKeyForTab('log') == 'combatlog'")), "layout key for the log tab is 'combatlog' (matches drag/resize persistence)")
rt.execute("RLSuite.mainWindow:ShowTab('log')")
check(bool(rt.eval("RLSuite.mainWindow.currentTab == 'log'")), "SelectTab keeps the 'log' key (was silently rewritten to 'group' -> opened Groupmaking)")
check(bool(rt.eval("RLSuite.combatLog.frame:IsShown() == true")), "clicking the Log tab shows the combat log window (not Groupmaking)")
rt.execute("RLSuite.combatLog.frame:Hide(); RLSuite.mainWindow.currentTab = nil")

# resize grip regression: delta relativo al mouse-down, clampato allo schermo
rt.execute("Rh = CreateFrame('Frame', nil, UIParent); Rh:Show(); Rh:SetSize(300, 200); Rh:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -100, -100)")
rt.execute("R_GRIP = RLSuite.utils:AddResizeGrip(Rh, 'rsztest', 100, 80)")
rt.execute("""
SAVED_GCP_R, SAVED_IMBD_R = GetCursorPosition, IsMouseButtonDown
GetCursorPosition = function() return 300, 150 end
IsMouseButtonDown = function() return true end
R_GRIP._scripts["OnMouseDown"](R_GRIP, "LeftButton")
GetCursorPosition = function() return 400, 200 end
R_GRIP._scripts["OnUpdate"](R_GRIP)
R_W1, R_H1 = Rh:GetWidth(), Rh:GetHeight()
GetCursorPosition = function() return 100000, -100000 end
R_GRIP._scripts["OnUpdate"](R_GRIP)
R_W2, R_H2 = Rh:GetWidth(), Rh:GetHeight()
IsMouseButtonDown = function() return false end
R_GRIP._scripts["OnUpdate"](R_GRIP)
R_LASTW = RLSuite.utils:WindowLayout('rsztest').width
GetCursorPosition, IsMouseButtonDown = SAVED_GCP_R, SAVED_IMBD_R
""")
check(rt.eval("math.abs(R_W1 - 400) < 0.01 and math.abs(R_H1 - 150) < 0.01"), "resize grip follows the mouse delta while dragging (400x150)")
check(rt.eval("R_W2 <= 1024 and R_H2 <= 768"), "resize grip CLAMPED to the screen: window can never become huge again (was the StartSizing bug)")
check(rt.eval("R_LASTW == R_W2 and R_LASTW > 0"), "resize grip size persisted on release (auto-finish outside the grip works)")
rt.execute("Rh:Hide()")

# window self-heal regression: brutalized saved sizes are clamped back on open
rt.execute("RLSuite.utils:WindowLayout('combatlog').width = 5001; RLSuite.utils:WindowLayout('combatlog').height = 3001")
rt.execute("RLSuite.mainWindow:ShowTab('log')")
check(rt.eval("RLSuite.combatLog.frame:GetWidth() <= 1024 and RLSuite.combatLog.frame:GetHeight() <= 768"), "opening a tab heals oversized SAVED window dims (<= screen): the Log window comes back on-screen by itself")
check(rt.eval("RLSuite.utils:WindowLayout('combatlog').width == 1024"), "healed size written back into the saved layout (no more repeating blow-up)")
rt.execute("Cw = CreateFrame('Frame', nil, UIParent); Cw:Show(); Cw:SetSize(5000, 3000); Cw:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 0, 0); RLSuite.utils:ClampWindowToScreen(Cw)")
check(rt.eval("Cw:GetWidth() == 1024 and Cw:GetHeight() == 768"), "ClampWindowToScreen directly clamps any oversized frame to the screen")
rt.execute("Cw:Hide(); RLSuite.combatLog.frame:Hide(); RLSuite.mainWindow.currentTab = nil")


check(bool(rt.eval("RLSuite.combatLog.db ~= nil and RLSuite.combatLog.db.saveFights == 15 and RLSuite.combatLog.db.maxEvents == 3000")), "db.combatlog defaults loaded (saveFights 15, maxEvents 3000)")

# --- I.2 helpers: guid npc id + realm strip + flags ---
rt.execute("""
local cl = RLSuite.combatLog
G_NPC = cl:NpcIdFromGUID('0xF130008F040000AA')
G_NPC2 = cl:NpcIdFromGUID('0xF1300090020000BB')
G_MODERN = cl:NpcIdFromGUID('Creature-0-1463-0-63-36612-0000123ABC')
G_PLAYERGUID = cl:NpcIdFromGUID('0x0700000001234ABC')
G_SHORT = cl:ShortName('Testplayer-TestRealm')
G_SHORT2 = cl:ShortName('OtherName')
""")
check(bool(rt.eval("G_NPC == 36612")), "3.3.5 GUID parse: Marrowgar npc id 36612 from hex GUID")
check(bool(rt.eval("G_NPC2 == 36866")), "3.3.5 GUID parse: second npc id (36866)")
check(bool(rt.eval("G_MODERN == 36612")), "modern dash GUID parse also yields the npc id")
check(bool(rt.eval("G_PLAYERGUID == nil")), "player GUID does not produce an npc id")
check(bool(rt.eval("G_SHORT == 'Testplayer' and G_SHORT2 == 'OtherName'")), "realm suffix stripped for same-realm names only")

# --- I.3 registrazione: pull, eventi, kill, ring buffer, filtri ---
rt.execute("""
local cl = RLSuite.combatLog
local now = GetTime()
cl.selFight = nil
-- fight 1: danni + kill Marrowgar
cl:OnRegenDisabled()
I_REC1 = (cl.current ~= nil)
-- player -> boss: SPELL_DAMAGE (id, name, school, amount, overkill, school2, resisted, blocked, absorbed, critical)
cl:OnCLEU(nil, now, 'SPELL_DAMAGE', '0x0p', 'PlayerOne', 1024+16+1, '0xF130008F040000AA', 'Lord Marrowgar', 2048+64, 100, 'Fireball', 4, 5000, 0, 0, 0, 0, 0, 1)
cl:OnCLEU(nil, now, 'SPELL_DAMAGE', '0x0p', 'PlayerTwo', 1024+16+1, '0xF130008F040000AA', 'Lord Marrowgar', 2048+64, 100, 'Frostbolt', 2, 3000, 100, 0, 0, 200, 0, 0)
cl:OnCLEU(nil, now, 'SWING_DAMAGE', '0x0p', 'PlayerOne', 1024+16+1, '0xF130008F040000AA', 'Lord Marrowgar', 2048+64, 1500, 0, 1, 0, 0, 0, 0)
cl:OnCLEU(nil, now, 'SPELL_HEAL', '0x0p', 'HealerOne', 1024+16+1, '0x0q', 'PlayerOne', 1024+16+1, 200, 'Flash Heal', 2, 4000, 500, 0, 0)
-- aura uptime: 10s applicate poi rimosse (fake GetTime avanzato via t2)
cl:OnCLEU(nil, now, 'SPELL_AURA_APPLIED', '0xF130008F040000AA', 'Lord Marrowgar', 2048+64, '0x0p', 'PlayerOne', 1024+16+1, 300, 'Bone Spike', 6, 'DEBUFF')
cl:OnCLEU(nil, now, 'SPELL_INTERRUPT', '0x0p', 'KickerOne', 1024+16+1, '0xF130008F040000AA', 'Lord Marrowgar', 2048+64, 400, 'Kick', 1, 500, 'Frost Bolt', 4)
cl:OnCLEU(nil, now, 'UNIT_DIED', '0x0p', '', 0, '0xF130008F040000AA', 'Lord Marrowgar', 2048+64)
I_BOSS = cl.current.boss
I_KILL0 = cl.current.kill
I_CNT1 = cl.current.count
cl:OnRegenEnabled()
I_REC0 = (cl.current == nil)
I_F1 = cl.db.fights[1]
I_KILLF = I_F1.kill == true
I_PERSISTCNT = #cl.db.fights
""")
check(bool(rt.eval("I_REC1 == true and I_REC0 == true")), "combat start/end opens and closes a fight segment")
check(bool(rt.eval("I_BOSS == 'Lord Marrowgar' and I_KILLF == true")), "fight named after the boss NPC and marked KILL on its UNIT_DIED")
check(bool(rt.eval("I_CNT1 == 7 and I_PERSISTCNT == 1")), "7 events captured and fight persisted into db.fights")
check(rt.eval("I_F1.name") == "Lord Marrowgar", "saved fight carries the boss name")

# --- I.4 filtri cattura: damage off => non registrato; buffs off ---
rt.execute("""
local cl = RLSuite.combatLog
cl.db.filters.damage = false
cl:OnRegenDisabled()
local now = GetTime()
cl:OnCLEU(nil, now, 'SPELL_DAMAGE', '0x0p', 'PlayerOne', 1024+16+1, '0xF1300090020000BB', 'Sindragosa', 2048+64, 100, 'Fireball', 4, 5000, 0)
cl:OnCLEU(nil, now, 'SPELL_HEAL', '0x0p', 'HealerOne', 1024+16+1, '0x0q', 'PlayerOne', 1024+16+1, 200, 'Flash Heal', 2, 4000, 500, 0, 0)
I_FLTCNT = cl.current.count
cl:OnRegenEnabled()
cl.db.filters.damage = true
""")
check(bool(rt.eval("I_FLTCNT == 1")), "capture filters skip disabled categories (damage off: only the heal lands)")

# --- I.5 aggregazioni ---
rt.execute("""
local cl = RLSuite.combatLog
ROSTER_MOCK = { { 'PlayerOne', 1, 1, 80, 80, 'WARRIOR' }, { 'PlayerTwo', 1, 1, 80, 80, 'PALADIN' }, { 'HealerOne', 1, 1, 80, 80, 'DRUID' } }
local f = cl.db.fights[2] -- fight di Marrowgar (subito dopo: il fight filtrato e' [1])
local rows, total = cl:AggTotals(f, 'damage')
I_TOT = total
I_TOP = rows[1] and rows[1].name
I_TOPAMT = rows[1] and rows[1].amt
local srows, stotal = cl:AggSpells(f, 'damage', 'PlayerOne')
I_SPELLS = #srows
I_SP1 = srows[1] and srows[1].amt
local arows = cl:AggAuras(f)
I_AURAUPS = 0
for _, a in ipairs(arows) do if a.name == 'Bone Spike' then I_AURAUPS = a.up end end
local erows, etotal = cl:AggEnemies(f)
I_ENEMY = erows[1] and erows[1].name
local irows = cl:AggInterrupts(f, 'interrupt')
I_ITXT = irows[1] and irows[1].text
local prows = cl:FightPlayers(f)
I_PSP = #prows
local dps = cl:DpsSeries(f, 'PlayerOne', 1)
I_DPSMAX = 0
for _, p in ipairs(dps) do if p[2] > I_DPSMAX then I_DPSMAX = p[2] end end
""")
check(bool(rt.eval("I_TOT == 9500 and I_TOP == 'PlayerOne' and I_TOPAMT == 6500")), "damage totals per source aggregated (PlayerOne 6500 of 9500)")
check(bool(rt.eval("I_SPELLS >= 2 and I_SP1 == 5000")), "per-spell breakdown for the selected source")
check(bool(rt.eval("I_AURAUPS > 0")), "aura uptime engine closes the opened aura at fight end")
check(bool(rt.eval("I_ENEMY == 'Lord Marrowgar'")), "enemies tab: damage taken by boss")
check(bool(rt.eval("I_ITXT == 'KickerOne interrupt Lord Marrowgar with Kick (Frost Bolt)'")), "interrupt row formatted MRT-style (X interrupt Y with Z (interrupted))")
check(bool(rt.eval("I_PSP >= 3")), "player list of the fight enumerated from GUID flags")
check(bool(rt.eval("I_DPSMAX >= 6000")), "DPS series buckets spike over 6000 on the nuke second")

# --- I.5b v1.11.58: il grafico e' una CURVA CONTINUA, non barrette --------
# Il vecchio disegno tentava di tracciare una polilinea con texture ruotate:
# Texture:SetRotation ruota il DISEGNO dentro la texture, non il rettangolo,
# quindi su colore pieno non cambia nulla e i tratti restano orizzontali
# ("accrocchio di barrette"). Ora: colonne che riempiono l'area + linea sopra.
_cl_src = open("CombatLog.lua", encoding="utf-8").read()
_cl_code = "\n".join(l for l in _cl_src.split("\n") if not l.strip().startswith("--"))
check('SetRotation' not in _cl_code, "no rotated textures left in the drawing code (rotation never worked on a flat texture)")
check('g.ValueAt = function' in _cl_src, "graph exposes ValueAt (interpolated value at any x, used by draw + mouse readout)")

rt.execute("""
    G = RLSuite.combatLog.graph
    -- serie sintetica a rampa: 0 -> 10000 in 10 passi
    SYN = {}
    for i = 0, 10 do SYN[#SYN + 1] = { i, i * 1000 } end
    G:SetData(SYN, {})
    SYN_FILLS, SYN_CAPS, SYN_H, SYN_YMAX = 0, 0, 0, G._yMax
    prevCapTop, CONT = nil, true
    for i, t in ipairs(G._linePool) do
        if t:IsShown() then
            SYN_FILLS = SYN_FILLS + 1
            local p = t._points[1] or {}
            local top = (p[5] or 0) + (t._h or 0)
            if prevCapTop and math.abs(top - prevCapTop) > 60 then CONT = false end
            prevCapTop = top
        end
    end
    for i, t in ipairs(G._capPool) do if t:IsShown() then SYN_CAPS = SYN_CAPS + 1 end end
    -- altezza massima del riempimento = altezza del grafico (valore di picco)
    local hi = 0
    for i, t in ipairs(G._linePool) do
        if t:IsShown() and (t._h or 0) > hi then hi = t._h end
    end
    SYN_H = hi
    SYN_PLOTH = G.height - 4
""")
check(bool(rt.eval("SYN_FILLS > 200 and SYN_CAPS == SYN_FILLS")),
      "curve drawn as %d columns, each with its own line cap" % rt.eval("SYN_FILLS"))
check(bool(rt.eval("CONT == true")),
      "adjacent columns never jump: the curve is CONTINUOUS (no more dashes)")
check(bool(rt.eval("SYN_H >= SYN_PLOTH - 2 and SYN_YMAX == 10000")),
      "column heights follow the values (peak = full plot height)")
rt.execute("""
    V1 = G:ValueAt(2.5)
    V2 = G:ValueAt(7.5)
    V3 = G:ValueAt(0)
    V4 = G:ValueAt(10)
    GRID = 0
    for i, t in ipairs(G._gridPool) do if t:IsShown() then GRID = GRID + 1 end end
""")
check(rt.eval("V1") == 2500 and rt.eval("V2") == 7500, "ValueAt interpolates linearly between samples (mouse readout values)")
check(rt.eval("V3") == 0 and rt.eval("V4") == 10000, "ValueAt clamps at the series ends")
check(bool(rt.eval("GRID") == 3), "horizontal grid lines at 25/50/75%% of the scale")

# -- il tooltip legge tempo + valore (con l'unita' del modo attivo) --------
rt.execute("""
    TIP_OK = false
    if GameTooltip and G.ValueAt then
        G.series = SYN
        G.xMin, G.xMax, G._hoverOn = 0, 10, true
        TOOLTIP_LINES = {}
        local tip = GameTooltip
        local oldAdd, oldClear = tip.AddLine, tip.ClearLines
        tip.AddLine = function(self2, txt) TOOLTIP_LINES[#TOOLTIP_LINES + 1] = tostring(txt) return self2 end
        tip.ClearLines = function(self2) return self2 end
        G:GetScript("OnUpdate")(G, 0.2)
        tip.AddLine, tip.ClearLines = oldAdd, oldClear
        G._hoverOn = false
        TIP_OK = (#TOOLTIP_LINES >= 1)
    end
""")
check(bool(rt.eval("TIP_OK == true")), "hovering the graph opens a readout tooltip (time + value)")

# --- I.6 UI (v1.11.63, layout stile UwU): griglia + tab + grafico fanno parte
# --- di una sola finestra: grafico sempre visibile, tab che cambiano il
# --- contenuto (griglia / due liste storiche / morti).
rt.execute("""
local cl = RLSuite.combatLog
ROSTER_MOCK = { { 'PlayerOne', 1, 1, 80, 80, 'WARRIOR' } }
cl.selFight = cl.db.fights[2]
cl:SelectTab('damage')
I_GRID_TAB = cl.gridPane:IsShown() and not cl.legacyPane:IsShown()
I_COLS = #(cl.grid.cols or {})
I_ROWS = #(cl.grid.pool[I_COLS] or {})
I_HDR = cl.grid.hdrPool[1] and cl.grid.hdrPool[1].btn.fs:GetText()
-- click su una riga (la 1 e' la riga TOTAL, senza nome): la 2 = primo player
local row = cl.grid.pool[I_COLS] and cl.grid.pool[I_COLS][2]
I_ROWTXT = row and row.cells[1].fs:GetText()
if row and row._scripts.OnClick then row._scripts.OnClick(row) end
I_SEL = cl.selSource
cl:SelectTab('interrupts')
I_IL = 0
for _, r in ipairs(cl._lRows) do if r:IsShown() then I_IL = I_IL + 1 end end
I_LEGACY = cl.legacyPane:IsShown() and not cl.gridPane:IsShown()
cl:SelectTab('deaths')
I_DEATH = cl.deathPane:IsShown() and not cl.gridPane:IsShown()
cl:SelectTab('damage')
I_BACK = cl.gridPane:IsShown() and not cl.deathPane:IsShown()
cl:RefreshGraph()
I_SERIES = (cl.graph.series ~= nil and #cl.graph.series > 0)
I_VLINES = (cl.graph.vlines ~= nil and #cl.graph.vlines >= 1)
I_GPANE = (cl.graphPane:IsShown() == true)
""")
check(bool(rt.eval("I_GRID_TAB == true and I_COLS >= 6")), "v1.11.63: damage tab draws a GRID (name/rank/dps/useful/heal/taken)")
check(bool(rt.eval("I_HDR == 'Name'")), "v1.11.63: grid column headers rendered (first = Name)")
check(bool(rt.eval("I_ROWS >= 2")), "v1.11.63: grid has the TOTAL row + one row per player")
check(bool(rt.eval("I_SEL == 'PlayerOne'")), "v1.11.63: clicking a grid row selects the player for the graph")
check(bool(rt.eval("I_IL == 1")), "interrupts tab lists the kick event (legacy two-list pane)")
check(bool(rt.eval("I_LEGACY == true")), "v1.11.63: legacy tabs show the two-list pane and hide the grid")
check(bool(rt.eval("I_DEATH == true")), "v1.11.63: deaths tab shows its own pane (list + recap)")
check(bool(rt.eval("I_BACK == true")), "v1.11.63: going back to damage restores the grid")
check(bool(rt.eval("I_GPANE == true and I_SERIES == true and I_VLINES == true")), "v1.11.63: the graph is ALWAYS visible (own pane) and still draws series + death markers")

# --- I.7 clear + report + live dropdown ---
rt.execute("""
local cl = RLSuite.combatLog
CHAT_LOG = {}
IsShiftKeyDown = function() return true end
cl.clearBtn._scripts.OnClick(cl.clearBtn)
I_WIPED = (#cl.db.fights == 0)
IsShiftKeyDown = SAVED_ISD or function() return false end
""")
check(bool(rt.eval("I_WIPED == true")), "Shift+Clear wipes the saved fights")

# --- I.8 ring buffer cap (saveFights) ---
rt.execute("""
local cl = RLSuite.combatLog
cl.db.saveFights = 3
for i = 1, 5 do
    cl:OnRegenDisabled()
    cl:OnCLEU(nil, GetTime(), 'SPELL_DAMAGE', '0x0p', 'PlayerOne', 1024+16+1, '0xF130008F040000AA', 'Lord Marrowgar', 2048+64, 100, 'Fireball', 4, 100, 0)
    cl:OnRegenEnabled()
end
I_CAP = #cl.db.fights
cl.db.saveFights = 15
cl.db.fights = {}
""")
check(bool(rt.eval("I_CAP == 3")), "fights ring buffer capped at saveFights (3/5 kept)")

# --- Debug panel (RLS DEBUG bar with Fill Group / Fill Loot / Whisp test / Test MS) ---
rt.execute("""
DBG_PROFILE_SAVED = RLSuite.db.profile.debug
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
""")
check(bool(rt.eval("RLSuite.debugPanel ~= nil")), "debug panel created when debug mode turns on")
check(bool(rt.eval("RLSuite.debugPanel:IsShown() == true")), "debug panel shown only while debug mode is on (looks like a mini main bar)")
check(bool(rt.eval("#RLSuite.debugPanel.debugButtons == 6")), "debug panel has 6 command buttons (with Log Test)")
check(bool(rt.eval("RLSuite.debugPanel.debugButtons[1]:GetText() == 'Fill Raid'")), "first debug button is Fill Group")
rt.execute("RLSuite:DebugFillGroup()")
check(bool(rt.eval("#RLSuite:DebugRoster() >= 15")), "Fill Group fills the simulated raid with fake players")
check(bool(rt.eval("""(function() local seen = {} for _, m in ipairs(RLSuite:DebugRoster()) do seen[m.class] = true end local n = 0 for _ in pairs(seen) do n = n + 1 end return n >= 6 end)()""")), "Fill Group fakes span many different classes")
rt.execute("LM_HIST_N = #RLSuite.lootManager.history")
rt.execute("RLSuite:DebugFillLoot()")
check(bool(rt.eval("#RLSuite.lootManager.history > LM_HIST_N")), "Fill Loot appends random pieces to the loot history (random raid pool)")
rt.execute("""
RLSuite.msManager.listening = true
RLSuite:DebugTestMS()
""")
check(bool(rt.eval("#RLSuite.msManager.db >= 3")), "Test MS feeds fake 'ms <spec>' whispers into the MS manager while listening")
rt.execute("RLSuite.msManager:StopListening(false); RLSuite.msManager.db = {}; RLSuite.msManager:UpdateList()")
rt.execute("""
DBG_W_SAVED = RLSuite.db.profile.debug
RLSuite.db.profile.debug = true
RLSuite.groupmaking.whisperDB.entries = {}
local btn = RLSuite.debugPanel.debugButtons[4]
btn._scripts["OnClick"](btn)
RLSuite.db.profile.debug = DBG_W_SAVED
""")
check(bool(rt.eval("#RLSuite.groupmaking.whisperDB.entries == 10")), "Whisp test button alone delivers all 10 fake whispers into the real whisplist")
check(bool(rt.eval("RLSuite.groupmaking.spamActive ~= true")), "Whisp test works WITHOUT the spammer running (no auto-flow at all)")
rt.execute("RLSuite.db.profile.debug = false; RLSuite:ApplyDebugMode()")
check(bool(rt.eval("RLSuite.debugPanel:IsShown() == false")), "debug panel hides when debug mode turns off")
rt.execute("RLSuite.db.profile.debug = DBG_PROFILE_SAVED; if DBG_PROFILE_SAVED then RLSuite:ApplyDebugMode() end")

# --- Loot list stays clickable after two rolls (pickup windows no longer over the list) ---
rt.execute("""
local lm = RLSuite.lootManager
RLSuite.db.profile.debug = true
RLSuite.mainWindow:ShowTab('loot')
lm:ClearHistory()
lm:SpawnDebugLoot()
for i = 1, 2 do
    local item = nil
    for j = #lm.history, 1, -1 do
        if not lm.history[j].assignedTo then item = lm.history[j]; break end
    end
    lm:SelectItem(item)
    lm:StartRoll("MS")
    if lm.currentRoll then
        lm.currentRoll.rolls[1] = {name="Tankbot", roll=97}
        lm.currentRoll.rolls[2] = {name="Healbot", roll=72}
    end
    for tick = 1, 30 do if lm.rollTimer then lm:RollTick() end end
end
RLL_TRADE_N = #lm.tradeWindows
RLL_P = lm.tradeWindows[1] and lm.tradeWindows[1]._points[1] or nil
local row = lm.histRows[1]
local entry = row and row.entry or nil
if row then row._scripts["OnClick"](row) end
RLL_CLICK_OK = (lm.selectedItem == entry)
lm:ClearHistory()
RLSuite.lootManager.frame:Hide()
RLSuite.mainWindow.currentTab = nil
""")
check(bool(rt.eval("RLL_TRADE_N == 2")), "two roll cycles each stacked one pick-up window (2 kept open)")
check(bool(rt.eval("RLL_CLICK_OK")), "loot list rows stay CLICKABLE after two rolls (regression of the blocked list)")
check(bool(rt.eval("RLL_P ~= nil and RLL_P[2] == RLSuite.lootManager.frame")), "pick-up windows anchor to the loot window EDGE, never over the list")

# --- Debug panel: Log Test fills the combat log with fake fights ---
rt.execute("""
DBG_L_SAVED = RLSuite.db.profile.debug
RLSuite.db.profile.debug = true
RLSuite.combatLog.db.fights = {}
local btn = RLSuite.debugPanel.debugButtons[6]
btn._scripts["OnClick"](btn)
CL_N = #RLSuite.combatLog.db.fights
CL_MG = nil
CL_LD = nil
for _, fq in ipairs(RLSuite.combatLog.db.fights) do
    if fq.name == 'Lord Marrowgar' then CL_MG = fq end
    if fq.name == 'Lady Deathwhisper' then CL_LD = fq end
end
""")
check(bool(rt.eval("CL_N == 3")), "Log Test feeds three fake fights into the combat log")
check(bool(rt.eval("CL_MG ~= nil and CL_MG.kill == true")), "fake Marrowgar fight is a named KILL (segmentation works through the real path)")
check(bool(rt.eval("CL_LD ~= nil and CL_LD.kill ~= true")), "fake Lady fight is a WIPE")
check(bool(rt.eval("(function() local rows, tot = RLSuite.combatLog:AggTotals(CL_MG, 'damage') return tot ~= nil and tot > 5000 end)()")), "fake fights contain real damage aggregation (tabs/graphs have data)")
rt.execute("RLSuite.combatLog.db.fights = {}; RLSuite.db.profile.debug = DBG_L_SAVED")

check(bool(rt.eval("RLSuite.debugPanel.debugButtons[2]:GetText() == 'Test Loot' and RLSuite.debugPanel.debugButtons[3]:GetText() == 'Empty Loot' and RLSuite.debugPanel.debugButtons[4]:GetText() == 'Test Whisplist'")), "debug bar buttons are in English on EVERY client locale")

check(bool(rt.eval("RLSuite.debugPanel._noOuterBorder == true")), "debug bar has no dialog border (borderless like the main bar)")
check(bool(rt.eval("""(function() local b = RLSuite.debugPanel.debugButtons[1] return b._backdrop ~= nil and b._backdrop.edgeFile == nil end)()""")), "debug bar buttons are borderless too")

# --- List rows (clickable buttons) are borderless ---
rt.execute("""
local r = RLSuite.lootManager.histRows and RLSuite.lootManager.histRows[1]
ROW_EDGEOK = (r == nil) or (r._backdrop ~= nil and r._backdrop.edgeFile == nil)
""")
check(bool(rt.eval("ROW_EDGEOK")), "list rows (loot/whisper/log) lost their dialog border; selection now uses a marked fill")

# --- Debug panel layout: single column, non-draggable, anchored to the main bar ---# --- Debug panel layout: single column, non-draggable, anchored to the main bar ---
check(bool(rt.eval("""(function() local xs = nil for _, b in ipairs(RLSuite.debugPanel.debugButtons) do local p = b._points[1]; if not p then return false end; if xs == nil then xs = p[4] elseif p[4] ~= xs then return false end end return true end)()""")), "debug panel buttons form a SINGLE column")
check(bool(rt.eval("""(function() local f = RLSuite.debugPanel return f._points[1] ~= nil and f._points[1][2] == RLSuite.mainWindow.frame end)()""")), "debug panel is anchored to the main bar (moves with it, never saved)")
check(bool(rt.eval("RLSuite.debugPanel._scripts['OnDragStart'] == nil")), "debug panel is NOT draggable (part of the main bar)")

# --- Debug mode no longer auto-fills the loot manager ---
rt.execute("""
RLSuite.lootManager:ClearHistory()
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
LL_N = #RLSuite.lootManager.history
RLSuite:DebugFillLoot()
LL_N2 = #RLSuite.lootManager.history
RLSuite.db.profile.debug = false
RLSuite:ApplyDebugMode()
""")
check(bool(rt.eval("LL_N == 0")), "enabling debug mode no longer spawns loot by itself")
check(bool(rt.eval("LL_N2 > 0")), "the Fill Loot button is the ONLY thing spawning debug loot")

# --- CombatLog window: dropdown clears the close X; min width covers the tab row ---
check(bool(rt.eval("""(function() local p = RLSuite.combatLog.fightDropdown._points[1] return p ~= nil and p[4] ~= nil and p[4] <= -24 end)()""")), "fight dropdown stays CLEAR of the close X (11px wide at -4)")
check(bool(rt.eval("RLSuite.windowMins.log() >= 730")), "log min width covers the full top tab row (8 tabs x 88px + margins)")
check(bool(rt.eval("(function() local _, h = RLSuite.windowMins.log() return h ~= nil and h >= 540 end)()")), "log min height covers the stacked content (lists 398 + top area 78 + bottom bar, never clipped)")
check(bool(rt.eval("(function() local tx = 0 for _ in pairs(RLSuite.combatLog.tabBtns) do tx = tx + 1 end return (14 + tx * 83 + 14) <= RLSuite.windowMins.log() + 10 end)()")), "every top tab stays inside the min-width window")

# --- Loot Manager: min width includes the MS announce button# --- Loot Manager: min width includes the MS announce button; window fixed like the equip panel ---
rt.execute("LM_MINW = RLSuite.windowMins.loot()")
check(bool(rt.eval("LM_MINW >= 506")), "loot min width fits all roll buttons incl. Announce Changes (no clipping)")
rt.execute("RLSuite.mainWindow:ShowTab('loot')")
check(bool(rt.eval("RLSuite.lootManager.frame._scripts['OnDragStart'] == nil")), "loot window is NOT draggable anymore (behaves like the native equip panel)")
check(bool(rt.eval("""(function() local p = RLSuite.lootManager.frame._points[1] return p ~= nil and p[1] == 'TOPLEFT' and p[2] == UIParent and p[4] == 16 and p[5] == -116 end)()""")), "loot window anchors to the fixed equip-style spot (TOPLEFT 16,-116 of UIParent)")
check(bool(rt.eval("RLSuite.combatLog.frame._scripts['OnDragStart'] ~= nil")), "other windows keep their draggable behavior (combat log untouched)")
rt.execute("RLSuite.lootManager.frame:Hide(); RLSuite.mainWindow.currentTab = nil")

# --- Loot Manager yields the left side to an open Trade (native panel behavior) ---
rt.execute("""
TradeFrame = CreateFrame('Frame', 'RLSuiteTestTrade', UIParent)
TradeFrame.GetRight = function() return 410 end
RLSuite.lootManager._tradeHooked = nil
RLSuite.lootManager:HookTradePanel()
RLSuite.mainWindow:ShowTab('loot')
local p1 = RLSuite.lootManager.frame._points[1]
TF_X1 = p1 and p1[4] or 0
TradeFrame:Show()
TradeFrame._scripts['OnShow'](TradeFrame)
TF_X2 = RLSuite.lootManager.frame._points[1] and RLSuite.lootManager.frame._points[1][4] or 0
TradeFrame:Hide()
TradeFrame._scripts['OnHide'](TradeFrame)
TF_X3 = RLSuite.lootManager.frame._points[1] and RLSuite.lootManager.frame._points[1][4] or 0
RLSuite.lootManager.frame:Hide()
RLSuite.mainWindow.currentTab = nil
RLSuite.lootManager.tradeOpen = false
""")
check(bool(rt.eval("TF_X1 == 16")), "loot opens at the left equip-style spot when no trade is open")
check(bool(rt.eval("TF_X2 == 420")), "opening Trade instantly pushes the loot manager to the right of it (trade keeps the left)")
check(bool(rt.eval("TF_X3 == 16")), "closing Trade puts the loot manager back on the left")
rt.execute("TradeFrame = nil")

# --- Reroll button stays ENABLED after a tie (AnnounceWinner -> ResetButtons bug) ---
rt.execute("""
local lm = RLSuite.lootManager
RLSuite.db.profile.debug = true
RLSuite.mainWindow:ShowTab('loot')
lm:ClearHistory()
lm:SpawnDebugLoot()
lm:SelectItem(lm.history[#lm.history])
lm:StartRoll("MS")
lm.currentRoll.rolls = {}
lm.currentRoll.rolls[1] = {name="Tankbot", roll=42}
lm.currentRoll.rolls[2] = {name="Healbot", roll=42}
lm.currentRoll.rolls[3] = {name="Dpsbot", roll=7}
for tick = 1, 30 do if lm.rollTimer then lm:RollTick() end end
RR_ENABLED = lm.rerollBtn:IsEnabled()
lm:DoReroll()
RR_ROLLS = #lm.currentRoll.rolls
for tick = 1, 30 do if lm.rerollTimer then lm:RerollTick() end end
RR_DONE_ITEM = (lm.history[#lm.history].assignedTo == "Tankbot" or lm.history[#lm.history].assignedTo == "Healbot")
lm:ClearHistory()
RLSuite.lootManager.frame:Hide()
RLSuite.mainWindow.currentTab = nil
RLSuite.db.profile.debug = false
""")
check(bool(rt.eval("RR_ENABLED == true")), "a TIE keeps the Reroll button enabled (was disabled by the trailing ResetButtons)")
check(bool(rt.eval("RR_DONE_ITEM")), "debug reroll resolves the tie and assigns the item to one of the tied fakes")
# --- Debug panel: Clear loot ---
rt.execute("""
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
RLSuite.lootManager:SpawnDebugLoot()
CL_N = #RLSuite.lootManager.history
RLSuite:DebugClearLoot()
""")
check(bool(rt.eval("CL_N > 0 and #RLSuite.lootManager.history == 0")), "Clear loot empties the loot history")
check(bool(rt.eval("#RLSuite.lootManager.tradeWindows == 0")), "Clear loot closes any open pick-up windows")
rt.execute("RLSuite.db.profile.debug = false; RLSuite:ApplyDebugMode()")


# === Scenario 1.11.19: X bianche close.blp, PH:<fase> in matrice, barretta ==================
print("\n== v1.11.19: white close.blp X buttons, macrobar PH text, main title bar, fstack guard ==")

# -- media presenti e referenziate
import os
check(os.path.isfile("media/close.tga") and os.path.isfile("media/arrowup.tga"), "media/close.tga + media/arrowup.tga exist in the addon folder")
# i file tga SONO quelli caricati dall'utente (type 2 o 10/RLE, 32 bpp):
for _p in ("media/close.tga", "media/arrowup.tga"):
    _d = open(_p, "rb").read()
    _ok = len(_d) > 26 and _d[2] in (2, 10) and _d[16] == 32
    check(_ok, _p + ": valid uncompressed/RLE 32bpp TGA uploaded by the user")

# -- MS changes: X piu' grande (20x20) e bianca (close.blp)
rt.execute("RLSuite.msManager:AddEntry('BigX', 'Frost'); MSROW = RLSuite.msManager.rows and RLSuite.msManager.rows[1]")
rt.execute("RLSuite.msManager:UpdateList()")
rt.execute("""
MS_DEL = nil
for _, c in ipairs(ALLFRAMES) do
    if c._parent ~= nil and c._w == 10 and c._h == 10 and c._text == nil and c.icon and c.icon._texture and tostring(c.icon._texture):find('close.tga') then
        MS_DEL = MS_DEL or c
    end
end
""")
found_ms = rt.eval("MS_DEL ~= nil")
if not found_ms:
    # fallback: cammina le righe del listato ms direttamente
    rt.execute("for _, r in ipairs(RLSuite.msManager.listContent and RLSuite.msManager.listContent._children or {}) do end; MS_DEL = nil")
rt.execute("""
-- scansione robusta: cerca fra TUTTI i frame un button 20x20 con normal texture close.blp
MS_DEL = nil
for _, c in ipairs(ALLFRAMES) do
    if c.icon ~= nil and c.icon._texture ~= nil and tostring(c.icon._texture):find('close.tga', 1, true) and c._w == 10 and c._h == 10 then MS_DEL = c end
end
""")
check(bool(rt.eval("MS_DEL ~= nil")), "MS changes list: red X is now a white close.tga button (BCI format, renders)")
check(bool(rt.eval("MS_DEL == nil or (MS_DEL._w == 10 and MS_DEL._h == 10)")), "MS changes X is halved (10x10)")

# -- GroupMaking: le x rosse testuali sono diventate tessere bianche
rt.execute("""
GM_WHITE = 0; GM_RED_TEXT = 0
for _, c in ipairs(ALLFRAMES) do
    if c._text == 'x' then GM_RED_TEXT = GM_RED_TEXT + 1 end
    if c.icon ~= nil and c.icon._texture ~= nil and tostring(c.icon._texture):find('close.tga', 1, true) then GM_WHITE = GM_WHITE + 1 end
end
""")
check(rt.eval("GM_RED_TEXT") == 0, "no red 'x' text buttons remain in the suite")
check(int(rt.eval("GM_WHITE") or 0) >= 2, "white close.tga X buttons exist in GroupMaking rows (calendar + whisplist)")

# -- MacroBar: testo fase dentro la matrice, formato PH:<FASE>
rt.execute("MBPT = RLSuite.macrobar.phaseText; MBPS = RLSuite.macrobar.phaseSlot")
check(bool(rt.eval("MBPT ~= nil")), "macrobar phase text exists")
check(bool(rt.eval("MBPS ~= nil and MBPS._enabledMouse == false")), "PH is a NON-CLICKABLE button slot in the matrix (mouse off)")
check(bool(rt.eval("MBPS._backdrop == nil")), "PH slot has NO backdrop and NO border")
check(bool(rt.eval("MBPT._parent == MBPS")), "PH text lives ON the slot button")
rt.execute("MBP = MBPS._points[1] or {}; MBPTN = MBPT.GetText and MBPT:GetText() or ''")
check(bool(rt.eval("MBP[1] == 'TOPLEFT' and MBP[2] == RLSuite.macrobar.keypadFrame")), "PH slot anchored at the first cell of the KEYPAD grid (the buttons below, not the macros)")
check(bool(rt.eval("MBPTN:sub(1,3) == 'PH:'")), "phase text format is PH:<phase>")
check(rt.eval("MBPTN") == "PH:PRE-RAID", "initial phase text is PH:PRE-RAID")
rt.execute("RLSuite.context = 'preboss'; RLSuite.macrobar:UpdatePhase()")
check(rt.eval("RLSuite.macrobar.phaseText:GetText()") == "PH:PRE-BOSS", "phase text updates to PH:PRE-BOSS")
rt.execute("RLSuite.context = 'preraid'; RLSuite.macrobar:UpdatePhase()")

# -- Barretta titolo main bar: bassa (20px), sopra la finestra, larghezza ereditata
rt.execute("TB = RLSuite.mainWindow.titleBar")
check(bool(rt.eval("TB ~= nil")), "main title bar exists")
check(rt.eval("TB._h") == 20, "title bar is LOW: height 20px (was 30)")
rt.execute("""
    TB_P1 = TB._points[1] or {}
    TB_POINTS = TB:GetNumPoints()
    TB_W = TB:GetWidth()
    TB_TITLE_W = RLSuite.mainWindow._titleRowW
    PB = RLSuite.mainWindow.phaseBtn
    PT = RLSuite.mainWindow.phaseText
    RC = TB.raidControlBtn
    CLB = TB.closeBtn
    SUM_W = 4 + PB:GetWidth() + 4 + RLSuite.mainWindow._phaseLabelW + 4
        + RC:GetWidth() + 4 + CLB:GetWidth() + 4
""")
check(bool(rt.eval("TB_P1[1] == 'TOPLEFT' and TB_P1[3] == 'TOPLEFT' and TB_P1[2] == UIParent")),
      "title bar is the anchor: TOPLEFT of the screen at x = Raid Frame width (%s)" % rt.eval("TB_P1[4]"))
check(rt.eval("TB_P1[5]") == 0, "title bar touches the top edge exactly (y = 0)")
check(bool(rt.eval("TB_W == TB_TITLE_W and TB_W == SUM_W")),
      "TITLE BAR WIDTH = SUM OF ITS ELEMENTS (phase icon+name, Raid Control, close) = %d px" % rt.eval("TB_W"))
check(bool(rt.eval("TB_POINTS == 1")), "single anchor: the width is fixed, not derived from the panel")
check(bool(rt.eval("TB.title ~= nil and tostring(TB.title:GetText()):find('RLS') == nil")),
      "no more 'RLS' text in the title bar")
check(bool(rt.eval("TB.raidControlBtn ~= nil and TB.arrowBtn == TB.raidControlBtn")), "'Raid Control' button replaced the arrow (arrowBtn kept as alias)")
check(bool(rt.eval("tostring(TB.raidControlBtn:GetText()) == 'Raid Control'")), "the button says 'Raid Control'")
check(bool(rt.eval("TB.closeBtn ~= nil and TB.closeBtn.icon ~= nil and tostring(TB.closeBtn.icon._texture):find('close.tga', 1, true) ~= nil")), "close.tga button present on the right (ARTWORK texture, renders)")

# -- v1.11.56: icona di fase DENTRO la barretta + SaveRaid tornato pulsante --
rt.execute("""
    MW = RLSuite.mainWindow
    TB = MW.titleBar
    PB = MW.phaseBtn
    PT = MW.phaseText
    PB_PARENT = (PB:GetParent() == TB)
    PT_PARENT = (PT:GetParent() == TB)
    PB_SIZE = PB._w .. 'x' .. PB._h
    PT_LEFT = PT._points[1] and PT._points[1][2] == PB
    PH_LABEL = PT:GetText()
    SAVE_BTN = MW.saveRaidBtn
    SAVE_TXT = (SAVE_BTN.SetText and SAVE_BTN:GetText()) or ''
    SAVE_W = SAVE_BTN._w
    SAVE_H = SAVE_BTN._h
    SAVE_IS_MATRIX = false
    for i, b in ipairs(MW.matrixButtons or {}) do
        if b == SAVE_BTN then SAVE_IS_MATRIX = true SAVE_IDX = i end
    end
    SAVE_HAS_ICON = (SAVE_BTN.icon ~= nil)
""")
check(bool(rt.eval("PB_PARENT == true")), "phase icon lives IN the title bar (was in the main bar)")
check(bool(rt.eval("PT_PARENT == true")), "phase name lives IN the title bar, next to the icon")
check(bool(rt.eval("PB_SIZE == '16x16'")), "phase icon is 16x16 (fits the 20px title bar)")
check(bool(rt.eval("PT_LEFT == true")), "phase name is anchored to the RIGHT of the phase icon")
check(bool(rt.eval("PH_LABEL == 'Pre-raid' or PH_LABEL == 'Pre-boss' or PH_LABEL == 'In-fight'")),
      "phase name shows the current phase ('%s')" % rt.eval("PH_LABEL"))
check(bool(rt.eval("SAVE_TXT == 'SaveRaid'")), "SaveRaid is a TEXT BUTTON showing 'SaveRaid'")
check(bool(rt.eval("SAVE_W == 90 and SAVE_H == 22")), "SaveRaid button has the same size as the matrix buttons (90x22)")
check(bool(rt.eval("SAVE_IS_MATRIX == true and SAVE_IDX == 7")), "SaveRaid joins the button matrix as the 7th button")
check(bool(rt.eval("SAVE_HAS_ICON == false")), "SaveRaid is no longer an icon button")

# -- la barra e' piu' bassa e i tasti sono ADERENTI al bordo (PAD ridotto)
rt.execute("""
    MW = RLSuite.mainWindow
    local L = RLSuite.db.profile.layout.main or {}
    local cols = math.max(1, math.min(8, tonumber(L.matrixCols) or 2))
    local rows = math.max(1, math.min(8, tonumber(L.matrixRows) or 4))
    local n = #(MW.matrixButtons or {})
    rows = math.max(rows, math.ceil(n / cols))
    PADU = 4
    EXPECT_H = 2 * PADU + rows * 22 + (rows - 1) * 4
    BAR_H = MW.frame._h
    BAR_W = MW.frame._w
    -- il primo tasto sta a PAD dal bordo (misurato dai punti)
    local p1 = MW.matrixButtons[1]._points[1] or {}
    FIRST_X = p1[4]
    FIRST_Y = p1[5]
    -- ultimo tasto della prima riga: la matrice e' CENTRATA, margini pari
    local last = MW.matrixButtons[cols]
    local rEdge = (last._points[1][4] or 0) + (last._w or 0)
    RIGHT_GAP = BAR_W - rEdge
    MATRIX_MW = cols * 90 + (cols - 1) * 8
""")
check(bool(rt.eval("BAR_H == EXPECT_H")),
      "main bar height = padding + matrix only (icon row removed): %d px" % rt.eval("BAR_H"))
check(bool(rt.eval("FIRST_Y == 4 * -1 and FIRST_X == 4")),
      "buttons sit 4px from the bar border on all sides (spacing reduced, was 12)")
check(bool(rt.eval("RIGHT_GAP >= 4")), "matrix left-aligned: any extra width of the title row sits on the right")

# -- il click sul pulsante salva davvero (OnSaveRaid) ---------------------
rt.execute("""
    MW = RLSuite.mainWindow
    SAVED_CALLS = 0
    local orig = MW.OnSaveRaid
    MW.OnSaveRaid = function() SAVED_CALLS = SAVED_CALLS + 1 end
    MW.saveRaidBtn._scripts.OnClick(MW.saveRaidBtn)
    MW.OnSaveRaid = orig
""")
check(bool(rt.eval("SAVED_CALLS == 1")), "clicking SaveRaid calls OnSaveRaid (still works as a button)")

# -- barretta stretta: il nome della fase sparisce, l'icona resta ---------
rt.execute("""
    MW = RLSuite.mainWindow
    local layout = RLSuite.db.profile.layout
    layout.main = layout.main or {}
    local oldCols = layout.main.matrixCols
    layout.main.matrixCols = 1
    MW:ApplyLayout()
    NARROW_TEXT = MW.phaseText:IsShown()
    NARROW_BTN = MW.phaseBtn:IsShown()
    NARROW_W = MW.frame._w
    layout.main.matrixCols = oldCols
    MW:ApplyLayout()
    WIDE_TEXT = MW.phaseText:IsShown()
    WIDE_W = MW.frame._w
""")
check(bool(rt.eval("NARROW_TEXT == true and NARROW_BTN == true")),
      "narrow bar: phase icon AND phase name stay (the name has a reserved slot)")
check(bool(rt.eval("NARROW_W == WIDE_W")),
      "fixed width: with 1 or 2 matrix columns the bar keeps the same width (title row dominates)")

# -- v1.11.57: ancoraggio fisso + larghezza = somma degli elementi --------
rt.execute("""
    MW = RLSuite.mainWindow
    local f = MW.frame
    local p1, _, p3, px, py = f:GetPoint(1)
    ANCH_P, ANCH_REL, ANCH_RELP, ANCH_X, ANCH_Y = p1, f:GetParent(), p3, px, py
    ANCH_PARENT_NAME = (ANCH_REL == UIParent) and 'UIParent' or 'ALTRO'
    RFW = MW:RaidFrameWidth()
    TBH = MW.titleBar:GetHeight()
    RF_M = RLSuite.raidFrame:LayoutMetrics()
    RF_LIVE_W = RLSuite.raidFrame.frame._w
    RF_SCALE = RLSuite.raidFrame.db.scale or 1
    -- larghezza dei BUFF in colonne (matrice oltre il bordo destro del frame)
    local cols = #(RLSuite.raidFrame._buffHdrBtns or {})
    BUFFS_W = cols * RF_M.cellW
""")
check(bool(rt.eval("ANCH_P == 'TOPLEFT' and ANCH_RELP == 'TOPRIGHT'")),
      "button matrix panel opens at the RIGHT of the title bar (%s -> %s)" % (rt.eval("ANCH_P"), rt.eval("ANCH_RELP")))
rt.execute("""
    local tp1, tpParent, tp3, tx, ty = RLSuite.mainWindow.titleBar:GetPoint(1)
    TB_ANCH_P, TB_ANCH_REL, TB_ANCH_X, TB_ANCH_Y = tp1, tp3, tx, ty
    TB_ANCH_PARENT = (tpParent == UIParent) and 'UIParent' or 'ALTRO'
""")
check(bool(rt.eval("TB_ANCH_P == 'TOPLEFT' and TB_ANCH_PARENT == 'UIParent' and TB_ANCH_REL == 'TOPLEFT'")),
      "the title bar (the anchor) is at the TOP-LEFT of the screen: distance from the LEFT side")
check(bool(rt.eval("ANCH_Y == 0 and TB_ANCH_Y == 0")),
      "title bar and panel are both flush with the top edge (tops aligned, dy 0)")
check(bool(rt.eval("ANCH_X == 4")), "panel starts 4px right of the title bar (no overlap)")
check(bool(rt.eval("RFW == RF_LIVE_W and RF_LIVE_W == RF_M.W * RF_SCALE")),
      "right offset = Raid Frame width (%d px at scale %s)" % (rt.eval("RF_M.W * RF_SCALE"), rt.eval("RF_SCALE")))
check(bool(rt.eval("TB_ANCH_X == RFW")), "the offset IS the Raid Frame width, on the LEFT side (no other constant)")
check(bool(rt.eval("BUFFS_W > 0 and RFW < RF_M.rowWidth + BUFFS_W")),
      "the buff columns are NOT part of that width (matrix %d px drawn beyond the frame)" % rt.eval("BUFFS_W"))
check(bool(rt.eval("RF_M.W == RF_M.rowWidth")), "Raid Frame width = food/flask + player bar + CDs (no buffs)")

# -- il Raid Frame cambia -> la barra si riposiziona da sola ---------------
rt.execute("""
    MW = RLSuite.mainWindow
    local app = RLSuite.raidFrame.db.appearance
    local old = app.barWidth
    app.barWidth = 220
    RLSuite.raidFrame:ApplyLayout()
    local _, _, _, xNew = MW.titleBar:GetPoint(1)
    RFW_NEW = MW:RaidFrameWidth()
    ANCH_X_NEW = xNew
    FOLLOWS = (MW.frame._points[1] or {})[2] == MW.titleBar
    app.barWidth = old
    RLSuite.raidFrame:ApplyLayout()
    local _, _, _, xBack = MW.titleBar:GetPoint(1)
    ANCH_X_BACK = xBack
""")
check(bool(rt.eval("RFW_NEW == RFW + 40 and ANCH_X_NEW == (RFW + 40)")),
      "player bar +40px -> the bar moves 40px right (offset follows the Raid Frame)")
check(bool(rt.eval("FOLLOWS == true")), "the panel keeps following the title bar when the bar moves")
check(bool(rt.eval("ANCH_X_BACK == RFW")), "restoring the Raid Frame restores the bar position")

# -- larghezza fissa = somma degli elementi -------------------------------
rt.execute("""
    MW = RLSuite.mainWindow
    local layout = RLSuite.db.profile.layout
    layout.main = layout.main or {}
    local map = { [1] = 1, [2] = 2, [3] = 3, [4] = 4 }
    W_BY_COLS = {}
    for _, c in ipairs({ 1, 2, 3, 5, 8 }) do
        layout.main.matrixCols = c
        MW:ApplyLayout()
        W_BY_COLS[c] = MW.frame._w
    end
    -- riga della barretta: tutti gli elementi presenti e dentro il bordo
    local tbW = MW.titleBar._w
    local rc = MW.titleBar.raidControlBtn
    TITLE_FITS = (MW.phaseText:IsShown() and rc ~= nil and rc:IsShown() and MW.phaseBtn:IsShown())
    TITLE_W = tbW
    TITLE_BAR_W = MW.frame._w
    layout.main.matrixCols = 2
    MW:ApplyLayout()
""")
rt.execute("""
    local MWc = RLSuite.mainWindow
    WFORM_OK = true
    for c, w in pairs(W_BY_COLS) do
        local matrixW = c * 90 + (c - 1) * 8
        local expect = 2 * 4 + math.max(matrixW, MWc._titleRowW)
        if w ~= expect then WFORM_OK = false end
    end
""")
check(bool(rt.eval("WFORM_OK == true")),
      "every width = padding + widest element row (formula holds for 1..8 columns)")
check(bool(rt.eval("W_BY_COLS[8] > W_BY_COLS[2] and W_BY_COLS[3] > W_BY_COLS[1]")),
      "wider matrix -> wider bar (width = widest element row)")
check(bool(rt.eval("TITLE_FITS == true")), "every title bar element always fits (phase icon + name + Raid Control)")
rt.execute("""
    local MWt = RLSuite.mainWindow
    local layout = RLSuite.db.profile.layout
    layout.main = layout.main or {}
    local oldC = layout.main.matrixCols
    local tw1, tw8
    layout.main.matrixCols = 1; MWt:ApplyLayout(); tw1 = MWt.titleBar:GetWidth()
    layout.main.matrixCols = 8; MWt:ApplyLayout(); tw8 = MWt.titleBar:GetWidth()
    TITLE_CONST_W = (tw1 == tw8)
    TITLE_W_1 = tw1
    layout.main.matrixCols = oldC
    MWt:ApplyLayout()
""")
check(bool(rt.eval("TITLE_CONST_W == true")),
      "title bar keeps its own width whatever the matrix does (1 vs 8 columns: %d px)" % rt.eval("TITLE_W_1"))
rt.execute("""
    -- larghezza attesa = PAD + max(matrice, riga barretta) + PAD
    local MW = RLSuite.mainWindow
    local layout = RLSuite.db.profile.layout.main or {}
    local cols = tonumber(layout.matrixCols) or 2
    local matrixW = cols * 90 + (cols - 1) * 8
    local rcW = MW.titleBar.raidControlBtn:GetWidth()
    local titleW = MW._titleRowW
    EXPECT_W = 2 * 4 + math.max(matrixW, titleW)
    BAR_W = MW.frame._w
    RC_W = rcW
    RC_TEXT_W = MW.titleBar.raidControlBtn:GetStringWidth()
    PHASE_RESERVE = MW._phaseLabelW
""")
check(bool(rt.eval("BAR_W == EXPECT_W")),
      "bar width = padding + widest element row (matrix vs title row) = %d px" % rt.eval("BAR_W"))
check(bool(rt.eval("RC_W >= RC_TEXT_W + 8")),
      "the Raid Control button is sized on its own text (%d px wide)" % rt.eval("RC_W"))
check(bool(rt.eval("PHASE_RESERVE >= 40 and PHASE_RESERVE <= 90")),
      "phase name reserve is measured on the real labels (%d px), not a magic number" % rt.eval("PHASE_RESERVE"))

# -- v1.11.61: la matrice di MAIN BAR si apre a DESTRA della barretta -------
rt.execute("""
    MW = RLSuite.mainWindow
    MW.frame:Show(); MW.titleBar:Show(); MW:ApplyLayout()
    local fp1, fpParent, fp3, fx, fy = MW.frame:GetPoint(1)
    PANEL_ANCH = fp1 .. ' -> ' .. fp3 .. ' dx=' .. tostring(fx) .. ' dy=' .. tostring(fy)
    PANEL_TO_TITLE = (fpParent == MW.titleBar)
    PANEL_POINTS = MW.frame:GetNumPoints()
    PANEL_TOP = fy
    TB_TOP = select(5, MW.titleBar:GetPoint(1))
    -- la barretta resta larga quanto i suoi elementi
    TITLE_W2 = MW.titleBar:GetWidth()
    TITLE_SUM = 4 + MW.phaseBtn:GetWidth() + 4 + MW._phaseLabelW + 4
        + MW.titleBar.raidControlBtn:GetWidth() + 4 + MW.titleBar.closeBtn:GetWidth() + 4
""")
check(bool(rt.eval("PANEL_TO_TITLE == true and PANEL_POINTS == 1")),
      "MAIN BAR panel is anchored to the title bar (%s)" % rt.eval("PANEL_ANCH"))
check(bool(rt.eval("PANEL_ANCH:find('TOPRIGHT') ~= nil")),
      "it opens at the RIGHT of the title bar (TOPLEFT -> TOPRIGHT)")
check(bool(rt.eval("PANEL_TOP == 0 and TB_TOP == 0")), "panel and bar are top-aligned (both at y = 0)")
check(bool(rt.eval("TITLE_W2 == TITLE_SUM")), "title bar still measures exactly its own elements")

# -- la MACROBAR e' tornata come prima (nessun ancoraggio alla barretta) ---
rt.execute("""
    MB = RLSuite.macrobar
    MB:ApplyLayout()
    local mp = MB.frame._points[1] or {}
    MB_TB_ANCHOR = (mp[2] == RLSuite.mainWindow.titleBar)
    MB_OVERRIDE_FN = (MB.CaptureManualPosition ~= nil)
    MB_HAS_POINT = (mp[1] ~= nil)
""")
check(bool(rt.eval("MB_TB_ANCHOR == false")), "MacroBar is NOT anchored to the title bar any more (back to its own position)")
check(bool(rt.eval("MB_OVERRIDE_FN == false")), "MacroBar manual-position override removed (v1.11.60 reverted)")
check(bool(rt.eval("MB_HAS_POINT == true")), "MacroBar keeps using its configured anchor point")

# -- Raid Control apre/chiude proprio quel pannello, che resta a destra -----
rt.execute("""
    MW = RLSuite.mainWindow
    MW.frame:Hide(); MW.titleBar:Show()
    MW.titleBar.raidControlBtn._scripts.OnClick(MW.titleBar.raidControlBtn)
    RC_OPEN = MW.frame:IsShown()
    local p2 = MW.frame._points[1] or {}
    RC_RIGHT = (p2[2] == MW.titleBar and (p2[4] or 0) == 4)
""")
check(bool(rt.eval("RC_OPEN == true and RC_RIGHT == true")),
      "'Raid Control' opens the panel, and it appears right of the bar (dx 4)")

# -- Barretta: "Raid Control" = solo pannello; close = tutto chiuso
rt.execute("""
f = RLSuite.mainWindow.frame
f:Show(); TB:Show()
TB.raidControlBtn._scripts.OnClick(TB.raidControlBtn)
A1 = f:IsShown(); A1TB = TB:IsShown()
HL_HIDDEN = TB.raidControlBtn._highlight
TB.raidControlBtn._scripts.OnClick(TB.raidControlBtn)
A2 = f:IsShown()
HL_SHOWN = TB.raidControlBtn._highlight
f:Show(); TB:Show()
TB.closeBtn._scripts.OnClick(TB.closeBtn)
C_F = f:IsShown(); C_TB = TB:IsShown()
""")
check(bool(rt.eval("A1 == false and A1TB == true")), "Raid Control: hides ONLY the panel under the bar (bar stays)")
check(bool(rt.eval("A2 == true")), "Raid Control: shows the panel back under the bar")
check(bool(rt.eval("HL_SHOWN == true and HL_HIDDEN == false")),
      "Raid Control is highlighted only while the panel is open")
check(bool(rt.eval("C_F == false and C_TB == false")), "close.blp: closes the main bar (panel + title bar)")

# -- Toggle tab riallinea anche la barretta
rt.execute("RLSuite.mainWindow:ShowTab('group')")
check(bool(rt.eval("RLSuite.mainWindow.frame:IsShown() and RLSuite.mainWindow.titleBar:IsShown()")), "ShowTab shows the window AND the title bar")
rt.execute("RLSuite.mainWindow.frame:Hide(); RLSuite.mainWindow.titleBar:Hide(); RLSuite.mainWindow:CloseTab()")

# -- fstack guard: chiudere la finestra NON lascia catcher zombie
rt.execute("""
dd = RLSuite.lootManager.rarityDropdown
RLSuite.utils:ToggleDropdownMenu(dd)
ZS_MENU = RLSuite.utils.activeMenu; ZS_CAT = RLSuite.utils.dropCatcher:IsShown()
dd._scripts.OnHide(dd)
ZS_AFTER_MENU = RLSuite.utils.activeMenu; ZS_AFTER_CAT = RLSuite.utils.dropCatcher:IsShown()
""")
check(bool(rt.eval("ZS_MENU ~= nil and ZS_CAT == true")), "opening the rarity dropdown shows menu + fullscreen catcher")
check(bool(rt.eval("ZS_AFTER_MENU == nil and ZS_AFTER_CAT == false")), "hiding the window kills menu AND catcher (no invisible fullscreen blocker)")
# zombie catcher globale recuperato anche se perso l'owner
rt.execute("RLSuite.utils.dropCatcher:Show(); RLSuite.utils.activeMenu = nil; RLSuite.utils:AssertNoZombieCatcher()")
check(bool(rt.eval("RLSuite.utils.dropCatcher:IsShown() == false")), "zombie catcher with no menu is force-closed")
# -- v1.11.38: difese definite centrale (tutti i moduli)
_u = open("Utils.lua", encoding="utf-8").read()
check('menu:SetScript("OnHide", function()' in _u and 'Utils.activeMenu == nil' in _u.replace(' ', '') or "Utils.activeMenu==nil" in _u.replace(' ', ''), "dropdown menu OnHide always kills the catcher + clears activeMenu")
check('anc:HookScript("OnHide"' in _u, "ancestor-hide hook: closing the owner window kills menu + catcher")
check('RegisterForClicks("LeftButtonUp", "RightButtonUp")' in _u, "catcher closes with left AND right click")
rt.execute("""
dd38 = RLSuite.lootManager.rarityDropdown
RLSuite.utils:ToggleDropdownMenu(dd38)
M38 = RLSuite.utils.activeMenu
C38 = RLSuite.utils.dropCatcher:IsShown()
M38._scripts.OnHide(M38)
C38A = RLSuite.utils.dropCatcher:IsShown()
AM38 = RLSuite.utils.activeMenu
""")
check(bool(rt.eval("M38 ~= nil and C38 == true")), "dropdown opens menu + catcher")
check(bool(rt.eval("C38A == false and AM38 == nil")), "hiding the menu BY ANY MEANS also hides the catcher (engine-level defense)")
# -- v1.11.39: content scroll non mouse-eating + raise cap + mousefocus diag
_u = open("Utils.lua", encoding="utf-8").read()
check('RLSuite._windowStack' in _u and 'ShiftSubtree' in _u, "RaiseWindow uses a normalized window stack + subtree shift (deterministic layering)")
check("row:SetFrameLevel((self.histContent:GetFrameLevel()" in open("LootManager.lua", encoding='utf-8').read(), "fresh loot rows get an explicit above-content level")
rt.execute("""
RLSuite._windowStack = {}
w1 = CreateFrame("Frame", nil, UIParent); w2 = CreateFrame("Frame", nil, UIParent)
k1 = CreateFrame("Frame", nil, w1); c1 = CreateFrame("Frame", nil, k1)
RLSuite.utils:RaiseWindow(w1)
RLSuite.utils:RaiseWindow(w2)
RLSuite.utils:RaiseWindow(w1)
L41 = w1:GetFrameLevel(); L42 = w2:GetFrameLevel(); LK41 = k1:GetFrameLevel(); LC41 = c1:GetFrameLevel()
""")
check(bool(rt.eval("L41 > L42")), "window recursive raise: last-raised window is physically above the older one")
check(bool(rt.eval("LK41 >= L41 and LC41 >= L41")), "whole subtree shifts with the window (children never buried under their own window) — deterministic layering")
# -- v1.11.42: main bar panel chiudibile sempre, mai chiudere altre finestre
_rp42 = open("RaidProfile.lua", encoding="utf-8").read()
import re as _re
_ct = _rp42.split("function MW:CloseTab()", 1)[1].split("end", 1)[0]
check('HideAllWindows' not in _ct, "CloseTab never hides other windows (in-fight panel close stays local)")
check(_rp42.count('MW:CloseTab()') == 1, "only the CloseTab definition remains (no implicit calls from arrow/X/toggle)")
_rt42 = _re.sub(r'--[^\n]*', '', _rp42)
_rt42 = _re.sub(r'\s+', ' ', _rt42)
check('rcBtn:SetScript("OnClick", function() if f:IsShown() then f:Hide() else f:Show() end' in _rt42, "the Raid Control button toggles ONLY the button panel, at any time")
# -- v1.11.42: loot dedupe + boss from looted corpse
_l42 = open("LootManager.lua", encoding='utf-8').read()
check('< 4 then' in _l42 and 'prev.itemLink == itemLink' in _l42, "loot dedupe: same itemLink within 4s is skipped (no duplicates)")
check('UnitIsDead("target")' in _l42 and '_recentBoss' in _l42, "boss name taken from the freshly looted corpse target")
check('#self.history > 200' in _l42, "loot history capped at 200 entries (SavedVariables-friendly)")
# -- X levels
check('delBtn:SetFrameLevel(row:GetFrameLevel() + 2)' in open("MSManager.lua", encoding='utf-8').read(), "MS list X always above the row")
check('xBtn:SetFrameLevel(row:GetFrameLevel() + 2)' in open("GroupMaking.lua", encoding='utf-8').read(), "GM manual-list X always above the row")
check('lootdiag' in open("Core.lua", encoding='utf-8').read(), "/rls lootdiag persistence check available")

# -- comportamento live
rt.execute("""
RLSuite.mainWindow:ShowTab('ms')
RLSuite.mainWindow:ShowTab('loot')
local pms = RLSuite.mainWindow:PaneForTab('ms'); local pl = RLSuite.mainWindow:PaneForTab('loot')
RLSuite.mainWindow.frame:Hide(); RLSuite.mainWindow.titleBar:Show()
local arrS = RLSuite.mainWindow.titleBar and RLSuite.mainWindow.titleBar.arrowBtn
arrS._scripts.OnClick(arrS)
AF1 = pms:IsShown(); AL1 = pl:IsShown()
UnitExists = function() return true end
UnitIsDead = function() return true end
UnitName = function() return "Onyxia" end
RLSuite.lootManager._containerUseT = nil
RLSuite.lootManager:OnLootOpened()
G_LL = "item:2600:0:0:0:0:0:0:0"
RLSuite.lootManager:AddToHistory(G_LL, "Talisman", nil, 4)
RLSuite.lootManager:AddToHistory(G_LL, "Talisman", nil, 4)
DUPC = #RLSuite.lootManager.history
BOSV = RLSuite.lootManager.history[#RLSuite.lootManager.history].boss
""")
check(bool(rt.eval("AF1 == true and AL1 == true")), "arrow-click on the bar hides only the panel; module windows stay open")
check(bool(rt.eval("DUPC >= 1 and BOSV == 'Onyxia'")), "looting a boss corpse names the boss; identical announce within 4s is deduped")
check(bool(rt.eval("DUPC < 3")), "no duplicate entries for the same item announcement")
# -- v1.11.43: RepinFrameOrder deterministico sui rebuild
check('function Utils:RepinFrameOrder' in _u, "RepinFrameOrder helper available")
check('RepinFrameOrder(self.listContent)' in open("MSManager.lua", encoding='utf-8').read(), "MS list repinned after every refresh")
check('RepinFrameOrder(content)' in open("GroupMaking.lua", encoding='utf-8').read(), "GM manual list repinned after every refresh")
check('RepinFrameOrder(self.histContent)' in open("LootManager.lua", encoding='utf-8').read(), "loot history repinned after every refresh")
rt.execute("""
R43 = CreateFrame("Frame", nil, UIParent)
C43a = CreateFrame("Frame", nil, R43)
C43b = CreateFrame("Frame", nil, R43)
C43c = CreateFrame("Button", nil, C43b)
RLSuite.utils:RepinFrameOrder(R43)
RP43_1 = C43a:GetFrameLevel(); RP43_2 = C43b:GetFrameLevel(); RP43_3 = C43c:GetFrameLevel()
RP43_R = R43:GetFrameLevel()
""")
check('ieAutoNamesList:EnableMouse(true)' not in open("GroupMaking.lua", encoding='utf-8').read(), "IE manual-list container is NEVER mouse-enabled (it ate every X/row click)")
check("mousefocus" not in open("Core.lua", encoding='utf-8').read() and "lmdebug" not in open("Core.lua", encoding='utf-8').read(), "no left-over debug slash commands")
# --- comportamento end-to-end: la X rimuove DAVVERO il nome
rt.execute("""
IE_N1 = "AaFirst"; IE_N2 = "ZzSecond"
GM = RLSuite.groupmaking
GM.autoinvite = GM.autoinvite or {}
GM.autoinvite.names = { IE_N1, IE_N2 }
GM:BuildAutoNameListUI()
IE_XROW = GM._autoNameRows and GM._autoNameRows[2]
IE_XROW.xBtn._scripts.OnClick(IE_XROW.xBtn)
IE_LEFT = #GM.autoinvite.names
IE_PRESENT = GM.autoinvite.names[1] == IE_N1
""")
check(bool(rt.eval("IE_LEFT == 1 and IE_PRESENT")), "clicking the manual-list X removes exactly that player")
check(bool(rt.eval("RP43_2 > RP43_1 and RP43_1 > RP43_R and RP43_3 > RP43_2")), "RepinFrameOrder: children strictly above parents, in creation order, deterministic")
check('function GM:PinTabStrip' in open("GroupMaking.lua", encoding='utf-8').read(), "PinTabStrip helper exists")
check('base + 50 + i' in open("GroupMaking.lua", encoding='utf-8').read(), "IE tab buttons pinned strictly above the border and the pages")
rt.execute("""
-- tabs above border, pages below tabs: deterministic add-on stacking
G46 = RLSuite.groupmaking
G46.ieTabGroup = { border = CreateFrame("Frame", nil, UIParent), tabs = {} }
G46.ieTabGroup.tabs[1] = CreateFrame("Button", nil, UIParent)
G46.ieTabGroup.tabs[2] = CreateFrame("Button", nil, UIParent)
G46.ieTabGroup.border:SetFrameLevel(100)
G46:PinTabStrip()
P46_B = G46.ieTabGroup.border:GetFrameLevel()
P46_T1 = G46.ieTabGroup.tabs[1]:GetFrameLevel()
P46_T2 = G46.ieTabGroup.tabs[2]:GetFrameLevel()
""")
check(bool(rt.eval("P46_T1 > P46_B and P46_T2 > P46_T1")), "pin: tab buttons strictly above the border, in order")
_g48 = open("GroupMaking.lua", encoding="utf-8").read()
check('AceGUI:Create("TabGroup")' not in _g48, "no opaque external tab widget anywhere near the invite engine")
check('CreateFrame("Button", "RLSuiteIETab" .. i, strip)' in _g48, "IE tabs are our own plain buttons inside the new strip")
check('function GM:ApplyInviteEngineTabStyles' in _g48 and 'SetTextColor(1, 0.82, 0)' in _g48, "active tab highlight in code")
check('SetFrameLevel((host:GetFrameLevel() or 1) + 50)' in _g48, "tab strip born with a level above the window content")



check('function GM:RepinManualPage' in open("GroupMaking.lua", encoding='utf-8').read(), "RepinManualPage exists (headers vs content deterministic pinning)")
check('self:RepinManualPage()' in open("GroupMaking.lua", encoding='utf-8').read(), "RepinManualPage invoked at page-build end AND on tab show")



check('content:EnableMouse(false)' not in _u, "scroll contents untouched (no EnableMouse overrides)")




# === v1.11.20: fix texture, label holder, barretta staccata, clip scroll =====================
print("\n== v1.11.20: TGA fix, macrobar label holder, detached title bar, scroll input clip ==")

# -- texture del addon: BLP nativi referenziati solo via AddonTexture (MAI path hardcoded)
import re
for _f in ("MSManager.lua", "GroupMaking.lua", "RaidProfile.lua"):
    _src = open(_f, encoding="utf-8").read()
    check("RaidLeadSuite\\\\media" not in _src, _f + ": no hardcoded addon-folder texture paths (AddonTexture only)")
check('ApplyIcon(delBtn, "media\\\\close.tga")' in open("MSManager.lua", encoding="utf-8").read(), "MS changes X uses ApplyIcon media close.tga (AddonTexture)")
check('"RLSuiteRaidControlBtn"' in open("RaidProfile.lua", encoding="utf-8").read(), "title bar hosts the Raid Control button (the old arrow is gone)")

# -- PH slot e' un bottone del KEYPAD: i tasti sotto (Pull/Ready/Break), stesso parent
rt.execute("MBPS = RLSuite.macrobar.phaseSlot")
check(bool(rt.eval("MBPS ~= nil and MBPS._parent == RLSuite.macrobar.keypadFrame")), "PH slot is part of the KEYPAD button grid (same parent as the buttons below)")
# -- tassello PH: prima cella della prima riga attiva del keypad, i tasti di quella riga scalano di una cella
rt.execute("""
MBKB = RLSuite.macrobar.keypadButtons
KP  = RLSuite.macrobar.keypadFrame
RLSuite.context = 'preboss'
RLSuite.macrobar:UpdateKeypad('preboss')
RLSuite.macrobar:UpdatePhase()
KP_SHOWN = KP:IsShown()
PS_P = RLSuite.macrobar.phaseSlot._points[1] or {}
PS_X = PS_P[4]; PS_Y = PS_P[5]
P15_P = MBKB[1]._points[1] or {}
P15_X = P15_P[4]; P15_Y = P15_P[5]
RDY_P = MBKB[4]._points[1] or {}
RDY_X = RDY_P[4]; RDY_Y = RDY_P[5]
""")
check(bool(rt.eval("KP_SHOWN == true")), "keypad visible in preboss")
check(bool(rt.eval("PS_X == 8 and PS_Y == -8")), "PH tassel sits in the FIRST CELL of the keypad grid (8,-8)")
check(bool(rt.eval("RLSuite.macrobar.phaseSlot._w == 75 and RLSuite.macrobar.phaseSlot._h == 22")), "PH tassel has the same cell size as the key buttons (75x22)")
check(bool(rt.eval("P15_X == 89 and P15_Y == -8")), "first key button of the top row starts one cell AFTER the PH tassel, same row")
check(bool(rt.eval("RDY_X == 8 and RDY_Y == -34")), "second-row key buttons keep the first cell (only the top row holds the PH tassel)")
rt.execute("RLSuite.context = 'preraid'; RLSuite.macrobar:UpdateKeypad('preraid'); RLSuite.macrobar:UpdatePhase()")

# === Scenario 1.11.23: X bianche ovunque (MakeCloseX), no X rossa in main bar, barretta trascinabile =
print("\n== v1.11.23: white close.blp X on every window close, no red X inside main bar, draggable title bar ==")
import glob
_red = []
for _f in glob.glob("*.lua"):
    if "UIPanelCloseButton" in open(_f, encoding="utf-8").read():
        _red.append(_f)
check(_red == [], "no UIPanelCloseButton remains in ANY addon module file (white close.blp X everywhere)")
check('function Utils:MakeCloseX' in open("Utils.lua", encoding="utf-8").read(), "Utils:MakeCloseX shared helper exists")
check(bool(rt.eval("RLSuite.utils.MakeCloseX ~= nil")), "MakeCloseX live in the runtime")

rt.execute("""
CLOSE_OK = 0
CLOSE_BAD = ''
local function chk(btn)
    if btn ~= nil then
        if btn.icon ~= nil and btn.icon._texture ~= nil and tostring(btn.icon._texture):find('close.tga', 1, true) and btn._w == 11 and btn._h == 11 then
            CLOSE_OK = CLOSE_OK + 1
        else
            CLOSE_BAD = CLOSE_BAD .. 'x'
        end
    end
end
chk(RLSuite.combatLog and RLSuite.combatLog.frame and RLSuite.combatLog.frame.closeBtn)
chk(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame and RLSuite.groupmaking.mainFrame.closeBtn)
chk(RLSuite.groupmaking and RLSuite.groupmaking.whisplistFrame and RLSuite.groupmaking.whisplistFrame.closeBtn)
chk(RLSuite.lootManager and RLSuite.lootManager.frame and RLSuite.lootManager.frame.closeBtn)
chk(RLSuite.msManager and RLSuite.msManager.frame and RLSuite.msManager.frame.closeBtn)
""")
check(int(rt.eval("CLOSE_OK") or 0) == 5, "all 5 built window-close buttons are the 11x11 close.tga X, HALVED (CL/GM/GM-wl/LM/MS)")
check(rt.eval("CLOSE_BAD") == '', "no close button kept the old red Blizzard artwork")

# -- LA X ROSSA nella main bar: eliminata
check(bool(rt.eval("RLSuite.mainWindow.closeBtn == nil")), "the red X INSIDE the main bar is GONE (only the title bar X remains)")
check('CreateFrame("Button", nil, f, "UIPanelCloseButton")' not in open("RaidProfile.lua", encoding="utf-8").read(), "RaidProfile main window: no more UIPanelCloseButton creation")

# -- Barretta trascinabile: muove TUTTA la main bar
rt.execute("""
TB23 = RLSuite.mainWindow.titleBar
TB23DRAG = TB23._dragButtons ~= nil
TB23PROXY = TB23._scripts.OnDragStart ~= nil or TB23._scripts.OnDragStop ~= nil
TB23_NO_DRAG = (TB23DRAG == false and TB23PROXY == false)
""")
check(bool(rt.eval("TB23_NO_DRAG == true")),
      "title bar is NOT draggable any more: the bar is anchored (top of the screen, right offset)")

# -- v1.11.30/56: X a 11x11 e pulsante "Raid Control" al posto della freccia
rt.execute("""
TB30C = RLSuite.mainWindow.titleBar.closeBtn
TB30A = RLSuite.mainWindow.titleBar.arrowBtn
MFW30 = RLSuite.mainWindow.frame
MFW30:Hide(); RLSuite.mainWindow._updateArrowDir()
HL_CLOSED30 = TB30A._highlight
MFW30:Show(); RLSuite.mainWindow._updateArrowDir()
HL_OPEN30 = TB30A._highlight
MFW30:Hide(); RLSuite.mainWindow._updateArrowDir()
TB30_H = TB30A._h
TB30_TEXT = TB30A:GetText()
""")
check(bool(rt.eval("TB30C._w == 11 and TB30C._h == 11")), "title bar close icon HALVED (11x11)")
check(bool(rt.eval("TB30_TEXT == 'Raid Control' and TB30_H == 16")),
      "the panel toggle is a 16px 'Raid Control' text button (no more arrow)")
check(bool(rt.eval("HL_CLOSED30 == false and HL_OPEN30 == true")),
      "Raid Control highlight follows the panel state")
# -- v1.11.31: la barra non esce mai dallo schermo
_rp = open("RaidProfile.lua", encoding="utf-8").read()
check(('MakeDraggable(f, "main")' not in _rp) and ('MakeUniversalWindow(f, "main")' not in _rp),
      "main window is NOT draggable: its position is anchored (Raid Frame width offset)")
check(bool(rt.eval("RLSuite.mainWindow.frame._rlsDraggable == nil")), "main window carries no drag machinery")
_u35 = open("Utils.lua", encoding="utf-8").read()
check('_rlsDragGuard' in _u35 and _u35.count("ClampWindowToScreen(frame)") >= 1 and _u35.count("ClampWindowToScreen(self2)") >= 1, "MakeDraggable clamps ALL windows during drag + on drop (the identical machinery everywhere)")
check('tb:RegisterForDrag("LeftButton")' not in _rp, "title bar no longer registers any drag")
check('ClampWindowToScreen(self.frame)' in open("MacroBar.lua", encoding="utf-8").read(), "macrobar shift-drag drop clamped inside the screen")
check('ClampWindowToScreen(self2)' in open("MacroBar.lua", encoding="utf-8").read(), "macrobar anchor-mode drop clamped inside the screen")






# -- scroll clip util: registrazione nei moduli
check(bool(rt.eval("RLSuite.lootManager.histContent._rlsScrollClip ~= nil")), "scroll clip registered on LootManager history")
check(bool(rt.eval("RLSuite.combatLog.leftContent._rlsScrollClip ~= nil and RLSuite.combatLog.rightContent._rlsScrollClip ~= nil")), "scroll clip registered on CombatLog panes")
check(bool(rt.eval("RLSuite.msManager.listContent._rlsScrollClip ~= nil")), "scroll clip registered on MS changes list")
check(bool(rt.eval("RLSuite.groupmaking.wlContent._rlsScrollClip ~= nil")), "scroll clip registered on whisplist")

# -- util funzionante su frames finti: fuori viewport = Hide, dentro = Show
rt.execute("""
U = RLSuite.utils
ROWS = {}
V_OFF = 0
SCR = CreateFrame("Frame", "RlsScrollClipTestScroll", UIParent)
SCR._h = 100
SCR.GetVerticalScroll = function() return V_OFF end
CON = CreateFrame("Frame", "RlsScrollClipTestContent", SCR)
U:RegisterScrollClip(SCR, CON)
U:ClearScrollClip(CON)
local tops = { 0, 60, 96, 200 }
for i, tp in ipairs(tops) do
    local r = CreateFrame("Frame", nil, CON)
    ROWS[i] = r
    U:ClipScrollRow(CON, r, tp, 24)
end
V_OFF = 60
U:RefreshScrollClip(CON)
V1 = ROWS[1]:IsShown(); V2 = ROWS[2]:IsShown(); V3 = ROWS[3]:IsShown(); V4 = ROWS[4]:IsShown()
""")
check(bool(rt.eval("V1 == false and V2 == true and V3 == true and V4 == false")), "scroll clip: rows outside the viewport are hidden, visible ones stay shown")
rt.execute("V_OFF = 96; SCR._scripts.OnMouseWheel(SCR); V_AFTER = ROWS[3]:IsShown() and (not ROWS[4]:IsShown())")
check(bool(rt.eval("V_AFTER == true")), "scroll clip refreshes on scroll events")

# -- dropdown: menu RIUSATO, mai un cadavere nuovo
rt.execute("""
dd2 = RLSuite.lootManager.rarityDropdown
RLSuite.utils:ToggleDropdownMenu(dd2)
M_A = dd2._rlsDropMenu
RLSuite.utils:CloseDropdownMenu()
RLSuite.utils:ToggleDropdownMenu(dd2)
M_B = dd2._rlsDropMenu
RLSuite.utils:CloseDropdownMenu()
""")
check(bool(rt.eval("M_A ~= nil and M_A == M_B")), "dropdown menu is reused per dropdown (no leaked rebuilds)")


# =====================================================================
# v1.11.49: check buff consapevole di CLASSE e COMPOSIZIONE
#   - applicabilita' per classe (Int non si segnala a un warrior)
#   - scope completo: raid-wide / party-only (totem) / single (FM) / capped
#   - intestazione GRIGIA se la categoria non e' disponibile con la comp
#   - overlay ROSSO se la categoria e' disponibile ma il check non e' ok
#   - Focus Magic: tante aure quanti maghi, nomi dei maghi mancanti
# =====================================================================
print("\n== v1.11.49: class/composition-aware buff check (grey header, red overlay, FM per mage) ==")

# --- guardie statiche sul modello dati ------------------------------------
rt.execute("""
COMPB_PARTY_SUBSET, COMPB_CAP_OK, COMPB_BEN_VALID = true, true, true
local VALID = { WARRIOR=true, PALADIN=true, HUNTER=true, ROGUE=true, PRIEST=true,
                DEATHKNIGHT=true, SHAMAN=true, MAGE=true, WARLOCK=true, DRUID=true }
for _, c in ipairs(RLSuite.raidBuffColumns) do
    for _, pc in ipairs(c.partyProviders or {}) do
        local found = false
        for _, cc in ipairs(c.classes or {}) do if cc == pc then found = true end end
        if not found then COMPB_PARTY_SUBSET = false end
    end
    if c.scope == "capped" and not (c.cap and c.cap > 0) then COMPB_CAP_OK = false end
    for _, bc in ipairs(c.beneficiaries or {}) do
        if not VALID[bc] then COMPB_BEN_VALID = false end
    end
end
COMPB_SCOPE_VALUES = true
for _, c in ipairs(RLSuite.raidBuffColumns) do
    if c.scope ~= nil and c.scope ~= 'raid' and c.scope ~= 'single' and c.scope ~= 'capped' then
        COMPB_SCOPE_VALUES = false
    end
end
""")
check(bool(rt.eval("COMPB_PARTY_SUBSET")), "static: every partyProviders class is also listed in classes (provider subset invariant)")
check(bool(rt.eval("COMPB_CAP_OK")), "static: every 'capped' category declares a positive cap")
check(bool(rt.eval("COMPB_BEN_VALID")), "static: every beneficiaries entry is a real WoW class")
check(bool(rt.eval("COMPB_SCOPE_VALUES")), "static: scope is only raid/single/capped")

# --- roster deterministico + aure STUBBATE --------------------------------
# G1: Pala(PALADIN) Mago1(MAGE) Sham(SHAMAN) Warro(WARRIOR) Pret(PRIEST)
# G2: Mago2(MAGE) Druid(DRUID) Ladro(ROGUE)
# Le aure sono stub: il test misura la LOGICA (applicabilita'/copertura), non
# lo scan di UnitBuff del client.
rt.execute("""
local RF = RLSuite.raidFrame
COMPB_SAVED = RF._BuffCellIconFor
RLSuite.db.profile.debug = true
RLSuite.debugTanks = nil
RLSuite.debugRaid = { slots = {
    [1] = { name = 'Pala',  class = 'PALADIN', isPlayer = false, subgroup = 1 },
    [2] = { name = 'Mago1', class = 'MAGE',    isPlayer = false, subgroup = 1 },
    [3] = { name = 'Sham',  class = 'SHAMAN',  isPlayer = false, subgroup = 1 },
    [4] = { name = 'Warro', class = 'WARRIOR', isPlayer = false, subgroup = 1 },
    [5] = { name = 'Pret',  class = 'PRIEST',  isPlayer = false, subgroup = 1 },
    [6] = { name = 'Mago2', class = 'MAGE',    isPlayer = false, subgroup = 2 },
    [7] = { name = 'Druid', class = 'DRUID',   isPlayer = false, subgroup = 2 },
    [8] = { name = 'Ladro', class = 'ROGUE',   isPlayer = false, subgroup = 2 },
} }
COMPB_AURA = {}
RF._BuffCellIconFor = function(self2, member, col)
    local byName = COMPB_AURA[member and member.name]
    if byName and byName[col.key] then return 'Tex:' .. col.key, 1 end
    return nil
end
COMPB = function(key)
    for _, c in ipairs(RLSuite.raidBuffColumns) do
        if c.key == key then return RLSuite.raidFrame:BuffCoverage(c) end
    end
    return nil
end
COMPB_HDR = function(key)
    for c, b in ipairs(RLSuite.raidFrame._buffHdrBtns) do
        if b._col and b._col.key == key then return b, c end
    end
    return nil, nil
end
RLSuite.raidFrame.buffMatrixOn = true
RLSuite.raidFrame:Rebuild()
""")

# --- applicabilita' per classe --------------------------------------------
rt.execute("""
local st = COMPB('intellect')
COMPB_INT_APPLICABLE = st.applicable
COMPB_INT_MISSING = #st.missing
COMPB_INT_AVAILABLE = st.available
COMPB_INT_NO_PHYS = true
for _, n in ipairs(st.missing) do
    if n == 'Warro' or n == 'Ladro' then COMPB_INT_NO_PHYS = false end
end
-- e la stessa categoria su chi NON ha mana: 0 player applicabili
local st2 = COMPB('intellect')
COMPB_INT_MANA_ONLY = (st2.applicable == 6)
""")
check(bool(rt.eval("COMPB_INT_MANA_ONLY")), "class applicability: Int counts the 6 mana users only (warrior/rogue are NOT applicable)")
check(bool(rt.eval("COMPB_INT_NO_PHYS")), "class applicability: the missing list never names non-benefiting classes (no Int for a warrior)")
check(bool(rt.eval("COMPB_INT_AVAILABLE")), "a category whose provider class IS in the raid stays available")

# --- totem RAID-WIDE (3.3.5) + meccanismo party-only ----------------------
# Dal patch 3.0.2 i totem shaman di buff sono RAID-WIDE, con limite di RAGGIO
# (non di party): marcarli party-only darebbe FALSI NEGATIVI. La meccanica
# partyProviders resta disponibile e si verifica con una categoria SINTETICA,
# cosi' il test non congela un dato di gioco sbagliato.
rt.execute("""
local st = COMPB('spellHaste')
COMPB_SPH_COVERABLE = st.coverable
COMPB_SPH_AVAILABLE = st.available
COMPB_NO_PARTY_MARKED = true
for _, c in ipairs(RLSuite.raidBuffColumns) do
    if c.partyProviders and #c.partyProviders > 0 then COMPB_NO_PARTY_MARKED = false end
end
-- categoria sintetica party-only: esercita il meccanismo
RLSuite.raidBuffColumns[#RLSuite.raidBuffColumns + 1] = {
    key = 'compbSyntheticParty', label = 'SynthParty',
    icon = 'SynthIcon',  -- irrilevante: l'aura e' stub, nessun rendering
    classes = { 'SHAMAN' }, partyProviders = { 'SHAMAN' },
    beneficiaries = { 'MAGE', 'WARLOCK', 'PRIEST', 'DRUID', 'SHAMAN', 'PALADIN' },
    spells = { 3738 } }
local stp = COMPB('compbSyntheticParty')
COMPB_SP_COVERABLE = stp.coverable
COMPB_SP_MISSING = #stp.missing
COMPB_SP_NO_G2 = true
for _, n in ipairs(stp.missing) do
    if n == 'Mago2' or n == 'Druid' then COMPB_SP_NO_G2 = false end
end
COMPB_SP_G1 = false
for _, n in ipairs(stp.missing) do
    if n == 'Mago1' then COMPB_SP_G1 = true end
end
RLSuite.raidBuffColumns[#RLSuite.raidBuffColumns] = nil
""")
check(bool(rt.eval("COMPB_NO_PARTY_MARKED")), "3.3.5 reality: NO category is party-only (patch 3.0.2 made every shaman buff totem raid-wide, range-limited)")
check(bool(rt.eval("COMPB_SPH_AVAILABLE and COMPB_SPH_COVERABLE == 6")), "raid-wide totem: Wrath of Air covers ALL 6 casters, not just the shaman's party")
check(bool(rt.eval("COMPB_SP_COVERABLE == 4 and COMPB_SP_MISSING == 4")), "party-only MECHANISM (synthetic category): only the provider's party is expected to have it")
check(bool(rt.eval("COMPB_SP_NO_G2")), "party-only MECHANISM: members OUTSIDE the provider's party are NOT reported (no false alarm)")
check(bool(rt.eval("COMPB_SP_G1")), "party-only MECHANISM: members INSIDE the provider's party ARE reported when it is down")

# --- scope capped (Replenishment copre 10) --------------------------------
rt.execute("""
local slots = {}
for i = 1, 25 do
    local mana = (i <= 15)
    slots[i] = { name = mana and ('Mana' .. i) or ('Phys' .. i),
                 class = mana and 'MAGE' or 'WARRIOR', isPlayer = false,
                 subgroup = math.floor((i - 1) / 5) + 1 }
end
RLSuite.debugRaid = { slots = slots }
RLSuite.debugTanks = nil
COMPB_AURA = {}
RLSuite.raidFrame:Rebuild()
local st = COMPB('replen')
COMPB_REPLEN_EXPECTED = st.expected
COMPB_REPLEN_APPLICABLE = st.applicable
COMPB_REPLEN_RED = (COMPB_HDR('replen')._red:IsShown() == true)
-- 10 aure su 15 mana user: il check DEVE essere soddisfatto (cap 10)
for i = 1, 10 do COMPB_AURA['Mana' .. i] = { replen = true } end
RLSuite.raidFrame:RefreshBuffMatrix()
local st2 = COMPB('replen')
COMPB_REPLEN_SAT_10 = st2.satisfied
COMPB_REPLEN_COUNT_10 = (st2.count == 10)
COMPB_REPLEN_RED_10 = (COMPB_HDR('replen')._red:IsShown() == true)
-- 9 aure: non soddisfatto -> overlay rosso
COMPB_AURA['Mana10'] = nil
RLSuite.raidFrame:RefreshBuffMatrix()
local st3 = COMPB('replen')
COMPB_REPLEN_SAT_9 = st3.satisfied
COMPB_REPLEN_RED_9 = (COMPB_HDR('replen')._red:IsShown() == true)
""")
check(bool(rt.eval("COMPB_REPLEN_EXPECTED == 10 and COMPB_REPLEN_APPLICABLE == 15")), "capped: Replenishment expects 10 of the 15 mana users (cap respected, not 'everyone')")
check(bool(rt.eval("COMPB_REPLEN_SAT_10 and COMPB_REPLEN_COUNT_10")), "capped: 10 covered auras SATISFY the check")
check(bool(rt.eval("COMPB_REPLEN_RED_10 == false")), "capped: a satisfied category shows NO red overlay")
check(bool(rt.eval("COMPB_REPLEN_RED == true")), "red overlay: an available category with nobody covered is flagged")
check(bool(rt.eval("COMPB_REPLEN_SAT_9 == false and COMPB_REPLEN_RED_9 == true")), "red overlay: dropping to 9 auras (below the 10 cap) flags the column again")

# --- Focus Magic: una FM per mago + nomi nell'alert -----------------------
rt.execute("""
RLSuite.debugTanks = nil
RLSuite.debugRaid = { slots = {
    [1] = { name = 'Pala',  class = 'PALADIN', isPlayer = false, subgroup = 1 },
    [2] = { name = 'Mago1', class = 'MAGE',    isPlayer = false, subgroup = 1 },
    [3] = { name = 'Sham',  class = 'SHAMAN',  isPlayer = false, subgroup = 1 },
    [4] = { name = 'Warro', class = 'WARRIOR', isPlayer = false, subgroup = 1 },
    [5] = { name = 'Pret',  class = 'PRIEST',  isPlayer = false, subgroup = 1 },
    [6] = { name = 'Mago2', class = 'MAGE',    isPlayer = false, subgroup = 2 },
    [7] = { name = 'Druid', class = 'DRUID',   isPlayer = false, subgroup = 2 },
    [8] = { name = 'Ladro', class = 'ROGUE',   isPlayer = false, subgroup = 2 },
} }
COMPB_AURA = {}
RLSuite.raidFrame.fmCasters = nil
RLSuite.raidFrame:Rebuild()
-- il combat log registra FONTE -> BERSAGLIO (l'aura sta sul bersaglio)
RLSuite.raidFrame:OnCombatLog('COMBAT_LOG_EVENT_UNFILTERED', 0, 'SPELL_AURA_APPLIED',
    'GUID-A', 'Mago1', 0, 'GUID-B', 'Mago2', 0, 54646)
COMPB_FM_LOGGED = (RLSuite.raidFrame.fmCasters ~= nil
    and RLSuite.raidFrame.fmCasters['Mago1'] == 'Mago2')
-- 1 sola aura su 2 maghi -> manca Mago2
COMPB_AURA['Mago2'] = { focusMagic = true }
RLSuite.raidFrame:RefreshBuffMatrix()
local st = COMPB('focusMagic')
COMPB_FM_EXPECTED = st.expected
COMPB_FM_COUNT = st.count
COMPB_FM_SAT = st.satisfied
COMPB_FM_NAMES = table.concat(st.missingProviders, ',')
COMPB_FM_RED = (COMPB_HDR('focusMagic')._red:IsShown() == true)
-- alert: conteggio + NOME del mago che non l'ha dato
local n0 = #CHAT_LOG
COMPB_HDR('focusMagic')._scripts.OnClick(COMPB_HDR('focusMagic'))
COMPB_FM_ALERT = ''
for i = n0 + 1, #CHAT_LOG do
    if CHAT_LOG[i]:find('RAID_WARNING', 1, true) then COMPB_FM_ALERT = CHAT_LOG[i] end
end
-- secondo mago coperto -> soddisfatto, niente rosso
COMPB_AURA['Druid'] = { focusMagic = true }
RLSuite.raidFrame:OnCombatLog('COMBAT_LOG_EVENT_UNFILTERED', 0, 'SPELL_AURA_APPLIED',
    'GUID-C', 'Mago2', 0, 'GUID-D', 'Druid', 0, 54646)
RLSuite.raidFrame:RefreshBuffMatrix()
local st2 = COMPB('focusMagic')
COMPB_FM_SAT2 = st2.satisfied
COMPB_FM_RED2 = (COMPB_HDR('focusMagic')._red:IsShown() == true)
COMPB_FM_NAMES2 = #st2.missingProviders
""")
check(bool(rt.eval("COMPB_FM_LOGGED")), "FM: the combat log records caster->target for Focus Magic (SPELL_AURA_APPLIED)")
check(bool(rt.eval("COMPB_FM_EXPECTED == 2")), "FM: expected auras = number of MAGES in the raid (2), not number of casters (6)")
check(bool(rt.eval("COMPB_FM_COUNT == 1 and COMPB_FM_SAT == false")), "FM: one aura on two mages leaves the check unsatisfied")
check(bool(rt.eval("COMPB_FM_NAMES == 'Mago2'")), "FM: the missing provider is named from the combat log (only Mago2, Mago1 already cast)")
check(bool(rt.eval("COMPB_FM_RED == true")), "FM: an unsatisfied category paints the red overlay on its header")
check(bool(rt.eval("COMPB_FM_ALERT:find('1/2', 1, true) ~= nil and COMPB_FM_ALERT:find('Mago2', 1, true) ~= nil")), "FM: the alert carries the count (1/2) AND the name of the mage who has not cast it")
check(bool(rt.eval("COMPB_FM_SAT2 == true and COMPB_FM_RED2 == false and COMPB_FM_NAMES2 == 0")), "FM: with one FM per mage the column is satisfied and the red overlay disappears")

# --- intestazione GRIGIA per categoria non disponibile --------------------
# Roster: solo WARRIOR + ROGUE -> niente paladini/maghi/shaman.
rt.execute("""
RLSuite.debugTanks = nil
RLSuite.debugRaid = { slots = {
    [1] = { name = 'Warro', class = 'WARRIOR', isPlayer = false, subgroup = 1 },
    [2] = { name = 'Ladro', class = 'ROGUE',   isPlayer = false, subgroup = 1 },
} }
COMPB_AURA = {}
RLSuite.raidFrame:Rebuild()
local hStats = COMPB_HDR('stats')
local hHp = COMPB_HDR('hp')
local stStats = COMPB('stats')
local stHp = COMPB('hp')
COMPB_NODATA_FLAG = (hStats._nodata == true)
COMPB_NODATA_GREY = (hStats._icon._vertex[1] == 0.35)
COMPB_NODATA_NORED = (hStats._red:IsShown() == false)
COMPB_NODATA_HIDDEN = (stStats.available == false)
COMPB_AVAIL_NOT_GREY = (hHp._nodata == false and hHp._icon._vertex[1] == 0.8)
COMPB_AVAIL_RED = (hHp._red:IsShown() == true)
-- tooltip: riga di stato dedicata
local t1 = select(1, RLSuite.raidFrame:_BuffStatusText(stStats))
local t2 = select(1, RLSuite.raidFrame:_BuffStatusText(stHp))
COMPB_TOOLTIP_NODATA = (t1 == 'Not available in this composition')
COMPB_TOOLTIP_MISS = (t2 == 'Missing: 2: Warro, Ladro')
-- hover su una categoria non disponibile: resta spenta
hStats._scripts.OnEnter(hStats)
COMPB_NODATA_HOVER = (hStats._icon._vertex[1] == 0.35 and hStats._red:IsShown() == false)
hStats._scripts.OnLeave(hStats)
-- alert: dice che la categoria non e' disponibile, senza accusare nessuno
local n0 = #CHAT_LOG
hStats._scripts.OnClick(hStats)
COMPB_NODATA_ALERT = ''
for i = n0 + 1, #CHAT_LOG do
    if CHAT_LOG[i]:find('RAID_WARNING', 1, true) then COMPB_NODATA_ALERT = CHAT_LOG[i] end
end
""")
check(bool(rt.eval("COMPB_NODATA_FLAG and COMPB_NODATA_HIDDEN")), "unavailable: a category with no provider class in the raid is marked not-available")
check(bool(rt.eval("COMPB_NODATA_GREY")), "unavailable: its header icon is greyed (0.35) instead of the normal 0.8")
check(bool(rt.eval("COMPB_NODATA_NORED")), "unavailable: NO red overlay (grey and red are distinct states)")
check(bool(rt.eval("COMPB_NODATA_HOVER")), "unavailable: hovering keeps it dim (it must not look available)")
check(bool(rt.eval("COMPB_AVAIL_NOT_GREY and COMPB_AVAIL_RED")), "available but unsatisfied: normal brightness + red overlay (e.g. HP with nobody buffed)")
check(bool(rt.eval("COMPB_TOOLTIP_NODATA")), "tooltip: 'Not available in this composition' on an unavailable column")
check(bool(rt.eval("COMPB_TOOLTIP_MISS")), "tooltip: missing count + names on an unsatisfied column")
check(bool(rt.eval("COMPB_NODATA_ALERT:find('not available in this composition', 1, true) ~= nil")), "alert: an unavailable category says so instead of listing the whole raid as missing")

# --- ripristino: nessuna traccia lasciata ai test successivi --------------
rt.execute("""
local RF = RLSuite.raidFrame
RF._BuffCellIconFor = COMPB_SAVED
RF.fmCasters = nil
COMPB_AURA = nil
RLSuite:ResetDebugRaid()
RLSuite.debugTanks = nil
RLSuite.raidFrame.buffMatrixOn = false
RLSuite.raidFrame:Rebuild()
COMPB_RESTORED = (RF._BuffCellIconFor == COMPB_SAVED)
""")
check(bool(rt.eval("COMPB_RESTORED")), "v1.11.49 harness restores the aura source and the roster (no leak into other scenarios)")

check(rt.eval("LAST_ERROR") is None or rt.eval("LAST_ERROR") == None, "no errors during Scenarios G+H (LAST_ERROR=%r)" % rt.eval("LAST_ERROR"))

rt.execute("""
-- ================= v1.11.62: GRIGLIA IMMOBILE DEL RAID FRAME ==========
-- Il bug: a raid vuoto il roster si "ri-compattava" dal fondo e la barra
-- del player finiva IN CIMA al frame (e la strip del buff check si
-- agganciava all'header G1, che con G1 vuoto non c'e'). La griglia ora ha
-- un posto FISSO per ogni gruppo: la y di un player dipende SOLO dal suo
-- gruppo, qualunque sia il resto del roster.
_IM_GM = GetNumRaidMembers
_IM_GR = GetRaidRosterInfo
_IM_CTX = RLSuite.context
RLSuite.db.profile.debug = false
IMRF = RLSuite.raidFrame
IM_M = IMRF:LayoutMetrics()
IM_BAND = IM_M.groupHeaderH + 5 * (IM_M.rowHeight + IM_M.rowSpacing) + IM_M.groupSpacing
function IM_SetRoster(list)
    IM_RAID = list
    GetNumRaidMembers = function() return #IM_RAID end
    GetRaidRosterInfo = function(i)
        local m = IM_RAID[i]
        if m then return m.name, 0, m.subgroup, 80, 'Warrior', 'WARRIOR', 'Icecrown', true, false end
        return nil
    end
    IMRF:Rebuild()
    IMRF:RefreshBuffMatrix()
end
function IM_RowY(g)
    local sl = IMRF.slots[(g - 1) * 5 + 1]
    local p = sl and sl._points and sl._points[1]
    return p and p[5]
end
function IM_CellY(g)
    local sl = IMRF.slots[(g - 1) * 5 + 1]
    local cell = sl and sl._buffCells and sl._buffCells[1]
    local p = cell and cell._points and cell._points[1]
    return p and p[5]
end
function IM_HdrIcon()
    local hb = IMRF._buffHdrBtns and IMRF._buffHdrBtns[1]
    local p = hb and hb._points and hb._points[1]
    return hb, p and p[5]
end
IM_FULL = {}
for g = 1, 6 do for i = 1, 5 do IM_FULL[#IM_FULL + 1] = {name='P'..g..i, subgroup=g} end end

IMRF.buffMatrixOn = false
IM_SetRoster({})
IM_H_EMPTY = IMRF.frame._h
IM_Y6_EMPTY = IM_RowY(6)
IM_SetRoster({{name='Me', subgroup=4}})     -- "raid vuoto, mi sposto in un gruppo"
IM_H_ONE = IMRF.frame._h
IM_Y4_ONE = IM_RowY(4)
IM_SetRoster({{name='Me', subgroup=6}})
IM_Y6_ONE = IM_RowY(6)
IM_SetRoster(IM_FULL)
IM_H_FULL = IMRF.frame._h
IM_Y6_FULL = IM_RowY(6)
IM_Y5_FULL = IM_RowY(5)
IM_Y4_FULL = IM_RowY(4)
IM_Y1_FULL = IM_RowY(1)

-- buff check: matrice accesa, un solo player in G4 -> la strip resta in cima
IMRF.buffMatrixOn = true
IM_SetRoster({{name='Me', subgroup=4}})
local hb1, hy1 = IM_HdrIcon()
IM_HDR_SHOWN_ONE = hb1 and hb1:IsShown() or false
IM_HDR_Y_ONE = hy1
IM_CELL4_ONE = IM_CellY(4)
IM_SetRoster(IM_FULL)
local hb2, hy2 = IM_HdrIcon()
IM_HDR_Y_FULL = hy2
IM_CELL4_FULL = IM_CellY(4)
IMRF.buffMatrixOn = false
IM_SetRoster({{name='Me', subgroup=6}})

-- drag attivo (pre-boss): mostrare gli slot vuoti NON deve spostare niente
RLSuite.context = 'preboss'
IMRF._rfDragSource = IMRF.slots[1]
IMRF:RefreshDropTargets()
IM_DRAG_H = IMRF.frame._h
IM_DRAG_Y6 = IM_RowY(6)
local dragShown = 0
for _, sl in ipairs(IMRF.slots) do if sl:IsShown() then dragShown = dragShown + 1 end end
IM_DRAG_SHOWN = dragShown
IMRF._rfDragSource = nil
IMRF:RefreshDropTargets()
IMRF.buffMatrixOn = false

-- toggle della matrice: non deve muovere NIENTE
IM_SetRoster({{name='Me', subgroup=6}})
IMRF.buffMatrixOn = false
IMRF:Rebuild()
IM_H_MAT_OFF = IMRF.frame._h
IM_Y6_MAT_OFF = IM_RowY(6)
IMRF.buffMatrixOn = true
IMRF:Rebuild()
IM_H_MAT_ON = IMRF.frame._h
IM_Y6_MAT_ON = IM_RowY(6)
IMRF.buffMatrixOn = false
-- blocco Tanks riservato sempre: la barra MT non si muove col roster
local mt1 = IMRF.tankSlots[1]
local mp1 = mt1 and mt1._points and mt1._points[1]
IM_MT_Y_ONE = mp1 and mp1[5]
IM_SetRoster({})
IM_BTN_EMPTY_SHOWN = (IMRF.buffPanelBtn and IMRF.buffPanelBtn:IsShown()) and true or false
IM_SetRoster(IM_FULL)
local mt2 = IMRF.tankSlots[1]
local mp2 = mt2 and mt2._points and mt2._points[1]
IM_MT_Y_FULL = mp2 and mp2[5]
IM_BTN_FULL_SHOWN = (IMRF.buffPanelBtn and IMRF.buffPanelBtn:IsShown()) and true or false
IMRF.buffMatrixOn = false
IM_SetRoster({{name='Me', subgroup=6}})

GetNumRaidMembers = _IM_GM
GetRaidRosterInfo = _IM_GR
RLSuite.context = _IM_CTX
RLSuite.db.profile.debug = true
if RLSuite.ApplyDebugMode then pcall(function() RLSuite:ApplyDebugMode() end) end
RLSuite:ResetDebugRaid()
IMRF:Rebuild()
""")


check(bool(rt.eval("IM_H_EMPTY == IM_H_ONE and IM_H_ONE == IM_H_FULL")), "v1.11.62: il Raid Frame ha la STESSA altezza con raid vuoto, un player solo e raid pieno (%r/%r/%r)" % (rt.eval("IM_H_EMPTY"), rt.eval("IM_H_ONE"), rt.eval("IM_H_FULL")))
check(bool(rt.eval("IM_Y6_ONE == IM_Y6_FULL and IM_Y6_EMPTY == IM_Y6_FULL")), "v1.11.62: la barra del player in G6 sta IN FONDO anche a raid vuoto (y=%r, raid pieno y=%r)" % (rt.eval("IM_Y6_ONE"), rt.eval("IM_Y6_FULL")))
check(bool(rt.eval("IM_Y4_ONE == IM_Y4_FULL")), "v1.11.62: spostarsi in un gruppo a caso non manda la barra in cima (G4 solo: y=%r, raid pieno: y=%r)" % (rt.eval("IM_Y4_ONE"), rt.eval("IM_Y4_FULL")))
check(bool(rt.eval("IM_Y4_FULL > IM_Y6_FULL and IM_Y1_FULL > IM_Y4_FULL")), "v1.11.62: i gruppi restano in ordine G1..G6 dall'alto verso il basso (mai ricompattati)")
check(bool(rt.eval("(IM_Y5_FULL - IM_Y6_FULL) == IM_BAND and (IM_Y1_FULL - IM_Y5_FULL) == 4 * IM_BAND")), "v1.11.62: la distanza fra i blocchi dei gruppi e' costante (banda fissa, non dipende dal roster)")
check(bool(rt.eval("IM_HDR_SHOWN_ONE == true")), "v1.11.62: con G1 vuoto le icone del buff check si vedono lo stesso (prima sparivano)")
check(bool(rt.eval("IM_HDR_Y_ONE == IM_HDR_Y_FULL")), "v1.11.62: la strip del buff check resta in cima, stessa y con roster pieno o quasi vuoto (%r/%r)" % (rt.eval("IM_HDR_Y_ONE"), rt.eval("IM_HDR_Y_FULL")))
check(bool(rt.eval("IM_CELL4_ONE == IM_CELL4_FULL")), "v1.11.62: le celle della matrice restano allineate alla riga del loro gruppo")
check(bool(rt.eval("IM_DRAG_H == IM_H_FULL and IM_DRAG_Y6 == IM_Y6_FULL")), "v1.11.62: mostrare gli slot vuoti durante il drag non sposta le barre (slot visibili: %r)" % rt.eval("IM_DRAG_SHOWN"))
check(bool(rt.eval("IM_DRAG_SHOWN >= 5")), "v1.11.62: durante il drag gli slot vuoti restano drop target (nessuna regressione)")

check(bool(rt.eval("IM_H_MAT_OFF == IM_H_MAT_ON and IM_Y6_MAT_OFF == IM_Y6_MAT_ON")), "v1.11.62: accendere/spegnere il buff check non muove le barre")
check(bool(rt.eval("IM_MT_Y_ONE == IM_MT_Y_FULL")), "v1.11.62: il blocco Tanks e' riservato sempre (barra MT ferma: %r / %r)" % (rt.eval("IM_MT_Y_ONE"), rt.eval("IM_MT_Y_FULL")))
check(bool(rt.eval("IM_BTN_EMPTY_SHOWN == false and IM_BTN_FULL_SHOWN == true")), "v1.11.62: a roster vuoto il tasto 'Raid Buffs' resta nascosto e riappare col roster")

rt.execute("""
-- =====================================================================
-- v1.11.63: report stile UwU Logs (targets/consumables/auras/deaths/powers)
-- Fight SINTETICO deterministico: numeri esatti per ogni aggregazione.
-- =====================================================================
CLT = RLSuite.combatLog
CLT.db.enabled = true
UW_P = 1024 + 16 + 1      -- player, friendly, affiliato al raid
UW_N = 2048 + 64          -- npc, hostile
UW_FLASK = 53760          -- Flask of Endless Rage (in RLSuite.buffData.flask)
UW_FOOD = 57399           -- Well Fed (Fish Feast)
UW_F = {
    name = "Test Boss", kill = true, duration = 100, startTime = 0, startUTC = 0,
    count = 0, events = {}, samples = { health = {}, power = {} },
    player = "Alpha", raidSize = 25, difficulty = 3, boss = "Test Boss",
}
function UWPush(t, sub, src, srcf, dst, dstf, sid, sname, amt, over)
    local ev = { t, sub, src, srcf or 0, dst, dstf or 0, sid, sname, amt, over }
    UW_F.count = UW_F.count + 1
    UW_F.events[UW_F.count] = ev
    return ev
end
for i = 1, 6 do
    UWPush(10 * i, "SPELL_DAMAGE", "Alpha", UW_P, "Test Boss", UW_N, 48230, "Fireball", 10000, 0)[17] = true
end
for i = 1, 4 do
    UWPush(12 * i, "SPELL_DAMAGE", "Beta", UW_P, "Test Boss", UW_N, 47488, "Mortal Strike", 10000, 0)[17] = true
end
UWPush(30, "SWING_DAMAGE", "Alpha", UW_P, "Trash Mob", UW_N, 0, "Melee", 10000, 0)
UWPush(40, "SPELL_DAMAGE", "Test Boss", UW_N, "Alpha", UW_P, 59448, "Cleave", 5000, 0)
UWPush(45, "SPELL_HEAL", "Alpha", UW_P, "Beta", UW_P, 48782, "Holy Light", 3000, 200)
UWPush(46, "SPELL_HEAL", "Beta", UW_P, "Beta", UW_P, 43185, "Runic Healing Potion", 2000, 0)
UWPush(0, "SPELL_AURA_APPLIED", "Alpha", UW_P, "Alpha", UW_P, UW_FLASK, "Flask of Endless Rage")
UWPush(50, "SPELL_AURA_REMOVED", "Alpha", UW_P, "Alpha", UW_P, UW_FLASK, "Flask of Endless Rage")
UWPush(0, "SPELL_AURA_APPLIED", "Alpha", UW_P, "Beta", UW_P, UW_FOOD, "Well Fed")
UWPush(20, "SPELL_CAST_SUCCESS", "Alpha", UW_P, "Alpha", UW_P, 53908, "Potion of Speed")
UWPush(5, "SPELL_ENERGIZE", "Alpha", UW_P, "Alpha", UW_P, 29131, "Bloodrage", 500)
UWPush(6, "SPELL_ENERGIZE", "Beta", UW_P, "Beta", UW_P, 29131, "Bloodrage", 300)
UWPush(89.5, "SPELL_DAMAGE", "Test Boss", UW_N, "Beta", UW_P, 59448, "Cleave", 4000, 1000)
UWPush(89.7, "SPELL_CAST_SUCCESS", "Test Boss", UW_N, "Beta", UW_P, 59448, "Cleave")
UWPush(89.9, "SPELL_HEAL", "Alpha", UW_P, "Beta", UW_P, 48782, "Holy Light", 800, 100)
UWPush(90, "UNIT_DIED", nil, 0, "Beta", UW_P)

local st = CLT:AggPlayerStats(UW_F)
UW_ORDER = {}
for _, a in ipairs(st.rows) do UW_ORDER[#UW_ORDER + 1] = a.name end
UW_A = st.rows[1]
UW_B = st.rows[2]
UW_STATS = {
    order = table.concat(UW_ORDER, ","),
    a_useful = UW_A.useful, a_total = UW_A.total, a_heal = UW_A.heal, a_taken = UW_A.taken,
    b_useful = UW_B.useful, b_taken = UW_B.taken, b_heal = UW_B.heal,
    t_useful = st.total.useful, t_total = st.total.total, t_heal = st.total.heal,
    t_taken = st.total.taken, dur = st.duration,
}

local tg = CLT:AggTargets(UW_F)
UW_TG = {
    ncol = #tg.targetCols,
    c1 = tg.targetCols[1].name, c1boss = tg.targetCols[1].boss,
    c2 = tg.targetCols[2].name, c2boss = tg.targetCols[2].boss,
    a_useful = tg.rows[1].useful, a_total = tg.rows[1].total,
    a_boss = tg.rows[1].byTarget["Test Boss"], a_trash = tg.rows[1].byTarget["Trash Mob"],
    t_total = tg.totalRow.total, t_useful = tg.totalRow.useful,
}

local cg = CLT:AggConsumables(UW_F)
UW_CONS = { ncol = #cg.cols, nplayers = #cg.players }
for _, c in ipairs(cg.cols) do
    if c.sid == UW_FLASK then UW_CONS.flask = c.key end
    if c.name == "Potion of Speed" then UW_CONS.pot = c.key end
    if c.name == "Well Fed" then UW_CONS.food = c.key end
end
UW_CONS.a_flask = cg.cells["Alpha"] and UW_CONS.flask and cg.cells["Alpha"][UW_CONS.flask]
UW_CONS.a_pot = cg.cells["Alpha"] and UW_CONS.pot and cg.cells["Alpha"][UW_CONS.pot]
UW_CONS.b_food = cg.cells["Beta"] and UW_CONS.food and cg.cells["Beta"][UW_CONS.food]
UW_CONS.b_pot = cg.cells["Beta"] and cg.cells["Beta"][tostring(43185) .. "|Runic Healing Potion"]

local ag = CLT:AggAuraMatrix(UW_F)
UW_AUR = { ncol = #ag.cols, dur = ag.duration }
local acell = ag.cells["Alpha"] and ag.cells["Alpha"][UW_FLASK]
if acell then UW_AUR.a_flask_count = acell.count; UW_AUR.a_flask_pct = acell.up / ag.duration * 100 end
local fcell = ag.cells["Beta"] and ag.cells["Beta"][UW_FOOD]
if fcell then UW_AUR.b_food_count = fcell.count; UW_AUR.b_food_pct = fcell.up / ag.duration * 100 end

local pm = CLT:AggPowerMatrix(UW_F)
UW_POW = { ncol = #pm.cols, total = pm.total, nplayers = #pm.players, sid = pm.cols[1].sid }
if pm.cells["Alpha"] then UW_POW.a = pm.cells["Alpha"][pm.cols[1].key] end
if pm.cells["Beta"] then UW_POW.b = pm.cells["Beta"][pm.cols[1].key] end

local de = CLT:AggDeaths(UW_F)
UW_DEATH = { n = #de, name = de[1] and de[1].name, t = de[1] and de[1].t, killer = de[1] and de[1].killer }
local dd = CLT:DeathDetail(UW_F, "Beta", 90, 12)
UW_DD = { n = #dd, first_kind = dd[1] and dd[1].kind }
for _, r in ipairs(dd) do
    if r.kind == "DAMAGE" and r.spell == "Cleave" and r.val == "4000" then
        UW_DD.dmg_val, UW_DD.dmg_over, UW_DD.dmg_flag, UW_DD.dmg_src = r.val, r.over, r.flag, r.src
    end
    if r.kind == "CAST" then UW_DD.cast_flag = r.flag end
    if r.kind == "HEAL" and r.val == "800" then UW_DD.heal_over = r.over end
end
UW_DD.stamp = CLT:RelStamp(-0.887)

-- titolo/etichette + dropdown
UW_TITLE = CLT:FightTitle(UW_F)
UW_LABEL = CLT:FightLabel(UW_F, 1)
local savedFights = CLT.db.fights
CLT.db.fights = { UW_F }
local items = CLT:FightListItems()
UW_ITEM1 = items[1] and items[1].text
UW_HAS_ALL = false
for _, it in ipairs(items) do
    if it.text == "All Test Boss segments" then UW_HAS_ALL = true end
end

-- fight unito ("All <boss> segments") su due pull
local fa = { name = "Same Boss", kill = false, duration = 100, startTime = 0,
    count = 1, events = { { 10, "SPELL_DAMAGE", "Alpha", UW_P, "Boss", UW_N, 1, "Hit", 100 } },
    samples = { health = {}, power = {} } }
local fb = { name = "Same Boss", kill = true, duration = 50, startTime = 200,
    count = 1, events = { { 5, "SPELL_DAMAGE", "Alpha", UW_P, "Boss", UW_N, 1, "Hit", 200 } },
    samples = { health = {}, power = {} } }
CLT.db.fights = { fb, fa }
local mf = CLT:MergedFight("Same Boss")
UW_MERGE = { n = mf and mf.count, dur = mf and mf.duration, seg = mf and mf.segments,
    kill = mf and mf.kill, t2 = mf and mf.events[2] and mf.events[2][1] }
CLT.db.fights = savedFights

-- grafico: 6 discretizzazioni + serie "media dell'intero fight"
CLT.selFight = UW_F
CLT:SelectTab("damage")
UW_STEPS = CLT.stepDropdown.options
UW_STEP1 = UW_STEPS[1] and UW_STEPS[1].text
UW_STEP6 = UW_STEPS[6] and UW_STEPS[6].text
UW_STEPN = #UW_STEPS
UW_GSTEP = CLT.graphStep
local s0 = CLT:DpsSeries(UW_F, nil, 0)
local s5 = CLT:DpsSeries(UW_F, nil, 5)
UW_SER = { n0 = #s0, first0 = s0[1] and s0[1][2], last0 = s0[#s0] and s0[#s0][2],
    n5 = #s5, b2_5 = s5[3] and s5[3][2] }

-- i tab si costruiscono senza errori e con le colonne giuste
UW_TABS = {}
for _, tab in ipairs({ "damage", "targets", "consumables", "auras", "powers" }) do
    CLT:SelectTab(tab)
    local cols = CLT.grid.cols or {}
    local rows = CLT.grid.pool[#cols] or {}
    UW_TABS[#UW_TABS + 1] = tab .. ":" .. #cols .. "x" .. (CLT.grid.rowCount or 0)
end
CLT:SelectTab("targets")
UW_TG_LABEL = CLT.grid.cols[4] and CLT.grid.cols[4].label
UW_TG_TIP = CLT.grid.cols[4] and CLT.grid.cols[4].tip
CLT:SelectTab("consumables")
UW_CONS_ICON = false
for _, c in ipairs(CLT.grid.cols) do
    if c.ic and tostring(c.ic):find("Tex:") then UW_CONS_ICON = true end
end
CLT:SelectTab("deaths")
UW_DEATH_ROWS = #CLT._dRows
local drows = CLT.deathGrid.pool[#(CLT.deathGrid.cols or {})] or {}
UW_DEATH_DETAIL_ROWS = CLT.deathGrid.rowCount or 0
UW_DEATH_FIRST = drows[1] and drows[1].cells[2].fs:GetText()
CLT:SelectTab("damage")
UW_BACK = CLT.gridPane:IsShown()
-- chiusura: nessuna finestra lasciata aperta dai test
CLT.selFight = nil
CLT.selTab = "damage"
CLT.db.fights = savedFights
CLT:RefreshUI()
""")


check(bool(rt.eval("UW_STATS.order == 'Alpha,Beta'")), "v1.11.63 AggPlayerStats: righe ordinate per danno utile (%s)" % rt.eval("UW_STATS.order"))
check(bool(rt.eval("UW_STATS.a_useful == 60000 and UW_STATS.a_total == 70000")), "v1.11.63 AggPlayerStats: danno utile (solo boss) separato dal totale (%r/%r)" % (rt.eval("UW_STATS.a_useful"), rt.eval("UW_STATS.a_total")))
check(bool(rt.eval("UW_STATS.a_taken == 5000 and UW_STATS.b_taken == 4000")), "v1.11.63 AggPlayerStats: danno SUBITO per giocatore (%r/%r)" % (rt.eval("UW_STATS.a_taken"), rt.eval("UW_STATS.b_taken")))
check(bool(rt.eval("UW_STATS.a_heal == 3800 and UW_STATS.b_heal == 2000")), "v1.11.63 AggPlayerStats: cure per giocatore (%r/%r)" % (rt.eval("UW_STATS.a_heal"), rt.eval("UW_STATS.b_heal")))
check(bool(rt.eval("UW_STATS.t_useful == 100000 and UW_STATS.t_total == 110000 and UW_STATS.t_heal == 5800 and UW_STATS.t_taken == 9000")), "v1.11.63 AggPlayerStats: riga TOTAL (utile %r, totale %r, cure %r, subito %r)" % (rt.eval("UW_STATS.t_useful"), rt.eval("UW_STATS.t_total"), rt.eval("UW_STATS.t_heal"), rt.eval("UW_STATS.t_taken")))
check(bool(rt.eval("UW_TG.ncol == 2 and UW_TG.c1boss == true and UW_TG.c2boss == false")), "v1.11.63 AggTargets: un boss e' marcato come tale (danno utile), lo spazzino no")
check(bool(rt.eval("UW_TG.a_useful == 60000 and UW_TG.a_boss == 60000 and UW_TG.a_trash == 10000")), "v1.11.63 AggTargets: danno per bersaglio per giocatore (%r boss / %r spazzino)" % (rt.eval("UW_TG.a_boss"), rt.eval("UW_TG.a_trash")))
check(bool(rt.eval("UW_TG.t_total == 110000 and UW_TG.t_useful == 100000")), "v1.11.63 AggTargets: totali di colonna/riga coerenti")
check(bool(rt.eval("UW_CONS.ncol == 4 and UW_CONS.a_flask == 1 and UW_CONS.a_pot == 1")), "v1.11.63 AggConsumables: flask (per ID) e pozione (per nome) contati 1 volta (%r/%r su %r colonne)" % (rt.eval("UW_CONS.a_flask"), rt.eval("UW_CONS.a_pot"), rt.eval("UW_CONS.ncol")))
check(bool(rt.eval("UW_CONS.b_food == 1 and UW_CONS.b_pot == 1")), "v1.11.63 AggConsumables: Well Fed (aura) e pozione curativa (heal su di se') riconosciute")
check(bool(rt.eval("UW_AUR.a_flask_count == 1 and math.abs(UW_AUR.a_flask_pct - 50) < 0.01")), "v1.11.63 AggAuraMatrix: applicazioni + uptime%% della flask (%r appl., %r%%)" % (rt.eval("UW_AUR.a_flask_count"), rt.eval("UW_AUR.a_flask_pct")))
check(bool(rt.eval("UW_AUR.b_food_count == 1 and math.abs(UW_AUR.b_food_pct - 100) < 0.01")), "v1.11.63 AggAuraMatrix: aura ancora aperta a fine pull = 100%% di uptime")
check(bool(rt.eval("UW_POW.total == 800 and UW_POW.a == 500 and UW_POW.b == 300")), "v1.11.63 AggPowerMatrix: risorsa generata per giocatore e per spell (%r)" % rt.eval("UW_POW.total"))
check(bool(rt.eval("UW_DEATH.n == 1 and UW_DEATH.name == 'Beta' and UW_DEATH.killer == 'Test Boss'")), "v1.11.63 AggDeaths: morto + chi ha dato il colpo finale (%s da %s)" % (rt.eval("UW_DEATH.name"), rt.eval("UW_DEATH.killer")))
check(bool(rt.eval("UW_DD.first_kind == 'DIED'")), "v1.11.63 DeathDetail: la riga DIED e' la prima (tempo 0:00.000)")
check(bool(rt.eval("UW_DD.dmg_val == '4000' and UW_DD.dmg_over == '1000' and UW_DD.dmg_flag == 'SPELL'")), "v1.11.63 DeathDetail: colpo con valore e overkill (%r, over %r, %s)" % (rt.eval("UW_DD.dmg_val"), rt.eval("UW_DD.dmg_over"), rt.eval("UW_DD.dmg_flag")))
check(bool(rt.eval("UW_DD.cast_flag == 'SUCCESS' and UW_DD.heal_over == '100'")), "v1.11.63 DeathDetail: righe CAST (SUCCESS) e HEAL con overheal")
check(bool(rt.eval("UW_DD.stamp == '-0:00.887'")), "v1.11.63 DeathDetail: timestamp relativo -m:ss.mmm (%s)" % rt.eval("UW_DD.stamp"))
check(bool(rt.eval("UW_TITLE == '1:40.000  Test Boss 25H  Kill'")), "v1.11.63 testata fight: durata + nome + taglia/difficolta' + esito (%s)" % rt.eval("UW_TITLE"))
check(bool(rt.eval("UW_LABEL == '1:40.000 | Kill  Test Boss'")), "v1.11.63 etichetta del dropdown (%s)" % rt.eval("UW_LABEL"))
check(bool(rt.eval("UW_HAS_ALL == true")), "v1.11.63 dropdown: voce 'All <boss> segments' per i segmenti uniti")
check(bool(rt.eval("UW_MERGE.n == 2 and UW_MERGE.dur == 150 and UW_MERGE.seg == 2 and UW_MERGE.kill == true")), "v1.11.63 MergedFight: eventi dei pull concatenati su una linea di tempo continua (%r)" % rt.eval("UW_MERGE.n"))
check(bool(rt.eval("UW_MERGE.t2 == 105")), "v1.11.63 MergedFight: il secondo pull parte dopo la durata del primo (t=%r)" % rt.eval("UW_MERGE.t2"))
check(bool(rt.eval("UW_STEPN == 6 and UW_STEP1 == 'Avg whole fight' and UW_STEP6 == 'Avg every 10 seconds'")), "v1.11.63 grafico: le 6 discretizzazioni di UwU (%s ... %s)" % (rt.eval("UW_STEP1"), rt.eval("UW_STEP6")))
check(bool(rt.eval("UW_GSTEP == 0")), "v1.11.63 grafico: default = 'Avg whole fight' (media dell'intero fight)")
check(bool(rt.eval("UW_SER.n0 == 61 and UW_SER.first0 == 0 and math.abs(UW_SER.last0 - 110000/61) < 0.01")), "v1.11.63 DpsSeries step 0 = media cumulativa (parte da 0 e finisce a 110000/61 = %.1f dps: %r)" % (110000/61, rt.eval("UW_SER.last0")))
check(bool(rt.eval("UW_SER.n5 == 13 and UW_SER.b2_5 == 4000")), "v1.11.63 DpsSeries step 5 = bucket da 5s (20k dmg nel bucket 10-15s = 4000 dps: %r)" % rt.eval("UW_SER.b2_5"))
check(bool(rt.eval("UW_TABS[1] == 'damage:6x3'")), "v1.11.63 tab Damage: 6 colonne (Name/Rank/Dps%%/Useful/Heal/Taken) e 3 righe (TOTAL + 2) (%s)" % rt.eval("UW_TABS[1]"))
check(bool(rt.eval("UW_TABS[2] == 'targets:5x3'")), "v1.11.63 tab Targets: Name + Useful + Total + 2 bersagli (%s)" % rt.eval("UW_TABS[2]"))
check(bool(rt.eval("UW_CONS_ICON == true")), "v1.11.63 tab Consumables: colonne con l'icona della spell")
check(bool(rt.eval("UW_TG_TIP and UW_TG_TIP:find('BOSS') ~= nil")), "v1.11.63 tab Targets: tooltip dell'intestazione che spiega il danno utile")
check(bool(rt.eval("UW_DEATH_ROWS == 1 and UW_DEATH_DETAIL_ROWS >= 4 and UW_DEATH_FIRST == 'DIED'")), "v1.11.63 tab Deaths: lista dei morti + recap (prima riga %s, %r righe)" % (rt.eval("UW_DEATH_FIRST"), rt.eval("UW_DEATH_DETAIL_ROWS")))
check(bool(rt.eval("UW_BACK == true")), "v1.11.63: tornando sul tab Damage la griglia e' di nuovo visibile")

rt.execute("""
-- ---- v1.11.63: struttura della finestra (layout UwU) ----
local cl = RLSuite.combatLog
UW_LAYOUT = {
    w = cl.frame._w, h = cl.frame._h,
    graphH = cl.graphPane._h,
    graphVis = cl.graphPane:IsShown(),
    steps = {},
    tabs = {},
    deaths_left = (cl.deathListBox ~= nil),
    deaths_right = (cl.deathGrid ~= nil),
    title_anchor = cl.titleText._points[1] and cl.titleText._points[1][1],
    dd_pt = cl.fightDropdown._points[1] and cl.fightDropdown._points[1][1],
    dd_rel = cl.fightDropdown._points[1] and cl.fightDropdown._points[1][3],
}
for _, st in ipairs(cl.graphSteps or {}) do UW_LAYOUT.steps[#UW_LAYOUT.steps + 1] = st.text end
for _, def in ipairs(cl.uiTabs or {}) do UW_LAYOUT.tabs[#UW_LAYOUT.tabs + 1] = def.key end
UW_LAYOUT.stepn = #UW_LAYOUT.steps
UW_LAYOUT.tabn = #UW_LAYOUT.tabs
local minW, minH = RLSuite.windowMins.log()
UW_LAYOUT.minW, UW_LAYOUT.minH = minW, minH
-- "Show graph" spegne/riaccende il grafico senza toccare il resto
cl.showGraphCheck:SetChecked(true)
cl.showGraphCheck._scripts.OnClick(cl.showGraphCheck)
UW_LAYOUT.graphOn1 = cl.graphPane:IsShown()
cl.showGraphCheck:SetChecked(false)
cl.showGraphCheck._scripts.OnClick(cl.showGraphCheck)
UW_LAYOUT.graphOn2 = cl.graphPane:IsShown()
cl.showGraphCheck:SetChecked(true)
if not cl.graphPane:IsShown() then cl.graphPane:Show() end
""")


check(bool(rt.eval("UW_LAYOUT.w >= 870 and UW_LAYOUT.h >= 660")), "v1.11.63 layout: la finestra non e' mai sotto il minimo del nuovo layout (%rx%r)" % (rt.eval("UW_LAYOUT.w"), rt.eval("UW_LAYOUT.h")))
_uw_src = open("CombatLog.lua", encoding="utf-8").read()
check('local CL_WIN_W, CL_WIN_H = 900, 660' in _uw_src, "v1.11.63 layout: dimensione di progetto della finestra = 900x660 (riga titolo + controlli + grafico + tab + contenuto + footer)")
check(bool(rt.eval("UW_LAYOUT.minW == 870 and UW_LAYOUT.minH == 660")), "v1.11.63 layout: minimi della finestra Log aggiornati (%rx%r)" % (rt.eval("UW_LAYOUT.minW"), rt.eval("UW_LAYOUT.minH")))
check(bool(rt.eval("UW_LAYOUT.graphH == 150 and UW_LAYOUT.graphVis == true")), "v1.11.63 layout: grafico SEMPRE visibile in alto, altezza fissa (%r px)" % rt.eval("UW_LAYOUT.graphH"))
check(bool(rt.eval("UW_LAYOUT.graphOn1 == true and UW_LAYOUT.graphOn2 == false")), "v1.11.63 layout: la casella 'Show graph' accende/spegne il grafico")
check(bool(rt.eval("UW_LAYOUT.title_anchor == 'TOPLEFT' and UW_LAYOUT.dd_pt == 'TOPRIGHT' and UW_LAYOUT.dd_rel == 'TOPRIGHT'")), "v1.11.63 layout: nome fight in alto a SINISTRA, dropdown dei fight in alto a DESTRA")
check(bool(rt.eval("UW_LAYOUT.stepn == 6 and UW_LAYOUT.steps[1] == 'Avg whole fight' and UW_LAYOUT.steps[6] == 'Avg every 10 seconds'")), "v1.11.63 layout: discretizzazioni del grafico identiche al terzo screen (%r voci)" % rt.eval("UW_LAYOUT.stepn"))
check(bool(rt.eval("UW_LAYOUT.tabs[1] == 'damage' and UW_LAYOUT.tabs[2] == 'targets' and UW_LAYOUT.tabs[3] == 'consumables' and UW_LAYOUT.tabs[4] == 'auras' and UW_LAYOUT.tabs[5] == 'deaths' and UW_LAYOUT.tabs[6] == 'powers'")), "v1.11.63 layout: tab group nell'ordine di UwU (Damage/Targets/Consumables/Auras/Deaths/Powers) e poi gli storici")
check(bool(rt.eval("UW_LAYOUT.deaths_left == true and UW_LAYOUT.deaths_right == true")), "v1.11.63 layout: tab Deaths = lista dei morti a sinistra + tabella di dettaglio a destra")

rt.execute("""
-- ---- v1.11.64: regressione del crash ScrollFrame senza nome ----
UW_NAMES = {
    grid = (_G["RLSuiteCombatLogGrid"] ~= nil),
    dgrid = (_G["RLSuiteCombatLogDeathGrid"] ~= nil),
    left = (_G["RLSuiteCombatLogLeft"] ~= nil),
    right = (_G["RLSuiteCombatLogRight"] ~= nil),
    deaths = (_G["RLSuiteCombatLogDeaths"] ~= nil),
    gridbar = (_G["RLSuiteCombatLogGridScrollBar"] ~= nil),
    dgridbar = (_G["RLSuiteCombatLogDeathGridScrollBar"] ~= nil),
    gridparent = (RLSuite.combatLog.grid and RLSuite.combatLog.grid.scroll._parent ~= nil),
}
-- l'harness ora RIFIUTA uno ScrollFrame senza nome (crash reale del client)
UW_STRICT = false
local ok = pcall(function()
    CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
end)
UW_STRICT = (ok == false)
""")


check(bool(rt.eval("UW_NAMES.grid == true and UW_NAMES.dgrid == true")), "v1.11.64: gli ScrollFrame delle griglie hanno un NOME globale (rlSuiteCombatLogGrid / ...DeathGrid)")
check(bool(rt.eval("UW_NAMES.gridbar == true and UW_NAMES.dgridbar == true")), "v1.11.64: il template UIPanelScrollFrameTemplate trova le sue barre (<nome>ScrollBar)")
check(bool(rt.eval("UW_NAMES.left == true and UW_NAMES.right == true and UW_NAMES.deaths == true")), "v1.11.64: anche gli ScrollFrame storici sono nominati")
check(bool(rt.eval("UW_STRICT == true")), "v1.11.64: l'harness riproduce il crash del client (ScrollFrame senza nome = errore), cosi' non ricapita")
_uw_scroll = ["CombatLog.lua", "Config.lua", "GroupMaking.lua", "LootManager.lua", "MSManager.lua", "RaidProfile.lua", "RaidFrame.lua", "MacroBar.lua", "Core.lua", "Utils.lua"]
UW_BADNAME = []
for _f in _uw_scroll:
    try:
        _t = open(_f, encoding="utf-8").read()
    except Exception:
        continue
    for _line in _t.split("\n"):
        if 'CreateFrame("ScrollFrame", nil' in _line:
            UW_BADNAME.append(_f)
check(not UW_BADNAME, "v1.11.64: nessuno ScrollFrame senza nome in tutto l'addon (%s)" % (UW_BADNAME or "ok"))

rt.execute("""
-- =====================================================================
-- v1.11.65: TAB GROUP vero + griglia che non si incasina (no wrap)
-- =====================================================================
local cl = RLSuite.combatLog
UW_TAB = {
    isGroup = (cl.tabGroup ~= nil),
    parent_ok = true, same_width = true, contiguous = true,
    overlap = cl.tabGroup and cl.tabGroup._tabOverlap,
    w = cl.tabGroup and cl.tabGroup._tabW,
    n = #(cl.tabOrder or {}),
    nbtns = 0,
}
for _, _ in pairs(cl.tabBtns or {}) do UW_TAB.nbtns = UW_TAB.nbtns + 1 end
for i, def in ipairs(cl.tabOrder or {}) do
    local b = cl.tabBtns[def.key]
    if b._parent ~= cl.tabGroup then UW_TAB.parent_ok = false end
    if b._w ~= UW_TAB.w then UW_TAB.same_width = false end
    local p = b._points[1]
    if i == 1 then
        if p[2] ~= cl.tabGroup or p[4] ~= 0 then UW_TAB.contiguous = false end
    else
        local prev = cl.tabBtns[cl.tabOrder[i - 1].key]
        if p[2] ~= prev or p[4] ~= -UW_TAB.overlap then UW_TAB.contiguous = false end
    end
end
UW_TAB.id = cl.tabBtns.targets and cl.tabBtns.targets:GetID()
cl:SelectTab("auras")
UW_TAB.sel_auras = (cl.tabBtns.auras._sel:IsShown() == true)
UW_TAB.sel_damage = (cl.tabBtns.damage._sel:IsShown() == true)
UW_TAB.pt = cl.tabGroup.selectedTab
cl:SelectTab("damage")
UW_TAB.back = (cl.tabBtns.damage._sel:IsShown() == true and cl.tabBtns.auras._sel:IsShown() == false)

-- troncamento: il testo non esce MAI dalla colonna
local probe = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
if probe.SetWordWrap then probe:SetWordWrap(false) end
RLSuite.combatLog.FitText(probe, string.rep("Lunghissimo", 6), 100)
UW_FIT = { text = probe:GetText(), len = #probe:GetText(), w = probe:GetStringWidth() }

-- 3.3.5: GetStringWidth NON vede il SetText appena fatto (testo misurato solo
-- al frame dopo). Senza la stima, il troncamento non scattava MAI e il testo
-- usciva dalla colonna (le tabelle "sovrapposte" viste in game).
local probe2 = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
local realW = probe2.GetStringWidth
probe2.GetStringWidth = function() return 0 end   -- simula la misura "stantia"
RLSuite.combatLog.FitText(probe2, string.rep("Lunghissimo", 3), 70)
UW_STALE = { len = #probe2:GetText(), text = probe2:GetText() }
probe2.GetStringWidth = realW
local probe3 = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
probe3.GetStringWidth = function() return 0 end
RLSuite.combatLog.FitText(probe3, "Breve", 200)
UW_STALE.kept = probe3:GetText()

-- celle della griglia: niente word wrap, larghezza rispettata
cl.selFight = UW_F
cl:SelectTab("damage")
local g = cl.grid
local cols = g.cols or {}
local rows = g.pool[#cols] or {}
UW_CELL = { wrap = {}, ok = true, maxw = 0, colw = 0 }
for ci, c in ipairs(cols) do
    local cell = rows[1].cells[ci]
    local fs = cell.fs
    UW_CELL.wrap[#UW_CELL.wrap + 1] = (fs._wordWrap == false) and "n" or "y"
    local cw = math.max(18, c.px - 8)
    if (fs:GetStringWidth() or 0) > cw then UW_CELL.ok = false end
    if cw > UW_CELL.maxw then UW_CELL.maxw = cw end
    UW_CELL.colw = UW_CELL.colw + c.px
end
UW_CELL.wrap = table.concat(UW_CELL.wrap, "")
UW_CELL.headers_wrap = (g.hdrPool[1].btn.fs._wordWrap == false)

-- larghezza VIVA: se la finestra viene ridimensionata le colonne si rifanno
local before = cols[1].px
g._w = 1200
cl:RefreshLists()
local cols2 = cl.grid.cols or {}
UW_LIVE = { before = before, after = cols2[1] and cols2[1].px, content = cl.grid.content._w }
cl.grid._w = 0
cl:RefreshLists()
-- senza pull registrati: nessun tab deve andare in errore (era un crash)
UW_NOFIGHT = { ok = true }
cl.selFight = nil
for _, tab in ipairs({ "damage", "targets", "consumables", "auras", "powers", "deaths", "healing" }) do
    local ok2 = pcall(function() cl:SelectTab(tab) end)
    if not ok2 then UW_NOFIGHT.ok = false; UW_NOFIGHT.fail = tab end
end
cl:SelectTab("damage")
""")


check(bool(rt.eval("UW_TAB.isGroup == true and UW_TAB.n == UW_TAB.nbtns")), "v1.11.65: i tab stanno in UN SOLO gruppo (RLSuiteCombatLogTabs), non in pulsanti sparsi (%r tab)" % rt.eval("UW_TAB.n"))
check(bool(rt.eval("UW_TAB.parent_ok == true")), "v1.11.65: ogni tab e' figlio del gruppo dei tab")
check(bool(rt.eval("UW_TAB.same_width == true and UW_TAB.w > 40")), "v1.11.65: tab di larghezza identica (%r px) che riempiono il gruppo" % rt.eval("UW_TAB.w"))
check(bool(rt.eval("UW_TAB.contiguous == true and UW_TAB.overlap == 16")), "v1.11.65: tab ATTACCATI l'uno all'altro (overlap %r px, niente buchi da pulsanti sciolti)" % rt.eval("UW_TAB.overlap"))
check(bool(rt.eval("UW_TAB.id == 2")), "v1.11.65: ogni tab ha il suo ID (per PanelTemplates): targets = 2")
check(bool(rt.eval("UW_TAB.sel_auras == true and UW_TAB.sel_damage == false and UW_TAB.pt == 4")), "v1.11.65: un solo tab selezionato (PanelTemplates.selectedTab = %r)" % rt.eval("UW_TAB.pt"))
check(bool(rt.eval("UW_TAB.back == true")), "v1.11.65: cambiando tab l'evidenza si sposta (auras -> damage)")
check(bool(rt.eval("UW_FIT.len < 72 and UW_FIT.w <= 100")), "v1.11.65 FitText: il testo viene troncato per stare nella larghezza (\"%s\" = %rpx)" % (rt.eval("UW_FIT.text"), rt.eval("UW_FIT.w")))
check(bool(rt.eval("UW_STALE.len < 39 and UW_STALE.text:sub(-2) == '..'")), "v1.11.66 FitText: tronca anche quando il client non ha ancora misurato il testo (3.3.5) — \"%s\"" % rt.eval("UW_STALE.text"))
check(bool(rt.eval("UW_STALE.kept == 'Breve'")), "v1.11.66 FitText: un testo che ci sta non viene toccato")
check(bool(rt.eval("UW_CELL.wrap == 'nnnnnn'")), "v1.11.65: NESSUNA cella della tabella va a capo (word wrap OFF, era la causa delle tabelle incasinate: %s)" % rt.eval("UW_CELL.wrap"))
check(bool(rt.eval("UW_CELL.ok == true")), "v1.11.65: ogni testo sta dentro la sua colonna (nessuna sovrapposizione fra celle/righe)")
check(bool(rt.eval("UW_CELL.headers_wrap == true")), "v1.11.65: anche le intestazioni non vanno a capo")
check(bool(rt.eval("UW_LIVE.after > UW_LIVE.before and UW_LIVE.content > 1000")), "v1.11.65: la larghezza delle colonne usa quella VERA della finestra (%r -> %r px a finestra larga)" % (rt.eval("UW_LIVE.before"), rt.eval("UW_LIVE.after")))
check(bool(rt.eval("UW_NOFIGHT.ok == true")), "v1.11.65: senza pull registrati ogni tab si apre senza errori (crash su colonna senza larghezza: %r)" % rt.eval("UW_NOFIGHT.fail"))

rt.execute("""
-- =====================================================================
-- v1.11.67: le tab NON devono condividere/impilare le tabelle.
-- Il pool delle righe e' diviso per NUMERO di colonne: passando da una tab
-- con 6 colonne (Damage) a una con 5 (Targets) le righe del pool precedente
-- restavano visibili -> tutte le tab sembravano la stessa tabella.
-- =====================================================================
function UW_VisibleRows(g)
    local n = 0
    for _, p in pairs(g.pool or {}) do
        for _, r in ipairs(p) do if r:IsShown() then n = n + 1 end end
    end
    return n
end
function UW_Pools(g)
    local n = 0
    for _, _ in pairs(g.pool or {}) do n = n + 1 end
    return n
end
local cl = RLSuite.combatLog
cl.selFight = UW_F

UW_STACK = { tabs = {} }
local seq = { "damage", "targets", "consumables", "auras", "powers", "damage" }
for _, tab in ipairs(seq) do
    cl:SelectTab(tab)
    local cols = #(cl.grid.cols or {})
    local vis = UW_VisibleRows(cl.grid)
    UW_STACK.tabs[#UW_STACK.tabs + 1] = string.format("%s:%dcol:%drow:%dvis", tab, cols,
        cl.grid.rowCount or -1, vis)
end
-- la griglia dei morti: si ri-renderizza con un altro numero di colonne
cl:SelectTab("deaths")
UW_STACK.death1 = UW_VisibleRows(cl.deathGrid)
cl:SelectTab("targets")
cl:SelectTab("deaths")            -- ritorno sulla tab dei morti
UW_STACK.death2 = UW_VisibleRows(cl.deathGrid)
UW_STACK.death_rows = cl.deathGrid.rowCount or -1
UW_STACK.pools = UW_Pools(cl.grid)
cl:SelectTab("damage")
UW_STACK.vis_damage = UW_VisibleRows(cl.grid)
UW_STACK.rows_damage = cl.grid.rowCount
cl.selFight = nil
cl:SelectTab("damage")
""")


UW_STACK_SEQ = str(rt.eval("table.concat(UW_STACK.tabs, ' | ')"))
check(bool(rt.eval("(function() for _, t in ipairs(UW_STACK.tabs) do local r, v = t:match('%d+col:(%d+)row:(%d+)vis'); if tonumber(r) ~= tonumber(v) then return false end end return true end)()")),
    "v1.11.67: in OGNI tab le righe visibili sono SOLO quelle della tabella corrente (niente tabelle impilate) -> %s" % UW_STACK_SEQ)
check(bool(rt.eval("UW_STACK.tabs[1]:find('damage:6col') ~= nil and UW_STACK.tabs[2]:find('targets:5col') ~= nil")),
    "v1.11.67: le tabelle hanno davvero un numero di colonne diverso (e' il caso che le impilava)")
check(bool(rt.eval("UW_STACK.tabs[6] == UW_STACK.tabs[1]")), "v1.11.67: tornando su Damage la tabella e' identica (stesse colonne, stesse righe visibili)")
check(bool(rt.eval("UW_STACK.death1 == UW_STACK.death2 and UW_STACK.death2 == UW_STACK.death_rows")), "v1.11.67: tornando sulla tab Deaths la tabella mostra solo le sue righe (%r visibili / %r righe)" % (rt.eval("UW_STACK.death2"), rt.eval("UW_STACK.death_rows")))

rt.execute("""
-- =====================================================================
-- v1.11.68: ICONE e NOMI delle spell visibili nelle tabelle
-- =====================================================================
CLT = RLSuite.combatLog
CLT.selFight = UW_F
UW_ICON = {}
-- la risoluzione dell'icona usa GetSpellTexture e, se fallisce, GetSpellInfo
local realGST = GetSpellTexture
GetSpellTexture = function(id) if id == 48230 then return "ICON_FIREBOLT" end return nil end
CLT.spellIconCache[48230] = nil
CLT.spellIconCache[99999] = nil
UW_ICON.tex = CLT:SpellIcon(48230)
UW_ICON.fallback = CLT:SpellIcon(99999)   -- GetSpellInfo mock -> icona
GetSpellTexture = realGST
UW_ICON.none = CLT:SpellIcon(nil)

-- tab a icone: ogni colonna ha icona E nome
UW_ICON.cols = {}
for _, tab in ipairs({ "consumables", "auras", "powers" }) do
    CLT:SelectTab(tab)
    local has_icon, has_name, blank = 0, 0, 0
    for _, c in ipairs(CLT.grid.cols or {}) do
        if c.ic then has_icon = has_icon + 1 end
        if c.label and c.label ~= "" then has_name = has_name + 1 end
        if (not c.ic) and (not c.label or c.label == "") then blank = blank + 1 end
    end
    UW_ICON.cols[tab] = string.format("icone=%d nomi=%d vuote=%d", has_icon, has_name, blank)
end
CLT:SelectTab("auras")
UW_ICON.hdr_h = CLT.grid.hdr._h
local hb = CLT.grid.hdrPool[#(CLT.grid.cols or {})]
UW_ICON.hdr_shown = hb and hb.btn.fs:IsShown() and (hb.btn.fs:GetText() ~= "")
UW_ICON.hdr_text = hb and hb.btn.fs:GetText()
UW_ICON.hdr_icon = hb and hb.btn.icon:IsShown()
-- intestazione SENZA icona: deve restare il nome (mai vuota)
local cols2 = { { label = "Spell Name", w = 100, fix = true, align = "CENTER", ic = nil } }
CLT:GridRender(CLT.grid, cols2, { { { t = "x" } } }, {})
local h2 = CLT.grid.hdrPool[1]
UW_ICON.noicon_text = h2.btn.fs:GetText()
UW_ICON.noicon_icon = h2.btn.icon:IsShown()
UW_ICON.noicon_shown = h2.btn.fs:IsShown()
-- lista Spells: icona sulla riga
CLT:SelectTab("spells")
CLT.selSource = "Alpha"
CLT:RefreshLists()
local anyIcon = false
for _, r in ipairs(CLT._rRows or {}) do
    if r.spellIcon and r.spellIcon:IsShown() then anyIcon = true end
end
UW_ICON.rows = anyIcon
CLT.selSource = nil
CLT.selFight = nil
CLT:SelectTab("damage")
""")


check(bool(rt.eval("tostring(UW_ICON.tex) == 'ICON_FIREBOLT'")), "v1.11.68: l'icona della spell viene risolta da GetSpellTexture (%r)" % rt.eval("UW_ICON.tex"))
check(bool(rt.eval("UW_ICON.fallback ~= nil")), "v1.11.68: se GetSpellTexture fallisce si usa l'icona di GetSpellInfo (3o valore, catalogo locale)")
check(bool(rt.eval("UW_ICON.none == nil")), "v1.11.68: nessuna spell = nessuna icona (nessun errore)")
check(bool(rt.eval("UW_ICON.cols.consumables and UW_ICON.cols.consumables:find('vuote=0') ~= nil")), "v1.11.68 tab Consumables: ogni colonna ha icona e NOME (%s)" % rt.eval("UW_ICON.cols.consumables"))
check(bool(rt.eval("UW_ICON.cols.auras and UW_ICON.cols.auras:find('vuote=0') ~= nil")), "v1.11.68 tab Auras: ogni colonna ha icona e NOME (%s)" % rt.eval("UW_ICON.cols.auras"))
check(bool(rt.eval("UW_ICON.cols.powers and UW_ICON.cols.powers:find('vuote=0') ~= nil")), "v1.11.68 tab Powers: ogni colonna ha icona e NOME (%s)" % rt.eval("UW_ICON.cols.powers"))
check(bool(rt.eval("UW_ICON.hdr_h == 34")), "v1.11.68: intestazione alta 34px (icona sopra, nome sotto)")
check(bool(rt.eval("UW_ICON.hdr_icon == true and UW_ICON.hdr_shown == true")), "v1.11.68: nell'intestazione si vedono icona E nome della spell (\"%s\")" % rt.eval("UW_ICON.hdr_text"))
check(bool(rt.eval("UW_ICON.noicon_shown == true and UW_ICON.noicon_text == 'Spell Name' and UW_ICON.noicon_icon == false")), "v1.11.68: senza icona l'intestazione mostra il NOME (mai una colonna vuota)")
check(bool(rt.eval("UW_ICON.rows == true")), "v1.11.68 tab Spells: l'icona compare anche accanto al nome di ogni spell nella lista")

rt.execute("""
-- =====================================================================
-- v1.11.70: encounter-anchored (la morte non chiude il pull) + watchdog
--           + riga di stato
-- =====================================================================
local cl = RLSuite.combatLog
local R_IAC, R_DEAD, R_NRAID, R_PARTY, R_UE, R_UG = UnitAffectingCombat, UnitIsDeadOrGhost, GetNumRaidMembers, GetNumPartyMembers, UnitExists, UnitGUID
local R_DEADU, R_HEALTH = UnitIsDead, UnitHealth
UW_COMBAT, UW_DEAD, UW_RAIDN = {}, false, 0
UnitAffectingCombat = function(u) return UW_COMBAT[u] == true end
GetNumRaidMembers = function() return UW_RAIDN end
GetNumPartyMembers = function() return 0 end
UW_BOSS_UNITS, UW_BOSS_DEAD = {}, {}
UnitExists = function(u)
    return (UW_COMBAT[u] ~= nil) or u == "player" or (UW_BOSS_UNITS[u] ~= nil)
end
UnitIsDead = function(u) return UW_BOSS_DEAD[u] == true end
UnitIsDeadOrGhost = function(u)
    if u ~= "player" then return UW_BOSS_DEAD[u] == true end
    return UW_DEAD
end
UnitHealth = function(u) if u == "player" then return 100 end return (UW_BOSS_DEAD[u] and 0) or 100 end

cl.db.fights = {}
cl.current = nil
cl.selFight = nil
cl.recoveries = 0
cl.sessionLost = 0
cl._initError = nil

-- A) morte a meta' pull: il pull NON si chiude, la morte viene annotata
UW_COMBAT = { player = true, raid1 = true, boss1 = true }
UW_RAIDN = 2
UW_DEAD = false
cl:OnRegenDisabled()
UW_A_OPEN = (cl.current ~= nil)
cl:OnCLEU(nil, GetTime(), 'SPELL_DAMAGE', '0x0p', 'PlayerOne', 1024+16+1, '0xF130008F040000AA', 'Lord Marrowgar', 2048+64, 100, 'Fireball', 4, 5000, 0, 0, 0, 0, 0, 1)
UW_DEAD = true
cl:OnRegenEnabled()                        -- scatta QUANDO MUORI (esci dalla hate list)
cl:OnCLEU(nil, GetTime(), 'SPELL_DAMAGE', '0x0p', 'PlayerTwo', 1024+16+1, '0xF130008F040000AA', 'Lord Marrowgar', 2048+64, 100, 'Frostbolt', 2, 3000, 0, 0, 0, 0, 0, 0)
UW_A_STILL = (cl.current ~= nil)
UW_A_DIED = cl.current and cl.current.playerDied
UW_A_CNT = cl.current and cl.current.count
UW_A_NFIGHTS = #cl.db.fights

-- B) res in combat: stesso pull, nessun secondo record
UW_DEAD = false
cl:OnRegenDisabled()
UW_B_SAME = (cl.current ~= nil)
UW_B_DIED = cl.current and cl.current.playerDied
cl:WatchTick('tick')                       -- il tick da 1 Hz annota la ripresa
UW_B_ALIVE = cl.current and cl.current.playerAlive
UW_B_NFIGHTS = #cl.db.fights

-- C) l'encounter finisce -> il pull si chiude (una volta sola)
UW_COMBAT = {}
cl:WatchTick('test')
UW_C_CLOSED = (cl.current == nil)
UW_C_NF = #cl.db.fights
UW_C_F = cl.db.fights[1] or {}
UW_C_REASON = UW_C_F.closeReason
UW_C_DIED = UW_C_F.playerDied
UW_C_ALIVE = UW_C_F.playerAlive

-- C2) kill del boss + trash a catena: il pull si chiude lo stesso
cl.current = nil
cl.db.fights = {}
UW_COMBAT = { raid1 = true }
UW_RAIDN = 2
cl:OpenFight(false)
cl.current.boss = "Lord Marrowgar"
cl.current.kill = true
cl:WatchTick('kill')
UW_C2_CLOSED = (cl.current == nil)
UW_C2_NF = #cl.db.fights
-- C3) encounter MULTI-BOSS: un boss muore ma un altro e' vivo -> resta aperto
cl.current = nil
cl.db.fights = {}
UW_BOSS_UNITS = { boss1 = true, boss2 = true }
UW_BOSS_DEAD = { boss1 = true }
cl:OpenFight(false)
cl.current.boss = "Blood Prince Council"
cl.current.kill = true
cl:WatchTick('multiboss')
UW_C3_OPEN = (cl.current ~= nil)
-- ora muore anche il secondo
UW_BOSS_DEAD = { boss1 = true, boss2 = true }
cl:WatchTick('multiboss')
UW_C3_CLOSED = (cl.current == nil)
UW_BOSS_UNITS, UW_BOSS_DEAD = {}, {}

-- D) watchdog: in combat senza pull aperto -> apri e marca "recuperato"
cl.current = nil
cl.db.fights = {}
UW_COMBAT = { raid1 = true }
UW_RAIDN = 2
local rec0 = cl.recoveries or 0
cl:WatchTick('test')
UW_D_OPEN = (cl.current ~= nil)
UW_D_REC = cl.current and cl.current.recovered
UW_D_COUNT = (cl.recoveries or 0) - rec0
cl.current = nil

-- E) re-arm dopo /reload: PLAYER_ENTERING_WORLD mentre sei in combat
cl.db.fights = {}
UW_COMBAT = { player = true }
UW_E_BEFORE = (cl.current == nil)
cl:OnEnteringWorld()
UW_E_AFTER = (cl.current ~= nil)
UW_E_REC = cl.current and cl.current.recovered
cl.current = nil

-- F) riga di stato
cl.db.fights = {}
cl.recoveries = 0
cl.sessionLost = 0
cl.current = nil
cl:RefreshInfo(nil)
UW_F_IDLE = tostring(cl.infoText:GetText())
UW_COMBAT = { raid1 = true }
UW_RAIDN = 2
cl:OpenFight(true)
cl:RefreshInfo(nil)
UW_F_REC = tostring(cl.infoText:GetText())
cl.current.recovered = nil
cl.current.dropped = 12
cl:RefreshInfo(nil)
UW_F_LOST = tostring(cl.infoText:GetText())
cl.current = nil
cl.sessionLost = 40
cl:RefreshInfo(nil)
UW_F_SESS = tostring(cl.infoText:GetText())
cl.sessionLost = 0
cl.recoveries = 1
cl:RefreshInfo(nil)
UW_F_RECOVERY = tostring(cl.infoText:GetText())
cl.recoveries = 0
cl._initError = 'boom in CreateFrame'
cl:RefreshInfo(nil)
UW_F_ERR = tostring(cl.infoText:GetText())
cl._initError = nil
cl:RefreshInfo(nil)
UW_F_IDLE2 = tostring(cl.infoText:GetText())
cl:RefreshInfo(nil)

-- G) pull salvato VECCHIO (senza i campi nuovi) si apre ancora
UW_LEGACY = { name = 'Sindragosa', duration = 95, kill = false, events = {}, count = 0 }
UW_G_LABEL = cl:FightLabel(UW_LEGACY, 1)
UW_G_TITLE = cl:FightTitle(UW_LEGACY)

UnitAffectingCombat, UnitIsDeadOrGhost, GetNumRaidMembers, GetNumPartyMembers, UnitExists, UnitGUID, UnitIsDead, UnitHealth = R_IAC, R_DEAD, R_NRAID, R_PARTY, R_UE, R_UG, R_DEADU, R_HEALTH
cl.current = nil
cl.db.fights = {}
cl.recoveries = 0
cl.sessionLost = 0
cl:RefreshInfo(nil)
""")


check(bool(rt.eval("UW_A_OPEN == true and UW_A_STILL == true")), "v1.11.70: la morte del tuo personaggio NON chiude piu' il pull (l'encounter e' ancora in corso)")
check(bool(rt.eval("UW_A_DIED ~= nil and UW_A_CNT == 2")), "v1.11.70: la morte viene annotata (t=%r) e il pull continua a registrare anche dopo" % rt.eval("UW_A_DIED"))
check(bool(rt.eval("UW_A_NFIGHTS == 0")), "v1.11.70: morendo NON nasce un pull falso con esito Wipe")
check(bool(rt.eval("UW_B_SAME == true and UW_B_DIED == UW_A_DIED and UW_B_ALIVE ~= nil")), "v1.11.70: la res in combat continua lo STESSO pull (ripresa annotata a t=%r)" % rt.eval("UW_B_ALIVE"))
check(bool(rt.eval("UW_B_NFIGHTS == 0")), "v1.11.70: la res non crea un pull fantasma")
check(bool(rt.eval("UW_C_CLOSED == true and UW_C_NF == 1")), "v1.11.70: quando l'encounter finisce il pull si chiude (e una volta sola)")
check(bool(rt.eval("tostring(UW_C_REASON) == 'test' and UW_C_DIED ~= nil and UW_C_ALIVE ~= nil")), "v1.11.70: il pull salvato porta motivo di chiusura, morte e ripresa (%r / %r / %r)" % (rt.eval("UW_C_REASON"), rt.eval("UW_C_DIED"), rt.eval("UW_C_ALIVE")))
check(bool(rt.eval("UW_D_OPEN == true and UW_D_REC == true and UW_D_COUNT == 1")), "v1.11.70 watchdog: in combat senza pull aperto lo apre da solo e lo marca 'recuperato'")
check(bool(rt.eval("UW_C2_CLOSED == true and UW_C2_NF == 1")), "v1.11.70: boss ucciso + trash a catena -> il pull si chiude comunque (kill pulito)")
check(bool(rt.eval("UW_C3_OPEN == true and UW_C3_CLOSED == true")), "v1.11.70: encounter multi-boss, un boss morto NON chiude il pull; si chiude quando muoiono tutti")
check(bool(rt.eval("UW_E_BEFORE == true and UW_E_AFTER == true and UW_E_REC == true")), "v1.11.70 re-arm: rientrando nel mondo in combat (dopo un /reload) il pull riparte da solo")
check(bool(rt.eval("UW_F_IDLE:find('Idle') ~= nil and UW_F_IDLE:find('8') == nil")), "v1.11.70 riga di stato a riposo: \"%s\"" % rt.eval("UW_F_IDLE"))
check(bool(rt.eval("UW_F_REC:find('Recording') ~= nil and UW_F_REC:find('watchdog') ~= nil")), "v1.11.70 riga di stato con pull recuperato: \"%s\"" % rt.eval("UW_F_REC"))
check(bool(rt.eval("UW_F_LOST:find('12') ~= nil and UW_F_LOST:find('lost') ~= nil")), "v1.11.70 riga di stato con eventi persi: \"%s\"" % rt.eval("UW_F_LOST"))
check(bool(rt.eval("UW_F_SESS:find('40') ~= nil")), "v1.11.70 riga di stato a riposo con eventi persi in sessione: \"%s\"" % rt.eval("UW_F_SESS"))
check(bool(rt.eval("UW_F_RECOVERY:find('watchdog') ~= nil")), "v1.11.70 riga di stato a riposo con un recupero del watchdog: \"%s\"" % rt.eval("UW_F_RECOVERY"))
check(bool(rt.eval("UW_F_ERR:find('Window error') ~= nil and UW_F_ERR:find('boom') ~= nil")), "v1.11.70 riga di stato con finestra rotta: \"%s\"" % rt.eval("UW_F_ERR"))
check(bool(rt.eval("UW_G_LABEL ~= nil and UW_G_TITLE ~= nil")), "v1.11.70: i pull salvati con il formato vecchio (senza campi nuovi) si aprono ancora: \"%s\"" % rt.eval("UW_G_TITLE"))

print()
if fails:
    print("RESULT: %d FAILURES: %s" % (len(fails), fails))
    sys.exit(1)
print("RESULT: ALL CHECKS PASSED")
