## Context

本プロジェクトはターン制戦闘の骨格（`TurnEngine` / `CombatActor` / `CombatOverlay` / `BattleResolver`）と消費アイテムフロー（`ItemEffect` / `ItemCondition` / `ItemUseFlow`）を備えるが、職業の差別化要素として中核となる魔法システムが未実装である。`Character.current_mp` / `JobData.has_magic` / `JobData.base_mp` / MP 回復ポーション（`heal_mp_effect`）といった「MP の容れ物」だけが先行して用意されており、呪文そのもののデータと詠唱フローを足せば一気にゲーム性が変わる状態にある。

設計上の制約:

- 既存戦闘の構造は `TurnEngine` がコマンド順に解決する Wizardry 風で、新コマンドは「Attack / Defend / Escape / UseItem」と同列に追加する形になる（`combat-engine` spec）。
- `MonsterPanel` は種類ごとに集約表示されているため、敵グループ概念（種類単位）が UI と自然に合致する（`combat-overlay` spec）。
- 消費アイテムが既に `ItemEffect` （ダメージ／回復スクリプト）と `ItemCondition`（使用条件）の Strategy 構造を持つので、呪文効果はこの設計を踏襲できる（`consumable-items` / `item-use-flow`）。
- セーブフォーマットは `Character.to_dict` / `from_dict` を経由する。古いセーブを読めるようにする後方互換が要件（`serialization`）。
- 呪文選択 UI は既存の `CursorMenuRow` パターン（`cursor-menu-ui`）に沿う。

スコープ前提（探索フェーズで決定済み）:

- 単一 MP プール／二系統（MAGE / PRIEST）／レベル到達で自動習得／戦闘外詠唱 ESC 経由のみ／状態異常・バフ・ユーティリティ呪文は別 change。

## Goals / Non-Goals

**Goals:**

- 8 つの呪文（即時ダメージ／即時回復のみ）を `.tres` データとして同梱する
- 戦闘内コマンドに「魔術」「祈り」を追加し、職に応じて出し分けする
- ESC メニュー経由で戦闘外でも回復呪文を詠唱できる
- レベルアップ時に、職と新レベルに応じた呪文を `Character.known_spells` へ自動追加する
- セーブ／ロードを後方互換つきで拡張する
- 既存テスト（`tests/combat/` / `tests/dungeon/` / `tests/save_load/`）の互換を保つ

**Non-Goals:**

- 状態異常（睡眠／毒／麻痺）／バフ・デバフ／ユーティリティ呪文（脱出・位置確認）の追加
- 呪文失敗判定／モンスターの呪文抵抗
- 属性弱点（火／冷／神聖）の差別化（v1 では効果計算上は同等扱い）
- 呪文 Lv3 以上の呪文
- 戦闘外で攻撃呪文を詠唱できる導線（v1 では戦闘外詠唱は scope=`OUTSIDE_OK` の呪文のみ）
- INT / PIE 値による呪文威力／消費 MP 補正
- 呪文の購入・スクロール・学習費

## Decisions

### D1. 呪文データの表現: `SpellData` を `JobData` / `MonsterData` と並列の Custom Resource にする

**選択**: `SpellData` を `Resource` 派生のクラスとして実装し、`data/spells/<id>.tres` に格納する。`SpellRepository` が起動時に `DataLoader.load_all_spells()` で読み込む。

**理由**: 既存の `JobData` / `MonsterData` / `RaceData` / `ConsumableItemData` が同じパターンを採っており、データロードと参照の経路がそろう。エディタで `.tres` を直接編集できる利点も同じ。

**代替案**: GDScript dict 直書き（廃案）。エディタで触れず、id / display_name / mp_cost のような数値の調整にコード変更が必要になる。

```gd
class_name SpellData extends Resource

@export var id: StringName            # &"fire" など
@export var display_name: String      # "ファイア"
@export var school: StringName        # &"mage" or &"priest"
@export var level: int                # 1, 2 (v1)
@export var mp_cost: int
@export_enum("ENEMY_ONE", "ENEMY_GROUP", "ALLY_ONE", "ALLY_ALL") var target_type: int
@export_enum("BATTLE_ONLY", "OUTSIDE_OK") var scope: int
@export var effect: SpellEffect       # サブリソース（Strategy）
```

