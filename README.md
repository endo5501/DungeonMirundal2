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

## 戦闘遠征シミュレータ (バランス調整用)

パーティ構成・エンカウント供給・AI ノブを JSON で設定してヘッドレスで連戦を回し、「何戦・何ターン耐えられるか」と HP/MP の減衰カーブを再現性のある形で測定するツールです。実際の戦闘コード (`TurnEngine` / `BattleResolver` 等) をそのまま利用者として呼ぶため、本番と同じルールで戦闘が解決されます。

### 実行方法

```bash
godot --headless -s src/simulation/expedition_cli.gd -- --config=docs/simulation/sample_expedition_config.json
```

オプション (いずれも config の値を上書き):

- `--csv=<path>` — CSV 出力先
- `--runs=<int>` — 遠征の反復回数
- `--seed=<int>` — master_seed

終了コード: `0` = 成功 / `1` = config・実行時エラー / `2` = コマンドライン引数エラー。

同一 config・同一 seed なら CSV はバイト単位で一致します (run i の乱数シードは `hash(str(master_seed) + ":" + str(i))` で導出)。

### 設定ファイル

サンプル: `docs/simulation/sample_expedition_config.json` (テーブルモード) / `docs/simulation/sample_expedition_fixed.json` (固定パターンモード)

```jsonc
{
  "runs": 20,               // 遠征の反復回数
  "master_seed": 12345,     // 乱数の親シード (再現性の起点)
  "max_battles": 50,        // 1 遠征あたりの戦闘数上限
  "csv_path": "tmp/simulation/sample_result.csv",
  "party": [                // name / race / job / level / row (front|back)。
    {"name": "Fritz", "race": "human", "job": "fighter", "level": 3, "row": "front"}
    // "stats": {"STR": 12, ...} で基礎ステータスを個別指定可能 (省略時は職の要求値ベース)
  ],
  "ai": {
    "heal_hp_threshold": 0.6,       // HP 割合がこの値以下の味方がいたら僧侶系は回復を優先
    "attack_magic_min_enemies": 2,  // 生存敵がこの数以上なら魔法使い系は攻撃呪文を使う
    "attack_magic_min_tier": 0      // 敵の最大 tier がこの値以上なら敵数に関係なく攻撃呪文 (0 = 無効)
  },
  "encounters": {"mode": "table", "floor": 3}
  // 固定パターンモードの場合:
  // "encounters": {"mode": "fixed", "patterns": [{"goblin": 3}, {"slime": 2}]}
  //   (patterns は種族ID→体数の辞書の配列。順番にループ供給される)
}
```

- `table` モード: 指定フロアの `data/encounter_tables/floor_N.tres` から本番の編成生成ロジックで毎戦闘エンカウントを生成 (遭遇判定はスキップし、常に戦闘が発生)
- 戦闘間には `OUTSIDE_OK` の回復呪文を MP が許す限り自動使用し、経験値・レベルアップも本番経路で反映されます

### 出力

CSV は 1 行 = 1 run × 1 battle の long format です。`run` 列は 0 始まり、`battle` 列は 1 始まりです:

| 列 | 意味 |
|----|------|
| `run` | 遠征の通し番号 (0 始まり) |
| `battle` | 遠征内の戦闘番号 (1 始まり) |
| `encounter` | エンカウントのラベル (`floor_3` / `pattern_0:goblin_x3` 等) |
| `turns` | その戦闘のターン数 |
| `hp_pct_before_heal` | 戦闘間回復**前**のパーティ合計 HP 割合 (0..1) |
| `party_hp_pct` / `party_mp_pct` | 戦闘間回復**後**のパーティ合計 HP / MP 割合 (0..1) |
| `deaths_cum` | 累計死亡者数 |
| `outcome` | `CLEARED` / `WIPED` / `STALLED` |

コンソールには全 run 集計のサマリ表 (battles survived / total turns / first death / MP exhausted の median・p10・p90 と end cause 比率) が出力されます。

> **注意 (ノブ掃引):** PartyAi は実プレイヤーの最適行動を完全には模倣しません。単一の実行結果を真値として扱わず、AI ノブ (`heal_hp_threshold` 等) を掃引して楽観/悲観の幅として読んでください。

