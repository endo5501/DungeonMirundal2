## Context

現状、`DungeonData` は単一の `WizMap` / `ExploredMap` / `PlayerState` を保持し、ダンジョン = 1 階という構造になっている。`EncounterTableData` と `main.gd` は既に階数を意識した API（`floor` フィールド、`_encounter_tables_by_floor` 辞書）を持っており、`main.gd:207-208` には多階層化を待つ TODO が明記されている。`TileType` enum は `FLOOR / START / GOAL` の 3 値で、階段マスは未定義である。

本 change は Wizardry 系の「複数階層を潜行する」体験を実現するため、データモデル・生成・移動・遷移・エンカ切替・シリアライズを一括して多階層対応に拡張する。

## Goals / Non-Goals

**Goals:**
- ダンジョンを `floors: Array[FloorData]` の集合体としてモデル化し、階間遷移を可能にする。
- 階段マス（`STAIRS_DOWN` / `STAIRS_UP`）を生成パイプラインに組み込み、上下対応はインデックス（floor index 差）のみで規定する。
- 階段進入時に既存 `ConfirmDialog` を再利用した確認ダイアログで階遷移を行い、UX を START 帰還と統一する。
- `EncounterCoordinator` を現在階に追従させ、`main.gd:207-208` の TODO を解消する。
- 探索率を全階合計で算出する素直な拡張に留める。

**Non-Goals:**
- フルマップオーバーレイの階タブ切替（別 change）。
- ボス階・暗闇・ワープ・落とし穴などの特殊ギミック。
- 階層降下スクロール等の新規アイテム。
- 既存セーブの後方互換マイグレーション（開発中であり、過去スロット移行は不要）。
- 各階での「直前位置の記憶」（プレイヤー位置は階段ペアで決定論的に決まる）。

## Decisions

### Decision 1: `DungeonData.floors: Array[FloorData]` 構造

```
DungeonData
  ├─ dungeon_name : String
  ├─ floors       : Array[FloorData]
  └─ player_state : PlayerState  # current_floor を保持

FloorData
  ├─ seed_value   : int
  ├─ map_size     : int
  ├─ wiz_map      : WizMap
  └─ explored_map : ExploredMap
```

**選定理由:** 階ごとに独立した `seed` / `map_size` / `wiz_map` / `explored_map` が必要。`PlayerState` は 1 つに集約し `current_floor` を追加することで、階間遷移を「位置 + 階の差し替え」というシンプルな操作にできる。

**代替案:**
- 各 `FloorData` に `last_position` を持たせる案（プレイヤーが階を離れた時の位置を記憶）→ 階段ペアで決定論的に位置が決まるため不要。過剰設計。
- `DungeonData` 自体に `current_floor` を持たせる案 → `PlayerState` に含めた方が「位置情報」として一貫し、`to_dict` 時の対称性も保てる。

### Decision 2: 階数決定 — サイズ連動でランダム

| size_category | 階数レンジ |
|---------------|------------|
| SMALL  (0)    | 2-4        |
| MEDIUM (1)    | 4-7        |
| LARGE  (2)    | 8-12       |

各階の `map_size` は既存の `SIZE_RANGES` 内で**階ごとに独立して**ランダム決定する。

**選定理由:** 「同じ大ダンジョンでも階構成は毎回違う」という個性を出せる。生成は `DungeonRegistry.create()` 1 回で全階一括実行する（遅延生成しない）。

### Decision 3: 各階のシード派生

```
floor[i].seed_value = base_seed + i * 0x9E3779B1   # 黄金比由来の散らし定数
```

または単純に `base_seed + i + 1`。乱数品質より**再現性**が重要。

**選定理由:** 同じダンジョン名で同じ `base_seed` を持つ DungeonData は、to_dict→from_dict 後も全階が同じ wiz_map に再生成される必要がある。各階のシードを決定論的に派生すれば、`floors[].seed` を保存するだけで全階を復元できる。

### Decision 4: 階段配置ルール

