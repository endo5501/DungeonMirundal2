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
The system SHALL provide an `Attack` command that targets exactly one opposing `CombatActor`, and SHALL compute damage through a `DamageCalculator` that uses attacker and target stats plus an RNG for both a hit roll and a damage spread. When the hit roll fails, no damage SHALL be applied and a miss action entry SHALL be appended to the TurnReport.

#### Scenario: Basic damage formula on a hit
- **WHEN** damage is calculated for attacker with `get_attack() = 10`, target with `get_defense() = 4`, RNG yielding a successful hit roll, and the spread roll producing `+1`
- **THEN** the returned `DamageResult` SHALL satisfy `hit == true` and `amount == max(1, 10 - 4 / 2 + 1) == 9`, and the target SHALL take that damage via `take_damage`

#### Scenario: Minimum damage floor on a hit
- **WHEN** the computed damage on a hit would be `0` or negative (e.g., attack well below defense)
- **THEN** the applied damage SHALL be exactly `1`

#### Scenario: Miss does not apply damage and records a miss action
- **WHEN** the hit roll fails
- **THEN** `take_damage` SHALL NOT be called on the target and the TurnReport SHALL contain a single action entry with `type == "miss"`, attacker name, and target name

#### Scenario: Attack on a dead target is skipped
- **WHEN** the selected target has `is_alive() == false` at the time the attacker acts
- **THEN** the attack SHALL either be retargeted to another living enemy of the same side, or SHALL be skipped if no living target remains; in neither case SHALL damage be dealt to a dead target and the hit roll SHALL only happen on a valid (living) target

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

### Requirement: TurnReport records miss action entries

The system SHALL provide `TurnReport.add_miss(attacker, target)` and SHALL append an action entry of the form `{ type: "miss", attacker_name: String, target_name: String }`. Existing `add_attack` entries SHALL keep their current shape and SHALL only be created when an attack hits.

#### Scenario: add_miss produces the documented entry
- **WHEN** `report.add_miss(attacker, target)` is called with `attacker.actor_name = "Alice"` and `target.actor_name = "Slime A"`
- **THEN** the appended action SHALL have `type == "miss"`, `attacker_name == "Alice"`, and `target_name == "Slime A"`

#### Scenario: add_attack is unchanged for hits
- **WHEN** an attack lands and the engine calls `report.add_attack(attacker, target, damage, defended, retargeted_from)`
- **THEN** the appended action SHALL keep its existing shape (`type == "attack"`, plus damage/defended/retargeted_from fields)

### Requirement: TurnEngine ticks modifier stacks at end-of-turn cleanup

The system SHALL invoke `modifier_stack.tick_battle_turn()` for every party member and every monster as part of `_end_turn_cleanup()`, so that battle-only stat modifiers decay one turn per resolved turn. The system SHALL NOT clear battle-only modifiers at the end of an individual turn — only `clear_battle_only()` (called at battle end by a later change) does that.

#### Scenario: A 2-turn modifier survives one turn end and expires after the second
- **WHEN** an actor has `modifier_stack.add(&"attack", +2, 2)` set before turn N, and turn N completes
- **THEN** at the start of turn N+1 the actor's `modifier_stack.sum(&"attack")` SHALL still be `+2`
- **WHEN** turn N+1 also completes
- **THEN** at the start of turn N+2 the actor's `modifier_stack.sum(&"attack")` SHALL be `0`

#### Scenario: Tick is invoked for every actor including dead ones
- **WHEN** `_end_turn_cleanup()` runs at the end of a turn where one party member died
- **THEN** every party member (alive or dead) and every monster SHALL have `tick_battle_turn()` called once

### Requirement: TurnReport records new status-related action entries

The system SHALL extend `TurnReport` with the following action shapes (all new types, no modifications to existing types):

- `tick_damage`: `{ type, actor_name, status_id, amount, killed_by_tick }`
- `wake`: `{ type, actor_name, status_id }`
- `inflict`: `{ type, target_name, status_id, success }`
- `cure`: `{ type, actor_name, status_id }`
- `resist`: `{ type, target_name, status_id }`
- `stat_mod`: `{ type, target_name, stat, delta, turns }`
- `action_locked`: `{ type, actor_name }`
- `cast_silenced`: `{ type, caster_name, spell_id }`

