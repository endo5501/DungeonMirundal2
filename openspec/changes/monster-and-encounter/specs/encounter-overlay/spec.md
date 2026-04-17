## ADDED Requirements

### Requirement: EncounterOverlay presents a monster party and blocks dungeon input
The system SHALL provide an `EncounterOverlay` (CanvasLayer) that, when started with a MonsterParty, is displayed on top of the dungeon screen and consumes keyboard input until dismissed.

#### Scenario: Overlay appears with monster names
- **WHEN** `EncounterOverlay.start_encounter(monster_party)` is called with a party of 2 slimes and 1 goblin
- **THEN** the overlay SHALL become visible and SHALL display the monster names (e.g., "スライム x2", "ゴブリン x1")

#### Scenario: Dungeon input is blocked while overlay is visible
- **WHEN** the EncounterOverlay is visible
- **THEN** keyboard events for movement SHALL NOT reach the DungeonScreen

#### Scenario: Overlay is hidden before start
- **WHEN** an EncounterOverlay is instantiated but `start_encounter` has not been called
- **THEN** the overlay SHALL NOT be visible

### Requirement: EncounterOverlay resolves via signal contract
The system SHALL ensure that `EncounterOverlay` emits `encounter_resolved(outcome: EncounterOutcome)` when the overlay is dismissed, enabling future replacement by a full combat UI without changing callers.

#### Scenario: Confirm input dismisses the overlay
- **WHEN** the overlay is visible and the user presses the confirm key (Enter/Space)
- **THEN** the overlay SHALL hide itself and SHALL emit `encounter_resolved` exactly once

#### Scenario: Stub overlay reports CLEARED outcome
- **WHEN** the stub EncounterOverlay is dismissed
- **THEN** the emitted EncounterOutcome SHALL have `result == CLEARED`

#### Scenario: Dungeon input resumes after resolution
- **WHEN** `encounter_resolved` has been emitted
- **THEN** subsequent keyboard events SHALL reach the DungeonScreen again

### Requirement: EncounterOutcome is an extension-friendly value
The system SHALL provide an `EncounterOutcome` (RefCounted) with at minimum a `result` enum value in `{ESCAPED, CLEARED, WIPED}`, designed to accept additional fields (e.g., experience, drops) in future changes without breaking the stub contract.

#### Scenario: Stub sets result to CLEARED
- **WHEN** the stub overlay constructs an EncounterOutcome
- **THEN** the outcome SHALL have `result == CLEARED`

#### Scenario: Future fields default to empty
- **WHEN** an EncounterOutcome is created without optional fields
- **THEN** any unset optional field SHALL default to an empty or zero value
