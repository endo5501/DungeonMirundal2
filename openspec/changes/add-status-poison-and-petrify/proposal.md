## Why

Phase 2 で battle-only な状態異常（sleep / silence）を入れた。次は **永続異常** (poison / petrify) を入れて、ダンジョン探索のリスクと「街に戻る重要性」を導入する。これにより:
- 毒モンスターから受けた毒で、ダンジョン奥に進むほど HP が削れていく緊張感
- 石化した仲間を抱えて街に戻り、解除する戦略
- 教会の存在意義が「蘇生」だけから「状態回復もできる場所」へ広がる

Wizardry の poison は dungeon step ごとに `max_hp/16` 程度の HP 削りで実質的なターン制限として機能した。同じモデルを採用する。これに伴い `StatusData` に「割合 tick」を表現するフィールドを追加する。

## What Changes

- `StatusData` にフィールド `tick_in_dungeon_ratio: int` を追加する（**Phase 1 で導入したスキーマの拡張**）
  - `> 0` のとき、step ごとの HP 損失は `max(1, floor(max_hp / ratio))`
  - `0` のとき、既存の `tick_in_dungeon` （平 HP 値）が使われる
  - 両方 0 のときは tick なし
  - `tick_in_dungeon_ratio` が優先される
- `StatusTickService.tick_character_step` を上記ロジックに対応させる（floor at HP=1 の挙動は維持）
- 新規 `data/statuses/poison.tres`（永続異常 / battle・dungeon 双方で tick / cures_on_battle_end=false）
  - `id = &"poison"`, `display_name = "毒"`, `scope = PERSISTENT`
  - `tick_in_battle = 1`（戦闘中のターン頭で固定 1 ダメージ）
  - `tick_in_dungeon = 0`, `tick_in_dungeon_ratio = 16`（探索フェーズで合意した max_hp/16）
  - `cures_on_damage = false`, `cures_on_battle_end = false`
  - `default_duration` は無視（PERSISTENT は cure 専用）
  - `resist_key = &"poison"`
- 新規 `data/statuses/petrify.tres`（永続異常 / 行動完全停止 / 戦闘でも持続）
  - `id = &"petrify"`, `display_name = "石化"`, `scope = PERSISTENT`
  - `prevents_action = true`, `cures_on_battle_end = false`
  - `tick_in_battle = 0`, `tick_in_dungeon = 0`, `tick_in_dungeon_ratio = 0`
  - `resist_key = &"petrify"`
- 新規呪文
  - `data/spells/poison_dart.tres` (Mage / lv1 / mp_cost=3 / ENEMY_ONE / BATTLE_ONLY / `DamageWithStatusSpellEffect base_damage=3 spread=1 status_id=&"poison" inflict_chance=0.6 status_duration=0`)
    - 毒のダメージ呪文（探索フェーズで「あった方が良い」と決定済）
    - PERSISTENT scope のため status_duration は実際には使われない (sentinel に置換される)
  - `data/spells/madi.tres` (Priest / lv2 / mp_cost=4 / ALLY_ONE / OUTSIDE_OK / `CureStatusSpellEffect status_id=&"poison"`)
    - 解毒呪文
  - `data/spells/dialma.tres` (Priest / lv3 / mp_cost=6 / ALLY_ONE / OUTSIDE_OK / `CureStatusSpellEffect status_id=&"petrify"`)
    - 石化解除呪文（高位）
- 新規アイテム
  - `data/items/antidote.tres`（解毒草）: `CureStatusItemEffect status_id=&"poison"`、価格 100G
  - `data/items/golden_needle.tres`（金の針）: `CureStatusItemEffect status_id=&"petrify"`、価格 1500G
- `JobData.spell_progression` を更新:
  - Mage: Lv3 → 既存 `[flame, blizzard]` に `poison_dart` を追加（合計 3）
  - Priest: Lv3 → 既存 `[heala, allheal]` に `madi` を追加（合計 3）
  - Priest: 新規 Lv5 を追加し `[dialma]`
  - Bishop: 既存 Lv5 → 新呪文を追加（poison_dart, madi）。dialma は Lv5 ではなく **Bishop は dialma を覚えない**（Lord と同様、伝統的に高位治療は Priest 専用）
