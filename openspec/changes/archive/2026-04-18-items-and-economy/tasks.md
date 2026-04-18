## 1. Item データモデル

- [x] 1.1 `tests/items/test_item.gd` を新規作成し、`Item` リソースが必須フィールド（`item_id`, `item_name`, `unidentified_name`, `category`, `equip_slot`, `allowed_jobs`, `attack_bonus`, `defense_bonus`, `agility_bonus`, `price`）を公開することをテスト
- [x] 1.2 `src/items/item.gd` に `class_name Item extends Resource` と `@export` フィールド、および `ItemCategory` / `EquipSlot` enum を実装
- [x] 1.3 `tests/items/test_item.gd` に「`category == OTHER` のとき `equip_slot == NONE`」「`category == WEAPON` のとき `equip_slot == WEAPON`」などのカテゴリ/スロット整合性テストを追加
- [x] 1.4 `tests/items/test_item_instance.gd` を新規作成し、`ItemInstance` のコンストラクタ（`Item` + `identified: bool`）と `to_dict() / ItemInstance.from_dict()` の round-trip テスト、`from_dict` で `item_id` が見つからない場合は `null` を返すテストを書く
- [x] 1.5 `src/items/item_instance.gd` (`class_name ItemInstance extends RefCounted`) を実装
- [x] 1.6 `tests/items/test_item_repository.gd` を新規作成し、`find(item_id)` の存在/非存在、`all()` の一覧、モック配列からのロードをテスト
- [x] 1.7 `src/items/item_repository.gd` (`class_name ItemRepository extends RefCounted`) を実装
- [x] 1.8 `src/dungeon/data_loader.gd`（既存）に `load_all_items() -> ItemRepository` を追加し、`data/items/*.tres` を舐めて Repository を返す実装を書く。併せて `tests/dungeon/test_data_loader.gd` にアイテムロード確認テストを追加
- [x] 1.9 `data/items/` ディレクトリを作成し、各 `EquipSlot`（WEAPON / ARMOR / HELMET / SHIELD / GAUNTLET / ACCESSORY）ごとに最低 1 つの `.tres` を整備（例: `long_sword.tres`, `short_sword.tres`, `staff.tres`, `mace.tres`, `leather_armor.tres`, `robe.tres`, `leather_helmet.tres`, `wooden_shield.tres`, `leather_gauntlet.tres`, `ring_of_protection.tres`）。MVP では消耗品カテゴリの `.tres` は作らない
- [x] 1.10 `openspec validate items-and-economy` が pass することを確認

## 2. Inventory

- [x] 2.1 `tests/items/test_inventory.gd` を新規作成し、`add` / `remove` / `contains` / `list()` の基本動作、`list()` の defensive copy 性、100 個追加が通ることをテスト
- [x] 2.2 `src/items/inventory.gd` (`class_name Inventory extends RefCounted`) を実装（`_items: Array[ItemInstance]`, `add` / `remove` / `contains` / `list` を含む）
- [x] 2.3 `test_inventory.gd` に gold のテスト（`add_gold`, `spend_gold` の成功/失敗、負数引数の扱い）を追加
- [x] 2.4 `inventory.gd` に `gold: int`, `add_gold` / `spend_gold` を実装
- [x] 2.5 `test_inventory.gd` に `to_dict / from_dict` の round-trip テスト（gold と item 順序の保存、欠損キーで空 Inventory が返る）を追加
- [x] 2.6 `inventory.gd` に `to_dict / from_dict(repository)` を実装

## 3. Equipment

