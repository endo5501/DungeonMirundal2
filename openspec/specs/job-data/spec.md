## Purpose
職業（JobData）リソースの定義と各種バランス数値を規定する。HP/MP 初期値・成長率・装備可能カテゴリ・使用可能魔法系統などの項目を対象とする。
## Requirements
### Requirement: JobData holds job configuration
JobData SHALL store the job name, base HP, magic school flags (`mage_school`, `priest_school`), base MP, and stat requirements for all six stats. The legacy `has_magic` boolean SHALL no longer exist on `JobData`; magic capability SHALL be expressed exclusively through `mage_school` and `priest_school`. A job is "magic-capable" if and only if at least one of `mage_school` or `priest_school` is `true`.

#### Scenario: Create Fighter job with no magic and no requirements
- **WHEN** a JobData is created with job_name="Fighter", base_hp=10, mage_school=false, priest_school=false, base_mp=0, and all required stats set to 0
- **THEN** job_name SHALL be "Fighter", base_hp SHALL be 10, both `mage_school` and `priest_school` SHALL be false, and all required stat thresholds SHALL be 0

#### Scenario: Create Mage job with mage school
- **WHEN** a JobData is created with job_name="Mage", mage_school=true, priest_school=false, base_mp=5, required_int=11
- **THEN** `mage_school` SHALL be true, `priest_school` SHALL be false, base_mp SHALL be 5, required_int SHALL be 11

#### Scenario: Create Bishop job with both schools
- **WHEN** a JobData is created with job_name="Bishop", mage_school=true, priest_school=true, base_mp=4, required_int=12, required_pie=12
- **THEN** both `mage_school` and `priest_school` SHALL be true

#### Scenario: has_magic field no longer exists
- **WHEN** a `JobData` instance is inspected
- **THEN** there SHALL NOT be a public `has_magic` property; calls to `obj.has_magic` SHALL be a parse-time error or return the default `Variant` for missing properties

### Requirement: JobData can check stat qualification
JobData SHALL provide a method `can_qualify(stats: Dictionary) -> bool` that returns true only when all stat values meet or exceed the corresponding required thresholds.

#### Scenario: Fighter qualifies with any stats
- **WHEN** can_qualify is called with all stats at 8
- **THEN** the result SHALL be true (Fighter has no requirements)

#### Scenario: Mage qualifies with sufficient INT
- **WHEN** can_qualify is called with INT=11 on a Mage (required_int=11)
- **THEN** the result SHALL be true

#### Scenario: Mage does not qualify with insufficient INT
- **WHEN** can_qualify is called with INT=10 on a Mage (required_int=11)
- **THEN** the result SHALL be false

#### Scenario: Lord requires all six stats to meet thresholds
- **WHEN** can_qualify is called with STR=15, INT=12, PIE=12, VIT=15, AGI=14, LUC=15 on a Lord
- **THEN** the result SHALL be true

#### Scenario: Lord fails if any single stat is below threshold
- **WHEN** can_qualify is called with STR=15, INT=12, PIE=12, VIT=14, AGI=14, LUC=15 on a Lord (required_vit=15)
- **THEN** the result SHALL be false

### Requirement: Eight jobs are defined as .tres resources
The system SHALL provide .tres resource files for exactly eight jobs: Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja. Each `.tres` SHALL declare values for `mage_school` and `priest_school` consistent with the job's role.

#### Scenario: All job files exist
- **WHEN** the data/jobs/ directory is scanned
- **THEN** exactly eight .tres files SHALL exist

#### Scenario: Fighter has no stat requirements
- **WHEN** fighter.tres is loaded
- **THEN** all required stat thresholds SHALL be 0

#### Scenario: Mage requires INT >= 11
- **WHEN** mage.tres is loaded
- **THEN** required_int SHALL be 11 and all other required stats SHALL be 0

#### Scenario: Priest requires PIE >= 11
- **WHEN** priest.tres is loaded
- **THEN** required_pie SHALL be 11 and all other required stats SHALL be 0

#### Scenario: Thief requires AGI >= 11
- **WHEN** thief.tres is loaded
- **THEN** required_agi SHALL be 11 and all other required stats SHALL be 0

#### Scenario: Bishop requires INT >= 12 and PIE >= 12
- **WHEN** bishop.tres is loaded
- **THEN** required_int SHALL be 12, required_pie SHALL be 12, and all other required stats SHALL be 0

#### Scenario: Samurai requires multiple stats
- **WHEN** samurai.tres is loaded
- **THEN** required_str SHALL be 15, required_int SHALL be 11, required_pie SHALL be 10, required_vit SHALL be 14, required_agi SHALL be 10, required_luc SHALL be 0

