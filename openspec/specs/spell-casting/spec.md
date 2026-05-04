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

The system SHALL invoke `spell.effect.apply(caster, resolved_targets, spell_rng)` after MP is consumed and targets are resolved, where `spell_rng` is a `SpellRng` instance (a project-defined RefCounted wrapper around `RandomNumberGenerator` that exposes `roll(low, high) -> int`). The system SHALL incorporate the returned `SpellResolution` into the cast's report (battle context: `TurnReport`; outside-battle context: equivalent flow report) so that UI can render per-target HP deltas and per-target events.

The caller SHALL construct the `SpellRng` by wrapping the active `RandomNumberGenerator` (e.g. `SpellRng.new(rng)`) at the cast site. `SpellEffect` subclasses SHALL invoke `spell_rng.roll(low, high)` (rather than `rng.randi_range(low, high)`) when they need a random integer in a closed interval.

`SpellResolution.entries[i]` SHALL include `events: Array` in addition to the existing `actor`, `actor_name`, `hp_delta` keys. Producers SHALL keep `hp_delta` consistent with the sum of HP-affecting events (damage / heal / tick_damage).

#### Scenario: SpellResolution entries match resolved targets
- **WHEN** a flame spell resolves on 2 slimes
- **THEN** `entries.size()` SHALL equal 2

#### Scenario: SpellResolution entry exposes events
- **WHEN** a status inflict spell resolves on a single target with a successful roll
- **THEN** the entry SHALL have `events == [{type: "inflict", status_id, success: true}]` and `hp_delta == 0`

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

### Requirement: SpellResolution entries carry an events list

The system SHALL extend each `SpellResolution.entries[i]` to include a key `events: Array` containing zero or more event Dictionaries, in addition to existing keys `actor`, `actor_name`, `hp_delta`. Each event Dictionary SHALL have a `type: String` and one of the following recognized shapes:

- `{ type: "damage", amount: int }` (positive int)
- `{ type: "heal", amount: int }` (positive int)
- `{ type: "inflict", status_id: StringName, success: bool }`
- `{ type: "cure", status_id: StringName }`
- `{ type: "resist", status_id: StringName }`
- `{ type: "stat_mod", stat: StringName, delta: Variant, turns: int }`
- `{ type: "tick_damage", status_id: StringName, amount: int }` (reserved for future use; not produced by SpellEffect.apply directly)
- `{ type: "wake", status_id: StringName }` (reserved for future use)

The `hp_delta` value SHALL equal the signed sum of HP deltas implied by the events: `sum(heal.amount) - sum(damage.amount) - sum(tick_damage.amount)`. Producers of events SHALL keep `hp_delta` consistent with the events they append.

#### Scenario: DamageSpellEffect appends a damage event in addition to hp_delta
- **WHEN** `DamageSpellEffect.apply(...)` deals 6 damage to a target
- **THEN** the corresponding entry SHALL have `hp_delta == -6` and `events == [{type: "damage", amount: 6}]`

#### Scenario: HealSpellEffect appends a heal event
- **WHEN** `HealSpellEffect.apply(...)` heals a target by 4
- **THEN** the entry SHALL have `hp_delta == +4` and `events == [{type: "heal", amount: 4}]`

#### Scenario: SpellResolution.add_entry returns the entry Dictionary
- **WHEN** `resolution.add_entry(actor, hp_delta)` is called
- **THEN** the return value SHALL be the same Dictionary appended to `entries`, allowing the caller to mutate `events` directly

### Requirement: StatusInflictSpellEffect inflicts a status with chance and resistance

The system SHALL provide a `StatusInflictSpellEffect` Resource with `@export status_id: StringName`, `@export chance: float` (0..1), `@export duration: int`. Its `apply(caster, targets, spell_rng) -> SpellResolution` SHALL:

1. Resolve `data := DataLoader.new().load_status_repository().find(status_id)`. If `data == null`, return an empty SpellResolution.
2. For each target:
   a. Add a fresh entry with `hp_delta = 0`.
   b. Compute `effective = clamp(chance - target.get_resist(data.resist_key), 0.0, 1.0)`.
   c. Roll `r = spell_rng.roll(0, 99)`. Treat `r < effective * 100` (integer floor) as a hit.
   d. On hit: pick `dur := duration` if `data.scope == BATTLE_ONLY`, else `StatusTrack.PERSISTENT_DURATION`. Call `target.statuses.apply(data.id, dur)`. Append `{type: "inflict", status_id, success: true}`.
   e. On miss: append `{type: "resist", status_id}`. The `success: false` form is used only when callers need it; the standard miss path emits `resist`.

