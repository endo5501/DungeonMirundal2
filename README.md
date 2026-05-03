# DungeonMirundal2

Wizardry風一人称ダンジョン探索RPG（Godot 4.x）

## 必要環境

- [Godot Engine 4.6+](https://godotengine.org/download/) (Standard版)
- Git

## セットアップ

```bash
git clone git@github.com:endo5501/DungeonMirundal2.git
cd DungeonMirundal2
```

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

### コマンドライン (ヘッドレス)

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

`.gutconfig.json` の設定に従い、`tests/dungeon/` 配下のテストが実行されます。

### 特定のテストファイルのみ実行

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/dungeon/test_wiz_map.gd
```

### テストディレクトリを追加指定

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/dungeon/,res://tests/other/
```

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

## セーブ互換性についての注意

`data/items/potion.tres` は `data/items/healing_potion.tres` にリネームされ、`item_id` も `&"potion"` から `&"healing_potion"` に変更されました(2026-05 のリファクタ)。これより前のセーブで `potion` を所持している場合、ロード時に当該アイテムは復元されず欠落します(他の所持品・装備への影響はありません)。

## 新しいclass_nameを追加した場合

GDScriptで `class_name` を使った新しいスクリプトを追加した後、テスト実行前にインポートが必要です。

```bash
godot --headless --import
```

これを忘れると、テスト実行時に `Nonexistent function 'new'` エラーが発生します。
