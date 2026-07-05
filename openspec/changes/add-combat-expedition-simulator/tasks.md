# Tasks: add-combat-expedition-simulator

TDD で進める: 各グループはテスト作成 → 失敗確認 → コミット → 実装 → パス確認 → コミットの順。

## 1. PartyAiConfig / PartyAi

- [x] 1.1 `tests/simulation/test_party_ai.gd` を作成(前衛の攻撃/防御 fallback、僧侶の回復閾値・MP 不足時 fallback、過剰回復最小の呪文選択、魔法使いのノブ条件 3 種、ENEMY_GROUP/ENEMY_ONE 選択)。失敗を確認してコミット
- [x] 1.2 `src/simulation/party_ai_config.gd`(ノブ 3 種と既定値)を実装
- [x] 1.3 `src/simulation/party_ai_context.gd` と `src/simulation/party_ai.gd`(`MonsterAi` と同型の static `choose()`)を実装し、1.1 のテストをパスさせてコミット

## 2. 戦闘間回復 (BetweenBattleHealer)

- [x] 2.1 `spell_use_flow.gd` の戦闘外回復の適用経路を確認し、design.md の Open Question を解消(必要なら design.md を更新)
- [x] 2.2 `tests/simulation/test_between_battle_healer.gd` を作成(最傷者優先、過剰回復最小、MP 切れで停止、全員満タンで何もしない)。失敗を確認してコミット
- [x] 2.3 `src/simulation/between_battle_healer.gd` を実装しテストをパスさせてコミット

## 3. エンカウント供給 (EncounterSource)

- [x] 3.1 `tests/simulation/test_encounter_source.gd` を作成(FixedPatternSource の順序ループ、TableEncounterSource が floor テーブルの範囲内の編成を返すこと)。失敗を確認してコミット
- [x] 3.2 `src/simulation/encounter_source.gd`(基底)、`fixed_pattern_source.gd`、`table_encounter_source.gd` を実装しテストをパスさせてコミット

## 4. パーティ生成 (PartyFactory) と設定ロード

- [x] 4.1 `tests/simulation/test_party_factory.gd` を作成(レベル 3 僧侶が spell_progression 通りの呪文と成長済み HP/MP を持つ、初期装備適用、row 反映、不正な job/race でエラー)。失敗を確認してコミット
- [x] 4.2 `src/simulation/party_factory.gd` を実装(レベル 1 生成 → 本番のレベルアップ経路で目標レベルまで成長)しテストをパスさせてコミット
- [x] 4.3 `tests/simulation/test_expedition_config.gd` を作成(JSON パース、既定値、encounters.mode 分岐、不正フィールドのエラー)。失敗を確認してコミット
- [x] 4.4 `src/simulation/expedition_config.gd` を実装しテストをパスさせてコミット

## 5. 遠征ループ (ExpeditionRunner)

- [ ] 5.1 `tests/simulation/test_expedition_runner.gd` を作成(WIPED で停止、max_battles で停止、STALLED 打ち切り、HP/MP の戦闘間持ち越し、経験値付与とレベルアップ反映、同一シードで同一結果)。失敗を確認してコミット
- [ ] 5.2 `src/simulation/expedition_result.gd`(per-battle 記録と end cause)を実装
- [ ] 5.3 `src/simulation/expedition_runner.gd` を実装(PartyAi → submit_command → resolve_turn ループ、BattleResolver.resolve_rewards、BetweenBattleHealer 呼び出し)しテストをパスさせてコミット

## 6. 集計とレポート (simulation-report)

- [x] 6.1 `tests/simulation/test_result_aggregator.gd` を作成(nearest-rank の median/p10/p90、「発生しなかった run」の除外と件数、end cause 比率)。失敗を確認してコミット
- [x] 6.2 `src/simulation/result_aggregator.gd`(純ロジック、I/O なし)を実装しテストをパスさせてコミット
- [x] 6.3 `tests/simulation/test_csv_writer.gd` を作成(ヘッダ行、行数、親ディレクトリ作成)。失敗を確認してコミット
- [x] 6.4 `src/simulation/simulation_csv_writer.gd` とコンソールサマリ整形(`summary_formatter.gd`)を実装しテストをパスさせてコミット

## 7. ヘッドレス CLI と結線

- [ ] 7.1 `src/simulation/expedition_cli.gd`(SceneTree 継承、`OS.get_cmdline_user_args()` パース、master_seed からの run シード導出、終了コード)を実装
- [ ] 7.2 サンプル設定 `tmp/simulation/sample_config.json`(または `docs/` 配下)を作成し、`godot --headless -s src/simulation/expedition_cli.gd -- --config=...` の実行方法を README か docs に記載
- [ ] 7.3 固定パターンモードとテーブルモードの両方で end-to-end 実行し、サマリ表と CSV の内容を目視確認(同一 config 2 回実行で CSV が一致することも確認)してコミット

## 8. 仕上げ

- [ ] 8.1 GUT 全テストスイートを実行し既存テストに回帰がないことを確認
- [ ] 8.2 openspec の仕様シナリオとテストの対応を確認し、抜けがあればテストを追補してコミット