#### Scenario: Inflict succeeds when roll is below effective chance
- **WHEN** a StatusInflictSpellEffect with `chance = 0.6` targets an actor with `get_resist == 0.2` and `spell_rng.roll(0, 99)` returns `30`
- **THEN** `effective = 0.4`, `30 < 40`, the target's `statuses.has(status_id)` SHALL be `true`, and the entry SHALL contain `{type: "inflict", success: true}`

#### Scenario: Inflict fails when roll is at or above effective chance
- **WHEN** the same setup but `spell_rng.roll(0, 99)` returns `45`
- **THEN** the target's `statuses.has(status_id)` SHALL be `false` and the entry SHALL contain `{type: "resist"}`

#### Scenario: Inflict on PERSISTENT scope uses sentinel duration
- **WHEN** the StatusData for the inflicted status has `scope == PERSISTENT`
- **THEN** the duration applied SHALL be `StatusTrack.PERSISTENT_DURATION` regardless of the spell effect's `duration` field

### Requirement: DamageWithStatusSpellEffect deals damage and rolls inflict per target

The system SHALL provide a `DamageWithStatusSpellEffect` Resource with `@export base_damage: int`, `@export spread: int`, `@export status_id: StringName`, `@export inflict_chance: float`, `@export status_duration: int`. Its `apply` SHALL, for each target:

1. Compute and apply damage as in `DamageSpellEffect` (`amount = max(1, base_damage + roll)`), append a `damage` event, and update `hp_delta`.
2. After damage, compute `effective = clamp(inflict_chance - target.get_resist(status_data.resist_key), 0.0, 1.0)` and roll for inflict.
3. On hit: `target.statuses.apply(status_id, dur)` (using PERSISTENT sentinel when scope is PERSISTENT) and append `inflict` event.
4. On miss: append `resist` event.
5. If the damage step kills the target (`is_alive() == false`), the inflict step SHALL be skipped (no event appended).

#### Scenario: Damage applies and status is rolled separately
- **WHEN** the spell deals 4 damage and inflict roll succeeds
- **THEN** the entry SHALL include both `damage(4)` and `inflict` events, and the target SHALL hold the status

#### Scenario: Killed targets do not receive status inflicts
- **WHEN** the damage step reduces the target to HP 0
- **THEN** no `inflict` or `resist` event SHALL be appended for that target, and `target.statuses.has(status_id)` SHALL be `false`

### Requirement: StatModSpellEffect adds a modifier via the β rule

The system SHALL provide a `StatModSpellEffect` Resource with `@export stat: StringName`, `@export delta: Variant` (int or float), `@export turns: int`. Its `apply` SHALL, for each target, call `target.modifier_stack.add(stat, delta, turns)` and append a `stat_mod` event with the same `(stat, delta, turns)`.

The β rule (defined in `combat-actor`) governs whether the new modifier replaces, extends, or is dropped.

#### Scenario: StatModSpellEffect adds a modifier
- **WHEN** the spell adds `{stat: &"attack", delta: +2, turns: 3}` to a target with no prior modifier on `&"attack"`
- **THEN** `target.modifier_stack.sum(&"attack") == +2` and the entry SHALL contain a `stat_mod` event

#### Scenario: Stronger modifier replaces weaker one
- **WHEN** a target has `&"attack": +1` and the spell tries `{delta: +2}`
- **THEN** the modifier SHALL become `+2` (β rule from combat-actor)

### Requirement: CureStatusSpellEffect cures a single status id

The system SHALL provide a `CureStatusSpellEffect` Resource with `@export status_id: StringName`. Its `apply` SHALL, for each target, call `target.statuses.cure(status_id)`. If the cure removed an entry, append a `cure` event; otherwise append nothing for that target (no failure event).

#### Scenario: Cure removes the named status
- **WHEN** a target holds `&"poison"` and the spell with `status_id == &"poison"` is cast
- **THEN** the target's `statuses.has(&"poison")` SHALL be `false` and the entry SHALL contain a `cure` event

#### Scenario: Cure on a clean target is a no-op
- **WHEN** a target does not hold the status
- **THEN** no event SHALL be appended for that target

