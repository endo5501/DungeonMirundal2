## ADDED Requirements

### Requirement: ESCメニューはaction ベースで入力を受ける
SHALL: `EscMenu._unhandled_input` は ui_* action(`ui_up`, `ui_down`, `ui_accept`, `ui_cancel`)を介してメニュー操作を受け取る。`event.keycode == KEY_*` の直接マッチを使ってはならない。本要件は MenuController 採用そのもの(C6 で実施)とは独立で、入力規約のみを規定する。

#### Scenario: ui_down action でカーソルが下に移動する
- **WHEN** ESCメニューが開いている状態で `is_action_pressed("ui_down")` がディスパッチされる
- **THEN** メニュー上のカーソルが次の有効項目へ進む

#### Scenario: ui_cancel action でメニューが閉じる(またはサブメニューから戻る)
- **WHEN** ESCメニューが開いている状態で `is_action_pressed("ui_cancel")` がディスパッチされる
- **THEN** メニューが閉じる(メインメニューの場合)、またはサブメニューからメインに戻る

#### Scenario: ui_accept action で選択項目が確定する
- **WHEN** ESCメニューが開いている状態で `is_action_pressed("ui_accept")` がディスパッチされる
- **THEN** 選択中の項目が確定し、対応する遷移が起きる
