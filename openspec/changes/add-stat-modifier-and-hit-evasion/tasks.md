## 1. StatModifierStack 基盤（テスト先行）

- [ ] 1.1 `tests/combat/test_stat_modifier_stack.gd` を新規作成: 空 add → 値が見える / 同 stat 強い側勝ち / 弱い側 no-op / 同強度は duration max / 異 stat 共存 / sum 集計 / tick_battle_turn 1減算 / duration<=0 で削除 / clear_battle_only で全削除
- [ ] 1.2 `src/combat/stat_modifier_stack.gd` を新規実装: `_entries: Array`、`add(stat, delta, duration)`、`sum(stat) -> Variant`、`tick_battle_turn()`、`clear_battle_only()`、`is_empty() -> bool` 補助
- [ ] 1.3 1.1 のテストが緑になることを確認

## 2. DamageResult 値オブジェクト

- [ ] 2.1 `tests/combat/test_damage_result.gd` を新規作成: `DamageResult.new(true, 5)` 構築 / hit==true & amount==5 / `DamageResult.new(false, 0)` で hit==false / DamageResult はインスタンスごとに独立
- [ ] 2.2 `src/combat/damage_result.gd` を新規実装: `class_name DamageResult extends RefCounted`、`var hit: bool`、`var amount: int`、`func _init(p_hit: bool = true, p_amount: int = 0)`
- [ ] 2.3 2.1 のテストが緑になることを確認

## 3. CombatActor の modifier 統合（テスト先行）

- [ ] 3.1 `tests/combat/test_combat_actor_modifiers.gd` を新規作成:
  - `CombatActor` インスタンスに `modifier_stack` プロパティが存在
  - `get_attack/defense/agility` がそれぞれ `_get_base_<stat>() + modifier_stack.sum(&"<stat>")` を返す
  - `get_hit_modifier_total()` は `modifier_stack.sum(&"hit")` を ±0.4 でクランプ
  - `get_evasion_modifier_total()` は ±0.4 でクランプ
  - `has_blind_flag()` のデフォルトが `false`
  - `MOD_CAP = 0.40` 定数が `CombatActor` に存在
- [ ] 3.2 `src/combat/combat_actor.gd` 改修:
  - `var modifier_stack := StatModifierStack.new()` を追加
  - `const MOD_CAP := 0.40` を追加
  - `_get_base_attack/defense/agility() -> int` を virtual として追加（既定 0）
  - `get_attack/defense/agility() -> int` を `_get_base_<stat>() + int(modifier_stack.sum(&"<stat>"))` に変更
  - `get_hit_modifier_total() -> float` 実装（clamp 適用）
  - `get_evasion_modifier_total() -> float` 実装
  - `has_blind_flag() -> bool` 実装（既定 false）
- [ ] 3.3 `src/combat/party_combatant.gd` 改修: `get_attack/defense/agility()` を override から `_get_base_attack/defense/agility()` の override に変更し、内部で `equipment_provider.get_<stat>(character)` を返す
- [ ] 3.4 `src/combat/monster_combatant.gd` 改修: 同様に `_get_base_<stat>()` 経路へ移行し、`MonsterData` から base 値を返す
- [ ] 3.5 既存 `tests/combat/test_combat_actor.gd` / `tests/combat/test_party_combatant.gd` / `tests/combat/test_monster_combatant.gd` の `get_attack` 系シナリオが modifier ゼロでも数値変化なく緑であることを確認
- [ ] 3.6 3.1 のテストが緑になることを確認

## 4. DamageCalculator の命中式（テスト先行）

- [ ] 4.1 `tests/combat/test_damage_calculator.gd` を更新/拡張:
  - 既存「基本ダメージ式」テストを「ヒット成功時の式」に書き換え（DamageResult 戻り）
  - 「最低 1 ダメージ」のシナリオを `hit==true, amount==1` で書き直し
  - 新規: 等 AGI / 修飾なし / blind なし → `final_hit_chance == 0.85`
  - 新規: AGI 差 +5 → `+0.10`、AGI 差 +20 → `+0.30` で頭打ち
  - 新規: AGI 差 -25 → `-0.30` で頭打ち
  - 新規: hit_modifier +0.7 → +0.4 にクランプ / evasion +0.6 → +0.4 にクランプ
  - 新規: 最終 clamp 0.05..0.99 の境界
  - 新規: `randf()` 戻り値 vs `final_hit_chance` の strict less-than 判定（境界値）
  - 新規: `attacker.has_blind_flag() == true` でも本 change では BLIND_PENALTY=0 なので影響なし（次 change の差分で挙動変わる予告コメント）
