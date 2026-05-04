# spell-casting Specification

## Purpose
TBD - created by archiving change add-magic-system. Update Purpose after archive.
## Requirements
### Requirement: Casting consumes MP via the caster's spend_mp interface

The system SHALL, before applying any spell effect, attempt to consume `spell.mp_cost` from the caster via `caster.spend_mp(spell.mp_cost)`. If the call returns `false` (insufficient MP), the cast SHALL be aborted and SHALL NOT apply any effect.

#### Scenario: Sufficient MP allows the cast
- **WHEN** a caster with `current_mp = 5` casts a spell with `mp_cost = 2`
- **THEN** `spend_mp(2)` SHALL return `true`, the caster's `current_mp` SHALL become `3`, and the spell effect SHALL be applied to the resolved targets

#### Scenario: Insufficient MP aborts the cast
- **WHEN** a caster with `current_mp = 1` attempts to cast a spell with `mp_cost = 2`
- **THEN** `spend_mp(2)` SHALL return `false`, the caster's `current_mp` SHALL remain `1`, and the spell effect SHALL NOT be applied to any target

### Requirement: Target resolution depends on target_type

The system SHALL resolve cast targets at resolution time according to `spell.target_type`:

- `ENEMY_ONE`: a single specified opposing CombatActor.
- `ENEMY_GROUP`: every living opposing MonsterCombatant whose underlying `MonsterData` matches the specified species.
- `ALLY_ONE`: a single specified PartyCombatant from the caster's side.
- `ALLY_ALL`: every living PartyCombatant from the caster's side.

If at resolution time the originally specified single target (`ENEMY_ONE` / `ALLY_ONE`) is no longer alive, the system SHALL retarget to another living member of the same side (preferring the same species for `ENEMY_ONE`); if no living member exists on that side, the cast SHALL be skipped without consuming MP.

#### Scenario: ENEMY_ONE targets one specific monster
- **WHEN** a fire spell with `target_type = ENEMY_ONE` is cast at "Slime A"
- **THEN** the resolved target list SHALL contain exactly `["Slime A"]` (assuming alive)

#### Scenario: ENEMY_GROUP targets all living monsters of one species
- **WHEN** a flame spell with `target_type = ENEMY_GROUP` is cast at the "Slime" group, where 2 slimes and 1 goblin are alive
- **THEN** the resolved target list SHALL contain both slimes and SHALL NOT contain the goblin

#### Scenario: ENEMY_GROUP omits dead members of the group
- **WHEN** a group spell is cast at "Slime" group with 3 slimes alive at command time, but 1 slime dies before the cast resolves
- **THEN** the resolved target list SHALL contain only the 2 still-living slimes

#### Scenario: ALLY_ALL targets every living party member
- **WHEN** an allheal spell is cast on a party of 4, where 1 member is dead at resolution time
- **THEN** the resolved target list SHALL contain exactly the 3 living party members

#### Scenario: Single-target retarget when target is dead
- **WHEN** a fire spell is cast at "Slime A", but "Slime A" dies before resolution and "Slime B" (same species) is still alive
- **THEN** the cast SHALL retarget to "Slime B" and apply the effect there

#### Scenario: Cast is skipped when no valid target remains
- **WHEN** a fire spell is cast at the only remaining living monster, but that monster dies (via an earlier action this turn) before resolution and no other monster is alive
- **THEN** the cast SHALL be skipped, MP SHALL NOT be consumed (refund or pre-resolution check), and a log entry SHALL note the cancellation

### Requirement: Cast effect application produces a SpellResolution

The system SHALL invoke `spell.effect.apply(caster, resolved_targets, spell_rng)` after MP is consumed and targets are resolved, where `spell_rng` is a `SpellRng` instance (a project-defined RefCounted wrapper around `RandomNumberGenerator` that exposes `roll(low, high) -> int`). The system SHALL incorporate the returned `SpellResolution` into the cast's report (battle context: `TurnReport`; outside-battle context: equivalent flow report) so that UI can render per-target HP deltas.

The caller SHALL construct the `SpellRng` by wrapping the active `RandomNumberGenerator` (e.g. `SpellRng.new(rng)`) at the cast site, so that determinism under a fixed seed is preserved through the wrapper. `SpellEffect` subclasses SHALL invoke `spell_rng.roll(low, high)` (rather than `rng.randi_range(low, high)`) when they need a random integer in a closed interval.

