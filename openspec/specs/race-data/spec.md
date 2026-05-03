## Purpose
種族（RaceData）リソースの定義と能力値補正を規定する。人間・エルフ・ドワーフ・ホビット・ノームなど種族ごとの基本補正値・寿命・特性を対象とする。

## Requirements

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
