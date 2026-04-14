## 1. Model層: ダンジョン管理

- [x] 1.1 DungeonNameGenerator を実装する（形容詞+名詞のランダム名生成）
- [x] 1.2 DungeonData を実装する（dungeon_name, seed, map_size, wiz_map, explored_map, player_state, get_exploration_rate）
- [x] 1.3 DungeonRegistry を実装する（create, remove, get, get_all, size、サイズカテゴリ対応）

## 2. GameState autoload

- [ ] 2.1 GameState を実装する（guild, dungeon_registry, new_game, heal_party）
- [ ] 2.2 project.godot に GameState を autoload として登録する

## 3. タイトル画面

- [ ] 3.1 TitleScreen を実装する（4項目メニュー、カーソル選択、disabled項目のグレーアウト、start_new_game シグナル）

## 4. 地上画面

- [ ] 4.1 TownScreen を実装する（左カラム施設ボタン、右カラムイラストプレースホルダ、disabled項目スキップ、open_guild / open_dungeon_entrance シグナル）

## 5. ダンジョン入口

- [ ] 5.1 DungeonEntrance を実装する（ダンジョン一覧表示、カーソル選択、潜入/新規生成/破棄/戻るボタン、パーティ未編成時の潜入disabled）
- [ ] 5.2 DungeonCreateDialog を実装する（サイズカテゴリ選択、ランダム名+編集、生成確認/キャンセル）

## 6. ダンジョン帰還

- [ ] 6.1 DungeonScreen に STARTタイル検出ロジックを追加する（移動後にタイル判定）
- [ ] 6.2 帰還確認ダイアログを実装する（はい/いいえ選択、ダイアログ中の入力ブロック、return_to_town シグナル）

## 7. 画面遷移統合

- [ ] 7.1 main.gd を画面管理者に改修する（_switch_screen、TitleScreen初期表示）
- [ ] 7.2 TitleScreen → TownScreen 遷移を接続する（new_game呼び出し含む）
- [ ] 7.3 TownScreen → GuildScreen / DungeonEntrance 遷移を接続する
- [ ] 7.4 GuildScreen → TownScreen 帰還遷移を接続する（back_requested）
- [ ] 7.5 DungeonEntrance → DungeonScreen 遷移を接続する（enter_dungeon）
- [ ] 7.6 DungeonScreen → TownScreen 帰還遷移を接続する（return_to_town + heal_party）
- [ ] 7.7 全画面フローの結合テスト（タイトル→地上→ギルド→地上→ダンジョン入口→ダンジョン→帰還→地上）
