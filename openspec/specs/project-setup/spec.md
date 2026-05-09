## Purpose
Godot プロジェクトの初期設定を規定する。Godot バージョン要件、ディレクトリ構成（src/tests/data/addons）、必須アドオン（GUT）、AutoLoad 登録などを対象とする。
## Requirements
### Requirement: Godotプロジェクト初期化
SHALL: Godot 4.xプロジェクトとして正しく初期化され、`project.godot` が存在しなければならない。

#### Scenario: プロジェクトファイルが存在する
- **WHEN** プロジェクトルートを確認する
- **THEN** `project.godot` ファイルが存在する

### Requirement: GUTテストフレームワーク導入
SHALL: GUT（Godot Unit Test）プラグインが `addons/gut/` に配置され、テストの実行が可能でなければならない。

#### Scenario: GUTプラグインが配置されている
- **WHEN** `addons/gut/` ディレクトリを確認する
- **THEN** GUTプラグインのファイル群が存在する

#### Scenario: テストスクリプトが実行可能
- **WHEN** `tests/` ディレクトリ内のテストスクリプトを GUT で実行する
- **THEN** テストが正常に実行され、結果が出力される

### Requirement: ディレクトリ構成
SHALL: 製品コードは `src/` 配下、テストコードは `tests/` 配下に配置しなければならない。

#### Scenario: ソースコードとテストの分離
- **WHEN** プロジェクト構造を確認する
- **THEN** `src/` ディレクトリに製品コードが存在する
- **THEN** `tests/` ディレクトリにテストコードが存在する
- **THEN** テストコードは `tests/` 配下のみに存在する

### Requirement: テストは決定的でなければならない
SHALL: すべてのテストは、ランダム生成や seed に依存する入力データの「適合・不適合」を理由として `pending()` 等で早期 return してはならない。`pending()` は「実装中の未完成テスト」のためにのみ使用してよい。テストが特定の地形・データ条件を必要とする場合、テスト側で当該条件を確実に満たすフィクスチャを手動構築するか、検証済みのデータセットを直接読み込むこと。

#### Scenario: テスト実行が常に同じ結論を出す
- **WHEN** 同一のテストを 100 回実行する
- **THEN** 各テストは pass / fail のいずれか一定の結果を返し、`pending` で早期 return することはない

#### Scenario: ランダム生成への依存を避ける
- **WHEN** テストが特定の地形条件を必要とする
- **THEN** テストはその条件を満たすフィクスチャを `TestHelpers` 等のヘルパー関数で明示的に構築する。`WizMap.generate(seed)` の結果に依存して条件を満たすかを検査し、満たさない場合に `pending` で skip する実装は許容されない

#### Scenario: pending は未実装のテストのみで使う
- **WHEN** テストが「将来実装するが今は書けない」状態である
- **THEN** `pending("未実装")` 相当のメッセージで明確に意図を示してよい

### Requirement: TestHelpers は決定的フィクスチャ構築 API を提供する
SHALL: `tests/test_helpers.gd` (`TestHelpers` クラス) は、地形依存テストのための決定的なフィクスチャ構築用ユーティリティを提供すること。最低限、以下の用途をカバーする:
- 直線通路フィクスチャ(指定位置から指定方向へ N セル開いた地形)
- 完全閉塞フィクスチャ(指定位置を全方向 WALL で囲んだ地形)
- 隣接 START フィクスチャ(指定位置の隣に START があり、forward で START に着く地形)

#### Scenario: コリドーフィクスチャは指定方向に open している
- **WHEN** `TestHelpers.make_corridor_fixture(Vector2i(3, 3), Direction.NORTH, 3)` を呼び出す
- **THEN** (3, 3) から NORTH 方向に PlayerState.move_forward が成功する WizMap が返る(3 セル分以上開通)

#### Scenario: ブロックフィクスチャは全方向 WALL
- **WHEN** `TestHelpers.make_blocked_fixture(Vector2i(3, 3))` を呼び出す
- **THEN** (3, 3) からどの方向に move_forward しても false が返る WizMap が返る

### Requirement: project.godot defines custom InputMap actions for game-specific input
SHALL: `project.godot` SHALL contain an `[input]` section that defines the following custom actions in addition to Godot's default `ui_*` actions:

- `move_forward`: bound to KEY_W and KEY_UP
- `move_back`: bound to KEY_S and KEY_DOWN
- `strafe_left`: bound to KEY_A
- `strafe_right`: bound to KEY_D
- `turn_left`: bound to KEY_LEFT
- `turn_right`: bound to KEY_RIGHT
- `toggle_full_map`: bound to KEY_M

These actions SHALL be the canonical source of truth for in-game movement and game-specific UI inputs. Source code SHALL NOT compare against `event.keycode == KEY_*` for these inputs; instead, code SHALL use `event.is_action_pressed("<action_name>")`.

#### Scenario: Custom actions exist in project.godot
- **WHEN** `project.godot` is loaded by Godot 4.x
- **THEN** `InputMap.has_action("move_forward")` SHALL return `true` for each of the seven custom actions

#### Scenario: WASD and arrow keys both trigger move_forward
- **WHEN** a KEY_W or KEY_UP press event is dispatched
- **THEN** `event.is_action_pressed("move_forward")` SHALL return `true`

#### Scenario: M key triggers toggle_full_map
- **WHEN** a KEY_M press event is dispatched
- **THEN** `event.is_action_pressed("toggle_full_map")` SHALL return `true`

### Requirement: All _unhandled_input handlers use action-based input
SHALL: Source files under `src/` containing `_unhandled_input(event)` MUST use `event.is_action_pressed("<action_name>")` for input matching. Direct keycode comparisons (`event.keycode == KEY_*`) SHALL NOT appear in any `_unhandled_input` body in `src/`. Exceptions: text input handlers (typing a character name) MAY still inspect keycode/unicode for letter input.

#### Scenario: No keycode comparisons in _unhandled_input under src/
- **WHEN** the codebase is grepped for `event.keycode == KEY_` within `_unhandled_input` bodies
- **THEN** the search SHALL return no matches in `src/` (text-input character entry handlers are excepted)

#### Scenario: Action-based pattern is followed
- **WHEN** a screen handles ESC input
- **THEN** it SHALL use `event.is_action_pressed("ui_cancel")` rather than `event.keycode == KEY_ESCAPE`

### Requirement: project.godot configures viewport stretch for window resize support

`project.godot` SHALL contain a `[display]` section that configures the viewport-based stretch system so that the entire UI scales uniformly when the user resizes the window. The configuration SHALL set:

- `window/size/viewport_width = 1600` and `window/size/viewport_height = 900` as the design canvas
- `window/stretch/mode = "canvas_items"` so each Control node re-rasterizes at the actual window resolution
- `window/stretch/aspect = "expand"` so the design canvas extends naturally on aspect ratios that differ from 16:9 (no letterboxing, no distortion)

These settings SHALL be loaded by Godot 4.x at engine startup so that all subsequent scene rendering operates under the configured stretch system.

#### Scenario: Display section exists in project.godot
- **WHEN** `project.godot` is opened
- **THEN** it SHALL contain a `[display]` section with `window/size/viewport_width = 1600`, `window/size/viewport_height = 900`, `window/stretch/mode = "canvas_items"`, and `window/stretch/aspect = "expand"`

#### Scenario: Window content scales when resized larger
- **WHEN** the game is launched at the default window size and the user resizes the window from the design size to twice as large in each dimension
- **THEN** the rendered Control content (fonts, panels, sprites) SHALL appear approximately twice as large on screen

#### Scenario: Aspect ratio is preserved without distortion
- **WHEN** the user resizes the window to an aspect ratio different from the design (e.g., 21:9 ultrawide)
- **THEN** the rendered fonts and sprites SHALL NOT distort horizontally or vertically; instead, the additional viewport area SHALL extend the design canvas so anchored Control nodes redistribute proportionally

### Requirement: project.godot defines a default launch window size

`project.godot` SHALL configure the initial OS window size at game launch to match the design viewport (1600×900) so that the default launch state shows the UI at unscaled, designer-intended density. This is achieved by relying on Godot's default behavior where `window/size/viewport_width` and `window/size/viewport_height` also drive the initial window size when no `window_width_override` / `window_height_override` are provided, OR by explicitly setting them to the same values.

#### Scenario: Default window dimensions match design canvas
- **WHEN** the game is launched without command-line size overrides
- **THEN** the initial OS window SHALL be 1600 pixels wide by 900 pixels tall (subject to the host OS window decorations and DPI scaling)

