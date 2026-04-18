## 1. CursorMenu 拡張

- [ ] 1.1 `ensure_valid_selection()` のテストを追加: 初期 selected_index が disabled_indices に含まれる時、最初の有効インデックスに移動することを確認 (`tests/dungeon/test_cursor_menu.gd` 相当)
- [ ] 1.2 全項目 disabled の場合に現状の selected_index を維持することのテストを追加
- [ ] 1.3 テストが失敗することを確認してコミット
- [ ] 1.4 `src/dungeon/cursor_menu.gd` に `ensure_valid_selection()` を実装
- [ ] 1.5 1.1〜1.2 のテストが通過することを確認

## 2. タイトル画面の並び替えと初期カーソル

- [ ] 2.1 `tests/` 配下の既存 title テストを確認し、新仕様と合わない scenario を特定
- [ ] 2.2 新仕様のテストを追加: (a) MENU_ITEMS 順が `["前回から","新規ゲーム","ロード","ゲーム終了"]` (b) セーブ有り + last_slot 有効で初期 selected_index = 0 (c) セーブ無しで初期 selected_index = 1 (d) セーブ有り + last_slot 無効で初期 selected_index = 1
- [ ] 2.3 既存テスト（Down キーで「新規ゲーム」→「前回から」に動くなど）を新順序に合わせて更新
- [ ] 2.4 テストが失敗することを確認してコミット
- [ ] 2.5 `src/title_scene/title_screen.gd` の `MENU_ITEMS` を並び替え
- [ ] 2.6 `setup_save_state()` の末尾で `_menu.ensure_valid_selection()` を呼び、初期カーソルを最初の有効項目に合わせる
- [ ] 2.7 `select_item(index)` の `match` 分岐を新しいインデックスに合わせて更新（0=continue, 1=new_game, 2=load, 3=quit）
- [ ] 2.8 すべての title テストが通過することを確認

## 3. ダンジョン入口の空状態初期フォーカス

- [ ] 3.1 既存の dungeon_entrance テストを確認し、空 registry 時の初期状態を検証している scenario を特定
- [ ] 3.2 新仕様のテストを追加: (a) 空 registry で `setup()` 呼び出し後に `_focus == Focus.BUTTONS` (b) `_button_menu.selected_index == 1` (新規生成) (c) Enter キー1回で DungeonCreateDialog が開く (d) registry に1件以上ある場合は `_focus == Focus.DUNGEON_LIST` が維持される
- [ ] 3.3 テストが失敗することを確認してコミット
- [ ] 3.4 `src/town_scene/dungeon_entrance.gd` の `setup()` を修正: registry 空時に `_focus = Focus.BUTTONS` と `_button_menu.selected_index = 1` を設定
- [ ] 3.5 3.2 のテストが通過することを確認

## 4. ダンジョン入口の空状態メッセージ

- [ ] 4.1 新仕様のテストを追加: 空 registry 時の表示文言が "まず「新規生成」でダンジョンを作成してください" である、かつ通常色（`CursorMenu.ENABLED_COLOR` または override 無し）で表示される
- [ ] 4.2 テストが失敗することを確認してコミット
- [ ] 4.3 `src/town_scene/dungeon_entrance.gd` の `_build_ui()` 内、空 registry ブランチのメッセージ文字列を差し替え
- [ ] 4.4 `empty.add_theme_color_override("font_color", CursorMenu.DISABLED_COLOR)` を削除し、通常色で表示されるようにする
- [ ] 4.5 4.1 のテストが通過することを確認

## 5. 統合確認

- [ ] 5.1 `godot --headless -s addons/gut/gut_cmdln.gd` で全テストが通過することを確認
- [ ] 5.2 手動確認: セーブなしで起動 → タイトル画面で初期カーソルが「新規ゲーム」
- [ ] 5.3 手動確認: セーブありで起動 → タイトル画面で初期カーソルが「前回から」
- [ ] 5.4 手動確認: 町から「ダンジョン入口」へ、ダンジョン0件で Enter 1回で新規生成ダイアログが開く
- [ ] 5.5 手動確認: ダンジョン1件以上で入口を開くと、カーソルがダンジョンリストに乗っている（既存挙動）
- [ ] 5.6 `openspec validate polish-title-and-entrance-ux --strict` が通る

## 6. 完了

- [ ] 6.1 変更内容をコミット（英語メッセージ）
- [ ] 6.2 `/opsx:verify polish-title-and-entrance-ux` で検証