#### Scenario: Lord requires all stats at high thresholds
- **WHEN** lord.tres is loaded
- **THEN** required_str SHALL be 15, required_int SHALL be 12, required_pie SHALL be 12, required_vit SHALL be 15, required_agi SHALL be 14, required_luc SHALL be 15

#### Scenario: Ninja requires all stats at 15
- **WHEN** ninja.tres is loaded
- **THEN** all required stats SHALL be 15

#### Scenario: Magic schools per job
- **WHEN** job data files are loaded
- **THEN** `mage_school` SHALL be true for Mage, Bishop, Samurai (others false), and `priest_school` SHALL be true for Priest, Bishop, Lord (others false). Fighter, Thief, and Ninja SHALL have both flags false.

### Requirement: DataLoader loads all jobs
DataLoader SHALL provide a method to load all job resources from the data/jobs/ directory.

#### Scenario: Load all jobs
- **WHEN** DataLoader.load_all_jobs() is called
- **THEN** an array of 8 JobData instances SHALL be returned

#### Scenario: Loaded jobs have correct names
- **WHEN** DataLoader.load_all_jobs() is called
- **THEN** the returned array SHALL contain jobs named Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja

### Requirement: JobData declares per-level HP and MP growth

`JobData` SHALL declare per-level growth fields `hp_per_level: int` and `mp_per_level: int`, so that level-up can apply job-specific HP (and, for magic-capable jobs, MP) gains. `mp_per_level` SHALL only take effect for jobs whose `mage_school` or `priest_school` is `true`. For jobs with both flags false, `mp_per_level` SHALL be `0`.

#### Scenario: Fighter has nonzero hp_per_level and zero mp_per_level
- **WHEN** `fighter.tres` is loaded
- **THEN** `hp_per_level` SHALL be greater than `0` and `mp_per_level` SHALL be `0`

#### Scenario: Mage has nonzero hp_per_level and mp_per_level
- **WHEN** `mage.tres` is loaded
- **THEN** `hp_per_level` SHALL be greater than `0` and `mp_per_level` SHALL be greater than `0`

#### Scenario: Thief has zero mp_per_level
- **WHEN** `thief.tres` is loaded
- **THEN** `mp_per_level` SHALL be `0`

### Requirement: JobData declares an experience table for level-ups
`JobData` SHALL declare a monotonically-increasing `exp_table: PackedInt64Array` such that index `i` stores the cumulative experience required to reach level `i + 2` (i.e., to advance from level `i + 1` to level `i + 2`). The table SHALL cover at least levels up to `13` (12 thresholds: level 2 through level 13), allowing the system to extrapolate beyond if needed in a later change.

#### Scenario: exp_table exists and is non-empty
- **WHEN** any job `.tres` file is loaded
- **THEN** `exp_table.size()` SHALL be at least `12`

#### Scenario: exp_table is monotonically increasing
- **WHEN** `exp_table` is inspected for any job
- **THEN** for every index `i >= 1`, `exp_table[i] > exp_table[i - 1]` SHALL hold

#### Scenario: Jobs can have different experience tables
- **WHEN** the Fighter and Mage tables are compared
- **THEN** they MAY differ at any index (job-specific growth curves are allowed)

### Requirement: JobData exposes a helper to resolve the next-level threshold
`JobData` SHALL provide `exp_to_reach_level(target_level: int) -> int` that returns `exp_table[target_level - 2]` for `target_level >= 2`, and SHALL return `0` for `target_level <= 1`.

#### Scenario: Threshold for level 2 is the first table entry
- **WHEN** `exp_to_reach_level(2)` is called on any job
- **THEN** the returned value SHALL equal `exp_table[0]`

#### Scenario: Threshold for level 1 is zero
- **WHEN** `exp_to_reach_level(1)` or `exp_to_reach_level(0)` is called
- **THEN** the returned value SHALL be `0`

#### Scenario: Out-of-range lookup clamps to last entry
- **WHEN** `exp_to_reach_level(target_level)` is called with `target_level - 2 >= exp_table.size()`
- **THEN** the returned value SHALL equal the last element of `exp_table` (no interpolation in combat-system scope)

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

### Requirement: JobData declares spell_progression for magic-capable jobs

`JobData` SHALL declare a `spell_progression: Dictionary` field whose keys are job-level integers (`int`, indicating "the level at which these spells are first granted"), and whose values are `Array[StringName]` of spell ids learned at that level. For jobs with neither magic school flag set, `spell_progression` SHALL be empty (`{}`).

The progression after this change SHALL be:

| Job | spell_progression |
|---|---|
| fighter | {} |
| thief | {} |
| ninja | {} |
| mage | { 1: [&"fire", &"frost", &"dazil"], 2: [&"katino", &"manifo", &"morlis", &"dilto", &"sopic", &"madalto"], 3: [&"flame", &"blizzard", &"poison_dart", &"badi"] } |
| priest | { 1: [&"heal", &"holy", &"calfo"], 2: [&"dios", &"porfic", &"bamatu", &"varyu"], 3: [&"heala", &"allheal", &"madi", &"maporfic"], 5: [&"dialma"] } |
| bishop | { 2: [&"fire", &"frost", &"heal", &"holy", &"katino", &"manifo", &"dios", &"morlis", &"dilto", &"sopic", &"porfic", &"bamatu", &"varyu", &"dazil", &"madalto", &"calfo"], 5: [&"flame", &"blizzard", &"heala", &"allheal", &"poison_dart", &"madi", &"maporfic", &"badi"] } |
| samurai | { 4: [&"fire", &"frost"], 8: [&"flame", &"blizzard"] } |
| lord | { 4: [&"heal", &"holy"], 8: [&"heala", &"allheal"] } |

Spell ids in `spell_progression` SHALL match a real `SpellData.id` from `data/spells/`.

#### Scenario: Mage learns dazil at level 1 alongside fire and frost
- **WHEN** `mage.tres` is loaded
- **THEN** `spell_progression[1]` SHALL contain exactly `&"fire"`, `&"frost"`, `&"dazil"`

#### Scenario: Mage learns madalto at level 2
- **WHEN** `mage.tres` is loaded
- **THEN** `spell_progression[2]` SHALL contain `&"madalto"` (in addition to existing 5 ids)

#### Scenario: Mage learns badi at level 3
- **WHEN** `mage.tres` is loaded
- **THEN** `spell_progression[3]` SHALL contain `&"badi"` alongside existing 3 ids

#### Scenario: Priest learns calfo at level 1
- **WHEN** `priest.tres` is loaded
- **THEN** `spell_progression[1]` SHALL contain exactly `&"heal"`, `&"holy"`, `&"calfo"`

#### Scenario: Bishop's level-2 list includes the three new ids
- **WHEN** `bishop.tres` is loaded
- **THEN** `spell_progression[2]` SHALL contain `&"dazil"`, `&"madalto"`, `&"calfo"` in addition to its existing 13 ids (total 16)

#### Scenario: Bishop's level-5 list includes badi
- **WHEN** `bishop.tres` is loaded
- **THEN** `spell_progression[5]` SHALL contain `&"badi"` (total 8 ids)

#### Scenario: Non-magic jobs still have empty spell_progression
- **WHEN** `fighter.tres`, `thief.tres`, or `ninja.tres` is loaded
- **THEN** `spell_progression` SHALL be `{}`

#### Scenario: Samurai progression unchanged
- **WHEN** `samurai.tres` is loaded
- **THEN** `spell_progression[4]` SHALL contain exactly `&"fire"` and `&"frost"`

#### Scenario: spell_progression ids reference real SpellData
- **WHEN** any job .tres with non-empty `spell_progression` is loaded
- **THEN** every spell id appearing in the progression's value arrays SHALL also appear in the SpellRepository at startup

### Requirement: JobData carries a resists dictionary

The system SHALL extend `JobData` with `@export var resists: Dictionary = {}` mapping `StringName` resist keys to `float` values. Negative values are allowed.

The eight existing job `.tres` files SHALL declare resists as follows:

| Job | resists |
|-----|---------|
| fighter | `{ &"sleep": 0.10, &"confusion": 0.10 }` |
| mage | `{ &"silence": -0.20 }` |
| priest | `{ &"silence": -0.10 }` |
| thief | `{ &"paralysis": 0.10 }` |
| ninja | `{ &"paralysis": 0.20, &"sleep": 0.10 }` |
| bishop | `{}` |
| samurai | `{ &"confusion": 0.10 }` |
| lord | `{ &"silence": -0.05 }` |

#### Scenario: Fighter resists sleep and confusion
- **WHEN** `fighter.tres` is loaded
- **THEN** `resists` SHALL be `{&"sleep": 0.10, &"confusion": 0.10}`

#### Scenario: Mage is vulnerable to silence
- **WHEN** `mage.tres` is loaded
- **THEN** `resists.get(&"silence")` SHALL be `-0.20`

#### Scenario: Priest is moderately vulnerable to silence
- **WHEN** `priest.tres` is loaded
- **THEN** `resists.get(&"silence")` SHALL be `-0.10`

#### Scenario: Ninja resists paralysis and sleep
- **WHEN** `ninja.tres` is loaded
- **THEN** `resists` SHALL contain `{&"paralysis": 0.20, &"sleep": 0.10}`

