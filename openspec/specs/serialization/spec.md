## Purpose
GameState および主要ドメインオブジェクトのシリアライズ契約を規定する。to_dict／from_dict の対称性、バージョン互換、未知フィールド検出などの要件を対象とする。

## Requirements

### Requirement: Character.to_dict()はキャラクターデータをDictionaryに変換する
Character SHALL provide a `to_dict()` method that returns a Dictionary containing character_name, race_id（ファイル名）, job_id（ファイル名）, level, base_stats, current_hp, max_hp, current_mp, max_mp。

#### Scenario: キャラクターをDictionaryに変換
- **WHEN** Character.to_dict() を呼び出す
- **THEN** character_name, race_id, job_id, level, base_stats, current_hp, max_hp, current_mp, max_mp を含むDictionaryが返される

#### Scenario: race_idはファイル名から抽出
- **WHEN** raceのresource_pathが "res://data/races/human.tres" のキャラクターでto_dict()を呼び出す
- **THEN** race_idは "human" となる

#### Scenario: job_idはファイル名から抽出
- **WHEN** jobのresource_pathが "res://data/jobs/fighter.tres" のキャラクターでto_dict()を呼び出す
- **THEN** job_idは "fighter" となる

### Requirement: Character.from_dict()はDictionaryからキャラクターを復元する
Character SHALL provide a `static func from_dict(data: Dictionary) -> Character` that restores a Character instance from a Dictionary.

#### Scenario: Dictionaryからキャラクターを復元
- **WHEN** 有効なキャラクターDictionaryでCharacter.from_dict()を呼び出す
- **THEN** 元のキャラクターと同一のデータを持つCharacterインスタンスが返される

#### Scenario: race/jobはファイル名IDから.tresを読み込んで復元
- **WHEN** race_id="elf", job_id="mage" のDictionaryでfrom_dict()を呼び出す
- **THEN** "res://data/races/elf.tres" と "res://data/jobs/mage.tres" からRaceData/JobDataが読み込まれる

### Requirement: Guild.to_dict()はギルドデータをDictionaryに変換する
Guild SHALL provide a `to_dict()` method that returns a Dictionary containing party_name, characters配列（各Character.to_dict()）, front_row（charactersインデックス配列）, back_row（charactersインデックス配列）。

#### Scenario: ギルドをDictionaryに変換
- **WHEN** キャラクター2体が登録されfront_row[0]に1体目が配置されたGuildでto_dict()を呼び出す
- **THEN** characters配列に2件、front_rowが[0, null, null]のDictionaryが返される

### Requirement: Guild.from_dict()はDictionaryからギルドを復元する
Guild SHALL provide a `static func from_dict(data: Dictionary) -> Guild` that restores a Guild instance.

#### Scenario: Dictionaryからギルドを復元
- **WHEN** 有効なギルドDictionaryでGuild.from_dict()を呼び出す
- **THEN** 全キャラクターとパーティ編成が復元されたGuildインスタンスが返される

### Requirement: PlayerState.to_dict()は位置情報をDictionaryに変換する
PlayerState SHALL provide a `to_dict()` method that returns a Dictionary containing position（[x, y]配列）and facing。

#### Scenario: PlayerStateをDictionaryに変換
- **WHEN** position=(5,7), facing=NORTH のPlayerStateでto_dict()を呼び出す
- **THEN** {"position": [5, 7], "facing": 0} が返される

### Requirement: PlayerState.from_dict()はDictionaryから位置情報を復元する
PlayerState SHALL provide a `static func from_dict(data: Dictionary) -> PlayerState` that restores a PlayerState instance.

#### Scenario: Dictionaryから位置情報を復元
- **WHEN** {"position": [5, 7], "facing": 0} でfrom_dict()を呼び出す
- **THEN** position=Vector2i(5,7), facing=NORTH のPlayerStateが返される

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
DungeonData SHALL provide a `to_dict()` method that returns a Dictionary containing dungeon_name, seed_value, map_size, explored_map（to_dict）, player_state（to_dict）。WizMapのセルデータは含まない。

#### Scenario: DungeonDataをDictionaryに変換
- **WHEN** DungeonData.to_dict() を呼び出す
- **THEN** dungeon_name, seed_value, map_size, explored_map, player_state を含むDictionaryが返される（WizMapのグリッドデータは含まれない）

### Requirement: DungeonData.from_dict()はDictionaryからダンジョンデータを復元する
DungeonData SHALL provide a `static func from_dict(data: Dictionary) -> DungeonData` that restores a DungeonData instance. WizMap SHALL be regenerated from seed_value and map_size.

#### Scenario: Dictionaryからダンジョンデータを復元
- **WHEN** 有効なダンジョンDictionaryでfrom_dict()を呼び出す
- **THEN** seed_valueからWizMapが再生成され、explored_mapとplayer_stateが復元されたDungeonDataが返される

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
