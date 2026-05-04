## ADDED Requirements

### Requirement: FloorData.to_dict() converts floor data to a Dictionary
FloorData SHALL provide a `to_dict()` method that returns a Dictionary containing `seed_value` (int), `map_size` (int), and `explored_map` (the result of `ExploredMap.to_dict()`). The Dictionary SHALL NOT contain `wiz_map` cell data (the WizMap is regenerated from `seed_value` and `map_size`).

#### Scenario: FloorData を Dictionary に変換
- **WHEN** seed_value=42, map_size=16 で 5 セル探索済みの FloorData で to_dict() を呼ぶ
- **THEN** {"seed_value": 42, "map_size": 16, "explored_map": {"visited": [...]}} が返される (wiz_map のグリッドデータは含まれない)

### Requirement: FloorData.from_dict() restores floor data from a Dictionary
FloorData SHALL provide a `static func from_dict(data: Dictionary) -> FloorData` that restores a FloorData instance. WizMap SHALL be regenerated from `seed_value` and `map_size` (and the floor's role within the parent DungeonData, which is supplied by the caller).

#### Scenario: Dictionary から FloorData を復元
- **WHEN** {"seed_value": 42, "map_size": 16, "explored_map": {"visited": [[2,3]]}} で from_dict() を呼ぶ
- **THEN** seed_value からマップが再生成され、explored_map が復元された FloorData が返される

## MODIFIED Requirements

### Requirement: PlayerState.to_dict()は位置情報をDictionaryに変換する
PlayerState SHALL provide a `to_dict()` method that returns a Dictionary containing position（[x, y]配列）、facing、current_floor。

#### Scenario: PlayerStateをDictionaryに変換
- **WHEN** position=(5,7), facing=NORTH, current_floor=2 のPlayerStateでto_dict()を呼び出す
- **THEN** {"position": [5, 7], "facing": 0, "current_floor": 2} が返される

### Requirement: PlayerState.from_dict()はDictionaryから位置情報を復元する
PlayerState SHALL provide a `static func from_dict(data: Dictionary) -> PlayerState` that restores a PlayerState instance. Missing `current_floor` SHALL default to 0.

#### Scenario: Dictionaryから位置情報を復元
- **WHEN** {"position": [5, 7], "facing": 0, "current_floor": 2} でfrom_dict()を呼び出す
- **THEN** position=Vector2i(5,7), facing=NORTH, current_floor=2 のPlayerStateが返される

#### Scenario: current_floor 未設定時は 0 にデフォルト
- **WHEN** {"position": [5, 7], "facing": 0} (current_floor 欠落) で from_dict() を呼ぶ
- **THEN** current_floor=0 の PlayerState が返される

### Requirement: DungeonData.to_dict()はダンジョンデータをDictionaryに変換する
DungeonData SHALL provide a `to_dict()` method that returns a Dictionary containing `dungeon_name`, `floors` (Array of `FloorData.to_dict()` results), `player_state` (PlayerState.to_dict() の結果)。各 floor の wiz_map のセルデータは含まない。

#### Scenario: DungeonDataをDictionaryに変換
- **WHEN** floors.size() == 3 の DungeonData で to_dict() を呼ぶ
- **THEN** {"dungeon_name": ..., "floors": [floor0_dict, floor1_dict, floor2_dict], "player_state": ...} が返される

#### Scenario: WizMap のグリッドデータは保存されない
- **WHEN** to_dict() の結果を文字列化する
- **THEN** wiz_map のセルやエッジ情報が含まれない（各 floor の seed_value と map_size のみ）

### Requirement: DungeonData.from_dict()はDictionaryからダンジョンデータを復元する
DungeonData SHALL provide a `static func from_dict(data: Dictionary) -> DungeonData` that restores a DungeonData instance. 各 FloorData は seed_value と map_size から WizMap を再生成し、floor index に応じた階の役割（first / middle / last / 単一）でタイルを再配置する。

#### Scenario: Dictionaryからダンジョンデータを復元
- **WHEN** 有効な多階層ダンジョンDictionaryでfrom_dict()を呼び出す
- **THEN** floors 配列の各要素から WizMap が再生成され、explored_map が復元され、player_state（current_floor 含む）が復元された DungeonData が返される

#### Scenario: 各階のタイルは floor index に応じて配置される
- **WHEN** floors.size() == 3 の DungeonData を from_dict で復元する
- **THEN** floors[0] は START + STAIRS_DOWN、floors[1] は STAIRS_UP + STAIRS_DOWN、floors[2] は STAIRS_UP + GOAL を持つ
