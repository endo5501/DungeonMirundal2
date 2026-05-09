## Purpose
画面端に常時表示されるパーティ一覧のミニ UI を規定する。各キャラクターの名前・HP・MP・状態異常アイコンのコンパクト表示を対象とする。
## Requirements
### Requirement: PartyMemberData holds character display information
PartyMemberData (RefCounted) SHALL hold the display data for a single party member: name (String), level (int), current_hp (int), max_hp (int), current_mp (int), max_mp (int), and job_id (StringName). `job_id` SHALL identify the member's job when known and SHALL be empty when the display data has no job context.

#### Scenario: Create party member with all fields
- **WHEN** PartyMemberData is created with name "Warrior", level 5, current_hp 120, max_hp 150, current_mp 30, max_mp 45, and job_id `&"fighter"`
- **THEN** name SHALL be "Warrior", level SHALL be 5, current_hp SHALL be 120, max_hp SHALL be 150, current_mp SHALL be 30, max_mp SHALL be 45, and job_id SHALL be `&"fighter"`

#### Scenario: Create party member without job context
- **WHEN** PartyMemberData is created with name "Warrior", level 5, current_hp 120, max_hp 150, current_mp 30, and max_mp 45 without an explicit job_id
- **THEN** job_id SHALL be empty

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

- (combat mode, i.e. `_combat_actor != null`) `_combat_displayed_hp <= 0`, OR
- (non-combat mode, i.e. `_combat_actor == null`) `current_hp <= 0`, OR
- `persistent_statuses` contains `&"sleep"`, OR
- `persistent_statuses` contains `&"paralysis"`, OR
- `persistent_statuses` contains `&"petrify"`

`confusion`, `silence`, `blind`, and `poison` SHALL NOT trigger the dim overlay (the character is still able to act).

In combat mode, the HP-zero condition SHALL be evaluated against `_combat_displayed_hp` rather than the live `Character.current_hp`, so that the dim overlay appears in the same flush step as the corresponding death log line.

#### Scenario: HP zero dims the panel out of combat
- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 0` and is NOT bound to a CombatActor
- **THEN** a semi-transparent dark overlay SHALL be drawn covering the panel area

#### Scenario: HP zero in combat dims based on displayed HP
- **WHEN** a `PartyMemberPanel` is bound to a CombatActor whose live `current_hp = 0` but `_combat_displayed_hp = 5` (no flush yet)
- **THEN** the dim overlay SHALL NOT be drawn
- **AND** when the panel later receives `set_combat_displayed_hp(0)` and re-draws, the dim overlay SHALL be drawn

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
- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 0` (out of combat), then the Character's `current_hp` is assigned a positive value
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

`PartyMemberPanel` SHALL render body text such as HP/MP numeric values at a font size suitable for a portrait-forward card layout under the new 1600×900 design canvas. The body font size SHALL be at least `21` so that text remains readable at the default launch window. The member name and level SHALL NOT be rendered as normal stacked body-text lines; they SHALL be rendered as badges over the portrait area. Text and bars SHALL fit cleanly within the panel without clipping.

#### Scenario: Body font is enlarged for readability

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** the body font size used for member name and HP/MP numbers SHALL be at least `21` and at most `30`

#### Scenario: Level is not part of the stacked body text

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the level SHALL be displayed as a badge in the portrait area instead of as a normal text line between the name and HP/MP display

#### Scenario: Member name overlays the portrait

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the member name SHALL be displayed as a badge over the portrait area instead of below the portrait

#### Scenario: Text and bars fit within panel height

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the name, level badge, HP bar, MP bar, numeric HP/MP values, and icon row SHALL fit within `PANEL_HEIGHT` without clipping

### Requirement: PartyMemberPanel uses an enlarged panel size to accommodate body text

`PartyMemberPanel` SHALL define `PANEL_HEIGHT` and `PANEL_WIDTH` large enough to contain an enlarged character portrait placeholder, a level badge, member name, HP/MP bars with numeric values, and status/stat modifier icons with sane padding under the new 1600×900 design canvas. `PANEL_WIDTH` SHALL be `240` and `PANEL_HEIGHT` SHALL be at least `200` so that six panels (three FRONT + three BACK) fit horizontally within the design canvas with a non-overlapping center gap.

