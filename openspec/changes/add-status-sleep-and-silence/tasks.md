## 1. Status .tres ファイル

- [ ] 1.1 `data/statuses/sleep.tres` を作成（Decision 1 のフィールド値）
- [ ] 1.2 `data/statuses/silence.tres` を作成（Decision 2 のフィールド値）
- [ ] 1.3 `tests/dungeon/test_status_repository.gd` を更新: 2 件 load される、`find(&"sleep")` / `find(&"silence")` の値検証
- [ ] 1.4 1.3 のテスト緑

## 2. 呪文 .tres と spell_progression（テスト先行）

- [ ] 2.1 `tests/dungeon/test_spell_data.gd` 等を拡張: katino / manifo / dios の各フィールド検証 (school / level / mp_cost / target_type / scope / effect の型)
- [ ] 2.2 `data/spells/katino.tres` を作成（Mage / lv1 / mp=2 / ENEMY_GROUP / BATTLE_ONLY / StatusInflictSpellEffect status_id=&"sleep" chance=0.6 duration=3）
- [ ] 2.3 `data/spells/manifo.tres` を作成（Mage / lv1 / mp=2 / ENEMY_ONE / BATTLE_ONLY / StatusInflictSpellEffect status_id=&"silence" chance=0.55 duration=4）
- [ ] 2.4 `data/spells/dios.tres` を作成（Priest / lv1 / mp=2 / ALLY_ONE / OUTSIDE_OK / CureStatusSpellEffect status_id=&"sleep"）
- [ ] 2.5 `tests/dungeon/test_job_data.gd` を更新: Mage[2]=[katino, manifo] / Priest[2]=[dios] / Bishop[2]=拡張済 7 件 / Bishop[5]=既存 4 件
- [ ] 2.6 `data/jobs/mage.tres` を更新: `spell_progression[2] = [&"katino", &"manifo"]` を追加
- [ ] 2.7 `data/jobs/priest.tres` を更新: `spell_progression[2] = [&"dios"]` を追加
- [ ] 2.8 `data/jobs/bishop.tres` を更新: `spell_progression[2]` の配列に `[&"katino", &"manifo", &"dios"]` を追加（既存と合算）
- [ ] 2.9 `tests/dungeon/test_character.gd` を拡張: Mage Lv1→Lv2 で katino/manifo 取得、Priest Lv1→Lv2 で dios 取得、Bishop Lv1→Lv2 で 7 件取得
- [ ] 2.10 2.1, 2.5, 2.9 のテスト緑

## 3. wake_powder アイテム（テスト先行）

- [ ] 3.1 `tests/items/test_wake_powder.gd` を新規作成:
  - インベントリに wake_powder を入れて、戦闘中 sleep の party member に使う → cure
  - 戦闘外 (Character.persistent_statuses は sleep を持たない設計だが API パスは通る) で no-op
  - clean な target に使うと success=false
- [ ] 3.2 `data/items/wake_powder.tres` を作成（Decision 6 のフィールド）
- [ ] 3.3 3.1 のテスト緑

## 4. CombatLog 描画（テスト先行）

- [ ] 4.1 `tests/combat/test_combat_log_status_entries.gd` を新規作成: 各エントリ種別が想定文言を生成
- [ ] 4.2 `src/combat/combat_log.gd`（または描画担当ノード）を改修:
  - `tick_damage / wake / inflict / cure / resist / action_locked / cast_silenced / stat_mod` の 8 種を 1 行ずつ描画
  - StatusRepository を遅延ロードして status_display を引く / 失敗時は `String(status_id)` フォールバック
- [ ] 4.3 4.1 のテスト緑

## 5. CombatCommandMenu の silence disable（テスト先行）

- [ ] 5.1 `tests/combat/test_combat_command_menu.gd` を拡張: silence 状態の Mage で Cast 行が disabled になる、Enter で進まない、他コマンドは生きている
- [ ] 5.2 `src/combat/combat_command_menu.gd`（or 同等の UI レイヤ）を改修: combatant が has_silence_flag() のとき Cast 行を disabled でレンダリング、ラベルに "(沈黙中)" 等の suffix
- [ ] 5.3 5.1 のテスト緑

## 6. 統合テスト

- [ ] 6.1 `tests/combat/integration/test_status_sleep_integration.gd` を新規作成:
  - 固定 RNG で katino をスライム3体に → 全員に inflict 試行（成功率に応じた件数）
  - 寝たスライムは action_locked エントリで攻撃しない
  - 寝たスライムが Mage に殴られると wake が出て次ターン行動再開
  - 寝たまま 3 ターン経過すると自然起床
- [ ] 6.2 `tests/combat/integration/test_status_silence_integration.gd` を新規作成:
  - manifo を 敵 Mage 風モンスター（spell を使う将来想定）に当てる ─ 本 change では monster に Cast 経路がないので、manifo の挙動は「party の Cast を阻止する」テストで代用: PartyCombatant に手動で silence を `apply` し、Cast 提出が `cast_silenced` で握り潰される
  - 戦闘終了で silence が cure される
- [ ] 6.3 6.1 / 6.2 緑

## 7. 全体検証

- [ ] 7.1 `tests/combat/`, `tests/dungeon/`, `tests/items/` 全件緑
- [ ] 7.2 ゲーム手動起動: Mage Lv2 で katino を撃ってスライムが寝るか確認、CombatLog に文言が出るか確認
- [ ] 7.3 `openspec validate add-status-sleep-and-silence --strict` 成功

## 8. アーカイブ準備

- [ ] 8.1 `/opsx:verify add-status-sleep-and-silence`
- [ ] 8.2 `/opsx:archive add-status-sleep-and-silence`
