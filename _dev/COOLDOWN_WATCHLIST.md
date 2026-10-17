# Raid Cooldown Watchlist — WotLK 3.3.5

Questo file è il riferimento completo per categorie, abilità e Spell ID del CD Watcher. Il rilevamento delle abilità avviene tramite Spell ID; le spell Fear e Banish sono disponibili soltanto durante Trial of the Crusader / Trial of the Grand Crusader a 10 o 25 giocatori. Le barre Tank Defensive includono esclusivamente i giocatori assegnati MT/OT.

## Tank Defensive
- Shield Wall — Guerriero — Spell ID `871`
- Last Stand — Guerriero, specializzazione Protection — Spell ID `12975`
- Icebound Fortitude — Cavaliere della Morte — Spell ID `48792`
- Anti-Magic Shell — Cavaliere della Morte — Spell ID `48707`
- Vampiric Blood — Cavaliere della Morte, specializzazione Blood — Spell ID `55233`
- Barkskin — Druido — Spell ID `22812`
- Survival Instincts — Druido, specializzazione Feral — Spell ID `61336`
- Frenzied Regeneration — Druido, specializzazione Feral — Spell ID `22842`
- Divine Protection — Paladino — Spell ID `498`

## Raid Wide Offensive
- Bloodlust / Heroism — Sciamano — Spell ID `2825` / `32182`
- Shattering Throw — Guerriero, specializzazione Arms — Spell ID `64382`

## Raid/Party Wide Defensive
- Aura Mastery — Paladino, specializzazione Holy — Spell ID `31821`
- Divine Sacrifice — Paladino, specializzazione Protection — Spell ID `64205`
- Divine Hymn — Sacerdote — Spell ID `64843`
- Anti-Magic Zone — Cavaliere della Morte, specializzazione Unholy — Spell ID `51052`
- Tranquility — Druido — Spell ID `48447`, `26983`, `9863`, `740`

## Single Target Offensive
- Power Infusion — Sacerdote, specializzazione Discipline — Spell ID `10060`
- Hysteria — Cavaliere della Morte, specializzazione Blood — Spell ID `49016`

## Single Target Defensive
- Hand of Sacrifice — Paladino — Spell ID `6940`
- Hand of Protection — Paladino — Spell ID `1022`, `5599`, `10278`
- Lay on Hands — Paladino — Spell ID `633`, `2800`, `10310`, `27154`, `48788`
- Pain Suppression — Sacerdote, specializzazione Discipline — Spell ID `33206`
- Guardian Spirit — Sacerdote, specializzazione Holy — Spell ID `47788`

## Battle Resurrection
- Rebirth — Druido — Spell ID `48477`, `26994`, `20748`, `20484`
- Soulstone — Stregone — Spell ID `47884`, `47883`, `27239`, `20765`, `20764`, `20763`, `20762`, `20707`; stato tracciato: disponibile, piazzata o consumata

## Mana Regeneration
- Innervate — Druido — Spell ID `29166`
- Mana Tide Totem — Sciamano — Spell ID `16190`
- Hymn of Hope — Sacerdote — Spell ID `64901`

## Threat (Taunt and Aggro)
- Misdirection — Cacciatore — Spell ID `34477`
- Tricks of the Trade — Ladro — Spell ID `57934`
- Taunt — Guerriero — Spell ID `355`
- Hand of Reckoning — Paladino — Spell ID `62124`
- Righteous Defense — Paladino — Spell ID `31789`
- Hand of Salvation — Paladino — Spell ID `1038`, `25895`
- Dark Command — Cavaliere della Morte — Spell ID `56222`
- Death Grip — Cavaliere della Morte — Spell ID `49576`
- Growl — Druido — Spell ID `6795`

## Interrupt Rotation
Rotazione e prossimo pronto.

