## Context

GDScript 4.x は `var x = ...` で右辺の戻り値型から推論できる場合は推論するが、`Dictionary.get(key)` は `Variant` を返すため推論が緩む。各暗黙 Variant は単独では問題ないが、ホットパス(turn_engine が毎ターン呼ぶ `_pending_commands.get()`)で型情報が失われると、`cmd.execute()` などが「メソッド存在チェックを実行時に行う」コードになる。

監査で挙がった 11 箇所のうち 9 箇所は副次的だが、`turn_engine.gd:64,98` は性能・可読性の両方で型を入れた方が良い。

`Character.to_dict` が `race.resource_path.get_file().get_basename()` で id を抽出している件(F047)も同根。`.tres` をリネームすると id が壊れるため、`RaceData.id: StringName` を export すべき。

## Goals / Non-Goals

**Goals:**
- 暗黙 Variant 11 箇所を明示型に
- `Array[Vector2i]` / `Array[Array]` などの typed array シグネチャを導入
- `RaceData.id` / `JobData.id` を `.tres` の export フィールドとして追加
- `Character.to_dict` の id 取得ロジックを `id` フィールド参照に
- `GameState.new_game` と `_ready` を `_initialize_state()` ヘルパーに統合
- `Inventory.spend_gold(0)` を no-op true に
- 既存テストが通り続ける(`.tres` の id 値が空でも fallback として resource_path から取れるよう移行期間を作る)

**Non-Goals:**
- 全コードベースの型強化(本 change は監査で挙がった箇所のみ)
- セーブフォーマット変更(`race_id` 文字列の値は変えない)
- データマイグレーション API の整備
- パフォーマンス測定(本 change は型強化が主、性能改善は副次効果)

## Decisions

### Decision 1: `id: StringName` フィールドを RaceData / JobData に追加

**選択**:
```gdscript
# race_data.gd
class_name RaceData
extends Resource

@export var id: StringName  # MUST equal the .tres filename's basename
@export var race_name: String
# ...
```

`.tres` ファイル側に id 値を手動で埋める(`id = &"human"` のような形)。

**理由**:
- ファイル名から id を推測する fragility を排除
- export フィールドなので Godot エディタで設定可能
- StringName で identity 比較が高速

### Decision 2: 移行期間を作る — id が空ならファイル名 fallback

**選択**:
```gdscript
# Character.to_dict
func _resolve_race_id() -> String:
    if race != null and race.id != &"":
        return String(race.id)
    push_warning("RaceData.id is empty, falling back to resource_path")
    return race.resource_path.get_file().get_basename()
```

**理由**:
- 全 `.tres` を一気に更新するのは非現実的
- fallback で警告を出し、徐々に移行
- 全 `.tres` 更新後に fallback を削除する別 change を切る(または C11 quick wins で)

### Decision 3: turn_engine の `_pending_commands.get()` は型注釈 + null ガード

**選択(実装後の確定形)**:
```gdscript
# Before
var cmd = _pending_commands.get(idx)
# After
var cmd: RefCounted = _pending_commands.get(idx, null) as RefCounted
if cmd == null:
    continue
```

**理由**:
- ホットパス(ターン解決毎に呼ばれる)で型推論を確実に
- `as <T>` で null になるのは型ミスマッチか not present の 2 ケース、いずれも skip 可

**当初案からの逸脱**:
- 当初は `var cmd: CombatCommand` を提案したが、リポジトリには `CombatCommand` 基底クラスは存在せず、`AttackCommand` / `DefendCommand` / `EscapeCommand` / `ItemCommand` はすべて直接 `RefCounted` を継承している。
- 共通基底クラスの導入は本 change のスコープ外の独立した refactor になるため、現存する最も近い共通静的型である `RefCounted` を採用した。
- 後続の `is DefendCommand` / `is ItemCommand` / `as DefendCommand` / `as ItemCommand` チェックは `RefCounted` 経由でも従来通り機能する。
- もし将来 `class_name CombatCommand extends RefCounted` を導入する場合は、`turn_engine.gd:65, 101` の `as RefCounted` を `as CombatCommand` に置き換える局所的な変更で済む。

### Decision 4: `get_party_characters()` は `Array[Array]` 型

