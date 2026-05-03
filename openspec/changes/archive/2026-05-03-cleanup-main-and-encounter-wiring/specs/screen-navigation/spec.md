## ADDED Requirements

### Requirement: main.gd の ESCメニュー開閉判定は単一メソッドに集約される
SHALL: `Main._unhandled_input` でトップレベル ESC を受け取ったとき、ESCメニューを開くべきかの判定は `_should_open_esc_menu() -> bool` という 1 つのプライベートメソッドに集約される。判定条件(タイトル画面でないこと、ESCメニューが既に開いていないこと、エンカウンタ中でないこと、その他の input gate)はこのメソッド内で順に評価される。

#### Scenario: タイトル画面では ESC メニューを開かない
- **WHEN** `_current_screen is TitleScreen` の状態で ui_cancel がディスパッチされる
- **THEN** `_should_open_esc_menu()` が `false` を返し、ESCメニューは開かない

#### Scenario: ESCメニュー表示中は再度開かない
- **WHEN** `_esc_menu.is_menu_visible() == true` の状態で ui_cancel がディスパッチされる
- **THEN** `_should_open_esc_menu()` が `false` を返す(ESCメニュー側が input を消費する想定)

#### Scenario: エンカウンタ中は ESCメニューを開かない
- **WHEN** `_encounter_coordinator.is_encounter_active() == true` の状態で ui_cancel がディスパッチされる
- **THEN** `_should_open_esc_menu()` が `false` を返す

#### Scenario: 全てのゲートが open なら ESCメニューが開く
- **WHEN** タイトル外、ESCメニュー非表示、エンカウンタ非アクティブの状態で ui_cancel がディスパッチされる
- **THEN** `_should_open_esc_menu()` が `true` を返し、`_esc_menu.show_menu()` が呼ばれる

### Requirement: combat_overlay の依存配線は 1 度だけ行われる
SHALL: `_combat_overlay.setup_dependencies(guild, equipment_provider, rng)` の呼び出しは、`new_game()` 完了後または `_load_game()` 完了後の guild が確定するタイミングで 1 度だけ行われる。`_attach_encounter_coordinator_to_screen` の呼び出しごとに依存配線を refresh する `_refresh_combat_overlay_dependencies` メソッドは存在しない。

#### Scenario: 依存配線は guild 確定タイミングで 1 度だけ
- **WHEN** `_on_start_new_game` または `_load_game` が完了する
- **THEN** `_combat_overlay.setup_dependencies(...)` が 1 回呼ばれる

#### Scenario: ダンジョン入場のたびに依存配線は走らない
- **WHEN** `_attach_encounter_coordinator_to_screen` が呼ばれる
- **THEN** `_combat_overlay.setup_dependencies` は呼ばれない(_setup 時または new_game 時の値が引き続き使われる)

#### Scenario: 旧 _refresh_combat_overlay_dependencies は存在しない
- **WHEN** `main.gd` を grep
- **THEN** `_refresh_combat_overlay_dependencies` メソッドは存在しない
