## Context

`add-magic-system` change のマージ後、3つのテストファイルが GUT のテスト集計から **沈黙のうちに脱落している**。

- `tests/esc_menu/flows/test_spell_use_flow.gd` および `tests/combat/test_spell_effects.gd`：自前 stub `class _FixedRng extends RandomNumberGenerator` が `randi_range()` を override しているが、GDScript はこれを `native_method_override` 警告として検知する。Godot 4.6 ではこの警告が default で error 昇格されるため、parse error となりファイル全体が load 失敗。
- `tests/combat/test_item_command_resolution.gd`：`CombatCommandMenu.OPTIONS[OPT_ITEM]` を参照しているが、magic system の動的コマンド対応リファクタで public な `const OPTIONS: Array[String]` が `const _LABELS: Dictionary` (private) に変更され、シンボルが消滅。同じく parse error。

GUT は parse error のテストを `[WARNING]: Ignoring script ... because it does not extend GutTest` と誤判定して集計から外し、終了コード `0` で `All tests passed!` を出す。コミットメッセージ「GUT: 1462/1462 passing」は parse 通過した1462件のみを指しており、**実際にはこの3ファイルのテストは一度も走っていない**。

本 change は3ファイルの parse 通過を回復するが、その手段として **「test 側 workaround」ではなく「設計レベルでの根本対応」** を選ぶ。具体的には:

1. テストが native クラスを override せざるを得ない構造を解消する。
2. 本体のリファクタで失われた public 契約 (`OPTIONS` 配列定数) を、より良い形 (`OPTION_LABELS` Dictionary + `base_option_ids()` static method) で復活させる。

## Goals / Non-Goals

**Goals:**
- 3ファイル全部の parse error を解消し、テストが GUT に集計されるようにする。
- `RandomNumberGenerator` の native method override を本リポジトリのテスト戦略から構造的に追放する。
- `CombatCommandMenu` の semantic ID と表示ラベルの対応関係を再び public な testable な契約として公開する。
- 既存の `spell-casting` シナリオ・テスト動作・ゲームプレイ挙動は不変。

**Non-Goals:**
- `@warning_ignore` による警告抑制は行わない（症状を隠すだけで根本未解決）。
- 戦闘 RNG 全体のリファクタ（`turn_engine`, `battle_resolver`, `damage_calculator`, `encounter_*` 等の RNG 引数型変更）は行わない。本 change は spell effect 経路に限定する。
- GUT 自体の挙動修正（`Ignoring script` を error 終了させる等）は行わない。CI 側で parse error を検知する仕組みは別 change で扱う。
- `CombatCommandMenu` の動的コマンド構築ロジック自体の改修は行わない（`_build_option_ids_for(actor)` の挙動は不変）。

## Decisions

### Decision 1: `SpellRng` ラッパクラスを RefCounted で導入（合成）

**選択**: 新規クラス `class_name SpellRng extends RefCounted`。`RandomNumberGenerator` を内部に保持し、`roll(low, high) -> int` 等の自前メソッドを公開する。

**理由**:
- `RefCounted` を継承し、自前メソッド `roll()` を公開するため、テストが `SpellRng` を extend して `roll()` を override しても `native_method_override` 警告は **構造的に発生しない**（GDScript→GDScript の override は GDScript の動的ディスパッチで完全に処理される）。
- `Callable` を引数に取る案 (R-B) と比べ、型がクラスとして補完・参照可能で、GDScript の type system と相性が良い。
- 将来 `roll_d20()`, `roll_percent()`, `weighted_pick()` などが必要になった場合に同じクラスに追加でき、抽象が育てやすい。

**却下した代替**:
- `Callable` 引数化 (R-B): 型補完が効かず、将来の拡張が散らばる。
- `RandomNumberGenerator` 引数のまま `@warning_ignore` で抑止: ユーザー要望により却下。
- ロール値を事前計算して引数渡し (R-C): effect 自身が roll の range (`spread`) を持つため、呼び出し側に逆向き依存が生じて不自然。
- `RandomNumberGenerator` 全面廃止して新 RNG 抽象に統一: 17箇所のプロダクション利用箇所への波及が過大、本 change のスコープを越える。

