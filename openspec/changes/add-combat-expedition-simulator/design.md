# Design: add-combat-expedition-simulator

## Context

`TurnEngine`(`src/combat/turn_engine.gd`)は `RefCounted` の純ロジックで、シーンツリーにも UI にも依存しない。モンスター側は `MonsterAi.choose()` で既に自動行動する。パーティ側のコマンドは UI(`CombatOverlay`)が `submit_command()` で注入する設計であり、ここを自動化する層(PartyAi)を足せばヘッドレスで戦闘が完走する。実際 `tests/combat/test_battle_integration.gd` は while ループで戦闘を完走させている。

エンカウント編成は `EncounterManager.generate(rng)` が `EncounterTableData`(tier_weights / species_count / count_per_species)から `MonsterParty` を生成する。キャラクターは `Character` + `JobData.spell_progression`(レベルで呪文自動習得)+ `PartyCombatant`(equipment_provider 注入)で構成される。回復呪文には `SpellData.Scope.OUTSIDE_OK` があり戦闘外使用が既にモデル化されている。

## Goals / Non-Goals

**Goals:**

- パーティ構成・モンスター供給・AI ノブを設定して連戦を回し、「何戦・何ターン耐えられるか」と HP/MP 減衰カーブを再現性のある形で測定する
- 既存の戦闘コードを一切変更せず、利用者(クライアント)として実装する
- `godot --headless` で CI・ローカルから実行できる
- GUT でユニットテスト可能な純ロジック構造にする(godot-tdd スキルの RefCounted 分離パターンに従う)

**Non-Goals:**

- アイテム使用・逃走判断・隊列変更・歩行中の毒ティックの再現
- 実プレイヤーの最適行動の完全な模倣(ノブで幅を見る設計とする)
- GUI での可視化(CSV → スプレッドシートに委ねる)
- 経験値テーブルやドロップ率そのものの調整機能

## Decisions

### D1: 配置は `src/simulation/`、エントリポイントは SceneTree スクリプト

シミュレーション本体(PartyAi、遠征ループ、集計)は `src/simulation/` 配下の `RefCounted` クラス群とし、ヘッドレス起動用に `SceneTree` を継承した薄いエントリスクリプト(`src/simulation/expedition_cli.gd`)を置く。実行は:

```
godot --headless -s src/simulation/expedition_cli.gd -- --config=<path> --csv=<path>
```

`--` 以降は `OS.get_cmdline_user_args()` で取得する。

- 代替案: `tools/` 配下 → `res://` 外だとリソースロードが面倒になるため不採用
- 代替案: GUT テストとして実装 → 設定を差し替えて回す用途にはテストの形は不向き(assert が目的ではない)。ただしユニットテストは別途 GUT で書く

### D2: PartyAi は MonsterAi と同型のステートレス static クラス + 設定オブジェクト

`PartyAi.choose(member: PartyCombatant, ctx: PartyAiContext, config: PartyAiConfig, rng) -> RefCounted` として、`MonsterAi.choose()` と対称の設計にする。返り値は `AttackCommand` / `CastCommand` / `DefendCommand` のいずれか。

`PartyAiConfig`(RefCounted)がノブを保持する:

| ノブ | 既定値 | 意味 |
|------|--------|------|
| `heal_hp_threshold` | 0.6 | この割合以下の味方がいたら僧侶系は回復を優先 |
| `attack_magic_min_enemies` | 2 | 生存敵がこの数以上なら攻撃呪文を使う |
| `attack_magic_min_tier` | 0 | 敵の最大 tier がこの値以上なら敵数に関係なく攻撃呪文を使う(0 = 無効) |

優先順位(1 キャラの判断):
1. priest_school かつ `heal_hp_threshold` 以下の生存味方がいて回復呪文の MP がある → 最も HP 割合の低い味方に回復(不足 HP と回復量期待値が最も釣り合う呪文を選択)
2. mage_school かつ MP 温存条件(上表)を満たし攻撃呪文の MP がある → 攻撃呪文(生存敵が複数なら ENEMY_GROUP 優先、単体なら ENEMY_ONE)。対象は生存敵のうち HP 最大の種
3. それ以外 → 生存敵のうち先頭(reach 可能なもの)へ `AttackCommand`。reach 可能な敵がいなければ `DefendCommand`

- 代替案: ビヘイビアツリー等の汎用 AI 基盤 → 過剰。ノブ付きルールで十分であり、実プレイの幅はノブ掃引で見る方針

### D3: 遠征ループは `ExpeditionRunner`、エンカウント供給は Strategy で抽象化

```
ExpeditionRunner.run(config: ExpeditionConfig, rng) -> ExpeditionResult
  ├─ PartyFactory: 設定からCharacter/PartyCombatant生成
  ├─ EncounterSource(抽象)
  │    ├─ FixedPatternSource: 固定編成リストを順番/ループで供給
  │    └─ TableEncounterSource: EncounterTableData + MonsterRepositoryから生成
  ├─ 戦闘ループ: PartyAi.choose → submit_command → resolve_turn
  ├─ BattleResolver.resolve_rewards: 経験値・レベルアップを反映
  └─ BetweenBattleHealer: OUTSIDE_OK回復呪文をMPが許す限り使用
```

- 1 戦闘には安全上限ターン(既定 100)を設け、超えたら `STALLED` として遠征を打ち切る(無限ループ保険)
- 遠征の終了条件: 全滅(WIPED)/ 上限戦闘数到達 / STALLED
- `TableEncounterSource` は `EncounterManager` の編成生成ロジックを再利用する(遭遇判定 `should_trigger` は使わず、常に 1 戦闘を生成)

