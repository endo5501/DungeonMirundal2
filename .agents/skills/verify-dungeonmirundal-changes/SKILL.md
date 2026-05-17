---
name: verify-dungeonmirundal-changes
description: Repository-specific validation workflow for DungeonMirundal2. Use when changing code, data, assets, tests, specs, or skills in this repo and you need to choose the right verification scope, run the Godot/GUT test wrapper safely, execute focused tests without accidentally loading the whole suite, or recover from Windows-specific Godot/GUT execution problems in this environment.
---

# Verify DungeonMirundal Changes

Use this skill to choose and run the correct validation path for this repository.

## Workflow

1. Classify the change before running commands.
   - For runtime code, data, or battle assets, run automated checks.
   - For narrow changes, start with the smallest meaningful test target.
   - For broad or risky changes, widen to the related suite or full wrapper run after the focused check.
   - For pure spec/archive/documentation changes, prefer structural validation and git diff review; do not invent engine tests that do not exercise the change.

2. Prefer the repo wrapper first.
   - On Windows, default to `.\scripts\run_tests.ps1`.
   - Use the wrapper whenever possible because it adds two repo-specific safety nets:
     - pre-flight parse checking via `scripts/check_scripts.gd`
     - post-scan failure detection for silently skipped GUT tests
   - Treat the wrapper as the default path for full or related-suite validation.

3. Switch to the focused-command path when you need precise targeting.
   - If you need one file or one test name, read [references/commands.md](references/commands.md).
   - In this repo, direct GUT runs must bypass `.gutconfig.json` with `-gconfig=` or GUT may discover far more tests than intended.
   - In this Windows environment, use the monitored `Start-Process` pattern from the reference when direct invocation hangs or hides stderr.

4. Triage failures in this order.
   - Parse/load failure: run or inspect the pre-flight parse check first.
   - Unexpectedly large test run: confirm you used `-gconfig=` on direct GUT commands.
   - Hung Godot/GUT process: use the monitored process recipe and clean up stray `Godot*` processes.
   - Passing test that should fail: narrow to the exact test file or test name and verify the failure reason before implementing.

5. Finish with evidence, not assumptions.
   - Report the exact command path used.
   - Report whether validation was wrapper-based or direct-GUT fallback.
   - If you could only run focused checks, say that explicitly and note what broader validation remains.

## Validation Matrix

- Small GDScript/data fix:
  - Run the narrowest affected test first.
  - After it passes, run the nearest related suite through `.\scripts\run_tests.ps1`.

- Asset replacement that changes loaded runtime resources:
  - Add or update a regression test first.
  - Verify the new test fails before the asset change.
  - After replacement, run the focused regression tests again.

- Broad combat/dungeon behavior change:
  - Start with the directly affected test file.
  - Then run the related dungeon/combat suite through the wrapper.

- Skill/spec-only change:
  - Validate the skill/spec artifact directly.
  - Run engine tests only if the change also touched runtime code, data, or assets.

## Repo Rules

- Do not replace the wrapper with generic Godot advice from elsewhere.
- Do not use direct GUT commands without understanding the `.gutconfig.json` side effects in this repo.
- Do not claim a verification result unless you captured actual output or an exit condition.
- Do not widen the test scope by accident when a focused repro is required.

## References

- Read [references/commands.md](references/commands.md) for concrete Windows commands, focused-test recipes, and the monitored `Start-Process` fallback.
