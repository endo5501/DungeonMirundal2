## ADDED Requirements

### Requirement: Confusion status data is shipped at data/statuses/confusion.tres

The system SHALL ship `data/statuses/confusion.tres` (`StatusData`) with:
- `id = &"confusion"`, `display_name = "混乱"`, `scope = BATTLE_ONLY`
- `prevents_action = false`, `randomizes_target = true`, `blocks_cast = false`, `hit_penalty = 0.0`
- `default_duration = 3`
- `tick_in_battle = 0`, `tick_in_dungeon = 0`, `tick_in_dungeon_ratio = 0`
- `cures_on_damage = true`, `cures_on_battle_end = true`
- `resist_key = &"confusion"`

#### Scenario: confusion.tres loads with documented fields
- **WHEN** `find(&"confusion")` is called on the StatusRepository
- **THEN** every field SHALL match the values listed above

### Requirement: Blind status data is shipped at data/statuses/blind.tres

The system SHALL ship `data/statuses/blind.tres` (`StatusData`) with:
- `id = &"blind"`, `display_name = "暗闇"`, `scope = BATTLE_ONLY`
- `prevents_action = false`, `randomizes_target = false`, `blocks_cast = false`, `hit_penalty = 0.20`
- `default_duration = 4`
- tick fields all 0
- `cures_on_damage = false`, `cures_on_battle_end = true`
- `resist_key = &"blind"`

#### Scenario: blind.tres loads with documented fields
- **WHEN** `find(&"blind")` is called
- **THEN** every field SHALL match

#### Scenario: Blind attacker reduces hit chance via DamageCalculator
- **WHEN** an attacker holds `&"blind"` and `DamageCalculator.calculate(...)` runs
- **THEN** the computed `hit_chance` SHALL include `-0.20` from the blind hit_penalty (in addition to other terms), and the final hit_chance SHALL be clamped to `[0.05, 0.99]`

### Requirement: Paralysis status data is shipped at data/statuses/paralysis.tres

The system SHALL ship `data/statuses/paralysis.tres` (`StatusData`) with:
- `id = &"paralysis"`, `display_name = "麻痺"`, `scope = BATTLE_ONLY`
- `prevents_action = true`, `randomizes_target = false`, `blocks_cast = false`, `hit_penalty = 0.0`
- `default_duration = 2`
- tick fields all 0
- `cures_on_damage = false`, `cures_on_battle_end = true`
- `resist_key = &"paralysis"`

#### Scenario: paralysis.tres loads with documented fields
- **WHEN** `find(&"paralysis")` is called
- **THEN** every field SHALL match

### Requirement: Dazil spell inflicts blind on a single enemy

The system SHALL ship `data/spells/dazil.tres` (`SpellData`) with:
- `id = &"dazil"`, `display_name = "ダジール"`, `school = &"mage"`, `level = 1`, `mp_cost = 2`, `target_type = ENEMY_ONE`, `scope = BATTLE_ONLY`
- `effect`: `StatusInflictSpellEffect` with `status_id = &"blind"`, `chance = 0.55`, `duration = 4`

#### Scenario: dazil loads correctly
- **WHEN** `find(&"dazil")` is called
- **THEN** the SpellData SHALL match the documented fields

### Requirement: Madalto spell inflicts confusion on an enemy group

The system SHALL ship `data/spells/madalto.tres` (`SpellData`) with:
- `id = &"madalto"`, `display_name = "マダルト"`, `school = &"mage"`, `level = 2`, `mp_cost = 3`, `target_type = ENEMY_GROUP`, `scope = BATTLE_ONLY`
- `effect`: `StatusInflictSpellEffect` with `status_id = &"confusion"`, `chance = 0.5`, `duration = 3`

#### Scenario: madalto loads correctly
- **WHEN** `find(&"madalto")` is called
- **THEN** the SpellData SHALL match the documented fields

### Requirement: Badi spell inflicts paralysis on a single enemy

The system SHALL ship `data/spells/badi.tres` (`SpellData`) with:
- `id = &"badi"`, `display_name = "バディ"`, `school = &"mage"`, `level = 3`, `mp_cost = 5`, `target_type = ENEMY_ONE`, `scope = BATTLE_ONLY`
- `effect`: `StatusInflictSpellEffect` with `status_id = &"paralysis"`, `chance = 0.5`, `duration = 2`

#### Scenario: badi loads correctly
- **WHEN** `find(&"badi")` is called
- **THEN** the SpellData SHALL match

### Requirement: Calfo spell cures blind on a single ally

The system SHALL ship `data/spells/calfo.tres` (`SpellData`) with:
- `id = &"calfo"`, `display_name = "カルフォ"`, `school = &"priest"`, `level = 1`, `mp_cost = 2`, `target_type = ALLY_ONE`, `scope = OUTSIDE_OK`
- `effect`: `CureStatusSpellEffect` with `status_id = &"blind"`

#### Scenario: calfo loads correctly
- **WHEN** `find(&"calfo")` is called
- **THEN** the SpellData SHALL match
