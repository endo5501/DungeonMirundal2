## 1. Baseline confirmation

- [x] 1.1 `godot --headless -s addons/gut/gut_cmdln.gd 2>&1 > /tmp/before.log` を実行し、parse error 3件と `Ignoring script ... because it does not extend GutTest` 警告 3件、`1462 passing` を baseline として確認する。**(確認済: 1462 Passing, Asserts 7647, Orphans 86, parse error 3件)**
- [x] 1.2 修正対象 3 ファイル (`tests/combat/test_spell_effects.gd`, `tests/esc_menu/flows/test_spell_use_flow.gd`, `tests/combat/test_item_command_resolution.gd`) のテスト関数数を控えておく（修正後の合計テスト数増加の検証用）。**(test_spell_effects=9, test_spell_use_flow=9, test_item_command_resolution=8 → 計 26)**

## 2. SpellRng クラスを TDD で導入

- [x] 2.1 `tests/combat/test_spell_rng.gd` を新規作成 (プロジェクト規約に合わせ flat 構造) し、以下の振る舞いを assert するテストを書く（**実装より先**にテストだけ作成して赤を確認）:
  - [x] 2.1.1 `SpellRng.new(rng)` が与えた `RandomNumberGenerator` を内部に保持し、`roll(low, high)` が `rng.randi_range(low, high)` の戻り値と一致する。
  - [x] 2.1.2 `SpellRng.new(null)` (もしくは引数省略) が内部で `RandomNumberGenerator.new()` を作り `randomize()` した上で動作する。
  - [x] 2.1.3 同じ seed の RNG を複数の `SpellRng` でラップして同じ範囲を `roll` すると、同じ値列を返す（決定性検証）。
  - [x] 2.1.4 `class _StubRng extends SpellRng: func roll(_a, _b): return 7` というテストローカル sub-class を定義し、parse error が発生せず、`roll(0, 100) == 7` が返ることを確認する（native method override 警告が**出ないこと**の構造的検証）。
- [x] 2.2 pre-flight (scripts/check_scripts.gd) で `test_spell_rng.gd` が PARSE_FAIL リストに加わることで赤を確認 (SpellRng 未実装のため)。
- [x] 2.3 `src/combat/spells/spell_rng.gd` を新規作成:
  - [x] 2.3.1 `class_name SpellRng extends RefCounted`
  - [x] 2.3.2 `var _rng: RandomNumberGenerator`
  - [x] 2.3.3 `func _init(rng: RandomNumberGenerator = null) -> void`：null なら新規 `RandomNumberGenerator` を作って `randomize()` する。
  - [x] 2.3.4 `func roll(low: int, high: int) -> int`：`_rng.randi_range(low, high)` を返す。
- [x] 2.4 全テスト再実行 (1462 → 1469 = +7 SpellRng tests, 全緑)。

## 3. SpellEffect 系のシグネチャ移行

- [x] 3.1 `src/combat/spells/spell_effect.gd` の `apply` シグネチャを `(_caster, _targets, _spell_rng: SpellRng) -> SpellResolution` に変更（base クラスはデフォルト動作のみ）。
- [x] 3.2 `src/combat/spells/damage_spell_effect.gd`:
  - [x] 3.2.1 `apply` シグネチャを `SpellRng` 受け取りに変更。
  - [x] 3.2.2 内部の `roll = rng.randi_range(-spread, spread)` を `roll = spell_rng.roll(-spread, spread)` に変更。
  - [x] 3.2.3 `if rng != null and spread != 0` ガードを `if spell_rng != null and spread != 0` に追従。
- [x] 3.3 `src/combat/spells/heal_spell_effect.gd`：3.2 と同様に修正。
- [x] 3.4 `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_spell_effects.gd` を実行 → parse error は別の理由（テスト側がまだ更新されていない）で残るが、本体側の compile error がないことを確認する。

## 4. 呼び出し側のラップ追加

- [x] 4.1 `src/combat/turn_engine.gd:_resolve_cast` の `spell.effect.apply(caster, targets, rng)` を `spell.effect.apply(caster, targets, SpellRng.new(rng))` に変更。
- [x] 4.2 `src/esc_menu/flows/spell_use_flow.gd`:
  - [x] 4.2.1 `var _rng: RandomNumberGenerator = null` を `var _spell_rng: SpellRng = null` に変更（フィールド名を rename）。
  - [x] 4.2.2 `_get_rng() -> RandomNumberGenerator` を `_get_spell_rng() -> SpellRng` に変更。null なら `SpellRng.new(null)` を作って保持する。
  - [x] 4.2.3 `set_rng(rng: RandomNumberGenerator)` を `set_rng(spell_rng: SpellRng)` に変更。
  - [x] 4.2.4 `_apply_cast_and_show_result` 内の `_spell.effect.apply(caster_pc, targets, _get_rng())` を `_spell.effect.apply(caster_pc, targets, _get_spell_rng())` に変更。
- [x] 4.3 grep で `RandomNumberGenerator` を spell 経路で残っている箇所がないか確認:
  - [x] 4.3.1 `grep -rn "RandomNumberGenerator" src/combat/spells/ src/esc_menu/flows/` で予期しないヒットがないこと（base RNG を保持する `SpellRng._rng` の宣言と `_init` の引数のみが残ってよい）。
  - [x] 4.3.2 `src/combat/turn_engine.gd:_resolve_cast` 内では `rng: RandomNumberGenerator` が引数のまま（`turn_engine` 全体は本 change のスコープ外）であることを確認する。