### D2. 呪文効果の表現: `ItemEffect` と並列の Strategy パターン

**選択**: `SpellEffect`（抽象、`Resource` 派生）と具象 `DamageSpellEffect` / `HealSpellEffect` を導入する。`SpellData.effect` にサブリソースとして埋め込む。

**理由**: `src/items/effects/heal_hp_effect.gd` / `heal_mp_effect.gd` が既に同型の構造を持つ。同じデザインに揃えれば、呪文／アイテムの効果を将来的に共通化する可能性も残る。サブリソースで `.tres` 内に効果パラメータを保持できるため、効果差し替えがエディタで完結する。

**代替案A**: `SpellData` に `effect_type: enum` と `effect_value: int` を直接持たせ、`SpellResolver` で switch する平坦設計（廃案）。新効果追加のたびに resolver を変更する必要があり、状態異常／バフを別 change で足す時にスキーマが膨らむ。

```gd
class_name SpellEffect extends Resource
# 派生クラスで apply(caster, targets, rng) -> SpellResolution を実装

class_name DamageSpellEffect extends SpellEffect
@export var base_damage: int
@export var spread: int  # ±N の RNG 揺れ

class_name HealSpellEffect extends SpellEffect
@export var base_heal: int
@export var spread: int
```

`SpellResolution` は `Array[ActorEffect]` のような単純な値オブジェクト（誰が何 HP 増減したか）で、`TurnReport` および ESC フローで共通に使用する。

### D3. JobData スキーマ変更: `has_magic` を 2 系統 bool に分割し、`spell_progression` を追加

**選択**: `JobData.has_magic: bool` を**廃止**し、`mage_school: bool` と `priest_school: bool` を追加。さらに `spell_progression: Dictionary` を追加し、職レベル → 取得呪文 ID 配列のマップを保持する。

**理由**: 二系統の判別を一箇所で済ませる。Bishop は `mage_school=true` かつ `priest_school=true` で表現できる。`spell_progression` を JobData 上に持たせることで、ジョブごとに `.tres` だけでバランスを調整できる。

```gd
@export var mage_school: bool
@export var priest_school: bool
# {1: ["fire", "frost"], 3: ["flame", "blizzard"]}
@export var spell_progression: Dictionary
```

**代替案A**: `has_magic` を残して `magic_schools: PackedStringArray` を追加（廃案）。bool 1 つ＋配列 1 つは冗長で、`has_magic` の役目が曖昧になる。

**代替案B**: 別リソース `SpellProgression` を作って JobData に参照を持たせる（廃案）。今回 8 呪文／4 職分なので、ファイル分割するメリットが薄い。

**マイグレーション**: 既存 8 つの `.tres` を一括書き換え。`fighter / thief / ninja` は両 bool 共に `false`、`spell_progression = {}`。`mage / priest` は片方が true、`bishop` は両方 true、`samurai` は `mage_school=true` のみで Lv4 開始、`lord` は `priest_school=true` のみで Lv4 開始。

| Job | mage_school | priest_school | spell_progression |
|---|---|---|---|
| fighter | false | false | {} |
| thief | false | false | {} |
| ninja | false | false | {} |
| mage | true | false | {1:[fire,frost], 3:[flame,blizzard]} |
| priest | false | true | {1:[heal,holy], 3:[heala,allheal]} |
| bishop | true | true | {2:[fire,frost,heal,holy], 5:[flame,blizzard,heala,allheal]} |
| samurai | true | false | {4:[fire,frost], 8:[flame,blizzard]} |
| lord | false | true | {4:[heal,holy], 8:[heala,allheal]} |

### D4. 呪文習得の経路: `Character.create` と `Character.level_up` の2点に集約

**選択**:

