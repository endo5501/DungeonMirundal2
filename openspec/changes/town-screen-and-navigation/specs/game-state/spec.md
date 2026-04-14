## ADDED Requirements

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
GameState SHALL provide a `new_game()` method that creates fresh Guild and DungeonRegistry instances.

#### Scenario: New game resets state
- **WHEN** `new_game()` is called
- **THEN** guild SHALL be a new empty Guild and dungeon_registry SHALL be a new empty DungeonRegistry

### Requirement: GameState heals party on town return
GameState SHALL provide a `heal_party()` method that restores all party members' HP to max_hp and MP to max_mp.

#### Scenario: Heal party restores HP and MP
- **WHEN** a party member has current_hp=5, max_hp=20, current_mp=0, max_mp=10 and `heal_party()` is called
- **THEN** current_hp SHALL be 20 and current_mp SHALL be 10

#### Scenario: Heal party affects all party members
- **WHEN** the party has 3 members with reduced HP and `heal_party()` is called
- **THEN** all 3 members SHALL have current_hp equal to max_hp
