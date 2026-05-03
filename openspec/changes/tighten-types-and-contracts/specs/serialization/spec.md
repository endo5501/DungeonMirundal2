## MODIFIED Requirements

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
