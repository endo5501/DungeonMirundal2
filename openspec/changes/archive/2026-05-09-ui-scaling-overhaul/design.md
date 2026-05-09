## Context

`DungeonMirundal2` は Godot 4.6 で作られた一人称ダンジョン RPG。UI は `Control` ノードに対する anchor 配置と、ハードコードされたピクセル定数 (font_size, パネル寸法, スプライトサイズ) で構成されている。

現状、`project.godot` に `[display]` セクションが存在しないため、Godot のデフォルト `stretch_mode = "disabled"` が適用される。この設定では、ウィンドウをリサイズしても Control 内部のレンダリング解像度はピクセル等倍で固定される。結果として:

- ウィンドウだけが拡大し、フォント・スプライト・パネル内部要素は据え置かれて UI が相対的に小さく見える
- 大きいウィンドウでは情報密度がスカスカになり、文字も読みづらい
- 起動時の小さい標準ウィンドウ (1146×768 程度) では、文字 14px が物理的にも小さい

加えて、`DungeonScreen` は SubViewport を `UPDATE_DISABLED` で初期化し、移動・回転時のみ `UPDATE_ONCE` で 1 フレーム描画している。これはパフォーマンス最適化として妥当だが、ウィンドウリサイズ時に SubViewport が新しいサイズで再描画されないため、テクスチャがクリアされたまま黒く表示される副作用を生んでいる。

ターゲットプラットフォームは macOS / Windows デスクトップ。HiDPI 環境を含む。

## Goals / Non-Goals

**Goals:**

- ウィンドウリサイズに応じて UI 全体 (フォント・スプライト・パネル) が均一にスケールする
- デフォルト起動時 (1600×900) の状態で、本文フォント 21px 相当の読みやすさを確保する
- 任意のリサイズで UI が歪まない (アスペクト比保持)
- 超ワイドモニターでも黒帯を出さず、anchor 比例配置で右カラムが端まで到達する
- ウィンドウリサイズ時にダンジョン3D 描画が消失しない

**Non-Goals:**

- ユーザー設定によるフォントサイズ調整機能の追加 (将来検討)
- 多言語対応に伴うフォント切替
- レスポンシブな UI レイアウト変更 (例: 横長ウィンドウで右カラムを縦長に変えるなど)
- モバイル / Web ビルドの最適化
- 既存のレイアウト構造 (FRONT/BACK 行の左右配置、右カラムのコマンド等) の変更

## Decisions

### D1: Stretch mode は `canvas_items` を採用する

Godot 4 の stretch mode には `viewport` と `canvas_items` がある。

- `viewport`: 設計解像度のフレームバッファを 1 枚生成し、それをウィンドウサイズに引き伸ばす。ピクセルアート向け。
- `canvas_items`: 全 Control を仮想設計解像度として扱い、各要素を実画面解像度で個別に再描画する。ベクター系 UI 向け。

本プロジェクトはピクセルアートでなく、Label の文字も TextureRect の画像もネイティブ解像度で再描画されるべきため、**`canvas_items`** を採用する。フォントは `font_size` 値を「設計ピクセル」として扱い、実画面ではスケール倍率に応じて自動的に再ラスタライズされる。

### D2: Aspect mode は `expand` を採用する

候補:
- `keep`: 黒帯/ピラーで設計アスペクト比を維持
- `expand`: 設計アスペクト比とウィンドウアスペクト比が異なる場合、余分な領域を「設計座標系の外側」として可視化。歪まない。
- `ignore`: 強制フィット。歪みが発生

`expand` を採用する理由:

- 黒帯が出ない (ユーザー希望)
- 歪まない (`ignore` のように文字が横に間延びしない)
- 既存レイアウトが anchor 比率 (例: `RIGHT_COLUMN_LEFT = 0.74`) を多用しており、余分な領域が広がっても anchor は新ビューポートの % で再配置されるので右カラムが端に貼り付き続ける
- 16:9 を超える 21:9 等のウルトラワイドでも自然に動作する

### D3: ベース解像度は 1600×900 を採用する

候補:
- 1280×720: 現状の暗黙的設計値に近い。コード変更最小。だがデフォルト起動時のフォント/パネルが現状並みで「小さい」感覚が解消されない
- 1920×1080: 一般的な設計解像度。だが現定数の比率では UI がスカスカになり、より大きく bump する必要がある (約 1.7×)。また、6 つのパーティパネルを並べた時の幅制約もより厳しくなる
- **1600×900: 中間点**

