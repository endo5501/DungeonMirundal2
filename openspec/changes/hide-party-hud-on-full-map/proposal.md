## Why

Mキーで全画面マップ (`FullMapOverlay`) を開いた時、autoload の `PartyHud` (CanvasLayer) は最前面で描画されるため、画面下部に並ぶ6つのキャラクターパネル (174×240px × 6) がマップ下部を覆い、地図の詳細(プレイヤー位置・未踏破セル・通路の繋がり)が確認できなくなっている。フルマップは「探索状況を俯瞰するための機能」なので、表示中はマップ全体が見えるべきで、HUD は隠すのが妥当。

`FullMapOverlay` は既に `MinimapDisplay` を開閉時に隠す/戻す対称的なパターンを実装している (`full_map_overlay.gd:97-104`)。同じ DI パターンで `PartyHud` にも適用すれば、最小の変更で目的を達成できる。

## What Changes

- `FullMapOverlay.setup()` に `party_hud_layer: CanvasLayer = null` 引数を追加 (既存呼び出しを壊さないようデフォルト null)
- `FullMapOverlay.open()` で `_party_hud_layer.visible = false`、`close()` で `_party_hud_layer.visible = true`
- `DungeonScreen` の 2 箇所の `_full_map_overlay.setup(...)` 呼び出しに `PartyHud` (autoload) を末尾引数として渡す
- **BREAKING (spec)**: `party-hud-autoload` の「HUD remains visible during ESC menu and full-map overlays」要件のうち、**full-map overlay 部分のみ反転**(ESC menu 部分は据え置き)。フルマップ表示中は `PartyHud.visible` が `false` になる
- 新規テスト: `tests/dungeon/test_full_map_overlay.gd` に minimap visibility テストと対称な3テスト追加

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities
- `full-map-overlay`: フルマップ表示中はパーティHUD (CanvasLayer) も非表示にし、閉じた時に復帰する要件を追加。`setup()` のシグネチャ拡張も含む。
- `party-hud-autoload`: 「フルマップオーバーレイが HUD を隠さない」シナリオを反転させ、「フルマップオーバーレイ表示中は HUD が非表示になる」に変更。ESC メニューに対する HUD 据え置きの挙動は維持。

## Impact

- **Code**:
  - `src/dungeon_scene/full_map_overlay.gd`: フィールド追加、`setup()` シグネチャ拡張、`open()`/`close()` 拡張
  - `src/dungeon_scene/dungeon_screen.gd`: `setup()` 呼び出し 2 箇所 (line 82, 262) を更新
- **Tests**:
  - `tests/dungeon/test_full_map_overlay.gd`: party HUD stub の追加と新規 3 テスト
- **No runtime risk**: フルマップ表示中は `dungeon_screen.gd:118-119` で全移動入力がブロックされ、エンカウント発生不可。HUD 表示状態の保存/復帰は対称な open/close で完結する
- **Dependencies**: 影響なし
- **APIs**: `FullMapOverlay.setup()` の引数追加(後方互換: デフォルト値 null)
