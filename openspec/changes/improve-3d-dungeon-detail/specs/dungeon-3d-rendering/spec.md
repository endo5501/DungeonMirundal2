## MODIFIED Requirements

### Requirement: CellMeshBuilder generates wall geometry
CellMeshBuilder SHALL generate 3D mesh vertex data for walls, floor, and ceiling. Each cell occupies a 2.0 x 2.0 x 2.0 unit space. Floor is at Y=0, ceiling at Y=2.0.

Walls SHALL be rendered as solid rectangular boxes with thickness T = 0.20 units, centered on the edge between the two adjacent cells. A wall on the NORTH edge of cell (gx, gy) SHALL occupy the volume `x ∈ [gx*2.0, (gx+1)*2.0]`, `y ∈ [0, 2.0]`, `z ∈ [gy*2.0 - 0.10, gy*2.0 + 0.10]`. The box SHALL emit six face groups (`inner`, `outer`, `top`, `bottom`, `east`, `west`) tagged with face type prefixes that include the direction.

Walls SHALL be deduplicated across cells: each shared edge between two visible cells SHALL produce exactly one wall box (not one per cell). Boundary edges (where the neighboring cell is outside the map) SHALL still produce a wall box if the cell's edge is `WALL`.

#### Scenario: Cell with wall on NORTH edge generates a thick wall box
- **WHEN** CellMeshBuilder builds the visible mesh for a single isolated cell at grid position (3, 2) with a `WALL` on the NORTH edge
- **THEN** the returned faces SHALL include face types matching `wall_north_*` (inner, outer, top, bottom, east, west — 6 face groups)
- **AND** the inner face vertices SHALL satisfy `z ≈ 4.10` (cell-side, gy*2 + T/2)
- **AND** the outer face vertices SHALL satisfy `z ≈ 3.90` (neighbor-side, gy*2 - T/2)
- **AND** all wall vertices SHALL satisfy `6.0 ≤ x ≤ 8.0` and `0.0 ≤ y ≤ 2.0`

#### Scenario: Shared wall between two cells is rendered exactly once
- **WHEN** CellMeshBuilder builds the visible mesh for two adjacent visible cells that share a `WALL` edge between them
- **THEN** exactly one wall box (one set of `wall_*` faces for that edge) SHALL be produced, not two
- **AND** the resulting box vertex count for the shared wall SHALL match a single 6-face box

#### Scenario: Cell with OPEN edge has no wall mesh
- **WHEN** CellMeshBuilder builds the visible mesh for a cell with an `OPEN` edge in some direction
- **THEN** no `wall_*` face SHALL be generated for that edge

#### Scenario: Floor and ceiling are always generated per cell
- **WHEN** CellMeshBuilder builds the visible mesh including a given visible cell
- **THEN** it SHALL generate a floor quad at Y=0 and a ceiling quad at Y=2.0 for that cell (one of each per cell, no deduplication needed)

### Requirement: Visual distinction between wall types
The rendering system SHALL visually distinguish between WALL edges, DOOR edges, and OPEN edges under the lit dungeon environment. WALL edges SHALL render as a neutral stone-gray surface formed by a thick box. DOOR edges SHALL render as a door assembly composed of a stone-gray frame (lintel and jambs) plus a recessed warm-brown door panel that is visually distinct from WALL. OPEN edges SHALL render no surface. Exact RGB values are implementation details (chosen so that readability is preserved after torch illumination and fog darken the scene).

#### Scenario: Wall renders as stone gray
- **WHEN** a cell has a `WALL` edge facing the player
- **THEN** the inner face of the wall box SHALL be rendered with a neutral gray base tint that appears as stone under the torch light

#### Scenario: Door assembly distinguishes frame from panel
- **WHEN** a cell has a `DOOR` edge facing the player
- **THEN** the lintel and jamb faces SHALL be rendered with the stone-gray (WALL-like) base tint
- **AND** the door panel face SHALL be rendered with a warm brown base tint that is perceptibly distinct from the stone tint under torch light

#### Scenario: Open edge renders nothing
- **WHEN** a cell has an `OPEN` edge facing the player
- **THEN** no surface (no wall, no frame, no panel) SHALL be rendered on that edge

