## Why

ESC メニューからヒール呪文を唱えると `Character.current_hp` は書き換わるが、ダンジョン画面下部のパーティステータスバー(`PartyDisplay`)は古い HP を表示し続ける。原因は、戦闘中のみ `CombatOverlay` が `party_state_changed` を発火して UI を再描画する一方、ESC メニューの `SpellUseFlow` には同等の通知経路が無いこと。今後追加される状態異常治療(治癒・解毒・覚醒)、消費アイテム使用、装備変更による HP/MP 上限変動など、戦闘外で Character の状態を変える経路はさらに増える予定で、その都度 UI 経路を手で繋ぐとバグが再発する。`Character` 自身が変化を通知する仕組みを 1 度だけ整備すれば、書き換え経路がいくつ増えても UI は自動で追従する。

## What Changes

- `Character` (RefCounted) に変化通知シグナルを追加する:
  - `hp_changed(current_hp: int, max_hp: int)`
  - `mp_changed(current_mp: int, max_mp: int)`
  - `statuses_changed(persistent_statuses: Array[StringName])`
- `Character` の HP/MP 書き換え経路を「直接プロパティ代入」から「セッターメソッド経由」に整理し、値が変わったときだけシグナルを発火する。プロパティへの直接代入は引き続き許容するが、ゲームコードは原則セッターを使う(プロパティ代入時にもシグナル発火させるかは design で決定)。
- `PartyCombatant._write_current_hp` / `_write_current_mp` および `commit_persistent_to_character` を、ラップしている `Character` のセッター経由で書き換えるよう変更する。これにより戦闘中の HP 変化も同じシグナル経路を通る。
- `PartyMemberPanel`(ステータスバー 1 人分)を、表示対象 Character のシグナルに購読し、HP/MP/状態異常の変化で自動的に再描画するように変更する。表示対象が差し替わるとき(`set_member`)に古い接続を解除し新しい Character に繋ぎ直す。
- 戦闘側 `CombatOverlay._refresh_panels()` の `party_state_changed.emit()` は残すが、PartyDisplay 側がシグナル直購読になることで、戦闘外経路でも同じ品質の追従が保証される(冗長だが安全側)。
- 既存の手動 refresh 経路(`main._on_combat_party_state_changed` → `DungeonScreen.refresh_party_display`)は維持する。シグナル化は **追加** であり、既存経路を撤去する破壊的変更ではない。

## Capabilities

### New Capabilities

- `character-state-signals`: Character (および PartyCombatant 経由) が HP/MP/永続状態異常の変化を通知する観察者契約。発火条件・引数・購読側の責務を規定する。

### Modified Capabilities

- `combat-actor`: PartyCombatant の `_write_current_hp` / `_write_current_mp` / `commit_persistent_to_character` が、書き換え後にラップ先 Character の状態変化シグナルを経由して通知することを要件化する。
- `party-display`: PartyMemberPanel が表示対象 Character のシグナルに購読し、HP/MP/状態異常の変化で自動再描画することを要件化する。

## Impact

- **コード**: `src/dungeon/character.gd`, `src/combat/party_combatant.gd`, `src/dungeon_scene/party_display.gd`, `src/dungeon_scene/party_member_panel.gd`
- **テスト**: 既存の `tests/esc_menu/flows/test_spell_use_flow.gd` に UI 反映確認は無いので新規テスト追加。`tests/dungeon_scene/` 配下に PartyMemberPanel のシグナル購読テストを追加。
- **保存ロード**: `Character.from_dict` でフィールドを直接代入している箇所はシグナル発火対象外で良い(ロード中の通知は不要・むしろノイズ)。design.md でロード時の安全策を規定。
- **依存変更との関係**: in-progress の `add-status-poison-and-petrify` / `add-status-sleep-and-silence` / `add-status-confusion-blind-paralysis` / `add-stat-modifier-spells` は、戦闘外での状態変化を扱う際にこのシグナル契約を前提にできる(本変更が先行マージされる前提)。
- **互換性**: 既存の `party_state_changed` 経由の更新経路は破壊しない。シグナル購読は冗長だが、UI が二度更新される程度で害は無い。
