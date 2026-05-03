## MODIFIED Requirements

### Requirement: EncounterOverlay presents a monster party and blocks dungeon input
`EncounterOverlay` SHALL be an abstract base class for encounter UIs. It SHALL declare the `encounter_resolved(outcome: EncounterOutcome)` signal and the abstract `start_encounter(monster_party)` API, but SHALL NOT build any UI itself. Concrete subclasses (`SimpleEncounterOverlay` for text-only encounters and `CombatOverlay` for the full combat UI) SHALL present the monster party and SHALL consume input until dismissed.

#### Scenario: Direct base instantiation rejects start_encounter
- **WHEN** `EncounterOverlay.new()` is instantiated and `start_encounter` is called on it directly
- **THEN** the base class SHALL emit an error (`push_error("EncounterOverlay.start_encounter must be overridden")` or equivalent warning)

#### Scenario: Subclasses provide the UI
- **WHEN** `SimpleEncounterOverlay` or `CombatOverlay` is instantiated and `_ready()` runs
- **THEN** each subclass SHALL build its own UI; the base class SHALL NOT add any UI children

#### Scenario: encounter_resolved is declared on the base
- **WHEN** the `EncounterOverlay` class is inspected
- **THEN** `encounter_resolved(outcome: EncounterOutcome)` SHALL be declared on the base and available to all subclasses

## REMOVED Requirements

### Requirement: EncounterOverlay は ui_accept action で確認入力を受ける
**Reason**: 入力処理は具象サブクラスの責務になった。`ui_accept` による単純確認は `simple-encounter-overlay` capability の新規要件で扱う。
**Migration**: 既存の `EncounterOverlay._unhandled_input` を直接呼ぶテストは `SimpleEncounterOverlay` または `CombatOverlay` を経由する形に置換する。
