## MODIFIED Requirements

### Requirement: Resistance is the sum of race and job resists for players

The system SHALL compute resistance for a `PartyCombatant` as `race.resists.get(key, 0.0) + job.resists.get(key, 0.0)` for any given `resist_key`. The result SHALL NOT be clamped at this layer; negative resists (representing increased vulnerability) SHALL be preserved. The clamp `[0.0, 1.0]` SHALL be applied only at the inflict-chance computation site (i.e. `effective = clamp(chance - target_resist, 0.0, 1.0)`).

#### Scenario: Resist defaults to zero when neither race nor job declares it
- **WHEN** `get_resist(&"poison")` is called on a PartyCombatant whose race and job both have `resists == {}`
- **THEN** the result SHALL be `0.0`

#### Scenario: Negative resist surfaces increased vulnerability
- **WHEN** a Mage Elf has `race.resists = {silence: -0.10}` and `job.resists = {silence: -0.20}` and `get_resist(&"silence")` is called
- **THEN** the result SHALL be `-0.30` (no clamp at this layer)

#### Scenario: Positive resist sums normally
- **WHEN** a PartyCombatant has `race.resists = {poison: 0.20}` and `job.resists = {poison: 0.10}`
- **THEN** `get_resist(&"poison")` SHALL return `0.30`

#### Scenario: Effective inflict chance clamps at the spell site
- **WHEN** a spell with `chance = 0.5` targets an actor with `get_resist == -0.30` (vulnerable)
- **THEN** `effective = clamp(0.5 - (-0.30), 0.0, 1.0) = 0.80`

#### Scenario: Full resist guarantees failure
- **WHEN** a spell with `chance = 0.8` targets an actor with `get_resist == 1.0`
- **THEN** `effective = clamp(0.8 - 1.0, 0.0, 1.0) = 0.0`

### Requirement: Monster resistance comes from MonsterData

The system SHALL compute resistance for a `MonsterCombatant` as `monster_data.resists.get(key, 0.0)`. The result SHALL NOT be clamped at this layer; the clamp `[0.0, 1.0]` SHALL apply at the inflict-chance computation site.

#### Scenario: Monster resist from MonsterData
- **WHEN** a MonsterCombatant whose `MonsterData.resists = {&"sleep": 0.5}` is asked for `get_resist(&"sleep")`
- **THEN** the result SHALL be `0.5`

#### Scenario: Missing key returns zero
- **WHEN** `get_resist(&"poison")` is called and `MonsterData.resists` does not contain that key
- **THEN** the result SHALL be `0.0`

#### Scenario: Negative monster resist (rare) surfaces vulnerability
- **WHEN** a MonsterData has `resists = {&"holy": -0.20}` (a hypothetical undead vulnerable to holy)
- **THEN** `get_resist(&"holy")` SHALL return `-0.20` (no clamp at this layer)
