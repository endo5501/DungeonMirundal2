## 1. BattleSummary 値オブジェクト追加 (TDD)

- [ ] 1.1 `tests/combat/test_battle_summary.gd` を作成、`BattleSummary.new(exp, gold, level_ups)` の値保持テスト
- [ ] 1.2 `BattleSummary.empty()` が 0/0/[] を返すテスト
- [ ] 1.3 テスト Red コミット
- [ ] 1.4 `src/combat/battle_summary.gd` を実装
- [ ] 1.5 テスト Green コミット

## 2. BattleResolver の追加 (TDD)

- [ ] 2.1 `tests/combat/test_battle_resolver.gd` を作成、CLEARED outcome での経験値計算テスト
- [ ] 2.2 ゴールド drop の min/max 範囲テスト(rng を seed 付きで)
- [ ] 2.3 レベルアップ検出テスト(participants の level が上がった場合のみ level_ups に含まれる)
- [ ] 2.4 ESCAPED / DEFEATED で empty() が返るテスト
- [ ] 2.5 テスト Red コミット
- [ ] 2.6 `src/combat/battle_resolver.gd` を実装、`resolve_rewards` static 関数、`_collect_participant_characters` / `_collect_dead_monsters` / `_compute_gold_drop` / `_detect_level_ups` を private 関数として
- [ ] 2.7 テスト Green コミット

## 3. CombatOverlay から BattleResolver 利用への置換 (TDD)

- [ ] 3.1 既存 `tests/combat/test_combat_overlay.gd` のうち、戦闘終了時の経験値・ゴールド assert が BattleResolver 経由でも通ることを確認
- [ ] 3.2 `src/dungeon_scene/combat_overlay.gd:_finalize_battle` を BattleResolver.resolve_rewards 呼び出しに置換
- [ ] 3.3 `show_result(outcome, level_ups)` を `show_result(outcome, summary: BattleSummary)` に変更、result_panel への引数も更新
- [ ] 3.4 `_compute_gold_drop`, `_collect_participant_characters`, `_collect_dead_monsters` を CombatOverlay から削除
- [ ] 3.5 既存テスト全通過を確認しコミット

## 4. CombatInputRouter の追加 (TDD)

- [ ] 4.1 `tests/combat/test_combat_input_router.gd` を作成、各 phase で適切な panel に input が届くテスト
- [ ] 4.2 ITEM_SELECT / IDLE / RESOLVING で false が返るテスト
- [ ] 4.3 テスト Red コミット
- [ ] 4.4 `src/combat/combat_input_router.gd` を実装
- [ ] 4.5 テスト Green コミット

## 5. CombatOverlay の per-phase ハンドラ撤廃 (TDD)

- [ ] 5.1 既存テストが MenuController/InputRouter 経由でも通ることを確認
- [ ] 5.2 `combat_overlay.gd:_unhandled_input` を `CombatInputRouter.route(event, _current_phase, _panels_dict())` 形に書き換え
- [ ] 5.3 旧 `_handle_command_menu_key`, `_handle_target_select_key`, `_handle_item_select_key`, `_handle_result_key` を削除
- [ ] 5.4 全テスト通過を確認しコミット

## 6. ItemUseFlow を CombatOverlay で利用 (TDD)

- [ ] 6.1 `tests/combat/test_combat_overlay.gd` に「アイテムコマンド → ItemUseFlow が visible」「flow_completed("") でコマンドメニュー復帰」「flow_completed("...") で advance_to_next_actor」テストを追加
- [ ] 6.2 テスト Red 確認(現実装は CombatItemSelector を使っている)
- [ ] 6.3 `combat_overlay.gd` の `_build_combat_ui` で `_item_use_flow = ItemUseFlow.new()` を生成・add_child
- [ ] 6.4 `_show_item_use_flow()` メソッドを追加、コマンドメニューで OPT_ITEM 選択時に呼ぶ
- [ ] 6.5 `_on_item_use_flow_completed(message)` を ItemUseFlow.flow_completed に connect
- [ ] 6.6 旧 `_open_item_selector`, `_on_item_selector_item_selected`, `_on_item_selector_cancelled`, `_valid_item_targets`, `_commit_item_command`, `_pending_item_instance` を削除
- [ ] 6.7 `CombatItemSelector` クラスの扱いを判断:残すなら ItemUseFlow が内部で利用、削除するならテストも更新
- [ ] 6.8 全テスト通過を確認しコミット

## 7. リターゲット情報の TurnReport 追加 (TDD)

- [ ] 7.1 `tests/combat/test_turn_engine.gd` (既存)に「死んだターゲットへの攻撃で retargeted_from が記録される」テストを追加
- [ ] 7.2 `tests/combat/test_combat_log.gd` に「retargeted_from が空でないとき log 行に元ターゲット名が含まれる」テストを追加
- [ ] 7.3 テスト Red コミット
- [ ] 7.4 `src/combat/turn_report.gd` の ReportAction クラスに `retargeted_from: String = ""` フィールドを追加
- [ ] 7.5 `src/combat/turn_engine.gd:_resolve_attack` でリターゲット時に `retargeted_from` を記録
- [ ] 7.6 `src/combat/combat_log.gd:append_from_report_action` で retargeted_from が空でない場合の表示ロジックを追加
- [ ] 7.7 テスト Green コミット

## 8. ログ再生の Timer 化 (TDD)

- [ ] 8.1 `tests/combat/test_combat_overlay.gd` に「`cancel_log_playback()` でペンディングのログが再生されない」テストを追加
- [ ] 8.2 テスト Red コミット
- [ ] 8.3 `combat_overlay.gd:_play_log_sequentially` を Timer ノードベースに書き換え、`_log_pending_actions: Array`, `_log_timer: Timer` フィールドを追加
- [ ] 8.4 `_show_next_log_line()`, `_on_log_timer()`, `cancel_log_playback()` を実装
- [ ] 8.5 旧 `await get_tree().create_timer(...).timeout` を削除
- [ ] 8.6 `_on_result_confirmed` などで visible=false 時に `cancel_log_playback()` を呼ぶ
- [ ] 8.7 テスト Green コミット

## 9. 動作確認

- [ ] 9.1 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過
- [ ] 9.2 ゲーム起動 → ダンジョン → エンカウンタ → 全コマンド(攻撃/防御/アイテム/逃走)を試す
- [ ] 9.3 アイテム使用フローが ItemUseFlow 経由で正しく動くこと
- [ ] 9.4 死んだ敵への攻撃でリターゲット表示がログに出ること
- [ ] 9.5 戦闘ログ再生中に高速で結果に進めるかをスタブで確認
- [ ] 9.6 戦闘終了時の経験値・ゴールド・レベルアップ表示が正しいこと

## 10. 仕上げ

- [ ] 10.1 `openspec validate refactor-combat-overlay --strict`
- [ ] 10.2 `/opsx:verify refactor-combat-overlay`
- [ ] 10.3 `/opsx:archive refactor-combat-overlay`
