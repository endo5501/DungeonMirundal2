# full-map-overlay Specification

## Purpose
TBD - created by archiving change add-full-map. Update Purpose after archive.
## Requirements
### Requirement: FullMapOverlay is a full-rect Control overlay added to DungeonScreen
The system SHALL provide a `FullMapOverlay` (Control) that is added as a child of `DungeonScreen` at setup time and starts hidden. The overlay SHALL be configured with `PRESET_FULL_RECT` so that it covers the entire screen when visible. The overlay SHALL contain a semi-transparent dark background panel and a `TextureRect` displaying the output of `FullMapRenderer`.

#### Scenario: Overlay is hidden on creation
- **WHEN** a `FullMapOverlay` is instantiated and added to `DungeonScreen`
- **THEN** `overlay.visible` SHALL be `false`

#### Scenario: Overlay covers the entire screen when visible
- **WHEN** the overlay is opened
- **THEN** the overlay SHALL fill the entire screen rectangle (anchors set to PRESET_FULL_RECT) so that the underlying 3D dungeon view is darkened

#### Scenario: Overlay displays the rendered map texture
- **WHEN** the overlay is opened with a valid `WizMap`, `ExploredMap`, and `PlayerState`
- **THEN** the overlay SHALL invoke `FullMapRenderer.render(...)` and display the resulting Image via a `TextureRect` centered in the overlay

### Requirement: FullMapOverlay displays HUD elements (dungeon name, coordinates, exploration rate)
FullMapOverlay SHALL display three text HUD elements while visible:
- The dungeon name (from `DungeonData.dungeon_name`) at the top of the overlay
- The player coordinates (from `PlayerState.position`) at the bottom of the overlay
- The exploration rate as a percentage (from `DungeonData.get_exploration_rate()`) at the bottom of the overlay

The HUD SHALL be refreshed each time the overlay is opened so that values reflect the current state.

#### Scenario: Dungeon name is shown at the top
- **WHEN** the overlay is opened with `dungeon_data.dungeon_name == "古びた地下牢"`
- **THEN** a Label SHALL be visible at the top of the overlay displaying `古びた地下牢`

#### Scenario: Player coordinates are shown at the bottom
- **WHEN** the overlay is opened with `player_state.position == Vector2i(7, 3)`
- **THEN** a Label SHALL be visible at the bottom of the overlay displaying the coordinates `(7, 3)` (exact format SHALL include both X and Y values)

#### Scenario: Exploration rate is shown as a percentage
- **WHEN** the overlay is opened and `dungeon_data.get_exploration_rate() == 0.42`
- **THEN** a Label SHALL be visible at the bottom of the overlay displaying `42%` (rounded to integer percentage)

#### Scenario: HUD refreshes on each open
- **WHEN** the overlay is opened, closed, the player moves to a new position, then the overlay is reopened
- **THEN** the displayed coordinates SHALL reflect the new position (not the cached previous position)

### Requirement: FullMapOverlay hides the minimap while visible
FullMapOverlay SHALL hide the `MinimapDisplay` of `DungeonScreen` while the overlay is visible, and SHALL restore the minimap's visibility when the overlay is closed.

#### Scenario: Minimap is hidden when overlay opens
- **WHEN** the overlay is opened
- **THEN** the `MinimapDisplay` of `DungeonScreen` SHALL have `visible == false`

#### Scenario: Minimap is restored when overlay closes
- **WHEN** the overlay is closed (either via m or ESC)
- **THEN** the `MinimapDisplay` of `DungeonScreen` SHALL have `visible == true`

### Requirement: FullMapOverlay closes on ESC and consumes the input
FullMapOverlay SHALL listen for `is_action_pressed("ui_cancel")` (the InputMap action bound to KEY_ESCAPE) in `_unhandled_input` and SHALL invoke `close()` and `get_viewport().set_input_as_handled()` so that the ESC press does NOT propagate to `main.gd` and open the ESC menu.

#### Scenario: ui_cancel action closes the overlay without opening ESC menu
- **WHEN** the FullMapOverlay is visible and `is_action_pressed("ui_cancel")` is dispatched
- **THEN** `FullMapOverlay.close()` SHALL be invoked, the overlay SHALL become hidden, and `set_input_as_handled()` SHALL be called preventing main.gd from opening the ESC menu

#### Scenario: Other actions do not close the overlay
- **WHEN** the overlay is visible and an action other than `ui_cancel` (e.g., `move_forward`, `ui_accept`) is dispatched
- **THEN** the overlay SHALL remain visible

### Requirement: FullMapOverlay exposes open / close / is_open methods
FullMapOverlay SHALL provide `open()`, `close()`, and `is_open() -> bool` methods so that `DungeonScreen` can control its lifecycle and query its state.

#### Scenario: open() makes the overlay visible
- **WHEN** `overlay.open()` is called
- **THEN** `overlay.visible` SHALL become `true` and `overlay.is_open()` SHALL return `true`

#### Scenario: close() hides the overlay
- **WHEN** `overlay.close()` is called on a visible overlay
- **THEN** `overlay.visible` SHALL become `false` and `overlay.is_open()` SHALL return `false`

#### Scenario: is_open() reflects visibility
- **WHEN** the overlay's `visible` property is `true`
- **THEN** `overlay.is_open()` SHALL return `true`