1600×900 を選んだ根拠:

- 現定数からの bump 倍率が中庸 (フォント 1.5×, 大きめ要素 1.33×) で、深い見直し不要
- 16:9 アスペクトで一般的なディスプレイにフィット
- パーティパネル 6 並びが `PANEL_WIDTH=240` で `6×240 + 6×11 = 1506px` と 1600 内に余裕を持って収まる
- HiDPI 環境では OS の論理解像度より小さく扱われるので、Retina MacBook でもデフォルト起動が画面に収まる

### D4: フォント 1.5× / パネル 1.33× の非均一 bump

理想的には全定数を均一に bump したいが、`PartyDisplay._layout_panels` のレイアウト計算 (`m + 6*PW + 6*M`) により、PANEL_WIDTH を 1.5× (180→270) すると 6 並びが 1692px となり 1600 ベースに収まらない。

採用ルール:

- フォントサイズ・モンスター戦闘画像など「読みやすさ最優先」のものは 1.5×
- パーティパネル枠・ポートレート・アイコン・余白など「レイアウト制約があるもの」は 1.33× (`6×240 + 6×11 = 1506` で 1600 内に収まり、中央に約 90px の隙間が残る)

副作用として、パーティパネル内ではフォントが相対的にゆとりを持つ (= さらに読みやすい) が、これは利点として受容する。

### D5: SubViewport リサイズ時の再描画

`DungeonScreen._sub_viewport.render_target_update_mode = UPDATE_DISABLED` を維持しつつ、ウィンドウサイズ変更を検知して `UPDATE_ONCE` を再トリガーする。

実装パターンの候補:

- (a) `Control._notification(NOTIFICATION_RESIZED)` を `DungeonScreen` に実装
- (b) `Control._notification(NOTIFICATION_WM_SIZE_CHANGED)` を購読
- (c) `SubViewportContainer.resized` シグナルを購読

採用は (a)。`DungeonScreen` 自体が画面いっぱいの Control なのでリサイズ通知を受け取れる。`_refresh_all()` を呼べば既存パスを通って `UPDATE_ONCE` がセットされる。シグナル接続より単純で副作用も少ない。

`_player_state` や `_wiz_map` が未セットの状態 (起動直後など) で発火する可能性があるため、ガード条件を入れる。

### D6: スペック更新の方針

`party-display` の既存要件には PANEL_WIDTH=180 固定や body font size < 20 が明記されている。これらは bump 後の値に合わせて要件側を更新する (delta spec)。

`project-setup` には現在 `[display]` セクション要件が無いので、新規追加する (ADDED)。

`dungeon-3d-rendering` には SubViewport のリサイズ動作要件が無いので、新規追加する (ADDED)。

その他のサブスペック (combat-overlay 等) には font_size の具体値が明記されていないため、delta は不要。

## Risks / Trade-offs

- **[Risk]** `stretch_mode = "canvas_items"` の有効化で、現在の起動ウィンドウ (1146×768) より起動デフォルトが大きくなる (1600×900) → **Mitigation**: 1600×900 は一般的なディスプレイの 1366×768〜2560×1440 の範囲に収まる。Retina MacBook では論理解像度ベースで OS が縮小表示するため画面に収まる。問題があれば `window/size/window_width_override` で初期サイズを別指定可能
- **[Risk]** フォント 1.5× とパネル 1.33× の非均一 bump により、パネル内テキスト密度が現状と異なる印象になる → **Mitigation**: テストプレイで確認。視覚的に問題があれば局所的に微調整 (PANEL_HEIGHT を 1.4× するなど)
- **[Risk]** golden text や rect 計算系のテストで具体値を期待しているものは大量に更新が必要になる可能性 → **Mitigation**: テストの失敗を機械的に潰す。スコープを最小化するため、定数を bump する以外のロジック変更は行わない
- **[Risk]** `expand` モードでは、ウィンドウのアスペクト比次第で「右カラムの右端マージンが変わる」 → 一見デザイン崩れに見えるかもしれない → **Mitigation**: anchor が 0.74〜0.98 等で配置されているため、ビューポート幅が広がれば右カラムも比例して広がるため違和感は最小
- **[Risk]** `_notification(NOTIFICATION_RESIZED)` は親 Control のサイズ変更でも発火する。ウィンドウ起動直後など複数回連続して発火することがある → **Mitigation**: `UPDATE_ONCE` は冪等 (1 フレームだけ描画する) なので副作用なし。ガード条件 (`_wiz_map != null`) で未初期化時は no-op

