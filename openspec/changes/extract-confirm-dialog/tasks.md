## 1. ConfirmDialog の追加 (TDD)

- [x] 1.1 `tests/ui/test_confirm_dialog.gd` を作成、setup でメッセージ表示・default_index 反映テスト
- [x] 1.2 「はい」選択 + ui_accept で confirmed シグナル発行テスト
- [x] 1.3 「いいえ」選択 + ui_accept で cancelled シグナル発行テスト
- [x] 1.4 ui_cancel で常に cancelled テスト
- [x] 1.5 setup を再度呼ぶと再表示されるテスト
- [x] 1.6 visible=false の状態で input が来ても何も起きないテスト
- [x] 1.7 テスト Red コミット
- [x] 1.8 `src/ui/confirm_dialog.gd` を実装、内部で MenuController.route を利用
- [x] 1.9 テスト Green コミット

## 2. dungeon_screen の帰還ダイアログ置換 (TDD)

- [x] 2.1 `tests/dungeon/test_dungeon_screen.gd` (or 既存)で「START タイル上で帰還ダイアログが表示される」「はいで町遷移」「いいえ/ESC で残る」テストを ConfirmDialog 経由でも通るよう更新
- [x] 2.2 `src/dungeon_scene/dungeon_screen.gd` から `_show_return_dialog` 旧実装と関連入力ハンドラを削除
- [x] 2.3 `_return_dialog: ConfirmDialog` フィールドを追加、_ready で生成、シグナル接続
- [x] 2.4 `is_showing_return_dialog()` を `_return_dialog.visible` で代替
- [x] 2.5 全テスト通過を確認しコミット

## 3. dungeon_entrance の削除確認置換 (TDD)

- [x] 3.1 既存テストを ConfirmDialog 経由で通るよう更新
- [x] 3.2 `src/town_scene/dungeon_entrance.gd:179-234` のインライン実装を削除
- [x] 3.3 ConfirmDialog インスタンスを保持してシグナル接続
- [x] 3.4 全テスト通過を確認しコミット

## 4. save_screen の上書き確認置換 (TDD)

- [x] 4.1 既存 `test_save_screen.gd` のうち `is_overwrite_dialog_visible()` を assert している箇所を確認し、ConfirmDialog の visible を参照するよう書き換え
- [x] 4.2 `src/save_screen.gd` から `_build_overwrite_dialog` / `_handle_overwrite_input` を削除
- [x] 4.3 `_overwrite_dialog: ConfirmDialog` フィールドを追加、シグナル接続
- [x] 4.4 `is_overwrite_dialog_visible()` の getter は `_overwrite_dialog.visible` を返す形にして、テスト互換性を維持
- [x] 4.5 全テスト通過を確認しコミット

## 5. esc_menu の終了確認置換 (TDD)

- [x] 5.1 既存テストを更新
- [x] 5.2 `src/esc_menu/esc_menu.gd:124-126` のインライン実装(_quit_menu / _quit_dialog_container 等)を削除
- [x] 5.3 ConfirmDialog インスタンスを保持
- [x] 5.4 全テスト通過を確認しコミット

## 6. shop_screen の _handle_list_input 統合 (TDD)

- [x] 6.1 `tests/town/test_shop_screen.gd` の既存 buy / sell テストが共通ヘルパー経由でも通ることを確認
- [x] 6.2 `src/town_scene/shop_screen.gd` に `_handle_list_input(event, count, on_accept: Callable) -> bool` を追加
- [x] 6.3 `_input_buy` を `_handle_list_input` 呼び出しに簡素化
- [x] 6.4 `_input_sell` を `_handle_list_input` 呼び出しに簡素化(sell 後の `_selected_index` 補正は on_accept 内で実行)
- [x] 6.5 全テスト通過を確認しコミット

## 7. 動作確認

- [x] 7.1 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過
- [ ] 7.2 ゲーム起動 → 各ダイアログを目視確認(ユーザ確認待ち):
  - START タイル上で帰還ダイアログ
  - ダンジョン入口で削除確認
  - セーブ画面で上書き確認
  - ESC で終了確認
- [ ] 7.3 ショップで購入・売却モードのリスト操作を確認(ユーザ確認待ち)

## 8. 仕上げ

- [x] 8.1 `openspec validate extract-confirm-dialog --strict`
- [ ] 8.2 `/simplify`スキルでコードレビューを実施
- [ ] 8.3 `/opsx:verify extract-confirm-dialog`
- [ ] 8.4 `/opsx:archive extract-confirm-dialog`
