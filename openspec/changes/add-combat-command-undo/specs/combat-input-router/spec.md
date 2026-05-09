## ADDED Requirements

### Requirement: COMMAND_MENU phase routes ui_cancel to overlay.request_undo_actor

`CombatInputRouter.route` SHALL, when `phase == CombatOverlay.Phase.COMMAND_MENU` and the event is `ui_cancel`, invoke `panels.overlay.request_undo_actor()` and SHALL return `true`. The `panels` Dictionary SHALL therefore include an `overlay` key referencing the active CombatOverlay (or an object that responds to `request_undo_actor`).

For all other events under `COMMAND_MENU`, routing SHALL continue to dispatch to `panels.command_menu` as previously specified (movement / accept).

The router SHALL NOT itself decide what step-back means; it SHALL only deliver the event to the overlay's `request_undo_actor` hook.

#### Scenario: ui_cancel under COMMAND_MENU calls overlay.request_undo_actor

- **WHEN** `route(ui_cancel_event, Phase.COMMAND_MENU, panels)` is called and `panels.overlay` is a non-null object with a `request_undo_actor` method
- **THEN** `panels.overlay.request_undo_actor()` SHALL be invoked exactly once and the method SHALL return `true`

#### Scenario: ui_cancel under COMMAND_MENU is a no-op when overlay key is missing

- **WHEN** `route(ui_cancel_event, Phase.COMMAND_MENU, panels)` is called and `panels.overlay` is null or absent
- **THEN** the method SHALL return `false` and SHALL NOT raise

#### Scenario: Non-cancel events under COMMAND_MENU still go to command_menu

- **WHEN** `route(ui_down_event, Phase.COMMAND_MENU, panels)` is called
- **THEN** `panels.command_menu.move_down()` SHALL be invoked (existing behavior preserved) and `panels.overlay.request_undo_actor` SHALL NOT be called


### Requirement: TARGET_SELECT phase routes ui_cancel via the cancellable path

`CombatInputRouter.route` SHALL, when `phase == CombatOverlay.Phase.TARGET_SELECT`, dispatch the event through the cancellable routing path so that `ui_cancel` triggers `panels.target_selector.request_cancel()`. Other events (movement, accept) SHALL continue to be routed to `panels.target_selector` as before.

This brings TARGET_SELECT in line with `SPELL_TARGET` and `SPELL_SELECT` for cancel handling. The actual phase transition on cancel is the CombatOverlay's responsibility (driven by the existing `cancelled` signal from the target selector).

#### Scenario: ui_cancel under TARGET_SELECT calls target_selector.request_cancel

- **WHEN** `route(ui_cancel_event, Phase.TARGET_SELECT, panels)` is called and `panels.target_selector` is non-null
- **THEN** `panels.target_selector.request_cancel()` SHALL be invoked exactly once and the method SHALL return `true`

#### Scenario: Non-cancel events under TARGET_SELECT continue to dispatch normally

- **WHEN** `route(ui_up_event, Phase.TARGET_SELECT, panels)` is called
- **THEN** `panels.target_selector.move_up()` SHALL be invoked (existing behavior preserved)

#### Scenario: SPELL_TARGET cancel routing is unaffected

- **WHEN** `route(ui_cancel_event, Phase.SPELL_TARGET, panels)` is called
- **THEN** `panels.target_selector.request_cancel()` SHALL be invoked exactly once (existing behavior preserved)