## ADDED Requirements

### Requirement: CellMeshBuilder builds the visible mesh in batch with edge deduplication
CellMeshBuilder SHALL expose a per-batch method `build_meshes(visible_cells: Array[Vector2i], wiz_map: WizMap) -> Array` that produces the complete face list for a frame's visible mesh. Inside this method, walls (and door assemblies) SHALL be enumerated from the unique set of edges adjacent to the visible cells (not from per-cell iteration), so that each shared edge contributes geometry exactly once. Floor, ceiling, and landmark (stairs / pit / altar) faces SHALL still be generated per cell.

The legacy per-cell helper `build_faces(cell, pos)` MAY be retained as an internal helper for floor / ceiling / landmark generation, but SHALL NOT be used by `DungeonScene` for wall geometry.

#### Scenario: build_meshes deduplicates shared edges
- **WHEN** `build_meshes` is called with `visible_cells = [(0, 0), (0, 1)]` where the SOUTH edge of (0, 0) (= NORTH edge of (0, 1)) is `WALL`
- **THEN** exactly one wall box (one set of `wall_*` faces for that shared edge) SHALL appear in the returned face list

#### Scenario: build_meshes produces floor and ceiling per cell
- **WHEN** `build_meshes` is called with N visible cells
- **THEN** the returned face list SHALL contain exactly N `floor` faces and exactly N `ceiling` faces

#### Scenario: DungeonScene uses build_meshes
- **WHEN** `DungeonScene._rebuild_mesh(visible_cells)` is called
- **THEN** it SHALL invoke `build_meshes(visible_cells, wiz_map)` (or equivalent) and SHALL NOT iterate cells calling `build_faces` per cell for walls

### Requirement: Corner pillars at wall-touching corners
CellMeshBuilder SHALL place a vertical stone pillar at every grid corner (i, j) (i, j integer in cell-grid coordinates) that is adjacent to at least one `WALL` or `DOOR` edge among the up-to-four edges meeting that corner. A corner adjacent to four `OPEN` edges SHALL NOT receive a pillar. A corner where any contributing cell is outside the map SHALL treat the missing edges as `WALL` (boundary corners always get a pillar).

A pillar SHALL be a 0.25 x 2.0 x 0.25 box centered at the corner: `x ∈ [i*2.0 - 0.125, i*2.0 + 0.125]`, `y ∈ [0, 2.0]`, `z ∈ [j*2.0 - 0.125, j*2.0 + 0.125]`. Pillars SHALL be deduplicated across visible cells (each corner produces at most one pillar). Pillar face types SHALL use the `pillar_*` prefix.

#### Scenario: Corner with all four edges OPEN has no pillar
- **WHEN** `build_meshes` is called for a 3x3 region of fully-OPEN cells (e.g. the interior of a room) so that the inner corners have all four meeting edges OPEN
- **THEN** no `pillar_*` faces SHALL be produced at those inner corners

#### Scenario: Corner with at least one WALL edge gets a pillar
- **WHEN** `build_meshes` is called with a corner where one of the four meeting edges is `WALL` (e.g. the end of a wall stub poking into a room)
- **THEN** exactly one set of `pillar_*` faces SHALL be produced at that corner

#### Scenario: Cross intersection corner gets a pillar
- **WHEN** `build_meshes` is called with a corner where all four meeting edges are `WALL`
- **THEN** exactly one set of `pillar_*` faces SHALL be produced at that corner (not four)

#### Scenario: Map boundary corner gets a pillar
- **WHEN** `build_meshes` is called for the cell at grid (0, 0) where the NW corner has only one in-map cell contributing
- **THEN** the NW corner SHALL receive a pillar (boundary edges treated as WALL)

#### Scenario: Pillar dimensions and position
- **WHEN** a pillar is generated at corner (i, j) with i=2, j=3
- **THEN** all pillar vertices SHALL satisfy `3.875 ≤ x ≤ 4.125`, `0 ≤ y ≤ 2.0`, `5.875 ≤ z ≤ 6.125`

