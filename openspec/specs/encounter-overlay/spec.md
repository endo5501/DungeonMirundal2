## ADDED Requirements

### Requirement: EncounterOverlay presents a monster party and blocks dungeon input
The system SHALL provide an `EncounterOverlay` (CanvasLayer) that, when started with a MonsterParty, is displayed on top of the dungeon screen and consumes keyboard input until dismissed. A concrete implementation (`CombatOverlay`, ADDED by combat-system) SHALL extend `EncounterOverlay` and present a full Wizardry-style battle UI; the base stub (text-only confirmation) is retained only as a testing baseline for the contract.

#### Scenario: Overlay appears with monster names
- **WHEN** `EncounterOverlay.start_encounter(monster_party)` is called with a party of 2 slimes and 1 goblin
- **THEN** the overlay SHALL become visible and SHALL display the monster names (e.g., "スライム x2", "ゴブリン x1")

#### Scenario: Dungeon input is blocked while overlay is visible
- **WHEN** the EncounterOverlay is visible
- **THEN** keyboard events for movement SHALL NOT reach the DungeonScreen

#### Scenario: Overlay is hidden before start
- **WHEN** an EncounterOverlay is instantiated but `start_encounter` has not been called
- **THEN** the overlay SHALL NOT be visible

#### Scenario: Combat overlay subclass replaces stub in production wiring
- **WHEN** the application is running in production wiring
- **THEN** the overlay instance received by `EncounterCoordinator` SHALL be a `CombatOverlay` (a subclass of `EncounterOverlay`), not the raw stub

### Requirement: EncounterOverlay resolves via signal contract
The system SHALL ensure that `EncounterOverlay` emits `encounter_resolved(outcome: EncounterOutcome)` exactly once when the overlay is dismissed, regardless of whether the concrete implementation is the stub or the full combat UI. The signal contract and function signature SHALL NOT change.

#### Scenario: Confirm input dismisses the stub overlay
- **WHEN** the stub overlay is visible and the user presses the confirm key (Enter/Space)
- **THEN** the overlay SHALL hide itself and SHALL emit `encounter_resolved` exactly once

#### Scenario: Dungeon input resumes after resolution
- **WHEN** `encounter_resolved` has been emitted
- **THEN** subsequent keyboard events SHALL reach the DungeonScreen again

#### Scenario: Combat overlay emits resolved only after the result panel confirm
- **WHEN** the `CombatOverlay` subclass reaches a terminal battle state
- **THEN** it SHALL display a ResultPanel first, and SHALL emit `encounter_resolved` exactly once upon the user's confirm input on that panel

### Requirement: EncounterOutcome is populated with battle results
The system SHALL provide an `EncounterOutcome` (RefCounted) with:
- `result: { ESCAPED, CLEARED, WIPED }`
- `gained_experience: int` (per-member distributed experience; `0` unless `result == CLEARED`)
- `drops: Array` (reserved for items-and-economy; SHALL always be an empty array in combat-system)

`EncounterOutcome` SHALL be populated by the concrete overlay implementation to reflect the actual battle outcome (stub: always `CLEARED` with `gained_experience = 0`; combat: real values).

#### Scenario: Stub sets result to CLEARED with zero experience
- **WHEN** the stub overlay constructs an EncounterOutcome
- **THEN** the outcome SHALL have `result == CLEARED` and `gained_experience == 0` and `drops.is_empty() == true`

#### Scenario: CombatOverlay populates CLEARED outcome with experience
- **WHEN** the `CombatOverlay` ends a battle with all monsters dead and distributes `25` experience per member
- **THEN** the emitted EncounterOutcome SHALL have `result == CLEARED` and `gained_experience == 25`

#### Scenario: CombatOverlay populates WIPED outcome with zero experience
- **WHEN** the `CombatOverlay` ends a battle with all party members dead
- **THEN** the emitted EncounterOutcome SHALL have `result == WIPED` and `gained_experience == 0`

#### Scenario: CombatOverlay populates ESCAPED outcome with zero experience
- **WHEN** the `CombatOverlay` ends a battle with a successful escape
- **THEN** the emitted EncounterOutcome SHALL have `result == ESCAPED` and `gained_experience == 0`

#### Scenario: drops is always empty in combat-system
- **WHEN** any EncounterOutcome is emitted during the combat-system scope
- **THEN** `drops` SHALL be an empty array (items-and-economy populates this field in a later change)
