## MODIFIED Requirements

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
