## 1. TurnEngine: actor_spent_mp シグナル (TDD)

- [x] 1.1 `tests/combat/test_turn_engine_ui_signals.gd` に `actor_spent_mp` の発火条件 5 シナリオを追加 (成功 / silenced / no_target / no_mp / mp_cost==0)、現状コードでは fail することを確認
- [x] 1.2 `src/combat/turn_engine.gd` に `signal actor_spent_mp(actor: CombatActor, cost: int)` を宣言
- [x] 1.3 `_resolve_cast` の `caster.spend_mp(spell.mp_cost)` 成功 (return true) かつ `spell.mp_cost > 0` の直後、`report.add_cast(...)` 呼び出し前に `actor_spent_mp.emit(caster, spell.mp_cost)` を追加
- [x] 1.4 1.1 のテストが全て pass することを確認
- [x] 1.5 `./scripts/run_tests.sh` で combat 関連の既存テストが回帰していないことを確認

## 2. PartyMemberPanel: 表示専用 HP/MP ステート (TDD)

- [x] 2.1 `tests/dungeon_scene/test_party_member_panel_displayed_hp.gd` を新規作成し、以下のシナリオを fail させる状態で書く:
  - bind_combat_actor で `_combat_displayed_hp` / `_combat_displayed_mp` がラッチされる
  - bind_combat_actor(null) で両者が `-1` に戻る
  - apply_combat_hp_delta が 0 と max_hp でクランプされる
  - apply_combat_mp_delta が 0 と max_mp でクランプされる
  - set_combat_displayed_hp が値を強制設定する
  - 戦闘中の hp_changed では `_combat_displayed_hp` が動かない (が `_data` と queue_redraw は更新される)
- [x] 2.2 `src/dungeon_scene/party_member_panel.gd` に `_combat_displayed_hp: int = -1` / `_combat_displayed_mp: int = -1` を追加
- [x] 2.3 `bind_combat_actor` を拡張して非 null actor で live 値をラッチ、null bind で `-1` に戻す
- [x] 2.4 `apply_combat_hp_delta(delta)` / `apply_combat_mp_delta(delta)` / `set_combat_displayed_hp(value)` を実装 (clampi で範囲制限 + queue_redraw)
- [x] 2.5 `_on_character_hp_changed` / `_on_character_mp_changed` を、戦闘中も `_data` 更新と `queue_redraw` を実行するが `_combat_displayed_*` には触れないように修正 (既存実装で要件を満たしている)
- [x] 2.6 2.1 のテストを全て pass させる

## 3. PartyMemberPanel: 描画と incapacitated 判定の分岐 (TDD)

- [x] 3.1 `tests/dungeon_scene/test_party_member_panel_displayed_hp.gd` に描画分岐シナリオを追加: 戦闘中 HP バー比は `_combat_displayed_hp / max_hp`、戦闘外は `current_hp / max_hp`
- [x] 3.2 同テストに「is_incapacitated は戦闘中 `_combat_displayed_hp <= 0` を見る」シナリオを追加 (live は 0 でも displayed が >0 なら dim しない)
- [x] 3.3 `_draw_stat_bar` 呼び出し側で、戦闘中は `_combat_displayed_hp` / `_combat_displayed_mp` を渡すように分岐
- [x] 3.4 `is_incapacitated()` を、`_combat_actor != null` なら `_combat_displayed_hp <= 0`、そうでなければ既存の `_character.current_hp <= 0` を使うように修正
- [x] 3.5 3.1〜3.2 のテストが pass することを確認
- [x] 3.6 既存 `tests/dungeon_scene/test_party_member_panel_dim.gd` / `test_party_member_panel_animations.gd` / `test_party_member_panel_combat_actor.gd` が引き続き pass することを確認 (戦闘外シナリオの挙動は変更されないこと)

## 4. PartyHud: バッファエントリ拡張と新ハンドラ (TDD)

