## Purpose
セーブ／ロードの JSON ファイル入出力と last_slot 管理を規定する。スロット採番・上書き・検証・ファイル欠損時のフォールバック挙動を対象とする。

## Requirements

### Requirement: SaveManagerはゲーム状態をJSONファイルに保存する
SaveManager SHALL provide a `save(slot_number: int)` method that serializes the current GameState to a JSON file at `user://saves/save_NNN.json` (zero-padded 3 digits).

#### Scenario: ゲーム状態を保存
- **WHEN** save(1) を呼び出す
- **THEN** `user://saves/save_001.json` にゲーム状態のJSONが書き出される

#### Scenario: 保存時にlast_slot.txtを更新
- **WHEN** save(3) を呼び出す
- **THEN** `user://saves/last_slot.txt` に "3" が書き込まれる

#### Scenario: savesディレクトリが存在しない場合は作成する
- **WHEN** `user://saves/` ディレクトリが存在しない状態でsave()を呼び出す
- **THEN** ディレクトリが自動作成されセーブファイルが書き出される

### Requirement: SaveManagerはJSONファイルからゲーム状態を復元する
SaveManager SHALL provide a `load(slot_number: int)` method that reads a JSON file and restores GameState.

#### Scenario: ゲーム状態を復元
- **WHEN** load(1) を呼び出す
- **THEN** `user://saves/save_001.json` を読み込み、GameState.guild と GameState.dungeon_registry が復元される

#### Scenario: ロード時にgame_locationが復元される
- **WHEN** game_location="dungeon"のセーブデータをロードする
- **THEN** GameState.game_location が "dungeon" に設定される

#### Scenario: ロード時にcurrent_dungeon_indexが復元される
- **WHEN** current_dungeon_index=2のセーブデータをロードする
- **THEN** GameState.current_dungeon_index が 2 に設定される

### Requirement: SaveManagerはセーブファイル一覧を取得できる
SaveManager SHALL provide a `list_saves() -> Array[Dictionary]` method that returns metadata for all save files, sorted by last_saved descending (newest first).

#### Scenario: セーブファイル一覧の取得
- **WHEN** save_001.json と save_002.json が存在する状態でlist_saves()を呼び出す
- **THEN** 2件のメタ情報Dictionary（slot_number, last_saved, game_location, party_name, max_level, dungeon_name）が返される

#### Scenario: セーブファイルが存在しない場合
- **WHEN** セーブファイルが1件も存在しない状態でlist_saves()を呼び出す
- **THEN** 空の配列が返される

#### Scenario: 新しい順にソートされる
- **WHEN** 複数のセーブファイルが異なる日時で保存されている場合
- **THEN** last_savedが新しい順に並んだ配列が返される

### Requirement: SaveManagerは最終セーブスロット番号を取得できる
SaveManager SHALL provide a `get_last_slot() -> int` method that reads last_slot.txt and returns the slot number. Returns -1 if no last slot exists.

#### Scenario: 最終スロット番号の取得
- **WHEN** last_slot.txt に "3" と記録されている状態でget_last_slot()を呼び出す
- **THEN** 3 が返される

#### Scenario: last_slot.txtが存在しない場合
- **WHEN** last_slot.txt が存在しない状態でget_last_slot()を呼び出す
- **THEN** -1 が返される

#### Scenario: last_slot.txtのファイルが削除されている場合
- **WHEN** last_slot.txt が "5" を指しているがsave_005.jsonが存在しない場合にget_last_slot()を呼び出す
- **THEN** -1 が返される

### Requirement: SaveManagerは次の連番スロット番号を取得できる
SaveManager SHALL provide a `get_next_slot_number() -> int` method that returns the next available slot number.

#### Scenario: 次の連番を取得
- **WHEN** save_001.json, save_002.json が存在する状態でget_next_slot_number()を呼び出す
- **THEN** 3 が返される

#### Scenario: セーブファイルが存在しない場合
- **WHEN** セーブファイルが存在しない状態でget_next_slot_number()を呼び出す
- **THEN** 1 が返される

### Requirement: SaveManagerはセーブファイルを削除できる
SaveManager SHALL provide a `delete_save(slot_number: int)` method that removes the specified save file.

#### Scenario: セーブファイルの削除
- **WHEN** delete_save(2) を呼び出す
- **THEN** `user://saves/save_002.json` が削除される

