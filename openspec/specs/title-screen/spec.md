## Purpose
タイトル画面のメニュー項目・初期カーソル・セーブ有無に応じた活性制御を規定する。新規ゲーム／前回から／ロード／ゲーム終了の各項目とキーナビゲーションを対象とする。
## Requirements
### Requirement: Title screen displays menu options
TitleScreen SHALL display a text-based menu with 4 options in this order: "前回から", "新規ゲーム", "ロード", "ゲーム終了".

#### Scenario: All options are displayed
- **WHEN** the title screen is shown
- **THEN** all 4 menu options SHALL be displayed in the order "前回から", "新規ゲーム", "ロード", "ゲーム終了"

### Requirement: Title screen has cursor selection
TitleScreen SHALL provide keyboard-based cursor navigation. Up/Down arrow keys SHALL move the cursor between options. Enter/Space SHALL select the current option. The initial cursor position SHALL be on the first enabled option, determined after `setup_save_state()` has applied the disabled state.

#### Scenario: Cursor starts on 前回から when save exists and last_slot is valid
- **WHEN** the title screen is shown and SaveManager has a valid last_slot
- **THEN** the cursor SHALL be on "前回から"

#### Scenario: Cursor skips to 新規ゲーム when no save exists
- **WHEN** the title screen is shown and SaveManager has no saves
- **THEN** "前回から" and "ロード" SHALL be disabled and the cursor SHALL be on "新規ゲーム"

#### Scenario: Cursor skips to 新規ゲーム when last_slot is invalid but saves exist
- **WHEN** the title screen is shown and SaveManager has saves but last_slot is invalid
- **THEN** "前回から" SHALL be disabled and the cursor SHALL be on "新規ゲーム"

#### Scenario: Cursor moves down
- **WHEN** the cursor is on "前回から" and the Down key is pressed
- **THEN** the cursor SHALL move to "新規ゲーム"

#### Scenario: Cursor wraps around
- **WHEN** the cursor is on "ゲーム終了" and the Down key is pressed
- **THEN** the cursor SHALL wrap to "前回から" (or skip to the next enabled option if "前回から" is disabled)

### Requirement: New game starts a fresh game
TitleScreen SHALL emit a `start_new_game` signal when "新規ゲーム" is selected.

#### Scenario: Select new game
- **WHEN** the user selects "新規ゲーム"
- **THEN** the `start_new_game` signal SHALL be emitted

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

### Requirement: Quit game exits the application
TitleScreen SHALL call `get_tree().quit()` when "ゲーム終了" is selected.

#### Scenario: Select quit
- **WHEN** the user selects "ゲーム終了"
- **THEN** the application SHALL exit

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

### Requirement: タイトル画面はESCキーを明示的に無視する
SHALL: `TitleScreen._unhandled_input` で ESC キー(`ui_cancel` action)を受け取った際、戻る先がないため何も実行しない。ただし「忘れた」のではなく「意図的に無視」していることをコード上明示する(`MenuController.route` に `on_back` を渡さないことで `route` が `false` を返し、`set_input_as_handled` も呼ばれない)。

#### Scenario: ESC押下でもタイトル画面の状態は変わらない
- **WHEN** タイトル画面表示中に ESC キーを押す
- **THEN** タイトル画面はそのまま表示を維持し、いずれのシグナル(start_new_game / continue_game / load_game / quit_game)も発行されない

#### Scenario: ESC押下のイベントは消費されない
- **WHEN** タイトル画面で ESC キーを押す
- **THEN** `set_input_as_handled` は呼ばれず、上位層がもしあれば ESC を受け取れる(現状は上位層なし)

### Requirement: タイトル画面はMenuControllerでメニュー入力をルーティングする
SHALL: `TitleScreen._unhandled_input` は `MenuController.route(event, _menu, _rows, confirm_selection)` を介して ui_up / ui_down / ui_accept をルーティングする。同等のボイラープレートを直接書いてはならない。

#### Scenario: ui_down でカーソルが下方向に移動する
- **WHEN** タイトル画面で ui_down(KEY_DOWN/KEY_S/joystick down のいずれか)を押す
- **THEN** `_menu.selected_index` が次の有効項目に進み、行のカーソル表示が更新される

#### Scenario: ui_accept で選択項目が確定する
- **WHEN** タイトル画面で ui_accept(KEY_ENTER/KEY_SPACE)を押す
- **THEN** `confirm_selection()` が呼ばれ、選択項目に対応するシグナルが発行される

