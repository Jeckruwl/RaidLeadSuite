# RLSuite — Raid Leading Suite

Addon per **raid leader** su World of Warcraft **Wrath of the Lich King 3.3.5** (Interface `30300`), pensato per **Warmane Lordaeron**.

**Versione: 1.11.89**

> Questa è una **build per i tester di gilda**: se qualcosa non funziona, segnalalo al raid leader con **cosa hai fatto**, **cosa ti aspettavi** e **cosa è successo**, più l'eventuale errore Lua.

<!-- NOTA (richieste esplicite del 24/09/2026): la README NON deve contenere
     - una sezione di installazione,
     - una sezione "Struttura del repository",
     - una sezione "Se qualcosa non va".
     Non reintrodurle, nemmeno in forma ridotta o come elenco puntato.
     Questo documento descrive solo comandi, interfaccia, moduli e requisiti. -->

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

## Requisiti

- Client **3.3.5a** (non Retail, non Classic Era, non Cataclysm).
- Permessi di **raid leader** o assistente per raid warning, ready check, pull timer e assegnazione MT/OT.
- Nessuna dipendenza obbligatoria: **DBM** (o BigWigs) è opzionale e aggiunge solo la barra del timer.
