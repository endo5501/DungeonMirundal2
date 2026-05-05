## ADDED Requirements

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