### Decision 2: `SpellRng` のスコープを spell effect 経路に限定

**選択**: `SpellEffect.apply` / `DamageSpellEffect.apply` / `HealSpellEffect.apply` の RNG 引数のみ `SpellRng` に切り替える。`turn_engine.resolve_turn(rng: RandomNumberGenerator)` や `battle_resolver.resolve_rewards(turn_engine, rng: RandomNumberGenerator)` 等は **触らない**。呼び出し側 (`turn_engine._resolve_cast`, `spell_use_flow._apply_cast_and_show_result`) で `SpellRng.new(rng)` でラップする。

**理由**:
- 問題が顕在化したのは spell effect の値制御テストのみ。他の RNG 利用箇所 (turn order 決定、ダメージ計算、エンカウント生成、宝箱ゴールド) は seed 固定 RNG で十分なテスト戦略が成立しており、変更する必然性がない。
- 本 change を最小スコープに保つことで、レビュー負荷を下げ、リグレッションリスクも下げる。
- 将来 `SpellRng` の有用性が他の経路にも及ぶと判明したら、別 change で段階的に拡大できる。

### Decision 3: `SpellUseFlow.set_rng()` も `SpellRng` 受け取りに統一

**選択**: `func set_rng(spell_rng: SpellRng)` に変更し、内部の `_rng` フィールドの型も `SpellRng` にする。`_get_rng()` も `SpellRng` を返す。

**理由**:
- `set_rng(RandomNumberGenerator)` のままだと、test_spell_use_flow.gd で「テストは `_FixedRng extends SpellRng` を渡したいが API は `RandomNumberGenerator` を要求する」というギャップが残り、結局テスト側で `RandomNumberGenerator` を継承するしかなくなる。
- `SpellUseFlow` が effect.apply に渡すのは結局 `SpellRng` なので、内部表現を最初から `SpellRng` で持つ方がレイヤとして一貫する。
- 既存呼び出し箇所は test 経由のみ（プロダクションは `set_rng` を呼んでいない）。`SpellUseFlow._get_rng()` のフォールバックは `SpellRng.new(null)` で内部に新規 `RandomNumberGenerator` を作って `randomize()` する。

### Decision 4: `_LABELS` を `OPTION_LABELS` (public) に rename

**選択**: `CombatCommandMenu` の `const _LABELS: Dictionary` を `const OPTION_LABELS: Dictionary` に rename し、private アンダースコア prefix を外す。

**理由**:
- 元々 magic system 直前まで `const OPTIONS: Array[String]` として public だった。private 化は明示的な意図ではなく、リファクタでの単純な naming choice の流れ弾。
- このテーブルは「OPT_* semantic ID と表示ラベルの対応」という、**外部から検証する価値のある契約**。テストが「OPT_ITEM (=2) は 'アイテム' と表示される」と assert することは正当な spec verification。
- 「`LABELS` だけだと『何の?』が抜ける」というユーザー指摘を受け、`OPTION_LABELS` を採用（`OPT_*` オプションのラベル、と素直に読める）。
- `static func get_label(id) -> String` 化する案もあるが、Dictionary を直接参照可能にしておく方が Godot 4 の `const` 表現と素直に揃う。

### Decision 5: `static func base_option_ids() -> Array[int]` を新設

**選択**: `CombatCommandMenu.base_option_ids()` を static として新設し、`[OPT_ATTACK, OPT_DEFEND, OPT_ITEM, OPT_ESCAPE]` を返す。`_build_option_ids_for(actor)` の実装からも参照されるよう内部リファクタを行う。

**理由**:
- 「魔法職でない actor のベース4オプション」というコンセプトを **ドメイン語彙として明示**。テスト側が `assert_eq(menu.get_options(), expected)` のような expected を構築する際の根拠になる。
- 現状 `test_command_menu_options_include_item` は `var menu := CombatCommandMenu.new(); var opts := menu.get_options()` で4オプションを期待しているが、`_option_ids` は `show_for(actor)` 呼ぶまで空。 `base_option_ids()` を expected として使うことで、テストが actor セットアップ無しでベース契約を検証できる。
- `_build_option_ids_for(null)` を呼べば事実上同じ結果が得られるが、**意図が不明瞭**（"actor が null の特殊ケース" のように読める）。`base_option_ids()` という名前で意図を明示するほうが読み手に親切。

