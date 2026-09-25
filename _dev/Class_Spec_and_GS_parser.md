# Class and spec parser rules

| SPEC | CLASS | PREFIX | BODY | SUFFIX | CLASS SPECIFIC RULES | GENERAL RULES (apply to all classes and specs) |
| --- | --- | --- | --- | --- | --- | --- |
| Unholy | Death Knight | U / UH / Unholy | DK | U / UH / Unholy | | IF there is no specific class rule overriding this THEN IF there's SUFFIX there is no PREFIX and vice versa<br><br>ALL ELEMENTS CAN BE UPPERCASE or lowercase or have only the first letter be UPPERCASE |
| Blood | Death Knight | B / Blood | DK | B / Blood | | |
| Frost | Death Knight | F / Frost | DK | F / Frost | | |
| Balance | Druid | None / Balance | Druid / dudu / Boomkin / Boomie | None / Balance | IF BODY = Boomkin OR Boomie THEN prefix and suffix are empty | |
| Feral Cat | Druid | F / Cat | Druid / dudu | Feral / Cat | SUFFIX CAN BE BOTH OPTIONS AT THE SAME TIME ("Feral Cat/Bear")<br>IF PREFIX is present THEN there can be SUFFIX | |
| Feral Bear | Druid | F / Bear | Druid / dudu | Feral / Bear | | |
| Restoration | Druid | R / Resto | Druid / dudu | Resto | | |
| Beast Mastery | Hunter | BM | Hunter / Hunt | BM | | |
| Marksmanship | Hunter | MM | Hunter / Hunt | MM | | |
| Survival | Hunter | S / Surv / Survival | Hunter / Hunt | S / Surv / Survival | | |
| Fire | Mage | F / Fire | Mage | Fire | | |
| Frost | Mage | Frost | Mage | Frost | | |
| Arcane | Mage | Arcane | Mage | Arcane | | |
| Protection | Paladin | P / Prot / Protection | Pal / Pala / Paladin | Prot / Protection | | |
| Retribution | Paladin | R / Ret / Retri / Retribution | Pal / Pala / Paladin | Ret / Retri / Retribution | | |
| Holy | Paladin | H / Holy | Pal / Pala / Paladin | Holy | | |
| Shadow | Priest | S / Sh / Shadow | Priest | Shadow | | |
| Discipline | Priest | D / Disci / Discipline | Priest / Disco | Disci / Disco | IF BODY = Disco THEN no PREFIX AND no SUFFIX | |
| Holy | Priest | H / Holy | Priest | Holy | | |
| Combat | Rogue | C / Combat | Rog / Rogue | Combat | | |
| Assassination | Rogue | Assa / Assassination | Rog / Rogue | Assa / Assassination | | |
| Sublety | Rogue | S / Sub / Sublety | Rog / Rogue | S / Sub / Sublety | | |
| Enhancement | Shaman | Enha / Enhancement | Sham / Shammy / Shaman | Enha / Enhancement | | |
| Elemental | Shaman | Ele / Elemental | Sham / Shammy / Shaman | Ele / Elemental | | |
| Restoration | Shaman | R / Resto | Sham / Shammy / Shaman | Resto | | |
| Afliction | Warlock | Aff / Affly / Afliction | Lock / Warlock | Aff / Affly / Afliction | | |
| Demonology | Warlock | Demo / Demonology | Lock / Warlock | Demo / Demonology | | |
| Destruction | Warlock | Destro / Destriction | Lock / Warlock | Destro / Destriction | | |
| Fury | Warrior | F / Fury | War / Warr / Warrior | Fury | | |
| Arms | Warrior | Arms | War / Warr / Warrior | Arms | | |
| Proection | Warrior | P / Prot / Protection | War / Warr / Warrior | Prot / Protection | | |

### GS FORMS (tabella di riferimento accanto alle prime righe)

| GS FORMS | PREFIX | Numero esempio | Suffisso |
| --- | --- | --- | --- |
| whole number | None / k / K | 6542 | None / gs / GS |
| short number | | 6 | |
| short number decimal | | 6.5 / 6,5 | |

### Elenco classi (colonna C, righe 53–62)

Death Knight, Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior

---

# GS parser rules

| GS FORMS | PREFIX | NUMBER | SUFFIX 1 | SUFFIX 2 | RULES |
| --- | --- | --- | --- | --- | --- |
| whole number | None / gs / GS | 6542 | | None / gs / GS | IF PREFIX IS NOT "none" THEN there is no SUFFIX 2 |
| short number | | 6 | None / k / K | | |
| short number decimal | | 6.5 / 6,5 | None / k / K | | |
