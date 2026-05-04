## Why

Phase 0 で `StatModifierStack` と命中/回避修飾の枠を整え、Phase 1 で `StatModSpellEffect` クラスも実装した。だがこれらを実際に発火させる `.tres` がまだない。Phase 4 ではバフ/デバフ呪文を 8 本投入し、戦闘戦術の幅を増やす。

Wizardry/JRPG 共通の戦術: 「物理アタッカーに ATK/HIT バフをかけて殴る」「ボス戦で DEF/EVA バフを撒いて耐える」「逆にボス側に ATK ダウンを撃って事故を減らす」。これらの最低ラインを揃える。

## What Changes

- 新規呪文 8 本を追加 (Mage 4 / Priest 4)。命名は Wizardry / 軽量 JRPG 風混在
  - Mage 系 (debuff): 敵への減衰呪文 (target = ENEMY_ONE / ENEMY_GROUP)
    - `data/spells/morlis.tres` (Mage / lv2 / mp=3 / ENEMY_ONE / BATTLE_ONLY) — `StatModSpellEffect stat=&"defense" delta=-2 turns=4` 「敵 1 体の防御を下げる」
    - `data/spells/dilto.tres` (Mage / lv2 / mp=3 / ENEMY_ONE / BATTLE_ONLY) — `StatModSpellEffect stat=&"evasion" delta=-0.2 turns=4` 「敵 1 体の回避を下げる」(味方が当てやすくなる)
    - `data/spells/maporfic.tres` の Mage 版は無し（伝統的に Priest 担当）
    - `data/spells/sopic.tres` (Mage / lv2 / mp=3 / ENEMY_GROUP / BATTLE_ONLY) — `StatModSpellEffect stat=&"hit" delta=-0.2 turns=4` 「敵集団の命中を下げる」(被弾減らす守備バフ間接版)
  - Priest 系 (buff): 味方への強化呪文 (target = ALLY_ONE / ALLY_ALL)
    - `data/spells/porfic.tres` (Priest / lv2 / mp=3 / ALLY_ONE / OUTSIDE_OK) — `StatModSpellEffect stat=&"defense" delta=+2 turns=4` 「味方 1 体の防御を上げる」
    - `data/spells/maporfic.tres` (Priest / lv3 / mp=5 / ALLY_ALL / BATTLE_ONLY) — `StatModSpellEffect stat=&"defense" delta=+2 turns=4` 「全員の防御を上げる」
    - `data/spells/bamatu.tres` (Priest / lv2 / mp=3 / ALLY_ONE / OUTSIDE_OK) — `StatModSpellEffect stat=&"attack" delta=+2 turns=4` 「味方 1 体の攻撃を上げる」
  - 共通混合: hit / evasion / agility のバリエーションを Priest 側に1本ずつ
    - `data/spells/halito.tres` 名は既存予約があるかも → 命名は `data/spells/varyu.tres` (Priest / lv2 / mp=3 / ALLY_ONE / OUTSIDE_OK) — `StatModSpellEffect stat=&"hit" delta=+0.2 turns=4` 「味方 1 体の命中を上げる」
- 上記 8 本のうち何本かは **同 stat 異符号のペア** で「両陣営対称な戦術カード」になっている (porfic↔morlis, varyu↔sopic, bamatu↔??-mage_atk_down は今回入れない)
- `JobData.spell_progression` を更新:
  - Mage Lv2 に `morlis, dilto, sopic` を追加（既存 katino, manifo の隣り）
  - Priest Lv2 に `porfic, bamatu, varyu` を追加（既存 dios の隣り）
  - Priest Lv3 に `maporfic` を追加（既存 heala, allheal, madi の隣り）
  - Bishop Lv2 / Lv5 に追加分を反映 (Mage debuff 3 本 + Priest buff 4 本)
- `CombatLog` の `stat_mod` 描画はすでに Phase 2 仕様で 1 行表現が定義されているので、本 change で追加描画は不要
- Phase 0 で予約していた modifier_stack の `clear_battle_only()` 呼び出しが Phase 1 で `_finish_with_battle_end_cleanup` 経由で発火していることを再確認するスモークテストを追加
- 互換性: 開発段階のためセーブ移行は不要

## Capabilities

### New Capabilities

- なし

### Modified Capabilities

- `spell-data`: 8 本の `.tres` 追加と SpellRepository への組み込み。
- `job-data`: Mage Lv2 / Priest Lv2 / Priest Lv3 / Bishop Lv2 / Bishop Lv5 の spell_progression 更新。
- `spell-casting`: ALLY_ALL バフの SpellResolution に複数 stat_mod イベントが入る挙動の明示。
- `combat-overlay`: stat_mod 行のレンダリング描画を Phase 2 仕様で十分かをスモーク確認 (新規要件は出さない)。

## Impact

- **影響コード**:
  - 新規 `.tres`: `data/spells/morlis.tres`, `data/spells/dilto.tres`, `data/spells/sopic.tres`, `data/spells/porfic.tres`, `data/spells/maporfic.tres`, `data/spells/bamatu.tres`, `data/spells/varyu.tres` (計 7 本; 8 本目を整理: `dilto` を入れるなら計 7 = 7 + 1=mage 攻撃ダウン)。
  - **再整理**: Mage 3 本 (morlis, dilto, sopic) + Priest 4 本 (porfic, maporfic, bamatu, varyu) = 7 本。命名がどうしても 8 になりそうなら追加 Mage `katirn = ATK -2 ENEMY_ONE` を入れるが、本 change では 7 本で固定する。
  - 改修: `data/jobs/mage.tres`, `data/jobs/priest.tres`, `data/jobs/bishop.tres`
- **テスト**: 7 本の SpellData テスト / spell_progression / Bishop の追加分 / 統合: ATK バフ後の damage 増加 / DEF バフ後の被ダメージ減 / EVA デバフ後の命中向上 / 4 ターン後にバフが切れる
- **互換性**: 開発段階のためセーブ移行不要
