## Context

`combat-party-reactions` (2026-05-05) で `PartyHud` に `begin_buffering` / `flush_up_to_step` の同期インフラが導入され、`TurnEngine` の各シグナル emit はその時点の `_resolve_report.actions.size()` を `step` として運ぶ。これにより shake / heal flash / lift / die / status_inflicted の **アニメーション再生** はログ行と同期している。

しかし HP/MP の数値表示と「モンスターがいなくなる」可視化は同期から外れている。

**現状フロー(問題点を強調):**
```
コマンド入力完了
  │
  ▼
PartyHud.begin_buffering()
  │
  ▼
TurnEngine.resolve_turn(rng)        ┐
  ├ 状態異常 tick → current_hp 即時減   │ この間
  ├ 攻撃処理     → take_damage 即時    │ Character.hp_changed が
  └ 詠唱        → spend_mp / 効果適用 │ 連発、 PartyMemberPanel._data
                                     │ が live と同期して即時更新
─────────────── resolve_turn 復帰 ──┘
  │
  ▼
_refresh_panels()  ← ここでモンスターパネル再描画 → 死亡モンスター即時消失
  │
  ▼
_play_log_sequentially(report)
  ├ flush_up_to_step(0) → action 0 の shake/die 演出
  ├ flush_up_to_step(1) → action 1 の演出
  └ ...
```

`PartyMemberPanel` は `Character.hp_changed` シグナルを直接購読し、`_data = _character.to_party_member_data()` で snapshot を更新するため、`_draw_stat_bar` が描く HP 値は live を反映してしまう。`is_incapacitated()` も `_character.current_hp <= 0` を見るため dim overlay も即時に出る。

`CombatMonsterPanel` は `refresh()` 内で `mc.is_alive()` を直接呼ぶため、live で死んだモンスターは `refresh` のたびに行から消える。

**スコープ:**
- 描画タイミングを変える表示層の変更だけで解決する。エンジンの「1 ターン atomic 解決」モデルは維持
- セーブ/ロード、戦闘外 HUD、ESC メニュー経由のアイテム使用フラッシュなどには影響を与えない

## Goals / Non-Goals

**Goals:**
- パーティ HP バー、HP 数値、MP 数値が「対応するログ行が表示された瞬間」に変化する
- 倒したモンスターが「対応する撃破ログが表示された瞬間」にエネミー一覧から消える
- パーティメンバーの dim overlay (incapacitated) も同じタイミングで反映される
- 既存のシグナル契約は破壊しない (追加のみ)
- ESC メニューや戦闘外でのアイテム使用など、戦闘以外のシナリオは現状の即時反映を維持

**Non-Goals:**
- `TurnEngine` の解決モデル変更 (atomic 解決を yield ベースに変えない)
- ログ再生速度 (`log_line_delay`) のチューニング (本変更とは独立した課題)
- 戦闘 UI のアニメーション種類追加 (本変更は同期の修正のみ)
- モンスター個別の HP バー表示など、見せ方そのものの変更
- 状態異常アイコン / stat_modifier_stack アイコンの遅延表示 (battle-end コミットや常時更新で十分視認可能なため対象外)

## Decisions

### Decision 1: 表示専用の遅延ステートを各パネル内に持たせる (アプローチ A)

`PartyMemberPanel` に `_combat_displayed_hp` / `_combat_displayed_mp` (戦闘外は `-1`) を、`CombatMonsterPanel` に `_displayed_alive: Dictionary<MonsterCombatant, bool>` を持たせ、戦闘中はこれらを描画ソースとする。`PartyHud` がバッファ flush 時に `apply_combat_*_delta` / `apply_died` を呼んで前進させる。

**代替案:**
- **(B) `TurnEngine.resolve_turn` を await ベースの coroutine 化**: エンジン本体の async 化が広範囲に波及し、エンジン単体テスト群を書き直す必要がある。本問題に対しては過剰
- **(C) エンジンを「プラン」と「適用」に分離 (mutator を返す)**: 各アクション解決が次アクションの再ターゲット判断 (死亡確認) に依存しており、純粋な分離が困難
- **(D) バッファリングを廃止し演出も即時に**: 違和感の方向が逆になるだけ。ログを文学的に見せる現在の方針と整合しない

