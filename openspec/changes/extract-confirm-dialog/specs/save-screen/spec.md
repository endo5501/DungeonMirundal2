## ADDED Requirements

### Requirement: セーブ画面の上書き確認は ConfirmDialog で構築される
SHALL: セーブ画面で既存スロットを選択した時の上書き確認ダイアログは、`ConfirmDialog` の子インスタンスを利用して構築される。`SaveScreen` 内でインライン実装する `_build_overwrite_dialog` / `_handle_overwrite_input` のコードは存在しない。

#### Scenario: 上書き確認ダイアログ表示時に ConfirmDialog が使われる
- **WHEN** ユーザが既存スロットを選択する
- **THEN** `_overwrite_dialog.setup("上書きしますか？", 1)` が呼ばれ、ConfirmDialog が visible になる

#### Scenario: 「はい」確定で上書き保存される
- **WHEN** ConfirmDialog が `confirmed` シグナルを発行
- **THEN** `SaveManager.save(slot_number)` が呼ばれ、`save_completed` シグナルが発行される

#### Scenario: 「いいえ」または ESC で上書きがキャンセルされる
- **WHEN** ConfirmDialog が `cancelled` シグナルを発行
- **THEN** ダイアログが閉じ、保存は行われず、スロット一覧に戻る
