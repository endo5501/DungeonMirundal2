## ADDED Requirements

### Requirement: SaveScreen は MenuController + action ベースで入力を受ける
SHALL: `SaveScreen._unhandled_input` は `MenuController.route(event, _menu, _menu_rows, _on_slot_selected, back_requested.emit)` を介して ui_up / ui_down / ui_accept / ui_cancel を処理する。`event.keycode == KEY_*` の直接マッチは使わない。上書き確認ダイアログ表示中の入力は別ハンドラ `_handle_overwrite_input(event)` に委譲し、こちらも action ベースで実装する(C9 で ConfirmDialog に抽出予定)。

#### Scenario: ui_down でセーブスロット一覧のカーソルが進む
- **WHEN** セーブ画面が表示されている状態で `is_action_pressed("ui_down")` がディスパッチされる
- **THEN** セーブスロット一覧のカーソルが次のスロットに移動する

#### Scenario: ui_accept で選択スロットへの保存が開始される
- **WHEN** セーブ画面で「新規保存」を選択している状態で `is_action_pressed("ui_accept")` がディスパッチされる
- **THEN** `_on_slot_selected()` が呼ばれ、保存処理または上書き確認ダイアログ表示が始まる

#### Scenario: ui_cancel でセーブ画面が閉じる
- **WHEN** セーブ画面(上書き確認ダイアログ非表示)で `is_action_pressed("ui_cancel")` がディスパッチされる
- **THEN** `back_requested` シグナルが発行される

#### Scenario: 上書き確認ダイアログ表示中の入力は別ハンドラに委譲される
- **WHEN** 上書き確認ダイアログが表示中で何らかの action input が来る
- **THEN** `_handle_overwrite_input(event)` がそれを処理し、メインメニュー側のルーティングはスキップされる
