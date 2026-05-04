## 1. StatusData / StatusRepository（テスト先行）

- [ ] 1.1 `tests/dungeon/test_status_data.gd` を新規作成: 必須フィールドの存在、Scope enum 値、scope/prevents_action/randomizes_target/blocks_cast/hit_penalty/default_duration/tick_in_battle/tick_in_dungeon/cures_on_damage/cures_on_battle_end/resist_key の readability
- [ ] 1.2 `tests/dungeon/test_status_repository.gd` を新規作成: id 検索、不在は null、bulk load の件数、has_id
- [ ] 1.3 `tests/dungeon/test_data_loader.gd` を拡張: `load_status_repository()` 存在、二度呼び出しでキャッシュが効く
- [ ] 1.4 `src/combat/statuses/status_data.gd` を新規実装: `class_name StatusData extends Resource`、`enum Scope`、各 @export
- [ ] 1.5 `src/dungeon/data/status_repository.gd` を新規実装: dict ベース id → StatusData、`has_id`
- [ ] 1.6 `src/dungeon/data/data_loader.gd` に `load_status_repository()` を追加（初回のみ disk スキャン、以降キャッシュ返却）
- [ ] 1.7 1.1〜1.3 のテストが緑になることを確認（実 .tres は積まないので bulk load は 0 件で OK）

## 2. StatusTrack 基盤（テスト先行）

- [ ] 2.1 `tests/combat/test_status_track.gd` を新規作成:
  - 空 apply / has で見える
  - apply で同 id, 大きい duration を採用
  - apply で同 id, 小さい duration を拒否
  - PERSISTENT_DURATION sentinel が DURATION 上書きを拒否
  - cure 成功 (true) / cure 失敗 (false)
  - active_ids() が StringName 配列を返す
  - cure_all_battle_only(repo) で BATTLE_ONLY のみ消去 / 戻り値に消去 id 列
  - tick_battle_turn(actor, repo): tick HP 減量、`killed_by_tick` 検出、duration decrement、PERSISTENT は decrement されない
  - handle_damage_taken(actor, repo) で cures_on_damage の status を消去
- [ ] 2.2 `src/combat/statuses/status_track.gd` を新規実装: 上記 API に従う
- [ ] 2.3 2.1 のテスト緑を確認

## 3. StatusTickService（テスト先行）

- [ ] 3.1 `tests/combat/test_status_tick_service.gd` を新規作成:
  - 死亡キャラはスキップ (total_loss 0)
  - PERSISTENT 以外の status は無視
  - tick_in_dungeon=3 / hp=5 → loss=3, hp=2
  - tick_in_dungeon=3 / hp=2 → loss=1, hp=1（floor）
  - tick_in_dungeon=3 / hp=1 → loss=0, hp=1
  - 複数 status 持ちの合算
- [ ] 3.2 `src/combat/statuses/status_tick_service.gd` を新規実装: static method 1 個
- [ ] 3.3 3.1 のテスト緑を確認

## 4. CombatActor の status 統合（テスト先行）

- [ ] 4.1 `tests/combat/test_combat_actor_status.gd` を新規作成:
  - `statuses` プロパティの存在と初期化
  - `has_silence_flag/has_confusion_flag/has_action_lock/has_blind_flag` がフラグセットに応じて切り替わる（テスト用に StatusRepository を test util から差し込む）
  - `get_resist` のデフォルト 0.0
- [ ] 4.2 `src/combat/combat_actor.gd` 改修:
  - `var statuses := StatusTrack.new()`
  - `has_silence_flag/has_confusion_flag/has_action_lock` をリポジトリ照会で実装
  - `has_blind_flag` を `statuses.has(&"blind")` に変更
  - `get_resist(resist_key) -> float` を default 0.0 で追加
- [ ] 4.3 `src/combat/party_combatant.gd` 改修:
  - constructor で `character.persistent_statuses` を `statuses.apply(sid, PERSISTENT_DURATION)` で seed
  - `get_resist(resist_key)` を race+job 加算+clamp で実装
  - `commit_persistent_to_character(repo)` を追加（PERSISTENT のみ Character へ書き戻し）
- [ ] 4.4 `src/combat/monster_combatant.gd` 改修: `get_resist(resist_key)` を MonsterData から実装
- [ ] 4.5 4.1 のテスト緑を確認、`tests/combat/test_party_combatant.gd` / `tests/combat/test_monster_combatant.gd` の互換確認

## 5. RaceData / JobData / MonsterData の resists（テスト先行）