- `Character.create()` 経路で、`p_job.spell_progression.get(1, [])` を `known_spells` の初期値として登録する（Lv1 で取得する呪文）。
- `Character.level_up()` 経路で、新しい `level` がキーに存在するなら、その配列を `known_spells` にマージ追加する（重複は除く）。

**理由**: 既に `level_up` は `max_hp / max_mp` を更新しているため、既存ロジックと一致する場所で呪文取得を行うのが自然。`gain_experience` ループで複数レベル一気に上がる場合も、各 `level_up()` 内で正しく処理される。

**代替案A**: 別ヘルパー `SpellProgression.grant(character, level)` を独立に呼ぶ（廃案）。呼び出し漏れリスクが残る。

### D5. CombatActor インターフェース: MP は CombatActor 共通の概念にする

**選択**: `CombatActor` に `current_mp: int` / `max_mp: int` / `spend_mp(amount: int) -> bool` を追加する。`PartyCombatant` は `Character.current_mp` を proxy する。`MonsterCombatant` は `current_mp = 0`、`max_mp = 0`、`spend_mp` は常に false を返す（v1 ではモンスターは魔法を使わない）。

**理由**: 戦闘ロジック（`TurnEngine.resolve_turn`）が PartyCombatant / MonsterCombatant を区別せずに扱えるよう統一する既存方針（`combat-actor` spec）に従う。`spend_mp` の戻り値で MP 不足を呼び出し側に通知できる。

```gd
# spend_mp returns true if amount <= current_mp; reduces current_mp by amount.
func spend_mp(amount: int) -> bool
```

**代替案**: PartyCombatant 側だけに MP を持たせる（廃案）。Cast コマンドの解決時に actor 種別判定が必要となり、抽象が漏れる。

### D6. 戦闘コマンドの追加: `Cast` を 4 番目（または 5 番目）の `CombatCommand` として追加

**選択**: `Cast` コマンドを既存の `Attack` / `Defend` / `Escape` / `UseItem` と同じレベルで `TurnEngine` に submit できるようにする。

```gd
class_name CastCommand
var spell: SpellData
var caster_index: int  # party index
var target: CastTarget  # 単体: 具体 actor; グループ: MonsterPanel の種類; 全体: side
```

`TurnEngine.resolve_turn(rng)` で `Cast` 解決時:

1. `caster.spend_mp(spell.mp_cost)` を呼ぶ。`false` なら「MP不足」のログを残してスキップ（命令は失敗する）。
2. `spell.effect.apply(caster, resolved_targets, rng)` で `SpellResolution` を取得。
3. `SpellResolution` を `TurnReport` に詰めて UI に渡す。

**理由**: 既存コマンド（Attack / Defend / Escape / UseItem）の処理経路と整合する。

**MP 不足時の扱い**: コマンド入力フェーズの時点で UI 側が MP 不足を検出し、選択不可にする（リスト上で半透明表示）。万一すり抜けても resolver で graceful にスキップ。

### D7. ターゲット解決: グループ＝モンスター種別、全体＝陣営

**選択**:

- `ENEMY_ONE`: 生存している MonsterCombatant 1 体
- `ENEMY_GROUP`: 同一 `MonsterData` の生存している MonsterCombatant 全員
- `ALLY_ONE`: 生存している PartyCombatant 1 体
- `ALLY_ALL`: 生存している PartyCombatant 全員

**理由**: `MonsterPanel` が species 単位で集約表示している既存仕様（`combat-overlay`）と整合。グループ概念を「種別」と定義することで、UI 上でも自然に「スライムの群れ」「ゴブリンの群れ」を選択肢として提示できる。

**死亡ターゲットの扱い**: コマンド入力時点では生存していたが、解決時に既に死亡している場合：

- ENEMY_ONE / ALLY_ONE → 同サイドの生存者へリターゲット（順序: 同種の生存者 → 任意の生存者）。生存者ゼロならスキップ。
- ENEMY_GROUP → 残った生存者だけに効果適用。全滅ならスキップ。
- ALLY_ALL → 生存者だけに効果適用。

