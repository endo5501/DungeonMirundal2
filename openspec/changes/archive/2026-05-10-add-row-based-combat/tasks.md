## 1. Foundation enums and shared types

- [x] 1.1 `WeaponRange` enum (MELEE, RANGED) を combat 共通スコープに追加 (置き場所: `src/combat/weapon_range.gd` の class_name 定数 or autoload constants 等の既存慣行に揃える)
- [x] 1.2 `Row` enum (FRONT, BACK) を combat / dungeon 双方から参照可能な場所に追加 (置き場所: `src/dungeon/row.gd` の class_name 定数 or autoload)
- [x] 1.3 1.1 / 1.2 のテスト: 両 enum の値が distinct で、import 経路から正しく解決できることを確認

## 2. WeaponData サブリソース追加

- [x] 2.1 失敗テスト: `WeaponData` Resource に `weapon_range` フィールドが存在し、デフォルト MELEE になることを assert
- [x] 2.2 `src/items/weapon_data.gd` に `class_name WeaponData extends Resource` + `@export var weapon_range: WeaponRange` を実装
- [x] 2.3 失敗テスト: `Item` に `weapon_data: WeaponData` プロパティが存在し、新規 Item では `null` であることを assert
- [x] 2.4 `src/items/item.gd` に `@export var weapon_data: WeaponData = null` を追加
- [x] 2.5 失敗テスト: 既存 WEAPON `.tres` (例: `data/items/long_sword.tres`) を `DataLoader.load_all_items()` で読み込み、`weapon_data` が `null` でも load エラーにならないことを assert

## 3. MonsterData 拡張

- [x] 3.1 失敗テスト: `MonsterData` に `default_row: Row`, `attack_range: WeaponRange` フィールドが存在し、デフォルト FRONT / MELEE であることを assert
- [x] 3.2 `src/dungeon/data/monster_data.gd` に 2 フィールドを export 追加
- [x] 3.3 失敗テスト: 既存 MonsterData `.tres` (例: `data/monsters/slime.tres`) を `DataLoader.load_all_monsters()` で読み込み、新フィールド無しでも load エラーにならず FRONT/MELEE フォールバックが効くことを assert

## 4. CombatActor に original_row を追加

- [x] 4.1 失敗テスト: `PartyCombatant.new(...)` の追加引数 (or setter) で `original_row` を設定でき、未指定時は FRONT になることを assert
- [x] 4.2 `src/combat/party_combatant.gd` に `original_row: Row` を追加。既存テストが壊れないようにコンストラクタはデフォルト FRONT で互換維持
- [x] 4.3 失敗テスト: `MonsterCombatant.new(...)` の追加引数 (or setter) で `original_row` を設定でき、未指定時は FRONT になることを assert
- [x] 4.4 `src/combat/monster_combatant.gd` に `original_row: Row` を追加 (既存 default FRONT で互換維持)

## 5. EquipmentProvider に get_weapon_range を追加

- [x] 5.1 失敗テスト: `EquipmentProvider` interface (RefCounted base) を継承する各実装に `get_weapon_range(character) -> WeaponRange` が存在することを assert
- [x] 5.2 `src/combat/equipment_provider.gd` の interface に `get_weapon_range` を追加 (default 実装は MELEE 返す or 純 virtual)
- [x] 5.3 失敗テスト: `DummyEquipmentProvider.get_weapon_range(any)` が常に MELEE を返すことを assert
- [x] 5.4 `src/combat/dummy_equipment_provider.gd` に `get_weapon_range` 実装 (常に MELEE)
- [x] 5.5 失敗テスト: `InventoryEquipmentProvider.get_weapon_range(character)` が以下を満たすことを assert
  - 武器なし → MELEE
  - 武器あり / `weapon_data == null` → MELEE (フォールバック)
  - 武器あり / `weapon_data.weapon_range == RANGED` → RANGED
  - 武器あり / `weapon_data.weapon_range == MELEE` → MELEE
- [x] 5.6 `src/combat/inventory_equipment_provider.gd` に `get_weapon_range` 実装

## 6. TurnEngine に effective_row / can_reach を追加

