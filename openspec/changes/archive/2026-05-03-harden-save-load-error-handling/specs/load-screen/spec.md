## ADDED Requirements

### Requirement: ロード画面はロード失敗事由をユーザに通知する
LoadScreen SHALL provide a `show_load_failure(result: SaveManager.LoadResult)` method (or equivalent signal-based mechanism) that displays a status label with a reason-specific message when `main._load_game` reports a load failure. The screen SHALL remain open (it SHALL NOT auto-dismiss) so the user can read the message and choose another slot or cancel.

#### Scenario: ファイル欠損時のメッセージ
- **WHEN** `_load_game` が `LoadResult.FILE_NOT_FOUND` でロードに失敗する
- **THEN** LoadScreen のステータスラベルに「セーブファイルが見つかりません」と表示される

#### Scenario: 破損 JSON のメッセージ
- **WHEN** `_load_game` が `LoadResult.PARSE_ERROR` でロードに失敗する
- **THEN** ステータスラベルに「セーブデータが破損しています」と表示される

#### Scenario: バージョン未来のメッセージ
- **WHEN** `_load_game` が `LoadResult.VERSION_TOO_NEW` でロードに失敗する
- **THEN** ステータスラベルに「未対応のセーブデータです(新しいバージョン)」と表示される

#### Scenario: 復元失敗のメッセージ
- **WHEN** `_load_game` が `LoadResult.RESTORE_FAILED` でロードに失敗する
- **THEN** ステータスラベルに「ロードに失敗しました」と表示される

#### Scenario: 失敗後も画面に留まり別スロット選択可能
- **WHEN** ロードに失敗し、ステータスラベルが表示されている状態でユーザが別スロットを選択する
- **THEN** ロードが再試行され、成功すれば通常通り遷移、失敗すればステータスラベルが新しいメッセージで更新される
