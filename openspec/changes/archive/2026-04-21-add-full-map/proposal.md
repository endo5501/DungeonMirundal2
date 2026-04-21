## Why

ダンジョン画面には右上に常時表示される 7x7 セル範囲のミニマップしかなく、フロア全体を俯瞰する手段が存在しない。Wizardry風の自動マッピング体験では「歩いた範囲を後から見返す」操作が前提であり、現状ではプレイヤーが探索状況を把握しづらい。本変更でフロア全体マップを開閉できるオーバーレイを追加し、探索済み範囲の把握とランドマーク (START / GOAL / 扉) の確認を可能にする。

## What Changes

- ダンジョン画面に **m キー** で開閉する全画面オーバーレイ「全体マップ」を追加する
- 全体マップは探索済みセルのみを描画し、プレイヤー位置・向き・START マーカー・GOAL マーカー・扉エッジを示す
- 全体マップのHUDにダンジョン名・プレイヤー座標・探索率を表示する
- 全体マップ表示中はミニマップを非表示にし、移動入力をロックする
- エンカウンター中・帰還ダイアログ表示中は m キーを無視する
- 全体マップ表示中に ESC を押すと閉じる (ESCメニューは開かない)
- DungeonScreen の入力ハンドリングに m キー処理と表示中フラグによる入力ロックを追加する

## Capabilities

### New Capabilities
- `full-map-renderer`: ダンジョンのフロア全体を一枚の Image として描画するレンダラ。探索済みセルのみ可視、プレイヤー / START / GOAL / 扉を視覚化、出力サイズは呼び出し側指定で自動フィット。
- `full-map-overlay`: ダンジョン画面に被せる全画面オーバーレイ Control。m キーでトグル、ESC で閉じる。HUD (ダンジョン名・座標・探索率) とレンダラ出力を表示する。表示中はミニマップを隠し、入力を遮断する。

### Modified Capabilities
- `dungeon-3d-rendering`: DungeonScreen の入力ハンドリング規則に「m キーで全体マップを開閉」「全体マップ表示中は移動入力を無視」「全体マップ表示中の ESC は全体マップを閉じる側で消費される」を追記する。

## Impact

- **新規コード**:
  - `src/dungeon/full_map_renderer.gd` (RefCounted)
  - `src/dungeon_scene/full_map_overlay.gd` (Control)
- **変更コード**:
  - `src/dungeon_scene/dungeon_screen.gd` (m キー入力ハンドリング、全体マップ表示中の入力ロック、ミニマップ可視性連動)
- **新規テスト**:
  - `tests/dungeon/test_full_map_renderer.gd`
  - `tests/dungeon/test_full_map_overlay.gd`
- **依存関係**: 既存の `WizMap` / `ExploredMap` / `PlayerState` / `TileType` / `EdgeType` / `Direction` / `DungeonData.dungeon_name` / `DungeonData.get_exploration_rate()` を読み取りで利用するのみ。これらの API は変更しない。
- **互換性**: 既存挙動はそのまま (m キーは現状未バインド、新規追加のみ)。セーブデータ形式への影響なし。