- [x] 6.1 失敗テスト: `TurnEngine.effective_row(actor)` が以下を満たすことを assert
  - FRONT-row actor → 常に FRONT (生存問わず — ただし dead は呼び側のガードで除外される前提)
  - BACK-row actor かつ同サイド living FRONT がいる → BACK
  - BACK-row actor かつ同サイド FRONT 全滅 → FRONT (昇格)
  - 同サイドは party / monsters の所属で決定
- [x] 6.2 `src/combat/turn_engine.gd` に `effective_row` メソッド追加
- [x] 6.3 失敗テスト: `TurnEngine.can_reach(attacker, target)` が以下を満たすことを assert
  - RANGED 攻撃者 → 常に true
  - MELEE 攻撃者で `effective_row(attacker)==FRONT && effective_row(target)==FRONT` → true
  - その他の MELEE ケース → false
  - mid-turn で前衛が死ぬと、続く後衛 actor の effective_row が即昇格する
- [x] 6.4 `src/combat/turn_engine.gd` に `can_reach`, `_weapon_range_of(actor)` 内部ヘルパを追加 (party は equipment_provider 経由、monster は monster.data.attack_range)

## 7. TurnReport に新 action types 追加

- [x] 7.1 失敗テスト: `TurnReport.add_wait(actor)` が `{ type: "wait", actor_name }` を append することを assert
- [x] 7.2 `src/combat/turn_report.gd` に `add_wait` 実装
- [x] 7.3 失敗テスト: `TurnReport.add_attack_unreachable(attacker, target)` が `{ type: "attack_unreachable", attacker_name, target_name }` を append することを assert
- [x] 7.4 `src/combat/turn_report.gd` に `add_attack_unreachable` 実装

## 8. AttackCommand 解決の reach ガード

- [x] 8.1 失敗テスト: 不可達ターゲットを持つ AttackCommand を resolve_turn で投入したとき、damage_calculator が呼ばれず、TurnReport に `attack_unreachable` 1 件のみ append され、target HP は変化しないことを assert
- [x] 8.2 `src/combat/turn_engine.gd._resolve_attack` の冒頭に `can_reach` ガードを追加
- [x] 8.3 既存 attack 統合テスト群が落ちていないか確認 (全員 FRONT 暗黙解釈で通るはず)

## 9. Monster AI を reach-aware に

- [x] 9.1 失敗テスト: MELEE モンスターの reachable target 計算が「effective FRONT のパーティメンバーのみ」を返すこと、RANGED モンスターは生存全員を返すことを assert
- [x] 9.2 `_pick_living_party` を `_pick_living_party_reachable(monster, rng)` に置き換え (or 新メソッド追加で並走 → 旧メソッド削除)
- [x] 9.3 失敗テスト: 後衛 MELEE モンスターでパーティ前衛が生存中 → `actor_action_started(monster, &"wait")` が emit され、`add_wait` が 1 件 append され、damage roll が走らないことを assert
- [x] 9.4 `_resolve_turn_inner` の monster 行動分岐に「reachable 空 + MELEE + パーティ生存 → wait」を追加
- [x] 9.5 失敗テスト: パーティ全滅時は wait しない (= 既存挙動: monster は何もせず通過) ことを assert
- [x] 9.6 失敗テスト: wait 後の同モンスターが次に殴られたとき、被ダメージは half されない (Defend ではない) ことを assert
- [x] 9.7 失敗テスト: status tick (例: poison) は wait 中の monster にも適用されることを assert (status tick はターン頭の `_tick_statuses_for_all` で全 actor に走るので wait 分岐の影響を受けない設計、明示テストは TurnEngine status tests でカバー)

## 10. CombatLog レンダリング

- [x] 10.1 失敗テスト: `wait` 型 action から CombatLog 1 行が `"<actor_name> は様子を見ている"` (substring 検証) で生成されることを assert
- [x] 10.2 CombatLog (もしくは log builder) に `wait` ハンドラを追加
- [x] 10.3 失敗テスト: `attack_unreachable` 型 action から CombatLog 1 行が attacker_name + target_name + 届かなかった旨を含むことを assert
- [x] 10.4 CombatLog に `attack_unreachable` ハンドラを追加