- 各階につき `STAIRS_DOWN` 最大 1 個、`STAIRS_UP` 最大 1 個を配置する。
- 1F: `START` + `STAIRS_DOWN`（GOAL マスは無し）
- 中間階: `STAIRS_UP` + `STAIRS_DOWN`
- 最深階: `STAIRS_UP` + `GOAL`（`STAIRS_DOWN` は無し）

**配置位置:**
- 既存の `place_start_and_goal` をベースに拡張する。
- 1F STAIRS_DOWN: 既存 GOAL 位置（START から BFS 最遠）にそのまま置く。
- 中間階 STAIRS_UP: いずれかの部屋中央（既存の START 配置ロジックを流用）。
- 中間階 STAIRS_DOWN: STAIRS_UP から BFS 最遠の位置（既存の GOAL 配置ロジックを流用）。
- 最深階 STAIRS_UP: 部屋中央。
- 最深階 GOAL: STAIRS_UP から BFS 最遠（既存ロジック流用）。

**選定理由:** 既存の「最遠点配置」ロジックは「マップを縦断する探索体験」を提供しており、これを階段マスにも適用すれば踏破感が保たれる。階段の上下座標を一致させない（自由配置）ため生成アルゴリズムの制約は最小。

### Decision 5: 階段ペアの紐付け — インデックス差のみ

各階に最大 1 個ずつしか階段マスを置かないため、階段ペアの対応は floor index 差で自明:
- `floor[i]` の `STAIRS_DOWN` を踏む → `floor[i+1]` の `STAIRS_UP` 座標へワープ
- `floor[i]` の `STAIRS_UP` を踏む → `floor[i-1]` の `STAIRS_DOWN` 座標へワープ

**選定理由:** メタデータ（pair_id 等）が不要で実装最小。複数ペアが必要になれば後続 change で拡張すればよい。

### Decision 6: 階段マス進入時の UX

既存 `ConfirmDialog` を再利用し、START 帰還ダイアログと同パターン:

| マス進入       | 文言                       | 「はい」確定後                              |
|----------------|----------------------------|---------------------------------------------|
| `START` (1F)   | 「地上に戻りますか?」       | 町に戻る（既存挙動を維持）                  |
| `STAIRS_DOWN`  | 「下の階に降りますか?」     | `current_floor += 1`、対応 `STAIRS_UP` へ移動、facing 保持 |
| `STAIRS_UP`    | 「上の階に戻りますか?」     | `current_floor -= 1`、対応 `STAIRS_DOWN` へ移動、facing 保持 |
| `GOAL` (最深)  | （MVP では反応なし）        | -                                           |

進入毎に毎回ダイアログを出す（既存 START 帰還と同パターン）。階遷移後は新しい階の wiz_map / explored_map に差し替えてレンダリング再構築。

**選定理由:** 既存 `ConfirmDialog` の再利用と既存の "毎回出す" 仕様で UX 統一。`DungeonScreen` は階段マス検出と遷移ロジックを 1 箇所に集約できる。

### Decision 7: エンカウンターテーブル切替

`EncounterCoordinator` は現在の階（1-based）に対応した `EncounterTableData` を `set_table()` で差し替える。階遷移のたびに `main.gd`（または `DungeonScreen` 経由のシグナル）が再セットする。

**フォールバック:**
```
要求階 N に対するテーブルがない場合:
  - 登録済みテーブルのうち最大の floor 番号のテーブルを使用
  - push_warning("No encounter table for floor N, using floor M") を出力
```

**選定理由:** 開発中のため `floor_2.tres` 以降を段階的に整備できる。本番では各階に対応テーブルを揃える前提。

### Decision 8: 探索率の全階合計

```gdscript
func get_exploration_rate() -> float:
    var total := 0
    var visited := 0
    for f in floors:
        total += f.map_size * f.map_size
        visited += f.explored_map.get_visited_count()
    return 0.0 if total == 0 else float(visited) / float(total)
```

