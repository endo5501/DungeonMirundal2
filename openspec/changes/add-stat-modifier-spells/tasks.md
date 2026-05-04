## 1. 呪文 .tres ファイル

- [ ] 1.1 `data/spells/morlis.tres` を作成 (Mage / lv2 / mp=3 / ENEMY_ONE / BATTLE_ONLY / StatModSpellEffect stat=&"defense" delta=-2 turns=4)
- [ ] 1.2 `data/spells/dilto.tres` を作成 (Mage / lv2 / mp=3 / ENEMY_ONE / BATTLE_ONLY / stat=&"evasion" delta=-0.2 turns=4)
- [ ] 1.3 `data/spells/sopic.tres` を作成 (Mage / lv2 / mp=3 / ENEMY_GROUP / BATTLE_ONLY / stat=&"hit" delta=-0.2 turns=4)
- [ ] 1.4 `data/spells/porfic.tres` を作成 (Priest / lv2 / mp=3 / ALLY_ONE / OUTSIDE_OK / stat=&"defense" delta=+2 turns=4)
- [ ] 1.5 `data/spells/bamatu.tres` を作成 (Priest / lv2 / mp=3 / ALLY_ONE / OUTSIDE_OK / stat=&"attack" delta=+2 turns=4)
- [ ] 1.6 `data/spells/varyu.tres` を作成 (Priest / lv2 / mp=3 / ALLY_ONE / OUTSIDE_OK / stat=&"hit" delta=+0.2 turns=4)
- [ ] 1.7 `data/spells/maporfic.tres` を作成 (Priest / lv3 / mp=5 / ALLY_ALL / BATTLE_ONLY / stat=&"defense" delta=+2 turns=4)

## 2. SpellRepository / SpellData 検証（テスト先行）

- [ ] 2.1 `tests/dungeon/test_spell_data.gd` (or 新規) を拡張: 7 本それぞれの school / level / mp_cost / target_type / scope / effect の値検証
- [ ] 2.2 SpellRepository の bulk load で総件数が増えていることを確認

## 3. spell_progression 更新（テスト先行）

- [ ] 3.1 `tests/dungeon/test_job_data.gd` を更新: 新しい配列要素を厳密に検証 (Mage[2]=5件 / Priest[2]=4件 / Priest[3]=4件 / Bishop[2]=13件 / Bishop[5]=7件)
- [ ] 3.2 `data/jobs/mage.tres` を更新: spell_progression[2] に morlis, dilto, sopic を append
- [ ] 3.3 `data/jobs/priest.tres` を更新: spell_progression[2] に porfic, bamatu, varyu を append / [3] に maporfic を append
- [ ] 3.4 `data/jobs/bishop.tres` を更新: spell_progression[2] に 6 本追加 / [5] に maporfic を追加
- [ ] 3.5 `tests/dungeon/test_character.gd` を拡張: 各レベル到達で新呪文取得
- [ ] 3.6 3.1 / 3.5 のテスト緑

## 4. 統合テスト：バフ/デバフがダメージ式に効くこと

- [ ] 4.1 `tests/combat/integration/test_stat_buff_attack.gd`: bamatu (ATK +2) 後、fighter の通常攻撃ダメージが +2 増える (固定 RNG)
- [ ] 4.2 `tests/combat/integration/test_stat_buff_defense.gd`: porfic (DEF +2) 後、被弾ダメージが減る (def/2 = +1)
- [ ] 4.3 `tests/combat/integration/test_stat_debuff_morlis.gd`: morlis (DEF -2) 後、敵への通常攻撃ダメージが +1 増える
- [ ] 4.4 `tests/combat/integration/test_stat_debuff_dilto.gd`: dilto (EVA -0.2) 後、味方の命中チャンスが +0.2 上昇
- [ ] 4.5 `tests/combat/integration/test_stat_debuff_sopic.gd`: sopic (HIT -0.2) 後、敵集団の命中チャンスが -0.2 (味方への被弾減)
- [ ] 4.6 `tests/combat/integration/test_stat_buff_varyu.gd`: varyu (HIT +0.2) 後、命中が +0.2 上昇
- [ ] 4.7 `tests/combat/integration/test_stat_buff_maporfic.gd`: maporfic 後、全ての living party member の DEF が +2

## 5. 持続と消滅のテスト

- [ ] 5.1 `tests/combat/integration/test_stat_buff_decay.gd`: turns=4 のバフが 4 ターン後に消える (sum が 0 に戻る)
- [ ] 5.2 `tests/combat/integration/test_stat_buff_battle_end_clear.gd`: 戦闘終了で modifier_stack.clear_battle_only() が呼ばれて空になる

## 6. 重複付与の β 規則テスト

- [ ] 6.1 `tests/combat/integration/test_stat_buff_beta_rule.gd`:
  - porfic (+2 / 4T) → bamatu (+1 / 5T) を attack に → ATK が +1 (porfic とは別 stat) / DEF は +2 のまま
  - 同 stat: porfic (+2 / 4T) → 他キャラからの porfic (+2 / 4T) を再び → β 規則で同強度 max duration → 4T のまま
  - porfic (+2 / 4T) → 強い (+3 / 1T) → 置換で +3 / 1T

## 7. 全体検証

- [ ] 7.1 `tests/combat/`, `tests/dungeon/`, `tests/items/` 全件緑
- [ ] 7.2 ゲーム手動起動: Lv2 Mage が morlis を撃ってその後の通常攻撃ダメージが上がるか確認、Lv3 Priest が maporfic を撃って画面で 4 行のログが出るか確認
- [ ] 7.3 `openspec validate add-stat-modifier-spells --strict` 成功

## 8. アーカイブ準備

- [ ] 8.1 `/opsx:verify add-stat-modifier-spells`
- [ ] 8.2 `/opsx:archive add-stat-modifier-spells`
