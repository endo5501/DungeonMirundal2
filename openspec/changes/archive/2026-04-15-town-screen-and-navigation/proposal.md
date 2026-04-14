# Change: 地上画面 + 画面遷移

## Why

現在のゲームはmain.gdがダンジョン画面を直接生成するだけで、タイトル画面・地上画面・画面遷移の仕組みが存在しない。ゲームとして成立させるためにはタイトル→地上→ダンジョンの画面フロー、施設への導線、複数ダンジョンの管理が必要である。

## What Changes

- タイトル画面の新設（新規ゲーム / 前回から / ロード / ゲーム終了）
- 地上画面の新設（施設選択ボタン + イラストエリアプレースホルダ）
- ダンジョン入口画面の新設（ダンジョン一覧・選択・新規生成・破棄）
- ダンジョン新規生成（サイズカテゴリ選択 + ランダム名生成 + 名前編集）
- GameState autoloadシングルトン（Guild, DungeonRegistryを画面間で共有）
- main.gdをトップレベル画面管理者に拡張（signal + _switch_screen方式）
- ダンジョン帰還機能（STARTタイルで確認ダイアログ→地上帰還+HP全回復）
- GuildScreenの地上画面への接続（「立ち去る」→TownScreenに戻る）

## Capabilities

### New Capabilities
- `game-state`: ゲーム全体の状態管理シングルトン（Guild, DungeonRegistry保持、new_game/heal_party）
- `dungeon-management`: 複数ダンジョンのデータ管理（DungeonData, DungeonRegistry, DungeonNameGenerator）
- `title-screen`: タイトル画面（新規ゲーム / 前回から / ロード / ゲーム終了）
- `town-screen`: 地上画面（施設選択メニュー + イラストエリア）
- `dungeon-entrance`: ダンジョン入口画面（一覧・選択・新規生成・破棄）
- `screen-navigation`: 画面遷移管理（main.gdによるトップレベル画面切り替え）
- `dungeon-return`: ダンジョンからの帰還（STARTタイル検出 + 確認ダイアログ + HP全回復）

### Modified Capabilities
（なし）

## Impact

- `src/main.gd`: 直接DungeonScreen生成からトップレベル画面管理者に全面改修
- `src/dungeon_scene/dungeon_screen.gd`: STARTタイル検出と帰還ダイアログの追加
- `project.godot`: GameState autoload登録
- 新規ファイル: GameState, DungeonData, DungeonRegistry, DungeonNameGenerator, TitleScreen, TownScreen, DungeonEntrance, DungeonCreateDialog