- Pummel — Guerriero — Spell ID `6552`
- Shield Bash — Guerriero — Spell ID `72`
- Silencing Shot — Cacciatore — Spell ID `34490`
- Kick — Ladro — Spell ID `1766`
- Mind Freeze — Cavaliere della Morte — Spell ID `47528`
- Strangulate — Cavaliere della Morte — Spell ID `47476`
- Wind Shear — Sciamano — Spell ID `57994`
- Counterspell — Mago — Spell ID `2139`
- Spell Lock — Stregone, Vilsegugio — Spell ID `19647`

## Crowd Control
- Polymorph — Mago — Spell ID `118`, `12824`, `12825`, `12826`, `28271`, `28272`, `61025`
- Cyclone — Druido — Spell ID `33786`
- Entangling Roots — Druido — Spell ID `339`, `1062`, `5195`, `5196`, `9852`, `9853`, `26989`
- Hex — Sciamano — Spell ID `51514`
- Blind — Ladro — Spell ID `2094`
- Freezing Trap — Cacciatore — Spell ID `14311`, `14310`, `14309`, `3355`
- Sap — Ladro — Spell ID `6770`, `2070`, `11297`, `51724`
- Wyvern Sting — Cacciatore — Spell ID `49012`, `49011`
- Fear — Stregone — Spell ID `5782`, `6213`, `6215`; solo Trial of the Crusader / Trial of the Grand Crusader a 10 o 25 giocatori
- Banish — Stregone — Spell ID `710`, `18647`, `18648`; solo Trial of the Crusader / Trial of the Grand Crusader a 10 o 25 giocatori

## Utility / Dispel
- Fear Ward — Sacerdote — Spell ID `6346`
- Tremor Totem — Sciamano — Spell ID `8143`
- Mass Dispel — Sacerdote — Spell ID `32375`
- Tranquilizing Shot — Cacciatore — Spell ID `19801`
- Purge — Sciamano — Spell ID `370`, `8012`, `27626`, `33625`
- Grounding Totem — Sciamano — Spell ID `8177`
- Spellsteal — Mago — Spell ID `30449`
- Divine Intervention — Paladino — Spell ID `19752`

## UI and assignment behavior
- Le etichette delle categorie sono mostrate per esteso, senza sigle.
- `Bloodlust / Heroism` è mostrato come `Bloodlust` per la fazione Horde e `Heroism` per la fazione Alliance.
- `Bar options > Abbreviate spell names` (attivo per default) accorcia solo le etichette delle barre e i raggruppamenti per spell; tooltip e annunci raid usano il nome completo. Le sigle attuali sono: Icebound Fortitude → IBF; Anti-Magic Shell → AMS; Vampiric Blood → Vamp Blood; Survival Instincts → SI; Frenzied Regeneration → Frenzied Regen; Divine Protection → DP; Aura Mastery → AM; Divine Sacrifice → DSAC; Anti-Magic Zone → AMZ; Tranquility → Tranq; Power Infusion → PI; Hand of Sacrifice → HoSac; Hand of Protection → HOP; Lay on Hands → LoH; Pain Suppression → PS; Guardian Spirit → GS; Soulstone → SS; Mana Tide Totem → Mana Tide; Hymn of Hope → HoH; Misdirection → MD; Tricks of the Trade → Tricks; Hand of Reckoning → HoR; Righteous Defense → RD; Hand of Salvation → HoSalv; Dark Command → DC; Death Grip → DG; Shield Bash → SB; Mind Freeze → MF; Counterspell → CS; Spell Lock (Felhunter) → Spell Lock; Polymorph → Poly; Entangling Roots → Roots; Tremor Totem → Tremor; Tranquilizing Shot → Tranq Shot; Grounding Totem → Grounding; Divine Intervention → DI.
- Le barre riportano soltanto `Nome spell:Nome player  Cooldown`; target, stato, durata e altri dettagli sono nel tooltip.
- Trascinare una barra CD Watcher su una riga giocatore del Raid Frame assegna il target della spell, non il caster.
- Trascinare un giocatore dal Raid Frame sulla categoria Tank Defensive assegna il primo ruolo MT/OT libero. Se MT/OT non sono assegnati, la categoria mostra: `assign MT, OT or drag&drop Tanks here from Raid Frame`.
- Sated / Exhaustion non fanno parte della watchlist.
