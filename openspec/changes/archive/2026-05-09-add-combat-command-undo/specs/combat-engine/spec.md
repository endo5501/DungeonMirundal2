## ADDED Requirements

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
