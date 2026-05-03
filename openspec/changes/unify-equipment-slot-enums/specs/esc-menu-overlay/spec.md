## ADDED Requirements

### Requirement: 装備サブメニューは Equipment.ALL_SLOTS をスロット一覧の単一ソースとする
SHALL: ESC メニューの装備サブメニューでスロット一覧を構築する際、`Equipment.ALL_SLOTS` (= `Item.EquipSlot.WEAPON` ... `Item.EquipSlot.ACCESSORY` の配列) を直接参照すること。`esc_menu.gd` 内で独自に WEAPON / ARMOR / ... の重複定数(以前の `EQUIPMENT_SLOT_VALUES`)を保持してはならない。

#### Scenario: 装備サブメニューが ALL_SLOTS から構築される
- **WHEN** ユーザが ESC → パーティ → 装備 を選択する
- **THEN** 表示される 6 個のスロット行は `Equipment.ALL_SLOTS` の順序と内容に一致する

#### Scenario: 新しい装備スロットが追加された場合
- **WHEN** 将来 `Item.EquipSlot` に新しい値が追加され、`Equipment.ALL_SLOTS` がそれを含むよう更新される
- **THEN** ESC メニューの装備サブメニューは追加修正なしで新しいスロットを 7 行目として表示する
