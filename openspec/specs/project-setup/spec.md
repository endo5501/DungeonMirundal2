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

