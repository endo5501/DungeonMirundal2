## ADDED Requirements

### Requirement: ダンジョン削除確認ダイアログは ConfirmDialog で構築される
SHALL: ダンジョン入口画面で「削除」を選択した時の確認ダイアログは、`ConfirmDialog` の子インスタンスを利用して構築される。`DungeonEntrance` 内でインライン実装する確認 UI コードは存在しない。

#### Scenario: 削除確認ダイアログ表示時に ConfirmDialog が使われる
- **WHEN** ダンジョン入口で削除アクションがトリガされる
- **THEN** `_delete_dialog.setup("削除しますか？", 1)` が呼ばれ、ConfirmDialog が visible になる

#### Scenario: 「はい」確定でダンジョンが削除される
- **WHEN** ConfirmDialog が `confirmed` シグナルを発行
- **THEN** 対応するダンジョンが `DungeonRegistry` から削除される

#### Scenario: 「いいえ」または ESC で削除がキャンセルされる
- **WHEN** ConfirmDialog が `cancelled` シグナルを発行
- **THEN** ダイアログが閉じ、ダンジョンは削除されずに入口画面に戻る
