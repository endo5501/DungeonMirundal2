## MODIFIED Requirements

### Requirement: EncounterOverlay は抽象基底クラスである
SHALL: `EncounterOverlay` クラスは、自身が UI を構築する具象クラスではなく、エンカウンタ完了時の `encounter_resolved` シグナルおよび `start_encounter(monster_party)` の抽象 API のみを規定する基底クラスとして機能する。`_build_ui()` や `_ready()` の実装は持たず、サブクラスが提供する。`SimpleEncounterOverlay`(具象、単純表示)と `CombatOverlay`(戦闘 UI)が EncounterOverlay を継承する。

#### Scenario: EncounterOverlay は抽象として動作する
- **WHEN** `EncounterOverlay.new()` を直接インスタンス化して `start_encounter` を呼ぶ
- **THEN** `push_error("EncounterOverlay.start_encounter must be overridden")` が呼ばれる(または同等の警告)

#### Scenario: サブクラスが UI を提供する
- **WHEN** `SimpleEncounterOverlay` または `CombatOverlay` をインスタンス化して `_ready()` が呼ばれる
- **THEN** それぞれのサブクラスが UI を構築する(EncounterOverlay 自身は何もしない)

#### Scenario: encounter_resolved シグナルは基底で定義される
- **WHEN** `EncounterOverlay` のシグナル一覧を確認する
- **THEN** `encounter_resolved(outcome: EncounterOutcome)` が定義されており、サブクラスはこれを発行できる

## REMOVED Requirements

### Requirement: EncounterOverlay は自身で UI を構築する具象クラスとして機能する
**Reason**: EncounterOverlay は抽象基底化される。単純表示の責務は `SimpleEncounterOverlay` という独立クラスに移される。

**Migration**: 既存の `EncounterOverlay.new()` を直接 instantiate していた箇所(主に `EncounterCoordinator._ready` とテストコード)は `SimpleEncounterOverlay.new()` に置き換える。
