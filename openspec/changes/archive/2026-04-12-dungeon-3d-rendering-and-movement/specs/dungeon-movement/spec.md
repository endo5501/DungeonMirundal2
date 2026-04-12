## ADDED Requirements

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
DungeonScreen SHALL accept keyboard input to control player movement. Up arrow or W SHALL trigger move forward. Down arrow or S SHALL trigger move backward. Left arrow or A SHALL trigger turn left. Right arrow or D SHALL trigger turn right.

#### Scenario: Up arrow moves forward
- **WHEN** user presses the Up arrow key
- **THEN** the system SHALL call move_forward on PlayerState

#### Scenario: Left arrow turns left
- **WHEN** user presses the Left arrow key
- **THEN** the system SHALL call turn_left on PlayerState

#### Scenario: Movement input updates 3D view
- **WHEN** user presses a movement key and the move succeeds
- **THEN** the DungeonScene SHALL update to reflect the new position and direction
