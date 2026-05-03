## ADDED Requirements

### Requirement: Equipment.equip は can_equip を内部で呼んで重複を排除する
SHALL: `Equipment.equip(slot, instance, character)` の slot match と job allowed の check は、`Equipment.can_equip(item, slot, character)` を内部で呼ぶ形で実装される。`equip` は `can_equip` の結果が false の場合に詳細な FailReason を判定して返す。

#### Scenario: equip が can_equip を呼ぶ
- **WHEN** `equip(slot, instance, character)` が呼ばれる
- **THEN** 内部で `can_equip(instance.item, slot, character)` 相当のチェックロジックが共有され、重複したスロット/ジョブ判定コードは存在しない

#### Scenario: equip と can_equip の判定が一致する
- **WHEN** `can_equip` が false を返す任意の組み合わせで `equip` を呼ぶ
- **THEN** `equip` は失敗(success == false)を返す

#### Scenario: equip の FailReason は失敗事由を区別する
- **WHEN** slot mismatch で equip が失敗する
- **THEN** `EquipResult.reason == SLOT_MISMATCH`

#### Scenario: job not allowed で equip が失敗する
- **WHEN** job が allowed_jobs に含まれない状態で equip が呼ばれる
- **THEN** `EquipResult.reason == JOB_NOT_ALLOWED`
