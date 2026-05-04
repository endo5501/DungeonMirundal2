## Purpose
GameState および主要ドメインオブジェクトのシリアライズ契約を規定する。to_dict／from_dict の対称性、バージョン互換、未知フィールド検出などの要件を対象とする。
## Requirements
### Requirement: Character.to_dict()はキャラクターデータをDictionaryに変換する
Character SHALL provide a `to_dict()` method that returns a Dictionary containing character_name, race_id（RaceData.id 経由で取得した文字列。ファイル名と一致）, job_id（JobData.id 経由で取得した文字列。ファイル名と一致）, level, base_stats, current_hp, max_hp, current_mp, max_mp。

#### Scenario: キャラクターをDictionaryに変換
- **WHEN** Character.to_dict() を呼び出す
- **THEN** character_name, race_id, job_id, level, base_stats, current_hp, max_hp, current_mp, max_mp を含むDictionaryが返される

#### Scenario: race_id は RaceData.id フィールドから取得
- **WHEN** raceの id が `&"human"` のキャラクターでto_dict()を呼び出す
- **THEN** race_idは `"human"` となる

#### Scenario: job_id は JobData.id フィールドから取得
- **WHEN** jobの id が `&"fighter"` のキャラクターでto_dict()を呼び出す
- **THEN** job_idは `"fighter"` となる

#### Scenario: id 未設定時は resource_path にフォールバック
- **WHEN** RaceData.id が `&""` (空) でかつ resource_path が `"res://data/races/human.tres"` のキャラクターで to_dict() を呼び出す
- **THEN** race_id は `"human"` となり、`push_warning` が呼ばれる(移行期間用 fallback)

### Requirement: Character.from_dict()はDictionaryからキャラクターを復元する
Character SHALL provide a `static func from_dict(data: Dictionary, inventory: Inventory = null) -> Character` that restores a Character instance from a Dictionary. The method SHALL load the RaceData and JobData resources from the recorded `race_id` / `job_id` strings. When EITHER the RaceData OR the JobData fails to load (the resource file does not exist or fails to cast), the method SHALL emit `push_warning` describing the missing resource and SHALL return `null`. Callers SHALL treat `null` as "this character entry is unrecoverable" and SHALL skip it.

#### Scenario: Dictionaryからキャラクターを復元
- **WHEN** 有効なキャラクターDictionaryでCharacter.from_dict()を呼び出す
- **THEN** 元のキャラクターと同一のデータを持つCharacterインスタンスが返される

#### Scenario: race/jobはファイル名IDから.tresを読み込んで復元
- **WHEN** race_id="elf", job_id="mage" のDictionaryでfrom_dict()を呼び出す
- **THEN** "res://data/races/elf.tres" と "res://data/jobs/mage.tres" からRaceData/JobDataが読み込まれる

#### Scenario: race リソースが見つからない場合は null を返す
- **WHEN** race_id="bogus_race" (存在しない) でfrom_dict()を呼び出す
- **THEN** `null` が返り、`push_warning` が呼ばれる

#### Scenario: job リソースが見つからない場合は null を返す
- **WHEN** job_id="bogus_job" (存在しない) でfrom_dict()を呼び出す
- **THEN** `null` が返り、`push_warning` が呼ばれる

### Requirement: Guild.to_dict()はギルドデータをDictionaryに変換する
Guild SHALL provide a `to_dict()` method that returns a Dictionary containing party_name, characters配列（各Character.to_dict()）, front_row（charactersインデックス配列）, back_row（charactersインデックス配列）。

#### Scenario: ギルドをDictionaryに変換
- **WHEN** キャラクター2体が登録されfront_row[0]に1体目が配置されたGuildでto_dict()を呼び出す
- **THEN** characters配列に2件、front_rowが[0, null, null]のDictionaryが返される

