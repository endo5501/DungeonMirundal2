## ADDED Requirements

### Requirement: CombatActor exposes a StatModifierStack with β override semantics

The system SHALL provide each `CombatActor` with a `StatModifierStack` (RefCounted) instance, accessible as `modifier_stack`, that records active stat modifiers (stat key, signed delta, and remaining duration in turns). The stack SHALL recognize the stat keys `&"attack"`, `&"defense"`, `&"agility"`, `&"hit"`, `&"evasion"`. For `attack` / `defense` / `agility` the delta SHALL be `int`; for `hit` / `evasion` the delta SHALL be `float`.

When `add(stat, delta, duration)` is called and a modifier for the same stat already exists, the system SHALL apply the **β rule**:
- If `abs(new_delta) > abs(existing_delta)`, the existing entry SHALL be replaced (delta and duration both overwritten).
- If `abs(new_delta) == abs(existing_delta)`, the existing entry SHALL be kept but its duration SHALL be `max(existing_duration, new_duration)`.
- If `abs(new_delta) < abs(existing_delta)`, the existing entry SHALL be kept unchanged.

#### Scenario: Adding a stronger modifier overwrites both delta and duration
- **WHEN** `modifier_stack.add(&"attack", +2, 3)` is called and then `modifier_stack.add(&"attack", -3, 1)` is called
- **THEN** `modifier_stack.sum(&"attack")` SHALL return `-3` and the stored duration SHALL be `1`

#### Scenario: Adding a weaker modifier is a no-op
- **WHEN** `modifier_stack.add(&"attack", +2, 5)` is called and then `modifier_stack.add(&"attack", +1, 99)` is called
- **THEN** `modifier_stack.sum(&"attack")` SHALL return `+2` and the stored duration SHALL be `5`

#### Scenario: Adding an equal-magnitude modifier extends duration only
- **WHEN** `modifier_stack.add(&"attack", +2, 3)` is called and then `modifier_stack.add(&"attack", +2, 5)` is called
- **THEN** `modifier_stack.sum(&"attack")` SHALL return `+2` and the stored duration SHALL be `5`
- **WHEN** instead the second call is `modifier_stack.add(&"attack", -2, 5)`
- **THEN** `modifier_stack.sum(&"attack")` SHALL still return `+2` (sign of incoming equal-magnitude modifier is ignored when not stronger) and duration SHALL be `5`

#### Scenario: Adding to an empty slot adds a new entry
- **WHEN** `modifier_stack.add(&"hit", +0.1, 3)` is called on an empty stack
- **THEN** `modifier_stack.sum(&"hit")` SHALL return `+0.1`

### Requirement: StatModifierStack supports per-turn ticking and battle-only clearing

The system SHALL provide `tick_battle_turn()` which decrements every entry's duration by 1 and removes any entry whose duration reaches 0 or below. The system SHALL also provide `clear_battle_only()` which removes every entry whose scope is `BATTLE_ONLY` (the only scope used in this change).

#### Scenario: Tick decrements duration and removes expired entries
- **WHEN** a stack contains `{attack:+2, duration:1}` and `tick_battle_turn()` is called
- **THEN** the entry SHALL be removed and `sum(&"attack")` SHALL return `0`

#### Scenario: Tick keeps unexpired entries
- **WHEN** a stack contains `{attack:+2, duration:3}` and `tick_battle_turn()` is called
- **THEN** the entry SHALL remain with duration `2` and `sum(&"attack")` SHALL still return `+2`

#### Scenario: clear_battle_only removes all battle-scoped entries
- **WHEN** a stack contains entries `{attack:+2}` and `{evasion:+0.1}` (both BATTLE_ONLY) and `clear_battle_only()` is called
- **THEN** `sum(&"attack")` SHALL return `0` and `sum(&"evasion")` SHALL return `0.0`

## MODIFIED Requirements

### Requirement: PartyCombatant wraps a Character and writes back directly

The system SHALL provide a `PartyCombatant` (extends CombatActor) that holds a reference to a `Character` and an `EquipmentProvider`, and SHALL proxy HP and MP reads and writes through the wrapped Character so no write-back step is required after combat.

#### Scenario: HP changes propagate to Character
- **WHEN** `take_damage(5)` is called on a PartyCombatant wrapping a Character with `current_hp = 20`
- **THEN** the wrapped Character's `current_hp` SHALL become `15`

#### Scenario: MP changes propagate to Character
- **WHEN** `spend_mp(2)` is called on a PartyCombatant wrapping a Character with `current_mp = 5`
- **THEN** `spend_mp` SHALL return `true` and the wrapped Character's `current_mp` SHALL become `3`

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

The system SHALL provide a `MonsterCombatant` (extends CombatActor) that holds a reference to a `Monster` and SHALL source derived stats from the underlying `MonsterData`. In v1, monsters SHALL NOT cast spells; their MP fields SHALL be zero and `spend_mp` SHALL always return `false` for any positive amount.

#### Scenario: HP proxies to Monster instance
- **WHEN** `take_damage(3)` is called on a MonsterCombatant whose Monster has `current_hp = 10`
- **THEN** the wrapped Monster's `current_hp` SHALL become `7`

#### Scenario: Derived stats include MonsterData base plus modifier stack
- **WHEN** `get_attack()`, `get_defense()`, and `get_agility()` are called on a MonsterCombatant whose `MonsterData` declares `attack = 4`, `defense = 2`, `agility = 6` and whose `modifier_stack.sum(&"attack") = -1`
- **THEN** the returned values SHALL be `3`, `2`, and `6` respectively (each stat sums base and modifier)

#### Scenario: actor_name comes from MonsterData
- **WHEN** a MonsterCombatant wraps a Monster whose `MonsterData.monster_name` is `"スライム"`
- **THEN** `actor_name` SHALL equal `"スライム"`

#### Scenario: MonsterCombatant has zero MP in v1
- **WHEN** a MonsterCombatant is instantiated
- **THEN** `current_mp` and `max_mp` SHALL both be `0`

#### Scenario: MonsterCombatant.spend_mp rejects positive amounts
- **WHEN** `spend_mp(1)` is called on a MonsterCombatant
- **THEN** the call SHALL return `false`

## ADDED Requirements

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
