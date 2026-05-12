## Why

現状、魔法 (魔術/祈祷) を使えるのはパーティキャラクターのみで、モンスター側は `MonsterCombatant` 内で MP を持つことすら禁止されている (`_read_max_mp() → 0`、`spend_mp(>0) → false`)。`TurnEngine` のモンスター行動分岐も「reachable な party member を1人殴る」一択のハードコードで、戦闘の戦術的駆け引きが片側に偏っている。

`SpellEffect.apply(caster, targets, rng)` は既に `CombatActor` を受け取る汎用 API として実装されており、silence/混乱/状態異常などの周辺機構もパーティ専用の前提を持っていない。データとアクタとエンジンの3層の制約を外せば、モンスターが既存のスペル基盤をそのまま使って魔法を撃てるようになる。

## What Changes

- **`MonsterData` に魔法関連フィールドを追加** — `max_mp_min: int`, `max_mp_max: int`, `known_spells: Array[StringName]`。既存の `.tres` ファイルは未指定で MP 0 / known_spells 空 のフォールバックでロードできる (後方互換)。
- **`Monster` インスタンスに MP をロール** — `max_hp` と同様、生成時に RNG で `max_mp` を範囲内決定し `current_mp = max_mp` で開始する。
- **`MonsterCombatant` の詠唱禁止を解除** — `_read_max_mp` / `_read_current_mp` / `_write_current_mp` / `spend_mp` を標準実装に置き換える。v1 monsters cannot cast のコメントも撤去。
- **新規 capability `monster-ai`** — `static MonsterAi.choose(monster: MonsterCombatant, ctx, rng) -> RefCounted` (返り値は `AttackCommand` または `CastCommand`、もしくは null=待機)。重み付き乱択を基本に、scope/MP/known_spells で絞り、回復系は HP 閾値、群体系は対象側 ≥2 のときだけ選ぶ。純粋関数で TDD 可能。
- **`TurnEngine` のモンスター分岐をリプレース** — ハードコード attack の代わりに `MonsterAi.choose(...)` の戻り値を使う。`CastCommand` 経路に乗ることで既存の `silence`/`action_lock`/`confusion` ロジックがモンスター側でも自動的に機能する。
- **`_resolve_cast_targets()` を side-relative 化** — `target_type == ENEMY_*` は「caster の反対側」、`ALLY_*` は「caster の自陣」を意味するように再解釈する。既存スペル `.tres` は不変、`fire.tres` 一つでパーティとモンスター双方向のキャストを表現する。
- **新規モンスター 6 種を追加** — `witch`, `dark_priest`, `imp`, `lich`, `goblin_shaman`, `wraith`。それぞれ妥当な `known_spells` 構成と `default_row` / `attack_range` を持つ。バランス値 (HP/MP/attack/defense/agility/EXP/gold) は v1 範囲に収める。
- **戦闘画像はダミーで OK** — 既存資産から流用 or 透明 PNG を使う。後の差し替えを妨げない `assets/images/monsters/<id>.png` の配置のみ守る。
- **HUD 仕様** — モンスター MP は UI 非表示 (Wizardry 流)。詠唱の発生/効果はログとダメージ/ヒール演出に乗る (既存の `actor_dealt_damage` / `actor_healed` / `actor_status_inflicted` 経路で自動)。

## Capabilities

### New Capabilities

- `monster-ai`: モンスター戦闘行動の決定ロジック。`MonsterAi.choose(monster, ctx, rng)` が AttackCommand / CastCommand / null を返す純粋関数。MP・既知スペル・スコープ・味方/敵の生死/HP割合を入力に、重み付き乱択ベースの行動選択ポリシーを定義する。

### Modified Capabilities

- `monster-data`: `max_mp_min` / `max_mp_max` / `known_spells` フィールドを追加。新規モンスター 6 体 (witch / dark_priest / imp / lich / goblin_shaman / wraith) の `.tres` 出荷義務を追加。
- `combat-actor`: `MonsterCombatant` の MP/cast 禁止契約を撤回。`MonsterCombatant.spend_mp` / `_read_*_mp` / `_write_current_mp` が他の `CombatActor` と同じ意味論で動くことを規定。
- `combat-engine`: モンスター行動分岐に `MonsterAi.choose(...)` を経由させる。`CastCommand` がモンスターから submit されたケースの解決経路を規定し、`silence` / `action_lock` / `confusion` 既存ガードがモンスター詠唱にも自然に適用されることを明示する。
- `spell-casting`: `target_type` の解釈を side-relative にする。`ENEMY_*` は caster の反対側、`ALLY_*` は caster の自陣。target 解決時の retarget 規則も両側対称になることを規定。
- `monster-data`: (上記と統合)

## Impact

- **Affected code (実装側)**:
  - `src/dungeon/data/monster_data.gd` — フィールド追加 + デフォルト値
  - `src/dungeon/monster.gd` — MP ロール
  - `src/combat/monster_combatant.gd` — cast 禁止コード削除、`Monster` 経由の MP 委譲を追加
  - `src/combat/turn_engine.gd` — モンスター分岐 + `_resolve_cast_targets` の side-relative 化
  - `src/combat/monster_ai.gd` — 新規ファイル
  - `data/monsters/*.tres` — 既存6体は不変、新規6体を追加
  - `assets/images/monsters/` — 新規 6 体のダミー画像
- **Affected tests**:
  - `tests/combat/test_monster_combatant.gd` — cast 禁止前提のテストが消える/書き換わる
  - 新規 `tests/combat/test_monster_ai.gd`
  - `tests/combat/test_turn_engine_monster_cast.gd` (新規) — silence/混乱/MP切れ/ターゲット切替
  - `tests/dungeon/test_monster_data.gd` — フィールド追加と pre-migration フォールバック
- **Affected specs**: 上記 Capabilities 節参照。
- **Save 互換性**: 既存セーブの `MonsterData` 参照に新フィールドが含まれない場合、`.tres` リソースのロード時にデフォルト値 (`max_mp_min=0, max_mp_max=0, known_spells=[]`) でフォールバックさせる。エンカウント中のモンスターは戦闘内でのみ存在し永続化しないので、進行中のセーブを壊さない。
- **バランス影響**: モンスター魔法導入によりプレイヤー側の難易度は上がる。新規 6 体は `dragon` 相当の高 EXP/gold で報酬を釣り合わせる。既存 6 体 (slime/goblin/bat/skeleton/ghost/dragon) の動作は変えない。
- **Out of scope**: モンスター側の蘇生スペル (Wizardry のディ系)、ボス専用カスタム AI スクリプト、戦闘画像の本制作。これらは別 change で扱う。