- [x] 3.1 `tests/items/test_equipment.gd` を新規作成し、`Equipment` の 6 スロット初期値 null、`get_equipped`、`all_equipped` の挙動をテスト
- [x] 3.2 `src/items/equipment.gd` (`class_name Equipment extends RefCounted`) と `EquipResult` 型、`SLOT_MISMATCH` / `JOB_NOT_ALLOWED` の reason 列挙を実装
- [x] 3.3 `test_equipment.gd` に `equip(slot, instance, character)` のスロット一致・職業許可チェック、成功時の previous 返却、失敗時のスロット不変をテスト
- [x] 3.4 `equipment.gd` に `equip` / `unequip` / `all_equipped` を実装
- [x] 3.5 `test_equipment.gd` に `to_dict(inventory) / from_dict(data, inventory)` の round-trip テスト、欠損キーで空装備、装備アイテムが Inventory から削除されないことをテスト
- [x] 3.6 `equipment.gd` に `to_dict / from_dict` を実装
- [x] 3.7 `tests/dungeon/test_character.gd`（既存）に `Character.equipment` が存在し、`Character` の `to_dict / from_dict` で equipment が保存/復元されることをテスト
- [x] 3.8 `src/dungeon/character.gd` に `equipment: Equipment` フィールドと `to_dict / from_dict` での永続化を追加

## 4. GameState と ItemRepository の起動時配線

- [x] 4.1 `tests/dungeon/test_game_state.gd` に `GameState.item_repository` / `GameState.inventory` が存在し、`new_game()` で `inventory.gold == 500` かつ空の item 一覧になることをテスト
- [x] 4.2 `src/game_state.gd` に `var item_repository: ItemRepository` / `var inventory: Inventory` を追加し、`new_game()` での初期化、起動時 `_ready` で `DataLoader.load_all_items()` の呼び出しを実装
- [x] 4.3 `test_game_state.gd` に `heal_party` が死亡キャラ（`current_hp == 0`）の HP/MP を復活させないテストを追加
- [x] 4.4 `src/game_state.gd` の `heal_party` を修正し、`current_hp > 0` の生存メンバーのみ HP/MP を回復する実装に変更

## 5. InventoryEquipmentProvider

- [x] 5.1 `tests/combat/test_inventory_equipment_provider.gd` を新規作成し、装備 0 個時の値（base_stats[STR]/2, [VIT]/3, [AGI]）、単一装備時のボーナス加算、複数装備の合算、identified/unidentified で結果が変わらないことをテスト
- [x] 5.2 `src/combat/inventory_equipment_provider.gd` (`class_name InventoryEquipmentProvider extends EquipmentProvider`) を実装
- [x] 5.3 `main.gd` のプロダクション配線箇所を確認し、`PartyCombatant` 生成時の provider を `DummyEquipmentProvider` → `InventoryEquipmentProvider` へ切り替える（テストからは DummyEquipmentProvider も使えるように維持）
- [x] 5.4 `tests/combat/test_dummy_equipment_provider.gd` が引き続き pass することを確認

## 6. 初期装備付与（CharacterCreation）

- [x] 6.1 `tests/guild/test_character_creation_equipment.gd` を新規作成し、Fighter / Mage / Priest / Thief / Bishop / Samurai / Lord / Ninja の各職が少なくとも 1 スロット装備済みでパーティに加入することをテスト
- [x] 6.2 `tests/guild/test_character_creation_equipment.gd` に「初期アイテムが `GameState.inventory` に追加される」「`allowed_jobs` を満たすアイテムが自動で該当スロットに装備される」テストを追加
- [x] 6.3 `src/guild_scene/character_creation.gd` （または作成完了の最終コード箇所）に初期装備付与ロジックを実装。職業 → `Array[StringName]` のマッピングを定数で保持し、各 item_id を `ItemRepository` で解決して `Inventory.add` + `Equipment.equip` を呼ぶ
- [x] 6.4 必要な初期装備 `.tres`（職業毎の武器・鎧 8 職分）が手順 1.9 で揃っていることを確認し、不足分を追加

## 7. MonsterData に gold_min/gold_max 追加

- [x] 7.1 `tests/dungeon/test_monster_data.gd` に `gold_min` / `gold_max` フィールドの存在、バリデーション（`gold_min <= gold_max`）のテストを追加
- [x] 7.2 `src/dungeon/data/monster_data.gd` に `@export var gold_min: int` / `@export var gold_max: int` と validation を追加
- [x] 7.3 `data/monsters/*.tres` （slime, goblin, bat）に `gold_min` / `gold_max` を設定（slime: 1-3, goblin: 5-15, bat: 2-8 などの暫定値）

## 8. EncounterOutcome と CombatOverlay のゴールド処理

