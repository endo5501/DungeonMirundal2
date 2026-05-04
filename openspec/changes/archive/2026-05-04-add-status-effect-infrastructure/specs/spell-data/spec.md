## ADDED Requirements

### Requirement: StatusInflictSpellEffect schema

The system SHALL provide a `StatusInflictSpellEffect` Resource (extends `SpellEffect`) with the following exported fields:

- `status_id: StringName`
- `chance: float` — base inflict chance, 0.0 to 1.0
- `duration: int` — turns to apply for BATTLE_ONLY statuses; ignored for PERSISTENT (always sentinel)

#### Scenario: StatusInflictSpellEffect carries required fields
- **WHEN** a StatusInflictSpellEffect resource is created with `status_id`, `chance`, `duration`
- **THEN** every field SHALL be readable and typed consistently with its declaration

### Requirement: DamageWithStatusSpellEffect schema

The system SHALL provide a `DamageWithStatusSpellEffect` Resource (extends `SpellEffect`) with the following exported fields:

- `base_damage: int`
- `spread: int`
- `status_id: StringName`
- `inflict_chance: float`
- `status_duration: int`

#### Scenario: DamageWithStatusSpellEffect carries required fields
- **WHEN** a DamageWithStatusSpellEffect resource is created with all fields
- **THEN** every field SHALL be readable and typed consistently with its declaration

### Requirement: StatModSpellEffect schema

The system SHALL provide a `StatModSpellEffect` Resource (extends `SpellEffect`) with the following exported fields:

- `stat: StringName` — one of `&"attack"`, `&"defense"`, `&"agility"`, `&"hit"`, `&"evasion"`
- `delta: Variant` — `int` for attack/defense/agility, `float` for hit/evasion
- `turns: int`

#### Scenario: StatModSpellEffect carries required fields
- **WHEN** a StatModSpellEffect resource is created with `stat`, `delta`, `turns`
- **THEN** every field SHALL be readable

#### Scenario: stat key is a recognized value
- **WHEN** a StatModSpellEffect is loaded from a `.tres`
- **THEN** `stat` SHALL be one of `&"attack"`, `&"defense"`, `&"agility"`, `&"hit"`, `&"evasion"`

### Requirement: CureStatusSpellEffect schema

The system SHALL provide a `CureStatusSpellEffect` Resource (extends `SpellEffect`) with the following exported field:

- `status_id: StringName`

#### Scenario: CureStatusSpellEffect carries the status id
- **WHEN** a CureStatusSpellEffect resource is created with `status_id`
- **THEN** the field SHALL be readable