これは `combat-engine` の既存「dead target retarget」ルールに準拠。

### D8. 戦闘内 UI フロー

```
CommandMenu (5 entries: 攻撃/防御/魔術*/祈り*/アイテム/逃げる)
  │ * 魔術: mage_school=true の職のみ表示
  │ * 祈り: priest_school=true の職のみ表示
  │
  ├─ 「魔術」/「祈り」 選択
  │     ↓
  │  CombatSpellSelector (Caster の known_spells から school 一致の呪文を抽出)
  │     ↓
  │  選択された SpellData に応じて
  │     ├─ ENEMY_ONE → CombatTargetSelector (敵単体)
  │     ├─ ENEMY_GROUP → CombatTargetSelector (敵種別)
  │     ├─ ALLY_ONE → CombatTargetSelector (味方単体)
  │     └─ ALLY_ALL → 即確定
  │     ↓
  │  CastCommand を TurnEngine に submit
```

`CombatSpellSelector` / `CombatTargetSelector` は新規 Control。`CombatItemSelector` を雛形にする（リスト表示＋カーソル＋確定）。

**Bishop の扱い**: コマンドメニューに「魔術」と「祈り」が両方並ぶ。それぞれ選ぶと該当系統の known_spells のみフィルタされる。

### D9. 戦闘外詠唱（ESC メニュー）

**選択**: `EscMenu` のパーティサブメニュー（既存の「ステータス」「アイテム」「装備」と並列）に「じゅもん」を追加する。フローは既存の `ItemUseFlow` に準じた `SpellUseFlow` を新設する。`EscMenu` の View enum に `SPELL_FLOW` を追加する。

```
ESCメニュー → パーティ
  ├ ステータス    ←既存
  ├ アイテム      ←既存
  ├ 装備          ←既存
  └ じゅもん      ←新規
       ↓
  詠唱者選択 (魔法職のみリスト表示)
       ↓
  系統選択 (魔術/祈り)  Bishop のみ。それ以外は唯一の系統に直行
       ↓
  呪文選択 (scope == OUTSIDE_OK のもののみ表示)
       ↓
  ターゲット選択 (ALLY_ONE / ALLY_ALL)
       ↓
  MP 消費 → 効果適用 → 結果ログ
```

戦闘外で詠唱可能な呪文は `scope = OUTSIDE_OK` のものに限定する（v1 では `ヒール / ヒーラ / オールヒール` の 3 つ）。攻撃呪文（敵対象）は戦闘外で対象が存在しないため、`scope = BATTLE_ONLY` を単独でフィルタ条件にする。

### D10. セーブフォーマット拡張と後方互換

**選択**: `Character.to_dict` に `"known_spells": Array[String]` を追加する。`Character.from_dict` ではキーが存在しない場合に `JobData.spell_progression` を `current level` までリプレイして再構築する。

**理由**: 既存セーブファイルを読めなくしないため、欠損時の安全なフォールバックを必須とする。`save-manager` / `serialization` 既存テストとの整合をとる。

```gd
# from_dict pseudocode
if data.has("known_spells"):
    ch.known_spells = StringName 配列に変換
else:
    ch.known_spells = []
    for lv in 1..ch.level:
        for sid in ch.job.spell_progression.get(lv, []):
            if sid not in ch.known_spells:
                ch.known_spells.append(sid)
    push_warning("...legacy save migrated...")
```

### D11. テスト戦略（TDD）

各層で先にテストを置く（プロジェクト方針）:

1. `tests/dungeon/test_spell_data.gd`: SpellData 読み込み、必須フィールド存在
2. `tests/dungeon/test_spell_repository.gd`: 起動時ロード、id 検索
3. `tests/dungeon/test_job_data.gd`（拡張）: 新フィールド存在、 spell_progression の妥当性
4. `tests/dungeon/test_character.gd`（拡張）: create／level_up 経路で known_spells が正しく入る
5. `tests/save_load/test_character_serialization.gd`（拡張）: known_spells の往復、欠損時フォールバック
6. `tests/combat/test_turn_engine.gd`（拡張）: Cast コマンド解決、MP 消費、ターゲット解決、リターゲット
7. `tests/combat/test_spell_effects.gd`（新規）: DamageSpellEffect / HealSpellEffect の効果計算
8. UI 関連は overlay レベルでスモーク（コマンドメニューの出し分けと選択フロー）

