# RLSuite — Raid Leading Suite

Addon per **raid leader** su World of Warcraft **Wrath of the Lich King 3.3.5** (Interface `30300`), pensato per **Warmane Lordaeron**.

Versione: **1.3.0**

## Installazione

WoW carica l’addon dal **nome della cartella**, che deve coincidere con il file `.toc`.

1. Scarica o clona questa repository.
2. La cartella deve chiamarsi **`RaidLeadSuite`** (è già il nome del clone GitHub: non rinominare).
3. Copiala in:

```
World of Warcraft/_classic_ o WotLK/Interface/AddOns/RaidLeadSuite
```

Su Warmane / client 3.3.5 il percorso tipico è:

```
<WoW 3.3.5>/Interface/AddOns/RaidLeadSuite
```

Dentro quella cartella devono esserci:

- `RaidLeadSuite.toc`
- i file `.lua` (`Core.lua`, `Utils.lua`, …)
- la cartella `Libs` (librerie Ace3)

4. Riavvia il client (o `/reload` se l’addon era già presente).
5. In gioco: `/rls`

`ADDON_LOADED` riconosce il nome cartella `RaidLeadSuite`; le librerie Ace3 sono caricate dal `.toc` (LibStub per primo).

## Comandi

`/rls help` stampa l’elenco in chat.

| Comando | Finestra |
|---|---|
| `/rls` o `/rlsuite` | Barra principale (matrice bottoni + fase) |
| `/rls help` | Elenco comandi |
| `/rls group` | Tab Groupmaking |
| `/rls whisplist` | Tab Whisplist |
| `/rls macro` | Config → Macros → Macro Editor |
| `/rls macrobar` | HUD MacroBar (mostra/nascondi) |
| `/rls raidframe` | Tab impostazioni Raid Frame |
| `/rls rfhud` | HUD Raid Frame |
| `/rls ms` | Tab MS Manager |
| `/rls loot` | Tab Loot Manager |
| `/rls config` | Tab Config |

## Interfaccia

- **Barra in alto**: in cima sta la **riga delle icone** (larga quanto la matrice): a sinistra in fila **rotellina Config**, **icona save (SaveRaid)** e **icona fase**, a destra la **X rossa** di chiusura; se c'è spazio compare anche il **nome della fase** accanto all'icona. L'icona fase cambia con la fase corrente (**occhio LFG animato** = pre-raid, **clessidra** = pre-boss, **spade** = in-fight) e al clic passa alla successiva. Sotto sta la **matrice di bottoni configurabile** (default **2×4**) con Groupmaking, Whisplist, Macrobar, Raid Frame, MS, Loot. I tab sono bistabili; le finestre si aprono come **pannelli liberi, spostabili** (posizione ricordata). **Eccezione**: il bottone **Macrobar** della barra mostra/nasconde la **HUD MacroBar** (non apre più una finestra tab).
- **SaveRaid**: salva un setup con un titolo richiesto da un prompt → **Comp** (composizione, raid, riservati, messaggio, whisplist), **MacroBar** (macro e layout) e **Config esclusa la categoria General**.
- **Config → Saved Raids** (voce sotto General): elenco dei salvataggi con il titolo e pulsante **Load** per ripristinare tutto.
- **Anchors stile ElvUI** in *Config → General → Finestra → Toggle Anchors*: le HUD **Raid Frame** e **MacroBar** sono bloccate di default; con Toggle Anchors compaiono come placeholder spostabili evidenziati. Le altre finestre restano normali.
- **Ridimensionabili** (maniglia in basso a destra): Groupmaking, Whisplist, MS Manager e Loot Manager; le dimensioni vengono ricordate.
- **Integrazione DBM/BigWigs**: se DBM (o BigWigs) è installato, pull timer, richiesta MS changes e roll/reroll avviano anche una barra-timer visibile.

## Moduli

- **Group Making** — composizione 10/25, messaggio LFG, spam canali, whisplist con invite
- **MacroBar** — 12 macro per fase (`preraid` / `preboss` / `infight`); keypad su due righe e dipendente dalla fase: **ready check** in pre-raid; in pre-boss prima riga **pull 15/20/30**, seconda riga **ready + break 5m/3m/2m**. L'editor 12 slot sta in **Config → Macros → Macro Editor**.
- **Raid Frame** — HP/mana, alert flask/food/buff, cooldown raid via combat log
- **MS Manager** — legge `ms <spec>` in raid chat e genera il pre-messaggio loot
- **Loot Manager** — history drop, roll, tie/reroll
- **Config** — tab stile ElvUI (lista a sinistra, pannello + sottotab a destra): aspetto, bordi, font, dimensioni, ancoraggi e Saved Raids. La categoria **Macros** contiene il sottotab **Bar Layout** (impostazioni della HUD) e **Macro Editor** (editor 12 slot per fase).

## Requisiti

- Client **3.3.5a** (non Retail / non Classic Era / non Cata)
- Permessi da **Raid Leader** o assist per raid warning, ready check e pull timer