**選定理由:** 既存の単一階セマンティクスの自然な拡張。階タブ別の表示は別 change で改善する。

### Decision 9: シリアライズ形式

```json
{
  "dungeon_name": "暗黒の迷宮",
  "floors": [
    {
      "seed_value": 42,
      "map_size": 16,
      "explored_map": {"visited": [[2,3], ...]}
    },
    {
      "seed_value": 12345678,
      "map_size": 18,
      "explored_map": {"visited": []}
    }
  ],
  "player_state": {
    "position": [5, 7],
    "facing": 0,
    "current_floor": 0
  }
}
```

`wiz_map` のセル情報は保存せず、各階の `seed_value` + `map_size` から再生成する（既存方針の踏襲）。

### Decision 10: テストデータの追加

最低限の動作確認のため `data/encounter_tables/floor_2.tres` を新規追加する。中身はやや強めのモンスターパターン（goblin 増量、新たに `kobold` 等が monsters に存在すれば追加）。`floor_3.tres` 以降はフォールバックで運用しても可。実装タスクで「最低 2 階分」を要件とする。

## Risks / Trade-offs

- **Risk:** `TileType` enum 拡張で既存の `match` 文や `TileType.FLOOR / START / GOAL` 直接比較箇所が新タイルを未処理になる → **Mitigation:** `tile_type.gd` 拡張時に `Grep` で全参照箇所を洗い出し、`STAIRS_DOWN/UP` を追加処理。`full_map_renderer` / `cell_mesh_builder` / `minimap_renderer` の表示は当面 START / GOAL と同等の見た目で代替可（見た目の差別化は別 change で改善）。
- **Risk:** 階遷移時に `EncounterCoordinator` の状態（cooldown、step count）をどう扱うか → **Mitigation:** 階遷移は「ワープ」扱いとして `step_taken` を発火しない。cooldown は階を跨いでも継続するが、これはむしろ「階段直後に強制エンカウント」を防ぐので望ましい挙動。
- **Risk:** `DungeonScreen.setup_from_data` が単一 wiz_map を前提にしている設計→ **Mitigation:** 現在階の wiz_map を `DungeonData` から都度取得する方式に変更。`_wiz_map` / `_explored_map` フィールドを保持しつつ、階遷移メソッドで差し替える。
- **Trade-off:** 各階のシードを派生式で決めるため、「特定階だけシードを変えて再生成する」ことは MVP では不可。後続 change で `floors[i].seed_value` を独立に保存する方式に変えれば対応可能。
- **Trade-off:** 階段マス自由配置のため、階段が部屋中央にあるか通路上にあるかは生成結果次第。極端に近接配置になる可能性は残るが、BFS 最遠ロジックで実質的に避けられる。
- **Trade-off:** `floor_3.tres` 以降が無くてもフォールバックで動くため、開発中は手抜きが進みやすい。タスクで「想定最大階分のテーブル整備」をフォローアップ項目として明記する。

## Migration Plan

開発中のためデータマイグレーションは不要。本 change のマージで:
1. 既存セーブ（単一階形式）はロード不能になる（許容）。
2. `DungeonRegistry` を新規生成すれば多階層が即座に有効化される。
3. 古い v1 セーブを誤ってロードした場合の振る舞いについて:
   - `DungeonData.from_dict` は `floors` キー欠落時に空配列を返し、その後の `floors[0]` 参照で実行時エラーとなる。
   - 開発中のため、旧セーブを意識的に削除する運用とし、`SaveManager` 側での明示的な version 拒否は実装しない。
   - 古いセーブが残っている場合は `%APPDATA%\Godot\app_userdata\DungeonMirundal2\saves\` を削除する。

## Open Questions

- 階段マスの 3D / ミニマップでの見た目をどこまで差別化するか → MVP では START / GOAL と同色で許容、別 change で改善余地あり。
- 最深階の `GOAL` マスを将来「クリアフラグ立て」に使うか → MVP では反応なし。将来のボス階機能で活用想定。
