## Context

Phase 2 までで battle-only の状態異常 (sleep / silence) と土管 (StatusData / StatusTrack / SpellEffect 4 種) は揃っている。本 change は **永続異常** を初投入する。

設計上の制約:
- `StatusData.tick_in_dungeon: int` は Phase 1 で平 HP 量として導入された
- Wizardry 風の poison は `max_hp/16` 単位の比率削りなので、平 HP 量では表現できない
- 探索フェーズで「ratio もサブリソース化はしない」と決めたので、`StatusData` のフィールドを拡張する方が筋
- `EncounterCoordinator._on_step_taken` の hook は Phase 1 で敷いた
- `Character.persistent_statuses` も Phase 1 で導入済
- 「街に戻ると状態異常が自動回復する」は探索フェーズで決定済

## Goals / Non-Goals

**Goals:**

- StatusData に `tick_in_dungeon_ratio` を追加し、StatusTickService が `max_hp / ratio` の HP 損失を返す
- poison / petrify の 2 つの永続 status を `data/statuses/` に投入する
- poison_dart / madi / dialma の 3 つの呪文と antidote / golden_needle の 2 つのアイテムを投入する
- ダンジョン中の毒 tick が HUD に通知される
- 街帰還時にパーティ全員の persistent_statuses が自動でクリアされる
- 教会のヒント表示と ESC メニューでの状態表示
- 既存の battle-only 経路 (sleep / silence) を破壊しない

**Non-Goals:**

- 教会で個別 status を有料解除する課金システム（探索フェーズで「街帰還で自動回復」と決定済なので不要）
- 解毒テキスト演出の派手さ（HUD 通知は1行で十分）
- 石化キャラの「触れると壊れる」みたいな特殊フレーバー
- 毒のグレード差（軽毒/重毒など）
- タレント制 resist や race-specific resist チューニング（Phase 5 でまとめて）

## Decisions

### Decision 1: tick_in_dungeon_ratio フィールド設計

```gdscript
# StatusData
@export var tick_in_dungeon: int = 0          # 平 HP 量。0 なら ratio に委譲
@export var tick_in_dungeon_ratio: int = 0    # > 0 なら max_hp/ratio で計算 (優先)
```

**意味論**:
- `tick_in_dungeon_ratio > 0` のとき: `loss = maxi(1, character.max_hp / ratio)` (整数除算 + 最低 1)
- `tick_in_dungeon_ratio == 0 and tick_in_dungeon > 0` のとき: `loss = tick_in_dungeon`
- 両方 0 のとき: tick なし
- 両方 > 0 のとき: ratio が優先（design 上、両方設定する意味はないので警告のみ）

**理由**:
- 既存の平 HP 量フィールド (`tick_in_dungeon`) を残しておけば、将来「step ごとに 5 ダメージ固定の重出血」みたいな status も表現できる
- ratio フィールドを追加するだけなら spec の MODIFIED で済み、既存の status (Phase 2 の sleep / silence は dungeon tick = 0) は何も影響を受けない
- 「ratio 優先」のルールを spec 化すれば曖昧さなし

`HP=1 で止め死なせない` の floor は Phase 1 で `mini(loss, max(0, current_hp - 1))` として実装済。ratio 経由で計算した loss にも同じ式が掛かる。

### Decision 2: StatusTickService の更新

```gdscript
static func tick_character_step(character: Character, repo: StatusRepository) -> Dictionary:
    var result := {"total_loss": 0, "ticks": []}
    if character.is_dead():
        return result
    for sid in character.persistent_statuses:
        var data: StatusData = repo.find(sid)
        if data == null:
            continue
        if data.scope != StatusData.Scope.PERSISTENT:
            continue
        var requested := 0
        if data.tick_in_dungeon_ratio > 0:
            requested = maxi(1, character.max_hp / data.tick_in_dungeon_ratio)
        elif data.tick_in_dungeon > 0:
            requested = data.tick_in_dungeon
        else:
            continue
        var loss: int = mini(requested, max(0, character.current_hp - 1))
        if loss > 0:
            character.current_hp -= loss
            result.total_loss += loss
            result.ticks.append({"status_id": sid, "amount": loss})
    return result
```

