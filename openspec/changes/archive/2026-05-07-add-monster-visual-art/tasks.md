## 1. Tests

- [x] 1.1 Add MonsterData tests for the optional `battle_texture` field and validation accepting null textures.
- [x] 1.2 Add shipped-data tests asserting the six existing monsters load with non-null battle textures.
- [x] 1.3 Add asset-path tests asserting the six generated monster PNG files exist under `assets/images/monsters/`.
- [x] 1.4 Update CombatMonsterPanel tests to cover texture-backed living monster visuals without requiring dummy rectangles.
- [x] 1.5 Add CombatMonsterPanel fallback coverage for a living monster with no battle texture.
- [x] 1.6 Run the focused failing tests and confirm the new expectations fail before implementation.

## 2. Monster Art Assets

- [x] 2.1 Generate a consistent battle image for `slime`.
- [x] 2.2 Generate a consistent battle image for `goblin`.
- [x] 2.3 Generate a consistent battle image for `bat`.
- [x] 2.4 Generate a consistent battle image for `skeleton`.
- [x] 2.5 Generate a consistent battle image for `ghost`.
- [x] 2.6 Generate a consistent battle image for `dragon`.
- [x] 2.7 Save all generated images as PNG assets under `assets/images/monsters/`.

## 3. Data Wiring

- [x] 3.1 Add `battle_texture: Texture2D` to `MonsterData`.
- [x] 3.2 Wire `data/monsters/slime.tres` to `assets/images/monsters/slime.png`.
- [x] 3.3 Wire `data/monsters/goblin.tres` to `assets/images/monsters/goblin.png`.
- [x] 3.4 Wire `data/monsters/bat.tres` to `assets/images/monsters/bat.png`.
- [x] 3.5 Wire `data/monsters/skeleton.tres` to `assets/images/monsters/skeleton.png`.
- [x] 3.6 Wire `data/monsters/ghost.tres` to `assets/images/monsters/ghost.png`.
- [x] 3.7 Wire `data/monsters/dragon.tres` to `assets/images/monsters/dragon.png`.

## 4. Combat Rendering

- [x] 4.1 Refactor `CombatMonsterPanel.refresh()` to retain living monster presentation entries with draw rects and optional textures.
- [x] 4.2 Render `battle_texture` entries in `_draw()` while preserving aspect ratio inside each visual slot.
- [x] 4.3 Preserve the existing procedural dummy drawing for entries without a texture.
- [x] 4.4 Preserve stable lower baseline positioning and enemy list window layout for one or more living monsters.
- [x] 4.5 Keep `get_display_text()` behavior and per-individual HP hiding unchanged.

## 5. Verification

- [x] 5.1 Run focused monster data and combat overlay tests.
- [x] 5.2 Run the full test wrapper `.\scripts\run_tests.ps1`.
- [x] 5.3 Inspect or capture the combat UI with an encounter containing multiple monster species to confirm generated images render instead of dummy rectangles.
- [x] 5.4 Review generated art consistency and replace any asset that reads poorly at combat-screen size.
