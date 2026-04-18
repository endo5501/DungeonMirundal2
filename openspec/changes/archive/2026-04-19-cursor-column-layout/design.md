## Context

`src/dungeon/cursor_menu.gd` は `CURSOR_PREFIX := "> "` と `NO_CURSOR_PREFIX := "  "` を Label テキストに連結する方式で選択カーソルを表現している。Godot のデフォルトフォントはプロポーショナルのため、`>` と空白の描画幅差がそのままテキスト開始位置のズレになり、選択が切り替わるたびに項目が左右に数ピクセル揺れる。ダンジョン入口のリスト行のように `prefix + 名前 + サイズ + 探索率` と複数カラムを1つの Label に詰めている箇所では、後続カラムも連動してズレる。

CursorMenu は 8 画面で `.new()` 経由、さらに 3 箇所で `CURSOR_PREFIX` / `NO_CURSOR_PREFIX` 定数を直接使って独自整形している。戦闘系メニューや guild/character 系画面は CursorMenu を使っていないため今回の対象外。

## Goals / Non-Goals

**Goals:**
- カーソル移動時に、項目のテキスト開始位置が1ピクセルも動かない（テキスト位置の不変性）。
- 複数カラム表示（名前・サイズ・探索率等）でも位置が動かない。
- 既存の挙動（カーソル移動、wrap、disabled スキップ、選択シグナル発火、disabled 色）は完全に保つ。
- CursorMenu を使う 9 画面（title / town / shop / temple / dungeon-entrance / esc-menu / save / load / dungeon-screen のリターンダイアログ）を移行する。

**Non-Goals:**
- 戦闘メニュー、encounter overlay、guild/character 系画面のレイアウト変更。
- カーソルアイコンのアニメーション、効果音、テーマ化。
- フォント変更（monospace 化）。案1 の選択肢だったが、「案4 = カーソル列分離」で確定済み。
- カーソル以外の UI（ボタン配置、見出し、背景）への手入れ。

## Decisions

### Decision 1: 行ヘルパー `CursorMenuRow`

新しい class `CursorMenuRow extends HBoxContainer` を `src/dungeon/cursor_menu_row.gd` に置く。内部構造:

```
HBoxContainer (CursorMenuRow)
├── Control (cursor_slot, 固定幅 24px 程度)
│   └── Label (cursor_icon, text="▶" or "") ← 可視/不可視で切替
└── Label (text_label, メインテキスト)
```

API:
- `set_text(text: String)` — テキスト列を更新
- `set_selected(selected: bool)` — カーソル列の可視性切替
- `set_disabled(disabled: bool)` — テキスト列に `DISABLED_COLOR` / `ENABLED_COLOR` を適用
- `add_extra_label(label: Label)` — ダンジョン入口のリスト行のようなマルチカラム行で、text_label の右に追加カラムを並べる。cursor 列は常に先頭で固定幅のまま。

カーソル表現:
- **第一候補**: Unicode 文字 `"▶"`（色は ENABLED_COLOR、右寄せ）。装飾なしで済み、既存フォントで問題なく出る。
- **第二候補**: `TextureRect` に専用アイコン。今回は第一候補で進め、必要に応じて後日差し替え可能なように cursor_slot を Control にしておく。

### Decision 2: `CursorMenu.update_rows()` の追加

`src/dungeon/cursor_menu.gd` に以下を追加:

```gdscript
func update_rows(rows: Array[CursorMenuRow]) -> void:
    for i in range(rows.size()):
        rows[i].set_selected(i == selected_index)
        rows[i].set_disabled(is_disabled(i))
```

既存 `update_labels(Array[Label])` は当面残すが、非推奨コメントを付ける。9 画面の移行が完了した段階で `CURSOR_PREFIX` / `NO_CURSOR_PREFIX` / `update_labels` を削除する（同一 change 内で削除する）。

### Decision 3: 各画面の移行パターン

旧コード (title_screen を例に):

```gdscript
for i in range(MENU_ITEMS.size()):
    var label := Label.new()
    label.add_theme_font_size_override("font_size", 20)
    vbox.add_child(label)
    _labels.append(label)

_menu.update_labels(_labels)
```

