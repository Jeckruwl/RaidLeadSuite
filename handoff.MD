# Handoff — RaidLeadSuite (agent → agent)

Documento di passaggio per continuare il lavoro su questa repo in una nuova chat.
Branch di lavoro corrente: `arena/01a0aa40-raidleadsuite` — base `main @ 36cdbac`
(che già include il merge della PR #3 della sessione precedente, branch
`arena/01a0883a-raidleadsuite`).
Questo file è committato nel branch, quindi **entra in `main` con la PR**.

Contesto prodotto: addon per **raid leader** su WoW **WotLK 3.3.5** (Interface `30300`),
target **Warmane**. Cartella addon: `RaidLeadSuite` (= nome del `.toc`). Versione: **1.4.7**.

## Novità della sessione 1.4.7 (questo branch, dopo 1.4.6)

Fix DEFINITIVO icone consumabili non cliccabili (2° reclamo utente in game,
test: aggiornamenti Scenario F, **341 check totali**):

**Causa**: i bottoni flask/food erano **figli della riga-Button**, che ha
drag registrato. In 3.3.5 il mouse-down dentro un Button del genere viene
intercettato dal meccanismo di drag del genitore stesso/ancestale e il
ciclo press+release del click figlio non si chiude mai → zero alert in
qualsiasi fase, e i due fix (1.4.5/1.4.6) non bastavano.

**Soluzione strutturale** (`RF:MakeConsumableIcon`):
1. le icone ora nascono **figlie di `self.content` (sorelle delle righe)**,
   con ancoraggio alla riga in `LayoutSlotGeometry` come prima → nessun
   antenato interattivo che possa divorare il click, level content+30;
2. implementazione click **"primitiva" OnMouseDown/OnMouseUp** (fotografa il
   tasto al down, al rilascio conferma se stesso tasto+stesso bottone),
   `OnClick`/`RegisterForClicks` rimossi — il canale più affidabile su
   3.3.5 per click semplici. Semantiche invariate: sinistro=whisper player,
   destro=RAID_WARNING; in debug entrambe → whisper a se stessi.

**Lezione handoff aggiornata a §3**: il divieto di OnMouseDown/OnMouseUp
vale SOLO per implementare DRAG&DROP (in quel caso OnMouseUp viene
risucchiato durante il drag). Per CLICK semplici su bottoni senza drag è il
contrario: OnMouseDown/OnMouseUp è il canale più robusto, e **mai fare
bottoni cliccabili figli di un Button con RegisterForDrag**.
Nota sandbox: questa sessione era una clone fresca (branch reset al base,
file però coerenti col remote) → fix con `git fetch origin <branch>` +
`git reset --soft FETCH_HEAD` (working tree == tip remoto, nessuna perdità).

## Novità della sessione 1.4.6 (questo branch, dopo 1.4.5)

Fix vero per "**ste dannate icone non cliccabili**" (confermato dal test in
game dopo 1.4.5, test: assert in Scenario F, **340 check totali**):

**Causa radice**: `RF:UpdateDragState` chiamava `slot:EnableMouse(false)`
fuori pre-boss. In 3.3.5 un genitore con mouse disabilitato blocca la
hit-region ANCHE dei figli → i bottoni flask/Well Fed (figli della riga)
non ricevevano NIENTE in qualunque fase diversa da pre-boss, cioè sempre
quando servono davvero. I test con il mock non lo vedevano mai.

Fix su 4 livelli:
1. `UpdateDragState` NON tocca più `EnableMouse`: solo
   `RegisterForDrag("LeftButton")` in pre-boss / `RegisterForDrag()` fuori
   (`OnDragStart` controlla già `IsDragEnabled()`); la riga nasce con
   `row:EnableMouse(true)` in `CreateSlotFrame`.
2. I bottoni consumabili hanno frame level esplicito sopra la riga
   (`+2`) così vincono sempre l'hit-test nella loro area.
3. Strata dell'HUD `LOW` → `MEDIUM` (in LOW le righe potevano finire sotto
   il chrome UI nell'hit-test; l'HUD resta trasparente, nessun impatto
   visivo).
4. Le semantiche click e debug restano: sinistro=whisper al player,
   destro=RAID_WARNING su qualsiasi icona; in debug entrambe arrivano come
   whisper a se stessi (RW con tag `[RAID_WARNING]`).

