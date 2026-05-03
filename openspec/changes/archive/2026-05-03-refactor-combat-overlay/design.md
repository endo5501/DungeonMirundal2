## Context

現在の `combat_overlay.gd` の責務:
1. UI 構築(`_build_combat_ui`、4 つの panel と log を配置)
2. 戦闘開始(`start_encounter` で TurnEngine 構築)
3. Phase 状態機械(`_begin_command_phase`, `_prompt_next_actor`, `_advance_to_next_actor` 等)
4. コマンド処理(`_handle_command_choice`)
5. アイテム使用サブフロー(`_open_item_selector` 〜 `_commit_item_command`)
6. ターン解決(`_resolve_turn_now`, `_play_log_sequentially`)
7. 戦闘終了処理(`_finalize_battle` で経験値・ゴールド・レベルアップ計算)
8. 結果表示(`show_result`, `_on_result_confirmed`)
9. Phase ごとの入力ルーティング(`_handle_*_key` 5 メソッド)

本 change では (5)、(7)、(9) を切り出して、(1)(2)(3)(4)(6)(8) のオーケストレーション役にする。

C6 完了後は `ItemUseFlow` が独立 Control として in_combat=true 対応で動くので、(5) は ItemUseFlow に完全に置き換えられる。

## Goals / Non-Goals

**Goals:**
- `combat_overlay.gd` を 552 LOC から 350 LOC 程度に縮小
- 報酬計算ロジックを `BattleResolver` に分離(ユニットテストしやすい RefCounted)
- 入力ルーティングを `CombatInputRouter` に集約
- アイテム使用を `ItemUseFlow`(C6)で再利用、C7 で完全に置換
- 死んだターゲットへの再ターゲット(F037)を combat log に表示
- await ベースのログ表示を Timer ノードに置換し、キャンセル可能化(F038)
- 既存テストの外部観測可能シナリオは無修正で通過

**Non-Goals:**
- 戦闘システムの仕様変更(コマンド種別追加、ダメージ計算変更等)
- TurnEngine の全面リファクタ
- BattleSummary の永続化(セーブ対象には含めない)
- マルチターン戦闘の AI 強化

## Decisions

### Decision 1: BattleResolver は RefCounted、`resolve_rewards(turn_engine, rng) -> BattleSummary`

**選択**:
```gdscript
class_name BattleResolver
extends RefCounted

# 戦闘が CLEARED で終了した場合の報酬を計算する。
# CLEARED 以外(逃走、全滅)では BattleSummary.empty() を返す。
static func resolve_rewards(turn_engine: TurnEngine, rng: RandomNumberGenerator) -> BattleSummary:
    var outcome = turn_engine.outcome()
    if outcome == null or outcome.result != EncounterOutcome.Result.CLEARED:
        return BattleSummary.empty()
    var participants = _collect_participant_characters(turn_engine)
    var dead = _collect_dead_monsters(turn_engine)
    var levels_before = participants.map(func(c): return c.level)
    var share = ExperienceCalculator.award(participants, dead)
    var gold = _compute_gold_drop(dead, rng)
    var level_ups = _detect_level_ups(participants, levels_before)
    return BattleSummary.new(share, gold, level_ups)
```

**理由**:
- ドメインロジックを UI から切り離す
- RefCounted で副作用なし(award の中で character.gain_experience は呼ばれるが、これは BattleResolver の責務範囲)
- 単体テストが書きやすい(`TurnEngine` のスタブを渡せばよい)

### Decision 2: BattleSummary は 3 フィールドの値オブジェクト

**選択**:
```gdscript
class_name BattleSummary
extends RefCounted

var gained_experience: int
var gained_gold: int
var level_ups: Array  # [{name: String, new_level: int}, ...]

func _init(p_exp: int = 0, p_gold: int = 0, p_level_ups: Array = []) -> void:
    gained_experience = p_exp
    gained_gold = p_gold
    level_ups = p_level_ups

static func empty() -> BattleSummary:
    return BattleSummary.new()
```

**理由**:
- combat_overlay.show_result が `(outcome, level_ups)` ではなく `(outcome, summary)` を受ける形に統一
- summary が `outcome` を持っていてもよいが、`outcome` は既存の `EncounterOutcome` クラスがあり、責務が違うので分離

### Decision 3: CombatInputRouter は phase 引数ベースの static method

**選択**:
```gdscript
class_name CombatInputRouter
extends RefCounted

# Returns true if event was consumed by the given phase's panel.
static func route(
    event: InputEvent,
    phase: CombatOverlay.Phase,
    panels: Dictionary,  # {command_menu, target_selector, item_selector, result_panel}
) -> bool:
    match phase:
        CombatOverlay.Phase.COMMAND_MENU:
            return _route_to_panel(event, panels.command_menu)
        CombatOverlay.Phase.TARGET_SELECT, CombatOverlay.Phase.ITEM_TARGET:
            return _route_to_panel(event, panels.target_selector)
        # ITEM_SELECT は ItemUseFlow が直接処理するので CombatInputRouter は handle しない
        CombatOverlay.Phase.RESULT:
            return _route_to_panel(event, panels.result_panel)
    return false
```

**理由**:
- phase の switch を 1 箇所にまとめる
- Phase enum を引数で受けることで、CombatOverlay が状態を管理する権限を保つ
- panel の MenuController-like API(`move_up` / `move_down` / 選択確定)はそれぞれの panel が持っているので、CombatInputRouter は薄いラッパー
- ITEM_SELECT phase は ItemUseFlow が visible 中に自身の input を処理するので、ここでは扱わない

### Decision 4: ItemUseFlow を combat_overlay の child に追加

