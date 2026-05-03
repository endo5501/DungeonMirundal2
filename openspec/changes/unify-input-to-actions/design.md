## Context

現状の `project.godot` (`config/features=PackedStringArray("4.6")`) には `[input]` セクションが存在せず、`ui_up` / `ui_down` / `ui_accept` / `ui_cancel` 等の Godot デフォルトアクションのみが利用可能。ダンジョン移動キー(W/A/S/D + 矢印)はカスタムアクション化されておらず、各画面が直接 `event.keycode == KEY_W` のような形でハードコードしている。

入力ルートの分布(audit より):
- action ベース(`is_action_pressed`): 10 ファイル (title_screen, town_screen, temple_screen, character_creation, character_list, guild_menu, party_formation, dungeon_create_dialog, dungeon_entrance, shop_screen)
- keycode ベース(`event.keycode == KEY_*`): 9 ファイル (dungeon_screen, dungeon_scene 系の 3 ファイル, esc_menu, save/load_screen, main, combat_overlay, character_list の一部)

mixed: `character_list.gd` と `shop_screen.gd` は両方使っている。

`MenuController` (C4a で導入済み)は `is_action_pressed("ui_*")` ベースなので、keycode ベースの画面を action 化することで MenuController の対象範囲が広がる。

## Goals / Non-Goals

**Goals:**
- すべての `_unhandled_input` を action ベース(`event.is_action_pressed(...)`)に統一
- ダンジョン移動キー用のカスタムアクション(`move_forward` 等)を `project.godot` に定義
- M キーを `toggle_full_map` カスタムアクションに
- `MenuController` を本 change で扱う画面のうち、パターンに合致する箇所(save_screen, load_screen)で採用
- 各画面のテストも action ベースに書き換える
- エンドユーザのキー操作は完全に維持

**Non-Goals:**
- `MenuController` を esc_menu 全体に適用(C6 の神クラス分解時に行う)
- 戦闘オーバーレイの per-phase 入力ルータ化(C7 で行う)
- character_creation の Step ベース化(C5)
- カスタムキーバインドのプレイヤー設定 UI
- ゲームパッド対応(action ベースにすることで将来追加しやすくはなる)
- マウス入力

## Decisions

### Decision 1: カスタムアクション名は英語スネークケース、用途別に分類

**選択**:
```
move_forward    : KEY_W, KEY_UP
move_back       : KEY_S, KEY_DOWN
strafe_left     : KEY_A
strafe_right    : KEY_D
turn_left       : KEY_LEFT
turn_right      : KEY_RIGHT
toggle_full_map : KEY_M
```

**理由**:
- `move_*` / `turn_*` / `strafe_*` で意図が読み取れる
- ui_* は Godot のデフォルト(汎用 UI 操作)、`move_*` 等はゲーム固有
- 矢印キーと WASD の両方を 1 アクションに束ねることで、画面側で or 条件を書く必要がなくなる
- `toggle_full_map` は M キー専用のシングルバインド

**代替案**:
- 日本語名(`移動_前進` 等) → InputMap 名は内部 ID なので英語が無難
- `forward` / `back` のみ → 「strafe_left」のような移動軸の違いを区別できない

### Decision 2: 矢印キーと WASD の両方を 1 アクションにバインド

**選択**: `move_forward` に KEY_W と KEY_UP の両方をバインド。同様に `move_back` に KEY_S と KEY_DOWN。

**理由**:
- 既存の `dungeon_screen.gd` は両方をサポート(`KEY_W` と `KEY_UP` をどちらも処理)
- ユーザのキー操作を変えないため
- InputMap 1 アクションに複数 InputEventKey をバインドできる Godot の標準機能

**`strafe_left` / `strafe_right` / `turn_left` / `turn_right` は KEY_A/D と KEY_LEFT/RIGHT を別アクションに**:
- `dungeon_screen.gd` では現状 KEY_A=strafe_left, KEY_LEFT=turn_left のように別アクションに割り当てている
- WASD は strafe(平行移動)、矢印は turn(回転)で意味が違う
- これは現状仕様を維持

### Decision 3: `project.godot` の `[input]` セクションは Godot エディタで編集する

**選択**: `[input]` セクション追加は Godot エディタの Project Settings → Input Map で GUI 編集してファイルを生成する。手書きで `events` の binary blob 風のフォーマットを作らない。