Mock: `EnableMouse → _enabledMouse`, `RegisterForDrag → _dragButtons`,
`SetFrameStrata → _strata`, `SetFrameLevel → _level`.
Nota test: in lupa (Lua 5.4) `table.getn` NON esiste → usare `#` o
`_dragButtons[1] == nil`.

## Novità della sessione 1.4.5 (questo branch, dopo 1.4.4)

Richieste utente sul **Raid Frame** (test: blocchi F.2/F.3 + aggiornamento
E5/F1 in Scenario E/F, **335 check totali**):

1. **Alert icone consumabili**: il bottone icona ora dichiara
   `EnableMouse(true)` + `RegisterForClicks("LeftButtonUp","RightButtonUp")`
   (la causa probabile degli alert che non partivano sui player reali).
   `RF:OnAlertClick(row, atype, button)` — **sinistro → whisper al player
   singolo**; **destro su QUALSIASI icona consumabile → `RAID_WARNING`**
   (Utils:SendChat declassa a RAID se non leader; in debug whisper taggato
   `[RAID_WARNING]` a se stessi). Tooltip aggiornato, chiavi aggiunte in
   Locale.lua.
2. **Percentuale HP tolta dalle barre**: `bar.hpText` rimosso del tutto
   (creation + tutti i SetText in Fill/Clear/Update/Layout).
3. **Blocchi vuoti dei gruppi invisibili di default**: `ClearSlot` nasconde
   sempre; nuovo `RF:RefreshDropTargets()` (blocchi vuoti + header gruppi
   vuoti compaiono SOLO in pre-boss con `RF._rfDragSource ~= nil`, cioè
   mentre si trascina un player), chiamato da `Rebuild` e dagli script
   `OnDragStart/OnDragStop/OnReceiveDrag`. `RF_EMPTY_BACKDROP` resta per il
   drop target durante il drag.
4. **Nuove opzioni** in Config → Raid Frame → **Layout**: `font` (Friz
   Quadrata/Arial Narrow/Skurri/Morpheus), `fontOutline` toggle,
   `barTexture` (Blizzard / Skill bar / Flat WHITE8x8), `alpha` (opacità HUD
   0.30–1.00). Default in Core (`appearance.font/fontOutline/barTexture`,
   `rf.alpha`). Applicati in `LayoutSlotGeometry` (SetFont su nome e timer
   CD; SetStatusBarTexture su fill+track) e `ApplyLayout` (`frame:SetAlpha`).
   Mock test: `SetFont → _fontArgs`, `SetAlpha → _alpha`,
   `SetStatusBarTexture → _statusbarTex`.

## Novità della sessione 1.4.4 (questo branch, dopo 1.4.3)

Fix da test in game sui bordi (test: blocco bordi G.3 ampliato, **316 check
totali**):

1. **Raid Group (InviteEngine) clipping**: `WL_BORDER` 18→14 — a 18 le barre
   da 16px alte si tagliavano a vicenda (bordo più alto della barra). 14 è
   "un po'" più spesso del 12 precedente senza sovrapporsi.
2. **Comp slots: bordo ora VERAMENTE visibile più spesso** — il bordo dello
   slot era nel backdrop, quindi *sotto* l'icona spec (ARTWORK) e non sembrava
   cambiare. Ora `BuildCompSlots` crea `slot.borderFrame` (figlio, solo
   `edgeFile`, edgeSize `RLS_BORDER=16`) **dopo** l'icona spec (disegnato
   sopra) e ci ATTACCA `slot.roleIconBg`+`slot.roleIcon` (render sopra il
   bordo). Ordine layer: icona spec → BORDO → backdrop ruolo → icona ruolo.
   `FillSlot`/`ClearSlot` colorano il bordo su `slot.borderFrame`. Mock test:
   `CreateTexture` ora registra `_parent`.

## Novità della sessione 1.4.3 (questo branch, dopo 1.4.2)

Richieste utente su 3 aree (test: blocco G.10 + aggiornamento G.2/G.3 in
Scenario G, **311 check totali**):

1. **Bordi**: comp slots + icone "select a spec" `RLS_BORDER` 12→16; caselle
   del pannello **Raid Group** (InviteEngine) con costante separata
   `WL_BORDER = 18` (ancora più spesso, come chiesto).
