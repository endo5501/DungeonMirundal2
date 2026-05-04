## ADDED Requirements

### Requirement: RaceData carries a resists dictionary

The system SHALL extend `RaceData` with `@export var resists: Dictionary = {}` mapping `StringName` resist keys to `float` values in the range `[0.0, 1.0]`. Missing keys SHALL be treated as `0.0` resistance. All five existing `.tres` race files (human, elf, dwarf, gnome, hobbit) SHALL be updated to include `resists = {}` (no resistances configured by default in this change).

#### Scenario: RaceData exposes resists
- **WHEN** a RaceData resource is instantiated
- **THEN** the `resists` field SHALL be a Dictionary that is at least readable

#### Scenario: All race tres files have a resists field
- **WHEN** any of the five race `.tres` files is loaded
- **THEN** `resists` SHALL be a Dictionary (empty in this change)
