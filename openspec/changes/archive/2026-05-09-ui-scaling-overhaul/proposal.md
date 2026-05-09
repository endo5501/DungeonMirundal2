## Why

現在 `project.godot` に `[display]` セクションが存在せず、Godot のデフォルト `stretch_mode = disabled` で動作している。このため、ウィンドウをリサイズしてもフォント・スプライト・各 UI パネル内部の要素はピクセル等倍のまま据え置かれ、ウィンドウだけが大きくなって UI が相対的に小さく読みづらくなる。加えて、リサイズ時に `DungeonScreen` 内の SubViewport が再描画されず、ダンジョン3D 描画が黒く消失するバグがある。

本変更は、ウィンドウリサイズに対して UI 全体が均一にスケールし、かつデフォルト起動時にも従来比で読みやすいフォントサイズを採用するための、配置基盤と関連定数を整える。

## What Changes

- `project.godot` に `[display]` セクションを追加:
  - `viewport_width=1600`, `viewport_height=900` (設計キャンバス = デフォルト起動サイズ)
  - `stretch/mode="canvas_items"` で全 Control を均一スケール
  - `stretch/aspect="expand"` でワイドモニターでも歪まず anchor が比例配置される
- HUD 定数の bump:
  - フォントサイズ全般を 1.5× (例: 14→21, 16→24, 18→27, 20→30, 22→33, 12→18)
  - モンスター戦闘画像を 1.5× (`DESIRED_VISUAL_SIZE` (180,144)→(270,216), `VISUAL_GAP` 28→42)
  - パーティパネル枠を 1.33× (`PANEL_WIDTH` 180→240, `PANEL_HEIGHT` 168→224) ※6 パネル並びの幅制約のため bump 倍率を控えめに
  - ポートレートを 1.33× (`PORTRAIT_WIDTH` 128→170, `PORTRAIT_HEIGHT` 104→138)
  - アイコン・余白を 1.33× (`STATUS_ICON_SIZE` 16→21, `MARGIN` 8→11, `LABEL_AREA_HEIGHT` 26→35, `LABEL_BOX_WIDTH` 200→266)
- `DungeonScreen` のリサイズ対応: ウィンドウサイズ変更時に SubViewport の `render_target_update_mode = UPDATE_ONCE` を再トリガーし、ダンジョン3D 描画が再構築されるようにする
- 関連テストの更新: golden text や rect 計算系テストの期待値を新定数に合わせて見直し

## Capabilities

### New Capabilities
- (なし)

### Modified Capabilities
- `project-setup`: `[display]` セクション (viewport size, stretch mode, aspect) を要件として明示する
- `dungeon-3d-rendering`: ウィンドウリサイズ時に SubViewport が再描画されるという要件を追加
- `party-display`: `PANEL_WIDTH = 180` 固定要件と `body font size < 20` 要件、および `PANEL_HEIGHT > 130` 要件を新しい定数 (1.33×〜1.5× bump 後の値) に更新

## Impact

- 設定ファイル: `project.godot`
- 描画ロジック: `src/dungeon_scene/dungeon_screen.gd` (SubViewport 再描画)
- HUD 定数: `src/dungeon_scene/party_member_panel.gd`, `src/dungeon_scene/party_display.gd`, `src/dungeon_scene/combat/*.gd` (各種 font_size, パネルサイズ定数)
- テスト: golden text や rect 計算で具体的な数値を期待しているテストは新定数に合わせて更新が必要
- ユーザー体験: デフォルト起動ウィンドウが現状(~1146×768)より大きく(1600×900)なる。リサイズ時の挙動が変わるため、操作中のウィンドウ操作で UI が動的に拡縮するようになる
- ターゲット: macOS / Windows デスクトップ。Retina/HiDPI ディスプレイでも論理解像度ベースで自然にスケールする
