## Why

現在のパーティ表示は画面下部の中央に 3列×2行 で表示されており、ダンジョンの中央視界(階段や敵の正面)にかぶることが多く、エンカウンタダイアログとも領域が重なる。また、フォントが 14pt と小さく、状況把握しづらい。視界を妨げず読みやすい配置に再構成することで、移動・進行時の視認性とプレイフィールを改善する。

これは「パーティ表示の段階的な強化」3部作の第1段で、本変更ではレイアウト・サイズだけを扱う。常駐化(街表示)・状態異常アイコン・戦闘時アニメーションは後続変更で実施する。

## What Changes

- PartyDisplay のレイアウトを 1行×6パネル構成に変更
- 前列3パネルを画面左下に左詰め、後列3パネルを画面右下に右詰めで配置(中央は空ける)
- 各パネル群の上に "FRONT" / "BACK" ラベルを描画
- 全体を覆っていた半透明の背景帯(`_bg_panel`)を廃止
- パネル幅は現状(180px)を維持、高さはフォント拡大に合わせて 80 → 100〜110 に拡張
- フォントサイズを 14pt → 20pt に拡大、行間を再調整
- 空スロット(Character が null)は完全に透明描画(矩形も出さない)
- DungeonScreen のみへのマウント、描画項目(名前/LV/HP/MP)、Character 連携(hp/mp/statuses シグナル)、空スロット = null の構造、パネル位置の固定は維持

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `party-display`: PartyDisplay のレイアウト要件を 1行×6・前後列分離配置に変更し、FRONT/BACK ラベル要件を追加、PartyMemberPanel のサイズ・フォント要件を更新、空スロット透明描画要件と背景帯廃止要件を追加

## Impact

- `src/dungeon_scene/party_display.gd`(レイアウト全面書き直し: アンカー、子配置、FRONT/BACK ラベル描画、`_bg_panel` 削除)
- `src/dungeon_scene/party_member_panel.gd`(`PANEL_HEIGHT`, `FONT_SIZE` 定数の更新、`_draw` 内のテキスト配置・行間、空スロットでの矩形描画抑止)
- `tests/dungeon_scene/`(レイアウト変更を反映するテストの更新と、新規テスト: 配置位置、FRONT/BACK ラベル、空スロット透明、背景帯廃止)
- 既存のシグナル経路(`hp_changed` / `mp_changed` / `statuses_changed` → `queue_redraw`)、`bind_character` / `set_member` API、`DungeonScreen` の bind フローは変更なし