2. **Loot Manager**:
   - i tasti Roll MS/OS/FFA e **Reroll** annunciano in `RAID_WARNING`
     (`Utils:SendChat` già declassa a RAID se non leader/assistant; in debug
     resta il whisper a se stessi con tag `[RAID_WARNING]`).
   - finestra pickup: sotto "Click to pick up item" c'è ora la riga dorata
     **"give to: <vincitore>"** (`f.giveTo`, testo spostato a +7y).
   - dopo una vincita (`AnnounceWinner` e `ProcessReroll`): nuovo
     `LM:ClearSelection()` svuota la riga selected item → si rollano altri
     pezzi anche con finestre pickup aperte; in `UpdateHistory` le righe con
     `entry.assignedTo` sono **ingrigite** (testi 0.45, icona desaturata) con
     il nome del vincitore in oro.
3. **Main bar**: la coppia **MT/OT sta SOTTO il tasto "Raid Frame"** (cella
   `i_raidframe + cols` in `MW:ApplyLayout`, con skip dei tasti seguenti; se la
   cella sarebbe fuori matrice la coppia resta dopo l'ultimo tasto).
4. Estensioni al mock dei test: `SendChatMessage` → log globale `CHAT_LOG`,
   `SetTextColor` → `o._tc`, `SetDesaturated` → `o._desat`.

## Novità della sessione 1.4.2 (questo branch, dopo 1.4.1)

Correzioni utente al pannello **Group Making** (test: blocchi G.8/G.9 in
Scenario G, **300 check totali, tutti verdi**):

1. **Spazio morto eliminato riducendo l'altezza minima** (NON allargando i box):
   `GM:MinHeight()` ora restituisce `topH + 328` (pila itemizzata nel commento:
   66 title/righe dropdown + 8 + 8 + 140 reqBox-contenuto + 8 + 24 bottoni + 8 +
   58 anteprima + 16 margine). Rimossa la costante `IE_TAB_EXTRA` (era 53): la
   costola InviteEngine segue ancora `MinHeight()` via `SyncWhisplistHeight`,
   sufficiente al contenuto dei tab. Allineato anche il fallback
   `RaidProfile.lua` → `windowMins.groupmaking` (`topH + 328`).
2. **Box "Select a spec" a 2 colonne**: `LayoutClassBar` `COLS = 2` e ordine
   classi `WARRIOR, PALADIN, ROGUE, PRIEST, SHAMAN, MAGE, DEATHKNIGHT, WARLOCK,
   HUNTER, DRUID` (riempimento riga-per-riga a coppie) → col 1: Warrior, Rogue,
   Shaman, DK, Hunter; col 2: Paladin, Priest, Mage, Warlock, Druid
   (Warlock sotto Mage, Druid sotto Warlock, DK+Hunter sotto Shaman).
3. **Larghezza minima = fila bottoni in basso**: nuovo `GM:MinWidth()` che
   somma la fila reale (16 margine + 100 Start Spam + 8 + 100 Preview Msg +
   6 + 24 checkbox + `GetStringWidth()` del testo "Show specs in message",
   fallback 140 + 10 + 100 InviteEngine + 16 margine = 380+label ≈ 510).
   `RaidProfile.lua` → `windowMins.groupmaking` lo usa (fallback 560) al posto
   del 560 cablato; la label è salvata in `self.specsLbl`.

## Novità della sessione 1.4.1

Richieste utente implementate (test: Scenario G):

- **Main bar**: slider Config → General → Window (`matrixCols`, `matrixRows`,
  `barScale`) applicano il layout **in tempo reale** (`self:ApplyAll()` nei set).
  Nuovi tasti **MT / OT**: due mezzi tasti in UNA cella della matrice
  (`RaidProfile.lua`, `self.mtBtn`/`self.otBtn`, cella extra gestita in
  `MW:ApplyLayout`); chiamano `RLSuite:AssignPartyRole("MAINTANK"/"MAINASSIST")`
  in `Core.lua` → `SetPartyAssignment(role, "target")` **toggle**, guardie:
  target presente + `RLSuite:IsOfficer()` (sempre true in debug).
- **Loot Manager** (`LootManager.lua`): finestre "Click to pick up item"
  impilate **una sotto l'altra** (`LM:StackTradeWindows`, lista `self.tradeWindows`,
  noms globali univoci `RLSuiteTradeWindowN`; chiudendone una le altre risalgono
  via `LM:CloseTradeWindow`); altezza ridotta = icona 32px + padding;
  testo **a destra** dell'icona cliccabile. `LM:ClearHistory()` svuota storico +
  roll + finestre pickup: chiamata da `RLSuite:ApplyDebugMode()` quando la
  **debug mode viene DISATTIVATA**.
