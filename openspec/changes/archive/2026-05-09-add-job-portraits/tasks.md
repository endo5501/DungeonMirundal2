## 1. Tests First

- [x] 1.1 Add a failing test that PartyMemberData stores an optional `job_id` and defaults it to empty when omitted.
- [x] 1.2 Add a failing test that `Character.to_party_member_data()` carries the canonical job id.
- [x] 1.3 Add failing PartyMemberPanel tests for known job portrait path resolution across all eight jobs.
- [x] 1.4 Add failing PartyMemberPanel tests for empty and unknown job ids falling back to no portrait texture.
- [x] 1.5 Run the targeted tests and confirm they fail for the expected missing behavior.

## 2. Portrait Assets

- [x] 2.1 Generate eight dark-fantasy painted job portrait images with the built-in image generation tool: fighter, mage, priest, thief, bishop, samurai, lord, and ninja.
- [x] 2.2 Save the selected final PNG assets under `assets/images/portraits/jobs/` using lowercase job id filenames.
- [x] 2.3 Inspect the generated set for consistent crop, readable silhouette, no text, and no race-specific visual dependency.

## 3. Data Plumbing

- [x] 3.1 Extend PartyMemberData with optional `job_id: StringName` while preserving existing constructor call sites.
- [x] 3.2 Update `Character.to_party_member_data()` to populate `job_id` from the character's job identity.
- [x] 3.3 Run the targeted data tests and confirm they pass.

## 4. HUD Rendering

- [x] 4.1 Add PartyMemberPanel portrait path/texture resolution for the eight known job ids.
- [x] 4.2 Update `_draw_portrait()` to draw the resolved portrait inside `get_portrait_rect()` and keep existing placeholder fallback.
- [x] 4.3 Keep level and name badges rendered over the portrait after the image draw.
- [x] 4.4 Materialize resolved portrait resources as cached runtime textures for HUD drawing.
- [x] 4.5 Run the targeted PartyMemberPanel tests and confirm they pass.

## 5. Verification

- [x] 5.1 Run the relevant party display and character tests through `scripts/run_tests.ps1`.
- [x] 5.2 Run the full test wrapper if targeted tests pass.
- [x] 5.3 Verify Godot imports the new PNG assets cleanly and no parse/import errors appear in test output.
