## ADDED Requirements

### Requirement: Returning to town auto-cures all persistent statuses

When the party returns to town (via the START-tile dialog confirmation, the escape-to-town consumable, or any other return path), the system SHALL clear `persistent_statuses` for every Character in the party guild. The cure SHALL apply to every status currently held, regardless of how the status was inflicted.

If at least one character had at least one persistent status removed, the system SHALL emit a single notification (toast / log line) such as "教会の祈りで状態異常が癒えた" via the town screen. If no character had any persistent statuses, no notification SHALL be shown.

This auto-cure SHALL be the only way to remove `petrify` and `poison` outside of the spell/item paths defined in `spell-data` and `consumable-items`. The temple screen does not provide a separate cure menu.

#### Scenario: Town arrival clears poison from all afflicted members
- **WHEN** the party returns to town with two members holding `&"poison"`
- **THEN** both members' `Character.persistent_statuses` SHALL be `[]` and a single notification SHALL be displayed

#### Scenario: Town arrival with no afflictions shows no notification
- **WHEN** the party returns to town with all members having empty `persistent_statuses`
- **THEN** no notification SHALL be shown and no behavior SHALL change

#### Scenario: Auto-cure works even when triggered by escape-to-town item
- **WHEN** an emergency-escape consumable returns the party to town with a poisoned member
- **THEN** the same auto-cure rule SHALL apply
