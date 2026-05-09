# combat-input-router Specification

## Purpose
TBD - created by archiving change refactor-combat-overlay. Update Purpose after archive.
## Requirements
### Requirement: CombatInputRouter dispatches per-phase input to combat panels
SHALL: `CombatInputRouter` (RefCounted) SHALL provide a static method `route(event: InputEvent, phase: CombatOverlay.Phase, panels: Dictionary) -> bool` that dispatches the input event to the panel responsible for the given phase. The `panels` Dictionary SHALL include keys `command_menu`, `target_selector`, `item_selector` (or null when ItemUseFlow handles items), `result_panel`. The method SHALL return `true` if the event was handled. The router SHALL NOT call `set_input_as_handled` itself.

#### Scenario: COMMAND_MENU phase routes to command_menu panel
- **WHEN** `route(ui_down, Phase.COMMAND_MENU, panels)` is called
- **THEN** `panels.command_menu.move_down()` SHALL be invoked and the method SHALL return `true`

#### Scenario: TARGET_SELECT phase routes to target_selector panel
- **WHEN** `route(ui_accept, Phase.TARGET_SELECT, panels)` is called
- **THEN** `panels.target_selector` SHALL receive an accept-equivalent action and the method SHALL return `true`

#### Scenario: ITEM_TARGET phase routes to target_selector panel (same as TARGET_SELECT)
- **WHEN** `route(ui_up, Phase.ITEM_TARGET, panels)` is called
- **THEN** `panels.target_selector.move_up()` SHALL be invoked

#### Scenario: ITEM_SELECT phase is not routed by CombatInputRouter
- **WHEN** `route(any_event, Phase.ITEM_SELECT, panels)` is called
- **THEN** the method SHALL return `false` (because ItemUseFlow handles ITEM_SELECT itself)

#### Scenario: RESULT phase routes to result_panel
- **WHEN** `route(ui_accept, Phase.RESULT, panels)` is called
- **THEN** the result panel SHALL receive a confirm-equivalent action and the method SHALL return `true`

#### Scenario: IDLE / RESOLVING phases consume nothing
- **WHEN** `route(any_event, Phase.IDLE, panels)` or `route(any_event, Phase.RESOLVING, panels)` is called
- **THEN** the method SHALL return `false`

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

