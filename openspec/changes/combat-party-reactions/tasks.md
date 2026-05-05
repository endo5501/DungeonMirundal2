## 1. CombatActor.stat_modifiers_changed シグナル (TDD: red→green)

- [x] 1.1 新規テスト `tests/combat/test_combat_actor_stat_modifiers_signal.gd`:
  - `add()` で新規エントリ → 1 回発火
  - `add()` で既存より強い置換 → 1 回発火
  - `add()` で既存より弱い(no-op) → 発火しない
  - tick で duration 0 になり削除 → 1 回発火
  - tick で duration が減るが残る → 発火しない
- [x] 1.2 GUT 実行 → red 確認
- [x] 1.3 `src/combat/combat_actor.gd` に `signal stat_modifiers_changed()` を宣言
- [x] 1.4 `src/combat/stat_modifier_stack.gd` に変更通知 callback フィールドを追加(`_on_change: Callable`)
- [x] 1.5 `StatModifierStack.add()` の各 return 直前で「実際に状態が変わった経路」だけ `_on_change.call()` を呼ぶ
- [x] 1.6 tick / prune を担うコード(`StatusTickService` 周辺の調査)で、変更があった場合のみ `_on_change.call()` を呼ぶ
- [x] 1.7 `CombatActor._init()` で `stat_modifier_stack._on_change = func(): stat_modifiers_changed.emit()` を設定
- [x] 1.8 GUT 実行 → green 確認
- [x] 1.9 コミット

## 2. TurnEngine の UI シグナル追加 (TDD: red→green)

- [x] 2.1 新規テスト `tests/combat/test_turn_engine_ui_signals.gd`:
  - attack コマンドで `actor_action_started(pc, &"attack")` が action 解決前に発火
  - 各 command 種(defend / cast / item / escape)でも対応する action_kind で発火
  - 死亡している actor の保留コマンドでは発火しない
- [x] 2.2 同テスト: `actor_dealt_damage(target, amount, source)` が hit 時のみ正しい amount で発火、miss では発火しない、defend で半減した amount が渡る
- [x] 2.3 同テスト: `actor_healed(target, amount, source)` が回復時のみ発火、max_hp 上限でクリップされた actual amount が渡る、満タンには発火しない
- [x] 2.4 同テスト: `actor_died(actor)` が is_alive() の true→false 遷移時に 1 回発火、ダメージ起因と毒 tick 起因の両方で発火、既に死んでいる actor では発火しない
- [x] 2.5 同テスト: `actor_status_inflicted(actor, status_id)` が新規付与でのみ発火、既に同じ status を持っている場合発火しない
- [x] 2.6 GUT 実行 → red 確認
- [x] 2.7 `src/combat/turn_engine.gd` に 5 シグナルを宣言
- [x] 2.8 各 command resolution の入口で `actor_action_started` を emit
- [x] 2.9 damage 適用箇所 (`take_damage` 呼び出し直後で actual delta > 0 の時) で `actor_dealt_damage` を emit
- [x] 2.10 heal 適用箇所で actual delta > 0 の時 `actor_healed` を emit
- [x] 2.11 actor の HP が 0 になり、かつ前ターンの状態で alive だった時のみ `actor_died` を emit
- [x] 2.12 `StatusTrack.apply` での新規付与時に `actor_status_inflicted` を emit
- [x] 2.13 GUT 実行 → green 確認
- [x] 2.14 コミット

## 3. PartyMemberPanel に CombatActor バインディング (TDD: red→green)

- [x] 3.1 新規テスト `tests/dungeon_scene/test_party_member_panel_combat_actor.gd`:
  - `bind_combat_actor(actor)` で `_combat_actor` がセットされる
  - `bind_combat_actor(null)` で解放される
  - 切替時に旧 actor の `stat_modifiers_changed` 接続が解除され、新 actor の接続が追加される
