# Handoff — RaidLeadSuite (agent → agent)

Documento di passaggio per continuare il lavoro su questa repo in una nuova chat.
Branch di lavoro corrente: `arena/01a0c461-raidleadsuite` — base `main @ 0430146`
(che già include il merge della PR #4 della sessione precedente, branch
`arena/01a0aa40-raidleadsuite`, 1.11.30 → 1.11.48).
Questo file è committato nel branch, quindi **entra in `main` con la PR**.

Contesto prodotto: addon per **raid leader** su WoW **WotLK 3.3.5** (Interface `30300`),
target **Warmane**. Cartella addon: `RaidLeadSuite` (= nome del `.toc`). Versione: **1.11.82**.

## 1.11.82 — Barre Tanks inerti (come sempre) + gesto con tolleranza + `/rls rfdump`

Direttiva dell'utente: *"le barre MT/OT non sono oggetto del problema: mi sposto
dalla prima barra di G1 a un'altra in un altro gruppo"*. Quindi:

* **1.11.81 ANNULLATA**: le barre Tanks tornano a NON essere ne' sorgenti ne'
  bersagli di trascinamento (comportamento identico a prima della 1.11.77).
  Prenendo una barra Tanks la chat dice il perche' (una riga sola) e basta.
  Rimosso `GridSlotForMember`; `SlotAtCursor` cerca SOLO fra le righe dei
  gruppi (niente effetto collaterale sui drop: con `dst.slot = nil` un rilascio
  su una barra Tanks poteva pure dare errore Lua).
* **Tolleranza del gesto**: `RF:MemberRowAtCursor(tol)` con `RF_DRAG_SNAP = 10
  px`. Le righe sono alte ~20 px: un click "a filo" (5-6 px sopra/sotto/sul
  bordo) finiva nel vuoto e il gesto non faceva nulla -> da fuori sembrava che
  quel player non si potesse piu' spostare. Ora aggancia e lo dice in chat
  (`aggancio la barra 8 (Nome) a 6 px (a filo)`). Oltre la tolleranza: nessun
  effetto (niente agganci a distanza).
* **Riga non mostrata ma con un player**: dalla 1.11.76 barra/icone vivono su
  `content` (fuori dalla riga), quindi una barra VISIBILE puo' avere la riga
  non mostrata. La sorgente del gesto ora non guarda piu' `IsShown()`: se il
  player si vede, si prende (traccia: `la riga N risulta NON mostrata ma ha
  Nome: la prendo lo stesso`).
* **`/rls rfdump`**: per ogni barra con un player stampa nome, se la RIGA e' "
  mostrata/nascosta, se la BARRA e' mostrata e i rettangoli dei due, piu' il
  rettangolo della finestra: serve a capire in un colpo se cio' che si vede
  corrisponde a cio' che il mouse puo' prendere.

Test: **1084 check** (7 nuovi al posto dei 7 della 1.11.81).

## 1.11.81 — (ANNULLATA dalla 1.11.82) La barra Tanks era lo SPECCHIO del player: prendendola si trascina il player

Il log in game ha dato la risposta. Con il solo player in raid, due pressioni
che non facevano **niente**:

```
RF shift+left: NESSUNA barra sotto (88,614)
RF shift+left: NESSUNA barra sotto (72,616)
```

Stessa zona, x piccola, y alta: e' il **blocco Tanks** in cima al Raid Frame -
la barra **MT**, dove il player compare anche da solo (auto-assegnazione MT =
primo del roster). Quella barra **non rispondeva per scelta**: il drag
partiva solo dalle righe della griglia, e con un roster corto la barra
visibile e' quella in alto. Da qui "posso spostare un giocatore una volta
sola": dopo il primo spostamento la riga di gruppo se ne va in un'altra
colonna e la barra che il player prende naturalmente e' il mirror MT.

Rimedio (senza cambiare NIENTE dell'aspetto delle barre Tanks):

* `RF:SlotAtCursor()`/`_SlotUnderCursor()` ora cercano anche fra le barre
  Tanks: una pressione li' viene **risolta** da `RF:_StartDragFromSlot()` in
  `RF:GridSlotForMember()` = la RIGA della griglia che mostra lo stesso
  membro (per tabella o, nel raid vero, per NOME: ogni rebuild ricrea le
  tabelle dei membri). Destinazione del drop = come sempre uno slot dei
  gruppi; il mirror non diventa drop target.
* Le barre Tanks restano identiche: tag MT/OT, barra del target, nessuna
  icona consumabile, nessun CD, nessun piano di rilascio (test dedicato).
* Se il player mostrato dalla barra non e' nella griglia: nessun effetto, con
  traccia in chat.
* Diagnostica piu' parlante: premendo nel vuoto la chat dice quale barra con
  un player e' **la piu' vicina e a quanti pixel** (`... piu' vicina: barra MT
  (Borracciablu) a 8 px`), cosi' un gesto a vuoto dice subito se il cursore e'
  in un buco o fuori dalle barre.

Test: **1085 check** (8 nuovi).

## 1.11.80 — Diagnostica INSTALLAZIONE (`/rls diag`) + versione vera

Indizio dal campo: l'addon in chat diceva **1.11.52** mentre nel client girava
l'ultima build. Motivo: la versione era cercata con un NOME FISSO
(`GetAddOnMetadata("RaidLeadSuite", "Version")`), quindi con una cartella
storica `RLSuite` in giro - o con un `.toc` vecchio rimasto nella copia del
client - la stampa riportava la versione della copia SBAGLIATA.

Rimedio:

* `RLSuite:RefreshVersionFromFolder()` legge la versione dal .toc della cartella
  **davvero caricata** (`baseName` dall'ADDON_LOADED); la stampa all'avvio ora
  include anche il nome cartella: `v1.11.80 loaded (RLSuite)`.
* `RLSuite:AddonCopiesInfo()` / `AddonCopiesWarning()`: elenca le copie trovate
  in `Interface\\AddOns` (per i nomi `RaidLeadSuite` e `RLSuite`) con versione
  e stato caricata/no, e **avvisa in chat** se ce n'e' piu' di una. Due copie
  dell'addon insieme registrano gli stessi eventi e creano frame con gli stessi
  nomi: e' il primo sospetto quando "una cosa non funziona ma il codice e'
  giusto".
* **`/rls diag`** (alias `/rls version`): stampa cartella caricata, versione in
  uso, tutte le copie trovate e l'avviso. E' il comando da chiedere per primo
  a un tester.

Test: **1077 check** (4 nuovi): versione presa dalla cartella caricata (non dal
nome fisso), elenco copie con versione/stato, avviso che nomina la copia
vecchia e dice quale e' caricata, nessun avviso con una sola copia.

## 1.11.79 — Drag: tracce in chat + pannello Raid Group sul poller

Report dopo la 1.11.78: *"non mi fa ancora spostare piu' volte"*. La causa NON
e' riproducibile in laboratorio (la simulazione fedele del gesto passa anche
con gli handler di riga spenti), quindi questa release fa due cose:

1. **Il gesto diventa DIAGNOSTICABILE in game.** In debug mode OGNI gesto
   lascia una riga in chat (via `rfDbg`/`wlDbg`):
   - HUD, Shift+sinistra: `RF shift+left: barra 8 (Onyxia)` /
     `RF shift+left: barra 8 VUOTA (nessun player sulla riga)` /
     `RF shift+left: cursore sull'HUD ma NESSUNA barra sotto (x,y)`;
   - rilascio: `RF drag: rilascio sullo slot 12` /
     `RF drag: rilascio senza bersaglio (annullo)`;
   - rifiuti: `RF move(debug): slot N vuoto, niente da spostare`.
   Cosi' "non si muove" non e' piu' muto: o manca la pressione, o la barra
   sotto il cursore non ha un player, o il rilascio non trova il bersaglio.
2. **Pannello Raid Group sullo stesso poller dell'HUD**
   (`GM:_InitWlDragPoller`): prima il suo drag era affidato in toto al
   drag&drop del CLIENT (`RegisterForDrag` + `OnDragStart/OnDragStop`), la
   stessa macchina che in 3.3.5 digerisce pressioni e rilasci e che ci ha
   mangiato i click per 4 release. Ora il gesto (pressione -> barra sotto il
   cursore -> rilascio) e' letto dall'addon; gli handler del client restano
   come rete (`_wlDragSource` e' condiviso e chi arriva primo consuma, quindi
   non c'e' mai un doppio spostamento). Traccia: `RG drag: barra 11 (Onyxia)`,
   `RG drag: rilascio -> barra 3`, `RG drag: barra 11 VUOTA`.

Test: **1073 check** (6 nuovi): tracciato coerente su barra piena/vuota,
poller del pannello presente e a mouse spento, drag+drop del pannello SENZA la
macchina del client (spostamento su slot vuoto e SCAMBIO su slot pieno),
secondo trascinamento consecutivo dello stesso player, pressione su barra
vuota = nessun drag.

## 1.11.78 — Il drag giocatore non dipende piu' da chi riceve gli eventi

Report (1.11.76/1.11.77): *"con solo me in raid in debug posso spostare solo un
giocatore: un giocatore che ho spostato non lo posso piu' muovere; con Fill Raid
invece posso spostare chiunque"*.

Cosa ho provato PRIMA di toccare il codice: simulazioni fedeli del gesto
(pressione/rilascio consegnati al frame che il client sceglierebbe per livello
e mouse, InCombatLockdown = true, roster sparso con il solo player). **In tutte
il secondo spostamento riesce**: il percorso dati (slot sparso -> MoveSlotDebug
-> Rebuild -> riga aggiornata) e' corretto. Quindi il punto fragile non e' il
roster: e' la CONSEGNA degli eventi del mouse, che in 3.3.5 e' storicamente
inaffidabile (e' la stessa famiglia del bug dei click che ha richiesto 4
release: drag manager che divora i rilasci, frame figli/sicuri che si mangiano
la pressione).

Per questo il gesto e' stato RISC RITTO senza dipendere dagli eventi:

* **Poller del drag** (`RF:_InitDragPoller`): frame 1x1, mouse SPENTO, tick a
  20 Hz (solo se la finestra c'e'). Legge lo STATO del tasto sinistro
  (`IsMouseButtonDown`) e la POSIZIONE del cursore:
  - rising edge = inizio: se il cursore e' su una barra giocatore piena → drag;
  - falling edge = rilascio: bersaglio risolto **geometricamente** (rettangoli
    delle barre) e spostamento;
  - lo SHIFT puo' arrivare anche DOPO la pressione (basta che la pressione sia
    partita su una barra giocatore).
* **Handler di riga/piano e watchdog** restano come via secondaria, ma non sono
  piu' necessari: chi arriva primo esegue, gli altri vedono la sorgente gia'
  pulita (`_StartDragFromSlot`/`_FinishDrag` sono idempotenti).
* Le barre **Tanks MT/OT tornano NON trascinabili** (comportamento 1.11.76).
* **Rebuild a prova di errore**: ogni riga e' protetta singolarmente
  (`pcall`) e un fallimento marca `_rebuildDirty` → l'HUD si rimette in pari da
  solo al giro successivo (0.5 s). Prima, un errore su una sola riga in combat
  poteva congelare tutto l'HUD: da fuori si vedeva esattamente "non si sposta
  piu' niente".
* **Tracce di debug**: in debug mode ogni drag scrive in chat
  `RF drag: parto dallo slot N (Nome)`, `RF drag: rilascio sullo slot M`,
  `RF drag: rilascio senza bersaglio (annullo)`, `RF move(debug): slot N vuoto`.
  Se il problema si ripresenta, quelle righe dicono in un colpo dove si rompe.

