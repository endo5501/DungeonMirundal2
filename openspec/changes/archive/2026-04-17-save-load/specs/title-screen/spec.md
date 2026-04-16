## MODIFIED Requirements

### Requirement: Continue and Load are conditionally enabled
"前回から" SHALL be enabled when SaveManager.get_last_slot() returns a valid slot number (>= 0). "ロード" SHALL be enabled when SaveManager.has_saves() returns true. When disabled, they SHALL be visually grayed out and not selectable.

#### Scenario: セーブデータが存在する場合
- **WHEN** タイトル画面を表示し、セーブファイルが存在する
- **THEN** 「前回から」と「ロード」が有効状態で表示される

#### Scenario: セーブデータが存在しない場合
- **WHEN** タイトル画面を表示し、セーブファイルが存在しない
- **THEN** 「前回から」と「ロード」がdisabled状態（グレー）で表示される

#### Scenario: last_slotが無効な場合
- **WHEN** タイトル画面を表示し、last_slot.txtが無効（ファイル削除済み等）だがセーブファイルは存在する
- **THEN** 「前回から」はdisabled、「ロード」は有効で表示される

## ADDED Requirements

### Requirement: 「前回から」は最後のセーブデータをロードする
TitleScreen SHALL emit a `continue_game` signal when "前回から" is selected. main.gd SHALL load the save file indicated by SaveManager.get_last_slot().

#### Scenario: 前回からを選択
- **WHEN** 「前回から」を選択する
- **THEN** continue_gameシグナルが発行され、最後のセーブデータがロードされる

### Requirement: 「ロード」はロード画面を表示する
TitleScreen SHALL emit a `load_game` signal when "ロード" is selected. main.gd SHALL display the load screen.

#### Scenario: ロードを選択
- **WHEN** 「ロード」を選択する
- **THEN** load_gameシグナルが発行され、ロード画面が表示される
