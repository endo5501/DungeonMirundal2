## Why

Six shipped spellcasting monsters currently reference distinct `battle_texture` paths but still use the same placeholder pixel content as `slime.png`. That leaves late-game and caster enemies visually indistinguishable in battle and makes placeholder regressions easy to miss.

## What Changes

- Replace the placeholder monster PNGs for `dark_priest`, `goblin_shaman`, `imp`, `lich`, `witch`, and `wraith` with dedicated generated transparent-background artwork.
- Keep the existing asset path convention and `.tres` wiring so runtime loading behavior does not change.
- Add regression coverage that verifies the six replacement assets exist and are no longer byte-identical to `slime.png`.
- Document a shared art-direction rule for these six images so they stay aligned with the existing shipped monster set.

## Capabilities

### New Capabilities
- `monster-art-regression-checks`: Verify shipped replacement monster textures exist at stable paths and are not placeholder duplicates of `slime.png`.

### Modified Capabilities
- `monster-data`: Tighten battle-art requirements for the six spellcasting monsters so shipped assets must be dedicated production images rather than placeholders or reused slime art.

## Impact

- Affected assets under `assets/images/monsters/`.
- Affected monster resource fixtures under `data/monsters/`.
- Affected test coverage in `tests/dungeon/` for shipped monster art validation.
- No API or save-data format changes.
