## 1. TestHelpers 拡張

- [x] 1.1 `tests/test_helpers.gd` に `make_action_event(action: StringName, pressed: bool = true) -> InputEventAction` を追加(InputEventAction で action を再現)
- [x] 1.2 `Callable()` (引数なしコンストラクタ) が `is_valid() == false` を返すことを 1 行のテストで確認(設計前提の検証)

## 2. MenuController の単体実装 (TDD)

- [x] 2.1 `tests/ui/test_menu_controller.gd` を新規作成し、`route(event_ui_down, ...)` で `menu.move_cursor(1)` が呼ばれ true が返るテスト
- [x] 2.2 `route(event_ui_up, ...)` で `move_cursor(-1)` が呼ばれ true が返るテスト
- [x] 2.3 `route(event_ui_accept, ..., on_accept)` で `on_accept` が呼ばれ true が返るテスト
- [x] 2.4 `route(event_ui_cancel, ..., on_back)` で `on_back` が呼ばれ true が返るテスト
- [x] 2.5 `route(event_ui_cancel, ...)` で on_back 未指定の場合 false が返り、コールバックは呼ばれないテスト
- [x] 2.6 `route(event_ui_down, ..., on_cursor_changed)` で `on_cursor_changed` が `update_rows` の後に 1 回呼ばれるテスト
- [x] 2.7 未対応 event(ui_left など)で false が返り、menu の状態が変わらないテスト
- [x] 2.8 テストを実行し全て失敗することを確認しコミット (Red)
- [x] 2.9 `src/ui/menu_controller.gd` を新規作成、`class_name MenuController extends RefCounted` で static `route` を実装
- [x] 2.10 全テスト通過を確認しコミット (Green)

## 3. title_screen の MenuController 採用 (TDD)

- [x] 3.1 `tests/title_scene/test_title_screen.gd` に「ESC 押下でいずれのシグナルも発行されない、`set_input_as_handled` も呼ばれない」テストを追加 — added to tests/dungeon/test_title_screen.gd (no signals emitted, cursor unchanged); set_input_as_handled is covered by MenuController unit tests since asserting viewport state is unreliable across gut tests.
- [x] 3.2 既存テストが MenuController 経由でも通ることを念のため確認するテスト(ui_down, ui_up, ui_accept での menu 動作)を追加(既存にあればそのまま使う)
- [x] 3.3 テストを実行し ESC テストが失敗することを確認しコミット (Red) — current title_screen already silently ignores ESC (no handler), so the new test passes pre-refactor; tests are pinned as regression for the explicit ignore.
- [x] 3.4 `src/title_scene/title_screen.gd` の `_unhandled_input` を `MenuController.route(event, _menu, _rows, confirm_selection)` ベースに書き換える
- [x] 3.5 戻り値が true なら `set_input_as_handled()` を呼ぶ
- [x] 3.6 ESC については `on_back` を渡さないことで明示的に無視、コメントで意図を明示
- [x] 3.7 全テスト通過を確認しコミット (Green)

## 4. town_screen の MenuController 採用 (TDD)

- [x] 4.1 既存 `tests/town/test_town_screen.gd` を読み、外部挙動(menu 移動 + イラスト更新 + select_item)を網羅していることを確認 — covered by test_move_down_*, test_label_updates_when_cursor_moves, etc.
- [x] 4.2 不足があればテスト追加 — coverage already sufficient (cursor moves + illustration texture/label tracking).
- [x] 4.3 `src/town_scene/town_screen.gd` の `_unhandled_input` を `MenuController.route(event, _menu, _rows, confirm_selection, Callable(), _update_illustration)` に書き換える
- [x] 4.4 全テスト通過を確認しコミット

## 5. temple_screen の MenuController 採用 (TDD)

- [x] 5.1 既存 `tests/town/test_temple_screen.gd` を読み、外部挙動を確認 — covers revive cost / success / blocked / dead-vs-alive checks; cursor movement is not asserted, so the migration to CursorMenu is safe.
- [x] 5.2 `src/town_scene/temple_screen.gd` の `_unhandled_input` を MenuController.route ベースに書き換える(temple は ESC で町に戻るので `on_back` を渡す)。Internally migrated from a manual `_selected_index` to `CursorMenu` so MenuController.route applies. Living members are passed as disabled_indices, matching the original "(生存)" greying.
- [x] 5.3 全テスト通過を確認しコミット

## 6. 動作確認

- [x] 6.1 `godot --headless --import` を実行
- [x] 6.2 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過 — 1164/1164 passing.
- [ ] 6.3 ゲームを起動し、タイトル画面でカーソル移動・選択・ESC 押下を目視確認 — manual verification by user.
- [ ] 6.4 町画面でカーソル移動と各施設遷移を目視確認、イラストが更新されることを確認 — manual verification by user.
- [ ] 6.5 教会画面でカーソル移動・選択・ESC で町に戻れることを確認 — manual verification by user.

## 7. 仕上げ

- [x] 7.1 `openspec validate add-menu-controller --strict` で妥当性確認
- [x] 7.2 `/simplify`スキルでコードレビューを実施 — Three-agent review found one actionable item (trim verbose WHAT comments on menu_controller.gd header and title_screen.gd ESC block); applied. Other findings were out of scope (pre-existing TitleScreen.setup_save_state cursor reset; convention question on src/ui/ vs src/dungeon/, but tasks.md explicitly specifies src/ui/) or low value (stringly-typed action names — only used in one file).
- [ ] 7.3 `/opsx:verify add-menu-controller` で実装と仕様の整合確認
- [ ] 7.4 `/opsx:archive add-menu-controller` でアーカイブ
