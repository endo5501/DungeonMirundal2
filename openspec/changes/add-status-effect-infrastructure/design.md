## Context

Phase 0 で `CombatActor.modifier_stack` と命中式が整備された。本 change はその上に「状態異常の汎用基盤」を載せる。具体的な status (sleep / poison など) は **一切追加しない**。代わりに、後続 4 つの change が個別の `.tres` を `data/statuses/` に置くだけで動くよう、すべての枠組みと flow フックを準備する。

設計上の制約:

- `Character` は `RefCounted` で永続データを持つ。シリアライズは `to_dict` / `from_dict` 経由
- `CombatActor` は `RefCounted` で battle-scoped な wrapper。`PartyCombatant` は `Character` への参照を保持し、そちらへ書き戻す
- `TurnEngine.resolve_turn(rng) -> TurnReport` は既存契約があり、`COMMAND_INPUT → RESOLVING → COMMAND_INPUT` の遷移を持つ
- `SpellEffect` 階層は既に `DamageSpellEffect` / `HealSpellEffect` の 2 件があり、`apply(caster, targets, spell_rng) -> SpellResolution` 契約が立っている
- `EncounterCoordinator` がダンジョン側の `step_taken` シグナルを購読する経路を持つ

スコープ前提（探索フェーズで決定済み）:

- フラグセット型（複数 status 並列、例外なし）
- 重複付与 = duration 上書き (= max(現存, 新規))
- battle-only は戦闘終了で全消去
- persistent は cure か街帰還で消去（街帰還は実 status の change で扱う）
- 抵抗 = 差し引き式 (effective = chance - resist, clamp 0..1)
- Player resist = race + job 加算 / Monster resist = MonsterData 個別

## Goals / Non-Goals

**Goals:**

- `status-effects` capability を新設し、StatusData / StatusRepository / StatusTrack の責務を確定する
- `Character.persistent_statuses` を導入し、シリアライズに統合する
- `CombatActor.statuses` を導入し、blind/silence/confusion/action_lock 等のフラグ照会 API を提供する
- `RaceData` / `JobData` / `MonsterData` に `resists` フィールドを足し、Player は race+job 加算で参照する
- `SpellResolution.entries` を events list 形式に拡張する（既存 hp_delta も維持）
- 新 SpellEffect 4 種と新 ItemEffect 2 種のクラスを実装する（実 .tres は積まない）
- `TurnEngine` に「ターン頭 tick」「戦闘終了の battle-only クリア」「persistent 書き戻し」「action_locked / cast_silenced / confusion 差替」のフックを通す
- `EncounterCoordinator` のダンジョン step に persistent_statuses の tick フックを通す
- 既存の SpellEffect (Damage / Heal) は events list で書けるよう内部を再構成するが、外向きの動作は変えない

**Non-Goals:**

- 具体的な status の追加 (sleep / silence / poison / petrify / confusion / blind / paralysis)
- 具体的なバフ・デバフ呪文の `.tres` 追加
- 具体的な cure アイテム `.tres` 追加
- temple での status cure UI 追加（次 change で）
- party-status / esc-menu-status の status 表示 UI 改修（実 status を入れる Phase で対応）
- combat overlay のアイコン表示
- 特殊 cure 経路（dios で sleep のみ解除、など）の細かい絞り込み — Phase 2 以降のデータで表現する

## Decisions

### Decision 1: StatusData のスキーマと scope の意味

```gdscript
class_name StatusData
extends Resource

enum Scope { BATTLE_ONLY = 0, PERSISTENT = 1 }

@export var id: StringName = &""
@export var display_name: String = ""
@export var scope: int = 0  # Scope

# 行動制御
@export var prevents_action: bool = false
@export var randomizes_target: bool = false
@export var blocks_cast: bool = false
@export var hit_penalty: float = 0.0  # blind 用 (attacker 側に適用)

# 持続
@export var default_duration: int = 0  # BATTLE_ONLY なら turn 数。PERSISTENT は無視 (cure専用)

# tick (HP 減量。0 ならなし)
@export var tick_in_battle: int = 0   # battle のターン頭で適用
@export var tick_in_dungeon: int = 0  # dungeon の step ごとに適用

# cure 条件
@export var cures_on_damage: bool = false      # 例: sleep
@export var cures_on_battle_end: bool = false  # 例: BATTLE_ONLY 全般

# 抵抗
@export var resist_key: StringName = &""  # 通常は id と同じ。複数 status が同じキーを共有することも可
```

