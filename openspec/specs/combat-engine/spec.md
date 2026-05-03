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

