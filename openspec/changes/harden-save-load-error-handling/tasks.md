## 1. SaveManager の失敗通知 (TDD)

- [x] 1.1 `tests/save_load/test_save_manager.gd` に `save` が `bool` を返すことを assert するテストを追加する(既存テストの assert を更新)
- [x] 1.2 `SaveManager.LoadResult` enum を定義するテスト(列挙値の存在確認)を追加する
- [x] 1.3 `version > CURRENT_VERSION` のセーブを `load` した時 `LoadResult.VERSION_TOO_NEW` が返ることをテストする
- [x] 1.4 JSON が壊れたファイルを `load` した時 `LoadResult.PARSE_ERROR` が返ることをテストする
- [x] 1.5 ファイル欠損時 `load` が `LoadResult.FILE_NOT_FOUND` を返すことをテストする
- [x] 1.6 テストを実行し全て失敗することを確認しコミットする (Red)
- [x] 1.7 `src/save_manager.gd` の `save` 戻り値を `bool` 化、失敗時は `push_error` でログを出して `false` 返却するように実装
- [x] 1.8 `LoadResult` enum を実装、`load` の返却を `LoadResult` に置き換える
- [x] 1.9 全テスト通過を確認しコミットする (Green)

## 2. Character.from_dict / Guild.from_dict の堅牢化 (TDD)

- [x] 2.1 `tests/save_load/` または `tests/dungeon/` に `Character.from_dict` の race_id 不在ケース、job_id 不在ケースで `null` が返ることをテスト追加
- [x] 2.2 `Guild.from_dict` で characters 配列に null 要素を含むデータを与えた時、null をスキップして他は復元されることをテスト追加
- [x] 2.3 null をスキップした後の `front_row` / `back_row` インデックス整合性のテストを追加(null 要素を指していたインデックスは配置しない、他は配置される)
- [x] 2.4 テストを実行し全て失敗することを確認しコミットする (Red)
- [x] 2.5 `src/dungeon/character.gd:from_dict` で race / job の load 失敗時 `push_warning` を出して `null` 返却に変更
- [x] 2.6 `src/dungeon/guild.gd:from_dict` で null character をスキップ、party 配置を破損 character を踏まないように再構築
- [x] 2.7 全テスト通過を確認しコミットする (Green)

## 3. DataLoader の packaging エラー検出 (TDD)

- [x] 3.1 `tests/dungeon/test_data_loader.gd` (新規 or 既存)に存在しないディレクトリを与えた時のテストを追加(空配列返却 + push_error が呼ばれることの検証は限定的だが、空配列は確認可)
- [x] 3.2 テストを実行し既存実装でも空配列は返るが push_error はないことを確認(Red 相当)
- [x] 3.3 `src/dungeon/data/data_loader.gd:_load_resources` に `push_error` を追加
- [x] 3.4 全テスト通過を確認しコミットする (Green)

## 4. SaveScreen の失敗 UI (TDD)

- [x] 4.1 `tests/save_load/test_save_screen.gd` (既存) に保存失敗時 `_status_label` がエラーメッセージを表示するテストを追加
- [x] 4.2 保存成功時に `_status_label` がクリアされることをテスト追加
- [x] 4.3 上書き失敗時の表示テストを追加
- [x] 4.4 テストを実行し全て失敗することを確認しコミットする (Red)
- [x] 4.5 `src/save_screen.gd` に `_status_label: Label` を追加、`_on_slot_selected` / `_handle_overwrite_input` の `_save_manager.save(...)` 戻り値を確認して失敗時はラベルにメッセージ、成功時はクリア
- [x] 4.6 全テスト通過を確認しコミットする (Green)

## 5. LoadScreen と main._load_game の失敗 UI (TDD)

- [x] 5.1 `tests/save_load/test_load_screen.gd` (既存 or 新規) に load 失敗事由ごとの表示テストを追加(VERSION_TOO_NEW / PARSE_ERROR / FILE_NOT_FOUND / RESTORE_FAILED)
- [x] 5.2 `tests/save_load/test_main_save_load.gd` に `_load_game` 失敗時にロード画面が閉じずエラーメッセージが表示されることを確認するテストを追加
- [x] 5.3 テストを実行し全て失敗することを確認しコミットする (Red)
- [x] 5.4 `src/load_screen.gd` に `_status_label` 追加、`load_failed(reason)` シグナルを追加、または `show_load_failure(result: LoadResult)` メソッドを追加
- [x] 5.5 `src/main.gd:_load_game` を `LoadResult` ベースに書き換え、失敗時は `_load_screen.show_load_failure(result)` を呼ぶ
- [x] 5.6 全テスト通過を確認しコミットする (Green)

## 6. 動作確認

- [x] 6.1 `godot --headless --import` を実行
- [x] 6.2 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイートが通ることを確認 — 35 既存失敗(画像読込等)以外は全 pass、本変更による回帰なし
- [x] 6.3 Godot エディタで起動し、セーブ画面で保存 → 「保存しました」相当のフィードバックがあること(現状は無音なので新規 UI の追加でも可)
- [x] 6.4 セーブ画面で(手動で `user://saves/` を読み取り専用にした状態で)保存 → 失敗ラベルが出ることを確認
- [x] 6.5 ロード画面で破損 JSON のスロットを選択 → 失敗ラベルが出ることを確認
- [x] 6.6 race_id を架空の値にしたセーブをロード → 該当キャラクターがスキップされ、他のキャラクターは復元されることを確認

## 7. 仕上げ

- [x] 7.1 `openspec validate harden-save-load-error-handling --strict` で仕様妥当性を確認
- [x] 7.2 すべてのテスト・目視確認が通ったらコミット
- [x] 7.3 `/opsx:verify harden-save-load-error-handling` で実装と仕様の整合性確認
- [x] 7.4 `/opsx:archive harden-save-load-error-handling` でアーカイブ
