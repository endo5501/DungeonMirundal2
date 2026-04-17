# Design: combat-system

## Context

本 change は、monster-and-encounter が用意した「エンカウント発生 → オーバーレイ表示」のフローに、Wizardry 風のターン制戦闘本体を差し込むものである。以下の前提の上に乗る。

- **Godot 4.x + GDScript**。ロジック層は `RefCounted`、表示層は `Node`。
- **データは Custom Resource (.tres)**、`DataLoader` で一括ロード。
- **Character**（`src/dungeon/character.gd`）: `STR/INT/PIE/VIT/AGI/LUC`、`level`、`current_hp/max_hp`、`current_mp/max_mp`、`race: RaceData`、`job: JobData`。攻撃力・防御力・素早さの**派生値は未実装**。戦闘不能フラグは存在せず、`current_hp == 0` で扱う想定。
- **Monster**（`src/dungeon/monster.gd`）: `data: MonsterData` と `max_hp/current_hp` のみ。`MonsterData` は `attack/defense/agility/experience` を既に保持。
- **Guild**（`src/dungeon/guild.gd`）: `_front_row` / `_back_row` に `Character` 参照を保持。`get_party_data()` は `PartyMemberData` スナップショットを返すのみで、Character への参照経路は別途必要。
- **EncounterOverlay**（`src/dungeon_scene/encounter_overlay.gd`）: `CanvasLayer`（layer=10）スタブ。`start_encounter(party)` → 確認入力で `encounter_resolved(EncounterOutcome(CLEARED))`。
- **EncounterCoordinator**（`src/dungeon/encounter_coordinator.gd`）: `step_taken` → `should_trigger` → `generate` → `overlay.start_encounter` → `encounter_resolved` → `check_start_tile_return` を司る。`main.gd` が `_encounter_coordinator.is_encounter_active()` で ESC メニュー開示をブロック済み。
- **EncounterOutcome**: `result (ESCAPED/CLEARED/WIPED)`、`gained_experience`、`drops` のフィールドは確保済みで、現状は CLEARED 固定。
- **テスト**: GUT、`tests/<subsystem>/test_*.gd`、`extends GutTest`。

アイテム・装備は items-and-economy で本実装するため、本 change では**最小インターフェース＋ダミー実装**で済ませる。

## Goals / Non-Goals

**Goals:**
- Wizardry 風ターン制戦闘（全員のコマンド入力 → 行動順一括解決）をロジック層で完結させる
- 戦闘画面をダンジョン画面のオーバーレイとして提供し、`EncounterOverlay` を継承した `CombatOverlay` で置換する
- 契約（`encounter_resolved(outcome)` シグナル、`EncounterOutcome`）を維持し、`EncounterCoordinator` に手を入れずに済ませる
- 戦闘中 HP の書き戻しを不要にする（`Character` を直接参照して更新）
- ダミー装備を items-and-economy で無痛に差し替えられるインターフェースに閉じる
- TDD で `RefCounted` ロジックを GUT から純粋にテスト可能にする

**Non-Goals:**
- 魔法・スキル・特殊技（別 change）
- 本番アイテム・商店・教会蘇生（items-and-economy）
- 戦闘バランスの最終調整（全 change 完成後）
- 灰化・ロスト等の高度な死亡ステート（今回は `current_hp == 0` のみ）
- 戦闘アニメーションや演出強化（固定レイアウトのみ）
- セーブ中断（戦闘中のセーブ抑止は `_encounter_active` による ESC ブロックで担保済み）

## Decisions

### 1. CombatActor 統一抽象でパーティとモンスターを扱う

`Character`（Party）と `Monster`（Enemy）を直接使い分けず、`CombatActor` 抽象を経由する。

```
CombatActor (RefCounted)
  ├─ actor_name: String
  ├─ current_hp / max_hp: int
  ├─ get_attack() / get_defense() / get_agility(): int
  ├─ is_alive() -> bool  ( current_hp > 0 )
  ├─ take_damage(amount: int)
  └─ apply_defend() / clear_turn_flags()

PartyCombatant extends CombatActor
  ・character: Character を参照
  ・equipment_provider: EquipmentProvider を参照
  ・current_hp / max_hp は character を read/write（プロキシ）
  ・get_attack 等は equipment_provider 経由で計算

MonsterCombatant extends CombatActor
  ・monster: Monster を参照
  ・get_attack 等は monster.data（MonsterData）を参照
  ・current_hp / max_hp は monster を read/write
```

