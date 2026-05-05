## ADDED Requirements

### Requirement: PartyDisplay anchors to screen bottom and spans full width

The `PartyDisplay` SHALL anchor to the bottom edge of its parent and span the full horizontal width of the screen, so that its child panels can be positioned with reference to both the left and right edges.

#### Scenario: PartyDisplay anchors fill bottom width

- **WHEN** `PartyDisplay` is added to a parent of width `W` and `_ready()` runs
- **THEN** its anchors SHALL be `anchor_left = 0.0`, `anchor_right = 1.0`, `anchor_top = 1.0`, `anchor_bottom = 1.0`
- **AND** its size SHALL extend to the full width `W` of the parent

### Requirement: PartyDisplay places front row at left and back row at right with empty center

The `PartyDisplay` SHALL place the three front-row `PartyMemberPanel`s left-aligned to the left edge (with a small left margin) and the three back-row `PartyMemberPanel`s right-aligned to the right edge (with a small right margin), leaving the horizontal center empty (no panels and no background fill). All six panels SHALL share the same vertical position (single row).

#### Scenario: Front-row panels are left-aligned

- **WHEN** `PartyDisplay` is laid out in a parent of width `W`
- **THEN** the three front-row panels SHALL be positioned starting from the left edge, with each panel's `position.x` increasing left-to-right
- **AND** the leftmost front-row panel's `position.x` SHALL be at most `MARGIN` pixels from the left edge

#### Scenario: Back-row panels are right-aligned

- **WHEN** `PartyDisplay` is laid out in a parent of width `W`
- **THEN** the three back-row panels SHALL be positioned ending at the right edge, with each panel's `position.x` increasing left-to-right
- **AND** the rightmost back-row panel's right edge SHALL be at most `MARGIN` pixels from the right edge `W`

#### Scenario: Front and back rows share the same vertical position

- **WHEN** `PartyDisplay` is laid out
- **THEN** every front-row panel and every back-row panel SHALL have the same `position.y` value

#### Scenario: Center area is empty

- **WHEN** `PartyDisplay` is laid out
- **THEN** there SHALL be a horizontal gap between the rightmost front-row panel and the leftmost back-row panel
- **AND** no `PartyMemberPanel`, label, or background rectangle SHALL be drawn in that gap

### Requirement: PartyDisplay shows FRONT and BACK labels above each row group

The `PartyDisplay` SHALL render the text label "FRONT" above the front-row panel group and the text label "BACK" above the back-row panel group. The labels SHALL be drawn by `PartyDisplay` itself (not by `PartyMemberPanel`), with a font size at least equal to the body font size used by the panels (target 20pt).

#### Scenario: FRONT label above front row

- **WHEN** `PartyDisplay` renders
- **THEN** the text "FRONT" SHALL appear above the front-row panel group (vertically above the leftmost front-row panel) and SHALL be horizontally aligned to the front-row group's left edge

#### Scenario: BACK label above back row

- **WHEN** `PartyDisplay` renders
- **THEN** the text "BACK" SHALL appear above the back-row panel group (vertically above the rightmost back-row panel) and SHALL be horizontally aligned to the back-row group's right edge

#### Scenario: Label font size is at least body font size

- **WHEN** `PartyDisplay` renders the FRONT/BACK labels
- **THEN** the labels' font size SHALL be at least equal to `PartyMemberPanel.FONT_SIZE`

### Requirement: PartyDisplay does not render a global background bar

The `PartyDisplay` SHALL NOT render any global background rectangle or `ColorRect` covering the full HUD area. Each `PartyMemberPanel` retains its own per-panel background; the `PartyDisplay` itself contributes no background fill.

#### Scenario: No global background ColorRect child

- **WHEN** `PartyDisplay._ready()` completes
- **THEN** `PartyDisplay` SHALL NOT have any `ColorRect` child whose role is to fill the HUD background

#### Scenario: Center area is fully transparent

- **WHEN** `PartyDisplay` renders with valid front and back rows
- **THEN** the center horizontal gap between the front and back panel groups SHALL contain no rendered pixels from `PartyDisplay` (no background, no fill)

### Requirement: PartyMemberPanel uses an enlarged font size for body text

`PartyMemberPanel` SHALL render its body text (name, level, HP, MP) at a font size of at least 20 pixels. Line spacing SHALL be adjusted so all four text lines fit cleanly within the panel without clipping.

#### Scenario: FONT_SIZE constant is at least 20

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.FONT_SIZE` SHALL be at least `20`

#### Scenario: All four text lines fit within panel height

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the bottom of the MP line SHALL be at or above `PANEL_HEIGHT - 4`

### Requirement: PartyMemberPanel uses an enlarged panel height to accommodate body text

`PartyMemberPanel` SHALL define `PANEL_HEIGHT` large enough to contain the icon, the name, level, HP, and MP lines at the enlarged font size with sane padding. `PANEL_WIDTH` SHALL remain at `180`.

#### Scenario: PANEL_HEIGHT is enlarged

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_HEIGHT` SHALL be at least `100`

#### Scenario: PANEL_WIDTH is unchanged

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_WIDTH` SHALL be `180`

### Requirement: PartyMemberPanel renders nothing for empty slots

When `PartyMemberPanel` has no data to render (the bound `Character` is null and the snapshot `PartyMemberData` is null), it SHALL render nothing — no background rectangle, no icon, and no text. The panel's slot position remains reserved (the panel still occupies its `position`/size in the parent), but it is visually empty.

#### Scenario: Empty panel draws no pixels

- **WHEN** `PartyMemberPanel._data` is `null` and `_character` is `null` and `_draw()` runs
- **THEN** no `draw_rect`, `draw_string`, or other draw call SHALL be invoked

#### Scenario: Empty slot position is preserved

- **WHEN** `PartyDisplay` is bound with a front row of `[Character, null, Character]`
- **THEN** the three front-row `PartyMemberPanel`s SHALL still occupy their original three slot positions (the second remains visually empty; the third does NOT shift left)
