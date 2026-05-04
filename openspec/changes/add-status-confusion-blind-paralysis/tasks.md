## 1. Status .tres ファイル

- [ ] 1.1 `data/statuses/confusion.tres` を作成（Decision 1 のフィールド）
- [ ] 1.2 `data/statuses/blind.tres` を作成（Decision 2 のフィールド）
- [ ] 1.3 `data/statuses/paralysis.tres` を作成（Decision 3 のフィールド）
- [ ] 1.4 `tests/dungeon/test_status_repository.gd` を更新: 7 件 (sleep / silence / poison / petrify / confusion / blind / paralysis) load 検証 / find の各値検証

## 2. 呪文 .tres と spell_progression（テスト先行）

- [ ] 2.1 `tests/dungeon/test_spell_data.gd` を拡張: dazil / madalto / badi / calfo の各フィールド検証
- [ ] 2.2 `data/spells/dazil.tres` を作成
- [ ] 2.3 `data/spells/madalto.tres` を作成
- [ ] 2.4 `data/spells/badi.tres` を作成
- [ ] 2.5 `data/spells/calfo.tres` を作成
- [ ] 2.6 `tests/dungeon/test_job_data.gd` を更新: Mage Lv1/2/3 の新内容 / Priest Lv1 / Bishop Lv2/Lv5 の新内容
- [ ] 2.7 `data/jobs/mage.tres` を更新: Lv1 に dazil / Lv2 に madalto / Lv3 に badi
- [ ] 2.8 `data/jobs/priest.tres` を更新: Lv1 に calfo
- [ ] 2.9 `data/jobs/bishop.tres` を更新: Lv2 に 3 本追加 / Lv5 に badi
- [ ] 2.10 `tests/dungeon/test_character.gd` を拡張: 各 Lv 到達で新呪文取得
- [ ] 2.11 2.1 / 2.6 / 2.10 緑

## 3. アイテム .tres（テスト先行）

- [ ] 3.1 `tests/items/test_holy_water.gd` を新規作成: 全状態同時解除 / clean target で fail
- [ ] 3.2 `data/items/holy_water.tres` を作成
- [ ] 3.3 3.1 緑

## 4. resists の値設定（テスト先行）

- [ ] 4.1 `tests/dungeon/test_race_data.gd` を更新: 5 race の resists 値が design の通り
- [ ] 4.2 `data/races/elf.tres` `dwarf.tres` `hobbit.tres` `gnome.tres` の resists を design 通り更新（human は空のまま）
- [ ] 4.3 `tests/dungeon/test_job_data.gd` を更新: 各 job の resists 値検証
- [ ] 4.4 `data/jobs/fighter.tres` `mage.tres` `priest.tres` `thief.tres` `ninja.tres` `samurai.tres` `lord.tres` の resists を design 通り更新（bishop は空のまま）
- [ ] 4.5 `tests/dungeon/test_monster_data.gd` を更新: 代表モンスター 5 種以上の resists 検証
- [ ] 4.6 `data/monsters/slime.tres` `skeleton.tres` `ghost.tres` `bat.tres` `dragon.tres` の resists を design 通り更新
- [ ] 4.7 4.1 / 4.3 / 4.5 緑

## 5. CombatActor.get_resist の clamp 撤廃（テスト先行）

- [ ] 5.1 `tests/combat/test_combat_actor_status.gd` を更新: race/job 合算で負の値が返る、clamp されない
- [ ] 5.2 `tests/combat/test_status_inflict_spell_effect.gd` を更新: target が負の resist を持つとき effective が増える、clamp 0..1 はインフリクト側で適用
- [ ] 5.3 `src/combat/combat_actor.gd` の `get_resist` を改修: clamp 撤廃 (PartyCombatant / MonsterCombatant 両方)
- [ ] 5.4 5.1 / 5.2 緑

## 6. 統合テスト

- [ ] 6.1 `tests/combat/integration/test_status_confusion_battle.gd`:
  - madalto が敵集団 3 体に → 確率に応じて confusion 付与
  - 混乱した敵が AttackCommand を持っている場合、ターゲットが random に差し替わる (party + monsters から、自分以外)
  - 混乱した敵が Cast を撃とうとしても Attack に置換される
  - 被弾で起き上がる (cures_on_damage)
  - 戦闘終了で全消去
- [ ] 6.2 `tests/combat/integration/test_status_blind_battle.gd`:
  - 攻撃側が blind だと hit_chance が -0.20
  - 最終 clamp 0.05..0.99 でクランプ
  - 戦闘終了で消える
- [ ] 6.3 `tests/combat/integration/test_status_paralysis_battle.gd`:
  - badi が敵に → action_locked エントリで攻撃 skip
  - 2 ターン後に自然回復
  - holy_water で即時解除可能

## 7. 全体検証

- [ ] 7.1 `tests/combat/`, `tests/dungeon/`, `tests/items/` 全件緑
- [ ] 7.2 ゲーム手動起動: madalto / dazil / badi / calfo / holy_water 全部試す
- [ ] 7.3 `openspec validate add-status-confusion-blind-paralysis --strict` 成功

## 8. アーカイブ準備

- [ ] 8.1 `/opsx:verify add-status-confusion-blind-paralysis`
- [ ] 8.2 `/opsx:archive add-status-confusion-blind-paralysis`
