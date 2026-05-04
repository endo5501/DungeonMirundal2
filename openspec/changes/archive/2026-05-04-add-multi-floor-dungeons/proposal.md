## Why

現在のダンジョンは 1 ダンジョンあたり 1 階層しか持てず、Wizardry 系ダンジョン RPG として期待される「深層へ潜る」体験が成立しない。エンカウンターテーブルと `main.gd` には既に多階層を見越した TODO（`_encounter_tables_by_floor`、`# TODO: use the dungeon's current floor once multi-floor dungeons land.`）が残されており、土台が整った今のタイミングで多階層化を行うのが自然である。

## What Changes

- **BREAKING**: `DungeonData` を 1 つの `wiz_map` / `explored_map` 保持から、`floors: Array[FloorData]` 保持に変更する。`FloorData` は単一階分の `seed_value`、`map_size`、`wiz_map`、`explored_map` を持つ。
- **BREAKING**: `PlayerState` に `current_floor: int` フィールドを追加し、プレイヤーの所属階を保持する。
- **BREAKING**: `TileType` に `STAIRS_DOWN` と `STAIRS_UP` を追加する。`FLOOR / START / GOAL` の 3 値想定だったコード分岐を更新する。
- ダンジョン生成時に階数をサイズ連動でランダム決定する（小=2-4 / 中=4-7 / 大=8-12）。各階の `map_size` も独立してサイズレンジ内でランダムに決まる。各階のシードは基底シードから決定論的に派生させ、再現性を保つ。
- 階段配置: 各階に最大 1 個の `STAIRS_DOWN`、最大 1 個の `STAIRS_UP` を配置する。階段マスの座標は階間で対応せず、階段ペアは「同じダンジョン内の floor index 差」だけで紐付く。1F は START + STAIRS_DOWN、中間階は STAIRS_UP + STAIRS_DOWN、最深階は STAIRS_UP + GOAL を持つ。
- 階段マスへの進入時、START 帰還ダイアログと同じ `ConfirmDialog` を再利用して「下の階に降りますか?」「上の階に戻りますか?」を表示する。「はい」確定で対応階段マスへ瞬間移動し、向き（facing）は保持する。
- `EncounterCoordinator` がダンジョンの現在階を参照し、階に対応した `EncounterTableData` をセットするよう変更する。階が登録テーブル数を超える場合は、登録済み最大階のテーブルにフォールバックし、警告ログを出力する。
- 探索率（`DungeonData.get_exploration_rate()`）は全階合計セル数に対する全階合計訪問セル数の比に拡張する。
- セーブ/ロード（`DungeonData.to_dict` / `from_dict`）を新スキーマに合わせて更新する。**互換性は保たない**（開発中のため過去スロットの移行は対象外）。
- `main.gd:207-208` の TODO を解消し、現在階に応じたエンカウンターテーブル切替を実装する。

スコープ外（別 change）:
- フルマップオーバーレイの階タブ切替
- ボス階・特殊ギミック（暗闇・回転床・落とし穴 等）
- 階層降下スクロール等の新規アイテム
- 既存セーブの後方互換マイグレーション

## Capabilities

### New Capabilities

- なし（新規 capability は作らない方針）

### Modified Capabilities

- `dungeon-generation`: タイル種別に `STAIRS_DOWN` / `STAIRS_UP` を追加し、階段配置ステップを生成パイプラインに組み込む。
- `dungeon-management`: `DungeonData` に `floors: Array[FloorData]` を導入。`FloorData` 構造、`PlayerState.current_floor`、探索率計算の全階拡張を含む。
- `dungeon-movement`: 階段マス進入時の階移動トリガを追加し、`PlayerState` の階更新を規定する。
- `dungeon-return`: 階段マスでの確認ダイアログ表示と「はい」確定時の対応階段マスへの遷移を規定する。1F の START 帰還挙動は維持する。
- `encounter-detection`: ダンジョンの現在階に応じた `EncounterTableData` のセット切替と、テーブル不足時のフォールバックを規定する。
- `serialization`: `DungeonData` / `FloorData` / `PlayerState` の dict 化を新スキーマに合わせる。

## Impact

**コード（src/）**
- `src/dungeon/dungeon_data.gd`: `floors` 配列保持に再構成。`reset_to_start` は 1F の START へ戻す挙動に変更。
- `src/dungeon/floor_data.gd` (新規): 単一階分の `seed_value` / `map_size` / `wiz_map` / `explored_map` を保持。
- `src/dungeon/dungeon_registry.gd`: `create()` で多階層を一括生成。
- `src/dungeon/wiz_map.gd`: 階段タイル配置メソッドを追加。
- `src/dungeon/tile_type.gd`: enum 拡張（`STAIRS_DOWN` / `STAIRS_UP`）。
- `src/dungeon/player_state.gd`: `current_floor` フィールド追加、`to_dict` / `from_dict` 更新。
- `src/dungeon_scene/dungeon_screen.gd`: 階段マス検出と確認ダイアログ表示、階遷移ロジック。
- `src/dungeon/encounter_coordinator.gd` または `main.gd`: 階に応じたエンカテーブル切替。
- `src/dungeon/full_map_renderer.gd` / `src/dungeon/minimap_renderer.gd` / `src/dungeon/cell_mesh_builder.gd` 等の `TileType` 列挙参照箇所: 新タイルへの対応（描画は当面 START/GOAL と同等の表示で可）。

**データ（data/）**
- `data/encounter_tables/floor_2.tres` 〜 必要分のテーブル追加。最低でも 2-3 階分は実データ用意。

**テスト（tests/）**
- `tests/dungeon/test_dungeon_data.gd`: 多階層生成と探索率の検証を追加。
- `tests/dungeon/test_wiz_map.gd`: 階段タイル配置の検証を追加。
- `tests/dungeon/test_dungeon_screen_*.gd`: 階段ダイアログと階遷移の検証を追加。
- `tests/dungeon/test_encounter_coordinator.gd`: 階別テーブル切替とフォールバックの検証を追加。
- `tests/save_load/`: 多階層 DungeonData の round-trip 検証を追加。

**ドキュメント / 既存 TODO**
- `main.gd:207-208` の TODO コメントを削除。
