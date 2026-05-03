## Purpose
ダンジョン内の移動・回転・壁衝突判定などの操作を規定する。前進・後退・左右旋回・壁接触時の抑止、階段昇降のトリガ条件を対象とする。
## Requirements
### Requirement: PlayerState tracks position and direction
PlayerState SHALL maintain the player's current grid position (x, y) and facing direction (NORTH, EAST, SOUTH, WEST).

#### Scenario: Initial state
- **WHEN** PlayerState is initialized with position (3, 4) and direction NORTH
- **THEN** position SHALL be (3, 4) and direction SHALL be NORTH

#### Scenario: Position and direction are readable
- **WHEN** PlayerState has position (5, 5) and direction EAST
- **THEN** querying position SHALL return (5, 5) and querying direction SHALL return EAST

### Requirement: Player can move forward
PlayerState SHALL support moving forward one cell in the current facing direction when the path is not blocked by a wall.

#### Scenario: Move forward with open path
- **WHEN** player is at (5, 5) facing NORTH and the NORTH edge of cell (5, 5) is OPEN
- **THEN** after move_forward, player position SHALL be (5, 4)

#### Scenario: Move forward blocked by wall
- **WHEN** player is at (5, 5) facing NORTH and the NORTH edge of cell (5, 5) is WALL
- **THEN** after move_forward, player position SHALL remain (5, 5) and the method SHALL return false

#### Scenario: Move forward through door
- **WHEN** player is at (5, 5) facing NORTH and the NORTH edge of cell (5, 5) is DOOR
- **THEN** after move_forward, player position SHALL be (5, 4)

### Requirement: Player can move backward
PlayerState SHALL support moving backward one cell (opposite of facing direction) without changing the facing direction, when the path is not blocked.

#### Scenario: Move backward with open path
- **WHEN** player is at (5, 5) facing NORTH and the SOUTH edge of cell (5, 5) is OPEN
- **THEN** after move_backward, player position SHALL be (5, 6) and direction SHALL remain NORTH

#### Scenario: Move backward blocked by wall
- **WHEN** player is at (5, 5) facing NORTH and the SOUTH edge of cell (5, 5) is WALL
- **THEN** after move_backward, player position SHALL remain (5, 5)

### Requirement: Player can turn left and right
PlayerState SHALL support 90-degree rotation left (counter-clockwise) and right (clockwise) without changing position.

#### Scenario: Turn right from NORTH
- **WHEN** player is facing NORTH
- **THEN** after turn_right, player SHALL face EAST

#### Scenario: Turn left from NORTH
- **WHEN** player is facing NORTH
- **THEN** after turn_left, player SHALL face WEST

#### Scenario: Turn right wraps from WEST to NORTH
- **WHEN** player is facing WEST
- **THEN** after turn_right, player SHALL face NORTH

#### Scenario: Turn left wraps from NORTH to WEST
- **WHEN** player is facing NORTH
- **THEN** after turn_left, player SHALL face WEST

#### Scenario: Turning does not change position
- **WHEN** player is at (5, 5) and turns in any direction
- **THEN** player position SHALL remain (5, 5)

### Requirement: Wall collision prevents movement
PlayerState SHALL use WizMap.can_move() to determine if movement is allowed. Movement SHALL be rejected if the target edge is WALL or if the target cell is out of bounds.

#### Scenario: Cannot move out of map bounds
- **WHEN** player is at (0, 0) facing NORTH (map boundary)
- **THEN** move_forward SHALL return false and position SHALL remain (0, 0)

#### Scenario: Can move returns true on success
- **WHEN** player moves forward successfully
- **THEN** move_forward SHALL return true

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

### Requirement: DungeonScreen notifies observers of successful position changes
DungeonScreen SHALL emit a signal or invoke an injected callback when the player successfully changes grid position (not merely rotation), enabling encounter detection to run per step without coupling DungeonScreen to the encounter subsystem.

#### Scenario: Forward move emits a step event
- **WHEN** the player presses Up and the forward move succeeds
- **THEN** DungeonScreen SHALL notify observers that a step has occurred, with the new position

#### Scenario: Blocked move does not emit a step event
- **WHEN** the player presses Up and the forward move is blocked by a wall
- **THEN** DungeonScreen SHALL NOT notify observers of a step

#### Scenario: Rotation does not emit a step event
- **WHEN** the player presses Left or Right and the facing changes
- **THEN** DungeonScreen SHALL NOT notify observers of a step

### Requirement: Encounter trigger takes priority over start-tile return prompt
When both the start-tile return prompt and an encounter would fire on the same step, the system SHALL present the encounter first; the return prompt SHALL only appear after the encounter is resolved if the player is still on the start tile.

#### Scenario: Step onto start tile with triggered encounter
- **WHEN** the player moves onto the start tile and the encounter roll also triggers
- **THEN** the encounter overlay SHALL be shown first and the return dialog SHALL NOT be shown until the encounter is resolved

#### Scenario: Step onto start tile without encounter
- **WHEN** the player moves onto the start tile and no encounter triggers
- **THEN** the return dialog SHALL appear as before

### Requirement: DungeonScreen suspends input while encounter overlay is active
DungeonScreen SHALL ignore movement, rotation, and return-dialog input while the EncounterOverlay is active, and SHALL resume input only after `encounter_resolved` is emitted.

#### Scenario: Movement keys are ignored during encounter
- **WHEN** the EncounterOverlay is visible and the user presses Up
- **THEN** the player position SHALL NOT change and no additional step event SHALL be emitted

#### Scenario: ESC is not intercepted to open the ESC menu during encounter
- **WHEN** the EncounterOverlay is visible and the user presses ESC
- **THEN** the ESC menu SHALL NOT open

