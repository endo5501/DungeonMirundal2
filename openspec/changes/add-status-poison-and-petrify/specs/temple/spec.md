## ADDED Requirements

### Requirement: TempleScreen shows a hint about automatic status cure

`TempleScreen` SHALL render a one-line hint indicating that returning to town automatically cures all persistent statuses (poison, petrify, etc.). The exact phrasing SHALL be at minimum equivalent to "(街に戻ると状態異常は自動的に治ります)". The hint SHALL render in a less prominent style (smaller font, muted color) so as not to distract from the resurrection menu.

`TempleScreen` SHALL NOT provide any per-status cure action; the cure is handled by the town arrival path defined in `dungeon-return`.

#### Scenario: TempleScreen renders the auto-cure hint
- **WHEN** `TempleScreen` is rendered
- **THEN** a label SHALL exist whose text contains the substring "状態異常" or equivalent indicating auto-cure on town arrival

#### Scenario: TempleScreen does not offer per-status cure menu
- **WHEN** the user navigates `TempleScreen`
- **THEN** the only interactive action SHALL be revival (existing behavior); no cure-status entry SHALL be present