**選択**:
```gdscript
# Before
func get_party_characters() -> Array:
    return [_front_row.duplicate(), _back_row.duplicate()]

# After
func get_party_characters() -> Array[Array]:
    return [_front_row.duplicate(), _back_row.duplicate()]
```

注: 内側の `Array` は依然として untyped(`Array[Variant]` 相当)。`Array[Character]` にできない理由は、`null` を含むため。`Array[Character]` は null を許容するが、Godot の `is` 経由の判定で問題が出ないか実装時確認。

**理由**:
- 戻り値の構造を明示
- 呼び出し側 `for row in rows: for ch in row` がそのまま書ける(typed iteration)

### Decision 5: `mark_visible(cells: Array[Vector2i])`

**選択**:
```gdscript
# explored_map.gd
func mark_visible(cells: Array[Vector2i]) -> void:
    ...
```

**理由**:
- 唯一の呼び出し元 (`dungeon_screen.gd:80`) はすでに `Array[Vector2i]` を渡している
- 型が緩い理由がない

### Decision 6: GameState の `_initialize_state()` ヘルパー

**選択**:
```gdscript
# game_state.gd
func _ready() -> void:
    _initialize_state()

func new_game() -> void:
    _initialize_state(true)

func _initialize_state(reset_for_new_game: bool = false) -> void:
    if item_repository == null:
        var loader := DataLoader.new()
        item_repository = loader.load_all_items()
    if reset_for_new_game or guild == null:
        guild = Guild.new()
    if reset_for_new_game or dungeon_registry == null:
        dungeon_registry = DungeonRegistry.new()
    if reset_for_new_game or inventory == null:
        inventory = Inventory.new()
        if reset_for_new_game:
            inventory.gold = INITIAL_GOLD
    if reset_for_new_game:
        game_location = LOCATION_TOWN
        current_dungeon_index = -1
```

**理由**:
- `_ready` と `new_game` の重複を排除
- 「項目を 1 つ追加するときに 2 箇所触る」フットガンの解消(F030)
- `item_repository` は new_game でも再構築しない(セッション単位でキャッシュ)

### Decision 7: `Inventory.spend_gold(0)` は true 返却

**選択**:
```gdscript
# inventory.gd
func spend_gold(amount: int) -> bool:
    if amount == 0:
        return true  # no-op success
    if gold < amount:
        return false
    gold -= amount
    return true
```

**理由**:
- 0 ゴールド消費は概念上常に成功
- 現状の false 返却は呼び出し元の意図を裏切る(F028)
- Temple revive で「金額 0 でも成功扱い」にしたい状況が将来出るかもしれない

### Decision 8: `Item.get_target_failure_reason(target: Variant, ctx)` のドキュメント

**選択**:
```gdscript
# item.gd
# target: Character | CombatActor (暗黙的に "ターゲットになり得るオブジェクト")
# 静的型は Variant、is チェックで動的に判別する。
func get_target_failure_reason(target: Variant, ctx: ItemUseContext) -> String:
    ...
```

**理由**:
- 真の interface 抽象化(`Targetable`)はオーバーキル
- コメントで型を明示することで、読み手が混乱しない

## Risks / Trade-offs

- **[fallback 経路の長期残留]** id フィールド未設定の `.tres` を fallback で受け続けると、いつまで経っても警告が出続ける → 全 `.tres` 更新を別 quick win タスクとし、その後 fallback を削除する別 change を立てる(Tier 6 の C11 で吸収)。
- **[既存セーブの race_id 文字列とのズレ]** `.tres` の id を明示すれば、Character.to_dict の出力は不変(同じ文字列)。既存セーブのロードも不変。
- **[`Array[Array]` 型の制約]** Godot の typed array は内側の型を `Variant` にできない場合がある → 実装時に確認、もし NG なら `Array` のまま PR コメントで諦める。
- **[`as CombatCommand` の挙動]** Godot の `as` キャストは型違いで null を返す。null チェックを追加する必要がある。turn_engine の挙動が変わらないか実装時確認。
- **[GameState `_initialize_state` の reset_for_new_game フラグ]** ブール引数は smell だが、2 経路を 1 関数にまとめる選択。代替として `_initialize_session()` と `start_new_game()` の 2 関数に分ける形もあり、実装時に選ぶ。
