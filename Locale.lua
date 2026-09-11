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
    L["  /rls              Tab bar"] = true
    L["  /rls help         This list"] = true
    L["  /rls group        Groupmaking tab"] = true
    L["  /rls inviteengine InviteEngine panel (whisper + auto-invite)"] = true
    L["  /rls whisplist    InviteEngine panel (alias)"] = true
    L["  /rls macro        Config -> Macros (editor)"] = true
    L["  /rls macrobar     HUD MacroBar"] = true
    L["  /rls raidframe    Raid Frame tab (settings)"] = true
    L["  /rls rfhud        HUD Raid Frame"] = true
    L["  /rls ms           MS Manager tab"] = true
    L["  /rls loot         Loot Manager tab"] = true
    L["  /rls config       Config tab"] = true
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
    L["Names (one per line)"] = true
    L["Add player"] = true
    L["Enter to add"] = true
    L["Enter to add - right-click a name to remove"] = true
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
    L["Autoinviter: no names to invite."] = true
    L["Autoinviter armed: %d names."] = true
    L["Autoinviter: all invites sent."] = true
    L["Autoinviter: inviting %d names now."] = true
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
    L["Hey $name, you're missing food buff!"] = true
    L["Hey $name, you're missing some raid buffs!"] = true
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
    L["The bar automatically adapts to the matrix and the top icon row (Config, SaveRaid, phase). Here you set the default height of the tab windows and the bar scale."] = true
    L["Default window height"] = true
    L["Bar scale"] = true
    L["Button matrix (bar only)"] = true
    L["How many columns and buttons per column to use for the bar buttons. Above the matrix sit the icons (Config, SaveRaid, phase); the phase icon shows the current phase and cycles to the next on click."] = true
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
    L["Saves created with the SaveRaid button in the top bar. Click Load to restore Comp, MacroBar and Config (except General)."] = true
    L["No saves yet."] = true
    L["Save #%d"] = true
    L["All macros"] = true
    L["Macro"] = true
    L["Name:"] = true
    L["Macro icon"] = true
    L["Position"] = true

    -- Utils
    L['DBM/BigWigs not available: timer "%s" not started.'] = true
end

RLSuite.L = (AceLocale and AceLocale:GetLocale("RLSuite", true)) or L
