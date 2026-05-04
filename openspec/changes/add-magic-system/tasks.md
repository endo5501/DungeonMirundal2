## 1. SpellData / SpellEffect 基盤（テスト先行）

- [x] 1.1 `tests/dungeon/test_spell_data.gd` を新規作成（SpellData の必須フィールド存在、id == filename、school/target_type/scope のバリデーション）
- [x] 1.2 `tests/combat/test_spell_effects.gd` を新規作成（DamageSpellEffect の base+spread+RNG、最小 1 ダメージのフロア、HealSpellEffect の max_hp クランプ、死亡者は対象外）
- [x] 1.3 `tests/dungeon/test_spell_repository.gd` を新規作成（id 検索、不在は null、bulk load で 8 件揃う）
- [x] 1.4 `tests/dungeon/test_data_loader.gd` を拡張（`DataLoader.load_all_spells()` の存在、件数、id セット）
- [x] 1.5 `src/dungeon/data/spell_data.gd` を実装（`SpellData extends Resource`、各 @export フィールド、target_type/scope の enum 定数公開）
- [x] 1.6 `src/combat/spells/spell_effect.gd` を実装（抽象 `SpellEffect extends Resource`、`apply(caster, targets, rng) -> SpellResolution` の virtual シグネチャと既定実装）
- [x] 1.7 `src/combat/spells/spell_resolution.gd` を実装（`entries: Array`、各 entry は actor/hp_delta/actor_name）
- [x] 1.8 `src/combat/spells/damage_spell_effect.gd` を実装（base_damage / spread、最小 1 ダメージ、SpellResolution 構築）
- [x] 1.9 `src/combat/spells/heal_spell_effect.gd` を実装（base_heal / spread、max_hp クランプ、死亡者スキップ）
- [x] 1.10 `src/dungeon/data/spell_repository.gd` を実装（dict ベースの id → SpellData）
- [x] 1.11 `src/dungeon/data/data_loader.gd` に `load_all_spells()` を追加（既存の `load_all_jobs()` 等と同型）
- [x] 1.12 1.1–1.4 のテストが全て緑になることを確認

## 2. 8 つの呪文 .tres を作成

- [x] 2.1 `data/spells/fire.tres`（id=fire / mage / lv1 / mp_cost=2 / ENEMY_ONE / BATTLE_ONLY / DamageSpellEffect base_damage=6, spread=2）
- [x] 2.2 `data/spells/frost.tres`（id=frost / mage / lv1 / mp_cost=2 / ENEMY_ONE / BATTLE_ONLY / DamageSpellEffect base_damage=6, spread=2）
- [x] 2.3 `data/spells/flame.tres`（id=flame / mage / lv2 / mp_cost=4 / ENEMY_GROUP / BATTLE_ONLY / DamageSpellEffect base_damage=5, spread=2）
- [x] 2.4 `data/spells/blizzard.tres`（id=blizzard / mage / lv2 / mp_cost=4 / ENEMY_GROUP / BATTLE_ONLY / DamageSpellEffect base_damage=5, spread=2）
- [x] 2.5 `data/spells/heal.tres`（id=heal / priest / lv1 / mp_cost=2 / ALLY_ONE / OUTSIDE_OK / HealSpellEffect base_heal=8, spread=2）
- [x] 2.6 `data/spells/holy.tres`（id=holy / priest / lv1 / mp_cost=2 / ENEMY_ONE / BATTLE_ONLY / DamageSpellEffect base_damage=6, spread=2）
- [x] 2.7 `data/spells/heala.tres`（id=heala / priest / lv2 / mp_cost=3 / ALLY_ONE / OUTSIDE_OK / HealSpellEffect base_heal=14, spread=3）
- [x] 2.8 `data/spells/allheal.tres`（id=allheal / priest / lv2 / mp_cost=5 / ALLY_ALL / OUTSIDE_OK / HealSpellEffect base_heal=6, spread=2）
- [x] 2.9 起動時に SpellRepository が 8 件全てロードできることをスモーク確認（main / test 両方）(test_spell_repository.gd で 8 件確認)

## 3. JobData スキーマ変更（破壊的・テスト先行）

