## Purpose
ダンジョンの 1 人称 3D 描画に関する表示ルールを規定する。壁・床・天井のテクスチャ、視野角、カメラ位置、向き変更時のスムージングなどを対象とする。
## Requirements
### Requirement: DungeonView calculates visible cells
DungeonView SHALL calculate the set of visible cells from the player's current position and facing direction. The view SHALL extend up to 4 cells forward and 1 cell to each side. Cells behind walls SHALL NOT be included in the visible set. Lateral visibility SHALL be evaluated independently at each depth so that an opening at depth N is not hidden by a wall at a shallower depth. The 3D rasterizer's depth buffer handles the actual geometric occlusion between the nearer wall and the deeper cell.

When the caller requests `fill_openings = true` (the 3D renderer's path), DungeonView SHALL additionally flood-fill one hop from each visible cell across `EdgeType.OPEN` edges so that visible openings never reveal an un-meshed black void. The exploration / minimap path SHALL leave `fill_openings` at its default of `false` so that revealed cells stay tied to strict line-of-sight.

#### Scenario: Forward view in open corridor
- **WHEN** player is at position (5, 5) facing NORTH with no walls in the forward path for 4 cells
- **THEN** DungeonView SHALL return cells at (5,5), (5,4), (5,3), (5,2), (5,1) and lateral cells (4,4), (6,4), (4,3), (6,3), (4,2), (6,2), (4,1), (6,1)

#### Scenario: Wall blocks forward view
- **WHEN** player is at position (5, 5) facing NORTH and there is a wall on the NORTH edge of cell (5, 3)
- **THEN** DungeonView SHALL return cells up to (5,3) but NOT (5,2) or (5,1), and lateral cells SHALL also be cut at that depth

#### Scenario: Lateral wall blocks its own depth side cell
- **WHEN** player is at position (5, 5) facing NORTH and there is a wall on the WEST edge of cell (5, 4)
- **THEN** cell (4, 4) SHALL NOT be included in the visible set

#### Scenario: Lateral wall at one depth does not hide openings at other depths
- **WHEN** player is at position (5, 5) facing NORTH with a wall on the WEST edge of cell (5, 4) and OPEN west edges on (5, 3), (5, 2), (5, 1)
- **THEN** (4, 4) SHALL NOT be included but (4, 3), (4, 2), and (4, 1) SHALL all be included because each has its own lateral opening to inspect

#### Scenario: fill_openings pads the view for rendering
- **WHEN** DungeonView.get_visible_cells is called with `fill_openings = true` for a fully-open corridor starting at (5, 5) facing NORTH
- **THEN** the returned set SHALL include not only the strict line-of-sight cells but also the one-hop OPEN-edge neighbors of every included cell (e.g. (3, 5), (7, 5)), so that openings at the edge of the 3D frustum never reveal un-meshed black space

#### Scenario: Map boundary limits view
- **WHEN** player is at position (5, 1) facing NORTH with map size 10
- **THEN** DungeonView SHALL NOT include cells with y < 0

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

### Requirement: DungeonScene renders 3D view
DungeonScene (Node3D) SHALL render the dungeon from a first-person perspective using a Camera3D. The camera SHALL be positioned at the player's cell center at Y=1.0 (eye height) and face the player's current direction.

#### Scenario: Scene updates on player state change
- **WHEN** the player's position or direction changes
- **THEN** DungeonScene SHALL rebuild the visible mesh and update the Camera3D position and rotation

#### Scenario: Camera faces player direction
- **WHEN** the player is facing NORTH
- **THEN** the Camera3D SHALL face the negative Z direction (Godot's forward convention)

### Requirement: DungeonScreen composes the dungeon UI
DungeonScreen (Control) SHALL display the 3D dungeon view using a SubViewportContainer in the upper portion of the screen.

#### Scenario: Screen layout
- **WHEN** DungeonScreen is displayed
- **THEN** a SubViewportContainer with the 3D dungeon view SHALL occupy the upper area of the screen

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

### Requirement: Dungeon scene provides a camera-attached torch light
DungeonScene SHALL attach a single dynamic point light (Godot `OmniLight3D`) as a child of the player `Camera3D`, simulating a hand-held torch. The light SHALL use a warm color tint, have a finite range, and fall off with distance so that surfaces far from the camera receive substantially less illumination than nearby surfaces.

#### Scenario: Torch light exists on scene setup
- **WHEN** DungeonScene finishes `_ready()`
- **THEN** a single `OmniLight3D` SHALL be a child of the active `Camera3D`, with a warm (non-white) color and a finite `omni_range` greater than zero

#### Scenario: Torch light follows the camera
- **WHEN** the player changes position or facing and DungeonScene rebuilds the camera transform
- **THEN** the torch light SHALL remain a child of the camera so that its world position/rotation follows the camera without any additional update code

#### Scenario: Distant surfaces receive less light than near surfaces
- **WHEN** two identical wall surfaces exist, one within the torch `omni_range` and another beyond it
- **THEN** the far surface SHALL render darker than the near surface under the same material

### Requirement: Dungeon scene configures a dark environment with fog
DungeonScene SHALL own a `WorldEnvironment` node configured so that the global ambient illumination is very low (near black) and depth fog is enabled with a dark fog color. The environment SHALL be set up once and SHALL NOT require rebuilding when the player moves.

#### Scenario: Ambient light is dim
- **WHEN** DungeonScene finishes `_ready()`
- **THEN** the attached `Environment`'s `ambient_light_color` luminance SHALL be below 0.1 (near-black) so that unlit surfaces appear dark

#### Scenario: Depth fog is enabled
- **WHEN** DungeonScene finishes `_ready()`
- **THEN** the attached `Environment` SHALL have `fog_enabled = true` with a dark `fog_light_color`

#### Scenario: Environment persists across movement
- **WHEN** the player moves or rotates and the visible mesh is rebuilt
- **THEN** the existing `WorldEnvironment` SHALL be reused (NOT recreated) and its settings SHALL NOT change

### Requirement: Wall surfaces use a procedural stone shader
DungeonScene SHALL apply a custom `ShaderMaterial` (spatial; self-lit via a procedural torch term) to the dungeon mesh. The shader SHALL compute surface detail procedurally without requiring UV coordinates on the mesh vertices, using world-space vertex positions and face normals as inputs. The shader SHALL:
1. Tint output by the incoming vertex color (tile-type identity: wall / floor / ceiling / door / stairs),
2. Modulate the albedo with a world-space pseudo-noise pattern for stone speckling,
3. Add a brick / masonry line pattern on vertical wall surfaces by quantizing world-space coordinates,
4. Darken fragments further from the camera (pseudo distance-AO) as an additional multiplicative factor on top of lighting and fog.

The shader SHALL NOT require modifications to `CellMeshBuilder` to emit UVs.

#### Scenario: Shader is applied on scene setup
- **WHEN** DungeonScene finishes `_ready()`
- **THEN** the `MeshInstance3D`'s surface override material SHALL be a `ShaderMaterial` (not `StandardMaterial3D`)

#### Scenario: Tile type tinting is preserved
- **WHEN** two cells render with different tile-type colors emitted by `CellMeshBuilder` (e.g. wall vs door)
- **THEN** the rendered result SHALL retain a perceptible hue difference between the two tile types under the same lighting

#### Scenario: Wall surfaces show brick-line pattern
- **WHEN** a wall face renders under the shader
- **THEN** the fragment output SHALL contain a non-uniform pattern derived from world-space coordinates (not a single solid color) visible as brick/masonry lines

#### Scenario: Distance attenuation darkens far surfaces
- **WHEN** two surfaces with identical material and lighting exist, one near the camera and one far from it
- **THEN** the far surface SHALL render darker than the near surface due to the shader's distance term, independently of torch light falloff

#### Scenario: No UVs required
- **WHEN** the mesh is rebuilt by `DungeonScene._rebuild_mesh()` without any call to `surface_set_uv()`
- **THEN** the shader SHALL still render stone / brick patterns correctly based on world-space coordinates

#### Scenario: Door surfaces use a distinct plank pattern
- **WHEN** a vertical face is rendered with a door-warm base color (door tile type)
- **THEN** the shader SHALL suppress the stone-brick pattern on that face and apply a wooden plank pattern (vertical grooves plus at least one horizontal cross-band) so that doors read as doors rather than tinted walls

### Requirement: DungeonScreen toggles the FullMapOverlay with the M key
DungeonScreen SHALL listen for `is_action_pressed("toggle_full_map")` (the InputMap action bound to KEY_M) in `_unhandled_input` and SHALL toggle the visibility of `FullMapOverlay` on action press. The action SHALL be ignored when an encounter is active or when the return-to-town dialog is visible.

#### Scenario: toggle_full_map opens the overlay when closed
- **WHEN** DungeonScreen is active (no encounter, no return dialog) and the overlay is hidden, and an event matching `is_action_pressed("toggle_full_map")` is dispatched
- **THEN** `FullMapOverlay.open()` SHALL be invoked and the overlay SHALL become visible

#### Scenario: toggle_full_map closes the overlay when open
- **WHEN** the overlay is visible and `is_action_pressed("toggle_full_map")` is dispatched
- **THEN** `FullMapOverlay.close()` SHALL be invoked and the overlay SHALL become hidden

#### Scenario: toggle_full_map is ignored during encounter
- **WHEN** DungeonScreen has `_encounter_active == true` and `is_action_pressed("toggle_full_map")` is dispatched
- **THEN** the overlay SHALL NOT change state

#### Scenario: toggle_full_map is ignored during return dialog
- **WHEN** DungeonScreen has `_showing_return_dialog == true` and `is_action_pressed("toggle_full_map")` is dispatched
- **THEN** the overlay SHALL NOT change state

#### Scenario: Echo events are ignored
- **WHEN** an action event with `event.echo == true` is received
- **THEN** the overlay SHALL NOT toggle (only the initial press counts; this is the InputMap's default behavior for non-pressed/echo events)

### Requirement: DungeonScreen blocks movement input while the FullMapOverlay is visible
DungeonScreen SHALL ignore movement and turn actions (`move_forward`, `move_back`, `strafe_left`, `strafe_right`, `turn_left`, `turn_right`) while `FullMapOverlay.is_open() == true`.

#### Scenario: move_forward action does not move the player while overlay is visible
- **WHEN** the overlay is visible and `is_action_pressed("move_forward")` is dispatched
- **THEN** the player position SHALL NOT change and DungeonScene SHALL NOT rebuild

#### Scenario: turn_left action does not rotate the player while overlay is visible
- **WHEN** the overlay is visible and `is_action_pressed("turn_left")` is dispatched
- **THEN** the player facing SHALL NOT change

#### Scenario: Movement is restored after the overlay closes
- **WHEN** the overlay is closed and `is_action_pressed("move_forward")` is dispatched
- **THEN** the player SHALL move forward as normal (input handling resumes)

### Requirement: DungeonScene.refresh は visible_cells を必ず受け取る
SHALL: `DungeonScene.refresh(visible_cells: Array[Vector2i])` は呼び出し側から `visible_cells` を必ず渡される前提で動作する。空配列での fallback として内部で `DungeonView` を保持する仕組みは存在しない。`_dungeon_view: DungeonView` フィールドおよび `refresh` 内の null/empty fallback 分岐は削除される。

#### Scenario: refresh は呼び出し側のセル情報を必ず使う
- **WHEN** `DungeonScreen.refresh()` が `DungeonScene.refresh(cells)` を呼ぶ
- **THEN** `cells` の内容で 3D シーンが再構築され、`_dungeon_view` を経由した fallback はない

#### Scenario: 旧 _dungeon_view フィールドは存在しない
- **WHEN** `dungeon_scene.gd` を grep する
- **THEN** `_dungeon_view: DungeonView` フィールドおよび関連の fallback ロジックは存在しない

### Requirement: DungeonScreen refreshes the SubViewport on window resize

`DungeonScreen` (Control) SHALL detect window/control resize events and re-trigger a single SubViewport update so that the dungeon 3D rendering remains visible after the user resizes the game window. The existing optimization of using `SubViewport.UPDATE_DISABLED` between explicit refreshes (driven by player movement and rotation) SHALL be preserved; only one additional `UPDATE_ONCE` SHALL be issued per resize event.

The detection SHALL be implemented via Godot's `_notification(NOTIFICATION_RESIZED)` (or an equivalent resize signal) on `DungeonScreen` itself. The handler SHALL re-arm the SubViewport directly by setting `_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE`. The handler SHALL NOT call `_refresh_all()` on resize: the existing `ImmediateMesh` and camera transform remain valid (the player has not moved), so a re-render of the existing geometry into the new framebuffer is sufficient. Calling `_refresh_all()` would additionally re-mark explored cells (semantically incorrect — a resize is not exploration), rebuild the mesh, and refresh the minimap, which is unnecessary work.

When the resize notification fires before `_ready()` has constructed `_sub_viewport` (e.g. during a parent layout pass that fires earlier in the lifecycle), the handler SHALL be a no-op.

#### Scenario: Resizing the window re-renders the dungeon
- **WHEN** the player is in a dungeon room and resizes the OS window from one size to another
- **THEN** the dungeon 3D view SHALL remain visible after the resize completes (the SubViewport SHALL NOT be left blank/black)

#### Scenario: Resize before SubViewport construction is a no-op
- **WHEN** `DungeonScreen` receives a `NOTIFICATION_RESIZED` notification before `_ready()` has run (so `_sub_viewport` is null)
- **THEN** the handler SHALL return early without touching `_sub_viewport` and without crashing

#### Scenario: Resize after _ready does not invoke _refresh_all
- **WHEN** `DungeonScreen` receives a `NOTIFICATION_RESIZED` notification after `_ready()` has run
- **THEN** the handler SHALL set `_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE` directly
- **AND** the handler SHALL NOT call `_refresh_all()` (no `_explored_map.mark_visible` mutation, no mesh rebuild, no minimap refresh)

#### Scenario: Movement-driven refresh is unchanged
- **WHEN** the player moves forward, backward, sideways, or rotates
- **THEN** `_refresh_all()` SHALL still set `_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE` exactly as before, with no behavioral change for non-resize updates

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

#### Scenario: Door panel is recessed from the wall surface
- **WHEN** a DOOR is generated on the NORTH edge of cell at grid (3, 2)
- **THEN** the door panel front face vertices SHALL satisfy `z ≈ gy*2` (the panel front sits on the wall center axis at z = 4.0, recessed 0.10 from the cell-interior wall surface at z = gy*2 + T/2 = 4.10)

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