`requested` を計算してから HP=1 floor を掛けるので、low-HP 時に「予定量の一部だけ食らう」が自然に表現される。

### Decision 3: poison のチューニング

| パラメータ | 値 | 根拠 |
|-----------|---|------|
| `tick_in_battle` | 1 | 戦闘中は短いので軽め。max_hp/16 を battle にも使うと8ターン戦闘で max_hp/2 食らうので過酷 |
| `tick_in_dungeon` | 0 | ratio 側を使う |
| `tick_in_dungeon_ratio` | 16 | Wizardry 古典の比率 |
| `cures_on_battle_end` | false | 永続なので戦闘終了で消えない |
| `cures_on_damage` | false | sleep と違い、被弾では治らない |

例: max_hp=32 のキャラだと step ごとに 2 ダメージ。8 歩で 16 削られるので、地下深くでの遠征がリスクになる。

### Decision 4: petrify のチューニング

| パラメータ | 値 | 根拠 |
|-----------|---|------|
| `prevents_action` | true | 戦闘中は完全停止 |
| `tick_*` | 0 | ダメージはない |
| `cures_on_battle_end` | false | 永続 |
| `cures_on_damage` | false | 殴っても解除されない |
| `randomizes_target` | false | confusion とは無関係 |

petrify は戦闘終了後も持続し、街に戻るまで石のまま。dungeon を歩けるかについては明示的に「歩ける」(parties traveling with petrified members は normal) とする — 仲間に背負われている扱い。dungeon-movement / dungeon-management 側に追加要件は出さない (歩行はパーティ全体の生存判定に依存し、石化は dead ではないので問題なし)。

### Decision 5: poison_dart の効果

`DamageWithStatusSpellEffect`:
- `base_damage = 3, spread = 1` → 2-4 ダメージ
- `status_id = &"poison"`, `inflict_chance = 0.6`, `status_duration = 0`
  - PERSISTENT scope のため duration は無視され、StatusTrack は PERSISTENT_DURATION で apply される
  - design 的には `status_duration` フィールドの値は何でも良いが、コード／テストの一貫性のため 0 を入れる

mp_cost=3 は既存 fire (mp=2) より高めで、ダメージは控えめ。代わりに毒付与を狙う。

### Decision 6: madi / dialma の住み分け

- `madi` (Priest Lv3): mp_cost=4 で `poison` のみ解除。Mage には覚えさせない (dios と同じく Priest 系)
- `dialma` (Priest Lv5): mp_cost=6 で `petrify` のみ解除。高位呪文として位置付け
- 「全状態解除」のような latumofis 的呪文は本 change で入れない (将来の Phase で必要になれば検討)

`spell_progression` 更新方針:
- Priest Lv5 を新設するため `priest.tres` に新キーを追加
- Bishop は伝統的に Priest の高位呪文を遅れて覚えるが、本 change では dialma を Bishop に与えない (Bishop が貴重すぎる回復役になりすぎないため)
- madi は Bishop の Lv5 に追加 (poison_dart も同 Lv5 で追加)

| Job | spell_progression after this change |
|-----|--------------------------------------|
| mage | { 1: [fire, frost], 2: [katino, manifo], 3: [flame, blizzard, **poison_dart**] } |
| priest | { 1: [heal, holy], 2: [dios], 3: [heala, allheal, **madi**], **5: [dialma]** } |
| bishop | { 2: [fire, frost, heal, holy, katino, manifo, dios], 5: [flame, blizzard, heala, allheal, **poison_dart**, **madi**] } |
| lord | (unchanged) |
| samurai | (unchanged) |

### Decision 7: 街帰還時の auto-cure

```gdscript
# town_scene/town_screen.gd または equivalent
func _on_arrived_in_town():
    if _guild == null:
        return
    var cured: int = 0
    for ch in _guild.get_all_characters():
        if not ch.persistent_statuses.is_empty():
            ch.persistent_statuses.clear()
            cured += 1
    if cured > 0:
        _show_town_message("教会の祈りで状態異常が癒えた")
```

