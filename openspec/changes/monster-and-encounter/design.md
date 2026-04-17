# Design: monster-and-encounter

## Context

本 change は、既存のダンジョン探索機能にモンスターとの遭遇（エンカウント）機構を追加するものである。戦闘そのものは後続 change（combat-system）で実装し、本 change はスタブのオーバーレイまでで止める。

既存のプロジェクト構造は以下の前提で成り立っている:
- **Godot 4.x + GDScript**、`class_name` と RefCounted / Node 分離
- **ロジック層は RefCounted**（例: `Character`, `PartyData`, `Guild`, `BonusPointGenerator`）、**表示層は Node**（例: `DungeonScene`, `DungeonScreen`, `EscMenu`）
- **データは Custom Resource (.tres)**（例: `RaceData`, `JobData` @ `data/races/`, `data/jobs/`）、ローダーは `DataLoader`
- **キャラクターステータス**: `STR` / `INT` / `PIE` / `VIT` / `AGI` / `LUC`、HP/MP は現行値・最大値を個別に保持
- **テスト**は GUT（`tests/<subsystem>/test_*.gd`、`extends GutTest`）
- **ダンジョン移動**は `DungeonScreen._unhandled_input()` で処理され、移動・旋回の成功時に `moved = true` を立て `_refresh_all()` を呼ぶ
- **オーバーレイの先例**は `EscMenu`（`CanvasLayer layer=10`）、`main.gd` が ESC キーで可視化、`move_child` で ZOrder 管理

本 change はこの前提の上に乗り、新たに外部依存は追加しない。

## Goals / Non-Goals

**Goals:**
- モンスターデータを Custom Resource で定義し、階層別に出現パターンを宣言的に管理する
- ダンジョン移動中のランダムエンカウントを**決定論的にテスト可能**な形で実装する
- エンカウント発生時にオーバーレイを表示し、ダンジョン入力を遮断・解除する
- スタブオーバーレイは、combat-system が置換する**明確なインターフェース**（シグナル契約）を提供する
- 既存 `DungeonScreen` への侵襲を最小化（コンポジション、シグナル駆動）

**Non-Goals:**
- ターン制戦闘ロジック・UI（combat-system）
- 経験値・レベルアップ・死亡処理（combat-system）
- アイテムドロップ（combat-system / items-and-economy）
- 魔法・スキル・モンスター固有行動パターン
- モンスター画像・アニメーション（スタブオーバーレイはテキスト中心で可）

## Decisions

### 1. データ形式: Custom Resource (.tres) を採用

`RaceData` / `JobData` と同じく Godot の Custom Resource を使う。

- `MonsterData` (`src/dungeon/data/monster_data.gd`, `extends Resource`)
  - `@export` フィールド: `monster_id: StringName`, `monster_name: String`, `max_hp_min: int`, `max_hp_max: int`, `attack: int`, `defense: int`, `agility: int`, `experience: int` 等
  - HP を範囲で持つのは、同種複数体を生成する際の個体差を簡潔に表現するため
- `EncounterTableData` (`src/dungeon/data/encounter_table_data.gd`, `extends Resource`)
  - `@export` フィールド: `floor: int`, `entries: Array[EncounterEntry]`（後述）
- `EncounterEntry` (`extends Resource`)
  - `pattern: EncounterPattern`（再利用可能な出現パターン）, `weight: int`
- `EncounterPattern` (`extends Resource`)
  - `groups: Array[MonsterGroupSpec]`
  - 各 `MonsterGroupSpec` は `monster_id: StringName`, `count_min: int`, `count_max: int`
  - 例: 「スライム 2〜4 + ゴブリン 1」

**理由**: エディタで編集・プレビュー可能、既存 `DataLoader` パターンとの統一、型安全。YAML/JSON は外部依存・パーサー・バリデーションを余計に持ち込むため採用しない。

**検討した代替案**:
- **JSON + スキーマバリデータ**: 外部エディタで編集しやすいが、Godot の既存データ資産がすべて .tres のため整合性が崩れる。却下。
- **辞書直書き**: プロトタイプとしては速いが、拡張時に型が崩れる。却下。

### 2. モンスターステータス: キャラクターと独立した簡略スキーマ

`Character` は `STR` / `INT` / `PIE` / `VIT` / `AGI` / `LUC` を持つが、モンスターは戦闘計算に使う**攻撃力・防御力・素早さ**に集約する。

- 根拠: Wizardry 系では敵ステータスの内部計算は簡略化されているのが通例で、本 change ではエンカウント発生までしか扱わないため戦闘計算に必要な最低限で足りる
- combat-system が必要に応じて追加フィールドを MonsterData に足せる拡張性は保つ
- Character 側とフィールド名を揃えるかは戦闘計算時の議論に回す（現時点では `attack`/`defense`/`agility`）

### 3. ロジック層の責務分割

```
┌────────────────────────────────────────────────────────┐
│ MonsterRepository (RefCounted)                          │
│  ・MonsterData を id 引きで提供                          │
│  ・DataLoader が起動時に一括ロード                       │
└────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────┐
│ EncounterTableRepository (RefCounted)                   │
│  ・階層番号で EncounterTableData を引く                  │
└────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────┐
│ EncounterManager (RefCounted)                           │
│  ・should_trigger(step_count, rng) -> bool              │
│  ・generate(floor, rng) -> MonsterParty                 │
│  ・RandomNumberGenerator を外部注入（テスト決定論）      │
└────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────┐
│ MonsterParty (RefCounted)                               │
│  ・戦闘参加モンスターのインスタンス集合                   │
│  ・生成時に MonsterData から個体 HP 等をロール            │
└────────────────────────────────────────────────────────┘
```

