## Context

現状の `DamageCalculator.calculate(attacker, target, rng) -> int` は `max(1, attacker.get_attack() - target.get_defense() / 2 + spread)` だけで、命中・回避は無い。したがって完全な攻撃命中前提の戦闘である。`CombatActor` は `_defending` フラグ（`apply_defend()` / `clear_turn_flags()`）以外に動的なステータス修飾を扱う仕組みを持たない。Equipment 由来のステータス取得は `EquipmentProvider` が担うが、これは「装備から計算する」純粋関数で、戦闘中に変動する修飾を表現しない。

後続フェーズの `add-status-effect-infrastructure` 以降は、命中判定 (sleep/blind の挙動)、修飾スタック (バフ・デバフ呪文)、status による外部からのステータス書き換えを必要とする。本 change はそれらの前段としての「式と入れ物」だけを純粋に整備する。

設計上の制約:

- `TurnEngine._resolve_attack` は `DamageCalculator.calculate` の戻り値 `int` を `take_damage(damage)` に流し、`TurnReport.add_attack(attacker, target, damage, defended, retargeted_from)` を呼ぶ既存契約を持つ
- `EquipmentProvider` は `get_attack(character)` 等を提供し `PartyCombatant.get_attack()` が呼んでいる
- `MonsterCombatant.get_attack()` は `MonsterData` を参照して直接返す
- `_end_turn_cleanup()` がターン終了処理 (defend クリア) のフックポイント
- 既存テスト（`tests/combat/test_damage_calculator*` など）は固定 RNG とフィクスチャ前提の数値検証

## Goals / Non-Goals

**Goals:**

- `DamageCalculator.calculate` を 2 段階フロー (hit roll → damage roll) に刷新する
- `DamageResult { hit: bool, amount: int }` 戻り値を導入し、`TurnReport` に miss を記録する
- `CombatActor` に `StatModifierStack` を保持させ、`get_attack/defense/agility` を base+modifier 合算にする
- `get_hit_modifier_total()` / `get_evasion_modifier_total()` / `has_blind_flag()` の照会 API を追加する
- ターン終端で battle-only 修飾を全消去する責務を `_end_turn_cleanup()` に追加する
- 本 change の実行直後の状態で、modifier_stack の add 呼び出し元はゼロ件 (= プレイ感は命中判定の追加分だけ)

**Non-Goals:**

- 状態異常の実装 (sleep / blind / poison など — `add-status-effect-infrastructure` 以降)
- バフ・デバフ呪文の追加 (modifier_stack の活用は `add-stat-modifier-spells`)
- AC や属性弱点の導入
- クリティカルヒット
- セーブ移行 (開発段階のため不要)

## Decisions

### Decision 1: `DamageCalculator.calculate` の戻り値型を `int` → `DamageResult` に変更する

**選択**: `class_name DamageResult extends RefCounted` で `var hit: bool` / `var amount: int` を保持する小さな値オブジェクトに切替。既存の `int` 戻りは廃止。

**理由**:
- 「ダメージ 0 で外した」「ダメージ 1 で当たった」を `int` だけでは区別不能
- `Dictionary` 戻りより型が明示でき、テストが書きやすい
- 後続で `is_critical: bool` 等を増やすときも RefCounted の方が拡張しやすい

**代替**: `int` 戻りを維持して `damage == 0` を miss とする ─ ただし最低 1 ダメージ仕様と衝突して破綻するため却下。

### Decision 2: 命中式の構造

```
hit_chance =
    BASE_HIT (= 0.85)
  + clamp(attacker.get_hit_modifier_total(),       -0.4, +0.4)
  - clamp(target.get_evasion_modifier_total(),     -0.4, +0.4)
  + clamp((attacker.AGI - target.AGI) * AGI_K,     -0.30, +0.30)
  - (BLIND_PENALTY if attacker.has_blind_flag() else 0.0)
final = clamp(hit_chance, 0.05, 0.99)
```

定数:
- `BASE_HIT = 0.85`
- `AGI_K = 0.02`（AGI 差5で ±0.10、差15で上限張り付き）
- `AGI 上限 = 0.30`（差し引き式の他要素より少し強い影響を許容）
- `MOD_CAP = 0.40`（hit/eva 修飾の上下限）
- `BLIND_PENALTY` の値は本 change では `0.0` 固定。実値は `add-status-effect-infrastructure` で StatusData に持たせる
- 最終 clamp `[0.05, 0.99]` で「絶対外れる」「絶対当たる」を排除

