## Context

Phase 1 までで:
- StatusData / StatusRepository / StatusTrack の土管が通っている
- StatusInflictSpellEffect / CureStatusSpellEffect / CureStatusItemEffect の SpellEffect / ItemEffect が実装済
- TurnEngine がターン頭 tick / action_lock / cast_silenced のフックを持っている
- TurnReport が `tick_damage`, `wake`, `inflict`, `cure`, `resist`, `action_locked`, `cast_silenced` の 8 種類のエントリを記録できる
- ただし実 status は 1 つも `data/statuses/` に存在しない、よってフックは発火しない

本 change で初めて実 status をデータ投入し、CombatLog / CommandMenu で人間に見せる。

## Goals / Non-Goals

**Goals:**

- sleep / silence の `.tres` を追加し、StatusRepository.find が機能することを確認する
- katino (sleep 付与) / manifo (silence 付与) / dios (sleep 解除) の 3 呪文を追加し、Mage / Priest / Bishop の spell_progression に組み込む
- wake_powder アイテム（覚醒の粉）を追加する
- silence 中の Cast コマンドが UI でも resolution でも噛み合うこと（UI で disable / resolution で握り潰し）
- CombatLog で 8 種類のエントリ種別を視覚化する
- 戦闘外で dios を使って眠っている味方を起こせる（ESC メニューじゅもん経由）

**Non-Goals:**

- poison / petrify / blind / paralysis / confusion 等の追加（後続 change）
- バフ・デバフ呪文（Phase 4）
- combat overlay でのアイコン表示（status の見た目アイコン化は将来）
- party-status 表示の改修（Phase 3 で persistent と一緒にやる方が自然）
- 種族・職業の resist チューニング（resists の `.tres` は空のまま — Phase 5 でまとめてバランス調整）

## Decisions

### Decision 1: sleep の duration 設計

`default_duration = 3` とし、katino の `StatusInflictSpellEffect.duration = 3` を採用する。理由:

- 1 だと寝た直後に起きるので戦術として弱い
- 5 以上だと起きない前提でゲームが終わる（ボス戦が壊れる）
- Wizardry 系の感覚として「寝たら 2-3 ターンは硬直」が一般的

`cures_on_damage = true` で被弾起床を表現。`tick_battle_turn` の duration decrement で 3 ターン後に自動起床。

### Decision 2: silence の duration 設計

`default_duration = 4` とし、manifo の `StatusInflictSpellEffect.duration = 4` を採用する。理由:

- silence は被弾で解除しない (`cures_on_damage = false`) ので、duration が短すぎるとほぼ無意味
- 4 ターンで「呪文を主な攻撃手段とする敵への嫌がらせ」として機能
- `cures_on_battle_end = true` で戦闘終了時には自動回復するので長期影響なし

### Decision 3: katino の chance / manifo の chance

`katino.chance = 0.6`, `manifo.chance = 0.55`. 理由:

- 状態異常はかかれば強烈なので生 chance は 0.5 〜 0.65 程度に抑える
- katino は ENEMY_GROUP（複数体に同時判定）で広域効果なので、単体に対する成功率は低めで設定
- manifo は ENEMY_ONE で単体だが「呪文使い限定で意味がある」ため、それなりの命中
- resist は本 change ではどの種族・職業・モンスターも 0 で、生 chance がそのまま effective になる

### Decision 4: dios の効果範囲

`dios = CureStatusSpellEffect(status_id=&"sleep")`, `target_type = ALLY_ONE`, `scope = OUTSIDE_OK`, `mp_cost = 2`. 理由:

- Phase 2 の段階では Priest が解除できるのは sleep のみで十分
- 「全状態異常を解除する万能呪文 (latumofis)」は Phase 3 で導入する方が、毒・石化を解除対象にできて意義深い
- ESC メニュー経由で戦闘外でも撃てるよう OUTSIDE_OK
- ALLY_ONE で対象指定。仲間が全員生存・clean だと cure は no-op になるが、結果は失敗扱いではなく「効果なし」エントリで穏やかに表現

### Decision 5: spell_progression の組み込み

| Job | 既存 | 追加 |
|-----|------|------|
| Mage | Lv1: fire, frost / Lv3: flame, blizzard | Lv2: katino, manifo |
| Priest | Lv1: heal, holy / Lv3: heala, allheal | Lv2: dios |
| Bishop | Lv2: fire, frost, heal, holy / Lv5: flame, blizzard, heala, allheal | Lv2: + katino, manifo, dios（既存と合算） |
| Samurai | 触らない |
| Lord | 触らない |
| Fighter / Thief / Ninja | 触らない |

Lv2 という「ちょうど良い空き」が Mage / Priest にあったので、ここを使う。Bishop は既に Lv2 に呪文が割当てられており、追加 3 件を後ろに append する形。

### Decision 6: wake_powder のスコープ

`CureStatusItemEffect(status_id=&"sleep")` を中身にする。`ItemUseContext` 側の制約:

- `in_battle = true` でも `in_battle = false` でも使える
- 対象は単体味方 (`ALLY_ONE` 相当)
- 既存の `target_condition` で `alive_only` を付ける（死人の sleep を起こしても意味がない）