**Scope の挙動契約**:
- `BATTLE_ONLY` の status は `CombatActor.statuses` でのみ保持される。`Character.persistent_statuses` には**書き戻されない**。`tick_in_dungeon` は無視される（フィールドはあっても使われない）
- `PERSISTENT` の status は `CombatActor.statuses` で保持され、戦闘終了時に `Character.persistent_statuses` へコピーされる。`tick_in_battle` も `tick_in_dungeon` も両方有効

**理由**: scope を一つの enum で持つと「battle終了でcureされる」と「dungeon step tickがある」の組合せが曖昧になるが、実用 statuses (sleep / poison / petrify) は2分類でカバーできる。混合 (例: 出血が dungeon でも battle でも tick) は将来必要になったら scope=PERSISTENT で表現できる。

### Decision 2: StatusTrack のデータ構造と API

```gdscript
class_name StatusTrack
extends RefCounted

# Dictionary[StringName, int]: status_id -> remaining duration
# PERSISTENT な status は duration を -1 (sentinel) で保持
var _entries: Dictionary = {}

const PERSISTENT_DURATION := -1


func apply(status_id: StringName, duration: int) -> void:
    if _entries.has(status_id):
        var existing: int = _entries[status_id]
        if existing == PERSISTENT_DURATION:
            return  # PERSISTENT は上書きしない
        if duration == PERSISTENT_DURATION:
            _entries[status_id] = PERSISTENT_DURATION
            return
        _entries[status_id] = max(existing, duration)
    else:
        _entries[status_id] = duration


func has(status_id: StringName) -> bool:
    return _entries.has(status_id)


func cure(status_id: StringName) -> bool:
    return _entries.erase(status_id)


func cure_all_battle_only(repo: StatusRepository) -> Array[StringName]:
    var cured: Array[StringName] = []
    for sid in _entries.keys():
        var data := repo.find(sid)
        if data == null:
            continue
        if data.scope == StatusData.Scope.BATTLE_ONLY:
            cured.append(sid)
    for sid in cured:
        _entries.erase(sid)
    return cured


# Returns an array of {status_id, hp_loss, killed_by_tick}
func tick_battle_turn(actor, repo) -> Array:
    var report: Array = []
    var to_remove: Array[StringName] = []
    for sid in _entries.keys():
        var data: StatusData = repo.find(sid)
        if data == null:
            continue
        # 1) tick HP
        if data.tick_in_battle > 0 and actor.is_alive():
            var before := actor.current_hp
            actor.take_damage(data.tick_in_battle)
            report.append({
                "status_id": sid,
                "hp_loss": before - actor.current_hp,
                "killed_by_tick": not actor.is_alive(),
            })
        # 2) duration decrement (PERSISTENT は decrement しない)
        var dur: int = _entries[sid]
        if dur != PERSISTENT_DURATION:
            dur -= 1
            if dur <= 0:
                to_remove.append(sid)
            else:
                _entries[sid] = dur
    for sid in to_remove:
        _entries.erase(sid)
    return report


# Returns int: total HP loss from dungeon ticks (so EncounterCoordinator
# can produce a single popup if it likes).
func tick_dungeon_step(character, repo) -> int:
    var total := 0
    for sid in _entries.keys():
        var data: StatusData = repo.find(sid)
        if data == null:
            continue
        if data.scope != StatusData.Scope.PERSISTENT:
            continue
        if data.tick_in_dungeon <= 0:
            continue
        # Floor at HP=1: dungeon ticks SHALL NOT kill characters
        var loss: int = mini(data.tick_in_dungeon, max(0, character.current_hp - 1))
        if loss > 0:
            character.current_hp -= loss
            total += loss
    return total


func handle_damage_taken(actor, repo) -> Array[StringName]:
    # Returns the list of statuses that were cured by `cures_on_damage`.
    var cured: Array[StringName] = []
    for sid in _entries.keys():
        var data: StatusData = repo.find(sid)
        if data == null:
            continue
        if data.cures_on_damage:
            cured.append(sid)
    for sid in cured:
        _entries.erase(sid)
    return cured


func active_ids() -> Array[StringName]:
    return _entries.keys()
```