Each shape SHALL have a corresponding `add_*` method on `TurnReport`.

#### Scenario: add_tick_damage produces the documented entry
- **WHEN** `report.add_tick_damage(actor, &"poison", 2, false)` is called with `actor.actor_name == "Alice"`
- **THEN** the appended entry SHALL equal `{ type: "tick_damage", actor_name: "Alice", status_id: &"poison", amount: 2, killed_by_tick: false }`

#### Scenario: add_action_locked produces the documented entry
- **WHEN** `report.add_action_locked(actor)` is called
- **THEN** the appended entry SHALL have `type == "action_locked"` and `actor_name == actor.actor_name`

#### Scenario: Existing action types are unchanged
- **WHEN** any of `add_attack`, `add_defend`, `add_escape`, `add_cast`, `add_item_use`, `add_defeated`, `add_miss` is called
- **THEN** the appended entry SHALL keep its existing structure (no new mandatory fields)

### Requirement: TurnEngine emits actor_action_started during resolution

`TurnEngine` SHALL define a signal `actor_action_started(actor: CombatActor, action_kind: StringName)` and SHALL emit it once for each actor immediately before that actor's command resolution begins, while the engine is in the `RESOLVING` state. The `action_kind` SHALL be one of: `&"attack"`, `&"defend"`, `&"cast"`, `&"item"`, `&"escape"`.

#### Scenario: Attack command emits actor_action_started with kind "attack"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted an `Attack` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"attack")` for that PartyCombatant before any damage is computed

#### Scenario: Defend command emits actor_action_started with kind "defend"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted a `Defend` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"defend")` for that PartyCombatant

#### Scenario: Cast command emits actor_action_started with kind "cast"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted a `Cast` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"cast")` for that PartyCombatant before MP is spent

#### Scenario: Item command emits actor_action_started with kind "item"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted an `Item` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"item")` for that PartyCombatant

#### Scenario: Escape command emits actor_action_started with kind "escape"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted an `Escape` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"escape")` for that PartyCombatant

#### Scenario: Dead actors are not signaled

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant whose `is_alive() == false` would have a command in `_pending_commands`
- **THEN** `actor_action_started` SHALL NOT fire for that PartyCombatant

### Requirement: TurnEngine emits actor_dealt_damage when a target takes damage

`TurnEngine` SHALL define a signal `actor_dealt_damage(target: CombatActor, amount: int, source: CombatActor)` and SHALL emit it whenever a `take_damage` call within `resolve_turn(rng)` actually reduces a target's HP. The signal SHALL fire once per target per damage application. The `amount` SHALL be the actual HP reduction applied to the target (after defense halving etc.).

#### Scenario: Attack hit emits actor_dealt_damage

- **WHEN** an attack from actor A hits actor B for 5 HP and B's HP is reduced from 10 to 5
- **THEN** `actor_dealt_damage` SHALL fire once with `(B, 5, A)`

#### Scenario: Attack miss does not emit actor_dealt_damage

- **WHEN** an attack from actor A misses actor B
- **THEN** `actor_dealt_damage` SHALL NOT fire for that miss

#### Scenario: Defend halving reduces the emitted amount

- **WHEN** an actor B is defending and takes a hit that would deal 8 damage at full, but actually applies 4
- **THEN** `actor_dealt_damage` SHALL fire with `amount = 4`

### Requirement: TurnEngine emits actor_healed when a target receives healing

`TurnEngine` SHALL define a signal `actor_healed(target: CombatActor, amount: int, source: CombatActor)` and SHALL emit it whenever a heal effect within `resolve_turn(rng)` actually increases a target's HP. The signal SHALL fire once per target per heal application. The `amount` SHALL be the actual HP gain applied (capped at `max_hp - prev_hp`).

#### Scenario: Heal spell on a damaged target emits actor_healed

- **WHEN** caster A casts a healing spell on target B with `current_hp = 5`, `max_hp = 20`, restoring 7 HP, and B's HP becomes 12
- **THEN** `actor_healed` SHALL fire once with `(B, 7, A)`