**選択**: `combat_overlay._build_combat_ui` で `_item_use_flow = ItemUseFlow.new()` を add_child する。`_open_item_selector` の代わりに `_show_item_use_flow()` を呼び、ItemUseFlow.flow_completed シグナルで戻りを受ける。

```gdscript
func _show_item_use_flow():
    var ctx = ItemUseContext.make(true, true, [])  # in_combat = true
    var party_chars = _collect_participant_characters_alive()
    _item_use_flow.setup(ctx, GameState.inventory, party_chars)
    _item_use_flow.visible = true
    _command_menu.hide_menu()
    _current_phase = Phase.ITEM_SELECT  # ItemUseFlow が visible

func _on_item_use_flow_completed(message: String):
    _item_use_flow.visible = false
    if message == "":
        # キャンセル → コマンドメニューに戻る
        _current_phase = Phase.COMMAND_MENU
        _command_menu.show_for(_turn_engine.party[_current_actor_index])
    else:
        # アイテム使用完了 → 次のアクター or ターン解決へ
        _advance_to_next_actor()
```

**理由**:
- C6 で抽出した ItemUseFlow を完全に再利用
- 旧 `_pending_item_instance`, `_open_item_selector`, `_on_item_selector_item_selected`, `_valid_item_targets`, `_commit_item_command` を削除できる
- `CombatItemSelector` (`src/dungeon_scene/combat_item_selector.gd`)も場合によっては撤廃可能(ItemUseFlow の SELECT_ITEM サブビューに統合)

**注意**: `CombatItemSelector` を撤廃するか維持するかは判断が必要。既存テストが直接参照している場合があるので、判断は実装時に行う。

### Decision 5: TurnReport にリターゲット情報を追加

**選択**:
```gdscript
# turn_report.gd の ReportAction クラス
class ReportAction:
    var actor_name: String
    var action_type: int  # ATTACK / DEFEND / ITEM / ESCAPE
    var target_name: String
    var damage: int
    var retargeted_from: String = ""  # 元のターゲット名(空なら retargetなし)
    # ...
```

`turn_engine.gd:_resolve_attack` で死んだターゲットを検出した時、`_pick_living_same_side_as` で代替ターゲットを選びつつ、ReportAction に元のターゲット名を `retargeted_from` として記録する。

`combat_log.append_from_report_action` は `retargeted_from` が空でなければ「[元ターゲット]は死亡 — [新ターゲット]を攻撃」のように表示する。

**理由**:
- F037 の「ログに出ない」問題の解消
- TurnEngine の挙動(retarget 自体)は変えない、表示のみ強化

### Decision 6: ログ再生は Timer ノードベース

**選択**:
```gdscript
# 旧: await get_tree().create_timer(log_line_delay).timeout

var _log_timer: Timer
var _log_pending_actions: Array

func _play_log_sequentially(report):
    _log_pending_actions = report.actions.duplicate()
    if _log_timer == null:
        _log_timer = Timer.new()
        _log_timer.one_shot = true
        _log_timer.timeout.connect(_on_log_timer)
        add_child(_log_timer)
    _show_next_log_line()

func _show_next_log_line():
    if _log_pending_actions.is_empty():
        _on_log_playback_finished()
        return
    var action = _log_pending_actions.pop_front()
    _combat_log.append_from_report_action(action)
    if log_line_delay > 0.0:
        _log_timer.start(log_line_delay)
    else:
        _show_next_log_line()

func _on_log_timer():
    _show_next_log_line()

func cancel_log_playback():  # encounter_resolved 中に呼べる
    _log_pending_actions.clear()
    if _log_timer:
        _log_timer.stop()
```

**理由**:
- await チェーンと違い、`cancel_log_playback` で安全に中断できる
- visible = false やオーバーレイ destroy 時にもクリーンアップしやすい

### Decision 7: 既存テストの保護

**選択**: `tests/combat/test_combat_overlay.gd` のうち、以下を保護:
- `start_encounter` → `encounter_resolved` の end-to-end フロー
- `command_menu_select(OPT_ATTACK)` → `target_select(0)` → 戦闘進行
- `show_result(outcome)` → `confirm_result()` → `encounter_resolved.emit`

更新が必要:
- `_handle_*_key` を直接呼んでいる箇所(あれば)
- `_pending_item_instance` などの private state を直接 assert している箇所

`_finalize_battle` の振る舞いは BattleResolver の単体テストで検証。

## Risks / Trade-offs

- **[`CombatItemSelector` 削除の判断]** 既存 UI コンポーネント。ItemUseFlow に取り込むと UI レイアウトが変わる可能性。実装時に「保つ vs 統合」を decision として再評価し、保つ場合は ItemUseFlow が `CombatItemSelector` を内部で使う形にする。
- **[`ItemUseFlow` の visibility 競合]** combat_overlay 自身も visible だがその子の ItemUseFlow も visible になるとレイアウトがオーバーラップ → ItemUseFlow を「中央 panel 領域」に配置することで command_menu と同じ位置を占有する。
- **[`BattleResolver` がテスト用 outcome を扱えるか]** 既存テストが `show_result` をハンドビルド `EncounterOutcome` で呼んでいる(コメント `:36-39`)→ BattleResolver は呼ばずに `show_result(outcome, BattleSummary.empty())` で直接呼べる経路を維持する。
- **[TurnReport の retargeted_from]** 既存テストの ReportAction 比較が `retargeted_from` を期待しないため、デフォルト値 `""` で問題なし。
- **[Timer ノードのライフサイクル]** combat_overlay が destroy されたとき Timer も自動 destroy(child として add_child してあるため)。await チェーンと違い、orphan await が残らない。