Test: **1067 check** (5 nuovi): drag+drop con TUTTI gli handler delle righe
spenti, doppio spostamento consecutivo senza reset manuale, shift arrivato dopo
la pressione, rilascio fuori dalle barre = annullo, poller a mouse spento.

## 1.11.77 — (SUPERATA dalla 1.11.78) Barre TANKS trascinabili

> **ATTENZIONE — questa modifica e' stata ANNULLATA in 1.11.78.** Il report
> parlava delle BARRE GIOCATORE NEI GRUPPI, non delle barre MT/OT: il drag
> delle barre Tanks NON c'era prima e non c'e' adesso (comportamento
> ripristinato identico alla 1.11.76). La causa vera e' descritta in 1.11.78.
> Resta valida solo la suite deterministica (math.randomseed).


Report in gioco della 1.11.76: *"ora si vede tutto ma posso spostare solo UN
giocatore... un giocatore che ho spostato non lo posso piu' muovere. Sono in
debug mode con solo me presente in raid; se uso Fill Raid invece posso spostare
chiunque"*.

Perche' (due fatti che insieme spiegano tutto):

1. Le barre Tanks MT/OT **non erano trascinabili per scelta** (drag start con
   `not self2.isTank`, `t.slot = nil` in `EnsureTanks`, commento "niente drag
   player su di esse").
2. Con un roster da UNA persona il player e' **anche** l'MT (auto-fill: MT =
   primo del roster): l'HUD mostra la stessa persona due volte, la barra MT in
   alto e la riga di gruppo nella griglia. Trascinando la barra in alto non
   succedeva **niente, in silenzio**.
   Dopo il primo spostamento la riga di gruppo se ne va in un altro gruppo e la
   barra MT resta dov'e': la barra che si prende naturalmente e' quella in
   alto... e quella non rispondeva. Con Fill Raid si spostano i finti nella
   griglia -> tutto funzionava, per questo il limite si vedeva solo col roster
   corto.

Rimedio:

- Anche le barre MT/OT si trascinano (via il veto `isTank` sul drag start).
- `MoveSlotDebug` risolve lo slot sorgente **per nome** quando la barra tank non
  ha `slot` (le barre tank non stanno nella griglia dei gruppi).
- `MoveSlot` risolve l'indice raid con `RF:MemberRaidIndex()` (per nome, via
  `GetRaidRosterInfo`) quando il membro non ce l'ha: cosi' nei raid veri la
  mossa di un tank chiama `SetRaidSubgroup` come per chiunque altro.
- Dopo lo spostamento la barra MT continua a rispecchiare il player (il mirror
  tank si aggiorna da solo col rebuild).

Extra: la suite ora e' **deterministica** (`math.randomseed` all'avvio): il
test dei roll di loot era instabile ("two roll cycles..." fallito una volta su
varie corse) e faceva sembrare rotto altro codice.

Test: **1066 check** totali (8 nuovi: 4 sul roster sparse che si sposta due
volte, 4 sulle barre tank).

## 1.11.76 — Barra HP e CD FUORI dalla riga (update grafico del drag)

Report in gioco della 1.11.75: **il drop funziona** (il giocatore si sposta),
ma l'update grafico no: *"vedo solo le icone di flask/food mentre barra
giocatore e CD sono invisibili"*.

Diagnosi: e' la stessa malattia delle icone consumabili, su altri pezzi.

- le icone flask/food sono figlie di `content` (spostate li' in una fix
  precedente, proprio per questo motivo) -> restano visibili;
- **barra HP e texture dei CD erano figlie della RIGA** -> se la riga non viene
  renderizzata (in combat la riga di destinazione di un move non lo e'), loro
  spariscono con lei. Sintomo esatto: icons visibili, barra e CD no.

Rimedio:

- la barra (StatusBar) e le icone CD ora vivono su `content`, come le icone
  consumabili: barra a `content+20`, supporto CD a `content+21`. Le coordinate
  NON cambiano: tutto resta ancorato allo slot (`SetPoint(..., slot, ...)`).
- `ClearSlot` spegne ESPLICITAMENTE la barra (non sparisce piu' da sola: non e'
  piu' figlia della riga).
- `FillSlot` rimette SEMPRE i CD (`ApplySlotCDs`), non solo al cambio di
  classe: prima, svuotando e riempiendo lo stesso slot con la stessa classe, i
  CD restavano spenti.
- anche il tag MT/OT e' fuori dalla riga.

La riga adesso e' solo una zona di click/target: la grafica del player non
dipende piu' dalla sua visibilita'. Stessa filosofia dei piani di rilascio
(1.11.75) e delle icone consumabili.

Test: **1058 check** totali (5 nuovi).

## 1.11.75 — Drag in combat, seconda parte: PIANI DI RILASCIO

Report in gioco della 1.11.74: consumabili OK, tag OK; **drag in combat: si
vedono solo gli header dei gruppi, niente barre, niente bordo dorato, e il drop
non sposta il player.**

Causa trovata NEL NOSTRO CODICE (non nel client, non nei gate di fase):

- `SlotAtCursor()` pretendeva che la riga fosse visibile (`slot:IsShown()`)
  **e** che `_rfDragSource` fosse ancora valorizzato. Ma nel rilascio la
  sorgente viene azzerata PRIMA dell'hit-test: su uno slot vuoto (riga non
  visibile in combat) il bersaglio non veniva mai trovato -> niente bordo
  dorato, niente drop. Con gli slot vuoti non trovati, l'unico bersaglio
  possibile erano le righe piene.
- I visuali del drag (bordo dorato + slot vuoti) erano figli della RIGA: se la
  riga non si mostra, non si mostra nemmeno il figlio.

Rimedio (v1.11.75):

- **PIANO DI RILASCIO**: un frame SEMPLICE (nessun template, nessun attributo,
  quindi mai protetto) per ogni slot di gruppo, sopra tutto (content+40).
  Fuori dal drag: nascosto e col mouse spento, zero interferenza con click e
  icone. Durante il drag: bordo tenue + riempimento scuro sugli slot VUOTI
  (ora si VEDONO), bordo tenue sulle righe piene (li' si scambia), bordo
  DORATO sul bersaglio sotto il cursore. I piani ricevono OnMouseDown/OnMouseUp
  con gli stessi handler delle righe: in combat non possono essere bloccati.
- `_dropActive`: flag di "drag in corso" che sopravvive all'azzeramento della
  sorgente, usato dall'hit-test geometrico di `SlotAtCursor()`.
- Il watchdog del rilascio (tasto mollato fuori dalle righe) passa dalla stessa
  strada: testato anche quello.

Test: **1053 check** totali (9 nuovi: piani, righe bloccate, dorato, drop dal
piano e dal watchdog).

Diagnostica per il prossimo test in gioco: se il bordo dorato compare ma il
player NON si muove, allora il blocco e' a valle (chiamata al client rifiutata
dal core) e va riportato PRIMA di qualunque ripiego.

## 1.11.74 — Passata 5: drag & drop dei player DURANTE il combat

Direttiva: *"no voglio che sia instant la modifica, se sposto di barra nel raid
frame un player mentre sono in combat e' per un valido motivo che serve DURANTE
IL COMBAT non dopo"*.

**Causa vera (verificata, non ipotizzata): il blocco era NOSTRO.** Su 3.3.5
`SetRaidSubgroup`/`SwapRaidSubgroup` NON sono protette (la protezione arriva
con Cataclysm 4.0.1); era `RF:IsDragEnabled()` a permettere il drag solo in fase
"preboss", quindi in infight il drag non partiva nemmeno e sembrava colpa del
client.

- `RF:IsDragEnabled()` ora torna **sempre true**: nessun gate di fase, nessuna
  coda, nessun "applico a fine combat". La modifica e' istantanea.
- Aggiornati i commenti di `UpdateDragState` / `RefreshDropTargets` / `MoveSlot`
  (i blocchi vuoti restano visibili solo MENTRE si trascina, ora in qualunque
  fase).
- Le test v1.11.63 che pretendevano "drag disabilitato fuori da pre-boss" sono
  state aggiornate al comportamento nuovo (era la documentazione del gate).
- Resta invariato: solo raid leader/officer possono riordinare (messaggio in
  chat), drag = Shift+tasto sinistro, il rilascio fuori dall'HUD annulla.

Da provare in gioco (2 minuti): in combat, Shift+click su un player e rilascio
su un altro gruppo. Se sul core privato la chiamata andasse a vuoto (capita su
alcuni core), riportare PRIMA di qualunque ripiego: la strada e' il chiamante
(`MoveSlot`), non un workaround di fase.

Test: **1044 check** totali (5 nuovi).

## 1.11.73 — Passata 4: TAG taglia+difficolta' ("25H")

Direttiva: *"aaah e' nel combat log intendi, allora si il tag va bene inserirlo"*.

Il lettore del tag esisteva ma non era mai alimentato: `GetInstanceDifficulty`
non veniva mai chiamata, quindi `FightSizeTag` tornava sempre "".

- `CL:DifficultySnapshot()` legge, in ordine di affidabilita':
  1. `GetInstanceInfo()` -> tipo di gruppo, indice, **maxPlayers** e, per le
     istanze dinamiche (ICC/ToC/RS), `dynamicDifficulty` (1 = heroic). E' l'unico
     modo per non sbagliare la taglia quando la modalita' si cambia dentro
     l'istanza, come a ICC.
  2. `GetInstanceDifficulty()` -> tabella 3.3.5 post-3.2: 1/2 = dungeon,
     3 = 10 normal, 4 = 25 normal, 5 = 10 heroic, 6 = 25 heroic.
  3. numero di membri del raid (ultimo ripiego, solo taglia).
- **Correzione importante**: la vecchia mappa del tag era quella di Cataclysm
  (1 = 10N, 2 = 25N, 3 = 10H, 4 = 25H) e su 3.3.5 avrebbe scritto "25H" su un
  raid 25 NORMAL. Ora la lettera esce solo quando la modalita' e' dedotta
  davvero; se non lo e', esce la sola taglia ("25"), mai una lettera inventata.
- Il tag viene letto **all'apertura** del pull (quando si e' certamente dentro
  l'istanza) e riletto alla chiusura; se nel frattempo si e' usciti non si
  perde.
- Dove si vede: titolo grande ("1:40.000  Deathbringer Saurfang 25H  Kill"),
  riga del selettore dei pull, voce del pull IN CORSO e vista unificata
  ("All <boss> segments", che prende il tag del segmento piu' recente).
- Fuori raid (dungeon da 5, open world) nessun tag.

Test: **1039 check** totali (13 nuovi).

## 1.11.72 — Passata 3: consumabili per SPELL ID

Direttiva: *"implementa lo spell id per le funzioni necessarie"*.

**Difetto trovato verificando gli id (non ipotizzato):** il nome della SPELL di
un consumabile non e' il nome dell'item. `Potion of Speed` usa la spell
**"Speed"**, `Potion of Wild Magic` usa **"Wild Magic"**: il match per nome
("potion", "elixir") **non le contava affatto**, su qualunque client. Quindi la
tab Consumables perdeva la pozione piu' usata del gioco.

- `CL_CONSUM_IDS` = id -> categoria, con gli id **verificati** su 3.3.5:
  53908 "Speed" (Potion of Speed), 53909 "Wild Magic" (Potion of Wild Magic),
  53763 "Protection" (Elixir of Protection).
- Il rilevamento per id viene PRIMA; i pattern per nome restano come fallback
  per gli id non in tabella; flask/food restano dalle liste curate (gia' per id).
- Un buff qualunque non viene contato (verificato: "Arcane Intellect" fuori).
- Il dedup cast+aura continua a valere (Potion of Speed con cast e aura = 1 uso
  per player, non 2).
- Come aggiungere una voce: una riga in `CL_CONSUM_IDS`. L'id si legge nel tab
  "Spells" del pannello con l'opzione `showSpellIds`, o nella pagina Wowhead
  dell'item (campo "Use:").

Test: **1026 check** totali (7 nuovi).

## 1.11.71 — Passata 2: lista boss UNICA + bersaglio principale + trash-first

Direttiva: *"il target per etichettare il pull … usa il target anche per
filtrare i trash. Usa la lista completa delle macro"*.

**Correzione di una mia misura sbagliata.** In audit avevo scritto che il Log
riconosceva 56 id e ne mancavano 93 rispetto alle macro: era un errore di
misura (una regex troppo larga usata nei miei script di analisi). La verifica
corretta: la lista delle macro (`RLSuite.bossUnits`) ha **56 id** e la vecchia
lista del Log li copriva **tutti**. L'unificazione resta giusta (una sola
fonte: se domani aggiungi un boss alle macro, il Log lo riconosce da solo), ma
NON era un bug con 93 boss a zero danno utile.

Cosa cambia:
- `CL:EnsureBossIndex()` costruisce l'indice dei boss **da `RLSuite.bossUnits`**
  (id -> nome, nome minuscolo -> nome). La tabella scritta a mano nel Log e'
  sparita: `CL_BOSS_SET`/`CL_BOSS_BYNAME` sono riempiti dall'indice.
- `CL:MainTarget(f)` = NPC che ha preso **piu' danno** dai membri del raid (con
  ripiego sul bersaglio piu' colpito se il pull e' di soli heal).
- `CL:CloseFight`: il pull viene **etichettato col bersaglio principale**
  (`f.target`) e classificato `f.isBoss`. Un boss che compare ovunque nel pull
  (anche solo come sorgente) tiene il pull come BOSS: meglio un trash marcato
  boss che un boss perso.
- `f.name = f.boss or f.target or "Combat"`: niente piu' `Combat` x N nel
  dropdown, ogni pull di trash porta il nome del mob che hai ucciso.
- **SFRATTO TRASH-FIRST**: a cap raggiunto esce il trash piu' vecchio, mai un
  boss (verificato: cap 3 con 1 boss + 3 trash -> il boss resta).
- **Override manuale**: click destro sul selettore dei pull -> il pull
  selezionato passa boss <-> trash (copre Gunship Battle, Faction Champions e
  qualunque caso fuori lista). Il pull in corso non si tocca (avviso).
- Nel log il **counter di progressione NON si usa**: durante il progress
  qualunque trash verrebbe marcato come il boss "prossimo" (Gunship). Per i due
  buchi vale l'override manuale, approvato dall'utente.

Test: **1018 check** totali (10 nuovi: copertura completa dell'indice, raid da
un solo boss, id ignoto, etichetta trash, etichetta boss, boss-sorgente,
sfratto trash-first, override manuale, click destro sull'handler, pull in corso
non riclassificabile, conteggi boss/trash nella riga di stato).

## 1.11.70 — Passata 1: pull legato all'ENCOUNTER + watchdog + riga di stato

Direttiva: *"utilizza lo stesso metodo di DBM, lega il pull all'encounter"* +
*"diagnostica combat log: implementa riga di stato e watchdog"*.

**Il difetto vero (misurato nel codice):** l'unica porta di chiusura era
`CL:OnRegenEnabled` (PLAYER_REGEN_ENABLED). Morire toglie dalla hate list,
quindi quel evento scatta **quando il tuo personaggio muore**: il pull veniva
chiuso a meta' con esito `falso Wipe`, il CLEU veniva deregistrato (il resto del
pull, kill compreso, non registrato) e una res in combat faceva partire un
**secondo** record per lo stesso encounter.

