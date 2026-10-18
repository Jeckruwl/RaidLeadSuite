# RLS – Raid Lead Suite

This addon aims to be the only tool you need to host and manage your Raids.

##   FEATURES:

### PHASE BASED MANAGEMENT:

this addon separates managing a RAid group in three phases:

- Pre-Raid: making the group, and managing the comp
- Pre-Boss: every moment between bosses with full raid group
- In-Fight: you are fighting a boss

### GROUPMAKING & INVITE ENGINE:

- Easily create and manage your LFM message
- Manage all your whispers in a unique place
- Autoinvite from a manual list
- Autoinvite from an in-game calendar event
- Drag&drop reorganization of raid group without looking at raid frame

### MACROBAR:

A practical tool to manage alerts in all possible situations. Each phase has it’s own 12 slot customizable macro actionbar and a panel with the common tools in that phase

**Pre-Raid:** ready check

**Pre-Boss:** ready check, Pull timers(15,20,30s), Break timers(2,3,5m)

**In-Fight:** no buttons but you can create a macro set for each boss. The addon knows which boss you are facing and provides the correct macro set, so you can see only the macros you need.

In the config panel you can create all the macros using the custom macro editor.

### RAID FRAME:

A convenient matrix based raid frame to monitor anything you need. It features:

- Distance-based fade out
- drag&drop reorganization
- Separate Main Tank & Main Assist frames

### RAID BUFFS & UTILITY:
A toggleable Raid Buff & Durability check window with alerts for all categories. Each category can be assigned a provider by dragging and dropping a name on the icon. Each icon features a tooltip showing:

- Actual comp providers in the raid
- Assigments: Who is asigned to what
- how many are missing the buff

Buff category icons are color coded based on the current composition:

- greyed-out: The comp can’t provide for it
- red: someone is missing the buff. Clicking the icon sends raid warning alerts
- normal: everyone that needs the buff has it

Buff alerts can also be character specific. Ctrl-click on a name in the frame sends an alert with the buffs missing and the players who have to provide for them.

### COOLDOWNS WATCHER:
A Panel based bar CD watcher to montor all the Cooldowns of your raid.
Comes with a database already but will feature the ability to add any spells and/or item CD in the future.
CDs are grouped my category and can either be displayed in one of three modes:
- single panel per category
- Default groups of category
- custom Panels

Spells in a panel gan be grouped by:
- Caster
- Ability
- none

Custom panels lets you choose which spell to put in up to 6 panels for which you can set a name.
Spells can be chosen from a database window and simply dragged and dropped inside the custom panels

each bar is fully customizable but has different fixed modes with their indicators on the right:
- In CD
- Ready Alive (green bar and square indicator)
- Ready DEAD (Greyed bar with skull icon)
- Ready Disconnected (reddish black bar with null icon)

### MS CHANGE MANAGER:

Quick and easy one button MS changes, with timer. Automatically scans the raid chat and stores the specs. Text is parsed with regards to every spec’s short form or abbreviation.

Features easy one click-announcement with auto filled message.

### LOOT MANAGER:

Chronological loot list with loot timers. Features:

- Rarity threshold
- Custom ignore list: Ctrl-click on an item to ignore it forever
- BOE, Recipe, Shards filters to ignore if reserved
- Roll MS,OS,FFA, Reroll, Reserved(User + Raid)
- Double rolls filter
- Winner announcement
- Roll timers
- Click to pick up window: each won roll pops up a window with the item in it and the winning player’s name. You just need to click it and drop it in the trade, no more scrambling in your bags.

### RAID PROFILES:

Stores the choices made in groupmaking, macrobar options and configs in a reusable profile so you don't have to set up each time for the same raid




!!!!screens not updated!!!!
<details>
<summary>Clicca per vedere gli screenshot</summary>

**GroupMaking**
![GroupInv](_dev/RLS%20screens/0.0_grpinv.png)

**Macro Bar**

![Macro Bar](_dev/RLS%20screens/2.0_macrob.png)
![Macro Editor](_dev/RLS%20screens/1.0_macroed.png)

**Raid Frame**
![RaidFrame](_dev/RLS%20screens/3.0_raidframe.png)

**Raid Buffs**
![MSCM](_dev/RLS%20screens/4.0_rbuffs.png)

**Cooldown Watcher(custom panels)s**
![MSCM](_dev/RLS%20screens/5.0_cdwpanele.png)

**Cooldown watcher(CD Database)**
![MSCM](_dev/RLS%20screens/6.0_cdwdatab.png)

**MS Change Manager**
![MSCM](_dev/RLS%20screens/7.0_mscm.png)

**Loot Manager**
![LootM](_dev/RLS%20screens/8.0_lootm.png)

**Raid control bar**
![LogW](_dev/RLS%20screens/9.0_rcb.png)

</details>
