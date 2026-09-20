# Handoff — RaidLeadSuite (agent → agent)

Documento di passaggio per continuare il lavoro su questa repo in una nuova chat.
Branch di lavoro corrente: `arena/01a0aa40-raidleadsuite` — base `main @ 36cdbac`
(che già include il merge della PR #3 della sessione precedente, branch
`arena/01a0883a-raidleadsuite`).
Questo file è committato nel branch, quindi **entra in `main` con la PR**.

Contesto prodotto: addon per **raid leader** su WoW **WotLK 3.3.5** (Interface `30300`),
target **Warmane**. Cartella addon: `RaidLeadSuite` (= nome del `.toc`). Versione: **1.11.23**.

## Novità della sessione 1.11.30 (questo branch, dopo 1.11.29) — icone dimezzate + freccia direzionale

- Tutte le icone close/arrow **dimezzate**: X finestre (MakeCloseX) 22→11, X barretta e freccia 22→11, X MS changes 20→10, X GroupMaking 14→7 e 16→8.
- **Freccia barretta direzionale**: pannello APERTO → punta in su (tga com'è), pannello CHIUSO → **specchiata verticalmente** (punta in giù) tramite `SetTexCoord(0,1,1,0)` (flip reale, nessun secondo file). Aggiornata su OnClick + HookScript OnShow/OnHide del frame.

## Novità della sessione 1.11.29 (questo branch, dopo 1.11.28) — case fix: tutto minuscolo

I riferimenti puntavano a "Close.tga/Arrowup.tga" mentre i file reali sono **close.tga/arrowup.tga (tutto minuscolo)** — su filesystem case-sensitive il client non trovava nulla. File rinominati minuscoli + TUTTI i riferimenti (code, icondbg, test, handoff) allineati. I `media/close.tga` e `media/arrowup.tga` attuali SONO LAVORO DELL'UTENTE (upload diretto, type-10 RLE 32bpp): MAI rigenerarli né sostituirli. Vecchi .blp ormai inutilizzati rimossi dal repo. Versione 1.11.29.

## Novità della sessione 1.11.28 (questo branch, dopo 1.11.27) — ICONE IN TGA, formato BCI (quelli che rendono sempre)

L'utente: "tutte le TGA che ho caricato si sono sempre viste". OK: **le icone tornano TGA**. `media/close.tga` e `media/arrowup.tga` ricreati **byte-identici in formato a `media/BUFFCATICONS/BCI_*.tga`** (type 2 non compresso, 32x32, 32 bpp BGRA, descriptor 0x28 top-origin, **4114 byte**) — stessi file che il client renderizza SEMPRE nel raid frame. Icone attaccate via `Utils:ApplyIcon(btn, "media\\close.tga")` = texture ARTWORK + HIGHLIGHT (pattern minimappa/BCI) su TUTTI i punti (tutte le X finestra, MS changes, GM ×2, barretta X+freccia). BLP delle icone eliminati (solo font/BLP-built-in provati prima senza esito). `/rls icondbg` ora testa i TGA. X verificata anche renderizzando il TGA a PNG: X bianca e freccia bianca corrette. Versione 1.11.28.

## Novità della sessione 1.11.27 (questo branch, dopo 1.11.26) — icone IMPOSSIBILI da non vedere (zero file nuovi)

VERDETTO FINALE sul "non si vedono": `save.blp` caricava perché era già nell'installazione originale dell'utente; Close/Arrowup erano file NUOVI che non arrivavano nella cartella media (qualsiasi metodo di update) → NOT LOADED per sempre, indipendentemente dall'encoding. Soluzione che non dipende da file nuovi MAI più: **la X è un glyph "X" bianco di Fonts\\FRIZQT__.TTF (presente in OGNI client)** via `Utils:ApplyWhiteX(btn, size)`; **la freccia usa la texture built-in `Interface\\Buttons\\Arrow-Up-Up`** via `Utils:ApplyArrowUp(btn)`. Convertiti: `MakeCloseX` (tutte le finestre), X MS changes, X GroupMaking ×2, X e freccia della barretta. I .blp restano nel repo ma non sono più usati. `/rls icondbg` resta come diagnostica. Versione 1.11.27.

## Novità della sessione 1.11.26 (questo branch, dopo 1.11.25) — Close/Arrowup RICCOSTRUITI sul contenitore di save.blp

Prova in game `/rls icondbg`: save.blp/hordeicon.blp = **LOADED**, Close/Arrowup miei = NOT LOADED → il client rifiutava i miei FILE anche se "uguali" in header. Fix definitivo: i due .blp ora sono COSTRUITI PER SPLICE sopra `media/save.blp` — **primi 1172 byte (header+palette) copiati byte per byte dal file che carica**, payload DXT5 proprio (1024+256+64+16+16+16 = 1392B, totale 2564B come save.blp). Verifica a doppio controllo: decoder DXT5 INDIPENDENTE → PNG: X bianca e freccia corrette e centrate. Versione 1.11.26.

## Novità della sessione 1.11.25 (questo branch, dopo 1.11.24) — icone come texture ARTWORK (rendono davvero)

Le icone custom NON si vedevano perché erano attaccate ai bottoni con `SetNormalTexture`/`SetHighlightTexture` (con file custom non si disegnano in modo affidabile su 3.3.5). Ora **tutte** le icone da file usano `Utils:ApplyIcon(btn, rel)` = textures esplicite su layer **ARTWORK + HIGHLIGHT** (blend ADD), IDENTICO al pattern dell'icona minimappa che renderizza sempre. Convertite: barretta (X + freccia), MS changes X, GroupMaking X x2, e `MakeCloseX` (= `MakeIconButton`) su tutte le finestre. Inoltre `/rls icondbg` stampa path risolto + LOADED/NOT LOADED per ogni file custom (usa `GetTexture()==nil` come test di caricamento, stesso criterio della minimappa). Versione 1.11.25.

## Novità della sessione 1.11.24 (questo branch, dopo 1.11.23) — le icone ORA SI VEDONO (encoding BLP)

Causa vera dell'invisibilità persistente: i Close/Arrowup .blp erano codificati
**palettizzati non compressi, senza mipmaps** — il client 3.3.5 (Warmane) non li
renderizza. Ora i due file sono **DXT5 con catena mip completa (32→1)**, byte a
byte nella STESSA forma dei file che si vedono in game (save.blp/hordeicon.blp):
fmt fields [2,4,1,1], offsets [1172,2196,2452,2516,2532,2548], sizes [1024,256,64,16,16,16], totale 2564 byte.

REGOLA per sempre: un `.blp` nuovo va generato come DXT5+mips (comparabile a media/save.blp); se gli header non coincidono, l'icona non si vedrà.

## Novità della sessione 1.11.23 (questo branch, dopo 1.11.22) — X bianche ovunque, X rossa eliminata, barretta trascinabile

- **TUTTE le X di chiusura delle finestre usano la X bianca** `RLSuite.utils:MakeCloseX(parent, onclick)` (BLP nativo `media\\close.blp` via AddonTexture, 22x22, no bordo): CombatLog, GroupMaking (main + whisplist), LootManager (main + finestra trade), MSManager, MacroBar (frame keybind), Config (picker icone macro). La barretta usava già close.blp da 1.11.21.
- **La X ROSSA dentro la main bar è stata ELIMINATA**: in `RaidProfile` la finestra principale non crea più `self.closeBtn` (col template rosso Blizzard). Resta SOLO la X bianca nella barretta sopra la main bar.
- **La barretta ora TRASCINA tutta la main bar**: RegisterForDrag LeftButton → `f:StartMoving()`/`StopMovingOrSizing()` del frame principale.
- Test: nessun `UIPanelCloseButton` resta in nessun file modulo; i 5 close delle finestre costruite sono la X bianca; `mainWindow.closeBtn == nil`; drag della barretta muove la finestra.

## Novità della sessione 1.11.22 (questo branch, dopo 1.11.21) — PH dentro il KEYPAD

- **Il tassello PH vive nella matrice dei TASTI SOTTO (keypad Pull/Ready/Break), NON nella matrice macro.** Bottone figlio di `keypadFrame` (stesso parent dei tasti), cella 75x22 identica ai tasti, senza sfondo e senza bordo, NON cliccabile (mouse off, niente RegisterForClicks), testo oro PH:<FASE> centrato.
- Posizione: **prima cella della prima riga attiva** del keypad; i tasti di quella riga scalano di una cella a destra. `KeypadSize()` conta la cella extra (+1 sulla prima riga attiva) così la larghezza resta esatta.
- La matrice MACRO è tornata identica a prima (n celle, col = (vis-1)%cols): nessuno shift.
- In `infight` il keypad resta nascosto e col keypad anche il tassello PH.

## Novità della sessione 1.11.21 (questo branch, dopo 1.11.20) — texture BLP native + PH tassello matrice + barretta 30px

- **Texture invisibili in game — CAUSA VERA**: path hardcodati `Interface\AddOns\RaidLeadSuite\media\...`. La cartella addon può chiamarsi `RLSuite` o `RaidLeadSuite` (per questo esiste `RLSuite:AddonTexture()`); col nome diverso i file non venivano trovati = icone invisibili ovunque. Ora TUTTE le texture addon passano da **AddonTexture()**.
- **media/close.blp + media/arrowup.blp**: icone rigenerate in **BLP2 nativo 3.3.5** (palettizzato alpha-8, 32x32). I TGA rotti sono stati eliminati dal repo. Referenze in MS changes, GroupMaking (calendar + whisplist) e barretta main.
- **Barretta main**: altezza **30px** (era 20), icone 22x22.
- **PH diventa un TASSELLO DELLA MATRICE**: bottone non cliccabile (mouse off), senza sfondo e senza bordo, stesso parent dei tasti macro e stesso frame level. Occupa la **cella 0** della matrice (i bottoni macro partono dalla cella 1, colonne/righe contano nTotale = n+1). Testo **PH:<FASE>** oro centrato sul tassello.
- (Rimangono pile full di 1.11.20: clip-input degli scroll su tutti i moduli + dropdown guard/reuse.)

## Novità della sessione 1.11.20 (questo branch, dopo 1.11.19) — fix in-game (texture, label, barretta, scroll) (storico)

- **media/close.tga rigenerata**: la X della 1.11.19 era quasi vuota (gate margini invertito → solo 30px agli angoli). Ora X piena al centro (68% copertura). Anche arrowup.tga ingrassata (78%).
- **MacroBar PH:<fase>**: la fontstring era una texture figlia del frame e i bottoni macro (frame level +10) la COPRIVANO. Ora vive in un holder a livello +50 (EnableMouse(false), i click sui tasti sotto restano vivi). Visibile davvero nella prima cella.
- **Barretta main**: **staccata** (gap 2px sopra la main bar).
- **Bug fstack LootManager — la vera causa**: in 3.3.5 lo scroll clippa solo la GRAFICA; le righe-Bottone fuori viewport restano INVISIBILI ma hit-testabili sopra TUTTA la finestra (con tanti loot coprono tutto: "a volte non posso cliccare nulla"). Fix generico `Utils:RegisterScrollClip / ClipScrollRow / RefreshScrollClip`: le righe fuori viewport vengono Nascoste (geometria contenuto invariata → scroll identico). Registrato in **LootManager, CombatLog (2 panelli), MS changes, Whisplist, autonames, mirror invitees**. Bonus: menu dropdown ora RIUSATO per dropdown (mai frame cadaveri nuovi a ogni toggle).

## Novità della sessione 1.11.19 (questo branch, dopo 1.11.18) — icone Close/Arrowup, barretta main, fstack guard (storico)

- **media/close.tga** (X bianca) e **media/arrowup.tga** (freccia bianca): nuove texture (32x32 TGA) generate per l'addon.
- **MS changes**: le X delle righe sono diventate **bianche** (close.tga) e **più grandi**: 20x20 (erano 14x14).
- **Tutte le “x” rosse dei moduli** (GroupMaking calendar invitees + whisplist auto) sostituite con bottoni testurizzati **close.tga bianchi** (niente più fontstring rossi).
- **MacroBar**: testo di fase ora **dentro la matrice** (prima cella in alto a sinistra), formato **PH:<FASE>** (PRE-RAID / PRE-BOSS / IN-FIGHT), oro.
- **Main bar**: nuova **barretta titolo 20px** fissa sopra la finestra, larghezza ereditata dalla main bar (anchor ai due angoli). A sinistra **RLS** oro; a destra **arrowup.tga** (mostra/nasconde SOLO il pannello sotto la barretta) e **close.tga** (chiude main bar + barretta). /rls, minimappa e tab riallineano entrambi.
- **Bug fstack**: `CreateDropdown` ora aggancia OnHide al dropdown: se la finestra ospite si chiude/col menu ancora aperto, menu e **catcher full-screen invisibile** vengono forzatamente chiusi (era il pannello invisibile che rubava i click a tutta la UI). Vale per TUTTI i moduli (condividono lo stesso util). Aggiunto `Utils:AssertNoZombieCatcher` per i casi zombie residui.

## Novità della sessione 1.11.18 (questo branch, dopo 1.11.17) — channel # per canale + debug alleggerito (storico)

- **Groupmaking**: ogni canale spam ha ora la casella **Channel #** affiancata alla checkbox. Il numero esplicito (>0) ha la precedenza sulla risoluzione automatica via `GetChannelName(nome)`; vuoto/0 = auto. Salvato in `groupmaking.spamChannelNums` (default `{}` in Core).
- **Debug**: rimosso il tasto **“Fill fake loot”** dalla voce Debug del Config (resta solo “Enable debug mode”).

## Novità della sessione 1.11.17 (questo branch, dopo 1.11.16) — riforma pannello Config (storico)

- Struttura categorie: **General** (SOLO Font + Scale globale), **Module Menu** (ex General/Window: barScale + Columns + Buttons per column, senza altezza e senza Toggle Anchors), **Groupmaking** (solo spam channels), **Macros** (Bar Layout senza “Enable”, Macro Editor senza tasto HUD), **Raid Frame** (SOLO Layout — eliminati Checks, Alert Messages, Position), **Saved Raids** (penultimo), **Debug** (ultimo, voce top-level).
- Eliminate le voci top **MS Manager** e **Loot Manager** (contenevano solo lo slider scale).
- Eliminati TUTTI gli slider Scale per-modulo: un unico slider **Scale** in General governa ogni finestra (groupmaking, MS, loot, combat log, Raid Frame HUD, MacroBar).
## Novità della sessione 1.11.16 (questo branch, dopo 1.11.15) — pulsanti e debug bar borderless (storico)

- **SkinButton senza bordo dialog**: tutti i pulsanti skinnati (Roll MS/OS/
  FFA, Reroll, Announce Changes, Raid Buffs, tab, debug bar...) ora hanno
  SOLO il fill piatto scuro; l'hover schiarisce il riempimento invece di
  accendere il bordo oro (highlight White8x8 0.08 resta).
- **SkinRow senza bordo dialog**: anche le righe-lista cliccabili (loot,
  whisplist, combat log) perdono l'UI-Tooltip-Border; la selezione passa
  da bordo oro a riempimento caldo ben piu' marcato (0.34,0.26,0.06).
- **Debug bar borderless** (_noOuterBorder = fill tenuto, bordo via), come
  la main bar.
I bordi "artwork" RLS (comp icons, raid group slots, RLS_BORDER 16/14)
NON sono toccati: sono il look tematico richiesto a suo tempo, non bordi
dialog. 589 check PASS.

## Novità della sessione 1.11.15 (questo branch, dopo 1.11.14) — debug bar SEMPRE inglese

Rimosse le traduzioni italiane delle 4 etichette debug bar: Fill Raid /
Test Loot / Empty Loot / Test Whisplist ora sono in inglese su QUALUNQUE
client (il file Locale precedente le rimandava in italiano su client itIT,
per questo le si vedeva ancora tradotte). 586 check PASS.

## Novità della sessione 1.11.14 (questo branch, dopo 1.11.13) — min height finestra Log

Anche l'altezza minima del CombatLog rispetta lo stack reale: 78
(dropdown/tab/header) + 398 (liste) + ~30 (barra report/clear/live) +
margini = 540 (era 420: sotto, la barra inferiore clippava le liste).
Aggiornati windowMins.log e il clamp iniziale del resize grip.
585 check PASS.

## Novità della sessione 1.11.13 (questo branch, dopo 1.11.12) — debug bar inglese + fix grafici log

- Etichette debug bar in inglese: Fill Raid / Test Loot / Empty Loot /
  Test Whisplist (Test MS e Log Test gia' inglesi).
- CombatLog: la dropdown del fight si fermava a x=-16, dentro la zona
  della X rossa di chiusura (-34..-4) -> spostata a -44.
- CombatLog: min width 640 -> 730 (i 8 tab in alto, 16 + 8*88 = 720,
  sforavano); aggiornato anche il clamp iniziale del resize grip.
584 check PASS.

## Novità della sessione 1.11.12 (questo branch, dopo 1.11.11) — tasto Log Test nella debug bar

Sesto tasto **"Test log"**: RLSuite:DebugLogTest() alimenta il CombatLog
con 3 pull fittizi completi attraverso il percorso reale OnCLEU/Regen
(GUID boss col formato esadecimale vero, entry id in chars 9-12):
- Lord Marrowgar (KILL): swing spavaldaturi, Fireball crit, danno boss su
  tank, cure (Flash Heal/Chain Heal), Bone Spike APPLIED+REMOVED (uptime
  aure), Kick (interrupt), Replenishment (power), morte player (vline).
- Lady Deathwhisper (WIPE): senza boss death.
- Professor Putricide (KILL): crit Eviscerate, Malleable Goo, Pummel.
SampleTick chiamato a ogni evento: anche la tabella Health/Power del tab
Grafici ha serie. Il RefreshUI aggiorna la finestra se aperta.
581 check PASS.

## Novità della sessione 1.11.11 (questo branch, dopo 1.11.10) — debug bar ordinate + whisper solo dal tasto

- **Niente auto-loot all'accensione del debug**: il loot finto nasce SOLO
  dal tasto "Riempi loot" (SpawnDebugLoot non viene piu' chiamato in
  ApplyDebugMode).
- **Whisper di test**: spariti gli 8 messaggi automatici e il promemoria
  sullo spammer; il percorso reale OnWhisper registra solo a spammer
  attivo, quindi il burst simula spamActive per la durata dell'iniezione e
  la Whisplist si popola lo stesso (10/10 istantanei).
- **Debug bar: colonna singola** verticale con tutti e 5 i tasti, NON
  spostabile e ancorata alla main bar (TOPLEFT->TOPRIGHT relativo, segue
  la barra ovunque).
- Reroll debug: TI pareggiati fittizi rispondono sempre (niente piu'
  "No valid rerolls!" intermittente): il pareggio si risolve sempre.
577 check PASS (3 run consecutive).

## Novità della sessione 1.11.10 (questo branch, dopo 1.11.9) — Loot Manager reattivo al trade (pannello Blizzard)

Il Loot Manager ora si comporta DAVVERO come un pannello nativo: apre in
alto a sinistra (16,-116, stile equip), e quando il TradeFrame compare si
SPOSTA SUBITO a destra del trade (`x = TradeFrame:GetRight() + 10`),
lasciando il trade a sinistra; alla chiusura del trade torna a sinistra.
Se il trade si apre mentre il LM e' chiuso, all'apertura successiva il LM
nasce gia' a destra (stato tradeOpen persistente). Hook una-tantum su
TradeFrame OnShow/OnHide (LM:HookTradePanel), anchor centralizzato in
LM:AnchorDefault chiamato anche da SelectTab. 572 check PASS.

## Novità della sessione 1.11.9 (questo branch, dopo 1.11.8) — Loot Manager fissato (tipo pannello equip) + min width

- **Min width 480 -> 510**: i bottoni in basso (Roll MS/OS/FFA/Reroll da
  80px + Announce Changes da 124px + margini) occupano ~506px; sotto, il
  tasto "Announce Changes" (MS) sbordava fuori finestra.
- **Non spostabile**: rimosso MakeDraggable dal tab loot e SetMovable/
  RegisterForDrag dal CreateFrame del Loot Manager; ad ogni apertura la
  finestra si riancora a TOPLEFT UIParent 16,-116 (in alto a sinistra
  sotto il menu manager), ignorando le posizioni salvate di quando era
  trascinabile. Comportamento identico a una finestra nativa: si apre,
  si chiude, sta dove sta.
569 check PASS.

## Novità della sessione 1.11.8 (questo branch, dopo 1.11.7) — reroll su pareggio ora si attiva

Bug: il ramo "tie" di AnnounceWinner abilitava il tasto Reroll e il
ResetButtons() finale lo disabilitava subito dopo (pareggio => reroll mai
disponibile). ResetButtons ora MANTIENE abilitato il reroll se currentRoll
ha rerollWinners pendenti; inoltre DoReroll in debug inietta anche i
reroll fittizi (prima un pareggio di debug si chiudeva con "No valid
rerolls!"). 565 check PASS.

## Novità della sessione 1.11.7 (questo branch, dopo 1.11.6) — listato loot cliccabile + Clear loot in debug bar

- **Bug**: le finestre "click to pick up" delle vincite erano ancorate al
  centro-alto dello schermo e, aperte in pila dopo un paio di roll,
  coprivano le righe del listato Loot Manager: frame trasparente ai click
  ma bottoni icona/X cattivi => i pezzi smettevano di rispondere. Ora le
  finestre pickup si IMPILANO AFFIANCATE alla finestra del Loot Manager
  (lato con piu' spazio, destra/sinistra via GetLeft vs GetScreenWidth),
  con fallback al centro solo se la finestra loot non e' visibile.
- **Pannello debug**: quinto pulsante "Clear loot"
  (RLSuite:DebugClearLoot -> LM:ClearHistory, chiude anche le pickup).
  Layout debug bar da 2x2 a 3x2 celle (106px), larghezza 344.
563 check PASS (regressione: due roll -> due pickup -> click riga OK,
punto di ancoraggio == edge finestra loot, clear svuota history+pickup).

## Novità della sessione 1.11.6 (questo branch, dopo 1.11.5) — pannello DEBUG stile main bar

In debug mode compare **RLS DEBUG**: una mini-barra trascinabile (SkinFrame
+ SkinButton come la main bar) accanto alla barra principale, con 4 comandi:
- **Fill Group**: riempie il raid simulato con fittizi a caso (pool di 20
  nomi, tutte le 10 classi, spec diverse; m.spec memorizzato sul membro).
- **Fill Loot**: SpawnDebugLoot ora accetta un raid; il pannello pesca un
  RAID A CASO dalla tabella debugLoot e genera i pezzi (SpawnDebugLoot(gm
  raid) resta il default per l'auto-spawn all'accensione).
- **Whisp test**: riusa GM:StartDebugWhispers; se lo spammer non e' attivo
  stampa il promemoria (i whisper finti arrivano solo a spammer attivo).
- **Test MS**: da cliccare DOPO "Ask MS changes": whisper fittizi
  "ms <spec>" di 6 membri casuali del roster in MSManager:ParseMSMessage.
Il pannello si mostra/nasconde in ApplyDebugMode. 558 check PASS.

## Novità della sessione 1.11.5 (questo branch, dopo 1.11.4) — comp ideale xN + canale spam global

- **Messaggio LFM**: spec duplicate nella comp ideale ora collassano in
  "HPriest x2" (invece di "HPriest, HPriest"); ordine = prima comparsa,
  nessun numero per le spec singole.
- **Config -> Groupmaking**: nuovo blocco "Spam channels" con toggle per
  General / Trade / LookingForGroup / World e il canale custom **global**
  (Warmane). Le scelte restano in db.groupmaking.spamChannels e DoSpam le
  usa cosi' come sono (GetChannelName risolve anche canali custom).
548 check PASS.

## Novità della sessione 1.11.4 (questo branch, dopo 1.11.3) — auto-sanazione finestre: mai piu' grip fuori schermo

Il bug resize di 1.11.2 aveva gia' scritto nei salvataggi dimensioni
enormi: riaprendo, la finestra tornava gigantesca e il grip restava
fuori schermo anche col nuovo resize. Ora l'apertura di QUALUNQUE tab
(SelectTab) clampa la dimensione salvata/allo schermo e riscrive i
valori sanati nel layout db; nuovo `Utils:ClampWindowToScreen` riporta
dentro lo schermo size e posizione di qualunque frame sovradimensionato.
543 check PASS.

## Novità della sessione 1.11.3 (questo branch, dopo 1.11.2) — fix resize handle: niente piu' finestre enormi

Tutte le finestre ridimensionabili (grip UI-ChatIM-SizeGrabber in basso a
destra) usavano `StartSizing("BOTTOMRIGHT")`: il sizing nativo usa coordinate
assolute del cursore e litiga con `SetClampedToScreen` — vicino ai bordi la
finestra si gonfiava in modo enorme e il grip finiva fuori schermo (a volte
piu' volte di seguito). Riscritto come resize CUSTOM: delta relativo alla
posizione del mouse-down, scala effettiva rispettata, dimensione SEMPRE
clampata entro lo schermo (e nello spazio a destra del bordo sinistro della
finestra), fine drag robusta anche a rilascio fuori grip. 540 check PASS
(regressione: delta mouse, clamp schermo, persistenza dimensione).

## Novità della sessione 1.11.2 (questo branch, dopo 1.11.1) — fix 3.3.5: il tab Log non apriva nulla

API assenti sul client 3.3.5a che rompevano l'init del modulo a meta' (il
mock di test le possiede, il client no):
- `Frame:SetClipsChildren` (API 5.0.4+): RIMOSSA dal widget grafico.
- `UnitPower/UnitPowerMax` (API 4.0+): sostituite con `UnitMana/UnitManaMax`
  (l'API corretta di WotLK) nel sampling di power%.
- Il widget grafico e' ora costruito PER ULTIMO in CreateFrame: un suo
  errore non puo' piu' impedire la creazione della finestra.
- `LayoutKeyForTab('log')` ora risponde 'combatlog' (stessa chiave di
  drag/resize persistenti, niente piu' layout db diviso) e "log" entra in
  HideAllWindows (CloseTab ora nasconde anche il combat log).
537 check PASS (regressione: layout key + graph creato a init).

## Novità della sessione 1.11.1 (questo branch, dopo 1.11.0) — fix: il tab Log non apriva piu' Groupmaking

`MW:SelectTab` aveva una whitelist hardcoded (group/raidframe/ms/loot):
la chiave "log" veniva riscritta in "group" e il tab apriva Groupmaking.
Aggiunta "log" alla whitelist + test di regressione (SelectTab mantiene
'log' e mostra la finestra combat log). 535 check PASS.

## Novità della sessione 1.11.0 (questo branch, dopo 1.10.6) — COMBAT LOG stile MRT (Fight log in-game)

Nuovo modulo **CombatLog.lua** + tab "Log" nella mainbar: registrazione e
visualizzazione dei combat log in gioco, architettura ispetta a
Method/Exorsus Raid Tools (Logexampl = riferimento read-only, mai modificato/spostato).

- **Parser CLEU 3.3.5** (args diretti, no CombatLogGetCurrentEventInfo):
  categorie damage/heal/death/aura/cast/interrupt/dispel/energize, suffix
  decodificati per subEvent (spell/swung/heal/aura/interrupt/dispel/energize),
  realm-strip dei nomi, NPC id da GUID (hex "F1xx": entry = chars 9-12, o
  formato moderno Creature-...-ID-), flag PLAYER=1024 NPC=2048 PET=4096
  FRIENDLY=16 via aritmetica pura (no bit lib).
- **Segmentazione pull**: su 3.3.5a non esistono ENCOUNTER_START/END →
  PLAYER_REGEN_DISABLED/ENABLED; nome pull = primo boss noto (tabella NPC
  ICC/RS/ToC/Ulduar/Naxx/VoA/Ony/Maly/Sarth); UNIT_DIED boss => KILL,
  altrimenti WIPE.
- **Store**: ring buffer pull (saveFights=15 default) con cap eventi/pull
  (3000 default + contatore dropped), filtri di cattura per categoria,
  opzione disableBuffs; persistenza profilo SOLO a fine combat.
- **Viewer identico a MRT**: finestra 730x540, selezione fight (dropdown, "[LIVE]" per il fight in corso),
  tab Damage/Healing/Enemies/Interrupts/Auras/Players spells/Power/Graphs.
  Lista sx: sorgenti ordinate (colori classe, amount+%); click => breakdown
  per spell a destra con tooltip Total/Hits/Crit + Overkill/Absorbed/Blocked.
  Enemies = danno subito per NPC. Interrupts/Dispels = righe evento stile
  "X interrupt Y with Z (interrupted)". Auras = count + uptime% con
  breakdown per target (stack aperti chiusi a fine fight). Power = energize
  per tipo (Mana/Rage/Energy/Runic...) + per player.
- **Tab Graphs con grafico**: widget port del concetto ExLib.CreateGraph
  (assi, serie lineari da pool texture, vline rosse sulle morti, label max-Y,
  tooltip hover, zoom a trascina + click=reset): modalita' DPS / Health /
  Power, selettore "Step, sec." (1/2/3/5/10), "Total DPS" o player
  selezionato dalla lista sx. Health/Power% campionati 1 Hz sui raid members
  (+ boss via target dei membri, "[BOSS] nome").
- Barra inferiore: **Send report** (top-5 del tab corrente in RAID),
  **Clear** (Shift+click, svuota i pull salvati), checkbox **Live**
  (aggiornamento 2s durante il combat), info eventi/dropped.
- Wiring: toc, db.combatlog defaults, InitModules, PaneForTab/tabDefs/
  ALL_KEYS/windowMins(640x420)/layoutKeys/resizable "combatlog", ~30 stringhe
  Locale.
533 check PASS (+29 Scenario I: parser, GUID, realm, segmentazione, filtri,
aggregazioni totali/spell/aure/enemy/interrupt/players/DPS, UI tabs+click,
grafico serie+vline, clear, cap ring buffer).

## Novità della sessione 1.10.6 (questo branch, dopo 1.10.5) — keypad MacroBar senza bordo

La sezione tasti della MacroBar (keypad Ready/Pull/Break) e' marcata
`_noOuterBorder`: resta il riempimento a tema ma il Tooltip-Border e'
invisibile (stesso trattamento di main bar, Groupmaking, MS, Loot).
504 check PASS (2 nuovi: flag borderless + borderColor alpha 0 con fill).

## Novità della sessione 1.10.5 (questo branch, dopo 1.10.4) — MacroBar numeri + Loot Manager (piattaforma ignore)

**MacroBar**: rimossi i numerini indice sulle icone; resta solo il keybind (se assegnato).

**Loot Manager**:
- **Fix click lista**: la finestra "Click to pick up" non blocca piu' la
  lista: (a) NIENTE piu' PickupItem senza trade aperto (item sul cursore =
  TUTTI i click UI diventano azioni del cursore); il pezzo si prende SOLO a
  trade aperto (click = pickup + trascina in slot 1 + chiudi); (b) frame
  pickup mouse-disabled (catturano solo icona+X); (c) pila finestre spostata
  in CIMA allo schermo (TOP, -80), lontana dalla finestra loot.
- **Emblemi MAI tracciati** (id Heroism/Valor/Conquest/Triumph/Frost).
- **Loot da item in borsa ignorato** (Sack of Frosty Treasures ecc.):
  hooksecurefunc su UseContainerItem + LOOT_OPENED/LOOT_CLOSED marcano la
  loot window "da container"; quei CHAT_MSG_LOOT vengono scartati.
- **Tasto "Announce Changes"** anche nel Loot Manager (a destra di Reroll):
  esegue la stessa GenerateMessage dell'MS Manager.
- **Checkbox "ignore loots:" recipes / BOE / gems / shards** sotto il titolo:
  filtro in cattura (mai registrati) E a video (le righe spariscono),
  persistenti in db.loot.filters. Ricette: classe Recipe/Ricetta o euristica
  pattern esistente; gemme: classe Gem/Gemma; shards: id noti (Dream Shard,
  Abyss Crystal, famiglie TBC/vanilla); BOE: scan tooltip per la riga
  ITEM_BIND_ON_EQUIP / ITEM_BIND_ON_PICKUP (globali localizzate).
502 check PASS (Scenario H nuovo: numeri macrobar, emblemi, bag-loot con
hook mock reale, 4 checkbox, tasto announce con spy, click pickup gated).

## Novità della sessione 1.10.4 (questo branch, dopo 1.10.3) — niente più bordi "dialog" sulle barre player

- I bordi stile tooltip/dialog sono SPARITI dalle barre dei giocatori:
  - gli slot vuoti che appaiono come drop target durante lo shift+drag sono
    ORA invisibili (restano cliccabili: il bordino DORATO del dropGlow segna
    comunque la destinazione sotto il cursore);
  - gli slot MT/OT senza assegnazione sono ORA nascosti del tutto (non sono
    drop target: MT/OT arrivano solo da GetPartyAssignment del raid o dai
    pulsanti debug), niente più riquadri grigi sempre visibili.
- Rimossa la costante RF_EMPTY_BACKDROP (inutilizzata).
482 check PASS (contratto aggiornato: svuotamento intenzionale MT/OT =
invisibile, non più visibile-con-bordo; slot vuoti/tank mai con backdrop).

## Novità della sessione 1.10.3 (questo branch, dopo 1.10.2) — tasto Raid Buffs allineato come G1

Il bottone "Raid Buffs" ora ha il bordo INFERIORE sulla stessa linea del
fondo del testo "Gruppo 1" (BOTTOMRIGHT -> content TOPLEFT a
(rowWidth, y - stripH)), bordo destro = fine barra. Quando non c'e' roster
resta appeso sotto la barra target dell'OT come prima.
480 check PASS.

## Novità della sessione 1.10.2 (questo branch, dopo 1.10.1) — layout G1/strip stabile

- **Header G1 attaccato IN BASSO** alla sua riga (ancora BOTTOMLEFT).
- **Zona strip SEMPRE riservata** (cellW+4 = dimensione icone intestazione)
  tra Tanks e G1: le icone BCI compaiono/scompaiono DENTRO la zona con il
  tasto "Raid Buffs" e NIENTE si sposta sotto (niente groupSpacing extra
  prima di G1 quando c'e' roster: il gap Tanks->G1 e' sempre = stripH).
- **Tasto "Raid Buffs" SOTTO le barre target dei tank**: ancorato
  TOPRIGHT->BOTTOMRIGHT della barra target dell'OT.
480 check PASS (BP_HDR_TOP riscritto sul nuovo ancoraggio; BP_NOSHIFT nuovo:
le righe player non si muovono MAI tra matrice on/off; anchor bottone rebasato).

## Novità della sessione 1.10.1 (questo branch, dopo 1.10.0) — barre MT/OT: target bar al posto dei CD

- Barre MT/OT: MAI piu' CD del player a destra (ApplySlotCDs salta gli slot
  tank e LayoutSlotGeometry nasconde sempre le 4 icone).
- Al loro posto `slot.targetBar`: StatusBar a destra della barra HP che mostra
  nome + HP% del TARGET ATTUALE del tank (colore: classe se player, rosso se
  ostile, verde se alleato). Refresh su evento UNIT_TARGET + dentro UpdateAll
  (RF:UpdateTankTargets). Regola v1.5.3 rispettata: tank fittizi/debug ->
  barra vuota, nessuna query su unit fake.
- Tag MT/OT: ancorato RIGHT->LEFT della barra (-3): attaccato al bordo
  sinistro della barra (prima fluttuava nello spazio consumabili).
479 check PASS (+6 nuovi check tank: tag, no-CD, target bar + fake-guard).

## Novità della sessione 1.10.0 (questo branch, dopo 1.9.9) — TUTTI i bottoni con skin ACE

Richiesta utente: a tutti i tasti togliere la grafica di default Blizzard e
usare "quella ACE".
- Nuovo `Utils:SkinButton(btn)`: rimuove le texture UIPanelButtonTemplate di
  default (normal/pushed/disabled nil), highlight WHITE8x8 8%, backdrop piatto
  SCURO (WHITE8x8 0.16/0.18/0.22 a 0.95) con bordo tooltip fine, bordo DORATO
  in hover via HookScript (stesso oro delle righe selezionate SkinRow).
- Applicata a TUTTI i bottoni di dialogo: Config (3), Groupmaking (16),
  Loot manager (4), MS Manager (3), Macro bar (3), Raid profile (4) e il tasto
  "Raid Buffs" del Raid Frame (34 siti totali). Icon-button con grafica propria
  (macro slot, minimap, righe/liste, overlay invisibili, catchall) INVARIATI:
  non sono tasti di dialogo.
473 check PASS (+5 nuovi check skin + hover su bottoni RF/GM/LM/MS).

## Novità della sessione 1.9.9 (questo branch, dopo 1.9.8) — zona buff CLICK-THROUGH

Report utente: l'area dove compaiono i buff non fa cliccare (aperta o chiusa).
Causa: la WINDOW riservava la zona colonne nella sua larghezza
(W = rowWidth + colonne + 10): il frame, anche invisibile, inghiottiva i click.
Fix: **W = rowWidth** — la finestra finisce al bordo destro delle barre e TUTTA
la grafica matrice (celle, strip icone header, backdrop, tasto Raid Buffs)
viene disegnata OLTRE il bordo destro della window (i figli renderizzano e
ricevono input fuori dal rect del parent, ma solo se mouse-enabled: texture =
niente input, bottoni header/tasto = interattivi come da spec R27). La zona
colonne e' ora click-through garantito perché NON c'e' nessun frame hit-test
sopra: /rls debugbuff e i test confermano frame._w == rowWidth.
La larghezza non "salta" piu' neanche teoricamente (costante = barre).
468 check PASS (aggiornati BP_W/SP_W/BP_W_KEEP + 3 nuovi check click-through).

## Novità della sessione 1.9.8 (questo branch, dopo 1.9.7) — tasto a destra dell'OT + header toggle

- **Tasto "Raid Buffs"**: non piu' sulla riga header Tanks; ora ancorato
  A DESTRA DELLA BARRA OT (LEFT->RIGHT di tankSlots[2], centrato in verticale
  sulla riga OT).
- **Riga d'intestazione icone NON piu' permanente**: si mostra/nasconde col
  tasto "Raid Buffs" insieme alla matrice (e al suo backdrop strip). Quando
  off, la riga G1 consuma solo groupHeaderH in verticale. La LARGHEZZA finestra
  continua a riservare l'area matrice quando c'e' roster (invariato).
466 check PASS (+2 nuovi: anchor OT + header strip OFF a matrice spenta).

## Novità della sessione 1.9.7 (questo branch, dopo 1.9.6) — spacing negativo + barre automatiche

- **Row spacing**: slider Config -> Raid Frame -> Layout ora scende a **-10**
  (prima min 0): le barre dei player possono sovrapporsi dentro il gruppo.
- **Player bar height**: opzione RIMOSSA; l'altezza delle barre e' AUTOMATICA
  = `iconSize` (`LayoutMetrics.barHeight = iconSize`). Default `barHeight=20`
  tolto anche dai defaults DB (valore legacy nei profili esistenti ignorato).
464 check PASS (+2 nuovi check: opzione rimossa + barHeight==iconSize + min -10).

## Novità della sessione 1.9.6 (questo branch, dopo 1.9.5) — icone a altezza G1 + backdrop strip

Richiesta utente: icone BCI spostate all'altezza dell'header G1 e backdrop
che prende il valore da quello delle barre.
- ApplyLayout: la strip icone NON consuma piu' verticale in cima (l'header
  Tanks torna a y=0); in cima resta solo la CREAZIONE/refresh dei bottoni.
  Nel loop gruppi, per g==1 con header mostrato: bottoni posizionati
  nell'area colonne (x = rowWidth + 4 + (c-1)*cellW) alla STESSA y
  dell'header G1; la riga consuma max(groupHeaderH, cellW+4) cosi' niente
  sovrapposizioni con le righe player.
- Nuovo `self._buffHdrBg`: texture BACKGROUND figlia di self.frame, UNICA
  striscia dietro la strip (m.rowWidth+2, #cols*cellW+6 x cellW+4), colore =
  `db.appearance.matrixBackdrop` {r,g,b,a} (default 0.5/0.5/0.5/0.35) = lo
  STESSO valore letto dai backdrop per-riga delle barre: cambiandolo in
  Config cambiano entrambi. Nascosta quando non c'e' intestazione.
462 check PASS (+1 nuovo check BP_HDR_BG).

## Novità della sessione 1.9.5 (questo branch, dopo 1.9.4) — ICONE CUSTOM DELL'UTENTE, punto finale

L'utente ha chiarito lo stato reale del suo client: nella cartella addon ci
sono SOLO i suoi .tga in media/BUFFCATICONS (mai avuti i .blp: i .lua li
aggiorna lui, i media no) e le icone Blizzard caricano senza problemi. Le
icone custom invisibili delle 1.9.1-1.9.3 erano quindi semplicemente FILE
ASSENTI nella cartella al momento del tentativo — non "client che rifiuta i
formati". Ripristinato il design originale, nella forma piu' semplice
possibile:
- Header matrice: UNA `SetTexture(self:_BuffCatIconPath(c))` -> 
  `media\BUFFCATICONS\BCI_<c-1>.tga`. Niente blp, niente fallback,
  niente GetTexture-detection. `_BuffCatIconPath` ripristinato (tga only).
- `/rls debugbuff` stampa per colonna: chiave, path BCI usato, btn, size.
- Locale aggiornata ("Buff headers: media/BUFFCATICONS/BCI_<0..24>.tga").
NIENTE .blp nel repo (eliminati in 1.9.4, restano eliminati per volonta'
dell'utente); i .tga sono i suoi file e sono l'unica fonte delle icone.
NOTA DEPLOY: su 3.3.5a le immagini nuove entrano nell'indice del client solo
con chiusura completa + rilancio (mai solo /reload) dopo aver copiato file
nella cartella addon.
461 check PASS.

## Novità della sessione 1.9.4 (questo branch, dopo 1.9.3) — header = icone DI GIOCO

> SUPERATA dalla 1.9.5 per richiesta esplicita dell'utente (spiegazione della causa errata: non era il client a rifiutare i file, i file non c'erano nella cartella). Mantenuto come log.

`/rls debugbuff` sul client utente: BCI = NOT LOADED in TRE formati provati:
TGA (1.9.1), BLP raw (1.9.2), BLP DXT3 byte-identico a media/save.blp (1.9.3,
file verificati presenti nel push remoto quindi sul disco utente). Verdetto
definitivo: **quel client 3.3.5 non carica NESSUNA texture loose-file da
Interface\AddOns** — di nessun formato. Le uniche texture che renderizza sono
quelle interne del gioco ("Interface\Icons\..."), prova: le icone spell
nelle celle della matrice, che il giocatore vede da sempre.

FIX (nessun fallback, nessun detection, richiesto esplicitamente dall'utente):
l'header della matrice fa UNA sola `SetTexture(col.icon)` sull'icona di gioco
definita nella colonna (`RLSuite.raidBuffColumns[].icon`, gia' corretta e
collaudata): STESSA fonte delle celle -> caricamento garantito al 100%.
- Rimossi: `_BuffCatIconPath/_BuffCatIconTexture` (blp->tga fallback),
  i 25 BCI_*.blp generati, il convertitore tests/tools/tga2blp.py, i 2 check
  python di formato BLP, le locale "loaded"/"NOT LOADED".
- `/rls debugbuff` ora stampa per colonna: chiave, path icona di gioco, btn,
  size — informazione deterministica, niente "load probes".
- I .tga originali dell'utente RESTANO in media/BUFFCATICONS (asset suoi,
  inutilizzati dal codice: quel client non li montera' mai).
- Se in futuro servono icone custom visibili sul client utente: l'unica via e'
  patchare le texture dentro un MPQ custom (fuori scope addon).
461 check PASS.

## Novità della sessione 1.9.3 (questo branch, dopo 1.9.2) — BLP DXT3 (il formato che il client accetta)

> SUPERATA dalla 1.9.4: dimostrato che il client rifiuta ANCHE il DXT3. Mantenuto solo come log della verifica.

`/rls debugbuff` sul client utente: BCI = **NOT LOADED** anche coi .blp RAW
(v1.9.2). Diagnosa definitiva confrontando gli header: i BLP che il client
utente CARICA da sempre (media/save.blp, alliance/hordeicon.blp) sono
**type=1, compression=2 (DXT), alphaBits=4, alphaType=1 (DXT3), hasMips=1**;
la build 3.3.5 in uso accetta SOLO BLP compressi DXT per le texture addon,
non RAW (compression=3) né TGA.

- `tests/tools/tga2blp.py` riscritto: **encoder DXT3/BC2 puro Python**
  (8B alpha LSB-first 4bpp + color0/1 RGB565 + palette 2bpp; endpoint ai
  vertici del bounding box, c0>=c1; 16B/blocco anche per mip 4x4/2x2/1x1).
  Output byte-layout IDENTICO a media/save.blp: 32x32 -> 2564 byte, offsets
  (1172,2196,2452,2516,2532,2548), sizes (1024,256,64,16,16,16).
- Rigenerati i **25 BCI_*.blp** in DXT3 (loader Lua invariato: blp prima,
  tga fallback).
- Suite: +2 controlli python di regressione formato BLP (magic/type/comp/
  alphaBits/alphaType/mip offsets+sizes/len per ogni file + twin tga<->blp).
Il fix NON tocca Lua: solo i file media. Se dopo pull+reload `/rls debugbuff`
dice ancora NOT LOADED, il colpevole restante sarebbe il PATH, non il formato
(ma il path è lo stesso schema del minimap icon che funziona).
463 check PASS.

## Novità della sessione 1.9.2 (questo branch, dopo 1.9.1) — ICONE .blp + /rls debugbuff

Report utente: nessuna icona dell'header BCI visibile (bottoni/clic/alert ok).
I TGA utente sono validissimi (32x32 32bpp non compressi) MA il loro client 3.3.5
aveva GIA' diventato necessario il .blp per il minimap icon (blp fallback
presente in Core: "se il .blp non viene caricato, riprova col .tga" —
il dettaglio funziona col 3.3.5 `Texture:GetTexture()` che torna nil se il
file non si carica). Applicata la STESSA strategia agli BCI:
- `_BuffCatIconTexture(tex,c)`: prova BCI_<c-1>.blp; se GetTexture() == nil ripiega
  su BCI_<c-1>.tga.
- **Convertitore puro Python `tests/tools/tga2blp.py`** (BLP2 non compresso,
  catena mip completa 32..1, header 1172B): `BCI_*.tga` -> **25 `BCI_*.blp`**
  nel repo (BCI_16 incluso, SPCRIT caricato dall'utente in 7b21930).
- Nuovo slash **`/rls debugbuff`**: stampa per OGNI colonna: caricato Y/N,
  path reale tentato, presenza bottone, dimensione region — collaudo nel
  client reale per distinguere "path sbagliato" vs "file non reso".
- Rimedio bug mock: `methods:GetTexture()` ritornava il FRAME invece del path
  (ritardava il debug di middleware) — ora ritorna `self._texture` come nel client.
461 check PASS.

## Novità della sessione 1.9.1 (questo branch, dopo 1.9.0) — HEADER COLONNE A ICONE (Media/BUFFCATICONS)

Richiesta utente: le intestazioni delle colonne della matrice non sono piu'
TESTI ma ICONE from `media/BUFFCATICONS/BCI_<i>.tga`.
- Indice: colonna c (sinistra->destra, stesso ordine attuale) usa BCI_(c-1).tga
  (BCI_0 = Kings/stats, ..., BCI_24 = retAura). Path via RLSuite:AddonTexture.
- **Size fissa = iconSize raid frame + icon spacing** (= passo colonna cellW):
  _icon:SetSize(m.cellW, m.cellW), quadrata, centrata nel bottone.
- Strip header snellita: altezza = cellW + 4 px (da 80 dei testi 45° — Título
  ruotati RIMOSSI DEFINITIVAMENTE; tankHeader y passa da -80 a -(cellW+4)).
- Bottone identico di logica: permanente (headersOn indipendente dal toggle),
  figlio della WINDOW, hover = l'icona si accende (vertex 0.8 -> 1.0) + TOOLTIP
  col nome categoria, click = raid warning categoria (inessato).
- `SetVertexColor` ora registrata nei mock (_vertex); GameTooltip:SetText testato.
- ATTENZIONE: cartella utente contiene 24 icone (BCI_0..BCI_24) ma **manca
  BCI_16.tga** (colonna 17 = focusMagic): a runtime quella testata risultera'
  vuota -> aggiungere il file mancante lato utente.
- NOTE DI SESSIONE: branch locale riavvolto a 36cdbac dall'ambiente, remoto
  al commit utente 277893d "Add files via upload" (icone). Recuperato con
  checkout FETCH_HEAD media + reset --soft + add -A (albero identico, pulito).
  459 check PASS.

## Novità della sessione 1.9.0 (questo branch, dopo 1.8.0) — CATEGORIE BUFF ALLINEATE A ICY VEINS WOTLK GUIDE

Confronto con https://www.icy-veins.com/wotlk-classic/raid-buffs-and-debuffs:
19 -> **25 colonne** visibili nella matrice ("fuori" restano flask/wellfed come
voluto). Correzioni dati (id spell):
- atkpower: 19506 (Trueshot) spostato nella NUOVA colonna **apIncrease "AP%"**
  (Trueshot/Unleashed Rage/Abomination's Might: HUNTER, SHAMAN, DEATHKNIGHT).
- haste: NON piu' Bloodlust (2825/32182) -> categoria giusta **luna/ret 3%**:
  Moonkin Aura 24907 + Swift Retribution 53648 (DRUID, PALADIN).
- damage: ids veri: Arcane Empowerment 31583 + Ferocious Inspiration 34460 +
  Sanctified Retribution 31869 (prima 75447/31579/31580 sbagliati).
- meleeCrit aggiunti LotP 17007; meleeHaste aggiunto Imp Icy Talons 55610;
  intellect/spirit aggiunto Fel Intellect 57567 (Affli lock); stats aggiunto
  Blessing of Sanctuary 20911.
- NUOVE COLONNE: apIncrease "AP%", dmgReduction "DR%" (Sanctuary 20911 +
  Renewed Hope 57472/57479), healReceived "Heal+" (Tree of Life aura 34123;
  Improved Devotion non lascia aura propria), physReduction "Armor+"
  (Ancestral Healing/Inspiration, tank-side), replen "Repl" (5 fonti),
  spellHaste "SpH" (Wrath of Air Totem 3738).
- Tenute le categorie extra che Icy Veins NON elenca ma utili: armor (Devotion),
  shadow (ShProt), focusMagic, retAura (ora ultima colonna per priorita').
- Priorita' left->right aggiornata (RF_BP_PRIORITY 1..25): Kings, Stamina, Gift,
  Int, Spirit, ShProt, Armor, MP5, ATK, AP%, HP, Str+Agi, SPow, SpH, MHaste,
  MCrit, SpC, FM, Dmg%, Haste, DR%, Heal+, Armor+, Repl, Ret.
- raidBuffChecks sincronizzata (10 categorie mancanti aggiunte);
  raidDebuffChecks +4: apReduction, attackSpeedReduction, castSpeedReduction,
  healingReduction (debuff page Icy Veins).
- Test: conteggi dinamici su #_MatrixCols() (25) ovunque; 7 nuovi check di
  allineamento (AL_*). 458 check PASS.

## Novità della sessione 1.8.0 (questo branch, dopo 1.7.3) — BACKDROP UNO PER RIGA + HEADER PERMANENTE FUORI DAL PANNELLO

Richieste utente (esplicite e ripetute):
1. **"backdrop UNO PER BARRA, non tutta la finestra"**: eliminato il rettangolo unico
   matrixBg; ora OGNI riga occupata ha la propria striscia grigia semi-trasparente
   dietro le icone (slot._matrixBg): x = bordo destro barre+2, altezza = rowHeight-2,
   larghezza = colonne*cellW+6. Colore/alpha = opzione "Buff check backdrop".
   La striscia esegue SetSize esplicito (mai doppi anchor su content: content e'
   largo solo rowWidth — trappola che rendeva tutto invisibile al primo tentativo).
2. **"TIRALA FUORI una volta per tutte: SEMPRE VISIBILE INDIPENDENTEMENTE dal tasto
   Raid Buffs"**: la striscia coi 19 titoli di categoria e' ora PERMANENTE finche'
   esiste un roster: LayoutMetrics riserva SEMPRE l'area matrice (W = righe+matrice),
   ApplyLayout mostra SEMPRE le testate (rinominata headersOn = NON legata a
   buffMatrixOn), RefreshBuffMatrix show condizione rows[1]. I bottoni restano figli
   della window (fuori dal "pannello" content). IL TASTO "Raid Buffs" ORA ACCENDE/
   SPENGE SOLO LE ICONE dei player (+ strisce di riga) — e' diventato un toggle
   delle sole cellule.
3. Test riscritti per la nuova semantica: RB_SHOW/FAKE/GEOM/RGB0/OFF/STILL,
   BP_HDR_PERM (header visibili anche a matrice spenta), BP_W_KEEP (W sempre
   riservata); aggiornato anche il check storico "width = rows only" (contraddiceva
   il design permanente) -> "rows + permanent category-header area".
451 check PASS.

## Novità della sessione 1.7.3 (questo branch, dopo 1.7.2) — BACKDROP VISIBILE + HEADER FUORI DAL PANNELLO SEMPRE

1. **Backdrop invisibile**: `content` e' largo solo `rowWidth` (le barre!); il
   backdrop grigio era ancorato TOPLEFT(rowWidth+2)/BOTTOMRIGHT(-2) ENTRAMBI su
   content -> larghezza NEGATIVA -> texture invisibile. Ora BOTTOMRIGHT sul
   `frame` (largo W = righe + matrice). Il test MBG_RIGHT_OK asserta il relativo.
2. **Riga d'intestazione "tirata fuori dal pannello"**: i 19 bottoni categoria
   erano figli di `content` (il pannello che viene riposizionato/nascosto dai
   layout/recreate) -> potevano sparire. Ora sono figli della WINDOW
   (`CreateFrame(..., self.frame)`), coordinati solo in ApplyLayout, e
   RE-SHOWnati da ApplyLayout/RefreshBuffMatrix/UpdateAll ad OGNI giro:
   con la matrice aperta non spariscono mai.
   TEST: BP_HDR_OUT (parent==frame + shown per tutte le 19), BP_HDR_STILL
   (UpdateAll+Refresh non tolgono visibilita'), MBG_STILL (backdrop fermo).
450 check PASS.

## Novità della sessione 1.7.2 (questo branch, dopo 1.7.1) — FIX REGRESSIONE 1.7.0: FontString:SetRotation assente su 3.3.5

SINTOMI UTENTE (tutti dalla stessa causa): niente overlay dorato/gruppi vuoti
cliccando un player, niente buff casuali della matrice dopo fill, impostazioni
non realtime, intestazione matrice sparita.
CAUSA: `FontString:SetRotation` NON ESISTE sul client 3.3.5 base (e' prerogativa
delle Texture; su FontString e' arrivata solo in client estesi). Chiamandola
dentro `_MatrixHeaderBtn` (prima colonna della matrice) il Lua error usciva da
ApplyLayout a meta': niente packing dei gruppi, niente _LayoutMatrixRow/celle,
niente matrixBg, niente UpdateAll -> TUTTI i sintomi. Ed era SILENZIOSO.
FIX: guard `if fs.SetRotation then SetRotation(math.rad(45))` (Anthropic
Ascension/clients estesi => rotazione 45° identica a 1.7.0) ELSE fallback
orizzontale clippato (SetWidth(RF_MATRIX_HDR_H-10), no word-wrap): le testate
non si accavallano, bottoni/hover/click uguali. TEST: `_rotatedLabel` flag +
BP_LAYOUT_DONE: content height>0 e OGNI header di gruppo packato dopo
ApplyLayout con matrice attiva (rilevamento abort a meta' layout).
446 check PASS. Lezione: MAI chiamare API del client "assicurative" dentro
codice di layout critico senza guard: un errore li ferma l'intero HUD e
silenziosamente.

## Novità della sessione 1.7.1 (questo branch, dopo 1.7.0) — NIENTE BORDO ESTERNO SUI DIALOG PRINCIPALI

Richiesta utente: togliere il bordo del dialog (Tooltip-Border) dalle finestre
Main bar, Groupmaking, Invite engine, MS Manager, Loot Manager.
Implementazione: le finestre portano il flag `f._noOuterBorder = true` (setto
SUL FRAME, cosi' ogni re-skin da theme/ApplyAll resta consistente);
`Utils:SkinFrame` chiama `SetBackdropBorderColor(0,0,0,0)` se il flag e' attivo,
altrimenti mantiene il bordo temico. Fill invariato.
Punti: RaidProfile frame (main bar), GroupMaking mainFrame, whisplistFrame
(= RLSuiteInviteEngine, ancorata a Groupmaking), MSManager.frame,
LootManager.frame. LE TRADE WINDOW del Loot Manager restano CON bordo (non richieste).
445 check PASS (5 finestre senza bordo + controllo: finestre non marcate invariato).

## Novità della sessione 1.7.0 (questo branch, dopo 1.6.3) — 5 OPZIONI LAYOUT + HEADER MATRICE 45°/HOVER/CLICK

### Nuove opzioni in Config -> Raid Frame -> Layout (profile.raidframe.appearance)
- **Icon spacing** (0..16, def 8): gap tra le icone della matrice; passo colonna =
  iconSize + iconSpacing (default 24 invariato).
- **Row spacing** (0..12, def 0): gap tra le barre dentro ogni gruppo.
- **Group spacing** (0..24, def 8): gap tra i gruppi (era RF_GROUP_GAP fisso).
- **Group header font size** (8..16, def 10): SetFont(font, size, outline) applicato a
  G1..G6 e Tanks; l'altezza header = size + 4 (sostituisce RF_HEADER_H).
- **Buff check backdrop** (type=color, hasAlpha): colore + trasparenza del rettangolo
  dietro le righe della matrice (default 0.5/0.5/0.5/0.35). Defaults anche in Core.lua.
- LayoutMetrics ora espone iconSpacing/rowSpacing/groupSpacing/groupHeaderH/cellW;
  ApplyLayout usa m.rowSpacing/m.groupSpacing/m.groupHeaderH/m.cellW ovunque.

### Matrice Raid Buffs — header ridisegnato
- **Testi inclinati di 45°** (FontString:SetRotation(math.rad(45)), risalgono verso
  destra) su bottoni alti RF_MATRIX_HDR_H=80 px → leggibili con colonne da 24px.
- **Header SEMPRE visibile** con la matrice attiva (refresh loop su _buffHdrBtns).
- **Ordine per importanza** (RF_BP_PRIORITY): Stats(Kings), Stamina, Wild/Gift,
  Intellect, Spirit, ShadowProt, Armor, MP5, AtkPower, HP, Str+Agi, SpellPower,
  Haste, Dmg%, MeleeHaste, MeleeCrit, SpellCrit, FocusMagic, RetAura.
- **Hover sul titolo** → testo bianco acceso (1,1,1); OnLeave → oro (1,0.82,0).
- **Click sul titolo** → `Utils:SendChat(msg, "RAID_WARNING")` con elenco di chi
  manca quella categoria (`RF:WarnBuffCategory`, scan via _BuffCellIconFor: funziona
  anche sui fake coi buff casuali; troncato a 240 char; in debug diventa whisper a
  se stessi col prefisso [RAID_WARNING] come da convenzione).
- Attenzione test: la colonna strAgi ORA e' la 11a non la 10a (usa ricerca per key).
- 439 check PASS.

## Novità della sessione 1.6.3 (questo branch, dopo 1.6.2) — BACKDROP GRIGIO TRASPARENTE SOTTO LE RIGHE DELLA MATRICE

Con la matrice "Raid Buffs" aperta, le 19 colonne di icone estendono la finestra del
raid frame a destra della colonna barre ma senza sfondo: sul mondo dietro le celle
risultavano poco leggibili. Ora `self.matrixBg` (texture del content, strato BACKGROUND
=> sotto TUTTE le righe e le icone) mostra un rettangolo grigio semi-trasparente
 SetTexture(0.5,0.5,0.5,0.35) che copre dall'angolo in cima a destra della colonna barre
(m.rowWidth+2, 0) al bordo destro/in fondo del content (-2, 1): header + righe incluse.
Solo a `buffMatrixOn`; si nasconde al collapse. In 3.3.5 il colore pieno si fa con
SetTexture(r,g,b,a) (SetColorTexture NON esiste prima della 6.0!).
422 check PASS (backdrop visibile/nascosto, RGBA grigio, ancoraggio al bordo righe).

## Novità della sessione 1.6.2 (questo branch, dopo 1.6.1) — DEBUG: MT/OT FITTIZI + BUFF CASUALI AGLI INVITATI

Perché in debug non si vedeva nulla: le barre Tanks restavano vuote (GetPartyAssignment
non risponde per i fake) e la matrice buff era tutta vuota (i fake non hanno aure).

1. **MT/OT fittizi in debug** (`RF:RebuildTanks` → branch `RLSuite:DebugMode()`):
   store `RLSuite.debugTanks = { mt, ot }`. Semantica: `nil` = mai toccato → AUTO-FILL
   (MT = primo del roster, OT = primo diverso → barre SEMPRE piene in debug);
   `string` = assegnato; `false` = svuotato INTENZIONALMENTE dall'utente (no auto-refill).
   Nome sparito dal roster → torna nil (auto). Real raid invariato (GetPartyAssignment).
2. **Tasti MT/OT in debug** (PreClick dei secure button): in DebugMode scrivono
   debugTanks invece di comporre la macro (fallirebbe sui fake) + `raidFrame:Rebuild()`
   + print di conferma. In raid reale: secure macro invariata. In F.4/G-MT lo stage
   secure gira con `RLSuite.DebugMode` temporaneamente off (mock).
3. **Gli invitati ricevono buff casuali** (`RF:_DebugMemberBuffSet(nome)`): set di
   spellId STABILE in sessione (seme LCG dal nome), ~55% per categoria, spell scelta a
   caso tra quelle della colonna → la matrice si popola in debug senza flicker.
   `_BuffCellIconFor(member, col)` instrada: fake+debug → set simulato; altrimenti →
   scan aure reale UnitBuff (player incluso). Le ICONE consumabili per-riga sui fake
   restano "missing" come sempre (clickabili per testare whisper/warning).
4. `ApplyDebugMode` azzera `debugRaid` + `debugTanks` + `debugBuffs` (niente leak tra sessioni).
5. **418 check PASS** (tank auto-fill/override/clear-persistent, buff casuali stabili
   sulla riga dei fake, secure-button MT/OT invariati fuori debug).

## Novità della sessione 1.6.1 (questo branch, dopo 1.6.0) — FIX FUNZIONI PROTETTE + MATRICE RAID BUFFS INTEGRATA

### 1) Errore "forbidden function TargetUnit()" dal Raid Frame — RIMOSSA LA FUNZIONE RESIDUA
TargetUnit() e' PROTETTA: il client la rifiutava da qualunque percorso tainted (l'errore
dell'utente, target comunque funzionante perche' lo fa l'overlay engine 1.5.6).
`RF:TargetRow` ora: overlay sicuro visibile → SOLO trace rfDbg (il target e' engine);
overlay nascosto (attributi congelati in combat) → fallback `TargetByName(nome esatto)`
(non protetta); fake/debug → solo trace. La chiamata TargetUnit e' stata ELIMINATA
dal codice. Il mock nei test ora lancia error() se TargetUnit venisse mai chiamata.

### 2) Errore "forbidden function SetPartyAssignment()" assegnando MT/OT — TASTI SECURE
SetPartyAssignment e' PROTETTA su 3.3.5: i tasti MT/OT del Raid Profile (MainWindow)
non possono chiamarla. Sostituiti con **SecureActionButtonTemplate type="macro"**:
in `PreClick` (solo fuori combat, target valido, leader/assist) assembla
`/maintank <nome>` o `/mainassist <nome>`, `PostClick` svuota (mai azioni secure stale).
Le macro slash sono l'unico canale lecito, identico a una macro fatta a mano.
`RLSuite:AssignPartyRole` resta in Core (deprecated, non piu' usata dalla UI).

### 3) Matrice "Raid Buffs": il pannello 1.6.0 SOSTITUITO dal design richiesto
- **Fa parte del Raid Frame**: niente finestra separata a destra; le icone delle
  categorie stanno **lungo la riga di OGNI player** nei gruppi (oltre il bordo
  destro di barra+cd), centrate in altezza con la riga.
- **Solo al click** del tasto "Raid Buffs" (on/off; off anche senza roster).
- **Niente colonne Flask e Food** (gia' controllate dalle icone per-riga): 19 colonne
  via `RF:_MatrixCols()` che filtra `raidBuffColumns`.
- **Riga d'intestazione in CIMA** del frame coi nomi sintetici delle categorie
  (Tanks sotto). La finestra si allarga dell'area matrice solo quando attiva.
- Tooltip/celle: scan UnitBuff 1..40 per giocatore per categoria, icona della spell
  reale (GetSpellTexture) o icona fissa categoria per byName; vuota se mancante.
- Rimossi EnsureBuffPanel/ToggleBuffPanel/_LayoutBuffPanel/RefreshBuffPanel;
  nuove ToggleBuffMatrix/_MatrixHeaderFS/_MatrixCell/_LayoutMatrixRow/RefreshBuffMatrix.
- **415 check PASS** (F.2f riscritto su semantica engine-only, F.3 matrice integrata,
  F.4 tasti MT/OT secure, mock TargetUnit→error / GetPartyAssignment / GetSpellTexture).

## Novità della sessione 1.6.0 (questo branch, dopo 1.5.9) — FONT COLOR + GRUPPO TANKS + PANNELLO "RAID BUFFS"

### 1) Colore font giocatori (Config → Raid Frame → Layout → "Font color")
Color picker AceConfig (`type="color"`) che scrive `rf.appearance.fontColor = {r,g,b,a}`;
applicato da `RF:ApplyLayout()` a TUTTI i nameText (righe gruppi + barre Tanks).

### 2) Gruppo "Tanks" sopra G1 (barre Main Tank / Main Assist)
- `RF.tankHeader` (FontString dorato "Tanks", esatto) + `RF.tankSlots[1..2]` create da
  `EnsureTanks()` (chiamata in coda a `EnsureSlots`). Sono slot normali del Raid Frame
  ma `_SetupTankSlot` li tiene SEMPRE visibili quando c'e' roster (placeholder vuoti altrimenti).
- **Niente icone flask/food**: `CreateSlotFrame(i, g, tankTag)` salta `MakeConsumableIcon`
  e crea `row.tankTag` (FontString oro "MT"/"OT" dove stavano le icone);
  `UpdateConsumables` early-return su `row.isTank`.
- Popolamento da `GetPartyAssignment("MAINTANK"|"MAINASSIST", unit or name)` in
  `RF:RebuildTanks()` (Rebuild → ogni roster change). Chiave = unit o nome (fake debug).
- Fuori dalla geometria di drop dei gruppi: `t.slot = nil` + guard `not self2.isTank`
  nel drag manuale shift+sinistro. Le altre meccaniche (barra HP, nome, CD classe,
  secTarget engine-click, bordino dorato NO perché non draggabili) restano.
- Layout: header+2 barre+gap PRIMA del loop G1..G6 nel conteggio righe della finestra.

### 3) Pannello "Raid Buffs" (matrice stile Method Raid Tools)
- Bottone `buffPanelBtn` ("Raid Buffs", testo oro) sulla RIGA dell'header Tanks,
  ancorato TOPRIGHT di content (= bordo destro di barra + cd). Visibile solo col gruppo Tanks.
- Pannello `RF.buffPanel` a scomparsa (toggle OnClick), figlio della finestra RF,
  ancorato TOPLEFT → frame:TOPRIGHT (si apre a DESTRA di tutte le barre); eredita la
  scala della finestra. Backdrop scuro UI-Tooltip. Nascosto di default e in assenza di roster.
- Matrice: righe = giocatori (ordine = self.rows, ALTEZZA riga = m.rowHeight dei gruppi,
  nome class-color a sinistra), colonne = **21 categorie** `RLSuite.raidBuffColumns`
  (in Core.lua: label sintetica header + icona + spells/spellId o byNameSpell).
- Cella = icona del buff ATTIVO del player che copre quella categoria: scan
  `UnitBuff(unit, i)` 1..40; match per spellId (icona = GetSpellTexture della spell reale!)
  o per NOME aura (`byNameSpell` → GetSpellInfo(id) locale-safe: colonna Food = "Well Fed"
  di OGNI variante). Categoria mancante → cella vuota. Row dei fake → celle vuote (unita' nil).
- Refresh: UpdateAll (0.5s) + al toggle. Header con nomi sintetici in oro.
- 405 check PASS (F.3: font color applicato/ripristinato, header "Tanks", MT/OT da
  GetPartyAssignment, icone assenti, placeholders, righe gruppi invariate, bottone,
  21 colonne, header labels, passo righe == rowHeight, celle flask/Well Fed/empty, collapse).

## Novità della sessione 1.5.9 (questo branch, dopo 1.5.8) — BUFF BAR ELIMINATE + FOOD CHECK = AURA "Well Fed"

Richiesta utente: (a) eliminare TUTTE le buff/debuff bar del Raid Frame (redesign da
ripensare), tenere SOLO le icone per-riga flask/food; (b) il controllo food deve
trovare il buff "Well Fed".

Rimosso COMPLETAMENTE (codice, non solo hidden):
1. `RF.buffBar` + `RF.debuffBar` (alert bar orizzontali sotto i gruppi) e
   `RF.abilityBar` (striscia verticale a destra) con tutto il macchinario:
   `CreateAlertBar/RefreshAlertBars/PopulateAlertBar/GetAlertItem/FillAlertItem/
   UpdateAlertItems`, `BuildAbilityBar/GetAbilityButton/FillAbilityButton/
   UpdateAbilityButtons/SetAbilityButtonState`, e la famiglia coverage
   `AllChecks/GetCompClasses/CheckCoverage/CheckBuffCoverage/CheckDebuffCoverage/
   UnitHasSpellDebuff` (usata solo da quelle barre).
2. Layout: niente colonna ability (W = rowWidth), altezza finestra = SOLO righe.
3. Config: via le opzioni showBuffBar/showDebuffBar/showAbilityBar + slider
   abilityBarWidth; defaults Core ripuliti. Le tabelle dati
   `RLSuite.raidBuffChecks/raidDebuffChecks` in Core.lua RESTANO (rielaborazione).
4. Resta TUTTO il sistema consumabili per-riga: icone flask/food a sinistra,
   whisper/warning al click, toggle showFlask/showFood.

FOOD = "Well Fed" (era: whitelist spellId → dava "missing" sulle varianti non elencate):
- Nuovo `RF:UnitHasBuffName(unit, name)`: scan `UnitBuff(unit, i)` per indice 1..40,
  match sul NOME → copre OGNI variante di Well Fed (feast, spezie...).
- Il nome e' derivato a runtime da `GetSpellInfo(57399)` (Fish Feast) → locale-safe
  ("Ben Nutrito" su client IT), fallback letterale "Well Fed".
- Test F.2j: presente→off, assente→missing, flask path intatto, nome localizzato ok.
- **380 check PASS**.

## Novità della sessione 1.5.8 (questo branch, dopo 1.5.7) — HIT-TEST CON FINESTRA SCALATA (bug storico SlotAtCursor)

Bug segnalato dall'utente (respo VISIBILE dal bordino dorato 1.5.7, ma il drop era
sbagliato anche prima): trascinando un player, lo slot evidenziato era ~un gruppo
PIU' IN ALTO del cursore (es. cursore su G2/pos5 → highlight su G1/pos3).

Causa radice: i rettangoli `GetLeft/GetBottom/...` sono nello spazio della **scala
EFFETTIVA DEL FRAME**, non di UIParent. Se la finestra ha una scala propria
(`RF.frame:SetScale(db.scale)`, slider config 0.70–1.30), `SlotAtCursor()` normalizzava
il cursore per `UIParent:GetEffectiveScale()` → mismatch frazionale che cresce con la
distanza dall'ancora (finestra ancorata LEFT, scala < 1 → banda evidenziata sopra il
cursore). **Regola corretta: il cursore si divide per `frame:GetEffectiveScale()` del
frame testato.**

Fix applicato a TUTTI gli hit-test a cursore dello stesso tipo:
1. `RF:SlotAtCursor()` — per-slot `slot:GetEffectiveScale()` (drop slot + bordino dorato).
2. `RF:FireConsumableFromCursor()` — per-icona `btn:GetEffectiveScale()` (click sulle
   icone consumabili con finestra scalata).
3. `GM:WlSlotAtCursor()` — per-barra `bar:GetEffectiveScale()` (stesso bug nel pannello
   Group Making, che ha il suo slider di scala).

Non toccati (voluto): i confronti cursore-cursore per la soglia drag/click (`_pressX` vs
posizione attuale) — entrambi i lati sono nello stesso spazio grezzo, nessun mismatch.

Test F.2i: finestra/pannello al 50%: bordino sullo slot sotto il cursore VISIVO, il
vecchio punto grezzo non matcha più niente (controprova del rescale), cleanup integro;
stesso per GM (`WlSlotAtCursor`). **379 check PASS**.

## Novità della sessione 1.5.7 (questo branch, dopo 1.5.6) — BORDINO DORATO DI DROP nel Raid Frame

Richiesta utente: mentre trascini un player nel Raid Frame (Shift+sinistro, pre-boss) vedere
ESATTAMENTE dove atterrerebbe il rilascio.

1. `row.dropGlow` = Frame figlio decorativo per OGNI slot: `SetAllPoints(row)`,
   backdrop `RF_DROP_GLOW_BACKDROP` (edgeFile UI-Tooltip-Border, edgeSize 10),
   `SetBackdropBorderColor(1, 0.82, 0, 1)` dorato, riempimento trasparente, `Hide()`
   di default. **Puro-visuale**: `EnableMouse(false)` QUI è sicuro e voluto (è un
   overlay, NON lo slot — la regola ferrea sul non disabilitare il mouse vale per
   gli slot; questo non tocca la hit-region e non ruba click).
2. `RF:UpdateDropGlow()`: fonte di verità = CURSORE via `SlotAtCursor()` (gli hover
   Enter/Leave dei frame sono inaffidabili durante il drag manuale a tasto premuto).
   Solo se `_rfDragSource` attivo e drag abilitato (pre-boss); la sorgente non si
   illumina mai (rilasciarla lì = no-op). Fuori drag → tutto spento.
3. Chiamate: ogni tick del `_ArmManualDragWatchdog` (il bordino insegue il cursore
   senza bisogno di eventi di frame) + fine di `RefreshDropTargets()` (accensione
   immediata se già in hover; spegnimento totale a drop/cancel/fine drag).
4. Cancella anche nel caso in cui il watchdog si disarmi per `_rfDragSource` nil.
5. Fisica immutata: blocco pieno = swap, vuoto = move (`MoveSlot` invariato);
   nessun RegisterForDrag / nessun EnableMouse(false) sulle righe.
6. Test F.2h: glow esistente + mouse-immuned, avvio drag, nessun bordino senza
   cursore sullo slot, bordino SOLO sulla destinazione puntata, spegnimento su
   rilascio-esterno/cancel, roster integro; **374 check PASS**.

## Novità della sessione 1.5.6 (questo branch, dopo 1.5.5) — TARGET BY PRESS HARDWARE-LEVEL (engine SecureButton)

Casus belli: TUTTI i fix Lua al canale click vicinale alla barra/nome producevano zero
differenze osservabili in client; il suono-bonk del widget Button dimostrava la pressione
ricevuta ma gli script erano inaffidabili/instradabili. Soluzione DEFINITIVA: togliere il
target dal piano Lua e affidarlo ALL'ENGINE, cioè la tecnica di Grid/VuhDo/Clique per gli
unit frame.

1. `row.secTarget` = CreateFrame("Button", nil, content, **SecureActionButtonTemplate**),
   `SetAllPoints(row)` (intera barra/nome), livello content+5 (sopra la riga, SOTTO le icone
   consumabili a content+30), `RegisterForClicks("LeftButtonDown")` → TARGET AL PRIMO PIXEL
   DI PRESSIONE in hardware, `SetAttribute("type1", "target")` + `SetAttribute("unit", X)`.
   Attributi secure toccati SOLO fuori combattimento (`InCombatLockdown` guard in
   FillSlot/ClearSlot conforme al divieto Blizzard).
2. Gating: member con `unit` reale e non-fake → Show; fake/debug (unit nil) → Hide: la via
   Lua con UnitExists/TargetByName/trace rfDbg resta dietro per il debug.
3. **Handler Lua CONDIVISI** (`RowBodyOnMouseDown/Up`, estratti dai closure originali):
   identici script sulla riga E sull'overlay secure, così Shift+destro (move HUD),
   Shift+sinistro (manual drag player), icone/hit-test/RowBodyPoller/target-Lua continuano
   a funzionare ESATTAMENTE come prima nella zona coperta dall'overlay. Il trucco dell'overlay
   non ha cambiato
4. Fingerprint in-game: all'avvio RF stampa in debug `RF RaidFrame <ver> click-module attivo
   (secure overlay + press-target)` → verifica immediata di quale codice sta girando.
5. Mock: Set/GetAttribute, RegisterForClicks record, InCombatLockdown=true/false globale.
6. Test: F.2g nuovo overlay, type, LeftButtonDown, show/hide gating, gating una showed
   gating la FillSlot real unit; **368 check PASS**.

## Novità della sessione 1.5.5 (questo branch, dopo 1.5.4) — TARGET ALLA PRESSIONE + PER NOME (esattamente lo spec irrogabile)

ZTL dell'utente (irrogabile): "SE CLICCO IL NOME TARGETTI IL PLAYER CON QUEL NOME".
1. **TargetRow su `TargetByName(name)` come fallback universale**: "clicco il nome → target il
   player con quel nome" letteralmente; la via principale resta `TargetUnit(unit)` se l'unit
   e' valida (UnitExists e non fake; l'unico modo senza bonk d'errore su unit inesistenti).
2. **Target ALLA PRESSIONE (mouse-down)**: come ogni unit frame Blizzard-aderente (Grid/VuhDo/
   HealBot/cliqué): press su nome/barra → TargetRow ORA; il release/poller deduppano via TTL.
   Il mouse-down e' l'unico evento mai fallito in client in questa saga (il click-bonk del
   widget ne dava conferma). Shift+sinistro resta ESCLUSIVAMENTE drag player.
3. Il click su nome/barra non ha piu' tra-dipendenze su OnMouseUp: press lo fa tutto; rilascio
   → scrap. Muovere il cursore senza shift NON puo' piu' "cancellare" un click: e' target a
   pressione solida come sugli unit frame ufficiali.
- Test: 362 PASS con la nuova sovranità: fake → nessun bonk/nessun target; unit valida → target
  a press; nome reale senza unit → TargetByName; shift → niente; press+move → target gia' partito.

## Novità della sessione 1.5.4 (questo branch, dopo 1.5.3) — RADICE FINALE: RegisterForDrag sulle righe MANGIA GLI SCRIPT CLICK

Dato in-game: click sulla barra del PROPRIO player (unit "player" reale, fake=false) = solo il
suono del Button, nessun target, nessuna traccia rfDbg. Ne deduzione meccanica: **il frame-riga
con RegisterForDrag("LeftButton") non riceve nemmeno OnMouseDown/OnMouseUp-left su quel tasto**
(il drag manager di 3.3.5 si prende tutto il canale sinistro REGISTRATO, anche senza drag avviato;
il suono e' del widget Button, a livello sottostante, non prova di script eseguiti). Le icone
non avevano registrazione → le loro coppie down/up funzionavano (confurmato in game).

Soluzione strutturale (stessa scuola della finestra HUD 1.5.0): **Drag player 100% MANUALE**.
1. `UpdateDragState`: righe `slot:RegisterForDrag()` (senza tasti = unregister) SEMPRE, qualunque
   fase → i click nudi arrivano a TUTTI gli script, pre-boss incluso.
2. OnMouseDown Shift+sinistro: se pre-boss e c'e' un member → `_rfDragSource = row`,
   `RefreshDropTargets()` (mostra i vuoti) + `_ArmManualDragWatchdog()` (frame dedicato 1x1 con
   OnUpdate: se il release avviene FUORI dall'HUD completa comunque il drop via SlotAtCursor).
   OnMouseUp completamento: slot sotto il cursore → `MoveSlot(src, t)` + nasconde i vuoti.
3. Handlers OnDragStart/OnDragStop/OnReceiveDrag ELIMINATI (morti, il gesto non li usa piu').
4. RowBodyPoller: cancello se `_manualDrag` (il poller non targetta durante un drag); reset a ogni
   nuovo plain down.
5. Comportamento invariato per: move HUD (Shift+destro), icone (click nudi = messaggi), target
   barra (click nudo sinistro = target, ora FINALMENTE gli script vengono consegnati in qualsiasi fase).
6. Test aggiornati: le righe NON hanno drag registrato (inversione dell'invariante); simulazione
   drag via OnMouseDown/Up shift + drop fuori observer; **360 check PASS**.

## Novità della sessione 1.5.3 (questo branch, dopo 1.5.2) — TARGET BAR: era un bug DEBUG, non di click

Segnalazione utente: click sulla barra = "solo il rumore del dialog Blizzard", nessun target.
Traduzione: **TargetUnit(unit) veniva chiamata su unit che NON ESISTE nel gioco**
(il roster finto di debug: "raidX", "partyY" senza raid) → WoW suona il bonk di errore
invalid-unit e non targetta nessuno. Il canale del click era corretto.

Fix `RF:TargetRow`:
- `TargetUnit` solo se `unit` esiste (`UnitExists(unit)`) E il membro non e' fake:
  in un raid VERO → target reale istantaneo; nel roster finto di debug → niente bonk,
  solo la traccia rfDbg `RF target (unit non valida...) -> ...`.
- Mock: globale `UnitExists` (default false) + override nel test.
- Test F.2f aggiornato: fake roster → nessun target/nessun bonk; unit valida +
  membro non-fake → target; shift / cursore mosso → niente. **360 check PASS**.

## Novità della sessione 1.5.2 (questo branch, dopo 1.5.1) — CLICK SU BARRA = TARGET PLAYER

- Feature utente: **click sinistro nudo sulla barra di un player = TargetUnit(unit)**
  (qualsiasi fase, pre-boss e boss). Realizzata col pattern 1.5.x dimostrato in game:
  - `RF:RowPlainClick(row, button)`: prima hit-test icone (messaggi missing buff hanno
    precedenza), poi se nessuna icona e tasto sinistro → `RF:TargetRow(row)`.
  - `RF:TargetRow`: `TargetUnit(row.unit or row.member.unit)` con guardia TTL 0.3s
    (dedup con il poller di riserva); in debug fake roster senza unit stampa solo
    `RF target -> ...` (rfDbg) senza errori.
  - **RowBodyPoller** (locale file-level): riserva release via IsMouseButtonDown (si arma
    ad ogni down sinistro non-shift, si autodisarma; cancello su `_manualDrag`; timeout 4s).
    Da 1.5.5 e' SOLO riserva: il target scatta ALLA PRESSIONE nel plain down.
  - Shift+click barra = NO target (gesti drag); cursore mosso = NO target; click su
    icona = messaggio (NON target!) — icone hanno la precedenza.
- Mock: `TargetUnit(u) → LAST_TARGET`. Test F.2f: target barra (coppia+poller a 1),
  shift+click = niente, cursore mosso = niente. **359 check PASS**.

## Novità della sessione 1.5.1 (questo branch, dopo 1.5.0) — TRACCIATURA + SILENT-KILL LEFT CLICK

Dato utente: DESTRO funziona, SINISTRO mostra solo il print "RF icon down" e zero whisper.
Il ramo destro (funzionava) non usa `row.name` né il messaggio da config: il ramo sinistro di
`OnAlertClick` sì → **due gate silenziosi senza errori**: (a) `alerts[atype] == ""` (config salvata
con campo svuotato dall'utente in QUEL momento → per sempre nei SavedVariables, niente fallback)
e (b) `row.name` nil. In 7 versioni il whisper poteva morire lì in silenzio — o il click poteva
non arrivare, ma nessuno ne sapeva nulla: **da 1.5.1 il punto morto NON PUO' piu' nascondersi**.

1. `rfDbg()` locale in cima a RaidFrame.lua: ogni passaggio in debug stampa in chat
   "RF -- diagnostica click icone (solo debug): ogni passaggio del click lascia una
   riga in chat, cosi' un eventuale punto morto e' VISIBILE subito in game."...
   - `OnAlertClick` in ingresso: `RF alert: <atype> <button>`
   - dedup: `RF dedup: stesso click ignorato`
   - aborts: `RF abort: nessun nome sulla riga` / `RF abort: nessun messaggio per <atype>`
   - successo: `RF whisper -> <nome>: <msg>`
   - icon OnMouseUp: `RF icon up: <button> <atype>` (prova che l'up arriva)
   - Poller fire: `RF poll fire: <atype>` (prova del canale di riserva)
2. OnAlertClick sinistro HARDENED: `name = row.name or row.member.name` (stessa fonte del ramo
   destro che funziona in game); `msg = alerts[atype]; se nil o "" → GetDefaultAlertMessage(atype)`.
3. Test F.2e: config salvata `""` → whisper col msg default; `row.name=nil` → whisper con member.name.
4. Suite-row-fallback F.2b convertita a scan-pattern (i print debug shiftano gli indici di CHAT_LOG).

**356 check PASS**.

## Novità della sessione 1.5.0 (questo branch, dopo 1.4.9) — MODELLO INTERAZIONE DECISO DALL'UTENTE

<SPEC UTENTE (verbatim, da fare esattamente)>
- **Shift + left click sulla riga = sposto il player** (drag&drop già esistente, ora gated su Shift)
- **Shift + right click = sposto il Raid Frame** (la finestra HUD, da riga O da sfondo)
- **Click nudo (sinistro o destro, nessuno Shift) sulle icone = messaggio missing buff** (sinistro whisper, destro raid warning "Missing ...: n1, n2, ..." - in come di debug: whisper a se stessi col tag)
</SPEC>

"così non vanno più in conflitto": **il trucco che chiude la lite con 3.3.5** e' che il drag manager
si attiva SOLO con Shift, quindi i rilasci-click nudi sono liberi da sempre (finestra `f` NON ha
piu' nessun RegisterForDrag: la finestra si muove via `OnMouseDown/OnMouseUp` + StartMoving manuale,
proxyato anche dalle righe che la ricoprono). Dettagli:
1. `f` (finestra): `RegisterForDrag` RIMOSSO; Shift+destro down = StartMoving, Up = StopMoving + `RF:PersistAnchor` (salva point/relPoint/x/y in db.raidframe come prima del OnDragStop). Rispetta `db.locked`/`anchorMode` esattamente come il vecchio OnDragStart.
2. Righe: `RegisterForDrag("LeftButton")` resta in pre-boss, ma `OnDragStart` ora esige `IsShiftKeyDown()`; `OnMouseDown/Up` delle righe fungono da proxy Shift+destro per muovere la finestra. Gli stessi handler restano fallback di hit-test per i click nudi sulle icone (dedup TTL 0.3s invariato).
3. Icone: Shift-down = MAI messaggi (`_shiftedAtDown`); click nudo gestito dalla coppia OnMouseDown/OnMouseUp per ENTRAMBI i tasti (il canale up e' ora libero) + poller OnUpdate/IsMouseButtonDown **come riserva** solo senza shift (disarmato dopo uso, riarmato a ogni down; drag-cancel > 6px, timeout 4s tenuto giu').
4. Tooltip icone: aggiunte le righe guida "Shift + left drag on a row: move player" / "Shift + right drag: move window".
5. Mock test: `IsShiftKeyDown` va SEMPRE ripristinato a false dopo un override - gli scenari condividono un UNICO runtime e Scenario A in passato lo lasciava true (bug di suite latente, non dell'addon); mock StartMoving/StopMovingOrSizing ora registrano `_moving`.
6. Test: 354 check PASS (già inclusi: no-shift drag non parte, shift+click icone = zero messaggi, shift+destro riga/HUD muove e ferma la finestra, canali click primari+riserva deduppati).

## Novità della sessione 1.4.9 (questo branch, dopo 1.4.8)

- **CAUSA DEFINITIVA trovata col dato in-game dell'utente**: il DESTRO funzionava
  (nessun antenato ha drag sul tasto destro), il SINISTRO mostrava solo il print
  diagnostico del mouse-DOWN → **in 3.3.5 un antenato con
  `RegisterForDrag("LeftButton")` divora il mouse-UP sinistro di OGNI click
  nel suo albero** (finestra HUD draggabile + righe draggabili in preboss).
  OnMouseUp per LeftButton NEL Raid Frame e' quindi INAFFIDABILE per definizione.
- **Fix**: il rilascio-sinistro si rileva a POLLING col canale gia' provato in
  client (bordo oro drop-target): al down si arma un `OnUpdate` che controlla
  `IsMouseButtonDown("LeftButton")`; rilascio + cursore non mosso (> 6px = drag →
  cancello) = CLICK → whisper. Timeout 4s = tenuto giu', non click. **REGOLA §3
  NUOVA**: dentro l'albero di un frame con drag left NON usare mai OnMouseUp per
  click sinistri: usare polling IsMouseButtonDown + GetCursorPosition.
- Il DESTRO resta sulla coppia down/up (nessun drag sul tasto destro, e'
  piu' reattiva del poll), con hit-test riga e dedup TTL di 1.4.8 invariati.
- Lezione test: il poller si autodisarma (`SetScript(nil)` dopo l'uso); ogni
  down-sinistro lo riarma - il primo click funzionava e i successivi no, i
  test lo hanno beccato subito. Nuovi test F.2c: drag-ermo su icona non invia,
  release dopo drag-cancel non invia; smoke drag reale.
- Test: **346 check PASS**.

## Novità della sessione 1.4.8 (questo branch, dopo 1.4.7)

- **ULTIMATUM FIX click icone consumabili — smette di passare dai bottoni-icona, passa per il canale PROVATO in client**: l'utente trascina le righe del Raid Frame pre-boss → l'input mouse a livello RIGA arriva sempre; i bottoni figli (anche ri-parentati come sorelle in content, v1.4.7) restano muti in client.
  - `CreateSlotFrame`: la riga ora ha `OnMouseDown` (registra tasto + `GetCursorPosition`) e `OnMouseUp` (stesso tasto, schippa se `_rfDragSource` attivo, schippa se il cursore si è mosso > 5px = drag) → `RF:FireConsumableFromCursor(row, button)` fa hit-test col cursore (`GetCursorPosition` scalato per `UIParent:GetEffectiveScale`, stesso pattern dei drop-target WL/gold-border che in client funzionano) sui rettangoli di `row.flaskIcon`/`row.foodIcon` (GetLeft/Right/Bottom/Top), solo se l'icona è visibile e `btn._missing`.
  - **`_missing` in `SetConsumable`** (true se lo stato non è "off"): la lista "chi manca" riflette esattamente ciò che il leader vede.
  - **Dedup TTL in `OnAlertClick`**: `row._lastAlert[atype.."|"..button] = GetTime()`, schippa < 0.3s — se icona (v1.4.7, invariata) AND fallback riga entrambi sparano lo stesso click, parte UN solo messaggio.
  - Diagnostica in-game: in debug `OnMouseDown` dell'icona stampa `RF icon down: <tasto> <tipo>` (prova che l'input arriva ancora al bottone).
- **Semantica click cambiata allo spec ESATTO dell'utente**:
  - SINISTRO: whisper al player cliccato (debug: whisper a se stessi col messaggio del player — come da `Utils:Whisper`).
  - DESTRO: UN RAID WARNING che elenca TUTTI i player a cui manca quel consumabile: `"Missing flask|food buff: n1, n2, ..."` via `RF:SendMissingConsumableAlert` (debug: whisper a se stessi col tag `[RAID_WARNING]` — come da `Utils:SendChat`).
- Tooltip icona: riga destra ora dice "raid warning (everyone missing)".
- Test Scenario F: F.2 riscrive le asserzioni come SCAN pattern-based di CHAT_LOG (il print diagnostico in debug finisce nel log); F.2b nuovo: fallback riga (hit-test con geometry per-istanza + `GetCursorPosition` override, cleanup dopo), click fuori icona = niente, cursore mosso = niente, dedup TTL con `GetTime` override (1000→1000.1 = 1 msg, →1001.0 = 2 msg).

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
python3 tests/rls_ace3_test.py   # atteso: 540 PASS, RESULT: ALL CHECKS PASSED
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
