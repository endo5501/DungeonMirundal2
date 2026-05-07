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

### Requirement: PartyHud attaches to a TurnEngine to receive combat reaction signals

`PartyHud` SHALL provide a method `attach_to_turn_engine(engine: TurnEngine)` that connects the engine's UI signals (`actor_action_started`, `actor_dealt_damage`, `actor_healed`, `actor_died`, `actor_status_inflicted`, `actor_spent_mp`) to internal handlers that route the events to the corresponding `PartyMemberPanel` based on the actor's wrapped Character. When invoked while already attached, the new attach SHALL detach from the previous engine first.

For each `PartyCombatant` in `engine.party`, `PartyHud` SHALL also bind that `PartyCombatant` (a `CombatActor`) to the matching `PartyMemberPanel` via `bind_combat_actor()` so that stat modifier icons can render during the battle and so that the panel latches its `_combat_displayed_hp` / `_combat_displayed_mp` from the actor's live values.

While `begin_buffering()` is active, signal handlers SHALL queue events tagged with the engine's `get_pending_action_index()` so they replay in lockstep with log line playback. Damage / heal / spent-mp events SHALL include a `delta` field on their queue entry equal to the signed change to apply to the panel's combat-displayed value when the event is flushed.

#### Scenario: attach_to_turn_engine connects all six signals

- **WHEN** `PartyHud.attach_to_turn_engine(engine)` is called with a fresh TurnEngine
- **THEN** all six signals (`actor_action_started`, `actor_dealt_damage`, `actor_healed`, `actor_died`, `actor_status_inflicted`, `actor_spent_mp`) SHALL have a connection from `engine` to the PartyHud handler

#### Scenario: actor_action_started routes to the matching panel

- **WHEN** `PartyHud` is attached to a `TurnEngine`, and the engine emits `actor_action_started(pc, &"attack")` where `pc` is a `PartyCombatant` with `pc.character == C`
- **THEN** the `PartyMemberPanel` whose `_character == C` SHALL have its `play_lift_animation()` invoked

#### Scenario: actor_died routes to the matching panel

- **WHEN** the attached `TurnEngine` emits `actor_died(pc)` where `pc.character == C`
- **THEN** the `PartyMemberPanel` whose `_character == C` SHALL have its `play_die_animation()` invoked

#### Scenario: PartyCombatants are bound to panels for stat modifier display

- **WHEN** `PartyHud.attach_to_turn_engine(engine)` is called with `engine.party` containing PartyCombatants whose `character` fields match the panels' bound Characters
- **THEN** each panel SHALL have its `bind_combat_actor()` called with the matching `PartyCombatant`

#### Scenario: Monster actor signals are ignored by panels

- **WHEN** the attached `TurnEngine` emits `actor_died(mc)` where `mc` is a `MonsterCombatant`
- **THEN** no `PartyMemberPanel` SHALL be affected (no party member animation triggered)

#### Scenario: Re-attaching detaches from the previous engine first

- **WHEN** `PartyHud.attach_to_turn_engine(engine_A)` is called, then `attach_to_turn_engine(engine_B)` is called
- **THEN** the connections from `engine_A` SHALL be removed and only `engine_B` connections SHALL remain

#### Scenario: actor_dealt_damage queue entry carries a negative delta

- **WHEN** `begin_buffering()` is active and the attached engine emits `actor_dealt_damage(pc, 7, attacker)`
- **THEN** the queued entry SHALL include `type = "shake"`, `actor = pc`, `delta = -7`, and `step` equal to `engine.get_pending_action_index()` at emission time

#### Scenario: actor_healed queue entry carries a positive delta

- **WHEN** `begin_buffering()` is active and the attached engine emits `actor_healed(pc, 5, healer)`
- **THEN** the queued entry SHALL include `type = "flash"`, `actor = pc`, `delta = +5`, and `step` equal to `engine.get_pending_action_index()` at emission time

#### Scenario: actor_spent_mp queue entry carries a negative delta

- **WHEN** `begin_buffering()` is active and the attached engine emits `actor_spent_mp(pc, 4)`
- **THEN** the queued entry SHALL include `type = "mp_spend"`, `actor = pc`, `delta = -4`, and `step` equal to `engine.get_pending_action_index()` at emission time

### Requirement: PartyHud detaches from a TurnEngine after combat

`PartyHud` SHALL provide a method `detach_from_turn_engine()` that disconnects all UI signals (including `actor_spent_mp`) from the previously attached engine, clears each `PartyMemberPanel`'s `CombatActor` binding (`bind_combat_actor(null)`), detaches any monster panel previously registered via `attach_monster_panel`, and releases the engine reference. Calling `detach_from_turn_engine()` while not attached SHALL be a no-op.

#### Scenario: detach removes signal connections

