## Why

戦闘の 1 ターンを解決すると、`TurnEngine.resolve_turn` が HP/MP/生死をすべて即時に最終状態へ書き換え、その直後に `CombatOverlay._refresh_panels()` が走るため、コマンド入力直後にパーティの HP バーが一気に減り、倒したモンスターも即座に消えてしまう。一方でログ行は `_play_log_sequentially` で一行ずつ後から流れるため、「結果が画面に出てからログが攻撃や呪文発動を後追いで語る」という違和感が出ている。`PartyHud` には既に `begin_buffering()` / `flush_up_to_step()` という同期インフラがあり、shake / heal flash / die といった**演出**だけはログ行に合わせて再生されているが、表示される数値・生死状態自体が同期から外れている。

## What Changes

- TurnEngine に新シグナル `actor_spent_mp(actor: CombatActor, cost: int)` を追加し、`_resolve_cast` の `spend_mp` が成功した直後にだけ emit する (silence/睡眠/対象消失/MP不足の skip では emit しない)
- 既存の `actor_dealt_damage` / `actor_healed` はシグネチャ変更なし。`PartyHud` 側のキューエントリに `delta` を保持し、flush 時に新 API `panel.apply_combat_hp_delta(delta)` を呼び出すように拡張する
- `PartyHud` に `actor_spent_mp` ハンドラを追加し、attach/detach の配線対象に含める。flush で `panel.apply_combat_mp_delta(-cost)` を呼ぶ
- `PartyHud` から `CombatMonsterPanel` を仲介できるよう `attach_monster_panel(panel)` / `detach_monster_panel()` を追加し、`actor_died` シグナル受信時にモンスター側にも `apply_died(actor)` を伝搬する
- `PartyMemberPanel` に表示専用ステート `_combat_displayed_hp` / `_combat_displayed_mp` (それぞれ `-1` で「戦闘外」を表す) を追加し、`bind_combat_actor(actor)` で live 値からラッチする。新 API: `apply_combat_hp_delta(delta)` / `apply_combat_mp_delta(delta)` / `set_combat_displayed_hp(value)`
- `PartyMemberPanel._draw_stat_bar` および `is_incapacitated()` は戦闘中(`_combat_actor != null`)はこの遅延ステートを優先する。dim overlay も同じ判定で遅延される
- `PartyMemberPanel._on_character_hp_changed` / `_on_character_mp_changed` は戦闘中も `_data` の更新と `queue_redraw()` を継続するが、_combat_displayed_* には触れない (描画は遅延ステート優先)
- `CombatMonsterPanel` に `_displayed_alive: Dictionary` を導入し、`setup_for_battle(monsters)` で全員 alive 初期化、`apply_died(actor)` で false に。`refresh()` は live の `is_alive()` ではなく `_displayed_alive` を集計して描画する
- `CombatOverlay._resolve_turn_now()` 直後の `_refresh_panels()` 呼び出しを撤去し、`_on_log_playback_finished` で最終的な refresh を行う。`start_encounter` で `attach_to_turn_engine` 直後に `setup_for_battle` と `attach_monster_panel` を実施する
- TDD で各ステップに先行テストを追加。既存 `test_party_hud_buffering.gd` / `test_turn_engine_ui_signals.gd` / `test_party_member_panel_animations.gd` / `test_party_member_panel_combat_actor.gd` / `test_combat_overlay.gd` を拡張、新規 `test_party_member_panel_displayed_hp.gd` と `test_combat_monster_panel_displayed_alive.gd` を追加

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities
- `combat-engine`: `actor_spent_mp` シグナルが追加され、`_resolve_cast` の MP 消費成功時にだけ emit する要件が増える
- `party-hud-autoload`: バッファ内エントリが `delta` を保持し、`actor_spent_mp` を購読、`attach_monster_panel` / `detach_monster_panel` を介してモンスターパネルへ `apply_died` を伝搬する要件が増える
- `party-display`: `PartyMemberPanel` に `_combat_displayed_hp` / `_combat_displayed_mp` を導入。戦闘中は描画と `is_incapacitated()` 判定がこの遅延ステートを使う要件、戦闘外と戦闘終了直後の挙動も明文化
- `combat-overlay`: `_refresh_panels` のタイミング変更 (resolve_turn 直後ではなく log playback 完了時) と、戦闘開始時にモンスターパネルを `setup_for_battle` + `PartyHud.attach_monster_panel` で初期化する要件、「モンスター撤去はログ行と同期」という要件を明文化

## Impact

- **コード**:
  - `src/combat/turn_engine.gd`: 新シグナル定義と `_resolve_cast` での emit
  - `src/autoload/party_hud.gd`: キューエントリ拡張、新ハンドラ、モンスターパネル仲介 API
  - `src/dungeon_scene/party_member_panel.gd`: 遅延ステート導入、新 API、描画/判定ロジック分岐
  - `src/dungeon_scene/combat/combat_monster_panel.gd`: `_displayed_alive` 導入、`refresh` ロジック差し替え、新 API
  - `src/dungeon_scene/combat_overlay.gd`: refresh タイミング変更、戦闘開始時のセットアップ追加
- **テスト**: 上述の既存 5 ファイル拡張 + 新規 2 ファイル
- **セーブ/ロード**: 影響なし (遅延ステートは純粋に表示用で、エンジン正準状態は不変)
- **後方互換性**: シグナルシグネチャは追加のみで既存は変えないため、テスト以外への破壊的影響はない
- **パフォーマンス**: 1 ターンあたりに発生するシグナル数・キュー操作は数件レベルで増加のみ (削減なし)、影響無視できる範囲
