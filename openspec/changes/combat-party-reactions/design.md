## Context

`enlarge-party-display` でレイアウト見直し、`persistent-party-display` で常駐化と persistent_statuses の視覚化が完了している前提。本変更では戦闘エンジンと UI を疎に結合し、ユーザが戦闘の "誰の番か" "誰がやられたか" を視覚で追えるようにする。

調査で確認したこと:
- `TurnEngine` は `RESOLVING` ステートで複数 actor の行動を順に解決する。各行動の解決処理は `_resolve_*` 系の private メソッドに分かれており、行動開始/終了の境界は明確。
- `Character.hp_changed` シグナルは既に存在し、PartyCombatant 経由でダメージ/回復が character に伝わると発火する。`statuses_changed` も同様に存在。
- `StatModifierStack` は `CombatActor` 所有で、`add(stat, delta, duration)` でエントリ追加、ターン経過で `duration` が減って削除される。シグナルはまだ無い。
- `PartyCombatant.character` で wrapped Character にアクセスできる。`MonsterCombatant` には Character 相当が無いため、UI シグナルの引数で `CombatActor` 渡しでも、HUD 側はパーティ側だけを扱える(モンスター側は無視)。

## Goals / Non-Goals

**Goals:**
- 戦闘の "テンポ" を HUD で視覚化する: 行動開始 → 持ち上げ、ダメージ → 揺れ、回復 → 緑光、死亡 → フェード
- 戦闘中のみ存在するバフ/デバフ(StatModifierStack)を HUD パネルに表示する
- TurnEngine と HUD を疎結合にする(TurnEngine は HUD を知らない、PartyHud が attach する)
- 連続イベント時はアニメ上書き(直前の Tween を kill)で対応

**Non-Goals:**
- モンスター側のアニメーション(モンスター描画は `combat-overlay` / `encounter-overlay` のスコープ)
- アニメーションの細かいパラメータ調整 UI(プログラム定数で十分)
- `actor_action_started` の `action_kind` ごとに違うアニメ(本変更では全 kind で同じ lift。将来差し替え余地あり)
- 状態異常付与時のアイコン点滅エフェクト(`actor_status_inflicted` は HUD 全体の通知用に signal は出すが、本変更では panel 側で再描画のみ)
- 戦闘終了時の演出(勝利/敗北の HUD 演出は `battle-summary` などの別 spec に委ねる)

## Decisions

### D1. シグナル発火点(TurnEngine)

`TurnEngine.resolve_turn(rng)` の中の各 actor の行動解決ループで、適切なタイミングで以下を emit する:

| シグナル                     | 発火タイミング                                                                                  |
| ---------------------------- | ----------------------------------------------------------------------------------------------- |
| `actor_action_started`       | actor の行動解決ブロックに入った直後、effect 適用前                                              |
| `actor_dealt_damage`         | `take_damage` で実際に HP が減った直後(target, amount, source)                                  |
| `actor_healed`               | 回復系 effect で HP が増えた直後(target, amount, source)                                        |
| `actor_died`                 | `is_alive()` が `false` に遷移した直後 (HP=0 起因。本変更で 1 行動内で複数 actor が同時死亡しても各々で 1 回ずつ発火) |
| `actor_status_inflicted`     | `StatusTrack.apply` で新しい status が追加された直後 (既存だった場合は発火しない)               |

`action_kind` の値は `&"attack"`, `&"defend"`, `&"cast"`, `&"item"`, `&"escape"` の StringName。将来追加可。

### D2. PartyHud と TurnEngine の attach/detach

- `PartyHud.attach_to_turn_engine(engine: TurnEngine)`:
  - 上記 5 シグナルを購読する Callable を connect。
  - actor_action_started / actor_dealt_damage / actor_healed / actor_died / actor_status_inflicted 各々で、対象 actor が `PartyCombatant` の場合に内包 Character を取得し、対応する `PartyMemberPanel` に通知。
  - `engine.party` 内の各 `PartyCombatant.character` と `PartyMemberPanel._character` のマッピングを構築し、各 panel に CombatActor 参照を渡す(stat_modifier 表示用)。
