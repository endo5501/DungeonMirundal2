## ADDED Requirements

### Requirement: main.gd のトップレベル ESC は ui_cancel action で処理される
SHALL: `Main._unhandled_input` のトップレベル ESC 処理は `is_action_pressed("ui_cancel")` で行う。`event is InputEventKey and event.keycode == KEY_ESCAPE` の組み合わせを使ってはならない。

#### Scenario: ui_cancel が ESCメニューを開く
- **WHEN** 町画面/ダンジョン画面/ギルド画面表示中(タイトル画面以外、子画面が ESC を消費していない状態)で `is_action_pressed("ui_cancel")` がディスパッチされる
- **THEN** ESCメニューがオーバーレイ表示される

#### Scenario: 子画面が消費した ui_cancel は ESCメニューを開かない
- **WHEN** ダンジョン画面の帰還ダイアログが ui_cancel を `set_input_as_handled` で消費する
- **THEN** main.gd の `_unhandled_input` には届かず、ESCメニューは開かない

#### Scenario: タイトル画面では ui_cancel を無視する
- **WHEN** タイトル画面表示中に `is_action_pressed("ui_cancel")` がディスパッチされる
- **THEN** ESCメニューは開かない(タイトル画面の判定で early return する)
