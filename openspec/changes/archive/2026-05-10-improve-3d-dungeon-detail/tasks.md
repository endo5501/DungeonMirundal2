## 1. Refactor to per-batch mesh building (no visual change)

- [x] 1.1 Add a failing test that asserts `CellMeshBuilder.build_meshes(visible_cells, wiz_map)` exists and returns a face list with one floor and one ceiling face per visible cell
- [x] 1.2 Implement `build_meshes` by iterating `visible_cells` and aggregating `build_faces(cell, pos)` results (still per-cell internally)
- [x] 1.3 Add a failing test that asserts `DungeonScene._rebuild_mesh` (or equivalent) calls `build_meshes` with the visible cells set
- [x] 1.4 Update `DungeonScene._rebuild_mesh` to call `build_meshes` instead of looping `build_faces` directly
- [x] 1.5 Verify existing tests in `tests/dungeon/test_cell_mesh_builder.gd` still pass with the new code path
- [x] 1.6 Commit (refactor: introduce per-batch CellMeshBuilder.build_meshes)

## 2. Edge deduplication and thick wall boxes

- [x] 2.1 Add a failing test: shared WALL edge between two visible cells produces exactly one set of `wall_*_*` faces (not two)
- [x] 2.2 Add a failing test: WALL edge generates a 6-face box (`wall_<dir>_inner`, `wall_<dir>_outer`, `wall_<dir>_top`, `wall_<dir>_bottom`, `wall_<dir>_east`, `wall_<dir>_west`) with thickness T=0.20 centered on the edge
- [x] 2.3 Update `test_wall_north_generates_quad`, `test_wall_vertices_at_correct_position`, `test_all_four_walls_default` to reflect the new box face structure (use the inner face as the canonical "the wall is here" assertion)
- [x] 2.4 Implement edge enumeration helper that yields unique (cell, direction) pairs from the visible_cells set
- [x] 2.5 Implement `_add_wall_box(faces, cell_pos, dir, edge_type)` that emits the 6 faces for a wall box of thickness T=0.20
- [x] 2.6 Wire `build_meshes` to call the edge enumerator and `_add_wall_box` for WALL edges (DOOR temporarily uses the same box, replaced in section 5)
- [x] 2.7 Run the project locally and visually confirm walls have visible thickness at corners; capture before/after screenshot
- [x] 2.8 Commit (feat: render dungeon walls as thick boxes with edge deduplication)

## 3. Corner pillars

- [x] 3.1 Add a failing test: a 3x3 region of fully-OPEN cells produces no `pillar_*` faces at the 4 inner corners
- [x] 3.2 Add a failing test: corner with at least one WALL or DOOR edge among its 4 meeting edges produces exactly one set of `pillar_*` faces
- [x] 3.3 Add a failing test: cross-intersection corner (4 WALL edges meeting) produces exactly one pillar (not four)
- [x] 3.4 Add a failing test: pillar dimensions match the spec (0.25 x 2.0 x 0.25, centered at corner)
- [x] 3.5 Add a failing test: map boundary corner gets a pillar (treating off-map edges as WALL)
- [x] 3.6 Implement corner enumeration helper that yields unique corners (i, j) adjacent to visible cells
- [x] 3.7 Implement corner-WALL detection helper that checks the 4 meeting edges (treating off-map as WALL)
- [x] 3.8 Implement `_add_pillar(faces, corner)` that emits a 6-face box at the corner using `PILLAR_COLOR`
- [x] 3.9 Define `PILLAR_COLOR = Color(0.45, 0.43, 0.38, STONE_ALPHA)` near the existing color constants
- [x] 3.10 Wire `build_meshes` to call the corner enumerator and `_add_pillar`
- [x] 3.11 Visual confirm pillars only appear at wall-touching corners; commit (feat: place corner pillars at wall-touching grid corners)

## 4. Skirting and cornice trim

- [x] 4.1 Add a failing test: WALL edge produces `skirting_<dir>_*` faces with `0 ≤ y ≤ 0.08`
- [x] 4.2 Add a failing test: WALL edge produces `cornice_<dir>_*` faces with `1.92 ≤ y ≤ 2.0`
- [x] 4.3 Add a failing test: OPEN edge produces no `skirting_*` or `cornice_*` faces
- [x] 4.4 Add a failing test: DOOR edge produces `skirting_*` and `cornice_*` faces
- [x] 4.5 Implement `_add_skirting(faces, cell_pos, dir)` and `_add_cornice(faces, cell_pos, dir)` that emit thin boxes (height 0.08, projection 0.04 from wall surface, length CELL_SIZE)
- [x] 4.6 Wire `build_meshes` to emit trim per cell-side for each WALL/DOOR edge (note: trim is NOT deduplicated; one per visible cell side)
- [x] 4.7 Visual confirm trim is visible at floor and ceiling joints; commit (feat: add skirting and cornice trim along walls)

## 5. Door frame and recessed panel

- [x] 5.1 Add a failing test: DOOR edge generates `door_lintel_*`, `door_jamb_left_*`, `door_jamb_right_*`, and `door_panel_*` face groups
- [x] 5.2 Add a failing test: door panel is recessed 0.10 from the wall center axis
- [x] 5.3 Add a failing test: lintel sits at `1.80 ≤ y ≤ 2.00`
- [x] 5.4 Add a failing test: left jamb width is 0.18 along the edge axis, right jamb is 0.18
- [x] 5.5 Add a failing test: shared DOOR edge between two visible cells produces exactly one assembly
- [x] 5.6 Update `test_door_generates_door_face` to assert the new assembly faces (replace the single `door_north` expectation)
- [x] 5.7 Implement `_add_door_assembly(faces, cell_pos, dir)` that emits lintel + 2 jambs + panel boxes with stone color for frame and door color for panel
- [x] 5.8 Replace the WALL-box-for-DOOR fallback from section 2 with the door assembly call
- [x] 5.9 Visual confirm doors render with frame and recessed panel; commit (feat: render doors as frame plus recessed panel assembly)

## 6. Final visual review and cleanup

- [x] 6.1 Take final screenshots from a corridor, a room corner, and a doorway; compare against tmp/dungeon16.png to confirm the "paper wall" feel is gone (confirmed by user)
- [x] 6.2 Run the full test suite (`tests/dungeon/test_cell_mesh_builder.gd` and any related) and confirm all green (2369/2369 passing)
- [x] 6.3 Remove any dead helper code left from the refactor (e.g. unused `_add_wall_face` if fully replaced)
- [x] 6.4 Commit (chore: clean up legacy single-quad wall helpers)