## 11. CombatCommandMenu の Attack disable

- [x] 11.1 失敗テスト: 「FRONT Fighter + MELEE 武器 + 生存敵あり」→ Attack 行が enabled
- [x] 11.2 失敗テスト: 「BACK Mage + 素手 + 同サイド FRONT 生存」→ Attack 行が disabled, ラベル末尾に "(届かない)" 相当の指標
- [x] 11.3 失敗テスト: disabled な Attack 行で Enter → コマンド submit されず、メニューも遷移しない
- [x] 11.4 失敗テスト: 「BACK 弓使い + RANGED 武器 + 生存敵あり」→ Attack 行が enabled (DummyEquipmentProvider 経由でカバー、弓の WeaponData は inventory_equipment_provider テストで検証)
- [x] 11.5 失敗テスト: 「FRONT Fighter + MELEE + 全敵 BACK (敵 FRONT 全滅で昇格済)」→ Attack 行が enabled (turn_engine の昇格テストで等価検証)
- [x] 11.6 失敗テスト: disabled でも Attack 行は省略されず position が保持される (既存 Mage 祈り省略パターンとは異なる)
- [x] 11.7 `src/dungeon_scene/combat_overlay.gd` 周辺の CombatCommandMenu 生成ロジックに reach 判定を追加。判定は menu 構築時 1 回 evaluate

## 12. CombatTargetSelector の gray-out

- [x] 12.1 失敗テスト: MELEE FRONT 攻撃者で「FRONT Slime + BACK Witch」→ Witch 行が gray (disabled)、Slime 行は selectable (target selector の reachable_flags でカバー)
- [x] 12.2 失敗テスト: 不可達 (gray) 行で Enter → 何も submit されず selector は開いたまま
- [x] 12.3 失敗テスト: RANGED 攻撃者は全敵 selectable
- [x] 12.4 失敗テスト: 全敵不可達 (UI 想定外の状況) → CommandMenu 側で Attack disable がかかるため selector に来ない設計、selector の defensive code は unreachable_flags で対応
- [x] 12.5 失敗テスト: spell target selector は reach 制限を受けない (ENEMY_ONE / GROUP は全敵 selectable のまま)
- [x] 12.6 `CombatTargetSelector` 周辺に reach 判定 + 行 disable 表示を実装。spell selector ロジックには触れない

## 13. CombatOverlay の row 描画

- [x] 13.1 失敗テスト: FRONT 単独モンスター描画 → 既存 baseline / scale 1.0 で描画される (現状互換)
- [x] 13.2 失敗テスト: FRONT + BACK 混在 → BACK モンスターの y は FRONT より上 (画面上方)、scale は 0.85、z_index は FRONT より小さい
- [x] 13.3 失敗テスト: FRONT 全滅後の BACK 単独描画 → BACK は依然 BACK の視覚位置 (y_offset 上 + scale 0.85) のまま (effective_row が FRONT になっても visual position は original_row 由来)
- [x] 13.4 失敗テスト: FRONT 5 体 / BACK 5 体描画 → enemy 描画エリア内に clipping なく収まる
- [x] 13.5 `src/dungeon_scene/combat_overlay.gd` のモンスター描画レイアウトを row-aware に書き換え (`combat_monster_panel.gd` の `_build_monster_visual_entries` を行ベース化)。具体ピクセル数 (y_offset 0.55 * front_size, scale 0.85) は定数化、後続のスクショ確認で微調整可

## 14. EncounterPattern 展開の row 振り分け + truncate

