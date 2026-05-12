## Context

DungeonMirundal2 の戦闘は `PartyCombatant` と `MonsterCombatant` という2つの `CombatActor` 派生で構成され、`TurnEngine.resolve_turn(rng)` がコマンド解決のすべてのフローを所有している。スペル系統 (`SpellEffect.apply(caster, targets, rng)`) は `CombatActor` を受け取る汎用 API として既に実装されており、Party/Monster の区別なく扱えるよう設計されている。

しかし現状のモンスターは戦術的に貧弱:

- `MonsterCombatant._read_max_mp() == 0` / `spend_mp(>0) == false` で詠唱を明示的に禁止。
- `TurnEngine` のモンスター分岐は「reachable な party member を1人ランダムに殴る or wait」のみで、`CastCommand` 経路に乗らないため `silence` / `confusion` / 状態異常の効果も中途半端。
- `MonsterData` には魔法関連フィールドが無い。

この change はこの3層の壁を取り払い、既存のスペル基盤を双方向に使えるようにする。Wizardry シリーズの「魔法を撃つモンスター」体験を低リスクで再現することがゴール。

## Goals / Non-Goals

**Goals:**

- モンスターが攻撃系・状態異常系・回復系のスペルを撃てる。
- 既存スペル `.tres` をそのまま流用できる (データ重複なし)。
- `silence` / `confusion` / `action_lock` などのモンスター被掛かりが、Party 詠唱を抑止するのと同じ機構で機能する。
- AI 行動選択は純粋関数で TDD 可能。`MonsterAi.choose(monster, ctx, rng) -> Command` の単一エントリポイント。
- 既存 6 モンスター (slime/goblin/bat/skeleton/ghost/dragon) の挙動を変えない (`max_mp = 0` / `known_spells = []` のデフォルトで物理のまま)。
- 戦闘画像はダミーで実装でき、後の本制作差し替えを妨げない。
- 新規モンスター 6 種 (witch / dark_priest / imp / lich / goblin_shaman / wraith) を出荷する。

**Non-Goals:**

- モンスター側の蘇生スペル (Wizardry のディ系) — Party 側でも未実装なので別 change。
- ボス専用のシナリオ駆動 AI スクリプト — 今回は「重み付き乱択 + 簡易条件」止まり。
- モンスター MP の UI 表示 — Wizardry 流に内部値のみ。
- 戦闘画像の本制作 — 透明 PNG または既存資産流用で済ます。
- 出現テーブル (encounter spawn) の調整 — 新モンスター追加に伴うバランス変更は別 change。本 change では新モンスターを `data/monsters/` に置くだけで、`MonsterGroupSpec` の更新はしない (= 既存ダンジョンの遭遇には登場しない / 開発者用のスポーン経路でのみ検証可能)。

## Decisions

### Decision 1: ターゲット enum を side-relative に再解釈する

**選択**: `target_type == ENEMY_*` を「caster の所属の反対側」、`ALLY_*` を「caster の自陣」と解釈する。enum 値は変えない。`TurnEngine._resolve_cast_targets()` が caster の所属側を見て pool を切り替える。

**代替案**:

- *(B)* `CastCommand` に side フラグを持たせる → cast site が爆発、Party 側のコードが汚れる。
- *(C)* `monster_fire.tres` などモンスター専用スペルを分離 → データ二重化。新スペルを追加するたびに2回書くことになる。

**採用理由**:

- side-relative にすれば `fire.tres` 一つでパーティの「敵」とモンスターの「敵」の両方が表現できる。
- Wizardry でもファイアは「相手側に飛ぶ」のが自然な解釈で、enum 名 (ENEMY/ALLY) が caster 視点であることは違和感がない。
- 既存スペル `.tres` は不変。`spell-data` capability は影響を受けない。

**Implementation hint**:

