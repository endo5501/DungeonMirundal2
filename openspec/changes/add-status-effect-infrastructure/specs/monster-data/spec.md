## ADDED Requirements

### Requirement: MonsterData carries a resists dictionary

The system SHALL extend `MonsterData` with `@export var resists: Dictionary = {}` mapping `StringName` resist keys to `float` values in the range `[0.0, 1.0]`. Missing keys SHALL be treated as `0.0` resistance. All existing `.tres` monster files SHALL be updated to include `resists = {}` in this change.

#### Scenario: MonsterData exposes resists
- **WHEN** a MonsterData resource is instantiated
- **THEN** the `resists` field SHALL be a Dictionary that is at least readable

#### Scenario: All monster tres files have a resists field
- **WHEN** any monster `.tres` file is loaded
- **THEN** `resists` SHALL be a Dictionary (empty in this change)
