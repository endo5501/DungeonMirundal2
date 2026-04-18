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
