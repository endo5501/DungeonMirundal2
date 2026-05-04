## MODIFIED Requirements

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