- [ ] 4.2 `src/combat/damage_calculator.gd` を改修:
  - `calculate(attacker, target, rng) -> DamageResult` の戻り型に変更
  - `BASE_HIT = 0.85` / `AGI_K = 0.02` / `AGI_CAP = 0.30` / `BLIND_PENALTY = 0.0` を `const` で定義（後続 change で StatusData 側に移すコメント付き）
  - 命中チャンス計算 → `randf()` 比較 → ミスなら `DamageResult.new(false, 0)` を返す
  - ヒット時のみ既存スプレッド計算で `amount` を求め、`max(1, amount)` で `DamageResult.new(true, amount)` を返す
- [ ] 4.3 4.1 のテストが緑になることを確認

## 5. TurnReport.add_miss

- [ ] 5.1 `tests/combat/test_turn_report.gd` (なければ新規) に `add_miss` シナリオを追加: 戻り構造 `{type: "miss", attacker_name, target_name}`
- [ ] 5.2 `src/combat/turn_report.gd` に `func add_miss(attacker: CombatActor, target: CombatActor) -> void` を追加
- [ ] 5.3 既存 `add_attack` の戻り構造に変更を加えていないことを確認（既存テスト保全）

## 6. TurnEngine の attack 経路改修（テスト先行）

- [ ] 6.1 `tests/combat/test_turn_engine.gd` を改修:
  - 既存 attack シナリオで RNG モックの `randf()` を 0.0 (絶対ヒット) に固定するヘルパーを追加
  - 新規: 命中チャンスが 0.05 を下回る条件で `randf()` が 0.99 → ミス → `report.actions[i].type == "miss"`、target HP 不変
  - 新規: `report.add_attack` は hit のみ呼ばれる
- [ ] 6.2 `src/combat/turn_engine.gd._resolve_attack` を改修:
  - `DamageCalculator.calculate(...) -> DamageResult` に対応
  - `result.hit == false` なら `report.add_miss(attacker, target)` を呼んで return
  - `result.hit == true` なら既存通り `take_damage` + `add_attack`
- [ ] 6.3 6.1 のテストと既存戦闘統合テストが緑であることを確認

## 7. _end_turn_cleanup での tick_battle_turn

- [ ] 7.1 `tests/combat/test_turn_engine.gd` に新規シナリオ:
  - 戦闘前にあるアクターへ `modifier_stack.add(&"attack", +2, 2)` を直接設定
  - 1 ターン解決後 → `sum(&"attack")` が `+2` のまま (duration=1)
  - 2 ターン解決後 → `sum(&"attack")` が `0` (削除済)
- [ ] 7.2 `src/combat/turn_engine.gd._end_turn_cleanup()` を改修:
  - 各 party / monster に対し `actor.modifier_stack.tick_battle_turn()` を呼ぶ
  - 既存の `clear_turn_flags()` 呼び出しは維持
- [ ] 7.3 7.1 のテスト緑を確認

## 8. テストインフラ整備

- [ ] 8.1 `tests/combat/_helpers/` に共通テスト util を新規作成または既存を拡張: `make_certain_hit_rng()` (0.0 を返す stub) / `make_certain_miss_rng()` (0.99 を返す stub) / `make_fixed_spread_rng(int)` (randi_range だけ固定)
- [ ] 8.2 既存戦闘テストのうち RNG 直叩きで現状動いているものを 8.1 のヘルパーで書き換え、命中判定の追加で破綻しないことを確認

## 9. 全体検証

- [ ] 9.1 `tests/combat/` 配下の全テストが緑になることを確認
- [ ] 9.2 `tests/dungeon/` の戦闘関連 (encounter, combat_overlay) も緑であることを確認
- [ ] 9.3 ゲーム手動起動でランダムエンカウントを 1-2 戦闘行い、命中チャンスが「だいたい当たる、たまに外す」感覚であることを確認（base_hit=0.85 の体感確認）
- [ ] 9.4 `openspec validate add-stat-modifier-and-hit-evasion --strict` が成功することを確認

## 10. アーカイブ準備

- [ ] 10.1 実装完了後 `/opsx:verify add-stat-modifier-and-hit-evasion` を実行して齟齬がないかをレビュー
- [ ] 10.2 `/opsx:archive add-stat-modifier-and-hit-evasion` で specs に統合
