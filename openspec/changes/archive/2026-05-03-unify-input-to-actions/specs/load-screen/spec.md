## ADDED Requirements

### Requirement: LoadScreen は MenuController + action ベースで入力を受ける
SHALL: `LoadScreen._unhandled_input` は `MenuController.route(event, _menu, _menu_rows, _on_slot_chosen, back_requested.emit)` を介して ui_up / ui_down / ui_accept / ui_cancel を処理する。`event.keycode == KEY_*` の直接マッチは使わない。「セーブデータがありません」表示時は ui_cancel のみを受け付け、その他の action は無視する。

#### Scenario: ui_down でロードスロット一覧のカーソルが進む
- **WHEN** ロード画面でスロットが 1 件以上ある状態で `is_action_pressed("ui_down")` がディスパッチされる
- **THEN** ロードスロット一覧のカーソルが次のスロットに移動する

#### Scenario: ui_accept で選択スロットのロードが開始される
- **WHEN** ロード画面で `is_action_pressed("ui_accept")` がディスパッチされる
- **THEN** `load_requested(slot_number)` シグナルが発行される

#### Scenario: ui_cancel でロード画面が閉じる
- **WHEN** ロード画面で `is_action_pressed("ui_cancel")` がディスパッチされる
- **THEN** `back_requested` シグナルが発行される

#### Scenario: セーブ無し状態では ui_cancel のみ受け付ける
- **WHEN** 「セーブデータがありません」表示中で `is_action_pressed("ui_down")` がディスパッチされる
- **THEN** 何も起きない(カーソル移動できる対象がない)

#### Scenario: セーブ無し状態の ui_cancel
- **WHEN** 「セーブデータがありません」表示中で `is_action_pressed("ui_cancel")` がディスパッチされる
- **THEN** `back_requested` シグナルが発行される
