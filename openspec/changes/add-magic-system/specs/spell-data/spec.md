## ADDED Requirements

### Requirement: SpellData defines a spell template

The system SHALL provide a `SpellData` Custom Resource that defines a spell template with identifier, display name, school, level, MP cost, target type, scope, and effect strategy.

`SpellData` SHALL expose the following fields:
- `id: StringName` — unique identifier matching the `.tres` filename basename (e.g., `fire.tres` → `id == &"fire"`).
- `display_name: String` — Japanese display name shown in UI.
- `school: StringName` — either `&"mage"` or `&"priest"`.
- `level: int` — spell level (1 or 2 in v1; structure SHALL allow higher values for future expansion).
- `mp_cost: int` — MP consumed per cast. SHALL be `>= 1`.
- `target_type: int` — enum value: `ENEMY_ONE` (0) | `ENEMY_GROUP` (1) | `ALLY_ONE` (2) | `ALLY_ALL` (3).
- `scope: int` — enum value: `BATTLE_ONLY` (0) | `OUTSIDE_OK` (1).
- `effect: SpellEffect` — sub-resource holding the effect strategy.

#### Scenario: SpellData carries required fields
- **WHEN** a SpellData resource is created with all required fields populated
- **THEN** every field SHALL be readable and typed consistently with its declaration

#### Scenario: id matches filename
- **WHEN** `data/spells/fire.tres` is loaded
- **THEN** the loaded SpellData's `id` SHALL equal `&"fire"`

#### Scenario: school is one of the recognized values
- **WHEN** any of the eight v1 SpellData files is loaded
- **THEN** `school` SHALL be either `&"mage"` or `&"priest"`

#### Scenario: target_type and scope are valid enum values
- **WHEN** any v1 SpellData is loaded
- **THEN** `target_type` SHALL be in `{0, 1, 2, 3}` and `scope` SHALL be in `{0, 1}`

### Requirement: SpellEffect provides a strategy abstraction for casting outcomes

The system SHALL provide a `SpellEffect` (Resource) abstract type with a method `apply(caster: CombatActor, targets: Array, rng: RandomNumberGenerator) -> SpellResolution`. Each concrete subclass SHALL implement this method to produce a `SpellResolution` value capturing per-target HP changes.

`SpellResolution` SHALL be a value object exposing `entries: Array` where each entry has `actor: CombatActor`, `hp_delta: int` (negative for damage, positive for heal), and `actor_name: String`.

#### Scenario: SpellEffect.apply returns SpellResolution
- **WHEN** `apply(caster, targets, rng)` is invoked on any concrete SpellEffect subclass
- **THEN** the return value SHALL be a SpellResolution with `entries.size() == targets.size()` (one entry per resolved target)

#### Scenario: SpellResolution preserves actor identity
- **WHEN** `apply(caster, [target_a, target_b], rng)` is called and produces non-zero deltas
- **THEN** `entries[0].actor` SHALL be `target_a` and `entries[1].actor` SHALL be `target_b`

### Requirement: DamageSpellEffect deals randomized damage

The system SHALL provide `DamageSpellEffect extends SpellEffect` with `@export var base_damage: int` and `@export var spread: int`, computing per-target damage as `base_damage + rng.randi_range(-spread, +spread)`, clamped at minimum `1`. Each target SHALL have `take_damage(damage)` invoked.

#### Scenario: Base damage with zero spread
- **WHEN** DamageSpellEffect with `base_damage = 6, spread = 0` is applied to one target
- **THEN** the target's HP SHALL decrease by exactly `6` and the SpellResolution entry SHALL have `hp_delta == -6`

#### Scenario: Damage with spread uses RNG
- **WHEN** DamageSpellEffect with `base_damage = 5, spread = 2` is applied with an RNG that returns `+1` from `randi_range(-2, 2)`
- **THEN** the target SHALL take exactly `6` damage

#### Scenario: Minimum damage floor of 1
- **WHEN** DamageSpellEffect computation produces `0` or a negative value
- **THEN** the applied damage SHALL be exactly `1`

#### Scenario: Damage applies to multiple targets independently
- **WHEN** DamageSpellEffect is applied to three monster targets, with RNG producing rolls of `+1`, `0`, `-1` for `base_damage = 5, spread = 1`
- **THEN** the three targets SHALL take `6`, `5`, and `4` damage respectively

### Requirement: HealSpellEffect restores HP without exceeding max_hp

The system SHALL provide `HealSpellEffect extends SpellEffect` with `@export var base_heal: int` and `@export var spread: int`, computing per-target heal as `base_heal + rng.randi_range(-spread, +spread)`, clamped at minimum `1`. Each target's `current_hp` SHALL be increased by the heal amount but SHALL NOT exceed `max_hp`. Dead targets (`is_alive() == false`) SHALL NOT be healed and SHALL NOT receive a SpellResolution entry; in v1 raise-dead is out of scope.

