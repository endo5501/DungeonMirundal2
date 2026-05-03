## Context

現状の `EncounterOverlay`(`src/dungeon_scene/encounter_overlay.gd`)は、自身が `_ready` で `_build_ui` を呼び、シンプルな遭遇 UI(モンスター名表示)を構築する。`CombatOverlay extends EncounterOverlay` だが、`CombatOverlay._ready` は `super._ready()` を呼ばないため、親の `_build_ui` が走らない(暗黙の契約)。

`EncounterCoordinator._ready` で `EncounterOverlay.new()` を直接 instantiate するため、テストや単純な遭遇シナリオではこの fallback 実装が動く。

問題:
- 「親が _ready をスキップされることを期待している」のは Godot の慣習に反する
- 単純な遭遇 UI の責務が `EncounterOverlay` にあるのか `SimpleEncounterOverlay` という別物に切り出すべきかが曖昧

main.gd の `_unhandled_input` の 3 ゲート(F023)は、画面が増えるたびに hard-code した条件が増えるリスク。`Control` の virtual method `consumes_global_esc() -> bool` を導入して、各画面が自身の input gate を宣言する形が理想。

`_refresh_combat_overlay_dependencies` (F035)は `_setup_encounter_coordinator` で同じことをやっており、dungeon_screen attach のたびに呼ぶ意味がない(guild は session 単位で変わらない)。

## Goals / Non-Goals

**Goals:**
- `EncounterOverlay` を抽象基底化、`SimpleEncounterOverlay` を切り出す
- main.gd の input ゲートを 1 つの仕組みに統合
- dead defensive code の削除
- DungeonEntrance に Guild 参照を渡し、画面側で has_party_members() を fresh に query

**Non-Goals:**
- マルチフロアダンジョン対応(別 feature change)
- EncounterCoordinator のリアーキ
- main.gd 全体のリファクタ(本 change はピンポイント)
- screen-navigation の全面ルータ化

## Decisions

### Decision 1: EncounterOverlay を抽象に、SimpleEncounterOverlay を新規追加

**選択**:
```gdscript
# encounter_overlay.gd (抽象)
class_name EncounterOverlay
extends CanvasLayer

signal encounter_resolved(outcome: EncounterOutcome)

var _is_active: bool = false

# 各サブクラスが実装する
func start_encounter(monster_party: MonsterParty) -> void:
    push_error("EncounterOverlay.start_encounter must be overridden")
```

```gdscript
# simple_encounter_overlay.gd (具象)
class_name SimpleEncounterOverlay
extends EncounterOverlay

func _ready():
    _build_ui()
    visible = false

func _build_ui(): ...
func start_encounter(monster_party):
    _is_active = true
    visible = true
    # シンプル UI で表示、ui_accept で encounter_resolved 発行
```

```gdscript
# combat_overlay.gd
class_name CombatOverlay
extends EncounterOverlay

func _ready():
    _build_combat_ui()  # super._ready() を呼ばないことに違和感がなくなる
    visible = false
```

**理由**:
- 親が抽象になることで、サブクラスが自由に UI を構築できる
- `super._ready()` を呼ばないことが「設計通り」になる
- `SimpleEncounterOverlay` という名前で「単純な遭遇 UI」だと明示

### Decision 2: EncounterCoordinator._ready で SimpleEncounterOverlay を instantiate

**選択**:
```gdscript
# encounter_coordinator.gd
func _ready():
    if _overlay == null:
        _overlay = SimpleEncounterOverlay.new()
        add_child(_overlay)
    _overlay.encounter_resolved.connect(_on_encounter_resolved)
```

**理由**:
- main.gd は `set_overlay(_combat_overlay)` を呼び出して上書きするので、デフォルトは SimpleEncounterOverlay でよい
- テストやシンプルな単独実行で SimpleEncounterOverlay が動く

### Decision 3: main.gd の input ゲートを `_should_open_esc_menu()` メソッドに集約

**選択**:
```gdscript
# main.gd
func _unhandled_input(event):
    if event.is_action_pressed("ui_cancel") and _should_open_esc_menu():
        _on_esc_key_pressed()
        get_viewport().set_input_as_handled()

func _should_open_esc_menu() -> bool:
    if _current_screen is TitleScreen:
        return false
    if _esc_menu.is_menu_visible():
        return false
    if _encounter_coordinator != null and _encounter_coordinator.is_encounter_active():
        return false
    return true
```

**理由**:
- ゲート条件を 1 メソッドに集約することで、追加・削除の影響範囲が明確
- 本 change のスコープでは「virtual method による screen self-declaration」までは行わない(過剰)
- 将来的な拡張(将来的なゲートの追加)もこの 1 メソッドを編集するだけ

### Decision 4: `_refresh_combat_overlay_dependencies` を削除

**選択**: `_setup_encounter_coordinator` で `_combat_overlay.setup_dependencies(GameState.guild, _equipment_provider, _encounter_rng)` を 1 度だけ呼ぶ。`_attach_encounter_coordinator_to_screen` からは削除。

**注意**: `_setup_encounter_coordinator` は `main._ready` で呼ばれるが、その時点で `GameState.guild` は null の可能性がある(`new_game` 前)。`_combat_overlay.setup_dependencies` は guild 設定タイミングで呼ぶ必要がある。

**改修案**:
- `_combat_overlay.setup_dependencies` の呼び出しを `_on_start_new_game` および `_load_game` の中で行う(guild が確定したタイミング)
- これにより `_refresh_combat_overlay_dependencies` は完全に不要になる

### Decision 5: DungeonEntrance の setup シグネチャ変更

**選択**:
```gdscript
# Before
screen.setup(GameState.dungeon_registry, has_party)

# After
screen.setup(GameState.dungeon_registry, GameState.guild)
```

DungeonEntrance 内部で `_guild.has_party_members()` を必要に応じて参照する。

**理由**:
- 「party を変えるための画面遷移が起きうる」現状ではないが、将来 entrance UI の中でパーティ変更を許容しても整合
- フィールドを bool スナップショットで保持するより、参照を保持する方が future-proof

## Risks / Trade-offs

- **[`SimpleEncounterOverlay` の挙動が一致するかの検証]** 既存テストが `EncounterOverlay` を直接 instantiate している場合、`SimpleEncounterOverlay` への置換が必要 → grep で確認、置換
- **[`super._ready` 呼び出しチェック]** Godot 4.x では super._ready を呼ばなくても親の _ready が走らないだけ。エラーにはならない → CombatOverlay と FullMapOverlay などの既存サブクラスが super を呼んでいないことを確認
- **[`_should_open_esc_menu` の test 性]** main.gd は単体テストしにくい(autoload 含むため)が、ロジック自体は単純
- **[`DungeonEntrance.setup` のシグネチャ変更]** 既存テスト `test_dungeon_entrance.gd` を更新する必要がある → 引数を Guild 参照に変える
