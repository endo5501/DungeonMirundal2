## ADDED Requirements

### Requirement: CombatLog renders status-related action entries

`CombatLog` SHALL render the following TurnReport action types as one line each, in the order they appear in the report. The text SHALL pull `status_display` from `StatusRepository.find(status_id).display_name` (falling back to `String(status_id)` when the lookup fails).

| Entry type | Rendered text template |
|---|---|
| `tick_damage` | `"{actor_name} は {status_display} で {amount} ダメージを受けた"` |
| `wake` | `"{actor_name} は目を覚ました"` (status-specific text allowed for future statuses) |
| `inflict` | `"{target_name} は {status_display} になった"` |
| `cure` | `"{actor_name} の {status_display} が治った"` |
| `resist` | `"{target_name} は {status_display} に抵抗した"` |
| `action_locked` | `"{actor_name} は行動できない"` (status_display optional in this change) |
| `cast_silenced` | `"{caster_name} は呪文を唱えようとしたが声が出ない"` |
| `stat_mod` | `"{target_name} の {stat_display} が {sign}{abs(delta)} 変化した"` |
| `miss` | `"{attacker_name} の攻撃は外れた"` (already specified in `add-stat-modifier-and-hit-evasion`) |

#### Scenario: tick_damage entry is rendered with status display name
- **WHEN** a TurnReport contains a `tick_damage` entry with `actor_name = "Alice"`, `status_id = &"poison"`, `amount = 2`
- **THEN** the CombatLog SHALL show one line containing "Alice", "毒" (or fallback), and "2 ダメージ"

#### Scenario: cast_silenced entry shows the caster name
- **WHEN** a TurnReport contains a `cast_silenced` entry with `caster_name = "Alice"`
- **THEN** the CombatLog SHALL show "Alice は呪文を唱えようとしたが声が出ない"

#### Scenario: action_locked entry is rendered without crashing if status is unknown
- **WHEN** a TurnReport contains an `action_locked` entry but no matching status data is available
- **THEN** the CombatLog SHALL still produce a non-empty line (showing at least the actor name and a generic "行動できない" phrase)

### Requirement: CombatCommandMenu disables Cast row when caster has silence

`CombatCommandMenu` SHALL, when building command rows for a `PartyCombatant` whose `has_silence_flag()` returns `true`, render the "呪文" row in a disabled state (visually distinct, e.g. greyed text). Pressing Enter on a disabled Cast row SHALL be a no-op (the menu does not advance to spell selection). Other rows (Attack / Defend / Item / Escape) SHALL remain enabled.

The actual silence-induced no-op at action resolution remains the engine's responsibility; the menu disable is a UI affordance.

#### Scenario: Silence disables Cast row
- **WHEN** the command menu is built for a Mage whose `has_silence_flag() == true`
- **THEN** the Cast row SHALL be flagged disabled and SHALL render with a "(沈黙中)" suffix or equivalent visual indicator

#### Scenario: Disabled Cast row does not advance the menu
- **WHEN** the user moves the cursor onto the disabled Cast row and presses Enter
- **THEN** the menu SHALL remain on the command selection step and the action SHALL NOT be queued

#### Scenario: Other commands remain available when silenced
- **WHEN** the silenced Mage's command menu is open
- **THEN** Attack / Defend / Item / Escape rows SHALL be selectable and behave as usual