### Requirement: Skirting and cornice trim along walls
CellMeshBuilder SHALL emit skirting (along the floor / wall joint) and cornice (along the ceiling / wall joint) trim for every `WALL` and `DOOR` edge. Each trim SHALL be a thin box of height 0.08 along Y, length CELL_SIZE (2.0) along the edge axis, and projection 0.04 from the wall surface into the cell interior. The trim SHALL be emitted on the cell-interior side of the wall (one trim per visible cell side, not deduplicated like the wall box itself).

Skirting SHALL occupy `y ∈ [0, 0.08]`. Cornice SHALL occupy `y ∈ [CELL_HEIGHT - 0.08, CELL_HEIGHT]`. Trim face types SHALL use `skirting_*` and `cornice_*` prefixes.

#### Scenario: Wall edge produces skirting and cornice on the cell-interior side
- **WHEN** a visible cell has a `WALL` on its NORTH edge
- **THEN** the returned faces SHALL include face types matching `skirting_north_*` and `cornice_north_*` for that cell
- **AND** skirting vertices SHALL satisfy `0 ≤ y ≤ 0.08`
- **AND** cornice vertices SHALL satisfy `1.92 ≤ y ≤ 2.0`

#### Scenario: OPEN edge has no trim
- **WHEN** a visible cell has an `OPEN` edge in some direction
- **THEN** no `skirting_*` or `cornice_*` face SHALL be generated for that direction

#### Scenario: Door edge produces trim
- **WHEN** a visible cell has a `DOOR` on its NORTH edge
- **THEN** the returned faces SHALL include `skirting_north_*` and `cornice_north_*` for that cell

### Requirement: Door geometry is a frame plus recessed panel
CellMeshBuilder SHALL render a `DOOR` edge as a four-element assembly: a stone lintel along the top of the opening, a stone jamb on each side, and a wooden door panel recessed into the opening. The lintel SHALL occupy the top 0.20 of the door height with full edge width and the wall thickness T=0.20. Each jamb SHALL be 0.18 wide (along the edge axis), full height below the lintel (1.80), and thickness T=0.20. The door panel SHALL fill the remaining opening: width = CELL_SIZE - 2*0.18 = 1.64, height = 1.80, thickness 0.04, recessed 0.10 from the wall's center axis (so it sits flush with the back face of the wall, opening toward the cell interior).

Frame elements SHALL use the stone wall color. The door panel SHALL use the door (warm brown) color so that the existing wood-plank shader pattern applies. Face types SHALL use `door_lintel_*`, `door_jamb_left_*`, `door_jamb_right_*`, and `door_panel_*` prefixes.

The door assembly SHALL be deduplicated like a regular wall (one assembly per shared DOOR edge, not one per cell).

#### Scenario: DOOR edge generates the four assembly elements
- **WHEN** `build_meshes` is called with a visible cell that has a `DOOR` on its NORTH edge
- **THEN** the returned faces SHALL include face types matching `door_lintel_*`, `door_jamb_left_*`, `door_jamb_right_*`, and `door_panel_*` for that edge
- **AND** SHALL NOT include the legacy single `door_north` face type

#### Scenario: Door panel is recessed from the wall axis
- **WHEN** a DOOR is generated on the NORTH edge of cell at grid (3, 2)
- **THEN** the door panel front face vertices SHALL satisfy `z ≈ gy*2 + 0.10` (recessed 0.10 toward the cell interior from the wall center axis at z = 4.0)

#### Scenario: Lintel sits at the top of the opening
- **WHEN** a DOOR is generated on any edge
- **THEN** the lintel face vertices SHALL satisfy `1.80 ≤ y ≤ 2.00`

#### Scenario: Jambs sit at each side of the opening
- **WHEN** a DOOR is generated on the NORTH edge of cell at grid (3, 2)
- **THEN** the left jamb vertices SHALL satisfy `6.00 ≤ x ≤ 6.18` (along edge axis)
- **AND** the right jamb vertices SHALL satisfy `7.82 ≤ x ≤ 8.00`

#### Scenario: Shared DOOR edge produces one assembly
- **WHEN** `build_meshes` is called with two adjacent visible cells that share a `DOOR` edge between them
- **THEN** exactly one set of `door_lintel_*`, `door_jamb_left_*`, `door_jamb_right_*`, and `door_panel_*` faces SHALL appear in the returned face list (not two)
