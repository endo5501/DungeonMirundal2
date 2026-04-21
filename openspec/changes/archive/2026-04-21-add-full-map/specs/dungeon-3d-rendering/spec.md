## ADDED Requirements

### Requirement: DungeonScreen toggles the FullMapOverlay with the M key
DungeonScreen SHALL listen for the M key in `_unhandled_input` and SHALL toggle the visibility of `FullMapOverlay` on key press. The M key SHALL be ignored when an encounter is active or when the return-to-town dialog is visible.

#### Scenario: M key opens the overlay when closed
- **WHEN** DungeonScreen is active (no encounter, no return dialog) and the overlay is hidden, and the user presses the M key
- **THEN** `FullMapOverlay.open()` SHALL be invoked and the overlay SHALL become visible

#### Scenario: M key closes the overlay when open
- **WHEN** the overlay is visible and the user presses the M key
- **THEN** `FullMapOverlay.close()` SHALL be invoked and the overlay SHALL become hidden

#### Scenario: M key is ignored during encounter
- **WHEN** DungeonScreen has `_encounter_active == true` and the user presses the M key
- **THEN** the overlay SHALL NOT change state (remains hidden if it was hidden)

#### Scenario: M key is ignored during return dialog
- **WHEN** DungeonScreen has `_showing_return_dialog == true` and the user presses the M key
- **THEN** the overlay SHALL NOT change state

#### Scenario: M key echo events are ignored
- **WHEN** an M key event with `event.echo == true` is received
- **THEN** the overlay SHALL NOT toggle (only the initial press counts)

### Requirement: DungeonScreen blocks movement input while the FullMapOverlay is visible
DungeonScreen SHALL ignore movement and turn key inputs (UP/W, DOWN/S, LEFT/A, RIGHT/D) while `FullMapOverlay.is_open() == true`. This SHALL prevent the player from moving or rotating while inspecting the full map.

#### Scenario: Movement key does not move the player while overlay is visible
- **WHEN** the overlay is visible and the user presses the UP key
- **THEN** the player position SHALL NOT change and DungeonScene SHALL NOT rebuild

#### Scenario: Turn key does not rotate the player while overlay is visible
- **WHEN** the overlay is visible and the user presses the LEFT key
- **THEN** the player facing SHALL NOT change and the minimap SHALL NOT refresh (it is hidden anyway)

#### Scenario: Movement is restored after the overlay closes
- **WHEN** the overlay is closed and the user presses the UP key
- **THEN** the player SHALL move forward as normal (input handling resumes)
