## Context

4 箇所のインライン実装の典型例(`save_screen.gd:78-103`):
```gdscript
func _build_overwrite_dialog() -> void:
    _overwrite_menu = CursorMenu.new(["はい", "いいえ"])
    _overwrite_menu.selected_index = 1  # default to いいえ
    _overwrite_container = CenterContainer.new()
    # ... PanelContainer + VBox + Label("上書きしますか？") + 行作成 ...
```

各箇所:
1. メッセージ文言(「町に戻りますか？」「上書きしますか？」「ゲームを終了しますか？」「ダンジョンを削除しますか？」)
2. デフォルト選択(「いいえ」が default の場合が多い)
3. 「はい」「いいえ」の確定ハンドラ
4. オーバーレイ visibility 管理

これらを 1 つの ConfirmDialog Control にまとめる。各画面は `add_child(dialog)` し、`dialog.setup(message, default_index)` で初期化、`confirmed` / `cancelled` シグナルで結果を受ける。

## Goals / Non-Goals

**Goals:**
- 4 箇所のインライン実装を共通化
- ConfirmDialog の単体テスト
- 各画面のテストが外部挙動レベルで通る
- shop_screen の `_input_buy` / `_input_sell` の重複解消

**Non-Goals:**
- 3 択以上のダイアログ(将来の機能拡張)
- カスタム文言の自動翻訳
- ダイアログのアニメーション
- esc_menu / save_screen / dungeon_screen の入力ルーティング全体のリファクタ(C9 のスコープ外)

## Decisions

### Decision 1: ConfirmDialog は Control、setup() で初期化

**選択**:
```gdscript
class_name ConfirmDialog
extends Control

signal confirmed
signal cancelled

const OPTIONS: Array[String] = ["はい", "いいえ"]
const DEFAULT_NO_INDEX := 1
const DEFAULT_YES_INDEX := 0

var _menu: CursorMenu
var _menu_rows: Array[CursorMenuRow]
var _container: CenterContainer

func setup(message: String, default_index: int = DEFAULT_NO_INDEX) -> void:
    _build_ui(message)
    _menu.selected_index = default_index
    _menu.update_rows(_menu_rows)
    visible = true
    grab_focus()  # input 受け取り
```

**理由**:
- setup で再構築できる(再利用可能)
- default が「いいえ」(慎重) になる場面が多いので定数化
- 「はい」を default にしたい場面(セーブ画面の上書き確認は「はい」default のほうが UX 良い?)は呼び出し側で指定可

### Decision 2: ConfirmDialog 自身が `_unhandled_input` を持ち、MenuController.route を呼ぶ

**選択**:
```gdscript
func _unhandled_input(event):
    if not visible:
        return
    var consumed = MenuController.route(
        event, _menu, _menu_rows,
        _on_accept,
        _on_cancel
    )
    if consumed:
        get_viewport().set_input_as_handled()

func _on_accept():
    if _menu.selected_index == 0:
        confirmed.emit()
    else:
        cancelled.emit()
    visible = false

func _on_cancel():
    cancelled.emit()
    visible = false
```

**理由**:
- C4a の MenuController を完全に再利用
- 「はい」選択 → confirmed、「いいえ」選択 or ui_cancel → cancelled
- visibility は ConfirmDialog 自身が管理

### Decision 3: 呼び出し側はインスタンスを保持してシグナル接続

**選択**:
```gdscript
# save_screen.gd (例)
var _overwrite_dialog: ConfirmDialog

func _ready():
    _overwrite_dialog = ConfirmDialog.new()
    _overwrite_dialog.visible = false
    add_child(_overwrite_dialog)
    _overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
    _overwrite_dialog.cancelled.connect(_on_overwrite_cancelled)

func _show_overwrite_dialog(slot: int):
    _overwrite_slot = slot
    _overwrite_dialog.setup("上書きしますか？", 1)  # default = いいえ
```

**理由**:
- 1 度だけ instantiate して使い回す
- 表示時に `setup` で文言を再設定

### Decision 4: shop_screen の `_handle_list_input` ヘルパー

**選択**:
```gdscript
# shop_screen.gd
func _handle_list_input(
    event: InputEvent,
    count: int,
    on_accept: Callable,  # (selected_index: int) -> void
) -> bool:
    if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
        _toggle_tab()
        _rebuild()
        return true
    if count == 0:
        if event.is_action_pressed("ui_cancel"):
            _mode = Mode.TOP_MENU
            _selected_index = 0
            _rebuild()
            return true
        return false
    if event.is_action_pressed("ui_down"):
        _selected_index = (_selected_index + 1) % count
        _rebuild()
        return true
    elif event.is_action_pressed("ui_up"):
        _selected_index = (_selected_index - 1 + count) % count
        _rebuild()
        return true
    elif event.is_action_pressed("ui_accept"):
        on_accept.call(_selected_index)
        _rebuild()
        return true
    elif event.is_action_pressed("ui_cancel"):
        _mode = Mode.TOP_MENU
        _selected_index = 0
        _rebuild()
        return true
    return false

func _input_buy(event):
    var catalog := get_buy_catalog()
    _handle_list_input(event, catalog.size(), func(i): buy(catalog[i]))
    if _handled: get_viewport().set_input_as_handled()  # set_input は呼び出し側で

func _input_sell(event):
    var candidates := get_sell_candidates()
    _handle_list_input(event, candidates.size(), func(i):
        sell(candidates[i])
        if _selected_index >= get_sell_candidates().size():
            _selected_index = maxi(0, get_sell_candidates().size() - 1)
    )
```

**理由**:
- 80% 重複を解消
- buy / sell の違いはキャリッジ式に Callable で渡す
- 各 Mode の `_input_*` メソッドが 5 行程度に縮む

### Decision 5: dungeon_screen / dungeon_entrance / esc_menu の置換

**選択**: 各画面で同様のパターン。`_show_*_dialog()` メソッドで `setup` を呼んで visible にし、シグナルで確定処理を受ける。`_handle_*_input` メソッドは ConfirmDialog が input を消費する間、画面側は早期 return する。

**理由**:
- 既存の `_showing_return_dialog` フラグ等は ConfirmDialog の visible で代用できる
- 画面側の `_unhandled_input` で `if _confirm_dialog.visible: return` を冒頭に書く

## Risks / Trade-offs

- **[既存テストの assert]** `_overwrite_visible` などの bool フィールドを直接 assert しているテストがある → ConfirmDialog の `visible` を参照する形に書き換える、またはラッパー getter を追加
- **[`grab_focus()` の挙動]** ConfirmDialog が visible になった瞬間に focus を奪う必要があるが、Control の grab_focus は focus_mode が NONE/CLICK 以外で機能する → focus_mode を ALL にする
- **[`set_input_as_handled` の競合]** 画面とダイアログが同時に visible だと、画面の _unhandled_input にも到達する可能性 → ダイアログ visible 時、画面側で early return するルールを徹底
- **[「はい」 default vs 「いいえ」 default]** save_screen の上書きは「いいえ」default、esc の終了は「いいえ」default、dungeon_entrance の削除も「いいえ」default、dungeon_screen の帰還は「はい」 default の可能性あり → 各画面の現状挙動を確認しつつ、setup の引数で制御
- **[shop_screen の Callable lambda の Godot 互換性]** Godot 4.x の Callable lambda は capturing が制限されている可能性 → 実装時に確認、必要なら named function に
