## ADDED Requirements

### Requirement: CombatActor emits stat_modifiers_changed when its modifier stack mutates

`CombatActor` SHALL define a signal `stat_modifiers_changed()` (zero arguments) and SHALL emit it whenever its `stat_modifier_stack` is mutated in a way that changes the visible modifier set: an entry is added, an entry's delta or duration is updated, or an entry is removed (including via duration tick reaching zero). Subscribers are expected to re-read `stat_modifier_stack` after the signal fires to obtain the current state.

#### Scenario: add() emits the signal

- **WHEN** `combat_actor.stat_modifier_stack.add(&"attack", 2, 3)` is called on a CombatActor whose stack did not previously contain that entry
- **THEN** `combat_actor.stat_modifiers_changed` SHALL fire exactly once

#### Scenario: add() that replaces an existing weaker entry emits the signal

- **WHEN** an existing entry `(&"attack", +1, duration 2)` is present and `add(&"attack", +3, 4)` is called (stronger, replaces)
- **THEN** `combat_actor.stat_modifiers_changed` SHALL fire exactly once

#### Scenario: add() that is a no-op (weaker than existing) does not emit

- **WHEN** an existing entry `(&"attack", +3, 4)` is present and `add(&"attack", +1, 2)` is called (weaker, no-op)
- **THEN** `combat_actor.stat_modifiers_changed` SHALL NOT fire

#### Scenario: Tick that removes an entry emits the signal

- **WHEN** an entry has `duration = 1` and the per-turn tick decrements it to `0` and removes it
- **THEN** `combat_actor.stat_modifiers_changed` SHALL fire exactly once for that removal

#### Scenario: Tick that decrements but keeps an entry does not emit

- **WHEN** an entry has `duration = 3` and the tick decrements it to `2` (still active)
- **THEN** `combat_actor.stat_modifiers_changed` SHALL NOT fire (no visible change beyond duration)

Note: emission for duration-only changes is intentionally omitted so HUD subscribers do not redraw on every turn for stable modifiers.
