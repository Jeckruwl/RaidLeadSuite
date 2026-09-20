-- ============================================================
-- RLSuite - LootManager Module
-- ============================================================

RLSuite.lootManager = {}
local LM = RLSuite.lootManager

local L = RLSuite.L or setmetatable({}, { __index = function(_, k) return k end })

-- Listato: le righe hanno un'altezza UNICA calcolata sulla voce che va a
-- capo su piu' righe (il nome dell'item, che fa word-wrap nella colonna).
-- Padding verticale e gap tra le righe come nella versione a riga singola.
local LM_ROW_TOP = 6      -- spazio sopra/sotto il testo dentro la riga
local LM_ROW_GAP = 2      -- spazio tra una riga e l'altra
local LM_ROW_MIN_H = 26   -- altezza minima (una sola riga di testo)

-- Non-overlapping roll/reroll countdowns (AceTimer named timers):
-- restarting a roll cancels the previous timer instead of stacking a
-- second one (which used to double the announcements).
-- AceEvent-3.0 sostituisce il vecchio frame dedicato a CHAT_MSG_SYSTEM
-- (roll di sistema); AceTimer-3.0 sostituisce ticker/pending OnUpdate.
LibStub("AceTimer-3.0"):Embed(LM)
LibStub("AceEvent-3.0"):Embed(LM)

function LM:Init()
    self.db = RLSuite.db.profile.loot
    self.history = self.db.history or {}
    self.db.history = self.history
    self.db.filters = self.db.filters or {}
    self.currentRoll = nil
    self.preMessage = ""
    self:CreateFrame()
    -- Loot da item in borsa (Sack of Frosty Treasures & co.): viene sempre
    -- IGNORATO. Unica provenienza di quel loot e' una loot window aperta
    -- da UseContainerItem: marcata a LOOT_OPENED (entro 2s dall'uso),
    -- smarcata a LOOT_CLOSED. Le loot window dei boss NON seguono mai un
    -- UseContainerItem, quindi il flag non tocca il loot dei boss.
    self._containerUseT = nil
    self._containerLoot = false
    self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
    self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
    hooksecurefunc("UseContainerItem", function()
        LM._containerUseT = GetTime()
    end)
end

function LM:OnLootOpened()
    local t = self._containerUseT
    self._containerLoot = (t ~= nil and (GetTime() - t) < 2) or false
end

function LM:OnLootClosed()
    self._containerLoot = false
    self._containerUseT = nil
end

function LM:Toggle()
    if RLSuite.mainWindow and RLSuite.mainWindow.ShowTab then
        RLSuite.mainWindow:ShowTab("loot")
        return
    end
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    elseif self.frame then
        self.frame:Show()
        self:UpdateHistory()
    end
end

function LM:CreateFrame()
    local f = CreateFrame("Frame", "RLSuiteLootManager", UIParent)
    f:SetSize(500, 500)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
    f:SetFrameStrata("HIGH")
    -- NON trascinabile: il Loot Manager si comporta come una finestra
    -- nativa (pannello equip), posizione fissa decisa da SelectTab.
    f:SetMovable(false)
    f:EnableMouse(true)
    f:Hide()
    f._noOuterBorder = true
    self.frame = f
    RLSuite.utils:SkinFrame(f)
    RLSuite.utils:ClampWindow(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -10)
    title:SetText("Loot Manager")
    self.titleFS = title

    self.preMsgText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.preMsgText:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -32)
    self.preMsgText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -32)
    self.preMsgText:SetJustifyH("LEFT")
    self.preMsgText:SetText("")

    local histLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    histLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -50)
    histLabel:SetText("Loot History")

    local filterFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -152, -54)
    filterFS:SetText("Rarity threshold")

    self.rarityFilter = (self.db and self.db.rarityFilter) or "all"
    self.rarityDropdown = RLSuite.utils:CreateDropdown(f, "RLSuiteLootRarityDD", 130, 20)
    self.rarityDropdown:ClearAllPoints()
    self.rarityDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -50)
    RLSuite.utils:SetupDropdown(self.rarityDropdown, {
        { text = "All", value = "all" },
        { text = "Poor", value = 0 },
        { text = "Common", value = 1 },
        { text = "Uncommon", value = 2 },
        { text = "Rare", value = 3 },
        { text = "Epic", value = 4 },
        { text = "Legendary", value = 5 },
    }, self.rarityFilter, function(value)
        LM.rarityFilter = value
        if LM.db then LM.db.rarityFilter = value end
        LM:UpdateHistory()
    end)

    -- Checkbox "ignore loots": escludono intere categorie sia in cattura
    -- (mai registrate) sia a video (le righe gia' in storico spariscono).
    local ignoreLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ignoreLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -78)
    ignoreLabel:SetText("ignore loots:")
    self.ignoreChecks = {}
    local ignoreDefs = {
        { key = "recipes", label = "recipes" },
        { key = "boe",     label = "BOE" },
        { key = "gems",    label = "gems" },
        { key = "shards",  label = "shards" },
    }
    local ix = 96
    for _, def in ipairs(ignoreDefs) do
        local cb = CreateFrame("CheckButton", "RLSuiteLootIgnore_" .. def.key, f, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", f, "TOPLEFT", ix, -72)
        cb:SetChecked(self.db and self.db.filters and self.db.filters[def.key] and true or false)
        cb:SetScript("OnClick", function(btn)
            if LM.db and LM.db.filters then
                LM.db.filters[def.key] = btn:GetChecked() and true or false
            end
            LM:UpdateHistory()
        end)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        lbl:SetText(def.label)
        self.ignoreChecks[def.key] = cb
        ix = ix + 20 + (#def.label * 7) + 18
    end

    -- Header spostato sotto la riga delle checkbox (-74 -> -100).
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -100)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -100)
    header:SetHeight(18)
    self.histHeader = header
    self:PaintHeader(header)

    self.histBox = CreateFrame("Frame", nil, f)
    self.histBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    self.histBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 78)
    self:SkinBox(self.histBox)

    self.histScroll = CreateFrame("ScrollFrame", "RLSuiteLootHistory", self.histBox, "UIPanelScrollFrameTemplate")
    self.histScroll:SetPoint("TOPLEFT", self.histBox, "TOPLEFT", 6, -6)
    self.histScroll:SetPoint("BOTTOMRIGHT", self.histBox, "BOTTOMRIGHT", -26, 6)

    self.histContent = CreateFrame("Frame", nil, self.histScroll)
    self.histContent:SetWidth(420)
    self.histContent:SetHeight(1)
    self.histScroll:SetScrollChild(self.histContent)
    RLSuite.utils:RegisterScrollClip(self.histScroll, self.histContent)
    self.histScroll:SetScript("OnSizeChanged", function(s, w, h)
        if LM.histContent and w and w > 50 then
            LM.histContent:SetWidth(w)
        end
    end)

    self.selBox = CreateFrame("Frame", nil, f)
    self.selBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 40)
    self.selBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 40)
    self.selBox:SetHeight(34)
    self:SkinBox(self.selBox)

    self.selectedItem = nil
    self.selectedItemIcon = self.selBox:CreateTexture(nil, "ARTWORK")
    self.selectedItemIcon:SetSize(24, 24)
    self.selectedItemIcon:SetPoint("LEFT", self.selBox, "LEFT", 8, 0)
    self.selectedItemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.selectedItemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    self.selectedItemText = self.selBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.selectedItemText:SetPoint("LEFT", self.selectedItemIcon, "RIGHT", 8, 0)
    self.selectedItemText:SetPoint("RIGHT", self.selBox, "RIGHT", -8, 0)
    self.selectedItemText:SetJustifyH("LEFT")
    self.selectedItemText:SetText(L["No item selected"])

    self.rollMSBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.rollMSBtn)
    self.rollMSBtn:SetSize(80, 24)
    self.rollMSBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 10)
    self.rollMSBtn:SetText("Roll MS")
    self.rollMSBtn:SetScript("OnClick", function() self:StartRoll("MS") end)

    self.rollOSBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.rollOSBtn)
    self.rollOSBtn:SetSize(80, 24)
    self.rollOSBtn:SetPoint("LEFT", self.rollMSBtn, "RIGHT", 6, 0)
    self.rollOSBtn:SetText("Roll OS")
    self.rollOSBtn:SetScript("OnClick", function() self:StartRoll("OS") end)

    self.rollOtherBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.rollOtherBtn)
    self.rollOtherBtn:SetSize(80, 24)
    self.rollOtherBtn:SetPoint("LEFT", self.rollOSBtn, "RIGHT", 6, 0)
    self.rollOtherBtn:SetText("Roll FFA")
    self.rollOtherBtn:SetScript("OnClick", function() self:StartRoll("FFA") end)

    self.rerollBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.rerollBtn)
    self.rerollBtn:SetSize(80, 24)
    self.rerollBtn:SetPoint("LEFT", self.rollOtherBtn, "RIGHT", 6, 0)
    self.rerollBtn:SetText("Reroll")
    self.rerollBtn:Disable()
    self.rerollBtn:SetScript("OnClick", function() self:DoReroll() end)

    -- Stesso tasto dell'MS Manager: annuncia le MS changes in raid (e le
    -- pre-pone al messaggio di roll come preMessage). Utile mentre si lootano.
    self.announceMSBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    RLSuite.utils:SkinButton(self.announceMSBtn)
    self.announceMSBtn:SetSize(124, 24)
    self.announceMSBtn:SetPoint("LEFT", self.rerollBtn, "RIGHT", 6, 0)
    self.announceMSBtn:SetText("Announce Changes")
    self.announceMSBtn:SetScript("OnClick", function()
        RLSuite.msManager:GenerateMessage()
    end)

    f.closeBtn = RLSuite.utils:MakeCloseX(f, function() f:Hide() end)
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    self:HookTradePanel()
    self:EnsureTicker()
