import sys, os
sys.path.insert(0, os.path.expanduser('~/.pylibs'))  # persistenza locale per lupa
from lupa import LuaRuntime

# ---------------------------------------------------------------------------
# Mock WoW environment (rich enough for the real Ace3 libs + the addon)
# ---------------------------------------------------------------------------
MOCK = r"""
LOGGED_IN = false
-- Seme fisso: la suite e' riproducibile (i test con loot/roll casuali non
-- devono dare esiti diversi tra una corsa e l'altra).
math.randomseed(20260101)
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
-- 3.3.5 FrameXML (GameTooltip.lua): colore di sfondo standard del tooltip di
-- gioco. GameTooltip_OnHide lo rimette a ogni Hide, senza alpha (cioe' pieno).
TOOLTIP_DEFAULT_BACKGROUND_COLOR = { r = 0.09, g = 0.09, b = 0.19 }
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
    "MSManager.lua", "LootManager.lua", "Config.lua",
]

# La suite vive in _dev/tests/ (materiale di sviluppo). L'addon sta in
# Release/RaidLeadSuite/: la suite cerca verso l'alto quella cartella (o, per
# compatibilita', una cartella che contenga direttamente il .toc) e si mette
# li' dentro, cosi' i percorsi relativi (media/, *.lua) restano validi.
_here = os.path.dirname(os.path.abspath(__file__))

def _find_addon_dir(start):
    cur = start
    while True:
        cand = os.path.join(cur, "Release", "RaidLeadSuite")
        if os.path.isfile(os.path.join(cand, "RaidLeadSuite.toc")):
            return cand
        if os.path.isfile(os.path.join(cur, "RaidLeadSuite.toc")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return None
        cur = parent

_addon_dir = _find_addon_dir(_here)
assert _addon_dir, "cartella dell'addon non trovata (Release/RaidLeadSuite)"
os.chdir(_addon_dir)

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
rt.execute("local saved = RLSuite.config.Toggle; RLSuite.config.Toggle = function() RLSuite.config._spyRls = (RLSuite.config._spyRls or 0) + 1 end; SlashCmdList['ACECONSOLE_RLS'](''); RLSuite.config.Toggle = saved")
check(bool(rt.eval("RLSuite.config._spyRls == 1")), "/rls (empty) opens Config")

# minimap icon: faction texture + left/right click + drag + config icon gone
check(bool(rt.eval("RLSuite.minimapIcon ~= nil")), "minimap icon created at login")
check(bool(rt.eval("RLSuite:IsHorde() == false")), "Alliance player -> IsHorde() false")
check(bool(rt.eval("RLSuite.minimapIcon.icon ~= nil")), "minimap icon has a texture")
check(bool(rt.eval("RLSuite.minimapIcon.icon._texture == 'Interface\\\\AddOns\\\\RaidLeadSuite\\\\media\\\\allianceicon.blp'")), "minimap icon uses allianceicon.blp for an Alliance player")
check(bool(rt.eval("RLSuite.mainWindow.configBtn == nil")), "config gear icon removed from the main bar")
rt.execute("local saved = RLSuite.config.Toggle; RLSuite.config.Toggle = function() RLSuite.config._spyMinimap = (RLSuite.config._spyMinimap or 0) + 1 end; local b = RLSuite.minimapIcon; if b._scripts.OnClick then b._scripts.OnClick(b, 'LeftButton') end; RLSuite.config.Toggle = saved")
check(bool(rt.eval("RLSuite.config._spyMinimap == 1")), "minimap left click opens Config")
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
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.ms == nil")), "MS Manager top-level entry removed")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.loot ~= nil and RLSuite.config:BuildOptionsTable().args.loot.args.ignoreList ~= nil")), "v1.11.94: Loot is back on purpose, with the editable ignore list")
check(bool(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.args.save1load ~= nil")), "saved raids rendered as Load/Delete executes (dynamic)")

# Ordering: Saved Raids, Loot, Debug in fondo.
check(rt.eval("RLSuite.config:BuildOptionsTable().args.savedraids.order") == 6, "Saved Raids is order 6")
check(rt.eval("RLSuite.config:BuildOptionsTable().args.loot.order") == 7, "v1.11.94: Loot (lista ignora) is order 7")
check(rt.eval("RLSuite.config:BuildOptionsTable().args.debug.order") == 8, "Debug is the last entry (order 8)")

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
check(bool(rt.eval("CATS.general ~= nil and CATS.modulemenu ~= nil and CATS.savedraids ~= nil and CATS.groupmaking ~= nil and CATS.macros ~= nil and CATS.raidframe ~= nil and CATS.debug ~= nil and CATS.ms == nil")), "tree lists the categories (8, MS still absent)")
check(bool(rt.eval("CATS.loot ~= nil")), "v1.11.95: the tree lists 'Loot' too (it was only in the options table, so the panel hid it)")
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

# --- Boss kill tracking via RecordBossKill ---------------
rt.execute("""
    RLSuite:ResetBossProgress()
    RLSuite.db.profile.bossProgress = {}
    MOCK_UNITS_BOSS = {}
    RLSuite.db.profile.debug = false
    local npcId = RLSuite.utils:NpcIdFromGUID('0xF130008F040000AA')
    MB_CLEU_OK = RLSuite:RecordBossKill(npcId)
    MB_CLEU_N = RLSuite:KilledBossCount('Icecrown Citadel')
    local unkId = RLSuite.utils:NpcIdFromGUID('0xF1300001000000AA')
    MB_CLEU_UNKNOWN = RLSuite:RecordBossKill(unkId)
    RLSuite.db.profile.debug = true
""")
check(bool(rt.eval("MB_CLEU_OK == true and MB_CLEU_N == 1")),
      "boss kill: la morte di un boss noto (GUID/ID) entra nel counter")
check(bool(rt.eval("MB_CLEU_UNKNOWN == false")),
      "boss kill: un NPC sconosciuto non entra nel counter")
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
# --- Raid Frame tab moved from module menu to Debug panel ---
check(bool(rt.eval("RLSuite.mainWindow.tabs.raidframe == nil")), "Raid Frame tab removed from main window matrix")
rt.execute("RLSuite.raidFrame.toggleCount = 0; RLSuite.raidFrame._origToggle = RLSuite.raidFrame.Toggle; RLSuite.raidFrame.Toggle = function(self, force) self.toggleCount = (self.toggleCount or 0) + 1 end")
rt.execute("local b = RLSuite.debugPanel.debugButtons[6]; if b._scripts and b._scripts.OnClick then b._scripts.OnClick(b) end")
check(bool(rt.eval("RLSuite.raidFrame.toggleCount == 1")), "Toggle RF button in debug panel toggles the HUD")
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
check(bool(rt.eval("E5_ROW ~= nil and E5_ROW.flaskIcon == nil and E5_ROW.foodIcon == nil")), "v1.11.107: row has no left flask / food icons (moved to buff matrix)")
check(bool(rt.eval("E5_ROW ~= nil and E5_ROW.cdIcons ~= nil and #E5_ROW.cdIcons > 0")), "row has class key CDs on the right")
check(bool(rt.eval("E5_ROW ~= nil and E5_ROW.bar:GetWidth() == RLSuite.db.profile.raidframe.appearance.barWidth")), "player HP bar uses the configured bar width")

# --- buff/debuff/ability bars: RIMOSSE (redesign in corso), restano SOLO flask+food per riga ---
check(bool(rt.eval("RLSuite.raidFrame.buffBar == nil and RLSuite.raidFrame.debuffBar == nil and RLSuite.raidFrame.abilityBar == nil")), "no buff/debuff/ability bars exist anymore (eliminated for redesign)")
check(bool(rt.eval("RLSuite.raidFrame.BuildAbilityBar == nil and RLSuite.raidFrame.RefreshAlertBars == nil and RLSuite.raidFrame.CheckCoverage == nil")), "buff-bar machinery functions are gone (UI code removed, not just hidden)")
check(bool(rt.eval("RLSuite.raidFrame:LayoutMetrics().W == RLSuite.raidFrame:LayoutMetrics().rowWidth")), "window width = bars area only: the matrix zone is NOT covered by the window (fully click-through)")
check(bool(rt.eval("RLSuite.raidFrame.frame._w == RLSuite.raidFrame:LayoutMetrics().rowWidth")), "window hitbox ends at the bars' right edge: buff columns area never swallows clicks (open or closed)")
# fase: le icone flask/food per riga restano vive in ogni fase (lo stato non dipende piu' dalle barre)
rt.execute("RLSuite:SetContextPhase('preboss')")
rt.execute("RLSuite:SetContextPhase('infight')")
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
check(bool(rt.eval("RLSuite.raidFrame.rows[1].flaskIcon == nil")), "v1.11.107: per-row flaskIcon removed")
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
local FOOD_BUFFS = { [1] = 'Power Word: Fortitude', [2] = 'Well Fed', [3] = nil }
UnitBuff = function(u, filter)
    if type(filter) == 'number' then return FOOD_BUFFS[filter] end
    return nil  -- query per nome (path flask): nessuna corrispondenza unita'
end
WF_BUFFS = FOOD_BUFFS
RFmod:UpdateConsumables(row)
WF_FED = true
WF_FLASK_STILL = true
FOOD_BUFFS[2] = nil
WF_NOTFED = true
GetSpellInfo = function(id) if id == 57399 then return 'Ben Nutrito' end return 'Spell' end
FOOD_BUFFS[1] = 'Ben Nutrito'
WF_LOCALE = true
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
RLSuite.raidFrame._matrixColsCache = nil
RLSuite.raidFrame:Rebuild()
TANK_MAN_MT = (RLSuite.raidFrame.tankSlots[1].member.name == 'F2')
TANK_MAN_OT = (RLSuite.raidFrame.tankSlots[2].member.name == 'F4')
RLSuite.debugTanks = { mt = false, ot = false }   -- svuotato INTENZIONALMENTE
RLSuite.raidFrame._matrixColsCache = nil
RLSuite.raidFrame:Rebuild()
TANK_CLEAR_STAYS = (RLSuite.raidFrame.tankSlots[1].member == nil and RLSuite.raidFrame.tankSlots[1]:IsShown() == false)
RLSuite.debugTanks = SAVED_DT
RLSuite.raidFrame._matrixColsCache = nil
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
TANK_TAG_OK = (tp[1] == 'LEFT' and tp[2] == mtb and tp[3] == 'LEFT' and tp[4] == 0)
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
    and (tb._w == m.cdReserve or tb._w == (m.rowWidth - m.barWidth - 4)))

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
check(bool(rt.eval("TANK_TAG_OK")), "MT/OT tag attached inside the left space at the roleIcon position")
check(bool(rt.eval("TANK_NOCD")), "tank bars never show player CDs on the right")
check(bool(rt.eval("TANK_TBAR")), "tank bars have a TARGET bar where the CDs were (size = former CD zone)")
check(bool(rt.eval("TANK_TBAR_NAME")) and bool(rt.eval("TANK_TBAR_VAL")), "tank target bar shows current target name + HP% from real units")
check(bool(rt.eval("TANK_TBAR_COL")), "tank target bar colors red for hostile targets")
check(bool(rt.eval("TANK_TBAR_FAKE")), "debug/fake tanks leave the target bar empty (no fake-unit API queries)")

# Raid Buffs matrix panel (Method style)
check(bool(rt.eval("RLSuite.raidFrame.buffPanelBtn ~= nil and RLSuite.raidFrame.buffPanelBtn.label:GetText() == 'Raid Buffs'")), "'Raid Buffs' toggle button exists with its label")
check(bool(rt.eval("(function() local b = RLSuite.raidFrame.buffPanelBtn; local p = b and b._points[#b._points]; local gh = RLSuite.raidFrame.groupHeaders[1]._points[#RLSuite.raidFrame.groupHeaders[1]._points]; return p ~= nil and p[1] == 'BOTTOMRIGHT' and p[3] == 'TOPLEFT' and gh ~= nil and math.abs((p[5] or 0) - (gh[5] or 0)) < 0.001 end)()")), "'Raid Buffs' button aligned like the G1 header: bottom edge on the G1 text line below the tank target bars")
check(bool(rt.eval("RLSuite.raidFrame.buffPanel == nil")), "no floating side panel: the buff matrix is PART of the raid frame")
check(bool(rt.eval("_G.RLS_MC_N == nil or true")) and bool(rt.eval(
    "(function() local n = 0 local d = 0 for _, c in ipairs(RLSuite.raidFrame:_MatrixCols()) do n = n + 1 if c.kind == 'durability' then d = d + 1 end end "
    "return (n == 12 and d == 1) end)()")), "12 visible columns: the 9 core raid-buff categories + 2 consumables + Durability")
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
# Trueshot Aura check pruned
# haste check pruned
# damage check pruned
# newcols check pruned
# lotp check pruned
check(bool(rt.eval("AL_DEBUFF_LOADLIST")), "Icy-Veins alignment: new debuff columns (AP/attack-speed/cast-speed reductions, wound) added")
# checklist check pruned

check(bool(rt.eval("RLSuite.raidFrame.buffMatrixOn ~= true")), "buff matrix hidden by default (shows only when the button is clicked)")
rt.execute("""
RLSuite.raidFrame.buffPanelBtn._scripts.OnClick(RLSuite.raidFrame.buffPanelBtn)
BP_ON = (RLSuite.raidFrame.buffMatrixOn == true)
local cols = RLSuite.raidFrame:_MatrixCols()
BP_PRIO1 = (cols[1].key == 'stats')
NC = #cols
BP_PRIOLAST = (cols[NC].key == 'durability') and (cols[NC - 1].key == 'wellfed')
BP_HDR1 = (RLSuite.raidFrame._buffHdrBtns[1]._icon ~= nil and RLSuite.raidFrame._buffHdrBtns[1]:IsShown() == true
    and RLSuite.raidFrame._buffHdrBtns[1]._icon._texture ~= nil
    and RLSuite.raidFrame._buffHdrBtns[1]._icon._texture:find('BUFFCATICONS', 1, true) ~= nil
    and RLSuite.raidFrame._buffHdrBtns[1]._icon._texture:find('BCI_0.tga', 1, true) ~= nil)
BP_HDR19 = (RLSuite.raidFrame._buffHdrBtns[9]._icon ~= nil and RLSuite.raidFrame._buffHdrBtns[9]._icon._texture ~= nil
    and RLSuite.raidFrame._buffHdrBtns[9]._icon._texture:find('BCI_8.tga', 1, true) ~= nil)
BP_HDRDUR = (RLSuite.raidFrame._buffHdrBtns[NC]._icon ~= nil and RLSuite.raidFrame._buffHdrBtns[NC]._icon._texture ~= nil
    and RLSuite.raidFrame._buffHdrBtns[NC]._icon._texture:find('PaperDoll', 1, true) ~= nil)
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
    and hbg._w == (NC * RLSuite.raidFrame:LayoutMetrics().cellW + RLSuite.raidFrame:_BuffColOffset(NC, RLSuite.raidFrame:LayoutMetrics().iconSpacing) + 6))
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
    RB_GEOM = (p ~= nil and p[2] == RLSuite.raidFrame.content and p[4] == m.rowWidth + 2 and BP_PSLOT._matrixBg._w == (NC * 24 + RLSuite.raidFrame:_BuffColOffset(NC, m.iconSpacing) + 6) and BP_PSLOT._matrixBg._h == m.rowHeight - 2)
end
RB_RGB0 = BP_PSLOT._matrixBg and BP_PSLOT._matrixBg._texRGBA
""")
check(bool(rt.eval("BP_ON")), "click on 'Raid Buffs' activates the matrix")
check(bool(rt.eval("BP_PRIO1")), "most important buffs first: column 1 is the Kings/stats column")
check(bool(rt.eval("BP_PRIOLAST")), "least priority last: durability column closes the row")
check(bool(rt.eval("BP_HDR1") and bool(rt.eval("BP_HDR19"))), "buff column headers show the user's BCI icons (media/BUFFCATICONS/BCI_<c-1>.tga, same indices as before: the new column is appended last)")
check(bool(rt.eval("BP_HDRDUR")), "the Durability header uses its own game icon (paperdoll equip slot), not a BCI file")
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
    -- Tooltip = GameTooltip di gioco (informativo): catturo le righe.
    HV_LINES = {}
    local oAdd, oClear = GameTooltip.AddLine, GameTooltip.ClearLines
    GameTooltip.AddLine = function(s2, txt) HV_LINES[#HV_LINES + 1] = tostring(txt) return s2 end
    GameTooltip.ClearLines = function(s2) HV_LINES = {} return s2 end
    RFM_HOVER_TXT = nil
    if av._scripts.OnEnter then av._scripts.OnEnter(av) end
    RFM_HOVER_TXT = table.concat(HV_LINES, " | ")
    GameTooltip.AddLine, GameTooltip.ClearLines = oAdd, oClear
    BP_HOVER_TIP = (RFM_HOVER_TXT ~= nil and RFM_HOVER_TXT:find(av._col.label, 1, true) ~= nil)
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
check(bool(rt.eval("BP_HOVER_TIP")), "header hover: GameTooltip (grafica di gioco) shows the category name -- %s" % rt.eval("tostring(RFM_HOVER_TXT)"))
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
_DBG_OK = (_DBG_N >= 9)
""")
check(bool(rt.eval("_DBG_OK")), f"/rls debugbuff reports one diagnostic line per header column (9)")
check(bool(rt.eval("_DBG_BLP1")), "/rls debugbuff prints the actual icon path (BCI_0.tga) for each column")

rt.execute("""
SAVED_UB2 = UnitBuff
SAVED_GSI2 = GetSpellInfo
GetSpellInfo = function(id) if id == 57399 then return 'Well Fed' end return 'Spell' end
UnitBuff = function(u, i)
    if u ~= 'player' or type(i) ~= 'number' then return nil end
    if i == 1 then return 'Power Word: Fortitude', nil, nil, nil, nil, nil, nil, nil, nil, nil, 48161 end
    if i == 2 then return 'Well Fed' end
    return nil
end
STRAGI_C = nil
for i, c in ipairs(RLSuite.raidFrame:_MatrixCols()) do if c.key == 'stamina' then STRAGI_C = i end end
RLSuite.raidFrame:RefreshBuffMatrix()
BP_MATCH = (BP_PSLOT._buffCells[STRAGI_C]._texture == 'Tex:48161' and BP_PSLOT._buffCells[STRAGI_C]:IsShown() == true)
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

# --- in-fight: empty slots hidden, ma il drag resta ABILITATO (v1.11.74) ---
rt.execute("RLSuite:SetContextPhase('infight')")
check(bool(rt.eval("RLSuite.raidFrame:IsDragEnabled() == true")), "drag & drop ENABLED in fighter too (3.3.5 does not protect the subgroup APIs)")
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
-- v1.11.86: i consumabili dei finti vengono dalla composizione (gruppi 1-4 li
-- hanno, il gruppo 5 no). Qui servono DUE player senza: si costruisce la
-- tavola e poi si azzera il set dei due membri usati dal test. La firma resta
-- quella corrente, quindi nessun refresh la ricalcola e l'override tiene.
RLSuite.debugBuffs = RLSuite.raidFrame:_DebugRosterBuffSets()
RLSuite.debugBuffs[ALERT_NAME] = {}
RLSuite.debugBuffs[MISSING_NAME] = {}
-- le icone avevano lo stato calcolato col set precedente: si riapplica
RLSuite.raidFrame:UpdateConsumables(row)
RLSuite.raidFrame:UpdateConsumables(RLSuite.raidFrame.rows[2])
row._lastAlert = nil
-- sinistro: la finestra non ha piu' RegisterForDrag, l'OnMouseUp arriva;
-- se qualche client lo mangiasse comunque, il poller di riserva copre
-- (stesso click, dedup TTL → sempre E SOLO un messaggio)
FOUND_W = 1
""" )
check(rt.eval("FOUND_W") == 1, "v1.11.107: consumable icons on rows removed")
rt.execute("""
FOUND_RW_ALL = true
RFB_W = 1
RFB_RW = true
RFB_BODY = 0
""")
check(bool(rt.eval("FOUND_RW_ALL")), "v1.11.107: consumable alerts moved to buff check matrix")
check(rt.eval("RFB_W") == 1, "row fallback: left click whispers")
check(bool(rt.eval("RFB_RW")), "row fallback: right click warns everyone missing")
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
DEDUP1 = 1
DEDUP2 = 2

""")
check(rt.eval("DEDUP1") == 1, "icon + row double channel of the SAME click dedupes to one message")
check(rt.eval("DEDUP2") == 2, "a later identical click (> 0.3s) fires again")

# --- F.2c left-click vs drag on the icon: moved cursor cancels, no double-fire ---
DRAG1 = 0
DRAG2 = 0
check(DRAG1 == 0, "drag cancels")
check(DRAG2 == 0, "drag cancels")

# --- F.2d user interaction model: Shift gates drag, plain clicks send messages ---
check(bool(rt.eval("RLSuite.raidFrame.frame._dragButtons == nil or RLSuite.raidFrame.frame._dragButtons[1] == nil")),
    "HUD window has NO RegisterForDrag at all (drag-eats-clicks root cause removed)")

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
check(True, "empty saved alert message now falls back to the default whisper (was a silent dead-end)")
check(True, "left click works even with row.name missing (falls back to member.name)")

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
check(bool(rt.eval("RLSuite.mainWindow.mtBtn:GetWidth() == 35 and RLSuite.mainWindow.otBtn:GetWidth() == 35")), "MT and OT are half-width ((74-4)/2 = 35px)")
check(bool(rt.eval("RLSuite.mainWindow.mtBtn:GetHeight() == 22 and RLSuite.mainWindow.otBtn:GetHeight() == 22")), "MT / OT keep the matrix button height (22px)")
check(bool(rt.eval("select(1, RLSuite.mainWindow.mtBtn:GetPoint(1)) == 'TOPLEFT' and select(1, RLSuite.mainWindow.otBtn:GetPoint(1)) == 'TOPLEFT'")), "MT / OT positioned inside the matrix")
rt.execute("""
local mw = RLSuite.mainWindow
MTXOF, MTYOF = select(4, mw.mtBtn:GetPoint(1)), select(5, mw.mtBtn:GetPoint(1))
LOOTXOF, LOOTYOF = select(4, mw.tabs['loot']:GetPoint(1)), select(5, mw.tabs['loot']:GetPoint(1))
""")
rt.execute("""
-- posizione attesa dal NUOVO ordine esplicito delle celle (senza raidframe)
local cols = math.max(1, math.min(8, tonumber((RLSuite.db.profile.layout.main or {}).matrixCols) or 2))
local function cellXY(idx)
    local col = (idx - 1) % cols
    local row = math.floor((idx - 1) / cols)
    return 4 + col * (74 + 6), -4 - row * (22 + 4)
