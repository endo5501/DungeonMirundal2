## Context

DungeonMirundal2はWizardry風ダンジョン探索RPG（Godot 4.x）。現在、ダンジョン生成・3D描画・移動・UIが完成しており、次のステップとしてキャラクター＆パーティシステムのロジック層を構築する。

既存コードでは表示専用の `PartyMemberData`（name, level, hp, mp）と `PartyData`（前列3・後列3）がプレースホルダーとして存在する。本changeでは、フルスペックの `Character` クラスとデータ定義を実装し、既存の表示パイプラインと接続する。

既存アーキテクチャの原則:
- **RefCounted** でロジック層を構築（Node非依存、テスト容易）
- **Node層** は薄い表示レイヤー（本changeではスコープ外）
- TDDで進行

## Goals / Non-Goals

**Goals:**
- Godot Resource (.tres) による種族・職業データの外部定義と読み込み
- Wizardry準拠のキャラクター作成ロジック（ボーナスポイント配分制）
- Character クラスによるキャラクター状態の管理
- 冒険者ギルドのキャラクター管理ロジック（登録・削除・一覧）
- パーティ編成ロジック（前列3・後列3、メンバー入替え）
- 既存 PartyMemberData への導出（ダンジョンUIとの互換性維持）

**Non-Goals:**
- UI/シーン層（guild-ui changeで実装）
- レベルアップ・経験値システム（combat-system で実装）
- アイテム・装備（items-and-economy で実装）
- 転職・種族特性
- セーブ/ロード永続化（save-load で実装）

## Decisions

### 1. データ形式: Godot Custom Resource (.tres)

GDScript の `Resource` を継承したカスタムリソースクラスを定義し、エディタまたは手書きで `.tres` ファイルを作成する。

```
src/dungeon/data/race_data.gd       ← Resource継承クラス
src/dungeon/data/job_data.gd        ← Resource継承クラス
data/races/human.tres               ← 実データ
data/races/elf.tres
data/jobs/fighter.tres
data/jobs/mage.tres
...
```

**理由:** Godotネイティブで型安全。`@export` によりエディタで編集可能。`load()` / `preload()` で直接ロード可能。将来MODのような外部データ読込も `ResourceLoader` で対応可能。

**代替案:**
- JSON: パース処理が必要、型安全性なし。テストでは文字列から生成しやすいが、Godot統合が弱い
- GDScript Dictionary: 外部ファイル化できず、カスタマイズ不可

### 2. データローダー: DataLoader クラス

```
src/dungeon/data/data_loader.gd
```

- `load_all_races() -> Array[RaceData]` — `data/races/` 配下の全 .tres をロード
- `load_all_jobs() -> Array[JobData]` — `data/jobs/` 配下の全 .tres をロード
- ファイルシステムアクセスを一箇所に集約し、テストではモック/直接生成が可能

**理由:** ロジック層がファイルパスに依存しないよう、ロード責務を分離する。テストでは `RaceData.new()` で直接インスタンスを生成し、DataLoader を経由しない。

### 3. Character クラス設計

```gdscript
class_name Character extends RefCounted

var character_name: String
var race: RaceData
var job: JobData
var level: int = 1
var base_stats: Dictionary  # {&"STR": int, &"INT": int, ...}
var current_hp: int
var max_hp: int
var current_mp: int
var max_mp: int
```

- `base_stats` は種族基礎値 + ボーナスポイント配分の合計値を保持
- HP = 職業の基礎HP + VIT補正（VIT // 3 程度を想定、具体値はバランス調整対象）
- MP = 魔法職のみ。レベル1の初期MP は職業データから取得
- `to_party_member_data() -> PartyMemberData` で既存UIと接続

**experience, equipment フィールドは本changeでは追加しない。** 後続changeで `Character` を拡張する。

### 4. ボーナスポイント生成: Wizardry準拠の確率分布

```
ボーナスポイント = 基本値(5〜9をランダム) + 追加抽選
追加抽選: 10%の確率で +1〜3 を加算、さらに10%で再抽選（再帰的）
```