**理由**: status は `id` 単位で 1 entry のみ（重複付与は上書きで増えない）。PERSISTENT は duration を -1 で sentinel 表現することで、tick logic 内でも自然に「decrement しない」「BATTLE_ONLY 一掃で残る」が表現できる。

`cure_all_battle_only` と `handle_damage_taken` は `StatusRepository` 参照が必要（scope や cures_on_damage を読むため）。`StatusTrack` 自体には repo を持たせず、呼び出し側 (`TurnEngine` / `EncounterCoordinator`) が渡す方針にする。これは `Character` に `RefCounted` への余計な参照を残さないため。

### Decision 3: PERSISTENT の duration sentinel

`apply(&"poison", duration)` を呼ぶとき、永続化したい場合は呼び出し側が `StatusTrack.PERSISTENT_DURATION (-1)` を渡す。`StatusInflictSpellEffect` 側で `status_data.scope == PERSISTENT` のときは `duration` 入力を無視して `PERSISTENT_DURATION` を渡すよう実装する。

```gdscript
# StatusInflictSpellEffect.apply
func apply(caster, targets, spell_rng) -> SpellResolution:
    var res := SpellResolution.new()
    var data: StatusData = ... # repo lookup by status_id
    for target in targets:
        var entry := res.add_entry(target, 0)
        var resist := target.get_resist(data.resist_key)
        var effective := clamp(chance - resist, 0.0, 1.0)
        var roll := spell_rng.roll(0, 99) / 100.0   # or randf() — TBD
        if roll < effective:
            var dur := duration if data.scope == StatusData.Scope.BATTLE_ONLY \
                        else StatusTrack.PERSISTENT_DURATION
            target.statuses.apply(data.id, dur)
            entry.events.append({"type": "inflict", "status_id": data.id, "success": true})
        else:
            entry.events.append({"type": "resist", "status_id": data.id})
    return res
```

`SpellRng.roll(low, high) -> int` は既存の API。決定性のため `randf` ではなく `roll(0, 99) / 100.0` で確率を再現する案を採用する（既存 SpellRng が `roll` のみ提供）。

### Decision 4: SpellResolution の events list 拡張

```gdscript
class_name SpellResolution
extends RefCounted

var entries: Array = []  # [{actor, actor_name, hp_delta, events: Array}]


func add_entry(actor: CombatActor, hp_delta: int) -> Dictionary:
    var entry := {
        "actor": actor,
        "actor_name": actor.actor_name if actor != null else "",
        "hp_delta": hp_delta,
        "events": [],
    }
    entries.append(entry)
    return entry  # 呼び出し側が events に追加可能
```

**event 種別の標準形** (Dictionary 表現):

| type | 追加フィールド |
|------|----------------|
| `damage` | `amount: int` (正の整数, 既存 hp_delta も同期) |
| `heal` | `amount: int` |
| `inflict` | `status_id: StringName`, `success: bool` |
| `cure` | `status_id: StringName` |
| `resist` | `status_id: StringName` |
| `stat_mod` | `stat: StringName`, `delta: Variant`, `turns: int` |
| `tick_damage` | `status_id: StringName`, `amount: int` |
| `wake` | `status_id: StringName` |

`hp_delta` フィールドは下位互換のため `Damage / Heal / TickDamage` の総合計を符号付きで持つ。CombatLog の既存描画 (`SpellResolution.format_entries`) は `hp_delta` だけ見ているので壊れない。新描画は events を見るよう拡張可能だが、本 change では描画ロジックの差し替えは行わない（実 status を入れる Phase 2+ で）。

**既存 DamageSpellEffect / HealSpellEffect** の改修は最小限:
```gdscript
# DamageSpellEffect.apply
var entry := resolution.add_entry(target, after - before)
entry.events.append({"type": "damage", "amount": before - after})
```

これだけで events list に格納される。

### Decision 5: `Character.persistent_statuses` のシリアライズ