**Ora (encounter-anchored, metodo DBM):**
- `CL:EncounterActive()` = il tuo personaggio, **boss1..boss4 in combattimento**,
  oppure un membro di gruppo/raid ancora in combattimento.
- Apertura: `PLAYER_REGEN_DISABLED` (via rapida) **oppure** il watchdog quando
  rileva un encounter attivo (apertura marcata `recovered`).
- Chiusura: nessuno piu' in combattimento, **oppure** kill di un boss
  riconosciuto senza altri boss vivi (`CL:BossAlive()` = boss1..boss4 con vita
  > 0: gli encounter multi-boss NON si chiudono alla prima morte).
- **La tua morte e' un evento del pull** (`f.playerDied`), la ripresa anche
  (`f.playerAlive`): il pull continua e la tab Deaths la usa.
- **Res in combat = stesso record** (nessun pull fantasma).
- **Re-arm**: `PLAYER_ENTERING_WORLD` -> se sei in combat il pull riparte
  (dopo un `/reload` in pull si perde comunque la parte precedente).
- **Un solo tick da 1 Hz** (`WatchTick`) = campioni + watchdog; prima i campioni
  avevano un timer creato/distrutto a ogni pull e **nessun** controllo di stato
  (un evento perso lasciava il log muto per tutta la sessione).
- Modulo disattivato -> il pull aperto viene chiuso (`closeReason = "disabled"`).

**Riga di stato** (`CL:RefreshInfo`), 1 volta al secondo quando la finestra e'
visibile:
- `Recording 1:23 · 3721 Events · Deathbringer Saurfang` (verde)
- `... · recovered by watchdog` (giallo) / `... · 12 events lost` (rosso)
- `Recording ... · you died at 0:47` quando sei morto nel pull
- a riposo: `Idle · 8 pulls (5 boss, 3 trash)` (+ recuperi o eventi persi)
- `Window error: <testo>` (rosso) se la finestra non si e' costruita: l'errore
  non resta piu' solo in chat.
- Priorita': eventi persi (grave) > recuperi (auto-riparato).

**Test:** +18 check (1008 totali): morte che non chiude, morte annotata e pull
che continua, res senza pull fantasma, chiusura a fine encounter, motivo di
chiusura salvato, kill con trash a catena, multi-boss, watchdog che apre e
marca il recupero, re-arm da PLAYER_ENTERING_WORLD, i 6 stati della riga di
stato, pull vecchi (senza campi nuovi) ancora apribili.

## 1.11.69 — audit: la versione mostrata in chat viene dal .toc

Dall'audit completo prima del test in gilda: `RLSuite.version` era una costante
nel codice, ferma a **1.11.48** mentre il `.toc` era 1.11.68 e il README 1.11.16.
Tre numeri diversi = nessuna segnalazione dei tester tracciabile.

Ora `RLSuite.version` si legge da `GetAddOnMetadata("RaidLeadSuite", "Version")`
(dentro pcall), con la costante nel codice solo come fallback. Due check nuovi:
uno confronta `RLSuite.version` col valore nel `.toc` (fallisce se qualcuno
bumpa il .toc e dimentica il fallback), l'altro verifica che Core usi la
metadata.

Test: **990 check** totali.

## 1.11.68 — Log: icone E nomi delle spell visibili (non solo tooltip)

Domanda dell'utente: *"perche' non vedo le icone o i nomi delle spell?"*.
Due problemi reali:

1. `GetSpellTexture(sid)` in 3.3.5 puo' non risolvere l'id (spell non in
   cache): l'icona restava `nil` e, siccome per le colonne a icona il `label`
   era **vuoto**, l'intestazione diventava **completamente vuota** (ne' icona
   ne' nome). Ora:
   - `CL:SpellIcon(sid)` prova `GetSpellTexture` e poi l'icona di
     `GetSpellInfo` (3o valore), con **cache** (`CL_ICON_CACHE`);
   - le colonne di Consumables/Auras/Powers passano SEMPRE anche il nome
     (`label = Trunc(name, 12)`);
   - l'intestazione e' alta **34px**: ICONA sopra (18x18) + NOME sotto;
   - se l'icona non c'e', resta il nome: **mai una colonna anonima**.
2. I nomi delle spell erano visibili solo al passaggio del mouse: risolto con
   il nome sotto l'icona + icona accanto al nome nella lista del tab "Spells"
   (riga con texture + testo).

Test: **1026 check** totali (7 nuovi nella 1.11.72); 988 nella 1.11.68 (risoluzione icona, fallback GetSpellInfo,
nessuna spell = nessuna icona, "vuote=0" per Consumables/Auras/Powers, altezza
intestazione, icona+nome nell'header, nome al posto dell'icona se manca, icona
nella lista Spells).

## 1.11.67 — Log: FINE delle tabelle impilate fra le tab

Sintomo segnalato: *"le tab mostrano ancora testo sovrapposto, come se
condividessero la stessa unica tab Damage/Powers/Targets/Consumables/Auras"*.

Causa VERA (diversa da quella della 1.11.66): il pool delle righe della
griglia e' diviso PER NUMERO DI COLONNE (`g.pool[#cols]`) e nascondeva SOLO il
pool della tab corrente:

```lua
for _, r in ipairs(pool) do r:Hide() end   -- solo il pool corrente!
```

Passando da `Damage` (6 colonne) a `Targets` (5) o `Auras` (3) le righe della
tab precedente restavano VISIBILI e la nuova tabella si disegnava sopra:
l'effetto era "tutte le tab sono la stessa tabella". Ora si nascondono le righe
di TUTTI i pool:

```lua
for _, p in pairs(g.pool) do for _, r in ipairs(p) do r:Hide() end end
```

Test di regressione (4): per ognuno dei tab Damage/Targets/Consumables/Auras/
Powers le righe visibili DEVONO essere pari a quelle della tabella corrente
(`damage:6col:3row:3vis | targets:5col:3row:3vis | consumables:6col:2row:2vis |
auras:3col:2row:2vis | powers:3col:3row:3vis`), le tabelle hanno davvero un
numero di colonne diverso (era il caso che le impilava), tornando su Damage la
tabella e' identica, e la griglia dei morti mostra solo le sue righe.

Test: **978 check** totali.

## 1.11.66 — Log: sovrapposizioni vere (misura testo 3.3.5) e celle vuote

Dopo la 1.11.65 le tabelle risultavano ANCORA sovrapposte in game. Due cause
reali, trovate leggendo il comportamento di 3.3.5:

1. **`GetStringWidth()` in 3.3.5 non vede il `SetText` appena eseguito** (il
   testo viene misurato solo al frame successivo). Quindi `FitText` misurava
   il testo VECCHIO (o 0), il troncamento non scattava mai e i testi lunghi
   uscivano dalla colonna, sopra la colonna vicina.
   Fix: `TruncTo` usa una **stima per carattere** (`CharW`, misurata una volta
   su "MMMMMMMMMM" con il font di gioco) come rete di sicurezza, e poi rifinisce
   con la misura reale quando disponibile; le intestazioni hanno anche una
   seconda passata differita (150ms via OnUpdate) quando il client ha misurato.
   Nuovo `CL:FitPass(g)` dopo ogni render per le FontString riciclate.
2. **Celle vuote non nascoste**: il pool e' per NUMERO di colonne, quindi
   cambiando tab una riga riusata con meno colonne lasciava visibili i testi
   della tabella precedente (sovrapposizione fra tabelle diverse).
   Fix: quando una cella non ha dato -> `cell.fs:Hide()`.

3. Altre difese: pelo verticale fra le colonne nell'intestazione (rendono
   visibile subito un disallineamento), etichette dei bersagli piu' corte
   ("*Nome" a 10-12 caratteri, tooltip col nome completo), `_initError` salvato
   in `CL.Init` (e test che fallisce se la finestra non si e' costruita: il
   pcall della 1.11.64 aveva nascosto per un attimo un errore vero).

