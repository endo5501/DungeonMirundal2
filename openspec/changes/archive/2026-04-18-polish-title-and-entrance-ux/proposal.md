## Why

タイトル画面とダンジョン入口画面に、初期カーソル位置に関わる小さな UX の引っかかりがある。いずれも「最も使いたい選択肢にカーソルが乗っていない」ため、ユーザは毎回1〜2回の余計な入力を強いられる。どちらも局所的な修正で済むため、1本の change にまとめて解消する。

## What Changes

- **タイトル画面のメニュー順序を入れ替える**: `["新規ゲーム", "前回から", "ロード", "ゲーム終了"]` → `["前回から", "新規ゲーム", "ロード", "ゲーム終了"]`。セーブデータがある2回目以降の起動で、初期カーソルが「前回から」に乗るようにする。
- **CursorMenu に初期 disabled 自動スキップ機能を追加する**: 初回起動（セーブ無し）時は「前回から」が disabled になるため、CursorMenu の初期 selected_index が disabled の場合は自動で次の有効インデックスに進む挙動を持たせる。既存の `move_cursor()` の disabled スキップと同じ原則。
- **ダンジョン入口の空状態の初期フォーカスを BUTTONS に変える**: DungeonRegistry が空の時、setup() 時点で `_focus = Focus.BUTTONS` かつボタンカーソルを最初の有効項目（新規生成）に置く。Enter キーを1回押さなくても、すぐに「新規生成」を確定できる。
- **ダンジョン入口の空状態メッセージを誘導文に差し替える**: `(ダンジョンがありません)` → `まず「新規生成」でダンジョンを作成してください`。ユーザが次にとるべき行動を明示する。

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities
- `title-screen`: メニュー項目の順序と、セーブ状態に応じた初期カーソル位置の決定ルールが変わる。
- `dungeon-entrance`: 登録済みダンジョンが 0 件の時の初期フォーカスと、空状態で表示するメッセージが変わる。

## Impact

- **コード**:
  - `src/title_scene/title_screen.gd` — `MENU_ITEMS` の並び、`setup_save_state()` 後の初期 selected_index。
  - `src/town_scene/dungeon_entrance.gd` — `setup()` で空 registry 時の `_focus` 初期化、`_build_ui()` 内の空状態メッセージ文言。
  - `src/dungeon/cursor_menu.gd` — 初期 disabled スキップの追加。`CursorMenu` を利用する 18 画面全てに効くが、既存はいずれも index 0 が disabled 前提ではないため挙動は変わらない（安全な拡張）。
- **テスト**:
  - `tests/` 配下の title / dungeon-entrance 関連テストの追加・更新。
- **スコープ外**:
  - 他画面の CursorMenu 表示方式変更（`"> "` プレフィックスのズレ解消）は別 change で扱う。
  - ダンジョン入口のボタン位置変更やレイアウト再設計。
