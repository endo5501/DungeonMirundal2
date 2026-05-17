## 1. Regression Coverage

- [x] 1.1 Add automated tests or test helpers that assert the six replacement monster art files exist at the stable `assets/images/monsters/<monster_id>.png` paths.
- [x] 1.2 Add automated checks that fail when `dark_priest`, `goblin_shaman`, `imp`, `lich`, `witch`, or `wraith` are byte-identical to `slime.png`.
- [x] 1.3 Confirm the new regression coverage fails against the current placeholder asset state before changing any monster art files.

## 2. Replace Placeholder Art

- [x] 2.1 Generate dedicated transparent-background PNG artwork for `dark_priest`, `goblin_shaman`, `imp`, `lich`, `witch`, and `wraith` using a shared art-direction prompt aligned with the existing shipped monster style.
- [x] 2.2 Replace the placeholder PNG payloads in `assets/images/monsters/` while keeping the existing filenames and `.tres` references unchanged.
- [x] 2.3 Verify each target `MonsterData` resource still resolves a non-null `battle_texture` after the asset replacement.

## 3. Final Validation

- [x] 3.1 Run the relevant monster-data and asset regression tests to confirm the six replacements pass and no slime-duplicate files remain.
- [x] 3.2 Review the generated batch for consistency with existing battle art readability, transparent backgrounds, and one-monster-per-image composition.