`item_name = "覚醒の粉"`, `description = "眠っている仲間を目覚めさせる粉。"`, `consumable = true`, `stack_max = 5`.

価格は本 change ではバランス対象外として 200 G 程度に置く（shop での販売は consumable-items spec に依存）。

### Decision 7: CombatCommandMenu の silence disable 実装

```gdscript
# combat_command_menu.gd の `_build_rows()` 拡張イメージ
var cast_row := CursorMenuRow.create(...)
if combatant.has_silence_flag():
    cast_row.disabled = true
    cast_row.label = "呪文 (沈黙中)"
```

`CursorMenu` / `CursorMenuRow` の disable 機能が既存にあるなら踏襲、無ければ「選択カーソルが乗るが Enter で no-op + 「沈黙中で唱えられない」を一行表示」で簡易対応。

resolution 側 (TurnEngine) でも握り潰しがかかるので二重防御。UI で見えるだけが目的。

### Decision 8: CombatLog の文言

| Entry type | 文言テンプレート |
|------------|----------------|
| `tick_damage` | `"{actor_name} は {status_display} で {amount} ダメージを受けた"` |
| `wake` | `"{actor_name} は目を覚ました"` (status_id によって文言切り替え可能) |
| `inflict` | `"{target_name} は {status_display} になった"` |
| `cure` | `"{actor_name} の {status_display} が治った"` |
| `resist` | `"{target_name} は {status_display} に抵抗した"` |
| `action_locked` | `"{actor_name} は {status_display} で行動できない"` |
| `cast_silenced` | `"{caster_name} は唱えようとしたが声が出ない"` |

`status_display` は `StatusRepository.find(status_id).display_name` を引く。当該 id が見つからない場合は `String(status_id)` でフォールバック。

`wake` の特殊扱い: 当面は sleep しか入っていないので「目を覚ました」固定で良いが、将来 cures_on_damage が他にも出るかもしれないので status_id によって切り替えられる方が望ましい。本 change では sleep 用文言で OK。

### Decision 9: action_locked と cast_silenced のメッセージ整合

action_locked は status を伴うが、複数の status (sleep / paralysis / petrify) が prevents_action 持ち。 `actor.has_action_lock()` が true となる原因 status を 1 つだけログに出すか、複数ある場合に全部出すかは設計判断。

**選択**: 「action_locked エントリ自体は status を含まない」（シンプル）。CombatLog は actor が現在持っている prevents_action 持ち status のうち、最初に見つかったものを `status_display` として表示する。複数を持つ事例は当面 sleep のみなので問題にならない。

cast_silenced は spell_id を含むので `"アリスは『カチノ』を唱えようとしたが…"` のように呪文名も出せる。

### Decision 10: 統合テストの粒度

```gdscript
# tests/combat/test_status_sleep_integration.gd
func test_katino_puts_slime_to_sleep():
    var engine := _make_engine_with(party=[mage], monsters=[slime])
    # mage が katino を slime に
    # spell_rng の roll を 0 (絶対命中) に固定
    # turn 1 解決 → slime に sleep が付与
    assert_true(slime.statuses.has(&"sleep"))

func test_sleeping_slime_does_nothing():
    # 上の状態で turn 2 → slime が action_locked エントリで action skip
    
func test_damage_wakes_sleeping_slime():
    # turn 2 で mage が attack → slime に damage → wake が記録され statuses が空に
```

統合テストは StatusRepository を実際に load して動かす（モックではなく）。これにより `data/statuses/*.tres` の内容ミスもキャッチできる。

## Risks / Trade-offs

- **[katino の chance=0.6 が体感バランスとずれる] → Mitigation**: `.tres` の数値変更は import で済むので、バランス調整は実装後に手早くできる。テストには「具体的な roll 値で hit する」シナリオが入っているので、バランス変更時はテスト数値も合わせて触る。
- **[silence で Cast を disable しても Defend / Item / Attack はできるので戦況は崩壊しない] → 観察事項**: silence が「魔法職の専用デバフ」になり、戦士系には effectively 効かない。これは意図通り (manifo は対呪文使いカード)。
- **[Bishop の Lv2 spell_progression が肥大化（fire/frost/heal/holy + katino/manifo/dios = 7件）] → Mitigation**: 一度に 7 件覚えるのは少々派手だが、Bishop の遅成長を補う設計と捉える。気になれば後続 change で再配分。
- **[CombatLog のメッセージが冗長になる可能性 (寝てるキャラが毎ターン action_locked を出す)] → Mitigation**: 1 行 / ターンの頻度なので許容。気になれば「同じ status の連続 action_locked は 1 行に圧縮」を後続で導入。
- **[wake_powder と dios の役割重複] → 観察事項**: アイテムと呪文の併存は MP 切れリスクへの保険として正常。Wizardry 系の伝統でもある。

## Migration Plan

開発段階のため移行不要。既存 Mage / Priest / Bishop キャラの level が Lv2 以上の場合、初回ロード時に `Character._rebuild_known_spells_through_level` を経由するか、単純な再 level_up 経由で新呪文が補充される。本 change では `Character.from_dict` の不在キーフォールバックパスがそのまま動くので追加コードは不要。
