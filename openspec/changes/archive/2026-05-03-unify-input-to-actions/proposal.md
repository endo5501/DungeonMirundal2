## Why

ソースコード全体で 2 つの入力規約(action ベースと keycode 直接マッチ)が並存しており、どの画面がどちらを使うかは歴史的経緯に過ぎず、意図的なものではない(ユーザ確認済み)。9 ファイルが keycode ベース、10 ファイルが action ベース。これを放置すると、C5/C6/C7 の神クラス分解時に「どちらに合わせるべきか」を毎回判断する必要が生じる。リファクタの前に、すべての画面を action ベースに統一することで、`MenuController` (C4a) と `project.godot` の InputMap を単一ソースにする。

合わせて、現状 `project.godot` に明示的な `[input]` セクションがなく、Godot のデフォルト ui_* アクションのみに依存している。ダンジョン移動キー(W/A/S/D + 矢印)用のカスタムアクション(`move_forward` / `turn_left` / etc.)を追加することで、移動キーも action ベースに統一できる。

## What Changes

- `project.godot` に `[input]` セクションを追加し、以下のカスタムアクションを定義:
  - `move_forward`: KEY_W, KEY_UP
  - `move_back`: KEY_S, KEY_DOWN
  - `strafe_left`: KEY_A
  - `strafe_right`: KEY_D
  - `turn_left`: KEY_LEFT
  - `turn_right`: KEY_RIGHT
  - `toggle_full_map`: KEY_M
- 9 つの keycode ベース `_unhandled_input` を action ベースに移行:
  - `src/dungeon_scene/dungeon_screen.gd`: 移動キーを `move_forward` 等に
  - `src/dungeon_scene/full_map_overlay.gd`: ESC を `ui_cancel` に
  - `src/dungeon_scene/encounter_overlay.gd`: 確認キーを `ui_accept` に
  - `src/dungeon_scene/combat_overlay.gd`: メニュー入力を `ui_*` に
  - `src/esc_menu/esc_menu.gd`: メニュー入力を `ui_*` に(`MenuController` への移行は C6 で実施、本 change は keycode → action のみ)
  - `src/save_screen.gd` / `src/load_screen.gd`: メニュー入力を `ui_*` に
  - `src/main.gd`: トップレベル ESC を `ui_cancel` に(挙動は変えない)
  - `src/guild_scene/character_list.gd`: action と keycode が混在しているので action に揃える
- 新しい `MenuController` (C4a で導入済み)を、本 change で扱う画面のうちパターンに合致する箇所(esc_menu のサブメニュー以外、save_screen, load_screen)で先行採用
- `src/dungeon_scene/dungeon_screen.gd` の M キー処理を `toggle_full_map` action にする
- 各画面のテストを action ベースのイベント送信(`TestHelpers.make_action_event`)に書き換える

## Capabilities

### Modified Capabilities

- `project-setup`: `[input]` セクションのカスタムアクション要件を追加
- `dungeon-movement`: 移動入力を keycode から action ベースの規約に変更(`move_forward` / `move_back` / `strafe_left` / `strafe_right` / `turn_left` / `turn_right`)
- `dungeon-3d-rendering`: M キー処理を `toggle_full_map` action ベースに
- `full-map-overlay`: ESC 処理を `ui_cancel` action ベースに
- `esc-menu-overlay`: 入力規約を action ベースに統一(MenuController 採用は C6 で行う)
- `save-screen`: 入力規約を action ベースに統一
- `load-screen`: 入力規約を action ベースに統一
- `combat-overlay`: 入力規約を action ベースに統一(per-phase 入力ルータは C7 で扱う)
- `encounter-overlay`: 確認キーを `ui_accept` に
- `screen-navigation`: main.gd のトップレベル ESC を `ui_cancel` に

## Impact

- **変更コード**:
  - `project.godot` — `[input]` セクション追加
  - 9 ファイルの `_unhandled_input` メソッド — keycode マッチを action マッチに置換
  - 各テストファイル — `make_key_event` を `make_action_event` に切り替え(または両対応)
- **新規ヘルパー**:
  - `tests/test_helpers.gd:make_action_event` — C4a で追加済みなら再利用、なければ追加
- **互換性**:
  - エンドユーザのキー操作は変わらない(同じキーが同じアクションにマップされる)
  - スクリプト API の `_unhandled_input` 内部実装のみ変更
  - セーブデータへの影響なし
- **依存関係**:
  - C4a (add-menu-controller) が前提条件 — `MenuController` を本 change で利用する
  - C4b 完了後、C5/C6/C7 の神クラス分解時に MenuController + action ベースの統一規約に乗れる
