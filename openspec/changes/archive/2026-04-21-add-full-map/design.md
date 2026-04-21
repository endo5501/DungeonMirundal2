## Context

ダンジョン画面 (`DungeonScreen`) は現在、SubViewport 内の 3D シーン (`DungeonScene`) と右上の `MinimapDisplay` (140x140, 7x7セル範囲) で構成される。`MinimapDisplay` は `MinimapRenderer` (RefCounted) が生成する 29x29 px の Image を表示する。

ダンジョンのフロアサイズは `WizMap.map_size` で可変 (最小 8、現在のデフォルト生成は数十セル)。階層機能はまだ無く、`DungeonData` は `wiz_map` を 1 個保持するのみ。タイル種別は `TileType.{FLOOR, START, GOAL}` の 3 種類、エッジ種別は `EdgeType.{WALL, OPEN, DOOR}` の 3 種類。`ExploredMap` が訪問済みセルを管理する。

入力は `DungeonScreen._unhandled_input` で処理され、`_encounter_active` / `_showing_return_dialog` のフラグで早期リターンするパターンが既にある。ESC キーは `main.gd._unhandled_input` で吸い上げて ESCメニューを開くが、`set_input_as_handled()` を子画面側で呼ぶことで抑止できる (帰還ダイアログがこのパターンを使う)。

`encounter-overlay` / `combat-overlay` / `esc-menu-overlay` といったオーバーレイ機構は既に複数存在し、半透明背景パネル + フルレクト Control の構成が共通パターンになっている。

## Goals / Non-Goals

**Goals:**
- 既存のミニマップ実装を変更せず、独立した全体マップ機能を追加する
- ミニマップとは別の `FullMapRenderer` を新設し、責務を分離する
- 既存のオーバーレイパターン (半透明背景 + フルレクト Control + 入力消費) に倣って `FullMapOverlay` を作る
- 入力ハンドリングは既存の `_encounter_active` / `_showing_return_dialog` と同列の表示中フラグで早期リターンする
- 探索済みセルのみ可視 (Wizardry的な手書きマップ感覚と既存ミニマップの一貫性を保つ)

**Non-Goals:**
- ミニマップ自体の挙動・見た目の変更 (`MinimapRenderer` / `MinimapDisplay` は手を入れない)
- 階段・宝箱・特殊タイルの新規導入 (本変更時点では `TileType.GOAL` までのみ。将来 TileType が増えたら描画追加で対応)
- 複数階層対応 (現状単一フロアのまま、将来の階層追加で `階層番号` 表示を足す余地を残す)
- マップのスクロール / ズーム操作 (常に画面フィット、操作はトグル開閉のみ)
- セーブデータ形式の変更 (描画専用機能なので保存対象なし)

## Decisions

### Decision 1: ミニマップを汎化せず別レンダラを新設する (B2)
**選択**: `FullMapRenderer` を独立した RefCounted として新設する。`MinimapRenderer` の継承や VIEW_RADIUS 可変化はしない。

**理由**:
- ミニマップは「中心固定の小さな線画 (1セル 3px)」、全体マップは「フロア全体を画面いっぱいに自動フィット (1セル 4-N px 動的計算)」と要件が大きく異なる
- ミニマップの 7x7 範囲制約・コーナーピラー描画ロジックは全体マップでは不要
- 共通化を狙うとレンダラ基底クラスを抽出することになり、現時点では 2 種類しか居ないため過剰設計
- 将来 3 種類目 (例: 探索率ヒートマップ) が出てきた段階で再考すれば良い

**代替案**: `MinimapRenderer` の VIEW_RADIUS をパラメータ化して全体マップ呼び出しを兼ねる → 描画ロジックの分岐が増えて読みづらくなるため不採用。

### Decision 2: 自動フィットのセルピクセル計算
**選択**: `cell_px = max(MIN_CELL_PX, floor(min(target_w, target_h) / map_size))`。`MIN_CELL_PX = 4`。

**理由**:
- マップサイズが画面より大きい状況は現状想定外 (map_size 数十、画面 1000+ px) だが、保険として最低 4px を保証してマーカーが潰れないようにする
- 整数ピクセルにすることで Image 描画時の補間ぼやけを防ぐ
- 縦横の小さい方を基準にすることで正方形マップが画面に収まる

**代替案**:
- 浮動小数のセルサイズで埋める → ImageTexture 上ではドット感が出ない方が良いが、ピクセルアートとの整合と単純さを優先
- 固定セルサイズ + スクロール → 操作が増えて面倒、要件 E1 (全画面フィット) 違反

### Decision 3: オーバーレイは Control + add_child パターン
**選択**: `FullMapOverlay extends Control` を `DungeonScreen` の子として常に存在させ、`visible` プロパティで開閉する。CanvasLayer は使わない。

