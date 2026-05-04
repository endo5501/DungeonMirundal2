## Why

Phase 0 で命中式と stat modifier の入れ物が整った。次に必要なのは「状態異常そのもの」の汎用基盤 — つまり StatusData リソース、CombatActor／Character への状態保持の仕組み、戦闘ターン頭での tick、ダンジョン step での tick、戦闘終了でのクリア、抵抗値、結果オブジェクトの events list 拡張、までの「土管」を一括で敷くことだ。本 change では具体的な状態（sleep / poison など）はまだ追加しない。土管だけ通して、後続 4 つの change が個別 status を載せるだけで動くようにする。

## What Changes

- 新規 spec `status-effects` を導入する
  - `StatusData (Resource)`: id / display_name / scope (BATTLE_ONLY | PERSISTENT) / prevents_action / randomizes_target / blocks_cast / hit_penalty / default_duration / tick_in_battle (HP減量 int) / tick_in_dungeon (HP減量 int) / cures_on_damage / cures_on_battle_end / resist_key
  - `StatusRepository`: `data/statuses/*.tres` を起動時に bulk load し id 検索を提供
  - `StatusTrack (RefCounted)`: 1 アクター分の状態保持。`apply(status_id, duration)` / `has(status_id) -> bool` / `cure(status_id)` / `cure_all_battle_only()` / `tick_battle_turn() -> Array` (turn頭で battle tick HP減量と起床判定を返す) / `tick_dungeon_step() -> int` (poison step tick の HP減量を返す) / `each_active() -> Array[StringName]`
  - 重複付与は **「status_id 単位で duration = max(現存, 新規)」** (Phase 探索で確定済)
- `CombatActor` に `statuses: StatusTrack` を追加し、battle-only な状態を保持する
- `CombatActor.has_blind_flag()` は `statuses.has(&"blind")` を返すよう **override** する（Phase 0 のスタブを実装に置換）
- `CombatActor.has_silence_flag() -> bool` / `has_confusion_flag() -> bool` / `has_action_lock() -> bool` (= sleep / paralysis / petrify いずれかの prevents_action を持つ) のヘルパーを追加
- `Character` に `persistent_statuses: Array[StringName]` を追加する
  - シリアライズに含める（開発段階のため後方互換は不要、from_dict は不在キーを空配列で扱う）
  - 戦闘開始時に `PartyCombatant.statuses.apply(...)` へコピーされる
  - 戦闘終了時、persistent な status のみが Character 側へ書き戻される
- `RaceData` / `JobData` / `MonsterData` に `resists: Dictionary` (StringName → float, 0..1) を追加する
  - Player の解決値: `race.resists.get(key, 0.0) + job.resists.get(key, 0.0)` （clamp 0..1 はせず、付与計算側で clamp）
  - Monster は `MonsterData.resists` を直接参照
  - 既存の race/job/monster の `.tres` には空 dict を入れる（本 change での値設定はゼロ初期）
- `CombatActor.get_resist(resist_key) -> float` を追加し、PartyCombatant / MonsterCombatant でそれぞれ実装
- `SpellResolution` の entry 形式を Plan B (events list) へ拡張
  - 各 entry は `{ actor, actor_name, hp_delta, events: Array }`
  - event 種別: `Damage(amount)` / `Heal(amount)` / `Inflict(status_id, success: bool)` / `Cure(status_id)` / `Resist(status_id)` / `StatMod(stat, delta, turns)` / `TickDamage(status_id, amount)` / `Wake(status_id)`
  - 既存の `hp_delta` フィールドは下位互換のため残し、Damage/Heal/TickDamage の合計と一致させる
- 新規 SpellEffect 抽象クラス階層
  - `StatusInflictSpellEffect`: `status_id` / `chance` / `duration` を持ち、`target.get_resist(status_data.resist_key)` を差し引いた effective chance で付与判定
  - `DamageWithStatusSpellEffect`: ダメージ + 付与判定（毒のダメージ呪文用）
  - `StatModSpellEffect`: バフ/デバフ呪文（attack/defense/hit/evasion 等を ±値で modifier_stack に追加）
  - `CureStatusSpellEffect`: 単体 status を cure
  - 各クラスはこの change ではクラスとテストのみ追加し、実 .tres は **載せない**（次 change 以降で）
- 新規 ItemEffect
  - `CureStatusItemEffect`: 単体 status を cure
  - `CureAllStatusItemEffect`: 全 battle-only または全 persistent を cure（オプションで scope 指定）
  - 同じく実 .tres はこの change では載せない
