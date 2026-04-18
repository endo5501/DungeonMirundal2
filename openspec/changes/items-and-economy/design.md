# Design: items-and-economy

## Context

本 change は、combat-system が「最小インターフェース + ダミー実装」として残した装備・アイテム層を本実装で埋める。以下の前提の上に乗る。

- **Godot 4.x + GDScript**。ロジック層は `RefCounted`、表示層は `Node`。
- **データは Custom Resource (.tres)**、`DataLoader` で一括ロード（`data/monsters/`, `data/jobs/`, `data/races/` が既存パターン）。
- **Character**（`src/dungeon/character.gd`）: `STR/INT/PIE/VIT/AGI/LUC`、`level`、`current_hp / max_hp`、`current_mp / max_mp`、`race: RaceData`、`job: JobData`、`to_dict / from_dict` あり。
- **Guild**（`src/dungeon/guild.gd`）: `_front_row` / `_back_row` に `Character` 参照を保持。永続化は SaveManager が担う。
- **EquipmentProvider**（`src/combat/equipment_provider.gd`, archive combat-system）: `get_attack(character) / get_defense(character) / get_agility(character)` の 3 メソッドの仮想インターフェース。`PartyCombatant` に DI されている。
- **DummyEquipmentProvider**（`src/combat/dummy_equipment_provider.gd`）: 職業別の固定ボーナスを返すだけの実装。本 change で `InventoryEquipmentProvider` に置き換える。
- **EncounterOutcome**（`src/dungeon/encounter_outcome.gd`）: `result`、`gained_experience`、`drops` を持つ。本 change で `gained_gold` を追加。
- **MonsterData**（`src/dungeon/data/monster_data.gd`）: `monster_id`, `monster_name`, `max_hp_min/max`, `attack/defense/agility`, `experience` を持つ。本 change で `gold_min` / `gold_max` を追加。
- **SaveManager**（`src/save_manager.gd`）: `save(slot) / load(slot)` で JSON シリアライズ。`Guild` / `DungeonRegistry` / `game_location` を保存済み。本 change で Inventory / Gold / Equipment を追加。
- **ESC メニュー**（`src/esc_menu/esc_menu.gd`）: 「アイテム」「装備」が `PARTY_MENU_DISABLED = [1, 2]` で無効化中。本 change で有効化。
- **TownScreen**（`src/town_scene/town_screen.gd`）: 「商店」「教会」が `DISABLED_INDICES = [1, 2]` で無効化中。本 change で有効化。
- **テスト**: GUT、`tests/<subsystem>/test_*.gd`、`extends GutTest`。

## Goals / Non-Goals

**Goals:**
- `.tres` ベースのアイテム定義を整備し、武器・鎧・兜・盾・籠手・装身具・その他カテゴリを扱えるようにする
- パーティ共有インベントリ + ゴールド + キャラ毎 6 スロット装備を `RefCounted` 主体で実装し、純粋ロジックを GUT から単体検証可能にする
- `InventoryEquipmentProvider` を新設し、`main.gd` の `PartyCombatant` 生成時に `DummyEquipmentProvider` と差し替える
- 商店 UI（購入 / 売却、単一固定在庫）と教会 UI（死亡 → 蘇生、100% 成功）をオーバーレイではなく **町画面のサブ画面**として実装
- 戦闘勝利時にゴールドドロップ（`gold_min〜gold_max` の一様乱数）を `EncounterOutcome.gained_gold` 経由で反映
- キャラ作成時に職業別の初期装備を `Inventory` に積み、該当スロットへ自動装備
- セーブ/ロードに Inventory / Gold / Equipment を含め、後方互換を保つ（旧 save ファイルは inventory 空 / gold 0 / equipment 空として読める）

**Non-Goals:**
- 消耗品の「使用」アクション（データ定義すら MVP から除外）
- 未鑑定 UI（`identified` フラグはデータモデルに入れるが、商店に鑑定サービスを置かない）
- 呪い装備・装備中ロック
- モンスタードロップ / 宝箱 / 罠
- 灰化・ロスト等の追加死亡ステート、蘇生失敗処理
- 戦闘中「アイテム使用」コマンドの追加
- 戦闘バランスの最終調整
- 商店の在庫ランダム化・多店舗化

## Decisions

### 1. Item / ItemInstance を二層に分ける

アイテムを**静的定義（不変）**と**動的インスタンス（状態あり）**の二層に分離する。