#### Scenario: Heal capped at max_hp emits actual delta

- **WHEN** caster A casts heal on target B with `current_hp = 18`, `max_hp = 20`, restoring 5 HP nominally, but actual gain is 2 (capped)
- **THEN** `actor_healed` SHALL fire with `amount = 2`

#### Scenario: Heal on a target already at max does not emit

- **WHEN** caster A casts heal on target B with `current_hp = 20` and `max_hp = 20` (no actual gain)
- **THEN** `actor_healed` SHALL NOT fire

### Requirement: TurnEngine emits actor_died when an actor's HP reaches zero

`TurnEngine` SHALL define a signal `actor_died(actor: CombatActor)` and SHALL emit it once when an actor's `is_alive()` transitions from `true` to `false` during `resolve_turn(rng)`, regardless of cause (damage, status tick, etc.).

#### Scenario: Damage that kills emits actor_died

- **WHEN** a hit reduces target B's HP from 3 to 0
- **THEN** `actor_died` SHALL fire once with `(B,)` after `actor_dealt_damage` for the same hit

#### Scenario: Status tick that kills emits actor_died

- **WHEN** a poison battle tick reduces target B's HP from 1 to 0
- **THEN** `actor_died` SHALL fire once with `(B,)`

#### Scenario: Already-dead actors do not emit actor_died

- **WHEN** an actor is already dead at the start of `resolve_turn(rng)` and remains dead
- **THEN** `actor_died` SHALL NOT fire for that actor in this turn

### Requirement: TurnEngine emits actor_status_inflicted when a new status is applied

`TurnEngine` SHALL define a signal `actor_status_inflicted(actor: CombatActor, status_id: StringName)` and SHALL emit it whenever a status effect is applied to an actor that did NOT already have that status active during `resolve_turn(rng)`. Re-applying an already-active status SHALL NOT emit.

#### Scenario: Sleep inflicted on a non-sleeping actor

- **WHEN** a sleep-inducing spell hits actor B who has no sleep status, and sleep is applied
- **THEN** `actor_status_inflicted` SHALL fire with `(B, &"sleep")`

#### Scenario: Already-inflicted status is not re-emitted

- **WHEN** actor B already has `&"poison"` and a poison-inflicting attack lands again on B
- **THEN** `actor_status_inflicted` SHALL NOT fire (no transition)

### Requirement: TurnEngine emits actor_spent_mp when a cast consumes MP

