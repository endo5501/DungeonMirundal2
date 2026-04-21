## ADDED Requirements

### Requirement: FullMapRenderer generates a fitted Image of the entire floor
FullMapRenderer (RefCounted) SHALL generate an Image representing the entire `WizMap` at a size that fits within a caller-supplied target rectangle. The renderer SHALL compute a per-cell pixel size such that `cell_px = max(MIN_CELL_PX, floor(min(target_w, target_h) / wiz_map.map_size))`, where `MIN_CELL_PX = 4`. The output Image SHALL have side length `cell_px * map_size + WALL_PX` (square), where `WALL_PX = 1`. Cells SHALL be laid out so that grid (0, 0) maps to the top-left and grid (map_size-1, map_size-1) maps to the bottom-right of the Image.

#### Scenario: Cell pixel size adapts to target size
- **WHEN** `render(wiz_map, explored_map, player_state, Vector2i(640, 480))` is called on a `WizMap` with `map_size = 20`
- **THEN** the renderer SHALL choose `cell_px = floor(480 / 20) = 24` (since `min(640, 480) = 480` and 24 ≥ MIN_CELL_PX), and the returned Image SHALL be square with side length `24 * 20 + 1 = 481`

#### Scenario: Minimum cell pixel size is enforced
- **WHEN** `render(...)` is called with a target rectangle so small that the natural calculation yields fewer than `MIN_CELL_PX` pixels per cell
- **THEN** `cell_px` SHALL be clamped to `MIN_CELL_PX` and the resulting Image MAY exceed the target rectangle

#### Scenario: Image is square based on the smaller dimension
- **WHEN** `render(...)` is called with `target_size = Vector2i(1000, 500)` on a `map_size = 10` map
- **THEN** `cell_px = floor(500 / 10) = 50` SHALL be used (the smaller dimension governs), and the Image SHALL be square with side `50 * 10 + 1 = 501`

### Requirement: FullMapRenderer draws only explored cells
FullMapRenderer SHALL render floor area, wall edges, and door edges ONLY for cells that are in `explored_map`. Cells not yet explored SHALL render as background color (no floor, no walls, no doors). Edges between an explored and an unexplored cell SHALL be drawn from the explored side only.

#### Scenario: Unexplored cell renders as background
- **WHEN** a cell at grid (5, 5) is NOT in `explored_map`
- **THEN** the pixel area for that cell SHALL be entirely background color (no floor, walls, or doors visible)

#### Scenario: Explored cell floor area is drawn
- **WHEN** a cell at grid (5, 5) IS in `explored_map`
- **THEN** the `cell_px x cell_px` floor area for that cell SHALL be filled with floor color

#### Scenario: WALL edge of explored cell renders as wall color
- **WHEN** an explored cell has a WALL edge on NORTH
- **THEN** a wall-colored line SHALL be drawn at the north gap of that cell

#### Scenario: DOOR edge of explored cell renders as door color
- **WHEN** an explored cell has a DOOR edge on EAST
- **THEN** a door-colored line SHALL be drawn at the east gap of that cell

#### Scenario: OPEN edge between two explored cells shows passage
- **WHEN** two adjacent explored cells share an OPEN edge
- **THEN** the gap pixels between them SHALL be floor color (passage is visually connected)

#### Scenario: OPEN edge from explored to unexplored cell does not render passage
- **WHEN** an explored cell has an OPEN edge toward an unexplored cell
- **THEN** the gap pixels SHALL NOT be floor color (the unexplored side is hidden)

### Requirement: FullMapRenderer marks START and GOAL tiles distinctly
FullMapRenderer SHALL overlay a START marker on explored cells whose `tile == TileType.START` and a GOAL marker on explored cells whose `tile == TileType.GOAL`. The two marker colors SHALL be distinct from each other, from floor color, and from player color. Markers SHALL stay within the floor area of their respective cells (SHALL NOT overwrite wall-gap pixels). Unexplored START or GOAL cells SHALL NOT render any marker.

#### Scenario: Explored START tile shows START marker
- **WHEN** an explored cell has `tile == TileType.START`
- **THEN** the floor area of that cell SHALL contain START-marker-colored pixels in addition to the floor color

#### Scenario: Explored GOAL tile shows GOAL marker
- **WHEN** an explored cell has `tile == TileType.GOAL`
- **THEN** the floor area of that cell SHALL contain GOAL-marker-colored pixels in addition to the floor color

#### Scenario: START and GOAL markers use different colors
- **WHEN** both a START and a GOAL marker are drawn in the same Image
- **THEN** the START marker color SHALL NOT equal the GOAL marker color, and neither SHALL equal the floor or player color

#### Scenario: Unexplored START tile does not draw marker
- **WHEN** a cell with `tile == TileType.START` is NOT in `explored_map`
- **THEN** no marker SHALL be drawn at that cell location and the cell area SHALL remain background color

#### Scenario: Markers stay within the cell floor area
- **WHEN** a START or GOAL marker is drawn at grid (cx, cy)
- **THEN** every marker pixel SHALL be inside the `cell_px x cell_px` floor rectangle for that cell, and no wall-gap pixel SHALL be overwritten

### Requirement: FullMapRenderer draws the player at the actual grid position
FullMapRenderer SHALL render the player marker at the cell corresponding to `player_state.position` (NOT centered in the Image). The player marker SHALL be a player-colored fill of the floor area, and the player's facing direction SHALL be indicated by filling the gap pixels on the facing side of that cell with player color.

#### Scenario: Player marker appears at the player's grid position
- **WHEN** `player_state.position == Vector2i(7, 3)` and that cell is explored
- **THEN** the floor area of cell (7, 3) SHALL be player color (overriding the normal floor color)

#### Scenario: Player direction indicator on NORTH
- **WHEN** the player is at (5, 5) facing NORTH
- **THEN** the north gap pixels of cell (5, 5) SHALL be player color

#### Scenario: Player direction indicator on EAST
- **WHEN** the player is at (5, 5) facing EAST
- **THEN** the east gap pixels of cell (5, 5) SHALL be player color

#### Scenario: Player on START tile takes precedence over START marker
- **WHEN** the player is standing on a cell with `tile == TileType.START`
- **THEN** the player floor color and direction indicator SHALL be visible (the START marker MAY be covered)

#### Scenario: Player cell is always considered explored for rendering
- **WHEN** `render(...)` is called with the player at a position
- **THEN** the player marker SHALL be drawn at that position regardless of whether the player's current cell has been recorded in `explored_map` (the player is by definition there)