#### Scenario: PANEL_HEIGHT is enlarged for portrait-forward cards

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_HEIGHT` SHALL be at least `200`

#### Scenario: PANEL_WIDTH fits six panels in the design canvas

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_WIDTH` SHALL be `240`

#### Scenario: Six panels fit within the design canvas width with margin

- **WHEN** `PartyDisplay` lays out three FRONT and three BACK panels under the design canvas width of `1600`
- **THEN** the rightmost FRONT panel's right edge SHALL be strictly less than the leftmost BACK panel's left edge (i.e. the center gap remains positive and non-overlapping)

### Requirement: PartyMemberPanel renders nothing for empty slots

When `PartyMemberPanel` has no data to render (the bound `Character` is null and the snapshot `PartyMemberData` is null), it SHALL render nothing — no background rectangle, no icon, and no text. The panel's slot position remains reserved (the panel still occupies its `position`/size in the parent), but it is visually empty.

#### Scenario: Empty panel draws no pixels

- **WHEN** `PartyMemberPanel._data` is `null` and `_character` is `null` and `_draw()` runs
- **THEN** no `draw_rect`, `draw_string`, or other draw call SHALL be invoked

#### Scenario: Empty slot position is preserved

- **WHEN** `PartyDisplay` is bound with a front row of `[Character, null, Character]`
- **THEN** the three front-row `PartyMemberPanel`s SHALL still occupy their original three slot positions (the second remains visually empty; the third does NOT shift left)

### Requirement: PartyMemberPanel shakes on damage via hp_changed delta

`PartyMemberPanel` SHALL trigger a horizontal shake animation when its bound `Character`'s HP decreases (i.e., the new `current_hp` is less than the previously observed `current_hp`). The shake SHALL displace the panel's `position.x` by approximately ±4 pixels with a total duration of approximately 0.2 seconds and SHALL restore the panel to its layout position when complete. If a previous animation is still active, it SHALL be killed before the new shake starts.

#### Scenario: HP decrease starts a shake

- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 20`, and the Character's `current_hp` is then assigned `15`
- **THEN** the panel SHALL initiate a shake animation (a Tween acting on `position.x`)

#### Scenario: HP increase does not start a shake

- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 10`, and the Character's `current_hp` is then assigned `15`
- **THEN** the panel SHALL NOT initiate a shake animation

#### Scenario: Consecutive damage overrides the previous shake

- **WHEN** a `PartyMemberPanel` has an active shake Tween from a prior damage, and the bound Character's `current_hp` decreases again
- **THEN** the previous Tween SHALL be killed and a new shake Tween SHALL be created

#### Scenario: Shake restores the panel position

- **WHEN** a shake animation completes (or is killed)
- **THEN** the panel's `position.x` SHALL be restored to the layout x value assigned by `PartyDisplay`

### Requirement: PartyMemberPanel flashes green on heal via hp_changed delta

`PartyMemberPanel` SHALL trigger a green flash overlay when its bound `Character`'s HP increases. The flash SHALL be a semi-transparent green overlay drawn over the entire panel, with an alpha that starts around 0.5 and fades to 0 over approximately 0.3 seconds. If a previous flash is still active, it SHALL be killed before the new flash starts.

#### Scenario: HP increase starts a flash

- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 5`, and the Character's `current_hp` is then assigned `12`
- **THEN** the panel SHALL initiate a heal flash animation (a Tween acting on `_flash_alpha`)

#### Scenario: Heal flash overlay is drawn while alpha > 0

- **WHEN** a `PartyMemberPanel` has `_flash_alpha > 0` and `_draw()` runs
- **THEN** a semi-transparent green rectangle covering the panel area SHALL be drawn

#### Scenario: Heal flash hidden when alpha is 0

- **WHEN** the heal flash Tween completes and `_flash_alpha = 0`
- **THEN** no green overlay SHALL be drawn on the next `_draw()` call

### Requirement: PartyMemberPanel lifts on actor_action_started

`PartyMemberPanel` SHALL provide a method `play_lift_animation()` that displaces the panel upward by approximately 8 pixels for 0.15 seconds and returns it to the layout position over another 0.15 seconds (total 0.3 seconds). The HUD layer (PartyHud) SHALL invoke this method when the `actor_action_started` signal fires from the attached `TurnEngine` for an actor whose Character matches the panel's bound Character. If a previous lift is still active, it SHALL be killed before starting a new lift.

#### Scenario: actor_action_started triggers panel lift

- **WHEN** the attached `TurnEngine` emits `actor_action_started(actor, &"attack")` and `actor.character` matches `PartyMemberPanel._character`
- **THEN** the panel's `play_lift_animation()` SHALL be invoked AND a Tween acting on `position.y` SHALL be created

#### Scenario: Lift kind is uniform regardless of action_kind

- **WHEN** `actor_action_started` fires with any of `&"attack"`, `&"defend"`, `&"cast"`, `&"item"`, `&"escape"`
- **THEN** the same lift animation SHALL be played (no kind-specific differentiation in this version)

#### Scenario: Lift restores y position

- **WHEN** a lift animation completes (or is killed)
- **THEN** the panel's `position.y` SHALL be restored to the layout y value assigned by `PartyDisplay`

### Requirement: PartyMemberPanel fades on actor_died

`PartyMemberPanel` SHALL provide a method `play_die_animation()` that fades `modulate.a` from `1.0` to `0.7` over approximately 0.4 seconds. The HUD layer SHALL invoke this method when `actor_died` fires for an actor whose Character matches the panel's bound Character. The fade SHALL be removed (modulate.a restored to `1.0`) automatically when the bound Character's `current_hp` becomes positive again (revival).

#### Scenario: actor_died fades the panel

- **WHEN** the attached `TurnEngine` emits `actor_died(actor)` and `actor.character` matches `PartyMemberPanel._character`
- **THEN** the panel's `modulate.a` SHALL transition toward `0.7`

#### Scenario: Revival restores modulate

- **WHEN** the bound Character's `current_hp` was `0` (panel faded), and the Character's `current_hp` is later assigned a positive value
- **THEN** the panel's `modulate.a` SHALL be set back to `1.0`

### Requirement: PartyMemberPanel renders stat modifier icons during combat

When `PartyMemberPanel` has been bound to a `CombatActor` (via `bind_combat_actor()`), it SHALL render an icon for each entry in `combat_actor.stat_modifier_stack` (positive deltas as buffs, negative deltas as debuffs). The icons SHALL use a colored rectangle plus a 2- to 3-character label such as `A+`, `A-`, `D+`, `D-`. The icon row SHALL be drawn within the panel and MUST NOT collide with the existing name/LV/HP/MP text or the persistent_status icon row.

When `PartyMemberPanel` has not been bound to a `CombatActor` (outside combat), no stat modifier icons SHALL be rendered.

#### Scenario: Single buff renders an icon

- **WHEN** a `PartyMemberPanel` is bound to a `CombatActor` whose `stat_modifier_stack` contains one entry `(stat = &"attack", delta = +2, duration = 3)` and `_draw()` runs
- **THEN** at least one stat modifier icon (e.g., a green-tinted rectangle with label `A+`) SHALL be drawn

#### Scenario: Single debuff renders an icon

- **WHEN** the stack contains one entry `(stat = &"defense", delta = -1, duration = 2)`
- **THEN** at least one stat modifier icon (e.g., a red-tinted rectangle with label `D-`) SHALL be drawn

#### Scenario: Empty stack renders no icons

- **WHEN** the bound CombatActor's `stat_modifier_stack.is_empty() == true`
- **THEN** no stat modifier icon SHALL be drawn

#### Scenario: Without CombatActor binding, no icons

- **WHEN** a `PartyMemberPanel` has not been bound to a `CombatActor` (only to a `Character`)
- **THEN** no stat modifier icon SHALL be drawn even if persistent statuses exist

#### Scenario: Stat modifiers update on signal

- **WHEN** a `PartyMemberPanel` is bound to a `CombatActor` and the actor's `stat_modifiers_changed` signal fires
- **THEN** the panel SHALL `queue_redraw()` so the next frame reflects the updated stack

### Requirement: PartyMemberPanel renders an enlarged portrait placeholder with a level badge

`PartyMemberPanel` SHALL reserve a centered character image placeholder larger than the previous 48x48 icon area, using the vertical space above the HP bar with minimal dead gap. Until real character art exists, this area SHALL continue to use a dummy or placeholder rendering. The member level SHALL be rendered as a small badge at the upper-right of the portrait area.

#### Scenario: Portrait placeholder is larger than the previous icon

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the portrait placeholder area SHALL be larger than `48x48`

#### Scenario: Portrait placeholder is centered

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the portrait placeholder area SHALL be horizontally centered within the panel

#### Scenario: Portrait uses space above HP bar

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the bottom of the portrait placeholder SHALL sit close to the HP bar rather than leaving a large unused gap

#### Scenario: Level badge appears at portrait upper-right

- **WHEN** `PartyMemberPanel` renders a member at level 3
- **THEN** the panel SHALL show `LV.3` or equivalent level text in a badge positioned at the upper-right of the portrait area

### Requirement: PartyMemberPanel renders HP and MP as bars with numeric values

`PartyMemberPanel` SHALL render HP and MP using color-coded bars plus numeric current/max values. HP SHALL use the existing HP color family and MP SHALL use the existing MP color family. Bar fill ratios SHALL be computed from `current / max` and clamped to a safe range.

When the panel is bound to a `CombatActor` (`_combat_actor != null`), the `current` value used for HP rendering SHALL be `_combat_displayed_hp` and the `current` value used for MP rendering SHALL be `_combat_displayed_mp`. When not bound to a `CombatActor`, the `current` values SHALL come from the live `_data.current_hp` / `_data.current_mp` as before.

#### Scenario: HP bar reflects current HP ratio out of combat
- **WHEN** a member out of combat has `current_hp = 8` and `max_hp = 10`
- **THEN** the HP bar SHALL render approximately 80 percent filled and the numeric HP value SHALL display `8 / 10` or equivalent text

#### Scenario: MP bar reflects current MP ratio out of combat
- **WHEN** a member out of combat has `current_mp = 5` and `max_mp = 20`
- **THEN** the MP bar SHALL render approximately 25 percent filled and the numeric MP value SHALL display `5 / 20` or equivalent text

#### Scenario: HP bar in combat reflects displayed HP, not live HP
- **WHEN** a panel is bound to a CombatActor whose live `current_hp = 3`, but `_combat_displayed_hp = 8` and `max_hp = 10`
- **THEN** the HP bar SHALL render approximately 80 percent filled and the numeric HP value SHALL display `8 / 10` or equivalent text

#### Scenario: MP bar in combat reflects displayed MP, not live MP
- **WHEN** a panel is bound to a CombatActor whose live `current_mp = 1`, but `_combat_displayed_mp = 5` and `max_mp = 20`
- **THEN** the MP bar SHALL render approximately 25 percent filled and the numeric MP value SHALL display `5 / 20` or equivalent text

#### Scenario: Zero maximum value is safe
- **WHEN** a member has `max_mp = 0`
- **THEN** the MP bar ratio calculation SHALL NOT divide by zero and SHALL still render a numeric MP value

### Requirement: PartyMemberPanel preserves combat feedback in the new card layout

`PartyMemberPanel` SHALL continue to render persistent status icons, combat stat modifier icons, incapacitated dimming, heal flash overlay, shake animation, lift animation, and death fade behavior in the portrait-forward card layout. Status and stat modifier icons SHALL be drawn in a reserved area and SHALL NOT collide with the HP/MP bars.

#### Scenario: Status icons do not collide with HP and MP bars

- **WHEN** a member has one or more persistent statuses and the panel renders HP/MP bars
- **THEN** the status icons SHALL be drawn inside panel bounds without overlapping the HP or MP bar rectangles

#### Scenario: Stat modifier icons do not collide with HP and MP bars

- **WHEN** a combat-bound member has one or more stat modifier icons and the panel renders HP/MP bars
- **THEN** the stat modifier icons SHALL be drawn inside panel bounds without overlapping the HP or MP bar rectangles

#### Scenario: Incapacitated dimming covers the full new panel

- **WHEN** a member is incapacitated
- **THEN** the dim overlay SHALL cover the entire enlarged `PartyMemberPanel`

### Requirement: PartyDisplay renders FRONT and BACK as framed row windows

`PartyDisplay` SHALL render the FRONT and BACK row labels inside framed row windows that enclose their corresponding three `PartyMemberPanel` cards.

#### Scenario: FRONT label appears inside the front row window

- **WHEN** `PartyDisplay` renders the party HUD
- **THEN** the FRONT label SHALL be inside the framed front row window

#### Scenario: BACK label appears inside the back row window

- **WHEN** `PartyDisplay` renders the party HUD
- **THEN** the BACK label SHALL be inside the framed back row window

#### Scenario: Row windows enclose party panels

- **WHEN** `PartyDisplay` lays out the party HUD
- **THEN** each row window SHALL enclose the three `PartyMemberPanel` cards in that row

### Requirement: PartyMemberPanel maintains combat-displayed HP and MP that lag behind live values

`PartyMemberPanel` SHALL maintain integer fields `_combat_displayed_hp` and `_combat_displayed_mp` that represent the values currently shown on the HP and MP bars during combat. The sentinel value `-1` indicates that the panel is not in combat mode.

`bind_combat_actor(actor)` SHALL set `_combat_displayed_hp = actor.current_hp` and `_combat_displayed_mp = actor.current_mp` when `actor` is non-null. `bind_combat_actor(null)` SHALL reset both to `-1`.

`PartyMemberPanel` SHALL provide three public methods:
- `apply_combat_hp_delta(delta: int)`: assigns `_combat_displayed_hp = clampi(_combat_displayed_hp + delta, 0, max_hp)` and queues a redraw.
- `apply_combat_mp_delta(delta: int)`: assigns `_combat_displayed_mp = clampi(_combat_displayed_mp + delta, 0, max_mp)` and queues a redraw.
- `set_combat_displayed_hp(value: int)`: assigns `_combat_displayed_hp = clampi(value, 0, max_hp)` and queues a redraw.

While in combat mode, `_on_character_hp_changed` and `_on_character_mp_changed` SHALL still refresh `_data` from the live Character (so non-bar fields such as level/name stay current) and SHALL still call `queue_redraw()`, but they SHALL NOT modify `_combat_displayed_hp` / `_combat_displayed_mp`.

#### Scenario: bind_combat_actor latches displayed values from live actor
- **WHEN** a panel is bound to a CombatActor with `current_hp = 12`, `current_mp = 5`
- **THEN** `_combat_displayed_hp` SHALL equal `12` and `_combat_displayed_mp` SHALL equal `5`

#### Scenario: bind_combat_actor(null) resets displayed values to -1
- **WHEN** a panel is currently in combat mode and `bind_combat_actor(null)` is called
- **THEN** `_combat_displayed_hp` SHALL equal `-1` and `_combat_displayed_mp` SHALL equal `-1`

#### Scenario: apply_combat_hp_delta clamps to 0 and max_hp
- **WHEN** a panel has `_combat_displayed_hp = 3` and `max_hp = 10`, and `apply_combat_hp_delta(-7)` is called
- **THEN** `_combat_displayed_hp` SHALL equal `0` (not negative)
- **WHEN** the same panel then receives `apply_combat_hp_delta(+15)`
- **THEN** `_combat_displayed_hp` SHALL equal `10` (clamped to max_hp)

#### Scenario: apply_combat_mp_delta clamps to 0 and max_mp
- **WHEN** a panel has `_combat_displayed_mp = 4` and `max_mp = 10`, and `apply_combat_mp_delta(-6)` is called
- **THEN** `_combat_displayed_mp` SHALL equal `0`

#### Scenario: set_combat_displayed_hp forces an exact value
- **WHEN** a panel has `_combat_displayed_hp = 5` and `set_combat_displayed_hp(0)` is called
- **THEN** `_combat_displayed_hp` SHALL equal `0`

#### Scenario: live hp_changed during combat does not move displayed HP
- **WHEN** a panel is bound to a CombatActor with `_combat_displayed_hp = 10`, and the live `Character.current_hp` is then assigned `2` (e.g. by mid-resolve mutation)
- **THEN** `_combat_displayed_hp` SHALL still equal `10`
- **AND** `_data.current_hp` SHALL be refreshed to reflect the live value
- **AND** `queue_redraw()` SHALL still be called

#### Scenario: After combat ends, hp_changed drives the bar again
- **WHEN** `bind_combat_actor(null)` resets the panel to non-combat mode, then the live `Character.current_hp` changes
- **THEN** the HP bar SHALL render the new live value (existing non-combat behavior is preserved)

### Requirement: PartyMemberPanel renders default job portraits
PartyMemberPanel SHALL render a default portrait image for a party member when that member's `PartyMemberData.job_id` matches a known job portrait asset. The default portrait set SHALL include one image for each existing job id: `fighter`, `mage`, `priest`, `thief`, `bishop`, `samurai`, `lord`, and `ninja`. The portrait image SHALL be drawn inside the existing portrait rectangle before the level and name badges are rendered.

#### Scenario: Known job id resolves a portrait
- **WHEN** a PartyMemberPanel is set with PartyMemberData whose job_id is `&"fighter"` and the fighter portrait asset exists
- **THEN** the panel SHALL resolve a portrait texture for `fighter`
- **AND** the portrait SHALL be drawn inside `get_portrait_rect()`

#### Scenario: Each defined job has a portrait mapping
- **WHEN** PartyMemberPanel is asked to resolve portraits for `fighter`, `mage`, `priest`, `thief`, `bishop`, `samurai`, `lord`, and `ninja`
- **THEN** each job id SHALL resolve to a non-empty project asset path under `res://assets/images/portraits/jobs/`