- [x] 8.1 `tests/combat/test_encounter_outcome.gd`（または既存）に `EncounterOutcome.gained_gold` フィールドが存在し、スタブ初期値が `0` であることをテスト
- [x] 8.2 `src/dungeon/encounter_outcome.gd` に `gained_gold: int` フィールドを追加
- [x] 8.3 `tests/dungeon/test_combat_overlay.gd` に「CLEARED のとき gained_gold が dead monsters の `gold_min..gold_max` 合計（固定シード下で決定論的）」「WIPED/ESCAPED のとき gained_gold == 0」のテストを追加
- [x] 8.4 `src/dungeon_scene/combat_overlay.gd` に gold 計算（`rng.randi_range` の和）と `EncounterOutcome.gained_gold` への代入を実装
- [x] 8.5 `test_combat_overlay.gd` に「ResultPanel が CLEARED で gained_experience と gained_gold の両方を表示する」「WIPED/ESCAPED では表示しない」テストを追加
- [x] 8.6 ResultPanel の表示ロジックを更新
- [x] 8.7 `tests/dungeon/test_main_encounter_flow.gd`（既存または新規）で「`encounter_resolved(outcome)` 受信時、`GameState.inventory.add_gold(outcome.gained_gold)` が呼ばれ `inventory.gold` が増える」ことをテスト
- [x] 8.8 `src/main.gd` の `encounter_resolved` ハンドラで `GameState.inventory.add_gold` を呼ぶ処理を追加

## 9. ShopScreen

- [x] 9.1 `tests/items/test_shop_inventory.gd` を新規作成し、`ShopInventory` が固定の Item 配列を返し、`purchase(item)` で新規 `ItemInstance(identified=true)` を返すテストを書く
- [x] 9.2 `src/items/shop_inventory.gd` (`class_name ShopInventory extends RefCounted`) を実装。MVP では `ItemRepository.all()` から装備系アイテムを取り込んだ固定リストを返す
- [x] 9.3 `tests/town/test_shop_screen.gd` を新規作成し、上位メニューに「購入する / 売却する / 出る」が出ることをテスト
- [x] 9.4 `src/town_scene/shop_screen.gd` (`class_name ShopScreen extends Control`) の骨組みと上位メニューを実装
- [x] 9.5 `test_shop_screen.gd` に購入フローのテスト（所持金 500G で 100G のアイテムを買う → gold 400、インベントリに 1 個追加）、所持金不足時に取引成立しないテスト、購入アイテムが `identified == true` であるテストを追加
- [x] 9.6 ShopScreen の購入ロジックを実装（`Inventory.spend_gold` → `ShopInventory.purchase` → `Inventory.add`）
- [x] 9.7 `test_shop_screen.gd` に売却フローのテスト（買値 100 のアイテム売却で +50 gold、`price == 25` で +12 gold、装備中のアイテムが候補に出ないこと）を追加
- [x] 9.8 ShopScreen の売却ロジックを実装（装備中判定は全パーティメンバーの `Equipment.all_equipped()` を走査）
- [x] 9.9 `test_shop_screen.gd` に「鑑定メニューが存在しない」ことをテスト（画面文字列の negative assertion）

## 10. TempleScreen

- [x] 10.1 `tests/town/test_temple_screen.gd` を新規作成し、パーティメンバー一覧表示、生存/死亡の区別表示、`REVIVE_COST_PER_LEVEL == 100` のコスト計算（Lv1=100, Lv5=500）をテスト
- [x] 10.2 `src/town_scene/temple_screen.gd` (`class_name TempleScreen extends Control`) の骨組みとキャラ一覧・コスト表示を実装
- [x] 10.3 `test_temple_screen.gd` に蘇生成功テスト（gold 足りる → gold 減算 + current_hp == 1、current_mp は変化なし）を追加
- [x] 10.4 蘇生ロジックを実装
- [x] 10.5 `test_temple_screen.gd` に gold 不足時のブロックテスト（gold 減らず、current_hp 0 のまま）、生存キャラ選択時の拒否テストを追加
- [x] 10.6 gold 不足・無効選択の処理を実装

## 11. TownScreen の有効化