- [x] 3.1 `tests/dungeon/test_job_data.gd` を更新: `has_magic` の参照を全て削除し、`mage_school` / `priest_school` / `spell_progression` の存在と各職の値を検証する新しいシナリオを追加
- [x] 3.2 `src/dungeon/data/job_data.gd` から `has_magic: bool` を削除し、`mage_school: bool` / `priest_school: bool` / `spell_progression: Dictionary` を追加
- [x] 3.3 `data/jobs/fighter.tres` を更新（mage_school=false, priest_school=false, spell_progression={}）
- [x] 3.4 `data/jobs/thief.tres` を更新（同上）
- [x] 3.5 `data/jobs/ninja.tres` を更新（同上）
- [x] 3.6 `data/jobs/mage.tres` を更新（mage_school=true, priest_school=false, spell_progression={1:[fire,frost], 3:[flame,blizzard]}）
- [x] 3.7 `data/jobs/priest.tres` を更新（mage_school=false, priest_school=true, spell_progression={1:[heal,holy], 3:[heala,allheal]}）
- [x] 3.8 `data/jobs/bishop.tres` を更新（mage_school=true, priest_school=true, spell_progression={2:[fire,frost,heal,holy], 5:[flame,blizzard,heala,allheal]}）
- [x] 3.9 `data/jobs/samurai.tres` を更新（mage_school=true, priest_school=false, spell_progression={4:[fire,frost], 8:[flame,blizzard]}）
- [x] 3.10 `data/jobs/lord.tres` を更新（mage_school=false, priest_school=true, spell_progression={4:[heal,holy], 8:[heala,allheal]}）
- [x] 3.11 既存コードベースから `has_magic` の参照を grep で全件洗い出し、`mage_school or priest_school` または等価な「is_magic_capable」ヘルパー呼び出しに置換（`character.gd` の create / level_up を含む）
- [x] 3.12 3.1 のテスト緑、加えて他の依存テスト（character_creation 系など）が緑になることを確認

## 4. Character.known_spells と習得経路（テスト先行）

- [x] 4.1 `tests/dungeon/test_character.gd` を拡張: 各職の Lv1 作成時 known_spells を検証（Mage→[fire,frost], Priest→[heal,holy], Bishop/Samurai/Lord→[]、非魔法職→[]）
- [x] 4.2 同テストに level_up のシナリオを追加: Mage Lv1→Lv3 で flame/blizzard 取得、Bishop Lv1→Lv2 で 4 つ取得、多レベル一気上げで漏れなし、重複追加されない
- [x] 4.3 `src/dungeon/character.gd` に `var known_spells: Array[StringName] = []` を追加
- [x] 4.4 `Character.create()` で `known_spells = job.spell_progression.get(1, []).duplicate()` 相当の処理を実装（Lv1 配列を StringName で正規化し重複排除）
- [x] 4.5 `Character.level_up()` 内で、新しい `level` がキーに存在する場合のみその配列を `known_spells` に追加（既存と重複する id は除外）
- [x] 4.6 4.1 / 4.2 のテスト緑を確認

## 5. セーブ／ロードの拡張（後方互換、テスト先行）

- [x] 5.1 `tests/save_load/test_character_serialization.gd` を拡張: `to_dict` の戻りに `known_spells: Array[String]` が含まれること、`from_dict` で StringName 配列に復元されること、`known_spells` キー欠落のレガシー Dictionary でも JobData.spell_progression からリプレイ復元できること、未知 id がドロップされ push_warning が出ることを検証
- [x] 5.2 `Character.to_dict` を更新: `known_spells` を文字列配列として出力
- [x] 5.3 `Character.from_dict` を更新: `known_spells` キー存在時は StringName 化、欠落時は spell_progression から再構築（push_warning）、未知 id はドロップ（push_warning）
- [x] 5.4 既存の `test_save_manager.gd` / `test_main_save_load.gd` がそのまま緑になることを確認（known_spells を含むセーブを書き出してロードできる回帰テスト）
- [x] 5.5 5.1 のテスト緑を確認

## 6. CombatActor の MP 拡張（テスト先行）

- [x] 6.1 `tests/combat/test_turn_engine.gd` 等にダミー Actor のテストがある場合、`current_mp` / `max_mp` / `spend_mp` を備えた CombatActor のテストを追加
- [x] 6.2 `src/combat/combat_actor.gd`（または該当抽象クラス）に `current_mp: int`, `max_mp: int`, `spend_mp(amount: int) -> bool` を追加（共通実装）
- [x] 6.3 `src/combat/party_combatant.gd` を更新: `current_mp`/`max_mp` を `Character.current_mp`/`max_mp` に proxy、`spend_mp` で Character の MP を減らす
- [x] 6.4 `src/combat/monster_combatant.gd` を更新: `current_mp = 0`, `max_mp = 0`、`spend_mp(amount)` は `amount > 0` で常に false、`amount == 0` のみ true
- [x] 6.5 6.1 のテスト緑、加えて既存 combat-actor テスト（test_combat_actor 系がある場合）が緑

## 7. Cast コマンドと TurnEngine（テスト先行）

- [x] 7.1 `tests/combat/test_turn_engine.gd` を拡張: Cast コマンド submit → resolve、MP 消費、ENEMY_ONE/ENEMY_GROUP/ALLY_ONE/ALLY_ALL の各 target_type で正しい対象に効果が乗ること
- [x] 7.2 同テストに MP 不足時の cast_skipped_no_mp、対象全滅時の cast_skipped_no_target、ENEMY_ONE のリターゲット（同種優先）、TurnReport のエントリ構造を検証するシナリオを追加
- [x] 7.3 `src/combat/commands/cast_command.gd`（または既存コマンドファイル群と同じ場所）を新規作成: SpellData id / caster_index / target_descriptor を保持
- [x] 7.4 `src/combat/turn_engine.gd` を更新: `submit_command(actor_index, CastCommand)` 受け入れ、resolve_turn 内で Cast ブランチを追加（MP チェック → ターゲット解決 → 効果適用 → TurnReport 追記）
- [x] 7.5 `src/combat/turn_report.gd`（または該当ファイル）を更新: cast / cast_skipped_no_mp / cast_skipped_no_target のエントリ型を追加
- [x] 7.6 7.1 / 7.2 のテスト緑を確認

