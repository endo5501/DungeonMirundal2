## ADDED Requirements

### Requirement: 回復ポーションのアイテム名は healing_potion で統一される
SHALL: 回復用消費アイテムの `.tres` ファイル名は `healing_potion.tres`、`item_id` は `&"healing_potion"` とし、`magic_potion.tres` (`item_id == &"magic_potion"`) と命名規約を揃える。旧 `potion.tres` は削除され、エイリアス機構は提供されない(既存セーブで `&"potion"` を持つ場合、復元時に当該アイテムは欠落する)。

#### Scenario: healing_potion が ItemRepository に登録される
- **WHEN** `DataLoader.load_all_items()` が呼ばれる
- **THEN** ItemRepository には `find(&"healing_potion")` で見つかるアイテムが含まれる

#### Scenario: 旧 potion アイテムは存在しない
- **WHEN** `data/items/` を確認する
- **THEN** `potion.tres` は存在しない(削除済み or リネーム済み)

#### Scenario: 旧セーブのロードでは欠落する
- **WHEN** `&"potion"` を持つ古いセーブをロードする
- **THEN** `ItemInstance.from_dict({"item_id": &"potion"}, repo)` は null を返し、Inventory には追加されない(README に明記)
