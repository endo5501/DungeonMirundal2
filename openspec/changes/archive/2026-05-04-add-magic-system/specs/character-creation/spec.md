## MODIFIED Requirements

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

## ADDED Requirements

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