**採用理由:** 既存の `pending_action_index` / `begin_buffering` / `flush_up_to_step` インフラを素直に拡張するだけで済み、エンジン側の侵入が最小 (新シグナル 1 本のみ)。状態同期の正準源 (engine の actor) は変えず、表示用のスナップショットだけが遅延する。

### Decision 2: 描画値ソースは `_combat_displayed_*` 優先、`_data` は live を維持

`_on_character_hp_changed` / `_on_character_mp_changed` は戦闘中も従来通り `_data = _character.to_party_member_data()` を実行する。ただし `_draw_stat_bar` は `_combat_actor != null` のときに限り `_combat_displayed_hp` / `_combat_displayed_mp` を渡し、そうでない場合のみ `_data.current_hp` / `_data.current_mp` を使う。

**代替案:**
- _data 自体を遅延させる: 二重台帳になり、戦闘終了直後に「_data を再生成して live に追従」する追加同期が必要になる。実装コストが上がるだけで利点なし
- _on_character_hp_changed を戦闘中は丸ごと無視する: `to_party_member_data()` には HP 以外の派生情報も含まれるため、副作用的に他の表示が壊れる懸念

**採用理由:** 「正準源は live、描画は遅延ソースを優先」という単純な層分けで、責務が明確。戦闘終了 (`bind_combat_actor(null)`) 時に `_combat_displayed_*` を `-1` に戻すだけで自然に live ソースへフォールバックする。

### Decision 3: `is_incapacitated()` も戦闘中は遅延ステート基準

`is_incapacitated()` は描画 (`_draw` の dim overlay) で参照される。これを `_combat_actor != null` のときは `_combat_displayed_hp <= 0` を見るように分岐する (sleep / paralysis / petrify など persistent_statuses ベースの incapacitate はそのまま)。これにより HP バーと dim overlay が同じタイミングで遷移する。

### Decision 4: `actor_spent_mp` シグナルの追加と emit 条件

新シグナル `signal actor_spent_mp(actor: CombatActor, cost: int)` を `TurnEngine` に追加する。emit するのは `_resolve_cast` 内で `caster.spend_mp(spell.mp_cost)` が `true` を返した直後のみ。以下のケースでは emit しない:
- silence で `add_cast_silenced` に流れた場合 (MP 消費なし)
- ターゲット消失で `add_cast_skipped_no_target` に流れた場合 (MP 消費なし)
- MP 不足で `add_cast_skipped_no_mp` に流れた場合 (`spend_mp` 自体が `false` を返す)

emit 位置は他の pre-emit パターンと同様、対応する `report.add_cast` の前。これにより `_resolve_report.actions.size()` (= step) が `cast` ログ行と一致する。

**代替案: `CombatActor.spend_mp` 内で emit**
- spend_mp はエンジン以外 (将来のESCメニュー詠唱など) からも呼ばれる可能性があり、戦闘 UI 同期目的のシグナルがあちこちで発火するのは設計上汚い
- step 取得は `TurnEngine._resolve_report` に依存するため、いずれにせよエンジン側で emit するのが筋が通る

### Decision 5: モンスターパネル仲介を PartyHud 経由に集約

`CombatOverlay` が `actor_died` を直接購読してモンスターパネルを更新するのではなく、`PartyHud.attach_monster_panel(panel)` でパネル参照を持たせ、PartyHud の既存 `_on_actor_died` ハンドラから派生して伝搬させる。これにより:
- `_event_queue` への積み込みと flush の単一窓口を維持できる
- モンスター死亡演出 (将来的にスプライト fade 等) も同じ step 同期を享受できる

**Queue エントリ拡張:**
```
{ "type": "shake",     "actor": <party>,   "delta": -amount, "step": N }
{ "type": "flash",     "actor": <party>,   "delta": +amount, "step": N }
{ "type": "mp_spend",  "actor": <party>,   "delta": -cost,   "step": N }
{ "type": "lift",      "actor": <party>,                     "step": N }
{ "type": "die",       "actor": <any>,                       "step": N }   ← party | monster
{ "type": "redraw",    "actor": <party>,                     "step": N }
```

`die` は actor が PartyCombatant か MonsterCombatant かで処理を分岐:
- PartyCombatant → 既存の `_do_die`: panel.set_combat_displayed_hp(0) → play_die_animation
- MonsterCombatant → 新 `_do_monster_die`: `_attached_monster_panel.apply_died(actor)`

