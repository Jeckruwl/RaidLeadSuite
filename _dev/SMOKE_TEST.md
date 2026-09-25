# RLSuite — lista di smoke test (da fare in gioco)

**Regola d'oro:** i test automatici non possono vedere i comportamenti del *client* (template, tempi delle misure, click, strati). Questi bug si trovano **solo giocando**. Quindi: prima di consegnare a un altro player, questa lista va passata **tutta**.

**Preparazione (una volta sola)**
- Client 3.3.5 con l'addon in `Interface/AddOns/RaidLeadSuite`.
- **Errori Lua ATTIVI**: Esc → Interfaccia → Aiuto → *Mostra errori Lua* (o un addon che li cattura).
- `/reload` e verifica in chat: `RLSuite vX.Y.Z loaded` → **annota la versione** (serve in ogni segnalazione).
- Da fare in gruppo/raid vero (non da solo: molte cose richiedono il roster).

---

## A. Caricamento e finestre (3)

- [ ] **A1** Primo `/reload`: compare il messaggio di versione, **nessun riquadro di errore**.
- [ ] **A2** `/rls` apre la barra; apri e chiudi **tutte** le finestre (group, macrobar, raid frame, ms, loot, config, log).
- [ ] **A3** Fuori dal raid apri il pannello Log → deve dire "No fights recorded", non deve andare in errore.

## B. Pannello Log (il cuore: 11)

- [ ] **B1** Pull di **trash** → nel dropdown compare un pull; durata plausibile; il nome è quello del trash o "Combat".
- [ ] **B2** Pull su **boss con kill** → nome boss corretto, esito `Kill`, durata ≈ reale.
- [ ] **B3** **Wipe** su boss → esito `Wipe`.
- [ ] **B4** *Test morte*: muori a metà pull e resta morto mentre il raid finisce il boss → guarda la durata salvata: **se si ferma al momento della tua morte, è il difetto noto** (segnala con orario).
- [ ] **B5** *Test res*: vieni ressato durante il fight → verifica se compaiono **due** pull al posto di uno (difetto noto).
- [ ] **B6** Grafico sempre visibile; le **6 discretizzazioni** (Avg whole fight / 1 / 2 / 3 / 5 / 10 s) cambiano la curva.
- [ ] **B7** Ogni tab: Damage / Targets / Consumables / Auras / Deaths / Powers → righe e colonne corrette, **nessuna tabella impilata, nessun testo che sborda**.
- [ ] **B8** Tab **Deaths**: il tuo nome nella lista a sinistra, tabella a destra con TIME / FLAG / SOURCE / SPELL / VALUE / OVERKILL / STACKS.
- [ ] **B9** Tab **Consumables**: flask/pozioni/elisir compaiono con icona **e nome** (segnala se la colonna è vuota o anonima).
- [ ] **B10** Dropdown in alto a destra: scegli un altro pull; poi `All <boss> segments` con almeno 2 pull dello stesso boss.
- [ ] **B11** Dopo 2-3 pull: `/reload` → i pull **sono ancora** nel dropdown e la versione in chat è la stessa.

## C. Raid Frame (3)

- [ ] **C1** Raid 25: le barre stanno nella griglia, i 6 gruppi non si spostano, il buff check è visibile in alto.
- [ ] **C2** Muori, poi spostati di gruppo: **la tua barra resta al suo posto** (non sale in cima, la griglia non si riordina).
- [ ] **C3** Click sinistro = target, click destro = menu. **Durante il combat** prova a trascinare un player in un altro gruppo → segnala se non succede niente o se compare un messaggio rosso.

## D. Main bar e MacroBar (2)

- [ ] **D1** La barretta: larghezza fissa, `Raid Control` apre il pannello **a destra** allineato in alto; la fase (preraid/preboss/infight) cambia da sola entrando in combat.
- [ ] **D2** Macro boss: con un boss nel target compaiono i suoi pulsanti; su **Gunship Battle** e **Faction Champions** funziona col counter; in un fight **senza boss** non compaiono macro.

## E. Group making, Loot, MS (3)

- [ ] **E1** Whisplist: fatti mandare un whisper contenente la parola d'invito → la riga compare e il click su "invita" invita.
- [ ] **E2** Invito automatico: arma l'annuncio e verifica che inviti i firmati (e solo quelli).
- [ ] **E3** Loot: apri un loot su un boss, avvia i dadi → lo storico tiene traccia; MS Manager: chiedi gli MS e verifica la tabella.

## F. Costo sulla serata (2)

- [ ] **F1** A fine serata: `/reload` e logout → **quanto ci mette** la chiusura? (segnala se si impunta)
- [ ] **F2** Peso del file `WTF/Account/<account>/SavedVariables/RaidLeadSuite.lua` in MB → segnala il numero.

---

## Come segnalare (formato obbligatorio)

1. **Versione** (dal messaggio in chat).
2. **Cosa stavi facendo** (pull/boss/finestra/tab).
3. **Cosa ti aspettavi** e **cosa è successo**.
4. **Testo dell'errore** se compare (copia-incolla del riquadro).
5. **Screenshot** della finestra.
6. Se il problema è *"manca un pull"*: allega anche `SavedVariables/RaidLeadSuite.lua`.

**Cosa NON fare durante la prima prova:** `/reload` mentre siete in combat su un boss (il pull in corso si perde: è un difetto noto, non una novità).