**理由**:
- `EncounterOverlay` は CanvasLayer (戦闘 UI 全体差し替え) だが、本機能はダンジョン画面の上に重ねるだけで十分
- `DungeonScreen` の同階層に置くことで、ESC 入力消費もシンプル (オーバーレイ自身が `set_input_as_handled()`)
- 既存の `MinimapDisplay` / `PartyDisplay` と同じ親階層になるため対称的

**代替案**: 別シーンに遷移 (C2) → 3D シーンの再生成コストが発生し、シーン遷移管理が複雑になるため不採用。

### Decision 4: m キーは DungeonScreen が処理 (オーバーレイ自体は m を見ない)
**選択**: `DungeonScreen._unhandled_input` で m キー押下を検出し、`FullMapOverlay.toggle()` を呼ぶ。オーバーレイ側は ESC のみ処理する。

**理由**:
- `_encounter_active` / `_showing_return_dialog` といった抑止条件は `DungeonScreen` が一元管理しているため、m キーの抑止判定もここに置くのが自然
- オーバーレイ側で m を処理してしまうと、表示状態によって m が DungeonScreen まで届いたり届かなかったりして抑止判定が分散する
- 既存の同パターン (帰還ダイアログ表示中の上下キー処理) に倣う

### Decision 5: 表示中の入力ロックは「フラグ + 早期リターン」
**選択**: `DungeonScreen` に `_full_map_visible: bool` を追加し、`_unhandled_input` の冒頭で `_encounter_active` / `_showing_return_dialog` と同列にチェックする。

**理由**:
- 既存パターンと完全一致するため学習コストが低い
- 移動入力 (KEY_UP/W/DOWN/S/LEFT/A/RIGHT/D) は match に到達しないので自然にロックされる
- m キー再押下と ESC のみ表示中も処理する (これらは早期リターンの後で個別に分岐)

### Decision 6: ミニマップ可視性はオーバーレイが直接操作
**選択**: `FullMapOverlay.open()` 内で `_minimap_display.visible = false`、`close()` 内で `true` に戻す。`DungeonScreen` がセットアップ時に MinimapDisplay の参照をオーバーレイに渡す。

**理由**:
- 「全体マップ表示中はミニマップを隠す」は本機能固有の振る舞いなので、オーバーレイの責務として閉じる
- DungeonScreen 側にロジックを書くと、複数のオーバーレイが将来増えた時に責務が分散する

**代替案**: シグナル (`overlay_opened` / `overlay_closed`) で疎結合にする → オーバーレイが 1 つしか無い現時点ではオーバーキル。シグナルは必要になった時点で導入。

### Decision 7: HUD 要素は Label を直接配置
**選択**: ダンジョン名 (上部中央) / 座標 (下部左) / 探索率 (下部右) を `Label` で固定配置する。

**理由**:
- 値は `DungeonData.dungeon_name`、`PlayerState.position`、`DungeonData.get_exploration_rate()` から直接取得できる
- 既存の `party_member_panel.gd` 等と同じスタイルで Label の theme_font_size_override を使う
- 表示要素が 3 つしか無いのでコンテナ階層は最小限

### Decision 8: GOAL マーカーは START と異なる色で描画
**選択**: `MinimapRenderer` で使われる `COLOR_START` (黄系) と区別するため、GOAL は別色 (例: 赤系) を `FullMapRenderer` 内に独立定数として定義する。

**理由**:
- `MinimapRenderer` は START のみ描画していて GOAL は対応していない (現状ミニマップに GOAL は出ていない)
- `FullMapRenderer` でも `MinimapRenderer.COLOR_START` を再利用すると依存方向が好ましくないので、独立した定数を持つ

## Risks / Trade-offs

- **[巨大マップでの描画コスト]** 現状 map_size は数十セルで `Image.set_pixel()` 走査も問題ないが、将来 100+ セルになると描画が重くなる可能性 → 開閉時のみ再描画する設計 (毎フレームではない) で十分軽い。必要なら後でキャッシュ追加。
- **[ミニマップ可視性のリーク]** `FullMapOverlay.close()` を呼び忘れるとミニマップが隠れたまま → ダンジョン画面遷移時 (帰還等) は DungeonScreen ごと破棄されるため次回 setup で再生成される。リスク小。
- **[m キーバインドの衝突]** 将来別機能で m キーが必要になった場合 → 本機能が m を恒久的に占有することを README なりキー設定規約に記す必要があるが、本変更スコープ外。
- **[GOAL タイルの可視化前例なし]** ミニマップに GOAL が出ていなかったため、初めて GOAL がプレイヤーに見える機能になる → 仕様上は意図通り (探索済みでないと見えないので、GOAL を発見した時点で初めて表示される)。
- **[トグル中の二重押し]** m キー押下イベントが echo を含む可能性 → 既存パターンと同様 `event.echo` を弾く。
