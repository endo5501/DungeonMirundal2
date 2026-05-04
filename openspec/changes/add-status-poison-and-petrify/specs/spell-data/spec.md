## ADDED Requirements

### Requirement: Poison status data is shipped at data/statuses/poison.tres

The system SHALL ship `data/statuses/poison.tres` (`StatusData`) with:
- `id = &"poison"`, `display_name = "毒"`, `scope = PERSISTENT (1)`
- `prevents_action = false`, `randomizes_target = false`, `blocks_cast = false`, `hit_penalty = 0.0`
- `default_duration = 0` (ignored for PERSISTENT)
- `tick_in_battle = 1`
- `tick_in_dungeon = 0`, `tick_in_dungeon_ratio = 16`
- `cures_on_damage = false`, `cures_on_battle_end = false`
- `resist_key = &"poison"`

#### Scenario: poison.tres loads with documented fields
- **WHEN** `find(&"poison")` is called on the StatusRepository
- **THEN** every field SHALL match the values listed above

### Requirement: Petrify status data is shipped at data/statuses/petrify.tres

The system SHALL ship `data/statuses/petrify.tres` (`StatusData`) with:
- `id = &"petrify"`, `display_name = "石化"`, `scope = PERSISTENT (1)`
- `prevents_action = true`, `randomizes_target = false`, `blocks_cast = false`, `hit_penalty = 0.0`
- `default_duration = 0`
- `tick_in_battle = 0`, `tick_in_dungeon = 0`, `tick_in_dungeon_ratio = 0`
- `cures_on_damage = false`, `cures_on_battle_end = false`
- `resist_key = &"petrify"`

#### Scenario: petrify.tres loads with documented fields
- **WHEN** `find(&"petrify")` is called on the StatusRepository
- **THEN** every field SHALL match the values listed above

### Requirement: Poison Dart spell deals damage and inflicts poison

The system SHALL ship `data/spells/poison_dart.tres` (`SpellData`) with:
- `id = &"poison_dart"`, `display_name = "ポイズン・ダート"`, `school = &"mage"`, `level = 1`, `mp_cost = 3`, `target_type = ENEMY_ONE`, `scope = BATTLE_ONLY`
- `effect`: `DamageWithStatusSpellEffect` with `base_damage = 3`, `spread = 1`, `status_id = &"poison"`, `inflict_chance = 0.6`, `status_duration = 0`

#### Scenario: poison_dart loads correctly
- **WHEN** `find(&"poison_dart")` is called
- **THEN** the SpellData SHALL match the documented fields and `effect` SHALL be a `DamageWithStatusSpellEffect`

#### Scenario: poison inflicted by poison_dart is PERSISTENT
- **WHEN** poison_dart hits a target and the inflict roll succeeds
- **THEN** the target's StatusTrack entry for `&"poison"` SHALL have duration `StatusTrack.PERSISTENT_DURATION` (regardless of `status_duration` field value)

### Requirement: Madi spell cures poison

The system SHALL ship `data/spells/madi.tres` (`SpellData`) with:
- `id = &"madi"`, `display_name = "マディ"`, `school = &"priest"`, `level = 2`, `mp_cost = 4`, `target_type = ALLY_ONE`, `scope = OUTSIDE_OK`
- `effect`: `CureStatusSpellEffect` with `status_id = &"poison"`

#### Scenario: madi loads correctly
- **WHEN** `find(&"madi")` is called
- **THEN** the SpellData SHALL match the documented fields

### Requirement: Dialma spell cures petrify

The system SHALL ship `data/spells/dialma.tres` (`SpellData`) with:
- `id = &"dialma"`, `display_name = "ディアルマ"`, `school = &"priest"`, `level = 3`, `mp_cost = 6`, `target_type = ALLY_ONE`, `scope = OUTSIDE_OK`
- `effect`: `CureStatusSpellEffect` with `status_id = &"petrify"`

#### Scenario: dialma loads correctly
- **WHEN** `find(&"dialma")` is called
- **THEN** the SpellData SHALL match the documented fields and `level == 3`
