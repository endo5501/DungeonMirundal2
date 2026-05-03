## Context

GUT の `pending(message)` は `Godot.Test` の skip 機能と異なり、明示的に「実装中」を示す目印として使う想定。現状の使い方は「ランダム生成された地形が想定通りでない場合、テストをスキップ」という用途で、これは GUT の本来の意図に反する(検証していないのに緑になる)。

既存の `WizMap` API には `WizMap.new(size)` (全壁初期化) と `set_edge(x, y, dir, edge_type)` / `open_between(x1, y1, x2, y2)` が既に公開されており、手動でフィクスチャを構築できる。`generate(seed)` は決定的なので、特定の seed が要求 topology を満たすことを検証して使うこともできる。

ただし、seed ベースのフィクスチャは「seed N でこの位置に open_forward があることを検証する」ロジックが要るので、手動構築のほうがシンプル。

## Goals / Non-Goals

**Goals**
- すべてのテストが決定的に検証する
- `pending` を「実装中」以外の理由で使わないことを project-setup spec で確立する
- 既存の検証範囲を狭めない(リファクタ前と同じ振る舞いを検証する)
- 将来書く同種テストのためのヘルパーを `TestHelpers` に整理する

**Non-Goals**
- `WizMap` 本体への変更(API は十分そろっている)
- テストフレームワークの差し替え(GUT のまま)
- `make_test_map()` の既存呼び出し全体の置換 — 既に動いているテストはそのまま
- Property-based testing の導入 — 過剰

## Decisions

### Decision 1: 手動構築フィクスチャを優先する

**選択**: `WizMap.new(8)` + `open_between` 等で構築する `make_corridor_fixture()` / `make_blocked_fixture()` 等のヘルパーを `TestHelpers` に追加する。seed-and-verify は使わない。

**理由**:
- 「(3, 3) は (3, 2) に対して open」のように、テストが期待する topology を明示的に書ける
- seed の検証ロジックを書くより、4-5 行で構築するほうが短い
- 将来 WizMap の生成アルゴリズムを変えたとき、特定 seed の topology が変わるリスクがない

**代替案**: `for seed in range(0, 1000): if has_topology: break` で seed を探す → 過剰、しかも生成アルゴリズムに結合する。

### Decision 2: 既存 `make_test_map()` は残す

**選択**: 既存 `TestHelpers.make_test_map()` (8x8 の seed=42 ベース) は触らない。`pending` を使っていなかったテストはそのまま動く。

**理由**:
- 多くのテストが make_test_map に依存しており、この change のスコープを膨らませるのは避ける
- `make_test_map` は START の位置を固定するだけで、内部 topology は seed 42 のまま — 地形が「適切」かどうかは現状検証していないし、それでも 90% のテストは passed なので維持で問題ない

### Decision 3: `pending` の用途を project-setup spec で固定する

**選択**: `project-setup` spec に Requirement: 「Tests SHALL be deterministic; `pending()` SHALL be used only for tests whose implementation is in progress, NOT for tests whose input data may not match the test's preconditions」を追加。

**理由**:
- 同じパターンが将来他のテストファイルにも忍び込まないようにする
- 仕様レベルでの宣言は OpenSpec のリファクタ計画(改修対象テストの再生成)時に参照できる

### Decision 4: 空ディレクトリ削除と HasMpSlot テスト追加は同梱

**選択**: F013 と F044 はテストファイル整理の一環として同じ change にまとめる。

**理由**:
- どちらもテスト周りの「掃除」で、レビュー単位として一体感がある
- 別 change にすると 2-3 ファイルだけの change が増えて煩雑

## Risks / Trade-offs

- **[既存 `make_test_map` が薄く検証されている]** seed=42 の地形は実は `place_start_and_goal` で START を別位置に置いてから手動で書き換える形で「START 位置だけ決定的」にしている。地形そのものはランダム生成なので、地形に依存するテストはそもそも fragility がある → これは現状 `_find_open_forward_position` で吸収しているが、今回の change で fixture を導入することで地形依存を解消する。
- **[手動フィクスチャの保守]** 4-5 行のフィクスチャ構築コードがテストごとに散らばる → ヘルパーに集約する方針なので OK。
- **[GUT の `pending` 文化]** 他プロジェクトでは `pending` を skip 的に使うことがある。本リポジトリはそれを許容しないと spec で宣言する → 強い宣言だが、CI の信頼性のために必要。
