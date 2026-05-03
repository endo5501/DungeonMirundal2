## Why

`src/dungeon_scene/combat_overlay.gd` (552 LOC) は 7-phase の状態機械、4 つの UI サブパネル、依存関係の配線、戦闘設定、phase ごとの入力処理、`_finalize_battle` 内のレベルアップ・ゴールド処理が同居する god class。`esc_menu.gd` と並んで top-churned ファイルの 1 つ。

主な問題:
1. **`_finalize_battle` (`:293-310`) が報酬計算をオーバーレイ内に持っている** — `ExperienceCalculator.award` 呼び出し、ゴールドドロップ計算、レベルアップ通知。これらは UI ではなくドメインロジック。
2. **アイテム使用フローが esc_menu と重複している** (F033) — `_open_item_selector` → `_on_item_selector_item_selected` → `_valid_item_targets` → `_commit_item_command` の流れは esc_menu が同じ shape で持っている。
3. **per-phase 入力処理が 5 つの `_handle_*_key` メソッドに散らばる** — `_handle_command_menu_key`, `_handle_target_select_key`, `_handle_item_select_key`, `_handle_result_key`、各 phase の入力規約を内部で再実装。
4. **死んだターゲットへの再ターゲット (F037) が log に出ない** — `TurnEngine._resolve_attack` が静かに別敵を選ぶが、戦闘ログには元の宣言通りに表示される。プレイヤーに伝わらない。
5. **`await timer.timeout` がキャンセル不能** (F038) — エンカウンタ resolved や overlay close 中に await が走り続ける。

C6 で `ItemUseFlow` が独立 Control として抽出済み(in_combat 対応含む)なので、本 change で再利用する。

## What Changes

- `src/combat/battle_resolver.gd` を新規追加(`BattleResolver` RefCounted)
  - `resolve_rewards(turn_engine, rng) -> BattleSummary` を提供
  - 経験値・ゴールド・レベルアップ前後の計算を内部で実行
  - `BattleSummary` は `gained_experience: int`, `gained_gold: int`, `level_ups: Array[Dictionary]` を保持する RefCounted
- `src/combat/combat_input_router.gd` を新規追加(`CombatInputRouter` RefCounted)
  - `route(event, phase, panels) -> bool` で phase ごとの入力ルーティングを集約
  - `phase` 引数で対応する panel(`command_menu`, `target_selector`, `item_selector`, `result_panel`)に MenuController.route を委譲
- `combat_overlay.gd` を:
  - `_finalize_battle` 内の報酬計算ロジックを `BattleResolver` に委譲
  - per-phase `_handle_*_key` 5 メソッドを撤廃し、`CombatInputRouter.route` 1 呼び出しに統合
  - C6 で抽出した `ItemUseFlow` を `_item_selector` の代わりに使う(`_open_item_selector`, `_on_item_selector_item_selected`, `_valid_item_targets`, `_commit_item_command` を削除)
  - `await get_tree().create_timer(...)` を `Timer` ノードベースの cancellable な実装に置換
- `TurnEngine` に `TurnReport.actions` の各エントリへ「retargeted_from」情報を加え、リターゲット発生時に combat log に「X は死亡しているため Y を攻撃した」と表示する
- 既存テスト(`tests/combat/test_combat_overlay.gd`)の外部観測可能シナリオは無修正で通る。phase ごとの内部メソッドを直接呼んでいるテストは更新

## Capabilities

### Modified Capabilities

- `combat-overlay`: 入力ルータ・報酬計算の責務分離、ItemUseFlow の利用、await のキャンセル対応を追加
- `combat-engine`: TurnReport にリターゲット情報を追加

### New Capabilities

- `battle-resolver`: 戦闘終了時の報酬計算を担当する RefCounted。経験値・ゴールド・レベルアップを 1 つの `BattleSummary` にまとめて返す。
- `combat-input-router`: 戦闘 phase ごとの入力ルーティングを集約する RefCounted。

## Impact

- **新規コード**:
  - `src/combat/battle_resolver.gd`
  - `src/combat/battle_summary.gd`
  - `src/combat/combat_input_router.gd`
  - `tests/combat/test_battle_resolver.gd`
  - `tests/combat/test_combat_input_router.gd`
- **変更コード**:
  - `src/dungeon_scene/combat_overlay.gd` — 約 200 LOC 削減見込み
  - `src/combat/turn_engine.gd` — TurnReport にリターゲット情報追加、`_resolve_attack` のリターゲットを記録
  - `src/combat/turn_report.gd` — ReportAction に retargeted_from フィールド
- **削除**:
  - combat_overlay 内の `_handle_command_menu_key`, `_handle_target_select_key`, `_handle_item_select_key`, `_handle_result_key`
  - combat_overlay 内の `_open_item_selector`, `_on_item_selector_item_selected`, `_valid_item_targets`, `_commit_item_command`(ItemUseFlow に置換)
  - combat_overlay 内の `_compute_gold_drop`, `_collect_participant_characters`, `_collect_dead_monsters`(BattleResolver に移動)
- **互換性**:
  - 戦闘の外部 API(`start_encounter`, `encounter_resolved`, `party_state_changed` 等)は不変
  - セーブデータ形式は不変
- **依存関係**:
  - C4b (action 統一) と C6 (ItemUseFlow) 完了が前提
  - 本 change が完了すると combat_overlay は 350 LOC 程度の薄いオーケストレータになる