Test: **974 check** totali (4 nuovi: init senza errori, pannelli presenti,
troncamento con misura "stantia" del client, testi che ci stanno non toccati).

## 1.11.65 — Log: tabelle non piu' "incasinate" + TAB GROUP vero

Due difetti visti in game nella v1.11.63/64:

1. **tabelle illeggibili** (testo mescolato fra le righe). Causa: le celle
   avevano il **word wrap attivo** e una larghezza forzata: i testi piu' lunghi
   andavano a capo, la FontString cresceva in altezza oltre la riga (20px) e la
   seconda riga finiva SOPRA la riga successiva -> numeri e nomi mescolati.
   Inoltre le colonne erano misurate su una larghezza FISSA (838px) mentre la
   finestra si puo' ridimensionare (nel caso reale era ~1400px): intestazioni e
   celle non erano allineate.
   Fix: `CL.FitText` (testo troncato misurando `GetStringWidth`, max 8 passi),
   `SetWordWrap(false)` + `SetNonSpaceWrap(false)` + `SetMaxLines(1)` su OGNI
   cella e su OGNI intestazione, larghezza colonne presa dalla griglia VERA
   (`g:GetWidth() - 30`) con fallback al valore di progetto, intestazioni
   allineate come la colonna (LEFT/RIGHT/CENTER).
2. **tab = pulsanti sparsi**. Ora c'e' un vero **TAB GROUP**: contenitore unico
   `RLSuiteCombatLogTabs` con strip di sfondo, tab nominati
   `RLSuiteCombatLogTabsTab<i>` (cosi' funziona `PanelTemplates`, che cerca
   `<parent>Tab<id>`), template `CharacterFrameTabButtonTemplate` con ripiego su
   `UIPanelButtonTemplate` (flag `_plainTab`), larghezza UNIFORME che riempie il
   gruppo, tab ATTACCATI (overlap 16px col template, 0 col ripiego),
   `PanelTemplates_SetNumTabs`/`SetTab` + evidenza propria (`_sel` +
   LockHighlight) perche' la selezione si veda in entrambi i percorsi.
   Etichette dei tab anch'esse senza wrap (FitText).
3. Bug trovato dai test: aprendo Targets/Consumables/Auras/Powers **senza pull
   registrati** `GridMeasure` faceva aritmetica su `w = nil` -> errore Lua.
   Ora colonne di ripiego valide + `c.w = tonumber(c.w) or 60` (difensivo).
4. Testata: il sottotitolo (data + player) e' ancorato a SINISTRA del dropdown
   dei fight (prima finiva sotto/dentro il selettore a finestra larga) e il
   nome del fight nel dropdown e' troncato a 24 caratteri.

Test: **970 check** totali (13 nuovi: gruppo unico, tab contigui e di pari
larghezza, selezione singola, ID dei tab, FitText, zero wrap nelle celle,
testo dentro la colonna, larghezza viva, nessun crash senza dati).

## 1.11.64 — fix crash: ScrollFrame senza nome (pannello Log, v1.11.63)

Errore segnalato in game:

```
..\FrameXML\UIPanelTemplates.lua line 255: attempt to concatenate a nil value
   ScrollFrame_OnLoad() <- CreateFrame()
   RaidLeadSuite\CombatLog.lua:1494: NewGrid() <- 2163: CreateFrame() <- 229: Init()
```

Causa: in 3.3.5 `ScrollFrame_OnLoad` fa `self:GetName() .. "ScrollBar"`, quindi uno
`CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")` va in
errore. Le due griglie nuove (tabella principale + recap dei morti) erano create
senza nome -> **il load dell'addon si interrompeva** (Count: 2 = i due NewGrid).

