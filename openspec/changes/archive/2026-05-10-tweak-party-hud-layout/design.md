## Context

`PartyMemberPanel` (および親コンテナ `PartyDisplay`) は、ダンジョン画面下部に常時表示されるパーティ HUD のカード型 UI である。直近の画面サイズ調整 (1600×900 設計キャンバス) に合わせてサイズを更新したものの、各種フォント・矩形定数が portrait 中心のレイアウトに対して過大で、以下の破綻が確認されている (添付スクリーンショット tmp/dungeon14.png):

- `LV` バッジ枠 32×18px に `BADGE_FONT_SIZE=18` の "LV.99" が収まらず数値が消失
- HP/MP 行ラベル ("HP" / "MP") が `FONT_SIZE=21` のまま 24px 幅に押し込まれて見切れ
- HP/MP 数値テキスト (`%d / %d`, `FONT_SIZE=21`) の高さが HP 行と MP 行の縦間隔 16px を超え、上下が物理的に重なる
- `PANEL_WIDTH=240` に対して `PORTRAIT_WIDTH=170` で左右に 35px ずつの空白 → 6 枚並ぶと約 400px 分の死んだ余白が 3D ビュー中央を占拠し、階段・宝箱の視認を阻害

ステークホルダ: プレイヤー (視認性向上)、開発者 (party-display spec § 13/14 が現状値を固定しているため明示的に書き換える必要)。

## Goals / Non-Goals

**Goals:**
- HP/MP 数値・ラベル・LV 値を見切れ・重なりなく描画する
- HUD 横幅を縮め、3D ビューの中央領域を約 400px 開ける
- 既存テスト・spec の数値依存箇所を新値に追従させる
- 純粋なレイアウト変更に留め、シグナル契約・アニメーション・コンバット連携には触れない

**Non-Goals:**
- `PANEL_HEIGHT` の変更 (現状 240 を維持)
- 名前バッジのフォントサイズ変更 (現状の `FONT_SIZE=21` を維持)
- ステータス・stat-modifier アイコンサイズ変更 (`STATUS_ICON_SIZE=21` 維持)
- アニメーションパラメータの変更
- portrait 解像度・素材差し替え

## Decisions

### D1. パネル幅は `PORTRAIT_WIDTH` + フレーム余裕で 174 とする

`PANEL_WIDTH = 174` を採用する。

- 候補比較:
  - **174** (採用): portrait 170 + 左右フレーム 2px 余裕。フレーム描画 (2.0px) と portrait の縁が衝突しない。
  - 170 (棄却): portrait と panel が同サイズだとフレーム線が portrait 上に被って描画される。
  - 180 (棄却): 余裕は出るが 3D ビュー側を不必要に圧迫する。
- 影響: HUD 6 枚合計で `(240-174)*6 = 396px` の節約。1280 横幅の場合、現状 front 群と back 群が中央で 226px 重なっている問題も同時に解消し、中央に約 170px 以上の隙間が生まれる。

### D2. HP/MP 行と LV badge のフォントは別定数で 14pt にする

`FONT_SIZE = 21` (名前バッジ用) は据え置きで、HP/MP 行用に **新定数 `BAR_FONT_SIZE = 14`** を導入する。`BADGE_FONT_SIZE` は 18 → 14 に縮小。

- 既存の `FONT_SIZE` を一斉に 14 に下げると名前まで縮小され、視認性が落ちる (ユーザ指示: 名前は維持)。
- `BAR_FONT_SIZE` を設けて `_draw_stat_bar` のみを差し替えるのが最小副作用。
- 14pt の根拠: 数字 "184/184" 7 文字 ≒ 約 56px。バー右側に確保できる空間 (174 - bar 終端 116 - 余白 = 約 56px) に収まる。
- 行間も 14pt (≒ 16px text height) なら BAR_HEIGHT 12 + BAR_GAP 4 = 16px 間隔に収まる。

### D3. LV badge は幅を広げ、`LV.99` を許容する

badge を 32×18 → **48×18** に拡張し、フォントは 14pt とする。`get_level_badge_rect` の戻り値の幅を更新する。

- 候補比較:
  - フォント縮小のみ (14pt × 32px): "LV.99" は 14pt で 約 38-42px なので 32px 枠には依然入らない、もしくはギリギリ。
  - 幅 48px に拡張 + フォント 14: 余裕を持って LV.99 が表示でき、視認性も保たれる。
- portrait 内右上に配置されるので、portrait の 170px 幅から 4px 余白を引いた 166px に対して 48px は十分収まる。

