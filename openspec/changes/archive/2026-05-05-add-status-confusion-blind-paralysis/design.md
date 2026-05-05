## Context

Phase 1 で TurnEngine 内に以下のフックは敷いてある:
- `has_action_lock()` → action_locked エントリで行動 skip
- `has_confusion_flag()` → AttackCommand のターゲットを random 差し替え、Cast/Item を Attack に変換
- `has_blind_flag()` → DamageCalculator が hit_penalty を引く

つまり 3 つの新 status は「StatusData の `prevents_action / randomizes_target / hit_penalty` を立てる .tres を置く」だけで挙動が完成する。

resist については Phase 1 で `RaceData / JobData / MonsterData.resists` フィールドが追加済 (空 dict)。本 change ではここに具体値を入れて、種族・職業・モンスターの個性を出す。

## Goals / Non-Goals

**Goals:**

- confusion / blind / paralysis の `.tres` を投入して挙動を発火させる
- 各々の inflict 呪文 (dazil / madalto / badi) と blind の cure 呪文 (calfo) を追加
- holy_water (全状態解除アイテム) を追加し、複数 status を一気に解除する救援を成立させる
- 種族 / 職業 / モンスターの resist 値を設定する
- 統合テストで confusion / blind / paralysis のフローを通す

**Non-Goals:**

- AGI バフ・デバフ呪文 (戦術的影響が大きいので追加 change を切る方が安全)
- 状態異常をかける モンスター行動の追加 (敵 AI で sleep をかける等は Phase 別で扱う)
- 教会で個別 cure する有料メニューの再導入
- 状態異常アイコンの combat overlay 表示

## Decisions

### Decision 1: confusion の duration / chance / cures_on_damage

- `default_duration = 3`, madalto の duration も 3
- `cures_on_damage = true` (被弾で正気に戻る — JRPG の慣習)
- chance 0.5 (madalto)。ENEMY_GROUP に対して 0.5 ずつなので 3 体中 1 〜 2 体に効く程度

### Decision 2: blind の duration / chance

- `default_duration = 4`, dazil の duration も 4
- `hit_penalty = 0.20` (attacker 側の hit_chance から引く)
- chance 0.55 (dazil は単体)

### Decision 3: paralysis の duration / chance

- `default_duration = 2`, badi の duration も 2
- 麻痺は強烈なので duration を短く (2 ターン)
- chance 0.5 (badi)、mp=5 で重め

### Decision 4: resist 値の設定

```
data/races/human.tres     resists = {}
data/races/elf.tres       resists = { silence: -0.10, poison: -0.10 }     # 魔法系・体弱い
data/races/dwarf.tres     resists = { poison: 0.20, petrify: 0.10 }       # 鉱夫的に毒・石に強い
data/races/hobbit.tres    resists = { sleep: 0.10, paralysis: 0.10 }      # 落ち着いている
data/races/gnome.tres     resists = { silence: 0.10 }                     # 賢いので沈黙されにくい

data/jobs/fighter.tres    resists = { sleep: 0.10, confusion: 0.10 }      # 集中力がある
data/jobs/mage.tres       resists = { silence: -0.20 }                    # 沈黙されると致命的
data/jobs/priest.tres     resists = { silence: -0.10 }                    # 中程度
data/jobs/thief.tres      resists = { paralysis: 0.10 }                   # 反射神経
data/jobs/ninja.tres      resists = { paralysis: 0.20, sleep: 0.10 }      # 反射神経の最高峰
data/jobs/bishop.tres     resists = {}
data/jobs/samurai.tres    resists = { confusion: 0.10 }
data/jobs/lord.tres       resists = { silence: -0.05 }

# モンスター (代表例; 全件は実装時に決定)
data/monsters/slime.tres       resists = { poison: 1.0, sleep: 0.30 }
data/monsters/skeleton.tres    resists = { poison: 1.0, sleep: 1.0, paralysis: 0.50 }    # アンデッド
data/monsters/ghost.tres       resists = { poison: 1.0, sleep: 1.0, blind: 1.0 }          # 物理的でない
data/monsters/bat.tres         resists = { poison: 0.30, blind: 1.0 }                     # 視覚に頼らない
data/monsters/dragon.tres      resists = { sleep: 0.50, paralysis: 0.30, confusion: 0.50 }
data/monsters/orc.tres         resists = {}
data/monsters/goblin.tres      resists = {}
```

