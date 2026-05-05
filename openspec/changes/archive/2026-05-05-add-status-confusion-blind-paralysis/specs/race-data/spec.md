## MODIFIED Requirements

### Requirement: RaceData carries a resists dictionary

The system SHALL extend `RaceData` with `@export var resists: Dictionary = {}` mapping `StringName` resist keys to `float` values. Negative values are allowed (representing increased vulnerability).

The five existing race `.tres` files SHALL declare resists as follows:

| Race | resists |
|------|---------|
| human | `{}` |
| elf | `{ &"silence": -0.10, &"poison": -0.10 }` |
| dwarf | `{ &"poison": 0.20, &"petrify": 0.10 }` |
| hobbit | `{ &"sleep": 0.10, &"paralysis": 0.10 }` |
| gnome | `{ &"silence": 0.10 }` |

#### Scenario: Human has no resists
- **WHEN** `human.tres` is loaded
- **THEN** `resists` SHALL be `{}`

#### Scenario: Elf is vulnerable to silence and poison
- **WHEN** `elf.tres` is loaded
- **THEN** `resists` SHALL contain `{&"silence": -0.10, &"poison": -0.10}`

#### Scenario: Dwarf resists poison and petrify
- **WHEN** `dwarf.tres` is loaded
- **THEN** `resists` SHALL contain `{&"poison": 0.20, &"petrify": 0.10}`

#### Scenario: Hobbit resists sleep and paralysis
- **WHEN** `hobbit.tres` is loaded
- **THEN** `resists` SHALL contain `{&"sleep": 0.10, &"paralysis": 0.10}`

#### Scenario: Gnome resists silence
- **WHEN** `gnome.tres` is loaded
- **THEN** `resists` SHALL contain `{&"silence": 0.10}`
