## ADDED Requirements

### Requirement: CellMeshBuilder renders START tile with stairs-up geometry

CellMeshBuilder SHALL inspect the `tile` type of the given cell and, when it is `TileType.START`, generate additional mesh faces forming a simple upward-facing staircase placed on top of the floor quad. The staircase SHALL be centered horizontally within the 2.0 x 2.0 cell footprint, composed of 2 or 3 rectangular steps ascending in a consistent direction, and SHALL NOT exceed the cell ceiling height (Y < CELL_HEIGHT). The existing floor and ceiling faces SHALL continue to be generated unchanged. Cells whose `tile` is not `START` SHALL NOT receive any staircase faces.

#### Scenario: START tile generates staircase faces
- **WHEN** CellMeshBuilder is given a cell whose `tile` is `TileType.START`
- **THEN** the returned faces SHALL include at least one additional face type identifiable as the staircase (e.g. `stairs_up_*`) in addition to the usual floor/ceiling/wall faces

#### Scenario: Non-START tile does not generate staircase faces
- **WHEN** CellMeshBuilder is given a cell whose `tile` is `TileType.FLOOR`
- **THEN** the returned faces SHALL NOT include any staircase face

#### Scenario: Staircase stays within the cell volume
- **WHEN** CellMeshBuilder generates staircase faces for a START cell at grid (3, 2)
- **THEN** every staircase vertex SHALL satisfy `x0 <= x <= x1`, `z0 <= z <= z1`, and `0 <= y < CELL_HEIGHT` where `x0/x1/z0/z1` are the cell's horizontal bounds

#### Scenario: Floor and ceiling still generated on START tile
- **WHEN** CellMeshBuilder is given a START cell
- **THEN** the returned faces SHALL still include the floor and ceiling faces at Y=0 and Y=CELL_HEIGHT respectively
