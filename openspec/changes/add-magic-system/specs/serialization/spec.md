## MODIFIED Requirements

### Requirement: Character.to_dict()はキャラクターデータをDictionaryに変換する

Character SHALL provide a `to_dict()` method that returns a Dictionary containing character_name, race_id（RaceData.id 経由で取得した文字列。ファイル名と一致）, job_id（JobData.id 経由で取得した文字列。ファイル名と一致）, level, base_stats, current_hp, max_hp, current_mp, max_mp, accumulated_exp, equipment（オプション、inventory が与えられた場合のみ）, および `known_spells`（`Array[String]`、習得済み呪文 id を文字列化したもの）。

#### Scenario: キャラクターをDictionaryに変換
- **WHEN** Character.to_dict() を呼び出す
- **THEN** character_name, race_id, job_id, level, base_stats, current_hp, max_hp, current_mp, max_mp, accumulated_exp, known_spells を含むDictionaryが返される

#### Scenario: race_id は RaceData.id フィールドから取得
- **WHEN** raceの id が `&"human"` のキャラクターでto_dict()を呼び出す
- **THEN** race_idは `"human"` となる

#### Scenario: job_id は JobData.id フィールドから取得
- **WHEN** jobの id が `&"fighter"` のキャラクターでto_dict()を呼び出す
- **THEN** job_idは `"fighter"` となる

#### Scenario: id 未設定時は resource_path にフォールバック
- **WHEN** RaceData.id が `&""` (空) でかつ resource_path が `"res://data/races/human.tres"` のキャラクターで to_dict() を呼び出す
- **THEN** race_id は `"human"` となり、`push_warning` が呼ばれる(移行期間用 fallback)

#### Scenario: known_spells は文字列配列として保存される
- **WHEN** Character の `known_spells` が `[&"fire", &"frost"]` でto_dict()を呼び出す
- **THEN** 返された Dictionary の `known_spells` キーは `["fire", "frost"]` という `Array[String]` 相当である

#### Scenario: 非魔法職の known_spells は空配列
- **WHEN** Fighter の Character で to_dict() を呼び出す
- **THEN** 返された Dictionary の `known_spells` は空配列である

### Requirement: Character.from_dict()はDictionaryからキャラクターを復元する

Character SHALL provide a `static func from_dict(data: Dictionary, inventory: Inventory = null) -> Character` that restores a Character instance from a Dictionary. The method SHALL load the RaceData and JobData resources from the recorded `race_id` / `job_id` strings. When EITHER the RaceData OR the JobData fails to load (the resource file does not exist or fails to cast), the method SHALL emit `push_warning` describing the missing resource and SHALL return `null`. Callers SHALL treat `null` as "this character entry is unrecoverable" and SHALL skip it.

When `data.known_spells` exists, the method SHALL load that list and convert each string to `StringName` to populate `Character.known_spells`. When `data.known_spells` is missing (legacy save), the method SHALL reconstruct `known_spells` by replaying the loaded `JobData.spell_progression` for every key `lv` such that `lv <= ch.level`, deduplicating ids, and SHALL emit `push_warning` describing the migration.

Spell ids in `data.known_spells` that do not resolve in the SpellRepository SHALL be silently dropped from `Character.known_spells`, and a `push_warning` SHALL be emitted listing the dropped ids.

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

#### Scenario: known_spells が文字列配列で保存されている場合は復元する
- **WHEN** `known_spells = ["fire", "frost"]` を含む Mage の Dictionary で from_dict() を呼ぶ
- **THEN** `Character.known_spells` は `[&"fire", &"frost"]` (StringName 配列) となる

#### Scenario: known_spells キー欠落時は JobData.spell_progression から再構築する
- **WHEN** `known_spells` キーが存在せず、`level = 3` の Mage の Dictionary で from_dict() を呼ぶ
- **THEN** `Character.known_spells` は Mage の `spell_progression` の `1` と `3` のキー値を結合した内容（重複排除後）となり、`push_warning` が呼ばれる

#### Scenario: 未知の呪文 id はドロップされる
- **WHEN** `known_spells = ["fire", "obsolete_spell"]` を含む Dictionary で from_dict() を呼び、`obsolete_spell` が SpellRepository に存在しない
- **THEN** `Character.known_spells` は `[&"fire"]` のみとなり、`push_warning` で `obsolete_spell` がドロップされたことが告知される
