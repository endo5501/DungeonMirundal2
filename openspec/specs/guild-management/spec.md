## Purpose
ギルドによるキャラクター登録・待機・パーティ編成のデータモデルを規定する。登録・解雇・パーティスロット割り当て、複数パーティ管理の制約を対象とする。

## Requirements

### Requirement: Guild registers characters
Guild SHALL allow registering newly created Characters and maintain a list of all registered characters.

#### Scenario: Register a character
- **WHEN** a Character is registered with the Guild
- **THEN** the character SHALL appear in the Guild's character list

#### Scenario: Register multiple characters
- **WHEN** 3 characters are registered
- **THEN** the Guild's character list SHALL contain exactly 3 characters

### Requirement: Guild removes characters
Guild SHALL allow removing characters that are not currently assigned to the party.

#### Scenario: Remove an unassigned character
- **WHEN** an unassigned Character is removed from the Guild
- **THEN** the character SHALL no longer appear in the Guild's character list

#### Scenario: Cannot remove a party-assigned character
- **WHEN** a Character currently assigned to the party is attempted to be removed
- **THEN** the removal SHALL fail or be rejected and the character SHALL remain in the Guild

### Requirement: Guild lists unassigned characters
Guild SHALL provide a method to list characters that are not currently assigned to any party slot.

#### Scenario: All characters unassigned
- **WHEN** 3 characters are registered and none are in the party
- **THEN** get_unassigned() SHALL return all 3 characters

#### Scenario: Some characters assigned
- **WHEN** 3 characters are registered and 1 is assigned to the party
- **THEN** get_unassigned() SHALL return 2 characters

### Requirement: Guild assigns characters to party slots
Guild SHALL allow assigning a registered Character to a specific party slot (row and position).

#### Scenario: Assign to front row
- **WHEN** a Character is assigned to front row position 0
- **THEN** the party's front row position 0 SHALL contain that character

#### Scenario: Assign to back row
- **WHEN** a Character is assigned to back row position 2
- **THEN** the party's back row position 2 SHALL contain that character

#### Scenario: Cannot assign to occupied slot
- **WHEN** a Character is assigned to a slot already occupied by another character
- **THEN** the assignment SHALL fail or be rejected

#### Scenario: Cannot assign character already in party
- **WHEN** a Character already in the party is assigned to another slot
- **THEN** the assignment SHALL fail or be rejected

### Requirement: Guild removes characters from party slots
Guild SHALL allow removing a character from a party slot, returning them to unassigned status.

#### Scenario: Remove from party slot
- **WHEN** a Character is removed from front row position 1
- **THEN** that slot SHALL be empty (null) and the character SHALL appear in unassigned list

#### Scenario: Remove from empty slot
- **WHEN** removal is attempted on an empty party slot
- **THEN** the operation SHALL have no effect (no error)

### Requirement: Guild produces PartyData for dungeon use
Guild SHALL provide a method to generate a PartyData instance reflecting the current party composition, with each Character converted to PartyMemberData.

#### Scenario: Full party
- **WHEN** get_party_data() is called with 6 characters assigned (3 front, 3 back)
- **THEN** the returned PartyData SHALL have all 6 slots filled with corresponding PartyMemberData

#### Scenario: Partial party
- **WHEN** get_party_data() is called with only 2 characters assigned (front 0 and back 1)
- **THEN** the returned PartyData SHALL have those 2 slots filled and 4 slots as null

#### Scenario: Empty party
- **WHEN** get_party_data() is called with no characters assigned
- **THEN** the returned PartyData SHALL have all 6 slots as null
