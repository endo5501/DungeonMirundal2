## Purpose
キャラクター作成の基本フローと能力値割り当てルールを定義する。種族・職業の選択、ボーナスポイントの分配、最終確定までの一連の振る舞いを規定する。
## Requirements
### Requirement: Bonus point generation follows Wizardry distribution
BonusPointGenerator SHALL generate bonus points using a recursive method: a base roll of 5-9 (uniform), then a 10% chance to add 1-3 and re-roll for more bonus (recursively).

#### Scenario: Bonus points are at least 5
- **WHEN** bonus points are generated
- **THEN** the result SHALL be >= 5

#### Scenario: Bonus points have expected average
- **WHEN** bonus points are generated 10000 times
- **THEN** the average SHALL be approximately 7-8 (within statistical tolerance)

#### Scenario: High bonus points are rare
- **WHEN** bonus points are generated 10000 times
- **THEN** less than 5% of results SHALL be >= 15

#### Scenario: Deterministic generation with seed
- **WHEN** BonusPointGenerator is created with a fixed seed and generate() is called
- **THEN** the result SHALL be the same every time for that seed

### Requirement: Character creation combines race stats and bonus points
A Character SHALL be created with base stats equal to the race's base stats plus allocated bonus points.

#### Scenario: Character with no bonus allocated
- **WHEN** a Character is created with Human race (all base 8) and 7 bonus points all allocated to STR
- **THEN** STR SHALL be 15, and INT, PIE, VIT, AGI, LUC SHALL each be 8

#### Scenario: Bonus points distributed across stats
- **WHEN** a Character is created with Elf race and bonus points allocated as STR+2, VIT+3, LUC+2
- **THEN** STR SHALL be 9 (7+2), VIT SHALL be 9 (6+3), LUC SHALL be 8 (6+2), and other stats SHALL equal Elf base values

#### Scenario: Total allocated points must equal bonus points
- **WHEN** a Character creation is attempted with allocated points not summing to the bonus total
- **THEN** the creation SHALL fail or be rejected

### Requirement: Character initial HP is derived from job and VIT
Character initial HP SHALL be calculated as the job's base_hp plus a VIT-based bonus.

#### Scenario: Fighter with VIT 8
- **WHEN** a Character is created as Fighter (base_hp=10) with VIT=8
- **THEN** max_hp SHALL be 10 + (8 / 3) = 12, and current_hp SHALL equal max_hp

#### Scenario: Fighter with VIT 15
- **WHEN** a Character is created as Fighter (base_hp=10) with VIT=15
- **THEN** max_hp SHALL be 10 + (15 / 3) = 15, and current_hp SHALL equal max_hp

### Requirement: Character initial MP depends on job magic capability
Only magic-capable jobs SHALL have MP. A job is magic-capable when at least one of `mage_school` or `priest_school` is `true`. Non-magic jobs SHALL have 0 MP.

#### Scenario: Mage has initial MP
- **WHEN** a Character is created as Mage (mage_school=true, base_mp=5)
- **THEN** max_mp SHALL be base_mp (5) and current_mp SHALL equal max_mp

#### Scenario: Priest has initial MP
- **WHEN** a Character is created as Priest (priest_school=true, base_mp=5)
- **THEN** max_mp SHALL be base_mp (5) and current_mp SHALL equal max_mp

#### Scenario: Bishop has initial MP
- **WHEN** a Character is created as Bishop (mage_school=true, priest_school=true, base_mp=4)
- **THEN** max_mp SHALL be base_mp (4) and current_mp SHALL equal max_mp

#### Scenario: Fighter has no MP
- **WHEN** a Character is created as Fighter (mage_school=false, priest_school=false)
- **THEN** max_mp SHALL be 0 and current_mp SHALL be 0

#### Scenario: Thief has no MP
- **WHEN** a Character is created as Thief (mage_school=false, priest_school=false)
- **THEN** max_mp SHALL be 0 and current_mp SHALL be 0

