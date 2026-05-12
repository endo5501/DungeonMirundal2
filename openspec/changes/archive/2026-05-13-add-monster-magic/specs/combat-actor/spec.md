## MODIFIED Requirements

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