```
Item (Resource, data/items/*.tres)          ItemInstance (RefCounted, runtime)
  ├─ item_id: StringName                     ├─ item: Item (参照)
  ├─ item_name: String                       └─ identified: bool (MVP 常に true)
  ├─ unidentified_name: String
  ├─ category: Enum
  ├─ equip_slot: Enum (WEAPON/ARMOR/...)
  ├─ allowed_jobs: Array[StringName]
  ├─ attack_bonus: int
  ├─ defense_bonus: int
  ├─ agility_bonus: int
  └─ price: int
```

**理由**:
- 同一定義の剣が 3 本あったとき、`identified` や将来の「耐久」「チャージ」はインスタンス毎に異なる
- `.tres` は不変データ向けに最適、`RefCounted` で in-memory 状態管理
- セーブは `ItemInstance` 側を `to_dict() / from_dict(repo)` で直列化（`item_id` だけ保存し、ロード時に `ItemRepository` から定義を解決）

**代替案（却下）**:
- `Item` 単体で `identified` も持たせる → 複数本区別できない、呪い追加時に破綻
- 全てを dict で扱う → 型がない、`.tres` エディタ編集の利便性を捨てる

### 2. ItemRepository は `DataLoader` 経由で一括ロード

既存パターンに合わせ、`data/items/*.tres` を起動時に `DataLoader.load_all_items()` で舐めて `ItemRepository` に登録する。

```
ItemRepository (RefCounted)
  ├─ _by_id: Dictionary[StringName -> Item]
  ├─ find(item_id) -> Item / null
  └─ all() -> Array[Item]
```

- `GameState.item_repository` を追加（`guild` や `save_manager` と並列）
- 起動時の初期化は `main.gd` の既存フローに合わせる
- テストはディレクトリを触らず、Repository をモック配列から組める API にする

### 3. Inventory は `Guild` ではなく独立クラス

```
Inventory (RefCounted)
  ├─ _items: Array[ItemInstance]
  ├─ add(instance)
  ├─ remove(instance) -> bool
  ├─ contains(instance) -> bool
  ├─ list() -> Array[ItemInstance]  (copy)
  ├─ gold: int
  ├─ add_gold(amount)
  └─ spend_gold(amount) -> bool
```

**理由**:
- `Guild` はパーティ編成（キャラクター配置）の責務に集中させる
- Inventory を単独クラスにすることで、商店・教会・戦闘ドロップ各々から `inventory` への参照だけで扱える
- `Guild` と `Inventory` を並列に `GameState` が持つ設計（`GameState.guild`, `GameState.inventory`）

**代替案（却下）**:
- `Guild.inventory` フィールド → パーティ編成と所持品が同じオブジェクトに混ざり、テストの組みづらさが増す
- キャラ毎個別インベントリ → UI/管理コストが高く、MVP でパーティ共有と決めた方針と矛盾

### 4. Equipment はキャラに 6 スロット

```
Equipment (RefCounted)
  ├─ _slots: Dictionary[Enum EquipSlot -> ItemInstance]
  ├─ equip(slot, instance) -> PreviousInstance / null
  ├─ unequip(slot) -> ItemInstance / null
  ├─ get_equipped(slot) -> ItemInstance / null
  └─ all_equipped() -> Array[ItemInstance]

EquipSlot enum: WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY
```

- `Character.equipment: Equipment` を追加（`to_dict / from_dict` に含める）
- `equip(slot, instance)` は `allowed_jobs` が `character.job.job_name` を含む場合のみ成功（それ以外は失敗を返す）
- `equip` はスロット種別と `instance.item.equip_slot` が一致する場合のみ成功

**代替案（却下）**:
- 装備を `Inventory` の「どのアイテムがどのキャラに装備中か」フラグで持つ → キャラ毎の 6 スロット参照が直接引けず、戦闘ステータス計算で毎回走査が必要
- `Character` に `weapon / armor / helmet / shield / gauntlet / accessory` を 6 フィールドとして持つ → enum 経由のループ処理が書きにくい

### 5. InventoryEquipmentProvider は装備を合算する

```
InventoryEquipmentProvider extends EquipmentProvider
  ・get_attack(character)  = base_stats[STR]/2  + Σ equipped.attack_bonus
  ・get_defense(character) = base_stats[VIT]/3  + Σ equipped.defense_bonus
  ・get_agility(character) = base_stats[AGI]    + Σ equipped.agility_bonus
```

