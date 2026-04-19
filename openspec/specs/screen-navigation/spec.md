## Purpose
main.gd を中心とする画面切替の共通仕組みを規定する。Screen の add/remove、前画面ポインタの扱い、ESC キーによる戻る操作の一元化を対象とする。

## Requirements

### Requirement: main.gd manages top-level screen switching
main.gd SHALL manage a single current screen as a child node. Switching screens SHALL queue_free the current screen and add the new screen as a child. main.gd SHALL handle game state loading and restore the appropriate screen based on game_location.

#### Scenario: Initial screen is TitleScreen
- **WHEN** the game starts
- **THEN** TitleScreen SHALL be displayed as the first screen

#### Scenario: Switch from title to town
- **WHEN** TitleScreen emits start_new_game
- **THEN** main.gd SHALL call GameState.new_game(), remove TitleScreen, and display TownScreen

#### Scenario: Switch from town to guild
- **WHEN** TownScreen emits open_guild
- **THEN** main.gd SHALL remove TownScreen and display GuildScreen initialized with GameState.guild

#### Scenario: Switch from guild to town
- **WHEN** GuildScreen emits back_requested
- **THEN** main.gd SHALL remove GuildScreen and display TownScreen

#### Scenario: Switch from town to dungeon entrance
- **WHEN** TownScreen emits open_dungeon_entrance
- **THEN** main.gd SHALL remove TownScreen and display DungeonEntrance initialized with GameState.dungeon_registry

#### Scenario: Switch from dungeon entrance to dungeon
- **WHEN** DungeonEntrance emits enter_dungeon with a dungeon index
- **THEN** main.gd SHALL set GameState.current_dungeon_index, set GameState.game_location to "dungeon", remove DungeonEntrance and display DungeonScreen initialized with the selected DungeonData's wiz_map, player_state, and explored_map

#### Scenario: Switch from dungeon entrance back to town
- **WHEN** DungeonEntrance emits back_requested
- **THEN** main.gd SHALL remove DungeonEntrance and display TownScreen

#### Scenario: Switch from dungeon to town on return
- **WHEN** DungeonScreen emits return_to_town
- **THEN** main.gd SHALL call GameState.heal_party(), set GameState.game_location to "town", set GameState.current_dungeon_index to -1, save the player's position to DungeonData, remove DungeonScreen, and display TownScreen

#### Scenario: ESCメニューからタイトルに戻る
- **WHEN** ESCメニューがquit_to_titleシグナルを発行する
- **THEN** main.gd SHALL ESCメニューを閉じ、現在の画面を破棄し、TitleScreenを表示する

#### Scenario: ESCキーでメニューを表示
- **WHEN** タイトル画面以外の画面でESCキーが_unhandled_inputに到達する
- **THEN** main.gd SHALL ESCメニューオーバーレイを表示する

#### Scenario: タイトル画面ではESCメニューを開かない
- **WHEN** タイトル画面が表示されている状態でESCキーが押される
- **THEN** main.gd SHALL ESCメニューを開かない

#### Scenario: Switch from title to town via continue
- **WHEN** TitleScreen emits continue_game
- **THEN** main.gd SHALL load the last save slot via SaveManager, and display the appropriate screen based on GameState.game_location

#### Scenario: Load game restores town screen
- **WHEN** a save file with game_location="town" is loaded
- **THEN** main.gd SHALL display TownScreen

#### Scenario: Load game restores dungeon screen
- **WHEN** a save file with game_location="dungeon" is loaded
- **THEN** main.gd SHALL retrieve DungeonData from GameState.dungeon_registry using current_dungeon_index, regenerate WizMap from seed, and display DungeonScreen initialized with the restored data

#### Scenario: Load game from title screen via load screen
- **WHEN** a save slot is selected in the load screen opened from TitleScreen
- **THEN** main.gd SHALL load the selected save slot and display the appropriate screen based on GameState.game_location

#### Scenario: Load game from ESC menu via load screen
- **WHEN** a save slot is selected in the load screen opened from ESCメニュー
- **THEN** main.gd SHALL close ESCメニュー, load the selected save slot, and display the appropriate screen based on GameState.game_location

### Requirement: Quit game from title screen
main.gd SHALL exit the application when TitleScreen indicates quit.

#### Scenario: Quit from title
- **WHEN** TitleScreen triggers game quit
- **THEN** the application SHALL call get_tree().quit()

### Requirement: main.gd updates game_location on screen transitions
main.gd SHALL update GameState.game_location whenever screen transitions occur to keep the location state current.

#### Scenario: 町画面に遷移時
- **WHEN** main.gdが町画面を表示する
- **THEN** GameState.game_location が "town" に設定される

#### Scenario: ダンジョン画面に遷移時
- **WHEN** main.gdがダンジョン画面を表示する
- **THEN** GameState.game_location が "dungeon" に設定される

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
