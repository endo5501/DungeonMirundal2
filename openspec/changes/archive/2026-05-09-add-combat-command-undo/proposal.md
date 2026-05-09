## Why

戦闘の COMMAND_INPUT フェーズでは、メンバーのコマンドを確定すると次のメンバーに進むだけで、直前のメンバーの選択をやり直す手段が無い。攻撃のターゲット選択中も `ui_cancel` で戻れない。Cast / Item のサブフローには戻り経路があるのに Attack とアクター間だけ抜けており、操作ミスを取り戻せず体感が悪い。

## What Changes

- `TurnEngine` に **`withdraw_command(party_index)`** を追加し、submit 済みコマンドを撤回できるようにする(`COMMAND_INPUT` 状態時のみ動作、副作用なし)。
- `CombatOverlay` の **COMMAND_MENU フェーズで `ui_cancel`** を受け付け、直前の生存メンバーの COMMAND_MENU に巻き戻す(死亡メンバーはスキップ、先頭メンバー以前なら no-op)。巻き戻し時は対象メンバーの pending command を `withdraw_command` で撤回し、アクティブなサブパネルは隠す。
- `CombatOverlay` の **TARGET_SELECT(攻撃)フェーズで `ui_cancel`** を受け付け、ターゲット選択をキャンセルして同一アクターの COMMAND_MENU に戻す(submit しない)。
- `CombatInputRouter` のルーティングを更新し、上記2つのキャンセル経路をディスパッチする(COMMAND_MENU では `ui_cancel` をオーバーレイに通知、TARGET_SELECT は `_route_to_panel_cancellable` を経由)。
- 既存のキャンセルパス(SPELL_SELECT / SPELL_TARGET / ItemUseFlow)は退行させない。

## Capabilities

### New Capabilities
- なし

### Modified Capabilities
- `combat-engine`: `TurnEngine.withdraw_command(party_index)` の追加要件。
- `combat-overlay`: COMMAND_MENU の `ui_cancel` でアクター間の巻き戻し、TARGET_SELECT(攻撃)の `ui_cancel` で同一アクターの COMMAND_MENU 復帰、を要件として追加。
- `combat-input-router`: COMMAND_MENU phase の `ui_cancel` をオーバーレイ経由でハンドルするルーティング、TARGET_SELECT phase を cancellable ルートに変更。

## Impact

- **コード**:
  - `src/combat/turn_engine.gd`(新メソッド)
  - `src/dungeon_scene/combat_overlay.gd`(COMMAND_MENU の cancel ハンドラ、`_on_target_selector_cancelled` の分岐拡張、`_step_back_to_previous_actor` の追加、ヘルパー `_panels` への overlay キー追加)
  - `src/combat/combat_input_router.gd`(phase ごとの cancel ルーティング)
- **テスト**: GUT による単体・結合テスト追加(`turn_engine` / `combat_input_router` / `combat_overlay`)。
- **副作用なし**: 撤回は `_pending_commands` の dictionary 操作のみ。`resolve_turn` 前のため HP/MP/インベントリ/シグナル(`actor_action_started` 等)は一切影響を受けない。
- **後方互換**: 既存セーブデータや戦闘進行ロジックには影響しない。Cast / Item の戻り動作は維持。