```gdscript
# character.gd
var persistent_statuses: Array[StringName] = []

func to_dict(...) -> Dictionary:
    var d := {
        ...
        "persistent_statuses": [String(s) for s in persistent_statuses],  # GDScript 風: array comprehension は無いので for ループで構築
    }

func from_dict(data, ...) -> Character:
    ...
    var raw: Array = data.get("persistent_statuses", [])
    ch.persistent_statuses = []
    for s in raw:
        ch.persistent_statuses.append(StringName(s))
```

`from_dict` は不在キーを空配列で扱う（既存の `known_spells` と同じパターン）。

**戦闘開始 → 終了の流れ**:

1. `EncounterCoordinator` が `PartyCombatant.new(character, equipment)` を作るとき、コンストラクタ内で `for sid in character.persistent_statuses: statuses.apply(sid, PERSISTENT_DURATION)` を実行する
2. 戦闘中に新しい persistent status が付与されることがある（呪文で petrify など）
3. `TurnEngine._finish` で各 PartyCombatant の `commit_persistent_to_character()` を呼び、`character.persistent_statuses = [sid for sid in statuses.active_ids() if status_repo.find(sid).scope == PERSISTENT]` に更新
4. battle_only は `cure_all_battle_only` で消去

### Decision 6: `RaceData` / `JobData` / `MonsterData` の `resists` 追加

```gdscript
# race_data.gd
@export var resists: Dictionary = {}  # StringName -> float (0..1)
```

```gdscript
# job_data.gd
@export var resists: Dictionary = {}
```

```gdscript
# monster_data.gd
@export var resists: Dictionary = {}
```

既存の `.tres` ファイルすべてに `resists = {}` を追加する（空 dict）。本 change では値設定はしない（Phase 5 などで blind に弱い種族を調整するなど、必要に応じて）。

`CombatActor.get_resist` の実装:

```gdscript
# CombatActor (default)
func get_resist(_resist_key: StringName) -> float:
    return 0.0

# PartyCombatant
func get_resist(resist_key: StringName) -> float:
    if resist_key == &"":
        return 0.0
    var r := character.race
    var j := character.job
    var sum := 0.0
    if r != null:
        sum += float(r.resists.get(resist_key, 0.0))
    if j != null:
        sum += float(j.resists.get(resist_key, 0.0))
    return clamp(sum, 0.0, 1.0)

# MonsterCombatant
func get_resist(resist_key: StringName) -> float:
    if resist_key == &"" or _data == null:
        return 0.0
    return clamp(float(_data.resists.get(resist_key, 0.0)), 0.0, 1.0)
```

clamp は呼び出し側 (StatusInflictSpellEffect) でも掛けるので二重だが、防御的に維持する。

### Decision 7: TurnEngine の挿入箇所

```
resolve_turn(rng):
  if state != COMMAND_INPUT: return
  state = RESOLVING

  # ▼ NEW: ターン頭 tick
  for actor in all_actors:
    var ticks := actor.statuses.tick_battle_turn(actor, status_repo)
    for t in ticks:
      report.add_tick_damage(actor, t.status_id, t.hp_loss, t.killed_by_tick)

  # ▼ NEW: ターン頭 tick で全滅したら早期終了
  if _all_party_dead() or _all_monsters_dead():
    _finish_with_battle_end_cleanup(report)
    return report

  # 既存: Defend 適用
  ...
  # 既存: Escape 判定
  ...
  # 既存: 行動順走査
  for actor in order:
    if not actor.is_alive(): continue

    # ▼ NEW: action_lock チェック
    if actor.has_action_lock():
      report.add_action_locked(actor)
      continue

    # ▼ NEW: confusion 差替
    var cmd: RefCounted = ...
    if actor.has_confusion_flag():
      cmd = _confuse_command(cmd, actor, rng)  # AttackCommand に置換

    # 既存: 各コマンド分岐
    if cmd is CastCommand:
      # ▼ NEW: silence チェック
      if actor.has_silence_flag():
        report.add_cast_silenced(actor, cmd.spell_id)
        continue
      _resolve_cast(actor, cmd, rng, report)
    elif cmd is AttackCommand:
      _resolve_attack(actor, cmd.target, rng, report)
    ...

  # ▼ NEW: 戦闘終了処理を統合
  _end_turn_cleanup()  # modifier_stack tick (Phase 0) + status の cure_on_damage 処理は別経路
  ...
  if cleared / wiped:
    _finish_with_battle_end_cleanup(report)
  else:
    state = COMMAND_INPUT


func _finish_with_battle_end_cleanup(report):
  # ▼ NEW: battle-only status を全消去
  for actor in party + monsters:
    var cured := actor.statuses.cure_all_battle_only(status_repo)
    for sid in cured:
      report.add_cure(actor, sid)
  # ▼ NEW: persistent status を Character へ書き戻し
  for actor in party:
    if actor is PartyCombatant:
      actor.commit_persistent_to_character(status_repo)
  # ▼ NEW: modifier_stack の battle-only 消去
  for actor in party + monsters:
    actor.modifier_stack.clear_battle_only()
  _finish(...)
```