### Requirement: SaveManagerはセーブファイルの存在を確認できる
SaveManager SHALL provide a `has_saves() -> bool` method that returns true if at least one save file exists.

#### Scenario: セーブファイルが存在する場合
- **WHEN** save_001.json が存在する状態でhas_saves()を呼び出す
- **THEN** true が返される

#### Scenario: セーブファイルが存在しない場合
- **WHEN** セーブファイルが存在しない状態でhas_saves()を呼び出す
- **THEN** false が返される

### Requirement: セーブデータにはバージョン番号を含む
SaveManager SHALL include a "version" field (value: 1) in every save file. load() SHALL verify the version and reject save files with a version higher than CURRENT_VERSION (forward compatibility: older versions are accepted for future migration support).

#### Scenario: バージョン番号の記録
- **WHEN** save()を呼び出す
- **THEN** JSONファイルに "version": 1 が含まれる

#### Scenario: 未来のバージョンのロード拒否
- **WHEN** version値がCURRENT_VERSIONより大きいセーブデータをロードする
- **THEN** ロードが失敗しfalseが返される

#### Scenario: 過去のバージョンのロード許可
- **WHEN** version値がCURRENT_VERSION以下のセーブデータをロードする
- **THEN** ロードが成功する（将来のマイグレーション対応のため前方互換性を維持）

### Requirement: SaveManager persists party inventory including gold and items
The system SHALL include the party-shared `Inventory` (gold and item list) in every save file and SHALL restore it on load. The save JSON SHALL contain an `"inventory"` object with `"gold": <int>` and `"items": Array[Dictionary]`, where each item dictionary is the result of `ItemInstance.to_dict()` (at least `{"item_id": ..., "identified": ...}`).

#### Scenario: Save writes inventory gold
- **WHEN** `save(1)` is called with `GameState.inventory.gold == 750`
- **THEN** `save_001.json` SHALL contain `inventory.gold == 750`

#### Scenario: Save writes inventory items in order
- **WHEN** `save(1)` is called with an inventory containing items A, B, C in that order
- **THEN** the `inventory.items` array in the saved JSON SHALL contain three dictionaries in that same order (A, B, C)

#### Scenario: Load restores inventory gold and items
- **WHEN** `load(1)` is called on a file with `inventory.gold == 750` and items A, B, C
- **THEN** `GameState.inventory.gold` SHALL equal `750` and `inventory.list()` SHALL return the restored ItemInstances in order A, B, C

#### Scenario: Load tolerates missing inventory key
- **WHEN** `load(1)` is called on a legacy save file that has no `inventory` key
- **THEN** the load SHALL succeed with `GameState.inventory.gold == 0` and an empty item list (no error)

### Requirement: SaveManager persists per-character equipment
The system SHALL include each Character's `Equipment` in the save file as part of the Character's serialized dictionary. Equipment SHALL be stored as a mapping of `slot_name: String -> index: int | null`, where `index` refers to the position in `inventory.items` of the equipped ItemInstance.

#### Scenario: Save writes equipment slot indices
- **WHEN** `save(1)` is called with a Character whose WEAPON slot holds the ItemInstance at `inventory.list()[0]` and whose ARMOR slot holds the one at `inventory.list()[2]`, other slots empty
- **THEN** the saved Character's `equipment` SHALL be `{"weapon": 0, "armor": 2, "helmet": null, "shield": null, "gauntlet": null, "accessory": null}`

#### Scenario: Load restores equipment slot references
- **WHEN** `load(1)` is called on a file with a Character having `equipment.weapon == 0`
- **THEN** the restored Character's `equipment.get_equipped(WEAPON)` SHALL point to the restored `inventory.list()[0]` ItemInstance (same object reference after restore)

#### Scenario: Load tolerates missing equipment key
- **WHEN** `load(1)` is called on a legacy save file where a Character lacks the `equipment` key
- **THEN** the load SHALL succeed with that Character having all six slots empty (no error)

### Requirement: SaveManager load order ensures inventory exists before character equipment
The system SHALL deserialize inventory before per-character equipment so that equipment indices can resolve into `inventory.list()`.

#### Scenario: Inventory is deserialized before Guild
- **WHEN** `load(slot)` processes the save JSON
- **THEN** the inventory SHALL be populated before any Character's equipment is restored, ensuring slot-index lookups succeed
