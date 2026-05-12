## Purpose
戦闘に参加するアクター（プレイヤーキャラクター／モンスター）の状態モデルを定義する。HP・MP・状態異常・行動済みフラグなど、1 ターン内の進行管理に必要な情報を対象とする。
## Requirements
### Requirement: CombatActor provides a uniform combat-participant interface

The system SHALL provide a `CombatActor` (RefCounted) abstract type that exposes a unified interface for any battle participant (party member or monster), so that combat logic can treat both kinds identically. The interface SHALL include MP fields and a `spend_mp` method so that magic casting can be expressed at the abstract level.

#### Scenario: CombatActor exposes required fields and methods

- **WHEN** any concrete CombatActor subclass is instantiated
- **THEN** it SHALL expose `actor_name: String`, `current_hp: int`, `max_hp: int`, `current_mp: int`, `max_mp: int`, `get_attack() -> int`, `get_defense() -> int`, `get_agility() -> int`, `is_alive() -> bool`, `take_damage(amount: int)`, and `spend_mp(amount: int) -> bool`.

#### Scenario: is_alive reflects current_hp
- **WHEN** a CombatActor has `current_hp = 0`
- **THEN** `is_alive()` SHALL return `false`
- **WHEN** a CombatActor has `current_hp > 0`
- **THEN** `is_alive()` SHALL return `true`

#### Scenario: take_damage reduces current_hp and clamps at zero
- **WHEN** `take_damage(amount)` is called with `amount >= 0` on a CombatActor with `current_hp > 0`
- **THEN** `current_hp` SHALL decrease by exactly `amount` but SHALL NOT go below `0`

#### Scenario: spend_mp succeeds when sufficient MP exists
- **WHEN** `spend_mp(2)` is called on a CombatActor with `current_mp = 5`
- **THEN** the call SHALL return `true` and `current_mp` SHALL become `3`

#### Scenario: spend_mp fails when insufficient MP exists
- **WHEN** `spend_mp(3)` is called on a CombatActor with `current_mp = 2`
- **THEN** the call SHALL return `false` and `current_mp` SHALL remain `2`

#### Scenario: spend_mp with zero amount returns true and is a no-op
- **WHEN** `spend_mp(0)` is called on any CombatActor
- **THEN** the call SHALL return `true` and `current_mp` SHALL remain unchanged

### Requirement: CombatActor has per-turn defend state
The system SHALL allow a CombatActor to enter a defending posture for a single turn that halves incoming damage, and SHALL provide a hook to clear turn-scoped flags at turn boundaries.

#### Scenario: Defending halves incoming damage for the turn
- **WHEN** a CombatActor calls `apply_defend()` during command input, and subsequently takes damage of `amount` during resolution
- **THEN** the actual HP reduction SHALL be `amount / 2` (integer division, minimum 1 when `amount > 0`)

#### Scenario: Defend state resets at turn end
- **WHEN** `clear_turn_flags()` is called on a defending CombatActor after resolution
- **THEN** subsequent damage in later turns SHALL be taken at full value unless `apply_defend()` is called again

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

### Requirement: MonsterCombatant wraps a Monster and its MonsterData

The system SHALL provide a `MonsterCombatant` (extends CombatActor) that holds a reference to a `Monster` and SHALL source derived stats from the underlying `MonsterData`. Monsters MAY cast spells when the underlying `Monster` has `max_mp > 0` and `MonsterData.known_spells` is non-empty; their MP fields and `spend_mp` SHALL behave identically to other `CombatActor` subclasses.

#### Scenario: HP proxies to Monster instance
- **WHEN** `take_damage(3)` is called on a MonsterCombatant whose Monster has `current_hp = 10`
- **THEN** the wrapped Monster's `current_hp` SHALL become `7`

#### Scenario: Derived stats include MonsterData base plus modifier stack
- **WHEN** `get_attack()`, `get_defense()`, and `get_agility()` are called on a MonsterCombatant whose `MonsterData` declares `attack = 4`, `defense = 2`, `agility = 6` and whose `modifier_stack.sum(&"attack") = -1`
- **THEN** the returned values SHALL be `3`, `2`, and `6` respectively (each stat sums base and modifier)

#### Scenario: actor_name comes from MonsterData
- **WHEN** a MonsterCombatant wraps a Monster whose `MonsterData.monster_name` is `"スライム"`
- **THEN** `actor_name` SHALL equal `"スライム"`

