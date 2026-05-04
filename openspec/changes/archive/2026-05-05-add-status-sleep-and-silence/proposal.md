## Why

Phase 1 で StatusData / StatusTrack / events list / 新エフェクト4種の土管が通った。次は実 status を載せて、戦闘に最初の戦術的厚みを足す段階。Wizardry 系統の戦闘は「katino で寝かせて固定砲台にする」「manifo で敵モンクを黙らせる」が定番の魔法戦術で、土管に最初に流すべき水としてふさわしい。本 change では battle-only 異常 2 種 (sleep / silence) と、それぞれを付与/解除する呪文・アイテム、そして CombatLog / overlay の最低限の表示を導入する。

## What Changes

- 新規 `data/statuses/sleep.tres` を追加
  - `id = &"sleep"`, `display_name = "睡眠"`, `scope = BATTLE_ONLY`
  - `prevents_action = true` / `cures_on_damage = true` / `cures_on_battle_end = true`
  - `default_duration = 3` / `tick_in_battle = 0` / `tick_in_dungeon = 0`
  - `randomizes_target = false` / `blocks_cast = false` / `hit_penalty = 0.0`
  - `resist_key = &"sleep"`
- 新規 `data/statuses/silence.tres` を追加
  - `id = &"silence"`, `display_name = "沈黙"`, `scope = BATTLE_ONLY`
  - `blocks_cast = true` / `cures_on_battle_end = true` / `default_duration = 4`
  - `resist_key = &"silence"`
- 新規呪文 `data/spells/katino.tres` を追加（mage / lv1 / mp_cost=2 / ENEMY_GROUP / BATTLE_ONLY / StatusInflictSpellEffect: status_id=&"sleep", chance=0.6, duration=3）
- 新規呪文 `data/spells/manifo.tres` を追加（mage / lv1 / mp_cost=2 / ENEMY_ONE / BATTLE_ONLY / StatusInflictSpellEffect: status_id=&"silence", chance=0.55, duration=4）
- 新規呪文 `data/spells/dios.tres` を追加（priest / lv1 / mp_cost=2 / ALLY_ONE / OUTSIDE_OK / CureStatusSpellEffect: status_id=&"sleep"）
  - 「眠っている味方を起こす」用の呪文。回復系 priest の汎用治療呪文 (latumofis) は次 change で
- 新規アイテム `data/items/wake_powder.tres` を追加（覚醒の粉: CureStatusItemEffect status_id=&"sleep"）
  - 戦闘内/外両方で使える消費アイテム
- `JobData.spell_progression` を更新:
  - Mage: Lv2 → `[katino, manifo]` を追加
  - Priest: Lv2 → `[dios]` を追加
  - Bishop: 既存 Lv2 → `[katino, manifo, dios]` を追加（fire/frost/heal/holy はそのまま）
  - 注: 既存の Lv1 / Lv3 / Lv5 / Lv8 のエントリは触らない
- `CombatCommandMenu`（or 同等の UI）で actor が silence のときに「呪文」コマンドを **disable 表示**（grey out）にする — 選んでも resolution 時に握り潰されるが、入力時に視覚的にフィードバックを出す
- `CombatLog` の描画拡張:
  - `tick_damage` / `wake` / `inflict` / `cure` / `resist` / `action_locked` / `cast_silenced` の各 TurnReport エントリを 1 行ずつ表示
  - 表現例: 「アリスは眠ってしまった」「アリスは目を覚ました」「ゴブリンは沈黙した」「ボブは唱えようとしたが声が出ない」「アリスは眠っていて行動できない」
- `EscMenuOverlay` のじゅもんメニューから dios を撃てる導線（既存 OUTSIDE_OK 経路に乗る）を確認
- `tests/combat/integration/` 配下に「katino でスライムを寝かせて被弾でない限り起きないことを 3 ターン回す」などの統合シナリオを追加

## Capabilities

### New Capabilities

- なし（status-effects spec は Phase 1 で成立済。本 change は実データ追加とログ表現の規定のみ）

### Modified Capabilities

- `combat-overlay`: CombatLog が新エントリ種別 (tick_damage / wake / inflict / cure / resist / action_locked / cast_silenced) を 1 行表示する責務、コマンドメニューが silence 状態のとき「呪文」を disable 表示する責務。
- `spell-data`: katino / manifo / dios の 3 つの新呪文 `.tres` の存在と、Mage / Priest / Bishop の `spell_progression` への組み込み。
- `consumable-items`: wake_powder アイテムの存在と効果。
- `job-data`: Mage / Priest / Bishop の `spell_progression` 更新（Lv2 で 1〜3 件の新呪文を取得）。
- `spell-casting`: BATTLE_ONLY scope な OUTSIDE_OK でない呪文 (katino / manifo) と、OUTSIDE_OK な status 系呪文 (dios) の両方が既存ルールで動くことを再確認する規定（実際には既存 spec の挙動に新呪文が乗るだけ）。

## Impact

- **影響コード**:
  - 新規 `.tres`: `data/statuses/sleep.tres`, `data/statuses/silence.tres`, `data/spells/katino.tres`, `data/spells/manifo.tres`, `data/spells/dios.tres`, `data/items/wake_powder.tres`
  - 改修: `data/jobs/mage.tres`, `data/jobs/priest.tres`, `data/jobs/bishop.tres`（spell_progression）
  - 改修: `src/combat/combat_command_menu.gd`（silence 時の Cast disable）
  - 改修: `src/combat/combat_log.gd`（新エントリ描画）
- **テスト**:
  - `tests/combat/test_status_sleep_integration.gd`: katino → 寝た → ターン頭で行動 skip → 被弾で起床
  - `tests/combat/test_status_silence_integration.gd`: manifo → 沈黙 → Cast 握り潰し → 戦闘終了で解除
  - `tests/combat/test_combat_command_menu.gd`: silence 状態で Cast 行が disable 表示
  - `tests/combat/test_combat_log_status_entries.gd`: 各エントリ種別の 1 行表現
  - `tests/items/test_wake_powder.gd`: 戦闘中/外で sleep を解除
- **後続依存**: なし（Phase 3 / 4 / 5 と独立）
- **互換性**: 開発段階のためセーブ移行は不要。既存 Mage / Priest / Bishop の Lv2 到達キャラは known_spells が拡張されるが、from_dict の `known_spells` 復元はそのまま動く（追加分は再ログイン時に level_up を経由して反映）。