- **Group Making**: `reqBox` (Aim/Reserved/Other) ancorato in basso a 8px sopra
  la fila bottoni (`reqBox:BOTTOMLEFT → spamBtn:TOPLEFT`) — niente più spazio
  morto tra caselle di testo e tasti; bordi più spessi (`RLS_BORDER = 12`:
  comp slots, icone spec class bar).
- **InviteEngine / Raid Group**: bordino **dorato** sullo slot-drop durante il
  drag (`GM:StartWLDragTracking`/`GM:WlDragTick`/`GM:StopWLDragTracking`,
  tracker nascosto `wlDragTracker` con OnUpdate 0.03s, flag `bar._wlDropHl`,
  colori normali salvati in `bar._nbR/_nbG/_nbB` e rispettati da
  `GM:UpdateWLGroups`); bordi caselle Raid Group a 12px; **fix popolamento**:
  `IsInRaid()` non esiste su 3.3.5 reale (API 4.0+) — ora il panel usa
  `GetNumRaidMembers()` come fonte di verità, quindi si popola anche
  **entrando in un raid già formato** (metà pieno).

## Lezioni apprese aggiuntive

- `IsInRaid()` **non** esiste nel client 3.3.5a (né su Warmane): controlli raid
  solo via `GetNumRaidMembers() > 0` (guardia `if GetNumRaidMembers`).
- Nei test: geometrie degli slot mockate con override per-istanza
  (`slot.GetLeft = function() ... end`) persistono tra scenari — azzerarle
  (`b.GetLeft, ... = nil, ...`) prima di un nuovo scenario di hit-test.
- `rt.eval` accetta SOLO espressioni: gli statement vanno in `rt.execute`
  (salvare il booleano in una globale e leggerla con `rt.eval`).

## 1. Struttura della repo

Ordine di caricamento dal `.toc` (`RaidLeadSuite.toc`): prima le Ace3 in `Libs/`
(`LibStub` per primo), poi:

| # | File | Righe | Ruolo |
|---|------|------:|-------|
| 1 | `Locale.lua` | ~100 | AceLocale-3.0; `enUS` default; tutte le stringhe UI via `RLSuite.L` |
| 2 | `Utils.lua` | ~700 | Helper condivisi (colori classe, icone spec, chat/whisper, tempo, tabelle) |
| 3 | `Core.lua` | ~1480 | AceAddon core: DB (`RLSuiteDB`), fasi (`RLSuite.context`), debug raid model, minimap button, autoinviter, spam Lim/Aim |
| 4 | `RaidProfile.lua` | ~800 | Finestra principale dell'addon (main window) |
| 5 | `MacroBar.lua` | ~900 | Barra macro/pull; countdown pull/break non sovrapposti (AceTimer named timers) |
| 6 | `GroupMaking.lua` | ~3770 | **InviteEngine**: composizione raid, pannello "Raid Group" a 6 gruppi con drag & drop (implementazione di riferimento) |
| 7 | `RaidFrame.lua` | ~1200 | **Raid Frame HUD**: barre HP per player in 6 gruppi, CD classe, flask/food, barre buff pre-boss / debuff in-fight, drag & drop pre-boss |
| 8 | `MSManager.lua` | ~250 | Main-spec manager; countdown 40s ascolto via AceTimer |
| 9 | `LootManager.lua` | ~800 | Gestione loot/roll; righe ad altezza unica con word-wrap; countdown roll/reroll non sovrapposti; AceEvent per `CHAT_MSG_SYSTEM` |
| 10 | `Config.lua` | ~1270 | **Unica** finestra Ace3 di configurazione: `AceGUI:Create("Window")` + `TreeGroup` a sinistra + `AceConfigDialog` |

Altre directory/file:

- `Libs/` — Ace3 vendorizzate (LibStub, CallbackHandler, AceAddon/Event/DB/Console/Comm/Serializer/Timer/Hook/Locale/Tab/Bucket/GUI/Config/DBOptions). Caricate dal `.toc`.
- `media/` — `allianceicon`, `hordeicon`, `save` in `.blp` + `.tga`.
- `tests/rls_ace3_test.py` — suite di test Python+Lupa: **251 check, tutti verdi**. Scenari A–F (vedi §4).
- `README.md` — in inglese; installazione con cartella `RaidLeadSuite`.
- `RaidLeadSuite.toc` — unico `.toc` (il vecchio `RLSuite.toc` è stato eliminato).

