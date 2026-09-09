# RLSuite — Raid Leading Suite

Addon per **raid leader** su World of Warcraft **Wrath of the Lich King 3.3.5** (Interface `30300`), pensato per **Warmane Lordaeron**.

Versione: **1.2.0**

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
| `/rls` o `/rlsuite` | Finestra principale (tutte le tab) |
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

## Moduli

- **Group Making** — composizione 10/25, messaggio LFG, spam canali, whisplist con invite
- **MacroBar** — 12 macro per fase (`preraid` / `preboss` / `infight`), pull 15/20/30, ready check
- **Raid Frame** — HP/mana, alert flask/food/buff, cooldown raid via combat log
- **MS Manager** — legge `ms <spec>` in raid chat e genera il pre-messaggio loot
- **Loot Manager** — history drop, roll, tie/reroll

## Requisiti

- Client **3.3.5a** (non Retail / non Classic Era / non Cata)
- Permessi da **Raid Leader** o assist per raid warning, ready check e pull timer