- ダンジョン step tick の通知 UI
  - Phase 1 で `EncounterCoordinator._on_step_taken` から `StatusTickService.tick_character_step` を呼ぶ経路は敷いた
  - 本 change で初めて実 status (`poison`) が tick > 0 を持つので、毒持ちパーティのダンジョン徒歩で実際に HP が減ること、HP=1 で止まることを統合テストで検証
  - `EncounterCoordinator` から `dungeon_status_tick` シグナルを発火し、`DungeonHUD` で「Alice は毒で 2 ダメージ」のような 1 行通知を 2 秒程度表示
- `TempleScreen` の拡張
  - 既存の蘇生メニューに加えて「状態回復」のヒント (「街に戻ると状態異常は自動回復します」) を表示
  - 実処理: `town_scene/town_screen.gd` の `_on_entered_town` (or 同等) で `for ch in guild.get_all_characters(): ch.persistent_statuses.clear()` を実行する街帰還時の自動処理を実装
  - これにより教会で別途解除する手間は不要 (探索フェーズで「街へ戻ると回復」決定済)
- `EscMenuStatus` のキャラ詳細に `persistent_statuses` を 1 行表示
  - 例: `状態: 毒, 石化` / 何もなければ `状態: 通常`
  - status_id → display_name は StatusRepository 経由
- 互換性: 開発段階のためセーブ移行不要

## Capabilities

### New Capabilities

- なし

### Modified Capabilities

- `status-effects`: `StatusData.tick_in_dungeon_ratio` フィールドの追加と `StatusTickService.tick_character_step` の divisor 対応。
- `spell-data`: poison_dart / madi / dialma の存在を spec に明記。
- `consumable-items`: antidote / golden_needle の存在を spec に明記。
- `job-data`: Mage Lv3 / Priest Lv3 / Priest Lv5 / Bishop Lv5 の spell_progression 更新。
- `temple`: 「街帰還時の自動 cure」を伝えるヒント表示の追加と、教会自体は status cure を行わないことの明確化。
- `dungeon-return` (or `town-screen`): 街に戻った瞬間に全パーティの persistent_statuses を空にする責務を追加。
- `dungeon-movement`: step ごとの persistent status tick が `EncounterCoordinator` 経由で実 status `poison` に対して発火し、HUD 通知を出す責務を追加。
- `esc-menu-overlay`: パーティメンバー詳細に persistent_statuses を 1 行表示する責務を追加。
- `consumable-items`: antidote / golden_needle の挙動。

## Impact

- **影響コード**:
  - 新規 `.tres`: `data/statuses/poison.tres`, `data/statuses/petrify.tres`, `data/spells/poison_dart.tres`, `data/spells/madi.tres`, `data/spells/dialma.tres`, `data/items/antidote.tres`, `data/items/golden_needle.tres`
  - 改修 `.tres`: `data/jobs/mage.tres`, `data/jobs/priest.tres`, `data/jobs/bishop.tres`
  - 改修コード: `src/combat/statuses/status_data.gd`（フィールド追加）, `src/combat/statuses/status_tick_service.gd`（ratio 対応）, `src/dungeon/encounter_coordinator.gd`（dungeon tick 通知シグナル）, `src/dungeon/dungeon_screen.gd`（HUD 表示）, `src/town_scene/town_screen.gd`（街帰還時の auto-cure フック）, `src/town_scene/temple_screen.gd`（ヒント表示）, `src/esc_menu/esc_menu_status.gd`（persistent_statuses 行）
- **テスト**:
  - 統合: 毒で HP が削れる / HP=1 で止まる / 街に戻ると治る / poison_dart の damage+inflict / antidote の cure / golden_needle の cure / temple の状態回復ヒント表示
  - 単体: StatusTickService の ratio ロジック / `tick_in_dungeon` と `tick_in_dungeon_ratio` の優先順位
- **互換性**: 開発段階のためセーブ移行不要
