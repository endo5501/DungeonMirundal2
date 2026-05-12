## 1. MonsterData / Monster (data layer)

- [x] 1.1 `tests/dungeon/test_monster_data.gd` に MP フィールド / known_spells / pre-migration fallback のテストを追加 (Red)
- [x] 1.2 `src/dungeon/data/monster_data.gd` に `@export var max_mp_min: int = 0` / `@export var max_mp_max: int = 0` / `@export var known_spells: Array[StringName] = []` を追加 (Green)
- [x] 1.3 `MonsterData` の validate に `max_mp_min >= 0` および `max_mp_min <= max_mp_max` のチェックを追加 (Green)
- [x] 1.4 `tests/dungeon/test_monster.gd` に「シードを揃えると max_mp が等しい」「MP 0 範囲なら max_mp == 0」のテストを追加 (Red)
- [x] 1.5 `src/dungeon/monster.gd` の `_init` で `max_mp = rng.randi_range(data.max_mp_min, data.max_mp_max)` / `current_mp = max_mp` を追加 (Green)
- [x] 1.6 既存6体 (`slime.tres` 他) を未変更でロードでき、`max_mp == 0` / `known_spells == []` になることをテスト (Red→Green、おそらく 1.2 でそのまま通る)

## 2. MonsterCombatant (combatant layer)

- [x] 2.1 `tests/combat/test_monster_combatant.gd` の v1 "cannot cast" シナリオを削除し、新規シナリオ (MP proxy / spend_mp 標準動作 / 0-MP モンスターは spend_mp(>0)==false) を追加 (Red)
- [x] 2.2 `src/combat/monster_combatant.gd` の `_read_max_mp` / `_read_current_mp` / `_write_current_mp` / `spend_mp` を CombatActor の標準実装に置き換え、Monster.current_mp / Monster.max_mp に委譲 (Green)
- [x] 2.3 「v1 monsters do not have MP」「v1 monsters cannot cast」コメントを削除
- [x] 2.4 既存の Party 詠唱関連テスト (`tests/combat/test_turn_engine_cast*.gd` 等) が全て通ることを確認

## 3. MonsterAi (新規 capability)

- [x] 3.1 `tests/combat/test_monster_ai_context.gd` を新規作成: `MonsterAiContext` のフィールド露出を assert (Red)
- [x] 3.2 `src/combat/monster_ai_context.gd` を実装: `party / monsters / spell_repo / status_repo / turn_engine` を保持する RefCounted DTO (Green)
- [x] 3.3 `tests/combat/test_monster_ai.gd` を新規作成: `MonsterAi.choose` が known_spells 空の場合に AttackCommand を返す (Red)
- [x] 3.4 `src/combat/monster_ai.gd` の最小実装: known_spells 空 → reachable target を rng で選んで AttackCommand (Green)
- [x] 3.5 MELEE BACK + 全 FRONT パーティ生存 → null (wait) ケースをテスト & 実装
- [x] 3.6 全パーティ死亡 → null (skip) ケースをテスト & 実装
- [x] 3.7 candidate filter のテストを追加: MP 不足 / silence / target precondition (ENEMY_ONE, ENEMY_GROUP の同 species 2体, ALLY_ONE heal の HP<max 条件, ALLY_ONE cure の active status 条件)
- [x] 3.8 candidate filter ロジックを `MonsterAi` 内に実装 (`_filter_candidates(monster, ctx, spells) -> Array[SpellData]`)
- [x] 3.9 「candidate が複数 → 一様乱択」のテスト (固定シードで決定的) & 実装
- [x] 3.10 ENEMY_ONE cast の target が「reach 無視で生きてる party からランダム」になるテスト & 実装
- [x] 3.11 ALLY_ONE heal の target が「HP 最低の生存味方」になるテスト & 実装
- [x] 3.12 ALLY_ALL cast の target が null になるテスト & 実装
- [x] 3.13 silenced monster で candidate ゼロ → AttackCommand fallback の統合テスト

## 4. TurnEngine 統合

- [x] 4.1 `tests/combat/test_turn_engine_monster_cast.gd` を新規作成: 「witch が fire を Party Fighter に詠唱して当たる」end-to-end (Red)
- [x] 4.2 `src/combat/turn_engine.gd` のモンスター分岐で `MonsterAi.choose(monster, ctx, rng)` を呼ぶ実装 (Green)
- [x] 4.3 `AttackCommand` 戻り値 → `_resolve_attack` ルートに繋ぐ
- [x] 4.4 `CastCommand` 戻り値 → `_resolve_cast` ルートに繋ぐ。`actor_action_started.emit(monster, &"cast")` を発火させる
- [x] 4.5 `null` 戻り値 → 既存の wait 経路 (MELEE BACK のみ) または skip
- [x] 4.6 「monster cast が actor_spent_mp を発火する」テスト (固定 mp_cost, 固定 caster)
- [x] 4.7 「monster heal が actor_healed(target, amount, monster_caster) を発火する」テスト
- [x] 4.8 「monster cast が damage を与えると actor_dealt_damage(target, amount, monster_caster) を発火する」テスト
- [x] 4.9 「monster の状態異常付与で actor_status_inflicted(target, status_id) を発火する」テスト

