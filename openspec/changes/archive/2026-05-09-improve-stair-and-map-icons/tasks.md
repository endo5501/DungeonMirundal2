## 1. 3D Landmark Geometry Tests

- [x] 1.1 Update `tests/dungeon/test_cell_mesh_builder.gd` so `START` expects ordinary `stairs_up_*` face types and no special return face types.
- [x] 1.2 Add `STAIRS_UP` mesh tests that expect upward stair face types and verify floor/ceiling are still generated.
- [x] 1.3 Add `STAIRS_DOWN` mesh tests that expect pit/opening face types plus descending stair face types.
- [x] 1.4 Add `GOAL` mesh tests that expect altar/stone marker face types.
- [x] 1.5 Add a shared bounds test proving all landmark vertices for `START`, `STAIRS_UP`, `STAIRS_DOWN`, and `GOAL` remain inside the owning cell volume.
- [x] 1.6 Run the targeted cell mesh tests and confirm the new tests fail before implementation.

## 2. 3D Landmark Geometry Implementation

- [x] 2.1 Refactor `src/dungeon/cell_mesh_builder.gd` so landmark dispatch is tile-specific instead of using the same stair helper for all special tiles.
- [x] 2.2 Implement `START` as ordinary upward stair geometry with identifiable `stairs_up_*` face type prefixes and existing shader-compatible vertex colors.
- [x] 2.3 Implement improved `STAIRS_UP` stone step geometry with identifiable face type prefixes.
- [x] 2.4 Implement `STAIRS_DOWN` pit rim/dark opening and descending step geometry with identifiable face type prefixes.
- [x] 2.5 Implement `GOAL` altar or stone marker geometry with identifiable face type prefixes.
- [x] 2.6 Run the targeted cell mesh tests until they pass.

## 3. Minimap Icon Tests

- [x] 3.1 Update `tests/dungeon/test_minimap_renderer.gd` so explored `START` expects the same ordinary upward stair icon as `STAIRS_UP`.
- [x] 3.2 Add explored `STAIRS_UP` and `STAIRS_DOWN` minimap icon tests proving the two stair icons are distinct.
- [x] 3.3 Add explored `GOAL` minimap icon tests proving the goal icon is distinct from floor/player colors.
- [x] 3.4 Add or extend minimap bounds tests so all landmark icons stay inside the high-resolution floor area and do not overwrite wall gaps.
- [x] 3.5 Add or extend minimap precedence tests so the player marker overrides every landmark icon on the center cell.
- [x] 3.6 Run the targeted minimap tests and confirm the new tests fail before implementation.

## 4. Minimap Icon Implementation

- [x] 4.1 Refactor `src/dungeon/minimap_renderer.gd` landmark marker drawing into tile-specific icon helpers.
- [x] 4.2 Implement high-resolution minimap icon sampling from generated PNG stair assets for `START`, `STAIRS_UP`, and `STAIRS_DOWN`, plus the GOAL icon.
- [x] 4.3 Ensure unexplored landmark cells still render no icon and player drawing remains last.
- [x] 4.4 Run the targeted minimap tests until they pass.

## 5. Full Map Icon Tests

- [x] 5.1 Update `tests/dungeon/test_full_map_renderer.gd` so explored `START` expects the same ordinary upward stair icon as `STAIRS_UP` rather than a generic line marker.
- [x] 5.2 Add explored `STAIRS_UP` and `STAIRS_DOWN` full-map icon tests proving the two stair icons are distinct.
- [x] 5.3 Add explored `GOAL` full-map icon tests for the altar/goal icon.
- [x] 5.4 Add or extend full-map bounds tests so landmark icons stay inside the floor area at both typical and minimum cell sizes.
- [x] 5.5 Add or extend full-map precedence tests so the player marker overrides every landmark icon when occupying the same cell.
- [x] 5.6 Run the targeted full-map tests and confirm the new tests fail before implementation.

## 6. Full Map Icon Implementation

- [x] 6.1 Refactor `src/dungeon/full_map_renderer.gd` marker drawing into tile-specific icon helpers.
- [x] 6.2 Implement scalable image icon sampling for `START`, `STAIRS_UP`, `STAIRS_DOWN`, and `GOAL` that degrades gracefully at `MIN_CELL_PX`.
- [x] 6.3 Ensure unexplored landmark cells still render no icon and player drawing remains last.
- [x] 6.4 Run the targeted full-map tests until they pass.

## 7. Integration Verification

- [x] 7.1 Run targeted dungeon renderer tests covering cell mesh, minimap renderer, and full-map renderer.
- [x] 7.2 Run `.\scripts\run_tests.ps1` for the full suite.
- [x] 7.3 Manually inspect the generated `stairs_up.png` and `stairs_down.png` assets to confirm they read as white stair icons with dark stairwell/shadow detail.