## モンスターバランス調整ツール

モンスターの戦闘4値 (HP レンジ/攻撃/防御/敏捷) を、個別の `.tres` 手編集ではなく 1 つの曲線定義 `data/balance/monster_curve.json` から一括調整するためのツール群です。

### バランス曲線定義 (`data/balance/monster_curve.json`)

各ステータスは tier の幾何級数 `base × growth^(tier-1)` に種ごとの役割係数 (`species.<id>.hp` 等、省略時 1.0) を掛けて決まります。HP は中央値を `hp_spread` (種別上書き可) で `hp_min..hp_max` に展開します。曲線に乗らない種 (dragon) は `overrides` で 5 値を直接指定します。役割係数の幾何平均が 1.0 から大きく外れると警告が出ますが処理は続行されます (意図的に外している種: bat / skeleton / witch / wraith)。

### ジェネレータ (`.tres` の戦闘値を再生成)

```bash
# 1. まず --check で差分をプレビュー (ファイルは書き換えない)
godot --headless -s src/simulation/balance_generator_cli.gd -- --balance=data/balance/monster_curve.json --check

# 2. 納得したら --check を外して生成
godot --headless -s src/simulation/balance_generator_cli.gd -- --balance=data/balance/monster_curve.json

# 3. git diff で書き換え結果を確認してからコミット
git diff data/monsters/
```

置換されるのは戦闘4値の行のみで、他のフィールド・書式はバイト単位で保持されます。定義に載っていない種は警告付きでスキップされ (exit 0)、定義が無効な場合は何も書かずに exit 1 で終了します。

### 計器盤 (生存率ヒートマップ / ノブ掃引)

パーティレベル × フロアのグリッドで「`max_battles` 連戦を生き残った割合」を測るツールです。`--balance` を渡すと曲線をメモリ上でのみ適用します (`data/monsters/*.tres` は一切書き換えません。省略時は現状の `.tres` 値で測定)。

```bash
# heatmap: レベル×フロアの生存率グリッド (コンソール表示 + CSV)
godot --headless -s src/simulation/balance_dashboard_cli.gd -- --config=data/balance/dashboard_config.json --mode=heatmap --balance=data/balance/monster_curve.json

# sweep: 曲線ノブ (例: curves.attack.growth) を範囲掃引して感度を見る
godot --headless -s src/simulation/balance_dashboard_cli.gd -- --config=data/balance/sweep_config_example.json --mode=sweep --balance=data/balance/monster_curve.json
```

- CSV 出力先は `--csv=<path>` で指定 (省略時 `tmp/simulation/dashboard_<mode>.csv`)。同一 config・同一 balance なら CSV はバイト単位で一致します
- **粗い設定 → 精密設定の順で見る:** まず levels/floors を広く・`runs` を小さくして全体の傾向を掴み、気になるセルに levels/floors を絞って `runs` を増やして精査してください。`runs` が小さいと ±0.05 程度のノイズで単調性が崩れて見えることがあります
- 実行時間の目安 (実測): heatmap 5 レベル × 12 フロア × 100 runs ≈ 2 分、sweep 4 点 × 2 シナリオ × 50 runs ≈ 12 秒

運用としては「sweep や heatmap で曲線を決める → ジェネレータ `--check` → 生成 → `git diff` → コミット」の順に回します。

## ビルド

### デバッグビルド (デフォルト)

Godotエディタのプロジェクト > エクスポートから、対象プラットフォームのプリセットを追加してエクスポートします。

> **エクスポートプリセット作成時の注意**: 開発者専用ツールである `tools/` 配下と GUT のテスト群 `tests/` 配下はリリースビルドに含めないでください。各プリセットの `Resources` タブの `Filters to exclude non-resource files/folders from export` (= `exclude_filter`) に `tools/*, tests/*` を追加してください。
>
> **Dev Console (開発者向けセーブ編集ツール)**: `godot --path . res://tools/dev_console/main.tscn` で起動。詳細は `tools/dev_console/README.md` を参照。

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
