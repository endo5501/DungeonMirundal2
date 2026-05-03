## MODIFIED Requirements

### Requirement: Keyboard input controls movement
DungeonScreen SHALL handle movement input via the following `InputMap` actions (each bound to the appropriate keys in `project.godot`) instead of direct keycode comparison:

- `move_forward`: advance one cell in the current facing direction
- `move_back`: retreat one cell against the current facing direction
- `strafe_left`: side-step one cell to the player's left without rotating
- `strafe_right`: side-step one cell to the player's right without rotating
- `turn_left`: rotate the facing 90° counter-clockwise (no position change)
- `turn_right`: rotate the facing 90° clockwise (no position change)

Each action SHALL trigger its corresponding movement only when no encounter is active and no return-to-town dialog is showing and the full map overlay is not visible.

#### Scenario: move_forward action moves the player one cell ahead
- **WHEN** the player faces NORTH and an event matching `is_action_pressed("move_forward")` is dispatched
- **THEN** the player position SHALL update by `Direction.offset(NORTH)`, `step_taken` SHALL be emitted, and the dungeon SHALL re-render

#### Scenario: turn_left action rotates the facing 90° counter-clockwise
- **WHEN** the player faces NORTH and `is_action_pressed("turn_left")` is dispatched
- **THEN** the player facing SHALL be `WEST`, the player position SHALL be unchanged, and `step_taken` SHALL NOT be emitted

#### Scenario: strafe_left moves the player one cell to the left without rotating
- **WHEN** the player faces NORTH and `is_action_pressed("strafe_left")` is dispatched and the WEST edge is open
- **THEN** the player position SHALL update by `Direction.offset(WEST)`, the facing SHALL remain `NORTH`, and `step_taken` SHALL be emitted

#### Scenario: Movement is blocked while encounter is active
- **WHEN** `set_encounter_active(true)` has been called and `is_action_pressed("move_forward")` is dispatched
- **THEN** the player position SHALL NOT change and `step_taken` SHALL NOT be emitted

#### Scenario: Movement is blocked while return dialog is showing
- **WHEN** the return-to-town dialog is visible and `is_action_pressed("move_forward")` is dispatched
- **THEN** the player position SHALL NOT change

#### Scenario: Movement is blocked while full map overlay is visible
- **WHEN** the full map overlay is visible and `is_action_pressed("move_forward")` is dispatched
- **THEN** the player position SHALL NOT change
