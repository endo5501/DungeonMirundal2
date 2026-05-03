## MODIFIED Requirements

### Requirement: DungeonScreen toggles the FullMapOverlay with the toggle_full_map action
DungeonScreen SHALL listen for `is_action_pressed("toggle_full_map")` in `_unhandled_input` and SHALL toggle the visibility of `FullMapOverlay` on action press. The action SHALL be ignored when an encounter is active or when the return-to-town dialog is visible.

#### Scenario: toggle_full_map opens the overlay when closed
- **WHEN** DungeonScreen is active (no encounter, no return dialog) and the overlay is hidden, and an event matching `is_action_pressed("toggle_full_map")` is dispatched
- **THEN** `FullMapOverlay.open()` SHALL be invoked and the overlay SHALL become visible

#### Scenario: toggle_full_map closes the overlay when open
- **WHEN** the overlay is visible and `is_action_pressed("toggle_full_map")` is dispatched
- **THEN** `FullMapOverlay.close()` SHALL be invoked and the overlay SHALL become hidden

#### Scenario: toggle_full_map is ignored during encounter
- **WHEN** DungeonScreen has `_encounter_active == true` and `is_action_pressed("toggle_full_map")` is dispatched
- **THEN** the overlay SHALL NOT change state

#### Scenario: toggle_full_map is ignored during return dialog
- **WHEN** DungeonScreen has `_showing_return_dialog == true` and `is_action_pressed("toggle_full_map")` is dispatched
- **THEN** the overlay SHALL NOT change state

#### Scenario: Echo events are ignored
- **WHEN** an action event with `event.echo == true` is received
- **THEN** the overlay SHALL NOT toggle (only the initial press counts; this is the InputMap's default behavior for non-pressed/echo events)

### Requirement: DungeonScreen blocks movement input while the FullMapOverlay is visible
DungeonScreen SHALL ignore movement and turn actions (`move_forward`, `move_back`, `strafe_left`, `strafe_right`, `turn_left`, `turn_right`) while `FullMapOverlay.is_open() == true`.

#### Scenario: move_forward action does not move the player while overlay is visible
- **WHEN** the overlay is visible and `is_action_pressed("move_forward")` is dispatched
- **THEN** the player position SHALL NOT change and DungeonScene SHALL NOT rebuild

#### Scenario: turn_left action does not rotate the player while overlay is visible
- **WHEN** the overlay is visible and `is_action_pressed("turn_left")` is dispatched
- **THEN** the player facing SHALL NOT change

#### Scenario: Movement is restored after the overlay closes
- **WHEN** the overlay is closed and `is_action_pressed("move_forward")` is dispatched
- **THEN** the player SHALL move forward as normal (input handling resumes)
