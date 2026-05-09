## MODIFIED Requirements

### Requirement: PartyMemberData holds character display information
PartyMemberData (RefCounted) SHALL hold the display data for a single party member: name (String), level (int), current_hp (int), max_hp (int), current_mp (int), max_mp (int), and job_id (StringName). `job_id` SHALL identify the member's job when known and SHALL be empty when the display data has no job context.

#### Scenario: Create party member with all fields
- **WHEN** PartyMemberData is created with name "Warrior", level 5, current_hp 120, max_hp 150, current_mp 30, max_mp 45, and job_id `&"fighter"`
- **THEN** name SHALL be "Warrior", level SHALL be 5, current_hp SHALL be 120, max_hp SHALL be 150, current_mp SHALL be 30, max_mp SHALL be 45, and job_id SHALL be `&"fighter"`

#### Scenario: Create party member without job context
- **WHEN** PartyMemberData is created with name "Warrior", level 5, current_hp 120, max_hp 150, current_mp 30, and max_mp 45 without an explicit job_id
- **THEN** job_id SHALL be empty

## ADDED Requirements

### Requirement: PartyMemberPanel renders default job portraits
PartyMemberPanel SHALL render a default portrait image for a party member when that member's `PartyMemberData.job_id` matches a known job portrait asset. The default portrait set SHALL include one image for each existing job id: `fighter`, `mage`, `priest`, `thief`, `bishop`, `samurai`, `lord`, and `ninja`. The portrait image SHALL be drawn inside the existing portrait rectangle before the level and name badges are rendered.

#### Scenario: Known job id resolves a portrait
- **WHEN** a PartyMemberPanel is set with PartyMemberData whose job_id is `&"fighter"` and the fighter portrait asset exists
- **THEN** the panel SHALL resolve a portrait texture for `fighter`
- **AND** the portrait SHALL be drawn inside `get_portrait_rect()`

#### Scenario: Each defined job has a portrait mapping
- **WHEN** PartyMemberPanel is asked to resolve portraits for `fighter`, `mage`, `priest`, `thief`, `bishop`, `samurai`, `lord`, and `ninja`
- **THEN** each job id SHALL resolve to a non-empty project asset path under `res://assets/images/portraits/jobs/`

#### Scenario: Unknown job falls back to placeholder
- **WHEN** a PartyMemberPanel is set with PartyMemberData whose job_id is `&"unknown_job"`
- **THEN** the panel SHALL NOT resolve a job portrait texture
- **AND** the existing placeholder portrait SHALL remain the fallback rendering

#### Scenario: Missing job id falls back to placeholder
- **WHEN** a PartyMemberPanel is set with PartyMemberData whose job_id is empty
- **THEN** the panel SHALL NOT resolve a job portrait texture
- **AND** the existing placeholder portrait SHALL remain the fallback rendering

### Requirement: Character display data carries canonical job id
Character.to_party_member_data() SHALL populate `PartyMemberData.job_id` from the character's canonical `JobData.id` when a job is present. If the job has no id, the value SHALL use the same fallback identity that Character serialization uses for job ids. If neither id nor resource path is available, the display value SHALL fall back to the normalized `JobData.job_name` when present.

#### Scenario: Character display data includes job id
- **WHEN** Character.to_party_member_data() is called for a character whose JobData id is `&"mage"`
- **THEN** the returned PartyMemberData job_id SHALL be `&"mage"`

#### Scenario: Character display data tolerates missing job
- **WHEN** Character.to_party_member_data() is called for a character with no job
- **THEN** the returned PartyMemberData job_id SHALL be empty

#### Scenario: Character display data falls back to job name
- **WHEN** Character.to_party_member_data() is called for a character whose JobData has no id and no resource path but has job_name "Mage"
- **THEN** the returned PartyMemberData job_id SHALL be `&"mage"`
