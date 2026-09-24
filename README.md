# RLSuite — Raid Leading Suite

Addon per **raid leader** su World of Warcraft **Wrath of the Lich King 3.3.5** (Interface `30300`), pensato per **Warmane Lordaeron**.

**Versione: 1.11.85**

> Questa è una **build per i tester di gilda**: se qualcosa non funziona, leggi in fondo *"Se qualcosa non va"* — ci sono tre comandi che dicono subito cosa sta succedendo, e con quelle righe si risolve in un colpo.

---

## Installazione

La cartella deve chiamarsi **`RaidLeadSuite`** (il nome della cartella deve corrispondere al file `.toc`, altrimenti il gioco non la carica).

### Con lo ZIP (consigliato per chi non usa git)

1. Scarica `RaidLeadSuite-1.11.85-AddOns.zip`.
2. Estrai la cartella **`RaidLeadSuite`** in:

```
<WoW 3.3.5>/Interface/AddOns/
```

3. Il percorso finale deve essere `<WoW 3.3.5>/Interface/AddOns/RaidLeadSuite/RaidLeadSuite.toc`.
4. Avvia il client (o `/reload` se era già installato). In chat compare:

```
[RLSuite] v1.11.85 loaded (RaidLeadSuite). Type /rls to open.
```

### Con git (per chi aggiorna spesso)

```bash
git clone <repo>
# l'addon sta in Release/RaidLeadSuite/
cp -r <repo>/Release/RaidLeadSuite "<WoW 3.3.5>/Interface/AddOns/RaidLeadSuite"
```

Per aggiornare: `git pull` e ricopia la cartella `Release/RaidLeadSuite`.

**La cartella dell'addon deve contenere solo**: `RaidLeadSuite.toc`, i file `.lua`, `Libs/` e `media/`. Niente altro.

---

## Comandi

`/rls help` stampa la lista in chat.

