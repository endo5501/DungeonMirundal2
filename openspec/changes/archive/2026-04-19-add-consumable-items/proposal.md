## Why

現状、Item は装備品 (武器/防具/盾/etc.) のみを扱っており、プレイヤーは消費アイテムを使った回復や緊急帰還ができない。Wizardry 系ダンジョン探索において消費アイテムは戦術的奥行きを与える中核要素であり、これを欠いたままではダンジョン進行の緊張感 (リソース管理・撤退判断) が成立しにくい。今、データモデルと UI の両面に手を入れて「使えるアイテム」の土台を導入する。

## What Changes

- Item に新カテゴリ `CONSUMABLE` を追加し、装備とは別の扱いにする
- Item に `effect: ItemEffect` (Resource) を追加し、使用時の効果を差し替え可能にする
- Item に `context_conditions` / `target_conditions` (Resource 配列) を追加し、「いつ/誰に」使えるかを宣言的に表現する
- 初期ラインナップ 4 点: ポーション、マジックポーション、脱出の巻物、緊急脱出の巻物
- ESC メニュー → パーティ → アイテム画面で消費アイテムを使用可能にする (対象条件による対象選択 UI、コンテキスト条件によるグレーアウト)
- 戦闘コマンドに「アイテム」を追加し、ItemCommand をすばやさ順で解決する
- 戦闘中の「緊急脱出の巻物」は 100% 全員逃走 → 町へ帰還
- ショップに [装備品] / [消費アイテム] のタブを追加し、買売両方を消費アイテムにも対応させる
- 消費アイテムは常に identified=true で生成 (ショップ購入時)

## Capabilities

### New Capabilities

- `consumable-items`: 消費アイテムのデータモデル (CONSUMABLE カテゴリ、Effect Resource 階層、Context/Target Condition Resource 階層)、使用フロー、初期 4 アイテム

### Modified Capabilities

- `items`: Item に CONSUMABLE カテゴリおよび effect / context_conditions / target_conditions フィールドを追加する要件変更
- `shop`: 消費アイテムの買売取扱い、カテゴリ別タブ UI を要件として追加
- `esc-menu-overlay`: アイテム View に使用フロー (対象選択・効果適用・消費) を追加 (現行は読み取り専用)
- `combat-overlay`: コマンドメニューに「アイテム」を追加、ItemCommand の選択 UI とすばやさ順解決ルールを追加
- `dungeon-return`: アイテムによる町への帰還経路を追加 (START タイル経由の既存経路は維持)

## Impact

- **コード**: `src/items/item.gd` (カテゴリ拡張、新フィールド)、`src/items/` 配下に Effect/Condition 階層 (新規多数)、`src/items/shop_inventory.gd` (フィルタ変更)、`src/shop/shop_screen.gd` (タブ UI)、`src/esc_menu/esc_menu.gd` (使用フロー)、`src/dungeon_scene/combat/combat_command_menu.gd` (OPTIONS 拡張)、`src/dungeon_scene/combat/` 配下に ItemCommand 追加 + turn_engine への組み込み、`src/dungeon_scene/dungeon_screen.gd` (帰還経路の共通化)、`main.gd` (帰還シグナル経路の流用)
- **データ**: `data/items/potion.tres` / `magic_potion.tres` / `escape_scroll.tres` / `emergency_escape_scroll.tres` を新規追加
- **セーブデータ**: Inventory のシリアライズ形式は変更しない (ItemInstance.to_dict を流用)。既存セーブと後方互換
- **テスト**: GUT テストを Effect/Condition/Inventory 使用フロー/戦闘 ItemCommand/ショップタブに追加
- **スコープ外**: スタック表示、ダンジョンでの消費アイテム drop、蘇生/毒消し等の追加 Effect は別 change
