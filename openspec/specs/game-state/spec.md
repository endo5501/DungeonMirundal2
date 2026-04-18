### Requirement: GameState is an autoload singleton
GameState SHALL be registered as an autoload in project.godot and SHALL be accessible from any script via the name `GameState`.

#### Scenario: GameState is globally accessible
- **WHEN** any script references `GameState`
- **THEN** it SHALL resolve to the singleton instance

### Requirement: GameState holds Guild instance
GameState SHALL hold a `guild` property of type Guild that persists across screen transitions.

#### Scenario: Guild persists across screens
- **WHEN** a character is created in GuildScreen and the player navigates to TownScreen and back
- **THEN** the character SHALL still exist in GameState.guild

### Requirement: GameState holds DungeonRegistry instance
GameState SHALL hold a `dungeon_registry` property of type DungeonRegistry that persists across screen transitions.

#### Scenario: DungeonRegistry persists across screens
- **WHEN** a dungeon is created in DungeonEntrance and the player navigates away and back
- **THEN** the dungeon SHALL still exist in GameState.dungeon_registry

### Requirement: GameState initializes new game
GameState SHALL provide a `new_game()` method that creates fresh Guild, DungeonRegistry, and Inventory instances, resets game_location to "town" and current_dungeon_index to -1, and sets the starting gold to 500.

#### Scenario: New game resets state
- **WHEN** `new_game()` is called
- **THEN** guild SHALL be a new empty Guild, dungeon_registry SHALL be a new empty DungeonRegistry, inventory SHALL be a new empty Inventory with `gold == 500`, game_location SHALL be "town", and current_dungeon_index SHALL be -1

#### Scenario: New game preserves item_repository
- **WHEN** `new_game()` is called
- **THEN** `GameState.item_repository` SHALL remain the repository loaded at startup (not reset)

### Requirement: GameState heals party on town return
GameState SHALL provide a `heal_party()` method that restores all party members' HP to max_hp and MP to max_mp.

#### Scenario: Heal party restores HP and MP
- **WHEN** a party member has current_hp=5, max_hp=20, current_mp=0, max_mp=10 and `heal_party()` is called
- **THEN** current_hp SHALL be 20 and current_mp SHALL be 10

#### Scenario: Heal party affects all party members
- **WHEN** the party has 3 members with reduced HP and `heal_party()` is called
- **THEN** all 3 members SHALL have current_hp equal to max_hp

### Requirement: GameState holds game_location
GameState SHALL hold a `game_location` property of type String that tracks the current game screen. Valid values are "title", "town", "dungeon".

#### Scenario: game_locationが画面遷移に応じて更新される
- **WHEN** main.gdが町画面に遷移する
- **THEN** GameState.game_location が "town" に設定される

#### Scenario: ダンジョン入場時にgame_locationが更新される
- **WHEN** main.gdがダンジョン画面に遷移する
- **THEN** GameState.game_location が "dungeon" に設定される

### Requirement: GameState holds current_dungeon_index
GameState SHALL hold a `current_dungeon_index` property of type int that tracks which dungeon the player is currently in. Value is -1 when not in a dungeon.

#### Scenario: ダンジョン入場時にインデックスが設定される
- **WHEN** ダンジョンインデックス2のダンジョンに入場する
- **THEN** GameState.current_dungeon_index が 2 に設定される

#### Scenario: 町に戻った時にインデックスがリセットされる
- **WHEN** ダンジョンから町に戻る
- **THEN** GameState.current_dungeon_index が -1 に設定される

### Requirement: GameState holds SaveManager
GameState SHALL hold a `save_manager` property of type SaveManager.

#### Scenario: SaveManagerにアクセスできる
- **WHEN** any script references `GameState.save_manager`
- **THEN** SaveManagerインスタンスにアクセスできる

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
