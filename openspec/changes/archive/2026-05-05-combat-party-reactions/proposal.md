## Why

`persistent-party-display` でパーティ HUD が常駐表示されるようになり、`Character.persistent_statuses` の視覚化までは整う。だが現状、戦闘中の "誰が今行動しているか" "誰がダメージを受けたか" "誰が回復したか" "誰が倒れたか" は戦闘ログのテキストでしか追えず、HUD は静的なステータス表示のままになる。

本変更は「パーティ表示の段階的強化」3部作の最終段で、戦闘エンジン側にハイレベル UI シグナルを追加し、HUD のパネルが戦闘の流れに視覚的にリアクションするようにする。これにより戦闘の "テンポ" がプレイヤーの目で追えるようになり、ログを読まずに状況を把握できる。

加えて、戦闘中だけ存在するバフ/デバフ(`StatModifierStack`)もこの HUD で視覚化し、戦闘判断材料として使えるようにする。

## What Changes

- `TurnEngine` に UI 向けハイレベルシグナルを追加:
  - `actor_action_started(actor: CombatActor, action_kind: StringName)` — 行動開始時(攻撃・詠唱・アイテム使用・防御・逃走)
  - `actor_dealt_damage(target: CombatActor, amount: int, source: CombatActor)` — ターゲットがダメージを受けた時
  - `actor_healed(target: CombatActor, amount: int, source: CombatActor)` — ターゲットが回復された時
  - `actor_died(actor: CombatActor)` — actor の HP が 0 になった瞬間
  - `actor_status_inflicted(actor: CombatActor, status_id: StringName)` — actor に新しい状態が付与された瞬間
- `CombatActor` に `stat_modifiers_changed()` シグナルを追加(`StatModifierStack.add` / 期間切れ削除のタイミングで発火)
- `PartyHud` に `attach_to_turn_engine(engine)` / `detach_from_turn_engine()` を追加。戦闘開始時に encounter overlay 等が attach、終了時に detach する
- `PartyMemberPanel` にアニメーション機能を追加:
  - **shake**: `Character.hp_changed` の delta が負(ダメージ)の時、左右に揺れる(±4px、計 0.2s)
  - **heal flash**: `hp_changed` の delta が正(回復)の時、緑色のフラッシュ(0.3s)
  - **lift**: 自分が結びついた actor の `actor_action_started` で上方向に持ち上げる(8px、0.15s up + 0.15s down)
  - **fade**: 自分が結びついた actor の `actor_died` でパネル全体をフェードして倒れた表現(`persistent-party-display` の暗転オーバーレイと併用)
- 連続再生時の挙動: 既存 Tween を `kill()` して新しいアニメで上書き
- 戦闘中のバフ/デバフアイコン:
  - `PartyMemberPanel` が attach 中の `CombatActor` を保持し、`StatModifierStack` の中身をアイコンとして描画する
  - 描画タイミングは `stat_modifiers_changed` シグナルでの `queue_redraw`
- アニメーションは戦闘外でも HP 変動には反応する(ESC 回復スポット等で flash する)。lift / fade は戦闘専用シグナル経由のため戦闘中のみ発生
- 戦闘終了時に detach すると、CombatActor 参照は捨てられ、stat_modifier アイコンも消える(戦闘専用データなので妥当)

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `combat-engine`: TurnEngine が UI 向けの 5 種類のシグナル(action_started / dealt_damage / healed / died / status_inflicted)を発火する要件を追加
- `combat-actor`: CombatActor に `stat_modifiers_changed` シグナルを追加し、`StatModifierStack` 変更時に発火する要件を追加
- `party-display`: PartyMemberPanel のアニメーション(shake / heal flash / lift / fade)要件と、戦闘中の StatModifierStack アイコン描画要件を追加
- `party-hud-autoload`: PartyHud に `attach_to_turn_engine` / `detach_from_turn_engine` API 要件を追加

## Impact

- `src/combat/turn_engine.gd`: シグナル宣言、resolution 中の各分岐で `emit_signal` 呼び出し追加
- `src/combat/combat_actor.gd`: `stat_modifiers_changed` シグナル宣言、`stat_modifier_stack` 変更経路(`add` 経由・ターン終了時の `tick`/`prune` 経由)での emit 追加
- `src/autoload/party_hud.gd`: `attach_to_turn_engine` / `detach_from_turn_engine`、PartyMemberPanel への CombatActor 配布
- `src/dungeon_scene/party_member_panel.gd`: Tween アニメ、`hp_changed` delta による shake/flash 分岐、CombatActor 保持と stat_modifiers アイコン描画
- 戦闘開始/終了処理(encounter overlay または combat input router 周辺): `PartyHud.attach_to_turn_engine(engine)` / `detach_from_turn_engine()` 呼び出し
- 関連テスト:
  - `tests/combat/test_turn_engine_ui_signals.gd`(新規): 各シグナルが適切なタイミングで適切な引数で発火する
  - `tests/combat/test_combat_actor_stat_modifiers_signal.gd`(新規)
  - `tests/dungeon_scene/test_party_member_panel_animations.gd`(新規): hp_changed 反応 / lift / fade のロジック検証(Tween の停止・再生は手動確認)
  - `tests/dungeon_scene/test_party_member_panel_stat_modifiers.gd`(新規)
- `combat-overlay` / `combat-input-router` 関連の attach/detach 配線
