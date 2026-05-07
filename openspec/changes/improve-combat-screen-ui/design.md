## Context

The current combat UI is built mostly from lightweight Godot `Control` classes created in code. `CombatOverlay._build_combat_ui()` owns the battle panels and positions them with anchors. `CombatMonsterPanel`, `CombatLog`, and `CombatCommandMenu` are simple controls, while `PartyMemberPanel` draws the HUD directly in `_draw()` and `PartyDisplay` anchors six panels at the bottom of the screen.

The target direction is a more visual combat screen: right-side battle controls, a central enemy presentation area with dummy monster images, and taller party cards with portrait space and HP/MP bars. Dungeon background rendering and real art production are explicitly out of scope.

## Goals / Non-Goals

**Goals:**

- Move the combat log and command-related controls into a stable, compact right-side column.
- Reserve the main battle area for enemy information and dummy enemy visuals.
- Keep monster species/count information visible and behaviorally unchanged.
- Increase `PartyMemberPanel` height and make its layout portrait-forward.
- Render level as a small badge in the portrait area rather than as a normal text line.
- Render HP/MP as color-coded bars plus numeric values.
- Preserve existing combat input, command IDs, turn resolution, log formatting, party binding, status icons, stat modifier icons, and animation hooks.
- Keep the implementation compatible with the existing test-driven workflow and `scripts/run_tests.ps1`.

**Non-Goals:**

- Do not change dungeon wall/floor/background rendering.
- Do not introduce final monster art or character portrait art.
- Do not alter combat rules, target resolution, spell/item behavior, reward logic, or command semantics.
- Do not replace the existing code-created UI with `.tscn` scenes as part of this change.
- Do not add new external UI or asset dependencies.

## Decisions

### Decision 1: Keep the combat UI code-created and anchor-based

Use the existing `Control` classes and `_place()` anchor helper in `CombatOverlay` instead of introducing scene files or a new layout framework.

Rationale: The current combat overlay already constructs and tests panels programmatically. Keeping that pattern limits the blast radius and makes layout assertions straightforward in GUT.

Alternative considered: Move the combat overlay to a dedicated `.tscn` hierarchy. This would make visual iteration easier later, but it adds migration risk and is unnecessary for this scoped layout change.

### Decision 2: Define a reusable right-side panel region in `CombatOverlay`

Introduce a consistent right-column placement for `CombatLog`, `CombatCommandMenu`, `CombatTargetSelector`, `CombatSpellSelector`, and the combat item panel. The log should use only enough vertical space for its title and eight retained visible lines, splitting multi-line action text before enforcing the cap. Its content should be clipped to the frame so accumulated log text cannot visually spill over command panels. Command and selection panels should begin close below it while still staying clear of the party HUD. Exact constants can remain in `combat_overlay.gd`, but the layout should be named or grouped so later tuning is not scattered.

Rationale: The user-facing change is spatial consistency. If command, spell, target, and item flows appear in unrelated regions, the new layout will feel fragmented even if the command menu itself moves.

Alternative considered: Move only the command menu and leave sub-selection panels in the old center-left area. This is less invasive, but it creates a jarring phase transition and wastes the enemy presentation area.

### Decision 3: Extend monster presentation without changing monster-count behavior

`CombatMonsterPanel` should continue exposing species/count text through `get_display_text()` and `refresh()`. Dummy enemy visuals should be derived from the current living monster combatants or grouped species data and drawn procedurally in the panel, either inside `CombatMonsterPanel` itself or a small child `Control` owned by it.

Rationale: Existing tests and target selection depend on monster display text and counts. Procedural dummy drawing avoids new asset dependencies and keeps this change focused on layout.

Alternative considered: Add placeholder PNG assets now. This would be closer to a production art pipeline, but it would create asset-management concerns before real monster art exists.

### Decision 4: Redesign `PartyMemberPanel` drawing through internal layout helpers

Keep `PartyMemberPanel` as a custom-drawn `Control`, but split drawing into small helpers for the portrait area, level badge, name, HP/MP bars, and icon row. Add layout constants for portrait size, bar rectangles, body font size, and badge font size.

Rationale: `_draw()` is currently simple but will become crowded once bars and a larger portrait are added. Helper methods make the visual contract easier to test without changing the public API.

Alternative considered: Rebuild each party card as a tree of `PanelContainer`, `TextureRect`, `Label`, and `ProgressBar` nodes. That would improve editor-style composition but risks breaking the existing signal/animation tests and requires more lifecycle work.

### Decision 5: Increase panel height while keeping width stable initially

Increase `PartyMemberPanel.PANEL_HEIGHT` enough to fit the larger portrait, smaller text, HP/MP bars, and icon rows cleanly. Keep `PANEL_WIDTH` at 180 for this change unless implementation proves the new layout cannot fit.

Rationale: At the current target resolution, six panels already nearly fill the screen width. Height is the safer dimension to grow without forcing responsive row wrapping or overlap.

Alternative considered: Increase panel width to match the target mock more closely. This would improve portrait/card proportions, but it would require changes to `PartyDisplay` layout behavior and may not fit six members on narrower windows.

### Decision 6: Preserve existing icon and animation semantics

Status icons, stat modifier icons, incapacitated dimming, heal flash, shake, lift, and death fade should continue to draw over or within the new card layout. The icon row should move to a reserved lower area so it does not collide with HP/MP bars.

Rationale: These visual systems are already covered by tests and are tied to combat feedback. The new layout should improve readability without removing existing combat state cues.

Alternative considered: Defer status/stat icon layout until later. That would make the first visual pass easier, but it risks regressing important battle-state feedback.

## Risks / Trade-offs

- Panel height growth may cover more of the dungeon view -> Keep background changes out of scope, update `PartyDisplay.HUD_HEIGHT` through existing constants, and verify the combat screen at the current window size.
- Right-column panels may conflict with each other or the party HUD -> Hide the minimap during combat, keep explicit compact log and command anchor regions, and add layout tests that assert command/log panels occupy the intended side without excessive unused vertical gap.
- HP/MP bars with zero max values may divide by zero -> Clamp bar ratio calculation so zero max renders an empty or safe-width bar while still showing numeric values.
- Smaller text may make Japanese command/log content harder to read -> Reduce only party card body text; command and log font sizes can remain readable or be tuned separately.
- Dummy enemy visuals could imply target selection that does not exist yet -> Keep selection behavior unchanged and treat visuals as non-interactive presentation for this change.
- Existing tests assert old `PartyMemberPanel.FONT_SIZE >= 20` behavior -> Update tests first to reflect the new smaller body-font requirement and add tests for bar layout/ratios.

## Migration Plan

1. Update or add tests for the new combat overlay panel placement, monster dummy visual support, party panel sizing, level badge placement contract, and HP/MP bar ratio behavior.
2. Adjust `CombatOverlay` layout constants and move command-related panels into the right-side column.
3. Extend `CombatMonsterPanel` to draw dummy enemy visuals while preserving `refresh()` and `get_display_text()`.
4. Refactor `PartyMemberPanel._draw()` into helper methods and implement the new portrait-forward card layout.
5. Update `PartyDisplay` expectations that depend on panel height or label/body font relationships.
6. Run the recommended wrapper test command and perform screenshot inspection against the current/target images.

Rollback is straightforward because the change is UI-only: revert the affected UI files and corresponding tests/spec deltas without touching combat engine state or save data.

## Open Questions

- Should the target selector visually highlight dummy enemy images in this change, or remain text/list based in the right-side panel?
- Should `PartyMemberPanel.PANEL_WIDTH` remain fixed at 180 permanently, or should a later change introduce responsive card width for larger windows?
