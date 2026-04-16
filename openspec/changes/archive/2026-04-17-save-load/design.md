## Context

現在のゲームはセーブ/ロード機能を持たず、ゲームを終了すると全データが失われる。タイトル画面の「前回から」「ロード」はdisabled状態で、ESCメニュー（esc-menu changeで実装予定）の「ゲームを保存」「ゲームをロード」もdisabled状態で配置される。

ゲーム状態は `GameState` Autoloadが一元管理しており、`Guild`（キャラクター・パーティ）と `DungeonRegistry`（ダンジョン一覧）の2つの主要オブジェクトで構成される。全データクラスは `RefCounted` ベースであり、Godotの `Resource` シリアライズは使えない。

WizMap（ダンジョンマップ）は `seed_value` から決定論的に再生成可能であることが確認されており、マップ全体をシリアライズする必要はない。

## Goals / Non-Goals

**Goals:**
- ゲーム状態をJSON形式で永続化し、アプリ再起動後も復元可能にする
- 町・ダンジョンどちらの画面からでもセーブ可能にする
- 自由に作成可能なセーブスロットで複数の進行状態を管理できる
- タイトル画面の「前回から」で最後のセーブデータを即座にロードできる
- ESCメニューからのセーブ/ロード操作を提供する

**Non-Goals:**
- オートセーブ機能
- セーブデータの暗号化・改竄防止
- セーブデータのクラウド同期
- アイテム・装備データのシリアライズ（items-and-economy changeで対応時に拡張）

## Decisions

### 1. シリアライズ方式: to_dict() / from_dict() パターン

各データクラスに `to_dict() -> Dictionary` と `static func from_dict(data: Dictionary)` メソッドを追加する。GameState全体を1つのDictionaryツリーに変換し、`JSON.stringify()` でファイルに書き出す。

```
GameState.to_save_dict()
├── guild.to_dict()
│   ├── character.to_dict()  × N
│   │   ├── race_id: resource_pathからファイル名抽出
│   │   └── job_id: resource_pathからファイル名抽出
│   ├── front_row: characterのインデックス配列
│   └── back_row: characterのインデックス配列
└── dungeon_registry.to_dict()
    └── dungeon_data.to_dict()  × N
        ├── seed_value, map_size (WizMap再生成用)
        ├── explored_map.to_dict() → visited座標の配列
        └── player_state.to_dict() → position, facing
```

**代替案:**
- Godot Resource (.tres/.res) → RefCountedベースのクラスには適用不可
- var_to_bytes → バイナリ形式でデバッグ困難、バージョニングが困難
- ConfigFile → 複雑なネスト構造の表現に不向き

### 2. race/jobの参照方式: ファイル名ID

セーブデータにはrace/jobの `resource_path` からファイル名部分を抽出してIDとして保存する。ロード時は `"res://data/races/" + race_id + ".tres"` で復元する。

```gdscript
# セーブ時
var race_id = character.race.resource_path.get_file().get_basename()  # → "human"

# ロード時
var race = load("res://data/races/" + race_id + ".tres") as RaceData
```

RaceData/JobDataにIDフィールドを追加する必要がなく、既存の.tresファイルとDataLoaderに変更不要。

**代替案:**
- RaceData/JobDataにID exportフィールド追加 → 全.tresファイルの更新が必要で過剰
- resource_pathをそのまま保存 → パス変更に弱い

### 3. WizMap保存方式: seedのみ保存 + 再生成

WizMapの生成は決定論的であるため、`seed_value` と `map_size` のみを保存する。ロード時に `WizMap.generate()` で同一のマップを再生成し、その上に `ExploredMap` と `PlayerState` を復元する。

マップ全体のセルデータを保存する方式と比較して、セーブファイルサイズを大幅に削減できる（30×30マップで約3600セル分のデータが不要）。

### 4. セーブファイル管理: SaveManagerクラス

`SaveManager` を `RefCounted` クラスとして実装する。GameStateのAutoloadに保持させるか、独立したAutoloadとするかは以下の判断による:

**GameState内に保持する方式を採用。** SaveManagerはGameStateのデータを読み書きするため、GameStateと密接に関連する。独立Autoloadにするほどの独立性はない。

```
GameState (Autoload)
├── guild: Guild
├── dungeon_registry: DungeonRegistry
├── save_manager: SaveManager  ← 新規追加
└── game_location: String      ← 新規追加 ("title" / "town" / "dungeon")
```