- `DummyEquipmentProvider` と **同じ base_stats 係数**を踏襲（combat-system のバランスを維持）
- 装備が 0 個のキャラも動作（Σ = 0）
- 未鑑定フラグは MVP では無視（鑑定 UI 別 change）
- `main.gd` の `PartyCombatant` 生成箇所で `DummyEquipmentProvider` → `InventoryEquipmentProvider` に切り替え。`combat-system` spec は「Provider を DI」方針なのでコンストラクタ引数だけ差し替えで済む

**代替案（却下）**:
- 職業ボーナスを併用 → Dummy のボーナスが「素手の職業差」を擬似表現だっただけで、装備込みで二重加算すると過剰。装備 0 個は素手（Σ=0）として扱うのが正しい

### 6. 商店は町画面のサブ画面

TownScreen から「商店」を選ぶと `ShopScreen` に遷移（フェードや履歴 push は既存 ScreenNavigation に合わせる）。単一商店、固定在庫。

```
ShopScreen (Control)
  ├─ 購入モード: 商店在庫 × 所持金 → 購入
  ├─ 売却モード: パーティ所持品 → 売却（買値の 1/2 切り捨て）
  └─ 戻る: TownScreen に復帰

ShopInventory (RefCounted)
  ├─ _items: Array[Item]  (Item 定義の配列。ItemInstance ではない)
  └─ purchase(item) -> ItemInstance
```

- 在庫は `ShopInventory` を `Item` の配列で保持（固定・無限供給）
- 購入: `Inventory.spend_gold(price)` → 新規 `ItemInstance.new(item, identified=true)` → `Inventory.add(instance)`
- 売却: `Inventory.remove(instance)` → `Inventory.add_gold(item.price / 2)`（切り捨て）
- 装備中のアイテムは売却 **不可**（`Equipment.get_equipped` で装備中判定）

**代替案（却下）**:
- 商店もオーバーレイ化 → 町画面の既存パターン（ダンジョン入口、ギルド）は画面遷移。揃える

### 7. 教会は町画面のサブ画面（MVP は蘇生のみ）

```
TempleScreen (Control)
  ├─ パーティ一覧から死亡キャラを選択
  ├─ コスト表示: character.level × 100 G
  ├─ ゴールド支払い → character.current_hp = 1（生き返る）
  └─ 100% 成功（失敗処理は別 change）
```

- ゴールド不足時は「ゴールドが足りません」表示のみ（金額固定なので減算なし）
- 生存キャラを選んだ場合は「蘇生対象がいません」表示
- 定数 100 は `TempleScreen.REVIVE_COST_PER_LEVEL` として定義、バランス調整しやすくする

### 8. ゴールドドロップは monster 単位 + 乱数範囲

`MonsterData` に `gold_min: int, gold_max: int` を追加。

```
EncounterOutcome.gained_gold = Σ over dead monsters: rng.randi_range(gold_min, gold_max)
```

- `TurnEngine.outcome()` を経由して `CombatOverlay` の ResultPanel で表示
- `main.gd` が `encounter_resolved(outcome)` 時に `GameState.inventory.add_gold(outcome.gained_gold)` を呼ぶ
- `MonsterData` 既存 `.tres`（slime / goblin / bat）3 体にフィールドを補う（slime: 1〜3、goblin: 5〜15、bat: 2〜8 など暫定値）

**代替案（却下）**:
- 全モンスター固定ドロップ → 単調
- パーセンテージ（30% で X） → MVP では範囲乱数で十分、複雑さを避ける

### 9. 初期装備はキャラ作成時に職業に応じて付与

```
Character 作成時（CharacterCreation）:
  └ job.job_name に応じて CharacterCreation.INITIAL_EQUIPMENT 辞書から
    Array[StringName item_id] を引き、ItemRepository で解決して
    Inventory に add + Equipment の該当スロットに装備
```

- 職業別の初期装備例（暫定、データ整備時に最終化）:
  - Fighter: ロングソード + レザーアーマー
  - Mage: スタッフ + ローブ
  - Priest: メイス + ローブ
  - Thief: ショートソード + レザーアーマー
  - Bishop: スタッフ + ローブ
  - Samurai: ロングソード + レザーアーマー
  - Lord: ロングソード + レザーアーマー
  - Ninja: ショートソード + レザーアーマー
- 初期ゴールドは **パーティ毎** 500G（`GameState.new_game()` で `Inventory.gold = 500` 初期化）

**代替案（却下）**:
- 初期装備なしで初期ゴールド潤沢 → 最初の戦闘が DummyEquipmentProvider 切り替えで破綻するリスクが高い

### 10. ESC メニュー「アイテム」「装備」の中身