### Decision 6: `_refresh_panels` のタイミング変更

`CombatOverlay._resolve_turn_now()` 内、`resolve_turn(rng)` 直後にあった `_refresh_panels()` 呼び出しを削除し、`_on_log_playback_finished` の冒頭で呼び直す。これは「最終確認用の再同期」として、表示用ステートとエンジン正準状態が完全一致しているはずだが、念のため整合性を担保する。

ログ再生途中で battle が `FINISHED` になった場合 (全滅・全敵撃破) も、最終 `flush_up_to_step` が走ってから `_on_log_playback_finished` で `_refresh_panels` → `_finalize_battle` の順になる。

### Decision 7: 戦闘開始時のセットアップ

`CombatOverlay.start_encounter` 内、`PartyHud.attach_to_turn_engine(_turn_engine)` の直後に:
1. `_monster_panel.setup_for_battle(_turn_engine.monsters)` - `_displayed_alive` を全 true で初期化
2. `PartyHud.attach_monster_panel(_monster_panel)` - 死亡シグナル仲介を登録

`PartyHud.detach_from_turn_engine()` の中で `detach_monster_panel()` も呼ぶことで、戦闘終了時に参照が残らないようにする (`encounter_resolved` 経由のシーン遷移時)。

`PartyMemberPanel.bind_combat_actor(actor)` は既に `attach_to_turn_engine` のループで呼ばれているので、その実装を拡張して `_combat_displayed_hp` / `_combat_displayed_mp` ラッチを行う。

## Risks / Trade-offs

- **ログ再生途中で `_is_active = false` になる (overlay 強制 hide 等)** → 既存 `cancel_log_playback()` が `PartyHud.end_buffering()` を呼んで残キューを drain するので、表示ステートが宙ぶらりんで残ることはない。ただし drain 中は `apply_combat_hp_delta` が一気に走るため、HP バーが瞬時に最終値へジャンプする (これは現状と同じ挙動への安全側 fallback)
- **resolve_turn と pre-emit のシグナル順が崩れた場合** → 現状コードでは emit が `_resolve_report.actions.size()` を基準にしており、各 add_* メソッド呼び出し前に emit する pre-emit パターンが守られている。本変更で新規 `actor_spent_mp` も同パターンに従えばリスクなし → コードレビューで pre-emit 順序逸脱がないか確認
- **MP 0 詠唱 (spell.mp_cost == 0)** → `spend_mp(0)` は `true` を返すが、`actor_spent_mp(actor, 0)` を emit すると不要な mp_spend イベントが queue に積まれる。`cost > 0` のときだけ emit するガードを入れる
- **bind_combat_actor 後のラッチタイミング** → `attach_to_turn_engine` のループで bind 時に live 値を読むため、その時点で actor.current_hp / current_mp が「戦闘開始時の正しい初期値」であることを前提にする。`start_battle` で turn 1 の status tick はまだ走らないので OK
- **`_combat_displayed_hp` がゼロ未満や max 超過になるケース** → `apply_combat_hp_delta` 内で `clampi(value, 0, max_hp)` する。die イベントは `set_combat_displayed_hp(0)` で確実に 0 へ
- **複数発の damage が同じ step で並ぶ confusion 等** → 各 emit が個別キューエントリで `delta` を持ち、flush 順 = emit 順なので個別に減算される。最終値は live と一致する
- **テスト負債** → 既存 5 ファイルが構造変更に追従する必要あり。先行テスト → 実装の TDD で「pre-emit に新フィールドが乗っているか」「flush 後の panel 状態」を assertion 強化する
- **将来 PartyHud から複数モンスターパネルを扱う必要が出る場合** → 現状は単一 `_attached_monster_panel`。複数化が必要になったら `Array` 化するが、現スコープでは単一で十分

## Open Questions

- 現在 `log_line_delay = 0.0` で運用されており、デフォルトだとログ行は瞬時に流れる (= 演出も瞬時)。本変更は同期は正しくするが、見た目には依然「一瞬で終わる」体感が残る可能性がある。`log_line_delay` のデフォルト調整は本提案のスコープ外とするが、検証時に「同期は取れているがプレイ感としては?」のレビューを別途実施したい
- die 演出がモンスター側にも将来追加される場合の API 形 (`_displayed_alive` を bool ではなく enum 化するか) → 現スコープでは bool で十分、将来必要なら別 change で拡張する