`_end_turn_cleanup` は既存の defend クリア + Phase 0 の modifier tick を維持し、`_finish_with_battle_end_cleanup` を新設して battle 終了時のみ呼ぶ。`_finish` を直接呼ぶ既存 4 経路（CLEARED / WIPED / ESCAPED / 早期 town escape）すべてを `_finish_with_battle_end_cleanup` 経由に置き換える。

### Decision 8: damage_taken 時の cures_on_damage

`take_damage` を直接 hook するか、`_resolve_attack` / `tick_battle_turn` の damage 適用後にチェックするかを決める必要がある。

**選択**: `CombatActor.take_damage()` 内に最低限のフックは入れず、TurnEngine 側で `take_damage` 直後に `actor.statuses.handle_damage_taken(actor, status_repo)` を呼ぶ方針。理由:

- `CombatActor.take_damage` は status_repo を持たず、それを引き渡す経路を増やしたくない
- damage の発生元が複数 (`_resolve_attack`, `_resolve_cast`, tick_battle_turn) あるので、それぞれの呼び出しサイトで明示的に `handle_damage_taken` を呼ぶ方が漏れも見つけやすい
- アイテム経由のダメージ（毒矢等）は将来の Phase 範囲外

```gdscript
# _resolve_attack 内
effective_target.take_damage(result.amount)
var woke := effective_target.statuses.handle_damage_taken(effective_target, status_repo)
for sid in woke:
    report.add_wake(effective_target, sid)
```

### Decision 9: `EncounterCoordinator` のダンジョン step tick

```gdscript
# EncounterCoordinator._on_step_taken (新規追加)
func _on_step_taken(...):
    # 既存: encounter manager の cooldown 更新等
    # ▼ NEW: パーティ全員に dungeon step tick を適用
    if _guild != null:
        for ch in _guild.get_all_characters():
            if ch.is_dead():
                continue
            var loss := ch.status_track_for_persistent().tick_dungeon_step(ch, status_repo)
            # loss を UI 通知するには? — 本 change では単に内部処理。
            # 個別 status の Phase で popup 等を入れる
```

ただし `Character` 自体に `StatusTrack` を持たせるか、`persistent_statuses` の Array から都度 `StatusTrack` を build するかは設計判断。

**選択**: `Character` に直接 `StatusTrack` を持たせず、`Character.persistent_statuses: Array[StringName]` のみ保持。dungeon step tick は専用の関数 `StatusTickService.tick_character_step(character, repo) -> int` を新設してそこで処理する。理由:

- `StatusTrack` は battle 中の duration 管理 (turn) を含むので Character 永続側と機能が違う
- 永続側は duration 不要なので Array で十分
- step tick で `character.current_hp -= loss` を直接行う

```gdscript
class_name StatusTickService

static func tick_character_step(character: Character, repo: StatusRepository) -> Dictionary:
    # Returns {total_loss: int, ticks: [{status_id, amount}]}
    var result := {"total_loss": 0, "ticks": []}
    if character.is_dead():
        return result
    for sid in character.persistent_statuses:
        var data: StatusData = repo.find(sid)
        if data == null or data.tick_in_dungeon <= 0:
            continue
        var loss: int = mini(data.tick_in_dungeon, max(0, character.current_hp - 1))
        if loss > 0:
            character.current_hp -= loss
            result.total_loss += loss
            result.ticks.append({"status_id": sid, "amount": loss})
    return result
```

