## Context

現状のアイテムシステムは装備品専用で、データモデル (Item.category) も UI (ESC メニュー Items View は読み取り専用、戦闘コマンドは 3 択固定配列) も「使用可能なアイテム」の概念を持たない。Shop は `equip_slot != NONE` で装備品だけをフィルタしており、消費アイテムの買売も通っていない。ダンジョンからの帰還は START タイルでの確認ダイアログ経由に限定されている。

本 change は消費アイテム 4 種 (ポーション / マジックポーション / 脱出の巻物 / 緊急脱出の巻物) を導入するのと同時に、効果 (Effect) と利用条件 (Context/Target Condition) を **Resource 階層で宣言的に表現する基盤** を整える。これは今回のアイテム 4 種だけでなく、将来の蘇生/毒消し/バフ系などの追加アイテムを小さな .tres 編集で済ませるための土台でもある。

影響を受ける既存コードの起点:

- `src/items/item.gd` — Item Resource と ItemCategory/EquipSlot 列挙
- `src/items/item_instance.gd` — identified フラグ付きラッパー
- `src/items/inventory.gd` — パーティ共有インベントリ (add/remove/list/contains、gold)
- `src/items/shop_inventory.gd` line 12 — 現在の装備品フィルタ
- `src/shop/shop_screen.gd` line 87-111 — 買売実装
- `src/esc_menu/esc_menu.gd` line 387-412 — Items View の読み取り専用描画
- `src/dungeon_scene/combat/combat_command_menu.gd` line 4 — OPTIONS 固定配列
- `src/dungeon_scene/dungeon_screen.gd` line 137-192 — START タイル帰還ダイアログ + `return_to_town` シグナル

## Goals / Non-Goals

**Goals:**

- 消費アイテムを装備とは別カテゴリとしてデータモデルに導入し、`.tres` だけで新規追加できるようにする
- 「何が起きるか (Effect)」と「いつ・誰に使えるか (Context/Target Condition)」を Resource 階層で分離し、UI と解決ロジックが同じ宣言を参照できるようにする
- 非戦闘 (ESC メニュー) / 戦闘 (ItemCommand) / ショップ (タブ付き買売) の 3 箇所で使用可能にする
- 既存の START タイル帰還経路を維持しつつ、巻物経由の同等帰還を追加する
- 既存セーブデータとの互換性を保つ (Inventory のシリアライズ形式を変更しない)

**Non-Goals:**

- スタック/数量表示 (N 個 = N 行のままとする。将来別 change)
- ダンジョンでの消費アイテム drop (ショップ購入のみが入手経路)
- 蘇生 / 毒消し / バフ / デバフ解除などの追加 Effect (階層は拡張可能に作るが、今回のアイテムには含めない)
- 戦闘中のアイテム使用すばやさ補正 (通常のすばやさ順に混ぜる)
- インベントリ上限 (現在上限なし、そのまま)

## Decisions

### 1. Effect を Resource 階層で表現 (enum + params 案を却下)

`ItemEffect` を abstract base Resource として定義し、具象として `HealHpEffect { power }` / `HealMpEffect { power }` / `EscapeToTownEffect` を派生させる。Item は `@export var effect: ItemEffect` を持つ。

代替案として「効果を enum + パラメータにまとめる」も検討したが:

- Effect ごとに持つパラメータ数・型が異なると enum + dict 的になり、型安全性が落ちる
- Godot エディタ上で `.tres` を編集するとき、Resource のほうがフィールドが見える
- 将来の拡張 (蘇生に target 指定、バフに duration) で無理なく拡張できる

Effect には `apply(user, targets, context) -> ItemEffectResult` のような統一インターフェースを持たせ、使用ロジック側は `item.effect.apply(...)` を呼ぶだけにする。

### 2. 利用条件を Context / Target の 2 階層に分離

`ItemUseCondition` を 1 つにまとめる案も検討したが、UI の挙動が異なるため分離する:

- **ContextCondition** (`InDungeonOnly`、`NotInCombatOnly`) — 「その場面で使えるか」。満たされないときは **アイテム行自体をグレーアウト** する
- **TargetCondition** (`AliveOnly`、`NotFullHp`、`NotFullMp`、`HasMpSlot`) — 「その対象に使えるか」。満たされないときは **対象選択画面の該当味方のみグレーアウト** する

Item は両方を配列で持つ:

```gdscript
@export var context_conditions: Array[ContextCondition]
@export var target_conditions: Array[TargetCondition]
```

対象条件が空 (`[]`) のアイテムは「対象選択なし」(巻物系) と解釈する。

### 3. 脱出の巻物 / 緊急脱出の巻物 を単一 Effect で表現

差は「戦闘中に使えるか」だけなので、Effect は `EscapeToTownEffect` に統一し、アイテム側の `context_conditions` で差別化する:

- 脱出の巻物: `context_conditions = [InDungeonOnly, NotInCombatOnly]`
- 緊急脱出の巻物: `context_conditions = [InDungeonOnly]`

`EscapeToTownEffect.apply` は内部で「戦闘中なら全員逃走 + 町へ / 非戦闘なら直接町へ」を分岐する。シグナル経路は既存の `return_to_town` を流用する。

代替案として「NormalEscapeEffect と CombatEscapeEffect を分ける」も考えたが、ユーザーから見れば結果 (= 町メニュー入口に戻る) は同じなので、Effect を分けるメリットが薄い。

### 4. 戦闘コマンドの拡張方針