注: race / job の負の resist (例: `silence: -0.10`) は「より掛かりやすい」を表現する。差し引き式なので `effective = chance - resist` のとき resist が負だと effective が増える。

clamp は CombatActor.get_resist 内でも `clamp(value, 0.0, 1.0)` を掛けるが、**負の値は clamp しない**よう挙動を調整する必要がある。Phase 1 の design では `clamp(0, 1)` だったが、ここで負の resist を表現できるように `clamp(-0.5, 1.0)` 程度に緩和するか、もしくは clamp を行わず inflict 側でだけ effective を `clamp(0, 1)` する方が表現力が高い。

**選択**: `CombatActor.get_resist` の clamp を撤廃し（生値を返す）、`StatusInflictSpellEffect` 側で `effective = clamp(chance - resist, 0.0, 1.0)` のみ clamp する。これは Phase 1 spec の MODIFIED として表現する。

### Decision 5: holy_water の挙動

`CureAllStatusItemEffect` で `scope = 2 (ALL)` を採用。これにより 1 個で:
- battle 中: PartyCombatant.statuses から battle-only / persistent 全部を消去
- battle 外: Character.persistent_statuses も消去

価格 600 G。stack_max 3。複数仲間の状態異常を一度に整理できるが値段が高めなので終盤救援用。

### Decision 6: 呪文一覧と spell_progression 更新

| Job | Lv1 既存 | Lv1 追加 | Lv2 既存 | Lv2 追加 | Lv3 既存 | Lv3 追加 |
|-----|----------|----------|----------|----------|----------|----------|
| Mage | fire, frost | **dazil** | katino, manifo, morlis, dilto, sopic | **madalto** | flame, blizzard, poison_dart | **badi** |
| Priest | heal, holy | **calfo** | dios, porfic, bamatu, varyu | (なし) | heala, allheal, madi, maporfic | (なし) |
| Bishop | (なし) | (なし) | (Lv2 既存 13) | **dazil, madalto, calfo** | (Bishop は Lv3 を使わない) | (なし) |
| Bishop Lv5 | (既存 7) | **badi** | | | | |

最終形:

| Job | spell_progression |
|-----|-------------------|
| mage | { 1: [fire, frost, dazil], 2: [katino, manifo, morlis, dilto, sopic, madalto], 3: [flame, blizzard, poison_dart, badi] } |
| priest | { 1: [heal, holy, calfo], 2: [dios, porfic, bamatu, varyu], 3: [heala, allheal, madi, maporfic], 5: [dialma] } |
| bishop | { 2: [fire, frost, heal, holy, katino, manifo, dios, morlis, dilto, sopic, porfic, bamatu, varyu, dazil, madalto, calfo], 5: [flame, blizzard, heala, allheal, poison_dart, madi, maporfic, badi] } |

Bishop Lv2 が 16 件、Lv5 が 8 件と肥大化するが、Bishop の遅咲き・多芸性として許容。

## Risks / Trade-offs

- **[Phase 1 で `CombatActor.get_resist` の clamp(0..1) を入れたのを本 change で外す] → Mitigation**: Phase 1 spec に対して MODIFIED な要件を出す。spec 検証で齟齬がないことを openspec validate で確認。
- **[clamp 撤廃で resist が極端な値 (-1.0 とか) で破綻] → Mitigation**: race / job / monster の `.tres` 値設定で常識的な範囲 (-0.20 〜 +1.00) に収める。inflict 側の `clamp(0, 1)` で破綻はガード可能。
- **[confusion で全員ランダム攻撃すると勝てない試合になる] → Mitigation**: madalto の chance=0.5 / cures_on_damage=true / duration=3 の組み合わせで自然と長期戦化を防ぐ。
- **[paralysis duration=2 が短すぎて意味ない] → 観察事項**: 2 ターン行動不能でも十分強力。気になればチューニング。
- **[Bishop Lv2 で 16 呪文同時取得は派手すぎる] → 観察事項**: Bishop は Lv2 まで魔法ゼロでひたすら堪える設計なので、報酬として許容。
- **[holy_water 600G が安すぎ/高すぎ] → Mitigation**: チューニング対象。stack_max 3 で運用しても問題ないバランスを目指す。

## Migration Plan

開発段階のため移行不要。