## Risks / Trade-offs

- **JobData スキーマの破壊的変更が広い** → 影響範囲: 既存の 8 つの `.tres` ／ `tests/dungeon/test_job_data.gd` ／ `Character.create` ／ セーブ JSON。緩和: 1 PR でまとめ切り替えし、`has_magic` 参照を全コードベースから grep で抜く。テストでスキーマを保証。
- **古いセーブの自動マイグレーションが完全には保証できない** → `spell_progression` の改修によって過去キャラが今のテーブルとずれる可能性。緩和: マイグレーション時に `push_warning` で告知し、現行 `spell_progression` を全レベル分リプレイする方式で「将来テーブル」に追従させる。
- **戦闘外詠唱が攻撃呪文を持たないため、Bishop 以外は単純フローしか試せない** → v1 の意図的なスコープ制限。状態異常／バフを足す別 change で自然に増える。
- **状態異常・バフを別 change にしたことで、Mage/Priest の戦闘上の差別化が「ターゲット種別の差」だけになる** → v1 の戦闘テンポを壊さないための意図的トレードオフ。後続 change（KATINO/MOGREF/MATU 等）で深みを足す前提。
- **モンスター側に魔法を導入していない** → モンスターが呪文を撃たないため、プレイヤーは MP 切れの圧力を受けにくい。緩和: 別 change `add-monster-magic` で対応。
- **MP 不足時の UI フィードバック** → CombatSpellSelector で残量による無効化表示と、TurnEngine 側でのフェイルセーフを二重化する。テストでカバー。

## Migration Plan

1. **データ層**: `SpellData` / `SpellEffect` / 派生クラスを追加 → `data/spells/*.tres` 8 ファイルを作成 → `SpellRepository` ／ `DataLoader.load_all_spells()` 追加。テスト先行。
2. **JobData 改修**: スキーマ変更（has_magic 削除、`mage_school` / `priest_school` / `spell_progression` 追加）→ 既存 8 つの `.tres` 更新 → JobData テスト更新。
3. **Character 改修**: `known_spells` 追加、`create` / `level_up` 経路で習得処理 → save 経路の往復対応 → 後方互換テスト追加。
4. **CombatActor 改修**: MP 系統を共通インターフェースに昇格、`spend_mp` 追加。MonsterCombatant は no-op 実装。
5. **TurnEngine 改修**: `CastCommand` 追加、解決ロジック、リターゲット → ユニットテスト。
6. **戦闘 UI**: CommandMenu 改修（魔術／祈りエントリ）、CombatSpellSelector / CombatTargetSelector 新設、CombatOverlay の状態遷移に組み込み → スモークテスト。
7. **ESC メニュー**: SpellUseFlow 新設、ESC メニューに「じゅもん」追加 → スモークテスト。
8. **統合**: 全テスト緑、フィクスチャ／既存セーブの互換確認、`openspec validate add-magic-system --strict` で検証。

ロールバック: 1 つの change として archived 前であれば `git revert` で戻せる。データ層のみマージしたあと UI が間に合わない場合、UI 側だけ後段の小さな change に切るオプションも残す。

## Open Questions

- 戦闘外詠唱の MP 切れ／詠唱者全員死亡時のフィードバック文言は、UI スモークで決める（design 段階では文言まで詰めない）。
- 呪文威力のバランス調整値（base_damage / base_heal）は `.tres` に書き下ろす段階で実数を決める。テストではプレースホルダ値で動作確認のみ行い、バランス調整は別タスク扱いとする。
- 将来 INT/PIE 補正を入れるとき、`SpellEffect.apply` のシグネチャに `caster.get_attribute(...)` を渡せる余地は確保するが、v1 では参照しない。
