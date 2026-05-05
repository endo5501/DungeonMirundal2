## ADDED Requirements

### Requirement: Dungeon step ticks emit a signal for HUD notification

The system SHALL, on every `STATUS_TICK_STEP_INTERVAL`-th successful step in the dungeon (default `5`), invoke `StatusTickService.tick_character_step(character, status_repo)` for every living character in the party guild. Steps that do not land on the interval SHALL NOT trigger any tick. For every entry in the returned `ticks` array, the system SHALL emit a `dungeon_status_tick(character_name: String, status_id: StringName, amount: int)` signal so that the dungeon HUD can render a one-line notification.

When `tick_character_step` returns `total_loss == 0`, no signal SHALL be emitted.

Movement SHALL proceed even when ticks reduce a character's HP to 1; tick-induced damage MUST NOT block or cancel the step itself.

#### Scenario: Tick fires once per interval, not on every step
- **WHEN** a single poisoned member takes `STATUS_TICK_STEP_INTERVAL` consecutive steps
- **THEN** `dungeon_status_tick` SHALL be emitted exactly once (on the Nth step), and the member SHALL lose `tick_in_dungeon` HP exactly once

#### Scenario: Steps below the interval threshold do not tick
- **WHEN** a poisoned member takes fewer than `STATUS_TICK_STEP_INTERVAL` steps
- **THEN** no HP loss SHALL occur and no `dungeon_status_tick` SHALL be emitted

#### Scenario: Step with no afflicted members emits no signal
- **WHEN** the interval fires and no member holds a tick-bearing PERSISTENT status
- **THEN** no `dungeon_status_tick` signal SHALL be emitted

#### Scenario: Tick that floors HP at 1 still emits a signal with the actual amount
- **WHEN** a poisoned character at HP=2 reaches the tick interval (poison would deal more than 1 damage but is capped at 1 by the HP floor)
- **THEN** the emitted signal SHALL have `amount == 1`