## 5. テスト側の修正

- [x] 5.1 `tests/combat/test_spell_effects.gd`:
  - [x] 5.1.1 `class _FixedRng extends RandomNumberGenerator` を `class _FixedRng extends SpellRng` に変更。
  - [x] 5.1.2 `func randi_range(_from, _to) -> int` を `func roll(_low, _high) -> int` に変更。
  - [x] 5.1.3 `_init` 内で `super._init(null)` を呼び SpellRng 親の初期化を済ませる。
  - [x] 5.1.4 `_make_rng()` ヘルパが `RandomNumberGenerator.new()` を返している箇所は、effect.apply に渡す前に `SpellRng.new(rng)` でラップするか、`_make_rng()` 自体が `SpellRng` を返すように rename する。コードの読みやすさを優先して後者を採用し、関数名を `_make_spell_rng()` 等に変更する。
  - [x] 5.1.5 全 `effect.apply(... , rng_or_make_rng)` 呼び出しで第3引数が `SpellRng` になっていることを目視確認。
- [x] 5.2 `tests/esc_menu/flows/test_spell_use_flow.gd`:
  - [x] 5.2.1 `class _FixedRng extends RandomNumberGenerator` を `class _FixedRng extends SpellRng` に変更（5.1 と同じパターン）。
  - [x] 5.2.2 `randi_range` override を `roll` override に変更。
  - [x] 5.2.3 `flow.set_rng(_FixedRng.new(rng_value))` の呼び出しはシグネチャが `SpellRng` になったので修正不要だが、確認する。
- [x] 5.3 `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_spell_effects.gd,test_spell_use_flow.gd` で 2 ファイルが parse 通過し、全テスト緑になることを確認する。
- [x] 5.4 `grep -rn "extends RandomNumberGenerator" tests/` の結果が **空** であることを確認する（native method override が完全に追放されたことの検証）。

## 6. CombatCommandMenu の API 回復

- [x] 6.1 `src/dungeon_scene/combat/combat_command_menu.gd`:
  - [x] 6.1.1 `const _LABELS: Dictionary = { ... }` を `const OPTION_LABELS: Dictionary = { ... }` に rename（中身は不変）。
  - [x] 6.1.2 `_LABELS` への参照を `OPTION_LABELS` に置換 (`get_options()` 内、`_rebuild_rows()` 内など)。
  - [x] 6.1.3 `static func base_option_ids() -> Array[int]` を新設し、`[OPT_ATTACK, OPT_DEFEND, OPT_ITEM, OPT_ESCAPE]` を返す。
  - [x] 6.1.4 `_build_option_ids_for(actor)` が魔法職以外で `base_option_ids()` を returns するか、または明示的に `base_option_ids()` のコピーから始めるよう内部リファクタする（DRY）。
- [x] 6.2 `tests/combat/test_item_command_resolution.gd`:
  - [x] 6.2.1 `test_command_menu_options_include_item` を `var ids := CombatCommandMenu.base_option_ids(); assert_eq(ids.size(), 4); assert_true(CombatCommandMenu.OPT_ITEM in ids)` のように書き直す（`menu.new()` セットアップを廃し、static contract を直接検証）。
  - [x] 6.2.2 `test_command_menu_item_is_at_opt_item_index` の `CombatCommandMenu.OPTIONS[CombatCommandMenu.OPT_ITEM]` を `CombatCommandMenu.OPTION_LABELS[CombatCommandMenu.OPT_ITEM]` に変更。
- [x] 6.3 `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_item_command_resolution.gd` でファイルが parse 通過し、全テスト緑になることを確認する。

## 7. 全体回帰確認

- [x] 7.1 `scripts/run_tests.ps1` (Windows) または `scripts/run_tests.sh` (Linux/WSL) を実行し、exit code が `0` で終わることを確認する。
- [x] 7.2 ラッパが `[OK] All checks passed: pre-flight clean, GUT green, no silent failures.` を出力していることを確認する（pre-flight も post-scan も発火していないこと）。
- [x] 7.3 GUT 末尾の `Passing Tests` 行を確認し、baseline (1462) からテスト数が **増えている** ことを確認する（修正対象3ファイルが集計に入った分。最低でも `test_spell_effects.gd` の元テスト数 + `test_spell_use_flow.gd` の元テスト数 + `test_item_command_resolution.gd` の元テスト数 + 新規 `test_spell_rng.gd` のテスト数だけ増えるはず）。
- [x] 7.4 `Failures: 0` であることを確認する。
- [x] 7.5 終了時のリーク警告 (`RIDs leaked`, `resources still in use`) 等は別件として残存して構わない（本 change のスコープ外）。

## 8. OpenSpec validation

- [x] 8.1 `openspec validate fix-magic-system-test-regressions --strict` が `valid` を返すことを確認する。
- [x] 8.2 全 task のチェックがついた状態で `tasks.md` を最終確認する。

## 9. コミット粒度

- [x] 9.1 以下の単位でコミットを分けることを推奨（不要なら統合可）:
  - Commit 1: SpellRng クラス導入 (Sec.2 の Add `src/combat/spells/spell_rng.gd` + tests)
  - Commit 2: SpellEffect 系の SpellRng 移行と呼び出し側のラップ (Sec.3, Sec.4, Sec.5)
  - Commit 3: CombatCommandMenu 公開 API 回復とテスト追従 (Sec.6)
- [x] 9.2 各コミットメッセージは英語で、CLAUDE.md の規約に従う。