- [ ] 5.1 `tests/dungeon/test_race_data.gd` 等に `resists` フィールドのデフォルト存在テストを追加
- [ ] 5.2 同様に test_job_data.gd / test_monster_data.gd に追加
- [ ] 5.3 `src/dungeon/data/race_data.gd` に `@export var resists: Dictionary = {}` を追加
- [ ] 5.4 `src/dungeon/data/job_data.gd` に同上
- [ ] 5.5 `src/dungeon/data/monster_data.gd` に同上
- [ ] 5.6 既存 `data/races/*.tres` (5 件) に `resists = {}` を追加（Godot エディタ側操作 or テキスト編集）
- [ ] 5.7 既存 `data/jobs/*.tres` (8 件) に同上
- [ ] 5.8 既存 `data/monsters/*.tres` の各ファイルに同上（件数は実装時に grep）
- [ ] 5.9 5.1〜5.2 のテスト緑、起動時 `DataLoader.load_*` で全件 load 成功

## 6. Character.persistent_statuses（テスト先行）

- [ ] 6.1 `tests/dungeon/test_character.gd` を拡張: 新規キャラの `persistent_statuses` 初期値が `[]`
- [ ] 6.2 `tests/save_load/test_main_save_load.gd` 等に: to_dict で persistent_statuses が含まれる、from_dict で StringName に正規化される、不在キーは空配列で扱う
- [ ] 6.3 `src/dungeon/character.gd` に `var persistent_statuses: Array[StringName] = []` を追加
- [ ] 6.4 `Character.to_dict` を改修: `"persistent_statuses": [String(s) for s in persistent_statuses]` を追加
- [ ] 6.5 `Character.from_dict` を改修: `data.get("persistent_statuses", [])` から StringName 配列を復元
- [ ] 6.6 6.1〜6.2 のテスト緑

## 7. SpellResolution の events 拡張（テスト先行）

- [ ] 7.1 `tests/combat/test_spell_resolution.gd` を新規作成 / 拡張: 各 entry に `events: Array` がある、`add_entry` の戻り値が同じ Dictionary を指す、format_entries は既存と同じ表示
- [ ] 7.2 `src/combat/spells/spell_resolution.gd` を改修: entries の各要素に `events: []` キーを追加し、`add_entry` を `Dictionary` 戻り型に変更
- [ ] 7.3 既存 `DamageSpellEffect` / `HealSpellEffect` を改修: `add_entry` の戻り値に `events.append({type: "damage"|"heal", amount: int})` を入れる
- [ ] 7.4 既存テスト (`test_spell_effects.gd`) が緑のまま、新規 events テストも緑

## 8. 新 SpellEffect 4 種（テスト先行）

- [ ] 8.1 `tests/combat/test_status_inflict_spell_effect.gd` を新規作成:
  - StatusRepository をテスト用に差し込み
  - chance=0.6, resist=0.2, roll=30 → 命中 / statuses.has(...) true / inflict event
  - 同条件で roll=45 → 失敗 / resist event
  - StatusData.scope==PERSISTENT のとき duration が PERSISTENT_DURATION 入る
- [ ] 8.2 `src/combat/spells/status_inflict_spell_effect.gd` を新規実装
- [ ] 8.3 `tests/combat/test_damage_with_status_spell_effect.gd` を新規作成:
  - ダメージ + inflict 両方のイベントが entry に積まれる
  - target が damage で死ぬと inflict は実行されない
- [ ] 8.4 `src/combat/spells/damage_with_status_spell_effect.gd` を新規実装
- [ ] 8.5 `tests/combat/test_stat_mod_spell_effect.gd` を新規作成:
  - target.modifier_stack.add(...) が呼ばれる
  - β 規則で重複時の挙動 (combat-actor 側の振る舞いに準拠)
  - stat_mod event が積まれる
- [ ] 8.6 `src/combat/spells/stat_mod_spell_effect.gd` を新規実装
- [ ] 8.7 `tests/combat/test_cure_status_spell_effect.gd` を新規作成: cure 成功で event 出力 / 既に cleanな target は no-op
- [ ] 8.8 `src/combat/spells/cure_status_spell_effect.gd` を新規実装
- [ ] 8.9 8.1/8.3/8.5/8.7 のテスト緑

## 9. 新 ItemEffect 2 種（テスト先行）

- [ ] 9.1 `tests/items/test_cure_status_item_effect.gd` を新規作成:
  - 戦闘中 PartyCombatant 経由で statuses.cure
  - 戦闘外 Character 経由で persistent_statuses から削除
  - cleanな target は失敗
