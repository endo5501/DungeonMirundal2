## Purpose
ターン制戦闘の全体フローを規定する。コマンド選択・行動順決定・ダメージ算出・勝敗判定・戦闘終了処理までを CombatEngine の責務として定める。
## Requirements
### Requirement: TurnEngine manages the battle state machine
The system SHALL provide a `TurnEngine` (RefCounted) that orchestrates a Wizardry-style turn-based battle between a party (array of `PartyCombatant`) and a monster party (array of `MonsterCombatant`), exposing state transitions `IDLE → COMMAND_INPUT → RESOLVING → COMMAND_INPUT` until a terminal `FINISHED` state is reached.

#### Scenario: start_battle enters COMMAND_INPUT
- **WHEN** `start_battle(party, monsters)` is called on a TurnEngine in `IDLE`
- **THEN** the state SHALL become `COMMAND_INPUT` and the turn counter SHALL be `1`

#### Scenario: All party commands submitted transitions to RESOLVING
- **WHEN** every living PartyCombatant has a command submitted via `submit_command(actor_index, command)` during `COMMAND_INPUT`
- **THEN** the state SHALL become `RESOLVING` on the next `resolve_turn(rng)` call

#### Scenario: Turn resolution cycles back to COMMAND_INPUT if battle continues
- **WHEN** `resolve_turn(rng)` completes and neither side is wiped and no escape succeeds
- **THEN** the state SHALL return to `COMMAND_INPUT` and the turn counter SHALL increment

#### Scenario: Battle terminates with CLEARED when all monsters die
- **WHEN** resolution results in all MonsterCombatants with `is_alive() == false`
- **THEN** the state SHALL become `FINISHED` and `outcome()` SHALL return an `EncounterOutcome` with `result == CLEARED`

#### Scenario: Battle terminates with WIPED when all party members die
- **WHEN** resolution results in all PartyCombatants with `is_alive() == false`
- **THEN** the state SHALL become `FINISHED` and `outcome()` SHALL return an `EncounterOutcome` with `result == WIPED`

#### Scenario: Battle terminates with ESCAPED on successful flee
- **WHEN** the party submits an Escape command and the escape roll succeeds during resolution
- **THEN** the state SHALL become `FINISHED` and `outcome()` SHALL return an `EncounterOutcome` with `result == ESCAPED`

### Requirement: Turn order is agility-descending with deterministic tiebreak
The system SHALL order all living combatants (party and monsters) by `get_agility()` in descending order, breaking ties deterministically using the injected `RandomNumberGenerator`.

#### Scenario: Higher agility acts first
- **WHEN** combatants A (agility 8) and B (agility 5) are ordered for a turn
- **THEN** A SHALL appear before B in the turn order

#### Scenario: Dead combatants are excluded from order
- **WHEN** a combatant has `is_alive() == false` at the moment turn order is computed
- **THEN** that combatant SHALL NOT appear in the turn order

#### Scenario: Tiebreak is deterministic under a fixed RNG seed
- **WHEN** two combatants with equal agility are ordered twice using an RNG seeded with the same value
- **THEN** both runs SHALL produce the same ordering

### Requirement: Attack command resolves damage via DamageCalculator
The system SHALL provide an `Attack` command that targets exactly one opposing `CombatActor`, and SHALL compute damage through a `DamageCalculator` that uses attacker and target stats plus an RNG for spread.

#### Scenario: Basic damage formula
- **WHEN** damage is calculated for attacker with `get_attack() = 10`, target with `get_defense() = 4`, and RNG producing a spread of `+1`
- **THEN** the damage SHALL equal `max(1, 10 - 4 / 2 + 1) == 9`

#### Scenario: Minimum damage floor
- **WHEN** the computed damage would be `0` or negative (e.g., attack well below defense)
- **THEN** the applied damage SHALL be exactly `1`

#### Scenario: Attack on a dead target is skipped
- **WHEN** the selected target has `is_alive() == false` at the time the attacker acts
- **THEN** the attack SHALL either be retargeted to another living enemy of the same side, or SHALL be skipped if no living target remains; in neither case SHALL damage be dealt to a dead target

### Requirement: Defend command halves incoming damage for that turn
The system SHALL provide a `Defend` command that, when submitted by a PartyCombatant, causes the combatant to be in the defending posture throughout the entire resolution of the current turn.

#### Scenario: Defending actor takes half damage
- **WHEN** a PartyCombatant with `Defend` submitted is attacked for `8` damage during the turn
- **THEN** the HP reduction SHALL be `4`

#### Scenario: Defend does not carry over
- **WHEN** a defending PartyCombatant finishes the turn and a new turn begins without re-submitting Defend
- **THEN** incoming damage in the new turn SHALL be taken at full value

