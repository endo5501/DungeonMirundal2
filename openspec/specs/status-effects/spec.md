# status-effects Specification

## Purpose
TBD - created by archiving change add-status-effect-infrastructure. Update Purpose after archive.
## Requirements
### Requirement: StatusData defines a status effect template

The system SHALL provide a `StatusData` Custom Resource that defines a status effect template. `StatusData` SHALL expose the following fields:

- `id: StringName` — unique identifier matching the `.tres` filename basename.
- `display_name: String` — Japanese display name shown in UI.
- `scope: int` — `StatusData.Scope`: `BATTLE_ONLY (0)` or `PERSISTENT (1)`.
- `prevents_action: bool`
- `randomizes_target: bool`
- `blocks_cast: bool`
- `hit_penalty: float`
- `default_duration: int` — turns granted at inflict for `BATTLE_ONLY`.
- `tick_in_battle: int` — flat HP damage at the head of each battle turn. `0` means no battle tick.
- `tick_in_dungeon: int` — flat HP damage applied each time `StatusTickService.tick_character_step` is invoked (used when `tick_in_dungeon_ratio == 0`). Only meaningful for `PERSISTENT`. Note: the dungeon coordinator gates how often `tick_character_step` is called per step (see `dungeon-movement` spec).
- `tick_in_dungeon_ratio: int` — when `> 0`, dungeon step damage SHALL equal `maxi(1, character.max_hp / tick_in_dungeon_ratio)` (integer division, minimum 1). When `> 0`, this value takes precedence over `tick_in_dungeon`.
- `cures_on_damage: bool`
- `cures_on_battle_end: bool`
- `resist_key: StringName`

#### Scenario: StatusData carries required fields including dungeon_ratio
- **WHEN** a StatusData resource is created
- **THEN** it SHALL expose all listed fields including `tick_in_dungeon_ratio`

#### Scenario: id matches filename
- **WHEN** `data/statuses/poison.tres` is loaded
- **THEN** the loaded StatusData's `id` SHALL equal `&"poison"`

#### Scenario: scope is one of the recognized values
- **WHEN** any StatusData file is loaded
- **THEN** `scope` SHALL be either `0 (BATTLE_ONLY)` or `1 (PERSISTENT)`

#### Scenario: Both tick fields default to zero
- **WHEN** a StatusData is created without overriding tick fields
- **THEN** `tick_in_battle == 0`, `tick_in_dungeon == 0`, `tick_in_dungeon_ratio == 0` (no tick at all)

### Requirement: StatusRepository provides StatusData lookup by id

The system SHALL provide a `StatusRepository` that loads all `data/statuses/*.tres` resources at startup and exposes `find(status_id: StringName) -> StatusData` and `has_id(status_id: StringName) -> bool`. The system SHALL provide `DataLoader.load_status_repository() -> StatusRepository` that lazily constructs and caches a single repository instance.

#### Scenario: Lookup existing status
- **WHEN** `find(&"poison")` is called on a repository that loaded `data/statuses/poison.tres`
- **THEN** the returned StatusData SHALL have `id == &"poison"`

#### Scenario: Lookup missing status returns null
- **WHEN** `find(&"nonexistent")` is called
- **THEN** the returned value SHALL be `null`

#### Scenario: DataLoader caches the repository instance
- **WHEN** `DataLoader.new().load_status_repository()` is called twice in the same session
- **THEN** the same StatusRepository instance SHALL be returned both times (subsequent calls SHALL NOT rescan disk)

### Requirement: StatusTrack records active statuses keyed by id

The system SHALL provide a `StatusTrack` (RefCounted) that holds at most one entry per status id. Each entry stores a remaining duration: a positive integer for BATTLE_ONLY statuses, or the sentinel `StatusTrack.PERSISTENT_DURATION = -1` for PERSISTENT statuses.

