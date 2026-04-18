## ADDED Requirements

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
