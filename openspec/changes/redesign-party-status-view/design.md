## Context

ESC > パーティ > ステータス画面は `src/esc_menu/esc_menu.gd` 内の `_refresh_status_view()` / `_build_character_entry()` で組み立てられており、`TitledView` の中に編成済みメンバー全員を縦に積む実装になっている。表示項目は名前/Lv、HP/MP、基礎ステータス、状態の 4 行のみで、経験値・装備・習得呪文・ポートレイトは含まれていない。

ESC メニュー全体は `EscMenu` (`extends CanvasLayer`, `layer = 10`) としてオーバーレイ表示されるが、`CanvasLayer.visible` は子 Control の `_unhandled_input` を停止しないため、フォーカス制御は flow 個別 (`_unhandled_input` 内で `if not visible: return`) に頼っている。一方 `DungeonScreen._unhandled_input` (`src/dungeon_scene/dungeon_screen.gd:108`) は full_map_overlay / encounter_active / return_dialog の各状態だけをガードしており、EscMenu の表示状態を見ていない。EscMenu 自身は `ui_up`/`ui_down`/`ui_accept`/`ui_cancel` だけを `set_input_as_handled()` で消費しており、`move_forward` などのアクションは EscMenu を素通りして DungeonScreen に届く。これがダンジョン中にメニューを開いたまま WASD でプレイヤーが動いてしまう不具合の原因。

ジョブポートレイト機能は `src/dungeon_scene/party_member_panel.gd:21-31` で導入済みで、`JOB_PORTRAIT_PATHS` 定数および `_job_portrait_texture_cache` static 辞書、`get_job_portrait_path` / `get_job_portrait_texture` ヘルパが揃っている。`assets/images/portraits/jobs/` 配下に 8 ジョブ分の PNG が存在する。同様の機能をステータス画面用に再実装すると 2 重保守になるため、共通化が望ましい。

呪文表示名は `SpellData.display_name` (`src/dungeon/data/spell_data.gd:20`) に定義されており、`SpellRepository` (`src/dungeon/data/spell_repository.gd`) から ID 経由で取得できる。`SpellUseFlow` (`src/esc_menu/flows/spell_use_flow.gd:42, 390`) には `_spell_repo` フィールドと `_get_spell_repo()` (DataLoader 経由 lazy load) のパターンが既に確立しているため、新 status view も同じパターンを使える。

## Goals / Non-Goals

**Goals:**
- ステータス画面を「左: メンバーリスト+カーソル / 右: 詳細パネル」の 2 ペイン UI に作り替え、職業ポートレイト・経験値・装備・習得呪文を含む詳細を表示する。
- カーソル移動で右ペインが即時に更新される、操作の予測可能な閲覧 UI を実装する。
- EscMenu 表示中は背後画面（特にダンジョン）への入力リークを完全に塞ぎ、`esc-menu-overlay` 仕様の意図を実装で満たす。
- ジョブポートレイトのアセット参照ロジックを共通化し、`party_member_panel` と新 status view が同じソース・同じキャッシュを共有する。

**Non-Goals:**
- ギルド全員（パーティ未編成キャラ含む）の閲覧（別画面の責務）。
- ステータス画面からの装備変更や呪文詠唱（既存 `EquipmentFlow` / `SpellUseFlow` のままにする）。
- マウス操作・ホバー反応。
- 職業以外（種族・性別・キャラ個別）に紐付くポートレイトの導入。
- セーブフォーマットの変更（既存 `Character` フィールドのみ参照）。

## Decisions

### D1. 新 view を `src/esc_menu/views/status_view.gd` に分離する

`esc_menu.gd` は既に flow 群 (`ItemUseFlow`/`EquipmentFlow`/`SpellUseFlow`) を子 Control として保持しビュー切替で委譲する構造を持つ。新ステータス画面も同じパターンに従い、`StatusView extends Control` を新設する。`EscMenu` 側は `_status_container`（`TitledView` ベースの旧実装）と `_refresh_status_view`/`_build_character_entry`/`_build_status_line` を削除し、`_status_view: StatusView` フィールドと visibility 切替・`back_requested` シグナル受信だけを残す。

理由: `esc_menu.gd` の責務肥大を避け、テストを view 単位で書きやすくするため。

代替案: 既存の `_status_container` をそのまま膨らませる案。却下 — `esc_menu.gd` のサイズが既に 380 行を超えており、UI 構築コードを分離した方が他の flow と一貫する。

### D2. レイアウトは `HSplitContainer` ではなく `HBoxContainer` + 固定幅の左ペイン

左ペイン（メンバーリスト）は最大 6 行の固定リストで、ユーザがリサイズする必要がない。`HBoxContainer` の中に左 `VBoxContainer`（幅固定）と右 `ScrollContainer`（残り幅を埋める）を置き、右パネルだけスクロール可能にする。

