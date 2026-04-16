## MODIFIED Requirements

### Requirement: main.gd manages top-level screen switching
main.gd SHALL manage a single current screen as a child node. Switching screens SHALL queue_free the current screen and add the new screen as a child. main.gd SHALL also manage the ESCメニューオーバーレイをCanvasLayerとして保持し、ESCキー入力で表示/非表示を切り替える。

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
- **THEN** main.gd SHALL remove DungeonEntrance and display DungeonScreen initialized with the selected DungeonData's wiz_map, player_state, and explored_map

#### Scenario: Switch from dungeon entrance back to town
- **WHEN** DungeonEntrance emits back_requested
- **THEN** main.gd SHALL remove DungeonEntrance and display TownScreen

#### Scenario: Switch from dungeon to town on return
- **WHEN** DungeonScreen emits return_to_town
- **THEN** main.gd SHALL call GameState.heal_party(), save the player's position to DungeonData, remove DungeonScreen, and display TownScreen

#### Scenario: ESCメニューからタイトルに戻る
- **WHEN** ESCメニューがquit_to_titleシグナルを発行する
- **THEN** main.gd SHALL ESCメニューを閉じ、現在の画面を破棄し、TitleScreenを表示する

#### Scenario: ESCキーでメニューを表示
- **WHEN** タイトル画面以外の画面でESCキーが_unhandled_inputに到達する
- **THEN** main.gd SHALL ESCメニューオーバーレイを表示する

#### Scenario: タイトル画面ではESCメニューを開かない
- **WHEN** タイトル画面が表示されている状態でESCキーが押される
- **THEN** main.gd SHALL ESCメニューを開かない

### Requirement: Quit game from title screen
main.gd SHALL exit the application when TitleScreen indicates quit.

#### Scenario: Quit from title
- **WHEN** TitleScreen triggers game quit
- **THEN** the application SHALL call get_tree().quit()
