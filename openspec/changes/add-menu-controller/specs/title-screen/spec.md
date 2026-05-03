## ADDED Requirements

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
