## ADDED Requirements

### Requirement: Sleep status data is shipped at data/statuses/sleep.tres

The system SHALL ship a `data/statuses/sleep.tres` resource of type `StatusData` with the following fields:
- `id = &"sleep"`
- `display_name = "睡眠"`
- `scope = StatusData.Scope.BATTLE_ONLY (0)`
- `prevents_action = true`
- `randomizes_target = false`
- `blocks_cast = false`
- `hit_penalty = 0.0`
- `default_duration = 3`
- `tick_in_battle = 0`
- `tick_in_dungeon = 0`
- `cures_on_damage = true`
- `cures_on_battle_end = true`
- `resist_key = &"sleep"`

#### Scenario: sleep.tres loads with the documented fields
- **WHEN** `DataLoader.new().load_status_repository().find(&"sleep")` is called
- **THEN** every field SHALL match the values listed above

### Requirement: Silence status data is shipped at data/statuses/silence.tres

The system SHALL ship a `data/statuses/silence.tres` resource of type `StatusData` with the following fields:
- `id = &"silence"`
- `display_name = "沈黙"`
- `scope = BATTLE_ONLY (0)`
- `prevents_action = false`
- `randomizes_target = false`
- `blocks_cast = true`
- `hit_penalty = 0.0`
- `default_duration = 4`
- `tick_in_battle = 0`
- `tick_in_dungeon = 0`
- `cures_on_damage = false`
- `cures_on_battle_end = true`
- `resist_key = &"silence"`

#### Scenario: silence.tres loads with the documented fields
- **WHEN** `find(&"silence")` is called on the StatusRepository
- **THEN** every field SHALL match the values listed above

### Requirement: Katino spell inflicts sleep on an enemy group

The system SHALL ship `data/spells/katino.tres` (`SpellData`) with:
- `id = &"katino"`, `display_name = "カティノ"`, `school = &"mage"`, `level = 1`, `mp_cost = 2`, `target_type = ENEMY_GROUP`, `scope = BATTLE_ONLY`
- `effect` is a `StatusInflictSpellEffect` sub-resource with `status_id = &"sleep"`, `chance = 0.6`, `duration = 3`

#### Scenario: katino is loaded as a SpellData
- **WHEN** the SpellRepository is loaded
- **THEN** `find(&"katino")` SHALL return a SpellData with the documented fields and a `StatusInflictSpellEffect` effect

#### Scenario: katino targets an enemy group at the resolution layer
- **WHEN** katino is cast at a slime group with 3 living slimes
- **THEN** every slime SHALL be subject to an independent inflict roll (per the StatusInflictSpellEffect spec)

### Requirement: Manifo spell inflicts silence on a single enemy

The system SHALL ship `data/spells/manifo.tres` (`SpellData`) with:
- `id = &"manifo"`, `display_name = "マニフォ"`, `school = &"mage"`, `level = 1`, `mp_cost = 2`, `target_type = ENEMY_ONE`, `scope = BATTLE_ONLY`
- `effect` is a `StatusInflictSpellEffect` with `status_id = &"silence"`, `chance = 0.55`, `duration = 4`

#### Scenario: manifo is loaded as a SpellData
- **WHEN** `find(&"manifo")` is called
- **THEN** the returned SpellData SHALL have the documented fields and effect

### Requirement: Dios spell cures sleep on a single ally

The system SHALL ship `data/spells/dios.tres` (`SpellData`) with:
- `id = &"dios"`, `display_name = "ディオス"`, `school = &"priest"`, `level = 1`, `mp_cost = 2`, `target_type = ALLY_ONE`, `scope = OUTSIDE_OK`
- `effect` is a `CureStatusSpellEffect` with `status_id = &"sleep"`

#### Scenario: dios is loaded as a SpellData
- **WHEN** `find(&"dios")` is called
- **THEN** the returned SpellData SHALL have the documented fields and a `CureStatusSpellEffect` effect

#### Scenario: dios works outside battle on a sleeping party member
- **WHEN** dios is cast on a sleeping ally via the ESC menu spell flow
- **THEN** the ally's `statuses.has(&"sleep")` SHALL become `false` (or, in the out-of-battle case where statuses live on Character.persistent_statuses, sleep is BATTLE_ONLY so this is a no-op outside battle in practice)
