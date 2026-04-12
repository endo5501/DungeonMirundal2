## ADDED Requirements

### Requirement: DungeonView calculates visible cells
DungeonView SHALL calculate the set of visible cells from the player's current position and facing direction. The view SHALL extend up to 4 cells forward and 1 cell to each side. Cells behind walls SHALL NOT be included in the visible set.

#### Scenario: Forward view in open corridor
- **WHEN** player is at position (5, 5) facing NORTH with no walls in the forward path for 4 cells
- **THEN** DungeonView SHALL return cells at (5,5), (5,4), (5,3), (5,2), (5,1) and lateral cells (4,4), (6,4), (4,3), (6,3), (4,2), (6,2), (4,1), (6,1)

#### Scenario: Wall blocks forward view
- **WHEN** player is at position (5, 5) facing NORTH and there is a wall on the NORTH edge of cell (5, 3)
- **THEN** DungeonView SHALL return cells up to (5,3) but NOT (5,2) or (5,1), and lateral cells SHALL also be cut at that depth

#### Scenario: Lateral wall blocks side view
- **WHEN** player is at position (5, 5) facing NORTH and there is a wall on the WEST edge of cell (5, 4)
- **THEN** cell (4, 4) SHALL NOT be included in the visible set

#### Scenario: Map boundary limits view
- **WHEN** player is at position (5, 1) facing NORTH with map size 10
- **THEN** DungeonView SHALL NOT include cells with y < 0

### Requirement: CellMeshBuilder generates wall geometry
CellMeshBuilder SHALL generate 3D mesh vertex data for a single cell's visible walls, floor, and ceiling. Each cell occupies a 2.0 x 2.0 x 2.0 unit space. Floor is at Y=0, ceiling at Y=2.0.

#### Scenario: Cell with wall on NORTH edge
- **WHEN** CellMeshBuilder is given a cell at grid position (3, 2) with a WALL on the NORTH edge
- **THEN** it SHALL generate a vertical quad face at the north boundary of the cell (z = 2*2 = 4.0, spanning x from 6.0 to 8.0, y from 0.0 to 2.0)

#### Scenario: Cell with OPEN edge has no wall mesh
- **WHEN** CellMeshBuilder is given a cell at grid position (3, 2) with an OPEN NORTH edge
- **THEN** it SHALL NOT generate a wall face on the north side

#### Scenario: Cell with DOOR edge generates door-colored wall
- **WHEN** CellMeshBuilder is given a cell with a DOOR edge
- **THEN** it SHALL generate a wall face with the door material (visually distinct from regular walls)

#### Scenario: Floor and ceiling are always generated
- **WHEN** CellMeshBuilder is given any visible cell
- **THEN** it SHALL generate a floor quad at Y=0 and a ceiling quad at Y=2.0 for that cell

### Requirement: DungeonScene renders 3D view
DungeonScene (Node3D) SHALL render the dungeon from a first-person perspective using a Camera3D. The camera SHALL be positioned at the player's cell center at Y=1.0 (eye height) and face the player's current direction.

#### Scenario: Scene updates on player state change
- **WHEN** the player's position or direction changes
- **THEN** DungeonScene SHALL rebuild the visible mesh and update the Camera3D position and rotation

#### Scenario: Camera faces player direction
- **WHEN** the player is facing NORTH
- **THEN** the Camera3D SHALL face the negative Z direction (Godot's forward convention)

### Requirement: DungeonScreen composes the dungeon UI
DungeonScreen (Control) SHALL display the 3D dungeon view using a SubViewportContainer in the upper portion of the screen.

#### Scenario: Screen layout
- **WHEN** DungeonScreen is displayed
- **THEN** a SubViewportContainer with the 3D dungeon view SHALL occupy the upper area of the screen

### Requirement: Visual distinction between wall types
The rendering system SHALL visually distinguish between WALL edges, DOOR edges, and OPEN edges. WALL edges SHALL render as gray surfaces. DOOR edges SHALL render as brown surfaces. OPEN edges SHALL render no surface.

#### Scenario: Wall renders as gray
- **WHEN** a cell has a WALL edge facing the player
- **THEN** it SHALL be rendered as a gray-colored surface

#### Scenario: Door renders as brown
- **WHEN** a cell has a DOOR edge facing the player
- **THEN** it SHALL be rendered as a brown-colored surface

#### Scenario: Open edge renders nothing
- **WHEN** a cell has an OPEN edge facing the player
- **THEN** no surface SHALL be rendered on that edge
