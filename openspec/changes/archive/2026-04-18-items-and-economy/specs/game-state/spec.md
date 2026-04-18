## MODIFIED Requirements

### Requirement: GameState initializes new game
GameState SHALL provide a `new_game()` method that creates fresh Guild, DungeonRegistry, and Inventory instances, resets game_location to "town" and current_dungeon_index to -1, and sets the starting gold to 500.

#### Scenario: New game resets state
- **WHEN** `new_game()` is called
- **THEN** guild SHALL be a new empty Guild, dungeon_registry SHALL be a new empty DungeonRegistry, inventory SHALL be a new empty Inventory with `gold == 500`, game_location SHALL be "town", and current_dungeon_index SHALL be -1

#### Scenario: New game preserves item_repository
- **WHEN** `new_game()` is called
- **THEN** `GameState.item_repository` SHALL remain the repository loaded at startup (not reset)

## ADDED Requirements

### Requirement: GameState holds Inventory instance
GameState SHALL hold an `inventory` property of type Inventory that persists across screen transitions and represents the party-shared bag and gold pool.

#### Scenario: Inventory persists across screens
- **WHEN** gold is added to `GameState.inventory` in TownScreen and the player navigates to DungeonScreen and back
- **THEN** the gold SHALL still be present in `GameState.inventory`

#### Scenario: Inventory is accessible globally
- **WHEN** any script references `GameState.inventory`
- **THEN** it SHALL resolve to the single shared Inventory instance

### Requirement: GameState holds ItemRepository instance
GameState SHALL hold an `item_repository` property of type ItemRepository, populated at application startup via `DataLoader.load_all_items()`.

#### Scenario: item_repository is populated at startup
- **WHEN** the game finishes starting up (main scene ready)
- **THEN** `GameState.item_repository` SHALL contain every Item defined under `data/items/`

#### Scenario: item_repository is accessible from any script
- **WHEN** any script references `GameState.item_repository`
- **THEN** it SHALL resolve to the same ItemRepository instance

### Requirement: GameState heal_party does not restore dead characters
The system SHALL, when `heal_party()` is called, restore HP and MP only for characters whose `current_hp > 0`. Characters with `current_hp <= 0` SHALL remain at `current_hp == 0` (still dead) and SHALL NOT have their HP or MP restored; resurrection is the responsibility of the temple.

#### Scenario: Living members are fully healed
- **WHEN** a living member with `current_hp = 5, max_hp = 20, current_mp = 0, max_mp = 10` is present and `heal_party()` is called
- **THEN** `current_hp` SHALL be `20` and `current_mp` SHALL be `10`

#### Scenario: Dead members stay dead after heal_party
- **WHEN** a dead member with `current_hp == 0` is present and `heal_party()` is called
- **THEN** the member's `current_hp` SHALL remain `0` (no HP/MP restore)
