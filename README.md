# RLSuite — Raid Leading Suite

Addon per **raid leader** su World of Warcraft **Wrath of the Lich King 3.3.5** (Interface `30300`), pensato per **Warmane Lordaeron**.

Versione: **1.3.0**

## Installazione

WoW carica l’addon dal **nome della cartella**, che deve coincidere con il file `.toc`.

1. Scarica o clona questa repository.
2. Rinomina la cartella in **`RLSuite`** (se cloni da GitHub si chiama `RaidLeadSuite`).
3. Copiala in:

```
World of Warcraft/_classic_ o WotLK/Interface/AddOns/RLSuite
```

Su Warmane / client 3.3.5 il percorso tipico è:

```
<WoW 3.3.5>/Interface/AddOns/RLSuite
```

Dentro quella cartella devono esserci:

- `RLSuite.toc`
- i file `.lua` (`Core.lua`, `Utils.lua`, …)

4. Riavvia il client (o `/reload` se l’addon era già presente).
5. In gioco: `/rls`

Se lasci il nome `RaidLeadSuite` (clone GitHub senza rinomina), è comunque supportato: è incluso `RaidLeadSuite.toc` e `ADDON_LOADED` accetta entrambi i nomi. **Consigliato: cartella `RLSuite`.**

## Comandi

`/rls help` stampa l’elenco in chat.

| Comando | Finestra |
|---|---|
| `/rls` o `/rlsuite` | Barra principale (matrice bottoni + fase) |
| `/rls help` | Elenco comandi |
| `/rls group` | Tab Groupmaking |
| `/rls whisplist` | Tab Whisplist |
| `/rls macro` | Tab editor Macrobar |
| `/rls macrobar` | HUD MacroBar (pull / ready) |
| `/rls raidframe` | Tab impostazioni Raid Frame |
| `/rls rfhud` | HUD Raid Frame |
| `/rls ms` | Tab MS Manager |
| `/rls loot` | Tab Loot Manager |
| `/rls config` | Tab Config |

## Interfaccia

- **Barra in alto**: matrice di bottoni **configurabile** (default **2×4**) con Groupmaking, Whisplist, Macrobar, Raid Frame, MS, Loot + **SaveRaid**. **Config** è una **rotellina sotto la X rossa**. Sotto la rotellina c'è una **singola icona fase** che cambia in base alla fase corrente (**occhio LFG animato** = pre-raid, **clessidra** = pre-boss, **spade** = in-fight); cliccandola si passa alla fase successiva. I tab sono bistabili; le finestre si aprono come **pannelli liberi, spostabili** (posizione ricordata).
- **SaveRaid**: salva un setup con un titolo richiesto da un prompt → **Comp** (composizione, raid, riservati, messaggio, whisplist), **MacroBar** (macro e layout) e **Config esclusa la categoria General**.
- **Config → Saved Raids** (voce sotto General): elenco dei salvataggi con il titolo e pulsante **Load** per ripristinare tutto.
- **Anchors stile ElvUI** in *Config → General → Finestra → Toggle Anchors*: le HUD **Raid Frame** e **MacroBar** sono bloccate di default; con Toggle Anchors compaiono come placeholder spostabili evidenziati. Le altre finestre restano normali.
- **Ridimensionabili** (maniglia in basso a destra): Groupmaking, Whisplist, MS Manager e Loot Manager; le dimensioni vengono ricordate.
- **Integrazione DBM/BigWigs**: se DBM (o BigWigs) è installato, pull timer, richiesta MS changes e roll/reroll avviano anche una barra-timer visibile.

## Moduli

- **Group Making** — composizione 10/25, messaggio LFG, spam canali, whisplist con invite
- **MacroBar** — 12 macro per fase (`preraid` / `preboss` / `infight`), pull 15/20/30, ready check
- **Raid Frame** — HP/mana, alert flask/food/buff, cooldown raid via combat log
- **MS Manager** — legge `ms <spec>` in raid chat e genera il pre-messaggio loot
- **Loot Manager** — history drop, roll, tie/reroll
- **Config** — tab stile ElvUI (lista a sinistra, pannello + sottotab a destra): aspetto, bordi, font, dimensioni, ancoraggi e Saved Raids. Non cambia le funzionalità (es. testi macro restano nella tab Macrobar)

## Requisiti

- Client **3.3.5a** (non Retail / non Classic Era / non Cata)
- Permessi da **Raid Leader** o assist per raid warning, ready check e pull timer