理由: スプリッタは閲覧専用画面では雑音。装備や呪文が増えても破綻しないようスクロールが必要なのは右パネルのみ。

### D3. 左ペインは `CursorMenu` を再利用

`src/dungeon/cursor_menu.gd` および `cursor_menu_row.gd` は EscMenu 内の他のメニューが既に使用している共通カーソル制御。これを再利用してメンバー名行を構築すれば、↑↓ のスキップ動作・disabled 表現・ハイライト描画を統一できる。空スロットは disabled として混ぜず、編成済みメンバーだけをリストに入れる方針（カーソルが空欄に止まらない）。

行ラベルのフォーマット: `"%d. %s" % [position+1, character_name]`（前列 1-3、後列 4-6）。Lv 等の追加情報は右パネル側で出すため左は氏名のみ。

代替案: 単純な `Button` 群を `VBoxContainer` に並べる案。却下 — フォーカス遷移と disabled 制御を CursorMenu 経由に統一した方が ESC メニュー内で一貫する。

### D4. 経験値表示

形式: `EXP: %d / %d` （現在値 / 次レベルに必要な値）。最大レベル時は `EXP: %d (MAX)`。次レベル必要値は `Character.job.exp_to_reach_level(level + 1)` を参照。最大レベル判定は `level >= job.exp_table.size() + 1`（`Character.gain_experience` で使われている同じ式）。

### D5. ポートレイト共通化を `src/ui/job_portrait.gd` で行う

`party_member_panel.gd` の `JOB_PORTRAIT_PATHS` / `_job_portrait_texture_cache` / `get_job_portrait_path` / `get_job_portrait_texture` を新規 `class_name JobPortrait extends RefCounted`（または `Object` の static-only ユーティリティ）に切り出す。`party_member_panel.gd` 側はこのモジュールを呼び出す形に書き換える。テクスチャキャッシュは static として共有し、両者で重複ロードを避ける。

仕様面では `dungeon-3d-rendering` 等で `JOB_PORTRAIT_PATHS` の場所を直接参照する記述はないため、内部リファクタとして扱う。`party-display` の既存テスト (`test_party_member_panel_job_portraits.gd`) は新 API を呼ぶ形に追従する。

代替案: ポートレイトロジックを status_view.gd に複製。却下 — 同じ職アセット辞書を 2 箇所で管理することになり、ジョブ追加時の保守事故が発生しやすい。

### D6. 呪文の取得・表示

`StatusView` が `_spell_repo: SpellRepository = null` フィールドを持ち、`SpellUseFlow._get_spell_repo()` と同形のヘルパ `_get_spell_repo()` を実装する（テストで差し替え可能なように `set_spell_repo(repo)` 公開メソッドも用意）。各 known_spell ID について `_spell_repo.get(id).display_name` で表示名を取得し、未登録 ID は `String(id)` にフォールバックする（既存 `StatusRepository.get_display_name` のパターンと同等）。

ソート順: `Character.known_spells` の登録順を尊重する（学習順 ≒ レベル順）。重複ソートは行わない。`known_spells` が空なら `(未習得)` を表示する。

### D7. 装備の取得・表示

`Equipment.ALL_SLOTS` をスロット順序の単一ソースとして反復する（`esc-menu-overlay` の既存要件と整合）。スロットラベルは現状 `equipment_flow.gd` の `SLOT_LABELS = ["武器", "鎧", "兜", "盾", "籠手", "装身具"]` と同じ並びで、これも将来の保守を考えると共通化の余地はあるが、本変更では同じ定数を `StatusView` 側にも持たせるに留める（過剰なリファクタを避ける）。

各スロットに対し `Character.equipment.get_equipped(slot)` で `ItemInstance` を取得。装備済みの場合は `inst.item.item_name`（`identified` を考慮するか否かは下記）、空なら `(なし)`。

未鑑定アイテム判定: ステータス画面はパーティのキャラが装備中＝既に判別済みの状況なので、`ItemInstance.identified` の値を尊重し未鑑定なら `inst.item.unidentified_name` を表示する（`item_use_flow.gd:297` と同じ規約）。

### D8. EscMenu の入力遮断（B 案）

`EscMenu._unhandled_input` の挙動を以下に変更する:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    handle_input(event)            # 既存の up/down/accept/cancel ハンドリング
    get_viewport().set_input_as_handled()  # 常に消費
