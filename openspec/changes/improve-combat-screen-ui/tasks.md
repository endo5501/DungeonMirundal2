## 1. Test Contracts

- [x] 1.1 Add or update combat overlay layout tests to assert CombatLog, CommandMenu, target selector, spell selector, and combat item panel are anchored in the right-side battle UI column.
- [x] 1.2 Add or update monster panel tests to assert species/count text remains available and at least one dummy enemy visual is exposed or renderable when living monsters exist.
- [x] 1.3 Update PartyMemberPanel size/font tests so panel height is greater than 130, width remains 180, and body text is compact rather than at least 20 pixels.
- [x] 1.4 Add PartyMemberPanel layout contract tests for enlarged portrait placeholder, level badge placement data, HP/MP bar ratio calculation, and zero-max MP safety.
- [x] 1.5 Add or update PartyMemberPanel icon layout tests so persistent status icons and stat modifier icons have reserved positions that do not collide with HP/MP bar rectangles.
- [x] 1.6 Add follow-up visual contract tests for framed FRONT/BACK row windows, ENEMY list window separation, lower aligned enemy visuals, taller CombatLog retention, and tighter portrait-to-HP spacing.
- [x] 1.7 Add follow-up tests for hiding the dungeon minimap during combat and separating the right-column log/command windows from the party HUD area.
- [x] 1.8 Add a follow-up layout contract test for compacting the right-column CombatLog height and moving the command window start position upward.
- [x] 1.9 Add follow-up tests for retaining enough CombatLog lines to fill the compact log window and keeping the command window clear of the party HUD.
- [x] 1.10 Add follow-up tests for limiting CombatLog retention to eight lines, clipping log content to its window, and further shortening the command window.
- [x] 1.11 Add follow-up tests for multi-line action logs counting against the eight-line CombatLog cap as visible display lines.

## 2. Combat Overlay Layout

- [x] 2.1 Introduce named right-column layout constants or helper methods in `combat_overlay.gd` for log, command, selector, spell, and item panel placement.
- [x] 2.2 Move CombatLog into the right-side battle UI column while preserving log clearing, rolling line retention, and formatting behavior.
- [x] 2.3 Move CommandMenu, CombatTargetSelector, CombatSpellSelector, and the combat ItemUseFlow panel into the right-side battle UI column while preserving input routing and cancel/confirm behavior.
- [x] 2.4 Keep the result panel behavior unchanged except for any necessary non-overlap adjustment with the new combat layout.
- [x] 2.5 Render right-side CombatLog, command, selector, spell, and item-use panels as framed windows.
- [x] 2.6 Hide the dungeon minimap while combat is active, restore it afterward, and remove minimap-clearance offsets from the CombatLog layout.
- [x] 2.7 Compact the right-column CombatLog window and raise the command/selection panel placement so the right column uses vertical space more tightly.
- [x] 2.8 Increase CombatLog retention to fill the compact window and reduce command/selection panel height so it stays clear of the party HUD.
- [x] 2.9 Limit CombatLog retention to eight lines, clip its rendered content, and further reduce command/selection panel height.
- [x] 2.10 Split multi-line CombatLog entries into retained visible lines before enforcing the eight-line cap.

## 3. Enemy Presentation

- [x] 3.1 Extend `CombatMonsterPanel` so it stores enough refreshed monster presentation data to draw dummy visuals for living enemies without changing `get_display_text()`.
- [x] 3.2 Draw procedural dummy enemy placeholders in the enemy presentation area, using stable spacing for one or more living monsters.
- [x] 3.3 Preserve species/count text updates when monsters die and continue hiding per-individual HP.
- [x] 3.4 Replace the encounter title with `ENEMY`, constrain the enemy name/count list to a framed list window, and keep dummy visuals lower with a shared baseline.

## 4. Party HUD Card Layout

- [x] 4.1 Add PartyMemberPanel layout constants/helpers for portrait rectangle, level badge rectangle, name position, HP bar rectangle, MP bar rectangle, numeric value positions, and icon row origin.
- [x] 4.2 Increase PartyMemberPanel height and keep PartyDisplay HUD anchoring derived from `PartyMemberPanel.PANEL_HEIGHT`.
- [x] 4.3 Render a larger dummy portrait placeholder and draw the level badge at the portrait area's upper-right.
- [x] 4.4 Replace text-only HP/MP lines with color-coded HP/MP bars plus compact numeric current/max values.
- [x] 4.5 Clamp HP/MP bar ratio helpers so zero maximum values and out-of-range values render safely.
- [x] 4.6 Reposition persistent status icons and combat stat modifier icons into the reserved icon area without changing their color/label semantics.
- [x] 4.7 Preserve incapacitated dimming, heal flash, shake, lift, death fade, live Character binding, and CombatActor binding behavior.
- [x] 4.8 Render FRONT/BACK row windows and extend the portrait placeholder to reduce the dead gap above HP.

## 5. Verification

- [x] 5.1 Run the focused combat overlay and party display test files through `scripts/run_tests.ps1` until they pass.
- [x] 5.2 Run the full recommended test wrapper `.\scripts\run_tests.ps1`.
- [ ] 5.3 Capture or inspect the combat screen visually and compare against `tmp/dungeon5.png` and `tmp/update_graphics2.png`, confirming dungeon background rendering was not changed.
- [x] 5.4 Update `tasks.md` checkboxes as each implementation task is completed.
