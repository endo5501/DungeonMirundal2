## ADDED Requirements

### Requirement: Character emits hp_changed when HP fields mutate

The `Character` (RefCounted) SHALL define a signal `hp_changed(current_hp: int, max_hp: int)` and SHALL emit it whenever `current_hp` or `max_hp` is assigned to a value different from its previous value, except while signal suppression is active.

#### Scenario: hp_changed fires on current_hp change
- **WHEN** a Character with `current_hp = 20` is assigned `current_hp = 15`
- **THEN** the signal `hp_changed` SHALL fire exactly once with arguments `(15, max_hp)`

#### Scenario: hp_changed fires on max_hp change
- **WHEN** a Character with `max_hp = 30` is assigned `max_hp = 35`
- **THEN** the signal `hp_changed` SHALL fire exactly once with arguments `(current_hp, 35)`

#### Scenario: Equal-value assignment does not fire
- **WHEN** a Character with `current_hp = 20` is assigned `current_hp = 20`
- **THEN** the signal `hp_changed` SHALL NOT fire

### Requirement: Character emits mp_changed when MP fields mutate

The `Character` SHALL define a signal `mp_changed(current_mp: int, max_mp: int)` and SHALL emit it whenever `current_mp` or `max_mp` is assigned to a value different from its previous value, except while signal suppression is active.

#### Scenario: mp_changed fires on current_mp change
- **WHEN** a Character with `current_mp = 5` is assigned `current_mp = 3`
- **THEN** the signal `mp_changed` SHALL fire exactly once with arguments `(3, max_mp)`

#### Scenario: mp_changed fires on max_mp change
- **WHEN** a Character with `max_mp = 8` is assigned `max_mp = 10`
- **THEN** the signal `mp_changed` SHALL fire exactly once with arguments `(current_mp, 10)`

#### Scenario: Equal-value assignment does not fire
- **WHEN** a Character with `current_mp = 5` is assigned `current_mp = 5`
- **THEN** the signal `mp_changed` SHALL NOT fire

### Requirement: Character emits statuses_changed when persistent_statuses mutates

The `Character` SHALL define a signal `statuses_changed(persistent_statuses: Array[StringName])` and SHALL emit it whenever `persistent_statuses` is assigned to an array whose contents differ (by element-wise equality including order) from the previous array, except while signal suppression is active.

#### Scenario: statuses_changed fires on add
- **WHEN** a Character with `persistent_statuses = []` is assigned `persistent_statuses = [&"poison"]`
- **THEN** the signal `statuses_changed` SHALL fire exactly once with the new array `[&"poison"]`

#### Scenario: statuses_changed fires on removal
- **WHEN** a Character with `persistent_statuses = [&"poison"]` is assigned `persistent_statuses = []`
- **THEN** the signal `statuses_changed` SHALL fire exactly once with the new array `[]`

#### Scenario: Equal-content assignment does not fire
- **WHEN** a Character with `persistent_statuses = [&"poison"]` is assigned `persistent_statuses = [&"poison"]`
- **THEN** the signal `statuses_changed` SHALL NOT fire

### Requirement: Character supports signal suppression during load

The `Character` SHALL provide a private boolean `_suspend_signals` that, when `true`, suppresses emission of `hp_changed`, `mp_changed`, and `statuses_changed` for all field mutations. The flag SHALL default to `false`. `Character.from_dict` SHALL set the flag to `true` for the duration of all field assignments on the new instance, and SHALL restore the flag to `false` before returning the instance (and on every early-return path).

#### Scenario: from_dict does not emit signals
- **WHEN** `Character.from_dict(data)` is called with valid data containing non-zero current_hp / current_mp / persistent_statuses
- **THEN** no `hp_changed`, `mp_changed`, or `statuses_changed` signal SHALL fire during the call
- **AND** the returned Character SHALL have `_suspend_signals == false`

#### Scenario: Post-load mutations resume signal emission
- **WHEN** a Character is created via `from_dict`, then its `current_hp` is assigned a different value after the call returns
- **THEN** the signal `hp_changed` SHALL fire exactly once for that mutation

#### Scenario: from_dict early-return on invalid data restores the flag
- **WHEN** `Character.from_dict(data)` is called with data that causes it to return null (e.g., missing race resource), and a separate Character is then mutated normally
- **THEN** the unrelated Character's signal emission SHALL be unaffected (the flag is per-instance, not global, and there is no global state to leak)
