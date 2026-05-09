## ADDED Requirements

### Requirement: COMMAND_MENU phase ui_cancel steps back to the previous living actor

While the CombatOverlay is in `Phase.COMMAND_MENU` collecting a command for the current acting `PartyCombatant`, pressing `ui_cancel` SHALL cause the overlay to step back to the most recent prior **living** PartyCombatant in Guild order, and SHALL withdraw any command previously submitted for that prior actor by calling `TurnEngine.withdraw_command(prior_index)`. The overlay SHALL then re-display the command menu for the prior actor by calling `_command_menu.show_for(party[prior_index])`. Dead members SHALL be skipped during the backward search using the same liveness rule that the forward path uses.

If no prior living actor exists (the current actor is the first living member of the party), `ui_cancel` SHALL be a no-op: no withdraw, no panel mutation, no phase change.

When the step-back occurs, the overlay SHALL defensively hide any active sub-panel (`target_selector`, `spell_selector`, `item_use_flow`) before re-showing the prior actor's command menu. The overlay's `_current_phase` SHALL remain `Phase.COMMAND_MENU` after the step-back.

The step-back SHALL NOT call `submit_command` for the new current actor (the menu is opened fresh) and SHALL NOT have any effect on combatant HP, MP, inventory, or signals.

#### Scenario: Cancel from second member returns to first

- **WHEN** the first living member submits a command and the overlay advances to the second living member's `COMMAND_MENU`, then `ui_cancel` is pressed
- **THEN** the second member's pending command is unchanged (none was submitted yet) and the first member's pending command SHALL be withdrawn from `_pending_commands`
- **AND** the command menu SHALL be re-shown for the first member
- **AND** `_current_actor_index` SHALL refer to the first member

#### Scenario: Repeated cancel walks back through the party

- **WHEN** members A, B, C have all submitted commands and the overlay is now collecting D's command, and `ui_cancel` is pressed three times in succession
- **THEN** after the first press the overlay is on C with C's command withdrawn
- **AND** after the second press the overlay is on B with B's command withdrawn
- **AND** after the third press the overlay is on A with A's command withdrawn

#### Scenario: Cancel skips dead members on the way back

- **WHEN** the party is `[A(alive), B(dead), C(alive), D(alive)]`, A and C have submitted commands, and the overlay is collecting D's command, then `ui_cancel` is pressed
- **THEN** the overlay SHALL step back to C (skipping no one — C is the immediate predecessor)
- **WHEN** `ui_cancel` is pressed again while collecting C's command (after step-back removed C's command)
- **THEN** the overlay SHALL step back past dead member B and land on A, with A's previously-submitted command withdrawn

#### Scenario: Cancel on the first living member is a no-op

- **WHEN** the overlay is on the first living member's `COMMAND_MENU` and `ui_cancel` is pressed
- **THEN** `_pending_commands` SHALL be unchanged
- **AND** `_current_actor_index` SHALL be unchanged
- **AND** `_current_phase` SHALL still be `Phase.COMMAND_MENU`

#### Scenario: Step-back hides any leftover sub-panels

- **WHEN** `ui_cancel` triggers a step-back and a sub-panel (e.g. `target_selector`) is somehow still visible
- **THEN** the sub-panel SHALL be hidden before the prior actor's command menu is shown


### Requirement: TARGET_SELECT phase ui_cancel returns to the same actor's COMMAND_MENU without submitting

While the CombatOverlay is in `Phase.TARGET_SELECT` (attack target selection, entered from the `Attack` command), pressing `ui_cancel` SHALL hide the target selector and re-display the command menu for the **same** actor (`_current_actor_index` is unchanged), with `_current_phase` set back to `Phase.COMMAND_MENU`. The overlay SHALL NOT call `TurnEngine.submit_command` for this cancellation, and SHALL NOT advance to the next actor.

This SHALL NOT affect the existing `Phase.SPELL_TARGET` cancel behavior (which returns to `Phase.SPELL_SELECT`).

#### Scenario: Attack target cancel returns to command menu

- **WHEN** an actor selects "Attack" from the command menu and the overlay enters `Phase.TARGET_SELECT`, then `ui_cancel` is pressed
- **THEN** the target selector SHALL be hidden
- **AND** `_current_phase` SHALL be `Phase.COMMAND_MENU`
- **AND** the command menu SHALL be re-shown for the same actor (`_current_actor_index` unchanged)
- **AND** `_pending_commands` SHALL NOT contain a new entry for this actor

#### Scenario: Spell target cancel still returns to spell selector

- **WHEN** an actor selects a Cast spell, the overlay enters `Phase.SPELL_TARGET`, and `ui_cancel` is pressed
- **THEN** the overlay SHALL return to `Phase.SPELL_SELECT` (existing behavior preserved)
- **AND** `_current_phase` SHALL NOT be `Phase.COMMAND_MENU`


### Requirement: CombatOverlay exposes request_undo_actor for router-driven cancel

`CombatOverlay` SHALL expose a public method `request_undo_actor() -> void` that performs the COMMAND_MENU step-back described above. The method SHALL be safe to call regardless of whether a step-back target exists; when no prior living actor is available it SHALL be a no-op.

This method exists so that `CombatInputRouter` can deliver the COMMAND_MENU `ui_cancel` event to the overlay without the router needing to know about multi-actor state.

#### Scenario: request_undo_actor on an idle overlay is a no-op

- **WHEN** `request_undo_actor()` is called and `_current_phase != Phase.COMMAND_MENU`
- **THEN** the call SHALL be a safe no-op (no withdraw, no panel mutation)

#### Scenario: request_undo_actor performs the documented step-back

- **WHEN** `request_undo_actor()` is called while in `Phase.COMMAND_MENU` with a valid prior living actor
- **THEN** the prior actor's command SHALL be withdrawn and the prior actor's command menu SHALL be shown, equivalent to the COMMAND_MENU `ui_cancel` requirement above