## 5. side-relative target resolution

- [x] 5.1 `tests/combat/test_turn_engine_cast_targets.gd` に monster caster ENEMY_ONE / ENEMY_GROUP / ALLY_ONE / ALLY_ALL のターゲット解決テストを追加 (Red)
- [x] 5.2 `TurnEngine._resolve_cast_targets()` を side-relative 化: caster の所属側を見て enemy/ally pool を切り替える (Green)
- [x] 5.3 ENEMY_GROUP で「相手が party の場合」全 living party をターゲットにする実装 & テスト
- [x] 5.4 retarget ロジックも両側対称になることを確認: monster ENEMY_ONE で target が死んだら別 party member へ retarget
- [x] 5.5 monster ALLY_ONE heal で味方が死んだら別 monster へ retarget するテスト & 実装
- [x] 5.6 既存 Party 詠唱テスト群 (`tests/combat/test_turn_engine_cast*.gd`) が全て通ることを確認

## 6. silence / status との相互作用

- [x] 6.1 「silenced witch が CastCommand を submit すると cast_silenced 記録される」テスト & 実装確認 (TurnEngine の既存コードがそのまま機能するはず)
- [x] 6.2 「sleep 中の witch は action_locked で行動できない」テスト & 実装確認
- [x] 6.3 「confusion 中の witch は random target attack に置き換わる」テスト & 実装確認 (TurnEngine の既存 monster 分岐 confusion ロジックが残ることを確認)
- [x] 6.4 「monster cast 中に当該 monster が死ぬと add_cast_silenced/add_defeated 並びが正しい」エッジケーステスト

## 7. 新規モンスター .tres 出荷

- [x] 7.1 `assets/images/monsters/` にダミー画像 6 枚 (witch.png / dark_priest.png / imp.png / lich.png / goblin_shaman.png / wraith.png) を配置 (透明 PNG または既存資産流用)
- [x] 7.2 `data/monsters/witch.tres` を作成: BACK / RANGED, MP 6-12, known_spells = [fire, frost, katino], resists = {sleep: 0.30}
- [x] 7.3 `data/monsters/dark_priest.tres` を作成: BACK / MELEE, MP 8-14, known_spells = [heal, holy, badi], resists = {poison: 1.0, sleep: 1.0}
- [x] 7.4 `data/monsters/imp.tres` を作成: FRONT / MELEE, MP 4-8, known_spells = [dazil, poison_dart], resists = {}
- [x] 7.5 `data/monsters/lich.tres` を作成: BACK / RANGED, MP 14-22, known_spells = [flame, blizzard, madalto], resists = {poison: 1.0, sleep: 1.0, paralysis: 0.50}
- [x] 7.6 `data/monsters/goblin_shaman.tres` を作成: BACK / MELEE, MP 5-10, known_spells = [heal, manifo], resists = {sleep: 0.20}
- [x] 7.7 `data/monsters/wraith.tres` を作成: BACK / RANGED, MP 7-13, known_spells = [poison_dart, dazil], resists = {poison: 1.0, sleep: 1.0, blind: 1.0}
- [x] 7.8 `tests/dungeon/test_monster_repository.gd` (または相当) に「新規 6 体が `find(<id>)` で取得できる」テストを追加
- [x] 7.9 新規 6 体が `known_spells` の最安 spell.mp_cost を必ず満たす MP 範囲を持つことの spec scenario をテスト化

## 8. 統合テストと QA

- [x] 8.1 end-to-end 統合テスト: witch + slime のエンカウントで `MonsterAi` が確率的に fire を撃つ (固定シードで再現)
- [x] 8.2 end-to-end 統合テスト: dark_priest + imp の片方が瀕死で dark_priest が heal を撃つ
- [x] 8.3 end-to-end 統合テスト: lich + slime x3 で lich が flame (ENEMY_GROUP) を撃ち、全 living party に当たる
- [x] 8.4 `scripts/run_tests.ps1` 全実行で通すこと (parse error / SCRIPT ERROR ゼロ)
- [x] 8.5 既存テストの regression check: `tests/combat/test_turn_engine*.gd` / `tests/combat/test_monster_combatant.gd` / `tests/dungeon/test_monster*.gd` が全て pass

## 9. ドキュメントとレビュー

- [x] 9.1 各 spec ファイルの "Pre-migration" シナリオで slime.tres など既存6体が無修正で通ることを確認 (実環境テスト) — `test_existing_six_monsters_load_with_zero_mp_and_empty_spells` で確認済
- [x] 9.2 `proposal.md` の Out-of-scope を再確認: encounter テーブル変更、蘇生魔法、本制作画像 は次 change へ — 確認済 (MonsterGroupSpec 未変更)
- [x] 9.3 CHANGELOG / commit メッセージドラフト — commit 時にユーザに合意確認
- [x] 9.4 self code review (`superpowers:requesting-code-review` 相当の観点で確認) — MonsterAi の冗長 return 文を簡素化、TurnEngine の non-MonsterCombatant fallback を確認
