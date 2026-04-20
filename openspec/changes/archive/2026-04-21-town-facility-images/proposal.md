## Why

現在の町画面 (TownScreen) では、右カラムのイラスト領域が単色の ColorRect と施設名ラベルのプレースホルダ表示にとどまっている。施設の雰囲気を伝えるイラストを用意できたため、プレースホルダから本番イラスト表示へ差し替え、プレイヤーが町にいる没入感と施設の識別性を高める。

## What Changes

- `assets/images/facilities/` に 4 施設のイラスト (guild.png / shop.png / church.png / dungeon.png) を配置 (元画像 1536×1024・3-4MB をリサイズ＋再圧縮して軽量化)
- TownScreen 右カラムのイラスト領域を `ColorRect` 単色背景から `TextureRect` による施設画像表示に差し替え
- 施設名ラベルは画像の上に半透明背景付きで残し、可読性を確保
- カーソル移動時に表示画像とラベルが切り替わる挙動は維持
- 画像ロード失敗時のフォールバックとして従来の `FACILITY_COLORS` を保持
- **BREAKING (spec-level)**: town-screen spec の "Illustration area updates on cursor movement" 要件を ColorRect ベースから TextureRect ベースに更新

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities
- `town-screen`: 右カラムのイラスト領域の描画方式を ColorRect + Label から TextureRect + 画像 + オーバーレイ Label に変更。カーソル移動で画像が切り替わる要件を追加。

## Impact

- 追加: `assets/images/facilities/guild.png`, `shop.png`, `church.png`, `dungeon.png` (リサイズ・再圧縮版)
- 変更: `src/town_scene/town_screen.gd` (右カラム構築・更新ロジック)
- 変更: `openspec/specs/town-screen/spec.md` (要件更新)
- 追加: `tests/town/test_town_screen.gd` (画像切替の挙動テスト)
- 一時ファイル: `tmp/*.png` は作業後にリポジトリから削除 (元画像はリサイズ後の最適化済み版のみ残す)
- 依存: Godot 標準の Texture2D / ImageTexture のみ使用。追加の外部依存なし
