## Purpose
ダンジョン内ミニマップ（平面俯瞰図）の描画ルールを規定する。探索済み部分のみ表示、現在位置・向きインジケータ、階段マーカーなどの要素を対象とする。

## Requirements

### Requirement: MinimapRenderer creates a line-based Image centered on the player
MinimapRenderer (RefCounted) SHALL generate an Image representing a VIEW_RADIUS (3) cell area around the player (7x7 cells). Each cell SHALL occupy a CELL_PX (9) pixel floor area with WALL_PX (3) pixel gaps between cells for wall lines and high-resolution landmark icons. The Image size SHALL be STRIDE * VIEW_SIZE + WALL_PX = 87 x 87 pixels. The player SHALL always be centered.

#### Scenario: Image size is fixed at 87x87
- **WHEN** render(wiz_map, explored_map, player_state) is called
- **THEN** the returned Image SHALL have width 87 and height 87

#### Scenario: Unexplored cell within view is not drawn
- **WHEN** a cell within the 7x7 view is NOT in explored_map
- **THEN** the floor area pixels SHALL be background color (black)

#### Scenario: Explored cell floor area is drawn
- **WHEN** a cell within the 7x7 view IS in explored_map
- **THEN** the 9x9 floor area pixels SHALL be floor color

#### Scenario: Cell outside map bounds renders as background
- **WHEN** player is at position (0, 0) and cells to the north/west are outside map bounds
- **THEN** those pixels SHALL be background color

### Requirement: MinimapRenderer draws walls and doors as lines
MinimapRenderer SHALL draw wall and door edges as WALL_PX-wide lines spanning the cell width (CELL_PX pixels). Lines SHALL NOT extend to corner pixels. An OPEN edge between two explored cells SHALL be drawn as floor color to connect passages.

#### Scenario: WALL edge renders as wall-colored line
- **WHEN** an explored cell within the view has a WALL edge on NORTH
- **THEN** a 9px horizontal line in wall color SHALL be drawn at the north gap

#### Scenario: DOOR edge renders as door-colored line
- **WHEN** an explored cell within the view has a DOOR edge on EAST
- **THEN** a 9px vertical line in door color SHALL be drawn at the east gap

#### Scenario: OPEN edge between explored cells renders as floor-colored line
- **WHEN** two adjacent explored cells have an OPEN edge between them
- **THEN** the gap pixels SHALL be floor color (passage is visible)

#### Scenario: OPEN edge to unexplored cell is not drawn as floor
- **WHEN** an explored cell has an OPEN edge toward an unexplored cell
- **THEN** the gap pixels SHALL NOT be floor color

#### Scenario: No corner pillars in open areas
- **WHEN** an explored cell has all four edges OPEN with all neighbors explored
- **THEN** the corner pixels adjacent to that cell SHALL NOT be wall color

### Requirement: MinimapRenderer draws player at the center
MinimapRenderer SHALL draw the player marker at the center cell floor area. The direction indicator SHALL fill the edge gap in the facing direction with player color.

#### Scenario: Player floor area is marked
- **WHEN** render is called
- **THEN** the center cell floor pixels SHALL be player color

#### Scenario: Player direction indicator for NORTH
- **WHEN** player is facing NORTH
- **THEN** the north gap pixels of the center cell SHALL be player color

#### Scenario: Player direction indicator for EAST
- **WHEN** player is facing EAST
- **THEN** the east gap pixels of the center cell SHALL be player color

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