**理由**: 探索フェーズで合意した数値そのまま。`AGI_K` は CombatActor 経由で AGI を読むため `int` 同士の差分 × `float` の混合計算 (Godot の自動 promotion で問題なし)。

**注意**: `CombatActor.get_agility()` は modifier 合算後の値を返す（後の change のため）。命中式には modifier 後 AGI を使う方が「素早さバフは命中も上げる」副次効果が出て直観的。

### Decision 3: AGI 取得は modifier 後で良いか?

**選択**: AGI 差は `attacker.get_agility() - target.get_agility()` で取る (= modifier 適用後の AGI で計算)。

**理由**:
- `get_agility()` をベースで取り直すヘルパーを用意するとコード経路が二系統になる
- バフ/デバフ呪文を考えると「素早さアップ呪文 → 命中もちょっと上がる」は望ましい挙動
- 修飾上限が hit/eva 側と AGI 側でそれぞれ独立してクランプされるので、AGI 修飾が間接的に hit を破壊することはない

### Decision 4: `StatModifierStack` の構造と β 規則

```gdscript
class_name StatModifierStack
extends RefCounted

# entries: [{stat: StringName, delta: Variant, duration: int, scope: int (BATTLE_ONLY=0)}]
var _entries: Array = []

func add(stat: StringName, delta, duration: int) -> void:
    var existing := _find(stat)
    if existing == null:
        _entries.append({stat=stat, delta=delta, duration=duration, scope=0})
        return
    if abs_value(delta) > abs_value(existing.delta):
        existing.delta = delta
        existing.duration = duration
        return
    if abs_value(delta) == abs_value(existing.delta):
        existing.duration = max(existing.duration, duration)
        return
    # weaker incoming: keep existing as-is
```

**β 規則の正式化**:
1. **同 stat の既存修飾なし** → 新規追加
2. **新規が既存より強い** (`abs(new.delta) > abs(existing.delta)`) → 既存を破棄して新規で置換 (符号も含めて上書き、duration も新規)
3. **同強度** (`abs(new.delta) == abs(existing.delta)`) → 既存を維持しつつ duration のみ `max(existing, new)`
4. **新規が既存より弱い** → 何もしない

**理由**: ATK+1 の上に ATK-2 を食らったら -2 が勝つ（強い側勝ち）。ATK+2 の上に ATK+1 を重ねても弱化されない。同強度を上書きにしないのは、「同じバフの2回目」がリセットになる挙動を避けるため。

**集計**:
```gdscript
func sum(stat: StringName) -> Variant:
    var total = 0  # int / float の最初の0
    for e in _entries:
        if e.stat == stat:
            total += e.delta
    return total
```

`int`（attack/defense/agility）と `float`（hit/evasion）の両方を扱うが、stat ごとに種類は固定なので Variant で十分。

**tick**:
```gdscript
func tick_battle_turn() -> void:
    for e in _entries.duplicate():
        if e.scope == 0:  # BATTLE_ONLY
            e.duration -= 1
            if e.duration <= 0:
                _entries.erase(e)
```

**clear_battle_only**: 戦闘終了時に scope==BATTLE_ONLY を全削除。

`_end_turn_cleanup` での扱い: ターン進行 (`tick_battle_turn`) はターン終端で 1 だけ進める。`clear_battle_only` は **本 change では呼ばれない**（戦闘終了 hook が後続 change の話のため）。

### Decision 5: `CombatActor.get_attack/defense/agility()` 改修

**改修前**:
```gdscript
func get_attack() -> int:
    return 0  # 既定。サブクラスで override
```
派生 `PartyCombatant.get_attack()` → `equipment_provider.get_attack(character)` を返す。

**改修後**:
- 抽象側の virtual を `_get_base_attack()` 等に rename し、サブクラスにはこちらを実装させる
- 親クラスで `get_attack()` を `final` 相当に固定し `_get_base_attack() + modifier_stack.sum(&"attack")` を返す

```gdscript
# CombatActor
func get_attack() -> int:
    return _get_base_attack() + int(modifier_stack.sum(&"attack"))

func _get_base_attack() -> int:
    return 0  # サブクラスで override
```

派生クラスは `_get_base_attack()` に `equipment_provider.get_attack(character)` を返すよう書き換える。

**理由**: 1 行で base+mod を加算する責務をスーパークラスに集約。サブクラスは modifier の存在を意識せずに済む。

### Decision 6: `get_hit_modifier_total` / `get_evasion_modifier_total` / `has_blind_flag` の置き場所