`combat_command_menu.gd` の OPTIONS を `["こうげき", "ぼうぎょ", "アイテム", "にげる"]` に広げる。位置は固定 (インベントリが空でも「アイテム」は残す)。

`ItemCommand extends CombatCommand`:

```
ItemCommand:
  - actor: CombatActor    (使用者)
  - item_instance: ItemInstance
  - target: CombatActor | Array[CombatActor] | null
  - cancelled: bool       (すばやさ順解決前に使用者が KO なら true)
```

**TurnEngine での解決ルール:**

- すばやさ順に通常の行動と混在
- 解決直前に「使用者が行動可能か」をチェック、不可なら `cancelled = true` で終了、アイテムは **消費しない**
- 解決時に Effect.apply を呼び、Inventory から instance を削除
- `EscapeToTownEffect` を戦闘中に発火した場合: TurnEngine はターン解決を打ち切り、「逃走成功」 → 町への遷移を発火

### 5. 帰還経路の共通化

現状 `dungeon_screen.gd` の `_show_return_dialog` が `return_to_town` シグナルを発火している。巻物使用時も同じシグナルを発火させて `main.gd` の既存遷移コードを再利用する。

戦闘中帰還の場合、先に戦闘オーバーレイを閉じる必要があるので、遷移は:

```
EscapeToTownEffect.apply (戦闘中)
  → 戦闘終了 (逃走成功扱い、EXP/Gold 無し)
  → dungeon_screen の return_to_town 経路を発火
  → main.gd が town メニュー入口 (TownScreen) に遷移
```

### 6. ショップの UI とフィルタ変更

`ShopInventory` のフィルタを「販売対象カテゴリ (=装備品 OR 消費アイテム)」に変更する。現行の `equip_slot != NONE` は装備品が副次的に満たすだけの条件だったので、明示的に `item.category == WEAPON/ARMOR/... OR CONSUMABLE` に書き換える。

UI は `shop_screen.gd` に **カテゴリタブ** を追加する:

```
┌────────────────────────────────┐
│ [装備品] [消費アイテム]        │  ← タブ (現在アクティブは強調)
├────────────────────────────────┤
│ ポーション         50 G        │
│ マジックポーション 200 G       │
│ ...                            │
└────────────────────────────────┘
```

売却価格は既存ルール `floor(price / 2)`、装備中チェックは消費アイテムには不適用 (そもそも装備できない)。購入時は identified=true で ItemInstance を生成 (既存仕様通り)。

### 7. 鑑定の扱い

消費アイテムは常に `identified=true` で生成する。ダンジョン drop は Non-Goal なので、現状の「ショップ購入 = identified」のルールで一貫する。将来 drop を入れる change で再検討する。

### 8. セーブデータ互換性

Inventory のシリアライズ形式 (`to_dict = { gold, items: [ItemInstance.to_dict()] }`) は一切変更しない。ItemInstance.to_dict は item_id と identified を持つだけで、Item 側の新フィールド (effect/conditions) は `.tres` ファイルから読み込まれる。既存セーブは item_id 解決を通して新 Item Resource にマップされるため、後方互換。

## Risks / Trade-offs

- **[Risk] `.tres` を手書きで作ると Resource 参照 (SubResource) の記法を間違えやすい** → 設計上、新規の `.tres` 作成時は Godot エディタで作成することをタスクで明記。手書きが必要な場合は既存 .tres を雛形にする
- **[Risk] 戦闘中の EscapeToTownEffect が TurnEngine のターン解決途中で発火すると、残りの行動 (遅いキャラのこうげき等) が宙に浮く** → 「逃走成功」時と同じ扱いで **残ターン破棄** と決める。specs/combat-overlay の delta に明記
- **[Risk] Target Condition が増えると、対象選択 UI の判定が重くなる** → 現時点で 4 種なので許容。UI 側は条件配列を素直に AND 評価する単純実装で良い
- **[Trade-off] スタックなし方針** → インベントリが縦に伸びる。N=10 でも許容範囲として今回は見送り、実運用で問題が出た時点で別 change
- **[Trade-off] Effect クラス増加** → 将来 Effect が 10 種を超えると `src/items/effects/` 配下のファイル数が増える。許容し、ディレクトリ構造で整理する

## Migration Plan

1. データモデル拡張 (Item に CONSUMABLE カテゴリ、effect/conditions フィールド追加)。既存 .tres は影響なし (新フィールドはデフォルト null/空配列)
2. Effect / Condition Resource 階層を追加 (純データ & 単体テスト)
3. 初期 4 アイテムの `.tres` を `data/items/` に追加
4. Inventory 側のアイテム使用 API (use_item など) を追加 (Inventory 自体の内部データは不変)
5. ESC メニュー Items View に使用フロー追加
6. ShopInventory フィルタ変更 + Shop 画面タブ UI 追加
7. 戦闘コマンドメニュー拡張 + ItemCommand + TurnEngine 組込み
8. 帰還経路の共通化 (EscapeToTownEffect → return_to_town シグナル)
9. E2E の手動確認 (ショップで買う → 非戦闘で使う → 戦闘で使う → 巻物で帰還)

**ロールバック戦略**: 各ステップは独立なコミットとし、問題があれば該当コミットを revert。Item 側の新フィールドは optional なので、revert しても既存 .tres と既存セーブは壊れない。

## Open Questions

- なし (探索モードで主要な論点は合意済み)。実装中に細部 (Effect.apply の戻り値設計、対象選択 UI のキー操作) は必要に応じて tasks.md 内で決める。
