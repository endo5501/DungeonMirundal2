## Context

`PartyMemberPanel` already uses a portrait-forward layout with a 170x174 portrait region, level badge, name badge, HP/MP bars, and status/stat modifier icons. The current portrait renderer only draws a generic placeholder rectangle. Character objects already reference `JobData`, and `JobData.id` is the canonical stable job identifier used by serialization. The eight supported jobs are fixed for now: fighter, mage, priest, thief, bishop, samurai, lord, and ninja.

This change adds static generated portrait assets and connects the existing HUD display data to those assets. It does not alter save data or make portraits user-selectable.

## Goals / Non-Goals

**Goals:**

- Render a default dark-fantasy portrait for each existing job in the party HUD.
- Keep live `Character` binding and `PartyMemberData` snapshot setup visually consistent.
- Use the existing `JobData.id` as the portrait lookup key.
- Keep fallback behavior robust when a job id or image is unavailable.
- Store generated project-bound image assets under `assets/images/portraits/jobs/`.

**Non-Goals:**

- No race-specific portrait variants.
- No per-character portrait customization.
- No save-data schema changes.
- No new image repository abstraction unless implementation shows the HUD-local map becoming too large.
- No changes to job qualification, spell progression, growth, or serialization behavior.

## Decisions

### Use `PartyMemberData.job_id` for snapshot and live HUD paths

`Character.to_party_member_data()` will include the character's canonical job id in the `PartyMemberData` it creates. This keeps both existing paths aligned:

```
Character.job.id
       |
       v
Character.to_party_member_data()
       |
       v
PartyMemberData.job_id
       |
       v
PartyMemberPanel portrait lookup
```

Alternative considered: read `_character.job.id` directly in `PartyMemberPanel`. That works only for live binding and leaves `setup(party_data)` snapshots without enough information. Adding the id to the display DTO keeps rendering behavior explicit and testable.

If a fixture or legacy in-memory `JobData` has no `id` or `resource_path`, the display path falls back to a normalized `job_name` (for example `Mage` -> `mage`). This is intentionally display-only and does not change save serialization.

### Keep portrait lookup HUD-local for this change

`PartyMemberPanel` will map known job ids to texture paths such as `res://assets/images/portraits/jobs/fighter.png`. This limits the behavioral change to the party display surface.

Alternative considered: add an exported `portrait_texture` or `portrait_path` to `JobData`. That would make the data model more direct, but it expands the `job-data` contract and every job resource for a HUD-only default image. The current requirement is a default visual, not a broader job data capability.

Alternative considered: introduce a `PortraitRepository`. That would help if portraits become race-specific, character-specific, or used across multiple screens. For eight static defaults used by one HUD component, it is unnecessary indirection.

### Generate uniform dark-fantasy portrait assets

Each asset will be generated as a square or near-square bust portrait suitable for cropping into the existing portrait rectangle. Prompts should keep the set consistent: dark-fantasy painted style, front-facing or three-quarter bust, readable silhouette, muted dungeon-compatible lighting, no text, no watermark, and no race-specific traits. The generated files will be saved in the project, not referenced from the image generation cache.

### Preserve placeholder fallback

If `job_id` is empty, unknown, or its image fails to load, the panel will draw the existing placeholder. This protects tests, partial fixtures, legacy snapshot data, and development builds where an asset import is missing.

Portrait textures are materialized as cached `ImageTexture` instances before drawing. This avoids renderer-side placeholder output from imported `CompressedTexture2D` resources while still loading through Godot's resource system first.

## Risks / Trade-offs

- Generated portraits may vary in crop, contrast, or detail between jobs -> Use a shared prompt structure and visually inspect outputs before wiring them in.
- Godot image imports may not exist immediately after copying PNGs into the project -> Run the project/test wrapper or editor import path as part of verification so `.import` metadata is generated if needed.
- `PartyMemberData` constructor changes may affect many tests -> Keep the new `job_id` parameter optional with a default empty value, and update only tests that need portrait behavior.
- HUD-local mapping duplicates the fixed job list -> Acceptable for this narrow change; revisit if portraits become configurable outside the HUD.

## Migration Plan

No save migration is required. Existing characters already retain job identity through `JobData.id` and serialized `job_id`. Existing `PartyMemberData` construction sites without a job id continue to work through the default empty id and fallback portrait rendering.

Rollback is straightforward: remove the image assets and revert the `PartyMemberData`/`PartyMemberPanel` changes. Missing assets already fall back to the placeholder.

## Open Questions

None. The initial style direction is dark-fantasy painted portraits, one per job, with no race-specific variants.