### Decision 6: `OPTION_LABELS` のキー型は `int` (現状の `_LABELS` と同じ)

**選択**: `const OPTION_LABELS: Dictionary` のキーは `OPT_ATTACK` 等の `int` 定数のまま。型注釈を `Dictionary` のままにし、`Dictionary[int, String]` のような typed dictionary への昇格は本 change では行わない。

**理由**:
- 既存実装が `Dictionary` のため、最小変更で目的が達成できる。
- typed dictionary は GDScript の比較的新しい機能で、プロジェクト全体の他の Dictionary 定数との一貫性も問題になる。本 change のスコープ外。

## Risks / Trade-offs

- **Risk**: `SpellRng` の API (`roll(low, high)`) が将来増えた場合、テストの `_FixedRng` stub も追加 method を override する必要が出てくる。
  → **Mitigation**: 現時点では `roll()` 1個だけで十分。将来追加する method はプロダクションコードが本当に必要になったタイミングで追加する（YAGNI）。

- **Risk**: `OPTION_LABELS` を public にすると、本来 internal なはずの label テーブルが外部依存対象になる。
  → **Mitigation**: 元々 magic system 直前までは public だった (`const OPTIONS: Array[String]`)。回復であって新規 expose ではない。 `_LABELS` の private 化が無自覚な regression だったというのが本 change の前提。

- **Risk**: `set_rng` のシグネチャ変更で既存テストが壊れる。
  → **Mitigation**: `set_rng` を呼んでいる test 自体が今回の修正対象 2ファイルのみ。プロダクションは呼んでいない。

- **Risk**: `SpellRng` 経由で 1 layer 増えることによる微小なオーバーヘッド。
  → **Mitigation**: 実測上問題になる規模ではない（spell cast は秒に数回オーダー、roll() は単純な method dispatch）。

- **Trade-off**: 本 change は parse error の修正のみで、「parse error が CI で検知されない」という問題自体は別 change で扱う。本 change マージ後も、**将来同じことが起きうる**（GUT は parse error を error 扱いせず exit 0 で終わる）。
  → 当初は別 change として残す予定だったが、ユーザー判断により**直接コミット**で `scripts/run_tests.ps1` / `scripts/run_tests.sh` / `scripts/check_scripts.gd` を追加し、README の「テストの実行」セクションを推奨ルートに書き換えた（pre-flight + post-scan の二重防壁）。本 change の作業が始まる前にラッパ自身は `main` 上で動いている前提で、本 change の Sec.7 「全体回帰確認」では `scripts/run_tests.ps1` 経由で 0-exit を確認する形に置き換えてよい。

## Migration Plan

本 change は internal API の変更のみで、データファイル・セーブデータ・public ゲームプレイ仕様には影響しない。マイグレーションは不要。

実装順序（tasks.md で詳述）:
1. 新規 `SpellRng` クラスを作成し、unit test を書く（TDD）。
2. `SpellEffect` 系3クラスのシグネチャを変更する。
3. `turn_engine` / `spell_use_flow` の呼び出し側で `SpellRng.new(rng)` を入れる。
4. `tests/combat/test_spell_effects.gd` の `_FixedRng` を `extends SpellRng` に変更。
5. `tests/esc_menu/flows/test_spell_use_flow.gd` の `_FixedRng` を `extends SpellRng` に変更、`set_rng` 呼び出しを更新。
6. `CombatCommandMenu` で `_LABELS` → `OPTION_LABELS` rename、`base_option_ids()` を追加。
7. `tests/combat/test_item_command_resolution.gd` の2テストを `OPTION_LABELS` / `base_option_ids` ベースに修正。
8. 全テスト実行で 1465+ パス、parse error ゼロを確認。

## Open Questions

- なし。設計議論は explore 段階で完了済み。
