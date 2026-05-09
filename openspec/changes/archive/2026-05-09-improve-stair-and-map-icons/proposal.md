## Why

Dungeon landmark tiles currently do not communicate their meanings clearly enough. In the 3D view, `START`, `STAIRS_UP`, and `STAIRS_DOWN` all use the same upward-stair mesh, while the map renderers use simple line markers that make stairs and destination tiles hard to distinguish at a glance.

## What Changes

- Distinguish the 3D landmark geometry for upward stairs, downward stairs, and goal tiles.
- Render `STAIRS_UP` as a more legible upward stone stairway.
- Render `STAIRS_DOWN` as a floor opening with a dark pit and descending steps.
- Render `START` as the same ordinary upward stairway as `STAIRS_UP`.
- Render `GOAL` as a destination altar or stone marker.
- Replace line-only map markers with image-generated stair icons for minimap and full-map rendering.
- Use cleaned-up PNG stair icon assets based on `tmp/kaidan.jpeg` reference B for upward stairs and reference 10 for downward stairs.
- Preserve existing dungeon movement, floor transition, exploration, and map visibility behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dungeon-3d-rendering`: Landmark tile meshes shall render `START`/`STAIRS_UP` as ordinary upward stairs, `STAIRS_DOWN` as a pit with descending stairs, and `GOAL` as an altar tile.
- `minimap-renderer`: The 87x87 minimap shall draw distinct imported image icons for explored `START`, `STAIRS_UP`, `STAIRS_DOWN`, and `GOAL` tiles.
- `full-map-renderer`: The full map shall draw distinct imported image icons for explored `START`, `STAIRS_UP`, `STAIRS_DOWN`, and `GOAL` tiles.

## Impact

- `src/dungeon/cell_mesh_builder.gd`: Split current shared stair mesh generation into tile-specific landmark geometry.
- `src/dungeon/minimap_renderer.gd`: Increase minimap raster resolution and replace the shared start/stair marker with imported stair icon rendering.
- `src/dungeon/full_map_renderer.gd`: Replace single-line markers with imported stair icon rendering that fits within explored cell floor bounds.
- `assets/images/map_icons/stairs_up.png`, `assets/images/map_icons/stairs_down.png`: Add cleaned-up generated stair icon assets and Godot import metadata.
- `tests/dungeon/test_cell_mesh_builder.gd`: Add/adjust geometry tests for landmark tile face types and bounds.
- `tests/dungeon/test_minimap_renderer.gd`: Add/adjust pixel tests for the four minimap icons and precedence with the player marker.
- `tests/dungeon/test_full_map_renderer.gd`: Add/adjust pixel tests for the four full-map icons and precedence with the player marker.
