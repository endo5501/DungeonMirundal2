## ADDED Requirements

### Requirement: RaceData holds base stats for a race
RaceData SHALL store the race name and base values for all six stats (STR, INT, PIE, VIT, AGI, LUC) as integer values.

#### Scenario: Create a Human race
- **WHEN** a RaceData is created with race_name="Human" and all base stats set to 8
- **THEN** race_name SHALL be "Human" and each of base_str, base_int, base_pie, base_vit, base_agi, base_luc SHALL be 8

#### Scenario: Create an Elf race with asymmetric stats
- **WHEN** a RaceData is created with race_name="Elf", base_str=7, base_int=10, base_pie=10, base_vit=6, base_agi=9, base_luc=6
- **THEN** all stat values SHALL match the provided values

### Requirement: Five races are defined as .tres resources
The system SHALL provide .tres resource files for exactly five races: Human, Elf, Dwarf, Gnome, Hobbit.

#### Scenario: All race files exist
- **WHEN** the data/races/ directory is scanned
- **THEN** exactly five .tres files SHALL exist: human.tres, elf.tres, dwarf.tres, gnome.tres, hobbit.tres

#### Scenario: Human base stats
- **WHEN** human.tres is loaded
- **THEN** base stats SHALL be STR=8, INT=8, PIE=8, VIT=8, AGI=8, LUC=8

#### Scenario: Elf base stats
- **WHEN** elf.tres is loaded
- **THEN** base stats SHALL be STR=7, INT=10, PIE=10, VIT=6, AGI=9, LUC=6

#### Scenario: Dwarf base stats
- **WHEN** dwarf.tres is loaded
- **THEN** base stats SHALL be STR=10, INT=7, PIE=10, VIT=10, AGI=5, LUC=6

#### Scenario: Gnome base stats
- **WHEN** gnome.tres is loaded
- **THEN** base stats SHALL be STR=7, INT=7, PIE=10, VIT=8, AGI=10, LUC=7

#### Scenario: Hobbit base stats
- **WHEN** hobbit.tres is loaded
- **THEN** base stats SHALL be STR=5, INT=7, PIE=7, VIT=6, AGI=10, LUC=15

### Requirement: DataLoader loads all races
DataLoader SHALL provide a method to load all race resources from the data/races/ directory.

#### Scenario: Load all races
- **WHEN** DataLoader.load_all_races() is called
- **THEN** an array of 5 RaceData instances SHALL be returned

#### Scenario: Loaded races have correct names
- **WHEN** DataLoader.load_all_races() is called
- **THEN** the returned array SHALL contain races named Human, Elf, Dwarf, Gnome, Hobbit
