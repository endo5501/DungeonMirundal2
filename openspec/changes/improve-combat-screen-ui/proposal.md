## Why

The current combat screen presents the encounter, command menu, combat log, and party HUD as mostly text-heavy panels over the dungeon view, which makes the battle state harder to scan than the target visual direction. This change improves combat readability by moving battle controls to a stable right-side column, adding enemy dummy visuals, and making the party HUD more visual with larger portrait areas and HP/MP bars.

## What Changes

- Move combat log and command-related panels to the right side of the combat screen, using a compact stacked layout so the center-left battle area can be reserved for enemy presentation.
- Keep the dungeon background rendering out of scope for this change.
- Extend the enemy area so it continues to show monster species/count information and also displays dummy enemy monster images while real monster art is not yet available.
- Improve `PartyMemberPanel` visual density by increasing panel height, enlarging the character image placeholder area, and reducing body text size.
- Move level display from the normal text stack to a small badge at the character image area's upper-right.
- Replace HP/MP text-only presentation with bar + numeric value presentation, using smaller text and color-coded bars.
- Preserve existing combat behavior, command semantics, turn flow, log contents, party binding, animation hooks, status icons, and stat modifier icons.
- No breaking changes to gameplay logic or public command IDs are intended.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `combat-overlay`: Battle screen layout requirements change so battle log, command menu, and combat selection panels are placed in a right-side UI column, while the enemy presentation area supports dummy monster images alongside species/count text.
- `party-display`: Party HUD presentation requirements change so member panels are taller, portrait-forward, use a level badge, and render HP/MP as bars with numeric values rather than text-only lines.

## Impact

- Affected code:
  - `src/dungeon_scene/combat_overlay.gd`
  - `src/dungeon_scene/combat/combat_monster_panel.gd`
  - `src/dungeon_scene/combat/combat_log.gd`
  - `src/dungeon_scene/combat/combat_command_menu.gd`
  - `src/dungeon_scene/party_member_panel.gd`
  - `src/dungeon_scene/party_display.gd`
- Affected tests:
  - Combat overlay layout and monster panel tests.
  - Party member panel size, text, icon, HP/MP, and layout tests.
  - Existing behavior tests should continue to pass after expectation updates for the new UI presentation.
- No new runtime dependency is expected. Dummy enemy and character visuals may be drawn procedurally or with existing placeholder-style drawing.
