## Context

The dungeon visual stack is intentionally lightweight. `DungeonScene` owns camera, light, environment, and an `ImmediateMesh`, while `CellMeshBuilder` generates per-cell wall, floor, ceiling, door, and landmark faces. Map rendering writes `Image` instances directly: `MinimapRenderer` now uses an 87x87 raster so icons have enough pixels to read as stairs, and `FullMapRenderer` writes a fitted floor image using direct pixel operations.

The current landmark rendering is overloaded. `CellMeshBuilder` generates the same upward-stair faces for `START`, `STAIRS_DOWN`, and `STAIRS_UP`. `MinimapRenderer` draws the same small marker for start and stair tiles, and `FullMapRenderer` uses simple line markers for special tiles. This change improves readability without changing movement/floor-transition logic.

## Goals / Non-Goals

**Goals:**

- Give each landmark tile a distinct visual identity in 3D and map views.
- Make `STAIRS_DOWN` read as a hole in the floor with descending steps.
- Make `STAIRS_UP` read as a stairway, not just a flat marker.
- Make `START` read as the same ordinary stairway as `STAIRS_UP`, without a special return-to-town shape.
- Make `GOAL` read as a destination altar or stone marker.
- Use image-generated white stair icons based on `tmp/kaidan.jpeg` reference B for up stairs and reference 10 for down stairs.
- Keep all generated geometry inside the owning cell bounds.
- Keep all map icons inside explored cell floor pixels and preserve player marker precedence.

**Non-Goals:**

- No movement, encounter, floor transition, dungeon generation, or save-data behavior changes.
- No imported 3D models or 3D texture pipeline.
- No new tile types.
- No camera, lighting, fog, shader, or UI layout redesign beyond supporting the new geometry/icons.

## Decisions

1. Keep procedural mesh generation in `CellMeshBuilder`.

   The existing render path already expects `CellMeshBuilder.Face` entries with vertex colors consumed by the dungeon shader. Adding tile-specific helpers such as `_add_stairs_up`, `_add_stairs_down`, and `_add_goal_altar` keeps the behavior testable through face types and vertex bounds. The alternative, adding separate scene nodes or imported meshes, would require lifecycle management and asset handling that the current renderer does not need.

2. Treat `START` as ordinary upward stairs.

   The latest visual direction is that the town-return stair should not be special; it should be a normal stair. Therefore `START` reuses the same upward stair geometry and map icon as `STAIRS_UP`.

3. Render `STAIRS_DOWN` with an above-floor dark opening and descending steps.

   Godot mesh geometry can stay simple: a dark pit surface or bottom plane, rim faces, and step/riser faces descending visually into the opening. The mesh does not need real negative-depth gameplay collision because the dungeon view is decorative; vertex bounds still need to remain within the cell volume expected by current tests and rendering assumptions.

4. Use image-generated stair icon assets for both map renderers.

   The stair icons are cleaned-up PNG assets generated from `tmp/kaidan.jpeg`: reference B for upward stairs and reference 10 for downward stairs. They use white/light-gray stair surfaces, visible step lines, and dark wall/shadow areas rather than cyan markers. Renderers load these assets through Godot's imported `Texture2D` resources and sample them into each map cell.

5. Increase minimap raster detail.

   The old 3x3 floor pixels could not express the requested stair step details. The minimap now uses a 9x9 floor pixel area per visible cell, allowing the generated stair icons to retain recognizable step lines.

6. Keep icon drawing after floor/edge drawing and before player drawing.

   This preserves existing layering: explored floor is always drawn first, landmark icons overlay only explored cells, and the player marker remains dominant when standing on a special tile.

## Risks / Trade-offs

- Imported image icons can lose detail when sampled into small cells -> Keep the minimap at 9x9 floor pixels and retain simple fallback patterns if the asset cannot load.
- More 3D faces per landmark tile could slightly increase mesh size -> Landmark tiles are rare, so the performance impact is negligible.
- Shader alpha is already used as a surface-kind flag -> Reuse existing color conventions and avoid introducing transparent rendering assumptions.
- Full-map icons must work at very small cell sizes -> Implement bounds-aware drawing with minimum symbolic pixels rather than fixed large shapes.
