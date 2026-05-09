## Context

戦闘の COMMAND_INPUT は `CombatOverlay` が複数アクターをループしながらコマンドを集める state machine になっている。`CombatInputRouter` は phase ごとに 1 つのパネルへ入力をディスパッチする静的ルーターで、現状は以下の経路しかキャンセルを受けつけない:

| phase | キャンセル経路 |
|---|---|
| SPELL_SELECT | `_route_to_panel_cancellable` → `spell_selector.request_cancel` → `cancelled` シグナル → COMMAND_MENU 復帰 |
| SPELL_TARGET | `_route_to_panel_cancellable` → `target_selector.request_cancel` → `cancelled` シグナル → SPELL_SELECT 復帰 |
| ItemUseFlow | フロー内で完結し `flow_completed("")` で COMMAND_MENU に戻る |

つまり Cast / Item には戻りパスがあるが、Attack のターゲット選択 (`TARGET_SELECT`) と、メンバー間の戻り (`A→B 確定後に A をやり直す`) が抜けている。本変更はこの 2 経路を埋める。

`_pending_commands` への submit は dictionary 操作のみで副作用が無い(HP/MP/インベントリ/シグナルはすべて `resolve_turn` で初めて動く)ため、撤回はメモリ操作だけで完結する。

## Goals / Non-Goals

**Goals:**
- COMMAND_MENU で `ui_cancel` を押すと直前の生存メンバーの COMMAND_MENU に戻り、そのメンバーの pending command が撤回される(連打でターン頭まで遡れる)。
- TARGET_SELECT(攻撃)で `ui_cancel` を押すと、submit せずに同一アクターの COMMAND_MENU に戻る。
- 既存の SPELL_SELECT / SPELL_TARGET / ItemUseFlow の戻り動作は退行させない。
- 撤回は副作用ゼロ(`resolve_turn` 前なので HP/MP/インベントリ/シグナルすべて不変)。

**Non-Goals:**
- 任意メンバーまでジャンプする UI(HUD カーソル選択など)。
- 全員確定後の確認画面ベースのやり直し。
- 戻ったときにメニューカーソルを直前選択肢に復元する機能。
- ターン終了後(resolve 完了後)のロールバック。

## Decisions

### D1: `TurnEngine.withdraw_command(party_index)` を追加(submit と対称な API)

代替:
- (a) 専用メソッドを追加(採用)
- (b) `submit_command(i, null)` を撤回扱いにする
- (c) `_pending_commands` を CombatOverlay から直接いじる

**採用は (a)**。理由:
- `submit` と対をなす API になり読み手の意図が明白。
- (b) は `null` という曖昧な意味をすべての呼び出し側に強いる。
- (c) は engine の private 状態を破る。
- 動作は `state == COMMAND_INPUT` のときだけ `_pending_commands.erase(party_index)` する単純なもの。`submit_command` と同じガードに揃える。

### D2: COMMAND_MENU の `ui_cancel` をオーバーレイへ届ける経路は `panels.overlay` 経由

代替:
- (a) `panels` Dictionary に `overlay` キーを追加し、router が `overlay.request_undo_actor()` を呼ぶ(採用)
- (b) router がステータスコード(enum)を返し、CombatOverlay 側で解釈
- (c) `command_menu.request_cancel` を新設して、CommandMenu からシグナルでオーバーレイへ通知

**採用は (a)**。理由:
- 既存ルーターは「panel オブジェクトのメソッドを叩く」パターンで統一されているので、その延長で済む。
- 複数アクター state machine を所有しているのは CombatOverlay なので、メソッドの置き場として最も自然。
- (c) は CommandMenu に「マルチアクター進行」という関心事を背負わせてしまう。

### D3: TARGET_SELECT の `ui_cancel` は既存の `target_selector.cancelled` シグナルに乗る

`target_selector` は既に `cancelled` シグナルを持ち、`_on_target_selector_cancelled` に繋がっている(現在は SPELL_TARGET 限定の分岐)。

採用案:
- ルーターで TARGET_SELECT を `_route_to_panel_cancellable` 経由に変更 → `target_selector.request_cancel()` が呼ばれる → `cancelled` 発火。
- `_on_target_selector_cancelled` を拡張し、`_current_phase == Phase.TARGET_SELECT` のときは `target_selector.hide_selector()` してから `_command_menu.show_for(現在のactor)` で COMMAND_MENU に戻す(submit しない)。

新シグナルや新クラスは不要。

### D4: 戻り側の死亡メンバースキップは進行側ロジックの逆向き

進む側:
```
while idx < party.size() and not party[idx].is_alive():
    idx += 1
```

戻る側:
```
idx -= 1
while idx >= 0 and not party[idx].is_alive():
    idx -= 1
if idx < 0:
    return  # no-op (先頭以前は戻り先なし)
```

party=[A生, B死, C生, D生] のとき D 入力中の cancel は C へ、C 入力中の cancel は A へ、A 入力中の cancel は何もしない。

### D5: 戻り時はサブパネルを防御的にすべて hide

COMMAND_MENU から ui_cancel が走るときは原則 `_command_menu` だけが見えているはずだが、UI 状態の取りこぼしを避けるため `target_selector` / `spell_selector` / `item_use_flow` をすべて hide してから対象アクターの `command_menu.show_for(actor)` を呼ぶ。コストはほぼゼロ。

### D6: 撤回後のメニューカーソルはリセット

戻り先メンバーのコマンドメニューはカーソルが先頭(攻撃)から始まる。前回選んだ位置の復元は実装複雑度を増やすうえに「やり直したい」という意図とも整合しないため対象外(D1〜D5 の動作に対するスタンスを明確化)。

## Risks / Trade-offs

- **[Risk] 副作用ある submit が将来追加されると undo が破綻** → **Mitigation:** 「`resolve_turn` 前は副作用なし」をテストで明示的に固定する(`withdraw_command` 後に `are_party_commands_complete` が `false` に戻ること、HP/MP が変化していないこと等)。新しいコマンド種別追加時のレビュー観点として明記。
- **[Risk] 先頭アクター時の `ui_cancel` が無反応で「壊れて見える」** → **Mitigation:** Wizardry / DQ 系のメニュー慣習に沿った既定挙動。今回は許容(将来必要なら "戻れません" の SE / フラッシュを追加可)。
- **[Risk] サブフロー(Cast/Item)のキャンセル仕様と取り違える混乱** → **Mitigation:** 既存サブフローのキャンセルは `_route_to_panel_cancellable` でパネル内側、新しいアクター間 cancel は `panels.overlay.request_undo_actor()` でルーター上層、と層を分ける。テストでも層別に検証。
- **[Trade-off] カーソル位置の復元なし** → 仕様簡素化を優先。

## Migration Plan

- 旧セーブやランタイム状態は変わらない(state machine の追加経路のみ)。
- 段階リリース不要。1 PR で完結。
- ロールバック: PR を revert すれば元に戻る(API 追加と分岐追加のみで、既存挙動の削除はない)。

## Open Questions

- なし。
