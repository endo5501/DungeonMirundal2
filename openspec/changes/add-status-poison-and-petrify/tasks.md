## 1. StatusData の ratio フィールド拡張（テスト先行）

- [ ] 1.1 `tests/dungeon/test_status_data.gd` に `tick_in_dungeon_ratio` の存在テストを追加
- [ ] 1.2 `tests/combat/test_status_tick_service.gd` を拡張:
  - ratio=16 / max_hp=32 → loss=2
  - ratio=16 / max_hp=10 → loss=1 (floor)
  - ratio と flat 両方設定 → ratio が優先
  - ratio=0 / flat>0 で flat が使われる
  - ratio=0 / flat=0 で no-op
- [ ] 1.3 `src/combat/statuses/status_data.gd` に `@export var tick_in_dungeon_ratio: int = 0` を追加
- [ ] 1.4 `src/combat/statuses/status_tick_service.gd` を拡張: ratio 優先ロジックを追加
- [ ] 1.5 1.1 / 1.2 のテスト緑

## 2. Status .tres ファイル

- [ ] 2.1 `data/statuses/poison.tres` を作成（Decision 3 のフィールド）
- [ ] 2.2 `data/statuses/petrify.tres` を作成（Decision 4 のフィールド）
- [ ] 2.3 `tests/dungeon/test_status_repository.gd` を更新: 4 件 (sleep / silence / poison / petrify) load される、`find` で各値が取れる

## 3. 呪文 .tres と spell_progression（テスト先行）

- [ ] 3.1 `tests/dungeon/test_spell_data.gd` 等を拡張: poison_dart / madi / dialma の各フィールド検証
- [ ] 3.2 `data/spells/poison_dart.tres` を作成（Mage / lv1 / mp=3 / ENEMY_ONE / BATTLE_ONLY / DamageWithStatusSpellEffect base=3 spread=1 status=&"poison" chance=0.6 duration=0）
- [ ] 3.3 `data/spells/madi.tres` を作成（Priest / lv2 / mp=4 / ALLY_ONE / OUTSIDE_OK / CureStatusSpellEffect status=&"poison"）
- [ ] 3.4 `data/spells/dialma.tres` を作成（Priest / lv3 / mp=6 / ALLY_ONE / OUTSIDE_OK / CureStatusSpellEffect status=&"petrify"）
- [ ] 3.5 `tests/dungeon/test_job_data.gd` を更新: Mage[3] / Priest[3] / Priest[5] / Bishop[5] の新内容
- [ ] 3.6 `data/jobs/mage.tres` を更新: spell_progression[3] に `poison_dart` を追加
- [ ] 3.7 `data/jobs/priest.tres` を更新: spell_progression[3] に `madi` 追加、新しいキー [5] に [dialma]
- [ ] 3.8 `data/jobs/bishop.tres` を更新: spell_progression[5] に `poison_dart, madi` を追加
- [ ] 3.9 `tests/dungeon/test_character.gd` を拡張: Mage Lv2→Lv3 で poison_dart 取得 / Priest Lv2→Lv3 で madi 取得 / Priest Lv4→Lv5 で dialma 取得 / Bishop Lv4→Lv5 で 6 件
- [ ] 3.10 3.1 / 3.5 / 3.9 のテスト緑

## 4. アイテム .tres（テスト先行）

- [ ] 4.1 `tests/items/test_antidote.gd` を新規作成: 戦闘中/外で poison cure / clean target で fail
- [ ] 4.2 `data/items/antidote.tres` を作成
- [ ] 4.3 `tests/items/test_golden_needle.gd` を新規作成: petrify cure / clean target で fail
- [ ] 4.4 `data/items/golden_needle.tres` を作成
- [ ] 4.5 4.1 / 4.3 のテスト緑

## 5. EncounterCoordinator の dungeon tick 通知（テスト先行）

- [ ] 5.1 `tests/dungeon/test_encounter_coordinator.gd` を拡張:
  - `dungeon_status_tick` シグナルが定義されている
  - poisoned member がいる状態で step → 該当キャラの名前 / "poison" / amount が emit
  - 全員 clean なら emit しない
  - HP=2 の poisoned member がいて requested=2 / actual=1 → amount=1 で emit
