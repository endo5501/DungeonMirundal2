## Context

`_unhandled_input` でメニュー入力(ui_up / ui_down / ui_accept / ui_cancel)を処理するコードが 18 ファイル以上で重複している。一例:

```gdscript
# title_screen.gd と town_screen.gd と temple_screen.gd で繰り返される
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_down"):
        _menu.move_cursor(1)
        _menu.update_rows(_rows)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("ui_up"):
        _menu.move_cursor(-1)
        _menu.update_rows(_rows)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("ui_accept"):
        confirm_selection()
        get_viewport().set_input_as_handled()
```

これに加えて、画面によっては:
- `ui_cancel` で back シグナル発行
- カーソル移動後にイラスト更新コールバック(`_update_illustration` 等)を呼ぶ
- `ui_accept` の前に disabled チェックを入れる

といった派生がある。重複だが微妙に違う。

C4b で keycode ベースの 8 画面を action ベースに移行する予定だが、その前に **共通ヘルパーを 1 箇所だけ用意して、すでに action ベースで動いている画面で先行採用する** ことで「共通ヘルパーが安定している」状態を作る。これにより、C4b / C5 / C6 / C7 で MenuController に依存する移行作業が安全になる。

`CursorMenu` (`src/dungeon/cursor_menu.gd`) は既に `move_cursor`, `update_rows` を提供している。本 change で追加する `MenuController` はその上に薄く乗るルーターレイヤーで、入力イベントを `CursorMenu` の操作に変換する。

## Goals / Non-Goals

**Goals:**
- 共通の `MenuController` (RefCounted) を新規追加し、ui_up / ui_down / ui_accept / ui_cancel の標準ルーティングを 1 箇所に集約
- すでに action ベースで動いている画面 3 つ(title_screen / town_screen / temple_screen)で先行採用
- `title_screen` の ESC キーを明示的 no-op として扱う(F041 対応)
- 単体テスト `tests/ui/test_menu_controller.gd` で各分岐をカバー
- 既存テスト(`test_title_screen.gd` 等)は 1 行も変えずに通過する(外部挙動不変)

**Non-Goals:**
- keycode ベースの画面の移行(C4b で実施)
- カスタムキーバインドのサポート(`ui_*` action は project.godot のデフォルトのまま)
- マウス入力サポート
- メニュー以外の入力(ダンジョン移動、戦闘コマンド等)のラップ
- すべての画面の `_unhandled_input` を即座に書き換える(段階的移行)

## Decisions

### Decision 1: MenuController は RefCounted で `route()` 1 メソッドのみ

**選択**:
```gdscript
class_name MenuController
extends RefCounted

# event を消費した場合 true を返す。呼び出し側は false なら自前のフォールバックを実行できる。
static func route(
    event: InputEvent,
    menu: CursorMenu,
    rows: Array[CursorMenuRow],
    on_accept: Callable,             # () -> void
    on_back: Callable = Callable(),  # () -> void or null Callable to ignore ui_cancel
    on_cursor_changed: Callable = Callable(),  # () -> void called after move_cursor
) -> bool:
    if event.is_action_pressed("ui_down"):
        menu.move_cursor(1)
        menu.update_rows(rows)
        if on_cursor_changed.is_valid(): on_cursor_changed.call()
        return true
    elif event.is_action_pressed("ui_up"):
        menu.move_cursor(-1)
        menu.update_rows(rows)
        if on_cursor_changed.is_valid(): on_cursor_changed.call()
        return true
    elif event.is_action_pressed("ui_accept"):
        on_accept.call()
        return true
    elif event.is_action_pressed("ui_cancel"):
        if on_back.is_valid():
            on_back.call()
            return true
        return false  # ui_cancel が登録されていなければ消費しない
    return false
```

**理由**:
- static method 1 つに集約することで、呼び出し側で MenuController インスタンスを保持する必要がない
- `Callable.is_valid()` で「コールバック未登録」を表現できる
- `on_back` を未指定にすれば ui_cancel は無視される(title_screen のような画面に適切)
- 戻り値が bool なので、呼び出し側で `set_input_as_handled()` の判断ができる

**代替案**:
- インスタンス化して `add_handler(action, callable)` で登録 → 過剰、5 つしかないアクションを Dictionary 管理するメリットなし
- Signal ベース(MenuController が内部で Signal を持つ) → static にすれば不要

### Decision 2: `set_input_as_handled` は呼び出し側の責務