- [x] 11.1 `tests/town/test_town_screen.gd` を更新し、「商店」「教会」がカーソルでスキップされず選択可能であること、選択時に `open_shop` / `open_temple` シグナルが発火することをテスト
- [x] 11.2 `src/town_scene/town_screen.gd` の `DISABLED_INDICES` を空配列にし、`select_item(1)` で `open_shop.emit()`、`select_item(2)` で `open_temple.emit()` を実装。シグナル宣言も追加
- [x] 11.3 `src/main.gd` の町画面遷移処理に「`open_shop` → ShopScreen 表示」「`open_temple` → TempleScreen 表示」「戻り処理で TownScreen 復帰」を配線
- [x] 11.4 `tests/test_main_screen_transitions.gd` などで町→商店→町、町→教会→町の往復テストを追加

## 12. ESC メニューのアイテム / 装備ビュー

- [x] 12.1 `tests/esc_menu/test_esc_menu.gd` を更新し、パーティメニューで「アイテム」「装備」が有効で選択可能であることをテスト
- [x] 12.2 `src/esc_menu/esc_menu.gd` の `PARTY_MENU_DISABLED` から `[1, 2]` を削除し、`_handle_party_menu_select` に ITEMS / EQUIPMENT 分岐を追加
- [x] 12.3 `tests/esc_menu/test_item_view.gd` を新規作成し、所持金表示、アイテム一覧、装備中マーク、使用ボタンなし、ESC で戻るをテスト
- [x] 12.4 `src/esc_menu/item_view.gd` （または `esc_menu.gd` 内ビュー）を実装
- [x] 12.5 `tests/esc_menu/test_equipment_view.gd` を新規作成し、キャラ選択 → スロット選択 → 候補選択 → 装備変更の正常系、`allowed_jobs` による候補フィルタ、装備解除（はずす）、ESC で 1 階層戻るをテスト
- [x] 12.6 `src/esc_menu/equipment_view.gd` （または `esc_menu.gd` 内ビュー）を実装

## 13. SaveManager 拡張

- [x] 13.1 `tests/save/test_save_manager_inventory.gd` を新規作成し、「save → load で gold 750 と items A/B/C の順序が保存/復元される」「レガシーセーブ（inventory キーなし）が空インベントリ + gold 0 でロードできる」ことをテスト
- [x] 13.2 `src/save_manager.gd` に `inventory.to_dict()` / `Inventory.from_dict()` を統合。save ファイルに `"inventory"` キーを追加、load でキー欠如時に空 Inventory を生成
- [x] 13.3 `tests/save/test_save_manager_equipment.gd` を新規作成し、Character の equipment 6 スロット（index または null）が正しく save/load されること、装備参照が復元後に Inventory の同じ ItemInstance を指すこと、レガシーセーブ（equipment キーなし）が全スロット null でロードできることをテスト
- [x] 13.4 `src/save_manager.gd` と `src/dungeon/character.gd` の `to_dict / from_dict` を連携し、load 時に inventory → Guild の順で復元するよう保証

## 14. 統合確認とクリーンアップ

- [x] 14.1 `openspec validate items-and-economy --strict` が pass することを確認
- [x] 14.2 全 GUT テストがローカルで pass することを確認 (913/913)（`./addons/gut/gut_cmdln.sh` 等のプロジェクト慣用コマンドを使う）
- [x] 14.3 手動確認シナリオを実行: 新規ゲーム → 町 → 商店で装備購入 → ダンジョンで戦闘勝利 → ゴールド加算確認 → ESC メニューで装備変更 → 戻る → セーブ → ロード → 状態復元確認 (装備候補カーソル / 装備者表示 / クロスキャラ装備の3件を修正後に通過)
- [x] 14.4 戦闘で死亡キャラを作成し → 町の教会で蘇生 → current_hp == 1 になり、current_mp は変化なし・ゴールドが減っていることを確認
- [x] 14.5 `DummyEquipmentProvider` がテスト以外で参照されていないことを grep で確認 (src 内の参照は定義ファイル self のみ)
- [x] 14.6 `openspec archive items-and-economy` の準備（ `/opsx:verify` 相当）に移れる状態を確認