- 「町に到着した瞬間」で発火する。具体的なシグナル名は `dungeon-return` spec で決まっている `town_returned` か `entered_town` を再利用
- 表示は `town_screen` の上部に小さく 1 行
- TempleScreen 自体には status cure メニューを置かない (自動なので不要)。代わりにヒント表示

### Decision 8: dungeon HUD の tick 通知

```gdscript
# encounter_coordinator.gd
signal dungeon_status_tick(character_name: String, status_id: StringName, amount: int)

func _on_step_taken(...):
    if status_repo == null or _guild == null:
        return
    for ch in _guild.get_all_characters():
        if ch.is_dead():
            continue
        var result := StatusTickService.tick_character_step(ch, status_repo)
        for tick in result.ticks:
            dungeon_status_tick.emit(ch.character_name, tick.status_id, tick.amount)
```

`DungeonHUD` (もしくは `dungeon_screen.gd`) は `dungeon_status_tick` を購読し、シンプルな Toast を 2 秒表示する。複数 tick は 1 行ずつ縦に並べる (フェードアウト時間で自動消滅)。

### Decision 9: ESC メニュー status 行

```gdscript
# esc_menu_status.gd
func _build_status_line(character: Character) -> String:
    if character.persistent_statuses.is_empty():
        return "状態: 通常"
    var names: Array[String] = []
    var repo := DataLoader.new().load_status_repository()
    for sid in character.persistent_statuses:
        var data := repo.find(sid)
        names.append(data.display_name if data != null else String(sid))
    return "状態: " + ", ".join(names)
```

複数 status 持ちは「状態: 毒, 石化」のようにカンマ区切り。

### Decision 10: temple_screen のヒント

```gdscript
# temple_screen.gd の _rebuild() 内
var hint := Label.new()
hint.text = "(街に戻ると状態異常は自動的に治ります)"
hint.add_theme_font_size_override("font_size", 14)
hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
_root.add_child(hint)
```

機能追加はなし、文言追加のみ。

### Decision 11: poison_dart の battle 時 inflict 経路

`DamageWithStatusSpellEffect.apply` で:

1. ダメージ計算 → `take_damage` → events に `damage`
2. target が is_alive() のとき:
   a. resist を引いて effective chance を計算
   b. spell_rng.roll(0, 99) で判定
   c. hit: `target.statuses.apply(&"poison", PERSISTENT_DURATION)` → events に `inflict`
   d. miss: events に `resist`
3. handle_damage_taken は呼ばれない (これは TurnEngine 側の責務)

注: PERSISTENT_DURATION で apply されたあと、battle 中の `tick_battle_turn` は「duration が PERSISTENT_DURATION なら decrement しない」(Phase 1 で規定済) なのでターン頭 tick = 1 ダメージずつ受ける挙動になる。

戦闘終了時:
- `cures_on_battle_end = false` なので battle-only クリアからは除外される
- `commit_persistent_to_character` で Character.persistent_statuses に書き込まれる
- 街帰還時に auto-cure される

## Risks / Trade-offs

- **[max_hp/16 の整数除算で max_hp が 16 未満なら always 1 ダメージ] → 観察事項**: 序盤キャラ (max_hp=10 とか) でも step ごとに 1 食らうので、序盤の毒は意外と痛い。これは Wizardry 風として正しい挙動。
- **[街帰還で全部治るので教会の蘇生以外は無料] → 観察事項**: 探索フェーズで決まった方針通り。長期的にはバランス調整で「ダメージ累積」「保険的な金消費」を入れる余地はある。
- **[poison_dart が PvE 的に強すぎる可能性] → Mitigation**: chance=0.6 / dmg=2-4 / mp=3 はやや強めだが、初期実装としては許容。プレイテスト後に調整。
- **[石化キャラのダンジョン歩行] → 観察事項**: 歩ける扱い (パーティに背負われる) で実装。既存の dungeon-movement spec は変更不要。
- **[ESC メニューと temple のテキストが冗長になる] → Mitigation**: ESC メニューは「状態: 毒」だけ、temple はヒント1行のみ。問題ない範囲。

## Migration Plan

開発段階のため移行は不要。既存セーブの `persistent_statuses` 不在は Phase 1 のフォールバックでカバー済。
