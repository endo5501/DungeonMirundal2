## ADDED Requirements

### Requirement: EncounterCoordinator のデフォルト Overlay は SimpleEncounterOverlay
SHALL: `EncounterCoordinator._ready` で `_overlay == null` の場合、`SimpleEncounterOverlay.new()` を instantiate して `add_child` する。`set_overlay(other_overlay)` が外部から呼ばれた後はその Overlay を優先する。

#### Scenario: デフォルト Overlay が SimpleEncounterOverlay
- **WHEN** `EncounterCoordinator.new()` を `_ready` で起動し、`set_overlay` を呼ばないままエンカウンタを起こす
- **THEN** `SimpleEncounterOverlay` が動作し、`encounter_resolved` シグナル経由でフローが進む

#### Scenario: 外部 Overlay が優先される
- **WHEN** `set_overlay(combat_overlay)` を呼んだ後にエンカウンタを起こす
- **THEN** SimpleEncounterOverlay ではなく combat_overlay が `start_encounter` される
