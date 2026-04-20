## 1. アセット準備

- [x] 1.1 `assets/images/facilities/` ディレクトリを作成
- [x] 1.2 `tmp/guild.png` を幅 1024px に `sips` でリサイズし、必要に応じて `oxipng`/`pngcrush` で再圧縮して `assets/images/facilities/guild.png` に書き出し (目標 1MB 以下)
- [x] 1.3 `tmp/shop.png` を同様にリサイズ・圧縮して `assets/images/facilities/shop.png` に書き出し
- [x] 1.4 `tmp/church.png` を同様にリサイズ・圧縮して `assets/images/facilities/church.png` に書き出し
- [x] 1.5 `tmp/dungeon.png` を同様にリサイズ・圧縮して `assets/images/facilities/dungeon.png` に書き出し
- [x] 1.6 `godot --headless --import` を走らせ、`.godot/imported/` に 4 画像が取り込まれることを確認
- [x] 1.7 `tmp/*.png` を削除 (作業用原画をリポジトリから外す)

## 2. テスト先行 (TDD)

- [x] 2.1 `tests/town/test_town_screen.gd` を新規作成し、TownScreen がロード可能であること (既存挙動の回帰テスト用ベース) を追加
- [x] 2.2 カーソル初期位置 (index=0) でギルド画像 (`assets/images/facilities/guild.png`) が TextureRect に設定されていることを検証するテストを追加
- [x] 2.3 下方向に 3 回カーソル移動するとダンジョン画像が設定されることを検証するテストを追加
- [x] 2.4 施設名ラベルが画像切替後も正しい施設名 (`MENU_ITEMS[selected_index]`) を表示していることを検証するテストを追加
- [x] 2.5 画像リソースが存在しない場合に ColorRect フォールバックが可視になり TextureRect が不可視になることを検証するテストを追加 (存在しないパスを注入するテスト用フック or privateメンバー直接操作)
- [x] 2.6 `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/town/test_town_screen.gd` を実行し、追加したテストが期待通り失敗することを確認
- [x] 2.7 この時点でテストのみをコミット (TDD Red フェーズ) — ユーザー判断により 4.3 と合わせて 2 コミット構成で実施

## 3. TownScreen 実装

- [x] 3.1 `src/town_scene/town_screen.gd` に `FACILITY_IMAGES: Array[String]` 定数を追加 (MENU_ITEMS と同インデックス順)
- [x] 3.2 `_illustration_texture: TextureRect` と `_illustration_overlay: ColorRect` (半透明帯) メンバーを追加
- [x] 3.3 `_ready()` で右カラムに TextureRect を配置し、`expand_mode = EXPAND_IGNORE_SIZE` / `stretch_mode = STRETCH_KEEP_ASPECT_COVERED` を設定
- [x] 3.4 `_ready()` で下部オーバーレイ (半透明黒 ColorRect) とその上に既存 `_illustration_label` を再配置するレイアウトを構築
- [x] 3.5 既存の `_illustration_rect` (フォールバック用 ColorRect) を残しつつ初期状態で不可視にする
- [x] 3.6 `_update_illustration()` を画像切替対応に書き換え: `load()` で画像取得 → 成功なら TextureRect に設定・可視化、失敗なら ColorRect を可視化して施設色を適用
- [x] 3.7 ラベル更新は従来通り `MENU_ITEMS[selected_index]` を表示するよう維持
- [x] 3.8 テスト 2.6 を再実行し、すべて通過することを確認
- [x] 3.9 Godot エディタ上で実機確認し、カーソル移動で画像とラベルが切り替わること・フォールバックが妥当であることを目視チェック

## 4. Spec 同期とクリーンアップ

- [x] 4.1 `openspec validate town-facility-images --strict` を通過させる
- [x] 4.2 全テスト実行 (`godot --headless -s addons/gut/gut_cmdln.gd`) で回帰がないことを確認 (1086/1086 passed)
- [x] 4.3 変更をコミット: OpenSpec 成果物 / 実装 (アセット+TownScreen+テスト) の 2 コミットに整理
- [ ] 4.4 main へ PR を作成
- [ ] 4.5 マージ後に `openspec archive town-facility-images` を実行し、`openspec/specs/town-screen/spec.md` に delta を反映