この方式により、5〜9が最も多く、10以上は低確率、20以上は極めて稀になる。

`BonusPointGenerator` クラス（RefCounted）として分離し、乱数シードをテストで制御可能にする。

**代替案:**
- 固定テーブル方式: 拡張性が低い
- 正規分布: Wizardryの「極端に高いボーナスが稀に出る」特性を再現しにくい

### 5. 冒険者ギルド管理: Guild クラス

```gdscript
class_name Guild extends RefCounted

var _characters: Array[Character]   # 全登録キャラクター
var _party: PartyData               # 現在のパーティ
```

- `register(character: Character)` — キャラクター登録
- `remove(character: Character)` — キャラクター削除（パーティ所属中は不可）
- `get_unassigned() -> Array[Character]` — パーティ未所属のキャラクター一覧
- `assign_to_party(character, row, position)` — パーティに配置
- `remove_from_party(row, position)` — パーティから外す
- `get_party_data() -> PartyData` — 現在のパーティ（PartyMemberData導出済み）

**理由:** キャラクター管理とパーティ編成を一つのクラスに集約。UI層はGuildに対してのみ操作する。

### 6. 既存 PartyData との関係

現在の `PartyData` は `PartyMemberData` の配列を保持している。この構造は変更せず、`Guild.get_party_data()` が `Character.to_party_member_data()` を使って `PartyData` を生成する。

既存の `DungeonScreen` → `PartyDisplay` → `PartyMemberPanel` のパイプラインは変更不要。

### 7. RaceData / JobData のフィールド設計

**RaceData:**
```gdscript
class_name RaceData extends Resource

@export var race_name: String
@export var base_str: int
@export var base_int: int
@export var base_pie: int
@export var base_vit: int
@export var base_agi: int
@export var base_luc: int
```

**JobData:**
```gdscript
class_name JobData extends Resource

@export var job_name: String
@export var base_hp: int
@export var has_magic: bool
@export var base_mp: int        # has_magic == true の場合のみ使用
@export var required_str: int   # 0 = 条件なし
@export var required_int: int
@export var required_pie: int
@export var required_vit: int
@export var required_agi: int
@export var required_luc: int
```

- `can_qualify(stats: Dictionary) -> bool` — ステータスが就任条件を満たすか判定

### 8. ファイル配置

```
src/dungeon/
├── data/
│   ├── race_data.gd          # RaceData Resource定義
│   ├── job_data.gd           # JobData Resource定義
│   └── data_loader.gd        # DataLoader
├── character.gd              # Character
├── bonus_point_generator.gd  # ボーナスポイント生成
├── guild.gd                  # 冒険者ギルド管理
├── party_data.gd             # (既存)
└── party_member_data.gd      # (既存)

data/
├── races/
│   ├── human.tres
│   ├── elf.tres
│   ├── dwarf.tres
│   ├── gnome.tres
│   └── hobbit.tres
└── jobs/
    ├── fighter.tres
    ├── mage.tres
    ├── priest.tres
    ├── thief.tres
    ├── bishop.tres
    ├── samurai.tres
    ├── lord.tres
    └── ninja.tres

tests/dungeon/
├── test_race_data.gd
├── test_job_data.gd
├── test_character.gd
├── test_bonus_point_generator.gd
├── test_guild.gd
└── test_data_loader.gd
```

## Risks / Trade-offs

- **[Wizardryボーナスポイント分布の再現性]** → 原作の正確な分布は不明瞭な部分がある。再帰的抽選方式で近似し、テストでは確率分布の傾向（平均値、範囲）を検証する
- **[Resource (.tres) のテスト]** → テストでは `RaceData.new()` で直接生成し、.tres ファイルのロードはDataLoaderのテストでのみ検証する。class_name追加後は `godot --headless --import` が必要
- **[Character クラスの将来的な肥大化]** → experience, equipment, spells 等が後続changeで追加される。現時点では最小限のフィールドに留め、拡張ポイントを意識しつつも過剰設計はしない
- **[PartyData の後方互換]** → PartyData / PartyMemberData の既存インターフェースは変更しない。Guild が導出メソッドで橋渡しする
