## MODIFIED Requirements

### Requirement: CombatOverlay renders a fixed Wizardry-style layout

The system SHALL display, while a battle is active, a fixed layout consisting of an enemy presentation area, a right-side battle UI column, and the persistent bottom party HUD. The enemy presentation area SHALL show monster species with per-species remaining counts in a framed `ENEMY` list window and dummy enemy monster images in a separate graphics area. The right-side battle UI column SHALL contain framed CombatLog and active command or selection windows. During battle, the normal dungeon minimap SHALL be hidden so the right-side battle UI can use the full column without overlapping itself or the party HUD. The CombatLog window SHALL be vertically compact enough to match its title plus eight retained visible log lines, leaving the active command or selection window to start higher in the same column. The CombatLog SHALL split multi-line action text into retained visible lines before enforcing its line cap. The CombatLog SHALL clip its contents to its own window so repeated battles cannot draw log text over command windows. The active command or selection window SHALL keep a clear vertical gap above the bottom party HUD. The bottom party HUD SHALL remain owned by PartyHud/PartyDisplay rather than by CombatOverlay.

The CommandMenu options for a living PartyCombatant SHALL be assembled in this order: 「こうげき」, 「ぼうぎょ」, 「魔術」 (only if the actor's job has `mage_school == true`), 「祈り」 (only if the actor's job has `priest_school == true`), 「アイテム」, 「にげる」. For a non-magic actor (e.g. Fighter), the magic entries SHALL be omitted entirely (not greyed-out) so the menu shows only 「こうげき」/「ぼうぎょ」/「アイテム」/「にげる」. For a Bishop both 「魔術」 and 「祈り」 SHALL appear in this order. The position of 「アイテム」 and 「にげる」 SHALL be the last two entries regardless of magic visibility.

The MonsterPanel's per-species remaining counts SHALL be derived from a panel-internal `_displayed_alive` table that is initialized via `setup_for_battle(monsters)` at battle start (all monsters marked alive) and is mutated only by `apply_died(actor)` calls. The MonsterPanel SHALL NOT consult the live `MonsterCombatant.is_alive()` for count rendering during a battle, so that monster removal from the list is bound to log playback rather than to the engine's atomic resolution.

#### Scenario: MonsterPanel shows species and remaining count
- **WHEN** the monster party contains 2 live slimes and 1 live goblin
- **THEN** the MonsterPanel SHALL display text including both `"スライム"` and `"ゴブリン"` with their remaining counts

#### Scenario: MonsterPanel updates as monsters die
- **WHEN** one slime dies during resolution and the corresponding death log line is reached during playback
- **THEN** at or after the matching `flush_up_to_step` for that step, the MonsterPanel SHALL show the reduced count for slimes
- **AND** before that step the MonsterPanel SHALL still show the pre-death count

#### Scenario: MonsterPanel does not show per-individual HP
- **WHEN** any monster is alive
- **THEN** the MonsterPanel SHALL NOT show numeric HP for individual monsters

#### Scenario: MonsterPanel shows dummy enemy visuals
- **WHEN** the monster party contains one or more living monsters and the battle UI is refreshed
- **THEN** the enemy presentation area SHALL render at least one dummy monster image or procedural placeholder representing the living enemies

#### Scenario: MonsterPanel uses an ENEMY list window
- **WHEN** the monster party contains one or more living monsters and the battle UI is refreshed
- **THEN** the enemy count list SHALL be shown in a framed window titled `"ENEMY"` and the window SHALL NOT span the enemy graphics area

#### Scenario: Monster visuals sit lower with stable baseline
- **WHEN** the monster party contains multiple living monsters
- **THEN** the dummy monster visuals SHALL be positioned lower in the battle area and SHALL share a stable baseline

#### Scenario: CombatLog is placed in the right-side battle column
- **WHEN** CombatOverlay builds its combat UI
- **THEN** the CombatLog SHALL be anchored in the right-side battle UI column and SHALL NOT occupy the center-left enemy presentation area

#### Scenario: Dungeon minimap is hidden during combat
- **WHEN** a battle becomes active
- **THEN** the normal dungeon minimap SHALL be hidden
- **AND** when the battle is no longer active, the minimap visibility SHALL be restored to its previous state