```
ESC メニュー > パーティ > アイテム
  ├─ インベントリ一覧表示（アイテム名 / カテゴリ / 装備中の場合は印）
  └─ 閲覧のみ（使用は別 change）

ESC メニュー > パーティ > 装備
  ├─ キャラ選択 → スロット選択 → インベントリから候補表示 → 装備/解除
  ├─ `allowed_jobs` に含まれないアイテムはグレーアウト（ただし装備中の物は外せる）
  └─ 装備中アイテムの売却は不可（商店側で制御）
```

- 既存 `PARTY_MENU_DISABLED = [1, 2]` から両項目を外す
- `PartyMenuInventoryView` / `PartyMenuEquipmentView` を `esc_menu` 内部のサブビューとして追加
- ViewState 機械は既存 `View` enum を拡張

### 11. セーブデータフォーマット拡張

```
SaveFile JSON:
  ...
  "inventory": {
      "gold": 500,
      "items": [
          {"item_id": "long_sword", "identified": true},
          ...
      ]
  },
  "guild": {
      "front_row": [
          {"character": {...既存...,
                          "equipment": {
                              "weapon": 0,       // inventory.items の index
                              "armor": 1,
                              "helmet": null,
                              "shield": null,
                              "gauntlet": null,
                              "accessory": null
                          }}},
          ...
      ],
      ...
  }
```

- `ItemInstance` 参照は **インベントリ内 index** で表現（JSON 循環参照を避ける）
- `Equipment.to_dict(inventory)` が `{slot_name: index_or_null}` を返し、`from_dict(data, inventory)` で復元
- 旧セーブ互換: `inventory` キーが無い場合は空インベントリ / gold=0 として読む

### 12. 依存順と施行順

```
1. Item / ItemRepository / ItemInstance
2. Inventory
3. Equipment
4. InventoryEquipmentProvider  ← ここまで来ると combat 差し替え可能
5. 初期装備 & 初期ゴールド（CharacterCreation / GameState.new_game）
6. MonsterData gold_min/gold_max + EncounterOutcome.gained_gold + CombatOverlay 表示
7. ESC メニューのアイテム / 装備ビュー
8. ShopScreen / TempleScreen + TownScreen の enable
9. SaveManager の inventory / equipment / gold 永続化
10. DummyEquipmentProvider 削除（または Deprecated マーク）
```

## Risks / Trade-offs

- **InventoryEquipmentProvider 切り替え時のバランス崩壊** → 初期装備を職業毎に付与し、Dummy の固定ボーナスと近い範囲の数値に設定する。バランス最終調整は別 change。
- **セーブ互換の壊れ方** → 旧セーブに `inventory` / `equipment` が無い場合は空で補う明示ロジックを入れる。新フィールドはすべて default 値を持つ。
- **アイテム数が増えた時のロード時間** → `DataLoader.load_all_items()` は起動時 1 回のみ。現状想定アイテム数は十数〜数十で十分高速。
- **`allowed_jobs` の書き漏れ** → 全 8 職を明示する spec シナリオと、テストで代表 3 職（Fighter / Mage / Priest）のチェックで担保。
- **装備中アイテムの売却防止が複数箇所に散る** → `Inventory.remove()` に「装備中のアイテムは remove 不可」制約を寄せるか、`ShopScreen` 側で一元チェックするか。**後者を採用**：Inventory は低レベル、装備判定は画面側の責務。
- **MVP 境界線が曖昧になる** → `identified` フラグはデータモデルに残すが、UI は存在しない。商店の鑑定サービスも無い。ドロップ時は生成コードが常に `identified=true` を渡す。ここをコード規約として design.md に明記。
- **商店在庫の決め方** → 暫定で全 Item 定義を在庫に並べる。将来的に `ShopInventory` を `.tres` 化する余地を残す（今は配列リテラル）。

## Open Questions

- ShopScreen の UI レイアウト（購入/売却の切り替え方式）: タブ切り替え vs メニュー切替。初期は **メニュー切り替え**（「購入する」「売却する」「出る」）で進める想定。
- TempleScreen で死亡キャラが複数いる時の UI（キャラ個別選択の順番）: 既存 PartyFormation 風のカーソル選択が素直。
- ESC メニューの装備ビューでアイテム候補数が多い時のスクロール UI: MVP では候補数が少ない前提で、シンプルな縦リスト。スクロールは将来課題。
- `ItemInstance` の JSON 表現で、同一 `item_id` の複数本を扱う際のソート安定性: 配列 index で参照するため、load 時に順序が保存される前提を明示する。