```
func _resolve_cast_targets(caster, cmd, spell):
    var caster_is_party = _is_party_member(caster)
    var enemy_pool = monsters if caster_is_party else party
    var ally_pool  = party    if caster_is_party else monsters
    match spell.target_type:
        ENEMY_ONE, ENEMY_GROUP:
            # 既存ロジックの monsters 直参照を enemy_pool に置換
        ALLY_ONE, ALLY_ALL:
            # 既存ロジックの party 直参照を ally_pool に置換
```

### Decision 2: `MonsterAi` は静的純粋関数 (RefCounted の static method)

**選択**: `class_name MonsterAi extends RefCounted` で `static func choose(...) -> RefCounted` を提供。インスタンス状態を持たない。

```
MonsterAi.choose(
    monster: MonsterCombatant,
    ctx: MonsterAiContext,         # party + monsters 配列、spell_repo、status_repo を運ぶ DTO
    rng: RandomNumberGenerator
) -> RefCounted                    # AttackCommand | CastCommand | null (= 「攻撃したいが reachable target なし」)
```

**代替案**:

- *(B)* インスタンスベース AI (`var ai := MonsterAi.new(profile)`) → 状態を持たないので無駄。
- *(C)* `MonsterData` に script ベース AI フックを直接持たせる → 汎用化しすぎてテストが書きにくい。

**採用理由**:

- 純粋関数は TDD のテーブル化が容易 (`(known_spells, current_mp, party_state, seed) → expected_command`)。
- 後でボス用に「条件付き分岐」を足したくなったら、`MonsterAi.choose` 内の戦略をディスパッチするだけで済む (`if monster.data.ai_script != null: return monster.data.ai_script.choose(...)`)。

### Decision 3: AI ポリシーは v1 では「重み付き乱択 + ガード式」

**選択**: 以下の決定木に従う。

```
1. action_lock があれば → null (TurnEngine 側で action_locked エントリが付く)
2. silence があり known_spells が全て BATTLE_ONLY スペル → 攻撃に fallback
3. known_spells のうち以下を満たす candidate を集める:
   - current_mp >= spell.mp_cost
   - silence ガードを抜けている (silence 中はそもそも候補ゼロ)
   - target_type 別の前提条件:
     ENEMY_ONE   : 敵が1体以上いる
     ENEMY_GROUP : 同一 species の敵が2体以上いる (1体なら ENEMY_ONE と差別化できないので除外)
     ALLY_ONE    : 回復系 (HealSpellEffect / CureStatusSpellEffect) → 該当者がいる場合のみ
                   バフ系 (StatModSpellEffect with delta>0) → 1ターン目に限定
     ALLY_ALL    : 同様の判定を全体に
4. candidate が空 → 物理攻撃を選ぶ (既存の reachable target picker を呼ぶ)
5. candidate が非空 → 一様乱択で1つ選び CastCommand を組む
   - ENEMY_ONE は reachable な party member 1体をターゲットに
     (RANGED 扱い: 詠唱は射程概念を持たないので、生きている敵から一様乱択)
   - ENEMY_GROUP は同種 group の代表 1 体を target に渡す (既存 _resolve_cast_targets が species 解決)
   - ALLY_ONE は条件を最も強く満たす味方 1 体 (HP最低 or 状態異常持ち)
   - ALLY_ALL は target = null (既存仕様)
```

**代替案**:

- *(B)* `MonsterData.spell_priority` で「優先度リスト」を持つ → 表現力は上がるが、データ作成コストが上がる。v1 は乱択で十分。
- *(C)* 学習/評価関数で最適行動を選ぶ → 過剰設計。

**採用理由**:

- 「魔法を持ってる時に確率的にちゃんと撃つ」が最低限の体験要件。重み付き乱択で 50%/50% (cast/attack) スタートで OK。
- 回復・群体・バフのガード式を加えるだけで「MP 余ってるのに無効な詠唱を撃つ」のを防げる。

### Decision 4: モンスター詠唱のターゲットは詠唱専用ルートで解決し、reach 制限を適用しない

