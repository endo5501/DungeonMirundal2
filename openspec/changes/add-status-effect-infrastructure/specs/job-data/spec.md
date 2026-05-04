## ADDED Requirements

### Requirement: JobData carries a resists dictionary

The system SHALL extend `JobData` with `@export var resists: Dictionary = {}` mapping `StringName` resist keys to `float` values in the range `[0.0, 1.0]`. Missing keys SHALL be treated as `0.0` resistance. All eight existing `.tres` job files (fighter, mage, priest, thief, bishop, samurai, lord, ninja) SHALL be updated to include `resists = {}` in this change.

#### Scenario: JobData exposes resists
- **WHEN** a JobData resource is instantiated
- **THEN** the `resists` field SHALL be a Dictionary that is at least readable

#### Scenario: All job tres files have a resists field
- **WHEN** any of the eight job `.tres` files is loaded
- **THEN** `resists` SHALL be a Dictionary (empty in this change)
