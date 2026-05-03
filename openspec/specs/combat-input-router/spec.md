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

