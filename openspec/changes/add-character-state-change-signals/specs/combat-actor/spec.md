## MODIFIED Requirements

### Requirement: PartyCombatant wraps a Character and writes back directly

The system SHALL provide a `PartyCombatant` (extends CombatActor) that holds a reference to a `Character` and an `EquipmentProvider`, and SHALL proxy HP and MP reads and writes through the wrapped Character so no write-back step is required after combat. All HP and MP writes performed by `PartyCombatant` SHALL go through the Character's setter so that Character's `hp_changed` / `mp_changed` signals fire on real value changes.

#### Scenario: HP changes propagate to Character

- **WHEN** `take_damage(5)` is called on a PartyCombatant wrapping a Character with `current_hp = 20`
- **THEN** the wrapped Character's `current_hp` SHALL become `15`

#### Scenario: HP write triggers hp_changed signal

- **WHEN** `take_damage(5)` is called on a PartyCombatant wrapping a Character with `current_hp = 20` and a connected listener on `hp_changed`
- **THEN** the listener SHALL be invoked exactly once with arguments `(15, max_hp)`

#### Scenario: MP changes propagate to Character

- **WHEN** `spend_mp(2)` is called on a PartyCombatant wrapping a Character with `current_mp = 5`
- **THEN** `spend_mp` SHALL return `true` and the wrapped Character's `current_mp` SHALL become `3`

#### Scenario: MP write triggers mp_changed signal

- **WHEN** `spend_mp(2)` is called on a PartyCombatant wrapping a Character with `current_mp = 5` and a connected listener on `mp_changed`
- **THEN** the listener SHALL be invoked exactly once with arguments `(3, max_mp)`

#### Scenario: PartyCombatant max_mp comes from Character

- **WHEN** a PartyCombatant wraps a Character with `max_mp = 8`
- **THEN** the PartyCombatant's `max_mp` SHALL equal `8`

#### Scenario: Derived stats include EquipmentProvider base plus modifier stack

- **WHEN** `get_attack()` is called on a PartyCombatant whose `equipment_provider.get_attack(character)` returns `7` and whose `modifier_stack.sum(&"attack")` returns `+2`
- **THEN** the returned value SHALL be `9`
- **WHEN** `get_defense()` / `get_agility()` are called
- **THEN** each SHALL return `equipment_provider.get_<stat>(character) + modifier_stack.sum(&"<stat>")` (integer arithmetic)

#### Scenario: actor_name comes from Character

- **WHEN** a PartyCombatant wraps a Character with `character_name = "Fighter"`
- **THEN** `actor_name` SHALL equal `"Fighter"`

### Requirement: PartyCombatant resolves resist from race + job and commits persistent statuses

The system SHALL implement on `PartyCombatant`:
- `get_resist(resist_key: StringName) -> float`: returns `clamp(race.resists.get(key, 0.0) + job.resists.get(key, 0.0), 0.0, 1.0)`. Returns `0.0` when `resist_key == &""` or either resource is null.
- `commit_persistent_to_character(repo: StatusRepository) -> void`: updates `character.persistent_statuses` to contain exactly the status ids whose StatusData has `scope == PERSISTENT` and which are currently active in `statuses`. The assignment SHALL go through Character's setter so that `statuses_changed` fires when the resulting array differs from the previous value.

The constructor SHALL seed `statuses` from `character.persistent_statuses` by calling `statuses.apply(sid, StatusTrack.PERSISTENT_DURATION)` for each id, before the actor enters battle.

#### Scenario: get_resist returns 0 for empty key
- **WHEN** `get_resist(&"")` is called
- **THEN** the result SHALL be `0.0`

#### Scenario: get_resist sums race and job resists
- **WHEN** a PartyCombatant has `race.resists = {&"poison": 0.2}` and `job.resists = {&"poison": 0.1}` and `get_resist(&"poison")` is called
- **THEN** the result SHALL be `0.3`

#### Scenario: get_resist clamps at 1.0
- **WHEN** the sum of race and job resists for a key exceeds 1.0
- **THEN** the returned value SHALL be `1.0`

#### Scenario: persistent statuses seed at construction
- **WHEN** a PartyCombatant is constructed wrapping a Character whose `persistent_statuses == [&"poison"]`
- **THEN** the new combatant's `statuses.has(&"poison")` SHALL be `true` with persistent duration

#### Scenario: commit_persistent_to_character writes back persistent ids only
- **WHEN** a PartyCombatant has `statuses` containing `&"poison"` (PERSISTENT) and `&"sleep"` (BATTLE_ONLY) and `commit_persistent_to_character(repo)` is called
- **THEN** the wrapped `character.persistent_statuses` SHALL equal `[&"poison"]` (BATTLE_ONLY entries are not committed)

#### Scenario: commit_persistent_to_character emits statuses_changed when content differs

- **WHEN** a PartyCombatant whose wrapped Character has `persistent_statuses = []` calls `commit_persistent_to_character(repo)` and the resulting array is `[&"poison"]`, with a listener connected on `statuses_changed`
- **THEN** the listener SHALL be invoked exactly once with `[&"poison"]`

#### Scenario: commit_persistent_to_character does not emit when content unchanged

- **WHEN** a PartyCombatant whose wrapped Character has `persistent_statuses = [&"poison"]` calls `commit_persistent_to_character(repo)` and the resulting array is also `[&"poison"]`, with a listener connected on `statuses_changed`
- **THEN** the listener SHALL NOT be invoked