### Requirement: Escape command is a party-level action
The system SHALL provide an `Escape` command that, if submitted by any one PartyCombatant in a turn, causes the TurnEngine to roll for escape during resolution; the roll is a single party-level check, not per-member.

#### Scenario: One escape command per turn triggers one check
- **WHEN** multiple party members submit `Escape` in the same turn
- **THEN** the TurnEngine SHALL roll for escape exactly once during resolution

#### Scenario: Escape success ends the battle with ESCAPED
- **WHEN** the escape roll succeeds
- **THEN** the battle SHALL end with `outcome().result == ESCAPED` and no further actions SHALL resolve this turn

#### Scenario: Escape failure forfeits party offense this turn
- **WHEN** the escape roll fails
- **THEN** no PartyCombatant attacks SHALL resolve this turn; only the monsters SHALL take their actions

#### Scenario: Initial escape probability is 0.5
- **WHEN** the RNG rolls below the configured escape threshold (initial value `0.5`)
- **THEN** the escape SHALL succeed

### Requirement: Monster actions target a random living PartyCombatant
The system SHALL make every acting MonsterCombatant attack exactly one randomly-selected living PartyCombatant per turn, using the injected RNG.

#### Scenario: Monster skips its action when no party member is alive
- **WHEN** every PartyCombatant has `is_alive() == false` at the moment a monster would act
- **THEN** the monster SHALL NOT take an action (resolution proceeds to termination check)

#### Scenario: Target choice is deterministic under fixed seed
- **WHEN** a monster selects a target twice with identically-seeded RNGs and the same living-party set
- **THEN** both runs SHALL select the same PartyCombatant

### Requirement: TurnEngine exposes a per-turn report for the UI
The system SHALL expose, after each `resolve_turn(rng)` call, a `TurnReport` value that lists the actions taken in order (attacker, target, damage, miss/defended flags) so that the CombatOverlay can render a combat log without introspecting internal state.

#### Scenario: TurnReport lists actions in resolution order
- **WHEN** `resolve_turn(rng)` has executed one party attack then one monster attack
- **THEN** the returned TurnReport SHALL contain exactly two action entries, in that order

### Requirement: TurnEngine records target retargeting in TurnReport
SHALL: When `TurnEngine._resolve_attack` retargets an attack from a dead target to a living one (via `_pick_living_same_side_as`), the resulting `ReportAction` SHALL record the original (now-dead) target's name in a new `retargeted_from: String` field. When no retargeting occurs, `retargeted_from` SHALL be the empty string.

#### Scenario: Attack on dead target retargets and records
- **WHEN** Player attacks Slime A; Slime A dies before player's turn; TurnEngine resolves and retargets to Slime B
- **THEN** the corresponding `ReportAction` SHALL have `target_name = "Slime B"` and `retargeted_from = "Slime A"`

#### Scenario: Attack on living target does not record retargeting
- **WHEN** Player attacks Slime A and Slime A is alive at resolution time
- **THEN** the corresponding `ReportAction` SHALL have `target_name = "Slime A"` and `retargeted_from = ""`

#### Scenario: CombatLog displays retargeting message
- **WHEN** `combat_log.append_from_report_action(action)` is called with `action.retargeted_from = "Slime A"` and `action.target_name = "Slime B"`
- **THEN** the appended log line SHALL contain both names with text indicating that "Slime A" was already dead and the attack landed on "Slime B"

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

The system SHALL append cast actions to the TurnReport using a structure containing at minimum: `type = "cast"`, `caster_name: String`, `spell_id: StringName`, `spell_display_name: String`, `entries: Array` of per-target deltas (`actor_name: String`, `hp_delta: int`), and optional `retargeted_from: String` (empty when no retarget). Skipped casts SHALL use `type = "cast_skipped_no_mp"` or `type = "cast_skipped_no_target"` with appropriate fields. The `type` key (rather than `kind`) is chosen for consistency with existing TurnReport entries (`attack`, `defend`, `escape`, `item_use`, `item_cancelled`, `defeated`).

#### Scenario: Cast action entry exposes spell metadata
- **WHEN** a fire spell is cast and resolved
- **THEN** the corresponding TurnReport entry SHALL have `type == "cast"`, `spell_id == &"fire"`, `spell_display_name == "ファイア"`, and at least one `entries` element with the target's name and HP delta

#### Scenario: Cast skip is rendered with explanation
- **WHEN** `cast_skipped_no_mp` is recorded for caster "Alice" attempting "ファイア"
- **THEN** the TurnReport entry SHALL have `type == "cast_skipped_no_mp"`, `caster_name == "Alice"`, `spell_display_name == "ファイア"`