**選択**: `MenuController.route` は `set_input_as_handled` を呼ばない。呼び出し側が戻り値を見て呼ぶ。

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if MenuController.route(event, _menu, _rows, confirm_selection, Callable(), _update_illustration):
        get_viewport().set_input_as_handled()
```

**理由**:
- `MenuController` は `Viewport` に依存しないようにする(テスト容易性)
- `set_input_as_handled` を呼ぶかどうかは画面の責務(背後画面に流したい場合もある)
- 呼び出し側のコードは依然として 2-3 行に集約される

### Decision 3: `on_back` 未登録時は ui_cancel を消費しない

**選択**: `on_back.is_valid()` が false のとき `route` は false を返す。呼び出し側は ESC を別途処理するか、何もしないかを判断できる。

**理由**:
- title_screen は ESC で何も起きないが、`set_input_as_handled` を呼ばないことで上位層(あれば)に流せる
- 「ESC 押してもメニューを閉じない」設計が明示的になる(F041 の意図に合致)

### Decision 4: 採用先は「すでに action ベース」「リスク低」「動作確認しやすい」3 画面

**選択**: title_screen, town_screen, temple_screen を C4a の採用先とする。

**理由**:
- 3 つともすでに `event.is_action_pressed("ui_*")` で書かれているので、置換が機械的
- title から town、town から各施設、温泉(temple)から町への戻り、と動作確認の動線がシンプル
- `tests/title_scene/test_title_screen.gd`, `tests/town/test_town_screen.gd`, `tests/town/test_temple_screen.gd` が外部挙動を網羅しているので、リファクタの安全網がある

**代替案**:
- shop_screen, dungeon_entrance も含める → これらは独自のサブメニュー(購入リスト、削除ダイアログ)を持つので C9(ConfirmDialog 抽出)後に移行するのが安全
- esc_menu, dungeon_screen → C4b と神クラス分解(C6/C7)で扱う

### Decision 5: title_screen の ESC は明示的 no-op

**選択**: title_screen の `_unhandled_input` で `ui_cancel` を検知して、何もしないが `set_input_as_handled` も呼ばない、という形を取る。`MenuController.route` の `on_back` を `Callable()` にすれば、route は false を返す。呼び出し側で「ESC は無視する」コメントを 1 行残す。

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if MenuController.route(event, _menu, _rows, confirm_selection):
        get_viewport().set_input_as_handled()
    # ESC は明示的に無視: タイトル画面では戻る先がない (on_back を渡さないことで route が false を返す)
```

**理由**:
- 「忘れた」のではなく「意図的に無視」が明示される
- F041 の指摘解消

### Decision 6: 単体テストは `MenuController` 単独で書く

**選択**: `tests/ui/test_menu_controller.gd` で `route()` の各分岐(ui_up / ui_down / ui_accept / ui_cancel あり/なし、未対応 event)をテスト。`CursorMenu` を実際に作って `selected_index` の変化を assert する。

**理由**:
- 共通ヘルパーは独立してテストすべき
- 採用先 3 画面のテストは無修正で通るのが原則(別途 regression check)

## Risks / Trade-offs

- **[on_cursor_changed の呼び出し漏れ]** 採用先で `on_cursor_changed` を渡し忘れるとイラスト更新がスキップされる可能性 → 採用先の既存テストでイラスト連動を assert していれば検出可能。town_screen のテストは `_update_illustration` を間接的にカバーしている。
- **[Callable.is_valid() の挙動]** GDScript の `Callable()` (引数なしコンストラクタ) は invalid になる前提だが、Godot 4.x で本当にそうかをテストで確認する必要がある → 1.1 で先にテストを書いて検証する。
- **[`ui_*` action の rebind 問題]** プレイヤーがキーバインドを変えると、現状の MenuController は project.godot の InputMap に依存する → 本 change のスコープ外。InputMap カスタマイズが将来必要になったら別 change で対応。
- **[戻り値 bool の運用]** `route` が false でも `set_input_as_handled` を呼びたい画面がない、という前提で OK。万が一あれば呼び出し側で個別に呼ぶ。
- **[テストヘルパーで `InputEventAction.new()` を作る必要がある]** action ベースのイベントを再現するため、`InputEventAction.new()` を使う(現状 `TestHelpers.make_key_event` は keycode ベース) → `TestHelpers.make_action_event(action: StringName, pressed: bool)` を追加で書く。
