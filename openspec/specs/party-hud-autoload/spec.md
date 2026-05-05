## Purpose
ゲーム中のあらゆるシーンで常駐表示されるパーティ HUD を、シーンの寿命に依存しない単一の Autoload として規定する。アクティブパーティの bind、シーン毎の表示/非表示、編成変更への追従、オーバーレイとの共存を扱う。

## Requirements

### Requirement: PartyHud is registered as a singleton autoload

The system SHALL register `PartyHud` as a Godot autoload singleton, defined at `src/autoload/party_hud.gd`, registered as `PartyHud` in `project.godot`. `PartyHud` SHALL extend `CanvasLayer` and SHALL own a single `PartyDisplay` instance as a child node throughout the game session.

#### Scenario: PartyHud is reachable from any scene
- **WHEN** any scene script accesses the global identifier `PartyHud`
- **THEN** it SHALL receive the `PartyHud` autoload instance (not null)

#### Scenario: PartyHud is not destroyed across scene changes
- **WHEN** the active screen is changed via `main.gd` from one screen to another
- **THEN** `PartyHud` SHALL remain the same `Node` instance (no `queue_free` and re-instantiation)

#### Scenario: PartyHud owns a PartyDisplay
- **WHEN** `PartyHud._ready()` completes
- **THEN** `PartyHud` SHALL have exactly one `PartyDisplay` child node

### Requirement: PartyHud exposes show_hud() and hide_hud() controls

`PartyHud` SHALL expose `show_hud()` and `hide_hud()` methods that toggle the `visible` property of the autoload (and thereby the visibility of the contained `PartyDisplay`). The methods SHALL be idempotent — calling `show_hud()` while already visible, or `hide_hud()` while already hidden, SHALL be a no-op.

#### Scenario: show_hud makes the HUD visible
- **WHEN** `PartyHud.hide_hud()` has been called and then `PartyHud.show_hud()` is called
- **THEN** `PartyHud.visible` SHALL be `true`

#### Scenario: hide_hud makes the HUD invisible
- **WHEN** `PartyHud.show_hud()` has been called and then `PartyHud.hide_hud()` is called
- **THEN** `PartyHud.visible` SHALL be `false`

#### Scenario: show_hud is idempotent
- **WHEN** `PartyHud.show_hud()` is called twice in succession
- **THEN** the second call SHALL be a no-op AND `PartyHud.visible` SHALL be `true`

### Requirement: PartyHud binds to the active party from GameState

`PartyHud` SHALL provide a method `bind_active_party()` that reads the current party composition (front row and back row of `Character` instances) from `GameState` and binds it to its internal `PartyDisplay` via `bind_party_characters(front_row, back_row)`. Empty slots in the party SHALL be passed as `null` entries.

#### Scenario: bind_active_party uses GameState
- **WHEN** `GameState` has a guild with an active party of three front-row Characters and three back-row Characters, and `PartyHud.bind_active_party()` is called
- **THEN** the internal `PartyDisplay` SHALL receive `bind_party_characters` with those six Characters in their slots

#### Scenario: bind_active_party handles partial parties
- **WHEN** `GameState` has only two front-row Characters and one back-row Character, and `PartyHud.bind_active_party()` is called
- **THEN** the internal `PartyDisplay` SHALL be bound with arrays containing those Characters and `null` for empty slots

### Requirement: PartyHud rebinds when the active party changes

`PartyHud` SHALL connect to a party-changed notification signal on `GameState` (or `Guild`) and SHALL re-invoke `bind_active_party()` when notified. Adding/removing/reordering members in the active party (e.g., from the guild's party formation UI) SHALL eventually be reflected in the HUD without manual rebinding from screen code.

#### Scenario: Adding a member rebinds the HUD
- **WHEN** the active party has two front-row members, `PartyHud.bind_active_party()` has run, and a third member is added to the front row via the guild
- **THEN** the HUD's third front-row panel SHALL eventually display the new member's data

#### Scenario: Removing a member rebinds the HUD
- **WHEN** a Character is removed from the active party and the appropriate signal fires
- **THEN** the corresponding panel SHALL eventually render as empty (no data)

### Requirement: main.gd controls HUD visibility based on the active screen

`main.gd` SHALL call `PartyHud.show_hud()` when transitioning to a screen on which the HUD should be visible, and `PartyHud.hide_hud()` when transitioning to a screen on which it should be hidden. The visibility policy SHALL be:

- **Visible**: TownScreen, GuildScreen, Shop, Temple, DungeonEntrance, DungeonScreen
- **Hidden**: TitleScreen, LoadScreen, SaveScreen

#### Scenario: HUD is visible on TownScreen
- **WHEN** `main.gd` transitions from TitleScreen to TownScreen
- **THEN** `PartyHud.show_hud()` SHALL be called as part of that transition AND `PartyHud.visible` SHALL be `true` after the transition

#### Scenario: HUD is hidden on TitleScreen
- **WHEN** `main.gd` transitions from any screen to TitleScreen (e.g., quit_to_title)
- **THEN** `PartyHud.hide_hud()` SHALL be called as part of that transition AND `PartyHud.visible` SHALL be `false` after the transition

#### Scenario: HUD is visible on DungeonScreen
- **WHEN** `main.gd` transitions from DungeonEntrance to DungeonScreen
- **THEN** `PartyHud.visible` SHALL be `true` after the transition

#### Scenario: HUD is hidden on LoadScreen and SaveScreen
- **WHEN** `main.gd` displays LoadScreen or SaveScreen
- **THEN** `PartyHud.visible` SHALL be `false` while that screen is active

### Requirement: GuildScreen hides the HUD during party formation editing

`GuildScreen` SHALL call `PartyHud.hide_hud()` when entering its party formation sub-screen and SHALL call `PartyHud.show_hud()` when leaving it back to the main guild menu. This avoids displaying stale party data while the party is being edited.

#### Scenario: Entering formation hides the HUD
- **WHEN** the user opens the party formation UI from within GuildScreen
- **THEN** `PartyHud.visible` SHALL be `false`

#### Scenario: Leaving formation re-shows the HUD
- **WHEN** the user closes the party formation UI back to the GuildScreen main menu
- **THEN** `PartyHud.visible` SHALL be `true`

### Requirement: HUD remains visible during ESC menu and full-map overlays

When the ESC menu overlay or the full-map overlay is opened on top of a screen where the HUD is visible, the HUD SHALL remain visible (its visibility SHALL NOT be toggled by overlay open/close). Overlays MAY visually cover parts of the HUD via Z order without explicit hide.

#### Scenario: ESC menu does not hide the HUD
- **WHEN** ESC menu is opened on top of TownScreen or DungeonScreen
- **THEN** `PartyHud.visible` SHALL remain `true`

#### Scenario: Full-map overlay does not hide the HUD
- **WHEN** the full-map overlay is opened on top of DungeonScreen
- **THEN** `PartyHud.visible` SHALL remain `true`
