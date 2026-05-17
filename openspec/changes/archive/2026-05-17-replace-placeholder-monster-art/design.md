## Context

The project already loads monster battle textures through `MonsterData.battle_texture` and resolves them from stable asset paths under `assets/images/monsters/`. For the six spellcasting monsters added in the monster-magic change, the resource wiring is correct, but the PNG payloads are still identical to `slime.png`. Runtime code therefore cannot distinguish placeholder reuse from dedicated art, and current tests only verify file existence and non-null texture references.

This change is intentionally asset-first. It should preserve the existing runtime loading path, avoid format or schema churn, and add enough automated verification to prevent placeholder art from silently shipping again.

## Goals / Non-Goals

**Goals:**
- Replace the six placeholder PNGs with dedicated transparent-background monster artwork.
- Keep `data/monsters/*.tres` references and the `assets/images/monsters/<monster_id>.png` convention unchanged.
- Define a shared art-direction contract so the six replacement images stay visually coherent with the existing shipped monster set.
- Add automated regression checks that fail if any of the six assets are missing or byte-identical to `slime.png`.

**Non-Goals:**
- Changing how battle textures are loaded or rendered at runtime.
- Introducing a runtime image comparison system or metadata field for art provenance.
- Reworking existing non-target monster art such as `slime`, `goblin`, `bat`, `skeleton`, `ghost`, or `dragon`.
- Building a general-purpose asset pipeline beyond the checks needed for these six shipped files.

## Decisions

### Keep path and resource wiring stable

The change will replace image file contents in place instead of renaming files or adding new `MonsterData` fields. This minimizes implementation risk because `MonsterData.battle_texture`, `DataLoader`, and `CombatMonsterPanel` already consume the existing path convention successfully.

Alternative considered:
- Add explicit art metadata or version fields to `MonsterData`.
  Rejected because the issue is asset payload quality, not missing runtime metadata.

### Treat visual direction as a testable contract

The six target monsters will share a single art-direction rule: transparent background, single monster subject, readability inside the existing combat visual slots, and fidelity aligned with the current shipped monster set rather than a new rendering style. The spec will encode the structural requirements, while the design captures the qualitative style constraints that are hard to express as executable tests.

Alternative considered:
- Let each generated image evolve independently.
  Rejected because it increases the chance of mixed style and weakens batch review.

### Detect placeholder regressions with deterministic duplicate checks

Regression coverage will compare the six target files against `slime.png` using deterministic file-content checks rather than visual heuristics. Byte-level identity is sufficient for the currently observed failure mode and is cheap to run in tests. The checks should live in the test suite or a narrowly scoped helper so they run with normal repository validation.

Alternative considered:
- Perceptual image similarity checks.
  Rejected because they are more complex, noisier, and unnecessary for catching exact placeholder reuse.

## Risks / Trade-offs

- [Generated art still feels slightly off-model next to existing monsters] → Mitigation: constrain prompts to the current art direction and review the batch together before finalizing.
- [Byte-identity checks only catch exact duplicates, not near-duplicates] → Mitigation: acceptable for this change because the known regression is exact slime reuse; broader art review remains a human step.
- [Asset replacement without code changes can look “done” while tests remain too weak] → Mitigation: strengthen specs and tests in the same change so the regression becomes enforceable.
- [Future contributors may not know why these six are special-cased] → Mitigation: encode the target set and rationale in the OpenSpec delta and regression-check capability.
