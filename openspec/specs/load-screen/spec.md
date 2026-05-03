## Purpose
ロード画面のスロット一覧表示とセーブデータ読込処理を規定する。スロットのメタデータ（日時・場所・代表キャラ名）表示とキャンセル遷移を対象とする。

## Requirements

### Requirement: ロード画面はスロット一覧を表示する
ロード画面 SHALL SaveManagerからセーブファイル一覧を取得し、各スロットのメタ情報を一覧表示する。

#### Scenario: セーブファイルが存在する場合の一覧表示
- **WHEN** ロード画面を開き、セーブファイルが3件存在する
- **THEN** 3件のスロット情報が一覧表示される

#### Scenario: セーブファイルが存在しない場合
- **WHEN** ロード画面を開き、セーブファイルが0件の場合
- **THEN** 「セーブデータがありません」と表示される

### Requirement: スロット情報の表示内容
各スロット SHALL display: スロット番号、保存日時、パーティ名、パーティ最大レベル、現在地（「町」またはダンジョン名+探索率）。表示形式はセーブ画面と同一。

#### Scenario: スロット情報の表示
- **WHEN** ロード画面にスロットが表示される
- **THEN** スロット番号、保存日時、パーティ名、最大レベル、現在地が表示される

### Requirement: スロットを選択するとロードを実行する
SHALL: スロットを選択すると、load_requestedシグナルをスロット番号とともに発行する。

#### Scenario: スロットを選択してロード
- **WHEN** スロットを選択してEnterキーを押す
- **THEN** load_requested(slot_number)シグナルが発行される

### Requirement: ロード画面からの戻る操作
SHALL: ESCキーでロード画面を閉じ、呼び出し元に戻る。

#### Scenario: ESCキーで閉じる
- **WHEN** ロード画面でESCキーを押す
- **THEN** ロード画面が閉じ、back_requestedシグナルが発行される

### Requirement: ロード画面はESCメニューとタイトル画面の両方から利用可能
SHALL: ロード画面は独立した画面クラスとして実装し、ESCメニューのサブビューとしてもタイトル画面からの遷移先としても利用できる。

#### Scenario: ESCメニューからロード画面を開く
- **WHEN** ESCメニューの「ゲームをロード」を選択する
- **THEN** ロード画面が表示される

#### Scenario: タイトル画面からロード画面を開く
- **WHEN** タイトル画面の「ロード」を選択する
- **THEN** ロード画面が表示される

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
