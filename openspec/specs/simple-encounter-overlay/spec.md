# simple-encounter-overlay Specification

## Purpose
TBD - created by archiving change cleanup-main-and-encounter-wiring. Update Purpose after archive.
## Requirements
### Requirement: SimpleEncounterOverlay は単純な遭遇 UI を提供する具象 EncounterOverlay
SHALL: `SimpleEncounterOverlay extends EncounterOverlay` クラスを `src/dungeon_scene/simple_encounter_overlay.gd` に定義する。本 Control は `start_encounter(monster_party)` 呼び出し時に、モンスター名を表示するシンプルな UI を構築し、`ui_accept` 入力で `encounter_resolved` シグナルを発行する。本 Overlay はテストおよび戦闘 UI 不要のシナリオで使用される。

#### Scenario: モンスター名を表示する
- **WHEN** `SimpleEncounterOverlay.start_encounter(monster_party)` が呼ばれる
- **THEN** モンスター名(またはパーティ名の集計)を表示する Label を含む UI が visible になる

#### Scenario: ui_accept で encounter_resolved を発行
- **WHEN** SimpleEncounterOverlay が visible で `ui_accept` がディスパッチされる
- **THEN** `encounter_resolved(outcome)` シグナルが発行され、visible = false になる

#### Scenario: EncounterCoordinator のデフォルト Overlay として使われる
- **WHEN** `EncounterCoordinator._ready` が overlay を未設定で呼ばれる
- **THEN** デフォルトで `SimpleEncounterOverlay.new()` が instantiate され add_child される

