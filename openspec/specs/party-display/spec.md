## Purpose
画面端に常時表示されるパーティ一覧のミニ UI を規定する。各キャラクターの名前・HP・MP・状態異常アイコンのコンパクト表示を対象とする。
## Requirements
### Requirement: PartyMemberData holds character display information
PartyMemberData (RefCounted) SHALL hold the display data for a single party member: name (String), level (int), current_hp (int), max_hp (int), current_mp (int), max_mp (int).

#### Scenario: Create party member with all fields
- **WHEN** PartyMemberData is created with name "Warrior", level 5, current_hp 120, max_hp 150, current_mp 30, max_mp 45
- **THEN** name SHALL be "Warrior", level SHALL be 5, current_hp SHALL be 120, max_hp SHALL be 150, current_mp SHALL be 30, max_mp SHALL be 45

### Requirement: PartyData holds a party of up to 6 members in two rows
PartyData (RefCounted) SHALL manage a party with a front row (up to 3 members) and a back row (up to 3 members).

#### Scenario: Create party with front and back rows
- **WHEN** PartyData is created with front_row of 3 members and back_row of 3 members
- **THEN** get_front_row() SHALL return the 3 front row members AND get_back_row() SHALL return the 3 back row members

#### Scenario: Empty slots are null
- **WHEN** PartyData is created with front_row of 2 members and back_row of 1 member
- **THEN** get_front_row() SHALL return an array of size 3 where index 2 is null AND get_back_row() SHALL return an array of size 3 where indices 1 and 2 are null

### Requirement: PartyData provides default placeholder data
PartyData SHALL provide a static method create_placeholder() that returns a PartyData instance with 6 pre-defined placeholder members for testing purposes.

#### Scenario: Placeholder data has 6 members
- **WHEN** PartyData.create_placeholder() is called
- **THEN** the returned PartyData SHALL have 3 front row members and 3 back row members, all with non-empty names and positive max_hp and max_mp values

### Requirement: PartyMemberPanel auto-refreshes from a bound Character

The `PartyMemberPanel` SHALL accept a `Character` as its display source and SHALL connect to the Character's `hp_changed`, `mp_changed`, and `statuses_changed` signals so that the panel re-renders automatically when those signals fire. When the panel's display source is reassigned to a different Character (or to null), it SHALL disconnect from the previous Character's signals before connecting to the new one.

#### Scenario: HP change on bound Character refreshes the panel
- **WHEN** a PartyMemberPanel has been bound to a Character with `current_hp = 20`, and that Character's `current_hp` is then assigned `15`
- **THEN** the panel SHALL re-render its HP display so that subsequent reads of the displayed current HP value reflect `15`

#### Scenario: MP change on bound Character refreshes the panel
- **WHEN** a PartyMemberPanel has been bound to a Character with `current_mp = 5`, and that Character's `current_mp` is then assigned `3`
- **THEN** the panel SHALL re-render its MP display so that subsequent reads of the displayed current MP value reflect `3`

#### Scenario: Switching Characters disconnects old signals
- **WHEN** a PartyMemberPanel is bound to Character A, then re-bound to Character B, and afterward Character A's `current_hp` is assigned a new value
- **THEN** the panel SHALL NOT re-render in response to A's change

#### Scenario: Unbinding a Character disconnects signals
- **WHEN** a PartyMemberPanel is bound to a Character, then unbound (set to null), and afterward the Character's `current_hp` is assigned a new value
- **THEN** the panel SHALL NOT re-render in response to that change

### Requirement: PartyDisplay supports binding party members from Character objects

The `PartyDisplay` SHALL provide an interface to bind front-row and back-row members directly from `Character` objects (in addition to the existing `setup(party_data: PartyData)` snapshot interface). When bound from Character objects, each constituent `PartyMemberPanel` SHALL receive the Character and connect to its signals as defined above.

#### Scenario: Binding from Characters wires signal-driven refresh
- **WHEN** `PartyDisplay` is bound with three front-row Characters and three back-row Characters, and one of them later has its `current_hp` mutated
- **THEN** the corresponding `PartyMemberPanel` SHALL refresh, while the other panels SHALL NOT refresh

#### Scenario: Empty slots are handled
- **WHEN** `PartyDisplay` is bound from rows that contain `null` for some slots
- **THEN** those slots SHALL render as empty (matching existing PartyMemberData null handling) and SHALL NOT attempt signal connections

### Requirement: PartyHud autoload owns the sole PartyDisplay and binds live Characters

