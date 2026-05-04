# DungeonMirundal2

Wizardry風一人称ダンジョン探索RPG（Godot 4.x）

## 必要環境

- [Godot Engine 4.6.x](https://godotengine.org/download/) (Standard版)
- Git

## セットアップ

```bash
git clone git@github.com:endo5501/DungeonMirundal2.git
cd DungeonMirundal2
```

> **セーブデータ互換性の注意:** 2026-05 のリファクタで `data/items/potion.tres` を `healing_potion.tres` にリネームし、`item_id` を `&"potion"` から `&"healing_potion"` に変更しました。これ以前のセーブで `potion` を所持している場合、ロード時に当該アイテムは復元されず欠落します(他の所持品・装備には影響しません)。

初回はGodotにclass_nameを認識させるためインポートが必要です。

```bash
godot --headless --import
```

## セットアップ:AI

Claude Code/Codex等コーディングエージェントを準備してください

```bash
# OpenSpec
npm install -g @fission-ai/openspec@latest
openspec init
openspec config profile
# Codex CLI
npm i -g @openai/codex

# superpowers (in Claude Code)
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

# Codex plugin for Claude Code
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

## エディタで開く

```bash
godot --editor
```

またはGodotエディタからプロジェクトマネージャ経由で `project.godot` をインポートしてください。

## テストの実行

### コマンドライン (推奨ラッパ経由)

```powershell
# Windows (PowerShell)
.\scripts\run_tests.ps1
```

```bash
# Linux / macOS / WSL / Git Bash
./scripts/run_tests.sh
```

`scripts/run_tests.ps1` (および `.sh`) は GUT を 2 段階の安全網付きで実行します:

1. **Pre-flight**: `src/` と `tests/` 配下の全 `.gd` を `scripts/check_scripts.gd` で parse 検証する。1つでも parse error があれば GUT を起動せずに即座に halt する。
2. **Post-scan**: GUT 出力から `SCRIPT ERROR:` / `Failed to load script` / `Ignoring script ... because it does not extend GutTest` を検出したら、たとえ GUT が `All tests passed!` と返しても exit 1 で fail する。

これにより、parse error で silently skip されたテストファイルが「緑」のまま見過ごされる事故を防げます。

追加の引数はそのまま `gut_cmdln.gd` に転送されます:

```powershell
.\scripts\run_tests.ps1 -gtest=res://tests/dungeon/test_wiz_map.gd
```

### 直接実行 (素の GUT、安全網なし)

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

`.gutconfig.json` の設定に従い、`tests/dungeon/` 等の配下のテストが実行されます。**parse error が発生しても緑のまま終わる可能性があるため、CI や日常運用ではラッパ経由を推奨します**。

### エディタから実行

1. Godotエディタを開く
2. 下部パネルの「GUT」タブをクリック
3. 「Run All」で全テスト実行

## ビルド

### デバッグビルド (デフォルト)

Godotエディタのプロジェクト > エクスポートから、対象プラットフォームのプリセットを追加してエクスポートします。

```bash
# コマンドラインでのデバッグエクスポート (プリセット設定済みの場合)
godot --headless --export-debug "Windows Desktop" build/DungeonMirundal2.exe
```

デバッグビルドでは `assert()` が有効です。例えば `WizMap.new(7)` のような不正なサイズ指定で即座に停止します。

### リリースビルド

```bash
godot --headless --export-release "Windows Desktop" build/DungeonMirundal2.exe
```

リリースビルドでは `assert()` は無効化されます。

## 新しいclass_nameを追加した場合

GDScriptで `class_name` を使った新しいスクリプトを追加した後、テスト実行前にインポートが必要です。

```bash
godot --headless --import
```

これを忘れると、テスト実行時に `Nonexistent function 'new'` エラーが発生します。