end

-- Ancoraggio "finestra nativa": normalmente in alto a sinistra (16, -116),
-- ma se il trade e' aperto il Loot Manager cede la sinistra al trade e si
-- sposta SUBITO a destra di esso (come fanno equip/talenti/spellbook con
-- gli altri pannelli Blizzard).
function LM:AnchorDefault()
    if not self.frame then return end
    self.frame:ClearAllPoints()
    local x = 16
    if self.tradeOpen and TradeFrame and TradeFrame.IsShown and TradeFrame:IsShown() then
        x = (TradeFrame.GetRight and TradeFrame:GetRight() or 0) + 10
    end
    if x < 16 then x = 16 end
    self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -116)
end

-- Gancio una tantum al TradeFrame di Blizzard (OnShow/OnHide): il pannello
-- "sa" cosa c'e' aperto e reagisce nell'istante in cui il trade appare
-- ("quando aprono una trade si sposta a destra lasciando il trade a
-- sinistra"). Registrabile anche a runtime se il TradeFrame esiste gia'.
function LM:HookTradePanel()
    if self._tradeHooked then return end
    if not (TradeFrame and TradeFrame.HookScript) then return end
    self._tradeHooked = true
    TradeFrame:HookScript("OnShow", function()
        LM.tradeOpen = true
        LM:AnchorDefault()
    end)
    TradeFrame:HookScript("OnHide", function()
        LM.tradeOpen = false
        LM:AnchorDefault()
    end)
end

function LM:SkinBox(box)
    RLSuite.utils:SkinBox(box)
end

function LM:SkinInner()
    self:SkinBox(self.histBox)
    self:SkinBox(self.selBox)
end

function LM:HistMetrics(w)
    w = tonumber(w) or 420
    local timeW, assignedW, typeW, gap, padR = 64, 72, 48, 6, 8
    local itemX = 58
    local assignedX = w - padR - timeW - gap - assignedW
    local typeX = assignedX - gap - typeW
    local inner = typeX - itemX - gap
    if inner < 120 then inner = 120 end
    local itemW = math.floor(inner * 0.58)
    local bossW = inner - itemW
    local bossX = itemX + itemW + gap
    return {
        itemX = itemX, itemW = itemW,
        bossX = bossX, bossW = bossW,
        typeX = typeX, typeW = typeW,
        assignedX = assignedX, assignedW = assignedW,
        timeW = timeW, padR = padR,
    }
end

function LM:PaintHeader(header)
    self.histHeads = {}
    local function add(key, text)
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetText(text)
        fs:SetTextColor(1, 0.82, 0)
        self.histHeads[key] = fs
        return fs
    end
    add("num", "#"):SetPoint("LEFT", header, "LEFT", 6, 0)
    add("item", "Item")
    add("boss", "Boss")
    add("type", "Type")
    add("assigned", "Assigned")
    local tfs = add("time", "Time left")
    tfs:SetJustifyH("RIGHT")
    self:LayoutHeader()
end

function LM:LayoutHeader()
    local header = self.histHeader
    if not header or not self.histHeads then return end
    local w = header:GetWidth()
    if not w or w < 80 then w = 452 end
    -- Il listato vive dentro lo scroll frame, che rispetto al riquadro
    -- (e quindi all'header) e' rientrato di 6px a sinistra e 26px a
    -- destra (scrollbar). Le intestazioni usano la STESSA larghezza del
    -- contenuto e gli stessi offset delle righe, cosi' colonne e header
    -- restano allineati a qualsiasi dimensione della finestra.
    local insetL, insetR = 6, 26
    local m = self:HistMetrics(w - insetL - insetR)
    local h = self.histHeads
    h.num:ClearAllPoints()
    h.num:SetPoint("LEFT", header, "LEFT", insetL + 6, 0)
    h.item:ClearAllPoints()
    h.item:SetPoint("LEFT", header, "LEFT", insetL + m.itemX, 0)
    h.boss:ClearAllPoints()
    h.boss:SetPoint("LEFT", header, "LEFT", insetL + m.bossX, 0)
    h.type:ClearAllPoints()
    h.type:SetPoint("LEFT", header, "LEFT", insetL + m.typeX, 0)
    h.assigned:ClearAllPoints()
    h.assigned:SetPoint("LEFT", header, "LEFT", insetL + m.assignedX, 0)
    h.time:ClearAllPoints()
    h.time:SetPoint("RIGHT", header, "RIGHT", -(insetR + m.padR), 0)
end

function LM:EnsureTicker()
    if self.remainTicker then return end
    self.remainTicker = self:ScheduleRepeatingTimer("TickRemaining", 1)
end

function LM:TickRemaining()
    for _, rec in ipairs(self.remainTexts or {}) do
        if rec.fs and rec.entry then
            rec.fs:SetText(self:TradeRemaining(rec.entry))
        end
    end
end

function LM:SetPreMessage(msg)
    self.preMessage = msg or ""
    if self.preMsgText then
        self.preMsgText:SetText(msg)
    end
end

-- raidName opzionale: nil = usa il raid selezionato in Groupmaking (debug
-- standard), altrimenti il pool del raid indicato (Debug panel "Fill Loot").
function LM:SpawnDebugLoot(raidName)
    local raid = raidName or (RLSuite.db.profile.groupmaking and RLSuite.db.profile.groupmaking.raid) or "Icecrown Citadel"
    local pool = (RLSuite.debugLoot and RLSuite.debugLoot[raid]) or {49623, 49908, 52025}
    local bosses = (RLSuite.raidDB[raid] and RLSuite.raidDB[raid].bosses) or {"Unknown"}
    local ids = {}
    for _, id in ipairs(pool) do table.insert(ids, id) end
    local n = math.min(6, #ids)
    for i = #ids, 2, -1 do
        local j = math.random(1, i)
        ids[i], ids[j] = ids[j], ids[i]
    end
    for i = 1, n do
        local id = ids[i]
        local itemName, itemLink, quality, _, _, _, _, _, _, itemTexture = GetItemInfo(id)
        if not itemLink then
            itemLink = "|cffff8000|Hitem:" .. id .. ":0:0:0:0:0:0:0:80|h[Debug Item " .. id .. "]|h|r"
            itemName = "Debug Item " .. id
            itemTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
            quality = 5
        end
        local boss = bosses[((i - 1) % #bosses) + 1] or "Unknown"
        table.insert(self.history, {
            id = #self.history + 1,
            itemLink = itemLink,
            itemName = itemName,
            itemTexture = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark",
            boss = "[DBG] " .. boss,
            itemType = self:DetectItemType(itemLink, itemName),
            quality = quality or 4,
            time = time(),
            assignedTo = nil,
        })
    end
    self:UpdateHistory()
    RLSuite.utils:Print(string.format(L["Loot debug: %d items from %s"], n, raid))
end

function LM:OnLootMessage(msg)
    if self._containerLoot then return end -- loot da item in borsa: MAI tracciato
    local itemLink = RLSuite.utils:GetItemLinkFromChat(msg or "")
    if not itemLink then return end
    local itemName, _, quality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
    if itemName then
        self:AddToHistory(itemLink, itemName, itemTexture, quality)
    else
        self:QueuePendingLoot(itemLink)
    end
end

function LM:QueuePendingLoot(itemLink)
    self.pendingLoot = self.pendingLoot or {}
    table.insert(self.pendingLoot, {link = itemLink, tries = 0})
    if self.pendingTimer then return end
    self.pendingTimer = self:ScheduleRepeatingTimer("ProcessPendingLoot", 0.25)
end

function LM:ProcessPendingLoot()
    local pending = self.pendingLoot or {}
    if #pending == 0 then
        if self.pendingTimer then
            self:CancelTimer(self.pendingTimer)
            self.pendingTimer = nil
        end
        return
    end
    for i = #pending, 1, -1 do
        local p = pending[i]
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        pcall(function() GameTooltip:SetHyperlink(p.link) end)
        GameTooltip:Hide()
        local itemName, _, quality, _, _, _, _, _, _, itemTexture = GetItemInfo(p.link)
        if itemName then
            self:AddToHistory(p.link, itemName, itemTexture, quality)
            table.remove(pending, i)
        else
            p.tries = (p.tries or 0) + 1
            if p.tries > 20 then
                self:AddToHistory(p.link, "Unknown Item", "Interface\\Icons\\INV_Misc_QuestionMark")
                table.remove(pending, i)
            end
        end
    end
end

-- Emblemi WotLK: MAI tracciati (regola fissa, senza checkbox).
local LM_EMBLEM_IDS = { [40752] = true, [40753] = true, [45624] = true, [47241] = true, [49426] = true }
-- Shard da incantamento: Dream Shard / Small Dream Shard / Abyss Crystal
-- (WotLK) + i corrispettivi TBC e vanilla.
local LM_SHARD_IDS = {
    [34052] = true, [34053] = true, [34057] = true,
    [22448] = true, [22449] = true, [22450] = true, [20725] = true,
    [14343] = true, [14344] = true,
}
local LM_GEM_CLASSES = { Gem = true, Gemma = true }
local LM_RECIPE_CLASSES = { Recipe = true, Ricetta = true }

-- BOE detection: la riga di vincolo nel tooltip usa la globale localizzata
-- ITEM_BIND_ON_EQUIP (e ITEM_BIND_ON_PICKUP per i BoP, che chiude il giro).
function LM:IsBindOnEquip(itemLink)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    pcall(function() GameTooltip:SetHyperlink(itemLink) end)
    local lines = (GameTooltip.NumLines and GameTooltip:NumLines()) or 0
    for i = 2, lines do
        local fs = _G["GameTooltipTextLeft" .. i]
        local txt = fs and fs.GetText and fs:GetText()
        if txt and txt == ITEM_BIND_ON_PICKUP then
            GameTooltip:Hide()
            return false
        end
        if txt and txt == ITEM_BIND_ON_EQUIP then
            GameTooltip:Hide()
            return true
        end
    end
    GameTooltip:Hide()
    return false
end

-- Categoria speciale del pezzo (governano le checkbox "ignore loots" e
-- l'esclusione fissa degli emblemi). nil = loot normale.
function LM:LootCategory(itemLink, itemName)
    if not itemLink then return nil end
    local id = tonumber(string.match(itemLink, "Hitem:(%d+)"))
    if id then
        if LM_EMBLEM_IDS[id] then return "EMBLEM" end
        if LM_SHARD_IDS[id] then return "SHARD" end
    end
    local itemClass = select(6, GetItemInfo(itemLink))
    if itemClass then
        if LM_GEM_CLASSES[itemClass] then return "GEM" end
        if LM_RECIPE_CLASSES[itemClass] then return "RECIPE" end
    end
    if self:DetectItemType(itemLink, itemName) == "PATTERN" then
        return "RECIPE"
    end
    if self:IsBindOnEquip(itemLink) then
        return "BOE"
    end
    return nil
end

function LM:EntryCategory(entry)
    if entry._cat == nil then
        entry._cat = self:LootCategory(entry.itemLink, entry.itemName) or false
    end
    if entry._cat == false then return nil end
    return entry._cat
end

-- Le categorie attive nelle checkbox "ignore loots" (e gli emblemi, sempre):
-- usato sia in cattura (AddToHistory) sia a video (MatchesFilter).
function LM:IsCategoryIgnored(cat)
    if cat == nil then return false end
    if cat == "EMBLEM" then return true end
    local f = (self.db and self.db.filters) or {}
    if cat == "RECIPE" then return f.recipes == true end
    if cat == "BOE" then return f.boe == true end
    if cat == "GEM" then return f.gems == true end
    if cat == "SHARD" then return f.shards == true end
    return false
end

function LM:AddToHistory(itemLink, itemName, itemTexture, quality)
    -- Filtro in cattura: categorie ignorate MAI registrate.
    if self:IsCategoryIgnored(self:LootCategory(itemLink, itemName)) then return end
    if quality == nil and itemLink then
        local _, _, q = GetItemInfo(itemLink)
        quality = q
    end
    local entry = {
        id = #self.history + 1,
        itemLink = itemLink,
        itemName = itemName,
        itemTexture = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark",
        boss = "Unknown",
        itemType = self:DetectItemType(itemLink, itemName),
        quality = quality,
        time = time(),
        assignedTo = nil,
    }
    table.insert(self.history, entry)
    self:UpdateHistory()
end

function LM:DetectItemType(itemLink, itemName)
    local lower = string.lower(itemName or itemLink or "")
    if string.find(lower, "pattern") or string.find(lower, "formula") or string.find(lower, "schematic") or string.find(lower, "design") then
        return "PATTERN"
    end
    if string.find(lower, "primordial saronite") or string.find(lower, "orb") then
        return "ORB"
    end
    if string.find(lower, "token") or string.find(lower, "conqueror") or string.find(lower, "protector") or string.find(lower, "vanquisher") or string.find(lower, "regalia") then
        return "TOKEN"
    end
    return "BOP"
end

function LM:EntryQuality(entry)
    if not entry then return -1 end
    if entry.quality ~= nil then return entry.quality end
    if entry.itemLink then
        local _, _, q = GetItemInfo(entry.itemLink)
        if q ~= nil then
            entry.quality = q
            return q
        end
    end
    return -1
end

function LM:MatchesFilter(entry)
    local f = self.rarityFilter
    if self.db and self.db.rarityFilter ~= nil then
        f = self.db.rarityFilter
    end
    if self:IsCategoryIgnored(self:EntryCategory(entry)) then return false end
    if f == nil or f == "all" then return true end
    local q = self:EntryQuality(entry)
    return q >= tonumber(f)
end

function LM:TradeRemaining(entry)
    local start = (entry and entry.time) or 0
    local window = (self.db and self.db.tradeWindow) or 7200
    local left = window - (time() - start)
    if left <= 0 then return "Expired" end
    local h = math.floor(left / 3600)
    local m = math.floor((left % 3600) / 60)
    local s = left % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

function LM:UpdateHistory()
    if not self.histContent then return end
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    self:SkinBox(self.histBox)
    self:SkinBox(self.selBox)
    for _, child in ipairs(self.histRows or {}) do
        child:Hide()
        child:SetParent(nil)
    end
    self.histRows = {}
    self.remainTexts = {}

    local w = self.histContent:GetWidth() or 420
    if self.histScroll then
        local sw = self.histScroll:GetWidth()
        if sw and sw > 50 then
            w = sw
            self.histContent:SetWidth(w)
        end
    end

    local m = self:HistMetrics(w)
    self:LayoutHeader()

    -- Pass 1: costruisce le righe e misura quante righe di testo servono
    -- al nome dell'item (che fa word-wrap nella sua colonna). Il numero
    -- massimo di righe definisce l'altezza UNICA di tutte le righe.
    local lineH = nil
    local maxLines = 1
    local y = 0
    for i = #self.history, 1, -1 do
        local entry = self.history[i]
        if self:MatchesFilter(entry) then
            local row = CreateFrame("Button", nil, self.histContent)
            self.histRows[#self.histRows + 1] = row
            row:EnableMouse(true)
            row:RegisterForClicks("LeftButtonUp")
            row.entry = entry
            RLSuite.utils:SkinRow(row, self.selectedItem == entry)

            local num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            num:SetWidth(28)
            num:SetJustifyH("LEFT")
            num:SetText("#" .. (entry.id or 0))
            if not lineH then
                lineH = num:GetStringHeight() or 14
            end

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetTexture(entry.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            name:SetWidth(m.itemW)
            name:SetWordWrap(true)
            name:SetJustifyH("LEFT")
            name:SetJustifyV("TOP")
            name:SetText(entry.itemName or "Unknown")
            local q = self:EntryQuality(entry)
            if GetItemQualityColor and q and q >= 0 then
                local r, g, b = GetItemQualityColor(q)
                name:SetTextColor(r or 1, g or 1, b or 1)
            end
            -- righe occupate dal nome con wrap (minimo una)
            local lines = math.max(1, math.ceil((name:GetStringHeight() or lineH) / lineH))
            row._lines = lines
            if lines > maxLines then maxLines = lines end
            row.name = name

            local boss = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            boss:SetWidth(m.bossW)
            boss:SetJustifyH("LEFT")
            boss:SetText(entry.boss or "Unknown")

            local itype = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            itype:SetWidth(m.typeW)
            itype:SetJustifyH("LEFT")
            itype:SetText(entry.itemType or "BOP")

            local remain = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            remain:SetWidth(m.timeW)
            remain:SetJustifyH("RIGHT")
            remain:SetText(self:TradeRemaining(entry))

            local assigned = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            assigned:SetWidth(m.assignedW)
            assigned:SetJustifyH("LEFT")
            assigned:SetText(entry.assignedTo or "-")
            table.insert(self.remainTexts, { fs = remain, entry = entry })

            -- Pezzo gia' rollato e vinto: riga ingrigita nel listato (il
            -- vincitore resta in oro, l'icona desaturata). Visibile ma
            -- chiaramente "chiuso": il prossimo pezzo da rollare salta
            -- all'occhio.
            if entry.assignedTo then
                local GR = 0.45
                num:SetTextColor(GR, GR, GR, 1)
                name:SetTextColor(GR, GR, GR, 1)
                boss:SetTextColor(GR, GR, GR, 1)
                itype:SetTextColor(GR, GR, GR, 1)
                remain:SetTextColor(GR, GR, GR, 1)
                assigned:SetTextColor(1, 0.82, 0, 1) -- chi ha vinto, in oro
                if icon.SetDesaturated then icon:SetDesaturated(true) end
            end

            -- riferimenti ai figli per il secondo passaggio (posizionamento)
            row.num = num
            row.icon = icon
            row.name = name
            row.boss = boss
            row.itype = itype
            row.remain = remain
            row.assigned = assigned

            row:SetScript("OnClick", function()
                self:SelectItem(entry)
                self:RefreshHistoryHighlight()
            end)
            row:SetScript("OnEnter", function(s)
                if entry.itemLink then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    pcall(function() GameTooltip:SetHyperlink(entry.itemLink) end)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end

    if not lineH then lineH = 14 end

    -- Pass 2: altezza unica per tutte le righe (quella della voce piu' alta)
    -- e posizionamento verticale con contenuto allineato in alto.
    local rowH = math.max(LM_ROW_MIN_H, 2 * LM_ROW_TOP + maxLines * lineH)
    RLSuite.utils:ClearScrollClip(self.histContent)
    y = 0
    for _, row in ipairs(self.histRows) do
        row:SetHeight(rowH)
        row:SetPoint("TOPLEFT", self.histContent, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", self.histContent, "TOPRIGHT", 0, -y)
        RLSuite.utils:ClipScrollRow(self.histContent, row, y, rowH)

        -- Riposiziona i figli (num, icon, name, boss, itype, remain,
        -- assigned) allineandoli in alto, dentro la riga.
        if row.num then row.num:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -LM_ROW_TOP) end
        if row.icon then row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -LM_ROW_TOP) end
        if row.name then
            row.name:SetPoint("TOPLEFT", row, "TOPLEFT", m.itemX, -LM_ROW_TOP)
            row.name:SetHeight((row._lines or 1) * lineH)
        end
        if row.boss then row.boss:SetPoint("TOPLEFT", row, "TOPLEFT", m.bossX, -LM_ROW_TOP) end
        if row.itype then row.itype:SetPoint("TOPLEFT", row, "TOPLEFT", m.typeX, -LM_ROW_TOP) end
        if row.remain then row.remain:SetPoint("TOPRIGHT", row, "TOPRIGHT", -m.padR, -LM_ROW_TOP) end
        if row.assigned then row.assigned:SetPoint("TOPLEFT", row, "TOPLEFT", m.assignedX, -LM_ROW_TOP) end

        y = y + rowH + LM_ROW_GAP
    end
    self.histContent:SetHeight(math.max(y, 1))
    RLSuite.utils:RefreshScrollClip(self.histContent)
    self:EnsureTicker()
end

function LM:SelectItem(entry)
    self.selectedItem = entry
    if self.selectedItemIcon then
        self.selectedItemIcon:SetTexture(entry.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    if self.selectedItemText then
        self.selectedItemText:SetText(entry.itemName or "Unknown")
    end
end

-- Svuota la riga "selected item": chiamata dopo ogni vincita, cosi' le
-- finestre pickup aperte non bloccano la preparazione del roll seguente.
function LM:ClearSelection()
    self.selectedItem = nil
    if self.selectedItemIcon then
        self.selectedItemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    if self.selectedItemText then
        self.selectedItemText:SetText(L["No item selected"])
    end
end

-- Highlights the selected row without rebuilding the list (see notes on
-- RefreshWhisperHighlight: rebuilding inside the click breaks future clicks).
function LM:RefreshHistoryHighlight()
    for _, row in ipairs(self.histRows or {}) do
        if row and row.SetBackdrop then
            RLSuite.utils:SkinRow(row, self.selectedItem == row.entry)
        end
    end
end

function LM:StartRoll(rollType)
    if not self.selectedItem then
        RLSuite.utils:Print(L["Select an item from the history first!"])
        return
    end

    self.currentRoll = {
        item = self.selectedItem,
        type = rollType,
        rolls = {},
        timer = self.db.rollDuration or 10,
        active = true,
    }

    local typeNames = { MS = "MS", OS = "OS", FFA = "Free For All", OTHER = "Free For All" }
    local msg = "Roll " .. (typeNames[rollType] or rollType or "MS") .. " for " .. (self.selectedItem.itemName or "Unknown")
    if self.preMessage and self.preMessage ~= "" then
        msg = self.preMessage .. " " .. msg
    end
    -- I messaggi dei tasti di roll vanno in RAID WARNING
    -- (Utils:SendChat torna a RAID se non leader/assistant).
    RLSuite.utils:SendChat(msg, "RAID_WARNING")
    -- barra-timer in DBM/BigWigs se installati (durata del roll)
    RLSuite.utils:StartDbmTimer(self.db.rollDuration or 10, "Roll " .. (self.selectedItem.itemName or "Unknown"),
        self.selectedItem.itemTexture)

    if RLSuite.DebugMode and RLSuite:DebugMode() then
        local me = UnitName("player") or "You"
        local names = {me, "Tankbot", "Healbot", "Dpsbot", "Huntbot"}
        local template = self:GetRollTemplate()
        for _, n in ipairs(names) do
            if math.random(1, 10) > 2 then
                self:OnSystemRoll(string.format(template, n, math.random(1, 100), 1, 100))
            end
        end
    end

    if self.rollMSBtn then self.rollMSBtn:Disable() end
    if self.rollOSBtn then self.rollOSBtn:Disable() end
    if self.rollOtherBtn then self.rollOtherBtn:Disable() end

    -- Non-overlapping: cancel any previous roll/reroll countdown.
    self:CancelRollTimers()
    self.rollRemaining = self.currentRoll.timer
    self.rollTimer = self:ScheduleRepeatingTimer("RollTick", 1)

    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemRollMessage")
end

function LM:OnSystemRollMessage(event, msg)
    self:OnSystemRoll(msg)
end

-- Cancels the running roll and reroll countdown timers, if any.
function LM:CancelRollTimers()
    if self.rollTimer then
        self:CancelTimer(self.rollTimer, true)
        self.rollTimer = nil
    end
    if self.rerollTimer then
        self:CancelTimer(self.rerollTimer, true)
        self.rerollTimer = nil
    end
end

function LM:RollTick()
    self.rollRemaining = (self.rollRemaining or 0) - 1
    if self.rollRemaining <= 0 then
        if self.rollTimer then
            self:CancelTimer(self.rollTimer, true)
            self.rollTimer = nil
        end
        self:AnnounceWinner()
        return
    end
    if self.rollRemaining <= 3 then
        RLSuite.utils:SendChat("Roll ending in " .. self.rollRemaining .. "...", "RAID")
    end
end

-- Localized roll template, e.g. "%s rolls %d (%d-%d)" on enUS.
function LM:GetRollTemplate()
    return RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
end

-- Builds a Lua pattern from the localized RANDOM_ROLL_RESULT template so
-- system roll messages are parsed on any client locale (enUS "Name rolls 42
-- (1-100)", itIT "Name tira 42 (1-100)", deDE "Name wuerfelt 42 (1-100)",
-- etc.) instead of matching English-only wording.
function LM:GetRollPattern()
    if self._rollPattern then return self._rollPattern end
    local t = self:GetRollTemplate()
    -- Mark the substitution tokens so the remaining text can be escaped.
    t = string.gsub(t, "%%s", "\001NAME\001")
    t = string.gsub(t, "%%d", "\001NUM\001")
    -- Escape Lua pattern magic characters in the literal text.
    t = string.gsub(t, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    -- Restore capture groups.
    t = string.gsub(t, "\001NAME\001", "(.+)")
    t = string.gsub(t, "\001NUM\001", "(%%d+)")
    self._rollPattern = t
    return t
end

function LM:OnSystemRoll(msg)
    if not self.currentRoll or not self.currentRoll.active then return end
    local name, roll, _, maxRoll = string.match(msg or "", self:GetRollPattern())
    if name and roll and maxRoll == "100" then
        table.insert(self.currentRoll.rolls, {name = name, roll = tonumber(roll)})
    end
end

function LM:AnnounceWinner()
    if not self.currentRoll then return end
    self.currentRoll.active = false

    if #self.currentRoll.rolls == 0 then
        RLSuite.utils:SendChat("No rolls received for " .. (self.currentRoll.item.itemName or "Unknown"), "RAID")
        self:ResetButtons()
        self:UnregisterEvent("CHAT_MSG_SYSTEM")
        return
    end

    table.sort(self.currentRoll.rolls, function(a, b) return a.roll > b.roll end)
    local winner = self.currentRoll.rolls[1]
    local winners = {winner}

    for i = 2, #self.currentRoll.rolls do
        if self.currentRoll.rolls[i].roll == winner.roll then
            table.insert(winners, self.currentRoll.rolls[i])
        else
            break
        end
    end

    if #winners > 1 then
        self.currentRoll.rerollWinners = winners
        if self.rerollBtn then self.rerollBtn:Enable() end
        local names = {}
        for _, w in ipairs(winners) do table.insert(names, w.name or "?") end
        RLSuite.utils:SendChat("Tie! Reroll between: " .. table.concat(names, ", "), "RAID")
    else
        RLSuite.utils:SendChat((winner.name or "?") .. " wins " .. (self.currentRoll.item.itemName or "Unknown") .. " with " .. (winner.roll or 0) .. "! Please trade.", "RAID")
        self.currentRoll.item.assignedTo = winner.name
        self:ShowTradeWindow(self.currentRoll.item)
        -- La riga "selected item" torna vuota: con la finestra pickup aperta
        -- si puo' subito selezionare e rollare un altro pezzo.
        self:ClearSelection()
        self:UpdateHistory()
    end

    self:ResetButtons()
    self:UnregisterEvent("CHAT_MSG_SYSTEM")
end

function LM:DoReroll()
    if not self.currentRoll or not self.currentRoll.rerollWinners then return end

    local winners = self.currentRoll.rerollWinners
    local names = {}
    for _, w in ipairs(winners) do table.insert(names, w.name or "?") end

    RLSuite.utils:SendChat("Reroll! Only " .. table.concat(names, ", ") .. " can roll for " .. (self.currentRoll.item.itemName or "Unknown"), "RAID_WARNING")
    -- barra-timer in DBM/BigWigs se installati (durata del reroll)
    RLSuite.utils:StartDbmTimer(self.db.rerollDuration or 5, "Reroll " .. (self.currentRoll.item.itemName or "Unknown"),
        self.currentRoll.item.itemTexture)

    self.currentRoll.rolls = {}
    self.currentRoll.active = true
    if self.rerollBtn then self.rerollBtn:Disable() end

    -- In debug i fittizi rerollano anche loro (come nello StartRoll),
    -- altrimenti il pareggio di test si fermava a "No valid rerolls!".
    if RLSuite.DebugMode and RLSuite:DebugMode() then
        local template = self:GetRollTemplate()
        -- a differenza dello StartRoll (80% di presenza), nel reroll TUTTI
        -- i pareggiati fittizi rispondono: il pareggio si risolve sempre.
        for _, w in ipairs(winners) do
            self:OnSystemRoll(string.format(template, w.name, math.random(1, 100), 1, 100))
        end
    end

    -- Non-overlapping: cancel any previous reroll/roll countdown.
    self:CancelRollTimers()
    self.rerollRemaining = self.db.rerollDuration or 5
    self.rerollTimer = self:ScheduleRepeatingTimer("RerollTick", 1)
end

function LM:RerollTick()
    self.rerollRemaining = (self.rerollRemaining or 0) - 1
    if self.rerollRemaining <= 0 then
        if self.rerollTimer then
            self:CancelTimer(self.rerollTimer, true)
            self.rerollTimer = nil
        end
        self:ProcessReroll()
    end
end

function LM:ProcessReroll()
    if not self.currentRoll then return end
    self.currentRoll.active = false

    local validRolls = {}
    for _, roll in ipairs(self.currentRoll.rolls) do
        for _, w in ipairs(self.currentRoll.rerollWinners) do
            if roll.name == w.name then
                table.insert(validRolls, roll)
                break
            end
        end
    end

    if #validRolls == 0 then
        RLSuite.utils:SendChat("No valid rerolls!", "RAID")
        return
    end

    table.sort(validRolls, function(a, b) return a.roll > b.roll end)
    local winner = validRolls[1]
    RLSuite.utils:SendChat((winner.name or "?") .. " wins the reroll for " .. (self.currentRoll.item.itemName or "Unknown") .. " with " .. (winner.roll or 0) .. "! Please trade.", "RAID")
    self.currentRoll.item.assignedTo = winner.name
    self:ShowTradeWindow(self.currentRoll.item)
    self:ClearSelection()
    self:UpdateHistory()
end

function LM:ResetButtons()
    if self.rollMSBtn then self.rollMSBtn:Enable() end
    if self.rollOSBtn then self.rollOSBtn:Enable() end
    if self.rollOtherBtn then self.rollOtherBtn:Enable() end
    if self.rerollBtn then
        -- MAI disabilitare un reroll pendente: in caso di pareggio il
        -- ResetButtons() finale di AnnounceWinner cancellava subito il
        -- tasto appena abilitato (il bug "pari e il reroll non parte").
        local pending = self.currentRoll and self.currentRoll.rerollWinners
        if pending and #pending > 1 then
            self.rerollBtn:Enable()
        else
            self.rerollBtn:Disable()
        end
    end
end

-- Finestre "click to pick up": si IMPILANO una sotto l'altra (mai
-- sovrapposte) partendo dal centro-alto dello schermo. Ogni finestra e'
-- alta quanto l'icona del pezzo (+padding) e il testo sta a DESTRA
-- dell'icona cliccabile. tradeWindows tiene traccia delle finestre aperte
-- cosi' chiudendone una le altre risalgo a riempire il buco.
local LM_TRADE_ICON = 32     -- lato dell'icona cliccabile
local LM_TRADE_PAD = 6       -- padding sopra/sotto l'icona
local LM_TRADE_GAP = 6       -- spazio verticale tra una finestra e l'altra

function LM:ShowTradeWindow(item)
    if not item then return end
    self.tradeWindows = self.tradeWindows or {}
    -- nome globale univoco (le finestre possono convivere, una per vincita)
    local n = #self.tradeWindows + 1
    local name = "RLSuiteTradeWindow" .. n
    while _G[name] do
        n = n + 1
        name = "RLSuiteTradeWindow" .. n
    end

    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(230, LM_TRADE_ICON + 2 * LM_TRADE_PAD)
    f:SetFrameStrata("DIALOG")
    RLSuite.utils:SkinFrame(f)
    -- Il frame NON cattura MAI i click (passano alla lista loot dietro):
    -- catturano solo l'icona cliccabile e la X di chiusura.
    f:EnableMouse(false)
    table.insert(self.tradeWindows, f)

    -- icona cliccabile a sinistra, alta quanto la finestra
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(LM_TRADE_ICON, LM_TRADE_ICON)
    icon:SetPoint("LEFT", f, "LEFT", LM_TRADE_PAD + 2, 0)
    icon:SetTexture(item.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.icon = icon

    -- "Click to pick up item" a DESTRA dell'icona; sotto, la riga
    -- "give to: <nome del vincitore>" che indica a chi va consegnato.
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", icon, "RIGHT", 8, 7)
    text:SetPoint("RIGHT", f, "RIGHT", -34, 0) -- lascia spazio alla X
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetText("Click to pick up item")
    f.text = text

    local giveTo = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    giveTo:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
    giveTo:SetPoint("RIGHT", text, "RIGHT", 0, 0)
    giveTo:SetJustifyH("LEFT")
    giveTo:SetText("give to: " .. (item.assignedTo or "?"))
    giveTo:SetTextColor(1, 0.82, 0) -- oro, in evidenza
    f.giveTo = giveTo

    local btn = CreateFrame("Button", nil, f)
    btn:SetAllPoints(icon)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    f.pickBtn = btn
    btn:SetScript("OnClick", function()
        if TradeFrame and TradeFrame:IsShown() then
            if item.itemLink then
                PickupItem(item.itemLink)
            end
            ClickTradeButton(1)
            self:CloseTradeWindow(f)
        else
            -- NIENTE pickup senza trade aperto: un item sul cursore trasforma
            -- OGNI click dell'interfaccia in un'azione del cursore e la lista
            -- loot smette di rispondere (il bug "finestra pickup = lista
            -- bloccata"). Il pezzo si prende solo quando il trade e' aperto.
            RLSuite.utils:Print(L["Open the trade with the winner first, then click the item icon."])
        end
    end)

    f.closeBtn = RLSuite.utils:MakeCloseX(f, function() self:CloseTradeWindow(f) end)
    f.closeBtn:SetPoint("RIGHT", f, "RIGHT", 0, 0)

    self:StackTradeWindows()
end

-- Chiude una finestra di pickup e risistema la pila (le altre risalgono).
function LM:CloseTradeWindow(f)
    if not f then return end
    if f.Hide then f:Hide() end
    for i, w in ipairs(self.tradeWindows or {}) do
        if w == f then
            table.remove(self.tradeWindows, i)
            break
        end
    end
    self:StackTradeWindows()
end

function LM:CloseAllTradeWindows()
    for _, w in ipairs(self.tradeWindows or {}) do
        if w and w.Hide then w:Hide() end
    end
    self.tradeWindows = {}
end

-- Impila le finestre aperte UNA SOTTO L'ALTRA, affiancate alla finestra
-- del Loot Manager (lato con piu' spazio libero: destra o sinistra).
-- MAI piu' al centro dello schermo: stavano SOPRA il listato e, dopo un
-- paio di roll, i loro bottoni catturavano i click destinati alle righe
-- (il bug "dopo due roll non clicco piu' i pezzi"). Solo se la finestra
-- del Loot Manager non e' visibile ripiombano al centro-alto, come prima.
function LM:StackTradeWindows()
    local prev = nil
    for _, w in ipairs(self.tradeWindows or {}) do
        if w and w.IsShown and w:IsShown() then
            w:ClearAllPoints()
            if prev then
                w:SetPoint("TOP", prev, "BOTTOM", 0, -LM_TRADE_GAP)
            else
                local lm = self.frame
                if lm and lm.IsShown and lm:IsShown() then
                    local left = (lm.GetLeft and lm:GetLeft()) or 0
                    local sw = (GetScreenWidth and GetScreenWidth()) or 1024
                    if left < sw / 2 then
                        w:SetPoint("TOPLEFT", lm, "TOPRIGHT", 8, 0)
                    else
                        w:SetPoint("TOPRIGHT", lm, "TOPLEFT", -8, 0)
                    end
                else
                    w:SetPoint("TOP", UIParent, "TOP", 0, -80)
                end
            end
            prev = w
        end
    end
end

-- Svuota il Loot Manager: uscendo dalla debug mode lo storico (loot finto),
-- il roll in corso e le finestre pickup non devono sopravvivere.
function LM:ClearHistory()
    if self.db and self.db.history then
        for k in pairs(self.db.history) do self.db.history[k] = nil end
    end
    self.history = (self.db and self.db.history) or {}
    self.selectedItem = nil
    self:CancelRollTimers()
    if self.UnregisterEvent then
        self:UnregisterEvent("CHAT_MSG_SYSTEM")
    end
    self.currentRoll = nil
    self:CloseAllTradeWindows()
    if self.selectedItemIcon then
        self.selectedItemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    if self.selectedItemText then
        self.selectedItemText:SetText(L["No item selected"])
    end
    self:ResetButtons()
    self:UpdateHistory()
end