- [ ] 9.2 `src/items/effects/cure_status_item_effect.gd` を新規実装
- [ ] 9.3 `tests/items/test_cure_all_status_item_effect.gd` を新規作成:
  - scope=ALL で全消去
  - scope=PERSISTENT で BATTLE_ONLY は残る
- [ ] 9.4 `src/items/effects/cure_all_status_item_effect.gd` を新規実装
- [ ] 9.5 9.1/9.3 のテスト緑

## 10. TurnReport の新エントリ種別（テスト先行）

- [ ] 10.1 `tests/combat/test_turn_report.gd` を拡張: add_tick_damage / add_wake / add_inflict / add_cure / add_resist / add_stat_mod / add_action_locked / add_cast_silenced の各エントリ形式
- [ ] 10.2 `src/combat/turn_report.gd` に上記 8 メソッドを追加（既存メソッドは無変更）
- [ ] 10.3 10.1 のテスト緑

## 11. TurnEngine のフロー改修（テスト先行）

- [ ] 11.1 `tests/combat/test_turn_engine_status.gd` を新規作成:
  - status_repo の lazy load + 注入
  - ターン頭 tick: tick_in_battle>0 で actor が damage を受け、TurnReport に tick_damage が出る
  - ターン頭 tick で全滅 → 行動ループ skip / WIPED で終了
  - has_action_lock のとき行動 skip + action_locked エントリ
  - has_silence_flag のとき CastCommand 握り潰し + cast_silenced エントリ / MP 不変
  - has_confusion_flag のとき AttackCommand のターゲットが random replace（party+monsters 全員から、自分以外）
  - has_confusion_flag のとき CastCommand → AttackCommand に置換、MP 不変
  - has_confusion_flag のとき ItemCommand → AttackCommand に置換、Item 不消費
  - 戦闘終了時: cure_all_battle_only / commit_persistent_to_character / clear_battle_only すべて呼ばれる
  - 攻撃で damage 与えた直後 handle_damage_taken が呼ばれ wake event が記録される
- [ ] 11.2 `src/combat/turn_engine.gd` を改修:
  - `var status_repo: StatusRepository = null` フィールド追加
  - `get_status_repo()` lazy loader（既存 `get_spell_repo` と同型）
  - `resolve_turn` 冒頭で全 actor に `tick_battle_turn` を呼ぶ → tick_damage を report に積む → 全滅判定 → `_finish_with_battle_end_cleanup`
  - 行動順走査内で `has_action_lock` / `has_silence_flag` / `has_confusion_flag` をチェック
  - confusion 用 helper `_swap_to_random_attack(actor, rng) -> AttackCommand` を追加
  - 各 take_damage 後に `actor.statuses.handle_damage_taken(actor, status_repo)` を呼んで wake を report に積む
  - `_finish_with_battle_end_cleanup(report, result)` を新設（cure_all_battle_only / commit_persistent_to_character / clear_battle_only / _finish）
  - 既存 `_finish` 直叩き経路すべてを `_finish_with_battle_end_cleanup` 経由に置換
- [ ] 11.3 既存 `tests/combat/test_turn_engine.gd` の互換確認（modifier_stack 0 / statuses 空のとき従来挙動）
- [ ] 11.4 11.1 の新シナリオ全件緑

## 12. EncounterCoordinator のダンジョン step tick（テスト先行）

- [ ] 12.1 `tests/dungeon/test_encounter_coordinator.gd` を拡張: step_taken でパーティ各キャラに `StatusTickService.tick_character_step` が呼ばれる（モック character の persistent_statuses が空ならノーオプ）
- [ ] 12.2 `src/dungeon/encounter_coordinator.gd` に `set_status_repo(repo)` と `set_guild(guild)` を追加し、`_on_step_taken` 内でパーティ全員へ tick を呼ぶ
- [ ] 12.3 12.1 のテスト緑

## 13. 全体検証

- [ ] 13.1 `tests/combat/` `tests/dungeon/` `tests/items/` `tests/save_load/` 全テスト緑
- [ ] 13.2 ゲーム手動起動: 戦闘が従来通り動作（実 status は載せていないので体感は変わらないことを確認）
- [ ] 13.3 `openspec validate add-status-effect-infrastructure --strict` が成功

## 14. アーカイブ準備

- [ ] 14.1 `/opsx:verify add-status-effect-infrastructure` で齟齬レビュー
- [ ] 14.2 `/opsx:archive add-status-effect-infrastructure` で specs に統合
