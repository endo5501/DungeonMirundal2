## ADDED Requirements

### Requirement: Dungeon re-entry from town resets party position to START tile

`main.gd` SHALL reset the entering `DungeonData`'s `player_state` to the START tile of that dungeon whenever the transition from the dungeon entrance screen to the dungeon screen is taken (i.e. when `DungeonEntrance.enter_dungeon` is handled). The reset SHALL be performed by calling `DungeonData.reset_to_start()` on the retrieved dungeon BEFORE `DungeonScreen` is initialized from that dungeon's data, so that the first rendered frame shows the party at the entrance. This reset SHALL NOT be performed when the dungeon screen is restored via a save-file load, because the load path does not go through the entrance-to-dungeon transition.

#### Scenario: Re-entering after wipe starts at the entrance
- **WHEN** the party wipes in a dungeon, returns to town, and then re-enters the same dungeon via the entrance screen
- **THEN** before `DungeonScreen` is shown, the dungeon's `player_state` SHALL be reset to the START tile with facing `Direction.NORTH`, and the first rendered view SHALL be from the entrance

#### Scenario: Re-entering after escape scroll starts at the entrance
- **WHEN** the party uses an `escape_scroll` or `emergency_escape_scroll` in a dungeon to return to town, and then re-enters the same dungeon via the entrance screen
- **THEN** before `DungeonScreen` is shown, the dungeon's `player_state` SHALL be reset to the START tile

#### Scenario: Re-entering after voluntary return starts at the entrance
- **WHEN** the party reaches the START tile, confirms "はい" on the return dialog, and later re-enters the same dungeon via the entrance screen
- **THEN** before `DungeonScreen` is shown, `DungeonData.reset_to_start()` SHALL still be invoked (position is idempotently set to START even though it was already there)

#### Scenario: Loading a dungeon save does not reset position
- **WHEN** a save file with `game_location == "dungeon"` is loaded and the dungeon screen is restored via the load path (not via the entrance screen)
- **THEN** `DungeonData.reset_to_start()` SHALL NOT be called, and the party SHALL appear at the saved `player_state.position` and `player_state.facing`

#### Scenario: Exploration data is preserved across re-entry
- **WHEN** a dungeon has partially explored cells, the party returns to town, and then re-enters the same dungeon via the entrance screen
- **THEN** the `explored_map` SHALL remain unchanged (previously visited cells are still marked as visited after re-entry)
