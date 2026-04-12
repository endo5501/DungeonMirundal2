## Context

Wizardry風ダンジョン探索RPG「DungeonMirundal2」の最初のchangeとして、Godotプロジェクトの初期セットアップとダンジョン自動生成アルゴリズムを実装する。

Python参考実装 (`docs/reference/dungeon_generator.py`) が存在し、約400行のコードで完全迷路ベースのダンジョン生成を実現している。これをGDScriptに移植する。

プロジェクト全体ではTDD（テスト駆動開発）を採用しており、GUTフレームワークを使用する。ダンジョン生成はUI非依存の純粋ロジックであるため、TDDの最初の対象として最適。

## Goals / Non-Goals

**Goals:**
- Godot 4.xプロジェクトを正しく初期化し、GUTによるテスト実行環境を構築する
- Python参考実装と同等のダンジョン生成アルゴリズムをGDScriptで実装する
- RefCountedベースの純粋ロジッククラスとして実装し、UIやNodeツリーに依存しない
- シード値による再現可能な生成を保証する

**Non-Goals:**
- 3D描画やUI要素（後続changeで対応）
- 外部データファイル形式の決定（必要になった時点で決める）
- パフォーマンス最適化（まず正しさを優先）

## Decisions

### 1. クラス基底: RefCounted

**選択:** 全ダンジョン生成クラスをRefCountedベースにする

**理由:** Nodeベースにすると SceneTree への追加が必要になり、テストが複雑化する。RefCountedなら `var map = WizMap.new()` だけでインスタンス化でき、GUTテストから直接呼べる。

**代替案:**
- Node/Resource ベース → SceneTree依存が発生しテストが困難
- static関数群 → 状態管理が煩雑、テストしにくい

### 2. ファイル構成

**選択:**

```
project_root/
├── project.godot
├── src/
│   └── dungeon/
│       ├── direction.gd        # Direction enum + ヘルパー
│       ├── edge_type.gd        # EdgeType enum (WALL/OPEN/DOOR)
│       ├── tile_type.gd        # TileType enum (FLOOR/START/GOAL)
│       ├── cell.gd             # Cell クラス（RefCounted）
│       ├── rect.gd             # Rect クラス（RefCounted）
│       └── wiz_map.gd          # WizMap メインクラス（RefCounted）
├── tests/
│   └── dungeon/
│       ├── test_direction.gd
│       ├── test_cell.gd
│       ├── test_rect.gd
│       └── test_wiz_map.gd
└── addons/
    └── gut/                    # GUT プラグイン
```

**理由:** Python実装の各クラスに対応するファイルに分離し、各クラスを独立してテスト可能にする。`src/` と `tests/` を分離してテストコードが製品ビルドに含まれないようにする。

### 3. GDScript enumの扱い

**選択:** Direction, EdgeType, TileType は個別の `.gd` ファイルにconst辞書 or enumとして定義

**理由:** GDScriptのenumはファイルスコープ。クラス間で共有するにはファイルを分ける必要がある。`class_name` を使ってグローバル参照可能にする。

**代替案:**
- 全部一つのファイルにまとめる → ファイルが肥大化し、個別テスト困難
- Godot Resourceとして定義 → over-engineering

### 4. 乱数管理

**選択:** `RandomNumberGenerator`（Godot組込み）を使用し、シード値を受け取る

**理由:** Python実装の `random.Random(seed)` に相当。シード値で再現可能な生成を保証でき、テストでの検証が容易。

### 5. Python → GDScript 移植方針

**選択:** クラス構造とアルゴリズムはPython実装に忠実に移植し、GDScript固有の最適化は後回し

**理由:**
- まず動作の正しさを保証（テストで検証）
- Python実装と同じシードで同じ結果を期待する必要はない（乱数実装が異なるため）
- ただしアルゴリズムの論理的等価性は保つ

**主要な言語差異への対応:**
- `Dict` → `Dictionary`
- `List` → `Array`
- `set` → `Dictionary`（キーのみ使用）または `Array`
- `deque` → `Array`（pop_front）
- `dataclass` → RefCountedクラス
- `Enum` → const辞書 or GDScript enum
- `Tuple[int,int]` → `Vector2i`

## Risks / Trade-offs

- **GDScriptのパフォーマンス**: 大きなマップ（size >= 50）でDFS/BFSが遅くなる可能性がある → 当面size=20前後で運用し、問題が出たら最適化
- **GDScript enumの制約**: Pythonのように柔軟なenumが使えない → const辞書パターンで代替し、型安全性はテストでカバー
- **GUT導入手順**: Godot 4.x + GUT の組合せでのセットアップ手順が変わる可能性 → 公式ドキュメントに従い、テスト実行確認を最初のタスクとする