### D4: 戦闘間回復は「最も傷ついた味方 × 最も効率の良い呪文」の貪欲法

`BetweenBattleHealer.heal_party(characters, spell_repo, rng)`:

1. HP 割合が最も低い生存メンバーを選ぶ(全員満タンなら終了)
2. パーティ内の全キャスターから、MP が足り `OUTSIDE_OK` かつ回復効果の呪文を列挙
3. 過剰回復が最小になる呪文(不足 HP に最も近い期待回復量)を選んで使用
4. 誰も回復できなくなる(MP 切れ or 全員満タン)まで繰り返す

回復呪文の適用は `SpellEffect.apply` を戦闘外文脈で使うのではなく、既存の `esc_menu` の戦闘外使用と同じ経路(`HealSpellEffect` を Character に適用)に合わせる。実装時に `spell_use_flow.gd` の適用経路を確認して同じ API を使うこと。

### D5: パーティ設定・シミュレーション設定は JSON ファイル

`ExpeditionConfig` は JSON からロードする。Godot エディタなしで編集でき、ノブ掃引スクリプトからも生成しやすい。

```json
{
  "runs": 100,
  "master_seed": 12345,
  "max_battles": 50,
  "party": [
    {"name": "P1", "race": "human", "job": "fighter", "level": 3, "row": "front"},
    {"name": "P4", "race": "elf",   "job": "mage",    "level": 3, "row": "back"}
  ],
  "ai": {"heal_hp_threshold": 0.6, "attack_magic_min_enemies": 2, "attack_magic_min_tier": 0},
  "encounters": {"mode": "table", "floor": 3},
  "csv_path": "tmp/simulation/result.csv"
}
```

- `encounters.mode` は `"table"`(floor 指定)または `"fixed"`(`patterns: [{"goblin": 3}, {"slime": 2}, ...]` — species→count のフラット辞書の配列をループ)
- 装備は当面 `InitialEquipment`(職の初期装備)を自動適用。個別指定は将来拡張
- キャラクター生成: レベル 1 で `Character.create` 相当を行い、目標レベルまで既存のレベルアップ処理(経験値付与)を通す。これにより HP/MP 成長と `spell_progression` 由来の `known_spells` が本番と同一経路で決まる
- 代替案: .tres プリセット → エディタ必須になるため不採用。GDScript 直書き → 掃引に不向き

### D6: 乱数は master_seed から run ごとに導出

run i の RNG シードは `hash(master_seed, i)` で導出し、run 単位で完全再現可能にする。1 つの run 内では単一の `RandomNumberGenerator` を PartyFactory / EncounterSource / TurnEngine で共有する(既存テストと同じ流儀)。

### D7: メトリクスと出力形式

**per-battle 記録**(CSV 1 行 = 1 run × 1 battle、long format):

```
run,battle,encounter,turns,hp_pct_before_heal,party_hp_pct,party_mp_pct,deaths_cum,outcome
```

`party_hp_pct` / `party_mp_pct` は戦闘間回復**後**のパーティ合計割合(0..1 の float、小数3桁)。`hp_pct_before_heal` は回復前の値(回復呪文の寄与が見える)。`encounter` は EncounterSource.describe() のラベル(例: `floor_3`)。

**コンソールサマリ**(N runs 集計):

```
runs=100  seed=12345  encounters=floor_3
                      median   p10    p90
battles survived        12       7     23
total turns             41      25     77
first death at battle    9       5     18
MP exhausted at battle   6       4     10
end cause: WIPED 84% / MAX_BATTLES 16% / STALLED 0%
```

パーセンタイルは実装を単純にするため nearest-rank 法で算出する。

## Risks / Trade-offs

- [PartyAi が実プレイヤーと乖離し、バランスを誤読する] → ノブ掃引で楽観/悲観の幅として読む運用を README に明記。単一値を真値として扱わない
- [ヘッドレス実行で MonsterData の `battle_texture`(ctex)ロードに import キャッシュが必要] → GUT の CI 実行と同条件(`--import` 済み前提)。CI では import ステップを先行させる。テクスチャはシミュレーションでは未使用なのでロードエラー時の fallback も検討
- [TurnEngine 側の変更でシミュレータが壊れる] → シミュレータ自体を GUT テスト(小さな決定的シナリオ)で守り、public API のみ使用する
- [レベルアップが遠征中に起こり指標が非定常になる] → 仕様として許容(実プレイでも起こる)。CSV に経験値・レベルは含めず、必要になったら列を足す
- [固定 100 ターン上限で長期戦バランスの情報が切れる] → STALLED を end cause として明示し、発生率をサマリに出す

## Open Questions

- ~~戦闘外回復の適用 API の正確な形~~ → 解決済み。`spell_use_flow.gd` の `_apply_cast_and_show_result()` は (1) `Scope.OUTSIDE_OK` と MP を検査、(2) `caster.current_mp = maxi(current_mp - spell.mp_cost, 0)` で Character から直接 MP を控除、(3) caster / target を `PartyCombatant.new(character, DummyEquipmentProvider.new())` でラップ、(4) `spell.effect.apply(caster_pc, targets, SpellRng)` を呼ぶ。`HealSpellEffect.apply` が `spell_rng.roll(-spread, spread)` で回復量をロールし(最低 1)、`mini(max_hp, before + heal)` で上限キャップして `current_hp` に書き戻す(PartyCombatant 経由で Character に伝播)。Character 専用の回復 API は存在しない。`BetweenBattleHealer` はこの経路をそのまま再現している
- `attack_magic_min_tier` の tier は `MonsterData.tier` を参照するが、固定パターンモードで tier 未設定のカスタム編成をどう扱うか(既定 0 で常に敵数条件のみ、で開始)
