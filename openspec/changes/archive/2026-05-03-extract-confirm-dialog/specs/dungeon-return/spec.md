## ADDED Requirements

### Requirement: ダンジョン帰還ダイアログは ConfirmDialog で構築される
SHALL: ダンジョンスクリーンで START タイル上で起動される帰還確認ダイアログは、`ConfirmDialog` の子インスタンスを利用して構築される。`DungeonScreen` 内でインライン実装する `_build_return_dialog` のような per-screen UI 構築コードは存在しない。`DungeonScreen` は `_return_dialog: ConfirmDialog` フィールドを保持し、`_show_return_dialog()` で `setup("町に戻りますか？", default_index)` を呼ぶ。

#### Scenario: 帰還ダイアログ表示時に ConfirmDialog が使われる
- **WHEN** プレイヤーが START タイル上で `check_start_tile_return()` をトリガする
- **THEN** `_return_dialog.setup("町に戻りますか？", ...)` が呼ばれ、ConfirmDialog が visible になる

#### Scenario: 「はい」確定で町に戻る
- **WHEN** ConfirmDialog が `confirmed` シグナルを発行
- **THEN** ダンジョンスクリーンが町画面に遷移する

#### Scenario: 「いいえ」または ESC でダイアログが閉じてダンジョンに残る
- **WHEN** ConfirmDialog が `cancelled` シグナルを発行
- **THEN** ダイアログが閉じ、ダンジョンスクリーンに残る(プレイヤーは START タイル上のまま)