`StatusTrack` SHALL expose:
- `apply(status_id: StringName, duration: int) -> void`
- `has(status_id: StringName) -> bool`
- `cure(status_id: StringName) -> bool`
- `cure_all_battle_only(repo: StatusRepository) -> Array[StringName]` — removes every entry whose StatusData has `scope == BATTLE_ONLY` and returns the cured ids.
- `tick_battle_turn(actor, repo) -> Array` — applies battle tick damage to `actor`, decrements BATTLE_ONLY durations, removes expired entries, and returns an array of `{status_id, hp_loss, killed_by_tick}` dictionaries.
- `handle_damage_taken(actor, repo) -> Array[StringName]` — removes every entry whose StatusData has `cures_on_damage == true` and returns the cured ids.
- `active_ids() -> Array[StringName]`

#### Scenario: apply on an empty slot adds a new entry
- **WHEN** `apply(&"sleep", 3)` is called on an empty StatusTrack
- **THEN** `has(&"sleep")` SHALL return `true`

#### Scenario: apply on existing entry takes max duration
- **WHEN** `apply(&"sleep", 3)` is followed by `apply(&"sleep", 1)`
- **THEN** the stored duration SHALL be `3` (the existing duration is kept since it is larger)

#### Scenario: apply on existing entry uses larger duration
- **WHEN** `apply(&"sleep", 1)` is followed by `apply(&"sleep", 5)`
- **THEN** the stored duration SHALL be `5`

#### Scenario: apply preserves PERSISTENT against override
- **WHEN** `apply(&"poison", PERSISTENT_DURATION)` is followed by `apply(&"poison", 3)`
- **THEN** the stored duration SHALL remain `PERSISTENT_DURATION`

#### Scenario: cure removes an entry and returns true on success
- **WHEN** `apply(&"sleep", 3)` is followed by `cure(&"sleep")`
- **THEN** `cure` SHALL return `true` and `has(&"sleep")` SHALL return `false`

#### Scenario: cure on missing entry returns false
- **WHEN** `cure(&"sleep")` is called on an empty StatusTrack
- **THEN** the call SHALL return `false`

### Requirement: StatusTrack.tick_battle_turn applies damage and decrements durations

The system SHALL, on `tick_battle_turn(actor, repo)`:
1. For each active entry whose StatusData has `tick_in_battle > 0`, call `actor.take_damage(tick_in_battle)` (only if `actor.is_alive()` at the moment of the call), and record `{status_id, hp_loss, killed_by_tick}`.
2. Decrement the duration of every BATTLE_ONLY entry (those with `duration != PERSISTENT_DURATION`) by 1.
3. Remove any entry whose new duration is `<= 0`.
4. Return the array of tick reports.

#### Scenario: Tick applies battle damage and reports it
- **WHEN** an actor with `current_hp = 10` holds a status whose `tick_in_battle = 2` and `tick_battle_turn` is called
- **THEN** the actor's `current_hp` SHALL become `8` and the returned array SHALL contain one entry `{status_id, hp_loss == 2, killed_by_tick == false}`

#### Scenario: Tick can kill the actor
- **WHEN** an actor with `current_hp = 1` holds a status whose `tick_in_battle = 2` and `tick_battle_turn` is called
- **THEN** the actor's `current_hp` SHALL become `0`, `is_alive()` SHALL be `false`, and the returned tick entry SHALL have `killed_by_tick == true`

#### Scenario: Tick decrements duration
- **WHEN** an actor holds a BATTLE_ONLY status with `duration = 2` and `tick_battle_turn` is called once
- **THEN** the entry SHALL remain with duration `1`
- **WHEN** `tick_battle_turn` is called a second time
- **THEN** the entry SHALL be removed

#### Scenario: PERSISTENT entries do not have their duration decremented
- **WHEN** a PERSISTENT entry with sentinel duration `-1` is present and `tick_battle_turn` is called many times
- **THEN** the entry SHALL remain present indefinitely until `cure` is called