#### Scenario: MonsterCombatant MP proxies to the wrapped Monster
- **WHEN** a `MonsterCombatant` wraps a `Monster` with rolled `max_mp = 8` and `current_mp = 8`
- **THEN** `max_mp` SHALL equal `8` AND `current_mp` SHALL equal `8`

#### Scenario: MonsterCombatant with zero-MP data still has zero MP
- **WHEN** a `MonsterCombatant` wraps a `Monster` whose `MonsterData` has `max_mp_min = 0` and `max_mp_max = 0`
- **THEN** `max_mp` SHALL equal `0` AND `current_mp` SHALL equal `0`

#### Scenario: MonsterCombatant.spend_mp follows the standard contract
- **WHEN** `spend_mp(2)` is called on a `MonsterCombatant` whose wrapped Monster has `current_mp = 5`
- **THEN** the call SHALL return `true` AND the wrapped Monster's `current_mp` SHALL become `3`

#### Scenario: MonsterCombatant.spend_mp rejects insufficient MP
- **WHEN** `spend_mp(3)` is called on a `MonsterCombatant` whose wrapped Monster has `current_mp = 2`
- **THEN** the call SHALL return `false` AND `current_mp` SHALL remain `2`

#### Scenario: MonsterCombatant.spend_mp with zero amount returns true and is a no-op
- **WHEN** `spend_mp(0)` is called on a `MonsterCombatant`
- **THEN** the call SHALL return `true` AND `current_mp` SHALL remain unchanged

#### Scenario: MP write propagates to the wrapped Monster
- **WHEN** `spend_mp(2)` is called on a `MonsterCombatant` whose Monster has `current_mp = 5`
- **THEN** the wrapped `Monster.current_mp` SHALL become `3` (the MonsterCombatant SHALL NOT cache MP independently of the Monster)

### Requirement: CombatActor exposes hit/evasion modifier totals and a blind hook

The system SHALL provide on every `CombatActor`:
- `get_hit_modifier_total() -> float`: returns `clamp(modifier_stack.sum(&"hit"), -MOD_CAP, +MOD_CAP)` where `MOD_CAP = 0.40`.
- `get_evasion_modifier_total() -> float`: returns `clamp(modifier_stack.sum(&"evasion"), -MOD_CAP, +MOD_CAP)`.
- `has_blind_flag() -> bool`: returns whether the actor is currently blinded. In this change, the default implementation SHALL return `false` for all subclasses (no caller sets the flag yet).

#### Scenario: hit modifier total clamps at +0.4
- **WHEN** an actor's `modifier_stack.sum(&"hit")` returns `+0.6`
- **THEN** `get_hit_modifier_total()` SHALL return `+0.4`

#### Scenario: hit modifier total clamps at -0.4
- **WHEN** an actor's `modifier_stack.sum(&"hit")` returns `-0.7`
- **THEN** `get_hit_modifier_total()` SHALL return `-0.4`

#### Scenario: evasion modifier total clamps at +0.4
- **WHEN** an actor's `modifier_stack.sum(&"evasion")` returns `+0.5`
- **THEN** `get_evasion_modifier_total()` SHALL return `+0.4`

#### Scenario: has_blind_flag default is false
- **WHEN** `has_blind_flag()` is called on any newly constructed CombatActor
- **THEN** the result SHALL be `false`

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

### Requirement: MonsterCombatant resolves resist from MonsterData

The system SHALL implement `MonsterCombatant.get_resist(resist_key) -> float` returning `clamp(monster_data.resists.get(resist_key, 0.0), 0.0, 1.0)`. Returns `0.0` when `resist_key == &""` or `monster_data` is null.

`MonsterCombatant` SHALL NOT commit persistent statuses to any persistent storage (monsters disappear at battle end).

#### Scenario: Monster resist from data
- **WHEN** a MonsterCombatant whose `MonsterData.resists = {&"sleep": 0.4}` is asked `get_resist(&"sleep")`
- **THEN** the result SHALL be `0.4`

#### Scenario: Missing resist key
- **WHEN** `get_resist(&"poison")` is called and `MonsterData.resists` lacks that key
- **THEN** the result SHALL be `0.0`

### Requirement: CombatActor emits stat_modifiers_changed when its modifier stack mutates