SaveManagerの責務:
- `save(slot_number: int)` → GameStateからDictionary構築 → JSON書き出し
- `load(slot_number: int)` → JSON読み込み → GameStateに復元
- `list_saves() -> Array[Dictionary]` → 全セーブファイルのメタ情報一覧
- `get_last_slot() -> int` → last_slot.txtから最終スロット番号取得
- `get_next_slot_number() -> int` → 次の連番を算出
- `delete_save(slot_number: int)` → セーブファイル削除

### 5. セーブファイル形式とディレクトリ構造

```
user://saves/
  save_001.json
  save_002.json
  ...
  last_slot.txt    ← "2" のようにスロット番号のみ
```

JSONファイルの最上位構造:
```json
{
  "version": 1,
  "last_saved": "2026-04-16T14:30:00",
  "game_location": "dungeon",
  "current_dungeon_index": 0,
  "guild": { ... },
  "dungeons": [ ... ]
}
```

メタ情報（ロード画面での一覧表示用）はJSONファイル内のトップレベルフィールドから取得する。一覧表示時に全ファイルをパースする必要があるが、セーブ数が現実的な範囲（数十件）では問題ない。

### 6. game_locationの管理

セーブ時にプレイヤーがどの画面にいるかを記録するため、`GameState` に `game_location` プロパティを追加する。main.gdが画面遷移時に更新する。

| game_location | 復元先 |
|---|---|
| `"town"` | 町画面を表示 |
| `"dungeon"` | current_dungeon_indexのダンジョン画面を表示 |

`"title"` 状態ではセーブ不可。

### 7. ロード後の画面復元フロー

ロードはmain.gdが実行する。SaveManagerからデータを復元した後、`game_location` に応じて適切な画面を表示する。

```
main.gd._load_game(slot_number)
  │
  ├── save_manager.load(slot_number)
  │     → GameState.guild, dungeon_registry を復元
  │     → GameState.game_location を復元
  │
  ├── game_location == "town"
  │     → _show_town_screen()
  │
  └── game_location == "dungeon"
        → dungeon_data = dungeon_registry.get_dungeon(current_dungeon_index)
        → dungeon_data.regenerate_map()  ← seedからWizMap再生成
        → _show_dungeon_screen(dungeon_data)
```

### 8. セーブ/ロード画面UI: ESCメニューのサブビューとして実装

セーブ画面とロード画面はESCメニューの拡張として実装する。ESCメニューの「ゲームを保存」「ゲームをロード」を有効化し、選択時にサブビューを表示する。

タイトル画面の「ロード」もロード画面を使用するが、この場合はESCメニュー経由ではなく、main.gdが直接ロード画面を表示する。ロード画面コンポーネントはESCメニューとタイトル画面の両方から利用可能な独立した画面クラスとして実装する。

セーブ画面のみESCメニューのサブビューとして実装し、ロード画面はタイトル画面からも利用するため独立画面とする。

### 9. タイトル画面の「前回から」

`last_slot.txt` に記録された最終スロット番号のセーブファイルを直接ロードする。ファイルが存在しない場合はエラーメッセージを表示して何もしない。

タイトル画面表示時に `save_manager.get_last_slot()` を確認し、有効なセーブが存在する場合のみ「前回から」を有効化する。同様に、セーブファイルが1件以上存在する場合のみ「ロード」を有効化する。

## Risks / Trade-offs

- **セーブデータのバージョニング** → versionフィールドで管理。現時点ではversion 1のみ。将来のマイグレーションはversion番号に応じた変換関数で対応予定。version不一致時はロードを拒否するのではなく、可能な限りマイグレーションを試みる方針。
- **ダンジョン内セーブからの復元整合性** → WizMap再生成後にExploredMapとPlayerStateを適用する際、座標がマップ範囲外にならないことを検証する。不整合時は入口位置にフォールバック。
- **一覧表示時の全ファイルパース** → セーブ数が数百件を超えると遅くなる可能性があるが、現実的な使用範囲では問題ない。将来必要に応じてメタ情報のインデックスファイルを導入可能。
- **アイテム・装備追加時の拡張** → to_dict/from_dictパターンにより、Characterクラスにフィールド追加 + シリアライズ対応で済む。from_dictでは未知のフィールドを無視し、不足フィールドにはデフォルト値を使用する方針で後方互換性を確保。