- [x] 3.2 GUT 実行 → red
- [x] 3.3 `PartyMemberPanel` に `var _combat_actor: CombatActor` フィールドを追加
- [x] 3.4 `bind_combat_actor(actor: CombatActor)` メソッドを追加(切断/接続を bind_character と同じパターンで)
- [x] 3.5 `_on_stat_modifiers_changed()` ハンドラで `queue_redraw`
- [x] 3.6 `_exit_tree()` で disconnect
- [x] 3.7 GUT 実行 → green
- [x] 3.8 コミット

## 4. PartyMemberPanel の stat modifier アイコン描画 (TDD: red→green)

- [x] 4.1 新規テスト `tests/dungeon_scene/test_party_member_panel_stat_modifiers.gd`:
  - 単一 buff `(stat=&"attack", delta=+2)` で 1 個のアイコン描画
  - 単一 debuff `(stat=&"defense", delta=-1)` で 1 個のアイコン描画
  - 空 stack でアイコン描画なし
  - CombatActor 未 bind では persistent_statuses があってもアイコン描画なし
  - `stat_modifiers_changed` で `queue_redraw` が呼ばれる
- [x] 4.2 GUT 実行 → red
- [x] 4.3 `PartyMemberPanel` の `_draw()` の persistent_status 描画の後、`_combat_actor != null` のとき stat_modifier_stack を走査してアイコン描画
- [x] 4.4 buff(delta > 0)は緑系、debuff(delta < 0)は赤系の色矩形 + ラベル(`A+`, `A-`, `D+`, `D-`, `Ag+/-`, `H+/-`, `E+/-`)
- [x] 4.5 持続行を持たないため、persistent_status のアイコン行と同じ y で右側に配置(衝突する場合は MP 行の右へ移動するなど)
- [x] 4.6 GUT 実行 → green
- [x] 4.7 コミット

## 5. PartyMemberPanel のアニメーション機構 (TDD: red→green)

- [x] 5.1 新規テスト `tests/dungeon_scene/test_party_member_panel_animations.gd`:
  - hp_changed で delta < 0 → shake 用 Tween が起動(`_active_shake_tween` が non-null)
  - hp_changed で delta > 0 → flash 用 Tween が起動(`_active_flash_tween` が non-null)
  - hp_changed で delta = 0 → 何も起動しない
  - 連続 damage で前の shake が kill されて新しいのが起動
  - `play_lift_animation()` で lift 用 Tween が起動
  - `play_die_animation()` で `modulate.a` が 0.7 に向かう Tween が起動
  - 死亡後の hp 回復(蘇生)で `modulate.a` が 1.0 に戻る
- [x] 5.2 GUT 実行 → red
- [x] 5.3 `PartyMemberPanel` に `_layout_position: Vector2` を追加(`PartyDisplay` が配置時に設定)
- [x] 5.4 `_active_shake_tween` / `_active_flash_tween` / `_active_lift_tween` / `_active_die_tween` フィールドを追加
- [x] 5.5 `_prev_hp` フィールドを追加(bind_character で初期化)、hp_changed で delta を計算
- [x] 5.6 shake: delta < 0 で `_play_shake()` を呼ぶ。Tween で `position.x = layout_x ± 4` を 4 サイクル、計 0.2 秒で振動 → restore
- [x] 5.7 heal flash: delta > 0 で `_play_heal_flash()` を呼ぶ。`_flash_alpha` を 0.5 → 0 に 0.3 秒で Tween。`_draw()` で `_flash_alpha > 0` のとき緑半透明矩形を描画
- [x] 5.8 lift: `play_lift_animation()` を実装。`position.y = layout_y - 8` を 0.15 秒、戻すのに 0.15 秒(計 0.3 秒)
- [x] 5.9 die: `play_die_animation()` を実装。`modulate.a = 1.0 → 0.7` を 0.4 秒で
- [x] 5.10 hp_changed のハンドラで蘇生(prev_hp = 0, new > 0)時に `modulate.a = 1.0` に戻す
- [x] 5.11 連続再生時は対応する `_active_*_tween.kill()` を呼んでから新規 Tween を作成
- [x] 5.12 GUT 実行 → green
- [x] 5.13 コミット