### Requirement: StatusTickService applies dungeon ticks to a Character with HP floor

The system SHALL provide a static helper `StatusTickService.tick_character_step(character: Character, repo: StatusRepository) -> Dictionary` that:

1. Returns immediately if `character.is_dead()`.
2. Iterates `character.persistent_statuses`, looks up each in `repo`.
3. For each StatusData with `scope == PERSISTENT`, computes the requested damage:
   - If `tick_in_dungeon_ratio > 0`, `requested = maxi(1, character.max_hp / tick_in_dungeon_ratio)`.
   - Else if `tick_in_dungeon > 0`, `requested = tick_in_dungeon`.
   - Else: skip this status (no tick).
4. Applies `loss = mini(requested, max(0, character.current_hp - 1))` and decrements `current_hp` by that amount.
5. The character's HP SHALL NOT drop below `1` due to dungeon ticks.
6. Returns `{ "total_loss": int, "ticks": [{ "status_id": StringName, "amount": int }] }`.

#### Scenario: Ratio-based dungeon tick
- **WHEN** a character with `current_hp = 32`, `max_hp = 32` holds a PERSISTENT status with `tick_in_dungeon_ratio = 16` (and `tick_in_dungeon = 0`)
- **THEN** `tick_character_step` SHALL apply `loss = 32 / 16 = 2`, `current_hp` SHALL become `30`, and the result SHALL include the tick of amount 2

#### Scenario: Ratio with low max_hp floors at 1
- **WHEN** `max_hp = 10`, `current_hp = 10`, status `tick_in_dungeon_ratio = 16`
- **THEN** `requested = maxi(1, 10 / 16) = maxi(1, 0) = 1`, the loss SHALL be 1

#### Scenario: Ratio takes precedence over flat amount
- **WHEN** a status has both `tick_in_dungeon = 5` and `tick_in_dungeon_ratio = 16`, applied to a character with `max_hp = 32, current_hp = 32`
- **THEN** the loss SHALL be `2` (ratio wins) not `5`

#### Scenario: Both tick fields zero is a no-op
- **WHEN** a status has `tick_in_dungeon = 0` and `tick_in_dungeon_ratio = 0`
- **THEN** `tick_character_step` SHALL produce no entry for that status

#### Scenario: Dungeon tick floors at HP=1 when tick would kill
- **WHEN** a character with `current_hp = 2, max_hp = 32` holds poison with `tick_in_dungeon_ratio = 16` (requested loss 2)
- **THEN** the loss SHALL be capped at `1` (HP floor) and `current_hp` SHALL become `1`

#### Scenario: Dead character is skipped
- **WHEN** a character with `is_dead() == true` is passed to `tick_character_step`
- **THEN** no HP change SHALL occur and the result SHALL contain `total_loss == 0` with empty `ticks`

#### Scenario: BATTLE_ONLY statuses are ignored in dungeon ticks
- **WHEN** a character has `&"sleep"` (BATTLE_ONLY) listed in `persistent_statuses` somehow
- **THEN** `tick_character_step` SHALL ignore it (no damage applied)

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

### Requirement: Inflict chance subtracts target resist and clamps at zero

The system SHALL compute the effective inflict chance for a status spell as `effective = clamp(base_chance - target.get_resist(status_data.resist_key), 0.0, 1.0)`. The roll SHALL succeed when `spell_rng.roll(0, 99) < effective * 100`.

#### Scenario: Resistance reduces chance
- **WHEN** a spell with `chance = 0.6` targets an actor with `get_resist == 0.2`
- **THEN** the effective chance SHALL be `0.4`

#### Scenario: Full resistance produces guaranteed failure
- **WHEN** a spell with `chance = 0.8` targets an actor with `get_resist == 1.0`
- **THEN** the effective chance SHALL be `0.0` and the inflict roll SHALL never succeed

