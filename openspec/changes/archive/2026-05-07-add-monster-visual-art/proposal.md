## Why

The combat screen currently represents living enemies with procedural dummy rectangles, which makes encounters harder to read and keeps the visual presentation below the intended direction. The shipped monster roster is small enough to establish the real monster-art pipeline now and replace the dummy-only battle presentation.

## What Changes

- Add generated monster image assets for the six existing shipped monsters: `slime`, `goblin`, `bat`, `skeleton`, `ghost`, and `dragon`.
- Extend monster data so each shipped monster can reference its own battle visual.
- Update the combat monster panel to render monster-specific images for living enemies when art is available.
- Preserve a dummy/procedural fallback for missing monster art so future monsters or incomplete data do not break combat rendering.
- Keep the existing enemy species/count list, per-individual HP hiding, and stable lower baseline behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `monster-data`: MonsterData resources shall expose an optional battle visual reference, and the six shipped monster data files shall reference generated monster art.
- `combat-overlay`: The battle enemy presentation area shall render monster-specific visual art when available, falling back to the existing dummy visual only when art is missing.

## Impact

- Affected code:
  - `src/dungeon/data/monster_data.gd`
  - `src/dungeon_scene/combat/combat_monster_panel.gd`
  - `data/monsters/*.tres`
  - `tests/dungeon/test_monster_data.gd`
  - `tests/dungeon/test_combat_overlay.gd`
- New assets:
  - `assets/images/monsters/slime.png`
  - `assets/images/monsters/goblin.png`
  - `assets/images/monsters/bat.png`
  - `assets/images/monsters/skeleton.png`
  - `assets/images/monsters/ghost.png`
  - `assets/images/monsters/dragon.png`
- No new runtime dependency is expected. Images are generated during development and committed as regular Godot assets.
