## Why

CursorMenu はタイトル・町・商店・教会・ダンジョン入口・ESCメニュー・セーブ・ロードなど多数の画面で使われているが、現在の実装はプレフィックス文字列（`"> "` / `"  "`）を Label のテキスト先頭に連結する方式のため、Godot のデフォルトフォント（プロポーショナル）では選択行と非選択行の間で **項目の開始 x 座標が僅かにズレる**。カーソルを動かすたびに文字の位置が小刻みに動いて見え、選択UIの落ち着きを損ねている。プレフィックス方式は複数列の表示（ダンジョン入口のリスト等）でも同じ問題を引き起こしている。

## What Changes

- **カーソル表示を独立した固定幅のカラムに分離する**: 選択行のインジケータを、テキストと同じ Label 内ではなく、行ごとに設けた **固定幅のカーソル列**（`TextureRect` もしくは `Label` を内包した `Control`）に表示する。テキスト列は選択状態に関わらず位置が変わらない。
- **`CursorMenuRow` 共通ヘルパーを新設する**: 「カーソル列 + テキスト列」を内部に持つ `HBoxContainer` 派生クラス。追加の本文ラベルやカラムを連結する API も持つ（ダンジョン入口のリスト行のようなマルチカラム対応）。
- **CursorMenu に行ベースの更新 API を追加する**: 既存の `update_labels(Array[Label])` に加えて `update_rows(Array[CursorMenuRow])` を追加。cursor カラムの可視性切り替えと disabled 色の適用を担う。旧 API は段階移行のため当面残す。
- **8〜10 画面の呼び出しを行ベース API に移行する**: title / town / shop / temple / dungeon-entrance / esc-menu / save / load / dungeon-screen（return dialog）を対象。
- **プレフィックス定数 (`CURSOR_PREFIX`, `NO_CURSOR_PREFIX`) を非推奨にし、最終的に削除する**: 全呼び出しが移行した時点で削除。

## Capabilities

### New Capabilities
- `cursor-menu-ui`: CursorMenu のカーソル表示レイアウト契約。固定幅カーソル列・テキスト位置の不変性・disabled 視覚表現・マルチカラム行の扱いを規定する。

### Modified Capabilities
<!-- 各画面の挙動（カーソル移動、項目選択、disabled 判定）は変わらないため、個別画面 spec の変更は発生しない。 -->

## Impact

- **新規コード**:
  - `src/dungeon/cursor_menu_row.gd` — `HBoxContainer` 派生の行ヘルパー。
- **変更コード**:
  - `src/dungeon/cursor_menu.gd` — `update_rows()` 追加、プレフィックス定数の非推奨化。
  - `src/title_scene/title_screen.gd`, `src/town_scene/town_screen.gd`, `src/town_scene/shop_screen.gd`, `src/town_scene/temple_screen.gd`, `src/town_scene/dungeon_entrance.gd`, `src/esc_menu/esc_menu.gd`, `src/save_screen.gd`, `src/load_screen.gd`, `src/dungeon_scene/dungeon_screen.gd` — 行ベース API への移行。
- **テスト**:
  - `CursorMenuRow` 単体テスト新設。
  - 既存画面テストのうち、プレフィックス文字列に依存したアサーション（例: `label.text.begins_with("> ")`）の書き換え。
- **既存挙動への影響**: カーソル移動・選択シグナル・disabled スキップなどの動作は不変。純粋にレンダリング方式の変更。
- **非対象**: 戦闘関連メニュー（combat_command_menu / combat_monster_panel / combat_target_selector / combat_result_panel）、encounter_overlay、guild_menu、character_list、character_creation、dungeon_create_dialog。これらは独自の表示実装を持ち、CursorMenu 非依存か別形状の UI のため、今回の対象外とする（必要なら別 change で追加）。
