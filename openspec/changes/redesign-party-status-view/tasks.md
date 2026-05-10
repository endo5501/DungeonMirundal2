## 1. JobPortrait 共通モジュールへの抽出 (TDD)

- [x] 1.1 Red: `tests/ui/test_job_portrait.gd` を新規作成し、`JobPortrait.path_for(&"fighter")` が `res://assets/images/portraits/jobs/fighter.png` を返すこと、未登録 ID で `null` テクスチャを返すこと、同一 job_id 連続呼び出しでキャッシュが共有されること（同じインスタンスが返ること）を検証する。テストは赤で失敗することを確認してコミットする。（`get_path` は `Resource.get_path()` と衝突するため `path_for` / `texture_for` にリネーム）
- [x] 1.2 Red: `tests/dungeon_scene/test_party_member_panel_job_portraits.gd` を、`PartyMemberPanel` が新 `JobPortrait` モジュール経由で同じテクスチャ参照を持つことを検証する形に書き換える。テストは赤で失敗することを確認してコミットする。
- [x] 1.3 Green: `src/ui/job_portrait.gd` を新規作成。`PORTRAIT_PATHS` 辞書、`_texture_cache` static 変数、`path_for(job_id) -> String`、`texture_for(job_id) -> Texture2D` を定義する（`party_member_panel.gd` の既存ロジックを移植）。
- [x] 1.4 Green: `src/dungeon_scene/party_member_panel.gd` を、`JobPortrait.path_for()` / `JobPortrait.texture_for()` を呼ぶ形に書き換える。`JOB_PORTRAIT_PATHS`、`_job_portrait_texture_cache`、`get_job_portrait_path`、`get_job_portrait_texture` の重複定義は削除する。
- [x] 1.5 すべての関連テスト (`test_job_portrait.gd` および `test_party_member_panel_job_portraits.gd`) が緑になることを確認してコミットする。

## 2. StatusView の骨格作成 (TDD)

- [x] 2.1 Red: `tests/esc_menu/test_esc_menu_status.gd` の既存テスト (`test_status_view_shows_party_members`、`test_status_view_shows_empty_message_when_no_party`、状態行関連 3 件) を、新仕様（`StatusView` 経由でメンバーリストと詳細パネルを検証）の API に合わせて書き換える。検証メソッドとして仮の `StatusView.get_member_count() -> int`、`StatusView.get_selected_character() -> Character`、`StatusView.get_status_line_text() -> String` の使用を前提とする。テストは赤で失敗することを確認してコミットする。
- [x] 2.2 Green: `src/esc_menu/views/status_view.gd` を新規作成 (`class_name StatusView extends Control`、`signal back_requested`)。`setup(party: Array[Character])` を公開し、空パーティ時に「パーティが編成されていません」のメッセージを表示する。`HBoxContainer` で左ペイン（`CursorMenu` ベースのメンバーリスト VBoxContainer）と右ペイン（`ScrollContainer` を内包する詳細 VBoxContainer）の枠を構築する。
- [x] 2.3 Green: `_get_party_in_order()` ヘルパで `front 0..2 → back 0..2` の順に編成済みメンバーだけを `Array[Character]` として返す内部実装を追加する。`EscMenu` 側にも `_get_party_in_order()` をペアで実装し、null ギャップを保ったまま StatusView に渡す（StatusView 側で null を除去しつつ元スロット index を保持）。
- [x] 2.4 既存テストの状態行表示（"状態: 通常"、"状態: 毒"、"状態: 毒, 石化"）が新 view 上で緑になることを確認しコミットする。Step 5.1-5.3 の旧コード削除と委譲もこの段階で同時に実施した（独立コミットにする利点が薄かったため）。

## 3. StatusView 詳細パネル各項目の実装 (TDD)

- [x] 3.1 Red: `tests/esc_menu/test_esc_menu_status_detail.gd` を新規作成。以下のシナリオで失敗するテストを書く: ポートレイト Texture が `JobPortrait.get_texture()` と一致、HP/MP の表示文字列が "HP: 28/35"、"MP: 0/0" 形式、Lv.1 で `accumulated_exp=100`、`exp_to_reach_level(2)=1000` のとき "EXP: 100 / 1000" 表示、最大レベル時 "EXP: <値> (MAX)" 表示、6 ステータス値表示、装備 6 スロットの並びとラベル（武器/鎧/兜/盾/籠手/装身具）、装備済みアイテムの `item_name` 表示、未装備時 "(なし)"、未鑑定アイテムの `unidentified_name` 表示、`known_spells = []` 時 "(未習得)" 表示、`known_spells` ありかつ `SpellRepository` で解決できる ID で日本語表示名が表示される、未登録 ID でフォールバックが起きる。テストは赤で失敗することを確認してコミットする。
- [x] 3.2 Green: `StatusView` に `_refresh_detail_pane()` を実装。ポートレイトは `TextureRect` で `JobPortrait.texture_for(ch.to_party_member_data().job_id)`、名前/種族/職/Lv をヘッダ行に、HP/MP、EXP、ステータス、装備、呪文、状態を順に Label 群で配置。
- [x] 3.3 Green: 経験値計算は `_format_exp(ch)` で `level >= exp_table.size() + 1` のとき MAX、それ以外は `"EXP: %d / %d" % [accumulated_exp, job.exp_to_reach_level(level + 1)]`。
- [x] 3.4 Green: 装備描画は `Equipment.ALL_SLOTS` を反復、`SLOT_LABELS_JP: Array[String] = ["武器", "鎧", "兜", "盾", "籠手", "装身具"]` を `StatusView` 内定数として宣言。装備済みは `item_name`/未鑑定は `unidentified_name`、未装備は `(なし)`。
- [x] 3.5 Green: 呪文描画は `_get_spell_repo()` ヘルパ（`SpellUseFlow` と同様のパターン）で SpellRepository を lazy-load。`set_spell_repo(repo)` 公開メソッドで差し替え可能。`SpellRepository.find(id)` で `display_name` を取得、未登録なら `String(id)` にフォールバック。空配列なら `(未習得)`。
- [x] 3.6 Green: 状態行は `StatusRepoLocator.resolve(null).get_display_name()` を使い、空なら `"状態: 通常"`、それ以外は `"状態: " + ", ".join(names)`。
- [x] 3.7 detail テスト 12 件すべて緑を確認しコミット。