Fasi (`RLSuite.context`, in `Core.lua`): `preraid` → `preboss` → `infight`.
Il debug raid model è sparso: `RLSuite.debugRaid.slots[1..30]` (slot → gruppo =
`floor((i-1)/5)+1`); API: `DebugRoster`, `DebugRaidSlots`, `DebugSyncSubgroups`,
`DebugRosterChanged`.

## 2. Modifiche/aggiunte della sessione (vs `main @ 53826a7`)

Diff totale: **+7610 / −2757** su 12 file, più 4 path nuovi (`Libs/`, `Locale.lua`,
`media/`, `tests/`). Sintesi per file:

- **Nuovi file**
  - `Libs/` — intero stack Ace3 vendorizzato (prima mancava / era esterno).
  - `Locale.lua` — nuovo modulo AceLocale (`RLSuite.L`, default `enUS`).
  - `media/` — icone fazione + save (`.blp`/`.tga`).
  - `tests/rls_ace3_test.py` — harness Python+Lupa con mock dell'API WoW/Ace3, 251 check.
- **`RaidLeadSuite.toc` / `RLSuite.toc`** — eliminato `RLSuite.toc`; unico `.toc`
  `RaidLeadSuite.toc`, versione **1.3.0 → 1.4.0**, folder canonica `RaidLeadSuite`.
- **`Core.lua`** (+1405/−~) — modello debug raid sparso a 30 slot + API sync;
  default `appearance.barWidth=180`, `appearance.nameFontSize=11`; fasi
  `preraid/preboss/infight`; fix minimap-in-MBF (vedi vincoli sotto); autoinviter;
  spam Lim/Aim; migrazione DB legacy flat → nuovo schema.
- **`Config.lua`** (+2015/−) — riscritta come **unica** finestra Ace3
  (Window + TreeGroup + AceConfigDialog); pannello Raid Frame destro a **tab**
  (`childGroups = "tab"`, una tab per sub-voce); sezione Layout con slider
  `Icon size`, `Player bar height/width`, `Name font size`, `Ability bar width`,
  `Scale`. **Nota**: il vecchio slider `Width` totale è stato rimosso —
  da verificare con l'utente se era voluto (punto aperto).
- **`RaidFrame.lua`** (+1304/−) — riscritto: HUD "clean" (niente backdrop/bordo/X
  rossa); **30 slot in 6 gruppi G1–G6 × 5** (`RF_GROUPS`/`RF_PER_GROUP`,
  `EnsureSlots`/`CreateSlotFrame`, header `G1..G6`); `GetGroupedRoster()` mappa
  debug-sparso e `GetRaidRosterInfo`; **drag & drop solo in pre-boss**
  (`IsDragEnabled`, `UpdateDragState`, `SlotAtCursor`, `MoveSlot`/`MoveSlotDebug`):
  vuoto = sposta, occupato = scambia; path reale con `SetRaidSubgroup` /
  `SwapRaidSubgroup` dietro `IsRaidLeader() or IsRaidOfficer()`; barre HP
  colorate per classe con nome dentro; flask/food a sinistra, CD classe a destra,
  ability bar verticale; buff-bar pre-boss + debuff-bar in-fight (con varianti
  fazione).
- **`GroupMaking.lua`** (+3197/−) — InviteEngine ampliato; pannello Raid Group a
  6 gruppi con slot/drag/hit-test (`WL_*`, `MoveWLSlotDebug`): è il **riferimento**
  da cui il RaidFrame ha copiato il pattern drag & drop.
- **`RaidProfile.lua`** — main window aggiornata; rimosso `tabPanels`
  (i test ora asseriscono `RLSuite.mainWindow.tabPanels == nil`).
- **`MacroBar.lua`, `MSManager.lua`, `LootManager.lua`, `Utils.lua`** — adozione
  AceTimer/AceEvent (timer nominati non sovrapposti), AceLocale (`RLSuite.L`),
  fix righe loot con word-wrap.
- **`README.md`** — riscritto in inglese, versione 1.4.0, installazione con
  cartella `RaidLeadSuite` + nota `Libs`.

## 3. Vincoli / lezioni apprese (NON violare)