- `TurnEngine` のフロー変更
  - **ターン頭**（`resolve_turn` の冒頭、Defend 処理の直前）に各アクターへ `statuses.tick_battle_turn()` を呼び、battle tick ダメージを `take_damage` で適用、報告を `TurnReport` に記録する。HP=0 で `is_alive() == false` になっても行動順では既存の死亡スキップ仕様で対応
  - **ターン頭の tick による全滅** (party 全員 HP=0 / monster 全員 HP=0) は、その場で `_finish` を呼んで `WIPED` / `CLEARED` で終了
  - **行動解決** で `actor.has_action_lock()` が true なら攻撃/詠唱コマンドを no-op し `TurnReport.add_action_locked` を記録（具体 status は付与されないので Phase 1 では発火しないがフックを敷く）
  - **行動解決** で actor の confusion フラグが true なら、`AttackCommand` の target を「敵味方の生存者からランダム」に差し替え、`CastCommand` / `ItemCommand` を「Attack 単発（同様のランダムターゲット）」に置換 — このフックも Phase 1 では発火しないが整備する
  - **CastCommand 解決時** に actor の silence フラグが true なら詠唱を握り潰し `TurnReport.add_cast_silenced` を記録（フックのみ）
  - **戦闘終了** で各アクターに `statuses.cure_all_battle_only()` を呼ぶ（`_finish` の中で）
  - **戦闘終了書き戻し** で `PartyCombatant.commit_persistent_to_character()` を呼んで persistent な status を `Character.persistent_statuses` へ更新
- `EncounterCoordinator` のダンジョン step ハンドラに、パーティ各キャラの persistent status を tick_dungeon_step させる経路を追加（毒 step ダメージを Character に直接適用、HP=1 で止める）
  - 本 change では tick_in_dungeon が 0 の status しか存在しないので発火はしないが、フックは敷く
- `TurnReport` に新エントリ種別を追加
  - `tick_damage`, `wake_up`, `inflict`, `cure`, `resist`, `stat_mod`, `action_locked`, `cast_silenced`
- 互換性: 開発段階のためセーブ移行は不要（`persistent_statuses` 不在の旧セーブは空配列で扱う 1 行のみ追加）

## Capabilities

### New Capabilities

- `status-effects`: StatusData / StatusRepository / StatusTrack の定義、事象の events list、抵抗値の解決、battle/dungeon tick の意味論を規定する。

### Modified Capabilities

- `combat-actor`: `statuses: StatusTrack` を保持する責務、`has_blind_flag` の本実装、`has_silence_flag` / `has_confusion_flag` / `has_action_lock` / `get_resist` の追加。
- `combat-engine`: ターン頭での tick、戦闘終了時の battle-only クリア、persistent status の Character への書き戻し、action_locked / cast_silenced / confusion 差し替えのフック挿入。
- `spell-casting`: `SpellResolution.entries` の events 拡張、抵抗値を取り込んだ inflict 計算、新エフェクト経路 (StatusInflict / DamageWithStatus / StatMod / CureStatus) の規定。
- `spell-data`: 新エフェクトクラスのフィールド契約（`StatusInflictSpellEffect.status_id/chance/duration` 等）。
- `items`: 新エフェクト `CureStatusItemEffect` / `CureAllStatusItemEffect` の規定。
- `race-data`: `RaceData.resists: Dictionary` の追加。
- `job-data`: `JobData.resists: Dictionary` の追加。
- `monster-data`: `MonsterData.resists: Dictionary` の追加。
- `serialization`: `Character.persistent_statuses` の to_dict / from_dict 取り扱い。

## Impact

- **影響コード**:
  - 新規: `src/combat/statuses/status_data.gd`, `src/combat/statuses/status_track.gd`, `src/dungeon/data/status_repository.gd`, `src/combat/spells/status_inflict_spell_effect.gd`, `src/combat/spells/damage_with_status_spell_effect.gd`, `src/combat/spells/stat_mod_spell_effect.gd`, `src/combat/spells/cure_status_spell_effect.gd`, `src/items/effects/cure_status_item_effect.gd`, `src/items/effects/cure_all_status_item_effect.gd`
  - 改修: `src/combat/combat_actor.gd`, `src/combat/party_combatant.gd`, `src/combat/monster_combatant.gd`, `src/combat/turn_engine.gd`, `src/combat/turn_report.gd`, `src/combat/spells/spell_resolution.gd`, `src/dungeon/character.gd`, `src/dungeon/data/race_data.gd`, `src/dungeon/data/job_data.gd`, `src/dungeon/data/monster_data.gd`, `src/dungeon/data/data_loader.gd`, `src/dungeon/encounter_coordinator.gd`
- **テスト**: status_track / status_data / status_repository / spell effects 新4種 / item effects 新2種 / character.persistent_statuses / race+job+monster.resists / turn engine の tick 経路、 confusion/silence/action_lock のフック発火だけは stub で確認 (具体 status は次 change)
- **後続依存**: Phase 2 (sleep+silence) / Phase 3 (poison+petrify) / Phase 4 (stat-mod-spells) / Phase 5 (confusion+blind+paralysis) すべての前提
- **互換性**: セーブの `persistent_statuses` 不在は空配列扱い。それ以外は破壊的変更なし。
