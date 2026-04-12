## ADDED Requirements

### Requirement: Godotプロジェクト初期化
Godot 4.xプロジェクトとして正しく初期化され、`project.godot` が存在しなければならない。

#### Scenario: プロジェクトファイルが存在する
- **WHEN** プロジェクトルートを確認する
- **THEN** `project.godot` ファイルが存在する

### Requirement: GUTテストフレームワーク導入
GUT（Godot Unit Test）プラグインが `addons/gut/` に配置され、テストの実行が可能でなければならない。

#### Scenario: GUTプラグインが配置されている
- **WHEN** `addons/gut/` ディレクトリを確認する
- **THEN** GUTプラグインのファイル群が存在する

#### Scenario: テストスクリプトが実行可能
- **WHEN** `tests/` ディレクトリ内のテストスクリプトを GUT で実行する
- **THEN** テストが正常に実行され、結果が出力される

### Requirement: ディレクトリ構成
製品コードは `src/` 配下、テストコードは `tests/` 配下に配置しなければならない。

#### Scenario: ソースコードとテストの分離
- **WHEN** プロジェクト構造を確認する
- **THEN** `src/` ディレクトリに製品コードが存在する
- **THEN** `tests/` ディレクトリにテストコードが存在する
- **THEN** テストコードは `tests/` 配下のみに存在する
