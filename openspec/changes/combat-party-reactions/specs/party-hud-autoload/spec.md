## ADDED Requirements

### Requirement: PartyHud attaches to a TurnEngine to receive combat reaction signals

`PartyHud` SHALL provide a method `attach_to_turn_engine(engine: TurnEngine)` that connects the engine's UI signals (`actor_action_started`, `actor_dealt_damage`, `actor_healed`, `actor_died`, `actor_status_inflicted`) to internal handlers that route the events to the corresponding `PartyMemberPanel` based on the actor's wrapped Character. When invoked while already attached, the new attach SHALL detach from the previous engine first.

For each `PartyCombatant` in `engine.party`, `PartyHud` SHALL also bind that `PartyCombatant` (a `CombatActor`) to the matching `PartyMemberPanel` via `bind_combat_actor()` so that stat modifier icons can render during the battle.

#### Scenario: attach_to_turn_engine connects all five signals

- **WHEN** `PartyHud.attach_to_turn_engine(engine)` is called with a fresh TurnEngine
- **THEN** all five signals (`actor_action_started`, `actor_dealt_damage`, `actor_healed`, `actor_died`, `actor_status_inflicted`) SHALL have a connection from `engine` to the PartyHud handler

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
- **THEN** no `PartyMemberPanel` SHALL be affected (no animation triggered)

#### Scenario: Re-attaching detaches from the previous engine first

- **WHEN** `PartyHud.attach_to_turn_engine(engine_A)` is called, then `attach_to_turn_engine(engine_B)` is called
- **THEN** the connections from `engine_A` SHALL be removed and only `engine_B` connections SHALL remain

### Requirement: PartyHud detaches from a TurnEngine after combat

`PartyHud` SHALL provide a method `detach_from_turn_engine()` that disconnects all UI signals from the previously attached engine, clears each `PartyMemberPanel`'s `CombatActor` binding (`bind_combat_actor(null)`), and releases the engine reference. Calling `detach_from_turn_engine()` while not attached SHALL be a no-op.

#### Scenario: detach removes signal connections

- **WHEN** `PartyHud.attach_to_turn_engine(engine)` is followed by `PartyHud.detach_from_turn_engine()`
- **THEN** none of the five UI signals on `engine` SHALL have a connection to PartyHud handlers afterwards

#### Scenario: detach clears CombatActor bindings on panels

- **WHEN** `PartyHud.attach_to_turn_engine(engine)` is followed by `PartyHud.detach_from_turn_engine()`
- **THEN** every panel SHALL have its `_combat_actor` set back to null AND no stat modifier icons SHALL be rendered

#### Scenario: detach when not attached is a no-op

- **WHEN** `PartyHud.detach_from_turn_engine()` is called without a prior `attach_to_turn_engine()`
- **THEN** the call SHALL not error and SHALL leave PartyHud state unchanged