**選択**: スペルキャストは射程概念の外。`MonsterAi.choose` がスペルのキャストを選んだ場合、ENEMY_ONE のターゲット選択でも `can_reach` ガードはかけない。物理攻撃時のみ `can_reach` を見る。

**代替案**:

- *(B)* スペルキャストにも reach ガードをかける → BACK 行のスペル詠唱者が攻撃不能で待機してしまい、AI として無意味。

**採用理由**:

- 既存の `_resolve_attack` の reach ガードは武器の物理射程概念。スペルは別概念で、`SpellEffect.apply` には reach 引数も無い。
- これは Party 側も同じ (Party が BACK の Mage から `fire` を撃つときも reach は無関係)。

### Decision 5: 新規モンスター 6 体のスペック (data-shipped)

| id | row | range | HP範囲 | MP範囲 | atk | def | agi | EXP | gold範囲 | known_spells |
|---|---|---|---|---|---|---|---|---|---|---|
| `witch` | BACK | RANGED | 12-22 | 6-12 | 5 | 3 | 9 | 80 | 30-90 | `fire`, `frost`, `katino` |
| `dark_priest` | BACK | MELEE | 15-26 | 8-14 | 6 | 4 | 7 | 95 | 40-110 | `heal`, `holy`, `badi` |
| `imp` | FRONT | MELEE | 8-16 | 4-8 | 4 | 2 | 11 | 50 | 15-50 | `dazil`, `poison_dart` |
| `lich` | BACK | RANGED | 35-55 | 14-22 | 10 | 7 | 10 | 220 | 180-400 | `flame`, `blizzard`, `madalto` |
| `goblin_shaman` | BACK | MELEE | 10-18 | 5-10 | 5 | 3 | 8 | 65 | 25-70 | `heal`, `manifo` |
| `wraith` | BACK | RANGED | 18-30 | 7-13 | 7 | 5 | 12 | 110 | 60-150 | `poison_dart`, `dazil` |

`resists` は thematic に: undead 系 (`dark_priest`, `lich`, `wraith`) は `&"poison": 1.0` と `&"sleep": 1.0`、`witch` は `&"sleep": 0.50`、`imp` は thematic 無し、`goblin_shaman` は `&"sleep": 0.20` など。これは spec の Requirement 単位で記述する。

### Decision 6: 戦闘画像は透明 PNG ダミーで出荷

**選択**: `assets/images/monsters/<id>.png` に 1x1 透明 PNG (もしくは既存の `slime.png` 等の流用) を置き、`.tres` から `battle_texture` で参照する。`MonsterData` の Requirement 「Battle texture is optional」が既にカバーしているので、null 出荷も可能。

**採用理由**: 仕様検証可能性を優先。本制作画像は後追いで `assets/images/monsters/<id>.png` を上書きするだけ。

## Risks / Trade-offs

- **[Risk] AI が「MP を温存しすぎて全然撃たない」または「最序盤で全部撃ち切って後半物理だけ」になる** → Mitigation: v1 では「MP がある限り 50% で撃つ」ベース。AI ポリシーの調整は `MonsterAi` の単一ファイル内のリテラルを差し替えるだけで済むよう、定数として括り出す。
- **[Risk] side-relative semantics の変更で既存 Party 詠唱テストが壊れる** → Mitigation: テスト側で「caster は party、targets は monsters」前提のシナリオばかりなので、現在の挙動と等価。pre-merge で `tests/combat/test_turn_engine_*.gd` のフル実行を必須化する。
- **[Risk] モンスター MP の永続化** → Mitigation: モンスターは battle 内のみ存在。`Monster` は RefCounted で `battle` のスコープを超えない。セーブには載らない。
- **[Risk] 新モンスターが encounter テーブルに自動で出てしまい既存セーブのバランスを壊す** → Mitigation: 本 change は `MonsterGroupSpec` を触らない。新モンスターは spawn されない。出現追加は別 change。
- **[Trade-off] AI を `MonsterData` に持たせず固定にした結果、「特定モンスターだけ違う AI」を作りたくなったら別 change で profile 引数追加が必要** → 受容。
- **[Trade-off] target_type の side-relative 化で `spell-casting` spec の Requirement テキストが「caster の反対側」のような抽象表現に変わる** → 一度書き換えれば永続的に良い表現になる。