#### Scenario: Unknown job falls back to placeholder
- **WHEN** a PartyMemberPanel is set with PartyMemberData whose job_id is `&"unknown_job"`
- **THEN** the panel SHALL NOT resolve a job portrait texture
- **AND** the existing placeholder portrait SHALL remain the fallback rendering

#### Scenario: Missing job id falls back to placeholder
- **WHEN** a PartyMemberPanel is set with PartyMemberData whose job_id is empty
- **THEN** the panel SHALL NOT resolve a job portrait texture
- **AND** the existing placeholder portrait SHALL remain the fallback rendering

### Requirement: Character display data carries canonical job id
Character.to_party_member_data() SHALL populate `PartyMemberData.job_id` from the character's canonical `JobData.id` when a job is present. If the job has no id, the value SHALL use the same fallback identity that Character serialization uses for job ids. If neither id nor resource path is available, the display value SHALL fall back to the normalized `JobData.job_name` when present.

#### Scenario: Character display data includes job id
- **WHEN** Character.to_party_member_data() is called for a character whose JobData id is `&"mage"`
- **THEN** the returned PartyMemberData job_id SHALL be `&"mage"`

#### Scenario: Character display data tolerates missing job
- **WHEN** Character.to_party_member_data() is called for a character with no job
- **THEN** the returned PartyMemberData job_id SHALL be empty

#### Scenario: Character display data falls back to job name
- **WHEN** Character.to_party_member_data() is called for a character whose JobData has no id and no resource path but has job_name "Mage"
- **THEN** the returned PartyMemberData job_id SHALL be `&"mage"`

