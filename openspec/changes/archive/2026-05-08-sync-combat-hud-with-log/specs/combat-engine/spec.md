## ADDED Requirements

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