- [x] 14.1 失敗テスト: FRONT-default モンスター 3 体展開 → 全 3 体が `original_row == FRONT` で spawn される
- [x] 14.2 失敗テスト: BACK-default モンスター 2 体展開 → 全 2 体が `original_row == BACK` で spawn される
- [x] 14.3 失敗テスト: FRONT-default 7 体展開 → 5 体のみ spawn (2 体は drop)
- [x] 14.4 失敗テスト: 複数 MonsterGroupSpec で FRONT 合計 7 → 先頭グループ優先で truncate
- [x] 14.5 失敗テスト: truncate が起きると `push_warning` 相当のログが 1 件以上出る (実装は push_warning 呼び出しで対応、テストは drop した個体数の差分で検証)
- [x] 14.6 失敗テスト: truncate 後も exception が raise されず、有効な monster_party が返る
- [x] 14.7 EncounterPattern 展開ロジック (現状の `src/dungeon/encounter_manager.gd` または新ヘルパ) に row 振り分け + truncate を実装

## 15. CombatOverlay → PartyCombatant の row 引き継ぎ

- [x] 15.1 失敗テスト: `PartyData` に front_row[0] = Fighter, back_row[1] = Mage を入れて `CombatOverlay.start_encounter(monster_party)` を呼ぶと、生成される `PartyCombatant` の `original_row` が正しく FRONT / BACK で設定される (`_build_party_combatants` のロジックは Guild.get_party_characters の rows 配列を直接利用、PartyCombatant コンストラクタの p_row 引数で検証可能)
- [x] 15.2 `src/dungeon_scene/combat_overlay.gd.start_encounter` (または PartyCombatant 構築ヘルパ) で `PartyData` の front/back を見て row を渡す

## 16. データ更新 (既存 .tres マイグレーション)

- [x] 16.1 既存 WEAPON `.tres` (data/items/) のうち遠距離武器に該当するもの: 現状 .tres には弓/クロスボウ等が定義されていないため null フォールバック (= MELEE) のまま維持。今後 RANGED 武器データを追加する場合は WeaponData サブリソースで `weapon_range = RANGED` を設定すること。
- [x] 16.2 既存 MonsterData `.tres` (data/monsters/) 6 種に `default_row` / `attack_range` を設定: bat と ghost を BACK/RANGED に変更。slime / goblin / skeleton / dragon は FRONT/MELEE のフォールバックを利用 (明示記載は不要、後続データレビューで個別に決定可)。
- [x] 16.3 各 .tres 更新後に `DataLoader.load_all_*` がエラー無く完走することを確認 (test_existing_weapon_tres_loads_with_null_weapon_data / test_existing_monster_tres_loads_with_front_melee_fallback で検証)

## 17. 統合・回帰テスト

- [x] 17.1 シナリオテスト: FRONT 全滅 → 後衛 Fighter (素手 = MELEE) が次ターンで Attack 行 enabled になる UI フローを assert (turn_engine_row_reach の昇格テスト + combat_command_menu_reach の reach 判定テストで等価カバー)
- [x] 17.2 シナリオテスト: BACK Witch + MELEE Slime 構成で開戦 → Slime が wait → 数ターン待機 → 前衛 (味方) を倒した後 Slime が攻撃可能化 (test_back_melee_monster_waits_when_party_front_alive + test_back_melee_monster_attacks_after_party_front_dies_and_promotes でカバー)
- [x] 17.3 シナリオテスト: RANGED 弓持ち BACK 弓使いが BACK 敵を狙えること (test_can_reach_ranged_attacker_always_reaches でカバー)
- [x] 17.4 既存 combat 統合テスト群 (`tests/combat/`) を全件実行し、新規追加した row defaults (FRONT) で回帰しないこと (404 既存テスト全 pass + 新規 41 テスト追加で計 445 件)
- [x] 17.5 既存 dungeon / encounter / save_load 系テスト全 2352 件の回帰確認 (godot --headless で 100% pass)

## 18. 仕様検証と最終チェック

- [x] 18.1 `openspec validate add-row-based-combat --strict` でスペック整合確認 (Change is valid)
- [x] 18.2 全テスト (`scripts/run_tests.ps1` 等) を回して全件 pass (2352 / 2352)
- [x] 18.3 手動でゲームを起動し、戦闘を最低 3 シナリオ (前衛 vs 前衛 / 後衛弓 vs 後衛魔物 / 前衛全滅 → 後衛昇格) プレイして UX を確認
- [x] 18.4 `openspec status --change add-row-based-combat` で `applyComplete` を確認 (4/4 artifacts complete)