### Requirement: Guild.from_dict()はDictionaryからギルドを復元する
Guild SHALL provide a `static func from_dict(data: Dictionary, inventory: Inventory = null) -> Guild` that restores a Guild instance. The method SHALL skip Character entries whose `Character.from_dict` returns `null` (logging the skip via `push_warning`). The skipped index positions SHALL NOT be registered into the resulting Guild's `_characters` array. Party row positions (`front_row` / `back_row`) referencing a skipped index SHALL remain unassigned (null) instead of pointing at the wrong character.

#### Scenario: Dictionaryからギルドを復元
- **WHEN** 有効なギルドDictionaryでGuild.from_dict()を呼び出す
- **THEN** 全キャラクターとパーティ編成が復元されたGuildインスタンスが返される

#### Scenario: 壊れたキャラクターはスキップして他は復元される
- **WHEN** characters 配列の 2 番目の要素の race_id が存在しないリソースを指している
- **THEN** 1 番目と 3 番目以降のキャラクターは登録され、2 番目はスキップされる

#### Scenario: 壊れたキャラクターを指していたパーティ位置は空のままになる
- **WHEN** front_row=[1, null, null] (1 番目のキャラクターが壊れている)
- **THEN** front_row[0] は null になり、他の有効な配置はそのまま復元される

#### Scenario: 全キャラクターが壊れていても空 Guild が返る
- **WHEN** 全キャラクターの race_id が存在しないリソースを指している
- **THEN** `_characters` が空の Guild が返り、ゲームはクラッシュしない

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

### Requirement: ExploredMap.to_dict()は探索済みセルをDictionaryに変換する
ExploredMap SHALL provide a `to_dict()` method that returns a Dictionary containing visited cells as an array of [x, y] pairs.

#### Scenario: ExploredMapをDictionaryに変換
- **WHEN** Vector2i(2,3)とVector2i(4,5)が探索済みのExploredMapでto_dict()を呼び出す
- **THEN** {"visited": [[2, 3], [4, 5]]} が返される

### Requirement: ExploredMap.from_dict()はDictionaryから探索情報を復元する
ExploredMap SHALL provide a `static func from_dict(data: Dictionary) -> ExploredMap` that restores an ExploredMap instance.

#### Scenario: Dictionaryから探索情報を復元
- **WHEN** {"visited": [[2, 3], [4, 5]]} でfrom_dict()を呼び出す
- **THEN** Vector2i(2,3)とVector2i(4,5)がvisitedのExploredMapが返される

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

### Requirement: DungeonRegistry.to_dict()はダンジョン一覧をDictionaryに変換する
DungeonRegistry SHALL provide a `to_dict()` method that returns a Dictionary containing all dungeon data as an array.

#### Scenario: DungeonRegistryをDictionaryに変換
- **WHEN** 2つのダンジョンを持つDungeonRegistryでto_dict()を呼び出す
- **THEN** {"dungeons": [dungeon1.to_dict(), dungeon2.to_dict()]} が返される

### Requirement: DungeonRegistry.from_dict()はDictionaryからダンジョン一覧を復元する
DungeonRegistry SHALL provide a `static func from_dict(data: Dictionary) -> DungeonRegistry` that restores a DungeonRegistry instance.

#### Scenario: Dictionaryからダンジョン一覧を復元
- **WHEN** 有効なダンジョン一覧DictionaryでDungeonRegistry.from_dict()を呼び出す
- **THEN** 全ダンジョンが復元されたDungeonRegistryが返される

### Requirement: from_dict()は不足フィールドにデフォルト値を使用する
全クラスのfrom_dict() SHALL handle missing fields gracefully by using default values, enabling forward compatibility when new fields are added in future versions.

#### Scenario: 不足フィールドにはデフォルト値が使用される
- **WHEN** 一部のフィールドが欠落したDictionaryでfrom_dict()を呼び出す
- **THEN** 欠落フィールドにはデフォルト値が使用され、エラーにならない

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