- [x] 4.1 `tests/autoload/test_party_hud_buffering.gd` に以下のシナリオを fail させる状態で追加:
  - `actor_dealt_damage` 受信時、queue に `delta = -amount` が乗る
  - `actor_healed` 受信時、queue に `delta = +amount` が乗る
  - `actor_spent_mp` 受信時、queue に `{type:"mp_spend", actor, delta:-cost, step}` が乗る
  - flush_up_to_step で shake/flash 解放時、`apply_combat_hp_delta` が animation の前に呼ばれる
  - flush_up_to_step で mp_spend 解放時、`apply_combat_mp_delta` が呼ばれ、追加 animation は無し
  - flush_up_to_step で die (PartyCombatant) 解放時、`set_combat_displayed_hp(0)` → `play_die_animation()` の順
- [x] 4.2 `src/autoload/party_hud.gd`: `attach_to_turn_engine` に `actor_spent_mp.connect(_on_actor_spent_mp)`、`detach_from_turn_engine` に対応 disconnect を追加
- [x] 4.3 `_on_actor_dealt_damage` / `_on_actor_healed` を queue エントリに `delta` フィールド付きで積むよう拡張 (バッファ外の即時パスは現状維持)
- [x] 4.4 `_on_actor_spent_mp(actor, cost)` ハンドラを実装 (Party 系 actor のみ対象、buffer 中は queue、外は即時 `apply_combat_mp_delta(-cost)`)
- [x] 4.5 `_play_event` を拡張: `shake` で `apply_combat_hp_delta(delta)` 後に `_do_shake`、`flash` で `apply_combat_hp_delta(delta)` 後に `_do_flash`、`mp_spend` で `apply_combat_mp_delta(delta)`、`die` (Party) で `set_combat_displayed_hp(0)` 後に `_do_die`
- [x] 4.6 4.1 のテスト全 pass を確認

## 5. CombatMonsterPanel: _displayed_alive と setup/apply API (TDD)

- [x] 5.1 `tests/dungeon_scene/test_combat_monster_panel_displayed_alive.gd` を新規作成し fail シナリオを追加:
  - `setup_for_battle(monsters)` 後、`_displayed_alive` に全モンスターが true で登録される
  - `apply_died(actor)` で対象だけ false になる
  - `refresh()` の表示行が `_displayed_alive` の集計に従う (live `is_alive()` を見ない)
  - 全 monster が `_displayed_alive` で false になったとき、表示は 0 件になる
- [x] 5.2 `src/dungeon_scene/combat/combat_monster_panel.gd` に `_displayed_alive: Dictionary = {}` を追加
- [x] 5.3 `setup_for_battle(monsters: Array)` を実装: `_displayed_alive` をクリアし全 monster を true で登録、`refresh` を呼ぶ
- [x] 5.4 `apply_died(actor)` を実装: `_displayed_alive[actor] = false` で `refresh` を呼ぶ
- [x] 5.5 `refresh(monster_combatants, initial_counts)` の集計を `mc.is_alive()` ではなく `_displayed_alive.get(mc, true)` ベースに変更 (引数 monster_combatants は順序維持と name lookup のために残す)
- [x] 5.6 5.1 のテスト全 pass を確認

## 6. PartyHud: モンスターパネル仲介 (TDD)

- [x] 6.1 `tests/autoload/test_party_hud_buffering.gd` に以下を追加:
  - `attach_monster_panel(panel)` 後、Monster の actor_died (buffer 中) で queue に `{type:"die", actor:<monster>, step}` が乗る
  - flush_up_to_step で `panel.apply_died(monster)` が呼ばれる
  - 未 attach 時の Monster actor_died は no-op
  - buffer 外の Monster actor_died は即時 `apply_died`
