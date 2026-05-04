## MODIFIED Requirements

### Requirement: Character.to_dict()はキャラクターデータをDictionaryに変換する

`Character.to_dict()` SHALL serialize the character into a Dictionary including `character_name`, `race_id`, `job_id`, `level`, `base_stats`, `current_hp`, `max_hp`, `current_mp`, `max_mp`, `accumulated_exp`, `known_spells`, `persistent_statuses`, and (when an inventory is provided) `equipment`. The `persistent_statuses` field SHALL be an `Array` of `String`-encoded status ids derived from `Character.persistent_statuses` (`StringName -> String`).

#### Scenario: Character.to_dict serializes persistent_statuses
- **WHEN** a Character with `persistent_statuses == [&"poison"]` calls `to_dict`
- **THEN** the returned Dictionary SHALL contain `"persistent_statuses": ["poison"]`

#### Scenario: Empty persistent_statuses serializes to empty array
- **WHEN** a Character with `persistent_statuses == []` calls `to_dict`
- **THEN** the returned Dictionary SHALL contain `"persistent_statuses": []`

#### Scenario: Existing fields are preserved
- **WHEN** a Character with previous fields populated calls `to_dict`
- **THEN** all previously-required fields (character_name, race_id, job_id, level, base_stats, current_hp, max_hp, current_mp, max_mp, accumulated_exp, known_spells) SHALL still appear in the returned Dictionary

### Requirement: Character.from_dict()はDictionaryからキャラクターを復元する

`Character.from_dict(data, inventory, repo)` SHALL restore a Character from a Dictionary. The function SHALL read `persistent_statuses` from the Dictionary; when missing, SHALL initialize `persistent_statuses` to an empty Array. Existing fields and behavior SHALL be preserved.

#### Scenario: from_dict reads persistent_statuses
- **WHEN** the input Dictionary contains `"persistent_statuses": ["poison", "petrify"]`
- **THEN** the returned Character SHALL have `persistent_statuses == [&"poison", &"petrify"]` (Strings normalized to StringName)

#### Scenario: from_dict tolerates missing persistent_statuses
- **WHEN** the input Dictionary lacks the `persistent_statuses` key
- **THEN** the returned Character's `persistent_statuses` SHALL be an empty Array (no warning required since this change ships during development)

#### Scenario: Unknown status ids are kept as-is
- **WHEN** the input Dictionary contains an id not present in StatusRepository
- **THEN** the function SHALL still include it in `persistent_statuses` (no validation in this change; later changes may add a strict-mode option)
