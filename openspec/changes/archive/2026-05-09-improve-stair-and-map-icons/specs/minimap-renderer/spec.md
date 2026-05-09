## MODIFIED Requirements

### Requirement: MinimapRenderer draws generated stair icons

MinimapRenderer SHALL inspect the `tile` type of each explored cell within the 7x7 view and overlay a tile-specific icon on top of the already-drawn floor area for `TileType.START`, `TileType.STAIRS_UP`, `TileType.STAIRS_DOWN`, and `TileType.GOAL`. `START` and `STAIRS_UP` SHALL use the same generated upward-stair icon based on `tmp/kaidan.jpeg` reference B. `STAIRS_DOWN` SHALL use a generated descending-stairwell icon based on reference 10, with white/light-gray steps, visible step lines, and dark wall/shadow pixels rather than cyan or blue. Each icon SHALL occupy only the 9x9 floor pixel area of that cell and SHALL NOT extend into wall-gap pixels. The floor color underneath the icon SHALL continue to be drawn normally. Unexplored landmark cells SHALL NOT draw icons.

#### Scenario: Explored START tile within view shows ordinary upward stair icon
- **WHEN** an explored cell within the 7x7 view has `tile == TileType.START`
- **THEN** the floor area of that cell SHALL contain the same upward stair icon shape used for `TileType.STAIRS_UP`

#### Scenario: Explored STAIRS_UP tile within view shows upward stair icon
- **WHEN** an explored cell within the 7x7 view has `tile == TileType.STAIRS_UP`
- **THEN** the floor area of that cell SHALL contain multiple visible stair step pixels distinct from `COLOR_FLOOR`, `COLOR_PLAYER`, and the STAIRS_DOWN icon shape

#### Scenario: Explored STAIRS_DOWN tile within view shows downward stair icon
- **WHEN** an explored cell within the 7x7 view has `tile == TileType.STAIRS_DOWN`
- **THEN** the floor area of that cell SHALL contain a dark opening/shadow area and multiple visible stair step pixels distinct from `COLOR_FLOOR`, `COLOR_PLAYER`, and the STAIRS_UP icon shape

#### Scenario: Explored GOAL tile within view shows goal icon
- **WHEN** an explored cell within the 7x7 view has `tile == TileType.GOAL`
- **THEN** the floor area of that cell SHALL contain GOAL icon pixels distinct from `COLOR_FLOOR` and `COLOR_PLAYER`

#### Scenario: Landmark icons stay within the 9x9 floor area
- **WHEN** a landmark icon is drawn on a cell at view-grid (vx, vy)
- **THEN** every icon pixel SHALL be inside the 9x9 floor rectangle starting at `(vx * STRIDE + WALL_PX, vy * STRIDE + WALL_PX)`, and no wall-gap pixel SHALL be overwritten

#### Scenario: Unexplored landmark tile does not draw icon
- **WHEN** a `START`, `STAIRS_UP`, `STAIRS_DOWN`, or `GOAL` cell within the 7x7 view is NOT in explored_map
- **THEN** the floor area pixels SHALL remain background color and no landmark icon SHALL be drawn

#### Scenario: Player on landmark tile still shows player marker
- **WHEN** the player stands on any landmark tile at the center cell of the view
- **THEN** the player floor color and direction indicator SHALL take precedence over the landmark icon on the center cell floor area