- [x] 6.2 `src/autoload/party_hud.gd` に `attach_monster_panel(panel)` / `detach_monster_panel()` と `_attached_monster_panel: CombatMonsterPanel` フィールドを追加
- [x] 6.3 `_on_actor_died` を「Party の場合は既存の lift/die 経路、Monster かつパネル attach 中ならパネルへの die 経路」へ分岐 (buffer 中はそれぞれ queue、外は即時) — 既存 _on_actor_died が type:"die" でキューイングし、_do_die が分岐するため追加実装不要
- [x] 6.4 `_play_event` の `die` 処理で、actor が `MonsterCombatant` なら `_attached_monster_panel.apply_died(actor)`、そうでなければ既存の `_do_die` (Party panel が見つからなければ monster panel へ fallback、で実装)
- [x] 6.5 `detach_from_turn_engine()` の中で `detach_monster_panel()` も実行
- [x] 6.6 6.1 のテスト全 pass を確認

## 7. CombatOverlay: refresh タイミング変更とセットアップ追加 (TDD)

- [x] 7.1 `tests/dungeon/test_combat_overlay.gd` (または `test_combat_overlay_party_hud_wiring.gd`) に以下のシナリオを追加:
  - `_resolve_turn_now()` 内で resolve_turn 復帰直後に `_refresh_panels()` が呼ばれない (撤去で確認)
  - `_on_log_playback_finished()` で `_refresh_panels()` が 1 回呼ばれる (`test_on_log_playback_finished_triggers_refresh_panels`)
  - `start_encounter` 中に `_monster_panel.setup_for_battle(_turn_engine.monsters)` が呼ばれる (`test_start_encounter_initializes_monster_panel_displayed_alive`)
  - `start_encounter` 中に `PartyHud.attach_monster_panel(_monster_panel)` が `attach_to_turn_engine` の後に呼ばれる (`test_start_encounter_attaches_monster_panel_to_party_hud`)
  - 「monster は対応する death log step まで表示が維持される」統合シナリオ (`test_displayed_alive_lags_engine_state_during_async_playback`)
- [x] 7.2 `src/dungeon_scene/combat_overlay.gd::_resolve_turn_now()` 内、`resolve_turn` 直後の `_refresh_panels()` 呼び出しを削除
- [x] 7.3 `_on_log_playback_finished()` の冒頭で `_refresh_panels()` を呼ぶ (existing `PartyHud.end_buffering()` の後)
- [x] 7.4 `start_encounter()` の `PartyHud.attach_to_turn_engine(_turn_engine)` 直後に `_monster_panel.setup_for_battle(_turn_engine.monsters)` と `PartyHud.attach_monster_panel(_monster_panel)` を追加
- [x] 7.5 7.1 のテスト全 pass を確認 (新規 4 シナリオ + 既存 `test_monster_panel_reflects_killed_monster` を新スペック準拠に更新)

## 8. 統合確認とドキュメント

- [x] 8.1 `./scripts/run_tests.sh` を全件実行し、本変更の追加 / 拡張テストおよび回帰テストすべてが pass することを確認 (2152/2152 pass)
- [x] 8.2 Godot エディタで実際に戦闘を 1 回プレイし、以下を目視確認:
  - 攻撃ログ表示と HP バー減少が同期する
  - 詠唱ログ表示と MP バー減少が同期する
  - モンスター撃破ログ表示と該当モンスター行の消失が同期する
  - パーティメンバーが倒れたとき、dim overlay が die ログ表示と同時に出る
  - 戦闘終了後、HUD が live state と整合している (HP/MP 数値が正しい)
- [x] 8.3 `openspec validate sync-combat-hud-with-log --strict` が pass することを確認
- [x] 8.4 `openspec list --json` で本変更が「in-progress (ほぼ完了)」状態であることを確認 (40/45 tasks)

## 9. アーカイブ準備

- [ ] 9.1 全タスク完了後、`/opsx:archive sync-combat-hud-with-log` 相当の手順でアーカイブする (8.2 の目視確認後に実施)