#### Scenario: CombatLog starts at the top of the right-side battle column
- **WHEN** CombatOverlay builds its combat UI for battle
- **THEN** the CombatLog SHALL NOT reserve vertical space for the minimap

#### Scenario: CombatLog uses the available window height
- **WHEN** more than four combat log lines are appended
- **THEN** the CombatLog SHALL retain exactly eight recent lines to fit the compact battle log window without overlapping command windows

#### Scenario: Multi-line actions count as visible log lines
- **WHEN** a spell or other action appends text containing multiple newline-separated display rows
- **THEN** the CombatLog SHALL split that text into separate retained visible lines
- **AND** the eight-line cap SHALL be applied to visible lines rather than to action entries

#### Scenario: CombatLog is compact and command windows start higher
- **WHEN** CombatOverlay shows the right-side CombatLog and active command window
- **THEN** the CombatLog SHALL occupy only the upper compact portion of the right-side column
- **AND** the active command window SHALL begin close below the CombatLog instead of leaving a large unused vertical gap
- **AND** the active command window SHALL end high enough to avoid overlapping the bottom party HUD

#### Scenario: CombatLog content stays inside its window
- **WHEN** repeated battles append enough log lines to fill the CombatLog
- **THEN** log text SHALL NOT be drawn over the command windows below it

## ADDED Requirements

### Requirement: CombatOverlay synchronizes panel refresh with log playback

CombatOverlay SHALL NOT call `_refresh_panels()` immediately after `TurnEngine.resolve_turn(rng)` returns inside `_resolve_turn_now()`. Instead, the per-step visual updates SHALL flow through `PartyHud.flush_up_to_step` driven by `_show_next_log_line`, and a single final `_refresh_panels()` SHALL be issued from `_on_log_playback_finished` to guarantee that the displayed state ultimately matches the engine's canonical state once playback completes.

If log playback is cancelled (e.g. via `cancel_log_playback`), the cleanup of buffered HUD events (existing behavior) SHALL drain remaining deltas and the next `_refresh_panels()` SHALL still produce a state consistent with the engine.

#### Scenario: resolve_turn return does not refresh panels
- **WHEN** `_resolve_turn_now()` calls `_turn_engine.resolve_turn(rng)` and the call returns
- **THEN** `_refresh_panels()` SHALL NOT be called within `_resolve_turn_now()` after that return

#### Scenario: log playback completion refreshes panels
- **WHEN** `_on_log_playback_finished()` is invoked after the last log line is shown
- **THEN** `_refresh_panels()` SHALL be called once before any battle finalization

#### Scenario: monsters remain visible until their death log line
- **WHEN** an attack kills a monster during `resolve_turn` at action index N, but the log has only displayed up through index N-1
- **THEN** the MonsterPanel SHALL still show the monster as alive
- **AND** when log playback advances to index N, the MonsterPanel SHALL show the monster as removed

### Requirement: CombatOverlay registers the monster panel with PartyHud at battle start

In `start_encounter(monster_party)`, after `PartyHud.attach_to_turn_engine(_turn_engine)`, CombatOverlay SHALL:
1. Call `_monster_panel.setup_for_battle(_turn_engine.monsters)` to initialize the panel's `_displayed_alive` table to all-true.
2. Call `PartyHud.attach_monster_panel(_monster_panel)` so that subsequent `actor_died` events for `MonsterCombatant` actors are bridged to the panel through the buffering pipeline.

When the battle ends and `PartyHud.detach_from_turn_engine()` is called, the matching `detach_monster_panel()` step SHALL also occur (handled by PartyHud) so the monster panel reference is released.

#### Scenario: setup_for_battle initializes displayed_alive
- **WHEN** `start_encounter` is invoked with a monster party containing 3 monsters
- **THEN** after the call, the MonsterPanel's internal `_displayed_alive` table SHALL contain exactly those 3 monsters mapped to `true`

#### Scenario: attach_monster_panel is called after attach_to_turn_engine
- **WHEN** `start_encounter` runs
- **THEN** `PartyHud.attach_monster_panel(_monster_panel)` SHALL be called after `PartyHud.attach_to_turn_engine(_turn_engine)`

#### Scenario: Battle end releases monster panel reference
- **WHEN** the battle is resolved and `PartyHud.detach_from_turn_engine()` is invoked
- **THEN** PartyHud's stored monster panel reference SHALL be cleared