`CombatActor` SHALL define a signal `stat_modifiers_changed()` (zero arguments) and SHALL emit it whenever its `stat_modifier_stack` is mutated in a way that changes the visible modifier set: an entry is added, an entry's delta or duration is updated, or an entry is removed (including via duration tick reaching zero). Subscribers are expected to re-read `stat_modifier_stack` after the signal fires to obtain the current state.

#### Scenario: add() emits the signal

- **WHEN** `combat_actor.stat_modifier_stack.add(&"attack", 2, 3)` is called on a CombatActor whose stack did not previously contain that entry
- **THEN** `combat_actor.stat_modifiers_changed` SHALL fire exactly once

#### Scenario: add() that replaces an existing weaker entry emits the signal

- **WHEN** an existing entry `(&"attack", +1, duration 2)` is present and `add(&"attack", +3, 4)` is called (stronger, replaces)
- **THEN** `combat_actor.stat_modifiers_changed` SHALL fire exactly once

#### Scenario: add() that is a no-op (weaker than existing) does not emit

- **WHEN** an existing entry `(&"attack", +3, 4)` is present and `add(&"attack", +1, 2)` is called (weaker, no-op)
- **THEN** `combat_actor.stat_modifiers_changed` SHALL NOT fire

#### Scenario: Tick that removes an entry emits the signal

- **WHEN** an entry has `duration = 1` and the per-turn tick decrements it to `0` and removes it
- **THEN** `combat_actor.stat_modifiers_changed` SHALL fire exactly once for that removal

#### Scenario: Tick that decrements but keeps an entry does not emit

- **WHEN** an entry has `duration = 3` and the tick decrements it to `2` (still active)
- **THEN** `combat_actor.stat_modifiers_changed` SHALL NOT fire (no visible change beyond duration)

Note: emission for duration-only changes is intentionally omitted so HUD subscribers do not redraw on every turn for stable modifiers.

### Requirement: PartyCombatant carries an original_row from PartyData

The system SHALL extend `PartyCombatant` with `original_row: Row` (default `Row.FRONT`). When `CombatOverlay.start_encounter` constructs a `PartyCombatant` for each living party member, it SHALL pass the row in which that member sits within `PartyData` (FRONT or BACK).

The `original_row` SHALL NOT be mutated during a battle. Row promotion (BACK → effective FRONT) is computed dynamically by `TurnEngine`; the actor's `original_row` field stays fixed.

#### Scenario: PartyCombatant constructed from a FRONT-row character
- **WHEN** `CombatOverlay.start_encounter` wraps a Character that occupies a slot in `PartyData.front_row`
- **THEN** the resulting `PartyCombatant` SHALL have `original_row == Row.FRONT`

#### Scenario: PartyCombatant constructed from a BACK-row character
- **WHEN** `CombatOverlay.start_encounter` wraps a Character that occupies a slot in `PartyData.back_row`
- **THEN** the resulting `PartyCombatant` SHALL have `original_row == Row.BACK`

#### Scenario: original_row defaults to FRONT for legacy callers
- **WHEN** test code or legacy production code constructs a `PartyCombatant` without specifying a row
- **THEN** `original_row` SHALL default to `Row.FRONT`

### Requirement: MonsterCombatant exposes an original_row sourced from MonsterData

The system SHALL expose `MonsterCombatant.original_row: Row` whose value is sourced from `monster.data.default_row` (the implementation MAY store the row as a field initialized at construction OR derive it dynamically from the wrapped data; both are acceptable as long as the observed value matches `monster.data.default_row` while the data is reachable).

When the wrapped `monster` or `monster.data` is `null`, `original_row` SHALL fall back to `Row.FRONT` so engine code can rely on a non-null value.

`original_row` SHALL reflect the spawn-time value of `MonsterData.default_row` for the duration of a battle. (No code path mutates `MonsterData.default_row` during battle.)

#### Scenario: MonsterCombatant adopts MonsterData.default_row
- **WHEN** a `MonsterCombatant` is constructed wrapping a `Monster` whose `MonsterData.default_row == Row.BACK`
- **THEN** the resulting `MonsterCombatant.original_row` SHALL equal `Row.BACK`

#### Scenario: MonsterCombatant fallback is FRONT when data is missing
- **WHEN** a `MonsterCombatant` is constructed without a wrapped monster (or with a monster whose `data` is null)
- **THEN** `original_row` SHALL equal `Row.FRONT`

