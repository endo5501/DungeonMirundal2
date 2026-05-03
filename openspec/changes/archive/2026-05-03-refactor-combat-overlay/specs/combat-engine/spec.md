## ADDED Requirements

### Requirement: TurnEngine records target retargeting in TurnReport
SHALL: When `TurnEngine._resolve_attack` retargets an attack from a dead target to a living one (via `_pick_living_same_side_as`), the resulting `ReportAction` SHALL record the original (now-dead) target's name in a new `retargeted_from: String` field. When no retargeting occurs, `retargeted_from` SHALL be the empty string.

#### Scenario: Attack on dead target retargets and records
- **WHEN** Player attacks Slime A; Slime A dies before player's turn; TurnEngine resolves and retargets to Slime B
- **THEN** the corresponding `ReportAction` SHALL have `target_name = "Slime B"` and `retargeted_from = "Slime A"`

#### Scenario: Attack on living target does not record retargeting
- **WHEN** Player attacks Slime A and Slime A is alive at resolution time
- **THEN** the corresponding `ReportAction` SHALL have `target_name = "Slime A"` and `retargeted_from = ""`

#### Scenario: CombatLog displays retargeting message
- **WHEN** `combat_log.append_from_report_action(action)` is called with `action.retargeted_from = "Slime A"` and `action.target_name = "Slime B"`
- **THEN** the appended log line SHALL contain both names with text indicating that "Slime A" was already dead and the attack landed on "Slime B"