#### Scenario: Heal restores HP up to max
- **WHEN** HealSpellEffect with `base_heal = 8, spread = 0` is applied to a target with `current_hp = 5, max_hp = 12`
- **THEN** the target's `current_hp` SHALL become `12` (clamped) and the SpellResolution entry SHALL have `hp_delta == +7`

#### Scenario: Heal at full HP is a no-op
- **WHEN** HealSpellEffect is applied to a target whose `current_hp == max_hp`
- **THEN** the target's `current_hp` SHALL remain unchanged and the SpellResolution entry SHALL have `hp_delta == 0`

#### Scenario: Heal does not raise the dead
- **WHEN** HealSpellEffect is applied to a target list including one dead actor and two living
- **THEN** the SpellResolution SHALL contain entries for the two living targets only, and the dead actor's `current_hp` SHALL remain `0`

### Requirement: SpellRepository loads and provides spells by id

The system SHALL provide a `SpellRepository` that loads all `SpellData` resources at startup and exposes lookup by `id` via `find(id: StringName) -> SpellData`.

#### Scenario: Lookup existing spell
- **WHEN** a SpellRepository is populated with a SpellData whose `id` is `&"fire"`
- **THEN** `find(&"fire")` SHALL return that SpellData

#### Scenario: Lookup missing spell
- **WHEN** a SpellRepository is queried for `id` `&"nonexistent"`
- **THEN** `find(&"nonexistent")` SHALL return `null`

### Requirement: DataLoader bulk-loads spells from data directory

The system SHALL provide `DataLoader.load_all_spells()` that scans `res://data/spells/` for `.tres` files, casts each to `SpellData`, and returns the resulting array.

#### Scenario: Bulk load from data directory
- **WHEN** `DataLoader.load_all_spells()` is invoked
- **THEN** every `.tres` file under `data/spells/` SHALL be loaded into the returned array, with size matching the file count

#### Scenario: Returned array contains the eight v1 spells
- **WHEN** `DataLoader.load_all_spells()` is invoked in v1
- **THEN** the returned array's `id` set SHALL contain `{&"fire", &"frost", &"flame", &"blizzard", &"heal", &"holy", &"heala", &"allheal"}`

### Requirement: Eight v1 spells are defined as .tres resources

The system SHALL provide eight `.tres` resource files under `data/spells/` covering MAGE and PRIEST schools at spell levels 1 and 2.

| id | display_name | school | level | mp_cost | target_type | scope |
|---|---|---|---|---|---|---|
| `fire` | ファイア | mage | 1 | 2 | ENEMY_ONE | BATTLE_ONLY |
| `frost` | フロスト | mage | 1 | 2 | ENEMY_ONE | BATTLE_ONLY |
| `flame` | フレイム | mage | 2 | 4 | ENEMY_GROUP | BATTLE_ONLY |
| `blizzard` | ブリザード | mage | 2 | 4 | ENEMY_GROUP | BATTLE_ONLY |
| `heal` | ヒール | priest | 1 | 2 | ALLY_ONE | OUTSIDE_OK |
| `holy` | ホーリー | priest | 1 | 2 | ENEMY_ONE | BATTLE_ONLY |
| `heala` | ヒーラ | priest | 2 | 3 | ALLY_ONE | OUTSIDE_OK |
| `allheal` | オールヒール | priest | 2 | 5 | ALLY_ALL | OUTSIDE_OK |

Each `.tres` SHALL embed a `DamageSpellEffect` (for damaging spells) or `HealSpellEffect` (for healing spells) sub-resource. Specific damage/heal numbers SHALL be set so that v1 spells are useful but not dominant relative to physical attacks of the same level (concrete tuning values are an implementation detail of `tasks.md`).

#### Scenario: All eight files exist
- **WHEN** the `data/spells/` directory is scanned
- **THEN** exactly eight `.tres` files SHALL exist with the ids listed above

#### Scenario: Each file's id matches its filename
- **WHEN** `data/spells/<id>.tres` is loaded for any of the eight ids
- **THEN** the loaded SpellData's `id` SHALL equal `<id>`

#### Scenario: Damage spells embed DamageSpellEffect
- **WHEN** `fire.tres`, `frost.tres`, `flame.tres`, `blizzard.tres`, or `holy.tres` is loaded
- **THEN** the `effect` field SHALL be a `DamageSpellEffect` instance

#### Scenario: Healing spells embed HealSpellEffect
- **WHEN** `heal.tres`, `heala.tres`, or `allheal.tres` is loaded
- **THEN** the `effect` field SHALL be a `HealSpellEffect` instance

#### Scenario: Group spells use ENEMY_GROUP target_type
- **WHEN** `flame.tres` or `blizzard.tres` is loaded
- **THEN** `target_type` SHALL equal `ENEMY_GROUP`

#### Scenario: Outside-OK scope is set only on healing spells
- **WHEN** any v1 spell is loaded
- **THEN** `scope == OUTSIDE_OK` SHALL hold for `heal`, `heala`, `allheal` only; all other v1 spells SHALL have `scope == BATTLE_ONLY`
