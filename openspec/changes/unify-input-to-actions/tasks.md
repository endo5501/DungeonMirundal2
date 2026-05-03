## 1. project.godot にカスタムアクションを追加

- [x] 1.1 Godot エディタで Project Settings → Input Map を開く
- [x] 1.2 `move_forward` アクションを追加し、KEY_W と KEY_UP をバインド
- [x] 1.3 `move_back` アクションを追加し、KEY_S と KEY_DOWN をバインド
- [x] 1.4 `strafe_left` アクションを追加し、KEY_A をバインド
- [x] 1.5 `strafe_right` アクションを追加し、KEY_D をバインド
- [x] 1.6 `turn_left` アクションを追加し、KEY_LEFT をバインド
- [x] 1.7 `turn_right` アクションを追加し、KEY_RIGHT をバインド
- [x] 1.8 `toggle_full_map` アクションを追加し、KEY_M をバインド
- [x] 1.9 `project.godot` を保存し、`[input]` セクションが追加されていることを確認

## 2. TestHelpers の action event ヘルパー確認

- [x] 2.1 `tests/test_helpers.gd` に `make_action_event(action: StringName, pressed: bool = true) -> InputEventAction` が存在することを確認(C4a で追加済みのはず、なければ追加)
- [x] 2.2 GUT 実行時に `is_action_pressed("move_forward")` が `make_action_event("move_forward")` で true を返すことを smoke test で確認

## 3. dungeon_screen.gd の action 化 (TDD)

- [x] 3.1 `tests/dungeon/test_dungeon_screen_encounter.gd` の `make_key_event(KEY_UP/W/S/...)` 呼び出しを `make_action_event("move_forward"/...)` に置換
- [x] 3.2 `tests/dungeon/test_dungeon_screen_full_map.gd` の同様の置換
- [x] 3.3 既存テストが失敗することを確認(production がまだ keycode のため)
- [x] 3.4 `src/dungeon_scene/dungeon_screen.gd` の `_unhandled_input` を action ベースに書き換え:
  - `KEY_W/UP` → `is_action_pressed("move_forward")`
  - `KEY_S/DOWN` → `is_action_pressed("move_back")`
  - `KEY_A` → `is_action_pressed("strafe_left")`
  - `KEY_D` → `is_action_pressed("strafe_right")`
  - `KEY_LEFT` → `is_action_pressed("turn_left")`
  - `KEY_RIGHT` → `is_action_pressed("turn_right")`
  - `KEY_M` → `is_action_pressed("toggle_full_map")`
  - `KEY_ESCAPE` → `is_action_pressed("ui_cancel")` (帰還ダイアログ用)
  - `KEY_ENTER/SPACE` → `is_action_pressed("ui_accept")` (帰還ダイアログ用)
- [x] 3.5 全テスト通過を確認しコミット

## 4. dungeon_scene 系の action 化

- [ ] 4.1 `src/dungeon_scene/full_map_overlay.gd` の ESC キー処理を `is_action_pressed("ui_cancel")` に置換、対応するテストも更新
- [ ] 4.2 `src/dungeon_scene/encounter_overlay.gd` の確認キー処理を `is_action_pressed("ui_accept")` に置換、対応するテストも更新
- [ ] 4.3 `src/dungeon_scene/combat_overlay.gd` の入力処理を action ベースに書き換え(per-phase ルータ化は C7 で行うので、本 change では keycode → action のみ)、対応するテストも更新
- [ ] 4.4 各ファイルごとにテスト通過を確認しコミット

## 5. esc_menu の action 化

- [ ] 5.1 `tests/esc_menu/test_esc_menu.gd` の keycode マッチを action マッチに置換
- [ ] 5.2 `src/esc_menu/esc_menu.gd` の `_unhandled_input` を action ベースに書き換え(MenuController 採用は C6 で行う)
- [ ] 5.3 全テスト通過を確認しコミット

## 6. save_screen / load_screen の MenuController 採用 + action 化

- [ ] 6.1 `tests/save_load/test_save_screen.gd` の keycode を action に置換
- [ ] 6.2 `tests/save_load/test_load_screen.gd` の keycode を action に置換
- [ ] 6.3 既存テストが失敗することを確認
- [ ] 6.4 `src/save_screen.gd` の `_unhandled_input` を `MenuController.route` ベースに書き換え、上書き確認ダイアログは別ハンドラに残す(action ベース)
- [ ] 6.5 `src/load_screen.gd` の `_unhandled_input` を `MenuController.route` ベースに書き換え、no-saves 状態は `ui_cancel` のみ処理
- [ ] 6.6 全テスト通過を確認しコミット

## 7. main.gd の action 化

- [ ] 7.1 `tests/save_load/test_main_*.gd` または `tests/test_main.gd` で main の keycode 比較が action ベースになっても通ることを確認
- [ ] 7.2 `src/main.gd` の `_unhandled_input` の `KEY_ESCAPE` を `is_action_pressed("ui_cancel")` に置換
- [ ] 7.3 全テスト通過を確認しコミット

## 8. character_list / shop_screen の混在解消

- [ ] 8.1 `src/guild_scene/character_list.gd` で残っている `KEY_*` 比較を action に置換
- [ ] 8.2 `src/town_scene/shop_screen.gd` で残っている `KEY_*` 比較を action に置換(あれば)
- [ ] 8.3 対応するテストを action ベースに合わせる
- [ ] 8.4 全テスト通過を確認しコミット

## 9. 全体検証

- [ ] 9.1 `Grep` で `src/` 内の `_unhandled_input` 関数本体に `event.keycode == KEY_` が残っていないことを確認(テキスト入力ハンドラは除外)
- [ ] 9.2 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過
- [ ] 9.3 ゲームを起動し、全画面でキー操作が変わっていないことを目視確認(タイトル → 町 → ギルド → 各サブ画面 → ダンジョン → 戦闘)
- [ ] 9.4 ダンジョンの WASD + 矢印で移動できることを確認
- [ ] 9.5 M キーで全体マップが開閉できることを確認
- [ ] 9.6 ESC キーで全画面のメニューが開閉できることを確認

## 10. 仕上げ

- [ ] 10.1 `openspec validate unify-input-to-actions --strict`
- [ ] 10.2 `/simplify`スキルでコードレビューを実施
- [ ] 10.3 `/opsx:verify unify-input-to-actions`
- [ ] 10.4 `/opsx:archive unify-input-to-actions`