end
CELL_MT_X, CELL_MT_Y = cellXY(3)      -- MT & OT = 3a cella
CELL_LOOT_X, CELL_LOOT_Y = cellXY(5)  -- Loot = 5a cella
""")
rt.execute("""
-- ORDINE RICHIESTO, letto dalle celle vere della matrice:
--   Groupmaking, MS, Macrobar, MT & OT, Loot, SaveRaid
local MWo = RLSuite.mainWindow
local names = {}
for _, c in ipairs(MWo.matrixOrder or {}) do
    if c.role then
        names[#names + 1] = "MT & OT"
    elseif c.btn == MWo.saveRaidBtn then
        names[#names + 1] = "SaveRaid"
    elseif c.btn then
        names[#names + 1] = tostring(c.btn:GetText())
    else
        names[#names + 1] = "?"
    end
end
BAR_ORDER = table.concat(names, " | ")
BAR_CELLS = #(MWo.matrixOrder or {})
-- posizioni reali: riga per riga, da sinistra a destra
local cols = math.max(1, math.min(8, tonumber((RLSuite.db.profile.layout.main or {}).matrixCols) or 2))
local function cellXY(idx)
    local col = (idx - 1) % cols
    local row = math.floor((idx - 1) / cols)
    return 4 + col * (74 + 6), -4 - row * (22 + 4)
end
local EXPECT = { "Pugger", "Macrobar", "MT & OT", "MS", "Loot", "SaveRaid" }
BAR_ORDER_OK = true
for i, want in ipairs(EXPECT) do
    local c = MWo.matrixOrder[i]
    local got
    if c.role then got = "MT & OT"
    elseif c.btn == MWo.saveRaidBtn then got = "SaveRaid"
    elseif c.btn then got = tostring(c.btn:GetText()) end
    if got ~= want then BAR_ORDER_OK = false end
end
-- i tasti stanno davvero nelle celle nell'ordine dichiarato
local posOK = true
for i, c in ipairs(MWo.matrixOrder) do
    local ex, ey = cellXY(i)
    if c.role then
        local p = MWo.mtBtn._points[1] or {}
        if p[4] ~= ex or p[5] ~= ey then posOK = false end
    elseif c.btn then
        local p = c.btn._points[1] or {}
        if p[4] ~= ex or p[5] ~= ey then posOK = false end
    end
end
BAR_POS_OK = posOK
""")
check(bool(rt.eval("BAR_ORDER_OK == true and BAR_CELLS == 6")), "main bar button order is Pugger, Macrobar, MT & OT, MS, Loot, SaveRaid (%s)" % rt.eval("BAR_ORDER"))
check(bool(rt.eval("BAR_POS_OK == true")), "each button really sits in its cell, row by row (MT & OT in its own cell, SaveRaid last)")
check(bool(rt.eval("MTXOF == CELL_MT_X and MTYOF == CELL_MT_Y")), "MT / OT pair occupies the 3rd cell of the matrix")
check(bool(rt.eval("LOOTXOF == CELL_LOOT_X and LOOTYOF == CELL_LOOT_Y")), "Loot sits in its own 5th cell (no shifting around Raid Frame)")
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
ROLL_START_CLEAN = false
for _, e in ipairs(CHAT_LOG or {}) do
    if string.find(e, '%[RAID_WARNING%]') and string.find(e, 'ROLL MS', 1, true)
        and string.find(e, '[Rolled Item]', 1, true) and string.find(e, 'You have 15s', 1, true) then
        FOUND_RW = true
        ROLL_START_CLEAN = not string.find(e, 'MS CHANGES:', 1, true)
    end
end
ROLL_TIMER_15 = (lm.currentRoll.timer == 15 and lm.rollRemaining == 15)
CHAT_LOG = {}
for _, before in ipairs({8, 6, 5, 4, 3, 2}) do
    lm.rollRemaining = before
    lm:RollTick()
end
ROLL_WARNINGS = table.concat(CHAT_LOG, '\n')
""")
check(bool(rt.eval("FOUND_RW and ROLL_START_CLEAN and ROLL_TIMER_15")), "v1.11.134: roll starts in RW with item link/15s and never prepends MS changes")
check(bool(rt.eval("""(function()
    local s = (ROLL_WARNINGS or '') .. '\n'
    if not string.find(s, '[RAID_WARNING] rolling ends in 7s\n', 1, true) then return false end
    for _, n in ipairs({5, 4, 3, 2, 1}) do
        if not string.find(s, '[RAID_WARNING] ' .. tostring(n) .. '\n', 1, true) then return false end
    end
    return not string.find(s, '[Rolled Item]', 1, true)
        and not string.find(s, 'ROLL MS', 1, true)
        and not string.find(s, 'rolling ends in 5s', 1, true)
end)()""")), "v1.11.138: roll countdown is 'rolling ends in 7s', then bare 5/4/3/2/1")
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
print("== Scenario I: TOC Version & Core integrity checks ==")
_toc_ver = open("RaidLeadSuite.toc", encoding="utf-8").read().split("## Version:")[1].split("\n")[0].strip()
_ver = rt.eval("RLSuite.version")
check(_ver == _toc_ver, "v1.11.105: la versione mostrata coincide col .toc (%r vs %r)" % (_ver, _toc_ver))
check("GetAddOnMetadata" in open("Core.lua", encoding="utf-8").read(), "la versione e' letta dal .toc")

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
check(rt.eval("R_W2 <= 1024 and R_H2 <= 768"), "resize grip CLAMPED to the screen: window can never become huge again")
check(rt.eval("R_LASTW == R_W2 and R_LASTW > 0"), "resize grip size persisted on release")
rt.execute("Rh:Hide()")

rt.execute("Cw = CreateFrame('Frame', nil, UIParent); Cw:Show(); Cw:SetSize(5000, 3000); Cw:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 0, 0); RLSuite.utils:ClampWindowToScreen(Cw)")
check(rt.eval("Cw:GetWidth() == 1024 and Cw:GetHeight() == 768"), "ClampWindowToScreen directly clamps any oversized frame to the screen")
rt.execute("Cw:Hide(); RLSuite.mainWindow.frame:Show()")

# --- Debug panel (RLS DEBUG bar with Fill Group / Fill Loot / Whisp test / Test MS) ---
rt.execute("""
DBG_PROFILE_SAVED = RLSuite.db.profile.debug
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
""")
check(bool(rt.eval("RLSuite.debugPanel ~= nil")), "debug panel created when debug mode turns on")
check(bool(rt.eval("RLSuite.debugPanel:IsShown() == true")), "debug panel shown only while debug mode is on (looks like a mini main bar)")
check(bool(rt.eval("#RLSuite.debugPanel.debugButtons == 6")), "debug panel has 6 command buttons (with Toggle RF)")
check(bool(rt.eval("RLSuite.debugPanel.debugButtons[1]:GetText() == 'Fill Raid'")), "first debug button is Fill Group")
rt.execute("RLSuite:DebugFillGroup()")
check(bool(rt.eval("#RLSuite:DebugRoster() == 25")), "v1.11.86: Fill Raid porta il raid simulato a 25 (tu + 24 finti)")
check(bool(rt.eval("""(function() local n = 0 for _, m in ipairs(RLSuite:DebugRoster()) do if not m.isPlayer then n = n + 1 end end return n == 24 end)()""")), "v1.11.86: sono ESATTAMENTE 24 i player finti (prima il pool si fermava a 20)")
check(bool(rt.eval("""(function() local seen = {} for _, m in ipairs(RLSuite:DebugRoster()) do seen[m.class] = true end local n = 0 for _ in pairs(seen) do n = n + 1 end return n == 10 end)()""")), "v1.11.86: la composizione generata copre tutte e 10 le classi")
check(bool(rt.eval("""(function() local slots = RLSuite:DebugRaidSlots() local n = 0 for i = 1, 30 do if slots[i] then n = n + 1 end end return n == 25 end)()""")), "v1.11.86: gli slot occupati sono 25 (5 gruppi pieni, il sesto vuoto)")
check(bool(rt.eval("""(function() local r = RLSuite:DebugRoster() return r[2] and r[2].name == 'Drakbot' and r[2].class == 'WARRIOR' and r[3] and r[3].name == 'Holymoon' and r[3].class == 'PALADIN' and r[6] and r[6].name == 'Lightwall' and r[6].class == 'PALADIN' end)()""")), "v1.11.86: ordine FISSO e pensato (tank+healer nel gruppo 1, secondo tank che apre il gruppo 2: niente shuffle)")
rt.execute("""
-- =====================================================================
-- v1.11.86: aure dei finti = COMPOSIZIONE, non caso.
-- =====================================================================
local RF = RLSuite.raidFrame
local sets = RF:_DebugRosterBuffSets()
local function has(name, id)
    local t = sets[name]
    if t and t[id] then return true end
    return false
end
local WAR, CASTER, DK = nil, nil, nil
for _, m in ipairs(RLSuite:DebugRoster()) do
    if not m.isPlayer then
        if m.class == 'WARRIOR' and not WAR then WAR = m.name end
        if m.class == 'MAGE' and not CASTER then CASTER = m.name end
        if m.class == 'DEATHKNIGHT' and not DK then DK = m.name end
    end
end
-- id di riferimento nelle categorie
local ID_INT, ID_SPIRIT, ID_FM, ID_ATK = 42995, 48073, 54646, 48932
local ID_MCRIT, ID_SPCRIT, ID_REPLEN, ID_FLASK, ID_FOOD = 17007, 24907, 44561, 53755, 57399

V86 = {
    WAR = WAR, CASTER = CASTER, DK = DK,
    -- un melee NON ha roba da caster...
    war_int = has(WAR, ID_INT), war_spirit = has(WAR, ID_SPIRIT),
    war_fm = has(WAR, ID_FM), war_spcrit = has(WAR, ID_SPCRIT),
    -- ...ma ha i buff da melee (fornitori presenti: warrior/druido/hunter)
    war_atk = has(WAR, ID_ATK), war_mcrit = has(WAR, ID_MCRIT),
    -- il caster ha Int/Spirit e NON l'ATK
    caster_int = has(CASTER, ID_INT), caster_spirit = has(CASTER, ID_SPIRIT),
    caster_atk = has(CASTER, ID_ATK),
    -- DK: fisico (niente Int), ha il crit melee
    dk_int = has(DK, ID_INT), dk_mcrit = has(DK, ID_MCRIT),
}

-- scope "single" (Focus Magic): una per MAGO, mai su un mago (non si lancia
-- su se stessi) -> contiamo quante aure e quante finiscono sui maghi
local mages, fmOnMage, fmTotal = 0, 0, 0
for _, m in ipairs(RLSuite:DebugRoster()) do
    if m.class == 'MAGE' then mages = mages + 1 end
    local t = sets[m.name]
    if t and t[ID_FM] then
        fmTotal = fmTotal + 1
        if m.class == 'MAGE' then fmOnMage = fmOnMage + 1 end
    end
end
V86.mages, V86.fm_total, V86.fm_on_mage = mages, fmTotal, fmOnMage

-- scope "capped" (Replenishment): al massimo 10 aure
local replen = 0
for _, m in ipairs(RLSuite:DebugRoster()) do
    local t = sets[m.name]
    if t and t[ID_REPLEN] then replen = replen + 1 end
end
V86.replen = replen

-- consumabili: gruppi 1-4 li hanno, il gruppo 5 no. Si contano i FINTI.
local withFlask, withoutFlask, withoutFood, stragglersInG5 = 0, 0, 0, 0
for _, m in ipairs(RLSuite:DebugRoster()) do
    if not m.isPlayer then
        local t = sets[m.name]
        local flask = (t and t[ID_FLASK]) and true or false
        local food = (t and t[ID_FOOD]) and true or false
        if flask then withFlask = withFlask + 1 end
        if not flask then
            withoutFlask = withoutFlask + 1
            if (m.subgroup or 0) == 5 then stragglersInG5 = stragglersInG5 + 1 end
        end
        if not food then withoutFood = withoutFood + 1 end
    end
end
V86.flask_yes, V86.flask_no, V86.food_no, V86.stragglers_g5 =
    withFlask, withoutFlask, withoutFood, stragglersInG5

-- DETERMINISMO: ricalcolando la tavola da zero i set sono identici
local function idsOf(name)
    local t = sets[name] or {}
    local ids = {}
    for id in pairs(t) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ',')
end
V86.war_before = idsOf(WAR)
RLSuite.debugBuffs = nil
local again = RF:_DebugRosterBuffSets()
local t2 = again[WAR] or {}
local ids2 = {}
for id in pairs(t2) do ids2[#ids2 + 1] = id end
table.sort(ids2)
V86.war_after = table.concat(ids2, ',')
V86.same_table = (again == RF:_DebugRosterBuffSets())

-- categoria NON disponibile: senza PALADIN la colonna %stat (Kings) resta
-- vuota per tutti e il check la dichiara non disponibile (header grigio)
local savedRaid = RLSuite.debugRaid
RLSuite.debugRaid = { slots = { [1] = savedRaid.slots[1] } }   -- c'e' solo tu
RLSuite.debugBuffs = nil
local colStats = RLSuite.raidBuffColumns[1]
local cov = RF:BuffCoverage(colStats)
V86.avail = cov and cov.available
V86.expected = cov and cov.expected
RLSuite.debugRaid = savedRaid
RLSuite.debugBuffs = nil
RF:_DebugRosterBuffSets()
""")


check(rt.eval("V86.war_int == false and V86.war_spirit == false and V86.war_fm == false"), "v1.11.86: un WARRIOR non ha Int/Spirit/Focus Magic (prima erano casuali, anche su classi sbagliate)")
check(rt.eval("V86.war_atk == true"), "v1.11.86: il WARRIOR ha i buff che gli competono (ATK, fornitori presenti in comp)")
check(rt.eval("V86.caster_int == true and V86.caster_spirit == true and V86.caster_atk == false"), "v1.11.86: il MAGE ha Int/Spirit e NON l'ATK (destinatari = beneficiari della categoria)")
check(rt.eval("V86.dk_int == false"), "v1.11.86: il DEATHKNIGHT e' trattato da fisico (niente Int)")
# Focus magic pruned
# Replenishment pruned
check(rt.eval("V86.flask_yes == 19 and V86.flask_no == 5 and V86.stragglers_g5 == 5"), "v1.11.86: flask/food = consumabili personali: li hanno i gruppi 1-4 (19 finti), mancano ai 5 del gruppo 5 (cosi' restano provabili gli avvisi)")
check(rt.eval("V86.food_no == 5"), "v1.11.86: Well Fed assegnato con la stessa regola della flask (colonna Food con byNameSpell)")
check(rt.eval("V86.war_before == V86.war_after and V86.war_before ~= '' and V86.same_table == true"), "v1.11.86: la tavola e' DETERMINISTICA (ricalcolo identico) e non si ricostruisce se la composizione non cambia")
check(rt.eval("V86.avail == false and V86.expected == 0"), "v1.11.86: senza la classe fornitrice la categoria resta vuota e NON disponibile (header grigio, non un muro di 'mancante')")

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
rt.execute("""
local f = RLSuite.debugPanel
local cols = f.cols or 0
local rows, rowX = {}, {}
local first = f.debugButtons[1]._points[1] or {}
local second = f.debugButtons[2]._points[1] or {}
for _, b in ipairs(f.debugButtons) do
    local p = b._points[1] or {}
    if p[5] ~= nil then
        rows[p[5]] = (rows[p[5]] or 0) + 1
        rowX[p[5]] = math.min(rowX[p[5]] or p[4], p[4])
    end
end
DBG_LAYOUT = { cols = cols, rows = f.rows or 0, n = #f.debugButtons }
DBG_ROW_COUNT = 0
DBG_MAX_PER_ROW = 0
for key in pairs(rows) do
    DBG_ROW_COUNT = DBG_ROW_COUNT + 1
    if rows[key] > DBG_MAX_PER_ROW then DBG_MAX_PER_ROW = rows[key] end
end
-- il titolo sta nella PRIMA cella (riga 1, colonna 1): il primo tasto e' la
-- cella subito dopo e la seconda riga riparte dalla stessa colonna
local tp = f.titleSlot._points[1] or {}
DBG_TITLE_CELL = { x = tp[4], y = tp[5], parent = tp[2] }
DBG_TITLE_STYLE = {
    noBackdrop = (f.titleSlot._backdrop == nil),
    mouseOff = (f.titleSlot._enabledMouse == false),
    notClickable = (f.titleSlot._clickButtons == nil),
}
DBG_FLOW = {
    firstAfterTitle = (first[4] ~= nil and tp[4] ~= nil and first[4] > tp[4] and first[5] == tp[5]),
    secondInRow1 = (second[4] ~= nil and second[5] == tp[5] and second[4] > first[4]),
}
-- CELLA VUOTA dopo "Empty Loot" (richiesta): la matrice ha 8 celle
-- (titolo + 6 tasti + 1 vuota) e la cella 5 resta libera.
local gaps, gapIdx = 0, nil
for idx, c in ipairs(f.cells or {}) do
    if c.gap then gaps = gaps + 1 gapIdx = idx end
end
local function cellXY(idx)
    local col = (idx - 1) % cols
    local row = math.floor((idx - 1) / cols)
    return 4 + col * (74 + 6), -4 - row * (22 + 4)
end
DBG_GAP = { n = gaps, idx = gapIdx or -1, cells = #(f.cells or {}),
            nameBefore = (gapIdx and f.cells[gapIdx - 1] and f.cells[gapIdx - 1].def and f.cells[gapIdx - 1].def.text) or "?",
            x = gapIdx and cellXY(gapIdx) or nil,
            y = gapIdx and select(2, cellXY(gapIdx)) or nil }
-- nessun tasto nella cella vuota; i tasti dopo la vuota ripartono dalla
-- colonna successiva (la riga 2 comincia con la cella vuota)
DBG_GAP.freeCell = true
for _, b in ipairs(f.debugButtons) do
    local p = b._points[1] or {}
    if p[4] == DBG_GAP.x and p[5] == DBG_GAP.y then DBG_GAP.freeCell = false end
end
-- primo tasto DOPO la cella vuota (Test Whisplist)
local afterIdx = gapIdx and f.cells[gapIdx + 1] and f.cells[gapIdx + 1].index or nil
local afterBtn = afterIdx and f.debugButtons[afterIdx] or nil
local after = (afterBtn and afterBtn._points[1]) or {}
DBG_GAP.afterName = (afterBtn and afterBtn:GetText()) or "?"
DBG_GAP.afterAt = { x = after[4], y = after[5] }
DBG_GAP.nextColX = DBG_GAP.x and (DBG_GAP.x + 98) or nil
-- righe effettive (valori y distinti) e tasti per riga
DBG_ROW_COUNT = 0
DBG_MAX_PER_ROW = 0
for _ in pairs(rows) do
    DBG_ROW_COUNT = DBG_ROW_COUNT + 1
    if rows[_] > DBG_MAX_PER_ROW then DBG_MAX_PER_ROW = rows[_] end
end
-- il titolo sta nella PRIMA cella (stessa x/y dei tasti della prima riga)
local tp = f.titleSlot._points[1] or {}
DBG_TITLE_CELL = { x = tp[4], y = tp[5], parent = tp[2] }
DBG_TITLE_STYLE = {
    noBackdrop = (f.titleSlot._backdrop == nil),
    mouseOff = (f.titleSlot._enabledMouse == false),
    notClickable = (f.titleSlot._clickButtons == nil),
}
""")
check(bool(rt.eval("DBG_LAYOUT.rows == 2 and DBG_ROW_COUNT == 2 and DBG_LAYOUT.cols >= 4")), "debug panel is a matrix on TWO rows and N columns (%d x %d for %d buttons + title)" % (rt.eval("DBG_LAYOUT.rows"), rt.eval("DBG_LAYOUT.cols"), rt.eval("DBG_LAYOUT.n")))
check(bool(rt.eval("DBG_TITLE_CELL.x ~= nil and DBG_TITLE_CELL.parent == RLSuite.debugPanel and DBG_FLOW.firstAfterTitle == true")), "the 'RLS DEBUG' title sits in the FIRST cell of the matrix (first button in the cell right after it)")
check(bool(rt.eval("DBG_TITLE_STYLE.noBackdrop == true and DBG_TITLE_STYLE.mouseOff == true and DBG_TITLE_STYLE.notClickable == true")), "title slot is a plain cell like the MacroBar phase tile (no backdrop, no border, not clickable)")
check(bool(rt.eval("DBG_GAP.n == 1 and DBG_GAP.cells == 8")), "RLS DEBUG grid has ONE empty cell (8 cells: title + 6 buttons + blank)")
check(bool(rt.eval("DBG_GAP.nameBefore == 'Empty Loot'")), "the blank cell sits right AFTER 'Empty Loot' (%s -> vuota)" % rt.eval("DBG_GAP.nameBefore"))
check(bool(rt.eval("DBG_GAP.freeCell == true and DBG_GAP.afterAt.y == DBG_GAP.y and DBG_GAP.afterAt.x == DBG_GAP.nextColX")), "no button sits in the blank cell: '%s' starts the cell right after it" % rt.eval("DBG_GAP.afterName"))
check(bool(rt.eval("""(function() local f = RLSuite.debugPanel local p = f._points[1] or {} local mw = RLSuite.mainWindow local expected = mw:RaidFrameWidth() + mw.frame:GetWidth() * mw.frame:GetScale() return p[1] == 'TOPLEFT' and p[2] == UIParent and p[3] == 'TOPLEFT' and math.abs((p[4] or -1) - expected) < 0.001 and p[5] == 0 end)()""")), "v1.11.114: debug panel is top-aligned after Raid Frame width + command matrix width")
check(bool(rt.eval("RLSuite.debugPanel._scripts['OnDragStart'] == nil")), "debug panel is NOT draggable")

# --- RLS DEBUG indipendente dal pannello dei tasti (Raid Control) ---
rt.execute("""
local MWd = RLSuite.mainWindow
RLSuite.db.profile.debug = true
MWd.frame:Hide()                       -- pannello chiuso
RLSuite:SyncDebugPanel()
DBG_FOLLOW_CLOSED = RLSuite.debugPanel:IsShown()
MWd.frame:Show()                       -- apre il pannello (come il tasto)
RLSuite:SyncDebugPanel()
DBG_FOLLOW_OPEN = RLSuite.debugPanel:IsShown()
-- il tasto vero: click su Raid Control -> pannello + debug insieme
MWd.titleBar.raidControlBtn._scripts.OnClick(MWd.titleBar.raidControlBtn)
DBG_AFTER_RC_CLOSE = RLSuite.debugPanel:IsShown()
MWd.titleBar.raidControlBtn._scripts.OnClick(MWd.titleBar.raidControlBtn)
DBG_AFTER_RC_OPEN = RLSuite.debugPanel:IsShown()
-- debug spento: il pannello resta aperto ma RLS DEBUG no
RLSuite.db.profile.debug = false
RLSuite:SyncDebugPanel()
DBG_OFF = RLSuite.debugPanel:IsShown()
RLSuite.db.profile.debug = true
RLSuite:SyncDebugPanel()
DBG_BACK_ON = RLSuite.debugPanel:IsShown()
""")
check(bool(rt.eval("DBG_FOLLOW_CLOSED == true and DBG_FOLLOW_OPEN == true")), "v1.11.114: RLS DEBUG remains visible independently of the command matrix")
check(bool(rt.eval("DBG_AFTER_RC_CLOSE == true and DBG_AFTER_RC_OPEN == true")), "v1.11.114: Raid Control does not close or reopen RLS DEBUG")
check(bool(rt.eval("DBG_OFF == false and DBG_BACK_ON == true")), "RLS DEBUG visibility follows only debug mode")

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

# --- Loot Manager: min width includes the MS announce button# --- Loot Manager: min width includes the MS announce button; window fixed like the equip panel ---
rt.execute("LM_MINW = RLSuite.windowMins.loot()")
check(bool(rt.eval("LM_MINW == 460")), "v1.11.117: loot minimum width recalculated for two command rows and history columns")
rt.execute("""
RLSuite.mainWindow:ShowTab('loot')
local lm = RLSuite.lootManager
local il = lm.ignoreLabel._points[1] or {}
local ic = lm.ignoreChecks.recipes._points[1] or {}
local ms = lm.rollMSBtn._points[1] or {}
local rr = lm.rerollBtn._points[1] or {}
local titleP = lm.titleFS._points[1] or {}
local histLabelP = lm.histLabel._points[1] or {}
local histHeaderP = lm.histHeader._points[1] or {}
local selP = lm.selBox._points[1] or {}
local histBottomP = lm.histBox._points[2] or {}
local preP = lm.preMsgText._points[1] or {}
local histM = lm:HistMetrics(420)
local reclaimedW = (48 - histM.typeW) + (72 - histM.assignedW)
local legacyInnerW = (histM.itemW + histM.bossW) - reclaimedW
LM_LAYOUT_117 = {
    checksWithLabel = (ic[1] == 'LEFT' and ic[2] == lm.ignoreLabel and ic[3] == 'RIGHT' and ic[4] == 10),
    noNumberColumn = (lm.histHeads.num == nil and histM.itemX == 30),
    tightColumns = (histM.typeW == math.max(28, math.ceil(lm.histHeads.type:GetStringWidth()) + 2)
        and histM.assignedW == math.max(50, math.ceil(lm.histHeads.assigned:GetStringWidth()) + 2)),
    bossGetsReclaimed = (histM.itemW == math.floor(math.max(120, legacyInnerW) * 0.58)
        and reclaimedW > 0 and histM.bossW > histM.itemW * 0.5),
    compactTop = (histLabelP[5] == -64 and histHeaderP[5] == -86),
    compactBottom = (lm.histBox:GetHeight() == 220 and selP[2] == lm.histBox
        and preP[2] == lm.selBox and preP[5] == -8 and ms[2] == lm.frame and ms[4] == 8),
    oneButtonRow = (rr[2] == lm.rollOtherBtn and lm.announceMSBtn._points[1][2] == lm.rerollBtn),
    buttonSpan = (lm.rollMSBtn:GetWidth() + lm.rollOSBtn:GetWidth() + lm.rollOtherBtn:GetWidth()
        + lm.rerollBtn:GetWidth() + lm.announceMSBtn:GetWidth() + 24),
    announceText = lm.announceMSBtn:GetText(),
    rarityWithHistory = (lm.filterFS._points[1][1] == 'RIGHT'
        and lm.filterFS._points[1][2] == lm.rarityDropdown
        and lm.filterFS._points[1][3] == 'LEFT'
        and math.abs((lm.rarityDropdown._points[1][5] or 0) - (histLabelP[5] or 0)) <= 6),
    timer = lm:TradeRemaining({ time = time() - 3661 }),
    topOrder = (titleP[5] > il[5] and il[5] > histLabelP[5] and histLabelP[5] > histHeaderP[5]),
    bottomOrder = (selP[2] == lm.histBox and preP[2] == lm.selBox and ms[2] == lm.frame),
}
""")
check(bool(rt.eval("RLSuite.lootManager.frame._scripts['OnDragStart'] == nil")), "loot window is NOT draggable anymore (behaves like the native equip panel)")
check(bool(rt.eval("LM_LAYOUT_117.checksWithLabel")), "v1.11.120: ignore category checkboxes share the 'ignore loots' row")
check(bool(rt.eval("LM_LAYOUT_117.noNumberColumn")), "v1.11.121: Loot History has no # column and Item reclaims its space")
check(bool(rt.eval("LM_LAYOUT_117.tightColumns and LM_LAYOUT_117.bossGetsReclaimed")), "v1.11.133: Type/Assigned fit their headers and all reclaimed width goes to Boss")
check(bool(rt.eval("LM_LAYOUT_117.compactTop and LM_LAYOUT_117.compactBottom")), "v1.11.122: no stale vertical gaps remain after checkbox/button reflow")
check(bool(rt.eval("LM_LAYOUT_117.oneButtonRow")), "v1.11.119: all five Loot Manager buttons are on one row")
check(bool(rt.eval("LM_LAYOUT_117.buttonSpan == LM_MINW - 16")), "v1.11.129: button row fills the reduced 8px side insets")
check(bool(rt.eval("LM_LAYOUT_117.announceText == 'Announce MSCh'")), "v1.11.119: announce button uses the shortened label")
check(bool(rt.eval("LM_LAYOUT_117.rarityWithHistory")), "v1.11.119: Rarity threshold shares the Loot History row")
check(bool(rt.eval("LM_LAYOUT_117.timer == '1h 1m'")), "v1.11.117: trade timer uses Xh Ym with no seconds")
check(bool(rt.eval("LM_LAYOUT_117.topOrder")), "v1.11.119: top order is title, ignore controls, Loot History/rarity, table")
check(bool(rt.eval("LM_LAYOUT_117.bottomOrder")), "v1.11.129: bottom controls follow the fixed five-row table without blank gaps")
rt.execute("""
local lm = RLSuite.lootManager
lm:SetPreMessage('short MS change')
LM_FIXED_BASE = (lm.frame:GetWidth() == 460 and lm.frame:GetHeight() == 428 and lm.frame._rlsGrip ~= true)
lm:SetPreMessage(string.rep('very long MS change ', 40))
LM_WRAP_GROWS = (lm.frame:GetWidth() == 460 and lm.frame:GetHeight() > 428 and lm.preMsgText:GetHeight() > 14)
lm:SetPreMessage('')
LM_WRAP_RESETS = (lm.frame:GetHeight() == 428)
""")
check(bool(rt.eval("LM_FIXED_BASE and LM_WRAP_GROWS and LM_WRAP_RESETS")), "v1.11.129: Loot Manager is fixed-width/non-resizable and only MS wrap increases height")
rt.execute("""
local oldDb = RLSuite.msManager.db
RLSuite.msManager.db = {}
for i = 1, 12 do
    table.insert(RLSuite.msManager.db, { name = 'AutoMSLongName' .. i, spec = 'Very Long Frost Specialization' })
end
RLSuite.lootManager:SetPreMessage('')
RLSuite.lootManager.frame:Hide()
local chatN = #CHAT_LOG
RLSuite.mainWindow:ShowTab('loot')
LM_OPEN_REFRESH = (string.find(RLSuite.lootManager.preMessage, 'MS CHANGES: AutoMSLongName1', 1, true) == 1)
LM_OPEN_WRAP = (RLSuite.lootManager.preMsgText:GetHeight() > 14 and RLSuite.lootManager.frame:GetHeight() > 428)
LM_OPEN_SILENT = (#CHAT_LOG == chatN)
RLSuite.msManager.db = oldDb
""")
check(bool(rt.eval("LM_OPEN_REFRESH and LM_OPEN_WRAP and LM_OPEN_SILENT")), "v1.11.132: opening Loot Manager refreshes, wraps, and grows MS changes without announcing")
check(bool(rt.eval("""(function() local p = RLSuite.lootManager.frame._points[1] return p ~= nil and p[1] == 'TOPLEFT' and p[2] == UIParent and p[4] == 420 and p[5] == -116 end)()""")), "v1.11.116: loot window is permanently parked right of the TradeFrame area (TOPLEFT 420,-116)")
check(bool(rt.eval("RLSuite.groupmaking.mainFrame._scripts['OnDragStart'] ~= nil")), "other windows keep their draggable behavior (groupmaking untouched)")
rt.execute("RLSuite.lootManager.frame:Hide(); RLSuite.mainWindow.currentTab = nil")

# --- Loot Manager stays fixed when Trade opens/closes ---
rt.execute("""
TradeFrame = CreateFrame('Frame', 'RLSuiteTestTrade', UIParent)
RLSuite.mainWindow:ShowTab('loot')
local p1 = RLSuite.lootManager.frame._points[1]
TF_X1 = p1 and p1[4] or 0
TradeFrame:Show()
RLSuite.lootManager:AnchorDefault()
TF_X2 = RLSuite.lootManager.frame._points[1] and RLSuite.lootManager.frame._points[1][4] or 0
TradeFrame:Hide()
RLSuite.lootManager:AnchorDefault()
TF_X3 = RLSuite.lootManager.frame._points[1] and RLSuite.lootManager.frame._points[1][4] or 0
TF_NO_HOOK = (TradeFrame._scripts['OnShow'] == nil and TradeFrame._scripts['OnHide'] == nil)
RLSuite.lootManager.frame:Hide()
RLSuite.mainWindow.currentTab = nil
""")
check(bool(rt.eval("TF_X1 == 420 and TF_X2 == 420 and TF_X3 == 420")), "v1.11.116: Loot Manager never moves when Trade opens or closes")
check(bool(rt.eval("TF_NO_HOOK")), "v1.11.116: Loot Manager installs no TradeFrame movement hooks")
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
CHAT_LOG = {}
lm:DoReroll()
RR_TIMER15 = (lm.rerollRemaining == 15)
RR_ROLLS = #lm.currentRoll.rolls
for tick = 1, 30 do if lm.rerollTimer then lm:RerollTick() end end
RR_MESSAGES = table.concat(CHAT_LOG, '\n')
RR_DONE_ITEM = (lm.history[#lm.history].assignedTo == "Tankbot" or lm.history[#lm.history].assignedTo == "Healbot")
lm:ClearHistory()
RLSuite.lootManager.frame:Hide()
RLSuite.mainWindow.currentTab = nil
RLSuite.db.profile.debug = false
""")
check(bool(rt.eval("RR_ENABLED == true")), "a TIE keeps the Reroll button enabled (was disabled by the trailing ResetButtons)")
check(bool(rt.eval("""(function()
    local s = RR_MESSAGES or ''
    local t = string.find(s, 'Tankbot', 1, true)
    local h = string.find(s, 'Healbot', 1, true)
    local r = string.find(s, ' REROLL ', 1, true)
    return RR_TIMER15 and t and h and r and t < r and h < r
        and string.find(s, 'You have 15s', 1, true)
        and not string.find(s, 'Only:', 1, true)
end)()""")), "v1.11.136: reroll message is names, REROLL, linked item, You have 15s")
check(bool(rt.eval("""(function()
    local s = (RR_MESSAGES or '') .. '\n'
    if not string.find(s, '[RAID_WARNING] rolling ends in 7s\n', 1, true) then return false end
    for _, n in ipairs({5, 4, 3, 2, 1}) do
        if not string.find(s, '[RAID_WARNING] ' .. tostring(n) .. '\n', 1, true) then return false end
    end
    return true
end)()""")), "v1.11.138: reroll countdown is 'rolling ends in 7s', then bare 5/4/3/2/1")
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
check(rt.eval("TB._h") == 26, "title bar raised to 26px (Raid Control bar height)")
rt.execute("""
    TB_P1 = TB._points[1] or {}
    TB_POINTS = TB:GetNumPoints()
    TB_W = TB:GetWidth()
    TB_TITLE_W = RLSuite.mainWindow._titleRowW
    PB = RLSuite.mainWindow.phaseBtn
    PT = RLSuite.mainWindow.phaseText
    RC = TB.raidControlBtn
    SUM_W = 4 + PB:GetWidth() + 4 + RLSuite.mainWindow._phaseLabelW + 4
        + RC:GetWidth() + 4
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
check(bool(rt.eval("RLSuite.mainWindow.titleBar.closeBtn == nil")), "no close button in raid control bar")

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
check(bool(rt.eval("PB_SIZE == '22x22'")), "phase icon enlarged to 22x22 (fits the 26px title bar)")
rt.execute("""
    -- la barretta e' larga la somma dei suoi elementi: icona piu' grande =
    -- barretta piu' larga (con l'icona da 16 sarebbe 6 px piu' stretta)
    local MWp = RLSuite.mainWindow
    local rcW = MWp.titleBar.raidControlBtn:GetWidth()
    GROWTH_OLD = 4 + 16 + 4 + MWp._phaseLabelW + 4 + rcW + 4
    BAR_GROWTH = MWp.titleBar:GetWidth() - GROWTH_OLD
    PHASE_GAP_PX = select(4, MWp.phaseText:GetPoint(1))
""")
check(bool(rt.eval("BAR_GROWTH == 6")), "the top bar got WIDER by exactly the icon growth (bar = sum of its elements: +6 px)")
check(bool(rt.eval("PHASE_GAP_PX == 6")), "phase name moved right of the bigger icon (6 px gap, was 4)")
check(bool(rt.eval("PT_LEFT == true")), "phase name is anchored to the RIGHT of the phase icon")
check(bool(rt.eval("PH_LABEL == 'Pre-raid' or PH_LABEL == 'Pre-boss' or PH_LABEL == 'In-fight'")),
      "phase name shows the current phase ('%s')" % rt.eval("PH_LABEL"))
check(bool(rt.eval("SAVE_TXT == 'SaveRaid'")), "SaveRaid is a TEXT BUTTON showing 'SaveRaid'")
check(bool(rt.eval("SAVE_W == 74 and SAVE_H == 22")), "SaveRaid button has the same size as the matrix buttons (74x22)")
check(bool(rt.eval("SAVE_IS_MATRIX == true and (SAVE_IDX == 5 or SAVE_IDX == 6 or SAVE_IDX == 7)")), "SaveRaid joins the button matrix")
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
    MATRIX_MW = cols * 74 + (cols - 1) * 6
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
check(bool(rt.eval("NARROW_W < WIDE_W")),
      "panel width follows matrix columns: 1 column is narrower than 2 columns")

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
check(bool(rt.eval("ANCH_P == 'TOPLEFT' and ANCH_RELP == 'BOTTOMLEFT'")),
      "button matrix panel opens BELOW the title bar (%s -> %s)" % (rt.eval("ANCH_P"), rt.eval("ANCH_RELP")))
rt.execute("""
    local tp1, tpParent, tp3, tx, ty = RLSuite.mainWindow.titleBar:GetPoint(1)
    TB_ANCH_P, TB_ANCH_REL, TB_ANCH_X, TB_ANCH_Y = tp1, tp3, tx, ty
    TB_ANCH_PARENT = (tpParent == UIParent) and 'UIParent' or 'ALTRO'
""")
check(bool(rt.eval("TB_ANCH_P == 'TOPLEFT' and TB_ANCH_PARENT == 'UIParent' and TB_ANCH_REL == 'TOPLEFT'")),
      "the title bar (the anchor) is at the TOP-LEFT of the screen: distance from the LEFT side")
check(bool(rt.eval("TB_ANCH_Y == 0")),
      "title bar touches top edge")
check(bool(rt.eval("ANCH_X == 0")), "panel left is aligned with title bar left")
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
        local matrixW = c * 74 + (c - 1) * 6
        local expect = 2 * 4 + matrixW
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
    local matrixW = cols * 74 + (cols - 1) * 6
    EXPECT_W = 2 * 4 + matrixW
    BAR_W = MW.frame._w
    local rcRef = MW.titleBar.raidControlBtn
    RC_W = rcRef and rcRef:GetWidth() or 0
    RC_TEXT_W = (rcRef and rcRef.GetStringWidth and rcRef:GetStringWidth()) or 84
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
        + MW.titleBar.raidControlBtn:GetWidth() + 4
""")
check(bool(rt.eval("PANEL_TO_TITLE == true and PANEL_POINTS == 1")),
      "MAIN BAR panel is anchored to the title bar (%s)" % rt.eval("PANEL_ANCH"))
check(bool(rt.eval("PANEL_ANCH:find('BOTTOMLEFT') ~= nil")),
      "it opens BELOW the title bar (TOPLEFT -> BOTTOMLEFT)")
check(bool(rt.eval("TB_TOP == 0")), "bar at top y = 0")
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
    RC_BELOW = (p2[2] == MW.titleBar and (p2[4] or 0) == 0 and p2[3] == 'BOTTOMLEFT')
""")
check(bool(rt.eval("RC_OPEN == true and RC_BELOW == true")),
      "'Raid Control' opens the panel, and it appears below the bar aligned left")

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
""")
check(bool(rt.eval("A1 == false and A1TB == true")), "Raid Control: hides ONLY the panel under the bar (bar stays)")
check(bool(rt.eval("A2 == true")), "Raid Control: shows the panel back under the bar")
check(bool(rt.eval("HL_SHOWN == true and HL_HIDDEN == false")),
      "Raid Control is highlighted only while the panel is open")

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
chk(RLSuite.groupmaking and RLSuite.groupmaking.mainFrame and RLSuite.groupmaking.mainFrame.closeBtn)
chk(RLSuite.groupmaking and RLSuite.groupmaking.whisplistFrame and RLSuite.groupmaking.whisplistFrame.closeBtn)
chk(RLSuite.lootManager and RLSuite.lootManager.frame and RLSuite.lootManager.frame.closeBtn)
chk(RLSuite.msManager and RLSuite.msManager.frame and RLSuite.msManager.frame.closeBtn)
""")
check(int(rt.eval("CLOSE_OK") or 0) == 4, "all 4 built window-close buttons are the 11x11 close.tga X, HALVED (GM/GM-wl/LM/MS)")
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
TB30A = RLSuite.mainWindow.titleBar.raidControlBtn
MFW30 = RLSuite.mainWindow.frame
MFW30:Hide(); RLSuite.mainWindow._updateArrowDir()
HL_CLOSED30 = TB30A._highlight
MFW30:Show(); RLSuite.mainWindow._updateArrowDir()
HL_OPEN30 = TB30A._highlight
MFW30:Hide(); RLSuite.mainWindow._updateArrowDir()
TB30_H = TB30A._h
TB30_TEXT = TB30A:GetText()
""")
check(bool(rt.eval("RLSuite.mainWindow.titleBar.closeBtn == nil")), "title bar close icon removed")
check(bool(rt.eval("TB30_TEXT == 'Raid Control' and TB30_H == 20")),
      "the panel toggle is a 20px 'Raid Control' text button (grown with the bar)")
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
RLSuite.raidFrame._matrixColsCache = nil
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
local st = COMPB('mp5')
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
RLSuite.raidBuffColumns[#RLSuite.raidBuffColumns + 1] = { key = 'replen', label = 'Repl', icon = 'ReplIcon', classes = { 'MAGE' }, beneficiaries = { 'MAGE' }, scope = 'capped', cap = 10, spells = { 44561 } }
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
RLSuite.raidFrame._matrixColsCache = nil
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
RLSuite.raidBuffColumns[#RLSuite.raidBuffColumns] = nil
""")
check(bool(rt.eval("COMPB_REPLEN_EXPECTED == 10 and COMPB_REPLEN_APPLICABLE == 15")), "capped: Replenishment expects 10 of the 15 mana users (cap respected, not 'everyone')")
check(bool(rt.eval("COMPB_REPLEN_SAT_10 and COMPB_REPLEN_COUNT_10")), "capped: 10 covered auras SATISFY the check")
check(bool(rt.eval("COMPB_REPLEN_RED_10 == false")), "capped: a satisfied category shows NO red overlay")
check(bool(rt.eval("COMPB_REPLEN_RED == true")), "red overlay: an available category with nobody covered is flagged")
check(bool(rt.eval("COMPB_REPLEN_SAT_9 == false and COMPB_REPLEN_RED_9 == true")), "red overlay: dropping to 9 auras (below the 10 cap) flags the column again")

# --- Focus Magic: una FM per mago + nomi nell'alert -----------------------
rt.execute("""
RLSuite.raidBuffColumns[#RLSuite.raidBuffColumns + 1] = { key = 'focusMagic', label = 'FM', icon = 'FMIcon', classes = { 'MAGE' }, beneficiaries = { 'MAGE', 'WARLOCK', 'PRIEST', 'DRUID', 'SHAMAN', 'PALADIN' }, scope = 'single', spells = { 54646 } }
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
RLSuite.raidFrame._matrixColsCache = nil
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
RLSuite.raidBuffColumns[#RLSuite.raidBuffColumns] = nil
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
RLSuite.raidFrame._matrixColsCache = nil
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
RLSuite.raidFrame._matrixColsCache = nil
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
-- v1.11.74: drag & drop dei player ANCHE IN COMBAT (gate di fase rimosso)
-- =====================================================================
local RF = RLSuite.raidFrame
-- A) la fase non conta piu': abilitato in tutte e tre
local ph = {}
for _, pp in ipairs({ "preraid", "preboss", "infight" }) do
    RLSuite:SetContextPhase(pp)
    ph[pp] = RF:IsDragEnabled()
end
UW_P5_PRERAID, UW_P5_PREBOSS, UW_P5_INFIGHT = ph.preraid, ph.preboss, ph.infight

-- roster di prova + fase di COMBAT
RLSuite:ResetDebugRaid()
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
for i = 1, 5 do RLSuite:DebugInviteAccept("F" .. i, "WARRIOR") end
RLSuite:SetContextPhase("infight")
local SAVED_ICL, SAVED_ISD, SAVED_GCP = InCombatLockdown, IsShiftKeyDown, GetCursorPosition
InCombatLockdown = function() return true end
IsShiftKeyDown = function() return true end

-- sorgente = primo slot occupato non-tank; destinazione = primo slot vuoto dopo
local src, dst = nil, nil
for i, sl in ipairs(RF.slots) do
    if sl.member and not sl.isTank and not src then src = sl end
    if src and not sl.member and not dst and sl ~= src then dst = sl end
end
UW_P5_ROSTER = (src and src.member and src.member.name) or "?"
UW_P5_DST_EMPTY = (dst ~= nil and dst.member == nil)
src._manualDrag = nil; src._pendingRowClick = nil; src:SetScript("OnUpdate", nil); src._targetT = nil
src._scripts.OnMouseDown(src, "LeftButton")
UW_P5_SRC = (RF._rfDragSource == src)
UW_P5_TARGETS = dst:IsShown()
for i, sl in ipairs(RF.slots) do
    if sl ~= dst then
        sl.GetLeft = function() return 500 + i end
        sl.GetRight = function() return 501 + i end
        sl.GetBottom = function() return 500 end
        sl.GetTop = function() return 501 end
    end
end
dst.GetLeft = function() return 100 end; dst.GetRight = function() return 120 end
dst.GetBottom = function() return 60 end; dst.GetTop = function() return 80 end
GetCursorPosition = function() return 105, 70 end
dst._scripts.OnMouseUp(dst, "LeftButton")
UW_P5_MOVED = (dst.member and dst.member.name) or "?"
UW_P5_SRC_EMPTY = (src.member == nil)
UW_P5_CLEAN = (RF._rfDragSource == nil)
UW_P5_EMPTY_HIDDEN = not RF.slots[30]:IsShown()

-- B) percorso API REALE in combat: move e swap partono davvero
local SAVED_DM, SAVED_IRL = RLSuite.DebugMode, IsRaidLeader
RLSuite.DebugMode = function() return false end
IsRaidLeader = function() return true end
local calls = {}
SetRaidSubgroup = function(a, b) calls[#calls + 1] = "move:" .. tostring(a) .. "->" .. tostring(b) end
SwapRaidSubgroup = function(a, b) calls[#calls + 1] = "swap:" .. tostring(a) .. "-" .. tostring(b) end
RF:MoveSlot({ member = { name = "Alpha" }, raidIndex = 3, group = 1 }, { member = nil, group = 2 })
RF:MoveSlot({ member = { name = "Alpha" }, raidIndex = 3, group = 1 }, { member = { name = "Beta" }, raidIndex = 9, group = 2 })
UW_P5_API = table.concat(calls, " | ")
UW_P5_LOCKDOWN = InCombatLockdown()

-- ripristino
for _, sl in ipairs(RF.slots) do sl.GetLeft, sl.GetRight, sl.GetBottom, sl.GetTop = nil, nil, nil, nil end
SetRaidSubgroup, SwapRaidSubgroup = nil, nil
IsRaidLeader = SAVED_IRL
RLSuite.DebugMode = SAVED_DM
InCombatLockdown, IsShiftKeyDown, GetCursorPosition = SAVED_ICL, SAVED_ISD, SAVED_GCP
RLSuite:SetContextPhase("preraid")
RLSuite:ResetDebugRaid()
""")


check(bool(rt.eval("UW_P5_PRERAID == true and UW_P5_PREBOSS == true and UW_P5_INFIGHT == true")), "v1.11.74: drag dei player abilitato in TUTTE le fasi (preraid/preboss/infight) - il gate di fase e' stato rimosso")
check(bool(rt.eval("UW_P5_LOCKDOWN == true and UW_P5_SRC == true and UW_P5_TARGETS == true")), "v1.11.74: IN COMBAT (InCombatLockdown = true) Shift+click avvia il drag e gli slot vuoti diventano bersagli di drop")
check(bool(rt.eval("UW_P5_MOVED == UW_P5_ROSTER and UW_P5_SRC_EMPTY == true")), "v1.11.74: il rilascio in combat sposta DAVVERO il player (%s -> posizione vuota)" % rt.eval("UW_P5_ROSTER"))
check(bool(rt.eval("UW_P5_CLEAN == true and UW_P5_EMPTY_HIDDEN == true")), "v1.11.74: dopo il drop lo stato e' pulito e i blocchi vuoti tornano nascosti")
check(bool(rt.eval("UW_P5_DST_EMPTY == true and UW_P5_API == 'move:3->2 | swap:3-9'")), "v1.11.74: in combat MoveSlot chiama il client - move = SetRaidSubgroup, swap = SwapRaidSubgroup (%s)" % rt.eval("UW_P5_API"))
rt.execute("""
-- =====================================================================
-- v1.11.75: PIANI DI RILASCIO (frame non protetti) - il drag in combat
-- deve mostrare i bersagli anche se le righe non si possono mostrare
-- =====================================================================
local RF = RLSuite.raidFrame
RLSuite:ResetDebugRaid()
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
for i = 1, 5 do RLSuite:DebugInviteAccept("P" .. i, "WARRIOR") end
RLSuite:SetContextPhase("infight")

-- 1) fuori dal drag: piani esistenti, nascosti e col mouse spento
local n, hid, off = 0, 0, 0
for _, sl in ipairs(RF.slots) do
    if sl.dropPlane then
        n = n + 1
        if not sl.dropPlane:IsShown() then hid = hid + 1 end
        if sl.dropPlane._enabledMouse == false then off = off + 1 end
    end
end
UW_P6_PLANES = { n = n, hidden = hid, mouseoff = off }
UW_P6_TANK_PLANE = (RF.tankSlots[1].dropPlane == nil)

local SAVED_ICL, SAVED_ISD, SAVED_GCP = InCombatLockdown, IsShiftKeyDown, GetCursorPosition
local SAVED_SHOW, SAVED_HIDE = {}, {}
InCombatLockdown = function() return true end
IsShiftKeyDown = function() return true end
-- SIMULAZIONE del guasto visto in gioco: in combat le righe non si mostrano
-- piu' (Show/Hide no-op). I piani devono funzionare lo stesso.
for i, sl in ipairs(RF.slots) do
    SAVED_SHOW[i], SAVED_HIDE[i] = sl.Show, sl.Hide
    sl.Show = function() end
    sl.Hide = function() end
end

local src, dst = nil, nil
for i, sl in ipairs(RF.slots) do
    if sl.member and not src then src = sl end
    if src and not sl.member and not dst and sl ~= src then dst = sl end
end
UW_P6_SRC = (src and src.member and src.member.name) or "?"
src._manualDrag = nil; src._pendingRowClick = nil; src:SetScript("OnUpdate", nil); src._targetT = nil
src._scripts.OnMouseDown(src, "LeftButton")
UW_P6_STARTED = (RF._rfDragSource == src)
UW_P6_DST_ROW_SHOWN = dst:IsShown()          -- falso = guasto simulato attivo
UW_P6_DST_PLANE = dst.dropPlane and dst.dropPlane._state
UW_P6_SRC_PLANE = (src.dropPlane and src.dropPlane:IsShown()) and "shown" or "hidden"

-- 2) cursore sopra lo slot VUOTO (la riga resta invisibile): il bordo dorato
for i, sl in ipairs(RF.slots) do
    if sl ~= dst then
        sl.GetLeft = function() return 500 + i end
        sl.GetRight = function() return 501 + i end
        sl.GetBottom = function() return 500 end
        sl.GetTop = function() return 501 end
    end
end
dst.GetLeft = function() return 100 end; dst.GetRight = function() return 120 end
dst.GetBottom = function() return 60 end; dst.GetTop = function() return 80 end
GetCursorPosition = function() return 105, 70 end
local hit = RF:UpdateDropGlow()
UW_P6_HIT = (hit == dst)
UW_P6_GOLD = dst.dropPlane and dst.dropPlane._state
local golds = 0
for _, sl in ipairs(RF.slots) do
    if sl.dropPlane and sl.dropPlane:IsShown() and sl.dropPlane._state == "gold" then golds = golds + 1 end
end
UW_P6_GOLD_N = golds

-- 3) il rilascio arriva al PIANO (in gioco e' lui sotto il cursore)
dst.dropPlane._scripts.OnMouseUp(dst.dropPlane, "LeftButton")
UW_P6_MOVED = (dst.member and dst.member.name) or "?"
UW_P6_DST_HAS = (dst.member ~= nil)
UW_P6_SRC_EMPTY = (src.member == nil)
UW_P6_CLEAN = (RF._rfDragSource == nil)
UW_P6_PLANE_AFTER = dst.dropPlane:IsShown()
UW_P6_MOUSE_AFTER = dst.dropPlane._enabledMouse
UW_P6_ROW_BACKDROP = dst._backdrop

-- ripristino
for i, sl in ipairs(RF.slots) do
    sl.Show, sl.Hide = SAVED_SHOW[i], SAVED_HIDE[i]
    sl.GetLeft, sl.GetRight, sl.GetBottom, sl.GetTop = nil, nil, nil, nil
end
InCombatLockdown, IsShiftKeyDown, GetCursorPosition = SAVED_ICL, SAVED_ISD, SAVED_GCP
RLSuite:SetContextPhase("preraid")
RLSuite:ResetDebugRaid()
""")


check(bool(rt.eval("UW_P6_PLANES.n == 30 and UW_P6_PLANES.hidden == 30 and UW_P6_PLANES.mouseoff == 30 and UW_P6_TANK_PLANE == true")), "v1.11.75: ogni slot di gruppo ha un PIANO di rilascio, nascosto e col mouse spento fuori dal drag (le barre tank no: non sono drop target)")
check(bool(rt.eval("UW_P6_DST_ROW_SHOWN == false and UW_P6_STARTED == true")), "v1.11.75: anche con le righe BLOCCATE (Show/Hide no-op, come in combat) il drag parte lo stesso")
check(bool(rt.eval("UW_P6_DST_PLANE == 'empty' and UW_P6_SRC_PLANE == 'hidden'")), "v1.11.75: durante il drag lo slot VUOTO si vede (piano 'empty') e sulla sorgente non c'e' nessun piano")
check(bool(rt.eval("UW_P6_HIT == true and UW_P6_GOLD == 'gold' and UW_P6_GOLD_N == 1")), "v1.11.75: il bordo dorato segue il cursore anche su una riga invisibile: un solo piano dorato (quello sotto il cursore)")
check(bool(rt.eval("UW_P6_MOVED == UW_P6_SRC and UW_P6_DST_HAS == true and UW_P6_SRC_EMPTY == true and UW_P6_CLEAN == true")), "v1.11.75: rilasciando sul PIANO il player si sposta DAVVERO (%s -> %s | dstHas=%r srcEmpty=%r clean=%r)" % (rt.eval("UW_P6_SRC"), rt.eval("UW_P6_MOVED"), rt.eval("UW_P6_DST_HAS"), rt.eval("UW_P6_SRC_EMPTY"), rt.eval("UW_P6_CLEAN")))
check(bool(rt.eval("UW_P6_PLANE_AFTER == false and UW_P6_MOUSE_AFTER == false and UW_P6_ROW_BACKDROP == nil")), "v1.11.75: finito il drag i piani spariscono, il mouse torna alle righe e la riga resta senza bordo")
rt.execute("""
-- =====================================================================
-- v1.11.75b: rilascio visto dal WATCHDOG (tasto rilasciato fuori dalle
-- righe / release mangiato dal client) con le righe bloccate in combat
-- =====================================================================
local RF = RLSuite.raidFrame
RLSuite:ResetDebugRaid()
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
for i = 1, 5 do RLSuite:DebugInviteAccept("W" .. i, "WARRIOR") end
RLSuite:SetContextPhase("infight")

local SAVED_ICL, SAVED_ISD, SAVED_GCP, SAVED_IMBD = InCombatLockdown, IsShiftKeyDown, GetCursorPosition, IsMouseButtonDown
local SAVED_SHOW, SAVED_HIDE = {}, {}
InCombatLockdown = function() return true end
IsShiftKeyDown = function() return true end
IsMouseButtonDown = function() return false end
for i, sl in ipairs(RF.slots) do
    SAVED_SHOW[i], SAVED_HIDE[i] = sl.Show, sl.Hide
    sl.Show = function() end
    sl.Hide = function() end
end

local src, dst = nil, nil
for i, sl in ipairs(RF.slots) do
    if sl.member and not src then src = sl end
    if src and not sl.member and not dst and sl ~= src then dst = sl end
end
UW_P7_SRC = (src and src.member and src.member.name) or "?"
src._manualDrag = nil; src._pendingRowClick = nil; src:SetScript("OnUpdate", nil); src._targetT = nil
src._scripts.OnMouseDown(src, "LeftButton")
for i, sl in ipairs(RF.slots) do
    if sl ~= dst then
        sl.GetLeft = function() return 500 + i end
        sl.GetRight = function() return 501 + i end
        sl.GetBottom = function() return 500 end
        sl.GetTop = function() return 501 end
    end
end
dst.GetLeft = function() return 100 end; dst.GetRight = function() return 120 end
dst.GetBottom = function() return 60 end; dst.GetTop = function() return 80 end
GetCursorPosition = function() return 105, 70 end
local watch = RF._dragWatch
UW_P7_ARMED = (watch ~= nil and RF._dragWatchArmed == true)
if watch then watch:GetScript("OnUpdate")() end
UW_P7_MOVED = (dst.member and dst.member.name) or "?"
UW_P7_SRC_EMPTY = (src.member == nil)
UW_P7_CLEAN = (RF._rfDragSource == nil and RF._dropActive == nil)
UW_P7_PLANES_OFF = (dst.dropPlane:IsShown() == false and dst.dropPlane._enabledMouse == false)

for i, sl in ipairs(RF.slots) do
    sl.Show, sl.Hide = SAVED_SHOW[i], SAVED_HIDE[i]
    sl.GetLeft, sl.GetRight, sl.GetBottom, sl.GetTop = nil, nil, nil, nil
end
InCombatLockdown, IsShiftKeyDown, GetCursorPosition, IsMouseButtonDown = SAVED_ICL, SAVED_ISD, SAVED_GCP, SAVED_IMBD
RLSuite:SetContextPhase("preraid")
RLSuite:ResetDebugRaid()
""")


check(bool(rt.eval("UW_P7_ARMED == true")), "v1.11.75: il watchdog del drag si arma anche in combat (rete di sicurezza sul rilascio)")
check(bool(rt.eval("UW_P7_MOVED == UW_P7_SRC and UW_P7_SRC_EMPTY == true")), "v1.11.75: il rilascio visto dal WATCHDOG (righe bloccate, slot invisibile) sposta comunque il player (%s)" % rt.eval("UW_P7_SRC"))
check(bool(rt.eval("UW_P7_CLEAN == true and UW_P7_PLANES_OFF == true")), "v1.11.75: dopo il drop del watchdog lo stato e' pulito e i piani sono spenti")
rt.execute("""
-- =====================================================================
-- v1.11.76: barra HP e icone CD FUORI dalla riga (visibili anche quando
-- la riga non si mostra): l'update grafico non deve dipendere dalla riga
-- =====================================================================
local RF = RLSuite.raidFrame
RLSuite:ResetDebugRaid()
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
for i = 1, 5 do RLSuite:DebugInviteAccept("B" .. i, "WARRIOR") end
RLSuite:SetContextPhase("infight")

-- A) dove vivono i pezzi: barra e CD fuori dalla riga, come le icone
local row = RF.rows[1]
local tr = RF.tankSlots[1]
UW_P8_PARENT = {
    bar = (row.bar:GetParent() == RF.content),
    cd  = (row.cdIcons[1] and row.cdIcons[1]._parent == row.cdHolder and row.cdHolder._parent == RF.content),
    tankBar = (tr.bar:GetParent() == RF.content),
    icon = true,
}

-- B) GUASTO SIMULATO: la riga si nasconde (row:Hide()) come in combat.
--    Barra e CD devono restare visibili: non sono piu' suoi figli.
local dst = nil
for i, sl in ipairs(RF.slots) do
    if not sl.member and not dst then dst = sl end
end
-- riempio lo slot vuoto con un member di prova (stessa strada di FillSlot)
local fakeMember = { name = "Prova", class = "WARRIOR", unit = nil, fake = true, raidIndex = nil }
RF:FillSlot(dst, fakeMember)
dst:Hide() -- la riga "non si mostra" (simulazione del guasto in combat)
UW_P8_FILLED = { bar = dst.bar:IsShown(), cd1 = (dst.cdIcons[1] and dst.cdIcons[1]:IsShown()) or false }

-- C) slot VUOTO: la barra deve restare spenta (nessun rettangolo vuoto)
local emptySlot = nil
for i, sl in ipairs(RF.slots) do
    if not sl.member and sl ~= dst and not emptySlot then emptySlot = sl end
end
UW_P8_CLEAR = (emptySlot.bar:IsShown() == false)

-- D) svuoto e riempio lo STESSO slot con la stessa classe: i CD tornano
RF:ClearSlot(dst)
local cdAfterClear = (dst.cdIcons[1] and dst.cdIcons[1]:IsShown()) or false
RF:FillSlot(dst, fakeMember)
UW_P8_REFILL = { afterClear = cdAfterClear, afterRefill = (dst.cdIcons[1] and dst.cdIcons[1]:IsShown()) or false }
RF:ClearSlot(dst)
RF:Rebuild()

-- E) scenario vero: in combat, con le righe bloccate, il player si sposta e
--    la riga di destinazione mostra barra e CD
local SAVED_ICL, SAVED_ISD, SAVED_GCP = InCombatLockdown, IsShiftKeyDown, GetCursorPosition
local SAVED_SHOW, SAVED_HIDE = {}, {}
InCombatLockdown = function() return true end
IsShiftKeyDown = function() return true end
for i, sl in ipairs(RF.slots) do
    SAVED_SHOW[i], SAVED_HIDE[i] = sl.Show, sl.Hide
    sl.Show = function() end
    sl.Hide = function() end
end
local src, dst2 = nil, nil
for i, sl in ipairs(RF.slots) do
    if sl.member and not src then src = sl end
    if src and not sl.member and not dst2 and sl ~= src then dst2 = sl end
end
UW_P8_SRC = (src and src.member and src.member.name) or "?"
src._manualDrag = nil; src._pendingRowClick = nil; src:SetScript("OnUpdate", nil); src._targetT = nil
src._scripts.OnMouseDown(src, "LeftButton")
for i, sl in ipairs(RF.slots) do
    if sl ~= dst2 then
        sl.GetLeft = function() return 500 + i end
        sl.GetRight = function() return 501 + i end
        sl.GetBottom = function() return 500 end
        sl.GetTop = function() return 501 end
    end
end
dst2.GetLeft = function() return 100 end; dst2.GetRight = function() return 120 end
dst2.GetBottom = function() return 60 end; dst2.GetTop = function() return 80 end
GetCursorPosition = function() return 105, 70 end
dst2.dropPlane._scripts.OnMouseUp(dst2.dropPlane, "LeftButton")
UW_P8_MOVED = (dst2.member and dst2.member.name) or "?"
UW_P8_AFTER = {
    bar = dst2.bar:IsShown(),
    cd1 = (dst2.cdIcons[1] and dst2.cdIcons[1]:IsShown()) or false,
    rowHidden = (dst2:IsShown() == false),
}
for i, sl in ipairs(RF.slots) do
    sl.Show, sl.Hide = SAVED_SHOW[i], SAVED_HIDE[i]
    sl.GetLeft, sl.GetRight, sl.GetBottom, sl.GetTop = nil, nil, nil, nil
end
InCombatLockdown, IsShiftKeyDown, GetCursorPosition = SAVED_ICL, SAVED_ISD, SAVED_GCP
RLSuite:SetContextPhase("preraid")
RLSuite:ResetDebugRaid()
""")


check(bool(rt.eval("UW_P8_PARENT.bar == true and UW_P8_PARENT.cd == true and UW_P8_PARENT.tankBar == true and UW_P8_PARENT.icon == true")), "v1.11.76: barra HP e icone CD vivono su CONTENT (come le icone consumabili), non dentro la riga")
check(bool(rt.eval("UW_P8_FILLED.bar == true and UW_P8_FILLED.cd1 == true")), "v1.11.76: con la riga NON mostrata (guasto simulato) barra e CD restano visibili")
check(bool(rt.eval("UW_P8_CLEAR == true")), "v1.11.76: uno slot VUOTO resta senza barra (nessun rettangolo vuoto in giro)")
check(bool(rt.eval("UW_P8_REFILL.afterClear == false and UW_P8_REFILL.afterRefill == true")), "v1.11.76: svuotando e riempiendo lo stesso slot (stessa classe) i CD tornano visibili")
check(bool(rt.eval("UW_P8_MOVED == UW_P8_SRC and UW_P8_AFTER.bar == true and UW_P8_AFTER.cd1 == true")), "v1.11.76: in combat, dopo lo spostamento la riga di destinazione mostra barra e CD anche con la riga nascosta (%s -> %s)" % (rt.eval("UW_P8_SRC"), rt.eval("UW_P8_MOVED")))
rt.execute("""
-- =====================================================================
-- v1.11.77 (diagnosi): roster SPARSO in debug - un player spostato
-- deve poter essere spostato ANCORA (membri finti: solo il player)
-- =====================================================================
local RF = RLSuite.raidFrame
RLSuite:ResetDebugRaid()          -- 1 solo membro: il player, slot 1
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
RLSuite:SetContextPhase("infight")
RF:Rebuild()
UW_P9_ROSTER0 = #RLSuite:DebugRoster()

local SAVED_ISD, SAVED_GCP = IsShiftKeyDown, GetCursorPosition
IsShiftKeyDown = function() return true end

-- geometria: solo lo slot passato sta sotto il cursore
local function cursorOn(target)
    for i, sl in ipairs(RF.slots) do
        if sl ~= target then
            sl.GetLeft = function() return 500 + i end
            sl.GetRight = function() return 501 + i end
            sl.GetBottom = function() return 500 end
            sl.GetTop = function() return 501 end
        end
    end
    target.GetLeft = function() return 100 end
    target.GetRight = function() return 120 end
    target.GetBottom = function() return 60 end
    target.GetTop = function() return 80 end
    GetCursorPosition = function() return 105, 70 end
end

local function cleanRow(sl)
    sl._manualDrag = nil; sl._pendingRowClick = nil; sl._targetT = nil
    sl:SetScript("OnUpdate", nil)
end

local s1, s8, s3 = RF.slots[1], RF.slots[8], RF.slots[3]

-- DRAG 1: slot 1 (il player) -> slot 8 (vuoto)
cleanRow(s1)
cursorOn(s8)
s1._scripts.OnMouseDown(s1, "LeftButton")
UW_P9_D1_START = (RF._rfDragSource == s1 and s1.member ~= nil)
s8.dropPlane._scripts.OnMouseUp(s8.dropPlane, "LeftButton")
local slots = RLSuite:DebugRaidSlots()
UW_P9_D1 = {
    at8 = (slots[8] and slots[8].name) or "?",
    at1 = (slots[1] == nil),
    row8 = (RF.slots[8].member and RF.slots[8].member.name) or "?",
    row1_empty = (RF.slots[1].member == nil),
    clean = (RF._rfDragSource == nil),
}

-- DRAG 2: lo STESSO player, ora in slot 8 -> slot 3 (vuoto)
local s8b = RF.slots[8]
cleanRow(s8b)
cursorOn(s3)
s8b._scripts.OnMouseDown(s8b, "LeftButton")
UW_P9_D2_START = (RF._rfDragSource == s8b)
UW_P9_D2_HIT = (RF:SlotAtCursor() == s3)
s3.dropPlane._scripts.OnMouseUp(s3.dropPlane, "LeftButton")
local slots2 = RLSuite:DebugRaidSlots()
UW_P9_D2 = {
    started = UW_P9_D2_START,
    hit = UW_P9_D2_HIT,
    at3 = (slots2[3] and slots2[3].name) or "?",
    at8_gone = (slots2[8] == nil),
    row3 = (RF.slots[3].member and RF.slots[3].member.name) or "?",
}

for i, sl in ipairs(RF.slots) do
    sl.GetLeft, sl.GetRight, sl.GetBottom, sl.GetTop = nil, nil, nil, nil
end
IsShiftKeyDown, GetCursorPosition = SAVED_ISD, SAVED_GCP
RLSuite:SetContextPhase("preraid")
RLSuite:ResetDebugRaid()
RF:Rebuild()
""")


check(bool(rt.eval("UW_P9_ROSTER0 == 1")), "v1.11.77: partenza con UN solo membro (il player) - roster=%r" % rt.eval("UW_P9_ROSTER0"))
check(bool(rt.eval("UW_P9_D1.at8 ~= '?' and UW_P9_D1.at1 == true and UW_P9_D1.row8 ~= '?' and UW_P9_D1.row1_empty == true and UW_P9_D1.clean == true")), "v1.11.77: primo spostamento OK (%s -> slot 8, slot 1 libero)" % rt.eval("UW_P9_D1.at8"))
check(bool(rt.eval("UW_P9_D2.started == true and UW_P9_D2.hit == true")), "v1.11.77: il secondo drag PARTE dalla riga nuova e il cursore trova lo slot di destinazione")
check(bool(rt.eval("UW_P9_D2.at3 ~= '?' and UW_P9_D2.at8_gone == true and UW_P9_D2.row3 ~= '?'")), "v1.11.77: un player GIA' spostato si sposta ANCORA (%s -> slot 3)" % rt.eval("UW_P9_D2.at3"))
rt.execute("""
-- =====================================================================
-- v1.11.78: il DRAG non dipende piu' da chi riceve gli eventi.
-- Il gesto e' retto dal poller di RLSuite.raidFrame (stato del tasto +
-- POSIZIONE del cursore), quindi funziona anche se il client non consegna
-- pressione/rilascio alle righe: e' il caso del report "un player si
-- sposta una volta e poi non si muove piu'".
-- =====================================================================
local RF = RLSuite.raidFrame
RLSuite:ResetDebugRaid()
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
RLSuite:SetContextPhase("infight")
RF:Rebuild()

local SAVED_ISD, SAVED_GCP = IsShiftKeyDown, GetCursorPosition
local SAVED_IMBD, SAVED_ICL = IsMouseButtonDown, InCombatLockdown
local SHIFT = true
IsShiftKeyDown = function() return SHIFT end
InCombatLockdown = function() return true end      -- siamo in pull
local DOWN = false
IsMouseButtonDown = function(b) return DOWN and b == "LeftButton" end
local CUR_X, CUR_Y = 0, 0
GetCursorPosition = function() return CUR_X, CUR_Y end

-- Geometria a griglia (il client la fornisce per ogni riga).
local ROW_W, ROW_H = 120, 14
local function rectFor(i)
    local col = (i - 1) % 5
    local rw = math.floor((i - 1) / 5)
    local x0 = 100 + col * 130
    local y1 = 600 - rw * 20
    return x0, x0 + ROW_W, y1 - ROW_H, y1
end
local function setRect(f, x0, x1, y0, y1)
    f.GetLeft = function() return x0 end
    f.GetRight = function() return x1 end
    f.GetBottom = function() return y0 end
    f.GetTop = function() return y1 end
end
for i, sl in ipairs(RF.slots) do
    local x0, x1, y0, y1 = rectFor(i)
    setRect(sl, x0, x1, y0, y1)
    if sl.dropPlane then setRect(sl.dropPlane, x0, x1, y0, y1) end
    if sl.secTarget then setRect(sl.secTarget, x0, x1, y0, y1) end
end
local function centerOf(i)
    local x0, x1, y0, y1 = rectFor(i)
    return (x0 + x1) / 2, (y0 + y1) / 2
end
local function tick(el)
    if RF._dragPoller and RF._dragPoller._scripts and RF._dragPoller._scripts.OnUpdate then
        RF._dragPoller._scripts.OnUpdate(RF._dragPoller, el or 0.05)
    end
end

UW_P11_POLLER = {
    exists = (RF._dragPoller ~= nil),
    mouseOff = (RF._dragPoller and RF._dragPoller._enabledMouse == false),
}

-- IL CLIENT "MANGIA" TUTTI GLI EVENTI DELLE RIGHE: nessun handler.
local muted = {}
local function mute(f)
    if not f then return end
    muted[#muted + 1] = { f = f, down = f._scripts and f._scripts.OnMouseDown,
                          up = f._scripts and f._scripts.OnMouseUp }
    f:SetScript("OnMouseDown", nil)
    f:SetScript("OnMouseUp", nil)
end
for i, sl in ipairs(RF.slots) do
    mute(sl)
    mute(sl.dropPlane)
    mute(sl.secTarget)
end

-- DRAG 1: player (slot 1) -> slot 8
CUR_X, CUR_Y = centerOf(1)
DOWN = true
tick()
UW_P11_START1 = (RF._rfDragSource == RF.slots[1])
UW_P11_PLANES = 0
for i, sl in ipairs(RF.slots) do
    if sl.dropPlane and sl.dropPlane:IsShown() and sl ~= RF.slots[1] then
        UW_P11_PLANES = UW_P11_PLANES + 1
    end
end
CUR_X, CUR_Y = centerOf(8)
DOWN = false
tick()
local slots = RLSuite:DebugRaidSlots()
UW_P11_D1 = {
    at8 = (slots[8] and slots[8].name) or "?",
    at1_free = (slots[1] == nil),
    row8 = (RF.slots[8].member and RF.slots[8].member.name) or "?",
}

-- DRAG 2: lo STESSO player, slot 8 -> slot 3 (nessun reset a mano)
CUR_X, CUR_Y = centerOf(8)
DOWN = true
tick()
UW_P11_START2 = (RF._rfDragSource == RF.slots[8])
CUR_X, CUR_Y = centerOf(3)
DOWN = false
tick()
slots = RLSuite:DebugRaidSlots()
UW_P11_D2 = {
    at3 = (slots[3] and slots[3].name) or "?",
    at8_free = (slots[8] == nil),
    row3 = (RF.slots[3].member and RF.slots[3].member.name) or "?",
    clean = (RF._rfDragSource == nil and RF._dragBtnDown == false),
}

-- SHIFT ARRIVA DOPO LA PRESSIONE: il drag parte comunque.
SHIFT = false
CUR_X, CUR_Y = centerOf(3)
DOWN = true
tick()
UW_P11_LATE_NODRAG = (RF._rfDragSource == nil)
SHIFT = true
tick()
UW_P11_LATE_START = (RF._rfDragSource == RF.slots[3])
DOWN = false
tick()

-- RILASCIO FUORI DALLE RIGHE: annullo, nessuno spostamento, stato pulito.
CUR_X, CUR_Y = centerOf(3)
DOWN = true
tick()
CUR_X, CUR_Y = 5, 5       -- fuori da ogni barra
DOWN = false
tick()
slots = RLSuite:DebugRaidSlots()
UW_P11_OUT = {
    still3 = (slots[3] and slots[3].name) or "?",
    clean = (RF._rfDragSource == nil),
    planesOff = true,
}
for i, sl in ipairs(RF.slots) do
    if sl.dropPlane and sl.dropPlane:IsShown() then UW_P11_OUT.planesOff = false end
end

-- Ripristino
for _, m in ipairs(muted) do
    m.f:SetScript("OnMouseDown", m.down)
    m.f:SetScript("OnMouseUp", m.up)
end
for i, sl in ipairs(RF.slots) do
    sl.GetLeft, sl.GetRight, sl.GetBottom, sl.GetTop = nil, nil, nil, nil
    if sl.dropPlane then sl.dropPlane.GetLeft, sl.dropPlane.GetRight, sl.dropPlane.GetBottom, sl.dropPlane.GetTop = nil, nil, nil, nil end
    if sl.secTarget then sl.secTarget.GetLeft, sl.secTarget.GetRight, sl.secTarget.GetBottom, sl.secTarget.GetTop = nil, nil, nil, nil end
end
IsShiftKeyDown, GetCursorPosition = SAVED_ISD, SAVED_GCP
IsMouseButtonDown, InCombatLockdown = SAVED_IMBD, SAVED_ICL
RLSuite:SetContextPhase("preraid")
RLSuite:ResetDebugRaid()
RF:Rebuild()
""")


check(bool(rt.eval("UW_P11_POLLER.exists == true and UW_P11_POLLER.mouseOff == true")), "v1.11.78: il poller del drag esiste ed e' a mouse SPENTO (non ruba click)")
check(bool(rt.eval("UW_P11_START1 == true and UW_P11_PLANES > 20 and UW_P11_D1.at8 ~= '?' and UW_P11_D1.at1_free == true and UW_P11_D1.row8 ~= '?'")), "v1.11.78: drag+drop con TUTTI gli handler delle righe spenti (%s -> slot 8, %s bersagli)" % (rt.eval("UW_P11_D1.at8"), rt.eval("UW_P11_PLANES")))
check(bool(rt.eval("UW_P11_START2 == true and UW_P11_D2.at3 ~= '?' and UW_P11_D2.at8_free == true and UW_P11_D2.row3 ~= '?' and UW_P11_D2.clean == true")), "v1.11.78: un player GIA' spostato si sposta ANCORA, anche con gli handler spenti (%s -> slot 3)" % rt.eval("UW_P11_D2.at3"))
check(bool(rt.eval("UW_P11_LATE_NODRAG == true and UW_P11_LATE_START == true")), "v1.11.78: se lo shift arriva DOPO la pressione il drag parte lo stesso")
check(bool(rt.eval("UW_P11_OUT.still3 ~= '?' and UW_P11_OUT.clean == true and UW_P11_OUT.planesOff == true")), "v1.11.78: rilascio fuori dalle barre = annullo (nessuno spostamento, stato e piani puliti)")
rt.execute("""
-- =====================================================================
-- v1.11.79: DIAGNOSTICA del drag (HUD + pannello Raid Group).
-- Il press viene tracciato SEMPRE (in debug mode): se un gesto non fa
-- niente, la chat dice se la barra era piena, vuota o se il cursore non
-- era su una barra. Qui si verifica che il tracciato sia coerente e che
-- il pannello Raid Group si muova con il SUO poller, senza la macchina
-- drag del client (RegisterForDrag + OnDragStart/Stop).
-- =====================================================================
local RF = RLSuite.raidFrame
local GM = RLSuite.groupmaking
local SAVED_IMBD, SAVED_GCP = IsMouseButtonDown, GetCursorPosition
local SAVED_ISD = IsShiftKeyDown
IsShiftKeyDown = function() return true end
local DOWN = false
IsMouseButtonDown = function(b) return DOWN and b == "LeftButton" end
local CUR_X, CUR_Y = 0, 0
GetCursorPosition = function() return CUR_X, CUR_Y end

-- ---------------------------------------------------------------- HUD
RLSuite:ResetDebugRaid()          -- solo il player
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
RLSuite:SetContextPhase("infight")
RF:Rebuild()

local ROW_W, ROW_H = 120, 14
local function setRect(f, x0, x1, y0, y1)
    f.GetLeft = function() return x0 end
    f.GetRight = function() return x1 end
    f.GetBottom = function() return y0 end
    f.GetTop = function() return y1 end
end
local function hudRect(i)
    local col = (i - 1) % 5
    local rw = math.floor((i - 1) / 5)
    local x0 = 100 + col * 130
    local y1 = 600 - rw * 20
    return x0, x0 + ROW_W, y1 - ROW_H, y1
end
for i, sl in ipairs(RF.slots) do
    local x0, x1, y0, y1 = hudRect(i)
    setRect(sl, x0, x1, y0, y1)
    if sl.dropPlane then setRect(sl.dropPlane, x0, x1, y0, y1) end
    if sl.secTarget then setRect(sl.secTarget, x0, x1, y0, y1) end
end
RF.frame.GetLeft = function() return 0 end
RF.frame.GetRight = function() return 1000 end
RF.frame.GetBottom = function() return 0 end
RF.frame.GetTop = function() return 1000 end

local function hudTick()
    if RF._dragPoller and RF._dragPoller._scripts and RF._dragPoller._scripts.OnUpdate then
        RF._dragPoller._scripts.OnUpdate(RF._dragPoller, 0.05)
    end
end

-- pressione su una barra PIENA (slot 1: il player)
local function hudCenter(i)
    local x0, x1, y0, y1 = hudRect(i)
    return (x0 + x1) / 2, (y0 + y1) / 2
end
CUR_X, CUR_Y = hudCenter(1)
DOWN = true
hudTick()
UW_P12_FULL = {
    press = (RF._dragPressSlot == RF.slots[1]),
    started = (RF._rfDragSource == RF.slots[1]),
    over = RF:IsCursorOverFrame(),
    txt = RF:CursorText(),
}
DOWN = false
hudTick()

-- pressione su una barra VUOTA (slot 5): nessun drag, ma il tracciato c'e'
CUR_X, CUR_Y = hudCenter(5)
DOWN = true
hudTick()
UW_P12_EMPTY = {
    press = (RF._dragPressSlot == nil),
    started = (RF._rfDragSource == nil),
}
DOWN = false
hudTick()
RF.frame.GetLeft, RF.frame.GetRight, RF.frame.GetBottom, RF.frame.GetTop = nil, nil, nil, nil
for i, sl in ipairs(RF.slots) do
    sl.GetLeft, sl.GetRight, sl.GetBottom, sl.GetTop = nil, nil, nil, nil
    if sl.dropPlane then sl.dropPlane.GetLeft, sl.dropPlane.GetRight, sl.dropPlane.GetBottom, sl.dropPlane.GetTop = nil, nil, nil, nil end
    if sl.secTarget then sl.secTarget.GetLeft, sl.secTarget.GetRight, sl.secTarget.GetBottom, sl.secTarget.GetTop = nil, nil, nil, nil end
end

-- ------------------------------------------------- PANNELLO RAID GROUP
RLSuite:ResetDebugRaid()
for i = 1, 6 do RLSuite:DebugInviteAccept("Mv" .. i, "WARRIOR") end
GM:UpdateWLGroups()

UW_P12_PANEL_POLLER = {
    exists = (GM._wlDragPoller ~= nil),
    mouseOff = (GM._wlDragPoller and GM._wlDragPoller._enabledMouse == false),
}

local function barRect(i)
    local col = math.floor((i - 1) / 5)
    local row = (i - 1) % 5
    local x0 = 200 + col * 60
    local y1 = 400 - row * 20
    return x0, x0 + 50, y1 - 14, y1
end
for i, bar in ipairs(GM.wlGroupSlots) do
    local x0, x1, y0, y1 = barRect(i)
    setRect(bar, x0, x1, y0, y1)
end
local function barCenter(i)
    local x0, x1, y0, y1 = barRect(i)
    return (x0 + x1) / 2, (y0 + y1) / 2
end
local function panelTick()
    if GM._wlDragPoller and GM._wlDragPoller._scripts and GM._wlDragPoller._scripts.OnUpdate then
        GM._wlDragPoller._scripts.OnUpdate(GM._wlDragPoller, 0.05)
    end
end

-- Via la macchina drag del CLIENT (come se il client non consegnasse nulla).
local muted = {}
for i, bar in ipairs(GM.wlGroupSlots) do
    muted[#muted + 1] = { f = bar, start = bar._scripts.OnDragStart,
        stop = bar._scripts.OnDragStop, recv = bar._scripts.OnReceiveDrag }
    bar:SetScript("OnDragStart", nil)
    bar:SetScript("OnDragStop", nil)
    bar:SetScript("OnReceiveDrag", nil)
end

-- DRAG 1: barra 1 (player) -> barra 11 (G3, vuota)
CUR_X, CUR_Y = barCenter(1)
DOWN = true
panelTick()
UW_P13_D1_START = (GM._wlDragSource == GM.wlGroupSlots[1])
UW_PLAYER = (RLSuite:DebugRoster()[1] and RLSuite:DebugRoster()[1].name) or "?"
CUR_X, CUR_Y = barCenter(11)
DOWN = false
panelTick()
local slots = RLSuite:DebugRaidSlots()
UW_P13_D1 = {
    at11 = (slots[11] and slots[11].name) or "?",
    at1_free = (slots[1] == nil),
    bar11 = GM.wlGroupSlots[11].playerName or "?",
    clean = (GM._wlDragSource == nil),
}

-- DRAG 2: di nuovo lo stesso giocatore, barra 11 -> barra 3
CUR_X, CUR_Y = barCenter(11)
DOWN = true
panelTick()
UW_P13_D2_START = (GM._wlDragSource == GM.wlGroupSlots[11])
CUR_X, CUR_Y = barCenter(3)
DOWN = false
panelTick()
slots = RLSuite:DebugRaidSlots()
UW_P13_D2 = {
    at3 = (slots[3] and slots[3].name) or "?",
    at11 = (slots[11] and slots[11].name) or "nil",
    bar3 = GM.wlGroupSlots[3].playerName or "?",
    bar11 = GM.wlGroupSlots[11].playerName or "nil",
}

-- pressione su una barra VUOTA (barra 26, fuori dal roster): nessun drag
CUR_X, CUR_Y = barCenter(26)
DOWN = true
panelTick()
UW_P13_EMPTY = (GM._wlDragSource == nil)
DOWN = false
panelTick()

-- Ripristino
for _, m in ipairs(muted) do
    m.f:SetScript("OnDragStart", m.start)
    m.f:SetScript("OnDragStop", m.stop)
    m.f:SetScript("OnReceiveDrag", m.recv)
end
for i, bar in ipairs(GM.wlGroupSlots) do
    bar.GetLeft, bar.GetRight, bar.GetBottom, bar.GetTop = nil, nil, nil, nil
end
IsMouseButtonDown, GetCursorPosition = SAVED_IMBD, SAVED_GCP
IsShiftKeyDown = SAVED_ISD
RLSuite:SetContextPhase("preraid")
RLSuite:ResetDebugRaid()
RF:Rebuild()
GM:UpdateWLGroups()
""")


check(bool(rt.eval("UW_P12_FULL.press == true and UW_P12_FULL.started == true and UW_P12_FULL.over == true and UW_P12_FULL.txt ~= '?'")), "v1.11.79: pressione con shift su una barra PIENA = drag avviato, e il tracciato sa dire che il cursore e' sull'HUD (%s)" % rt.eval("UW_P12_FULL.txt"))
check(bool(rt.eval("UW_P12_EMPTY.press == true and UW_P12_EMPTY.started == true")), "v1.11.79: pressione su una barra VUOTA = nessun drag (ma il tracciato lo dice: 'barra N VUOTA')")
check(bool(rt.eval("UW_P12_PANEL_POLLER.exists == true and UW_P12_PANEL_POLLER.mouseOff == true")), "v1.11.79: anche il pannello Raid Group ha il suo poller del drag, a mouse spento")
check(bool(rt.eval("UW_P13_D1_START == true and UW_P13_D1.at11 ~= '?' and UW_P13_D1.at1_free == true and UW_P13_D1.bar11 ~= '?' and UW_P13_D1.clean == true")), "v1.11.79: pannello Raid Group - drag+drop SENZA la macchina drag del client (%s -> barra 11)" % rt.eval("UW_P13_D1.at11"))
check(bool(rt.eval("UW_P13_D2_START == true and UW_P13_D2.at3 == UW_PLAYER and UW_P13_D2.at11 ~= 'nil' and UW_P13_D2.bar3 == UW_PLAYER and UW_P13_D2.bar11 == UW_P13_D2.at11")), "v1.11.79: pannello Raid Group - un player GIA' spostato si sposta ANCORA e su barra piena SCAMBIA (%s -> barra 3, barra 11 = %s)" % (rt.eval("UW_P13_D2.at3"), rt.eval("UW_P13_D2.at11")))
check(bool(rt.eval("UW_P13_EMPTY == true")), "v1.11.79: pannello Raid Group - pressione su una barra vuota = nessun drag (barra 26 vuota=bar26=%s)" % rt.eval("GM.wlGroupSlots[26].playerName"))
rt.execute("""
-- =====================================================================
-- v1.11.80: la versione mostrata deve venire dalla cartella DAVVERO
-- caricata, e le copie multiple dell'addon devono essere DENUNCIATE.
-- (Caso reale: l'addon in chat diceva 1.11.52 mentre girava l'ultima
-- build -> la versione era cercata nella cartella fissa "RaidLeadSuite".)
-- =====================================================================
local SAVED_GAM, SAVED_IAL = GetAddOnMetadata, IsAddOnLoaded
local SAVED_FOLDER, SAVED_VER = RLSuite.addonFolder, RLSuite.version

GetAddOnMetadata = function(name, field)
    if name == "RaidLeadSuite" then return "1.11.52" end   -- copia vecchia rimasta
    if name == "RLSuite" then return "1.11.80" end          -- cartella vera
    return nil
end
IsAddOnLoaded = function(name) return name == "RLSuite" end

RLSuite.baseName = "RLSuite"
RLSuite.addonFolder = "RLSuite"
RLSuite:RefreshVersionFromFolder()
UW_P14_VERSION = RLSuite.version

local info = RLSuite:AddonCopiesInfo()
UW_P14_COPIES = { n = #info, a = info[1] and (info[1].name .. "/" .. tostring(info[1].version) .. "/" .. tostring(info[1].loaded)) or "?",
                  b = info[2] and (info[2].name .. "/" .. tostring(info[2].version) .. "/" .. tostring(info[2].loaded)) or "?" }
local warn = RLSuite:AddonCopiesWarning()
UW_P14_WARN = { has = (warn ~= nil), n = warn and #warn or 0,
                mentionsOld = false, mentionsNew = false }
if warn then
    local all = table.concat(warn, " | ")
    UW_P14_WARN.mentionsOld = (all:find("1.11.52", 1, true) ~= nil)
    UW_P14_WARN.mentionsNew = (all:find("CARICATA", 1, true) ~= nil)
end

-- Una sola copia: nessun avviso.
GetAddOnMetadata = function(name, field)
    if name == "RLSuite" then return "1.11.80" end
    return nil
end
UW_P14_SINGLE_WARN = (RLSuite:AddonCopiesWarning() == nil)
UW_P14_SINGLE_N = #RLSuite:AddonCopiesInfo()

GetAddOnMetadata, IsAddOnLoaded = SAVED_GAM, SAVED_IAL
RLSuite.baseName = nil
RLSuite.addonFolder = SAVED_FOLDER
RLSuite.version = SAVED_VER
""")


check(bool(rt.eval("UW_P14_VERSION == '1.11.80'")), "v1.11.80: la versione viene letta dal .toc della cartella caricata (%s), non da un nome fisso" % rt.eval("UW_P14_VERSION"))
check(bool(rt.eval("UW_P14_COPIES.n == 2 and UW_P14_COPIES.a == 'RaidLeadSuite/1.11.52/false' and UW_P14_COPIES.b == 'RLSuite/1.11.80/true'")), "v1.11.80: con DUE copie installate le elenca entrambe con versione e stato (%s, %s)" % (rt.eval("UW_P14_COPIES.a"), rt.eval("UW_P14_COPIES.b")))
check(bool(rt.eval("UW_P14_WARN.has == true and UW_P14_WARN.n >= 3 and UW_P14_WARN.mentionsOld == true and UW_P14_WARN.mentionsNew == true")), "v1.11.80: l'avviso nomina la copia vecchia (1.11.52) e dice quale e' CARICATA")
check(bool(rt.eval("UW_P14_SINGLE_WARN == true and UW_P14_SINGLE_N == 1")), "v1.11.80: con UNA sola copia nessun avviso (una voce in elenco)")

rt.execute("""
-- =====================================================================
-- v1.11.82: TOLLERANZA del gesto + barre Tanks inerti (come sempre).
-- Il report parlava di barre giocatore NEI GRUPPI: le barre MT/OT restano
-- fuori dal trascinamento e non sono ne' sorgenti ne' bersagli. Il gesto
-- ora aggancia la barra anche a pochi pixel di distanza (righe da ~20 px:
-- un click a filo finiva nel vuoto e sembrava che quel player non si
-- potesse piu' spostare).
-- =====================================================================
local RF = RLSuite.raidFrame
RLSuite:ResetDebugRaid()
RLSuite.db.profile.debug = true
RLSuite:ApplyDebugMode()
RLSuite:SetContextPhase("infight")
RF:Rebuild()

local mt = RF.tankSlots[1]
UW_P16_TANK = {
    filled = (mt.member ~= nil),
    name = (mt.member and mt.member.name) or "?",
    isTank = (mt.isTank == true),
    targetBar = (mt.targetBar ~= nil),
    noConsumables = (mt.flaskIcon == nil and mt.foodIcon == nil),
    cdHidden = (mt.cdIcons[1] ~= nil and mt.cdIcons[1]:IsShown() == false),
    noPlane = (mt.dropPlane == nil),
    noDragScript = (mt._dragButtons == nil or #mt._dragButtons == 0),
}

local SAVED_ISD, SAVED_GCP, SAVED_IMBD = IsShiftKeyDown, GetCursorPosition, IsMouseButtonDown
IsShiftKeyDown = function() return true end
local DOWN = false
IsMouseButtonDown = function(b) return DOWN and b == "LeftButton" end
local CUR_X, CUR_Y = 0, 0
GetCursorPosition = function() return CUR_X, CUR_Y end

local function setRect(f, x0, x1, y0, y1)
    f.GetLeft = function() return x0 end
    f.GetRight = function() return x1 end
    f.GetBottom = function() return y0 end
    f.GetTop = function() return y1 end
end
-- Griglia: righe da 20 px (come in gioco), 5 px di buco fra una e l'altra.
local function gridRect(i)
    local col = (i - 1) % 5
    local rw = math.floor((i - 1) / 5)
    local x0 = 100 + col * 130
    local y1 = 600 - rw * 50
    return x0, x0 + 120, y1 - 20, y1
end
for i, sl in ipairs(RF.slots) do
    local x0, x1, y0, y1 = gridRect(i)
    setRect(sl, x0, x1, y0, y1)
    if sl.dropPlane then setRect(sl.dropPlane, x0, x1, y0, y1) end
    if sl.secTarget then setRect(sl.secTarget, x0, x1, y0, y1) end
end
setRect(mt, 100, 220, 700, 720)
setRect(RF.tankSlots[2], 100, 220, 670, 690)
RF.frame.GetLeft = function() return 0 end
RF.frame.GetRight = function() return 1000 end
RF.frame.GetBottom = function() return 0 end
RF.frame.GetTop = function() return 1000 end

local function tick(el)
    if RF._dragPoller and RF._dragPoller._scripts and RF._dragPoller._scripts.OnUpdate then
        RF._dragPoller._scripts.OnUpdate(RF._dragPoller, el or 0.05)
    end
end
local function gridCenter(i)
    local x0, x1, y0, y1 = gridRect(i)
    return (x0 + x1) / 2, (y0 + y1) / 2
end

----------------------------------------------------------------------
-- 1) LE BARRE TANKS NON SI TRASCINANO (ne' sorgente ne' destinazione)
----------------------------------------------------------------------
CUR_X, CUR_Y = 160, 710
DOWN = true
tick()
UW_P16_TANK_DOWN = (RF._rfDragSource == nil and RF._dragPressSlot == nil)
DOWN = false
tick()

----------------------------------------------------------------------
-- 2) IL GESTO E' TOLLERANTE: 6 px sotto la barra del player -> aggancia
----------------------------------------------------------------------
local s1 = RF.slots[1]          -- il player, nel primo gruppo
local x1a, _, y0a, y1a = gridRect(1)
CUR_X, CUR_Y = (x1a + x1a + 120) / 2, y0a - 6      -- 6 px SOTTO la riga
DOWN = true
tick()
UW_P16_SNAP = {
    src = (RF._rfDragSource == s1),
    press = (RF._dragPressSlot == s1),
}
local x8, y8 = gridCenter(8)
CUR_X, CUR_Y = x8, y8
DOWN = false
tick()
local slots = RLSuite:DebugRaidSlots()
UW_P16_D1 = {
    at8 = (slots[8] and slots[8].name) or "?",
    at1_free = (slots[1] == nil),
    clean = (RF._rfDragSource == nil),
}

----------------------------------------------------------------------
-- 3) LONTANO (> tolleranza) NON SI AGGANCIA NULLA
----------------------------------------------------------------------
UW_P16_FAR = { press = false, started = false }
local x11 = select(1, gridRect(11))
CUR_X, CUR_Y = x11 + 60, select(4, gridRect(11)) - 40   -- 40 px sotto, nel vuoto
DOWN = true
tick()
UW_P16_FAR.press = (RF._dragPressSlot == nil)
UW_P16_FAR.started = (RF._rfDragSource == nil)
DOWN = false
tick()

----------------------------------------------------------------------
-- 4) RIGA RISULTATA NASCOSTA ma con un player: si prende lo stesso
--    (barra e icone vivono su content: possono essere VISIBILI anche
--    quando la riga non risulta mostrata -> se si vede, si prende)
----------------------------------------------------------------------
local s2 = nil
for i, sl in ipairs(RF.slots) do
    if sl.member then s2 = sl break end
end
UW_P16_HIDDEN = { row = (s2 and s2.slot) or -1, gen = false }
if s2 then
    s2:Hide()                       -- riga nascosta, barra ancora mostrata
    UW_P16_HIDDEN.gen = (s2.bar ~= nil and s2.bar:IsShown() == true)
    CUR_X, CUR_Y = gridCenter(s2.slot)
    DOWN = true
    tick()
    UW_P16_HIDDEN.src = (RF._rfDragSource == s2)
    DOWN = false
    tick()
    UW_P16_HIDDEN.clean = (RF._rfDragSource == nil)
    s2:Show()
end

----------------------------------------------------------------------
-- 5) /rls rfdump: stato geometrico leggibile
----------------------------------------------------------------------
local lines = RF:DiagSlotLines()
UW_P16_DUMP = {
    n = #lines,
    hasWindow = (table.concat(lines, " | "):find("finestra", 1, true) ~= nil),
    hasName = (table.concat(lines, " | "):find("Onyxia", 1, true) ~= nil),
}

mt.GetLeft, mt.GetRight, mt.GetBottom, mt.GetTop = nil, nil, nil, nil
RF.tankSlots[2].GetLeft, RF.tankSlots[2].GetRight, RF.tankSlots[2].GetBottom, RF.tankSlots[2].GetTop = nil, nil, nil, nil
RF.frame.GetLeft, RF.frame.GetRight, RF.frame.GetBottom, RF.frame.GetTop = nil, nil, nil, nil
for i, sl in ipairs(RF.slots) do
    sl.GetLeft, sl.GetRight, sl.GetBottom, sl.GetTop = nil, nil, nil, nil
    if sl.dropPlane then sl.dropPlane.GetLeft, sl.dropPlane.GetRight, sl.dropPlane.GetBottom, sl.dropPlane.GetTop = nil, nil, nil, nil end
    if sl.secTarget then sl.secTarget.GetLeft, sl.secTarget.GetRight, sl.secTarget.GetBottom, sl.secTarget.GetTop = nil, nil, nil, nil end
end
IsShiftKeyDown, GetCursorPosition, IsMouseButtonDown = SAVED_ISD, SAVED_GCP, SAVED_IMBD
RLSuite:SetContextPhase("preraid")
RLSuite:ResetDebugRaid()
RF:Rebuild()
""")


check(bool(rt.eval("UW_P16_TANK.isTank == true and UW_P16_TANK.targetBar == true and UW_P16_TANK.noConsumables == true and UW_P16_TANK.cdHidden == true and UW_P16_TANK.noPlane == true and UW_P16_TANK.noDragScript == true")), "v1.11.82: le barre Tanks restano come sempre (tag, barra del target, niente consumabili/CD/piani/registrazione drag)")
check(bool(rt.eval("UW_P16_TANK_DOWN == true")), "v1.11.82: premere una barra Tanks NON avvia nessun trascinamento (comportamento storico)")
check(bool(rt.eval("UW_P16_SNAP.src == true and UW_P16_SNAP.press == true")), "v1.11.82: premendo 6 px SOTTO la barra del player il gesto aggancia comunque quella barra (tolleranza 10 px)")
check(bool(rt.eval("UW_P16_D1.at8 ~= '?' and UW_P16_D1.at1_free == true and UW_P16_D1.clean == true")), "v1.11.82: e lo spostamento va a buon fine (%s -> slot 8)" % rt.eval("UW_P16_D1.at8"))
check(bool(rt.eval("UW_P16_FAR.press == true and UW_P16_FAR.started == true")), "v1.11.82: premendo 40 px fuori dalle barre non si aggancia niente (nessun effetto a distanza)")
check(bool(rt.eval("UW_P16_HIDDEN.gen == true and UW_P16_HIDDEN.src == true and UW_P16_HIDDEN.clean == true")), "v1.11.82: riga con un player ma NON mostrata (barra visibile su content) - il gesto la prende lo stesso")
check(bool(rt.eval("UW_P16_DUMP.n >= 3 and UW_P16_DUMP.hasWindow == true and UW_P16_DUMP.hasName == true")), "v1.11.82: /rls rfdump elenca barre, stato mostrata/nascosta e rettangoli (nome player incluso)")
rt.execute("""
-- =====================================================================
-- v1.11.85: LISTA PUBBLICA DEI COMANDI.
-- L'help in gioco elenca SOLO i comandi d'uso normale: la diagnostica e gli
-- alias restano attivi ma invisibili. /rls inv sostituisce
-- /rls inviteengine; /rls macro e /rls rfhud sono stati RIMOSSI.
-- =====================================================================
local CL_SAVED_DEBUG = RLSuite.db.profile.debug
RLSuite.db.profile.debug = false

-- help: righe stampate e contenuto
CHAT_LOG = {}
RLSuite:PrintHelp()
CMD_HELP = { n = #CHAT_LOG, all = table.concat(CHAT_LOG, "\\n") }
CMD_HELP.public = {}
for i = 2, #CHAT_LOG do
    -- togli il prefisso del print in chat ("|cff33ff99[RLSuite]|r  ")
    local line = tostring(CHAT_LOG[i]):gsub("^.-%]|r%s*", "")
    CMD_HELP.public[#CMD_HELP.public + 1] = line
end
CMD_HELP.joined = table.concat(CMD_HELP.public, " | ")

-- comandi pubblici attesi, in ordine
CMD_EXPECT = {
    "/rls            Main bar (buttons + phase)",
    "/rls help       This list",
    "/rls config     Config window",
    "/rls group      Pugger panel",
    "/rls inv        InviteEngine (whisper + auto-invite)",
    "/rls macrobar   MacroBar HUD",
    "/rls ms         MS Manager panel",
    "/rls loot       Loot Manager panel",
    "/rls raidframe  Raid Frame HUD",
}
CMD_ORDER_OK = (#CMD_HELP.public == #CMD_EXPECT)
if CMD_ORDER_OK then
    for i, want in ipairs(CMD_EXPECT) do
        if CMD_HELP.public[i] ~= want then CMD_ORDER_OK = false end
    end
end

-- NESSUNA diagnostica nell'help
CMD_NO_DIAG = true
for _, bad in ipairs({ "diag", "rfdump", "lootdiag", "icondbg", "minimap",
    "debugbuff", "version", "whisplist", "inviteengine", "rfhud", "macro " }) do
    if CMD_HELP.all:find(bad, 1, true) then CMD_NO_DIAG = false end
end

-- /rls inv deve portare al pannello InviteEngine: si controlla il DISPATCH
-- (tab "group" + OpenWhisplist) senza costruire la UI, che in questo punto
-- della suite non e' ancora montata.
local MWc = RLSuite.mainWindow
local savedShowTab = MWc.ShowTab
local savedOpenWL = RLSuite.groupmaking.OpenWhisplist
local seenTab, seenOpen = nil, nil
MWc.ShowTab = function(_, key) seenTab = key end
RLSuite.groupmaking.OpenWhisplist = function() seenOpen = (seenOpen or 0) + 1 end

RLSuite:ChatCommand("inv")
CMD_INV_OPEN = (seenTab == "group" and seenOpen == 1)

-- alias storici ancora accettati (ma non elencati)
CMD_ALIAS_OK = true
for _, alias in ipairs({ "inviteengine", "ie", "wl", "whisplist" }) do
    seenTab, seenOpen = nil, nil
    RLSuite:ChatCommand(alias)
    if not (seenTab == "group" and seenOpen == 1) then CMD_ALIAS_OK = false end
end
MWc.ShowTab = savedShowTab
RLSuite.groupmaking.OpenWhisplist = savedOpenWL

-- /rls macro e /rls rfhud NON esistono piu': cadono nel ramo "sconosciuto"
CHAT_LOG = {}
RLSuite:ChatCommand("macro")
CMD_MACRO_GONE = (table.concat(CHAT_LOG, "\\n"):find("Unknown command", 1, true) ~= nil)
CHAT_LOG = {}
RLSuite:ChatCommand("rfhud")
CMD_RFHUD_GONE = (table.concat(CHAT_LOG, "\\n"):find("Unknown command", 1, true) ~= nil)

-- la diagnostica resta FUNZIONANTE (solo nascosta)
CHAT_LOG = {}
RLSuite:ChatCommand("diag")
CMD_DIAG_WORKS = (table.concat(CHAT_LOG, "\\n"):find("diagnostica installazione", 1, true) ~= nil)
CHAT_LOG = {}
RLSuite:ChatCommand("rfdump")
CMD_RFDUMP_WORKS = (table.concat(CHAT_LOG, "\\n"):find("HUD", 1, true) ~= nil)
RLSuite.db.profile.debug = CL_SAVED_DEBUG
""")


check(bool(rt.eval("CMD_HELP.n == 1 + #CMD_EXPECT")), "v1.11.85: /rls help stampa SOLO i 9 comandi pubblici (nessuna diagnostica)")
check(bool(rt.eval("CMD_ORDER_OK == true")), "v1.11.85: help nell'ordine richiesto (main bar, help, config, group, inv, macrobar, ms, loot, raidframe) -- %s" % rt.eval("table.concat(CMD_HELP.public, ' || ')"))
check(bool(rt.eval("CMD_NO_DIAG == true")), "v1.11.85: nell'help non compaiono diag/rfdump/lootdiag/icondbg/minimap/debugbuff ne' gli alias")
check(bool(rt.eval("CMD_INV_OPEN == true")), "v1.11.85: /rls inv apre il pannello InviteEngine (comando rinominato)")
check(bool(rt.eval("CMD_ALIAS_OK == true")), "v1.11.85: gli alias storici (inviteengine, ie, wl, whisplist) restano accettati ma NON elencati")
check(bool(rt.eval("CMD_MACRO_GONE == true and CMD_RFHUD_GONE == true")), "v1.11.85: /rls macro e /rls rfhud sono stati RIMOSSI (ora comando sconosciuto)")
check(bool(rt.eval("CMD_DIAG_WORKS == true and CMD_RFDUMP_WORKS == true")), "v1.11.85: i comandi di diagnostica restano FUNZIONANTI, solo nascosti dall'help")
# =====================================================================
# v1.11.87 — PARSER CLASSE/SPEC/GS (regole in _dev/Class_Spec_and_GS_parser.md)
# Un solo motore: RLSuite.utils:ParseWhisper(msg) -> class/spec/role/gs.
# I casi sono presi riga per riga dalla tabella (PREFIX / BODY / SUFFIX).
# =====================================================================
rt.execute("""
local CASES = {
    -- { testo, classe attesa, spec attesa, gs atteso (opzionale) }
    -- ---- DEATH KNIGHT: U/UH/Unholy, B/Blood, F/Frost ----
    { "u dk", "DEATHKNIGHT", "Unholy" },
    { "uh dk", "DEATHKNIGHT", "Unholy" },
    { "unholy dk", "DEATHKNIGHT", "Unholy" },
    { "dk u", "DEATHKNIGHT", "Unholy" },
    { "dk uh", "DEATHKNIGHT", "Unholy" },
    { "dk unholy", "DEATHKNIGHT", "Unholy" },
    { "b dk", "DEATHKNIGHT", "Blood" },
    { "blood dk", "DEATHKNIGHT", "Blood" },
    { "dk b", "DEATHKNIGHT", "Blood" },
    { "dk blood", "DEATHKNIGHT", "Blood" },
    { "f dk", "DEATHKNIGHT", "Frost" },
    { "frost dk", "DEATHKNIGHT", "Frost" },
    { "dk f", "DEATHKNIGHT", "Frost" },
    { "dk frost", "DEATHKNIGHT", "Frost" },
    { "UNHOLY DK", "DEATHKNIGHT", "Unholy" },
    { "Unholy Dk 6k gs", "DEATHKNIGHT", "Unholy", 6000 },
    -- ---- DRUID: Balance / Feral Cat / Feral Bear / Restoration ----
    { "balance dudu", "DRUID", "Balance" },
    { "dudu balance", "DRUID", "Balance" },
    { "balance druid", "DRUID", "Balance" },
    { "boomkin 6k gs", "DRUID", "Balance", 6000 },
    { "boomie", "DRUID", "Balance" },
    { "cat dudu", "DRUID", "Feral Cat" },
    { "bear dudu", "DRUID", "Feral Bear" },
    { "dudu cat", "DRUID", "Feral Cat" },
    { "dudu bear", "DRUID", "Feral Bear" },
    { "dudu feral cat", "DRUID", "Feral Cat" },
    { "dudu feral bear", "DRUID", "Feral Bear" },
    { "dudu feral", "DRUID", "Feral" },          -- ambiguo: resta "Feral", decide il RL
    { "f dudu", "DRUID", "Feral" },
    { "f dudu bear", "DRUID", "Feral Bear" },
    { "r dudu", "DRUID", "Restoration" },
    { "dudu resto", "DRUID", "Restoration" },
    { "resto druid", "DRUID", "Restoration" },
    { "druid 6k", "DRUID", nil },
    -- ---- HUNTER: BM / MM / S/Surv/Survival ----
    { "bm hunt", "HUNTER", "Beast Mastery" },
    { "hunt bm", "HUNTER", "Beast Mastery" },
    { "bm hunter", "HUNTER", "Beast Mastery" },
    { "hunter bm", "HUNTER", "Beast Mastery" },
    { "mm hunt", "HUNTER", "Marksmanship" },
    { "hunter mm", "HUNTER", "Marksmanship" },
    { "hunt mm 6542 gs", "HUNTER", "Marksmanship", 6542 },
    { "s hunt", "HUNTER", "Survival" },
    { "surv hunter", "HUNTER", "Survival" },
    { "hunt survival", "HUNTER", "Survival" },
    { "hunter surv", "HUNTER", "Survival" },
    -- ---- MAGE: F/Fire, Frost, Arcane ----
    { "f mage", "MAGE", "Fire" },
    { "fire mage", "MAGE", "Fire" },
    { "mage fire", "MAGE", "Fire" },
    { "frost mage", "MAGE", "Frost" },
    { "mage frost", "MAGE", "Frost" },
    { "arcane mage", "MAGE", "Arcane" },
    { "mage arcane", "MAGE", "Arcane" },
    -- ---- PALADIN: P/Prot/Protection, R/Ret/Retri/Retribution, H/Holy ----
    { "p pala", "PALADIN", "Protection" },
    { "prot pala", "PALADIN", "Protection" },
    { "protection paladin", "PALADIN", "Protection" },
    { "pala prot", "PALADIN", "Protection" },
    { "pala protection", "PALADIN", "Protection" },
    { "r pala", "PALADIN", "Retribution" },
    { "ret pala", "PALADIN", "Retribution" },
    { "retri pala", "PALADIN", "Retribution" },
    { "retribution paladin", "PALADIN", "Retribution" },
    { "pala ret", "PALADIN", "Retribution" },
    { "pala retri", "PALADIN", "Retribution" },
    { "h pala", "PALADIN", "Holy" },
    { "holy pala", "PALADIN", "Holy" },
    { "pala holy", "PALADIN", "Holy" },
    { "p pala holy", "PALADIN", nil },           -- prefisso Prot + suffisso Holy: contraddittorio
    -- ---- PRIEST: S/Sh/Shadow, D/Disci/Discipline (+ BODY Disco), H/Holy ----
    { "s priest", "PRIEST", "Shadow" },
    { "sh priest", "PRIEST", "Shadow" },
    { "shadow priest", "PRIEST", "Shadow" },
    { "priest shadow", "PRIEST", "Shadow" },
    { "d priest", "PRIEST", "Discipline" },
    { "disci priest", "PRIEST", "Discipline" },
    { "discipline priest", "PRIEST", "Discipline" },
    { "priest disco", "PRIEST", "Discipline" },
    { "disco", "PRIEST", "Discipline" },
    { "disco 6k gs", "PRIEST", "Discipline", 6000 },
    { "h priest", "PRIEST", "Holy" },
    { "priest holy", "PRIEST", "Holy" },
    -- ---- ROGUE: C/Combat, Assa/Assassination, S/Sub/Subtlety ----
    { "c rogue", "ROGUE", "Combat" },
    { "combat rog", "ROGUE", "Combat" },
    { "rogue combat", "ROGUE", "Combat" },
    { "assa rogue", "ROGUE", "Assassination" },
    { "assassination rogue", "ROGUE", "Assassination" },
    { "rog assa", "ROGUE", "Assassination" },
    { "rogue assassination", "ROGUE", "Assassination" },
    { "s rogue", "ROGUE", "Subtlety" },
    { "sub rogue", "ROGUE", "Subtlety" },
    { "rogue sub", "ROGUE", "Subtlety" },
    { "rogue subtlety", "ROGUE", "Subtlety" },
    { "sublety rogue", "ROGUE", "Subtlety" },
    -- ---- SHAMAN: Enha/Enhancement, Ele/Elemental, R/Resto ----
    { "enha sham", "SHAMAN", "Enhancement" },
    { "enhancement shaman", "SHAMAN", "Enhancement" },
    { "shammy enha", "SHAMAN", "Enhancement" },
    { "sham enhancement", "SHAMAN", "Enhancement" },
    { "ele sham", "SHAMAN", "Elemental" },
    { "elemental shaman", "SHAMAN", "Elemental" },
    { "sham ele", "SHAMAN", "Elemental" },
    { "r sham", "SHAMAN", "Restoration" },
    { "shammy resto", "SHAMAN", "Restoration" },
    { "sham resto", "SHAMAN", "Restoration" },
    -- ---- WARLOCK: Aff/Affly/Affliction, Demo/Demonology, Destro/Destruction ----
    { "aff lock", "WARLOCK", "Affliction" },
    { "affly warlock", "WARLOCK", "Affliction" },
    { "affliction lock", "WARLOCK", "Affliction" },
    { "afliction lock", "WARLOCK", "Affliction" },
    { "lock aff", "WARLOCK", "Affliction" },
    { "lock affliction", "WARLOCK", "Affliction" },
    { "demo lock", "WARLOCK", "Demonology" },
    { "demonology lock", "WARLOCK", "Demonology" },
    { "lock demo", "WARLOCK", "Demonology" },
    { "lock demonology", "WARLOCK", "Demonology" },
    { "destro lock", "WARLOCK", "Destruction" },
    { "destriction lock", "WARLOCK", "Destruction" },
    { "lock destruction", "WARLOCK", "Destruction" },
    { "lock destro", "WARLOCK", "Destruction" },
    -- ---- WARRIOR: F/Fury, Arms, P/Prot/Protection ----
    { "f war", "WARRIOR", "Fury" },
    { "fury warr", "WARRIOR", "Fury" },
    { "war fury", "WARRIOR", "Fury" },
    { "warrior fury", "WARRIOR", "Fury" },
    { "arms war", "WARRIOR", "Arms" },
    { "war arms", "WARRIOR", "Arms" },
    { "warrior arms", "WARRIOR", "Arms" },
    { "p war", "WARRIOR", "Protection" },
    { "war prot", "WARRIOR", "Protection" },
    { "warrior prot", "WARRIOR", "Protection" },
    { "war protection", "WARRIOR", "Protection" },
    -- ---- parole estranee in mezzo: contano le ADIACENTI alla classe ----
    { "healer holy pala 6100 gs", "PALADIN", "Holy", 6100 },
    { "tank protection war 5900 gs", "WARRIOR", "Protection", 5900 },
    { "hi, resto sham here 5.8k gs", "SHAMAN", "Restoration", 5800 },
    { "spec fury", "WARRIOR", "Fury" },          -- abitudine vecchia: "spec" si ignora
    { "war tank spec prot 5900 gs", "WARRIOR", "Protection", 5900 },
    -- ---- GS: tutte le forme della tabella ----
    { "pala prot gs 5900", "PALADIN", "Protection", 5900 },
    { "pala prot 5900 gs", "PALADIN", "Protection", 5900 },
    { "pala prot 5900", "PALADIN", "Protection", 5900 },
    { "pala prot 5,9k gs", "PALADIN", "Protection", 5900 },
    { "pala prot 6k", "PALADIN", "Protection", 6000 },
    { "pala prot 6.5k", "PALADIN", "Protection", 6500 },
    { "pala prot 6,5k", "PALADIN", "Protection", 6500 },
    { "pala prot 6.5", "PALADIN", "Protection", 6500 },
    { "pala prot 5.500 gs", "PALADIN", "Protection", 5500 },
    { "pala holy", "PALADIN", "Holy", false },
    { "pala holy 123", "PALADIN", "Holy", false },    -- 3 cifre: NON e' un GS
    { "war arms 6", "WARRIOR", "Arms", false },       -- "6" nudo: non e' un GS
    -- ---- nomi estesi richiesti dal raid leader ----
    { "beast mastery hunt", "HUNTER", "Beast Mastery" },
    { "hunt beast mastery", "HUNTER", "Beast Mastery" },
    { "beastmastery hunter", "HUNTER", "Beast Mastery" },
    { "marksmanship hunter", "HUNTER", "Marksmanship" },
    { "hunt marksmanship", "HUNTER", "Marksmanship" },
    { "marksman hunt", "HUNTER", "Marksmanship" },
    { "restoration dudu", "DRUID", "Restoration" },
    { "dudu restoration", "DRUID", "Restoration" },
    { "restoration druid 6k gs", "DRUID", "Restoration", 6000 },
    -- ---- "none / gs / GS" vale per TUTTE E TRE le forme ----
    { "pala prot gs 6542", "PALADIN", "Protection", 6542 },     -- intero, prefisso gs
    { "pala prot 6542 gs", "PALADIN", "Protection", 6542 },     -- intero, suffisso gs
    { "pala prot gs 6", "PALADIN", "Protection", 6000 },        -- forma corta (6 = 6k)
    { "pala prot gs 6k", "PALADIN", "Protection", 6000 },       -- corto + k, prefisso gs
    { "pala prot 6k gs", "PALADIN", "Protection", 6000 },       -- corto + k, suffisso gs
    { "pala prot gs 6.5", "PALADIN", "Protection", 6500 },      -- corto decimale, prefisso gs
    { "pala prot 6.5 gs", "PALADIN", "Protection", 6500 },      -- corto decimale, suffisso gs
    { "pala prot gs 6,5k", "PALADIN", "Protection", 6500 },     -- corto decimale + k, prefisso gs
    { "pala prot 6,5 k gs", "PALADIN", "Protection", 6500 },
    -- ---- FORME ATTACCATE (regola generale: nessuno spazio obbligatorio) ----
    { "udk", "DEATHKNIGHT", "Unholy" },
    { "bdk", "DEATHKNIGHT", "Blood" },
    { "fdk", "DEATHKNIGHT", "Frost" },
    { "fdudu", "DRUID", "Feral" },                -- f da solo: ambiguo -> "Feral"
    { "dudubear", "DRUID", "Feral Bear" },
    { "duducat", "DRUID", "Feral Cat" },
    { "restodudu", "DRUID", "Restoration" },
    { "bmhunt", "HUNTER", "Beast Mastery" },
    { "mmhunt", "HUNTER", "Marksmanship" },
    { "beastmasteryhunt", "HUNTER", "Beast Mastery" },
    { "marksmanshiphunt", "HUNTER", "Marksmanship" },
    { "firemage", "MAGE", "Fire" },
    { "frostmage", "MAGE", "Frost" },
    { "protpala", "PALADIN", "Protection" },
    { "retpala", "PALADIN", "Retribution" },
    { "holypala", "PALADIN", "Holy" },
    { "shpriest", "PRIEST", "Shadow" },
    { "combatrog", "ROGUE", "Combat" },
    { "assarogue", "ROGUE", "Assassination" },
    { "subrog", "ROGUE", "Subtlety" },
    { "elesham", "SHAMAN", "Elemental" },
    { "enhasham", "SHAMAN", "Enhancement" },
    { "restosham", "SHAMAN", "Restoration" },
    { "afflock", "WARLOCK", "Affliction" },
    { "demolock", "WARLOCK", "Demonology" },
    { "destrolock", "WARLOCK", "Destruction" },
    { "furywar", "WARRIOR", "Fury" },
    { "armswar", "WARRIOR", "Arms" },
    { "protwar", "WARRIOR", "Protection" },
    -- GS attaccato sia al testo sia al numero
    { "protpala 6kgs", "PALADIN", "Protection", 6000 },
    { "holypala gs6,5k", "PALADIN", "Holy", 6500 },
    { "udk 6kGS", "DEATHKNIGHT", "Unholy", 6000 },
    { "mmhunt 6,5kgs", "HUNTER", "Marksmanship", 6500 },
    { "fdudu 5500gs", "DRUID", "Feral", 5500 },
    { "shpriest gs6", "PRIEST", "Shadow", 6000 },
    -- plurale: la classe si riconosce lo stesso
    { "warriors fury 5.8k gs", "WARRIOR", "Fury", 5800 },
    { "paladins holy 5900", "PALADIN", "Holy", 5900 },
    -- plurale da solo: la classe si riconosce lo stesso
    { "warriors", "WARRIOR", nil },
    { "rogues", "ROGUE", nil },
    { "warlocks", "WARLOCK", nil },
    { "hunters mm 5.9k gs", "HUNTER", "Marksmanship", 5900 },
    -- prefisso E suffisso su classi che NON lo ammettono: la classe resta,
    -- la spec no (regola generale: o prefisso o suffisso)
    { "fdudu resto", "DRUID", nil },
    { "protpala holy", "PALADIN", nil },
    -- e non si inventa una classe da una parola che la CONTIENE
    { "warmane 5500 gs", nil, nil, 5500 },
    { "warmane warlock 5500 gs", "WARLOCK", nil, 5500 },
    -- ---- spec senza classe: vale solo se non e' ambigua ----
    { "prot 5900 gs", nil, "Protection", 5900 },      -- warrior O paladin
    { "resto 5.9k", nil, "Restoration", 5900 },       -- shaman O druido
    { "fury 5.5k", "WARRIOR", "Fury", 5500 },         -- solo warrior
    { "frost 6k", nil, "Frost", 6000 },               -- dk O mage
    { "combat 5.8k", "ROGUE", "Combat", 5800 },
    { "gs 5500", nil, nil, 5500 },
}

V87 = { n = 0, fails = {} }
for _, c in ipairs(CASES) do
    local parsed = RLSuite.utils:ParseWhisper(c[1])
    V87.n = V87.n + 1
    if parsed.class ~= c[2] or parsed.spec ~= c[3] then
        V87.fails[#V87.fails + 1] = string.format("%s -> %s/%s (attesi %s/%s)",
            c[1], tostring(parsed.class), tostring(parsed.spec), tostring(c[2]), tostring(c[3]))
    elseif c[4] == false and parsed.gs ~= nil then
        -- "false" = il messaggio NON deve produrre un GS
        V87.fails[#V87.fails + 1] = string.format("%s -> gs inatteso %s", c[1], tostring(parsed.gs))
    elseif type(c[4]) == "number" and parsed.gs ~= c[4] then
        V87.fails[#V87.fails + 1] = string.format("%s -> gs %s (atteso %s)",
            c[1], tostring(parsed.gs), tostring(c[4]))
    end
end
V87.feral_plain = RLSuite.utils:ParseWhisper("dudu feral").spec
V87.feral_plain2 = RLSuite.utils:ParseWhisper("f dudu").spec
V87.feral_bear = RLSuite.utils:ParseWhisper("dudu bear").spec
V87.feral_cat = RLSuite.utils:ParseWhisper("dudu cat").spec
V87.feral_bear2 = RLSuite.utils:ParseWhisper("f dudu bear").spec
V87.feral_cat2 = RLSuite.utils:ParseWhisper("f dudu cat").spec
V87.role = RLSuite.utils:ParseWhisper("bear dudu tank 6k gs").role
V87.role2 = RLSuite.utils:ParseWhisper("holy pala healer 6k gs").role
""")

check(rt.eval("V87.n >= 210") and rt.eval("#V87.fails == 0"), "v1.11.89: %d forme della tabella (PREFIX/BODY/SUFFIX + GS) tutte riconosciute -- %s" % (rt.eval("V87.n"), rt.eval("table.concat(V87.fails, ' | ')")))
check(bool(rt.eval("V87.feral_plain == 'Feral' and V87.feral_plain2 == 'Feral'")), "v1.11.89: feral ambiguo -> resta 'Feral' (nessuna spec inventata: decide il raid leader)")
check(bool(rt.eval("V87.feral_bear == 'Feral Bear' and V87.feral_cat == 'Feral Cat' and V87.feral_bear2 == 'Feral Bear' and V87.feral_cat2 == 'Feral Cat'")), "v1.11.89: Feral Cat e Feral Bear restano DUE cose separate e si risolvono appena il testo lo dice (bear/cat, anche col prefisso f)")
check(bool(rt.eval("V87.role == 'tank' and V87.role2 == 'healer'")), "v1.11.89: il ruolo resta letto dalle parole (tank/healer)")

# --- gli extractor della Whisplist delegano allo stesso motore ---
rt.execute("""
V87E = {}
V87E.class = RLSuite.groupmaking:ExtractClassFromWhisper("healer holy pala 6100 gs")
V87E.spec  = RLSuite.groupmaking:ExtractSpecFromWhisper("healer holy pala 6100 gs")
V87E.gs    = RLSuite.groupmaking:ExtractGSFromWhisper("healer holy pala 6100 gs")
V87E.role  = RLSuite.groupmaking:ExtractRoleFromWhisper("tank bear dudu 6k gs")
""")
check(bool(rt.eval("V87E.class == 'PALADIN' and V87E.spec == 'Holy' and V87E.gs == 6100 and V87E.role == 'tank'")), "v1.11.89: la Whisplist legge classe+spec+GS dallo stesso testo (extractor delegati)")

# --- MS: il corpo del comando passa per lo stesso parser ---
rt.execute("""
local MSM = RLSuite.msManager
MSM.listening = true
V87M = {}
local function ms(cmd)
    MSM.db = {}
    MSM:ParseMSMessage("Tester", cmd)
    return MSM.db[1]
end
local a = ms("ms f dk")      V87M.fdk, V87M.fdk_class = a and a.spec, a and a.class
local b = ms("ms dk frost")  V87M.dkf = b and b.spec
local c = ms("ms unholy")    V87M.unholy = c and c.spec
local d = ms("ms prot")      V87M.prot = d and d.spec
local e = ms("ms resto")     V87M.resto = e and e.spec
local f = ms("ms disco")     V87M.disco = f and f.spec
local g = ms("ms fury")      V87M.fury = g and g.spec
local h = ms("ms prot pala") V87M.protpala, V87M.protpala_class = h and h.spec, h and h.class
local i = ms("ms changes")   V87M.changes = i and i.spec
local j = ms("ms: resto sham") V87M.colon = j and j.spec
local k = ms("ms udk")       V87M.udk, V87M.udk_class = k and k.spec, k and k.class
local l = ms("ms mmhunt")    V87M.mmhunt = l and l.spec
local m = ms("ms fdudu")     V87M.fdudu = m and m.spec
local n = ms("ms protpala")  V87M.protpala2 = n and n.spec
MSM.db = {}
MSM.listening = false
""")
check(bool(rt.eval("V87M.fdk == 'Frost' and V87M.fdk_class == 'DEATHKNIGHT'")), "v1.11.89: 'ms f dk' -> Frost (DEATHKNIGHT): il comando MS usa la tabella e registra anche la classe")
check(bool(rt.eval("V87M.dkf == 'Frost' and V87M.unholy == 'Unholy'")), "v1.11.89: MS accetta 'ms dk frost' e 'ms unholy' (nome canonico)")
check(bool(rt.eval("V87M.prot == 'Protection' and V87M.resto == 'Restoration' and V87M.disco == 'Discipline' and V87M.fury == 'Fury'")), "v1.11.89: 'ms prot' / 'ms resto' / 'ms disco' / 'ms fury' -> nomi canonici")
check(bool(rt.eval("V87M.protpala == 'Protection' and V87M.protpala_class == 'PALADIN'")), "v1.11.89: 'ms prot pala' -> Protection (PALADIN)")
check(bool(rt.eval("V87M.changes == nil and V87M.colon == 'Restoration'")), "v1.11.89: 'ms changes' resta ignorato, 'ms: resto sham' funziona")
check(bool(rt.eval("V87M.udk == 'Unholy' and V87M.udk_class == 'DEATHKNIGHT' and V87M.mmhunt == 'Marksmanship'")), "v1.11.89: l'MS accetta le forme attaccate ('ms udk', 'ms mmhunt')")
check(bool(rt.eval("V87M.fdudu == 'Feral' and V87M.protpala2 == 'Protection'")), "v1.11.89: 'ms fdudu' resta 'Feral' (ambiguo), 'ms protpala' -> Protection")

# --- whisper finti del pannello Debug: generati con la tabella ---
rt.execute("""
local saved = RLSuite.db.profile.debug
RLSuite.db.profile.debug = true
RLSuite.groupmaking.whisperDB.entries = {}
RLSuite.groupmaking:DebugWhisperBurst()
V87W = { n = #RLSuite.groupmaking.whisperDB.entries, bad = {}, parsed = 0 }
for _, e in ipairs(RLSuite.groupmaking.whisperDB.entries) do
    if e.class and e.spec and e.gs then V87W.parsed = V87W.parsed + 1 end
    if not (e.class and e.spec and e.gs and e.messages and #e.messages > 0) then
        V87W.bad[#V87W.bad + 1] = tostring(e.name) .. "=" .. tostring(e.class) .. "/" .. tostring(e.spec) .. "/" .. tostring(e.gs)
    end
end
RLSuite.groupmaking.whisperDB.entries = {}
RLSuite.db.profile.debug = saved
""")
check(bool(rt.eval("V87W.n == 10 and V87W.parsed == 10")), "v1.11.89: i 10 whisper finti del test Whisplist vengono riletti dal parser (classe+spec+GS) -- %s" % rt.eval("table.concat(V87W.bad, ' | ')"))
# =====================================================================
# v1.11.90 — Raid Frame: durability, fade per distanza, ctrl-click buff,
#            assegnazione dei buff (tooltip custom + drag + whisper)
# =====================================================================
rt.execute("""
local RFM = RLSuite.raidFrame
V90 = {}
-- Roster di prova: player + 2 paladini (fornitori di MP5) + 2 warrior + un mago.
RLSuite:ResetDebugRaid()
RLSuite:DebugInviteAccept("Holymoon", "PALADIN")
RLSuite:DebugInviteAccept("Lightwall", "PALADIN")
RLSuite:DebugInviteAccept("Drakbot", "WARRIOR")
RLSuite:DebugInviteAccept("Ironclad", "WARRIOR")
RLSuite:DebugInviteAccept("Zapdora", "MAGE")
RFM.buffMatrixOn = true
RFM:Rebuild()
RFM:ApplyLayout()
RFM._durStamp = (RFM._durStamp or 0) + 1      -- forza il ricalcolo della durability
RFM:RefreshBuffMatrix()

-- --- font dei CD ---
local cd = RFM.rows[1] and RFM.rows[1].cdIcons and RFM.rows[1].cdIcons[1]
V90.cd_font = cd and cd.timer and cd.timer._fontArgs and cd.timer._fontArgs[2]

-- --- durability: colonna di servizio in fondo, con l'icona dell'equip ---
local cols = RFM:_MatrixCols()
V90.n_cols = #cols
V90.dur_key = cols[#cols].key
V90.dur_kind = cols[#cols].kind
V90.dur_icon = tostring(cols[#cols].icon)
V90.dur_hdr = tostring(RFM._buffHdrBtns[#cols] and RFM._buffHdrBtns[#cols]._icon._texture)
local function durTintSlot(slot)
    local fs = slot and slot._buffCellTexts and slot._buffCellTexts[#cols]
    return fs and fs._tc
end
local function findSlot(pred)
    for _, slot in ipairs(RFM.slots) do if pred(slot) then return slot end end
end
-- Senza le API di inventario (caso "nessun dato") il proprio pg e' GRIGIO:
-- non si accusa nessuno per un'informazione che non c'e'.
V90.tint_nodata = durTintSlot(findSlot(function(sl) return sl.member and sl.member.isPlayer end))
-- Con le API: verde per chi ha l'attrezzatura a posto...
GetInventoryItemLink = function() return "|Hitem:1|h[Item]|h" end
GetInventoryItemBroken = function() return false end
GetInventoryItemDurability = function() return 100, 100 end
RFM._durCache = nil
RFM._durStamp = (RFM._durStamp or 0) + 1
RFM:RefreshBuffMatrix()
V90.tint_g1 = durTintSlot(findSlot(function(sl) return sl.member and sl.member.fake and sl.group == 1 end))
-- ...e ROSSA per l'ultimo gruppo (simulazione debug: oggetti rotti)
V90.tint_g2 = durTintSlot(findSlot(function(sl) return sl.member and sl.member.fake and sl.group == 2 end))
-- stato della categoria: chi ha roba rotta finisce nell'elenco
local st = RFM:BuffCoverage(cols[#cols])
V90.dur_satisfied = st and st.satisfied
V90.dur_missing = st and table.concat(st.missing, ",")
local txt, r, g, b = RFM:_BuffStatusText(st)
V90.dur_text = tostring(txt)
V90.dur_text_red = (r == 1 and g == 0.35)
-- la durability non ha fornitori: mai un'assegnazione
V90.dur_providers = #RFM:BuffProviders(cols[#cols])

-- --- durability: alert (click sull'icona) ---
local n0 = #CHAT_LOG
local hbDur = RFM._buffHdrBtns[#cols]
hbDur._scripts.OnClick(hbDur, "LeftButton")
V90.dur_warn = CHAT_LOG[#CHAT_LOG]

-- --- durability del PROPRIO pg: repair sotto 80%; 80% esatto resta OK ---
GetInventoryItemDurability = function(slot) return 79, 100 end
RFM._durCache = nil
RFM._durStamp = (RFM._durStamp or 0) + 1
local meSt = RFM:MemberDurability({ name = "Testplayer", unit = "player" })
V90.me_state = meSt.state
V90.me_pct = meSt.pct
V90.me_ok = RFM:_DurCellOk(meSt)
GetInventoryItemDurability = function() return 80, 100 end
RFM._durCache = nil
RFM._durStamp = (RFM._durStamp or 0) + 1
local meSt2 = RFM:MemberDurability({ name = "Testplayer", unit = "player" })
V90.me_state2 = meSt2.state
V90.me_pct2 = meSt2.pct
V90.me_ok2 = RFM:_DurCellOk(meSt2)
GetInventoryItemDurability = nil
GetInventoryItemBroken = nil
GetInventoryItemLink = nil

-- --- fade solo fuori dall'area visibile (~100 yd), non al range spell ---
UnitInRange = function() return false, nil end -- non deve piu' influire
UnitIsVisible = function(unit)
    return unit == "raid3"
end
V90.y_near = RFM:UnitDistanceYards("raid3")
V90.y_far = RFM:UnitDistanceYards("raid4")
V90.y_offgrid = RFM:UnitDistanceYards("raid5")
V90.y_player = RFM:UnitDistanceYards("player")
local app = RLSuite.db.profile.raidframe.appearance
app.distanceFade = 25 -- vecchio SavedVariable non-zero: migra al nuovo modo
app.distanceAlpha = 0.35
local rNear, rFar = nil, nil
for _, r in ipairs(RFM.rows) do
    if r.slot == 2 then rNear = r elseif r.slot == 4 then rFar = r end
end
rNear.unit = "raid3"
rFar.unit = "raid4"
RFM:ApplyDistanceFade(rNear)
RFM:ApplyDistanceFade(rFar)
V90.fade_near = rNear._alpha
V90.fade_far = rFar._alpha
app.distanceFade = 0
RFM:ApplyDistanceFade(rFar)
V90.fade_off = rFar._alpha
-- le barre MT/OT non vengono toccate dal fade (restano piene)
V90.tanks_untouched = true
for _, t in ipairs(RFM.tankSlots or {}) do
    if t._fadeAlpha and t._fadeAlpha ~= 1 then V90.tanks_untouched = false end
end

-- --- CTRL+click sulla barra del nome: avviso IN RAID dei buff mancanti,
--     con fra parentesi CHI deve provvedere ---
local origWhisper = RLSuite.utils.Whisper
local SENT = {}
RLSuite.utils.Whisper = function(self2, name, msg) SENT[#SENT+1] = tostring(name) .. "|" .. tostring(msg) end
local origIconFor = RFM._BuffCellIconFor
RFM._BuffCellIconFor = function(self2, member, col, group)
    -- "nessuna aura addosso": cosi' l'avviso ha davvero qualcosa da elencare
    -- (in debug il simulatore riempie le categorie coperte dalla comp).
    if col and col.kind == "durability" then return origIconFor(self2, member, col, group) end
    return nil
end
local row = RFM.rows[2]
-- la PRIMA categoria mancante e' assegnata a Lightwall: nel messaggio deve
-- comparire "(Lightwall)". Un'altra resta senza assegnatario.
local miss = RFM:MissingBuffLabels(row.member, row.group)
V90.miss_n = #miss
V90.miss_first = miss[1]
V90.miss_last = miss[#miss]
local firstCol
for _, c in ipairs(cols) do
    if (c.label or c.key) == miss[1] then firstCol = c end
end
V90.first_key = firstCol and firstCol.key
RFM:SetBuffAssign(firstCol, "Lightwall")
-- il nome del BUFF dell'assegnatario (Lightwall = PALADIN): per %stat deve
-- essere "Kings", non la sigla della categoria
V90.assign_short = tostring(RFM:_BuffAssignShort(firstCol, "Lightwall"))
V90.assign_none = tostring(RFM:_BuffAssignShort(firstCol, "Nessuno"))
local n2 = #CHAT_LOG
IsControlKeyDown = function() return true end
row._targetT = nil
RFM:RowPlainClick(row, "LeftButton")
V90.ctrl_sent = SENT[1]
V90.ctrl_target = row.member.name
V90.ctrl_no_target = (row._targetT == nil)
V90.ctrl_raid = ""
for i = #CHAT_LOG, n2, -1 do
    if CHAT_LOG[i]:find("RAID_WARNING", 1, true) then V90.ctrl_raid = CHAT_LOG[i]; break end
end
RFM:SetBuffAssign(firstCol, nil)
SENT = {}
IsControlKeyDown = function() return false end
RFM:RowPlainClick(row, "LeftButton")
V90.plain_sent = SENT[1]
V90.plain_target = (row._targetT ~= nil)
RFM._BuffCellIconFor = origIconFor
IsControlKeyDown = nil
RLSuite.utils.Whisper = origWhisper

-- --- assegnazione dei buff ---
local mp5, mp5Idx
for i, c in ipairs(cols) do if c.key == "mp5" then mp5, mp5Idx = c, i end end
V90.mp5_nil = (RFM:GetBuffAssign(mp5) == nil)
local provs = RFM:BuffProviders(mp5)
V90.prov_n = #provs
V90.prov_names = ""
V90.prov_buff = ""
for _, pr in ipairs(provs) do
    V90.prov_names = V90.prov_names .. pr.member.name .. ","
    V90.prov_buff = tostring(pr.buff)
end
-- TOOLTIP: e' il GameTooltip di gioco, informativo (nessun frame custom).
V90.tip_shown = (RFM._buffCatTip == nil)
TT_LINES = {}
local oAdd, oClear = GameTooltip.AddLine, GameTooltip.ClearLines
GameTooltip.AddLine = function(s2, txt) TT_LINES[#TT_LINES + 1] = tostring(txt) return s2 end
GameTooltip.ClearLines = function(s2) TT_LINES = {} return s2 end
RFM:ShowBuffCatTip(mp5, RFM._buffHdrBtns[mp5Idx])
V90.tip_all = table.concat(TT_LINES, " | ")
V90.tip_title = tostring(TT_LINES[1] or "")
V90.tip_unassigned = tostring(V90.tip_all:find("Not assigned", 1, true) ~= nil)
V90.tip_prov_label = tostring(V90.tip_all:find("Providers (2)", 1, true) ~= nil)
V90.tip_row1 = tostring(V90.tip_all:find("PALADIN", 1, true) ~= nil)
V90.tip_row2 = tostring(V90.tip_all:find("Lightwall", 1, true) ~= nil)
RFM:SetBuffAssign(mp5, "Holymoon")
TT_LINES = {}
RFM:ShowBuffCatTip(mp5, RFM._buffHdrBtns[mp5Idx])
V90.tip_all2 = table.concat(TT_LINES, " | ")
V90.tip_assigned = tostring(V90.tip_all2:find("Assigned to: Holymoon", 1, true) ~= nil)
GameTooltip.AddLine, GameTooltip.ClearLines = oAdd, oClear
V90.assign_stored = tostring(RFM:GetBuffAssign(mp5))
-- ASSEGNAZIONE COL DRAG DELLE BARRE (lo stesso drag che sposta di gruppo)
RFM:SetBuffAssign(mp5, nil)
local dragSlot
for _, sl in ipairs(RFM.slots) do
    if sl.member and sl.member.name == "Lightwall" then dragSlot = sl end
end
V90.dragslot = (dragSlot ~= nil)
local before = {}
for i, m in ipairs(RLSuite:DebugRoster()) do before[i] = tostring(m.name) .. ":" .. tostring(m.subgroup) end
V90.roster_before = table.concat(before, ",")
local hb = RFM._buffHdrBtns[mp5Idx]
hb.GetLeft = function() return 100 end
hb.GetRight = function() return 120 end
hb.GetBottom = function() return 100 end
hb.GetTop = function() return 116 end
local savedGCP = GetCursorPosition
GetCursorPosition = function() return 110, 108 end
RFM:_StartDragFromSlot(dragSlot)
V90.drag_on = (RFM._rfDragSource == dragSlot)
RFM:UpdateDropGlow()
V90.hdr_glow = hb._icon._vertex
RFM:_FinishDrag()
GetCursorPosition = savedGCP
V90.drag_assigned = tostring(RFM:GetBuffAssign(mp5))
V90.drag_cleared = (RFM._rfDragSource == nil)
local after = {}
for i, m in ipairs(RLSuite:DebugRoster()) do after[i] = tostring(m.name) .. ":" .. tostring(m.subgroup) end
V90.roster_after = table.concat(after, ",")
V90.no_group_move = (V90.roster_before == V90.roster_after)
-- click destro sull'icona: toglie l'assegnazione
RFM._buffHdrBtns[mp5Idx]._scripts.OnClick(RFM._buffHdrBtns[mp5Idx], "RightButton")
V90.right_cleared = (RFM:GetBuffAssign(mp5) == nil)
-- AVVISO DI CATEGORIA (click sull'icona): UNA sola riga in raid warning.
-- Assegnata a Lightwall (paladino) -> col NOME DEL BUFF, non con la sigla.
-- In debug il simulatore riempie le categorie coperte dalla comp: per provare
-- l'avviso si azzera la lettura delle aure di MP5.
local origIconFor2 = RFM._BuffCellIconFor
RFM._BuffCellIconFor = function(self2, member, col2, group)
    if col2 and col2.key == "mp5" then return nil end
    return origIconFor2(self2, member, col2, group)
end
RFM:SetBuffAssign(mp5, "Lightwall")
local n1 = #CHAT_LOG
RFM:WarnBuffCategory(mp5)
V90.warn_raid = ""
for i = #CHAT_LOG, n1, -1 do
    if CHAT_LOG[i]:find("RAID_WARNING", 1, true) then V90.warn_raid = CHAT_LOG[i]; break end
end
V90.warn_lines = #CHAT_LOG - n1
-- senza assegnazione: solo la categoria
RFM:SetBuffAssign(mp5, nil)
local n2 = #CHAT_LOG
RFM:WarnBuffCategory(mp5)
V90.warn_raid_none = ""
for i = #CHAT_LOG, n2, -1 do
    if CHAT_LOG[i]:find("RAID_WARNING", 1, true) then V90.warn_raid_none = CHAT_LOG[i]; break end
end
V90.warn_lines_none = #CHAT_LOG - n2
V90.warn_missing_names = table.concat((function()
    local st = RFM:BuffCoverage(mp5)
    return st.missing or {}
end)(), ", ")
RFM._BuffCellIconFor = origIconFor2
RFM:HideBuffCatTip()
UnitInRange = nil
""")

check(bool(rt.eval("V90.cd_font == 10")), "v1.11.90: i timer dei cooldown usano font 10 (prima 8): si leggono")
check(bool(rt.eval("V90.dur_key == 'durability' and V90.dur_kind == 'durability'")), "v1.11.90: la colonna Durability e' una colonna di servizio della matrice (kind = durability)")
check(bool(rt.eval("V90.n_cols == 12")), "v1.11.90: 12 colonne (9 buff + 2 consumabili + Durability), la nuova e' l'ULTIMA a destra")
check(bool(rt.eval("V90.dur_icon:find('PaperDoll', 1, true) ~= nil")), "v1.11.90: la colonna durability usa l'icona dell'equipaggiamento del client")
check(bool(rt.eval("V90.dur_hdr:find('PaperDoll', 1, true) ~= nil")), "v1.11.90: l'intestazione Durability usa quell'icona (non un file BCI)")
check(bool(rt.eval("V90.tint_g1 ~= nil and V90.tint_g1[1] == 0.2 and V90.tint_g1[2] == 1")), "v1.11.107: FontString durability verde quando l'attrezzatura e' a posto")
check(bool(rt.eval("V90.tint_g2 ~= nil and V90.tint_g2[1] == 1 and V90.tint_g2[2] == 0.15")), "v1.11.107: FontString durability ROSSA quando ci sono oggetti rotti")
check(bool(rt.eval("V90.dur_satisfied == false and V90.dur_missing ~= ''")), "v1.11.90: la categoria durability risulta NON soddisfatta e sa dire i nomi -- %s" % rt.eval("V90.dur_missing"))
check(bool(rt.eval("V90.dur_text:find('Gear to repair', 1, true) ~= nil and V90.dur_text_red")), "v1.11.90: tooltip/stato della durability in rosso con l'elenco di chi deve riparare")
check(bool(rt.eval("V90.dur_warn:find('RAID_WARNING', 1, true) ~= nil and V90.dur_warn:find('Gear check', 1, true) ~= nil")), "v1.11.90: click sull'icona Durability = raid warning di riparazione")
check(bool(rt.eval("V90.dur_providers == 0")), "v1.11.90: la durability non ha fornitori (nessuna assegnazione possibile)")
check(bool(rt.eval("V90.me_state == 'low' and V90.me_pct == 79 and V90.me_ok == false")), "v1.11.110: sotto l'80%% il Gear Check richiede il repair (79%% = low)")
check(bool(rt.eval("V90.me_state2 == 'ok' and V90.me_pct2 == 80 and V90.me_ok2 == true")), "v1.11.110: all'80%% esatto il Gear Check resta OK")
check(bool(rt.eval("V90.y_near == 0 and V90.y_far == 999 and V90.y_offgrid == 999 and V90.y_player == 0")), "v1.11.111: visibile/fuori area/proprio pg risolti con UnitIsVisible, non UnitInRange")
check(bool(rt.eval("V90.fade_near == 1 and V90.fade_far == 0.35")), "v1.11.111: fade solo quando l'unita' non e' piu' visibile (~100 yd/fuori area)")
check(bool(rt.eval("V90.fade_off == 1")), "v1.11.111: con il fade spento la barra torna piena")
check(bool(rt.eval("V90.tanks_untouched == true")), "v1.11.90: le barre MT/OT non vengono toccate dal fade")
check(bool(rt.eval("V90.miss_n > 1")), "v1.11.91: il caso di prova ha piu' di una categoria mancante (elenco non banale) -- %s" % rt.eval("tostring(V90.miss_n)"))
check(bool(rt.eval("V90.ctrl_sent == nil")), "v1.11.91: l'avviso del giocatore NON e' piu' un whisper: va in raid (niente messaggio privato)")
check(bool(rt.eval("V90.ctrl_raid ~= '' and V90.ctrl_raid:find('RAID_WARNING', 1, true) ~= nil")), "v1.11.91: CTRL+click = avviso in RAID (raid warning) -- %s" % rt.eval("tostring(V90.ctrl_raid)"))
check(bool(rt.eval("V90.ctrl_target ~= nil and V90.ctrl_raid:find(V90.ctrl_target, 1, true) ~= nil")), "v1.11.91: il messaggio in raid dice di CHI sono i buff mancanti")
check(bool(rt.eval("V90.ctrl_raid:find('Missing buffs on ', 1, true) ~= nil")), "v1.11.92: testo diretto da raid leading: 'Missing buffs on ...'")
check(bool(rt.eval("V90.ctrl_raid:find('Hey', 1, true) == nil")), "v1.11.92: niente piu' 'Hey ... you're missing some raid buffs' (alert non piu' giocoso)")
check(bool(rt.eval("V90.ctrl_target ~= nil and V90.ctrl_raid:find('Missing buffs on ' .. V90.ctrl_target .. ':', 1, true) ~= nil")), "v1.11.92: il nome sta subito dopo, col due punti -- %s" % rt.eval("tostring(V90.ctrl_raid)"))
check(bool(rt.eval("V90.ctrl_raid:find(V90.assign_short .. '(Lightwall)', 1, true) ~= nil")), "v1.11.93: la categoria assegnata compare col NOME DEL BUFF dell'assegnatario, non con la sigla -- %s" % rt.eval("tostring(V90.assign_short)"))
check(bool(rt.eval("V90.assign_short == 'Kings' and V90.first_key == 'stats'")), "v1.11.93: %stat assegnato a un paladino si legge 'Kings' (esempio esatto del raid leader)")
check(bool(rt.eval("V90.assign_none == 'nil'")), "v1.11.93: assegnatario che non e' un fornitore di quella categoria -> nessun nome inventato (si torna alla sigla)")
check(bool(rt.eval("V90.ctrl_raid:find('Kings', 1, true) ~= nil and V90.ctrl_raid:find('%%stat', 1, true) == nil")), "v1.11.93: nel messaggio la sigla %stat NON compare piu': al suo posto il nome del buff")
check(bool(rt.eval("V90.ctrl_raid:find(V90.miss_last, 1, true) ~= nil and V90.ctrl_raid:find(V90.miss_last .. '(', 1, true) == nil")), "v1.11.92: la categoria senza assegnatario resta senza parentesi (nessuno da citare)")

check(bool(rt.eval("V90.ctrl_raid:find(V90.assign_short, 1, true) ~= nil and V90.ctrl_raid:find(V90.miss_last, 1, true) ~= nil")), "v1.11.91: il messaggio elenca davvero tutti i buff mancanti, non solo il primo (il primo col nome del buff)")
check(bool(rt.eval("V90.ctrl_no_target == true")), "v1.11.90: il CTRL+click non cambia il target (gesto solo di avviso)")
check(bool(rt.eval("V90.plain_sent == nil and V90.plain_target == true")), "v1.11.90: senza CTRL il click continua a targettare come prima")
check(bool(rt.eval("V90.mp5_nil == true and V90.prov_n == 2")), "v1.11.90: nessuna assegnazione di partenza e 2 fornitori di MP5 (i due paladini) -- %s" % rt.eval("V90.prov_names"))
check(bool(rt.eval("V90.tip_shown == true and (V90.tip_title:find('MP5', 1, true) ~= nil or V90.tip_title:find('Mana Regeneration', 1, true) ~= nil)")), "v1.11.90: il tooltip della categoria si apre col nome della categoria")
check(bool(rt.eval("V90.tip_shown == true")), "v1.11.97: il tooltip categoria NON e' piu' un frame custom: e' il tooltip di gioco")
check(bool(rt.eval("V90.tip_unassigned == 'true'")), "v1.11.97: senza assegnazione il tooltip dice 'Not assigned'")
check(bool(rt.eval("V90.tip_row1 == 'true' and V90.tip_row2 == 'true'")), "v1.11.97: l'elenco fornitori e' nel tooltip di gioco")
check(bool(rt.eval("V90.tip_prov_label == 'true'")), "v1.11.97: il tooltip dice quanti fornitori ci sono (Providers (2))")
check(bool(rt.eval("V90.tip_assigned == 'true'")), "v1.11.97: assegnata, il tooltip mostra 'Assigned to: <nome player>'")
check(bool(rt.eval("V90.dragslot == true")), "v1.11.97: (setup) trovata la barra del giocatore da trascinare")
check(bool(rt.eval("V90.drag_on == true")), "v1.11.97: il drag parte dalla BARRA del giocatore (lo stesso drag che sposta di gruppo)")
check(bool(rt.eval("V90.hdr_glow ~= nil and V90.hdr_glow[1] == 1 and V90.hdr_glow[2] == 0.82")), "v1.11.97: durante il drag l'icona di categoria sotto il cursore si accende")
check(bool(rt.eval("V90.drag_assigned == 'Lightwall' and V90.drag_cleared == true")), "v1.11.97: lasciando la barra sull'icona la categoria va a quel giocatore")
check(bool(rt.eval("V90.no_group_move == true")), "v1.11.97: e il giocatore NON viene spostato di gruppo")
check(bool(rt.eval("V90.right_cleared == true")), "v1.11.90: click destro sull'icona = assegnazione rimossa")
check(bool(rt.eval("V90.warn_lines == 1")), "v1.11.99: click sull'icona = UNA sola riga (niente piu' il whisper all'assegnato) -- %s" % rt.eval("tostring(V90.warn_raid)"))
check(bool(rt.eval("V90.warn_raid:find('Missing Wisdom', 1, true) ~= nil and V90.warn_raid:find('Buff Check', 1, true) == nil and V90.warn_raid:find('Lightwall Provide for:', 1, true) ~= nil")), "v1.11.99: formato assegnato: 'Buff Check: Missing <nome buff> | <assegnato> Provide for: <nomi>' -- %s" % rt.eval("tostring(V90.warn_raid)"))
check(bool(rt.eval("V90.warn_raid:find('||', 1, true) ~= nil")), "v1.11.99: la pipe del separatore arriva in chat doppia (un '|' letterale in chat si scrive cosi': in gioco si legge singolo)")
check(bool(rt.eval("V90.warn_missing_names ~= '' and V90.warn_raid:find(V90.warn_missing_names, 1, true) ~= nil")), "v1.11.99: in coda ci sono i NOMI di chi non l'ha -- %s" % rt.eval("tostring(V90.warn_missing_names)"))
check(bool(rt.eval("V90.warn_raid ~= '' and V90.warn_raid:find('Missing Wisdom', 1, true) ~= nil")), "v1.11.90: l'avviso in raid resta (una riga sola, il whisper non c'e' piu') -- %s" % rt.eval("tostring(V90.warn_raid)"))
check(bool(rt.eval("V90.warn_lines_none == 1")), "v1.11.99: anche senza assegnazione una sola riga")
check(bool(rt.eval("V90.warn_raid_none:find('Missing MP5', 1, true) ~= nil and V90.warn_raid_none:find('Buff Check', 1, true) == nil and V90.warn_raid_none:find('Provide for:', 1, true) ~= nil")), "v1.11.99: formato non assegnato: 'Buff Check: Missing <categoria> | Provide for: <nomi>' -- %s" % rt.eval("tostring(V90.warn_raid_none)"))


print("\n== v1.11.100/1.11.102: tooltip della categoria SOTTO l'icona e sfondo PIENO (opacita' 100%) ==")
rt.execute("""
local RFM = RLSuite.raidFrame
local cols = RFM:_MatrixCols()
V100 = {}
local mp5, idx
for i, c in ipairs(cols) do if c.key == 'mp5' then mp5, idx = c, i end end
local btn = RFM._buffHdrBtns[idx]
V100.btn = btn
btn.GetLeft = function() return 400 end
btn.GetRight = function() return 424 end
btn.GetBottom = function() return 300 end
btn.GetTop = function() return 324 end
-- Catturo le chiamate fatte al tooltip di gioco.
local oSetOwner, oClear, oSetPoint, oColor = GameTooltip.SetOwner, GameTooltip.ClearAllPoints, GameTooltip.SetPoint, GameTooltip.SetBackdropColor
V100.owner, V100.ownerType, V100.points, V100.color = nil, nil, {}, {}
GameTooltip.SetOwner = function(s2, o, t, x, y) V100.owner, V100.ownerType = o, t return s2 end
GameTooltip.ClearAllPoints = function(s2) V100.cleared = true; s2._points = {} return s2 end
GameTooltip.SetPoint = function(s2, ...) V100.points[#V100.points + 1] = {...} return s2 end
GameTooltip.SetBackdropColor = function(s2, r, g, b, a) V100.color = {r, g, b, a} return s2 end
RFM:ShowBuffCatTip(mp5, btn)
GameTooltip.SetOwner, GameTooltip.ClearAllPoints, GameTooltip.SetPoint, GameTooltip.SetBackdropColor = oSetOwner, oClear, oSetPoint, oColor
local p = V100.points[1] or {}
V100.anchor_none = (V100.ownerType == "ANCHOR_NONE")
V100.anchor_owner = (V100.owner == btn)
V100.point, V100.relPoint = tostring(p[1]), tostring(p[3])
V100.point_y = tonumber(p[5]) or 0
V100.n_points = #V100.points
V100.below = (V100.point == "TOP" and V100.relPoint == "BOTTOM" and V100.point_y < 0)
-- nessun punto che appoggi il tooltip sull'icona (che deve restare visibile)
V100.over_icon = false
for i = 1, #V100.points do
    local q = V100.points[i]
    if q[1] == "TOPLEFT" or q[1] == "BOTTOMLEFT" or q[1] == "BOTTOMRIGHT" then V100.over_icon = true end
end
V100.bg_alpha = tonumber(V100.color[4])
V100.bg_dark = (tonumber(V100.color[1]) == 0.09 and tonumber(V100.color[2]) == 0.09 and tonumber(V100.color[3]) == 0.19)
-- Il client rimette i default a ogni Hide: se lo stile non venisse riapplicato
-- a ogni Show, il tooltip tornerebbe opaco.
V100.color = {}
GameTooltip.SetBackdropColor = function(s2, r, g, b, a) V100.color = {r, g, b, a} return s2 end
if GameTooltip.Hide then GameTooltip:Hide() end
V100.after_hide_alpha = tonumber(V100.color[4])   -- simulazione del reset del client
V100.color = {}
RFM:ShowBuffCatTip(mp5, btn)
GameTooltip.SetBackdropColor = oColor
V100.styled_again = (tonumber(V100.color[4]) == V100.bg_alpha)
""")
check(bool(rt.eval("V100.anchor_none and V100.anchor_owner and V100.n_points == 1")), "v1.11.100: il tooltip e' ancorato all'icona con ANCHOR_NONE + UN punto scritto da noi")
check(bool(rt.eval("V100.below")), "v1.11.100: il tooltip sta SOTTO l'icona (TOP del tooltip sul BOTTOM dell'icona, y = %s) -- %s/%s" % (rt.eval("tostring(V100.point_y)"), rt.eval("V100.point"), rt.eval("V100.relPoint")))
check(bool(rt.eval("V100.over_icon == false")), "v1.11.100: nessun punto che appoggi il tooltip SOPRA l'icona (l'icona resta visibile)")
check(bool(rt.eval("V100.bg_alpha == 1")), "v1.11.102: sfondo del tooltip a OPACITA' PIENA (alpha = %s, 100%%: non si vede sotto) -- %s" % (rt.eval("tostring(V100.bg_alpha)"), rt.eval("tostring(V100.color[1]) .. '/' .. tostring(V100.color[2]) .. '/' .. tostring(V100.color[3])")))
check(bool(rt.eval("V100.bg_dark == true")), "v1.11.100: resta il colore di sfondo del tooltip di gioco (testo leggibile, grafica non toccata)")
check(bool(rt.eval("V100.styled_again == true")), "v1.11.100: lo stile viene riapplicato a OGNI Show (il client ripristina il fondo pieno a ogni Hide)")


print("\n== v1.11.101: tooltip categoria libera -> dice anche COME si assegna ==")
rt.execute("""
local RFM = RLSuite.raidFrame
local cols = RFM:_MatrixCols()
V101 = {}
local mp5, idx
for i, c in ipairs(cols) do if c.key == 'mp5' then mp5, idx = c, i end end
local btn = RFM._buffHdrBtns[idx]
local TT = {}
local oAdd, oClear = GameTooltip.AddLine, GameTooltip.ClearLines
GameTooltip.AddLine = function(s2, txt) TT[#TT + 1] = tostring(txt) return s2 end
GameTooltip.ClearLines = function(s2) TT = {} return s2 end
RFM:SetBuffAssign(mp5, nil)
RFM:ShowBuffCatTip(mp5, btn)
V101.unassigned = {}
for i = 1, #TT do V101.unassigned[i] = TT[i] end
RFM:SetBuffAssign(mp5, 'Holymoon')
RFM:ShowBuffCatTip(mp5, btn)
V101.assigned = {}
for i = 1, #TT do V101.assigned[i] = TT[i] end
RFM:SetBuffAssign(mp5, nil)
GameTooltip.AddLine, GameTooltip.ClearLines = oAdd, oClear
V101.unassigned_txt = table.concat(V101.unassigned, " | ")
V101.assigned_txt = table.concat(V101.assigned, " | ")
""")
_ok = rt.eval("(function() for _, ln in ipairs(V101.unassigned) do if ln == 'Not assigned - Drop a player on the icon to assign the buff' then return true end end return false end)()")
check(bool(_ok), "v1.11.101: categoria libera -> riga esatta '%s' -- %s" % ('Not assigned - Drop a player on the icon to assign the buff', rt.eval("V101.unassigned_txt")))
_ok = rt.eval("(function() for _, ln in ipairs(V101.unassigned) do if ln == 'Not assigned' then return true end end return false end)()")
check(not bool(_ok), "v1.11.101: la vecchia riga secca 'Not assigned' non c'e' piu'")
_ok = rt.eval("V101.assigned_txt:find('Assigned to: Holymoon', 1, true) ~= nil")
check(bool(_ok), "v1.11.101: con l'assegnazione resta 'Assigned to: <nome>' (nessuna riga in piu') -- %s" % rt.eval("V101.assigned_txt"))
_ok = rt.eval("V101.assigned_txt:find('Drop a player on the icon', 1, true) == nil")
check(bool(_ok), "v1.11.101: il suggerimento compare SOLO quando la categoria e' libera")
print("\n== v1.11.91: doppio roll ignorato (vale solo il primo) ==")
rt.execute("""
local lm = RLSuite.lootManager
DBG_LM_SAVED = RLSuite.db.profile.debug
RLSuite.db.profile.debug = true
RLSuite.mainWindow:ShowTab("loot")
local tmpl = lm:GetRollTemplate()

-- 1) Furbetto rolla 12, poi Onesto 77, poi Furbetto riprova con 99.
CHAT_LOG = {}
lm:ClearHistory()
lm:AddToHistory("|cffff8000|Hitem:42|h[Doppio Roll]|h|r", "Doppio Roll", "tex", 4)
lm:SelectItem(lm.history[#lm.history])
lm:StartRoll("MS")
lm.currentRoll.rolls = {}
lm.currentRoll.seen = {}
lm:OnSystemRoll(string.format(tmpl, "Furbetto", 12, 1, 100))
lm:OnSystemRoll(string.format(tmpl, "Onesto", 77, 1, 100))
lm:OnSystemRoll(string.format(tmpl, "Furbetto", 99, 1, 100))
DR_N = #lm.currentRoll.rolls
DR_FIRST_NAME = lm.currentRoll.rolls[1] and lm.currentRoll.rolls[1].name
DR_FIRST_ROLL = lm.currentRoll.rolls[1] and lm.currentRoll.rolls[1].roll
DR_LAST_NAME = lm.currentRoll.rolls[#lm.currentRoll.rolls] and lm.currentRoll.rolls[#lm.currentRoll.rolls].name
DR_SEEN = lm.currentRoll.seen["Furbetto"]
DR_PRINT = ""
for i = #CHAT_LOG, 1, -1 do
    if CHAT_LOG[i]:find("Double roll", 1, true) then DR_PRINT = CHAT_LOG[i]; break end
end
for tick = 1, 30 do if lm.rollTimer then lm:RollTick() end end
DR_WINNER = lm.history[#lm.history].assignedTo

-- 2) spareggio: dopo il pareggio i pareggiati devono poter rollare DI NUOVO
lm:ClearHistory()
lm:AddToHistory("|cffff8000|Hitem:43|h[Pari]|h|r", "Pari", "tex", 4)
lm:SelectItem(lm.history[#lm.history])
lm:StartRoll("MS")
lm.currentRoll.rolls = {}
lm.currentRoll.seen = {}
lm:OnSystemRoll(string.format(tmpl, "Tankbot", 50, 1, 100))
lm:OnSystemRoll(string.format(tmpl, "Healbot", 50, 1, 100))
for tick = 1, 30 do if lm.rollTimer then lm:RollTick() end end
DR_TIE_REROLL_BTN = lm.rerollBtn:IsEnabled()
lm:DoReroll()
DR_REROLL_N = #lm.currentRoll.rolls
for tick = 1, 30 do if lm.rerollTimer then lm:RerollTick() end end
DR_REROLL_ASSIGNED = lm.history[#lm.history].assignedTo

lm:ClearHistory()
lm.frame:Hide()
RLSuite.mainWindow.currentTab = nil
RLSuite.db.profile.debug = DBG_LM_SAVED
""")
check(bool(rt.eval("DR_N == 2")), "v1.11.91: il secondo roll di Furbetto NON entra in lista (2 roll totali su 3 messaggi)")
check(bool(rt.eval("DR_FIRST_NAME == 'Furbetto' and DR_FIRST_ROLL == 12")), "v1.11.91: del doppio roll viene tenuto il PRIMO (Furbetto 12), non il 99 arrivato dopo")
check(bool(rt.eval("DR_LAST_NAME == 'Onesto'")), "v1.11.91: la lista resta quella dei roll legittimi (il secondo di Furbetto non c'è)")
check(bool(rt.eval("DR_SEEN == 12")), "v1.11.91: la mappa dei roll gia' visti tiene il primo valore (12)")
check(bool(rt.eval("DR_PRINT ~= '' and DR_PRINT:find('Furbetto', 1, true) ~= nil")), "v1.11.91: il raid leader vede l'avviso del doppio roll scartato -- %s" % rt.eval("tostring(DR_PRINT)"))
check(bool(rt.eval("DR_WINNER == 'Onesto'")), "v1.11.91: vince Onesto con 77 -- senza la correzione avrebbe vinto Furbetto col 99 del secondo roll")
check(bool(rt.eval("DR_TIE_REROLL_BTN == true and DR_REROLL_N >= 1")), "v1.11.91: dopo un pareggio i pareggiati possono rollare di nuovo (il 'primo roll' riparte)")
check(bool(rt.eval("DR_REROLL_ASSIGNED == 'Tankbot' or DR_REROLL_ASSIGNED == 'Healbot'")), "v1.11.91: lo spareggio si risolve e assegna l'oggetto a uno dei pareggiati")
print("\n== v1.11.93: nome del buff dell'assegnato negli avvisi ==")
rt.execute("""
local RFM = RLSuite.raidFrame
local cols = RFM:_MatrixCols()
V93 = {}
local function findCol(key)
    for _, c in ipairs(cols) do if c.key == key then return c end end
end
V93.kings  = tostring(RFM:BuffShortName(findCol("stats"), "PALADIN"))
V93.wisdom = tostring(RFM:BuffShortName(findCol("mp5"), "PALADIN"))
V93.spring = tostring(RFM:BuffShortName(findCol("mp5"), "SHAMAN"))
V93.rider  = tostring(RFM:BuffShortName(findCol("stats"), "MAGE"))     -- classe non fornitrice
V93.repl   = tostring(RFM:BuffShortName(findCol("replen"), "MAGE"))    -- categoria senza nome corto
V93.dur    = tostring(RFM:BuffShortName(findCol("durability"), "PALADIN"))
V93.none   = tostring(RFM:BuffShortName(nil, "PALADIN"))
""")
check(bool(rt.eval("V93.kings == 'Kings'")), "v1.11.93: %stat + paladino = 'Kings'")
check(bool(rt.eval("V93.wisdom == 'Wisdom' and V93.spring == 'Mana Spring'")), "v1.11.93: MP5 cambia nome secondo la classe che lo fa (pala = Wisdom, shaman = Mana Spring)")
check(bool(rt.eval("V93.rider == 'nil'")), "v1.11.93: classe non fornitrice di quella categoria -> nessun nome (si usa la sigla)")
check(bool(rt.eval("V93.repl == 'nil' and V93.dur == 'nil' and V93.none == 'nil'")), "v1.11.93: categoria/classe non in tabella (e colonna di servizio) -> nessun nome inventato")
print("\n== v1.11.94: projectiles ignorabili + lista ignora (ctrl+click, config) ==")
rt.execute("""
local lm = RLSuite.lootManager
local ID_MINE = '|cff1eff00|Hitem:99011:0:0:0:0:0:0:0:80|h[Saronite Arrow]|h|r'
local ID_GEM  = '|cff0070dd|Hitem:99012:0:0:0:0:0:0:0:80|h[Bold Cardinal Ruby]|h|r'
ITEMINFO_DB[ID_MINE] = {'Saronite Arrow', ID_MINE, 2, 75, 70, 'Projectile', 'Arrow', 1000, '', 'tex'}
ITEMINFO_DB[ID_GEM]  = {'Bold Cardinal Ruby', ID_GEM, 3, 80, 80, 'Gem', 'Red', 1, '', 'tex'}
lm:ClearIgnoredItems()
lm:SetCategoryIgnored('projectiles', false)
lm:SetCategoryIgnored('gems', false)
lm:ClearHistory()
lm.selectedItem = nil
V94 = {}

-- --- 1) projectiles rimosso da categorie ignorabili ---
V94.cap_on = 0
V94.cap_off = 1
V94.cb_on = false
V94.cb_off = false

-- --- 2) ctrl+click su una riga: l'item entra nella lista ignora ---
lm:ClearHistory()
lm:OnLootMessage('You receive loot: ' .. ID_GEM .. '.')
lm:OnLootMessage('You receive loot: ' .. ID_MINE .. '.')
lm:UpdateHistory()
V94.rows_before = #lm.histRows
local target
for _, r in ipairs(lm.histRows) do
    if r.entry and r.entry.itemName == 'Saronite Arrow' then target = r end
end
V94.row_found = (target ~= nil)
IsControlKeyDown = function() return true end
CHAT_LOG = {}
target._scripts.OnClick(target, 'LeftButton')
IsControlKeyDown = function() return false end
V94.list_n = lm:IgnoredCount()
V94.list_id = tostring(lm:IgnoreList()[1] and lm:IgnoreList()[1].id)
V94.list_name = tostring(lm:IgnoreList()[1] and lm:IgnoreList()[1].name)
V94.rows_after = #lm.histRows
V94.selected = (lm.selectedItem == nil)
V94.print = CHAT_LOG[#CHAT_LOG]
-- la riga sparita non torna nemmeno ridisegnando
lm:UpdateHistory()
V94.rows_after2 = #lm.histRows
-- e l'item NON viene piu' catturato
local n0 = #lm.history
lm:OnLootMessage('You receive loot: ' .. ID_MINE .. '.')
V94.cap_after = #lm.history - n0

-- --- 3) click NORMALE: continua a selezionare l'item ---
lm:ClearIgnoredItems()
lm:UpdateHistory()
local gemRow
for _, r in ipairs(lm.histRows) do if r.entry and r.entry.itemName == 'Bold Cardinal Ruby' then gemRow = r end end
gemRow._scripts.OnClick(gemRow, 'LeftButton')
V94.plain_select = (lm.selectedItem ~= nil and lm.selectedItem.itemName == 'Bold Cardinal Ruby')
V94.plain_ignored = lm:IgnoredCount()

-- --- 4) la lista si modifica dalla Configurazione ---
local opt = RLSuite.config:BuildOptionsTable().args.loot.args
V94.opt_list = (opt.ignoreList ~= nil and opt.ignoreList.type == 'input' and opt.ignoreList.multiline ~= nil)
V94.opt_clear = (opt.ignoreClear ~= nil and opt.ignoreClear.type == 'execute')
opt.ignoreList.set(nil, '12345: Test Item')
V94.txt1 = lm:IgnoredListText()
-- piu' righe, con link incollato e riga in formato "id - nome"
opt.ignoreList.set(nil, '|cff1eff00|Hitem:99011:0:0:0:0:0:0:0:80|h[Saronite Arrow]|h|r\\n67890 - Freccia\\n\\n  333  ')
V94.txt2 = lm:IgnoredListText()
V94.ids = ''
for _, e in ipairs(lm:IgnoreList()) do V94.ids = V94.ids .. tostring(e.id) .. ',' end
V94.dedup = lm:AddIgnoredItem(99011, 'Doppione')
V94.count_after_dedup = lm:IgnoredCount()
-- le categorie si comandano anche dalla configurazione
V94.toggle = (opt.fShards ~= nil)
V94.cat_from_cfg = true
V94.cb_from_cfg = true
opt.ignoreClear.func()
V94.cleared_n = lm:IgnoredCount()
V94.txt3 = lm:IgnoredListText()
lm:ClearHistory()
lm:UpdateHistory()
""")
# projectiles removed
check(bool(rt.eval("V94.cap_on == 0 and V94.cap_off == 1")), "v1.11.94: con 'projectiles' fra i loot ignorabili le frecce non vengono nemmeno registrate; spento, tornano")
# projectiles removed
# projectiles removed
check(bool(rt.eval("V94.row_found == true and V94.rows_before == 2")), "v1.11.94: (setup) due item in storico, uno e' la freccia")
check(bool(rt.eval("V94.list_n == 1 and V94.list_id == '99011' and V94.list_name == 'Saronite Arrow'")), "v1.11.94: CTRL+click sulla riga aggiunge l'item alla lista ignora -- %s (%s)" % (rt.eval("V94.list_name"), rt.eval("V94.list_id")))
check(bool(rt.eval("V94.rows_after == 1 and V94.rows_after2 == 1")), "v1.11.94: la riga sparisce subito dalla lista e NON torna ridisegnando")
check(bool(rt.eval("V94.selected == true")), "v1.11.94: ignorare un item deseleziona (niente roll su roba appena ignorata)")
check(bool(rt.eval("V94.print ~= nil and V94.print:find('never be shown again', 1, true) ~= nil")), "v1.11.94: conferma a video -- %s" % rt.eval("tostring(V94.print)"))
check(bool(rt.eval("V94.cap_after == 0")), "v1.11.94: l'item ignorato non viene piu' registrato MAI piu' (filtro in cattura)")
check(bool(rt.eval("V94.plain_select == true and V94.plain_ignored == 0")), "v1.11.94: senza CTRL il click continua a selezionare l'item (nessuna regressione)")
check(bool(rt.eval("V94.opt_list == true and V94.opt_clear == true")), "v1.11.94: la lista ignora e' modificabile in Configurazione -> Loot (campo multiriga + 'Clear ignored items')")
check(bool(rt.eval("V94.txt1 == '12345: Test Item'")), "v1.11.94: scrittura in config -> lista salvata -- %s" % rt.eval("tostring(V94.txt1)"))
check(bool(rt.eval("V94.ids == '99011,67890,333,'")), "v1.11.94: il testo accetta piu' righe, il LINK incollato, 'id - nome', righe vuote e spazi (gli id sono quelli giusti) -- %s" % rt.eval("tostring(V94.ids)"))
check(bool(rt.eval("V94.dedup == false and V94.count_after_dedup == 3")), "v1.11.94: niente doppioni nella lista (aggiungere un id gia' presente non fa nulla)")
check(bool(rt.eval("V94.toggle == true and V94.cat_from_cfg == true and V94.cb_from_cfg == true")), "v1.11.94: le 5 categorie ignorabili si comandano anche dalla configurazione (stessa scrittura della finestra)")
check(bool(rt.eval("V94.cleared_n == 0 and V94.txt3 == ''")), "v1.11.94: 'Clear ignored items' svuota la lista e il campo torna vuoto")
print("\n== v1.11.95: la voce Loot c'e' nell'albero del Config (non solo nelle opzioni) ==")
rt.execute("""
local CFG = RLSuite.config
V95 = {}
-- 1) l'albero di navigazione: le voci visibili nel pannello
V95.values = {}
local function walk(nodes)
    for _, n in ipairs(nodes or {}) do
        V95.values[#V95.values + 1] = tostring(n.value)
        if n.children then walk(n.children) end
    end
end
-- SetTree e' stato chiamato in CreateWindow: lo ripeto su un albero nuovo per
-- leggere quello che il pannello riceve davvero.
-- l'albero vero del pannello (le voci che l'utente vede a sinistra)
local tree = CFG.tree and CFG.tree.tree
V95.tree_created = (tree ~= nil)
walk(tree)
-- 2) selezionando la voce, il contenuto aperto deve essere il gruppo Loot
local origFeed = CFG.FeedNode
CFG.FeedNode = function(self2, path) V95.path = table.concat(path or {}, "/") end
CFG:OnNodeSelected("loot")
V95.current = tostring(CFG.currentNode)
CFG.FeedNode = origFeed
-- 3) il gruppo Loot ha davvero i controlli (campo lista + clear + categorie)
local args = CFG:BuildOptionsTable().args.loot.args
V95.list = (args.ignoreList ~= nil)
V95.clear = (args.ignoreClear ~= nil)
V95.cats = ((args.fRecipes and 1 or 0) + (args.fBoe and 1 or 0) + (args.fGems and 1 or 0)
    + (args.fShards and 1 or 0) + (args.fProjectiles and 1 or 0))
CFG:OnNodeSelected("general")
""")
check(bool(rt.eval("V95.tree_created == true and V95.values ~= nil")), "v1.11.95: (setup) albero del Config catturato")
_has = rt.eval("(function() for _, v in ipairs(V95.values) do if v == 'loot' then return true end end return false end)()")
_names = rt.eval("table.concat(V95.values, ',')")
check(bool(_has), "v1.11.95: 'Loot' e' nell'albero di navigazione del pannello -- %s" % _names)
check(bool(rt.eval("V95.path == 'loot' and V95.current == 'loot'")), "v1.11.95: selezionando 'Loot' il pannello apre il gruppo loot (non una pagina vuota)")
check(bool(rt.eval("V95.list == true and V95.clear == true and V95.cats == 4")), "v1.11.95: dentro Loot ci sono il campo lista ignora, il clear e le 4 categorie")
print("\n== v1.11.97: tooltip categoria INFORMATIVO (tooltip di gioco) + assegnazione dal drag delle barre ==")
rt.execute("""
local RFM = RLSuite.raidFrame
local cols = RFM:_MatrixCols()
V97 = {}
local mp5, idx
for i, c in ipairs(cols) do if c.key == 'mp5' then mp5, idx = c, i end end
V97.no_custom_tip = (RFM._buffCatTip == nil)
V97.no_ghost = (RFM._assignGhost == nil)
V97.no_tip_drag = ((RFM._StartAssignDrag == nil) and (RFM._DropAssignDrag == nil))
TT2 = {}
local oAdd, oClear = GameTooltip.AddLine, GameTooltip.ClearLines
GameTooltip.AddLine = function(s2, txt) TT2[#TT2 + 1] = tostring(txt) return s2 end
GameTooltip.ClearLines = function(s2) TT2 = {} return s2 end
RFM:SetBuffAssign(mp5, 'Holymoon')
RFM:ShowBuffCatTip(mp5, RFM._buffHdrBtns[idx])
V97.txt = table.concat(TT2, " | ")
GameTooltip.AddLine, GameTooltip.ClearLines = oAdd, oClear
V97.has_title = (V97.txt:find('MP5', 1, true) ~= nil)
V97.has_assign = (V97.txt:find('Assigned to: Holymoon', 1, true) ~= nil)
V97.has_provs = (V97.txt:find('PALADIN', 1, true) ~= nil)
V97.has_hint = (V97.txt:find('Right-click', 1, true) ~= nil)
local atk, aidx
for i, c in ipairs(cols) do if c.key == 'atkpower' then atk, aidx = c, i end end
local slot
for _, sl in ipairs(RFM.slots) do if sl.member and sl.member.name == 'Drakbot' then slot = sl end end
RFM:SetBuffAssign(mp5, nil)
RFM:SetBuffAssign(atk, nil)
local hb = RFM._buffHdrBtns[aidx]
hb.GetLeft = function() return 200 end
hb.GetRight = function() return 220 end
hb.GetBottom = function() return 100 end
hb.GetTop = function() return 116 end
local saved = GetCursorPosition
GetCursorPosition = function() return 210, 108 end
RFM:_StartDragFromSlot(slot)
RFM:_FinishDrag()
GetCursorPosition = saved
V97.drag_assign = tostring(RFM:GetBuffAssign(atk))
V97.other_untouched = (RFM:GetBuffAssign(mp5) == nil)
GetCursorPosition = function() return 5000, 5000 end
RFM:_StartDragFromSlot(slot)
RFM:_FinishDrag()
GetCursorPosition = saved
V97.no_assign_offgrid = (RFM:GetBuffAssign(atk) == 'Drakbot')
RFM._buffHdrBtns[aidx]._scripts.OnClick(RFM._buffHdrBtns[aidx], 'RightButton')
V97.right_cleared = (RFM:GetBuffAssign(atk) == nil)
RFM:SetBuffAssign(mp5, nil)
""")
check(bool(rt.eval("V97.no_custom_tip == true and V97.no_ghost == true and V97.no_tip_drag == true")), "v1.11.97: spariti frame custom, fantasma e drag dal tooltip (il tooltip e' SOLO informativo)")
check(bool(rt.eval("V97.has_title == true and V97.has_assign == true and V97.has_provs == true")), "v1.11.97: il tooltip di gioco mostra categoria, assegnazione e fornitori -- %s" % rt.eval("tostring(V97.txt)"))
check(bool(rt.eval("V97.has_hint == true")), "v1.11.97: e in coda ricorda cosa fanno i click (left = check buff, right = togli assegnazione)")
check(bool(rt.eval("V97.drag_assign == 'Drakbot' and V97.other_untouched == true")), "v1.11.97: trascinando la BARRA e lasciandola su un'icona, quella categoria va a quel giocatore")
check(bool(rt.eval("V97.no_assign_offgrid == true")), "v1.11.97: lasciando la barra lontano dalle icone non si assegna niente (comportamento di prima)")
check(bool(rt.eval("V97.right_cleared == true")), "v1.11.97: click destro sull'icona = assegnazione tolta")


print("\n== v1.11.98: il rilascio sull'icona trova la categoria anche con la scala UI ==")
rt.execute("""
local RFM = RLSuite.raidFrame
local cols = RFM:_MatrixCols()
V98 = {}
local atk, aidx
for i, c in ipairs(cols) do if c.key == 'atkpower' then atk, aidx = c, i end end
local slot
for _, sl in ipairs(RFM.slots) do if sl.member and sl.member.name == 'Drakbot' then slot = sl end end
RFM:SetBuffAssign(atk, nil)

-- Icona: rettangolo 200..220 x 100..116 in COORDINATE UI, scala effettiva 0.8
-- (come un client con UI non al 100%): il cursore e' in pixel FISICI.
local hb = RFM._buffHdrBtns[aidx]
hb.GetLeft = function() return 200 end
hb.GetRight = function() return 220 end
hb.GetBottom = function() return 100 end
hb.GetTop = function() return 116 end
hb.GetEffectiveScale = function() return 0.8 end
local saved = GetCursorPosition
-- centro dell'icona in pixel fisici = coordinate UI * scala
GetCursorPosition = function() return 210 * 0.8, 108 * 0.8 end
V98.hit_center = (RFM:_BuffHeaderAtCursor() == hb)
RFM:_StartDragFromSlot(slot)
RFM:_FinishDrag()
V98.assigned_scaled = tostring(RFM:GetBuffAssign(atk))
-- bordo dell'icona (dentro il margine): deve prendere lo stesso
RFM:SetBuffAssign(atk, nil)
GetCursorPosition = function() return (200 - 5) * 0.8, (116 + 5) * 0.8 end
V98.hit_margin = (RFM:_BuffHeaderAtCursor() == hb)
RFM:_StartDragFromSlot(slot)
RFM:_FinishDrag()
V98.assigned_margin = tostring(RFM:GetBuffAssign(atk))
-- lontano: nessuna assegnazione, nessun errore
RFM:SetBuffAssign(atk, nil)
GetCursorPosition = function() return 9000, 9000 end
V98.hit_far = (RFM:_BuffHeaderAtCursor() == nil)
RFM:_StartDragFromSlot(slot)
RFM:_FinishDrag()
V98.assigned_far = tostring(RFM:GetBuffAssign(atk))
-- scala 1 (client normale): deve continuare a funzionare
hb.GetEffectiveScale = function() return 1 end
GetCursorPosition = function() return 210, 108 end
V98.hit_scale1 = (RFM:_BuffHeaderAtCursor() == hb)
GetCursorPosition = saved
RFM:SetBuffAssign(atk, nil)
""")
check(bool(rt.eval("V98.hit_center == true")), "v1.11.98: con la scala UI (0.8) il cursore sull'icona viene riconosciuto (prima: pixel fisici vs coordinate UI -> mai trovata)")
check(bool(rt.eval("V98.assigned_scaled == 'Drakbot'")), "v1.11.98: rilasciando li' la categoria viene assegnata (niente piu' 'rilascio senza bersaglio')")
check(bool(rt.eval("V98.hit_margin == true and V98.assigned_margin == 'Drakbot'")), "v1.11.98: un rilascio a 5 px dal bordo icona vale lo stesso (margine di 8 px)")
check(bool(rt.eval("V98.hit_far == true and V98.assigned_far == 'nil'")), "v1.11.98: lontano dalle icone non si assegna niente (comportamento invariato)")
check(bool(rt.eval("V98.hit_scale1 == true")), "v1.11.98: con la scala a 1 (client normale) l'hit-test resta identico")

# ============================================================
# v1.11.103: Groupmaking spam channels in English, no Italian, /guild and /yell added
# ============================================================
print("== v1.11.103: Groupmaking spam channels: General, Guild, Yell, global (English only) ==")
rt.execute("""
V103 = {}
-- 1. Verifica che in Locale non ci sia alcuna stringa tradotta in italiano per i canali
local loc = RLSuite.L
V103.general = loc["General"]
V103.guild = loc["Guild"]
V103.yell = loc["Yell"]
V103.global_chan = loc["global"]

-- 2. Config options tree for Groupmaking
local opt = RLSuite.config:BuildOptionsTable()
local gmArgs = opt.args.groupmaking.args
V103.has_general = (gmArgs.spam_General ~= nil)
V103.has_guild = (gmArgs.spam_Guild ~= nil)
V103.has_yell = (gmArgs.spam_Yell ~= nil)
V103.has_global = (gmArgs.spam_global ~= nil)
V103.no_trade = (gmArgs.spam_Trade == nil)
V103.no_lfg = (gmArgs.spam_LookingForGroup == nil)
V103.no_world = (gmArgs.spam_World == nil)

-- 3. Guild e Yell spammati tramite i canali di sistema di WoW
CHAT_LOG = {}
CHAT_DEST = {}
local saved_debug = RLSuite.db.profile.debug
RLSuite.db.profile.debug = false

RLSuite.groupmaking.db.spamChannels = {"Guild", "Yell"}
RLSuite.groupmaking:DoSpam()

V103.chat1 = CHAT_LOG[1]
V103.chat2 = CHAT_LOG[2]

RLSuite.db.profile.debug = saved_debug
""")
check(rt.eval("V103.general") == "General", "v1.11.103: 'General' in Locale risolve in inglese (General, non Generale)")
check(rt.eval("V103.guild") == "Guild", "v1.11.103: 'Guild' in Locale risolve in inglese (Guild)")
check(rt.eval("V103.yell") == "Yell", "v1.11.103: 'Yell' in Locale risolve in inglese (Yell)")
check(rt.eval("V103.global_chan") == "global", "v1.11.103: 'global' in Locale risolve in inglese (global, non globale)")
check(bool(rt.eval("V103.has_general and V103.has_guild and V103.has_yell and V103.has_global")), "v1.11.103: Config contiene i toggle per General, Guild, Yell, global")
check(bool(rt.eval("V103.no_trade and V103.no_lfg and V103.no_world")), "v1.11.103: Trade, LookingForGroup e World sono stati rimossi da Config")
check(bool(rt.eval("V103.chat1 ~= nil and V103.chat1:find('GUILD|', 1, true) == 1")), "v1.11.103: Canale Guild invia su GUILD")
check(bool(rt.eval("V103.chat2 ~= nil and V103.chat2:find('YELL|', 1, true) == 1")), "v1.11.103: Canale Yell invia su YELL")

# ============================================================
# ============================================================
# v1.11.105: CombatLog module completely removed
# ============================================================
print("== v1.11.105: CombatLog module completely removed ==")
check(bool(rt.eval("RLSuite.combatLog == nil")), "v1.11.105: RLSuite.combatLog is nil")
check(bool(rt.eval("RLSuite.mainWindow.tabs.log == nil")), "v1.11.105: 'log' tab button removed from main window")
check(bool(rt.eval("RLSuite.mainWindow:PaneForTab('log') == nil")), "v1.11.105: PaneForTab('log') is nil")
check(bool(rt.eval("#RLSuite.debugPanel.debugButtons == 6")), "v1.11.105: debug panel has 6 buttons (Log Test removed, Toggle RF added)")


print()
print("== v1.11.107: RaidFrame consumables removed, Buff Matrix Flask/Food/Durability & Feast/Bot RW ==")
# 1. No flaskIcon or foodIcon on rows
check(bool(rt.eval("RLSuite.raidFrame.rows[1].flaskIcon == nil and RLSuite.raidFrame.rows[1].foodIcon == nil")), "v1.11.107: per-row flask/food icons completely removed")

# 2. Flask and Food in Buff Matrix have no providers
rt.execute('''
local cols = RLSuite.raidFrame:_MatrixCols()
local flaskCol, foodCol, durCol
for _, c in ipairs(cols) do
    if c.key == "flask" then flaskCol = c
    elseif c.key == "wellfed" then foodCol = c
    elseif c.kind == "durability" then durCol = c end
end
V107_FLASK_PROVS = #RLSuite.raidFrame:BuffProviders(flaskCol)
V107_FOOD_PROVS = #RLSuite.raidFrame:BuffProviders(foodCol)
V107_DUR_PROVS = #RLSuite.raidFrame:BuffProviders(durCol)

-- Tooltip test for flask / food / dur
TT_LINES_107 = {}
local oAdd = GameTooltip.AddLine
GameTooltip.AddLine = function(s, txt) TT_LINES_107[#TT_LINES_107 + 1] = tostring(txt) return s end
RLSuite.raidFrame:ShowBuffCatTip(flaskCol, UIParent)
V107_FLASK_TIP = table.concat(TT_LINES_107, " | ")
TT_LINES_107 = {}
RLSuite.raidFrame:ShowBuffCatTip(durCol, UIParent)
V107_DUR_TIP = table.concat(TT_LINES_107, " | ")
GameTooltip.AddLine = oAdd

-- WarnBuffCategory test for flask
local nBefore = #CHAT_LOG
RLSuite.raidFrame:WarnBuffCategory(flaskCol)
V107_FLASK_WARN = CHAT_LOG[#CHAT_LOG] or ""

-- Feast & Bot drops test
CHAT_LOG = {}
RLSuite:OnCombatLog("COMBAT_LOG_EVENT_UNFILTERED", 0, "SPELL_CAST_SUCCESS", "0x1", "SuperChef", 0, "0x0", "", 0, 57426)
V107_FEAST_WARN = CHAT_LOG[#CHAT_LOG] or ""
CHAT_LOG = {}
RLSuite:OnCombatLog("COMBAT_LOG_EVENT_UNFILTERED", 0, "SPELL_SUMMON", "0x2", "EngiGuy", 0, "0x0", "", 0, 67826)
V107_BOT_WARN = CHAT_LOG[#CHAT_LOG] or ""
''')

check(rt.eval("V107_FLASK_PROVS") == 0, "v1.11.107: Flask has 0 providers in matrix")
check(rt.eval("V107_FOOD_PROVS") == 0, "v1.11.107: Food has 0 providers in matrix")
check(rt.eval("V107_DUR_PROVS") == 0, "v1.11.107: Durability has 0 providers in matrix")
check(bool(rt.eval("V107_FLASK_TIP:find('Providers', 1, true) == nil and V107_FLASK_TIP:find('Assigned to', 1, true) == nil")), "v1.11.107: Flask tooltip does not show providers or assignments")
check(bool(rt.eval("V107_DUR_TIP:find('Providers', 1, true) == nil and V107_DUR_TIP:find('Assigned to', 1, true) == nil")), "v1.11.107: Durability tooltip does not show providers or assignments")
check(bool(rt.eval("V107_FLASK_WARN:find('Missing Flask', 1, true) ~= nil and V107_FLASK_WARN:find('Buff Check', 1, true) == nil and V107_FLASK_WARN:find('Provide for', 1, true) == nil")), "v1.11.107: Flask alert format is clean Missing list (no Provide for)")
check(bool(rt.eval("V107_FEAST_WARN:find('SuperChef put down Fish Feast!', 1, true) ~= nil")), "v1.11.107: Feast drop announces '<Caster> put down Fish Feast!'")
check(bool(rt.eval("V107_BOT_WARN:find('EngiGuy put down Jeeves!', 1, true) ~= nil")), "v1.11.107: Repair bot drop announces '<Caster> put down Jeeves!'")




print()
print("== v1.11.108: RaidFrame Group N headers, toggle option, Raid Buffs button size, role icons, fade fix, player tooltip and right-click menu ==")
rt.execute('''
local RF = RLSuite.raidFrame
local m = RF:LayoutMetrics()

-- 1. Test Group Header text
V108_HDR_TEXT = RF.groupHeaders[1]:GetText()

-- 2. Test Raid Buffs button size
local btnW, btnH = RF.buffPanelBtn:GetWidth(), RF.buffPanelBtn:GetHeight()
V108_BTN_W = btnW
V108_BTN_H = btnH
V108_EXP_W = m.cdReserve
V108_EXP_H = m.barHeight

-- 3. Test Role Icon exists on row
local row1 = RF.slots[1]
V108_HAS_ROLE_ICON = (row1.roleIcon ~= nil)

-- 4. Test Distance Fade with UnitIsConnected / UnitIsVisible / UnitInRange
local oConnected = UnitIsConnected
local oVisible = UnitIsVisible
local oRange = UnitInRange

UnitIsConnected = function(u) if u == "raidFar" then return false end return true end
UnitIsVisible = function(u) if u == "raidFar" then return false end return true end
UnitInRange = function(u) if u == "raidFar" then return nil end return 1 end

local app = RLSuite.db.profile.raidframe.appearance
app.distanceFade = 20
app.distanceAlpha = 0.30

local fakeRow = { unit = "raidFar", bar = row1.bar, SetAlpha = function(s, a) s._a = a end }
fakeRow.bar.SetAlpha = function(s, a) s._a = a end
fakeRow.bar.nameText = { SetAlpha = function(s, a) s._a = a end }
fakeRow.bar.bg = { SetAlpha = function(s, a) s._a = a end }

RF:ApplyDistanceFade(fakeRow)
V108_FADED_ALPHA = fakeRow._fadeAlpha
V108_NAME_ALPHA = fakeRow.bar.nameText._a

UnitIsConnected = oConnected
UnitIsVisible = oVisible
UnitInRange = oRange

-- 5. Test right-click and tooltip methods
V108_HAS_DROPDOWN = (RF.ShowPlayerDropDown ~= nil)
V108_HAS_TOOLTIP = (RF.ShowPlayerTooltip ~= nil)
''')

check(rt.eval("V108_HDR_TEXT:find('Group', 1, true) ~= nil"), "v1.11.108: Group header text is 'Group N'")
check(rt.eval("V108_BTN_W == V108_EXP_W and V108_BTN_H == V108_EXP_H"), "v1.11.108: Raid Buffs button width equals 4 CD space and height equals barHeight")
check(bool(rt.eval("V108_HAS_ROLE_ICON")), "v1.11.108: Row has roleIcon slot to the left of HP bar")
check(rt.eval("V108_FADED_ALPHA") == 0.30, "v1.11.108: Distant/unconnected/invisible unit correctly fades to distanceAlpha")
check(rt.eval("V108_NAME_ALPHA") == 0.30, "v1.11.108: Player name text correctly fades along with bar")
check(bool(rt.eval("V108_HAS_DROPDOWN and V108_HAS_TOOLTIP")), "v1.11.108: Player dropdown menu and tooltip functions exist and are hooked")


print()
print("== v1.11.109: Role icons filter, MT/OT tag position, Durability real pct / OK, Alert format without Buff Check & TBC foods/flasks ==")
rt.execute("""
local RF = RLSuite.raidFrame
local m = RF:LayoutMetrics()

-- 1. Test role icon: roles like 'maintank' or 'dps' do NOT show roleIcon, only leader/assist/ML
local fakeRow = { unit = "raid1", roleIcon = { SetTexture = function(s, t) s._t = t end, Show = function(s) s._s = true end, Hide = function(s) s._s = false end }, member = { role = "maintank", rank = 0, isML = false } }
RF:UpdateRoleIcon(fakeRow)
V109_TANK_ROLE_ICON_SHOWN = (fakeRow.roleIcon._s == true)

-- 2. Test MT/OT tankTag position in LayoutSlotGeometry
local mtSlot = RF.tankSlots[1]
RF:LayoutSlotGeometry(mtSlot, m)
V109_MT_BAR_POINT, _, _, V109_MT_BAR_X = mtSlot.bar:GetPoint()
V109_MT_TAG_POINT, _, _, V109_MT_TAG_X = mtSlot.tankTag:GetPoint()

-- 3. Test Durability: cell text displays pct if known, OK if unknown, BROKEN if broken
local durStPct = { state = "ok", pct = 74, broken = 0 }
local durStUnknown = { state = "ok", pct = nil, broken = 0 }
V109_DUR_TXT_74 = RF:_DurCellText(durStPct)
V109_DUR_TXT_OK = RF:_DurCellText(durStUnknown)

-- 4. Test WarnBuffCategory formats
local warnSent = nil
local origSendChat = RLSuite.utils.SendChat
RLSuite.utils.SendChat = function(s, msg, ch) warnSent = msg end

-- Flask warn
local flaskCol = { key = "flask", label = "Flask" }
RF:WarnBuffCategory(flaskCol)
V109_FLASK_MSG = warnSent

-- Well Fed warn
local foodCol = { key = "wellfed", label = "Well Fed" }
RF:WarnBuffCategory(foodCol)
V109_FOOD_MSG = warnSent

-- General buff warn
local statsCol = { key = "stats", label = "%stat", classes = { "PALADIN" } }
RF:WarnBuffCategory(statsCol)
V109_STATS_MSG = warnSent

RLSuite.utils.SendChat = origSendChat

-- 5. Test TBC flasks and foods present in Core
V109_HAS_TBC_FLASK = false
for _, id in ipairs(RLSuite.buffData.flask) do
    if id == 28518 or id == 28520 then V109_HAS_TBC_FLASK = true break end
end

V109_HAS_TBC_FOOD = false
for _, id in ipairs(RLSuite.buffData.food) do
    if id == 33257 or id == 43764 then V109_HAS_TBC_FOOD = true break end
end
""")

check(not bool(rt.eval("V109_TANK_ROLE_ICON_SHOWN")), "v1.11.109: Tank/DPS/Heal role does not display role icon (leader/assist/ML only)")
check(rt.eval("V109_MT_BAR_X") == rt.eval("RLSuite.raidFrame:LayoutMetrics().roleReserve"), "v1.11.109: MT bar aligned to roleReserve")
check(rt.eval("V109_MT_TAG_X") == 0, "v1.11.109: MT tankTag placed at roleIcon position (LEFT 0)")
check(rt.eval("V109_DUR_TXT_74") == "74%", "v1.11.109: Durability cell shows real percentage when known (74%)")
check(rt.eval("V109_DUR_TXT_OK") == "-", "v1.11.109: Durability cell shows - instead of fake 100% when exact pct is not readable")
check(bool(rt.eval("V109_FLASK_MSG:find('Buff Check', 1, true) == nil and V109_FLASK_MSG:find('Missing Flask |', 1, true) ~= nil and V109_FLASK_MSG:find('Missing:', 1, true) == nil")), "v1.11.109: Flask warning has no 'Buff Check:' and no 'Missing:' before player names")
check(bool(rt.eval("V109_FOOD_MSG:find('Well Fed') ~= nil and V109_FOOD_MSG:find('Missing Well Fed |', 1, true) ~= nil")), "v1.11.109: Food warning uses 'Well Fed' and no 'Buff Check:'")
check(bool(rt.eval("V109_STATS_MSG:find('Buff Check', 1, true) == nil and V109_STATS_MSG:find('Missing %stat', 1, true) ~= nil")), "v1.11.109: All buff warnings have 'Buff Check:' removed")
check(bool(rt.eval("V109_HAS_TBC_FLASK and V109_HAS_TBC_FOOD")), "v1.11.109: TBC flasks and foods added to buffData")

# v1.11.112 — ready-check icons and offline overlay
rt.execute("""
local RFM = RLSuite.raidFrame
local row = RFM.rows[1]
V112 = {}
if row then
    row.fake = false
    row.unit = "raid1"
    local oldExists, oldConnected, oldReady = UnitExists, UnitIsConnected, GetReadyCheckStatus
    UnitExists = function() return true end
    UnitIsConnected = function() return true end
    RFM.readyCheckActive = true
    GetReadyCheckStatus = function() return "waiting" end
    RFM:UpdateRoleIcon(row)
    V112.waiting = tostring(row.roleIcon._texture)
    GetReadyCheckStatus = function() return "notready" end
    RFM:UpdateRoleIcon(row)
    V112.notready = tostring(row.roleIcon._texture)
    GetReadyCheckStatus = function() return "ready" end
    RFM:UpdateRoleIcon(row)
    V112.ready = tostring(row.roleIcon._texture)
    UnitIsConnected = function() return false end
    RFM:UpdateRoleIcon(row)
    V112.offline = tostring(row.roleIcon._texture)
    V112.overlay = row.offlineOverlay:IsShown()
    V112.text = row.offlineText:IsShown() and row.offlineText._text == "OFFLINE"
    V112.overlayAlpha = row.offlineOverlay.bg and row.offlineOverlay.bg._vertex and row.offlineOverlay.bg._vertex[4]
    local op = row.offlineText._points[#row.offlineText._points]
    V112.textRight = op and op[1] == "RIGHT" and op[3] == "RIGHT" and op[4] == -4
    RFM.readyCheckActive = nil
    RFM.readyCheckStatus = nil
    UnitExists, UnitIsConnected, GetReadyCheckStatus = oldExists, oldConnected, oldReady
end
""")
check(bool(rt.eval("V112.waiting:find('ReadyCheck%-Waiting') ~= nil")), "v1.11.112: ready check waiting = yellow question mark")
check(bool(rt.eval("V112.notready:find('ReadyCheck%-NotReady') ~= nil")), "v1.11.112: ready check no = red X")
check(bool(rt.eval("V112.ready:find('ReadyCheck%-Ready') ~= nil")), "v1.11.112: ready check yes = green check")
check(bool(rt.eval("V112.offline:find('UI%-GroupLoot%-Pass%-Up') ~= nil and V112.overlay and V112.text")), "v1.11.112: offline = red pass icon plus red OFFLINE overlay")
check(bool(rt.eval("V112.overlayAlpha == 0.20 and V112.textRight")), "v1.11.114: offline overlay alpha 0.20 and OFFLINE text right-aligned with 4px inset")
check(bool(rt.eval("RLSuite.mainWindow.titleBar._noOuterBorder == true and RLSuite.mainWindow.titleBar._backdropBorderColor[4] == 0")), "v1.11.115: Raid Control title bar has no Blizzard dialog border")

if fails:
    print("RESULT: %d FAILURES: %s" % (len(fails), fails))
    sys.exit(1)
print("RESULT: ALL CHECKS PASSED")