- `PartyHud.detach_from_turn_engine()`:
  - 全シグナル切断、各 panel への CombatActor 参照クリア。
- 呼び出し側:
  - 戦闘開始: `combat-input-router` または encounter overlay の戦闘開始処理で `PartyHud.attach_to_turn_engine(engine)`。
  - 戦闘終了: 同箇所の終了処理で `detach_from_turn_engine()`。

### D3. PartyMemberPanel のアニメーション機構

- `Tween` を panel ごとに 1 つだけ保持(`_active_tween: Tween`)。新しいアニメ開始時に `if _active_tween: _active_tween.kill()`。
- shake (ダメージ反応):
  - `Character.hp_changed(new_hp, max_hp)` を購読(既存)。
  - panel 内で前回の current_hp を保持しておき、delta < 0 で shake トリガ。
  - パラメータ: 振幅 ±4px、周期 4 サイクル、合計 0.2 秒。`position.x` をオフセット → 戻す。
- heal flash (回復反応):
  - 同じく hp_changed の delta > 0 でトリガ。
  - パラメータ: パネル全体に緑色 (`Color(0.4, 1.0, 0.4, 0.5)`) のオーバーレイを `_draw()` 経由で描画、0.3 秒でフェードアウト。
  - 実装は `_flash_alpha: float` を Tween で 0.5→0 に推移させ、`_draw()` 内で `_flash_alpha > 0` の時だけ overlay を描画。
- lift (行動開始反応):
  - `actor_action_started(actor, kind)` を PartyHud 経由で受け、対応 panel の `_lift()` を呼ぶ。
  - パラメータ: `position.y` を -8px に 0.15 秒で持ち上げ → 元の位置に 0.15 秒で戻す(計 0.3 秒)。
  - kind による分岐は本変更では行わない(全 kind 同じ lift)。
- fade (死亡反応):
  - `actor_died(actor)` を受け、対応 panel の `_modulate.a` を 1.0 → 0.7 に 0.4 秒でフェード(完全消失ではない、暗転オーバーレイと組み合わせて視認可能)。
  - 既に `persistent-party-display` で incapacitated 時のパネル暗転が描画されるので、fade はその上から軽く透過させる強調表現。
  - HP が回復(蘇生)で再び > 0 になったら `_modulate.a` を 1.0 に戻す(hp_changed 内でリセット)。

### D4. 連続再生(Tween 上書き)

- shake / lift / heal flash で同じ panel に連続イベントが来た場合、`_active_tween.kill()` して新しい Tween を作る。
- 副作用として、shake 中にダメージが連続で来ると振動が "リセット" される。これはユーザの要求通りの挙動(上書き)。
- shake 終了時に panel position を元のオフセットに戻す処理を `Tween.tween_callback(restore)` で必ず最後に挟む。Tween が kill されても position が戻らない不具合を避けるため、`_layout_position: Vector2` を保持して切替時に明示リセット。

### D5. 戦闘外での hp_changed アニメ

- shake / heal flash は `Character.hp_changed` 由来なので、戦闘外(ESC 回復、毒のダメージティック等)でも反応する。
- これは仕様: 「ダメージ → 揺れ、回復 → 光」が常に一貫する。
- 戦闘外で意図的に抑止する分岐は設けない(複雑さ vs 一貫性のトレードオフで一貫性を採る)。

### D6. CombatActor.stat_modifiers_changed シグナル

- `CombatActor` に `signal stat_modifiers_changed()` を追加(引数なし、HUD 側で `stat_modifier_stack` を再走査)。
- `StatModifierStack.add()` の各 return 直前で発火 → CombatActor 側で発火するか、StatModifierStack 自身に signal を持たせて CombatActor が forward するか。
  - **採用**: `StatModifierStack` に変更通知 callback を保持させ、CombatActor が初期化時に自身の `stat_modifiers_changed.emit` を渡す。テスト容易性と疎結合の両立。
