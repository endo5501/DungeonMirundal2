## Purpose
ダンジョン内ミニマップ（平面俯瞰図）の描画ルールを規定する。探索済み部分のみ表示、現在位置・向きインジケータ、階段マーカーなどの要素を対象とする。

## Requirements

### Requirement: MinimapRenderer creates a line-based Image centered on the player
MinimapRenderer (RefCounted) SHALL generate an Image representing a VIEW_RADIUS (3) cell area around the player (7x7 cells). Each cell SHALL occupy a CELL_PX (3) pixel floor area with WALL_PX (1) pixel gaps between cells for wall lines. The Image size SHALL be STRIDE * VIEW_SIZE + WALL_PX = 29 x 29 pixels. The player SHALL always be centered.

#### Scenario: Image size is fixed at 29x29
- **WHEN** render(wiz_map, explored_map, player_state) is called
- **THEN** the returned Image SHALL have width 29 and height 29

#### Scenario: Unexplored cell within view is not drawn
- **WHEN** a cell within the 7x7 view is NOT in explored_map
- **THEN** the floor area pixels SHALL be background color (black)

#### Scenario: Explored cell floor area is drawn
- **WHEN** a cell within the 7x7 view IS in explored_map
- **THEN** the 3x3 floor area pixels SHALL be floor color

#### Scenario: Cell outside map bounds renders as background
- **WHEN** player is at position (0, 0) and cells to the north/west are outside map bounds
- **THEN** those pixels SHALL be background color

### Requirement: MinimapRenderer draws walls and doors as lines
MinimapRenderer SHALL draw wall and door edges as 1-pixel-wide lines spanning the cell width (CELL_PX pixels). Lines SHALL NOT extend to corner pixels. An OPEN edge between two explored cells SHALL be drawn as floor color to connect passages.

#### Scenario: WALL edge renders as wall-colored line
- **WHEN** an explored cell within the view has a WALL edge on NORTH
- **THEN** a 3px horizontal line in wall color SHALL be drawn at the north gap

#### Scenario: DOOR edge renders as door-colored line
- **WHEN** an explored cell within the view has a DOOR edge on EAST
- **THEN** a 3px vertical line in door color SHALL be drawn at the east gap

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
- **THEN** the center cell floor pixels (14, 14) SHALL be player color

#### Scenario: Player direction indicator for NORTH
- **WHEN** player is facing NORTH
- **THEN** the north gap pixels of the center cell SHALL be player color

#### Scenario: Player direction indicator for EAST
- **WHEN** player is facing EAST
- **THEN** the east gap pixels of the center cell SHALL be player color
