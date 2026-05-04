## Why

Magic system v1 のマージ後、3つのテストファイル (`test_spell_use_flow.gd`, `test_spell_effects.gd`, `test_item_command_resolution.gd`) が parse error によって GUT に「`Ignoring script ... because it does not extend GutTest`」として silently 除外されている。`godot --headless -s addons/gut/gut_cmdln.gd` は `All tests passed!` を出すものの、それは parse 可能だった 1462 件についてのみで、parse 失敗した3ファイルのテストは一度も実行されていない（コミットメッセージの「GUT: 1462/1462 passing」は parse error の存在に気付かないまま記録された false positive）。本 change で根本原因を解消し、CI と同じ手で「気付かない緑」が再発しないようにする。

## What Changes

- **`SpellRng` ラッパクラスを新設** (`src/combat/spells/spell_rng.gd`)。`RandomNumberGenerator` を内部に保持し、`roll(low, high)` 等の自前メソッドを公開する。テストはこれを extend して値制御 stub を作れるため、`RandomNumberGenerator.randi_range()` を override する必要がなくなる。
- **BREAKING (内部 API)**: `SpellEffect.apply` / `DamageSpellEffect.apply` / `HealSpellEffect.apply` のシグネチャを `(caster, targets, rng: RandomNumberGenerator)` から `(caster, targets, spell_rng: SpellRng)` に変更。
- 呼び出し側 (`turn_engine.gd:_resolve_cast`, `spell_use_flow.gd:_apply_cast_and_show_result`) で `SpellRng.new(rng)` でラップして渡すよう修正。
- `SpellUseFlow.set_rng()` のシグネチャも `SpellRng` 受け取りに統一する（呼び出し側のテストが `RandomNumberGenerator` を継承する必要を完全に断つ）。
- **`CombatCommandMenu` の public API を回復**：
  - `_LABELS` (private Dictionary) を `OPTION_LABELS` (public const Dictionary) に rename。
  - `static func base_option_ids() -> Array[int]` を新設。「魔法職でない actor のベース4オプション (ATTACK / DEFEND / ITEM / ESCAPE)」をドメイン語彙として公開する。
- 影響を受ける3つの既存テストを、新 API に沿って parse error なく動く形に修正：
  - `tests/combat/test_spell_effects.gd` — `_FixedRng extends SpellRng` に変更。
  - `tests/esc_menu/flows/test_spell_use_flow.gd` — 同上。
  - `tests/combat/test_item_command_resolution.gd` — `OPTIONS[OPT_ITEM]` 参照を `OPTION_LABELS[OPT_ITEM]` に修正、`test_command_menu_options_include_item` も `base_option_ids()` ベースに書き直す。

## Capabilities

### New Capabilities
- なし。新規ケイパビリティは導入しない（既存の `spell-casting` 内に SpellRng を導入する形）。

### Modified Capabilities
- `spell-casting`: `effect.apply` の RNG 引数の型を SpellRng に変更する旨を明記する（既存の "RNG をそのまま渡す" 記述は SpellRng 経由の roll 抽象に変わる）。

## Impact

- **新規ファイル**: `src/combat/spells/spell_rng.gd`
- **本体修正**:
  - `src/combat/spells/spell_effect.gd` — apply シグネチャ
  - `src/combat/spells/damage_spell_effect.gd` — apply シグネチャ + `rng.randi_range` → `spell_rng.roll`
  - `src/combat/spells/heal_spell_effect.gd` — 同上
  - `src/combat/turn_engine.gd:221` — 呼び出し側ラップ
  - `src/esc_menu/flows/spell_use_flow.gd` — 呼び出し側ラップ + `set_rng` シグネチャ
  - `src/dungeon_scene/combat/combat_command_menu.gd` — `_LABELS` → `OPTION_LABELS`、`base_option_ids()` 追加
- **テスト修正**:
  - `tests/combat/test_spell_effects.gd`
  - `tests/esc_menu/flows/test_spell_use_flow.gd`
  - `tests/combat/test_item_command_resolution.gd`
- **既存仕様**:
  - `spell-casting` の Requirement「Cast effect application produces a SpellResolution」と「Out-of-battle cast applies effects via the same SpellEffect path」が apply の RNG 引数型に言及しているため、SpellRng への変更を反映する。
- **`@warning_ignore` は使用しない**。GDScript の native method override 警告を構造的に発生させない設計（自前クラス `SpellRng` の自前メソッドを override する形）に倒す。
- **後方互換**: 本 change は public ゲームプレイ仕様には影響しない。シナリオ（呪文の効果、MP消費、target 解決）は不変。`SpellEffect.apply` の引数型は内部 API なのでセーブデータ・データファイルへの影響なし。