- `StatusTickService` 等が duration を減算して 0 になったエントリを削除するタイミングでも発火する必要がある → tick 後に変更があった場合のみ発火するヘルパを介す。

### D7. PartyMemberPanel が CombatActor を保持して stat_modifier を描画

- `PartyMemberPanel.bind_combat_actor(actor: CombatActor)` を追加。
- 描画は `_draw()` の最後(暗転オーバーレイの直前)で、CombatActor がいれば `stat_modifier_stack._entries` を走査してアイコン(色矩形 + 簡略ラベル e.g. `A+`, `D-`, `Ag+`, `H+`, `E-` 等)を描画。
- attach 時に `stat_modifiers_changed` を connect、detach 時に disconnect。
- 描画位置: persistent_status アイコンと同じ行に並べる(persistent_statuses が左、stat_modifiers が右)。スペース不足なら 2 段にする。

### D8. 描画優先順位(`_draw()` 全体構造)

最終的な PartyMemberPanel の `_draw()` は以下の順:

1. データ無し(`_data == null`)なら何もせず終了
2. パネル背景矩形
3. アイコン(キャラ画像プレースホルダ)
4. 名前 / LV / HP / MP テキスト
5. persistent_statuses アイコン群(`persistent-party-display`)
6. stat_modifiers アイコン群(本変更)
7. heal flash オーバーレイ(`_flash_alpha > 0`)
8. 暗転オーバーレイ(`_is_incapacitated()`)

shake / lift は `_draw()` ではなく `position` への Tween。fade は `modulate` への Tween。

### D9. テスト戦略

- TurnEngine のシグナル発火: 単体テストで通常の attack / cast / defend / item / escape の各シナリオで適切なシグナルが適切な順で出ることを `signal_recorder` パターンで検証。
- CombatActor.stat_modifiers_changed: `add` / tick / prune のそれぞれで発火することを検証。
- PartyMemberPanel: アニメ "起動" の検証(`_active_tween != null`、shake 起動フラグ)までを単体テストで担保。実際の見た目は手動確認。
- PartyHud.attach_to_turn_engine: テストダブルの TurnEngine からシグナルを発火させ、対応 panel に転送されることを検証。

## Risks / Trade-offs

- **TurnEngine がシグナルを発火する位置を増やすと resolution の流れが複雑になる** → 1 行動の resolution の入口/出口だけに限定し、他は既存ヘルパに委ねる。
- **戦闘外で hp_changed → flash/shake が連発するケース** (毒の dungeon tick で複数キャラ同時にダメージ等) → アニメは独立してそれぞれ走るのでコスト的には問題なし。視覚的にも有用。
- **Tween 過剰**: 戦闘で 6 panel 全部が同時に lift / shake / flash すると重い? → Godot Tween は軽量で問題なし。心配なら手動確認で再評価。
- **PartyHud autoload が CombatActor を保持し続けて GC されない問題** → detach_from_turn_engine で確実に参照を解放する。
- **既存テストの破壊**: `tests/combat/test_turn_engine_*.gd` に signal を追加する必要があるが、既存テストには影響しない(シグナルは購読者が居なければ no-op)。

## Migration Plan

1. CombatActor に `stat_modifiers_changed` シグナル追加。テスト → green。
2. TurnEngine に 5 シグナル追加。テスト → green。
3. PartyHud に attach/detach API 追加、PartyMemberPanel に CombatActor 保持機能追加。
4. PartyMemberPanel に shake/heal flash/lift/fade のアニメ機構追加。
5. encounter overlay / combat-input-router で attach/detach を呼ぶ。
6. 手動確認で戦闘の流れを目視チェック。

## Open Questions

- 死亡アニメの最終的な表現(透過率 0.7 で十分か、もっと強くフェードするか)→ 実装後に手動確認で確定
- stat_modifier アイコンのラベル(`A+`, `Atk+`, `+ATK` 等)→ 実装時にテーブル定数で決める
- attach/detach の呼び出し場所が encounter overlay 単一で十分か(複数の戦闘エントリポイントがあるか)→ 実装時に encounter-detection / combat-overlay の流れを再確認
