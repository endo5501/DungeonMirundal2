## ADDED Requirements

### Requirement: Cast command resolves a spell via the spell-casting flow

The system SHALL provide a `Cast` command that a PartyCombatant can submit during command input. The command SHALL carry the SpellData id, the caster's party index, and a target descriptor (single-target identity for `ENEMY_ONE` / `ALLY_ONE`, or a species/group key for `ENEMY_GROUP`, or `null` for `ALLY_ALL`).

When `TurnEngine.resolve_turn(rng)` reaches the caster's turn, the engine SHALL:

1. Resolve the SpellData by id from the SpellRepository.
2. Attempt `caster.spend_mp(spell.mp_cost)`. If `false`, skip the cast and emit a `cast_skipped_no_mp` action entry (no MP consumed, no effect applied).
3. Resolve targets per `spell.target_type` as defined in the `spell-casting` capability.
4. If no living target remains after resolution, refund/abort: SHALL NOT consume MP (in v1, the engine SHALL pre-check living targets before calling `spend_mp`), SHALL NOT apply effect, and SHALL emit a `cast_skipped_no_target` action entry.
5. Otherwise, invoke `spell.effect.apply(caster, resolved_targets, rng)` and append a cast action entry to the TurnReport.

#### Scenario: Cast deducts MP and applies effect
- **WHEN** a Mage with `current_mp = 5` submits a Cast for `fire` (mp_cost=2) on a slime, and the slime is alive at resolution
- **THEN** the Mage's `current_mp` SHALL become `3`, the slime SHALL take damage per `DamageSpellEffect`, and the TurnReport SHALL contain a cast action entry referencing the spell id, caster name, and the per-target HP delta

#### Scenario: Cast aborts on insufficient MP
- **WHEN** a Mage with `current_mp = 1` submits a Cast for `fire` (mp_cost=2)
- **THEN** the Mage's `current_mp` SHALL remain `1`, no target SHALL take damage, and the TurnReport entry SHALL be a `cast_skipped_no_mp` action

#### Scenario: Cast aborts when no target survives
- **WHEN** a Mage submits a Cast for `fire` on the only living monster, but that monster dies before the cast resolves and no other monster is alive
- **THEN** the Mage's MP SHALL NOT be consumed and the TurnReport entry SHALL be a `cast_skipped_no_target` action

#### Scenario: Cast retargets ENEMY_ONE within group when original dies
- **WHEN** a Mage submits a Cast for `fire` on "Slime A", but "Slime A" dies before resolution while "Slime B" (same species) is alive
- **THEN** the cast SHALL apply to "Slime B" and the TurnReport SHALL record the retarget

#### Scenario: ENEMY_GROUP cast applies to all living members of the species
- **WHEN** a Mage submits a Cast for `flame` (ENEMY_GROUP) on the Slime group with 2 slimes alive
- **THEN** both slimes SHALL take damage and the TurnReport SHALL list both per-target deltas under one cast action entry

#### Scenario: ALLY_ALL cast targets every living party member
- **WHEN** a Priest submits a Cast for `allheal` (ALLY_ALL) with 3 of 4 party members alive
- **THEN** the 3 living members SHALL be healed and the dead member SHALL be untouched

### Requirement: Cast actions are recorded in TurnReport with structure suitable for the combat log

The system SHALL append cast actions to the TurnReport using a structure containing at minimum: `kind = "cast"`, `caster_name: String`, `spell_id: StringName`, `spell_display_name: String`, `entries: Array` of per-target deltas (`actor_name: String`, `hp_delta: int`), and optional `retargeted_from: String` (empty when no retarget). Skipped casts SHALL use `kind = "cast_skipped_no_mp"` or `kind = "cast_skipped_no_target"` with appropriate fields.

#### Scenario: Cast action entry exposes spell metadata
- **WHEN** a fire spell is cast and resolved
- **THEN** the corresponding TurnReport entry SHALL have `kind == "cast"`, `spell_id == &"fire"`, `spell_display_name == "ファイア"`, and at least one `entries` element with the target's name and HP delta

#### Scenario: Cast skip is rendered with explanation
- **WHEN** `cast_skipped_no_mp` is recorded for caster "Alice" attempting "ファイア"
- **THEN** the TurnReport entry SHALL have `kind == "cast_skipped_no_mp"`, `caster_name == "Alice"`, `spell_display_name == "ファイア"`