## 8. 戦闘 UI（CommandMenu / SpellSelector / TargetSelector）

- [x] 8.1 `src/dungeon_scene/combat/combat_command_menu.gd` を更新: アクター（Character.job）の `mage_school` / `priest_school` を見て、「魔術」「祈り」を動的に挿入。Fighter 系では従来 4 項目のまま。OPTIONS 配列を builder で組み立てる方式に変更
- [x] 8.2 `tests/dungeon/test_combat_overlay.gd` を拡張: Mage / Priest / Bishop / Fighter ごとに表示項目が仕様通りであることを検証
- [x] 8.3 `src/dungeon_scene/combat/combat_spell_selector.gd` を新規作成（`combat_item_selector.gd` を雛形に）: 引数の school と Character.known_spells から呪文一覧を構築、MP 不足行の disabled 表示
- [x] 8.4 `src/dungeon_scene/combat/combat_target_selector.gd` を新規作成: target_type に応じてモード切替（個別敵 / モンスター種別 / 個別味方 / 即確定）
- [x] 8.5 `src/dungeon_scene/combat_overlay.gd` を更新: 「魔術」「祈り」選択 → SpellSelector → TargetSelector → CastCommand を TurnEngine に submit する状態遷移を組み込む
- [x] 8.6 `tests/dungeon/test_combat_overlay.gd` にスモークシナリオ（Mage が「魔術」→「ファイア」→ スライム選択 → resolve 後にスライム HP が減る）を追加
- [x] 8.7 8.2 / 8.6 のテスト緑、加えて既存戦闘テストが緑であることを確認

## 9. CombatLog の Cast エントリ表示

- [x] 9.1 `tests/combat/test_battle_summary.gd` 等の戦闘ログ系テストに、Cast エントリのフォーマット（caster + 呪文名 + 対象 + delta）が含まれることを検証するシナリオを追加 (test_combat_log.gd に追加)
- [x] 9.2 `src/dungeon_scene/combat/combat_log.gd`（または該当ファイル）に Cast / cast_skipped_* のレンダリング分岐を追加
- [x] 9.3 9.1 のテスト緑を確認

## 10. ESC メニューと SpellUseFlow

- [x] 10.1 `src/esc_menu/esc_menu.gd` の View enum に `SPELL_FLOW` を追加し、パーティサブメニューに「じゅもん」エントリを追加（魔法職不在時 disabled）
- [x] 10.2 `tests/esc_menu/test_esc_menu.gd` を拡張: 「じゅもん」項目の表示/disabled 切替、選択で SPELL_FLOW へ遷移すること
- [x] 10.3 `src/esc_menu/flows/spell_use_flow.gd` を新規作成（`item_use_flow.gd` を雛形に）: 詠唱者選択 → (Bishop のみ系統選択) → 呪文一覧（scope=OUTSIDE_OK のみ、MP 不足は disabled）→ ターゲット選択 → 効果適用 → ログ表示 → パーティメニューへ復帰
- [x] 10.4 `tests/esc_menu/flows/test_spell_use_flow.gd` を新規作成: ヒール／オールヒール／系統スキップ／戦闘専用呪文の非表示／MP 消費が Character に反映、をシナリオごとに検証
- [x] 10.5 10.2 / 10.4 のテスト緑、および既存 esc_menu / item_use_flow / equipment_flow のテストが緑であることを確認

## 11. 統合と検証

- [x] 11.1 GUT で全テストスイートを実行し、緑であることを確認 (1455/1455 緑)
- [x] 11.2 `openspec validate add-magic-system --strict` を実行し、エラー無しを確認
- [x] 11.3 手動スモーク: 新規ゲーム → Mage を作成 → ダンジョン → 戦闘で「魔術」→「ファイア」がスライムにヒット → 帰還 → 町で MP 全回復することを確認
- [x] 11.4 手動スモーク: ESC → パーティ → じゅもん → Mage 選択（攻撃呪文しか持たないので呪文一覧が空 → empty state）／ Priest 選択 → ヒール → 味方を選択 → HP 回復 → ログを確認
- [x] 11.5 手動スモーク: 既存セーブ（known_spells 欠落のレガシー想定）をロードしても push_warning が出るのみでクラッシュしないことを確認（必要に応じて手元で擬似的な古いセーブを作成）
- [x] 11.6 ハイブリッド職の習得確認: Bishop を作成し、Lv2 / Lv5 への到達で正しく呪文セットが解放されること、Samurai/Lord を Lv4 まで上げて呪文セットが解放されることを確認（テストで保証していれば省略可）
- [x] 11.7 PR 作成前に `git diff` をレビューし、`has_magic` の取り残しが無いこと、`SpellData` 関連の新規ファイル群が漏れなく add されていることを確認