**理由**:
- Godot の InputEvent シリアライズは `events=PackedStringArray` ではなく `events=Array[Resource]` 風のテキスト表現で、手書きはエラーが出やすい
- エディタで作ったあと `project.godot` をコミットすればよい
- 実装担当者は Godot を立ち上げる必要があるが、移動キー追加は 7 アクション × 2-4 keys = 20 程度のクリック作業、5 分で済む

**代替案**: `project.godot` を手書き → 動作不安定、保守困難

### Decision 4: keycode → action 置換は機械的、テストもセットで

**選択**: 各画面の `_unhandled_input` を 1 ファイルずつ書き換え、対応するテストファイルも `make_key_event` を `make_action_event` に置き換える。1 ファイル 1 commit。

**例**:
```gdscript
# Before (dungeon_screen.gd)
func _unhandled_input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_W, KEY_UP: _move_forward()
            KEY_S, KEY_DOWN: _move_back()
            ...

# After
func _unhandled_input(event):
    if event.is_action_pressed("move_forward"): _move_forward()
    elif event.is_action_pressed("move_back"): _move_back()
    ...
```

**理由**:
- 1 ファイル単位で進めることで、レビュー単位が明確
- `make_action_event` がテスト側で必要(C4a で追加済みのはず)

### Decision 5: save_screen / load_screen は MenuController 採用

**選択**: `save_screen.gd` / `load_screen.gd` の `_unhandled_input` を `MenuController.route(event, _menu, _menu_rows, _on_slot_selected, back_requested.emit)` の形に書き換える。上書き確認ダイアログの入力は別ハンドラに残す。

**理由**:
- パターンが MenuController に完全に合致する
- C9 で ConfirmDialog を抽出する際、上書き確認ダイアログも MenuController + ConfirmDialog で書き直せる(本 change のスコープ外)

**combat_overlay / esc_menu は MenuController 採用しない**:
- esc_menu は 11 個の View 状態を持ち、MenuController の単純な「accept で確定」モデルに合わない部分がある(C6 で対応)
- combat_overlay も 7 phase の入力ルータ化が C7 で予定されているので、本 change では keycode → action 化のみ

### Decision 6: dungeon_screen の M キーは `toggle_full_map`

**選択**: `KEY_M` ハードコードを `event.is_action_pressed("toggle_full_map")` に置換。

**理由**:
- 他の dungeon 移動キーと一貫性
- 将来別キーへの rebind を許容する余地

### Decision 7: 既存の `make_test_map` フィクスチャは維持

**選択**: 本 change で「テストヘルパーの全面刷新」は行わない。`make_action_event` を追加し、必要に応じて呼び出すだけ。`make_key_event` も残す(他のキー入力テスト用)。

**理由**:
- ゲームコントローラ等、ui_* 以外のキー直接テストは将来必要になる可能性
- `make_key_event` を撤廃する積極的理由がない

## Risks / Trade-offs

- **[`project.godot` の手動編集ミス]** GUI で編集することを規約として強調。直接編集ガイドを書かない。
- **[InputMap の優先順位]** Godot は project.godot に書かれた InputMap が default override される。デフォルト ui_* に WASD を上書き bind すると挙動が崩れる可能性 → 新規アクション(`move_forward` 等)を追加するだけにし、既存 `ui_*` には触らない。
- **[テスト書き換え量]** action ベースに変えると `make_key_event(KEY_W)` を `make_action_event("move_forward")` に置換するが、Godot の InputEventAction は内部的に project.godot 設定とは独立して動くので、テスト時に「KEY_W で `is_action_pressed("move_forward")` が true になる」を担保するには project.godot がロードされている必要がある。GUT 実行時は project.godot がロードされるので問題ないはずだが、検証する。
- **[`character_list.gd` / `shop_screen.gd` の混在対応]** action と keycode の両方が同じファイルにある状態を解消する必要がある → 全部 action に揃える。
- **[`main.gd` の ESC 処理]** トップレベル ESC は今 `KEY_ESCAPE` 直接マッチ。`ui_cancel` (デフォルト ESC + バックスペース? 等) に変えると不要なキーで ESC メニューが開く可能性 → Godot のデフォルトでは `ui_cancel` は ESC のみなので問題なし。ただし将来 `ui_cancel` に別キーを bind したくなった時のリスクは認識しておく。
- **[ENTER と SPACE と KP_ENTER]** save/load で `KEY_ENTER, KEY_KP_ENTER, KEY_SPACE` をすべて受けている → `ui_accept` に統一できる(Godot のデフォルトでは ENTER, SPACE, KP_ENTER がすべて bind されている)。
