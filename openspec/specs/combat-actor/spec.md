## Purpose
戦闘に参加するアクター（プレイヤーキャラクター／モンスター）の状態モデルを定義する。HP・MP・状態異常・行動済みフラグなど、1 ターン内の進行管理に必要な情報を対象とする。

## Requirements

### Requirement: CombatActor provides a uniform combat-participant interface
The system SHALL provide a `CombatActor` (RefCounted) abstract type that exposes a unified interface for any battle participant (party member or monster), so that combat logic can treat both kinds identically.

#### Scenario: CombatActor exposes required fields and methods
- **WHEN** any concrete CombatActor subclass is instantiated
- **THEN** it SHALL expose `actor_name: String`, `current_hp: int`, `max_hp: int`, `get_attack() -> int`, `get_defense() -> int`, `get_agility() -> int`, `is_alive() -> bool`, and `take_damage(amount: int)`.

#### Scenario: is_alive reflects current_hp
- **WHEN** a CombatActor has `current_hp = 0`
- **THEN** `is_alive()` SHALL return `false`
- **WHEN** a CombatActor has `current_hp > 0`
- **THEN** `is_alive()` SHALL return `true`

#### Scenario: take_damage reduces current_hp and clamps at zero
- **WHEN** `take_damage(amount)` is called with `amount >= 0` on a CombatActor with `current_hp > 0`
- **THEN** `current_hp` SHALL decrease by exactly `amount` but SHALL NOT go below `0`

### Requirement: CombatActor has per-turn defend state
The system SHALL allow a CombatActor to enter a defending posture for a single turn that halves incoming damage, and SHALL provide a hook to clear turn-scoped flags at turn boundaries.

#### Scenario: Defending halves incoming damage for the turn
- **WHEN** a CombatActor calls `apply_defend()` during command input, and subsequently takes damage of `amount` during resolution
- **THEN** the actual HP reduction SHALL be `amount / 2` (integer division, minimum 1 when `amount > 0`)

#### Scenario: Defend state resets at turn end
- **WHEN** `clear_turn_flags()` is called on a defending CombatActor after resolution
- **THEN** subsequent damage in later turns SHALL be taken at full value unless `apply_defend()` is called again

### Requirement: PartyCombatant wraps a Character and writes back directly
The system SHALL provide a `PartyCombatant` (extends CombatActor) that holds a reference to a `Character` and an `EquipmentProvider`, and SHALL proxy HP reads and writes through the wrapped Character so no write-back step is required after combat.

#### Scenario: HP changes propagate to Character
- **WHEN** `take_damage(5)` is called on a PartyCombatant wrapping a Character with `current_hp = 20`
- **THEN** the wrapped Character's `current_hp` SHALL become `15`

#### Scenario: Derived stats come from EquipmentProvider
- **WHEN** `get_attack()` is called on a PartyCombatant
- **THEN** the returned value SHALL equal `equipment_provider.get_attack(character)`
- **WHEN** `get_defense()` / `get_agility()` are called
- **THEN** the returned values SHALL equal the corresponding `equipment_provider` lookups

#### Scenario: actor_name comes from Character
- **WHEN** a PartyCombatant wraps a Character with `character_name = "Fighter"`
- **THEN** `actor_name` SHALL equal `"Fighter"`

### Requirement: MonsterCombatant wraps a Monster and its MonsterData
The system SHALL provide a `MonsterCombatant` (extends CombatActor) that holds a reference to a `Monster` and SHALL source derived stats from the underlying `MonsterData`.

#### Scenario: HP proxies to Monster instance
- **WHEN** `take_damage(3)` is called on a MonsterCombatant whose Monster has `current_hp = 10`
- **THEN** the wrapped Monster's `current_hp` SHALL become `7`

#### Scenario: Derived stats come from MonsterData
- **WHEN** `get_attack()`, `get_defense()`, and `get_agility()` are called on a MonsterCombatant whose `MonsterData` declares `attack = 4`, `defense = 2`, `agility = 6`
- **THEN** the returned values SHALL be `4`, `2`, and `6` respectively

#### Scenario: actor_name comes from MonsterData
- **WHEN** a MonsterCombatant wraps a Monster whose `MonsterData.monster_name` is `"スライム"`
- **THEN** `actor_name` SHALL equal `"スライム"`
