## MODIFIED Requirements

### Requirement: MonsterData carries a resists dictionary

The system SHALL extend `MonsterData` with `@export var resists: Dictionary = {}` mapping `StringName` resist keys to `float` values. Negative values are allowed.

Representative monster `.tres` files SHALL declare resists consistent with their thematic role (full list authored at implementation time; the following are mandatory examples):

| Monster | resists (minimum required keys) |
|---------|---------------------------------|
| slime | `{ &"poison": 1.0, &"sleep": 0.30 }` |
| skeleton | `{ &"poison": 1.0, &"sleep": 1.0, &"paralysis": 0.50 }` |
| ghost | `{ &"poison": 1.0, &"sleep": 1.0, &"blind": 1.0 }` |
| bat | `{ &"poison": 0.30, &"blind": 1.0 }` |
| dragon | `{ &"sleep": 0.50, &"paralysis": 0.30, &"confusion": 0.50 }` |

Other monsters MAY declare `resists = {}` if no thematic resistance applies.

#### Scenario: Slime is fully poison-immune
- **WHEN** `slime.tres` is loaded
- **THEN** `resists.get(&"poison")` SHALL be `1.0`

#### Scenario: Skeleton is immune to poison and sleep
- **WHEN** `skeleton.tres` is loaded
- **THEN** `resists.get(&"poison")` SHALL be `1.0` AND `resists.get(&"sleep")` SHALL be `1.0`

#### Scenario: Ghost is immune to physical-flavored statuses
- **WHEN** `ghost.tres` is loaded
- **THEN** `resists.get(&"poison")` AND `resists.get(&"sleep")` AND `resists.get(&"blind")` SHALL all equal `1.0`

#### Scenario: Bat resists blind fully and poison partially
- **WHEN** `bat.tres` is loaded
- **THEN** `resists.get(&"blind")` SHALL be `1.0` AND `resists.get(&"poison")` SHALL be approximately `0.30`

#### Scenario: Dragon resists multiple mind-affecting statuses
- **WHEN** `dragon.tres` is loaded
- **THEN** `resists` SHALL contain at least `&"sleep"`, `&"paralysis"`, `&"confusion"` with positive values
