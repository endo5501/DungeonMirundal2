## MODIFIED Requirements

### Requirement: CellMeshBuilder renders landmark stair geometry

CellMeshBuilder SHALL inspect the `tile` type of the given cell and, when it is a landmark tile, generate additional mesh faces that visually distinguish the landmark while preserving the usual wall, floor, and ceiling faces. `TileType.START` SHALL generate the same ordinary upward stair geometry as `TileType.STAIRS_UP`. `TileType.STAIRS_UP` SHALL generate upward stair geometry. `TileType.STAIRS_DOWN` SHALL generate a floor opening with a dark pit and descending stair geometry. `TileType.GOAL` SHALL generate a destination altar or stone marker. Cells whose `tile` is `TileType.FLOOR` SHALL NOT receive landmark faces. All landmark vertices SHALL remain within the owning 2.0 x 2.0 cell footprint and within the vertical cell volume from floor to below or at `CELL_HEIGHT`.

#### Scenario: START tile generates ordinary upward stair faces
- **WHEN** CellMeshBuilder is given a cell whose `tile` is `TileType.START`
- **THEN** the returned faces SHALL include additional face types identifiable as upward stairs
- **AND** the returned faces SHALL NOT include return landmark or stair-down face types

#### Scenario: STAIRS_UP tile generates upward stair faces
- **WHEN** CellMeshBuilder is given a cell whose `tile` is `TileType.STAIRS_UP`
- **THEN** the returned faces SHALL include additional face types identifiable as upward stairs

#### Scenario: STAIRS_DOWN tile generates pit and descending stair faces
- **WHEN** CellMeshBuilder is given a cell whose `tile` is `TileType.STAIRS_DOWN`
- **THEN** the returned faces SHALL include additional face types identifiable as a downward opening or pit
- **AND** the returned faces SHALL include additional face types identifiable as descending stairs

#### Scenario: GOAL tile generates altar faces
- **WHEN** CellMeshBuilder is given a cell whose `tile` is `TileType.GOAL`
- **THEN** the returned faces SHALL include additional face types identifiable as a goal altar or stone marker

#### Scenario: FLOOR tile does not generate landmark faces
- **WHEN** CellMeshBuilder is given a cell whose `tile` is `TileType.FLOOR`
- **THEN** the returned faces SHALL NOT include any landmark, stair, pit, or altar face

#### Scenario: Landmark geometry stays within the cell volume
- **WHEN** CellMeshBuilder generates landmark faces for any of `START`, `STAIRS_UP`, `STAIRS_DOWN`, or `GOAL` at grid (3, 2)
- **THEN** every landmark vertex SHALL satisfy `x0 <= x <= x1`, `z0 <= z <= z1`, and `0 <= y <= CELL_HEIGHT` where `x0/x1/z0/z1` are the cell's horizontal bounds

#### Scenario: Floor and ceiling still generated on landmark tiles
- **WHEN** CellMeshBuilder is given any of `START`, `STAIRS_UP`, `STAIRS_DOWN`, or `GOAL`
- **THEN** the returned faces SHALL still include the floor and ceiling faces at Y=0 and Y=CELL_HEIGHT respectively