## Migration Plan

1. `project.godot` に `[display]` セクションを追加 (起動時から有効)
2. UI 定数を bump (実行時から有効)
3. `DungeonScreen` のリサイズ対応を追加
4. テスト期待値を更新
5. 手動テストでウィンドウサイズを変えて UI とダンジョン描画が正常にスケールすることを確認

ロールバックは git revert で全体を戻すだけで済む (configuration ベースのため)。

## Open Questions

- パーティパネル `PANEL_HEIGHT` の bump 倍率は 1.33× (224) で十分か、それともフォント側に合わせて 1.5× (252) にすべきか? → 暫定で 1.33× を採用するが、テストプレイで判断する
- 既存 spec の `PartyMemberPanel uses an enlarged font size for body text` 要件は「body font size SHALL be less than 20」と書かれており、bump 後 (21) は要件に違反する → spec 側を「less than 25」等に緩めるか、定数定義として明示する形式に変更する。delta spec の中で明確化する

## Update from visual review pass (2026-05-09)

ユーザー目視確認の結果、以下を追加実施した:

- `PartyMemberPanel` のポートレート領域が縦に伸ばし足りなかった (HP/MP bar が portrait の中に重なる + bar の下に大きな空白) ため、`PANEL_HEIGHT` 224→240, `PORTRAIT_HEIGHT` 138→174 に拡張
- 戦闘メニューの行 (`CursorMenuRow.create` 第3引数として渡される font_size) は `add_theme_font_size_override` 経由のフォント bump とは別パスだったため、当初 bump から漏れていた。`combat_command_menu` / `combat_target_selector` で 16→24, `combat_spell_selector` / `combat_item_selector` で 14→21 に追加 bump

## Update from simplify review pass (2026-05-09)

D5 の決定 ("re-triggering SHALL use the existing `_refresh_all()` path") を撤回し、`_notification(NOTIFICATION_RESIZED)` は SubViewport を直接 `UPDATE_ONCE` にするだけに変更した。

理由:

- `_refresh_all()` は `_explored_map.mark_visible()` を呼んでおり、リサイズ時にこれが走るのは意味的に間違い (リサイズは探索行為ではない)。現状はべき等で実害がないが、将来 `mark_visible` がシグナルを emit するようになった場合に偽陽性のイベントが流れる
- `_refresh_all()` は ImmediateMesh を再構築・minimap を再描画するが、リサイズ時に player は移動していないため既存メッシュ・カメラ・minimap は有効のまま。SubViewport の framebuffer を再アームすれば既存ジオメトリが新しいサイズで再描画される
- `NOTIFICATION_RESIZED` は親 Control の layout pass 中に複数回発火しうる。最小実装にすることでこの redundant な発火コストも最小化される

ガード条件は `_wiz_map == null` (ダンジョン未 setup) から `_sub_viewport == null` (`_ready()` 未実行) に変更。`_ready()` 後 `setup()` 前の状態で発火しても SubViewport を空のまま再アームするだけで安全。

## Refactor: shared constants introduced in simplify pass

simplify pass の副産物として、以下の定数を導入した (spec で外部観測される挙動には影響なし):

- `CombatWindowStyle.TITLE_FONT_SIZE` (24), `BODY_FONT_SIZE` (21), `ROW_FONT_SIZE` (24), `HINT_FONT_SIZE` (18) — 戦闘 UI 6 ファイルに散在していた font_size リテラルを集約
- `PartyMemberPanel.BAR_HEIGHT` (12), `BAR_GAP` (4), `BAR_LEFT` (32), `BAR_WIDTH` (88) — `get_hp_bar_rect` / `get_mp_bar_rect` のハードコード Rect2 を `get_portrait_rect()` 由来の計算に変換し、PORTRAIT_HEIGHT 変更が bar 位置に追従するようにした

これらは spec で外部から観測すべき制約ではなく、内部実装の整理。次回スケール変更時の触る箇所を最小化する効果がある。
