## Why

監査で挙がった quick win 群(F010, F015, F021, F026, F027, F028 — C8 でカバー、F032, F040, F042, F043, F045)を 1 つの change にまとめて掃除する。各 finding は単独だと 1 ファイル数行レベル、別 change にすると分割オーバーヘッドが大きすぎるが、放置すると小さなノイズが積もる。

C11 は **tier 6 の最後** として、リファクタの大物が片付いた後の仕上げに位置づける。リスクは個別に低いが、まとめてレビューすることで漏れなく潰せる。

## What Changes

- **F010** — `src/dungeon_scene/dungeon_scene.gd` の未使用 `DungeonView` フォールバックを削除。`refresh()` が空 `visible_cells` を受け取るパスは存在しないので、防御的フォールバックを撤去する。
- **F015** — `src/town_scene/temple_screen.gd:62-67` の `gold < cost` 重複ガードを削除し、`spend_gold` の戻り値だけに依存する。
- **F021** — `src/dungeon/wiz_map.gd:218,220` の冗長な `as int` キャストを削除。
- **F026** — `docs/reference/first_plan.md` の冒頭に「これはプロジェクト初期のスナップショット。最新仕様は `openspec/specs/` を参照」のバナーを追加。
- **F027** — `src/items/equipment.gd:equip` を `can_equip` に内部委譲する形に整理。
- **F032** — `data/items/potion.tres` を `healing_potion.tres` にリネーム、`item_id` を `&"healing_potion"` に変更。既存セーブの `inventory.items` に `&"potion"` がある場合の互換性を `ItemRepository` 内のエイリアスで吸収する(または既存セーブを破壊する旨を README に明記)。
- **F040** — `src/save_manager.gd:33` の `JSON.stringify(data, "\t")` の `"\t"` を `""` に変更してセーブファイルサイズを削減。
- **F042** — `README.md` の「Godot Engine 4.6+」を「Godot Engine 4.6.x」に修正(または `4.6+` を維持して 4.7 でテストする)。
- **F043** — `src/items/conditions/item_use_context.gd` と `src/items/conditions/item_effect_result.gd` を `src/items/` 直下に移動。
- **F045** — `src/town_scene/town_screen.gd:select_item` の `match index` を `MAIN_IDX_*` 定数に置き換え。

## Capabilities

### Modified Capabilities

- `dungeon-3d-rendering`: F010 のフォールバック削除を反映
- `temple`: F015 の gold check 重複削除
- `equipment`: F027 の `equip` を `can_equip` ベースに整理
- `consumable-items`: F032 のアイテム名統一
- `save-manager`: F040 のフォーマット圧縮を反映
- `town-screen`: F045 の MAIN_IDX_* 定数化
- `items`: F043 の context / result の場所を反映

## Impact

- **削除**:
  - `src/dungeon_scene/dungeon_scene.gd` の `_dungeon_view: DungeonView` フィールドおよび関連ロジック
  - `src/town_scene/temple_screen.gd` の `gold < cost` 早期 return
  - `src/dungeon/wiz_map.gd:218,220` の `as int` キャスト
  - `src/items/equipment.gd` の `equip` 内重複バリデーション(can_equip 経由化)
- **変更コード**:
  - `data/items/potion.tres` リネーム → `healing_potion.tres`、`item_id` 更新
  - `src/save_manager.gd` の JSON フォーマット
  - `README.md` のバージョン記述
  - `src/town_scene/town_screen.gd` の `select_item` を `MAIN_IDX_*` 定数化(F045 は既に部分的に適用されているなら必要箇所のみ)
- **新規コード**:
  - なし
- **移動**:
  - `src/items/conditions/item_use_context.gd` → `src/items/item_use_context.gd`
  - `src/items/conditions/item_effect_result.gd` → `src/items/item_effect_result.gd`
- **ドキュメント追加**:
  - `docs/reference/first_plan.md` 冒頭バナー
- **互換性**:
  - F032 のアイテムリネームは既存セーブに影響(potion を持っている場合 from_dict が null を返す)→ `ItemRepository` にエイリアス機構を追加するか、既存セーブを破壊することを README に明記する判断が必要
  - F040 の JSON フォーマット変更は既存セーブファイルのロードには影響しない(改行・タブが減るだけ、parser は受け入れる)
- **依存関係**:
  - 全前段(C1〜C10)完了後に着手するのが自然
  - 各 finding は独立しており、他 change との衝突はほぼなし