**理由**:
- TurnEngine / DamageCalculator が「敵か味方か」を分岐せずに書ける
- UI も同一インターフェースで両者を描画できる
- 将来、魔法や状態異常を追加する際、CombatActor に一箇所足せば両者に効く

**代替案（却下）**: TurnEngine が `Character` と `Monster` を別配列で直接扱う — コード量は少なめだが、コマンド解決・ターン順で同じ分岐が何度も現れる。却下。

### 2. 戦闘中 HP の書き戻しは「直接参照」で消す

`Guild._front_row` / `_back_row` は既に `Character` 参照を保持している。`Guild.get_party_characters() -> Array[Array[Character]]` を足し、`PartyCombatant` が `Character` を**直接参照**して `current_hp` を書き換える。

- 戦闘終了後の `PartyData` 再構築は不要。次回 `get_party_data()` 呼び出しで自動的に最新 HP が入る
- 死亡判定も `Character.current_hp <= 0` で統一
- 書き戻しフェーズやイベント配線が不要になり、テストも単純化

**代替案（却下）**: 戦闘専用の可変コピーを作って終了時に書き戻す — 書き戻し漏れと二重管理の温床。却下。

### 3. 死亡・戦闘不能は `current_hp == 0` のみ

`Character` に `status` enum を導入せず、`current_hp <= 0` を「戦闘不能」として扱う。

- 蘇生・灰化・ロストは別 change（items-and-economy 以降）の仕事
- `is_alive()` は `current_hp > 0`
- ターンオーダーは **戦闘不能者をスキップ**
- 全滅判定は「全 PartyCombatant が `is_alive() == false`」

**代替案（却下）**: 今のうちに `status enum { ALIVE, DEAD, ASHES, LOST }` を入れておく — YAGNI。灰化・ロストの仕様が固まっていない段階で拡張するとスキーマが固定化される。却下。

### 4. 装備は `EquipmentProvider` インターフェース + `DummyEquipmentProvider`

```
EquipmentProvider (RefCounted, 仮想的なインターフェース)
  ・get_attack(character) -> int
  ・get_defense(character) -> int
  ・get_agility(character) -> int

DummyEquipmentProvider extends EquipmentProvider
  ・職業別に固定のボーナスを返す
  ・Fighter: 攻+5/防+3、Mage: 攻+1/防+1、Priest: 攻+2/防+3 など
  ・attack = base_stats[STR] / 2 + job_weapon_bonus
  ・defense = base_stats[VIT] / 3 + job_armor_bonus
  ・agility = base_stats[AGI]
```

- items-and-economy では装備インベントリと鑑定を反映した本番 `InventoryEquipmentProvider` を差し替える
- `CombatActor` は `EquipmentProvider` 経由でのみステータスを取得し、本 change と本番で同じコードパスを通る
- TurnEngine / DamageCalculator は `EquipmentProvider` を知らず、`CombatActor.get_*()` を叩くだけ

**代替案（却下）**: `Character` に `equipment: Equipment` フィールドを直接持たせる — 本 change では装備品データ型を定義しないため、`Character` に「宙ぶらりんの型」を足すことになり後方互換で揉める。却下。

### 5. UI は `EncounterOverlay` を継承した `CombatOverlay` で提供

既存のスタブ `EncounterOverlay`（`CanvasLayer` layer=10）を**継承**し、子クラス `CombatOverlay` で戦闘UIを組む。

```
EncounterOverlay (existing stub)
    └─ CombatOverlay (new)
          ├─ MonsterPanel      (上段: 種別別生存数)
          ├─ PartyStatusPanel  (下段左: Character 参照で HP 表示)
          ├─ CommandMenu       (下段右: こうげき/ぼうぎょ/にげる)
          ├─ CombatLog         (固定高さ、直近 4 行)
          └─ ResultPanel       (終戦時: EXP・LvUp 通知)
```

- `EncounterCoordinator` が生成するクラスを `CombatOverlay` に差し替えるため、**`EncounterCoordinator` の生成メソッドを DI 化**する（コンストラクタ or セッター）
- スタブテスト（`test_encounter_overlay.gd`）は **親クラスの契約（非表示・可視化・signal 発火）** を守る限り継続テスト可能
- `CombatOverlay` は `start_encounter(monster_party)` を override して内部 `TurnEngine` を初期化
- `encounter_resolved(outcome)` の発火点は「結果画面確認入力」に移る

