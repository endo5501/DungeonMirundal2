## ADDED Requirements

### Requirement: CombatLog renders confusion_swap annotations on attack and miss actions

When a TurnReport entry of type `attack` or `miss` carries a truthy `confusion_swap` flag (added by the engine when a confused actor's command was retargeted), the `CombatLog` SHALL prepend or append a clarifying phrase such as "(混乱中)" so the player understands why the actor attacked an unexpected target.

#### Scenario: Confused attack on an ally is rendered with annotation
- **WHEN** a TurnReport contains an `attack` entry with `attacker_name = "Alice"`, `target_name = "Bob"`, `damage = 4`, and `confusion_swap == true`
- **THEN** the CombatLog SHALL show a single line that includes "Alice", "Bob", "4", and the substring "混乱" (e.g. "Alice (混乱中) は Bob に 4 ダメージを与えた")

#### Scenario: Confused miss is rendered with annotation
- **WHEN** a TurnReport contains a `miss` entry with `confusion_swap == true`
- **THEN** the CombatLog SHALL show a line that includes the attacker name, target name, "外れた", and the substring "混乱"

#### Scenario: Non-confused attack/miss entries render unchanged
- **WHEN** a TurnReport contains an `attack` or `miss` entry without `confusion_swap` (or with it set to `false`)
- **THEN** the line SHALL render in the standard pre-existing format with no confusion annotation
