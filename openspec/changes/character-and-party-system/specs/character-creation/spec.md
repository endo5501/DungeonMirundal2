## ADDED Requirements

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
Only magic-capable jobs SHALL have MP. Non-magic jobs SHALL have 0 MP.

#### Scenario: Mage has initial MP
- **WHEN** a Character is created as Mage (has_magic=true, base_mp=5)
- **THEN** max_mp SHALL be base_mp (5) and current_mp SHALL equal max_mp

#### Scenario: Fighter has no MP
- **WHEN** a Character is created as Fighter (has_magic=false)
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