#### Scenario: Ninja has no MP
- **WHEN** a Character is created as Ninja (mage_school=false, priest_school=false)
- **THEN** max_mp SHALL be 0 and current_mp SHALL be 0

### Requirement: Character level starts at 1
A newly created Character SHALL have level 1.

#### Scenario: New character level
- **WHEN** a Character is created
- **THEN** level SHALL be 1

### Requirement: Character can produce PartyMemberData
Character SHALL provide a method to_party_member_data() that creates a PartyMemberData instance with the character's current display values.

#### Scenario: Convert character to party member data
- **WHEN** to_party_member_data() is called on a Character named "Alice" at level 1 with HP 12/12 and MP 5/5
- **THEN** the returned PartyMemberData SHALL have member_name="Alice", level=1, current_hp=12, max_hp=12, current_mp=5, max_mp=5

### Requirement: Job qualification check at creation
Character creation SHALL verify that the final stats (race base + bonus allocation) meet the chosen job's requirements.

#### Scenario: Valid Mage creation
- **WHEN** a Character is created with stats resulting in INT=11 and job=Mage (required_int=11)
- **THEN** the creation SHALL succeed

#### Scenario: Invalid Mage creation
- **WHEN** a Character is created with stats resulting in INT=10 and job=Mage (required_int=11)
- **THEN** the creation SHALL fail or be rejected

### Requirement: Character creation grants initial equipment based on job
The system SHALL, at the moment a Character is created through the character-creation flow and added to the Guild, grant a job-specific set of starter items. Each starter item SHALL be:
- added to `GameState.inventory` as a new `ItemInstance` with `identified == true`
- equipped into the matching slot of `character.equipment` when `allowed_jobs` includes the character's job

The initial equipment mapping SHALL cover all eight jobs (Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja) so that no newly-created character starts with every slot empty.

#### Scenario: Fighter receives weapon and armor on creation
- **WHEN** a Fighter is created and added to the guild
- **THEN** `GameState.inventory` SHALL contain at least two new ItemInstances (weapon and armor), and the character's `equipment` SHALL have non-null WEAPON and ARMOR slots

#### Scenario: Mage receives weapon and armor on creation
- **WHEN** a Mage is created and added to the guild
- **THEN** `GameState.inventory` SHALL contain at least two new ItemInstances (weapon and armor appropriate for Mage), and the character's `equipment` SHALL have non-null WEAPON and ARMOR slots with items whose `allowed_jobs` includes `Mage`

#### Scenario: Initial items go to shared inventory
- **WHEN** a character is created and receives starter items
- **THEN** those ItemInstances SHALL be present in `GameState.inventory.list()` (shared across the party), not in a per-character storage

#### Scenario: Every job has an initial equipment entry
- **WHEN** a character is created for any of the eight jobs (Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja)
- **THEN** the character creation flow SHALL NOT leave all equipment slots empty; at least one slot SHALL be equipped

### Requirement: new_game initializes party-shared gold to 500
The system SHALL, when `GameState.new_game()` is invoked, initialize the party-shared inventory with `gold == 500` and an empty item list.

#### Scenario: Initial gold is 500
- **WHEN** `GameState.new_game()` is called
- **THEN** `GameState.inventory.gold` SHALL equal `500`

#### Scenario: Initial inventory is empty of items
- **WHEN** `GameState.new_game()` is called (before any character is created)
- **THEN** `GameState.inventory.list().is_empty()` SHALL be `true`

### Requirement: Character creation grants initial spells from JobData.spell_progression

The system SHALL, at the moment a Character is created (level 1), populate `Character.known_spells` with the union of all `JobData.spell_progression[lv]` arrays whose key `lv` is `<= 1`. For typical magic jobs whose progression starts at level 1 (Mage, Priest), this grants the level-1 spells immediately. For magic jobs whose progression starts at level >= 2 (Bishop, Samurai, Lord), `known_spells` SHALL be empty at level 1; spells are granted when those characters reach the configured level via `Character.level_up`.

