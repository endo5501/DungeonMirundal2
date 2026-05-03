## ADDED Requirements

### Requirement: EncounterOverlay は ui_accept action で確認入力を受ける
SHALL: `EncounterOverlay._unhandled_input` は `is_action_pressed("ui_accept")` でモンスター遭遇画面の確認操作を受け付ける。`event.keycode == KEY_*` の直接マッチは使わない。

#### Scenario: ui_accept で遭遇確認が完了する
- **WHEN** encounter overlay が表示されている状態で `is_action_pressed("ui_accept")` がディスパッチされる
- **THEN** `encounter_resolved` シグナルが発行され、戦闘 phase または通常移動に遷移する
