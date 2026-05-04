## ADDED Requirements

### Requirement: Dungeon step ticks emit a signal for HUD notification

The system SHALL, after each successful step in the dungeon, invoke `StatusTickService.tick_character_step(character, status_repo)` for every living character in the party guild. For every entry in the returned `ticks` array, the system SHALL emit a `dungeon_status_tick(character_name: String, status_id: StringName, amount: int)` signal so that the dungeon HUD can render a one-line notification.

When `tick_character_step` returns `total_loss == 0`, no signal SHALL be emitted.

Movement SHALL proceed even when ticks reduce a character's HP to 1; tick-induced damage MUST NOT block or cancel the step itself.

#### Scenario: Step with poisoned character emits one tick signal per character
- **WHEN** the party takes one step with two members holding `&"poison"` (each receives 2 damage)
- **THEN** `dungeon_status_tick` SHALL be emitted twice (once per character) with the corresponding name, status_id `&"poison"`, and amount `2`

#### Scenario: Step with no afflicted members emits no signal
- **WHEN** the party takes a step and no member holds a tick-bearing PERSISTENT status
- **THEN** no `dungeon_status_tick` signal SHALL be emitted

#### Scenario: Tick that floors HP at 1 still emits a signal with the actual amount
- **WHEN** a poisoned character at HP=2 takes a step (poison would deal 2 damage but is capped at 1)
- **THEN** the emitted signal SHALL have `amount == 1`