- [ ] 5.2 `src/dungeon/encounter_coordinator.gd` を改修:
  - `signal dungeon_status_tick(character_name: String, status_id: StringName, amount: int)`
  - `_on_step_taken` 内で StatusTickService を呼び、ticks を loop して emit
- [ ] 5.3 5.1 のテスト緑

## 6. DungeonHUD の通知表示

- [ ] 6.1 `tests/dungeon/test_dungeon_screen.gd` (or HUD 専用 test) に: dungeon_status_tick シグナル受信時に HUD ノードがメッセージを 1 行追加し N 秒後に消える挙動を確認 (Timer モックでテスト)
- [ ] 6.2 `src/dungeon/dungeon_screen.gd` (or HUD 担当) を改修: `EncounterCoordinator.dungeon_status_tick` を購読し、シンプルな Toast 表示を行う
- [ ] 6.3 6.1 緑

## 7. 街帰還時の自動 cure（テスト先行）

- [ ] 7.1 `tests/town_scene/test_town_screen.gd` (or `tests/dungeon/test_dungeon_return.gd`) を拡張:
  - 戻ったときに poisoned / petrified キャラの persistent_statuses が空になる
  - 全員 clean なら通知が出ない
  - 1 人でも cure があれば通知が 1 回出る
- [ ] 7.2 `src/town_scene/town_screen.gd` (or dungeon_return ハンドラ) を改修:
  - 街到着時に `for ch in guild.get_all_characters(): ch.persistent_statuses.clear()` を実行
  - `cured > 0` のとき "教会の祈りで状態異常が癒えた" を表示
- [ ] 7.3 7.1 緑

## 8. TempleScreen ヒント

- [ ] 8.1 `tests/town_scene/test_temple_screen.gd` を拡張: ヒントラベルが存在し "状態異常" の文字列を含む / 蘇生メニューは従来通り動作
- [ ] 8.2 `src/town_scene/temple_screen.gd._rebuild()` にヒント Label を追加
- [ ] 8.3 8.1 緑

## 9. EscMenuStatus の persistent_statuses 表示（テスト先行）

- [ ] 9.1 `tests/esc_menu/test_esc_menu_status.gd` を拡張:
  - 通常状態 → "状態: 通常"
  - poison 1 件 → "状態: 毒"
  - poison + petrify → "状態: 毒, 石化"
- [ ] 9.2 `src/esc_menu/esc_menu_status.gd` を改修: status line を生成・表示
- [ ] 9.3 9.1 緑

## 10. 統合テスト

- [ ] 10.1 `tests/combat/integration/test_status_poison_battle.gd` を新規作成:
  - poison_dart で敵に毒 → 次ターン頭で 1 ダメージ tick → 戦闘終了で poison が persistent として残る (commit_persistent_to_character) — ただし monster は永続化されないので、仲間が毒を受けるシナリオで:
    - mage 仲間に毒を直接 apply (テスト util) → 戦闘終了で character.persistent_statuses に poison が記録
- [ ] 10.2 `tests/dungeon/integration/test_poison_dungeon_walk.gd` を新規作成:
  - poison 持ちの character で 8 step → max_hp/16 × 8 削れる
  - HP=1 で止まる
  - 街帰還で auto-cure
- [ ] 10.3 `tests/combat/integration/test_status_petrify_battle.gd` を新規作成:
  - petrified キャラは action_locked エントリで行動 skip
  - 戦闘後も petrify が残る (cures_on_battle_end=false)
  - 街帰還で cure
- [ ] 10.4 全統合テスト緑

## 11. 全体検証

- [ ] 11.1 `tests/combat/`, `tests/dungeon/`, `tests/items/`, `tests/town_scene/`, `tests/esc_menu/` 全件緑
- [ ] 11.2 ゲーム手動起動: poison_dart で敵を毒、Mage を入れ替えて街→ダンジョンで毒キャラを歩かせて HP 削れを確認、街に戻って治る
- [ ] 11.3 `openspec validate add-status-poison-and-petrify --strict` 成功

## 12. アーカイブ準備

- [ ] 12.1 `/opsx:verify add-status-poison-and-petrify`
- [ ] 12.2 `/opsx:archive add-status-poison-and-petrify`
