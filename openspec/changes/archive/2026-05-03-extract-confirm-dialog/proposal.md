## Why

「はい/いいえ」確認ダイアログのインライン実装が 4 箇所で重複している:

- `src/dungeon_scene/dungeon_screen.gd:165-220` — ダンジョンから町へ戻る確認
- `src/town_scene/dungeon_entrance.gd:179-234` — ダンジョン削除確認
- `src/save_screen.gd:78-103` — セーブ上書き確認
- `src/esc_menu/esc_menu.gd:124-126` — タイトル戻り(ゲーム終了)確認

すべて「PanelContainer + VBox + メッセージ Label + CursorMenu("はい", "いいえ")」のパターン。1 つの ConfirmDialog Control に集約できる。

加えて F014 で指摘されている `shop_screen.gd:_input_buy` と `_input_sell` の near-duplicate(80% 重複)もリスト操作の共通化として、本 change で `_handle_list_input(event, count, on_accept: Callable, on_cancel: Callable)` ヘルパーに集約する。

## What Changes

- `src/ui/confirm_dialog.gd` を新規追加(`ConfirmDialog extends Control`)
  - `setup(message: String, default_index: int = 1)` で初期化
  - 内部に CursorMenu("はい", "いいえ") を保持
  - `confirmed` シグナル(yes が選ばれた時)、`cancelled` シグナル(no か ui_cancel 時)を発行
  - 半透明オーバーレイ + 中央 PanelContainer のレイアウト
- 4 箇所のインライン実装を `ConfirmDialog` に置き換え:
  - `dungeon_screen.gd` の帰還ダイアログ
  - `dungeon_entrance.gd` の削除確認
  - `save_screen.gd` の上書き確認
  - `esc_menu.gd` の終了確認
- `shop_screen.gd` の `_input_buy` / `_input_sell` を `_handle_list_input` ヘルパーに統合
- 各画面のテストは ConfirmDialog 経由でも外部挙動が同じになることを確認

## Capabilities

### New Capabilities

- `confirm-dialog`: はい/いいえ確認ダイアログ Control。共通 UI コンポーネント。

### Modified Capabilities

- `dungeon-return`: 帰還ダイアログを ConfirmDialog で構築することを規定
- `dungeon-entrance`: 削除確認を ConfirmDialog で構築することを規定
- `save-screen`: 上書き確認を ConfirmDialog で構築することを規定
- `esc-menu-overlay`: 終了確認を ConfirmDialog で構築することを規定
- `shop`: list 入力ハンドリングの統合(`_handle_list_input` ヘルパー)を規定

## Impact

- **新規コード**:
  - `src/ui/confirm_dialog.gd`
  - `tests/ui/test_confirm_dialog.gd`
- **変更コード**:
  - `src/dungeon_scene/dungeon_screen.gd` — 約 50 LOC 削減
  - `src/town_scene/dungeon_entrance.gd` — 同様に削減
  - `src/save_screen.gd` — `_build_overwrite_dialog` / `_handle_overwrite_input` を ConfirmDialog 利用に置換
  - `src/esc_menu/esc_menu.gd` — 終了確認の build/input を置換
  - `src/town_scene/shop_screen.gd` — `_input_buy` / `_input_sell` 統合
- **互換性**:
  - 各ダイアログの外部観測可能挙動(表示、選択、シグナル発行)は不変
  - 既存テストが通る(必要なら ConfirmDialog 経由でアクセスする getter を追加)
- **依存関係**:
  - C4a (MenuController) を ConfirmDialog 内部で利用
  - C4b 完了が前提(action ベースで input 処理)
  - C6 完了後に着手すると esc_menu 側の置換と整合