#### Scenario: SpellResolution entries match resolved targets
- **WHEN** a flame spell resolves on 2 slimes
- **THEN** the SpellResolution returned by `effect.apply` SHALL contain exactly 2 entries, one per slime

#### Scenario: SpellResolution is recorded in TurnReport (battle context)
- **WHEN** a Cast command resolves during a battle turn
- **THEN** the resulting `TurnReport` SHALL include a cast action entry referencing the spell id, caster name, and the SpellResolution entries

#### Scenario: SpellRng wraps the active RandomNumberGenerator at the cast site
- **WHEN** `_resolve_cast` (battle context) or `_apply_cast_and_show_result` (outside-battle context) calls `effect.apply`
- **THEN** the third argument SHALL be a `SpellRng` instance constructed from the active `RandomNumberGenerator` (i.e. `SpellRng.new(rng)`), and `SpellEffect` subclasses SHALL obtain random rolls via `spell_rng.roll(low, high)`

#### Scenario: Same seed produces same SpellResolution through SpellRng
- **WHEN** two casts of the same spell on equivalent targets are executed with `RandomNumberGenerator` instances that share the same seed
- **THEN** both calls to `effect.apply(caster, targets, SpellRng.new(rng))` SHALL produce SpellResolutions whose per-target HP deltas are identical

### Requirement: BATTLE_ONLY scope rejects out-of-battle casts

The system SHALL reject any attempt to cast a spell whose `scope == BATTLE_ONLY` in an out-of-battle context (the ESC-menu spell flow). The UI SHALL filter such spells out of the selectable list, and the casting helper SHALL refuse the cast even if invoked programmatically.

#### Scenario: ESC-menu spell list excludes BATTLE_ONLY spells
- **WHEN** the ESC-menu spell flow asks the SpellRepository for a caster's available spells in the out-of-battle context
- **THEN** the returned list SHALL contain only spells whose `scope == OUTSIDE_OK` and which appear in the caster's `known_spells`

#### Scenario: Programmatic out-of-battle cast of a BATTLE_ONLY spell is refused
- **WHEN** the casting helper is invoked outside of battle with a `BATTLE_ONLY` spell
- **THEN** the call SHALL return a failure result, MP SHALL NOT be consumed, and the spell effect SHALL NOT be applied

### Requirement: Out-of-battle cast applies effects via the same SpellEffect path

The system SHALL, in the out-of-battle ESC-menu spell flow, invoke `spell.effect.apply(caster, resolved_targets, spell_rng)` using the same `SpellEffect` strategy as in battle, ensuring that healing applies identically inside and outside of battle. The `spell_rng` argument SHALL be a `SpellRng` instance wrapping the flow's active `RandomNumberGenerator`.

`SpellUseFlow.set_rng()` SHALL accept a `SpellRng` directly so that the out-of-battle flow exposes the same `SpellRng`-typed seam as the in-battle `_resolve_cast` path. When no RNG has been injected, the flow SHALL lazily construct `SpellRng.new(null)` (which internally creates and randomizes a `RandomNumberGenerator`).

#### Scenario: Heal applied outside battle changes Character HP
- **WHEN** a Priest casts heal on an injured ally via the ESC menu spell flow with `current_hp = 5, max_hp = 12`
- **THEN** the ally's `current_hp` SHALL increase by the rolled heal amount (clamped at `max_hp`), the caster's MP SHALL be consumed, and the change SHALL persist in `Character.current_hp`

#### Scenario: SpellUseFlow.set_rng accepts a SpellRng
- **WHEN** a test calls `flow.set_rng(SpellRng.new(seeded_rng))` before invoking the flow
- **THEN** subsequent `effect.apply` calls inside the flow SHALL receive that exact `SpellRng` instance, and the flow SHALL NOT construct a new RNG

#### Scenario: Default SpellRng is created when none is injected
- **WHEN** `SpellUseFlow` invokes `effect.apply` without any prior `set_rng` call
- **THEN** the flow SHALL lazily construct a `SpellRng` whose internal `RandomNumberGenerator` is created and randomized, and SHALL pass that instance to `effect.apply`

