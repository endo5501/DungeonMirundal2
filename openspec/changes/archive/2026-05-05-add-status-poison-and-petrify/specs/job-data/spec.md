## MODIFIED Requirements

### Requirement: JobData declares spell_progression for magic-capable jobs

`JobData` SHALL declare a `spell_progression: Dictionary` field whose keys are job-level integers (`int`, indicating "the level at which these spells are first granted"), and whose values are `Array[StringName]` of spell ids learned at that level. For jobs with neither magic school flag set, `spell_progression` SHALL be empty (`{}`).

The progression after this change SHALL be:

| Job | spell_progression |
|---|---|
| fighter | {} |
| thief | {} |
| ninja | {} |
| mage | { 1: [&"fire", &"frost"], 2: [&"katino", &"manifo"], 3: [&"flame", &"blizzard", &"poison_dart"] } |
| priest | { 1: [&"heal", &"holy"], 2: [&"dios"], 3: [&"heala", &"allheal", &"madi"], 5: [&"dialma"] } |
| bishop | { 2: [&"fire", &"frost", &"heal", &"holy", &"katino", &"manifo", &"dios"], 5: [&"flame", &"blizzard", &"heala", &"allheal", &"poison_dart", &"madi"] } |
| samurai | { 4: [&"fire", &"frost"], 8: [&"flame", &"blizzard"] } |
| lord | { 4: [&"heal", &"holy"], 8: [&"heala", &"allheal"] } |

Spell ids in `spell_progression` SHALL match a real `SpellData.id` from `data/spells/`.

#### Scenario: Non-magic jobs have empty spell_progression
- **WHEN** `fighter.tres`, `thief.tres`, or `ninja.tres` is loaded
- **THEN** `spell_progression` SHALL be `{}`

#### Scenario: Mage learns level-1 spells at level 1
- **WHEN** `mage.tres` is loaded
- **THEN** `spell_progression[1]` SHALL contain `&"fire"` and `&"frost"`

#### Scenario: Mage learns katino and manifo at level 2
- **WHEN** `mage.tres` is loaded
- **THEN** `spell_progression[2]` SHALL contain exactly `&"katino"` and `&"manifo"`

#### Scenario: Mage learns poison_dart at level 3 alongside flame and blizzard
- **WHEN** `mage.tres` is loaded
- **THEN** `spell_progression[3]` SHALL contain exactly `&"flame"`, `&"blizzard"`, `&"poison_dart"`

#### Scenario: Priest learns dios at level 2
- **WHEN** `priest.tres` is loaded
- **THEN** `spell_progression[2]` SHALL contain exactly `&"dios"`

#### Scenario: Priest learns madi at level 3 alongside heala and allheal
- **WHEN** `priest.tres` is loaded
- **THEN** `spell_progression[3]` SHALL contain exactly `&"heala"`, `&"allheal"`, `&"madi"`

#### Scenario: Priest learns dialma at level 5
- **WHEN** `priest.tres` is loaded
- **THEN** `spell_progression[5]` SHALL contain exactly `&"dialma"`

#### Scenario: Bishop learns at levels 2 and 5
- **WHEN** `bishop.tres` is loaded
- **THEN** `spell_progression` SHALL have keys exactly `{2, 5}`, with `2` containing the seven spell-level-1 ids `&"fire"`, `&"frost"`, `&"heal"`, `&"holy"`, `&"katino"`, `&"manifo"`, `&"dios"` and `5` containing the six ids `&"flame"`, `&"blizzard"`, `&"heala"`, `&"allheal"`, `&"poison_dart"`, `&"madi"`

#### Scenario: Bishop does not learn dialma
- **WHEN** `bishop.tres` is loaded
- **THEN** `spell_progression[5]` SHALL NOT contain `&"dialma"` (Priest only)

#### Scenario: Samurai learns mage spells starting at level 4
- **WHEN** `samurai.tres` is loaded
- **THEN** `spell_progression` SHALL have a key `4` containing `&"fire"` and `&"frost"`, and a key `8` containing `&"flame"` and `&"blizzard"`

#### Scenario: Lord learns priest spells starting at level 4
- **WHEN** `lord.tres` is loaded
- **THEN** `spell_progression` SHALL have a key `4` containing `&"heal"` and `&"holy"`, and a key `8` containing `&"heala"` and `&"allheal"`

#### Scenario: spell_progression ids reference real SpellData
- **WHEN** any job .tres with non-empty `spell_progression` is loaded
- **THEN** every spell id appearing in the progression's value arrays SHALL also appear in the SpellRepository at startup
