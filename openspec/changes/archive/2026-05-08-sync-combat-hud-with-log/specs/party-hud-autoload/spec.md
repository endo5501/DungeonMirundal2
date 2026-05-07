## MODIFIED Requirements

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

## ADDED Requirements

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
