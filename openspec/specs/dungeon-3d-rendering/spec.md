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
CellMeshBuilder SHALL generate 3D mesh vertex data for a single cell's visible walls, floor, and ceiling. Each cell occupies a 2.0 x 2.0 x 2.0 unit space. Floor is at Y=0, ceiling at Y=2.0.

#### Scenario: Cell with wall on NORTH edge
- **WHEN** CellMeshBuilder is given a cell at grid position (3, 2) with a WALL on the NORTH edge
- **THEN** it SHALL generate a vertical quad face at the north boundary of the cell (z = 2*2 = 4.0, spanning x from 6.0 to 8.0, y from 0.0 to 2.0)

#### Scenario: Cell with OPEN edge has no wall mesh
- **WHEN** CellMeshBuilder is given a cell at grid position (3, 2) with an OPEN NORTH edge
- **THEN** it SHALL NOT generate a wall face on the north side

#### Scenario: Cell with DOOR edge generates door-colored wall
- **WHEN** CellMeshBuilder is given a cell with a DOOR edge
- **THEN** it SHALL generate a wall face with the door material (visually distinct from regular walls)

#### Scenario: Floor and ceiling are always generated
- **WHEN** CellMeshBuilder is given any visible cell
- **THEN** it SHALL generate a floor quad at Y=0 and a ceiling quad at Y=2.0 for that cell

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
The rendering system SHALL visually distinguish between WALL edges, DOOR edges, and OPEN edges under the lit dungeon environment. WALL edges SHALL render as a neutral stone-gray surface. DOOR edges SHALL render as a warm brown surface visually distinct from WALL. OPEN edges SHALL render no surface. Exact RGB values are implementation details (chosen so that readability is preserved after torch illumination and fog darken the scene).

#### Scenario: Wall renders as stone gray
- **WHEN** a cell has a WALL edge facing the player
- **THEN** it SHALL be rendered with a neutral gray base tint that appears as stone under the torch light

#### Scenario: Door renders as warm brown
- **WHEN** a cell has a DOOR edge facing the player
- **THEN** it SHALL be rendered with a warm brown base tint that is perceptibly distinct from the WALL tint under torch light

#### Scenario: Open edge renders nothing
- **WHEN** a cell has an OPEN edge facing the player
- **THEN** no surface SHALL be rendered on that edge

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
DungeonScreen SHALL listen for the M key in `_unhandled_input` and SHALL toggle the visibility of `FullMapOverlay` on key press. The M key SHALL be ignored when an encounter is active or when the return-to-town dialog is visible.

#### Scenario: M key opens the overlay when closed
- **WHEN** DungeonScreen is active (no encounter, no return dialog) and the overlay is hidden, and the user presses the M key
- **THEN** `FullMapOverlay.open()` SHALL be invoked and the overlay SHALL become visible

#### Scenario: M key closes the overlay when open
- **WHEN** the overlay is visible and the user presses the M key
- **THEN** `FullMapOverlay.close()` SHALL be invoked and the overlay SHALL become hidden

#### Scenario: M key is ignored during encounter
- **WHEN** DungeonScreen has `_encounter_active == true` and the user presses the M key
- **THEN** the overlay SHALL NOT change state (remains hidden if it was hidden)

#### Scenario: M key is ignored during return dialog
- **WHEN** DungeonScreen has `_showing_return_dialog == true` and the user presses the M key
- **THEN** the overlay SHALL NOT change state

#### Scenario: M key echo events are ignored
- **WHEN** an M key event with `event.echo == true` is received
- **THEN** the overlay SHALL NOT toggle (only the initial press counts)

### Requirement: DungeonScreen blocks movement input while the FullMapOverlay is visible
DungeonScreen SHALL ignore movement and turn key inputs (UP/W, DOWN/S, LEFT/A, RIGHT/D) while `FullMapOverlay.is_open() == true`. This SHALL prevent the player from moving or rotating while inspecting the full map.

#### Scenario: Movement key does not move the player while overlay is visible
- **WHEN** the overlay is visible and the user presses the UP key
- **THEN** the player position SHALL NOT change and DungeonScene SHALL NOT rebuild

#### Scenario: Turn key does not rotate the player while overlay is visible
- **WHEN** the overlay is visible and the user presses the LEFT key
- **THEN** the player facing SHALL NOT change and the minimap SHALL NOT refresh (it is hidden anyway)

#### Scenario: Movement is restored after the overlay closes
- **WHEN** the overlay is closed and the user presses the UP key
- **THEN** the player SHALL move forward as normal (input handling resumes)

