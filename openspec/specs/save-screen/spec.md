## Purpose
セーブ画面のスロット一覧表示と上書き確認フローを規定する。空スロット／既存スロットの視覚表現、上書き時のはい／いいえ確認ダイアログを対象とする。

## Requirements

### Requirement: セーブ画面はスロット一覧を表示する
セーブ画面 SHALL SaveManagerからセーブファイル一覧を取得し、各スロットのメタ情報を一覧表示する。一覧の先頭には「新規保存」項目を表示する。

#### Scenario: セーブファイルが存在する場合の一覧表示
- **WHEN** セーブ画面を開き、セーブファイルが3件存在する
- **THEN** 「新規保存」と3件のスロット情報が一覧表示される

#### Scenario: セーブファイルが存在しない場合
- **WHEN** セーブ画面を開き、セーブファイルが0件の場合
- **THEN** 「新規保存」のみが表示される

### Requirement: スロット情報の表示内容
各スロット SHALL display: スロット番号、保存日時、パーティ名、パーティ最大レベル、現在地（「町」またはダンジョン名+探索率）。

#### Scenario: 町でセーブしたスロットの表示
- **WHEN** game_location="town"のセーブスロットが表示される
- **THEN** 現在地に「町」と表示される

#### Scenario: ダンジョンでセーブしたスロットの表示
- **WHEN** game_location="dungeon"、ダンジョン名="暗黒の迷宮"、探索率=32%のセーブスロットが表示される
- **THEN** 現在地に「暗黒の迷宮 32%」と表示される

### Requirement: 新規保存を選択すると新しいスロットに保存する
SHALL: 「新規保存」を選択すると、次の連番スロットにゲーム状態を保存する。

#### Scenario: 新規保存の実行
- **WHEN** 「新規保存」を選択する
- **THEN** SaveManager.get_next_slot_number()で取得した番号のスロットに保存され、save_completedシグナルが発行される

### Requirement: 既存スロットを選択すると上書き確認を表示する
SHALL: 既存のスロットを選択した場合、上書き確認ダイアログを表示する。

#### Scenario: 上書き確認ダイアログ
- **WHEN** 既存のセーブスロットを選択する
- **THEN** 「上書きしますか？」と「はい」「いいえ」の確認ダイアログが表示される

#### Scenario: 上書きを承認
- **WHEN** 上書き確認ダイアログで「はい」を選択する
- **THEN** そのスロット番号に現在のゲーム状態が保存され、save_completedシグナルが発行される

#### Scenario: 上書きをキャンセル
- **WHEN** 上書き確認ダイアログで「いいえ」を選択する
- **THEN** 確認ダイアログが閉じ、スロット一覧に戻る

### Requirement: セーブ画面からの戻る操作
SHALL: ESCキーでセーブ画面を閉じ、呼び出し元に戻る。

#### Scenario: ESCキーで閉じる
- **WHEN** セーブ画面でESCキーを押す
- **THEN** セーブ画面が閉じ、back_requestedシグナルが発行される

### Requirement: セーブ画面は保存失敗をユーザに通知する
SaveScreen SHALL inspect the boolean return value of `SaveManager.save(slot_number)` and SHALL display a status label with an error message when the save fails. The status label SHALL be cleared (or hidden) on success. The `save_completed` signal SHALL be emitted ONLY when `SaveManager.save` returns `true`.

#### Scenario: 保存成功時にsave_completedが発行される
- **WHEN** ユーザが新規スロットを選択し `SaveManager.save(slot)` が `true` を返す
- **THEN** `save_completed` シグナルが発行され、ステータスラベルが空(または非表示)である

#### Scenario: 保存失敗時にエラーラベルが表示される
- **WHEN** ユーザが新規スロットを選択し `SaveManager.save(slot)` が `false` を返す
- **THEN** `save_completed` は発行されず、ステータスラベルに「保存に失敗しました」と表示される

#### Scenario: 上書き保存失敗時にもエラーラベルが表示される
- **WHEN** ユーザが上書き確認で「はい」を選択し `SaveManager.save(slot)` が `false` を返す
- **THEN** 上書きダイアログは閉じるが、ステータスラベルにエラーメッセージが表示され `save_completed` は発行されない

#### Scenario: 失敗後の再試行で成功した場合はラベルがクリアされる
- **WHEN** 一度保存に失敗してエラーラベルが表示された状態で、別スロットを選択して保存が成功する
- **THEN** ステータスラベルがクリアされ、`save_completed` が発行される