```

これにより `move_forward`/`move_back`/`strafe_left`/`strafe_right`/`turn_left`/`turn_right`/`toggle_full_map` などのアクションは `EscMenu` で食べられ、`DungeonScreen._unhandled_input` には届かない。サブ flow が visible のときの early return 条件（既存）はそのまま維持する — flow 自身が `_unhandled_input` で `set_input_as_handled()` を呼ぶ規約で、上位 EscMenu が握りつぶさない。

代替案 A: DungeonScreen 側に `if _esc_menu_visible: return` を増やす案。却下 — DungeonScreen が EscMenu を直接知ることになり、town_screen / guild_screen など今後も同種ガードを増やす羽目になる。
代替案 C: フラグを GameState 経由で持つ案。却下 — 描画レイヤとモード状態の二重管理になる。

### D9. テスト戦略

新規/書き換えテスト:

1. `tests/esc_menu/test_esc_menu_status.gd`（既存・要書き換え）: 旧構造前提（`_status_container.get_child_count() > 2`、`_find_status_line`）を、新 `StatusView` の API（`get_member_list_size()`、`get_selected_character()`、`get_detail_labels_text()` など）を使った検証に置き換える。「状態: 通常 / 毒 / 毒, 石化」の表示は引き続き検証する。
2. `tests/esc_menu/test_esc_menu_status_cursor.gd`（新規）: ↑↓ で右パネルが切り替わること、リスト先頭/末尾のラップ動作、編成済みメンバーのみがリストに含まれることを検証。
3. `tests/esc_menu/test_esc_menu_status_detail.gd`（新規）: 詳細パネル各項目（HP/MP, EXP, 装備, 呪文, 状態, ポートレイト適用）を検証。`SpellRepository` をテスト用ダブルで差し替えた状態での呪文名表示を確認。
4. `tests/esc_menu/test_esc_menu_blocks_world_input.gd`（新規）: `EscMenu` を visible にした状態で `move_forward` / `toggle_full_map` 等の InputEventAction を `Input.parse_input_event()` 等経由で送り、`get_viewport().is_input_handled()` または DungeonScreen 側のハンドラ呼び出し有無で「漏れていない」ことを検証する。テストヘルパは `tests/test_helpers.gd` の既存ユーティリティを活用。
5. `tests/dungeon_scene/test_party_member_panel_job_portraits.gd`（既存・要更新）: `JobPortrait` 共通モジュール経由で同じテクスチャを返すこと、`_job_portrait_texture_cache` が共通であることを確認。
6. `tests/ui/test_job_portrait.gd`（新規）: 共通モジュール単体の挙動（パス解決、未登録 ID で `null`、キャッシュヒット）を検証。

すべて TDD で進め、まず失敗する Red テストをコミット、次に実装で Green にする。

## Risks / Trade-offs

- **[ScrollContainer 内のフォーカス挙動]** → カーソル移動はあくまで左の `CursorMenu` 内で行うため、右の `ScrollContainer` はフォーカスを受け取らない設定 (`focus_mode = Control.FOCUS_NONE`) にして、右クリックスクロール等の意図しないインタラクションを排除する。
- **[`set_input_as_handled` の汎用消費が他レイヤを巻き込む]** → ESC メニュー上に重ねる ConfirmDialog や flow 群は `_unhandled_input` で処理する規約が既にあり、`_unhandled_input` の発火順は子 → 親なので、サブ flow が先に `set_input_as_handled()` を呼んだ場合 EscMenu の `_unhandled_input` は走らない（Godot の `_unhandled_input` 仕様）。よって既存挙動を壊さない。
- **[ポートレイトモジュール抽出による回帰]** → `party_member_panel` のジョブ追加テストが共通モジュールに直接依存する形になるため、移行時に red のままコミットして実装で green にする TDD 順序を厳守する。
- **[未鑑定アイテムの取り扱い]** → 装備中アイテムが未鑑定の状態（呪われた装備の鑑定前など）は本変更の主題ではないが、`identified` を尊重しないと `item_use_flow` と表示挙動がずれる。Decision D7 でこれに従う方針を明記済み。
- **[最大レベル時の EXP 表示]** → `Character.gain_experience` の最大レベル判定式と完全に一致させないと、ピッタリ最大レベルに達したケースで `次のレベルまで`==`現在値` のような誤表示になる。Decision D4 で同じ式を参照することで整合させる。

## Migration Plan

1. **Red phase commits** (Step 1 群): 新規テストとリネーム後のテストを失敗状態でコミットする。
2. **Implementation commits** (Step 2 群): `JobPortrait` 共通化 → `StatusView` 新規作成 → `EscMenu` の view 差し替え → `EscMenu._unhandled_input` のモーダル化、の順で各ステップ後にすべてのテストが緑になることを確認しながらコミット。
3. データ互換性問題なし（保存形式不変）。
4. ロールバック手順: 各ステップは独立コミットになっているので、`git revert` で逐次戻せる。

## Open Questions

なし — explore モードで合意済み。