## 6. PartyDisplay が PartyMemberPanel に layout_position を渡す

- [ ] 6.1 既存テスト or 新規テストで、`PartyDisplay` がパネル配置時に `panel._layout_position = panel.position` を設定することを検証
- [ ] 6.2 `src/dungeon_scene/party_display.gd` の配置ロジックで、`panel.position = ...` の直後に `panel._layout_position = panel.position` を代入(setter があるならそれを使う)
- [ ] 6.3 GUT 実行 → green
- [ ] 6.4 コミット

## 7. PartyHud に attach_to_turn_engine / detach_from_turn_engine (TDD: red→green)

- [ ] 7.1 新規テスト `tests/autoload/test_party_hud_attach.gd`:
  - `attach_to_turn_engine(engine)` で 5 つのシグナルが接続される
  - 同じ engine への二重 attach、別 engine への再 attach の挙動(前のは detach される)
  - `actor_action_started` で対応する panel の `play_lift_animation` が呼ばれる(モック panel 経由)
  - `actor_died` で対応する panel の `play_die_animation` が呼ばれる
  - PartyCombatant の character と panel の `_character` が一致するパネルだけが反応する
  - MonsterCombatant のシグナルでは何のパネルも反応しない
  - `engine.party` の各 PartyCombatant が対応 panel に `bind_combat_actor` される
  - `detach_from_turn_engine()` で全シグナル切断、各 panel の combat_actor が null に
  - `detach_from_turn_engine()` を未 attach 時に呼んでもエラーにならない
- [ ] 7.2 GUT 実行 → red
- [ ] 7.3 `src/autoload/party_hud.gd` に `attach_to_turn_engine(engine)` / `detach_from_turn_engine()` を実装
- [ ] 7.4 シグナルハンドラ内で actor が PartyCombatant かを判定し、`actor.character` で panel を引く(panel リストを `PartyDisplay` から取得するヘルパを用意)
- [ ] 7.5 GUT 実行 → green
- [ ] 7.6 コミット

## 8. encounter overlay / combat-input-router 配線 (TDD: red→green)

- [ ] 8.1 新規テスト or 既存テスト拡張: 戦闘開始ロジックの中で `PartyHud.attach_to_turn_engine(engine)` が呼ばれることを検証
- [ ] 8.2 戦闘終了ロジックの中で `PartyHud.detach_from_turn_engine()` が呼ばれることを検証
- [ ] 8.3 既存の戦闘開始/終了処理(encounter overlay または combat-input-router 周辺)を調査して呼び出し位置を決定
- [ ] 8.4 attach/detach を埋め込む
- [ ] 8.5 GUT 実行 → green
- [ ] 8.6 コミット

## 9. 手動確認

- [ ] 9.1 戦闘を開始し、行動順にパネルが順次浮き上がる(lift)ことを確認
- [ ] 9.2 ダメージを受けたパネルが横揺れ(shake)することを確認
- [ ] 9.3 回復スキルを受けたパネルが緑にフラッシュすることを確認(戦闘外でも ESC 回復で同じく flash することを確認)
- [ ] 9.4 HP 0 になるとパネルが薄くフェードし、暗転オーバーレイと組み合わさって "倒れた" 表現になることを確認
- [ ] 9.5 蘇生でパネルが通常表示に戻ることを確認
- [ ] 9.6 戦闘中にバフ/デバフ(STAT modifier)アイコンが出る・消えることを確認
- [ ] 9.7 戦闘終了後、stat modifier アイコンが消えることを確認(detach されているか)
- [ ] 9.8 ステータス付与時に persistent_status のアイコンが新たに出ることを確認
- [ ] 9.9 連続被弾で shake が上書きされることを確認(視覚的にちらつかず、最後のダメージの shake で終わる)

## 10. クリーンアップ・最終コミット

- [ ] 10.1 不要になったコメント・デッドコードを削除
- [ ] 10.2 `openspec validate combat-party-reactions --strict` で valid 確認
- [ ] 10.3 全 GUT テスト green を確認
- [ ] 10.4 最終コミット