| Comando | Cosa fa |
|---|---|
| `/rls` | Barra principale (matrice pulsanti + fase) |
| `/rls help` | Lista dei comandi |
| `/rls config` | Finestra Config (anche col **clic destro sull'icona della minimappa**) |
| `/rls group` | Pannello Groupmaking |
| `/rls inv` | Pannello InviteEngine (whisper ricevuti + auto-invito) |
| `/rls macrobar` | HUD MacroBar (mostra/nascondi) |
| `/rls ms` | Pannello MS Manager |
| `/rls loot` | Pannello Loot Manager |
| `/rls raidframe` | HUD Raid Frame (mostra/nascondi) |

L'editor dei 12 tasti della MacroBar si apre da **Config → Macros → Macro Editor**.

---

## Interfaccia

### Barretta in alto (Raid Control)

- A sinistra: **icona di fase** (occhio LFG animato = pre-raid, clessidra = pre-boss, spade = in-fight) + **nome della fase**. **Click sinistro** = fase successiva, **click destro** = fase precedente.
- A destra: pulsante **Raid Control** (apre/chiude il pannello dei tasti) e la **X** di chiusura.
- Il pannello dei tasti si apre **a destra** della barretta. Ordine dei tasti:

```
Groupmaking | Raid Frame | MS | Log | Macrobar | MT & OT | Loot | SaveRaid
```

- **MT & OT**: due mezzi tasti nella stessa cella. Assegnano (o tolgono) il **Main Tank** / **Main Assist** sul target corrente. Richiedono i permessi di raid leader/assistente e **non funzionano in combat** (limite del client).
- **SaveRaid**: salva la configurazione corrente (Comp, MacroBar e Config tranne *General*) chiedendo un titolo; si ricarica da *Config → Saved Raids*.

### Raid Frame (HUD)

Barre dei giocatori per gruppo, con:

- barra HP colorata per classe + nome;
- icone **flask** e **food** mancanti (click sinistro = whisper al giocatore, click destro = raid warning a tutti quelli a cui manca);
- **cooldown di classe** per riga (letto dal combat log);
- blocco **Tanks** in alto con **MT/OT** e barra del **target** del tank;
- **matrice Raid Buffs** (tasto *Raid Buffs*): check per classe, rosso sulle intestazioni mancanti;
- **spostare i giocatori di gruppo**: `Shift` + click sinistro su una barra **giocatore dei gruppi**, trascina, rilascia su un'altra barra (vuota = spostamento, piena = scambio). Funziona **anche in combat**; rilascio fuori dalle barre = annulla. *(Le barre MT/OT non si trascinano.)*

### MacroBar

- 12 macro per fase (`preraid` / `preboss` / `infight`), editor in *Config → Macros*.
- Tastierino a due righe dipendente dalla fase: **ready check** in pre-raid; in pre-boss prima riga **pull 15/20/30**, seconda riga **ready + break 5m/3m/2m**.
- Integrazione **DBM/BigWigs**: pull timer, richiesta cambi MS e roll/reroll mostrano la barra del timer.

### Pannello Log

- Ogni pull è agganciato all'**encounter** (non si perde se muori o ricarichi la UI).
- Intestazione: durata, fight, **tag taglia/difficoltà** (es. `25H`), Kill/Wipe; dropdown dei fight in alto a destra (click destro su una riga = segna boss/trash).
- **Grafico sempre visibile** (discretizzazione 1/2/3/5/10 s) e schede: **targets**, **consumables** (per spell ID, non per nome), **auras**, **deaths**, **powers**; le schede storiche (healing, spells, entities, interrupts) restano.

---

## Debug mode (per chi prova da solo)

*Config → Debug → Enable debug mode*: simula un raid vero (roster finto, whisper e loot a te stesso), così si prova tutto **senza 24 persone**.

Con il debug attivo, accanto alla barra compare il pannello **RLS DEBUG** (due righe di tasti): *Fill Raid*, *Test Loot*, *Empty Loot*, *Test Whisplist*, *Test MS*, *Log Test*. Si apre e si chiude insieme al pannello dei tasti (**Raid Control**).

In debug mode la chat scrive righe di traccia utili (`RF …` per l'HUD, `RG …` per il pannello Raid Group): ogni gesto lascia il segno, quindi un problema è sempre leggibile.

---

## Se qualcosa non va

1. **Attiva gli errori Lua**: Esc → Interfaccia → Aiuto → *Mostra errori Lua*. Un riquadro rosso è la segnalazione più preziosa.
2. **Annota la versione**: la chat la stampa all'avvio (`v1.11.85 loaded`) — serve sempre.
3. **Controlla di avere UNA sola copia dell'addon** in `Interface/AddOns` (due copie danno comportamenti strani).
5. **Copia in chat le righe `RF …` / `RG …`** se il problema riguarda un click o un trascinamento.
6. Se sai usare la riga di comando dell'addon, segnalalo al raid leader: esiste un set di comandi di **diagnostica** (elenco completo nel file `commands.txt` della cartella `_dev/` del repository) che fa risalire la causa in pochi secondi.

Nella segnalazione servono: **cosa hai fatto**, **cosa ti aspettavi**, **cosa è successo**, **versione**, **eventuale errore Lua** (o le righe di traccia).

---

## Struttura del repository (per chi sviluppa)

```
Release/RaidLeadSuite/   <-- l'addon (questa è la cartella da copiare in AddOns)
_dev/                    <-- materiale di sviluppo, NON serve per giocare
    commands.txt         <-- elenco COMPLETO dei comandi (pubblici + diagnostica)
    handoff.MD           <-- diario tecnico del progetto
    SMOKE_TEST.md        <-- lista di controlli da fare in gioco prima di consegnare
    Logexampl/           <-- log di esempio
    tests/               <-- suite automatica: python3 _dev/tests/rls_ace3_test.py
```

Gli ZIP di release si fanno con:

```bash
# pronto da estrarre in Interface/AddOns
git archive --format=zip --prefix=RaidLeadSuite/ -o RaidLeadSuite.zip HEAD:Release/RaidLeadSuite

# oppure con la struttura del repo (Release/RaidLeadSuite/...)
git archive --format=zip -o RaidLeadSuite-repo.zip HEAD Release/RaidLeadSuite
```

---

## Requisiti

- Client **3.3.5a** (non Retail, non Classic Era, non Cataclysm).
- Permessi di **raid leader** o assistente per raid warning, ready check, pull timer e assegnazione MT/OT.
- Nessuna dipendenza obbligatoria: **DBM** (o BigWigs) è opzionale e aggiunge solo la barra del timer.