## 4. カーソル操作と詳細更新 (TDD)

- [x] 4.1 Red: `tests/esc_menu/test_esc_menu_status_cursor.gd` を新規作成。3 名のパーティで `StatusView` を開いた後、`ui_down` action を発火 → `get_selected_character()` が 2 番目を返す、`ui_up` を発火 → 先頭に戻る、ラップ動作、各カーソル移動後に詳細パネルの名前が切り替わる、`ui_cancel` で back_requested、`ui_accept` は閲覧専用 no-op、を検証する。
- [x] 4.2 Green: `StatusView.handle_input` で `ui_up`/`ui_down` を解釈し `_move_cursor(direction)` → カーソル更新後に `_refresh_detail_pane()`。`ui_cancel` で `back_requested.emit()`、`ui_accept` は consume するが何もしない（閲覧専用）。
- [x] 4.3 Green: `StatusView._unhandled_input` を実装し、`if not visible: return` の後に `handle_input(event)` の戻り値で `set_input_as_handled()` を呼ぶ。
- [x] 4.4 cursor テスト 6/6 緑を確認しコミット。

## 5. EscMenu からの委譲・旧コード削除

- [x] 5.1 `src/esc_menu/esc_menu.gd` の `_status_container`、`_refresh_status_view()`、`_build_character_entry()`、`_build_status_line()` を削除する。（Step 2 と同時に実施）
- [x] 5.2 `EscMenu._build_ui()` で `StatusView` を子 Control として `add_child` し、`back_requested` を `_on_status_view_back` に接続する。`_on_status_view_back` は `_switch_view(View.PARTY_MENU)` を呼ぶ。
- [x] 5.3 `EscMenu._switch_view()` の `View.STATUS` 分岐を、`_status_view.setup(_get_party_in_order())` を呼ぶ形に書き換える。`_status_view.visible = (view == View.STATUS)` を visibility 一覧に追加し、その他の view でも `_status_view.visible = false` になることを確認する。
- [ ] 5.4 `EscMenu.handle_input` の `View.STATUS` 分岐は不要（`StatusView` が `_unhandled_input` で自身処理）になるため、必要に応じて整理する。`go_back` の `View.STATUS` 分岐は維持しても害はないが、`back_requested` 経由が主経路となる。
- [ ] 5.5 既存テスト一式 (`test_esc_menu.gd`、`test_esc_menu_integration.gd` 等) が引き続き緑であることを確認しコミットする。

## 6. EscMenu モーダル入力遮断 (TDD)

- [ ] 6.1 Red: `tests/esc_menu/test_esc_menu_blocks_world_input.gd` を新規作成。テストヘルパで `EscMenu` を visible 化した後、`move_forward`/`move_back`/`strafe_left`/`strafe_right`/`turn_left`/`turn_right`/`toggle_full_map` の各 action を発火し、`get_viewport().is_input_handled()` が true（または `_unhandled_input` のスタブが呼ばれない）ことを検証する。さらに EscMenu を非表示にした後の `move_forward` は通常通り通過することも検証する。テストは赤で失敗することを確認してコミットする。
- [ ] 6.2 Green: `src/esc_menu/esc_menu.gd` の `_unhandled_input` を以下に変更する:
  1. `if not visible: return`
  2. サブフロー visible 時の early return（既存）
  3. それ以外: `handle_input(event)` を呼ぶ（戻り値は無視）
  4. 末尾で常に `get_viewport().set_input_as_handled()` を呼ぶ
- [ ] 6.3 既存テスト全体（`test_esc_menu.gd` を含む）が引き続き緑であること、および `test_esc_menu_blocks_world_input.gd` が緑になることを確認してコミットする。

## 7. Spec verification と仕上げ

- [ ] 7.1 `openspec validate redesign-party-status-view --strict` を実行し、エラーがないことを確認する。
- [ ] 7.2 Godot プロジェクト全体のテストスイート (GUT) を起動し、全テストが緑になることを確認する。
- [ ] 7.3 手動確認: ダンジョン画面で ESC → パーティ → ステータスを開き、↑↓ でカーソルが動き右パネルが切り替わること、装備/呪文/EXP/ポートレイトが表示されること、メニュー表示中に WASD を押してもプレイヤーが動かないこと、ESC で正しくパーティメニューに戻ることを確認する。
- [ ] 7.4 完了状態でコミットし、`/opsx:archive` できる状態にしておく。
