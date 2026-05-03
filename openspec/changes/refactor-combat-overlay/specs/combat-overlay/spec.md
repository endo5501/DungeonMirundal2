## ADDED Requirements

### Requirement: CombatOverlay は BattleResolver で報酬を計算する
SHALL: `CombatOverlay._finalize_battle` は経験値・ゴールド・レベルアップの計算を直接行わず、`BattleResolver.resolve_rewards(_turn_engine, _rng)` を呼び出して `BattleSummary` を取得する。`show_result(outcome, summary)` は summary をそのまま `_result_panel.show_result` に渡す。`_compute_gold_drop`, `_collect_participant_characters`, `_collect_dead_monsters` メソッドは CombatOverlay から削除され、BattleResolver の private 関数として実装される。

#### Scenario: CombatOverlay が BattleResolver を呼ぶ
- **WHEN** 戦闘終了(CLEARED)時に `_finalize_battle` が呼ばれる
- **THEN** `BattleResolver.resolve_rewards(_turn_engine, _rng)` が 1 回呼ばれ、その返却値で `show_result` が呼ばれる

#### Scenario: 旧報酬計算メソッドは存在しない
- **WHEN** `combat_overlay.gd` を grep する
- **THEN** `_compute_gold_drop`, `_collect_participant_characters`, `_collect_dead_monsters` メソッドは存在しない

### Requirement: CombatOverlay は CombatInputRouter で phase 入力をルーティングする
SHALL: `CombatOverlay._unhandled_input` は phase ごとの入力処理を `CombatInputRouter.route(event, _current_phase, _panels)` 1 呼び出しに集約する。旧 `_handle_command_menu_key`, `_handle_target_select_key`, `_handle_item_select_key`, `_handle_result_key` の 4 メソッドは削除される。

#### Scenario: 旧 per-phase ハンドラは存在しない
- **WHEN** `combat_overlay.gd` を grep する
- **THEN** `_handle_command_menu_key`, `_handle_target_select_key`, `_handle_item_select_key`, `_handle_result_key` は存在しない

#### Scenario: phase に応じて適切な panel に input が届く
- **WHEN** COMMAND_MENU phase で ui_down がディスパッチされる
- **THEN** CombatInputRouter 経由で command_menu の cursor が下に移動する

### Requirement: CombatOverlay はアイテム使用に ItemUseFlow を使う
SHALL: アイテム使用は `ItemUseFlow` (C6 で抽出) を `_item_use_flow` フィールドとして保持し、コマンドメニューで「アイテム」が選ばれたら `_show_item_use_flow()` で起動する。`flow_completed` シグナルで戻りを受け、空メッセージならコマンドメニューに戻り、メッセージありなら `_advance_to_next_actor` を呼ぶ。旧 `_open_item_selector`, `_on_item_selector_item_selected`, `_valid_item_targets`, `_commit_item_command`, `_pending_item_instance` は削除される。

#### Scenario: アイテムコマンドで ItemUseFlow が表示される
- **WHEN** COMMAND_MENU phase でアイテムコマンドが選ばれる
- **THEN** `_item_use_flow.setup(ctx_in_combat_true, inventory, party_chars)` が呼ばれ、`_item_use_flow.visible = true` になる

#### Scenario: ItemUseFlow キャンセルでコマンドメニューに戻る
- **WHEN** ItemUseFlow が `flow_completed("")` を発行
- **THEN** ItemUseFlow が hidden になり、`_current_phase = Phase.COMMAND_MENU` で command_menu が再表示される

#### Scenario: ItemUseFlow 完了で次アクターに進む
- **WHEN** ItemUseFlow が `flow_completed("回復した！")` のような結果メッセージを発行
- **THEN** ItemUseFlow が hidden になり、`_advance_to_next_actor` が呼ばれる

### Requirement: CombatOverlay の戦闘ログ再生はキャンセル可能である
SHALL: `_play_log_sequentially` は `await get_tree().create_timer(...)` を使わず、`Timer` ノードベースの実装で 1 行ずつログを再生する。`encounter_resolved` 発行時や `_is_active = false` のとき、ペンディングのログ再生を `cancel_log_playback()` で安全に停止できること。

#### Scenario: ログ再生中にオーバーレイが非アクティブになると停止する
- **WHEN** `_play_log_sequentially` 実行中に `_is_active = false` がセットされ `cancel_log_playback()` が呼ばれる
- **THEN** Timer が停止し、ペンディングのログ行は再生されない

#### Scenario: ログ再生は Timer ノードで実装される
- **WHEN** `combat_overlay.gd` を grep する
- **THEN** `await get_tree().create_timer` は `_play_log_sequentially` 内に存在しない
