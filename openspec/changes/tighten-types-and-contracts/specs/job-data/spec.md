## ADDED Requirements

### Requirement: JobData exposes an explicit id field
SHALL: `JobData` SHALL declare an `@export var id: StringName` field that uniquely identifies the job within the game. The value MUST equal the `.tres` file's basename (e.g., `fighter.tres` → `id == &"fighter"`). This `id` field SHALL be the canonical identifier used for save serialization.

#### Scenario: id field exists on JobData
- **WHEN** `JobData` is instantiated
- **THEN** the `id: StringName` property SHALL be available

#### Scenario: Each job .tres has its id set to its filename
- **WHEN** `fighter.tres` is loaded
- **THEN** the loaded JobData's `id` SHALL equal `&"fighter"`

#### Scenario: Character.to_dict uses JobData.id
- **WHEN** `Character.to_dict()` is called for a character with the fighter JobData
- **THEN** the returned Dictionary's `job_id` SHALL be `"fighter"` (derived from `id`)

#### Scenario: Migration tolerates empty id (transitional)
- **WHEN** a legacy `.tres` is loaded with `id == &""`
- **THEN** `Character.to_dict` SHALL fall back to deriving the id from `resource_path` and emit `push_warning`
