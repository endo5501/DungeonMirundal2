## 1. is_slot_consistent の代替テストを先に追加 (TDD)

- [x] 1.1 `tests/items/test_item.gd` に「`data/items/*.tres` をロードしてカテゴリと equip_slot の整合を確認するテスト」を追加(category=WEAPON なら equip_slot=WEAPON、CONSUMABLE/OTHER なら NONE、等)
- [x] 1.2 テストを実行し既存実装で通ることを確認

## 2. Equipment 内部の Item.EquipSlot 化 (TDD)

- [ ] 2.1 `tests/items/test_equipment.gd` の `Equipment.EquipSlot.*` を `Item.EquipSlot.*` に書き換える
- [ ] 2.2 「Equipment.equip(Item.EquipSlot.NONE, ...) は SLOT_MISMATCH を返す」テストを追加
- [ ] 2.3 「`item.equip_slot` を直接 `Equipment.equip` に渡しても動く」テストを追加(`slot_from_item_slot` 経由が消えても OK な担保)
- [ ] 2.4 テストを実行し失敗することを確認しコミット (Red)
- [ ] 2.5 `src/items/equipment.gd` から `enum EquipSlot` を削除
- [ ] 2.6 `src/items/equipment.gd` から `static func slot_from_item_slot(...)` を削除
- [ ] 2.7 `src/items/equipment.gd` の `SLOT_KEYS` / `ALL_SLOTS` を `Item.EquipSlot.*` ベースで再定義
- [ ] 2.8 `Equipment.equip` / `unequip` / `get_equipped` 内部で `Item.EquipSlot` 値を使うように更新、`NONE` チェックを追加
- [ ] 2.9 `_init` の slot 初期化ループを `ALL_SLOTS` を使う形に維持(値が変わるだけで構造は同じ)
- [ ] 2.10 テスト通過を確認しコミット (Green)

## 3. Item.is_slot_consistent の削除 (TDD)

- [ ] 3.1 `tests/items/test_item.gd` から `is_slot_consistent` を直接呼ぶテストを削除(代替テストは 1.1 で追加済み)
- [ ] 3.2 `src/items/item.gd` から `func is_slot_consistent()` を削除
- [ ] 3.3 grep で `is_slot_consistent` 残存呼び出しがないことを確認
- [ ] 3.4 テスト通過を確認しコミット

## 4. 呼び出し側の更新 (TDD)

- [ ] 4.1 `tests/combat/test_inventory_equipment_provider.gd` の `Equipment.EquipSlot.*` を `Item.EquipSlot.*` に置換
- [ ] 4.2 `tests/dungeon/test_character.gd` の `Equipment.EquipSlot.*` を置換
- [ ] 4.3 `tests/esc_menu/test_esc_menu.gd` の `Equipment.EquipSlot.*` を置換
- [ ] 4.4 `tests/guild_scene/test_initial_equipment.gd` の `Equipment.EquipSlot.*` を置換
- [ ] 4.5 テスト実行し失敗することを確認(production がまだ `Equipment.EquipSlot` 参照を持つため)
- [ ] 4.6 `src/esc_menu/esc_menu.gd:25-32` の `EQUIPMENT_SLOT_VALUES` を `Equipment.ALL_SLOTS` 参照に変更(または `Item.EquipSlot.*` ベースで書き直し)
- [ ] 4.7 `src/items/initial_equipment.gd:28` の `Equipment.slot_from_item_slot(item.equip_slot)` を `item.equip_slot` に置換
- [ ] 4.8 全テスト通過を確認しコミット

## 5. .tres 整合性確認

- [ ] 5.1 `data/items/*.tres` をエディタで開いて `equip_slot` の数値が変わっていないことを確認(enum 宣言順を変えていないので不変のはず)
- [ ] 5.2 `godot --headless --import` で再インポートし、`.tres` のロードが警告なしで通ることを確認

## 6. 動作確認

- [ ] 6.1 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過
- [ ] 6.2 ゲームを起動し、ESC → パーティ → アイテム → アイテムを装備するフローを目視確認
- [ ] 6.3 既存セーブをロードして装備が復元されることを確認
- [ ] 6.4 ショップで装備品を購入してパーティメンバーに装備できることを確認

## 7. 仕上げ

- [ ] 7.1 `openspec validate unify-equipment-slot-enums --strict`
- [ ] 7.2 `/simplify`スキルでコードレビューを実施
- [ ] 7.3 `/opsx:verify unify-equipment-slot-enums`
- [ ] 7.4 `/opsx:archive unify-equipment-slot-enums`
