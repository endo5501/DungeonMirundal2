## Context

現状の enum 関係:

```
Item.ItemCategory:  WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY, OTHER, CONSUMABLE
Item.EquipSlot:     NONE, WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY
Equipment.EquipSlot: WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY
```

3 つの enum で同じ装備種別を重複して表現している。`Item.ItemCategory` は「カテゴリ」(消費アイテム vs 装備品 vs その他のグルーピング)、`Item.EquipSlot` は「装備スロット」(`NONE` で「装備しない」を表現)、`Equipment.EquipSlot` は「実際に占有するスロット」(`NONE` がない)。

`Equipment.slot_from_item_slot` は `Item.EquipSlot.WEAPON` → `Equipment.EquipSlot.WEAPON` のような自明なマッピング 6 行。`Item.is_slot_consistent` は `category == WEAPON` なら `equip_slot == WEAPON` であることをチェックする関数で、テストで呼ばれているのみ(ユーザ確認済み)。

セーブデータ形式は `{"weapon": idx, "armor": idx, ...}` の string キーで、SLOT_KEYS 経由の文字列表現に依存している。enum 値は数値なので enum を変えてもセーブ形式には影響しない。

## Goals / Non-Goals

**Goals**
- スロット識別子の単一ソースを `Item.EquipSlot` に統一する
- `Equipment.EquipSlot` を撤廃し、Equipment は `Item.EquipSlot` の値を直接使う
- `slot_from_item_slot` / `is_slot_consistent` を削除する
- `Item.ItemCategory` は別概念(カテゴリ vs スロット)として保持する
- 全テストとプロダクションコードを更新する
- セーブ互換性を維持する

**Non-Goals**
- `Item.ItemCategory` を撤廃する(消費アイテム/装備品/その他の高レベル分類は別の概念で必要)
- enum を `StringName` ベースに変える(過剰)
- セーブフォーマット変更
- データファイル(`.tres`)の export 値を変える(`equip_slot` フィールドは `Item.EquipSlot` の値なので不変)

## Decisions

### Decision 1: `Item.EquipSlot` を「単一ソース」とする

**選択**: Equipment は内部で `Item.EquipSlot.WEAPON` ... `Item.EquipSlot.ACCESSORY` の 6 値を Dictionary キーとして使う。`Item.EquipSlot.NONE` は Equipment では無効値として扱う。

**理由**:
- `Item.EquipSlot` は既に `.tres` の export 値で使われているので、これを単一ソースにすれば追加 enum を増やさずに済む
- `NONE` の存在は意味がある(消費アイテムや「その他」アイテムは equip_slot=NONE)
- Equipment 側で `NONE` を排除する(`equip(NONE, ...)` を呼んだらエラー)のは Equipment の責任なので、API シグネチャは `int` のままで内部チェックする

### Decision 2: `Equipment.ALL_SLOTS` の値を `Item.EquipSlot` に切り替える

**選択**:
```gdscript
const ALL_SLOTS: Array[int] = [
    Item.EquipSlot.WEAPON,
    Item.EquipSlot.ARMOR,
    Item.EquipSlot.HELMET,
    Item.EquipSlot.SHIELD,
    Item.EquipSlot.GAUNTLET,
    Item.EquipSlot.ACCESSORY,
]
```

`SLOT_KEYS` も同様に `Item.EquipSlot.WEAPON: "weapon", ...` と書き換える。

**理由**:
- 値だけ変わるので、`for slot in ALL_SLOTS:` のループは無変更
- セーブの string キー(weapon, armor, ...)は SLOT_KEYS 経由なので不変

### Decision 3: `slot_from_item_slot` 撤廃 → 単純な `slot` 直接渡し

**選択**: `Equipment.equip(slot, instance, character)` の引数 `slot` には呼び出し元が `instance.item.equip_slot` を直接渡す形を許可する。`slot_from_item_slot` は不要。

```gdscript
# Before
ch.equipment.equip(Equipment.slot_from_item_slot(item.equip_slot), inst, ch)
# After
ch.equipment.equip(item.equip_slot, inst, ch)
```

**理由**:
- マッピング関数自体が不要になる
- 呼び出しがシンプル(`InitialEquipment` で 1 行短くなる)
- `equip_slot == NONE` のときは `equip` が `SLOT_MISMATCH` を返す(既存挙動と同じ)

### Decision 4: `is_slot_consistent` を削除

**選択**: `Item.is_slot_consistent` を完全に削除する。テスト側の呼び出しを「`Item` が WEAPON/ARMOR/... のとき equip_slot がそれぞれ対応していること」をデータバリデーションテスト 1 箇所に集約する。

**理由**:
- `.tres` の整合性チェックなら `tests/items/test_data_files.gd` 等で 1 回ロード時に行う方が筋がいい
- 実行時に同じ Item インスタンスに対して何度も呼ぶ意味がない
- ユーザ確認: テスト以外の呼び出しなし

**実装**: `tests/items/test_item.gd` (既存) に「`data/items/*.tres` をロードしてカテゴリと equip_slot の整合を確認するテスト」を残す(関数を呼ぶのではなく、`match category` 構造をテスト内で書く)。

### Decision 5: テストファイルの大量更新

**選択**: 全 17 箇所の `Equipment.EquipSlot.*` を `Item.EquipSlot.*` に sed-replace する。

**理由**:
- 機械的置換で済む
- 1 commit で grep + 置換 + テスト実行を完結
- Git diff も読みやすい(同じ変更が並ぶだけ)

### Decision 6: `EQUIPMENT_SLOT_VALUES` の整理

**選択**: `src/esc_menu/esc_menu.gd:25-32` の `EQUIPMENT_SLOT_VALUES` を `Equipment.ALL_SLOTS` を直接参照する形に変える。

```gdscript
# Before
const EQUIPMENT_SLOT_VALUES: Array[int] = [
    Equipment.EquipSlot.WEAPON, ..., Equipment.EquipSlot.ACCESSORY,
]
# After
# (Equipment.ALL_SLOTS をそのまま使う)
```

**理由**:
- 重複定数を 1 つ減らす
- `Equipment.ALL_SLOTS` が信頼できる単一ソースとして機能する

## Risks / Trade-offs

- **[セーブ互換性]** SLOT_KEYS の string 表現を維持していれば不変 → 互換性は守られる。
- **[`.tres` の数値]** `Item.EquipSlot.WEAPON == 1` という値が `.tres` ファイルにシリアライズされている可能性 → Godot の Resource フォーマットは enum 値を数値で保存するが、enum の宣言順を変えていないので不変。実装時に念のため `.tres` を grep して数値が合っていることを確認する。
- **[Equipment.equip(NONE) のテスト]** 新たに「NONE を渡したら SLOT_MISMATCH」というケースが現れる → 既存テストの slot mismatch ケース(WEAPON を ARMOR スロットに、等)と同質なので、ケース 1 つ追加で済む。
- **[`Equipment.EquipSlot` を参照しているコードの見落とし]** grep で 17 箇所確認済み。実装時にもう一度 grep して取りこぼしを潰す。
