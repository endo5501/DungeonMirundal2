## ADDED Requirements

### Requirement: Morlis spell lowers a single enemy's defense

The system SHALL ship `data/spells/morlis.tres` (`SpellData`) with:
- `id = &"morlis"`, `display_name = "モーリス"`, `school = &"mage"`, `level = 2`, `mp_cost = 3`, `target_type = ENEMY_ONE`, `scope = BATTLE_ONLY`
- `effect`: `StatModSpellEffect` with `stat = &"defense"`, `delta = -2`, `turns = 4`

#### Scenario: morlis loads and applies a defense modifier
- **WHEN** morlis is cast on a slime with `modifier_stack.sum(&"defense") == 0`
- **THEN** after resolution `slime.modifier_stack.sum(&"defense") == -2` and the SpellResolution entry SHALL contain a `stat_mod` event for `(stat=&"defense", delta=-2, turns=4)`

### Requirement: Dilto spell lowers a single enemy's evasion

The system SHALL ship `data/spells/dilto.tres` (`SpellData`) with:
- `id = &"dilto"`, `display_name = "ディルト"`, `school = &"mage"`, `level = 2`, `mp_cost = 3`, `target_type = ENEMY_ONE`, `scope = BATTLE_ONLY`
- `effect`: `StatModSpellEffect` with `stat = &"evasion"`, `delta = -0.2`, `turns = 4`

#### Scenario: dilto loads and applies an evasion modifier
- **WHEN** dilto is cast on a target
- **THEN** the target's `modifier_stack.sum(&"evasion") == -0.2`

### Requirement: Sopic spell lowers an enemy group's hit rate

The system SHALL ship `data/spells/sopic.tres` (`SpellData`) with:
- `id = &"sopic"`, `display_name = "ソピック"`, `school = &"mage"`, `level = 2`, `mp_cost = 3`, `target_type = ENEMY_GROUP`, `scope = BATTLE_ONLY`
- `effect`: `StatModSpellEffect` with `stat = &"hit"`, `delta = -0.2`, `turns = 4`

#### Scenario: sopic applies hit modifier to every group member
- **WHEN** sopic is cast on a slime group with 3 living slimes
- **THEN** every slime's `modifier_stack.sum(&"hit") == -0.2` and the SpellResolution SHALL contain 3 entries each with a `stat_mod` event

### Requirement: Porfic spell raises a single ally's defense

The system SHALL ship `data/spells/porfic.tres` (`SpellData`) with:
- `id = &"porfic"`, `display_name = "ポーフィック"`, `school = &"priest"`, `level = 2`, `mp_cost = 3`, `target_type = ALLY_ONE`, `scope = OUTSIDE_OK`
- `effect`: `StatModSpellEffect` with `stat = &"defense"`, `delta = +2`, `turns = 4`

#### Scenario: porfic raises ally defense
- **WHEN** porfic is cast on an ally
- **THEN** the ally's `modifier_stack.sum(&"defense") == +2`

### Requirement: Bamatu spell raises a single ally's attack

The system SHALL ship `data/spells/bamatu.tres` (`SpellData`) with:
- `id = &"bamatu"`, `display_name = "バマツ"`, `school = &"priest"`, `level = 2`, `mp_cost = 3`, `target_type = ALLY_ONE`, `scope = OUTSIDE_OK`
- `effect`: `StatModSpellEffect` with `stat = &"attack"`, `delta = +2`, `turns = 4`

#### Scenario: bamatu raises ally attack
- **WHEN** bamatu is cast on an ally
- **THEN** the ally's `modifier_stack.sum(&"attack") == +2`

### Requirement: Varyu spell raises a single ally's hit rate

The system SHALL ship `data/spells/varyu.tres` (`SpellData`) with:
- `id = &"varyu"`, `display_name = "バルユ"`, `school = &"priest"`, `level = 2`, `mp_cost = 3`, `target_type = ALLY_ONE`, `scope = OUTSIDE_OK`
- `effect`: `StatModSpellEffect` with `stat = &"hit"`, `delta = +0.2`, `turns = 4`

#### Scenario: varyu raises ally hit rate
- **WHEN** varyu is cast on an ally
- **THEN** the ally's `modifier_stack.sum(&"hit") == +0.2`

### Requirement: Maporfic spell raises every living ally's defense

The system SHALL ship `data/spells/maporfic.tres` (`SpellData`) with:
- `id = &"maporfic"`, `display_name = "マポーフィック"`, `school = &"priest"`, `level = 3`, `mp_cost = 5`, `target_type = ALLY_ALL`, `scope = BATTLE_ONLY`
- `effect`: `StatModSpellEffect` with `stat = &"defense"`, `delta = +2`, `turns = 4`

#### Scenario: maporfic raises every living ally's defense
- **WHEN** maporfic is cast with 3 of 4 party members alive
- **THEN** the 3 living members SHALL each have `modifier_stack.sum(&"defense") == +2` and the SpellResolution SHALL contain 3 entries with `stat_mod` events
