## MODIFIED Requirements

### Requirement: メニュー表示中はゲーム入力を遮断する
SHALL: ESC メニュー表示中は背面画面（DungeonScreen 等）への入力を遮断する。実装手段として、`EscMenu._unhandled_input` は `visible == true` のとき、自身が解釈する `ui_*` action を処理した後（処理対象外のイベントであっても）必ず `get_viewport().set_input_as_handled()` を呼び、Godot の unhandled-input 伝播チェーンを断ち切る。これにより `move_forward`/`move_back`/`strafe_left`/`strafe_right`/`turn_left`/`turn_right`/`toggle_full_map` などのゲームワールド操作 action は EscMenu によって消費され、DungeonScreen の `_unhandled_input` には届かない。サブフロー (`ItemUseFlow`/`EquipmentFlow`/`SpellUseFlow`) が visible のときの early return 規約は維持され、サブフロー自身が `_unhandled_input` 内で `set_input_as_handled()` を呼ぶ。

#### Scenario: メニュー表示中に移動キーを押す
- **WHEN** ダンジョン画面で ESC メニューが表示されている状態で `move_forward` action を発火する
- **THEN** プレイヤーキャラクターは移動せず、`PlayerState.position` は変化しない

#### Scenario: メニュー表示中に全体マップキーを押す
- **WHEN** ダンジョン画面で ESC メニューが表示されている状態で `toggle_full_map` action を発火する
- **THEN** 全体マップオーバーレイは開閉せず、状態が変わらない

#### Scenario: メニューを閉じた後は操作可能
- **WHEN** ESCメニューを閉じてゲーム画面に復帰する
- **THEN** 通常の入力操作が復帰する（`move_forward` でプレイヤーが前進する）

#### Scenario: サブフロー表示中はサブフローが入力を握る
- **WHEN** ESC メニューの ItemUseFlow が visible である状態で任意の InputEvent が発火する
- **THEN** ItemUseFlow がイベントを処理し、`EscMenu._unhandled_input` は early return する（既存挙動）