Non-magic jobs SHALL have `known_spells` empty.

#### Scenario: Mage at level 1 starts with mage spell-level-1 spells
- **WHEN** a Mage is created at level 1
- **THEN** `Character.known_spells` SHALL equal `[&"fire", &"frost"]` (order-insensitive, deduplicated)

#### Scenario: Priest at level 1 starts with priest spell-level-1 spells
- **WHEN** a Priest is created at level 1
- **THEN** `Character.known_spells` SHALL equal `[&"heal", &"holy"]` (order-insensitive)

#### Scenario: Bishop at level 1 starts with no spells
- **WHEN** a Bishop is created at level 1 (spell_progression starts at level 2)
- **THEN** `Character.known_spells` SHALL be empty

#### Scenario: Samurai at level 1 starts with no spells
- **WHEN** a Samurai is created at level 1 (spell_progression starts at level 4)
- **THEN** `Character.known_spells` SHALL be empty

#### Scenario: Lord at level 1 starts with no spells
- **WHEN** a Lord is created at level 1 (spell_progression starts at level 4)
- **THEN** `Character.known_spells` SHALL be empty

#### Scenario: Fighter has no known spells
- **WHEN** a Fighter is created at any level
- **THEN** `Character.known_spells` SHALL be empty

### Requirement: level_up grants spells whose progression key matches the new level

The system SHALL, every time `Character.level_up()` increments `level`, append every spell id in `JobData.spell_progression.get(level, [])` to `Character.known_spells` (deduplicating against existing entries). This SHALL apply consistently regardless of whether `level_up` is invoked once or multiple times in succession (e.g., during a `gain_experience` cascade).

#### Scenario: Mage at level 3 acquires spell-level-2 spells
- **WHEN** a Mage starts at level 1 with `known_spells = [&"fire", &"frost"]` and gains enough experience to reach level 3
- **THEN** after the level-up cascade, `known_spells` SHALL contain `[&"fire", &"frost", &"flame", &"blizzard"]` (set-equal)

#### Scenario: Bishop at level 2 acquires its first spells
- **WHEN** a Bishop starts at level 1 with empty `known_spells` and reaches level 2
- **THEN** `known_spells` SHALL equal `[&"fire", &"frost", &"heal", &"holy"]` (set-equal)

#### Scenario: Bishop at level 5 acquires the second batch
- **WHEN** a Bishop at level 4 with `known_spells = [&"fire", &"frost", &"heal", &"holy"]` reaches level 5
- **THEN** `known_spells` SHALL contain `[&"fire", &"frost", &"flame", &"blizzard", &"heal", &"holy", &"heala", &"allheal"]` (set-equal)

#### Scenario: Samurai at level 4 acquires mage spell-level-1 spells
- **WHEN** a Samurai reaches level 4 (with empty `known_spells` previously)
- **THEN** `known_spells` SHALL equal `[&"fire", &"frost"]`

#### Scenario: Lord at level 4 acquires priest spell-level-1 spells
- **WHEN** a Lord reaches level 4 (with empty `known_spells` previously)
- **THEN** `known_spells` SHALL equal `[&"heal", &"holy"]`

#### Scenario: Multi-level cascade grants every applicable batch
- **WHEN** a freshly created Mage gains a single huge experience reward that pushes level from 1 to 4
- **THEN** the resulting `known_spells` SHALL include both the level-1 grants (`fire`, `frost`) and the level-3 grants (`flame`, `blizzard`)

#### Scenario: level_up does not duplicate already-known spells
- **WHEN** a Character whose `known_spells` already contains `&"fire"` levels up into a key that grants `&"fire"` again
- **THEN** `known_spells` SHALL still contain exactly one occurrence of `&"fire"`

