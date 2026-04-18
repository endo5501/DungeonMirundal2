## 1. CursorMenuRow の導入

- [x] 1.1 `tests/dungeon/test_cursor_menu_row.gd`（または相当位置）に `CursorMenuRow` の単体テストを追加: (a) 構築時にカーソル列がある (b) `set_selected(true)` でインジケータが可視 (c) `set_selected(false)` で不可視 (d) カーソル列の幅が両状態で同一 (e) `set_text` がテキスト列に反映 (f) `set_disabled(true)` でテキスト列が DISABLED_COLOR (g) `add_extra_label` が右に追加される (h) extra label 追加後もカーソル列幅不変
- [x] 1.2 テストが失敗することを確認してコミット
- [x] 1.3 `src/dungeon/cursor_menu_row.gd` を実装
- [x] 1.4 1.1 のテストが通過することを確認

## 2. CursorMenu.update_rows の追加

- [x] 2.1 `test_cursor_menu.gd` に `update_rows()` のテストを追加: (a) selected_index に応じて cursor 表示が切り替わる (b) disabled_indices に応じて行の色が切り替わる (c) 空配列で呼んでもクラッシュしない
- [x] 2.2 テストが失敗することを確認してコミット
- [x] 2.3 `src/dungeon/cursor_menu.gd` に `update_rows(Array[CursorMenuRow])` を実装
- [x] 2.4 2.1 のテストが通過することを確認

## 3. 画面移行: title_screen

- [x] 3.1 `title_screen` の既存テストから `"> "` / `"  "` 前提のアサーションを抽出、新 API（`row.is_selected()` など）に書き換え
- [x] 3.2 テストが失敗することを確認
- [x] 3.3 `src/title_scene/title_screen.gd` を `_rows: Array[CursorMenuRow]` と `_menu.update_rows(_rows)` に書き換え
- [x] 3.4 title_screen のテストが全て通過することを確認

## 4. 画面移行: town_screen

- [x] 4.1 `town_screen` のテストを新 API に更新
- [x] 4.2 `src/town_scene/town_screen.gd` を行ベースに移行
- [x] 4.3 テストが通過することを確認

## 5. 画面移行: shop_screen

- [x] 5.1 `shop_screen` のテストを新 API に更新（`TOP_MENU_ITEMS` 部分のみ該当）
- [x] 5.2 `src/town_scene/shop_screen.gd` を行ベースに移行
- [x] 5.3 テストが通過することを確認

## 6. 画面移行: temple_screen

- [x] 6.1 `temple_screen` のテストを新 API に更新
- [x] 6.2 `src/town_scene/temple_screen.gd` を行ベースに移行
- [x] 6.3 テストが通過することを確認

## 7. 画面移行: esc_menu

- [x] 7.1 `esc_menu` のテストを新 API に更新。main_menu / party_menu / quit_menu の 3 メニュー分が対象
- [x] 7.2 `src/esc_menu/esc_menu.gd` の `_build_menu_labels` を `_build_menu_rows` に書き換え、3 メニューとも行ベースに移行
- [x] 7.3 テストが通過することを確認

## 8. 画面移行: save_screen / load_screen

- [x] 8.1 save_screen / load_screen のテストを新 API に更新（save_screen は `_menu` と `_overwrite_menu` の 2 メニュー）
- [x] 8.2 `src/save_screen.gd` を行ベースに移行
- [x] 8.3 `src/load_screen.gd` を行ベースに移行
- [x] 8.4 テストが通過することを確認

## 9. 画面移行: dungeon_screen (return dialog)

- [x] 9.1 `dungeon_screen` のリターンダイアログのテストを新 API に更新（line 173 付近の `CURSOR_PREFIX` 直接参照を書き換え）
- [x] 9.2 `src/dungeon_scene/dungeon_screen.gd` の return dialog を行ベースに移行
- [x] 9.3 テストが通過することを確認

## 10. 画面移行: dungeon_entrance（複合ケース）

- [x] 10.1 dungeon_entrance のテストを新 API に更新。対象: (a) ダンジョンリスト行（マルチカラム: 名前・サイズ・探索率）(b) ボタン列 4 項目 (c) 削除確認ダイアログの「はい/いいえ」
- [x] 10.2 `src/town_scene/dungeon_entrance.gd` の `_build_ui` と `_update_labels` を行ベースに書き換え、リスト行は `CursorMenuRow.add_extra_label` でマルチカラム化
- [x] 10.3 削除確認ダイアログ（line 180 付近の直接プレフィックス参照）も行ベースに移行
- [x] 10.4 フォーカス切替（DUNGEON_LIST ↔ BUTTONS）と連動したカーソル可視性がテストで緑
- [x] 10.5 テストが通過することを確認

## 11. 旧 API の削除

- [x] 11.1 `src/` を `CURSOR_PREFIX` / `NO_CURSOR_PREFIX` で grep し、参照が残っていないことを確認
- [x] 11.2 `src/` を `update_labels` で grep し、残参照が無いことを確認
- [x] 11.3 `src/dungeon/cursor_menu.gd` から `CURSOR_PREFIX`, `NO_CURSOR_PREFIX`, `update_labels(labels)` を削除
- [x] 11.4 全テスト通過を確認

## 12. 統合確認

- [x] 12.1 `godot --headless -s addons/gut/gut_cmdln.gd` で全テストが通過することを確認
- [ ] 12.2 手動確認: title → ↓↑ で項目位置が一切動かない
- [ ] 12.3 手動確認: town/shop/temple のメニューで同上
- [ ] 12.4 手動確認: ダンジョン入口のリスト行（マルチカラム）でカーソル移動時に名前・サイズ・探索率のテキスト開始位置が不変
- [ ] 12.5 手動確認: ESC メニュー 3 階層すべてで位置不変
- [ ] 12.6 手動確認: セーブ・ロード画面で位置不変
- [x] 12.7 `openspec validate cursor-column-layout --strict` が通る

## 13. 完了

- [x] 13.1 変更内容を機能ごとにコミット（英語メッセージ）
- [ ] 13.2 `/opsx:verify cursor-column-layout` で検証
