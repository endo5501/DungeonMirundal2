## Why

残る battle-only 異常 3 種 (confusion / blind / paralysis) を投入し、状態異常システムを完成させる。Phase 1 で既に TurnEngine 内に confusion 差替フック / blind の hit_penalty フック / action_lock フックは敷いてあり、データを置いて呪文を投入するだけで動く。

これにより:
- パーティが confusion を食らうと「同士討ち」のリスクがある
- blind デバフで敵 (or 味方) の命中を下げる戦術が使える
- paralysis は短時間の麻痺で「いったん戦線から外れる」を表現する
- 種族・職業・モンスターの resist チューニングを併せて行い、状態異常システム全体のバランスを整える

## What Changes

- 新規 `data/statuses/confusion.tres` (battle-only)
  - `id = &"confusion"`, `display_name = "混乱"`, `scope = BATTLE_ONLY`
  - `randomizes_target = true`, `cures_on_battle_end = true`, `default_duration = 3`
  - `cures_on_damage = true`（被弾で正気に戻る — JRPG の慣習）
  - `resist_key = &"confusion"`
- 新規 `data/statuses/blind.tres` (battle-only)
  - `id = &"blind"`, `display_name = "暗闇"`, `scope = BATTLE_ONLY`
  - `hit_penalty = 0.20`（attacker が blind のとき hit_chance から 0.20 引く）
  - `cures_on_battle_end = true`, `default_duration = 4`
  - `resist_key = &"blind"`
- 新規 `data/statuses/paralysis.tres` (battle-only)
  - `id = &"paralysis"`, `display_name = "麻痺"`, `scope = BATTLE_ONLY`
  - `prevents_action = true`, `cures_on_battle_end = true`, `default_duration = 2`
  - `resist_key = &"paralysis"`
- 新規呪文 (3 系統 × 各 inflict + cure 系統的に)
  - `data/spells/madalto.tres` (Mage / lv2 / mp=3 / ENEMY_GROUP / BATTLE_ONLY / `StatusInflictSpellEffect status_id=&"confusion" chance=0.5 duration=3`)
  - `data/spells/dumapic.tres` … 既存予約と被るので避ける。代わりに `data/spells/dazil.tres` (Mage / lv1 / mp=2 / ENEMY_ONE / BATTLE_ONLY / `StatusInflictSpellEffect status_id=&"blind" chance=0.55 duration=4`)
  - `data/spells/badi.tres` (Mage / lv3 / mp=5 / ENEMY_ONE / BATTLE_ONLY / `StatusInflictSpellEffect status_id=&"paralysis" chance=0.5 duration=2`)
  - `data/spells/calfo.tres` (Priest / lv1 / mp=2 / ALLY_ONE / OUTSIDE_OK / `CureStatusSpellEffect status_id=&"blind"`) — 視力を取り戻す
  - 「混乱解除」「麻痺解除」は battle-only で `cures_on_battle_end=true` なので戦闘終了で自然回復、 個別解除呪文は本 change では入れない (アイテムでカバー)
- 新規アイテム
  - `data/items/holy_water.tres`（聖水 / `CureAllStatusItemEffect scope=2 (ALL)`）: 値段 600G
  - 戦闘中に味方の混乱・麻痺・暗闇すべてを 1 回で解除する救援アイテム
- `JobData.spell_progression` を更新:
  - Mage: Lv1 → 既存 `[fire, frost]` に `dazil` を追加（合計 3）
  - Mage: Lv2 → 既存に `madalto` を追加（合計 6）
  - Mage: Lv3 → 既存に `badi` を追加（合計 4）
  - Priest: Lv1 → 既存 `[heal, holy]` に `calfo` を追加（合計 3）
  - Bishop: Lv2 / Lv5 を反映
- `RaceData.resists` / `JobData.resists` / `MonsterData.resists` の値設定
  - 種族: Hobbit が `&"sleep"` 0.10、Dwarf が `&"poison"` 0.20 / `&"petrify"` 0.10、Elf が `&"silence"` -0.10 (魔法系で逆に弱い) ＝ Wizardry 風味のチューニング
  - 職業: Priest が `&"silence"` -0.10 (祈りの職業として逆に黙らされやすい)、Mage が `&"silence"` -0.20 (より致命的)、Fighter が `&"sleep"` 0.10
  - モンスター: 代表的な数体に resist を設定 (例: Slime に `&"poison"` 1.0 = 完全免疫、Skeleton に `&"poison"` 1.0 / `&"sleep"` 1.0、Ghost に物理-related 系のフラグなし、典型的な毒モンスター Bat に `&"poison"` 0.50)
  - resist 値の細かいリストは design.md に整理
- `combat-overlay` の `CombatLog` 描画は Phase 2 で `action_locked` 等の文言を定義済。本 change で confusion 用の「{actor_name} は混乱した」「混乱で {target_name} を攻撃した」表現を確認する程度で実コード変更は最小
- `EscMenu` のじゅもんメニュー経由で calfo を撃てる導線確認

## Capabilities

### New Capabilities

- なし

### Modified Capabilities

- `spell-data`: 3 status .tres + 4 呪文 .tres の追加。
- `consumable-items`: holy_water アイテムの追加。
- `job-data`: Mage Lv1/Lv2/Lv3 / Priest Lv1 / Bishop Lv2/Lv5 の spell_progression 更新。
- `race-data`: 種族別の resists 値設定。
- `monster-data`: 代表的なモンスターの resists 値設定。
- `combat-overlay`: confusion による confusion_swap 注釈の log 描画文言を追加。

## Impact

- **影響コード**:
  - 新規 `.tres`: 3 status (confusion / blind / paralysis) + 4 呪文 (dazil / madalto / badi / calfo) + 1 item (holy_water)
  - 改修 `.tres`: races 5 件、jobs 8 件のうち magic-capable 5 件、monsters 全件 (resists 設定)
- **テスト**:
  - 各 status / 呪文 / item の単体テスト
  - 統合テスト: 混乱した party member が味方を殴る、blind の hit_penalty が反映、paralysis の action skip
  - resist テスト: 種族 + 職業合算 / モンスター個別 / clamp 0..1
- **後続依存**: なし。これで状態異常基盤・データの全体が揃う
- **互換性**: 開発段階のためセーブ移行不要
