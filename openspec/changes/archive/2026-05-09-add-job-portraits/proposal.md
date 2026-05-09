## Why

The party HUD currently reserves a large portrait area but renders only a generic placeholder, which makes party members harder to read at a glance and leaves the portrait-forward layout underused. Adding default job portraits gives each character a clear visual identity without introducing race-specific or character-specific portrait selection yet.

## What Changes

- Add one generated dark-fantasy portrait asset for each existing job: Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, and Ninja.
- Display a party member's default portrait in `PartyMemberPanel` based on the character's job id.
- Carry the job id through the existing `PartyMemberData` snapshot path so live character binding and snapshot setup render portraits consistently.
- Preserve the current placeholder portrait rendering as a fallback for empty slots, missing job ids, unknown jobs, or missing image assets.
- Do not add race-specific portrait variants in this change.
- Do not add custom per-character portrait selection in this change.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `party-display`: Party HUD member panels render default job portraits and include the job id in display data used by snapshot and live binding paths.

## Impact

- Affected code: `src/dungeon/party_member_data.gd`, `src/dungeon/character.gd`, `src/dungeon_scene/party_member_panel.gd`, and related party display tests.
- Affected assets: new generated images under `assets/images/portraits/jobs/`.
- Affected specs: `openspec/specs/party-display/spec.md`.
- No save-data format change: persisted characters already store job identity through existing character serialization.
- No new runtime dependency: portraits are static project assets loaded through Godot resource paths.