### D4. `BAR_LEFT` を 30 に、`BAR_WIDTH` を 76 に調整 (MP ラベルが見切れないよう実測で再決定)

新パネル幅 174 に対し、ラベル領域・バー長・値テキスト領域の三者を実測で割り付け:
- 旧 (240px パネル): `BAR_LEFT=32, BAR_WIDTH=88` → bar 範囲 32-120、value text 124-234
- 中間案: `BAR_LEFT=26, BAR_WIDTH=80` (テスト 1 周目で採用) → "999 / 999" は収まったが、ラベル領域 4-24 (20px) では `MP` が 14pt フォールバックフォントで約 22-24px となり右端が欠ける
- 最終案: `BAR_LEFT=30, BAR_WIDTH=76` → ラベル領域 4-28 (24px) で `MP` 完全表示、bar 30-106、value text 108-170 (値テキスト領域 64px、"999 / 999" 61px が 3px マージン込みで収まる)

`BAR_WIDTH` 88 → 80 → 76 と再調整した結果、バー長は 12px (約 14%) 短くなったが、HP 残量比率の視覚的把握には依然十分。

### D6. `STATUS_ICON_SIZE` を 17 に縮小 (狭くなったパネル幅に対するアイコンの相対視認バランス調整)

ユーザレビューで「stat-modifier アイコンは一回り小さい方が良い」とフィードバック。パネル幅が 240 → 174 に縮んだ結果、相対的に従来の 21px 角アイコンが過大に見えるため:
- `STATUS_ICON_SIZE`: 21 → 17
- `STATUS_ICON_FONT_SIZE`: 18 → 14
- `STATUS_ICON_GAP`: 3 維持

スペックは `STATUS_ICON_SIZE` の絶対値を要件化していない (sane padding のみ規定) ため、spec delta の追加は不要。アイコン行原点 `get_icon_row_origin()` は `PANEL_HEIGHT - STATUS_ICON_SIZE - 5` の式で自動追従するので副作用なし。

### D5. spec delta は最小限の MODIFIED + 新規 ADDED のみ

party-display capability に対し:
- **MODIFIED**: §13 (body font の最小値) と §14 (PANEL_WIDTH 値)
- **ADDED**: LV badge の寸法・フォント要件 (現 spec には未明文化)

§ それ以外の挙動 (アニメーション、シグナル、portrait、name badge 等) は触らない。

## Risks / Trade-offs

- **Risk**: 14pt は 1600×900 で見ると小さく感じる可能性がある → スクリーンショットで確認、必要なら 15-16pt にチューニング (実装フェーズで判断)。
- **Risk**: 既存テストで `PANEL_WIDTH=240`、`FONT_SIZE=21`、`get_level_badge_rect()` の旧サイズ、`get_hp_bar_rect()` / `get_mp_bar_rect()` の旧 x 座標 をハードコードしている箇所が多数想定される → tasks.md でテスト改修を実装前 (TDD red 段階) に行う。
- **Risk**: portrait のレンダリング結果 (`get_portrait_rect()`) はパネル中央配置: `(PANEL_WIDTH - PORTRAIT_WIDTH)/2`。174-170=4 → portrait は x=2 から始まる。フレーム描画 (panel 全体に 2px 線) と portrait 縁の隙間が 2px しかない → 視覚的に詰まりすぎる場合は portrait をわずかに縮める案 (PORTRAIT_WIDTH=164 等) を検討。ただし portrait アセット差し替えになり scope が広がるため、初期実装では PORTRAIT_WIDTH 維持で着地。
- **Trade-off**: `BAR_LEFT=26` だとバー左端のラベル ("HP"/"MP") は x=4-22 に描かれる。14pt なら "HP" は約 18px 幅で収まる → ギリギリ。フォントによっては "MP" が 20px となる場合あり。実装テストで実測確認。
- **Migration**: 仕様変更だが意味論的にはサイズ最適化のみでセーブデータ・シグナル契約に互換性影響なし。ロールバックは git revert 一発。

## Migration Plan

1. tasks.md に従って TDD: テスト先行で新値を期待、red 確認 → 実装で green。
2. 既存の `tests/` 配下で旧値依存しているテストを並行で更新 (同 PR/同コミット内で整合)。
3. 起動して dungeon screen を視認 (ヒューリスティック: スクリーンショット tmp/dungeon14.png と同じシーンを開いて 4 つの破綻が解消していることを確認)。
4. ロールバック: 該当コミットを revert すれば即座に旧レイアウトに戻る。

## Open Questions

- なし (現時点。実装中に LV badge 配置や portrait 余白で違和感が出たら都度判断)。
