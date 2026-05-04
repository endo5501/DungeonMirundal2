## Context

Phase 0–3 までで:
- `StatModifierStack` と β 規則は実装済 (Phase 0)
- `StatModSpellEffect` クラスは実装済 (Phase 1)
- `_end_turn_cleanup` での `tick_battle_turn` (duration decrement) と battle 終了時の `clear_battle_only` も実装済 (Phase 0/1)
- CombatLog の `stat_mod` 行描画も Phase 2 で定義済

つまり「データを置けば動く」状態。本 change は純粋に `.tres` 追加とジョブ progression 更新のみ。

## Goals / Non-Goals

**Goals:**

- 7 本のバフ/デバフ呪文 `.tres` を追加する
- Mage の Lv2 に debuff 3 本、Priest の Lv2 に buff 3 本、Priest の Lv3 に全体 DEF バフ 1 本
- Bishop の spell_progression を反映
- 統合テストで「バフによってダメージ計算結果が実際に変わる」を検証する

**Non-Goals:**

- AGI バフ呪文 (素早さ操作は影響範囲が大きいので Phase 5 以降に検討)
- 対全体への ATK/DEF バフを Mage 側に持たせる (Priest 専門で残す)
- 命中/回避の上限以上の段（±0.4 の壁を超えるための重ね掛け呪文）
- 複数同時の混合効果 (例: ATK+2 と DEF+1 を同時にかける呪文) — 単機能呪文に統一

## Decisions

### Decision 1: 数値スケール

`StatModifierStack` の β 規則で「強い側勝ち」だが、刻みは:

- ATK / DEF: ±2 (整数)
- HIT / EVA: ±0.2 (= 2 段。`MOD_CAP` の半分)
- duration: 4 ターン

これにより、1 回かけると 4 ターン残り、その間に同 stat の弱いバフ (+1) を受けても上書きされない。逆により強い (+3) が来れば置換される (Phase 0 の β 規則)。

ATK ±2 / DEF ±2 は素ステータスが概ね 5–15 のレンジなので、効果として ~20–40% の差となり、明確に体感できる。HIT/EVA の ±0.2 は最終 hit_chance に直接 ±0.2 影響するので、戦闘 1〜2 ターンで効果が見える。

### Decision 2: 7 本のラインナップと住み分け

```
                              ATK         DEF         HIT         EVA
                              ───         ───         ───         ───
 Mage debuff (敵対象)         (なし)      morlis      sopic       dilto
                                          ENEMY_ONE   ENEMY_GROUP ENEMY_ONE
                                          DEF -2      HIT -0.2    EVA -0.2

 Priest buff (味方対象)       bamatu      porfic      varyu       (なし)
                              ALLY_ONE    ALLY_ONE    ALLY_ONE
                              ATK +2      DEF +2      HIT +0.2

 Priest 全体 (Lv3)            (なし)      maporfic    (なし)      (なし)
                                          ALLY_ALL
                                          DEF +2
```

非対称な理由:
- ATK -2 を Mage debuff に入れると「Mage 1 人で全員のヒット力を削る」が強すぎる。代わりに Mage は「DEF を直接下げる morlis」「敵集団の命中を下げる sopic」「敵 1 体の回避を下げて殴りやすくする dilto」の三種に絞る
- Priest は守備系を充実 (DEF / HIT 強化) させ、攻撃 buff (bamatu = ATK+2) を 1 つだけ入れる。EVA buff は今回入れない (理由: 戦士に評価が回らないと dios の存在意義が薄れる)
- maporfic は Priest 高位呪文の伝統に乗せて全体 DEF バフ。BATTLE_ONLY (戦闘外で全体 DEF アップしても無意味)

### Decision 3: scope の選択

- 個別呪文 (porfic / bamatu / varyu) は ALLY_ONE で OUTSIDE_OK。バフを「街で事前にかけておく」運用は modifier_stack の battle-only クリアで戦闘開始時に消えるので、実質的には戦闘内のみ機能する。OUTSIDE_OK にしたのは ESC メニュー経由で「呪文を覚えているか確認するために唱えてみる」みたいな利用を許可するため
- maporfic は ALLY_ALL で BATTLE_ONLY。戦闘外でかけても無意味なので明確に battle-only
- Mage debuff 系はすべて BATTLE_ONLY (敵がいない場面で唱えられない)

### Decision 4: spell_progression 更新

| Job | 追加 |
|-----|------|
| Mage Lv2 | morlis, dilto, sopic（既存 katino, manifo に追加 → 計 5） |
| Priest Lv2 | porfic, bamatu, varyu（既存 dios に追加 → 計 4） |
| Priest Lv3 | maporfic（既存 heala, allheal, madi に追加 → 計 4） |
| Bishop Lv2 | morlis, dilto, sopic, porfic, bamatu, varyu の 6 本を追加 (既存 7 本に → 計 13) |
| Bishop Lv5 | maporfic を追加 (既存 6 本に → 計 7) |

Bishop が肥大するが、これは Bishop が遅咲きで多芸という設計意図に合致。

### Decision 5: 数値検証テストの粒度

```gdscript
func test_morlis_lowers_target_defense_by_2():
    # 戦闘 setup, mage が slime に morlis
    # turn 1 解決後、slime.modifier_stack.sum(&"defense") == -2
    # 同条件で fighter が殴ると damage が +1 (def/2 が小さくなる影響)

func test_porfic_raises_ally_defense_by_2():
    # priest が fighter に porfic
    # 敵に殴られたとき damage が -1
    
func test_modifier_clears_after_battle():
    # 戦闘終了で modifier_stack が空になる

func test_modifier_decays_over_4_turns():
    # turn 1 で +2 / 4 turns
    # turn 5 開始時 (4 turn 経過後) で 0
```

DamageCalculator のフォーミュラを統合的に検証するため、固定 RNG で挙動を厳密にテストする。

### Decision 6: stat_mod イベントの発火

ALLY_ALL の maporfic は SpellResolution.entries が 4 件 (party 4 人想定) で、それぞれに `stat_mod` イベントが 1 件ずつ載る。CombatLog はそれらを 4 行表示する。

```
priest はマポーフィックを唱えた
  alice の防御 が +2 上昇した
  bob の防御 が +2 上昇した
  carol の防御 が +2 上昇した
  dave の防御 が +2 上昇した
```

(描画スタイルは Phase 2 で定義した stat_mod テンプレートに従う)

## Risks / Trade-offs

- **[bamatu (ATK+2) と morlis (DEF-2) を併用すると ダメージが過大になる] → 観察事項**: 数値設定は意図的にやや強め。バランス調整は実装後のプレイテストで対応。
- **[呪文ラインナップが 7 本で命名カバレッジに穴 (ATK debuff Mage がない)] → Mitigation**: 探索段階で「最低限のセット」と決めたので問題なし。後続 Phase で穴を埋める change を出せる。
- **[OUTSIDE_OK にした個別 buff を街で唱えても意味がない (戦闘開始時に消える)] → Mitigation**: 動作上は問題ないが、プレイヤーが混乱する可能性。ESC メニュー側でメッセージ「(戦闘外でかけても効果は持続しません)」を補足できるが、本 change スコープ外。
- **[Bishop Lv2 が 13 本同時取得は多すぎる印象] → 観察事項**: 既存 magic-system change で Bishop は Lv2 で 4 本同時取得していたので、増分自体は許容内 (4 → 13 = +9)。

## Migration Plan

開発段階のため移行不要。