```gdscript
# CombatActor
func get_hit_modifier_total() -> float:
    return clamp(float(modifier_stack.sum(&"hit")), -MOD_CAP, MOD_CAP)

func get_evasion_modifier_total() -> float:
    return clamp(float(modifier_stack.sum(&"evasion")), -MOD_CAP, MOD_CAP)

func has_blind_flag() -> bool:
    return false  # 後続 change が override
```

`MOD_CAP = 0.40` は `CombatActor` のクラス定数として置く。同じ値は `DamageCalculator` 側でも参照される（DRY のため `CombatActor.MOD_CAP` を直接参照）。

### Decision 7: `TurnReport` の miss action

新エントリ種別:
```gdscript
# turn_report.gd
func add_miss(attacker, target) -> void:
    actions.append({
        "type": "miss",
        "attacker_name": attacker.actor_name,
        "target_name": target.actor_name,
    })
```

CombatLog 描画 (本 change の範囲外) は後続 change で行う想定だが、`type == "miss"` のフォーマットと既存 `type == "attack"` の互換は守る。

**追加で**: `add_attack` のエントリに `hit: bool = true` フィールドは追加せず、外したケースは別エントリ (`type == "miss"`) として表現する（既存テストの構造を壊さないため）。

### Decision 8: `_resolve_attack` の流れ

```gdscript
func _resolve_attack(attacker, target, rng, report):
    var effective_target = _retarget_if_dead(attacker, target)
    if effective_target == null:
        return
    var result := DamageCalculator.calculate(attacker, effective_target, rng)
    if not result.hit:
        report.add_miss(attacker, effective_target)
        return
    var defended := effective_target.is_defending()
    effective_target.take_damage(result.amount)
    report.add_attack(attacker, effective_target, result.amount, defended, retargeted_from)
    if not effective_target.is_alive():
        report.add_defeated(effective_target)
```

`is_defending()` の半減は **`take_damage()` 内** で適用される既存挙動を維持。`DamageCalculator` は素のダメージを返し、TurnReport.add_attack の `damage` フィールドはこれまで通り「素ダメージ」を持つ。`take_damage()` 後の HP 減量と表示用ダメージのズレは既存と同じ範囲。

### Decision 9: 既存テストの扱い

固定 RNG を使う既存テストは、命中判定でも RNG が消費されるようになるため数値が変わる。対応方針:

- 既存攻撃シナリオ: テストの RNG モックに「`randf() < hit_chance`」をコントロールする手当を入れ、必要に応じて `randf` 戻り値を 0.0 (絶対命中) や 1.0 (絶対外し) に固定
- DamageCalculator のテストは既存の数値検証を残しつつ、新しい命中境界テストを追加
- TurnEngine 側の attack シナリオは hit_chance を 0.99 に張り付かせるため `attacker.modifier_stack.add(&"hit", 0.5, 99)` 等で底上げするヘルパーを test util に置く

これは破壊的なテスト書き換えだが、開発段階のため許容。

## Risks / Trade-offs

- **[既存戦闘テストが落ちる] → Mitigation**: テスト RNG ヘルパーで命中判定をコントロールし、シナリオごとに「絶対命中」「絶対外し」を選べるようにする。テスト書き換え量は中程度。
- **[base_hit=0.85 が体感的に渋い可能性] → Mitigation**: 定数なので Phase 0 完了後に手早く調整可能。実装段階で 0.90 に上げる選択もある（プレイテストで判断）。
- **[Variant 計算の暗黙型変換ミス] → Mitigation**: `StatModifierStack.sum` は `int` 開始の合計と `float` 開始の合計を separate メソッドにするか、stat ごとに sum_int/sum_float を分ける。実装時に `Variant` の落とし穴 (空配列で初期値が 0 か null か) をテストで網羅。
- **[modifier_stack の Variant が将来形質を増やす] → Mitigation**: 当面 `delta` は `int | float` のみ。状態異常 (例: `&"sleep"` フラグ) は modifier ではなく `StatusTrack` 側で持つので混入しない。
- **[_end_turn_cleanup で tick するか戦闘終了で clear するか] → Mitigation**: 本 change は `tick` のみ実装し、`clear_battle_only()` の呼び出しは `add-status-effect-infrastructure` で battle 終了 hook を整える際に追加する。実装段階で hook 不在を理由にデッドコードにならないよう、ユニットテストで `clear_battle_only()` の単体動作だけ検証しておく。

## Migration Plan

開発段階のため移行ステップは不要。実装直後にゲームを起動して、既存戦闘が「数値は若干上下するが破綻しない」ことを目視確認すれば良い。
