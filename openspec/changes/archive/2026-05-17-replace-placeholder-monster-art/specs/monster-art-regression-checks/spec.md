## ADDED Requirements

### Requirement: Dedicated replacement monster art is regression-checked
The system SHALL include automated regression coverage for the shipped replacement monster art files `dark_priest`, `goblin_shaman`, `imp`, `lich`, `witch`, and `wraith`.

The regression coverage SHALL verify all of the following:
- each file exists at `assets/images/monsters/<monster_id>.png`
- each file remains loadable through the existing `MonsterData.battle_texture` references
- each file is not byte-identical to `assets/images/monsters/slime.png`

#### Scenario: Replacement art files exist at stable paths
- **WHEN** repository validation inspects the six replacement monster ids
- **THEN** `assets/images/monsters/dark_priest.png`, `goblin_shaman.png`, `imp.png`, `lich.png`, `witch.png`, and `wraith.png` SHALL all exist

#### Scenario: Replacement art files are not slime duplicates
- **WHEN** repository validation compares each replacement monster art file to `assets/images/monsters/slime.png`
- **THEN** none of the six files SHALL have identical byte content to `slime.png`

#### Scenario: Replacement MonsterData resources still resolve textures
- **WHEN** `DataLoader.load_all_monsters()` loads the shipped monster set
- **THEN** the returned `MonsterData` for `dark_priest`, `goblin_shaman`, `imp`, `lich`, `witch`, and `wraith` SHALL each have a non-null `battle_texture`
