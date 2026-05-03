## MODIFIED Requirements

### Requirement: FullMapOverlay closes on ESC and consumes the input
FullMapOverlay SHALL listen for `is_action_pressed("ui_cancel")` (the InputMap action bound to KEY_ESCAPE) in `_unhandled_input` and SHALL invoke `close()` and `get_viewport().set_input_as_handled()` so that the ESC press does NOT propagate to `main.gd` and open the ESC menu.

#### Scenario: ui_cancel action closes the overlay without opening ESC menu
- **WHEN** the FullMapOverlay is visible and `is_action_pressed("ui_cancel")` is dispatched
- **THEN** `FullMapOverlay.close()` SHALL be invoked, the overlay SHALL become hidden, and `set_input_as_handled()` SHALL be called preventing main.gd from opening the ESC menu

#### Scenario: Other actions do not close the overlay
- **WHEN** the overlay is visible and an action other than `ui_cancel` (e.g., `move_forward`, `ui_accept`) is dispatched
- **THEN** the overlay SHALL remain visible
