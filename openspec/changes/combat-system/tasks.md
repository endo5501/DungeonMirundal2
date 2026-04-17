## 1. JobData 拡張とデータ補填

- [x] 1.1 `tests/dungeon/test_job_data.gd` に `hp_per_level` / `mp_per_level` の読み出しテストを追加（Fighter: `hp_per_level > 0`、Fighter: `mp_per_level == 0`、Mage: 両方 `> 0` を検証）
- [x] 1.2 `tests/dungeon/test_job_data.gd` に `exp_table` 単調増加・サイズ 12 以上の検証テストを追加
- [x] 1.3 `tests/dungeon/test_job_data.gd` に `exp_to_reach_level(target_level)` のテスト（`target_level <= 1` で 0、`2` で `exp_table[0]`、範囲外で最終要素を返す）を追加
- [x] 1.4 `src/dungeon/data/job_data.gd` に `@export var hp_per_level: int` / `@export var mp_per_level: int` / `@export var exp_table: PackedInt64Array` と `exp_to_reach_level()` メソッドを実装
- [x] 1.5 8 職 `.tres`（`data/jobs/*.tres`）を編集し、`hp_per_level` / `mp_per_level` / `exp_table`（少なくとも 12 エントリ）を設定（Fighter: hp 4 / mp 0、Mage: hp 2 / mp 2 など、Wizardry 1 参考値）
- [x] 1.6 `openspec validate combat-system` が pass することを確認

## 2. EquipmentProvider インターフェースと DummyEquipmentProvider

- [x] 2.1 `tests/combat/test_equipment_provider.gd` を新規作成し、`EquipmentProvider` インターフェースのメソッドシグネチャ存在テスト（`get_attack` / `get_defense` / `get_agility`）を書く
- [x] 2.2 `src/combat/equipment_provider.gd` (`class_name EquipmentProvider extends RefCounted`) を作成し、3 メソッドを virtual として実装（デフォルトは 0 返しで good enough、実装はサブクラス）
- [x] 2.3 `tests/combat/test_dummy_equipment_provider.gd` を新規作成し、Fighter / Mage / Priest / Thief / Bishop / Samurai / Lord / Ninja の 8 職それぞれで `get_attack` / `get_defense` / `get_agility` が想定値を返すテストを書く
- [x] 2.4 `src/combat/dummy_equipment_provider.gd` (`extends EquipmentProvider`) を実装し、`weapon_bonus` / `armor_bonus` の職別テーブルを辞書として内包、`base_stats[STR]/2 + weapon_bonus`、`base_stats[VIT]/3 + armor_bonus`、`base_stats[AGI]` の計算を実装

## 3. CombatActor 抽象と PartyCombatant / MonsterCombatant

- [x] 3.1 `tests/combat/test_combat_actor.gd` を新規作成し、`CombatActor` のインターフェース（フィールド・メソッド存在）と `is_alive` / `take_damage` / `apply_defend` / `clear_turn_flags` の基本動作テストを書く
- [x] 3.2 `src/combat/combat_actor.gd` (`class_name CombatActor extends RefCounted`) を実装（`take_damage` で 0 クランプ、`apply_defend` / `clear_turn_flags` で防御フラグを切替、is_alive は `current_hp > 0`、`get_attack` 等はサブクラスで override する virtual）
- [x] 3.3 `tests/combat/test_party_combatant.gd` を新規作成し、Character への HP 書き戻し、`EquipmentProvider` 経由の派生ステータス取得、`actor_name` が Character の `character_name` を返すことをテスト
- [x] 3.4 `src/combat/party_combatant.gd` (`extends CombatActor`) を実装
- [x] 3.5 `tests/combat/test_monster_combatant.gd` を新規作成し、Monster への HP 書き戻し、`MonsterData` の `attack` / `defense` / `agility` を派生ステータスとして返すこと、`actor_name` が `MonsterData.monster_name` を返すことをテスト
- [x] 3.6 `src/combat/monster_combatant.gd` (`extends CombatActor`) を実装

## 4. Damage 計算とコマンド

- [x] 4.1 `tests/combat/test_damage_calculator.gd` を新規作成し、`max(1, attack - defense/2 + rng_spread)` の計算、最小 1 クランプをテスト（固定シード、`rng.seed = 12345`）
- [x] 4.2 `src/combat/damage_calculator.gd` (`class_name DamageCalculator extends RefCounted`) を実装
- [x] 4.3 `tests/combat/test_combat_commands.gd` を新規作成し、`AttackCommand` / `DefendCommand` / `EscapeCommand` の各データ型と target 保持、`apply_defend` が実行されることをテスト
- [x] 4.4 `src/combat/combat_commands.gd` を実装（`AttackCommand(target: CombatActor)`, `DefendCommand()`, `EscapeCommand()` の 3 種を `RefCounted` サブクラスで定義）— ファイル分割（`attack_command.gd` / `defend_command.gd` / `escape_command.gd`）

