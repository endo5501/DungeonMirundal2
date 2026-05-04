## Why

本プロジェクトの戦闘は `max(1, attack - defense/2 + spread)` という単純なダメージ式のみで成立しており、命中・回避の概念が存在しない。次に控える状態異常システム (sleep / blind / silence など) や バフ・デバフ呪文（攻撃力±N、命中±0.1 など）は、命中判定フックと汎用ステータス修飾ストックを前提に設計されている。これらを「素のシステム拡張」として先行投入し、後続 5 つの change の土台にすることで、状態異常導入時のテスト失敗箇所を「命中式の問題」「修飾の問題」「状態の問題」の3層に切り分けやすくする。

## What Changes

- `DamageCalculator.calculate(attacker, target, rng)` を 2 段階フローに刷新する
  - Step 1: 命中判定 — `hit_chance = clamp(0.85 + atk.hit_modifier_total - tgt.evasion_modifier_total + (atk.AGI - tgt.AGI) × 0.02 - blind_penalty, 0.05, 0.99)`
  - Step 2: 命中時のみ既存ダメージ式 `max(1, attack - defense/2 + spread)`
  - 外した場合のシグナル: `DamageResult { hit: bool, amount: int }` を返し、TurnReport に miss を記録できるようにする
- 命中/回避修飾の上限と AGI 寄与の上限をハードクランプ (±0.4 / ±0.30) で表現
- `CombatActor` に `StatModifierStack` を追加する
  - `add(stat: StringName, delta: Variant, duration_turns: int)` / `tick(turns: int)` / `clear_battle_only()`
  - 重複付与の規則は **「絶対値が大きい側を残す（duration は新規側で上書き）」**（β 規則）
  - 認識する stat キー: `&"attack"`, `&"defense"`, `&"agility"`, `&"hit"`, `&"evasion"`
  - `attack/defense/agility` は加算 (int)、`hit/evasion` は加算（float, ±0.4 でクランプ）
  - **本 change の段階では、modifier 値はすべてゼロ初期で誰も add しない** — 振る舞いは現状維持
- `CombatActor.get_attack/defense/agility()` を「Equipment 値 + modifier_stack による加算」に拡張
- `CombatActor.get_hit_modifier_total() -> float` / `get_evasion_modifier_total() -> float` を新設（modifier_stack の集計）
- `CombatActor.has_blind_flag() -> bool` を予約 — 本 change では常に `false` を返す（後続 change が override する）
- `TurnEngine` のターン終端で `clear_battle_only()` を呼び、modifier_stack を空にする
  - `_end_turn_cleanup()` の責務を維持

## Capabilities

### New Capabilities

- なし

### Modified Capabilities

- `combat-engine`: `Attack` 命令の解決経路で命中判定が前段に挿入される。`DamageCalculator` の契約が `int` 戻りから `DamageResult` 戻りへ変わる。`TurnReport` に miss action 種別が追加される。`_end_turn_cleanup` で modifier_stack のターン進行・battle-only 修飾の消去を行う要件が追加される。
- `combat-actor`: `CombatActor` に `StatModifierStack` を保持する責務、`get_attack/defense/agility` が「base + modifier」になる責務、`get_hit_modifier_total` / `get_evasion_modifier_total` / `has_blind_flag` の照会 API、`clear_battle_only` の責務が追加される。

## Impact

- **影響コード**: `src/combat/damage_calculator.gd`, `src/combat/combat_actor.gd`, `src/combat/turn_engine.gd`, `src/combat/turn_report.gd`, 派生クラス `src/combat/party_combatant.gd` / `src/combat/monster_combatant.gd`
- **新規ファイル**: `src/combat/stat_modifier_stack.gd`, `src/combat/damage_result.gd`
- **テスト**: `tests/combat/test_damage_calculator.gd`（命中境界、AGI 差クランプ、最終 clamp）、`tests/combat/test_stat_modifier_stack.gd`（β 規則、duration tick、battle-only クリア）、`tests/combat/test_combat_actor_modifiers.gd`（base+modifier 合算）、既存 `tests/combat/test_turn_engine*` の互換確認
- **後続依存**: 本 change は次の change `add-status-effect-infrastructure` の前提となる。状態異常側は modifier_stack と DamageResult/has_blind_flag に新フックを足し込む形で乗る
- **互換性**: プロジェクトは開発段階のためセーブ互換は不要。テスト RNG シードを通した既存戦闘ログの数値は変わり得る（外し率 0.85 ≒ 1 失敗/7 ターン）— 既存テストは固定 RNG を前提にしているため必要に応じて RNG モックを更新
