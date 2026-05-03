## Why

`Item.ItemCategory` (8 値)、`Item.EquipSlot` (7 値、`NONE` を含む)、`Equipment.EquipSlot` (6 値) という重複した enum が並存しており、装備カテゴリを 1 つ追加するたびに 5 箇所(両 enum、`Equipment.slot_from_item_slot`、`Item.is_slot_consistent`、`Equipment.SLOT_KEYS`)を手で同期する必要がある。

`Equipment.slot_from_item_slot` は `Item.EquipSlot` から `Equipment.EquipSlot` への手動マッピング、`Item.is_slot_consistent` はこの 2 つの enum が整合しているかを実行時にチェックする関数で、いずれも単一ソースがあれば不要なバンド・エイドである。`Item.is_slot_consistent` はテスト以外で呼ばれていないこともユーザ確認済み。

将来の F003 / F006 系リファクタの前に、この単一ソース化を済ませておく。

## What Changes

- `Equipment.EquipSlot` enum を撤廃し、Equipment は `Item.EquipSlot` の値(`NONE` を除く 6 値)を直接スロット識別子として使う
- `Equipment.slot_from_item_slot` を削除する
- `Item.is_slot_consistent` を削除する
- `Equipment.SLOT_KEYS` / `ALL_SLOTS` を `Item.EquipSlot` ベースで再定義する
- `Equipment.equip` / `unequip` / `get_equipped` の引数型は `int` のままだが、許容値は `Item.EquipSlot.WEAPON` ... `Item.EquipSlot.ACCESSORY` のいずれかに固定する(`NONE` を渡すと拒否)
- `EQUIPMENT_SLOT_VALUES` (`src/esc_menu/esc_menu.gd:25-32`) を `Item.EquipSlot` に切り替える
- 全テストファイルの `Equipment.EquipSlot.*` 参照を `Item.EquipSlot.*` に置換する
- `InitialEquipment.gd` の `Equipment.slot_from_item_slot(item.equip_slot)` を `item.equip_slot` 直接参照に置換する

## Capabilities

### Modified Capabilities

- `equipment`: スロット識別の単一ソースを `Item.EquipSlot` に変更。`Equipment.EquipSlot` を撤廃。
- `items`: `is_slot_consistent` の暗黙的契約を削除(spec に明示されていなかったが、`category` と `equip_slot` が常に整合することを保証する責任を Item 側で持たないことを明文化)。

## Impact

- **削除**:
  - `src/items/equipment.gd` から `enum EquipSlot`、`slot_from_item_slot`、`SLOT_KEYS` 定数の旧キー、`ALL_SLOTS` の旧値
  - `src/items/item.gd` から `is_slot_consistent`
- **変更コード**:
  - `src/items/equipment.gd` — `_slots` を `Item.EquipSlot` キーで再構築、`equip` / `unequip` / `get_equipped` / `to_dict` / `from_dict` の内部実装を更新
  - `src/esc_menu/esc_menu.gd:25-32` — `EQUIPMENT_SLOT_VALUES` を `Item.EquipSlot` に
  - `src/items/initial_equipment.gd:28` — `Equipment.slot_from_item_slot(item.equip_slot)` を `item.equip_slot` に
  - 全テストファイル(`tests/items/test_equipment.gd`, `tests/items/test_item.gd`, `tests/combat/test_inventory_equipment_provider.gd`, `tests/dungeon/test_character.gd`, `tests/esc_menu/test_esc_menu.gd`, `tests/guild_scene/test_initial_equipment.gd`) — `Equipment.EquipSlot.*` を `Item.EquipSlot.*` に
- **互換性**:
  - セーブデータ JSON の `equipment` キーは `{"weapon": idx, "armor": idx, ...}` の形式を維持(SLOT_KEYS の文字列表現は不変)
  - 既存セーブからの load は問題なし
- **依存関係**:
  - C1, C2 と独立に進行可能
  - C3 完了後、C6(esc_menu リファクタ)で `EQUIPMENT_SLOT_VALUES` の単純化を享受できる
