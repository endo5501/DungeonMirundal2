## ADDED Requirements

### Requirement: JobData holds job configuration
JobData SHALL store the job name, base HP, magic capability (has_magic), base MP, and stat requirements for all six stats.

#### Scenario: Create Fighter job with no requirements
- **WHEN** a JobData is created with job_name="Fighter", base_hp=10, has_magic=false, and all required stats set to 0
- **THEN** job_name SHALL be "Fighter", base_hp SHALL be 10, has_magic SHALL be false, and all required stat thresholds SHALL be 0

#### Scenario: Create Mage job with INT requirement
- **WHEN** a JobData is created with job_name="Mage", has_magic=true, base_mp=5, required_int=11
- **THEN** has_magic SHALL be true, base_mp SHALL be 5, required_int SHALL be 11

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
The system SHALL provide .tres resource files for exactly eight jobs: Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja.

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

#### Scenario: Magic jobs
- **WHEN** job data files are loaded
- **THEN** Mage, Priest, Bishop, Samurai, Lord, Ninja SHALL have has_magic=true and Fighter, Thief SHALL have has_magic=false

### Requirement: DataLoader loads all jobs
DataLoader SHALL provide a method to load all job resources from the data/jobs/ directory.

#### Scenario: Load all jobs
- **WHEN** DataLoader.load_all_jobs() is called
- **THEN** an array of 8 JobData instances SHALL be returned

#### Scenario: Loaded jobs have correct names
- **WHEN** DataLoader.load_all_jobs() is called
- **THEN** the returned array SHALL contain jobs named Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja
