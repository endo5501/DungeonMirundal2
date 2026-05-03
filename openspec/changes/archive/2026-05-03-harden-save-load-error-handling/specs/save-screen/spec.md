## ADDED Requirements

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
