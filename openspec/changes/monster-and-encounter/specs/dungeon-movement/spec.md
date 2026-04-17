## ADDED Requirements

### Requirement: DungeonScreen notifies observers of successful position changes
DungeonScreen SHALL emit a signal or invoke an injected callback when the player successfully changes grid position (not merely rotation), enabling encounter detection to run per step without coupling DungeonScreen to the encounter subsystem.

#### Scenario: Forward move emits a step event
- **WHEN** the player presses Up and the forward move succeeds
- **THEN** DungeonScreen SHALL notify observers that a step has occurred, with the new position

#### Scenario: Blocked move does not emit a step event
- **WHEN** the player presses Up and the forward move is blocked by a wall
- **THEN** DungeonScreen SHALL NOT notify observers of a step

#### Scenario: Rotation does not emit a step event
- **WHEN** the player presses Left or Right and the facing changes
- **THEN** DungeonScreen SHALL NOT notify observers of a step

### Requirement: Encounter trigger takes priority over start-tile return prompt
When both the start-tile return prompt and an encounter would fire on the same step, the system SHALL present the encounter first; the return prompt SHALL only appear after the encounter is resolved if the player is still on the start tile.

#### Scenario: Step onto start tile with triggered encounter
- **WHEN** the player moves onto the start tile and the encounter roll also triggers
- **THEN** the encounter overlay SHALL be shown first and the return dialog SHALL NOT be shown until the encounter is resolved

#### Scenario: Step onto start tile without encounter
- **WHEN** the player moves onto the start tile and no encounter triggers
- **THEN** the return dialog SHALL appear as before

### Requirement: DungeonScreen suspends input while encounter overlay is active
DungeonScreen SHALL ignore movement, rotation, and return-dialog input while the EncounterOverlay is active, and SHALL resume input only after `encounter_resolved` is emitted.

#### Scenario: Movement keys are ignored during encounter
- **WHEN** the EncounterOverlay is visible and the user presses Up
- **THEN** the player position SHALL NOT change and no additional step event SHALL be emitted

#### Scenario: ESC is not intercepted to open the ESC menu during encounter
- **WHEN** the EncounterOverlay is visible and the user presses ESC
- **THEN** the ESC menu SHALL NOT open