新コード:

```gdscript
for i in range(MENU_ITEMS.size()):
    var row := CursorMenuRow.new()
    row.set_text(MENU_ITEMS[i])
    row.set_text_font_size(20)
    vbox.add_child(row)
    _rows.append(row)

_menu.update_rows(_rows)
```

ダンジョン入口リストのマルチカラム版:

```gdscript
var row := CursorMenuRow.new()
row.set_text(dd.dungeon_name)
var size_label := Label.new()
size_label.text = "%dx%d" % [dd.map_size, dd.map_size]
var rate_label := Label.new()
rate_label.text = "探索%d%%" % rate
row.add_extra_label(size_label)
row.add_extra_label(rate_label)
```

### Decision 4: カーソル列の幅とフォント整合

`cursor_slot.custom_minimum_size.x = 24` を基準とする（本文フォント 18〜20 に対して `▶` が収まる幅）。画面ごとに幅を変える必要は当面なし。テスト時は `get_minimum_size()` または `get_rect()` で固定幅であることを検証する。

### Decision 5: disabled 色の適用方式

現状は `CursorMenu.update_labels` で `add_theme_color_override("font_color", ...)` を Label 全体に適用している。新方式ではテキスト Label と extra Label の両方に同じ色を適用する。カーソル列は常に ENABLED_COLOR（選択中のみ可視なので disabled 時は非表示でもある）。

### Decision 6: 段階移行 vs 一括移行

**採用: 一括移行**。中途半端に両方存在すると、`> ` と `▶カラム` が画面間で混在してちぐはぐになる。1 change 内で全 9 画面を移行し、その中で旧 API（プレフィックス定数 + `update_labels`）を削除する。

## Risks / Trade-offs

- **[Risk] 既存テストがプレフィックス文字列に依存している** → Mitigation: タスクで「移行前のテスト棚卸し」を明示する。`label.text.begins_with("> ")` のようなアサーションを、`row.is_selected()` や cursor_slot の visibility に書き換える。
- **[Risk] ダンジョン入口の `_focus == Focus.DUNGEON_LIST` 判定と連動したカーソル表示が崩れる** → Mitigation: 既存の「フォーカスがリスト側かボタン側か」で行のカーソル可視性を切り替えるロジックは `CursorMenu.update_rows()` に移す。`_update_labels()` の条件分岐を行単位に書き換える。
- **[Risk] `▶` 文字が環境によって字形が違う** → Mitigation: 最初は `▶` で進めるが、CursorMenuRow の内部実装を Control にしておくことで、後で TextureRect に差し替え可能にする。
- **[Trade-off] 9 画面の変更で差分が大きい** → Mitigation: TDD とタスク分割で 1 画面ずつ確実に移行。移行中は旧 API も残し、CI が通る状態を保ちながら進める。削除は最終ステップ。
- **[Trade-off] 対象外（戦闘・guild 等）の画面は今のまま** → 許容。これらは CursorMenu を使っておらず独自実装なので、別 change で対処する。

## Migration Plan

TDD の順で:

1. `CursorMenuRow` の単体テストを先に書く（レイアウト・API 挙動）
2. 実装して緑に
3. `CursorMenu.update_rows()` のテスト → 実装
4. 画面ごとに順次移行（title → town → shop → temple → esc-menu → save → load → dungeon-screen → dungeon-entrance）。各移行は「テスト更新 → 実装変更 → 該当画面のテスト緑」を1単位とする
5. 全 9 画面移行後、`CURSOR_PREFIX` / `NO_CURSOR_PREFIX` / `update_labels` を削除し、他に参照が残っていないことを grep で確認
6. 全テスト通過 + 手動で全画面を巡回して視覚確認

ロールバック: 変更量が多いため、段階的なブランチコミットを切り、問題のあるコミットだけを revert できるようにする。

## Open Questions

- `▶` 以外のカーソル候補（`→`, `>`, `❯`, 専用アイコン）について、ビジュアル的な好みがあればこの段階で固定したい。実装中に差し替えるのは容易。