`EncounterCoordinator` は `StatusTickService.tick_character_step` を `_on_step_taken` 経路で各 PartyMember に呼ぶ。

### Decision 10: ダンジョン step tick の StatusRepository アクセス

`StatusRepository` はどこから引いてくるか?

**選択**: `DataLoader.load_status_repository()` を新設し、`EncounterCoordinator._init` で受け取ってフィールドに保持する。`TurnEngine` は同じインスタンスを `set_status_repo()` で受け取れるようにする（`spell_repo` と同じパターン）。

### Decision 11: 新 SpellEffect クラスの構成

```gdscript
# StatusInflictSpellEffect
@export var status_id: StringName
@export var chance: float = 1.0          # 0..1
@export var duration: int = 3              # turns (BATTLE_ONLY 時のみ意味あり)
@export var status_repo_path: String = "" # 使わない: SpellEffect は state 持たず repo は別経路で渡す
```

`status_repo` をどう渡すか問題: `SpellEffect.apply(caster, targets, spell_rng)` の API は変えないので、TurnEngine から SpellEffect に明示的に渡せない。

**選択**: `Engine` （シングルトン）か `DataLoader` のキャッシュから引く。`DataLoader` は既に `load_spell_repository()` のキャッシュを持つので、同様に `load_status_repository()` を作り、`SpellEffect.apply` 内で `DataLoader.new().load_status_repository()` を呼ぶ（シングルトン化はしないが、`load_*` メソッドが内部キャッシュを持つので実害なし）。

これは `add-magic-system` の `TurnEngine.get_spell_repo()` と対称な構造。

### Decision 12: 新 SpellEffect / ItemEffect は実装するが .tres は積まない

本 change はあくまで「土管」。クラスとテストは載せるが、`data/spells/*.tres` や `data/items/*.tres` の追加は行わない。次 change 以降が個別の実 status の `.tres` を載せるたびに、対応する spell/item の `.tres` も追加する流れ。

**理由**:
- 1 change の規模を抑える
- 個別 status の挙動 (例: sleep の duration / chance) は実 status を入れる Phase で議論したい
- 空の framework class はテスト一括で網羅できる

## Risks / Trade-offs

- **[StatusRepository をどう渡すかの一貫性] → Mitigation**: `DataLoader.new().load_status_repository()` のキャッシュ前提を明確に test で検証する（複数回呼んでも同じインスタンス）。
- **[`Character.persistent_statuses` を入れたら既存 セーブが旧形式] → Mitigation**: from_dict で `data.get("persistent_statuses", [])` で空配列フォールバック。開発段階のため後方互換は最低限。
- **[`PartyCombatant.commit_persistent_to_character` のタイミングミス] → Mitigation**: ESCAPED / CLEARED / WIPED の各経路から確実に呼ばれるよう、`_finish_with_battle_end_cleanup` 一箇所に集約してテストで網羅する。WIPED 後の persistent_statuses は「死亡時点で持っていた status を残す」かが議論の余地あり — 復活後も毒のまま、はゲーム的には正しいので維持する。
- **[events list で SpellResolution の hp_delta との二重持ち] → Mitigation**: `add_entry` の戻り値で entry を返し、events に追記しても `hp_delta` は呼び出し側で同期する責務を持たせる。テストで一致を検証。
- **[confusion 差替フックを敷くだけだが行動の一貫性が失われる] → Mitigation**: 本 change で `actor.has_confusion_flag()` は常に false なのでフックは発火しない。Phase 5 で confusion を入れるとき、ターゲット解決ロジック (`_pick_living_party` 等) を共有して書く設計を design 側で予め整える。今は `_confuse_command` のスタブを追加するに留める。
- **[StatusData の field 数が多くて 認知コストが高い] → Mitigation**: 11 個程度に収まる。Wizardry 風の少数 status しか入らない見込みなら、後で deprecate する余地もあるが当面は明示性重視で展開する。

## Migration Plan

開発段階のため移行は不要。`from_dict` の `persistent_statuses` 不在フォールバックのみ実装する。
