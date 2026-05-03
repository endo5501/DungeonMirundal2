## ADDED Requirements

### Requirement: RaceData exposes an explicit id field
SHALL: `RaceData` SHALL declare an `@export var id: StringName` field that uniquely identifies the race within the game. The value MUST equal the `.tres` file's basename (e.g., `human.tres` → `id == &"human"`). This `id` field SHALL be the canonical identifier used for save serialization, replacing the previous practice of deriving the id from `resource_path.get_file().get_basename()`.

#### Scenario: id field exists on RaceData
- **WHEN** `RaceData` is instantiated
- **THEN** the `id: StringName` property SHALL be available

#### Scenario: Each race .tres has its id set to its filename
- **WHEN** `human.tres` is loaded
- **THEN** the loaded RaceData's `id` SHALL equal `&"human"`

#### Scenario: Character.to_dict uses RaceData.id
- **WHEN** `Character.to_dict()` is called for a character with the human RaceData
- **THEN** the returned Dictionary's `race_id` SHALL be `"human"` (derived from `id`, not `resource_path`)

#### Scenario: Migration tolerates empty id (transitional)
- **WHEN** a legacy `.tres` is loaded with `id == &""` (not yet migrated)
- **THEN** `Character.to_dict` SHALL fall back to deriving the id from `resource_path` and emit `push_warning("RaceData.id is empty for <path>")`
