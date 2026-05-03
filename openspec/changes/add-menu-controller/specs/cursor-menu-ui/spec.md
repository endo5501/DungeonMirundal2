## ADDED Requirements

### Requirement: MenuController routes standard menu actions to CursorMenu
The system SHALL provide a `MenuController` (RefCounted) class with a static method `route(event, menu, rows, on_accept, on_back, on_cursor_changed) -> bool` that routes the four standard menu input actions (`ui_up`, `ui_down`, `ui_accept`, `ui_cancel`) into operations on a `CursorMenu` and `Array[CursorMenuRow]`. The method SHALL return `true` if the event was consumed (matched and dispatched), `false` otherwise. Callers SHALL be responsible for calling `get_viewport().set_input_as_handled()` based on the return value.

#### Scenario: ui_down moves cursor forward and updates rows
- **WHEN** `route(event_ui_down, menu, rows, on_accept)` is called with `event_ui_down` matching `is_action_pressed("ui_down")`
- **THEN** `menu.move_cursor(1)` SHALL be invoked, `menu.update_rows(rows)` SHALL be invoked, and the method SHALL return `true`

#### Scenario: ui_up moves cursor backward and updates rows
- **WHEN** `route(event_ui_up, menu, rows, on_accept)` is called
- **THEN** `menu.move_cursor(-1)` SHALL be invoked, `menu.update_rows(rows)` SHALL be invoked, and the method SHALL return `true`

#### Scenario: ui_accept invokes the accept callback
- **WHEN** `route(event_ui_accept, menu, rows, on_accept)` is called and `on_accept` is a valid `Callable`
- **THEN** `on_accept.call()` SHALL be invoked exactly once and the method SHALL return `true`

#### Scenario: ui_cancel invokes the back callback when registered
- **WHEN** `route(event_ui_cancel, menu, rows, on_accept, on_back)` is called and `on_back` is a valid `Callable`
- **THEN** `on_back.call()` SHALL be invoked exactly once and the method SHALL return `true`

#### Scenario: ui_cancel is ignored when back callback is not registered
- **WHEN** `route(event_ui_cancel, menu, rows, on_accept)` is called with no `on_back` (default `Callable()`)
- **THEN** no callback SHALL be invoked and the method SHALL return `false`

#### Scenario: on_cursor_changed fires after move_cursor when registered
- **WHEN** `route(event_ui_down, menu, rows, on_accept, on_back, on_cursor_changed)` is called and `on_cursor_changed` is valid
- **THEN** `on_cursor_changed.call()` SHALL be invoked exactly once after `menu.update_rows(rows)`

#### Scenario: Unrecognized event returns false
- **WHEN** `route(some_other_event, menu, rows, on_accept)` is called with an event that is none of ui_up/ui_down/ui_accept/ui_cancel
- **THEN** no callback SHALL be invoked, no method SHALL be invoked on `menu`, and the method SHALL return `false`

### Requirement: MenuController uses action-based input convention
SHALL: `MenuController.route` MUST use `event.is_action_pressed(action_name)` for matching, NOT keycode comparison. The four standard actions SHALL be `ui_up`, `ui_down`, `ui_accept`, `ui_cancel` as defined in `project.godot`.

#### Scenario: keycode-based events trigger only via their bound actions
- **WHEN** a KEY_W InputEventKey is dispatched and `ui_up` is bound to KEY_W in InputMap
- **THEN** `MenuController.route` SHALL detect it via `is_action_pressed("ui_up")` and route as ui_up

#### Scenario: events not bound to a menu action are ignored
- **WHEN** a key event is received that does not match any of the four ui_ actions
- **THEN** the method SHALL return `false`

### Requirement: MenuController does not call set_input_as_handled
The `route` method SHALL NOT call `get_viewport().set_input_as_handled()` itself. The caller SHALL inspect the boolean return value and call it if appropriate. This SHALL keep `MenuController` viewport-independent and unit-testable.

#### Scenario: route does not consume input via the viewport
- **WHEN** `MenuController.route(event_ui_down, menu, rows, on_accept)` is invoked outside a SceneTree context
- **THEN** the method SHALL complete without throwing or accessing `get_viewport()`
