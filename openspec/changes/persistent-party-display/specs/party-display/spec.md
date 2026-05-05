## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: DungeonScreen binds PartyDisplay to live Characters when entering the dungeon

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
