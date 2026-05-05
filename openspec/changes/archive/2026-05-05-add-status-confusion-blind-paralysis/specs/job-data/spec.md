## MODIFIED Requirements

### Requirement: JobData carries a resists dictionary

The system SHALL extend `JobData` with `@export var resists: Dictionary = {}` mapping `StringName` resist keys to `float` values. Negative values are allowed.

The eight existing job `.tres` files SHALL declare resists as follows:

| Job | resists |
|-----|---------|
| fighter | `{ &"sleep": 0.10, &"confusion": 0.10 }` |
| mage | `{ &"silence": -0.20 }` |
| priest | `{ &"silence": -0.10 }` |
| thief | `{ &"paralysis": 0.10 }` |
| ninja | `{ &"paralysis": 0.20, &"sleep": 0.10 }` |
| bishop | `{}` |
| samurai | `{ &"confusion": 0.10 }` |
| lord | `{ &"silence": -0.05 }` |

#### Scenario: Fighter resists sleep and confusion
- **WHEN** `fighter.tres` is loaded
- **THEN** `resists` SHALL be `{&"sleep": 0.10, &"confusion": 0.10}`

#### Scenario: Mage is vulnerable to silence
- **WHEN** `mage.tres` is loaded
- **THEN** `resists.get(&"silence")` SHALL be `-0.20`

#### Scenario: Priest is moderately vulnerable to silence
- **WHEN** `priest.tres` is loaded
- **THEN** `resists.get(&"silence")` SHALL be `-0.10`

#### Scenario: Ninja resists paralysis and sleep
- **WHEN** `ninja.tres` is loaded
- **THEN** `resists` SHALL contain `{&"paralysis": 0.20, &"sleep": 0.10}`

### Requirement: JobData declares spell_progression for magic-capable jobs

`JobData` SHALL declare a `spell_progression: Dictionary` field whose keys are job-level integers (`int`, indicating "the level at which these spells are first granted"), and whose values are `Array[StringName]` of spell ids learned at that level. For jobs with neither magic school flag set, `spell_progression` SHALL be empty (`{}`).

The progression after this change SHALL be:

| Job | spell_progression |
|---|---|
| fighter | {} |
| thief | {} |
| ninja | {} |
| mage | { 1: [&"fire", &"frost", &"dazil"], 2: [&"katino", &"manifo", &"morlis", &"dilto", &"sopic", &"madalto"], 3: [&"flame", &"blizzard", &"poison_dart", &"badi"] } |
| priest | { 1: [&"heal", &"holy", &"calfo"], 2: [&"dios", &"porfic", &"bamatu", &"varyu"], 3: [&"heala", &"allheal", &"madi", &"maporfic"], 5: [&"dialma"] } |
| bishop | { 2: [&"fire", &"frost", &"heal", &"holy", &"katino", &"manifo", &"dios", &"morlis", &"dilto", &"sopic", &"porfic", &"bamatu", &"varyu", &"dazil", &"madalto", &"calfo"], 5: [&"flame", &"blizzard", &"heala", &"allheal", &"poison_dart", &"madi", &"maporfic", &"badi"] } |
| samurai | { 4: [&"fire", &"frost"], 8: [&"flame", &"blizzard"] } |
| lord | { 4: [&"heal", &"holy"], 8: [&"heala", &"allheal"] } |

Spell ids in `spell_progression` SHALL match a real `SpellData.id` from `data/spells/`.

#### Scenario: Mage learns dazil at level 1 alongside fire and frost
- **WHEN** `mage.tres` is loaded
- **THEN** `spell_progression[1]` SHALL contain exactly `&"fire"`, `&"frost"`, `&"dazil"`

#### Scenario: Mage learns madalto at level 2
- **WHEN** `mage.tres` is loaded
- **THEN** `spell_progression[2]` SHALL contain `&"madalto"` (in addition to existing 5 ids)

#### Scenario: Mage learns badi at level 3
- **WHEN** `mage.tres` is loaded
- **THEN** `spell_progression[3]` SHALL contain `&"badi"` alongside existing 3 ids

#### Scenario: Priest learns calfo at level 1
- **WHEN** `priest.tres` is loaded
- **THEN** `spell_progression[1]` SHALL contain exactly `&"heal"`, `&"holy"`, `&"calfo"`

#### Scenario: Bishop's level-2 list includes the three new ids
- **WHEN** `bishop.tres` is loaded
- **THEN** `spell_progression[2]` SHALL contain `&"dazil"`, `&"madalto"`, `&"calfo"` in addition to its existing 13 ids (total 16)

#### Scenario: Bishop's level-5 list includes badi
- **WHEN** `bishop.tres` is loaded
- **THEN** `spell_progression[5]` SHALL contain `&"badi"` (total 8 ids)

#### Scenario: Non-magic jobs still have empty spell_progression
- **WHEN** `fighter.tres`, `thief.tres`, or `ninja.tres` is loaded
- **THEN** `spell_progression` SHALL be `{}`

#### Scenario: Samurai progression unchanged
- **WHEN** `samurai.tres` is loaded
- **THEN** `spell_progression[4]` SHALL contain exactly `&"fire"` and `&"frost"`

#### Scenario: spell_progression ids reference real SpellData
- **WHEN** any job .tres with non-empty `spell_progression` is loaded
- **THEN** every spell id appearing in the progression's value arrays SHALL also appear in the SpellRepository at startup
