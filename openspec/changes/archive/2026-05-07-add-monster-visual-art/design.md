## Context

The current combat enemy presentation is implemented in `CombatMonsterPanel` as procedural dummy rectangles derived from the number of living enemies. Monster definitions are Godot `Resource` files under `data/monsters/`, and the six shipped monster ids are `slime`, `goblin`, `bat`, `skeleton`, `ghost`, and `dragon`.

This change introduces committed monster image assets and data references to those assets. Image generation is a development-time asset creation step; combat rendering must not depend on a network service, external API, or runtime image generation.

## Goals / Non-Goals

**Goals:**

- Generate and commit one battle image for each existing shipped monster.
- Store monster images under a stable project asset path.
- Let each `MonsterData` resource reference its battle image.
- Render monster-specific images in the combat enemy graphics area when the referenced texture exists.
- Preserve the existing dummy visual as a fallback for missing or invalid art.
- Preserve enemy count text, per-individual HP hiding, lower placement, and stable baseline behavior.

**Non-Goals:**

- Runtime AI image generation during battle.
- Animation, hit flashes, target highlighting, or per-monster selection via the image area.
- A generalized art-authoring tool inside the game.
- Character portrait art.
- Changing encounter generation, combat rules, target selection semantics, or reward behavior.

## Decisions

### Decision 1: Use committed PNG assets, not runtime generation

Monster images will be generated during development and committed as PNG files under `assets/images/monsters/`.

Rationale: Runtime generation would introduce latency, network availability, credentials, cost, nondeterminism, and packaging issues into a combat UI path that should be local and predictable. Committed assets keep battle rendering deterministic and testable.

Alternative considered: Generate images on first encounter and cache them. This would reduce upfront asset work, but it still couples gameplay to external generation and creates cache invalidation and offline behavior problems.

### Decision 2: Add an optional `Texture2D` reference to `MonsterData`

`MonsterData` should expose an exported `battle_texture: Texture2D` field. Each shipped `.tres` monster resource should reference its corresponding PNG through a normal Godot external resource.

Rationale: `MonsterData` is already the authoritative monster template. A typed `Texture2D` export integrates with Godot resource loading and avoids string-path load errors in the rendering code.

Alternative considered: Store `battle_texture_path: String`. This is simple for tests, but it pushes path validation into rendering and gives less help from Godot's resource system.

### Decision 3: Preserve fallback rendering inside `CombatMonsterPanel`

`CombatMonsterPanel` should collect presentation entries for living monsters. Each entry has a target draw rect and an optional texture. `_draw()` renders the texture when present and falls back to the existing procedural dummy for entries with no texture.

Rationale: Future monsters can be added without art first, and tests can still construct synthetic MonsterData without having to create textures.

Alternative considered: Require every monster to have art and fail validation otherwise. This is stricter, but it would make test data and incremental content authoring brittle.

### Decision 4: Keep existing layout contracts

Images should use the current lower enemy visual area and share a stable baseline. Texture scaling should fit inside each visual slot while preserving aspect ratio. The enemy list window remains separate from the graphics area.

Rationale: The previous combat UI change established readability contracts around enemy count text, right-side command panels, and lower visual placement. This change should improve art fidelity without moving the battle UI.

Alternative considered: Resize the whole enemy graphics layout around each image's native dimensions. That may look better for single monsters, but it risks layout shifts and inconsistent target presentation across encounters.

## Risks / Trade-offs

- Generated art style may be inconsistent across monsters -> Use a shared prompt direction and post-generation review before committing assets.
- Large monsters such as dragon may lose detail when fit into the current slot -> Preserve aspect ratio and allow implementation to tune slot sizing without breaking the stable baseline requirement.
- Godot may create `.import` metadata for PNGs -> Include whatever project metadata is needed for the images to load in tests and editor.
- Tests that construct MonsterData manually will not set textures -> Keep texture optional and fallback rendering covered by tests.
- Existing dummy visual tests may be too narrowly named -> Update tests to assert visual entries/renderability rather than requiring all visuals to be dummy rectangles.