## Migration Plan

1. **Step 1 (フィールド追加)**: `MonsterData` に `max_mp_min` / `max_mp_max` / `known_spells` を `@export` で追加。`.tres` 側は未指定でデフォルト値 (0 / 0 / `[]`) でロードされるように設定する。既存6体の `.tres` は無修正で動く。
2. **Step 2 (Monster ロール)**: `Monster._init` で `max_mp = rng.randi_range(data.max_mp_min, data.max_mp_max)` / `current_mp = max_mp` を追加。`max_mp_min == 0` のときは max_mp == 0 で安全。
3. **Step 3 (MonsterCombatant 解放)**: `_read_max_mp` / `_read_current_mp` / `_write_current_mp` / `spend_mp` を標準実装に置き換え。テスト `test_monster_combatant.gd` のうち「v1 monsters cannot cast」相当のテストを削除/書き換え。
4. **Step 4 (MonsterAi 追加)**: 新規ファイル `src/combat/monster_ai.gd` を TDD で書く。コマンド生成のみの責務 (引数は monster + context + rng, 戻り値は Command)。
5. **Step 5 (TurnEngine 統合)**: モンスター分岐を `MonsterAi.choose(...)` の戻り値を使う形に書き換え。
   - 戻り値が `CastCommand` の場合は既存の `_resolve_cast` フローに乗せる (silence/no_target/no_mp 経路はそのまま動く)。
   - 戻り値が `AttackCommand` の場合は `_resolve_attack` を呼ぶ。
   - null の場合は (reach 不能 MELEE attacker) → 既存の wait action を出す。
6. **Step 6 (side-relative 化)**: `_resolve_cast_targets()` で caster の所属側を見て pool を切り替える。既存 Party テストが壊れないことを確認。
7. **Step 7 (新モンスター出荷)**: 6 種の `.tres` と `assets/images/monsters/*.png` のダミーを追加。`tests/dungeon/test_monster_repository.gd` などのロードテストで新モンスター 6 体が認識されることを assert。
8. **Step 8 (統合テスト)**: TurnEngine レベルで「witch が fire を Party Fighter に詠唱して当たる」「dark_priest が瀕死味方に heal を撃つ」「silenced witch が詠唱しようとして add_cast_silenced になる」などの end-to-end テストを追加。

**Rollback**: 各 step は独立してリバート可能。Step 3 まで進めてから保留にしても、`MonsterData` の新フィールドはオプショナルなので既存挙動は崩れない。Step 5 のリバートは git revert で `TurnEngine.gd` のモンスター分岐を戻すだけ。

## Open Questions

- **(Resolved) ENEMY_GROUP の解釈**: ENEMY_GROUP は「同一 species の敵 ≥2 体」のときだけ AI 候補に入れる方針 (Decision 3 で確定)。1 体なら ENEMY_ONE 系で十分。
- **(Resolved) silence 中のモンスター AI**: silence 中は known_spells が全て使えない (BATTLE_ONLY であっても `blocks_cast` フラグで弾かれる)。`MonsterAi.choose` が candidate を集める時点で「silence なら cast 候補ゼロ」と扱い、自動的に物理攻撃に倒れる。
- **(Open)** モンスター側の `actor_spent_mp` シグナル発火を HUD でどう活かすか — PartyHud は今 Party の MP しか描画していないので影響ゼロ。だが将来「モンスター詠唱の演出」を追加するときの seam として残しておくべきか。本 change では「発火はするが subscribers なし」で OK。
- **(Open)** 新モンスターを encounter テーブルに混ぜるバランス調整 — 本 change の外。次の change で `MonsterGroupSpec` 更新を提案する。