**ポイント**:
- すべて RefCounted、Node に依存しない → GUT で純粋にテスト可能
- `RandomNumberGenerator` は `EncounterManager` のメソッド引数またはコンストラクタ引数として受け取り、テスト時はシード固定

### 4. エンカウント発生率とチェック方式

- **方式**: 歩数ベース（`should_trigger(step_count, rng)`）。単純な「毎ステップ p% で発生」式を採用し、p は階層別に `EncounterTableData` に含める
- **旋回はステップとして数えない**（位置変化のみをステップとしてカウント）。理由: 戦闘前に安全に周囲確認したい場面でテンポが損なわれないため
- **連続エンカウント抑止**: 直前のエンカウント後は N = 3 ステップ猶予。実装では定数 `POST_ENCOUNTER_COOLDOWN` として宣言し、後のバランス調整で `EncounterTableData` への移動も検討可能にする

**検討した代替案**:
- **領域 (Area3D) 踏みで発生**: 階層マップに固定配置すると Wizardry 風のランダム感が薄れる。却下。
- **カウントダウン（次のエンカウントまで残り X 歩）**: 内部的には同等。API としては bool 返しの方が呼び出し側がシンプル。

### 5. ダンジョン統合: シグナル駆動で疎結合

既存 `DungeonScreen._unhandled_input()` を以下のように改造する（疑似構造）:

```
if moved:
    _refresh_all()
    if is_on_start_tile():
        _show_return_dialog()
    elif _encounter_manager.should_trigger(_step_count, _rng):
        _emit_encounter(_encounter_manager.generate(floor, _rng))
```

`DungeonScreen` が直接オーバーレイを生成するのではなく、新規シグナル `encounter_triggered(monster_party)` を発行する。オーバーレイの生成と入力差し替えは、**上位の調整役（現状は `main.gd` ないし `DungeonScreen` のオーナー）** が受け持つ。

**理由**:
- `DungeonScreen` は表示・入力に集中し、フロー制御は持たない
- combat-system でオーバーレイ実装を差し替える際、`DungeonScreen` を触らずに済む

### 6. オーバーレイ: `CanvasLayer` + 入力差し替え

`EscMenu` と同じパターンを踏襲:

- `EncounterOverlay` を `CanvasLayer`（`layer >= 10`）で実装
- 表示中は `DungeonScreen` の入力を停止（`set_process_unhandled_input(false)` or 上位のフラグ管理）
- ESC メニューとの競合: エンカウント中は ESC メニューを開けない（`main.gd` 側で状態チェック）
- スタブオーバーレイは「〜と遭遇！」メッセージ＋確認ボタンのみ

### 7. スタブ → 本番 UI 差し替えの契約

スタブオーバーレイ（本 change）と本番戦闘UI（combat-system）が交換可能になるよう、以下の契約を定義する:

```
class_name EncounterOverlay extends CanvasLayer

signal encounter_resolved(outcome: EncounterOutcome)

func start_encounter(monster_party: MonsterParty) -> void: ...
```

- `EncounterOutcome` (RefCounted)
  - `result: Enum { ESCAPED, CLEARED, WIPED }`
  - スタブ版は常に `CLEARED` を返す
  - 将来的に `gained_exp`, `drops` 等が追加される想定

**combat-system が何を変更するか**:
- `EncounterOverlay` の実装クラスを差し替える（またはサブクラス化）
- シグナル・関数シグネチャは維持、`EncounterOutcome` を拡充

### 8. 乱数ソース

`EncounterManager` は `RandomNumberGenerator` を受け取る。

- テストでは固定シード `rng.seed = 12345` でエンカウント発生パターンを検証
- 本番では `DungeonScreen` が所有する 1 つの RNG を使い回し、**セーブ時にシードを保存しない**（単純化）
- ロード直後はロード後の最初の数歩でエンカウントパターンが再現しないが、本 change のスコープではトレードオフとして許容する（save-load 側で将来別途扱う）

### 9. エンカウントテーブルの粒度: 階層単位

エンカウント判定は**フロア（階層）単位で一律**とし、階層内のゾーン分けは初期実装では行わない。

- 既に `EncounterTableData.floor: int` を持っている構造は維持
- 将来的にゾーン別が必要になった場合に備え、`EncounterTableData` にゾーンを配列として追加できる余地だけ残す（本 change では実装しない）
- 根拠: Wizardry 系は階層単位の出現テーブルで十分機能している前例があり、ゾーン対応は YAGNI

## Risks / Trade-offs

- **連続エンカウント抑止定数 N = 3 の妥当性** → 実プレイでテンポを体感して調整する可能性あり。定数として実装し、将来 `EncounterTableData` へ移す余地を残す。
- **`DungeonScreen` 改造の影響範囲** → 既存テスト（`tests/dungeon/test_*.gd`）に回帰が出ないか注意。シグナル追加は破壊的ではないが、`_unhandled_input` の分岐が増えるため、エンカウントを注入せずに移動だけ行うテストパスも用意する（`EncounterManager` が null のとき no-op）。
- **Custom Resource のリファクタリング負担** → フィールド追加は後方互換を保ちやすいが、削除・改名はデータ資産のマイグレーションが必要。combat-system 着手時にフィールド追加の可能性があるため、スキーマは**保守的に最小限**で出発する。
- **スタブオーバーレイの過剰実装** → スタブが凝りすぎると捨てにくい。テキスト＋ボタンの最小構成に徹する。
- **ロード直後の乱数再現性欠如** → RNG 状態を保存しないため、同じセーブからロードしても次のエンカウントは異なる。デバッグ時に再現できない点はトレードオフとして許容。
