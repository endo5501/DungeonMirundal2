## ADDED Requirements

### Requirement: セルとエッジの定義
各セルは4方向（北・東・南・西）のエッジを持ち、エッジの種類は WALL / OPEN / DOOR の3種類でなければならない。セルのタイルタイプは FLOOR / START / GOAL の3種類でなければならない。

#### Scenario: セルの初期状態
- **WHEN** 新しいセルを作成する
- **THEN** タイルタイプは FLOOR である
- **THEN** 4方向すべてのエッジが WALL である

#### Scenario: エッジの双方向同期
- **WHEN** セル(x,y)の東側エッジを OPEN に設定する
- **THEN** セル(x+1,y)の西側エッジも OPEN になる

### Requirement: マップの境界チェック
マップサイズは8以上を要求し、座標の境界チェックを行わなければならない。

#### Scenario: 最小サイズ未満でエラー
- **WHEN** size=7 でマップを作成しようとする
- **THEN** エラーが発生する

#### Scenario: 境界内の座標
- **WHEN** size=10 のマップで座標(0,0)から(9,9)を確認する
- **THEN** すべて境界内と判定される

#### Scenario: 境界外の座標
- **WHEN** size=10 のマップで座標(-1,0)や(10,0)を確認する
- **THEN** 境界外と判定される

### Requirement: 完全迷路生成（DFS）
深さ優先探索によりすべてのセルを訪問し、完全迷路（全セル連結のスパニングツリー）を生成しなければならない。

#### Scenario: 全セルが連結
- **WHEN** carve_perfect_maze を実行する
- **THEN** BFS探索で全セルに到達可能である

#### Scenario: スパニングツリー構造
- **WHEN** carve_perfect_maze を実行する
- **THEN** OPEN エッジの数は (size * size - 1) である（ツリーの辺数）

### Requirement: 部屋生成と配置
指定パラメータに基づいて矩形の部屋を配置し、部屋内部のエッジをすべて OPEN にしなければならない。部屋同士はマージン1以上離れていなければならない。

#### Scenario: 部屋の内部が開放される
- **WHEN** Rect(2,2,3,3)の部屋をcarveする
- **THEN** 部屋内部のセル間エッジがすべて OPEN になる

#### Scenario: 部屋が重ならない
- **WHEN** 複数の部屋を生成する
- **THEN** どの2つの部屋もマージン1以上離れている

#### Scenario: 部屋サイズの制約
- **WHEN** room_attempts回の試行で部屋を生成する
- **THEN** 各部屋のサイズはmin_room_size以上max_room_size以下である
- **THEN** 部屋はマップ端から1セル以上内側に配置される

### Requirement: ループ追加
完全迷路にランダムに壁を開放してループ（冗長経路）を追加しなければならない。

#### Scenario: 指定数のループ追加
- **WHEN** extra_links=3 で add_extra_links を実行する
- **THEN** 最大3箇所の壁が OPEN に変更される
- **THEN** 全体連結性は維持される

### Requirement: 部屋境界へのドア配置
部屋と通路の境界にあるOPENエッジを一定確率でDOORに変更しなければならない。

#### Scenario: ドアの配置条件
- **WHEN** add_doors_between_room_and_nonroom を実行する
- **THEN** 部屋内セルと部屋外セルの間の OPEN エッジのみがDOOR候補となる
- **THEN** 部屋内部のエッジはDOORにならない

### Requirement: 全体連結性の検証
BFS探索により、生成後のマップが全セル連結であることを検証しなければならない。

#### Scenario: 連結マップの検証
- **WHEN** 正常に生成されたマップで is_fully_connected を呼ぶ
- **THEN** true が返る

#### Scenario: BFSの到達距離
- **WHEN** 始点からBFSを実行する
- **THEN** 各セルへの最短距離が正しく計算される

### Requirement: 開始地点とゴールの配置
開始地点は部屋の中心付近に、ゴールは開始地点からBFS最遠のセルに配置しなければならない。

#### Scenario: 開始地点が部屋内
- **WHEN** 部屋が存在するマップで place_start_and_goal を実行する
- **THEN** START タイルがいずれかの部屋の中心に配置される

#### Scenario: ゴールが最遠
- **WHEN** place_start_and_goal を実行する
- **THEN** GOAL タイルは START からBFS距離が最大のセルに配置される

### Requirement: シード値による再現性
同じシード値で同じパラメータを指定した場合、同一のマップが生成されなければならない。

#### Scenario: 同一シードで同一結果
- **WHEN** seed=42, size=10 で2回生成する
- **THEN** 2つのマップの全セル・全エッジが一致する

#### Scenario: 異なるシードで異なる結果
- **WHEN** seed=42 と seed=99 で生成する
- **THEN** 2つのマップは異なる

### Requirement: 生成パイプライン統合
generate メソッドにより、全ステップ（迷路→部屋→ループ→ドア→連結検証→配置）を一括実行できなければならない。

#### Scenario: デフォルトパラメータでの生成
- **WHEN** size=20 でパラメータ未指定で generate を呼ぶ
- **THEN** 全体連結のマップが生成される
- **THEN** START と GOAL が1つずつ存在する

#### Scenario: カスタムパラメータでの生成
- **WHEN** min_room_size=2, max_room_size=5, extra_links=3 で generate を呼ぶ
- **THEN** 指定パラメータに従ったマップが生成される
- **THEN** 全体連結性が保たれる

### Requirement: 移動判定
指定方向への移動可否を判定できなければならない。OPEN または DOOR のエッジは通過可能、WALL は通過不可。

#### Scenario: 壁方向への移動不可
- **WHEN** エッジが WALL の方向に移動を試みる
- **THEN** 移動不可と判定される

#### Scenario: 開放方向への移動可能
- **WHEN** エッジが OPEN の方向に移動を試みる
- **THEN** 移動可能と判定される

#### Scenario: ドア方向への移動可能
- **WHEN** エッジが DOOR の方向に移動を試みる
- **THEN** 移動可能と判定される