- **WHEN** `PartyHud.attach_to_turn_engine(engine)` is followed by `PartyHud.detach_from_turn_engine()`
- **THEN** none of the six UI signals on `engine` SHALL have a connection to PartyHud handlers afterwards

#### Scenario: detach clears CombatActor bindings on panels

- **WHEN** `PartyHud.attach_to_turn_engine(engine)` is followed by `PartyHud.detach_from_turn_engine()`
- **THEN** every panel SHALL have its `_combat_actor` set back to null AND no stat modifier icons SHALL be rendered

#### Scenario: detach also releases attached monster panel

- **WHEN** `PartyHud.attach_monster_panel(monster_panel)` was called, then `detach_from_turn_engine()` is called
- **THEN** the monster panel reference SHALL be cleared so that subsequent `actor_died` events (if any leak through) do not mutate the released panel

### Requirement: PartyHud flushes combat-displayed value deltas in lockstep with log playback

When `PartyHud.flush_up_to_step(step)` releases a queued event whose `type` is `"shake"`, `"flash"`, or `"mp_spend"`, it SHALL apply the entry's `delta` to the matching `PartyMemberPanel`'s combat-displayed state **before** triggering the visual animation:
- `"shake"`: call `panel.apply_combat_hp_delta(delta)` then `panel.play_shake_animation()`.
- `"flash"`: call `panel.apply_combat_hp_delta(delta)` then `panel.play_heal_flash_animation()`.
- `"mp_spend"`: call `panel.apply_combat_mp_delta(delta)` (no animation).

For a `"die"` event whose `actor` is a `PartyCombatant`, `PartyHud` SHALL call `panel.set_combat_displayed_hp(0)` before `panel.play_die_animation()` so the HP bar reaches zero in the same flush step as the fade.

#### Scenario: shake event applies HP delta then plays animation
- **WHEN** a queued entry `{type: "shake", actor: pc, delta: -7, step: 2}` is released by `flush_up_to_step(2)`
- **THEN** `panel.apply_combat_hp_delta(-7)` SHALL be called first
- **AND** `panel.play_shake_animation()` SHALL be called afterwards

#### Scenario: flash event applies positive HP delta then plays animation
- **WHEN** a queued entry `{type: "flash", actor: pc, delta: +5, step: 1}` is released by `flush_up_to_step(1)`
- **THEN** `panel.apply_combat_hp_delta(+5)` SHALL be called first
- **AND** `panel.play_heal_flash_animation()` SHALL be called afterwards

#### Scenario: mp_spend event applies MP delta with no animation
- **WHEN** a queued entry `{type: "mp_spend", actor: pc, delta: -4, step: 3}` is released by `flush_up_to_step(3)`
- **THEN** `panel.apply_combat_mp_delta(-4)` SHALL be called
- **AND** no extra panel animation SHALL be triggered for this entry alone

#### Scenario: die event zeroes displayed HP before fade
- **WHEN** a queued entry `{type: "die", actor: pc, step: 4}` is released by `flush_up_to_step(4)` and `pc` is a `PartyCombatant`
- **THEN** `panel.set_combat_displayed_hp(0)` SHALL be called first
- **AND** `panel.play_die_animation()` SHALL be called afterwards

### Requirement: PartyHud bridges actor_died to an attached monster panel

`PartyHud` SHALL provide methods `attach_monster_panel(panel: CombatMonsterPanel)` and `detach_monster_panel()` that store / clear a single `CombatMonsterPanel` reference. While buffering is active, an `actor_died(actor)` event whose `actor` is a `MonsterCombatant` SHALL queue an entry `{type: "die", actor: <monster>, step: N}` and SHALL release it via `flush_up_to_step(N)` by calling `panel.apply_died(actor)` on the attached monster panel. When buffering is not active, `apply_died` SHALL be invoked immediately upon receiving the signal.

When no monster panel is attached, monster `actor_died` events SHALL be silently ignored by the monster bridge (other party-side handling is unaffected).

#### Scenario: monster die event releases via apply_died on attached panel
- **WHEN** `attach_monster_panel(mp)` was called, buffering is active, and the engine emits `actor_died(mc)` where `mc` is a `MonsterCombatant` at step N
- **THEN** the queue SHALL contain an entry `{type: "die", actor: mc, step: N}`
- **AND** `flush_up_to_step(N)` SHALL invoke `mp.apply_died(mc)`

#### Scenario: monster die event without attached panel is a no-op
- **WHEN** no monster panel is attached and the engine emits `actor_died(mc)` where `mc` is a `MonsterCombatant`
- **THEN** no panel method SHALL be called and no error SHALL occur

#### Scenario: monster die outside buffering applies immediately
- **WHEN** `attach_monster_panel(mp)` was called, buffering is NOT active, and the engine emits `actor_died(mc)` for a `MonsterCombatant`
- **THEN** `mp.apply_died(mc)` SHALL be called synchronously