**代替案（却下）**:
- まるごと差し替え: スタブテストが破棄対象となり、契約の回帰保護が弱まる。却下。
- コンポジション（Overlay が内部に CombatController を持つ）: CombatController の Node/RefCounted 判断が必要になり、`CanvasLayer` ライフサイクルと二重管理になる。却下。

### 6. 全滅時は `EncounterOutcome.WIPED` → 町に強制送還

- `TurnEngine` が全滅を検出したら `EncounterOutcome(result=WIPED)` を返す
- `CombatOverlay` は結果画面で「全滅しました」を表示し、確認入力で `encounter_resolved(WIPED)` を発火
- `main.gd` 側で `_encounter_coordinator.encounter_finished` を受けた後、直近 outcome が WIPED なら `_on_return_to_town()` に相当する遷移を発火
- `GameState.heal_party()` は既存。町帰還時に呼ばれるため、Character の HP は町で回復される
- 灰化・ロストは本 change では起こさない（Non-Goal）

### 7. 経験値・レベルアップは Wizardry 1 風

- **配布**: 勝利時 `Σ(monster.experience)` を計算し、**戦闘参加メンバー全員**（戦闘不能者を含む）に**均等配布** (`floor(total / count)`)
  - Wizardry 1 の挙動に揃える。配布経路のテストが書きやすい
- **経験値テーブル**: `JobData.exp_table: PackedInt64Array`。index `i` は「レベル `i+1` から `i+2` へ上がるのに必要な累計 EXP」（**それまでの総獲得 EXP がこの値以上なら次レベル**）
  - 初期データは Wizardry 1 の各職 EXP テーブルを参考にした固定値（Fighter 1000/1724/..., 職ごとに上昇係数調整）
- **レベルアップ効果**:
  - `level += 1`
  - `max_hp += job.hp_per_level + stats[VIT] / 3`（最小 1）、`current_hp += 同値`
  - `max_mp += job.mp_per_level`（`has_magic` のみ）、`current_mp += 同値`
  - ステータス成長（STR/INT/... のロール）は**本 change では行わない**（スコープ外・拡張余地として残す）
- **多段レベルアップ**: 累計 EXP が複数レベル分を超えていたら、1 回の `gain_experience(exp)` 呼び出しで繰り返しレベルアップする
- **職業別 `exp_table` / `hp_per_level` / `mp_per_level` の追加**: `JobData` を MODIFIED（ADDED フィールド）

**代替案（却下）**: 生存者のみ配布（Wizardry 3 以降風）— 戦闘不能者が経験値を得ず追いつけないゲーム性は今回避ける。

### 8. ターンエンジンの状態機械

```
        ┌────────────┐
        │  IDLE      │ start_battle() ─┐
        └────────────┘                 ▼
                              ┌──────────────┐
                              │ COMMAND_INPUT│ ← UI がコマンド提示
                              └──────┬───────┘
                                     │ all_party_commands_submitted()
                                     ▼
                              ┌──────────────┐
                              │  RESOLVING   │ ← 行動順に1アクションずつ処理
                              └──────┬───────┘
                                     │ turn_completed()
                                     ▼
                          ┌───────────────────────┐
                          │ 戦闘終了判定           │
                          │  全滅  → FINISHED(WIPED)│
                          │  掃討  → FINISHED(CLEARED)│
                          │  逃走成功 → FINISHED(ESCAPED)│
                          │  それ以外 → COMMAND_INPUT │
                          └───────────────────────┘
```

- `TurnEngine` は RefCounted で純ロジック。`RandomNumberGenerator` を注入してテスト決定論性を確保
- UI（`CombatOverlay`）は `TurnEngine` の状態を pull で読み、イベントを push する
- 1ターン内では **パーティ全員分のコマンドを先に確定** → その後に一括解決（Wizardry 1 式）

### 9. コマンドの最小セット

- **こうげき（Attack）**: 対象モンスター（1体）を選択。ダメージ = `max(1, attacker.attack - target.defense / 2 + rng.randi_range(0, 2))`
- **ぼうぎょ（Defend）**: そのターン中の被ダメージを **1/2 切捨て**。行動順に関係なく適用（ターン開始時フラグ）
- **にげる（Escape）**: パーティ単位のコマンド（1名でも選べば試行）。成功率 = `min(0.9, 0.5 + (party_avg_agi - enemy_avg_agi) * 0.05)`、初期は 0.5 固定でも可
  - 成功: `FINISHED(ESCAPED)`、失敗: そのターンは攻撃されるのみ（モンスター側のみ行動）

