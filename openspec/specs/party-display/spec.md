## Purpose
画面端に常時表示されるパーティ一覧のミニ UI を規定する。各キャラクターの名前・HP・MP・状態異常アイコンのコンパクト表示を対象とする。

## Requirements

### Requirement: PartyMemberData holds character display information
PartyMemberData (RefCounted) SHALL hold the display data for a single party member: name (String), level (int), current_hp (int), max_hp (int), current_mp (int), max_mp (int).

#### Scenario: Create party member with all fields
- **WHEN** PartyMemberData is created with name "Warrior", level 5, current_hp 120, max_hp 150, current_mp 30, max_mp 45
- **THEN** name SHALL be "Warrior", level SHALL be 5, current_hp SHALL be 120, max_hp SHALL be 150, current_mp SHALL be 30, max_mp SHALL be 45

### Requirement: PartyData holds a party of up to 6 members in two rows
PartyData (RefCounted) SHALL manage a party with a front row (up to 3 members) and a back row (up to 3 members).

#### Scenario: Create party with front and back rows
- **WHEN** PartyData is created with front_row of 3 members and back_row of 3 members
- **THEN** get_front_row() SHALL return the 3 front row members AND get_back_row() SHALL return the 3 back row members

#### Scenario: Empty slots are null
- **WHEN** PartyData is created with front_row of 2 members and back_row of 1 member
- **THEN** get_front_row() SHALL return an array of size 3 where index 2 is null AND get_back_row() SHALL return an array of size 3 where indices 1 and 2 are null

### Requirement: PartyData provides default placeholder data
PartyData SHALL provide a static method create_placeholder() that returns a PartyData instance with 6 pre-defined placeholder members for testing purposes.

#### Scenario: Placeholder data has 6 members
- **WHEN** PartyData.create_placeholder() is called
- **THEN** the returned PartyData SHALL have 3 front row members and 3 back row members, all with non-empty names and positive max_hp and max_mp values

### Requirement: PartyMemberPanel auto-refreshes from a bound Character

The `PartyMemberPanel` SHALL accept a `Character` as its display source and SHALL connect to the Character's `hp_changed`, `mp_changed`, and `statuses_changed` signals so that the panel re-renders automatically when those signals fire. When the panel's display source is reassigned to a different Character (or to null), it SHALL disconnect from the previous Character's signals before connecting to the new one.

#### Scenario: HP change on bound Character refreshes the panel
- **WHEN** a PartyMemberPanel has been bound to a Character with `current_hp = 20`, and that Character's `current_hp` is then assigned `15`
- **THEN** the panel SHALL re-render its HP display so that subsequent reads of the displayed current HP value reflect `15`

#### Scenario: MP change on bound Character refreshes the panel
- **WHEN** a PartyMemberPanel has been bound to a Character with `current_mp = 5`, and that Character's `current_mp` is then assigned `3`
- **THEN** the panel SHALL re-render its MP display so that subsequent reads of the displayed current MP value reflect `3`

#### Scenario: Switching Characters disconnects old signals
- **WHEN** a PartyMemberPanel is bound to Character A, then re-bound to Character B, and afterward Character A's `current_hp` is assigned a new value
- **THEN** the panel SHALL NOT re-render in response to A's change

#### Scenario: Unbinding a Character disconnects signals
- **WHEN** a PartyMemberPanel is bound to a Character, then unbound (set to null), and afterward the Character's `current_hp` is assigned a new value
- **THEN** the panel SHALL NOT re-render in response to that change

### Requirement: PartyDisplay supports binding party members from Character objects

The `PartyDisplay` SHALL provide an interface to bind front-row and back-row members directly from `Character` objects (in addition to the existing `setup(party_data: PartyData)` snapshot interface). When bound from Character objects, each constituent `PartyMemberPanel` SHALL receive the Character and connect to its signals as defined above.

#### Scenario: Binding from Characters wires signal-driven refresh
- **WHEN** `PartyDisplay` is bound with three front-row Characters and three back-row Characters, and one of them later has its `current_hp` mutated
- **THEN** the corresponding `PartyMemberPanel` SHALL refresh, while the other panels SHALL NOT refresh

#### Scenario: Empty slots are handled
- **WHEN** `PartyDisplay` is bound from rows that contain `null` for some slots
- **THEN** those slots SHALL render as empty (matching existing PartyMemberData null handling) and SHALL NOT attempt signal connections

### Requirement: DungeonScreen binds PartyDisplay to live Characters when entering the dungeon

`DungeonScreen` SHALL bind its `PartyDisplay` to the live `Character` instances of the active party (rather than to a `PartyMemberData` snapshot) when the dungeon scene becomes active, so that subsequent state mutations on those Characters from any source (combat, ESC menu spell casting, item use, status-effect changes) automatically refresh the status bar.

#### Scenario: ESC menu heal updates the status bar
- **WHEN** a Character in the active party has been damaged to `current_hp = 5` (with `max_hp = 20`), the dungeon screen is open, and an ESC-menu heal spell raises that Character's `current_hp` to `15`
- **THEN** the corresponding `PartyMemberPanel` SHALL re-render to reflect `15 / 20` without any explicit caller-side refresh
