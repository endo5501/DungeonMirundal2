## ADDED Requirements

### Requirement: ESCメニューの終了確認は ConfirmDialog で構築される
SHALL: ESCメニューで「終了」を選択した時の確認ダイアログは、`ConfirmDialog` の子インスタンスを利用して構築される。`EscMenu` 内でインライン実装する終了確認 UI コードは存在しない。

#### Scenario: 終了確認ダイアログ表示時に ConfirmDialog が使われる
- **WHEN** ユーザが ESC メニューで「終了」を選択
- **THEN** `_quit_dialog.setup("ゲームを終了しますか？", 1)` が呼ばれ、ConfirmDialog が visible になる

#### Scenario: 「はい」確定でタイトル画面に戻る
- **WHEN** ConfirmDialog が `confirmed` シグナルを発行
- **THEN** `quit_to_title` シグナルが発行される

#### Scenario: 「いいえ」または ESC で終了がキャンセルされる
- **WHEN** ConfirmDialog が `cancelled` シグナルを発行
- **THEN** ダイアログが閉じ、ESCメニューのメインに戻る
