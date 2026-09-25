-- ============================================================
-- RLSuite - Locale (AceLocale-3.0)
-- enUS is the primary/default locale. Every user-facing string is looked up
-- through RLSuite.L, which is the AceLocale-3.0 table for the "RLSuite"
-- application. Writing `true` stores the key itself as the value (standard
-- AceLocale semantics), and any missing key resolves to its own text, so
-- lookups always return English. Other locales can be added later by
-- registering the same application, e.g.
--   local L = AceLocale:NewLocale("RLSuite", "itIT")
--   if L then L["Save"] = "Salva" end
-- ============================================================

RLSuite = RLSuite or {}

local AceLocale = LibStub("AceLocale-3.0")

-- Fallback table used only if AceLocale were unavailable for some reason
-- (the library is bundled and always loaded, so this is purely defensive).
local L = AceLocale and AceLocale:NewLocale("RLSuite", "enUS", true, true)
if not L then
    L = setmetatable({}, {
        __index = function(_, key)
            return key
        end,
        __newindex = function(t, key, value)
            rawset(t, key, value == true and key or value)
        end,
    })
end

do
    -- Core
    L["v%s loaded. Type /rls to open."] = true
    L["Available commands:"] = true
    -- Lista PUBBLICA (solo comandi d'uso normale): la diagnostica e gli alias
    -- restano attivi ma fuori da questo elenco (elenco completo in
    -- _dev/commands.txt).
    L["  /rls            Main bar (buttons + phase)"] = true
    L["  /rls help       This list"] = true
    L["  /rls config     Config window"] = true
    L["  /rls group      Groupmaking panel"] = true
    L["  /rls inv        InviteEngine (whisper + auto-invite)"] = true
    L["  /rls macrobar   MacroBar HUD"] = true
    L["  /rls ms         MS Manager panel"] = true
    L["  /rls loot       Loot Manager panel"] = true
    L["  /rls raidframe  Raid Frame HUD"] = true
    L["Unknown command. Type /rls help for the list."] = true
    L["DEBUG MODE ON"] = true
    L["Simulated raid, messages are whispered to you."] = true
    L["Phase set: %s"] = true
    L["Save cancelled: empty title."] = true
    L['SaveRaid "%s" saved (%d total).'] = true
    L['SaveRaid "%s" deleted.'] = true
    L["Save not found (id %s)."] = true
    L['SaveRaid "%s" loaded.'] = true

    -- LootManager
    L["No item selected"] = true
    L["Select an item from the history first!"] = true
    L["Loot debug: %d items from %s"] = true

    -- GroupMaking
    L["Composition"] = true
    L["Click a spec to add"] = true
    L["Aim"] = true
    L["Reserved items"] = true
    L["Other requirements"] = true
    L["Message preview..."] = true
    L["No available slot for %s"] = true
    L["Message: %s"] = true
    L["AtlasLoot is not loaded."] = true
    L["Spammer started."] = true
    L["Spammer stopped."] = true
    L["Channel #"] = true
    L["Explicit channel number; leave empty (or 0) to auto-detect by name."] = true
    L["Whisper from %s received."] = true
    L["Received whispers"] = true
    L["Raid Group"] = true
    L["Select a player"] = true
    -- InviteEngine (ex-Whisplist): tab + Autoinviter
    L["InviteEngine"] = true
    L["Whisplist"] = true
    L["Autoinviter"] = true
    L["Manual list"] = true
    L["Calendar event"] = true
    L["Link to RLS"] = true
    L["Open your raid event and tick 'Link to RLS'."] = true
    L["Create/save the event first, then tick 'Link to RLS'."] = true
    L["Event linked: %s"] = true
    L["Event unlinked."] = true
    L["No event linked yet."] = true
    L["Created by %s"] = true
    L["Names (one per line)"] = true
    L["Add player"] = true
    L["Enter to add"] = true
    L["Enter to add - click X to remove"] = true
    L["Create/Update"] = true
    L["Invite new member"] = true
    L["Event updated."] = true
    L["Could not open the linked event."] = true
    L["Raid event"] = true
    L["Refresh"] = true
    L["Create event"] = true
    L["No raid events today"] = true
    L["%d players signed up"] = true
    L["No calendar event linked"] = true
    L["Link an existing event above, or create a new one."] = true
    L["Calendar addon could not be loaded."] = true
    L["Create the raid event, then press Refresh to link it."] = true
    L["Invite at"] = true
    L["(server time)"] = true
    L["Start Autoinviter"] = true
    L["Stop Autoinviter"] = true
    L["Auto invite now"] = true
    L["Autoinvite at set time"] = true
    L["Autoinviter: no names to invite."] = true
    L["Autoinviter armed: %d names."] = true
    L["Autoinviter: all invites sent."] = true
    L["Autoinviter: inviting %d names now."] = true
    -- Campi modificabili della tab Calendar event
    L["Title"] = true
    L["Type"] = true
    L["Day"] = true
    L["Time"] = true
    L["Attending"] = true
    L["%d attending"] = true
    -- Tipi evento (fallback se CalendarEventGetTypes non e' disponibile)
    L["Raid"] = true
    L["Dungeon"] = true
    L["PvP"] = true
    L["Meeting"] = true
    L["Other"] = true
    -- Stato degli invitati (specchio evento Calendario)
    L["Invited"] = true
    L["Accepted"] = true
    L["Declined"] = true
    L["Confirmed"] = true
    L["Out"] = true
    L["Standby"] = true
    L["Signed up"] = true
    L["Not signed up"] = true
    L["Tentative"] = true
    L["Armed: inviting in %d:%02d (%d names)"] = true
    L["Inviting %d/%d..."] = true
    L["Slot already taken!"] = true
    L["Class not recognized for %s"] = true
    L["%s invited to slot %d"] = true

    -- MSManager
    L["Name"] = true
    L["Spec"] = true
    L["MS change detected: %s -> %s"] = true
    L["No MS changes recorded."] = true
    L["Requesting MS changes - type in raid: ms <spec> you have only 40s"] = true

    L["Open the trade with the winner first, then click the item icon."] = true

    -- CombatLog
    L["Spam channels"] = "Canali spam"
    L["Channel #"] = "N° canale"
    L["Explicit channel number; leave empty (or 0) to auto-detect by name."] = "Numero canale esplicito; lascia vuoto (o 0) per rilevarlo dal nome."
L["General"] = "Generale"
L["Trade"] = "Commercio"
L["LookingForGroup"] = "Ricerca Gruppo"
L["World"] = "Mondo"
L["global"] = "globale"

L["Debug: loot history cleared."] = "Debug: storico loot svuotato."
L["Test MS"] = "Test MS"
L["Debug mode is OFF."] = "Modalita' debug OFF."
L["Debug: raid filled with %d fake players."] = "Debug: raid riempito con %d giocatori fittizi."
L["Debug: loot spawned from %s."] = "Debug: loot generato da %s."
L["Log Test"] = "Test log"
L["Debug: combat log filled with %d fights."] = "Debug: combat log riempito con %d pull."
L["Debug: %d fake whispers sent."] = "Debug: %d whisper fittizi inviati."
L["Debug: %d fake MS whispers sent."] = "Debug: %d whisper MS fittizi inviati."
L["Ask MS changes first (MS Manager), then click Test MS."] = "Chiedi prima gli MS change (MS Manager), poi clicca Test MS."
L["Start the spammer first, then Whisp test sends the fake whispers."] = "Avvia prima lo spammer, poi Whisper di test invia i whisper fittizi."

    L["Combat log"] = true
    -- Riga di stato del pannello Log (v1.11.70)
    L["Recording"] = true
    L["Idle"] = true
    L["events lost"] = true
    L["recovered by watchdog"] = true
    L["watchdog recoveries"] = true
    L["you died at"] = true
    L["Window error"] = true
    L["pulls"] = true
    L["Pull marked as %s."] = true
    L["Close the pull first."] = true
    L["Right-click: mark this pull as boss/trash"] = true
    L["boss"] = true
    L["trash"] = true
    L["Select fight"] = true
    L["Send report"] = true
    L["Shift+click to wipe the saved fights."] = true
    L["No fights recorded"] = true
    L["[LIVE]"] = true
    L["Live"] = true
    L["Events"] = true
    L["dropped"] = true
    L["Total"] = true
    L["By cast"] = true
    L["By target"] = true
    L["Spells list"] = true
    L["Select player"] = true
    L["Uptime"] = true
    L["Interrupts"] = true
    L["Dispels"] = true
    L["Damage"] = true
    L["Healing"] = true
    L["Enemies"] = true
    L["Auras"] = true
    L["Players spells"] = true
    L["Power"] = true
    L["Graphs"] = true
    L["DPS"] = true
    L["Health"] = true
    L["Total DPS"] = true
    L["Step, sec."] = true
    L["drag: zoom, click: reset, hover: values"] = true

    -- MacroBar
    L["Macrobar is disabled in Config."] = true
    L["Phase: %s"] = true
    L["Chat edit box not found."] = true
    L["Edit Macro %d"] = true
    L["Phase:"] = true
    L["Macro (max 10 lines):"] = true
    L["Save"] = true
    L["Cancel"] = true
    L["Macro %d saved for phase %s"] = true
    L["Empty"] = true
    L["Click a row, then press a key. Backspace or right-click to clear."] = true
    L["Press a key for Macro %d (Esc cancels)."] = true
    L["You must be raid leader or assist to use the pull timer."] = true
    L["You must be raid leader or assist to use the break timer."] = true

    -- RaidFrame
    L["Hey $name, you're missing a flask!"] = true
    L["Missing flask"] = true
    L["Missing food buff"] = true
    L["Tanks"] = true
    L["Raid Buffs"] = true
    L["Font color"] = true
    L["Icon spacing"] = true
    L["Gap between the Raid Buffs matrix icons."] = true
    L["Row spacing"] = true
    L["Gap between the player bars inside each group."] = true
    L["Group spacing"] = true
    L["Gap between the groups (Tanks, G1..G6)."] = true
    L["Group header font size"] = true
    L["Font size of the group labels (Tanks, G1..G6)."] = true
    L["Buff check backdrop"] = true
    L["Backdrop color and transparency of the Raid Buffs matrix rows."] = true
    L["Buff check: %s - OK on everyone"] = true
    L["Buff check: %s - missing: %s"] = true
    L["Buff check: %s - not available in this composition"] = true
    L["Buff check: %s - %d/%d"] = true
    L[" - mages missing: %s"] = true
    L["Not available in this composition"] = true
    L["OK on everyone"] = true
    L["Missing: %d"] = true
    L["Covered: %d/%d"] = true
    -- (/rls debugbuff resta ATTIVO, solo non elencato)
    L["Buff headers: media/BUFFCATICONS/BCI_<0..24>.tga"] = true
    L["Raid frame not initialized yet."] = true
    L["Color of the player name on the bars."] = true
    L["Open the raid buffs matrix panel."] = true
    L["Main tank"] = true
    L["Main assist"] = true
    L["Cannot assign Main Tank / Main Assist while in combat."] = true
    L["Main assist"] = true
    L["Hey $name, you're missing food buff!"] = true
    -- Avvisi in stile raid leading: dritti al punto, nessun "Hey". Il vecchio
    -- testo resta registrato perche' un profilo salvato che lo contiene viene
    -- riconosciuto e sostituito dal nuovo.
    L["Hey $name, you're missing some raid buffs!"] = true
    L["Missing buffs on $name:"] = true
    L["Assignment: provide %s for the raid."] = true
    L["Left click: whisper"] = true
    L["Right click: raid warning"] = true
    L["Right click: raid warning (everyone missing)"] = true
    L["Shift + left drag on a row: move player"] = true
    L["Shift + right drag: move window"] = true
    L["Pull in %d seconds!"] = true
    L["Pull in %d..."] = true
    L["PULL NOW!"] = true
    L["BREAK TIME - %s!"] = true
    L["BREAK OVER - back in position!"] = true
    L["Break ends in %d..."] = true
    L["Break ends in %d min..."] = true

    -- RaidProfile (main window)
    L["Phase"] = true
    L["Phase indicator"] = true
    L["Show/Hide HUD"] = true
    L["SaveRaid title:"] = true
    L["SaveRaid cancelled: no title entered."] = true
    -- MT / OT buttons (Main Tank / Main Assist assignment)
    L["Main Tank (MT)"] = true
    L["Main Assist (OT)"] = true
    L["Assign/remove your current target as Main Tank."] = true
    L["Assign/remove your current target as Main Assist."] = true
    L["%s assignment is not available on this client."] = true
    L["Target a raid member first to assign %s."] = true
    L["Only the raid leader or an assist can assign Main Tank / Main Assist."] = true
    L["%s toggled as %s."] = true

    -- Minimap icon
    L["Left click: open RLS"] = true
    L["Right click: config"] = true
    L["Shift + left drag: move"] = true
    L["Minimap icon: %s"] = true
    L["RLSuite minimap error: %s"] = true

    -- Config
    L["Appearance"] = true
    L["Window"] = true
    L["General Appearance"] = true
    L["Presets and background/border colors. Does not change functionality."] = true
    L["Theme:"] = true
    L["Background:"] = true
    L["Panel background:"] = true
    L["Borders:"] = true
    L["Border thickness"] = true
    L["Font size"] = true
    L["Simulates a raid group. Macros, LFM, rolls, loot and MS changes are whispered to you. Fake loot uses the raid selected in Groupmaking."] = true
    L["Enable debug mode"] = true
    L["Fill fake loot"] = true
    L["Bar and tab windows"] = true
    L["The bar automatically adapts to the button matrix (the phase icon with its name sits in the title bar). Here you set the default height of the tab windows and the bar scale."] = true
    L["Default window height"] = true
    L["Bar scale"] = true
    L["Button matrix (bar only)"] = true
    L["How many columns and buttons per column to use for the bar buttons. SaveRaid is a normal button of the matrix; the phase icon (with the phase name) sits in the title bar and cycles to the next phase on click."] = true
    L["Columns"] = true
    L["Buttons per column"] = true
    L["HUD anchors (ElvUI style)"] = true
    L["Unlocks the Raid Frame and MacroBar HUDs and shows them as movable placeholders. Other windows stay as usual."] = true
    L["Scale"] = true
    L["The visible HUD buttons match the macros filled in the current phase."] = true
    L["Raid Frame - HUD layout"] = true
    L["Width"] = true
    L["HP bar height"] = true
    L["Icon size"] = true
    L["Raid Frame - position"] = true
    L["Lock position"] = true
    L["Reset position"] = true
    L["Shows or hides the button panel under this bar."] = true
    L["Saves the current setup (Comp, MacroBar, Config)."] = true
    L["Saves created with the SaveRaid button of the main bar. Click Load to restore Comp, MacroBar and Config (except General)."] = true
    L["No saves yet."] = true
    L["Save #%d"] = true
    L["All macros"] = true
    L["Boss macros: %s"] = true
    L["Raid:"] = true
    L["Boss:"] = true
    L["In fight the bar uses the boss you are facing"] = true
    L["No boss detected: in-fight macros are per boss."] = true
    L["Macro"] = true
    L["Name:"] = true
    L["Macro icon"] = true
    L["Position"] = true

    -- Utils
    L['DBM/BigWigs not available: timer "%s" not started.'] = true
end

RLSuite.L = (AceLocale and AceLocale:GetLocale("RLSuite", true)) or L
