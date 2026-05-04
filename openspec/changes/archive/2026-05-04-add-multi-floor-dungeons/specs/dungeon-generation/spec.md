## ADDED Requirements

### Requirement: 階段タイルの定義
SHALL: `TileType` enum は `FLOOR / START / GOAL / STAIRS_DOWN / STAIRS_UP` の 5 種類を定義しなければならない。`STAIRS_DOWN` は下の階への階段マスを、`STAIRS_UP` は上の階への階段マスを表す。

#### Scenario: STAIRS_DOWN タイルが定義される
- **WHEN** `TileType.STAIRS_DOWN` を参照する
- **THEN** enum 値が定義されている

#### Scenario: STAIRS_UP タイルが定義される
- **WHEN** `TileType.STAIRS_UP` を参照する
- **THEN** enum 値が定義されている

### Requirement: 階段マスの配置ルール
SHALL: マップ生成時、階の役割（first / middle / last）に応じて以下の階段マスを配置しなければならない。各階につき `STAIRS_DOWN` は最大 1 個、`STAIRS_UP` は最大 1 個までである。

- **first 階（floor index = 0）**: `START` + `STAIRS_DOWN` を配置。`GOAL` は配置しない。
- **middle 階（0 < index < last）**: `STAIRS_UP` + `STAIRS_DOWN` を配置。`START` および `GOAL` は配置しない。
- **last 階（floor index = floors.size() - 1）**: `STAIRS_UP` + `GOAL` を配置。`STAIRS_DOWN` は配置しない。
- **floors.size() == 1 の特例**: `START` + `GOAL` のみ（既存挙動と同等）。

各階段マスの座標は次のルールで決定する:
- 1 つ目のマス（first 階の `START`、middle/last 階の `STAIRS_UP`）は、いずれかの部屋の中央付近に配置する。
- 2 つ目のマス（first/middle 階の `STAIRS_DOWN`、last 階の `GOAL`）は、1 つ目のマスから BFS 距離が最遠のセルに配置する。

#### Scenario: first 階に START と STAIRS_DOWN が配置される
- **WHEN** floors.size() == 3、floor index 0 のマップ生成を行う
- **THEN** マップ上に `START` タイルと `STAIRS_DOWN` タイルが各 1 個配置され、`GOAL` および `STAIRS_UP` は存在しない

#### Scenario: middle 階に STAIRS_UP と STAIRS_DOWN が配置される
- **WHEN** floors.size() == 3、floor index 1 のマップ生成を行う
- **THEN** マップ上に `STAIRS_UP` タイルと `STAIRS_DOWN` タイルが各 1 個配置され、`START` および `GOAL` は存在しない

#### Scenario: last 階に STAIRS_UP と GOAL が配置される
- **WHEN** floors.size() == 3、floor index 2 のマップ生成を行う
- **THEN** マップ上に `STAIRS_UP` タイルと `GOAL` タイルが各 1 個配置され、`START` および `STAIRS_DOWN` は存在しない

#### Scenario: 単一階ダンジョンは START と GOAL のみ
- **WHEN** floors.size() == 1 のマップ生成を行う
- **THEN** マップ上に `START` と `GOAL` が各 1 個配置され、`STAIRS_UP` および `STAIRS_DOWN` は存在しない

#### Scenario: 階段マスは BFS 最遠点に配置される
- **WHEN** middle 階で `STAIRS_UP` が部屋中央(x, y) に配置されている
- **THEN** `STAIRS_DOWN` は BFS で計算した(x, y) からの最遠セルに配置される

## MODIFIED Requirements

### Requirement: セルとエッジの定義
SHALL: 各セルは4方向（北・東・南・西）のエッジを持ち、エッジの種類は WALL / OPEN / DOOR の3種類でなければならない。セルのタイルタイプは FLOOR / START / GOAL / STAIRS_DOWN / STAIRS_UP の5種類でなければならない。

#### Scenario: セルの初期状態
- **WHEN** 新しいセルを作成する
- **THEN** タイルタイプは FLOOR である
- **THEN** 4方向すべてのエッジが WALL である

#### Scenario: エッジの双方向同期
- **WHEN** セル(x,y)の東側エッジを OPEN に設定する
- **THEN** セル(x+1,y)の西側エッジも OPEN になる

### Requirement: 開始地点とゴールの配置
SHALL: マップが単一階（floors.size() == 1 相当）として生成される場合、開始地点は部屋の中心付近に、ゴールは開始地点からBFS最遠のセルに配置しなければならない。多階層生成では「階段マスの配置ルール」要件で規定されたタイルを配置する。

#### Scenario: 開始地点が部屋内
- **WHEN** 部屋が存在するマップで単一階用の place_start_and_goal を実行する
- **THEN** START タイルがいずれかの部屋の中心に配置される

#### Scenario: ゴールが最遠
- **WHEN** 単一階用の place_start_and_goal を実行する
- **THEN** GOAL タイルは START からBFS距離が最大のセルに配置される

### Requirement: 生成パイプライン統合
SHALL: generate メソッドにより、全ステップ（迷路→部屋→ループ→ドア→連結検証→タイル配置）を一括実行できなければならない。タイル配置ステップは、階の役割（first / middle / last / 単一）に応じて START / GOAL / STAIRS_UP / STAIRS_DOWN を配置する。

#### Scenario: デフォルトパラメータでの単一階生成
- **WHEN** size=20 でパラメータ未指定で単一階向けに generate を呼ぶ
- **THEN** 全体連結のマップが生成される
- **THEN** START と GOAL が1つずつ存在する

#### Scenario: カスタムパラメータでの単一階生成
- **WHEN** min_room_size=2, max_room_size=5, extra_links=3 で単一階向けに generate を呼ぶ
- **THEN** 指定パラメータに従ったマップが生成される
- **THEN** 全体連結性が保たれる

#### Scenario: 中間階としての多階層生成
- **WHEN** size=20 で role=middle を指定して generate を呼ぶ
- **THEN** 全体連結のマップが生成される
- **THEN** STAIRS_UP と STAIRS_DOWN が各1個存在し、START と GOAL は存在しない