Fix:
- `CL:NewGrid(parent, name)` ora PRETENDE il nome globale; le griglie sono
  `RLSuiteCombatLogGrid` e `RLSuiteCombatLogDeathGrid` (gli ScrollFrame storici
  Left/Right/Deaths erano gia' nominati);
- `CL:Init` costruisce la finestra dentro un `pcall`: un errore di UI non
  blocca piu' il caricamento dell'addon (la cattura dei pull resta attiva e
  l'errore viene stampato in chat), + guardie in `Toggle`/`RefreshUI`;
- audit di tutto l'addon: nessun altro ScrollFrame/DropDownMenu/FauxScrollFrame
  creato senza nome;
- **harness**: il mock ora riproduce il crash reale (errore se uno ScrollFrame
  con template non ha nome) -> 5 check nuovi: nomi delle griglie, barre del
  template, nominati anche gli storici, harness che rifiuta il caso, scan di
  tutti i file per `CreateFrame("ScrollFrame", nil`.

Test: **957 check** totali.

## 1.11.63 — pannello Log rifatto: layout e viste stile UwU Logs

Richiesta: *"overhaul grafico del pannello di log ... stesse funzionalita' di
uwulogs"* (grafico sempre visibile + tab Targets/Consumables/Auras/Deaths/Powers).
L'aspetto (texture/colori) non conta: **conta la disposizione**.

Nuovo layout della finestra `Log` (900x660, minimi 870x660 in `windowMins.log`):

```
[durata + nome boss + taglia + esito]        [data, ora - player] [fight ▼]
[Show graph] [Avg whole fight ▼] [DPS][Health][Power]  <etichetta serie>
+-------------------------- GRAFICO (150px, SEMPRE visibile) ----------+
[Damage][Targets][Consumables][Auras][Deaths][Powers][Healing][Spells][Entities][Interrupts]
+-------------------------- contenuto del tab -------------------------+
[Send report][Clear][Live]  info
```

- **In alto a sinistra**: `0:02:31.994  Gunship 10H  Wipe` (durata + nome +
  taglia/difficolta' + esito). Il taglio `10N/25H` e' DEDOTTO da
  `GetNumRaidMembers` + `GetInstanceDifficulty` (guardato con pcall): da
  verificare in game, se sbaglia si leva.
- **In alto a destra**: dropdown di scelta del fight. Voci: i pull salvati
  (`durata | Kill/Wipe  Nome`) + **"All <boss> segments"** = tutti i pull di
  quel boss concatenati su una linea di tempo continua (`CL:MergedFight`,
  ultimi 8, in ordine cronologico).
- **Grafico sempre visibile** (pannello suo, 150px) con le 6 discretizzazioni
  di UwU: `Avg whole fight` (DEFAULT: media cumulativa = curva che sale e si
  appiattisce), `Avg every second`, `2/3/5/10 seconds`. La casella "Show graph"
  lo spegne/riaccende.
- **Tab** (ordine UwU: Damage, Targets, Consumables, Auras, Deaths, Powers,
  poi gli storici Healing/Spells/Entities/Interrupts):
  - `Damage`: griglia `Name | Rank | Dps% | Useful Damage | Heal | Damage Taken`
    con riga TOTAL in testa e barre rosse/verdi (danno utile/cure/subito).
    Dps% = danno utile / durata. Click su una riga = grafico su quel giocatore.
  - `Targets`: `Name | Useful | Total` + una colonna per bersaglio NPC (i boss
    sono marcati `*`, tooltip "conta come danno utile"). Colonne = top N che
    entrano nella larghezza (max 110px l'una).
  - `Consumables`: `Name | Uses` + colonne con l'ICONA della spell. Flask e
    "Well Fed" per ID (liste gia' curate in `RLSuite.buffData`), pozioni/elisir
    per NOME ("potion/elixir/flask/feast/rum/...", client EN). Un uso = un
    cast o un'aura (max dei due conteggi: cast+aura non conta doppio).
  - `Auras`: `Name` + una colonna per aura (icona) con `applicazioni uptime%`.
  - `Deaths`: lista dei morti a sinistra (ora + killer), a destra il recap
    stile UwU: `Time | Flag | Source | Spell | Type | Value | Over/Stacks`
    (12s prima della morte: DAMAGE con overkill, HEAL con overheal, CAST).
  - `Powers`: `Name` + una colonna per spell che ha generato risorsa + `TOTAL`,
    con riga Total in fondo.
- **Danno "utile"** = danno i cui bersagli sono NPC boss noti (`CL_BOSS_NPC`,
  flag `CL_E.BOSS=17` messo in cattura). Gli ADD importanti NON sono boss noti
  (es. Skybreaker Sorcerer del Gunship in UwU): per ora non contano come utili.
- Icone nell'intestazione con tooltip (nome della spell/aura), righe con
  tooltip di dettaglio, zebra + riga TOTAL evidenziata.

Test: **952 check** totali (45 nuovi): aggregazioni su un fight sintetico
deterministico (utile/totale/subito/cure, bersagli, consumabili, aure con
uptime, risorse, morti + recap con overkill), title/label dei fight, merge dei
segmenti, le 6 discretizzazioni e la serie cumulativa, colonne/righe dei tab,
struttura della finestra (grafico sempre visibile, ordine dei tab, minimi).

## 1.11.62 — Raid Frame: griglia IMMOBILE (le barre non saltano piu' in cima)

Bug segnalato: *"se il raid e' vuoto e mi sposto in un gruppo a caso, la barra
viene spostata in cima sminchiando tutto il buff check"*. Due cause, entrambe
in `RaidFrame.lua`:

1. **impacchettamento elastico** — header/slot dei gruppi vuoti venivano
   nascosti e la colonna si "ri-compattava" dal fondo: con un roster quasi
   vuoto, il player di G6 finiva disegnato a `y = -68` (in cima) invece che a
   `y = -692` (in fondo), e la finestra cambiava altezza (20 / 96 / 792) ->
   con l'ancora a centro-sinistra si spostava TUTTO;
2. **strip del buff check agganciata all'header G1** — con G1 vuoto la riga
   delle icone di categoria non si mostrava affatto (`g1Shown`).

Fix: **griglia fissa** — la geometria di `ApplyLayout` non dipende piu' dal
roster. Ogni gruppo ha SEMPRE il suo blocco (header + 5 righe), il blocco
Tanks (header + 2 barre) e la zona strip in alto sono riservati sempre, anche a
raid vuoto. La finestra ha quindi **altezza costante** (792 px con i default) e
non cambia MAI dimensione: la y di una barra dipende solo dal suo gruppo.
- chi sta in **G6 sta sempre in fondo** (`y = -692`), anche da solo in raid;
- la y di ogni gruppo e' identica a raid pieno (G1 -82, G2 -204, ... G6 -692):
  nessuna ricompattazione, nemmeno durante il drag (gli slot vuoti che si
  mostrano come drop target non spostano piu' niente);
- la strip del buff check resta in cima (`y = -54`) e le icone di categoria si
  vedono se c'e' un roster, anche con **G1 vuoto**;
- accendere/spegnere il tasto "Raid Buffs" non muove nulla (era gia' cosi'):
  ora vale anche per il passaggio roster vuoto <-> roster pieno.

Test: **988 check** totali (10 nuovi nella 1.11.68): altezza costante con raid
vuoto/1 player/pieno, G6 in fondo anche a raid vuoto, y uguali fra roster pieno
e quasi vuoto, banda fra gruppi costante, icone del buff check visibili con G1
vuoto e alla stessa y, celle della matrice allineate alla riga del gruppo,
drag senza spostamenti, tasto "Raid Buffs" nascosto a roster vuoto.

## 1.11.61 — la matrice di MAIN BAR si apre a DESTRA DELLA BARRETTA

(La 1.11.60 aveva ancorato alla barretta la matrice della **MacroBar**: era un
fraintendimento — la richiesta riguardava la matrice della **main bar**.
`MacroBar.lua` e' stato RIPRISTINATO esattamente allo stato precedente e i suoi
test rimossi.)

Cosa fa la 1.11.61:
- la **barretta** (barra in alto) e' l'ancora: `TOPLEFT` dello schermo a
  `x = larghezza Raid Frame` (298 a scala 1), `y = 0` -> tocca il bordo alto,
  subito a destra del Raid Frame;
- il **pannello dei pulsanti** (la matrice dei tasti) e' ancorato
  `TOPLEFT -> TOPRIGHT della barretta` con 4px di distacco e sommita' allineate
  (`dy 0`): si APRE A DESTRA DELLA BARRETTA, come richiesto;
- il tasto **"Raid Control"** nella barretta apre/chiude proprio quel pannello,
  che compare a destra della barretta;
- larghezze invariate: barretta = somma dei suoi elementi (205 px), pannello =
  213 px (4 + matrice 188 + 4, mai piu' stretto della barretta);
- l'ancoraggio segue il Raid Frame: se cambia la larghezza del Raid Frame la
  barretta (e con lei il pannello) si sposta.

Test: **907 check** totali (4 nuovi nella 1.11.61: pannello ancorato alla
barretta con dx 4 e dy 0, barretta = somma elementi, MacroBar NON piu' ancorata
alla barretta e senza override manuale, "Raid Control" che apre il pannello a
destra).

## 1.11.59 — barretta: larghezza = SOMMA DEI SUOI ELEMENTI + ancoraggio dal SINISTRO

Due richieste dell'utente (la 1.11.57 le aveva interpretate male):

1. **La barretta (barra in alto) ha larghezza FISSA = somma dei suoi elementi**:
   `4 + icona fase(16) + 4 + nome fase(riserva misurata) + 4 + Raid Control + 4
   + X(11) + 4` = **205 px** con "Raid Control" largo 100 (misurato sul testo).
   NON e' piu' "stirata" sulla larghezza della matrice dei tasti: con la matrice
   larga restava un vuoto enorme fra il nome della fase e Raid Control.
   La barretta e' ancorata `BOTTOMLEFT -> TOPLEFT` del pannello (dx 0, dy 2):
   resta quindi allineata a sinistra, sopra il pannello.
   Il nome della fase ha il posto riservato del nome piu' lungo, quindi la
   larghezza NON cambia al cambio fase.
2. **Ancoraggio dal lato SINISTRO** (l'utente aveva indicato il lato sbagliato):
   `SetPoint("TOPLEFT", UIParent, "TOPLEFT", +RaidFrameWidth(), -(20+2))`.
   Con la larghezza Raid Frame attuale (298 a scala 1) la barra parte 298 px dal
   bordo sinistro, cioe' subito a destra del Raid Frame; l'offset segue il Raid
   Frame (verificato: barra player +40 -> la barra si sposta di 40 a destra).

Il pannello resta largo `2*PAD + max(matrice, barretta)` = 213 px con 2 colonne,
cosi' nessun tasto sporge dal bordo (i tasti restano a 4 px dal bordo sinistro).

Test: **894 check** totali sul branch (6 aggiornati nella 1.11.59: barretta = somma elementi con
ancoraggio singolo, larghezza costante 1 vs 8 colonne, ancoraggio TOPLEFT con
x = +larghezza Raid Frame, spostamento a destra quando il Raid Frame si allarga).

## 1.11.58 — grafico del combat log: da "barrette" a CURVA DPS continua

Segnalato dall'utente (screenshot del tab Graphs): "crea una barra ogni secondo
col danno totale ... perche' non mi esce una linea continua ma sto accrocchio di
barrette?".

**Causa**: il disegno tentava una POLILINEA: ogni tratto era una texture-ruota
con `Texture:SetRotation`. Ma SetRotation ruota il DISEGNO *dentro* la texture
(mappa UV), non il rettangolo del widget: su un colore piatto (WHITE8x8) non
cambia assolutamente niente, quindi ogni tratto restava una barretta
ORIZZONTALE della lunghezza del segmento -> il "pettine" nello screenshot.

**Rimedio** (come fanno Recount/Skada, nessuna rotazione richiesta):
- la curva e' fatta di **colonne larghe 2px** che riempiono l'area sotto il
  valore (verde tenue) con sopra il **cap luminoso** che va dal valore minimo al
  massimo della colonna: il bordo superiore e' la curva interpolata, quindi
  **continua** anche nei tratti ripidi;
- `graph:ValueAt(x)` = valore interpolato linearmente in qualunque punto della
  serie (usato dal disegno e dal tooltip);
- **griglia** al 25/50/75%% dello scale + massimo in cima all'asse Y;
- **lettura col mouse**: passando sul grafico compare un tooltip con
  `m:ss` e valore nell'unita' del modo attivo (DPS / HP%% / Power%%); la linea
  verticale bianca segue il cursore;
- il testo d'aiuto ora dice "drag: zoom, click: reset, hover: values".

Nota: la serie NON cambia: e' gia' DPS (danno del bucket diviso i secondi del
bucket). Con "Step 1s" e' il DPS di quel secondo; il picco nell'etichetta in alto
a sinistra (es. 18.1k) e' il massimo del range visibile.

Test: **880 check** totali (9 nuovi nella 1.11.58: nessuna texture ruotata nel
codice di disegno, ValueAt interpolato/clampato, 318 colonne con cap,
continuita' fra colonne adiacenti, altezze proporzionali ai valori, 3 righe di
griglia, tooltip di lettura).

## 1.11.57 — main bar: tasti aderenti, "Raid Control", larghezza fissa, ancoraggio dal Raid Frame

Quattro richieste dell'utente sul layout della main bar:

1. **Spacing ridotto**: `PAD` 12 -> **4**. I tasti stanno a 4px dal bordo su
   tutti i lati (verticale) e la matrice e' allineata a sinistra a 4px; la
   larghezza in piu' che la riga della barretta impone resta a destra.
2. **La freccia e' diventata il pulsante "Raid Control"**: tasto di testo
   (`UIPanelButtonTemplate`, alto 16px, largo = testo + 16) dentro la barretta,
   a sinistra della X. Stesso comportamento di prima (apre/chiude SOLO il
   pannello sotto la barra) + highlight quando il pannello e' aperto.
   `titleBar.arrowBtn` resta come alias; `MW._updateArrowDir` ora gestisce
   l'highlight. La vecchia freccia TGA (`media/arrowup.tga`) non e' piu' usata
   nella barretta (i file restano in media/, non toccati).
3. **Larghezza FISSA = somma degli elementi**: il posto del nome della fase NON
   e' un numero a caso ma la larghezza **misurata** del nome piu' lungo
   ("Pre-raid"/"Pre-boss"/"In-fight", `MW._phaseLabelW`) e il pulsante "Raid
   Control" e' largo quanto il suo testo. Larghezza barra =
   `PAD + max(matrice, riga barretta) + PAD` -> non cambia mai al cambio fase e
   nessun elemento viene tagliato (`MW._titleRowW`).
4. **Ancoraggio fisso**: la barra NON si trascina piu' (via il drag della
   barretta e `MakeUniversalWindow("main")`): `ApplyLayout` la mette a
   **TOPRIGHT** di UIParent, `x = -MW:RaidFrameWidth()`, `y = -(20 + 2)`
   (altezza barretta + gap, cosi' e' la BARRETTA a toccare il bordo alto).
   `MW:RaidFrameWidth()` = `RaidFrame:LayoutMetrics().W * db.scale`, cioe' icone
   food/flask + barra giocatore + barre CD **senza i buff** (le colonne della
   matrice sono disegnate OLTRE il bordo destro del frame, `matrix a rowWidth+4`).
   `RaidFrame:ApplyLayout` richiama `mainWindow:ApplyLayout`, quindi se cambia
   larghezza del Raid Frame (icon size, bar width, scala) la barra si sposta.

Test: **871 check** totali (16 nuovi nella 1.11.57: ancoraggio TOPRIGHT con
offset = larghezza RF, barretta al bordo alto, offset che segue il Raid Frame
+40px e ritorno, larghezza = formula per 1..8 colonne, tasti a 4px dal bordo,
Raid Control pulsante di testo + highlight, riserva del nome fase misurata).

## 1.11.56 — barretta piu' bassa, icona di fase al posto di "RLS", SaveRaid pulsante

Tre richieste dell'utente, tutte sul "muso" della main bar:

1. **Barretta del titolo piu' bassa**: 30 -> **20 px**.
2. **Via la scritta "RLS"**: al suo posto, a sinistra, l'**icona di fase (16x16)
   con il nome della fase** accanto ("Pre-raid" / "Pre-boss" / "In-fight").
   L'icona resta quella cliccabile di prima (clic sinistro = fase successiva,
   clic destro = precedente) e continua ad animarsi (occhio LFG, spade).
   Se la barra e' stretta il NOME si nasconde e resta l'icona.
   `mainWindow.phaseText` e' anche `titleBar.title` (il vecchio campo "RLS").
3. **SaveRaid torna un PULSANTE**: era un'icona 26x26 con save.blp, ora e' un
   tasto di testo `UIPanelButtonTemplate` "SaveRaid" **90x22**, identico agli
   altri tasti, e sta **nella matrice come settimo tasto** (la Config, le
   stringhe e i tooltip sono aggiornati di conseguenza).

Conseguenza: **la riga di icone in alto al pannello non esiste piu'** (conteneva
solo save + fase), quindi la main bar e' piu' bassa di quella riga: altezza =
`2*PAD + matrice` (con 2 colonne x 4 righe = **124 px**, prima 156). Larghezza
invariata (segue la matrice). La coppia MT/OT resta appesa alla cella sotto
"Raid Frame"; la matrice ora e' 6 tab + SaveRaid (7 celle + la cella MT/OT).

Test: **855 check** totali (14 nuovi nella 1.11.56: barretta 20px, icona/nome
fase nella barretta, niente "RLS", SaveRaid pulsante di testo 90x22 settimo
della matrice, altezza barra = solo matrice, click -> OnSaveRaid, nome fase
nascosto sulle barre strette).

## 1.11.55 — CAUSA VERA dei dropdown che "smettono di aprirsi": la STRATA

Perche' la tendina smetteva di aprirsi dopo N aperture (N variabile: 2, 5, 6...):
la finestra di configurazione e' un **AceGUI Window**, che per costruzione vive
nella strata **FULLSCREEN_DIALOG** ed e' `SetToplevel(true)`: a ogni interazione
si **ri-alza da sola** dentro quella strata (AceGUIContainer-Window.lua:180 e
:92). Il menu dei nostri dropdown e il catcher stavano **nella stessa strata**
(FULLSCREEN_DIALOG) a livelli fissi 10 e 1: appena la finestra si ri-alzava,
finiva **sopra** il menu -> il menu si apriva **DIETRO** la finestra (quindi
invisibile e non cliccabile) e il click "fuori" non chiudeva niente perche'
andava sulla finestra invece che sul catcher. Non c'era nessuno stato da
consumare: era un problema di Z-ORDER, ed e' per questo che il numero di
aperture "sopportate" cambiava.

Rimedio (definitivo, allineato a quello che fa AceConfigDialog per i propri
popup: `AceConfigDialog-3.0.lua` usa `SetFrameStrata("TOOLTIP")`):

- catcher e menu in strata **TOOLTIP** (la piu' alta esistente) -> sempre sopra
  la finestra, qualunque cosa faccia AceGUI;
- menu a livello 20, catcher a 1 (le opzioni restano sopra il catcher);
- **un solo percorso di click**: la freccetta non e' piu' cliccabile, apre e
  chiude solo il frame del dropdown (prima lo stesso click fisico poteva
  arrivare a due handler -> "si apre e si richiude subito").

Vale per TUTTI i dropdown dell'addon (Loot Manager, MS Manager, Group Making,
macro), non solo per raid/boss.

Nota per i test: il mock ora emula il client anche su strata/livelli (i figli
EREDITANO strata e livello del genitore) -> i check "chi sta sopra chi" hanno
significato reale. Con il codice 1.11.54 i 4 check di z-order falliscono.

Test: **841 check** totali (10 nuovi nella 1.11.55).

## 1.11.54 — i dropdown si aprono/chiudono ALL'INFINITO (stato letto dal vero)

L'utente segnala che dopo DUE scelte ("un boss, un altro") la tendina non si apre
piu'. Riprodotto in test con lo stesso identico profilo: ciclo 1 e 2 aprono, dal 3
in poi `activeMenu` resta valorizzato ma il menu e' NASCOSTO e il catcher a
schermo intero mangia i click (la UI sembra morta).

Riscrittura del meccanismo (vale per TUTTI i dropdown: Loot/MS Manager, Group
Making, macro):

- `Utils:OpenDropdownMenu(dd, options)` = costruzione + `menu:Show()`; il toggle
  esegue l'apertura dentro `pcall`: un errore non puo' piu' lasciare il catcher
  a schermo (era la via principale per cui "la tendina non si apre piu'").
- Il toggle NON si fida piu' dello stato memorizzato: calcola se il menu e'
  DAVVERO visibile (`menu:IsShown()`), chiude sempre tutto e poi apre. Nessuno
  stato che si "consuma" dopo N aperture, e funziona anche se un terzo ha
  nascosto il menu a mano.
- `CloseDropdownMenu` azzera lo stato PRIMA di nascondere (niente riferimenti
  sporchi anche se un OnHide fallisce).
- WATCHDOG sul catcher (`OnUpdate` -> `AssertNoZombieCatcher`): se il menu non
  c'e' piu', il catcher si spegne da solo entro un frame. Il cadavere invisibile
  a schermo intero non puo' piu' esistere.
- Menu SENZA nome globale: prima ogni dropdown creava un frame chiamato
  `RLSuiteDropMenu` (nome duplicato, in 3.3.5 il registro tiene solo l'ultimo).
- Bottoni-opzione RIUSATI e ri-testualizzati (prima se ne creava un set nuovo a
  ogni apertura: crescita illimitata di frames figli del menu).
- `PopulateMacroRaid/BossDropdown`: una lista vuota non svuota piu' il menu
  (tendina "muta" che non apriva piu' niente).

Test: **831 check** (10 nuovi nella 1.11.54). Con il codice 1.11.53 lo stress a 12
giri alternati passa ma 4 check di robustezza falliscono (menu nascosto da terzi,
errore in apertura, watchdog).

## 1.11.53 (fix dei dropdown del config) — "le dropdown si aprono UNA VOLTA SOLA"

Bug segnalato dall'utente sui due menu nuovi (raid/boss delle macro in-fight):
si aprivano al primo click e poi mai piu'.

Causa (in `Utils:ToggleDropdownMenu`, valida per TUTTI i dropdown dell'addon —
Loot Manager, MS Manager, Group Making, macro): il frame del menu viene RIUSATO
(`dd._rlsDropMenu`), ma non veniva mai ri-mostrato. Il primo menu era visibile
solo perche' un frame appena creato nasce mostrato; dopo la prima chiusura
restava NASCOSTO e restava attivo il **catcher a schermo intero** (che si mangia
il click successivo): da li' in poi il menu non si vedeva piu'.
Rimedio: `menu:ClearAllPoints()` (gli ancoraggi si accumulavano tra le aperture)
e `menu:Show()` a ogni apertura.
Test: 6 nuovi check (apri -> scegli -> riapri, sia raid sia boss) + 821 totali.

## Novità della sessione 1.11.52 (questo branch, dopo 1.11.51) — BUCHI DI RICONOSCIMENTO DAL COUNTER

Richiesta utente: per i boss che non si riescono a riconoscere dal target (nessun NPC affidabile sul
server) **usare il counter del raid**, perche' sono punti fissi non skippabili della catena lineare
("chiesene del target").

**Counter di progressione** (`Core.lua`, persistito in `db.profile.bossProgress[raid]`):
`RecordBossKill(npcId)` (chiamato dal combat log), `NextBossByProgress(raid)` = primo boss non
ancora battuto in ordine RAIDDB, `KilledBossCount`, `IsProgressOnlyBoss`, `ResetBossProgress`.
Il **reset settimanale si deduce da se'**: se un boss GIA' segnato muore di nuovo, quello e' un
lockout nuovo e il registro riparte (`lockouts` conta i reset).

**Boss riconoscibili solo dal counter**: flag `progressOnly = true` su **Gunship Battle** (3o di ICC)
e **Faction Champions** (3o di ToC). `CurrentBossInfo` ordina: (1) target, poi boss1..boss4 (id NPC
dal GUID, poi nome); (2) **solo se** il prossimo boss non ancora battuto e' un `progressOnly`, il
counter. Quindi durante i trash normali la barra resta vuota come prima: il counter entra in gioco
solo per Gunship e Champions.

**Inferenza sulla catena lineare** (`InferLinearKills`): flag `linear = true` sui boss a
progressione obbligata (ICC: Marrowgar, Lady Deathwhisper, Gunship, Saurfang; ToC: tutti e 5).
Se in fight identifichi il boss N, i boss LINEARI che lo precedono sono per forza gia' morti in
questo lockout -> il registro si aggiorna anche per i boss la cui kill il combat log non vede
(Gunship e Champions non hanno un NPC "boss" affidabile: senza inferenza il counter resterebbe
bloccato su di loro). Il boss identificato NON viene mai segnato come battuto.

**Raid quando il boss non e' riconoscibile** (`CurrentRaidGuess`): nome della zona/istanza
(`GetRealZoneText`, sul client inglese coincide con raidDB), poi l'ultimo raid riconosciuto nella
sessione, poi l'ultimo con progressione registrata.

**Combat log** (`CombatLog.lua`): `CL:NoteBossKill(guidOrId)` aggiorna il counter; in **debug mode
NON registra** (i pull finti del debug non devono sporcare la progressione vera). `MacroBar:OnBossProgressChanged` riallinea la barra quando il counter avanza (guardia di rientranza perche'
passa da `CurrentBossInfo` -> `InferLinearKills` -> di nuovo `OnBossProgressChanged`).

Test: **883 check** totali sul branch (25 nuovi nella 1.11.52: registro kill, lockout reset,
counter su Gunship e Faction Champions, precedenza del target, inferenza lineare su ICC e ToC,
kill dal combat log con e senza debug, riallineo automatico della barra al variare del counter,
guardia di rientranza sempre rilasciata e robustezza a un errore di riconoscimento).

## Novità della sessione 1.11.51 (questo branch, dopo 1.11.50) — MACRO IN-FIGHT PER BOSS

Richiesta utente: le macro della fase **in-fight** cambiano in base al boss; nell'editor, quando si
seleziona la fase In-fight, compaiono **due menu (raid + boss)**; la barra deve capire da sola a che
boss siamo. Scelte dell'utente (ask_user): **il boss è quello in target** ("se sono in fight con il
boss X voglio le macro del boss X"), **nessun fallback** (boss senza macro dedicate → slot vuoti) e
**nessun override manuale in gioco**.

**Riconoscimento** (`Core.lua`): su 3.3.5a il client non manda `ENCOUNTER_START/END` (vedi
`CombatLog.lua`), quindi si guardano le UNITA': prima **target**, poi **boss1..boss4**.
`RLSuite.bossUnits` (54 boss, 9 raid) mappa ogni boss di `raidDB` su `npcs` (id NPC, estratti dal
GUID con `Utils:NpcIdFromGUID`: a prova di lingua) e/o `names` (alias). Indice inverso costruito una
volta sola (`RLSuite:BuildBossIndex`, `BossFromNpcId`, `BossFromName`), `RLSuite:CurrentBossInfo()`
= raid+boss in corso. Boss senza id affidabile (Gunship, Faction Champions, Assembly of Iron,
Quattro Cavalieri) si riconoscono per nome. `CombatLog:NpcIdFromGUID` ora **delega** a
`Utils:NpcIdFromGUID` (una sola implementazione).

**Storage**: `db.profile.macrobar.bossMacros[raid][boss][slot] = {text, icon}`. La fase in-fight
NON usa più `db.macros.infight` (i set vecchi restano nel DB, non cancellati, ma non vengono più
letti: nessun fallback, per scelta esplicita dell'utente). `MB:MacroTableFor(phase, create)` è il
punto unico di risoluzione (usato da `GetMacroData`, `FilledSlots`, `LoadMacrosForPhase` e
dall'editor rapido `OpenMacroEdit`): in-fight → set del boss, nessun boss → **nessuna macro**.

**Runtime** (`MacroBar.lua`): `MB:UpdatePhase` rilegge il boss; `RLSuite:OnTargetChanged`
(`PLAYER_TARGET_CHANGED`, registrato in Core) chiama `MB:OnBossTargetChanged()` che ricarica i set
quando il boss cambia durante il fight. `ApplyLayout` mostrando solo gli slot pieni, cambiando target
la barra si ridimensiona da sola sul numero di macro di quel boss.

**Editor** (`Config.lua`): i due dropdown (`macroRaidDD`, `macroBossDD`) stanno nello spazio a
destra delle 12 icone dell'anteprima, dentro `macroBossSel`, e sono **visibili solo con la fase
In-fight** (`UpdateMacroBossSelectors`, chiamata da `CreateMacroEditor`, `SelectMacroPhase` e
`ShowMacroEditor`). Default = boss in target (altrimenti raid scelto in Group Making + primo boss).
`CFG:GetMacroDB` in-fight lavora sul set `db.bossMacros[raid][boss]`, quindi anteprima, elenco,
campi e save scrivono lì; il titolo della lista diventa "Boss macros: <boss>".

Test: **810 check** totali sul branch (38 nuovi nella 1.11.51: guardie statiche su `bossUnits`
(54 boss, nessun id/nome ambiguo, tutti i raid coperti), lookup per id/nome/alias, boss in target →
boss1..4, cambio target, nessun fallback sulla macro generica, slot vuoti senza boss, menu
raid/boss comparsi solo in-fight con i valori giusti, scrittura nel set del boss, editor rapido).

## Novità della sessione 1.11.50 (questo branch, dopo 1.11.49) — BUG DEL CLICK NELLE LISTE (InviteEngine / Whisplist)

**Sintomo**: nella lista dei whisper (InviteEngine → tab Whisplist) le righe non rispondevano
al click; `/fstack` mostrava `RLSuiteWLScroll <700>` **sopra** la finestra `RLSuiteInviteEngine
<200>`, cioè il frame della lista centinaia di livelli fuori posto.

**Causa**: in 3.3.5 i frame **figli non seguono il livello del padre**. `Utils:RaiseWindow`
normalizza i livelli delle finestre (20+40*idx) e sposta il sotto-albero con `ShiftSubtree`, ma
la catena della Whisplist non veniva mai ri-ancorata: dopo un po' di raise/rebuild una sua parte
restava con centinaia di livelli di drift. Lo **ScrollFrame** (mouse-enabled: serve per la
rotellina) finiva così SOPRA i Bottone-riga e si mangiava i click. Loot Manager e MS Manager
avevano già il rimedio (righe a `content+2`); la Whisplist **no, era l'unica lista senza**.

**Rimedio** (tutto in `GM:UpdateWhisplist`, `GroupMaking.lua`, più un helper in `Utils.lua`):
1. nuovo `Utils:RealignSubtreeLevel(root, wantLvl, tol=20)`: se il root si è allontanato dal
   livello atteso oltre la tolleranza, sposta TUTTO il sotto-albero dello stesso delta
   (**shift, nessun rinumero**: l'ordine interno che funziona in gioco resta identico);
2. a ogni refresh vengono riallineati il **container dei tab** (`win+1`) e la **pagina** della
   whisplist (`genitore+1`, cioè `tg.border+1`: mai ancorata alla finestra, o si scenderebbe
   sotto il backdrop del border che copre la lista) → sparisce il drift da 500 livelli;
3. la catena visibile viene **ri-pinnata a ogni refresh** sul livello live della pagina:
   `wlListBox = pagina+2`, `wlScroll = +4`, `wlContent = +6`, **righe = +8 (livello UNIFORME
   per tutte le righe**, incluse quelle riusate dal pool: non si trascinano più il livello di
   quando sono nate; uniforme = banda sottile, così un pull-out aperto sopra la lista resta
   cliccabile);
4. la **chrome dello scroll** (barra del template + ogni altro figlio dello `ScrollFrame` che
   non sia `wlContent`) viene pinnata **sopra** le righe: le righe non coprono più i 16px della
   barra, che resta trascinabile (la rotellina continua a funzionare: in 3.3.5 `OnMouseWheel`
   risale ai genitori).
   ⚠️ **MAI** `EnableMouse(false)` su `wlScroll`/`wlContent`: in 3.3.5 blocca la hit-region anche
   dei figli (vedi `RaidFrame.lua`, consumabili non cliccabili).

Test: **752 check** (14 nuovi in `tests/rls_ace3_test.py`: catena livelli, righe sopra
scroll/content, livello uniforme, righe mouse-enabled, barra sopra le righe, chrome generica,
riparazione del drift simulato su pagina/scroll/righe e sul container dei tab, shift che
preserva l'ordine interno).

## Novità della sessione 1.11.49 (questo branch, dopo 1.11.48) — CHECK BUFF CONSAPEVOLE DI CLASSE E COMPOSIZIONE

Il check della matrice "Raid Buffs" non discriminava: chiedeva ogni categoria a TUTTI i player
(segnalando Int su un warrior) e non sapeva quali categorie il raid non può nemmeno fornire.
Ora ogni categoria ha tre dati in più in `RLSuite.raidBuffColumns` (`Core.lua`):
- **`beneficiaries`** = classi che ne BENEFICIANO (assente = tutti). Il check ignora le altre:
  Int/MP5/Replen → mana user (`BUFF_CLASSES_MANA`), Spirit/FM/spell power-haste-crit → caster
  (`BUFF_CLASSES_CASTER`), ATK/S+Agi/crit-haste melee/AP% → fisici (`BUFF_CLASSES_PHYS`).
- **`classes`** (già presente, prima "solo informativa") = FORNITORI: se nessuna di queste classi
  è nel raid la categoria è **NON disponibile** → icona di intestazione **grigio scuro 0.35**,
  resta spenta anche in hover, e l'alert dice "not available in this composition" invece di
  elencare 30 nomi.
- **`scope`** = `raid` (default, una sorgente copre tutti) · `single` (Focus Magic: tante aure
  quanti sono i **maghi**) · `capped` (Replenishment: `cap = 10`).
  **`partyProviders`** (classi la cui versione copre SOLO il party) è **vuoto e deve restare vuoto**:
  ⚠️ ATTENZIONE, errore già fatto una volta in questa sessione — dal **patch 3.0.2** (quindi per
  tutto il 3.3.5) **TUTTI i totem shaman di buff sono RAID-WIDE**, con limite di **RAGGIO** 30-40yd
  e NON di party: Strength of Earth, Windfury, Wrath of Air, Mana Spring (reso buff costante),
  Totem of Wrath, Flametongue. Marcarli `partyProviders` produce **FALSI NEGATIVI** (il check
  smette di segnalare chi è fuori dal party dello shaman ma DENTRO il raggio). Il limite di raggio
  lo gestisce già da solo il check per-player: chi è fuori raggio l'aura non ce l'ha. In 3.3.5 sono
  party-only solo i totem **"a impulso"** (Healing Stream, Mana Tide, Cleansing, Tremor), che NON
  sono nel matrix. Il campo esiste per quelli, se un domani si aggiungono.

Visivo: **overlay ROSSO** (WHITE8x8 tinta, sub-layer 1 sopra l'icona, icona desaturata) sull'icona
di colonna quando la categoria è disponibile ma il check non è soddisfatto — stile "spell non
usabile"; l'intestazione **grigia** e il rosso sono stati DISTINTI. Il tooltip dell'header ha ora
una riga di stato (`BuffCoverage` → `_BuffStatusText`): "OK on everyone" / "Missing: N: nomi" /
"Covered: 10/15" / "Not available in this composition".

Focus Magic: l'aura vive sul BERSAGLIO, quindi i nomi dei maghi mancanti vengono dal combat log
(`SPELL_AURA_APPLIED` → `RF.fmCasters[fonte] = bersaglio`, nuovo ramo in `RF:OnCombatLog`; il
conteggio delle aure resta la fonte di verità). Alert: "Buff check: FM - 1/2 - mages missing: Mago2".

Efficienza: i conteggi si accumulano nella STESSA passata che disegna le celle (`_BuffAggNew` /
`_BuffAggAdd` dentro `RefreshBuffMatrix`, che gira ogni 0,5s) → nessuno scan di `UnitBuff` in più.
`BuffCoverage` (ricalcolo completo) la usano solo il click sull'header e il tooltip. Le barre MT/OT
non fanno parte di `self.slots`, quindi nessun doppio conteggio dei tank.

Test: **790 check** totali sul branch (35 nuovi nella 1.11.49: guardie statiche sul modello dati, applicabilità per classe,
totem raid-wide + meccanismo party-only verificato con una categoria SINTETICA, cap di
Replenishment a 10, FM con nomi dal combat log, grigio vs rosso, tooltip, alert). Due check di
hover sono stati RISCRITTI: ora scelgono una colonna disponibile dinamicamente, perché "accenditi
in hover" vale solo per le categorie disponibili.

## Novità della sessione 1.11.48 (questo branch, dopo 1.11.47) — tab-strip RISCRITTA da zero (niente AceGUI TabGroup)

La striscia tab dell'InviteEngine è stata riscritta COMPLETAMENTE senza il widget AceGUI (che ri-disponava i layer interni e faceva finire il testo dei tab sotto qualcosa). Ora: host proprio + strip a height fissa + 3 bottoni nostri (skin+label Overlay, testi sempre dentro la nostra alberatura), border host compat per le pagine (`tg.border` invariato), larghezze equidistribuite al resize, evidenziazione oro/grigio della tab attiva. Tutta la gerarchia è nel nostro albero: impossibile che qualcosa esterno ci disegni sopra. Versione 1.11.48.

## Novità della sessione 1.11.47 (questo branch, dopo 1.11.46) — tab strip sollevata a strata piena (FULLSCREEN_DIALOG)

Il TabGroup AceGUI non dipende più dall'ordering relativo coi fratelli della finestra: il suo root vive su strata FULLSCREEN_DIALOG (sopra il HIGH degli slot/drag della matrice di gruppi) — le tab non possono più trovarsi sotto nessuna parte della griglia. PinTabStrip resta come ordering intra-widget. Versione 1.11.47 (e riallineamento della numerazione di versione nelle intestazioni).

## Novità della sessione 1.11.45 (questo branch, dopo 1.11.44) — header in pagina sempre sopra: RepinManualPage a fine build e a ogni tab-show

La Repin inside BuildManualPage girava a metà costruzione (manualBox con header/testostringeri nasceva DOPO → non pinnato). Ora `GM:RepinManualPage()` viene eseguita alla FINE di BuildManualPage (tutti i figli esistono) e a ogni visualizzazione della pagina dal selettore tab — la pila deterministic di livelli comprende TUTTI i figli fin da subito. Versione 1.11.45.

## Novità della sessione 1.11.44 (questo branch, dopo 1.11.43) — IL BUG DI INVITE-ENGINE, TROVATO E UCCISO

Dopo seduta di analisi della finestra: `GroupMaking.lua:1829` aveva `self.ieAutoNamesList:EnableMouse(true)` — un contenitore piatto GRANDE QUANTO l'area lista messo sopra come se fosse un pannello invisibile rubaclick (3.3.5 hit al frame mouse-enabled più alto del punto: il container vinceva, righe e X SEMPRE dietro — tonando esattamente lo "Stack che impedisce i click" e focus sul contenitore). Rimosso gli EnableMouse fuori spec: container = mai mouse-enabled; righe/X cliccabili al loro livello. Rimossi i comandi di debug di tracciamento (mousefocus/lmdebug); resta solo lootdiag. Versione 1.11.44.

## Novità della sessione 1.11.43 (questo branch, dopo 1.11.42) — RepinFrameOrder: ordine dei livelli deterministico a ogni rebuild

Nuovo `Utils:RepinFrameOrder(root)`: ricostruisce ricorsivamente i livelli dell'intero sotto-albero assegnando ad ogni figlio `base padre + 2 + 2*indice` (ordine di creazione). Invocata alla FINE di ogni refresh di lista/pagina (`LM:UpdateHistory`, `MSM:UpdateList`, `GM:BuildAutoNameListUI`, creazione pagine invite-engine), CANCELLA qualunque drift di livelli pregreso (refreshes + raises): gli header dei pannelli non stanno più sotto e le X sono sempre cliccabili. Gli assetti espliciti riga+1/X=riga+2 restano come rete. Versione 1.11.43.

## Novità della sessione 1.11.42 (questo branch, dopo 1.11.41) — pannello chiudibile sempre senza toccare le finestre; loot puliti; X funzionanti

1. **Panel/main bar sempre chiudibile, anche in fight, senza chiudere altro**: `MW:CloseTab` chiamava `HideAllWindows()` (tutte le finestre modulo!): freccia, X e /rls ora toccano SOLO barra+pannello.
2. **Loot Manager: niente duplicati e boss reali**: dedupe 4s sullo stesso itemLink; boss dal target del cadavere a LOOT_OPENED (120s); storia cap 200 (SavedVariables).
3. **X MS / X lista manuale GM funzionanti**: livelli espliciti riga+1 / X=riga+2; ShiftSubtree rebase live con clamp ≥0.
4. **`/rls lootdiag`** stampa count sessione vs SV.
5. Suite estesa con guardie statiche + comportamentali. Versione 1.11.42.

## Novità della sessione 1.11.41 (questo branch, dopo 1.11.40) — layering normalizzato: stack finestre deterministico

La riproduzione dell'utente (Loot Manager aperto mentre altre finestre sono aperte → righe senza mouse) inchioda la causa: `RaiseWindow` pompava un contatore GLOBALE (+50) e settava il livello SOLO alla finestra madre; i figli restavano a livello ~1, quindi sotto hit-test finivano sotto finestre vicine o sulla stessa finestra (`focus=RLSuiteLootManager`) — layering "a casaccio" confermato. Nuovo algoritmo: `RLSuite._windowStack` ordinato per recency; ogni raise ri-normalizza i livelli (slot da 40: 20,60,100...) e applica il DELTA a TUTTO il sotto-albero della finestra (figli, figli dei figli) — le finestre sono onde deterministiche, i figli sempre sopra. LM: ogni riga creata DOPO un raise riceve subito livello histContent+2. Cap +50 eliminato. Versione 1.11.41.

## Novità della sessione 1.11.40 (questo branch, dopo 1.11.39) — focus=RLSuiteLootManager (misura precisa degli hitbox)

Il mousefocus dell'utente (focus=finestra LM, mouse=1, sparisce solo sopra figli diretti) prova che le righe della lista NON ricevono il mouse: hit-test cade sulla finestra. Spedito: revert del content:EnableMouse(false) (era inerte ma ridondante); nuovo `/rls lmdebug` che stampa i rect effettivi [sinistra..destra x bottom..top], livelli, visibilità, stato mouse di window/histBox/histScroll/histContent/prima riga + coordinate del cursore normalizzate sal scale effettiva — output atteso per distinguere bug rettangolo-offset (scala/resize) da bug z/hierarchy. Versione 1.11.40.

## Novità della sessione 1.11.39 (questo branch, dopo 1.11.38) — hardening fstack/blocker + /rls mousefocus diagnostico

L'analisi dell'fstack dell'utente (RLSuiteLootHistory tra due frame anonimi) dimostra solo che il 3.3.5 framestack elenca frame non-mouse; non identifica il rubaclick. Hardening spedito: (a) TUTTI gli scroll-content (registrati tramite RegisterScrollClip) ora `EnableMouse(false)` — il content grande-tutta-l'area non comparirà più come pannello coprente; (b) `RaiseWindow` con cap a 1000: basta inflazione di frame-level a ogni click (+50 in fstack osservata); (c) nuovo `/rls mousefocus` che stampa focus/parent/level/strata/mouse del frame che ruba il click sotto il cursore — output atteso dall'utente per diagnosticare l'ultima causa residua. Versione 1.11.39.

## Novità della sessione 1.11.38 (questo branch, dopo 1.11.37) — il "pannello invisibile" (fstack zombie) è il drop catcher, ucciso in tutti i moduli

Il prompt `RLSuiteDropCatcher` era un bottone FULL-SCREEN INVISIBILE mostrato per i dropdown: a volte restava zombie (click su strata superiori/TOOLTIP, finestra padre chiusa col menu aperto) e in fstack copriva la finestra di Loot Manager bloccando ogni click. Fix centrali in `Utils` (valide per TUTTI i moduli, nessun fix per-modulo):
1. Il catcher chiude anche con **tasto destro**.
2. Il **menu** (dropMenu riusato) ha uno script OnHide: se svanisce per QUALUNQUE motivo, nasconde anche il catcher e pulisce activeMenu — difesa engine-level impossibile da aggirare.
3. All'apertura del dropdown, HookScript OnHide su TUTTI gli antenati del dd (fino a UIParent): nascondere la finestra/pannello che lo ospita uccide immediatamente menu+catcher.
Resta `Utils:AssertNoZombieCatcher()` come rete di sicurezza già esistente. Versione 1.11.38.

## Novità della sessione 1.11.37 (questo branch, dopo 1.11.35) — la BARRA = finestra universale; pannello aperto dalla freccia

MODELLO DEFINITIVO: **la barra è una finestra universale come tutte le altre** (`Utils:MakeUniversalWindow` = MakeDraggable guard-clamped + RaiseWindow + bordo tematico via `SkinFrameBordered`). **La main bar è solo il pannello** apribile/chiudibile con la freccia sulla barra. `MW:Toggle` apre/chiude la BARRA (e con lei il pannello); la freccia tocca SOLO il pannello; la X della barra chiude tutto. Drag della barra = forward alla finestra con `_rlsDragGuard` condiviso: mai fuori schermo. Versione 1.11.37.

## Novità della sessione 1.11.35 (questo branch, dopo 1.11.34) — guard per TUTTE le finestre + barretta

Causa definitiva: la main window viene SCALATA (`L.scale`) e su 3.3.5 `SetClampedToScreen` sui frame scalati è rotto in drag. Soluzione IDENTICA per tutte le finestre: `Utils:MakeDraggable` ora crea un **guard OnUpdate** (`_rlsDragGuard`) attivo solo durante il drag → `Utils:ClampWindowToScreen` scale-aware riporta la finestra nei bordi in tempo reale + sul drop. La barretta riprende il suo drag proxy ma legato allo STESSO guard di `f`. Versione 1.11.35.

## Novità della sessione 1.11.34 (questo branch, dopo 1.11.33) — drag della main bar IDENTICO alle altre finestre (niente proxy)

Il proxy `f:StartMoving()` lanciato dai drag della barretta ignorava il clamp dell'engine — per questo la barra usciva anche con SetClampedToScreen(true). RIMOSSO il proxy: la barretta ha solo `RegisterForDrag("LeftButton")` e il drag muove direttamente `f` (già `Utils:MakeDraggable(f, "main")` = SetClampedToScreen(true) come le altre finestre) — stessa identica meccanica, stessi limiti. Eliminato anche il guard OnUpdate (non serve più).

## Novità della sessione 1.11.33 (questo branch, dopo 1.11.32) — guard di clamp anche DURANTE il drag

- Barretta principale: guard OnUpdate attivo durante il drag → `Utils:ClampWindowToScreen(f)` ri-clampa la finestra **in tempo reale** (nemmeno durante il trascinamento può uscire dai bordi).
- Stesso clamp sul drop aggiunto allo **shift-drag della MacroBar** (`EndShiftDrag`) e allo stop della **anchor mode** (frame e macroHost) — erano gli unici trascinamenti scoperti.

## Novità della sessione 1.11.32 (questo branch, dopo 1.11.31) — main bar = STESSO trascinamento di tutte le finestre

La main bar ora usa LETTERALMENTE `Utils:MakeDraggable(f, "main")`, lo stesso meccanismo (SetClampedToScreen + RaiseWindow + persist) che usano pannelli/HUD/finestre che NON escono mai dallo schermo. La barretta continua a trascinarla per proxy e sul drop persiste la posizione + ri-clampa dentro i bordi. Versione 1.11.32.

## Novità della sessione 1.11.31 (questo branch, dopo 1.11.30) — main bar mai fuori schermo

`SetClampedToScreen(true)` c'era già ma su 3.3.5 non basta quando il drag parte per proxy dalla barretta. Ora **sia il drag diretto della main bar sia il drag dalla barretta** terminano con `RLSuite.utils:ClampWindowToScreen(f)`: la finestra viene riancorata dentro i bordi a fine trascinamento (mai persa fuori schermo).

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
| 1 | `Locale.lua` | 345 | AceLocale-3.0; `enUS` default; tutte le stringhe UI via `RLSuite.L` |
| 2 | `Utils.lua` | 1227 | Helper condivisi (colori classe, icone spec, chat/whisper, tempo, tabelle, drag/layering, scroll-clip) |
| 3 | `Core.lua` | 1961 | AceAddon core: DB (`RLSuiteDB`), fasi (`RLSuite.context`), debug raid model, minimap button, autoinviter, spam Lim/Aim, **tabelle `raidBuffColumns` / `raidBuffChecks` / `raidDebuffChecks`** |
| 4 | `RaidProfile.lua` | 906 | Finestra principale dell'addon (main window) + barretta titolo |
| 5 | `MacroBar.lua` | 1175 | Barra macro/pull; countdown pull/break non sovrapposti (AceTimer named timers) |
| 6 | `GroupMaking.lua` | 4061 | **InviteEngine**: composizione raid, pannello "Raid Group" a 6 gruppi con drag & drop (implementazione di riferimento) |
| 7 | `RaidFrame.lua` | 2328 | **Raid Frame HUD**: barre HP per player in 6 gruppi, CD classe, flask/food, barre buff pre-boss / debuff in-fight, drag & drop pre-boss, **matrice "Raid Buffs" + check consapevole di classe/composizione** |
| 8 | `MSManager.lua` | 271 | Main-spec manager; countdown 40s ascolto via AceTimer |
| 9 | `LootManager.lua` | 1247 | Gestione loot/roll; righe ad altezza unica con word-wrap; countdown roll/reroll non sovrapposti; AceEvent per `CHAT_MSG_SYSTEM` |
| 10 | `CombatLog.lua` | 1350 | **Combat log stile MRT** (fight log in-game, dalla 1.11.0): parser 3.3.5, segmentazione pull, store, aggregazioni, tab UI, grafici |
| 11 | `Config.lua` | 1251 | **Unica** finestra Ace3 di configurazione: `AceGUI:Create("Window")` + `TreeGroup` a sinistra + `AceConfigDialog` |

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
- **Matrice "Raid Buffs" (dalla 1.11.49)**: il check consapevole di classe e
  composizione vive in `RaidFrame.lua` e legge i campi di `RLSuite.raidBuffColumns`
  (`beneficiaries` = chi ne beneficia; `classes` = fornitori; `scope` +
  `cap`; `partyProviders` = fornitori party-only). Invarianti da rispettare:
  ogni voce di `partyProviders` DEVE essere anche in `classes`; `scope` può
  essere solo `raid`/`single`/`capped`; con `scope = "capped"` serve un `cap`
  positivo. In 3.3.5 **tutti i totem shaman sono party-only** e ci vanno
  elencati. ⚠️ Ma NON marcare i totem come party-only: dal 3.0.2 sono
  raid-wide (limite di RAGGIO): vedi la nota nella sezione 1.11.49.
  I conteggi si fanno in `RefreshBuffMatrix` (passata unica, gira ogni 0,5s):
  NON aggiungere scan di `UnitBuff` fuori da lì; per un ricalcolo completo
  esiste `RF:BuffCoverage(col)` (solo click/tooltip).
- **Test Lupa**: `rt.eval` NON esegue statement/`local` → setup con `rt.execute`,
  asserzioni con sole espressioni in `rt.eval`. Lupa va installata:
  `pip install --break-system-packages lupa` (ambiente PEP 668).

## 4. Verifiche

```bash
cd /home/user/RaidLeadSuite
python3 tests/rls_ace3_test.py   # atteso: 738 PASS, RESULT: ALL CHECKS PASSED
```

`lupa` non è installata di serie nell'ambiente: `pip install --break-system-packages lupa`
(poi lo script si esegue con `python3`). Suite aggiornata a ogni sessione: il numero di check
cresce e **le sezioni con intestazione `== vX.Y.Z ==` non sono in ordine cronologico stretto**:
verificare sempre il contenuto, non l'etichetta.

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
   finestre pickup loot → `LootManager.lua` (`ShowTradeWindow`, `StackTradeWindows`);
   matrice buff + check → `RaidFrame.lua` (`_MatrixCols`, `BuffCoverage`,
   `_BuffAggNew/_BuffAggAdd`, `_BuffStatusFromAgg`, `ApplyBuffHeaderStatus`)
   e i dati in `Core.lua` (`raidBuffColumns`).
6. **Nomi dei maghi per Focus Magic**: vengono dal combat log
   (`RF.fmCasters`, `SPELL_AURA_APPLIED`), quindi compaiono solo per i lanci
   visti da quando l'addon è caricato; dopo un `/reload` i maghi che avevano
   già dato FM risultano "mancanti" finché non rilanciano. Il CONTEGGIO delle
   aure resta corretto. Se dà fastidio, la via è ricostruire `fmCasters` anche
   dalle aure già presenti al login (non c'è modo di sapere CHI le ha date
   senza il log).
7. **Liste "classes" non riviste**: in `raidBuffColumns` restano provider
   storicamente imprecisi (`atkpower` elenca HUNTER anche se Trueshot è passata
   in `apIncrease`; `armor` elenca DRUID). Effetto: con una composizione che ha
   solo quelle classi la categoria risulta "disponibile" (rossa) invece che
   "non disponibile" (grigia). Da ripulire con l'utente, con calma.
8. **`raidBuffChecks` / `raidDebuffChecks` sono liste MORTE** (`Core.lua`):
   nessun codice di produzione le legge, le referenziano solo i test. Da
   rimuovere o da ricollegare alla ability bar verticale (che oggi usa
   `raidBuffColumns`).