## 5. TurnOrder とターンエンジン

- [x] 5.1 `tests/combat/test_turn_order.gd` を新規作成し、agility 降順ソート、死亡者除外、同値タイブレークの決定論性をテスト
- [x] 5.2 `src/combat/turn_order.gd` (`class_name TurnOrder extends RefCounted`) を実装
- [x] 5.3 `tests/combat/test_turn_engine.gd` で状態遷移テストを書く: `IDLE → COMMAND_INPUT`（`start_battle`）、`COMMAND_INPUT → RESOLVING`（全員コマンド投入）、`RESOLVING → COMMAND_INPUT`（戦闘継続）、`RESOLVING → FINISHED(CLEARED/WIPED/ESCAPED)`
- [x] 5.4 `src/combat/turn_engine.gd` (`class_name TurnEngine extends RefCounted`) の状態機械部分を実装
- [x] 5.5 `test_turn_engine.gd` に TurnReport（アクション順記録）・被撃対象選択・防御ダメージ半減・逃走判定（成功/失敗）のテストを追加
- [x] 5.6 `TurnEngine.resolve_turn(rng)` で行動順ループ、AttackCommand の target 再選定（死亡時）、モンスター側のランダム対象選択、TurnReport 生成を実装
- [x] 5.7 `EncounterOutcome` 生成（CLEARED / WIPED / ESCAPED）を `TurnEngine.outcome()` で返す実装を追加、全テスト green 確認

## 6. 経験値・レベルアップ

- [x] 6.1 `tests/combat/test_experience_calculator.gd` を新規作成し、`sum_experience(dead_monsters)` の合計、参加メンバー均等配布（生存・死亡含む）、余り切捨てをテスト
- [x] 6.2 `src/combat/experience_calculator.gd` (`class_name ExperienceCalculator extends RefCounted`) を実装
- [x] 6.3 `tests/dungeon/test_character_level_up.gd` を新規作成し、`Character.gain_experience(amount)` の累積、閾値跨ぎによる `level_up()` 発火、多段レベルアップ、HP/MP 増加（職業別 `hp_per_level + VIT/3`、`mp_per_level` は has_magic のみ、最小 1）、ステータス不変をテスト
- [x] 6.4 `src/dungeon/character.gd` に `accumulated_exp: int` フィールド（または内部保持）、`gain_experience(amount)`、`level_up()` を実装（`to_dict` / `from_dict` への反映を含む）
- [x] 6.5 `tests/combat/test_experience_calculator.gd` に `EncounterOutcome.gained_experience` への反映テストを追加（CLEARED 時のみ非ゼロ、WIPED / ESCAPED 時は 0）
- [x] 6.6 `ExperienceCalculator.award(party_characters, dead_monsters) -> int` を実装し、Character.gain_experience 呼び出しと per-member share 返却を両立

## 7. CombatOverlay 骨組み（EncounterOverlay 継承）

- [x] 7.1 `tests/dungeon/test_combat_overlay.gd` を新規作成し、以下を網羅:
  - `CombatOverlay` が `EncounterOverlay` のサブクラスである
  - `CanvasLayer`、`layer == 10`、初期非表示
  - `start_encounter(party)` で可視化し、内部 `TurnEngine` が `COMMAND_INPUT` 状態に入る
- [x] 7.2 `src/dungeon_scene/combat_overlay.gd` (`class_name CombatOverlay extends EncounterOverlay`) の骨組み（`start_encounter` override、内部 TurnEngine 初期化、空のサブパネル追加）を実装
- [x] 7.3 `test_combat_overlay.gd` に MonsterPanel の内容検証（種別別生存数表示、個体 HP 非表示、モンスター死亡で表示更新）を追加
- [x] 7.4 `src/dungeon_scene/combat/combat_monster_panel.gd` を実装（class_name `CombatMonsterPanel`）
- [x] 7.5 `test_combat_overlay.gd` に PartyStatusPanel の検証（Character 参照から HP が描画、ダメージ後に HP 表示更新）を追加
- [x] 7.6 `src/dungeon_scene/combat/combat_party_status_panel.gd` を実装（class_name `CombatPartyStatusPanel`、戦闘中専用として Character 参照）

