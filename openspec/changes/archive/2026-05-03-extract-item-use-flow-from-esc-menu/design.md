## Context

現在の `esc_menu.gd` (772 LOC) の View enum:
```
MAIN_MENU
  ├ PARTY_MENU
  │   ├ STATUS
  │   ├ ITEMS              ─┐
  │   ├ EQUIPMENT           │
  │   ├ EQUIPMENT_CHARACTER │── 抽出対象
  │   ├ EQUIPMENT_SLOT      │
  │   ├ EQUIPMENT_CANDIDATE │
  │   ├ ITEM_USE_TARGET     │
  │   └ ITEM_USE_CONFIRM   ─┘
  └ QUIT_DIALOG
```

抽出後:
```
MAIN_MENU
  ├ PARTY_MENU
  │   ├ STATUS
  │   ├ ITEMS_FLOW       (-> ItemUseFlow Control)
  │   └ EQUIPMENT_FLOW   (-> EquipmentFlow Control)
  └ QUIT_DIALOG
```

各 Flow は `Control` として独立し、`EscMenu` は `add_child(flow)` してシグナルで結果を受け取る。

## Goals / Non-Goals

**Goals:**
- `EscMenu` の View enum を 11 値から 6 値に縮小
- アイテム使用と装備変更を独立 Control として抽出
- 抽出した `ItemUseFlow` を C7 (combat_overlay) で再利用可能にする
- 既存の外部挙動(キーボード操作・遷移シナリオ)を完全に維持
- 内部状態(`_items_index`, `_item_use_instance`, etc.)を `EscMenu` から消す
- 各 Flow の単体テストを追加(EscMenu に依存せず、Flow だけ生成して挙動を検証)

**Non-Goals:**
- ステータス表示(`STATUS` ビュー)の抽出 — 単純な Label 表示だけなので EscMenu に残す
- 終了確認(`QUIT_DIALOG`)の抽出 — C9 で `ConfirmDialog` 抽出の一環として処理
- 装備変更の Flow ロジック自体の変更 — 抽出のみ、振る舞いは維持
- アイテム使用の Result 表示の抽出 — Flow の中に残す
- 設定画面(`MAIN_MENU_DISABLED` の 3 番)の追加

## Decisions

### Decision 1: ItemUseFlow は Control、内部に SubView enum を持つ

**選択**:
```gdscript
class_name ItemUseFlow
extends Control

signal flow_completed(message: String)

enum SubView { SELECT_ITEM, SELECT_TARGET, CONFIRM, RESULT }

var _sub_view: SubView = SubView.SELECT_ITEM
var _selected_item: ItemInstance
var _selected_target  # Character or null
var _context: ItemUseContext
var _inventory: Inventory
var _party: Array[Character]

func setup(context: ItemUseContext, inventory: Inventory, party: Array[Character]) -> void: ...
func _unhandled_input(event): ... # MenuController.route + sub_view ごとの分岐
```

**理由**:
- Flow 内の状態遷移は外部から見える必要がない(完了 or キャンセルのみ)
- `flow_completed(message)` で結果を呼び出し元に渡す
- `setup(context, ...)` で「フィールドで使用」 vs 「戦闘で使用」の文脈を切り替えられる(C7 で combat_overlay が活用)

### Decision 2: EquipmentFlow も同形

**選択**:
```gdscript
class_name EquipmentFlow
extends Control

signal flow_completed

enum SubView { CHARACTER, SLOT, CANDIDATE }
# ... 同様
```

**理由**:
- `ItemUseFlow` と同じパターンに揃えることで、保守者の認知負荷を下げる
- C7 では `EquipmentFlow` は再利用しない(combat 中に装備変更しない)が、構造の対称性は維持

### Decision 3: EscMenu はシグナル受信でビューを戻す

