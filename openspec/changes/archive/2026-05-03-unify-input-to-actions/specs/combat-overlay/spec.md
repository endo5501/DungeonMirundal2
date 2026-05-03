## ADDED Requirements

### Requirement: CombatOverlay はaction ベースで入力を受ける
SHALL: `CombatOverlay._unhandled_input` は ui_* action(`ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_accept`, `ui_cancel`)を介してメニュー操作・コマンド選択を処理する。`event.keycode == KEY_*` の直接マッチを使ってはならない。各 phase ごとの入力ルーティング詳細は C7 (refactor-combat-overlay) のスコープであり、本要件では入力規約のみを規定する。

#### Scenario: コマンド選択 phase で ui_down がカーソルを動かす
- **WHEN** combat overlay がコマンド選択 phase で `is_action_pressed("ui_down")` がディスパッチされる
- **THEN** コマンドメニューのカーソルが次の項目に移動する

#### Scenario: ui_accept でコマンドが確定する
- **WHEN** combat overlay の任意の選択 phase で `is_action_pressed("ui_accept")` がディスパッチされる
- **THEN** 現在のカーソル選択が確定し、次の phase に進む

#### Scenario: ui_cancel で前 phase に戻る
- **WHEN** combat overlay のターゲット選択 phase などサブ選択 phase で `is_action_pressed("ui_cancel")` がディスパッチされる
- **THEN** 1 つ前の phase(コマンド選択)に戻る