## 8. コマンド入力 UI

- [x] 8.1 `test_combat_overlay.gd` に CommandMenu のテストを追加:
  - 生存 PartyCombatant ごとに 1 人ずつ入力を求める
  - 死亡者をスキップして次に進む
  - 「こうげき」/「ぼうぎょ」/「にげる」の 3 オプションを表示
  - 「こうげき」選択で生存モンスターから対象選択画面に進む
  - 全員入力完了で `TurnEngine.resolve_turn` が呼ばれる
- [x] 8.2 `src/dungeon_scene/combat/combat_command_menu.gd` を実装
- [x] 8.3 `src/dungeon_scene/combat/combat_target_selector.gd` を実装（生存モンスター一覧から 1 体選択）

## 9. CombatLog と ResultPanel

- [x] 9.1 `test_combat_overlay.gd` に CombatLog のテスト（直近 4 行保持、古い行の押し出し、攻撃/被弾のログ文言）を追加
- [x] 9.2 `src/dungeon_scene/combat/combat_log.gd` を実装（`TurnReport` から行を生成して追記）
- [x] 9.3 `test_combat_overlay.gd` に ResultPanel のテスト（CLEARED: 獲得 EXP と LvUp 通知、WIPED: 敗北メッセージ、ESCAPED: 逃走メッセージ、確認入力で `encounter_resolved` 発火）を追加
- [x] 9.4 `src/dungeon_scene/combat/combat_result_panel.gd` を実装（class_name `CombatResultPanel`）

## 10. 入力制御と既存オーバーレイ契約回帰

- [x] 10.1 `test_combat_overlay.gd` に入力遮断テスト（戦闘中の移動キーは Dungeon に届かない、ESC で ESC メニューが開かない）を追加
- [x] 10.2 `src/dungeon_scene/combat_overlay.gd` の `_unhandled_input` を整備（親クラスの入力処理を override/拡張）
- [x] 10.3 既存 `tests/dungeon/test_encounter_overlay.gd` が引き続き green（スタブ契約の回帰）であることを確認

## 11. EncounterCoordinator への注入と main.gd 配線

- [x] 11.1 `tests/dungeon/test_encounter_coordinator.gd` に「コンストラクタ引数（または setter）で EncounterOverlay サブクラスを注入できる」テストを追加
- [x] 11.2 `src/dungeon/encounter_coordinator.gd` の `_init` / `_ready` を修正し、overlay インスタンスを外部注入可能にする（省略時は現行の `EncounterOverlay` スタブ）
- [x] 11.3 `src/dungeon/guild.gd` に `get_party_characters() -> Array[Array[Character]]`（front/back 2 次元配列、`null` を含む）を追加し、`tests/dungeon/test_guild.gd` に取得テストを追加
- [x] 11.4 `src/main.gd` の `_setup_encounter_coordinator()` を修正し、`CombatOverlay` を生成して `EncounterCoordinator` に渡す。`CombatOverlay.setup_dependencies(guild, equipment_provider, rng)` 相当のセッターで Guild 参照と `DummyEquipmentProvider` を渡す（タイミングの関係で、依存注入は `_attach_encounter_coordinator_to_screen` からの再注入で実施）
- [x] 11.5 `src/main.gd` で `EncounterOutcome.WIPED` を受けた際の町強制送還フローを実装（`encounter_finished(outcome)` に拡張してハンドラで分岐）
- [x] 11.6 `GameState.heal_party()` が町帰還時に呼ばれていることを確認し、WIPED 後の HP 全快を担保（既存の `_on_return_to_town` 経由）

## 12. 統合テストと手動検証

- [x] 12.1 `tests/combat/test_battle_integration.gd` を新規作成し、ダミー Guild + ダミー MonsterParty で 1 戦闘を最後まで流して CLEARED になることを検証（固定シード）
- [x] 12.2 `test_battle_integration.gd` に WIPED・ESCAPED パスのテストを追加（低 HP パーティで WIPED、RNG で Escape 成功を強制）
- [ ] 12.3 Godot エディタで起動し、実際にダンジョンを歩いてエンカウント→戦闘→勝利/敗北/逃走を一通り確認し、UI レイアウトと挙動の違和感を記録（**手動検証**。自動化では未実施）
- [x] 12.4 `openspec validate combat-system` が pass することを確認
- [x] 12.5 GUT 全テスト green の最終確認（776/776）