**選択**:
```gdscript
# EscMenu
func _on_party_menu_select():
    if selected == PARTY_IDX_ITEMS:
        _show_item_use_flow()

func _show_item_use_flow():
    var ctx = ItemUseContext.new(in_combat=false, ...)
    _item_use_flow.setup(ctx, GameState.inventory, _get_party_chars())
    _item_use_flow.visible = true
    # PARTY_MENU の visibility は false に
    _current_view = View.ITEMS_FLOW

func _on_item_use_flow_completed(message: String):
    _item_use_flow.visible = false
    # PARTY_MENU を再表示
    _current_view = View.PARTY_MENU
    # オプションで result message を Toast 表示するなど
```

**理由**:
- Flow と EscMenu の責務分離が明確
- Signal で戻ることで疎結合
- `_current_view` は EscMenu 内のルータ用、Flow 内の状態は Flow が保持

### Decision 4: 入力消費は Flow が責任を持つ

**選択**: Flow 表示中、`EscMenu._unhandled_input` は Flow に委譲し、Flow 側で `set_input_as_handled` を呼ぶ。EscMenu のメインメニューは `visible = false` で非表示にすることで input が届かない。

**理由**:
- Flow が表示中は他のビューに input が届かない
- 既存の View 切替パターン(`_current_view` で分岐)と整合

### Decision 5: ItemUseFlow と CombatOverlay の再利用

**選択**: C7 では CombatOverlay が `ItemUseFlow` を子 Control として add_child する。`ItemUseContext.in_combat = true` を渡すことで戦闘中専用のフィルタ(逃走アイテムは戦闘中のみ等)が動く。

**注**: 本 change のスコープでは ItemUseFlow が両方で使えるよう設計するだけ。実際の CombatOverlay 側の利用は C7 で行う。

### Decision 6: テスト戦略

**選択**:
- `tests/esc_menu/flows/test_item_use_flow.gd` — Flow 単体テスト。`ItemUseFlow.new()` をシーンに add_child せず、直接 setup → handle_input → assert
- `tests/esc_menu/flows/test_equipment_flow.gd` — 同様
- `tests/esc_menu/test_esc_menu.gd` — 既存テストのうち、内部状態(`_items_index` 等)を直接 assert している箇所を「外部観測可能シナリオ」に書き換え

**理由**:
- Flow 単体でテストできるようにすることが本 change の目的の 1 つ
- EscMenu 統合テストは「Flow が呼ばれた」「flow_completed が伝播した」を検証する形に

### Decision 7: ファイル配置

**選択**:
- `src/esc_menu/flows/item_use_flow.gd`
- `src/esc_menu/flows/equipment_flow.gd`
- `tests/esc_menu/flows/test_item_use_flow.gd`
- `tests/esc_menu/flows/test_equipment_flow.gd`

**理由**:
- `flows/` サブディレクトリで Flow という概念を明示
- 将来、設定画面なども Flow として追加するときの場所が決まる

## Risks / Trade-offs

- **[State migration の漏れ]** `_items_index`, `_item_use_target_index`, `_item_use_confirm_index`, `_equipment_*_index` などのフィールドを Flow 内に正しく移植する必要 → 1 ファイルずつ抽出、grep で残存参照を確認
- **[既存テストの破壊]** プライベート状態を assert しているテストはリライト必要 → audit して数を確認、安全に書き換え
- **[Flow visibility の管理]** `visible = false` で input を遮断する設計だが、レイアウトが消えると child の `_ready` が再呼び出しされる挙動が Godot にあるかを検証 → 実装時に確認、必要なら CanvasLayer 自体を再構築する
- **[`set_input_as_handled` の二重呼び出し]** EscMenu と Flow の両方で呼ぶと意味的に問題はないが、無駄 → EscMenu 側は Flow visible 中は `_unhandled_input` を early return する
- **[ItemUseContext の責務]** 既に `src/items/conditions/item_use_context.gd` がある → これを Flow に渡す形にすれば追加クラス不要。F043 で context を `src/items/` に移動する話があるが、本 change では現状のまま使う(C11 で整理)
