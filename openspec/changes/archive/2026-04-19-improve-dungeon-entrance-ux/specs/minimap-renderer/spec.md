## ADDED Requirements

### Requirement: MinimapRenderer draws a marker on the START tile

MinimapRenderer SHALL inspect the `tile` type of each explored cell within the 7x7 view and, when the tile is `TileType.START`, overlay a small marker on top of the already-drawn floor area. The marker SHALL use a color distinct from both `COLOR_FLOOR` and `COLOR_PLAYER`, SHALL occupy at most the 3x3 floor pixel area of that cell, and SHALL NOT extend into the wall-gap pixels. The floor color underneath the marker SHALL continue to be drawn normally (the marker overlays, not replaces, the base floor color). Unexplored START cells SHALL NOT draw the marker.

#### Scenario: Explored START tile within view shows marker
- **WHEN** an explored cell within the 7x7 view has `tile == TileType.START`
- **THEN** the floor area of that cell SHALL contain marker-color pixels in addition to the floor color

#### Scenario: Marker color is distinct from floor and player
- **WHEN** the START marker is drawn
- **THEN** the marker color SHALL NOT equal `COLOR_FLOOR` and SHALL NOT equal `COLOR_PLAYER`

#### Scenario: Marker stays within the 3x3 floor area
- **WHEN** the START marker is drawn on a cell at view-grid (vx, vy)
- **THEN** every marker pixel SHALL be inside the 3x3 floor rectangle starting at `(vx * STRIDE + WALL_PX, vy * STRIDE + WALL_PX)`, and no wall-gap pixel SHALL be overwritten

#### Scenario: Unexplored START tile does not draw marker
- **WHEN** a START cell within the 7x7 view is NOT in explored_map
- **THEN** the floor area pixels SHALL remain background color and no marker SHALL be drawn

#### Scenario: START tile directly under the player still shows player marker
- **WHEN** the player stands on the START tile (center cell of the view)
- **THEN** the player floor color and direction indicator SHALL take precedence over the START marker on the center cell floor area
