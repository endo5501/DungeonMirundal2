## Why

画面サイズ調整後にパーティ HUD のレイアウトが破綻している。具体的には (1) LV 値が badge 枠 (32×18px) に収まらず見切れ、(2) HP/MP ラベルが 24px 枠内で `FONT_SIZE=21` のため見切れ、(3) HP/MP 数値テキスト (FONT_SIZE=21) が HP 行と MP 行の縦間隔 16px を超えて上下が被り、(4) `PANEL_WIDTH=240` に対し `PORTRAIT_WIDTH=170` で左右に 35px ずつの死んだ余白が生じ、結果として 6 枚のパネルが 3D ビューの中央領域を必要以上に塞ぎ、階段や宝箱などのオブジェクト視認を阻害している。視認性・可読性双方を一度に解消する。

## What Changes

- `PartyMemberPanel.PANEL_WIDTH` を 240 → **174** に縮小 (ポートレイト 170 + 左右フレーム余裕 2px×2)。これにより HUD 全体が約 400px 細くなり、3D ビュー中央が広く開く。
- `PartyMemberPanel` の HP/MP 行で使う body font size を 21 → **14** に縮小。これにより HP/MP の数値テキストが行間に収まり、上下の重なりが解消する。
- LV badge の `BADGE_FONT_SIZE` を 18 → **14**、badge 幅を 32 → **48** に拡張し、`LV.99` のような 2 桁レベルでも見切れない。
- HP/MP バーの `BAR_LEFT` を 32 → **26** に左寄せ調整 (新パネル幅 174 に整合)。`BAR_WIDTH=88` は据え置き。
- `PANEL_HEIGHT=240`、name badge フォント、status / stat-modifier アイコンサイズ、各種アニメーション・シグナル連携は **据え置き** (純粋なレイアウト調整に範囲を限定)。
- **BREAKING (内部仕様のみ)**: 既存仕様 §13 の "body font size SHALL be at least 21" と §14 の "`PANEL_WIDTH` SHALL be 240" を緩める/書き換える。

## Capabilities

### New Capabilities

(なし — 既存 capability の調整のみ)

### Modified Capabilities

- `party-display`: §13 の body font 下限を引き下げ (HP/MP 行に限り 14 まで許容)、§14 の `PANEL_WIDTH` 値を 174 に変更、LV badge のサイズ要件を明示する。

## Impact

- コード: `src/dungeon_scene/party_member_panel.gd` (定数群と `_draw_stat_bar` / `get_level_badge_rect` / `get_hp_bar_rect` / `get_mp_bar_rect` の座標計算)、`src/dungeon_scene/party_display.gd` (パネル幅変更に伴う `_layout_panels` の動作確認のみ — 数式は `PartyMemberPanel.PANEL_WIDTH` 参照のため自動追従)。
- テスト: `tests/` 配下で `PANEL_WIDTH=240` や rect 戻り値の絶対値に依存する既存テストが破綻する。新値に追従させる必要あり。
- 仕様: `openspec/specs/party-display/spec.md` の §13 / §14 をモディファイ、LV badge の新規要件を追加。
- ランタイム: ゲーム起動時の見た目のみ変化。セーブデータ・シグナル契約・コンバットロジックには影響なし。
- 依存: `party-hud-autoload` capability は signal hookup のみで visual rect には触れていないため影響なし。
