## ADDED Requirements

### Requirement: CombatActor exposes a StatusTrack and status flag queries

The system SHALL provide on every `CombatActor`:
- `statuses: StatusTrack` — initialized to a new `StatusTrack` per CombatActor instance.
- `has_silence_flag() -> bool` — returns whether any active status has `blocks_cast == true` (looked up via `DataLoader.new().load_status_repository()`).
- `has_confusion_flag() -> bool` — returns whether any active status has `randomizes_target == true`.
- `has_action_lock() -> bool` — returns whether any active status has `prevents_action == true`.
- `get_resist(resist_key: StringName) -> float` — default returns `0.0`; subclasses override.

The system SHALL override `has_blind_flag()` (introduced in `add-stat-modifier-and-hit-evasion`) to return `statuses.has(&"blind")`. In this change, no concrete blind status is shipped, so the flag SHALL still effectively be `false` unless test code seeds the StatusTrack manually.

#### Scenario: statuses is initialized per actor
- **WHEN** a new CombatActor subclass instance is constructed
- **THEN** `statuses.active_ids().is_empty()` SHALL be `true`

#### Scenario: has_silence_flag is true when a blocks_cast status is active
- **WHEN** an actor's StatusTrack has an entry whose StatusData has `blocks_cast == true`
- **THEN** `has_silence_flag()` SHALL return `true`

#### Scenario: has_confusion_flag is true when a randomizes_target status is active
- **WHEN** an actor's StatusTrack has an entry whose StatusData has `randomizes_target == true`
- **THEN** `has_confusion_flag()` SHALL return `true`

#### Scenario: has_action_lock is true when a prevents_action status is active
- **WHEN** an actor's StatusTrack has an entry whose StatusData has `prevents_action == true`
- **THEN** `has_action_lock()` SHALL return `true`

#### Scenario: has_blind_flag now consults StatusTrack
- **WHEN** `statuses.apply(&"blind", 3)` is executed and a corresponding StatusData with `id == &"blind"` is loaded in the repository
- **THEN** `has_blind_flag()` SHALL return `true`
- **WHEN** the entry is later cured
- **THEN** `has_blind_flag()` SHALL return `false`

### Requirement: PartyCombatant resolves resist from race + job and commits persistent statuses

The system SHALL implement on `PartyCombatant`:
- `get_resist(resist_key: StringName) -> float`: returns `clamp(race.resists.get(key, 0.0) + job.resists.get(key, 0.0), 0.0, 1.0)`. Returns `0.0` when `resist_key == &""` or either resource is null.
- `commit_persistent_to_character(repo: StatusRepository) -> void`: updates `character.persistent_statuses` to contain exactly the status ids whose StatusData has `scope == PERSISTENT` and which are currently active in `statuses`.

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

### Requirement: MonsterCombatant resolves resist from MonsterData

The system SHALL implement `MonsterCombatant.get_resist(resist_key) -> float` returning `clamp(monster_data.resists.get(resist_key, 0.0), 0.0, 1.0)`. Returns `0.0` when `resist_key == &""` or `monster_data` is null.

`MonsterCombatant` SHALL NOT commit persistent statuses to any persistent storage (monsters disappear at battle end).

#### Scenario: Monster resist from data
- **WHEN** a MonsterCombatant whose `MonsterData.resists = {&"sleep": 0.4}` is asked `get_resist(&"sleep")`
- **THEN** the result SHALL be `0.4`

#### Scenario: Missing resist key
- **WHEN** `get_resist(&"poison")` is called and `MonsterData.resists` lacks that key
- **THEN** the result SHALL be `0.0`