`TurnEngine` SHALL define a signal `actor_spent_mp(actor: CombatActor, cost: int)` and SHALL emit it inside `resolve_turn(rng)` immediately after a `caster.spend_mp(spell.mp_cost)` call returns `true` during cast resolution. The signal SHALL fire exactly once per successful cast where MP was actually deducted, and the `cost` value SHALL equal the MP amount that was deducted (i.e. the spell's `mp_cost`).

The signal SHALL NOT fire in any of the following cases:
- The caster has the silence flag and the cast is recorded via `add_cast_silenced`.
- The cast is skipped via `add_cast_skipped_no_target` because no valid target exists.
- The cast is skipped via `add_cast_skipped_no_mp` because `spend_mp` returned `false`.
- The spell's `mp_cost` is `0`, so no MP is actually deducted.

The emission SHALL occur **before** the corresponding `report.add_cast(...)` call so that subscribers reading `get_pending_action_index()` at emission time see an index equal to the position where the cast log entry will land.

#### Scenario: Successful cast emits actor_spent_mp before add_cast
- **WHEN** caster A successfully casts a spell with `mp_cost = 4` and `spend_mp(4)` returns `true`
- **THEN** `actor_spent_mp` SHALL fire exactly once with `(A, 4)`
- **AND** the emission SHALL occur before the cast is appended to the TurnReport
- **AND** at emission time `TurnEngine.get_pending_action_index()` SHALL equal the index where the cast log entry will be appended

#### Scenario: Silenced cast does not emit actor_spent_mp
- **WHEN** caster A has the silence flag and submits a CastCommand
- **THEN** `actor_spent_mp` SHALL NOT fire and `spend_mp` SHALL NOT be called

#### Scenario: Cast skipped due to no valid target does not emit actor_spent_mp
- **WHEN** caster A submits a CastCommand whose target is dead and no replacement exists
- **THEN** `actor_spent_mp` SHALL NOT fire and `spend_mp` SHALL NOT be called

#### Scenario: Cast skipped due to insufficient MP does not emit actor_spent_mp
- **WHEN** caster A submits a CastCommand whose `mp_cost` exceeds `current_mp`, so `spend_mp` returns `false`
- **THEN** `actor_spent_mp` SHALL NOT fire (no successful deduction occurred)

#### Scenario: Zero-cost spell does not emit actor_spent_mp
- **WHEN** caster A successfully casts a spell with `mp_cost = 0`
- **THEN** `actor_spent_mp` SHALL NOT fire (no MP was actually deducted)

### Requirement: TurnEngine supports withdrawing a previously submitted command

`TurnEngine` SHALL provide a method `withdraw_command(party_index: int) -> void` that removes any previously submitted command for the given party index from `_pending_commands`. The method SHALL only mutate state when `state == State.COMMAND_INPUT`; in any other state the call SHALL be a no-op. The method SHALL NOT touch combatant HP, MP, inventory, or any other side-effectful state, and SHALL NOT emit any signal. Calling `withdraw_command` for an index that has no pending command SHALL be a safe no-op.

After a successful withdraw, `are_party_commands_complete()` SHALL reflect the removal — i.e. if the withdrawn command was the only missing-or-present blocker, completeness SHALL become `false`.

#### Scenario: Withdraw removes a previously submitted command

- **WHEN** `submit_command(0, AttackCommand.new(target))` is called and then `withdraw_command(0)` is called while `state == COMMAND_INPUT`
- **THEN** `_pending_commands` SHALL NOT contain the key `0`
- **AND** a subsequent call to `are_party_commands_complete()` SHALL return `false` (assuming index 0 corresponds to a living member)

#### Scenario: Withdraw outside COMMAND_INPUT is a no-op

- **WHEN** `withdraw_command(0)` is called while `state == State.RESOLVING` or `state == State.FINISHED`
- **THEN** `_pending_commands` SHALL be unchanged

#### Scenario: Withdraw on an index without a pending command is a safe no-op

- **WHEN** `withdraw_command(2)` is called and `_pending_commands` does not contain key `2`
- **THEN** the call SHALL not raise and `_pending_commands` SHALL be unchanged

#### Scenario: Withdraw does not produce side effects

- **WHEN** a PartyCombatant submits a `CastCommand` (mp_cost > 0) via `submit_command`, and then `withdraw_command` is called for that index before `resolve_turn` is invoked
- **THEN** the caster's `current_mp` SHALL be unchanged
- **AND** no `actor_action_started`, `actor_spent_mp`, or related signal SHALL have been emitted as a result of the submit/withdraw pair

### Requirement: TurnEngine exposes effective_row computed from current side liveness

The system SHALL provide `TurnEngine.effective_row(actor: CombatActor) -> Row` returning:

- `Row.FRONT` if `actor.original_row == Row.FRONT`.
- `Row.BACK` if `actor.original_row == Row.BACK` AND at least one same-side actor exists with `original_row == Row.FRONT` AND that FRONT actor `is_alive() == true` (no promotion needed).
- `Row.FRONT` if `actor.original_row == Row.BACK` AND no same-side living FRONT actor exists (promotion case).

"Same side" SHALL be determined by membership in the engine's `party` array (party side) or `monsters` array (monster side).

The function SHALL evaluate the current state at call time. The result SHALL NOT be cached for the duration of a turn — repeated calls within `resolve_turn` MAY return different values as combatants die.

#### Scenario: FRONT-row actor stays FRONT
- **WHEN** an actor whose `original_row == Row.FRONT` is queried via `effective_row`
- **THEN** the result SHALL be `Row.FRONT` regardless of liveness of others

#### Scenario: BACK-row actor stays BACK while a same-side FRONT lives
- **WHEN** a BACK-row party member is queried while at least one FRONT-row party member is alive
- **THEN** `effective_row` SHALL return `Row.BACK`

#### Scenario: BACK-row actor promotes to FRONT after all same-side FRONT die
- **WHEN** a BACK-row party member is queried after every FRONT-row party member has `is_alive() == false`
- **THEN** `effective_row` SHALL return `Row.FRONT`

#### Scenario: Promotion rule applies to monsters identically
- **WHEN** a BACK-row monster is queried after every FRONT-row monster in the same `monsters` array has died
- **THEN** `effective_row` SHALL return `Row.FRONT`

#### Scenario: Mid-turn re-evaluation reflects intra-turn deaths
- **WHEN** during a single `resolve_turn`, a FRONT-row party member dies at action index N, and `effective_row` is called for a BACK-row party member at action index N+1
- **THEN** the call at N+1 SHALL return `Row.FRONT` (promotion is observed mid-turn)

### Requirement: TurnEngine exposes can_reach for attack reachability

The system SHALL provide `TurnEngine.can_reach(attacker: CombatActor, target: CombatActor) -> bool` returning:

- `true` if `weapon_range_of(attacker) == WeaponRange.RANGED`.
- `true` if `weapon_range_of(attacker) == WeaponRange.MELEE` AND `effective_row(attacker) == Row.FRONT` AND `effective_row(target) == Row.FRONT`.
- `false` otherwise.

`weapon_range_of(attacker)` SHALL be:
- For a `PartyCombatant`: the value returned by `attacker.equipment_provider.get_weapon_range(attacker.character)`.
- For a `MonsterCombatant`: `attacker.monster.data.attack_range`.
- Fallback for either: `WeaponRange.MELEE` when no source resolves.

#### Scenario: RANGED attacker reaches any target
- **WHEN** `can_reach(attacker, target)` is called with `weapon_range_of(attacker) == RANGED`
- **THEN** the result SHALL be `true` regardless of either side's row

#### Scenario: MELEE FRONT vs FRONT reaches
- **WHEN** a MELEE attacker with `effective_row == FRONT` queries reach against a target with `effective_row == FRONT`
- **THEN** the result SHALL be `true`

#### Scenario: MELEE FRONT vs BACK does not reach
- **WHEN** a MELEE attacker with `effective_row == FRONT` queries reach against a target with `effective_row == BACK`
- **THEN** the result SHALL be `false`

#### Scenario: MELEE BACK vs anything does not reach
- **WHEN** a MELEE attacker with `effective_row == BACK` queries reach against any target
- **THEN** the result SHALL be `false`

#### Scenario: MELEE BACK promoted to FRONT can reach FRONT
- **WHEN** a MELEE attacker whose `original_row == BACK` queries reach AFTER same-side FRONT members are all dead, against a target with `effective_row == FRONT`
- **THEN** the result SHALL be `true` (the attacker's `effective_row` is now FRONT)

### Requirement: AttackCommand resolution gates on can_reach as a defense-in-depth check

`TurnEngine._resolve_attack` SHALL, before calling `DamageCalculator.calculate`, evaluate `can_reach(attacker, effective_target)`. When the check fails:

- The attack SHALL NOT roll for hit or damage.
- The attack SHALL NOT mutate target HP.
- A `TurnReport` action of `type == "attack_unreachable"` SHALL be appended with at minimum `{ type, attacker_name, target_name }`. (UI rendering: "<attacker> の攻撃は届かなかった" or equivalent.)

The UI is expected to prevent unreachable attacks from being submitted (CombatCommandMenu disable + CombatTargetSelector gray-out), but this engine-side gate exists so that direct API calls or debug-console submissions cannot bypass the rule.

The `attack_unreachable` action SHALL also have a corresponding `add_attack_unreachable(attacker, target)` method on `TurnReport`.

#### Scenario: Reachable MELEE attack proceeds normally
- **WHEN** a MELEE attacker FRONT vs FRONT submits AttackCommand and reach passes
- **THEN** `DamageCalculator.calculate` SHALL be invoked and a normal `attack` or `miss` log entry SHALL be appended

#### Scenario: Unreachable attack is blocked at engine level
- **WHEN** a MELEE attacker submits AttackCommand against a target where `can_reach` returns false (e.g., direct API call bypassing UI)
- **THEN** target HP SHALL NOT change, no hit roll SHALL occur, and the report SHALL contain a single `attack_unreachable` action entry naming attacker and target

#### Scenario: TurnReport.add_attack_unreachable produces the documented entry
- **WHEN** `report.add_attack_unreachable(attacker, target)` is called with `attacker.actor_name = "Bob"` and `target.actor_name = "Witch"`
- **THEN** the appended entry SHALL equal `{ type: "attack_unreachable", attacker_name: "Bob", target_name: "Witch" }`

### Requirement: Monster AI selects targets from the reachable subset

The system SHALL replace the existing `_pick_living_party(rng)` call site for monster attack resolution with a reachable-aware variant. For each acting `MonsterCombatant`:

1. Compute the candidate target set as living party members `p` such that `can_reach(monster, p) == true`.
2. If the set is non-empty, choose one uniformly at random using the injected RNG.
3. If the set is empty (no reachable target):
   - If the monster's `attack_range == MELEE` and at least one party member is still alive, the monster SHALL fall through to the "wait" branch (see next requirement).
   - If no party member is alive at all, the monster SHALL skip its action (existing behavior preserved).

The deterministic-tiebreak property SHALL be preserved: identical RNG seed and identical reachable set SHALL produce identical target selection.

#### Scenario: MELEE monster picks only from FRONT party while FRONT lives
- **WHEN** a MELEE monster's reachable-target computation runs with party `[FrontFighter (alive), BackMage (alive)]`
- **THEN** only FrontFighter SHALL be a candidate; BackMage SHALL NOT

#### Scenario: MELEE monster targets promoted BACK after FRONT dies
- **WHEN** a MELEE monster's reachable-target computation runs after FrontFighter died and only BackMage remains alive
- **THEN** BackMage SHALL be the candidate (BackMage's `effective_row` is now FRONT)

#### Scenario: RANGED monster targets any living party member
- **WHEN** a RANGED monster's reachable-target computation runs with a mixed-row living party
- **THEN** every living party member SHALL be a candidate

### Requirement: Back-row MELEE monster waits when no reachable target exists

The system SHALL, when an acting `MonsterCombatant` has `attack_range == MELEE` AND its reachable-target set is empty AND at least one party member is still alive, treat the monster's turn as a "wait" action:

1. Emit `actor_action_started.emit(monster, &"wait")`.
2. Append a `TurnReport` action of `type == "wait"` with `{ type, actor_name }` via `TurnReport.add_wait(monster)`.
3. Skip damage rolls and HP mutation.
4. Apply NO defensive bonus (the monster is NOT in defending posture; subsequent damage is taken at full).
5. End the monster's turn.

Status tick handling at turn boundaries SHALL be unchanged — the wait branch only short-circuits the attack action, not the engine's normal end-of-turn cleanup.

#### Scenario: Back-row MELEE monster waits while FRONT party blocks
- **WHEN** a BACK-row MELEE monster's turn arrives with FRONT-row party members alive
- **THEN** the engine SHALL emit `actor_action_started(monster, &"wait")`, append a `wait` report entry, and SHALL NOT roll damage

#### Scenario: Wait does not grant damage halving
- **WHEN** a monster has waited this turn and is then attacked
- **THEN** the incoming damage SHALL be at full value (no defending posture is applied by wait)

#### Scenario: Wait does not interrupt status ticks
- **WHEN** a monster with an active poison-style tick effect waits
- **THEN** the tick SHALL still be applied during the engine's per-turn tick pass (the wait branch only affects the action loop)

### Requirement: TurnReport supports the wait action type

`TurnReport` SHALL provide `add_wait(actor: CombatActor)` that appends an action of shape `{ type: "wait", actor_name: String }`. Existing TurnReport entries SHALL be unaffected.

#### Scenario: add_wait produces the documented entry
- **WHEN** `report.add_wait(actor)` is called with `actor.actor_name = "Bat"`
- **THEN** the appended entry SHALL equal `{ type: "wait", actor_name: "Bat" }`

