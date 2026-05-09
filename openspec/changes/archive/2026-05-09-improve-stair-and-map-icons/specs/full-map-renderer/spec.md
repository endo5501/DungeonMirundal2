## MODIFIED Requirements

### Requirement: FullMapRenderer draws generated stair icons

FullMapRenderer SHALL overlay tile-specific icons on explored cells whose `tile` is `TileType.START`, `TileType.STAIRS_UP`, `TileType.STAIRS_DOWN`, or `TileType.GOAL`. `START` and `STAIRS_UP` SHALL use the same generated upward-stair icon based on `tmp/kaidan.jpeg` reference B. `STAIRS_DOWN` SHALL use a generated descending-stairwell icon based on reference 10, with white/light-gray steps, visible step lines, and dark wall/shadow pixels rather than cyan or blue. Icons SHALL stay within the floor area of their respective cells and SHALL NOT overwrite wall-gap pixels. Unexplored landmark cells SHALL NOT render any icon. Icons SHALL render legibly at the minimum supported cell size and may include additional detail when `floor_px` is larger.

#### Scenario: Explored START tile shows ordinary upward stair icon
- **WHEN** an explored cell has `tile == TileType.START`
- **THEN** the floor area of that cell SHALL contain the same upward stair icon shape used for `TileType.STAIRS_UP`

#### Scenario: Explored STAIRS_UP tile shows upward stair icon
- **WHEN** an explored cell has `tile == TileType.STAIRS_UP`
- **THEN** the floor area of that cell SHALL contain multiple visible stair step pixels distinct from floor, player, and the STAIRS_DOWN icon shape

#### Scenario: Explored STAIRS_DOWN tile shows downward stair icon
- **WHEN** an explored cell has `tile == TileType.STAIRS_DOWN`
- **THEN** the floor area of that cell SHALL contain a dark opening/shadow area and multiple visible stair step pixels distinct from floor, player, and the STAIRS_UP icon shape

#### Scenario: Explored GOAL tile shows altar or goal icon
- **WHEN** an explored cell has `tile == TileType.GOAL`
- **THEN** the floor area of that cell SHALL contain GOAL icon pixels distinct from floor and player colors

#### Scenario: Landmark icons use distinct identities
- **WHEN** START, STAIRS_UP, STAIRS_DOWN, and GOAL icons are drawn in the same Image
- **THEN** START and STAIRS_UP SHALL match each other, and STAIRS_DOWN and GOAL SHALL be distinguishable by color and/or shape

#### Scenario: Unexplored landmark tile does not draw icon
- **WHEN** a cell with `tile == TileType.START`, `TileType.STAIRS_UP`, `TileType.STAIRS_DOWN`, or `TileType.GOAL` is NOT in `explored_map`
- **THEN** no icon SHALL be drawn at that cell location and the cell area SHALL remain background color

#### Scenario: Landmark icons stay within the cell floor area
- **WHEN** a landmark icon is drawn at grid (cx, cy)
- **THEN** every icon pixel SHALL be inside the floor rectangle for that cell, and no wall-gap pixel SHALL be overwritten

#### Scenario: Player on landmark tile takes precedence over landmark icon
- **WHEN** the player is standing on a cell with `tile == TileType.START`, `TileType.STAIRS_UP`, `TileType.STAIRS_DOWN`, or `TileType.GOAL`
- **THEN** the player floor color and direction indicator SHALL be visible over the landmark icon
