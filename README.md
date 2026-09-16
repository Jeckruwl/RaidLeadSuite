# RLSuite — Raid Leading Suite

An addon for **raid leaders** on World of Warcraft **Wrath of the Lich King 3.3.5** (Interface `30300`), designed for **Warmane Lordaeron**.

Version: **1.4.0**

## Installation

WoW loads the addon from the **folder name**, which must match the `.toc` file.

1. Download or clone this repository.
2. The folder must be named **`RaidLeadSuite`** (it already is the GitHub clone name — do not rename it).
3. Copy it into:

```
World of Warcraft/_classic_ or WotLK/Interface/AddOns/RaidLeadSuite
```

On Warmane / 3.3.5 clients the typical path is:

```
<WoW 3.3.5>/Interface/AddOns/RaidLeadSuite
```

The folder must contain:

- `RaidLeadSuite.toc`
- the `.lua` files (`Core.lua`, `Utils.lua`, …)
- the `Libs` folder (Ace3 libraries)

4. Restart the client (or `/reload` if the addon was already present).
5. In game: `/rls`

`ADDON_LOADED` recognizes the `RaidLeadSuite` folder name; the Ace3 libraries are loaded by the `.toc` (LibStub first).

## Commands

`/rls help` prints the list in chat.

| Command | Window |
|---|---|
| `/rls` or `/rlsuite` | Main bar (button matrix + phase) |
| `/rls help` | Command list |
| `/rls group` | Groupmaking tab |
| `/rls inviteengine` | InviteEngine (whisper + auto-invite). Alias: `/rls whisplist` |
| `/rls macro` | Config → Macros → Macro Editor |
| `/rls macrobar` | MacroBar HUD (show/hide) |
| `/rls raidframe` | Raid Frame settings tab |
| `/rls rfhud` | Raid Frame HUD |
| `/rls ms` | MS Manager tab |
| `/rls loot` | Loot Manager tab |
| `/rls config` | Config window (Ace3) |

## Interface

- **Top bar**: at the top sits the **icon row** (as wide as the matrix): on the left, in a row, the **Config gear**, the **save icon (SaveRaid)** and the **phase icon**; on the right, the red **close X**. If there is room, the **phase name** also appears next to the icon. The phase icon changes with the current phase (**animated LFG eye** = pre-raid, **hourglass** = pre-boss, **swords** = in-fight); **left-click** cycles to the next phase, **right-click** to the previous one. Below sits the **configurable button matrix** (default **2×4**) with Groupmaking, InviteEngine, Macrobar, Raid Manager, MS, Loot. The tabs are bistable; the windows open as **free, movable panels** (position remembered). **Exception**: the **Macrobar** button on the bar shows/hides the **MacroBar HUD** (it no longer opens a tab window).
- **SaveRaid**: saves a setup with a title requested via a prompt → **Comp** (composition, raid, reserved items, message, whisplist), **MacroBar** (macros and layout) and **Config except for the General category**.
- **Config → Saved Raids**: a top-level category in the Config tree with the list of saved setups (title + **Load**/**Delete** buttons).
- **ElvUI-style Anchors** in *Config → General → Window → Toggle Anchors*: the **Raid Frame** and **MacroBar** HUDs are locked by default; with Toggle Anchors they appear as highlighted movable placeholders. The other windows stay as usual.
- **Resizable** (grip in the bottom-right corner): Groupmaking, InviteEngine, MS Manager and Loot Manager; sizes are remembered.
- **DBM/BigWigs integration**: if DBM (or BigWigs) is installed, pull timer, MS-changes request and roll/reroll also start a visible timer bar.

## Modules

- **Group Making** — 10/25 composition, LFG message (the **Aim** note goes between difficulty/HC and "Need"), channel spam, **InviteEngine** panel (received whispers with invites + **Autoinviter**: manual name list with **Auto invite now**, or a linked **Calendar** raid event). In **debug mode** the spammer also fires 10 fake whispers and fake invitees auto-accept into the Raid Group and Raid Frame.
- **MacroBar** — 12 macros per phase (`preraid` / `preboss` / `infight`); a two-row keypad that depends on the phase: **ready check** in pre-raid; in pre-boss, first row **pull 15/20/30**, second row **ready + break 5m/3m/2m**. The 12-slot editor lives in **Config → Macros → Macro Editor**.
- **Raid Frame** — HP/mana, flask/food/buff alerts, raid cooldowns via combat log
- **MS Manager** — reads `ms <spec>` in raid chat and generates the loot pre-message
- **Loot Manager** — drop history, roll, tie/reroll
- **Config** — a single Ace3 window (AceGUI window + tree navigation): appearance, borders, font, sizes, anchors and Saved Raids. The **Macros** node contains **Bar Layout** (HUD settings) and the **Macro Editor** (12-slot per-phase editor, inside the same window).

## Requirements

- **3.3.5a** client (not Retail / not Classic Era / not Cata)
- **Raid Leader** or assistant permissions for raid warnings, ready check and pull timer
