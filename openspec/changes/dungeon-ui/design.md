## Context

現在の DungeonScreen は SubViewportContainer をフルスクリーンで配置し、3D ダンジョンビューのみを表示している。キーボード入力で移動・回転ができるが、UI 要素は一切ない。

本変更では、3D ビューのフルスクリーン表示を維持したまま、ミニマップとパーティ表示枠を半透明オーバーレイとして追加する。

既存のコード構成:
- `DungeonScreen` (Control): 画面全体を管理、入力処理
- `DungeonScene` (Node3D): 3D 描画、カメラ管理
- `DungeonView`: 可視セル計算（RefCounted）
- `PlayerState`: プレイヤー位置・向き管理（RefCounted）
- `WizMap`: ダンジョンデータ、エッジベースの壁管理（RefCounted）

## Goals / Non-Goals

**Goals:**
- 3D ビューを損なわずにミニマップとパーティ情報をオーバーレイ表示する
- エッジベースの WizMap 構造を正しくミニマップに反映する
- 探索済みセルの管理を独立クラスとして実装し、関心を分離する
- パーティ表示枠を仮データで表示し、将来の実データ差し替えに備える

**Non-Goals:**
- ミニマップのズーム/スクロール
- パーティの実データ連携
- 戦闘 UI やメニュー UI

## Decisions

### 1. レイアウト方式: フルスクリーン 3D + オーバーレイ（レイアウト A）

3D ビューを分割して縮小する方式（レイアウト B）も検討したが、ダンジョンの迫力・没入感を優先し、3D をフルスクリーンのまま UI をオーバーレイする方式を採用する。

**代替案**: レイアウト B（3D ビュー上部 60%、パーティ枠下部 40%）→ 3D 表示が狭くなりすぎるため不採用。

### 2. ミニマップ描画方式: Image + TextureRect（プレイヤー中心ビュー）

プレイヤーを中心として半径 3 セル（7x7 セル範囲）を Image に描画し、TextureRect で表示する。マップ全域は表示せず、常にプレイヤー周辺のみ。

```
Image サイズ: 15 x 15 px（固定）
VIEW_RADIUS = 3, VIEW_SIZE = 7

ビュー内セル(vx, vy) のピクセルマッピング:
  床   → pixel (2*vx+1, 2*vy+1)
  北壁 → pixel (2*vx+1, 2*vy)
  南壁 → pixel (2*vx+1, 2*vy+2)
  西壁 → pixel (2*vx,   2*vy+1)
  東壁 → pixel (2*vx+2, 2*vy+1)
  角   → pixel (2*vx,   2*vy)

プレイヤーは常に中心 pixel (7, 7) に描画。
マップ範囲外のセルは背景色のまま。
```

表示時は `TextureRect.expand_mode` で拡大し、`texture_filter = NEAREST` でピクセルのシャープさを維持する。

**代替案**:
- マップ全域表示 → マップが大きくなるとミニマップが広くなりすぎ、情報が散漫になるため不採用
- カスタム `_draw()`: 柔軟だが大量セルでの再描画コストが高い
- TileMap: Godot 組み込みだがエッジベース構造とのマッピングが煩雑

### 3. 探索済み管理: ExploredMap（独立 RefCounted クラス）

訪れたセルだけでなく、`DungeonView.get_visible_cells()` で見えたセルも探索済みとして記録する。ExploredMap 自体は壁情報を持たず、「どのセルが探索済みか」のみを管理する。ミニマップ描画時に WizMap からエッジ情報を取得する。

**代替案**: PlayerState に探索履歴を持たせる → 責務が混在するため不採用。

### 4. パーティ表示枠: 仮データの Control ベース UI

画面下部に前列 3 名・後列 3 名の 6 枠を配置する。各枠はプレースホルダー画像、名前、LV、HP、MP を表示する。仮データは固定値で定義し、将来 `character-and-party-system` で実データに差し替える。

```
1枠の構成:
┌─────────────────────────┐
│ ┌──────┐                │
│ │      │  名前           │
│ │ IMG  │  LV: 5         │
│ │      │  HP: 120/150   │
│ └──────┘  MP:  30/ 45   │
└─────────────────────────┘
```

### 5. ノードツリー構成

```
DungeonScreen (Control, FULL_RECT)
├── SubViewportContainer (FULL_RECT)  ← 既存、3Dビュー
│   └── SubViewport
│       └── DungeonScene (Node3D)
├── MinimapDisplay (Control)          ← 新規、右上オーバーレイ
│   └── TextureRect                   ← Image ベースのマップ描画
└── PartyDisplay (Control)            ← 新規、下部オーバーレイ
    ├── PartyMemberPanel x3 (前列)
    └── PartyMemberPanel x3 (後列)
```

### 6. 更新フロー

```
移動/回転イベント:
  1. PlayerState 更新
  2. DungeonView.get_visible_cells() で可視セル取得
  3. ExploredMap.mark_visible(visible_cells) で探索記録更新
  4. DungeonScene.refresh()   ← 3D 再描画
  5. MinimapDisplay.refresh() ← ミニマップ再描画
```

## Risks / Trade-offs

- **半透明 UI の視認性**: 3D ビューの色味によってはミニマップやパーティ枠が見づらくなる可能性がある → 背景に半透明の暗色パネルを敷いて対処
- **ミニマップのスケーリング**: 15x15 ピクセルの Image を拡大表示するため、NEAREST フィルタが必須。拡大率によってはジャギーが目立つ → 表示サイズ 140px 程度に調整
- **パーティ枠の仮データ管理**: 仮データをハードコードすると差し替え時の変更箇所が散らばる → パーティデータの構造体を定義し、仮データを一箇所にまとめる
