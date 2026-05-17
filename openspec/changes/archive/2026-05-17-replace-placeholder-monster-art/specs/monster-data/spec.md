## MODIFIED Requirements

### Requirement: New monsters reference battle texture assets at the conventional path
The system SHALL ship a battle-texture asset for each new monster at `assets/images/monsters/<monster_id>.png` and SHALL wire each new `.tres`'s `battle_texture` to that asset.

For the shipped monster ids `witch`, `dark_priest`, `imp`, `lich`, `goblin_shaman`, and `wraith`, the committed image SHALL be dedicated production art for that monster and SHALL NOT reuse the exact file content of `slime.png` or another placeholder duplicate. Each image SHALL remain a transparent-background PNG containing a single readable monster subject that fits the existing combat panel presentation.

#### Scenario: Each new monster has a battle texture file
- **WHEN** the `assets/images/monsters/` directory is inspected
- **THEN** the files `witch.png`, `dark_priest.png`, `imp.png`, `lich.png`, `goblin_shaman.png`, and `wraith.png` SHALL exist

#### Scenario: Each new MonsterData references its battle texture
- **WHEN** `MonsterRepository.find(<new_id>)` is called for any of the six new ids
- **THEN** the returned `MonsterData.battle_texture` SHALL NOT be `null`

#### Scenario: Spellcasting monster art is not shipped as slime placeholder content
- **WHEN** the shipped art files for `witch`, `dark_priest`, `imp`, `lich`, `goblin_shaman`, and `wraith` are compared with `assets/images/monsters/slime.png`
- **THEN** none of those six files SHALL be byte-identical to `slime.png`