- **Minimap**: bottone dentro MBF — parent a `Minimap`, nome `RLSuiteMinimapButton`
  (mai `"MinimapIcon"` nel nome), force rescan `MBF_Scan` + self-heal; **mai**
  `SetColorTexture` (nil su Warmane 3.3.5: usare `WHITE8x8` + `SetVertexColor`);
  approccio parent-`UIParent` **definitivamente abbandonato**.
- **Drag & drop**: solo `RegisterForDrag("LeftButton")` + `OnDragStart`/`OnDragStop`
  (+ fallback `OnReceiveDrag`) + hit-test `GetCursorPosition` scalato con
  `UIParent:GetEffectiveScale()`; **mai** `OnMouseDown`/`OnMouseUp`.
- **Raid reali**: `SetRaidSubgroup`/`SwapRaidSubgroup` solo dietro
  `IsRaidLeader() or IsRaidOfficer()`; in debug mutare `DebugRaidSlots()` e poi
  chiamare `DebugSyncSubgroups()` + `DebugRosterChanged()`.
- **Buff check**: confrontare spellId via `GetSpellInfo` (`UnitHasSpellBuff`),
  non nomi inglesi (client non-EN). Max rank WotLK già risolti nei sorgenti
  (es. Battle Shout `47436`, Trauma `46855`, Devotion `48942`).
- **Test Lupa**: `rt.eval` NON esegue statement/`local` → setup con `rt.execute`,
  asserzioni con sole espressioni in `rt.eval`. Lupa va installata:
  `pip install --break-system-packages lupa` (ambiente PEP 668).

## 4. Verifiche

```bash
cd /home/user/RaidLeadSuite
python3 tests/rls_ace3_test.py   # atteso: 341 PASS, RESULT: ALL CHECKS PASSED
```

Scenari: A DB fresh · B migrazione DB legacy · A2 AceTimer/AceEvent ·
C Config single-window · D Lim/Aim/fasi/debug/autoinviter · E HUD Raid Frame ·
F gruppi 6 + drag & drop pre-boss (30 slot + 6 header, fill in ordine, move su
vuoto, swap su occupato; vuoti/header vuoti nascosti di default, visibili SOLO
durante il drag; F.2 alert consumabili whisper/RAID_WARNING e no-%% barre;
F.3 opzioni font/outline/texture/opacita') ·
**G** novità 1.4.1 (config colonne real-time, MT/OT, reqBox→bottoni, bordi 12,
debug-off svuota loot, join raid formato, bordino dorato drag, stack finestre
pickup + layout slim) · **G.8** correzioni 1.4.2 (ordine classi 2 colonne con
posizioni Mage/Warlock/Druid e Shaman/DK/Hunter, MinHeight = topRow + 328) ·
**G.9** larghezza minima Groupmaking = fila bottoni bassa (MinWidth, windowMins) ·
**G.10** novità 1.4.3 (roll→RAID_WARNING, "give to" nella pickup, selezione
svuotata dopo la vincita, riga rollata ingrigita + desaturata) + G.2/G.3
aggiornati (MT/OT sotto Raid Frame, bordi 16/16/18) · fix 1.4.4 nel blocco bordi (comp borderFrame overlay, WL 14).

## 5. Punti aperti per la prossima sessione

1. Slider `Width` totale rimosso dal Layout — confermare con l'utente se voluto.
2. Drag RaidFrame attivo solo in pre-boss (da richiesta); se serve anche in altre
   fasi per leader/officer è un cambio da una riga in `RF:IsDragEnabled()`.
3. Il bordino dorato del drag esiste solo nel pannello Raid Group
   (InviteEngine); se piace, portarlo anche nel RaidFrame HUD (stesso pattern:
   tracker OnUpdate + `_wlDropHl` + colori `_nbR/_nbG/_nbB`).
4. MT/OT fanno `SetPartyAssignment("MAINTANK"/"MAINASSIST", "target")` (toggle):
   se l'utente vuole icone di stato o anti-toggle esplicito (`GetPartyAssignment`),
   lavorare su `RLSuite:AssignPartyRole` in `Core.lua`.
5. File chiave per area: HUD/gruppi → `RaidFrame.lua`; pannello riferimento →
   `GroupMaking.lua` (`WL_*`, `MoveWLSlotDebug`); roster debug → `Core.lua`
   (`DebugRaidSlots`, `DebugSyncSubgroups`); opzioni → `Config.lua`;
   finestre pickup loot → `LootManager.lua` (`ShowTradeWindow`, `StackTradeWindows`).