The `PartyHud` autoload SHALL be the sole owner of the `PartyDisplay` instance. `DungeonScreen` SHALL NOT instantiate or own a `PartyDisplay` directly. Live `Character` binding to the active party SHALL be performed by `PartyHud.bind_active_party()`, which reads the current party from `GameState`. State mutations on those Characters from any source (combat, ESC menu spell casting, item use, status-effect changes) SHALL automatically refresh the HUD's panels via the existing signal connections.

#### Scenario: DungeonScreen does not own a PartyDisplay child
- **WHEN** `DungeonScreen` is added to the scene tree
- **THEN** `DungeonScreen` SHALL NOT contain a `PartyDisplay` as a direct child node

#### Scenario: ESC menu heal updates the HUD via PartyHud
- **WHEN** a Character in the active party has been damaged to `current_hp = 5` (with `max_hp = 20`), the dungeon screen is open with `PartyHud` visible, and an ESC-menu heal spell raises that Character's `current_hp` to `15`
- **THEN** the `PartyMemberPanel` inside `PartyHud`'s `PartyDisplay` SHALL re-render to reflect `15 / 20` without any explicit caller-side refresh

#### Scenario: HUD survives dungeon-to-town transition
- **WHEN** the player returns from DungeonScreen to TownScreen
- **THEN** the same `PartyHud` instance SHALL remain in the scene tree (not destroyed) AND its bound Characters' state SHALL continue to be observed

### Requirement: PartyMemberPanel renders icons for active persistent statuses

When `PartyMemberPanel` is bound to a `Character` that has one or more entries in `persistent_statuses`, it SHALL render a small icon for each active status, using a colored rectangle plus a 1- to 2-character label. The icon row SHALL be drawn within the panel bounds and SHALL not collide with the existing name/LV/HP/MP text. The color and label per status SHALL follow a consistent table:

- `poison` → purple
- `blind` → grey
- `sleep` → blue
- `paralysis` → yellow
- `petrify` → dark grey
- `confusion` → pink
- `silence` → brown

When the bound display source is a `PartyMemberData` snapshot (legacy path) rather than a `Character`, no status icons SHALL be rendered.

#### Scenario: Single status renders an icon
- **WHEN** a `PartyMemberPanel` is bound to a `Character` with `persistent_statuses = [&"poison"]` and `_draw()` runs
- **THEN** at least one colored rectangle (purple) and label SHALL be drawn within the panel area, in addition to the standard text lines

#### Scenario: Multiple statuses render multiple icons
- **WHEN** a `PartyMemberPanel` is bound to a `Character` with `persistent_statuses = [&"poison", &"blind", &"sleep"]` and `_draw()` runs
- **THEN** at least three icon rectangles SHALL be drawn (one per status), each with its corresponding color

#### Scenario: Empty status list renders no icons
- **WHEN** a `PartyMemberPanel` is bound to a `Character` with `persistent_statuses = []` and `_draw()` runs
- **THEN** no status icon SHALL be drawn

#### Scenario: Status icons update on signal
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = []`, then the Character is assigned `persistent_statuses = [&"sleep"]`
- **THEN** the panel SHALL re-render and a sleep icon SHALL appear

#### Scenario: PartyMemberData snapshot path renders no status icons
- **WHEN** a `PartyMemberPanel` has been set with a `PartyMemberData` snapshot via `set_member()` (no Character bound)
- **THEN** no status icon SHALL be drawn regardless of any external status state

### Requirement: PartyMemberPanel dims the panel for incapacitated members

When the bound `Character` is incapacitated, `PartyMemberPanel` SHALL render a semi-transparent dark overlay covering the entire panel area (drawn after all other content) so that the panel appears visually "dimmed". A character is incapacitated if any of the following hold:

- `current_hp <= 0`, OR
- `persistent_statuses` contains `&"sleep"`, OR
- `persistent_statuses` contains `&"paralysis"`, OR
- `persistent_statuses` contains `&"petrify"`

`confusion`, `silence`, `blind`, and `poison` SHALL NOT trigger the dim overlay (the character is still able to act).

#### Scenario: HP zero dims the panel
- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 0`
- **THEN** a semi-transparent dark overlay SHALL be drawn covering the panel area

#### Scenario: Sleep dims the panel
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"sleep"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL be drawn

#### Scenario: Paralysis dims the panel
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"paralysis"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL be drawn

#### Scenario: Petrify dims the panel
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"petrify"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL be drawn

#### Scenario: Poison alone does not dim
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"poison"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL NOT be drawn

#### Scenario: Confusion alone does not dim
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"confusion"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL NOT be drawn

#### Scenario: Recovery removes the dim
- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 0`, then the Character's `current_hp` is assigned a positive value
- **THEN** the panel SHALL re-render AND the dim overlay SHALL no longer be drawn

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

