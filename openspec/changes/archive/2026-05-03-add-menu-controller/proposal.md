## Why

`_unhandled_input` のメニューボイラープレート(ui_down で move_cursor、ui_up で move_cursor、ui_accept で confirm、必要なら ui_cancel で back、いずれも `set_input_as_handled` を呼ぶ)が 18 ファイル以上で重複している。同じパターンが微妙に違う形(action ベース vs keycode、cancel ハンドリングの有無、`set_input_as_handled` の呼び方)で散在しており、追加修正(キーバインド変更や IME 対応)のたびに全ファイルを触る必要がある。

C4b で全画面を action ベースに統一する前段階として、本 change で **共通の `MenuController` ヘルパー** を導入し、すでに action ベースで書かれている画面(title_screen, town_screen, temple_screen など)で先行採用する。リスクの低い画面で先に動作確認することで、後続の C4b/C5/C6/C7 で安心して MenuController に依存できるようになる。

加えて、title_screen は ESC キーを明示的にハンドリングしていないため、将来の保守者が「忘れた」のか「意図的に無視」なのか判断できない。ESC を明示的に no-op として処理するロジックを追加する。

## What Changes

- `src/ui/menu_controller.gd` に `MenuController` (RefCounted) を新規追加し、`route(event, menu, rows, on_accept, on_back, on_cursor_changed)` メソッドで標準的なメニュー入力ルーティングを提供する
- `MenuController` は action ベース(`ui_up` / `ui_down` / `ui_accept` / `ui_cancel`)で動作し、event を消費した場合は `true` を返す
- `src/title_scene/title_screen.gd` の `_unhandled_input` を MenuController 経由に書き換える
- `src/town_scene/town_screen.gd` の `_unhandled_input` を MenuController 経由に書き換える
- `src/town_scene/temple_screen.gd` の `_unhandled_input` を MenuController 経由に書き換える
- `src/title_scene/title_screen.gd` に明示的な ESC no-op ハンドリングを追加する(`MenuController` の `on_back` を `null` にすると ui_cancel は無視されることを契約として確立する)
- `tests/ui/test_menu_controller.gd` を新規追加し、各分岐(ui_up / ui_down / ui_accept / ui_cancel / その他)を単体テスト
- 既存テスト(`test_title_screen.gd`, `test_town_screen.gd`, `test_temple_screen.gd`)は外部挙動が変わらないので無修正で通過する想定

## Capabilities

### New Capability

- `menu-controller`: 共通のメニュー入力ルーティングヘルパー。RefCounted ベース、action ベース、再利用可能。

### Modified Capabilities

- `cursor-menu-ui`: `MenuController` との連携要件を追記
- `title-screen`: ESC キーの明示的 no-op を追記

## Impact

- **新規コード**:
  - `src/ui/menu_controller.gd`
  - `tests/ui/test_menu_controller.gd`
- **変更コード**:
  - `src/title_scene/title_screen.gd` — `_unhandled_input` を MenuController 経由に
  - `src/town_scene/town_screen.gd` — 同上
  - `src/town_scene/temple_screen.gd` — 同上
- **互換性**:
  - 外部から見える挙動は変わらない(ボイラープレートを集約するだけ)
  - 他の画面(esc_menu, dungeon_screen, save/load, character_creation, etc.)は本 change では触らない — C4b で順次移行
- **依存関係**:
  - C1, C2, C3 と独立に進行可能だが、C4b の前提条件
  - C4b 完了後、本 change で導入した MenuController を全画面で使う形になる