魔法・アイテム使用は Non-Goal。

### 10. 行動順決定

- 全参加アクター（生存者のみ）を `agility` 降順でソート
- 同値タイブレークは `rng.randi_range(0, 999)` で安定決定
- モンスターの行動は「生存パーティからランダムに1人を対象に攻撃」（魔法・戦略性は別 change）

### 11. CombatOverlay のレンダリングポリシー

- **モンスター個体 HP は非表示**。種別ごとの「生存数 / 初期数」のみ表示（Wizardry 1 式）
- パーティは `PartyDisplay`（既存）と別パネル `PartyStatusPanel` を新設。Character 参照で HP 生描画（CombatOverlay 存続中はこちらを見る）
- CombatLog は固定 4 行、古いものは上から流れる
- ResultPanel は「獲得経験値 / レベルアップ通知 / 次へ」のみ。ドロップ欄は枠だけ置き、`EncounterOutcome.drops` は常に空配列

### 12. EncounterCoordinator は触らない方針

- `EncounterCoordinator` は現状のシグナル・インターフェースのまま
- `_overlay` を `EncounterOverlay` で受けているため、`CombatOverlay` もそのまま入る（ポリモーフィズム）
- **唯一の変更**: `EncounterCoordinator._init` または生成箇所で、差し替え用コンストラクタ引数 `overlay: EncounterOverlay = null` を受け取る（省略時は現行の `EncounterOverlay`）。`main.gd` が `CombatOverlay` を注入する

### 13. 乱数ソース

- `TurnEngine` も `RandomNumberGenerator` 注入式
- 本番では `EncounterCoordinator` と同じインスタンスを使い回す（1 つの RNG で完結）
- テストは固定シード `rng.seed = 12345` で決定論的に検証

## Risks / Trade-offs

- **Wizardry 風 UI の情報密度と視認性** → MonsterPanel は個体 HP 非表示で情報量を絞る。将来演出を足す余地は `CombatOverlay` 内で完結させ、他レイヤに漏らさない。
- **ダミー装備のバランスが本番と乖離** → バランス調整は全 change 完成後に行う（Non-Goal）。`DummyEquipmentProvider` の数値は "戦闘が最低 2 ターン続く" 程度を目安に置くだけでよい。
- **`CombatOverlay` が肥大化** → サブ UI（MonsterPanel, PartyStatusPanel, CommandMenu, CombatLog, ResultPanel）を `Control` 継承の小さなクラスに分割して責務分離する。
- **ESC キー・戻るダイアログとの競合** → `_encounter_active` フラグは既に `DungeonScreen` / `main.gd` で確認済み。戦闘中に ESC を奪わない現行動作を回帰テストで守る。
- **多段レベルアップの実装漏れ** → テーブルから EXP 量の跨ぎを検出するテストを書く（例: 一気に 2 レベル上がるケース）。
- **全滅 → 町帰還時のデータ整合** → `GameState.heal_party()` が既に実装済みで Character の HP を最大まで戻す。WIPED → town 遷移は `main.gd` の `_on_return_to_town()` 相当を再利用できる。
- **`JobData` 既存 .tres への後方互換** → フィールド追加は互換。既存 8 職に `exp_table` / `hp_per_level` / `mp_per_level` を補うマイグレーションは .tres 編集のみで完結する。
- **職業別 EXP テーブル数値の暫定性** → 初期値は参考レベル。戦闘バランス最終調整で書き換わる想定で、テーブル値を「設計資産」として固定しない。

## Open Questions

- CommandMenu の入力粒度: 「キャラ1人ずつ入力 → 次のキャラへ」か「1画面で全員分を選ぶか」。実装難度は前者の方が素直だが、Wizardry 1 は前者。初期実装は **前者（キャラ1人ずつ）** で進める想定。
- ResultPanel で LvUp したキャラの「どのステータスがどれだけ伸びたか」を UI で見せるか。本 change ではステータス成長を行わないので **「Lv X になった！」のみ**で十分だが、後続でステータス成長を導入する際の UI 拡張余地としてメモしておく。
- モンスター攻撃のテンポ演出（ログを 1 行ずつ順次表示 vs 一括表示）。初期は一括表示で実装し、違和感があればタイマーを挟む。
